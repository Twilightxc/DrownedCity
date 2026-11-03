class_name FighterHud
extends CanvasLayer
## The fighter's own HUD (PHASE1 1.5+ A4): HP and stamina bars at the bottom left, and a ring over each fighter's
## head that fills while it reloads (one step per shell for a pump shotgun; orange while clearing a jam). Downed,
## the HP bar becomes the time left to be helped up. Non-interactive, so nothing to navigate with a pad.

const BAR_SIZE: Vector2 = Vector2(260.0, 16.0)
const BAR_GAP: float = 8.0
const MARGIN: Vector2 = Vector2(24.0, 28.0)  ## from the bottom-left corner
const RING_RADIUS: float = 15.0
const RING_WIDTH: float = 5.0
const RING_HEIGHT: float = 2.25  ## m above the fighter's feet
const HP_COLOR: Color = Color(0.86, 0.22, 0.18)
const DOWNED_COLOR: Color = Color(0.55, 0.08, 0.08)
const STAMINA_COLOR: Color = Color(0.95, 0.72, 0.25)
const LOW_COLOR: Color = Color(1.0, 0.95, 0.85)
const RING_COLOR: Color = Color(1.0, 0.92, 0.6)
const JAM_COLOR: Color = Color(1.0, 0.55, 0.15)
const BACK_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const REVIVE_COLOR: Color = Color(0.45, 0.95, 0.45)
const MINI_BAR: Vector2 = Vector2(46.0, 5.0)  ## a teammate's HP over its head
const NAME_HEIGHT: float = 2.55  ## m: a teammate's name and HP bar

var player: SpikePlayer
## Every fighter that gets a reload ring (the player; teammates join in 1.5+ A5).
var fighters: Array[SpikePlayer] = []

var _draw: Control
var _font: Font
var _reload_from: Dictionary[SpikePlayer, Vector2i] = {}  ## per fighter: ammo when its reload began, rounds it loads
var _blink: float = 0.0


func _ready() -> void:
	layer = 39
	_draw = Control.new()
	_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_on_draw)
	add_child(_draw)
	_font = ThemeDB.fallback_font


func bind(p: SpikePlayer) -> void:
	player = p
	if not fighters.has(p):
		fighters.append(p)


func _process(delta: float) -> void:
	_blink += delta
	for f: SpikePlayer in fighters:
		_track_reload(f)
	_draw.queue_redraw()


## How far fighter `f`'s reload is, 0..1, or -1 when it isn't reloading. A pump shotgun's ring counts the shells
## this reload loads, so it fills one step per shell.
func reload_fill(f: SpikePlayer) -> float:
	var g: Gun = f.gun
	if g == null or not g.is_reloading():
		return -1.0
	if g.config.reload_per_round and not g.jammed and _reload_from.has(f):
		var from: Vector2i = _reload_from[f]
		return clampf((g.ammo - from.x + g.reload_progress()) / float(maxi(from.y, 1)), 0.0, 1.0)
	return clampf(g.reload_progress(), 0.0, 1.0)


## Shells this reload loads (the ring's steps), 1 for a magazine.
func reload_steps(f: SpikePlayer) -> int:
	var g: Gun = f.gun
	return _reload_from[f].y if g != null and g.config.reload_per_round and _reload_from.has(f) else 1


func _track_reload(f: SpikePlayer) -> void:
	var g: Gun = f.gun
	if g == null or not g.is_reloading():
		_reload_from.erase(f)
		return
	if not _reload_from.has(f):
		var left: int = f.pouch.count(g.config.caliber) if f.pouch != null else g.mag_size
		_reload_from[f] = Vector2i(g.ammo, maxi(mini(g.mag_size - g.ammo, left), 1))


func _on_draw() -> void:
	if player == null or get_tree().paused:
		return
	var size: Vector2 = _draw.size
	var x: float = MARGIN.x
	var y: float = size.y - MARGIN.y - BAR_SIZE.y * 2.0 - BAR_GAP
	var h: FighterHealth = player.health
	if h.state == FighterHealth.State.DOWNED:
		_bar(Vector2(x, y), h.downed_left / maxf(h.config.downed_sec, 0.01), DOWNED_COLOR,
			tr("DOWNED %d s") % ceili(h.downed_left))
	else:
		_bar(Vector2(x, y), h.hp_frac(), HP_COLOR, tr("HP %d") % h.hp)
	var m: FighterMotion = player.motion
	if m != null:
		var low: bool = m.stamina < m.config.sprint_min_stamina
		var col: Color = LOW_COLOR if low and fmod(_blink, 0.5) < 0.25 else STAMINA_COLOR
		_bar(Vector2(x, y + BAR_SIZE.y + BAR_GAP), m.stamina_fraction(), col, _stance_text(m))
	for f: SpikePlayer in fighters:
		if f != player:
			_tag(f)
		_ring(f)


