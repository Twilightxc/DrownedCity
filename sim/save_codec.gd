class_name SaveCodec
extends RefCounted
## Save = serialized SimState in a versioned JSON envelope (CLAUDE.md).
## Bump SCHEMA_VERSION whenever the state's shape changes, and add a migration from the old
## version that rewrites the old "state" dictionary into the new shape.

const GAME_ID: String = "drowned_city"
const SCHEMA_VERSION: int = 8

## from_version -> Callable(state: Dictionary) -> Dictionary, producing from_version + 1.
static func migrations() -> Dictionary[int, Callable]:
	return {1: _v1_to_v2, 2: _v2_to_v3, 3: _v3_to_v4, 4: _v4_to_v5, 5: _v5_to_v6, 6: _v6_to_v7, 7: _v7_to_v8}


## Schema 2 (1.6): survivors gain a background and the core skills. An old survivor has no background and every
## skill at 0 (the community played before 1.6 existed).
static func _v1_to_v2(d: Dictionary) -> Dictionary:
	var skill_ids: PackedStringArray = SkillCatalog.load_default().skill_ids()
	for sd: Variant in d.get("survivors", []):
		var s: Dictionary = sd
		s["background"] = ""
		var skills: Dictionary = {}
		for id: String in skill_ids:
			skills[id] = SurvivorSkill.new().to_array()
		s["skills"] = skills
	return d


## Schema 3 (1.6): traits, timed traits and the counters toward earned ones. An old survivor has none.
static func _v2_to_v3(d: Dictionary) -> Dictionary:
	for sd: Variant in d.get("survivors", []):
		var s: Dictionary = sd
		s["traits"] = []
		s["trait_days"] = {}
		s["counters"] = {}
	return d


## Schema 4 (1.6): body needs, and medicine + antiviral in the stockpile. An old survivor is rested, fed and well.
static func _v3_to_v4(d: Dictionary) -> Dictionary:
	for sd: Variant in d.get("survivors", []):
		(sd as Dictionary)["needs"] = SurvivorNeeds.new().to_dict()
	var stock: Dictionary = d.get("stock", {})
	for res: String in ["medicine", "antiviral"]:
		stock[res] = stock.get(res, 0.0)
	return d


## Schema 5 (1.6): influence pool, leader, and each survivor's status + rank points. An old community were the
## founders: members with no points, no leader.
static func _v4_to_v5(d: Dictionary) -> Dictionary:
	for sd: Variant in d.get("survivors", []):
		(sd as Dictionary)["status"] = "member"
		(sd as Dictionary)["rank_points"] = 0.0
	d["influence"] = 0.0
	d["leader_id"] = 0
	d["leader_type"] = ""
	return d


## Schema 6 (1.6): community skill, books and combat class. An old survivor has an empty slot, no class yet (a
## member is asked to pick one), and the shelf is empty.
static func _v5_to_v6(d: Dictionary) -> Dictionary:
	for sd: Variant in d.get("survivors", []):
		var s: Dictionary = sd
		s["community_skill"] = ""
		s["community_specs"] = []
		s["leader_paths"] = []
		s["reading"] = ""
		s["read_days"] = 0
		s["combat_class"] = ""
	d["books"] = {}
	return d


## Schema 7 (1.7): the base's rooms and who works where. An old community gets the starting base (rooms.json) and
## nobody assigned; herbs and meals start at 0.
static func _v6_to_v7(d: Dictionary) -> Dictionary:
	var fresh: SimState = SimState.new()
	BaseRules.init(fresh)
	d["rooms"] = fresh.rooms.map(func(r: RoomState) -> Dictionary: return r.to_dict())
	for sd: Variant in d.get("survivors", []):
		(sd as Dictionary)["assignment"] = -1
	var stock: Dictionary = d.get("stock", {})
	for res: String in ["herbs", "meals"]:
		stock[res] = stock.get(res, 0.0)
	return d


## Schema 8 (1.7 daily life): what each survivor is doing; an old save decides afresh on its next hour.
static func _v7_to_v8(d: Dictionary) -> Dictionary:
	for sd: Variant in d.get("survivors", []):
		var n: Dictionary = (sd as Dictionary).get("needs", {})
		n["doing"] = ""
		n["doing_slot"] = -1
		n["worked_today"] = 0.0
	return d


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


## `steps` replaces migrations() (tests); null = the real ones.
static func decode(text: String, steps: Variant = null, current_version: int = SCHEMA_VERSION) -> Result:
	var migrations_by_version: Dictionary = migrations() if steps == null else steps
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
		if not migrations_by_version.has(version):
			result.error = "no migration from schema %d" % version
			return result
		state_d = (migrations_by_version[version] as Callable).call(state_d)
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
