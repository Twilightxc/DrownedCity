class_name SfxEvent
extends Resource
## One kind of sound (a gun's shot, a zombie groan): a few takes picked at random, with its loudness, how far
## it carries and how many may play at once. Instances live in data/audio/sfx_bank.tres.

@export var streams: Array[AudioStream] = []
@export var volume_db: float = 0.0
@export var pitch_jitter: float = 0.05  ## ± random pitch per play, so repeats don't sound machine-gunned
@export var max_distance_m: float = 30.0  ## heard up to here from the listener; a shot uses its gun's noise_m
@export var max_voices: int = 4  ## more at once steals the oldest of this event
@export var min_interval_sec: float = 0.0  ## a new play sooner than this after the last one is dropped
