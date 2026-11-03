# phase1/zombie-meshes

- **PR:** #37 (CI build passed on 7d3f4f3)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ 0d5ffd6
- **Updated:** 2026-11-03

## J asked
"ซอมบี้ 3 แบบ": the desktop Blender job from PHASE1 1.2, Runner / Armored / Bloater meshes + VAT clips, and the
Armored helmet drop that waited for the mesh.

## Done
- `tools/blender/kit_zombie.py` MODELS: zombie_runner, zombie_armored (helmet = extra part 11), zombie_bloater,
  each with its own walk loop (sprint / march / waddle); attack, flinch and death clips are shared.
  `-- models_dir vat_dir name...` rebuilds just the named models.
- `EnemyConfig.models`, `HordeConfig.look_range` / `looks`; HordeRenderer and CorpseLayer draw one MultiMesh per look.
- Helmet drop: `EnemyConfig.helmet_hp` / `armor_after_helmet`, `Horde.helmet_drops`, `CorpseLayer.add_helmet`.
- Bug fix: part index in UV.y reached Godot flipped (0.5 − part) since 0.7; fixed in the kit, Walker .glb rebaked.
- 5 new tests, 177 total, all passing on desktop.

## Not done / next
- Gun meshes + attachments (the other desktop Blender job).
- Not measured on the Arc. A few more draw calls: 3 more looks × (horde + corpses), each with its shadow pass.

## J must test
- `?spike=arena`: can you tell the four types apart at a glance at normal zoom? Runner = thin, rust top, sprinting
  bent over; Armored = dark navy, helmet; Bloater = swollen yellow. Screenshot: `docs/art/07_zombie_types.png`.
- Shoot an Armored with the AR: the helmet flies off after a few hits and it goes bareheaded. Frag: it drops at once.
- Gore: severed limbs should now be the right pieces (head, arm, leg), not odd chunks.

## Next session must know
- Hidden-part bits are now 0..11, burning bit 12, spot fire 13..16 (shader + HordeRenderer + CorpseLayer agree).
- Re-run the kit with Blender 4.4: `blender -b --factory-startup --python tools/blender/kit_zombie.py`.
