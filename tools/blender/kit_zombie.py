"""Style 1.5 horde zombie + vertex animation textures (VAT) -> assets/models, assets/vat

usage: blender -b --factory-startup --python tools/blender/kit_zombie.py -- [models_dir] [vat_dir]

The zombie is a rigid-part figure (pelvis, torso, head, arms, legs): each part is a few boxes that
turn about its joint. Clips are posed by forward kinematics per frame and every vertex position and
normal is written to two half-float EXR textures, one row per frame. The horde shader
(game/shaders/horde_vat.gdshader) reads them with texelFetch, so the MultiMesh plays animation without
a skeleton per zombie (GDD §13, PHASE0 0.7).

UV.y holds the part index (SKELETON order), so the shader can hide parts of a corpse (dismemberment).
Every mesh corner gets its own index in UV.x; that index is the VAT column, so the glTF exporter and
Godot's importer may split or reorder vertices freely. The .glb.import must keep generate_lods and
create_shadow_meshes off: both rebuild index/vertex buffers from the rest pose, which the VAT moves.

Clips are hand-keyed stand-ins until J's Mixamo clips arrive; a Mixamo clip only has to supply the
per-part rotations below (same parts, same joints), the bake stays the same.
Origin = feet on the ground (z = 0); faces -Y in Blender, which is +Z (the velocity) in Godot.
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_common as K  # noqa: E402

K.PALETTE.update({
    "zombie_skin": "#93ad7a", "zombie_shirt": "#515865", "zombie_pants": "#3e434b",
    "zombie_hair": "#2d3032", "zombie_wound": "#4a2f2c",
})

FPS = 24

# part: (parent, joint position in the parent's frame at rest)
SKELETON = {
    "pelvis": (None, None),  # joint = hips, placed by the clip's root translation
    "torso": ("pelvis", (0.0, 0.0, 0.09)),
    "head": ("torso", (0.0, 0.0, 0.52)),
    "arm_l": ("torso", (0.22, 0.0, 0.46)),
    "fore_l": ("arm_l", (0.0, 0.0, -0.29)),
    "arm_r": ("torso", (-0.22, 0.0, 0.46)),
    "fore_r": ("arm_r", (0.0, 0.0, -0.29)),
    "thigh_l": ("pelvis", (0.1, 0.0, -0.06)),
    "shin_l": ("thigh_l", (0.0, 0.0, -0.42)),
    "thigh_r": ("pelvis", (-0.1, 0.0, -0.06)),
    "shin_r": ("thigh_r", (0.0, 0.0, -0.42)),
}
HIP_HEIGHT = 0.9

VARIANTS = {
    # name: (overall scale, shoulder width scale, hip width scale, head scale)
    "zombie_male": (1.0, 1.0, 1.0, 1.0),
    "zombie_female": (0.94, 0.84, 1.08, 0.94),
}


def part_boxes(shoulder, hip, head):
    """Boxes per part in the part's own frame: (centre, size, colour)."""
    return {
        "pelvis": [((0, 0, 0.0), (0.34 * hip, 0.2, 0.2), "zombie_pants")],
        "torso": [((0, 0, 0.27), (0.4 * shoulder, 0.24, 0.5), "zombie_shirt"),
                  ((0.06, -0.125, 0.3), (0.12, 0.02, 0.1), "zombie_wound")],
        "head": [((0, -0.01, 0.15), (0.22 * head, 0.24 * head, 0.26 * head), "zombie_skin"),
                 ((0, 0.02, 0.29 * head), (0.23 * head, 0.22 * head, 0.05), "zombie_hair")],
        "arm_l": [((0, 0, -0.14), (0.1, 0.11, 0.3), "zombie_shirt")],
        "fore_l": [((0, 0, -0.15), (0.085, 0.09, 0.3), "zombie_skin")],
        "arm_r": [((0, 0, -0.14), (0.1, 0.11, 0.3), "zombie_shirt")],
        "fore_r": [((0, 0, -0.15), (0.085, 0.09, 0.3), "zombie_skin")],
        "thigh_l": [((0, 0, -0.21), (0.15, 0.16, 0.44), "zombie_pants")],
        "shin_l": [((0, 0, -0.2), (0.12, 0.13, 0.42), "zombie_pants"),
                   ((0, -0.05, -0.43), (0.12, 0.24, 0.07), "zombie_hair")],
        "thigh_r": [((0, 0, -0.21), (0.15, 0.16, 0.44), "zombie_pants")],
        "shin_r": [((0, 0, -0.2), (0.12, 0.13, 0.42), "zombie_pants"),
                   ((0, -0.05, -0.43), (0.12, 0.24, 0.07), "zombie_hair")],
    }


