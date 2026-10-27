class_name SimState
extends RefCounted
## SimCore root: the single source of truth that a save serializes (CLAUDE.md).
## Spike D scope: clock, survivors, stockpile and the daily upkeep tick.

const RESOURCES: PackedStringArray = ["food", "water", "materials", "ammo"]

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


## Morning upkeep (GDD §11), then the clock moves to the next morning.
func advance_day(rules: SimRules) -> void:
	var people: Array[Survivor] = living()
	var short_food: bool = _consume("food", rules.food_per_survivor * people.size())
	var short_water: bool = _consume("water", rules.water_per_survivor * people.size())
	var short_materials: bool = _consume("materials", rules.materials_per_day)
	for s: Survivor in people:
		if short_food:
			s.damage(rules.hunger_health_loss)
		if short_water:
			s.damage(rules.thirst_health_loss)
		for short: bool in [short_food, short_water, short_materials]:
			if short:
				s.change_morale(-rules.shortage_morale_loss)
	clock.advance_hours(GameClock.HOURS_PER_DAY)


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
