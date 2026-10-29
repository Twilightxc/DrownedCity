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

## 0.7 Spike E — Animated horde, corpses and blood — ✅ pass at 200 on Arc (web, 2026-10-28; part 4 in Chrome, J); 300 at the primitive budget edge

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

### 0.7 part 3 — fake ragdoll, flying limbs, burning, ground fire, blast effects

| Item | How |
| --- | --- |
| Fake ragdoll | Blast corpses slide 1–2.5 m away from the centre along an arc (0.45 s, 0.6 m high) while `death_blown` plays; `NavGrid.ray_distance` stops them 0.35 m short of walls; sliding off the roof lands them in the water (float, then sink) |
| Flying limbs | A severed limb is a `RigidBody3D` (box from `VatModel.part_bounds` of that part group, read once from the VAT image) thrown along the push; the corpse MultiMesh draws it from the body's transform. Cap 16 bodies (`limb_body_cap`): the oldest freezes as a still corpse part; bodies also stop after 4 s or when they fall in the water. Collision = roof slab + one box per run of blocked cells |
| Burning | `Horde.burn_left` per agent: tick damage (1 per 0.5 s for 4 s), spreads to touching zombies, faster lurch, water puts it out; burn deaths leave a charred corpse and no blood. Shader: bit 11 of `INSTANCE_CUSTOM.w` → darker albedo + emissive flicker. Flames: one shared additive billboard MultiMesh (`game/fx/fire_fx.gd`, cap 96), no node per zombie |
| Ground fire | `combat/ground_fire.gd`: timed NavGrid cells (cap 12, 6 s) with a flow-field cost (+6 steps; `FlowField.compute` takes a cost array and switches to a re-queueing FIFO search); zombies standing in a cell catch fire |
| Incendiary | `ThrowableConfig.fire_radius` / `fire_cells`: survivors within 5 m of the spike grenade catch fire, 6 cells start burning. `?spike=style` now carries the grenade too, so `&autoshoot=1` exercises everything |
| Blast fx | `game/fx/explosion_fx.gd`: one reused omni flash (0.18 s), debris boxes + low-poly smoke puffs from 3 CPU emitters per kind, scorch marks (ring of 24, one MultiMesh), water column instead when the blast lands in water |
| Warm-up | The first blast froze the frame for about 1 s (shader compiles: light, emitters, flames). The harness fires an invisible warm-up blast and flame inside the building at load; the first real blast now costs 24 ms at worst |
| Tunables | `data/fx/gore.tres` (slide, limb bodies, charred tint), `data/combat/fire.tres`, `data/weapons/spike_grenade.tres` |
| Tests | ground fire cap / burn-out / water / blocked, flow detour around fire, burn kill + charred + no blood, water, spread, fire under feet, no config; blast slide + wall stop + into water, limb body cap, charred corpse: 12 new, 90 total |

| Device | Browser | Scene | FPS | Draw calls | Primitives | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Laptop Intel Arc 140V | desktop GL Compatibility 1280×720 (Godot 4.7.2 editor binary) | style + 200, `--auto-shoot`, 20 s: corpses 160, limb bodies 16, up to 47 burning, 12 fire cells, 96 flames | 60 (vsync) | 73–77 | 222–249k | worst frame 17–24 ms outside screenshot frames; horde update 0.5–0.8 ms |
| Laptop Intel Arc 140V | Claude pane (Chromium) 800×673, live build `cdc2193 · #56` | style + 200, `&autoshoot=1`, ~60 s: corpses 160, limb bodies 16, 9 burning, 10 fire cells, 39 flames | 60 (vsync) | 73 | 243k | horde update 0.64 ms, render sync 0.31 ms, flow field 0.30 ms |
| Laptop Intel Arc 140V | same | style + 300, `&autoshoot=1`, ~60 s: corpses 160, limb bodies 16, **80 burning**, 10 fire cells, 90 flames | 60 (vsync) | 73 | **297k** | horde update 1.70 ms; 1 % under the 300k budget |

