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


func test_cut_follows_the_player_and_camera() -> void:
	_ctl._enter_storey(2)
	_stand(Vector2(3.0, 4.0))
	assert_true(_ctl.cut_active)
	assert_almost_eq(_ctl.cut_origin.x, 3.0, 0.001)
	assert_almost_eq(_ctl.cut_origin.y, _ctl.layout.floor_y(2), 0.001)
	var back: Vector3 = _camera.global_basis.z
	assert_almost_eq(_ctl.cut_toward.dot(Vector2(back.x, back.z).normalized()), 1.0, 0.001)
	_camera.rotation_degrees.y += 90.0  # a camera turn moves the cut with it
	_ctl._process(0.016)
	back = _camera.global_basis.z
	assert_almost_eq(_ctl.cut_toward.dot(Vector2(back.x, back.z).normalized()), 1.0, 0.001)
