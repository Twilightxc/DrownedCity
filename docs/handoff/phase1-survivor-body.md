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
- 4 new tests, 191 total, all passing on desktop.

## Not done / next
- A3: keys for crouch (C), prone (Z), sprint (Shift), roll (Space) + stamina; SurvivorView already has
  `stance`, `sprinting`, `rolling` flags.
- Not measured on the Arc.

## J must test
- `?spike=poses`: do the clips read? Especially high ready vs port arms, prone / crawl, roll, reloads.
- `?spike=arena`: walk, aim, switch guns 1–4, reload (R); get downed. Does the body face the aim and do the legs
  step backwards when backing away?

## Next session must know
- Rebuild: `blender -b --factory-startup --python tools/blender/kit_survivor.py`. Clip names are listed in
  SurvivorView's constants; a new clip needs both.
