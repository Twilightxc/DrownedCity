"""Flooded city v2 — stylized realism. Everything procedural: geometry, materials, lighting, post.
usage: python3 scene_v2_realistic.py -- out.png [W H SAMPLES]
"""
import bpy, math, random, sys
from mathutils import Vector, Euler

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else "/tmp/v2.png"
RW, RH, SPP = (int(args[1]), int(args[2]), int(args[3])) if len(args) >= 4 else (1920, 1080, 40)

random.seed(11)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)

def rgba(h): return (*srgb(h), 1.0)

# ============================================================ node helpers
class NT:
    def __init__(self, nt): self.nt = nt; self.N = nt.nodes
    def new(self, t, **kw):
        n = self.N.new(t)
        for k, v in kw.items(): setattr(n, k, v)
        return n
    def set(self, sock, v):
        if isinstance(v, bpy.types.NodeSocket): self.nt.links.new(v, sock)
        else: sock.default_value = v
    def noise(self, vec, scale, detail=4.0, rough=0.5, dist=0.0):
        n = self.new("ShaderNodeTexNoise")
        if vec is not None: self.set(n.inputs["Vector"], vec)
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        n.inputs["Distortion"].default_value = dist
        return n.outputs["Fac"]
    def ramp(self, fac, p0, p1, c0=(0, 0, 0, 1), c1=(1, 1, 1, 1)):
        r = self.new("ShaderNodeValToRGB")
        e = r.color_ramp.elements
        e[0].position, e[1].position = p0, p1
        e[0].color, e[1].color = c0, c1
        self.set(r.inputs["Fac"] if "Fac" in r.inputs else r.inputs[0], fac)
        return r.outputs["Color"]
    def mix(self, fac, a, b, blend="MIX"):
        m = self.new("ShaderNodeMix", data_type="RGBA", blend_type=blend)
        self.set(m.inputs[0], fac); self.set(m.inputs[6], a); self.set(m.inputs[7], b)
        return m.outputs[2]
    def math(self, op, a, b=0.0, clamp=False):
        m = self.new("ShaderNodeMath", operation=op, use_clamp=clamp)
        self.set(m.inputs[0], a); self.set(m.inputs[1], b)
        return m.outputs[0]
    def maprange(self, v, a0, a1, b0, b1):
        m = self.new("ShaderNodeMapRange", clamp=True)
        self.set(m.inputs["Value"], v)
        m.inputs["From Min"].default_value, m.inputs["From Max"].default_value = a0, a1
        m.inputs["To Min"].default_value, m.inputs["To Max"].default_value = b0, b1
        return m.outputs["Result"]
    def mapping(self, vec, scale):
        m = self.new("ShaderNodeMapping")
        self.set(m.inputs["Vector"], vec); m.inputs["Scale"].default_value = scale
        return m.outputs["Vector"]
    def bump(self, h, strength, normal=None):
        b = self.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = strength
        b.inputs["Distance"].default_value = 0.1
        self.set(b.inputs["Height"], h)
        if normal is not None: self.set(b.inputs["Normal"], normal)
        return b.outputs["Normal"]

