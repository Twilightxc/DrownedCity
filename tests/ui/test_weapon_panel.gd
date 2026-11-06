extends GutTest
## The weapon panel (bug list item 17).


func test_pips_fit_the_space_and_big_magazines_get_a_bar() -> void:
	assert_eq(WeaponPanel.pip_width(7, 200.0), WeaponPanel.PIP_MAX_W, "a pistol: full-size pips")
	var w: float = WeaponPanel.pip_width(45, 200.0)
	assert_gt(w, 0.0)
	assert_lte(45 * (w + WeaponPanel.PIP_GAP) - WeaponPanel.PIP_GAP, 200.0 + 0.001, "45 fit")
	assert_eq(WeaponPanel.pip_width(100, 200.0), 0.0, "an LMG belt: a bar")


func test_downed_only_the_sidearm_slot_is_usable_and_it_draws() -> void:
	var cam: Camera3D = Camera3D.new()
	add_child_autofree(cam)
	var grid: NavGrid = NavGrid.new(20, 20)
	var p: SpikePlayer = SpikePlayer.new()
	p.loadout = preload("res://data/weapons/spike_loadout.tres")  # AR first, pistol second
	var marker: Node3D = Node3D.new()
	marker.name = "AimMarker"
	p.add_child(marker)
	add_child_autofree(p)
	p.setup(grid, Horde.new(HordeConfig.new(), grid, 4), cam, 0.0)
	var panel: WeaponPanel = WeaponPanel.new()
	add_child_autofree(panel)
	panel.bind(p)
	assert_true(WeaponPanel.slot_usable(p, 0))
	p.health.take_hit(999, RandomNumberGenerator.new())
	assert_false(WeaponPanel.slot_usable(p, 0), "no long gun while down")
	assert_true(WeaponPanel.slot_usable(p, 1), "the pistol")
	assert_false(WeaponPanel.slot_usable(p, 7), "no such slot")
	await wait_process_frames(2)
	assert_true(true, "drew without errors")
