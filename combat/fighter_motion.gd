class_name FighterMotion
extends RefCounted
## A fighter's stance, sprint, dodge roll and stamina (PHASE1 1.5+ A3). Pure state: the player (and the AI
## teammates, A5) feed it input and read the multipliers: speed, spread, step noise, how far zombies see them.

enum Stance { STAND, CROUCH, PRONE }

var config: MovementConfig
var stance: Stance = Stance.STAND
var stamina: float
var sprinting: bool = false
var roll_left: float = 0.0
var roll_dir: Vector2 = Vector2.ZERO
var _cooldown: float = 0.0
var _regen_wait: float = 0.0


func _init(cfg: MovementConfig) -> void:
	config = cfg
	stamina = cfg.stamina_max


func toggle_crouch() -> void:
	if not is_rolling():
		stance = Stance.STAND if stance == Stance.CROUCH else Stance.CROUCH
		sprinting = false


func toggle_prone() -> void:
	if not is_rolling():
		stance = Stance.STAND if stance == Stance.PRONE else Stance.PRONE
		sprinting = false


## Rolls along `dir` (unit, ground plane). Not from prone, not on cooldown, not without the stamina.
func try_roll(dir: Vector2) -> bool:
	if is_rolling() or _cooldown > 0.0 or stance == Stance.PRONE or dir == Vector2.ZERO \
			or stamina < config.roll_stamina:
		return false
	stamina -= config.roll_stamina
	_regen_wait = config.stamina_regen_delay_sec
	roll_left = config.roll_sec
	roll_dir = dir.normalized()
	sprinting = false
	return true


## `want_sprint`: the sprint button is held; `moving`: there is movement input; `firing`: the trigger is held
## (shooting stops a sprint).
func step(delta: float, want_sprint: bool, moving: bool, firing: bool = false) -> void:
	if roll_left > 0.0:
		roll_left = maxf(roll_left - delta, 0.0)
		if roll_left == 0.0:
			_cooldown = config.roll_cooldown_sec
	else:
		_cooldown = maxf(_cooldown - delta, 0.0)
	var can: bool = want_sprint and moving and not firing and not is_rolling() and stance != Stance.PRONE
	if can and not sprinting and stamina >= config.sprint_min_stamina:
		sprinting = true
		stance = Stance.STAND  # sprinting from a crouch stands you up
	elif not can or stamina <= 0.0:
		sprinting = false
	if sprinting:
		stamina = maxf(stamina - config.sprint_stamina_per_sec * delta, 0.0)
		_regen_wait = config.stamina_regen_delay_sec
	elif _regen_wait > 0.0:
		_regen_wait -= delta
	elif not is_rolling():
		stamina = minf(stamina + config.stamina_regen_per_sec * delta, config.stamina_max)


func is_rolling() -> bool:
	return roll_left > 0.0


## Zombie hits and blasts miss in the first roll_iframes_sec of a roll.
func has_iframes() -> bool:
	return is_rolling() and config.roll_sec - roll_left < config.roll_iframes_sec


func roll_velocity() -> Vector2:
	return roll_dir * config.roll_distance_m / maxf(config.roll_sec, 0.01)


func can_shoot() -> bool:
	return not sprinting and not is_rolling()


func speed_mul() -> float:
	return config.sprint_speed_mul if sprinting else config.speed_mul[stance]


func spread_mul() -> float:
	return config.spread_mul[stance]


func step_noise_m() -> float:
	return config.sprint_step_noise_m if sprinting else config.step_noise_m[stance]


func step_m() -> float:
	return config.step_m[stance]


func seen_mul() -> float:
	return config.seen_mul[stance]


func body_height_m() -> float:
	return config.body_height_m[stance]


func stamina_fraction() -> float:
	return stamina / config.stamina_max if config.stamina_max > 0.0 else 0.0
