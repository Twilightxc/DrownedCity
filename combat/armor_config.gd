class_name ArmorConfig
extends Resource
## One worn piece (GDD §7): what it protects against and what it costs. Instances live in data/armor/.
## One piece per slot; the slots follow GDD §7 (head · face · torso_outer · armor · legs · feet · pack).

@export var display_name: String = "Armor"
@export var slot: String = "armor"
@export var melee_mul: float = 1.0  ## × damage from zombie hits
@export var bite_mul: float = 1.0  ## × the chance that a hit is a bite (infection, GDD §3)
@export var gas_mul: float = 1.0  ## × gas damage (a filter mask: 0)
@export var fire_mul: float = 1.0  ## × burn damage
@export var blast_mul: float = 1.0  ## × grenade blast damage
@export var bullet_armor: WeaponConfig.Armor = WeaponConfig.Armor.NONE  ## against human enemies' guns, later
@export var speed_mul: float = 1.0  ## walking
@export var weight_kg: float = 0.0  ## with the guns: swimming and sinking (GDD §7, with the water)
@export var sinks: bool = false  ## heavy armor: falling in the water drowns you
