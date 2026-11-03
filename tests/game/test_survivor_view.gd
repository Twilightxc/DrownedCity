extends GutTest
## PHASE1 1.5+ A2: the survivor body, its two clip layers and the gun in hand.

const LOADOUT: LoadoutConfig = preload("res://data/weapons/spike_loadout.tres")

var _body: SurvivorView


func before_each() -> void:
	_body = SurvivorView.new()
	add_child_autofree(_body)


func _walk_for(velocity: Vector2, gun: Gun) -> void:
	for i: int in 40:
		_body.drive(velocity, Vector2.UP, gun, false)
		_body._process(0.05)


func _gun(slot: int) -> Gun:
	var s: WeaponSlot = LOADOUT.slots[slot]  # 0 AR, 1 pistol, 2 shotgun, 3 DMR
	return Gun.new(s.weapon, s.attachments)


func test_every_clip_exists_and_loops_where_it_should() -> void:
	var anims: AnimationPlayer = _body._anims
	for clip: String in SurvivorView.LOWER_CLIPS + SurvivorView.UPPER_CLIPS:
		if SurvivorView.WALK_SETS.has(clip):
			for dir_clip: String in SurvivorView.WALK_SETS[clip]:
				assert_true(anims.has_animation(dir_clip), dir_clip)
		else:
			assert_true(anims.has_animation(clip), clip)
	for clip: String in SurvivorView.LOOP_CLIPS:
		assert_eq(anims.get_animation(clip).loop_mode, Animation.LOOP_LINEAR, clip)
	assert_eq(anims.get_animation("roll").loop_mode, Animation.LOOP_NONE)


func test_the_legs_follow_movement_and_the_arms_the_gun() -> void:
	var ar: Gun = _gun(0)
	_body.set_gun(ar)
	_body.drive(Vector2.ZERO, Vector2.UP, ar, false)
	assert_eq([_body.lower, _body.upper], [&"idle", &"aim_rifle"])
	_body.drive(Vector2(0, -4.5), Vector2.UP, ar, false)
	assert_eq(_body.lower, &"walk")
	assert_almost_eq(_body._tree.get(&"parameters/lower_speed/scale"), 1.0, 0.01, "stride matches 4.5 m/s")
	_walk_for(Vector2(0, 4.5), ar)
	assert_lt(_body._tree.get(&"parameters/lower_walk/blend_position"), -0.9, "backing away: the backwards walk")
	assert_almost_eq(_body._hip.twist, 0.0, 0.05, "hips square to the aim")
	_walk_for(Vector2(0, -4.5), ar)  # forward again first: at exactly 90° either walk is right (hysteresis)
	_walk_for(Vector2(4.5, 0), ar)  # aiming up the screen (-Z), walking sideways
	assert_gt(_body._tree.get(&"parameters/lower_walk/blend_position"), 0.9, "sideways: the forward walk...")
	assert_almost_eq(absf(_body._hip.twist), PI / 2, 0.05, "...with the hips turned to the travel")
	var pistol: Gun = _gun(1)
	_body.set_gun(pistol)
	_body.sprinting = true
	_body.drive(Vector2(0, -4.0), Vector2.UP, pistol, false)
	assert_eq([_body.lower, _body.upper], [&"run", &"carry_high"], "high ready")
	_body.drive(Vector2(0, -4.0), Vector2.UP, ar, false)
	assert_eq(_body.upper, &"carry_port", "port arms")
	_body.sprinting = false
	_body.stance = SurvivorView.Stance.PRONE
	_body.drive(Vector2(0, -0.6), Vector2.UP, ar, false)
	assert_eq(_body.lower, &"crawl")
	assert_eq(_body._tree.get(&"parameters/layer/blend_amount"), 0.0, "prone is a whole-body clip")
	_body.stance = SurvivorView.Stance.STAND
	_body.drive(Vector2.ZERO, Vector2.UP, ar, true)
	assert_eq(_body.lower, &"downed")


func test_reload_clips_last_as_long_as_the_gun_reloads() -> void:
	var ar: Gun = _gun(0)
	_body.set_gun(ar)
	ar.ammo = 0
	ar.reload_left = ar.reload_sec
	_body.drive(Vector2.ZERO, Vector2.UP, ar, false)
	assert_eq(_body.upper, &"reload_rifle")
	var len: float = _body._anims.get_animation("reload_rifle").length
	assert_almost_eq(_body._tree.get(&"parameters/upper_speed/scale"), len / ar.reload_sec, 0.001)
	var sg: Gun = _gun(2)
	sg.ammo = 0
	sg.reload_left = sg.reload_sec
	_body.drive(Vector2.ZERO, Vector2.UP, sg, false)
	assert_eq(_body.upper, &"reload_shell", "pump: one loop per shell")


func test_the_gun_sits_in_front_of_the_chest_pointing_ahead() -> void:
	for slot: int in [0, 1]:
		_body.set_gun(_gun(slot))
		_body.drive(Vector2.ZERO, Vector2.UP, _body.gun_view.shown, false)
		await wait_physics_frames(10)
		var t: Transform3D = _body.global_transform.affine_inverse() * _body.gun_view.global_transform
		assert_gt(t.basis.z.normalized().dot(Vector3.BACK), 0.95, "slot %d level and ahead" % slot)
		assert_between(t.origin.y, 1.0, 1.6, "slot %d at chest height" % slot)
		assert_gt(t.origin.z, 0.15, "slot %d in front of the body" % slot)


