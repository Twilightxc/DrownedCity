class_name FeelConfig
extends Resource
## Game feel tunables (GDD §6 "Boxhead part", Phase 1 step 1.4). Every effect can be switched off (motion
## sensitivity, streaming, playtests). Instances live in data/fx/.

@export_group("Hit-stop")
@export var hitstop: bool = true
@export var hitstop_kills: int = 2  ## kills by one round (or one blast) that freeze the frame
@export var hitstop_sec: float = 0.045  ## real seconds
@export var hitstop_blast_sec: float = 0.07
@export var hitstop_scale: float = 0.05

@export_group("Camera shake")
@export var shake: bool = true
@export var shake_max_m: float = 0.5  ## camera offset at full trauma
@export var shake_decay: float = 2.2  ## trauma lost per second
@export var shake_per_recoil_deg: float = 0.06  ## a shot adds the gun's recoil × this
@export var shake_blast: float = 0.7  ## at the blast centre, falling off to 0 at 15 m
@export var shake_hit: float = 0.25  ## taking a hit

@export_group("Muzzle and casings")
@export var muzzle_flash: bool = true
@export var muzzle_light_energy: float = 1.6
@export var casings: bool = true
@export var casing_life_sec: float = 6.0

@export_group("Kill chain")
@export var chain_window_sec: float = 2.0  ## the next kill within this keeps the chain going
@export var chain_score_cap: int = 10  ## a kill scores the chain length, up to this
