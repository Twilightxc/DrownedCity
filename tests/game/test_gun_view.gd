extends GutTest
## PHASE1 1.1 assets: gun meshes and attachments in the player's hands.

const GUNS: Array[String] = ["pistol_9mm", "ar_556", "shotgun_12g", "dmr_308"]
const ATTACHMENTS: Array[String] = ["silencer", "red_dot", "extended_mag", "flashlight"]
const LOADOUT: LoadoutConfig = preload("res://data/weapons/spike_loadout.tres")


func test_every_demo_gun_has_a_model_with_a_mount_for_each_slot() -> void:
	for gun_name: String in GUNS:
		var cfg: WeaponConfig = load("res://data/weapons/%s.tres" % gun_name)
		assert_not_null(cfg.model, gun_name)
		assert_not_null(cfg.model.mesh_scene, gun_name)
		assert_gt(cfg.model.muzzle.z, 0.15, "%s: the muzzle is ahead of the grip" % gun_name)
		for slot: String in cfg.attachment_slots:
			assert_true(cfg.model.mounts.has(slot), "%s mounts %s" % [gun_name, slot])
	for att_name: String in ATTACHMENTS:
		var att: AttachmentConfig = load("res://data/weapons/attachments/%s.tres" % att_name)
		assert_not_null(att.mesh_scene, att_name)


func _view(slot: int) -> GunView:
	var view: GunView = GunView.new()
	add_child_autofree(view)
	var s: WeaponSlot = LOADOUT.slots[slot]
	view.show_gun(Gun.new(s.weapon, s.attachments))
	return view


func test_the_view_shows_the_gun_with_its_attachments() -> void:
	var ar: GunView = _view(0)  # red dot, extended mag, flashlight
	assert_eq(ar.part_count(), 3)
	assert_almost_eq(ar.muzzle_position(), ar.shown.config.model.muzzle, Vector3.ONE * 0.001)
	var shotgun: GunView = _view(2)
	assert_eq(shotgun.part_count(), 0, "no attachments")


func test_a_silencer_moves_the_muzzle_forward() -> void:
	var pistol: GunView = _view(1)  # silencer, flashlight
	var silencer: AttachmentConfig = load("res://data/weapons/attachments/silencer.tres")
	assert_eq(pistol.part_count(), 2)
	var bare: Vector3 = pistol.shown.config.model.muzzle
	var scale: float = pistol.shown.config.model.part_scale
	assert_almost_eq(pistol.muzzle_position().z, bare.z + silencer.muzzle_extend_m * scale, 0.001, "scaled with the gun")


func test_switching_guns_swaps_the_model() -> void:
	var view: GunView = _view(0)
	var s: WeaponSlot = LOADOUT.slots[3]
	view.show_gun(Gun.new(s.weapon, s.attachments))
	await wait_process_frames(1)  # the old model is freed at the end of the frame
	assert_eq(view.get_child_count(), 2, "only the DMR and its mag, no leftovers")
