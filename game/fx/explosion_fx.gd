class_name ExplosionFx
extends Node3D
## Blast effects (GDD §6, PHASE0 0.7): one short flash light; a fireball, hot shrapnel streaks, debris,
## a black soot column, lingering grey smoke and a ground dust ring from small pools of CPU particle
## emitters; scorch marks and burning embers stuck on the floor (one MultiMesh each, ring buffers);
## a water column when the blast lands in water. Web budget: one light, a handful of emitters
## (hidden once finished, so idle ones cost no draw call), nothing per blast node.

const EMITTERS: int = 3  ## per kind; a fourth blast in a row restarts the oldest
const SCORCH_CAP: int = 24
const SCORCH_LIFE: float = 40.0
const EMBER_CAP: int = 64
const EMBER_LIFE: Vector2 = Vector2(4.0, 8.0)  ## s, random per ember
const FLASH_SEC: float = 0.18
const FLASH_ENERGY: float = 6.0

var ground_y: float = 0.0
var water_y: float = -INF
var grid: NavGrid  ## optional: embers only land on walkable cells

var _light: OmniLight3D
var _flash_left: float = 0.0
var _debris: Array[CPUParticles3D] = []
var _shrapnel: Array[CPUParticles3D] = []
var _fireball: Array[CPUParticles3D] = []
var _soot: Array[CPUParticles3D] = []
var _smoke: Array[CPUParticles3D] = []
var _dust: Array[CPUParticles3D] = []
var _splash: Array[CPUParticles3D] = []
var _next: int = 0
var _scorch: MultiMeshInstance3D
var _scorch_pos: PackedVector3Array
var _scorch_size: PackedFloat32Array
var _scorch_age: PackedFloat32Array  ## < 0 = free
var _scorch_next: int = 0
var _embers: MultiMeshInstance3D
var _ember_pos: PackedVector3Array
var _ember_life: PackedFloat32Array
var _ember_age: PackedFloat32Array  ## < 0 = free
var _ember_next: int = 0
var _time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.7, 0.35)
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	for k: int in EMITTERS:
		_debris.append(_make_debris())
		_shrapnel.append(_make_shrapnel())
		_fireball.append(_make_fireball())
		_soot.append(_make_soot())
		_smoke.append(_make_smoke())
		_dust.append(_make_dust())
		_splash.append(_make_splash())
	_scorch_pos.resize(SCORCH_CAP)
	_scorch_size.resize(SCORCH_CAP)
	_scorch_age.resize(SCORCH_CAP)
	_scorch_age.fill(-1.0)
	_scorch = _make_scorch_layer()
	_ember_pos.resize(EMBER_CAP)
	_ember_life.resize(EMBER_CAP)
	_ember_age.resize(EMBER_CAP)
	_ember_age.fill(-1.0)
	_embers = _make_ember_layer()


## A blast at `at` (floor point), `radius` m. `in_water` = it landed off the roof. `embers` burning
## flecks stay on the floor (frag); `shrapnel` adds hot fragment streaks; `incendiary` swells the fireball.
func blast(at: Vector3, radius: float, in_water: bool, embers: int = 0, shrapnel: bool = true, incendiary: bool = false) -> void:
	_light.position = at + Vector3(0, 1.2, 0)
	_light.omni_range = radius * 3.0
	_light.light_energy = FLASH_ENERGY
	_light.visible = true
	_flash_left = FLASH_SEC * (1.8 if incendiary else 1.0)
	var k: int = _next
	_next = (_next + 1) % EMITTERS
	if in_water:
		var y: float = water_y if water_y > -INF else at.y
		_fire_emitter(_splash[k], Vector3(at.x, y, at.z))
		return
	var ball: CPUParticles3D = _fireball[k]
	ball.scale_amount_min = 1.6 if incendiary else 0.8
	ball.scale_amount_max = 2.8 if incendiary else 1.5
	_fire_emitter(ball, at + Vector3(0, 0.6, 0))
	if shrapnel:
		_fire_emitter(_shrapnel[k], at + Vector3(0, 0.4, 0))
	_fire_emitter(_debris[k], at + Vector3(0, 0.3, 0))
	_fire_emitter(_soot[k], at + Vector3(0, 0.8, 0))
	_fire_emitter(_smoke[k], at + Vector3(0, 0.5, 0))
	_fire_emitter(_dust[k], at + Vector3(0, 0.15, 0))
	var i: int = _scorch_next
	_scorch_next = (_scorch_next + 1) % SCORCH_CAP
	_scorch_pos[i] = Vector3(at.x, ground_y + 0.045 + 0.002 * (i % 4), at.z)
	_scorch_size[i] = radius * _rng.randf_range(0.7, 0.9)
	_scorch_age[i] = 0.0
	_scatter_embers(Vector2(at.x, at.z), radius * 0.85, embers)


