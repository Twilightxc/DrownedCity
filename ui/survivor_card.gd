class_name SurvivorCard
extends CanvasLayer
## The survivor card (GDD §4 Observer, §7 "survivor card"): click someone on the roof (pad X steps through people)
## to see who they are, what they're doing in words, body and mind, skills, and a short log of their day. Esc / pad
## B closes it. It stays up in Observer mode, where the camera follows whoever it shows.

const LOG_LINES: int = 6

var survivor_id: int = -1  ## -1 = closed

var _root: PanelContainer
var _name: Label
var _doing: Label
var _facts: Label
var _log: Label


func _ready() -> void:
	layer = 45
	_root = PanelContainer.new()
	_root.add_theme_stylebox_override("panel", BasePanel._style(0.88, 14.0))
	_root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.offset_left = 12.0
	_root.offset_bottom = -56.0  # above the stock bar
	_root.custom_minimum_size.x = 430.0
	add_child(_root)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_root.add_child(box)
	_name = _label(box, 24)
	_doing = _label(box, 16)
	_doing.add_theme_color_override("font_color", Color(1.0, 0.82, 0.55))
	_facts = _label(box, 13)
	_log = _label(box, 13)
	_log.modulate = Color(1, 1, 1, 0.8)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open(id: int) -> void:
	survivor_id = id
	_root.visible = true


func close() -> void:
	survivor_id = -1
	_root.visible = false


## Fills the card: `doing` from LifeStory.describe, `facts` from LifeStory.card, `entries` (the log) newest last.
func show_lines(who: String, doing: String, facts: PackedStringArray, entries: Array) -> void:
	_name.text = who
	_doing.text = doing
	_facts.text = "\n".join(facts)
	var lines: PackedStringArray = PackedStringArray()
	for entry: Variant in entries.slice(-LOG_LINES):
		lines.append(str(entry))
	_log.text = tr("Today") + "\n" + "\n".join(lines) if not lines.is_empty() else ""


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed
			and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B)):
		close()
		get_viewport().set_input_as_handled()


func _label(box: Container, size: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size.x = 400.0
	box.add_child(l)
	return l
