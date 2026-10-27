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
	assert_almost_eq(state.stock["water"], 7.5, 0.001)  # 12 - 4.5
	assert_almost_eq(state.stock["materials"], 5.0, 0.001)
	assert_eq(state.survivors[0].health, Survivor.MAX_STAT, "no shortage, no damage")


func test_shortage_hurts_and_floors_stock_at_zero() -> void:
	var state: SimState = SimState.new_game(_rules, 1)
	state.stock["food"] = 1.0
	state.advance_day(_rules)
	assert_eq(state.stock["food"], 0.0)
	assert_eq(state.survivors[0].health, Survivor.MAX_STAT - _rules.hunger_health_loss)
	assert_eq(state.survivors[0].morale, Survivor.MAX_STAT - _rules.shortage_morale_loss)


func test_dead_survivors_do_not_eat() -> void:
	var state: SimState = SimState.new_game(_rules, 1)
	state.survivors[0].damage(Survivor.MAX_STAT)
	state.advance_day(_rules)
	assert_almost_eq(state.stock["food"], 6.0, 0.001, "2 living people")
