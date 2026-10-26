extends GutTest

const CONE: float = deg_to_rad(12.0)

var _grid: NavGrid
var _horde: Horde
var _assist: AimAssist


func before_each() -> void:
	_grid = NavGrid.new(30, 30, 1.0, Vector2.ZERO)
	_horde = Horde.new(HordeConfig.new(), _grid, 16, 1)
	_assist = AimAssist.new(_grid)


func test_picks_smallest_angle_in_cone() -> void:
	_horde.spawn(Vector2(10.5, 6.5))  # 0: ~8° off
	_horde.spawn(Vector2(14.5, 5.3))  # 1: ~1° off, farther
	_horde.spawn(Vector2(8.5, 9.5))  # 2: outside the cone
	assert_eq(_assist.pick(_horde, Vector2(5, 5), Vector2.RIGHT, 18.0, CONE), 1)


func test_nothing_outside_cone_or_range() -> void:
	_horde.spawn(Vector2(8.5, 9.5))  # ~45° off
	_horde.spawn(Vector2(28.5, 5.0))  # 23.5 m away
	assert_eq(_assist.pick(_horde, Vector2(5, 5), Vector2.RIGHT, 18.0, CONE), -1)


func test_skips_target_behind_wall() -> void:
	_grid.set_blocked_rect(Rect2i(10, 0, 1, 6))  # covers y 0..6 at x 10
	_horde.spawn(Vector2(14.5, 5.2))  # 0: best angle, but behind the wall
	_horde.spawn(Vector2(9.0, 5.8))  # 1: in front of the wall
	assert_eq(_assist.pick(_horde, Vector2(5, 5), Vector2.RIGHT, 18.0, CONE), 1)


func test_angle_beats_distance() -> void:
	# Copilot PR #7 case: near but 3° off must not win over far but 1° off.
	var from: Vector2 = Vector2(2, 15)
	_horde.spawn(from + Vector2.RIGHT.rotated(deg_to_rad(3.0)) * 2.0)  # 0: 2 m, 3°
	_horde.spawn(from + Vector2.RIGHT.rotated(deg_to_rad(1.0)) * 17.0)  # 1: 17 m, 1°
	assert_eq(_assist.pick(_horde, from, Vector2.RIGHT, 18.0, CONE), 1)


func test_many_blocked_candidates_do_not_hide_a_visible_one() -> void:
	_grid.set_blocked_rect(Rect2i(10, 0, 1, 6))
	for i: int in 6:  # six better-aligned zombies, all behind the wall
		_horde.spawn(Vector2(12.5 + i, 5.0 + 0.02 * i))
	_horde.spawn(Vector2(9.0, 5.8))  # 6: worse angle (~11°), visible
	assert_eq(_assist.pick(_horde, Vector2(5, 5), Vector2.RIGHT, 18.0, CONE), 6)


func test_ignores_targets_behind_shooter() -> void:
	_horde.spawn(Vector2(2.0, 5.0))
	assert_eq(_assist.pick(_horde, Vector2(5, 5), Vector2.RIGHT, 18.0, CONE), -1)


func test_bend_strength() -> void:
	var from: Vector2 = Vector2.ZERO
	var target: Vector2 = Vector2(10, 1)  # ~5.7° off
	var full: Vector2 = AimAssist.bend(Vector2.RIGHT, from, target, 1.0)
	assert_almost_eq(full, target.normalized(), Vector2(0.001, 0.001))
	assert_almost_eq(AimAssist.bend(Vector2.RIGHT, from, target, 0.0), Vector2.RIGHT, Vector2(0.001, 0.001))
	var half: float = AimAssist.bend(Vector2.RIGHT, from, target, 0.5).angle()
	assert_almost_eq(half, target.angle() * 0.5, 0.001)
