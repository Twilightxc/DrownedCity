extends GutTest
## 1.6 core skills and backgrounds (docs/CITIZENS_1_6.md §3–4).

var _cat: SkillCatalog
var _s: Survivor


func before_each() -> void:
	_cat = SkillCatalog.load_default()
	_s = Survivor.new(1, "Rosa", 7)
	SkillRules.setup(_s, "boxer", _cat)


func _to_seven(skill: String) -> void:
	for i: int in 20:
		SkillRules.add_xp(_s, skill, 10000.0, _cat)


func test_the_catalog_has_five_skills_with_four_specs_and_nine_backgrounds() -> void:
	assert_eq(_cat.skill_ids().size(), 5)
	for id: String in _cat.skill_ids():
		assert_eq(_cat.spec_ids(id).size(), 4, id)
		for t: Dictionary in _cat.skills[id]["tracks"]:
			assert_eq((t["values"] as Array).size(), SkillCatalog.MAX_LEVEL + 1, "%s %s" % [id, t["stat"]])
	assert_eq(_cat.background_ids().size(), 9)
	assert_eq(_cat.xp_to_next.size(), SkillCatalog.MAX_LEVEL)


func test_a_background_sets_starting_levels() -> void:
	assert_eq(_s.skills["fitness"].level, 3, "boxer")
	assert_eq(_s.skills["melee"].level, 3)
	assert_eq(_s.skills["shooting"].level, 0)
	SkillRules.setup(_s, "ex_soldier", _cat)
	assert_eq(_s.skills["shooting"].level, 3)
	assert_almost_eq(SkillRules.mods(_s, _cat).apply(&"spread", 1.0), 0.75, 0.001, "spread −25 %")


func test_xp_raises_levels_and_stops_at_seven_until_a_spec() -> void:
	SkillRules.setup(_s, "farmer", _cat)
	assert_eq(SkillRules.add_xp(_s, "shooting", _cat.xp_to_next[0], _cat), 1)
	assert_eq(_s.skills["shooting"].level, 1)
	_to_seven("shooting")
	assert_eq(_s.skills["shooting"].level, 7)
	assert_true(_s.skills["shooting"].waiting_for_spec())
	assert_eq(SkillRules.add_xp(_s, "shooting", 99999.0, _cat), 0, "no XP past 7 without a spec")


func test_doing_things_grows_the_right_skill() -> void:
	SkillRules.setup(_s, "farmer", _cat)
	SkillRules.on_action(_s, "shot", 400.0, _cat)  # 0.25 XP a shot
	assert_eq(_s.skills["shooting"].level, 1)
	assert_eq(_s.skills["wits"].level, 0)


func test_shooting_levels_cut_sway_and_speed_up_reloads() -> void:
	SkillRules.setup(_s, "farmer", _cat)
	_to_seven("shooting")
	var m: StatMods = SkillRules.mods(_s, _cat)
	assert_almost_eq(m.apply(&"sway", 1.0), 0.75, 0.001)
	assert_almost_eq(m.apply(&"reload_speed", 1.0), 1.5, 0.001)


func test_the_second_climb_grows_the_spec_to_full_at_seven_without_losing_anything() -> void:
	_to_seven("fitness")
	assert_almost_eq(SkillRules.mods(_s, _cat).apply(&"max_stamina", 100.0), 121.0, 0.001)
	assert_false(SkillRules.choose_spec(_s, "fitness", "nope", _cat))
	assert_true(SkillRules.choose_spec(_s, "fitness", "backpacking", _cat))
	var k: SurvivorSkill = _s.skills["fitness"]
	assert_eq([k.climb, k.level, k.spec], [2, 0, "backpacking"])
	var m0: StatMods = SkillRules.mods(_s, _cat)
	assert_almost_eq(m0.apply(&"max_stamina", 100.0), 121.0, 0.001, "keeps level 7's +21 at once")
	assert_almost_eq(m0.apply(&"carry", 0.0), 0.0, 0.001, "spec-only numbers start at 0")
	_to_seven("fitness")
	assert_true(k.maxed())
	var m7: StatMods = SkillRules.mods(_s, _cat)
	assert_almost_eq(m7.apply(&"max_stamina", 100.0), 161.0, 0.001, "Backpacking +61 at 7")
	assert_almost_eq(m7.apply(&"carry", 0.0), 30.0, 0.001)


func test_a_spec_grants_its_perks() -> void:
	SkillRules.setup(_s, "farmer", _cat)
	_to_seven("wits")
	assert_true(SkillRules.choose_spec(_s, "wits", "stealth", _cat))
	assert_true(SkillRules.mods(_s, _cat).has_perk(&"crouch_sprint"))


func test_every_stat_and_spec_in_the_data_is_well_formed() -> void:
	for id: String in _cat.skill_ids():
		for spec: String in _cat.spec_ids(id):
			for m: Array in _cat.skills[id]["specs"][spec]["mods"]:
				assert_true(m.size() == 3 and str(m[1]) in ["add", "mul"], "%s/%s %s" % [id, spec, m])
	for id: String in _cat.background_ids():
		for skill: String in (_cat.backgrounds[id].get("start", {}) as Dictionary):
			assert_true(_cat.skills.has(skill), "%s starts %s" % [id, skill])


func test_a_new_game_gives_every_survivor_a_background_and_skills() -> void:
	var state: SimState = SimState.new_game(SimRules.new(), 42)
	for s: Survivor in state.survivors:
		assert_true(_cat.backgrounds.has(s.background), s.name)
		assert_eq(s.skills.size(), 5)
	var again: SimState = SimState.new_game(SimRules.new(), 42)
	assert_eq(again.to_dict(), state.to_dict(), "same seed, same community")
