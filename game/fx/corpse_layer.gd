class_name CorpseLayer
extends Node3D
## Corpses and severed limbs (GDD §6, PHASE0 0.7): a capped ring buffer drawn with one MultiMesh per
## zombie look, playing the VAT death clip once and then holding its last frame (no ragdoll).
## Old corpses sink through the floor to make room; corpses in water float a while, then sink.
## Blast deaths slide along an arc away from the centre (fake ragdoll), stopping at walls and
## splashing into the water off the roof. A severed limb is the same mesh with every other part
## hidden: thrown as a real rigid body while under the cap, else laid down near the corpse.

const FLOATS_PER_INSTANCE: int = 20
const VAT_SHADER: Shader = preload("res://game/shaders/horde_vat.gdshader")
const ALL_PARTS: int = (1 << 11) - 1  # kit_zombie SKELETON order
## Severable groups as part bitmasks: head, left arm, right forearm, left shin, right leg.
const LIMB_GROUPS: PackedInt32Array = [1 << 2, (1 << 3) | (1 << 4), 1 << 6, 1 << 8, (1 << 9) | (1 << 10)]
const LIMB_REST_T: float = 99.0  ## VAT time of a laid-down limb: the death clip's last (lying) frame
const WALL_GAP: float = 0.35  ## m a sliding corpse stops short of a blocked cell
const OBSTACLE_HEIGHT: float = 1.6  ## m, collision boxes over blocked cells for flying limbs

var config: GoreConfig
var models: Array[VatModel] = []
var grid: NavGrid  ## optional: corpses off the grid are in water
var ground_y: float = 0.0
var water_y: float = -INF

var _cap: int = 0
var _next: int = 0
var _alive: PackedByteArray
var _pos: PackedVector2Array
var _head: PackedVector2Array
var _y: PackedFloat32Array
var _variant: PackedByteArray
var _tint: PackedColorArray
var _clip: PackedByteArray  ## 0 death, 1 death_blown
var _t: PackedFloat32Array  ## s since death (or since landing in water)
var _pose_t: PackedFloat32Array  ## VAT time; < 0 = follow _t (corpses play their death clip)
var _hide: PackedInt32Array
var _in_water: PackedByteArray
var _sink: PackedFloat32Array  ## s sinking, < 0 = not yet
var _slide_t: PackedFloat32Array  ## s into the blast slide, < 0 = not sliding
var _from: PackedVector2Array
var _to: PackedVector2Array
var _free_xf: PackedByteArray  ## 1 = posed by _xf (a limb that flew as a rigid body)
var _xf: Array[Transform3D] = []
var _body: Array[RigidBody3D] = []
var _pivot: PackedVector3Array  ## limb centre in mesh space: body origin = slot transform * pivot
var _body_age: PackedFloat32Array
var _body_order: PackedInt32Array = PackedInt32Array()  ## slots with a live body, oldest first
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _layers: Array[MultiMeshInstance3D] = []
var _buffers: Array[PackedFloat32Array] = []
var _death_rows: Array[PackedInt32Array] = []  ## per look: [death, death_blown] clip index
var _floor: StaticBody3D


func setup(p_config: GoreConfig, p_models: Array[VatModel]) -> void:
	config = p_config
	models = p_models
	_cap = config.corpse_cap
	_alive.resize(_cap)
	_variant.resize(_cap)
	_clip.resize(_cap)
	_in_water.resize(_cap)
	_free_xf.resize(_cap)
	_pos.resize(_cap)
	_head.resize(_cap)
	_y.resize(_cap)
	_tint.resize(_cap)
	_t.resize(_cap)
	_pose_t.resize(_cap)
	_hide.resize(_cap)
	_sink.resize(_cap)
	_slide_t.resize(_cap)
	_from.resize(_cap)
	_to.resize(_cap)
	_pivot.resize(_cap)
	_body_age.resize(_cap)
	_xf.resize(_cap)
	_body.resize(_cap)
	_rng.randomize()
	for model: VatModel in models:
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = model.extract_mesh()
		mm.instance_count = _cap
		mm.visible_instance_count = 0
		var layer: MultiMeshInstance3D = MultiMeshInstance3D.new()
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = VAT_SHADER
		mat.set_shader_parameter("vat_position", model.positions)
		mat.set_shader_parameter("vat_normal", model.normals)
		layer.material_override = mat
		layer.multimesh = mm
		# Lying bodies throw almost no visible shadow; skipping the shadow pass halves their cost.
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.custom_aabb = AABB(Vector3(-500, -20, -500), Vector3(1000, 40, 1000))
		add_child(layer)
		_layers.append(layer)
		var buf: PackedFloat32Array = PackedFloat32Array()
		buf.resize(_cap * FLOATS_PER_INSTANCE)
		_buffers.append(buf)
		_death_rows.append(PackedInt32Array([model.clips.index_of("death"), model.clips.index_of("death_blown")]))
		# Read the limb boxes now (one CPU pass over the VAT image) instead of on the first blast.
		for group: int in LIMB_GROUPS:
			model.part_bounds(group, _death_rows[-1][0])
	if is_inside_tree() and config.enabled and config.limb_body_cap > 0:
		_ensure_floor()


