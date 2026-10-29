class_name InteriorLayout
extends RefCounted
## Seeded floor plans for one building (GDD §5, PHASE0 0.8). Pure data: a cell type per 1 m cell per
## storey (the NavGrid cell), furniture, and the stair flights that link storeys. InteriorBuilder turns it
## into meshes and NavGrids.
##
## Plan per storey: outer wall ring with windows, a 2-cell corridor along X through the middle, rooms north
## and south of it split by partition walls, one door from each room into the corridor. The corridor's west
## end is the stairwell: two 1-cell flights side by side (a switchback), landings at x = 1 and x = 6.
## Each flight spans a whole storey, so every other storey meets the stairs at the west landing, which
## the flights cut off from the corridor: a door from that landing into the first north room (always wide
## enough to have its own corridor door) is the way out.
## Storey 0 is the lowest; storeys at or below `flooded` are under water (drawn, not walkable).

enum Cell { OUTSIDE, FLOOR, WALL, WINDOW, DOOR, STAIR }

const STOREY: float = 3.2
const STAIR_X0: int = 2  ## first flight cell; landings at STAIR_X0 - 1 and STAIR_X0 + FLIGHT_LEN
const FLIGHT_LEN: int = 4
const ROOM_MIN: int = 4
const ROOM_MAX: int = 7
const FURNITURE: PackedStringArray = ["bed", "table", "shelf", "sofa", "crate"]
const TWO_CELL: PackedStringArray = ["bed", "sofa"]


class Item:
	var kind: String
	var cells: Array[Vector2i] = []
	var yaw: float  ## radians about Y; the piece's back faces the wall it stands against


var width: int
var depth: int
var storeys: int
var origin: Vector2  ## world XZ of cell (0, 0)'s corner
var base_y: float  ## world floor height of storey 0
var flooded: int = -1  ## storeys 0..flooded are under water
var corridor_row: int  ## north row of the corridor; the corridor is this row and the next
var cells: Array[PackedByteArray] = []
var furniture: Array = []  ## per storey: Array of Item

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func generate(w: int, d: int, p_storeys: int, p_seed: int, p_origin: Vector2, p_base_y: float,
		p_flooded: int = -1) -> InteriorLayout:
	var l: InteriorLayout = InteriorLayout.new()
	l.width = w
	l.depth = d
	l.storeys = p_storeys
	l.origin = p_origin
	l.base_y = p_base_y
	l.flooded = p_flooded
	l.corridor_row = d / 2 - 1
	for s: int in p_storeys:
		l._rng.seed = hash([p_seed, s])
		l._plan_storey()
	return l


func floor_y(storey: int) -> float:
	return base_y + storey * STOREY


func index(c: Vector2i) -> int:
	return c.y * width + c.x


func cell(storey: int, c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= depth:
		return Cell.OUTSIDE
	return cells[storey][index(c)]


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x - origin.x), floori(p.y - origin.y))


func cell_center(c: Vector2i) -> Vector2:
	return origin + Vector2(c) + Vector2(0.5, 0.5)


## Row of the flight that runs from `top` down to `top - 1`; neighbouring flights alternate rows.
func flight_row(top: int) -> int:
	return corridor_row + (top % 2)


## True when the flight from `top` reaches its upper end at the east landing.
func flight_top_east(top: int) -> bool:
	return top % 2 == 0


func flight_open(top: int) -> bool:
	return top >= 1 and top < storeys and top - 1 > flooded


## Height of a point on a flight drawn in `storey`'s grid (its own flight down or the one up), and the
## storey the player belongs to there. Returns [] off the stairs.
func stair_at(storey: int, p: Vector2) -> Array:
	var c: Vector2i = world_to_cell(p)
	for top: int in [storey, storey + 1]:
		if top < 1 or top >= storeys or c.y != flight_row(top):
			continue
		if c.x < STAIR_X0 or c.x >= STAIR_X0 + FLIGHT_LEN:
			continue
		var x0: float = origin.x + STAIR_X0
		var t: float = (x0 + FLIGHT_LEN - p.x) / FLIGHT_LEN if flight_top_east(top) else (p.x - x0) / FLIGHT_LEN
		t = clampf(t, 0.0, 1.0)  # 0 at the top landing, 1 at the bottom
		var y: float = floor_y(top) - t * STOREY
		return [y, top if t < 0.5 else top - 1]
	return []


