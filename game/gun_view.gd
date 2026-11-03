class_name GunView
extends Node3D
## The gun in a fighter's hands (PHASE1 1.1 assets): the WeaponConfig's GunModel with each attachment's mesh
## on its mount, and its mag (an extended mag replaces it). Lives under the aim marker, so it turns with the
## aim; `muzzle_position()` is where the flash and casings come from. A reload hides the mag while the left
## hand swaps it (SurvivorView, 1.5+ A2).

const SURFACE_MATERIAL: Material = preload("res://game/level/style15_surface.tres")

var shown: Gun  ## the gun on display
var mag_node: Node3D  ## the loaded mag on the gun (or the extended mag); null for the shotgun
var _muzzle: Vector3 = Vector3(0.0, 0.0, 0.6)  ## local, after a silencer
var _parts: int = 0
var _hand_scene: PackedScene


func show_gun(gun: Gun) -> void:
	if gun == shown:
		return
	shown = gun
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	mag_node = null
	_parts = 0
	_hand_scene = null
	var model: GunModel = gun.config.model if gun != null else null
	if model == null or model.mesh_scene == null:
		_muzzle = Vector3(0.0, 0.0, 0.6)
		return
	add_child(model.mesh_scene.instantiate())
	_muzzle = model.muzzle
	_hand_scene = model.mag_hand_scene
	for a: AttachmentConfig in gun.attachments:
		if a.mesh_scene == null or not model.mounts.has(a.slot):
			continue
		var part: Node3D = a.mesh_scene.instantiate() as Node3D
		part.position = model.mounts[a.slot]
		add_child(part)
		_parts += 1
		_muzzle.z += a.muzzle_extend_m
		if a.slot == "mag":
			mag_node = part
			_hand_scene = a.mesh_scene
	if mag_node == null and model.mag_scene != null and model.mounts.has("mag"):
		mag_node = model.mag_scene.instantiate() as Node3D
		mag_node.position = model.mounts["mag"]
		add_child(mag_node)
	Style15Level.apply_materials(self, SURFACE_MATERIAL)


func muzzle_position() -> Vector3:
	return to_global(_muzzle)


## A point of the gun (its own space) in world space.
func point(local: Vector3) -> Vector3:
	return to_global(local)


func set_mag_visible(on: bool) -> void:
	if mag_node != null:
		mag_node.visible = on


## What the left hand holds in a reload: a full mag (the extended one if fitted) or a shell.
func hand_item_scene() -> PackedScene:
	return _hand_scene


## Attachment meshes on show (tests).
func part_count() -> int:
	return _parts
