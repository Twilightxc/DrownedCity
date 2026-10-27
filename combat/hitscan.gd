class_name Hitscan
extends RefCounted
## Bullet ray vs. horde through the spatial hash (no physics engine).
## Walks every grid cell the ray crosses, tests agents in nearby cells once each,
## stops at the first blocked cell, and returns hits ordered along the ray.

var grid: NavGrid

var _visit_stamp: PackedInt32Array
var _stamp: int = 0
var _cand_agent: PackedInt32Array
var _cand_t: PackedFloat32Array


func _init(nav: NavGrid) -> void:
	grid = nav
	_visit_stamp.resize(nav.cell_count())


## Fills `out_hits` with up to `max_hits` agent indices, nearest first.
## Returns the distance the bullet travelled (to a wall or max_range).
func cast(horde: Horde, from: Vector2, dir: Vector2, max_range: float, max_hits: int, out_hits: PackedInt32Array) -> float:
	out_hits.clear()
	_cand_agent.clear()
	_cand_t.clear()
	_stamp += 1
	dir = dir.normalized()
	var radius: float = horde.config.radius
	var r2: float = radius * radius
	var heads: PackedInt32Array = horde.spatial.heads()
	var nexts: PackedInt32Array = horde.spatial.nexts()
	var pos: PackedVector2Array = horde.positions
	var w: int = grid.width
	var h: int = grid.height

	# Grid traversal (Amanatides & Woo): visit every cell the ray crosses, in order,
	# so a ray clipping only a wall's corner still stops there. Same corner rule as
	# NavGrid.ray_distance: through a corner exactly, either side cell blocks.
	var cs: float = grid.cell_size
	var c: Vector2i = grid.world_to_cell(from)
	var step_x: int = 1 if dir.x > 0.0 else -1
	var step_y: int = 1 if dir.y > 0.0 else -1
	var t_delta_x: float = cs / absf(dir.x) if dir.x != 0.0 else INF
	var t_delta_y: float = cs / absf(dir.y) if dir.y != 0.0 else INF
	var next_x: float = grid.origin.x + (c.x + (1 if step_x > 0 else 0)) * cs
	var next_y: float = grid.origin.y + (c.y + (1 if step_y > 0 else 0)) * cs
	var t_max_x: float = (next_x - from.x) / dir.x if dir.x != 0.0 else INF
	var t_max_y: float = (next_y - from.y) / dir.y if dir.y != 0.0 else INF

	var end_t: float = max_range
	var t: float = 0.0  # distance at which the ray entered cell c
	while t <= end_t:
		if grid.blocks_ray(c):
			end_t = t
			break
		for cy: int in range(maxi(c.y - 1, 0), mini(c.y + 2, h)):
			for cx: int in range(maxi(c.x - 1, 0), mini(c.x + 2, w)):
				var ci: int = cy * w + cx
				if _visit_stamp[ci] == _stamp:
					continue
				_visit_stamp[ci] = _stamp
				var a: int = heads[ci]
				while a != -1:
					var rel: Vector2 = pos[a] - from
					var along: float = rel.dot(dir)
					if along >= 0.0 and (rel - dir * along).length_squared() <= r2:
						_cand_agent.append(a)
						_cand_t.append(along)
					a = nexts[a]
		if t_max_x < t_max_y:
			t = t_max_x
			t_max_x += t_delta_x
			c.x += step_x
		elif t_max_y < t_max_x:
			t = t_max_y
			t_max_y += t_delta_y
			c.y += step_y
		else:  # exact corner: the side cells are inside the 3x3 block already searched
			t = t_max_x
			if t <= end_t and (grid.blocks_ray(Vector2i(c.x + step_x, c.y)) or grid.blocks_ray(Vector2i(c.x, c.y + step_y))):
				end_t = t
				break
			t_max_x += t_delta_x
			t_max_y += t_delta_y
			c += Vector2i(step_x, step_y)

	# Insertion sort: a handful of candidates per shot.
	var n: int = _cand_agent.size()
	for i: int in range(1, n):
		var ka: int = _cand_agent[i]
		var kt: float = _cand_t[i]
		var j: int = i - 1
		while j >= 0 and _cand_t[j] > kt:
			_cand_agent[j + 1] = _cand_agent[j]
			_cand_t[j + 1] = _cand_t[j]
			j -= 1
		_cand_agent[j + 1] = ka
		_cand_t[j + 1] = kt

	for i: int in n:
		if _cand_t[i] > end_t:
			break
		out_hits.append(_cand_agent[i])
		if out_hits.size() >= max_hits:
			return _cand_t[i]  # penetration used up: the bullet stops in this body
	return end_t