## Walkable cells of a storey as a NavGrid (walls, windows, furniture and closed flights block).
func nav_grid(storey: int) -> NavGrid:
	var grid: NavGrid = NavGrid.new(width, depth, 1.0, origin)
	for y: int in depth:
		for x: int in width:
			var c: Vector2i = Vector2i(x, y)
			var t: int = cell(storey, c)
			var walk: bool = storey > flooded and (t == Cell.FLOOR or t == Cell.DOOR or t == Cell.STAIR)
			if t == Cell.STAIR:
				var top: int = storey if y == flight_row(storey) else storey + 1
				walk = walk and flight_open(top)
			grid.blocked[index(c)] = 0 if walk else 1
	for item: Item in furniture[storey]:
		for c: Vector2i in item.cells:
			grid.blocked[index(c)] = 1
	return grid


## Walls and windows block sight; furniture and closed flights don't (dark rooms, PHASE0 0.8).
func sight_grid(storey: int) -> NavGrid:
	var grid: NavGrid = NavGrid.new(width, depth, 1.0, origin)
	for i: int in width * depth:
		var t: int = cells[storey][i]
		grid.blocked[i] = 0 if t == Cell.FLOOR or t == Cell.DOOR or t == Cell.STAIR else 1
	return grid


## Rooms of a storey: a region id per cell for floor and stair cells joined without crossing a wall, window
## or door (the corridor, its stairwell and the west landing are one region); -1 for every other cell.
func regions(storey: int) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	ids.resize(width * depth)
	ids.fill(-1)
	var next: int = 0
	for start: int in width * depth:
		if ids[start] != -1 or not _room_cell(storey, start):
			continue
		ids[start] = next
		var stack: PackedInt32Array = PackedInt32Array([start])
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var c: Vector2i = Vector2i(i % width, i / width)
			for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var m: Vector2i = c + n
				if m.x < 0 or m.y < 0 or m.x >= width or m.y >= depth:
					continue
				var j: int = index(m)
				if ids[j] == -1 and _room_cell(storey, j):
					ids[j] = next
					stack.append(j)
		next += 1
	return ids


func _room_cell(storey: int, i: int) -> bool:
	var t: int = cells[storey][i]
	return t == Cell.FLOOR or t == Cell.STAIR


