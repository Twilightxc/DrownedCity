class_name Teammate
extends SpikePlayer
## An AI survivor fighting beside the player (PHASE1 1.5+ A5). Everything a fighter is (guns, stances, body,
## health, noise) comes from SpikePlayer; only the wishes come from a TeammateBrain instead of the keyboard.
## Downed, it waits for the player: stand next to it and press F (interact) to get it up in revive_sec.
## No friendly fire: rounds only test the horde.

const PROMPT_HEIGHT: float = 1.4

@export var teammate_config: TeammateConfig = preload("res://data/combat/teammate.tres")
@export var display_name: String = "Teammate"

var brain: TeammateBrain
var leader: SpikePlayer
var reviver: SpikePlayer  ## the player helping it up, null when nobody is
var revive_left: float = 0.0
var _prompt: Label3D


func _ready() -> void:
	super._ready()
	set_process_input(false)
	set_process_unhandled_input(false)
	brain = TeammateBrain.new(teammate_config)
	_prompt = Label3D.new()
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 36
	_prompt.outline_size = 10
	_prompt.position = Vector3(0.0, PROMPT_HEIGHT, 0.0)
	_prompt.visible = false
	add_child(_prompt)


func _process(delta: float) -> void:
	if grid == null:
		return
	if health.state != FighterHealth.State.DEAD and leader != null and horde != null:  # down: still shoots
		brain.think(delta, ground_position(), gun, _muzzle_over(), leader.ground_position(), leader.aim_dir, horde, grid)
		if brain.want_reload:
			start_reload()
		if health.is_alive():
			_swap_if_dry()
	_update_revive(delta)
	super._process(delta)


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


func _update_aim() -> void:
	aim_dir = brain.aim
	_aim_marker.rotation.y = atan2(aim_dir.x, aim_dir.y)


func _update_throw() -> void:
	pass  # teammates don't throw grenades (yet)


func _update_interact() -> void:
	pass


func _draw_aim_line() -> void:
	_aim_line.clear_surfaces()  # only the player shows an aim laser


# Downed: an interactable the player can help up.

func _update_revive(delta: float) -> void:
	var downed: bool = health.state == FighterHealth.State.DOWNED
	if downed and not is_in_group("interactable"):
		add_to_group("interactable")
	elif not downed and is_in_group("interactable"):
		remove_from_group("interactable")
		_prompt.visible = false
	if not downed:
		reviver = null
		return
	if reviver != null:
		if not reviver.health.is_alive() or reviver.ground_position().distance_to(ground_position()) > teammate_config.revive_radius_m:
			reviver = null  # walked off or went down: start again next time
		else:
			revive_left -= delta
			if revive_left <= 0.0:
				health.revive()
				reviver = null
	if _prompt.visible:
		_prompt.text = tr("Helping %s up…") % display_name if reviver != null else tr("[F] Help %s up") % display_name


## How far the revive is, 0..1, or -1 when nobody is helping (the HUD's ring).
func revive_fill() -> float:
	return 1.0 - revive_left / teammate_config.revive_sec if reviver != null else -1.0


func show_prompt(on: bool, _pad: bool) -> void:
	_prompt.visible = on and health.state == FighterHealth.State.DOWNED


func interact(player: SpikePlayer) -> void:
	if health.state == FighterHealth.State.DOWNED and reviver == null:
		reviver = player
		revive_left = teammate_config.revive_sec
