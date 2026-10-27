# Decisions log (newest first)

| Date | Decision | Why |
| --- | --- | --- |
| 2026-10-27 | Fake ragdoll for the horde: "blown back" death clip + corpse slides along an arc; limbs are capped rigid bodies; real ragdolls only for few human enemies on the desktop High preset, later | J; the horde is MultiMesh + VAT with no skeleton, and physics per zombie breaks the web budget |
| 2026-10-27 | Spike 0.7 also measures explosions, burning zombies, ground fire and the flying-limb cap on Arc | J; these effects are the next likely budget breakers |
| 2026-10-27 | Weapon names are semi-fictional (based on real patterns, no brand or trademark names such as Colt, Kalashnikov, AK-47) | J; trademarks on some gun names in some countries; decide final names before the Steam page |
| 2026-10-27 | Weapon classes: AR = automatic 5.56/7.62, Rifle = semi-auto DMR .308, plus Sniper, Pistol, SMG, Shotgun, LMG, grenade launcher, flamethrower; one stat schema in `data/weapons/` with L/M/H armour and cover penetration; starting balance by sustained DPS vs a 100 HP Walker (GDD §6) | J's list and stat structure; one table keeps penetration readable |
| 2026-10-27 | Seasonal water: 2 seasons on a 21-day cycle, one floor apart; hot season drops one floor (never to the streets) and opens it for search; rainy season floods it back; a held floor needs pumps running all season or permanently sealed openings (replaces the 3-season version) | J |
| 2026-10-27 | Design proposals added to GDD for J's review: traits table, gun attachments, shared explosive payloads, building occupants, airdrops, construction with roof bridges, 3-level destruction, loot and quest layers, interior exploration with a cutaway camera, UI screen list; not yet in the hour estimate | J's request for design help; demo cut proposal in GDD §17 |
| 2026-10-26 | Claude sessions work in a git worktree (`.claude/worktrees/<branch>`), never in the main checkout; remove it after the last commit so GitHub Desktop can push | GitHub Desktop switched the shared checkout and stashed a session's work twice in one day |
| 2026-10-26 | Survivors are individually recognisable: male/female bodies (men larger on average), build, height, skin tone (6–8), hair/beard; stored in SimCore; cosmetic only | J's request; pillar 1 "every survivor matters" (GDD §3) |
| 2026-10-26 | One humanoid rig for survivors and human enemies: 2 base bodies + build blend shapes + bone scale; hair as a modular head piece (replaces "one base mesh") | Shares Mixamo clips; ≤ 6 survivors keeps cost low (GDD §13) |
| 2026-10-26 | Animation: people = skeleton + AnimationTree with upper/lower split (8-way walk while aiming); horde = vertex animation textures on the MultiMesh, no per-zombie skeleton | Realistic motion (J) within the 200-zombie WebGL2 budget; twin-stick strafing |
| 2026-10-26 | Zombie sub-variants inside each type (male/female, build, clothing by origin); the type's silhouette stays dominant; human enemies use the survivor character system + faction colours | J's request; readability pillar (GDD §9) |
| 2026-10-26 | Hit/death feedback: brief slow on unarmored enemies, blood bursts + pools, corpses stay (capped, fade/sink), random dismemberment on death, gore on/off setting; low-poly style, no ragdolls | J's request; caps keep the web budget; toggle for rating and streaming (GDD §6) |
| 2026-10-26 | Add Phase 0 spike 0.7 (animated horde + corpses + blood, measured on Arc) | Only new request that can break the 200-zombie web budget; Phase 0 estimate 25 → 33 h, demo ~650 → ~700 h |
| 2026-10-26 | Multi-machine handoff: one note per branch in `docs/handoff/<branch>.md` + `tools/handoff.sh` at session start | Claude Code memory is per machine; per-branch files never conflict on merge; the 0.5 session only found PR #5 when GitHub Desktop switched branches |
| 2026-10-26 | Mouse aim ray hits a plane at body height (0.9 m), not the floor | Iso pitch makes the floor point land ~1.3 m behind the zombie under the cursor |
| 2026-10-26 | Gamepad aim assist = bend toward the best target in a ±12° / 18 m cone with line of sight (60 %); no assist on mouse | "Light assist, pad only" from Phase 0.5; numbers are live-tunable |
| 2026-10-26 | Pad layout: RT fire, LT throw, X reload, A interact, Y orders wheel, LB/RB camera, D-pad ↑↓ zoom, Start tuning, Back overlay | Shoulders were promised to camera turn; D-pad ←→ already drive the horde slider |
| 2026-10-26 | Orders wheel reads mouse motion since it opened (not cursor position); stick release keeps the last pick | Works on the web without pointer lock; letting go of the stick first doesn't cancel |
| 2026-10-26 | Feel numbers live in `data/input/twin_stick.tres`, edited live by an F4 / Start panel (not saved) | J tunes on the web build without a rebuild, then reports the values |
| 2026-10-26 | Whole-scene mood = abandoned / desolate (J): weathered kit (`decay` per building), ruins, overgrowth, flotsam, cooler graded light | J's call after Spike B; loneliness supports the survival tone, lit base windows become the only sign of life |
| 2026-10-26 | Weathering is baked into vertex colour per 0.8 m quad (streaks, peeling patches), not shader noise or decals | Keeps 1 draw call and no textures per building; deterministic from the kit seed |
| 2026-10-25 | Spike launcher: default = newest spike, older via `?spike=<name>` (web) / `--spike=<name>` (desktop) | Spike A Arc test must stay reachable while Spike B is live |
| 2026-10-25 | Asset format: palette colour in vertex RGB + baked AO in vertex alpha, one shared Style 1.5 shader; lit windows on a 2nd surface | ~1–2 draw calls per building, no textures, matches flat palette |
| 2026-10-25 | Baked lighting = Cycles AO into vertex colours (Blender), not LightmapGI | LightmapGI baking needs RD hardware + manual editor step; vertex AO is scripted and reproducible |
| 2026-10-25 | Water "depth" tint and foam from a footprint SDF (≤ 16 boxes) instead of the depth texture | No extra depth pass on iGPU/WebGL2; buildings are boxes anyway |
| 2026-10-25 | Asset kits run on installed Blender 4.4 (`blender -b --python`); `bpy` pip wheel needs Python 3.13 | No extra Python install; kits use only bmesh + glTF exporter APIs stable across 4.4–5.x |
| 2026-10-25 | Main scene = current spike (horde spike for 0.3); add a launcher only if several spikes must be live at once — superseded by the spike launcher | Live URL always shows what J must test |
| 2026-10-25 | Debug overlay and spike harness text skip `tr()`; player-facing text still goes through `tr()` | Developer-only text; avoids translation churn on throwaway UI |
| 2026-10-25 | Horde = struct-of-arrays `RefCounted` in `combat/` + one MultiMesh; flow field resolves directions lazily | No nodes/physics per zombie; per-cell direction pass was 7 ms on web |
| 2026-10-25 | Pin Godot 4.7.2-stable (`.godot-version`, read by CI) | Latest stable at Phase 0 setup |
| 2026-10-25 | Test framework: GUT 9.7.1, vendored in `addons/gut`, excluded from export | Pure GDScript, one-line headless CLI with non-zero exit on failure; vendoring pins the version for CI |
| 2026-10-25 | Build number = CI-written `platform/build_info.json` (short SHA, UTC date, run #); local runs show `dev` | Web build cannot call git; every bug report maps to a commit |
| 2026-10-25 | Debug toggles (F3) bind by keycode, not physical key; gamepad Back also toggles | F-keys are layout-independent; overlay must work on gamepad |
| 2026-10-25 | Keep original platform plan: free web demo → Steam EA → 1.0 (same codebase) | Full game is not limited by browser; demo still gives feedback + Steam wishlists |
| 2026-10-25 | GDScript only (no C#) | Godot cannot export C# to web as of Apr 2026 |
| 2026-10-25 | Day length 20–25 real min, not half day/half night | Day = decisions (long), night = horde burst or skip |
| 2026-10-25 | Demo language English; controller support from the demo | Wider tester pool; Steam Deck later |
| 2026-10-25 | Setting: fictional city inspired by recent real floods | Familiar feel without real place names |
| 2026-10-25 | Dev pace ≤ 5 h/day, no deadline; plan by milestones, not dates | J's availability |
| 2026-10-25 | Permadeath always; squads of 1–3 on expeditions | Core tension: risk vs firepower |
| 2026-10-24 | Hybrid genre: State of Decay management + Boxhead-style horde action | Long-form replayable game a solo dev can fill with systems |
| 2026-10-24 | Art "Style 1.5" (flat + atmosphere, WebGL2-safe) | Readable with 200 zombies, runs on iGPU/web |
| 2026-10-24 | Setting: flooded city, rooftop base, boats between buildings | Rooftop look with island-level technical cost |
| 2026-10-24 | Engine Godot 4, isometric orthographic 3D camera | Free, web export, light on laptop |
| 2026-10-24 | No bought assets; no voice acting (text + gibberish SFX) | Owner preference; procedural Blender pipeline |
