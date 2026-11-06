# Phase 1 — Web demo vertical slice (≈ 750 h of J's time, ~9 months at 20 h/week)

Goal (GDD §15): prove the loop **manage → explore → defend** is fun, as a free web build on GitHub Pages and
itch.io. J's decisions (2026-10-29):
1. **No cuts:** the 2026-10-27 additions (interiors, building/bridges, gun attachments, traits, occupants,
   airdrops, fire and blast fx) stay in the demo. GDD §17: ~704 h − 49 h already spent (spikes, CI) + 80–100 h
   of additions ≈ 750 h. Solo estimates slip up to 2× (GDD §17).
2. **Combat fun first** (GDD §16: "prototype combat before everything"). Nothing else starts until J calls
   combat fun (gate 1.G).
3. **Mixamo** clips are downloaded by J when a milestone first needs them.

Rules that carry over from Phase 0: every PR states what J should playtest; every milestone is measured on the
Arc web build (≥ 50 FPS, < 250 draw calls, < 300k primitives, first download < 50 MB, 7.6 MB of it left);
numbers go to `docs/PHASE1_RESULTS.md`. Spike code (`game/spikes/`) stays as test scenes; the game gets its
own scene flow, reusing the Phase 0 modules (`sim/`, `combat/`, `game/fx/`, `game/interior/`, `platform/`).

## Part A — Combat first (detailed)

### 1.1 Weapons from data (GDD §6)
- [x] `WeaponConfig` grows to the GDD stat schema: class, caliber, damage, pellets, rpm, mag, reload, spread,
      recoil, range + falloff, stagger, body_pen (−20 % damage per body passed), armor_pen L/M/H, noise_m,
      weight, durability + jam curve. Data in `data/weapons/`, live in the F4 panel.
      → rpm, spread and recoil per gun in the F4 panel (`?spike=twinstick`); `Gun` is the carried state.
- [x] Demo guns, one per class: Pistol (9mm), AR (5.56, burst mode), Shotgun (pump, 15 pellets), Rifle (DMR
      .308). Calibers and ammo pick-ups; the two grenades already exist (frag, incendiary).
      → loose rounds per caliber (`AmmoPouch`); the supply crate tops them up (pick-ups in the world: 1.5).
- [x] Weapon switching (keys 1–4, wheel / pad Y+stick), ammo in the HUD, reload per class (shotgun: shell by shell).
      → keys 1–4, pad RB = next gun (was R3 until the knife took it, 2026-11-06; the wheel stays the orders
      wheel); fire mode V / pad D-pad left.
- [x] Gun attachments ×4 (GDD §6 demo list): silencer, red dot, extended mag, flashlight (the 0.8 flashlight
      moves onto the gun). → no models yet; the interior flashlight is on only with a flashlight on the gun.
- [x] Noise: every shot emits `noise_m` into the horde perception (1.2). → `SpikePlayer.noise`; inside a
      building it wakes sleepers at `noise_m` × 0.3 until 1.2's perception replaces those rules.
- [x] Tests: damage falloff, penetration, armor table, DPS per class within ±10 % of the GDD table.
- [x] Assets (desktop, Blender): 4 low-poly guns in the player's hands + the 4 attachments on them.
      → `tools/blender/kit_guns.py` (×1.3 real size, 48–152 tris a gun); `GunModel` .tres per gun with its muzzle
      and slot mounts; `GunView` under the aim marker; the silencer moves the muzzle flash forward.

### 1.2 Enemy types and perception (GDD §9)
- [x] Demo zombies (GDD §17 "4 types", J 2026-10-29): Walker (≥ 4 sub-variants), Runner, Armored
      (armor M, helmet can drop), Bloater (gas on death). Per-type data: HP, speed, armor, hit slow, stagger.
      → `data/enemies/`; the gas cloud's damage to the player is 1.3. Helmet drop (desktop, 2026-11-03): after
      `helmet_hp` damage or any blast the helmet flies off and the Armored's armor falls M → L.
