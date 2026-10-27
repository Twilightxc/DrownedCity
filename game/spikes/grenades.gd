class_name Grenades
extends Node3D
## Thrown grenades for the spikes: a lobbed arc, then a blast that damages every zombie in
## radius through the horde's spatial hash. A handful in flight at most, so one node each.

signal exploded(at: Vector3, killed: int)

const FLASH_TIME: float = 0.25


class Flight:
	var config: ThrowableConfig
	var from: Vector3
	var to: Vector3
	var t: float = 0.0
	var node: MeshInstance3D


class Flash:
	var node: MeshInstance3D
	var material: StandardMaterial3D
	var radius: float
	var age: float = 0.0


var horde: Horde

var _flying: Array[Flight] = []
var _flashes: Array[Flash] = []
var _hits: PackedInt32Array = PackedInt32Array()
var _ball_mesh: SphereMesh
var _flash_mesh: SphereMesh


func _ready() -> void:
	var ball_mat: StandardMaterial3D = StandardMaterial3D.new()
	ball_mat.albedo_color = Color(0.25, 0.3, 0.2)
	_ball_mesh = SphereMesh.new()
	_ball_mesh.radius = 0.12
	_ball_mesh.height = 0.24
	_ball_mesh.radial_segments = 8
	_ball_mesh.rings = 4
	_ball_mesh.material = ball_mat
	_flash_mesh = SphereMesh.new()
	_flash_mesh.radius = 1.0
	_flash_mesh.height = 2.0
	_flash_mesh.radial_segments = 16
	_flash_mesh.rings = 8


func in_flight() -> int:
	return _flying.size()


func throw(config: ThrowableConfig, from: Vector3, to: Vector3) -> void:
	var f: Flight = Flight.new()
	f.config = config
	f.from = from
	f.to = to
	f.node = MeshInstance3D.new()
	f.node.mesh = _ball_mesh
	f.node.position = from
	add_child(f.node)
	_flying.append(f)


func _process(delta: float) -> void:
	var i: int = _flying.size() - 1
	while i >= 0:
		var f: Flight = _flying[i]
		f.t = minf(f.t + delta / f.config.flight_time, 1.0)
		f.node.position = f.from.lerp(f.to, f.t) + Vector3.UP * (4.0 * f.config.arc_height * f.t * (1.0 - f.t))
		if f.t >= 1.0:
			f.node.queue_free()
			_flying.remove_at(i)
			_explode(f.config, f.to)
		i -= 1
	_update_flashes(delta)


func _explode(cfg: ThrowableConfig, at: Vector3) -> void:
	var killed: int = 0
	if horde != null:
		# Bullets may have swap-removed agents since the crowd step; re-index before the query.
		horde.spatial.rebuild(horde.positions, horde.count)
		_hits.clear()
		horde.spatial.query_radius(horde.positions, Vector2(at.x, at.z), cfg.blast_radius, _hits)
		killed = horde.apply_damage(_hits, cfg.damage, Vector2(at.x, at.z), true)
	var fl: Flash = Flash.new()
	fl.radius = cfg.blast_radius
	fl.material = StandardMaterial3D.new()
	fl.material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fl.material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fl.material.albedo_color = Color(1.0, 0.75, 0.35, 0.8)
	fl.node = MeshInstance3D.new()
	fl.node.mesh = _flash_mesh
	fl.node.material_override = fl.material
	fl.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fl.node.position = at
	add_child(fl.node)
	_flashes.append(fl)
	exploded.emit(at, killed)


func _update_flashes(delta: float) -> void:
	var i: int = _flashes.size() - 1
	while i >= 0:
		var fl: Flash = _flashes[i]
		fl.age += delta
		if fl.age >= FLASH_TIME:
			fl.node.queue_free()
			_flashes.remove_at(i)
		else:
			var k: float = fl.age / FLASH_TIME
			fl.node.scale = Vector3.ONE * fl.radius * lerpf(0.3, 1.0, k)
			fl.material.albedo_color.a = 0.8 * (1.0 - k)
		i -= 1
