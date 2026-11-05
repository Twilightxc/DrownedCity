# fix/teammates

- **PR:** #53 (pushed? yes)
- **Machine:** laptop (ASUS, Arc 140V)
- **Base:** main @ 810e7f8
- **Updated:** 2026-11-05

## J asked
J's bug list after gate 1.G (2026-11-05), "Teammate bugs first":
1. "เพื่อนไม่ชุบ / ไม่ปาระเบิด / ไม่หมอบ / ไม่นอนราบ"
2. "เพื่อนไม่โดนดาเมจแก๊ส"
5. "เพื่อนงงเวลาผู้เล่นล้ม"
7. "เพื่อนไม่ชุบผู้เล่น"

## Done
- Gas and burning ground hurt teammates (`horde_spike._hurt_by_ground`).
- Revive moved into SpikePlayer: `start_revive(by)`, `reviver`, `revive_fill()`, time and reach in
  `FighterConfig.revive_sec / revive_radius_m` (2 s, 1.6 m). The HUD ring shows on the player too.
- `Teammate.squad` (shared with horde_spike `_squad`). A teammate picks a downed squad member (the leader first,
  never one someone else is helping), walks or runs there pushing past all but zombies within `revive_kite_m`
  (1.2 m), kneels without firing until it is up. The downed line says "Marco is coming".
- Grenades: `TeammateConfig.throwable` (frag) × `grenades` (2). The brain checks every 0.5 s for ≥ 5 hunters in
  one blast within throw range and line of sight, with every friend outside blast + 1 m; 6 s cooldown.
- Stance: matches the leader when still beside it; crouches when moving with a crouched or prone leader; kneels
  to revive; on a hold, crouches while its target is > 7 m off; stands otherwise.
- 5 new tests, 223 total, all passing (Godot 4.7.2 headless, laptop). Arena wave 6 with `--auto-shoot` in GL
  for 2400 frames: no errors.

## Not done / next
- The PHASE1 bug table is in PR #52 (not merged when this branch started): mark items 1, 2, 5, 7 there after both merge.
- Later code bugs: HUD (3, 9, 16), 8, 13, 18. Items 10 and 17 need a design talk with J. Animation bugs are desktop.

## J must test
- `?spike=arena`: get downed on purpose. Does a teammate come to you, kneel and get you up? Does the downed line
  name them? With both teammates up, does only one come while the other keeps fighting?
- Let a teammate go down: does the other one help it up?
- Frags: do they throw into packed crowds only, never near you? Is 2 per teammate right?
- Crouch (C) / prone (Z) beside them while still: do they follow? Hold here + distant targets: do they crouch?
- Bloater gas on a teammate: does its HP drop?
