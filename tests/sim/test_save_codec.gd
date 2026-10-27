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
	var text: String = SaveCodec.encode(_played_state()).replace('"schema": 1', '"schema": 99')
	var result: SaveCodec.Result = SaveCodec.decode(text)
	assert_null(result.state)
	assert_string_contains(result.error, "newer build")


func test_rejects_damaged_state() -> void:
	var text: String = '{"game": "drowned_city", "schema": 1, "state": {"day": 3}}'
	assert_string_contains(SaveCodec.decode(text).error, "missing 'hour'")


func test_migrations_run_in_order_up_to_current() -> void:
	# A pretend schema 2 that renamed "stock" to "stockpile"; schema 3 reads it back as "stock".
	var to_v2: Callable = func(d: Dictionary) -> Dictionary:
		d["stockpile"] = d["stock"]
		d.erase("stock")
		return d
	var to_v3: Callable = func(d: Dictionary) -> Dictionary:
		d["stock"] = d["stockpile"]
		d.erase("stockpile")
		return d
	var migrations: Dictionary[int, Callable] = {1: to_v2, 2: to_v3}
	var state: SimState = _played_state()
	var result: SaveCodec.Result = SaveCodec.decode(SaveCodec.encode(state), migrations, 3)
	assert_eq(result.error, "")
	assert_eq(result.migrated_from, 1)
	assert_eq(result.state.to_dict(), state.to_dict())


func test_missing_migration_is_an_error() -> void:
	var result: SaveCodec.Result = SaveCodec.decode(SaveCodec.encode(_played_state()), {}, 2)
	assert_null(result.state)
	assert_string_contains(result.error, "no migration from schema 1")
