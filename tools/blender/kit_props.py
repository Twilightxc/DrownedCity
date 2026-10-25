"""Style 1.5 rooftop props -> assets/models/prop_*.glb

usage: blender -b --factory-startup --python tools/blender/kit_props.py -- [out_dir]

Origin = centre of the footprint on the roof surface (z = 0).
Footprints (for nav-grid obstacles): water tower 3.4 x 3.4, AC unit 1.3 x 1.0, sandbag wall 3.2 x 0.7.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_common as K  # noqa: E402


def water_tower(mb):
    for lx, ly in [(-1.2, -1.2), (1.2, -1.2), (-1.2, 1.2), (1.2, 1.2)]:
        mb.box((lx, ly, 1.2), (0.16, 0.16, 2.4), "metal")
    mb.box((0, -1.2, 1.0), (2.4, 0.08, 0.08), "metal")
    mb.box((0, 1.2, 1.0), (2.4, 0.08, 0.08), "metal")
    mb.box((0, 0, 2.45), (2.8, 2.8, 0.12), "metal")
    mb.cylinder((0, 0, 3.7), 1.55, 2.4, "tank", segments=20)
    mb.cylinder((0, 0, 5.25), 1.62, 0.7, "metal_paint", segments=20, radius_top=0.15)
    mb.box((1.7, 0, 2.6), (0.1, 0.1, 5.2), "metal")  # ladder rail


def ac_unit(mb):
    mb.box((0, 0, 0.45), (1.3, 1.0, 0.9), "metal_paint", seg=0.5)
    mb.cylinder((0, 0, 0.92), 0.38, 0.05, "dark", segments=16)
    for i in range(5):
        mb.box((-0.66, -0.3 + i * 0.15, 0.45), (0.02, 0.06, 0.6), "metal")
    mb.box((0, 0, 0.03), (1.4, 1.1, 0.06), "metal")


def sandbag_wall(mb):
    for row in range(2):
        for i in range(5):
            x = -1.28 + i * 0.64 + (0.32 if row else 0.0)
            if x > 1.3:
                continue
            col = "sand" if (i + row) % 2 == 0 else "sand_dark"
            mb.box((x, random.uniform(-0.03, 0.03), 0.1 + row * 0.2), (0.6, 0.34, 0.2), col,
                   yaw=random.uniform(-0.08, 0.08))
    mb.box((0, 0.2, 0.05), (3.2, 0.3, 0.1), "sand_dark")


PROPS = [("prop_water_tower", water_tower, 0.8), ("prop_ac_unit", ac_unit, 0.4), ("prop_sandbag_wall", sandbag_wall, 0.3)]


if __name__ == "__main__":
    a = K.args()
    out = a[0] if a else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")
    for name, fn, ao_dist in PROPS:
        K.reset(11)
        mb = K.MeshBuilder()
        fn(mb)
        obj = mb.to_object(name)
        K.bake_vertex_ao(obj, distance=ao_dist, samples=48)
        K.export_glb(obj, out, name)
