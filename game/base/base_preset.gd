class_name BasePreset
extends RefCounted
## Test bases for the base scene until the build UI (1.7 step 4): a community with rooms already standing and jobs
## queued, so daily life has something to do. `?rooms=start|tier1|tier2` (F5 cycles), `?people=3..6`.

const KINDS: PackedStringArray = ["start", "tier1", "tier2"]
const RULES: SimRules = preload("res://data/sim/base_economy.tres")
const EXTRA_NAMES: PackedStringArray = ["Ana", "Viktor", "Joe"]
## Slot order (BaseRules.init: large first): sleeping, farm, infirmary | water, kitchen, watchtower.
const ROOMS: PackedStringArray = ["sleeping", "farm", "infirmary", "water", "kitchen", "watchtower"]


static func make(kind: String, people: int, game_seed: int, hour: int) -> SimState:
	var state: SimState = SimState.new_game(RULES, game_seed)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = game_seed ^ 0xBA5E
	var cat: SkillCatalog = SkillCatalog.load_default()
	for i: int in clampi(people, 1, 6) - state.survivors.size():
		var s: Survivor = state.add_survivor(EXTRA_NAMES[i], rng.randi())
		SkillRules.setup(s, SkillRules.roll_background(rng, cat), cat)
		s.traits = TraitRules.roll(rng)
		s.status = "member"
		CommunityRules.roll_born(s, rng)
	for res: String in SimState.RESOURCES:
		state.stock[res] = 30.0
	state.stock["meals"] = 0.0
	state.books["skill:gardening"] = 1  # a book on the shelf: people read in the evening
	apply(state, kind)
	state.clock = GameClock.new(1, hour)
	LifeRules.decide(state)
	return state


## Sets the rooms of `kind` in place (keeps the people), so F5 can swap them live.
static func apply(state: SimState, kind: String) -> void:
	BaseRules.init(state)
	for s: Survivor in state.survivors:
		s.assignment = -1
	for i: int in ROOMS.size():
		var r: RoomState = state.rooms[i]
		r.room = ROOMS[i]
		r.tier = 2 if kind == "tier2" else 1
		r.building = 0
		r.queue.clear()
	state.rooms[1].worked = 5.0  # the farm has been going a while: its beds stand at different stages (FarmLook)
	if kind == "start":  # the infirmary is still going up
		state.rooms[2].tier = 0
		state.rooms[2].building = 1
		state.rooms[2].build_left = 8.0
	for job: Array in [[1, "grow_food"], [1, "grow_herbs"], [2, "herb_medicine"], [3, "filter_flood_water"],
			[4, "cook_meal"]]:
		BaseRules.queue_job(state, job[0], job[1])
