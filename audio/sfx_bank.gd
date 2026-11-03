class_name SfxBank
extends Resource
## Every sound event by name (PHASE1 1.5+ A1). Configs name their events (WeaponConfig.shot_sfx, ...).

@export var events: Dictionary[StringName, SfxEvent] = {}
@export var voices: int = 24  ## positional players in the pool; the web build mixes all of them on one thread
