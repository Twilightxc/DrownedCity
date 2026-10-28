class_name Horde
extends RefCounted
## Real-time zombie crowd as struct-of-arrays. Live agents are packed in [0, count);
## killing swaps the last agent into the hole. No nodes, no physics bodies.
## Animation is state only (clip + time per agent); HordeRenderer turns it into VAT rows.
## Hits and deaths are queued as events for the presentation (blood, corpses), which drains them.

enum Anim { WALK, ATTACK, FLINCH }

const MAX_EVENTS: int = 512  ## per queue; older events are dropped if nobody drains them
const SPOT_PARTS: Vector2i = Vector2i(1, 10)  ## spot fires land on torso .. shin_r (kit_zombie SKELETON order)


## A zombie that just died, as the corpse layer needs it.
class Death:
	var position: Vector2
	var heading: Vector2
	var variant: int
	var tint: Color
	var push: Vector2  ## unit, away from the shooter or the blast
	var blast: bool
	var burned: bool  ## died burning: charred corpse


var config: HordeConfig
var fire: FireConfig  ## optional: null = nothing burns
var ground_fire: GroundFire  ## optional: burning NavGrid cells (flow-field cost, ignites zombies)
var grid: NavGrid
var flow: FlowField
var spatial: SpatialHash

var capacity: int
var count: int = 0
var positions: PackedVector2Array
var velocities: PackedVector2Array
var hp: PackedInt32Array
var speed_scale: PackedFloat32Array
var tint: PackedColorArray
var heading: PackedVector2Array  ## unit facing; follows the velocity, turns to the target when still
var variant: PackedByteArray
var anim: PackedByteArray  ## Anim
var anim_time: PackedFloat32Array  ## walk: cycles (by distance walked); others: seconds
var slow_left: PackedFloat32Array  ## s of hit slow remaining (GDD §6)
var burn_left: PackedFloat32Array  ## s of burning remaining, 0 = not burning
var burn_spot: PackedByteArray  ## 0 = the whole body burns; else part index + 1 of a small spot fire

## Event queues (drained by game/fx): hit point + direction per bullet/blast hit, deaths.
var hit_points: PackedVector2Array = PackedVector2Array()
var hit_dirs: PackedVector2Array = PackedVector2Array()
var deaths: Array[Death] = []

## Totals since start, read by the presentation layer and reported to SimCore later.
var kills: int = 0
var hits_on_target: int = 0

var _attack_cooldown: PackedFloat32Array
var _burn_tick: PackedFloat32Array
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(cfg: HordeConfig, nav: NavGrid, max_agents: int, rng_seed: int = 0) -> void:
	config = cfg
	grid = nav
	capacity = max_agents
	flow = FlowField.new(nav)
	spatial = SpatialHash.new(nav, max_agents)
	positions.resize(max_agents)
	velocities.resize(max_agents)
	hp.resize(max_agents)
	speed_scale.resize(max_agents)
	tint.resize(max_agents)
	heading.resize(max_agents)
	variant.resize(max_agents)
	anim.resize(max_agents)
	anim_time.resize(max_agents)
	slow_left.resize(max_agents)
	burn_left.resize(max_agents)
	burn_spot.resize(max_agents)
	_burn_tick.resize(max_agents)
	_attack_cooldown.resize(max_agents)
	_rng.seed = rng_seed


func spawn(p: Vector2) -> bool:
	if count >= capacity or not grid.is_walkable_world(p):
		return false
	var a: int = count
	positions[a] = p
	velocities[a] = Vector2.ZERO
	hp[a] = config.hp
	speed_scale[a] = 1.0 + _rng.randf_range(-config.speed_jitter, config.speed_jitter)
	var shade: float = _rng.randf_range(0.85, 1.1)
	tint[a] = Color(shade, shade, shade)
	heading[a] = Vector2(0, 1)
	variant[a] = _rng.randi() % maxi(config.variants, 1)
	anim[a] = Anim.WALK
	anim_time[a] = _rng.randf()  # walk phase offset, so the crowd doesn't step in sync
	slow_left[a] = 0.0
	burn_left[a] = 0.0
	burn_spot[a] = 0
	_burn_tick[a] = 0.0
	_attack_cooldown[a] = _rng.randf() * config.attack_interval
	count += 1
	return true