- [x] One MultiMesh per type mesh; type silhouette stays readable at a glance (pillar 5).
      → `EnemyConfig.models`; `HordeConfig.looks()`: 2 shared Walker looks + 1 per special type = 5 MultiMeshes.
- [x] Perception: dormant → suspicious (walks to the last noise) → hunting; sound first, sight second (fog and
      night shorten sight). Replaces the interior spike's simple wake rules. → `Horde.hear` / `perceive`,
      `sight_mul` for fog and night (1.11); the roof horde of the spikes always hunts (a night attack).
- [x] Assets (desktop): Runner / Armored / Bloater meshes + VAT clips (hand-keyed or Mixamo when needed).
      → `tools/blender/kit_zombie.py` MODELS: Runner sprints bent over, Armored stomps (vest, helmet part 11),
      Bloater waddles (swollen belly); hand-keyed, the other clips are shared.

### 1.3 Player in danger
- [x] Player HP, hits from zombies (the horde already counts them), downed state, revive or restart.
      → `FighterHealth`: hits by zombie type, bites counted (infection is SimCore, 1.6), downed 10 s (GDD §5)
      → dead → R / X restarts; also gas, ground fire and your own grenade (×0.5). Revive by teammates: 1.9.
- [x] Armor and weight for the player (GDD §7), stamina-free for now. → `ArmorConfig` (`data/armor/`): bite
      vest, ballistic vest, heavy armor, filter mask; one per slot; speed and weight (water effects later).
- [x] Damage feedback: screen edge, hit sound, short slow-mo on low HP (tunable, can be off).
      → red edge + slow-mo; the hit sound moves to the 1.4 audio pass (no audio yet).
- [x] Added: fire burns Bloater gas away (GDD §9): a burning cell, a zombie burning all over or an incendiary
      blast sets a cloud alight; everyone inside catches fire.

### 1.4 Game feel (GDD §6 "Boxhead part")
- [x] Hit-stop, knock-back along the bullet, muzzle flash, shell casings, camera shake (tunable, off option).
      → `data/fx/feel.tres` + F4 switches; `TimeControl` owns Engine.time_scale (hit-stop + 1.3 slow-mo).
- [x] Kill chain counter (score → influence later), hit markers, crosshair per weapon spread.
- [x] Audio pass 1: CC0 gun, impact, zombie and blast sounds; noise radius matches what you hear. → 1.5+ A1.
      → needs CC0 sound downloads (J approves each); includes the 1.3 hit sound.

### 1.5 Combat test arena — "one night on the roof"
- [x] The arena **is** the base roof (J 2026-10-29), so it carries over into the night horde (1.10).
      → `?spike=arena` (now the default page).
- [x] A 10-minute defence: waves from several entrances, ammo crates, a barricade that can be
      broken, both grenades, the four zombie types mixed per wave (data-driven wave table).
      → `data/combat/arena_roof.tres`: 6 waves, 487 zombies, 4 entrances (N and E barricaded), crates once per calm.
      A bot clears it in ~4 min; a person will take longer. J tunes the length with the wave table.
- [x] Telemetry hooks (local only for now): time alive, kills per weapon, ammo used, hits taken.
      → `telemetry/run_log.gd`: one JSON line per run in `user://telemetry/arena_runs.jsonl` + the summary screen.

### 1.5+ Added before the gate (J 2026-11-03)
J: after the gun meshes (1.1 assets), do these before 1.G, because combat fun depends on them. The gate moves
after this set. Parts of 1.8 (one survivor body), 1.9 (teammates) and 1.13 (audio) move forward; ≈ 60 h, most
of it taken from those milestones.

- [x] **A1 Audio pass 1** (replaces the 1.4 item). CC0 only (Kenney, OpenGameArt, freesound CC0): Claude lists each
      file with source and licence, J approves before any download. Shots per gun class + silenced, reload and
      dry click, frag and incendiary blasts, fire loop, zombie groan / attack / death per type, Bloater pop,
      player hit, footsteps per stance. Ogg, pooled players, ≤ 3 MB of the 7.6 MB left. What you hear matches
      `noise_m`. → 9 packs (`docs/audio/SOURCES.md`) cut by `tools/audio/build_sfx.py` into 34 Ogg files, 0.31 MB;
      `SfxBank` (`data/audio/sfx_bank.tres`), `SfxPlayer` pool of 24, `SpikeAudio` glue; F4 volume / mute.
      Footsteps per stance come with A3.
