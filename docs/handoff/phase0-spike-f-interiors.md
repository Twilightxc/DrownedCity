# phase0/spike-f-interiors

- **PR:** #23 (part 1), CI green (run #63), ready to merge
- **Machine:** desktop (RTX 4080)
- **Base:** main @ `dd57dd5`
- **Updated:** 2026-10-29

## J asked
"เริ่ม 0.8" (PHASE0.md 0.8: building interiors with a cutaway camera).

## Done (part 1 of 2)
- `tools/blender/kit_interior.py` → `assets/models/interior_*.glb` (12 pieces).
- `game/interior/`: `interior_layout.gd` (seeded plans), `interior_builder.gd` (MultiMesh per piece per storey),
  `interior_controller.gd` (roof hatch, stairs, storey switch, cutaway globals), `hatch.gd`.
- `game/shaders/interior_cutaway.gdshader`; 4 global uniforms in `project.godot` (`cut_*`).
- `SpikePlayer.set_floor` / `set_height`; interactables are any node in group "interactable" (duck-typed).
- `?spike=interior` is the default URL; `&storey=2` / `-- --storey=2` starts inside.
- Fx warm-up moved under the water (`horde_spike.gd` `WARM_UP_Y`): it showed as smoke inside the building.
- 11 new GUT tests (106). Desktop + local WebGL2 checked (numbers in PHASE0_RESULTS 0.8).

## Not done / next (part 2)
- Unseen rooms dark until line of sight; flashlight (one shadowless spot light).
- ~30 dormant zombies inside per storey (a Horde + flow field per storey, linked by the stair cells), waking by
  noise and following across storeys; roof zombies should use the hatch.
- Water-level window entrance on storey 0/1 (boat stops at it); storey 0 is flooded (1 m), not walkable yet.
- Arc run by J after part 2: `?spike=interior&storey=2`.

## J must test
`https://twilightxc.github.io/DrownedCity/` (Ctrl+Shift+R after merge): walk to the yellow ring by the roof hut,
F (pad A) → fade into the top storey. Walls toward the camera drop to waist height; Q/E turns the camera and the
cut follows. Walk the stairs at the corridor's west end down one storey and back up; F at the ring on the top
landing goes back to the roof. Does the cutaway read clearly at every angle? Are rooms and doors readable?

## Next session must know
- Interior colours re-encode `COLOR` like the horde shader (see the 0.7 sRGB finding).
- `RenderingServer.global_shader_parameter_get` returns null under the headless dummy renderer; tests read
  `InteriorController.cut_*` instead.
- The interior is generated at load from `layout_seed` (7); nothing is saved yet.
