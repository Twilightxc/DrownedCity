class_name AmmoPouch
extends RefCounted
## Loose rounds by caliber that a fighter carries (GDD §6 calibers). Guns reload from it.

var rounds: Dictionary[String, int] = {}


func count(caliber: String) -> int:
	return rounds.get(caliber, 0)


func add(caliber: String, n: int) -> void:
	rounds[caliber] = count(caliber) + n


## Takes up to `n` rounds; returns how many it got.
func take(caliber: String, n: int) -> int:
	var got: int = mini(n, count(caliber))
	rounds[caliber] = count(caliber) - got
	return got
