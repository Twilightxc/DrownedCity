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
| Laptop Intel Arc | Chrome | style + 200 / 300 zombies | — | — | — | skipped by J (2026-10-27); covered by the 0.7 Arc runs (2026-10-28, 60 FPS) |

Arc for 0.4b skipped by J: low risk. Draw calls are unchanged (~59 of 250), and primitives rose ~47% to
~131k of 300k; the PR #4 look ran at the 60 FPS vsync cap on Arc. The default scene carries this look, so
the next Arc measurement of any spike (e.g. 0.7) covers it in passing.

## 0.5 Spike C — Twin-stick feel — ✅ mouse + keyboard pass (J, 2026-10-27); gamepad feel deferred by J

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
| — | Gamepad | deferred by J (2026-10-27) | — | no pad at hand; not a Phase 0 exit blocker, test when a pad is available |

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

## 0.7 Spike E — Animated horde, corpses and blood — 🟡 part 1 (animated horde) built

Live: `?spike=style` and `?spike=twinstick` use the animated horde; `?spike=horde` keeps the box placeholder
for comparison. The default URL is still the save spike.

| Item | How | Result |
| --- | --- | --- |
| Zombie | `tools/blender/kit_zombie.py`: rigid-part figure (11 parts, boxes), male + female variants | 180 tris each (target ≤ 500) |
| Clips | walk (loop, by distance walked), attack, flinch, death, death_blown (fake ragdoll); hand-keyed stand-ins until J's Mixamo clips | 102 frames at 24 fps |
| VAT | every mesh corner's position + normal per frame → two half-float EXR textures per variant (360 × 102); column index in UV.x, so import order doesn't matter | 140 KB + 37 KB per variant |
| Import | VAT EXR: VRAM Uncompressed, no mipmaps (`.import` written by the kit); zombie `.glb`: LODs, shadow meshes, tangents off (they rebuild buffers from the rest pose) | |
| Shader | `game/shaders/horde_vat.gdshader`: `texelFetch` two rows from `INSTANCE_CUSTOM`, blends, same Style 1.5 colour/AO | works in desktop GL Compatibility and WebGL2 |
| Horde | `Horde.Anim` per agent (walk / attack / flinch) + time, heading turns to the target when standing; `HordeRenderer`: one MultiMesh per variant | 2 MultiMeshes → +2 draw calls (+ shadow) |
| Tests | VatClips rows (loop wrap, one-shot hold), walk phase by distance, attack → walk, kill keeps anim state: 6 new, 68 total | |

Finding: the glTF vertex colour reaches `COLOR` one sRGB decode darker than the palette, so the dark clothes
rendered black; `horde_vat.gdshader` re-encodes it. `style15_surface.gdshader` (buildings) reads `COLOR` the
same way, so the building palette may be darker than authored; not changed here because J accepted that look.

| Device | Browser | Scene | FPS | Draw calls | Primitives | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Desktop RTX 4080 | desktop GL Compatibility 1080p | style + 200, box placeholder (before) | 144 (vsync) | 50 | 136k | from the 2026-10-27 Forward+ comparison |
| Desktop RTX 4080 | desktop GL Compatibility 1080p | style + 200, animated | 144 (vsync) | 53 | 215k | horde casts animated shadows |
| Desktop RTX 4080 | Claude pane (Chromium), local web export | style + 200, animated | not valid (pane hidden, throttled) | 63 | 209k | horde update 2.5 ms, render sync 0.2 ms, no console errors |
| Laptop Intel Arc 140V | Claude pane (Chromium) 800×673, live build `097bd56 · #52` | style + 200, animated, no shooting, packed on the player | 60 (vsync) | 63 | 209k | horde update 4.89 ms (crowd packed: separation), flow field 1.00 ms; also covers the 0.4b look |

Budget note: +80k primitives for 200 zombies (180 tris × main + shadow pass). 300 zombies should land near
255k of 300k; if Arc or the corpse cap pushes past budget, the first levers are no horde shadows on the far
split, then a coarser mesh for distant zombies.

### 0.7 part 2 — hit reaction, corpses, blood, dismemberment, gore toggle

