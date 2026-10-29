extends GutTest

var _layout: InteriorLayout
var _config: InteriorHordeConfig
var _hordes: InteriorHordes


func before_each() -> void:
	_layout = InteriorLayout.generate(26, 22, 3, 7, Vector2(-13, -11), -9.6, 0)
	_config = InteriorHordeConfig.new()
	_config.per_storey = 6
	var hc: HordeConfig = HordeConfig.new()
	hc.speed_jitter = 0.0
	_hordes = InteriorHordes.new()
	add_child_autofree(_hordes)
	_hordes.setup(_layout, _config, hc, [] as Array[VatModel], null, 3)


## Steps `seconds` of game time at 20 Hz.
func _run(seconds: float, player_storey: int, player_pos: Vector2) -> void:
	for i: int in int(seconds * 20.0):
		_hordes.step(0.05, player_storey, player_pos)


func _far_corner() -> Vector2:
	return _layout.cell_center(Vector2i(24, 20))


func test_flooded_storey_has_no_horde_and_the_others_start_asleep() -> void:
	assert_null(_hordes.horde_at(0))
	for s: int in [1, 2]:
		assert_eq(_hordes.horde_at(s).count, 6)
		assert_eq(_hordes.horde_at(s).awake_count(), 0)


func test_sleepers_stand_still() -> void:
	var h: Horde = _hordes.horde_at(2)
	var before: PackedVector2Array = h.positions.duplicate()
	_config.sight = 0.0
	_config.chain = 0.0
	_run(2.0, 2, _far_corner())
	for a: int in h.count:
		assert_eq(h.positions[a], before[a])


func test_noise_wakes_sleepers_in_range_and_less_through_a_floor() -> void:
	var h1: Horde = _hordes.horde_at(1)
	var h2: Horde = _hordes.horde_at(2)
	var at: Vector2 = h2.positions[0]
	_hordes.noise(at, 2, 0.5)
	assert_eq(h2.dormant[0], 0, "the one at the noise")
	for a: int in h1.count:
		var expect: int = 0 if h1.positions[a].distance_to(at) <= 0.5 * _config.floor_damping else 1
		assert_eq(h1.dormant[a], expect, "storey below, damped radius")
	_hordes.noise(at, 2, 100.0)
	assert_eq(h2.awake_count(), h2.count)
	assert_eq(h1.awake_count(), h1.count, "100 m × 0.5 still covers the floor below")


func test_a_hit_wakes_a_sleeper() -> void:
	var h: Horde = _hordes.horde_at(2)
	h.apply_damage(PackedInt32Array([0]), 1)
	assert_eq(h.dormant[0], 0)


func test_awake_zombies_climb_to_the_player_and_take_stair_heights() -> void:
	_hordes.noise(Vector2.ZERO, 1, 100.0)
	var landing: Vector2 = _hordes.top_landing()
	var lifted: bool = false
	for i: int in 1200:  # 60 s
		_hordes.step(0.05, 2, landing)
		for a: int in _hordes.horde_at(1).count:
			lifted = lifted or _hordes.horde_at(1).lift[a] > 0.5
	assert_eq(_hordes.horde_at(1).count, 0, "everyone from storey 1 went up")
	assert_eq(_hordes.horde_at(2).count, 12)
	assert_true(lifted, "drawn on the flight's slope while climbing")


func test_awake_zombies_come_down_to_the_player() -> void:
	_hordes.noise(Vector2.ZERO, 2, 100.0)
	_hordes.noise(Vector2.ZERO, 1, 100.0)
	var below: Vector2 = _layout.cell_center(Vector2i(InteriorLayout.STAIR_X0 - 1, _layout.corridor_row))
	_run(60.0, 1, below)
	assert_eq(_hordes.horde_at(2).count, 0, "everyone from storey 2 went down")
	assert_eq(_hordes.horde_at(1).count, 12)


func test_sight_needs_line_of_sight() -> void:
	_config.chain = 0.0
	var h: Horde = _hordes.horde_at(2)
	_config.sight = 100.0
	# Player in a sealed spot: the far corner of a room; only zombies that can see it wake.
	var p: Vector2 = _far_corner()
	_hordes.step(0.05, 2, p)
	var grid: NavGrid = _hordes.grids[2]
	for a: int in h.count:
		assert_eq(h.dormant[a] == 0, grid.line_of_sight(h.positions[a], p))