func kill(a: int) -> void:
	assert(a >= 0 and a < count)
	var last: int = count - 1
	if a != last:
		positions[a] = positions[last]
		velocities[a] = velocities[last]
		hp[a] = hp[last]
		speed_scale[a] = speed_scale[last]
		tint[a] = tint[last]
		heading[a] = heading[last]
		variant[a] = variant[last]
		anim[a] = anim[last]
		anim_time[a] = anim_time[last]
		slow_left[a] = slow_left[last]
		burn_left[a] = burn_left[last]
		burn_spot[a] = burn_spot[last]
		_burn_tick[a] = _burn_tick[last]
		_attack_cooldown[a] = _attack_cooldown[last]
	count = last


## Applies damage to the given agents (each listed once). Returns how many died.
## `source` is the muzzle or the blast centre: it sets the blood and corpse push direction.
## Survivors flinch and slow down (hit_slow, stacking up to hit_slow_cap_sec).
func apply_damage(agents: PackedInt32Array, damage: int, source: Vector2 = Vector2.INF, blast: bool = false) -> int:
	var dead: PackedInt32Array = PackedInt32Array()
	for a: int in agents:
		hp[a] -= damage
		var dir: Vector2 = _push_dir(a, source)
		_queue_hit(positions[a], dir)
		if hp[a] <= 0:
			dead.append(a)
			continue
		slow_left[a] = minf(slow_left[a] + config.hit_slow_sec, config.hit_slow_cap_sec)
		if anim[a] != Anim.ATTACK:
			anim[a] = Anim.FLINCH
			anim_time[a] = 0.0
	# Highest index first so swap-removal never moves a still-pending victim.
	dead.sort()
	for i: int in range(dead.size() - 1, -1, -1):
		var a: int = dead[i]
		_queue_death(a, _push_dir(a, source), blast)
		kill(a)
	kills += dead.size()
	return dead.size()


func clear_events() -> void:
	hit_points.clear()
	hit_dirs.clear()
	deaths.clear()


func _push_dir(a: int, source: Vector2) -> Vector2:
	if source == Vector2.INF:
		return -heading[a]
	var d: Vector2 = positions[a] - source
	return d.normalized() if d.length_squared() > 0.0001 else -heading[a]


func _queue_hit(p: Vector2, dir: Vector2) -> void:
	if hit_points.size() >= MAX_EVENTS:
		return
	hit_points.append(p)
	hit_dirs.append(dir)


func _queue_death(a: int, push: Vector2, blast: bool, burned: bool = false) -> void:
	if deaths.size() >= MAX_EVENTS:
		return
	var d: Death = Death.new()
	d.position = positions[a]
	d.heading = heading[a]
	d.variant = variant[a]
	d.tint = tint[a]
	d.push = push
	d.blast = blast
	d.burned = burned
	deaths.append(d)


func recompute_flow(targets: Array[Vector2i]) -> void:
	if ground_fire != null and ground_fire.active_count() > 0:
		flow.compute(targets, ground_fire.cost)
	else:
		flow.compute(targets)


## Sets agent `a`'s whole body on fire (or refreshes it); a spot fire grows into this.
## Nothing burns without a FireConfig.
func ignite(a: int) -> void:
	if fire == null:
		return
	if burn_left[a] <= 0.0:
		_burn_tick[a] = fire.burn_tick_sec
	burn_left[a] = fire.burn_sec
	burn_spot[a] = 0


## A small fire on one random body part (frag blasts): ticks damage, never spreads, no lurch.
## A zombie already burning all over stays that way.
func ignite_spot(a: int) -> void:
	if fire == null or (burn_left[a] > 0.0 and burn_spot[a] == 0):
		return
	if burn_left[a] <= 0.0:
		_burn_tick[a] = fire.burn_tick_sec
		burn_spot[a] = _rng.randi_range(SPOT_PARTS.x, SPOT_PARTS.y) + 1
	burn_left[a] = maxf(burn_left[a], fire.spot_burn_sec)


## Whole-body burners (spot fires excluded).
func burning_count() -> int:
	var n: int = 0
	for a: int in count:
		if burn_left[a] > 0.0 and burn_spot[a] == 0:
			n += 1
	return n


