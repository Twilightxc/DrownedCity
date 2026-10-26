class_name IsoCameraRig
extends Node3D
## Isometric orthographic camera. The rig yaws in 90° steps (Q/E, shoulder buttons) and zooms
## through fixed levels (wheel, D-pad up/down); the child camera sits at a fixed true-isometric
## pitch looking at the rig origin. Player controls read the camera basis, so they stay
## camera-relative through a turn.

const ISO_PITCH_DEG: float = -35.264

@export var distance: float = 30.0
@export var ortho_size: float = 24.0
@export_range(0.0, 360.0, 90.0) var yaw_deg: float = 45.0
@export var rotate_time: float = 0.25  ## s per 90° step
@export var zoom_factors: PackedFloat32Array = PackedFloat32Array([0.7, 1.0, 1.35])  ## × ortho_size
@export var zoom_index: int = 1
@export var zoom_time: float = 0.15

var _target_yaw: float
var _rotate_tween: Tween
var _zoom_tween: Tween

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	_target_yaw = yaw_deg
	rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = ortho_size * zoom_factors[zoom_index]
	_camera.rotation_degrees = Vector3(ISO_PITCH_DEG, 0.0, 0.0)
	_camera.position = _camera.basis.z * distance


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_rotate_left"):
		rotate_step(-1)
	elif event.is_action_pressed("camera_rotate_right"):
		rotate_step(1)
	elif event.is_action_pressed("zoom_in"):
		zoom_step(-1)
	elif event.is_action_pressed("zoom_out"):
		zoom_step(1)


## Turns the view 90° per step; repeated presses queue up on the same target.
func rotate_step(dir: int) -> void:
	_target_yaw += 90.0 * dir
	if _rotate_tween != null:
		_rotate_tween.kill()
	_rotate_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_rotate_tween.tween_property(self, "rotation_degrees:y", _target_yaw, rotate_time)


func zoom_step(dir: int) -> void:
	var i: int = clampi(zoom_index + dir, 0, zoom_factors.size() - 1)
	if i == zoom_index:
		return
	zoom_index = i
	if _zoom_tween != null:
		_zoom_tween.kill()
	_zoom_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(_camera, "size", ortho_size * zoom_factors[i], zoom_time)
