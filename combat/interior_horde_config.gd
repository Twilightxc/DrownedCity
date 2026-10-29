class_name InteriorHordeConfig
extends Resource
## Zombies inside a building (GDD §5, PHASE0 0.8 part 2): how many sleep per storey and what wakes them.
## Instances live in data/combat/.

@export var per_storey: int = 15  ## dormant zombies on each walkable storey
@export var hatch_clear: float = 5.0  ## m around the roof-hatch landing kept free at spawn

@export_group("Waking")
@export var shot_noise: float = 12.0  ## m: a shot wakes sleepers this close on the shooter's storey
@export var blast_noise: float = 20.0  ## m, the same for a grenade blast
@export var floor_damping: float = 0.5  ## noise radius on the storeys just above and below
@export var sight: float = 6.0  ## m: a sleeper with line of sight to the player wakes
@export var chain: float = 2.5  ## m: a sleeper next to an awake zombie wakes
@export var check_sec: float = 0.2  ## sight and chain checks run this often
