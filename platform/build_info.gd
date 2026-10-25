extends Node
## Build identity shown on screen so every playtest report maps to a commit.
## CI writes build_info.json before export; local runs fall back to "dev".

const INFO_PATH: String = "res://platform/build_info.json"

var commit: String = "dev"
var date: String = ""
var run_number: String = ""


func _ready() -> void:
	_load()


func label() -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var parts: PackedStringArray = PackedStringArray(["v" + version, commit])
	if not run_number.is_empty():
		parts.append("#" + run_number)
	if not date.is_empty():
		parts.append(date)
	return " · ".join(parts)


func _load() -> void:
	if not FileAccess.file_exists(INFO_PATH):
		date = Time.get_date_string_from_system()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INFO_PATH))
	if parsed is Dictionary:
		var info: Dictionary = parsed
		commit = str(info.get("commit", commit))
		date = str(info.get("date", date))
		run_number = str(info.get("run_number", run_number))
