"""Survivor bodies, hair and facial hair (PHASE1 1.8 step 2) for kit_survivor.py.

J (2026-11-07): keep the blocky, rigid-part figure (it reads like a voxel toy and suits the game better than a smooth
skinned body) and spend the effort on joints and detail instead. So every piece is a box on one bone, as before,
with joint blocks that cover the bend (shoulder caps, elbows, wrists, hip blocks, knees, ankle cuffs) and small
details: collar and hem, belt and buckle, knee pads, cargo pockets, boot soles, toe caps and laces, fingers and a
thumb, eyes with pupils, brows, ears, nose, mouth, jaw. Same 13 bones and joints, so every clip, grip and IK holds.

Bodies: male / female × slim / average / muscular / heavy (body_<sex>_<build>); the game shows one.
Hair: hair_<style> (buzz, short, messy, long, ponytail, bun); facial hair: beard_<style> (stubble, beard, moustache).

Tint channels: UV.x holds which per-survivor colour a face takes (game/shaders/survivor.gdshader); the vertex colour
holds the shade (1 = the colour as is) and the baked AO in alpha. Channel 0 = the vertex colour as it is (eyes, belt).
Underclothes for now: a T-shirt (top), trousers (bottom), boots; outfit pieces come in step 3.
"""
import random

import bmesh
import bpy

import kit_common as K

CH_FIXED, CH_SKIN, CH_HAIR, CH_TOP, CH_BOTTOM, CH_SHOES = 0, 1, 2, 3, 4, 5

BUILDS = ("slim", "average", "muscular", "heavy")
HAIR_STYLES = ("buzz", "short", "messy", "long", "ponytail", "bun")
BEARDS = ("stubble", "beard", "moustache")

# region -> (width mul, depth mul) per build; female multiplies on top
BUILD_MULS = {
    "slim": {"all": (0.9, 0.9), "waist": (0.92, 0.92)},
    "average": {},
    "muscular": {"chest": (1.12, 1.1), "arm": (1.22, 1.2), "leg": (1.1, 1.08), "neck": (1.2, 1.15)},
    "heavy": {"waist": (1.25, 1.35), "hips": (1.12, 1.15), "chest": (1.08, 1.15), "arm": (1.12, 1.12),
              "leg": (1.14, 1.14), "neck": (1.2, 1.2)},
}
FEMALE_MULS = {"chest": (0.9, 0.95), "waist": (0.86, 0.92), "hips": (1.06, 1.02), "arm": (0.86, 0.88),
               "leg": (0.93, 0.95), "neck": (0.85, 0.85), "head": (0.96, 0.96)}


class Body:
    """A bmesh of boxes, each on one bone, with per-corner colour and a tint-channel UV."""

    def __init__(self, bones):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.dl = self.bm.verts.layers.deform.verify()
        self.bones = list(bones)

    def box(self, bone, c, s, channel, shade=1.0, rgb=None):
        """A box centred at `c` (rest-pose position), size `s`, all on `bone`."""
        x, y, z = c
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        gi = self.bones.index(bone)
        v = []
        for dz in (-1, 1):
            for dy in (-1, 1):
                for dx in (-1, 1):
                    vert = self.bm.verts.new((x + dx * hx, y + dy * hy, z + dz * hz))
                    vert[self.dl][gi] = 1.0
                    v.append(vert)
        c4 = (*rgb, 1.0) if rgb else (shade, shade, shade, 1.0)
        for idx in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
            f = self.bm.faces.new([v[i] for i in idx])
            for loop in f.loops:
                loop[self.col] = c4
                loop[self.uv].uv = (channel + 0.5, 0.5)

    def to_object(self, name):
        me = bpy.data.meshes.new(name)
        self.bm.normal_update()
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(me)
        self.bm.free()
        me.materials.append(bpy.data.materials[K.SURFACE])
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        for b in self.bones:
            obj.vertex_groups.new(name=b)
        for poly in me.polygons:
            poly.use_smooth = False
        return obj


