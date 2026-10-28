class_name FireFx
extends Node3D
## Flames for burning zombies and burning ground cells (GDD §6): one shared MultiMesh of additive
## billboard quads, no particle node per zombie. The zombie's own glow is the horde shader flag; these
## are the tongues of flame above it, capped and flickered on the CPU.

const FLAME_CAP: int = 96
const CELL_FLAMES: int = 3  ## quads per burning cell
const SPOT_SCALE: float = 0.5  ## a spot fire's flame against a whole-body one
## Rough standing position of each part (kit_zombie SKELETON order): (sideways m, height m).
const SPOT_OFFSET: PackedVector2Array = [
	Vector2(0.0, 0.9), Vector2(0.0, 1.2), Vector2(0.0, 1.6), Vector2(0.22, 1.3), Vector2(0.24, 1.0),
	Vector2(-0.22, 1.3), Vector2(-0.24, 1.0), Vector2(0.1, 0.7), Vector2(0.1, 0.3), Vector2(-0.1, 0.7),
	Vector2(-0.1, 0.3),
]

var ground_y: float = 0.0

var _flames: MultiMeshInstance3D
var _time: float = 0.0
var _warm_frames: int = 0


func _ready() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.45, 0.7)
	quad.center_offset = Vector3(0, 0.35, 0)
	var mat: StandardMaterial3D = flame_material(true)
	mat.albedo_color = Color(1.0, 0.5, 0.12, 0.85)
	quad.surface_set_material(0, mat)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = FLAME_CAP
	mm.visible_instance_count = 0
	_flames = MultiMeshInstance3D.new()
	_flames.multimesh = mm
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flames.custom_aabb = AABB(Vector3(-500, -20, -500), Vector3(1000, 40, 1000))
	add_child(_flames)


## Unshaded upright billboard with a soft flame-shaped glow (bright low centre, fading up and out), so
## quads don't read as squares. Shared by the zombie/cell flames and the blast embers.
static func flame_material(additive: bool) -> StandardMaterial3D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.8))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.width = 32
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.72)  # texture v grows downward: the hot core sits low
	tex.fill_to = Vector2(0.5, 0.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.albedo_texture = tex
	return mat


## One flame for one frame at load, so the additive material compiles before the first fire.
func warm_up(at: Vector3) -> void:
	var mm: MultiMesh = _flames.multimesh
	mm.set_instance_transform(0, Transform3D(Basis().scaled(Vector3(0.01, 0.01, 0.01)), at))
	mm.visible_instance_count = 1
	_warm_frames = 3


func flame_count() -> int:
	return _flames.multimesh.visible_instance_count


## Writes this frame's flames: burning cells first (they're few), then burning zombies up to the cap.
func sync(delta: float, horde: Horde, fire: GroundFire) -> void:
	_time += minf(delta, 1.0 / 20.0)
	var mm: MultiMesh = _flames.multimesh
	if _warm_frames > 0:
		_warm_frames -= 1
		return
	var n: int = 0
	if fire != null:
		var grid: NavGrid = fire.grid
		for i: int in fire.active_cells():
			var c: Vector2 = grid.cell_center(grid.cell_of_index(i))
			for k: int in CELL_FLAMES:
				if n >= FLAME_CAP:
					break
				var off: Vector2 = Vector2(sin(i * 3.1 + k * 2.1), cos(i * 1.7 + k * 2.9)) * 0.3
				var s: float = 1.1 + 0.35 * sin(_time * 13.0 + i + k * 2.0)
				mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(c.x + off.x, ground_y, c.y + off.y)))
				n += 1
	if horde != null:
		for a: int in horde.count:
			if n >= FLAME_CAP:
				break
			if horde.burn_left[a] <= 0.0:
				continue
			var p: Vector2 = horde.positions[a]
			var spot: int = horde.burn_spot[a]
			var s: float = 0.9 + 0.3 * sin(_time * 15.0 + a * 1.3)
			var at: Vector3 = Vector3(p.x, ground_y + 0.9, p.y)
			if spot != 0:
				# A small tongue on the burning part, turned with the zombie's facing.
				var off: Vector2 = SPOT_OFFSET[spot - 1]
				var side: Vector2 = Vector2(-horde.heading[a].y, horde.heading[a].x)
				at = Vector3(p.x + side.x * off.x, ground_y + off.y, p.y + side.y * off.x)
				s *= SPOT_SCALE
			mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3(s, s, s)), at))
			n += 1
	mm.visible_instance_count = n
