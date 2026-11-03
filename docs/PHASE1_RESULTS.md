# Phase 1 results

Measured numbers and J's verdicts per milestone (plan: `docs/PHASE1.md`). Device/browser on every row; J's Arc
laptop is the pass/fail reference. New rows go at the top of each section.

## 1.5+ A2 Survivor body — 🟡 built (2026-11-03), waiting for J's look

Live: `?spike=poses` (every clip, labelled; Q / E turn, wheel zooms) and the player in `?spike=arena`.

| Item | How |
| --- | --- |
| Body | `tools/blender/kit_survivor.py`: rigid low-poly parts skinned to 13 bones, warm jacket / denim / boots, backpack; 288 tris, 1 draw call + shadow (the gun and attachments add theirs) |
| Clips | hand-keyed: idle, walk, run, crouch idle / walk, prone, crawl, roll, downed; aim pistol / rifle, sprint high ready (pistol, SMG) and port arms (long guns), reload pistol / rifle / shell |
| Layers | `SurvivorView`: AnimationTree, legs' clip × arms' clip through a Blend2 bone filter; moving clips scale to the speed (backwards when backing away); reloads stretch to the gun's reload time |
| Gun | on `hand_r`; the hold per clip is measured from the pose, so it stays level in the aim and points up / across the chest when sprinting |
| Pose fixes (J) | standing: right foot a step back and turned out; crouch = kneeling (right knee on the floor, left knee up), crouch walk stays a squat; prone: legs apart, toes turned out |
| Left hand | J: "แขนซ้ายไม่จับปืนเลย" → `LeftHandIK` (SkeletonModifier3D, two-bone IK) puts the left palm on the gun's support point (handguard, pump, fore-end; a pistol: the right hand), within 6 cm on all four guns; fades out for reloads, roll, downed |
| Picture | `docs/art/09_survivor_poses.png` |
| Not checked | Arc FPS with a skinned body; stances are not on keys yet (A3) |

## 1.5+ A1 Audio pass 1 — 🟡 built (2026-11-03), waiting for J's ears

Live: `?spike=arena&wave=4` (click once: browsers start audio on the first input). F4: "Sound off", "Sound volume (dB)".

