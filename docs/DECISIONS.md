# Decisions log (newest first)

| Date | Decision | Why |
| --- | --- | --- |
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
