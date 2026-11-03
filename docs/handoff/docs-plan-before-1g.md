# docs/plan-before-1g

- **PR:** #40 (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ d5cffe0
- **Updated:** 2026-11-03

## J asked
"หลังจากปั้นโมเดลปืนเสร็จแล้วอยากให้ลัดขั้นตอนทำสิ่งเหล่านี้ก่อน ใส่เสียงปืน ระเบิด เสียงซอมบี้ สร้างโมเดลฝั่งมนุษย์
แอนิเมชั่นท่าทางรีโหลด ยืน เดิน ท่านั่งยอง ท่านอน กดCนั่งยอง กดZนอน กดshiftวิ่งเร็ว กดcontrolกลิ้งหลบ (มีผลต่อความเเม่นปืน
เสียง ระยะถูกตรวจจับ) ไอคอนบอกตอนรีโหลดปืนอาจเป็นวงกลมและไหลจนเต้มวงกลมบนหัวตัวละคร hud แสดงเลือดสแตมิน่า
เอไอเพื่อนช่วยยิง"
Then: "แอนิเมชั่นตอนถือปืนวิ่ง ถ้าเป็นปืนพกหรือ smg อยากให้เป็นแบบแทคติคอลถือวิ่งแบบชี้ปลายขึ้นฟ้า ถ้าเป็นปืนยาวก็พาดข้อพับแขนวิ่งแบบทหาร"
Answers: CC0 sound packs; roll on Space instead of Ctrl (browser shortcuts); 2 teammates; gate 1.G after this set.

## Done
- PHASE1.md: new section 1.5+ (A1 audio, A2 survivor body, A3 stances, A4 HUD, A5 teammates); 1.G moves after it.
- A2: sprint carry per gun (`WeaponConfig.carry_pose`): high ready for pistol / SMG, port arms for long guns.
- DECISIONS.md: one row.

## Not done / next
- All of it: first the 1.1 gun meshes + attachments (desktop), then A1–A5.

## J must test
- Nothing to play: read the 1.5+ section in docs/PHASE1.md.
