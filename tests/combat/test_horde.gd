extends GutTest

var _config: HordeConfig
var _grid: NavGrid


func before_each() -> void:
	_config = HordeConfig.new()
	_config.speed_jitter = 0.0
	_grid = NavGrid.new(20, 20, 1.0, Vector2(-10, -10))


func _horde(capacity: int = 16) -> Horde:
	var horde: Horde = Horde.new(_config, _grid, capacity, 1)
	return horde


func test_spawn_respects_capacity_and_walls() -> void:
	_grid.set_blocked_rect(Rect2i(0, 0, 1, 1))
	var horde: Horde = _horde(2)
	assert_false(horde.spawn(Vector2(-9.5, -9.5)), "blocked cell")
	assert_true(horde.spawn(Vector2(0, 0)))
	assert_true(horde.spawn(Vector2(1, 0)))
	assert_false(horde.spawn(Vector2(2, 0)), "full")
	assert_eq(horde.count, 2)


func test_agents_close_in_on_target() -> void:
	var horde: Horde = _horde()
	var target: Vector2 = Vector2(5, 5)
	horde.spawn(Vector2(-8, -8))
	horde.recompute_flow([_grid.world_to_cell(target)] as Array[Vector2i])
	var start: float = horde.positions[0].distance_to(target)
	for i: int in 120:
		horde.update(1.0 / 60.0, target)
	assert_lt(horde.positions[0].distance_to(target), start - 3.0, "moved at least 3 m closer in 2 s")


func test_agents_never_enter_blocked_cells() -> void:
	_grid.set_blocked_rect(Rect2i(9, 0, 2, 18))  # wall with a gap at the bottom
	var horde: Horde = _horde()
	for i: int in 8:
		horde.spawn(Vector2(-6 + i * 0.4, -6))
	var target: Vector2 = Vector2(6, -6)
	horde.recompute_flow([_grid.world_to_cell(target)] as Array[Vector2i])
	for step: int in 600:
		horde.update(1.0 / 60.0, target)
		for a: int in horde.count:
			assert_true(_grid.is_walkable_world(horde.positions[a]), "agent %d inside wall at step %d" % [a, step])
			if not _grid.is_walkable_world(horde.positions[a]):
				return


func test_separation_spreads_stacked_agents() -> void:
	var horde: Horde = _horde()
	for i: int in 4:
		horde.spawn(Vector2(0.01 * i, 0))
	var target: Vector2 = Vector2(0, 0)
	horde.recompute_flow([_grid.world_to_cell(target)] as Array[Vector2i])
	for step: int in 60:
		horde.update(1.0 / 60.0, target)
	var min_d: float = INF
	for a: int in horde.count:
		for b: int in range(a + 1, horde.count):
			min_d = minf(min_d, horde.positions[a].distance_to(horde.positions[b]))
	assert_gt(min_d, _config.radius, "stacked agents pushed apart")


func test_attacks_when_in_range() -> void:
	var horde: Horde = _horde()
	horde.spawn(Vector2(0.5, 0))
	horde.recompute_flow([Vector2i(10, 10)] as Array[Vector2i])
	for step: int in 150:
		horde.update(1.0 / 60.0, Vector2(0, 0))
	assert_between(horde.hits_on_target, 2, 3, "about one hit per attack_interval over 2.5 s")


func test_apply_damage_removes_dead_and_keeps_survivors() -> void:
	var horde: Horde = _horde()
	for i: int in 5:
		horde.spawn(Vector2(i, 0))
	horde.hp[4] = 10
	# Kill agents 1, 3 and 4 (4 is the last slot; must not corrupt swap-removal).
	var died: int = horde.apply_damage(PackedInt32Array([1, 3, 4]), 3)
	assert_eq(died, 2, "agent 4 has 10 hp and survives")
	assert_eq(horde.count, 3)
	assert_eq(horde.kills, 2)
	var xs: Array[float] = []
	for a: int in horde.count:
		xs.append(horde.positions[a].x)
	xs.sort()
	assert_eq(xs, [0.0, 2.0, 4.0] as Array[float])
