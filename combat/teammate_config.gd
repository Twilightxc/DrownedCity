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

@export_group("Down")
@export var revive_sec: float = 2.0  ## the player stays next to a downed teammate this long (F) to get it up
@export var revive_radius_m: float = 1.6
