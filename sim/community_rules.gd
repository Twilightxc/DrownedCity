class_name CommunityRules
extends RefCounted
## Community skills, books and combat classes (CITIZENS_1_6 §6–7), from data/sim/community.json.
## - One community skill slot per survivor: born with it (from the background, by chance) or read from a book.
##   Its numbers are what the holder brings to its room (rooms: 1.7), so they are not in the holder's own build.
##   An outstanding citizen's skill also works base-wide at half strength while they are in the base (base_wide).
## - The skill decides which leader types the survivor may take; a leader book adds one more.
## - A class is picked on becoming a member; its passive is on the survivor's build.

const PATH: String = "res://data/sim/community.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data


static func skills() -> Dictionary:
	return data()["skills"]


static func classes() -> Dictionary:
	return data()["classes"]


## At birth: the skill the background suggests, at born.chance; otherwise an empty slot.
static func roll_born(s: Survivor, rng: RandomNumberGenerator) -> void:
	var born: Dictionary = data()["born"]
	var from_bg: Dictionary = born["from_background"]
	if from_bg.has(s.background) and rng.randf() < float(born["chance"]):
		s.community_skill = str(from_bg[s.background])


## Leader types this survivor may take: their community skill's path ("any" = all) plus leader books read.
static func leader_types(s: Survivor) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if skills().has(s.community_skill):
		var path: String = str(skills()[s.community_skill]["leader"])
		if path == "any":
			for t: String in StatusRules.data()["leaders"]:
				out.append(t)
		else:
			out.append(path)
	for t: String in s.leader_paths:
		if not t in out:
			out.append(t)
	return out


# --- books ---------------------------------------------------------------------------------------------------------

## Whether `s` can learn something from `book` ("skill:<id>", "spec:<skill>:<spec>", "leader:<type>").
static func can_read(s: Survivor, book: String) -> bool:
	if not s.is_alive() or not s.reading.is_empty():
		return false
	var p: PackedStringArray = book.split(":")
	match p[0]:
		"skill":
			return p.size() == 2 and s.community_skill.is_empty() and skills().has(p[1])
		"spec":
			return p.size() == 3 and s.community_skill == p[1] and skills().has(p[1]) \
				and (skills()[p[1]]["specs"] as Dictionary).has(p[2]) and not p[2] in s.community_specs
		"leader":
			return p.size() == 2 and (StatusRules.data()["leaders"] as Dictionary).has(p[1]) \
				and not p[1] in leader_types(s)
	return false


## Takes the book from the base's shelf and starts reading it. Library (base-wide or the reader's) halves the time.
static func start_reading(state: SimState, s: Survivor, book: String) -> bool:
	if state.books.get(book, 0) <= 0 or not can_read(s, book):
		return false
	state.books[book] -= 1
	if state.books[book] == 0:
		state.books.erase(book)
	var m: StatMods = BuildRules.base_mods(s)
	m.absorb(base_wide(state))
	s.reading = book
	s.read_days = maxi(1, roundi(m.apply(&"read_time", float(data()["books"]["read_days"]))))
	return true


## Morning: a day of reading; a finished book teaches its skill, specialization or leader path.
static func tick_day(state: SimState) -> void:
	for s: Survivor in state.living():
		if s.reading.is_empty():
			continue
		s.read_days -= 1
		if s.read_days > 0:
			continue
		var p: PackedStringArray = s.reading.split(":")
		match p[0]:
			"skill":
				s.community_skill = p[1]
			"spec":
				s.community_specs.append(p[2])
			"leader":
				s.leader_paths.append(p[1])
		s.reading = ""
		s.read_days = 0


# --- the skill's numbers -------------------------------------------------------------------------------------------

## What the holder brings to their skill's room (1.7): the skill and its specializations, numbers and perks.
static func room_mods(s: Survivor) -> StatMods:
	var out: StatMods = StatMods.new()
	if not skills().has(s.community_skill):
		return out
	var def: Dictionary = skills()[s.community_skill]
	_push(def, out)
	for spec: String in s.community_specs:
		_push(def["specs"].get(spec, {}), out)
	return out


## Every outstanding citizen in the base adds their skill's numbers at half strength (no perks: unlocks stay with
## the room). Leader or not, they all stack (J).
static func base_wide(state: SimState) -> StatMods:
	var out: StatMods = StatMods.new()
	for s: Survivor in state.living():
		if StatusRules.is_outstanding(s) and s.needs.activity != "mission":
			out.absorb(room_mods(s), 0.5)
	return out


# --- combat classes ------------------------------------------------------------------------------------------------

## A member (or above) without a class is asked to pick one.
static func needs_class(s: Survivor) -> bool:
	return s.is_alive() and s.combat_class.is_empty() and StatusRules.rank(s.status) >= StatusRules.rank("member")


static func pick_class(s: Survivor, class_id: String) -> bool:
	if not needs_class(s) or not classes().has(class_id):
		return false
	s.combat_class = class_id
	return true


## Changing class later happens in a training room and costs a day (the room and the day: 1.7).
static func change_class(s: Survivor, class_id: String) -> bool:
	if s.combat_class.is_empty() or s.combat_class == class_id or not classes().has(class_id):
		return false
	s.combat_class = class_id
	return true


## The class passive and its ability on the survivor's build (perks "class_<id>", "ability_<id>").
static func add_mods(s: Survivor, out: StatMods) -> void:
	if not classes().has(s.combat_class):
		return
	var c: Dictionary = classes()[s.combat_class]
	_push(c, out)
	out.grant(StringName("class_" + s.combat_class))
	out.grant(StringName("ability_" + str(c["active"]["id"])))


static func _push(def: Dictionary, out: StatMods) -> void:
	for m: Array in def.get("mods", []):
		out.push_for(StringName(m[0]), str(m[1]), float(m[2]), PackedStringArray(m[3]) if m.size() > 3 else PackedStringArray())
	for p: String in def.get("perks", []):
		out.grant(StringName(p))
