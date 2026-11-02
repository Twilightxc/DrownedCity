# Phase 1 results

Measured numbers and J's verdicts per milestone (plan: `docs/PHASE1.md`). Device/browser on every row; J's Arc
laptop is the pass/fail reference. New rows go at the top of each section.

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
