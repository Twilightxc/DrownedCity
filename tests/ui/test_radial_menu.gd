extends GutTest


func test_items_run_clockwise_from_top() -> void:
	assert_eq(RadialMenu.index_for(Vector2(0, -1), 6, 0.5), 0, "up")
	assert_eq(RadialMenu.index_for(Vector2(1, -1), 6, 0.5), 1, "up-right")
	assert_eq(RadialMenu.index_for(Vector2(0, 1), 6, 0.5), 3, "down")
	assert_eq(RadialMenu.index_for(Vector2(-1, -1), 6, 0.5), 5, "up-left")
	assert_eq(RadialMenu.index_for(Vector2(-0.1, -1), 6, 0.5), 0, "just left of up wraps to 0")


func test_deadzone_and_empty() -> void:
	assert_eq(RadialMenu.index_for(Vector2(0.2, 0.2), 6, 0.5), -1)
	assert_eq(RadialMenu.index_for(Vector2(0, -1), 0, 0.5), -1)


func test_stick_release_keeps_last_pick() -> void:
	var menu: RadialMenu = RadialMenu.new()
	menu.items = PackedStringArray(["a", "b", "c", "d"])
	add_child_autofree(menu)
	menu.open(Vector2(100, 100))
	menu.point_stick(Vector2(1, 0))
	menu.point_stick(Vector2.ZERO)
	assert_eq(menu.close(), 1)


func test_a_half_step_offset_puts_four_slots_above_and_four_below() -> void:
	# The orders wheel: 8 items, turned half a slot; item 0 sits just right of the top.
	assert_eq(RadialMenu.index_for(Vector2(0.2, -1), 8, 0.5, 0.5), 0, "just right of up")
	assert_eq(RadialMenu.index_for(Vector2(-0.2, -1), 8, 0.5, 0.5), 7, "just left of up")
	assert_eq(RadialMenu.index_for(Vector2(-1, -0.3), 8, 0.5, 0.5), 6, "upper left")
	assert_eq(RadialMenu.index_for(Vector2(1, -0.3), 8, 0.5, 0.5), 1, "upper right")
	assert_eq(RadialMenu.index_for(Vector2(1, 0.3), 8, 0.5, 0.5), 2, "lower right")
	assert_eq(RadialMenu.index_for(Vector2(-1, 0.3), 8, 0.5, 0.5), 5, "lower left")
