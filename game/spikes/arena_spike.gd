extends "res://game/spikes/twin_stick_spike.gd"
## Phase 1 step 1.5: "one night on the roof", the combat test arena on the real base roof (J, 2026-10-29).
## Zombies climb up at four entrances in waves from data (ArenaConfig): two entrances are barricaded and
## must be torn down first, two are open. Calm between waves: the supply crates refill once. The night
## ends when the last wave is cleared or you die; a summary shows and the run is logged locally.
## Gate 1.G: J plays it 3 times on the Arc and calls it fun (or not).

const POCKET_CROWD: int = 12  ## zombies waiting in one entrance pocket at most; more spawn later
## Barricade pieces (kit_props.py), [kind][stage]: nailed planks or an upright pallet, whole / battered / nearly gone.
const BARRICADE_PIECES: Array = [
	[preload("res://assets/models/prop_barricade_planks_0.glb"), preload("res://assets/models/prop_barricade_planks_1.glb"),
		preload("res://assets/models/prop_barricade_planks_2.glb")],
	[preload("res://assets/models/prop_barricade_pallet_0.glb"), preload("res://assets/models/prop_barricade_pallet_1.glb"),
		preload("res://assets/models/prop_barricade_pallet_2.glb")],
]

@export var arena: ArenaConfig = preload("res://data/combat/arena_roof.tres")
## AI teammates (1.5+ A5): one per loadout, named in order, on the leader's left then right.
@export var teammate_loadouts: Array[LoadoutConfig] = [preload("res://data/weapons/teammate_ar_loadout.tres"),
	preload("res://data/weapons/teammate_shotgun_loadout.tres")]
@export var teammate_names: PackedStringArray = PackedStringArray(["Marco", "Jess"])

var _director: WaveDirector
var _barricades: Barricades
var _bar_meshes: Array[MeshInstance3D] = []  ## per barricade id
var _bar_stage: PackedInt32Array = PackedInt32Array()  ## per barricade id: the damage stage its mesh shows
var _bar_cells: Array[Array] = []  ## per barricade id: its cells and the direction each faces (to the pocket)
var _piece_meshes: Dictionary[Vector2i, Mesh] = {}  ## (kind, stage) → the piece's mesh, read once
var _bar_rev: int = -1
var _pockets: Array[PackedVector2Array] = []  ## per entrance: spawn points (cell centres) at the roof edge
var _entrance_centres: PackedVector2Array = PackedVector2Array()
var _crates: Array[SupplyCrate] = []
var _banner: Label
var _summary: Label
var _summary_box: PanelContainer
var _was_phase: int = -1
var _elapsed: float = 0.0
var _hits_taken: int = 0
var _grenade_kills: int = 0
var _ended: bool = false
var _start_wave: int = 1  ## `?wave=N`: test runs that skip ahead are marked in the run log


func _ready() -> void:
	super._ready()
	_target_count = 0
	_count_slider.visible = false
	_start_wave = clampi(SpikeLauncher.arg("wave", "1").to_int(), 1, arena.waves.size())  # 1-based like the HUD
	_director = WaveDirector.new(arena, _rng.randi(), _start_wave - 1)
	_barricades = Barricades.new(_grid, arena.barricade_cost)
	_horde.barricades = _barricades
	_player.barricades = _barricades
	_build_entrances()
	for child: Node in get_children():
		if child is SupplyCrate:
			_crates.append(child as SupplyCrate)
	_refill_crates()
	_player.health.damaged.connect(func(_amount: int, kind: StringName) -> void:
		if kind == &"melee":
			_hits_taken += 1)
	if _grenades != null:
		_grenades.exploded.connect(func(_at: Vector3, killed: int, _cfg: ThrowableConfig) -> void:
			_grenade_kills += killed)
	_build_arena_ui()
	_spawn_teammates()


