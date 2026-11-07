extends GutTest
## 1.6 community skills, books and combat classes (docs/CITIZENS_1_6.md §6–7).

var _rules: SimRules
var _state: SimState
var _s: Survivor


func before_each() -> void:
	_rules = SimRules.new()
	_state = SimState.new()
	_s = _state.add_survivor("Rosa", 7)
	_s.status = "member"
	for res: String in SimState.RESOURCES:
		_state.stock[res] = 100.0
	_state.stock["meals"] = 0.0  # rations, not cooked meals


func _outstanding(s: Survivor, skill: String) -> void:
	s.community_skill = skill
	s.status = "outstanding"


func test_the_data_has_fourteen_skills_with_two_specs_and_six_classes() -> void:
	var skills: Dictionary = CommunityRules.skills()
	assert_eq(skills.size(), 14)
	var leaders: Dictionary = StatusRules.data()["leaders"]
	for id: String in skills:
		assert_eq((skills[id]["specs"] as Dictionary).size(), 2, id)
		var path: String = str(skills[id]["leader"])
		assert_true(path == "any" or leaders.has(path), "%s leads as %s" % [id, path])
	assert_eq(CommunityRules.classes().size(), 6, "the demo has all six (J)")
	for bg: String in CommunityRules.data()["born"]["from_background"]:
		assert_true(SkillCatalog.load_default().backgrounds.has(bg), bg)


func test_some_are_born_with_their_backgrounds_skill() -> void:
	var born: int = 0
	for i: int in 400:
		var s: Survivor = Survivor.new(1, "x", 1)
		s.background = "doctor"
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = i
		CommunityRules.roll_born(s, rng)
		if s.community_skill == "medicine":
			born += 1
		else:
			assert_eq(s.community_skill, "", "medicine or nothing")
	assert_almost_eq(born / 400.0, 0.5, 0.08)
	var boxer: Survivor = Survivor.new(1, "x", 1)
	boxer.background = "boxer"
	CommunityRules.roll_born(boxer, RandomNumberGenerator.new())
	assert_eq(boxer.community_skill, "")


func test_a_new_game_keeps_the_founders_traits_and_is_repeatable() -> void:
	var a: SimState = SimState.new_game(_rules, 42)
	var b: SimState = SimState.new_game(_rules, 42)
	assert_eq(a.to_dict(), b.to_dict())


func test_a_skill_book_fills_an_empty_slot_after_three_days() -> void:
	_state.books["skill:radio"] = 1
	assert_true(CommunityRules.start_reading(_state, _s, "skill:radio"))
	assert_false(_state.books.has("skill:radio"), "taken off the shelf")
	assert_false(CommunityRules.start_reading(_state, _s, "skill:radio"), "no copy left")
	for d: int in 2:
		_state.advance_day(_rules)
	assert_eq(_s.community_skill, "")
	_state.advance_day(_rules)
	assert_eq(_s.community_skill, "radio")
	assert_eq(_s.reading, "")


func test_the_slot_takes_one_skill_and_specs_need_their_skill() -> void:
	_s.community_skill = "medicine"
	assert_false(CommunityRules.can_read(_s, "skill:radio"), "the slot is full")
	assert_false(CommunityRules.can_read(_s, "spec:radio:signals"), "not their skill")
	assert_false(CommunityRules.can_read(_s, "spec:medicine:nope"))
	assert_true(CommunityRules.can_read(_s, "spec:medicine:surgery"))
	_s.community_specs.append("surgery")
	assert_false(CommunityRules.can_read(_s, "spec:medicine:surgery"), "already known")
	assert_true(CommunityRules.room_mods(_s).has_perk(&"heavy_injury_half_time"))


func test_the_skill_decides_the_leader_type_and_a_book_adds_one() -> void:
	_outstanding(_s, "engineering")
	assert_eq(CommunityRules.leader_types(_s), PackedStringArray(["builder"]))
	assert_false(StatusRules.appoint(_state, _s, "trader"))
	assert_true(StatusRules.appoint(_state, _s, "builder"))
	_state.books["leader:trader"] = 1
	assert_false(CommunityRules.can_read(_s, "leader:builder"), "already a builder")
	assert_true(CommunityRules.start_reading(_state, _s, "leader:trader"))
	for d: int in 3:
		_state.advance_day(_rules)
	assert_true(StatusRules.appoint(_state, _s, "trader"))


func test_a_teacher_can_lead_as_anything() -> void:
	_outstanding(_s, "teaching")
	assert_eq(CommunityRules.leader_types(_s).size(), 6)


