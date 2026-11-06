class_name RadialMenu
extends Control
## Hold-to-open command wheel (GDD §5 team orders). Items run clockwise from the top; with offset_steps 0.5 the
## first item sits just right of the top, so an 8-slot wheel has 4 slots in its top half and 4 in its bottom
## half (the orders wheel: movement above, fire rule below, J 2026-11-06). The owner feeds a pointer: the right
## stick, or mouse motion accumulated since opening (works on the web without pointer lock). Releasing the
## button picks the highlighted item. Each item may have an icon (drawn in code, see _draw_icon); items in
## `active` are ringed.

@export var radius: float = 200.0
@export var inner_radius: float = 55.0
@export var stick_deadzone: float = 0.5
@export var items: PackedStringArray = PackedStringArray()
@export var icons: Array[StringName] = []  ## per item, &"" = none (follow, sneak, hold, stay, fire, hold_fire, quiet, melee)
@export var offset_steps: float = 0.0  ## the wheel turned clockwise by this many items
@export var fill: Color = Color(0.1, 0.12, 0.13, 0.75)
@export var highlight: Color = Color(0.95, 0.6, 0.25, 0.9)
@export var active_color: Color = Color(0.55, 0.95, 0.55, 0.95)
@export var font_size: int = 14

var selected: int = -1
var active: PackedInt32Array = PackedInt32Array()  ## items in force now (the current orders)

var _center: Vector2 = Vector2.ZERO
var _mouse_offset: Vector2 = Vector2.ZERO


## Item under pointer `v` (screen space, y down), or -1 inside the dead zone.
static func index_for(v: Vector2, count: int, deadzone: float, offset: float = 0.0) -> int:
	if count <= 0 or v.length() < deadzone:
		return -1
	var step: float = TAU / count
	var angle: float = atan2(v.x, -v.y) - offset * step  # 0 = up, clockwise
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
		_select(index_for(v, items.size(), stick_deadzone, offset_steps))


func point_mouse(relative: Vector2) -> void:
	_mouse_offset = (_mouse_offset + relative).limit_length(radius)
	_select(index_for(_mouse_offset, items.size(), inner_radius, offset_steps))


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
		var mid_angle: float = (i + offset_steps) * step
		var a0: float = mid_angle - step * 0.5
		var points: PackedVector2Array = PackedVector2Array()
		for k: int in 9:
			points.append(_center + _dir(a0 + step * k / 8.0) * radius)
		for k: int in range(8, -1, -1):
			points.append(_center + _dir(a0 + step * k / 8.0) * inner_radius)
		draw_colored_polygon(points, highlight if i == selected else fill)
		var is_active: bool = active.has(i)
		points.append(points[0])
		draw_polyline(points, active_color if is_active else Color(1, 1, 1, 0.25), 3.0 if is_active else 1.0, true)
		var mid: Vector2 = _center + _dir(mid_angle) * (inner_radius + radius) * 0.5
		var ink: Color = active_color if is_active and i != selected else Color.WHITE
		var icon: StringName = icons[i] if i < icons.size() else &""
		var label_at: Vector2 = mid
		if icon != &"":
			_draw_icon(icon, mid + Vector2(0.0, -9.0), 15.0, ink)
			label_at = mid + Vector2(0.0, 20.0)
		var label: String = tr(items[i])
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, label_at + Vector2(-width * 0.5, font_size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1,
				font_size, ink)


## Simple line icons, `s` = half their size.
func _draw_icon(icon: StringName, c: Vector2, s: float, col: Color) -> void:
	const W: float = 2.5
	match icon:
		&"follow":  # double chevron forward
			for dy: float in [-0.25, 0.35]:
				draw_polyline(PackedVector2Array([c + Vector2(-s * 0.7, dy * s + s * 0.35), c + Vector2(0, dy * s - s * 0.3),
						c + Vector2(s * 0.7, dy * s + s * 0.35)]), col, W, true)
		&"sneak":  # a low chevron over a dashed line: forward, quietly
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.7, s * 0.1), c + Vector2(0, -s * 0.5),
					c + Vector2(s * 0.7, s * 0.1)]), col, W, true)
			for k: int in 3:
				var x: float = -s * 0.8 + k * s * 0.6
				draw_line(c + Vector2(x, s * 0.6), c + Vector2(x + s * 0.35, s * 0.6), col, W, true)
		&"hold":  # a flag on a pole
			draw_line(c + Vector2(-s * 0.4, s), c + Vector2(-s * 0.4, -s), col, W, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, -s), c + Vector2(s * 0.7, -s * 0.55),
					c + Vector2(-s * 0.4, -s * 0.1)]), col)
		&"stay":  # an octagon (stop) with a bar
			var pts: PackedVector2Array = PackedVector2Array()
			for k: int in 9:
				pts.append(c + Vector2.from_angle(PI / 8.0 + k * TAU / 8.0) * s)
			draw_polyline(pts, col, W, true)
			draw_line(c + Vector2(-s * 0.5, 0), c + Vector2(s * 0.5, 0), col, W + 1.0, true)
		&"fire", &"hold_fire":  # crosshair; hold fire strikes it through
			draw_arc(c, s * 0.65, 0.0, TAU, 20, col, W, true)
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + d * s * 0.35, c + d * s, col, W, true)
			if icon == &"hold_fire":
				draw_line(c + Vector2(-s, s), c + Vector2(s, -s), Color(1.0, 0.35, 0.3, col.a), W + 1.0, true)
		&"quiet":  # a pistol with a long silencer
			draw_rect(Rect2(c + Vector2(-s, -s * 0.35), Vector2(s * 1.1, s * 0.4)), col)
			draw_rect(Rect2(c + Vector2(s * 0.15, -s * 0.28), Vector2(s * 0.85, s * 0.26)), col, false, W)
			draw_line(c + Vector2(-s * 0.75, 0.0), c + Vector2(-s * 0.85, s * 0.7), col, W + 1.5, true)
		&"melee":  # a knife, blade up-right
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.15, s * 0.15), c + Vector2(s * 0.85, -s * 0.85),
					c + Vector2(s * 0.15, s * 0.15)]), col)
			draw_line(c + Vector2(-s * 0.35, -s * 0.05), c + Vector2(s * 0.05, s * 0.35), col, W, true)
			draw_line(c + Vector2(-s * 0.1, s * 0.1), c + Vector2(-s * 0.75, s * 0.75), col, W + 2.0, true)


static func _dir(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle))
