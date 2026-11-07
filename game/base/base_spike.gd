extends Node3D
## `?spike=base` (PHASE1 1.7 step 3): the rooftop base by day and night (the light dims), without the horde. The rooms stand in their
## slots by tier (tools/blender/kit_base.py) and the survivors live out the hours SimCore's daily life picks
## (LifeRules): they walk to a bed, a planter, the fire or a book and play the clip for it.
## Time: 1 game hour = layout seconds_per_hour at 1×; 1 / 2 / 3 (pad LB / RB) = 1× / 3× / 10×, Space (pad Y) pauses.
## F5 cycles the test rooms (start / tier 1 / tier 2), F3 shows who does what. Q / E turn the camera, the wheel zooms.
## Options: ?rooms=start|tier1|tier2 &people=3..6 &hour=0..23 &seed=N &zoom=0..2 &turn=0..3 (90° steps) &speed=1..3

const LEVEL: PackedScene = preload("res://game/level/style15_level.tscn")

var state: SimState
var kit: BaseKit = BaseKit.new()
var nav: BaseNav
var _rooms_root: Node3D
var _room_sig: PackedStringArray = PackedStringArray()
var _residents: Dictionary[int, Resident] = {}
var _hour_left: float = 0.0
var _speed_i: int = 0
var _paused: bool = false
var _kind_i: int = 0
var _clock_label: Label
var _log: Label  ## the last hour's notable events (built, made, turned)
var _env: Environment
var _sun: DirectionalLight3D
var _day_exposure: float = 1.0
var _day_sun: float = 1.0


func _ready() -> void:
	var rig: Node3D = $IsoCameraRig  # already ready: step it to the asked zoom and turn
	rig.call("zoom_step", clampi(SpikeLauncher.arg("zoom", "1").to_int(), 0, 2) - 1)
	rig.call("rotate_step", SpikeLauncher.arg("turn", "0").to_int())
	var level: Node = LEVEL.instantiate()
	add_child(level)
	_env = (level.get_node("WorldEnvironment") as WorldEnvironment).environment.duplicate() as Environment
	(level.get_node("WorldEnvironment") as WorldEnvironment).environment = _env
	_sun = level.get_node("Sun") as DirectionalLight3D
	_day_exposure = _env.tonemap_exposure
	_day_sun = _sun.light_energy
	var roof: Array = kit.layout["roof"]["size"]
	nav = BaseNav.new(Vector2(float(roof[0]), float(roof[1])), float(kit.layout["roof"]["cell"]))
	_kind_i = maxi(BasePreset.KINDS.find(SpikeLauncher.arg("rooms", "start")), 0)
	var people: int = SpikeLauncher.arg("people", "5").to_int()
	var hour: int = clampi(SpikeLauncher.arg("hour", "7").to_int(), 0, 23)
	state = BasePreset.make(BasePreset.KINDS[_kind_i], people, SpikeLauncher.arg("seed", "7").to_int(), hour)
	_rooms_root = Node3D.new()
	_rooms_root.name = "Rooms"
	add_child(_rooms_root)
	_build_ui()
	_refresh_rooms()
	for s: Survivor in state.survivors:
		var r: Resident = Resident.new()
		add_child(r)
		r.setup(s, nav, kit.stroll_points())
		_residents[s.id] = r
	_place(true)
	_hour_left = _sec_per_hour()
	_set_speed(SpikeLauncher.arg("speed", "1").to_int() - 1)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_1, KEY_2, KEY_3:
				_set_speed((event as InputEventKey).physical_keycode - KEY_1)
			KEY_SPACE:
				_paused = not _paused
			KEY_F5:
				_kind_i = (_kind_i + 1) % BasePreset.KINDS.size()
				BasePreset.apply(state, BasePreset.KINDS[_kind_i])
				LifeRules.decide(state)
				_refresh_rooms()
				_place(true)
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				_set_speed(_speed_i - 1)
			JOY_BUTTON_RIGHT_SHOULDER:
				_set_speed(_speed_i + 1)
			JOY_BUTTON_Y:
				_paused = not _paused


func _process(delta: float) -> void:
	Engine.time_scale = 0.0 if _paused else float((kit.layout["speeds"] as Array)[_speed_i])
	_hour_left -= delta
	if _hour_left <= 0.0:
		_hour_left += _sec_per_hour()
		_tick_hour()
	_update_ui()
	_update_light()


## Night falls on the roof: the exposure and the sun dim from 18:00, darkest 22:00–05:00, back by 07:00. The kitchen
## fire stays bright (emissive), so the evening gathering reads.
func _update_light() -> void:
	var h: float = state.clock.hour + clampf(1.0 - _hour_left / _sec_per_hour(), 0.0, 1.0)
	var night: float = 0.0
	if h >= 18.0 and h < 22.0:
		night = (h - 18.0) / 4.0
	elif h >= 22.0 or h < 5.0:
		night = 1.0
	elif h < 7.0:
		night = 1.0 - (h - 5.0) / 2.0
	night = smoothstep(0.0, 1.0, night)
	_env.tonemap_exposure = lerpf(_day_exposure, _day_exposure * 0.62, night)
	_sun.light_energy = lerpf(_day_sun, _day_sun * 0.45, night)


