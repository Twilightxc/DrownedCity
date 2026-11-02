# Phase 1 results

Measured numbers and J's verdicts per milestone (plan: `docs/PHASE1.md`). Device/browser on every row; J's Arc
laptop is the pass/fail reference. New rows go at the top of each section.

## 1.3 Player in danger — 🟡 built (2026-11-02), waiting for J's feel test

Live: `?spike=twinstick` (F4: Invulnerable, Slow-mo on low HP, Self blast damage ×), `?spike=style`.
`&autoshoot=1` makes the player invulnerable so measurements don't end in a death screen.

| Item | How |
| --- | --- |
| Health | `combat/fighter_health.gd` (`FighterHealth`, no nodes): HP 100 (`data/combat/player_fighter.tres`), zombie hits by type (Walker 10, Runner 6, Armored 12, Bloater 15; `Horde.target_hits`), 15 % of hits are bites (`bites`, for infection in 1.6), gas 12 HP/s at a cloud's centre, ground fire 15 HP/s, your own grenade × 0.5 with distance falloff; fractions of damage-over-time carry over |
| Downed | GDD §5: at 0 HP you're downed for 10 s (no moving, shooting or throwing), then dead; "YOU DIED · press R / X to restart" reloads the scene. `revive()` exists for teammates (1.9) |
| Armor | `combat/armor_config.gd`, `data/armor/`: bite vest (hits ×0.85, bites ×0.3, 3 kg; the spike loadout wears it), ballistic vest (×0.8, bullet armor M, speed ×0.95, 6 kg), heavy armor (×0.55, bites ×0.15, speed ×0.8, 15 kg, sinks), filter mask (no gas damage). One piece per slot |
| Feedback | `game/fx/damage_feedback.gd`: red screen edge that flashes per hit and pulses under 25 % HP; 0.5 s slow-mo (×0.45) the first time HP drops under 25 % (F4 toggle); HP on the HUD line |
| Gas + fire | fire burns a Bloater cloud away: a burning cell, a zombie burning all over, or an incendiary blast reaching it; zombies inside catch fire, a small blast shows; 20 damage if you stand in it |
| Tests | armor on hits, bite rate with and without a vest, downed → dead, revive, gas over time + mask, own blast, one piece per slot + heavy speed, invulnerable, zombie hit damage by type, cloud removal: 10 new, 162 total |

| Device | Browser | Scene | Result |
| --- | --- | --- | --- |
| Laptop Intel Arc 140V | desktop GL Compatibility 1280×720 | style + 200, no autoshoot, standing still | HP 100 → 0 in ~1 s once the crowd closes in (200 packed is a lot); downed 10 s → dead; 60 FPS |

Balance note: 200 zombies on an open roof kill a player standing still in about a second. That is what the
1.5 arena (waves, barricades, entrances) is for; tune `hit_damage` and `attack_interval` there.
Not measured on the web yet. No hit sound yet (1.4).

## 1.2 Enemy types and perception — 🟡 built (2026-11-02), waiting for J's look

Live: `?spike=style` / `?spike=twinstick` (roof: the mix hunts), `?spike=interior&storey=2` (sleepers inside).

| Item | How |
| --- | --- |
| Types | `combat/enemy_config.gd`, `data/enemies/`: Walker HP 100 (4 tints × 2 bodies = 8 looks), Runner HP 60 ×1.8 speed, sees 20 % further, Armored HP 150 armor M ×0.85 speed, no hit slow, stagger ×0.3, Bloater HP 250 ×0.6 speed, gas cloud on death (3 m, 8 s). HordeConfig.types + spawn_mix (72 / 14 / 10 / 4 %) |
| Look | body scale + tint per type on the shared VAT models (Runner thin and red-brown, Armored bulky and navy, Bloater wide and olive); corpses keep the scale. Real meshes: desktop |
| Armor | per agent from the type; pistol (L) does ×0.25 and stops in an Armored, AR (M) ×0.75, DMR (H) full |
| Perception | `Horde.state`: dormant / suspicious / hunting. `hear(at, r)`: calm agents within r walk to the noise on a shared noise flow field (×0.7 speed), within 0.35 r they hunt; `perceive(target)`: line of sight within 10 m × type × `sight_mul` → hunt; a hunter blind for 5 s turns suspicious at the last sighting; suspicious finds nothing for 10 s → dormant. A hit always makes it hunt. Suspicious agents don't attack |
| Interior | the interior hordes use it: shots (`noise_m` × 0.3) make sleepers walk to the sound, sight (6 m, dark) or a hunter next to them makes them hunt; hunters still follow across storeys |
| Gas | `combat/gas_field.gd` (cap 6, thins over the last 2 s; `strength_at` for 1.3) + `game/fx/gas_fx.gd` (one MultiMesh of puffs) |
| Overlay | Types (count per type), Gas Clouds; inside: Zombies Inside (awake, hunting) |
| Tests | stats per type, spawn mix, armor vs each gun, no slow on Armored, far / near / close noise, sight → hunt → lost → calm, Runner sight, death type + scale, gas fade + cap: 10 new, 152 total |

