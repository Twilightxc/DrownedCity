# Phase 0 — Technical spikes (≈ 39 h of J's time, 3 weeks)

Goal: prove the riskiest technical bets **before** building real systems. Spike code may be thrown
away; what we keep is the project skeleton, CI, and measured numbers in `docs/PHASE0_RESULTS.md`.

## 0.1 Project skeleton
- [x] Godot 4.x project (latest stable at setup; write it to `.godot-version`) → **4.7.2-stable**, Compatibility renderer.
- [x] Folder layout from `CLAUDE.md` (`sim/ data/ game/ combat/ ui/ platform/ tests/ tools/`).
- [x] Test framework chosen (GUT or gdUnit4) → **GUT 9.7.1**, vendored in `addons/gut` with one passing SimCore test.
- [x] Build number autoload (git short SHA + date) shown bottom-right; F3 debug overlay with FPS, draw
      calls, object count, zombie count.

## 0.2 CI → GitHub Pages
- [x] GitHub Actions: download pinned Godot + export templates, headless export preset "Web"
      (thread support OFF), run tests, deploy `build/web` to Pages on push to `main`.
- [x] Export preset committed; `.gitignore` excludes `.godot/` and build output.
- **Pass (2026-10-25):** pushing a commit updates the live URL within ~10 min, build number matches the commit.

## 0.3 Spike A — Horde on web (biggest risk)
- [x] Flat rooftop + surrounding water test scene, iso ortho camera.
- [x] Zombies rendered with `MultiMeshInstance3D` (blocky placeholder mesh, per-instance colour).
- [x] Shared flow field on a 2D grid (BFS/Dijkstra from player/base targets), recomputed at most every
      0.25 s; agents sample field + simple separation; no physics bodies per zombie.
- [x] Hitscan bullets with penetration (ray test against spatial hash, not physics).
- [x] Spawn slider: 50 / 100 / 200 / 300.
- **Pass (J to measure on Arc):** ≥ 50 FPS with 200 zombies on J's laptop (Intel Arc iGPU, Chrome, web build).
  **Fallback:** cap at 100 and design horde nights as multiple waves.

## 0.4 Spike B — "Style 1.5" look on WebGL2
- [x] Generate one rooftop base building + 3 props from `tools/blender/scene_v15_web.py` style → .glb.
- [x] Water shader: depth-tinted colour, 2 scrolling normal layers, cheap foam ring near geometry.
- [x] Wall shader: waterline stain from world Y (single `mix`), parameter = current water level.
- [x] One shadowed directional sun with dusk colour, emissive windows + glow, depth fog.
- [x] Baked lighting: verify `LightmapGI` works in Compatibility on the pinned version; if not, bake AO
      into vertex colours in Blender.
- **Pass — accepted by J 2026-10-27 (desolate look; Arc perf 2026-10-26, Arc for 0.4b skipped by J):** side-by-side screenshot vs `docs/art/03_style15_horde.png` that J accepts; stays within budget
  (draw calls < 250) with Spike A running.
