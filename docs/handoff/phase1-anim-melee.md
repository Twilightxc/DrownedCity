# phase1/anim-melee

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 362a6bf
- **Updated:** 2026-11-06

## J asked
"มาเริ่มงานต่อ" → "Animations + melee": the desktop list from `docs/handoff-to-desktop`: bug list 4 (weapon switch),
6 (death clip; the downed pose must not freeze), 11 (stand → prone "looks like just falling over"), 12 (crouch →
prone), 14 (side roll while prone), 15 (crawl, rifle across the elbows); knife + axe models and slash clips, the hit at
`MeleeConfig.windup_sec`.

## Done
- `tools/blender/kit_survivor.py`: new clips death, go_prone, crouch_to_prone, prone_to_stand, prone_to_crouch,
  prone_roll_l / r, switch, slash_light, slash_heavy; new crawl; livelier downed (29 clips).
- `tools/blender/kit_props.py`: prop_melee_knife, prop_melee_axe.
- `SurvivorView`: `dead`, `switch_gun(gun, guns)`, `swing(cfg)`, stance-change clips, prone roll side.
- `FighterMotion.try_roll(dir, aim)`: prone log roll; `can_shoot()` false while crawling.
- `MeleeConfig.mesh_scene / mesh_scale / clip`; knife.tres, axe.tres.
- Pose gallery shows the new clips. 7 new tests, 251 total, passing.

## Not done / next
- Melee sounds (CC0 list for J to approve), then `swing_sfx` / `hit_sfx` on `MeleeConfig`.
- Gun icons for `WeaponConfig.icon`. Optional more barricade stages.

## J must test
- `?spike=poses`: the new clips (get down, crouch to prone, get up, prone roll, death, switch gun, knife, axe).
- `?spike=arena`: Z to go prone from standing and from C; Space while prone + A/D; crawl (can't shoot while moving);
  1–4 to switch guns; X to knife (or the axe loadout); get downed and let the timer run out (death).

## Next session must know
- Crawling blocks shooting (new rule, DECISIONS 2026-11-06); revert in `FighterMotion.can_shoot` if J dislikes it.
