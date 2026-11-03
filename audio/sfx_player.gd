class_name SfxPlayer
extends Node3D
## Plays SfxBank events from a fixed pool of positional players (PHASE1 1.5+ A1). Each event caps its own
## voices and the pool steals the oldest voice when full, so a 200-zombie wave never spawns players.
## Distances are heard from the scene's AudioListener3D (the spike puts it on the player, turned with the
## camera so screen left is the left ear).

var bank: SfxBank
var _players: Array[AudioStreamPlayer3D] = []
var _event_of: Array[StringName] = []  ## per player: the event it plays
var _started: PackedFloat64Array = PackedFloat64Array()  ## per player: when it started (s)
var played: Dictionary[StringName, int] = {}  ## plays per event since setup (debug overlay, tests)
var _last_play: Dictionary[StringName, float] = {}
var _delayed: Array[Array] = []  ## [time, event, position, pitch, max_distance]
var _clock: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(sfx_bank: SfxBank) -> void:
	bank = sfx_bank
	for p: AudioStreamPlayer3D in _players:
		p.queue_free()
	_players.clear()
	_event_of.clear()
	_started.clear()
	for i: int in bank.voices:
		var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 0.6  # top-down: keep the side a hint, not a hard pan
		p.top_level = true
		add_child(p)
		_players.append(p)
		_event_of.append(&"")
	_started.resize(bank.voices)


func _process(delta: float) -> void:
	_clock += delta
	var i: int = 0
	while i < _delayed.size():
		var d: Array = _delayed[i]
		if _clock >= d[0]:
			_delayed.remove_at(i)
			play(d[1], d[2], d[3], d[4])
		else:
			i += 1


## Plays `event` at `at`. `max_distance` < 0 takes the event's own; `delay` > 0 plays it later (a pump after a
## shot). Returns false when the event is unknown, has no takes or came too soon after the last one.
func play(event: StringName, at: Vector3, pitch: float = 1.0, max_distance: float = -1.0, delay: float = 0.0) -> bool:
	if bank == null or not bank.events.has(event):
		return false
	if delay > 0.0:
		_delayed.append([_clock + delay, event, at, pitch, max_distance])
		return true
	var e: SfxEvent = bank.events[event]
	if e.streams.is_empty():
		return false
	if e.min_interval_sec > 0.0 and _clock - _last_play.get(event, -1e9) < e.min_interval_sec:
		return false
	_last_play[event] = _clock
	var p: AudioStreamPlayer3D = _players[_pick_voice(event, e.max_voices)]
	var range_m: float = e.max_distance_m if max_distance < 0.0 else max_distance
	p.stream = e.streams[_rng.randi() % e.streams.size()]
	p.volume_db = e.volume_db
	p.pitch_scale = maxf(pitch * (1.0 + _rng.randf_range(-e.pitch_jitter, e.pitch_jitter)), 0.05)
	p.max_distance = range_m
	p.unit_size = range_m * 0.25  # full volume close by, fading out toward max_distance
	p.global_position = at
	p.play()
	played[event] = played.get(event, 0) + 1
	return true


func active_count() -> int:
	var n: int = 0
	for p: AudioStreamPlayer3D in _players:
		if p.playing:
			n += 1
	return n


## A free player; else the oldest voice of this event once it has max_voices; else the oldest of all.
func _pick_voice(event: StringName, max_voices: int) -> int:
	var same: int = 0
	var oldest_same: int = -1
	var oldest: int = 0
	var free: int = -1
	for i: int in _players.size():
		if not _players[i].playing:
			if free < 0:
				free = i
			continue
		if _event_of[i] == event:
			same += 1
			if oldest_same < 0 or _started[i] < _started[oldest_same]:
				oldest_same = i
		if _started[i] < _started[oldest]:
			oldest = i
	var pick: int = oldest_same if same >= max_voices else free if free >= 0 else oldest
	_players[pick].stop()
	_event_of[pick] = event
	_started[pick] = _clock
	return pick
