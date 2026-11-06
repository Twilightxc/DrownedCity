extends GutTest
## Esc / Start pause (J 2026-11-06). Every test unpauses before it returns (GUT runs in this tree).


func test_open_pauses_and_close_resumes_unless_the_scene_says_no() -> void:
	var menu: PauseMenu = PauseMenu.new()
	add_child_autofree(menu)
	menu.open()
	assert_true(menu.is_open())
	assert_true(get_tree().paused, "the game stops")
	menu.close()
	assert_false(menu.is_open())
	assert_false(get_tree().paused, "and goes on")
	menu.can_open = func() -> bool: return false  # e.g. the orders wheel is up
	menu.open()
	assert_false(menu.is_open())
	assert_false(get_tree().paused)


func test_the_pause_action_toggles_it_and_restart_is_offered() -> void:
	var menu: PauseMenu = PauseMenu.new()
	add_child_autofree(menu)
	var restarts: Array[int] = [0]
	menu.restart_pressed.connect(func() -> void: restarts[0] += 1)
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"pause"
	ev.pressed = true
	menu._unhandled_input(ev)
	assert_true(menu.is_open())
	menu._unhandled_input(ev)
	assert_false(menu.is_open())
	assert_false(get_tree().paused)
	menu.restart_pressed.emit()
	assert_eq(restarts[0], 1)
	assert_true(InputMap.has_action(&"pause"))
