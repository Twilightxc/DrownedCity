class_name InteriorHordes
extends Node3D
## Zombies inside one building (GDD §5, PHASE0 0.8 part 2): a Horde + flow field + renderer per walkable
## storey, on that storey's NavGrid. They start dormant (standing still, no flow) and wake by noise (shots,
## blasts; damped through one floor), by sight (line of sight to the player) or next to an awake one.
## Awake zombies chase the player across storeys: on another storey they head for the stair flight toward
## the player, and an agent past the middle of a flight moves into the other storey's horde (the same rule
## that moves the player). Each flight's wrong end is blocked in the zombie grids, so they climb it from
## its foot instead of stepping onto its top from the landing below.

var config: InteriorHordeConfig
var horde_config: HordeConfig
var layout: InteriorLayout
var hordes: Array[Horde] = []  ## per storey; null = flooded (not walkable)
var grids: Array[NavGrid] = []  ## per storey: the player's grid with the wrong flight ends blocked

var _renderers: Array[HordeRenderer] = []
var _flow_cell: Array[Vector2i] = []
var _flow_timer: PackedFloat32Array = PackedFloat32Array()
var _check_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(p_layout: InteriorLayout, p_config: InteriorHordeConfig, p_horde_config: HordeConfig,
		models: Array[VatModel], fire: FireConfig, rng_seed: int) -> void:
	layout = p_layout
	config = p_config
	horde_config = p_horde_config
	_rng.seed = rng_seed
	var walkable: int = 0
	for s: int in layout.storeys:
		if s > layout.flooded:
			walkable += 1
	var capacity: int = maxi(config.per_storey * walkable, 1)
	for s: int in layout.storeys:
		var grid: NavGrid = layout.nav_grid(s)
		_block_wrong_ends(s, grid)
		grids.append(grid)
		_flow_cell.append(Vector2i(-1, -1))
		_flow_timer.append(0.0)
		if s <= layout.flooded:
			hordes.append(null)
			_renderers.append(null)
			continue
		var horde: Horde = Horde.new(horde_config, grid, capacity, _rng.randi())
		horde.fire = fire
		hordes.append(horde)
		var r: HordeRenderer = HordeRenderer.new()
		r.models = models
		add_child(r)
		r.setup(capacity)
		r.visible = false
		_renderers.append(r)
		_populate(s)


func horde_at(storey: int) -> Horde:
	return hordes[storey] if storey >= 0 and storey < hordes.size() else null


func total_count() -> int:
	var n: int = 0
	for h: Horde in hordes:
		if h != null:
			n += h.count
	return n


func awake_count() -> int:
	var n: int = 0
	for h: Horde in hordes:
		if h != null:
			n += h.awake_count()
	return n


## A sound at `at` on `storey`: sleepers within `radius` wake, and within radius × floor_damping on the
## storeys just above and below.
func noise(at: Vector2, storey: int, radius: float) -> void:
	for s: int in hordes.size():
		var h: Horde = hordes[s]
		if h == null or absi(s - storey) > 1:
			continue
		var r: float = radius if s == storey else radius * config.floor_damping
		var r2: float = r * r
		for a: int in h.count:
			if h.dormant[a] != 0 and h.positions[a].distance_squared_to(at) <= r2:
				h.dormant[a] = 0


## One step. `player_storey` = -1 while the player is outside: awake zombies then gather at the landing
## under the roof hatch.
func step(delta: float, player_storey: int, player_pos: Vector2) -> void:
	var chase: int = player_storey if player_storey >= 0 else layout.storeys - 1
	var goal: Vector2 = player_pos if player_storey >= 0 else top_landing()
	_check_left -= delta
	var check: bool = _check_left <= 0.0
	if check:
		_check_left = config.check_sec
	for s: int in hordes.size():
		var h: Horde = hordes[s]
		if h == null:
			continue
		if check:
			_wake_checks(s, player_storey, player_pos)
		if h.count == 0 or h.awake_count() == 0:
			h.spatial.rebuild(h.positions, h.count)  # the player's hitscan reads it; update() isn't run
			continue
		var target: Vector2 = goal
		var cell: Vector2i = grids[s].world_to_cell(goal)
		var attack: bool = s == player_storey
		if chase > s:
			var top: int = s + 1
			cell = _flight_end(top, true) + _flight_step_down(top)
			target = layout.cell_center(_flight_end(top, true))
			attack = false
		elif chase < s:
			cell = _flight_end(s, false) - _flight_step_down(s)
			target = layout.cell_center(_flight_end(s, false))
			attack = false
		_flow_timer[s] -= delta
		if cell != _flow_cell[s] and _flow_timer[s] <= 0.0:
			h.recompute_flow([cell] as Array[Vector2i])
			_flow_cell[s] = cell
			_flow_timer[s] = horde_config.flow_recompute_sec
		h.update(delta, target, attack)
		h.update_fire(delta)
		_follow_stairs(s)


