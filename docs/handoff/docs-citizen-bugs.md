# docs/citizen-bugs

- **PR:** not opened yet (GitHub was unreachable from the laptop when this was written; push + PR when it's back)
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `810e7f8` (gate 1.G merged as PR #51)
- **Updated:** 2026-11-05

## J asked
Two files: `1.6รายละเอียดระบบพลเมืองดีเด่น.txt` (answers to the citizen-system questions) and `รายงานข้อผิดพลาด.txt`
(18 bugs from the 3 arena nights), plus: "ระบบผู้นำ ทักษะหลัก ภูมิหลังทักษะเฉพาะ add on special ระบบtraitของตัวละคร
เพิ่มเติม community skill อ่านหนังสือ add on special จะแจ้งภายหลัง".

## Done
- GDD §3 (citizen system), §11 (influence pool + personal rank points), §12 (leader quests, personality).
- `docs/PHASE1.md`: the 1.6 citizen-system tasks, and J's 18 bugs grouped by kind and machine.
- DECISIONS row.

## Not done / next
1. Fix the code bugs, starting with the teammate group (1, 2, 5, 7), then the HUD group (3, 9, 16) and 8.
   Items 10 (hold-fire behaviours + a wider orders wheel) and 17 (weapon UI) need a short design with J first.
2. Desktop: the animation items (4, 6, 11, 12, 14, 15) and barricade pieces for item 18.
3. 1.6 SimCore day + citizen system; J will send the buffs, leader system, skills, traits, community skills, books.

## J must test
Nothing (docs only).

## Next session must know
- `docs/laptop-handoff` and `docs/arc-handoff` are obsolete; delete them in GitHub Desktop or the web
  (the laptop's permission rules blocked `git push --delete`).
