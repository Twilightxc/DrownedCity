extends GutTest
## 1.7 step 2: daily life in the base, a utility AI (GDD §4, data/sim/life.json + LifeRules).

var _rules: SimRules
var _state: SimState
var _s: Survivor


func before_each() -> void:
	_rules = SimRules.new()
	_state = SimState.new()
	_state.game_seed = 3
	BaseRules.init(_state)
	_s = _state.add_survivor("Rosa", 7)
	SkillRules.setup(_s, "farmer", SkillCatalog.load_default())
	for res: String in SimState.RESOURCES:
		_state.stock[res] = 50.0


func _at(hour: int) -> void:
	_state.clock = GameClock.new(1, hour)


func _empty(size: String) -> int:
	for i: int in _state.rooms.size():
		if _state.rooms[i].room.is_empty() and _state.rooms[i].size == size:
			return i
	return -1


## A finished room of this kind in a free slot.
func _room(room: String) -> int:
	var i: int = _empty(str(BaseRules.room_def(room)["size"]))
	BaseRules.build(_state, i, room)
	_state.rooms[i].tier = 1
	_state.rooms[i].building = 0
	return i


func _best(s: Survivor) -> Dictionary:
	return LifeRules.options(_state, s)[0]


func test_works_by_day_and_sleeps_at_night() -> void:
	var i: int = _empty("small")
	BaseRules.build(_state, i, "kitchen")
	_at(12)
	assert_eq(_best(_s)["act"], "work")
	assert_eq(_best(_s)["slot"], i)
	_s.needs.fatigue = 60.0
	_at(23)
	assert_eq(_best(_s)["act"], "sleep")


func test_asleep_until_rested_even_after_dawn() -> void:
	_s.needs.doing = "sleep"
	_s.needs.fatigue = 40.0
	_at(9)
	assert_eq(_best(_s)["act"], "sleep")
	_s.needs.fatigue = 2.0
	assert_ne(_best(_s)["act"], "sleep", "rested")


func test_too_tired_sleeps_by_day() -> void:
	BaseRules.build(_state, _empty("small"), "kitchen")
	_s.needs.fatigue = 90.0
	_at(14)
	assert_eq(_best(_s)["act"], "sleep")


func test_a_day_of_life_works_sleeps_and_ends_rested() -> void:
	var i: int = _empty("large")
	BaseRules.build(_state, i, "farm")
	var seen: Dictionary = {}
	_at(6)
	for h: int in 24:
		_state.advance_hour()
		seen[_s.needs.doing] = int(seen.get(_s.needs.doing, 0)) + 1
	assert_gte(int(seen.get("sleep", 0)), 6, "a night's sleep")
	assert_gte(int(seen.get("work", 0)), 8, "a shift")
	assert_eq(_state.rooms[i].tier, 1, "the farm got built (10 h)")
	assert_lt(_s.needs.fatigue, 30.0)


func test_the_heavily_hurt_rest_by_day_and_sleep_in_the_infirmary_at_night() -> void:
	BaseRules.build(_state, _empty("small"), "kitchen")
	_room("infirmary")
	NeedRules.injure(_s, "fracture", StatMods.new())
	_at(12)
	var opts: Array[Dictionary] = LifeRules.options(_state, _s)
	assert_eq(opts[0]["act"], "rest")
	assert_eq(opts.map(func(o: Dictionary) -> String: return o["act"]), ["rest", "sleep"], "nothing else")
	_at(23)
	_state.advance_hour()
	assert_eq(_s.needs.doing, "sleep")
	assert_almost_eq(float(_s.needs.injuries[0]["hours"]), 240.0 - 1.5, 0.001, "an infirmary bed: +50 %")


func test_two_survivors_spread_over_two_jobs() -> void:
	var other: Survivor = _state.add_survivor("Mali", 8)
	var a: int = _empty("small")
	BaseRules.build(_state, a, "kitchen")
	var b: int = _empty("small")
	BaseRules.build(_state, b, "watchtower")
	_at(12)
	LifeRules.decide(_state)
	assert_eq(_s.needs.doing, "work")
	assert_eq(other.needs.doing, "work")
	assert_ne(_s.needs.doing_slot, other.needs.doing_slot, "the second one takes the other site")


func test_pinned_to_a_room_works_only_there() -> void:
	var farm: int = _empty("large")
	BaseRules.build(_state, farm, "farm")
	var kitchen: int = _empty("small")
	BaseRules.build(_state, kitchen, "kitchen")
	BaseRules.assign(_state, _s, kitchen)
	_at(12)
	for o: Dictionary in LifeRules.options(_state, _s):
		if o["act"] == "work":
			assert_eq(o["slot"], kitchen)


