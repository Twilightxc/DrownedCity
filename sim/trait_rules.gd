class_name TraitRules
extends RefCounted
## Traits (GDD §3, CITIZENS_1_6 §5), read from data/sim/traits.json. Rolled at birth: 2–3, at least one negative,
## never two that conflict. Earned traits come later: from a counter (Hardened after 5 horde nights, Water Rat after
## 20 dives) or an event (Survivor's Guilt for 5 days after a close friend dies).

const PATH: String = "res://data/sim/traits.json"

static var _default: Dictionary = {}


static func catalog() -> Dictionary:
	if _default.is_empty():
		_default = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _default


static func defs() -> Dictionary:
	return catalog()["traits"]


static func is_negative(id: String) -> bool:
	return bool(defs()[id].get("neg", false))


static func is_earned(id: String) -> bool:
	return defs()[id].has("earned")


static func conflicts(a: String, b: String) -> bool:
	return b in defs()[a].get("conflicts", []) or a in defs()[b].get("conflicts", [])


## 2–3 traits (roll.min..max), at least roll.min_negative of them negative, no conflicting pair, none earned.
static func roll(rng: RandomNumberGenerator) -> PackedStringArray:
	var rules: Dictionary = catalog()["roll"]
	var pool: Array[String] = []
	for id: String in defs():
		if not is_earned(id):
			pool.append(id)
	var picked: PackedStringArray = PackedStringArray()
	var count: int = rng.randi_range(int(rules["min"]), int(rules["max"]))
	var guard: int = 0
	while picked.size() < count and guard < 500:
		guard += 1
		var want_neg: bool = _negatives(picked) < int(rules["min_negative"])
		var id: String = pool[rng.randi() % pool.size()]
		if id in picked or (want_neg and not is_negative(id)) or not _fits(picked, id):
			continue
		picked.append(id)
	return picked


## Adds `id` unless the survivor has it, it conflicts with one they have, or it was blocked (Hardened blocks
## Panicky for good). Returns true when added.
static func give(s: Survivor, id: String) -> bool:
	if id in s.traits or not defs().has(id):
		return false
	var earned: Dictionary = defs()[id].get("earned", {})
	var removes: Array = earned.get("removes", [])
	var keep: PackedStringArray = PackedStringArray()
	for t: String in s.traits:
		if not t in removes:
			keep.append(t)
	if not _fits(keep, id):
		return false
	for gone: String in removes:
		take(s, gone)
	s.traits.append(id)
	for extra: String in earned.get("grants", []):
		give(s, extra)
	if earned.has("days"):
		s.trait_days[id] = int(earned["days"])
	return true


static func take(s: Survivor, id: String) -> void:
	var i: int = s.traits.find(id)
	if i >= 0:
		s.traits.remove_at(i)
	s.trait_days.erase(id)


## Counts something toward the earned traits that wait for it ("horde_nights", "dives").
static func count(s: Survivor, counter: String, amount: int = 1) -> void:
	s.counters[counter] = s.counters.get(counter, 0) + amount
	for id: String in defs():
		var earned: Dictionary = defs()[id].get("earned", {})
		if earned.get("counter", "") == counter and s.counters[counter] >= int(earned["at"]):
			give(s, id)


## Something happened to the survivor ("close_friend_died"): earned traits triggered by it.
static func on_event(s: Survivor, event: String) -> void:
	for id: String in defs():
		if (defs()[id].get("earned", {}) as Dictionary).get("event", "") == event:
			if id in s.traits:
				s.trait_days[id] = int(defs()[id]["earned"]["days"])  # it starts over
			else:
				give(s, id)


## Morning: timed traits count down and wear off.
static func tick_day(s: Survivor) -> void:
	for id: String in s.trait_days.keys():
		s.trait_days[id] -= 1
		if s.trait_days[id] <= 0:
			take(s, id)


## Adds the survivor's trait modifiers and perks to `out`.
static func add_mods(s: Survivor, out: StatMods) -> void:
	for id: String in s.traits:
		if not defs().has(id):
			continue
		var d: Dictionary = defs()[id]
		for m: Array in d.get("mods", []):
			out.push_for(StringName(m[0]), str(m[1]), float(m[2]), PackedStringArray(m[3]) if m.size() > 3 else PackedStringArray())
		for p: String in d.get("perks", []):
			out.grant(StringName(p))


static func _negatives(ids: PackedStringArray) -> int:
	var n: int = 0
	for id: String in ids:
		if is_negative(id):
			n += 1
	return n


static func _fits(have: PackedStringArray, id: String) -> bool:
	for other: String in have:
		if conflicts(other, id):
			return false
	return true
