# phase1/arena

- **PR:** opened with this commit (pushed: yes); J merges after #35
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** `phase1/game-feel` @ `9322f3a` (PR #35, 1.4) — **stacked on it: merge #35 first**
- **Updated:** 2026-11-02

## J asked
"1.5 arena" — Phase 1 step 1.5, the combat test arena "one night on the roof" (`docs/PHASE1.md`).

## Done (details in `docs/PHASE1_RESULTS.md` 1.5)
- `ArenaConfig` / `WaveConfig` + `data/combat/arena_roof.tres` (6 waves, 4 entrances, N and E barricaded).
- `WaveDirector` (calm / wave / won, alive cap, refunds), `Barricades` (block movement, flow cost, torn down by
  hunters), `Horde.barricades`, `SpikePlayer.barricades`.
- `arena_spike` (`?spike=arena`, now the default page): pockets at entrances, plank meshes, crates once per
  calm, HUD + banner, summary + restart, `telemetry/run_log.gd` (local JSON lines).
- 172 GUT tests pass (5 new; one found a real wave-ending bug).
- Bot run: whole night in 3:55, ≤ 87 draws, ≤ 160k primitives.

## Not done / next
1. **Gate 1.G (J):** 3 runs on the Arc in Chrome — is combat fun? ≥ 50 FPS at the biggest wave? Tune waves,
   barricade HP (2000), crate uses in `data/combat/arena_roof.tres`, damage in `data/enemies/`.
2. Audio pass 1 (needs J's OK per CC0 download).
3. Desktop: gun / attachment / zombie-type meshes, Armored helmet.

## J must test (after #35 and this merge, Chrome, Ctrl+Shift+R)
Default page (`?spike=arena`): play the night 3 times. Barricades at N and E hold a while; S and W are open;
crates refill once per calm. Note where it felt unfair, boring or too easy, and the summary numbers.

## Next session must know
- The arena overrides `_spawn`; the horde-size slider is hidden there.
- `Barricades` changes force a flow recompute through `_flow_cell = (-1, -1)` in the arena spike.
