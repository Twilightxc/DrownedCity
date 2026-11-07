class_name BasePanel
extends CanvasLayer
## The base's slot panel (PHASE1 1.7 step 4): pick a slot, then build a room there, upgrade it, run its production
## queue, pin survivors to it or tear it down. Every action is a BaseRules call on SimCore; `changed` tells the scene
## to redraw. Buttons take focus, so the pad drives it all: D-pad / stick moves, A presses, B closes; LB / RB (Tab /
## Shift+Tab, or a click on the roof) pick the slot. A stock bar sits at the bottom left.

signal changed  ## SimCore was changed by the player: rooms, queues or pins
signal closed

const PANEL_W: float = 380.0
const JOB_COUNTS: Array[int] = [1, 5, -1]  ## the add-job buttons: one, five, keep going

var state: SimState
var slot: int = -1  ## the slot shown; -1 = closed

var _root: PanelContainer
var _box: VBoxContainer
var _stock: Label
var _confirm_demolish: bool = false


func _ready() -> void:
	layer = 40
	var top: PanelContainer = PanelContainer.new()
	top.add_theme_stylebox_override("panel", _style(0.75, 8.0))
	top.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	top.grow_vertical = Control.GROW_DIRECTION_BEGIN
	top.offset_left = 12.0
	top.offset_bottom = -12.0
	add_child(top)
	_stock = Label.new()
	_stock.add_theme_font_size_override("font_size", 15)
	top.add_child(_stock)
	_root = PanelContainer.new()
	_root.add_theme_stylebox_override("panel", _style(0.9, 16.0))
	_root.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_root.offset_left = -PANEL_W - 12.0
	_root.offset_right = -12.0
	_root.offset_top = 12.0
	_root.offset_bottom = -40.0  # the build label stays readable below it
	add_child(_root)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_root.add_child(scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open(i: int) -> void:
	slot = i
	_confirm_demolish = false
	_root.visible = true
	refresh(true)


func close() -> void:
	slot = -1
	_root.visible = false
	closed.emit()


## Rebuilds the panel from SimCore (each game hour, after each action). The focused button keeps its place.
func refresh(focus_first: bool = false) -> void:
	_update_stock()
	if not is_open() or state == null:
		return
	var focused: int = _focused_index()
	for c: Node in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var r: RoomState = state.rooms[slot]
	var def: Dictionary = BaseRules.room_def(r.room)
	_title(tr("Slot %d · %s") % [slot + 1, tr(r.size.capitalize())],
		tr("Empty") if r.room.is_empty() else str(def["name"]))
	if r.room.is_empty():
		_build_choices(r)
	else:
		_room_info(r, def)
		if r.tier > 0:
			_upgrade(r, def)
			_production(r, def)
		_workers(r)
		_demolish()
	var buttons: Array[Button] = _buttons()
	if buttons.is_empty():
		return
	if focus_first or focused < 0:
		_first_enabled(buttons).grab_focus()
	else:
		buttons[mini(focused, buttons.size() - 1)].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed
			and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B)):
		close()
		get_viewport().set_input_as_handled()


# --- sections ------------------------------------------------------------------------------------------------------

func _build_choices(r: RoomState) -> void:
	_heading(tr("Build"))
	var rooms: Dictionary = BaseRules.data()["rooms"]
	for id: String in rooms:
		if str(rooms[id]["size"]) != r.size:
			continue
		var t1: Dictionary = (rooms[id]["tiers"] as Array)[0]
		var problem: String = BaseRules.build_problem(state, slot, id)
		var b: Button = _button(tr("%s — %s") % [rooms[id]["name"], t1["name"]], func() -> void:
			if BaseRules.build(state, slot, id):
				_changed())
		_note(_cost_text(t1) + _why(problem))
		b.disabled = not problem.is_empty()


