"""Style 1.5 flooded, abandoned buildings -> assets/models/building_*.glb

usage: blender -b --factory-startup --python tools/blender/kit_building.py -- [out_dir] [name ...]

Origin = water surface at the building centre. Roof top is at floors * FLOOR - WATERLINE_OFFSET,
so every building shares one water plane in Godot (y = water level) and stacks floors consistently.

`decay` (0..1) drives the abandonment: bleached palette, rain streaks under sills and parapets,
peeling patches, broken / boarded / missing windows, parapet gaps, vines, moss and roof debris.
Optional ruin features: `roof_hole` (caved-in slab) and `collapse` (upper floors of one corner gone).
"""
import math
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
WIN_SPACING = 2.4
WIN_W, WIN_H = 1.3, 1.7
WALL_SEG = 0.8           # weathering resolution on walls (one colour per quad)

BARE = {"plaster": "plaster_bare", "brick": "brick_bare", "concrete": "concrete_stain"}

BUILDINGS = [
    # The survivors' base: weathered but held together; boarded floor above the water, a few lit rooms.
    dict(name="building_base_3f", size=(26.0, 22.0), floors=3, wall="plaster", lit=0.05, hut=True, seed=3,
         decay=0.45, boarded_floor=1),
    dict(name="building_brick_2f", size=(14.0, 12.0), floors=2, wall="brick", lit=0.0, hut=True, seed=5,
         decay=0.85, roof_hole=True),
    # collapse = (corner width x, corner depth y, floors lost) at the +x / +y corner (Godot +x / -z)
    dict(name="building_concrete_5f", size=(12.0, 13.0), floors=5, wall="concrete", lit=0.0, hut=False, seed=7,
         decay=0.9, collapse=(5.5, 6.0, 2)),
]


def roof_height(floors):
    return floors * FLOOR - WATERLINE_OFFSET


