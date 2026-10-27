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
| Laptop Intel Arc (min-spec) | Chrome | gl_compatibility | — | — | n/a: the default URL now opens the Spike B scene; see the 0.4 Arc row (60 FPS) |

## 0.3 Spike A — Horde on web — ✅ pass at 200 on Arc (2026-10-26, measured in the heavier Spike B scene)

Scene: 40×40 m rooftop with 8 obstacles over flood water. Zombies are one `MultiMeshInstance3D`
(raw buffer write per frame), steered by a shared BFS flow field (recompute ≤ every 0.25 s, only when the
player changes cell) + position-based separation via a spatial hash. Rifle: hitscan, penetration 3.
Overlay (F3) shows `Horde Update`, `Horde Render Sync` and `Flow Field` times.

| Device | Browser | Zombies | FPS | Draw calls | Primitives | Horde update | Flow field | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Desktop RTX 4080 (dev) | Claude pane (Chromium) | 200 | 144 (vsync) | 52 | 60k | 0.33 ms | 1.8 ms | spread out, approaching |
| Desktop RTX 4080 (dev) | Claude pane (Chromium) | 300 | 144 (vsync) | 55 | 87k | 1.5–3.4 ms | 1.8 ms | 300 packed around player = worst case |
| Laptop Intel Arc | Chrome | 200 | 60 (vsync) | 59 | 89k | 1.98 ms | 0.50 ms | measured in the Spike B scene (horde + full style), all 200 packed on the player = worst case; see 0.4 |
| Laptop Intel Arc | Chrome | 300 | — | — | — | — | — | not measured yet (headroom check, not a pass criterion) |

Findings so far:
- A full per-cell direction pass cost ~7 ms per recompute on web → directions are now resolved lazily
  only for cells agents stand in (flow field 6.8 → 1.8 ms; the rest is the BFS).
- Worst case is CPU, not GPU: separation cost grows when the whole horde piles on the player.
  If Arc misses the target, first lever = cap separation neighbours per agent; fallback per plan = cap 100.

## 0.4 Spike B — "Style 1.5" look — ✅ pass (perf on Arc 2026-10-26; look accepted by J 2026-10-27)

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
| Desktop RTX 4080 | desktop GL Compatibility 1080p | style + 200 zombies | 144 (vsync) | 48–55 | 88k | capture used for the comparison (`--hide-ui`) |
| Desktop RTX 4080 | Claude pane (Chromium) | style + 200 zombies | 144 (vsync) | 45 | 69k | horde update 1.8 ms |
| Laptop Intel Arc | Chrome | style + 200 zombies | 60 (vsync), process 6.2 ms | 59 | 89k | build `5073dbb · #10`; 200 packed on the player (worst case); objects 456, VRAM 62.7 MB, horde update 1.98 ms, flow field 0.50 ms. Adapter reads "WebKit WebGL" (Chrome masks the GPU name); device per J |

Arc notes:
- Pass with margin: 60 FPS is the display's vsync cap, draw calls are 59 of 250, primitives 89k of 300k.
- The overlay's ms value is `TIME_PROCESS` (CPU script time): 6.2 of 16.7 ms. GPU time is not measured,
  so the real headroom above 60 FPS is unknown. That is enough for the gate; measure it only if a later
  phase gets close to the budget.

