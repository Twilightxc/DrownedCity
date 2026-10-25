"""Flooded-city isometric mockup — procedural low-poly scene built entirely in code."""
import bpy, math, random, sys
from mathutils import Vector

random.seed(7)
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/render.png"

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ---------------------------------------------------------------- materials
_mats = {}
def mat(name, rgb, rough=0.8, metal=0.0, alpha=1.0, emit=0.0):
    key = (name)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
    _mats[key] = m
    return m

def hexc(h):
    h = h.lstrip("#")
    c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)

M = {
    "concrete": mat("concrete", hexc("#c9b8a3")),
    "concrete2": mat("concrete2", hexc("#a99e93")),
    "concrete3": mat("concrete3", hexc("#d8c7a8")),
    "brick": mat("brick", hexc("#b0705a")),
    "roof": mat("roof", hexc("#8a8279")),
    "roof2": mat("roof2", hexc("#7d746a")),
    "window": mat("window", hexc("#2b3a44"), rough=0.2),
    "windowlit": mat("windowlit", hexc("#ffc56b"), emit=3.0),
    "wood": mat("wood", hexc("#9c6b43")),
    "wood_dark": mat("wood_dark", hexc("#6e4a2f")),
    "tarp_blue": mat("tarp_blue", hexc("#3f7fb8")),
    "tarp_orange": mat("tarp_orange", hexc("#e07b39")),
    "tank": mat("tank", hexc("#e8e2d0"), rough=0.5),
    "metal": mat("metal", hexc("#6f7b80"), rough=0.4, metal=0.6),
    "rust": mat("rust", hexc("#a0522d")),
    "solar": mat("solar", hexc("#1d3557"), rough=0.15, metal=0.3),
    "soil": mat("soil", hexc("#5b4030")),
    "leaf": mat("leaf", hexc("#5f9e4a")),
    "leaf2": mat("leaf2", hexc("#3f7d3a")),
    "skin": mat("skin", hexc("#e0b08a")),
    "shirt_r": mat("shirt_r", hexc("#d9534f")),
    "shirt_y": mat("shirt_y", hexc("#f2c14e")),
    "shirt_g": mat("shirt_g", hexc("#4e9a6b")),
    "pants": mat("pants", hexc("#3b4a5a")),
    "zombie": mat("zombie", hexc("#7f9a6a")),
    "zombie_cloth": mat("zombie_cloth", hexc("#5a5550")),
    "fire": mat("fire", hexc("#ff8a2a"), emit=12.0),
    "boat": mat("boat", hexc("#e9e4d8")),
    "boat_trim": mat("boat_trim", hexc("#c0392b")),
    "foam": mat("foam", hexc("#d9f2ee"), rough=0.6),
    "select": mat("select", hexc("#7dffb0"), emit=4.0),
}

# ---------------------------------------------------------------- primitives
def box(loc, size, m, rot=(0, 0, 0), bevel=0.0, name="box"):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(m)
    if bevel:
        mod = o.modifiers.new("bev", "BEVEL")
        mod.width = bevel
        mod.segments = 1
    return o

def cyl(loc, r, h, m, verts=12, rot=(0, 0, 0), name="cyl"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(m)
    return o

def cone(loc, r1, r2, h, m, verts=8, name="cone"):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=h, location=loc)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(m)
    return o

def flat_shade_all():
    for o in bpy.data.objects:
        if o.type == "MESH":
            for p in o.data.polygons:
                p.use_smooth = False

# ---------------------------------------------------------------- water
bpy.ops.mesh.primitive_plane_add(size=220, location=(0, 0, 0))
water = bpy.context.object
water.name = "water"
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.subdivide(number_cuts=90)
bpy.ops.object.mode_set(mode="OBJECT")
tex = bpy.data.textures.new("waves", "CLOUDS")
tex.noise_scale = 1.6
disp = water.modifiers.new("disp", "DISPLACE")
disp.texture = tex
disp.strength = 0.28
wm = bpy.data.materials.new("water")
wm.use_nodes = True
nt = wm.node_tree
bsdf = nt.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (*hexc("#2f8a9a"), 1)
bsdf.inputs["Roughness"].default_value = 0.08
bsdf.inputs["Specular IOR Level"].default_value = 0.6
# depth tint: darker away from buildings via noise
noise = nt.nodes.new("ShaderNodeTexNoise")
noise.inputs["Scale"].default_value = 0.05
ramp = nt.nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].color = (*hexc("#17566b"), 1)
ramp.color_ramp.elements[1].color = (*hexc("#3aa7a8"), 1)
nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
water.data.materials.append(wm)

