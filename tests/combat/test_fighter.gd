extends GutTest
## Phase 1 step 1.3: the player in danger (FighterHealth, armor, zombie hits).

const FIGHTER: FighterConfig = preload("res://data/combat/player_fighter.tres")
const BITE_VEST: ArmorConfig = preload("res://data/armor/bite_vest.tres")
const BALLISTIC: ArmorConfig = preload("res://data/armor/ballistic_vest.tres")
const HEAVY: ArmorConfig = preload("res://data/armor/heavy_armor.tres")
const MASK: ArmorConfig = preload("res://data/armor/filter_mask.tres")
const RUNNER: EnemyConfig = preload("res://data/enemies/runner.tres")

var _rng: RandomNumberGenerator


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 21


func test_hits_go_through_the_armor() -> void:
	var bare: FighterHealth = FighterHealth.new(FIGHTER)
	bare.take_hit(10, _rng)
	assert_eq(bare.hp, 90)
	var vest: FighterHealth = FighterHealth.new(FIGHTER, [BITE_VEST])
	vest.take_hit(20, _rng)
	assert_eq(vest.hp, 100 - roundi(20 * BITE_VEST.melee_mul))


func test_a_bite_vest_cuts_bites() -> void:
	var tough: FighterConfig = FIGHTER.duplicate()
	tough.max_hp = 100000  # survives 2000 hits
	var bare: FighterHealth = FighterHealth.new(tough)
	var vest: FighterHealth = FighterHealth.new(tough, [BITE_VEST])
	for i: int in 2000:
		bare.take_hit(1, _rng)
		vest.take_hit(1, _rng)
	assert_almost_eq(bare.bites / 2000.0, FIGHTER.bite_chance, 0.03)
	assert_almost_eq(vest.bites / 2000.0, FIGHTER.bite_chance * BITE_VEST.bite_mul, 0.02)


func test_zero_hp_downs_then_kills_after_downed_sec() -> void:
	var h: FighterHealth = FighterHealth.new(FIGHTER)
	h.take_hit(500, _rng)
	assert_eq(h.state, FighterHealth.State.DOWNED)
	assert_false(h.is_alive())
	h.take_hit(10, _rng)
	assert_eq(h.hp, 0, "no more damage while down")
	h.step(FIGHTER.downed_sec - 0.1)
	assert_eq(h.state, FighterHealth.State.DOWNED)
	h.step(0.2)
	assert_eq(h.state, FighterHealth.State.DEAD)


func test_a_revive_brings_back_a_quarter() -> void:
	var h: FighterHealth = FighterHealth.new(FIGHTER)
	h.take_hit(500, _rng)
	h.revive()
	assert_true(h.is_alive())
	assert_eq(h.hp, FIGHTER.max_hp / 4)


func test_gas_hurts_over_time_and_a_mask_stops_it() -> void:
	var bare: FighterHealth = FighterHealth.new(FIGHTER)
	var masked: FighterHealth = FighterHealth.new(FIGHTER, [MASK])
	for i: int in 60:  # 1 s at 60 FPS: fractions must add up
		bare.take_dot(FIGHTER.gas_dps, 1.0 / 60.0, &"gas")
		masked.take_dot(FIGHTER.gas_dps, 1.0 / 60.0, &"gas")
	assert_almost_eq(bare.hp, 100 - roundi(FIGHTER.gas_dps), 1)
	assert_eq(masked.hp, 100)


func test_own_blast_is_scaled_and_armor_helps() -> void:
	var h: FighterHealth = FighterHealth.new(FIGHTER)
	h.take_blast(40, true)
	assert_eq(h.hp, 100 - roundi(40 * FIGHTER.self_blast_mul))
	var armored: FighterHealth = FighterHealth.new(FIGHTER, [BALLISTIC])
	armored.take_blast(40, false)
	assert_eq(armored.hp, 100 - roundi(40 * BALLISTIC.blast_mul))


func test_one_piece_per_slot_and_heavy_armor_slows() -> void:
	var h: FighterHealth = FighterHealth.new(FIGHTER, [HEAVY, BITE_VEST, MASK])
	assert_eq(h.wearing.size(), 2, "the bite vest shares the armor slot")
	assert_almost_eq(h.speed_mul(), HEAVY.speed_mul, 0.001)
	assert_almost_eq(h.weight_kg(), HEAVY.weight_kg + MASK.weight_kg, 0.001)


func test_invulnerable_takes_nothing() -> void:
	var h: FighterHealth = FighterHealth.new(FIGHTER)
	h.invulnerable = true
	h.take_hit(500, _rng)
	h.take_dot(100.0, 1.0, &"fire")
	assert_eq(h.hp, 100)
	assert_eq(h.bites, 0, "no bites either")
	assert_true(h.is_alive())


func test_zombie_hits_carry_their_type_damage() -> void:
	var grid: NavGrid = NavGrid.new(10, 10)
	var cfg: HordeConfig = HordeConfig.new()
	cfg.types = [RUNNER] as Array[EnemyConfig]
	var horde: Horde = Horde.new(cfg, grid, 2)
	horde.spawn(Vector2(5.5, 5.5), 0)
	horde.recompute_flow([Vector2i(5, 5)] as Array[Vector2i])
	for i: int in 40:
		horde.update(0.05, Vector2(5.9, 5.5))
	assert_false(horde.target_hits.is_empty())
	assert_eq(horde.target_hits[0], RUNNER.hit_damage)


func test_gas_cloud_removed_when_it_burns() -> void:
	var g: GasField = GasField.new()
	g.add(Vector2.ZERO, 3.0, 8.0)
	g.add(Vector2(10, 0), 3.0, 8.0)
	g.remove(0)
	assert_eq(g.count(), 1)
	assert_eq(g.centers[0], Vector2(10, 0))
