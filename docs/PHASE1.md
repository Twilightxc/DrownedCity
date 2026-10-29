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
- [ ] `WeaponConfig` grows to the GDD stat schema: class, caliber, damage, pellets, rpm, mag, reload, spread,
      recoil, range + falloff, stagger, body_pen (−20 % damage per body passed), armor_pen L/M/H, noise_m,
      weight, durability + jam curve. Data in `data/weapons/`, live in the F4 panel.
- [ ] Demo guns, one per class: Pistol (9mm), AR (5.56, burst mode), Shotgun (pump, 15 pellets), Rifle (DMR
      .308). Calibers and ammo pick-ups; the two grenades already exist (frag, incendiary).
- [ ] Weapon switching (keys 1–4, wheel / pad Y+stick), ammo in the HUD, reload per class (shotgun: shell by shell).
- [ ] Gun attachments ×4 (GDD §6 demo list): silencer, red dot, extended mag, flashlight (the 0.8 flashlight
      moves onto the gun).
- [ ] Noise: every shot emits `noise_m` into the horde perception (1.2).
- [ ] Tests: damage falloff, penetration, armor table, DPS per class within ±10 % of the GDD table.
- Assets (desktop, Blender): 4 low-poly guns in the player's hands.

### 1.2 Enemy types and perception (GDD §9)
- [ ] Demo zombies (GDD §17 "4 types", J 2026-10-29): Walker (≥ 4 sub-variants), Runner, Armored
      (armor M, helmet can drop), Bloater (gas on death). Per-type data: HP, speed, armor, hit slow, stagger.
- [ ] One MultiMesh per type mesh; type silhouette stays readable at a glance (pillar 5).
- [ ] Perception: dormant → suspicious (walks to the last noise) → hunting; sound first, sight second (fog and
      night shorten sight). Replaces the interior spike's simple wake rules.
- Assets (desktop): Runner / Armored / Bloater meshes + VAT clips (hand-keyed or Mixamo when needed).

### 1.3 Player in danger
- [ ] Player HP, hits from zombies (the horde already counts them), downed state, revive or restart.
- [ ] Armor and weight for the player (GDD §7), stamina-free for now.
- [ ] Damage feedback: screen edge, hit sound, short slow-mo on low HP (tunable, can be off).

### 1.4 Game feel (GDD §6 "Boxhead part")
- [ ] Hit-stop, knock-back along the bullet, muzzle flash, shell casings, camera shake (tunable, off option).
- [ ] Kill chain counter (score → influence later), hit markers, crosshair per weapon spread.
- [ ] Audio pass 1: CC0 gun, impact, zombie and blast sounds; noise radius matches what you hear.

### 1.5 Combat test arena — "one night on the roof"
- [ ] The arena **is** the base roof (J 2026-10-29), so it carries over into the night horde (1.10).
- [ ] A 10-minute defence: waves from several entrances, ammo crates, a barricade that can be
      broken, both grenades, the four zombie types mixed per wave (data-driven wave table).
- [ ] Telemetry hooks (local only for now): time alive, kills per weapon, ammo used, hits taken.

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
