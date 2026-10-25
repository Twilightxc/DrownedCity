class_name IsoCameraRig
extends Node3D
## Isometric orthographic camera. The rig yaws (90° steps later in 0.5); the child camera
## sits at a fixed true-isometric pitch looking at the rig origin.

const ISO_PITCH_DEG: float = -35.264

@export var distance: float = 30.0
@export var ortho_size: float = 24.0
@export_range(0.0, 360.0, 90.0) var yaw_deg: float = 45.0

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = ortho_size
	_camera.rotation_degrees = Vector3(ISO_PITCH_DEG, 0.0, 0.0)
	_camera.position = _camera.basis.z * distance
