class_name LookRules
extends RefCounted
## Rolls how a survivor looks (PHASE1 1.8) from data/sim/looks.json. Deterministic: the same name, background and
## appearance seed always give the same person, so a save (or a migration) rebuilds the same figure. Its own random
## stream, so adding looks never moves any other roll.

const PATH: String = "res://data/sim/looks.json"
const SALT: int = 0x10C5

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data


## The outfit set a background dresses in (looks.json background_outfit); civilian otherwise.
static func outfit_for(background: String) -> String:
	return str(data()["background_outfit"].get(background, "civilian"))


static func roll(survivor_name: String, background: String, appearance_seed: int) -> SurvivorLook:
	var d: Dictionary = data()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([appearance_seed, SALT])
	var l: SurvivorLook = SurvivorLook.new()
	var named: Variant = (d["names"] as Dictionary).get(survivor_name)
	var female_roll: bool = rng.randf() < float(d["sex_chance_female"])  # drawn either way: the stream stays aligned
	l.sex = str(named) if named in ["male", "female"] else ("female" if female_roll else "male")
	l.build = pick(d["builds"], rng)
	var hr: Array = d["height_m"][l.sex]
	# to the centimetre, parsed from text so a JSON round trip gives back the very same float
	l.height = ("%.2f" % lerpf(float(hr[0]), float(hr[1]), (rng.randf() + rng.randf()) * 0.5)).to_float()
	var skins: Array = d["skin"]
	l.skin = str(skins[rng.randi_range(0, skins.size() - 1)])
	l.hair = pick(d["hair_styles"][l.sex], rng)
	l.hair_colour = pick(d["hair_colours"], rng)
	var fh: Dictionary = d["facial_hair"]
	var beard: bool = rng.randf() < float(fh["chance_male"])
	var beard_style: String = pick(fh["styles"], rng)
	l.facial_hair = beard_style if beard and l.sex == "male" else ""
	l.outfit_set = outfit_for(background)
	var sets: Dictionary = d["outfits"]
	var set_ids: Array = sets.keys()
	for slot: String in d["slots"]:
		var from: String = l.outfit_set
		if rng.randf() < float(d["mix_chance"]):
			from = str(set_ids[rng.randi_range(0, set_ids.size() - 1)])
		var set_d: Dictionary = sets[from]
		var colours: Array = set_d["colours"]
		l.outfit[slot] = {"piece": pick(set_d[slot], rng), "colour": str(colours[rng.randi_range(0, colours.size() - 1)]),
			"pattern": pick(set_d["patterns"], rng)}
	return l


## Gives `s` its look (after its background is set).
static func dress(s: Survivor) -> void:
	s.look = roll(s.name, s.background, s.appearance_seed)


## A weighted pick from {id: weight} (a "note" key is skipped).
static func pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for k: String in weights:
		if k != "note":
			total += float(weights[k])
	var r: float = rng.randf() * total
	var last: String = ""
	for k: String in weights:
		if k == "note":
			continue
		last = k
		r -= float(weights[k])
		if r < 0.0:
			return k
	return last
