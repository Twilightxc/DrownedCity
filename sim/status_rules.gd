class_name StatusRules
extends RefCounted
## Influence, rank points, the status ladder and the leader (GDD §3, §11, §12; CITIZENS_1_6 §2), from
## data/sim/status.json. Influence earned goes to the base pool and to the earner's rank points; spending the pool
## never lowers a rank, and status only goes up. One leader at a time, picked from the outstanding citizens; a leader
## who steps down stays an outstanding citizen.

const PATH: String = "res://data/sim/status.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data


static func ladder_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for step: Dictionary in data()["ladder"]:
		out.append(str(step["id"]))
	return out


static func rank(status: String) -> int:
	return ladder_ids().find(status)


## `s` did `source` (status.json influence key) `count` times. Well Liked earns more. Returns the influence earned.
static func earn(state: SimState, s: Survivor, source: String, count: float = 1.0) -> float:
	if not s.is_alive() or count <= 0.0:
		return 0.0
	var amount: float = BuildRules.base_mods(s).apply(&"influence", float(data()["influence"][source]) * count)
	state.influence += amount
	s.rank_points += amount
	promote(s)
	return amount


## Moves `s` up the ladder as far as their rank points reach; never down. Returns true when they moved.
static func promote(s: Survivor) -> bool:
	var before: int = rank(s.status)
	var best: int = before
	var ladder: Array = data()["ladder"]
	for i: int in ladder.size():
		if s.rank_points >= float(ladder[i]["at"]) and i > best:
			best = i
	s.status = str(ladder[best]["id"])
	return best > before


## Pays from the base pool (recruiting, outposts, trade). Ranks are untouched. False when the pool is short.
static func spend(state: SimState, amount: float) -> bool:
	if amount < 0.0 or state.influence < amount:
		return false
	state.influence -= amount
	return true


## Morning: a day in the base for everyone alive, and a bonus for those in good spirits.
static func tick_day(state: SimState) -> void:
	var inf: Dictionary = data()["influence"]
	for s: Survivor in state.living():
		earn(state, s, "day_in_base")
		if s.morale >= float(inf["high_morale_at"]):
			earn(state, s, "high_morale_day")


static func is_outstanding(s: Survivor) -> bool:
	return rank(s.status) >= rank("outstanding")


## Makes `s` the leader of `leader_type` (status.json leaders). Only an outstanding citizen, alive; one leader at a
## time, so a sitting leader steps down first. Which types a survivor may take comes from their community skill
## (CITIZENS_1_6 §6), checked once community skills exist.
static func appoint(state: SimState, s: Survivor, leader_type: String) -> bool:
	if not s.is_alive() or not is_outstanding(s) or not (data()["leaders"] as Dictionary).has(leader_type):
		return false
	if not s in state.survivors:
		return false
	state.leader_id = s.id
	state.leader_type = leader_type
	return true


static func step_down(state: SimState) -> void:
	state.leader_id = 0
	state.leader_type = ""


static func leader(state: SimState) -> Survivor:
	for s: Survivor in state.survivors:
		if s.id == state.leader_id and s.is_alive():
			return s
	return null


## The current step's perks on the build: stranger (not under the player's control) or outstanding_citizen.
static func add_mods(s: Survivor, out: StatMods) -> void:
	var i: int = rank(s.status)
	if i < 0:
		return
	for p: String in (data()["ladder"] as Array)[i].get("perks", []):
		out.grant(StringName(p))
