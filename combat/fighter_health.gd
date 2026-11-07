class_name FighterHealth
extends RefCounted
## One fighter's health (Phase 1 step 1.3; GDD §3 injuries, §5 downed, §7 armor). No nodes: the player
## drives it, tests drive it directly. Damage goes through the worn pieces; at 0 HP the fighter is downed
## for downed_sec, then dead unless revived (teammates come with expeditions, 1.9).

enum State { ALIVE, DOWNED, DEAD }

signal damaged(amount: int, kind: StringName)
signal state_changed(state: State)

var config: FighterConfig
var wearing: Array[ArmorConfig] = []
var hp: int
var max_hp: int  ## the config's, with the survivor's build on (apply_build)
var build: FighterBuild = FighterBuild.new()
var state: State = State.ALIVE
var downed_left: float = 0.0
var bites: int = 0  ## hits that broke the skin; SimCore turns them into infection (1.6)
var invulnerable: bool = false  ## measurements and autoshoot
var dodging: bool = false  ## a dodge roll's i-frames (1.5+ A3): zombie hits and blasts miss

var _partial: float = 0.0  ## damage-over-time below 1 HP carried to the next frame


func _init(cfg: FighterConfig, worn: Array[ArmorConfig] = []) -> void:
	config = cfg
	var used: Dictionary[String, bool] = {}
	for piece: ArmorConfig in worn:
		if not used.has(piece.slot):
			used[piece.slot] = true
			wearing.append(piece)
	max_hp = cfg.max_hp
	hp = max_hp


func is_alive() -> bool:
	return state == State.ALIVE


func hp_frac() -> float:
	return float(hp) / float(maxi(max_hp, 1))


## A survivor's build on this fighter: max HP and what hurts it how much. Starts at full health.
func apply_build(b: FighterBuild) -> void:
	build = b
	max_hp = b.hp(config.max_hp)
	hp = max_hp


## Product of one multiplier over every worn piece ("melee_mul", "gas_mul", ...).
func mul(property: StringName) -> float:
	var m: float = 1.0
	for piece: ArmorConfig in wearing:
		m *= float(piece.get(property))
	return m


func speed_mul() -> float:
	return mul(&"speed_mul")


func weight_kg() -> float:
	var w: float = 0.0
	for piece: ArmorConfig in wearing:
		w += piece.weight_kg
	return w


## One zombie hit; may be a bite (chance × the armor's bite_mul).
func take_hit(damage: int, rng: RandomNumberGenerator) -> void:
	if not is_alive() or invulnerable or dodging:
		return
	if rng.randf() < config.bite_chance * mul(&"bite_mul"):
		bites += 1
	_lose(roundi(damage * mul(&"melee_mul") * build.melee_taken()), &"melee")


func take_blast(damage: int, own: bool) -> void:
	if is_alive() and not dodging:
		_lose(roundi(damage * mul(&"blast_mul") * (config.self_blast_mul * build.self_blast() if own else 1.0)), &"blast")


## Damage over time (gas, fire): `dps` × delta, fractions carried so low rates still add up.
func take_dot(dps: float, delta: float, kind: StringName) -> void:
	if not is_alive() or dps <= 0.0:
		return
	var m: float = mul(&"gas_mul") * build.gas_taken() if kind == &"gas" else mul(&"fire_mul") if kind == &"fire" else 1.0
	_partial += dps * m * delta
	var whole: int = floori(_partial)
	if whole > 0:
		_partial -= whole
		_lose(whole, kind)


## Downed: counts down to death. Call every frame.
func step(delta: float) -> void:
	if state == State.DOWNED:
		downed_left -= delta
		if downed_left <= 0.0:
			_set_state(State.DEAD)


## A teammate's help (or a debug key): back up with a quarter of max HP.
func revive() -> void:
	if state == State.DOWNED:
		hp = maxi(max_hp / 4, 1)
		_set_state(State.ALIVE)


func _lose(amount: int, kind: StringName) -> void:
	if amount <= 0 or invulnerable:
		return
	hp = maxi(hp - amount, 0)
	damaged.emit(amount, kind)
	if hp == 0:
		downed_left = config.downed_sec
		_set_state(State.DOWNED)


func _set_state(s: State) -> void:
	state = s
	state_changed.emit(s)
