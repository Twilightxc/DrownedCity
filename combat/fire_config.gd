class_name FireConfig
extends Resource
## Burning zombies and ground fire tunables (GDD §6, PHASE0 0.7 part 3). Instances live in data/combat/.

@export_group("Burning zombies")
@export var burn_sec: float = 4.0  ## how long a zombie burns after the last ignition
@export var burn_tick_sec: float = 0.5
@export var burn_damage: int = 1  ## per tick
@export var spread_radius: float = 0.7  ## m: a burning zombie bumping into another lights it
@export var spread_chance_per_sec: float = 0.6
@export var burn_speed_mul: float = 1.25  ## burning zombies lurch faster

@export_group("Ground fire")
@export var cell_cap: int = 12  ## burning NavGrid cells at once
@export var cell_life_sec: float = 6.0
@export var cell_cost: int = 6  ## extra flow-field steps to cross a burning cell: the crowd walks around

@export_group("Spot burning (frag)")
@export var spot_burn_sec: float = 2.5  ## a small fire on one body part: no spread, no lurch
@export var spot_burn_damage: int = 1  ## per burn tick