Arc web run 2026-10-28 (Claude in the Claude app's browser pane, visible; calibrated first with `?spike=horde`
at 59 FPS, because an earlier attempt read 1 FPS in every scene while the pane was throttled):
- **0.7 passes at 200** with blasts, burning, ground fire and the limb cap all live: 60 FPS, 73 draws, 243k.
- **300 is at the budget edge** (297k primitives) with 80 burning; take the levers above before 300 is a target.
- `VatModel.part_bounds` works on the web: no fallback warning in the console, limbs have their real size.
- The new effects add no draw calls in steady state (73 at 200 and at 300): every one is a MultiMesh or a
  shared emitter.
- Still not done: a run in full-screen Chrome (fill rate), and J's look at whether the blasts, limbs and fire
  read well.

### 0.7 part 4 — frag vs incendiary, blast force, spot fires, embers (J's look at part 3, 2026-10-28)

J: "ระเบิดอยากให้เพิ่มเอฟเฟคแรงระเบิดพวกเขม่า ฝุ่น ควัน สะเก็ดระเบิดชิ้นส่วนขาดกระเด็นแบบสุ่ม และไฟสำหรับระเบิดปกติอาจเป็น
สะเก็ดเล็กๆติดบนพื้น ส่วนที่ติดบนตัวอยากให้ติดเฉพาะจุดเล็กๆไม่ใช่ทั้งตัว ถ้าติดทั้งตัวควรเป็นระเบิดไฟ". J skipped the full-screen Chrome run.

