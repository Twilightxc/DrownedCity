class_name RoomState
extends RefCounted
## One slot of the rooftop base (GDD §4) and the room in it: its tier, a build or upgrade under way, and the
## production queue. BaseRules changes it; data/sim/rooms.json holds the numbers.

var size: String = "small"  ## "large" or "small"
var room: String = ""  ## rooms.json id; "" = an empty slot
var tier: int = 0  ## built tier, 1-based; 0 = not finished yet
var building: int = 0  ## the tier under construction; 0 = none
var build_left: float = 0.0  ## work hours left on it
var queue: Array[Dictionary] = []  ## {"recipe": id, "count": units left, -1 = keep going}
var progress: float = 0.0  ## work hours into the current unit
var started: bool = false  ## the current unit's inputs are taken
var worked: float = 0.0  ## production work done here ever (work hours × tier speed): how far the farm's crops have grown


func _init(p_size: String = "small") -> void:
	size = p_size


func to_dict() -> Dictionary:
	var q: Array = []
	for j: Dictionary in queue:
		q.append([j["recipe"], j["count"]])
	return {"size": size, "room": room, "tier": tier, "building": building, "build_left": build_left, "queue": q,
		"progress": progress, "started": started, "worked": worked}


static func from_dict(d: Dictionary) -> RoomState:
	var r: RoomState = RoomState.new(str(d["size"]))
	r.room = str(d["room"])
	r.tier = int(d["tier"])
	r.building = int(d["building"])
	r.build_left = float(d["build_left"])
	for j: Variant in d["queue"]:
		r.queue.append({"recipe": str(j[0]), "count": int(j[1])})
	r.progress = float(d["progress"])
	r.started = bool(d["started"])
	r.worked = float(d["worked"])
	return r
