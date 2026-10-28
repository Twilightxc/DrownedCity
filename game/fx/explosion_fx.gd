class_name ExplosionFx
extends Node3D
## Blast effects (GDD §6, PHASE0 0.7 part 3): one short flash light, debris and smoke from small
## pools of CPU particle emitters, a scorch mark ring buffer (one MultiMesh) and a water column when
## the blast lands in water. Web budget: one light, a handful of emitters, nothing per blast node.

const EMITTERS: int = 3  ## per kind; a fourth blast in a row restarts the oldest
const SCORCH_CAP: int = 24
const SCORCH_LIFE: float = 40.0
const FLASH_SEC: float = 0.18
const FLASH_ENERGY: float = 6.0

var ground_y: float = 0.0
var water_y: float = -INF

var _light: OmniLight3D
var _flash_left: float = 0.0
var _debris: Array[CPUParticles3D] = []
var _smoke: Array[CPUParticles3D] = []
var _splash: Array[CPUParticles3D] = []
var _next: int = 0
var _scorch: MultiMeshInstance3D
var _scorch_pos: PackedVector3Array
var _scorch_size: PackedFloat32Array
var _scorch_age: PackedFloat32Array  ## < 0 = free
var _scorch_next: int = 0
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
		_smoke.append(_make_smoke())
		_splash.append(_make_splash())
	_scorch_pos.resize(SCORCH_CAP)
	_scorch_size.resize(SCORCH_CAP)
	_scorch_age.resize(SCORCH_CAP)
	_scorch_age.fill(-1.0)
	_scorch = _make_scorch_layer()


## A blast at `at` (floor point), `radius` m. `in_water` = it landed off the roof.
func blast(at: Vector3, radius: float, in_water: bool) -> void:
	_light.position = at + Vector3(0, 1.2, 0)
	_light.omni_range = radius * 3.0
	_light.light_energy = FLASH_ENERGY
	_light.visible = true
	_flash_left = FLASH_SEC
	var k: int = _next
	_next = (_next + 1) % EMITTERS
	if in_water:
		var y: float = water_y if water_y > -INF else at.y
		_fire_emitter(_splash[k], Vector3(at.x, y, at.z))
		return
	_fire_emitter(_debris[k], at + Vector3(0, 0.3, 0))
	_fire_emitter(_smoke[k], at + Vector3(0, 0.5, 0))
	var i: int = _scorch_next
	_scorch_next = (_scorch_next + 1) % SCORCH_CAP
	_scorch_pos[i] = Vector3(at.x, ground_y + 0.045 + 0.002 * (i % 4), at.z)
	_scorch_size[i] = radius * _rng.randf_range(0.7, 0.9)
	_scorch_age[i] = 0.0


## First use of the light, emitters and scorch compiles their shaders (a long hitch on the web).
## Call once at load with a floor point the camera sees: everything fires invisibly small.
func warm_up(at: Vector3) -> void:
	blast(at, 3.0, false)
	_light.light_energy = 0.01
	var k: int = (_next + EMITTERS - 1) % EMITTERS
	_fire_emitter(_splash[k], at)
	_scorch_age[(_scorch_next + SCORCH_CAP - 1) % SCORCH_CAP] = SCORCH_LIFE - 0.05


func scorch_count() -> int:
	return _scorch.multimesh.visible_instance_count


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 20.0)
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


func _fire_emitter(e: CPUParticles3D, at: Vector3) -> void:
	e.position = at
	e.restart()
	e.emitting = true


func _base_emitter(amount: int, lifetime: float, mesh: Mesh, color: Color) -> CPUParticles3D:
	var e: CPUParticles3D = CPUParticles3D.new()
	e.one_shot = true
	e.emitting = false
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
	add_child(e)
	return e


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


## Low-poly puffs (flat-shaded spheres), not billboards: square quads read as grey boxes in this style.
func _make_smoke() -> CPUParticles3D:
	var puff: SphereMesh = SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 6
	puff.rings = 3
	var e: CPUParticles3D = _base_emitter(10, 2.2, puff, Color(0.36, 0.35, 0.34, 0.6))
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
	var grow: Curve = Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.6))
	e.scale_amount_curve = grow
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	e.color_ramp = fade
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
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = SCORCH_CAP
	mm.visible_instance_count = 0
	var layer: MultiMeshInstance3D = MultiMeshInstance3D.new()
	layer.multimesh = mm
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.custom_aabb = AABB(Vector3(-500, -20, -500), Vector3(1000, 40, 1000))
	add_child(layer)
	return layer
