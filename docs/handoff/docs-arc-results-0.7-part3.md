# docs/arc-results-0.7-part3

- **PR:** opened from the laptop with `gh`
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main after PR #19
- **Updated:** 2026-10-28

## J asked
"วัดในแผง Browser เหมือนรอบก่อน" for 0.7 part 3, then "Record, open PR".

## Done
- Web run on build `cdc2193 · #56`, Claude pane (visible, 800×673), calibrated first with `?spike=horde` at 59 FPS:
  - 200 + autoshoot: 60 FPS, 73 draws, 243k prims
  - 300 + autoshoot (80 burning): 60 FPS, 73 draws, 297k prims (1 % under budget)
- `VatModel.part_bounds` works on the web (no fallback warning).
- PHASE0_RESULTS 0.7 is marked pass at 200, and PHASE0 0.7 has the measured line.

## Not done / next
- Full-screen Chrome run (fill rate) and J's look at blasts, limbs and fire.
- 300 zombies need the budget levers (far-split horde shadows, corpse cap) before becoming a target.
- Phase 0 left: 0.8 interiors (desktop, Blender), then the Phase 0 exit review.

## J must test
Optional: `?spike=style&autoshoot=1` in full-screen Chrome; say whether the effects read well.

## Next session must know
An earlier pane attempt read 1 FPS in every scene, even the unchanged `?spike=horde`, while the pane was throttled.
Always calibrate with `?spike=horde` first.
