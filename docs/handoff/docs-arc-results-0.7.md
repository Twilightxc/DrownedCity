# docs/arc-results-0.7

- **PR:** opened from the laptop with `gh`
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `097bd56`
- **Updated:** 2026-10-28

## J asked
"คุณรันวัดผลบน Arc ตามตาราง A ให้หน่อยได้ไหม", then B and C; then "กรอกผลนี้ลงไฟล์บน branch ใหม่แล้วเปิด PR ท่าทางกับ
gore อ่านง่ายแล้ว".

## Done
- Claude ran A, B, C from `docs/arc-handoff` in the Claude app's browser pane on the laptop (visible, 800×673,
  build `097bd56 · #52`). Results are in `docs/PHASE0_RESULTS.md` (0.4b and the 0.7 part 1 and part 2 Arc rows).
  - A: 200 + autoshoot → 60 FPS, 70 draws, 239k prims
  - B: 300 + autoshoot → 60 FPS, 70 draws, 292k prims (3 % under budget)
  - C: 200 packed, no shooting → 60 FPS, 63 draws, 209k prims
- D: J says the zombie motion and the gore read well.

## Not done / next
- One run in full-screen Chrome to confirm fill rate (the pane is smaller than the real target).
- 0.7 part 3 (code only) can run on the laptop after downloading Godot into the scratchpad (ask J first).
- `docs/arc-handoff` can be deleted once this merges; its measurement steps are done.

## J must test
Nothing new. Optionally repeat A in full-screen Chrome.

## Next session must know
300 zombies is at the primitive budget edge; take the levers in PHASE0_RESULTS 0.7 before raising the target.
