extends GutTest
## 1.8 step 1: how survivors look, in SimCore (data/sim/looks.json, LookRules, SurvivorLook). Looks only.


func _roll(i: int, background: String = "teacher", survivor_name: String = "Nobody") -> SurvivorLook:
	return LookRules.roll(survivor_name, background, 1000 + i)


func test_the_same_seed_is_the_same_person() -> void:
	assert_eq(_roll(7).to_dict(), _roll(7).to_dict())
	assert_ne(_roll(7).to_dict(), _roll(8).to_dict())


func test_every_roll_uses_only_what_the_data_has() -> void:
	var d: Dictionary = LookRules.data()
	for i: int in 300:
		var l: SurvivorLook = _roll(i, ["ex_soldier", "doctor", "fisherman", "farmer", "boxer"][i % 5])
		assert_true(l.build in d["builds"] and l.build != "note", l.build)
		var hr: Array = d["height_m"][l.sex]
		assert_between(l.height, float(hr[0]), float(hr[1]))
		assert_true(l.skin in d["skin"])
		assert_true(d["hair_styles"][l.sex].has(l.hair), "%s hair for a %s" % [l.hair, l.sex])
		assert_true(l.facial_hair.is_empty() or l.sex == "male", "beards on men only")
		for slot: String in d["slots"]:
			var p: Dictionary = l.outfit[slot]
			assert_true(p["pattern"] in d["patterns"], p["pattern"])
			var known: bool = false
			for set_id: String in d["outfits"]:
				known = known or (d["outfits"][set_id][slot] as Dictionary).has(p["piece"])
			assert_true(known, "%s in %s" % [p["piece"], slot])


func test_a_background_dresses_its_set_mostly() -> void:
	var soldier_torso: int = 0
	var n: int = 400
	for i: int in n:
		var l: SurvivorLook = _roll(i, "ex_soldier")
		assert_eq(l.outfit_set, "soldier")
		if (LookRules.data()["outfits"]["soldier"]["torso"] as Dictionary).has(l.outfit["torso"]["piece"]):
			soldier_torso += 1
	assert_between(float(soldier_torso) / n, 0.7, 0.9, "a quarter of slots mix in another set")


func test_men_and_women_both_turn_up_and_men_run_taller() -> void:
	var count: Dictionary = {"male": 0, "female": 0}
	var tall: Dictionary = {"male": 0.0, "female": 0.0}
	for i: int in 600:
		var l: SurvivorLook = _roll(i)
		count[l.sex] += 1
		tall[l.sex] += l.height
	assert_between(float(count["female"]) / 600.0, 0.4, 0.6)
	assert_gt(tall["male"] / count["male"], tall["female"] / count["female"] + 0.08)


func test_known_names_keep_their_sex() -> void:
	for i: int in 20:
		assert_eq(_roll(i, "teacher", "Mara").sex, "female")
		assert_eq(_roll(i, "teacher", "Viktor").sex, "male")


func test_a_new_game_dresses_everyone_and_a_save_keeps_it() -> void:
	var state: SimState = SimState.new_game(SimRules.new(), 3)
	for s: Survivor in state.survivors:
		assert_eq(s.look.to_dict(), LookRules.roll(s.name, s.background, s.appearance_seed).to_dict(), s.name)
	var back: SaveCodec.Result = SaveCodec.decode(SaveCodec.encode(state))
	assert_eq(back.error, "")
	assert_eq(back.state.survivors[1].look.to_dict(), state.survivors[1].look.to_dict())


func test_a_schema_9_save_gets_the_looks_a_new_game_would_give() -> void:
	var state: SimState = SimState.new_game(SimRules.new(), 3)
	var envelope: Dictionary = JSON.parse_string(SaveCodec.encode(state))
	envelope["schema"] = 9
	for sd: Dictionary in envelope["state"]["survivors"]:
		sd.erase("look")
	var old: SaveCodec.Result = SaveCodec.decode(JSON.stringify(envelope))
	assert_eq(old.error, "")
	assert_eq(old.state.survivors[0].look.to_dict(), state.survivors[0].look.to_dict())
