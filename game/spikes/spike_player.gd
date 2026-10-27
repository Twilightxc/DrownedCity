class_name SpikePlayer
extends Node3D
## Twin-stick shooter for the Phase 0 spikes (0.5 = feel): camera-relative movement with
## acceleration, mouse aim on a body-height plane, right-stick aim with light assist (gamepad
## only), magazine + reload, hold-to-aim grenade throw, interact. Moves on the NavGrid like the
## zombies; no physics body.

signal fired(from: Vector3, to: Vector3)
signal device_changed(pad: bool)

const MUZZLE_HEIGHT: float = 0.9
const THROW_HEIGHT: float = 1.4
const PAD_SWITCH_AXIS: float = 0.5  # stick/trigger travel that counts as "now using the pad"
const AIM_LINE_WIDTH: float = 0.1
const AIM_LINE_COLOR: Color = Color(1.0, 0.45, 0.3, 0.6)
const AIM_LINE_ASSIST_COLOR: Color = Color(0.55, 1.0, 0.5, 0.85)

@export var radius: float = 0.3
@export var weapon: WeaponConfig
@export var throwable: ThrowableConfig
@export var controls: TwinStickConfig

var grid: NavGrid
var horde: Horde
var camera: Camera3D
var grenades: Grenades  ## null: throwing disabled
var ground_y: float = 0.0

var aim_dir: Vector2 = Vector2(0, 1)  # world XZ
var velocity: Vector2 = Vector2.ZERO
var using_pad: bool = false
var aim_locked: bool = false  ## radial menu open: sticks/mouse pick a command instead
var assist_target: int = -1  ## agent index this frame; may go stale once a shot swap-removes agents
var assist_point: Vector2 = Vector2.ZERO  ## that agent's position when it was picked
var interact_target: SupplyCrate
var shots_fired: int = 0
var ammo: int = 0
var reload_left: float = 0.0
var grenade_count: int = 0

var _hitscan: Hitscan
var _assist: AimAssist
var _hits: PackedInt32Array = PackedInt32Array()
var _cooldown: float = 0.0
var _aim_stick: Vector2 = Vector2.ZERO
var _throw_held: bool = false
var _throw_target: Vector3 = Vector3.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _aim_line: ImmediateMesh = ImmediateMesh.new()
var _throw_ring: MeshInstance3D

@onready var _aim_marker: Node3D = $AimMarker


func setup(nav: NavGrid, crowd: Horde, cam: Camera3D, y: float) -> void:
	grid = nav
	horde = crowd
	camera = cam
	ground_y = y
	_hitscan = Hitscan.new(nav)
	_assist = AimAssist.new(nav)
	position.y = y
	ammo = weapon.magazine_size
	grenade_count = throwable.carry if throwable != null else 0


func _ready() -> void:
	if controls == null:
		controls = TwinStickConfig.new()
	var line_mat: StandardMaterial3D = StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.vertex_color_use_as_albedo = true
	line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var line_node: MeshInstance3D = MeshInstance3D.new()
	line_node.mesh = _aim_line
	line_node.material_override = line_mat
	line_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line_node.top_level = true
	add_child(line_node)

	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(1.0, 0.9, 0.6, 0.85)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.0
	ring.rings = 32
	ring.ring_segments = 4
	ring.material = ring_mat
	_throw_ring = MeshInstance3D.new()
	_throw_ring.mesh = ring
	_throw_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_throw_ring.top_level = true
	_throw_ring.visible = false
	add_child(_throw_ring)


func ground_position() -> Vector2:
	return Vector2(position.x, position.z)


## 0..1 while reloading, 1 otherwise.
func reload_progress() -> float:
	if reload_left <= 0.0 or weapon.reload_time <= 0.0:
		return 1.0
	return 1.0 - reload_left / weapon.reload_time


func start_reload() -> void:
	if reload_left > 0.0 or weapon.magazine_size <= 0 or ammo >= weapon.magazine_size:
		return
	reload_left = weapon.reload_time


