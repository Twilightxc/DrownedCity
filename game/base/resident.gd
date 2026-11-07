class_name Resident
extends Node3D
## One survivor living in the base scene (1.7 step 3): walks (stroll clip) along a BaseNav path to this hour's
## spot (LifeSpots), then settles there: height (a bed, the tower deck), facing, the activity's clip and the item in
## hand (a hoe, a watering can, a book). Idle survivors wander between the layout's stroll points. An errand (lighting
## a fire drum) comes first. A name tag floats above the head.

const WALK_SPEED: float = 1.4  ## m/s, the stroll clip's stride (kit_survivor.py STROLL_SPEED)
const ARRIVE_M: float = 0.08
const TURN_RATE: float = 8.0  ## 1/s
const ITEMS: Dictionary[String, PackedScene] = {
	"hoe": preload("res://assets/models/hand_hoe.glb"), "can": preload("res://assets/models/hand_can.glb"),
	"book": preload("res://assets/models/hand_book.glb"),
}

var survivor_id: int = 0
var view: SurvivorView
var tag: Label3D
var spot: Dictionary = {}
var _nav: BaseNav
var _path: PackedVector2Array = PackedVector2Array()
var _wander: PackedVector2Array = PackedVector2Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _settled: bool = false
## A job on the way (lighting a fire drum): {"pos": Vector3, "yaw": float, "sec": float, "done": Callable}. They
## walk there first, kneel for `sec`, call `done`, then go on to their spot.
var _errand: Dictionary = {}
var _errand_left: float = 0.0


func setup(s: Survivor, nav: BaseNav, wander_points: PackedVector2Array) -> void:
	survivor_id = s.id
	name = "Resident_%s" % s.name
	_nav = nav
	_wander = wander_points
	_rng.seed = s.appearance_seed
	view = SurvivorView.new()
	add_child(view)
	view.set_look(s.id - 1)
	view.set_gun(null)
	tag = Label3D.new()
	tag.text = s.name
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.pixel_size = 0.008
	tag.font_size = 32
	tag.outline_size = 10
	tag.modulate = Color(1.0, 0.93, 0.8)
	tag.position = Vector3(0.0, 2.15, 0.0)
	add_child(tag)


## This hour's spot. A new place means a new walk; the same place with a new task (a planter's next stage) changes
## the clip in place; the same everything (asleep all night) leaves them be.
func go_to(new_spot: Dictionary) -> void:
	var same: bool = not spot.is_empty() and (spot["pos"] as Vector3).is_equal_approx(new_spot["pos"]) 			and spot.get("wander", false) == new_spot.get("wander", false)
	spot = new_spot
	if not _errand.is_empty():
		return  # the errand first; they head for the new spot after it
	if same and (_settled or spot.get("wander", false)):
		if _settled:
			_settle()
		return
	_head_for_spot()


## Walk to `pos` first, kneel there for `sec` (scaled game time), call `done`, then carry on.
func errand(pos: Vector3, yaw: float, sec: float, done: Callable) -> void:
	_errand = {"pos": pos, "yaw": yaw, "sec": sec, "done": done}
	_errand_left = -1.0
	_settled = false
	visible = true
	view.hold(null)
	_walk_to(pos)


func busy() -> bool:
	return not _errand.is_empty()


## Puts them at their spot at once (the scene's first frame, a skipped day).
func snap() -> void:
	if spot.get("wander", false):
		_next_wander()
		return
	_settle()


func _process(delta: float) -> void:
	if view == null or _settled:
		return
	if _errand_left > 0.0:  # kneeling at the errand
		_errand_left -= delta
		if _errand_left <= 0.0:
			var done: Callable = _errand["done"]
			_errand = {}
			if done.is_valid():
				done.call()
			_head_for_spot()
		return
	if _path.is_empty():
		if not _errand.is_empty():
			position = _errand["pos"]
			rotation.y = float(_errand["yaw"])
			view.live(&"work_kneel")
			_errand_left = float(_errand["sec"])
		elif spot.get("wander", false):
			_next_wander()
		else:
			_settle()
		return
	var here: Vector2 = Vector2(position.x, position.z)
	var to: Vector2 = _path[0]
	var step: float = WALK_SPEED * delta
	var d: float = here.distance_to(to)
	if d <= maxf(step, ARRIVE_M):
		position = Vector3(to.x, 0.0, to.y)
		_path.remove_at(0)
		return
	var dir: Vector2 = (to - here) / d
	position += Vector3(dir.x, 0.0, dir.y) * step
	position.y = 0.0
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.y), clampf(delta * TURN_RATE, 0.0, 1.0))
	view.live(&"stroll", WALK_SPEED)


func _head_for_spot() -> void:
	_settled = false
	visible = true
	view.hold(null)  # tools come out at the spot
	if spot.is_empty() or spot.get("wander", false):
		_next_wander()
	else:
		_walk_to(spot["pos"])


func _walk_to(p: Vector3) -> void:
	position.y = 0.0  # down off a bed or the tower first
	_path = _nav.path(Vector2(position.x, position.z), Vector2(p.x, p.z))
	if _path.is_empty():
		_path = PackedVector2Array([Vector2(p.x, p.z)])  # no way round: straight there
	elif _path.size() > 0:
		_path.remove_at(0)  # the start is where they stand


func _next_wander() -> void:
	if _wander.is_empty():
		_settle()
		return
	var p: Vector2 = _wander[_rng.randi_range(0, _wander.size() - 1)]
	_walk_to(Vector3(p.x, 0.0, p.y))


func _settle() -> void:
	_path.clear()
	_settled = true
	var p: Vector3 = spot["pos"]
	position = p
	rotation.y = float(spot["yaw"])
	view.live(spot["clip"])
	view.hold(ITEMS.get(str(spot.get("item", ""))))
	visible = not spot.get("away", false)
