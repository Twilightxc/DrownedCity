class_name KillChain
extends RefCounted
## Kill combo (GDD §6 "Boxhead part"): kills within `window` of the last one extend the chain; each kill
## scores the chain length at that moment, up to `score_cap` (a long chain pays ×10, not ×400). The score
## becomes influence after a horde night (1.10). Pure data: feed it kills and time.

var window: float = 2.0
var score_cap: int = 10
var chain: int = 0
var best: int = 0
var score: int = 0
var _left: float = 0.0


func _init(window_sec: float = 2.0, cap: int = 10) -> void:
	window = window_sec
	score_cap = cap


func add_kills(n: int) -> void:
	for i: int in n:
		chain += 1
		score += mini(chain, score_cap)
	if n > 0:
		best = maxi(best, chain)
		_left = window


func step(delta: float) -> void:
	if chain == 0:
		return
	_left -= delta
	if _left <= 0.0:
		chain = 0


## 1 just after a kill, falling to 0 when the chain breaks (for the HUD).
func freshness() -> float:
	return clampf(_left / window, 0.0, 1.0) if chain > 0 else 0.0