## Draws the storey the player is on and the one below (zombies coming up the stairs); nothing outside.
func sync(player_storey: int) -> void:
	for s: int in hordes.size():
		var r: HordeRenderer = _renderers[s]
		if r == null:
			continue
		r.visible = player_storey >= 0 and (s == player_storey or s == player_storey - 1)
		if r.visible:
			r.sync(hordes[s], layout.floor_y(s))


func top_landing() -> Vector2:
	return layout.cell_center(Vector2i(InteriorLayout.STAIR_X0 - 1, layout.corridor_row))


## Top (`top_end` = true) or foot cell of the flight from storey `top` down to `top - 1`.
func _flight_end(top: int, top_end: bool) -> Vector2i:
	var east: bool = layout.flight_top_east(top) == top_end
	var x: int = InteriorLayout.STAIR_X0 + InteriorLayout.FLIGHT_LEN - 1 if east else InteriorLayout.STAIR_X0
	return Vector2i(x, layout.flight_row(top))


## One cell along the flight from its top toward its foot.
func _flight_step_down(top: int) -> Vector2i:
	return Vector2i(-1, 0) if layout.flight_top_east(top) else Vector2i(1, 0)


func _block_wrong_ends(s: int, grid: NavGrid) -> void:
	if s >= 1 and layout.flight_open(s):  # own flight down: no stepping onto its foot from this floor
		grid.blocked[grid.index_of(_flight_end(s, false))] = 1
	if s + 1 < layout.storeys and layout.flight_open(s + 1):  # flight up: no stepping onto its top
		grid.blocked[grid.index_of(_flight_end(s + 1, true))] = 1


func _populate(s: int) -> void:
	var h: Horde = hordes[s]
	var grid: NavGrid = grids[s]
	var landing: Vector2 = top_landing()
	var cells: Array[Vector2i] = []
	for y: int in grid.height:
		for x: int in grid.width:
			var c: Vector2i = Vector2i(x, y)
			if not grid.is_walkable(c) or layout.cell(s, c) == InteriorLayout.Cell.STAIR:
				continue
			if layout.cell_center(c).distance_to(landing) < config.hatch_clear:
				continue
			cells.append(c)
	for i: int in mini(config.per_storey, cells.size()):
		var k: int = _rng.randi_range(i, cells.size() - 1)
		var c: Vector2i = cells[k]
		cells[k] = cells[i]
		var p: Vector2 = layout.cell_center(c) + Vector2(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.25, 0.25))
		if h.spawn(p):
			h.dormant[h.count - 1] = 1
			h.heading[h.count - 1] = Vector2.from_angle(_rng.randf() * TAU)


func _wake_checks(s: int, player_storey: int, player_pos: Vector2) -> void:
	var h: Horde = hordes[s]
	var sight2: float = config.sight * config.sight
	var chain2: float = config.chain * config.chain
	for a: int in h.count:
		if h.dormant[a] == 0:
			continue
		var p: Vector2 = h.positions[a]
		if s == player_storey and p.distance_squared_to(player_pos) <= sight2 \
				and grids[s].line_of_sight(p, player_pos):
			h.dormant[a] = 0
			continue
		for b: int in h.count:
			if h.dormant[b] == 0 and p.distance_squared_to(h.positions[b]) <= chain2:
				h.dormant[a] = 0
				break


## Stair heights for drawing, and agents past the middle of a flight move to the other storey's horde.
func _follow_stairs(s: int) -> void:
	var h: Horde = hordes[s]
	var floor_y: float = layout.floor_y(s)
	for a: int in range(h.count - 1, -1, -1):
		var on: Array = layout.stair_at(s, h.positions[a])
		if on.is_empty():
			h.lift[a] = 0.0
			continue
		var to: int = on[1]
		h.lift[a] = on[0] - floor_y
		if to == s or hordes[to] == null:
			continue
		var other: Horde = hordes[to]
		if h.transfer(a, other):
			other.lift[other.count - 1] = on[0] - layout.floor_y(to)
