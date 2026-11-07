class_name SurvivorNeeds
extends RefCounted
## A survivor's body state (GDD §3): meters 0..100 where 0 is fine, injuries, sickness and infection. NeedRules
## changes it; data/sim/needs.json holds the numbers.

const NONE: int = -1

var fatigue: float = 0.0
var hunger: float = 0.0
var thirst: float = 0.0
var activity: String = ""  ## "" = follow the schedule (sleep / work); "mission", "idle" set by the game
var injuries: Array[Dictionary] = []  ## {"kind": String, "hours": float left}
var sick_days: int = 0  ## 0 = healthy
var infection_hours: int = NONE  ## NONE = not infected; 0 = the time ran out and the player must choose
var quarantined: bool = false


func infected() -> bool:
	return infection_hours != NONE


func to_dict() -> Dictionary:
	var hurt: Array = []
	for i: Dictionary in injuries:
		hurt.append([i["kind"], i["hours"]])
	return {"fatigue": fatigue, "hunger": hunger, "thirst": thirst, "activity": activity, "injuries": hurt,
		"sick_days": sick_days, "infection_hours": infection_hours, "quarantined": quarantined}


static func from_dict(d: Dictionary) -> SurvivorNeeds:
	var n: SurvivorNeeds = SurvivorNeeds.new()
	n.fatigue = float(d["fatigue"])
	n.hunger = float(d["hunger"])
	n.thirst = float(d["thirst"])
	n.activity = str(d["activity"])
	for a: Variant in d["injuries"]:
		n.injuries.append({"kind": str(a[0]), "hours": float(a[1])})
	n.sick_days = int(d["sick_days"])
	n.infection_hours = int(d["infection_hours"])
	n.quarantined = bool(d["quarantined"])
	return n
