# phase1-6/community

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ cb83a7a
- **Updated:** 2026-11-07

## J asked
"next" → 1.6 step 5: community skills + books, the outstanding-citizen buff, combat classes
(`docs/CITIZENS_1_6.md` §6–7).

## Done
- `data/sim/community.json`: 14 community skills (2 book specializations each, leader path, room numbers / perks),
  books (3 days to read), 6 combat classes (weapons, passive, active ability + cooldown). Numbers Claude's.
- `sim/community_rules.gd`:
  - Born with the background's skill at 50 % (boxers never); otherwise an empty slot.
  - Books on the base shelf (`SimState.books`): `skill:<id>`, `spec:<skill>:<spec>`, `leader:<type>`; reading
    takes the copy, the morning tick counts down; Library halves it.
  - `leader_types(s)` (skill path, Teaching = any, plus leader books); `StatusRules.appoint` now checks it.
  - `room_mods(s)` = what the holder brings to their room (1.7); not on their own build.
  - `base_wide(state)`: every outstanding citizen in the base (not on a mission) adds their skill's numbers at half
    strength, stacked. Already live: heal_rate in the hourly tick, community_morale in the morning, read_time.
  - Classes: `needs_class` (member, no class), `pick_class`, `change_class` (room + day cost: 1.7); the passive
    and perks `class_<id>` / `ability_<id>` on the build.
- `StatMods.absorb(other, scale)`. Save schema 6.
- 14 new tests, 319 passing on desktop.

## Not done / next (1.6)
- Wire live stats to fighters (HP, stamina, sway / recoil / reload, class passives, revive speed) and the arena's
  kills / bites / horde nights back into SimCore. That closes 1.6's code.

## J must test
Nothing to play (SimCore). Read `data/sim/community.json`.
