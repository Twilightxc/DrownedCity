# phase0/spike-f-part2

- **PR:** not opened (pushed: yes; only this note so far)
- **Machine:** written on the desktop (RTX 4080) for whichever machine picks it up; the laptop can do it
- **Base:** main @ `b82c81a` (0.8 part 1 merged as PR #23, live build `b82c81a · #65`)
- **Updated:** 2026-10-29

## J asked
"เริ่ม 0.8" (2026-10-29), then "merge แล้วเดียวจะสลับเครื่องไปทำงานข้างนอก". Part 1 (enter, storeys,
cutaway) is merged; this branch is for part 2 of PHASE0 0.8.

## Done
- Nothing yet on this branch.

## Not done / next (0.8 part 2, PHASE0.md 0.8 unchecked items)
1. **Zombies inside:** ~30 dormant zombies per walkable storey that wake by noise (shots) and follow across
   storeys. Plan: one `Horde` + flow field per storey on `InteriorController.grids[s]`, stair cells as the link
   (an agent on a flight cell past half way moves to the other storey's horde); the player's hitscan uses the
   current storey's horde (today `SpikePlayer` keeps the roof horde, so shots inside can hit roof zombies
   through the floor). Roof zombies should go down the hatch or stay out; decide in the PR.
   Corpses, blood and fire layers take the storey's floor height (`ground_y` per storey).
2. **Dark rooms:** rooms the player has no line of sight into stay dark (per-room dim via a global or per-room
   uniform; `NavGrid.line_of_sight` from the player to room cells); a flashlight = one shadowless SpotLight3D on
   the player, on while inside.
3. **Water-level window:** an entrance on storey 1's outer wall above the flood line (storey 0 is 1 m under
   water and not walkable); a boat is out of scope, a ledge/plank from the water side is enough for the spike.
4. Then J's Arc run in Chrome: `?spike=interior&storey=2` with zombies awake (pass: ≥ 50 FPS, < 250 draws).

Code only, no Blender (unless the window needs a new kit piece, which can wait for the desktop). On the laptop:
download Godot 4.7.2 into the session scratchpad first (ask J, per CLAUDE.md).

## J must test
Part 1 on the live URL (default page): ring by the roof hut → F → inside; Q/E camera turns; stairs at the
corridor's west end; ring on the top landing → roof. Is the cutaway readable at every angle?

## Next session must know
- Interior code: `game/interior/` (`InteriorLayout` pure data + 7 tests, `InteriorBuilder`, `InteriorController`,
  `Hatch`), shader `game/shaders/interior_cutaway.gdshader`, `cut_*` shader globals in `project.godot`.
- `RenderingServer.global_shader_parameter_get` returns null under the headless dummy renderer (tests read
  `InteriorController.cut_*`).
- `docs/arc-handoff` is obsolete; delete it.
- Desktop: the zombie kit and the interior kit need Blender; the laptop has none.
