extends GutTest
## Style15Level.footprint_cells: props block the cells under them, not every cell they touch.

var _grid: NavGrid


func before_each() -> void:
	_grid = NavGrid.new(25, 21, 1.0, Vector2(-12.5, -10.5))  # the base roof


## J, 2026-10-29: two 1.3 m AC units 1.7 m apart were one 6-cell wall with no way between them.
func test_two_ac_units_leave_the_visible_gap_open() -> void:
	var a: Rect2i = Style15Level.footprint_cells(_grid, Vector2(5, -8), Vector2(1.3, 1.0))
	var b: Rect2i = Style15Level.footprint_cells(_grid, Vector2(8, -8), Vector2(1.3, 1.0))
	assert_eq(a.size, Vector2i(1, 1))
	assert_gte(b.position.x - a.end.x, 1, "at least one free cell between them")


func test_a_prop_thinner_than_a_cell_still_blocks_one() -> void:
	var r: Rect2i = Style15Level.footprint_cells(_grid, Vector2(0.3, 0.2), Vector2(0.4, 0.4))
	assert_eq(r.size, Vector2i(1, 1))
	assert_eq(r.position, _grid.world_to_cell(Vector2(0.3, 0.2)))


func test_a_big_prop_covers_every_cell_centre_under_it() -> void:
	var fp: Vector2 = Vector2(3.4, 3.4)
	var center: Vector2 = Vector2(-5, -7.5)
	var r: Rect2i = Style15Level.footprint_cells(_grid, center, fp)
	for y: int in range(_grid.height):
		for x: int in range(_grid.width):
			var c: Vector2 = _grid.cell_center(Vector2i(x, y))
			var inside: bool = absf(c.x - center.x) < fp.x * 0.5 and absf(c.y - center.y) < fp.y * 0.5
			if inside:
				assert_true(r.has_point(Vector2i(x, y)), "cell %d,%d under the prop" % [x, y])
