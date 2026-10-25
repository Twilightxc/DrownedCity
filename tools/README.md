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
- Next step: split scripts into a reusable kit (`kit_building.py`, `kit_props.py`, `kit_characters.py`) with
  one function per asset and a CLI that exports each to `assets/models/*.glb`.

## mockup/ — HUD overlays (Pillow) used on the mockup renders
`python3 tools/mockup/hud_v15.py in.png out.png`