## `?mates=N` (desktop `--mates=N`) fields fewer teammates, 0 for none: compare the fight with and without them.
func _spawn_teammates() -> void:
	var count: int = clampi(SpikeLauncher.arg("mates", str(teammate_loadouts.size())).to_int(), 0, teammate_loadouts.size())
	for i: int in count:
		var m: Teammate = Teammate.new()
		m.loadout = teammate_loadouts[i]
		m.body_look = i + 1  # the player wears look 0
		m.controls = _player.controls
		m.display_name = teammate_names[i] if i < teammate_names.size() else "Teammate %d" % (i + 1)
		var marker: Node3D = Node3D.new()
		marker.name = "AimMarker"
		m.add_child(marker)
		add_child(m)
		m.setup(_grid, _horde, _camera, GROUND_Y)
		m.barricades = _barricades
		var side: float = 1.0 if i % 2 == 0 else -1.0
		m.brain.side = side
		var spot: Vector2 = m.brain.follow_spot(_player.ground_position(), _player.aim_dir)
		if not _grid.is_walkable_world(spot):
			spot = _player.ground_position()
		m.position = Vector3(spot.x, GROUND_Y, spot.y)
		add_teammate(m)


func _process(delta: float) -> void:
	super._process(delta)
	if _barricades.revision != _bar_rev:
		_bar_rev = _barricades.revision
		_flow_cells.clear()  # a barricade fell: recompute the flow field now
		_flow_timer = 0.0
	_update_barricade_meshes()
	if _ended:
		return
	if _player.health.is_alive():
		_elapsed += delta
	if _director.phase != _was_phase:
		_on_phase_changed()
		_was_phase = _director.phase
	_update_arena_ui()
	if _director.phase == WaveDirector.Phase.WON or _player.health.state == FighterHealth.State.DEAD:
		_end_run()


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if _ended and _director.phase == WaveDirector.Phase.WON and event.is_action_pressed("reload"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()


## Spawns come from the wave director instead of the spike's horde-size slider.
func _spawn(delta: float, _target: Vector2) -> void:
	for req: Vector2i in _director.step(delta, _horde.count):
		var e: int = req.y
		var placed: bool = false
		if _crowd_at(e) < POCKET_CROWD:
			var spots: PackedVector2Array = _pockets[e]
			var p: Vector2 = spots[_rng.randi() % spots.size()] + Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3))
			placed = _horde.spawn(p, req.x, Horde.State.HUNTING)
		if not placed:
			_director.refund(req.x)


func _crowd_at(e: int) -> int:
	var c: Vector2 = _entrance_centres[e]
	var n: int = 0
	for a: int in _horde.count:
		if _horde.positions[a].distance_squared_to(c) < 2.5 * 2.5:
			n += 1
	return n


## Each entrance: a 3-cell pocket on the roof edge where zombies climb up, and (if it has hit points) a
## barricade over every walkable cell around the pocket, so they must break out.
func _build_entrances() -> void:
	for e: int in arena.entrance_cells.size():
		var cell: Vector2i = arena.entrance_cells[e]
		var outward: Vector2i = Vector2i(0, -1) if cell.y == 0 else Vector2i(0, 1) if cell.y == _grid.height - 1 \
			else Vector2i(-1, 0) if cell.x == 0 else Vector2i(1, 0)
		var along: Vector2i = Vector2i(outward.y, outward.x)
		var pocket: Array[Vector2i] = []
		for t: int in [-1, 0, 1]:
			var c: Vector2i = cell + along * t
			if _grid.is_walkable(c):
				pocket.append(c)
		var spots: PackedVector2Array = PackedVector2Array()
		var centre: Vector2 = Vector2.ZERO
		for c: Vector2i in pocket:
			spots.append(_grid.cell_center(c))
			centre += _grid.cell_center(c)
		_pockets.append(spots)
		_entrance_centres.append(centre / maxf(pocket.size(), 1.0))
		var hp: int = arena.barricade_hp[e] if e < arena.barricade_hp.size() else 0
		if hp <= 0:
			continue
		var ring: Array[Vector2i] = []
		for c: Vector2i in pocket:
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					var n: Vector2i = c + Vector2i(dx, dy)
					if _grid.is_walkable(n) and not pocket.has(n) and not ring.has(n):
						ring.append(n)
		_barricades.add(ring, hp)  # ids count up from 0, like _bar_meshes
		var faced: Array = []
		for c: Vector2i in ring:
			faced.append([c, (_entrance_centres[_entrance_centres.size() - 1] - _grid.cell_center(c)).normalized()])
		_bar_cells.append(faced)
		_bar_stage.append(0)
		var mi: MeshInstance3D = MeshInstance3D.new()
		add_child(mi)
		_bar_meshes.append(mi)
		_build_barricade_mesh(_bar_meshes.size() - 1, 0)


