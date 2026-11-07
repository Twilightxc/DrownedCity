extends Node3D
## `?spike=base` (PHASE1 1.7 step 3): the rooftop base by day and night (the light dims), without the horde. The rooms stand in their
## slots by tier (tools/blender/kit_base.py) and the survivors live out the hours SimCore's daily life picks
## (LifeRules): they walk to a bed, a planter, the fire or a book and play the clip for it. Planters grow crops
## through their stages as the farm works (FarmLook) and their tenders hoe, sow, water, weed and harvest. The kitchen
## fire burns while someone cooks and through the evening; at dusk someone lights the oil drums, and at night people
## warm their hands round them.
## Time: 1 game hour = layout seconds_per_hour at 1×; 1 / 2 / 3 (pad LT / RT) = 1× / 3× / 10×, Space / P (pad Y)
## pauses. The slot panel (1.7 step 4, BasePanel): click a slot, or Tab / Shift+Tab (pad RB / LB) to step through them;
## build, upgrade, queue, pin people; Esc / pad B closes. F5 cycles the test bases (new / start / tier 1 / tier 2),
## F3 shows who does what. Click a survivor (pad X steps through them) for their card: what they're doing in words,
## body and mind, skills and a short log of the day. O (pad Back) is Observer mode (1.7 step 5): the HUD hides and the
## camera drifts from one interesting thing to the next (ObserverDirector); with a card open it follows that person. Q / E turn the camera, the wheel zooms (4 steps, the closest for the details), WASD / the
## right stick pans (the left stick too while the panel is shut).
## Options: ?rooms=new|start|tier1|tier2 &people=3..6 &hour=0..23 &seed=N &zoom=0..3 &turn=0..3 (90° steps) &speed=1..3
## &focus=x,z (camera over that roof point) &slot=1..6 (the panel open on that slot) &observe=1 &card=<survivor id>

const LEVEL: PackedScene = preload("res://game/level/style15_level.tscn")
const PAN_SPEED: float = 12.0  ## m/s
const PAN_LIMIT: float = 14.0  ## m from the roof centre

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
var _rig: Node3D
var _last_ms: int = 0
var _crops_root: Node3D
var _crop_sig: PackedStringArray = PackedStringArray()
var _kitchen_fires: Array[Array] = []  ## [slot, BaseFire]
var _barrels: Array[Dictionary] = []  ## {"pos": Vector3, "fire": BaseFire, "pending": bool}
var _panel: BasePanel
var _frame: Node3D  ## the selected slot's outline on the roof
var _trigger_down: Array[bool] = [false, false]  ## LT, RT held (they are axes: act on the press only)
var _hud: CanvasLayer  ## clock, help, event line: hidden in Observer mode
var _card: SurvivorCard
var _spots: Dictionary = {}  ## this hour's LifeSpots, for the card's words
var _diary: Dictionary = {}  ## survivor id -> ["HH:00  what they started", ...] (the card's short log)
var _diary_key: Dictionary = {}  ## survivor id -> LifeStory.log_key last written
var _observing: bool = false
var _director: ObserverDirector
var _shot_left: float = 0.0  ## real seconds to the next shot
var _shot_id: int = -1
var _drift: Vector3 = Vector3.ZERO
var _zoom_before: int = 2


