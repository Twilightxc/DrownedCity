extends GutTest
## Low cover (J 2026-11-03): shots and sight held above an AC unit or sandbags pass over them.

var _grid: NavGrid


func before_each() -> void:
	_grid = NavGrid.new(20, 20)
	_grid.set_blocked_rect(Rect2i(8, 0, 1, 20), true, 0.95)  # a row of AC units at x 8..9
	_grid.set_blocked_rect(Rect2i(14, 0, 1, 20))  # a wall at x 14..15


func test_a_shot_from_standing_height_passes_low_cover_but_not_a_wall() -> void:
	var from: Vector2 = Vector2(5.5, 5.5)
	assert_almost_eq(_grid.ray_distance(from, Vector2.RIGHT, 30.0, 1.4), 8.5, 0.01, "over the AC, stops at the wall")
	assert_almost_eq(_grid.ray_distance(from, Vector2.RIGHT, 30.0, 0.9), 2.5, 0.01, "kneeling below its top: stopped")
	assert_almost_eq(_grid.ray_distance(from, Vector2.RIGHT, 30.0), 2.5, 0.01, "rays at the floor (default): stopped")
	assert_true(_grid.blocks_ray(Vector2i(8, 5)), "still blocks walking-height checks")
	assert_false(_grid.is_walkable(Vector2i(8, 5)), "and can't be walked through")


func test_hitscan_hits_a_zombie_behind_low_cover_from_standing_height() -> void:
	var cfg: HordeConfig = HordeConfig.new()
	var h: Horde = Horde.new(cfg, _grid, 4, 1)
	h.spawn(Vector2(10.5, 5.5), 0)
	h.spatial.rebuild(h.positions, h.count)
	var hs: Hitscan = Hitscan.new(_grid)
	var hits: PackedInt32Array = PackedInt32Array()
	hs.cast(h, Vector2(5.5, 5.5), Vector2.RIGHT, 30.0, 1, hits, 1.4)
	assert_eq(hits.size(), 1, "standing: over the AC into the zombie")
	hs.cast(h, Vector2(5.5, 5.5), Vector2.RIGHT, 30.0, 1, hits, 0.3)
	assert_eq(hits.size(), 0, "prone: the AC takes it")


func test_zombies_see_a_standing_survivor_over_low_cover_but_not_one_crouched_behind_it() -> void:
	var cfg: HordeConfig = HordeConfig.new()
	var h: Horde = Horde.new(cfg, _grid, 4, 1)
	h.spawn(Vector2(10.5, 5.5), 0, Horde.State.DORMANT)
	h.perceive(Vector2(6.5, 5.5), 1.0, 1.0, 0.9)
	assert_eq(h.state[0], Horde.State.DORMANT, "crouched behind it: hidden")
	h.perceive(Vector2(6.5, 5.5), 1.0, 1.0, 1.5)
	assert_eq(h.state[0], Horde.State.HUNTING, "standing: seen over it")
