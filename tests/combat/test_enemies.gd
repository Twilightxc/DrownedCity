extends GutTest
## Phase 1 step 1.2: zombie types and perception (GDD §9).

const WALKER: EnemyConfig = preload("res://data/enemies/walker.tres")
const RUNNER: EnemyConfig = preload("res://data/enemies/runner.tres")
const ARMORED: EnemyConfig = preload("res://data/enemies/armored.tres")
const BLOATER: EnemyConfig = preload("res://data/enemies/bloater.tres")
const PISTOL: WeaponConfig = preload("res://data/weapons/pistol_9mm.tres")
const AR: WeaponConfig = preload("res://data/weapons/ar_556.tres")
const DMR: WeaponConfig = preload("res://data/weapons/dmr_308.tres")

var _grid: NavGrid
var _config: HordeConfig


func before_each() -> void:
	_grid = NavGrid.new(40, 40)
	_config = HordeConfig.new()
	_config.speed_jitter = 0.0
	_config.types = [WALKER, RUNNER, ARMORED, BLOATER] as Array[EnemyConfig]


func _horde(cap: int = 8) -> Horde:
	return Horde.new(_config, _grid, cap, 5)


func _run(h: Horde, seconds: float, target: Vector2, perceive: bool = true) -> void:
	h.recompute_flow([_grid.world_to_cell(target)] as Array[Vector2i])
	for i: int in int(seconds * 20.0):
		if perceive:
			h.perceive(target, 0.05)
		h.update(0.05, target)


func test_types_set_hp_armor_and_speed() -> void:
	var h: Horde = _horde()
	for t: int in 4:
		h.spawn(Vector2(5.5 + t * 3, 5.5), t)
	assert_eq(Array(h.hp.slice(0, 4)), [100, 60, 150, 250])
	assert_eq(h.armor[2], WeaponConfig.Armor.M)
	assert_almost_eq(h.speed_scale[1], 1.8, 0.001, "runner")
	assert_almost_eq(h.speed_scale[3], 0.6, 0.001, "bloater")


func test_the_spawn_mix_is_followed() -> void:
	_config.spawn_mix = PackedFloat32Array([0.7, 0.2, 0.1, 0.0])
	var h: Horde = _horde()
	var n: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	for i: int in 2000:
		n[h.pick_type()] += 1
	assert_almost_eq(n[0] / 2000.0, 0.7, 0.05)
	assert_almost_eq(n[1] / 2000.0, 0.2, 0.05)
	assert_eq(n[3], 0, "weight 0 never spawns")


func test_armored_against_each_gun() -> void:
	var m: int = ARMORED.armor
	assert_true(Ballistics.stops_bullet(PISTOL.armor_pen, m), "pistol L stops in M armor")
	assert_eq(Ballistics.hit_damage(PISTOL.damage, 1.0, 0, m, PISTOL), roundi(30 * 0.25))
	assert_eq(Ballistics.hit_damage(AR.damage, 1.0, 0, m, AR), roundi(34 * 0.75), "equal pen")
	assert_eq(Ballistics.hit_damage(DMR.damage, 1.0, 0, m, DMR), 70, "DMR H: full")


func test_armored_isnt_slowed_by_hits() -> void:
	var h: Horde = _horde()
	h.spawn(Vector2(5.5, 5.5), 2)
	h.spawn(Vector2(9.5, 5.5), 0)
	h.apply_damage(PackedInt32Array([0, 1]), 1)
	assert_eq(h.slow_left[0], 0.0, "armored")
	assert_gt(h.slow_left[1], 0.0, "walker")


func test_a_far_noise_is_not_heard_and_a_near_one_makes_it_walk_there() -> void:
	var h: Horde = _horde()
	h.spawn(Vector2(5.5, 5.5), 0, Horde.State.DORMANT)
	h.hear(Vector2(30.5, 5.5), 10.0)
	assert_eq(h.state[0], Horde.State.DORMANT, "25 m away, 10 m noise")
	var noise_at: Vector2 = Vector2(15.5, 5.5)
	h.hear(noise_at, 15.0)
	assert_eq(h.state[0], Horde.State.SUSPICIOUS)
	_run(h, 8.0, Vector2(35.5, 35.5), false)
	assert_lt(h.positions[0].distance_to(noise_at), 1.5, "walked to the noise and stopped there")
	assert_eq(h.hits_on_target, 0, "suspicious zombies don't attack")


func test_a_close_noise_makes_it_hunt_at_once() -> void:
	var h: Horde = _horde()
	h.spawn(Vector2(5.5, 5.5), 0, Horde.State.DORMANT)
	h.hear(Vector2(7.5, 5.5), 20.0)  # 2 m < 0.35 × 20 m
	assert_eq(h.state[0], Horde.State.HUNTING)


func test_sight_makes_it_hunt_and_losing_sight_makes_it_suspicious_then_calm() -> void:
	var h: Horde = _horde()
	h.spawn(Vector2(5.5, 5.5), 0, Horde.State.DORMANT)
	h.perceive(Vector2(10.5, 5.5), 0.05)
	assert_eq(h.state[0], Horde.State.HUNTING, "5 m, line of sight")
	_grid.set_blocked_rect(Rect2i(7, 0, 1, 40))  # a wall between them now
	var p: Vector2 = h.positions[0]
	for i: int in int((_config.lose_sec + 0.2) * 20.0):
		h.perceive(Vector2(10.5, 5.5), 0.05)
	assert_eq(h.state[0], Horde.State.SUSPICIOUS, "lost sight for lose_sec")
	for i: int in int((_config.suspicious_sec + 0.2) * 20.0):
		h.perceive(Vector2(10.5, 5.5), 0.05)
	assert_eq(h.state[0], Horde.State.DORMANT, "found nothing: calms down")
	assert_eq(h.positions[0], p)


func test_runners_see_further() -> void:
	var h: Horde = _horde()
	h.spawn(Vector2(5.5, 5.5), 0, Horde.State.DORMANT)
	h.spawn(Vector2(5.5, 7.5), 1, Horde.State.DORMANT)
	h.perceive(Vector2(16.5, 5.5), 0.05)  # 11 m: past sight_m 10, inside the runner's 12
	assert_eq(h.state[0], Horde.State.DORMANT)
	assert_eq(h.state[1], Horde.State.HUNTING)


func test_deaths_carry_type_and_body_scale() -> void:
	var h: Horde = _horde()
	h.spawn(Vector2(5.5, 5.5), 3)
	h.apply_damage(PackedInt32Array([0]), 999)
	assert_eq(h.deaths[0].type, 3)
	assert_eq(h.deaths[0].scale, BLOATER.scale)


func test_gas_clouds_fade_out_and_cap() -> void:
	var g: GasField = GasField.new()
	g.add(Vector2(0, 0), 3.0, 8.0)
	assert_almost_eq(g.strength_at(Vector2(0, 0)), 1.0, 0.001)
	assert_eq(g.strength_at(Vector2(5, 0)), 0.0)
	g.update(7.0)
	assert_almost_eq(g.strength_at(Vector2(0, 0)), 0.5, 0.001, "thins over the last 2 s")
	g.update(1.5)
	assert_eq(g.count(), 0)
	for i: int in GasField.CAP + 2:
		g.add(Vector2(i, 0), 3.0, 8.0 + i)
	assert_eq(g.count(), GasField.CAP)
