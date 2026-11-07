class_name BaseKit
extends RefCounted
## The base's look on the roof (1.7 step 3): which room model stands in each slot (data/base/room_kit.json, written
## by tools/blender/kit_base.py) and where the slots and the roof's own spots are (data/base/roof_layout.json).
## Every spot comes back in world space: {"pos": Vector3, "yaw": float, "clip": StringName}.

const KIT_PATH: String = "res://data/base/room_kit.json"
const LAYOUT_PATH: String = "res://data/base/roof_layout.json"

var kit: Dictionary = {}  ## room_kit.json "rooms": model key -> {model, beds, work, seats, guards, solids}
var layout: Dictionary = {}


func _init() -> void:
	kit = (JSON.parse_string(FileAccess.get_file_as_string(KIT_PATH)) as Dictionary)["rooms"]
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))


## The model standing in slot `r`: "<room>_<tier>", a construction site while the first tier is built, "" when empty.
static func model_key(r: RoomState) -> String:
	if r.room.is_empty():
		return ""
	if r.tier <= 0:
		return "site_" + r.size
	return "%s_%d" % [r.room, r.tier]


## A small plank pile in a corner while a standing room is upgraded.
static func upgrading(r: RoomState) -> bool:
	return r.tier > 0 and r.building > 0


func slot_transform(i: int) -> Transform3D:
	var s: Dictionary = (layout["slots"] as Array)[i]
	var p: Array = s["pos"]
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(s.get("yaw", 0.0)))), Vector3(float(p[0]), 0.0, float(p[1])))


func pile_transform(i: int, r: RoomState) -> Transform3D:
	var at: Array = layout["pile"][r.size]
	return slot_transform(i) * Transform3D(Basis.IDENTITY, Vector3(float(at[0]), 0.0, float(at[1])))


## `kind` spots ("beds", "work", "seats", "guards") of the model in slot `i`, in world space. While a room is
## upgraded its work happens at the pile.
func room_spots(i: int, r: RoomState, kind: String) -> Array[Dictionary]:
	if kind == "work" and upgrading(r):
		return _spots(kit["site_pile"], kind, pile_transform(i, r))
	var key: String = model_key(r)
	if key.is_empty() or not kit.has(key):
		return []
	return _spots(kit[key], kind, slot_transform(i))


## Footprints people walk around in slot `i`: [centre (x, z), size (x, z)] in world space.
func room_solids(i: int, r: RoomState) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var key: String = model_key(r)
	if key.is_empty() or not kit.has(key):
		return out
	var xf: Transform3D = slot_transform(i)
	var quarter: bool = absf(sin(xf.basis.get_euler().y)) > 0.5
	for s: Array in kit[key]["solids"]:
		var c: Vector3 = xf * Vector3(float(s[0]), 0.0, float(s[1]))
		var size: Vector2 = Vector2(float(s[2]), float(s[3]))
		if quarter:
			size = Vector2(size.y, size.x)
		out.append(Rect2(Vector2(c.x, c.z), size))
	return out


## The planters' soil tops in slot `i` (farms), world space: where FarmLook's crops stand.
func plots(i: int, r: RoomState) -> Array[Vector3]:
	return _points(i, r, "plots")


## Fire points in slot `i` (the kitchen's campfire or stove): [world position, flame size].
func fires(i: int, r: RoomState) -> Array[Array]:
	var out: Array[Array] = []
	var key: String = model_key(r)
	if key.is_empty() or not kit.has(key):
		return out
	var xf: Transform3D = slot_transform(i)
	for f: Array in kit[key].get("fires", []):
		out.append([xf * Vector3(float(f[0]), float(f[1]), float(f[2])), float(f[3])])
	return out


## The oil drums on the roof (layout fire_barrels), on the roof surface.
func barrels() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p: Array in layout["fire_barrels"]:
		out.append(Vector3(float(p[0]), 0.0, float(p[1])))
	return out


func _points(i: int, r: RoomState, kind: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var key: String = model_key(r)
	if key.is_empty() or not kit.has(key):
		return out
	var xf: Transform3D = slot_transform(i)
	for p: Array in kit[key].get(kind, []):
		out.append(xf * Vector3(float(p[0]), float(p[1]), float(p[2])))
	return out


## A roof spot list from the layout ("read", "exercise", "gather", "floor_beds"), `clip` played there.
func roof_spots(kind: String, clip: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Array in layout[kind]:
		out.append({"pos": Vector3(float(p[0]), 0.0, float(p[1])), "yaw": float(p[2]) if p.size() > 2 else 0.0, "clip": clip})
	return out


func stroll_points() -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Array in layout["stroll"]:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


func exit_point() -> Vector3:
	var p: Array = layout["exit"]
	return Vector3(float(p[0]), 0.0, float(p[1]))


func _spots(model: Dictionary, kind: String, xf: Transform3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var yaw0: float = xf.basis.get_euler().y
	for s: Array in model.get(kind, []):
		var spot: Dictionary = {"pos": xf * Vector3(float(s[0]), float(s[1]), float(s[2])), "yaw": yaw0 + float(s[3]),
			"clip": StringName(s[4])}
		if s.size() > 5:
			spot["plot"] = int(s[5])  # a farm spot tends this planter (FarmLook)
		out.append(spot)
	return out
