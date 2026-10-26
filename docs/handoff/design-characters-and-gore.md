# design/characters-and-gore

- **PR:** not opened. Not pushed: the laptop CLI has no git credentials, so J pushes from GitHub Desktop.
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `5073dbb`. Docs only, no code.
- **Updated:** 2026-10-26

## J asked
New requirements, checked against the plan, then: "Add all 4 requests to the GDD (and the online doc), log them
in DECISIONS, and add spike 0.7 (animated horde + corpses + blood on Arc) to PHASE0."
1. ตัวละครทั้งหมดมีลักษณะเฉพาะ ชายตัวใหญ่กว่าหญิง สีผิว ทรงผมต่างกัน
2. มีแขนขาและแอนิเมชันเคลื่อนไหวสมจริง
3. ศัตรูรูปลักษณ์ต่างกันตามประเภท มีแบบย่อย (ซอมบี้ชาย/หญิง) รวมถึงศัตรูมนุษย์
4. โดนยิงแล้วช้าลงนิดหน่อย (พวกไม่มีเกราะ) เลือดกระเด็น ตายแล้วทิ้งศพ ชิ้นส่วนขาดแบบสุ่ม

## Done
- `docs/GDD.md`:
  - §3 survivor appearance (sex, build, height, skin, hair; stored in SimCore; cosmetic only)
  - §6 hit/death feedback (slow on unarmored, blood, capped corpses, random dismemberment, gore toggle)
  - §9 zombie sub-variants; human enemies use the survivor character system
  - §13 one humanoid rig with 2 bodies, animation plan (people: AnimationTree with an upper/lower split; horde: VAT)
  - §14 corpse/blood caps
  - §16 two new risks
  - §17 hours +48: combat 70, assets 55, animation 40, spikes 33, total ~698; phase 0 is 33 h over 2–3 weeks; spike list item 5
- Online GDD (https://claude.ai/artifact/4cij3hzxQCwe3dT9TdsDVg) has the same edits (doc rev 41).
- `docs/DECISIONS.md`: 6 rows. `docs/PHASE0.md`: spike 0.7 section; header and exit criteria no longer say "four".

## Not done / next
- Spike 0.7 itself. It needs the **desktop** (Blender: low-poly zombie with limbs, VAT bake) and J's Mixamo
  download (zombie walk/attack/hit/death).
- The default numbers (−30 % slow for 0.4 s, ≤ 500 tris per zombie, 6–8 skin tones, 8–10 hair styles, Walker ≥ 4
  variants) are proposals. J can change them.

## J must test
Nothing playable yet. Read GDD §3/§6/§9/§13 (or the online doc) and say if the defaults above are right.

## Next session must know
- `docs/DECISIONS.md` gets new rows at the top in every open branch (PR #5, 0.5, handoff, this one). Resolve by
  keeping all rows, newest first. `docs/PHASE0.md` is also touched by PR #5 and 0.5.
- Spike numbering: 0.6 (save) is still not started; 0.7 can run before or after it.
- Check whether `Decal` works in the Compatibility renderer on 4.7.2 before planning blood pools around it.
