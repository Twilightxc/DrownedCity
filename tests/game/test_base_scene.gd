extends GutTest
## 1.7 step 3: the base on the roof. The room kit (tools/blender/kit_base.py -> data/base/room_kit.json), the roof
## layout, where daily life puts people (LifeSpots) and how they walk there (BaseNav).

const LEVEL: PackedScene = preload("res://game/level/style15_level.tscn")

var _kit: BaseKit


func before_each() -> void:
	_kit = BaseKit.new()


func _state(kind: String, people: int = 5, hour: int = 10) -> SimState:
	return BasePreset.make(kind, people, 7, hour)


func test_every_room_and_tier_has_a_model_with_its_beds_and_guard_posts() -> void:
	var rooms: Dictionary = BaseRules.data()["rooms"]
	for id: String in rooms:
		var tiers: Array = rooms[id]["tiers"]
		for t: int in tiers.size():
			var key: String = "%s_%d" % [id, t + 1]
			assert_true(_kit.kit.has(key), key)
			if not _kit.kit.has(key):
				continue
			assert_not_null(load(_kit.kit[key]["model"]), key)
			var def: Dictionary = tiers[t]
			assert_eq((_kit.kit[key]["beds"] as Array).size(), int(def.get("beds", 0)), key + " beds")
			assert_eq((_kit.kit[key]["guards"] as Array).size(), int(def.get("guards", 0)), key + " guard posts")
			if rooms[id].has("recipes") and def.has("queue"):
				assert_gt((_kit.kit[key]["work"] as Array).size(), 0, key + " has somewhere to work")
	for key: String in ["site_large", "site_small", "site_pile", "crate_seat"]:
		assert_true(_kit.kit.has(key), key)


func test_the_slots_fit_on_the_roof_clear_of_its_props_and_each_other() -> void:
	var slots: Array = _kit.layout["slots"]
	var sizes: Dictionary = {"large": Vector2(6.0, 4.5), "small": Vector2(3.0, 3.0)}
	var count: Dictionary = BaseRules.data()["slots"]
	assert_eq(slots.size(), int(count["large"]) + int(count["small"]))
	var level: Node = LEVEL.instantiate()
	add_child_autofree(level)
	var props: Array[Rect2] = []
	for node: Node in get_tree().get_nodes_in_group("nav_obstacle"):
		if not level.is_ancestor_of(node):
			continue
		var n3: Node3D = node as Node3D
		var fp: Vector2 = n3.get_meta("footprint", Vector2.ONE)
		if absf(sin(n3.global_rotation.y)) > 0.5:
			fp = Vector2(fp.y, fp.x)
		props.append(Rect2(Vector2(n3.global_position.x, n3.global_position.z) - fp * 0.5, fp))
	var roof_size: Array = _kit.layout["roof"]["size"]
	var roof: Rect2 = Rect2(-Vector2(float(roof_size[0]), float(roof_size[1])) * 0.5,
		Vector2(float(roof_size[0]), float(roof_size[1])))
	var placed: Array[Rect2] = []
	for i: int in slots.size():
		var size: Vector2 = sizes["large" if i < int(count["large"]) else "small"]
		var c: Vector3 = _kit.slot_transform(i).origin
		var rect: Rect2 = Rect2(Vector2(c.x, c.z) - size * 0.5, size)
		assert_true(roof.encloses(rect), "slot %d on the roof" % i)
		for p: Rect2 in props:
			assert_false(rect.intersects(p), "slot %d clear of %s" % [i, p])
		for other: Rect2 in placed:
			assert_false(rect.intersects(other), "slot %d clear of the other slots" % i)
		placed.append(rect)


func test_a_room_shows_its_tier_a_site_while_built_and_a_pile_while_upgraded() -> void:
	var r: RoomState = RoomState.new("large")
	assert_eq(BaseKit.model_key(r), "")
	r.room = "farm"
	r.building = 1
	assert_eq(BaseKit.model_key(r), "site_large")
	r.tier = 1
	r.building = 2
	assert_eq(BaseKit.model_key(r), "farm_1")
	assert_true(BaseKit.upgrading(r))
	assert_eq(_kit.room_spots(1, r, "work").size(), (_kit.kit["site_pile"]["work"] as Array).size(), "work at the pile")