func _sec_per_hour() -> float:
	return float(kit.layout["seconds_per_hour"])


func _set_speed(i: int) -> void:
	_speed_i = clampi(i, 0, (kit.layout["speeds"] as Array).size() - 1)
	_paused = false


## One game hour: the morning upkeep at 06:00, then SimCore's hour (daily life decides, rooms work, needs move).
func _tick_hour() -> void:
	if state.clock.hour == 6:
		state.start_day(BasePreset.RULES)
	var before: Array = state.rooms.map(func(r: RoomState) -> String: return BaseKit.model_key(r))
	state.advance_hour()
	LifeRules.decide(state)  # what they do in the hour that starts now
	var after: Array = state.rooms.map(func(r: RoomState) -> String: return BaseKit.model_key(r))
	for i: int in before.size():
		if before[i] != after[i] and not str(after[i]).begins_with("site"):
			_log.text = "%02d:00  %s finished" % [state.clock.hour, str(after[i]).replace("_", " tier ")]
	_refresh_rooms()
	_place(false)


## Room models by tier, and the nav grid round them, when anything changed.
func _refresh_rooms() -> void:
	var sig: PackedStringArray = PackedStringArray()
	for r: RoomState in state.rooms:
		sig.append("%s|%s" % [BaseKit.model_key(r), BaseKit.upgrading(r)])
	if sig == _room_sig:
		return
	_room_sig = sig
	for c: Node in _rooms_root.get_children():
		c.queue_free()
	nav.clear()
	for node: Node in get_tree().get_nodes_in_group("nav_obstacle"):
		var n3: Node3D = node as Node3D
		var fp: Vector2 = n3.get_meta("footprint", Vector2.ONE)
		if absf(sin(n3.global_rotation.y)) > 0.5:
			fp = Vector2(fp.y, fp.x)
		nav.block(Vector2(n3.global_position.x, n3.global_position.z), fp)
	for i: int in state.rooms.size():
		var r: RoomState = state.rooms[i]
		var key: String = BaseKit.model_key(r)
		if key.is_empty():
			continue
		_add_model(key, kit.slot_transform(i))
		if BaseKit.upgrading(r):
			_add_model("site_pile", kit.pile_transform(i, r))
		for rect: Rect2 in kit.room_solids(i, r):
			nav.block(rect.position, rect.size)
	for spot: Dictionary in kit.roof_spots("read", &"read"):
		_add_model("crate_seat", Transform3D(Basis(Vector3.UP, spot["yaw"]), spot["pos"]))
	nav.commit()


func _add_model(key: String, xf: Transform3D) -> void:
	var model: Node3D = (load(kit.kit[key]["model"]) as PackedScene).instantiate() as Node3D
	model.transform = xf
	model.name = key
	_rooms_root.add_child(model)
	Style15Level.apply_materials(model, Style15Level.SURFACE_MATERIAL)


## Sends everyone to this hour's spot; `snap` puts them there at once.
func _place(snap: bool) -> void:
	var spots: Dictionary = LifeSpots.assign(state, kit)
	for s: Survivor in state.survivors:
		var r: Resident = _residents.get(s.id)
		if r == null:
			continue
		if not s.is_alive():
			r.visible = false
			continue
		r.go_to(spots[s.id])
		if snap:
			r.snap()


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(16, 12)
	layer.add_child(box)
	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override("font_size", 22)
	_clock_label.add_theme_constant_override("outline_size", 6)
	_clock_label.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(_clock_label)
	var help: Label = Label.new()
	help.text = "1 / 2 / 3 (LB / RB) speed · Space (Y) pause · F5 rooms · F3 who does what · Q / E turn"
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_constant_override("outline_size", 4)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(help)
	_log = Label.new()
	_log.add_theme_font_size_override("font_size", 14)
	_log.add_theme_constant_override("outline_size", 4)
	_log.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(_log)


func _update_ui() -> void:
	var minute: int = clampi(int((1.0 - _hour_left / _sec_per_hour()) * 60.0), 0, 59)
	var speed: String = "paused" if _paused else "×%d" % int((kit.layout["speeds"] as Array)[_speed_i])
	_clock_label.text = "Day %d  %02d:%02d  %s   ·   rooms: %s" % [state.clock.day, state.clock.hour, minute, speed,
		BasePreset.KINDS[_kind_i]]
	for s: Survivor in state.survivors:
		var where: String = ""
		if s.needs.doing_slot >= 0:
			where = " " + state.rooms[s.needs.doing_slot].room
		DebugOverlay.set_stat(s.name, "%s%s · fatigue %d hunger %d morale %d" % [NeedRules.activity(s, state.clock.hour),
			where, roundi(s.needs.fatigue), roundi(s.needs.hunger), roundi(s.morale)])
	DebugOverlay.set_stat("stock", "food %.0f water %.0f meals %.0f herbs %.0f medicine %.0f" % [state.stock["food"],
		state.stock["water"], state.stock["meals"], state.stock["herbs"], state.stock["medicine"]])
