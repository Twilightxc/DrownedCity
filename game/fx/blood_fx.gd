class_name BloodFx
extends Node3D
## Blood (GDD §6): short droplet bursts along the bullet and flat pools on the floor, each a capped
## ring buffer drawn with one MultiMesh. Flat Style 1.5 colour, no decals (Compatibility has none).
## Pools grow in, then shrink away at the end of their life; the oldest is reused when full.

const POOL_SIDES: int = 9
const BURST_HEIGHT: float = 1.1  ## m, chest height where bullets hit
const POOL_LIFT: float = 0.06  ## m above the walk plane: the roof slab mesh sits a few cm above it

var config: GoreConfig
var ground_y: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _drops: MultiMeshInstance3D
var _drop_pos: PackedVector3Array
var _drop_vel: PackedVector3Array
var _drop_life: PackedFloat32Array
var _drop_next: int = 0

var _pools: MultiMeshInstance3D
var _pool_pos: PackedVector3Array
var _pool_size: PackedFloat32Array
var _pool_yaw: PackedFloat32Array
var _pool_age: PackedFloat32Array  ## < 0 = free
var _pool_next: int = 0


func setup(p_config: GoreConfig) -> void:
	config = p_config
	_rng.randomize()
	var drop_mesh: BoxMesh = BoxMesh.new()
	drop_mesh.size = Vector3(0.06, 0.06, 0.06)
	_drops = _make_layer(drop_mesh, config.zombie_blood, config.droplet_cap, true)
	_drop_pos.resize(config.droplet_cap)
	_drop_vel.resize(config.droplet_cap)
	_drop_life.resize(config.droplet_cap)
	_pools = _make_layer(_pool_mesh(), config.zombie_pool, config.pool_cap, false)
	_pool_pos.resize(config.pool_cap)
	_pool_size.resize(config.pool_cap)
	_pool_yaw.resize(config.pool_cap)
	_pool_age.resize(config.pool_cap)
	_pool_age.fill(-1.0)


## Bullet or blast hit at floor point `p`, travelling along `dir`.
func hit(p: Vector2, dir: Vector2) -> void:
	if not config.enabled:
		return
	for k: int in config.droplets_per_hit:
		var i: int = _drop_next
		_drop_next = (_drop_next + 1) % config.droplet_cap
		var spread: Vector2 = dir.rotated(_rng.randf_range(-0.6, 0.6)) * _rng.randf_range(config.droplet_speed.x, config.droplet_speed.y)
		_drop_pos[i] = Vector3(p.x, ground_y + BURST_HEIGHT + _rng.randf_range(-0.2, 0.2), p.y)
		_drop_vel[i] = Vector3(spread.x, _rng.randf_range(0.3, 2.2), spread.y)
		_drop_life[i] = config.droplet_life * _rng.randf_range(0.6, 1.0)
	if _rng.randf() < config.pool_on_hit_chance:
		var at: Vector2 = p + dir * _rng.randf_range(0.3, 1.0)
		pool(at, _rng.randf_range(config.hit_pool_size.x, config.hit_pool_size.y))


func pool(p: Vector2, size: float) -> void:
	if not config.enabled:
		return
	var i: int = _pool_next
	_pool_next = (_pool_next + 1) % config.pool_cap
	# Tiny height steps keep overlapping pools from z-fighting.
	_pool_pos[i] = Vector3(p.x, ground_y + POOL_LIFT + 0.003 * (i % 5), p.y)
	_pool_size[i] = size
	_pool_yaw[i] = _rng.randf() * TAU
	_pool_age[i] = 0.0


func pool_count() -> int:
	return _pools.multimesh.visible_instance_count if _pools != null else 0


func clear() -> void:
	_drop_life.fill(0.0)
	_pool_age.fill(-1.0)


func _process(delta: float) -> void:
	if config == null:
		return
	delta = minf(delta, 1.0 / 20.0)  # a resumed background tab must not age every pool at once
	_update_drops(delta)
	_update_pools(delta)


func _update_drops(delta: float) -> void:
	var mm: MultiMesh = _drops.multimesh
	var n: int = 0
	var g: Vector3 = Vector3(0, -9.8, 0)
	for i: int in config.droplet_cap:
		if _drop_life[i] <= 0.0:
			continue
		_drop_life[i] -= delta
		_drop_vel[i] += g * delta
		_drop_pos[i] += _drop_vel[i] * delta
		if _drop_pos[i].y <= ground_y:
			_drop_life[i] = 0.0
			continue
		mm.set_instance_transform(n, Transform3D(Basis(), _drop_pos[i]))
		n += 1
	mm.visible_instance_count = n


func _update_pools(delta: float) -> void:
	var mm: MultiMesh = _pools.multimesh
	var n: int = 0
	var fade: float = 3.0
	for i: int in config.pool_cap:
		if _pool_age[i] < 0.0:
			continue
		_pool_age[i] += delta
		var age: float = _pool_age[i]
		if age >= config.pool_life_sec:
			_pool_age[i] = -1.0
			continue
		var k: float = minf(age / config.pool_grow_sec, 1.0)
		k = 1.0 - (1.0 - k) * (1.0 - k)  # ease out: spreads fast, then slows
		k *= clampf((config.pool_life_sec - age) / fade, 0.0, 1.0)
		var s: float = maxf(_pool_size[i] * k, 0.001)
		var basis: Basis = Basis(Vector3.UP, _pool_yaw[i]).scaled(Vector3(s, 1.0, s * 0.8))
		mm.set_instance_transform(n, Transform3D(basis, _pool_pos[i]))
		n += 1
	mm.visible_instance_count = n


func _make_layer(mesh: Mesh, color: Color, cap: int, shadows: bool) -> MultiMeshInstance3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.35  # a little wet sheen
	mesh.surface_set_material(0, mat)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var layer: MultiMeshInstance3D = MultiMeshInstance3D.new()
	layer.multimesh = mm
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.custom_aabb = AABB(Vector3(-500, -20, -500), Vector3(1000, 40, 1000))
	add_child(layer)
	return layer


## Irregular flat blob, 1 m across, facing up.
func _pool_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: PackedVector3Array = PackedVector3Array()
	for k: int in POOL_SIDES:
		var a: float = k * TAU / POOL_SIDES
		var r: float = 0.5 * (0.75 + 0.25 * sin(a * 3.0 + 0.7))
		rim.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	for k: int in POOL_SIDES:
		for v: Vector3 in [Vector3.ZERO, rim[k], rim[(k + 1) % POOL_SIDES]]:  # clockwise from above = front
			st.set_normal(Vector3.UP)  # applies to the next vertex only
			st.add_vertex(v)
	return st.commit()
