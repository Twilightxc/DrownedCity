# docs/arc-to-desktop

> Superseded by `docs-handoff-to-desktop.md` (2026-11-06, after PRs #60-#65 merged).

- **PR:** #64 (pushed? yes)
- **Machine:** laptop (ASUS, Intel Arc 140V) → desktop (RTX 4080)
- **Base:** main @ 924dab5
- **Updated:** 2026-11-06

## J asked
"ทำงานโค้ดทั้งหมดก่อนส่งต่อเครื่องdesktop". All of the code work from J's bug list after gate 1.G is done on the
laptop. What is left needs Blender, clips or the desktop's audio packs.

## State
Merged (laptop, 2026-11-05/06):
- #52: the citizen system design and J's 18-bug list (`docs/PHASE1.md`)
- #53 / #54: teammates revive, throw frags, take gas, pick their own stance from the cover
- #55 / #56: melee. Everyone has a knife: X / pad R3. Pad: next gun on RB, camera on LB.
- #57: the 8-slot orders wheel. Follow / Sneak-follow / Hold here / Stay still × Fire at will / Hold fire / Quiet
  only / Melee only.
- #58: the weapon panel at the bottom right
- #59: downed crosshair, downed badge, no reload ring on bodies, zombies leave the dead player

Open, waiting for J's playtest and merge (independent of each other):
- #60: the water by buildings, bug 13. J to confirm it is what "odd" meant.
- #61: barricade damage readable, bug 18: HP bar, shake, splinters.
- #62: the axe, Jess carries it; `?melee=axe` for the player.
- #63: the team cards show each teammate's orders.

## Next on the desktop
Pull main first, after J merges #60–#63.

1. **Animations** (J's bug list):
   - 4: weapon switch
   - 6: a death clip; the downed pose must not freeze
   - 11: stand → prone
   - 12: crouch → prone
   - 14: side roll while prone
   - 15: prone crawl, rifle across the elbows, on knees and elbows

   Clips go in `kit_survivor` / SurvivorView like the others.
2. **Melee:**
   - knife and axe models
   - a light slash clip (knife) and a heavy one (axe), standing and crouched
   - these replace the placeholder swipe (`SpikePlayer._build_swipe` / `_update_swipe`)
   - the hit lands at `MeleeConfig.windup_sec` (knife 0.12 s, axe 0.25 s); time the clips to it
   - the `SpikePlayer.meleed(cfg, hit)` signal is there for sounds
3. **Melee sounds** from the CC0 packs:
   - knife swing and hit, axe swing and hit
   - as SfxBank events (`MeleeConfig` has no sfx field yet; add `swing_sfx` / `hit_sfx` like `WeaponConfig`)
4. **Gun icons:**
   - render a side view per gun in `tools/blender/kit_guns.py`
   - set `WeaponConfig.icon`; the weapon panel shows the name until then
5. **Optional, more barricade stages:** more `prop_barricade_*_N.glb` pieces in `kit_props.py`. The code takes any
   count.

## Waiting on J
- 1.6 SimCore and the citizen system: J will send the buffs, leader system, core skills, background special skills,
  traits, community skills and books. Part B starts there.
- Arc playtests of #60–#63, with FPS for the water (#60) and the weapon panel (#58).

## Next session must know
- Cover heights: the crouched muzzle is 1.0 m (`MovementConfig.muzzle_height_m`: 1.38 / 1.0 / 0.38). Cover meant for
  crouched fire should be ≤ 0.85 m; the arena's AC units, at 0.95–1.0 m, are a coin toss.
- `test_feel`'s time-scale test uses wall-clock delays and can fail under load; a rerun passes.
- GL screenshots without playing: a `SceneTree` script run with `-s` (instance `arena_spike.tscn`, wait about
  90 frames, `root.get_texture().get_image().save_png(...)`). To show the orders wheel, call
  `Input.action_press("radial_menu")` first.
- Python heredocs in this environment's Bash mangle a backslash at the end of a line. Don't use backslash line
  continuations in GDScript written that way.