def smoothstep(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def window_grid(length):
    n = int((length - 1.5) // WIN_SPACING)
    return [-(n - 1) * WIN_SPACING / 2 + i * WIN_SPACING for i in range(n)]


def window_centres_z(top, z_lo, z_hi):
    zs, z = [], top - FLOOR / 2
    while z > -FLOOR:
        if z_lo + 0.9 < z < z_hi - 0.9:
            zs.append(z)
        z -= FLOOR
    return zs


class Side:
    """One wall face of a block. Local frame: x along the wall, -y = outward normal, z up."""

    def __init__(self, axis, sign, coord, lo, hi):
        self.axis, self.sign, self.coord, self.lo, self.hi = axis, sign, coord, lo, hi
        self.yaw = {("y", -1): 0.0, ("y", 1): math.pi, ("x", 1): math.pi / 2, ("x", -1): -math.pi / 2}[(axis, sign)]

    @property
    def length(self):
        return self.hi - self.lo

    def origin(self, z=0.0):
        mid = (self.lo + self.hi) / 2
        return (mid, self.coord, z) if self.axis == "y" else (self.coord, mid, z)

    def to_local(self, along):
        """World coordinate along the wall -> local x (the frame flips on +y / -x sides)."""
        mid = (self.lo + self.hi) / 2
        flip = -1 if (self.axis, self.sign) in (("y", 1), ("x", -1)) else 1
        return (along - mid) * flip


def make_weathering(spec, top):
    """Per-quad wall colour: rain streaks from parapets and sills, peeling patches, grime toward the top."""
    decay, seed = spec["decay"], spec["seed"]
    bare = K.color(BARE[spec["wall"]])
    win_cols = {"x": window_grid(spec["size"][0]), "y": window_grid(spec["size"][1])}

    def fn(c, n, rgba):
        if abs(n[2]) > 0.5:
            return rgba
        along_axis = "x" if abs(n[1]) > 0.5 else "y"
        s, z = (c[0] if along_axis == "x" else c[1]), c[2]
        side_key = (round(n[0]), round(n[1]))
        k = 1.0
        # parapet / roof run-off: random 0.8 m columns, strongest just under the roof
        col = math.floor(s / WALL_SEG)
        r = K.hash01(col, side_key, seed)
        if r > 1.0 - 0.45 * decay:
            k *= 1.0 - 0.32 * (r - (1.0 - 0.45 * decay)) / (0.45 * decay) * (0.35 + 0.65 * smoothstep(-2.0, top, z))
        # streaks under window sills
        if min(abs(s - w) for w in win_cols[along_axis] or [1e9]) < 0.55:
            rel = ((top - FLOOR / 2 - WIN_H / 2 - 0.15) - z) % FLOOR
            if rel < 1.8:
                k *= 1.0 - 0.3 * decay * (1.0 - rel / 1.8)
        out = (rgba[0] * k, rgba[1] * k, rgba[2] * k, rgba[3])
        # peeling plaster / spalled concrete
        if K.value_noise(s * 0.45 + side_key[0] * 31, z * 0.6 + side_key[1] * 17, seed) > 0.78 - 0.16 * decay:
            out = (bare[0] * k, bare[1] * k, bare[2] * k, rgba[3])
        return out

    return fn


def window(mb, side, along, z, spec, floor_z):
    """Window in the side's local frame. Fate depends on decay: lit / intact / broken / boarded / gone."""
    decay = spec["decay"]
    boarded_here = spec.get("boarded_floor") is not None and 1.5 < floor_z < 5.0
    r = random.random()
    p_lit = spec["lit"]
    p_board = (0.55 if boarded_here else 0.04 + 0.14 * decay)
    p_broken = 0.12 + 0.5 * decay
    p_gone = 0.12 * decay
    with mb.transform(side.origin(z), (0, 0, side.yaw)):
        with mb.transform((side.to_local(along), 0, 0)):
            fw, fh = WIN_W, WIN_H
            if r < p_gone:  # frame rotted away: just the dark opening and a cracked sill
                mb.box((0, -0.02, 0), (fw + 0.1, 0.06, fh + 0.1), "void")
                mb.box((0, -0.12, -fh / 2 - 0.1), (fw + 0.2, 0.25, 0.1), "trim", yaw=random.uniform(-0.1, 0.1))
                return
            mb.box((0, -0.05, 0), (fw + 0.2, 0.1, fh + 0.2), "frame")
            mb.box((0, -0.17, -fh / 2 - 0.12), (fw + 0.4, 0.3, 0.1), "trim")
            r -= p_gone
            if r < p_lit:
                mb.box((0, -0.11, 0), (fw, 0.04, fh), "lit", mat=1)
                mb.box((0, -0.14, 0), (0.06, 0.03, fh), "frame")
            elif r < p_lit + p_board:
                mb.box((0, -0.11, 0), (fw, 0.04, fh), "void")
                for i in range(random.choice((2, 3, 3))):
                    zc = -fh / 2 + 0.3 + i * (fh - 0.5) / 2 + random.uniform(-0.1, 0.1)
                    with mb.transform((0, -0.2, zc), (0, random.uniform(-0.35, 0.35), 0)):
                        mb.box((0, 0, 0), (fw + 0.45, 0.05, 0.24), random.choice(("board", "board_dark")))
            elif r < p_lit + p_board + p_broken:
                mb.box((0, -0.09, 0), (fw, 0.04, fh), "void")
                for _ in range(random.randint(1, 3)):  # shards left in the frame
                    ex = random.choice((-1, 1)) * (fw / 2 - 0.15)
                    ez = random.uniform(-fh / 2 + 0.2, fh / 2 - 0.2)
                    with mb.transform((ex, -0.12, ez), (0, random.uniform(0, math.pi), 0)):
                        mb.box((0, 0, 0), (random.uniform(0.15, 0.4), 0.02, random.uniform(0.25, 0.6)), "glass")
            else:
                mb.box((0, -0.11, 0), (fw, 0.04, fh), "glass" if random.random() < 0.5 else "glass_dirty")
                mb.box((0, -0.14, 0), (0.06, 0.03, fh), "frame")


def wall_block(mb, spec, top, x0, x1, y0, y1, z0, z1, boundary, weather, cut_color=None):
    """One box of building shell. boundary = set of sides on the footprint edge ('-y', '+y', '-x', '+x');
    other sides are exposed cuts (collapse) and get the interior colour."""
    w_col = spec["wall"]

    def fc(c, n, rgba):
        side = ("+" if (n[0] + n[1]) > 0 else "-") + ("x" if abs(n[0]) > 0.5 else "y")
        if abs(n[2]) < 0.5 and side not in boundary and cut_color:
            return K.color(cut_color)
        return weather(c, n, rgba)

    mb.box(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), w_col, seg=WALL_SEG,
           face_color=fc)
    sides = [Side("y", -1, y0, x0, x1), Side("y", 1, y1, x0, x1), Side("x", -1, x0, y0, y1), Side("x", 1, x1, y0, y1)]
    names = ["-y", "+y", "-x", "+x"]
    # floor bands: protruding trim on the facade, broken slab edges on cuts
    z = top - FLOOR
    while z > z0 + 0.5:
        if z < z1 - 0.2:
            for side, name in zip(sides, names):
                with mb.transform(side.origin(z), (0, 0, side.yaw)):
                    if name in boundary:
                        a = side.lo - (0.08 if _is_corner(side, "lo") else 0.0)
                        b = side.hi + (0.08 if _is_corner(side, "hi") else 0.0)
                        lx0, lx1 = sorted((side.to_local(a), side.to_local(b)))
                        mb.box(((lx0 + lx1) / 2, -0.035, 0), (lx1 - lx0, 0.09, 0.22), "trim", seg=3.0)
                    elif cut_color:
                        for i in range(int(side.length // 0.9)):
                            lx = -side.length / 2 + 0.45 + i * 0.9
                            depth = random.uniform(0.05, 0.6)
                            mb.box((lx, -depth / 2 + 0.02, random.uniform(-0.05, 0.05)), (0.92, depth, 0.24),
                                   "concrete_dark", yaw=random.uniform(-0.08, 0.08))
        z -= FLOOR
    # windows on facade sides only
    for side, name in zip(sides, names):
        if name not in boundary:
            continue
        grid = window_grid(spec["size"][0] if side.axis == "y" else spec["size"][1])
        for zc in window_centres_z(top, z0, z1):
            for along in grid:
                if side.lo + 0.9 < along < side.hi - 0.9:
                    window(mb, side, along, zc, spec, zc)
    return sides, names


def _is_corner(side, end):
    """Does this end of a facade side meet another facade side (an outside corner)?"""
    coord = side.lo if end == "lo" else side.hi
    w2 = SPEC_SIZE[0] / 2 if side.axis == "y" else SPEC_SIZE[1] / 2
    return abs(abs(coord) - w2) < 1e-6


def parapet(mb, side, top, spec, weather, ext_lo, ext_hi):
    """Parapet along a facade side, in 1.6 m segments; decay knocks some out or breaks them down."""
    decay = spec["decay"]
    t = PARAPET_T
    lo, hi = side.lo + ext_lo, side.hi - ext_hi
    n = max(1, round((hi - lo) / 1.6))
    seg_len = (hi - lo) / n
    with mb.transform(side.origin(top), (0, 0, side.yaw)):
        for i in range(n):
            a = lo + i * seg_len
            b = a + seg_len
            la, lb = sorted((side.to_local(a), side.to_local(b)))
            r = random.random()
            if r < 0.12 * decay:
                # gap: a stub and a fallen chunk on the roof
                mb.box((la + 0.2, t / 2, 0.15), (0.4, t, 0.3), spec["wall"])
                with mb.transform(((la + lb) / 2, t + 0.6, 0.15), (0.0, random.uniform(-0.3, 0.3), random.uniform(0, 1))):
                    mb.box((0, 0, 0), (seg_len * 0.6, t, 0.3), spec["wall"])
                continue
            h = PARAPET_H if r > 0.3 * decay else PARAPET_H * random.uniform(0.45, 0.8)
            mb.box(((la + lb) / 2, t / 2, h / 2), (lb - la, t, h), spec["wall"], seg=WALL_SEG, face_color=weather)
            if h == PARAPET_H:
                mb.box(((la + lb) / 2, t / 2, h + 0.05), (lb - la + 0.002, t + 0.12, 0.1), "trim")


def roof_slab(mb, top, rects):
    for x0, x1, y0, y1 in rects:
        mb.box(((x0 + x1) / 2, (y0 + y1) / 2, top - 0.06), (x1 - x0, y1 - y0, 0.12), "roof_slab", seg=1.6)


def roof_dressing(mb, spec, top, area, avoid):
    """Moss along the parapet, puddles, and (on derelict roofs) weeds and debris."""
    decay = spec["decay"]
    x0, x1, y0, y1 = area

    def free(x, y, r):
        return all(not (ax0 - r < x < ax1 + r and ay0 - r < y < ay1 + r) for ax0, ax1, ay0, ay1 in avoid)

    for _ in range(int(10 + 30 * decay)):  # moss creeping from the parapet foot
        edge = random.randrange(4)
        L = random.uniform(0.6, 2.2)
        if edge < 2:
            x, y = random.uniform(x0 + 1, x1 - 1), (y0 + 0.25 if edge == 0 else y1 - 0.25)
            size = (L, random.uniform(0.3, 0.7), 0.03)
        else:
            x, y = (x0 + 0.25 if edge == 2 else x1 - 0.25), random.uniform(y0 + 1, y1 - 1)
            size = (random.uniform(0.3, 0.7), L, 0.03)
        if free(x, y, 0.5):
            mb.box((x, y, top + 0.02), size, "moss")
    for _ in range(int(1 + 4 * decay)):  # standing water
        x, y = random.uniform(x0 + 2, x1 - 2), random.uniform(y0 + 2, y1 - 2)
        if free(x, y, 1.5):
            mb.box((x, y, top + 0.012), (random.uniform(1.0, 3.0), random.uniform(0.8, 2.2), 0.01), "puddle",
                   yaw=random.uniform(0, math.pi))
    if decay < 0.6:
        return
    for _ in range(int(6 * decay)):  # weeds and shrubs breaking through
        x, y = random.uniform(x0 + 0.8, x1 - 0.8), random.uniform(y0 + 0.8, y1 - 0.8)
        if not free(x, y, 0.8):
            continue
        for _ in range(random.randint(3, 6)):
            h = random.uniform(0.3, 1.1)
            mb.cylinder((x + random.uniform(-0.5, 0.5), y + random.uniform(-0.5, 0.5), top + h / 2),
                        random.uniform(0.2, 0.45), h, random.choice(("vine", "vine_dark", "moss")), segments=5,
                        radius_top=0.05)
    for _ in range(int(8 * decay)):  # planks, crates, trash bags
        x, y = random.uniform(x0 + 1, x1 - 1), random.uniform(y0 + 1, y1 - 1)
        if not free(x, y, 0.6):
            continue
        kind = random.random()
        with mb.transform((x, y, top), (0, 0, random.uniform(0, math.pi))):
            if kind < 0.45:
                with mb.transform((0, 0, 0.1), (random.uniform(-0.15, 0.15), random.uniform(-0.2, 0.2), 0)):
                    mb.box((0, 0, 0), (random.uniform(1.2, 2.6), 0.22, 0.05), random.choice(("board", "board_dark")))
            elif kind < 0.7:
                mb.box((0, 0, 0.3), (0.7, 0.6, 0.6), "board_dark")
            else:
                mb.box((0, 0, 0.18), (0.5, 0.45, 0.36), "trash", yaw=0.3)


def vines(mb, side, top, decay, z_bottom):
    """Creepers hanging from the parapet down the facade (local frame, outside the window frames)."""
    count = int(side.length / 5.0 * (0.4 + 1.6 * decay))
    with mb.transform(side.origin(0.0), (0, 0, side.yaw)):
        for _ in range(count):
            x = random.uniform(-side.length / 2 + 0.6, side.length / 2 - 0.6)
            z = top + PARAPET_H
            length = random.uniform(2.0, max(2.5, top + PARAPET_H - z_bottom) * (0.4 + 0.6 * decay))
            mb.box((x, PARAPET_T / 2, z + 0.12), (random.uniform(0.4, 0.8), PARAPET_T + 0.1, 0.06), "vine")
            dropped = 0.0
            while dropped < length:
                w = random.uniform(0.22, 0.45) * (1.0 - 0.5 * dropped / length)
                mb.box((x, -0.24, z - 0.3), (w, 0.06, 0.62), random.choice(("vine", "vine_dark")))
                if random.random() < 0.3:
                    mb.box((x + random.uniform(-0.25, 0.25), -0.28, z - 0.3), (random.uniform(0.4, 0.7), 0.08, 0.4),
                           "vine_dark")
                x += random.uniform(-0.18, 0.18)
                z -= 0.55
                dropped += 0.55


def rebar(mb, x, y, z, rot):
    with mb.transform((x, y, z), rot):
        L = random.uniform(0.5, 1.4)
        mb.box((0, 0, L / 2), (0.05, 0.05, L), "rebar")


def collapse_ruin(mb, spec, top, weather):
    """Shell with the +x/+y corner's upper floors gone: rubble on the exposed floor, rebar, broken slab edges."""
    w, d = spec["size"]
    cw, cd, lost = spec["collapse"]
    X0, X1, Y0, Y1 = -w / 2, w / 2, -d / 2, d / 2
    xc, yc = X1 - cw, Y1 - cd
    zc = top - lost * FLOOR
    body_top = top - 0.12
    all_sides = {"-x", "+x", "-y", "+y"}
    wall_block(mb, spec, top, X0, X1, Y0, Y1, -UNDERWATER, zc, all_sides, weather)
    wall_block(mb, spec, top, X0, X1, Y0, yc, zc, body_top, {"-x", "+x", "-y"}, weather, cut_color="interior")
    wall_block(mb, spec, top, X0, xc, yc, Y1, zc, body_top, {"-x", "+y"}, weather, cut_color="interior")
    t = PARAPET_T
    roof_slab(mb, top, [(X0 + t, X1 - t, Y0 + t, yc), (X0 + t, xc, yc, Y1 - t)])
    parapet(mb, Side("y", -1, Y0, X0, X1), top, spec, weather, 0, 0)
    parapet(mb, Side("x", -1, X0, Y0, Y1), top, spec, weather, t, t)
    parapet(mb, Side("x", 1, X1, Y0, yc), top, spec, weather, t, 0)
    parapet(mb, Side("y", 1, Y1, X0, xc), top, spec, weather, 0, 0)
    # exposed floor of the lost corner: broken slab, rubble heaped against the remaining walls
    mb.box(((xc + X1) / 2, (yc + Y1) / 2, zc + 0.06), (cw - 0.1, cd - 0.1, 0.12), "rubble", seg=1.0)
    for _ in range(int(cw * cd * 1.6)):
        x, y = random.uniform(xc + 0.2, X1 - 0.3), random.uniform(yc + 0.2, Y1 - 0.3)
        near = 1.0 - min(x - xc, y - yc) / max(cw, cd)
        s = random.uniform(0.25, 0.9) * (0.6 + near)
        with mb.transform((x, y, zc + 0.12 + s * 0.3 * near), (random.uniform(-0.4, 0.4), random.uniform(-0.4, 0.4),
                                                                 random.uniform(0, math.pi))):
            mb.box((0, 0, 0), (s, s * random.uniform(0.6, 1.2), s * 0.6), random.choice(("rubble", "concrete_dark", spec["wall"])))
    for _ in range(3):
        with mb.transform((random.uniform(xc + 1, X1 - 1), random.uniform(yc + 1, Y1 - 1), zc + 0.6),
                          (random.uniform(0.3, 0.7), random.uniform(-0.3, 0.3), random.uniform(0, math.pi))):
            mb.box((0, 0, 0), (random.uniform(1.5, 2.6), random.uniform(1.0, 1.8), 0.14), "roof_slab")
    # rebar sticking out of the cut slab edges
    for z in [zc] + [top - k * FLOOR for k in range(lost)]:
        for _ in range(4):
            rebar(mb, random.uniform(xc, X1 - 0.2), yc + 0.05, z, (random.uniform(-1.2, -0.3), random.uniform(-0.3, 0.3), 0))
            rebar(mb, xc + 0.05, random.uniform(yc, Y1 - 0.2), z, (random.uniform(-0.3, 0.3), random.uniform(0.3, 1.2), 0))
    return (X0 + t, X1 - t, Y0 + t, Y1 - t), [(xc, X1, yc, Y1)]


def roof_hole_ruin(mb, spec, top, weather):
    """Intact shell with a caved-in patch of roof slab: dark void, sagging slab pieces, rebar."""
    w, d = spec["size"]
    X0, X1, Y0, Y1 = -w / 2, w / 2, -d / 2, d / 2
    t = PARAPET_T
    nu, nv = math.ceil(w / WALL_SEG), math.ceil(d / WALL_SEG)
    cu, cv = w / nu, d / nv
    i0, j0 = int(nu * 0.55), int(nv * 0.25)
    i1, j1 = i0 + max(3, round(4.0 / cu)), j0 + max(3, round(3.2 / cv))
    hx0, hx1, hy0, hy1 = X0 + i0 * cu, X0 + i1 * cu, Y0 + j0 * cv, Y0 + j1 * cv

    def body_fc(c, n, rgba):
        if n[2] > 0.5 and hx0 < c[0] < hx1 and hy0 < c[1] < hy1:
            return K.color("void")
        return weather(c, n, rgba)

    all_sides = {"-x", "+x", "-y", "+y"}
    wall_block(mb, spec, top, X0, X1, Y0, Y1, -UNDERWATER, top - 0.12, all_sides, body_fc)
    roof_slab(mb, top, [(X0 + t, hx0, Y0 + t, Y1 - t), (hx1, X1 - t, Y0 + t, Y1 - t),
                        (hx0, hx1, Y0 + t, hy0), (hx0, hx1, hy1, Y1 - t)])
    for edge in range(4):  # slab pieces hinged down into the hole
        if edge < 2:
            x, y, rot = (hx0 + hx1) / 2, (hy0 if edge == 0 else hy1), ((-0.7 if edge == 0 else 0.7), 0, 0)
            size = (hx1 - hx0 - random.uniform(0.6, 1.4), 0.9, 0.1)
            off = (0, 0.45 if edge == 0 else -0.45, 0)
        else:
            x, y, rot = (hx0 if edge == 2 else hx1), (hy0 + hy1) / 2, (0, (0.7 if edge == 2 else -0.7), 0)
            size = (0.9, hy1 - hy0 - random.uniform(0.6, 1.4), 0.1)
            off = (0.45 if edge == 2 else -0.45, 0, 0)
        if random.random() < 0.7:
            with mb.transform((x, y, top - 0.08), rot):
                mb.box(off, size, "roof_slab")
        for _ in range(3):
            rebar(mb, x + random.uniform(-1, 1) * (edge < 2), y + random.uniform(-1, 1) * (edge >= 2), top - 0.1,
                  (random.uniform(-1.6, 1.6), random.uniform(-1.6, 1.6), 0))
    for side, el, eh in [(Side("y", -1, Y0, X0, X1), 0, 0), (Side("y", 1, Y1, X0, X1), 0, 0),
                         (Side("x", -1, X0, Y0, Y1), t, t), (Side("x", 1, X1, Y0, Y1), t, t)]:
        parapet(mb, side, top, spec, weather, el, eh)
    return (X0 + t, X1 - t, Y0 + t, Y1 - t), [(hx0 - 0.3, hx1 + 0.3, hy0 - 0.3, hy1 + 0.3)]


def intact_shell(mb, spec, top, weather):
    w, d = spec["size"]
    X0, X1, Y0, Y1 = -w / 2, w / 2, -d / 2, d / 2
    t = PARAPET_T
    wall_block(mb, spec, top, X0, X1, Y0, Y1, -UNDERWATER, top - 0.12, {"-x", "+x", "-y", "+y"}, weather)
    roof_slab(mb, top, [(X0 + t, X1 - t, Y0 + t, Y1 - t)])
    for side, el, eh in [(Side("y", -1, Y0, X0, X1), 0, 0), (Side("y", 1, Y1, X0, X1), 0, 0),
                         (Side("x", -1, X0, Y0, Y1), t, t), (Side("x", 1, X1, Y0, Y1), t, t)]:
        parapet(mb, side, top, spec, weather, el, eh)
    return (X0 + t, X1 - t, Y0 + t, Y1 - t), []


SPEC_SIZE = (0.0, 0.0)


def build(spec, out_dir):
    global SPEC_SIZE
    K.reset(spec["seed"])
    SPEC_SIZE = spec["size"]
    w, d = spec["size"]
    top = roof_height(spec["floors"])
    mb = K.MeshBuilder(aging=spec["decay"])
    weather = make_weathering(spec, top)

    hut_rect = None
    if spec["hut"]:
        # roof access hut in the -x/+y corner (Godot: -x/-z), footprint 3.0 x 2.6
        hx, hy = -w / 2 + PARAPET_T + 1.7, d / 2 - PARAPET_T - 1.5
        hut_rect = (hx - 1.5, hx + 1.5, hy - 1.3, hy + 1.3)

    if spec.get("collapse"):
        area, avoid = collapse_ruin(mb, spec, top, weather)
    elif spec.get("roof_hole"):
        area, avoid = roof_hole_ruin(mb, spec, top, weather)
    else:
        area, avoid = intact_shell(mb, spec, top, weather)

    if hut_rect:
        hx, hy = (hut_rect[0] + hut_rect[1]) / 2, (hut_rect[2] + hut_rect[3]) / 2
        mb.box((hx, hy, top + 1.35), (3.0, 2.6, 2.7), spec["wall"], seg=WALL_SEG, face_color=weather)
        mb.box((hx, hy, top + 2.75), (3.3, 2.9, 0.14), "trim")
        door = "board_dark" if spec["decay"] > 0.6 else "door"
        mb.box((hx + 1.52, hy - 0.3, top + 1.05), (0.06, 1.0, 2.1), door, yaw=0.0)
        avoid = avoid + [hut_rect]

    roof_dressing(mb, spec, top, area, avoid)
    for side in [Side("y", -1, -d / 2, -w / 2, w / 2), Side("y", 1, d / 2, -w / 2, w / 2),
                 Side("x", -1, -w / 2, -d / 2, d / 2), Side("x", 1, w / 2, -d / 2, d / 2)]:
        if spec.get("collapse") and (side.axis, side.sign) in (("x", 1), ("y", 1)):
            side = Side(side.axis, side.sign, side.coord, side.lo,
                        side.hi - (spec["collapse"][1] if side.axis == "x" else spec["collapse"][0]))
        vines(mb, side, top, spec["decay"], z_bottom=0.3)

    obj = mb.to_object(spec["name"])
    K.bake_vertex_ao(obj, distance=1.6, samples=48)
    return K.export_glb(obj, out_dir, spec["name"])


if __name__ == "__main__":
    a = K.args()
    out = a[0] if a else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")
    only = set(a[1:])
    for spec in BUILDINGS:
        if not only or spec["name"] in only:
            build(spec, out_dir=out)
