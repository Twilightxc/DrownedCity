extends Node3D
## Spike A (Phase 0.3): can the web build hold 200+ zombies at 50+ FPS on an Intel Arc iGPU?
## Also the shared harness for later spikes: player HUD line (ammo, grenades) and a controls
## cheat sheet that follows the input device.
## Flat rooftop over flood water, MultiMesh horde on a shared flow field, hitscan rifle.
## Spawn count: slider, [ / ] keys, or D-pad left/right.
## With `level_scene` set (Spike B), that scene supplies the art and its "nav_obstacle" nodes
## replace `obstacles`; otherwise placeholder boxes are built from `obstacles`.

const GROUND_Y: float = 0.0
const BUILDING_DEPTH: float = 6.0
const WATER_Y: float = -4.0

@export var horde_config: HordeConfig
@export var level_scene: PackedScene
## Spike E (0.7): corpses, blood and dismemberment; needs the animated horde (HordeRenderer.models).
@export var gore_config: GoreConfig
@export var roof_size: Vector2i = Vector2i(40, 40)
## Obstacles in roof cells: stair house, AC units, water tanks, low walls.
@export var obstacles: Array[Rect2i] = [
	Rect2i(4, 4, 5, 4), Rect2i(26, 6, 3, 2), Rect2i(30, 6, 3, 2), Rect2i(8, 26, 3, 3),
	Rect2i(28, 28, 4, 4), Rect2i(16, 17, 10, 1), Rect2i(18, 30, 1, 7), Rect2i(33, 16, 1, 9),
]
@export var roof_color: Color = Color(0.55, 0.52, 0.47)
@export var obstacle_color: Color = Color(0.45, 0.43, 0.4)
@export var wall_color: Color = Color(0.5, 0.46, 0.4)
@export var water_color: Color = Color(0.17, 0.33, 0.31)

var _grid: NavGrid
var _horde: Horde
var _target_count: int = 0
var _count_index: int = 0
var _flow_timer: float = 0.0
var _flow_cell: Vector2i = Vector2i(-1, -1)
var _spawn_budget: float = 0.0
var _perimeter: Array[Vector2i] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _horde_ms: float = 0.0
var _flow_ms: float = 0.0
var _render_ms: float = 0.0
var _stats_timer: float = 0.0

var _count_slider: HSlider
var _count_label: Label
var _status_label: Label
var _help_label: Label
var _grenades: Grenades
var _corpses: CorpseLayer
var _blood: BloodFx
## `-- --auto-shoot` (web: `&autoshoot=1`): the player fires at the nearest zombie and throws a grenade every few seconds,
## so captures and measurements see a repeatable gore load without hands on the keyboard.
var _auto_shoot: bool = false
var _auto_fire_left: float = 0.0
var _auto_throw_left: float = 2.0

@onready var _rig: IsoCameraRig = $IsoCameraRig
@onready var _camera: Camera3D = $IsoCameraRig/Camera3D
@onready var _player: SpikePlayer = $Player
@onready var _renderer: HordeRenderer = $HordeRenderer
@onready var _tracers: Tracers = $Tracers


