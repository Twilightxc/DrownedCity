# fix/water-shore

- **PR:** #60 (pushed? yes)
- **Machine:** laptop (ASUS, Arc 140V)
- **Base:** main @ 924dab5
- **Updated:** 2026-11-06

## J asked
"เริ่มงานต่อได้" after PR #59. Bug list item 13 (2026-11-05): "พื้นผิวน้ำข้างตึกแปลกๆ".

## Done
I took the problem to be this: the 1 m soft pale foam band around every building read as a glowing halo, and the
water near buildings was tinted noticeably lighter. Changes in `game/shaders/water.gdshader`:
- Foam:
  - a thin broken line, 0.45 m (`foam_width`), at 55 % strength (`foam_strength`)
  - its edge laps in and out by 0.18 m (`lap_m`, `lap_speed`), out of step along the wall
- A darker wet line against the wall: 0.35 m (`contact_width`), darkened by 45 % (`contact_dark`).
- The lighter tint near buildings: 4 m (was 6), at 35 % strength (was 70 %).
- Cost: a few ALU ops, no new texture reads or passes.

Before / after (GL, same view): `docs/art/19_water_shore_before.png`, `docs/art/19_water_shore_after.png`.
GUT 238/238.

## Not done / next
- If "odd" meant something else (seams, a gap at the wall, footprints that don't match the meshes, the
  backdrop buildings), J to point at it on a screenshot.
- Bug list: 18 (barricade stages), the axe.

## J must test
- `?spike=arena`, several camera angles (Q/E): does the waterline look right now?
- Is the lapping foam too busy or too faint? Tune `foam_strength` / `lap_m` in the water material.
- On the Arc: FPS the same as before?
