class_name MovementConfig
extends Resource
## How a fighter moves (PHASE1 1.5+ A3): stances, sprint, dodge roll and stamina. Per-stance arrays are
## indexed by FighterMotion.Stance (stand, crouch, prone). Instances live in data/combat/.

@export_group("Stand / crouch / prone")
@export var speed_mul: PackedFloat32Array = PackedFloat32Array([1.0, 0.55, 0.22])
@export var spread_mul: PackedFloat32Array = PackedFloat32Array([1.0, 0.7, 0.5])  ## steadier lower down
@export var step_noise_m: PackedFloat32Array = PackedFloat32Array([6.0, 2.5, 1.0])  ## zombies this close hear a step
@export var step_m: PackedFloat32Array = PackedFloat32Array([0.75, 0.55, 0.45])  ## a step (and its noise) every this far
@export var seen_mul: PackedFloat32Array = PackedFloat32Array([1.0, 0.65, 0.35])  ## × how far zombies see you
@export var body_height_m: PackedFloat32Array = PackedFloat32Array([1.5, 0.95, 0.35])  ## low cover under this doesn't hide you
@export var muzzle_height_m: PackedFloat32Array = PackedFloat32Array([1.38, 1.0, 0.38])  ## a held gun's muzzle (measured on the survivor, 2026-11-05): shots pass low cover under this

@export_group("Sprint")
@export var sprint_speed_mul: float = 1.6
@export var sprint_step_noise_m: float = 12.0
@export var sprint_stamina_per_sec: float = 18.0
@export var sprint_min_stamina: float = 15.0  ## needed to start sprinting

@export_group("Dodge roll")
@export var roll_distance_m: float = 3.0
@export var roll_sec: float = 0.54  ## the survivor's roll clip is this long
@export var roll_iframes_sec: float = 0.35  ## zombie hits and blasts miss for this long from the start
@export var roll_cooldown_sec: float = 0.6
@export var roll_stamina: float = 25.0
@export var roll_noise_m: float = 5.0

@export_group("Stamina")
@export var stamina_max: float = 100.0
@export var stamina_regen_per_sec: float = 22.0
@export var stamina_regen_delay_sec: float = 0.8  ## after sprinting or rolling
