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
## near the blast, and picks its own stance: the lowest one (steadier, harder to see) whose muzzle still clears
## the cover between it and its target, as long as no hunter is close; crouched while sneaking past sleepers
## (bug list 2026-11-05, items 1, 5, 7; J: its own call, not a copy of the player).
## Under "hold fire" it doesn't shoot but knifes a zombie that reaches it, and backs off only when mob_count
## crowd it (J 2026-11-06, item 10); it also knifes one in reach while its gun is empty or reloading.
## Orders (J 2026-11-06, the 8-slot wheel): one movement order and one fire rule at a time.
## Movement: FOLLOW its spot beside the leader; SNEAK the same spot, crouched and never sprinting; HOLD a point,
## backing off what comes close; STAY on a point without backing off. Helping a downed squad member up still
## comes first. Fire rule: AT_WILL; HOLD_FIRE (knife only in self-defence, no grenades); QUIET (only a gun
## quieter than quiet_noise_m, e.g. a silenced pistol; else as hold fire); MELEE (knife only, and it steps in
## to a lone zombie within melee_charge_m).

enum Order { FOLLOW, SNEAK, HOLD, STAY }
enum FireRule { AT_WILL, HOLD_FIRE, QUIET, MELEE }

const LOS_CHECKS: int = 6  ## line-of-sight tests per retarget, best scores first
const THROW_CANDIDATES: int = 12  ## nearest hunters in range tried as a grenade's centre

var config: TeammateConfig
var order: Order = Order.FOLLOW
var hold_point: Vector2 = Vector2.ZERO
var fire_rule: FireRule = FireRule.AT_WILL
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
var want_melee: bool = false  ## swing the knife this frame
var throw_at: Vector2 = Vector2.ZERO

# Inputs set by the Teammate before think()
var muzzle_heights: PackedFloat32Array = PackedFloat32Array([1.38, 1.0, 0.38])  ## per stance (MovementConfig)
var has_patient: bool = false  ## a downed squad member to help up
var patient_pos: Vector2 = Vector2.ZERO
var patient_radius: float = 1.6  ## that fighter's FighterConfig.revive_radius_m
var can_throw: bool = false  ## up, with a grenade and something to throw it with
var throw_blast_m: float = 0.0
var throw_range: Vector2 = Vector2.ZERO  ## (min, max) m
var melee_reach: float = 0.0  ## the fighter's MeleeConfig.reach_m, 0 = no melee
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
var _stance_left: float = 0.0
var _sneaking: bool = false
var _mobbed: bool = false
var _melee_at: Vector2 = Vector2.ZERO
var _guns_free: bool = true  ## this frame's fire rule lets the gun in hand shoot


## Whether the rule lets `gun` shoot (QUIET: only a gun at or under quiet_noise_m).
func may_shoot(gun: Gun) -> bool:
	match fire_rule:
		FireRule.AT_WILL:
			return true
		FireRule.QUIET:
			return gun.noise_m <= config.quiet_noise_m
	return false


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
	_guns_free = may_shoot(gun)
	_pick_target(delta, me, gun, muzzle_over, leader, horde, grid)
	_plan_throw(delta, me, muzzle_over, horde, grid)
	_plan_melee(me, gun, horde)
	_turn(delta, me)
	_shoot(delta, me, gun)
	_walk(delta, me, leader, leader_aim, horde, grid)
	_pick_stance(delta, me, horde, grid)
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
	if want_melee and _melee_at.distance_squared_to(me) > 0.0001:
		want = (_melee_at - me).normalized()
	elif target >= 0 and target_pos.distance_squared_to(me) > 0.01:
		want = (target_pos - me).normalized()
	elif move.length_squared() > 0.04:
		want = move.normalized()
	var step: float = deg_to_rad(config.aim_turn_deg_per_sec) * delta
	var angle: float = aim.angle_to(want)
	aim = aim.rotated(clampf(angle, -step, step)).normalized()


func _shoot(delta: float, me: Vector2, gun: Gun) -> void:
	fire = false
	_reaction_left -= delta
	if not _guns_free or reviving or target < 0 or _reaction_left > 0.0:
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
	var holding: bool = order == Order.HOLD or order == Order.STAY
	var spot: Vector2 = hold_point if holding else follow_spot(leader, leader_aim)
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
	var stays: bool = order == Order.STAY and not has_patient
	if near >= 0 and not stays and (_guns_free or _mobbed or melee_reach <= 0.0):
		var away: Vector2 = (me - horde.positions[near]).normalized()
		var home: Vector2 = (spot - me).normalized() if spot.distance_to(me) > 1.0 else Vector2.ZERO
		move = (away * 0.8 + home * 0.4).normalized()
		return
	if want_melee and not has_patient:
		move = Vector2.ZERO  # stand and fight it
		return
	if stays:
		move = Vector2.ZERO
		return
	if fire_rule == FireRule.MELEE and not has_patient and not _mobbed and melee_reach > 0.0:
		var prey: int = _nearest_hunter(me, horde, config.melee_charge_m)
		if prey >= 0:
			move = (horde.positions[prey] - me).normalized()  # step in to knife it
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
	sprint = target < 0 and dist > (3.0 if has_patient else config.sprint_beyond_m) and (has_patient or not _sneaking)


