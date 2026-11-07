class_name Survivor
extends RefCounted
## One named community member (GDD §3). 1.6 adds the build (CITIZENS_1_6 §1): background, core skills, traits;
## and the body's needs.

const MAX_STAT: float = 100.0

var id: int = 0
var name: String = ""
var appearance_seed: int = 0  ## the look is rebuilt from this, so it never changes between loads
var health: float = MAX_STAT
var morale: float = MAX_STAT
var background: String = ""  ## skills.json backgrounds id; "" = none (a save from before 1.6)
var skills: Dictionary[String, SurvivorSkill] = {}  ## core skill id -> state (SkillRules)
var traits: PackedStringArray = PackedStringArray()  ## traits.json ids (TraitRules)
var trait_days: Dictionary[String, int] = {}  ## timed traits (Survivor's Guilt) -> days left
var counters: Dictionary[String, int] = {}  ## toward earned traits: horde_nights, dives
var needs: SurvivorNeeds = SurvivorNeeds.new()  ## fatigue, hunger, thirst, injuries, sickness, infection (NeedRules)


func _init(p_id: int = 0, p_name: String = "", p_seed: int = 0) -> void:
	id = p_id
	name = p_name
	appearance_seed = p_seed


func is_alive() -> bool:
	return health > 0.0


func damage(amount: float) -> void:
	health = clampf(health - amount, 0.0, MAX_STAT)


func change_morale(amount: float) -> void:
	morale = clampf(morale + amount, 0.0, MAX_STAT)


func to_dict() -> Dictionary:
	var skill_d: Dictionary = {}
	for k: String in skills:
		skill_d[k] = skills[k].to_array()
	return {"id": id, "name": name, "appearance_seed": appearance_seed, "health": health, "morale": morale,
		"background": background, "skills": skill_d, "traits": Array(traits), "trait_days": trait_days.duplicate(),
		"counters": counters.duplicate(), "needs": needs.to_dict()}


static func from_dict(d: Dictionary) -> Survivor:
	var s: Survivor = Survivor.new(int(d["id"]), str(d["name"]), int(d["appearance_seed"]))
	s.health = float(d["health"])
	s.morale = float(d["morale"])
	s.background = str(d["background"])
	var skill_d: Dictionary = d["skills"]
	for k: Variant in skill_d:
		s.skills[str(k)] = SurvivorSkill.from_array(skill_d[k] as Array)
	s.traits = PackedStringArray(d["traits"])
	var days: Dictionary = d["trait_days"]
	for k: Variant in days:
		s.trait_days[str(k)] = int(days[k])
	var counts: Dictionary = d["counters"]
	for k: Variant in counts:
		s.counters[str(k)] = int(counts[k])
	s.needs = SurvivorNeeds.from_dict(d["needs"])
	return s
