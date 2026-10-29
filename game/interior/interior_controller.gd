class_name InteriorController
extends Node3D
## One enterable building for spike 0.8: builds the seeded interior, moves the player between the roof
## and the storeys (roof hatch, stairs, a rope to the window at water level), and drives the cutaway.
## While the player is inside, the building's own exterior mesh and the roof props only cast shadows,
## storeys above the player do the same, and every wall of the player's storey drops to waist height.

signal storey_changed(storey: int)  ## -1 = back on the roof

const FADE_SEC: float = 0.25
const FLOOD_SIGN_RANGE: float = 3.0  ## m: a "Flooded" sign shows when the player is this close

@export var footprint: Vector2i = Vector2i(26, 22)  ## the base building (style15_level)
@export var center: Vector2 = Vector2.ZERO
@export var storeys: int = 3
@export var waterline_offset: float = 1.0  ## kit_building: storey 0 sits this far under the water surface
@export var water_y: float = -8.6
@export var layout_seed: int = 7
@export var roof_hatch_at: Vector2 = Vector2(-10.8, -7.0)  ## in front of the roof hut
@export var cut_height: float = 1.1

var layout: InteriorLayout
var storey: int = -1  ## -1 = on the roof / outside
var grids: Array[NavGrid] = []
## Last values sent to the cutaway shader globals (also read by tests: the dummy renderer can't return them).
var cut_active: bool = false
var cut_origin: Vector3 = Vector3.ZERO

var _builder: InteriorBuilder
var _player: SpikePlayer
var _camera: Camera3D
var _roof_grid: NavGrid
var _roof_y: float
var _exterior: Array[GeometryInstance3D] = []
var _inner_hatch: Hatch
var _roof_hatch: Hatch
## The water-level entrance (part 2): a window on the lowest dry storey, reached by a rope from the roof
## edge above it (a boat that stops at the window comes later).
var window_storey: int = -1
var window_cell: Vector2i = Vector2i(-1, -1)  ## the outer-wall window
var window_inside: Vector2  ## where the player stands inside it
var window_roof: Vector2  ## where the rope starts on the roof
var _window_hatch: Hatch
## "Flooded" signs at the top of closed flights (down to a storey under water): [storey, label]. Without one,
## the drawn flight looks walkable and the player reads the stop as a bug (J, 2026-10-29).
var flood_signs: Array = []
var _rope_hatch: Hatch
var _fade: ColorRect
var _busy: bool = false


func setup(player: SpikePlayer, camera: Camera3D, roof_grid: NavGrid, roof_y: float, exterior: Array[Node]) -> void:
	_player = player
	_camera = camera
	_roof_grid = roof_grid
	_roof_y = roof_y
	for root: Node in exterior:
		for g: Node in root.find_children("*", "GeometryInstance3D", true, false):
			_exterior.append(g as GeometryInstance3D)
		if root is GeometryInstance3D:
			_exterior.append(root as GeometryInstance3D)
	var origin: Vector2 = center - Vector2(footprint) * 0.5
	var base_y: float = water_y - waterline_offset
	var flooded: int = floori((water_y - base_y) / InteriorLayout.STOREY + 0.999) - 1  # storeys with water above the floor
	layout = InteriorLayout.generate(footprint.x, footprint.y, storeys, layout_seed, origin, base_y, flooded)
	for s: int in storeys:
		grids.append(layout.nav_grid(s))
	_builder = InteriorBuilder.new()
	add_child(_builder)
	_builder.build(layout)
	_builder.show_storey(-1)

	_roof_hatch = Hatch.new()
	_roof_hatch.prompt = "Go down"
	_roof_hatch.position = Vector3(roof_hatch_at.x, roof_y, roof_hatch_at.y)
	_roof_hatch.used.connect(func(_p: SpikePlayer) -> void: _go(storeys - 1, _top_landing()))
	add_child(_roof_hatch)
	_inner_hatch = Hatch.new()
	_inner_hatch.prompt = "Up to the roof"
	var landing: Vector2 = _top_landing()
	_inner_hatch.position = Vector3(landing.x, layout.floor_y(storeys - 1), landing.y)
	_inner_hatch.used.connect(func(_p: SpikePlayer) -> void: _go(-1, roof_hatch_at + Vector2(0, 0.6)))
	_inner_hatch.visible = false
	add_child(_inner_hatch)

	_setup_window()
	_setup_flood_signs()

	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	_set_cut(false)


## West landing of the top storey: where the roof hatch's ladder comes down.
func _top_landing() -> Vector2:
	return layout.cell_center(Vector2i(InteriorLayout.STAIR_X0 - 1, layout.corridor_row))


func _process(_delta: float) -> void:
	if storey < 0 or _player == null:
		return
	var p: Vector2 = _player.ground_position()
	var on_stairs: Array = layout.stair_at(storey, p)
	if not on_stairs.is_empty():
		# Keep the player inside the 1-cell flight: past half way the other storey's grid takes over, and its
		# cell beside the flight may be blocked (the closed flight down to a flooded storey) where this storey
		# had floor; a player standing off-centre would then be stuck on the stairs.
		var row: float = layout.origin.y + layout.world_to_cell(p).y
		var r: float = _player.radius + 0.01
		_player.position.z = clampf(_player.position.z, row + r, row + 1.0 - r)
		_player.set_height(on_stairs[0])
		var s: int = on_stairs[1]
		if s != storey:
			_enter_storey(s)
	elif not is_equal_approx(_player.ground_y, layout.floor_y(storey)):
		_player.set_height(layout.floor_y(storey))
	_update_flood_signs(p)
	_update_cut()


