class_name SaveStore
extends RefCounted
## One save slot in user://. On web, Godot backs user:// with IndexedDB and syncs it when a file
## written here is closed, so the save survives closing the browser (unless site data is cleared:
## that is what export/import protects against).
## Writes go to a temp file first, the previous save is kept as .bak, and loading falls back to
## the .bak when the main file is damaged.

var dir: String
var slot: String


func _init(p_dir: String = "user://saves", p_slot: String = "slot_0") -> void:
	dir = p_dir
	slot = p_slot


func main_path() -> String:
	return "%s/%s.json" % [dir, slot]


func backup_path() -> String:
	return "%s/%s.bak.json" % [dir, slot]


func exists() -> bool:
	return FileAccess.file_exists(main_path()) or FileAccess.file_exists(backup_path())


## Returns "" on success, otherwise the error.
func write(text: String) -> String:
	var err: Error = DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		return "cannot create %s (%s)" % [dir, error_string(err)]
	var tmp: String = main_path() + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())]
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(main_path()):
		DirAccess.remove_absolute(backup_path())
		err = DirAccess.rename_absolute(main_path(), backup_path())
		if err != OK:
			return "cannot keep backup (%s)" % error_string(err)
	err = DirAccess.rename_absolute(tmp, main_path())
	if err != OK:
		return "cannot finish save (%s)" % error_string(err)
	return ""


## Decodes the main file, or the backup when the main file is missing or damaged.
func load_state() -> SaveCodec.Result:
	var result: SaveCodec.Result = _decode_file(main_path())
	if result.state != null:
		return result
	var backup: SaveCodec.Result = _decode_file(backup_path())
	if backup.state != null:
		backup.error = "main save damaged (%s), loaded the backup" % result.error
		return backup
	return result


func read_text() -> String:
	return FileAccess.get_file_as_string(main_path())


func clear() -> void:
	for path: String in [main_path(), backup_path(), main_path() + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _decode_file(path: String) -> SaveCodec.Result:
	if not FileAccess.file_exists(path):
		var missing: SaveCodec.Result = SaveCodec.Result.new()
		missing.error = "no save"
		return missing
	return SaveCodec.decode(FileAccess.get_file_as_string(path))
