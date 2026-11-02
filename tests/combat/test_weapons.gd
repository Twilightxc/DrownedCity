extends GutTest
## Phase 1 step 1.1: guns from data (GDD §6).

const PISTOL: WeaponConfig = preload("res://data/weapons/pistol_9mm.tres")
const AR: WeaponConfig = preload("res://data/weapons/ar_556.tres")
const SHOTGUN: WeaponConfig = preload("res://data/weapons/shotgun_12g.tres")
const DMR: WeaponConfig = preload("res://data/weapons/dmr_308.tres")
const SILENCER: AttachmentConfig = preload("res://data/weapons/attachments/silencer.tres")
const RED_DOT: AttachmentConfig = preload("res://data/weapons/attachments/red_dot.tres")
const EXT_MAG: AttachmentConfig = preload("res://data/weapons/attachments/extended_mag.tres")
const FLASHLIGHT: AttachmentConfig = preload("res://data/weapons/attachments/flashlight.tres")

var _rng: RandomNumberGenerator


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 11


## Frames at 60 FPS; returns the rounds fired.
func _hold(g: Gun, seconds: float, trigger: bool = true) -> int:
	var n: int = 0
	for i: int in int(round(seconds * 60.0)):
		n += g.step(1.0 / 60.0, trigger, _rng)
	return n


func _pouch(caliber: String, n: int) -> AmmoPouch:
	var p: AmmoPouch = AmmoPouch.new()
	p.add(caliber, n)
	return p


func test_sustained_dps_matches_the_gdd_table_within_10_percent() -> void:
	for row: Array in [[PISTOL, 110.0], [AR, 205.0], [SHOTGUN, 100.0], [DMR, 130.0]]:
		var cfg: WeaponConfig = row[0]
		var dps: float = Ballistics.sustained_dps(cfg)
		assert_almost_eq(dps, row[1], row[1] * 0.1, "%s: %.0f" % [cfg.display_name, dps])


func test_falloff_full_then_down_to_the_minimum() -> void:
	assert_eq(Ballistics.falloff(10.0, 20.0, 40.0, 0.6), 1.0)
	assert_almost_eq(Ballistics.falloff(30.0, 20.0, 40.0, 0.6), 0.8, 0.001)
	assert_almost_eq(Ballistics.falloff(99.0, 20.0, 40.0, 0.6), 0.6, 0.001)


func test_each_body_passed_takes_20_percent_off() -> void:
	assert_eq(Ballistics.body_mul(0), 1.0)
	assert_almost_eq(Ballistics.body_mul(1), 0.8, 0.001)
	assert_almost_eq(Ballistics.body_mul(2), 0.64, 0.001)


func test_armor_table() -> void:
	var A: Dictionary = {"none": WeaponConfig.Armor.NONE, "L": WeaponConfig.Armor.L, "M": WeaponConfig.Armor.M, "H": WeaponConfig.Armor.H}
	assert_eq(Ballistics.armor_mul(A.L, A.none), 1.0, "unarmored: full")
	assert_eq(Ballistics.armor_mul(A.H, A.M), 1.0, "higher pen: full")
	assert_eq(Ballistics.armor_mul(A.M, A.M), 0.75, "equal")
	assert_eq(Ballistics.armor_mul(A.L, A.M), 0.25, "lower")
	assert_true(Ballistics.stops_bullet(A.L, A.M))
	assert_false(Ballistics.stops_bullet(A.M, A.M))
	assert_false(Ballistics.stops_bullet(A.L, A.none))


func test_semi_fires_once_per_pull() -> void:
	var g: Gun = Gun.new(PISTOL)
	assert_eq(_hold(g, 1.0), 1, "held for a second")
	_hold(g, 0.1, false)
	assert_eq(_hold(g, 0.1), 1, "pulled again")


func test_auto_rate_follows_rpm() -> void:
	var g: Gun = Gun.new(AR)  # 700 rpm, 30 rounds
	assert_almost_eq(_hold(g, 1.0), 12, 1)


func test_burst_fires_three_then_pauses() -> void:
	var g: Gun = Gun.new(AR)
	g.next_mode()
	assert_eq(g.mode(), WeaponConfig.FireMode.BURST)
	assert_eq(_hold(g, 0.5), 3, "one burst per pull")
	assert_lt(g.shot_spread_deg(), g.spread_deg + g.bloom_deg, "burst is tighter")


