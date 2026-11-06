class_name MeleeConfig
extends Resource
## A melee weapon (GDD §6: knife, axe, crowbar, boat hook; 35–70 damage, silent, saves rounds). Every fighter
## carries one (PHASE1 bug list item 10: teammates defend themselves under "hold fire"). Instances in data/weapons/.

@export var display_name: String = "Knife"
@export var damage: int = 40
@export var armor_pen: WeaponConfig.Armor = WeaponConfig.Armor.L
@export var sneak_mul: float = 2.5  ## × damage on a zombie that isn't hunting yet (a silent takedown)
@export var reach_m: float = 1.4  ## from the fighter's centre to the zombie's
@export var arc_deg: float = 110.0  ## hits inside this cone around the aim
@export var max_targets: int = 1  ## nearest first
@export var windup_sec: float = 0.12  ## the hit lands this long after the press
@export var swing_sec: float = 0.45  ## the whole swing: no shooting, and the next swing after this
@export var knockback: float = 2.5  ## m/s along the push
@export var stagger_sec: float = 0.35
@export var noise_m: float = 2.0  ## GDD: 2 m
@export var stamina: float = 8.0  ## a swing costs this; not enough stamina, no swing
