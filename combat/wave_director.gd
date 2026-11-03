class_name WaveDirector
extends RefCounted
## Runs an ArenaConfig's waves (Phase 1 step 1.5): a calm, then a wave that spawns its zombies over time from
## its entrances (never more than alive_cap on the roof), then the next calm once the roof is clear. Pure
## data: `step()` returns what to spawn this frame; the scene spawns it and refunds what didn't fit.

enum Phase { CALM, WAVE, WON }

var config: ArenaConfig
var phase: Phase = Phase.CALM
var wave: int = -1  ## index of the current (or next, during a calm) wave
var calm_left: float = 0.0
var remaining: PackedInt32Array = PackedInt32Array()  ## still to spawn this wave, per type
var _budget: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## `start_wave` (0-based) skips the earlier waves, for testing late waves (`?wave=N`).
func _init(cfg: ArenaConfig, rng_seed: int = 0, start_wave: int = 0) -> void:
	config = cfg
	_rng.seed = rng_seed
	_enter_calm(clampi(start_wave, 0, cfg.waves.size() - 1))


func wave_count() -> int:
	return config.waves.size()


func left_to_spawn() -> int:
	var n: int = 0
	for c: int in remaining:
		n += c
	return n


## One frame. `alive` = zombies on the roof now. Returns spawn requests as Vector2i(type, entrance).
func step(delta: float, alive: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	match phase:
		Phase.CALM:
			calm_left -= delta
			if calm_left <= 0.0:
				_start_wave()
		Phase.WAVE:
			var w: WaveConfig = config.waves[wave]
			_budget += w.spawn_per_sec * delta
			while _budget >= 1.0 and left_to_spawn() > 0 and alive + out.size() < config.alive_cap:
				_budget -= 1.0
				out.append(Vector2i(_pick_type(), w.entrances[_rng.randi() % w.entrances.size()]))
			if left_to_spawn() == 0:
				_budget = 0.0
				if alive + out.size() == 0:  # this frame's spawns aren't on the roof yet: they count too
					if wave + 1 >= config.waves.size():
						phase = Phase.WON
					else:
						_enter_calm(wave + 1)
	return out


## A requested spawn that didn't fit (entrance pocket full): try it again later.
func refund(enemy_type: int) -> void:
	if phase == Phase.WAVE and enemy_type < remaining.size():
		remaining[enemy_type] += 1


func _enter_calm(next_wave: int) -> void:
	phase = Phase.CALM
	wave = next_wave
	calm_left = config.waves[next_wave].break_before_sec if next_wave < config.waves.size() else 0.0


func _start_wave() -> void:
	phase = Phase.WAVE
	remaining = config.waves[wave].counts.duplicate()
	_budget = 0.0


## A type weighted by what's left of it, so a wave's mix spreads over its whole length.
func _pick_type() -> int:
	var r: int = _rng.randi_range(1, left_to_spawn())
	for t: int in remaining.size():
		r -= remaining[t]
		if r <= 0:
			remaining[t] -= 1
			return t
	return 0
