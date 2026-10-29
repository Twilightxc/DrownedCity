# docs/interior-fixes

- **PR:** opened with this commit (pushed: yes); J merges
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `ff77131` (PRs #25 and #26 merged)
- **Updated:** 2026-10-29

## J asked
"บันทึกผล" after PR #26 (stairs never stuck, walls waist-high) was merged.

## Done
- PHASE0_RESULTS 0.8: the two fixes (cause, fix) and the desktop GL numbers.

## Not done / next
- J's web check of PR #26 (the build was still deploying when this was written): zombies visible across the
  whole storey at every Q/E angle; the stairs never stick. Add a line to PHASE0_RESULTS 0.8 when J reports.
- Then the Phase 0 exit review and Phase 1 planning.

## J must test
`https://twilightxc.github.io/DrownedCity/?spike=interior&storey=2&wake=1` (Ctrl+Shift+R; build `ff77131` or newer).

## Next session must know
- `docs/arc-handoff` is obsolete; delete it.
