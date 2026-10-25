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

import bmesh
import bpy

# Style 1.5 palette (sRGB hex). Survivors warm, zombies cool, walls warm plaster / brick / concrete.
PALETTE = {
    "plaster": "#ddb99d", "plaster_shade": "#c9b391", "brick": "#c06a4c", "concrete": "#a99e93",
    "concrete_dark": "#7f776f", "trim": "#e3d8c6", "roof": "#8d857c", "roof_slab": "#b3aa9e",
    "frame": "#e8e2d4", "glass": "#1c2329", "glass_dirty": "#2b343a", "lit": "#ffcf8a",
    "metal": "#7d868a", "metal_paint": "#cfc9b9", "tank": "#e6e0cf", "dark": "#14171a",
    "sand": "#c4a978", "sand_dark": "#a88f60", "wood": "#9c6b43", "door": "#b9a58a",
}

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


def reset(seed=1):
    random.seed(seed)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name in (SURFACE, EMISSIVE):
        if name not in bpy.data.materials:
            bpy.data.materials.new(name)


class MeshBuilder:
    """Accumulates boxes/cylinders into one bmesh with per-corner colours and material slots."""

    def __init__(self):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")

    def _face(self, verts, rgba, mat):
        f = self.bm.faces.new(verts)
        f.material_index = mat
        for loop in f.loops:
            loop[self.col] = rgba
        return f

    def box(self, center, size, col_name, mat=0, seg=0.0, yaw=0.0):
        """Axis-aligned (or yawed) box. seg > 0 splits faces into ~seg-metre quads so baked
        vertex AO has enough samples on big walls."""
        cx, cy, cz = center
        sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
        rgba = color(col_name)
        cs, sn = math.cos(yaw), math.sin(yaw)

        def P(x, y, z):
            return self.bm.verts.new((cx + x * cs - y * sn, cy + x * sn + y * cs, cz + z))

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
            grid = [[P(o[0] + u[0] * i / nu + v[0] * j / nv,
                       o[1] + u[1] * i / nu + v[1] * j / nv,
                       o[2] + u[2] * i / nu + v[2] * j / nv) for j in range(nv + 1)] for i in range(nu + 1)]
            for i in range(nu):
                for j in range(nv):
                    self._face((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]), rgba, mat)

    def cylinder(self, center, radius, height, col_name, segments=12, mat=0, radius_top=None):
        cx, cy, cz = center
        rt = radius if radius_top is None else radius_top
        rgba = color(col_name)
        bottom, top = [], []
        for k in range(segments):
            a = k / segments * math.tau
            bottom.append(self.bm.verts.new((cx + radius * math.cos(a), cy + radius * math.sin(a), cz - height / 2)))
            top.append(self.bm.verts.new((cx + rt * math.cos(a), cy + rt * math.sin(a), cz + height / 2)))
        for k in range(segments):
            n = (k + 1) % segments
            self._face((bottom[k], bottom[n], top[n], top[k]), rgba, mat)
        if rt > 0.001:
            self._face(top, rgba, mat)
        self._face(list(reversed(bottom)), rgba, mat)

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
