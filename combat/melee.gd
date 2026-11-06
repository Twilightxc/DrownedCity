class_name Melee
extends RefCounted
## One fighter's melee swing (GDD §6): press → wind-up → the hit lands on the zombies in the cone in reach →
## recovery. Pure state and pure target picking, so it is testable without a scene; SpikePlayer applies the hit.

var config: MeleeConfig
var left: float = 0.0  ## of the current swing, 0 = ready
var _pending: bool = false


func _init(cfg: MeleeConfig) -> void:
	config = cfg


func is_swinging() -> bool:
	return left > 0.0


## Starts a swing; false while one is still going.
func try_swing() -> bool:
	if left > 0.0:
		return false
	left = config.swing_sec
	_pending = true
	return true


## Advances the swing; true on the one frame the hit lands.
func step(delta: float) -> bool:
	if left <= 0.0:
		return false
	left = maxf(left - delta, 0.0)
	if _pending and config.swing_sec - left >= config.windup_sec:
		_pending = false
		return true
	return false


## The zombies a swing from `me` along `dir` (unit) hits: in reach, inside the cone, not behind a wall; nearest
## first, at most max_targets. Any state: a sleeper can be stabbed.
static func targets(cfg: MeleeConfig, horde: Horde, grid: NavGrid, me: Vector2, dir: Vector2) -> PackedInt32Array:
	var found: Array[Vector2] = []  # (distance, index)
	var half: float = deg_to_rad(cfg.arc_deg) * 0.5
	for a: int in horde.count:
		var to: Vector2 = horde.positions[a] - me
		var d: float = to.length()
		if d > cfg.reach_m:
			continue
		if d > 0.05 and absf(dir.angle_to(to)) > half:
			continue
		if grid != null and not grid.line_of_sight(me, horde.positions[a], 1.0):
			continue
		found.append(Vector2(d, a))
	found.sort()
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in mini(found.size(), cfg.max_targets):
		out.append(int(found[i].y))
	return out


## One hit's damage on agent `a`: armor as for bullets, more on a zombie that isn't hunting yet.
static func damage_to(cfg: MeleeConfig, horde: Horde, a: int) -> int:
	var d: float = cfg.damage * Ballistics.armor_mul(cfg.armor_pen, horde.armor[a])
	if horde.state[a] != Horde.State.HUNTING:
		d *= cfg.sneak_mul
	return maxi(roundi(d), 1)
