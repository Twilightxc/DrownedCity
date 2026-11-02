class_name CasingFx
extends Node3D
## Spent casings (Phase 1 step 1.4): a ring buffer drawn by one MultiMesh. Each casing flies out to the
## right of the gun, tumbles, bounces once on the floor and lies there until it shrinks away.

const CAP: int = 96
const GRAVITY: float = 12.0

var life_sec: float = 6.0

var _mm: MultiMesh
var _pos: PackedVector3Array
var _vel: PackedVector3Array
var _spin: PackedFloat32Array
var _age: PackedFloat32Array  ## < 0 = free
var _bounced: PackedByteArray
var _color: PackedColorArray
var _floor: PackedFloat32Array  ## each casing's floor (storeys inside buildings)
var _next: int = 0


func _ready() -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.035, 0.035, 0.09)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.6
	mat.roughness = 0.4
	box.surface_set_material(0, mat)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = box
	_mm.instance_count = CAP
	_mm.visible_instance_count = 0
	var layer: MultiMeshInstance3D = MultiMeshInstance3D.new()
	layer.multimesh = _mm
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.custom_aabb = AABB(Vector3(-500, -20, -500), Vector3(1000, 40, 1000))
	add_child(layer)
	_pos.resize(CAP)
	_vel.resize(CAP)
	_spin.resize(CAP)
	_age.resize(CAP)
	_age.fill(-1.0)
	_bounced.resize(CAP)
	_color.resize(CAP)
	_floor.resize(CAP)


## Ejects one casing at `at`, out to the right of `aim` (world XZ), landing on `floor_y`; shotgun shells are red.
func eject(at: Vector3, aim: Vector2, shell: bool, floor_y: float) -> void:
	var i: int = _next
	_next = (_next + 1) % CAP
	var right: Vector2 = Vector2(-aim.y, aim.x)  # right of the aim on screen in this iso view
	var side: float = randf_range(1.6, 2.6)
	_pos[i] = at
	_vel[i] = Vector3(right.x * side - aim.x * 0.4, randf_range(2.0, 3.2), right.y * side - aim.y * 0.4)
	_spin[i] = randf() * TAU
	_age[i] = 0.0
	_bounced[i] = 0
	_floor[i] = floor_y + 0.02
	_color[i] = Color(0.75, 0.16, 0.12) if shell else Color(0.86, 0.66, 0.3)


func live_count() -> int:
	return _mm.visible_instance_count


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 20.0)
	var n: int = 0
	for i: int in CAP:
		if _age[i] < 0.0:
			continue
		_age[i] += delta
		if _age[i] >= life_sec:
			_age[i] = -1.0
			continue
		var p: Vector3 = _pos[i]
		var v: Vector3 = _vel[i]
		var floor_y: float = _floor[i]
		if p.y > floor_y or v.y > 0.0:
			v.y -= GRAVITY * delta
			p += v * delta
			_spin[i] += delta * 18.0
			if p.y <= floor_y:
				p.y = floor_y
				if _bounced[i] == 0:
					_bounced[i] = 1
					v = Vector3(v.x * 0.4, -v.y * 0.3, v.z * 0.4)
				else:
					v = Vector3.ZERO
			_pos[i] = p
			_vel[i] = v
		var s: float = clampf((life_sec - _age[i]) / 1.0, 0.0, 1.0)
		var tumble: float = _spin[i] * 0.7 if v != Vector3.ZERO else PI * 0.5  # lies flat once still
		var b: Basis = Basis(Vector3.UP, _spin[i]) * Basis(Vector3.RIGHT, tumble)
		_mm.set_instance_transform(n, Transform3D(b.scaled(Vector3.ONE * s), p))
		_mm.set_instance_color(n, _color[i])
		n += 1
	_mm.visible_instance_count = n
