class_name WeaponConfig
extends Resource
## One gun (GDD §6 stat schema). Instances live in data/weapons/*.tres. A carried gun's state (magazine,
## mode, wear, jams) is a `Gun`; attachments change the numbers through `AttachmentConfig`.

enum FireMode { SEMI, AUTO, BURST }
enum Armor { NONE, L, M, H }  ## armor_pen against a target's armor or cover (GDD §6 table)

@export var display_name: String = "Weapon"
@export var weapon_class: String = "ar"  ## pistol · smg · ar · rifle · sniper · shotgun · lmg (traits key on it)
@export var caliber: String = "5.56"  ## ammo type: 9mm · .45 · 5.56 · 7.62 · .308 · 12g · 40mm · fuel

@export_group("Damage")
@export var damage: int = 34  ## per bullet (per pellet for shotguns)
@export var pellets: int = 1
@export var body_pen: int = 1  ## bodies one bullet can hit; each one passed takes 20 % off the next hit
@export var armor_pen: Armor = Armor.L
@export var stagger_sec: float = 0.0  ## a hit target stands still this long (on top of the hit slow)
@export var knockback: float = 0.0  ## m/s shove along the bullet per hit (per pellet), fading fast
@export var range_m: float = 40.0
@export var falloff_start_m: float = 20.0  ## full damage up to here, then down to falloff_min at range_m
@export var falloff_min: float = 0.6

@export_group("Handling")
@export var rpm: float = 600.0
@export var modes: Array[FireMode] = [FireMode.AUTO]  ## first = default; more than one: "fire_mode" cycles
@export var burst_count: int = 3
@export var burst_spread_mul: float = 0.7  ## burst is tighter (GDD: AR burst spread −30 %)
@export var burst_pause_sec: float = 0.25  ## after a burst before the next one
@export var spread_deg: float = 1.5  ## ± half-angle at rest
@export var recoil_deg: float = 0.4  ## spread added per shot (bloom)
@export var recoil_max_deg: float = 5.0
@export var recoil_recover_deg: float = 10.0  ## per second when not firing
@export var mag: int = 30
@export var reload_sec: float = 2.4  ## whole magazine, or one round if reload_per_round
@export var reload_per_round: bool = false  ## pump shotgun: one shell at a time, firing interrupts

@export_group("Noise and wear")
@export var noise_m: float = 40.0  ## sleepers this close hear a shot (GDD §9 perception)
@export var weight_kg: float = 3.5
@export var wear_per_shot: float = 0.05  ## durability % lost per shot
@export var jam_below: float = 50.0  ## durability % under which jams start
@export var jam_chance_max: float = 0.08  ## per shot at 0 % durability
@export var waterproof: bool = false
@export var attachment_slots: PackedStringArray = PackedStringArray(["muzzle", "optic", "under", "mag"])
@export var model: GunModel  ## mesh + mount points from tools/blender/kit_guns.py; null = the placeholder barrel

@export_group("Sound")
@export var shot_sfx: StringName = &"shot_ar"  ## SfxBank event; heard up to noise_m away
@export var reload_sfx: StringName = &"reload_rifle"  ## per round for reload_per_round guns
@export var cycle_sfx: StringName = &""  ## after each shot (pump action); empty = none
@export var cycle_delay_sec: float = 0.35
