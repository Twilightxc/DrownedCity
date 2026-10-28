class_name GroundFire
extends RefCounted
## Timed burning cells on the NavGrid (GDD §6 ground fire). Capped; the flow field sees them as an
## extra step cost, and zombies standing in one catch fire. Water (off-grid) never burns.

var config: FireConfig
var grid: NavGrid
var cost: PackedByteArray  ## per cell: extra flow-field steps, 0 = not burning
var revision: int = 0  ## bumps whenever the set of burning cells changes (recompute the flow field)

var _life: PackedFloat32Array  ## per cell, s left
var _active: PackedInt32Array = PackedInt32Array()  ## burning cell indices, oldest first


func _init(cfg: FireConfig, nav: NavGrid) -> void:
	config = cfg
	grid = nav
	cost.resize(nav.cell_count())
	_life.resize(nav.cell_count())


func active_count() -> int:
	return _active.size()


func active_cells() -> PackedInt32Array:
	return _active


func is_burning(index: int) -> bool:
	return cost[index] != 0


## Lights a walkable cell (or refreshes it). At the cap the oldest cell goes out first.
func ignite(cell: Vector2i) -> bool:
	if not grid.is_walkable(cell) or config.cell_cap <= 0:
		return false
	var i: int = grid.index_of(cell)
	_life[i] = config.cell_life_sec
	if cost[i] != 0:
		return true
	if _active.size() >= config.cell_cap:
		_extinguish(_active[0])
		_active.remove_at(0)
	cost[i] = clampi(config.cell_cost, 1, 255)
	_active.append(i)
	revision += 1
	return true


## Lights up to `count` random walkable cells within `radius` of `center`.
func ignite_area(center: Vector2, radius: float, count: int, rng: RandomNumberGenerator) -> int:
	var lit: int = 0
	for k: int in count * 3:
		if lit >= count:
			break
		var p: Vector2 = center + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))
		if p.distance_squared_to(center) <= radius * radius and ignite(grid.world_to_cell(p)):
			lit += 1
	return lit


func update(delta: float) -> void:
	var k: int = _active.size() - 1
	while k >= 0:
		var i: int = _active[k]
		_life[i] -= delta
		if _life[i] <= 0.0:
			_extinguish(i)
			_active.remove_at(k)
		k -= 1


func _extinguish(i: int) -> void:
	cost[i] = 0
	_life[i] = 0.0
	revision += 1
