extends GutTest
## PHASE1 1.5+ A3: stances, sprint, dodge roll, stamina.

const MOVE: MovementConfig = preload("res://data/combat/movement.tres")
const AR: WeaponConfig = preload("res://data/weapons/ar_556.tres")

var _m: FighterMotion


func before_each() -> void:
	_m = FighterMotion.new(MOVE)


func _run(sec: float, sprint: bool, moving: bool = true, firing: bool = false) -> void:
	for i: int in roundi(sec * 20.0):
		_m.step(0.05, sprint, moving, firing)


func test_lower_stances_are_slower_steadier_quieter_and_harder_to_see() -> void:
	var stand: Array = [_m.speed_mul(), _m.spread_mul(), _m.step_noise_m(), _m.seen_mul()]
	_m.toggle_crouch()
	var crouch: Array = [_m.speed_mul(), _m.spread_mul(), _m.step_noise_m(), _m.seen_mul()]
	_m.toggle_prone()
	assert_eq(_m.stance, FighterMotion.Stance.PRONE, "C then Z: prone")
	var prone: Array = [_m.speed_mul(), _m.spread_mul(), _m.step_noise_m(), _m.seen_mul()]
	for i: int in 4:
		assert_gt(stand[i], crouch[i])
		assert_gt(crouch[i], prone[i])
	_m.toggle_prone()
	assert_eq(_m.stance, FighterMotion.Stance.STAND, "Z again stands up")


func test_sprint_drains_stamina_stops_when_empty_and_it_comes_back() -> void:
	_m.toggle_crouch()
	_run(0.1, true)
	assert_true(_m.sprinting)
	assert_eq(_m.stance, FighterMotion.Stance.STAND, "sprinting from a crouch stands you up")
	assert_false(_m.can_shoot())
	assert_gt(_m.step_noise_m(), MOVE.step_noise_m[0], "sprinting is loud")
	_run(MOVE.stamina_max / MOVE.sprint_stamina_per_sec + 0.1, true)
	assert_false(_m.sprinting, "out of breath")
	assert_almost_eq(_m.stamina, 0.0, 0.001)
	_run(0.2, true)
	assert_false(_m.sprinting, "holding Shift doesn't restart it below sprint_min_stamina")
	var left: float = _m.stamina
	_run(1.0, false)
	_run(MOVE.stamina_regen_delay_sec * 0.5, false)
	var later: float = _m.stamina
	assert_gt(later, left, "it comes back after a pause")
	assert_lt(later, MOVE.stamina_regen_per_sec * 1.5, "but only after the pause")
	_run(0.1, true, true, true)
	assert_false(_m.sprinting, "the trigger stops a sprint")


func test_no_sprint_or_roll_from_prone() -> void:
	_m.toggle_prone()
	_run(0.2, true)
	assert_false(_m.sprinting)
	assert_false(_m.try_roll(Vector2.UP))


func test_roll_costs_stamina_dodges_early_and_has_a_cooldown() -> void:
	assert_true(_m.try_roll(Vector2(3, 0)))
	assert_almost_eq(_m.stamina, MOVE.stamina_max - MOVE.roll_stamina, 0.001)
	assert_true(_m.has_iframes())
	assert_false(_m.can_shoot())
	assert_almost_eq(_m.roll_velocity().length() * MOVE.roll_sec, MOVE.roll_distance_m, 0.001, "covers its distance")
	_run(MOVE.roll_iframes_sec + 0.05, false)
	assert_false(_m.has_iframes(), "late in the roll you can be hit")
	_run(MOVE.roll_sec, false)
	assert_false(_m.is_rolling())
	assert_false(_m.try_roll(Vector2.UP), "cooldown")
	_run(MOVE.roll_cooldown_sec + 0.05, false)
	assert_true(_m.try_roll(Vector2.UP))


func test_a_dodge_makes_zombie_hits_and_blasts_miss() -> void:
	var h: FighterHealth = FighterHealth.new(FighterConfig.new())
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	h.dodging = true
	h.take_hit(20, rng)
	h.take_blast(20, false)
	assert_eq(h.hp, h.config.max_hp)
	h.dodging = false
	h.take_hit(20, rng)
	assert_lt(h.hp, h.config.max_hp)


func test_stance_tightens_the_spread() -> void:
	var g: Gun = Gun.new(AR)
	var full: float = g.shot_spread_deg()
	g.stance_spread_mul = MOVE.spread_mul[2]
	assert_almost_eq(g.shot_spread_deg(), full * MOVE.spread_mul[2], 0.0001)


func test_a_prone_fighter_is_seen_from_less_far() -> void:
	var grid: NavGrid = NavGrid.new(40, 40)
	var cfg: HordeConfig = HordeConfig.new()
	var h: Horde = Horde.new(cfg, grid, 4, 1)
	h.spawn(Vector2(5.5, 5.5), 0, Horde.State.DORMANT)
	var target: Vector2 = Vector2(5.5 + cfg.sight_m * 0.6, 5.5)
	h.perceive(target, 1.0, MOVE.seen_mul[2])
	assert_eq(h.state[0], Horde.State.DORMANT, "prone at 0.6 × sight: unseen")
	h.perceive(target, 1.0, 1.0)
	assert_eq(h.state[0], Horde.State.HUNTING, "standing: seen")
