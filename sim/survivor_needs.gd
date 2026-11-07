class_name SurvivorNeeds
extends RefCounted
## A survivor's body state (GDD §3): meters 0..100 where 0 is fine, injuries, sickness and infection. NeedRules
## changes it; data/sim/needs.json holds the numbers.

const NONE: int = -1

var fatigue: float = 0.0
var hunger: float = 0.0
var thirst: float = 0.0
var activity: String = ""  ## the game's override ("mission"); "" = daily life decides (LifeRules)
var doing: String = ""  ## what daily life chose this hour (LifeRules): sleep, rest, work, read, exercise, ...
var doing_slot: int = -1  ## the base slot they work in this hour; -1 = not working
var worked_today: float = 0.0  ## work hours since the morning (the shift, LifeRules)
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
	return {"fatigue": fatigue, "hunger": hunger, "thirst": thirst, "activity": activity, "doing": doing,
		"doing_slot": doing_slot, "worked_today": worked_today, "injuries": hurt,
		"sick_days": sick_days, "infection_hours": infection_hours, "quarantined": quarantined}


static func from_dict(d: Dictionary) -> SurvivorNeeds:
	var n: SurvivorNeeds = SurvivorNeeds.new()
	n.fatigue = float(d["fatigue"])
	n.hunger = float(d["hunger"])
	n.thirst = float(d["thirst"])
	n.activity = str(d["activity"])
	n.doing = str(d["doing"])
	n.doing_slot = int(d["doing_slot"])
	n.worked_today = float(d["worked_today"])
	for a: Variant in d["injuries"]:
		n.injuries.append({"kind": str(a[0]), "hours": float(a[1])})
	n.sick_days = int(d["sick_days"])
	n.infection_hours = int(d["infection_hours"])
	n.quarantined = bool(d["quarantined"])
	return n
