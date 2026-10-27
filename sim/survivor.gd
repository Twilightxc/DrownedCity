class_name Survivor
extends RefCounted
## One named community member (GDD §3). Spike D carries only what the save needs to prove itself.

const MAX_STAT: float = 100.0

var id: int = 0
var name: String = ""
var appearance_seed: int = 0  ## the look is rebuilt from this, so it never changes between loads
var health: float = MAX_STAT
var morale: float = MAX_STAT


func _init(p_id: int = 0, p_name: String = "", p_seed: int = 0) -> void:
	id = p_id
	name = p_name
	appearance_seed = p_seed


func is_alive() -> bool:
	return health > 0.0


func damage(amount: float) -> void:
	health = clampf(health - amount, 0.0, MAX_STAT)


func change_morale(amount: float) -> void:
	morale = clampf(morale + amount, 0.0, MAX_STAT)


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "appearance_seed": appearance_seed, "health": health, "morale": morale}


static func from_dict(d: Dictionary) -> Survivor:
	var s: Survivor = Survivor.new(int(d["id"]), str(d["name"]), int(d["appearance_seed"]))
	s.health = float(d["health"])
	s.morale = float(d["morale"])
	return s
