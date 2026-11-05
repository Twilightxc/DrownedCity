extends GutTest
## PHASE1 1.5+ A5: what an AI teammate wants.

const MATE: TeammateConfig = preload("res://data/combat/teammate.tres")
const AR: WeaponConfig = preload("res://data/weapons/ar_556.tres")
const DMR: WeaponConfig = preload("res://data/weapons/dmr_308.tres")

var _grid: NavGrid
var _horde: Horde
var _brain: TeammateBrain


func before_each() -> void:
	_grid = NavGrid.new(40, 40)
	var cfg: HordeConfig = HordeConfig.new()
	_horde = Horde.new(cfg, _grid, 16, 1)
	_brain = TeammateBrain.new(MATE)


func _think(sec: float, me: Vector2, gun: Gun, leader: Vector2 = Vector2(20, 30)) -> void:
	for i: int in roundi(sec * 20.0):
		_brain.think(0.05, me, gun, 1.4, leader, Vector2(0, -1), _horde, _grid)


func test_it_picks_the_zombie_nearest_to_itself_turns_and_fires_after_a_beat() -> void:
	_horde.spawn(Vector2(10.5, 10.5), 0)  # far from it, near nobody
	_horde.spawn(Vector2(24.5, 24.5), 0)  # nearest to it
	_horde.spawn(Vector2(20.5, 29.5), 0)  # right by the leader, but further from it
	var gun: Gun = Gun.new(AR)
	_brain.aim = Vector2(-1, 0)
	_think(0.05, Vector2(20, 20), gun)
	assert_eq(_brain.target, 1, "nearest to itself first (J)")
	assert_false(_brain.fire, "not yet: turning and reacting")
	_think(0.6, Vector2(20, 20), gun)
	assert_gt(_brain.aim.dot((Vector2(24.5, 24.5) - Vector2(20, 20)).normalized()), 0.99, "aimed")
	assert_true(_brain.fire, "firing")


func test_no_target_through_a_wall_and_hold_fire_holds() -> void:
	_grid.set_blocked_rect(Rect2i(22, 0, 1, 40))  # a wall between
	_horde.spawn(Vector2(25.5, 20.5), 0)
	var gun: Gun = Gun.new(AR)
	_think(0.5, Vector2(20, 20), gun)
	assert_eq(_brain.target, -1, "can't see it")
	_grid.set_blocked_rect(Rect2i(22, 0, 1, 40), false)
	_brain.hold_fire = true
	_think(1.0, Vector2(20, 20), gun)
	assert_gt(_brain.target, -1, "sees it now")
	assert_false(_brain.fire, "but holds its fire")


func test_semi_guns_pulse_the_trigger() -> void:
	_horde.spawn(Vector2(20.5, 26.5), 0)
	var gun: Gun = Gun.new(DMR)
	_brain.aim = Vector2(0, 1)
	var presses: int = 0
	var was: bool = false
	for i: int in 40:
		_brain.think(0.05, Vector2(20.5, 20), gun, 1.4, Vector2(20, 30), Vector2(0, -1), _horde, _grid)
		if _brain.fire and not was:
			presses += 1
		was = _brain.fire
	assert_gt(presses, 5, "a fresh press each shot")


func test_it_keeps_its_spot_beside_the_leader_holds_when_told_and_backs_off_a_close_zombie() -> void:
	var gun: Gun = Gun.new(AR)
	var leader: Vector2 = Vector2(20, 20)
	var spot: Vector2 = _brain.follow_spot(leader, Vector2(0, -1))
	assert_almost_eq(spot.distance_to(leader), Vector2(MATE.side_offset_m, MATE.follow_distance_m).length(), 0.01)
	_think(0.5, Vector2(10, 10), gun, leader)
	assert_gt(_brain.move.dot((spot - Vector2(10, 10)).normalized()), 0.9, "heads for its spot")
	_brain.order = TeammateBrain.Order.HOLD
	_brain.hold_point = Vector2(10, 10)
	_think(0.5, Vector2(10, 10), gun, leader)
	assert_eq(_brain.move, Vector2.ZERO, "holds where it was told")
	_horde.spawn(Vector2(11.5, 10.0), 0)
	_think(0.1, Vector2(10, 10), gun, leader)
	assert_lt(_brain.move.x, 0.0, "backs away from the zombie on its right")


func test_the_horde_hunts_and_hits_the_nearest_target() -> void:
	_horde.spawn(Vector2(30.5, 20.5), 0)
	_horde.extra_targets = PackedVector2Array([Vector2(31.0, 20.5)])
	_horde.recompute_flow([Vector2i(10, 20), Vector2i(31, 20)] as Array[Vector2i])
	for i: int in 60:
		_horde.update(0.05, Vector2(10.5, 20.5))
	assert_eq(_horde.target_hits.size(), 0, "the far player isn't hit")
	assert_gt(_horde.extra_hits[0].size(), 0, "the teammate next to it is")


