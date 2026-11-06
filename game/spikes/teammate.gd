class_name Teammate
extends SpikePlayer
## An AI survivor fighting beside the player (PHASE1 1.5+ A5). Everything a fighter is (guns, stances, body,
## health, noise) comes from SpikePlayer; only the wishes come from a TeammateBrain instead of the keyboard.
## Downed, anyone in the squad can get it up (SpikePlayer.start_revive): the player stands next to it and
## presses F; another teammate comes on its own. It goes to help a downed squad member too (the leader first),
## throws frags into packed crowds, and crouches or goes prone on its own when the cover and the crowd allow. No friendly fire: rounds only
## test the horde.

const PROMPT_HEIGHT: float = 1.4

@export var teammate_config: TeammateConfig = preload("res://data/combat/teammate.tres")

var brain: TeammateBrain
var leader: SpikePlayer
var squad: Array[SpikePlayer] = []  ## everyone on this side, the leader and itself included (shared array)
var patient: SpikePlayer  ## the downed squad member it is going to help up, null when none
var _prompt: Label3D
var _gun_before_rule: Gun  ## the long gun put away for "quiet only"


func _ready() -> void:
	super._ready()
	display_name = "Teammate" if display_name == "You" else display_name
	set_process_input(false)
	set_process_unhandled_input(false)
	brain = TeammateBrain.new(teammate_config)
	brain.muzzle_heights = movement.muzzle_height_m
	brain.melee_reach = melee_weapon.reach_m if melee_weapon != null else 0.0
	_prompt = Label3D.new()
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 36
	_prompt.outline_size = 10
	_prompt.position = Vector3(0.0, PROMPT_HEIGHT, 0.0)
	_prompt.visible = false
	add_child(_prompt)


func setup(nav: NavGrid, crowd: Horde, cam: Camera3D, y: float) -> void:
	super.setup(nav, crowd, cam, y)
	throwable = teammate_config.throwable
	grenade_count = teammate_config.grenades


func _process(delta: float) -> void:
	if grid == null:
		return
	if health.state != FighterHealth.State.DEAD and leader != null and horde != null:  # down: still shoots
		_pick_patient()
		brain.has_patient = patient != null
		if patient != null:
			brain.patient_pos = patient.ground_position()
			brain.patient_radius = patient.health.config.revive_radius_m
		brain.can_throw = health.is_alive() and grenades != null and throwable != null and grenade_count > 0
		brain.throw_blast_m = throwable.blast_radius if throwable != null else 0.0
		brain.throw_range = Vector2(throwable.min_range, throwable.max_range) if throwable != null else Vector2.ZERO
		brain.allies = _ally_positions()
		brain.think(delta, ground_position(), gun, _muzzle_over(), leader.ground_position(), leader.aim_dir, horde, grid)
		if brain.want_reload:
			start_reload()
		if health.is_alive():
			_swap_if_dry()
			_gun_for_rule()
			_apply_stance()
			if brain.reviving and patient != null:
				patient.start_revive(self)
	super._process(delta)
	_update_prompt()


## The downed squad member to help: the leader first, then the nearest; never one someone else is helping.
func _pick_patient() -> void:
	patient = null
	if not health.is_alive():
		return
	var best_d: float = INF
	for f: SpikePlayer in squad:
		if f == self or f.health.state != FighterHealth.State.DOWNED or (f.reviver != null and f.reviver != self):
			continue
		var d: float = f.ground_position().distance_to(ground_position()) - (1000.0 if f == leader else 0.0)
		if d < best_d:
			best_d = d
			patient = f


func _ally_positions() -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array([ground_position()])
	for f: SpikePlayer in squad:
		if f != self and f.health.state != FighterHealth.State.DEAD:
			out.append(f.ground_position())
	if leader != null and not squad.has(leader):
		out.append(leader.ground_position())
	return out


func _apply_stance() -> void:
	if motion.stance != brain.stance and not motion.is_rolling():
		motion.stance = brain.stance as FighterMotion.Stance
		motion.sprinting = false


## "Quiet only": out comes a gun quiet enough (the silenced pistol); once the rule allows the long gun again it
## goes back to the one it had.
func _gun_for_rule() -> void:
	if brain.may_shoot(gun):
		if _gun_before_rule != null and brain.fire_rule == TeammateBrain.FireRule.AT_WILL:
			select_gun(guns.find(_gun_before_rule))
			_gun_before_rule = null
		return
	if brain.fire_rule != TeammateBrain.FireRule.QUIET:
		return
	for g: Gun in guns:
		if g != gun and brain.may_shoot(g):
			if _gun_before_rule == null:
				_gun_before_rule = gun
			select_gun(guns.find(g))
			return


## Out of rounds for the gun in hand (none in the mag, none left to load): the next gun that has some.
func _swap_if_dry() -> void:
	if gun.ammo > 0 or gun.is_reloading() or pouch == null or pouch.count(gun.config.caliber) > 0:
		return
	for g: Gun in guns:
		if g != gun and (g.ammo > 0 or pouch.count(g.config.caliber) > 0):
			select_gun(guns.find(g))
			return


func _move_input() -> Vector2:
	return brain.move if brain != null else Vector2.ZERO


func _wants_sprint() -> bool:
	return brain != null and brain.sprint


func _wants_fire() -> bool:
	return brain != null and brain.fire


func _wants_melee() -> bool:
	return brain != null and brain.want_melee


func _update_aim() -> void:
	aim_dir = brain.aim
	_aim_marker.rotation.y = atan2(aim_dir.x, aim_dir.y)


func _update_throw() -> void:
	if not brain.want_throw or grenades == null or throwable == null or grenade_count <= 0:
		return
	grenades.throw(throwable, Vector3(position.x, ground_y + THROW_HEIGHT, position.z),
			Vector3(brain.throw_at.x, ground_y, brain.throw_at.y))
	grenade_count -= 1
	brain.threw()


func _update_interact() -> void:
	pass


func _draw_aim_line() -> void:
	_aim_line.clear_surfaces()  # only the player shows an aim laser


# Downed: an interactable the player can help up.

func _update_revive(delta: float) -> void:
	super._update_revive(delta)
	var downed: bool = health.state == FighterHealth.State.DOWNED
	if downed and not is_in_group("interactable"):
		add_to_group("interactable")
	elif not downed and is_in_group("interactable"):
		remove_from_group("interactable")
		_prompt.visible = false


func _update_prompt() -> void:
	if _prompt.visible:
		_prompt.text = tr("Helping %s up…") % display_name if reviver != null else tr("[F] Help %s up") % display_name


func show_prompt(on: bool, _pad: bool) -> void:
	_prompt.visible = on and health.state == FighterHealth.State.DOWNED


func interact(player: SpikePlayer) -> void:
	start_revive(player)
