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
	goal -= (goal - shoulder).normalized() * PALM_M
	var to_goal: Vector3 = goal - shoulder
	var reach: float = clampf(to_goal.length(), 0.01, _upper_len + _fore_len - 0.001)
	var dir: Vector3 = to_goal.normalized()
	var bend: Vector3 = (POLE - dir * POLE.dot(dir)).normalized()
	var cos_a: float = clampf((_upper_len * _upper_len + reach * reach - _fore_len * _fore_len) / (2.0 * _upper_len * reach),
		-1.0, 1.0)
	var elbow: Vector3 = shoulder + dir * cos_a * _upper_len + bend * sqrt(1.0 - cos_a * cos_a) * _upper_len
	_point_bone(sk, _arm, elbow)
	_point_bone(sk, _fore, shoulder + dir * reach)


## Turns bone `b` (its limb hangs along -Y) the shortest way so it points at `to`.
func _point_bone(sk: Skeleton3D, b: int, to: Vector3) -> void:
	var g: Transform3D = sk.get_bone_global_pose(b)
	var now: Vector3 = (g.basis * Vector3.DOWN).normalized()
	var want: Vector3 = (to - g.origin).normalized()
	if now.dot(want) > 0.99999:
		return
	var turned: Basis = Basis(Quaternion(now, want)) * g.basis.orthonormalized()
	var parent: Basis = sk.get_bone_global_pose(sk.get_bone_parent(b)).basis.orthonormalized()
	sk.set_bone_pose_rotation(b, (parent.inverse() * turned).get_rotation_quaternion())
