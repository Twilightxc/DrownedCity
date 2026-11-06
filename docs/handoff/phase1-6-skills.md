# phase1-6/skills

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 9386b99
- **Updated:** 2026-11-06

## J asked
"next" → Part B 1.6 (citizen spec `docs/CITIZENS_1_6.md`). Step 1 of several: core skills + backgrounds in SimCore.

## Done
- `data/sim/skills.json`: 5 core skills (tracks per level 0–7), 4 specializations each, 9 backgrounds,
  XP table, `live_stats` (stats a system reads today).
- `sim/`: `StatMods` (add / mul / perks), `SkillCatalog` (reads the JSON), `SurvivorSkill`, `SkillRules`
  (setup, XP from actions, level-ups, spec choice, modifiers with the second-climb rule).
- `Survivor.background / skills`; a new game rolls a background per survivor (own RNG stream).
- Save schema 2 with a v1 → v2 migration; `SaveCodec.migrations()`.
- 9 new tests (+1 codec), 265 passing on desktop.

## Not done / next (1.6 steps)
1. Traits (GDD §3 + 9 more) and needs.
2. Influence, rank points, status ladder, leaders (6 types, one at a time, step down).
3. Community skills + books, combat classes.
4. Wire live stats to fighters (HP, stamina, sway, recoil, reload, wear…), once a fighter maps to a survivor.

## J must test
Nothing to play yet (SimCore only). Read the numbers in `data/sim/skills.json`; background numbers J left open are
marked "Claude's".

## Next session must know
- Second-climb rule and save v2: DECISIONS 2026-11-06.
