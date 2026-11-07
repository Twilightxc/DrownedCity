"""Style 1.5 rooftop base rooms (1.7) -> assets/models/room_*.glb + data/base/room_kit.json

usage: blender -b --factory-startup --python tools/blender/kit_base.py -- [out_dir] [json_path]

The demo's "survival set" (data/sim/rooms.json), two tiers each, built from scavenged stuff: tarps, crates, pallets,
barrels, planks. Large rooms fill a 6 x 4.5 m slot, small ones 3 x 3 m. Origin = the slot's centre on the roof
(z = 0). Nothing tall covers the middle of a room, so the isometric camera always sees the people in it.
Construction sites (site_large / site_small) stand in an empty slot while it is built; site_pile sits in a corner
while a room is upgraded.

Every room also writes its spots to room_kit.json, in Godot's space (x, y up, z = -Blender y), relative to the
slot centre: where people lie (beds), work, sit (seats) and stand guard, with the clip they play there
(kit_survivor.py's daily-life clips) and the way they face (yaw, Godot: 0 = +Z). `solids` are the footprints
people walk around ([centre x, centre z, size x, size z]).
"""
import json
import math
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_common as K  # noqa: E402

K.PALETTE.update({
    "soil": "#5b4636", "soil_dark": "#47372b", "leaf": "#6f8f3a", "leaf_dark": "#55722c", "tomato": "#b8452f",
    "bedroll": "#7a6a4a", "blanket": "#8a5a4a", "blanket_b": "#5a6a74", "pillow": "#d6cbb2", "cloth": "#d9d2c0",
    "sheet": "#e4e0d4", "red_cross": "#a83a32", "plastic": "#b9c6c1", "stone": "#8a8580", "stone_dark": "#6d6964",
    "ash": "#3a3634", "pot": "#3e4144", "plank": "#8f6a46", "plank_dark": "#6b4e34", "plank_pale": "#a98a64",
    "crate_olive": "#86934f", "rope": "#9a8660", "brick_stove": "#9a5a44", "pipe": "#5f6467", "canvas": "#a3987a", "tarp_light": "#7f97a0",
})
K.FRESH.update({"leaf", "leaf_dark", "tomato"})

LARGE = (6.0, 4.5)
SMALL = (3.0, 3.0)


class Spots:
    """Spots and solids in Blender coordinates (x, y, z up; a facing is a Blender direction), written to Godot."""

    def __init__(self):
        self.d = {"beds": [], "work": [], "seats": [], "guards": [], "solids": []}

    def _spot(self, kind, x, y, z, face, clip):
        yaw = math.atan2(face[0], -face[1])  # Godot yaw: facing (sin, cos) on (x, z); Blender (fx, fy) -> (fx, -fy)
        self.d[kind].append([round(x, 3), round(z, 3), round(-y, 3), round(yaw, 4), clip])

    def bed(self, x, y, h, face=(0, -1)):
        """The pelvis of someone lying on their back; the feet toward `face`."""
        self._spot("beds", x, y, h, face, "sleep")

    def work(self, x, y, face, clip, z=0.0):
        self._spot("work", x, y, z, face, clip)

    def seat(self, x, y, face):
        self._spot("seats", x, y, 0.0, face, "sit")

    def guard(self, x, y, face, z=0.0):
        self._spot("guards", x, y, z, face, "watch")

    def solid(self, cx, cy, sx, sy):
        self.d["solids"].append([round(cx, 3), round(-cy, 3), round(sx, 3), round(sy, 3)])


# ---- pieces --------------------------------------------------------------------------------------

def crate(mb, x, y, s=(0.6, 0.45, 0.45), col="board", yaw=0.0, z=0.0):
    mb.box((x, y, z + s[2] / 2), s, col, yaw=yaw)
    mb.box((x, y, z + s[2] - 0.02), (s[0] + 0.02, s[1] + 0.02, 0.04), "board_dark", yaw=yaw)


def barrel(mb, x, y, col="barrel_blue", h=0.9, r=0.3, z=0.0):
    mb.cylinder((x, y, z + h / 2), r, h, col, segments=12)
    mb.cylinder((x, y, z + h * 0.25), r + 0.01, 0.04, "rust", segments=12)
    mb.cylinder((x, y, z + h * 0.75), r + 0.01, 0.04, "rust", segments=12)


