class_name TwinStickConfig
extends Resource
## Player control feel tunables. Instances live in data/input/*.tres; the F4 tuning panel edits
## the loaded instance at runtime (not saved).

@export_group("Movement")
@export var move_speed: float = 4.5  ## m/s
@export var move_accel: float = 40.0  ## m/s², 0 → full speed in move_speed / move_accel s
@export var move_decel: float = 60.0  ## m/s² when the stick/keys are released
@export var stick_deadzone: float = 0.25  ## radial, both sticks

@export_group("Aim")
## Height above the floor of the plane the mouse ray hits. Body height, so the cursor on a
## zombie's torso aims at that zombie (the floor plane would aim behind it in iso view).
@export var aim_plane_height: float = 0.9
@export var aim_line: bool = true
@export var pad_auto_fire: bool = false  ## fire while the right stick is pushed past auto_fire_threshold
@export var auto_fire_threshold: float = 0.85

@export_group("Aim assist (gamepad only)")
@export var aim_assist: bool = true
@export var aim_assist_cone_deg: float = 12.0  ## ± around the stick direction
@export var aim_assist_range: float = 18.0  ## m
@export_range(0.0, 1.0) var aim_assist_strength: float = 0.6  ## fraction of the angle bent toward the target

@export_group("Throw")
@export var pad_throw_range: float = 8.0  ## m, when no assist target is in range

@export_group("Interact")
@export var interact_radius: float = 1.5  ## m

@export_group("Radial menu")
@export_range(0.05, 1.0) var radial_time_scale: float = 0.4  ## game speed while the wheel is open
