class_name AimMath
extends RefCounted
## Camera-relative input and iso aiming helpers. Pure functions, unit-tested.


## Screen-space stick/keys (x right, y down) to world XZ for a camera with this basis.
## Uses only the camera's yaw, so the result doesn't shrink with the iso pitch.
static func screen_to_world(v: Vector2, camera_basis: Basis) -> Vector2:
	var right: Vector2 = Vector2(camera_basis.x.x, camera_basis.x.z).normalized()
	var down: Vector2 = Vector2(camera_basis.z.x, camera_basis.z.z).normalized()
	return right * v.x + down * v.y


## Where a ray meets the horizontal plane y = plane_y, or null if it runs parallel/away.
static func ray_to_plane(origin: Vector3, dir: Vector3, plane_y: float) -> Variant:
	if absf(dir.y) < 0.0001:
		return null
	var t: float = (plane_y - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t


## Clamps a throw target to [min_range, max_range] from `from` (world XZ). A target on top of
## the thrower goes `fallback_dir`.
static func clamp_range(from: Vector2, to: Vector2, min_range: float, max_range: float, fallback_dir: Vector2) -> Vector2:
	var d: Vector2 = to - from
	var len: float = d.length()
	if len < 0.0001:
		return from + fallback_dir.normalized() * min_range
	return from + d / len * clampf(len, min_range, max_range)
