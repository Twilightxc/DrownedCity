class_name VatModel
extends Resource
## One horde look: the exported mesh (UV.x = VAT column) plus its baked textures and clip table.
## Instances live next to the textures in assets/vat/.

@export var mesh_scene: PackedScene  ## the .glb from tools/blender/kit_zombie.py
@export var positions: Texture2D
@export var normals: Texture2D
@export var clips: VatClips


func extract_mesh() -> Mesh:
	var root: Node = mesh_scene.instantiate()
	var found: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	root.free()
	return mesh