Look verdict (J, 2026-10-27, live URL build `d1a18ab · #28`, i.e. with the desolate pass and PR #9):
"บรรยากาศเริ่มเข้าที่เข้าทางแล้ว" ("the atmosphere is starting to fall into place") → accepted for Phase 0. Further tuning of mood
(`decay`, light, fog, grade) is content work for later phases.

Known gaps vs reference: no roof clutter (tents, garden, solar), shorter/cooler shadows, water a bit brighter,
no ladders/bridges/trees/boats. These are content, not renderer limits.

### 0.4b Abandoned / desolate pass (J's request, 2026-10-26)

Comparison: `docs/art/06_desolate_vs_spike_b.png` (left: PR #4 look, right: this pass).

| Item | How | Result |
| --- | --- | --- |
| Weathering | `kit_building.py` `decay` 0..1: aged palette, rain streaks from parapets and sills, peeling patches (vertex colour per 0.8 m quad) | base 0.45, backdrops 0.85–0.9 |
| Windows | per window: lit / intact / broken (void + shards) / boarded / frame gone | base keeps a boarded floor and a few lit rooms; backdrops dark |
| Ruins | parapet gaps and broken segments; `building_brick_2f` roof hole; `building_concrete_5f` top-corner collapse with rubble and rebar | still 1 draw call per building |
| Overgrowth | vines down facades, moss along parapets, weeds and debris on derelict roofs | |
| Flood props | `prop_flood_debris_a/b`: sunken car, leaning dead lamp, dead tree, road sign, planks, barrels, tyres, trash | 664 / 748 tris; lighter algae tint via group `floating` |
| Grade | cooler sun (1.45), grey-green fog from 50 m, Environment adjustments: saturation 0.8, contrast 1.1 | adjustments work in Compatibility (desktop GL + WebGL2) |

Tris: base 20.2k, brick 9.4k, concrete 15.5k (were 11.9k / 4.4k / 7.1k).

| Device | Browser | Scene | FPS | Draw calls | Primitives | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Desktop RTX 4080 | desktop GL Compatibility 1080p | style + 200 zombies | 144 (vsync) | 49 | 131k | capture for `06` |
| Desktop RTX 4080 | Claude pane (Chromium), local web export | style + 200 zombies | 144 (vsync) | 58 | 129k | horde update 2.0 ms, no console errors |
| Laptop Intel Arc | Chrome | style + 200 / 300 zombies | — | — | — | **skipped by J (2026-10-27)** |

Arc for 0.4b skipped by J: low risk. Draw calls are unchanged (~59 of 250), and primitives rose ~47% to
~131k of 300k; the PR #4 look ran at the 60 FPS vsync cap on Arc. The default scene carries this look, so
the next Arc measurement of any spike (e.g. 0.7) covers it in passing.

## 0.5 Spike C — Twin-stick feel — 🟡 mouse + keyboard pass (J, 2026-10-27); gamepad pending (no pad yet)

Live: default URL (`?spike=twinstick`) = Spike B scene + horde + two supply crates. Spike B stays at
`?spike=style`, Spike A at `?spike=horde`. All three use the new player controls.

| Action | Mouse + keyboard | Gamepad (Xbox layout) |
| --- | --- | --- |
| Move | WASD | Left stick |
| Aim | Mouse | Right stick (+ aim assist) |
| Fire | LMB | RT |
| Reload | R (auto on empty) | X |
| Throw grenade | hold RMB → ring at cursor, release | hold LT → ring along aim / on assist target, release |
| Interact (crate restocks grenades) | F | A |
| Orders wheel | hold Tab, move mouse, release (Esc cancels) | hold Y, right stick, release (B cancels) |
| Camera rotate 90° | Q / E | LB / RB |
| Zoom | Wheel | D-pad up / down |
| Tuning panel (pauses) | F4 | Start |
| Debug overlay | F3 | Back |

| Item | How |
| --- | --- |
| Iso aiming | Mouse ray hits a plane at body height (0.9 m), not the floor: on a −35° iso camera the floor plane aims ~1.3 m behind a zombie under the cursor (unit test) |
| Aim assist | Gamepad only: zombie with the smallest angle inside ±12° and 18 m, line of sight via the NavGrid, aim bent 60 % toward it; aim line turns green while it holds a target |
| Camera-relative | Move/aim map through the camera's yaw every frame, so they follow a 90° turn (0.25 s tween) |
| Movement | Accel 40 / decel 60 m/s² toward 4.5 m/s (was instant) |
| Tunables | `data/input/twin_stick.tres`, rifle magazine/reload in `spike_rifle.tres`, grenade in `spike_grenade.tres`; the panel edits them live, not saved; its bottom line lists every value for a screenshot |

Checked by Claude (desktop GL, Arc 140V, scripted input): mouse aim + fire, throw ring → flight → blast
kills, pad aim with assist (green line), wheel pick + order toast, camera turn, tuning panel pause,
crate restock. Unit tests: aim math, aim assist, NavGrid ray, wheel sectors (41 total).
**Not checked: how it feels.** That is J's call: 10 min per device.

| Device | Input | Verdict | Tuned values (panel summary line) | Notes |
| --- | --- | --- | --- | --- |
| J's machine (not stated), Chrome, live URL `d1a18ab · #28` | Mouse + keyboard | ✅ "no problems felt" | defaults (no tuning reported) | J, 2026-10-27 |
| — | Gamepad | — | — | **J: pending, no gamepad yet** |

## 0.6 Spike D — Save on web — ✅ pass (J, 2026-10-27)

Live: default URL (`?spike=save`). Twin-stick stays at `?spike=twinstick`, Spike B at `?spike=style`,
Spike A at `?spike=horde`.

| Item | How |
| --- | --- |
| SimCore | `sim/sim_state.gd` (clock, survivors, stockpile, daily upkeep tick), `sim/survivor.gd`; numbers in `data/sim/base_economy.tres` (GDD §11 upkeep) |
| Format | `sim/save_codec.gd`: JSON envelope `{game, schema, build, saved_unix, state}`; schema 1; migrations run one version at a time (`MIGRATIONS`); newer-schema, foreign and damaged files are refused with a message |
| Storage | `platform/save_store.gd`: one slot in `user://saves/` (IndexedDB on web); write to `.tmp` → rename, previous save kept as `.bak`, load falls back to it if the main file is damaged |
| Export / import | `platform/save_transfer.gd`: web = browser download + `<input type=file>` via JavaScriptBridge; desktop = native file dialog |
| Spike UI | Next day (autosave, like the real game) · Scavenge · Save · Load · Export · Import · New game; every action is a focusable button (mouse, keyboard, gamepad A); shows "Storage persistent" from `OS.is_userfs_persistent()` |
| Tests | SimState upkeep/shortage, codec round trip (incl. seeds > 2³¹), refusals, migration chain, store backup fallback: 16 new, 62 total |

Checked by Claude (desktop RTX 4080):

| Device | Browser | Check | Result |
| --- | --- | --- | --- |
| Desktop | desktop GL, two runs | quit → relaunch loads the save | ✅ |
| Desktop | Claude pane (Chromium), local web export | Next day ×2 → page reload → "Loaded day 3", same stock | ✅ no console errors; storage persistent: yes |
| — | — | export / import file | not checked: needs the browser's download and file picker (J) |

| Device | Browser | Check | Result |
| --- | --- | --- | --- |
| J's machine (not stated) | Chrome, live URL `7e2ba96 · #39` | save spike checks in Chrome | ✅ "no problems" (J, 2026-10-27) |
| J's machine (not stated) | Chrome → Edge/Firefox, live URL `7e2ba96 · #39` | export file → import → same day and stock | ✅ same day and stock (J, 2026-10-27) |
