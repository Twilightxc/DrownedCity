# phase1-8/looks-sim

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 134932d
- **Updated:** 2026-11-07

## J asked
"next" after 1.7 → 1.8 "survivors on screen". J chose: skinned bodies per the GDD; hand-keyed clips now, Mixamo
later; 5 outfit sets × 4 slots with colour + pattern. The 5-step plan is in PHASE1 1.8; this branch is step 1.

## Done
- `data/sim/looks.json`: sex (known names fixed), builds slim / average / muscular / heavy, height by sex, 8 skin
  tones, hair styles by sex, 6 hair colours, facial hair, 5 outfit sets (civilian, worker, medic, soldier, fisher)
  × head / torso / legs / back with pieces, colours and patterns, background → set, 25 % mixing.
- `sim/survivor_look.gd` (SurvivorLook), `sim/look_rules.gd` (LookRules.roll / dress): deterministic from name,
  background and appearance seed on its own stream. `Survivor.look`; new games and BasePreset dress everyone.
- Save schema 10 rolls looks for old saves the same way. Height is parsed from "%.2f" so JSON round-trips exactly.
- 7 tests (`tests/sim/test_looks.gd`); 400 passing.

## Not done / next
- Step 2 (Blender bodies, hair), 3 (outfit pieces + shader), 4 (SurvivorView from the look, `?spike=looks`),
  5 (Mixamo, when J downloads). Nothing on screen changes yet.

## J must test
Nothing to play. Read `data/sim/looks.json`: the outfit sets, pieces and colours are Claude's.
