# phase1/walk-twist

- **PR:** #45 (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 94c44b7
- **Updated:** 2026-11-03

## J asked
"ท่าเดินแนวข้างตลกมาก เหมือนเลื้อย ขาเหมือนแอร์แดนเซอร์"

## Done
- `game/hip_twist.gd`: the hips turn to the travel (≤ 100°), the torso keeps its world rotation (aim, gun, IK unchanged).
- SurvivorView: walk / crouch walk = backward + forward clips (BlendSpace1D, synced); past 115° off the aim the
  backward walk (back under 85°); the strafe clips are gone from kit_survivor.py.
- Clip speeds match the real move speeds: walk 4.5 m/s (the old clip was played 3× too fast), sprint 6, crouch 1.7,
  crawl 0.85; the walk has a longer, jog-like stride.
- J round 4: "1.พานท้ายปืนยาวควรอยู่ระดับหัวไหล่ 2.เวลายืนหลังcoverเช่นกล่องขาวในฉากควรยิงผ่านไปได้" →
  1. `game/right_arm_aim.gd` (+ `game/arm_ik.gd`, shared with LeftHandIK): stock in the right shoulder pocket at
     1.40 m, right-arm IK to the grip; bladed rifle stance; long guns scaled 1.05 / 1.0 (kit_guns GUN_SCALE),
     attachments real size × GunModel.part_scale; "stock" points in the kit.
  2. `NavGrid.low_cover` + `metadata/cover_height` (AC 0.95, sandbags 1.0); `blocks_ray / ray_distance /
     line_of_sight / Hitscan.cast / AimAssist.pick` take a height; the player passes its muzzle height, zombie
     sight the survivor's body height (`MovementConfig.body_height_m`).
- 5 new tests, 207 total, all passing on desktop.

## J must test
- Stand behind an AC unit or the sandbags and shoot zombies on the other side; kneel (C): the rounds hit the cover.
- Aim a long gun: the stock should be in the shoulder, the barrel at shoulder height.
- `?spike=arena`: aim one way and walk sideways, diagonally and backward. The legs should take normal steps; the
  upper body keeps aiming. Does the step rate feel right at walking, crouch and sprint speed?
