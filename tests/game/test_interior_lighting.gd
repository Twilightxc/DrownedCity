extends GutTest

var _layout: InteriorLayout
var _config: InteriorLightConfig
var _light: InteriorLighting


func before_each() -> void:
	_layout = InteriorLayout.generate(26, 22, 3, 7, Vector2(-13, -11), -9.6, 0)
	_config = InteriorLightConfig.new()
	_light = InteriorLighting.new()
	add_child_autofree(_light)
	_light.setup(_layout, _config)


func _at(c: Vector2i) -> Vector3:
	var p: Vector2 = _layout.cell_center(c)
	return Vector3(p.x, 0, p.y)


## Long enough for every fade to finish.
func _settle(storey: int, c: Vector2i) -> void:
	for i: int in 40:
		_light.step(0.05, storey, _at(c), Vector2(1, 0))


func _corridor() -> Vector2i:
	return Vector2i(12, _layout.corridor_row)


## A room cell south of the corridor, and the region of the room it's in.
func _south_room_cell() -> Vector2i:
	return Vector2i(12, _layout.corridor_row + 4)


func test_regions_split_rooms_and_keep_the_stairwell_with_the_corridor() -> void:
	var ids: PackedInt32Array = _layout.regions(2)
	var corridor: int = ids[_layout.index(_corridor())]
	assert_gte(corridor, 0)
	assert_eq(ids[_layout.index(Vector2i(InteriorLayout.STAIR_X0, _layout.corridor_row))], corridor, "stair cells")
	assert_eq(ids[_layout.index(Vector2i(InteriorLayout.STAIR_X0 - 1, _layout.corridor_row))], corridor, "west landing")
	assert_ne(ids[_layout.index(_south_room_cell())], corridor, "a door separates the room")
	assert_eq(ids[_layout.index(Vector2i(0, 0))], -1, "outer wall")


func test_unseen_rooms_are_dark_and_the_players_room_is_lit() -> void:
	_settle(2, _corridor())
	assert_almost_eq(_light.level_at(2, _corridor()), 1.0, 0.001)
	# Some room is out of sight of every door the corridor point sees: find one that stayed dark.
	var dark: int = 0
	for y: int in _layout.depth:
		for x: int in _layout.width:
			var c: Vector2i = Vector2i(x, y)
			if _light.region_at(2, c) >= 0 and _light.level_at(2, c) <= _config.dark + 0.001:
				dark += 1
	assert_gt(dark, 0, "rooms beyond line of sight stay dark")


func test_a_door_in_sight_reveals_the_room_behind_it_and_it_dims_when_left() -> void:
	var room: Vector2i = _south_room_cell()
	# Stand in the doorway of that room: both sides are lit.
	var door: Vector2i = Vector2i(-1, -1)
	var region: int = _light.region_at(2, room)
	for x: int in _layout.width:
		var c: Vector2i = Vector2i(x, _layout.corridor_row + 2)
		if _layout.cell(2, c) == InteriorLayout.Cell.DOOR and _light.region_at(2, c + Vector2i(0, 1)) == region:
			door = c
	assert_ne(door, Vector2i(-1, -1), "the room has a corridor door")
	_settle(2, door)
	assert_almost_eq(_light.level_at(2, room), 1.0, 0.001)
	# Walk into another room far away and out of sight: this one is remembered, dimmer.
	_settle(2, Vector2i(24, 2))
	var l: float = _light.level_at(2, room)
	assert_true(is_equal_approx(l, 1.0) or is_equal_approx(l, _config.remembered),
		"still in sight (lit) or remembered (dim), never dark again: %f" % l)


func test_walls_take_the_light_of_the_room_beside_them() -> void:
	_settle(2, _corridor())
	var wall: Vector2i = _corridor() + Vector2i(0, -1)  # the corridor's north wall
	assert_eq(_layout.cell(2, wall), InteriorLayout.Cell.WALL)
	assert_almost_eq(_light.level_at(2, wall), 1.0, 0.001)


func test_flashlight_only_inside_and_aims_with_the_player() -> void:
	_light.step(0.05, -1, Vector3.ZERO, Vector2(1, 0))
	assert_false(_light.flashlight.visible)
	_light.step(0.05, 2, _at(_corridor()), Vector2(1, 0))
	assert_true(_light.flashlight.visible)
	var forward: Vector3 = -_light.flashlight.global_basis.z
	assert_gt(forward.x, 0.9, "points along the aim")
	assert_lt(forward.y, 0.0, "tilted down a little")