def joints(shoulder, hip):
    out = {}
    for part, (parent, j) in SKELETON.items():
        if j is not None:
            x, y, z = j
            if part.startswith("arm"):
                x *= shoulder
            elif part.startswith("thigh"):
                x *= hip
            j = (x, y, z)
        out[part] = (parent, j)
    return out


# ---- clips: frame -> {part: (rx, ry, rz)}, root translation -----------------------------------
# Signs (Blender, figure faces -Y): rx < 0 swings a hanging limb forward; rx > 0 on the torso or
# pelvis leans it forward; rx > 0 on a shin bends the knee.

def _base_arms(pose, t, reach=-1.3, sway=0.1):
    pose["arm_l"] = (reach + sway * math.sin(t), 0.0, -0.08)
    pose["arm_r"] = (reach - sway * math.sin(t + 0.7), 0.0, 0.1)
    pose["fore_l"] = (-0.25, 0.0, 0.0)
    pose["fore_r"] = (-0.15, 0.0, 0.0)


def walk(f, n):
    """Limping shamble, one full cycle (two steps)."""
    t = f / n * math.tau
    pose = {}
    pose["thigh_l"] = (-0.5 * math.sin(t), 0.0, 0.0)
    pose["shin_l"] = (0.7 * max(0.0, math.sin(t + 1.4)), 0.0, 0.0)
    pose["thigh_r"] = (0.3 * math.sin(t), 0.0, 0.05)  # dragged leg
    pose["shin_r"] = (0.35 * max(0.0, math.sin(t + math.pi + 1.4)), 0.0, 0.0)
    pose["pelvis"] = (0.0, 0.06 * math.sin(t), 0.08 * math.sin(t))
    pose["torso"] = (0.22 + 0.04 * math.sin(2 * t), 0.05 * math.sin(t), -0.06 * math.sin(t))
    pose["head"] = (0.12, 0.25 + 0.08 * math.sin(t), 0.1 * math.sin(t * 0.5))
    _base_arms(pose, t)
    root = (0.0, 0.0, HIP_HEIGHT - 0.03 + 0.03 * abs(math.cos(t)))
    return pose, root


def _ease(a, b, u):
    u = max(0.0, min(1.0, u))
    u = u * u * (3 - 2 * u)
    return a + (b - a) * u


def _keys(keys, f):
    """Piecewise-eased value from [(frame, value), ...]."""
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if f <= f1:
            return _ease(v0, v1, (f - f0) / max(1e-6, f1 - f0))
    return keys[-1][1]


def attack(f, n):
    pose, root = walk(0, 1)
    reach = _keys([(0, -1.3), (7, -2.5), (11, -0.5), (n - 1, -1.3)], f)
    lean = _keys([(0, 0.22), (7, -0.05), (11, 0.55), (n - 1, 0.22)], f)
    _base_arms(pose, 0.0, reach, 0.0)
    pose["fore_l"] = (_keys([(0, -0.25), (7, -0.9), (11, 0.0), (n - 1, -0.25)], f), 0.0, 0.0)
    pose["fore_r"] = pose["fore_l"]
    pose["torso"] = (lean, 0.0, 0.0)
    pose["head"] = (_keys([(0, 0.12), (7, -0.25), (11, 0.35), (n - 1, 0.12)], f), 0.0, 0.0)
    root = (0.0, _keys([(0, 0.0), (11, -0.15), (n - 1, 0.0)], f), HIP_HEIGHT - 0.03)
    return pose, root


