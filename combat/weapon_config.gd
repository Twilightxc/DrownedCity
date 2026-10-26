class_name WeaponConfig
extends Resource
## Hitscan weapon tunables. Instances live in data/weapons/*.tres.

@export var display_name: String = "Weapon"
@export var damage: int = 1
@export var penetration: int = 1  ## targets one bullet can pass through
@export var fire_rate: float = 8.0  ## shots per second
@export var max_range: float = 30.0  ## m
@export var spread_deg: float = 2.0  ## ± random angle per shot
@export var magazine_size: int = 30
@export var reload_time: float = 1.6  ## s