## First use of the light, emitters, scorch and embers compiles their shaders (a long hitch on the
## web). Call once at load with a floor point the camera sees: everything fires invisibly small.
func warm_up(at: Vector3) -> void:
	var saved: NavGrid = grid
	grid = null  # the warm-up point is under the floor; embers must land anyway
	blast(at, 3.0, false, 1, true)
	grid = saved
	_light.light_energy = 0.01
	var k: int = (_next + EMITTERS - 1) % EMITTERS
	_fire_emitter(_splash[k], at)
	_scorch_age[(_scorch_next + SCORCH_CAP - 1) % SCORCH_CAP] = SCORCH_LIFE - 0.05
	var e: int = (_ember_next + EMBER_CAP - 1) % EMBER_CAP
	_ember_age[e] = _ember_life[e] - 0.05


func scorch_count() -> int:
	return _scorch.multimesh.visible_instance_count


func ember_count() -> int:
	return _embers.multimesh.visible_instance_count


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 20.0)
	_time += delta
	if _flash_left > 0.0:
		_flash_left -= delta
		_light.light_energy = FLASH_ENERGY * maxf(_flash_left / FLASH_SEC, 0.0)
		_light.visible = _flash_left > 0.0
	var mm: MultiMesh = _scorch.multimesh
	var n: int = 0
	for i: int in SCORCH_CAP:
		if _scorch_age[i] < 0.0:
			continue
		_scorch_age[i] += delta
		if _scorch_age[i] >= SCORCH_LIFE:
			_scorch_age[i] = -1.0
			continue
		var s: float = _scorch_size[i] * clampf((SCORCH_LIFE - _scorch_age[i]) / 4.0, 0.0, 1.0)
		mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3(s, 1.0, s)), _scorch_pos[i]))
		n += 1
	mm.visible_instance_count = n
	_update_embers(delta)


func _scatter_embers(center: Vector2, radius: float, count: int) -> void:
	for c: int in count:
		var p: Vector2 = center + Vector2.from_angle(_rng.randf() * TAU) * radius * sqrt(_rng.randf())
		if grid != null and not grid.is_walkable_world(p):
			continue  # in the water or inside a wall
		var i: int = _ember_next
		_ember_next = (_ember_next + 1) % EMBER_CAP
		_ember_pos[i] = Vector3(p.x, ground_y + 0.05, p.y)
		_ember_life[i] = _rng.randf_range(EMBER_LIFE.x, EMBER_LIFE.y)
		_ember_age[i] = 0.0


## Embers flicker and shrink out over their last second.
func _update_embers(delta: float) -> void:
	var mm: MultiMesh = _embers.multimesh
	var n: int = 0
	for i: int in EMBER_CAP:
		if _ember_age[i] < 0.0:
			continue
		_ember_age[i] += delta
		var left: float = _ember_life[i] - _ember_age[i]
		if left <= 0.0:
			_ember_age[i] = -1.0
			continue
		var flicker: float = 0.75 + 0.25 * sin(_time * 19.0 + i * 2.3) * sin(_time * 7.1 + i)
		var s: float = flicker * clampf(left, 0.0, 1.0)
		mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3(s, s, s)), _ember_pos[i]))
		mm.set_instance_color(n, Color(1.0, 0.35 + 0.3 * flicker, 0.05, clampf(left, 0.0, 1.0)))
		n += 1
	mm.visible_instance_count = n


