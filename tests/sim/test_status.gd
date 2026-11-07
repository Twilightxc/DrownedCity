extends GutTest
## 1.6 influence, rank points, status ladder and leaders (GDD §3, §11, §12; docs/CITIZENS_1_6.md §2).

var _rules: SimRules
var _state: SimState
var _s: Survivor


func before_each() -> void:
	_rules = SimRules.new()
	_state = SimState.new()
	_s = _state.add_survivor("Rosa", 7)
	for res: String in SimState.RESOURCES:
		_state.stock[res] = 100.0


func _make_outstanding(s: Survivor) -> void:
	s.rank_points = 0.0
	s.community_skill = "teaching"  # a teacher may lead as any type
	StatusRules.earn(_state, s, "mission_done", 30.0)


func test_the_ladder_runs_stranger_member_outstanding() -> void:
	assert_eq(StatusRules.ladder_ids(), PackedStringArray(["stranger", "member", "outstanding"]))
	assert_eq(_s.status, "stranger", "a newcomer")
	assert_true(BuildRules.mods(_s).has_perk(&"stranger"))


func test_the_founders_start_as_members() -> void:
	var state: SimState = SimState.new_game(_rules, 3)
	for s: Survivor in state.survivors:
		assert_eq(s.status, "member", s.name)
		assert_false(BuildRules.mods(s).has_perk(&"stranger"))


func test_influence_goes_to_the_pool_and_to_the_earner() -> void:
	var other: Survivor = _state.add_survivor("Ana", 8)
	assert_eq(StatusRules.earn(_state, _s, "mission_done"), 20.0)
	StatusRules.earn(_state, other, "zombie_kill", 10.0)
	assert_eq(_state.influence, 25.0)
	assert_eq(_s.rank_points, 20.0)
	assert_eq(other.rank_points, 5.0)


func test_spending_the_pool_never_lowers_a_rank() -> void:
	StatusRules.earn(_state, _s, "mission_done", 3.0)
	assert_eq(_s.status, "member")
	assert_true(StatusRules.spend(_state, 60.0))
	assert_false(StatusRules.spend(_state, 1.0), "the pool is empty")
	assert_eq(_s.rank_points, 60.0)
	assert_eq(_s.status, "member")


func test_well_liked_earns_more() -> void:
	TraitRules.give(_s, "well_liked")
	assert_almost_eq(StatusRules.earn(_state, _s, "mission_done"), 22.0, 0.001)


func test_days_in_base_and_good_spirits_climb_the_ladder() -> void:
	_s.morale = 100.0
	for d: int in 7:
		_state.advance_day(_rules)
	assert_eq(_s.status, "member", "a week in good spirits: 7 × 8 = 56")
	var gloomy: Survivor = _state.add_survivor("Bo", 9)
	gloomy.morale = 30.0
	_state.advance_day(_rules)
	assert_eq(gloomy.rank_points, 5.0, "no morale bonus")


func test_status_is_never_lost() -> void:
	_make_outstanding(_s)
	assert_eq(_s.status, "outstanding")
	_s.rank_points = 0.0
	assert_false(StatusRules.promote(_s))
	assert_eq(_s.status, "outstanding")
	assert_true(BuildRules.mods(_s).has_perk(&"outstanding_citizen"))


func test_only_an_outstanding_citizen_can_lead() -> void:
	StatusRules.earn(_state, _s, "mission_done", 3.0)
	assert_false(StatusRules.appoint(_state, _s, "builder"), "a member")
	_make_outstanding(_s)
	assert_false(StatusRules.appoint(_state, _s, "king"))
	assert_true(StatusRules.appoint(_state, _s, "builder"))
	assert_eq(StatusRules.leader(_state), _s)
	assert_eq(_state.leader_type, "builder")


func test_one_leader_at_a_time_and_stepping_down_keeps_the_buff() -> void:
	var other: Survivor = _state.add_survivor("Ana", 8)
	_make_outstanding(_s)
	_make_outstanding(other)
	StatusRules.appoint(_state, _s, "trader")
	assert_true(StatusRules.appoint(_state, other, "sheriff"))
	assert_eq(StatusRules.leader(_state), other, "the new one replaces the old")
	assert_eq(_s.status, "outstanding")
	StatusRules.step_down(_state)
	assert_null(StatusRules.leader(_state))
	assert_eq(other.status, "outstanding")
	assert_true(BuildRules.mods(other).has_perk(&"outstanding_citizen"))


func test_a_dead_leader_leads_nobody() -> void:
	_make_outstanding(_s)
	StatusRules.appoint(_state, _s, "warlord")
	_s.damage(Survivor.MAX_STAT)
	assert_null(StatusRules.leader(_state))
	assert_eq(StatusRules.earn(_state, _s, "mission_done"), 0.0)


func test_status_survives_a_save_and_a_schema_4_save_loads_as_founders() -> void:
	_make_outstanding(_s)
	StatusRules.appoint(_state, _s, "researcher")
	var text: String = SaveCodec.encode(_state)
	var back: SaveCodec.Result = SaveCodec.decode(text)
	assert_eq(back.error, "")
	assert_eq(back.state.to_dict(), _state.to_dict())
	var envelope: Dictionary = JSON.parse_string(text)
	envelope["schema"] = 4
	for key: String in ["influence", "leader_id", "leader_type"]:
		envelope["state"].erase(key)
	for sd: Dictionary in envelope["state"]["survivors"]:
		sd.erase("status")
		sd.erase("rank_points")
	var old: SaveCodec.Result = SaveCodec.decode(JSON.stringify(envelope))
	assert_eq(old.error, "")
	assert_eq(old.migrated_from, 4)
	assert_eq(old.state.survivors[0].status, "member")
	assert_null(StatusRules.leader(old.state))