## A barricade's look at damage `stage` (0 whole .. 2 nearly gone): one kit piece per cell, planks or a pallet by
## cell, boards turned to face the pocket, merged into one mesh so a barricade stays one draw call.
func _build_barricade_mesh(id: int, stage: int) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for item: Array in _bar_cells[id]:
		var c: Vector2i = item[0]
		var face: Vector2 = item[1]
		var kind: int = posmod(c.x * 7 + c.y * 13, BARRICADE_PIECES.size())
		var yaw: float = atan2(face.x, face.y) + 0.12 * sin(c.x * 3.1 + c.y * 1.7)
		var p: Vector2 = _grid.cell_center(c)
		st.append_from(_piece(kind, stage), 0, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, GROUND_Y, p.y)))
	var mi: MeshInstance3D = _bar_meshes[id]
	mi.mesh = st.commit()
	mi.material_override = Style15Level.SURFACE_MATERIAL
	_bar_stage[id] = stage


func _piece(kind: int, stage: int) -> Mesh:
	var key: Vector2i = Vector2i(kind, stage)
	if not _piece_meshes.has(key):
		var root: Node = (BARRICADE_PIECES[kind][stage] as PackedScene).instantiate()
		var found: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
		_piece_meshes[key] = (found[0] as MeshInstance3D).mesh
		root.free()
	return _piece_meshes[key]


func _update_barricade_meshes() -> void:
	for id: int in _barricades.cells.size():
		var mi: MeshInstance3D = _bar_meshes[id]
		var standing: bool = _barricades.standing(id)
		if mi.visible and not standing and _explosions != null:
			var c: Vector2 = _grid.cell_center(_grid.cell_of_index(_barricades.cells[id][0]))
			_explosions.blast(Vector3(c.x, GROUND_Y, c.y), 1.5, false, 0, false, false)  # splinters
		mi.visible = standing
		var left: float = float(_barricades.hp[id]) / float(maxi(_barricades.max_hp[id], 1))
		var stage: int = 0 if left > 0.66 else 1 if left > 0.33 else 2
		if standing and stage != _bar_stage[id]:
			_build_barricade_mesh(id, stage)  # boards come off as it is hit


func _refill_crates() -> void:
	for crate: SupplyCrate in _crates:
		crate.uses_left = arena.crate_uses_per_break


func _on_phase_changed() -> void:
	match _director.phase:
		WaveDirector.Phase.CALM:
			_refill_crates()
			for m: Teammate in _mates:
				if m.health.is_alive():
					m.restock()  # they top up at the crates between waves
			_show_banner(tr("Calm · crates refilled"))
		WaveDirector.Phase.WAVE:
			_show_banner(tr("WAVE %d") % (_director.wave + 1))


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	var t: Tween = create_tween()
	t.tween_interval(1.2)
	t.tween_property(_banner, "modulate:a", 0.0, 0.8)


func _build_arena_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 90.0
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 44)
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.modulate.a = 0.0
	layer.add_child(_banner)
	_summary_box = PanelContainer.new()
	_summary_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_summary_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_summary_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_summary_box.visible = false
	layer.add_child(_summary_box)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 20)
	_summary_box.add_child(_summary)


func _update_arena_ui() -> void:
	var waves: int = _director.wave_count()
	var text: String = ""
	match _director.phase:
		WaveDirector.Phase.CALM:
			text = tr("Calm · wave %d / %d in %d s") % [_director.wave + 1, waves, ceili(_director.calm_left)]
		WaveDirector.Phase.WAVE:
			text = tr("Wave %d / %d · %d to come · %d on the roof") % [_director.wave + 1, waves,
				_director.left_to_spawn(), _horde.count]
		WaveDirector.Phase.WON:
			text = tr("Night survived")
	if _count_label.text != text:
		_count_label.text = text


