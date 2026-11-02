class_name CrosshairHud
extends CanvasLayer
## Crosshair, hit markers and the kill chain (Phase 1 step 1.4). The crosshair sits on the mouse (or, with
## a pad, on the aim point) and opens with the gun's current spread; a white X flashes on a hit, a red one
## on a kill; the chain counter grows with the combo and fades as its window runs out.

const PX_PER_DEG: float = 7.0
const PAD_AIM_DIST: float = 8.0  ## m along the aim when using the pad

var player: SpikePlayer
var chain: KillChain

var _draw: Control
var _chain_label: Label
var _marker_left: float = 0.0
var _marker_kill: bool = false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS  # brings the cursor back while the F4 panel pauses the game
	_draw = Control.new()
	_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_on_draw)
	add_child(_draw)
	_chain_label = Label.new()
	_chain_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_chain_label.offset_left = -260.0
	_chain_label.offset_right = -40.0
	_chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chain_label.add_theme_font_size_override("font_size", 34)
	_chain_label.add_theme_constant_override("outline_size", 8)
	_chain_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_chain_label)


func bind(p: SpikePlayer, c: KillChain) -> void:
	player = p
	chain = c
	player.hit_confirmed.connect(func(kills: int) -> void:
		_marker_kill = kills > 0
		_marker_left = 0.2 if kills > 0 else 0.12)


func _process(delta: float) -> void:
	if player == null:
		return
	_marker_left = maxf(_marker_left - delta, 0.0)
	# The OS cursor hides while playing with the mouse; menus and pauses get it back.
	var hide_cursor: bool = not player.using_pad and not get_tree().paused and player.health.is_alive()
	var want: Input.MouseMode = Input.MOUSE_MODE_HIDDEN if hide_cursor else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want
	if chain != null and chain.chain >= 2:
		_chain_label.visible = true
		_chain_label.text = tr("x%d chain") % chain.chain
		_chain_label.modulate.a = 0.35 + 0.65 * chain.freshness()
	else:
		_chain_label.visible = false
	_draw.queue_redraw()


func _on_draw() -> void:
	if player == null or not player.health.is_alive() or get_tree().paused:
		return
	var at: Vector2
	if player.using_pad:
		var p: Vector2 = player.ground_position() + player.aim_dir * PAD_AIM_DIST
		at = player.camera.unproject_position(Vector3(p.x, player.ground_y + 0.9, p.y))
	else:
		at = _draw.get_viewport().get_mouse_position()
	var gap: float = 5.0 + player.gun.shot_spread_deg() * PX_PER_DEG
	var col: Color = Color(1, 1, 1, 0.85)
	for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		_draw.draw_line(at + d * gap, at + d * (gap + 8.0), Color(0, 0, 0, 0.6), 4.0)
		_draw.draw_line(at + d * gap, at + d * (gap + 8.0), col, 2.0)
	if _marker_left > 0.0:
		var mc: Color = Color(1.0, 0.25, 0.2) if _marker_kill else Color(1, 1, 1)
		var s: float = 7.0 + (4.0 if _marker_kill else 0.0)
		for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_draw.draw_line(at + d * 3.0, at + d * s, mc, 2.5)
