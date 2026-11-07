# phase1-6/live-stats

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ b21ab8c
- **Updated:** 2026-11-07

## J asked
"next" → 1.6 last code step: wire the survivor build into the fighters, and the arena's results back into SimCore.

## Done
- `combat/fighter_build.gd`: `BuildRules.mods(s)` as fighter numbers: max HP, stamina max / regen, sprint and roll
  cost, step noise, revive rate, melee / gas / own-blast damage taken, extra grenades; per gun class spread (× sway:
  no sway system yet), recoil, reload time, wear, fire rate. No survivor = no change.
- Hooks: `FighterHealth.apply_build` (+ `max_hp`), `FighterMotion.apply_build` (+ `stamina_max()`),
  `Gun.apply_build`, `SpikePlayer.set_survivor(s)` (name, build, Grenadier grenades). A reviver's `revive_speed`
  speeds a revive (Medic 2×). The configs stay untouched, so F4 tuning still works.
- `sim/night_rules.gd`: a night → shooting XP (shots, gun kills), influence (kills, night won), `horde_nights`
  (Hardened), bites → infection roll.
- Arena: a session-long community (`ArenaSpike.community`, `SimState.new_game`); the player is survivor 1, the
  teammates 2 and 3. A founder without a class gets the one that fits their first gun. F3 shows each fighter's
  build; the run summary adds a line per survivor. `?community=0` = plain fighters as before.
- 9 new tests, 328 passing on desktop. Arena scene runs (no script errors).

## Not done / next
- Melee stats (melee off). Sway as its own system. Class actives (abilities) need input + VFX: later.
- The community lives only for the browser session (no save in the arena). Arena deaths do not kill the survivor.
- 1.6 code is done after this; 1.7 (base) is next.

## J must test
Arena, F3: three names with background / class / traits and their HP, stamina, spread / reload multipliers.
Play a night: the summary lists each survivor's influence, levels and traits gained. Play again: same people,
XP carried over (5 won nights → Hardened). Does a tired/hungry-free founder feel the same as before?
