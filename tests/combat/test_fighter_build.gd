extends GutTest
## 1.6: a survivor's build on the fighter (CITIZENS_1_6 §8) and what a night leaves on the survivor.

const MATE_LOADOUT: LoadoutConfig = preload("res://data/weapons/teammate_ar_loadout.tres")


func _mods(pairs: Array) -> StatMods:
	var m: StatMods = StatMods.new()
	for p: Array in pairs:
		m.push_for(StringName(p[0]), str(p[1]), float(p[2]), PackedStringArray(p[3]) if p.size() > 3 else PackedStringArray())
	return m


func _fighter(f: SpikePlayer, grid: NavGrid, cam: Camera3D) -> SpikePlayer:
	var marker: Node3D = Node3D.new()
	marker.name = "AimMarker"
	f.add_child(marker)
	add_child_autofree(f)
	f.setup(grid, Horde.new(HordeConfig.new(), grid, 4), cam, 0.0)
	f.position = Vector3(10, 0, 10)
	return f


func test_no_survivor_changes_nothing() -> void:
	var b: FighterBuild = FighterBuild.new()
	assert_eq(b.hp(100), 100)
	assert_eq(b.stamina_max(100.0), 100.0)
	assert_eq(b.spread("ar"), 1.0)
	assert_eq(b.reload_time("ar"), 1.0)
	assert_eq(b.revive_rate(), 1.0)
	assert_eq(b.extra_grenades(), 0)


func test_health_takes_max_hp_and_damage_cuts() -> void:
	var h: FighterHealth = FighterHealth.new(FighterConfig.new())
	h.apply_build(FighterBuild.new(_mods([["max_hp", "add", 84], ["melee_damage_taken", "mul", -0.2]])))
	assert_eq(h.max_hp, 184)
	assert_eq(h.hp, 184)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	h.take_hit(50, rng)
	assert_eq(h.hp, 184 - 40)
	assert_almost_eq(h.hp_frac(), 144.0 / 184.0, 0.001)


func test_motion_takes_stamina_and_quiet_steps() -> void:
	var cfg: MovementConfig = MovementConfig.new()
	var m: FighterMotion = FighterMotion.new(cfg)
	m.apply_build(FighterBuild.new(_mods([["max_stamina", "add", 21], ["step_noise", "mul", -0.3], ["dodge_stamina", "mul", -0.5]])))
	assert_eq(m.stamina, 121.0)
	assert_almost_eq(m.step_noise_m(), cfg.step_noise_m[0] * 0.7, 0.001)
	assert_true(m.try_roll(Vector2.RIGHT))
	assert_almost_eq(m.stamina, 121.0 - cfg.roll_stamina * 0.5, 0.001)


func test_a_tired_hungry_survivor_has_less_stamina_in_the_fight() -> void:
	var s: Survivor = Survivor.new(1, "Rosa", 7)
	s.needs.fatigue = 100.0
	s.needs.hunger = 60.0
	var b: FighterBuild = FighterBuild.new(BuildRules.mods(s))
	assert_almost_eq(b.stamina_max(100.0), 30.0, 0.001, "−50 % tired, −20 % hungry")


func test_guns_take_spread_by_class_reload_and_rate() -> void:
	var b: FighterBuild = FighterBuild.new(_mods([["spread", "mul", -0.2, ["pistol"]], ["sway", "mul", -0.25],
		["reload_speed", "mul", 0.5], ["rpm", "mul", 0.1]]))
	var pistol_cfg: WeaponConfig = WeaponConfig.new()
	pistol_cfg.weapon_class = "pistol"
	var shotgun_cfg: WeaponConfig = WeaponConfig.new()
	shotgun_cfg.weapon_class = "shotgun"
	var pistol: Gun = Gun.new(pistol_cfg)
	var shotgun: Gun = Gun.new(shotgun_cfg)
	pistol.apply_build(b)
	shotgun.apply_build(b)
	assert_almost_eq(pistol.spread_deg, pistol_cfg.spread_deg * 0.8 * 0.75, 0.0001)
	assert_almost_eq(shotgun.spread_deg, shotgun_cfg.spread_deg * 0.75, 0.0001, "Steady Hands skips shotguns")
	assert_almost_eq(pistol.reload_sec, pistol_cfg.reload_sec / 1.5, 0.0001)
	assert_almost_eq(b.rpm("ar"), 1.1, 0.0001)


func test_a_survivor_behind_a_fighter_brings_name_build_and_grenades() -> void:
	var cam: Camera3D = Camera3D.new()
	add_child_autofree(cam)
	var p: SpikePlayer = SpikePlayer.new()
	p.loadout = preload("res://data/weapons/spike_loadout.tres")
	_fighter(p, NavGrid.new(20, 20), cam)
	var before: int = p.grenade_count
	var s: Survivor = Survivor.new(1, "Mali", 3)
	s.status = "member"
	CommunityRules.pick_class(s, "grenadier")
	TraitRules.give(s, "athlete")
	p.set_survivor(s)
	assert_eq(p.display_name, "Mali")
	assert_eq(p.grenade_count, before + 2)
	assert_almost_eq(p.motion.stamina_max(), 120.0, 0.001, "Athlete +20 %")
	assert_eq(p.gun._build, p.build, "the guns too")


func test_a_medic_gets_a_downed_mate_up_twice_as_fast() -> void:
	var cam: Camera3D = Camera3D.new()
	add_child_autofree(cam)
	var grid: NavGrid = NavGrid.new(20, 20)
	var medic: SpikePlayer = _fighter(SpikePlayer.new(), grid, cam)
	var s: Survivor = Survivor.new(1, "Ana", 3)
	s.status = "member"
	CommunityRules.pick_class(s, "medic")
	medic.set_survivor(s)
	var mate_node: Teammate = Teammate.new()
	mate_node.loadout = MATE_LOADOUT
	var mate: Teammate = _fighter(mate_node, grid, cam) as Teammate
	mate.leader = medic
	mate.health.take_hit(999, RandomNumberGenerator.new())
	mate.interact(medic)
	mate._update_revive(mate.health.config.revive_sec * 0.25)
	assert_almost_eq(mate.revive_fill(), 0.5, 0.01)


func test_a_night_gives_xp_influence_and_counts_toward_hardened() -> void:
	var state: SimState = SimState.new()
	var s: Survivor = state.add_survivor("Mali", 3)  # no traits: Well Liked would change the influence
	SkillRules.setup(s, "farmer", SkillCatalog.load_default())
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var got: Dictionary = NightRules.apply(state, s, {"shots": 400, "kills": 30, "bites": 0, "won": true}, rng)
	assert_eq(int(got["levels"]["shooting"]), 1, "100 XP from shots, 60 from kills: level 1, 60 toward 2")
	assert_almost_eq(s.skills["shooting"].xp, 60.0, 0.001)
	assert_almost_eq(float(got["influence"]), 15.0 + 10.0, 0.001)
	assert_eq(s.counters["horde_nights"], 1)
	assert_false(bool(got["infected"]))
	for i: int in 4:
		NightRules.apply(state, s, {"won": true}, rng)
	assert_true("hardened" in s.traits)


func test_a_lost_night_counts_no_horde_night_and_bites_may_infect() -> void:
	var state: SimState = SimState.new_game(SimRules.new(), 9)
	var s: Survivor = state.survivors[0]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var got: Dictionary = NightRules.apply(state, s, {"kills": 2, "bites": 40, "won": false}, rng)
	assert_false(s.counters.has("horde_nights"))
	assert_true(bool(got["infected"]), "40 bites")
	assert_true(s.needs.infected())
