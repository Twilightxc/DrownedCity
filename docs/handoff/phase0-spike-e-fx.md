# phase0/spike-e-fx

- **PR:** opened from the laptop with `gh` (see the PR list)
- **Machine:** laptop (ASUS, Intel Arc 140V), Godot 4.7.2 from the session scratchpad
- **Base:** main @ `097bd56`
- **Updated:** 2026-10-28

## J asked
"Download, start" → 0.7 part 3 from `docs/arc-handoff`: fake ragdoll slide on blasts, flying limbs as rigid
bodies (cap 16), burning zombies (shader flag), ground fire cells in the NavGrid, then a second Arc run.

## Done
- Blast corpses slide along an arc away from the blast, stop at walls, splash into the water off the roof.
- Severed limbs fly as `RigidBody3D`s (cap 16, oldest freezes), drawn by the corpse MultiMesh.
- Burning zombies: per-agent timer, tick damage, spread, water puts out, charred corpses; shader flicker
  (bit 11 of INSTANCE_CUSTOM.w) + one shared flame MultiMesh.
- Ground fire: `combat/ground_fire.gd` cells (cap 12) with a flow-field cost; incendiary spike grenade.
- Blast fx: flash light, debris, smoke puffs, scorch marks, water column; shaders warmed at load.
- 90 GUT tests pass; desktop GL run on the Arc 140V: 60 FPS, 73–77 draws, ≤ 249k prims under full load.

## Not done / next
- **Web check:** nobody has run this in a browser yet. `VatModel.part_bounds` reads the VAT image on the CPU;
  if `get_image()` fails on the web, limbs use a fallback box (warning in the console).
- Second Arc run in Chrome after merge (PHASE0 0.7 pass test): `?spike=style&autoshoot=1`, 200 and 300.
- Not in this PR: fire on the player, rain/water cannon putting fire out, wooden base structures burning,
  oil slicks on water (GDD §6 lists them; later phases).

## J must test
After merge, in Chrome on the Arc: `https://twilightxc.github.io/DrownedCity/?spike=style&autoshoot=1`,
Ctrl+Shift+R, F3. Wait about 60 s. Write down FPS, Draw calls, Primitives, Burning, Fire Cells, Limb Bodies,
then press `]` for 300. Also look at it: do the blasts, limbs and fire read well?

## Next session must know
- `?spike=style` now throws incendiary grenades under autoshoot, so its numbers aren't comparable to the
  2026-10-28 part 2 run (PR #18) without fire.
- In scratch drivers, a screenshot (`save_png`) costs about 140 ms; don't count that frame as a hitch.
