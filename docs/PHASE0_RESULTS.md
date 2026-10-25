# Phase 0 results

Measured numbers per spike. Device/browser on every row; J's Arc laptop is the pass/fail reference.

## 0.1 Project skeleton — ✅ done (PR #1, merged 2026-10-25)

| Item | Result |
| --- | --- |
| Godot | 4.7.2-stable (`.godot-version`), Compatibility renderer |
| Tests | GUT 9.7.1 vendored; `GameClock` 3/3 pass; failing test → exit 1 |
| Build label | `v0.0.1 · <sha> · #<run> · <date>` bottom-right; `dev` locally |
| Debug overlay | F3 / pad Back: FPS, draw calls, objects, primitives, nodes, VRAM, zombies |

## 0.2 CI → GitHub Pages — ✅ pass (2026-10-25)

| Check | Result |
| --- | --- |
| Live URL | https://twilightxc.github.io/DrownedCity/ |
| Push → live | merge `f640612` → deployed in ~2 min (run #3); criterion ≤ 10 min |
| Build number matches commit | `f640612 · #3` on screen = merge commit |
| CI time | ~1 min per run; template download step 7 s on the first run, cached after |
| Download size | `index.wasm` 39.5 MB + `index.pck` 17 KB (budget < 50 MB) |
| False-green guard | CI requires a JUnit report with ≥ 1 test (Copilot review finding) |

| Device | Browser | Renderer | FPS | Draw calls | Notes |
| --- | --- | --- | --- | --- | --- |
| Desktop RTX 4080 (dev) | Claude browser pane (Chromium) | gl_compatibility | 143 | 10 | empty test scene |
| Laptop Intel Arc (min-spec) | Chrome | — | — | — | **J to fill in** |

## 0.3 Spike A — Horde on web — built, awaiting Arc measurement

Scene: 40×40 m rooftop with 8 obstacles over flood water. Zombies are one `MultiMeshInstance3D`
(raw buffer write per frame), steered by a shared BFS flow field (recompute ≤ every 0.25 s, only when the
player changes cell) + position-based separation via a spatial hash. Rifle: hitscan, penetration 3.
Overlay (F3) shows `Horde Update`, `Horde Render Sync` and `Flow Field` times.

| Device | Browser | Zombies | FPS | Draw calls | Primitives | Horde update | Flow field | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Desktop RTX 4080 (dev) | Claude pane (Chromium) | 200 | 144 (vsync) | 52 | 60k | 0.33 ms | 1.8 ms | spread out, approaching |
| Desktop RTX 4080 (dev) | Claude pane (Chromium) | 300 | 144 (vsync) | 55 | 87k | 1.5–3.4 ms | 1.8 ms | 300 packed around player = worst case |
| Laptop Intel Arc | Chrome | 200 | — | — | — | — | — | **J: pass ≥ 50 FPS** |
| Laptop Intel Arc | Chrome | 300 | — | — | — | — | — | J |

Findings so far:
- A full per-cell direction pass cost ~7 ms per recompute on web → directions are now resolved lazily
  only for cells agents stand in (flow field 6.8 → 1.8 ms; the rest is the BFS).
- Worst case is CPU, not GPU: separation cost grows when the whole horde piles on the player.
  If Arc misses the target, first lever = cap separation neighbours per agent; fallback per plan = cap 100.

## 0.4 Spike B — "Style 1.5" look — built, awaiting J's verdict

Comparison: `docs/art/05_spike_b_vs_ref.png` (left: reference render, right: Godot capture).
Live: default URL (`?spike=style`); Spike A stays at `?spike=horde`.

| Item | How | Result |
| --- | --- | --- |
| Assets | `tools/blender/kit_building.py`, `kit_props.py` → `assets/models/*.glb` | base building 11.9k tris, 2 backdrop variants 4.4k / 7.1k, water tower / AC / sandbags < 250 tris each |
| One draw call per building | palette colour in vertex RGB, baked AO in vertex alpha, one shared shader; lit windows = 2nd surface | 2 surfaces per building |
| Wall shader | `game/shaders/style15_surface.gdshader`: wet tint + algae band from world Y vs global `water_level` | works; water level is one global uniform |
| Water | `game/shaders/water.gdshader`: 2 scrolling normal maps, shallow tint + foam ring from footprint SDF (≤ 16 boxes) | no depth-buffer pass needed |
| Light | 1 shadowed sun (PSSM 2 splits, 80 m), procedural sky ambient, ACES, glow on emissive windows, depth fog | all render in Compatibility (desktop GL + WebGL2), no console errors |
| Baked lighting | docs: Compatibility *renders* LightmapGI, but baking needs RenderingDevice hardware and a manual editor step | **chose vertex AO baked in Blender (Cycles)** — scripted, reproducible; LightmapGI not tested |

| Device | Browser | Scene | FPS | Draw calls | Primitives | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Desktop RTX 4080 | desktop GL Compatibility 1080p | style + 200 zombies | 144 (vsync) | 55 | 88k | capture used for the comparison |
| Desktop RTX 4080 | Claude pane (Chromium) | style + 200 zombies | 144 (vsync) | 45 | 69k | horde update 1.8 ms |
| Laptop Intel Arc | Chrome | style + 200 zombies | — | — | — | **J: pass ≥ 50 FPS, draw calls < 250** |

Known gaps vs reference: no roof clutter (tents, garden, solar), shorter/cooler shadows, water a bit brighter,
no ladders/bridges/trees/boats. These are content, not renderer limits.

## 0.5 Spike C — Twin-stick feel

_Not started._

## 0.6 Spike D — Save on web

_Not started._
