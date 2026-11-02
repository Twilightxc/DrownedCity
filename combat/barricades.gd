class_name Barricades
extends RefCounted
## Breakable barricades on a NavGrid (Phase 1 step 1.5; GDD §4 base defences). A barricade is a set of cells
## that blocks movement (zombies and the player) but not bullets, and that the flow field crosses at a
## cost, so the crowd goes round when that's shorter and otherwise piles up against it and tears it down.

var grid: NavGrid
var cells: Array[PackedInt32Array] = []  ## per barricade: its cell indices
var hp: PackedInt32Array = PackedInt32Array()
var max_hp: PackedInt32Array = PackedInt32Array()
var owner: PackedInt32Array = PackedInt32Array()  ## per cell: barricade id, -1 = none
var cost: PackedByteArray = PackedByteArray()  ## per cell: extra flow-field steps (for FlowField.compute)
var revision: int = 0  ## bumps when one falls (the flow field must be recomputed)
var step_cost: int = 8


func _init(nav: NavGrid, flow_cost: int = 8) -> void:
	grid = nav
	step_cost = flow_cost
	owner.resize(nav.cell_count())
	owner.fill(-1)
	cost.resize(nav.cell_count())


## Adds a barricade over `at` (walkable cells only); returns its id.
func add(at: Array[Vector2i], hit_points: int) -> int:
	var id: int = cells.size()
	var list: PackedInt32Array = PackedInt32Array()
	for c: Vector2i in at:
		if not grid.is_walkable(c):
			continue
		var i: int = grid.index_of(c)
		owner[i] = id
		cost[i] = step_cost
		list.append(i)
	cells.append(list)
	hp.append(hit_points)
	max_hp.append(hit_points)
	revision += 1
	return id


func standing(id: int) -> bool:
	return hp[id] > 0


## True if cell index `i` is part of a standing barricade.
func solid(i: int) -> bool:
	return owner[i] >= 0 and hp[owner[i]] > 0


func solid_world(p: Vector2) -> bool:
	var c: Vector2i = grid.world_to_cell(p)
	return grid.in_bounds(c) and solid(grid.index_of(c))


## Damage from a zombie; returns true if this hit brought it down.
func damage(id: int, amount: int) -> bool:
	if hp[id] <= 0:
		return false
	hp[id] = maxi(hp[id] - amount, 0)
	if hp[id] > 0:
		return false
	for i: int in cells[id]:
		cost[i] = 0
	revision += 1
	return true