func live_count() -> int:
	return _alive.count(1)


func body_count() -> int:
	return _body_order.size()


func sliding_count() -> int:
	var n: int = 0
	for i: int in _cap:
		if _alive[i] != 0 and _slide_t[i] >= 0.0:
			n += 1
	return n


## A zombie died: lay its corpse (maybe dismembered) and return the severed group mask (0 = whole).
func add_death(d: Horde.Death) -> int:
	var hide: int = 0
	var chance: float = config.dismember_chance_blast if d.blast else config.dismember_chance
	if config.enabled and _rng.randf() < chance:
		hide = LIMB_GROUPS[_rng.randi() % LIMB_GROUPS.size()]
	var tint: Color = d.tint
	if d.burned:
		tint = Color(tint.r * config.charred_tint, tint.g * config.charred_tint, tint.b * config.charred_tint)
	# Blasts throw the body backwards, away from the centre: face the blast, play death_blown, slide.
	var facing: Vector2 = -d.push if d.blast else d.heading
	var i: int = _add(d.position, facing, d.variant, tint, 1 if d.blast else 0, hide, 0.0)
	if d.blast:
		_start_slide(i, d.push)
	if hide != 0:
		_add_limb(d, tint, hide)
	return hide


func _start_slide(i: int, push: Vector2) -> void:
	var dist: float = _rng.randf_range(config.blast_slide.x, config.blast_slide.y)
	if grid != null:
		var free: float = grid.ray_distance(_pos[i], push, dist + WALL_GAP)
		if free < dist + WALL_GAP:
			dist = maxf(free - WALL_GAP, 0.0)
	if dist <= 0.01 or config.blast_slide_sec <= 0.0:
		return
	_from[i] = _pos[i]
	_to[i] = _pos[i] + push * dist
	_slide_t[i] = 0.0


