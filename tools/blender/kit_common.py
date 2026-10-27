"""Shared helpers for game-asset kits (Style 1.5).

Assets are flat-colour meshes: the palette colour lives in the vertex colour (RGB) and baked
ambient occlusion in its alpha, so one Godot shader (game/shaders/style15_surface.gdshader) draws a
whole building in a single draw call. Lit windows use a second material slot, "emissive".

Coordinates: Blender Z-up, metres. The glTF exporter converts to Godot Y-up (x, z, -y).
Run with the Blender in PATH or BLENDER env var, e.g.
    blender -b --factory-startup --python tools/blender/kit_building.py -- assets/models
"""
import math
import os
import random
import sys
from contextlib import contextmanager

import bmesh
import bpy

# Style 1.5 palette (sRGB hex). Survivors warm, zombies cool, walls warm plaster / brick / concrete.
PALETTE = {
    "plaster": "#ddb99d", "plaster_shade": "#c9b391", "brick": "#c06a4c", "concrete": "#a99e93",
    "concrete_dark": "#7f776f", "trim": "#e3d8c6", "roof": "#8d857c", "roof_slab": "#b3aa9e",
    "frame": "#e8e2d4", "glass": "#1c2329", "glass_dirty": "#2b343a", "lit": "#ffcf8a",
    "metal": "#7d868a", "metal_paint": "#cfc9b9", "tank": "#e6e0cf", "dark": "#14171a",
    "sand": "#c4a978", "sand_dark": "#a88f60", "wood": "#9c6b43", "door": "#b9a58a",
    # weathering / abandonment
    "plaster_bare": "#b49c86", "brick_bare": "#8e5a46", "concrete_stain": "#6f6a63", "interior": "#2c2a28",
    "void": "#0d0f10", "rubble": "#8f877e", "rebar": "#5b4637", "rust": "#7b4e33",
    "board": "#8a6c4f", "board_dark": "#64503d", "vine": "#62803c", "vine_dark": "#46622c", "moss": "#6f7f45",
    "puddle": "#958d82", "bark": "#4f4339", "tire": "#1d1e1f", "trash": "#25292b", "tarp": "#4b6672",
    "barrel_red": "#83382b", "barrel_blue": "#3a5266", "car": "#69767b", "styro": "#d8d5cc",
}

FRESH = {"vine", "vine_dark", "moss", "lit"}  # living / emissive colours skip MeshBuilder aging

SURFACE = "surface"    # material slot 0: vertex-colour Style 1.5 shader in Godot
EMISSIVE = "emissive"  # material slot 1: lit windows


def args():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def srgb_to_linear(hex_color):
    h = hex_color.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def color(name):
    return (*srgb_to_linear(PALETTE[name]), 1.0)


def aged(rgba, amount):
    """Desaturate and darken a linear colour: sun-bleached, grimy, unmaintained."""
    r, g, b, a = rgba
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    keep, dim = 1.0 - 0.4 * amount, 1.0 - 0.2 * amount
    return ((lum + (r - lum) * keep) * dim, (lum + (g - lum) * keep) * dim, (lum + (b - lum) * keep) * dim, a)


def hash01(*key):
    """Deterministic pseudo-random float in [0, 1) for a tuple of ints/strings."""
    return random.Random(",".join(str(k) for k in key)).random()


def value_noise(x, y, seed=0):
    """Smooth 2D value noise in [0, 1)."""
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    v00, v10 = hash01(ix, iy, seed), hash01(ix + 1, iy, seed)
    v01, v11 = hash01(ix, iy + 1, seed), hash01(ix + 1, iy + 1, seed)
    return (v00 * (1 - fx) + v10 * fx) * (1 - fy) + (v01 * (1 - fx) + v11 * fx) * fy


def rotation(rx=0.0, ry=0.0, rz=0.0):
    """3x3 rotation, applied X then Y then Z (radians)."""
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    rx_m = ((1, 0, 0), (0, cx, -sx), (0, sx, cx))
    ry_m = ((cy, 0, sy), (0, 1, 0), (-sy, 0, cy))
    rz_m = ((cz, -sz, 0), (sz, cz, 0), (0, 0, 1))
    return _matmul(rz_m, _matmul(ry_m, rx_m))


