class_name LifeStory
extends RefCounted
## What a survivor is doing, in words (1.7 step 5, GDD §4 Observer: "reading the engine manual 3/5"). Pure: reads
## SimCore and the spot LifeSpots gave them, so the survivor card and its short log can be tested.

const CROP_NAMES: Dictionary[String, String] = {"tomato": "tomatoes", "cabbage": "cabbages", "corn": "corn",
	"beans": "beans", "herbs": "herbs"}


## One line: "Watering the corn", "Asleep in a cot", "Building the Sick bay (3 / 8 h)", "By the fire with Mara".
static func describe(state: SimState, s: Survivor, spot: Dictionary, farm: Dictionary) -> String:
	var act: String = NeedRules.activity(s, state.clock.hour)
	match act:
		"sleep":
			return _sleep_line(state, s, spot)
		"rest":
			return tr_s("Resting: %s") % _ailment(s)
		"work":
			return _work_line(state, s, spot, farm)
		"read":
			if not s.reading.is_empty():
				return tr_s("Reading %s, %d day(s) to go") % [_book_name(s.reading), s.read_days]
			return tr_s("Leafing through a book from the shelf")
		"exercise":
			return tr_s("Doing squats to keep fit")
		"socialise":
			var others: PackedStringArray = _company(state, s, spot)
			var place: String = tr_s("Warming their hands at a fire drum") if spot.get("clip") == &"warm_hands" \
					else tr_s("Sitting by the fire") if spot.get("clip") == &"sit" else tr_s("Chatting")
			return place + (tr_s(" with %s") % ", ".join(others) if not others.is_empty() else "")
		"mission":
			return tr_s("Away on a mission")
	return tr_s("Wandering the roof")


## The activity alone, for the short log: "work: Farm", "sleep".
static func log_key(state: SimState, s: Survivor) -> String:
	var act: String = NeedRules.activity(s, state.clock.hour)
	if act == "work" and s.needs.doing_slot >= 0:
		return "%s:%d" % [act, s.needs.doing_slot]
	return act


## The card's lines: who they are, body and mind, skills.
static func card(state: SimState, s: Survivor) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var who: PackedStringArray = PackedStringArray()
	if not s.background.is_empty():
		who.append(s.background.replace("_", " ").capitalize())
	who.append(s.status.capitalize())
	if not s.community_skill.is_empty():
		who.append(CommunityRules.skills().get(s.community_skill, {}).get("name", s.community_skill))
	if not s.combat_class.is_empty():
		who.append(s.combat_class.capitalize())
	out.append(" · ".join(who))
	var traits: PackedStringArray = PackedStringArray()
	for t: String in s.traits:
		traits.append(str(TraitRules.defs().get(t, {}).get("name", t)))
	if not traits.is_empty():
		out.append(tr_s("Traits: %s") % ", ".join(traits))
	out.append(tr_s("Health %d · Morale %d · Tired %d · Hungry %d · Thirsty %d") % [roundi(s.health), roundi(s.morale),
		roundi(s.needs.fatigue), roundi(s.needs.hunger), roundi(s.needs.thirst)])
	var body: String = _ailment(s)
	if body != tr_s("feeling fine"):
		out.append(body[0].to_upper() + body.substr(1))
	var skills: PackedStringArray = PackedStringArray()
	for id: String in s.skills:
		skills.append("%s %d" % [id.capitalize(), s.skills[id].level])
	if not skills.is_empty():
		out.append(tr_s("Skills: %s") % ", ".join(skills))
	return out


## tr() for static code (a RefCounted has no tr of its own in a static function).
static func tr_s(text: String) -> String:
	return TranslationServer.translate(text)


static func _sleep_line(state: SimState, s: Survivor, spot: Dictionary) -> String:
	var p: Vector3 = spot.get("pos", Vector3.ZERO)
	if p.y > 0.3:
		for r: RoomState in state.rooms:
			if r.room == "infirmary" and NeedRules.heavily_injured(s):
				return tr_s("Asleep in the infirmary")
		return tr_s("Asleep in a cot")
	if p.y > 0.01:
		return tr_s("Asleep in a tent")
	return tr_s("Asleep on the bare roof: no bed left")


static func _work_line(state: SimState, s: Survivor, spot: Dictionary, farm: Dictionary) -> String:
	var i: int = s.needs.doing_slot
	if i < 0 or i >= state.rooms.size():
		return tr_s("Looking for work")
	var r: RoomState = state.rooms[i]
	var def: Dictionary = BaseRules.room_def(r.room)
	if r.building > 0:
		var t: Dictionary = (def["tiers"] as Array)[r.building - 1]
		var total: float = float(t["build_hours"])
		return tr_s("Building the %s (%d / %d h)") % [t["name"], roundi(total - r.build_left), roundi(total)]
	if BaseRules.tier_def(r).get("guards", 0) > 0:
		return tr_s("On watch at the %s") % BaseRules.tier_def(r)["name"]
	if r.room == "farm" and spot.has("plot"):
		var plots: int = 3
		var crop: String = CROP_NAMES.get(FarmLook.crop(i, r, spot["plot"], plots, farm), "crops")
		match FarmLook.stage(r, spot["plot"], plots, float(farm["cycle_hours"])):
			0:
				return tr_s("Hoeing a bed for %s, digging in compost") % crop
			1:
				return tr_s("Sowing %s and feeding the soil") % crop
			2:
				return tr_s("Watering the young %s") % crop
			3:
				return tr_s("Weeding the %s") % crop
			4:
				return tr_s("Harvesting %s") % crop
	if r.queue.is_empty():
		return tr_s("Tidying the %s") % def.get("name", r.room)
	var rec: Dictionary = BaseRules.recipe(r.queue[0]["recipe"])
	return tr_s("%s (%d / %d h)") % [rec["name"], roundi(r.progress), roundi(float(rec["work_hours"]))]


static func _ailment(s: Survivor) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for inj: Dictionary in s.needs.injuries:
		parts.append(tr_s("%s, %d day(s) to heal") % [str(inj["kind"]).replace("_", " "),
			ceili(float(inj["hours"]) / GameClock.HOURS_PER_DAY)])
	if s.needs.sick_days > 0:
		parts.append(tr_s("sick, %d day(s)") % s.needs.sick_days)
	if s.needs.infected():
		parts.append(tr_s("infected"))
	return ", ".join(parts) if not parts.is_empty() else tr_s("feeling fine")


static func _book_name(book: String) -> String:
	var parts: PackedStringArray = book.split(":")
	var id: String = parts[parts.size() - 1]
	if parts[0] == "skill":
		return "'%s'" % CommunityRules.skills().get(id, {}).get("name", id.capitalize())
	return "'%s'" % id.replace("_", " ").capitalize()


## The others keeping company this hour.
static func _company(state: SimState, s: Survivor, _spot: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for o: Survivor in state.living():
		if o == s or NeedRules.activity(o, state.clock.hour) != "socialise":
			continue
		out.append(o.name)
	return out
