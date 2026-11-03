"""Style 1.5 guns and gun attachments -> assets/models/gun_*.glb, att_*.glb + assets/models/gun_*.tres

usage: blender -b --factory-startup --python tools/blender/kit_guns.py -- [out_dir] [names...]

The four demo guns (one per class, PHASE1 1.1) and the four demo attachments. Low-poly boxes and
cylinders, dark metal and polymer with wood on the shotgun and DMR, so a gun reads as a dark silhouette
against a warm survivor.

Coordinates (Blender, before export): the barrel points along -Y (Godot +Z, the aim direction of the
player's AimMarker), up is +Z, the origin is where the right hand holds the grip. Everything is built at
real size and scaled by SCALE so the guns read from the isometric camera.

Each gun also gets a GunModel .tres: its muzzle, where the left hand holds it (support), and one mount point per
attachment slot (muzzle = the muzzle, optic, under, mag) in Godot space. An attachment's origin is its mount point: the silencer starts at the muzzle
and runs forward, the red dot sits on the top rail, the flashlight hangs under the barrel, the extended
mag hangs from the mag well over the standard mag.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_common as K  # noqa: E402
from mathutils import Matrix  # noqa: E402

SCALE = 1.3  # readable from the iso camera; the character is 1.6 m

K.PALETTE.update({
    "gun_black": "#6a7075", "gun_dark": "#868d92", "polymer": "#5f6468", "steel": "#b6bec2",
    "gun_wood": "#9a6438", "gun_wood_dark": "#784c2c", "lens": "#3d7480",
})

SILENCER_LENGTH = 0.17  # m before SCALE: the muzzle flash moves this far forward


def barrel(mb, y0, y1, z, radius, col, segments=8):
    """A cylinder along -Y from y0 to y1 (y1 < y0) at height z."""
    with mb.transform((0.0, (y0 + y1) / 2, z), (math.pi / 2, 0.0, 0.0)):
        mb.cylinder((0, 0, 0), radius, abs(y0 - y1), col, segments=segments)


def pistol(mb):
    mb.box((0, -0.06, 0.035), (0.03, 0.19, 0.035), "gun_black")          # slide
    mb.box((0, -0.05, 0.006), (0.028, 0.15, 0.024), "polymer")           # frame
    mb.box((0, -0.035, -0.012), (0.012, 0.035, 0.012), "polymer")        # trigger guard
    with mb.transform((0, 0.012, -0.005), (-0.3, 0.0, 0.0)):
        mb.box((0, 0, -0.05), (0.03, 0.045, 0.1), "polymer")             # grip, raked back
    return {"muzzle": (0, -0.155, 0.035), "optic": (0, -0.03, 0.0525), "under": (0, -0.1, -0.006),
            "support": (0.03, -0.005, -0.05)}  # the left hand cups the right on the grip


def ar(mb):
    mb.box((0, -0.05, 0.02), (0.042, 0.26, 0.07), "gun_dark")            # receiver
    mb.box((0, -0.15, 0.062), (0.026, 0.42, 0.014), "gun_black")         # top rail
    mb.box((0, -0.32, 0.024), (0.048, 0.3, 0.052), "gun_black")          # handguard
    barrel(mb, -0.47, -0.6, 0.026, 0.009, "steel")
    mb.box((0, -0.6, 0.026), (0.02, 0.03, 0.02), "gun_black")            # flash hider
    mb.box((0, -0.44, 0.068), (0.012, 0.012, 0.045), "gun_black")        # front sight
    barrel(mb, 0.2, 0.08, 0.035, 0.016, "gun_black")                     # buffer tube
    mb.box((0, 0.22, 0.012), (0.036, 0.14, 0.075), "polymer")            # stock
    with mb.transform((0, 0.03, -0.01), (-0.35, 0.0, 0.0)):
        mb.box((0, 0, -0.04), (0.03, 0.035, 0.08), "polymer")            # pistol grip
    with mb.transform((0, -0.1, -0.015), (0.18, 0.0, 0.0)):
        mb.box((0, 0, -0.06), (0.026, 0.06, 0.12), "gun_dark")           # 30-round mag
    return {"muzzle": (0, -0.615, 0.026), "optic": (0, -0.1, 0.069), "under": (0, -0.34, -0.002),
            "mag": (0, -0.1, -0.015), "support": (0, -0.28, -0.005)}  # under the handguard


def shotgun(mb):
    mb.box((0, -0.05, 0.02), (0.046, 0.22, 0.065), "gun_black")          # receiver
    barrel(mb, -0.16, -0.72, 0.04, 0.012, "gun_dark")
    barrel(mb, -0.16, -0.6, 0.012, 0.011, "gun_black")                   # tube magazine
    mb.box((0, -0.33, 0.012), (0.046, 0.16, 0.04), "gun_wood")           # pump
    mb.box((0, 0.03, -0.012), (0.012, 0.05, 0.012), "gun_black")         # trigger guard
    with mb.transform((0, 0.06, 0.01), (0.12, 0.0, 0.0)):
        mb.box((0, 0.03, -0.015), (0.036, 0.08, 0.05), "gun_wood_dark")  # wrist
        mb.box((0, 0.2, -0.03), (0.04, 0.26, 0.075), "gun_wood")         # stock
    return {"muzzle": (0, -0.72, 0.04), "optic": (0, -0.05, 0.0525), "under": (0, -0.64, 0.016),
            "support": (0, -0.27, -0.01)}  # on the back of the pump


def dmr(mb):
    mb.box((0, -0.12, 0.0), (0.046, 0.66, 0.055), "gun_wood")            # wooden stock and fore-end
    with mb.transform((0, 0.2, 0.0), (0.1, 0.0, 0.0)):
        mb.box((0, 0.1, -0.035), (0.046, 0.2, 0.1), "gun_wood")          # butt
    mb.box((0, -0.04, 0.04), (0.036, 0.22, 0.03), "gun_dark")            # receiver
    mb.box((0, -0.3, 0.043), (0.03, 0.24, 0.022), "gun_black")           # handguard
    barrel(mb, -0.45, -0.73, 0.036, 0.01, "gun_dark")
    mb.box((0, -0.73, 0.036), (0.024, 0.035, 0.024), "gun_black")        # muzzle brake
    mb.box((0, 0.04, -0.03), (0.012, 0.045, 0.012), "gun_black")         # trigger guard
    with mb.transform((0, -0.08, -0.028), (0.08, 0.0, 0.0)):
        mb.box((0, 0, -0.045), (0.026, 0.07, 0.09), "gun_dark")          # 20-round mag
    return {"muzzle": (0, -0.75, 0.036), "optic": (0, -0.05, 0.055), "under": (0, -0.4, -0.028),
            "mag": (0, -0.08, -0.028), "support": (0, -0.25, -0.03)}  # under the fore-end


def silencer(mb):
    barrel(mb, 0.0, -SILENCER_LENGTH, 0.0, 0.02, "gun_black", segments=10)
    return {}


def red_dot(mb):
    mb.box((0, 0, 0.008), (0.026, 0.055, 0.016), "gun_black")            # mount
    mb.box((0, 0, 0.033), (0.032, 0.045, 0.034), "gun_dark")             # housing
    mb.box((0, -0.0235, 0.035), (0.02, 0.002, 0.02), "lens")
    return {}


def extended_mag(mb):
    with mb.transform((0, 0, 0), (0.18, 0.0, 0.0)):
        mb.box((0, 0, -0.1), (0.028, 0.065, 0.2), "gun_dark")
        mb.box((0, 0, -0.205), (0.034, 0.07, 0.012), "gun_black")        # base plate
    return {}


def flashlight(mb):
    mb.box((0, -0.05, -0.004), (0.016, 0.035, 0.01), "gun_black")        # rail clamp
    barrel(mb, -0.0, -0.1, -0.022, 0.016, "gun_dark", segments=10)
    mb.box((0, -0.1015, -0.022), (0.022, 0.003, 0.022), "lit", mat=1)    # lens, lit
    return {}


GUNS = [("gun_pistol_9mm", pistol), ("gun_ar_556", ar), ("gun_shotgun_12g", shotgun), ("gun_dmr_308", dmr)]
ATTACHMENTS = [("att_silencer", silencer), ("att_red_dot", red_dot), ("att_extended_mag", extended_mag),
               ("att_flashlight", flashlight)]


def godot_vec(p):
    """Blender Z-up point (before SCALE) -> Godot Y-up after the glTF export."""
    x, y, z = (c * SCALE for c in p)
    return f"Vector3({x:.4f}, {z:.4f}, {-y:.4f})"


def write_gun_model(out_dir, name, points):
    mounts = ", ".join(f'"{k}": {godot_vec(v)}' for k, v in points.items() if k != "support")
    with open(os.path.join(out_dir, name + ".tres"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write('[gd_resource type="Resource" script_class="GunModel" load_steps=3 format=3]\n\n'
                 '[ext_resource type="Script" path="res://combat/gun_model.gd" id="1_model"]\n'
                 f'[ext_resource type="PackedScene" path="res://assets/models/{name}.glb" id="2_mesh"]\n\n'
                 '[resource]\nscript = ExtResource("1_model")\nmesh_scene = ExtResource("2_mesh")\n'
                 f'muzzle = {godot_vec(points["muzzle"])}\n'
                 f'support = {godot_vec(points["support"])}\n'
                 f'mounts = Dictionary[String, Vector3]({{{mounts}}})\n')


if __name__ == "__main__":
    a = K.args()
    out = a[0] if a else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")
    only = set(a[1:])
    for name, fn in GUNS + ATTACHMENTS:
        if only and name not in only:
            continue
        K.reset(17)
        mb = K.MeshBuilder(aging=0.15)
        points = fn(mb)
        obj = mb.to_object(name)
        obj.data.transform(Matrix.Scale(SCALE, 4))
        K.bake_vertex_ao(obj, distance=0.06, samples=32)
        K.export_glb(obj, out, name)
        if points:
            write_gun_model(out, name, points)
    print(f"silencer extends the muzzle by {SILENCER_LENGTH * SCALE:.4f} m")
