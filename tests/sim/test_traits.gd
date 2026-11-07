extends GutTest
## 1.6 traits (GDD §3, docs/CITIZENS_1_6.md §5).

var _s: Survivor


func before_each() -> void:
	_s = Survivor.new(1, "Rosa", 7)


func test_rolls_follow_the_gdd_rules() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	for i: int in 300:
		var t: PackedStringArray = TraitRules.roll(rng)
		assert_true(t.size() >= 2 and t.size() <= 3, str(t))
		var neg: int = 0
		for a: String in t:
			assert_false(TraitRules.is_earned(a), "%s is never rolled" % a)
			if TraitRules.is_negative(a):
				neg += 1
			for b: String in t:
				if a != b:
					assert_false(TraitRules.conflicts(a, b), "%s + %s" % [a, b])
		assert_gt(neg, 0, "at least one negative: %s" % t)


func test_every_trait_is_well_formed() -> void:
	var defs: Dictionary = TraitRules.defs()
	assert_eq(defs.size(), 37, "GDD 25 + J's 9 + 3 earned")
	for id: String in defs:
		for m: Array in defs[id].get("mods", []):
			assert_true(m.size() >= 3 and str(m[1]) in ["add", "mul"], "%s %s" % [id, m])
		for other: String in defs[id].get("conflicts", []):
			assert_true(defs.has(other), "%s conflicts with unknown %s" % [id, other])


func test_steady_hands_only_steadies_its_gun_classes() -> void:
	TraitRules.give(_s, "steady_hands")
	var m: StatMods = StatMods.new()
	TraitRules.add_mods(_s, m)
	assert_almost_eq(m.apply_for(&"spread", "pistol", 1.0), 0.8, 0.001)
	assert_almost_eq(m.apply_for(&"spread", "shotgun", 1.0), 1.0, 0.001)


func test_conflicting_traits_are_refused() -> void:
	assert_true(TraitRules.give(_s, "athlete"))
	assert_false(TraitRules.give(_s, "asthmatic"))


func test_hardened_after_five_horde_nights_cures_panicky_for_good() -> void:
	TraitRules.give(_s, "panicky")
	for i: int in 4:
		TraitRules.count(_s, "horde_nights")
	assert_false("hardened" in _s.traits)
	TraitRules.count(_s, "horde_nights")
	assert_true("hardened" in _s.traits)
	assert_false("panicky" in _s.traits)
	assert_false(TraitRules.give(_s, "panicky"), "never again")


func test_water_rat_after_twenty_dives_brings_born_diver() -> void:
	TraitRules.count(_s, "dives", 20)
	assert_true("water_rat" in _s.traits)
	assert_true("born_diver" in _s.traits)


func test_survivors_guilt_lasts_five_days_and_lowers_morale() -> void:
	var rules: SimRules = SimRules.new()
	var state: SimState = SimState.new()
	state.survivors.append(_s)
	for res: String in SimState.RESOURCES:
		state.stock[res] = 100.0
	state.stock["meals"] = 0.0  # rations, not cooked meals
	TraitRules.on_event(_s, "close_friend_died")
	assert_true("survivors_guilt" in _s.traits)
	_s.morale = 50.0
	state.advance_day(rules)
	assert_almost_eq(_s.morale, 45.0, 0.001)
	for i: int in 4:
		state.advance_day(rules)
	assert_false("survivors_guilt" in _s.traits, "gone after 5 days")


func test_a_big_eater_eats_half_again() -> void:
	var rules: SimRules = SimRules.new()
	var state: SimState = SimState.new()
	state.survivors.append(_s)
	for res: String in SimState.RESOURCES:
		state.stock[res] = 100.0
	state.stock["meals"] = 0.0  # rations, not cooked meals
	TraitRules.give(_s, "big_eater")
	state.advance_day(rules)
	assert_almost_eq(state.stock["food"], 100.0 - rules.food_per_survivor * 1.5, 0.001)


func test_an_optimist_lifts_everyone() -> void:
	var rules: SimRules = SimRules.new()
	var state: SimState = SimState.new()
	var other: Survivor = Survivor.new(2, "Mali", 3)
	state.survivors.append_array([_s, other])
	for res: String in SimState.RESOURCES:
		state.stock[res] = 100.0
	state.stock["meals"] = 0.0  # rations, not cooked meals
	TraitRules.give(_s, "optimist")
	other.morale = 50.0
	state.advance_day(rules)
	assert_almost_eq(other.morale, 52.0, 0.001)