def pole(mb, x, y, h, col="wood", r=0.04, z=0.0):
    mb.cylinder((x, y, z + h / 2), r, h, col, segments=6)


def bedroll(mb, x, y, col="blanket"):
    mb.box((x, y, 0.03), (0.72, 1.9, 0.06), "bedroll")
    mb.box((x, y - 0.15, 0.08), (0.68, 1.3, 0.05), col)
    mb.box((x, y + 0.75, 0.09), (0.5, 0.28, 0.1), "pillow")


def cot(mb, x, y, col="blanket", sheet=False):
    for lx in (-0.33, 0.33):
        for ly in (-0.85, 0.85):
            mb.box((x + lx, y + ly, 0.2), (0.05, 0.05, 0.4), "metal")
        mb.box((x + lx, y, 0.4), (0.05, 1.85, 0.05), "metal")
    mb.box((x, y, 0.41), (0.66, 1.8, 0.03), "tarp")
    mb.box((x, y - 0.15, 0.44), (0.64, 1.25, 0.04), "sheet" if sheet else col)
    mb.box((x, y + 0.7, 0.47), (0.48, 0.28, 0.08), "pillow")


def head_tarp(mb, x, y, col="tarp"):
    """A low A-frame over the head end of a bedroll: reads as a tent, keeps the sleeper in view."""
    for side in (-1, 1):  # two sloped sheets meeting at the ridge (0.72 m)
        with mb.transform((x + side * 0.25, y, 0.36), (0, -side * 0.6, 0)):
            mb.box((0, 0, 0), (0.03, 0.95, 0.86), col)
    pole(mb, x, y - 0.42, 0.72, r=0.025)
    pole(mb, x, y + 0.42, 0.72, r=0.025)
    mb.box((x, y, 0.71), (0.04, 0.9, 0.04), "rope")


def planter(mb, x, y, sx, sy, tall=False):
    mb.box((x, y, 0.2), (sx, sy, 0.4), "plank_dark")
    mb.box((x, y, 0.41), (sx - 0.1, sy - 0.1, 0.04), "soil")
    rows = 2
    n = int(sy / 0.42)
    for r in range(rows):
        px = x - sx / 4 + r * sx / 2
        for i in range(n):
            py = y - sy / 2 + 0.25 + i * (sy - 0.5) / max(1, n - 1)
            h = random.uniform(0.18, 0.3) * (2.2 if tall else 1.0)
            mb.cylinder((px, py, 0.43 + h / 2), random.uniform(0.09, 0.13), h,
                        "leaf" if (i + r) % 3 else "leaf_dark", segments=5, radius_top=0.03)
            if tall:
                pole(mb, px + 0.08, py, 0.9, r=0.012, z=0.43)
                if i % 2 == 0:
                    mb.box((px, py - 0.08, 0.43 + h * 0.6), (0.06, 0.06, 0.06), "tomato")


def sandbag_row(mb, x0, y0, x1, y1, rows=5):
    length = math.hypot(x1 - x0, y1 - y0)
    yaw = math.atan2(y1 - y0, x1 - x0)
    n = max(1, round(length / 0.6))
    for row in range(rows):
        for i in range(n):
            u = (i + 0.5 + (0.25 if row % 2 else 0.0)) / n
            if u > 1.0:
                continue
            col = "sand" if (i + row) % 2 == 0 else "sand_dark"
            mb.box((x0 + (x1 - x0) * u, y0 + (y1 - y0) * u, 0.1 + row * 0.2), (length / n * 0.98, 0.34, 0.2), col,
                   yaw=yaw + random.uniform(-0.06, 0.06))


def table(mb, x, y, sx=1.0, sy=0.6, h=0.8):
    for lx in (-sx / 2 + 0.06, sx / 2 - 0.06):
        for ly in (-sy / 2 + 0.06, sy / 2 - 0.06):
            mb.box((x + lx, y + ly, h / 2), (0.06, 0.06, h), "plank_dark")
    mb.box((x, y, h), (sx, sy, 0.05), "plank")


