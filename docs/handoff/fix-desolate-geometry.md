# fix/desolate-geometry

- **PR:** not opened (pushed: yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ `8ec3c6d`
- **Updated:** 2026-10-27

## J asked
"แก้ 2 จุดจาก Copilot PR #5 (หลุมหลังคาตึกอิฐ, กิ่งไม้ลอย) เป็น PR ใหม่ใน worktree แล้ว regen glb"

## Done
- Roof hole (`building_brick_2f`, Copilot r4373447057): the body's top face is now cut open where the slab is
  missing. `MeshBuilder.box` drops a quad when `face_color` returns None. The hole is a shaft down to the
  top-floor slab: interior walls, a dark floor and fallen roof chunks. The hanging slab pieces now show.
- Floating branch (`prop_flood_debris_b`, Copilot r4373447081): dead-tree branches are spread between 1.4 m and
  0.15 m below the trunk tip, so every one starts on the trunk.
- Regenerated `building_brick_2f.glb` (9588 tris) and `prop_flood_debris_b.glb` (748 tris).
- 43 GUT tests pass. Desktop capture: 50 draw calls, 132k prims, 200 zombies.

## Not done / next
- The brick roof's dressing (moss, weeds, debris) is laid out differently now: the shaft uses random numbers
  first, which shifts the random sequence. This is expected and has no gameplay effect.

## J must test
- Live URL after merge: the brick building's roof hole shows slabs hanging into a dark shaft. The dead tree in
  the water has no floating branch.

## Next session must know
- No overlap with other branches: this branch touches only `tools/blender/kit_*.py` and two .glb files.
