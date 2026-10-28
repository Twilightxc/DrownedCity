extends GutTest

var _fire: FireConfig
var _grid: NavGrid
var _rng: RandomNumberGenerator


func before_each() -> void:
	_fire = FireConfig.new()
	_grid = NavGrid.new(20, 20, 1.0, Vector2(-10, -10))
	_rng = RandomNumberGenerator.new()
	_rng.seed = 7


func _horde(capacity: int = 16) -> Horde:
	var config: HordeConfig = HordeConfig.new()
	config.speed_jitter = 0.0
	var horde: Horde = Horde.new(config, _grid, capacity, 1)
	horde.fire = _fire
	return horde


func test_ground_fire_cap_drops_the_oldest_cell() -> void:
	_fire.cell_cap = 2
	var gf: GroundFire = GroundFire.new(_fire, _grid)
	assert_true(gf.ignite(Vector2i(1, 1)))
	assert_true(gf.ignite(Vector2i(2, 1)))
	assert_true(gf.ignite(Vector2i(3, 1)))
	assert_eq(gf.active_count(), 2)
	assert_false(gf.is_burning(_grid.index_of(Vector2i(1, 1))), "oldest went out")
	assert_true(gf.is_burning(_grid.index_of(Vector2i(3, 1))))


func test_ground_fire_burns_out_and_skips_blocked_cells() -> void:
	var gf: GroundFire = GroundFire.new(_fire, _grid)
	_grid.set_blocked_rect(Rect2i(5, 5, 1, 1))
	assert_false(gf.ignite(Vector2i(5, 5)), "blocked")
	assert_false(gf.ignite(Vector2i(-1, 0)), "off the grid = water")
	gf.ignite(Vector2i(1, 1))
	var rev: int = gf.revision
	gf.update(_fire.cell_life_sec + 0.1)
	assert_eq(gf.active_count(), 0)
	assert_ne(gf.revision, rev, "flow field must recompute")


func test_flow_field_walks_around_a_burning_cell() -> void:
	var grid: NavGrid = NavGrid.new(7, 3, 1.0, Vector2.ZERO)
	var gf: GroundFire = GroundFire.new(_fire, grid)
	_fire.cell_cost = 6
	gf.ignite(Vector2i(3, 1))
	var flow: FlowField = FlowField.new(grid)
	flow.compute([Vector2i(0, 1)] as Array[Vector2i])
	assert_eq(flow.distance_at(Vector2i(6, 1)), 6, "plain BFS goes straight through")
	flow.compute([Vector2i(0, 1)] as Array[Vector2i], gf.cost)
	assert_eq(flow.distance_at(Vector2i(6, 1)), 8, "around via the side row (2 extra steps < 6)")
	assert_gt(absf(flow.direction_at(grid.index_of(Vector2i(4, 1))).y), 0.5, "steers off the fire row (either side)")


func test_burning_kills_with_a_charred_corpse_and_no_blood() -> void:
	var horde: Horde = _horde()
	horde.spawn(Vector2(0.5, 0.5))
	horde.ignite(0)
	for i: int in 40:  # 4 s at 0.1 s
		horde.spatial.rebuild(horde.positions, horde.count)
		horde.update_fire(0.1)
	assert_eq(horde.count, 0, "hp 3 at 1 per 0.5 s tick")
	assert_eq(horde.deaths.size(), 1)
	assert_true(horde.deaths[0].burned)
	assert_eq(horde.hit_points.size(), 0, "burn ticks don't bleed")


func test_water_puts_fire_out() -> void:
	var horde: Horde = _horde()
	horde.spawn(Vector2(0.5, 0.5))
	horde.ignite(0)
	horde.positions[0] = Vector2(-30, 0)  # off the roof
	horde.spatial.rebuild(horde.positions, horde.count)
	horde.update_fire(0.1)
	assert_eq(horde.burn_left[0], 0.0)


func test_fire_spreads_to_a_touching_zombie() -> void:
	_fire.spread_chance_per_sec = 1000.0  # certain within one step
	var horde: Horde = _horde()
	horde.spawn(Vector2(0.5, 0.5))
	horde.spawn(Vector2(0.9, 0.5))
	horde.spawn(Vector2(5.5, 5.5))
	horde.ignite(0)
	horde.spatial.rebuild(horde.positions, horde.count)
	horde.update_fire(0.05)
	assert_gt(horde.burn_left[1], 0.0, "neighbour caught")
	assert_eq(horde.burn_left[2], 0.0, "far one didn't")


func test_ground_fire_lights_a_zombie_standing_in_it() -> void:
	var horde: Horde = _horde()
	horde.ground_fire = GroundFire.new(_fire, _grid)
	horde.ground_fire.ignite(_grid.world_to_cell(Vector2(0.5, 0.5)))
	horde.spawn(Vector2(0.5, 0.5))
	horde.spatial.rebuild(horde.positions, horde.count)
	horde.update_fire(0.05)
	assert_gt(horde.burn_left[0], 0.0)


func test_no_fire_config_means_nothing_burns() -> void:
	var horde: Horde = _horde()
	horde.fire = null
	horde.spawn(Vector2(0.5, 0.5))
	horde.ignite(0)
	assert_eq(horde.burn_left[0], 0.0)


func test_spot_fire_burns_one_part_without_spreading_or_lurching() -> void:
	_fire.spread_chance_per_sec = 1000.0
	var horde: Horde = _horde()
	horde.spawn(Vector2(0.5, 0.5))
	horde.spawn(Vector2(0.9, 0.5))
	horde.ignite_spot(0)
	assert_gt(horde.burn_left[0], 0.0)
	assert_between(horde.burn_spot[0] - 1, Horde.SPOT_PARTS.x, Horde.SPOT_PARTS.y, "a body part, not the pelvis")
	horde.spatial.rebuild(horde.positions, horde.count)
	horde.update_fire(0.05)
	assert_eq(horde.burn_left[1], 0.0, "spot fires don't spread")
	assert_eq(horde.burning_count(), 0)
	assert_eq(horde.spot_burning_count(), 1)


func test_spot_fire_death_is_not_charred() -> void:
	_fire.spot_burn_sec = 10.0
	var horde: Horde = _horde()
	horde.spawn(Vector2(0.5, 0.5))
	horde.ignite_spot(0)
	for i: int in 40:
		horde.spatial.rebuild(horde.positions, horde.count)
		horde.update_fire(0.1)
	assert_eq(horde.deaths.size(), 1)
	assert_false(horde.deaths[0].burned, "only a spot burned: no charred corpse")


func test_full_fire_overrides_a_spot_and_never_shrinks_back() -> void:
	var horde: Horde = _horde()
	horde.spawn(Vector2(0.5, 0.5))
	horde.ignite_spot(0)
	horde.ignite(0)
	assert_eq(horde.burn_spot[0], 0, "whole body now")
	horde.ignite_spot(0)
	assert_eq(horde.burn_spot[0], 0, "a frag spark doesn't turn a full fire into a spot")
	assert_eq(horde.burn_left[0], _fire.burn_sec)
