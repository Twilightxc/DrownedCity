extends GutTest
## Phase 1 step 1.4: game feel (kill chain, shake, time control, knock-back).

const ARMORED: EnemyConfig = preload("res://data/enemies/armored.tres")
const WALKER: EnemyConfig = preload("res://data/enemies/walker.tres")


func test_kill_chain_grows_scores_and_breaks() -> void:
	var c: KillChain = KillChain.new(2.0)
	c.add_kills(1)
	c.step(1.0)
	c.add_kills(2)
	assert_eq(c.chain, 3)
	assert_eq(c.score, 1 + 2 + 3, "each kill scores the chain length")
	c.step(2.1)
	assert_eq(c.chain, 0, "the window ran out")
	assert_eq(c.best, 3)
	c.add_kills(1)
	assert_eq(c.chain, 1)


func test_chain_score_per_kill_is_capped() -> void:
	var c: KillChain = KillChain.new(2.0, 10)
	c.add_kills(20)
	assert_eq(c.score, 55 + 10 * 10, "1..10, then 10 each")


func test_shake_is_bounded_and_decays() -> void:
	var s: ScreenShake = ScreenShake.new()
	s.add(5.0)
	assert_eq(s.trauma, 1.0, "clamped")
	var biggest: float = 0.0
	for i: int in 30:
		biggest = maxf(biggest, s.step(1.0 / 60.0, 2.0, 0.5).length())
	assert_lte(biggest, 0.5 * sqrt(2.0) + 0.001)
	for i: int in 120:
		s.step(1.0 / 60.0, 2.0, 0.5)
	assert_eq(s.trauma, 0.0)
	assert_eq(s.step(0.016, 2.0, 0.5), Vector2.ZERO)


func test_time_control_takes_the_slowest_request_and_lets_go() -> void:
	var t: TimeControl = TimeControl.new()
	add_child_autofree(t)
	t.request(0.5, 0.05)
	t.request(0.1, 0.02)
	assert_almost_eq(Engine.time_scale, 0.1, 0.001)
	OS.delay_msec(30)
	t._process(0.0)
	assert_almost_eq(Engine.time_scale, 0.5, 0.001, "the shorter one ended")
	OS.delay_msec(30)
	t._process(0.0)
	assert_eq(Engine.time_scale, 1.0)
	assert_false(t.active())


func test_knockback_shoves_along_the_push_and_heavy_types_barely_move() -> void:
	var grid: NavGrid = NavGrid.new(30, 10)
	var cfg: HordeConfig = HordeConfig.new()
	cfg.types = [WALKER, ARMORED] as Array[EnemyConfig]
	cfg.speed = 0.0  # only the shove moves them
	var h: Horde = Horde.new(cfg, grid, 4)
	h.spawn(Vector2(10.5, 2.5), 0, Horde.State.SUSPICIOUS)
	h.spawn(Vector2(10.5, 7.5), 1, Horde.State.SUSPICIOUS)
	var from: Vector2 = Vector2(5.5, 5.0)
	h.apply_hits(PackedInt32Array([0, 1]), PackedInt32Array([1, 1]), from, false, 0.0, PackedFloat32Array([4.0, 4.0]))
	var before: PackedVector2Array = h.positions.duplicate()
	for i: int in 30:
		h.update(1.0 / 60.0, Vector2(29.5, 5.0), false)
	var walker_moved: float = h.positions[0].distance_to(before[0])
	var armored_moved: float = h.positions[1].distance_to(before[1])
	assert_gt(walker_moved, 0.25, "shoved")
	assert_gt((h.positions[0] - before[0]).dot(before[0] - from), 0.0, "away from the shooter")
	assert_lt(armored_moved, walker_moved * 0.5, "armored barely moves")
	assert_eq(h.knock[0], Vector2.ZERO, "faded out")
