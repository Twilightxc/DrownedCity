class_name CorpseLayer
extends Node3D
## Corpses and severed limbs (GDD §6, PHASE0 0.7): a capped ring buffer drawn with one MultiMesh per
## zombie look, playing the VAT death clip once and then holding its last frame (no ragdoll).
## Old corpses sink through the floor to make room; corpses in water float a while, then sink.
## A severed limb is the same mesh with every other part hidden, thrown along the push.

const FLOATS_PER_INSTANCE: int = 20
const VAT_SHADER: Shader = preload("res://game/shaders/horde_vat.gdshader")
const ALL_PARTS: int = (1 << 11) - 1  # kit_zombie SKELETON order
## Severable groups as part bitmasks: head, left arm, right forearm, left shin, right leg.
const LIMB_GROUPS: PackedInt32Array = [1 << 2, (1 << 3) | (1 << 4), 1 << 6, 1 << 8, (1 << 9) | (1 << 10)]

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
var _t: PackedFloat32Array  ## s since death
var _hide: PackedInt32Array
var _in_water: PackedByteArray
var _sink: PackedFloat32Array  ## s sinking, < 0 = not yet
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _layers: Array[MultiMeshInstance3D] = []
var _buffers: Array[PackedFloat32Array] = []
var _death_rows: Array[PackedInt32Array] = []  ## per look: [death, death_blown] clip index


func setup(p_config: GoreConfig, p_models: Array[VatModel]) -> void:
	config = p_config
	models = p_models
	_cap = config.corpse_cap
	_alive.resize(_cap)
	_pos.resize(_cap)
	_head.resize(_cap)
	_y.resize(_cap)
	_variant.resize(_cap)
	_tint.resize(_cap)
	_clip.resize(_cap)
	_t.resize(_cap)
	_hide.resize(_cap)
	_in_water.resize(_cap)
	_sink.resize(_cap)
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


func live_count() -> int:
	return _alive.count(1)


## A zombie died: lay its corpse (maybe dismembered) and return the severed group mask (0 = whole).
func add_death(d: Horde.Death) -> int:
	var hide: int = 0
	var chance: float = config.dismember_chance_blast if d.blast else config.dismember_chance
	if config.enabled and _rng.randf() < chance:
		hide = LIMB_GROUPS[_rng.randi() % LIMB_GROUPS.size()]
	# Blasts throw the body backwards, away from the centre: face the blast, play death_blown.
	var facing: Vector2 = -d.push if d.blast else d.heading
	_add(d.position, facing, d.variant, d.tint, 1 if d.blast else 0, hide, 0.0)
	if hide != 0:
		var perp: Vector2 = Vector2(-d.push.y, d.push.x)
		var p: Vector2 = d.position + d.push * _rng.randf_range(config.limb_throw.x, config.limb_throw.y) \
			+ perp * _rng.randf_range(-0.4, 0.4)
		var yaw: float = _rng.randf() * TAU
		_add(p, Vector2(sin(yaw), cos(yaw)), d.variant, d.tint, 0, ALL_PARTS & ~hide, 99.0)
	return hide


func _add(p: Vector2, facing: Vector2, look: int, tint: Color, clip: int, hide: int, t: float) -> void:
	var i: int = _next
	_next = (_next + 1) % _cap
	# The slot a tenth of the ring ahead starts sinking now, so a full buffer never pops a corpse.
	var ahead: int = (i + maxi(_cap / 10, 1)) % _cap
	if _alive[ahead] != 0 and _sink[ahead] < 0.0:
		_sink[ahead] = 0.0
	var water: bool = grid != null and not grid.in_bounds(grid.world_to_cell(p))
	_alive[i] = 1
	_pos[i] = p
	_head[i] = facing.normalized() if facing.length_squared() > 0.0001 else Vector2(0, 1)
	_y[i] = water_y if water and water_y > -INF else ground_y
	_variant[i] = look
	_tint[i] = tint
	_clip[i] = clip
	_t[i] = t
	_hide[i] = hide
	_in_water[i] = 1 if water else 0
	_sink[i] = -1.0


func _process(delta: float) -> void:
	if _layers.is_empty():
		return
	# Same clamp as the horde: a background browser tab resumes with a multi-second delta,
	# which would sink every corpse at once.
	delta = minf(delta, 1.0 / 20.0)
	for i: int in _cap:
		if _alive[i] == 0:
			continue
		_t[i] += delta
		if _sink[i] < 0.0:
			var life: float = config.water_float_sec if _in_water[i] != 0 else config.corpse_life_sec
			if _t[i] >= life:
				_sink[i] = 0.0
		else:
			_sink[i] += delta
			if _sink[i] >= config.sink_sec:
				_alive[i] = 0
	for v: int in _layers.size():
		_sync_look(v)


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
		var c: float = _head[i].y
		var s: float = _head[i].x
		var sink: float = 0.0 if _sink[i] < 0.0 else config.sink_depth * _sink[i] / config.sink_sec
		buf[o] = c
		buf[o + 1] = 0.0
		buf[o + 2] = s
		buf[o + 3] = _pos[i].x
		buf[o + 4] = 0.0
		buf[o + 5] = 1.0
		buf[o + 6] = 0.0
		buf[o + 7] = _y[i] - sink
		buf[o + 8] = -s
		buf[o + 9] = 0.0
		buf[o + 10] = c
		buf[o + 11] = _pos[i].y
		var t: Color = _tint[i]
		buf[o + 12] = t.r
		buf[o + 13] = t.g
		buf[o + 14] = t.b
		buf[o + 15] = 1.0
		var rows: Vector3 = clips.rows_at(rows_of[_clip[i]], _t[i])
		buf[o + 16] = rows.x
		buf[o + 17] = rows.y
		buf[o + 18] = rows.z
		buf[o + 19] = float(_hide[i])
	_buffers[v] = buf
	var mm: MultiMesh = _layers[v].multimesh
	mm.buffer = buf
	mm.visible_instance_count = n
