class_name LifeRules
extends RefCounted
## Daily life in the base (GDD §4, 1.7 step 2): a utility AI. Every hour each survivor not on a mission scores what
## they could do (own need × the base's need × traits, data/sim/life.json) and does the best. Survivors decide in id
## order, so a room someone already took this hour scores lower for the next (crowding). Deterministic: the jitter
## comes from SimState.rng_for.

const PATH: String = "res://data/sim/life.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data


## Everyone living picks this hour's activity (SurvivorNeeds.doing / doing_slot). A survivor with the game's
## override (a mission) keeps it and takes no room.
static func decide(state: SimState) -> void:
	var taken: Dictionary = {}  # slot -> people working there this hour
	for s: Survivor in state.living():
		if not s.needs.activity.is_empty():
			s.needs.doing = ""
			s.needs.doing_slot = -1
			continue
		var best: Dictionary = options(state, s, taken)[0]
		s.needs.doing = str(best["act"])
		s.needs.doing_slot = int(best["slot"])
		if s.needs.doing_slot >= 0:
			taken[s.needs.doing_slot] = int(taken.get(s.needs.doing_slot, 0)) + 1


## Every option `s` has this hour, best first: [{"act", "slot", "score"}]. `taken` = people already working in each
## slot this hour. The Observer's "why" (1.7 step 5) can show this list.
static func options(state: SimState, s: Survivor, taken: Dictionary = {}) -> Array[Dictionary]:
	var d: Dictionary = data()
	var acts: Dictionary = d["activities"]
	var hour: int = state.clock.hour
	var n: SurvivorNeeds = s.needs
	var night: bool = is_night(s, hour)
	var evening: bool = _in(hour, int(d["evening"]["from"]), int(d["evening"]["to"]))
	var out: Array[Dictionary] = []
	var sleep: Dictionary = acts["sleep"]
	if n.doing == "sleep" and n.fatigue > float(sleep["wake_below"]):
		out.append(_opt("sleep", -1, INF))  # asleep until rested
		return out
	var sleep_score: float = _curve(sleep["fatigue_curve"], n.fatigue) + (float(sleep["night"]) if night else 0.0)
	out.append(_opt("sleep", -1, sleep_score))
	if NeedRules.heavily_injured(s) or n.sick_days > 0 or n.quarantined or n.infection_hours == 0:
		if not night:
			out.append(_opt("rest", -1, float(acts["rest"]["score"])))
		return _finish(state, s, out)  # nothing else while hurt, sick or held
	var w: Dictionary = acts["work"]
	var shift: float = BuildRules.base_mods(s).apply(&"shift_length", float(w["shift_hours"]))  # Workhorse
	for i: int in state.rooms.size():
		if s.assignment >= 0 and s.assignment != i:
			continue  # the player pinned them to another room
		var need: float = _room_need(state, i, s, int(taken.get(i, 0)))
		if need <= 0.0:
			continue
		var score: float = float(w["score"]) * need / (1.0 + float(w["crowding"]) * int(taken.get(i, 0)))
		var room: String = state.rooms[i].room
		if not s.community_skill.is_empty() and str(d["room_skill"].get(room, "")) == s.community_skill:
			score *= 1.0 + float(w["skill_match"])
		if s.assignment == i:
			score *= 1.0 + float(w["pinned"])
		if n.worked_today >= shift:
			score *= float(w["after_shift"])
		out.append(_opt("work", i, score * _trait_weight(s, room)))
	var read: Dictionary = acts["read"]
	if not s.reading.is_empty() or not state.books.is_empty():
		var rs: float = float(read["book"]) if not s.reading.is_empty() else float(read["shelf"])
		out.append(_opt("read", -1, rs + (float(read["evening"]) if evening else 0.0)))
	var ex: Dictionary = acts["exercise"]
	if n.fatigue < float(ex["max_fatigue"]):
		out.append(_opt("exercise", -1, float(ex["score"])))
	var soc: Dictionary = acts["socialise"]
	var ss: float = float(soc["score"]) + _curve(soc["low_morale_curve"], s.morale)
	ss += float(soc["evening"]) if evening else 0.0
	if _has_room(state, "kitchen"):
		ss *= float(soc["fire_mul"])
	out.append(_opt("socialise", -1, ss))
	out.append(_opt("idle", -1, float(acts["idle"]["score"])))
	return _finish(state, s, out)


