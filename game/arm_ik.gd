class_name ArmIK
extends RefCounted
## Two-bone IK for the survivor's arms (shoulder → elbow → wrist), shared by LeftHandIK and RightArmAim. Limbs
## hang along their bone's -Y; the elbow bends toward `pole` (skeleton space).


## Turns `arm` and `fore` so the wrist (the child joint `fore` ends at) reaches `wrist`, or as near as it can.
static func solve(sk: Skeleton3D, arm: int, fore: int, upper_len: float, fore_len: float, wrist: Vector3,
		pole: Vector3) -> void:
	var shoulder: Vector3 = sk.get_bone_global_pose(arm).origin
	var to_goal: Vector3 = wrist - shoulder
	var reach: float = clampf(to_goal.length(), 0.01, upper_len + fore_len - 0.001)
	var dir: Vector3 = to_goal.normalized()
	var bend: Vector3 = (pole - dir * pole.dot(dir)).normalized()
	var cos_a: float = clampf((upper_len * upper_len + reach * reach - fore_len * fore_len) / (2.0 * upper_len * reach),
		-1.0, 1.0)
	var elbow: Vector3 = shoulder + dir * cos_a * upper_len + bend * sqrt(1.0 - cos_a * cos_a) * upper_len
	point_bone(sk, arm, elbow)
	point_bone(sk, fore, shoulder + dir * reach)


## Turns bone `b` the shortest way so its limb (along -Y) points at `to`.
static func point_bone(sk: Skeleton3D, b: int, to: Vector3) -> void:
	var g: Transform3D = sk.get_bone_global_pose(b)
	var now: Vector3 = (g.basis * Vector3.DOWN).normalized()
	var want: Vector3 = (to - g.origin).normalized()
	if now.dot(want) > 0.99999:
		return
	var turned: Basis = Basis(Quaternion(now, want)) * g.basis.orthonormalized()
	set_global_rotation(sk, b, turned)


## Gives bone `b` the skeleton-space rotation `global_basis`.
static func set_global_rotation(sk: Skeleton3D, b: int, global_basis: Basis) -> void:
	var parent: Basis = sk.get_bone_global_pose(sk.get_bone_parent(b)).basis.orthonormalized()
	sk.set_bone_pose_rotation(b, (parent.inverse() * global_basis.orthonormalized()).get_rotation_quaternion())
