class_name WeaponPanel
extends CanvasLayer
## The weapon panel at the bottom right (bug list item 17, J 2026-11-06): the gun in hand (its side-view icon
## from tools/blender/icons_guns.py, or its name without one), the magazine as pips with the reserve, the fire mode, jams and wear, the
## grenade type and count, the knife key, and slots 1–4 with the one in hand brighter (dimmed when it can't be
## used, e.g. a long gun while downed). Non-interactive, so nothing to navigate with a pad.

const SIZE: Vector2 = Vector2(330.0, 118.0)
const MARGIN: Vector2 = Vector2(24.0, 28.0)  ## from the bottom-right corner
const PAD: float = 10.0
const PIP_MAX_W: float = 7.0
const PIP_GAP: float = 2.0
const PIP_H: float = 12.0
const PIPS_MAX: int = 60  ## a bigger magazine shows a bar instead
const SLOT_SIZE: Vector2 = Vector2(72.0, 22.0)
const ICON_BOX: Vector2 = Vector2(170.0, 30.0)  ## the gun icon fits in here, left of the fire mode
const BACK: Color = Color(0.05, 0.06, 0.07, 0.62)
const INK: Color = Color(0.95, 0.95, 0.92)
const DIM: Color = Color(0.95, 0.95, 0.92, 0.35)
const AMMO: Color = Color(1.0, 0.86, 0.45)
const EMPTY: Color = Color(1.0, 1.0, 1.0, 0.16)
const WARN: Color = Color(1.0, 0.45, 0.25)
const MODES: PackedStringArray = ["SEMI", "AUTO", "BURST"]

var player: SpikePlayer

var _draw: Control
var _font: Font
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


func _process(delta: float) -> void:
	_blink += delta
	_draw.queue_redraw()


## Pip width for a magazine of `mag` rounds across `width` px: at most PIP_MAX_W, 0 when it needs a bar.
static func pip_width(mag: int, width: float) -> float:
	if mag <= 0 or mag > PIPS_MAX:
		return 0.0
	return minf(PIP_MAX_W, (width + PIP_GAP) / mag - PIP_GAP)


## Where a gun icon of `size` px goes: fitted into ICON_BOX at `at`, its aspect kept, sitting on the box's bottom.
static func icon_rect(size: Vector2, at: Vector2) -> Rect2:
	var k: float = minf(ICON_BOX.x / maxf(size.x, 1.0), ICON_BOX.y / maxf(size.y, 1.0))
	var s: Vector2 = size * k
	return Rect2(at + Vector2(0.0, ICON_BOX.y - s.y), s)


## Whether the gun in slot `i` can be taken in hand now (downed: sidearms only).
static func slot_usable(p: SpikePlayer, i: int) -> bool:
	if i >= p.guns.size():
		return false
	return p.health == null or p.health.state != FighterHealth.State.DOWNED or SpikePlayer.is_sidearm(p.guns[i])


