class_name NightRules
extends RefCounted
## What a night fight leaves on a survivor (the arena now; the base's horde nights in 1.10): skill XP from shots
## and kills, influence from kills and a night survived, the horde-night count toward Hardened, and bites that may
## infect (GDD §3, §11; CITIZENS_1_6 §8).


## `fight`: {"shots": int, "kills": int, "bites": int, "won": bool}. Returns what changed:
## {"influence": float, "levels": {skill: new level}, "infected": bool, "traits": [gained]}.
static func apply(state: SimState, s: Survivor, fight: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {"influence": 0.0, "levels": {}, "infected": false, "traits": []}
	if not s.is_alive():
		return out
	var cat: SkillCatalog = SkillCatalog.load_default()
	var before: Dictionary[String, int] = {}
	for id: String in s.skills:
		before[id] = s.skills[id].level
	var traits_before: PackedStringArray = s.traits.duplicate()
	var shots: int = int(fight.get("shots", 0))
	var kills: int = int(fight.get("kills", 0))
	SkillRules.on_action(s, "shot", float(shots), cat)
	SkillRules.on_action(s, "gun_kill", float(kills), cat)
	out["influence"] = StatusRules.earn(state, s, "zombie_kill", float(kills))
	if bool(fight.get("won", false)):
		out["influence"] = float(out["influence"]) + StatusRules.earn(state, s, "horde_night")
		TraitRules.count(s, "horde_nights")
	out["infected"] = NeedRules.on_bitten(s, int(fight.get("bites", 0)), BuildRules.base_mods(s), rng)
	for id: String in s.skills:
		if s.skills[id].level != before.get(id, s.skills[id].level):
			out["levels"][id] = s.skills[id].level
	for t: String in s.traits:
		if not t in traits_before:
			out["traits"].append(t)
	return out
