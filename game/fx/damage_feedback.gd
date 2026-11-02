class_name DamageFeedback
extends CanvasLayer
## What getting hurt looks like (Phase 1 step 1.3): a red screen edge that flashes on each hit and stays
## while HP is low, a short slow-mo when HP first drops below low_hp_frac (tunable, can be off), and the
## downed / dead message. Reads a FighterHealth; owns no game state except Engine.time_scale while slowed.

const EDGE_SHADER: String = """
shader_type canvas_item;
uniform float strength = 0.0;
uniform vec4 tint : source_color = vec4(0.75, 0.05, 0.04, 0.6);
void fragment() {
	vec2 d = abs(UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(0.72, 1.12, max(d.x, d.y) * 0.6 + length(d) * 0.4);
	COLOR = vec4(tint.rgb, tint.a * edge * strength);
}
"""

var health: FighterHealth

var _edge: ColorRect
var _mat: ShaderMaterial
var _label: Label
var _flash: float = 0.0
var _slowmo_until_ms: int = 0
var _was_low: bool = false


func _ready() -> void:
	layer = 50
	_edge = ColorRect.new()
	_edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = EDGE_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_edge.material = _mat
	add_child(_edge)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_constant_override("outline_size", 8)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.visible = false
	add_child(_label)


func bind(h: FighterHealth) -> void:
	health = h
	health.damaged.connect(func(amount: int, _kind: StringName) -> void:
		_flash = minf(_flash + 0.25 + amount / 40.0, 1.0))


func _process(delta: float) -> void:
	if health == null:
		return
	var real_delta: float = delta / maxf(Engine.time_scale, 0.01)
	_flash = maxf(_flash - real_delta * 2.5, 0.0)
	var low: float = 0.0
	var frac: float = health.hp_frac()
	var cfg: FighterConfig = health.config
	if health.is_alive() and frac < cfg.low_hp_frac:
		low = 0.35 + 0.15 * sin(Time.get_ticks_msec() / 180.0)  # a slow pulse while in danger
	if not health.is_alive():
		low = 0.8
	_mat.set_shader_parameter("strength", maxf(_flash, low))
	# Slow-mo once when HP first falls below the line.
	var is_low: bool = health.is_alive() and frac < cfg.low_hp_frac
	if is_low and not _was_low and cfg.slowmo:
		_slowmo_until_ms = Time.get_ticks_msec() + int(cfg.slowmo_sec * 1000.0)
		Engine.time_scale = cfg.slowmo_scale
	_was_low = is_low
	if _slowmo_until_ms > 0 and Time.get_ticks_msec() >= _slowmo_until_ms:
		_slowmo_until_ms = 0
		Engine.time_scale = 1.0
	match health.state:
		FighterHealth.State.DOWNED:
			_label.visible = true
			_label.text = tr("DOWNED · %d s · nobody to help") % ceili(health.downed_left)
		FighterHealth.State.DEAD:
			_label.visible = true
			_label.text = tr("YOU DIED · press R / X to restart")
		_:
			_label.visible = false


func _exit_tree() -> void:
	Engine.time_scale = 1.0