func _room_info(r: RoomState, def: Dictionary) -> void:
	var tiers: Array = def["tiers"]
	if r.tier > 0:
		_line(tr("Tier %d: %s") % [r.tier, (tiers[r.tier - 1] as Dictionary)["name"]])
		var t: Dictionary = BaseRules.tier_def(r)
		var facts: PackedStringArray = PackedStringArray()
		if t.has("beds"):
			facts.append(tr("%d beds") % int(t["beds"]))
		if t.has("guards"):
			facts.append(tr("%d guard posts") % int(t["guards"]))
		for res: String in t.get("per_day", {}):
			facts.append(tr("+%s %s a day") % [_num(float(t["per_day"][res])), tr(res)])
		if not facts.is_empty():
			_note(" · ".join(facts))
	if r.building > 0:
		var total: float = float((tiers[r.building - 1] as Dictionary)["build_hours"])
		_line(tr("Building %s: %s / %s work hours") % [(tiers[r.building - 1] as Dictionary)["name"],
			_num(total - r.build_left), _num(total)])
		_bar(1.0 - r.build_left / total)
		if _working_here().is_empty():
			_note(tr("Nobody is working on it."))


func _upgrade(r: RoomState, def: Dictionary) -> void:
	var tiers: Array = def["tiers"]
	if r.building > 0 or r.tier >= tiers.size():
		return
	var next: Dictionary = tiers[r.tier]
	var problem: String = BaseRules.upgrade_problem(state, slot)
	var b: Button = _button(tr("Upgrade to %s") % next["name"], func() -> void:
		if BaseRules.upgrade(state, slot):
			_changed())
	b.disabled = not problem.is_empty()
	_note(_cost_text(next) + _why(problem))


func _production(r: RoomState, def: Dictionary) -> void:
	var t: Dictionary = BaseRules.tier_def(r)
	var room_size: int = int(t.get("queue", 0))
	if room_size <= 0:
		return
	_heading(tr("Production (%d / %d)") % [r.queue.size(), room_size])
	for j: int in r.queue.size():
		var job: Dictionary = r.queue[j]
		var rec: Dictionary = BaseRules.recipe(job["recipe"])
		var count: String = "∞" if int(job["count"]) < 0 else "×%d" % int(job["count"])
		var text: String = "%s %s" % [rec["name"], count]
		if j == 0:
			text += "  ·  %s / %s h" % [_num(r.progress), _num(float(rec["work_hours"]))]
		var row: HBoxContainer = HBoxContainer.new()
		_box.add_child(row)
		var label: Label = Label.new()
		label.text = text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)
		var cancel: Button = Button.new()
		cancel.text = tr("Cancel")
		cancel.pressed.connect(func() -> void:
			BaseRules.cancel_job(state, slot, j)
			_changed())
		row.add_child(cancel)
		if j == 0:
			_bar(r.progress / float(rec["work_hours"]))
			var stalled: String = _stalled(r, rec)
			if not stalled.is_empty():
				_note(stalled)
	for id: String in def.get("recipes", []):
		var rec: Dictionary = BaseRules.recipe(id)
		if int(rec.get("tier", 1)) > r.tier:
			continue
		_note(tr("%s: %s → %s, %s h") % [rec["name"], _inputs_text(rec), _res_text(rec.get("outputs", {})),
			_num(float(rec["work_hours"]))] + (tr(" (needs Pathology)") if rec.has("needs_perk") else ""))
		var row: HBoxContainer = HBoxContainer.new()
		_box.add_child(row)
		for count: int in JOB_COUNTS:
			var b: Button = Button.new()
			b.text = tr("+ keep going") if count < 0 else tr("+%d") % count
			b.disabled = r.queue.size() >= room_size
			b.pressed.connect(func() -> void:
				if BaseRules.queue_job(state, slot, id, count):
					_changed())
			row.add_child(b)


func _workers(r: RoomState) -> void:
	_heading(tr("People"))
	_note(tr("Daily life sends people where they're needed. Pin someone to keep them working here only."))
	for s: Survivor in state.living():
		var here: bool = s.assignment == slot
		var now: String = NeedRules.activity(s, state.clock.hour)
		var where: String = ""
		if now == "work" and s.needs.doing_slot >= 0:
			where = " · %s" % BaseRules.room_def(state.rooms[s.needs.doing_slot].room).get("name", "")
		var pinned_elsewhere: String = ""
		if s.assignment >= 0 and not here:
			pinned_elsewhere = tr(" (pinned to slot %d)") % (s.assignment + 1)
		var b: Button = _button("%s — %s%s%s" % [s.name, tr(now), where, pinned_elsewhere], func() -> void:
			BaseRules.assign(state, s, -1 if s.assignment == slot else slot)
			_changed())
		b.text = (tr("PINNED · ") if here else "") + b.text
		b.tooltip_text = tr("Unpin") if here else tr("Pin here")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT


func _demolish() -> void:
	var b: Button = _button(tr("Really tear it down? Materials are lost") if _confirm_demolish else tr("Demolish"),
		func() -> void:
			if not _confirm_demolish:
				_confirm_demolish = true
				refresh()
				return
			BaseRules.demolish(state, slot)
			_confirm_demolish = false
			_changed())
	b.modulate = Color(1.0, 0.75, 0.7)


# --- helpers -------------------------------------------------------------------------------------------------------

func _changed() -> void:
	changed.emit()
	refresh()


func _working_here() -> Array[Survivor]:
	var out: Array[Survivor] = []
	for s: Survivor in state.living():
		if s.needs.doing == "work" and s.needs.doing_slot == slot:
			out.append(s)
	return out


## Why the first job can't run, or "": its inputs aren't in stock, or nobody has the perk it needs.
func _stalled(r: RoomState, rec: Dictionary) -> String:
	if rec.has("needs_perk"):
		var able: bool = false
		for s: Survivor in state.living():
			able = able or CommunityRules.room_mods(s).has_perk(StringName(rec["needs_perk"]))
		if not able:
			return tr("Stalled: nobody here can make it.")
	if not r.started:
		var inputs: Dictionary = rec.get("inputs", {})
		for res: String in inputs:
			if state.stock.get(res, 0.0) + 0.0001 < float(inputs[res]):
				return tr("Stalled: not enough %s.") % tr(res)
	return ""


func _update_stock() -> void:
	if state == null:
		return
	var parts: PackedStringArray = PackedStringArray()
	for res: String in ["food", "meals", "water", "materials", "herbs", "medicine", "antiviral", "ammo"]:
		parts.append("%s %s" % [tr(res.capitalize()), _num(state.stock.get(res, 0.0))])
	_stock.text = "   ".join(parts)


func _cost_text(tier: Dictionary) -> String:
	return tr("Cost: %s · %s work hours") % [_res_text(tier.get("build", {})), _num(float(tier["build_hours"]))]


func _inputs_text(rec: Dictionary) -> String:
	var inputs: Dictionary = rec.get("inputs", {})
	return tr("nothing") if inputs.is_empty() else _res_text(inputs)


func _res_text(amounts: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for res: String in amounts:
		parts.append("%s %s" % [_num(float(amounts[res])), tr(res)])
	return ", ".join(parts) if not parts.is_empty() else tr("nothing")


func _why(problem: String) -> String:
	return "" if problem.is_empty() else "  —  " + tr(problem)


static func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


func _title(a: String, b: String) -> void:
	var l: Label = Label.new()
	l.text = a
	l.add_theme_font_size_override("font_size", 13)
	l.modulate = Color(1, 1, 1, 0.7)
	_box.add_child(l)
	var t: Label = Label.new()
	t.text = b
	t.add_theme_font_size_override("font_size", 24)
	_box.add_child(t)


func _heading(text: String) -> void:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(1.0, 0.82, 0.55))
	_box.add_child(l)


func _line(text: String) -> void:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", 15)
	_box.add_child(l)


func _note(text: String) -> void:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", 13)
	l.modulate = Color(1, 1, 1, 0.75)
	_box.add_child(l)


func _bar(frac: float) -> void:
	var p: ProgressBar = ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 1.0
	p.value = clampf(frac, 0.0, 1.0)
	p.show_percentage = false
	p.custom_minimum_size.y = 8.0
	_box.add_child(p)


func _button(text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size.y = 34.0
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.pressed.connect(action)
	_box.add_child(b)
	return b


func _buttons() -> Array[Button]:
	var out: Array[Button] = []
	for n: Node in _box.find_children("*", "Button", true, false):
		out.append(n as Button)
	return out


func _first_enabled(buttons: Array[Button]) -> Button:
	for b: Button in buttons:
		if not b.disabled:
			return b
	return buttons[0]


func _focused_index() -> int:
	var f: Control = _root.get_viewport().gui_get_focus_owner() if _root.is_inside_tree() else null
	return _buttons().find(f) if f is Button else -1


static func _style(alpha: float, margin: float) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.09, alpha)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(margin)
	return sb