func _fire_emitter(e: CPUParticles3D, at: Vector3) -> void:
	e.position = at
	e.visible = true
	e.restart()
	e.emitting = true


func _base_emitter(amount: int, lifetime: float, mesh: Mesh, color: Color) -> CPUParticles3D:
	var e: CPUParticles3D = CPUParticles3D.new()
	e.one_shot = true
	e.emitting = false
	e.visible = false
	e.amount = amount
	e.lifetime = lifetime
	e.explosiveness = 0.95
	e.local_coords = false
	e.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, mat)
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.finished.connect(func() -> void: e.visible = false)
	add_child(e)
	return e


func _fade_ramp(from: Color, to: Color) -> Gradient:
	var g: Gradient = Gradient.new()
	g.set_color(0, from)
	g.set_color(1, to)
	return g


func _grow_curve(from: float, to: float) -> Curve:
	var c: Curve = Curve.new()
	c.max_value = maxf(to, 1.0)
	c.add_point(Vector2(0, from))
	c.add_point(Vector2(1, to))
	return c


func _puff_mesh(segments: int) -> SphereMesh:
	var puff: SphereMesh = SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = segments
	puff.rings = 3
	return puff


func _make_debris() -> CPUParticles3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.09, 0.09, 0.09)
	var e: CPUParticles3D = _base_emitter(24, 1.1, box, Color(0.22, 0.2, 0.18))
	e.direction = Vector3.UP
	e.spread = 70.0
	e.initial_velocity_min = 4.0
	e.initial_velocity_max = 9.0
	e.gravity = Vector3(0, -14, 0)
	e.angular_velocity_min = -400.0
	e.angular_velocity_max = 400.0
	e.scale_amount_min = 0.6
	e.scale_amount_max = 1.6
	return e


## Hot fragments: thin unshaded streaks along their velocity, fast and short-lived, white-hot to red.
func _make_shrapnel() -> CPUParticles3D:
	var streak: BoxMesh = BoxMesh.new()
	streak.size = Vector3(0.03, 0.42, 0.03)
	var e: CPUParticles3D = _base_emitter(40, 0.4, streak, Color(1, 1, 1))
	var mat: StandardMaterial3D = streak.surface_get_material(0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	e.particle_flag_align_y = true
	e.direction = Vector3.UP
	e.spread = 88.0
	e.initial_velocity_min = 12.0
	e.initial_velocity_max = 22.0
	e.gravity = Vector3(0, -9, 0)
	e.damping_min = 6.0
	e.damping_max = 12.0
	e.scale_amount_min = 0.6
	e.scale_amount_max = 1.3
	e.color_ramp = _fade_ramp(Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.3, 0.05, 0.0))
	return e


