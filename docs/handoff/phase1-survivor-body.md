# phase1/survivor-body

- **PR:** #43 (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 85569cf
- **Updated:** 2026-11-03

## J asked
"Start A2": 1.5+ A2 survivor body. From the plan: "สร้างโมเดลฝั่งมนุษย์ แอนิเมชั่นท่าทางรีโหลด ยืน เดิน ท่านั่งยอง ท่านอน";
sprint carry: "ปืนพกหรือ smg ... ถือวิ่งแบบชี้ปลายขึ้นฟ้า ถ้าเป็นปืนยาวก็พาดข้อพับแขนวิ่งแบบทหาร".

## Done
- `tools/blender/kit_survivor.py` → `assets/models/survivor.glb`: 288 tris, 13 bones, 16 hand-keyed clips.
- `game/survivor_view.gd`: lower / upper layers (Blend2 bone filter), clip speed from movement, reload clips
  stretched to reload_sec, gun on hand_r with a hold per clip (aim level, high ready up, port arms across).
- `SpikePlayer.survivor_body` (on): the body replaces the capsule; downed / dead plays `downed`.
- `?spike=poses`: every clip labelled (`game/spikes/pose_spike.*`). Picture: `docs/art/09_survivor_poses.png`.
- J: "ท่าจับปืนแขนซ้ายไม่จับปืนเลย" → `game/left_hand_ik.gd` two-bone IK to `GunModel.support` (kit_guns.py
  writes it); the rifle aim keeps the grip hand at the chest and the pistol arms meet on the centre line so the
  left arm reaches. Off for reloads, roll, downed.
- J: "ท่ายืนปกติ...ขาอีกข้างควรอยู่ข้างหลัง / ท่านั่งยิงเข่าอีกข้างต้องแตะพื้น / ท่านอนยิงปลายเท้าต้องชี้ออกนอกตัว" →
  idle shooting stance (right foot back), crouch_idle is a kneel, prone feet turned out (and the prone legs now
  spread with ry; rz had twisted them).
- 6 new tests, 193 total, all passing on desktop.

## Not done / next
- A3: keys for crouch (C), prone (Z), sprint (Shift), roll (Space) + stamina; SurvivorView already has
  `stance`, `sprinting`, `rolling` flags.
- Not measured on the Arc.

## J must test
- `?spike=poses`: do the clips read? Especially high ready vs port arms, prone / crawl, roll, reloads.
- `?spike=arena`: walk, aim, switch guns 1–4, reload (R); get downed. Does the body face the aim and do the legs
  step backwards when backing away?

## Next session must know
- Skeleton modifier results only exist inside `Skeleton3D.skeleton_updated`; read bone poses there to check the IK.
- Rebuild: `blender -b --factory-startup --python tools/blender/kit_survivor.py`. Clip names are listed in
  SurvivorView's constants; a new clip needs both.
