class_name FarmLook
extends RefCounted
## How a farm's planters look and what their tenders do (1.7 step 3, roof_layout.json "farm"). Each planter grows
## through STAGES every cycle_hours of the room's production work (RoomState.worked, SimCore), staggered by planter,
## so one bed is being hoed while another is ripe. Read-only: SimCore still decides what the farm makes.

const STAGES: int = 5  ## tilled, sprouts, young, grown, ripe


## Growth stage 0..4 of planter `k` of `plots`.
static func stage(r: RoomState, k: int, plots: int, cycle_hours: float) -> int:
	var phase: float = fposmod(r.worked / cycle_hours + float(k) / float(maxi(plots, 1)), 1.0)
	return mini(int(phase * STAGES), STAGES - 1)


## The crop in planter `k`: food crops in turn (by slot, so two farms differ); herbs in the last bed while herbs
## are queued, every bed when only herbs are.
static func crop(slot: int, r: RoomState, k: int, plots: int, farm: Dictionary) -> String:
	var herbs: bool = false
	var food: bool = false
	for job: Dictionary in r.queue:
		herbs = herbs or job["recipe"] == "grow_herbs"
		food = food or job["recipe"] == "grow_food"
	if herbs and (not food or k == plots - 1):
		return str(farm["herb_crop"])
	var crops: Array = farm["food_crops"]
	return str(crops[(k + slot) % crops.size()])


## The model on planter `k`: bare tilled soil, sprouts, then the crop's own stages.
static func model_key(slot: int, r: RoomState, k: int, plots: int, farm: Dictionary) -> String:
	var st: int = stage(r, k, plots, float(farm["cycle_hours"]))
	if st == 0:
		return "crop_tilled"
	if st == 1:
		return "crop_sprouts"
	return "crop_%s_%d" % [crop(slot, r, k, plots, farm), st]


## [clip, item] for tending planter `k` now: hoe it, sow it, water it, weed it, harvest it.
static func task(r: RoomState, k: int, plots: int, farm: Dictionary) -> Array:
	return (farm["tasks"] as Array)[stage(r, k, plots, float(farm["cycle_hours"]))]
