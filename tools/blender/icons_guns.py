"""Gun icons for the weapon panel (J bug list item 17) -> assets/ui/icons/gun_*.png

usage: blender -b --factory-startup --python tools/blender/icons_guns.py -- [models_dir] [out_dir]

Imports each gun_*.glb that kit_guns.py wrote and renders it from the right side with an orthographic camera:
muzzle to the right, a pale studio-lit silhouette on a transparent background, so it reads on the panel's dark
plate, with its loaded mag where GunView mounts it (not a pistol's: it is inside the grip). Every icon has the same pixels per metre, cropped to the gun, so a
pistol stays smaller than a rifle.
"""
import math
import os
import re
import sys

import bpy
from mathutils import Vector

GUNS = ["gun_pistol_9mm", "gun_ar_556", "gun_shotgun_12g", "gun_dmr_308"]
PX_PER_M = 300          # every gun at the same scale
PAD_PX = 6
COLOR = (0.86, 0.83, 0.77)  # bone white, the panel's ink


def args():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "SINGLE"
    sc.display.shading.single_color = COLOR
    sc.display.shading.show_cavity = True
    sc.display.shading.cavity_type = "WORLD"
    sc.display.shading.show_object_outline = True
    sc.display.shading.object_outline_color = (0.05, 0.05, 0.05)
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    return sc


def bounds(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        if o.type != "MESH":
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def mag_of(models, name):
    """(mag glb path, mount in Blender space) from the gun's GunModel .tres, as GunView puts it; None without."""
    tres = open(os.path.join(models, name + ".tres"), encoding="utf-8").read()
    scene = re.search(r'path="res://assets/models/(mag_[^"]+?\.glb)" id="3_mag"', tres)
    mount = re.search(r'"mag": Vector3\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)', tres)
    if not scene or not mount:
        return None
    x, y, z = (float(v) for v in mount.groups())
    return os.path.join(models, scene.group(1)), (x, -z, y)  # Godot (x, y, z) -> Blender (x, -z, y)


def render(models, out, name):
    sc = setup_scene()
    bpy.ops.import_scene.gltf(filepath=os.path.join(models, name + ".glb"))
    mag = None if "pistol" in name else mag_of(models, name)  # a pistol's mag sits inside the grip
    if mag:  # the loaded mag, where GunView mounts it
        before = set(sc.objects)
        bpy.ops.import_scene.gltf(filepath=mag[0])
        for o in set(sc.objects) - before:
            if o.parent is None:
                o.location = Vector(o.location) + Vector(mag[1])
        bpy.context.view_layer.update()
    objs = list(sc.objects)
    lo, hi = bounds(objs)
    centre = (lo + hi) / 2
    length = hi.y - lo.y  # the barrel runs along -Y (Godot +Z)
    width_px = int(length * PX_PER_M) + PAD_PX * 2
    height_px = int((hi.z - lo.z) * PX_PER_M) + PAD_PX * 2  # cropped to the gun: the panel fits it to a box
    sc.render.resolution_x = width_px
    sc.render.resolution_y = height_px
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(width_px, height_px) / PX_PER_M
    cam = bpy.data.objects.new("cam", cam_data)
    sc.collection.objects.link(cam)
    # from the gun's right side (-X), looking +X: -Y (the muzzle) is to the right of the frame
    cam.location = (centre.x - 5.0, centre.y, centre.z)
    cam.rotation_euler = (math.pi / 2, 0.0, -math.pi / 2)
    sc.camera = cam
    os.makedirs(out, exist_ok=True)
    sc.render.filepath = os.path.join(out, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("icon", name, width_px, "x", height_px)


if __name__ == "__main__":
    a = args()
    here = os.path.dirname(os.path.abspath(__file__))
    models = a[0] if a else os.path.join(here, "..", "..", "assets", "models")
    out = a[1] if len(a) > 1 else os.path.join(here, "..", "..", "assets", "ui", "icons")
    for g in GUNS:
        render(models, out, g)
