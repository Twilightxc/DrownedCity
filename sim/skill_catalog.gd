class_name SkillCatalog
extends RefCounted
## The core skills, their specializations and the backgrounds (CITIZENS_1_6 §3–4), read from
## data/sim/skills.json. Pure data: SkillRules does the maths.

const PATH: String = "res://data/sim/skills.json"
const MAX_LEVEL: int = 7

static var _default: SkillCatalog

var xp_to_next: PackedFloat32Array = PackedFloat32Array()  ## XP from level i to i + 1 in the first climb
var second_climb_xp_mul: float = 1.0
var skills: Dictionary = {}  ## id -> {name, tracks, grows_from, specs}
var backgrounds: Dictionary = {}  ## id -> {name, start, mods, perks}
var live_stats: PackedStringArray = PackedStringArray()  ## stats a system reads today (the rest wait)


static func load_default() -> SkillCatalog:
	if _default == null:
		_default = from_json(FileAccess.get_file_as_string(PATH))
	return _default


static func from_json(text: String) -> SkillCatalog:
	var d: Dictionary = JSON.parse_string(text)
	var c: SkillCatalog = SkillCatalog.new()
	for v: Variant in d["xp_to_next"]:
		c.xp_to_next.append(float(v))
	c.second_climb_xp_mul = float(d.get("second_climb_xp_mul", 1.0))
	c.skills = d["skills"]
	for id: String in d["backgrounds"]:
		if not id.begins_with("_"):
			c.backgrounds[id] = d["backgrounds"][id]
	c.live_stats = PackedStringArray(d.get("live_stats", []))
	return c


func skill_ids() -> PackedStringArray:
	return PackedStringArray(skills.keys())


func spec_ids(skill: String) -> PackedStringArray:
	return PackedStringArray((skills[skill]["specs"] as Dictionary).keys())


func background_ids() -> PackedStringArray:
	return PackedStringArray(backgrounds.keys())


## XP to go from `level` to the next one in `climb` (1 or 2).
func xp_needed(level: int, climb: int) -> float:
	return xp_to_next[level] * (second_climb_xp_mul if climb == 2 else 1.0)
