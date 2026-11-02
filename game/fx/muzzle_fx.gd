class_name MuzzleFx
extends Node3D
## Muzzle flash (Phase 1 step 1.4): one additive flame billboard and one shadowless omni light at the
## muzzle, shown for a couple of frames per shot. One node for the player, reused.

const FLASH_SEC: float = 0.05

var _quad: MeshInstance3D
var _light: OmniLight3D
var _left: float = 0.0
var _energy: float = 1.6


func _ready() -> void:
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(0.45, 0.45)
	var mat: StandardMaterial3D = FireFx.flame_material(true)
	mat.albedo_color = Color(1.0, 0.82, 0.45, 1.0)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.surface_set_material(0, mat)
	_quad = MeshInstance3D.new()
	_quad.mesh = mesh
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.visible = false
	add_child(_quad)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.75, 0.4)
	_light.omni_range = 5.0
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)


## A flash at `at` (world); `size` scales the flame (shotguns flash bigger).
func flash(at: Vector3, size: float, light_energy: float) -> void:
	_quad.global_position = at
	_quad.scale = Vector3.ONE * size * randf_range(0.8, 1.2)
	_quad.rotation.z = randf() * TAU
	_light.global_position = at
	_energy = light_energy
	_light.light_energy = light_energy
	_quad.visible = true
	_light.visible = light_energy > 0.0
	_left = FLASH_SEC


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		_quad.visible = false
		_light.visible = false
	else:
		_light.light_energy = _energy * _left / FLASH_SEC