func _nearest_hunter(me: Vector2, horde: Horde, within: float) -> int:
	var best: int = -1
	var best_d2: float = within * within
	for a: int in horde.count:
		if horde.state[a] == Horde.State.HUNTING:
			var d2: float = me.distance_squared_to(horde.positions[a])
			if d2 < best_d2:
				best_d2 = d2
				best = a
	return best


## Kneels to help someone up; moves standing (crouched while sneaking). Standing still it rethinks every
## stance_check_sec: with a target, the lowest stance whose muzzle clears the cover toward it (prone only with
## no hunter within prone_safe_m, crouch within crouch_safe_m); without one it stands to look over, or crouches
## while sneaking (sleeping or suspicious zombies near, nobody hunting).
func _pick_stance(delta: float, me: Vector2, horde: Horde, grid: NavGrid) -> void:
	_stance_left -= delta
	if reviving:
		stance = FighterMotion.Stance.CROUCH
		return
	var moving: bool = move.length_squared() > 0.01
	if not moving and _stance_left > 0.0:
		return
	_stance_left = config.stance_check_sec
	var hunter_d2: float = INF
	var calm_near: bool = false
	var sneak2: float = config.sneak_radius_m * config.sneak_radius_m
	for a: int in horde.count:
		var d2: float = me.distance_squared_to(horde.positions[a])
		if horde.state[a] == Horde.State.HUNTING:
			hunter_d2 = minf(hunter_d2, d2)
		elif d2 <= sneak2:
			calm_near = true
	var told_to_sneak: bool = order == Order.SNEAK and hunter_d2 >= config.crouch_safe_m * config.crouch_safe_m
	_sneaking = (hunter_d2 == INF and calm_near) or told_to_sneak
	if moving:
		stance = FighterMotion.Stance.CROUCH if _sneaking and not sprint else FighterMotion.Stance.STAND
		return
	if target < 0:
		stance = FighterMotion.Stance.CROUCH if _sneaking else FighterMotion.Stance.STAND
		return
	var hunter_d: float = sqrt(hunter_d2)
	for s: int in [FighterMotion.Stance.PRONE, FighterMotion.Stance.CROUCH]:
		var safe: float = config.prone_safe_m if s == FighterMotion.Stance.PRONE else config.crouch_safe_m
		if hunter_d >= safe and grid.line_of_sight(me, target_pos, muzzle_heights[s]):
			stance = s
			return
	stance = FighterMotion.Stance.STAND


## Every throw_check_sec: the packed spot in throw range with the most hunters inside a blast; a frag goes there
## when there are enough of them and no friend is near (want_throw, one frame; the Teammate calls threw()).
func _plan_throw(delta: float, me: Vector2, over: float, horde: Horde, grid: NavGrid) -> void:
	want_throw = false
	_throw_left -= delta
	_check_left -= delta
	if not can_throw or reviving or fire_rule != FireRule.AT_WILL or _throw_left > 0.0 or _check_left > 0.0:
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


## The nearest hunter in knife reach: swing at it under "hold fire" or with the gun empty / reloading.
## Also counts the crowd: mob_count hunters within kite_m and it backs off instead.
func _plan_melee(me: Vector2, gun: Gun, horde: Horde) -> void:
	want_melee = false
	var near: int = -1
	var near_d2: float = INF
	var crowd: int = 0
	var kite2: float = config.kite_m * config.kite_m
	for a: int in horde.count:
		if horde.state[a] != Horde.State.HUNTING:
			continue
		var d2: float = me.distance_squared_to(horde.positions[a])
		if d2 < kite2:
			crowd += 1
		if d2 < near_d2:
			near_d2 = d2
			near = a
	_mobbed = crowd >= config.mob_count
	var reach: float = melee_reach * 0.95
	if near < 0 or melee_reach <= 0.0 or reviving or near_d2 > reach * reach:
		return
	if not _guns_free or gun.is_reloading() or gun.ammo == 0:
		want_melee = true
		_melee_at = horde.positions[near]


func threw() -> void:
	want_throw = false
	_throw_left = config.throw_cooldown_sec
