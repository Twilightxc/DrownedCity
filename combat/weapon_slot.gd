class_name WeaponSlot
extends Resource
## A gun as carried: the weapon and the attachments on it (GDD §6). Part of a LoadoutConfig.

@export var weapon: WeaponConfig
@export var attachments: Array[AttachmentConfig] = []
