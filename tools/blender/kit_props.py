"""Style 1.5 rooftop props -> assets/models/prop_*.glb

usage: blender -b --factory-startup --python tools/blender/kit_props.py -- [out_dir]

Origin = centre of the footprint on the roof surface (z = 0).
Footprints (for nav-grid obstacles): water tower 3.4 x 3.4, AC unit 1.3 x 1.0, sandbag wall 3.2 x 0.7.
Every footprint also blocks hitscan, so each prop reaches at least the 0.9 m muzzle height.

Arena props (J 2026-11-04, replacing the spike's boxes): the supply crate (0.9 x 0.6 footprint, an ammo can on
top), barricade pieces for one 1 x 1 m cell in three damage stages (planks nailed across two posts, or an upright
pallet; stage 0 whole, 1 battered, 2 nearly gone; the boards run along X, the game turns them), and the two
throwables: a frag grenade and a Molotov bottle whose rag burns (emissive slot), both built at real size.
Melee weapons (J bug list 2026-11-05): a combat knife and a red fire axe, real size, origin at the right hand's grip.

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

K.PALETTE.update({
    "crate_olive": "#86934f", "crate_olive_dark": "#6c7a40", "crate_stencil": "#e2d9b0", "ammo_can": "#5d6b3c",
    "rope": "#9a8660", "plank": "#8f6a46", "plank_dark": "#6b4e34", "plank_pale": "#a98a64", "nail": "#4a4a4a",
    "frag_body": "#4b5532", "frag_metal": "#8d9296", "glass_bottle": "#5c7148", "rag": "#d8ccb0",
    "knife_grip": "#2b2a27", "knife_steel": "#9aa3a8", "knife_steel_dark": "#53595d", "knife_edge": "#d6dde0",
    "axe_haft": "#a8743e", "axe_head": "#b3302a", "axe_edge": "#c9cfd2",
})


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


def supply_crate(mb):
    mb.box((0, 0, 0.24), (0.9, 0.6, 0.48), "crate_olive", seg=0.3)
    mb.box((0, 0, 0.5), (0.94, 0.64, 0.05), "crate_olive_dark")           # lid
    for x in (-0.3, 0.3):
        mb.box((x, 0, 0.25), (0.06, 0.62, 0.5), "crate_olive_dark")       # battens
    mb.box((0, -0.302, 0.25), (0.34, 0.01, 0.14), "crate_stencil")        # stencilled marking
    mb.box((0.46, 0, 0.32), (0.03, 0.18, 0.04), "rope")                  # rope handles
    mb.box((-0.46, 0, 0.32), (0.03, 0.18, 0.04), "rope")
    mb.box((0.12, 0.05, 0.64), (0.3, 0.16, 0.22), "ammo_can")             # ammo can on top
    mb.box((0.12, 0.05, 0.76), (0.16, 0.04, 0.02), "frag_metal")          # its handle
    mb.box((-0.24, -0.08, 0.58), (0.18, 0.14, 0.1), "rag")                # a bundle of dressings


def _planks(mb, stage):
    """Two posts and planks nailed across (the boards run along X)."""
    for x in (-0.42, 0.42):
        h = 1.05 if stage < 2 else 0.7
        mb.box((x, 0.0, h / 2), (0.09, 0.09, h), "plank_dark")
    boards = [(0.2, 0.0), (0.42, 0.05), (0.64, -0.04), (0.86, 0.03)]
    keep = [0, 1, 2, 3] if stage == 0 else [0, 2] if stage == 1 else [0]
    for i in keep:
        z, tilt = boards[i]
        with mb.transform((0, -0.06, z), (0.0, tilt + (0.25 if stage == 1 and i == 2 else 0.0), 0.0)):
            mb.box((0, 0, 0), (1.0, 0.04, 0.17), "plank" if i % 2 == 0 else "plank_pale")
    if stage == 1:  # one board hangs off a single nail
        with mb.transform((0.3, -0.07, 0.5), (0.0, 1.1, 0.0)):
            mb.box((0, 0, 0), (0.7, 0.04, 0.16), "plank")
    for z, _ in [boards[i] for i in keep]:
        for x in (-0.42, 0.42):
            mb.box((x, -0.085, z), (0.02, 0.01, 0.02), "nail")


def _pallet(mb, stage):
    """A pallet stood on edge with a board across it, propped by a beam."""
    tilt = 0.0 if stage == 0 else 0.12 if stage == 1 else 0.5
    with mb.transform((0, 0, 0.0), (tilt, 0.0, 0.0)):
        for z in (0.06, 0.5, 0.94):
            if stage == 2 and z > 0.9:
                continue
            mb.box((0, 0.0, z), (1.0, 0.12, 0.09), "plank_dark")                 # stringers
        slats = [-0.4, -0.2, 0.0, 0.2, 0.4] if stage == 0 else [-0.4, 0.0, 0.4] if stage == 1 else [-0.2]
        for x in slats:
            mb.box((x, -0.07, 0.5), (0.12, 0.02, 1.0 if stage < 2 else 0.7), "plank_pale")
    mb.box((0, 0.3, 0.3), (0.08, 0.6, 0.08), "plank")                      # the prop behind it


def barricade_planks_0(mb): _planks(mb, 0)
def barricade_planks_1(mb): _planks(mb, 1)
def barricade_planks_2(mb): _planks(mb, 2)
def barricade_pallet_0(mb): _pallet(mb, 0)
def barricade_pallet_1(mb): _pallet(mb, 1)
def barricade_pallet_2(mb): _pallet(mb, 2)


def grenade_frag(mb):
    """Real size (about 9 cm tall); the game scales throwables up to read in flight."""
    mb.cylinder((0, 0, 0.04), 0.03, 0.07, "frag_body", segments=10, radius_top=0.026)
    mb.cylinder((0, 0, 0.083), 0.012, 0.016, "frag_metal", segments=8)       # fuse
    mb.box((0.018, 0, 0.065), (0.008, 0.012, 0.05), "frag_metal")           # spoon
    mb.box((-0.016, 0, 0.088), (0.012, 0.004, 0.012), "frag_metal")         # pin ring


def molotov(mb):
    """A bottle with a rag stuffed in the neck; the rag's tip burns (emissive)."""
    mb.cylinder((0, 0, 0.08), 0.035, 0.16, "glass_bottle", segments=10)
    mb.cylinder((0, 0, 0.19), 0.014, 0.06, "glass_bottle", segments=8, radius_top=0.012)  # neck
    mb.box((0, 0, 0.235), (0.03, 0.03, 0.04), "rag")
    mb.box((0.004, 0, 0.265), (0.026, 0.026, 0.025), "lit", mat=1)          # burning rag


