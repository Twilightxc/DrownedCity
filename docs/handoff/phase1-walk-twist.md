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
- 1 new test, 203 total, all passing on desktop.

## J must test
- `?spike=arena`: aim one way and walk sideways, diagonally and backward. The legs should take normal steps; the
  upper body keeps aiming. Does the step rate feel right at walking, crouch and sprint speed?
