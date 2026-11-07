class_name BaseRules
extends RefCounted
## The rooftop base (GDD §4), from data/sim/rooms.json: slots, building and upgrading rooms, production queues,
## who works where, beds, and what a room does for the people in it each hour.
## Rooms only move while someone works in them (GDD: "no one in the room, the work stops").

const PATH: String = "res://data/sim/rooms.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data


static func room_def(id: String) -> Dictionary:
	return data()["rooms"].get(id, {})


static func recipe(id: String) -> Dictionary:
	return data()["recipes"].get(id, {})


## The built tier's numbers, or {} for an empty or unfinished slot.
static func tier_def(r: RoomState) -> Dictionary:
	if r.room.is_empty() or r.tier <= 0:
		return {}
	return (room_def(r.room)["tiers"] as Array)[r.tier - 1]


## A new base: the empty slots, then the starting rooms already standing.
static func init(state: SimState) -> void:
	state.rooms.clear()
	var slots: Dictionary = data()["slots"]
	for size: String in ["large", "small"]:
		for i: int in int(slots[size]):
			state.rooms.append(RoomState.new(size))
	for start: Dictionary in data()["starting_rooms"]:
		for r: RoomState in state.rooms:
			if r.room.is_empty() and r.size == str(room_def(start["room"])["size"]):
				r.room = str(start["room"])
				r.tier = int(start["tier"])
				break


# --- building ------------------------------------------------------------------------------------------------------

## Why `room` can't go in slot `i` now, or "" when it can.
static func build_problem(state: SimState, i: int, room: String) -> String:
	if i < 0 or i >= state.rooms.size():
		return "no such slot"
	var r: RoomState = state.rooms[i]
	var def: Dictionary = room_def(room)
	if def.is_empty():
		return "no such room"
	if not r.room.is_empty():
		return "slot taken"
	if str(def["size"]) != r.size:
		return "needs a %s slot" % def["size"]
	return _cost_problem(state, (def["tiers"] as Array)[0])


## Starts building `room` in slot `i`: the materials are taken now, the work hours come from whoever works there.
static func build(state: SimState, i: int, room: String) -> bool:
	if not build_problem(state, i, room).is_empty():
		return false
	var r: RoomState = state.rooms[i]
	r.room = room
	_start_tier(state, r, 1)
	return true


static func upgrade_problem(state: SimState, i: int) -> String:
	if i < 0 or i >= state.rooms.size():
		return "no such slot"
	var r: RoomState = state.rooms[i]
	if r.room.is_empty() or r.tier <= 0 or r.building > 0:
		return "nothing to upgrade"
	var tiers: Array = room_def(r.room)["tiers"]
	if r.tier >= tiers.size():
		return "top tier"
	var next: Dictionary = tiers[r.tier]
	if next.has("needs_skill") and not _someone_has(state, str(next["needs_skill"])):
		return "needs someone with %s" % next["needs_skill"]
	return _cost_problem(state, next)


## Upgrades in place: the room keeps working at its old tier until the new one is finished.
static func upgrade(state: SimState, i: int) -> bool:
	if not upgrade_problem(state, i).is_empty():
		return false
	var r: RoomState = state.rooms[i]
	_start_tier(state, r, r.tier + 1)
	return true


## Tears a room down (its materials are lost); its workers go idle.
static func demolish(state: SimState, i: int) -> void:
	var size: String = state.rooms[i].size
	state.rooms[i] = RoomState.new(size)
	for s: Survivor in state.survivors:
		if s.assignment == i:
			s.assignment = -1


# --- production ----------------------------------------------------------------------------------------------------

## Adds a job: `count` units of `recipe_id` (-1 = keep going). The room must make it at its tier and have queue room.
static func queue_job(state: SimState, i: int, recipe_id: String, count: int = -1) -> bool:
	var r: RoomState = state.rooms[i]
	var t: Dictionary = tier_def(r)
	var rec: Dictionary = recipe(recipe_id)
	if t.is_empty() or rec.is_empty() or not recipe_id in room_def(r.room).get("recipes", []):
		return false
	if int(rec.get("tier", 1)) > r.tier or r.queue.size() >= int(t.get("queue", 0)) or count == 0:
		return false
	r.queue.append({"recipe": recipe_id, "count": count})
	return true


static func cancel_job(state: SimState, i: int, j: int) -> void:
	var r: RoomState = state.rooms[i]
	if j < 0 or j >= r.queue.size():
		return
	if j == 0:
		if r.started:  # the unit's inputs go back on the shelf
			state.add_stock(_floats(recipe(r.queue[0]["recipe"]).get("inputs", {})))
		r.progress = 0.0
		r.started = false
	r.queue.remove_at(j)


## Sends `s` to work in slot `i` (-1 = nowhere).
static func assign(state: SimState, s: Survivor, i: int) -> bool:
	if i >= state.rooms.size() or (i >= 0 and state.rooms[i].room.is_empty()):
		return false
	s.assignment = i
	return true


## What `s` could do in slot `i` now, without changing anything: "build" (building or upgrading), "job" (the
## queue's first job can run), "watch" (a guard post) or "" (nothing). The daily-life AI scores rooms by it.
static func work_kind(state: SimState, i: int, s: Survivor) -> String:
	if i < 0 or i >= state.rooms.size():
		return ""
	var r: RoomState = state.rooms[i]
	if r.building > 0:
		return "build"
	var t: Dictionary = tier_def(r)
	if t.is_empty():
		return ""
	if int(t.get("guards", 0)) > 0:
		return "watch"
	if r.queue.is_empty():
		return ""
	var rec: Dictionary = recipe(r.queue[0]["recipe"])
	if rec.has("needs_perk") and not CommunityRules.room_mods(s).has_perk(StringName(rec["needs_perk"])):
		return ""
	if not r.started and not _has(state, rec.get("inputs", {})):
		return ""
	return "job"