def melee_knife(mb):
    """Combat knife, real size (30 cm). Origin = the grip centre; the blade points +Z, its edge -Y."""
    mb.cylinder((0, 0, 0.0), 0.017, 0.12, "knife_grip", segments=8)
    mb.box((0, 0, 0.065), (0.016, 0.07, 0.012), "knife_steel_dark")          # guard
    mb.box((0, -0.002, 0.145), (0.005, 0.032, 0.15), "knife_steel")
    mb.box((0, 0.006, 0.232), (0.005, 0.018, 0.03), "knife_steel")           # clipped point
    mb.box((0, -0.017, 0.14), (0.006, 0.004, 0.13), "knife_edge")            # bright edge
    mb.cylinder((0, 0, -0.065), 0.019, 0.012, "knife_steel_dark", segments=8)  # pommel


def melee_axe(mb):
    """Fire axe, real size (80 cm). Origin = where the right hand holds, near the end of the haft; the haft runs +Z,
    the blade faces -Y (the swing's front), a pick on the back."""
    mb.cylinder((0, 0, 0.27), 0.019, 0.74, "axe_haft", segments=8)
    mb.box((0, 0, 0.6), (0.04, 0.06, 0.1), "axe_head")                       # eye
    mb.box((0, -0.09, 0.6), (0.028, 0.13, 0.12), "axe_head")                 # cheek
    mb.box((0, -0.165, 0.6), (0.02, 0.04, 0.2), "axe_edge")                  # flared bit
    mb.box((0, 0.08, 0.61), (0.024, 0.11, 0.035), "axe_head")                # pick
    mb.box((0, -0.005, -0.08), (0.042, 0.042, 0.03), "knife_grip")           # knob


# name, builder, AO distance, aging
PROPS = [
    ("prop_water_tower", water_tower, 0.8, 0.5), ("prop_ac_unit", ac_unit, 0.4, 0.5),
    ("prop_sandbag_wall", sandbag_wall, 0.3, 0.3),
    ("prop_flood_debris_a", flood_debris_a, 0.6, 0.7), ("prop_flood_debris_b", flood_debris_b, 0.6, 0.7),
    ("prop_supply_crate", supply_crate, 0.3, 0.3),
    ("prop_barricade_planks_0", barricade_planks_0, 0.25, 0.5), ("prop_barricade_planks_1", barricade_planks_1, 0.25, 0.5),
    ("prop_barricade_planks_2", barricade_planks_2, 0.25, 0.5), ("prop_barricade_pallet_0", barricade_pallet_0, 0.25, 0.5),
    ("prop_barricade_pallet_1", barricade_pallet_1, 0.25, 0.5), ("prop_barricade_pallet_2", barricade_pallet_2, 0.25, 0.5),
    ("prop_grenade_frag", grenade_frag, 0.03, 0.1), ("prop_molotov", molotov, 0.03, 0.1),
    ("prop_melee_knife", melee_knife, 0.02, 0.1), ("prop_melee_axe", melee_axe, 0.03, 0.25),
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
