class_name InteriorLighting
extends Node3D
## Dark interiors (GDD §5, PHASE0 0.8 part 2). A building's rooms are black until the player has seen
## them: the player's own room is lit, and so are both rooms beside every door the player has line of sight
## to (walls and windows block it, furniture doesn't). Rooms seen before and out of sight now stay dim.
## Levels go to one small texture per building (a texel per cell, for the player's storey) that the
## interior and horde shaders read through global uniforms, so there is no light node per room.
## A shadowless spot light on the player is the flashlight, on while inside.

const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
]

var config: InteriorLightConfig
var layout: InteriorLayout
var flashlight: SpotLight3D

var _regions: Array[PackedInt32Array] = []  ## per storey: region id per cell, -1 = wall / door / outside
var _region_count: PackedInt32Array = PackedInt32Array()
var _cell_regions: Array = []  ## per storey: per cell, the regions whose light it takes (own, or neighbours)
var _doors: Array = []  ## per storey: Array of [cell centre, region a, region b]
var _sight: Array[NavGrid] = []
var _seen: Array[PackedByteArray] = []
var _level: Array[PackedFloat32Array] = []
var _visible: PackedByteArray = PackedByteArray()
var _storey: int = -1
var _check_left: float = 0.0
var _image: Image
var _texture: ImageTexture


func setup(p_layout: InteriorLayout, p_config: InteriorLightConfig) -> void:
	layout = p_layout
	config = p_config
	for s: int in layout.storeys:
		var ids: PackedInt32Array = layout.regions(s)
		_regions.append(ids)
		var n: int = 0
		for id: int in ids:
			n = maxi(n, id + 1)
		_region_count.append(n)
		_sight.append(layout.sight_grid(s))
		var seen: PackedByteArray = PackedByteArray()
		seen.resize(n)
		_seen.append(seen)
		var level: PackedFloat32Array = PackedFloat32Array()
		level.resize(n)
		level.fill(config.dark)
		_level.append(level)
		_cell_regions.append(_light_sources(s, ids))
		_doors.append(_find_doors(s, ids))
	_image = Image.create(layout.width, layout.depth, false, Image.FORMAT_L8)
	_image.fill(Color(1, 1, 1))
	_texture = ImageTexture.create_from_image(_image)
	RenderingServer.global_shader_parameter_set("interior_light", _texture)
	RenderingServer.global_shader_parameter_set("interior_light_rect",
		Vector4(layout.origin.x, layout.origin.y, layout.width, layout.depth))
	RenderingServer.global_shader_parameter_set("interior_light_on", 0.0)
	flashlight = SpotLight3D.new()
	flashlight.shadow_enabled = false
	flashlight.light_energy = config.flashlight_energy
	flashlight.light_color = config.flashlight_color
	flashlight.spot_range = config.flashlight_range
	flashlight.spot_angle = config.flashlight_angle
	flashlight.visible = false
	add_child(flashlight)


## `storey` = -1 while the player is outside: everything off.
func step(delta: float, storey: int, player: Vector3, aim: Vector2) -> void:
	var inside: bool = storey >= 0
	flashlight.visible = inside
	if not inside:
		if _storey >= 0:
			RenderingServer.global_shader_parameter_set("interior_light_on", 0.0)
		_storey = -1
		return
	if storey != _storey:
		_storey = storey
		_check_left = 0.0
		RenderingServer.global_shader_parameter_set("interior_light_on", 1.0)
		_write_image(storey)
	var p: Vector2 = Vector2(player.x, player.z)
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = config.check_sec
		_update_visible(storey, p)
	var level: PackedFloat32Array = _level[storey]
	var changed: bool = false
	var max_step: float = config.fade_per_sec * delta
	for r: int in level.size():
		var target: float = config.dark
		if _visible[r] != 0:
			target = 1.0
		elif _seen[storey][r] != 0:
			target = config.remembered
		if not is_equal_approx(level[r], target):
			level[r] = move_toward(level[r], target, max_step)
			changed = true
	_level[storey] = level
	if changed:
		_write_image(storey)
	var dir: Vector3 = Vector3(aim.x, -config.flashlight_tilt, aim.y)
	var at: Vector3 = Vector3(player.x, layout.floor_y(storey) + config.flashlight_height, player.z)
	if dir.length_squared() > 0.0001:
		flashlight.global_transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), at)


## Light level of `cell` on `storey` as drawn (tests, overlay).
func level_at(storey: int, cell: Vector2i) -> float:
	var best: float = 0.0
	for r: int in _cell_regions[storey][layout.index(cell)]:
		best = maxf(best, _level[storey][r])
	return best


func region_at(storey: int, cell: Vector2i) -> int:
	return _regions[storey][layout.index(cell)]


func seen_count(storey: int) -> int:
	return _seen[storey].count(1)


func region_total(storey: int) -> int:
	return _region_count[storey]


func _update_visible(storey: int, p: Vector2) -> void:
	_visible.resize(_region_count[storey])
	_visible.fill(0)
	var own: int = _regions[storey][layout.index(layout.world_to_cell(p))] \
		if layout.cell(storey, layout.world_to_cell(p)) != InteriorLayout.Cell.OUTSIDE else -1
	if own >= 0:
		_visible[own] = 1
	var range2: float = config.view_range * config.view_range
	for d: Array in _doors[storey]:
		var at: Vector2 = d[0]
		if at.distance_squared_to(p) > range2 or not _sight[storey].line_of_sight(p, at):
			continue
		for r: int in [d[1], d[2]]:
			if r >= 0:
				_visible[r] = 1
	for r: int in _visible.size():
		if _visible[r] != 0:
			_seen[storey][r] = 1


func _write_image(storey: int) -> void:
	for y: int in layout.depth:
		for x: int in layout.width:
			var l: float = level_at(storey, Vector2i(x, y))
			_image.set_pixel(x, y, Color(l, l, l))
	_texture.update(_image)


## Region cells take their own light; walls, windows and doors the brightest region next to them (8-way),
## so a lit room's walls and doorway are lit too.
func _light_sources(s: int, ids: PackedInt32Array) -> Array:
	var out: Array = []
	out.resize(layout.width * layout.depth)
	for y: int in layout.depth:
		for x: int in layout.width:
			var i: int = layout.index(Vector2i(x, y))
			var list: PackedInt32Array = PackedInt32Array()
			if ids[i] >= 0:
				list.append(ids[i])
			else:
				for n: Vector2i in NEIGHBOURS:
					var m: Vector2i = Vector2i(x, y) + n
					if m.x < 0 or m.y < 0 or m.x >= layout.width or m.y >= layout.depth:
						continue
					var r: int = ids[layout.index(m)]
					if r >= 0 and not list.has(r):
						list.append(r)
			out[i] = list
	return out


func _find_doors(s: int, ids: PackedInt32Array) -> Array:
	var doors: Array = []
	for y: int in layout.depth:
		for x: int in layout.width:
			var c: Vector2i = Vector2i(x, y)
			if layout.cell(s, c) != InteriorLayout.Cell.DOOR:
				continue
			var sides: PackedInt32Array = PackedInt32Array()
			for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var m: Vector2i = c + n
				if m.x >= 0 and m.y >= 0 and m.x < layout.width and m.y < layout.depth and ids[layout.index(m)] >= 0:
					sides.append(ids[layout.index(m)])
			doors.append([layout.cell_center(c), sides[0] if sides.size() > 0 else -1, sides[1] if sides.size() > 1 else -1])
	return doors