func test_empty_magazine_reloads_from_the_pouch() -> void:
	var g: Gun = Gun.new(PISTOL, [], _pouch("9mm", 20))
	g.ammo = 1
	_hold(g, 0.05)
	assert_eq(g.ammo, 0)
	assert_true(g.is_reloading(), "auto reload on empty")
	_hold(g, PISTOL.reload_sec + 0.1, false)
	assert_eq(g.ammo, 15)
	assert_eq(g.pouch.count("9mm"), 5)


func test_no_rounds_no_reload() -> void:
	var g: Gun = Gun.new(PISTOL, [], _pouch("9mm", 0))
	g.ammo = 0
	assert_false(g.start_reload())


func test_shotgun_loads_shell_by_shell_and_a_pull_interrupts() -> void:
	var g: Gun = Gun.new(SHOTGUN, [], _pouch("12g", 20))
	g.ammo = 2
	assert_true(g.start_reload())
	_hold(g, SHOTGUN.reload_sec * 2.0 + 0.05, false)
	assert_eq(g.ammo, 4, "two shells in two reload steps")
	assert_true(g.is_reloading(), "still loading")
	assert_eq(_hold(g, 0.05), 1, "the pull fires a loaded shell")
	assert_false(g.is_reloading())
	assert_eq(g.pellet_dirs(Vector2.RIGHT, _rng).size(), 15)


func test_worn_guns_jam_and_a_reload_clears_it() -> void:
	var g: Gun = Gun.new(AR)
	assert_eq(g.jam_chance(), 0.0, "new gun")
	g.durability = 0.0
	assert_almost_eq(g.jam_chance(), AR.jam_chance_max, 0.0001)
	for i: int in 2000:
		g.step(1.0 / 60.0, true, _rng)
		if g.jammed:
			break
	assert_true(g.jammed)
	assert_eq(_hold(g, 0.5), 0, "a jammed gun doesn't fire")
	assert_true(g.start_reload())
	_hold(g, g.reload_sec, false)
	assert_false(g.jammed)


func test_wear_per_shot() -> void:
	var g: Gun = Gun.new(AR)
	var n: int = _hold(g, 1.0)
	assert_almost_eq(g.durability, 100.0 - n * AR.wear_per_shot, 0.001)


func test_attachments_change_the_numbers() -> void:
	var g: Gun = Gun.new(AR, [SILENCER, RED_DOT, EXT_MAG, FLASHLIGHT])
	assert_eq(g.mag_size, 45, "extended mag ×1.5")
	assert_eq(g.ammo, 45)
	assert_almost_eq(g.noise_m, AR.noise_m * 0.4, 0.001, "silencer")
	assert_almost_eq(g.damage, AR.damage * 0.95, 0.001)
	assert_almost_eq(g.spread_deg, AR.spread_deg * 0.9, 0.001, "red dot")
	assert_almost_eq(g.reload_sec, AR.reload_sec * 1.15, 0.001)
	assert_true(g.flashlight)
	assert_false(Gun.new(AR).flashlight)


func test_one_attachment_per_slot_and_only_slots_the_gun_has() -> void:
	var g: Gun = Gun.new(SHOTGUN, [SILENCER, FLASHLIGHT, FLASHLIGHT])  # no muzzle slot on the pump
	assert_eq(g.attachments.size(), 1)
	assert_almost_eq(g.noise_m, SHOTGUN.noise_m, 0.001, "silencer refused")


func test_hits_stagger_and_falloff_damage() -> void:
	var grid: NavGrid = NavGrid.new(20, 20)
	var config: HordeConfig = HordeConfig.new()
	config.hp = 100
	var horde: Horde = Horde.new(config, grid, 4)
	horde.spawn(Vector2(5.5, 5.5))
	var near: int = Ballistics.hit_damage(AR.damage, 5.0, 0, 0, AR)
	var far: int = Ballistics.hit_damage(AR.damage, 40.0, 0, 0, AR)
	assert_eq(near, 34)
	assert_eq(far, roundi(34 * 0.6))
	horde.apply_hits(PackedInt32Array([0]), PackedInt32Array([near]), Vector2(0, 5.5), false, 0.5)
	assert_eq(horde.hp[0], 66)
	horde.recompute_flow([Vector2i(0, 5)] as Array[Vector2i])
	var before: Vector2 = horde.positions[0]
	for i: int in 10:
		horde.update(0.02, Vector2(0.5, 5.5))
	assert_eq(horde.positions[0], before, "staggered: stands still")
