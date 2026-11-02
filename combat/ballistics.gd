class_name Ballistics
extends RefCounted
## Damage rules for one bullet (GDD §6), pure functions so they are unit-tested against the GDD tables.

const BODY_PEN_LOSS: float = 0.2  ## each body a bullet passed through takes this off the next hit


## Distance falloff: 1 up to `start`, then down to `min_mul` at `range_m` (and beyond).
static func falloff(distance: float, start: float, range_m: float, min_mul: float) -> float:
	if distance <= start or range_m <= start:
		return 1.0
	return lerpf(1.0, min_mul, clampf((distance - start) / (range_m - start), 0.0, 1.0))


## Multiplier for the `index`-th body along the bullet (0 = first).
static func body_mul(index: int) -> float:
	return pow(1.0 - BODY_PEN_LOSS, index)


## armor_pen against armor or cover: lower ×0.25 (and the bullet stops), equal ×0.75, higher ×1.
## Unarmored targets always take full damage.
static func armor_mul(pen: int, armor: int) -> float:
	if armor == WeaponConfig.Armor.NONE or pen > armor:
		return 1.0
	return 0.75 if pen == armor else 0.25


static func stops_bullet(pen: int, armor: int) -> bool:
	return armor != WeaponConfig.Armor.NONE and pen < armor


static func hit_damage(base: float, distance: float, index: int, armor: int, cfg: WeaponConfig) -> int:
	var d: float = base * falloff(distance, cfg.falloff_start_m, cfg.range_m, cfg.falloff_min) \
		* body_mul(index) * armor_mul(cfg.armor_pen, armor)
	return maxi(roundi(d), 1)


## Sustained DPS against one target, every round hits, reload included (how GDD §6 sets its numbers).
static func sustained_dps(cfg: WeaponConfig) -> float:
	var shots: float = cfg.mag / (cfg.rpm / 60.0)
	var reload: float = cfg.reload_sec * (cfg.mag if cfg.reload_per_round else 1)
	return cfg.damage * cfg.pellets * cfg.mag / (shots + reload)
