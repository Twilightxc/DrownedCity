class_name SurvivorView
extends Node3D
## A survivor's body on screen (PHASE1 1.5+ A2): the skinned model from tools/blender/kit_survivor.py, two clip
## layers and the gun in the right hand. The lower layer (legs, or the whole body for roll / prone / downed)
## and the upper layer (spine, head and arms: aim, reload, sprint carry) blend through a bone filter, so the
## legs walk while the arms keep aiming. Faces +Z: put it under the fighter's aim marker.

const MODEL: PackedScene = preload("res://assets/models/survivor.glb")
const SURFACE_MATERIAL: Material = preload("res://game/level/style15_surface.tres")
const SKELETON_PATH: String = "survivor_rig/Skeleton3D"
const UPPER_BONES: PackedStringArray = ["torso", "head", "arm_l", "fore_l", "hand_l", "arm_r", "fore_r", "hand_r"]
const LOWER_CLIPS: PackedStringArray = ["idle", "walk", "run", "crouch_idle", "crouch_walk", "prone_idle", "crawl",
	"roll", "downed"]
const UPPER_CLIPS: PackedStringArray = ["aim_pistol", "aim_rifle", "carry_high", "carry_port", "reload_pistol",
	"reload_rifle", "reload_shell"]
const LOOP_CLIPS: PackedStringArray = ["idle", "walk", "run", "crouch_idle", "crouch_walk", "prone_idle", "crawl",
	"downed", "aim_pistol", "aim_rifle", "carry_high", "carry_port", "reload_shell"]
const FULL_BODY: PackedStringArray = ["roll", "prone_idle", "crawl", "downed"]  ## the arms follow the legs' clip
## m/s each moving clip's stride matches at 1× (kit_survivor.py); faster or slower movement scales the clip
const CLIP_SPEED: Dictionary[StringName, float] = {&"walk": 1.4, &"run": 4.2, &"crouch_walk": 0.9, &"crawl": 0.6}
const MOVING_SPEED: float = 0.25  ## m/s: slower than this stands still
const XFADE_SEC: float = 0.15
const GRIP_BLEND: float = 12.0  ## 1/s: how fast the gun turns to a new clip's hold
## Where the gun points in each clip that sets its own hold, in the body's space (+Z ahead, +Y up, +X left).
## Other clips keep the aim hold and the gun simply follows the hand (reloads).
const HOLD_DIR: Dictionary[StringName, Vector3] = {
	&"aim_pistol": Vector3(0.0, 0.0, 1.0), &"aim_rifle": Vector3(0.0, 0.0, 1.0),
	&"carry_high": Vector3(0.0, 1.0, 0.15),  # high ready: muzzle to the sky (J 2026-11-03)
	&"carry_port": Vector3(0.6, 0.7, 0.35),  # port arms: across the chest, muzzle over the left shoulder
}

enum Stance { STAND, CROUCH, PRONE }

## Set by the fighter each frame before drive() (stances, sprint and roll come with 1.5+ A3).
var stance: Stance = Stance.STAND
var sprinting: bool = false
var rolling: bool = false

var gun_view: GunView
var skeleton: Skeleton3D
var lower: StringName = &""
var upper: StringName = &""
var _model: Node3D
var _anims: AnimationPlayer
var _tree: AnimationTree
var _mount: Node3D
var _grip: Dictionary[StringName, Transform3D] = {}  ## HOLD_DIR clip → hand-to-gun transform
var _hold: StringName = &"aim_rifle"  ## the aim clip of the gun in hand
var _grip_target: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	_model = MODEL.instantiate() as Node3D
	add_child(_model)
	Style15Level.apply_materials(_model, SURFACE_MATERIAL)
	skeleton = _model.get_node(SKELETON_PATH) as Skeleton3D
	_anims = _model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip: String in LOOP_CLIPS:
		if _anims.has_animation(clip):
			_anims.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_measure_grips()
	var hand: BoneAttachment3D = BoneAttachment3D.new()
	hand.bone_name = "hand_r"
	skeleton.add_child(hand)
	_mount = Node3D.new()
	hand.add_child(_mount)
	gun_view = GunView.new()
	_mount.add_child(gun_view)
	_build_tree()
	animate(&"idle", 1.0, &"aim_rifle", 1.0, 1.0)


## The gun in hand; pistols and SMGs are held like a pistol, the rest like a rifle.
func set_gun(gun: Gun) -> void:
	gun_view.show_gun(gun)
	_hold = _aim_clip(gun)
	_grip_target = _grip[_hold]
	_mount.transform = _grip_target