func _plan_storey() -> void:
	var g: PackedByteArray = PackedByteArray()
	g.resize(width * depth)
	g.fill(Cell.FLOOR)
	cells.append(g)
	var s: int = cells.size() - 1
	# Outer ring; windows on straight runs, never on corners.
	for x: int in width:
		for y: int in [0, depth - 1]:
			_put(s, Vector2i(x, y), Cell.WINDOW if _window_ok(x, width) else Cell.WALL)
	for y: int in range(1, depth - 1):
		for x: int in [0, width - 1]:
			_put(s, Vector2i(x, y), Cell.WINDOW if _window_ok(y, depth) else Cell.WALL)
	# Corridor walls with the room blocks north (rows 1..corridor_row - 2) and south.
	var north_wall: int = corridor_row - 1
	var south_wall: int = corridor_row + 2
	for x: int in range(1, width - 1):
		_put(s, Vector2i(x, north_wall), Cell.WALL)
		_put(s, Vector2i(x, south_wall), Cell.WALL)
	var items: Array = []
	for side: int in [-1, 1]:
		var y0: int = 1 if side < 0 else south_wall + 1
		var y1: int = north_wall - 1 if side < 0 else depth - 2
		var door_row: int = north_wall if side < 0 else south_wall
		var x: int = 1
		while x < width - 1:
			var room_w: int = _rng.randi_range(ROOM_MIN, ROOM_MAX)
			var lobby: bool = side < 0 and x == 1
			if x == 1:  # first rooms reach past the stairwell, so they get a corridor door (else sealed)
				room_w = maxi(room_w, STAIR_X0 + FLIGHT_LEN + 2 - x)
			var x_end: int = mini(x + room_w, width - 1)  # partition column (or the outer wall)
			if width - 1 - x_end < ROOM_MIN:
				x_end = width - 1  # don't leave a sliver room at the east end
			if x_end < width - 1:
				for y: int in range(y0, y1 + 1):
					_put(s, Vector2i(x_end, y), Cell.WALL)
			# Door into the corridor, kept clear of the stairwell end.
			var dx_lo: int = maxi(x, STAIR_X0 + FLIGHT_LEN + 1)
			var dx_hi: int = x_end - 1
			if dx_lo <= dx_hi:
				var dx: int = _rng.randi_range(dx_lo, dx_hi)
				_put(s, Vector2i(dx, door_row), Cell.DOOR)
				var clear: Array[Vector2i] = []
				if lobby:
					_put(s, Vector2i(STAIR_X0 - 1, door_row), Cell.DOOR)
					clear.append(Vector2i(STAIR_X0 - 1, y1))
				_furnish(s, Rect2i(x, y0, x_end - x, y1 - y0 + 1), Vector2i(dx, y0 if side > 0 else y1), items, clear)
			x = x_end + 1
	# Stairwell at the corridor's west end: both rows, between the landings.
	for top: int in [s, s + 1]:
		if top >= 1 and top < storeys:
			for fx: int in range(STAIR_X0, STAIR_X0 + FLIGHT_LEN):
				_put(s, Vector2i(fx, flight_row(top)), Cell.STAIR)
	furniture.append(items)


func _window_ok(i: int, n: int) -> bool:
	return i > 0 and i < n - 1 and i % 2 == 1 and _rng.randf() < 0.75


func _put(s: int, c: Vector2i, t: int) -> void:
	cells[s][index(c)] = t


## 1-3 pieces along the room's walls, never on the cell inside the door or on a corner run.
func _furnish(s: int, room: Rect2i, door_inside: Vector2i, items: Array, more_doors: Array[Vector2i] = []) -> void:
	var taken: Dictionary[Vector2i, bool] = {}
	for d: Vector2i in [door_inside] + more_doors:
		for dx: int in [-1, 0, 1]:
			taken[d + Vector2i(dx, 0)] = true
	var count: int = _rng.randi_range(1, 3)
	for attempt: int in 12:
		if count <= 0:
			break
		var kind: String = FURNITURE[_rng.randi() % FURNITURE.size()]
		var along_x: bool = _rng.randf() < 0.5
		var c: Vector2i
		var yaw: float
		if along_x:  # against the north or south wall of the room
			var top_wall: bool = _rng.randf() < 0.5
			c = Vector2i(_rng.randi_range(room.position.x, room.end.x - 1), room.position.y if top_wall else room.end.y - 1)
			yaw = PI if top_wall else 0.0
		else:  # against the west or east wall
			var west: bool = _rng.randf() < 0.5
			c = Vector2i(room.position.x if west else room.end.x - 1, _rng.randi_range(room.position.y, room.end.y - 1))
			yaw = -PI / 2.0 if west else PI / 2.0
		var cells_used: Array[Vector2i] = [c]
		if kind in TWO_CELL:
			cells_used.append(c + (Vector2i(1, 0) if along_x else Vector2i(0, 1)))
		var ok: bool = true
		for u: Vector2i in cells_used:
			ok = ok and room.has_point(u) and not taken.has(u) and cell(s, u) == Cell.FLOOR
		if not ok:
			continue
		var item: Item = Item.new()
		item.kind = kind
		item.cells = cells_used
		item.yaw = yaw
		items.append(item)
		for u: Vector2i in cells_used:
			taken[u] = true
			for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				taken[u + n] = true  # keep a gap so rooms stay walkable around furniture
		count -= 1
