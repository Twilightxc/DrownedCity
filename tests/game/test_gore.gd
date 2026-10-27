extends GutTest

const MALE: VatModel = preload("res://assets/vat/zombie_male.tres")

var _config: GoreConfig
var _corpses: CorpseLayer
var _blood: BloodFx


func before_each() -> void:
	_config = GoreConfig.new()
	_config.corpse_cap = 10
	_config.pool_cap = 4
	_corpses = CorpseLayer.new()
	add_child_autofree(_corpses)
	_corpses.setup(_config, [MALE] as Array[VatModel])
	_blood = BloodFx.new()
	add_child_autofree(_blood)
	_blood.setup(_config)


func _death(blast: bool = false) -> Horde.Death:
	var d: Horde.Death = Horde.Death.new()
	d.position = Vector2(1, 2)
	d.heading = Vector2(0, 1)
	d.push = Vector2(1, 0)
	d.blast = blast
	return d


func test_corpse_cap_is_never_exceeded() -> void:
	_config.dismember_chance = 0.0
	for i: int in 25:
		_corpses.add_death(_death())
	assert_eq(_corpses.live_count(), _config.corpse_cap)


## Steps of 1/20 s: CorpseLayer clamps each frame's delta to that.
func _advance(sec: float) -> void:
	for i: int in ceili(sec * 20.0):
		_corpses._process(1.0 / 20.0)


func test_old_corpses_sink_and_go() -> void:
	_config.dismember_chance = 0.0
	_corpses.add_death(_death())
	_advance(_config.corpse_life_sec + 0.1)
	assert_eq(_corpses.live_count(), 1, "starts sinking")
	_advance(_config.sink_sec + 0.1)
	assert_eq(_corpses.live_count(), 0, "gone after sinking")


func test_one_long_frame_does_not_sink_everything() -> void:
	_config.dismember_chance = 0.0
	_corpses.add_death(_death())
	_corpses._process(_config.corpse_life_sec * 2.0)  # a background tab resuming
	_corpses._process(_config.sink_sec * 2.0)
	assert_eq(_corpses.live_count(), 1, "delta is clamped")


func test_dismember_hides_a_group_and_throws_the_limb() -> void:
	_config.dismember_chance = 1.0
	var hide: int = _corpses.add_death(_death())
	assert_true(hide in CorpseLayer.LIMB_GROUPS)
	assert_eq(_corpses.live_count(), 2, "corpse + severed limb")
	assert_eq(_corpses._hide[0], hide, "corpse misses the group")
	assert_eq(_corpses._hide[1], CorpseLayer.ALL_PARTS & ~hide, "limb shows only the group")
	assert_gt(_corpses._pos[1].x, _corpses._pos[0].x, "limb thrown along the push")


func test_gore_off_keeps_corpses_whole_and_no_blood() -> void:
	_config.enabled = false
	_config.dismember_chance = 1.0
	assert_eq(_corpses.add_death(_death()), 0)
	assert_eq(_corpses.live_count(), 1)
	_blood.hit(Vector2.ZERO, Vector2.RIGHT)
	_blood.pool(Vector2.ZERO, 1.0)
	_blood._process(0.016)
	assert_eq(_blood.pool_count(), 0)


func test_blast_corpse_faces_the_blast() -> void:
	_config.dismember_chance_blast = 0.0
	_corpses.add_death(_death(true))
	assert_eq(_corpses._clip[0], 1, "death_blown clip")
	assert_eq(_corpses._head[0], Vector2(-1, 0), "faces the blast, falls away from it")


func test_pool_ring_reuses_oldest() -> void:
	for i: int in 6:
		_blood.pool(Vector2(i, 0), 1.0)
	_blood._process(0.016)
	assert_eq(_blood.pool_count(), _config.pool_cap)
