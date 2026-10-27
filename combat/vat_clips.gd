class_name VatClips
extends Resource
## Clip table of a vertex animation texture, written by tools/blender/kit_zombie.py next to the
## two EXR textures (positions, normals). One texture row per frame, one column per mesh corner.

@export var mesh_name: String = ""
@export var fps: float = 24.0
@export var vertex_count: int = 0
@export var frame_count: int = 0
@export var names: PackedStringArray = PackedStringArray()
@export var start_row: PackedInt32Array = PackedInt32Array()
@export var frames: PackedInt32Array = PackedInt32Array()
@export var loops: PackedInt32Array = PackedInt32Array()
@export var stride: PackedFloat32Array = PackedFloat32Array()  ## metres per loop for walk clips, 0 = by time


func index_of(clip_name: String) -> int:
	return names.find(clip_name)


func duration(clip: int) -> float:
	return frames[clip] / fps


## Two texture rows and the blend between them, for a clip at `t`: seconds, or cycles when
## the clip loops (walk phase). One-shot clips hold their last frame.
func rows_at(clip: int, t: float) -> Vector3:
	var n: int = frames[clip]
	var f: float
	if loops[clip] != 0:
		f = fposmod(t, 1.0) * n
	else:
		f = clampf(t * fps, 0.0, n - 1.0)
	var f0: int = floori(f)
	var f1: int = (f0 + 1) % n if loops[clip] != 0 else mini(f0 + 1, n - 1)
	return Vector3(start_row[clip] + f0, start_row[clip] + f1, f - f0)
