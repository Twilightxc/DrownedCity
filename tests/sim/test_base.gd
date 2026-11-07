extends GutTest
## 1.7 step 1: the rooftop base in SimCore (GDD §4, data/sim/rooms.json).

var _rules: SimRules
var _state: SimState
var _s: Survivor


func before_each() -> void:
	_rules = SimRules.new()
	_state = SimState.new()
	BaseRules.init(_state)
	_s = _state.add_survivor("Rosa", 7)
	for res: String in SimState.RESOURCES:
		_state.stock[res] = 50.0


func _slot(room: String) -> int:
	for i: int in _state.rooms.size():
		if _state.rooms[i].room == room:
			return i
	return -1


func _empty(size: String) -> int:
	for i: int in _state.rooms.size():
		if _state.rooms[i].room.is_empty() and _state.rooms[i].size == size:
			return i
	return -1


## `s` works `hours` hours in their slot.
func _work(s: Survivor, hours: int) -> void:
	for h: int in hours:
		BaseRules.work_hour(_state, s)


func _built(room: String) -> int:
	var i: int = _empty(str(BaseRules.room_def(room)["size"]))
	assert_true(BaseRules.build(_state, i, room), room)
	BaseRules.assign(_state, _s, i)
	_work(_s, int(BaseRules.data()["rooms"][room]["tiers"][0]["build_hours"]))
	return i


func test_the_demo_has_the_survival_set_with_two_tiers_each() -> void:
	var rooms: Dictionary = BaseRules.data()["rooms"]
	assert_eq(rooms.keys(), ["sleeping", "farm", "infirmary", "water", "kitchen", "watchtower"])
	for id: String in rooms:
		assert_eq((rooms[id]["tiers"] as Array).size(), 2, id)
		for r: String in rooms[id].get("recipes", []):
			assert_false(BaseRules.recipe(r).is_empty(), "%s makes %s" % [id, r])
	for r: String in BaseRules.data()["recipes"]:
		for res: String in BaseRules.recipe(r)["outputs"]:
			assert_true(res in SimState.RESOURCES, "%s → %s" % [r, res])


func test_a_new_base_has_its_slots_and_starting_rooms() -> void:
	var state: SimState = SimState.new_game(_rules, 1)
	assert_eq(state.rooms.size(), 6)
	assert_eq(state.rooms[0].room, "sleeping")
	assert_eq(state.rooms[0].tier, 1)
	assert_eq(BaseRules.beds(state, "sleeping"), 4)
	assert_ne(_slot_in(state, "water"), -1)


func _slot_in(state: SimState, room: String) -> int:
	for i: int in state.rooms.size():
		if state.rooms[i].room == room:
			return i
	return -1


func test_building_takes_materials_and_work_hours() -> void:
	var i: int = _empty("large")
	assert_eq(BaseRules.build_problem(_state, i, "water"), "needs a small slot")
	assert_eq(BaseRules.build_problem(_state, _slot("sleeping"), "farm"), "slot taken")
	_state.stock["materials"] = 1.0
	assert_eq(BaseRules.build_problem(_state, i, "farm"), "not enough materials")
	_state.stock["materials"] = 50.0
	assert_true(BaseRules.build(_state, i, "farm"))
	assert_eq(_state.stock["materials"], 44.0)
	assert_eq(_state.stock["water"], 48.0)
	assert_eq(_state.rooms[i].tier, 0, "not finished")
	BaseRules.assign(_state, _s, i)
	_work(_s, 9)
	assert_eq(_state.rooms[i].tier, 0)
	assert_eq(BaseRules.work_hour(_state, _s), "built")
	assert_eq(_state.rooms[i].tier, 1)


func test_nobody_working_means_nothing_moves() -> void:
	var i: int = _empty("small")
	BaseRules.build(_state, i, "kitchen")
	BaseRules.assign(_state, _s, _slot("water"))  # pinned to a room with nothing to do
	for d: int in 2:
		_state.advance_day(_rules)
	assert_eq(_state.rooms[i].tier, 0, "no one works there")


func test_an_assigned_survivor_works_there() -> void:
	var i: int = _empty("small")
	BaseRules.build(_state, i, "kitchen")
	BaseRules.assign(_state, _s, i)
	_state.advance_day(_rules)
	assert_eq(_state.rooms[i].tier, 1, "3 build hours in a working day")


func test_a_farm_grows_food_from_water_while_worked() -> void:
	var i: int = _built("farm")
	assert_true(BaseRules.queue_job(_state, i, "grow_food", 2))
	assert_false(BaseRules.queue_job(_state, i, "grow_herbs"), "tier 1 queues one job")
	var food: float = _state.stock["food"]
	var water: float = _state.stock["water"]
	_work(_s, 4)
	assert_eq(_state.stock["food"], food + 1.0)
	assert_eq(_state.stock["water"], water - 0.5)
	_work(_s, 4)
	assert_eq(_state.stock["food"], food + 2.0)
	assert_true(_state.rooms[i].queue.is_empty(), "two done")
	assert_eq(BaseRules.work_hour(_state, _s), "idle")


func test_missing_inputs_stall_the_job() -> void:
	var i: int = _built("kitchen")
	BaseRules.queue_job(_state, i, "cook_meal")
	_state.stock["food"] = 0.0
	assert_eq(BaseRules.work_hour(_state, _s), "stalled")
	_state.stock["food"] = 1.0
	assert_eq(BaseRules.work_hour(_state, _s), "made")
	assert_eq(_state.stock["meals"], 51.0)


