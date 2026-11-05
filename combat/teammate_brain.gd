class_name TeammateBrain
extends RefCounted
## What an AI teammate wants each frame (PHASE1 1.5+ A5): where to move, where to aim, whether to pull the
## trigger, sprint or reload. Pure data in, wishes out, so it is testable without a scene; the Teammate node
## feeds it and acts on the result with the same gun, stance and movement rules as the player.
## It picks the hunting zombie nearest to itself that it can see within its gun's reach (protect_weight can
## lean it toward those near the leader; 0 by default, J 2026-11-04), turns to it at a human rate, waits a reaction time, fires in bursts, backs away from anything too
## close, and otherwise keeps its spot beside the leader or where it was told to hold.
## A downed squad member comes first (has_patient): it walks there, pushing past all but the closest zombies,
## and kneels beside it without firing until it is up. It lobs a frag into a packed crowd when no friend is
## near the blast, and matches the leader's crouch or prone when it stands still beside it (bug list
## 2026-11-05, items 1, 5, 7).

enum Order { FOLLOW, HOLD }

const LOS_CHECKS: int = 6  ## line-of-sight tests per retarget, best scores first
const THROW_CANDIDATES: int = 12  ## nearest hunters in range tried as a grenade's centre

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
var stance: int = FighterMotion.Stance.STAND
var reviving: bool = false
var want_throw: bool = false
var throw_at: Vector2 = Vector2.ZERO

# Inputs set by the Teammate before think()
var leader_stance: int = FighterMotion.Stance.STAND
var has_patient: bool = false  ## a downed squad member to help up
var patient_pos: Vector2 = Vector2.ZERO
var patient_radius: float = 1.6  ## that fighter's FighterConfig.revive_radius_m
var can_throw: bool = false  ## up, with a grenade and something to throw it with
var throw_blast_m: float = 0.0
var throw_range: Vector2 = Vector2.ZERO  ## (min, max) m
var allies: PackedVector2Array = PackedVector2Array()  ## everyone a grenade must miss, itself included

var _retarget_left: float = 0.0
var _reaction_left: float = 0.0
var _burst_left: float = 0.0
var _pause_left: float = 0.0
var _semi_pulse: bool = false
var _path_left: float = 0.0
var _path_point: Vector2 = Vector2.ZERO
var _throw_left: float = 0.0
var _check_left: float = 0.0


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
	reviving = has_patient and me.distance_to(patient_pos) <= patient_radius * 0.75
	_pick_target(delta, me, gun, muzzle_over, leader, horde, grid)
	_plan_throw(delta, me, muzzle_over, horde, grid)
	_turn(delta, me)
	_shoot(delta, me, gun)
	_walk(delta, me, leader, leader_aim, horde, grid)
	_pick_stance(me)
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
	if hold_fire or reviving or target < 0 or _reaction_left > 0.0:
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
	var arrive: float = config.arrive_m
	var kite: float = config.kite_m
	if has_patient:
		spot = patient_pos
		arrive = patient_radius * 0.6
		kite = config.revive_kite_m  # someone's bleeding out: push in
	# Back away from anything too close, toward the leader rather than off the roof.
	var near: int = -1
	var near_d2: float = kite * kite
	for a: int in horde.count:
		if horde.state[a] == Horde.State.HUNTING:
			var d2: float = me.distance_squared_to(horde.positions[a])
			if d2 < near_d2:
				near_d2 = d2
				near = a
	sprint = false
	if near >= 0:
		var away: Vector2 = (me - horde.positions[near]).normalized()
		var home: Vector2 = (spot - me).normalized() if spot.distance_to(me) > 1.0 else Vector2.ZERO
		move = (away * 0.8 + home * 0.4).normalized()
		return
	var dist: float = me.distance_to(spot)
	if dist <= arrive or reviving:
		move = Vector2.ZERO
		return
	_path_left -= delta
	if _path_left <= 0.0:
		_path_left = 0.4
		_path_point = GridPath.next_point(grid, me, spot)
	var to: Vector2 = _path_point - me
	move = to.normalized() * clampf(dist / 1.5, 0.3, 1.0) if to.length_squared() > 0.0001 else Vector2.ZERO
	sprint = target < 0 and dist > (3.0 if has_patient else config.sprint_beyond_m)


## Kneels to help someone up; stands to move (crouches along with a crouching leader); otherwise matches the
## leader when following, and crouches on a hold while its target is far off.
func _pick_stance(me: Vector2) -> void:
	var follow_low: bool = order == Order.FOLLOW and not has_patient
	if reviving:
		stance = FighterMotion.Stance.CROUCH
	elif move.length_squared() > 0.01:
		var crouch: bool = follow_low and leader_stance != FighterMotion.Stance.STAND and not sprint
		stance = FighterMotion.Stance.CROUCH if crouch else FighterMotion.Stance.STAND
	elif follow_low:
		stance = leader_stance
	elif order == Order.HOLD and target >= 0 and me.distance_to(target_pos) > config.crouch_beyond_m:
		stance = FighterMotion.Stance.CROUCH
	else:
		stance = FighterMotion.Stance.STAND


## Every throw_check_sec: the packed spot in throw range with the most hunters inside a blast; a frag goes there
## when there are enough of them and no friend is near (want_throw, one frame; the Teammate calls threw()).
func _plan_throw(delta: float, me: Vector2, over: float, horde: Horde, grid: NavGrid) -> void:
	want_throw = false
	_throw_left -= delta
	_check_left -= delta
	if not can_throw or reviving or hold_fire or _throw_left > 0.0 or _check_left > 0.0:
		return
	_check_left = config.throw_check_sec
	var r: float = throw_blast_m * 0.8
	var candidates: Array[Vector2] = []  # (distance, index)
	for a: int in horde.count:
		if horde.state[a] != Horde.State.HUNTING:
			continue
		var d: float = me.distance_to(horde.positions[a])
		if d >= throw_range.x and d <= throw_range.y:
			candidates.append(Vector2(d, a))
	if candidates.size() < config.throw_min_cluster:
		return
	candidates.sort()
	var best: int = 0
	var best_at: Vector2 = Vector2.ZERO
	for i: int in mini(candidates.size(), THROW_CANDIDATES):
		var c: Vector2 = horde.positions[int(candidates[i].y)]
		var n: int = 0
		var sum: Vector2 = Vector2.ZERO
		for a: int in horde.count:
			if horde.state[a] == Horde.State.HUNTING and horde.positions[a].distance_to(c) <= r:
				n += 1
				sum += horde.positions[a]
		if n > best:
			best = n
			best_at = sum / n
	if best < config.throw_min_cluster or not grid.line_of_sight(me, best_at, over):
		return
	for p: Vector2 in allies:
		if p.distance_to(best_at) < throw_blast_m + config.throw_safety_m:
			return
	want_throw = true
	throw_at = best_at


func threw() -> void:
	want_throw = false
	_throw_left = config.throw_cooldown_sec