## Picks both layers from what the fighter is doing. `velocity` and `facing` are on the ground plane (m/s, unit).
func drive(velocity: Vector2, facing: Vector2, gun: Gun, is_downed: bool) -> void:
	var speed: float = velocity.length()
	var moving: bool = speed > MOVING_SPEED
	var low: StringName = &"idle"
	if is_downed:
		low = &"downed"
	elif rolling:
		low = &"roll"
	elif stance == Stance.PRONE:
		low = &"crawl" if moving else &"prone_idle"
	elif stance == Stance.CROUCH:
		low = &"crouch_walk" if moving else &"crouch_idle"
	elif moving:
		low = &"run" if sprinting else &"walk"
	var low_speed: float = 1.0
	if CLIP_SPEED.has(low):
		low_speed = speed / CLIP_SPEED[low]
		if facing != Vector2.ZERO and velocity.dot(facing) < -0.2 * speed:
			low_speed = -low_speed  # backing away while aiming: the legs step backwards
	var up: StringName = _aim_clip(gun) if gun != null else &"aim_rifle"
	var up_speed: float = 1.0
	if gun != null and gun.is_reloading():
		up = &"reload_pistol" if up == &"aim_pistol" else &"reload_shell" if gun.config.reload_per_round else &"reload_rifle"
		up_speed = _anims.get_animation(up).length / maxf(gun.reload_sec, 0.05)
	elif sprinting and low == &"run":
		up = &"carry_high" if up == &"aim_pistol" else &"carry_port"
	animate(low, low_speed, up, up_speed, 0.0 if String(low) in FULL_BODY else 1.0)


## Plays `low` on the legs and `up` on the arms (weight 0 = the legs' clip moves the arms too).
## A clip only restarts when it changes.
func animate(low: StringName, low_speed: float, up: StringName, up_speed: float, up_weight: float) -> void:
	if low != lower:
		lower = low
		_tree.set(&"parameters/lower/transition_request", String(low))
	if up != upper:
		upper = up
		_tree.set(&"parameters/upper/transition_request", String(up))
		_grip_target = _grip[up] if _grip.has(up) else _grip[_hold]
	_tree.set(&"parameters/lower_speed/scale", low_speed)
	_tree.set(&"parameters/upper_speed/scale", up_speed)
	_tree.set(&"parameters/layer/blend_amount", up_weight)


func _process(delta: float) -> void:
	_mount.transform = _mount.transform.interpolate_with(_grip_target, clampf(delta * GRIP_BLEND, 0.0, 1.0))


## Plays the current upper clip from the start again (the pose gallery repeats one-shots).
func replay() -> void:
	_tree.set(&"parameters/upper/transition_request", String(upper))
	_tree.set(&"parameters/lower/transition_request", String(lower))


func _aim_clip(gun: Gun) -> StringName:
	var cls: String = gun.config.weapon_class if gun != null else "ar"
	return &"aim_pistol" if cls == "pistol" or cls == "smg" else &"aim_rifle"


## For each HOLD_DIR clip, the transform from the right hand to the gun pointing that way with its grip in the
## palm, measured on the clip's first frame.
func _measure_grips() -> void:
	var hand: int = skeleton.find_bone("hand_r")
	for clip: StringName in HOLD_DIR:
		_anims.play(clip)
		_anims.seek(0.0, true)
		var pose: Transform3D = skeleton.get_bone_global_pose(hand)
		var palm: Vector3 = pose * Vector3(0.0, -0.05, 0.0)
		var z: Vector3 = HOLD_DIR[clip].normalized()
		var ref: Vector3 = Vector3.FORWARD if absf(z.y) > 0.9 else Vector3.UP  # the gun's top: up, or toward the face (-Z)
		var y: Vector3 = (ref - z * ref.dot(z)).normalized()
		_grip[clip] = pose.affine_inverse() * Transform3D(Basis(y.cross(z), y, z), palm)
	_anims.stop()
	skeleton.reset_bone_poses()


func _build_tree() -> void:
	var bt: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var layers: Array = [["lower", LOWER_CLIPS], ["upper", UPPER_CLIPS]]
	for layer: Array in layers:
		var name: String = layer[0]
		var clips: PackedStringArray = layer[1]
		var pick: AnimationNodeTransition = AnimationNodeTransition.new()
		pick.xfade_time = XFADE_SEC
		pick.allow_transition_to_self = true  # replay(); animate() only requests changes
		pick.input_count = clips.size()
		bt.add_node(name, pick)
		for i: int in clips.size():
			pick.set_input_name(i, clips[i])
			var a: AnimationNodeAnimation = AnimationNodeAnimation.new()
			a.animation = clips[i]
			bt.add_node(name + "_" + clips[i], a)
			bt.connect_node(name, i, name + "_" + clips[i])
		bt.add_node(name + "_speed", AnimationNodeTimeScale.new())
		bt.connect_node(name + "_speed", 0, name)
	var blend: AnimationNodeBlend2 = AnimationNodeBlend2.new()
	blend.filter_enabled = true
	for bone: String in UPPER_BONES:
		blend.set_filter_path(NodePath(SKELETON_PATH + ":" + bone), true)
	bt.add_node("layer", blend)
	bt.connect_node("layer", 0, "lower_speed")
	bt.connect_node("layer", 1, "upper_speed")
	bt.connect_node("output", 0, "layer")
	_tree = AnimationTree.new()
	_model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_anims)
	_tree.tree_root = bt
	_tree.active = true
