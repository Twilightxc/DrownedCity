# Phase 1 results

Measured numbers and J's verdicts per milestone (plan: `docs/PHASE1.md`). Device/browser on every row; J's Arc
laptop is the pass/fail reference. New rows go at the top of each section.

## Bug list animations + melee — 🟡 built (2026-11-06), waiting for J's look

J's bug list items 4, 6, 11, 12, 14, 15 and the melee models / clips (desktop). Live: `?spike=poses` (new row of
clips), `?spike=arena`.

| Item | How |
| --- | --- |
| Weapon switch (4) | `switch` upper clip, 0.4 s: the hand drops to the holster / sling and comes back up; the gun model and the slung ones swap halfway |
| Death (6) | `death` one-shot from the downed pose: the propped arm gives, flat on the back, head rolls aside; holds the last frame |
| Downed (6) | `downed` is a 4 s cycle: heavy breaths, the head lolls, the bent leg pushes and slides, the wounded side curls |
| Stand → prone (11), crouch → prone (12) | `go_prone` (0.67 s): both knees, hands to the floor, then flat behind the sights; `crouch_to_prone`, `prone_to_stand`, `prone_to_crouch`. Moving, rolling or falling cuts them short. Visual only: the stance itself still changes at once |
| Prone side roll (14) | Space while prone: a log roll 1.2 m across the aim, 0.62 s, 12 stamina, to the side the stick leans to (refused along the aim). The body keeps facing the aim. `MovementConfig.prone_roll_*` |
| Crawl (15) | elbows and knees, frog kick, the rifle across the forearms. **New rule: no shooting while crawling** (stop to fire) |
| Melee | `prop_melee_knife` (104 tris), `prop_melee_axe` (88 tris, red fire axe), `MeleeConfig.mesh_scene / mesh_scale / clip`. Knife: `slash_light`, a backhand cut, crosses the aim at 0.12 s of 0.45 s. Axe: `slash_heavy`, overhead chop, at 0.25 s of 0.8 s. Standing or crouched (upper-body clips). The gun goes away for the swing; the placeholder crescent is gone when a body exists |
| Tests | 7 new, 251 total, all passing on desktop |
| Not checked | the Arc (no new draw calls except the melee weapon during a swing) |

## 1.G Gate "combat is fun" — ✅ pass (J, 2026-11-05)

J played the arena night 3 times on the Arc laptop in Chrome (live build `e96d7dd · #144`):
"เล่นครบ 3 คืนแล้วสนุก" — fun. Teammates: "มีเพื่อนแล้วง่ายขึ้นแต่ก็ยังตาย ไม่ง่ายขนาดนั้น" — easier with Marco
and Jess, but you still die; not too easy, so they stay on by default. J has a list of bugs and will send it later.

| Device | Browser | Scene | FPS | Draw calls | Primitives | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Laptop Intel Arc 140V | Chrome, maximised window, live build `e96d7dd · #144` (J) | arena wave 6 / 6, 27–32 zombies on the roof (87 to come), teammates, corpses 136, blood 160 / 160, a gas cloud | 60 (17.0 ms) | 150 | 137k | horde update 0.13 ms, render sync 0.24 ms, flow field 0.20 ms; VRAM 104.6 MB |

- **Budget:** 150 of 250 draw calls, 137k of 300k primitives, at the vsync cap. The screenshot was not at the
  wave's peak crowd (~30 on the roof); with ~100 draw calls of headroom it should hold there too. Draw calls are
  up from the desktop's 90 at wave 5: teammates, casings, gas, and full corpse / blood caps.