| Item | How |
| --- | --- |
| Hit | `Horde.apply_damage(agents, damage, source, blast)`: survivors flinch (VAT clip) and slow down (−30 % for 0.4 s per hit, stacks to 1.2 s; `HordeConfig`, 0 for armored later); hits and deaths queue as events |
| Corpses | `game/fx/corpse_layer.gd`: ring buffer (cap 160) per look, death clip once then hold; `death_blown` for blasts, facing the blast; old corpses sink through the floor (45 s, or early when the ring is about to wrap); off-grid corpses float 6 s, then sink; no corpse shadows (half the cost) |
| Dismemberment | 12 % per bullet kill, 60 % per blast: the corpse hides a part group (head, arm, forearm, shin, leg) via a bitmask in `INSTANCE_CUSTOM.w` against the part index in UV.y; the limb is the same mesh with every other part hidden, thrown 0.5–1.3 m along the push |
| Blood | `game/fx/blood_fx.gd`: droplet bursts along the bullet (cap 256), flat pools (cap 160) from hits (30 %) and under every corpse; grow in, shrink out after 60 s; no decals (Compatibility has none) |
| Toggle | `GoreConfig.enabled` (`data/fx/gore.tres`): off = no blood, no dismemberment, corpses stay; in the F4 / Start tuning panel on `?spike=twinstick` with the dismember chance and hit slow |
| Test harness | `-- --auto-shoot` / `&autoshoot=1`: fire at the nearest zombie every 0.1 s, a grenade every 4 s; repeatable load for measurements |
| Tests | hit slow/flinch/events, slow speed, death event, corpse cap, sink, dismember masks + limb throw, gore off, blast facing, pool ring, one long frame: 10 new, 78 total |

| Device | Browser | Scene | FPS | Draw calls | Primitives | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Desktop RTX 4080 | desktop GL Compatibility 1080p | style + 200, auto-shoot, ~60 corpses (corpse shadows on) | 144 (vsync) | 65 | 268k | led to turning corpse shadows off |
| Desktop RTX 4080 | desktop GL Compatibility 1440p | style + 200, auto-shoot, corpse shadows off | 144 (vsync) | 56 | 240k | |
| Desktop RTX 4080 | ANGLE (GLES3 on D3D11) 1080p | style + 200, auto-shoot | 143 | 59 | 233k | corpses + pools draw as on desktop GL |
| Desktop RTX 4080 | Claude pane (Chromium), local web export | style + 200, `&autoshoot=1`, 145 corpses, 160 pools | 140–144 | 70 | 239k | no console errors; horde update 1.3 ms |
| Laptop Intel Arc 140V | Claude pane (Chromium) 800×673, live build `097bd56 · #52` | style + 200, `&autoshoot=1`, ~60 s, 143 corpses, 160 pools | 60 (vsync) | 70 | 239k | horde update 2.80 ms, render sync 0.39 ms, flow field 0.50 ms |
| Laptop Intel Arc 140V | same | style + 300, `&autoshoot=1`, ~60 s, 141 corpses, 160 pools | 60 (vsync) | 70 | **292k** | horde update 5.67 ms, render sync 0.57 ms; 3 % under the 300k budget |

Arc run 2026-10-28 (Claude in the Claude app's browser pane on the laptop, pane visible; not full-screen
Chrome, so fill rate is lighter than the real target):
- **Pass at 200** with margin on draw calls; primitives 239k of 300k.
- **300 is at the edge:** 292k primitives. Before 300 is a real target, take the levers above (no horde
  shadows on the far split, lower corpse cap in `data/fx/gore.tres`, coarser distant mesh).
- The overlay's ms value (`TIME_PROCESS`) read 10.9–31.5 ms while FPS held 60, so on web it is not the
  frame time; use it only to compare runs.
- J's verdict on `?spike=twinstick` (D): the zombie motion and the gore read well (2026-10-28).
- Still to do: one run in full-screen Chrome to confirm fill rate.

Found on the way: a resumed background tab hands the next frame a multi-second delta; the corpse and blood
timers now clamp it like the horde does, or every corpse sank at once.
