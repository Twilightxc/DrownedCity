# phase0/spike-e-horde-anim

- **PR:** not opened (pushed: yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ `23cae11`
- **Updated:** 2026-10-27

## J asked
"ต่อ 0.7" (PHASE0.md 0.7: animated horde, corpses, blood, dismemberment, gore toggle, plus fake ragdoll, fire,
explosions and the flying-limb cap added on 2026-10-27).

## Done (part 1 of 3: animated horde)
- `tools/blender/kit_zombie.py`: male/female zombie (180 tris), rigid-part rig, 5 hand-keyed clips, VAT bake
  to `assets/vat/` (half-float EXR + `VatClips` .tres + `VatModel` .tres).
- `game/shaders/horde_vat.gdshader`, `combat/vat_clips.gd`, `combat/vat_model.gd`; `Horde` animation state
  (`Anim`, `anim_time`, `heading`, `variant`); `HordeRenderer` is now a Node3D with one MultiMesh per look.
- style / twinstick spikes use the animated horde; horde spike keeps the box placeholder.
- 6 new GUT tests (68). Desktop: 144 FPS, 53 draws, 215k prims at 200. WebGL2 local export renders correctly.

## Not done / next
- Part 2 (next PR): hit flinch + slow, death clip → corpses (own MultiMesh, capped, fade/float/sink), blood
  bursts + pools, dismemberment, gore toggle.
- Part 3: fake ragdoll on blasts, burning flag, ground fire, flying limbs (cap 16), Arc measurement.
- Mixamo: J downloads clips; replace the stand-in clips (kit_zombie only needs per-part rotations).
- Arc measurement by J once parts 2–3 are in (also covers the 0.4b look).

## J must test
- `?spike=style` or `?spike=twinstick` (Ctrl+Shift+R): zombies walk with a limp, reach forward, swipe when
  they reach you, cast moving shadows. Does the motion read as zombies at this camera distance?

## Next session must know
- Zombie `.glb.import` must keep `generate_lods`, `create_shadow_meshes`, `ensure_tangents` off (VAT moves the
  vertices). The VAT `.exr.import` files are written by the kit (VRAM Uncompressed, no mipmaps).
- After a local web export, open the pane at a new origin (e.g. `http://127.0.0.2:8060/`): the pane caches
  `index.pck` per origin. FPS in a hidden pane is throttled and not valid.
- Building palette may be one sRGB decode darker than authored (see PHASE0_RESULTS 0.7 finding).
