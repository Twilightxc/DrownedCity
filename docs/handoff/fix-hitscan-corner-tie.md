# fix/hitscan-corner-tie

- **PR:** #11, CI green (run #32), ready to merge
- **Machine:** desktop (RTX 4080)
- **Base:** main @ `cb80807`
- **Updated:** 2026-10-27

## J asked
"แก้ hitscan corner tie แบบ conservative (เช็กทั้งสองช่องข้างมุม) ทั้ง hitscan.gd และ nav_grid.gd พร้อม unit test
เป็น PR เล็กใน worktree"

## Done
- Copilot finding from PR #3: when a ray passes exactly through a cell corner (`t_max_x == t_max_y`), the
  DDA always stepped y first. A wall at the y-side cell blocked the ray, but the mirrored wall at the x-side
  cell didn't.
- `NavGrid.ray_distance` and `Hitscan.cast` now handle the tie the same way: the ray is blocked if either
  side cell is blocked; otherwise it steps diagonally. The new `NavGrid.blocks_ray(cell)` holds the
  in-bounds + blocked check both functions use.
- Tests: all 4 diagonals × both side cells (nav grid), the open corner, and the hitscan mirror case. They
  fail on the old code (x-side walls let the ray through). GUT 46/46.

## Not done / next
- Nothing on this branch.

## J must test
Nothing to feel: the case needs an exact float tie, so it never shows up in normal play.

## Next session must know
- Side effect by design: no shooting or seeing through the gap where two walls meet diagonally.
