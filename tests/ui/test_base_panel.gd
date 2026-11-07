extends GutTest
## 1.7 step 4: the base's slot panel (ui/base_panel.gd) drives SimCore through BaseRules, by buttons a pad can focus.

var _state: SimState
var _panel: BasePanel


func before_each() -> void:
	_state = BasePreset.make("new", 3, 7, 10)
	_panel = BasePanel.new()
	_panel.state = _state
	add_child_autofree(_panel)


func _button(prefix: String) -> Button:
	for b: Button in _panel._buttons():
		if b.text.begins_with(prefix):
			return b
	return null


func _press(prefix: String) -> void:
	var b: Button = _button(prefix)
	assert_not_null(b, prefix)
	if b != null:
		b.pressed.emit()


func test_an_empty_slot_offers_the_rooms_that_fit_and_builds_one() -> void:
	_panel.open(1)
	assert_not_null(_button("Farm"))
	assert_null(_button("Kitchen"), "a small room in a large slot")
	_press("Farm")
	assert_eq(_state.rooms[1].room, "farm")
	assert_eq(_state.rooms[1].building, 1)
	assert_lt(_state.stock["materials"], 30.0, "paid up front")


func test_a_room_it_cannot_afford_is_greyed_with_the_reason() -> void:
	_state.stock["materials"] = 0.0
	_panel.open(1)
	assert_true(_button("Farm").disabled)
	_panel.close()
	assert_false(_panel.is_open())


func test_the_queue_takes_jobs_and_gives_inputs_back_on_cancel() -> void:
	BasePreset.apply(_state, "tier1")
	_state.rooms[1].queue.clear()
	_panel.open(1)
	_press("+5")
	assert_eq(_state.rooms[1].queue.size(), 1)
	assert_eq(int(_state.rooms[1].queue[0]["count"]), 5)
	assert_true(_button("+1").disabled, "soil beds queue one job")
	_press("Cancel")
	assert_eq(_state.rooms[1].queue.size(), 0)


func test_pinning_toggles_and_demolish_asks_twice() -> void:
	BasePreset.apply(_state, "tier1")
	var s: Survivor = _state.survivors[0]
	_panel.open(4)
	_press(s.name)
	assert_eq(s.assignment, 4)
	_press("PINNED · " + s.name)
	assert_eq(s.assignment, -1)
	_press("Demolish")
	assert_eq(_state.rooms[4].room, "kitchen", "not yet")
	_press("Really tear it down")
	assert_eq(_state.rooms[4].room, "")


func test_upgrade_shows_why_not_and_goes_when_it_can() -> void:
	BasePreset.apply(_state, "tier1")
	_panel.open(2)
	assert_true(_button("Upgrade to Clinic").disabled, "the clinic needs a Medicine survivor")
	_panel.open(0)
	_press("Upgrade to Cots")
	assert_eq(_state.rooms[0].building, 2)


func test_the_pad_lands_on_a_button_when_the_panel_opens() -> void:
	_panel.open(1)
	await get_tree().process_frame
	assert_true(get_viewport().gui_get_focus_owner() is Button)