def flinch(f, n):
    pose, root = walk(0, 1)
    k = _keys([(0, 0.0), (2, 1.0), (n - 1, 0.0)], f)
    pose["torso"] = (0.22 - 0.5 * k, 0.15 * k, 0.0)
    pose["head"] = (0.12 - 0.6 * k, -0.3 * k, 0.0)
    _base_arms(pose, 0.0, -1.3 + 0.8 * k, 0.0)
    pose["arm_l"] = (pose["arm_l"][0], 0.0, -0.08 - 0.5 * k)
    pose["arm_r"] = (pose["arm_r"][0], 0.0, 0.1 + 0.5 * k)
    root = (0.0, 0.08 * k, HIP_HEIGHT - 0.03 - 0.04 * k)
    return pose, root


def death(f, n):
    """Knees buckle, then a fall forward onto the face. The last frame is the corpse pose."""
    pose, _ = walk(0, 1)
    fall = _keys([(0, 0.0), (8, 0.15), (n - 1, 1.5)], f)
    knees = _keys([(0, 0.0), (8, 1.1), (16, 0.5), (n - 1, 0.1)], f)
    pose["pelvis"] = (fall, 0.0, _keys([(0, 0.0), (n - 1, 0.25)], f))
    pose["thigh_l"] = (-knees * 0.8, 0.0, 0.1)
    pose["thigh_r"] = (-knees * 0.6, 0.0, -0.15)
    pose["shin_l"] = (knees, 0.0, 0.0)
    pose["shin_r"] = (knees * 0.9, 0.0, 0.0)
    pose["torso"] = (_keys([(0, 0.22), (8, 0.5), (n - 1, 0.05)], f), 0.0, _keys([(0, 0.0), (n - 1, 0.2)], f))
    pose["head"] = (_keys([(0, 0.12), (n - 1, -0.5)], f), _keys([(0, 0.0), (n - 1, 0.9)], f), 0.0)
    reach = _keys([(0, -1.3), (10, -0.6), (n - 1, -2.9)], f)
    _base_arms(pose, 0.0, reach, 0.0)
    pose["arm_r"] = (_keys([(0, -1.3), (n - 1, -0.4)], f), 0.0, 0.6)
    height = _keys([(0, HIP_HEIGHT - 0.03), (8, 0.62), (n - 1, 0.13)], f)
    root = (0.0, _keys([(0, 0.0), (n - 1, -0.2)], f), height)
    return pose, root


def death_blown(f, n):
    """Thrown backwards by a blast (fake ragdoll, GDD §6): the horde moves the corpse along the arc."""
    pose, _ = walk(0, 1)
    fall = _keys([(0, 0.0), (n - 1, -1.5)], f)
    pose["pelvis"] = (fall, 0.0, _keys([(0, 0.0), (n - 1, -0.3)], f))
    flail = math.sin(f / n * math.tau * 1.5)
    pose["arm_l"] = (_keys([(0, -1.3), (6, -3.0), (n - 1, -2.6)], f) + 0.3 * flail, 0.0, -0.6)
    pose["arm_r"] = (_keys([(0, -1.3), (6, -2.6), (n - 1, -2.2)], f) - 0.3 * flail, 0.0, 0.7)
    pose["thigh_l"] = (_keys([(0, 0.0), (8, -0.9), (n - 1, -0.2)], f), 0.0, 0.15)
    pose["thigh_r"] = (_keys([(0, 0.0), (8, -0.5), (n - 1, -0.1)], f), 0.0, -0.2)
    pose["shin_l"] = (_keys([(0, 0.0), (8, 0.9), (n - 1, 0.2)], f), 0.0, 0.0)
    pose["shin_r"] = (_keys([(0, 0.0), (8, 0.5), (n - 1, 0.1)], f), 0.0, 0.0)
    pose["torso"] = (_keys([(0, 0.22), (n - 1, -0.1)], f), 0.0, 0.0)
    pose["head"] = (_keys([(0, 0.12), (5, -0.7), (n - 1, 0.3)], f), _keys([(0, 0.0), (n - 1, -0.6)], f), 0.0)
    height = _keys([(0, HIP_HEIGHT - 0.03), (6, 1.05), (n - 1, 0.13)], f)
    root = (0.0, 0.0, height)
    return pose, root


