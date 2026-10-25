class_name Horde
extends RefCounted
## Real-time zombie crowd as struct-of-arrays. Live agents are packed in [0, count);
## killing swaps the last agent into the hole. No nodes, no physics bodies.

var config: HordeConfig
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

## Totals since start, read by the presentation layer and reported to SimCore later.
var kills: int = 0
var hits_on_target: int = 0

var _attack_cooldown: PackedFloat32Array
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
		_attack_cooldown[a] = _attack_cooldown[last]
	count = last


## Applies damage to the given agents (each listed once). Returns how many died.
func apply_damage(agents: PackedInt32Array, damage: int) -> int:
	var dead: PackedInt32Array = PackedInt32Array()
	for a: int in agents:
		hp[a] -= damage
		if hp[a] <= 0:
			dead.append(a)
	# Highest index first so swap-removal never moves a still-pending victim.
	dead.sort()
	for i: int in range(dead.size() - 1, -1, -1):
		kill(dead[i])
	kills += dead.size()
	return dead.size()


func recompute_flow(targets: Array[Vector2i]) -> void:
	flow.compute(targets)


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
			desired *= config.speed * speed_scale[a]

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

		cooldown[a] -= delta
		if dist2 <= attack_r2 and cooldown[a] <= 0.0:
			cooldown[a] = config.attack_interval
			hits_on_target += 1

	positions = pos
	velocities = vel
	_attack_cooldown = cooldown
