# Phase 0 — Technical spikes (≈ 33 h of J's time, 2–3 weeks)

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
- **Pass (pending first push to GitHub):** pushing a commit updates the live URL within ~10 min, build number matches the commit.

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
- **Pass (J to judge `docs/art/05_spike_b_vs_ref.png` + live URL):** side-by-side screenshot vs `docs/art/03_style15_horde.png` that J accepts; stays within budget
  (draw calls < 250) with Spike A running.

## 0.5 Spike C — Twin-stick feel, mouse + gamepad
- [ ] Input map: WASD/left stick move, mouse/right stick aim, fire, reload, throw, interact, radial menu.
- [ ] Iso-correct aiming (screen → ground plane), light aim assist on gamepad only.
- [ ] Camera rotate 90° (Q/E, shoulder buttons) keeps controls camera-relative.
- **Pass:** J plays 10 minutes with each input device and says it feels right (subjective — J decides).

## 0.6 Spike D — Save on web
- [ ] Minimal SimCore (3 survivors, 4 resources, day counter) serializes to versioned JSON in `user://`.
- [ ] Export / import save file button (protects against browser cache clears).
- **Pass:** state survives closing and reopening the browser; exported file re-imports on another browser.

## 0.7 Spike E — Animated horde, corpses and blood on web
Added 2026-10-26 (J): characters with limbs and realistic motion, enemy variants, hit slow, blood, corpses,
dismemberment (GDD §3, §6, §9, §13). This is the only part of that request that can break the 200-zombie web
budget, so it is measured before Phase 1. Needs the **desktop** (Blender) and J's Mixamo download (login).
- [ ] Low-poly zombie with limbs (target ≤ ~500 tris) from `tools/blender`, 2 variants (male / female), rigged
      to a Mixamo humanoid; clips: walk, attack, hit flinch, death (J downloads from Mixamo).
- [ ] Bake the clips into a vertex animation texture (VAT) in Blender; the horde MultiMesh vertex shader plays
      a clip + time offset per instance (`INSTANCE_CUSTOM`). No skeleton per zombie. Works in Compatibility.
- [ ] Hit: brief slow on unarmored agents (per-type data, 0 for armored), flinch clip, blood burst along the
      bullet.
- [ ] Death: death clip → corpse stays (own MultiMesh, capped ring buffer, oldest fade; in water float then
      sink); random dismemberment (corpse variant missing a limb + a flying limb piece); blood pools as flat
      quads (check whether `Decal` works in Compatibility on 4.7.2 first).
- [ ] Gore toggle (blood + dismemberment on/off).
- **Pass (J on Arc, Chrome):** 200 animated zombies + corpse cap full + blood ≥ 50 FPS, draw calls < 250,
  < 300k tris on screen; J judges the motion reads as real enough. **Fallback:** fewer variants, lower corpse
  cap / faster fade, then 100 zombies.

## Exit criteria
All spikes pass (or have an accepted fallback) and results are logged in `docs/PHASE0_RESULTS.md`
with device, browser, FPS, draw calls. Then plan Phase 1 (web demo vertical slice, see GDD §15, §17).