func _ready() -> void:
	_rig = $IsoCameraRig  # already ready: step it to the asked zoom and turn
	_rig.call("zoom_step", clampi(SpikeLauncher.arg("zoom", "2").to_int(), 0, 3) - 2)
	_rig.call("rotate_step", SpikeLauncher.arg("turn", "0").to_int())
	var focus: PackedStringArray = SpikeLauncher.arg("focus", "").split(",")
	if focus.size() == 2:
		_rig.position = Vector3(focus[0].to_float(), 0.0, focus[1].to_float())
	_last_ms = Time.get_ticks_msec()
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
	_crops_root = Node3D.new()
	_crops_root.name = "Crops"
	add_child(_crops_root)
	for pos: Vector3 in kit.barrels():
		var drum: Node3D = (load(kit.kit["fire_barrel"]["model"]) as PackedScene).instantiate() as Node3D
		drum.position = pos
		add_child(drum)
		Style15Level.apply_materials(drum, Style15Level.SURFACE_MATERIAL)
		var f: Array = kit.kit["fire_barrel"]["fires"][0]
		var fire: BaseFire = BaseFire.new(float(f[3]))
		fire.position = pos + Vector3(float(f[0]), float(f[1]), float(f[2]))
		add_child(fire)
		_barrels.append({"pos": pos, "fire": fire, "pending": false})
	_barrels_now()
	_build_ui()
	_card = SurvivorCard.new()
	add_child(_card)
	_director = ObserverDirector.new(kit.layout["observer"])
	_panel = BasePanel.new()
	_panel.state = state
	add_child(_panel)
	_panel.changed.connect(_on_player_changed)
	_panel.refresh()  # the stock bar from the first frame
	_panel.closed.connect(func() -> void: _frame.visible = false)
	_frame = Node3D.new()
	_frame.visible = false
	add_child(_frame)
	_refresh_rooms()
	for s: Survivor in state.survivors:
		var r: Resident = Resident.new()
		add_child(r)
		r.setup(s, nav, kit.stroll_points())
		_residents[s.id] = r
	_place(true)
	_fires_now()
	for b: Dictionary in _barrels:  # a scene opened at night finds the drums already burning
		if state.clock.hour >= 19 or state.clock.hour < 6:
			(b["fire"] as BaseFire).lit = true
			b["pending"] = false
	_hour_left = _sec_per_hour()
	_set_speed(SpikeLauncher.arg("speed", "1").to_int() - 1)
	if SpikeLauncher.arg("observe", "0") == "1":
		_set_observing(true)
	var who: int = SpikeLauncher.arg("card", "0").to_int()
	if who > 0:
		_card.open(who)
	var open_slot: int = SpikeLauncher.arg("slot", "0").to_int()
	if open_slot > 0 and open_slot <= state.rooms.size():
		_select(open_slot - 1)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event as InputEventKey
		match key.physical_keycode:
			KEY_1, KEY_2, KEY_3:
				_set_speed(key.physical_keycode - KEY_1)
			KEY_SPACE, KEY_P:
				_paused = not _paused
			KEY_TAB:
				_step_slot(-1 if key.shift_pressed else 1)
				get_viewport().set_input_as_handled()
			KEY_O:
				_set_observing(not _observing)
			KEY_F5:
				_kind_i = (_kind_i + 1) % BasePreset.KINDS.size()
				BasePreset.apply(state, BasePreset.KINDS[_kind_i])
				_on_player_changed()
				_place(true)
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				_step_slot(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				_step_slot(1)
			JOY_BUTTON_Y:
				_paused = not _paused
			JOY_BUTTON_X:
				_step_person()
			JOY_BUTTON_BACK:
				_set_observing(not _observing)
	elif event is InputEventJoypadMotion:
		var m: InputEventJoypadMotion = event as InputEventJoypadMotion
		var which: int = 0 if m.axis == JOY_AXIS_TRIGGER_LEFT else 1 if m.axis == JOY_AXIS_TRIGGER_RIGHT else -1
		if which >= 0:
			var down: bool = m.axis_value > 0.6
			if down and not _trigger_down[which]:
				_set_speed(_speed_i + (-1 if which == 0 else 1))
			_trigger_down[which] = down
	elif event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = (event as InputEventMouseButton).position
		var who: int = _person_at(at)
		if who >= 0:
			_card.open(who)
			return
		var i: int = _slot_at(at)
		if i >= 0 and not _observing:
			_select(i)


## The survivor drawn nearest the mouse (their chest within 45 px), or -1.
func _person_at(screen: Vector2) -> int:
	var cam: Camera3D = get_viewport().get_camera_3d()
	var best: int = -1
	var best_d: float = 45.0
	for id: int in _residents:
		var r: Resident = _residents[id]
		if not r.visible or cam.is_position_behind(r.global_position):
			continue
		var d: float = cam.unproject_position(r.global_position + Vector3(0.0, 1.0, 0.0)).distance_to(screen)
		if d < best_d:
			best_d = d
			best = id
	return best


## Pad X: the card on the next living survivor.
func _step_person() -> void:
	var people: Array[Survivor] = state.living()
	if people.is_empty():
		return
	var k: int = 0
	for j: int in people.size():
		if people[j].id == _card.survivor_id:
			k = j + 1
	_card.open(people[k % people.size()].id)


## Observer mode: the HUD, the slot panel and the name tags hide; the camera comes in a step and starts directing.
func _set_observing(on: bool) -> void:
	_observing = on
	_hud.visible = not on
	_panel.visible = not on
	if on:
		_panel.close()
		_frame.visible = false
		_zoom_before = _rig.get("zoom_index")
		_rig.call("zoom_step", 1 - _zoom_before)
		_shot_left = 0.0
	else:
		_rig.call("zoom_step", _zoom_before - int(_rig.get("zoom_index")))
	for r: Resident in _residents.values():
		r.tag.visible = not on


## Each frame in Observer mode: follow the card's survivor, else hold the shot and drift, cut to an errand, and pick
## the next shot every shot_sec real seconds.
func _direct(dt: float) -> void:
	if _card.is_open() and _residents.has(_card.survivor_id):
		var target: Vector3 = _residents[_card.survivor_id].position
		target.y = 0.0
		_rig.position = _rig.position.lerp(target, clampf(dt * 2.0, 0.0, 1.0))
		return
	var cands: Array[Dictionary] = _candidates()
	var cut: Dictionary = _director.errand_cut(cands, _shot_id)
	_shot_left -= dt
	if cut.is_empty() and _shot_left > 0.0:
		_rig.position += _drift * dt
		return
	var shot: Dictionary = cut if not cut.is_empty() else _director.pick(cands)
	_shot_left = float(_director.cfg["shot_sec"])
	if shot.is_empty():
		return
	_shot_id = shot["id"]
	var a: float = randf() * TAU
	_drift = Vector3(cos(a), 0.0, sin(a)) * float(_director.cfg["drift_mps"])
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(_rig, "position",
		shot["pos"] - _drift * float(_director.cfg["shot_sec"]) * 0.5, 2.5)


## What each visible survivor is up to, for the director.
func _candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Survivor in state.living():
		var r: Resident = _residents.get(s.id)
		if r == null or not r.visible:
			continue
		var act: String = NeedRules.activity(s, state.clock.hour)
		var tending: bool = act == "work" and s.needs.doing_slot >= 0 \
				and (state.rooms[s.needs.doing_slot].room == "farm" or state.rooms[s.needs.doing_slot].building > 0)
		out.append({"id": s.id, "act": act, "pos": Vector3(r.position.x, 0.0, r.position.z), "errand": r.busy(),
			"tending": tending})
	return out


## The short log: a line whenever someone starts something new.
func _write_diary() -> void:
	for s: Survivor in state.living():
		var key: String = LifeStory.log_key(state, s)
		if _diary_key.get(s.id, "") == key:
			continue
		_diary_key[s.id] = key
		var lines: Array = _diary.get(s.id, [])
		lines.append("%02d:00  %s" % [state.clock.hour, LifeStory.describe(state, s, _spots.get(s.id, {}),
			kit.layout["farm"])])
		_diary[s.id] = lines.slice(-SurvivorCard.LOG_LINES)


func _update_card() -> void:
	if not _card.is_open():
		return
	for s: Survivor in state.survivors:
		if s.id == _card.survivor_id:
			if not s.is_alive():
				_card.close()
				return
			_card.show_lines(s.name, LifeStory.describe(state, s, _spots.get(s.id, {}), kit.layout["farm"]),
				LifeStory.card(state, s), _diary.get(s.id, []))


## A slot under the mouse: the camera ray meets the roof (y = 0) inside the slot's footprint.
func _slot_at(screen: Vector2) -> int:
	var cam: Camera3D = get_viewport().get_camera_3d()
	var from: Vector3 = cam.project_ray_origin(screen)
	var dir: Vector3 = cam.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return -1
	var hit: Vector3 = from + dir * (-from.y / dir.y)
	for i: int in state.rooms.size():
		if _slot_rect(i).has_point(Vector2(hit.x, hit.z)):
			return i
	return -1


func _slot_rect(i: int) -> Rect2:
	var size: Vector2 = Vector2(6.0, 4.5) if state.rooms[i].size == "large" else Vector2(3.0, 3.0)
	var c: Vector3 = kit.slot_transform(i).origin
	return Rect2(Vector2(c.x, c.z) - size * 0.5, size)


func _step_slot(dir: int) -> void:
	var n: int = state.rooms.size()
	_select(posmod((_panel.slot if _panel.slot >= 0 else (-1 if dir > 0 else 0)) + dir, n))


## Opens the panel on slot `i`, outlines it on the roof and swings the camera over it.
func _select(i: int) -> void:
	_panel.open(i)
	for c: Node in _frame.get_children():
		c.queue_free()
	var rect: Rect2 = _slot_rect(i)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.8, 0.4)
	var w: float = 0.08
	for side: Array in [[Vector2(rect.size.x, w), Vector2(0.0, -rect.size.y * 0.5)],
			[Vector2(rect.size.x, w), Vector2(0.0, rect.size.y * 0.5)],
			[Vector2(w, rect.size.y), Vector2(-rect.size.x * 0.5, 0.0)],
			[Vector2(w, rect.size.y), Vector2(rect.size.x * 0.5, 0.0)]]:
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3((side[0] as Vector2).x, 0.04, (side[0] as Vector2).y)
		box.material = mat
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = box
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var c: Vector2 = rect.get_center() + (side[1] as Vector2)
		mi.position = Vector3(c.x, 0.03, c.y)
		_frame.add_child(mi)
	_frame.visible = true
	var to: Vector3 = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(_rig, "position", to, 0.35)


