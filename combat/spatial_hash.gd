class_name SpatialHash
extends RefCounted
## Per-frame bucket grid of agent indices over a NavGrid.
## Buckets are linked lists in flat arrays, so a rebuild allocates nothing.

var grid: NavGrid

var _head: PackedInt32Array  # per cell: first agent index or -1
var _next: PackedInt32Array  # per agent: next agent in the same cell or -1


func _init(nav: NavGrid, max_agents: int) -> void:
	grid = nav
	_head.resize(nav.cell_count())
	_head.fill(-1)
	_next.resize(max_agents)


func rebuild(positions: PackedVector2Array, count: int) -> void:
	_head.fill(-1)
	var w: int = grid.width
	var h: int = grid.height
	var inv: float = 1.0 / grid.cell_size
	var ox: float = grid.origin.x
	var oy: float = grid.origin.y
	for a: int in count:
		var p: Vector2 = positions[a]
		var cx: int = clampi(floori((p.x - ox) * inv), 0, w - 1)
		var cy: int = clampi(floori((p.y - oy) * inv), 0, h - 1)
		var ci: int = cy * w + cx
		_next[a] = _head[ci]
		_head[ci] = a


func first(cell_index: int) -> int:
	return _head[cell_index]


func next(agent: int) -> int:
	return _next[agent]


## Raw arrays for hot loops (read-only; copy-on-write keeps them cheap).
func heads() -> PackedInt32Array:
	return _head


func nexts() -> PackedInt32Array:
	return _next


## Appends to `out` every agent within `radius` of p. Returns the number appended.
func query_radius(positions: PackedVector2Array, p: Vector2, radius: float, out: PackedInt32Array) -> int:
	var found: int = 0
	var r2: float = radius * radius
	var c0: Vector2i = grid.world_to_cell(p - Vector2(radius, radius))
	var c1: Vector2i = grid.world_to_cell(p + Vector2(radius, radius))
	for cy: int in range(maxi(c0.y, 0), mini(c1.y, grid.height - 1) + 1):
		for cx: int in range(maxi(c0.x, 0), mini(c1.x, grid.width - 1) + 1):
			var a: int = _head[cy * grid.width + cx]
			while a != -1:
				if positions[a].distance_squared_to(p) <= r2:
					out.append(a)
					found += 1
				a = _next[a]
	return found
