class_name ThrowableConfig
extends Resource
## Thrown explosive tunables. Instances live in data/weapons/*.tres.

@export var display_name: String = "Grenade"
@export var damage: int = 3
@export var blast_radius: float = 3.0  ## m
@export var flight_time: float = 0.7  ## s from release to blast
@export var arc_height: float = 2.5  ## m above the straight line at mid-flight
@export var min_range: float = 2.0  ## m
@export var max_range: float = 12.0  ## m
@export var carry: int = 3  ## how many the player holds after a restock

@export_group("Fire (incendiary)")
@export var fire_radius: float = 0.0  ## m: zombies left alive inside catch fire; 0 = no fire
@export var fire_cells: int = 0  ## ground cells set burning around the blast
