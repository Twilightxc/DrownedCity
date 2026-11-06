# docs/handoff-to-desktop

- **PR:** #66 (pushed? yes)
- **Machine:** laptop (ASUS, Intel Arc 140V) → desktop (RTX 4080)
- **Base:** main @ 10da5da
- **Updated:** 2026-11-06

This note replaces `docs-arc-to-desktop.md` (PR #64), which still listed #60–#63 as open and predates #65.

## J asked
"เตรียมส่งมอบงานต่อให้อีกเครื่อง" (earlier: "ทำงานโค้ดทั้งหมดก่อนส่งต่อเครื่องdesktop").

## State
Everything from the laptop is merged: PRs #52–#65. There are no open PRs and no unpushed branches. On main @ 10da5da:
GUT 244/244, and arena wave 6 `--auto-shoot` in GL has no errors (checked on the laptop after the last merge).

What the laptop added after gate 1.G (details in `docs/PHASE1.md` → "J's bug list after 1.G", and `docs/DECISIONS.md`):
- Teammates:
  - revive the player and each other, throw frags, take gas and fire damage
  - pick their stance from the cover
  - under Hold fire, knife a zombie in reach
- Melee: everyone has a knife (X / pad R3), Jess has the axe, `?melee=axe` for the player. One quick-use melee slot
  per fighter (DECISIONS).
- The 8-slot orders wheel with icons: Follow / Sneak-follow / Hold here / Stay still × Fire at will / Hold fire /
  Quiet only / Melee only. The team cards show each teammate's orders.
- HUD:
  - the weapon panel at the bottom right
  - downed badge and crosshair
  - no reload ring on bodies
  - barricade HP bar, shake and splinters
  - the top right shows only the wave line
- Esc / pad Start pause (Resume, Restart, controls). Tuning is F4 only now.
- A finished night pauses on its summary, with a Play again button (R / pad X / Enter / click).
- Zombies leave the dead player for a teammate. The water by buildings has thin lapping foam.

Pad layout now:
- R3: knife
- RB: next gun
- LB: camera (one way)
- Start: pause
- Back: debug overlay

## Next on the desktop
1. Pull main. On the laptop, J's GitHub Desktop checkout was still at e96d7dd; the desktop's is likely behind too.
2. **Animations** (J's bug list):
   - 4: weapon switch
   - 6: death clip; the downed pose must not freeze
   - 11: stand → prone
   - 12: crouch → prone
   - 14: side roll while prone
   - 15: prone crawl, rifle across the elbows
3. **Melee:**
   - knife and axe models
   - a light slash clip (knife) and a heavy one (axe), standing and crouched, replacing the placeholder swipe
     (`SpikePlayer._build_swipe` / `_update_swipe`)
   - the hit lands at `MeleeConfig.windup_sec`: knife 0.12 s, axe 0.25 s
4. **Melee sounds** (CC0 packs): knife and axe swing / hit. Add `swing_sfx` / `hit_sfx` to `MeleeConfig` and play
   them on `SpikePlayer.meleed(cfg, hit)`.
5. **Gun icons:** a side view per gun from `tools/blender/kit_guns.py` into `WeaponConfig.icon`. The weapon panel
   shows the name until then.
6. Optional: more barricade stages (`prop_barricade_*_N.glb` in `kit_props.py`). The code takes any count.

## Waiting on J
- J sent the 1.6 citizen spec on 2026-11-06: **`docs/CITIZENS_1_6.md`**. It holds J's spec, plus Claude's
  proposals for the parts J asked to have designed (diving specializations, community skills and books, combat
  classes, two unlock goals, trait names). J approved them all and answered every open question (§9 there,
  PR `docs/citizen-answers`). Part B (1.6 SimCore) starts from it.
- Arc playtests of #60–#65. The PRs list what to check.

## Next session must know
- Cover for crouched fire must be ≤ 0.85 m. The crouched muzzle is 1.0 m (`MovementConfig.muzzle_height_m`); the
  AC units, at 0.95–1.0 m, are a coin toss.
- `test_feel`'s time-scale test uses wall-clock delays and can fail once under load; a rerun passes.
- GL screenshots without playing: run a `SceneTree` script with `-s`. It should:
  1. instance `arena_spike.tscn`
  2. wait about 90 frames
  3. save `root.get_texture().get_image()`

  Button shortcuts only react to real key / joypad events, not to `InputEventAction`.
- A Python heredoc in this environment's Bash mangles a backslash at the end of a line, and `\n` inside strings.
  Write the script to a file with the Write tool instead.
- The laptop's Godot 4.7.2 for GUT lives in the session scratchpad. It was downloaded with J's OK.