| Item | How |
| --- | --- |
| Two grenades | `data/weapons/frag_grenade.tres` (damage 3, r 3 m, spot fires within 5 m at 35 %, 12 embers, shrapnel) and `incendiary_grenade.tres` (was `spike_grenade.tres`: damage 2, whole-body fire within 5 m, 6 ground cells). `SpikePlayer.throwables` + G / pad B to switch; the HUD shows the current one; autoshoot alternates |
| Spot fire | `Horde.ignite_spot`: `burn_spot` = part + 1 (torso..shins), 2.5 s, 1 damage per tick, no spread, no faster lurch; a death from it is not charred. A full ignite overrides a spot, never the other way. Shader: bits 12–15 of `INSTANCE_CUSTOM.w` light only that part; `FireFx` puts a half-size flame at the part's rough height |
| Blast force | `ExplosionFx`, per blast: additive fireball (bigger for incendiary), 40 hot shrapnel streaks (frag only), the debris, a black soot column, the grey smoke (longer), a tan dust ring pushed out along the floor. Finished emitters hide, so idle ones draw nothing |
| Embers | Ring of 64 small flame billboards on walkable floor only (`NavGrid`), 4–8 s, flicker, look only (no cost, don't ignite) |
| Limbs | A blast tears off 1–2 limb groups (`blast_limbs_max`), each turned up to ±0.8 rad off the push (`limb_spread`) |
| Flames | One soft radial-gradient texture for flames and embers: quads no longer read as squares |
| Tests | spot fire part / no spread / not charred / full overrides spot; multi-limb + scatter; embers only on walkable floor and burn out: 5 new, 95 total |

| Device | Browser | Scene | FPS | Draw calls | Primitives | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Laptop Intel Arc 140V | desktop GL Compatibility 1280×720 (Godot 4.7.2) | style + 200, `--auto-shoot`, 15 s, frag and incendiary alternating: up to 36 burning, 10 spot, 12 embers, limb cap full | 56–60 | 74–79 | ≤ 251k | worst frame 17–32 ms, plus one 49–62 ms frame ~1 s after the first incendiary in 2 of 3 runs (not at 300; cause not found) |
| Laptop Intel Arc 140V | same | style + 300, same | 58–60 | 74–79 | **≤ 301k** | worst 30 ms; 300 is now just over the primitive budget (two limbs per blast corpse) |

| Laptop Intel Arc 140V | Chrome, maximised window (~1920×1090), live build `c8db6be · #60` (J) | style + 200, `&autoshoot=1`, holding Incendiary: 31 burning (body), 4 fire cells, 43 flames, 8 embers, corpses 160, limb bodies 16 | 60 (4.7 ms) | 78 | 251k | horde update 0.81 ms, render sync 0.31 ms |
| Laptop Intel Arc 140V | same | same, holding Frag: 5 body / **4 spot** burning, 6 fire cells, 27 flames, 12 embers | 60 (5.9 ms) | 78 | 251k | flow field 0.40 ms |

Arc web run 2026-10-28 (J, in Chrome): **part 4 passes at 200**, with a large window, so fill rate is fine too
(4.7–5.9 ms per frame). Spot fires and embers work on the web. J: the look is good ("พอใจแล้ว"). At the default
zoom spot fires and embers are small; zoom in to see them. The single 49–62 ms frame seen on desktop GL after the
first incendiary was not checked on the web (two screenshots only).


## 0.8 Spike F — Building interiors with a cutaway camera — 🟡 part 1 (enter, storeys, cutaway) built

Live: default URL (`?spike=interior`); `&storey=2` starts inside on the top storey (0 = lowest). The base
building's roof has a hatch by the hut ([F] / A); the stairs are at the corridor's west end.

| Item | How | Result |
| --- | --- | --- |
| Kit | `tools/blender/kit_interior.py`: wall post + half-cell arm, window cell, doorway, floor tile, 4 m stair flight, bed, table, shelf, sofa, crate; 1 m grid, 3.2 m storey | 12–204 tris per piece |
| Layout | `game/interior/interior_layout.gd` (pure data, seeded): outer ring with windows, 2-cell corridor, rooms north and south with one door each, furniture against walls; switchback stairwell at the corridor's west end (flights alternate rows and ends) | 26 × 22 cells × 3 storeys for the base building |
| Water | storey 0 sits 1 m under the flood (kit_building waterline): drawn, not walkable; the flight down to it is closed | storeys 1–2 walkable |
| Builder | `game/interior/interior_builder.gd`: one MultiMesh per piece type per storey; storeys above the player and the building's exterior mesh + roof props switch to shadows-only, so the inside stays in the roof's shade | 89–112 draw calls inside, 49 on the roof |
| Cutaway | `game/shaders/interior_cutaway.gdshader`: discard above waist height (1.1 m) on the camera's side of the player (global uniforms, follow every 90° turn); cut back faces draw a dark cap | |
| Moves | roof hatch / inner hatch with a 0.25 s fade; stairs set the player's height every frame and switch the storey's NavGrid past half way (`InteriorController`); `SpikePlayer.set_floor` / `set_height` | |
| Tests | layout (seed, ring, reachability of every door, flooded storey, flights, stair height, furniture) + controller (storey switch both ways, cut follows player and camera turn): 11 new, 106 total | |

| Device | Browser | Scene | FPS | Draw calls | Primitives | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Desktop RTX 4080 | desktop GL Compatibility 1080p | interior spike on the roof | 144 (vsync) | 49 | 113k | |
| Desktop RTX 4080 | same | top storey (`--storey=2`) | 144 (vsync) | 103 | 146k | |
| Desktop RTX 4080 | same | middle storey (`--storey=1`) | 144 (vsync) | 89 | 137k | |
| Desktop RTX 4080 | Claude pane (Chromium), local web export | `&storey=2` | 141 | 112 | 129k | no console errors |
| Laptop Intel Arc | Chrome | `?spike=interior&storey=2` | — | — | — | **J** after part 2 (zombies inside) |

Found on the way: the fx warm-up drew one blast and flame 2 m under the player "inside the building"; with the
interior open it showed as a smoke puff in the corridor. It now runs under the flood water (`WARM_UP_Y`).