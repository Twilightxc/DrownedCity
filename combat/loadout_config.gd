class_name LoadoutConfig
extends Resource
## What a fighter carries (GDD §6): guns in slot order (keys 1–4) and loose rounds by caliber.
## Instances live in data/weapons/.

@export var slots: Array[WeaponSlot] = []
@export var ammo: Dictionary[String, int] = {}  ## loose rounds at the start; a supply crate tops up to this
