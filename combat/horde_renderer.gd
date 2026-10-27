class_name HordeRenderer
extends Node3D
## Draws the zombies with one MultiMesh per look (one draw call + shadow pass each).
## Writes each raw instance buffer once per frame instead of one call per instance.
## With `models` set, each look plays its vertex animation texture (PHASE0 0.7): the instance
## custom data carries the two VAT rows and their blend for the agent's clip and time.
## Without models it falls back to the blocky placeholder of spike A.

const FLOATS_PER_INSTANCE: int = 20  # 12 transform (3x4, row-major) + 4 colour + 4 custom
const VAT_SHADER: Shader = preload("res://game/shaders/horde_vat.gdshader")

@export var models: Array[VatModel] = []
## Placeholder colours. Cool grey clothes, pale green skin (Style 1.5). sRGB.
@export var clothes_color: Color = Color("#515865")
@export var skin_color: Color = Color("#93ad7a")

var _layers: Array[MultiMeshInstance3D] = []
var _buffers: Array[PackedFloat32Array] = []
var _clip_index: Array[PackedInt32Array] = []  # per look: Horde.Anim -> VatClips row


func setup(capacity: int) -> void:
	var looks: int = maxi(models.size(), 1)
	for v: int in looks:
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		var layer: MultiMeshInstance3D = MultiMeshInstance3D.new()
		if models.is_empty():
			mm.mesh = _make_placeholder_mesh()
		else:
			var model: VatModel = models[v]
			mm.mesh = model.extract_mesh()
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = VAT_SHADER
			mat.set_shader_parameter("vat_position", model.positions)
			mat.set_shader_parameter("vat_normal", model.normals)
			layer.material_override = mat
			var rows: PackedInt32Array = PackedInt32Array()
			for clip_name: String in ["walk", "attack", "flinch"]:  # Horde.Anim order
				rows.append(model.clips.index_of(clip_name))
			_clip_index.append(rows)
		mm.instance_count = capacity
		mm.visible_instance_count = 0
		layer.multimesh = mm
		# The crowd moves every frame; per-instance culling isn't worth it.
		layer.custom_aabb = AABB(Vector3(-500, -10, -500), Vector3(1000, 20, 1000))
		add_child(layer)
		_layers.append(layer)
		var buf: PackedFloat32Array = PackedFloat32Array()
		buf.resize(capacity * FLOATS_PER_INSTANCE)
		_buffers.append(buf)


func sync(horde: Horde, ground_y: float) -> void:
	for v: int in _layers.size():
		_sync_look(horde, v, ground_y)


## One pass per look keeps a single local buffer (packed arrays copy on write when shared).
func _sync_look(horde: Horde, v: int, ground_y: float) -> void:
	var looks: int = _layers.size()
	var buf: PackedFloat32Array = _buffers[v]
	_buffers[v] = PackedFloat32Array()  # drop the shared reference so writes don't copy
	var pos: PackedVector2Array = horde.positions
	var head: PackedVector2Array = horde.heading
	var tint: PackedColorArray = horde.tint
	var look: PackedByteArray = horde.variant
	var clip: PackedByteArray = horde.anim
	var clip_t: PackedFloat32Array = horde.anim_time
	var clips: VatClips = models[v].clips if not models.is_empty() else null
	var rows_of: PackedInt32Array = _clip_index[v] if clips != null else PackedInt32Array()
	var n: int = 0
	for a: int in horde.count:
		if look[a] % looks != v:
			continue
		var o: int = n * FLOATS_PER_INSTANCE
		n += 1
		var p: Vector2 = pos[a]
		# Yaw so local +Z faces the heading: basis = rotation about Y.
		var c: float = head[a].y
		var s: float = head[a].x
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
		if clips != null:
			var rows: Vector3 = clips.rows_at(rows_of[clip[a]], clip_t[a])
			buf[o + 16] = rows.x
			buf[o + 17] = rows.y
			buf[o + 18] = rows.z
	_buffers[v] = buf
	var mm: MultiMesh = _layers[v].multimesh
	mm.buffer = buf
	mm.visible_instance_count = n


## Blocky placeholder: grey body, pale green head and arms reaching forward (+Z).
func _make_placeholder_mesh() -> ArrayMesh:
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
	mat.vertex_color_is_srgb = true
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