func test_sprint_holds_point_the_gun_up_and_across() -> void:
	for case: Array in [[1, &"carry_high"], [0, &"carry_port"]]:
		var g: Gun = _gun(case[0])
		_body.set_gun(g)
		_body.sprinting = true
		_body.drive(Vector2(0, -4.2), Vector2.UP, g, false)
		await wait_physics_frames(30)
		var t: Transform3D = _body.global_transform.affine_inverse() * _body.gun_view.global_transform
		var want: Vector3 = SurvivorView.HOLD_DIR[case[1]].normalized()
		assert_gt(t.basis.z.normalized().dot(want), 0.85, "%s points %s" % [case[1], want])
	_body.sprinting = false


func test_the_left_hand_reaches_the_support_point_and_lets_go_to_reload() -> void:
	var sk: Skeleton3D = _body.skeleton
	for slot: int in 4:
		var g: Gun = _gun(slot)
		_body.set_gun(g)
		_body.drive(Vector2.ZERO, Vector2.UP, g, false)
		await wait_physics_frames(40)
		await sk.skeleton_updated  # modifier results only exist inside the skeleton's update
		var palm: Vector3 = sk.get_bone_global_pose(sk.find_bone("hand_l")) * Vector3(0, -LeftHandIK.PALM_M, 0)
		var support: Vector3 = _body._ik.target(sk)
		assert_lt(palm.distance_to(support), 0.08, "slot %d: left palm on the gun" % slot)
	var ar: Gun = _gun(0)
	_body.set_gun(ar)
	ar.ammo = 0
	ar.reload_left = ar.reload_sec
	_body.drive(Vector2.ZERO, Vector2.UP, ar, false)
	await wait_physics_frames(40)
	assert_eq(_body._ik.influence, 1.0, "reloading: the IK walks the left hand to the mag and back")


func test_a_rifle_reload_takes_the_mag_out_drops_it_and_seats_a_new_one() -> void:
	var ar: Gun = _gun(3)  # the DMR: a plain mag
	_body.set_gun(ar)
	ar.ammo = 0
	ar.reload_left = ar.reload_sec
	_body.drive(Vector2.ZERO, Vector2.UP, ar, false)
	var seen: Dictionary = {}
	for phase: float in [0.05, 0.18, 0.3, 0.5, 0.8]:
		ar.reload_left = ar.reload_sec * (1.0 - phase)
		_body._process(0.016)
		seen[phase] = [_body.gun_view.mag_node.visible, _body.hand_item.visible]
	assert_eq(seen[0.05], [true, false], "mag still in")
	assert_eq(seen[0.18], [false, true], "old mag in the left hand")
	assert_eq(seen[0.3], [false, false], "dropped, reaching for a new one")
	assert_eq(seen[0.5], [false, true], "new mag on its way")
	assert_eq(seen[0.8], [true, false], "seated")
	assert_eq(_body._dropped.size(), 1, "the empty mag fell to the floor")


func test_a_sprint_turns_the_body_to_where_it_runs() -> void:
	var pistol: Gun = _gun(1)
	_body.set_gun(pistol)
	_body.sprinting = true
	_body.drive(Vector2(4.2, 0), Vector2.UP, pistol, false)
	for i: int in 30:
		_body._process(0.05)
	assert_almost_eq(absf(_body.rotation.y), PI / 2, 0.05, "aim up the screen, running sideways")
	_body.sprinting = false
	_body.drive(Vector2.ZERO, Vector2.UP, pistol, false)
	for i: int in 30:
		_body._process(0.05)
	assert_almost_eq(_body.rotation.y, 0.0, 0.05, "back to the aim")


func test_the_hip_twist_keeps_the_torso_and_gun_aimed() -> void:
	var ar: Gun = _gun(0)
	_body.set_gun(ar)
	_body.drive(Vector2.ZERO, Vector2.UP, ar, false)
	await wait_physics_frames(20)
	var sk: Skeleton3D = _body.skeleton
	await sk.skeleton_updated
	var straight: Basis = sk.get_bone_global_pose(sk.find_bone("torso")).basis
	_body._hip.twist = 1.2
	_body._twist_target = 1.2
	await sk.skeleton_updated
	var twisted: Basis = sk.get_bone_global_pose(sk.find_bone("torso")).basis
	var pelvis: Basis = sk.get_bone_global_pose(sk.find_bone("pelvis")).basis
	assert_gt(twisted.z.dot(straight.z), 0.99, "the torso still faces the aim")
	assert_lt(pelvis.z.dot(straight.z), 0.5, "the hips turned away")


func test_a_long_gun_is_shouldered_at_shoulder_height() -> void:
	var sk: Skeleton3D = _body.skeleton
	for slot: int in [0, 2, 3]:
		var g: Gun = _gun(slot)
		_body.set_gun(g)
		_body.drive(Vector2.ZERO, Vector2.UP, g, false)
		await wait_physics_frames(40)
		await sk.skeleton_updated
		var gun_t: Transform3D = sk.global_transform.affine_inverse() * _body.gun_view.global_transform
		var stock: Vector3 = gun_t * g.config.model.hand_points["stock"]
		var pocket: Vector3 = sk.get_bone_global_pose(sk.find_bone("torso")) * RightArmAim.POCKET
		assert_lt(stock.distance_to(pocket), 0.03, "slot %d: butt plate in the shoulder" % slot)
		assert_between(stock.y, 1.3, 1.5, "slot %d: at shoulder height" % slot)
