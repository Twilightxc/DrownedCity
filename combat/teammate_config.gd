class_name TeammateConfig
extends Resource
## How an AI teammate fights (PHASE1 1.5+ A5). Instances live in data/combat/.

@export_group("Following")
@export var follow_distance_m: float = 2.0  ## behind the leader, along the leader's aim
@export var side_offset_m: float = 2.2  ## to the leader's left or right (each teammate its own side)
@export var arrive_m: float = 0.7  ## close enough to its spot to stop
@export var sprint_beyond_m: float = 9.0  ## sprints back to its spot when further than this and nothing to shoot
@export var kite_m: float = 2.4  ## backs away from any zombie closer than this

@export_group("Shooting")
@export var engage_range_mul: float = 0.85  ## × the gun's range: targets beyond aren't picked
@export var protect_weight: float = 0.0  ## a zombie's distance to the leader counts this much against it (J: 0, nearest to itself first)
@export var retarget_sec: float = 0.25
@export var reaction_sec: float = 0.3  ## a new target is held this long before the first shot
@export var aim_turn_deg_per_sec: float = 420.0
@export var fire_cone_deg: float = 5.0  ## fires only once aimed this close to the target
@export var burst_sec: float = 0.35  ## automatic guns: bursts this long...
@export var burst_pause_sec: float = 0.25  ## ...with this pause so the bloom settles
@export var tactical_reload_frac: float = 0.4  ## reloads when nothing is near and the mag is below this

@export_group("Melee")
@export var melee_charge_m: float = 4.0  ## "melee only": steps in to a lone hunting zombie this close
@export var quiet_noise_m: float = 15.0  ## "quiet only": shoots only a gun this quiet or quieter (a silenced pistol: 10 m)
@export var mob_count: int = 3  ## under "hold fire" it stands and knifes a lone zombie; this many within kite_m: it backs off

@export_group("Stance")
@export var stance_check_sec: float = 0.5  ## how often it rethinks its stance while standing still
@export var crouch_safe_m: float = 5.0  ## crouches only with no hunting zombie closer than this
@export var prone_safe_m: float = 10.0  ## goes prone only with no hunting zombie closer than this
@export var sneak_radius_m: float = 15.0  ## no hunters but a sleeping / suspicious zombie this close: moves crouched

@export_group("Grenades")
@export var throwable: ThrowableConfig = preload("res://data/weapons/frag_grenade.tres")  ## null: never throws
@export var grenades: int = 2  ## how many each teammate carries into the fight
@export var throw_min_cluster: int = 5  ## hunting zombies inside one blast before it throws
@export var throw_check_sec: float = 0.5
@export var throw_cooldown_sec: float = 6.0
@export var throw_safety_m: float = 1.0  ## no friend (itself included) within blast radius + this of the point

@export_group("Down")
## (How long and how close a revive takes is the downed fighter's FighterConfig.revive_sec / revive_radius_m.)
@export var revive_kite_m: float = 1.2  ## going to help someone up: only backs off a zombie this close
