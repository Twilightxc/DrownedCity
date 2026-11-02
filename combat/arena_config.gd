class_name ArenaConfig
extends Resource
## A horde night on the base roof (Phase 1 step 1.5; GDD §2 night, §10 horde): where zombies climb up, which
## entrances are barricaded, and the waves. Instances live in data/combat/.

@export var entrance_cells: Array[Vector2i] = []  ## roof NavGrid cell on the edge where they climb up
@export var entrance_names: PackedStringArray = PackedStringArray()
@export var barricade_hp: PackedInt32Array = PackedInt32Array()  ## per entrance; 0 = open
@export var barricade_cost: int = 8  ## extra flow-field steps through a barricade: they go round if it's shorter
@export var waves: Array[WaveConfig] = []
@export var alive_cap: int = 200  ## zombies on the roof at once (web budget)
@export var crate_uses_per_break: int = 1  ## each supply crate restocks once per calm between waves
