extends GutTest
## Melee (GDD §6; bug list item 10): the swing's timing, who it hits, how hard.

const KNIFE: MeleeConfig = preload("res://data/weapons/knife.tres")

var _grid: NavGrid
var _horde: Horde


func before_each() -> void:
	_grid = NavGrid.new(20, 20)
	_horde = Horde.new(HordeConfig.new(), _grid, 16, 1)


func test_the_hit_lands_once_after_the_windup_and_the_next_swing_waits() -> void:
	var m: Melee = Melee.new(KNIFE)
	assert_true(m.try_swing())
	assert_false(m.try_swing(), "one at a time")
	var hits: int = 0
	var first_at: float = -1.0
	var t: float = 0.0
	while m.is_swinging():
		t += 0.02
		if m.step(0.02):
			hits += 1
			first_at = t
	assert_eq(hits, 1)
	assert_almost_eq(first_at, KNIFE.windup_sec, 0.021)
	assert_true(m.try_swing(), "ready again after swing_sec")


func test_it_hits_the_nearest_in_the_cone_and_reach_not_behind_or_far_or_through_walls() -> void:
	var me: Vector2 = Vector2(10, 10)
	_horde.spawn(Vector2(10, 11.2), 0)  # 0: in front, 1.2 m
	_horde.spawn(Vector2(10, 10.8), 0)  # 1: in front, nearer
	_horde.spawn(Vector2(10, 9.0), 0)  # 2: behind
	_horde.spawn(Vector2(10, 12.5), 0)  # 3: too far
	assert_eq(Melee.targets(KNIFE, _horde, _grid, me, Vector2(0, 1)), PackedInt32Array([1]), "nearest in front")
	var wide: MeleeConfig = KNIFE.duplicate()
	wide.max_targets = 5
	assert_eq(Melee.targets(wide, _horde, _grid, me, Vector2(0, 1)), PackedInt32Array([1, 0]))
	_horde.kill(1)
	_horde.kill(0)
	_grid.set_blocked_rect(Rect2i(9, 10, 3, 1))  # a wall across the cell row in front
	_horde.spawn(Vector2(10.5, 11.05), 0)  # 1.35 m: in reach, but the wall is between
	assert_eq(Melee.targets(KNIFE, _horde, _grid, Vector2(10.5, 9.7), Vector2(0, 1)).size(), 0, "not through a wall")


func test_damage_armor_and_silent_takedowns() -> void:
	_horde.spawn(Vector2(5, 5), 0)
	_horde.spawn(Vector2(6, 5), 0, Horde.State.DORMANT)
	assert_eq(Melee.damage_to(KNIFE, _horde, 0), KNIFE.damage)
	assert_eq(Melee.damage_to(KNIFE, _horde, 1), roundi(KNIFE.damage * KNIFE.sneak_mul), "a sleeper: takedown")
	assert_gte(Melee.damage_to(KNIFE, _horde, 1), 100, "kills a Walker (HP 100) in one")
	_horde.armor[0] = WeaponConfig.Armor.M
	assert_eq(Melee.damage_to(KNIFE, _horde, 0), roundi(KNIFE.damage * 0.25), "a knife against armor")
