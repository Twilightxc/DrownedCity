class_name ScreenShake
extends RefCounted
## Trauma-based camera shake (Phase 1 step 1.4): events add trauma (0..1), it decays every second, and the
## offset grows with trauma² so small taps stay subtle. Smooth pseudo-noise from summed sines, no texture.

var trauma: float = 0.0
var _t: float = 0.0


func add(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Advances `delta` seconds and returns the camera offset (x, y in screen space) in metres.
func step(delta: float, decay: float, max_m: float) -> Vector2:
	_t += delta
	trauma = maxf(trauma - decay * delta, 0.0)
	var k: float = trauma * trauma * max_m
	var x: float = sin(_t * 37.0) * 0.6 + sin(_t * 59.0 + 1.7) * 0.4
	var y: float = sin(_t * 43.0 + 0.9) * 0.6 + sin(_t * 71.0 + 2.3) * 0.4
	return Vector2(x, y) * k
