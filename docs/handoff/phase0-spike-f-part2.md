# phase0/spike-f-part2

- **PR:** opened with this commit (pushed: yes); J merges
- **Machine:** plan written on the desktop (RTX 4080); built on the laptop (ASUS, Intel Arc 140V)
- **Base:** main @ `b82c81a` (0.8 part 1 merged as PR #23, live build `b82c81a · #65`)
- **Updated:** 2026-10-29

## J asked
"เริ่ม 0.8" (2026-10-29), then "merge แล้วเดียวจะสลับเครื่องไปทำงานข้างนอก". On the laptop: "สลับเครื่องแล้วมาเริ่มงาน
กันต่อ". Stair fix: J picked "ประตูจากชานบันได".

## Done (laptop, 2026-10-29; details in PHASE0_RESULTS 0.8 part 2)
- **Stair bug from part 1 fixed:** storey 1's corridor couldn't be reached from the stairs (full-storey flights
  leave every other storey at the cut-off west landing). Door from that landing into the first north room;
  first rooms always get a corridor door. Height-aware tests added.
- **Zombies inside:** `InteriorHordes`, 15 dormant per dry storey; wake by shot / blast noise, sight, a
  neighbour or a hit; follow across storeys via the flights. Roof zombies wait while the player is inside.
- **Dark rooms + flashlight:** `InteriorLighting`, one light texture read by the interior and horde shaders.
- **Water-level window:** rope from the roof's south edge to a storey-1 window, and back.
- 122 GUT tests pass (16 new). Desktop GL on the Arc: 30 awake inside = 60 FPS, ~125 draws, 160k.

## Not done / next
1. J's Arc run in Chrome after merge (below), then the 0.8 verdict and the Phase 0 exit review.
2. Later, not this spike: a boat that stops at the window; half-flight stairs if the lobby door feels wrong.

## J must test (after merge, Chrome on the Arc, Ctrl+Shift+R, F3)
1. `https://twilightxc.github.io/DrownedCity/?spike=interior&storey=2&wake=1`: all 30 awake come up the stairs
   (storey 1 ones through the lobby room). Write down FPS, Draw calls, Primitives (pass ≥ 50 FPS, < 250 draws).
2. Default page: roof hatch → walk the storeys. Rooms dark until you see in? Flashlight follows the aim?
   Shoot: sleepers nearby wake. Storey 1 is reached from the west landing through the lobby room door.
3. Rope at the roof's south edge (ring near the middle of the south parapet) → storey 1 window, and back up.
4. Is the cutaway readable at every angle (part 1 question, still open)?

## Next session must know
- `docs/arc-handoff` is obsolete; delete it.
- Corpses and blood are cleared on every storey change (one shared layer); roof corpses don't survive a visit inside.
- `Horde.update(delta, target, attack)`: `attack = false` for waypoints (stair flights); `Horde.dormant`, `lift`,
  `transfer` are new.
- Shader globals added: `interior_light` (sampler2D), `interior_light_rect`, `interior_light_on`.