_cache = {}
def weathered(name, base, dirt="#4a443c", rough=0.85, metal=0.0, scale=1.0, waterline=True,
              streaks=True, moss=0.0, bump=0.2, rust=0.0, emit=0.0):
    """Physically-plausible weathered surface: dirt, rain streaks, wet waterline, algae, moss, rust, grain."""
    if name in _cache: return _cache[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    t = NT(m.node_tree); b = t.N["Principled BSDF"]
    pos = t.new("ShaderNodeNewGeometry").outputs["Position"]
    col = rgba(base)
    # broad dirt variation
    dmask = t.ramp(t.noise(pos, 0.3 * scale, 6, 0.6), 0.42, 0.78)
    col = t.mix(t.math("MULTIPLY", dmask, 0.55), col, rgba(dirt))
    # tonal per-panel variation
    col = t.mix(t.math("MULTIPLY", t.noise(pos, 1.6 * scale, 2), 0.25), col, rgba(dirt), "OVERLAY")
    if streaks:  # vertical rain streaks
        sv = t.mapping(pos, (2.2 * scale, 2.2 * scale, 0.08))
        s = t.ramp(t.noise(sv, 2.0, 3, 0.5), 0.52, 0.8)
        col = t.mix(t.math("MULTIPLY", s, 0.45), col, (0.35, 0.33, 0.30, 1), "MULTIPLY")
    z = t.new("ShaderNodeSeparateXYZ"); t.set(z.inputs[0], pos); z = z.outputs["Z"]
    wet = None
    if waterline:
        # dark wet band that fades upward with a ragged edge
        edge = t.math("ADD", z, t.math("MULTIPLY", t.noise(pos, 1.2, 3), 0.9))
        wet = t.maprange(edge, 0.4, 2.6, 1.0, 0.0)
        col = t.mix(t.math("MULTIPLY", wet, 0.75), col, (0.30, 0.31, 0.27, 1), "MULTIPLY")
        alg = t.math("MULTIPLY", t.maprange(z, 0.0, 1.1, 1.0, 0.0),
                     t.ramp(t.noise(pos, 3.0, 4), 0.35, 0.6))
        col = t.mix(alg, col, rgba("#3d5a34"))
    if moss > 0:
        mm = t.ramp(t.noise(pos, 0.6, 6, 0.65), 0.62, 0.72)
        col = t.mix(t.math("MULTIPLY", mm, moss), col, rgba("#4f6b35"))
    if rust > 0:
        rm = t.ramp(t.noise(pos, 2.5, 6, 0.7), 0.5, 0.65)
        col = t.mix(t.math("MULTIPLY", rm, rust), col, rgba("#7a3b1c"))
    t.set(b.inputs["Base Color"], col)
    rr = t.math("ADD", rough, t.math("MULTIPLY", t.noise(pos, 4.0, 2), 0.12))
    if wet is not None: rr = t.math("SUBTRACT", rr, t.math("MULTIPLY", wet, 0.5), clamp=True)
    t.set(b.inputs["Roughness"], rr)
    b.inputs["Metallic"].default_value = metal
    if bump:
        t.set(b.inputs["Normal"], t.bump(t.noise(pos, 9.0 * scale, 6, 0.7), bump))
    if emit:
        b.inputs["Emission Color"].default_value = rgba(base)
        b.inputs["Emission Strength"].default_value = emit
    _cache[name] = m
    return m

def simple(name, base, rough=0.5, metal=0.0, emit=0.0, spec=0.5):
    if name in _cache: return _cache[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = rgba(base)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Specular IOR Level"].default_value = spec
    if emit:
        b.inputs["Emission Color"].default_value = rgba(base)
        b.inputs["Emission Strength"].default_value = emit
    _cache[name] = m
    return m

def cloth(name, base):
    return weathered(name, base, dirt="#3a352f", rough=0.95, waterline=False, streaks=False, bump=0.35, scale=3.0)

def foam_mat():
    m = bpy.data.materials.new("foam"); m.use_nodes = True
    t = NT(m.node_tree); N = t.N
    out = N["Material Output"]; b = N["Principled BSDF"]
    b.inputs["Base Color"].default_value = rgba("#b9c4b8"); b.inputs["Roughness"].default_value = 0.9
    tr = t.new("ShaderNodeBsdfTransparent")
    mx = t.new("ShaderNodeMixShader")
    pos = t.new("ShaderNodeNewGeometry").outputs["Position"]
    f = t.ramp(t.noise(pos, 3.0, 8, 0.7, 0.6), 0.6, 0.7, (0,0,0,1), (0.75,0.75,0.75,1))
    t.set(mx.inputs[0], f)
    t.nt.links.new(tr.outputs[0], mx.inputs[1]); t.nt.links.new(b.outputs[0], mx.inputs[2])
    t.nt.links.new(mx.outputs[0], out.inputs["Surface"])
    return m

def water_mat():
    m = bpy.data.materials.new("water"); m.use_nodes = True
    t = NT(m.node_tree); b = t.N["Principled BSDF"]
    pos = t.new("ShaderNodeNewGeometry").outputs["Position"]
    murk = t.ramp(t.noise(pos, 0.05, 4), 0.35, 0.7, rgba("#1d3a36"), rgba("#3c5a4c"))
    silt = t.ramp(t.noise(pos, 0.18, 5, 0.6), 0.55, 0.75)
    col = t.mix(t.math("MULTIPLY", silt, 0.5), murk, rgba("#6a6448"))
    t.set(b.inputs["Base Color"], col)
    b.inputs["Roughness"].default_value = 0.035
    b.inputs["Specular IOR Level"].default_value = 0.7
    big = t.noise(t.mapping(pos, (0.8, 1.4, 1)), 0.6, 3)
    small = t.noise(t.mapping(pos, (1, 2.2, 1)), 4.0, 4)
    n1 = t.bump(big, 0.35)
    t.set(b.inputs["Normal"], t.bump(small, 0.12, n1))
    return m

M = dict(
    concrete=weathered("concrete", "#c7bba8", scale=1.0, moss=0.5),
    concrete2=weathered("concrete2", "#a8a197", dirt="#3d3a35", moss=0.7),
    plaster=weathered("plaster", "#d6c4a0", dirt="#5a4b3a", moss=0.4),
    brick=weathered("brick", "#9c5a44", dirt="#3b2a22", scale=1.4, moss=0.6, bump=0.45),
    trim=weathered("trim", "#b8b0a2", dirt="#4a453e", waterline=True, moss=0.2),
    roof=weathered("roof", "#5f5a53", dirt="#2f2c28", waterline=False, streaks=False, moss=0.9, bump=0.5, scale=1.3),
    gravel=weathered("gravel", "#8a8378", dirt="#4a463f", waterline=False, streaks=False, bump=0.8, scale=3.0),
    glass=simple("glass", "#1b252b", rough=0.04, spec=1.0),
    glass_dirty=weathered("glass_dirty", "#28323a", dirt="#4a5048", rough=0.25, waterline=False, streaks=True, bump=0.0),
    dark=simple("dark", "#0d0f10", rough=0.9),
    lit=simple("lit", "#ffbe6e", emit=6.0),
    frame=weathered("frame", "#d9d2c3", dirt="#55504a", waterline=False, bump=0.05),
    wood=weathered("wood", "#8a6040", dirt="#3b2a1c", waterline=False, bump=0.4, scale=4.0),
    wood_old=weathered("wood_old", "#6f6355", dirt="#2f2a24", waterline=True, moss=0.5, bump=0.5, scale=4.0),
    metal=weathered("metal", "#7d868a", dirt="#3a3632", rough=0.45, metal=0.8, waterline=False, rust=0.6, bump=0.1),
    metal_paint=weathered("metal_paint", "#c9c4b4", dirt="#4a4036", rough=0.6, metal=0.2, waterline=False, rust=0.7, bump=0.1),
    tank=weathered("tank", "#d8d2c2", dirt="#4a453a", rough=0.6, waterline=False, rust=0.4, moss=0.0),
    solar=simple("solar", "#18243a", rough=0.12, metal=0.3, spec=1.0),
    tarp_blue=cloth("tarp_blue", "#2f6ea5"),
    tarp_orange=cloth("tarp_orange", "#d0702f"),
    tarp_green=cloth("tarp_green", "#4f6a3a"),
    sand=cloth("sand", "#b19a6c"),
    soil=weathered("soil", "#4a3426", waterline=False, streaks=False, bump=0.8, scale=5.0),
    leaf=weathered("leaf", "#3e5f2e", dirt="#2d4a22", rough=0.7, waterline=False, streaks=False, bump=0.4, scale=2.0),
    leaf2=weathered("leaf2", "#55702f", dirt="#34501f", rough=0.7, waterline=False, streaks=False, bump=0.4, scale=2.0),
    bark=weathered("bark", "#4a3a2c", waterline=True, streaks=False, bump=0.6),
    skin=simple("skin", "#d9a77f", rough=0.6),
    skin2=simple("skin2", "#a8724d", rough=0.6),
    hair=simple("hair", "#2a201a", rough=0.8),
    shirt_r=cloth("shirt_r", "#b8423c"),
    shirt_y=cloth("shirt_y", "#d6a83e"),
    shirt_g=cloth("shirt_g", "#4c7a58"),
    shirt_w=cloth("shirt_w", "#d8d4c8"),
    pants=cloth("pants", "#33404d"),
    pack=cloth("pack", "#5a4a32"),
    zombie=simple("zombie", "#7d8a6a", rough=0.7),
    zcloth=cloth("zcloth", "#4a4640"),
    fire=simple("fire", "#ff7a1f", emit=25.0),
    ember=simple("ember", "#ff3d00", emit=8.0),
    boat=weathered("boat", "#e2ddd0", dirt="#4d4a42", rough=0.5, waterline=True, rust=0.3),
    boat_trim=weathered("boat_trim", "#9e2f25", rough=0.5, waterline=False),
    sel=simple("sel", "#7dffb0", emit=5.0),
    puddle=simple("puddle", "#2a2f30", rough=0.02, spec=1.0),
    rope=cloth("rope", "#8c7a58"),
)
WATER = water_mat()
FOAM = foam_mat()

# ============================================================ geometry helpers
def finish(o, m, bevel=0.0, segs=1):
    o.data.materials.append(m)
    if bevel:
        b = o.modifiers.new("bev", "BEVEL"); b.width = bevel; b.segments = segs
        b.limit_method = "ANGLE"
    return o

import bmesh
COL = scene.collection
def _obj(bm, loc, rot, name="o"):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); COL.objects.link(o)
    o.location = loc; o.rotation_euler = rot
    return o

def box(loc, size, m, rot=(0, 0, 0), bevel=0.02, segs=1):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    return finish(_obj(bm, loc, rot, "box"), m, bevel, segs)

def cyl(loc, r, h, m, verts=16, rot=(0, 0, 0), bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts, radius1=r, radius2=r, depth=h)
    return finish(_obj(bm, loc, rot, "cyl"), m, bevel)

def cone(loc, r1, r2, h, m, verts=8):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts, radius1=r1, radius2=r2, depth=h)
    return finish(_obj(bm, loc, (0, 0, 0), "cone"), m)

