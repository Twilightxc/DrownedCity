# docs/citizen-answers

- **PR:** #67 (pushed? yes)
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ ead1da5
- **Updated:** 2026-11-06

## J asked
J sent the 1.6 citizen spec ("ขอแจ้งข้อมูลก่อนสลับเครื่อง"), then answered the eight open questions:
"1. ตามที่เสนอมาค่าของสายจะค่อยๆ เพิ่มจนเต็มที่ระดับ 7 · 2. 5% · 3. โอเค · 4. ไม่มีปิดเกม แต่จะเล่นต่อยาวๆเรื่อยๆ ·
5. โอเค · 6. เดโม่ใช้ทั้งหมด · 7. โอเค · 8. ไม่มีเสียถ้าลงจากผู้นำก็แค่กลับมาจุดดีเด่นที่ให้บัฟ"

## Done
- `docs/CITIZENS_1_6.md` is now on main. It was in PR #66, but the commit landed after the merge, so this branch
  brings it. J's answers are recorded there: the Claude designs are approved, and §9 holds the answers.
- GDD:
  - §3: status is never lost; one leader at a time
  - §12: no game-ending goals, and the table shows the unlock goals in J's words
  - Legacy: a run ends only if the community falls
- PHASE1 1.6 and DECISIONS are updated, and the desktop handoff note points here.

## Next
- Part B, 1.6 SimCore, from `docs/CITIZENS_1_6.md` §8: the data model and rules first.
