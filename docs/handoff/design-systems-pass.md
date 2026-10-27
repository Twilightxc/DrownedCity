# design/systems-pass

- **PR:** #12, CI green (run #35), ready to merge
- **Machine:** desktop (RTX 4080)
- **Base:** main @ `409f69b`
- **Updated:** 2026-10-27

## J asked
J's list (file `C:\Users\usEr\Documents\DrownedCity.md` on the desktop, not in the repo): building themes by
occupant (nest, infested, human factions, friendly enclave, raft community, rooftop hot spots, military/medical
crates, airdrops); advice on map size and environment destruction; immersion; building construction; trait
design; weapon stat structure + damage balance + classes (AR, Rifle, Sniper, Shotgun, Pistol, SMG, LMG,
grenade launcher, flamethrower; AK47, M16, M1911); attachments, ammo, grenades, mortar, mounted weapons, UI,
base management, quests, item farming, drops, ragdoll (flying limbs, corpses), explosion and fire effects,
more detailed character models.

J's decisions (2026-10-27): "Ragdoll: แบบปลอมตามข้อเสนอ ปืนใช้ชื่อกึ่งสมมติ เพิ่มการวัดเอฟเฟกต์ไฟ ระเบิด และชิ้นส่วน
กระเด็นเข้าไปใน spike 0.7 AR (5.56/7.62 อัตโนมัติ) และ Rifle (DMR semi .308) ตรงกับที่คิด เพิ่มเติม เรื่องระดับน้ำตาม
ฤดู ฤดดูร้อนไม่ได้ลดจนเห็นถนนแต่แค่ลดจนเห็นอีกชั้นได้และสำรวจได้ ฤดูฝนน้ำก็ขึ้นกลับถ้าเกิดอยากใช้ก็เตรียมเครื่องสูบออก
ตลอดหรือก่อปิดหน้าต่างถาวร เรื่องระบบสำรวจในอาคาร"

Follow-up (2026-10-27): "ข้อเสนอสำรวจในอาคารด้านบน: เพิ่มเป็น spike ในเฟส 0 / ฤดู: เดิม GDD มี 3 ฤดู ยึดตามเดิมฉันแค่บอก
รายละเอียดเพิ่ม / อยากทำตัวเต็มออนเว็บเลยได้ไหม ค่อยอัพเกรดก่อนขายสตรีมอีกที แล้วถ้าอัพเกรดอยากทำให้งานภาพดูดีกว่านี้ทำได้ไหม
ถ้ายกเครื่องเปลี่ยนใหม่หมด"

## Done
- `docs/GDD.md`: §3 traits table; §4 floor holding (pumps or sealing) + construction; §5 interior exploration
  (proposal); §6 weapon schema, class stats, ammo, attachments, payloads, fake ragdoll, fire/explosion
  effects; §9 enemy HP; §10 seasons (2, one floor apart), map size, occupants, airdrops, destruction, loot,
  quests; §13 character detail budget + immersion; §14 UI screens; §17 scope note + demo cut proposal.
- `docs/PHASE0.md` 0.7: effects items + harder pass condition. `docs/DECISIONS.md`: 7 rows.
- Follow-up: new spike 0.8 (interiors + cutaway) in PHASE0 and GDD §17 (Phase 0 33 → 39 h); seasons back to 3
  with J's one-floor details.

## Not done / next
- J reviews the demo cut list (§17); the hour estimate there is not updated for the new systems (+80–100 h, rough).
- Platform: J decided "เหมือนให้เล่นเดโม่ฟรีออนเว็บ พออัพเกรดบนสตรีมก็ขาย อดลดเว็บลงแบบทดลองเล่นแทน" → written to
  CLAUDE.md (platform plan), GDD §1, DECISIONS. Visual upgrade = Forward+ High + asset detail + water/effects;
  a full art overhaul only after EA feedback (advice, not decided).

## J must test
Nothing. Docs only.

## Next session must know
- Touches `CLAUDE.md`, `docs/GDD.md`, `docs/PHASE0.md`, `docs/DECISIONS.md`. Other branches editing DECISIONS: keep both sides,
  newest first.