def blob(loc, r, m, jitter=0.25, sub=2, squash=1.0):
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    for v in bm.verts:
        v.co *= 1 + random.uniform(-jitter, jitter); v.co.z *= squash
    return finish(_obj(bm, loc, (0, 0, 0), "blob"), m)

def quad(loc, sx, sy, m):
    me = bpy.data.meshes.new("q")
    me.from_pydata([(-sx/2, -sy/2, 0), (sx/2, -sy/2, 0), (sx/2, sy/2, 0), (-sx/2, sy/2, 0)], [], [(0, 1, 2, 3)])
    o = bpy.data.objects.new("q", me); COL.objects.link(o); o.location = loc
    o.data.materials.append(m); return o

# ============================================================ water + world
bpy.ops.mesh.primitive_plane_add(size=240, location=(0, 0, 0))
water = bpy.context.object; water.name = "water"
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.subdivide(number_cuts=120); bpy.ops.object.mode_set(mode="OBJECT")
tx = bpy.data.textures.new("w", "CLOUDS"); tx.noise_scale = 2.2
d = water.modifiers.new("d", "DISPLACE"); d.texture = tx; d.strength = 0.18; d.mid_level = 0.5
water.data.materials.append(WATER)

def foam_ring(x, y, w, d, pad=0.9):
    for (cx, cy, sx, sy) in [(x, y - d / 2 - pad / 2 + 0.1, w + 2 * pad, pad), (x, y + d / 2 + pad / 2 - 0.1, w + 2 * pad, pad),
                             (x - w / 2 - pad / 2 + 0.1, y, pad, d), (x + w / 2 + pad / 2 - 0.1, y, pad, d)]:
        quad((cx, cy, 0.13), sx, sy, FOAM)

