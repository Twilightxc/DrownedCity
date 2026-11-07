class_name NeedRules
extends RefCounted
## Body needs (GDD §3, §11): fatigue, hunger, thirst, injuries, sickness and infection, from data/sim/needs.json.
## The hourly tick moves the meters; the morning upkeep (SimState.advance_day) feeds, waters and medicates.
## `m` is the survivor's build without needs (BuildRules.base_mods): traits and skills scale the rates.

const PATH: String = "res://data/sim/needs.json"
const CHOICES: PackedStringArray = ["exile", "quarantine", "end_life"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data


## What the survivor does this hour: the game's override, else the schedule (sleep at night, work by day).
static func activity(s: Survivor, hour: int) -> String:
	if not s.needs.activity.is_empty():
		return s.needs.activity
	var sch: Dictionary = data()["schedule"]
	var from: int = int(sch["sleep_from"])
	var to: int = int(sch["sleep_to"])
	var asleep: bool = hour >= from or hour < to if from > to else (hour >= from and hour < to)
	return "sleep" if asleep else "work"


## One in-game hour. Returns what happened that the community feels: "turned" when a quarantined survivor's time
## ran out. A thirsty survivor drinks the flood water and may get sick (`rng`).
static func tick_hour(s: Survivor, hour: int, m: StatMods, rng: RandomNumberGenerator) -> PackedStringArray:
	var events: PackedStringArray = PackedStringArray()
	if not s.is_alive():
		return events
	var n: SurvivorNeeds = s.needs
	var d: Dictionary = data()
	var act: String = activity(s, hour)
	var fat: Dictionary = d["fatigue"]
	var rate: float = float((fat["per_hour"] as Dictionary).get(act, 0.0))
	if rate > 0.0:
		rate = m.apply(&"rest_need", rate)  # Short Sleeper
		if m.has_perk(&"night_owl") and act != "sleep":
			rate *= 1.0 + float(fat["night_owl_day_mul"])
	n.fatigue = clampf(n.fatigue + rate, 0.0, 100.0)
	n.hunger = clampf(n.hunger + float(d["hunger"]["per_hour"]), 0.0, 100.0)
	if n.hunger >= 100.0:
		s.damage(float(d["hunger"]["health_per_hour_starving"]))
	n.thirst = clampf(n.thirst + float(d["thirst"]["per_hour"]), 0.0, 100.0)
	if n.thirst >= float(d["thirst"]["drinks_flood_water_at"]):
		n.thirst = 0.0
		expose(s, "flood_water", m, rng)
	var heal: float = m.apply(&"heal_rate", 1.0)  # Fast Healer
	for i: int in range(n.injuries.size() - 1, -1, -1):
		n.injuries[i]["hours"] = float(n.injuries[i]["hours"]) - heal
		if float(n.injuries[i]["hours"]) <= 0.0:
			n.injuries.remove_at(i)
	if n.infection_hours > 0:
		n.infection_hours -= 1
		if n.infection_hours == 0 and n.quarantined:
			s.damage(Survivor.MAX_STAT)
			n.infection_hours = SurvivorNeeds.NONE
			n.quarantined = false
			events.append("turned")
	return events


## A new injury of `kind` (needs.json injury.kinds). Endurance (injury_severity) makes it shorter.
static func injure(s: Survivor, kind: String, m: StatMods) -> void:
	var k: Dictionary = data()["injury"]["kinds"][kind]
	s.needs.injuries.append({"kind": kind, "hours": m.apply(&"injury_severity", float(k["heal_hours"]))})


static func heavily_injured(s: Survivor) -> bool:
	for i: Dictionary in s.needs.injuries:
		if bool(data()["injury"]["kinds"][i["kind"]].get("heavy", false)):
			return true
	return false


## Rain, flood water, rotten food or a sick housemate: may make the survivor sick. True when it did.
static func expose(s: Survivor, source: String, m: StatMods, rng: RandomNumberGenerator) -> bool:
	var sick: Dictionary = data()["sickness"]
	if s.needs.sick_days > 0 or not s.is_alive():
		return false
	if source in sick["dirty_sources"] and m.has_perk(&"no_dirty_food_sickness"):  # Iron Stomach
		return false
	if rng.randf() >= m.apply(&"sickness_chance", float(sick["chance"][source])):  # Weak Immune ×2
		return false
	s.needs.sick_days = maxi(1, roundi(float(sick["days"]) / m.apply(&"illness_recovery", 1.0)))  # Robust
	return true


## Zombie bites from a fight (FighterHealth.bites): each may infect. True when the survivor got infected.
static func on_bitten(s: Survivor, bites: int, m: StatMods, rng: RandomNumberGenerator) -> bool:
	if s.needs.infected() or not s.is_alive():
		return false
	var chance: float = m.apply(&"infection_chance", float(data()["infection"]["bite_chance"]))  # Resistant
	for i: int in bites:
		if rng.randf() < chance:
			s.needs.infection_hours = int(data()["infection"]["hours"])
			return true
	return false


## The infected whose time ran out: the player must choose for each (CHOICES).
static func waiting_for_choice(s: Survivor) -> bool:
	return s.is_alive() and s.needs.infection_hours == 0 and not s.needs.quarantined


## Exile (they leave the community), quarantine (quarantine_days more for an antiviral, then they turn) or end
## their life. Everyone's morale takes the choice's cost. False when there is nothing to choose.
static func resolve_infection(state: SimState, s: Survivor, choice: String) -> bool:
	if not waiting_for_choice(s) or not choice in CHOICES:
		return false
	var inf: Dictionary = data()["infection"]
	match choice:
		"exile":
			state.survivors.erase(s)
		"quarantine":
			s.needs.quarantined = true
			s.needs.infection_hours = int(inf["quarantine_days"]) * GameClock.HOURS_PER_DAY
		"end_life":
			s.damage(Survivor.MAX_STAT)
			s.needs.infection_hours = SurvivorNeeds.NONE
	for o: Survivor in state.living():
		o.change_morale(float(inf["community_morale"][choice]))
	return true


## Can join an expedition or a tower crew: no heavy injury, not sick, not infected past the deadline.
static func fit_to_go_out(s: Survivor) -> bool:
	return s.is_alive() and not heavily_injured(s) and s.needs.sick_days == 0 and not s.needs.quarantined \
		and not waiting_for_choice(s)


## The needs' effect on the build: max stamina lost to fatigue, hunger, thirst, injuries, sickness, infection.
## Marathon (fatigue, already in `out`) softens the fatigue part.
static func add_mods(s: Survivor, out: StatMods) -> void:
	var n: SurvivorNeeds = s.needs
	var d: Dictionary = data()
	var fat: float = float(d["fatigue"]["stamina_mul_at_max"]) * n.fatigue / 100.0
	out.push(&"max_stamina", "mul", fat * (1.0 + out.mul.get(&"fatigue", 0.0)))
	if n.hunger >= float(d["hunger"]["hungry_at"]):
		out.push(&"max_stamina", "mul", float(d["hunger"]["stamina_mul"]))
	if n.thirst >= float(d["thirst"]["thirsty_at"]):
		out.push(&"max_stamina", "mul", float(d["thirst"]["stamina_mul"]))
	for i: Dictionary in n.injuries:
		out.push(&"max_stamina", "mul", float(d["injury"]["kinds"][i["kind"]]["stamina_mul"]))
	if n.sick_days > 0:
		out.push(&"max_stamina", "mul", float(d["sickness"]["stamina_mul"]))
	if n.infected():
		out.push(&"max_stamina", "mul", float(d["infection"]["stamina_mul"]))
	if not fit_to_go_out(s):
		out.grant(&"unfit")
