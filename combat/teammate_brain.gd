class_name TeammateBrain
extends RefCounted
## What an AI teammate wants each frame (PHASE1 1.5+ A5): where to move, where to aim, whether to pull the
## trigger, sprint or reload. Pure data in, wishes out, so it is testable without a scene; the Teammate node
## feeds it and acts on the result with the same gun, stance and movement rules as the player.
## It picks the hunting zombie nearest to itself that it can see within its gun's reach (protect_weight can
## lean it toward those near the leader; 0 by default, J 2026-11-04), turns to it at a human rate, waits a reaction time, fires in bursts, backs away from anything too
## close, and otherwise keeps its spot beside the leader or where it was told to hold.

enum Order { FOLLOW, HOLD }

const LOS_CHECKS: int = 6  ## line-of-sight tests per retarget, best scores first

var config: TeammateConfig
var order: Order = Order.FOLLOW
var hold_point: Vector2 = Vector2.ZERO
var hold_fire: bool = false
var side: float = 1.0  ## +1 = the leader's left, -1 = right

# Wishes, read after think()
var move: Vector2 = Vector2.ZERO  ## ground plane, length 0..1
var aim: Vector2 = Vector2(0, 1)
var fire: bool = false
var sprint: bool = false
var want_reload: bool = false
var target: int = -1  ## horde index, -1 = none
var target_pos: Vector2 = Vector2.ZERO

var _retarget_left: float = 0.0
var _reaction_left: float = 0.0
var _burst_left: float = 0.0
var _pause_left: float = 0.0
var _semi_pulse: bool = false
var _path_left: float = 0.0
var _path_point: Vector2 = Vector2.ZERO


func _init(cfg: TeammateConfig, own_side: float = 1.0) -> void:
	config = cfg
	side = own_side


## Where it stands when following: beside and a little behind the leader, relative to the leader's aim.
func follow_spot(leader: Vector2, leader_aim: Vector2) -> Vector2:
	var fwd: Vector2 = leader_aim.normalized() if leader_aim != Vector2.ZERO else Vector2(0, 1)
	var left: Vector2 = Vector2(fwd.y, -fwd.x)
	return leader + left * side * config.side_offset_m - fwd * config.follow_distance_m


func think(delta: float, me: Vector2, gun: Gun, muzzle_over: float, leader: Vector2, leader_aim: Vector2,
		horde: Horde, grid: NavGrid) -> void:
	_pick_target(delta, me, gun, muzzle_over, leader, horde, grid)
	_turn(delta, me)
	_shoot(delta, me, gun)
	_walk(delta, me, leader, leader_aim, horde, grid)
	want_reload = target < 0 and not gun.is_reloading() and gun.ammo < gun.mag_size * config.tactical_reload_frac


func _pick_target(delta: float, me: Vector2, gun: Gun, over: float, leader: Vector2, horde: Horde, grid: NavGrid) -> void:
	_retarget_left -= delta
	if target >= horde.count or (target >= 0 and horde.positions[target].distance_to(target_pos) > 1.5):
		target = -1  # it died (indices shift) or isn't where we saw it
	if target >= 0:
		target_pos = horde.positions[target]
	if _retarget_left > 0.0 and target >= 0:
		return
	_retarget_left = config.retarget_sec
	var reach: float = gun.config.range_m * config.engage_range_mul
	var scored: Array[Vector2] = []  # (score, index)
	for a: int in horde.count:
		if horde.state[a] != Horde.State.HUNTING:
			continue
		var d: float = me.distance_to(horde.positions[a])
		if d <= reach:
			scored.append(Vector2(d + config.protect_weight * leader.distance_to(horde.positions[a]), a))
	scored.sort()
	var previous: int = target
	target = -1
	for i: int in mini(scored.size(), LOS_CHECKS):
		var a: int = int(scored[i].y)
		if grid.line_of_sight(me, horde.positions[a], over):
			target = a
			target_pos = horde.positions[a]
			break
	if target >= 0 and target != previous:
		_reaction_left = config.reaction_sec


func _turn(delta: float, me: Vector2) -> void:
	var want: Vector2 = aim
	if target >= 0 and target_pos.distance_squared_to(me) > 0.01:
		want = (target_pos - me).normalized()
	elif move.length_squared() > 0.04:
		want = move.normalized()
	var step: float = deg_to_rad(config.aim_turn_deg_per_sec) * delta
	var angle: float = aim.angle_to(want)
	aim = aim.rotated(clampf(angle, -step, step)).normalized()


func _shoot(delta: float, me: Vector2, gun: Gun) -> void:
	fire = false
	_reaction_left -= delta
	if hold_fire or target < 0 or _reaction_left > 0.0:
		_burst_left = 0.0
		return
	var off: float = absf(aim.angle_to(target_pos - me))
	if off > deg_to_rad(config.fire_cone_deg):
		return
	if gun.mode() == WeaponConfig.FireMode.AUTO:
		if _pause_left > 0.0:
			_pause_left -= delta
			return
		if _burst_left <= 0.0:
			_burst_left = config.burst_sec
		_burst_left -= delta
		fire = true
		if _burst_left <= 0.0:
			_pause_left = config.burst_pause_sec
	else:
		_semi_pulse = not _semi_pulse  # semi and burst guns fire on a fresh press
		fire = _semi_pulse


func _walk(delta: float, me: Vector2, leader: Vector2, leader_aim: Vector2, horde: Horde, grid: NavGrid) -> void:
	var spot: Vector2 = hold_point if order == Order.HOLD else follow_spot(leader, leader_aim)
	# Back away from anything too close, toward the leader rather than off the roof.
	var near: int = -1
	var near_d2: float = config.kite_m * config.kite_m
	for a: int in horde.count:
		if horde.state[a] == Horde.State.HUNTING:
			var d2: float = me.distance_squared_to(horde.positions[a])
			if d2 < near_d2:
				near_d2 = d2
				near = a
	sprint = false
	if near >= 0:
		var away: Vector2 = (me - horde.positions[near]).normalized()
		var home: Vector2 = (leader - me).normalized() if leader.distance_to(me) > 1.0 else Vector2.ZERO
		move = (away * 0.8 + home * 0.4).normalized()
		return
	var dist: float = me.distance_to(spot)
	if dist <= config.arrive_m:
		move = Vector2.ZERO
		return
	_path_left -= delta
	if _path_left <= 0.0:
		_path_left = 0.4
		_path_point = GridPath.next_point(grid, me, spot)
	var to: Vector2 = _path_point - me
	move = to.normalized() * clampf(dist / 1.5, 0.3, 1.0) if to.length_squared() > 0.0001 else Vector2.ZERO
	sprint = target < 0 and dist > config.sprint_beyond_m
