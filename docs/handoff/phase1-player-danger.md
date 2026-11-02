# phase1/player-danger

- **PR:** opened with this commit (pushed: yes); J merges
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `20fea00` (1.2 enemies merged as PR #33)
- **Updated:** 2026-11-02

## J asked
"next" after 1.2 → Phase 1 step 1.3, the player in danger (`docs/PHASE1.md`).

## Done (details in `docs/PHASE1_RESULTS.md` 1.3)
- `FighterHealth` / `FighterConfig` / `ArmorConfig` (+ `data/armor/`, `data/combat/player_fighter.tres`).
- Zombie hits by type (`EnemyConfig.hit_damage`, `Horde.target_hits`), bites, gas, ground fire, own blasts.
- Downed 10 s → dead → R / X restarts; no move / shoot / throw while down.
- `DamageFeedback`: red edge, low-HP slow-mo, downed / dead message; HP on the HUD.
- Fire burns Bloater gas away.
- F4: Invulnerable, Slow-mo on low HP, Self blast damage ×. Autoshoot = invulnerable.
- 162 GUT tests pass (10 new).

## Not done / next
- Hit sound (1.4 audio pass); revive by teammates (1.9); water effects of weight / heavy armor (with water).
- Balance: 200 packed zombies kill a standing player in ~1 s; tune in the 1.5 arena.
- Then 1.4 game feel.

## J must test (after merge, Chrome, Ctrl+Shift+R)
`?spike=twinstick` without autoshoot: let a few zombies reach you (lower the horde with `[`). Red edge, slow-mo
once under 25 % HP, downed 10 s, YOU DIED, R restarts. Throw a frag close to yourself (half damage). Kill a
Bloater and walk into the cloud; then an incendiary into a cloud burns it away. Is it fair? Too fast, too slow?

## Next session must know
- `SpikePlayer.health` (`FighterHealth`); `SpikePlayer.fighter`; `LoadoutConfig.wearing`.
- `Horde.target_hits` must be drained (the spike clears it every frame).