func test_cancelling_a_started_unit_gives_its_inputs_back() -> void:
	var i: int = _built("farm")
	BaseRules.queue_job(_state, i, "grow_herbs")
	BaseRules.work_hour(_state, _s)
	assert_eq(_state.stock["water"], 50.0 - 2.0 - 0.5)
	BaseRules.cancel_job(_state, i, 0)
	assert_eq(_state.stock["water"], 50.0 - 2.0)
	assert_true(_state.rooms[i].queue.is_empty())


func test_upgrades_need_materials_and_sometimes_a_skill() -> void:
	var i: int = _built("infirmary")
	assert_eq(BaseRules.upgrade_problem(_state, i), "needs someone with medicine")
	_s.community_skill = "medicine"
	assert_true(BaseRules.upgrade(_state, i))
	assert_eq(_state.rooms[i].tier, 1, "works at tier 1 while it is upgraded")
	_work(_s, 16)
	assert_eq(_state.rooms[i].tier, 2)
	assert_eq(BaseRules.upgrade_problem(_state, i), "top tier")


func test_an_antiviral_needs_a_pathologist() -> void:
	var i: int = _built("infirmary")
	_s.community_skill = "medicine"
	BaseRules.upgrade(_state, i)
	_work(_s, 16)
	assert_true(BaseRules.queue_job(_state, i, "antiviral", 1))
	assert_eq(BaseRules.work_hour(_state, _s), "stalled")
	_s.community_specs.append("pathology")
	for h: int in 19:  # 24 work hours at the clinic's ×1.25
		BaseRules.work_hour(_state, _s)
	assert_eq(BaseRules.work_hour(_state, _s), "made")
	assert_eq(_state.stock["antiviral"], 51.0)


func test_rain_barrels_fill_every_morning() -> void:
	_state.stock["water"] = 0.0
	_state.advance_day(_rules)
	assert_almost_eq(_state.stock["water"], 3.0 - 1.5, 0.001, "barrels in, one person drank")


func test_no_bed_sleeps_worse() -> void:
	for k: int in 4:
		_state.add_survivor("x%d" % k, k)
	var acts: Dictionary = {}
	for s: Survivor in _state.living():
		acts[s.id] = "sleep"
	var mods: Dictionary = BaseRules.hour_mods(_state, acts)
	assert_eq((mods[_s.id] as StatMods).mul.get(&"sleep_quality", 0.0), 0.0, "a tent")
	var last: Survivor = _state.living()[4]
	assert_eq((mods[last.id] as StatMods).mul.get(&"sleep_quality", 0.0), -0.5, "four tents, five people")
	last.needs.fatigue = 50.0
	NeedRules.tick_hour(last, 23, mods[last.id], RandomNumberGenerator.new())
	assert_almost_eq(last.needs.fatigue, 50.0 - 12.5 * 0.5, 0.001)


func test_the_hurt_rest_in_the_infirmary_and_heal_faster() -> void:
	_built("infirmary")
	NeedRules.injure(_s, "fracture", StatMods.new())
	assert_eq(NeedRules.activity(_s, 12), "rest")
	_state.clock = GameClock.new(1, 12)
	_state.advance_hour()
	assert_almost_eq(float(_s.needs.injuries[0]["hours"]), 240.0 - 1.5, 0.001, "sick bay +50 %")


func test_a_cooked_meal_feeds_and_cheers() -> void:
	_s.morale = 50.0
	_s.needs.activity = "idle"  # no daily life: only the morning moves morale
	_s.needs.hunger = 40.0
	_state.stock["meals"] = 1.0
	var food: float = _state.stock["food"]
	_state.advance_day(_rules)
	assert_eq(_state.stock["meals"], 0.0)
	assert_eq(_state.stock["food"], food, "no ration needed")
	assert_almost_eq(_s.morale, 53.0, 0.001)


func test_the_watchtower_trains_shooting() -> void:
	SkillRules.setup(_s, "farmer", SkillCatalog.load_default())
	_built("watchtower")
	_work(_s, 20)
	assert_eq(_s.skills["shooting"].level, 1, "5 XP an hour")


func test_demolishing_frees_the_slot_and_its_workers() -> void:
	var i: int = _built("kitchen")
	BaseRules.demolish(_state, i)
	assert_eq(_state.rooms[i].room, "")
	assert_eq(_s.assignment, -1)


func test_the_base_survives_a_save_and_a_schema_6_save_gets_the_starting_base() -> void:
	var i: int = _built("farm")
	BaseRules.queue_job(_state, i, "grow_food")
	BaseRules.work_hour(_state, _s)
	var text: String = SaveCodec.encode(_state)
	var back: SaveCodec.Result = SaveCodec.decode(text)
	assert_eq(back.error, "")
	assert_eq(back.state.to_dict(), _state.to_dict())
	var envelope: Dictionary = JSON.parse_string(text)
	envelope["schema"] = 6
	envelope["state"].erase("rooms")
	for sd: Dictionary in envelope["state"]["survivors"]:
		sd.erase("assignment")
	envelope["state"]["stock"].erase("herbs")
	envelope["state"]["stock"].erase("meals")
	var old: SaveCodec.Result = SaveCodec.decode(JSON.stringify(envelope))
	assert_eq(old.error, "")
	assert_eq(old.state.rooms.size(), 6)
	assert_eq(old.state.rooms[0].room, "sleeping")
	assert_eq(old.state.survivors[0].assignment, -1)
