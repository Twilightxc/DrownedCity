class_name SaveCodec
extends RefCounted
## Save = serialized SimState in a versioned JSON envelope (CLAUDE.md).
## Bump SCHEMA_VERSION whenever the state's shape changes, and add a migration from the old
## version that rewrites the old "state" dictionary into the new shape.

const GAME_ID: String = "drowned_city"
const SCHEMA_VERSION: int = 1

## from_version -> Callable(state: Dictionary) -> Dictionary, producing from_version + 1.
const MIGRATIONS: Dictionary[int, Callable] = {}


class Result:
	var state: SimState = null
	var error: String = ""  ## empty on success
	var migrated_from: int = 0  ## 0 when the file was already current


## `build` is the on-screen build label, so a bad save maps to a commit.
static func encode(state: SimState, build: String = "dev") -> String:
	var envelope: Dictionary = {
		"game": GAME_ID,
		"schema": SCHEMA_VERSION,
		"build": build,
		"saved_unix": int(Time.get_unix_time_from_system()),
		"state": state.to_dict(),
	}
	return JSON.stringify(envelope, "\t")


static func decode(text: String, migrations: Dictionary[int, Callable] = MIGRATIONS,
		current_version: int = SCHEMA_VERSION) -> Result:
	var result: Result = Result.new()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		result.error = "not a save file (JSON error line %d: %s)" % [json.get_error_line(), json.get_error_message()]
		return result
	if typeof(json.data) != TYPE_DICTIONARY:
		result.error = "not a save file"
		return result
	var envelope: Dictionary = json.data
	if envelope.get("game", "") != GAME_ID:
		result.error = "not a Drowned City save"
		return result
	var version: int = int(envelope.get("schema", 0))
	if version > current_version:
		result.error = "save is from a newer build (schema %d, this build reads up to %d)" % [version, current_version]
		return result
	var data: Variant = envelope.get("state")
	if typeof(data) != TYPE_DICTIONARY:
		result.error = "save has no state"
		return result
	var state_d: Dictionary = data
	if version < current_version:
		result.migrated_from = version
	while version < current_version:
		if not migrations.has(version):
			result.error = "no migration from schema %d" % version
			return result
		state_d = migrations[version].call(state_d)
		version += 1
	var missing: String = _missing_key(state_d)
	if not missing.is_empty():
		result.error = "save is damaged (missing '%s')" % missing
		return result
	result.state = SimState.from_dict(state_d)
	return result


static func _missing_key(d: Dictionary) -> String:
	for key: String in ["day", "hour", "seed", "next_survivor_id", "survivors", "stock"]:
		if not d.has(key):
			return key
	return ""
