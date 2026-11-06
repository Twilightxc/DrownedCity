class_name SkillRules
extends RefCounted
## Core skills and backgrounds (CITIZENS_1_6 §3–4): XP from doing, levels, the specialization at 7, and the
## modifiers a survivor gets from all of it.
##
## Second climb (J 2026-11-06): the specialization's numbers grow step by step and are full at 7. A stat the skill's
## track already raised keeps its level-7 value and grows from there to the specialization's value, so nobody gets
## weaker by specializing. Perks come with the choice.


## Gives a new survivor `background` and every core skill, at the background's starting levels.
static func setup(s: Survivor, background: String, cat: SkillCatalog) -> void:
	s.background = background
	var start: Dictionary = cat.backgrounds[background].get("start", {}) if cat.backgrounds.has(background) else {}
	s.skills.clear()
	for id: String in cat.skill_ids():
		s.skills[id] = SurvivorSkill.new(int(start.get(id, 0)))


static func roll_background(rng: RandomNumberGenerator, cat: SkillCatalog) -> String:
	var ids: PackedStringArray = cat.background_ids()
	return ids[rng.randi() % ids.size()]


## Adds XP to one skill and returns the levels gained. XP stops at level 7 until a specialization is picked, and
## at the end of the second climb.
static func add_xp(s: Survivor, skill: String, amount: float, cat: SkillCatalog) -> int:
	var k: SurvivorSkill = s.skills.get(skill)
	if k == null or amount <= 0.0 or k.waiting_for_spec() or k.maxed():
		return 0
	k.xp += amount
	var gained: int = 0
	while k.level < SkillCatalog.MAX_LEVEL and k.xp >= cat.xp_needed(k.level, k.climb):
		k.xp -= cat.xp_needed(k.level, k.climb)
		k.level += 1
		gained += 1
	if k.level >= SkillCatalog.MAX_LEVEL:
		k.xp = 0.0
	return gained


## Something the survivor did `count` times (or for `count` seconds / hours): every skill that grows from it
## gets its rate × count (skills.json "grows_from").
static func on_action(s: Survivor, action: String, count: float, cat: SkillCatalog) -> void:
	for id: String in cat.skill_ids():
		var rates: Dictionary = cat.skills[id].get("grows_from", {})
		if rates.has(action):
			add_xp(s, id, float(rates[action]) * count, cat)


## Picks the specialization of a skill at level 7 of the first climb; it starts the second climb at 0.
static func choose_spec(s: Survivor, skill: String, spec: String, cat: SkillCatalog) -> bool:
	var k: SurvivorSkill = s.skills.get(skill)
	if k == null or not k.waiting_for_spec() or not (cat.skills[skill]["specs"] as Dictionary).has(spec):
		return false
	k.climb = 2
	k.level = 0
	k.xp = 0.0
	k.spec = spec
	return true


## Every modifier and perk the survivor has from skills and background.
static func mods(s: Survivor, cat: SkillCatalog) -> StatMods:
	var out: StatMods = StatMods.new()
	for id: String in s.skills:
		if cat.skills.has(id):
			_skill_mods(s.skills[id], cat.skills[id], out)
	if cat.backgrounds.has(s.background):
		var bg: Dictionary = cat.backgrounds[s.background]
		for m: Array in bg.get("mods", []):
			out.push(StringName(m[0]), str(m[1]), float(m[2]))
		for p: String in bg.get("perks", []):
			out.grant(StringName(p))
	return out


static func _skill_mods(k: SurvivorSkill, def: Dictionary, out: StatMods) -> void:
	var tracks: Array = def.get("tracks", [])
	if k.climb == 1:
		for t: Dictionary in tracks:
			out.push(StringName(t["stat"]), str(t["op"]), float((t["values"] as Array)[k.level]))
		return
	var spec: Dictionary = (def["specs"] as Dictionary).get(k.spec, {})
	var grow: float = float(k.level) / SkillCatalog.MAX_LEVEL
	var spec_vals: Dictionary = {}  # "stat|op" -> value
	for m: Array in spec.get("mods", []):
		spec_vals["%s|%s" % [m[0], m[1]]] = float(m[2])
	for t: Dictionary in tracks:
		var key: String = "%s|%s" % [t["stat"], t["op"]]
		var full: float = float((t["values"] as Array)[SkillCatalog.MAX_LEVEL])
		var v: float = full
		if spec_vals.has(key):
			v = full + (float(spec_vals[key]) - full) * grow
			spec_vals.erase(key)
		out.push(StringName(t["stat"]), str(t["op"]), v)
	for key: String in spec_vals:
		var parts: PackedStringArray = key.split("|")
		out.push(StringName(parts[0]), parts[1], float(spec_vals[key]) * grow)
	for p: String in spec.get("perks", []):
		out.grant(StringName(p))