func test_sleepers_take_beds_in_id_order_and_the_rest_sleep_on_the_roof() -> void:
	var state: SimState = _state("tier1", 6, 23)
	for s: Survivor in state.survivors:
		s.needs.doing = "sleep"
	var spots: Dictionary = LifeSpots.assign(state, _kit)
	var beds: Array[Dictionary] = _kit.room_spots(0, state.rooms[0], "beds")
	assert_eq(beds.size(), 4, "tents")
	for k: int in 4:
		assert_eq(spots[state.survivors[k].id]["pos"], beds[k]["pos"], "bed %d" % k)
	var floor_beds: Array[Dictionary] = _kit.roof_spots("floor_beds", &"sleep")
	assert_eq(spots[state.survivors[4].id]["pos"], floor_beds[0]["pos"])
	assert_eq(spots[state.survivors[5].id]["clip"], &"sleep")


func test_the_hurt_sleep_in_the_infirmary() -> void:
	var state: SimState = _state("tier1", 3, 23)
	var hurt: Survivor = state.survivors[2]
	NeedRules.injure(hurt, "fracture", StatMods.new())
	for s: Survivor in state.survivors:
		s.needs.doing = "sleep"
	var spots: Dictionary = LifeSpots.assign(state, _kit)
	assert_eq(spots[hurt.id]["pos"], _kit.room_spots(2, state.rooms[2], "beds")[0]["pos"])
	assert_eq(spots[state.survivors[0].id]["pos"], _kit.room_spots(0, state.rooms[0], "beds")[0]["pos"])


func test_workers_in_one_room_stand_apart_and_guards_take_the_posts() -> void:
	var state: SimState = _state("tier2", 3)
	for s: Survivor in state.survivors:
		s.needs.doing = "work"
		s.needs.doing_slot = 1
	state.survivors[2].needs.doing_slot = 5
	var spots: Dictionary = LifeSpots.assign(state, _kit)
	assert_ne(spots[state.survivors[0].id]["pos"], spots[state.survivors[1].id]["pos"])
	assert_eq(spots[state.survivors[0].id]["clip"], &"work_kneel", "at the planters")
	assert_eq(spots[state.survivors[2].id]["clip"], &"watch")
	assert_gt((spots[state.survivors[2].id]["pos"] as Vector3).y, 2.0, "up on the tower deck")


func test_idle_wander_and_a_mission_leaves_the_roof() -> void:
	var state: SimState = _state("tier1", 2)
	state.survivors[0].needs.doing = "idle"
	state.survivors[1].needs.activity = "mission"
	var spots: Dictionary = LifeSpots.assign(state, _kit)
	assert_true(spots[state.survivors[0].id].get("wander", false))
	assert_true(spots[state.survivors[1].id].get("away", false))


func test_company_sits_round_the_fire_then_stands_round_it() -> void:
	var state: SimState = _state("tier1", 5, 19)
	for s: Survivor in state.survivors:
		s.needs.doing = "socialise"
		s.needs.doing_slot = -1
	var spots: Dictionary = LifeSpots.assign(state, _kit)
	var clips: Array = state.survivors.map(func(s: Survivor) -> StringName: return spots[s.id]["clip"])
	assert_eq(clips, [&"sit", &"sit", &"sit", &"chat", &"chat"], "three logs")


func test_every_spot_in_the_presets_can_be_walked_to() -> void:
	for kind: String in BasePreset.KINDS:
		var state: SimState = _state(kind, 6)
		var nav: BaseNav = _nav(state)
		var start: Vector2 = Vector2(0.0, 0.0)
		for i: int in state.rooms.size():
			for k: String in ["beds", "work", "seats", "guards"]:
				for spot: Dictionary in _kit.room_spots(i, state.rooms[i], k):
					var p: Vector3 = spot["pos"]
					assert_gt(nav.path(start, Vector2(p.x, p.z)).size(), 0, "%s slot %d %s" % [kind, i, k])


func test_a_path_goes_round_a_room_not_through_it() -> void:
	var state: SimState = _state("tier1", 1)
	var nav: BaseNav = _nav(state)
	var farm: Vector3 = _kit.slot_transform(1).origin
	var path: PackedVector2Array = nav.path(Vector2(farm.x - 3.5, farm.z), Vector2(farm.x + 3.5, farm.z))
	assert_gt(path.size(), 2, "it turns")
	for k: int in range(1, path.size() - 1):
		assert_true(nav.grid.is_walkable_world(path[k]), "corner %d on open roof" % k)


func _nav(state: SimState) -> BaseNav:
	var roof: Array = _kit.layout["roof"]["size"]
	var nav: BaseNav = BaseNav.new(Vector2(float(roof[0]), float(roof[1])), float(_kit.layout["roof"]["cell"]))
	for i: int in state.rooms.size():
		for rect: Rect2 in _kit.room_solids(i, state.rooms[i]):
			nav.block(rect.position, rect.size)
	nav.commit()
	return nav
