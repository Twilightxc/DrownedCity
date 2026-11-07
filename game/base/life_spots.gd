class_name LifeSpots
extends RefCounted
## Where each survivor goes in the base scene this hour and what they play there (1.7 step 3), from what daily life
## chose (SurvivorNeeds.doing / doing_slot, LifeRules). Pure: the same state gives the same spots, so a test can
## check it. Beds go out like BaseRules.hour_mods: in id order, the hurt and sick to the infirmary first.
## A spot: {"pos": Vector3, "yaw": float, "clip": StringName}, plus "wander": true (idle: stroll the roof) or
## "away": true (on a mission: off the roof through the hut).


static func assign(state: SimState, kit: BaseKit) -> Dictionary:
	var out: Dictionary = {}  # survivor id -> spot
	var sleep_beds: Array[Dictionary] = _all(state, kit, "sleeping", "beds")
	var sick_beds: Array[Dictionary] = _all(state, kit, "infirmary", "beds")
	var floor_beds: Array[Dictionary] = kit.roof_spots("floor_beds", &"sleep")
	var seats: Array[Dictionary] = _all(state, kit, "kitchen", "seats")
	var chat: Array[Dictionary] = _chat_ring(state, kit)
	var reads: Array[Dictionary] = kit.roof_spots("read", &"read")
	var gyms: Array[Dictionary] = kit.roof_spots("exercise", &"exercise")
	var at_work: Dictionary = {}  # slot -> workers placed so far
	var used: Dictionary = {}  # shared list -> how many took a spot from it
	for s: Survivor in state.living():
		var act: String = NeedRules.activity(s, state.clock.hour)
		var hurt: bool = NeedRules.heavily_injured(s) or s.needs.sick_days > 0
		var spot: Dictionary = {}
		match act:
			"sleep":
				spot = _take(sick_beds) if hurt and not sick_beds.is_empty() else {}
				if spot.is_empty():
					spot = _take(sleep_beds) if not sleep_beds.is_empty() else _nth(floor_beds, used, "floor")
			"rest":
				spot = _take(sick_beds) if not sick_beds.is_empty() else {}
				if spot.is_empty():
					spot = _take(sleep_beds) if not sleep_beds.is_empty() else _nth(floor_beds, used, "floor")
			"work":
				spot = _work_spot(state, kit, s.needs.doing_slot, int(at_work.get(s.needs.doing_slot, 0)))
				at_work[s.needs.doing_slot] = int(at_work.get(s.needs.doing_slot, 0)) + 1
			"read":
				spot = _nth(reads, used, "read")
			"exercise":
				spot = _nth(gyms, used, "gym")
			"socialise":
				spot = _take(seats) if not seats.is_empty() else _nth(chat, used, "chat")
			"mission":
				spot = {"pos": kit.exit_point(), "yaw": 0.0, "clip": &"stroll", "away": true}
		if spot.is_empty():  # idle, or nowhere left to go
			spot = {"pos": Vector3.ZERO, "yaw": 0.0, "clip": &"stroll", "wander": true}
		out[s.id] = spot
	return out


## Workers in slot `i` take its spots in turn; more workers than spots stand beside the last ones.
static func _work_spot(state: SimState, kit: BaseKit, i: int, k: int) -> Dictionary:
	if i < 0 or i >= state.rooms.size():
		return {}
	var r: RoomState = state.rooms[i]
	var guarding: bool = r.building == 0 and int(BaseRules.tier_def(r).get("guards", 0)) > 0
	var kind: String = "guards" if guarding else "work"
	var spots: Array[Dictionary] = kit.room_spots(i, r, kind)
	if spots.is_empty() and kind == "guards":
		spots = kit.room_spots(i, r, "work")
	if spots.is_empty():
		return {}
	var spot: Dictionary = spots[k % spots.size()].duplicate()
	if k >= spots.size():
		spot["pos"] = (spot["pos"] as Vector3) + Vector3(0.6 * (k / spots.size()), 0.0, 0.0)
	return spot


## Every built room of this kind's `kind` spots, slot order.
static func _all(state: SimState, kit: BaseKit, room: String, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in state.rooms.size():
		var r: RoomState = state.rooms[i]
		if r.room == room and r.tier > 0:
			out.append_array(kit.room_spots(i, r, kind))
	return out


## Standing round the kitchen (any built one), facing it; without a kitchen the layout's gathering spot.
static func _chat_ring(state: SimState, kit: BaseKit) -> Array[Dictionary]:
	for i: int in state.rooms.size():
		var r: RoomState = state.rooms[i]
		if r.room == "kitchen" and r.tier > 0:
			var c: Vector3 = kit.slot_transform(i).origin
			var radius: float = float(kit.layout["chat_ring"])
			var out: Array[Dictionary] = []
			for k: int in 6:
				var a: float = PI * 0.5 + k * TAU / 6.0  # the front first
				var p: Vector3 = c + Vector3(sin(a), 0.0, cos(a)) * radius
				out.append({"pos": p, "yaw": atan2(c.x - p.x, c.z - p.z), "clip": &"chat"})
			return out
	return kit.roof_spots("gather", &"chat")


static func _take(spots: Array[Dictionary]) -> Dictionary:
	return spots.pop_front() if not spots.is_empty() else {}


## Shared spots (floor beds, reading crates, the gym corner): the next one in turn; once all are taken, round
## again half a metre aside.
static func _nth(spots: Array[Dictionary], used: Dictionary, key: String) -> Dictionary:
	if spots.is_empty():
		return {}
	var k: int = int(used.get(key, 0))
	used[key] = k + 1
	var spot: Dictionary = spots[k % spots.size()].duplicate()
	spot["pos"] = (spot["pos"] as Vector3) + Vector3(0.5, 0.0, 0.5) * float(k / spots.size())
	return spot
