class_name Style15Level
extends Node3D
## Level art for the Style 1.5 look: swaps the generated .glb placeholder materials for the
## Style 1.5 shaders, publishes the water level as a global shader uniform, and feeds building
## footprints to the water shader (foam ring + shallow tint).
## Nodes in group "nav_obstacle" carry metadata/footprint (metres) for the spike's NavGrid.
## Nodes in group "floating" sit on the water line and get a lighter wet/algae tint, otherwise the
## whole prop would read as algae.

const SURFACE_MATERIAL: Material = preload("res://game/level/style15_surface.tres")
const EMISSIVE_MATERIAL: Material = preload("res://game/level/style15_emissive.tres")
const FLOATING_MATERIAL: Material = preload("res://game/level/style15_surface_floating.tres")
const MAX_FOOTPRINTS: int = 16

@export var water_level: float = -8.6
@export var water: MeshInstance3D


func _ready() -> void:
	RenderingServer.global_shader_parameter_set("water_level", water_level)
	_apply_materials(self, SURFACE_MATERIAL)
	for node: Node in get_tree().get_nodes_in_group("floating"):
		if is_ancestor_of(node):
			_apply_materials(node, FLOATING_MATERIAL)
	_publish_footprints()


func _apply_materials(root: Node, surface: Material) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi == water or mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(s)
			var mat_name: String = mat.resource_name if mat != null else ""
			if mat_name == "emissive":
				mi.set_surface_override_material(s, EMISSIVE_MATERIAL)
			elif mat_name == "surface":
				mi.set_surface_override_material(s, surface)


func _publish_footprints() -> void:
	if water == null:
		return
	var boxes: PackedVector4Array = PackedVector4Array()
	for node: Node in get_tree().get_nodes_in_group("water_footprint"):
		if boxes.size() >= MAX_FOOTPRINTS or not is_ancestor_of(node):
			continue
		var n3: Node3D = node as Node3D
		var fp: Vector2 = n3.get_meta("footprint", Vector2.ONE)
		boxes.append(Vector4(n3.global_position.x, n3.global_position.z, fp.x * 0.5, fp.y * 0.5))
	var count: int = boxes.size()
	boxes.resize(MAX_FOOTPRINTS)
	var mat: ShaderMaterial = water.get_active_material(0) as ShaderMaterial
	mat.set_shader_parameter("footprints", boxes)
	mat.set_shader_parameter("footprint_count", count)


## Nav obstacles under this level as NavGrid cell rects.
func nav_obstacle_rects(grid: NavGrid) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	for node: Node in get_tree().get_nodes_in_group("nav_obstacle"):
		if not is_ancestor_of(node):
			continue
		var n3: Node3D = node as Node3D
		var fp: Vector2 = n3.get_meta("footprint", Vector2.ONE)
		var yaw: float = wrapf(n3.global_rotation.y, 0.0, PI)
		if absf(yaw - PI * 0.5) < 0.4:
			fp = Vector2(fp.y, fp.x)
		var center: Vector2 = Vector2(n3.global_position.x, n3.global_position.z)
		var c0: Vector2i = grid.world_to_cell(center - fp * 0.5)
		var c1: Vector2i = grid.world_to_cell(center + fp * 0.5 - Vector2(0.001, 0.001))
		rects.append(Rect2i(c0, c1 - c0 + Vector2i.ONE))
	return rects