- [x] Abandoned / desolate pass on the whole scene (J's request): weathering, ruins, overgrowth, flotsam,
      cooler grade → `docs/art/06_desolate_vs_spike_b.png`.

## 0.5 Spike C — Twin-stick feel, mouse + gamepad
- [x] Input map: WASD/left stick move, mouse/right stick aim, fire, reload, throw, interact, radial menu.
- [x] Iso-correct aiming (screen → aim plane at body height), light aim assist on gamepad only.
- [x] Camera rotate 90° (Q/E, shoulder buttons) keeps controls camera-relative. (+ zoom: wheel / D-pad up/down)
- [x] Live tuning panel (F4 / Start) so feel numbers change without a rebuild.
- **Pass:** J plays 10 minutes with each input device and says it feels right (subjective — J decides).
  Mouse + keyboard: ✅ J 2026-10-27. Gamepad: **deferred by J (2026-10-27), not a Phase 0 exit blocker**; the pad
  controls stay in the build (checked by Claude with scripted input) and J tests them when a pad is at hand.

## 0.6 Spike D — Save on web
- [x] Minimal SimCore (3 survivors, 4 resources, day counter) serializes to versioned JSON in `user://`.
- [x] Export / import save file button (protects against browser cache clears).
- **Pass:** state survives closing and reopening the browser; exported file re-imports on another browser.
  ✅ J 2026-10-27: Chrome close/reopen keeps the save; a Chrome export imports in Edge/Firefox with the same day and stock.

## 0.7 Spike E — Animated horde, corpses and blood on web
Added 2026-10-26 (J): characters with limbs and realistic motion, enemy variants, hit slow, blood, corpses,
dismemberment (GDD §3, §6, §9, §13). This is the only part of that request that can break the 200-zombie web
budget, so it is measured before Phase 1. Needs the **desktop** (Blender) and J's Mixamo download (login).
- [x] Low-poly zombie with limbs (target ≤ ~500 tris) from `tools/blender`, 2 variants (male / female), rigged
      to a Mixamo humanoid; clips: walk, attack, hit flinch, death (J downloads from Mixamo).
      → 180 tris, rigid-part rig; clips are hand-keyed stand-ins until the Mixamo clips arrive.
- [x] Bake the clips into a vertex animation texture (VAT) in Blender; the horde MultiMesh vertex shader plays
      a clip + time offset per instance (`INSTANCE_CUSTOM`). No skeleton per zombie. Works in Compatibility.
- [x] Hit: brief slow on unarmored agents (per-type data, 0 for armored), flinch clip, blood burst along the
      bullet.
- [x] Death: death clip → corpse stays (own MultiMesh, capped ring buffer, oldest fade; in water float then
      sink); random dismemberment (corpse variant missing a limb + a flying limb piece); blood pools as flat
      quads (check whether `Decal` works in Compatibility on 4.7.2 first).
      → oldest sink through the floor instead of a transparent fade; the limb lies where it landed (it flies in
      part 3); no decals (Compatibility has none), flat pools.
- [x] Gore toggle (blood + dismemberment on/off).
- [x] Added 2026-10-27 (J): fake ragdoll, fire and explosion effects (GDD §6): → part 3, see PHASE0_RESULTS
  - Explosion: "blown back" death clip + corpse slides along an arc away from the blast; one short flash light,
    debris/smoke particles, scorch mark, water column when it lands in water.
  - Flying limbs as real rigid bodies, capped (start at 16 at once, oldest freezes).
  - Burning: per-instance flag in the horde shader (emissive flicker) + one shared particle system, no particle
    node per zombie.
  - Ground fire: timed cells in the NavGrid with a flow-field cost and damage; ~10 burning cells at once.
- **Pass (J on Arc, Chrome):** 200 animated zombies + corpse cap full + blood ≥ 50 FPS, draw calls < 250,
  < 300k tris on screen, **also during a grenade blast into the pack with ~50 zombies burning and the limb cap
  full**; J judges the motion reads as real enough. **Fallback:** fewer variants, lower corpse cap / faster fade,
  lower limb cap, burning shown by shader only; then 100 zombies.
  → **Measured 2026-10-28** (web, Claude pane on the Arc): 200 + blasts + 9–80 burning + limb cap full = 60 FPS,
  73 draws, 243k; 300 = 60 FPS, 297k (at the edge). Motion verdict from J: reads well (part 2). J skipped the
  full-screen Chrome run.
- [x] Added 2026-10-28 (J, after seeing part 3): two grenade types and richer blasts → part 4, see PHASE0_RESULTS
  - Blast force: soot, dust, smoke, hot shrapnel, limbs torn off at random and thrown in random directions.
  - Frag (normal) grenade: small embers stuck on the floor; zombies catch fire only in small spots, never whole.
  - Whole-body burning only from the incendiary grenade (and its ground fire).
  → **Measured 2026-10-28** (J, Chrome on the Arc, build `c8db6be · #60`): 200 + both grenades = 60 FPS,
  78 draws, 251k. J accepts the look.

## 0.8 Spike F — Building interiors with a cutaway camera
Added 2026-10-27 (J): interior exploration (GDD §5). New risk: a readable cutaway in iso, multi-floor nav, and
staying in the draw-call budget with an interior loaded next to the outside block. Needs the **desktop**
(Blender) for the kit.
- [x] Interior kit in `tools/blender` (wall, wall with door / window, floor, stair, door, furniture/containers ×4)
      + a seeded layout generator in Godot for one 3-floor building (rooms, corridor, stairwell). Pieces are
      instanced per type (MultiMesh or merged per floor at load), not one node per wall.
- [x] Cutaway: floors above the player and the roof hide; walls facing the camera cut to waist height (one plane
      uniform in the wall shader), correct after each 90° camera turn; smooth fade in/out at the entrance.
- [ ] Entrances: roof hatch, stairs between floors, a window at water level (boat stops at the window).
      → part 1 (2026-10-29): roof hatch + stairs done; the water-level window is part 2.
- [ ] NavGrid + flow field per floor, linked through the stair cells; hitscan and LOS inside.
      → part 1: a NavGrid per storey for the player (hitscan/LOS on it); flow fields per storey come with the zombies.
- [ ] Unseen rooms stay dark until the player has line of sight; interior dark by default + flashlight
      (one shadowless spot light).
- [ ] ~30 dormant zombies inside that wake by noise and follow across floors.
- **Pass (J on Arc, Chrome):** inside the building with 30 zombies awake and the outside block still drawn
  ≥ 50 FPS, draw calls < 250; J says the cutaway reads clearly at every camera angle and moving between floors
  feels right. **Fallback:** hide the outside block while inside; simpler cutaway (hide whole near walls).

## Exit criteria
All spikes pass (or have an accepted fallback) and results are logged in `docs/PHASE0_RESULTS.md`
with device, browser, FPS, draw calls. Then plan Phase 1 (web demo vertical slice, see GDD §15, §17).
