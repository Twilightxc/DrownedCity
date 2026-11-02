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
@export var flashlight: bool = false  ## lights the way inside buildings (GDD: draws zombies at night, later)
