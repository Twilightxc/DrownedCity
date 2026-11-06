# fix/hud-downed

- **PR:** opening (pushed? yes)
- **Machine:** laptop (ASUS, Arc 140V)
- **Base:** main @ af4466f
- **Updated:** 2026-11-06

## J asked
"เริ่มงานต่อ" after PR #58. From J's bug list (2026-11-05):
- 3: "ไม่มีเป้าเล็งปืนพกตอนล้ม"
- 16: "ไอคอนตอนล้ม"
- 9: "ไอคอนรีโหลดค้างบนศพ"
- 8: "ซอมบี้ตีศพผู้เล่น"

## Done
- 3: the crosshair, and the hidden OS cursor, stay while downed (`CrosshairHud`: not dead instead of alive).
- 16: `FighterHud._downed_badge`.
  - A red badge with a white cross sits 2.8 m over every downed fighter, including the player.
  - Its ring shows the time left, in red, and pulses under 30 %. While someone helps, the ring shows the revive in green.
- 9: dying drops the reload (`SpikePlayer._on_health_state`), and `reload_fill` is -1 for the dead.
- 8: once the player is dead, the horde's main target is a teammate still up or downed (`_main_mate`), and its
  hits land on that teammate. With nobody left, the horde gathers without attacking.
- 1 new test, 238 total, all passing. Arena wave 6 `--auto-shoot` in GL: no errors. Picture:
  `docs/art/18_downed_badge.png`.

## Not done / next
- Bug list: 13 (water by buildings), 18 (barricade stages), the axe. Animation items are desktop.

## J must test
- Get downed:
  - Is the pistol crosshair there?
  - Is the badge over you and over a downed teammate?
  - Does its ring count down, and turn green while helped?
- Die mid-reload: no ring left over the body?
- Die with a teammate still up: do the zombies go for it instead of your body? With everyone dead: no more
  hitting?