func test_after_a_shift_work_pulls_less_and_a_workhorse_works_longer() -> void:
	var farm: int = _room("farm")
	BaseRules.queue_job(_state, farm, "grow_food")
	_state.stock["food"] = 20.0
	_at(15)
	assert_eq(_best(_s)["act"], "work")
	_s.needs.worked_today = 8.0
	assert_ne(_best(_s)["act"], "work", "shift over")
	TraitRules.give(_s, "workhorse")
	assert_eq(_best(_s)["act"], "work", "8 h × 1.25 = 10 h")


func test_a_shortage_makes_a_job_more_urgent() -> void:
	var farm: int = _room("farm")
	BaseRules.queue_job(_state, farm, "grow_food")
	_at(12)
	_state.stock["food"] = 3.0
	var full: float = _work_score(farm)
	_state.stock["food"] = 0.0
	assert_gt(_work_score(farm), full + 0.5)


func _work_score(slot: int) -> float:
	for o: Dictionary in LifeRules.options(_state, _s):
		if o["act"] == "work" and o["slot"] == slot:
			return o["score"]
	return 0.0


func test_a_job_without_inputs_offers_no_work() -> void:
	var farm: int = _room("farm")
	BaseRules.queue_job(_state, farm, "grow_food")
	_state.stock["water"] = 0.0
	_at(12)
	assert_eq(_work_score(farm), 0.0)


func test_a_medic_prefers_the_infirmary() -> void:
	var farm: int = _room("farm")
	BaseRules.queue_job(_state, farm, "grow_food")
	var inf: int = _room("infirmary")
	BaseRules.queue_job(_state, inf, "herb_medicine")
	_state.stock["food"] = 0.0
	_state.stock["medicine"] = 0.0
	_s.community_skill = "medicine"
	_at(12)
	assert_gt(_work_score(inf), _work_score(farm))


func test_the_watchtower_takes_as_many_guards_as_posts() -> void:
	var other: Survivor = _state.add_survivor("Mali", 8)
	var tower: int = _room("watchtower")
	_at(12)
	LifeRules.decide(_state)
	var guards: int = 0
	for s: Survivor in [_s, other]:
		if s.needs.doing_slot == tower:
			guards += 1
	assert_eq(guards, 1, "sandbags: one post")


func test_a_night_owl_sleeps_late() -> void:
	TraitRules.give(_s, "night_owl")
	assert_false(LifeRules.is_night(_s, 23))
	assert_true(LifeRules.is_night(_s, 3))
	assert_true(LifeRules.is_night(_s, 9))
	assert_false(LifeRules.is_night(_s, 12))


func test_on_a_mission_daily_life_leaves_them_alone() -> void:
	BaseRules.build(_state, _empty("small"), "kitchen")
	_s.needs.activity = "mission"
	_at(12)
	LifeRules.decide(_state)
	assert_eq(_s.needs.doing, "")
	assert_eq(NeedRules.activity(_s, 12), "mission")


func test_low_morale_gathers_round_the_fire_in_the_evening() -> void:
	_room("kitchen")
	_s.morale = 30.0
	_at(19)
	assert_eq(_best(_s)["act"], "socialise")
	_state.advance_hour()
	assert_almost_eq(_s.morale, 31.0, 0.001, "0.5 × 2 at the fire")


func test_a_reader_reads_in_the_evening_and_grows_wits() -> void:
	_s.reading = "skill:medicine"
	_s.read_days = 3
	TraitRules.give(_s, "loner")
	_at(19)
	assert_eq(_best(_s)["act"], "read")
	var xp: float = _s.skills["wits"].xp
	_state.advance_hour()
	assert_gt(_s.skills["wits"].xp, xp)


func test_the_same_save_lives_the_same_day() -> void:
	_state.add_survivor("Mali", 8)
	_state.add_survivor("Ana", 9)
	BaseRules.build(_state, _empty("large"), "farm")
	var twin: SimState = SimState.from_dict(_state.to_dict())
	_state.advance_day(_rules)
	twin.advance_day(_rules)
	assert_eq(twin.to_dict(), _state.to_dict())


func test_a_schema_7_save_decides_afresh() -> void:
	_at(12)
	_state.advance_hour()
	var envelope: Dictionary = JSON.parse_string(SaveCodec.encode(_state))
	envelope["schema"] = 7
	for sd: Dictionary in envelope["state"]["survivors"]:
		for key: String in ["doing", "doing_slot", "worked_today"]:
			(sd["needs"] as Dictionary).erase(key)
	var old: SaveCodec.Result = SaveCodec.decode(JSON.stringify(envelope))
	assert_eq(old.error, "")
	assert_eq(old.state.survivors[0].needs.doing, "")
	assert_eq(old.state.survivors[0].needs.doing_slot, -1)
