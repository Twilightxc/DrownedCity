extends GutTest
## Phase 1 step 1.5: waves and barricades.

const ARENA: ArenaConfig = preload("res://data/combat/arena_roof.tres")


func _arena(waves: Array) -> ArenaConfig:
	var a: ArenaConfig = ArenaConfig.new()
	a.alive_cap = 10
	var list: Array[WaveConfig] = []
	for w: Array in waves:
		var wc: WaveConfig = WaveConfig.new()
		wc.counts = PackedInt32Array(w[0])
		wc.entrances = PackedInt32Array([0, 1])
		wc.spawn_per_sec = 100.0
		wc.break_before_sec = w[1]
		list.append(wc)
	a.waves = list
	return a


func test_calm_then_wave_then_calm_then_won() -> void:
	var d: WaveDirector = WaveDirector.new(_arena([[[3, 1], 2.0], [[2, 0], 1.0]]), 1)
	assert_eq(d.phase, WaveDirector.Phase.CALM)
	assert_eq(d.step(1.0, 0).size(), 0, "calm: nothing yet")
	d.step(1.1, 0)
	assert_eq(d.phase, WaveDirector.Phase.WAVE)
	var spawned: Array[Vector2i] = d.step(0.1, 0)
	assert_eq(spawned.size(), 4, "the whole wave fits under the cap")
	var types: PackedInt32Array = PackedInt32Array([0, 0])
	for r: Vector2i in spawned:
		types[r.x] += 1
		assert_true(r.y in [0, 1], "from the wave's entrances")
	assert_eq(types, PackedInt32Array([3, 1]))
	d.step(0.1, 4)
	assert_eq(d.phase, WaveDirector.Phase.WAVE, "zombies still alive")
	d.step(0.1, 0)
	assert_eq(d.phase, WaveDirector.Phase.CALM, "cleared: next calm")
	assert_eq(d.wave, 1)
	d.step(1.1, 0)
	d.step(0.1, 0)
	d.step(0.1, 0)
	assert_eq(d.phase, WaveDirector.Phase.WON)


func test_a_start_wave_skips_the_earlier_waves_and_is_clamped() -> void:
	var a: ArenaConfig = _arena([[[3, 0], 1.0], [[0, 2], 1.0], [[1, 1], 1.0]])
	var d: WaveDirector = WaveDirector.new(a, 1, 1)
	assert_eq(d.wave, 1)
	d.step(1.1, 0)
	assert_eq(d.remaining, PackedInt32Array([0, 2]), "wave 2's mix")
	assert_eq(WaveDirector.new(a, 1, 9).wave, 2, "past the end: the last wave")
	assert_eq(WaveDirector.new(a, 1, -3).wave, 0)


func test_the_alive_cap_holds_spawns_back_and_refunds_come_back() -> void:
	var d: WaveDirector = WaveDirector.new(_arena([[[30, 0], 0.0]]), 2)
	d.step(0.01, 0)
	var first: Array[Vector2i] = d.step(1.0, 0)
	assert_eq(first.size(), 10, "cap 10")
	assert_eq(d.step(1.0, 10).size(), 0, "roof full")
	d.refund(0)
	assert_eq(d.left_to_spawn(), 21, "the refunded one is back in the queue")


func test_barricade_blocks_until_broken_and_clears_its_cost() -> void:
	var grid: NavGrid = NavGrid.new(10, 10)
	var b: Barricades = Barricades.new(grid, 8)
	var id: int = b.add([Vector2i(3, 3), Vector2i(4, 3)] as Array[Vector2i], 30)
	var i: int = grid.index_of(Vector2i(3, 3))
	assert_true(b.solid(i))
	assert_eq(b.cost[i], 8)
	var rev: int = b.revision
	assert_false(b.damage(id, 20))
	assert_true(b.damage(id, 20), "the hit that brings it down")
	assert_false(b.solid(i))
	assert_eq(b.cost[i], 0)
	assert_gt(b.revision, rev, "the flow field must be recomputed")


func test_hunters_tear_a_barricade_down_to_reach_the_target() -> void:
	var grid: NavGrid = NavGrid.new(12, 3)
	var b: Barricades = Barricades.new(grid, 8)
	b.add([Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2)] as Array[Vector2i], 40)  # a full wall across
	var cfg: HordeConfig = HordeConfig.new()
	var h: Horde = Horde.new(cfg, grid, 4)
	h.barricades = b
	h.spawn(Vector2(1.5, 1.5))
	h.spawn(Vector2(2.5, 1.5))
	var target: Vector2 = Vector2(10.5, 1.5)
	var crossed: bool = false
	for i: int in 400:  # 20 s
		if i % 5 == 0:
			h.recompute_flow([grid.world_to_cell(target)] as Array[Vector2i])
		h.update(0.05, target)
		if not b.standing(0):
			for a: int in h.count:
				crossed = crossed or h.positions[a].x > 6.0
	assert_false(b.standing(0), "torn down")
	assert_true(crossed, "then walked through")


func test_roof_arena_entrances_are_on_the_edge_and_waves_use_known_entrances() -> void:
	assert_eq(ARENA.entrance_cells.size(), ARENA.entrance_names.size())
	for w: WaveConfig in ARENA.waves:
		for e: int in w.entrances:
			assert_between(e, 0, ARENA.entrance_cells.size() - 1)
		assert_eq(w.counts.size(), 4, "one count per demo type")