## The player changed SimCore (built, queued, pinned, F5): daily life looks again now, the roof redraws.
func _on_player_changed() -> void:
	LifeRules.decide(state)
	_refresh_rooms()
	_place(false)
	_fires_now()


func _process(delta: float) -> void:
	var real_dt: float = minf((Time.get_ticks_msec() - _last_ms) / 1000.0, 0.1)
	_pan()
	if _observing:
		_direct(real_dt)
	_update_card()
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


## WASD / left stick moves the camera over the roof (real time, so it works paused or at 10×): close zoom is for
## the details.
func _pan() -> void:
	var now: int = Time.get_ticks_msec()
	var dt: float = minf((now - _last_ms) / 1000.0, 0.1)
	_last_ms = now
	var v: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if not _panel.is_open():  # the left stick moves the panel's focus while it is open
		v += Input.get_vector("move_left", "move_right", "move_up", "move_down")
	elif Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) \
			or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D):
		v += Input.get_vector("move_left", "move_right", "move_up", "move_down")
	v = v.limit_length(1.0)
	if v == Vector2.ZERO:
		return
	var move: Vector3 = (_rig.basis * Vector3(v.x, 0.0, v.y))
	move.y = 0.0
	_rig.position += move.normalized() * v.length() * PAN_SPEED * dt
	_rig.position = _rig.position.clamp(Vector3(-PAN_LIMIT, 0.0, -PAN_LIMIT), Vector3(PAN_LIMIT, 0.0, PAN_LIMIT))


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
	_fires_now()
	_barrels_now()
	_panel.refresh()


