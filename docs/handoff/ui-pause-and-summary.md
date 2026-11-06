# ui/pause-and-summary

- **PR:** #65 (pushed? yes)
- **Machine:** laptop (ASUS, Arc 140V)
- **Base:** main @ 410f4f5 (PRs #61-#64 still open; #61 also touches `arena_spike.gd`)
- **Updated:** 2026-11-06

## J asked
"ก่อนอื่น ช่วยลบส่วนอธิบายปุ่มกดตรงมุมบนขวา เหลือไว้เพียงข้อความบอกเวฟ และเมื่อตายหรือจบ ช่วยแสดงผลสรุปไม่ให้ซ้อนทับกับ
ปุ่มเริ่มใหม่ด้วย ซึ่งกดxก็ไม่เห็นเกิดอะไรขึ้น และ ช่วยเพิ่มฟังชั่นกดหยุดเกมด้วยปุ่ม esc"

## Done
- Arena top right: only the wave line ("Calm · wave 1 / 6 in 7 s"). The box grows to fit what it shows, and the
  controls moved into the pause menu.
- End of a night (dead or won):
  - The game pauses and the summary shows alone; `DamageFeedback.hide_messages()` drops the "YOU DIED" line.
  - The summary has a "Play again" button: R or pad X (a `reload` shortcut), Enter or pad A (focus), or a click.
  - On the keyboard, X is the knife, which is why it did nothing; the button names R or X by device.
- `ui/pause_menu.gd` (`PauseMenu`):
  - opened by the new `pause` action, Esc or pad Start
  - Resume, Restart, and the controls for the device in use
  - B, Esc or Start resumes; buttons take focus for the pad
  - it won't open while the orders wheel or a summary is up
- Pad Start no longer opens the tuning panel (F4 only); the help texts are updated.
- `HordeSpike.restart()` unpauses, resets time_scale and reloads, for every restart path.
- 2 new tests, 240 total, all passing.
- GL check: dying, then a real R key on the summary, gives a fresh, unpaused scene. Arena wave 6 `--auto-shoot`:
  no errors.
- Pictures: `docs/art/21_pause_menu.png`, `docs/art/22_run_summary.png`.

## J must test
- Top right: only the wave line?
- Esc mid-fight: does it pause? Do Resume and Restart work, with the mouse and with the pad (Start, A, B)?
- Die, and win once: does the summary sit alone? Do R, pad X, Enter or a click start a new night?
