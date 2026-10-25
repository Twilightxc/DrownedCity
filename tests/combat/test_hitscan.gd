extends GutTest

var _grid: NavGrid
var _horde: Horde
var _hitscan: Hitscan
var _hits: PackedInt32Array


func before_each() -> void:
	var config: HordeConfig = HordeConfig.new()
	config.radius = 0.3
	_grid = NavGrid.new(30, 10, 1.0, Vector2.ZERO)
	_horde = Horde.new(config, _grid, 32, 1)
	_hitscan = Hitscan.new(_grid)
	_hits = PackedInt32Array()


func _rebuild() -> void:
	_horde.spatial.rebuild(_horde.positions, _horde.count)


func test_hits_are_ordered_nearest_first() -> void:
	_horde.spawn(Vector2(12.5, 5.0))  # 0: far
	_horde.spawn(Vector2(4.5, 5.1))  # 1: near
	_horde.spawn(Vector2(8.5, 4.9))  # 2: middle
	_rebuild()
	_hitscan.cast(_horde, Vector2(0.5, 5.0), Vector2.RIGHT, 25.0, 10, _hits)
	assert_eq(_hits, PackedInt32Array([1, 2, 0]))


func test_penetration_limits_hits_and_shortens_bullet() -> void:
	for x: float in [3.5, 5.5, 7.5, 9.5]:
		_horde.spawn(Vector2(x, 5.0))
	_rebuild()
	var travelled: float = _hitscan.cast(_horde, Vector2(0.5, 5.0), Vector2.RIGHT, 25.0, 2, _hits)
	assert_eq(_hits.size(), 2)
	assert_almost_eq(travelled, 5.0, 0.01, "bullet stops inside the 2nd body")


func test_misses_agents_off_the_line() -> void:
	_horde.spawn(Vector2(6.5, 5.5))  # 0.5 m off the ray, radius 0.3
	_rebuild()
	_hitscan.cast(_horde, Vector2(0.5, 5.0), Vector2.RIGHT, 25.0, 3, _hits)
	assert_eq(_hits.size(), 0)


func test_ignores_agents_behind_shooter() -> void:
	_horde.spawn(Vector2(2.0, 5.0))
	_rebuild()
	_hitscan.cast(_horde, Vector2(5.0, 5.0), Vector2.RIGHT, 25.0, 3, _hits)
	assert_eq(_hits.size(), 0)


func test_wall_stops_bullet() -> void:
	_grid.set_blocked_rect(Rect2i(10, 0, 1, 10))
	_horde.spawn(Vector2(5.5, 5.0))
	_horde.spawn(Vector2(15.5, 5.0))
	_rebuild()
	var travelled: float = _hitscan.cast(_horde, Vector2(0.5, 5.0), Vector2.RIGHT, 25.0, 5, _hits)
	assert_eq(_hits, PackedInt32Array([0]), "agent behind the wall is safe")
	assert_lt(travelled, 10.0)
	assert_gt(travelled, 9.0)


func test_diagonal_shot() -> void:
	_horde.spawn(Vector2(6.5, 6.5))
	_rebuild()
	_hitscan.cast(_horde, Vector2(0.5, 0.5), Vector2(1, 1), 25.0, 1, _hits)
	assert_eq(_hits, PackedInt32Array([0]))


func test_wall_corner_blocks_diagonal_shot() -> void:
	# Regression (Copilot, PR #2): the ray clips only the corner of wall cell (3, 3);
	# half-cell sampling at t = 0.5 / 1.0 lands in (2, 3) and (3, 2) and missed it.
	_grid.set_blocked_rect(Rect2i(3, 3, 1, 1))
	_horde.spawn(Vector2(5.5, 0.6))  # on the ray, behind the corner
	_rebuild()
	var travelled: float = _hitscan.cast(_horde, Vector2(2.5, 3.6), Vector2(1, -1), 25.0, 5, _hits)
	assert_eq(_hits.size(), 0, "corner of the wall stops the bullet")
	assert_lt(travelled, 1.0)


func test_shot_just_past_corner_is_not_blocked() -> void:
	_grid.set_blocked_rect(Rect2i(3, 3, 1, 1))
	_horde.spawn(Vector2(5.4, 0.5))
	_rebuild()
	_hitscan.cast(_horde, Vector2(2.4, 3.5), Vector2(1, -1), 25.0, 5, _hits)
	assert_eq(_hits, PackedInt32Array([0]), "passes 0.1 m beside the corner")