## One sign over the top cell of every closed flight whose top storey is dry.
func _setup_flood_signs() -> void:
	for top: int in range(1, storeys):
		if layout.flight_open(top) or top <= layout.flooded:
			continue
		var x: int = InteriorLayout.STAIR_X0 + InteriorLayout.FLIGHT_LEN - 1 if layout.flight_top_east(top) else InteriorLayout.STAIR_X0
		var at: Vector2 = layout.cell_center(Vector2i(x, layout.flight_row(top)))
		var label: Label3D = Label3D.new()
		label.text = tr("Flooded")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.002
		label.font_size = 24
		label.outline_size = 6
		label.modulate = Color(0.75, 0.9, 1.0)
		label.position = Vector3(at.x, layout.floor_y(top) + 1.2, at.y)
		label.visible = false
		add_child(label)
		flood_signs.append([top, label])


func _update_flood_signs(p: Vector2) -> void:
	var r2: float = FLOOD_SIGN_RANGE * FLOOD_SIGN_RANGE
	for entry: Array in flood_signs:
		var label: Label3D = entry[1]
		label.visible = entry[0] == storey and Vector2(label.position.x, label.position.z).distance_squared_to(p) <= r2


func _go(to_storey: int, at: Vector2) -> void:
	if _busy:
		return
	_busy = true
	var t: Tween = create_tween()
	t.tween_property(_fade, "color:a", 1.0, FADE_SEC)
	t.tween_callback(func() -> void:
		_player.position.x = at.x
		_player.position.z = at.y
		_player.velocity = Vector2.ZERO
		if to_storey < 0:
			storey = -1
			_player.set_floor(_roof_grid, _roof_y)
			_builder.show_storey(-1)
			_set_exterior(true)
			_set_cut(false)
			_show_hatches()
			storey_changed.emit(-1)
		else:
			_set_exterior(false)
			_enter_storey(to_storey))
	t.tween_property(_fade, "color:a", 0.0, FADE_SEC)
	t.tween_callback(func() -> void: _busy = false)


func _enter_storey(s: int) -> void:
	storey = s
	var y: float = _player.ground_y if not layout.stair_at(s, _player.ground_position()).is_empty() else layout.floor_y(s)
	_player.set_floor(grids[s], y)
	_builder.show_storey(s)
	_show_hatches()
	_update_cut()
	storey_changed.emit(s)


## Each hatch shows only on its own storey (the roof one while outside).
func _show_hatches() -> void:
	_roof_hatch.visible = storey < 0
	for entry: Array in flood_signs:
		(entry[1] as Label3D).visible = false  # _process shows the near one again
	_inner_hatch.visible = storey == storeys - 1
	if _window_hatch != null:
		_rope_hatch.visible = storey < 0
		_window_hatch.visible = storey == window_storey


## Picks the south-wall window of the lowest dry storey closest to the middle whose inside cell is free,
## and the roof cell above it for the rope.
func _setup_window() -> void:
	window_storey = layout.flooded + 1
	if window_storey >= storeys:
		return
	var grid: NavGrid = grids[window_storey]
	var y: int = layout.depth - 1
	var best: int = -1
	for x: int in layout.width:
		if layout.cell(window_storey, Vector2i(x, y)) != InteriorLayout.Cell.WINDOW:
			continue
		if not grid.is_walkable(Vector2i(x, y - 1)):
			continue
		if best < 0 or absi(x - layout.width / 2) < absi(best - layout.width / 2):
			best = x
	if best < 0:
		return
	window_cell = Vector2i(best, y)
	window_inside = layout.cell_center(Vector2i(best, y - 1))
	window_roof = window_inside
	for step: int in range(1, 6):  # the roof edge may be blocked by the parapet: step inward
		window_roof = layout.cell_center(Vector2i(best, y - step))
		if _roof_grid.is_walkable_world(window_roof):
			break
	_rope_hatch = Hatch.new()
	_rope_hatch.prompt = "Rope down to the window"
	_rope_hatch.position = Vector3(window_roof.x, _roof_y, window_roof.y)
	_rope_hatch.used.connect(func(_p: SpikePlayer) -> void: _go(window_storey, window_inside))
	add_child(_rope_hatch)
	_window_hatch = Hatch.new()
	_window_hatch.prompt = "Climb up to the roof"
	_window_hatch.position = Vector3(window_inside.x, layout.floor_y(window_storey), window_inside.y)
	_window_hatch.used.connect(func(_p: SpikePlayer) -> void: _go(-1, window_roof))
	_window_hatch.visible = false
	add_child(_window_hatch)


func _set_exterior(drawn: bool) -> void:
	var mode: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if drawn \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for g: GeometryInstance3D in _exterior:
		g.cast_shadow = mode


func _set_cut(on: bool) -> void:
	cut_active = on
	RenderingServer.global_shader_parameter_set("cut_on", 1.0 if on else 0.0)
	RenderingServer.global_shader_parameter_set("cut_height", cut_height)


func _update_cut() -> void:
	_set_cut(true)
	cut_origin = Vector3(_player.position.x, layout.floor_y(storey), _player.position.z)
	RenderingServer.global_shader_parameter_set("cut_origin", cut_origin)
