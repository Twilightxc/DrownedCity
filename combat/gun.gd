class_name Gun
extends RefCounted
## One carried gun (GDD §6): its WeaponConfig with the attachments folded in, plus state: magazine, fire
## mode, bloom, durability, jam, reload. No nodes: the player drives `step()` each frame and turns the shots
## it returns into rays; tests drive it directly.

var config: WeaponConfig
var attachments: Array[AttachmentConfig] = []
var pouch: AmmoPouch  ## null = endless rounds

# Numbers after attachments, read live from the config (the F4 panel edits it while playing).
var damage: float:
	get: return config.damage * _mul.damage_mul
var noise_m: float:
	get: return config.noise_m * _mul.noise_mul
var spread_deg: float:
	get: return config.spread_deg * _mul.spread_mul
var recoil_deg: float:
	get: return config.recoil_deg * _mul.recoil_mul
var mag_size: int:
	get: return maxi(roundi(config.mag * _mul.mag_mul), 1)
var reload_sec: float:
	get: return config.reload_sec * _mul.reload_mul
var wear_per_shot: float:
	get: return config.wear_per_shot * _mul.wear_mul
var weight_kg: float:
	get: return config.weight_kg + _mul.weight_kg
var flashlight: bool:
	get: return _mul.flashlight

var ammo: int = 0
var mode_index: int = 0
var bloom_deg: float = 0.0
var durability: float = 100.0
var jammed: bool = false
var reload_left: float = 0.0
var shots_fired: int = 0

var _mul: AttachmentConfig = AttachmentConfig.new()  ## every attachment folded into one set of multipliers
var _clearing_jam: bool = false
var _cooldown: float = 0.0
var _burst_left: int = 0
var _trigger_held: bool = false


func _init(cfg: WeaponConfig, atts: Array[AttachmentConfig] = [], p_pouch: AmmoPouch = null) -> void:
	config = cfg
	pouch = p_pouch
	var used: Dictionary[String, bool] = {}
	for a: AttachmentConfig in atts:
		if a.slot in cfg.attachment_slots and not used.has(a.slot):
			used[a.slot] = true
			attachments.append(a)
	for a: AttachmentConfig in attachments:
		_mul.damage_mul *= a.damage_mul
		_mul.noise_mul *= a.noise_mul
		_mul.spread_mul *= a.spread_mul
		_mul.recoil_mul *= a.recoil_mul
		_mul.mag_mul *= a.mag_mul
		_mul.reload_mul *= a.reload_mul
		_mul.wear_mul *= a.wear_mul
		_mul.weight_kg += a.weight_kg
		_mul.flashlight = _mul.flashlight or a.flashlight
	ammo = mag_size


func mode() -> WeaponConfig.FireMode:
	return config.modes[mode_index] if not config.modes.is_empty() else WeaponConfig.FireMode.AUTO


func next_mode() -> void:
	if config.modes.size() > 1:
		mode_index = (mode_index + 1) % config.modes.size()
		_burst_left = 0


func is_reloading() -> bool:
	return reload_left > 0.0


## 0..1 through the current reload step (the whole magazine, or one shell), 1 when not reloading.
func reload_progress() -> float:
	if reload_left <= 0.0:
		return 1.0
	return 1.0 - reload_left / (reload_sec * (0.5 if _clearing_jam else 1.0))


## Starts a reload, or clears a jam (half a reload). False if there's nothing to do or no rounds.
func start_reload() -> bool:
	if reload_left > 0.0:
		return false
	if jammed:
		_clearing_jam = true
		reload_left = reload_sec * 0.5
		return true
	if ammo >= mag_size or _rounds_left() <= 0:
		return false
	_clearing_jam = false
	reload_left = reload_sec
	return true


## Spread of the next shot, ± degrees.
func shot_spread_deg() -> float:
	var s: float = spread_deg + bloom_deg
	return s * config.burst_spread_mul if mode() == WeaponConfig.FireMode.BURST else s


## One direction per pellet around `aim`.
func pellet_dirs(aim: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var s: float = deg_to_rad(shot_spread_deg())
	for i: int in maxi(config.pellets, 1):
		out.append(aim.rotated(rng.randf_range(-s, s)))
	return out


## Advances one frame with the trigger held or not; returns 1 if a round fired this frame, else 0.
func step(delta: float, trigger: bool, rng: RandomNumberGenerator) -> int:
	_cooldown -= delta
	bloom_deg = maxf(bloom_deg - config.recoil_recover_deg * delta, 0.0)
	var pressed: bool = trigger and not _trigger_held
	_trigger_held = trigger
	if reload_left > 0.0:
		# A pump shotgun fires the shells already loaded when the trigger is pulled mid-reload.
		if pressed and config.reload_per_round and not _clearing_jam and ammo > 0:
			reload_left = 0.0
		else:
			reload_left -= delta
			if reload_left <= 0.0:
				_finish_reload()
			_cooldown = maxf(_cooldown, 0.0)
			return 0
	var want: bool = false
	match mode():
		WeaponConfig.FireMode.SEMI:
			want = pressed
		WeaponConfig.FireMode.AUTO:
			want = trigger
		WeaponConfig.FireMode.BURST:
			if pressed and _burst_left == 0:
				_burst_left = config.burst_count
			want = _burst_left > 0
	if not want:
		_cooldown = maxf(_cooldown, 0.0)
		return 0
	if _cooldown > 0.0 or jammed:
		return 0
	if ammo <= 0:
		_burst_left = 0
		start_reload()
		return 0
	_cooldown += 60.0 / config.rpm  # carry the remainder so the rate doesn't depend on FPS
	if _burst_left > 0:
		_burst_left -= 1
		if _burst_left == 0:
			_cooldown += config.burst_pause_sec
	if _jam_roll(rng):
		jammed = true
		_burst_left = 0
		return 0
	ammo -= 1
	shots_fired += 1
	bloom_deg = minf(bloom_deg + recoil_deg, config.recoil_max_deg)
	durability = maxf(durability - wear_per_shot, 0.0)
	if ammo <= 0:
		start_reload()
	return 1


## Jam chance grows from 0 at jam_below % durability to jam_chance_max at 0 %.
func jam_chance() -> float:
	if durability >= config.jam_below or config.jam_below <= 0.0:
		return 0.0
	return config.jam_chance_max * (config.jam_below - durability) / config.jam_below


func _jam_roll(rng: RandomNumberGenerator) -> bool:
	var p: float = jam_chance()
	return p > 0.0 and rng.randf() < p


func _rounds_left() -> int:
	return pouch.count(config.caliber) if pouch != null else 1 << 30


func _take(n: int) -> int:
	return pouch.take(config.caliber, n) if pouch != null else n


func _finish_reload() -> void:
	reload_left = 0.0
	if _clearing_jam:
		_clearing_jam = false
		jammed = false
		return
	if config.reload_per_round:
		ammo += _take(1)
		if ammo < mag_size and _rounds_left() > 0:
			reload_left = reload_sec  # next shell
		return
	ammo += _take(mag_size - ammo)
