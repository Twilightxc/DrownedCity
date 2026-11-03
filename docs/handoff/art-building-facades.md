# art/building-facades

- **PR:** #49 (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 745bd16
- **Updated:** 2026-11-04

## J asked
"โมเดลตึก รู้สึกว่าหน้าต่างเยอะและถี่จนเกินไป ไม่เป็นธรรมชาติ ช่วยปรับให้ด้วย เพิ่มระเบียง หน้าต่างหลายแบบ เว้นระยะห่าง
ตัดแสงไฟที่สว่างลอดออกมาไม่ต้องมี"

## Done
- `tools/blender/kit_building.py`: per-building `bay` (3.4–4.2 m, was 2.4), `mix` of window types per column
  (single / tall / double with mullion / small / blank), now and then one floor differs; `balcony` share of columns
  stacks balconies with doors on dry floors (concrete slab, iron railing; decay collapses some or takes the railing);
  `lit` = 0 on all three buildings.
- Rebaked building_base_3f (18982 tris), building_brick_2f (8434), building_concrete_5f (14720): all smaller files.
- CLAUDE.md art direction + DECISIONS: no lit windows. Picture: `docs/art/15_facades.png`.

## J must test
- `?spike=arena`: turn the camera (Q / E). Do the facades read as real buildings now? Too few windows anywhere?
