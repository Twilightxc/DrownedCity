# phase1-6/status

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 017873f
- **Updated:** 2026-11-07

## J asked
"next" → 1.6 step 4: influence, rank points, status ladder (stranger → member → outstanding citizen), leaders
(6 types, one at a time, can step down; status is never lost).

## Done
- `data/sim/status.json`: influence rates (day in base 5, good-spirits day +3, mission 20, kill 0.5, horde night 10),
  ladder thresholds (member 50, outstanding 600), the 6 leader types. All numbers Claude's.
- `sim/status_rules.gd`: `earn` (pool + the earner's rank points; Well Liked +10 %), `promote` (up only), `spend`
  (pool only), `tick_day`, `appoint` (outstanding only; replaces a sitting leader), `step_down`, `leader`, perks
  `stranger` / `outstanding_citizen` on the build.
- Founders start as members; newcomers (`add_survivor`) as strangers. The morning tick pays a day in the base.
- Save schema 5 (an old save: everyone a member with 0 points, no leader).
- 11 new tests, 305 passing on desktop.

## Not done / next (1.6)
1. Community skills + books (they decide which leader types a survivor may take; `appoint` accepts any type until
   then), the outstanding-citizen half-strength buff, combat classes (picked on becoming a member).
2. Wire live stats to fighters; kills / bites / horde nights from the arena into SimCore.

## J must test
Nothing to play (SimCore). Read `data/sim/status.json`: is ~a week to member and ~a month to outstanding right?
