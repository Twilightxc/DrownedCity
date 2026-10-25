# Phase 0 — Technical spikes (≈ 25 h of J's time, 1–2 weeks)

Goal: prove the four riskiest technical bets **before** building real systems. Spike code may be thrown
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
- [ ] Flat rooftop + surrounding water test scene, iso ortho camera.
- [ ] Zombies rendered with `MultiMeshInstance3D` (blocky placeholder mesh, per-instance colour).
- [ ] Shared flow field on a 2D grid (BFS/Dijkstra from player/base targets), recomputed at most every
      0.25 s; agents sample field + simple separation; no physics bodies per zombie.
- [ ] Hitscan bullets with penetration (ray test against spatial hash, not physics).
- [ ] Spawn slider: 50 / 100 / 200 / 300.
- **Pass:** ≥ 50 FPS with 200 zombies on J's laptop (Intel Arc iGPU, Chrome, web build).
  **Fallback:** cap at 100 and design horde nights as multiple waves.

## 0.4 Spike B — "Style 1.5" look on WebGL2
- [ ] Generate one rooftop base building + 3 props from `tools/blender/scene_v15_web.py` style → .glb.
- [ ] Water shader: depth-tinted colour, 2 scrolling normal layers, cheap foam ring near geometry.
- [ ] Wall shader: waterline stain from world Y (single `mix`), parameter = current water level.
- [ ] One shadowed directional sun with dusk colour, emissive windows + glow, depth fog.
- [ ] Baked lighting: verify `LightmapGI` works in Compatibility on the pinned version; if not, bake AO
      into vertex colours in Blender.
- **Pass:** side-by-side screenshot vs `docs/art/03_style15_horde.png` that J accepts; stays within budget
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

## Exit criteria
All four spikes pass (or have an accepted fallback) and results are logged in `docs/PHASE0_RESULTS.md`
with device, browser, FPS, draw calls. Then plan Phase 1 (web demo vertical slice, see GDD §15, §17).
