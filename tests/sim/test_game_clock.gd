extends GutTest


func test_starts_at_day_one_midnight() -> void:
	var clock: GameClock = GameClock.new()
	assert_eq(clock.day, 1)
	assert_eq(clock.hour, 0)


func test_advance_within_day() -> void:
	var clock: GameClock = GameClock.new(1, 6)
	clock.advance_hours(5)
	assert_eq(clock.day, 1)
	assert_eq(clock.hour, 11)


func test_advance_rolls_over_days() -> void:
	var clock: GameClock = GameClock.new(1, 20)
	clock.advance_hours(53)
	assert_eq(clock.day, 4)
	assert_eq(clock.hour, 1)
	assert_eq(clock.total_hours(), 73)