func restock() -> void:
	if throwable != null:
		grenade_count = throwable.carry


func _input(event: InputEvent) -> void:
	# Last device touched decides aim mode and button prompts; never consumes the event.
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		_set_pad(true)
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > PAD_SWITCH_AXIS:
		_set_pad(true)
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length_squared() > 4.0:
		_set_pad(false)
	elif event is InputEventKey or event is InputEventMouseButton:
		_set_pad(false)


func _set_pad(pad: bool) -> void:
	if pad != using_pad:
		using_pad = pad
		device_changed.emit(pad)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload"):
		start_reload()
	elif event.is_action_pressed("interact") and interact_target != null:
		interact_target.interact(self)


func _process(delta: float) -> void:
	if grid == null:
		return
	_move(delta)
	if not aim_locked:
		_update_aim()
	_update_weapon(delta)
	_update_throw()
	_update_interact()
	_draw_aim_line()


func _move(delta: float) -> void:
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down", controls.stick_deadzone)
	var desired: Vector2 = AimMath.screen_to_world(input, camera.global_basis) * controls.move_speed
	var rate: float = controls.move_accel if desired != Vector2.ZERO else controls.move_decel
	velocity = velocity.move_toward(desired, rate * delta)
	if velocity == Vector2.ZERO:
		return
	var step: Vector2 = velocity * delta
	var p: Vector2 = ground_position()
	var np: Vector2 = p
	if _can_stand(Vector2(p.x + step.x, p.y)):
		np.x += step.x
	else:
		velocity.x = 0.0
	if _can_stand(Vector2(np.x, p.y + step.y)):
		np.y += step.y
	else:
		velocity.y = 0.0
	position.x = np.x
	position.z = np.y


func _can_stand(p: Vector2) -> bool:
	for offset: Vector2 in [Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		if not grid.is_walkable_world(p + offset):
			return false
	return true


func _update_aim() -> void:
	_aim_stick = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", controls.stick_deadzone)
	assist_target = -1
	if using_pad:
		if _aim_stick != Vector2.ZERO:
			var raw: Vector2 = AimMath.screen_to_world(_aim_stick, camera.global_basis).normalized()
			aim_dir = raw
			if controls.aim_assist and horde != null:
				var cone: float = deg_to_rad(controls.aim_assist_cone_deg)
				assist_target = _assist.pick(horde, ground_position(), raw, controls.aim_assist_range, cone)
				if assist_target >= 0:
					assist_point = horde.positions[assist_target]
					aim_dir = AimAssist.bend(raw, ground_position(), assist_point, controls.aim_assist_strength)
	else:
		var hit: Variant = _mouse_on_plane(ground_y + controls.aim_plane_height)
		if hit != null:
			var d: Vector2 = Vector2((hit as Vector3).x, (hit as Vector3).z) - ground_position()
			if d.length_squared() > 0.01:
				aim_dir = d.normalized()
	_aim_marker.rotation.y = atan2(aim_dir.x, aim_dir.y)


func _mouse_on_plane(plane_y: float) -> Variant:
	var mouse: Vector2 = get_viewport().get_mouse_position()
	return AimMath.ray_to_plane(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse), plane_y)


func _update_weapon(delta: float) -> void:
	_cooldown -= delta
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			reload_left = 0.0
			ammo = weapon.magazine_size
		_cooldown = maxf(_cooldown, 0.0)
		return
	var trigger: bool = not aim_locked and Input.is_action_pressed("fire")
	if using_pad and controls.pad_auto_fire and not aim_locked and _aim_stick.length() >= controls.auto_fire_threshold:
		trigger = true
	if not trigger:
		_cooldown = maxf(_cooldown, 0.0)
		return
	if _cooldown > 0.0:
		return
	if weapon.magazine_size > 0 and ammo <= 0:
		start_reload()
		return
	_cooldown += 1.0 / weapon.fire_rate  # carry the remainder so the rate doesn't depend on FPS
	ammo -= 1
	_fire()
	if weapon.magazine_size > 0 and ammo <= 0:
		start_reload()


