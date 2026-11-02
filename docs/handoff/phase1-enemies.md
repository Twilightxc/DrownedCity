# phase1/enemies

- **PR:** opened with this commit (pushed: yes); J merges
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `39b1458` (1.1 guns merged as PR #32)
- **Updated:** 2026-11-02

## J asked
"next" after 1.1 → Phase 1 step 1.2, enemy types and perception (`docs/PHASE1.md`).

## Done (details in `docs/PHASE1_RESULTS.md` 1.2)
- `EnemyConfig` + `data/enemies/` Walker, Runner, Armored, Bloater; `HordeConfig.types` + `spawn_mix`.
- `Horde`: type per agent (HP, speed, armor, hit slow, stagger, sight), `state` dormant / suspicious / hunting,
  `hear()`, `perceive()`, a shared noise flow field; deaths carry type + body scale.
- Look per type = body scale + tint on the shared VAT models (renderer + corpses).
- Bloater gas: `GasField` + `GasFx`.
- Interior hordes moved onto the new perception (`dormant` array is gone).
- 152 GUT tests pass (10 new); desktop GL 60 FPS, 72–78 draws; horde update same as main.

## Not done / next
- Meshes per type + Armored helmet drop (desktop, Blender).
- Gas damage to the player, and fire burning the gas: 1.3 (player HP).
- Then 1.3 player in danger.

## J must test (after merge, Chrome, Ctrl+Shift+R, F3)
1. `?spike=style`: can you tell Walker / Runner / Armored / Bloater apart at a glance? (F3 "Types" shows counts.)
   Pistol on an Armored (weak), DMR (full). A Bloater dies → green cloud.
2. `?spike=interior&storey=2`: shoot once in the corridor; sleepers further away should walk toward the sound
   (not straight at you); ones that see you hunt.

## Next session must know
- `Horde.dormant` is gone: use `Horde.state` (`Horde.State.DORMANT/SUSPICIOUS/HUNTING`).
- `Horde.spawn(p, type, state)`; `Horde.awake_count()` = suspicious + hunting; `hunting_count()`.
