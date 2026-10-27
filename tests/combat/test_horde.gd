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


func test_walk_phase_follows_distance() -> void:
	var horde: Horde = _horde()
	horde.spawn(Vector2(-8, 0))
	horde.anim_time[0] = 0.0
	var target: Vector2 = Vector2(8, 0)
	horde.recompute_flow([_grid.world_to_cell(target)] as Array[Vector2i])
	var travelled: float = 0.0
	for step: int in 30:
		var before: Vector2 = horde.positions[0]
		horde.update(1.0 / 60.0, target)
		travelled += horde.positions[0].distance_to(before)
	assert_eq(horde.anim[0], Horde.Anim.WALK)
	assert_almost_eq(horde.anim_time[0], fposmod(travelled / _config.walk_stride, 1.0), 0.001)
	assert_gt(horde.heading[0].x, 0.9, "faces where it walks")


func test_attack_plays_then_returns_to_walk() -> void:
	var horde: Horde = _horde()
	horde.spawn(Vector2(0.5, 0))
	horde.recompute_flow([Vector2i(10, 10)] as Array[Vector2i])
	var attacked: bool = false
	for step: int in 60:
		horde.update(1.0 / 60.0, Vector2(0, 0))
		attacked = attacked or horde.anim[0] == Horde.Anim.ATTACK
	assert_true(attacked, "attack clip started")
	assert_lt(horde.heading[0].x, -0.9, "turns to face the target while standing")
	for step: int in ceili(_config.attack_anim_sec * 60.0) + 2:
		horde.update(1.0 / 60.0, Vector2(0, 0))
		if horde.anim[0] == Horde.Anim.WALK:
			pass_test("back to walk")
			return
	fail_test("still attacking after attack_anim_sec")


func test_kill_moves_animation_state_with_the_agent() -> void:
	var horde: Horde = _horde()
	for i: int in 3:
		horde.spawn(Vector2(i, 0))
	horde.anim[2] = Horde.Anim.ATTACK
	horde.anim_time[2] = 0.3
	horde.variant[2] = 1
	horde.kill(0)
	assert_eq(horde.positions[0], Vector2(2, 0))
	assert_eq(horde.anim[0], Horde.Anim.ATTACK)
	assert_almost_eq(horde.anim_time[0], 0.3, 0.0001)
	assert_eq(horde.variant[0], 1)


func test_hit_slows_flinches_and_queues_events() -> void:
	_config.hp = 3
	var horde: Horde = _horde()
	horde.spawn(Vector2(2, 0))
	horde.spawn(Vector2(4, 0))
	horde.apply_damage(PackedInt32Array([0]), 1, Vector2(0, 0))
	assert_eq(horde.anim[0], Horde.Anim.FLINCH)
	assert_almost_eq(horde.slow_left[0], _config.hit_slow_sec, 0.001)
	assert_eq(horde.hit_points.size(), 1)
	assert_eq(horde.hit_dirs[0], Vector2(1, 0), "away from the shooter")
	for i: int in 5:
		horde.apply_damage(PackedInt32Array([1]), 0, Vector2(0, 0))
	assert_almost_eq(horde.slow_left[1], _config.hit_slow_cap_sec, 0.001, "stacking is capped")
	assert_true(horde.deaths.is_empty())


func test_slowed_agent_moves_slower() -> void:
	var a: Horde = _horde()
	var b: Horde = _horde()
	var target: Vector2 = Vector2(8, 0)
	for h: Horde in [a, b]:
		h.spawn(Vector2(-8, 0))
		h.recompute_flow([_grid.world_to_cell(target)] as Array[Vector2i])
		for i: int in 30:  # reach full speed first
			h.update(1.0 / 60.0, target)
	b.slow_left[0] = 10.0
	var start_a: Vector2 = a.positions[0]
	var start_b: Vector2 = b.positions[0]
	for i: int in 30:
		a.update(1.0 / 60.0, target)
		b.update(1.0 / 60.0, target)
	assert_lt(b.positions[0].distance_to(start_b), a.positions[0].distance_to(start_a) * 0.85)


func test_death_event_carries_corpse_data() -> void:
	var horde: Horde = _horde()
	horde.spawn(Vector2(3, 0))
	horde.variant[0] = 1
	horde.apply_damage(PackedInt32Array([0]), 99, Vector2(3, -5), true)
	assert_eq(horde.deaths.size(), 1)
	var d: Horde.Death = horde.deaths[0]
	assert_eq(d.position, Vector2(3, 0))
	assert_eq(d.variant, 1)
	assert_true(d.blast)
	assert_eq(d.push, Vector2(0, 1))
	horde.clear_events()
	assert_true(horde.deaths.is_empty() and horde.hit_points.is_empty())


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


func test_dense_crowd_cannot_push_through_thin_wall() -> void:
	# Regression (Copilot, PR #2): 50 neighbours summed a push of ~1.7 m in one frame,
	# skipping over a 1-cell wall because only the destination cell was checked.
	_grid = NavGrid.new(20, 20, 1.0, Vector2.ZERO)
	_grid.set_blocked_rect(Rect2i(6, 0, 1, 20))
	var horde: Horde = _horde(64)
	for i: int in 50:
		horde.spawn(Vector2(5.8, 5.5 + (i % 2) * 0.0001))
	horde.spawn(Vector2(5.9, 5.5))
	var target: Vector2 = Vector2(2.0, 5.5)
	horde.recompute_flow([_grid.world_to_cell(target)] as Array[Vector2i])
	for step: int in 30:
		horde.update(1.0 / 60.0, target)
		for a: int in horde.count:
			if horde.positions[a].x >= 6.0:
				fail_test("agent %d crossed the wall to x=%.2f at step %d" % [a, horde.positions[a].x, step])
				return
	pass_test("nobody crossed")
