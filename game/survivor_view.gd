class_name SurvivorView
extends Node3D
## A survivor's body on screen (PHASE1 1.5+ A2): the skinned model from tools/blender/kit_survivor.py, two clip
## layers and the gun in the right hand. The lower layer (legs, or the whole body for roll / prone / downed)
## and the upper layer (spine, head and arms: aim, reload, sprint carry) blend through a bone filter, so the
## legs walk while the arms keep aiming. Walking sideways turns the hips to the travel and twists the torso back
## to the aim (HipTwist); walking away from the aim plays the backward walk; a sprint or a roll turns the whole
## body to where it goes. The left hand is IK: on the gun, or
## walked through a reload (REACH) while the mag leaves the gun, drops and a new one comes in. Faces +Z: put it
## under the fighter's aim marker.

const MODEL: PackedScene = preload("res://assets/models/survivor.glb")
const SURFACE_MATERIAL: Material = preload("res://game/level/style15_surface.tres")
const SKELETON_PATH: String = "survivor_rig/Skeleton3D"
const UPPER_BONES: PackedStringArray = ["torso", "head", "arm_l", "fore_l", "hand_l", "arm_r", "fore_r", "hand_r"]
const LOWER_CLIPS: PackedStringArray = ["idle", "walk", "run", "crouch_idle", "crouch_walk", "prone_idle", "crawl",
	"roll", "downed"]  ## states; "walk" and "crouch_walk" are WALK_SETS
const UPPER_CLIPS: PackedStringArray = ["aim_pistol", "aim_rifle", "carry_high", "carry_port", "reload_pistol",
	"reload_rifle", "reload_shell"]
## A walking state's backward and forward clips (blend positions -1 and +1).
const WALK_SETS: Dictionary[String, Array] = {  # Array, not PackedStringArray: a typed const dict of those reads back empty strings in 4.7
	"walk": ["walk_b", "walk_f"],
	"crouch_walk": ["crouch_b", "crouch_f"],
}
const MAX_TWIST: float = 1.75  ## rad the hips turn from the aim at most (≈ 100°)
const BACK_FROM: float = deg_to_rad(115.0)  ## travel this far off the aim switches to the backward walk...
const FORWARD_FROM: float = deg_to_rad(85.0)  ## ...and back under this (no flicker in between)
const TWIST_RATE: float = 10.0  ## 1/s the hips follow the travel
const LOOP_CLIPS: PackedStringArray = ["idle", "walk_f", "walk_b", "run", "crouch_idle", "crouch_f", "crouch_b",
	"prone_idle", "crawl", "downed", "aim_pistol", "aim_rifle", "carry_high", "carry_port", "reload_shell"]
const FULL_BODY: PackedStringArray = ["roll", "prone_idle", "crawl", "downed"]  ## the arms follow the legs' clip
## m/s each moving clip's stride matches at 1× (kit_survivor.py); faster or slower movement scales the clip
const CLIP_SPEED: Dictionary[StringName, float] = {&"walk": 4.5, &"run": 6.0, &"crouch_walk": 1.7, &"crawl": 0.85}
const MOVING_SPEED: float = 0.25  ## m/s: slower than this stands still
const XFADE_SEC: float = 0.15
const GRIP_BLEND: float = 12.0  ## 1/s: how fast the gun turns to a new clip's hold
const TURN_RATE: float = 12.0  ## 1/s: the body turns toward a sprint or roll this fast, and back to the aim
const IK_FADE: float = 6.0  ## 1/s: the left hand leaves / returns to the gun this fast
const LEFT_HAND_BUSY: PackedStringArray = ["roll", "downed"]
## Where the gun points in each clip that sets its own hold, in the body's space (+Z ahead, +Y up, +X left).
## Other clips keep the aim hold and the gun simply follows the hand (reloads).
const HOLD_DIR: Dictionary[StringName, Vector3] = {
	&"aim_pistol": Vector3(0.0, 0.0, 1.0), &"aim_rifle": Vector3(0.0, 0.0, 1.0),
	&"carry_high": Vector3(0.0, 1.0, 0.15),  # high ready: muzzle to the sky (J 2026-11-03)
	&"carry_port": Vector3(0.6, 0.7, 0.35),  # port arms: across the chest, muzzle over the left shoulder
	&"prone_idle": Vector3(0.0, 0.0, 1.0),  # prone: level along the ground (crawl uses it too)
}
const PRONE_CLIPS: PackedStringArray = ["prone_idle", "crawl"]
## The left hand through a reload (J: make reloads read clearly): [phase, point] keys, eased between. Points are
## on the gun (support, mag, mag_low, handle, handle_back, port, port_low) or on the torso (pouch, belt).
const REACH: Dictionary[StringName, Array] = {
	&"reload_rifle": [[0.0, &"support"], [0.12, &"mag"], [0.22, &"mag_low"], [0.36, &"pouch"], [0.55, &"mag_low"],
		[0.66, &"mag"], [0.76, &"handle"], [0.84, &"handle_back"], [1.0, &"support"]],
	&"reload_pistol": [[0.0, &"support"], [0.12, &"mag"], [0.2, &"mag_low"], [0.38, &"belt"], [0.56, &"mag_low"],
		[0.66, &"mag"], [0.78, &"handle"], [0.88, &"handle_back"], [1.0, &"support"]],
	&"reload_shell": [[0.0, &"belt"], [0.45, &"port_low"], [0.6, &"port"], [1.0, &"belt"]],
}
## Mag swap in a reload's phase: [grab the old mag, drop it, take a new one, seat it]. A shell: [-, -, take, seat].
const SWAP: Dictionary[StringName, Array] = {
	&"reload_rifle": [0.13, 0.24, 0.38, 0.66], &"reload_pistol": [0.13, 0.22, 0.4, 0.66],
	&"reload_shell": [-1.0, -1.0, 0.03, 0.62],
}
const TORSO_POINTS: Dictionary[StringName, Vector3] = {
	&"pouch": Vector3(0.12, 0.15, 0.17),  # vest front, left (torso bone space)
	&"belt": Vector3(0.2, -0.05, 0.08),   # left hip
}
const DROPPED_MAX: int = 6  ## dropped mags kept on the floor at once
const DROPPED_SEC: float = 6.0

