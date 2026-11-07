class_name BuildRules
extends RefCounted
## A survivor's whole build (CITIZENS_1_6 §1) as one set of modifiers: core skills, background, traits, status and
## the body's needs so far; community skill, class and status join as 1.6 goes on. Systems read stats through this.


static func mods(s: Survivor) -> StatMods:
	var out: StatMods = base_mods(s)
	NeedRules.add_mods(s, out)
	return out


## Skills, background and traits only: what scales the needs themselves (NeedRules).
static func base_mods(s: Survivor) -> StatMods:
	var out: StatMods = SkillRules.mods(s, SkillCatalog.load_default())
	TraitRules.add_mods(s, out)
	StatusRules.add_mods(s, out)
	return out
