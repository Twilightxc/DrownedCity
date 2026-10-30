# fix/roof-gaps

- **PR:** opened with this commit (pushed: yes); J merges
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `05fd10a` (PR #29 merged; PR #30 Phase 1 plan open, docs only)
- **Updated:** 2026-10-29

## J asked
Two roof screenshots: "สองจุดนี้เดินผ่านไม่ได้" (between the two AC units by the east parapet; between an AC unit
and the sandbags at the south-east edge).

## Done
- Cause: `Style15Level.nav_obstacle_rects` blocked every 1 m cell a prop touched. Two 1.3 m AC units 1.7 m apart
  became one 6-cell wall; AC3 and Sandbags4 touched diagonally, closing the way between them.
- Fix: `Style15Level.footprint_cells` blocks the cells whose centre is inside the footprint + 0.2 m (at least
  the centre's cell). Every prop shrank to the cells under it; both gaps are open (2 cells between the ACs).
- 3 tests (127 total).

## Not done / next
- Zombies steer by their centre, so they may brush up to ~0.3 m into a prop's edge; fine for now.
- Then Phase 1 step 1.1 (weapons from data).

## J must test (after merge, Chrome, Ctrl+Shift+R)
Default page or `?spike=style`: walk between the two AC units by the east parapet, and between the AC unit and
the sandbags on the east edge.

## Next session must know
- `docs/arc-handoff` is obsolete; delete it.
