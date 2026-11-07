class_name SurvivorLook
extends RefCounted
## How one survivor looks (PHASE1 1.8, GDD §3 / §7 / §13): body, skin, hair and the outfit, piece by piece. Looks
## only, never stats. LookRules rolls it once from the survivor's appearance seed; the game builds the figure from it.

var sex: String = "male"  ## "male" / "female": which base body
var build: String = "average"  ## looks.json builds: a blend of the body's shape keys
var height: float = 1.75  ## metres; the game scales the skeleton
var skin: String = "#d39b72"  ## sRGB hex
var hair: String = "short"  ## looks.json hair_styles id; "bald" = none
var hair_colour: String = "#3b2a1e"
var facial_hair: String = ""  ## "" = clean-shaven
var outfit_set: String = "civilian"  ## the set most pieces came from (by background)
var outfit: Dictionary = {}  ## slot -> {"piece": id ("none" = empty), "colour": hex, "pattern": id}


func to_dict() -> Dictionary:
	return {"sex": sex, "build": build, "height": height, "skin": skin, "hair": hair, "hair_colour": hair_colour,
		"facial_hair": facial_hair, "outfit_set": outfit_set, "outfit": outfit.duplicate(true)}


static func from_dict(d: Dictionary) -> SurvivorLook:
	var l: SurvivorLook = SurvivorLook.new()
	l.sex = str(d["sex"])
	l.build = str(d["build"])
	l.height = float(d["height"])
	l.skin = str(d["skin"])
	l.hair = str(d["hair"])
	l.hair_colour = str(d["hair_colour"])
	l.facial_hair = str(d["facial_hair"])
	l.outfit_set = str(d["outfit_set"])
	var o: Dictionary = d["outfit"]
	for slot: Variant in o:
		var p: Dictionary = o[slot]
		l.outfit[str(slot)] = {"piece": str(p["piece"]), "colour": str(p["colour"]), "pattern": str(p["pattern"])}
	return l
