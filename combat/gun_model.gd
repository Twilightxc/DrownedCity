class_name GunModel
extends Resource
## How a gun looks: the exported mesh plus where its muzzle and attachment mounts are, in the mesh's own
## space (+Z = along the barrel, origin = the grip). Written by tools/blender/kit_guns.py next to the .glb.

@export var mesh_scene: PackedScene
@export var muzzle: Vector3 = Vector3(0.0, 0.0, 0.6)
@export var mounts: Dictionary[String, Vector3] = {}  ## attachment slot → mount point
