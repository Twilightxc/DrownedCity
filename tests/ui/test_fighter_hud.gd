extends GutTest
## PHASE1 1.5+ A4: HP / stamina bars and the reload ring.

const LOADOUT: LoadoutConfig = preload("res://data/weapons/spike_loadout.tres")

var _player: SpikePlayer
var _hud: FighterHud


func before_each() -> void:
	var cam: Camera3D = Camera3D.new()
	add_child_autofree(cam)
	_player = SpikePlayer.new()
	_player.loadout = LOADOUT
	var marker: Node3D = Node3D.new()
	marker.name = "AimMarker"
	_player.add_child(marker)
	add_child_autofree(_player)
	var grid: NavGrid = NavGrid.new(10, 10)
	_player.setup(grid, Horde.new(HordeConfig.new(), grid, 4), cam, 0.0)
	_hud = FighterHud.new()
	add_child_autofree(_hud)
	_hud.bind(_player)


func test_the_ring_follows_a_magazine_reload() -> void:
	var g: Gun = _player.gun  # slot 0: the AR
	assert_eq(_hud.reload_fill(_player), -1.0, "no ring when not reloading")
	g.ammo = 0
	g.start_reload()
	_hud._process(0.0)
	g.reload_left = g.reload_sec * 0.25
	assert_almost_eq(_hud.reload_fill(_player), 0.75, 0.001)
	assert_eq(_hud.reload_steps(_player), 1)


func test_a_pump_shotgun_ring_steps_once_per_shell() -> void:
	_player.select_gun(2)
	var g: Gun = _player.gun
	g.ammo = g.mag_size - 4
	g.start_reload()
	_hud._process(0.0)
	assert_eq(_hud.reload_steps(_player), 4, "four shells to load")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var fills: Array[float] = []
	for i: int in 4:
		for k: int in ceili(g.reload_sec / 0.05) + 1:
			if not g.is_reloading():
				break
			g.step(0.05, false, rng)
			_hud._process(0.05)
			if g.is_reloading() and k == 2:
				fills.append(_hud.reload_fill(_player))
	assert_eq(fills.size(), 4)
	for i: int in fills.size():
		assert_between(fills[i], i / 4.0, (i + 1) / 4.0, "shell %d fills its quarter" % (i + 1))
