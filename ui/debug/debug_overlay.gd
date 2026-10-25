extends CanvasLayer
## Always-on build label (bottom-right) + F3 / gamepad Back debug overlay.
## Other systems publish extra counters with DebugOverlay.set_stat("zombies", n).
## Desktop capture for art comparisons: `-- --capture=out.png [--capture-frames=300] [--hide-ui]`
## saves one frame and quits.

const REFRESH_SEC: float = 0.25

var _stats: Dictionary[String, String] = {}
var _refresh_left: float = 0.0
var _capture_path: String = ""
var _capture_frames: int = 300

@onready var _build_label: Label = %BuildLabel
@onready var _panel: PanelContainer = %Panel
@onready var _stats_label: Label = %StatsLabel


func _ready() -> void:
	_build_label.text = BuildInfo.label()
	_panel.visible = false
	set_stat("zombies", "0")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-frames="):
			_capture_frames = int(arg.trim_prefix("--capture-frames="))
		elif arg == "--hide-ui":
			visible = false


func _physics_process(_delta: float) -> void:
	if _capture_path.is_empty() or Engine.get_process_frames() < _capture_frames:
		return
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_capture_path)
	print("captured %s  fps=%d draws=%d prims=%d" % [_capture_path, Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	_capture_path = ""
	get_tree().quit()


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