func spot_burning_count() -> int:
	var n: int = 0
	for a: int in count:
		if burn_left[a] > 0.0 and burn_spot[a] != 0:
			n += 1
	return n


## Burning step, after update(): ground fire lights zombies standing in it, water (off-grid) puts
## them out, burning ones spread to neighbours and take damage per tick. Burn deaths queue a charred
## corpse and no blood hit.
func update_fire(delta: float) -> void:
	if fire == null:
		return
	if ground_fire != null:
		ground_fire.update(delta)
	var heads: PackedInt32Array = spatial.heads()
	var nexts: PackedInt32Array = spatial.nexts()
	var w: int = grid.width
	var h: int = grid.height
	var r2: float = fire.spread_radius * fire.spread_radius
	var spread_p: float = clampf(fire.spread_chance_per_sec * delta, 0.0, 1.0)
	var victims: PackedInt32Array = PackedInt32Array()
	var lit: PackedInt32Array = PackedInt32Array()
	for a: int in count:
		var cell: Vector2i = grid.world_to_cell(positions[a])
		if not grid.in_bounds(cell):
			burn_left[a] = 0.0  # in the water
			continue
		if ground_fire != null and ground_fire.is_burning(grid.index_of(cell)):
			lit.append(a)
		if burn_left[a] <= 0.0:
			continue
		burn_left[a] = maxf(burn_left[a] - delta, 0.0)
		_burn_tick[a] -= delta
		if _burn_tick[a] <= 0.0:
			_burn_tick[a] += fire.burn_tick_sec
			victims.append(a)
		if burn_spot[a] == 0 and spread_p > 0.0 and _rng.randf() < spread_p:
			# The spatial hash is from this frame's update(); indices are still valid (no kills yet).
			for ny: int in range(maxi(cell.y - 1, 0), mini(cell.y + 2, h)):
				for nx: int in range(maxi(cell.x - 1, 0), mini(cell.x + 2, w)):
					var b: int = heads[ny * w + nx]
					while b != -1:
						if b != a and b < count and burn_left[b] <= 0.0 and positions[b].distance_squared_to(positions[a]) <= r2:
							lit.append(b)
						b = nexts[b]
	for a: int in lit:
		ignite(a)
	if victims.is_empty():
		return
	var dead: PackedInt32Array = PackedInt32Array()
	for a: int in victims:
		hp[a] -= fire.burn_damage if burn_spot[a] == 0 else fire.spot_burn_damage
		if hp[a] <= 0:
			dead.append(a)
	dead.sort()
	for i: int in range(dead.size() - 1, -1, -1):
		var a: int = dead[i]
		_queue_death(a, -heading[a], false, burn_spot[a] == 0)
		kill(a)
	kills += dead.size()


