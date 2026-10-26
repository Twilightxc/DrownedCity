class_name AimAssist
extends RefCounted
## Light gamepad aim assist: picks the visible zombie closest to the stick direction inside a cone
## (smallest angle first, distance only breaks ties), and bends the aim toward it.

var grid: NavGrid


func _init(nav: NavGrid) -> void:
	grid = nav


## Index of the agent to assist toward, or -1.
## Line of sight is tested only for a candidate that beats the best visible one so far, so a crowd
## behind a wall never hides a visible zombie further down the ranking.
func pick(horde: Horde, from: Vector2, dir: Vector2, max_range: float, cone_rad: float) -> int:
	dir = dir.normalized()
	var range2: float = max_range * max_range
	var cos_cone: float = cos(cone_rad)
	var pos: PackedVector2Array = horde.positions
	var best: int = -1
	var best_angle: float = INF
	var best_d2: float = INF
	for a: int in horde.count:
		var rel: Vector2 = pos[a] - from
		var d2: float = rel.length_squared()
		if d2 > range2 or d2 < 0.0001:
			continue
		var c: float = rel.dot(dir) / sqrt(d2)
		if c < cos_cone:
			continue
		var angle: float = acos(minf(c, 1.0))
		if angle > best_angle or (angle == best_angle and d2 >= best_d2):
			continue
		if grid.line_of_sight(from, pos[a]):
			best = a
			best_angle = angle
			best_d2 = d2
	return best


## `dir` rotated toward `target` by `strength` (0 = unchanged, 1 = straight at it).
static func bend(dir: Vector2, from: Vector2, target: Vector2, strength: float) -> Vector2:
	var to_target: Vector2 = target - from
	if to_target.length_squared() < 0.0001:
		return dir.normalized()
	return dir.normalized().rotated(dir.angle_to(to_target) * clampf(strength, 0.0, 1.0))
