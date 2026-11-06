class_name LoadoutConfig
extends Resource
## What a fighter carries (GDD §6): guns in slot order (keys 1–4) and loose rounds by caliber.
## Instances live in data/weapons/.

@export var slots: Array[WeaponSlot] = []
@export var ammo: Dictionary[String, int] = {}  ## loose rounds at the start; a supply crate tops up to this
@export var wearing: Array[ArmorConfig] = []  ## GDD §7 pieces, one per slot
@export var melee: MeleeConfig  ## the one melee weapon (DECISIONS 2026-11-06); null = the fighter's own (a knife)
