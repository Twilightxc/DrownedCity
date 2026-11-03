# phase1/teammates

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** phase1/hud (PR #46) on main @ 7b8e6ec
- **Updated:** 2026-11-03

## J asked
"next task" → 1.5+ A5: "เอไอเพื่อนช่วยยิง" (2 teammates, J's answer).

## Done
- `combat/teammate_brain.gd`, `combat/teammate_config.gd` + `data/combat/teammate.tres`, `combat/grid_path.gd`.
- `game/spikes/teammate.gd`: a SpikePlayer whose wishes come from the brain; revive by F (2 s); swaps to the pistol.
- SpikePlayer input goes through `_move_input / _wants_sprint / _wants_fire / _update_aim` (overridable).
- `Horde.extra_targets / extra_hits`; horde_spike `add_teammate()` (flow goals, hits, blasts, fx, audio, HUD).
- Arena: Mali (AR) + Somchai (shotgun), restock each calm, orders (Follow / Hold here / Hold fire), summary line,
  `?mates=N`. HUD: names, mini HP bars, revive ring. Picture: `docs/art/11_teammates.png`.
- 6 new tests, 215 total, all passing on desktop.

## Not done / next
- Gate 1.G (J): play the arena 3× on the Arc, fun? ≥ 50 FPS at the biggest wave?
- Teammates don't revive the player, throw grenades, crouch, or take gas / fire damage yet.

## J must test
- `?spike=arena`: do the teammates help without stealing the fight? Compare with `&mates=0`.
- Tab: Follow me / Hold here / Hold fire. Let one get downed and help it up with F.
- Arc: FPS with three skinned bodies.
