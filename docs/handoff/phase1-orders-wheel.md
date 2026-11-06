# phase1/orders-wheel

- **PR:** #57 (pushed? yes)
- **Machine:** laptop (ASUS, Arc 140V)
- **Base:** main @ 3a2ac1b
- **Updated:** 2026-11-06

## J asked
Bug list item 10, step 2. J picked "วงเดียว 8 ช่อง" (2026-11-06):
- the top half is movement: Follow, Sneak-follow, Hold here, Stay still
- the bottom half is the fire rule: Fire at will, Hold fire, Quiet only, Melee only
- one of each at a time, with icons

Then J said "merge แล้ว" on PR #56, and the agreed order put this next.

## Done
- `RadialMenu`:
  - `icons` (drawn in code)
  - `offset_steps`: turned half a slot, so 4 slots sit above and 4 below
  - `active` (the orders in force, ringed green)
  - bigger (200 px)
- The wheel itself: `twin_stick_spike.ORDERS` + `ORDER_ICONS`, and the arena's `MOVE_ORDERS` / `FIRE_RULES`.
  Picture: `docs/art/16_orders_wheel.png`.
- `TeammateBrain`:
  - `Order { FOLLOW, SNEAK, HOLD, STAY }` and `FireRule { AT_WILL, HOLD_FIRE, QUIET, MELEE }` (replaces
    `hold_fire`), plus `may_shoot(gun)`.
  - Sneak: crouched, no sprinting.
  - Stay: never backs off.
  - Quiet: only guns ≤ `quiet_noise_m` (15 m).
  - Melee: knife only, steps in to a lone zombie within `melee_charge_m` (4 m).
  - Grenades only under Fire at will.
  - Reviving a downed squad member beats every order.
- `Teammate._gun_for_rule`: under Quiet only, it takes out the silenced pistol; back to the long gun at Fire at will.
- Data: the teammates' pistols carry a silencer.
- 5 new tests, 235 total, all passing. Arena wave 6 `--auto-shoot` in GL: no errors.

## Not done / next
- The weapon panel, bug item 17 (bottom right; gun icons from Blender on the desktop).
- The axe: the second demo melee weapon (DECISIONS 2026-11-06).
- The team cards don't show the current orders yet; only the wheel rings them.

## J must test
- Hold Tab. Do the icons read? Are the active orders ringed?
- Try each pair:
  - Sneak-follow + Quiet only: crouched, pistols only?
  - Stay still: no backing off?
  - Melee only: do they go in with knives and back off from 3?
- Get downed under Stay still: do they still come to help?
