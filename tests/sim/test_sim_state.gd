extends GutTest

var _rules: SimRules


func before_each() -> void:
	_rules = SimRules.new()


func test_new_game_has_starting_survivors_and_stock() -> void:
	var state: SimState = SimState.new_game(_rules, 42)
	assert_eq(state.survivors.size(), 3)
	assert_eq(state.survivors[0].id, 1)
	assert_eq(state.next_survivor_id, 4)
	assert_eq(state.stock["food"], 8.0)
	assert_eq(state.stock.size(), SimState.RESOURCES.size())


func test_same_seed_gives_same_looks() -> void:
	var a: SimState = SimState.new_game(_rules, 7)
	var b: SimState = SimState.new_game(_rules, 7)
	assert_eq(a.survivors[2].appearance_seed, b.survivors[2].appearance_seed)


func test_advance_day_consumes_upkeep_and_moves_clock() -> void:
	var state: SimState = SimState.new_game(_rules, 1)
	state.advance_day(_rules)
	assert_eq(state.clock.day, 2)
	assert_almost_eq(state.stock["food"], 5.0, 0.001)  # 8 - 3 people
	assert_almost_eq(state.stock["water"], 10.5, 0.001)  # 12 + 3 rain barrels - 4.5
	assert_almost_eq(state.stock["materials"], 5.0, 0.001)
	assert_eq(state.survivors[0].health, Survivor.MAX_STAT, "no shortage, no damage")


func test_a_shortage_lowers_morale_at_once_and_starves_later() -> void:
	var state: SimState = SimState.new_game(_rules, 1)
	state.stock["food"] = 1.0
	state.advance_day(_rules)
	assert_eq(state.stock["food"], 0.0)
	assert_eq(state.survivors[0].morale, Survivor.MAX_STAT - _rules.shortage_morale_loss)
	assert_eq(state.survivors[2].health, Survivor.MAX_STAT, "one missed meal: hungry by the next morning, not hurt")
	assert_gt(state.survivors[2].needs.hunger, 40.0)
	state.advance_day(_rules)
	state.advance_day(_rules)
	assert_lt(state.survivors[2].health, Survivor.MAX_STAT, "starving on the third day")


func test_dead_survivors_do_not_eat() -> void:
	var state: SimState = SimState.new_game(_rules, 1)
	state.survivors[0].damage(Survivor.MAX_STAT)
	state.advance_day(_rules)
	assert_almost_eq(state.stock["food"], 6.0, 0.001, "2 living people")
