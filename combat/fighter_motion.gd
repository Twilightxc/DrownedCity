class_name FighterMotion
extends RefCounted
## A fighter's stance, sprint, dodge roll and stamina (PHASE1 1.5+ A3). Pure state: the player (and the AI
## teammates, A5) feed it input and read the multipliers: speed, spread, step noise, how far zombies see them.

enum Stance { STAND, CROUCH, PRONE }

var config: MovementConfig
var build: FighterBuild = FighterBuild.new()  ## the survivor's stamina and noise (apply_build)
var stance: Stance = Stance.STAND
var stamina: float
var sprinting: bool = false
var roll_left: float = 0.0
var roll_dir: Vector2 = Vector2.ZERO
var roll_sec: float = 0.0  ## the current roll's length (a prone roll is shorter)
var roll_distance_m: float = 0.0
var moving: bool = false  ## last step's movement input
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


## Rolls along `dir` (unit, ground plane). Not on cooldown, not without the stamina. Prone (J bug 14) it is a
## short log roll to the side of `aim` that `dir` leans to, and refused when `dir` runs along the aim.
func try_roll(dir: Vector2, aim: Vector2 = Vector2.ZERO) -> bool:
	if is_rolling() or _cooldown > 0.0 or dir == Vector2.ZERO:
		return false
	var cost: float = build.roll_cost(config.roll_stamina)
	var along: Vector2 = dir.normalized()
	roll_sec = config.roll_sec
	roll_distance_m = config.roll_distance_m
	if stance == Stance.PRONE:
		var side: Vector2 = aim.normalized().orthogonal()
		var lean: float = along.dot(side)
		if aim == Vector2.ZERO or absf(lean) < 0.3:
			return false
		along = side * signf(lean)
		cost = build.roll_cost(config.prone_roll_stamina)
		roll_sec = config.prone_roll_sec
		roll_distance_m = config.prone_roll_distance_m
	if stamina < cost:
		return false
	stamina -= cost
	_regen_wait = config.stamina_regen_delay_sec
	roll_left = roll_sec
	roll_dir = along
	sprinting = false
	return true


## `want_sprint`: the sprint button is held; `moving`: there is movement input; `firing`: the trigger is held
## (shooting stops a sprint).
func step(delta: float, want_sprint: bool, is_moving: bool, firing: bool = false) -> void:
	moving = is_moving
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
		stamina = maxf(stamina - build.sprint_cost(config.sprint_stamina_per_sec) * delta, 0.0)
		_regen_wait = config.stamina_regen_delay_sec
	elif _regen_wait > 0.0:
		_regen_wait -= delta
	elif not is_rolling():
		stamina = minf(stamina + build.stamina_regen(config.stamina_regen_per_sec) * delta, stamina_max())


func is_rolling() -> bool:
	return roll_left > 0.0


## Zombie hits and blasts miss in the first roll_iframes_sec of a roll.
func has_iframes() -> bool:
	return is_rolling() and roll_sec - roll_left < config.roll_iframes_sec


func roll_velocity() -> Vector2:
	return roll_dir * roll_distance_m / maxf(roll_sec, 0.01)


## No shots on the run, mid-roll or crawling (J bug 15: the rifle rides across the forearms while crawling).
func can_shoot() -> bool:
	return not sprinting and not is_rolling() and not (stance == Stance.PRONE and moving)


func speed_mul() -> float:
	return config.sprint_speed_mul if sprinting else config.speed_mul[stance]


func spread_mul() -> float:
	return config.spread_mul[stance]


func step_noise_m() -> float:
	return build.step_noise(config.sprint_step_noise_m if sprinting else config.step_noise_m[stance])


func step_m() -> float:
	return config.step_m[stance]


func seen_mul() -> float:
	return config.seen_mul[stance]


func body_height_m() -> float:
	return config.body_height_m[stance]


func stamina_fraction() -> float:
	return stamina / stamina_max() if stamina_max() > 0.0 else 0.0


func stamina_max() -> float:
	return build.stamina_max(config.stamina_max)


## A survivor's build on this fighter; starts with a full bar.
func apply_build(b: FighterBuild) -> void:
	build = b
	stamina = stamina_max()
