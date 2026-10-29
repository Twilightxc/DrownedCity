class_name Hatch
extends Node3D
## A way in or out of a building (roof hatch, PHASE0 0.8): walk up, press interact, `used` fires.
## Same prompt behaviour as the supply crate; the building controller does the move.

signal used(player: SpikePlayer)

@export var prompt: String = "Go down"

var _label: Label3D


func _ready() -> void:
	add_to_group("interactable")
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.35
	ring.outer_radius = 0.45
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.45)
	ring.material = mat
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ring
	mi.position.y = 0.05
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.002
	_label.font_size = 24
	_label.outline_size = 6
	_label.position.y = 1.6
	_label.visible = false
	add_child(_label)


func show_prompt(on: bool, pad: bool) -> void:
	_label.visible = on
	_label.text = ("(A) " if pad else "[F] ") + tr(prompt)


func interact(player: SpikePlayer) -> void:
	used.emit(player)
