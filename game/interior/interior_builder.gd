class_name InteriorBuilder
extends Node3D
## Draws an InteriorLayout from the kit_interior pieces: one MultiMesh per piece type per storey, so a
## storey is ~12 draw calls however many walls it has. Walls are per cell: a post, plus an arm toward each
## wall neighbour; outer windows and doorways are whole-cell pieces turned along their wall.
## `show_storey` decides what the camera sees while the player is inside: storeys at or below the player's
## are drawn, the ones above only cast shadows (the interior stays in their shade, as under a real roof).

const PIECES: PackedStringArray = [
	"wall_post", "wall_arm", "wall_window", "doorway", "floor", "stair",
	"bed", "table", "shelf", "sofa", "crate",
]
const CUTAWAY_SHADER: Shader = preload("res://game/shaders/interior_cutaway.gdshader")
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var layout: InteriorLayout
var _meshes: Dictionary[String, Mesh] = {}
var _storey_nodes: Array[Node3D] = []
var _material: ShaderMaterial


func build(p_layout: InteriorLayout) -> void:
	layout = p_layout
	_material = ShaderMaterial.new()
	_material.shader = CUTAWAY_SHADER
	for piece: String in PIECES:
		_meshes[piece] = _load_mesh("res://assets/models/interior_%s.glb" % piece)
	for s: int in layout.storeys:
		var node: Node3D = Node3D.new()
		node.name = "Storey%d" % s
		add_child(node)
		_storey_nodes.append(node)
		_build_storey(s, node)


## Inside the building on `storey`: below and at it drawn, above shadow-only. -1 = player outside: hidden.
func show_storey(storey: int) -> void:
	visible = storey >= 0
	for s: int in _storey_nodes.size():
		var mode: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if s > storey:
			mode = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		for child: Node in _storey_nodes[s].get_children():
			(child as GeometryInstance3D).cast_shadow = mode


func _build_storey(s: int, node: Node3D) -> void:
	var xf: Dictionary[String, Array] = {}
	for piece: String in PIECES:
		xf[piece] = []
	var y: float = layout.floor_y(s)
	for cy: int in layout.depth:
		for cx: int in layout.width:
			var c: Vector2i = Vector2i(cx, cy)
			var t: int = layout.cell(s, c)
			var p: Vector2 = layout.cell_center(c)
			var at: Vector3 = Vector3(p.x, y, p.y)
			var hole: bool = t == InteriorLayout.Cell.STAIR and cy == layout.flight_row(s)  # flight down from here
			if t != InteriorLayout.Cell.OUTSIDE and not hole:
				xf["floor"].append(Transform3D(Basis(), at))
			match t:
				InteriorLayout.Cell.WALL:
					xf["wall_post"].append(Transform3D(Basis(), at))
					for d: Vector2i in DIRS:
						if _is_wallish(s, c + d):
							xf["wall_arm"].append(Transform3D(_yaw_toward(d), at))
				InteriorLayout.Cell.WINDOW:
					xf["wall_window"].append(Transform3D(_along_wall(s, c), at))
				InteriorLayout.Cell.DOOR:
					xf["doorway"].append(Transform3D(_along_wall(s, c), at))
	# Flights are drawn with the storey they start from (the bottom), so they show while the player is there.
	for top: int in range(s + 1, mini(s + 2, layout.storeys)):
		var row: float = layout.origin.y + layout.flight_row(top) + 0.5
		var cx: float = layout.origin.x + InteriorLayout.STAIR_X0 + InteriorLayout.FLIGHT_LEN * 0.5
		# The mesh rises toward +X: turn it when the flight tops out at the west landing.
		var basis: Basis = Basis() if layout.flight_top_east(top) else Basis(Vector3.UP, PI)
		xf["stair"].append(Transform3D(basis, Vector3(cx, y, row)))
	for item: InteriorLayout.Item in layout.furniture[s]:
		var mid: Vector2 = Vector2.ZERO
		for c: Vector2i in item.cells:
			mid += layout.cell_center(c)
		mid /= item.cells.size()
		var basis: Basis = Basis(Vector3.UP, item.yaw)
		if item.cells.size() > 1 and item.cells[1].y != item.cells[0].y:
			basis = Basis(Vector3.UP, PI / 2.0)  # two-cell piece standing along Z
		xf[item.kind].append(Transform3D(basis, Vector3(mid.x, y, mid.y)))
	for piece: String in PIECES:
		var list: Array = xf[piece]
		if list.is_empty():
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meshes[piece]
		mm.instance_count = list.size()
		for i: int in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = piece
		mmi.multimesh = mm
		mmi.material_override = _material
		node.add_child(mmi)


func _is_wallish(s: int, c: Vector2i) -> bool:
	var t: int = layout.cell(s, c)
	return t == InteriorLayout.Cell.WALL or t == InteriorLayout.Cell.WINDOW or t == InteriorLayout.Cell.DOOR


## Basis turning the kit's +X onto direction d (grid +y = world +Z).
func _yaw_toward(d: Vector2i) -> Basis:
	return Basis(Vector3.UP, -atan2(float(d.y), float(d.x)))


## A whole-cell wall piece runs along X; turn it when its wall runs along Z.
func _along_wall(s: int, c: Vector2i) -> Basis:
	var along_z: bool = _is_wallish(s, c + Vector2i(0, 1)) or _is_wallish(s, c + Vector2i(0, -1))
	var along_x: bool = _is_wallish(s, c + Vector2i(1, 0)) or _is_wallish(s, c + Vector2i(-1, 0))
	return Basis(Vector3.UP, PI / 2.0) if along_z and not along_x else Basis()


static func _load_mesh(path: String) -> Mesh:
	var scene: PackedScene = load(path) as PackedScene
	var root: Node = scene.instantiate()
	var found: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	root.free()
	return mesh
