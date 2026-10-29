class_name InteriorController
extends Node3D
## One enterable building for spike 0.8: builds the seeded interior, moves the player between the roof
## and the storeys (roof hatch, stairs), and drives the cutaway.
## While the player is inside, the building's own exterior mesh and the roof props only cast shadows,
## storeys above the player do the same, and the walls on the camera side drop to waist height.

const FADE_SEC: float = 0.25

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
var cut_toward: Vector2 = Vector2(0, 1)

var _builder: InteriorBuilder
var _player: SpikePlayer
var _camera: Camera3D
var _roof_grid: NavGrid
var _roof_y: float
var _exterior: Array[GeometryInstance3D] = []
var _inner_hatch: Hatch
var _roof_hatch: Hatch
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
		_player.set_height(on_stairs[0])
		var s: int = on_stairs[1]
		if s != storey:
			_enter_storey(s)
	elif not is_equal_approx(_player.ground_y, layout.floor_y(storey)):
		_player.set_height(layout.floor_y(storey))
	_update_cut()


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


## Each hatch shows only on its own storey (the roof one while outside).
func _show_hatches() -> void:
	_roof_hatch.visible = storey < 0
	_inner_hatch.visible = storey == storeys - 1


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
	var back: Vector3 = _camera.global_basis.z  # points from the scene toward the camera
	var toward: Vector2 = Vector2(back.x, back.z)
	if toward.length_squared() > 0.0001:
		cut_toward = toward.normalized()
	cut_origin = Vector3(_player.position.x, layout.floor_y(storey), _player.position.z)
	RenderingServer.global_shader_parameter_set("cut_toward_camera", cut_toward)
	RenderingServer.global_shader_parameter_set("cut_origin", cut_origin)
