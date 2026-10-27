extends Node
## Boots the requested Phase 0 spike: `?spike=horde` on the web URL, or `-- --spike=horde` on desktop.
## Default is the newest spike, so the live URL always shows what is under test.

const SPIKES: Dictionary[String, String] = {
	"save": "res://game/spikes/save_spike.tscn",
	"twinstick": "res://game/spikes/twin_stick_spike.tscn",
	"style": "res://game/spikes/style_spike.tscn",
	"horde": "res://game/spikes/horde_spike.tscn",
}
const DEFAULT_SPIKE: String = "save"


func _ready() -> void:
	var key: String = _requested_spike()
	if not SPIKES.has(key):
		push_warning("Unknown spike '%s', using '%s'" % [key, DEFAULT_SPIKE])
		key = DEFAULT_SPIKE
	get_tree().change_scene_to_file.call_deferred(SPIKES[key])


func _requested_spike() -> String:
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		for pair: String in str(search).trim_prefix("?").split("&", false):
			if pair.begins_with("spike="):
				return pair.trim_prefix("spike=")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--spike="):
			return arg.trim_prefix("--spike=")
	return DEFAULT_SPIKE
