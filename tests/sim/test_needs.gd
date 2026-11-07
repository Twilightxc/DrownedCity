extends GutTest
## 1.6 body needs (GDD §3 "status of body and mind", §11): data/sim/needs.json + NeedRules.

var _rules: SimRules
var _state: SimState
var _s: Survivor
var _m: StatMods


func before_each() -> void:
	_rules = SimRules.new()
	_state = SimState.new()
	_state.game_seed = 5
	_s = _state.add_survivor("Rosa", 7)
	for res: String in SimState.RESOURCES:
		_state.stock[res] = 100.0
	_state.stock["antiviral"] = 0.0
	_m = StatMods.new()


func _rng(i: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = i
	return r


## How many of `n` exposures make a fresh survivor sick.
func _sick_rate(source: String, m: StatMods, n: int = 2000) -> float:
	var hits: int = 0
	for i: int in n:
		var s: Survivor = Survivor.new(1, "x", 1)
		if NeedRules.expose(s, source, m, _rng(i)):
			hits += 1
	return float(hits) / n


func test_work_by_day_and_a_night_in_bed_balance_out() -> void:
	assert_eq(NeedRules.activity(_s, 23), "sleep")
	assert_eq(NeedRules.activity(_s, 3), "sleep")
	assert_eq(NeedRules.activity(_s, 12), "work")
	for h: int in range(6, 22):
		NeedRules.tick_hour(_s, h, _m, _rng(h))
	assert_almost_eq(_s.needs.fatigue, 64.0, 0.001, "16 h of work")
	assert_lt(BuildRules.mods(_s).apply(&"max_stamina", 100.0), 70.0, "tired = less stamina")
	for h: int in [22, 23, 0, 1, 2, 3, 4, 5]:
		NeedRules.tick_hour(_s, h, _m, _rng(h))
	assert_eq(_s.needs.fatigue, 0.0, "slept it off")


func test_short_sleeper_tires_slower_and_night_owl_faster_by_day() -> void:
	TraitRules.give(_s, "short_sleeper")
	NeedRules.tick_hour(_s, 12, BuildRules.base_mods(_s), _rng(1))
	assert_almost_eq(_s.needs.fatigue, 3.0, 0.001, "work 4 × 0.75")
	var owl: Survivor = Survivor.new(2, "Owl", 2)
	TraitRules.give(owl, "night_owl")
	NeedRules.tick_hour(owl, 12, BuildRules.base_mods(owl), _rng(1))
	assert_almost_eq(owl.needs.fatigue, 5.0, 0.001, "work 4 × 1.25")


func test_marathon_softens_what_fatigue_costs() -> void:
	_s.needs.fatigue = 100.0
	var plain: StatMods = StatMods.new()
	NeedRules.add_mods(_s, plain)
	assert_almost_eq(plain.apply(&"max_stamina", 100.0), 50.0, 0.001)
	var marathon: StatMods = StatMods.new()
	marathon.push(&"fatigue", "mul", -0.4)
	NeedRules.add_mods(_s, marathon)
	assert_almost_eq(marathon.apply(&"max_stamina", 100.0), 70.0, 0.001)


func test_fed_and_watered_every_morning_nobody_suffers() -> void:
	for d: int in 5:
		_state.advance_day(_rules)
	assert_eq(_s.health, Survivor.MAX_STAT)
	assert_eq(_s.needs.sick_days, 0, "never thirsty enough for flood water")
	assert_lt(_s.needs.hunger, 50.0)


func test_without_food_hunger_turns_to_starving() -> void:
	_state.stock["food"] = 0.0
	for d: int in 3:
		_state.advance_day(_rules)
	assert_eq(_s.needs.hunger, 100.0)
	assert_lt(_s.health, Survivor.MAX_STAT)
	assert_true(BuildRules.mods(_s).apply(&"max_stamina", 100.0) < 80.0)


func test_a_partial_meal_takes_part_of_the_hunger() -> void:
	_s.needs.hunger = 80.0
	_state.stock["food"] = 0.5
	_state.advance_day(_rules)
	assert_eq(_state.stock["food"], 0.0)
	assert_almost_eq(_s.needs.hunger, 40.0 + 48.0, 0.001, "half a meal, then a day")


func test_without_water_they_drink_the_flood_water() -> void:
	_state.stock["water"] = 0.0
	_s.needs.thirst = 74.0
	NeedRules.tick_hour(_s, 12, _m, _rng(1))
	assert_eq(_s.needs.thirst, 0.0, "drank")
	assert_almost_eq(_sick_rate("flood_water", _m), 0.3, 0.04)


func test_weak_immune_doubles_sickness_and_iron_stomach_shrugs_off_dirty_water() -> void:
	var weak: StatMods = StatMods.new()
	weak.push(&"sickness_chance", "mul", 1.0)
	assert_almost_eq(_sick_rate("rain", weak), 0.2, 0.03)
	var iron: StatMods = StatMods.new()
	iron.grant(&"no_dirty_food_sickness")
	assert_eq(_sick_rate("flood_water", iron), 0.0)
	assert_gt(_sick_rate("rain", iron), 0.0, "rain still gets them")


func test_sickness_runs_its_course_faster_with_medicine() -> void:
	_s.needs.sick_days = 3
	_state.advance_day(_rules)
	assert_eq(_s.needs.sick_days, 1, "medicine takes a day more off")
	assert_eq(_state.stock["medicine"], 99.0)
	_state.stock["medicine"] = 0.0
	var b: Survivor = _state.add_survivor("Ana", 8)
	b.needs.sick_days = 3
	_state.advance_day(_rules)
	assert_eq(b.needs.sick_days, 2, "no medicine: one day a day")


func test_sickness_spreads_in_the_base() -> void:
	var got_sick: int = 0
	for i: int in 200:
		var state: SimState = SimState.new()
		state.game_seed = i
		for res: String in SimState.RESOURCES:
			state.stock[res] = 100.0
		state.add_survivor("A", 1).needs.sick_days = 5
		var b: Survivor = state.add_survivor("B", 2)
		state.advance_day(_rules)
		if b.needs.sick_days > 0:
			got_sick += 1
	assert_almost_eq(got_sick / 200.0, 0.1, 0.05)


func test_injuries_heal_slower_without_medicine_and_heavy_ones_keep_you_home() -> void:
	NeedRules.injure(_s, "fracture", _m)
	assert_true(NeedRules.heavily_injured(_s))
	assert_false(NeedRules.fit_to_go_out(_s))
	assert_true(BuildRules.mods(_s).has_perk(&"unfit"))
	_state.advance_day(_rules)
	assert_almost_eq(float(_s.needs.injuries[0]["hours"]), 240.0 - 24.0, 0.001)
	_state.stock["medicine"] = 0.0
	_state.advance_day(_rules)
	assert_almost_eq(float(_s.needs.injuries[0]["hours"]), 240.0 - 24.0 - 12.0, 0.001, "half speed")
	NeedRules.injure(_s, "light", _m)
	assert_eq(_s.needs.injuries.size(), 2)


func test_fast_healer_and_endurance_shorten_injuries() -> void:
	var tough: StatMods = StatMods.new()
	tough.push(&"injury_severity", "mul", -0.5)
	NeedRules.injure(_s, "light", tough)
	assert_almost_eq(float(_s.needs.injuries[0]["hours"]), 24.0, 0.001)
	var fast: StatMods = StatMods.new()
	fast.push(&"heal_rate", "mul", 0.5)
	for h: int in 16:
		NeedRules.tick_hour(_s, 12, fast, _rng(h))
	assert_eq(_s.needs.injuries.size(), 0, "24 h at 1.5 per hour")


func test_bites_infect_and_resistant_helps() -> void:
	var plain: int = 0
	var resistant: int = 0
	var res_m: StatMods = StatMods.new()
	res_m.push(&"infection_chance", "mul", -0.3)
	for i: int in 2000:
		if NeedRules.on_bitten(Survivor.new(1, "x", 1), 1, _m, _rng(i)):
			plain += 1
		if NeedRules.on_bitten(Survivor.new(1, "x", 1), 1, res_m, _rng(i)):
			resistant += 1
	assert_almost_eq(plain / 2000.0, 0.25, 0.03)
	assert_almost_eq(resistant / 2000.0, 0.175, 0.03)
	assert_false(NeedRules.on_bitten(Survivor.new(1, "x", 1), 0, _m, _rng(1)), "no bite, no risk")


func test_an_antiviral_in_time_cures_the_infection() -> void:
	_s.needs.infection_hours = 72
	_state.advance_day(_rules)
	assert_eq(_s.needs.infection_hours, 72 - 24)
	_state.stock["antiviral"] = 1.0
	_state.advance_day(_rules)
	assert_false(_s.needs.infected())
	assert_eq(_state.stock["antiviral"], 0.0)


func test_out_of_time_the_player_chooses() -> void:
	_s.needs.infection_hours = 72
	var b: Survivor = _state.add_survivor("Ana", 8)
	for d: int in 3:
		_state.advance_day(_rules)
	assert_true(NeedRules.waiting_for_choice(_s))
	assert_false(NeedRules.fit_to_go_out(_s))
	assert_false(NeedRules.resolve_infection(_state, _s, "pray"))
	b.morale = 50.0
	assert_true(NeedRules.resolve_infection(_state, _s, "exile"))
	assert_false(_s in _state.survivors, "left the community")
	assert_eq(b.morale, 45.0)


func test_quarantine_buys_three_days_then_they_turn() -> void:
	_s.needs.infection_hours = 1
	var b: Survivor = _state.add_survivor("Ana", 8)
	NeedRules.tick_hour(_s, 12, _m, _rng(1))
	assert_true(NeedRules.resolve_infection(_state, _s, "quarantine"))
	assert_eq(_s.needs.infection_hours, 72)
	for d: int in 3:
		_state.advance_day(_rules)
	assert_false(_s.is_alive(), "turned")
	assert_lt(b.morale, Survivor.MAX_STAT)


func test_an_antiviral_still_works_in_quarantine() -> void:
	_s.needs.infection_hours = 0
	assert_true(NeedRules.resolve_infection(_state, _s, "quarantine"))
	_state.stock["antiviral"] = 1.0
	_state.advance_day(_rules)
	assert_false(_s.needs.infected())
	assert_false(_s.needs.quarantined)
	assert_true(NeedRules.fit_to_go_out(_s))


func test_end_life_is_a_death() -> void:
	_s.needs.infection_hours = 0
	assert_true(NeedRules.resolve_infection(_state, _s, "end_life"))
	assert_false(_s.is_alive())
	assert_true(_s in _state.survivors, "remembered, not gone")


func test_needs_survive_a_save_and_a_schema_3_save_loads_well() -> void:
	_s.needs.fatigue = 33.0
	_s.needs.sick_days = 2
	_s.needs.infection_hours = 40
	NeedRules.injure(_s, "burn", _m)
	var text: String = SaveCodec.encode(_state)
	var back: SaveCodec.Result = SaveCodec.decode(text)
	assert_eq(back.error, "")
	assert_eq(back.state.to_dict(), _state.to_dict())
	var envelope: Dictionary = JSON.parse_string(text)
	envelope["schema"] = 3
	for sd: Dictionary in envelope["state"]["survivors"]:
		sd.erase("needs")
	envelope["state"]["stock"].erase("medicine")
	envelope["state"]["stock"].erase("antiviral")
	var old: SaveCodec.Result = SaveCodec.decode(JSON.stringify(envelope))
	assert_eq(old.error, "")
	assert_eq(old.migrated_from, 3)
	assert_eq(old.state.survivors[0].needs.fatigue, 0.0)
	assert_eq(old.state.stock["medicine"], 0.0)


func test_every_injury_kind_is_well_formed() -> void:
	for kind: String in NeedRules.data()["injury"]["kinds"]:
		var k: Dictionary = NeedRules.data()["injury"]["kinds"][kind]
		assert_gt(float(k["heal_hours"]), 0.0, kind)
		assert_lt(float(k["stamina_mul"]), 0.0, kind)
