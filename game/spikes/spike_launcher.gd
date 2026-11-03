class_name SpikeLauncher
extends Node
## Boots the requested spike (Phase 0, and the Phase 1 arena): `?spike=horde` on the web URL, or `-- --spike=horde` on desktop.
## Spikes read their own test options the same way with `SpikeLauncher.arg()`, e.g. `?spike=arena&wave=4`.
## Default is the newest spike, so the live URL always shows what is under test.

const SPIKES: Dictionary[String, String] = {
	"arena": "res://game/spikes/arena_spike.tscn",
	"poses": "res://game/spikes/pose_spike.tscn",
	"interior": "res://game/spikes/interior_spike.tscn",
	"save": "res://game/spikes/save_spike.tscn",
	"twinstick": "res://game/spikes/twin_stick_spike.tscn",
	"style": "res://game/spikes/style_spike.tscn",
	"horde": "res://game/spikes/horde_spike.tscn",
}
const DEFAULT_SPIKE: String = "arena"


func _ready() -> void:
	var key: String = arg("spike", DEFAULT_SPIKE)
	if not SPIKES.has(key):
		push_warning("Unknown spike '%s', using '%s'" % [key, DEFAULT_SPIKE])
		key = DEFAULT_SPIKE
	get_tree().change_scene_to_file.call_deferred(SPIKES[key])


## `key=value` from the web URL's query string, or `--key=value` after `--` on desktop.
static func arg(key: String, fallback: String = "") -> String:
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		for pair: String in str(search).trim_prefix("?").split("&", false):
			if pair.begins_with(key + "="):
				return pair.trim_prefix(key + "=")
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.trim_prefix("--%s=" % key)
	return fallback