## One hour of `s` working in slot `i` (default: their assignment): building comes first, then the queue's first
## job. Returns what happened: "built", "made", "stalled" (inputs missing or a perk needed), "idle" (nothing to do)
## or "" for progress.
static func work_hour(state: SimState, s: Survivor, i: int = -2) -> String:
	if i == -2:
		i = s.assignment
	if i < 0 or i >= state.rooms.size():
		return "idle"
	var r: RoomState = state.rooms[i]
	var m: StatMods = BuildRules.base_mods(s)
	if r.building > 0:
		r.build_left -= m.apply(&"build_speed", 1.0)
		if r.build_left <= 0.0:
			r.tier = r.building
			r.building = 0
			r.build_left = 0.0
			return "built"
		return ""
	var t: Dictionary = tier_def(r)
	if t.is_empty():
		return "idle"
	var xp: String = str(room_def(r.room).get("xp_action", ""))
	if not xp.is_empty():
		SkillRules.on_action(s, xp, 1.0, SkillCatalog.load_default())
	if r.queue.is_empty():
		return "idle"
	var job: Dictionary = r.queue[0]
	var rec: Dictionary = recipe(job["recipe"])
	if rec.has("needs_perk") and not CommunityRules.room_mods(s).has_perk(StringName(rec["needs_perk"])):
		return "stalled"
	if not r.started:
		if not _has(state, rec.get("inputs", {})):
			return "stalled"
		for res: String in rec.get("inputs", {}):
			state.stock[res] = state.stock.get(res, 0.0) - float(rec["inputs"][res])
		r.started = true
	r.progress += float(t.get("work_mul", 1.0))
	r.worked += float(t.get("work_mul", 1.0))
	if r.progress < float(rec["work_hours"]):
		return ""
	state.add_stock(_floats(rec.get("outputs", {})))
	r.progress = 0.0
	r.started = false
	if int(job["count"]) > 0:
		job["count"] = int(job["count"]) - 1
		if int(job["count"]) == 0:
			r.queue.pop_front()
	return "made"


## Morning: rooms that make something on their own (rain barrels).
static func tick_day(state: SimState) -> void:
	for r: RoomState in state.rooms:
		var per_day: Dictionary = tier_def(r).get("per_day", {})
		if not per_day.is_empty():
			state.add_stock(_floats(per_day))


# --- what rooms do for people --------------------------------------------------------------------------------------

## Beds of every finished room of this kind ("sleeping", "infirmary").
static func beds(state: SimState, room: String) -> int:
	var n: int = 0
	for r: RoomState in state.rooms:
		if r.room == room:
			n += int(tier_def(r).get("beds", 0))
	return n


## The best tier's number among rooms of this kind, or `fallback` when there is none.
static func best(state: SimState, room: String, key: String, fallback: float) -> float:
	var v: float = fallback
	var found: bool = false
	for r: RoomState in state.rooms:
		if r.room == room and tier_def(r).has(key):
			v = float(tier_def(r)[key]) if not found else maxf(v, float(tier_def(r)[key]))
			found = true
	return v


## This hour's room effects for each living survivor doing `activity_of[s.id]`: a bed (or not) for sleepers, an
## infirmary bed for those resting hurt or sick, and for them asleep too (a bed, and they heal faster). Beds go to
## survivors in id order.
static func hour_mods(state: SimState, activity_of: Dictionary) -> Dictionary:
	var out: Dictionary = {}  # survivor id -> StatMods
	var sleep_beds: int = beds(state, "sleeping")
	var sick_beds: int = beds(state, "infirmary")
	var quality: float = best(state, "sleeping", "sleep_quality", 0.0)
	var heal: float = best(state, "infirmary", "heal_rate", 0.0)
	for s: Survivor in state.living():
		var m: StatMods = StatMods.new()
		var hurt: bool = NeedRules.heavily_injured(s) or s.needs.sick_days > 0
		match str(activity_of.get(s.id, "")):
			"sleep":
				if hurt and sick_beds > 0:
					sick_beds -= 1
					m.push(&"heal_rate", "mul", heal)
				elif sleep_beds > 0:
					sleep_beds -= 1
					m.push(&"sleep_quality", "mul", quality)
				else:
					m.push(&"sleep_quality", "mul", float(data()["no_bed_sleep"]))
			"rest":
				if sick_beds > 0:
					sick_beds -= 1
					m.push(&"heal_rate", "mul", heal)
		out[s.id] = m
	return out


static func _start_tier(state: SimState, r: RoomState, tier: int) -> void:
	var t: Dictionary = (room_def(r.room)["tiers"] as Array)[tier - 1]
	for res: String in t.get("build", {}):
		state.stock[res] = state.stock.get(res, 0.0) - float(t["build"][res])
	r.building = tier
	r.build_left = float(t["build_hours"])


static func _cost_problem(state: SimState, tier: Dictionary) -> String:
	return "" if _has(state, tier.get("build", {})) else "not enough materials"


static func _has(state: SimState, cost: Dictionary) -> bool:
	for res: String in cost:
		if state.stock.get(res, 0.0) + 0.0001 < float(cost[res]):
			return false
	return true


static func _someone_has(state: SimState, skill: String) -> bool:
	for s: Survivor in state.living():
		if s.community_skill == skill:
			return true
	return false


static func _floats(d: Dictionary) -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	for k: String in d:
		out[str(k)] = float(d[k])
	return out
