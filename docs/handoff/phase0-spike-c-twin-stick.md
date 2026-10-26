# phase0/spike-c-twin-stick

- **PR:** not opened yet. The branch is pushed (J pushed it from GitHub Desktop). Description draft: `build/PR_phase0.5.md` on the laptop only.
- **Machine:** laptop (ASUS, Intel Arc 140V)
- **Base:** `main` @ `5073dbb`. Does **not** include PR #5 (`phase0/spike-b-desolate`).
- **Updated:** 2026-10-26

## J asked
- Fill in the Arc results for 0.3/0.4 from J's screenshot. "Don't commit yet; include it in the 0.5 PR, then start 0.5."
- Phase 0.5 (`docs/PHASE0.md`): input map (move, aim, fire, reload, throw, interact, radial menu), iso-correct
  aiming, light aim assist on the gamepad only, and 90° camera turns that keep controls camera-relative.

## Done
- Arc results in `docs/PHASE0_RESULTS.md`: 60 FPS (vsync), 59 draw calls, 89k primitives, 200 zombies packed
  on the player. Build `5073dbb`, so this is the PR #4 look, not the desolate look.
- New default spike `?spike=twinstick` (`game/spikes/twin_stick_spike.tscn`, inherits `style_spike.tscn`):
  - supply crates
  - orders wheel (`ui/radial_menu.gd`)
  - F4 / Start live tuning panel
- Player (`game/spikes/spike_player.gd`, used by all three spikes):
  - accel/decel movement
  - mouse aim on a 0.9 m plane
  - pad aim assist (`combat/aim_assist.gd`)
  - magazine + reload
  - hold-to-aim grenades (`game/spikes/grenades.gd`)
  - aim line
  - interact
  - prompts that follow the last device used
- Camera: Q/E or LB/RB turns 90°; wheel or D-pad up/down zooms (`game/iso_camera_rig.gd`).
- New input actions in `project.godot`. Tunables in `data/input/twin_stick.tres`, `data/weapons/spike_grenade.tres`,
  and `spike_rifle.tres` (magazine).
- 41 GUT tests pass. A desktop run on the Arc with scripted input exercised every feature.

## Not done / next
- **Feel is unverified.** J plays 10 min per device, tunes with F4, and records the verdict and values in
  PHASE0_RESULTS §0.5.
- Web FPS/draw calls with the new HUD/aim line: not measured (no local web templates on the laptop).
- Orders only show a toast. Crates don't block the NavGrid. Tuning values are not saved.

## J must test
See PHASE0_RESULTS §0.5. In short:
- Mouse and gamepad, 10 min each. Watch the aim assist's green line, LT/RMB throw, the Y/Tab wheel and Q/E turns.
- F3 for FPS.

## Next session must know
- **Merge with PR #5:** code merges cleanly (checked with `git merge-tree`). Only `docs/DECISIONS.md` and
  `docs/PHASE0_RESULTS.md` conflict; keep both sides, newest rows first. After both merge, the twinstick
  scene picks up the desolate look through `style_spike.tscn`.
- The desolate look (131k primitives) still needs its own Arc measurement; the 60 FPS row above is pre-desolate.
- Crates sit at roof (-8, 3) and (6, -4). Move them if the base roof layout changes.
- Visual check without a human: a scratch `SceneTree` script (`-s drive.gd`) that loads the scene, fakes input
  with `Input.parse_input_event` (`InputEventAction` / `InputEventJoypadMotion`) and saves `root.get_texture()`
  frames. It is not in the repo.