## What the chosen activity does this hour, besides needs (NeedRules.tick_hour): work moves the room, reading and
## exercise train, company cheers.
static func act_hour(state: SimState, s: Survivor, act: String) -> void:
	var acts: Dictionary = data()["activities"]
	match act:
		"work":
			if s.needs.doing_slot >= 0:
				BaseRules.work_hour(state, s, s.needs.doing_slot)
				s.needs.worked_today += 1.0
		"read", "exercise":
			SkillRules.on_action(s, str(acts[act]["xp"]), float(acts[act]["xp_count"]), SkillCatalog.load_default())
		"socialise":
			var soc: Dictionary = acts["socialise"]
			var mul: float = float(soc["fire_morale_mul"]) if _has_room(state, "kitchen") else 1.0
			s.change_morale(float(soc["morale_per_hour"]) * mul)


## Sleep pulls hardest in these hours (life.json night); Night Owl's are later.
static func is_night(s: Survivor, hour: int) -> bool:
	var nd: Dictionary = data()["night"]
	if BuildRules.base_mods(s).has_perk(&"night_owl"):
		return _in(hour, int(nd["night_owl_from"]), int(nd["night_owl_to"]))
	return _in(hour, int(nd["from"]), int(nd["to"]))


## How much slot `i` needs a worker now (0 = nothing to do there for `s`), before crowding.
static func _room_need(state: SimState, i: int, s: Survivor, already: int) -> float:
	var w: Dictionary = data()["activities"]["work"]
	match BaseRules.work_kind(state, i, s):
		"build":
			return float(w["build"])
		"watch":
			var guards: int = int(BaseRules.tier_def(state.rooms[i]).get("guards", 0))
			return float(w["watch"]) if already < guards else 0.0
		"job":
			var rec: Dictionary = BaseRules.recipe(state.rooms[i].queue[0]["recipe"])
			var short: float = 0.0
			for res: String in rec.get("outputs", {}):
				short = maxf(short, _shortage(state, res))
			var floor_v: float = float(w["job_floor"])
			return floor_v + (1.0 - floor_v) * short
	return 0.0


## 0 = the base has all it wants of `res` (stock_want_per_person × people), 1 = none.
static func _shortage(state: SimState, res: String) -> float:
	var want: float = float(data()["stock_want_per_person"].get(res, 0.0)) * state.living().size()
	if want <= 0.0:
		return 0.0
	return clampf(1.0 - state.stock.get(res, 0.0) / want, 0.0, 1.0)


## Stick, jitter and traits, then best first (ties: the list's order, so sleep wins a tie).
static func _finish(state: SimState, s: Survivor, out: Array[Dictionary]) -> Array[Dictionary]:
	var d: Dictionary = data()
	var rng: RandomNumberGenerator = state.rng_for(-s.id)  # its own stream: needs' rolls stay as they were
	for o: Dictionary in out:
		if o["act"] != "work":
			o["score"] = float(o["score"]) * _trait_weight(s, str(o["act"]))
		else:
			o["score"] = float(o["score"]) * _trait_weight(s, "work")
		if o["act"] == s.needs.doing and int(o["slot"]) == s.needs.doing_slot:
			o["score"] = float(o["score"]) + float(d["stick"])
		o["score"] = float(o["score"]) + rng.randf() * float(d["jitter"])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	return out


static func _trait_weight(s: Survivor, key: String) -> float:
	var weights: Dictionary = data()["trait_weights"]
	var w: float = 1.0
	for t: String in s.traits:
		w *= float((weights.get(t, {}) as Dictionary).get(key, 1.0))
	return w


static func _has_room(state: SimState, room: String) -> bool:
	for r: RoomState in state.rooms:
		if r.room == room and r.tier > 0:
			return true
	return false


static func _opt(act: String, slot: int, score: float) -> Dictionary:
	return {"act": act, "slot": slot, "score": score}


static func _in(hour: int, from: int, to: int) -> bool:
	return hour >= from or hour < to if from > to else (hour >= from and hour < to)


static func _curve(points: Array, x: float) -> float:
	var first: Array = points[0]
	if x <= float(first[0]):
		return float(first[1])
	for i: int in range(1, points.size()):
		var a: Array = points[i - 1]
		var b: Array = points[i]
		if x <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (x - float(a[0])) / (float(b[0]) - float(a[0])))
	return float((points[points.size() - 1] as Array)[1])
