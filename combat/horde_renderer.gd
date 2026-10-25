class_name HordeRenderer
extends MultiMeshInstance3D
## Draws every zombie with one MultiMesh (one draw call + shadow pass).
## Writes the raw instance buffer once per frame instead of one call per instance.

const FLOATS_PER_INSTANCE: int = 16  # 12 transform (3x4, row-major) + 4 colour

## Cool grey clothes, pale green skin (Style 1.5).
@export var clothes_color: Color = Color(0.42, 0.45, 0.5)
@export var skin_color: Color = Color(0.62, 0.74, 0.55)

var _buffer: PackedFloat32Array


func setup(capacity: int) -> void:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _make_zombie_mesh()
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	multimesh = mm
	_buffer.resize(capacity * FLOATS_PER_INSTANCE)
	# The crowd moves every frame; per-instance culling isn't worth it.
	custom_aabb = AABB(Vector3(-500, -10, -500), Vector3(1000, 20, 1000))


func sync(horde: Horde, ground_y: float) -> void:
	var n: int = horde.count
	var pos: PackedVector2Array = horde.positions
	var vel: PackedVector2Array = horde.velocities
	var tint: PackedColorArray = horde.tint
	var buf: PackedFloat32Array = _buffer
	var o: int = 0
	for a: int in n:
		var p: Vector2 = pos[a]
		var v: Vector2 = vel[a]
		var c: float = 1.0
		var s: float = 0.0
		var sp2: float = v.length_squared()
		if sp2 > 0.0001:
			var inv: float = 1.0 / sqrt(sp2)
			# Yaw so local +Z faces the velocity: basis = rotation about Y.
			c = v.y * inv
			s = v.x * inv
		buf[o] = c
		buf[o + 1] = 0.0
		buf[o + 2] = s
		buf[o + 3] = p.x
		buf[o + 4] = 0.0
		buf[o + 5] = 1.0
		buf[o + 6] = 0.0
		buf[o + 7] = ground_y
		buf[o + 8] = -s
		buf[o + 9] = 0.0
		buf[o + 10] = c
		buf[o + 11] = p.y
		var t: Color = tint[a]
		buf[o + 12] = t.r
		buf[o + 13] = t.g
		buf[o + 14] = t.b
		buf[o + 15] = 1.0
		o += FLOATS_PER_INSTANCE
	_buffer = buf
	multimesh.buffer = _buffer
	multimesh.visible_instance_count = n


## Blocky placeholder: grey body, pale green head and arms reaching forward (+Z).
func _make_zombie_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st, Vector3(0, 0.45, 0), Vector3(0.44, 0.9, 0.28), clothes_color)  # body + legs
	_add_box(st, Vector3(0, 1.08, 0.04), Vector3(0.32, 0.32, 0.32), skin_color)  # head
	_add_box(st, Vector3(-0.17, 0.8, 0.22), Vector3(0.1, 0.1, 0.42), skin_color)  # arms
	_add_box(st, Vector3(0.17, 0.8, 0.22), Vector3(0.1, 0.1, 0.42), skin_color)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)
	return mesh


func _add_box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	var arrays: Array = box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	st.set_color(color)
	for i: int in indices:
		st.set_color(color)
		st.add_vertex(verts[i] + center)