func test_it_goes_to_a_downed_squad_member_and_kneels_without_firing() -> void:
	var gun: Gun = Gun.new(AR)
	_brain.has_patient = true
	_brain.patient_pos = Vector2(10, 20)
	_think(0.3, Vector2(20, 20), gun)
	assert_gt(_brain.move.dot(Vector2(-1, 0)), 0.9, "heads for the downed one")
	assert_true(_brain.sprint, "runs there when nothing is shooting at it")
	assert_false(_brain.reviving)
	_horde.spawn(Vector2(10.5, 25.5), 0)  # in view of the patient
	_think(1.0, Vector2(10.5, 20), gun)
	assert_true(_brain.reviving, "close enough to help up")
	assert_eq(_brain.move, Vector2.ZERO, "stays put")
	assert_false(_brain.fire, "hands busy")
	assert_eq(_brain.stance, FighterMotion.Stance.CROUCH, "kneels")


func test_it_pushes_past_zombies_that_would_make_it_back_off_when_someone_is_down() -> void:
	var gun: Gun = Gun.new(AR)
	_horde.spawn(Vector2(18.2, 20.0), 0)  # 1.8 m to its left: inside kite_m, outside revive_kite_m
	_brain.has_patient = true
	_brain.patient_pos = Vector2(10, 20)
	_think(0.1, Vector2(20, 20), gun)
	assert_lt(_brain.move.x, 0.0, "keeps going toward the patient")


func test_it_throws_into_a_packed_crowd_but_never_near_a_friend() -> void:
	var gun: Gun = Gun.new(AR)
	for i: int in 6:
		_horde.spawn(Vector2(20.5 + 0.3 * i, 28.5), 0)
	_brain.can_throw = true
	_brain.throw_blast_m = 3.0
	_brain.throw_range = Vector2(2.0, 12.0)
	_brain.allies = PackedVector2Array([Vector2(20, 20), Vector2(21, 27)])  # a friend right by them
	_think(1.0, Vector2(20, 20), gun)
	assert_false(_brain.want_throw, "a friend is inside the blast")
	_brain.allies = PackedVector2Array([Vector2(20, 20)])
	var thrown: bool = false
	for i: int in 20:
		_brain.think(0.05, Vector2(20, 20), gun, 1.4, Vector2(20, 18), Vector2(0, -1), _horde, _grid)
		if _brain.want_throw:
			thrown = true
			assert_almost_eq(_brain.throw_at.y, 28.5, 0.5, "at the crowd")
			_brain.threw()
	assert_true(thrown, "throws")
	_think(1.0, Vector2(20, 20), gun, Vector2(20, 18))
	assert_false(_brain.want_throw, "then waits out the cooldown")


func test_it_picks_the_lowest_stance_that_still_shoots_over_the_cover() -> void:
	var gun: Gun = Gun.new(AR)
	var me: Vector2 = Vector2(20, 5)
	_brain.order = TeammateBrain.Order.HOLD
	_brain.hold_point = me
	_horde.spawn(Vector2(20.5, 20.5), 0)  # 15 m off, open ground
	_think(1.0, me, gun)
	assert_eq(_brain.stance, FighterMotion.Stance.PRONE, "open ground, nothing close: prone, steadiest")
	_grid.set_blocked_rect(Rect2i(15, 8, 10, 1), true, 0.7)  # a low wall: crouched shoots over, prone can't
	_think(1.0, me, gun)
	assert_eq(_brain.stance, FighterMotion.Stance.CROUCH, "crouches behind cover it can shoot over")
	_grid.set_blocked_rect(Rect2i(15, 8, 10, 1), true, 1.2)  # only standing clears it
	_think(1.0, me, gun)
	assert_eq(_brain.stance, FighterMotion.Stance.STAND, "stands to shoot over a higher wall")
	_grid.set_blocked_rect(Rect2i(15, 8, 10, 1), false)
	_horde.spawn(Vector2(20.5, 8.5), 0)  # one 3.5 m off
	_think(1.0, me, gun)
	assert_eq(_brain.stance, FighterMotion.Stance.STAND, "one close: on its feet, ready to back off")


func test_it_crouches_to_sneak_past_sleepers() -> void:
	var gun: Gun = Gun.new(AR)
	_think(0.6, Vector2(20, 20), gun, Vector2(20, 30))
	assert_eq(_brain.stance, FighterMotion.Stance.STAND, "nothing around")
	_horde.spawn(Vector2(28.5, 20.5), 0, Horde.State.DORMANT)
	_think(0.6, Vector2(20, 20), gun, Vector2(20, 30))
	assert_eq(_brain.stance, FighterMotion.Stance.CROUCH, "sleepers near, nobody hunting: low and quiet")
