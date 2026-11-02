class_name GasField
extends RefCounted
## Toxic clouds left by Bloaters (GDD §9): a capped list of discs that thin out and vanish. Pure data; the
## player's damage (survivors without a mask) reads `strength_at` from step 1.3 on.

const CAP: int = 6  ## clouds at once; a new one replaces the oldest

var centers: PackedVector2Array = PackedVector2Array()
var radii: PackedFloat32Array = PackedFloat32Array()
var life: PackedFloat32Array = PackedFloat32Array()  ## s left
var total: PackedFloat32Array = PackedFloat32Array()  ## s at the start


func add(at: Vector2, radius: float, seconds: float) -> void:
	if centers.size() >= CAP:
		var oldest: int = 0
		for i: int in life.size():
			if life[i] < life[oldest]:
				oldest = i
		_remove(oldest)
	centers.append(at)
	radii.append(radius)
	life.append(seconds)
	total.append(seconds)


func count() -> int:
	return centers.size()


func update(delta: float) -> void:
	for i: int in range(life.size() - 1, -1, -1):
		life[i] -= delta
		if life[i] <= 0.0:
			_remove(i)


## 0 outside every cloud .. 1 at a fresh cloud's centre (the strongest cloud wins).
func strength_at(p: Vector2) -> float:
	var best: float = 0.0
	for i: int in centers.size():
		var d: float = p.distance_to(centers[i])
		if d < radii[i]:
			best = maxf(best, (1.0 - d / radii[i]) * clampf(life[i] / minf(total[i], 2.0), 0.0, 1.0))
	return best


func _remove(i: int) -> void:
	centers.remove_at(i)
	radii.remove_at(i)
	life.remove_at(i)
	total.remove_at(i)
