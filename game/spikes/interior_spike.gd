extends "res://game/spikes/horde_spike.gd"
## Spike F (Phase 0.8) part 1: walk into the base building through the roof hatch and move between its
## storeys with the cutaway camera. Spike B scene and player; the horde starts empty (raise it with ] —
## zombies stay on the roof until part 2 puts them inside).

@export var interior_seed: int = 7

var _interior: InteriorController


func _ready() -> void:
	super._ready()
	_target_count = 0
	_count_label.text = "Horde target: 0   ([ / ], D-pad left/right) · zombies stay on the roof in part 1"
	var level: Node = null
	for child: Node in get_children():
		if child is Style15Level:
			level = child
	var exterior: Array[Node] = []
	if level != null:
		for name: String in ["BaseBuilding", "Props", "RoofHut"]:
			var n: Node = level.get_node_or_null(name)
			if n != null:
				exterior.append(n)
	_interior = InteriorController.new()
	_interior.layout_seed = interior_seed
	add_child(_interior)
	_interior.setup(_player, _camera, _grid, GROUND_Y, exterior)
	# Start inside on a storey (0 = lowest): `-- --storey=2`, or `&storey=2` on the web.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		args = str(JavaScriptBridge.eval("window.location.search", true)).trim_prefix("?").split("&", false)
	for arg: String in args:
		var kv: String = arg.trim_prefix("--")
		if kv.begins_with("storey="):
			_interior.call_deferred("_go", int(kv.trim_prefix("storey=")), _interior.call("_top_landing"))


func _process(delta: float) -> void:
	super._process(delta)
	DebugOverlay.set_stat("storey", "roof" if _interior.storey < 0 else "%d of %d" % [_interior.storey + 1, _interior.storeys])


func _help_text(pad: bool) -> String:
	var extra: String = "\nRoof hatch by the hut: A to go down · stairs at the corridor's west end"
	if not pad:
		extra = "\nRoof hatch by the hut: F to go down · stairs at the corridor's west end"
	return super._help_text(pad) + extra