def _muls(sex, build):
    m = dict(BUILD_MULS[build])
    if sex == "female":
        for k, (fw, fd) in FEMALE_MULS.items():
            w, d = m.get(k, (1.0, 1.0))
            m[k] = (w * fw, d * fd)
    return m


def body(rest, sex, build):
    b = Body(rest.keys())
    m = _muls(sex, build)
    female = sex == "female"
    aw, ad = m.get("all", (1.0, 1.0))

    def sz(region, x, y, z):
        w, d = m.get(region, (1.0, 1.0))
        return (x * w * aw, y * d * ad, z)

    dark = K.color("surv_strap")[:3]
    # pelvis: hips, belt with a buckle
    b.box("pelvis", (0, 0, 0.92), sz("hips", 0.34, 0.2, 0.2), CH_BOTTOM)
    b.box("pelvis", (0, 0, 1.0), sz("waist", 0.35, 0.21, 0.04), CH_FIXED, rgb=dark)
    b.box("pelvis", (0, -0.106 * m.get("waist", (1, 1))[1] * ad, 1.0), (0.05, 0.012, 0.03), CH_FIXED,
          rgb=K.color("metal")[:3])
    # torso: waist, chest, hem, collar, neck
    b.box("torso", (0, 0, 1.12), sz("waist", 0.36, 0.22, 0.2), CH_TOP, 0.95)
    b.box("torso", (0, 0, 1.035), sz("waist", 0.37, 0.23, 0.03), CH_TOP, 0.82)
    if build == "heavy":
        b.box("torso", (0, -0.13 * m["waist"][1], 1.1), (0.28, 0.05, 0.16), CH_TOP, 0.93)  # belly
    b.box("torso", (0, 0, 1.37), sz("chest", 0.4, 0.24, 0.3), CH_TOP)
    if female:
        b.box("torso", (0, -0.125 * m["chest"][1], 1.37), sz("chest", 0.3, 0.04, 0.09), CH_TOP, 0.97)
    if build == "muscular":
        b.box("torso", (0, -0.125 * m["chest"][1], 1.4), (0.34, 0.03, 0.12), CH_TOP, 0.96)  # pecs
    b.box("torso", (0, -0.1 * m.get("chest", (1, 1))[1], 1.515), (0.2, 0.06, 0.04), CH_TOP, 0.82)  # collar
    b.box("torso", (0, 0.095 * m.get("chest", (1, 1))[1], 1.515), (0.24, 0.05, 0.05), CH_TOP, 0.82)
    b.box("torso", (0, 0, 1.54), sz("neck", 0.1, 0.1, 0.07), CH_SKIN, 0.95)
    _head(b, m, female)
    for side, s in (("l", 1.0), ("r", -1.0)):
        _arm(b, rest, side, s, sz)
        _leg(b, rest, side, s, sz, m)
    return b


def _head(b, m, female):
    hw, hd = m.get("head", (1.0, 1.0))
    h = "head"
    white = K.color("styro")[:3]
    dark = K.color("dark")[:3]
    b.box(h, (0, -0.01, 1.68), (0.22 * hw, 0.24 * hd, 0.26 * hw), CH_SKIN)
    b.box(h, (0, -0.025, 1.565), (0.2 * hw * (0.92 if female else 1.0), 0.2 * hd, 0.05), CH_SKIN, 0.95)  # jaw
    fy = -0.01 - 0.12 * hd  # the face plane
    b.box(h, (0, fy - 0.015, 1.665), (0.035, 0.035, 0.05), CH_SKIN, 0.9)                     # nose
    b.box(h, (0, fy - 0.002, 1.605), (0.06, 0.01, 0.012), CH_FIXED, rgb=K.color("rust")[:3])  # mouth
    for s in (-1, 1):
        b.box(h, (s * 0.046, fy - 0.002, 1.7), (0.042, 0.01, 0.026), CH_FIXED, rgb=white)     # eyes
        b.box(h, (s * 0.046, fy - 0.006, 1.698), (0.018, 0.01, 0.022), CH_FIXED, rgb=dark)    # pupils
        b.box(h, (s * 0.048, fy - 0.004, 1.728), (0.05, 0.012, 0.012), CH_HAIR, 0.85)          # brows
        b.box(h, (s * 0.114 * hw, 0.0, 1.68), (0.02, 0.05, 0.06), CH_SKIN, 0.9)                # ears


