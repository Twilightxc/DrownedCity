# phase1/melee

- **PR:** opening (pushed? yes)
- **Machine:** laptop (ASUS, Arc 140V)
- **Base:** main @ e230280
- **Updated:** 2026-11-06

## J asked
Bug list item 10 (2026-11-05) and the design talk on 2026-11-06. J picked:
- the orders wheel: one wheel with 8 slots
- under "hold fire": melee self-defence
- melee: build it first, as its own task
- item 17: a weapon panel at the bottom right

Then: "merge แล้ว เริ่มงานได้".
This branch is step 1: melee for everyone. Next come step 2 (the 8-slot orders wheel and its behaviours) and the weapon panel.

## Done
- `combat/melee_config.gd`, `combat/melee.gd` (swing timing, targets in cone / reach / line of sight, damage
  with armor and a ×2.5 silent takedown on a zombie not hunting), `data/weapons/knife.tres`.
- SpikePlayer: `melee_weapon` (knife by default), `try_melee()`, `_update_melee`.
  - The hit lands after the 0.12 s wind-up.
  - No shooting during the 0.45 s swing.
  - A swing costs 8 stamina and makes 2 m of noise.
  - No swing from prone or mid-roll.
  - Signal `meleed`.
  - Placeholder: a pale crescent sweeps across the aim.
- Input `melee`: X / pad R3. The pad's next gun moves to RB. Camera rotation on the pad is LB only (one way).
  The help text is updated.
- Teammates:
  - Under "hold fire", a teammate stands and knifes a zombie that reaches it. It backs off when 3 are within
    `kite_m` (`TeammateConfig.mob_count`).
  - A teammate also knifes a zombie in reach while its gun is empty or reloading.
- 7 new tests, 230 total, all pass. `test_feel` time-scale test is wall-clock flaky (failed once, then passed).
  Arena wave 6 `--auto-shoot` in GL: no errors.

## Not done / next
- No melee sound yet (SfxBank has no knife event; `meleed` is there to hook it).
- Desktop: a knife model and a slash clip (stand, crouch) to replace the swipe.
- Step 2: the 8-slot orders wheel with icons (Follow, Sneak-follow, Hold here, Stay still / Fire at will,
  Hold fire, Quiet only, Melee only). Then the weapon panel (item 17).

## J must test
- `?spike=arena`, X next to a zombie: does the hit feel timed right? Is 3 stabs per Walker right? Sneak up on a
  sleeper: one stab?
- Is the swipe readable? Does no shooting during the swing feel OK?
- Tab → Hold fire, let a lone zombie reach a teammate: does it knife it? Several at once: does it back off?
- Pad: R3 knife, RB next gun, LB camera. Fine?