- [x] **A2 Survivor body** (desktop, Blender): `tools/blender/kit_survivor.py`, low-poly, warm palette, the gun in
      the right hand. Skeleton3D + AnimationTree, not VAT (≤ 6 people on screen). Hand-keyed clips: idle, walk,
      run, crouch idle / walk, prone idle / crawl, roll, reload per class (pistol, rifle, shotgun shell by shell),
      downed. Replaces the capsule for the player and the teammates. Male / female, build and outfits stay in 1.8.
      Sprint carry per gun (J 2026-11-03), from `WeaponConfig.carry_pose`: pistol / SMG at high ready, both hands,
      muzzle up; long guns (AR, shotgun, DMR) at port arms, across the chest in the crook of the arm, military
      style. Walking and standing keep the aim pose (no shooting while sprinting, A3).
      → `tools/blender/kit_survivor.py` (288 tris, 13 bones, 16 clips); `SurvivorView`: lower + upper layer through
      a bone filter, the gun on `hand_r` with a measured hold per clip; the player uses it; `?spike=poses` shows
      every clip. Stance / sprint / roll flags are ready for A3. The left hand holds the gun by two-bone IK to
      `GunModel.support`.
- [x] **A3 Stances and movement:** C crouch (toggle), Z prone (toggle), Shift sprint (hold), Space dodge roll
      (not Ctrl: Ctrl+R / Ctrl+W are browser shortcuts). Pad: L3 sprint, B roll, crouch / prone on the D-pad;
      fire mode moves off L3. Per stance in `data/combat/stances.tres`: speed, spread, footstep and shot noise,
      how far zombies see you (`Horde.perceive`). Stamina: sprint and roll drain it, regen after a pause; no
      shooting while sprinting or rolling; the roll has short i-frames and a cooldown.
      → `FighterMotion` (combat/, also for the A5 teammates) + `data/combat/movement.tres`; steps emit noise
      (`SpikePlayer.footstep` / `noise`), `Horde.perceive(seen_mul)`, `Gun.stance_spread_mul`,
      `FighterHealth.dodging`. Pad: L3 sprint, B roll, D-pad down / up crouch / prone; fire mode and grenade type
      moved to D-pad left / right; pad zoom and horde ± dropped (keyboard keeps them).
- [x] **A4 HUD:** HP and stamina bars; a reload ring above the character's head that fills over the reload time
      (shotgun: one step per shell).
      → `ui/fighter_hud.gd`: bars bottom left (stance on the stamina bar, it flashes below sprint_min_stamina; downed:
      the bar counts down the time to be helped up); the ring sits 2.25 m over each fighter in `fighters` (teammates
      join in A5), orange while clearing a jam.
- [x] **A5 Two AI teammates:** follow the player, shoot the nearest hunting zombie in range and line of sight with
      the same `Gun` / ballistics, reload, carry their own ammo, make noise, can be downed and revived by the
      player (hold F). Orders from the Tab wheel: follow / hold here. No friendly fire for now.
      → `Teammate` (a SpikePlayer driven by `TeammateBrain` instead of input) + `data/combat/teammate.tres`;
      Marco (AR) and Jess (shotgun), each with a pistol; `Horde.extra_targets`: hunters chase and hit the nearest;
      orders wheel: Follow me / Hold here / Hold fire; downed: F next to them for 2 s; `?mates=N`.
      → Bug list 2026-11-05 (items 1, 2, 5, 7): gas and burning ground hurt teammates; revive lives in SpikePlayer
      (`start_revive`, `FighterConfig.revive_sec / revive_radius_m`), so a teammate walks to a downed squad member
      (the player first), kneels 2 s without firing and gets it up ("Marco is coming" on the downed line); frags
      (2 each, `TeammateConfig.grenades`) into ≥ 5 hunters with no friend near the blast, 6 s apart; stance is its
      own call (J): standing still, the lowest stance whose muzzle (`MovementConfig.muzzle_height_m`: 1.38 / 1.0 /
      0.38 m) clears the low cover toward its target, prone only with no hunter within 10 m, crouch within 5 m;
      crouched while sneaking past sleepers; kneels to revive; stands to move or look.

