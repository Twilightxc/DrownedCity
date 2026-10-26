class_name SupplyCrate
extends Node3D
## Interact target for the 0.5 spike: walk up, press interact, grenades refill. Doesn't block
## the NavGrid (spike placeholder). Shows a device-specific prompt while the player is in range.

const RESTOCKED_TIME: float = 1.2

@export var size: Vector3 = Vector3(0.9, 0.55, 0.6)
@export var color: Color = Color(0.45, 0.5, 0.25)  # olive military crate

var _label: Label3D
var _restocked_left: float = 0.0


func _ready() -> void:
	add_to_group("interactable")
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	box.material = mat
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = box
	mi.position.y = size.y * 0.5
	add_child(mi)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.002
	_label.font_size = 24
	_label.outline_size = 6
	_label.position.y = size.y + 0.6
	_label.visible = false
	add_child(_label)


func _process(delta: float) -> void:
	if _restocked_left > 0.0:
		_restocked_left -= delta


func show_prompt(on: bool, pad: bool) -> void:
	_label.visible = on
	if _restocked_left > 0.0:
		_label.text = "Restocked"
	else:
		_label.text = "(A) Restock grenades" if pad else "[F] Restock grenades"


func interact(player: SpikePlayer) -> void:
	player.restock()
	_restocked_left = RESTOCKED_TIME