def _arm(b, rest, side, s, sz):
    x = rest[f"arm_{side}"][0]
    a, f, hnd = f"arm_{side}", f"fore_{side}", f"hand_{side}"
    b.box(a, (x, 0, 1.44), sz("arm", 0.12, 0.13, 0.1), CH_TOP, 0.95)       # shoulder cap
    b.box(a, (x, 0, 1.355), sz("arm", 0.11, 0.12, 0.09), CH_TOP)          # sleeve
    b.box(a, (x, 0, 1.345 - 0.043), sz("arm", 0.115, 0.125, 0.02), CH_TOP, 0.82)  # sleeve hem
    b.box(a, (x, 0, 1.25), sz("arm", 0.09, 0.1, 0.12), CH_SKIN)           # upper arm
    b.box(f, (x, 0, 1.18), sz("arm", 0.098, 0.105, 0.06), CH_SKIN, 0.94)  # elbow
    b.box(f, (x, 0, 1.07), sz("arm", 0.085, 0.09, 0.17), CH_SKIN)         # forearm
    b.box(f, (x, 0, 0.965), sz("arm", 0.078, 0.082, 0.04), CH_SKIN, 0.94)  # wrist
    b.box(hnd, (x, -0.004, 0.89), (0.06, 0.085, 0.065), CH_SKIN)          # palm
    b.box(hnd, (x, -0.006, 0.835), (0.055, 0.078, 0.05), CH_SKIN, 0.92)    # fingers
    b.box(hnd, (x - s * 0.033, -0.036, 0.885), (0.024, 0.028, 0.05), CH_SKIN, 0.95)  # thumb, inward and forward


def _leg(b, rest, side, s, sz, m):
    x = rest[f"thigh_{side}"][0] * m.get("hips", (1.0, 1.0))[0]
    t, sh = f"thigh_{side}", f"shin_{side}"
    b.box(t, (x, 0, 0.84), sz("leg", 0.16, 0.17, 0.07), CH_BOTTOM, 0.95)  # hip block
    b.box(t, (x, 0, 0.65), sz("leg", 0.15, 0.16, 0.32), CH_BOTTOM)       # thigh
    b.box(t, (x + s * 0.08 * m.get("leg", (1, 1))[0], 0, 0.66), (0.02, 0.08, 0.1), CH_BOTTOM, 0.84)  # cargo pocket
    b.box(sh, (x, 0, 0.45), sz("leg", 0.145, 0.155, 0.08), CH_BOTTOM, 0.92)  # knee
    b.box(sh, (x, -0.078 * m.get("leg", (1, 1))[1], 0.44), (0.1, 0.02, 0.08), CH_BOTTOM, 0.78)  # knee pad
    b.box(sh, (x, 0, 0.26), sz("leg", 0.13, 0.14, 0.3), CH_BOTTOM)        # shin
    b.box(sh, (x, 0, 0.11), sz("leg", 0.14, 0.15, 0.04), CH_BOTTOM, 0.82)  # cuff
    b.box(sh, (x, -0.04, 0.05), (0.14, 0.25, 0.08), CH_SHOES)              # boot
    b.box(sh, (x, -0.04, 0.008), (0.145, 0.26, 0.016), CH_SHOES, 0.5)      # sole
    b.box(sh, (x, -0.15, 0.04), (0.135, 0.05, 0.065), CH_SHOES, 0.85)      # toe cap
    b.box(sh, (x, -0.075, 0.092), (0.04, 0.1, 0.01), CH_SHOES, 1.3)        # laces