func _ready() -> void:
	_rng.randomize()
	_grid = NavGrid.new(roof_size.x, roof_size.y, 1.0, -Vector2(roof_size) * 0.5)
	var rects: Array[Rect2i] = obstacles
	if level_scene != null:
		var level: Node = level_scene.instantiate()
		add_child(level)
		rects = (level as Style15Level).nav_obstacle_rects(_grid) if level is Style15Level else []
	for rect: Rect2i in rects:
		_grid.set_blocked_rect(rect)
	_collect_perimeter()
	assert(not _perimeter.is_empty(), "no walkable roof edge to spawn from")

	var capacity: int = 0
	for n: int in horde_config.spawn_counts:
		capacity = maxi(capacity, n)
	_horde = Horde.new(horde_config, _grid, capacity, _rng.randi())
	_renderer.setup(capacity)
	if gore_config != null and not _renderer.models.is_empty():
		_corpses = CorpseLayer.new()
		_corpses.grid = _grid
		_corpses.ground_y = GROUND_Y
		add_child(_corpses)
		_corpses.setup(gore_config, _renderer.models)
		_blood = BloodFx.new()
		_blood.ground_y = GROUND_Y
		add_child(_blood)
		_blood.setup(gore_config)

	if level_scene == null:
		_build_level_meshes()
	_player.setup(_grid, _horde, _camera, GROUND_Y)
	_player.position = Vector3(0.5, GROUND_Y, 2.5)
	_player.fired.connect(_tracers.add)
	if _player.throwable != null:
		_grenades = Grenades.new()
		_grenades.horde = _horde
		add_child(_grenades)
		_player.grenades = _grenades
	_rig.position = _player.position

	_auto_shoot = "--auto-shoot" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		_auto_shoot = str(JavaScriptBridge.eval("window.location.search", true)).contains("autoshoot=1")
	_build_ui()
	_set_count_index(horde_config.default_count_index)
	_player.device_changed.connect(func(_pad: bool) -> void: _update_help())
	_update_help()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("horde_more"):
		_set_count_index(_count_index + 1)
	elif event.is_action_pressed("horde_less"):
		_set_count_index(_count_index - 1)


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 20.0)  # a hitch must not teleport the crowd through walls
	var target: Vector2 = _player.ground_position()

	_flow_timer -= delta
	var cell: Vector2i = _grid.world_to_cell(target)
	if cell != _flow_cell and _flow_timer <= 0.0:
		var t0: int = Time.get_ticks_usec()
		_horde.recompute_flow([cell] as Array[Vector2i])
		_flow_ms = (Time.get_ticks_usec() - t0) / 1000.0
		_flow_cell = cell
		_flow_timer = horde_config.flow_recompute_sec

	_spawn(delta, target)
	if _auto_shoot:
		_auto_attack(delta, target)

	var t1: int = Time.get_ticks_usec()
	_horde.update(delta, target)
	var t2: int = Time.get_ticks_usec()
	_renderer.sync(_horde, GROUND_Y)
	_drain_horde_events()
	var t3: int = Time.get_ticks_usec()
	_horde_ms = lerpf(_horde_ms, (t2 - t1) / 1000.0, 0.1)
	_render_ms = lerpf(_render_ms, (t3 - t2) / 1000.0, 0.1)

	_rig.position = _rig.position.lerp(_player.position, clampf(delta * 6.0, 0.0, 1.0))
	_update_status()
	_publish_stats(delta)


func _auto_attack(delta: float, from: Vector2) -> void:
	var nearest: int = -1
	var best: float = INF
	for a: int in _horde.count:
		var d2: float = _horde.positions[a].distance_squared_to(from)
		if d2 < best:
			best = d2
			nearest = a
	if nearest < 0:
		return
	var at: Vector2 = _horde.positions[nearest]
	_auto_fire_left -= delta
	if _auto_fire_left <= 0.0 and best < 15.0 * 15.0:
		_auto_fire_left = 0.1
		_player.aim_dir = (at - from).normalized()
		_player._fire()
	_auto_throw_left -= delta
	if _auto_throw_left <= 0.0 and _grenades != null and _player.throwable != null:
		_auto_throw_left = 4.0
		_grenades.throw(_player.throwable, _player.position + Vector3(0, 1.2, 0), Vector3(at.x, GROUND_Y, at.y))


## Hits and deaths since the last frame → blood and corpses.
func _drain_horde_events() -> void:
	if _blood != null:
		for i: int in _horde.hit_points.size():
			_blood.hit(_horde.hit_points[i], _horde.hit_dirs[i])
	if _corpses != null:
		for d: Horde.Death in _horde.deaths:
			_corpses.add_death(d)
			if _blood != null:
				var size: float = randf_range(gore_config.death_pool_size.x, gore_config.death_pool_size.y)
				# Under the body: it falls forward, or backwards away from a blast.
				_blood.pool(d.position + (d.push if d.blast else d.heading) * 0.5, size)
	_horde.clear_events()


func _spawn(delta: float, target: Vector2) -> void:
	if _horde.count >= _target_count:
		_spawn_budget = 0.0
		while _horde.count > _target_count:
			_horde.kill(_horde.count - 1)
		return
	_spawn_budget += horde_config.spawn_per_second * delta
	var min_d2: float = horde_config.spawn_min_distance * horde_config.spawn_min_distance
	while _spawn_budget >= 1.0 and _horde.count < _target_count:
		_spawn_budget -= 1.0
		for attempt: int in 8:
			var c: Vector2i = _perimeter[_rng.randi() % _perimeter.size()]
			var p: Vector2 = _grid.cell_center(c) + Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3))
			if p.distance_squared_to(target) >= min_d2 and _horde.spawn(p):
				break


func _collect_perimeter() -> void:
	_perimeter.clear()
	for x: int in _grid.width:
		for y: int in [0, _grid.height - 1]:
			if _grid.is_walkable(Vector2i(x, y)):
				_perimeter.append(Vector2i(x, y))
	for y: int in range(1, _grid.height - 1):
		for x: int in [0, _grid.width - 1]:
			if _grid.is_walkable(Vector2i(x, y)):
				_perimeter.append(Vector2i(x, y))