enum Stance { STAND, CROUCH, PRONE }

## Set by the fighter each frame before drive() (stances, sprint and roll come with 1.5+ A3).
var stance: Stance = Stance.STAND
var sprinting: bool = false
var rolling: bool = false

var gun_view: GunView
var skeleton: Skeleton3D
var look: int = 0  ## which of survivor.glb's outfits shows (set_look); one per fighter, so no two alike
var lower: StringName = &""
var upper: StringName = &""
var hand_item: Node3D  ## the mag or shell in the left hand during a reload (null when nothing)
var _model: Node3D
var _anims: AnimationPlayer
var _tree: AnimationTree
var _mount: Node3D
var _hand_l_mount: Node3D
var _grip: Dictionary[StringName, Transform3D] = {}  ## HOLD_DIR clip → hand-to-gun transform
var _hold: StringName = &"aim_rifle"  ## the aim clip of the gun in hand
var _grip_target: Transform3D = Transform3D.IDENTITY
var _ik: LeftHandIK
var _hip: HipTwist
var _shoulder: RightArmAim
var _twist_target: float = 0.0
var _backwards: bool = false
var _walk_dir: float = 1.0  ## smoothed blend position of the walk sets: +1 forward, -1 backward
var _gun: Gun
var _model_gun: GunModel
var _target_yaw: float = 0.0
var _reload_phase: float = -1.0  ## last frame's phase of the reload clip, < 0 = none
var _dropped: Array[Node3D] = []


func _ready() -> void:
	_model = MODEL.instantiate() as Node3D
	add_child(_model)
	Style15Level.apply_materials(_model, SURFACE_MATERIAL)
	skeleton = _model.get_node(SKELETON_PATH) as Skeleton3D
	set_look(look)
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
	var hand_l: BoneAttachment3D = BoneAttachment3D.new()
	hand_l.bone_name = "hand_l"
	skeleton.add_child(hand_l)
	_hand_l_mount = Node3D.new()
	_hand_l_mount.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0.0, -0.06, 0.0))  # mag top to the fingers
	hand_l.add_child(_hand_l_mount)
	_hip = HipTwist.new()  # modifiers run in child order: hips, then the right arm, then the left hand
	skeleton.add_child(_hip)
	_shoulder = RightArmAim.new()
	_shoulder.influence = 0.0
	skeleton.add_child(_shoulder)
	_ik = LeftHandIK.new()
	_ik.influence = 0.0
	skeleton.add_child(_ik)
	_build_tree()
	animate(&"idle", 1.0, &"aim_rifle", 1.0, 1.0)


