class_name GridPath
extends RefCounted
## Shortest walkable path on a NavGrid (8-way BFS from the goal), for the few AI teammates (PHASE1 1.5+ A5);
## the horde uses its shared flow field instead. `next_point` answers where to head now: the farthest point
## along the path that can be walked to in a straight line.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


static func next_point(grid: NavGrid, from: Vector2, to: Vector2) -> Vector2:
	if grid.line_of_sight(from, to):
		return to
	var start: Vector2i = grid.world_to_cell(from)
	var goal: Vector2i = grid.world_to_cell(to)
	if not grid.in_bounds(start) or not grid.is_walkable(goal):
		return to
	var came: Dictionary[Vector2i, Vector2i] = {goal: goal}
	var queue: Array[Vector2i] = [goal]
	var head: int = 0
	while head < queue.size() and not came.has(start):
		var c: Vector2i = queue[head]
		head += 1
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if came.has(n) or not grid.is_walkable(n):
				continue
			if d.x != 0 and d.y != 0 and not (grid.is_walkable(Vector2i(c.x + d.x, c.y)) and grid.is_walkable(Vector2i(c.x, c.y + d.y))):
				continue  # no cutting corners
			came[n] = c
			queue.append(n)
	if not came.has(start):
		return to
	# Walk from the start toward the goal; head for the farthest cell still in a straight line.
	var best: Vector2 = grid.cell_center(came[start])
	var c2: Vector2i = came[start]
	var steps: int = 0
	while c2 != goal and steps < 64:
		c2 = came[c2]
		steps += 1
		var p: Vector2 = grid.cell_center(c2)
		if not grid.line_of_sight(from, p):
			break
		best = p
	return to if c2 == goal and grid.line_of_sight(from, to) else best
