class_name NavGrid
extends RefCounted
## Walkability grid on the ground plane, shared by the flow field, spatial hash and hitscan.
## A world Vector2 here is (x, z) of the 3D world.

var width: int
var height: int
var cell_size: float
var origin: Vector2  # world position of cell (0, 0)'s minimum corner
var blocked: PackedByteArray
## Per blocked cell: the height of low cover (an AC unit, sandbags), 0 = a wall to the sky. Shots fired and sight
## lines held above it pass over (J 2026-11-03: shoot over the boxes from behind them).
var low_cover: PackedFloat32Array


func _init(w: int, h: int, size: float = 1.0, world_origin: Vector2 = Vector2.ZERO) -> void:
	assert(w > 0 and h > 0 and size > 0.0)
	width = w
	height = h
	cell_size = size
	origin = world_origin
	blocked.resize(w * h)
	low_cover.resize(w * h)


func cell_count() -> int:
	return width * height


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func index_of(cell: Vector2i) -> int:
	return cell.y * width + cell.x


func cell_of_index(index: int) -> Vector2i:
	return Vector2i(index % width, index / width)


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / cell_size), floori((p.y - origin.y) / cell_size))


func cell_center(cell: Vector2i) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func is_walkable(cell: Vector2i) -> bool:
	return in_bounds(cell) and blocked[index_of(cell)] == 0


## Blocks rays held `over` m above the ground (0 = at the floor). Low cover lower than that lets them pass.
## Unlike `not is_walkable`, cells outside the grid don't block.
func blocks_ray(cell: Vector2i, over: float = 0.0) -> bool:
	if not in_bounds(cell):
		return false
	var i: int = index_of(cell)
	return blocked[i] != 0 and (low_cover[i] <= 0.0 or low_cover[i] >= over)


func is_walkable_world(p: Vector2) -> bool:
	return is_walkable(world_to_cell(p))


## `cover_m` > 0 makes the cells low cover of that height; 0 = walls.
func set_blocked_rect(rect: Rect2i, value: bool = true, cover_m: float = 0.0) -> void:
	for y: int in range(maxi(rect.position.y, 0), mini(rect.end.y, height)):
		for x: int in range(maxi(rect.position.x, 0), mini(rect.end.x, width)):
			blocked[y * width + x] = 1 if value else 0
			low_cover[y * width + x] = cover_m if value else 0.0


func world_size() -> Vector2:
	return Vector2(width, height) * cell_size


## Distance along `dir` from `from` to the first blocked cell, capped at max_range.
## Cells outside the grid don't block (bullets fly off the roof).
## A ray through a cell corner exactly is blocked if either side cell is (no squeezing between
## diagonal walls); the result is the same for mirrored shots.
## `over`: the ray's height above the floor (low cover under it doesn't stop it).
func ray_distance(from: Vector2, dir: Vector2, max_range: float, over: float = 0.0) -> float:
	dir = dir.normalized()
	var c: Vector2i = world_to_cell(from)
	var step_x: int = 1 if dir.x > 0.0 else -1
	var step_y: int = 1 if dir.y > 0.0 else -1
	var t_delta_x: float = cell_size / absf(dir.x) if dir.x != 0.0 else INF
	var t_delta_y: float = cell_size / absf(dir.y) if dir.y != 0.0 else INF
	var next_x: float = origin.x + (c.x + (1 if step_x > 0 else 0)) * cell_size
	var next_y: float = origin.y + (c.y + (1 if step_y > 0 else 0)) * cell_size
	var t_max_x: float = (next_x - from.x) / dir.x if dir.x != 0.0 else INF
	var t_max_y: float = (next_y - from.y) / dir.y if dir.y != 0.0 else INF
	var t: float = 0.0
	while t <= max_range:
		if blocks_ray(c, over):
			return t
		if t_max_x < t_max_y:
			t = t_max_x
			t_max_x += t_delta_x
			c.x += step_x
		elif t_max_y < t_max_x:
			t = t_max_y
			t_max_y += t_delta_y
			c.y += step_y
		else:  # exact corner: step diagonally, blocked by either side cell
			t = t_max_x
			if t <= max_range and (blocks_ray(Vector2i(c.x + step_x, c.y), over) \
					or blocks_ray(Vector2i(c.x, c.y + step_y), over)):
				return t
			t_max_x += t_delta_x
			t_max_y += t_delta_y
			c += Vector2i(step_x, step_y)
	return max_range


## `over`: how high the line runs; a target standing taller than low cover is seen over it.
func line_of_sight(a: Vector2, b: Vector2, over: float = 0.0) -> bool:
	var d: float = a.distance_to(b)
	return d < 0.0001 or ray_distance(a, b - a, d, over) >= d
