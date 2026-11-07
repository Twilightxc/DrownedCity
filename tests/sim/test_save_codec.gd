extends GutTest

var _rules: SimRules


func before_each() -> void:
	_rules = SimRules.new()


func _played_state() -> SimState:
	var state: SimState = SimState.new_game(_rules, 4_000_000_000)  # > 2^31: seeds must survive JSON
	state.advance_day(_rules)
	state.stock["food"] = 0.0
	state.advance_day(_rules)
	state.survivors[1].damage(Survivor.MAX_STAT)
	state.add_survivor("Ana", 123456789)
	return state


func test_round_trip_keeps_everything() -> void:
	var state: SimState = _played_state()
	var result: SaveCodec.Result = SaveCodec.decode(SaveCodec.encode(state, "test"))
	assert_eq(result.error, "")
	assert_eq(result.migrated_from, 0)
	assert_eq(result.state.to_dict(), state.to_dict())
	assert_eq(result.state.game_seed, 4_000_000_000)
	assert_false(result.state.survivors[1].is_alive())
	assert_eq(result.state.survivors[3].name, "Ana")


func test_envelope_is_versioned() -> void:
	var parsed: Dictionary = JSON.parse_string(SaveCodec.encode(_played_state(), "v0.0.1 · abc"))
	assert_eq(parsed["game"], SaveCodec.GAME_ID)
	assert_eq(int(parsed["schema"]), SaveCodec.SCHEMA_VERSION)
	assert_eq(parsed["build"], "v0.0.1 · abc")


func test_rejects_garbage_and_other_files() -> void:
	assert_string_contains(SaveCodec.decode("{not json").error, "not a save file")
	assert_string_contains(SaveCodec.decode("[1, 2]").error, "not a save file")
	assert_string_contains(SaveCodec.decode('{"game": "other", "schema": 1, "state": {}}').error, "not a Drowned City save")


func test_rejects_save_from_newer_build() -> void:
	var text: String = SaveCodec.encode(_played_state()).replace('"schema": %d' % SaveCodec.SCHEMA_VERSION, '"schema": 99')
	var result: SaveCodec.Result = SaveCodec.decode(text)
	assert_null(result.state)
	assert_string_contains(result.error, "newer build")


func test_rejects_damaged_state() -> void:
	var text: String = '{"game": "drowned_city", "schema": 1, "state": {"day": 3}}'
	assert_string_contains(SaveCodec.decode(text).error, "missing 'hour'")


func test_migrations_run_in_order_up_to_current() -> void:
	# A pretend schema 7 that renamed "stock" to "stockpile"; schema 8 reads it back as "stock".
	var to_v7: Callable = func(d: Dictionary) -> Dictionary:
		d["stockpile"] = d["stock"]
		d.erase("stock")
		return d
	var to_v8: Callable = func(d: Dictionary) -> Dictionary:
		d["stock"] = d["stockpile"]
		d.erase("stockpile")
		return d
	var steps: Dictionary[int, Callable] = {6: to_v7, 7: to_v8}
	var state: SimState = _played_state()
	var result: SaveCodec.Result = SaveCodec.decode(SaveCodec.encode(state), steps, 8)
	assert_eq(result.error, "")
	assert_eq(result.migrated_from, 6)
	assert_eq(result.state.to_dict(), state.to_dict())


func test_a_schema_1_save_gets_skills_at_0_and_no_background() -> void:
	var state: SimState = _played_state()
	var envelope: Dictionary = JSON.parse_string(SaveCodec.encode(state))
	envelope["schema"] = 1
	for sd: Dictionary in envelope["state"]["survivors"]:
		for key: String in ["background", "skills", "traits", "trait_days", "counters", "needs"]:
			sd.erase(key)
	var result: SaveCodec.Result = SaveCodec.decode(JSON.stringify(envelope))
	assert_eq(result.error, "")
	assert_eq(result.migrated_from, 1)
	var s: Survivor = result.state.survivors[0]
	assert_eq(s.background, "")
	assert_eq(s.skills.size(), SkillCatalog.load_default().skill_ids().size())
	assert_eq(s.skills["shooting"].level, 0)


func test_missing_migration_is_an_error() -> void:
	var result: SaveCodec.Result = SaveCodec.decode(SaveCodec.encode(_played_state()), {}, 7)
	assert_null(result.state)
	assert_string_contains(result.error, "no migration from schema 6")
