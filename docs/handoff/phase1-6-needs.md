# phase1-6/needs

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** `phase1-6/traits` (PR #74), which sits on `phase1-6/skills` (PR #73). Merge #73, then #74, then this
- **Updated:** 2026-11-07

## J asked
"next" → 1.6 step 3: needs (GDD §3 "สถานะร่างกายและจิตใจ": fatigue, hunger / thirst, injury, sickness, infection).

## Done
- `data/sim/needs.json`: every rate and threshold (Claude's numbers unless the note says GDD).
- `sim/survivor_needs.gd` (state per survivor), `sim/need_rules.gd` (rules).
- Hourly tick `SimState.advance_hour()`; `advance_day` = morning upkeep + 24 ticks. Until 1.7 a survivor sleeps
  22–06 and works the rest (`schedule`); `needs.activity` overrides it ("mission", "idle").
- Morning: hungriest / thirstiest eat and drink first, a partial meal takes part of the hunger; medicine for heavy
  injuries then the sick; sickness spreads; an antiviral cures an infection.
- Infection: bites (`NeedRules.on_bitten`, fed later from `FighterHealth.bites`), 72 h, then the player chooses
  exile / quarantine (3 more days, then they turn) / end their life (`NeedRules.resolve_infection`).
- Effects: max-stamina muls in `BuildRules.mods`, perk `unfit` (heavy injury, sick, infected past the deadline).
- Stock gains `medicine` (start 2) and `antiviral`. The old flat hunger / thirst health loss is gone: hunger starves
  (0.5 HP/h at 100), thirst means flood water and a sickness roll. Save schema 4.
- 20 new tests, 294 passing on desktop.

## Not done / next (1.6)
1. Influence, rank points, status ladder, leaders.
2. Community skills + books, combat classes.
3. Wire live stats to fighters (and bites → `on_bitten` after a night).
- Rain exposure waits for weather (1.11); rotten food for food spoilage; spores for the spore zones.

## J must test
Nothing to play (SimCore). Read `data/sim/needs.json`: all numbers are a first guess.
