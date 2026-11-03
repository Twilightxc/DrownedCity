# docs/desktop-to-arc

- **PR:** none (a note for the laptop; delete the branch once read)
- **Machine:** desktop (RTX 4080) → laptop (Intel Arc 140V)
- **Base:** main @ c23adb0
- **Updated:** 2026-11-04

## J asked
"วันนี้พอแค่นี้ เตรียมส่งต่องาน จะสลับไปใช้ Arc"

## State
Everything from the desktop is merged (PRs #37–#49). Pages: `index-c23adb0-142`.
- Phase 1 Part A (1.1–1.5) and section 1.5+ are all built: CC0 audio (A1), the skinned survivor body with its
  clips and left/right-hand IK (A2), stances / sprint / roll / stamina (A3), HP / stamina bars + reload ring + team
  cards (A4), two AI teammates Marco and Jess (A5).
- J's feedback rounds are in: hips follow the walk, rifles shouldered at 1.40 m, shoot over low cover (AC units,
  sandbags), downed 20 s with the pistol, 3 survivor outfits, 10 zombie looks, staged barricades, supply crate,
  frag + Molotov, guns slung / holstered, sparser facades with balconies and no lit windows.
- Every number and verdict is in `docs/PHASE1_RESULTS.md` (newest sections at the top).
- The obsolete laptop notes on `docs/laptop-handoff` and `docs/arc-handoff` say the Blender work is still waiting.
  It isn't: both branches can be deleted (J's OK).

## Next: gate 1.G on the Arc (J)
1. Pull main in GitHub Desktop (the desktop's main checkout was 51 commits behind; the laptop's likely too).
2. Chrome, https://twilightxc.github.io/DrownedCity/?spike=arena: play the night 3 times. Is it fun?
3. `?spike=arena&wave=6`: F3 overlay, note FPS, draw calls and primitives at the busiest moment. Pass: ≥ 50 FPS,
   < 250 draw calls, < 300k primitives. Desktop wave 5 was 90 draw calls / 92k primitives.
4. Compare with `&mates=0` (no teammates): too easy with them? (Marco, AR, out-killed the bot player 36 : 29.)
5. Write the numbers and the verdict into `docs/PHASE1_RESULTS.md` (1.G) on a branch, PR it.
Nothing in Part B starts before the verdict.

## Open, small (ask J before starting)
- Teammates can't help the player up yet ("DOWNED · nobody to help" still shows with them alive).
- Teammates don't throw grenades, crouch, or take gas / fire damage.
- Pad bindings are untested on a pad (J deferred pad tests).

## Next session must know
- Laptop: no Godot or Blender. Godot 4.7.2 for GUT tests must be downloaded into the session scratchpad (ask J).
  `gh` works there; `git push` needs `GCM_INTERACTIVE=always` and `GIT_TERMINAL_PROMPT=1`.
- Desktop: `gh` 2.103.3 is logged in as Twilightxc (PRs from either machine).
- Asset kits are the source of truth: rebuild with Blender 4.4 (`tools/blender/kit_*.py`); new zombie looks need
  `generate_lods` / `create_shadow_meshes` off in their `.glb.import` (the survivor's too: the shadow mesh drew nothing).
- Godot 4.7: a const `Dictionary[K, PackedStringArray / PackedFloat32Array]` built from literals reads back empty
  values; use `Array` values. Skeleton modifier results only exist inside `skeleton_updated`.
