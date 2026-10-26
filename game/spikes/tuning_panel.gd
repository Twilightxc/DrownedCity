class_name TuningPanel
extends CanvasLayer
## F4 / Start: live feel tuning for J's playtests. Pauses the game while open; sliders edit the
## loaded resources in memory only (a reload restores data/). Gamepad: D-pad/left stick moves
## and adjusts, A toggles, B or Start closes. The summary line is meant for a screenshot.

class Entry:
	var target: Object
	var property: String
	var is_bool: bool


var _rows: VBoxContainer
var _summary: Label
var _first: Control
var _entries: Array[Entry] = []


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = 16.0
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	var title: Label = Label.new()
	title.text = "Feel tuning (paused) · F4 / Start / B: close · not saved"
	box.add_child(title)
	_rows = VBoxContainer.new()
	box.add_child(_rows)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD
	_summary.custom_minimum_size.x = 460.0
	_summary.add_theme_font_size_override("font_size", 11)
	box.add_child(_summary)


func add_float(label: String, target: Object, property: String, min_value: float, max_value: float, step: float) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = label
	name_label.custom_minimum_size.x = 190.0
	row.add_child(name_label)
	var slider: HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = float(target.get(property))
	slider.custom_minimum_size.x = 200.0
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label: Label = Label.new()
	value_label.custom_minimum_size.x = 56.0
	value_label.text = _fmt(slider.value)
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float) -> void:
		target.set(property, v)
		value_label.text = _fmt(v)
		_refresh_summary())
	_add_row(row, slider, target, property, false)


func add_bool(label: String, target: Object, property: String) -> void:
	var check: CheckBox = CheckBox.new()
	check.text = label
	check.button_pressed = bool(target.get(property))
	check.toggled.connect(func(on: bool) -> void:
		target.set(property, on)
		_refresh_summary())
	_add_row(check, check, target, property, true)


func _add_row(row: Control, focus: Control, target: Object, property: String, is_bool: bool) -> void:
	focus.focus_mode = Control.FOCUS_ALL
	_rows.add_child(row)
	if _first == null:
		_first = focus
	var e: Entry = Entry.new()
	e.target = target
	e.property = property
	e.is_bool = is_bool
	_entries.append(e)
	_refresh_summary()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tuning_panel") or (visible and event.is_action_pressed("ui_cancel")):
		_set_open(not visible)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	visible = open
	get_tree().paused = open
	if open and _first != null:
		_first.grab_focus()
	elif not open:
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused != null:
			focused.release_focus()


func _refresh_summary() -> void:
	var parts: PackedStringArray = PackedStringArray()
	for e: Entry in _entries:
		var v: Variant = e.target.get(e.property)
		parts.append("%s=%s" % [e.property, str(v) if e.is_bool else _fmt(float(v))])
	_summary.text = " ".join(parts)


static func _fmt(v: float) -> String:
	return ("%.2f" % v).trim_suffix("0").trim_suffix("0").trim_suffix(".")
