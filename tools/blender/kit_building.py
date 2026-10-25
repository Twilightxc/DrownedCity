"""Style 1.5 flooded buildings -> assets/models/building_*.glb

usage: blender -b --factory-startup --python tools/blender/kit_building.py -- [out_dir]

Origin = water surface at the building centre. Roof top is at floors * FLOOR - WATERLINE_OFFSET,
so every building shares one water plane in Godot (y = water level) and stacks floors consistently.
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_common as K  # noqa: E402

FLOOR = 3.2
WATERLINE_OFFSET = 1.0   # water reaches ~1 m up the lowest dry floor
UNDERWATER = 3.4         # body continues below the water plane
PARAPET_H = 0.8
PARAPET_T = 0.5

# name, footprint (w, d), floors above water, wall colour, lit-window fraction, stair hut, seed
BUILDINGS = [
    ("building_base_3f", (26.0, 22.0), 3, "plaster", 0.10, True, 3),
    ("building_brick_2f", (14.0, 12.0), 2, "brick", 0.08, True, 5),
    ("building_concrete_5f", (12.0, 13.0), 5, "concrete", 0.05, False, 7),
]


def roof_height(floors):
    return floors * FLOOR - WATERLINE_OFFSET


def window(mb, x, y, z, normal_axis, out, lit_fraction):
    r = random.random()
    if r < lit_fraction:
        glass, mat = "lit", 1
    else:
        glass, mat = ("glass" if random.random() < 0.6 else "glass_dirty"), 0
    fw, fh = 1.3, 1.7
    if normal_axis == "y":
        mb.box((x, y + out * 0.05, z), (fw + 0.2, 0.1, fh + 0.2), "frame")
        mb.box((x, y + out * 0.11, z), (fw, 0.04, fh), glass, mat=mat)
        mb.box((x, y + out * 0.14, z), (0.06, 0.03, fh), "frame")
        mb.box((x, y + out * 0.17, z - fh / 2 - 0.12), (fw + 0.4, 0.3, 0.1), "trim")
    else:
        mb.box((x + out * 0.05, y, z), (0.1, fw + 0.2, fh + 0.2), "frame")
        mb.box((x + out * 0.11, y, z), (0.04, fw, fh), glass, mat=mat)
        mb.box((x + out * 0.14, y, z), (0.03, 0.06, fh), "frame")
        mb.box((x + out * 0.17, y, z - fh / 2 - 0.12), (0.3, fw + 0.4, 0.1), "trim")


def build(name, size, floors, wall, lit, hut, seed, out_dir):
    K.reset(seed)
    w, d = size
    top = roof_height(floors)
    mb = K.MeshBuilder()

    # body, roof slab, slab bands at every floor line
    bottom = -UNDERWATER
    body_top = top - 0.12  # the roof slab sits on top; coplanar faces would z-fight
    mb.box((0, 0, (body_top + bottom) / 2), (w, d, body_top - bottom), wall, seg=1.6)
    mb.box((0, 0, top - 0.06), (w - 2 * PARAPET_T, d - 2 * PARAPET_T, 0.12), "roof_slab", seg=1.6)
    z = top - FLOOR
    while z > bottom + 0.5:
        mb.box((0, 0, z), (w + 0.16, d + 0.16, 0.22), "trim", seg=3.0)
        z -= FLOOR

    # parapet + cap
    t = PARAPET_T
    for cx, cy, sx, sy in [(0, d / 2 - t / 2, w, t), (0, -d / 2 + t / 2, w, t),
                           (w / 2 - t / 2, 0, t, d - 2 * t), (-w / 2 + t / 2, 0, t, d - 2 * t)]:
        mb.box((cx, cy, top + PARAPET_H / 2), (sx, sy, PARAPET_H), wall, seg=1.6)
        mb.box((cx, cy, top + PARAPET_H + 0.05), (sx + 0.12, sy + 0.12, 0.1), "trim", seg=3.0)

    # windows on every floor, including the flooded one
    z = top - FLOOR / 2
    while z > -FLOOR:
        n = int((w - 1.5) // 2.4)
        for i in range(n):
            x = -(n - 1) * 1.2 + i * 2.4
            window(mb, x, -d / 2, z, "y", -1, lit)
            window(mb, x, d / 2, z, "y", 1, lit)
        n = int((d - 1.5) // 2.4)
        for i in range(n):
            y = -(n - 1) * 1.2 + i * 2.4
            window(mb, w / 2, y, z, "x", 1, lit)
            window(mb, -w / 2, y, z, "x", -1, lit)
        z -= FLOOR

    if hut:
        # roof access hut in the -x/+y corner (Godot: -x/-z), footprint 3.0 x 2.6
        hx, hy = -w / 2 + PARAPET_T + 1.7, d / 2 - PARAPET_T - 1.5
        mb.box((hx, hy, top + 1.35), (3.0, 2.6, 2.7), wall, seg=1.0)
        mb.box((hx, hy, top + 2.75), (3.3, 2.9, 0.14), "trim")
        mb.box((hx + 1.52, hy - 0.3, top + 1.05), (0.06, 1.0, 2.1), "door")

    obj = mb.to_object(name)
    K.bake_vertex_ao(obj, distance=1.6, samples=48)
    return K.export_glb(obj, out_dir, name)


if __name__ == "__main__":
    a = K.args()
    out = a[0] if a else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")
    only = set(a[1:])
    for spec in BUILDINGS:
        if not only or spec[0] in only:
            build(*spec, out_dir=out)
