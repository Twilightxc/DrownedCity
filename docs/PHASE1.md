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
      → keys 1–4, pad R3 = next gun (the wheel stays the orders wheel); fire mode V / pad L3.
- [x] Gun attachments ×4 (GDD §6 demo list): silencer, red dot, extended mag, flashlight (the 0.8 flashlight
      moves onto the gun). → no models yet; the interior flashlight is on only with a flashlight on the gun.
- [x] Noise: every shot emits `noise_m` into the horde perception (1.2). → `SpikePlayer.noise`; inside a
      building it wakes sleepers at `noise_m` × 0.3 until 1.2's perception replaces those rules.
- [x] Tests: damage falloff, penetration, armor table, DPS per class within ±10 % of the GDD table.
- [ ] Assets (desktop, Blender): 4 low-poly guns in the player's hands + the 4 attachments on them.

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
- [ ] Audio pass 1: CC0 gun, impact, zombie and blast sounds; noise radius matches what you hear.
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

### 1.G Gate — "combat is fun"
- **Pass (J):** J plays the arena at least 3 times on the Arc in Chrome and says it's fun; ≥ 50 FPS at the
  largest wave. **Fallback:** tune with the F4 panel and data for one more round; if still not fun, stop and
  rethink the combat design before Part B (GDD §16 risk "combat isn't fun").

## Part B — The rest of the loop (outline; detailed after 1.G)

Order follows the loop. Hours from GDD §17 (J's time).

| # | Milestone | Main content | h |
| --- | --- | --- | --- |
| 1.6 | SimCore day | survivors (named, skills, traits), needs, resources, the day tick, save v2 | 55 |
| 1.7 | Base | rooms ×6 tier 1–2, production, utility AI daily life, Observer mode | 70 |
| 1.8 | Survivors on screen | male/female bodies, build, height, skin, hair; locomotion 8-way (Mixamo); outfits ×5 + colour/pattern | 95 |
| 1.9 | Expedition | boat, district map with 4–6 buildings, interiors (from 0.8), looting, team orders, occupants, airdrops | 140 |
| 1.10 | Night horde | several entrances, tower crews, barricades, building + roof bridges | 50 |
| 1.11 | Time, weather, light | day/night, rain, seasonal water level, water shader | 30 |
| 1.12 | UI / HUD | every screen in English via `tr()`, full gamepad navigation | 45 |
| 1.13 | Audio + polish | CC0 mix, music, balance and bug passes (~25 % of the total) | 170 |
| 1.14 | Release | telemetry with opt-in consent (PDPA), feedback form, itch.io page "free during development" | 12 |

Part A (combat, 1.1–1.5) ≈ 80 h, so the total is ≈ 750 h.

## Settled with J (2026-10-29)
- Demo zombie types: Walker, Runner, Armored, Bloater.
- The combat test arena is the real base roof.
