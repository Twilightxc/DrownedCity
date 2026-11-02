class_name GasFx
extends Node3D
## Draws a GasField: a few low-poly puffs per cloud in one MultiMesh (one draw call), breathing slowly and
## fading out over the cloud's last two seconds. Yellow-green so it reads as toxic at a glance (pillar 5).

const PUFFS: int = 7  ## per cloud
const COLOR: Color = Color(0.62, 0.72, 0.22, 0.42)

var ground_y: float = 0.0
var gas: GasField

var _mm: MultiMesh
var _time: float = 0.0


func _ready() -> void:
	var puff: SphereMesh = SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 8
	puff.rings = 4
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	puff.surface_set_material(0, mat)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = puff
	_mm.instance_count = GasField.CAP * PUFFS
	_mm.visible_instance_count = 0
	var layer: MultiMeshInstance3D = MultiMeshInstance3D.new()
	layer.multimesh = _mm
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.custom_aabb = AABB(Vector3(-500, -20, -500), Vector3(1000, 40, 1000))
	add_child(layer)


func _process(delta: float) -> void:
	_time += minf(delta, 1.0 / 20.0)
	if gas == null:
		_mm.visible_instance_count = 0
		return
	var n: int = 0
	for i: int in gas.count():
		var c: Vector2 = gas.centers[i]
		var r: float = gas.radii[i]
		var fade: float = clampf(gas.life[i] / 2.0, 0.0, 1.0)
		var grow: float = clampf((gas.total[i] - gas.life[i]) / 0.6, 0.2, 1.0)  # puffs out in 0.6 s
		for k: int in PUFFS:
			var a: float = k * TAU / PUFFS + i * 1.3
			var d: float = 0.0 if k == 0 else r * 0.55
			var breathe: float = 1.0 + 0.08 * sin(_time * 1.7 + k * 2.1 + i)
			var s: float = r * (0.9 if k == 0 else 0.65) * grow * breathe
			var p: Vector3 = Vector3(c.x + cos(a) * d, ground_y + 0.35 + 0.15 * (k % 3), c.y + sin(a) * d)
			_mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3(s, s * 0.55, s)), p))
			_mm.set_instance_color(n, Color(COLOR, COLOR.a * fade))
			n += 1
	_mm.visible_instance_count = n
