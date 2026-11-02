class_name TimeControl
extends Node
## The one owner of Engine.time_scale in a scene (Phase 1 step 1.4): hit-stop and the low-HP slow-mo ask
## for a scale for some real seconds, the slowest active request wins, and the scale returns to 1 when
## they end. Real time, so a freeze can't stretch itself.

var _scales: PackedFloat32Array = PackedFloat32Array()
var _until_ms: PackedInt64Array = PackedInt64Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func request(scale: float, real_sec: float) -> void:
	_scales.append(scale)
	_until_ms.append(Time.get_ticks_msec() + int(real_sec * 1000.0))
	_apply()


func active() -> bool:
	return not _scales.is_empty()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	for i: int in range(_scales.size() - 1, -1, -1):
		if now >= _until_ms[i]:
			_scales.remove_at(i)
			_until_ms.remove_at(i)
	_apply()


func _apply() -> void:
	var s: float = 1.0
	for v: float in _scales:
		s = minf(s, v)
	if not is_equal_approx(Engine.time_scale, s):
		Engine.time_scale = s


func _exit_tree() -> void:
	Engine.time_scale = 1.0