func test_a_library_halves_reading_for_the_whole_base() -> void:
	var librarian: Survivor = _state.add_survivor("Lin", 8)
	_outstanding(librarian, "teaching")
	librarian.community_specs.append("library")
	_state.books["skill:cooking"] = 1
	assert_true(CommunityRules.start_reading(_state, _s, "skill:cooking"))
	assert_eq(_s.read_days, 2, "3 days × (1 − 0.25 at half strength)")


func test_outstanding_citizens_stack_their_skills_at_half_strength_in_the_base() -> void:
	var medic: Survivor = _state.add_survivor("Ana", 8)
	var gardener: Survivor = _state.add_survivor("Bo", 9)
	_outstanding(medic, "medicine")
	_outstanding(gardener, "gardening")
	_s.community_skill = "medicine"  # a member: works in their room only
	var base: StatMods = CommunityRules.base_wide(_state)
	assert_almost_eq(base.apply(&"heal_rate", 1.0), 1.125, 0.001)
	assert_almost_eq(base.apply(&"food_output", 1.0), 1.1, 0.001)
	assert_false(base.has_perk(&"infirmary_t2"), "unlocks stay with the room")
	medic.needs.activity = "mission"
	assert_almost_eq(CommunityRules.base_wide(_state).apply(&"heal_rate", 1.0), 1.0, 0.001, "away on a mission")


func test_the_base_wide_medicine_buff_heals_everyone_faster() -> void:
	var medic: Survivor = _state.add_survivor("Ana", 8)
	_outstanding(medic, "medicine")
	NeedRules.injure(_s, "light", StatMods.new())
	_state.advance_day(_rules)
	assert_almost_eq(float(_s.needs.injuries[0]["hours"]), 48.0 - 24.0 * 1.125, 0.001)


func test_a_leadership_citizen_lifts_everyones_morale() -> void:
	var boss: Survivor = _state.add_survivor("Ana", 8)
	_outstanding(boss, "leadership")
	_s.morale = 50.0
	_state.advance_day(_rules)
	assert_almost_eq(_s.morale, 50.5, 0.001)


func test_a_member_picks_a_class_once_and_changes_it_later() -> void:
	var stranger: Survivor = _state.add_survivor("Ana", 8)
	assert_false(CommunityRules.needs_class(stranger))
	assert_false(CommunityRules.pick_class(stranger, "medic"), "strangers have no class")
	assert_true(CommunityRules.needs_class(_s))
	assert_false(CommunityRules.pick_class(_s, "wizard"))
	assert_true(CommunityRules.pick_class(_s, "medic"))
	assert_false(CommunityRules.needs_class(_s))
	assert_false(CommunityRules.pick_class(_s, "rifleman"), "picking is once; changing is a training-room thing")
	assert_true(CommunityRules.change_class(_s, "rifleman"))
	assert_eq(_s.combat_class, "rifleman")


func test_a_class_puts_its_passive_and_ability_on_the_build() -> void:
	CommunityRules.pick_class(_s, "grenadier")
	var m: StatMods = BuildRules.mods(_s)
	assert_almost_eq(m.apply(&"grenades_carried", 2.0), 4.0, 0.001)
	assert_almost_eq(m.apply(&"self_blast_damage", 100.0), 75.0, 0.001)
	assert_true(m.has_perk(&"class_grenadier"))
	assert_true(m.has_perk(&"ability_barrage"))


func test_all_of_it_survives_a_save_and_a_schema_5_save_loads() -> void:
	_outstanding(_s, "radio")
	_s.community_specs.append("signals")
	_s.leader_paths.append("warlord")
	CommunityRules.pick_class(_s, "marksman")
	_state.books["skill:cooking"] = 2
	_state.books["spec:radio:negotiation"] = 1
	CommunityRules.start_reading(_state, _s, "spec:radio:negotiation")
	var text: String = SaveCodec.encode(_state)
	var back: SaveCodec.Result = SaveCodec.decode(text)
	assert_eq(back.error, "")
	assert_eq(back.state.to_dict(), _state.to_dict())
	var envelope: Dictionary = JSON.parse_string(text)
	envelope["schema"] = 5
	envelope["state"].erase("books")
	for sd: Dictionary in envelope["state"]["survivors"]:
		for key: String in ["community_skill", "community_specs", "leader_paths", "reading", "read_days", "combat_class"]:
			sd.erase(key)
	var old: SaveCodec.Result = SaveCodec.decode(JSON.stringify(envelope))
	assert_eq(old.error, "")
	assert_eq(old.migrated_from, 5)
	assert_eq(old.state.survivors[0].community_skill, "")
	assert_true(CommunityRules.needs_class(old.state.survivors[0]), "asked to pick a class")
	assert_true(old.state.books.is_empty())
