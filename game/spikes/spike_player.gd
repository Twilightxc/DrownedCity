class_name SpikePlayer
extends Node3D
## Minimal twin-stick shooter for the horde spike: camera-relative move, mouse or right-stick
## aim, hitscan fire. Moves on the NavGrid like the zombies; no physics body.
## (Full feel work is spike 0.5.)

signal fired(from: Vector3, to: Vector3)

@export var move_speed: float = 4.5
@export var radius: float = 0.3
@export var weapon: WeaponConfig
@export var stick_deadzone: float = 0.3

var grid: NavGrid
var horde: Horde
var camera: Camera3D
var ground_y: float = 0.0

var aim_dir: Vector2 = Vector2(0, 1)  # world XZ
var shots_fired: int = 0

var _hitscan: Hitscan
var _hits: PackedInt32Array = PackedInt32Array()
var _cooldown: float = 0.0
var _using_pad_aim: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _aim_marker: Node3D = $AimMarker


func setup(nav: NavGrid, crowd: Horde, cam: Camera3D, y: float) -> void:
	grid = nav
	horde = crowd
	camera = cam
	ground_y = y
	_hitscan = Hitscan.new(nav)
	position.y = y


func ground_position() -> Vector2:
	return Vector2(position.x, position.z)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_using_pad_aim = false


func _process(delta: float) -> void:
	if grid == null:
		return
	_move(delta)
	_update_aim()
	_cooldown -= delta
	if Input.is_action_pressed("fire") and _cooldown <= 0.0:
		_cooldown = 1.0 / weapon.fire_rate
		_fire()


func _move(delta: float) -> void:
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input == Vector2.ZERO:
		return
	var world: Vector2 = _screen_to_world(input) * move_speed * delta
	var p: Vector2 = ground_position()
	var np: Vector2 = p
	if _can_stand(Vector2(p.x + world.x, p.y)):
		np.x += world.x
	if _can_stand(Vector2(np.x, p.y + world.y)):
		np.y += world.y
	position.x = np.x
	position.z = np.y


func _can_stand(p: Vector2) -> bool:
	for offset: Vector2 in [Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		if not grid.is_walkable_world(p + offset):
			return false
	return true


## Screen-space stick/keys (x right, y down) to world XZ using the camera's yaw.
func _screen_to_world(v: Vector2) -> Vector2:
	var right: Vector3 = camera.global_basis.x
	var down: Vector3 = camera.global_basis.z
	var r: Vector2 = Vector2(right.x, right.z).normalized()
	var d: Vector2 = Vector2(down.x, down.z).normalized()
	return r * v.x + d * v.y


func _update_aim() -> void:
	var stick: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > stick_deadzone:
		_using_pad_aim = true
		aim_dir = _screen_to_world(stick).normalized()
	elif not _using_pad_aim:
		var mouse: Vector2 = get_viewport().get_mouse_position()
		var origin: Vector3 = camera.project_ray_origin(mouse)
		var normal: Vector3 = camera.project_ray_normal(mouse)
		if absf(normal.y) > 0.0001:
			var t: float = (ground_y - origin.y) / normal.y
			var hit: Vector3 = origin + normal * t
			var d: Vector2 = Vector2(hit.x, hit.z) - ground_position()
			if d.length_squared() > 0.01:
				aim_dir = d.normalized()
	_aim_marker.rotation.y = atan2(aim_dir.x, aim_dir.y)


func _fire() -> void:
	shots_fired += 1
	var spread: float = deg_to_rad(_rng.randf_range(-weapon.spread_deg, weapon.spread_deg))
	var dir: Vector2 = aim_dir.rotated(spread)
	var from: Vector2 = ground_position() + dir * radius
	var travelled: float = _hitscan.cast(horde, from, dir, weapon.max_range, weapon.penetration, _hits)
	if not _hits.is_empty():
		horde.apply_damage(_hits, weapon.damage)
	var muzzle_y: float = ground_y + 0.9
	var end: Vector2 = from + dir * travelled
	fired.emit(Vector3(from.x, muzzle_y, from.y), Vector3(end.x, muzzle_y, end.y))
