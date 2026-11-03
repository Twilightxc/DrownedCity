extends GutTest
## PHASE1 1.5+ A1: audio pass 1.

const BANK: SfxBank = preload("res://data/audio/sfx_bank.tres")
const LOADOUT: LoadoutConfig = preload("res://data/weapons/spike_loadout.tres")
const SHOTGUN: WeaponConfig = preload("res://data/weapons/shotgun_12g.tres")
const AR: WeaponConfig = preload("res://data/weapons/ar_556.tres")
const BUDGET_BYTES: int = 3 * 1024 * 1024  ## PHASE1 1.5+ A1


func test_every_event_has_takes_and_every_config_names_a_known_event() -> void:
	for name: StringName in BANK.events:
		assert_false(BANK.events[name].streams.is_empty(), "%s has takes" % name)
	var names: Array[StringName] = []
	for path: String in ["pistol_9mm", "ar_556", "shotgun_12g", "dmr_308"]:
		var w: WeaponConfig = load("res://data/weapons/%s.tres" % path)
		names.append_array([w.shot_sfx, w.reload_sfx])
		if w.cycle_sfx != &"":
			names.append(w.cycle_sfx)
	for path: String in ["frag_grenade", "incendiary_grenade"]:
		names.append((load("res://data/weapons/%s.tres" % path) as ThrowableConfig).blast_sfx)
	for path: String in ["walker", "runner", "armored", "bloater"]:
		var e: EnemyConfig = load("res://data/enemies/%s.tres" % path)
		names.append_array([e.voice_sfx, e.death_sfx])
	names.append((load("res://data/weapons/attachments/silencer.tres") as AttachmentConfig).shot_sfx)
	names.append_array([&"dry_click", &"flesh_hit", &"helmet_clang", &"player_hit", &"footstep", &"fire_loop"])
	for n: StringName in names:
		assert_true(BANK.events.has(n), "bank has %s" % n)


func test_the_sounds_fit_the_download_budget() -> void:
	var total: int = 0
	for f: String in DirAccess.get_files_at("res://assets/audio"):
		if f.ends_with(".ogg"):
			total += FileAccess.get_file_as_bytes("res://assets/audio/" + f).size()
	assert_gt(total, 0)
	assert_lt(total, BUDGET_BYTES)


func test_player_drops_unknown_events_and_repeats_too_soon() -> void:
	var p: SfxPlayer = SfxPlayer.new()
	add_child_autofree(p)
	p.setup(BANK)
	assert_false(p.play(&"no_such_sound", Vector3.ZERO))
	assert_true(p.play(&"dry_click", Vector3.ZERO))
	assert_false(p.play(&"dry_click", Vector3.ZERO), "min_interval_sec")
	p._process(BANK.events[&"dry_click"].min_interval_sec + 0.01)
	assert_true(p.play(&"dry_click", Vector3.ZERO))
	assert_true(p.play(&"pump_shotgun", Vector3.ZERO, 1.0, -1.0, 0.3), "queued")
	assert_eq(p._delayed.size(), 1)
	p._process(0.31)
	assert_eq(p._delayed.size(), 0, "played after the delay")


func test_a_silencer_swaps_the_shot_sound() -> void:
	var pistol: WeaponSlot = LOADOUT.slots[1]  # silencer + flashlight
	assert_eq(Gun.new(pistol.weapon, pistol.attachments).shot_sfx, &"shot_pistol_silenced")
	assert_eq(Gun.new(pistol.weapon).shot_sfx, &"shot_pistol")


func test_reload_sounds_once_per_mag_or_per_shell_and_dry_fire_clicks() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var pouch: AmmoPouch = AmmoPouch.new()
	pouch.add(AR.caliber, 60)
	var ar: Gun = Gun.new(AR, [], pouch)
	ar.ammo = 0
	assert_true(ar.start_reload())
	assert_eq(ar.reload_sounds, 1, "a whole mag: one sound")
	var shells: AmmoPouch = AmmoPouch.new()
	shells.add(SHOTGUN.caliber, 3)
	var sg: Gun = Gun.new(SHOTGUN, [], shells)
	sg.ammo = 0
	sg.start_reload()
	for i: int in 200:
		sg.step(0.05, false, rng)
	assert_eq(sg.reload_sounds, 3, "one per shell")
	sg.ammo = 0
	sg.step(0.05, true, rng)  # pulled: empty and nothing left
	assert_eq(sg.dry_fires, 1)
	sg.step(0.05, true, rng)  # still held: no second click
	assert_eq(sg.dry_fires, 1)