## Shows outfit `i` (survivor_<i> in the glb) and hides the others; out-of-range wraps around.
func set_look(i: int) -> void:
	look = i
	if skeleton == null:
		return
	var bodies: Array[MeshInstance3D] = []
	for n: Node in skeleton.get_children():
		if n is MeshInstance3D and String(n.name).begins_with("survivor_"):
			bodies.append(n as MeshInstance3D)
	bodies.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool: return String(a.name) < String(b.name))
	for k: int in bodies.size():
		bodies[k].visible = k == posmod(i, bodies.size())


func look_count() -> int:
	var n: int = 0
	for c: Node in skeleton.get_children():
		if c is MeshInstance3D and String(c.name).begins_with("survivor_"):
			n += 1
	return n


## The gun in hand; pistols and SMGs are held like a pistol, the rest like a rifle.
func set_gun(gun: Gun) -> void:
	gun_view.show_gun(gun)
	_gun = gun
	_model_gun = gun.config.model if gun != null else null
	_hold = _aim_clip(gun)
	_grip_target = _grip[_hold]
	_mount.transform = _grip_target
	_end_reload()
	if hand_item != null:
		hand_item.queue_free()
		hand_item = null
	var scene: PackedScene = gun_view.hand_item_scene()
	if scene != null:
		hand_item = scene.instantiate() as Node3D
		hand_item.visible = false
		_hand_l_mount.add_child(hand_item)
		Style15Level.apply_materials(hand_item, SURFACE_MATERIAL)


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
	_twist_target = 0.0
	if WALK_SETS.has(String(low)) and facing != Vector2.ZERO:
		var off: float = wrapf(atan2(velocity.x, velocity.y) - atan2(facing.x, facing.y), -PI, PI)  # travel vs aim
		_backwards = absf(off) > (FORWARD_FROM if _backwards else BACK_FROM)
		var legs: float = wrapf(off - PI, -PI, PI) if _backwards else off  # the hips face the travel, or away
		_twist_target = clampf(legs, -MAX_TWIST, MAX_TWIST)
	# A sprint or a roll faces where it goes; everything else faces the aim.
	_target_yaw = 0.0
	if (rolling or (sprinting and low == &"run")) and moving and facing != Vector2.ZERO:
		_target_yaw = wrapf(atan2(velocity.x, velocity.y) - atan2(facing.x, facing.y), -PI, PI)
	var up: StringName = _aim_clip(gun) if gun != null else &"aim_rifle"
	var up_speed: float = 1.0
	if gun != null and gun.is_reloading() and not gun.jammed:
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
	# The hold follows the clip that moves the arms: the legs' clip when it is a whole-body one.
	var arms: StringName = up if up_weight > 0.0 else &"prone_idle" if String(low) in PRONE_CLIPS else up
	_grip_target = _grip[arms] if _grip.has(arms) else _grip[_hold]
	_tree.set(&"parameters/lower_speed/scale", low_speed)
	_tree.set(&"parameters/upper_speed/scale", up_speed)
	_tree.set(&"parameters/layer/blend_amount", up_weight)


