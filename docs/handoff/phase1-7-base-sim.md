# phase1-7/base-sim

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ cefc104
- **Updated:** 2026-11-07

## J asked
"next" → 1.7. J picked the "survival set" (sleeping, farm, infirmary large; water, kitchen, watchtower small) and the
5-step order (PHASE1 1.7). This branch is step 1: the base in SimCore.

## Done
- `data/sim/rooms.json`: 6 rooms × 2 tiers (build cost, build hours, beds, queue size, work speed, per-day output,
  skill needed), 6 recipes, meal morale, no-bed sleep. Slots 3 large + 3 small (GDD said 2 + 4: flag for J).
  Start: tents + rain barrels standing. All numbers Claude's.
- `sim/room_state.gd`, `sim/base_rules.gd`: build / upgrade (materials now, work hours from whoever works the slot;
  the clinic needs a Medicine survivor), demolish, queue / cancel (inputs back), assign, `work_hour`, per-day
  output, beds, `hour_mods` (bed or not for sleepers, infirmary bed for the hurt).
- Hour tick: assigned survivors work during the schedule's work hours; the heavily hurt or sick rest instead.
  Sleep: a cot +25 %, no bed −50 %. Infirmary +50 % / +100 % healing. Watchtower trains shooting.
- Morning: rain barrels first, cooked meals before rations (+3 morale). Stock adds herbs and meals. Save schema 7.
- Old tests that fill every resource keep meals at 0. 17 new tests, 345 passing on desktop.

## Not done / next
- Step 2: utility AI (who works where, when to sleep / eat / rest) instead of the schedule + manual assignment.
- Power isn't in the demo set: no electricity costs.
- Community-skill room bonuses (Gardening food_output etc.) are not applied to production yet.

## J must test
Nothing to play (SimCore). Read `data/sim/rooms.json`; decide 3 + 3 slots vs the GDD's 2 + 4.