| Device | Browser | Scene | FPS | Draw calls | Primitives | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Laptop Intel Arc 140V | desktop GL Compatibility 1280×720 (Godot 4.7.2) | style + 200 mixed types, `--auto-shoot`, a gas cloud | 60 | 72–78 | ≤ 247k | horde update 1.2–1.75 ms, same as main (1.2–1.5 ms) in the same run |

Not measured on the web yet. Not decided yet (J): whether the four types read apart at a glance.

## 1.1 Weapons from data — 🟡 built (2026-11-02), waiting for J's feel test

Live: `?spike=twinstick` (F4 panel has the gun rows) and `?spike=style`; the interior spike carries the same guns.

| Item | How |
| --- | --- |
| Schema | `combat/weapon_config.gd`: class, caliber, damage, pellets, body_pen, armor_pen, stagger, range + falloff, rpm, fire modes (semi / auto / burst), spread + recoil bloom, mag, reload (whole mag or per round), noise, weight, wear + jam curve, waterproof, attachment slots |
| Rules | `combat/ballistics.gd`: falloff, −20 % per body passed, armor table (lower ×0.25 and the round stops, equal ×0.75, higher ×1), sustained DPS. Shots: every pellet is cast first, damage summed per zombie, applied once (`Horde.apply_hits`) with the gun's stagger |
| Carried state | `combat/gun.gd` (`Gun`): magazine, fire mode, bloom, durability, jams (from 50 % durability, up to 8 % per shot at 0 %; a reload clears it), reload from `AmmoPouch` (loose rounds per caliber) |
| Guns | `data/weapons/`: Pistol 9mm (semi, 15), AR 5.56 (auto + burst 3, 30), pump shotgun (15 pellets, 6, shell by shell; a pull fires mid-reload), DMR .308 (semi, 10, pierces 3) |
| Attachments | `data/weapons/attachments/`: silencer (noise ×0.4, damage −5 %, wear ×1.5), red dot (spread −10 %), extended mag (×1.5, reload +15 %), flashlight (the interior flashlight now needs one on the gun in hand) |
| Spike loadout | `data/weapons/spike_loadout.tres`: 1 AR + red dot + extended mag + flashlight · 2 pistol + silencer + flashlight · 3 shotgun · 4 DMR; 180 × 5.56, 90 × 9mm, 36 × 12g, 40 × .308. The supply crate tops rounds up |
| Controls | keys 1–4, pad R3 next gun; fire mode V / pad L3; HUD: `AR 5.56 [auto] 45 / 45 · 180`, reload %, JAMMED, durability under 50 % |
| Scale | GDD numbers: Walker HP 100 (was 3). Fire 34 per tick, spot fire 20, frag 150, incendiary 60, so kill times match 0.7 |
| Noise | `SpikePlayer.noise(at, radius)` per shot; inside a building sleepers wake at `noise_m` × 0.3 (silenced pistol ≈ 3 m, DMR 18 m) |
| Tests | DPS per class within ±10 % of GDD §6, falloff, pierce, armor table, semi / auto / burst, reload from the pouch, no rounds, shotgun shells + interrupt, jams + clearing, wear, attachments, one per slot, stagger: 15 new, 142 total |

| Device | Browser | Scene | FPS | Draw calls | Primitives | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Laptop Intel Arc 140V | desktop GL Compatibility 1280×720 (Godot 4.7.2) | style + 200, `--auto-shoot`, 40 s cycling the four guns + both grenades | 60 | 68–78 | ≤ 247k | no extra draw calls (a tracer per pellet, all in the one tracer mesh) |

Not measured on the web yet. Not decided yet: whether the guns feel right (J). No gun models yet (desktop).