- **Part B can start** (`docs/PHASE1.md`), with 1.6 SimCore day first. Open before or alongside it: J's bug list,
  and the small items from the desktop note (teammates can't revive the player, don't throw grenades or crouch,
  don't take gas / fire damage; pad bindings untested on a pad).

## 1.5+ arena props — 🟡 built (2026-11-04), waiting for J's look

J: "ทำตามที่เสนอได้เลย" (the four Blender pieces still placeholders in the arena). Live: `?spike=arena`.

| Item | How |
| --- | --- |
| Supply crate | `prop_supply_crate` (172 tris): olive military crate, stencilled, rope handles, an ammo can and dressings on the lid |
| Barricades | `prop_barricade_planks_0..2`, `prop_barricade_pallet_0..2` (48–168 tris): per cell, planks across posts or an upright pallet, boards turned to face the entrance pocket; above 66 % / 33 % / below of its HP the cells show stage 0 / 1 / 2 (boards come off); still one merged mesh per barricade |
| Throwables | `prop_grenade_frag`, `prop_molotov` (88 tris each, ×1.8 in flight, tumbling); the incendiary is a Molotov with a burning rag (emissive) |
| Carried guns | the guns not in hand show: two long guns slung crossed on the back, a sidearm in a holster on the right thigh; no shadows (+1 draw call each) |
| Picture | `docs/art/14_arena_props.png` |
| Not checked | the Arc (a few more draw calls: the slung guns and attachments of three fighters) |

## 1.5+ A5 Two AI teammates — 🟡 built (2026-11-03), waiting for J's feel test (then gate 1.G)

Live: `?spike=arena` (2 teammates), `?spike=arena&mates=0` (none, to compare). Orders: hold Tab.

| Item | How |
| --- | --- |
| Who | Marco (AR + red dot, pistol) on the left, Jess (pump shotgun, pistol) on the right; own ammo, topped up at each calm |
| Brain | `TeammateBrain` (pure): the hunting zombie nearest to itself that it can see within 0.85 × gun range (J; `protect_weight` 0); turns at 420°/s, waits 0.3 s on a new target, fires inside 5°, bursts 0.35 s / pause 0.25 s (semi guns pulse); backs off anything within 2.4 m; keeps a spot 2.2 m beside and 2 m behind the player (GridPath around props); sprints back when > 9 m off and idle; swaps to the pistol when the main gun is dry; tactical reload under 40 % when nothing is near |
| Horde | `Horde.extra_targets`: hunters chase and hit whichever of player / teammates is nearest; the flow field has them all as goals |
| Down | 20 s downed like the player, firing their pistol; F next to them for 2 s gets them up (green ring); walking off cancels |
| Orders | Follow me · Hold here (where each stands) · Hold fire (toggle); the other wheel items come with expeditions |
| HUD | a card per teammate above the player's bars: name, HP (downed: countdown), stamina; greyed when dead. Over their heads only the reload / revive ring (J: no names over heads) |
| No friendly fire | rounds test only the horde; grenades do hurt teammates |
| Desktop bot run, wave 3 | cleared in ~25 s with the player on auto-shoot: Marco 36 kills, Jess 6 of 65; nobody hit. Marco may be too strong: J's call (`data/combat/teammate.tres`) |
| Down but fighting (J 2026-11-04) | downed lasts 20 s (was 10; `FighterConfig.downed_sec`); the sidearm comes out by itself and the fighter aims, fires and reloads it from the ground (`downed_aim`: propped on the left elbow, pistol over the feet, muzzle 0.78 m, so low cover blocks it); no moving, long guns or throws; back up, the long gun returns. Teammates do the same and the horde keeps going for them |
| Looks (J 2026-11-04) | survivors: 3 outfits in one `survivor.glb` (one skeleton, one clip set): orange jacket (player), mustard work jacket + cap + beard (Marco), red hoodie + auburn ponytail (Jess); zombies: 10 looks: Walker male, female, office (shirt + tie, bald), dock worker (coveralls, beanie); a second look for each special type (hoodie Runner, riot-police Armored, darker Bloater). +5 VAT looks ≈ +0.9 MB; desktop wave 5: 51 zombies over all 10 looks, 90 draw calls, 92k primitives. Pictures: `docs/art/12_survivor_looks.png`, `docs/art/13_zombie_looks.png` |
| Not yet | teammates don't revive the player, throw grenades, crouch or take gas / fire damage |

## 1.5+ A4 HUD — 🟡 built (2026-11-03), waiting for J's look

Live: `?spike=arena`. The top-left line now only shows the gun (mode, mag, rounds, jam).

| Item | How |
| --- | --- |
| Bars | `FighterHud` (CanvasLayer 39), bottom left: HP (red) and stamina (amber, the stance written on it, flashing when there isn't enough to sprint); downed, the HP bar turns dark red and counts down `downed_sec` |
| Reload ring | over the head (2.25 m, projected each frame), fills from the top clockwise with the reload; a pump shotgun's ring has a tick per shell it loads and fills one step per shell; orange while clearing a jam |
| Cost | one Control redraw a frame, no nodes per fighter |
| Not checked | readability at the Arc's resolution |

## 1.5+ A3 Stances and movement — 🟡 built (2026-11-03), waiting for J's feel test

Live: `?spike=arena` (C crouch, Z prone, Shift sprint, Space roll; the HUD shows stamina and the stance). The
numbers are in `data/combat/movement.tres`.

| Item | Stand / crouch / prone | Notes |
| --- | --- | --- |
| Speed × | 1.0 / 0.55 / 0.22 | sprint × 1.6 (7.2 m/s), drains 18 stamina/s, needs 15 to start; shooting stops it |
| Spread × | 1.0 / 0.7 / 0.5 | `Gun.stance_spread_mul`; the crosshair widens and narrows with it |
| Step noise | 6 / 2.5 / 1 m every 0.75 / 0.55 / 0.45 m | sprint 12 m; the footstep sound is as loud as its noise |
| Seen from × | 1.0 / 0.65 / 0.35 | `Horde.perceive(seen_mul)`; the roof horde always hunts, so it shows inside buildings (`?spike=interior`) |
| Roll | 3 m in 0.54 s, i-frames 0.35 s, cooldown 0.6 s, 25 stamina, 5 m noise | not from prone; zombie hits and blasts miss during the i-frames (fire and gas still burn) |
| Stamina | 100, +22/s after 0.8 s | |
| Desktop bot run | crouch → crawl 0.99 m/s → sprint 7.2 m/s (stamina 100 → 86) → roll (i-frames, stamina 61) | body clips follow each state |

## 1.5+ A2 Survivor body — 🟡 built (2026-11-03), waiting for J's look

Live: `?spike=poses` (every clip, labelled; Q / E turn, wheel zooms) and the player in `?spike=arena`.

| Item | How |
| --- | --- |
| Body | `tools/blender/kit_survivor.py`: rigid low-poly parts skinned to 13 bones, warm jacket / denim / boots, backpack; 288 tris, 1 draw call + shadow (the gun and attachments add theirs) |
| Clips | hand-keyed: idle, walk, run, crouch idle / walk, prone, crawl, roll, downed; aim pistol / rifle, sprint high ready (pistol, SMG) and port arms (long guns), reload pistol / rifle / shell |
| Layers | `SurvivorView`: AnimationTree, legs' clip × arms' clip through a Blend2 bone filter; moving clips scale to the speed (backwards when backing away); reloads stretch to the gun's reload time |
| Gun | on `hand_r`; the hold per clip is measured from the pose, so it stays level in the aim and points up / across the chest when sprinting |
| J's round 4 (2026-11-03) | long guns are shouldered: `RightArmAim` puts the butt plate (`GunModel` "stock") in the right shoulder pocket at 1.40 m, level along the aim, and IKs the right hand to the grip; bladed stance (torso −34°) so the left hand reaches the handguard (palm within 7 cm on all three); long guns scaled 1.05 / 1.0 instead of 1.3 (the pistol keeps 1.3; attachments are built at real size and take their gun's scale) |
| Low cover (J) | `NavGrid.low_cover`: AC units 0.95 m, sandbags 1.0 m (`metadata/cover_height` in the level). Rounds, the aim line and aim assist fly over cover lower than the muzzle (standing rifle 1.39 m; kneeling ≈ 1.0 m clears an AC unit barely, prone 0.3 m doesn't); zombies see over it a survivor taller than it (stand 1.5 / crouch 0.95 / prone 0.35 m, `MovementConfig.body_height_m`); walls and the water tower still block everything |
| J's round 3 (2026-11-03) | the side-step clips looked like an air dancer: walking sideways now turns the hips to the travel and twists the torso back to the aim (`HipTwist`, up to 100°), past 115° off the aim the legs walk backward (back under 85°); strides retuned to the real speeds (walk 4.5 m/s: was played 3× too fast; crouch 2.5, crawl 1.0, sprint 7.2) |
| J's round 2 (2026-11-03) | walk / crouch-walk blend four clips (ahead, back, left, right of the aim; replaced in round 3); sprint and roll turn the body to where it goes; the body casts a shadow again (survivor.glb.import: shadow meshes and LODs off); reloads: the gun comes off the shoulder tipped toward the left hand, which the IK walks to the mag well → floor (the empty mag drops and stays 6 s) → vest pouch / belt → mag well → charging handle or slide; a shotgun shell goes from the belt into the loading port; mags are their own meshes (kit_guns.py MAGS) |
| Pose fixes (J) | standing: right foot a step back and turned out; crouch = kneeling (right knee on the floor, left knee up), crouch walk stays a squat; prone: legs apart, toes turned out; prone aim propped on both elbows, chest up, the stock in the shoulder and the gun level at head height (arm angles solved by FK), with its own measured hold |
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
