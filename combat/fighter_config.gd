class_name FighterConfig
extends Resource
## A fighter's health rules (player now; survivors on expeditions later). Instances live in data/combat/.

@export var max_hp: int = 100
@export var bite_chance: float = 0.15  ## per zombie hit, before armor (a bite risks infection, GDD §3)
@export var downed_sec: float = 20.0  ## GDD §5: this long for a teammate to help; nobody comes = death (J: 20 s, fighting with the pistol)
@export var gas_dps: float = 12.0  ## at a fresh cloud's centre (GasField.strength_at = 1)
@export var fire_dps: float = 15.0  ## standing in a burning cell
@export var self_blast_mul: float = 0.5  ## your own grenade's damage to you (0 = off)
@export var revive_sec: float = 2.0  ## someone stays next to this fighter, downed, this long to get it up (player: F; teammates on their own)
@export var revive_radius_m: float = 1.6

@export_group("Feedback")
@export var low_hp_frac: float = 0.25  ## the edge glows and slow-mo kicks in below this
@export var slowmo: bool = true
@export var slowmo_scale: float = 0.45  ## Engine.time_scale during the slow-mo
@export var slowmo_sec: float = 0.5  ## real seconds
