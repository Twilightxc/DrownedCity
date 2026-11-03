class_name LeftHandIK
extends SkeletonModifier3D
## The survivor's left hand (PHASE1 1.5+ A2): a two-bone IK on arm_l / fore_l after the clips. Its target is a
## blend between two points, each on the gun (support, mag well, charging handle, loading port) or on the torso
## (vest pouch, belt), so SurvivorView can walk the hand through a reload. Gun points are read through hand_r's
## pose this frame and never lag the gun. `influence` fades it out for the roll and downed.

enum Space { GUN, TORSO }

const PALM_M: float = 0.05  ## wrist to palm: the IK puts the wrist this far short of the target
const POLE: Vector3 = Vector3(1.0, -1.0, -0.3)  ## the elbow points out to the left and down (skeleton space)

var gun_in_hand: Transform3D = Transform3D.IDENTITY  ## hand_r → gun (the mount; set by SurvivorView)
var from_space: Space = Space.GUN
var from_point: Vector3 = Vector3.ZERO
var to_space: Space = Space.GUN
var to_point: Vector3 = Vector3.ZERO
var blend: float = 1.0  ## 0 = from, 1 = to
var enabled: bool = false  ## false: no target (a gun without a model)
var _arm: int = -1
var _fore: int = -1
var _hand_l: int = -1
var _hand_r: int = -1
var _torso: int = -1
var _upper_len: float = 0.29
var _fore_len: float = 0.27


func _ready() -> void:
	var sk: Skeleton3D = get_skeleton()
	_arm = sk.find_bone("arm_l")
	_fore = sk.find_bone("fore_l")
	_hand_l = sk.find_bone("hand_l")
	_hand_r = sk.find_bone("hand_r")
	_torso = sk.find_bone("torso")
	_upper_len = sk.get_bone_rest(_fore).origin.length()
	_fore_len = sk.get_bone_rest(_hand_l).origin.length()


## Holds the hand at one point.
func hold(space: Space, p: Vector3) -> void:
	from_space = space
	from_point = p
	to_space = space
	to_point = p
	blend = 1.0


## The target this frame in skeleton space (tests read it too).
func target(sk: Skeleton3D) -> Vector3:
	var a: Vector3 = _resolve(sk, from_space, from_point)
	var b: Vector3 = _resolve(sk, to_space, to_point)
	return a.lerp(b, smoothstep(0.0, 1.0, blend))


func _resolve(sk: Skeleton3D, space: Space, p: Vector3) -> Vector3:
	if space == Space.GUN:
		return sk.get_bone_global_pose(_hand_r) * gun_in_hand * p
	return sk.get_bone_global_pose(_torso) * p


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or _arm < 0 or not enabled:
		return
	var goal: Vector3 = target(sk)
	var shoulder: Vector3 = sk.get_bone_global_pose(_arm).origin
	ArmIK.solve(sk, _arm, _fore, _upper_len, _fore_len, goal - (goal - shoulder).normalized() * PALM_M, POLE)