# ---- hair and facial hair, on the head bone (the head box: x ±0.11, y -0.13..0.11, z 1.55..1.81) ---------

def hair(style):
    b = Body(["head"])
    h = "head"
    if style == "buzz":
        b.box(h, (0, -0.01, 1.817), (0.226, 0.246, 0.02), CH_HAIR)
        b.box(h, (0, 0.113, 1.73), (0.226, 0.02, 0.16), CH_HAIR, 0.95)
        for s in (-1, 1):
            b.box(h, (s * 0.113, 0.0, 1.77), (0.02, 0.2, 0.08), CH_HAIR, 0.95)
    elif style in ("short", "messy", "long", "ponytail"):
        b.box(h, (0, -0.01, 1.825), (0.236, 0.256, 0.05), CH_HAIR)                   # top
        b.box(h, (0, 0.117, 1.72), (0.236, 0.04, 0.2), CH_HAIR, 0.95)                # back
        for s in (-1, 1):
            b.box(h, (s * 0.118, 0.01, 1.765), (0.025, 0.19, 0.1), CH_HAIR, 0.95)   # sides
        b.box(h, (0, -0.132, 1.795), (0.2, 0.03, 0.04), CH_HAIR, 0.9)               # fringe
        if style == "messy":
            for _ in range(10):
                b.box(h, (random.uniform(-0.09, 0.09), random.uniform(-0.1, 0.09), random.uniform(1.845, 1.865)),
                      (0.05, 0.05, 0.04), CH_HAIR, random.uniform(0.85, 1.0))
        elif style == "long":
            b.box(h, (0, 0.122, 1.56), (0.24, 0.05, 0.34), CH_HAIR, 0.95)            # down the back
            for s in (-1, 1):
                b.box(h, (s * 0.12, 0.01, 1.64), (0.03, 0.09, 0.22), CH_HAIR, 0.92)  # past the ears
        elif style == "ponytail":
            b.box(h, (0, 0.145, 1.74), (0.05, 0.04, 0.04), CH_FIXED, rgb=K.color("surv_strap")[:3])  # tie
            b.box(h, (0, 0.155, 1.61), (0.06, 0.05, 0.22), CH_HAIR, 0.95)            # tail
    elif style == "bun":
        b.box(h, (0, -0.01, 1.82), (0.23, 0.25, 0.035), CH_HAIR)
        b.box(h, (0, 0.115, 1.73), (0.23, 0.03, 0.16), CH_HAIR, 0.95)
        for s in (-1, 1):
            b.box(h, (s * 0.115, 0.0, 1.77), (0.02, 0.2, 0.09), CH_HAIR, 0.95)
        b.box(h, (0, 0.07, 1.87), (0.1, 0.1, 0.09), CH_HAIR, 0.95)                 # bun
    return b


def beard(style):
    b = Body(["head"])
    h = "head"
    if style == "moustache":
        b.box(h, (0, -0.136, 1.622), (0.075, 0.02, 0.016), CH_HAIR, 0.85)
    elif style == "stubble":
        b.box(h, (0, -0.133, 1.585), (0.19, 0.015, 0.07), CH_HAIR, 0.55)
        for s in (-1, 1):
            b.box(h, (s * 0.108, -0.06, 1.6), (0.012, 0.12, 0.08), CH_HAIR, 0.55)
    elif style == "beard":
        b.box(h, (0, -0.13, 1.575), (0.21, 0.05, 0.11), CH_HAIR, 0.95)
        b.box(h, (0, -0.125, 1.505), (0.12, 0.06, 0.06), CH_HAIR, 0.9)              # chin
        b.box(h, (0, -0.138, 1.622), (0.08, 0.02, 0.018), CH_HAIR, 0.85)             # moustache
        for s in (-1, 1):
            b.box(h, (s * 0.108, -0.05, 1.62), (0.02, 0.14, 0.12), CH_HAIR, 0.92)
    return b
