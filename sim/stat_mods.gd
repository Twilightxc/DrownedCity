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


## Only for guns of these classes (GDD §3: Steady Hands is spread −20 % for pistols, rifles and snipers).
## Kept under "stat@class"; apply_for() adds them to the general ones.
func push_for(stat: StringName, op: String, value: float, classes: PackedStringArray) -> void:
	if classes.is_empty():
		push(stat, op, value)
		return
	for c: String in classes:
		push(StringName("%s@%s" % [stat, c]), op, value)


## The stat with every modifier on: (base + add) × (1 + mul), floored at 0.
func apply(stat: StringName, base: float) -> float:
	return maxf((base + add.get(stat, 0.0)) * (1.0 + mul.get(stat, 0.0)), 0.0)


## apply() for a gun of `weapon_class`: the general modifiers plus that class's own.
func apply_for(stat: StringName, weapon_class: String, base: float) -> float:
	var key: StringName = StringName("%s@%s" % [stat, weapon_class])
	var a: float = add.get(stat, 0.0) + add.get(key, 0.0)
	var m: float = mul.get(stat, 0.0) + mul.get(key, 0.0)
	return maxf((base + a) * (1.0 + m), 0.0)


## Adds `other`'s modifiers, scaled (an outstanding citizen's skill works base-wide at 0.5). Perks come along only
## at full strength.
func absorb(other: StatMods, scale: float = 1.0) -> void:
	for s: StringName in other.add:
		add[s] = add.get(s, 0.0) + other.add[s] * scale
	for s: StringName in other.mul:
		mul[s] = mul.get(s, 0.0) + other.mul[s] * scale
	if scale >= 1.0:
		for p: StringName in other.perks:
			perks[p] = true


## Every stat any modifier touches.
func stats() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: StringName in add:
		out.append(s)
	for s: StringName in mul:
		if not add.has(s):
			out.append(s)
	return out
