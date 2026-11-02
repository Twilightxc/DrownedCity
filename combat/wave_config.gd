class_name WaveConfig
extends Resource
## One wave of a horde night (Phase 1 step 1.5). Part of an ArenaConfig.

@export var counts: PackedInt32Array = PackedInt32Array()  ## zombies per enemy type (HordeConfig.types order)
@export var entrances: PackedInt32Array = PackedInt32Array()  ## which ArenaConfig entrances they climb in from
@export var spawn_per_sec: float = 4.0
@export var break_before_sec: float = 15.0  ## calm before it starts: restock, reposition