# name, builder, frames, loop, walk stride (m per cycle, 0 = time-driven)
CLIPS = [
    ("walk", walk, 24, True, 1.3),
    ("attack", attack, 18, False, 0.0),
    ("flinch", flinch, 8, False, 0.0),
    ("death", death, 28, False, 0.0),
    ("death_blown", death_blown, 24, False, 0.0),
]


# ---- mesh + bake ----------------------------------------------------------------------------

def world_matrices(pose, root, skel):
    out = {}
    for part, (parent, joint) in skel.items():  # SKELETON is ordered parents first
        rx, ry, rz = pose.get(part, (0.0, 0.0, 0.0))
        rot = Euler((rx, ry, rz), "XYZ").to_matrix().to_4x4()
        if parent is None:
            out[part] = Matrix.Translation(Vector(root)) @ rot
        else:
            out[part] = out[parent] @ Matrix.Translation(Vector(joint)) @ rot
    return out


def build_corners(boxes):
    """Flat list of quads: (part, 4 local corners, local normal, colour name)."""
    quads = []
    for part, items in boxes.items():
        for (cx, cy, cz), (sx, sy, sz), col in items:
            hx, hy, hz = sx / 2, sy / 2, sz / 2
            faces = [
                ((0, -1, 0), [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz)]),
                ((0, 1, 0), [(hx, hy, -hz), (-hx, hy, -hz), (-hx, hy, hz), (hx, hy, hz)]),
                ((1, 0, 0), [(hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz), (hx, -hy, hz)]),
                ((-1, 0, 0), [(-hx, hy, -hz), (-hx, -hy, -hz), (-hx, -hy, hz), (-hx, hy, hz)]),
                ((0, 0, 1), [(-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]),
                ((0, 0, -1), [(-hx, hy, -hz), (hx, hy, -hz), (hx, -hy, -hz), (-hx, -hy, -hz)]),
            ]
            for n, corners in faces:
                quads.append((part, [Vector((cx + x, cy + y, cz + z)) for x, y, z in corners], Vector(n), col))
    return quads


def rest_object(name, quads, skel):
    """Mesh in the walk pose at frame 0 (what the importer sees; the shader replaces it)."""
    pose, root = walk(0, 1)
    mats = world_matrices(pose, root, skel)
    verts, faces = [], []
    for part, corners, _n, _c in quads:
        base = len(verts)
        verts.extend((mats[part] @ c)[:] for c in corners)
        faces.append((base, base + 1, base + 2, base + 3))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    uv = me.uv_layers.new(name="VatIndex")
    parts = list(SKELETON)
    for poly, (part, _c, _n, col_name) in zip(me.polygons, quads):
        rgba = K.color(col_name)
        for li in poly.loop_indices:
            col.data[li].color = rgba
            # x: corner index = VAT column; y: part index for dismemberment masks (+0.5: no rounding edge)
            uv.data[li].uv = (li + 0.5, parts.index(part) + 0.5)
    me.color_attributes.active_color = col
    me.materials.append(bpy.data.materials[K.SURFACE])
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def to_godot(v):
    return (v.x, v.z, -v.y)


