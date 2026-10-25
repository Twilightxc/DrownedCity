extends CanvasLayer
## Always-on build label (bottom-right) + F3 / gamepad Back debug overlay.
## Other systems publish extra counters with DebugOverlay.set_stat("zombies", n).

const REFRESH_SEC: float = 0.25

var _stats: Dictionary[String, String] = {}
var _refresh_left: float = 0.0

@onready var _build_label: Label = %BuildLabel
@onready var _panel: PanelContainer = %Panel
@onready var _stats_label: Label = %StatsLabel


func _ready() -> void:
	_build_label.text = BuildInfo.label()
	_panel.visible = false
	set_stat("zombies", "0")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug_overlay"):
		_panel.visible = not _panel.visible
		_refresh_left = 0.0
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = REFRESH_SEC
	_stats_label.text = _compose()


func set_stat(key: String, value: String) -> void:
	_stats[key] = value


func _compose() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("FPS: %d (%.1f ms)" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	lines.append("Draw calls: %d" % RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	lines.append("Objects drawn: %d" % RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	lines.append("Primitives: %d" % RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	lines.append("Nodes: %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	lines.append("Video mem: %.1f MB" % (RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0))
	for key: String in _stats:
		lines.append("%s: %s" % [key.capitalize(), _stats[key]])
	lines.append("Renderer: %s" % RenderingServer.get_current_rendering_method())
	lines.append("Adapter: %s" % RenderingServer.get_video_adapter_name())
	return "\n".join(lines)
