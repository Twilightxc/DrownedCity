# phase0/spike-e-gore

- **PR:** #17 (part 2), CI green (run #50; run #49 failed on the sink test vs the delta clamp, fixed in `0cf6b59`)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ `911ef37` (0.7 part 1 merged as PR #16)
- **Updated:** 2026-10-27

## J asked
"merge PR #16 แล้ว ช่วยเช็ก deploy แล้วลบ worktree จากนั้นเริ่ม 0.7 part 2" (hit reaction, corpses, blood,
dismemberment, gore toggle).

## Done (part 2 of 3)
- `Horde`: `apply_damage(agents, damage, source, blast)` → flinch + hit slow for survivors, `hit_points` /
  `hit_dirs` / `deaths` event queues (`Horde.Death`), drained by the spike each frame.
- `game/fx/corpse_layer.gd` (ring buffer, death / death_blown clips, sink, water float, dismemberment masks,
  severed limbs), `game/fx/blood_fx.gd` (droplets + pools), `game/fx/gore_config.gd` + `data/fx/gore.tres`.
- Shader: hidden-part bitmask in `INSTANCE_CUSTOM.w` vs part index in UV.y (kit_zombie now writes it).
- Twinstick tuning panel: gore on/off, dismember chance, hit slow. `--auto-shoot` / `&autoshoot=1` harness.
- 10 new GUT tests (78). Desktop GL, ANGLE and local WebGL2 checked; numbers in PHASE0_RESULTS 0.7 part 2.

## Not done / next
- Part 3: fake ragdoll slide on blasts (corpse moves along an arc), flying limbs as rigid bodies (cap 16),
  burning flag in the horde shader, ground fire cells in the NavGrid, then J's Arc run with `&autoshoot=1`.
- Mixamo clips (J), whenever.

## J must test
- `?spike=twinstick` (Ctrl+Shift+R after merge): shoot zombies → they flinch and slow, fall and stay, blood
  sprays and pools, some lose a head/arm/leg (lying next to them); grenades throw bodies backwards. F4 / Start →
  "Blood + dismemberment" off: no blood, whole corpses. Does it read clearly and not clutter the field?

## Next session must know
- With `&autoshoot=1` the crowd soon engulfs the player and new corpses pile up under it; look early (first
  ~10 s) or lower the count with `[` to see them.
- Blood pool mesh winding: clockwise from above is the front face; `SurfaceTool.set_normal` applies to the next
  vertex only.
