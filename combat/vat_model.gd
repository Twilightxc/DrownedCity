class_name VatModel
extends Resource
## One horde look: the exported mesh (UV.x = VAT column) plus its baked textures and clip table.
## Instances live next to the textures in assets/vat/.

@export var mesh_scene: PackedScene  ## the .glb from tools/blender/kit_zombie.py
@export var positions: Texture2D
@export var normals: Texture2D
@export var clips: VatClips

var _image: Image  ## CPU copy of `positions`, only loaded by part_bounds()
var _uvs: PackedVector2Array
var _bounds_cache: Dictionary[int, AABB] = {}


func extract_mesh() -> Mesh:
	var root: Node = mesh_scene.instantiate()
	var found: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	root.free()
	return mesh


## Bounds of the parts in `mask` (bit = part index, UV.y) at texture `row`, in the mesh's own space.
## Read once from the position texture on the CPU and cached: severed limbs need a pivot and a box
## for their rigid body.
func part_bounds(mask: int, row: int) -> AABB:
	var key: int = (row << 16) | mask
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	if _image == null:
		_image = positions.get_image()
		var arrays: Array = extract_mesh().surface_get_arrays(0)
		_uvs = arrays[Mesh.ARRAY_TEX_UV]
	if _image == null or _image.is_empty():
		push_warning("VatModel: no CPU copy of the VAT texture; limb bounds fall back to a box")
		return AABB(Vector3(-0.1, 0.6, -0.1), Vector3(0.2, 0.3, 0.2))
	var box: AABB = AABB()
	var first: bool = true
	for uv: Vector2 in _uvs:
		if ((mask >> int(uv.y)) & 1) == 0:
			continue
		var c: Color = _image.get_pixel(int(uv.x), row)
		var p: Vector3 = Vector3(c.r, c.g, c.b)
		if first:
			box = AABB(p, Vector3.ZERO)
			first = false
		else:
			box = box.expand(p)
	_bounds_cache[key] = box
	return box