## The flash of the blast itself: a few additive orange puffs that swell and vanish in a third of a second.
func _make_fireball() -> CPUParticles3D:
	var puff: SphereMesh = _puff_mesh(8)
	var e: CPUParticles3D = _base_emitter(8, 0.35, puff, Color(1, 1, 1))
	var mat: StandardMaterial3D = puff.surface_get_material(0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 0.4
	e.direction = Vector3.UP
	e.spread = 180.0
	e.initial_velocity_min = 0.5
	e.initial_velocity_max = 2.0
	e.gravity = Vector3.ZERO
	e.scale_amount_curve = _grow_curve(0.5, 1.4)
	e.color_ramp = _fade_ramp(Color(1.0, 0.8, 0.35, 0.9), Color(0.9, 0.25, 0.05, 0.0))
	return e


## Black soot: dense dark puffs shooting up fast, ahead of the slower grey smoke.
func _make_soot() -> CPUParticles3D:
	var puff: SphereMesh = _puff_mesh(6)
	var e: CPUParticles3D = _base_emitter(8, 1.5, puff, Color(1, 1, 1))
	var mat: StandardMaterial3D = puff.surface_get_material(0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	e.direction = Vector3.UP
	e.spread = 18.0
	e.initial_velocity_min = 3.0
	e.initial_velocity_max = 6.0
	e.damping_min = 2.0
	e.damping_max = 3.0
	e.gravity = Vector3(0, 0.5, 0)
	e.scale_amount_min = 0.6
	e.scale_amount_max = 1.4
	e.scale_amount_curve = _grow_curve(0.5, 1.5)
	e.color_ramp = _fade_ramp(Color(0.07, 0.065, 0.06, 0.85), Color(0.12, 0.11, 0.1, 0.0))
	return e


## Low-poly puffs (flat-shaded spheres), not billboards: square quads read as grey boxes in this style.
func _make_smoke() -> CPUParticles3D:
	var puff: SphereMesh = _puff_mesh(6)
	var e: CPUParticles3D = _base_emitter(10, 3.2, puff, Color(0.36, 0.35, 0.34, 0.6))
	var mat: StandardMaterial3D = puff.surface_get_material(0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	e.direction = Vector3.UP
	e.spread = 35.0
	e.initial_velocity_min = 0.8
	e.initial_velocity_max = 2.0
	e.gravity = Vector3(0, 0.6, 0)
	e.scale_amount_min = 0.8
	e.scale_amount_max = 2.2
	e.scale_amount_curve = _grow_curve(0.4, 1.6)
	e.color_ramp = _fade_ramp(Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	return e


## The shock along the floor: a ring of tan dust puffs pushed outward and braking fast.
func _make_dust() -> CPUParticles3D:
	var puff: SphereMesh = _puff_mesh(6)
	var e: CPUParticles3D = _base_emitter(16, 1.6, puff, Color(1, 1, 1))
	var mat: StandardMaterial3D = puff.surface_get_material(0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	e.emission_ring_axis = Vector3.UP
	e.emission_ring_radius = 0.5
	e.emission_ring_inner_radius = 0.4
	e.emission_ring_height = 0.0
	e.direction = Vector3.UP
	e.spread = 10.0
	e.initial_velocity_min = 0.2
	e.initial_velocity_max = 0.6
	e.radial_accel_min = 16.0
	e.radial_accel_max = 24.0
	e.damping_min = 9.0
	e.damping_max = 12.0
	e.gravity = Vector3.ZERO
	e.scale_amount_min = 0.5
	e.scale_amount_max = 0.9
	e.scale_amount_curve = _grow_curve(0.6, 1.8)
	e.color_ramp = _fade_ramp(Color(0.55, 0.5, 0.42, 0.55), Color(0.55, 0.5, 0.42, 0.0))
	return e


func _make_splash() -> CPUParticles3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 0.12)
	var e: CPUParticles3D = _base_emitter(36, 1.3, box, Color(0.75, 0.86, 0.84))
	e.direction = Vector3.UP
	e.spread = 12.0
	e.initial_velocity_min = 5.0
	e.initial_velocity_max = 10.0
	e.gravity = Vector3(0, -12, 0)
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 0.6
	return e


func _make_scorch_layer() -> MultiMeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 10
	var rim: PackedVector3Array = PackedVector3Array()
	for k: int in sides:
		var a: float = k * TAU / sides
		var r: float = 0.5 * (0.8 + 0.2 * sin(a * 4.0 + 1.3))
		rim.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	for k: int in sides:
		for v: Vector3 in [Vector3.ZERO, rim[k], rim[(k + 1) % sides]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var mesh: ArrayMesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.075, 0.07)
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)
	return _make_layer(mesh, SCORCH_CAP, false)


## Burning flecks: small flame billboards standing on the floor, coloured per instance. Alpha blended,
## not additive: additive orange washes out to nothing on the light roof.
func _make_ember_layer() -> MultiMeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.2, 0.34)
	quad.center_offset = Vector3(0, 0.17, 0)
	var mat: StandardMaterial3D = FireFx.flame_material(false)
	mat.vertex_color_use_as_albedo = true
	quad.surface_set_material(0, mat)
	return _make_layer(quad, EMBER_CAP, true)


func _make_layer(mesh: Mesh, cap: int, colors: bool) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var layer: MultiMeshInstance3D = MultiMeshInstance3D.new()
	layer.multimesh = mm
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.custom_aabb = AABB(Vector3(-500, -20, -500), Vector3(1000, 40, 1000))
	add_child(layer)
	return layer
