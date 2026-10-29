extends "res://game/spikes/horde_spike.gd"
## Spike F (Phase 0.8): walk into the base building through the roof hatch and move between its storeys
## with the cutaway camera (part 1). Part 2: dormant zombies on every walkable storey wake by noise, sight
## or an awake neighbour and follow the player across storeys; rooms stay dark until seen, and the player
## carries a flashlight inside. Spike B scene and player; the roof horde
## starts empty (raise it with ]) and waits while the player is inside.

@export var interior_seed: int = 7
@export var interior_horde: InteriorHordeConfig = preload("res://data/combat/interior_horde.tres")
@export var interior_light: InteriorLightConfig = preload("res://data/fx/interior_light.tres")

var _interior: InteriorController
var _inside: InteriorHordes
var _lighting: InteriorLighting
var _inside_ms: float = 0.0


func _ready() -> void:
	super._ready()
	_target_count = 0
	_count_label.text = "Horde target: 0   ([ / ], D-pad left/right) · roof zombies wait while you're inside"
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
	_inside = InteriorHordes.new()
	add_child(_inside)
	_inside.setup(_interior.layout, interior_horde, horde_config, _renderer.models, fire_config, _rng.randi())
	_lighting = InteriorLighting.new()
	add_child(_lighting)
	_lighting.setup(_interior.layout, interior_light)
	_interior.storey_changed.connect(_on_storey_changed)
	_player.fired.connect(func(_from: Vector3, _to: Vector3) -> void:
		if _interior.storey >= 0:
			_inside.noise(_player.ground_position(), _interior.storey, interior_horde.shot_noise))
	if _grenades != null:
		_grenades.exploded.connect(func(at: Vector3, _k: int, _cfg: ThrowableConfig) -> void:
			if _interior.storey >= 0:
				_inside.noise(Vector2(at.x, at.z), _interior.storey, interior_horde.blast_noise))
	# Start inside on a storey (0 = lowest): `-- --storey=2`, or `&storey=2` on the web.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		args = str(JavaScriptBridge.eval("window.location.search", true)).trim_prefix("?").split("&", false)
	for arg: String in args:
		var kv: String = arg.trim_prefix("--")
		if kv.begins_with("storey="):
			_interior.call_deferred("_go", int(kv.trim_prefix("storey=")), _interior.call("_top_landing"))
		elif kv == "wake=1":  # every zombie inside starts awake (measurements)
			for h: Horde in _inside.hordes:
				if h != null:
					h.dormant.fill(0)


func _process(delta: float) -> void:
	var dt: float = minf(delta, 1.0 / 20.0)
	var t0: int = Time.get_ticks_usec()
	_inside.step(dt, _interior.storey, _player.ground_position())
	_inside.sync(_interior.storey)
	_lighting.step(dt, _interior.storey, _player.position, _player.aim_dir)
	_inside_ms = lerpf(_inside_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.1)
	super._process(delta)
	# Only the player's storey feeds gore; zombies elsewhere can't be hit, and their events are dropped.
	for h: Horde in _inside.hordes:
		if h != null and h != _fx_horde:
			h.clear_events()
	DebugOverlay.set_stat("storey", "roof" if _interior.storey < 0 else "%d of %d" % [_interior.storey + 1, _interior.storeys])
	DebugOverlay.set_stat("zombies_inside", "%d (%d awake)" % [_inside.total_count(), _inside.awake_count()])
	DebugOverlay.set_stat("inside_update", "%.2f ms" % _inside_ms)
	if _interior.storey >= 0:
		DebugOverlay.set_stat("rooms_seen", "%d / %d" % [_lighting.seen_count(_interior.storey), _lighting.region_total(_interior.storey)])


## Shots, grenades, blood, corpses and flames follow the player onto the storey's floor and horde.
func _on_storey_changed(s: int) -> void:
	var inside: bool = s >= 0
	var h: Horde = _inside.horde_at(s) if inside else _horde
	var floor_y: float = _interior.layout.floor_y(s) if inside else GROUND_Y
	var grid: NavGrid = _inside.grids[s] if inside else _grid
	if h == null:
		h = _horde  # a flooded storey: nothing walks there
	_roof_paused = inside
	_renderer.visible = not inside
	_player.horde = h
	_fx_horde = h
	if _grenades != null:
		_grenades.horde = h
		_grenades.ground_fire = null if inside else _ground_fire
	if _corpses != null:
		_corpses.clear()
		_corpses.grid = grid
		_corpses.ground_y = floor_y
		_blood.clear()
		_blood.ground_y = floor_y
	if _explosions != null:
		_explosions.ground_y = floor_y
		_explosions.grid = grid
	if _fire_fx != null:
		_fire_fx.ground_y = floor_y


func _help_text(pad: bool) -> String:
	var key: String = "A" if pad else "F"
	return super._help_text(pad) + "\nRoof hatch by the hut or rope at the south edge: %s · stairs at the corridor's west end" % key