def med_box(mb, x, y, z):
    mb.box((x, y, z + 0.1), (0.36, 0.24, 0.2), "sheet")
    mb.box((x, y - 0.121, z + 0.1), (0.14, 0.01, 0.04), "red_cross")
    mb.box((x, y - 0.121, z + 0.1), (0.04, 0.01, 0.14), "red_cross")


def curtain(mb, x0, y0, x1, y1, h=1.8, col="sheet"):
    pole(mb, x0, y0, h + 0.1)
    pole(mb, x1, y1, h + 0.1)
    length = math.hypot(x1 - x0, y1 - y0)
    yaw = math.atan2(y1 - y0, x1 - x0)
    n = max(2, int(length / 0.35))
    for i in range(n):
        u = (i + 0.5) / n
        mb.box((x0 + (x1 - x0) * u, y0 + (y1 - y0) * u + (0.03 if i % 2 else -0.03), 0.25 + (h - 0.25) / 2),
               (length / n, 0.03, h - 0.25), col, yaw=yaw)
    mb.box(((x0 + x1) / 2, (y0 + y1) / 2, h), (length, 0.03, 0.03), "metal", yaw=yaw)


def plank_pile(mb, x, y, n=6, length=2.0):
    for i in range(n):
        mb.box((x + random.uniform(-0.05, 0.05), y + (i % 3) * 0.22 - 0.22, 0.04 + (i // 3) * 0.06),
               (length, 0.2, 0.05), random.choice(("plank", "plank_pale", "plank_dark")), yaw=random.uniform(-0.04, 0.04))


def sawhorse(mb, x, y, yaw=0.0):
    with mb.transform((x, y, 0.0), (0, 0, yaw)):
        mb.box((0, 0, 0.62), (1.0, 0.1, 0.08), "plank")
        for lx in (-0.4, 0.4):
            for side in (-1, 1):
                with mb.transform((lx, side * 0.12, 0.3), (side * 0.3, 0, 0)):
                    mb.box((0, 0, 0), (0.06, 0.06, 0.64), "plank_dark")


def log_seat(mb, x, y, yaw=0.0):
    with mb.transform((x, y, 0.22), (0, math.pi / 2, yaw)):
        mb.cylinder((0, 0, 0), 0.2, 0.8, "bark", segments=8)


# ---- rooms ---------------------------------------------------------------------------------------

def sleeping_1(mb, s):
    """Tents: four bedrolls in a row, a low A-frame over each head end; packs and a crate."""
    cols = ("blanket", "blanket_b", "bedroll", "blanket")
    for i, x in enumerate((-2.25, -0.75, 0.75, 2.25)):
        bedroll(mb, x, 0.2, cols[i])
        head_tarp(mb, x, 0.78, "canvas" if i % 2 == 0 else "tarp_light")
        s.bed(x, 0.12, 0.06)
    s.solid(0.0, 0.2, 5.3, 1.95)
    crate(mb, -2.6, -1.6, (0.5, 0.4, 0.4), "crate_olive")
    mb.box((1.5, -1.5, 0.15), (0.35, 0.25, 0.3), "surv_pack" if "surv_pack" in K.PALETTE else "board_dark")


def sleeping_2(mb, s):
    """Cots: six camp beds in a row, blankets hung on a line behind for privacy, crates at the ends."""
    cols = ("blanket", "blanket_b", "blanket", "bedroll", "blanket_b", "blanket")
    for i, x in enumerate((-2.5, -1.5, -0.5, 0.5, 1.5, 2.5)):
        cot(mb, x, 0.25, cols[i])
        s.bed(x, 0.15, 0.45)
    s.solid(0.0, 0.25, 5.8, 1.95)
    curtain(mb, -2.9, 1.65, 2.9, 1.65, 1.7, "blanket_b")
    crate(mb, -2.6, -1.55, (0.5, 0.4, 0.45), "crate_olive")
    crate(mb, 2.6, -1.55, (0.5, 0.4, 0.45))


def _farm_beds(mb, s, tall):
    for x in (-2.0, 0.0, 2.0):
        planter(mb, x, 0.25, 0.9, 3.2, tall)
        s.solid(x, 0.25, 0.95, 3.25)
    s.work(-1.0, 0.9, (-1, 0), "work_kneel")
    s.work(1.0, -0.4, (1, 0), "work_kneel")
    s.work(-1.0, -0.7, (1, 0), "work_kneel")
    s.work(1.0, 1.0, (-1, 0), "work_kneel")
    mb.box((2.7, -1.75, 0.15), (0.3, 0.3, 0.3), "metal")  # bucket
    with mb.transform((-2.75, -1.6, 0.6), (0.25, 0, 0)):
        mb.box((0, 0, 0), (0.04, 0.04, 1.2), "wood")      # hoe
        mb.box((0, -0.05, -0.58), (0.2, 0.12, 0.03), "metal")


def farm_1(mb, s):
    """Soil beds: three raised planters of pallet wood with rows of seedlings; bucket and hoe."""
    _farm_beds(mb, s, False)


def farm_2(mb, s):
    """Greenhouse: taller staked crops, a frame of hoops (no roof panels, so the camera sees in), plastic on the back,
    a rain barrel."""
    _farm_beds(mb, s, True)
    for x in (-2.9, -1.0, 1.0, 2.9):
        pole(mb, x, -2.05, 2.3, "metal", 0.03)
        pole(mb, x, 2.05, 2.3, "metal", 0.03)
        mb.box((x, 0, 2.3), (0.05, 4.1, 0.05), "metal")
    mb.box((0, -2.05, 2.3), (5.8, 0.05, 0.05), "metal")
    mb.box((0, 2.05, 2.3), (5.8, 0.05, 0.05), "metal")
    for i in range(5):
        mb.box((-2.32 + i * 1.16, 2.08, 1.15), (1.1, 0.02, 2.2), "plastic")
    barrel(mb, 2.6, 1.75, "barrel_blue", 0.8, 0.25)


def infirmary_1(mb, s):
    """Sick bay: two cots behind a sheet screen, a crate table with a first-aid box, an IV pole."""
    for x in (-2.2, -1.0):
        cot(mb, x, 0.35, sheet=True)
        s.bed(x, 0.25, 0.45)
    s.solid(-1.6, 0.35, 2.0, 1.95)
    curtain(mb, -2.9, 1.7, 0.2, 1.7, 1.7)
    pole(mb, -0.4, 1.0, 1.8, "metal", 0.02)
    mb.box((-0.4, 1.0, 1.75), (0.12, 0.06, 0.18), "plastic")
    crate(mb, 1.6, 0.6, (0.9, 0.55, 0.7))
    med_box(mb, 1.45, 0.6, 0.7)
    mb.box((1.85, 0.6, 0.78), (0.1, 0.1, 0.16), "glass_bottle" if "glass_bottle" in K.PALETTE else "plastic")
    s.solid(1.6, 0.6, 0.95, 0.6)
    s.work(1.6, -0.15, (0, 1), "work_stand")
    s.work(-1.6, -0.95, (0, 1), "work_stand")


def infirmary_2(mb, s):
    """Clinic: three made beds, curtains on two sides, a metal cabinet and a treatment table."""
    for x in (-2.3, -1.2, -0.1):
        cot(mb, x, 0.3, sheet=True)
        s.bed(x, 0.2, 0.45)
    s.solid(-1.2, 0.3, 3.1, 1.95)
    curtain(mb, -2.9, 1.7, 0.6, 1.7, 1.9)
    curtain(mb, 0.6, 1.7, 0.6, -0.9, 1.9)
    for x in (-1.75, -0.65):
        pole(mb, x, 1.25, 1.8, "metal", 0.02)
        mb.box((x, 1.25, 1.75), (0.12, 0.06, 0.18), "plastic")
    mb.box((2.35, 1.65, 0.9), (0.9, 0.5, 1.8), "metal_paint")
    mb.box((2.35, 1.39, 0.9), (0.02, 0.02, 1.6), "metal")
    table(mb, 1.7, 0.2, 1.0, 0.6, 0.85)
    med_box(mb, 1.5, 0.2, 0.85)
    mb.box((1.95, 0.2, 0.93), (0.12, 0.12, 0.16), "plastic")
    s.solid(2.35, 1.65, 0.95, 0.55)
    s.solid(1.7, 0.2, 1.05, 0.65)
    s.work(1.7, -0.55, (0, 1), "work_stand")
    s.work(-1.2, -1.0, (0, 1), "work_stand")


def water_1(mb, s):
    """Rain barrels: three barrels under a tarp funnel on four poles."""
    for i, x in enumerate((-0.8, 0.0, 0.8)):
        barrel(mb, x, 0.8, ("barrel_blue", "barrel_red", "barrel_blue")[i])
    s.solid(0.0, 0.8, 2.3, 0.7)
    for x in (-1.25, 1.25):
        pole(mb, x, 1.25, 1.9)
        pole(mb, x, 0.25, 1.6)
    with mb.transform((0, 0.75, 1.75), (0.3, 0, 0)):
        mb.box((0, 0, 0), (2.5, 1.05, 0.03), "tarp")
    s.work(0.0, 0.0, (0, 1), "work_stand")


def water_2(mb, s):
    """Filter: a tank on a stand fed by a hand pump line, a sand-filter barrel, buckets."""
    for lx in (-0.95, -0.25):
        for ly in (0.4, 1.1):
            mb.box((lx, ly, 0.4), (0.07, 0.07, 0.8), "plank_dark")
    mb.box((-0.6, 0.75, 0.82), (0.85, 0.85, 0.05), "plank")
    mb.cylinder((-0.6, 0.75, 1.35), 0.42, 1.0, "tank", segments=14)
    barrel(mb, 0.65, 0.85, "barrel_red", 0.95, 0.3)
    mb.box((0.0, 0.8, 1.0), (1.3, 0.06, 0.06), "pipe")
    mb.box((0.65, 0.85, 1.0), (0.06, 0.06, 0.15), "pipe")
    mb.box((-0.6, 0.3, 0.55), (0.06, 0.06, 0.5), "pipe")
    for i, x in enumerate((1.1, 1.2)):
        mb.cylinder((x, -0.5 + i * 0.3, 0.15), 0.15, 0.3, "metal", segments=10, radius_top=0.17)
    s.solid(0.0, 0.8, 2.3, 0.85)
    s.work(0.1, 0.05, (0, 1), "work_stand")


def kitchen_1(mb, s):
    """Campfire: a stone ring with embers, a pot on a tripod, three logs to sit on."""
    for k in range(9):
        a = k / 9 * math.tau
        mb.box((0.45 * math.cos(a), 0.2 + 0.45 * math.sin(a), 0.08), (0.2, 0.16, 0.16),
               "stone" if k % 2 else "stone_dark", yaw=a)
    mb.box((0, 0.2, 0.03), (0.6, 0.6, 0.04), "ash")
    for k in range(4):  # a teepee of charred sticks over a small glowing core
        with mb.transform((0.0, 0.2, 0.0), (0, 0, k * math.pi / 2 + 0.3)):
            with mb.transform((0.12, 0, 0.15), (0, -0.7, 0)):
                mb.box((0, 0, 0), (0.06, 0.06, 0.36), "bark")
    mb.box((0, 0.2, 0.07), (0.16, 0.16, 0.08), "lit", mat=1)
    for k in range(3):
        a = k / 3 * math.tau + 0.4
        with mb.transform((0.0, 0.2, 0.0), (0, 0, a)):
            with mb.transform((0.42, 0, 0.55), (0, -0.62, 0)):
                mb.box((0, 0, 0), (0.04, 0.04, 1.25), "wood")
    mb.cylinder((0, 0.2, 0.62), 0.17, 0.22, "pot", segments=10)
    log_seat(mb, -1.0, 0.2, math.pi / 2)
    log_seat(mb, 1.0, 0.2, math.pi / 2)
    log_seat(mb, 0.0, 1.15, 0.0)
    s.seat(-1.0, 0.2, (1, 0))
    s.seat(1.0, 0.2, (-1, 0))
    s.seat(0.0, 1.15, (0, -1))
    s.solid(0.0, 0.2, 1.1, 1.1)
    s.work(0.0, -0.65, (0, 1), "work_stand")


def kitchen_2(mb, s):
    """Stove: a brick stove with a chimney pipe and a pot, a table with crates to sit on."""
    mb.box((0.2, 1.0, 0.45), (1.1, 0.7, 0.9), "brick_stove")
    mb.box((0.2, 0.64, 0.3), (0.4, 0.03, 0.25), "lit", mat=1)
    mb.box((0.2, 1.0, 0.92), (1.15, 0.75, 0.05), "metal")
    mb.cylinder((0.6, 1.2, 1.7), 0.08, 1.6, "pipe", segments=8)
    mb.cylinder((0.05, 0.95, 1.05), 0.17, 0.22, "pot", segments=10)
    s.solid(0.2, 1.0, 1.15, 0.75)
    s.work(0.2, 0.25, (0, 1), "work_stand")
    table(mb, -0.75, -0.5, 0.8, 0.6, 0.72)
    crate(mb, -0.75, -1.15, (0.45, 0.4, 0.45))
    crate(mb, 0.1, -0.5, (0.4, 0.45, 0.45))
    s.solid(-0.75, -0.5, 0.85, 0.65)
    s.seat(-0.75, -1.15, (0, 1))
    s.seat(0.1, -0.5, (-1, 0))
    crate(mb, -1.15, 1.05, (0.5, 0.45, 0.6), "crate_olive")


def watchtower_1(mb, s):
    """Sandbags: a U of sandbags a metre high, open at the back; an ammo crate."""
    sandbag_row(mb, -1.2, -1.15, 1.2, -1.15)
    sandbag_row(mb, -1.25, -1.0, -1.25, 0.7)
    sandbag_row(mb, 1.25, -1.0, 1.25, 0.7)
    s.solid(0.0, -1.15, 2.6, 0.4)
    s.solid(-1.25, -0.15, 0.4, 1.7)
    s.solid(1.25, -0.15, 0.4, 1.7)
    crate(mb, 0.6, 0.5, (0.5, 0.35, 0.3), "crate_olive")
    s.guard(0.0, -0.55, (0, -1))


TOWER_DECK = 2.4


def watchtower_2(mb, s):
    """Wooden tower: four posts, a deck at 2.4 m with a railing and sandbags at the front, a ladder at the back."""
    for x in (-1.0, 1.0):
        for y in (-1.0, 1.0):
            mb.box((x, y, (TOWER_DECK + 1.1) / 2), (0.16, 0.16, TOWER_DECK + 1.1), "wood")
            s.solid(x, y, 0.3, 0.3)
    for k in (-1, 1):  # cross braces
        with mb.transform((0, -1.0, TOWER_DECK / 2), (0, k * 0.85, 0)):
            mb.box((0, 0, 0), (0.06, 0.06, 2.9), "plank_dark")
        with mb.transform((k * 1.0, 0, TOWER_DECK / 2), (k * 0.85, 0, 0)):
            mb.box((0, 0, 0), (0.06, 0.06, 2.9), "plank_dark")
    for i in range(6):
        mb.box((0, -1.05 + i * 0.42, TOWER_DECK), (2.3, 0.4, 0.08), "plank" if i % 2 else "plank_pale")
    for y in (-1.15, 1.15):
        mb.box((0, y, TOWER_DECK + 1.0), (2.3, 0.06, 0.06), "plank_dark")
    for x in (-1.15, 1.15):
        mb.box((x, 0, TOWER_DECK + 1.0), (0.06, 2.3, 0.06), "plank_dark")
    for i in range(4):  # sandbags along the front edge
        mb.box((-0.84 + i * 0.56, -1.0, TOWER_DECK + 0.14), (0.54, 0.3, 0.2), "sand" if i % 2 else "sand_dark")
    for lx in (-0.22, 0.22):
        mb.box((lx, 1.25, TOWER_DECK / 2), (0.05, 0.05, TOWER_DECK + 0.4), "wood")
    for k in range(7):
        mb.box((0, 1.25, 0.3 + k * 0.33), (0.44, 0.04, 0.04), "wood")
    s.guard(-0.5, -0.55, (0, -1), TOWER_DECK + 0.04)
    s.guard(0.5, -0.55, (0, -1), TOWER_DECK + 0.04)


def _site(mb, s, sx, sy):
    for x in (-sx / 2 + 0.1, sx / 2 - 0.1):
        for y in (-sy / 2 + 0.1, sy / 2 - 0.1):
            pole(mb, x, y, 0.5, "plank_pale", 0.03)
    for (x0, y0, x1, y1) in ((-1, -1, 1, -1), (-1, 1, 1, 1), (-1, -1, -1, 1), (1, -1, 1, 1)):
        a, b = (x0 * (sx / 2 - 0.1), y0 * (sy / 2 - 0.1)), (x1 * (sx / 2 - 0.1), y1 * (sy / 2 - 0.1))
        ln = math.hypot(b[0] - a[0], b[1] - a[1])
        mb.box(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 0.42), (ln, 0.012, 0.012), "rope",
               yaw=math.atan2(b[1] - a[1], b[0] - a[0]))


def site_large(mb, s):
    """Building a large room: stakes and string round the slot, a plank pile, a sawhorse, cut beams laid out."""
    _site(mb, s, *LARGE)
    plank_pile(mb, -1.6, 0.9, 9, 2.2)
    sawhorse(mb, 1.4, 0.8)
    for i in range(3):
        mb.box((0.2 + i * 0.5, -0.9, 0.06), (0.12, 1.6, 0.12), "plank_dark", yaw=0.05 * i)
    s.solid(-1.6, 0.9, 2.3, 0.75)
    s.solid(1.4, 0.8, 1.1, 0.4)
    s.work(1.4, 0.2, (0, 1), "work_stand")
    s.work(0.7, -0.9, (1, 0), "work_kneel")
    s.work(-1.6, 0.1, (0, 1), "work_kneel")


def site_small(mb, s):
    _site(mb, s, *SMALL)
    plank_pile(mb, -0.2, 0.6, 6, 1.6)
    sawhorse(mb, 0.5, -0.6, math.pi / 2)
    s.solid(-0.2, 0.6, 1.7, 0.75)
    s.work(0.0, -0.6, (1, 0), "work_stand")
    s.work(-0.6, -0.3, (0, 1), "work_kneel")


def site_pile(mb, s):
    """A room being upgraded: a small plank pile and a sawhorse, placed in a front corner by the game."""
    plank_pile(mb, 0.0, 0.15, 5, 1.4)
    s.work(0.0, -0.45, (0, 1), "work_kneel")


def crate_seat(mb, s):
    """A crate on the bare roof to sit and read on."""
    crate(mb, 0.0, 0.0, (0.5, 0.45, 0.45))
    s.seat(0.0, 0.0, (0, -1))


# name, builder, AO distance, aging
ROOMS = [
    ("sleeping_1", sleeping_1), ("sleeping_2", sleeping_2), ("farm_1", farm_1), ("farm_2", farm_2),
    ("infirmary_1", infirmary_1), ("infirmary_2", infirmary_2), ("water_1", water_1), ("water_2", water_2),
    ("kitchen_1", kitchen_1), ("kitchen_2", kitchen_2), ("watchtower_1", watchtower_1),
    ("watchtower_2", watchtower_2), ("site_large", site_large), ("site_small", site_small),
    ("site_pile", site_pile), ("crate_seat", crate_seat),
]


if __name__ == "__main__":
    a = K.args()
    here = os.path.dirname(os.path.abspath(__file__))
    out = a[0] if a else os.path.join(here, "..", "..", "assets", "models")
    json_path = a[1] if len(a) > 1 else os.path.join(here, "..", "..", "data", "base", "room_kit.json")
    kit = {"_doc": "Written by tools/blender/kit_base.py: don't edit by hand. Spots are [x, y, z, yaw, clip] in Godot "
                   "space relative to the slot centre; solids are [x, z, size x, size z].", "rooms": {}}
    for name, fn in ROOMS:
        K.reset(31)
        random.seed(name)
        mb = K.MeshBuilder(aging=0.35)
        spots = Spots()
        fn(mb, spots)
        obj = mb.to_object("room_" + name)
        K.bake_vertex_ao(obj, distance=0.5, samples=32)
        K.export_glb(obj, out, "room_" + name)
        kit["rooms"][name] = {"model": "res://assets/models/room_%s.glb" % name, **spots.d}
    os.makedirs(os.path.dirname(json_path), exist_ok=True)
    with open(json_path, "w", encoding="utf-8", newline="\n") as f:
        text = json.dumps(kit, indent="\t")
        # one line per spot / solid: [x, y, z, yaw, clip]
        text = re.sub(r"\[\s+([^\[\]{}]*?)\s+\]", lambda m: "[" + re.sub(r"\s*\n\s*", " ", m.group(1)) + "]", text)
        f.write(text + "\n")
    print("wrote", json_path)
