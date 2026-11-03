class_name GunModel
extends Resource
## How a gun looks: the exported mesh plus where its muzzle and attachment mounts are, in the mesh's own
## space (+Z = along the barrel, origin = the grip). Written by tools/blender/kit_guns.py next to the .glb.

@export var mesh_scene: PackedScene
@export var muzzle: Vector3 = Vector3(0.0, 0.0, 0.6)
@export var mag_scene: PackedScene  ## the loaded mag on the "mag" mount, hidden while it is out (null: none)
@export var mag_hand_scene: PackedScene  ## what the left hand holds in a reload: a full mag, or a shell
@export var support: Vector3 = Vector3.ZERO  ## where the left hand holds it (handguard, pump; a pistol: the grip)
@export var hand_points: Dictionary[String, Vector3] = {}  ## "handle" (rack), "port" (shells), "stock" (the shoulder)
@export var mounts: Dictionary[String, Vector3] = {}  ## attachment slot → mount point
@export var part_scale: float = 1.0  ## the gun's kit scale: attachments (built at real size) are scaled by it
