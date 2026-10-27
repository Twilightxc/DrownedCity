extends GutTest

const TEST_DIR: String = "user://test_saves"

var _store: SaveStore
var _rules: SimRules = SimRules.new()


func before_each() -> void:
	_store = SaveStore.new(TEST_DIR, "slot_test")
	_store.clear()


func after_each() -> void:
	_store.clear()


func _state_on_day(day: int) -> SimState:
	var state: SimState = SimState.new_game(_rules, 5)
	for i: int in day - 1:
		state.advance_day(_rules)
	return state


func test_no_save_yet() -> void:
	assert_false(_store.exists())
	assert_eq(_store.load_state().error, "no save")


func test_write_then_load() -> void:
	assert_eq(_store.write(SaveCodec.encode(_state_on_day(3))), "")
	var result: SaveCodec.Result = _store.load_state()
	assert_eq(result.error, "")
	assert_eq(result.state.clock.day, 3)


func test_second_write_keeps_previous_as_backup() -> void:
	_store.write(SaveCodec.encode(_state_on_day(2)))
	_store.write(SaveCodec.encode(_state_on_day(4)))
	assert_true(FileAccess.file_exists(_store.backup_path()))
	assert_false(FileAccess.file_exists(_store.main_path() + ".tmp"))
	var backup: SaveCodec.Result = SaveCodec.decode(FileAccess.get_file_as_string(_store.backup_path()))
	assert_eq(backup.state.clock.day, 2)


func test_damaged_main_falls_back_to_backup() -> void:
	_store.write(SaveCodec.encode(_state_on_day(2)))
	_store.write(SaveCodec.encode(_state_on_day(4)))
	var f: FileAccess = FileAccess.open(_store.main_path(), FileAccess.WRITE)
	f.store_string('{"game": "drowned_ci')  # cut off mid-write
	f.close()
	var result: SaveCodec.Result = _store.load_state()
	assert_eq(result.state.clock.day, 2)
	assert_string_contains(result.error, "loaded the backup")
