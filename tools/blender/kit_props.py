"""Style 1.5 rooftop props -> assets/models/prop_*.glb

usage: blender -b --factory-startup --python tools/blender/kit_props.py -- [out_dir]

Origin = centre of the footprint on the roof surface (z = 0).
Footprints (for nav-grid obstacles): water tower 3.4 x 3.4, AC unit 1.3 x 1.0, sandbag wall 3.2 x 0.7.
Every footprint also blocks hitscan, so each prop reaches at least the 0.9 m muzzle height.

Flood props (origin = water surface, not nav obstacles): two floating-debris clusters (~18 m across) with a
sunken car, leaning street lamp, dead tree, road sign, planks, barrels and trash, so the empty streets read
under the water.
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


SANDBAG_ROWS = 5  # 5 x 0.2 m = 1.0 m: above the 0.9 m muzzle height, so it visibly blocks shots


def sandbag_wall(mb):
    for row in range(SANDBAG_ROWS):
        for i in range(5):
            x = -1.28 + i * 0.64 + (0.32 if row % 2 else 0.0)
            if x > 1.3:
                continue
            col = "sand" if (i + row) % 2 == 0 else "sand_dark"
            mb.box((x, random.uniform(-0.03, 0.03), 0.1 + row * 0.2), (0.6, 0.34, 0.2), col,
                   yaw=random.uniform(-0.08, 0.08))
    mb.box((0, 0.2, 0.05), (3.2, 0.3, 0.1), "sand_dark")


def street_lamp(mb, x, y, lean, yaw):
    with mb.transform((x, y, 0.0), (lean, 0.0, yaw)):
        mb.cylinder((0, 0, 0.5), 0.09, 7.0, "metal", segments=8)       # base 3 m under water
        mb.box((0.55, 0, 3.95), (1.2, 0.08, 0.08), "metal")
        mb.box((1.1, 0, 3.85), (0.45, 0.25, 0.14), "dark")              # dead lamp head


def dead_tree(mb, x, y, lean):
    with mb.transform((x, y, 0.0), (lean, lean * 0.5, random.uniform(0, math.pi))):
        trunk_base, trunk_h = -2.0, 5.2  # base under water
        mb.cylinder((0, 0, trunk_base + trunk_h / 2), 0.28, trunk_h, "bark", segments=7, radius_top=0.12)
        branches = 6
        z_lo, z_hi = 1.4, trunk_base + trunk_h - 0.15  # every branch starts on the trunk
        for i in range(branches):
            z = z_lo + (z_hi - z_lo) * i / (branches - 1)
            with mb.transform((0, 0, z), (random.uniform(0.6, 1.1), 0.0, i * 2.1 + random.uniform(-0.3, 0.3))):
                ln = random.uniform(0.9, 2.0) * (1.0 - i * 0.1)
                mb.cylinder((0, 0, ln / 2), 0.08, ln, "bark", segments=5, radius_top=0.02)


def sunken_car(mb, x, y, yaw):
    with mb.transform((x, y, 0.0), (0.04, -0.06, yaw)):
        mb.box((0, 0, -0.55), (1.8, 4.2, 0.9), "car")                    # body, mostly under water
        mb.box((0, -0.2, 0.05), (1.6, 2.0, 0.32), "glass_dirty")
        mb.box((0, -0.2, 0.25), (1.55, 1.9, 0.08), "car")                # roof just above the surface
        mb.box((0, 0.55, 0.32), (1.3, 0.08, 0.06), "rust")               # roof rack


def road_sign(mb, x, y, lean):
    with mb.transform((x, y, 0.0), (0.0, lean, random.uniform(0, math.pi))):
        mb.box((0, 0, 0.0), (0.07, 0.07, 5.0), "metal")
        mb.box((0, -0.05, 2.1), (0.9, 0.04, 0.6), "metal_paint")
        mb.box((0, -0.08, 2.1), (0.7, 0.02, 0.12), "rust")


def flotsam(mb, radius, count):
    for _ in range(count):
        a, r = random.uniform(0, math.tau), radius * math.sqrt(random.random())
        x, y = r * math.cos(a), r * math.sin(a)
        kind = random.random()
        with mb.transform((x, y, 0.0), (random.uniform(-0.06, 0.06), random.uniform(-0.06, 0.06), random.uniform(0, math.pi))):
            if kind < 0.4:
                mb.box((0, 0, 0.02), (random.uniform(1.0, 2.8), random.uniform(0.18, 0.3), 0.08),
                       random.choice(("board", "board_dark", "wood")))
            elif kind < 0.55:
                mb.cylinder((0, 0, 0.1), 0.3, 0.9, random.choice(("barrel_red", "barrel_blue", "rust")), segments=10)
            elif kind < 0.65:
                with mb.transform((0, 0, 0.05), (math.pi / 2, 0, 0)):
                    mb.cylinder((0, 0, 0), 0.3, 0.9, random.choice(("barrel_red", "barrel_blue")), segments=10)
            elif kind < 0.75:
                mb.cylinder((0, 0, 0.0), 0.36, 0.22, "tire", segments=10)
            elif kind < 0.88:
                mb.box((0, 0, 0.08), (0.5, 0.45, 0.3), "trash")
            else:
                mb.box((0, 0, 0.1), (0.6, 0.4, 0.3), "styro")


def flood_debris_a(mb):
    sunken_car(mb, -3.0, 1.5, 0.4)
    street_lamp(mb, 4.5, -3.0, 0.22, 2.4)
    road_sign(mb, -6.0, -4.5, -0.3)
    flotsam(mb, 9.0, 26)


def flood_debris_b(mb):
    dead_tree(mb, 2.0, 2.0, 0.12)
    street_lamp(mb, -5.0, 3.5, -0.3, 0.9)
    sunken_car(mb, -1.0, -5.0, 1.9)
    flotsam(mb, 9.0, 22)


# name, builder, AO distance, aging
PROPS = [
    ("prop_water_tower", water_tower, 0.8, 0.5), ("prop_ac_unit", ac_unit, 0.4, 0.5),
    ("prop_sandbag_wall", sandbag_wall, 0.3, 0.3),
    ("prop_flood_debris_a", flood_debris_a, 0.6, 0.7), ("prop_flood_debris_b", flood_debris_b, 0.6, 0.7),
]


if __name__ == "__main__":
    a = K.args()
    out = a[0] if a else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")
    only = set(a[1:])
    for name, fn, ao_dist, aging in PROPS:
        if only and name not in only:
            continue
        K.reset(11)
        mb = K.MeshBuilder(aging=aging)
        fn(mb)
        obj = mb.to_object(name)
        K.bake_vertex_ao(obj, distance=ao_dist, samples=48)
        K.export_glb(obj, out, name)