## One crowd step toward `target` (world XZ). The flow field must be computed beforehand.
func update(delta: float, target: Vector2) -> void:
	spatial.rebuild(positions, count)

	var heads: PackedInt32Array = spatial.heads()
	var nexts: PackedInt32Array = spatial.nexts()
	var blocked: PackedByteArray = grid.blocked
	var w: int = grid.width
	var h: int = grid.height
	var inv: float = 1.0 / grid.cell_size
	var ox: float = grid.origin.x
	var oy: float = grid.origin.y

	var pos: PackedVector2Array = positions
	var vel: PackedVector2Array = velocities
	var cooldown: PackedFloat32Array = _attack_cooldown
	var head: PackedVector2Array = heading
	var clip: PackedByteArray = anim
	var clip_t: PackedFloat32Array = anim_time
	var inv_stride: float = 1.0 / config.walk_stride
	var attack_len: float = config.attack_anim_sec
	var flinch_len: float = config.flinch_anim_sec
	var slow: PackedFloat32Array = slow_left
	var slow_mul: float = 1.0 - config.hit_slow
	var burn: PackedFloat32Array = burn_left
	var spot: PackedByteArray = burn_spot
	var burn_mul: float = fire.burn_speed_mul if fire != null else 1.0

	var sep_dist: float = config.radius * 2.0
	var sep_dist2: float = sep_dist * sep_dist
	var sep_k: float = config.separation_strength
	var attack_r2: float = config.attack_range * config.attack_range
	var stop_r2: float = attack_r2 * 0.6
	var turn: float = clampf(config.steering * delta, 0.0, 1.0)
	var max_step: float = grid.cell_size * 0.45
	var max_step2: float = max_step * max_step
	var target_cell: Vector2i = Vector2i(floori((target.x - ox) * inv), floori((target.y - oy) * inv))

	for a: int in count:
		var p: Vector2 = pos[a]
		var cx: int = floori((p.x - ox) * inv)
		var cy: int = floori((p.y - oy) * inv)
		var in_grid: bool = cx >= 0 and cy >= 0 and cx < w and cy < h

		var to_target: Vector2 = target - p
		var dist2: float = to_target.length_squared()
		var desired: Vector2 = Vector2.ZERO
		if dist2 > stop_r2:
			if in_grid and not (cx == target_cell.x and cy == target_cell.y):
				desired = flow.direction_at(cy * w + cx)
			if desired == Vector2.ZERO:
				desired = to_target / sqrt(dist2)
			desired *= config.speed * speed_scale[a] * (slow_mul if slow[a] > 0.0 else 1.0) 				* (burn_mul if burn[a] > 0.0 and spot[a] == 0 else 1.0)
		slow[a] = maxf(slow[a] - delta, 0.0)

		# Separation from neighbours in the 3x3 cells around.
		var push: Vector2 = Vector2.ZERO
		if in_grid:
			for ny: int in range(maxi(cy - 1, 0), mini(cy + 2, h)):
				for nx: int in range(maxi(cx - 1, 0), mini(cx + 2, w)):
					var b: int = heads[ny * w + nx]
					while b != -1:
						if b != a:
							var d: Vector2 = p - pos[b]
							var d2: float = d.length_squared()
							if d2 < sep_dist2 and d2 > 0.000001:
								var dl: float = sqrt(d2)
								push += d * ((sep_dist - dl) / dl)
						b = nexts[b]

		# Separation displaces directly (position-based) so it never builds up momentum.
		var v: Vector2 = vel[a].lerp(desired, turn)
		var step: Vector2 = v * delta + push * minf(sep_k * delta, 0.5)
		# Under half a cell per frame, so the destination-cell check can't skip a 1-cell wall
		# (a dense pile summed ~1.7 m of push in one frame).
		if step.length_squared() > max_step2:
			step = step.normalized() * max_step
		var np: Vector2 = p + step

		# Slide along blocked cells one axis at a time.
		var nx_cell: int = floori((np.x - ox) * inv)
		if nx_cell < 0 or nx_cell >= w or (in_grid and blocked[cy * w + nx_cell] != 0):
			np.x = p.x
			v.x = 0.0
			nx_cell = cx
		var ny_cell: int = floori((np.y - oy) * inv)
		if ny_cell < 0 or ny_cell >= h or (nx_cell >= 0 and nx_cell < w and blocked[ny_cell * w + nx_cell] != 0):
			np.y = p.y
			v.y = 0.0

		pos[a] = np
		vel[a] = v

		var speed2: float = v.length_squared()
		if speed2 > 0.04:
			head[a] = v / sqrt(speed2)
		elif dist2 > 0.0001:
			head[a] = head[a].lerp(to_target / sqrt(dist2), turn).normalized()

		cooldown[a] -= delta
		var attacking: bool = dist2 <= attack_r2 and cooldown[a] <= 0.0
		if attacking:
			cooldown[a] = config.attack_interval
			hits_on_target += 1

		if attacking:
			clip[a] = Anim.ATTACK
			clip_t[a] = 0.0
		elif clip[a] == Anim.WALK:
			clip_t[a] = fposmod(clip_t[a] + (np - p).length() * inv_stride, 1.0)
		else:
			clip_t[a] += delta
			if clip_t[a] >= (attack_len if clip[a] == Anim.ATTACK else flinch_len):
				clip[a] = Anim.WALK
				clip_t[a] = 0.0

	positions = pos
	velocities = vel
	heading = head
	anim = clip
	anim_time = clip_t
	slow_left = slow
	_attack_cooldown = cooldown
