class_name RunLog
extends RefCounted
## Local-only playtest log (Phase 1 step 1.5): one JSON line per arena run in user://telemetry/. Nothing leaves
## the machine; sending anything waits for the opt-in consent screen (CLAUDE.md, PDPA). No personal data.

const DIR: String = "user://telemetry"
const FILE: String = "user://telemetry/arena_runs.jsonl"


## Appends `run` (a flat Dictionary of numbers and strings; the caller adds the build label) with a timestamp.
static func append(run: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f: FileAccess = FileAccess.open(FILE, FileAccess.READ_WRITE if FileAccess.file_exists(FILE) else FileAccess.WRITE)
	if f == null:
		return false
	f.seek_end()
	var line: Dictionary = run.duplicate()
	line["unix"] = int(Time.get_unix_time_from_system())
	f.store_line(JSON.stringify(line))
	f.close()
	return true


static func read_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(FILE):
		return out
	var f: FileAccess = FileAccess.open(FILE, FileAccess.READ)
	while f != null and not f.eof_reached():
		var line: String = f.get_line()
		if line.is_empty():
			continue
		var v: Variant = JSON.parse_string(line)
		if v is Dictionary:
			out.append(v)
	return out