## Summary on screen, one line to the local log.
func _end_run() -> void:
	_ended = true
	var won: bool = _director.phase == WaveDirector.Phase.WON
	var kills: int = _horde.kills
	var by_gun: int = 0
	var lines: PackedStringArray = PackedStringArray()
	lines.append(tr("NIGHT SURVIVED") if won else tr("YOU DIED on wave %d / %d") % [_director.wave + 1, _director.wave_count()])
	lines.append(tr("Time %d:%02d · kills %d · best chain x%d · score %d") % [int(_elapsed) / 60, int(_elapsed) % 60,
		kills, _chain.best, _chain.score])
	var run: Dictionary = {
		"won": won, "wave": _director.wave + 1, "waves": _director.wave_count(), "start_wave": _start_wave, "seconds": roundi(_elapsed),
		"kills": kills, "best_chain": _chain.best, "score": _chain.score, "hits_taken": _hits_taken,
		"bites": _player.health.bites, "hp_left": _player.health.hp, "grenade_kills": _grenade_kills,
		"build": BuildInfo.label(), "autoshoot": _auto_shoot,
	}
	for g: Gun in _player.guns:
		var name: String = g.config.display_name
		var k: int = _player.kills_by_gun.get(name, 0)
		by_gun += k
		lines.append(tr("%s: %d kills, %d rounds") % [name, k, g.shots_fired])
		run["kills_" + name] = k
		run["rounds_" + name] = g.shots_fired
	lines.append(tr("Grenades: %d kills · fire and other: %d") % [_grenade_kills, maxi(kills - by_gun - _grenade_kills, 0)])
	lines.append(tr("Hits taken %d · bites %d") % [_hits_taken, _player.health.bites])
	var alive: int = 0
	for m: Teammate in _mates:
		alive += 1 if m.health.state != FighterHealth.State.DEAD else 0
	lines.append(tr("Teammates alive: %d / %d") % [alive, _mates.size()])
	run["teammates_alive"] = alive
	lines.append(tr("R / X: play again"))
	_summary.text = "\n".join(lines)
	_summary_box.visible = true
	RunLog.append(run)
	print("arena run: ", JSON.stringify(run))


## Orders wheel (1.5+ A5; 8 slots, J 2026-11-06): a movement order or a fire rule for every teammate.
const MOVE_ORDERS: Dictionary[String, TeammateBrain.Order] = {
	"Follow me": TeammateBrain.Order.FOLLOW, "Sneak-follow": TeammateBrain.Order.SNEAK,
	"Hold here": TeammateBrain.Order.HOLD, "Stay still": TeammateBrain.Order.STAY,
}
const FIRE_RULES: Dictionary[String, TeammateBrain.FireRule] = {
	"Fire at will": TeammateBrain.FireRule.AT_WILL, "Hold fire": TeammateBrain.FireRule.HOLD_FIRE,
	"Quiet only": TeammateBrain.FireRule.QUIET, "Melee only": TeammateBrain.FireRule.MELEE,
}


func _on_order(i: int) -> void:
	var order: String = ORDERS[i]
	for m: Teammate in _mates:
		if MOVE_ORDERS.has(order):
			m.brain.order = MOVE_ORDERS[order]
			m.brain.hold_point = m.ground_position()
		elif FIRE_RULES.has(order):
			m.brain.fire_rule = FIRE_RULES[order]


func _active_orders() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if _mates.is_empty():
		return out
	var b: TeammateBrain = _mates[0].brain
	for k: int in ORDERS.size():
		var order: String = ORDERS[k]
		var move_on: bool = MOVE_ORDERS.has(order) and MOVE_ORDERS[order] == b.order
		var fire_on: bool = FIRE_RULES.has(order) and FIRE_RULES[order] == b.fire_rule
		if move_on or fire_on:
			out.append(k)
	return out