def _matmul(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def _matvec(m, v):
    return tuple(sum(m[i][k] * v[k] for k in range(3)) for i in range(3))


def reset(seed=1):
    random.seed(seed)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name in (SURFACE, EMISSIVE):
        if name not in bpy.data.materials:
            bpy.data.materials.new(name)


class MeshBuilder:
    """Accumulates boxes/cylinders into one bmesh with per-corner colours and material slots."""

    def __init__(self, aging=0.0):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.aging = aging  # 0..1, applied to every non-emissive colour
        self._rot = rotation()
        self._origin = (0.0, 0.0, 0.0)

    @contextmanager
    def transform(self, origin=(0.0, 0.0, 0.0), rot=(0.0, 0.0, 0.0)):
        """Nested local frame: primitives inside are rotated by rot, then moved to origin."""
        saved = self._rot, self._origin
        moved = _matvec(self._rot, origin)
        self._origin = tuple(moved[i] + saved[1][i] for i in range(3))
        self._rot = _matmul(self._rot, rotation(*rot))
        try:
            yield
        finally:
            self._rot, self._origin = saved

    def _vert(self, p):
        q = _matvec(self._rot, p)
        return self.bm.verts.new((q[0] + self._origin[0], q[1] + self._origin[1], q[2] + self._origin[2]))

    def _face(self, verts, rgba, mat, age=True):
        if self.aging > 0.0 and age:
            rgba = aged(rgba, self.aging)
        f = self.bm.faces.new(verts)
        f.material_index = mat
        for loop in f.loops:
            loop[self.col] = rgba
        return f

    def box(self, center, size, col_name, mat=0, seg=0.0, yaw=0.0, face_color=None):
        """Axis-aligned (or yawed) box in the current frame. seg > 0 splits faces into ~seg-metre quads
        so baked vertex AO has enough samples on big walls. face_color(centre, normal, rgba) -> rgba
        recolours individual quads (weathering) or returns None to leave the quad out; centre/normal are in
        model space."""
        cx, cy, cz = center
        sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
        rgba = color(col_name)
        cs, sn = math.cos(yaw), math.sin(yaw)

        def L(x, y, z):
            return (cx + x * cs - y * sn, cy + x * sn + y * cs, cz + z)

        # (origin, u axis, v axis) for each face, outward-facing winding
        faces = [
            ((-sx, -sy, -sz), (2 * sx, 0, 0), (0, 0, 2 * sz)),   # -Y
            ((sx, sy, -sz), (-2 * sx, 0, 0), (0, 0, 2 * sz)),    # +Y
            ((sx, -sy, -sz), (0, 2 * sy, 0), (0, 0, 2 * sz)),    # +X
            ((-sx, sy, -sz), (0, -2 * sy, 0), (0, 0, 2 * sz)),   # -X
            ((-sx, -sy, sz), (2 * sx, 0, 0), (0, 2 * sy, 0)),    # +Z
            ((-sx, sy, -sz), (2 * sx, 0, 0), (0, -2 * sy, 0)),   # -Z
        ]
        for o, u, v in faces:
            lu = math.sqrt(sum(a * a for a in u))
            lv = math.sqrt(sum(a * a for a in v))
            nu = max(1, math.ceil(lu / seg)) if seg > 0 else 1
            nv = max(1, math.ceil(lv / seg)) if seg > 0 else 1
            pts = [[L(o[0] + u[0] * i / nu + v[0] * j / nv,
                      o[1] + u[1] * i / nu + v[1] * j / nv,
                      o[2] + u[2] * i / nu + v[2] * j / nv) for j in range(nv + 1)] for i in range(nu + 1)]
            grid = [[self._vert(p) for p in row] for row in pts]
            n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
            ln = math.sqrt(sum(a * a for a in n))
            n = (n[0] / ln * cs - n[1] / ln * sn, n[0] / ln * sn + n[1] / ln * cs, n[2] / ln)
            for i in range(nu):
                for j in range(nv):
                    c = rgba
                    if face_color is not None:
                        q = [pts[i][j], pts[i + 1][j + 1]]
                        mid = _matvec(self._rot, tuple((q[0][k] + q[1][k]) / 2 for k in range(3)))
                        mid = tuple(mid[k] + self._origin[k] for k in range(3))
                        c = face_color(mid, _matvec(self._rot, n), rgba)
                        if c is None:  # quad cut away (e.g. a hole in a roof)
                            continue
                    self._face((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]), c, mat,
                               col_name not in FRESH)

    def cylinder(self, center, radius, height, col_name, segments=12, mat=0, radius_top=None):
        cx, cy, cz = center
        rt = radius if radius_top is None else radius_top
        rgba = color(col_name)
        bottom, top = [], []
        for k in range(segments):
            a = k / segments * math.tau
            bottom.append(self._vert((cx + radius * math.cos(a), cy + radius * math.sin(a), cz - height / 2)))
            top.append(self._vert((cx + rt * math.cos(a), cy + rt * math.sin(a), cz + height / 2)))
        for k in range(segments):
            n = (k + 1) % segments
            self._face((bottom[k], bottom[n], top[n], top[k]), rgba, mat, col_name not in FRESH)
        if rt > 0.001:
            self._face(top, rgba, mat, col_name not in FRESH)
        self._face(list(reversed(bottom)), rgba, mat, col_name not in FRESH)

    def to_object(self, name):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0001)
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        me.uv_layers.new(name="UVMap")  # Cycles bake requires one, even for vertex targets; not exported
        me.materials.append(bpy.data.materials[SURFACE])
        me.materials.append(bpy.data.materials[EMISSIVE])
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        for poly in me.polygons:
            poly.use_smooth = False
        return obj


def bake_vertex_ao(obj, distance=1.6, samples=64):
    """Cycles AO bake into a temporary colour attribute, then store it in Col.alpha."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.light_settings.distance = distance
    me = obj.data
    ao = me.color_attributes.new("AO", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = ao
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.scene.objects:
        o.select_set(o == obj)
    scene.render.bake.target = "VERTEX_COLORS"
    bpy.ops.object.bake(type="AO")
    col = me.color_attributes["Col"]
    for i, c in enumerate(col.data):
        a = ao.data[i].color[0]
        rgba = c.color
        c.color = (rgba[0], rgba[1], rgba[2], max(0.25, a))
    me.color_attributes.remove(ao)
    me.color_attributes.active_color = me.color_attributes["Col"]
    me.color_attributes.render_color_index = 0


def export_glb(obj, out_dir, name):
    os.makedirs(out_dir, exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(o == obj)
    bpy.context.view_layer.objects.active = obj
    path = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
        export_vertex_color="ACTIVE", export_normals=True, export_texcoords=False,
        export_materials="EXPORT", export_animations=False,
    )
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"exported {path}  ({tris} tris)")
    return path
