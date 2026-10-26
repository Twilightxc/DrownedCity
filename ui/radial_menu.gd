class_name RadialMenu
extends Control
## Hold-to-open command wheel (GDD §5 team orders). Items run clockwise from the top. The
## owner feeds a pointer: the right stick, or mouse motion accumulated since opening (works on
## the web without pointer lock). Releasing the button picks the highlighted item.

@export var radius: float = 160.0
@export var inner_radius: float = 45.0
@export var stick_deadzone: float = 0.5
@export var items: PackedStringArray = PackedStringArray()
@export var fill: Color = Color(0.1, 0.12, 0.13, 0.75)
@export var highlight: Color = Color(0.95, 0.6, 0.25, 0.9)
@export var font_size: int = 16

var selected: int = -1

var _center: Vector2 = Vector2.ZERO
var _mouse_offset: Vector2 = Vector2.ZERO


## Item under pointer `v` (screen space, y down), or -1 inside the dead zone.
static func index_for(v: Vector2, count: int, deadzone: float) -> int:
	if count <= 0 or v.length() < deadzone:
		return -1
	var angle: float = atan2(v.x, -v.y)  # 0 = up, clockwise
	var step: float = TAU / count
	return int(fposmod(angle + step * 0.5, TAU) / step) % count


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open(center: Vector2) -> void:
	_center = center
	_mouse_offset = Vector2.ZERO
	selected = -1
	visible = true
	queue_redraw()


## Hides the wheel and returns the picked item (-1 = cancelled).
func close() -> int:
	visible = false
	return selected


## Keeps the last pick when the stick springs back, so letting go of the stick first doesn't cancel.
func point_stick(v: Vector2) -> void:
	if v.length() >= stick_deadzone:
		_select(index_for(v, items.size(), stick_deadzone))


func point_mouse(relative: Vector2) -> void:
	_mouse_offset = (_mouse_offset + relative).limit_length(radius)
	_select(index_for(_mouse_offset, items.size(), inner_radius))


func _select(i: int) -> void:
	if i != selected:
		selected = i
		queue_redraw()


func _draw() -> void:
	var n: int = items.size()
	if n == 0:
		return
	var step: float = TAU / n
	var font: Font = get_theme_default_font()
	for i: int in n:
		var a0: float = i * step - step * 0.5
		var points: PackedVector2Array = PackedVector2Array()
		for k: int in 9:
			points.append(_center + _dir(a0 + step * k / 8.0) * radius)
		for k: int in range(8, -1, -1):
			points.append(_center + _dir(a0 + step * k / 8.0) * inner_radius)
		draw_colored_polygon(points, highlight if i == selected else fill)
		draw_polyline(points, Color(1, 1, 1, 0.25), 1.0, true)
		var label: String = tr(items[i])
		var mid: Vector2 = _center + _dir(i * step) * (inner_radius + radius) * 0.5
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, mid + Vector2(-width * 0.5, font_size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)


static func _dir(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle))
