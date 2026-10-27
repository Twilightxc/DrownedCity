class_name GoreConfig
extends Resource
## Corpses, blood and dismemberment tunables (GDD §6). Instances live in data/fx/*.tres.
## Caps keep the web budget: every system is a ring buffer drawn with one MultiMesh.

@export var enabled: bool = true  ## the "blood and dismemberment" setting; corpses stay either way

@export_group("Corpses")
@export var corpse_cap: int = 160  ## corpses + severed limbs on screen at once
@export var corpse_life_sec: float = 45.0  ## then they sink through the floor
@export var sink_sec: float = 1.5
@export var sink_depth: float = 0.5  ## m below the floor = gone
@export var water_float_sec: float = 6.0  ## corpses that land in water float, then sink

@export_group("Dismemberment")
@export var dismember_chance: float = 0.12  ## per bullet kill
@export var dismember_chance_blast: float = 0.6
@export var limb_throw: Vector2 = Vector2(0.5, 1.3)  ## m from the corpse, along the push

@export_group("Blood")
@export var droplet_cap: int = 256
@export var droplets_per_hit: int = 6
@export var droplet_speed: Vector2 = Vector2(1.5, 4.0)  ## m/s along the bullet
@export var droplet_life: float = 0.6
@export var pool_cap: int = 160
@export var pool_on_hit_chance: float = 0.3
@export var hit_pool_size: Vector2 = Vector2(0.3, 0.6)
@export var death_pool_size: Vector2 = Vector2(1.1, 1.7)
@export var pool_grow_sec: float = 2.5
@export var pool_life_sec: float = 60.0
@export var zombie_blood: Color = Color("#6a2720")  ## darker than human blood (GDD §6). sRGB
@export var zombie_pool: Color = Color("#5c211b")
