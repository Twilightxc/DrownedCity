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
- Stance (J, 2026-11-05: "เพื่อนหมอบหรือนอนราบ ไม่ใช่ทำตามผู้เล่นเสมอไป แต่ตัดสินใจได้เอง ตามความเหมาะสมของสถานการณ์
  เพราะจะมีเรื่องระบบที่กำบังเข้ามาอีก นั่งยองยิงผ่านได้ ยืนยิงผ่านได้"): standing still, every 0.5 s it takes the lowest
  stance whose muzzle clears the low cover toward its target (`MovementConfig.muzzle_height_m` 1.38 / 1.0 / 0.38 m,
  measured on the survivor in GL); prone only with no hunter within 10 m, crouch within 5 m. Crouched (and no
  sprint) while sneaking past sleepers with nobody hunting; kneels to revive; stands to move or look.
- Note for the cover system: the crouched muzzle is 1.0 m and the arena's AC units are 0.95–1.0 m, so crouched
  shooting over them is a coin toss. Cover meant for crouched fire should be ≤ 0.85 m.
- 6 new tests, 224 total, all passing (Godot 4.7.2 headless, laptop). Arena wave 6 with `--auto-shoot` in GL
  for 2400 frames: no errors.

## Not done / next
- PHASE1 bug table: items 1, 2, 5, 7 marked fixed (after merging main with PR #52).
- Later code bugs: HUD (3, 9, 16), 8, 13, 18. Items 10 and 17 need a design talk with J. Animation bugs are desktop.

## J must test
- `?spike=arena`: get downed on purpose. Does a teammate come to you, kneel and get you up? Does the downed line
  name them? With both teammates up, does only one come while the other keeps fighting?
- Let a teammate go down: does the other one help it up?
- Frags: do they throw into packed crowds only, never near you? Is 2 per teammate right?
- Stance: Hold them behind an AC unit or the parapet with zombies far off: do they crouch or go prone where it
  makes sense, and get up when the crowd closes in? Near sleepers with nobody hunting: do they move crouched?
- Bloater gas on a teammate: does its HP drop?