def bake_vat(name, quads, skel, vat_dir):
    width = len(quads) * 4
    rows = []  # per frame: list of (pos, nrm) per corner
    clip_rows = []
    for clip_name, fn, frames, loop, stride in CLIPS:
        clip_rows.append((clip_name, len(rows), frames, loop, stride))
        for f in range(frames):
            pose, root = fn(f, frames)
            mats = world_matrices(pose, root, skel)
            row = []
            for part, corners, n, _c in quads:
                m = mats[part]
                nrm = (m.to_3x3() @ n).normalized()
                for c in corners:
                    row.append((to_godot(m @ c), to_godot(nrm)))
            rows.append(row)
    height = len(rows)
    os.makedirs(vat_dir, exist_ok=True)
    scene = bpy.context.scene
    scene.render.image_settings.file_format = "OPEN_EXR"
    scene.render.image_settings.color_depth = "16"
    scene.render.image_settings.exr_codec = "ZIP"
    paths = []
    for kind in ("pos", "nrm"):
        img = bpy.data.images.new(f"{name}_{kind}", width, height, alpha=True, float_buffer=True)
        img.colorspace_settings.name = "Non-Color"
        px = [0.0] * (width * height * 4)
        for r, row in enumerate(rows):
            y = height - 1 - r  # Blender rows start at the bottom; Godot row 0 is the top
            for x, (p, nr) in enumerate(row):
                v = p if kind == "pos" else nr
                i = (y * width + x) * 4
                px[i:i + 4] = (v[0], v[1], v[2], 1.0)
        img.pixels = px
        path = os.path.join(vat_dir, f"{name}_{kind}.exr")
        img.save_render(path, scene=scene)
        _write_import(path)
        paths.append(path)
    _write_clips(os.path.join(vat_dir, f"{name}_clips.tres"), name, width, height, clip_rows)
    print(f"baked {name}: {width} vertices x {height} frames -> {paths}")


def _write_import(exr_path):
    """Keep the VAT as raw half floats: no compression, no mipmaps (Godot fills in the rest).
    An existing .import is kept, so its uid stays stable."""
    if os.path.exists(exr_path + ".import"):
        return
    with open(exr_path + ".import", "w", encoding="utf-8", newline="\n") as fh:
        fh.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
                 "compress/mode=3\ncompress/high_quality=false\nmipmaps/generate=false\n"
                 "detect_3d/compress_to=0\nprocess/fix_alpha_border=false\n")


def _write_clips(path, name, width, height, clip_rows):
    def arr(kind, values):
        return f"{kind}({', '.join(values)})"
    names = arr("PackedStringArray", [f'"{c[0]}"' for c in clip_rows])
    starts = arr("PackedInt32Array", [str(c[1]) for c in clip_rows])
    frames = arr("PackedInt32Array", [str(c[2]) for c in clip_rows])
    loops = arr("PackedInt32Array", ["1" if c[3] else "0" for c in clip_rows])
    strides = arr("PackedFloat32Array", [f"{c[4]:.3f}" for c in clip_rows])
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write('[gd_resource type="Resource" script_class="VatClips" load_steps=2 format=3]\n\n'
                 '[ext_resource type="Script" path="res://combat/vat_clips.gd" id="1_vat"]\n\n'
                 f'[resource]\nscript = ExtResource("1_vat")\nmesh_name = "{name}"\nfps = {FPS}.0\n'
                 f"vertex_count = {width}\nframe_count = {height}\nnames = {names}\nstart_row = {starts}\n"
                 f"frames = {frames}\nloops = {loops}\nstride = {strides}\n")


if __name__ == "__main__":
    a = K.args()
    root = os.path.join(os.path.dirname(__file__), "..", "..", "assets")
    models = a[0] if a else os.path.join(root, "models")
    vat = a[1] if len(a) > 1 else os.path.join(root, "vat")
    for variant, (scale, shoulder, hip, head) in VARIANTS.items():
        K.reset(17)
        skel = joints(shoulder, hip)
        quads = build_corners(part_boxes(shoulder, hip, head))
        if scale != 1.0:
            skel = {p: (par, None if j is None else tuple(c * scale for c in j)) for p, (par, j) in skel.items()}
            quads = [(p, [c * scale for c in cs], n, col) for p, cs, n, col in quads]
        HIP_HEIGHT = 0.9 * scale  # module global read by the clips
        obj = rest_object(variant, quads, skel)
        K.bake_vertex_ao(obj, distance=0.35, samples=32)
        K.export_glb(obj, models, variant, texcoords=True)
        bake_vat(variant, quads, skel, vat)
