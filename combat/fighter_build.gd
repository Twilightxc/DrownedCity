class_name FighterBuild
extends RefCounted
## A survivor's build (SimCore BuildRules.mods: skills, background, traits, status, class, needs) turned into the
## numbers a fighter uses (CITIZENS_1_6 §8). Each one takes the config's base and returns it with the build on;
## FighterBuild.new() with no survivor changes nothing, so fighters without one play as before.
## Aim sway has no system of its own yet: the spread model is the only aim error, so `sway` scales spread too.

var mods: StatMods


func _init(m: StatMods = null) -> void:
	mods = m if m != null else StatMods.new()


func hp(base: int) -> int:
	return maxi(roundi(mods.apply(&"max_hp", float(base))), 1)


func stamina_max(base: float) -> float:
	return mods.apply(&"max_stamina", base)


func stamina_regen(base: float) -> float:
	return mods.apply(&"stamina_regen", base)


func sprint_cost(base: float) -> float:
	return mods.apply(&"sprint_stamina", base)


func roll_cost(base: float) -> float:
	return mods.apply(&"dodge_stamina", base)


func step_noise(base: float) -> float:
	return mods.apply(&"step_noise", base)


## × how fast this fighter gets a downed squad member up (Medic: 2×).
func revive_rate() -> float:
	return maxf(mods.apply(&"revive_speed", 1.0), 0.05)


func melee_taken() -> float:
	return mods.apply(&"melee_damage_taken", 1.0)


func gas_taken() -> float:
	return mods.apply(&"gas_damage", 1.0)


func self_blast() -> float:
	return mods.apply(&"self_blast_damage", 1.0)


func extra_grenades() -> int:
	return roundi(mods.apply(&"grenades_carried", 0.0))


# Guns, by WeaponConfig.weapon_class (Steady Hands only steadies some classes).

func spread(weapon_class: String) -> float:
	return mods.apply_for(&"spread", weapon_class, 1.0) * mods.apply_for(&"sway", weapon_class, 1.0)


func recoil(weapon_class: String) -> float:
	return mods.apply_for(&"recoil", weapon_class, 1.0)


## × the reload time: a faster reload is a shorter one.
func reload_time(weapon_class: String) -> float:
	return 1.0 / maxf(mods.apply_for(&"reload_speed", weapon_class, 1.0), 0.05)


func wear(weapon_class: String) -> float:
	return mods.apply_for(&"wear_per_shot", weapon_class, 1.0)


func rpm(weapon_class: String) -> float:
	return maxf(mods.apply_for(&"rpm", weapon_class, 1.0), 0.05)