# ---------------------------------------------------------------- buildings
def building(x, y, w, d, h, wall, roofm, windows=True, lit=0.0, name="bld"):
    """Building rising from below the waterline; roof surface at z=h."""
    base = -12
    f = 0.9
    box((x, y, 0.05), (w + f, d + f, 0.22), M["foam"], name=name + "_foam")
    box((x, y, (h + base) / 2), (w, d, h - base), wall, name=name)
    # roof slab + parapet
    box((x, y, h + 0.05), (w - 0.2, d - 0.2, 0.1), roofm, name=name + "_roof")
    t = 0.3
    ph = 0.7
    for sx, sy, sw, sd in [
        (x, y + d / 2 - t / 2, w, t), (x, y - d / 2 + t / 2, w, t),
        (x + w / 2 - t / 2, y, t, d - 2 * t), (x - w / 2 + t / 2, y, t, d - 2 * t),
    ]:
        box((sx, sy, h + ph / 2), (sw, sd, ph), wall)
    if not windows:
        return
    # windows on the two camera-facing sides (-y face and +x face)
    floor_h = 3.0
    z = h - 1.6
    while z > 0.4:
        for i in range(int(w // 2.6)):
            wx = x - w / 2 + 1.5 + i * 2.6
            if wx > x + w / 2 - 1.0:
                break
            m = M["windowlit"] if random.random() < lit else M["window"]
            box((wx, y - d / 2 - 0.02, z), (1.2, 0.08, 1.5), m)
        for i in range(int(d // 2.6)):
            wy = y - d / 2 + 1.5 + i * 2.6
            if wy > y + d / 2 - 1.0:
                break
            m = M["windowlit"] if random.random() < lit else M["window"]
            box((x + w / 2 + 0.02, wy, z), (0.08, 1.2, 1.5), m)
        z -= floor_h

# main base building
building(0, 0, 16, 14, 9, M["concrete3"], M["roof"], lit=0.05, name="base")
# neighbours
building(20, 2, 10, 12, 6, M["brick"], M["roof2"], name="b2")
building(-4, 18, 12, 10, 13, M["concrete2"], M["roof"], name="b3")
building(-20, -4, 10, 14, 4.5, M["concrete"], M["roof2"], name="b4")
building(14, -18, 9, 9, 3.2, M["brick"], M["roof"], name="b5")
building(-14, 22, 8, 8, 7, M["concrete3"], M["roof2"], name="b6")
building(30, 18, 12, 12, 10, M["concrete2"], M["roof"], name="b7")
building(-32, 14, 10, 10, 8, M["brick"], M["roof"], name="b8")
building(34, -8, 8, 10, 2.2, M["concrete"], M["roof2"], name="b9")

# collapsed / tilted ruin poking out of water
r = box((-12, -22, 0.8), (7, 6, 6), M["concrete2"], rot=(0.25, -0.18, 0.4), name="ruin")
box((-9, -25, 0.3), (3, 2, 1.2), M["concrete"], rot=(0.4, 0.2, 1.0))

# ---------------------------------------------------------------- main roof base props
H = 9.1
# water tank on legs
for lx, ly in [(-5.6, 4.0), (-3.6, 4.0), (-5.6, 5.6), (-3.6, 5.6)]:
    box((lx, ly, H + 1.0), (0.2, 0.2, 2.0), M["metal"])
cyl((-4.6, 4.8, H + 3.0), 1.4, 2.2, M["tank"], verts=14)
cyl((-4.6, 4.8, H + 4.2), 1.45, 0.2, M["metal"], verts=14)
box((-3.0, 4.8, H + 1.5), (0.12, 0.12, 3.0), M["metal"])  # pipe

# solar panels (tilted toward camera-left)
for i in range(3):
    px = 2.0 + i * 1.9
    box((px, 5.0, H + 0.35), (0.1, 0.1, 0.7), M["metal"])
    box((px, 5.0, H + 0.85), (1.7, 1.2, 0.08), M["solar"], rot=(math.radians(28), 0, 0))

# raised garden beds
for gx in (-5.0, -2.2):
    box((gx, -1.0, H + 0.3), (2.2, 1.2, 0.6), M["wood"])
    box((gx, -1.0, H + 0.62), (2.0, 1.0, 0.05), M["soil"])
    for k in range(4):
        cone((gx - 0.75 + k * 0.5, -1.0 + random.uniform(-0.25, 0.25), H + 0.9),
             0.25, 0.0, 0.55, random.choice([M["leaf"], M["leaf2"]]), verts=6)

# tarp tent (prism built from vertices)
def tent(x, y, z, L=3.2, W=2.4, Hh=1.6, m=None, yaw=0.0):
    me = bpy.data.meshes.new("tent")
    v = [(-L/2,-W/2,0),(L/2,-W/2,0),(L/2,W/2,0),(-L/2,W/2,0),(-L/2,0,Hh),(L/2,0,Hh)]
    f = [(0,1,5,4),(2,3,4,5),(0,4,3),(1,2,5)]
    me.from_pydata(v, [], f)
    o = bpy.data.objects.new("tent", me)
    scene.collection.objects.link(o)
    o.location = (x, y, z)
    o.rotation_euler.z = yaw
    o.data.materials.append(m)
    sol = o.modifiers.new("sol", "SOLIDIFY"); sol.thickness = 0.04
    return o
tent(4.4, -2.4, H, m=M["tarp_blue"], yaw=math.radians(90))

# second shelter: lean-to with orange tarp
box((-0.5, -4.6, H + 1.1), (3.2, 0.12, 2.2), M["wood_dark"])
box((-0.5, -3.7, H + 1.9), (3.4, 2.0, 0.08), M["tarp_orange"], rot=(math.radians(18), 0, 0))
for lx in (-2.0, 1.0):
    box((lx, -2.8, H + 0.8), (0.12, 0.12, 1.6), M["wood_dark"])

# crates & barrels (stockpile)
for (cx, cy, cz) in [(5.6, 2.0, 0), (6.5, 2.0, 0), (5.6, 2.9, 0), (6.05, 2.45, 0.85), (6.5, 2.9, 0)]:
    box((cx, cy, H + 0.42 + cz), (0.85, 0.85, 0.85), M["wood"], bevel=0.05)
for (bx, by, bm) in [(-6.5, -5.2, "rust"), (-5.7, -5.4, "tarp_blue"), (-6.2, -4.4, "rust")]:
    cyl((bx, by, H + 0.5), 0.38, 1.0, M[bm], verts=10)

# campfire
for k in range(5):
    a = k / 5 * math.tau
    box((1.5 + 0.35 * math.cos(a), 1.3 + 0.35 * math.sin(a), H + 0.12), (0.5, 0.12, 0.12),
        M["wood_dark"], rot=(0, 0, a))
cone((1.5, 1.3, H + 0.45), 0.28, 0.0, 0.7, M["fire"], verts=5)
fl = bpy.data.lights.new("fire", "POINT")
fl.energy = 250
fl.color = (1.0, 0.55, 0.2)
fl.shadow_soft_size = 0.2
fo = bpy.data.objects.new("fire_light", fl)
fo.location = (1.5, 1.3, H + 1.0)
scene.collection.objects.link(fo)

# radio antenna
box((6.8, 5.8, H + 3.0), (0.1, 0.1, 6.0), M["metal"])
box((6.8, 5.8, H + 5.6), (1.4, 0.06, 0.06), M["metal"])
box((6.8, 5.8, H + 4.8), (1.0, 0.06, 0.06), M["metal"])

# laundry line
box((-6.8, 1.5, H + 0.9), (0.08, 0.08, 1.8), M["wood_dark"])
box((-6.8, -3.0, H + 0.9), (0.08, 0.08, 1.8), M["wood_dark"])
box((-6.8, -0.75, H + 1.75), (0.02, 4.5, 0.02), M["metal"])
for k, cm in enumerate([M["shirt_r"], M["tank"], M["shirt_y"]]):
    box((-6.8, 0.6 - k * 1.2, H + 1.35), (0.04, 0.8, 0.75), cm)

# ---------------------------------------------------------------- characters
def person(x, y, z, shirt, face=0.0, zombie=False, selected=False):
    sk = M["zombie"] if zombie else M["skin"]
    cl = M["zombie_cloth"] if zombie else shirt
    parts = []
    parts.append(box((x - 0.13, y, z + 0.4), (0.2, 0.22, 0.8), M["pants"]))
    parts.append(box((x + 0.13, y, z + 0.4), (0.2, 0.22, 0.8), M["pants"]))
    parts.append(box((x, y, z + 1.15), (0.55, 0.32, 0.7), cl, bevel=0.03))
    parts.append(box((x, y, z + 1.75), (0.36, 0.36, 0.38), sk, bevel=0.04))
    arm_rot = (math.radians(-70), 0, 0) if zombie else (0, 0, 0)
    ay = y - 0.25 if zombie else y
    az = z + 1.25 if zombie else z + 1.1
    parts.append(box((x - 0.38, ay, az), (0.16, 0.18, 0.62), sk if zombie else cl, rot=arm_rot))
    parts.append(box((x + 0.38, ay, az), (0.16, 0.18, 0.62), sk if zombie else cl, rot=arm_rot))
    for p in parts:
        p.rotation_euler.z += 0  # keep simple; rotate as a group below
    # group rotate around person origin
    piv = Vector((x, y, z))
    for p in parts:
        off = p.location - piv
        off.rotate(__import__("mathutils").Euler((0, 0, face)))
        p.location = piv + off
        p.rotation_euler.z += face
    if selected:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.6, minor_radius=0.04,
                                         location=(x, y, z + 0.03))
        ring = bpy.context.object
        ring.data.materials.append(M["select"])

person(2.6, 1.0, H, M["shirt_r"], face=math.radians(150), selected=True)
person(0.5, 2.2, H, M["shirt_y"], face=math.radians(-120))
person(-3.6, -1.9, H, M["shirt_g"], face=math.radians(10))
person(5.5, 0.9, H, M["tank"], face=math.radians(200))
# survivor crossing bridge
person(10.2, 0.6, 9.0 - 1.25, M["shirt_y"], face=math.radians(90))

# zombies on low roof b9 and wading on ruin
for zx, zy, zf in [(33.0, -9.5, 2.6), (35.2, -7.4, 3.5), (34.2, -11.0, 2.2)]:
    person(zx, zy, 2.3, None, face=zf, zombie=True)
for zx, zy, zf in [(-20.5, -6.0, -0.4), (-18.7, -2.2, -0.2)]:
    person(zx, zy, 4.6, None, face=zf, zombie=True)

# ---------------------------------------------------------------- bridges
def plank_bridge(p0, p1, width=1.4):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    n = int(d.length / 0.45)
    yaw = math.atan2(d.y, d.x)
    for i in range(n):
        t = (i + 0.5) / n
        sag = -0.6 * math.sin(math.pi * t)
        p = p0 + d * t + Vector((0, 0, sag))
        box(p, (0.36, width, 0.08), M["wood"] if i % 3 else M["wood_dark"],
            rot=(0, 0, yaw + random.uniform(-0.05, 0.05)))
    # ropes
    for s in (-1, 1):
        off = Vector((-math.sin(yaw), math.cos(yaw), 0)) * (width / 2) * s
        for i in range(n):
            t = (i + 0.5) / n
            sag = -0.6 * math.sin(math.pi * t)
            p = p0 + d * t + off + Vector((0, 0, sag + 0.8))
            box(p, (0.47, 0.03, 0.03), M["wood_dark"], rot=(0, 0, yaw))

plank_bridge((8.0, 0.8, 9.1), (15.0, 0.8, 6.1))   # base -> b2 (slopes down)
plank_bridge((-1.0, 7.0, 9.1), (-1.0, 13.0, 9.1 + 0.0))  # base -> b3 side

# ---------------------------------------------------------------- dock + boat
for i in range(7):
    box((9.0 + i * 0.55, -8.0, 0.55), (0.5, 2.0, 0.1), M["wood"])
for px in (9.0, 12.3):
    for py in (-8.9, -7.1):
        cyl((px, py, 0.0), 0.12, 2.0, M["wood_dark"], verts=6)
# ladder up the base wall
for k in range(15):
    box((8.07, -6.0, 0.6 + k * 0.58), (0.06, 0.9, 0.06), M["metal"])
for sy in (-6.45, -5.55):
    box((8.07, sy, 4.9), (0.06, 0.06, 8.8), M["metal"])

def boat(x, y, yaw, length=4.5):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, 0.35))
    b = bpy.context.object
    b.scale = (length, 1.5, 0.6)
    bpy.ops.object.transform_apply(scale=True)
    # taper the bow
    for v in b.data.vertices:
        if v.co.x > 0:
            v.co.y *= 0.15 if v.co.z < 0 else 0.45
            v.co.x += 0.4 if v.co.z > 0 else 0.0
        if v.co.z < 0:
            v.co.y *= 0.7
    b.rotation_euler.z = yaw
    b.data.materials.append(M["boat"])
    box((x, y, 0.7), (length * 0.95, 1.55, 0.08), M["boat_trim"], rot=(0, 0, yaw))
    box((x - math.cos(yaw) * length * 0.42, y - math.sin(yaw) * length * 0.42, 0.85),
        (0.5, 0.4, 0.6), M["metal"], rot=(0, 0, yaw))  # outboard motor
    box((x + math.cos(yaw) * 0.3, y + math.sin(yaw) * 0.3, 0.75),
        (0.9, 0.7, 0.5), M["wood"], rot=(0, 0, yaw), bevel=0.04)  # cargo

boat(14.5, -8.3, math.radians(10))
boat(-14.0, 6.0, math.radians(-35), length=3.5)

# floating debris
for _ in range(26):
    x = random.uniform(-40, 40)
    y = random.uniform(-35, 35)
    if abs(x) < 10 and abs(y) < 9:
        continue
    if random.random() < 0.5:
        box((x, y, 0.15), (random.uniform(1.0, 2.5), 0.25, 0.18), M["wood_dark"],
            rot=(0, 0, random.uniform(0, math.pi)))
    else:
        box((x, y, 0.2), (0.7, 0.7, 0.5), M["wood"], rot=(0.1, 0.1, random.uniform(0, math.pi)))

# drowned trees / street lamps
for _ in range(9):
    x = random.uniform(-38, 38)
    y = random.uniform(-30, 32)
    if abs(x) < 12 and abs(y) < 10:
        continue
    cone((x, y, 1.0), 1.4, 0.0, 2.8, M["leaf2"], verts=7)
    cone((x, y, 2.4), 1.0, 0.0, 2.0, M["leaf"], verts=7)
for (lx, ly) in [(-8, -12), (6, -14), (24, -12)]:
    box((lx, ly, 1.0), (0.12, 0.12, 2.6), M["metal"])
    box((lx + 0.4, ly, 2.3), (0.9, 0.12, 0.1), M["metal"])

flat_shade_all()

# ---------------------------------------------------------------- lighting
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (*hexc("#a7c8d6"), 1)
bg.inputs["Strength"].default_value = 0.9

sun = bpy.data.lights.new("sun", "SUN")
sun.energy = 4.2
sun.color = hexc("#ffe2b8")
sun.angle = math.radians(3)
so = bpy.data.objects.new("sun", sun)
so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
scene.collection.objects.link(so)

# ---------------------------------------------------------------- camera (iso ortho)
target = Vector((2.0, 0.0, 4.0))
cam_d = bpy.data.cameras.new("cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = 52
cam_d.clip_end = 500
cam = bpy.data.objects.new("cam", cam_d)
scene.collection.objects.link(cam)
cam.location = target + Vector((40, -40, 38))
direction = target - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
scene.camera = cam

# ---------------------------------------------------------------- render settings
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 24
scene.render.threads_mode = "AUTO"
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 4
scene.render.resolution_x = 1920
scene.render.resolution_y = 1080
scene.render.film_transparent = False
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
# stylized outlines
scene.render.use_freestyle = True
scene.render.line_thickness_mode = "ABSOLUTE"
scene.render.line_thickness = 1.1
vl = scene.view_layers[0]
ls = vl.freestyle_settings.linesets[0]
ls.select_by_visibility = True
ls.select_silhouette = True
ls.select_border = True
ls.select_crease = True
if ls.linestyle is None:
    ls.linestyle = bpy.data.linestyles.new("ink")
ls.linestyle.color = hexc("#2a2420")
ls.linestyle.alpha = 0.55
# exclude water from outlines (its displaced mesh makes noise)
water_coll = bpy.data.collections.new("nolines")
scene.collection.children.link(water_coll)
for c in list(water.users_collection):
    c.objects.unlink(water)
water_coll.objects.link(water)
ls.select_by_collection = True
ls.collection = water_coll
ls.collection_negation = "EXCLUSIVE"

scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("DONE", OUT)
