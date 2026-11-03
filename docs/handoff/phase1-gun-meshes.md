# phase1/gun-meshes

- **PR:** #41 (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ d5cffe0
- **Updated:** 2026-11-03

## J asked
"Start the guns": the PHASE1 1.1 asset job, 4 low-poly guns in the player's hands + the 4 attachments. After
this, section 1.5+ (PR #40: audio, survivor body, stances, HUD, teammates) comes before gate 1.G.

## Done
- `tools/blender/kit_guns.py`: gun_pistol_9mm, gun_ar_556, gun_shotgun_12g, gun_dmr_308 + att_silencer,
  att_red_dot, att_extended_mag, att_flashlight (.glb), and a `GunModel` .tres per gun (muzzle + slot mounts).
- `WeaponConfig.model`, `AttachmentConfig.mesh_scene` / `muzzle_extend_m`; `GunView` (game/) under the player's
  aim marker; `SpikePlayer.muzzle_position()` feeds the muzzle flash and casings.
- `Style15Level.apply_materials()` is static now (GunView uses it).
- 4 new tests, 182 total, all passing on desktop.

## Not done / next
- The capsule body stays until 1.5+ A2 (survivor body); then the gun moves into the hand bone and gets the
  sprint carry poses (high ready / port arms).
- Not measured on the Arc: + 1 draw call for the gun and 1 per attachment, each with a shadow pass.

## J must test
- `?spike=arena`: switch guns 1–4. Each gun shows in hand with its attachments (AR: red dot, extended mag,
  flashlight; pistol: silencer, flashlight). Can you tell which gun is in hand at normal zoom?
- Shoot the silenced pistol: the flash comes from the end of the silencer.

## Next session must know
- Rebuild: `blender -b --factory-startup --python tools/blender/kit_guns.py`. Barrel along Blender −Y (Godot +Z),
  origin at the grip; the kit writes the mounts, never edit the .tres by hand.
