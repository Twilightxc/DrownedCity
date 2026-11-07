class_name ObserverDirector
extends RefCounted
## Observer mode's camera director (1.7 step 5, GDD §4): picks the most interesting thing on the roof to watch, a
## shot at a time (roof_layout.json "observer"). Pure: candidates in, a pick out, so a test can check its taste.
## A candidate: {"id": int, "act": String, "pos": Vector3, "errand": bool, "tending": bool (crops or building)}.

var cfg: Dictionary
var recent: Array[int] = []  ## the last shown, newest last


func _init(p_cfg: Dictionary) -> void:
	cfg = p_cfg


## How much `c` is worth watching among `all`.
func interest(c: Dictionary, all: Array[Dictionary]) -> float:
	var weights: Dictionary = cfg["interest"]
	var v: float = float(weights.get("errand" if c.get("errand", false) else c["act"], 0.0))
	if v <= 0.0:
		return 0.0
	if c.get("tending", false):
		v *= float(cfg["farm_or_build"])
	for o: Dictionary in all:
		if o["id"] != c["id"] and o["act"] != "mission" \
				and (o["pos"] as Vector3).distance_to(c["pos"]) <= float(cfg["group_m"]):
			v += float(cfg["per_companion"])
	if c["id"] in recent.slice(-2):
		v *= float(cfg["repeat"])
	return v


## The next shot: {"id", "pos" (the group's middle)}, or {} when there is nothing to see. Ties go to the lower id.
func pick(all: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_v: float = 0.0
	for c: Dictionary in all:
		var v: float = interest(c, all)
		if v > best_v + 0.0001:
			best = c
			best_v = v
	if best.is_empty():
		return {}
	recent.append(best["id"])
	if recent.size() > 4:
		recent.pop_front()
	return {"id": best["id"], "pos": group_centre(best, all)}


## The middle of `c` and everyone within group_m: the camera frames the whole group.
func group_centre(c: Dictionary, all: Array[Dictionary]) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0
	for o: Dictionary in all:
		if o["act"] != "mission" and (o["pos"] as Vector3).distance_to(c["pos"]) <= float(cfg["group_m"]):
			sum += o["pos"]
			n += 1
	return sum / maxi(n, 1)


## Does an errand start now while the shot shows something else? Then cut to it.
func errand_cut(all: Array[Dictionary], showing: int) -> Dictionary:
	for c: Dictionary in all:
		if c.get("errand", false) and c["id"] != showing:
			recent.append(c["id"])
			return {"id": c["id"], "pos": c["pos"]}
	return {}