func _add_limb(d: Horde.Death, tint: Color, hide: int) -> void:
	var shown: int = ALL_PARTS & ~hide
	if not is_inside_tree() or config.limb_body_cap <= 0:
		# No physics here: lay the limb down a little way along the push.
		var perp: Vector2 = Vector2(-d.push.y, d.push.x)
		var p: Vector2 = d.position + d.push * _rng.randf_range(config.limb_throw.x, config.limb_throw.y) \
			+ perp * _rng.randf_range(-0.4, 0.4)
		var yaw: float = _rng.randf() * TAU
		var j: int = _add(p, Vector2(sin(yaw), cos(yaw)), d.variant, tint, 0, shown, 0.0)
		_pose_t[j] = LIMB_REST_T
		return
	# The limb starts where it was on the standing body (death clip, first frame) and flies.
	var i: int = _add(d.position, d.heading, d.variant, tint, 0, shown, 0.0)
	_pose_t[i] = 0.0
	var model: VatModel = models[d.variant % models.size()]
	var box: AABB = model.part_bounds(hide, _death_rows[d.variant % models.size()][0])
	var slot: Transform3D = _yaw_transform(_pos[i], _head[i], ground_y)
	_pivot[i] = box.get_center()
	var body: RigidBody3D = RigidBody3D.new()
	body.mass = 1.5
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = box.size.max(Vector3(0.08, 0.08, 0.08))
	shape.shape = box_shape
	body.add_child(shape)
	_ensure_floor()
	add_child(body)
	body.global_transform = Transform3D(slot.basis, slot * _pivot[i])
	var speed: float = _rng.randf_range(config.limb_speed.x, config.limb_speed.y)
	body.linear_velocity = Vector3(d.push.x * speed, _rng.randf_range(config.limb_lift.x, config.limb_lift.y), d.push.y * speed)
	body.angular_velocity = Vector3(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
	_body[i] = body
	_body_age[i] = 0.0
	_free_xf[i] = 1
	_xf[i] = slot
	_body_order.append(i)
	while _body_order.size() > config.limb_body_cap:
		_retire_body(_body_order[0])


## Stops a limb's rigid body: the slot keeps its last pose as an ordinary (sinking) corpse part.
func _retire_body(i: int) -> void:
	var body: RigidBody3D = _body[i]
	if body == null:
		return
	_xf[i] = body.global_transform * Transform3D(Basis(), -_pivot[i])
	body.queue_free()
	_body[i] = null
	var k: int = _body_order.find(i)
	if k >= 0:
		_body_order.remove_at(k)
	if _xf[i].origin.y < ground_y - 0.5:  # fell off the roof
		_in_water[i] = 1
		_t[i] = 0.0
		if water_y > -INF:
			_xf[i].origin.y = water_y


func _add(p: Vector2, facing: Vector2, look: int, tint: Color, clip: int, hide: int, t: float) -> int:
	var i: int = _next
	_next = (_next + 1) % _cap
	# The slot a tenth of the ring ahead starts sinking now, so a full buffer never pops a corpse.
	var ahead: int = (i + maxi(_cap / 10, 1)) % _cap
	if _alive[ahead] != 0 and _sink[ahead] < 0.0:
		_sink[ahead] = 0.0
	if _body[i] != null:
		_body[i].queue_free()
		_body[i] = null
		_body_order.remove_at(_body_order.find(i))
	var water: bool = _is_water(p)
	_alive[i] = 1
	_pos[i] = p
	_head[i] = facing.normalized() if facing.length_squared() > 0.0001 else Vector2(0, 1)
	_y[i] = water_y if water and water_y > -INF else ground_y
	_variant[i] = look
	_tint[i] = tint
	_clip[i] = clip
	_t[i] = t
	_pose_t[i] = -1.0
	_hide[i] = hide
	_in_water[i] = 1 if water else 0
	_sink[i] = -1.0
	_slide_t[i] = -1.0
	_free_xf[i] = 0
	return i


func _is_water(p: Vector2) -> bool:
	return grid != null and not grid.in_bounds(grid.world_to_cell(p))


func _process(delta: float) -> void:
	if _layers.is_empty():
		return
	# Same clamp as the horde: a background browser tab resumes with a multi-second delta,
	# which would sink every corpse at once.
	delta = minf(delta, 1.0 / 20.0)
	for i: int in _cap:
		if _alive[i] == 0:
			continue
		if _body[i] != null:
			_body_age[i] += delta
			var lost: float = (water_y if water_y > -INF else ground_y - 30.0)
			if _body_age[i] >= config.limb_body_sec or _body[i].global_position.y < lost:
				_retire_body(i)
			else:
				_xf[i] = _body[i].global_transform * Transform3D(Basis(), -_pivot[i])
				continue  # a flying limb doesn't age toward sinking
		if _slide_t[i] >= 0.0:
			_slide_t[i] += delta
			var k: float = minf(_slide_t[i] / config.blast_slide_sec, 1.0)
			_pos[i] = _from[i].lerp(_to[i], 1.0 - (1.0 - k) * (1.0 - k))
			if k >= 1.0:
				_slide_t[i] = -1.0
				if _is_water(_pos[i]):
					_in_water[i] = 1
					_t[i] = 0.0
					if water_y > -INF:
						_y[i] = water_y
		_t[i] += delta
		if _sink[i] < 0.0:
			var life: float = config.water_float_sec if _in_water[i] != 0 else config.corpse_life_sec
			if _t[i] >= life:
				_sink[i] = 0.0
		else:
			_sink[i] += delta
			if _sink[i] >= config.sink_sec:
				_alive[i] = 0
				if _body[i] != null:
					_retire_body(i)
	for v: int in _layers.size():
		_sync_look(v)


func _yaw_transform(p: Vector2, head: Vector2, y: float) -> Transform3D:
	var c: float = head.y
	var s: float = head.x
	return Transform3D(Basis(Vector3(c, 0.0, -s), Vector3.UP, Vector3(s, 0.0, c)), Vector3(p.x, y, p.y))


func _sync_look(v: int) -> void:
	var buf: PackedFloat32Array = _buffers[v]
	_buffers[v] = PackedFloat32Array()  # drop the shared reference so writes don't copy
	var clips: VatClips = models[v].clips
	var rows_of: PackedInt32Array = _death_rows[v]
	var n: int = 0
	for i: int in _cap:
		if _alive[i] == 0 or _variant[i] != v:
			continue
		var o: int = n * FLOATS_PER_INSTANCE
		n += 1
		var sink: float = 0.0 if _sink[i] < 0.0 else config.sink_depth * _sink[i] / config.sink_sec
		var xf: Transform3D
		if _free_xf[i] != 0:
			xf = _xf[i]
		else:
			var y: float = _y[i]
			if _slide_t[i] >= 0.0:
				var k: float = minf(_slide_t[i] / config.blast_slide_sec, 1.0)
				y += 4.0 * config.blast_arc_height * k * (1.0 - k)
			xf = _yaw_transform(_pos[i], _head[i], y)
		var b: Basis = xf.basis
		buf[o] = b.x.x
		buf[o + 1] = b.y.x
		buf[o + 2] = b.z.x
		buf[o + 3] = xf.origin.x
		buf[o + 4] = b.x.y
		buf[o + 5] = b.y.y
		buf[o + 6] = b.z.y
		buf[o + 7] = xf.origin.y - sink
		buf[o + 8] = b.x.z
		buf[o + 9] = b.y.z
		buf[o + 10] = b.z.z
		buf[o + 11] = xf.origin.z
		var t: Color = _tint[i]
		buf[o + 12] = t.r
		buf[o + 13] = t.g
		buf[o + 14] = t.b
		buf[o + 15] = 1.0
		var rows: Vector3 = clips.rows_at(rows_of[_clip[i]], _pose_t[i] if _pose_t[i] >= 0.0 else _t[i])
		buf[o + 16] = rows.x
		buf[o + 17] = rows.y
		buf[o + 18] = rows.z
		buf[o + 19] = float(_hide[i])
	_buffers[v] = buf
	var mm: MultiMesh = _layers[v].multimesh
	mm.buffer = buf
	mm.visible_instance_count = n


## Roof slab + blocked cells as static collision for flying limbs; built on the first limb.
func _ensure_floor() -> void:
	if _floor != null:
		return
	_floor = StaticBody3D.new()
	add_child(_floor)
	var size: Vector2 = grid.world_size() if grid != null else Vector2(400, 400)
	var origin: Vector2 = grid.origin if grid != null else -size * 0.5
	_add_box(Vector3(origin.x + size.x * 0.5, ground_y - 0.5, origin.y + size.y * 0.5), Vector3(size.x, 1.0, size.y))
	if grid == null:
		return
	# One box per run of blocked cells in a row keeps the shape count low.
	for y: int in grid.height:
		var x: int = 0
		while x < grid.width:
			if grid.is_walkable(Vector2i(x, y)):
				x += 1
				continue
			var x0: int = x
			while x < grid.width and not grid.is_walkable(Vector2i(x, y)):
				x += 1
			var lo: Vector2 = grid.origin + Vector2(x0, y) * grid.cell_size
			var run: Vector2 = Vector2(x - x0, 1) * grid.cell_size
			_add_box(Vector3(lo.x + run.x * 0.5, ground_y + OBSTACLE_HEIGHT * 0.5, lo.y + run.y * 0.5),
				Vector3(run.x, OBSTACLE_HEIGHT, run.y))


func _add_box(center: Vector3, size: Vector3) -> void:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	_floor.add_child(shape)
