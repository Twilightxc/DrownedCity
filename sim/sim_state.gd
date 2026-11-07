class_name SimState
extends RefCounted
## SimCore root: the single source of truth that a save serializes (CLAUDE.md).
## Spike D scope: clock, survivors, stockpile and the daily upkeep tick.

const RESOURCES: PackedStringArray = ["food", "water", "materials", "ammo", "medicine", "antiviral"]

var clock: GameClock = GameClock.new(1, 6)
var survivors: Array[Survivor] = []
var stock: Dictionary[String, float] = {}
var game_seed: int = 0
var next_survivor_id: int = 1


static func new_game(rules: SimRules, p_seed: int) -> SimState:
	var state: SimState = SimState.new()
	state.game_seed = p_seed
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = p_seed
	for survivor_name: String in rules.starting_survivors:
		state.add_survivor(survivor_name, rng.randi())
	var build_rng: RandomNumberGenerator = RandomNumberGenerator.new()  # its own stream: looks stay as before 1.6
	build_rng.seed = p_seed ^ 0x5EED
	var cat: SkillCatalog = SkillCatalog.load_default()
	for s: Survivor in state.survivors:
		SkillRules.setup(s, SkillRules.roll_background(build_rng, cat), cat)
		s.traits = TraitRules.roll(build_rng)
	for res: String in RESOURCES:
		state.stock[res] = rules.starting_stock.get(res, 0.0)
	return state


func add_survivor(survivor_name: String, appearance_seed: int) -> Survivor:
	var s: Survivor = Survivor.new(next_survivor_id, survivor_name, appearance_seed)
	next_survivor_id += 1
	survivors.append(s)
	return s


func living() -> Array[Survivor]:
	var out: Array[Survivor] = []
	for s: Survivor in survivors:
		if s.is_alive():
			out.append(s)
	return out


func add_stock(amounts: Dictionary[String, float]) -> void:
	for res: String in amounts:
		stock[res] = stock.get(res, 0.0) + amounts[res]


## Morning upkeep (GDD §11), then 24 hourly ticks to the next morning.
func advance_day(rules: SimRules) -> void:
	_morning(rules)
	for h: int in GameClock.HOURS_PER_DAY:
		advance_hour()


## One in-game hour: every living survivor's needs move (NeedRules). Fast-forward = many of these.
func advance_hour() -> void:
	for s: Survivor in living():
		for event: String in NeedRules.tick_hour(s, clock.hour, BuildRules.base_mods(s), rng_for(s.id)):
			if event == "turned":
				for o: Survivor in living():
					o.change_morale(float(NeedRules.data()["infection"]["community_morale"]["turned"]))
	clock.advance_hours(1)