func _on_draw() -> void:
	if player == null or player.gun == null or player.health == null or player.health.state == FighterHealth.State.DEAD:
		return
	var view: Vector2 = _draw.size
	var o: Vector2 = view - MARGIN - SIZE
	_draw.draw_rect(Rect2(o, SIZE), BACK)
	var g: Gun = player.gun
	var cfg: WeaponConfig = g.config
	var inner_w: float = SIZE.x - PAD * 2.0
	# The gun: icon or name, with the fire mode and the knife key on the right.
	if cfg.icon != null:
		_draw.draw_texture_rect(cfg.icon, icon_rect(cfg.icon.get_size(), o + Vector2(PAD, PAD - 6.0)), false)
	else:
		_draw.draw_string(_font, o + Vector2(PAD, PAD + 18.0), tr(cfg.display_name), HORIZONTAL_ALIGNMENT_LEFT,
				inner_w * 0.6, 20, INK)
	var mode: String = tr(MODES[g.mode()])
	if cfg.modes.size() > 1:
		mode += " ▸"
	_draw.draw_string(_font, o + Vector2(PAD, PAD + 18.0), mode, HORIZONTAL_ALIGNMENT_RIGHT, inner_w, 14, DIM)
	# Rounds: the magazine as pips (or a bar), then the count and the reserve.
	var ammo_y: float = PAD + 34.0
	var count_w: float = 96.0
	var pips_w: float = inner_w - count_w - 8.0
	var pw: float = pip_width(g.mag_size, pips_w)
	var low: bool = g.ammo <= maxi(g.mag_size / 4, 1)
	var full_col: Color = WARN if low and fmod(_blink, 0.6) < 0.3 else AMMO
	if pw > 0.0:
		for k: int in g.mag_size:
			var r: Rect2 = Rect2(o + Vector2(PAD + k * (pw + PIP_GAP), ammo_y), Vector2(pw, PIP_H))
			_draw.draw_rect(r, full_col if k < g.ammo else EMPTY)
	else:
		_draw.draw_rect(Rect2(o + Vector2(PAD, ammo_y), Vector2(pips_w, PIP_H)), EMPTY)
		_draw.draw_rect(Rect2(o + Vector2(PAD, ammo_y), Vector2(pips_w * g.ammo / maxf(g.mag_size, 1.0), PIP_H)), full_col)
	var reserve: int = player.pouch.count(cfg.caliber) if player.pouch != null else 0
	var count_x: float = PAD + inner_w - count_w
	_draw.draw_string(_font, o + Vector2(count_x, ammo_y + PIP_H), "%d" % g.ammo, HORIZONTAL_ALIGNMENT_RIGHT, 44.0, 22,
			full_col if g.ammo > 0 else WARN)
	_draw.draw_string(_font, o + Vector2(count_x + 48.0, ammo_y + PIP_H), "/ %d" % reserve, HORIZONTAL_ALIGNMENT_LEFT,
			48.0, 14, DIM if reserve > 0 else WARN)
	# One status line: a jam beats wear; else grenades and the knife.
	var line_y: float = ammo_y + PIP_H + 20.0
	var status: String = ""
	var status_col: Color = DIM
	if g.jammed and not g.is_reloading():
		status = tr("JAMMED · reload")
		status_col = WARN
	elif g.durability < cfg.jam_below:
		status = tr("Worn %d%%") % int(g.durability)
		status_col = WARN
	_draw.draw_string(_font, o + Vector2(PAD, line_y), status, HORIZONTAL_ALIGNMENT_LEFT, inner_w * 0.45, 13, status_col)
	var extras: PackedStringArray = PackedStringArray()
	if player.throwable != null:
		extras.append("%s ×%d" % [tr(player.throwable.display_name), player.grenade_count])
	if player.melee_weapon != null:
		extras.append(tr(player.melee_weapon.display_name))
	_draw.draw_string(_font, o + Vector2(PAD, line_y), "  ·  ".join(extras), HORIZONTAL_ALIGNMENT_RIGHT, inner_w, 13,
			INK if player.grenade_count > 0 else DIM)
	# Slots 1–4.
	var slot_y: float = SIZE.y - PAD - SLOT_SIZE.y
	for i: int in 4:
		var r: Rect2 = Rect2(o + Vector2(PAD + i * (SLOT_SIZE.x + 6.0), slot_y), SLOT_SIZE)
		if i >= player.guns.size():
			_draw.draw_rect(r, Color(1, 1, 1, 0.05))
			continue
		var sg: Gun = player.guns[i]
		var in_hand: bool = sg == g
		var usable: bool = slot_usable(player, i)
		_draw.draw_rect(r, Color(1.0, 0.86, 0.45, 0.28) if in_hand else Color(1, 1, 1, 0.08))
		if in_hand:
			_draw.draw_rect(r, AMMO, false, 1.5)
		var label: String = "%d %s" % [i + 1, tr(sg.config.short_name if sg.config.short_name != "" else sg.config.display_name)]
		_draw.draw_string(_font, r.position + Vector2(5.0, 16.0), label, HORIZONTAL_ALIGNMENT_LEFT, SLOT_SIZE.x - 8.0, 12,
				INK if in_hand else DIM if not usable else Color(0.95, 0.95, 0.92, 0.7))
