extends "res://game/spikes/horde_spike.gd"
## Spike C (Phase 0.5): does twin-stick feel right with mouse + keyboard AND gamepad?
## Spike B scene + horde, plus what 0.5 asks for on top of the harness: supply crates to
## interact with, the hold-to-open orders wheel, and the F4 / Start live tuning panel.

const ORDERS: Array[String] = ["Follow me", "Hold here", "Attack target", "Hold fire", "Search room", "Back to boat"]
const TOAST_TIME: float = 1.5

@export var crate_positions: PackedVector2Array = PackedVector2Array([Vector2(-8, 3), Vector2(6, -4)])

var _radial: RadialMenu
var _tuning: TuningPanel
var _toast: Label
var _toast_left: float = 0.0


func _ready() -> void:
	super._ready()
	for p: Vector2 in crate_positions:
		var crate: SupplyCrate = SupplyCrate.new()
		crate.position = Vector3(p.x, GROUND_Y, p.y)
		add_child(crate)
	_build_twin_stick_ui()
	_build_tuning()


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event.is_action_pressed("radial_menu"):
		_open_radial()
	elif event.is_action_released("radial_menu"):
		_close_radial(true)
	elif _radial.visible and event.is_action_pressed("ui_cancel"):
		_close_radial(false)
	elif _radial.visible and event is InputEventMouseMotion:
		_radial.point_mouse((event as InputEventMouseMotion).relative)


func _process(delta: float) -> void:
	super._process(delta)
	if _radial.visible and _player.using_pad:
		_radial.point_stick(Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.0))
	if _toast_left > 0.0:
		_toast_left -= delta / Engine.time_scale  # real seconds, also while the wheel slows time
		_toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _open_radial() -> void:
	if _radial.visible:
		return
	_radial.open(get_viewport().get_visible_rect().size * 0.5)
	_player.aim_locked = true
	Engine.time_scale = _player.controls.radial_time_scale


func _close_radial(pick: bool) -> void:
	if not _radial.visible:
		return
	var i: int = _radial.close()
	_player.aim_locked = false
	Engine.time_scale = 1.0
	if pick and i >= 0:
		_toast.text = "Order: %s" % ORDERS[i]
		_toast_left = TOAST_TIME


func _help_text(pad: bool) -> String:
	if pad:
		return super._help_text(pad) + "\nInteract A · Orders hold Y (R-stick picks, B cancels) · Start: tuning"
	return super._help_text(pad) + "\nInteract F · Orders hold Tab (mouse picks, Esc cancels) · F4: tuning"


func _build_twin_stick_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 55
	add_child(layer)
	_radial = RadialMenu.new()
	_radial.items = PackedStringArray(ORDERS)
	layer.add_child(_radial)
	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 64.0
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.modulate.a = 0.0
	layer.add_child(_toast)


func _build_tuning() -> void:
	var c: TwinStickConfig = _player.controls
	_tuning = TuningPanel.new()
	add_child(_tuning)
	_tuning.add_float("Move speed (m/s)", c, "move_speed", 2.0, 8.0, 0.1)
	_tuning.add_float("Accel (m/s²)", c, "move_accel", 5.0, 120.0, 1.0)
	_tuning.add_float("Decel (m/s²)", c, "move_decel", 5.0, 120.0, 1.0)
	_tuning.add_float("Stick deadzone", c, "stick_deadzone", 0.05, 0.5, 0.01)
	_tuning.add_float("Mouse aim plane (m)", c, "aim_plane_height", 0.0, 1.8, 0.05)
	_tuning.add_bool("Aim line", c, "aim_line")
	_tuning.add_bool("Pad auto-fire (R-stick)", c, "pad_auto_fire")
	_tuning.add_bool("Aim assist (pad)", c, "aim_assist")
	_tuning.add_float("Assist cone (± deg)", c, "aim_assist_cone_deg", 0.0, 30.0, 1.0)
	_tuning.add_float("Assist strength", c, "aim_assist_strength", 0.0, 1.0, 0.05)
	_tuning.add_float("Assist range (m)", c, "aim_assist_range", 4.0, 30.0, 1.0)
	_tuning.add_float("Pad throw range (m)", c, "pad_throw_range", 2.0, 12.0, 0.5)
	_tuning.add_float("Orders wheel time scale", c, "radial_time_scale", 0.05, 1.0, 0.05)
	_tuning.add_float("Camera turn time (s)", _rig, "rotate_time", 0.05, 0.6, 0.01)
