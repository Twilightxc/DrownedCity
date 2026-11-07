extends GutTest
## 1.7 step 5: Observer mode. LifeStory puts what a survivor does into words (the card and its short log);
## ObserverDirector picks what the camera watches.

var _kit: BaseKit
var _farm: Dictionary


func before_each() -> void:
	_kit = BaseKit.new()
	_farm = _kit.layout["farm"]


func _describe(state: SimState, s: Survivor) -> String:
	return LifeStory.describe(state, s, LifeSpots.assign(state, _kit)[s.id], _farm)


func test_the_card_says_what_they_do_in_words() -> void:
	var state: SimState = BasePreset.make("tier1", 3, 7, 23)
	var s: Survivor = state.survivors[0]
	s.needs.doing = "sleep"
	assert_eq(_describe(state, s), "Asleep in a tent")
	s.needs.doing = "read"
	s.reading = "skill:gardening"
	s.read_days = 2
	assert_eq(_describe(state, s), "Reading 'Gardening', 2 day(s) to go")
	s.needs.doing = "exercise"
	assert_eq(_describe(state, s), "Doing squats to keep fit")
	s.needs.activity = "mission"
	assert_eq(_describe(state, s), "Away on a mission")


func test_a_farm_hand_is_described_by_the_bed_they_tend() -> void:
	var state: SimState = BasePreset.make("tier1", 1, 7, 10)
	var s: Survivor = state.survivors[0]
	s.needs.doing = "work"
	s.needs.doing_slot = 1
	var cycle: float = float(_farm["cycle_hours"])
	var plot: int = int(_kit.room_spots(1, state.rooms[1], "work")[0]["plot"])
	state.rooms[1].worked = cycle - cycle * float(plot) / 3.0 + 0.01  # that bed at stage 0
	assert_string_starts_with(_describe(state, s), "Hoeing a bed for")
	state.rooms[1].worked += cycle * 0.4  # stage 2
	assert_string_starts_with(_describe(state, s), "Watering the young")


func test_builders_and_guards_say_so() -> void:
	var state: SimState = BasePreset.make("start", 2, 7, 10)
	var s: Survivor = state.survivors[0]
	s.needs.doing = "work"
	s.needs.doing_slot = 2
	assert_eq(_describe(state, s), "Building the Sick bay (0 / 8 h)")
	s.needs.doing_slot = 5
	assert_eq(_describe(state, s), "On watch at the Sandbags")


func test_the_log_key_changes_only_when_the_activity_does() -> void:
	var state: SimState = BasePreset.make("tier1", 1, 7, 10)
	var s: Survivor = state.survivors[0]
	s.needs.doing = "work"
	s.needs.doing_slot = 1
	var a: String = LifeStory.log_key(state, s)
	state.rooms[1].worked += 3.0
	assert_eq(LifeStory.log_key(state, s), a, "still at the farm")
	s.needs.doing_slot = 4
	assert_ne(LifeStory.log_key(state, s), a)


func test_the_card_lists_traits_and_body() -> void:
	var state: SimState = BasePreset.make("tier1", 1, 7, 10)
	var s: Survivor = state.survivors[0]
	NeedRules.injure(s, "fracture", StatMods.new())
	var lines: String = "\n".join(LifeStory.card(state, s))
	assert_string_contains(lines, "Traits:")
	assert_string_contains(lines, "Fracture, 10 day(s) to heal")


func _cand(id: int, act: String, pos: Vector3, errand: bool = false, tending: bool = false) -> Dictionary:
	return {"id": id, "act": act, "pos": pos, "errand": errand, "tending": tending}


func test_the_director_prefers_company_and_errands_over_sleepers() -> void:
	var d: ObserverDirector = ObserverDirector.new(_kit.layout["observer"])
	var all: Array[Dictionary] = [_cand(1, "sleep", Vector3(-8, 0, 0)), _cand(2, "socialise", Vector3(2, 0, 4)),
		_cand(3, "socialise", Vector3(3, 0, 4)), _cand(4, "work", Vector3(-8, 0, 6), false, true)]
	var shot: Dictionary = d.pick(all)
	assert_eq(shot["id"], 2, "two by the fire")
	assert_almost_eq((shot["pos"] as Vector3).x, 2.5, 0.01, "framed between them")
	all.append(_cand(5, "idle", Vector3(6, 0, 3), true))
	assert_eq(d.errand_cut(all, 2)["id"], 5, "lighting a drum cuts in")


func test_the_director_moves_on_instead_of_staring() -> void:
	var d: ObserverDirector = ObserverDirector.new(_kit.layout["observer"])
	var all: Array[Dictionary] = [_cand(1, "work", Vector3(-8, 0, 0), false, true), _cand(2, "read", Vector3(4, 0, -3)),
		_cand(3, "exercise", Vector3(6, 0, 0))]
	var seen: Dictionary = {}
	for k: int in 6:
		seen[d.pick(all)["id"]] = true
	assert_eq(seen.size(), 3, "every one gets a turn")


func test_nobody_up_means_no_shot() -> void:
	var d: ObserverDirector = ObserverDirector.new(_kit.layout["observer"])
	assert_eq(d.pick([_cand(1, "mission", Vector3.ZERO)] as Array[Dictionary]), {})
