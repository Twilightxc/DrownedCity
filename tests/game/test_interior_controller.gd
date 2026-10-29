extends GutTest

var _player: SpikePlayer
var _camera: Camera3D
var _ctl: InteriorController
var _roof: NavGrid


func before_each() -> void:
	_camera = Camera3D.new()
	add_child_autofree(_camera)
	_camera.rotation_degrees = Vector3(-35.264, 45.0, 0.0)
	_player = SpikePlayer.new()
	var marker: Node3D = Node3D.new()
	marker.name = "AimMarker"
	_player.add_child(marker)
	_player.weapon = WeaponConfig.new()
	add_child_autofree(_player)
	_roof = NavGrid.new(25, 21, 1.0, Vector2(-12.5, -10.5))
	_player.setup(_roof, Horde.new(HordeConfig.new(), _roof, 4), _camera, 0.0)
	_ctl = InteriorController.new()
	add_child_autofree(_ctl)
	_ctl.setup(_player, _camera, _roof, 0.0, [] as Array[Node])


func _flight_point(top: int, t: float) -> Vector2:
	var l: InteriorLayout = _ctl.layout
	var x0: float = l.origin.x + InteriorLayout.STAIR_X0
	var x: float = x0 + InteriorLayout.FLIGHT_LEN * (1.0 - t) if l.flight_top_east(top) else x0 + InteriorLayout.FLIGHT_LEN * t
	return Vector2(x, l.origin.y + l.flight_row(top) + 0.5)


func _stand(p: Vector2) -> void:
	_player.position.x = p.x
	_player.position.z = p.y
	_ctl._process(0.016)


func test_flooded_storey_is_below_the_water() -> void:
	assert_eq(_ctl.layout.flooded, 0)
	assert_almost_eq(_ctl.layout.floor_y(2), -3.2, 0.001, "top storey under the roof")


func test_walking_down_the_stairs_changes_storey_and_height() -> void:
	_ctl._enter_storey(2)
	assert_eq(_ctl.storey, 2)
	assert_eq(_player.grid, _ctl.grids[2])
	_stand(_flight_point(2, 0.25))
	assert_eq(_ctl.storey, 2)
	assert_almost_eq(_player.ground_y, _ctl.layout.floor_y(2) - 0.8, 0.05)
	_stand(_flight_point(2, 0.75))
	assert_eq(_ctl.storey, 1, "past half way: the lower storey")
	assert_eq(_player.grid, _ctl.grids[1])
	assert_almost_eq(_player.ground_y, _ctl.layout.floor_y(1) + 0.8, 0.05)
	_stand(_ctl.layout.cell_center(Vector2i(InteriorLayout.STAIR_X0 + InteriorLayout.FLIGHT_LEN, _ctl.layout.corridor_row)))
	assert_almost_eq(_player.ground_y, _ctl.layout.floor_y(1), 0.001, "off the stairs: on the floor")


func test_walking_back_up() -> void:
	_ctl._enter_storey(1)
	_stand(_flight_point(2, 0.2))
	assert_eq(_ctl.storey, 2)


func test_cut_follows_the_player() -> void:
	_ctl._enter_storey(2)
	_stand(Vector2(3.0, 4.0))
	assert_true(_ctl.cut_active)
	assert_almost_eq(_ctl.cut_origin.x, 3.0, 0.001)
	assert_almost_eq(_ctl.cut_origin.y, _ctl.layout.floor_y(2), 0.001)


func test_water_level_window_on_the_lowest_dry_storey() -> void:
	assert_eq(_ctl.window_storey, 1, "storey 0 is flooded")
	var l: InteriorLayout = _ctl.layout
	assert_eq(l.cell(1, _ctl.window_cell), InteriorLayout.Cell.WINDOW)
	assert_eq(_ctl.window_cell.y, l.depth - 1, "south outer wall")
	assert_true(_ctl.grids[1].is_walkable_world(_ctl.window_inside), "room to stand inside it")
	assert_true(_roof.is_walkable_world(_ctl.window_roof), "rope starts on walkable roof")
	assert_gt(l.floor_y(1), _ctl.water_y, "the window's floor is above the water")
	assert_lt(l.floor_y(1) - _ctl.water_y, InteriorLayout.STOREY, "and within a storey of it")


func test_window_hatch_shows_only_on_its_storey() -> void:
	_ctl._enter_storey(1)
	assert_true(_ctl._window_hatch.visible)
	assert_false(_ctl._rope_hatch.visible)
	_ctl._enter_storey(2)
	assert_false(_ctl._window_hatch.visible)


## J, 2026-10-29: "ทางลงบันไดเดินแล้วติด". Off-centre on the 1-cell flight, the player switched to the storey below
## (whose cell beside the flight is the closed flight down) and could no longer stand anywhere.
func test_off_centre_on_a_flight_is_pulled_in_and_never_stuck_after_the_switch() -> void:
	_ctl._enter_storey(2)
	for t: float in [0.2, 0.4, 0.6, 0.8]:
		_stand(_flight_point(2, t) + Vector2(0, 0.28))
		assert_true(_player._can_stand(_player.ground_position()), "t %.1f storey %d" % [t, _ctl.storey])
	assert_eq(_ctl.storey, 1)


## J, 2026-10-29: the closed flight to the flooded storey looked walkable; the stop read as a bug.
func test_flooded_sign_over_the_closed_flight_shows_only_up_close() -> void:
	assert_eq(_ctl.flood_signs.size(), 1, "only storey 1's flight down to storey 0 is closed")
	var entry: Array = _ctl.flood_signs[0]
	assert_eq(entry[0], 1)
	var label: Label3D = entry[1]
	_ctl._enter_storey(1)
	_stand(Vector2(label.position.x + 1.0, label.position.z))
	assert_true(label.visible, "1 m away")
	_stand(Vector2(label.position.x + 8.0, label.position.z))
	assert_false(label.visible, "8 m away")
	_ctl._enter_storey(2)
	_stand(Vector2(label.position.x, label.position.z))
	assert_false(label.visible, "another storey")
