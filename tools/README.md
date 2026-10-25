# tools/

## blender/ — procedural asset & mockup scripts

Run headless with the Blender Python module (no Blender GUI needed):

```bash
pip install bpy==5.2.3          # Python 3.13; matches the version these scripts were written for
python3 tools/blender/scene_v15_web.py -- out.png 1920 1080 32   # W H Cycles-samples
```

| Script | What it is |
| --- | --- |
| `scene_v15_web.py` | **Chosen style 1.5** — horde-night mockup, flat palette + waterline stain, WebGL2-safe effects |
| `scene_v2_realistic.py` | Rejected "stylized realism" (procedural PBR weathering) — reference only, too costly for web |
| `scene_v1_flat.py` | First flat mockup — reference only |

Notes for turning these into game assets:
- Geometry helpers use `bmesh` (fast; `bpy.ops` per object was ~200× slower).
- Materials here are Cycles node trees for mockups. For the game, export geometry as .glb and recreate the
  look with Godot shaders (see `CLAUDE.md` → Art direction). The waterline stain is just
  `mix(base, wet, smoothstep(2.4, 0.3, world_y - water_level))`.

### Game-asset kits (source of truth for `assets/models/*.glb`)

```bash
blender -b --factory-startup --python tools/blender/kit_building.py -- assets/models [name ...]
blender -b --factory-startup --python tools/blender/kit_props.py -- assets/models
```

| Script | Output |
| --- | --- |
| `kit_common.py` | palette, `MeshBuilder` (boxes/cylinders with per-corner colour + material slot), Cycles AO → vertex alpha, glTF export |
| `kit_building.py` | `building_base_3f` (playable roof 25×21 inside the parapet), `building_brick_2f`, `building_concrete_5f`; origin = water surface |
| `kit_props.py` | `prop_water_tower`, `prop_ac_unit`, `prop_sandbag_wall`; origin = roof surface |

Vertex RGB = palette colour (linear), vertex alpha = baked AO; material slot `surface` / `emissive` is swapped
for the Style 1.5 shaders at runtime (`game/level/style15_level.gd`). Tested with Blender 4.4.3.
Never edit the .glb files — change the script and re-run.

## mockup/ — HUD overlays (Pillow) used on the mockup renders
`python3 tools/mockup/hud_v15.py in.png out.png`