func _set_count_index(i: int) -> void:
	_count_index = clampi(i, 0, horde_config.spawn_counts.size() - 1)
	_target_count = horde_config.spawn_counts[_count_index]
	if _count_slider != null:
		_count_slider.set_value_no_signal(_count_index)
		_count_label.text = "Horde target: %d   ([ / ], D-pad left/right)" % _target_count


func _publish_stats(delta: float) -> void:
	_stats_timer -= delta
	if _stats_timer > 0.0:
		return
	_stats_timer = 0.25
	DebugOverlay.set_stat("zombies", "%d / %d" % [_horde.count, _target_count])
	DebugOverlay.set_stat("horde_update", "%.2f ms" % _horde_ms)
	DebugOverlay.set_stat("horde_render_sync", "%.2f ms" % _render_ms)
	DebugOverlay.set_stat("flow_field", "%.2f ms (every %.2f s)" % [_flow_ms, horde_config.flow_recompute_sec])
	DebugOverlay.set_stat("kills", str(_horde.kills))
	if _corpses != null:
		DebugOverlay.set_stat("corpses", "%d / %d" % [_corpses.live_count(), gore_config.corpse_cap])
		DebugOverlay.set_stat("gore", "on" if gore_config.enabled else "off")
		DebugOverlay.set_stat("blood_pools", "%d / %d" % [_blood.pool_count(), gore_config.pool_cap])
		if _auto_shoot and Engine.get_process_frames() % 240 == 0:
			print("gore: corpses %d pools %d kills %d" % [_corpses.live_count(), _blood.pool_count(), _horde.kills])
	DebugOverlay.set_stat("hits_taken", str(_horde.hits_on_target))
	DebugOverlay.set_stat("shots", str(_player.shots_fired))
	DebugOverlay.set_stat("input", "gamepad" if _player.using_pad else "mouse + keyboard")
	DebugOverlay.set_stat("assist_target", str(_player.assist_target))


func _update_status() -> void:
	var text: String = "Ammo %d / %d" % [_player.ammo, _player.weapon.magazine_size]
	if _player.reload_left > 0.0:
		text = "Reloading %d%%" % int(_player.reload_progress() * 100.0)
	if _player.throwable != null:
		text += "   ·   Grenades %d" % _player.grenade_count
	if _status_label.text != text:
		_status_label.text = text


func _update_help() -> void:
	_help_label.text = _help_text(_player.using_pad)


## Controls cheat sheet for the device in use; subclasses append their extras.
func _help_text(pad: bool) -> String:
	if pad:
		return "Move L-stick · Aim R-stick · Fire RT · Reload X · Throw hold LT\nCamera LB/RB, D-pad up/down · Back: debug overlay"
	return "Move WASD · Aim mouse · Fire LMB · Reload R · Throw hold RMB\nCamera Q/E, wheel · F3: debug overlay"


func _build_level_meshes() -> void:
	var size: Vector2 = _grid.world_size()
	_add_box(Vector3(0, GROUND_Y - BUILDING_DEPTH * 0.5, 0), Vector3(size.x, BUILDING_DEPTH, size.y), roof_color)
	for rect: Rect2i in obstacles:
		var thin: bool = rect.size.x == 1 or rect.size.y == 1
		var h: float = 1.1 if thin else 1.8
		var center: Vector2 = _grid.origin + (Vector2(rect.position) + Vector2(rect.size) * 0.5) * _grid.cell_size
		_add_box(Vector3(center.x, GROUND_Y + h * 0.5, center.y), Vector3(rect.size.x, h, rect.size.y), wall_color if thin else obstacle_color)

	var water: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(240, 240)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = water_color
	mat.roughness = 0.2
	plane.material = mat
	water.mesh = plane
	water.position.y = WATER_Y
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _add_box(center: Vector3, size: Vector3, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	box.material = mat
	mi.mesh = box
	mi.position = center
	add_child(mi)


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -470.0
	panel.offset_top = 8.0
	panel.offset_right = -8.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	layer.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	_count_label = Label.new()
	box.add_child(_count_label)
	_count_slider = HSlider.new()
	_count_slider.min_value = 0
	_count_slider.max_value = horde_config.spawn_counts.size() - 1
	_count_slider.step = 1
	_count_slider.tick_count = horde_config.spawn_counts.size()
	_count_slider.ticks_on_borders = true
	_count_slider.focus_mode = Control.FOCUS_NONE  # keep keys/pad for the game; [ ] and D-pad drive it
	_count_slider.value_changed.connect(func(v: float) -> void: _set_count_index(int(v)))
	box.add_child(_count_slider)
	_status_label = Label.new()
	box.add_child(_status_label)
	_help_label = Label.new()
	_help_label.add_theme_font_size_override("font_size", 12)
	box.add_child(_help_label)
