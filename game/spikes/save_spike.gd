extends Control
## Spike D (Phase 0.6): does a SimCore save survive closing the browser, and does an exported file
## re-import in another browser? Minimal SimCore (3 survivors, 4 resources, day counter), autosave at
## each new day like the real game (GDD §12), plus manual save/load, export/import and new game.
## Mouse, keyboard and gamepad: every action is a focusable button (D-pad/stick + A).

const RULES: SimRules = preload("res://data/sim/base_economy.tres")

var _state: SimState
var _store: SaveStore = SaveStore.new()
var _transfer: SaveTransfer
var _info: Label
var _people: Label
var _stock: Label
var _log: Label
var _first_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transfer = SaveTransfer.new()
	_transfer.imported.connect(_on_imported)
	_transfer.failed.connect(func(msg: String) -> void: _say(tr("Import failed: %s") % msg))
	add_child(_transfer)
	_build_ui()
	if _store.exists():
		_load()
	else:
		_new_game()
	_first_button.grab_focus()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.09, 0.12, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)

	var buttons: VBoxContainer = VBoxContainer.new()
	row.add_child(buttons)
	var title: Label = Label.new()
	title.text = tr("Spike D: save on web")
	buttons.add_child(title)
	_first_button = _add_button(buttons, tr("Next day (autosave)"), _next_day)
	_add_button(buttons, tr("Scavenge (+supplies)"), _scavenge)
	_add_button(buttons, tr("Save now"), _save)
	_add_button(buttons, tr("Load"), _load)
	_add_button(buttons, tr("Export save file"), _export)
	_add_button(buttons, tr("Import save file"), _transfer.request_import)
	_add_button(buttons, tr("New game"), _new_game)

	var view: VBoxContainer = VBoxContainer.new()
	view.custom_minimum_size.x = 420.0
	row.add_child(view)
	_info = Label.new()
	_people = Label.new()
	_stock = Label.new()
	_log = Label.new()
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD
	for l: Label in [_info, _people, _stock, _log]:
		view.add_child(l)


func _add_button(parent: Container, text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _next_day() -> void:
	_state.advance_day(RULES)
	_save()


func _scavenge() -> void:
	_state.add_stock(RULES.scavenge_haul)
	_refresh()
	_say(tr("Scavenged. Not saved until the next day or Save now."))


func _save() -> void:
	var err: String = _store.write(SaveCodec.encode(_state, BuildInfo.label()))
	_say(tr("Saved day %d.") % _state.clock.day if err.is_empty() else tr("Save failed: %s") % err)
	_refresh()


func _load() -> void:
	var result: SaveCodec.Result = _store.load_state()
	if result.state == null:
		_say(tr("Load failed: %s") % result.error)
		return
	_state = result.state
	_refresh()
	_say(tr("Loaded day %d.") % _state.clock.day if result.error.is_empty() else result.error)


func _export() -> void:
	_transfer.export_text(SaveCodec.encode(_state, BuildInfo.label()))
	_say(tr("Exported %s.") % SaveTransfer.FILE_NAME)


func _on_imported(text: String) -> void:
	var result: SaveCodec.Result = SaveCodec.decode(text)
	if result.state == null:
		_say(tr("Import failed: %s") % result.error)
		return
	_state = result.state
	_save()
	_say(tr("Imported and saved day %d.") % _state.clock.day)


func _new_game() -> void:
	_state = SimState.new_game(RULES, int(Time.get_unix_time_from_system()))
	_save()
	_say(tr("New game started and saved."))


func _refresh() -> void:
	var persistent: String = tr("yes") if OS.is_userfs_persistent() else tr("NO (private window or storage blocked)")
	_info.text = tr("Day %d, %02d:00  ·  seed %d\nStorage persistent: %s\nBuild %s") % [
		_state.clock.day, _state.clock.hour, _state.game_seed, persistent, BuildInfo.label()]
	var lines: PackedStringArray = []
	for s: Survivor in _state.survivors:
		lines.append(tr("%s  health %d  morale %d%s") % [s.name, roundi(s.health), roundi(s.morale),
			"" if s.is_alive() else tr("  (dead)")])
	_people.text = "\n".join(lines)
	lines = []
	for res: String in SimState.RESOURCES:
		lines.append("%s %.1f" % [tr(res.capitalize()), _state.stock.get(res, 0.0)])
	_stock.text = "  ·  ".join(lines)


func _say(message: String) -> void:
	_log.text = message
	print("save spike: ", message)
