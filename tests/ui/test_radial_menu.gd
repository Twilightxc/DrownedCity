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
