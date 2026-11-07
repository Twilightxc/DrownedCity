class_name StatMods
extends RefCounted
## A survivor's modifiers summed per stat (GDD §3, CITIZENS_1_6 §8): flat adds and fractional muls, plus perks
## (effects without a number). A stat reads as (base + add) × (1 + mul), never below 0. Stats are names
## ("max_stamina", "sway"); a stat whose system doesn't exist yet is kept but nothing reads it.

var add: Dictionary[StringName, float] = {}
var mul: Dictionary[StringName, float] = {}
var perks: Dictionary[StringName, bool] = {}


## `op` is "add" or "mul" (data/sim/skills.json).
func push(stat: StringName, op: String, value: float) -> void:
	if value == 0.0:
		return
	if op == "mul":
		mul[stat] = mul.get(stat, 0.0) + value
	else:
		add[stat] = add.get(stat, 0.0) + value


func grant(perk: StringName) -> void:
	perks[perk] = true


func has_perk(perk: StringName) -> bool:
	return perks.has(perk)


## The stat with every modifier on: (base + add) × (1 + mul), floored at 0.
func apply(stat: StringName, base: float) -> float:
	return maxf((base + add.get(stat, 0.0)) * (1.0 + mul.get(stat, 0.0)), 0.0)


## Every stat any modifier touches.
func stats() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: StringName in add:
		out.append(s)
	for s: StringName in mul:
		if not add.has(s):
			out.append(s)
	return out