func _bar(at: Vector2, fill: float, col: Color, text: String) -> void:
	_draw.draw_rect(Rect2(at - Vector2(2, 2), BAR_SIZE + Vector2(4, 4)), BACK_COLOR)
	_draw.draw_rect(Rect2(at, Vector2(BAR_SIZE.x * clampf(fill, 0.0, 1.0), BAR_SIZE.y)), col)
	_draw.draw_string_outline(_font, at + Vector2(6.0, BAR_SIZE.y - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, 4,
		Color.BLACK)
	_draw.draw_string(_font, at + Vector2(6.0, BAR_SIZE.y - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13)


func _stance_text(m: FighterMotion) -> String:
	if m.is_rolling():
		return tr("ROLL")
	if m.sprinting:
		return tr("SPRINT")
	match m.stance:
		FighterMotion.Stance.CROUCH:
			return tr("CROUCH")
		FighterMotion.Stance.PRONE:
			return tr("PRONE")
	return tr("Stamina")


## A teammate's name and a small HP bar (downed: the time left, dark red) over its head.
func _tag(f: SpikePlayer) -> void:
	var at3: Vector3 = Vector3(f.position.x, f.ground_y + NAME_HEIGHT, f.position.z)
	if f.camera == null or f.camera.is_position_behind(at3):
		return
	var at: Vector2 = f.camera.unproject_position(at3)
	var h: FighterHealth = f.health
	var name: String = f.get("display_name") if f.get("display_name") != null else ""
	if h.state == FighterHealth.State.DEAD:
		name = tr("%s (dead)") % name
	var w: float = _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x
	_draw.draw_string_outline(_font, at + Vector2(-w * 0.5, -8.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, 4,
		Color.BLACK)
	_draw.draw_string(_font, at + Vector2(-w * 0.5, -8.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13)
	if h.state == FighterHealth.State.DEAD:
		return
	var downed: bool = h.state == FighterHealth.State.DOWNED
	var fill: float = h.downed_left / maxf(h.config.downed_sec, 0.01) if downed else h.hp_frac()
	var origin: Vector2 = at - Vector2(MINI_BAR.x * 0.5, 0.0)
	_draw.draw_rect(Rect2(origin - Vector2(1, 1), MINI_BAR + Vector2(2, 2)), BACK_COLOR)
	_draw.draw_rect(Rect2(origin, Vector2(MINI_BAR.x * clampf(fill, 0.0, 1.0), MINI_BAR.y)),
		DOWNED_COLOR if downed else HP_COLOR)


## The reload ring over `f`'s head: a dark track, the filled arc from the top clockwise, a tick per shell.
## A downed teammate being helped up gets a green ring for the revive instead.
func _ring(f: SpikePlayer) -> void:
	var fill: float = reload_fill(f)
	var reviving: bool = f is Teammate and (f as Teammate).revive_fill() >= 0.0
	if reviving:
		fill = (f as Teammate).revive_fill()
	if fill < 0.0 or f.camera == null:
		return
	var head: Vector3 = Vector3(f.position.x, f.ground_y + RING_HEIGHT, f.position.z)
	if f.camera.is_position_behind(head):
		return
	var at: Vector2 = f.camera.unproject_position(head)
	var start: float = -PI / 2.0
	_draw.draw_arc(at, RING_RADIUS, 0.0, TAU, 32, BACK_COLOR, RING_WIDTH + 3.0, true)
	if fill > 0.0:
		var col: Color = REVIVE_COLOR if reviving else JAM_COLOR if f.gun.jammed else RING_COLOR
		_draw.draw_arc(at, RING_RADIUS, start, start + TAU * fill, maxi(4, ceili(32 * fill)), col, RING_WIDTH, true)
	var steps: int = 1 if reviving else reload_steps(f)
	if steps > 1:
		for i: int in steps:
			var a: float = start + TAU * i / steps
			var d: Vector2 = Vector2(cos(a), sin(a))
			_draw.draw_line(at + d * (RING_RADIUS - RING_WIDTH), at + d * (RING_RADIUS + RING_WIDTH), BACK_COLOR, 2.0)
