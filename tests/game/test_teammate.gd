extends GutTest
## PHASE1 1.5+ A5: a downed teammate gets up when the player stays next to it.

const MATE_LOADOUT: LoadoutConfig = preload("res://data/weapons/teammate_ar_loadout.tres")


func _fighter(f: SpikePlayer, grid: NavGrid, cam: Camera3D, at: Vector2) -> SpikePlayer:
	var marker: Node3D = Node3D.new()
	marker.name = "AimMarker"
	f.add_child(marker)
	add_child_autofree(f)
	f.setup(grid, Horde.new(HordeConfig.new(), grid, 4), cam, 0.0)
	f.position = Vector3(at.x, 0.0, at.y)
	return f


func test_revive_needs_the_player_to_stay_close_for_revive_sec() -> void:
	var cam: Camera3D = Camera3D.new()
	add_child_autofree(cam)
	var grid: NavGrid = NavGrid.new(20, 20)
	var player: SpikePlayer = _fighter(SpikePlayer.new(), grid, cam, Vector2(10, 10))
	var mate_node: Teammate = Teammate.new()
	mate_node.loadout = MATE_LOADOUT
	var mate: Teammate = _fighter(mate_node, grid, cam, Vector2(11, 10)) as Teammate
	mate.leader = player
	mate.health.take_hit(999, RandomNumberGenerator.new())
	assert_eq(mate.health.state, FighterHealth.State.DOWNED)
	mate._update_revive(0.0)
	assert_true(mate.is_in_group("interactable"), "the player can interact with it now")
	mate.interact(player)
	mate._update_revive(mate.teammate_config.revive_sec * 0.5)
	assert_almost_eq(mate.revive_fill(), 0.5, 0.01, "the HUD ring")
	player.position.x = 15.0  # walked away
	mate._update_revive(0.1)
	assert_lt(mate.revive_fill(), 0.0, "revive cancelled")
	player.position.x = 10.0
	mate.interact(player)
	mate._update_revive(mate.teammate_config.revive_sec + 0.1)
	assert_eq(mate.health.state, FighterHealth.State.ALIVE, "back up")
	mate._update_revive(0.0)
	assert_false(mate.is_in_group("interactable"))


func test_a_downed_fighter_fights_on_with_the_pistol_and_gets_its_long_gun_back() -> void:
	var cam: Camera3D = Camera3D.new()
	add_child_autofree(cam)
	var grid: NavGrid = NavGrid.new(20, 20)
	var p: SpikePlayer = SpikePlayer.new()
	p.loadout = preload("res://data/weapons/spike_loadout.tres")  # AR first, pistol second
	_fighter(p, grid, cam, Vector2(10, 10))
	await wait_physics_frames(2)
	var long_gun: Gun = p.gun
	assert_false(SpikePlayer.is_sidearm(long_gun))
	assert_eq(p.health.config.downed_sec, 20.0, "J: longer on the ground")
	p.health.take_hit(999, RandomNumberGenerator.new())
	assert_eq(p.health.state, FighterHealth.State.DOWNED)
	assert_true(SpikePlayer.is_sidearm(p.gun), "the pistol comes out")
	p.select_gun(0)
	assert_true(SpikePlayer.is_sidearm(p.gun), "no long gun while down")
	p.auto_trigger = true
	var before: int = p.shots_fired
	for i: int in 20:
		p._process(0.05)
	assert_gt(p.shots_fired, before, "it shoots from the ground")
	assert_eq(p.body.lower, &"downed_aim")
	p.auto_trigger = false
	p.health.revive()
	assert_eq(p.gun, long_gun, "back on its feet: the long gun again")
