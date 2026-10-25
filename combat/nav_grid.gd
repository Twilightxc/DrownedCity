class_name NavGrid
extends RefCounted
## Walkability grid on the ground plane, shared by the flow field, spatial hash and hitscan.
## A world Vector2 here is (x, z) of the 3D world.

var width: int
var height: int
var cell_size: float
var origin: Vector2  # world position of cell (0, 0)'s minimum corner
var blocked: PackedByteArray


func _init(w: int, h: int, size: float = 1.0, world_origin: Vector2 = Vector2.ZERO) -> void:
	assert(w > 0 and h > 0 and size > 0.0)
	width = w
	height = h
	cell_size = size
	origin = world_origin
	blocked.resize(w * h)


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


func is_walkable_world(p: Vector2) -> bool:
	return is_walkable(world_to_cell(p))


func set_blocked_rect(rect: Rect2i, value: bool = true) -> void:
	for y: int in range(maxi(rect.position.y, 0), mini(rect.end.y, height)):
		for x: int in range(maxi(rect.position.x, 0), mini(rect.end.x, width)):
			blocked[y * width + x] = 1 if value else 0


func world_size() -> Vector2:
	return Vector2(width, height) * cell_size