func _process(delta: float) -> void:
	_mount.transform = _mount.transform.interpolate_with(_grip_target, clampf(delta * GRIP_BLEND, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(delta * TURN_RATE, 0.0, 1.0))
	_hip.twist = lerp_angle(_hip.twist, _twist_target, clampf(delta * TWIST_RATE, 0.0, 1.0))
	_walk_dir = move_toward(_walk_dir, -1.0 if _backwards else 1.0, delta * 6.0)
	for walk_state: String in WALK_SETS:
		_tree.set("parameters/lower_%s/blend_position" % walk_state, _walk_dir)
	_ik.gun_in_hand = _mount.transform
	_shoulder.gun_in_hand = _mount.transform
	_shoulder.stock = _model_gun.hand_points.get("stock", Vector3.ZERO) if _model_gun != null else Vector3.ZERO
	var shouldered: bool = upper == &"aim_rifle" and not String(lower) in FULL_BODY
	_shoulder.influence = move_toward(_shoulder.influence, 1.0 if shouldered else 0.0, delta * IK_FADE * 1.5)
	_ik.enabled = _model_gun != null
	var busy: bool = String(lower) in LEFT_HAND_BUSY
	_ik.influence = move_toward(_ik.influence, 0.0 if busy else 1.0, delta * IK_FADE)
	if REACH.has(upper) and _gun != null and _gun.is_reloading():
		_step_reload(1.0 - _gun.reload_left / maxf(_gun.reload_sec, 0.001))
	else:
		_end_reload()
		var at: Array = _point(&"support")
		_ik.hold(at[0], at[1])


## Plays the current upper clip from the start again (the pose gallery repeats one-shots).
func replay() -> void:
	_tree.set(&"parameters/upper/transition_request", String(upper))
	_tree.set(&"parameters/lower/transition_request", String(lower))


## Moves the left hand along REACH and swaps the mag at the SWAP phases.
func _step_reload(phase: float) -> void:
	var keys: Array = REACH[upper]
	for i: int in keys.size() - 1:
		if phase <= keys[i + 1][0] or i == keys.size() - 2:
			var a: Array = _point(keys[i][1])
			var b: Array = _point(keys[i + 1][1])
			_ik.from_space = a[0]
			_ik.from_point = a[1]
			_ik.to_space = b[0]
			_ik.to_point = b[1]
			_ik.blend = clampf((phase - keys[i][0]) / maxf(keys[i + 1][0] - keys[i][0], 0.001), 0.0, 1.0)
			break
	var swap: Array = SWAP[upper]
	var out: bool = swap[0] >= 0.0 and phase >= swap[0] and phase < swap[3]
	gun_view.set_mag_visible(not out)
	if hand_item != null:
		hand_item.visible = (phase >= swap[0] and phase < swap[1]) or (phase >= swap[2] and phase < swap[3])
		if swap[1] >= 0.0 and _reload_phase < swap[1] and phase >= swap[1]:
			_drop(hand_item)
	_reload_phase = phase


func _end_reload() -> void:
	_reload_phase = -1.0
	gun_view.set_mag_visible(true)
	if hand_item != null:
		hand_item.visible = false


## A copy of the empty mag falls from the left hand to the floor and stays a while.
func _drop(item: Node3D) -> void:
	var scene: PackedScene = gun_view.hand_item_scene()
	if scene == null or not is_inside_tree():
		return
	var mag: Node3D = scene.instantiate() as Node3D
	mag.top_level = true
	add_child(mag)
	Style15Level.apply_materials(mag, SURFACE_MATERIAL)
	mag.global_transform = item.global_transform
	var floor_y: float = global_position.y + 0.02
	var t: Tween = mag.create_tween().set_parallel()
	t.tween_property(mag, "global_position:y", floor_y, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(mag, "global_rotation", Vector3(PI / 2, randf() * TAU, 0.0), 0.35)
	t.chain().tween_interval(DROPPED_SEC)
	t.chain().tween_callback(mag.queue_free)
	_dropped.append(mag)
	while _dropped.size() > DROPPED_MAX:
		var old: Node3D = _dropped.pop_front()
		if is_instance_valid(old):
			old.queue_free()


## A REACH point as [LeftHandIK.Space, position]: on the gun (its own space) or on the torso. Points a gun lacks
## fall back to its support point.
func _point(name: StringName) -> Array:
	if TORSO_POINTS.has(name):
		return [LeftHandIK.Space.TORSO, TORSO_POINTS[name]]
	var m: GunModel = _model_gun
	if m == null:
		return [LeftHandIK.Space.GUN, Vector3.ZERO]
	var down: Vector3 = Vector3.DOWN
	match name:
		&"mag", &"mag_low":
			if m.mounts.has("mag"):
				return [LeftHandIK.Space.GUN, m.mounts["mag"] + down * (0.1 if name == &"mag" else 0.3)]
		&"handle", &"handle_back":
			if m.hand_points.has("handle"):
				return [LeftHandIK.Space.GUN, m.hand_points["handle"] + Vector3.BACK * (0.0 if name == &"handle" else -0.1)]
		&"port", &"port_low":
			if m.hand_points.has("port"):
				return [LeftHandIK.Space.GUN, m.hand_points["port"] + down * (0.02 if name == &"port" else 0.15)]
	return [LeftHandIK.Space.GUN, m.support]


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
			var node: AnimationRootNode
			if WALK_SETS.has(clips[i]):
				var space: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
				space.sync = true  # backward and forward stay in step while they cross-fade
				var names: Array = WALK_SETS[clips[i]]
				for k: int in names.size():
					var clip: AnimationNodeAnimation = AnimationNodeAnimation.new()
					clip.animation = names[k]
					space.add_blend_point(clip, -1.0 if k == 0 else 1.0, -1, StringName(names[k]))
				node = space
			else:
				var a: AnimationNodeAnimation = AnimationNodeAnimation.new()
				a.animation = clips[i]
				node = a
			bt.add_node(name + "_" + clips[i], node)
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