| Item | How |
| --- | --- |
| Sources | 9 CC0 packs, each approved by J (`docs/audio/SOURCES.md`); raw packs stay out of the repo |
| Files | `tools/audio/build_sfx.py` → 34 mono Ogg (q3; zombies and steps at 22 kHz), 0.31 MB of the 7.6 MB left |
| Mixing | `SfxPlayer`: 24 pooled AudioStreamPlayer3D, per-event voice cap and min interval, oldest voice stolen; listener on the player, turned with the camera. Desktop wave-4 bot run: peak 10 voices |
| Range | a shot carries its gun's `noise_m` (silenced pistol 16 m instead of 40 m), so you hear what the zombies hear |
| Not checked | how it sounds (Claude can't listen); web: no console errors in a local Chrome export, not tried on the Arc |

## 1.5 Combat test arena — 🟡 built (2026-11-02), waiting for J's gate 1.G (3 runs on the Arc)

Live: `?spike=arena` (also the default page). F4 still works (it's the twin-stick spike plus the arena).

| Item | How |
| --- | --- |
| Waves | `combat/wave_director.gd` over `data/combat/arena_roof.tres` (`ArenaConfig` + `WaveConfig`): calm → wave → calm…; 6 waves of 25 / 46 / 65 / 83 / 112 / 156 zombies (Walker → Runner → Armored → Bloater mixed in), 3–6 spawns/s, 8–15 s calms, never more than 200 on the roof |
| Entrances | 4 on the roof edge (N, E, S, W); zombies climb up into a 3-cell pocket there (12 waiting at most, the rest come later) |
| Barricades | `combat/barricades.gd`: N and E pockets are boxed in by planks (2000 HP each). They block zombies and the player, not bullets; the flow field crosses them at a cost, so hunters pile up and tear them down (each hit = their type's hit damage). Planks sink as they lose HP and splinter when they fall |
| Crates | the two supply crates restock once per calm (refilled when a calm starts) |
| HUD | "Wave 3 / 6 · 31 to come · 25 on the roof", "Calm · wave 4 / 6 in 9 s", a WAVE n banner |
| End | last wave cleared → NIGHT SURVIVED; dead → YOU DIED on wave n. Summary: time, kills, best chain, score, kills and rounds per gun, grenade kills, fire and other, hits taken, bites; R / X plays again |
| Telemetry | `telemetry/run_log.gd`: the same numbers + build label as one JSON line in `user://telemetry/arena_runs.jsonl` (IndexedDB on the web); local only, nothing is sent |
| Bug found by a test | the wave director counted the roof as clear on the frame that spawned a wave's last zombies, ending the wave early; fixed |
| Tests | calm → wave → calm → won, alive cap + refunds, barricade block / break / flow cost, hunters tear a barricade down and walk through, arena data sane: 5 new, 172 total |

| Device | Browser | Scene | FPS | Draw calls | Primitives | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Laptop Intel Arc 140V | desktop GL Compatibility 1280×720, fixed 60 FPS | whole night, `--auto-shoot` (invulnerable bot) | — | ≤ 87 | ≤ 160k | 3:55, 487 kills, best chain ×136; barricades fell in waves 2–3 |

Not measured on the web yet. The gate (1.G) is J's: 3 runs on the Arc in Chrome — is it fun, and ≥ 50 FPS at the biggest wave?

## 1.4 Game feel — 🟡 built without audio (2026-11-02), waiting for J's feel test

Live: `?spike=twinstick` (F4: Hit-stop, Camera shake + strength, Muzzle flash, Shell casings), `?spike=style`.

| Item | How |
| --- | --- |
| Knock-back | `WeaponConfig.knockback` m/s per hit (pistol 1.5, AR 1.0, shotgun 0.8 per pellet so a full blast ~8, DMR 3) × `EnemyConfig.knockback_mul` (Runner 1.2, Armored 0.35, Bloater 0.3); grenades shove survivors outward (6 m/s at the centre). `Horde.knock` fades at 9/s, rides on the walk, slides along walls |
| Hit-stop | ×0.05 for 45 ms when one round kills 2+, 70 ms for a blast that kills 2+ |
| Time | `game/fx/time_control.gd`: the one owner of Engine.time_scale; the slowest active request wins (hit-stop, the 1.3 low-HP slow-mo), real-time so a freeze can't stretch itself |
| Shake | `game/fx/screen_shake.gd`: trauma² (decays 2.2/s, max 0.5 m) via the camera's h/v offset; shots add recoil × 0.06, blasts 0.7 falling to 0 at 15 m, taking a hit 0.25 |
| Muzzle | `game/fx/muzzle_fx.gd`: an additive flame billboard + a shadowless omni light for 50 ms; bigger for the shotgun, smaller with the silencer |
| Casings | `game/fx/casing_fx.gd`: one MultiMesh ring (96): out to the right, tumble, one bounce, lie 6 s, shrink; brass, shotgun shells red |
| Kill chain | `combat/kill_chain.gd`: kills within 2 s extend it; each kill scores the chain length up to ×10 (score → influence in 1.10); "x12 chain" on the right, fading with the window |
| Crosshair | `game/fx/crosshair_hud.gd`: four ticks on the mouse (pad: 8 m along the aim) opening with the gun's spread + bloom; white X on a hit, red on a kill; the OS cursor hides while playing and comes back when paused or dead |
| Tests | kill chain + cap, shake bounds + decay, time control, knock-back (direction, armored barely moves, fades): 5 new, 167 total |

| Device | Browser | Scene | FPS | Draw calls | Primitives | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Laptop Intel Arc 140V | desktop GL Compatibility 1280×720 | style + 200, `--auto-shoot`, AR then shotgun | 60 | 71–89 | ≤ 251k | the muzzle light adds a few draws while it's on (+10 at most) |

Not measured on the web yet. No audio yet: CC0 sounds need J's OK for each download.

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
| Look | 2026-11-03 (desktop): a mesh + VAT clips per special type from `tools/blender/kit_zombie.py` (`docs/art/07_zombie_types.png`): Runner thin, bare-armed, rust tank top, sprints bent over (stride 2.6 m); Armored broad, navy vest, pads, helmet, stomps; Bloater swollen yellow belly with boils, waddles. Walker keeps the 2 shared bodies × 4 tints. 5 looks = 5 MultiMeshes (+3 for the horde, +3 for corpses); Armored 300 tris, Runner 204, Bloater 228, Walker 180. Was: body scale + tint on the shared models |
| Helmet | Armored only: `helmet_hp` 40 damage (after armor) or any blast knocks it off; it flies as a limb and lies there, the zombie and its corpse go bareheaded, armor M → L (`armor_after_helmet`) |
| Bug fixed | since 0.7 Godot read the part index as 0.5 − part (glTF flips V), so dismemberment masks and spot fires hit the wrong parts; the kit now writes it pre-flipped (Walker .glb rebaked, its VAT unchanged). Tests: looks per type, helmet drop, blast drop, corpse/helmet masks, baked meshes keep their parts: 5 new, 177 total |
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
| Gun meshes (desktop, 2026-11-03) | `tools/blender/kit_guns.py`: pistol 48 tris, AR 152, shotgun 116, DMR 112; silencer, red dot, extended mag, flashlight 24–60 each. One draw call for the gun + one per attachment (the AR in the arena: 4) plus their shadow pass. Close-up: `docs/art/08_guns_in_hand.png`. Not measured on the Arc |
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
