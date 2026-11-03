class_name RightArmAim
extends SkeletonModifier3D
## Shoulders a long gun when aiming (J 2026-11-03: "พานท้ายปืนยาวควรอยู่ระดับหัวไหล่"): places the gun level along
## the aim with its butt plate (GunModel "stock") in the right shoulder pocket, then IKs the right arm so the hand
## holds the grip there and turns the wrist to match. Runs after HipTwist and before LeftHandIK, which then finds
## the handguard where the gun now is. `influence` fades it in and out (SurvivorView: rifle aim only).

const POCKET: Vector3 = Vector3(-0.13, 0.42, 0.1)  ## the right shoulder pocket, torso bone space (+Z ahead)
const POLE: Vector3 = Vector3(-1.0, -1.0, -0.2)  ## the right elbow points out to the right and down

var gun_in_hand: Transform3D = Transform3D.IDENTITY  ## hand_r → gun (SurvivorView's grip for the rifle aim)
var stock: Vector3 = Vector3.ZERO  ## the gun's butt plate in its own space; zero = no stock, does nothing
var _arm: int = -1
var _fore: int = -1
var _hand: int = -1
var _torso: int = -1
var _upper_len: float = 0.29
var _fore_len: float = 0.27


func _ready() -> void:
	var sk: Skeleton3D = get_skeleton()
	_arm = sk.find_bone("arm_r")
	_fore = sk.find_bone("fore_r")
	_hand = sk.find_bone("hand_r")
	_torso = sk.find_bone("torso")
	_upper_len = sk.get_bone_rest(_fore).origin.length()
	_fore_len = sk.get_bone_rest(_hand).origin.length()


## Where the gun goes, in skeleton space: level, along +Z (the aim), the stock in the pocket.
func gun_pose(sk: Skeleton3D) -> Transform3D:
	var pocket: Vector3 = sk.get_bone_global_pose(_torso) * POCKET
	return Transform3D(Basis.IDENTITY, pocket - stock)


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or _arm < 0 or stock == Vector3.ZERO:
		return
	var hand: Transform3D = gun_pose(sk) * gun_in_hand.affine_inverse()
	ArmIK.solve(sk, _arm, _fore, _upper_len, _fore_len, hand.origin, POLE)
	ArmIK.set_global_rotation(sk, _hand, hand.basis)
