extends Node3D
## `?spike=poses` (PHASE1 1.5+ A2): every survivor clip side by side, labelled, so J can judge them at a glance.
## One-shots (roll, reloads, getting down / up, death, switch, melee) replay every few seconds. Q / E turn the camera, the wheel zooms.

const LOADOUT: LoadoutConfig = preload("res://data/weapons/spike_loadout.tres")
const SPACING: float = 2.6
const PER_ROW: int = 7
const REPLAY_SEC: float = 2.5

# label, lower clip, upper clip, upper weight, gun slot (0 AR, 1 pistol, 2 shotgun, 3 DMR), walk speed m/s
const POSES: Array = [
	["idle + aim (rifle)", &"idle", &"aim_rifle", 1.0, 0, 0.0],
	["walk + aim", &"walk", &"aim_rifle", 1.0, 0, 1.4],
	["sprint: port arms", &"run", &"carry_port", 1.0, 0, 4.2],
	["sprint: high ready", &"run", &"carry_high", 1.0, 1, 4.2],
	["crouch + aim", &"crouch_idle", &"aim_rifle", 1.0, 0, 0.0],
	["crouch walk + aim", &"crouch_walk", &"aim_rifle", 1.0, 0, 0.9],
	["aim (pistol)", &"idle", &"aim_pistol", 1.0, 1, 0.0],
	["prone", &"prone_idle", &"aim_rifle", 0.0, 0, 0.0],
	["crawl", &"crawl", &"aim_rifle", 0.0, 0, 0.6],
	["roll", &"roll", &"aim_rifle", 0.0, 0, 0.0],
	["downed", &"downed", &"aim_pistol", 0.0, 1, 0.0],
	["reload (pistol)", &"idle", &"reload_pistol", 1.0, 1, 0.0],
	["reload (rifle)", &"idle", &"reload_rifle", 1.0, 0, 0.0],
	["reload (shell)", &"idle", &"reload_shell", 1.0, 2, 0.0],
	["get down", &"go_prone", &"aim_rifle", 0.0, 0, 0.0],
	["crouch to prone", &"crouch_to_prone", &"aim_rifle", 0.0, 0, 0.0],
	["get up", &"prone_to_stand", &"aim_rifle", 0.0, 0, 0.0],
	["prone roll", &"prone_roll_l", &"aim_rifle", 0.0, 0, 0.0],
	["death", &"death", &"aim_pistol", 0.0, 1, 0.0],
	["switch gun", &"idle", &"switch", 1.0, 0, 0.0],
	["knife", &"idle", &"slash_light", 1.0, 0, 0.0],
	["knife (crouched)", &"crouch_idle", &"slash_light", 1.0, 0, 0.0],
	["axe", &"idle", &"slash_heavy", 1.0, 0, 0.0],
	["stroll (base)", &"stroll", &"aim_rifle", 0.0, -1, 1.4],
	["sleep", &"sleep", &"aim_rifle", 0.0, -1, 0.0],
	["sit", &"sit", &"aim_rifle", 0.0, -1, 0.0],
	["read", &"read", &"aim_rifle", 0.0, -1, 0.0],
	["chat", &"chat", &"aim_rifle", 0.0, -1, 0.0],
	["work (kneel)", &"work_kneel", &"aim_rifle", 0.0, -1, 0.0],
	["work (stand)", &"work_stand", &"aim_rifle", 0.0, -1, 0.0],
	["exercise", &"exercise", &"aim_rifle", 0.0, -1, 0.0],
	["watch", &"watch", &"aim_rifle", 0.0, -1, 0.0],
]
const MELEE: Dictionary[StringName, MeleeConfig] = {
	&"slash_light": preload("res://data/weapons/knife.tres"), &"slash_heavy": preload("res://data/weapons/axe.tres"),
}

var _bodies: Array[SurvivorView] = []
var _replay_left: float = REPLAY_SEC


func _ready() -> void:
	var guns: Array[Gun] = []
	for s: WeaponSlot in LOADOUT.slots:
		guns.append(Gun.new(s.weapon, s.attachments))
	var rows: int = ceili(float(POSES.size()) / PER_ROW)
	for i: int in POSES.size():
		var p: Array = POSES[i]
		var body: SurvivorView = SurvivorView.new()
		body.position = Vector3((i % PER_ROW - (PER_ROW - 1) * 0.5) * SPACING, 0.0, (i / PER_ROW - (rows - 1) * 0.5) * SPACING * 1.4)
		add_child(body)
		body.set_gun(guns[p[4]] if p[4] >= 0 else null)  # -1: daily life, empty hands
		var speed: float = p[5]
		body.animate(p[1], 1.0 if speed <= 0.0 else speed / SurvivorView.CLIP_SPEED.get(p[1], speed), p[2], 1.0, p[3])
		_bodies.append(body)
		if MELEE.has(p[2]):
			body.swing(MELEE[p[2]])
		var label: Label3D = Label3D.new()
		label.text = p[0]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 40
		label.outline_size = 10
		label.position = body.position + Vector3(0.0, 1.95, 0.0)
		add_child(label)


func _process(delta: float) -> void:
	_replay_left -= delta
	if _replay_left <= 0.0:
		_replay_left = REPLAY_SEC
		for i: int in _bodies.size():
			var low: String = POSES[i][1]
			var up: String = POSES[i][2]
			if MELEE.has(POSES[i][2]):
				_bodies[i].swing(MELEE[POSES[i][2]])
			elif not low in SurvivorView.LOOP_CLIPS and not SurvivorView.WALK_SETS.has(low) 					or not up in SurvivorView.LOOP_CLIPS:
				_bodies[i].replay()
