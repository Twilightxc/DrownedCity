class_name SaveTransfer
extends Node
## Export / import a save as a file, so a cleared browser cache or a new browser/PC does not lose
## the community (and, later, web saves import into the Steam build).
## Web: browser download + an <input type=file> picker through JavaScriptBridge.
## Desktop: the native file dialog.

signal imported(text: String)
signal failed(message: String)

const FILE_NAME: String = "drowned_city_save.json"

var _js_callback: JavaScriptObject  ## must stay referenced while the picker is open
var _dialog: FileDialog
var _export_text: String = ""


func export_text(text: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), FILE_NAME, "application/json")
		return
	_export_text = text
	_open_dialog(FileDialog.FILE_MODE_SAVE_FILE)


func request_import() -> void:
	if OS.has_feature("web"):
		_web_pick_file()
		return
	_open_dialog(FileDialog.FILE_MODE_OPEN_FILE)


func _web_pick_file() -> void:
	_js_callback = JavaScriptBridge.create_callback(_on_web_file)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	window.set("dcImportCallback", _js_callback)
	# Runs right after the click/press, inside the browser's user-activation window.
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.json,application/json';
			input.onchange = function () {
				var f = input.files[0];
				if (!f) { return; }
				f.text().then(function (t) { window.dcImportCallback(t); },
				              function () { window.dcImportCallback(''); });
			};
			input.click();
		})();
	""", true)


func _on_web_file(args: Array) -> void:
	var text: String = str(args[0]) if args.size() > 0 else ""
	if text.is_empty():
		failed.emit("could not read the file")
	else:
		imported.emit(text)


func _open_dialog(mode: FileDialog.FileMode) -> void:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.use_native_dialog = true
		_dialog.filters = PackedStringArray(["*.json ; Drowned City save"])
		_dialog.file_selected.connect(_on_dialog_file)
		add_child(_dialog)
	_dialog.file_mode = mode
	_dialog.current_file = FILE_NAME
	_dialog.popup_centered_ratio(0.6)


func _on_dialog_file(path: String) -> void:
	if _dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			failed.emit("cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
			return
		f.store_string(_export_text)
		f.close()
		return
	if not FileAccess.file_exists(path):
		failed.emit("file not found")
		return
	imported.emit(FileAccess.get_file_as_string(path))
