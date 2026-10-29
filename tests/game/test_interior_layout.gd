extends GutTest

const W: int = 26
const D: int = 22

var _layout: InteriorLayout


func before_each() -> void:
	_layout = InteriorLayout.generate(W, D, 3, 7, Vector2(-13, -11), -9.6, 0)


func _reachable(grid: NavGrid, from: Vector2i) -> Dictionary[Vector2i, bool]:
	var seen: Dictionary[Vector2i, bool] = {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var m: Vector2i = c + n
			if grid.is_walkable(m) and not seen.has(m):
				seen[m] = true
				queue.append(m)
	return seen


func test_same_seed_same_plan() -> void:
	var again: InteriorLayout = InteriorLayout.generate(W, D, 3, 7, Vector2(-13, -11), -9.6, 0)
	assert_eq(again.cells, _layout.cells)
	var other: InteriorLayout = InteriorLayout.generate(W, D, 3, 8, Vector2(-13, -11), -9.6, 0)
	assert_ne(other.cells, _layout.cells, "a new seed gives new rooms")


func test_outer_ring_is_wall_or_window_with_no_window_on_corners() -> void:
	for s: int in 3:
		for x: int in W:
			for y: int in [0, D - 1]:
				assert_true(_layout.cell(s, Vector2i(x, y)) in [InteriorLayout.Cell.WALL, InteriorLayout.Cell.WINDOW])
		for c: Vector2i in [Vector2i(0, 0), Vector2i(W - 1, 0), Vector2i(0, D - 1), Vector2i(W - 1, D - 1)]:
			assert_eq(_layout.cell(s, c), InteriorLayout.Cell.WALL)


func test_every_room_door_and_both_landings_are_reachable() -> void:
	for s: int in [1, 2]:
		var grid: NavGrid = _layout.nav_grid(s)
		var start: Vector2i = Vector2i(InteriorLayout.STAIR_X0 - 1, _layout.corridor_row)
		var seen: Dictionary[Vector2i, bool] = _reachable(grid, start)
		var doors: int = 0
		for y: int in D:
			for x: int in W:
				if _layout.cell(s, Vector2i(x, y)) == InteriorLayout.Cell.DOOR:
					doors += 1
					assert_true(seen.has(Vector2i(x, y)), "storey %d door %d,%d" % [s, x, y])
		assert_gt(doors, 4, "rooms on both sides")
		assert_true(seen.has(Vector2i(InteriorLayout.STAIR_X0 + InteriorLayout.FLIGHT_LEN, _layout.corridor_row + 1)))


func test_flooded_storey_is_not_walkable_and_its_flight_is_closed() -> void:
	var g0: NavGrid = _layout.nav_grid(0)
	assert_eq(g0.blocked.count(0), 0)
	var g1: NavGrid = _layout.nav_grid(1)
	var down: Vector2i = Vector2i(InteriorLayout.STAIR_X0 + 1, _layout.flight_row(1))
	assert_false(g1.is_walkable(down), "flight into the water is closed")
	var up: Vector2i = Vector2i(InteriorLayout.STAIR_X0 + 1, _layout.flight_row(2))
	assert_true(g1.is_walkable(up), "flight to storey 2 is open")


func test_flights_alternate_rows_and_ends() -> void:
	assert_ne(_layout.flight_row(1), _layout.flight_row(2))
	assert_ne(_layout.flight_top_east(1), _layout.flight_top_east(2))


func test_stair_height_runs_from_top_to_bottom_landing() -> void:
	var row: float = _layout.origin.y + _layout.flight_row(2) + 0.5
	var x0: float = _layout.origin.x + InteriorLayout.STAIR_X0
	var east: float = x0 + InteriorLayout.FLIGHT_LEN - 0.01
	var west: float = x0 + 0.01
	var top_x: float = east if _layout.flight_top_east(2) else west
	var bottom_x: float = west if _layout.flight_top_east(2) else east
	var at_top: Array = _layout.stair_at(2, Vector2(top_x, row))
	var at_bottom: Array = _layout.stair_at(1, Vector2(bottom_x, row))
	assert_almost_eq(at_top[0], _layout.floor_y(2), 0.01)
	assert_eq(at_top[1], 2)
	assert_almost_eq(at_bottom[0], _layout.floor_y(1), 0.01)
	assert_eq(at_bottom[1], 1)
	var mid: Array = _layout.stair_at(2, Vector2(x0 + InteriorLayout.FLIGHT_LEN * 0.5, row))
	assert_almost_eq(mid[0], (_layout.floor_y(2) + _layout.floor_y(1)) * 0.5, 0.01)
	assert_eq(_layout.stair_at(2, Vector2(0.0, 0.0)), [], "off the stairs")


func test_furniture_stays_inside_rooms_on_floor_cells() -> void:
	for s: int in 3:
		for item: InteriorLayout.Item in _layout.furniture[s]:
			for c: Vector2i in item.cells:
				assert_eq(_layout.cell(s, c), InteriorLayout.Cell.FLOOR)
				assert_true(c.y < _layout.corridor_row - 1 or c.y > _layout.corridor_row + 2, "not in the corridor")
