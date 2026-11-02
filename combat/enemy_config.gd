class_name EnemyConfig
extends Resource
## One zombie type (GDD §9). Instances live in data/enemies/*.tres; HordeConfig.types lists them.
## Until the desktop builds a mesh per type, the type reads by body scale and tint on the shared VAT models.

@export var display_name: String = "Walker"
@export var hp: int = 100
@export var hit_damage: int = 10  ## per attack on the player (armor reduces it, FighterHealth)
@export var speed_mul: float = 1.0  ## × HordeConfig.speed
@export var armor: WeaponConfig.Armor = WeaponConfig.Armor.NONE
@export var hit_slow_mul: float = 1.0  ## × the horde's hit slow (0: armored types don't slow)
@export var stagger_mul: float = 1.0  ## × a gun's stagger
@export var knockback_mul: float = 1.0  ## × a gun's knock-back (heavy types barely move)
@export var sight_mul: float = 1.0  ## × HordeConfig.sight_m
@export var gas_on_death: bool = false  ## Bloater: leaves a toxic cloud
@export var gas_radius_m: float = 3.0
@export var gas_sec: float = 8.0

@export_group("Look")
@export var scale: Vector3 = Vector3.ONE  ## body scale; type silhouette beats sub-variant detail
@export var tints: PackedColorArray = PackedColorArray([Color(1, 1, 1)])  ## sub-variants, × a small random shade
