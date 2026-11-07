class_name BaseFire
extends Node3D
## A fire in the base (1.7 step 3): the kitchen's campfire or stove, an oil drum at night. Lit, it shows a few
## flickering flame billboards (FireFx's soft additive flame), sparks drifting up and a warm flickering light with no
## shadow, so the base glows after dark. Out, nothing but the model's embers. ≤ 4 fires light the roof at once.

const LIGHT_COLOR: Color = Color(1.0, 0.62, 0.3)
const FADE_RATE: float = 1.5  ## 1/s the fire catches or dies

var size: float = 1.0
var lit: bool = false
var _amount: float = 0.0
var _flames: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _sparks: CPUParticles3D
var _t: float = 0.0


func _init(p_size: float = 1.0) -> void:
	size = p_size


func _ready() -> void:
	_t = randf() * 10.0
	var mat: StandardMaterial3D = FireFx.flame_material(true)
	mat.albedo_color = Color(1.0, 0.55, 0.15, 0.9)
	for k: int in 4:
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.32, 0.6) * size * (1.0 if k < 2 else 0.7)
		quad.center_offset = Vector3(0.0, quad.size.y * 0.5, 0.0)
		quad.surface_set_material(0, mat)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(k * 2.4) * 0.08, 0.0, sin(k * 2.4) * 0.08) * size
		add_child(mi)
		_flames.append(mi)
	_light = OmniLight3D.new()
	_light.light_color = LIGHT_COLOR
	_light.omni_range = 4.0 + 3.0 * size
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 0.5 * size, 0.0)
	add_child(_light)
	_sparks = CPUParticles3D.new()
	_sparks.amount = 10
	_sparks.lifetime = 1.4
	_sparks.local_coords = false
	var spark: QuadMesh = QuadMesh.new()
	spark.size = Vector2(0.035, 0.035)
	var spark_mat: StandardMaterial3D = FireFx.flame_material(true)
	spark_mat.albedo_color = Color(1.0, 0.7, 0.3, 1.0)
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark.surface_set_material(0, spark_mat)
	_sparks.mesh = spark
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 0.12 * size
	_sparks.direction = Vector3.UP
	_sparks.spread = 25.0
	_sparks.gravity = Vector3(0.0, 0.6, 0.0)
	_sparks.initial_velocity_min = 0.4
	_sparks.initial_velocity_max = 1.0
	_sparks.scale_amount_min = 0.6
	_sparks.scale_amount_max = 1.4
	add_child(_sparks)
	_apply(0.0)


func _process(delta: float) -> void:
	_t += delta
	_amount = move_toward(_amount, 1.0 if lit else 0.0, delta * FADE_RATE)
	_apply(_amount)


func _apply(a: float) -> void:
	var on: bool = a > 0.01
	for k: int in _flames.size():
		var f: MeshInstance3D = _flames[k]
		f.visible = on
		var flick: float = 0.75 + 0.25 * sin(_t * (7.0 + k * 1.7) + k) + 0.12 * sin(_t * 17.0 + k * 3.0)
		f.scale = Vector3(1.0, flick, 1.0) * a
	_light.visible = on
	_light.light_energy = a * (1.3 + 0.25 * sin(_t * 9.0) + 0.15 * sin(_t * 23.0)) * size
	_sparks.emitting = on and a > 0.5
