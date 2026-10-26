class_name AimAssist
extends RefCounted
## Light gamepad aim assist: picks the zombie closest to the stick direction inside a cone
## (angle first, distance as tie-breaker), skipping ones behind walls, and bends the aim toward it.

const MAX_LOS_CHECKS: int = 4

var grid: NavGrid

var _cand: PackedInt32Array = PackedInt32Array()
var _score: PackedFloat32Array = PackedFloat32Array()


func _init(nav: NavGrid) -> void:
	grid = nav


## Index of the agent to assist toward, or -1.
func pick(horde: Horde, from: Vector2, dir: Vector2, max_range: float, cone_rad: float) -> int:
	_cand.clear()
	_score.clear()
	dir = dir.normalized()
	var range2: float = max_range * max_range
	var cos_cone: float = cos(cone_rad)
	var pos: PackedVector2Array = horde.positions
	for a: int in horde.count:
		var rel: Vector2 = pos[a] - from
		var d2: float = rel.length_squared()
		if d2 > range2 or d2 < 0.0001:
			continue
		var d: float = sqrt(d2)
		var c: float = rel.dot(dir) / d
		if c < cos_cone:
			continue
		var angle: float = acos(minf(c, 1.0))
		_insert(a, angle / maxf(cone_rad, 0.0001) + 0.5 * d / max_range)
	for i: int in mini(_cand.size(), MAX_LOS_CHECKS):
		if grid.line_of_sight(from, pos[_cand[i]]):
			return _cand[i]
	return -1


## `dir` rotated toward `target` by `strength` (0 = unchanged, 1 = straight at it).
static func bend(dir: Vector2, from: Vector2, target: Vector2, strength: float) -> Vector2:
	var to_target: Vector2 = target - from
	if to_target.length_squared() < 0.0001:
		return dir.normalized()
	return dir.normalized().rotated(dir.angle_to(to_target) * clampf(strength, 0.0, 1.0))


## Keeps only the best MAX_LOS_CHECKS candidates, sorted by score.
func _insert(agent: int, score: float) -> void:
	var i: int = _cand.size()
	while i > 0 and _score[i - 1] > score:
		i -= 1
	if i >= MAX_LOS_CHECKS:
		return
	_cand.insert(i, agent)
	_score.insert(i, score)
	if _cand.size() > MAX_LOS_CHECKS:
		_cand.resize(MAX_LOS_CHECKS)
		_score.resize(MAX_LOS_CHECKS)
