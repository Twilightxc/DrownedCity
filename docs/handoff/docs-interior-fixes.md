# docs/interior-fixes

- **PR:** opened with this commit (pushed: yes); J merges
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `ff77131` (PRs #25 and #26 merged)
- **Updated:** 2026-10-29

## J asked
"บันทึกผล" after PR #26 (stairs never stuck, walls waist-high) was merged.

## Done
- PHASE0_RESULTS 0.8: the two fixes (cause, fix) and the desktop GL numbers.

## Done (2nd commit)
- J's web check of #26 (build `ff77131 · #71`): 60 FPS, 102 draws, 145k with 30 swarming; zombies visible across
  the storey at every angle. The one stop J hit was the closed flight to the flooded storey (by design, no cue).

## Not done / next
- A cue for closed flights (J to pick: "Flooded" prompt, water in the stairwell, or a railing).
- Then the Phase 0 exit review and Phase 1 planning.

## J must test
Nothing for this branch (docs only).

## Next session must know
- `docs/arc-handoff` is obsolete; delete it.
