class_name FlowField
extends RefCounted
## Shared flow field: one BFS from all targets, then one direction per cell.
## Every agent samples its cell instead of pathfinding on its own.
## Directions are resolved lazily, only for cells an agent actually samples
## (a full pass over every cell cost ~7 ms per recompute in the web build).

const UNREACHABLE: int = 0x7fffffff

var grid: NavGrid
var distance: PackedInt32Array

var _direction: PackedVector2Array
var _direction_gen: PackedInt32Array  # generation each cell's direction was resolved in
var _generation: int = 0
var _queue: PackedInt32Array


func _init(nav: NavGrid) -> void:
	grid = nav
	distance.resize(nav.cell_count())
	distance.fill(UNREACHABLE)
	_direction.resize(nav.cell_count())
	_direction_gen.resize(nav.cell_count())
	_queue.resize(nav.cell_count())


## `extra_cost` (optional, one byte per cell): extra steps to enter that cell, e.g. ground fire.
## Empty = plain BFS, the fast path.
func compute(targets: Array[Vector2i], extra_cost: PackedByteArray = PackedByteArray()) -> void:
	var w: int = grid.width
	var h: int = grid.height
	var blocked: PackedByteArray = grid.blocked
	distance.fill(UNREACHABLE)
	var head: int = 0
	var tail: int = 0
	for target: Vector2i in targets:
		if not grid.is_walkable(target):
			continue
		var ti: int = grid.index_of(target)
		if distance[ti] != 0:
			distance[ti] = 0
			_queue[tail] = ti
			tail += 1

	if not extra_cost.is_empty():
		_relax_weighted(head, tail, extra_cost)
		_generation += 1
		return

	# 4-neighbour BFS: integer steps are enough for a crowd heading to one spot.
	while head < tail:
		var i: int = _queue[head]
		head += 1
		var x: int = i % w
		var y: int = i / w
		var nd: int = distance[i] + 1
		if x > 0 and blocked[i - 1] == 0 and distance[i - 1] > nd:
			distance[i - 1] = nd
			_queue[tail] = i - 1
			tail += 1
		if x < w - 1 and blocked[i + 1] == 0 and distance[i + 1] > nd:
			distance[i + 1] = nd
			_queue[tail] = i + 1
			tail += 1
		if y > 0 and blocked[i - w] == 0 and distance[i - w] > nd:
			distance[i - w] = nd
			_queue[tail] = i - w
			tail += 1
		if y < h - 1 and blocked[i + w] == 0 and distance[i + w] > nd:
			distance[i + w] = nd
			_queue[tail] = i + w
			tail += 1

	_generation += 1


## Weighted 4-neighbour search: a FIFO that re-queues a cell when its distance improves (SPFA).
## Costs are 1 almost everywhere, so it does close to BFS work; the few costly cells re-queue a little.
func _relax_weighted(head: int, tail: int, extra_cost: PackedByteArray) -> void:
	var w: int = grid.width
	var h: int = grid.height
	var n: int = grid.cell_count()
	var blocked: PackedByteArray = grid.blocked
	var queued: PackedByteArray = PackedByteArray()
	queued.resize(n)
	for k: int in range(head, tail):
		queued[_queue[k]] = 1
	var size: int = tail - head
	while size > 0:
		var i: int = _queue[head]
		head = (head + 1) % n
		size -= 1
		queued[i] = 0
		var x: int = i % w
		var y: int = i / w
		var d: int = distance[i]
		for k: int in 4:
			var j: int
			if k == 0:
				if x == 0: continue
				j = i - 1
			elif k == 1:
				if x == w - 1: continue
				j = i + 1
			elif k == 2:
				if y == 0: continue
				j = i - w
			else:
				if y == h - 1: continue
				j = i + w
			if blocked[j] != 0:
				continue
			var nd: int = d + 1 + extra_cost[j]
			if nd < distance[j]:
				distance[j] = nd
				if queued[j] == 0:
					queued[j] = 1
					_queue[(head + size) % n] = j
					size += 1


## Direction to steer at world position p; ZERO on a target cell, unreachable cell or off-grid.
func sample(p: Vector2) -> Vector2:
	var cell: Vector2i = grid.world_to_cell(p)
	if not grid.in_bounds(cell):
		return Vector2.ZERO
	return direction_at(grid.index_of(cell))


## Unit direction for a cell index, resolved on first use after each compute().
func direction_at(i: int) -> Vector2:
	if _direction_gen[i] != _generation:
		_direction_gen[i] = _generation
		_direction[i] = _resolve_direction(i)
	return _direction[i]


func distance_at(cell: Vector2i) -> int:
	return distance[grid.index_of(cell)] if grid.in_bounds(cell) else UNREACHABLE


func _resolve_direction(i: int) -> Vector2:
	var d: int = distance[i]
	if d == 0 or d == UNREACHABLE:
		return Vector2.ZERO
	var w: int = grid.width
	var h: int = grid.height
	var blocked: PackedByteArray = grid.blocked
	var x: int = i % w
	var y: int = i / w
	var best: int = d
	var best_dir: Vector2 = Vector2.ZERO
	for dy: int in range(-1, 2):
		var ny: int = y + dy
		if ny < 0 or ny >= h:
			continue
		for dx: int in range(-1, 2):
			var nx: int = x + dx
			if (dx == 0 and dy == 0) or nx < 0 or nx >= w:
				continue
			var ni: int = ny * w + nx
			if blocked[ni] != 0:
				continue
			# Diagonals only when both orthogonal cells are open (no corner cutting).
			if dx != 0 and dy != 0 and (blocked[y * w + nx] != 0 or blocked[ny * w + x] != 0):
				continue
			var nd: int = distance[ni]
			if nd < best or (nd == best and nd < d and dx != 0 and dy != 0):
				best = nd
				best_dir = Vector2(dx, dy)
	return best_dir.normalized()
