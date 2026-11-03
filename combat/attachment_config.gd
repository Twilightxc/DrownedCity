class_name AttachmentConfig
extends Resource
## A gun attachment (GDD §6): multipliers on the gun's numbers. Instances live in data/weapons/attachments/.

@export var display_name: String = "Attachment"
@export var slot: String = "muzzle"  ## muzzle · optic · under · mag; one per slot
@export var damage_mul: float = 1.0
@export var noise_mul: float = 1.0
@export var spread_mul: float = 1.0
@export var recoil_mul: float = 1.0
@export var mag_mul: float = 1.0
@export var reload_mul: float = 1.0
@export var wear_mul: float = 1.0
@export var weight_kg: float = 0.0
@export var mesh_scene: PackedScene  ## from tools/blender/kit_guns.py; origin = the gun's mount point for `slot`
@export var muzzle_extend_m: float = 0.0  ## the silencer moves the muzzle (and its flash) this far forward
@export var flashlight: bool = false  ## lights the way inside buildings (GDD: draws zombies at night, later)