## The kitchen fire burns while someone cooks or sits by it, and from 17:00 to 23:00 anyway.
func _fires_now() -> void:
	var h: int = state.clock.hour
	for kf: Array in _kitchen_fires:
		var busy: bool = false
		for s: Survivor in state.living():
			busy = busy or (s.needs.doing == "work" and s.needs.doing_slot == kf[0])
		(kf[1] as BaseFire).lit = busy or (h >= 17 and h < 23)


## The drums: out at 07:00; from 18:00 on, each unlit one gets an errand: whoever is up and free (not asleep, hurt,
## working or away) walks over, kneels and lights it.
func _barrels_now() -> void:
	var h: int = state.clock.hour
	var night: bool = h >= 18 or h < 6
	for b: Dictionary in _barrels:
		var fire: BaseFire = b["fire"]
		if not night:
			fire.lit = false
			b["pending"] = false
			continue
		if fire.lit or b["pending"]:
			continue
		var pick: Resident = null
		var best: float = INF
		for s: Survivor in state.living():
			var r: Resident = _residents.get(s.id)
			if r == null or r.busy() or not NeedRules.activity(s, h) in ["socialise", "idle", "read", "exercise"]:
				continue
			var d: float = r.position.distance_to(b["pos"])
			if d < best:
				best = d
				pick = r
		if pick == null:
			continue
		var pos: Vector3 = b["pos"]
		var from: Vector3 = (pick.position - pos)
		from.y = 0.0
		from = from.normalized() if from.length() > 0.1 else Vector3.BACK
		var at: Vector3 = pos + from * 0.6
		b["pending"] = true
		pick.errand(at, atan2(pos.x - at.x, pos.z - at.z), 1.5, func() -> void:
			fire.lit = true
			b["pending"] = false
			_log.text = "%02d:00  %s lit a fire drum" % [state.clock.hour, pick.tag.text])


