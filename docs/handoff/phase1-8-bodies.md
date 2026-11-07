# phase1-8/bodies

- **PR:** see below (pushed? yes)
- **Machine:** desktop (RTX 4080)
- **Base:** main @ ce10b36
- **Updated:** 2026-11-07

## J asked
"next แล้วเปลี่ยนโมเดลใน ?spike=base&rooms=tier2&hour=10&zoom=0&focus=-8.5,6.5" → 1.8 step 2, shown in the base.
After a first try with smooth skinned bodies J said: "ไม่ชอบแบบในภาพเลย รู้สึกว่าแบบเดิมสวยกว่า ที่ตัวละครเหลี่ยมๆ
คล้ายตัวละครในมายคราฟ ไปทุ่มพวกข้อต่อ รายละเอียดดีเทลดีกว่า" — so the bodies are blocky again, with joints and detail.

## Done
- `tools/blender/body_survivor.py` (used by `kit_survivor.py`): body_<male|female>_<slim|average|muscular|heavy>,
  hair_<buzz|short|messy|long|ponytail|bun>, beard_<stubble|beard|moustache>; rigid boxes per bone, joint blocks and
  details (see DECISIONS). The old 3 fixed outfits (survivor_0..2) are gone.
- `game/shaders/survivor.gdshader`: skin / hair / top / bottom / shoes tints by UV.x channel, Style 1.5 lighting.
- `SurvivorView.apply_look(look)`: the body, hair, beard, tints (outfit torso / legs colours) and height scale.
  `set_look(i)` = a stand-in look for fighters without a survivor. The base residents and the arena's community
  fighters (`set_survivor`) show their own look; the pose gallery shows a different person per pose.
- 3 tests; 403 passing. Captures `docs/art/30_survivor_bodies.png`, `docs/art/31_survivors_by_the_fire.png`.

## Not done / next
- Step 3: outfit pieces (5 sets × 4 slots) and patterns; until then the T-shirt / trousers take the outfit colours.
- Step 4 is mostly done here (apply_look in base + arena); what's left: a `?spike=looks` gallery.
- Step 5: Mixamo (J downloads).

## J must test
`?spike=base&rooms=tier2&hour=10&zoom=0&focus=-8.5,6.5` and `?spike=base&rooms=tier1&hour=19&zoom=0&focus=2,3`:
do the blocky bodies with joints and details look right? `?spike=poses`: do bends (crouch, prone, sit) hold together?
