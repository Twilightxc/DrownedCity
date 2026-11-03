class_name SpikeAudio
extends Node3D
## Audio pass 1 (PHASE1 1.5+ A1) for the spikes: turns what the player, the guns, the horde and the fire do
## into SfxBank events. The listener rides on the player and turns with the camera, so what you hear is what
## is near you: a shot carries its gun's noise_m, the radius zombies hear it at (GDD §9).

const GROAN_RANGE_M: float = 20.0
const GROAN_SEC: Vector2 = Vector2(1.6, 0.3)  ## pause between groans: one zombie near → a crowd of 40
const STEP_M: float = 0.75  ## a footstep every this much walking
const DEATHS_PER_FRAME: int = 3

var volume_db: float = -6.0:
	set(v):
		volume_db = v
		AudioServer.set_bus_volume_db(0, v)
var muted: bool = false:
	set(v):
		muted = v
		AudioServer.set_bus_mute(0, v)

var sfx: SfxPlayer
var _player: SpikePlayer
var _rig: Node3D
var _listener: AudioListener3D
var _fire: AudioStreamPlayer3D
var _gun_counts: Dictionary[Gun, Vector2i] = {}  ## reload_sounds, dry_fires last seen
var _step_from: Vector2 = Vector2.ZERO
var _step_left: float = STEP_M
var _groan_left: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func bind(bank: SfxBank, player: SpikePlayer, rig: Node3D) -> void:
	_player = player
	_rig = rig
	sfx = SfxPlayer.new()
	add_child(sfx)
	sfx.setup(bank)
	_listener = AudioListener3D.new()
	add_child(_listener)
	_listener.make_current()
	if bank.events.has(&"fire_loop") and not bank.events[&"fire_loop"].streams.is_empty():
		var e: SfxEvent = bank.events[&"fire_loop"]
		var loop: AudioStream = e.streams[0].duplicate()
		if loop is AudioStreamOggVorbis:
			(loop as AudioStreamOggVorbis).loop = true
		_fire = AudioStreamPlayer3D.new()
		_fire.stream = loop
		_fire.max_distance = e.max_distance_m
		_fire.unit_size = e.max_distance_m * 0.25
		_fire.top_level = true
		add_child(_fire)
	volume_db = volume_db
	player.shot.connect(_on_shot)
	player.health.damaged.connect(func(_amount: int, _kind: StringName) -> void:
		sfx.play(&"player_hit", _at(player.ground_position())))
	_step_from = player.ground_position()


func _on_shot(g: Gun) -> void:
	var at: Vector3 = _player.muzzle_position()
	sfx.play(g.shot_sfx, at, 1.0, g.noise_m)
	if g.config.cycle_sfx != &"":
		sfx.play(g.config.cycle_sfx, at, 1.0, -1.0, g.config.cycle_delay_sec)


## Once a frame, after the horde moved. `burning` = ground fire cells (may be null).
func update(delta: float, horde: Horde, burning: GroundFire) -> void:
	if _player == null:
		return
	var me: Vector2 = _player.ground_position()
	_listener.global_position = _at(me)
	_listener.global_rotation = Vector3(0.0, _rig.global_rotation.y, 0.0)
	_update_gun()
	_update_steps(me)
	if horde != null:
		_update_groans(delta, horde, me)
	_update_fire(horde, burning, me)
	DebugOverlay.set_stat("sfx_voices", str(sfx.active_count()))


## Bullet hits, deaths and dropped helmets since the last frame (before Horde.clear_events()).
func on_horde_events(h: Horde) -> void:
	if not h.hit_points.is_empty():
		sfx.play(&"flesh_hit", _at(h.hit_points[0]))
	for i: int in mini(h.deaths.size(), DEATHS_PER_FRAME):
		var d: Horde.Death = h.deaths[i]
		var t: EnemyConfig = h.config.types[d.type] if d.type < h.config.types.size() else null
		sfx.play(t.death_sfx if t != null else &"flesh_hit", _at(d.position))
	for d: Horde.Death in h.helmet_drops:
		sfx.play(&"helmet_clang", _at(d.position))


func on_blast(at: Vector3, cfg: ThrowableConfig) -> void:
	sfx.play(cfg.blast_sfx, at)


func _update_gun() -> void:
	var g: Gun = _player.gun
	var seen: Vector2i = _gun_counts.get(g, Vector2i(g.reload_sounds, g.dry_fires))
	var at: Vector3 = _player.muzzle_position()
	if g.reload_sounds > seen.x:
		sfx.play(g.config.reload_sfx, at)
	if g.dry_fires > seen.y:
		sfx.play(&"dry_click", at)
	_gun_counts[g] = Vector2i(g.reload_sounds, g.dry_fires)


func _update_steps(me: Vector2) -> void:
	_step_left -= me.distance_to(_step_from)
	_step_from = me
	if _step_left <= 0.0:
		_step_left = STEP_M
		sfx.play(&"footstep", _at(me))


## A groan from a random hunting zombie nearby, more often the bigger the crowd around you.
func _update_groans(delta: float, h: Horde, me: Vector2) -> void:
	_groan_left -= delta
	if _groan_left > 0.0 or h.count == 0:
		return
	var near: int = 0
	var pick: int = -1
	var tries: int = mini(h.count, 12)
	for i: int in tries:
		var a: int = _rng.randi() % h.count
		if h.state[a] == Horde.State.DORMANT or h.positions[a].distance_to(me) > GROAN_RANGE_M:
			continue
		near += 1
		if pick < 0:
			pick = a
	var crowd: float = clampf(float(near) / tries * h.count / 40.0, 0.0, 1.0)
	_groan_left = lerpf(GROAN_SEC.x, GROAN_SEC.y, crowd) * _rng.randf_range(0.7, 1.3)
	if pick < 0:
		return
	var t: EnemyConfig = h.config.types[h.type[pick]] if h.type[pick] < h.config.types.size() else null
	var voice: StringName = t.voice_sfx if t != null else &"zombie_groan"
	sfx.play(voice, _at(h.positions[pick]), t.voice_pitch if t != null else 1.0)


## One fire loop at the nearest burning cell or zombie, louder the more is burning.
func _update_fire(h: Horde, burning: GroundFire, me: Vector2) -> void:
	if _fire == null:
		return
	var best: float = INF
	var at: Vector2 = Vector2.ZERO
	var n: int = 0
	if burning != null:
		for c: int in burning.active_cells():
			var p: Vector2 = burning.grid.cell_center(burning.grid.cell_of_index(c))
			n += 1
			if p.distance_squared_to(me) < best:
				best = p.distance_squared_to(me)
				at = p
	if h != null:
		for a: int in h.count:
			if h.burn_left[a] > 0.0:
				n += 1
				if h.positions[a].distance_squared_to(me) < best:
					best = h.positions[a].distance_squared_to(me)
					at = h.positions[a]
	if n == 0:
		if _fire.playing:
			_fire.stop()
		return
	_fire.global_position = _at(at)
	_fire.volume_db = sfx.bank.events[&"fire_loop"].volume_db + linear_to_db(clampf(n / 6.0, 0.35, 1.0))
	if not _fire.playing:
		_fire.play()


func _at(p: Vector2) -> Vector3:
	return Vector3(p.x, _player.ground_y + 1.0, p.y)
