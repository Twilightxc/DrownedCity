extends "res://game/spikes/twin_stick_spike.gd"
## Phase 1 step 1.5: "one night on the roof", the combat test arena on the real base roof (J, 2026-10-29).
## Zombies climb up at four entrances in waves from data (ArenaConfig): two entrances are barricaded and
## must be torn down first, two are open. Calm between waves: the supply crates refill once. The night
## ends when the last wave is cleared or you die; a summary shows and the run is logged locally.
## Gate 1.G: J plays it 3 times on the Arc and calls it fun (or not).

const POCKET_CROWD: int = 12  ## zombies waiting in one entrance pocket at most; more spawn later

@export var arena: ArenaConfig = preload("res://data/combat/arena_roof.tres")

var _director: WaveDirector
var _barricades: Barricades
var _bar_meshes: Array[MeshInstance3D] = []  ## per barricade id
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


func _process(delta: float) -> void:
	super._process(delta)
	if _barricades.revision != _bar_rev:
		_bar_rev = _barricades.revision
		_flow_cell = Vector2i(-1, -1)  # a barricade fell: recompute the flow field now
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
		_bar_meshes.append(_make_barricade_mesh(ring))


## Planks over the barricade cells: one mesh per barricade; it sinks as it takes damage and is gone at 0.
func _make_barricade_mesh(cells: Array[Vector2i]) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box: BoxMesh = BoxMesh.new()
	for c: Vector2i in cells:
		var p: Vector2 = _grid.cell_center(c)
		for k: int in 3:  # three planks stacked, a little crooked
			box.size = Vector3(0.95, 0.22, 0.95)
			var xf: Transform3D = Transform3D(Basis(Vector3.UP, 0.15 * sin(c.x * 3.1 + c.y * 1.7 + k)), Vector3(p.x, 0.15 + k * 0.32, p.y))
			st.append_from(box, 0, xf)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.3, 0.2)
	mat.roughness = 1.0
	st.set_material(mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	add_child(mi)
	return mi


func _update_barricade_meshes() -> void:
	for id: int in _barricades.cells.size():
		var mi: MeshInstance3D = _bar_meshes[id]
		var standing: bool = _barricades.standing(id)
		if mi.visible and not standing and _explosions != null:
			var c: Vector2 = _grid.cell_center(_grid.cell_of_index(_barricades.cells[id][0]))
			_explosions.blast(Vector3(c.x, GROUND_Y, c.y), 1.5, false, 0, false, false)  # splinters
		mi.visible = standing
		mi.scale.y = lerpf(0.35, 1.0, float(_barricades.hp[id]) / float(maxi(_barricades.max_hp[id], 1)))


func _refill_crates() -> void:
	for crate: SupplyCrate in _crates:
		crate.uses_left = arena.crate_uses_per_break


func _on_phase_changed() -> void:
	match _director.phase:
		WaveDirector.Phase.CALM:
			_refill_crates()
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
	lines.append(tr("R / X: play again"))
	_summary.text = "\n".join(lines)
	_summary_box.visible = true
	RunLog.append(run)
	print("arena run: ", JSON.stringify(run))
