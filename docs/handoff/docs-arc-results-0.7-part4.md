# docs/arc-results-0.7-part4

- **PR:** opened with this commit (pushed: yes); J merges
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `c8db6be` (PR #21 merged)
- **Updated:** 2026-10-28

## J asked
J sent two Chrome screenshots of `?spike=style&autoshoot=1` (build `c8db6be · #60`), then: "พอใจแล้ว".

## Done
- PHASE0_RESULTS 0.7 part 4: Arc web rows (Incendiary and Frag, both 60 FPS, 78 draws, 251k) and J's verdict.
- PHASE0 0.7: part 4 item ticked with the measured line.

## Not done / next
- Phase 0 left: 0.8 interiors (desktop, Blender), then the Phase 0 exit review.
- Unchecked: the one long frame after the first incendiary (desktop GL only).

## J must test
Nothing for this branch (docs only).

## Next session must know
Spot fires and embers are small at the default zoom; sizes are constants in `game/fx/fire_fx.gd` (`SPOT_SCALE`)
and `game/fx/explosion_fx.gd` (ember quad), not in `data/` yet.