# ============================================================ buildings
FLOOR = 3.2
def building(x, y, w, d, h, wall, name, lit=0.04, broken=0.12, clutter=True, hut=True):
    base = -14
    box((x, y, (h + base) / 2), (w, d, h - base), wall, bevel=0.06)
    foam_ring(x, y, w, d)
    # floor slab bands
    zf = h - FLOOR
    while zf > -1.0:
        box((x, y, zf), (w + 0.16, d + 0.16, 0.22), M["trim"], bevel=0.03)
        zf -= FLOOR
    # cornice + parapet
    box((x, y, h + 0.05), (w - 0.3, d - 0.3, 0.12), M["roof"], bevel=0.0)
    t, ph = 0.32, 0.8
    for sx, sy, sw, sd in [(x, y + d / 2 - t / 2, w, t), (x, y - d / 2 + t / 2, w, t),
                           (x + w / 2 - t / 2, y, t, d - 2 * t), (x - w / 2 + t / 2, y, t, d - 2 * t)]:
        box((sx, sy, h + ph / 2), (sw, sd, ph), wall, bevel=0.04)
    box((x, y, h + ph + 0.06), (w + 0.12, d + 0.12, 0.12), M["trim"], bevel=0.03)
    # windows on all 4 faces (2 visible ones dominate)
    def window(px, py, pz, axis, out):
        state = random.random()
        gm = M["lit"] if state < lit else (M["dark"] if state < lit + broken else
                                            (M["glass"] if random.random() < 0.6 else M["glass_dirty"]))
        fw, fh = 1.3, 1.7
        if axis == "x":  # face normal along y
            box((px, py + out * 0.05, pz), (fw + 0.2, 0.1, fh + 0.2), M["frame"], bevel=0.02)
            box((px, py + out * 0.11, pz), (fw, 0.04, fh), gm, bevel=0.0)
            box((px, py + out * 0.13, pz), (0.06, 0.04, fh), M["frame"], bevel=0.0)
            box((px, py + out * 0.16, pz - fh / 2 - 0.12), (fw + 0.4, 0.3, 0.1), M["trim"], bevel=0.02)
        else:
            box((px + out * 0.05, py, pz), (0.1, fw + 0.2, fh + 0.2), M["frame"], bevel=0.02)
            box((px + out * 0.11, py, pz), (0.04, fw, fh), gm, bevel=0.0)
            box((px + out * 0.13, py, pz), (0.04, 0.06, fh), M["frame"], bevel=0.0)
            box((px + out * 0.16, py, pz - fh / 2 - 0.12), (0.3, fw + 0.4, 0.1), M["trim"], bevel=0.02)
    z = h - FLOOR / 2
    while z > -0.8:
        n = int((w - 1.5) // 2.4)
        for i in range(n):
            wx = x - (n - 1) * 1.2 + i * 2.4
            window(wx, y - d / 2, z, "x", -1)
            window(wx, y + d / 2, z, "x", 1)
        n = int((d - 1.5) // 2.4)
        for i in range(n):
            wy = y - (n - 1) * 1.2 + i * 2.4
            window(x + w / 2, wy, z, "y", 1)
            window(x - w / 2, wy, z, "y", -1)
        z -= FLOOR
    if not clutter: return
    R = h + 0.11
    if hut:  # roof access stair hut
        hx, hy = x - w / 2 + 2.2, y + d / 2 - 2.0
        box((hx, hy, R + 1.35), (3.0, 2.6, 2.7), wall, bevel=0.04)
        box((hx, hy, R + 2.75), (3.3, 2.9, 0.14), M["trim"], bevel=0.03)
        box((hx + 1.52, hy - 0.3, R + 1.05), (0.06, 1.0, 2.1), M["metal_paint"], bevel=0.01)
    for _ in range(random.randint(1, 3)):  # AC units
        ax = x + random.uniform(-w / 2 + 2, w / 2 - 2); ay = y + random.uniform(-d / 2 + 2, d / 2 - 3)
        box((ax, ay, R + 0.45), (1.3, 1.0, 0.9), M["metal_paint"], bevel=0.04)
        cyl((ax, ay, R + 0.92), 0.38, 0.06, M["dark"], verts=16)
    for _ in range(random.randint(1, 3)):  # vent pipes
        vx = x + random.uniform(-w / 2 + 1, w / 2 - 1); vy = y + random.uniform(-d / 2 + 1, d / 2 - 1)
        cyl((vx, vy, R + 0.5), 0.14, 1.0, M["metal"], verts=10)
    for _ in range(random.randint(1, 2)):  # puddles
        px = x + random.uniform(-w / 3, w / 3); py = y + random.uniform(-d / 3, d / 3)
        o = cyl((px, py, R + 0.005), 1.0, 0.01, M["puddle"], verts=20)
        o.scale = (random.uniform(0.5, 1.1), random.uniform(0.4, 0.8), 1)

# --- the city
building(0, 0, 16, 14, 9.6, M["plaster"], "base", lit=0.06, clutter=False)
building(21, 2, 11, 12, 6.4, M["brick"], "b2")
building(-4, 19, 13, 11, 16.0, M["concrete2"], "b3")
building(-21, -4, 11, 15, 4.8, M["concrete"], "b4")
building(15, -19, 10, 10, 3.2, M["brick"], "b5")
building(-16, 24, 9, 9, 9.6, M["plaster"], "b6")
building(31, 19, 12, 12, 12.8, M["concrete2"], "b7")
building(-34, 15, 11, 11, 9.6, M["brick"], "b8")
building(35, -9, 9, 11, 3.2, M["concrete"], "b9")
building(-3, -32, 12, 8, 6.4, M["concrete2"], "b10")
building(45, 6, 9, 9, 9.6, M["plaster"], "b11")

# collapsed ruin + rubble
box((-12, -22, 0.6), (8, 7, 6.5), M["concrete2"], rot=(0.28, -0.2, 0.45), bevel=0.08)
for _ in range(14):
    box((-12 + random.uniform(-6, 6), -22 + random.uniform(-6, 5), random.uniform(-0.1, 0.5)),
        (random.uniform(0.6, 2.2), random.uniform(0.5, 1.8), random.uniform(0.3, 1.0)),
        M["concrete"], rot=(random.uniform(-.5, .5), random.uniform(-.5, .5), random.uniform(0, 3)), bevel=0.05)
foam_ring(-12, -22, 9, 8)

# ============================================================ survivor base (main roof)
H = 9.6 + 0.11
# sandbag wall along the camera-facing edges
def sandbag(x, y, z, yaw):
    o = box((x, y, z), (0.62, 0.34, 0.2), M["sand"], rot=(0, 0, yaw), bevel=0.09, segs=3)
    return o
for row in range(2):
    for i in range(22):
        sx = -7.0 + i * 0.64 + (0.32 if row else 0)
        if 3.0 < sx < 4.6: continue
        sandbag(sx, -6.1, H + 0.82 + row * 0.2, 0)
for row in range(2):
    for i in range(10):
        sy = -5.6 + i * 0.64 + (0.32 if row else 0)
        if -1.3 < sy < 1.6: continue
        sandbag(7.3, sy, H + 0.82 + row * 0.2, math.pi / 2)

# water tower
for lx, ly in [(-5.8, 3.9), (-3.4, 3.9), (-5.8, 6.0), (-3.4, 6.0)]:
    box((lx, ly, H + 1.2), (0.16, 0.16, 2.4), M["metal"], bevel=0.0)
box((-4.6, 3.9, H + 1.2), (2.4, 0.06, 0.06), M["metal"], rot=(0, 0.75, 0), bevel=0)
cyl((-4.6, 4.95, H + 3.5), 1.55, 2.4, M["tank"], verts=24, bevel=0.04)
cone((-4.6, 4.95, H + 5.05), 1.62, 0.15, 0.7, M["metal_paint"], verts=24)
box((-2.9, 4.95, H + 1.6), (0.12, 0.12, 3.2), M["metal"], bevel=0)
# rain collection tarp funnel
box((-1.3, 5.2, H + 1.2), (2.4, 1.6, 0.04), M["tarp_blue"], rot=(0.25, 0, 0), bevel=0)
cyl((-1.3, 5.6, H + 0.45), 0.42, 0.9, M["tarp_blue"], verts=14)

# solar panels on a frame
for i in range(4):
    px = 1.6 + i * 1.65
    box((px, 5.6, H + 0.35), (0.08, 0.08, 0.7), M["metal"], bevel=0)
    box((px, 5.0, H + 0.2), (0.08, 0.08, 0.4), M["metal"], bevel=0)
    box((px, 5.3, H + 0.75), (1.5, 1.15, 0.05), M["solar"], rot=(math.radians(28), 0, 0), bevel=0.01)
    box((px, 5.3, H + 0.72), (1.56, 1.2, 0.03), M["metal"], rot=(math.radians(28), 0, 0), bevel=0)

# garden beds with leafy crops
for gx in (-5.2, -2.4):
    box((gx, -0.6, H + 0.3), (2.3, 1.25, 0.6), M["wood"], bevel=0.03)
    box((gx, -0.6, H + 0.6), (2.12, 1.08, 0.04), M["soil"], bevel=0)
    for k in range(5):
        for j in range(2):
            blob((gx - 0.85 + k * 0.42, -0.85 + j * 0.5, H + 0.75), random.uniform(0.18, 0.26),
                 random.choice([M["leaf"], M["leaf2"]]), jitter=0.3, sub=1, squash=0.8)

# tents
def tent(x, y, z, L, W, Hh, m, yaw):
    me = bpy.data.meshes.new("tent")
    v = [(-L/2, -W/2, 0), (L/2, -W/2, 0), (L/2, W/2, 0), (-L/2, W/2, 0), (-L/2, 0, Hh), (L/2, 0, Hh),
         (-L/2 - 0.1, 0, Hh * 0.55), (L/2 + 0.1, 0, Hh * 0.55)]
    f = [(0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 6), (3, 6, 4), (1, 7, 5), (2, 5, 7)]
    me.from_pydata(v, [], f)
    o = bpy.data.objects.new("tent", me); scene.collection.objects.link(o)
    o.location = (x, y, z); o.rotation_euler.z = yaw
    o.data.materials.append(m)
    s = o.modifiers.new("s", "SOLIDIFY"); s.thickness = 0.03
    me.validate(); me.update()
    return o
tent(4.6, -2.6, H, 3.0, 2.4, 1.6, M["tarp_green"], math.radians(90))
tent(-5.5, -4.0, H, 2.6, 2.0, 1.3, M["tarp_blue"], math.radians(5))

# lean-to workshop
box((-0.3, -4.9, H + 1.15), (3.4, 0.12, 2.3), M["wood_old"], bevel=0.02)
box((-0.3, -4.0, H + 2.0), (3.6, 2.1, 0.05), M["tarp_orange"], rot=(math.radians(16), 0, 0), bevel=0)
for lx in (-1.9, 1.3):
    box((lx, -3.05, H + 0.85), (0.1, 0.1, 1.7), M["wood"], bevel=0)
box((-0.3, -4.3, H + 0.45), (2.4, 0.8, 0.9), M["wood"], bevel=0.03)  # workbench
box((-0.8, -4.3, H + 0.98), (0.6, 0.4, 0.16), M["metal_paint"], bevel=0.02)
cyl((0.5, -4.2, H + 1.0), 0.12, 0.25, M["metal"], verts=8)

# stockpile
for (cx, cy, cz) in [(5.6, 2.0, 0), (6.5, 2.0, 0), (5.6, 2.9, 0), (6.05, 2.45, 0.85), (6.5, 2.9, 0), (5.2, 3.8, 0)]:
    box((cx, cy, H + 0.42 + cz), (0.84, 0.84, 0.84), M["wood"], rot=(0, 0, random.uniform(-.15, .15)), bevel=0.04)
for (bx, by) in [(-6.6, 1.6), (-6.0, 2.3), (-6.7, 2.6)]:
    cyl((bx, by, H + 0.5), 0.36, 1.0, M["metal_paint"], verts=16, bevel=0.03)
    cyl((bx, by, H + 0.3), 0.37, 0.06, M["metal"], verts=16)
box((4.0, 4.0, H + 0.35), (1.8, 1.2, 0.7), M["tarp_blue"], bevel=0.15, segs=2)  # tarp-covered pile

# campfire with stone ring
for k in range(9):
    a = k / 9 * math.tau
    blob((1.4 + 0.62 * math.cos(a), 1.2 + 0.62 * math.sin(a), H + 0.08), 0.15, M["concrete2"], 0.3, 1, 0.7)
for k in range(4):
    a = k / 4 * math.pi
    box((1.4, 1.2, H + 0.14), (0.75, 0.1, 0.1), M["wood_old"], rot=(0, 0.2, a), bevel=0)
cone((1.4, 1.2, H + 0.45), 0.24, 0.0, 0.6, M["fire"], verts=6)
cone((1.32, 1.27, H + 0.35), 0.16, 0.0, 0.45, M["ember"], verts=5)
fl = bpy.data.lights.new("fire", "POINT"); fl.energy = 380; fl.color = (1.0, 0.5, 0.18); fl.shadow_soft_size = 0.3
fo = bpy.data.objects.new("fire_l", fl); fo.location = (1.4, 1.2, H + 1.0); scene.collection.objects.link(fo)
# string lights across the roof
for i in range(12):
    t_ = i / 11
    p = Vector((-6.0, -1.8, H + 2.4)).lerp(Vector((6.5, 0.5, H + 2.4)), t_)
    p.z -= 0.5 * math.sin(math.pi * t_)
    blob(p, 0.06, M["lit"], 0, 1)
for px, py in [(-6.0, -1.8), (6.5, 0.5)]:
    box((px, py, H + 1.2), (0.08, 0.08, 2.4), M["wood"], bevel=0)

# antenna
box((6.8, 6.1, H + 3.2), (0.08, 0.08, 6.4), M["metal"], bevel=0)
for hh, ww in [(5.8, 1.5), (5.0, 1.1), (4.2, 0.7)]:
    box((6.8, 6.1, H + hh), (ww, 0.04, 0.04), M["metal"], bevel=0)
blob((6.8, 6.1, H + 6.45), 0.07, simple("red", "#ff2a1a", emit=12), 0, 1)

# laundry
box((-7.0, -1.0, H + 0.95), (0.07, 0.07, 1.9), M["wood"], bevel=0)
box((-7.0, 3.0, H + 0.95), (0.07, 0.07, 1.9), M["wood"], bevel=0)
box((-7.0, 1.0, H + 1.85), (0.015, 4.0, 0.015), M["rope"], bevel=0)
for k, cm in enumerate([M["shirt_r"], M["shirt_w"], M["shirt_y"], M["pants"]]):
    box((-7.0, 2.4 - k * 0.95, H + 1.45), (0.03, 0.7, 0.75 if k < 3 else 0.9), cm, rot=(0, 0, random.uniform(-.1, .1)), bevel=0)

# ============================================================ people
def person(x, y, z, shirt, face=0.0, zombie=False, sel=False, pack=False, skin=None, pose=0.0):
    sk = M["zombie"] if zombie else (skin or M["skin"])
    cl = M["zcloth"] if zombie else shirt
    parts = []
    lean = 0.25 if zombie else 0.0
    parts += [box((x - 0.12, y + 0.06 * pose, z + 0.42), (0.17, 0.2, 0.84), M["pants"], bevel=0.05, segs=2),
              box((x + 0.12, y - 0.06 * pose, z + 0.42), (0.17, 0.2, 0.84), M["pants"], bevel=0.05, segs=2),
              box((x, y, z + 1.17), (0.48, 0.28, 0.7), cl, bevel=0.08, segs=2),
              box((x, y, z + 1.82), (0.27, 0.29, 0.32), sk, bevel=0.1, segs=3)]
    if not zombie:
        parts.append(box((x, y + 0.02, z + 1.95), (0.29, 0.31, 0.1), M["hair"], bevel=0.05, segs=2))
    ar = (math.radians(-80), 0, 0) if zombie else (math.radians(10 * pose), 0, 0)
    ay = y - 0.28 if zombie else y
    az = z + 1.32 if zombie else z + 1.12
    parts += [box((x - 0.33, ay, az), (0.13, 0.15, 0.62), sk if zombie else cl, rot=ar, bevel=0.05, segs=2),
              box((x + 0.33, ay, az), (0.13, 0.15, 0.62), sk if zombie else cl, rot=ar, bevel=0.05, segs=2)]
    if pack:
        parts.append(box((x, y + 0.24, z + 1.22), (0.38, 0.2, 0.5), M["pack"], bevel=0.06, segs=2))
    piv = Vector((x, y, z))
    rot = Euler((lean, 0, face))
    for p in parts:
        off = p.location - piv; off.rotate(rot); p.location = piv + off
        p.rotation_euler.x += lean; p.rotation_euler.z += face
    if sel:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.55, minor_radius=0.03, location=(x, y, z + 0.03))
        bpy.context.object.data.materials.append(M["sel"])

person(2.5, 0.9, H, M["shirt_r"], face=math.radians(150), sel=True, pack=True)
person(0.4, 2.2, H, M["shirt_y"], face=math.radians(-120), skin=M["skin2"])
person(-3.8, -1.6, H, M["shirt_g"], face=math.radians(10), pose=1)
person(5.4, 0.9, H, M["shirt_w"], face=math.radians(200), skin=M["skin2"])
person(-0.2, -3.6, H, M["pants"], face=math.radians(0))
person(11.0, 0.8, 7.9, M["shirt_y"], face=math.radians(90), pack=True, pose=1)  # on the bridge

# infected
for zx, zy, zf in [(34.0, -10.5, 2.6), (36.2, -7.6, 3.4), (33.0, -6.2, 2.2), (36.5, -12.0, 2.9)]:
    person(zx, zy, 3.31, None, face=zf, zombie=True)
for zx, zy, zf in [(-21.5, -6.5, -0.4), (-19.5, -1.6, -0.2), (-23.0, 0.5, 0.3)]:
    person(zx, zy, 4.91, None, face=zf, zombie=True)

# ============================================================ bridges, dock, boats
def plank_bridge(p0, p1, width=1.3, sag=0.55):
    p0, p1 = Vector(p0), Vector(p1)
    dv = p1 - p0; n = int(dv.length / 0.38); yaw = math.atan2(dv.y, dv.x)
    side = Vector((-math.sin(yaw), math.cos(yaw), 0))
    for i in range(n):
        t_ = (i + 0.5) / n
        p = p0 + dv * t_ + Vector((0, 0, -sag * math.sin(math.pi * t_)))
        if random.random() < 0.06: continue  # missing plank
        box(p, (0.3, width + random.uniform(-0.1, 0.1), 0.06), random.choice([M["wood"], M["wood_old"]]),
            rot=(0, 0, yaw + random.uniform(-0.06, 0.06)), bevel=0.01)
    for s in (-1, 1):
        for i in range(n):
            t_ = (i + 0.5) / n
            p = p0 + dv * t_ + side * (width / 2 + 0.05) * s + Vector((0, 0, -sag * math.sin(math.pi * t_) * 0.8 + 0.85))
            box(p, (0.4, 0.025, 0.025), M["rope"], rot=(0, 0, yaw), bevel=0)
        for i in range(0, n, 5):
            t_ = (i + 0.5) / n
            p = p0 + dv * t_ + side * (width / 2 + 0.05) * s + Vector((0, 0, -sag * math.sin(math.pi * t_) + 0.42))
            box(p, (0.05, 0.05, 0.85), M["wood"], bevel=0)

plank_bridge((8.0, 0.8, 9.7), (15.6, 0.8, 6.5))
plank_bridge((-1.2, 7.0, 9.7), (-1.2, 13.6, 9.7), sag=0.4)

# dock on floating barrels
for i in range(8):
    box((8.8 + i * 0.5, -8.2, 0.55), (0.46, 2.0, 0.08), M["wood_old"], rot=(0, 0, random.uniform(-.03, .03)), bevel=0.01)
for px in (9.2, 11.8):
    for py in (-8.9, -7.5):
        cyl((px, py, 0.25), 0.32, 0.6, M["metal_paint"], rot=(0, math.pi / 2, 0), verts=14)
foam_ring(10.5, -8.2, 4.0, 2.0, pad=0.6)
for k in range(16):
    box((8.08, -6.0, 0.6 + k * 0.58), (0.05, 0.85, 0.05), M["metal"], bevel=0)
for sy in (-6.42, -5.58):
    box((8.08, sy, 5.1), (0.05, 0.05, 9.2), M["metal"], bevel=0)

def boat(x, y, yaw, L=4.6, Wb=1.6, cargo=True):
    me = bpy.data.meshes.new("hull")
    v = [(-L/2, -Wb/2, 0.65), (L/2 - 0.9, -Wb/2, 0.65), (L/2 + 0.2, 0, 0.72), (L/2 - 0.9, Wb/2, 0.65), (-L/2, Wb/2, 0.65),
         (-L/2 + 0.1, -Wb/2 + 0.25, 0.05), (L/2 - 1.0, -Wb/2 + 0.3, 0.05), (L/2 - 0.3, 0, 0.25), (L/2 - 1.0, Wb/2 - 0.3, 0.05), (-L/2 + 0.1, Wb/2 - 0.25, 0.05)]
    f = [(0, 1, 6, 5), (1, 2, 7, 6), (2, 3, 8, 7), (3, 4, 9, 8), (4, 0, 5, 9), (5, 6, 7, 8, 9)]
    me.from_pydata(v, [], f)
    o = bpy.data.objects.new("boat", me); scene.collection.objects.link(o)
    o.location = (x, y, 0); o.rotation_euler.z = yaw
    o.data.materials.append(M["boat"])
    s = o.modifiers.new("s", "SOLIDIFY"); s.thickness = 0.06
    bv = o.modifiers.new("b", "BEVEL"); bv.width = 0.03
    c, sn = math.cos(yaw), math.sin(yaw)
    def at(lx, ly, z): return (x + lx * c - ly * sn, y + lx * sn + ly * c, z)
    box(at(-0.2, 0, 0.7), (L * 0.95, Wb + 0.04, 0.06), M["boat_trim"], rot=(0, 0, yaw), bevel=0.01)
    box(at(-L / 2 - 0.15, 0, 0.75), (0.4, 0.35, 0.7), M["metal_paint"], rot=(0, 0, yaw), bevel=0.04)
    box(at(-0.6, 0, 0.42), (0.3, Wb - 0.4, 0.06), M["wood"], rot=(0, 0, yaw), bevel=0.01)
    if cargo:
        box(at(0.6, 0, 0.45), (0.7, 0.6, 0.5), M["wood"], rot=(0, 0, yaw + 0.1), bevel=0.03)
        cyl(at(-0.1, 0.35, 0.45), 0.2, 0.55, M["tarp_blue"], verts=12)
    foam_ring(x, y, L * 0.7, Wb * 0.6, pad=0.5)

boat(14.8, -8.4, math.radians(8))
boat(-13.5, 7.0, math.radians(-35), L=3.6, Wb=1.3, cargo=False)

# floating debris, trees, lamp posts, car roof
for _ in range(36):
    x = random.uniform(-48, 50); y = random.uniform(-40, 40)
    if abs(x) < 10 and abs(y) < 9: continue
    r_ = random.random()
    if r_ < 0.45:
        box((x, y, 0.1), (random.uniform(1, 2.6), 0.22, 0.14), M["wood_old"], rot=(0, 0, random.uniform(0, 3.14)), bevel=0.01)
    elif r_ < 0.7:
        box((x, y, 0.15), (0.65, 0.65, 0.45), M["wood"], rot=(0.15, 0.1, random.uniform(0, 3.14)), bevel=0.03)
    elif r_ < 0.85:
        blob((x, y, 0.05), random.uniform(0.25, 0.5), random.choice([M["tarp_blue"], M["tarp_orange"], M["shirt_w"]]), 0.3, 1, 0.3)
    else:
        cyl((x, y, 0.15), 0.32, 0.9, M["metal_paint"], rot=(math.pi / 2, 0, random.uniform(0, 3)), verts=12)
for _ in range(14):
    x = random.uniform(-44, 46); y = random.uniform(-36, 36)
    if abs(x) < 11 and abs(y) < 10: continue
    cyl((x, y, 0.4), 0.18, 1.6, M["bark"], verts=7)
    for k in range(random.randint(2, 4)):
        blob((x + random.uniform(-0.8, 0.8), y + random.uniform(-0.8, 0.8), 1.3 + random.uniform(0, 1.2)),
             random.uniform(0.8, 1.4), random.choice([M["leaf"], M["leaf2"]]), 0.25, 2, 0.85)
    foam_ring(x, y, 1.5, 1.5, pad=0.6)
for (lx, ly) in [(-8, -12), (6, -14), (24, -12), (-28, 6)]:
    cyl((lx, ly, 1.2), 0.07, 3.0, M["metal"], verts=8)
    box((lx + 0.45, ly, 2.65), (1.0, 0.1, 0.08), M["metal"], bevel=0)
    box((lx + 0.9, ly, 2.58), (0.35, 0.22, 0.1), M["metal_paint"], bevel=0.02)
# submerged car roof
box((4.0, -14.5, 0.08), (2.2, 3.8, 0.3), simple("car", "#8c2a2a", rough=0.3, metal=0.6), rot=(0, 0, 0.4), bevel=0.15, segs=2)

# ============================================================ lighting: golden-hour sun + physical sky
world = bpy.data.worlds.new("w"); scene.world = world; world.use_nodes = True
wt = world.node_tree
sky = wt.nodes.new("ShaderNodeTexSky"); sky.sky_type = "MULTIPLE_SCATTERING"
sun_el, sun_rot = math.radians(17), math.radians(-60)
try:
    sky.sun_elevation = sun_el; sky.sun_rotation = sun_rot; sky.altitude = 200; sky.air_density = 1.4; sky.aerosol_density = 2.5
except Exception as e:
    print("sky props", e)
bg = wt.nodes["Background"]; bg.inputs["Strength"].default_value = 0.07
wt.links.new(sky.outputs[0], bg.inputs[0])
sky.sun_disc = False

sun = bpy.data.lights.new("sun", "SUN"); sun.energy = 6.5; sun.color = srgb("#ffd2a0"); sun.angle = math.radians(1.5)
so = bpy.data.objects.new("sun", sun); scene.collection.objects.link(so)
so.rotation_euler = (math.radians(90) - sun_el, 0, sun_rot + math.radians(90))
fill = bpy.data.lights.new("fill", "SUN"); fill.energy = 0.6; fill.color = srgb("#9fb8d6"); fill.use_shadow = False
fo2 = bpy.data.objects.new("fill", fill); scene.collection.objects.link(fo2)
fo2.rotation_euler = (math.radians(55), 0, math.radians(150))

# ============================================================ camera
target = Vector((2.0, 1.0, 7.5))
cd = bpy.data.cameras.new("cam"); cd.type = "ORTHO"; cd.ortho_scale = 44; cd.clip_end = 600
cam = bpy.data.objects.new("cam", cd); scene.collection.objects.link(cam)
cam.location = target + Vector((60, -60, 52))
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.camera = cam

# ============================================================ render
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = SPP
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 6
scene.cycles.glossy_bounces = 3
scene.cycles.transparent_max_bounces = 8
scene.cycles.use_adaptive_sampling = True
scene.render.resolution_x, scene.render.resolution_y = RW, RH
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.view_settings.exposure = -0.2

# atmospheric haze via mist pass + bloom (compositor)
vl = scene.view_layers[0]; vl.use_pass_mist = True
scene.world.mist_settings.start = 105; scene.world.mist_settings.depth = 60; scene.world.mist_settings.falloff = "QUADRATIC"
cg = bpy.data.node_groups.new("comp", "CompositorNodeTree")
cg.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
rl = cg.nodes.new("CompositorNodeRLayers")
out = cg.nodes.new("NodeGroupOutput")
fogm = cg.nodes.new("ShaderNodeMapRange"); fogm.clamp = True
fogm.inputs["To Max"].default_value = 0.3
mixn = cg.nodes.new("ShaderNodeMix"); mixn.data_type = "RGBA"
mixn.inputs[7].default_value = (*srgb("#c9c2b0"), 1)
glare = cg.nodes.new("CompositorNodeGlare")
glare.inputs["Type"].default_value = "Bloom"
glare.inputs["Threshold"].default_value = 1.2
glare.inputs["Strength"].default_value = 0.5
L = cg.links.new
L(rl.outputs["Mist"], fogm.inputs["Value"])
L(fogm.outputs["Result"], mixn.inputs[0])
L(rl.outputs["Image"], mixn.inputs[6])
L(mixn.outputs[2], glare.inputs["Image"])
L(glare.outputs["Image"], out.inputs[0])
scene.compositing_node_group = cg

scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("DONE", OUT)
