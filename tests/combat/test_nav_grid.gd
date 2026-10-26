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


func test_line_of_sight() -> void:
	_grid.set_blocked_rect(Rect2i(8, 0, 1, 6))
	assert_false(_grid.line_of_sight(Vector2(2.5, 2.5), Vector2(12.5, 2.5)))
	assert_true(_grid.line_of_sight(Vector2(2.5, 8.5), Vector2(12.5, 8.5)), "passes below the wall")
	assert_true(_grid.line_of_sight(Vector2(2.5, 2.5), Vector2(6.5, 2.5)), "stops short of the wall")
