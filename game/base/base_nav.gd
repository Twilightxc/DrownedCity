class_name BaseNav
extends RefCounted
## Walking about the base (1.7 step 3): a fine NavGrid over the roof (0.5 m cells) with the roof's props and the
## rooms' solids blocked, and A* paths on it (AStarGrid2D). ≤ 6 residents, a path each per hour: cheap.
## The horde keeps its own 1 m grid and flow field; this one is only for daily life.

var grid: NavGrid
var _astar: AStarGrid2D = AStarGrid2D.new()


func _init(roof_size: Vector2, cell: float) -> void:
	var w: int = roundi(roof_size.x / cell)
	var h: int = roundi(roof_size.y / cell)
	grid = NavGrid.new(w, h, cell, -roof_size * 0.5)
	_astar.region = Rect2i(0, 0, w, h)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()


## Blocks the cells under a footprint (centre, size in metres), like the level's nav obstacles.
func block(center: Vector2, size: Vector2) -> void:
	grid.set_blocked_rect(Style15Level.footprint_cells(grid, center, size), true)


func clear() -> void:
	grid.blocked.fill(0)


## Call after blocking: A* reads the grid's blocked cells.
func commit() -> void:
	for y: int in grid.height:
		for x: int in grid.width:
			_astar.set_point_solid(Vector2i(x, y), not grid.is_walkable(Vector2i(x, y)))


## World points from `from` to `to` (both ends on the roof), corners cut where the line is clear. A blocked end
## (a bed, a stove) is reached from the nearest open cell, then straight in. Empty when there is no way.
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a: Vector2i = nearest_open(grid.world_to_cell(from))
	var b: Vector2i = nearest_open(grid.world_to_cell(to))
	if a.x < 0 or b.x < 0:
		return PackedVector2Array()
	var ids: Array[Vector2i] = _astar.get_id_path(a, b)
	if ids.is_empty():
		return PackedVector2Array()
	var pts: PackedVector2Array = PackedVector2Array([from])
	for c: Vector2i in ids:
		pts.append(grid.cell_center(c))
	pts.append(to)
	return _smooth(pts)


## The open cell nearest `c` (itself when open), or (-1, -1).
func nearest_open(c: Vector2i) -> Vector2i:
	c = Vector2i(clampi(c.x, 0, grid.width - 1), clampi(c.y, 0, grid.height - 1))
	if grid.is_walkable(c):
		return c
	for r: int in range(1, 12):
		var best: Vector2i = Vector2i(-1, -1)
		var best_d: int = 1 << 30
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n: Vector2i = c + Vector2i(dx, dy)
				if grid.in_bounds(n) and grid.is_walkable(n) and dx * dx + dy * dy < best_d:
					best = n
					best_d = dx * dx + dy * dy
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## String-pulling: drop a point when the walk from the last kept one to the next is clear. The first and last
## legs may cross blocked cells (the way into a bed), so they stay.
func _smooth(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() <= 3:
		return pts
	var out: PackedVector2Array = PackedVector2Array([pts[0], pts[1]])
	var i: int = 1
	while i < pts.size() - 2:
		var j: int = pts.size() - 2
		while j > i + 1 and not grid.line_of_sight(pts[i], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	out.append(pts[pts.size() - 1])
	return out
