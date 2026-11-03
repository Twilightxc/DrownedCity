class_name HipTwist
extends SkeletonModifier3D
## Turns the survivor's hips toward where it walks while the torso keeps aiming (PHASE1 1.5+ A2, J: the side-step
## clips looked like an air dancer). Runs after the clips and before the left-hand IK: the pelvis yaws by `twist`
## about the skeleton's up axis and the torso is given back its world rotation, so the arms, the gun and the IK
## targets don't move. SurvivorView sets `twist` each frame.

var twist: float = 0.0  ## radians, + turns the hips toward +X (left of the aim)
var _pelvis: int = -1
var _torso: int = -1


func _ready() -> void:
	var sk: Skeleton3D = get_skeleton()
	_pelvis = sk.find_bone("pelvis")
	_torso = sk.find_bone("torso")


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or _pelvis < 0 or absf(twist) < 0.001:
		return
	var torso_before: Basis = sk.get_bone_global_pose(_torso).basis.orthonormalized()
	sk.set_bone_pose_rotation(_pelvis, Quaternion(Vector3.UP, twist) * sk.get_bone_pose_rotation(_pelvis))
	var pelvis_now: Basis = sk.get_bone_global_pose(_pelvis).basis.orthonormalized()
	sk.set_bone_pose_rotation(_torso, (pelvis_now.inverse() * torso_before).get_rotation_quaternion())
