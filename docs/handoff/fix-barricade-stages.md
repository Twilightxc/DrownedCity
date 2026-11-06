# fix/barricade-stages

- **PR:** #61 (pushed? yes)
- **Machine:** laptop (ASUS, Arc 140V)
- **Base:** main @ 924dab5 (PR #60, the water, is still open; no shared files)
- **Updated:** 2026-11-06

## J asked
"ทำต่อ" after PR #60. Bug list item 18 (2026-11-05): barricades should show damage by level. 3 stages exist;
make them clearer, or add more.

## Done
- `Barricades.stage(id, stages)` splits the HP into equal stages. It replaces the hard-coded thresholds in the
  arena.
- Arena (`_update_barricade_meshes`):
  - Every hit shakes the barricade for 0.15 s.
  - Dropping a stage swaps the kit piece, as before, and now also bursts small splinters.
  - An HP bar shows over the barricade for 3 s after each hit, with a notch per stage. It is green, then
    yellow, then red by stage, and fades out.
- 1 new test, 239 total, all passing. Arena wave 6 `--auto-shoot` in GL: no errors. Picture:
  `docs/art/20_barricade_stages.png`.

## Not done / next
- More stages: more `prop_barricade_*_N.glb` pieces in `tools/blender/kit_props.py` (desktop); the code takes
  any count (`BARRICADE_PIECES[kind].size()`).
- The axe (second demo melee weapon).

## J must test
- `?spike=arena`, let the zombies break a barricade:
  - Is the damage readable now: bar, shake, splinters?
  - Is the splinter burst at each stage too big?
- Should the bar stay up all the time instead of 3 s after a hit?
