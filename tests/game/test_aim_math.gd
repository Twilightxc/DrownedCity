extends GutTest

const PITCH: float = deg_to_rad(-35.264)


func _camera_basis(yaw_deg: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Basis(Vector3.RIGHT, PITCH)


func test_screen_axes_follow_camera_yaw() -> void:
	var b: Basis = _camera_basis(0.0)
	assert_almost_eq(AimMath.screen_to_world(Vector2.RIGHT, b), Vector2(1, 0), Vector2(0.001, 0.001))
	assert_almost_eq(AimMath.screen_to_world(Vector2.DOWN, b), Vector2(0, 1), Vector2(0.001, 0.001), "screen down = toward the camera")


func test_rotating_the_camera_keeps_controls_camera_relative() -> void:
	# After a 90° turn, "right on screen" is a different world direction...
	var turned: Vector2 = AimMath.screen_to_world(Vector2.RIGHT, _camera_basis(90.0))
	assert_almost_eq(turned, Vector2(0, -1), Vector2(0.001, 0.001))
	# ...and still perpendicular to "up on screen", at full length despite the iso pitch.
	var up: Vector2 = AimMath.screen_to_world(Vector2.UP, _camera_basis(90.0))
	assert_almost_eq(turned.dot(up), 0.0, 0.001)
	assert_almost_eq(AimMath.screen_to_world(Vector2(1, 1).normalized(), _camera_basis(45.0)).length(), 1.0, 0.001)


func test_ray_hits_plane_at_body_height() -> void:
	var hit: Variant = AimMath.ray_to_plane(Vector3(0, 10, 10), Vector3(0, -1, -1).normalized(), 0.9)
	assert_not_null(hit)
	assert_almost_eq(hit as Vector3, Vector3(0, 0.9, 0.9), Vector3(0.001, 0.001, 0.001))


func test_ray_parallel_or_away_from_plane_misses() -> void:
	assert_null(AimMath.ray_to_plane(Vector3(0, 10, 0), Vector3(1, 0, 0), 0.0))
	assert_null(AimMath.ray_to_plane(Vector3(0, 10, 0), Vector3(0, 1, 0), 0.0))


func test_body_height_plane_aims_at_the_body_not_behind_it() -> void:
	# Iso camera looking down at -35°: the cursor over a zombie's chest (0.9 m up) projects onto the
	# floor ~1.3 m behind the zombie. The body-height plane returns the zombie's own position.
	var dir: Vector3 = (Basis(Vector3.RIGHT, PITCH) * Vector3.FORWARD).normalized()
	var chest: Vector3 = Vector3(0, 0.9, -5)
	var origin: Vector3 = chest - dir * 20.0
	var on_body: Vector3 = AimMath.ray_to_plane(origin, dir, 0.9)
	var on_floor: Vector3 = AimMath.ray_to_plane(origin, dir, 0.0)
	assert_almost_eq(on_body.z, -5.0, 0.001)
	assert_lt(on_floor.z, -6.0, "floor plane overshoots")


func test_clamp_range() -> void:
	var from: Vector2 = Vector2(1, 1)
	assert_almost_eq(AimMath.clamp_range(from, Vector2(21, 1), 2.0, 12.0, Vector2.UP), Vector2(13, 1), Vector2(0.001, 0.001))
	assert_almost_eq(AimMath.clamp_range(from, Vector2(1, 1.5), 2.0, 12.0, Vector2.UP), Vector2(1, 3), Vector2(0.001, 0.001))
	assert_almost_eq(AimMath.clamp_range(from, from, 2.0, 12.0, Vector2.LEFT), Vector2(-1, 1), Vector2(0.001, 0.001), "on top of thrower → fallback dir")
