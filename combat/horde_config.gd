class_name HordeConfig
extends Resource
## Zombie crowd tunables. Instances live in data/combat/*.tres.

@export_group("Movement")
@export var speed: float = 2.2  ## m/s
@export var speed_jitter: float = 0.25  ## ± fraction per zombie
@export var steering: float = 8.0  ## how fast velocity turns toward the desired one (1/s)
@export var radius: float = 0.3  ## m, body radius for separation and bullet hits
@export var separation_strength: float = 4.0

@export_group("Combat")
@export var hp: int = 3
@export var attack_range: float = 0.9  ## m
@export var attack_interval: float = 1.0  ## s between hits per zombie
@export var hit_damage: int = 10  ## per attack when the horde has no types

@export_group("Hit reaction (GDD §6; 0 for armored types)")
@export var hit_slow: float = 0.3  ## speed fraction lost while slowed
@export var hit_slow_sec: float = 0.4  ## added per hit
@export var hit_slow_cap_sec: float = 1.2  ## stacking cap

@export_group("Animation")
@export var walk_stride: float = 1.3  ## m covered per walk cycle (two steps); matches the VAT walk clip
@export var attack_anim_sec: float = 0.75
@export var flinch_anim_sec: float = 0.33
@export var variants: int = 2  ## looks drawn by HordeRenderer (male / female)

@export_group("Types (GDD §9)")
@export var types: Array[EnemyConfig] = []  ## empty: one plain type from the numbers above
@export var spawn_mix: PackedFloat32Array = PackedFloat32Array()  ## weight per type for spawns; empty = all type 0

@export_group("Perception (GDD §9: sound first, sight second)")
@export var sight_m: float = 10.0  ## a calm zombie with line of sight this close starts hunting
@export var hunt_noise_frac: float = 0.35  ## a noise this close (× its radius) makes it hunt at once
@export var suspicious_sec: float = 10.0  ## a suspicious zombie that finds nothing calms down after this
@export var lose_sec: float = 5.0  ## a hunter without sight of its target this long turns suspicious
@export var perceive_sec: float = 0.2  ## sight checks run this often
@export var suspicious_speed: float = 0.7  ## × speed while walking to a noise

@export_group("Flow field")
@export var flow_recompute_sec: float = 0.25

@export_group("Spike harness")
@export var spawn_counts: PackedInt32Array = PackedInt32Array([50, 100, 200, 300])
@export var default_count_index: int = 2
@export var spawn_per_second: float = 120.0
@export var spawn_min_distance: float = 8.0  ## m from the player
