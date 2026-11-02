# phase1/game-feel

- **PR:** opened with this commit (pushed: yes); J merges
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `00f411c` (1.3 merged as PR #34)
- **Updated:** 2026-11-02

## J asked
"ขอทำงานโค้ดที่ยังค้างอยู่" → the code-only work left, in plan order: Phase 1 step 1.4 game feel first.

## Done (details in `docs/PHASE1_RESULTS.md` 1.4)
- Knock-back (`WeaponConfig.knockback`, `EnemyConfig.knockback_mul`, `Horde.knock`; grenades shove too).
- `TimeControl` (one owner of time_scale), hit-stop on multi-kills; the 1.3 slow-mo now asks it too.
- `ScreenShake` via the camera's h/v offset; `MuzzleFx`; `CasingFx`; `KillChain` (cap ×10); `CrosshairHud`.
- `data/fx/feel.tres`; F4 switches for each effect.
- 167 GUT tests pass (5 new); desktop GL 60 FPS, 71–89 draws.

## Not done / next
1. Audio pass 1 (CC0 gun, impact, zombie, blast sounds + the 1.3 hit sound): needs J's OK per download.
2. 1.5 combat test arena "one night on the roof" (code only).
3. The unexplained 49–62 ms frame after the first incendiary blast (0.7 part 4 note).
4. Desktop: gun / attachment / zombie-type meshes, Armored helmet drop.

## J must test (after merge, Chrome, Ctrl+Shift+R)
`?spike=twinstick`: shoot into the crowd with each gun. Do zombies get shoved (shotgun most, Armored least)?
Hit-stop on a multi-kill, shake, muzzle flash, casings, crosshair opening as you hold fire, hit / kill
markers, "xN chain". F4 turns each one off. Too much or too little?

## Next session must know
- Only `TimeControl` should write Engine.time_scale in a spike scene.
- `SpikePlayer.shot(gun)` and `hit_confirmed(kills)` signals; `Horde.apply_hits(..., knocks)`.
