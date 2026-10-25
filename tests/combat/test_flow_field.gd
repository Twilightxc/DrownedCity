extends GutTest


func _open_grid(w: int, h: int) -> NavGrid:
	return NavGrid.new(w, h, 1.0, Vector2.ZERO)


func test_distances_from_single_target() -> void:
	var grid: NavGrid = _open_grid(5, 5)
	var flow: FlowField = FlowField.new(grid)
	flow.compute([Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(flow.distance_at(Vector2i(0, 0)), 0)
	assert_eq(flow.distance_at(Vector2i(4, 0)), 4)
	assert_eq(flow.distance_at(Vector2i(4, 4)), 8)


func test_direction_points_toward_target() -> void:
	var grid: NavGrid = _open_grid(5, 5)
	var flow: FlowField = FlowField.new(grid)
	flow.compute([Vector2i(0, 2)] as Array[Vector2i])
	var dir: Vector2 = flow.sample(grid.cell_center(Vector2i(4, 2)))
	assert_almost_eq(dir.x, -1.0, 0.001)
	assert_almost_eq(dir.y, 0.0, 0.001)
	assert_eq(flow.sample(grid.cell_center(Vector2i(0, 2))), Vector2.ZERO, "target cell has no direction")


func test_routes_around_wall() -> void:
	# Wall at x=2 from y=0..3 leaves a gap at y=4.
	var grid: NavGrid = _open_grid(5, 5)
	grid.set_blocked_rect(Rect2i(2, 0, 1, 4))
	var flow: FlowField = FlowField.new(grid)
	flow.compute([Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(flow.distance_at(Vector2i(4, 0)), 12, "must walk down, through the gap and back up")
	assert_eq(flow.distance_at(Vector2i(2, 0)), FlowField.UNREACHABLE, "wall cell")
	# From right next to the wall the field must not point into it.
	var dir: Vector2 = flow.sample(grid.cell_center(Vector2i(3, 0)))
	assert_almost_eq(dir.y, 1.0, 0.001, "go down toward the gap")


func test_no_corner_cutting() -> void:
	var grid: NavGrid = _open_grid(3, 3)
	grid.set_blocked_rect(Rect2i(1, 0, 1, 1))
	var flow: FlowField = FlowField.new(grid)
	flow.compute([Vector2i(0, 0)] as Array[Vector2i])
	var dir: Vector2 = flow.sample(grid.cell_center(Vector2i(1, 1)))
	assert_ne(dir, Vector2(-1, -1).normalized(), "diagonal past a blocked corner is not allowed")


func test_enclosed_area_is_unreachable() -> void:
	var grid: NavGrid = _open_grid(5, 5)
	grid.set_blocked_rect(Rect2i(0, 2, 5, 1))
	var flow: FlowField = FlowField.new(grid)
	flow.compute([Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(flow.distance_at(Vector2i(0, 4)), FlowField.UNREACHABLE)
	assert_eq(flow.sample(grid.cell_center(Vector2i(0, 4))), Vector2.ZERO)


func test_multiple_targets_take_nearest() -> void:
	var grid: NavGrid = _open_grid(9, 1)
	var flow: FlowField = FlowField.new(grid)
	flow.compute([Vector2i(0, 0), Vector2i(8, 0)] as Array[Vector2i])
	assert_eq(flow.distance_at(Vector2i(4, 0)), 4)
	assert_almost_eq(flow.sample(grid.cell_center(Vector2i(6, 0))).x, 1.0, 0.001)
