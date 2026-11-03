class_name LeftHandIK
extends SkeletonModifier3D
## Puts the survivor's left hand on the gun (PHASE1 1.5+ A2, J: "แขนซ้ายไม่จับปืนเลย"): a two-bone IK on
## arm_l / fore_l after the clips, aimed at the gun's support point (handguard, pump, or a pistol's grip). The
## gun rides hand_r, so the target is read from hand_r's pose this frame and never lags. `influence` fades it
## out for clips that need the left hand elsewhere (reloads, roll, downed); SurvivorView drives it.

const PALM_M: float = 0.05  ## wrist to palm: the IK puts the wrist this far short of the support point
const POLE: Vector3 = Vector3(1.0, -1.0, -0.3)  ## the elbow points out to the left and down (skeleton space)

var support_in_hand: Vector3 = Vector3.ZERO  ## the support point in hand_r's bone space (set by SurvivorView)
var _arm: int = -1
var _fore: int = -1
var _hand_l: int = -1
var _hand_r: int = -1
var _upper_len: float = 0.29
var _fore_len: float = 0.27


func _ready() -> void:
	var sk: Skeleton3D = get_skeleton()
	_arm = sk.find_bone("arm_l")
	_fore = sk.find_bone("fore_l")
	_hand_l = sk.find_bone("hand_l")
	_hand_r = sk.find_bone("hand_r")
	_upper_len = sk.get_bone_rest(_fore).origin.length()
	_fore_len = sk.get_bone_rest(_hand_l).origin.length()


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or _arm < 0 or support_in_hand == Vector3.ZERO:
		return
	var target: Vector3 = sk.get_bone_global_pose(_hand_r) * support_in_hand
	var shoulder: Vector3 = sk.get_bone_global_pose(_arm).origin
	var to_target: Vector3 = target - shoulder
	target -= to_target.normalized() * PALM_M
	to_target = target - shoulder
	var reach: float = clampf(to_target.length(), 0.01, _upper_len + _fore_len - 0.001)
	var dir: Vector3 = to_target.normalized()
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
