# phase1-6/traits

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** `phase1-6/skills` (PR #73). Merge #73 first
- **Updated:** 2026-11-06

## J asked
"next" → 1.6 step 2: traits (GDD §3 table + the 9 in `docs/CITIZENS_1_6.md` §5).

## Done
- `data/sim/traits.json`: 34 rollable traits + 3 earned (Hardened, Survivor's Guilt, Water Rat), with conflicts.
- `sim/trait_rules.gd`: roll (2–3, ≥ 1 negative, no conflicts), give / take, counters, events, timed traits,
  modifiers; `StatMods.push_for / apply_for` for per-gun-class modifiers (Steady Hands).
- `sim/build_rules.gd`: one StatMods for a survivor (skills + background + traits).
- Day tick reads Big Eater (food), Optimist / Grumpy (everyone's morale), Survivor's Guilt (own morale), and counts
  timed traits down. Save schema 3.
- 9 new tests, 274 passing on desktop.

## Not done / next (1.6)
1. Needs: fatigue, hunger / thirst, injury, sickness, infection.
2. Influence, rank points, status ladder, leaders.
3. Community skills + books, combat classes.
4. Wire live stats to fighters.

## J must test
Nothing to play (SimCore). Check `data/sim/traits.json`; numbers marked "Claude's" were open in the GDD.
