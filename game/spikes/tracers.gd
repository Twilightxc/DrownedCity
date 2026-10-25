class_name Tracers
extends MeshInstance3D
## Short-lived bullet lines, all in one ImmediateMesh (one draw call).

@export var lifetime: float = 0.06
@export var color: Color = Color(1.0, 0.85, 0.4)

var _from: PackedVector3Array = PackedVector3Array()
var _to: PackedVector3Array = PackedVector3Array()
var _age: PackedFloat32Array = PackedFloat32Array()
var _im: ImmediateMesh = ImmediateMesh.new()


func _ready() -> void:
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	material_override = mat


func add(from: Vector3, to: Vector3) -> void:
	_from.append(from)
	_to.append(to)
	_age.append(0.0)


func _process(delta: float) -> void:
	var i: int = _age.size() - 1
	while i >= 0:
		_age[i] += delta
		if _age[i] > lifetime:
			_from.remove_at(i)
			_to.remove_at(i)
			_age.remove_at(i)
		i -= 1
	_im.clear_surfaces()
	if _from.is_empty():
		return
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	for j: int in _from.size():
		_im.surface_add_vertex(_from[j])
		_im.surface_add_vertex(_to[j])
	_im.surface_end()