## A random stream for this hour and `salt` (a survivor id): the same save replays the same, with no RNG state
## to store.
func rng_for(salt: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([game_seed, clock.total_hours(), salt])
	return rng


func _morning(rules: SimRules) -> void:
	var people: Array[Survivor] = living()
	var community_morale: float = 0.0
	var food_need: Dictionary[int, float] = {}
	for s: Survivor in people:
		var m: StatMods = BuildRules.base_mods(s)
		food_need[s.id] = m.apply(&"food_use", rules.food_per_survivor)  # Big Eater ×1.5
		community_morale += m.add.get(&"community_morale", 0.0)  # Optimist / Grumpy
		s.change_morale(m.add.get(&"morale_per_day", 0.0))  # Survivor's Guilt
		TraitRules.tick_day(s)
	for s: Survivor in people:
		s.change_morale(community_morale)
	var hungriest: Array[Survivor] = people.duplicate()
	hungriest.sort_custom(func(a: Survivor, b: Survivor) -> bool:
		return a.needs.hunger > b.needs.hunger or (a.needs.hunger == b.needs.hunger and a.id < b.id))
	var short_food: bool = false
	for s: Survivor in hungriest:
		var got: float = _take("food", food_need[s.id])
		s.needs.hunger *= 1.0 - got / food_need[s.id]  # a partial meal takes part of the hunger away
		short_food = short_food or got < food_need[s.id]
	var thirstiest: Array[Survivor] = people.duplicate()
	thirstiest.sort_custom(func(a: Survivor, b: Survivor) -> bool:
		return a.needs.thirst > b.needs.thirst or (a.needs.thirst == b.needs.thirst and a.id < b.id))
	var short_water: bool = false
	for s: Survivor in thirstiest:
		var got: float = _take("water", rules.water_per_survivor)
		s.needs.thirst *= 1.0 - got / rules.water_per_survivor
		short_water = short_water or got < rules.water_per_survivor
	var short_materials: bool = _consume("materials", rules.materials_per_day)
	for s: Survivor in people:
		for short: bool in [short_food, short_water, short_materials]:
			if short:
				s.change_morale(-rules.shortage_morale_loss)
	_medicate(people)


## Medicine for heavy injuries, then the sick (a day more off); sickness spreads and runs its course; an antiviral
## cures an infection, even one already waiting for the player's choice or in quarantine.
func _medicate(people: Array[Survivor]) -> void:
	var d: Dictionary = NeedRules.data()
	var inj: Dictionary = d["injury"]
	var sick: Dictionary = d["sickness"]
	for s: Survivor in people:
		if NeedRules.heavily_injured(s) and _take("medicine", float(inj["medicine_per_heavy_day"])) \
				< float(inj["medicine_per_heavy_day"]):
			for i: Dictionary in s.needs.injuries:  # no medicine: this day's healing is cut
				i["hours"] = float(i["hours"]) + GameClock.HOURS_PER_DAY * (1.0 - float(inj["no_medicine_heal_mul"]))
	var sick_now: int = 0
	for s: Survivor in people:
		if s.needs.sick_days > 0:
			sick_now += 1
	for s: Survivor in people:
		if s.needs.sick_days > 0:
			if _take("medicine", float(sick["medicine_per_day"])) >= float(sick["medicine_per_day"]):
				s.needs.sick_days -= int(sick["medicine_extra_days"])
			s.needs.sick_days = maxi(s.needs.sick_days - 1, 0)
			s.change_morale(float(sick["morale_per_day"]))
		else:
			var m: StatMods = BuildRules.base_mods(s)
			for i: int in sick_now:
				NeedRules.expose(s, "contagion", m, rng_for(s.id * 100 + i))
		if s.needs.infected() and _take("antiviral", 1.0) >= 1.0:
			s.needs.infection_hours = SurvivorNeeds.NONE
			s.needs.quarantined = false


## Takes up to `amount` and returns what it got.
func _take(res: String, amount: float) -> float:
	var got: float = minf(stock.get(res, 0.0), amount)
	stock[res] = stock.get(res, 0.0) - got
	return got


## Takes `amount`, floored at 0. Returns true when the stock ran short.
func _consume(res: String, amount: float) -> bool:
	var have: float = stock.get(res, 0.0)
	stock[res] = maxf(have - amount, 0.0)
	return have < amount


func to_dict() -> Dictionary:
	var people: Array = []
	for s: Survivor in survivors:
		people.append(s.to_dict())
	return {
		"day": clock.day,
		"hour": clock.hour,
		"seed": game_seed,
		"next_survivor_id": next_survivor_id,
		"survivors": people,
		"stock": stock.duplicate(),
	}


static func from_dict(d: Dictionary) -> SimState:
	var state: SimState = SimState.new()
	state.clock = GameClock.new(int(d["day"]), int(d["hour"]))
	state.game_seed = int(d["seed"])
	state.next_survivor_id = int(d["next_survivor_id"])
	for sd: Variant in d["survivors"]:
		state.survivors.append(Survivor.from_dict(sd as Dictionary))
	var stock_d: Dictionary = d["stock"]
	for res: Variant in stock_d:
		state.stock[str(res)] = float(stock_d[res])
	return state
