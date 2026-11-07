class_name SurvivorSkill
extends RefCounted
## One core skill of one survivor (CITIZENS_1_6 §3): levels 0–7, a specialization at 7, then 0–7 again.

var climb: int = 1  ## 1 = first climb, 2 = after picking a specialization
var level: int = 0
var xp: float = 0.0  ## toward the next level
var spec: String = ""  ## chosen at level 7 of the first climb


func _init(p_level: int = 0) -> void:
	level = p_level


## Level 7 of the first climb: no more XP until a specialization is picked.
func waiting_for_spec() -> bool:
	return climb == 1 and level >= SkillCatalog.MAX_LEVEL


## Level 7 of the second climb: the skill is complete.
func maxed() -> bool:
	return climb == 2 and level >= SkillCatalog.MAX_LEVEL


func to_array() -> Array:
	return [climb, level, xp, spec]


static func from_array(a: Array) -> SurvivorSkill:
	var s: SurvivorSkill = SurvivorSkill.new(int(a[1]))
	s.climb = int(a[0])
	s.xp = float(a[2])
	s.spec = str(a[3])
	return s