func _fire() -> void:
	shots_fired += 1
	var spread: float = deg_to_rad(_rng.randf_range(-weapon.spread_deg, weapon.spread_deg))
	var dir: Vector2 = aim_dir.rotated(spread)
	var from: Vector2 = ground_position() + dir * radius
	var travelled: float = _hitscan.cast(horde, from, dir, weapon.max_range, weapon.penetration, _hits)
	if not _hits.is_empty():
		horde.apply_damage(_hits, weapon.damage, from)
	var muzzle_y: float = ground_y + MUZZLE_HEIGHT
	var end: Vector2 = from + dir * travelled
	fired.emit(Vector3(from.x, muzzle_y, from.y), Vector3(end.x, muzzle_y, end.y))


## Hold to show the landing ring, release to throw.
func _update_throw() -> void:
	var can: bool = grenades != null and throwable != null and grenade_count > 0 and not aim_locked
	var held: bool = can and Input.is_action_pressed("throw")
	if held:
		_throw_target = _compute_throw_target()
		_throw_ring.position = _throw_target + Vector3.UP * 0.05
		_throw_ring.scale = Vector3(throwable.blast_radius, 1.0, throwable.blast_radius)
	elif _throw_held and can:
		grenades.throw(throwable, Vector3(position.x, ground_y + THROW_HEIGHT, position.z), _throw_target)
		grenade_count -= 1
	_throw_held = held
	_throw_ring.visible = held


func _compute_throw_target() -> Vector3:
	var p: Vector2 = ground_position()
	var target: Vector2 = p + aim_dir * controls.pad_throw_range
	if using_pad:
		# The saved point, not horde.positions[assist_target]: a shot this frame may have killed that
		# agent and swapped another one into its index.
		if assist_target >= 0:
			target = assist_point
	else:
		var hit: Variant = _mouse_on_plane(ground_y)
		if hit != null:
			target = Vector2((hit as Vector3).x, (hit as Vector3).z)
	target = AimMath.clamp_range(p, target, throwable.min_range, throwable.max_range, aim_dir)
	return Vector3(target.x, ground_y, target.y)


func _update_interact() -> void:
	var best: SupplyCrate = null
	var best_d2: float = controls.interact_radius * controls.interact_radius
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		var crate: SupplyCrate = node as SupplyCrate
		if crate == null:
			continue
		var d2: float = Vector2(crate.global_position.x, crate.global_position.z).distance_squared_to(ground_position())
		if d2 <= best_d2:
			best = crate
			best_d2 = d2
	if best != interact_target and interact_target != null:
		interact_target.show_prompt(false, using_pad)
	interact_target = best
	if interact_target != null:
		interact_target.show_prompt(true, using_pad)


## Flat laser from the muzzle to the first wall or max range; green while assist holds a target.
func _draw_aim_line() -> void:
	_aim_line.clear_surfaces()
	if not controls.aim_line or aim_locked:
		return
	var from: Vector2 = ground_position() + aim_dir * radius
	var length: float = grid.ray_distance(from, aim_dir, weapon.max_range)
	if length <= 0.0:
		return
	var to: Vector2 = from + aim_dir * length
	var side: Vector2 = aim_dir.orthogonal() * AIM_LINE_WIDTH * 0.5
	var y: float = ground_y + MUZZLE_HEIGHT
	var color: Color = AIM_LINE_ASSIST_COLOR if assist_target >= 0 else AIM_LINE_COLOR
	var tail: Color = Color(color, 0.0)
	_aim_line.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for v: Array in [[from + side, color], [from - side, color], [to + side, tail], [to - side, tail]]:
		_aim_line.surface_set_color(v[1])
		var p: Vector2 = v[0]
		_aim_line.surface_add_vertex(Vector3(p.x, y, p.y))
	_aim_line.surface_end()