func _lit_barrels() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for b: Dictionary in _barrels:
		if (b["fire"] as BaseFire).lit:
			out.append(b["pos"])
	return out


## Crops on the farms' planters by growth stage (FarmLook), rebuilt when a stage changes.
func _refresh_crops() -> void:
	var farm: Dictionary = kit.layout["farm"]
	var sig: PackedStringArray = PackedStringArray()
	var place: Array[Array] = []
	for i: int in state.rooms.size():
		var r: RoomState = state.rooms[i]
		if r.room != "farm" or r.tier <= 0:
			continue
		var plots: Array[Vector3] = kit.plots(i, r)
		for k: int in plots.size():
			var key: String = FarmLook.model_key(i, r, k, plots.size(), farm)
			sig.append(key)
			place.append([key, plots[k]])
	if sig == _crop_sig:
		return
	_crop_sig = sig
	for c: Node in _crops_root.get_children():
		c.queue_free()
	for p: Array in place:
		var model: Node3D = (load(kit.kit[p[0]]["model"]) as PackedScene).instantiate() as Node3D
		model.position = p[1]
		_crops_root.add_child(model)
		Style15Level.apply_materials(model, Style15Level.SURFACE_MATERIAL)


## Room models by tier, and the nav grid round them, when anything changed; crops every time.
func _refresh_rooms() -> void:
	_refresh_crops()
	var sig: PackedStringArray = PackedStringArray()
	for r: RoomState in state.rooms:
		sig.append("%s|%s" % [BaseKit.model_key(r), BaseKit.upgrading(r)])
	if sig == _room_sig:
		return
	_room_sig = sig
	for c: Node in _rooms_root.get_children():
		c.queue_free()
	_kitchen_fires.clear()
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
		for f: Array in kit.fires(i, r):
			var fire: BaseFire = BaseFire.new(f[1])
			fire.position = f[0]
			_rooms_root.add_child(fire)
			_kitchen_fires.append([i, fire])
	for pos: Vector3 in kit.barrels():
		nav.block(Vector2(pos.x, pos.z), Vector2(0.65, 0.65))
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
	var spots: Dictionary = LifeSpots.assign(state, kit, _lit_barrels())
	_spots = spots
	_write_diary()
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
	_hud = layer
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
	help.text = "Click a slot / Tab (RB / LB) to manage it · click a survivor (X) for their card · O (Back) Observer · 1 / 2 / 3 (LT / RT) speed · Space (Y) pause · WASD pan · wheel zoom · Q / E turn · F5 test bases · F3 who does what"
	help.add_theme_font_size_override("font_size", 14)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	help.custom_minimum_size.x = 640.0  # clear of the slot panel on the right
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
