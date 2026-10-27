extends GutTest

var _grid: NavGrid


func before_each() -> void:
	_grid = NavGrid.new(20, 10, 1.0, Vector2.ZERO)


func test_ray_distance_stops_at_first_blocked_cell() -> void:
	_grid.set_blocked_rect(Rect2i(8, 0, 1, 10))
	assert_almost_eq(_grid.ray_distance(Vector2(2.5, 5.0), Vector2.RIGHT, 30.0), 5.5, 0.001)
	assert_almost_eq(_grid.ray_distance(Vector2(2.5, 5.0), Vector2.LEFT, 30.0), 30.0, 0.001, "off the grid doesn't block")


func test_ray_distance_caps_at_max_range() -> void:
	assert_almost_eq(_grid.ray_distance(Vector2(2.5, 5.0), Vector2(1, 1), 3.0), 3.0, 0.001)


const DIAGONALS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


func test_ray_through_exact_corner_is_blocked_by_either_side_cell() -> void:
	# Regression (Copilot, PR #3): on a t_max_x == t_max_y tie the ray always stepped y first, so a
	# wall at the y-side cell blocked but the mirrored wall at the x-side cell didn't.
	var corner_t: float = 0.5 * sqrt(2.0)
	for d: Vector2i in DIAGONALS:
		for side: Vector2i in [Vector2i(5 + d.x, 5), Vector2i(5, 5 + d.y)]:
			_grid = NavGrid.new(20, 10, 1.0, Vector2.ZERO)
			_grid.set_blocked_rect(Rect2i(side, Vector2i.ONE))
			assert_almost_eq(_grid.ray_distance(Vector2(5.5, 5.5), Vector2(d), 4.0), corner_t, 0.001,
				"dir %s, wall %s" % [d, side])


func test_ray_through_exact_corner_passes_open_corner() -> void:
	for d: Vector2i in DIAGONALS:
		assert_almost_eq(_grid.ray_distance(Vector2(5.5, 5.5), Vector2(d), 4.0), 4.0, 0.001, "dir %s" % d)
	_grid.set_blocked_rect(Rect2i(7, 7, 1, 1))  # 2 cells along (1, 1): reached diagonally
	assert_almost_eq(_grid.ray_distance(Vector2(5.5, 5.5), Vector2(1, 1), 4.0), 1.5 * sqrt(2.0), 0.001)


func test_line_of_sight() -> void:
	_grid.set_blocked_rect(Rect2i(8, 0, 1, 6))
	assert_false(_grid.line_of_sight(Vector2(2.5, 2.5), Vector2(12.5, 2.5)))
	assert_true(_grid.line_of_sight(Vector2(2.5, 8.5), Vector2(12.5, 8.5)), "passes below the wall")
	assert_true(_grid.line_of_sight(Vector2(2.5, 2.5), Vector2(6.5, 2.5)), "stops short of the wall")
