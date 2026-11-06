# phase1/weapon-panel

- **PR:** #58 (pushed? yes)
- **Machine:** laptop (ASUS, Arc 140V)
- **Base:** main @ 8511bc1
- **Updated:** 2026-11-06

## J asked
Bug list item 17, "UI อาวุธ". On 2026-11-06 J picked "แผงขวาล่าง" (DECISIONS). After PR #57, J said "เริ่มงานต่อ".

## Done
- `ui/weapon_panel.gd` (`WeaponPanel`, a CanvasLayer drawn in code at the bottom right) shows:
  - the gun in hand: its icon, or its name until there is one
  - the fire mode, with ▸ when the gun has more than one
  - the magazine as pips (a bar above 60 rounds); they blink orange at ≤ ¼
  - rounds in the mag / reserve
  - JAMMED or "Worn N%"
  - grenade type ×count, and the knife
  - slots 1–4: the one in hand is outlined; long guns are dimmed while downed
  - nothing once dead
- `WeaponConfig.icon` (Texture2D, null for now) and `short_name` (set on the four guns).
- The gun text line in the top-right debug box is gone (`_update_status`, `_status_label`).
- Picture: `docs/art/17_weapon_panel.png`.
- 2 new tests, 237 total, all passing. Arena wave 6 `--auto-shoot` in GL: no errors.

## Not done / next
- Desktop: render a side-view icon per gun in Blender (`tools/blender/kit_guns.py`) and set `WeaponConfig.icon`.
- The axe (second demo melee weapon). The rest of the bug list: HUD 3, 9, 16; 8; 13; 18.

## J must test
- `?spike=arena`: does the panel read at a glance mid-fight?
  - the pips
  - the count
  - low ammo blinking
  - a jam
  - the grenade count
- Switch guns (1–4, pad RB): does the slot follow?
- Get downed: is only the pistol slot bright?
- On the Arc: does the FPS hold (it is one more redrawn control)?