### 1.G Gate — "combat is fun"
- **Pass (J):** after 1.5+, J plays the arena at least 3 times on the Arc in Chrome and says it's fun; ≥ 50 FPS at the
  largest wave. **Fallback:** tune with the F4 panel and data for one more round; if still not fun, stop and
  rethink the combat design before Part B (GDD §16 risk "combat isn't fun").
  → **✅ Pass 2026-11-05** (J, 3 nights on the Arc in Chrome, build `e96d7dd · #144`): fun; teammates make it easier
  but you still die. Wave 6: 60 FPS, 150 draws, 137k. Bugs from J to follow.

## Part B — The rest of the loop (outline; detailed after 1.G)

Order follows the loop. Hours from GDD §17 (J's time).

| # | Milestone | Main content | h |
| --- | --- | --- | --- |
| 1.6 | SimCore day | survivors (named, skills, traits), needs, resources, the day tick, save v2; influence + status ladder (citizen system, below) | 55 |
| 1.7 | Base | rooms ×6 tier 1–2, production, utility AI daily life, Observer mode | 70 |
| 1.8 | Survivors on screen | male/female bodies, build, height, skin, hair; locomotion 8-way (Mixamo); outfits ×5 + colour/pattern | 95 |
| 1.9 | Expedition | boat, district map with 4–6 buildings, interiors (from 0.8), looting, team orders, occupants, airdrops | 140 |
| 1.10 | Night horde | several entrances, tower crews, barricades, building + roof bridges | 50 |
| 1.11 | Time, weather, light | day/night, rain, seasonal water level, water shader | 30 |
| 1.12 | UI / HUD | every screen in English via `tr()`, full gamepad navigation | 45 |
| 1.13 | Audio + polish | CC0 mix, music, balance and bug passes (~25 % of the total) | 170 |
| 1.14 | Release | telemetry with opt-in consent (PDPA), feedback form, itch.io page "free during development" | 12 |

Part A (combat, 1.1–1.5) ≈ 80 h, so the total is ≈ 750 h.

### 1.6 citizen system (J, 2026-11-05; GDD §3, §11, §12)
- [ ] Influence earned per survivor for every action (days in the base, missions done, morale, zombie kills; rates
      in `data/`). It goes to one base pool (trading with other communities) **and** to the survivor's personal
      rank points; spending from the pool never lowers anyone's rank.
- [ ] Status ladder stranger → member → outstanding citizen by rank-point thresholds (data). No cap: anyone can be
      an outstanding citizen, and every outstanding citizen's buff applies at once, leader or not.
- [ ] Leader: picked from outstanding citizens; becoming leader opens a quest line to a tier-4 special room and
      special items made in tier-4 buildings. Leader personality from the survivor's special skill, or added by
      reading a book.
- [ ] J's full spec, 2026-11-06: **`docs/CITIZENS_1_6.md`**. It covers:
      - 6 leaders: room, items, community effect, unlock goal
      - core skills 0–7 twice, with 4 specializations each
      - 9 backgrounds and 9 more traits
      - community skills + books, and combat classes, designed by Claude and approved by J; all 6 classes in the demo
      1.6 builds the data model and rules for all of it, and wires only the effects whose systems exist now
      (§8 there). J's answers are in §9 there.
- Status is never lost (J, 2026-11-06). A leader can step down, back to outstanding citizen with the buff; one
      leader at a time. There are no game-ending goals: play goes on indefinitely.
- SimCore rule: all of this is pure data + rules in `sim/`, unit-tested, saved in the survivor state (save v2).

## J's bug list after 1.G (2026-11-05)

J: "รายงานข้อผิดพลาด", 18 items. Grouped by what they need; **code** = either machine, **desktop** = Blender / clips.

| # | Item | Group | Where |
| --- | --- | --- | --- |
| 1, 7 | ~~Teammates don't revive the downed player~~ fixed (PR #53, J passed 2026-11-06) | Teammate AI | code |
| 1 | ~~Teammates don't throw grenades, crouch or go prone~~ fixed (PR #53, J passed 2026-11-06; stance is their own call by cover) | Teammate AI | code |
| 2 | ~~Teammates take no damage from Bloater gas~~ fixed (PR #53, J passed 2026-11-06; ground fire too) | Teammate AI | code |
| 5 | ~~Teammates look lost when the player is downed~~ fixed (PR #53, J passed 2026-11-06) | Teammate AI | code |
| 10 | Under "hold fire" teammates only dodge: add behaviours (melee, suppressed fire, stay still, stealth-follow), fire modes (suppressed / not, melee) and a wider orders wheel with icons | Teammate AI + orders | code. Designed with J 2026-11-06 (DECISIONS). Step 1 melee: PR #55; step 2 the 8-slot wheel and its behaviours: `phase1/orders-wheel` (`docs/art/16_orders_wheel.png`) |
| 3 | ~~No crosshair for the pistol while downed~~ fixed (`fix/hud-downed`) | HUD | code |
| 16 | ~~A downed icon over the player and teammates~~ fixed (`fix/hud-downed`: red cross badge, ringed by time left or the revive; `docs/art/18_downed_badge.png`) | HUD | code |
| 17 | A weapon UI | HUD | code. Designed with J 2026-11-06: a bottom-right panel (DECISIONS). `ui/weapon_panel.gd` on `phase1/weapon-panel` (`docs/art/17_weapon_panel.png`); gun icons (`WeaponConfig.icon`): `tools/blender/icons_guns.py` on `phase1/gun-icons` |
| 9 | ~~The reload ring stays on dead teammates / the player~~ fixed (`fix/hud-downed`) | HUD bug | code |
| 8 | ~~Zombies keep attacking the dead player's body~~ fixed (`fix/hud-downed`: they turn to a teammate still up or down; with nobody left they gather without attacking) | Horde bug | code |
| 18 | ~~Barricades should show damage by level (3 stages exist; make them clearer or add more)~~ clearer (`fix/barricade-stages`: HP bar with stage notches after a hit, a shake per hit, splinters at each stage; `docs/art/20_barricade_stages.png`). More stages = more kit pieces on the desktop | Arena | code + desktop pieces |
| 13 | ~~The water next to buildings looks odd (foam ring / shore)~~ fixed (`fix/water-shore`: thin broken lapping foam, a dark wet line at the wall, less tint; `docs/art/19_water_shore_*.png`) | Water shader | code |
| 4 | ~~Weapon switch animation~~ built (`phase1/anim-melee`: `switch` clip, the model swaps halfway) | Animation | desktop |
| 6 | ~~No death animation; the downed pose freezes~~ built (`phase1/anim-melee`: `death` one-shot; `downed` breathes, rolls its head, pushes a leg) | Animation | desktop |
| 11 | ~~Standing → prone looks like just falling over~~ built (`phase1/anim-melee`: knees, hands, then flat; `prone_to_stand` back up) | Animation | desktop |
| 12 | ~~Crouch → prone transition~~ built (`phase1/anim-melee`: `crouch_to_prone`, `prone_to_crouch`) | Animation | desktop |
| 14 | ~~Side roll while prone~~ built (`phase1/anim-melee`: Space while prone = a 1.2 m log roll to the side the stick leans to) | Animation + motion | desktop |
| 15 | ~~Prone crawl: rifle across the elbows, crawl on knees and elbows~~ built (`phase1/anim-melee`; no shooting while crawling) | Animation | desktop |

## Settled with J
- 2026-11-03: 1.5+ before the gate; CC0 sound packs; roll on Space; 2 AI teammates in the arena. Sprint carry:
  pistol / SMG muzzle up (high ready), long guns across the chest (port arms).

### 2026-10-29
- Demo zombie types: Walker, Runner, Armored, Bloater.
- The combat test arena is the real base roof.
