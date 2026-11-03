class_name GunView
extends Node3D
## The gun in a fighter's hands (PHASE1 1.1 assets): the WeaponConfig's GunModel with each attachment's mesh
## on its mount. Lives under the aim marker, so it turns with the aim; `muzzle_position()` is where the
## flash and casings come from.

const SURFACE_MATERIAL: Material = preload("res://game/level/style15_surface.tres")

var shown: Gun  ## the gun on display
var _muzzle: Vector3 = Vector3(0.0, 0.0, 0.6)  ## local, after a silencer


func show_gun(gun: Gun) -> void:
	if gun == shown:
		return
	shown = gun
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var model: GunModel = gun.config.model if gun != null else null
	if model == null or model.mesh_scene == null:
		_muzzle = Vector3(0.0, 0.0, 0.6)
		return
	add_child(model.mesh_scene.instantiate())
	_muzzle = model.muzzle
	for a: AttachmentConfig in gun.attachments:
		if a.mesh_scene == null or not model.mounts.has(a.slot):
			continue
		var part: Node3D = a.mesh_scene.instantiate() as Node3D
		part.position = model.mounts[a.slot]
		add_child(part)
		_muzzle.z += a.muzzle_extend_m
	Style15Level.apply_materials(self, SURFACE_MATERIAL)


func muzzle_position() -> Vector3:
	return to_global(_muzzle)


## Attachment meshes on show (tests).
func part_count() -> int:
	return maxi(get_child_count() - 1, 0)
