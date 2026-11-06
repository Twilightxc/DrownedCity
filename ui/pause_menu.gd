class_name PauseMenu
extends CanvasLayer
## Esc / pad Start pauses the game (J 2026-11-06): Resume, Restart, and the controls for the device in use.
## Buttons take focus, so the pad's D-pad / stick and A drive it; B, Esc or Start again resumes.

signal restart_pressed

var can_open: Callable = func() -> bool: return true  ## the scene says no while a wheel or a summary is up
var help_text: Callable = func(_pad: bool) -> String: return ""
var using_pad: Callable = func() -> bool: return false

var _root: Control
var _resume: Button
var _help: Label


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_root.add_child(dim)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", card_style())
	_root.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title: Label = Label.new()
	title.text = tr("PAUSED")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	_resume = _button(box, tr("Resume"), close)
	_button(box, tr("Restart"), func() -> void: restart_pressed.emit())
	_help = Label.new()
	_help.add_theme_font_size_override("font_size", 13)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD
	_help.custom_minimum_size.x = 520.0
	box.add_child(_help)
	_root.visible = false


## A dark card with room around its content (the pause menu, the run summary).
static func card_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.09, 0.9)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(22.0)
	return sb


func _button(box: Container, text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240.0, 40.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(action)
	box.add_child(b)
	return b


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if is_open() or get_tree().paused or not can_open.call():
		return
	_help.text = tr("Controls") + "\n" + str(help_text.call(using_pad.call()))
	_root.visible = true
	get_tree().paused = true
	_resume.grab_focus()


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if is_open():
			close()
		else:
			open()
		if is_open() or not get_tree().paused:
			get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
