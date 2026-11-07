# phase1-7/life-ai

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 62ae164
- **Updated:** 2026-11-07

## J asked
"next" → 1.7 step 2 (PHASE1 1.7): utility AI daily life in SimCore, replacing the sleep 22–06 schedule and the
need to assign everyone by hand.

## Done
- `data/sim/life.json` + `sim/life_rules.gd` (LifeRules): every hour, every survivor not on a mission scores
  sleep / rest / work (per room) / read / exercise / socialise / idle = own need × base need × traits, + stick
  (0.1 for going on) + jitter (≤ 0.05, seeded by `SimState.rng_for(-id)`). Decided in id order; crowding splits
  a room's score by 1 + people already there.
  - Sleep: fatigue curve + 1.0 in the night window (22–06; Night Owl 02–10); asleep until fatigue < 5.
  - Rest: the heavily hurt, sick or held (quarantine / waiting for a choice) rest by day, sleep at night; nothing else.
  - Work: building 1.0, a runnable job 0.4–1.0 by shortage of its output (`stock_want_per_person`), a free
    watchtower post 0.4. Community skill fits the room ×1.3. Player assignment = pinned (only that room, ×1.3).
    After an 8 h shift (Workhorse `shift_length` → 10 h) ×0.3.
  - Read (a book or books on the shelf, + evening) → Wits XP; exercise (fatigue < 50) → a quarter of the fitness
    corner's XP; socialise (low morale, evening; a kitchen ×1.3 and twice the morale, 0.5 → 1.0 an hour).
  - Trait weights (Workhorse, Loner, Inspiring, Optimist, Grumpy, Athlete, Asthmatic, Trigger Happy, Pacifist).
- `BaseRules.work_kind` (what a slot offers, read-only), `work_hour(state, s, slot)`. Hurt sleepers get an
  infirmary bed first. `SurvivorNeeds`: `doing`, `doing_slot`, `worked_today` (reset each morning). needs.json
  loses `schedule` (the night window lives in life.json), adds fatigue rates for read / socialise / exercise.
- Save schema 8 (old saves decide afresh). 18 new tests; tests about the morning's morale set `activity = "idle"`
  so daily life stays out. 363 passing on desktop.
- A 48 h timeline (3 survivors, farm + kitchen) looks right: build/work till mid-afternoon, exercise, gather from
  17–18, sleep 22, up at 06; no hour-to-hour flipping.

## Not done / next
- Step 3: the base scene on the arena roof (rooms by tier from a Blender kit, survivors walking to `doing`).
- Repair, shelter from rain and eating as activities wait for their systems (damage 1.10, weather 1.11).
- Community-skill room bonuses (Gardening food_output etc.) still don't change production.

## J must test
Nothing to play (SimCore). Read `data/sim/life.json` for the weights.

## Next session must know
- `LifeRules.options(state, s)` returns every scored option, best first: the Observer's "why" can show it.
- Morning morale tests must keep daily life out (`needs.activity = "idle"`), or socialising adds morale.
