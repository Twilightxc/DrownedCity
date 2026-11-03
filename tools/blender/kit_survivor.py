"""Style 1.5 survivor body + skeleton + hand-keyed clips -> assets/models/survivor.glb

usage: blender -b --factory-startup --python tools/blender/kit_survivor.py -- [out_dir]

PHASE1 1.5+ A2. The same rigid-part figure as the zombies (kit_zombie.py: pelvis, torso, head, arms, legs, plus
two hands), but skinned to a real armature, because a survivor layers two clips at once: the legs walk, crouch
or crawl while the arms aim, reload or carry the gun (game/survivor_view.gd blends them with a bone filter).
≤ 6 survivors are on screen, so a Skeleton3D each is cheap; the horde keeps VAT.

Every bone points straight up at rest with no roll, so a bone's rest frame is the armature's: one rotation
convention for every part (same as kit_zombie): figure faces -Y (Godot +Z, the aim), right side is -X;
rx < 0 swings a hanging limb forward, rx > 0 leans the torso / pelvis / head forward, rx > 0 on a shin bends
the knee, rx < 0 on a forearm bends the elbow forward. Angles in radians.

Clips (24 fps). Lower body / full body: idle, walk, run, crouch_idle, crouch_walk, prone_idle, crawl, roll, downed.
Upper body (spine, head, arms, hands): aim_pistol, aim_rifle, carry_high (pistol / SMG sprint: high ready,
muzzle up), carry_port (long gun sprint: port arms, across the chest), reload_pistol, reload_rifle,
reload_shell. The gun hangs on hand_r; the game keeps it level in the aim pose (it measures the hand there).
Loop clips start and end on the same pose; the game sets their loop mode (LOOP_CLIPS below).
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_common as K  # noqa: E402

K.PALETTE.update({
    "surv_skin": "#e2a77c", "surv_jacket": "#c9652e", "surv_shirt": "#e6d3a8", "surv_pants": "#4f6178",
    "surv_boots": "#3d3027", "surv_hair": "#3b2a1e", "surv_pack": "#6f5b3a", "surv_strap": "#40362b",
})

FPS = 24
HIP_HEIGHT = 0.92

# bone: (parent, joint position relative to the parent's joint at rest)
SKELETON = {
    "pelvis": (None, (0.0, 0.0, HIP_HEIGHT)),
    "torso": ("pelvis", (0.0, 0.0, 0.09)),
    "head": ("torso", (0.0, 0.0, 0.52)),
    "arm_l": ("torso", (0.22, 0.0, 0.46)),
    "fore_l": ("arm_l", (0.0, 0.0, -0.29)),
    "hand_l": ("fore_l", (0.0, 0.0, -0.27)),
    "arm_r": ("torso", (-0.22, 0.0, 0.46)),
    "fore_r": ("arm_r", (0.0, 0.0, -0.29)),
    "hand_r": ("fore_r", (0.0, 0.0, -0.27)),
    "thigh_l": ("pelvis", (0.1, 0.0, -0.06)),
    "shin_l": ("thigh_l", (0.0, 0.0, -0.42)),
    "thigh_r": ("pelvis", (-0.1, 0.0, -0.06)),
    "shin_r": ("thigh_r", (0.0, 0.0, -0.42)),
}
UPPER = ["torso", "head", "arm_l", "fore_l", "hand_l", "arm_r", "fore_r", "hand_r"]  # survivor_view.gd agrees

BOXES = {  # bone: [(centre in the bone's frame, size, colour)]
    "pelvis": [((0, 0, 0.0), (0.34, 0.2, 0.2), "surv_pants"), ((0, 0, 0.08), (0.36, 0.22, 0.05), "surv_strap")],
    "torso": [((0, 0, 0.27), (0.4, 0.24, 0.5), "surv_jacket"), ((0, -0.123, 0.42), (0.14, 0.02, 0.12), "surv_shirt"),
              ((0, 0.17, 0.27), (0.3, 0.12, 0.36), "surv_pack"), ((0.1, -0.125, 0.3), (0.04, 0.02, 0.36), "surv_strap"),
              ((-0.1, -0.125, 0.3), (0.04, 0.02, 0.36), "surv_strap")],
    "head": [((0, -0.01, 0.15), (0.22, 0.24, 0.26), "surv_skin"), ((0, 0.02, 0.29), (0.235, 0.25, 0.06), "surv_hair"),
             ((0, 0.1, 0.19), (0.235, 0.06, 0.18), "surv_hair")],
    "thigh_l": [((0, 0, -0.21), (0.15, 0.16, 0.44), "surv_pants")],
    "thigh_r": [((0, 0, -0.21), (0.15, 0.16, 0.44), "surv_pants")],
    "shin_l": [((0, 0, -0.2), (0.13, 0.14, 0.42), "surv_pants"), ((0, -0.04, -0.41), (0.14, 0.25, 0.1), "surv_boots")],
    "shin_r": [((0, 0, -0.2), (0.13, 0.14, 0.42), "surv_pants"), ((0, -0.04, -0.41), (0.14, 0.25, 0.1), "surv_boots")],
}
for _s in "lr":
    BOXES[f"arm_{_s}"] = [((0, 0, -0.14), (0.1, 0.11, 0.3), "surv_jacket")]
    BOXES[f"fore_{_s}"] = [((0, 0, -0.1), (0.095, 0.1, 0.2), "surv_jacket"), ((0, 0, -0.23), (0.08, 0.085, 0.08), "surv_skin")]
    BOXES[f"hand_{_s}"] = [((0, -0.005, -0.045), (0.075, 0.09, 0.09), "surv_skin")]


def rest_positions():
    out = {}
    for bone, (parent, j) in SKELETON.items():
        base = out[parent] if parent else Vector((0, 0, 0))
        out[bone] = base + Vector(j)
    return out


# ---- clips: phase u in [0, 1) -> ({bone: (rx, ry, rz)}, pelvis offset) ------------------------------

def _ease(a, b, u):
    u = max(0.0, min(1.0, u))
    u = u * u * (3 - 2 * u)
    return a + (b - a) * u


def _keys(keys, u):
    """Piecewise-eased value from [(u, value), ...]."""
    for (u0, v0), (u1, v1) in zip(keys, keys[1:]):
        if u <= u1:
            return _ease(v0, v1, (u - u0) / max(1e-6, u1 - u0))
    return keys[-1][1]


def _arms_down(p, swing=0.0):
    p["arm_l"] = (swing, 0.0, -0.06)
    p["arm_r"] = (-swing, 0.0, 0.06)
    p["fore_l"] = (-0.2, 0.0, 0.0)
    p["fore_r"] = (-0.2, 0.0, 0.0)


def _legs(p, t, thigh, knee, lift=0.0):
    p["thigh_l"] = (-thigh * math.sin(t) - lift, 0.0, 0.0)
    p["thigh_r"] = (thigh * math.sin(t) - lift, 0.0, 0.0)
    p["shin_l"] = (knee * max(0.0, math.sin(t + 1.3)) + lift * 1.3, 0.0, 0.0)
    p["shin_r"] = (knee * max(0.0, math.sin(t + math.pi + 1.3)) + lift * 1.3, 0.0, 0.0)


def idle(u):
    t = u * math.tau
    p = {"torso": (0.02 + 0.015 * math.sin(t), 0.0, 0.0), "head": (0.0, 0.0, 0.03 * math.sin(t))}
    p["thigh_l"] = (0.0, 0.0, 0.04)
    p["thigh_r"] = (0.0, 0.0, -0.04)
    _arms_down(p)
    return p, (0, 0, -0.005 + 0.005 * math.sin(t))


def walk(u):
    t = u * math.tau
    p = {"pelvis": (0.0, 0.0, 0.08 * math.sin(t)), "torso": (0.05, 0.0, -0.08 * math.sin(t))}
    _legs(p, t, 0.45, 0.8)
    _arms_down(p, 0.3 * math.sin(t))
    return p, (0, 0, -0.02 + 0.02 * abs(math.cos(t)))


def run(u):
    t = u * math.tau
    p = {"pelvis": (0.1, 0.0, 0.1 * math.sin(t)), "torso": (0.2, 0.0, -0.12 * math.sin(t)), "head": (-0.15, 0, 0)}
    _legs(p, t, 0.75, 1.5, lift=0.15)
    _arms_down(p, 0.6 * math.sin(t))
    p["fore_l"] = p["fore_r"] = (-1.2, 0.0, 0.0)
    return p, (0, 0, -0.06 + 0.05 * abs(math.cos(t)))


CROUCH_DROP = 0.34


def _crouch(p, sway=0.0):
    p["pelvis"] = (0.05, 0.0, 0.0)
    p["torso"] = (0.3 + sway, 0.0, 0.0)
    p["head"] = (-0.25, 0.0, 0.0)
    p["thigh_l"] = (-1.45, 0.0, 0.1)
    p["thigh_r"] = (-1.1, 0.0, -0.1)
    p["shin_l"] = (1.9, 0.0, 0.0)
    p["shin_r"] = (2.2, 0.0, 0.0)


def crouch_idle(u):
    t = u * math.tau
    p = {}
    _crouch(p, 0.02 * math.sin(t))
    _arms_down(p)
    return p, (0, 0, -CROUCH_DROP)


def crouch_walk(u):
    t = u * math.tau
    p = {}
    _crouch(p)
    p["thigh_l"] = (-1.3 - 0.35 * math.sin(t), 0.0, 0.1)
    p["thigh_r"] = (-1.3 + 0.35 * math.sin(t), 0.0, -0.1)
    p["shin_l"] = (2.0 + 0.3 * max(0.0, math.sin(t + 1.3)), 0.0, 0.0)
    p["shin_r"] = (2.0 + 0.3 * max(0.0, math.sin(t + math.pi + 1.3)), 0.0, 0.0)
    _arms_down(p, 0.15 * math.sin(t))
    return p, (0, 0, -CROUCH_DROP + 0.02 * abs(math.cos(t)))


PRONE_HIP = 0.16


def _prone(p, t=0.0, crawl=0.0):
    """Face down, head toward the aim, both hands forward on the gun."""
    p["pelvis"] = (math.pi / 2, 0.0, 0.05 * crawl * math.sin(t))
    p["torso"] = (-0.12, 0.0, 0.08 * crawl * math.sin(t))
    p["head"] = (-0.9, 0.0, 0.0)  # looks ahead along the ground
    p["thigh_l"] = (0.0, 0.0, 0.18 + 0.4 * crawl * max(0.0, math.sin(t)))
    p["thigh_r"] = (0.0, 0.0, -0.18 - 0.4 * crawl * max(0.0, -math.sin(t)))
    p["shin_l"] = (0.9 * crawl * max(0.0, math.sin(t)), 0.0, 0.0)
    p["shin_r"] = (0.9 * crawl * max(0.0, -math.sin(t)), 0.0, 0.0)
    p["arm_l"] = (-2.6 - 0.3 * crawl * math.sin(t), 0.0, -0.3)
    p["arm_r"] = (-2.7 + 0.3 * crawl * math.sin(t), 0.0, 0.25)
    p["fore_l"] = (-0.5, 0.0, 0.0)
    p["fore_r"] = (-0.6, 0.0, 0.0)


def prone_idle(u):
    p = {}
    _prone(p)
    return p, (0, 0, PRONE_HIP - HIP_HEIGHT)


def crawl(u):
    t = u * math.tau
    p = {}
    _prone(p, t, 1.0)
    return p, (0, 0, PRONE_HIP - HIP_HEIGHT + 0.02 * abs(math.sin(t)))


def roll(u):
    """Dive forward and tuck over the shoulder; one-shot, the game moves the body."""
    spin = _keys([(0.0, 0.0), (0.15, 0.5), (0.85, math.tau - 0.4), (1.0, math.tau)], u)
    tuck = _keys([(0.0, 0.0), (0.2, 1.0), (0.75, 1.0), (1.0, 0.0)], u)
    p = {"pelvis": (spin, 0.0, 0.0), "torso": (0.7 * tuck, 0.0, 0.0), "head": (0.6 * tuck, 0.0, 0.0)}
    for s, sign in (("l", 1.0), ("r", -1.0)):
        p[f"thigh_{s}"] = (-1.8 * tuck, 0.0, 0.08 * sign)
        p[f"shin_{s}"] = (2.2 * tuck, 0.0, 0.0)
        p[f"arm_{s}"] = (-1.0 * tuck, 0.0, -0.2 * sign * tuck)
        p[f"fore_{s}"] = (-1.6 * tuck, 0.0, 0.0)
    drop = _keys([(0.0, 0.0), (0.3, -0.5), (0.7, -0.5), (1.0, 0.0)], u)
    return p, (0, 0, drop)


def downed(u):
    """Down on the back, propped on one elbow, a hand pressed to the wound."""
    t = u * math.tau
    p = {"pelvis": (-1.35, 0.0, 0.1), "torso": (0.55 + 0.03 * math.sin(t), 0.0, -0.1), "head": (0.35, 0.0, 0.0)}
    p["thigh_l"] = (-0.5, 0.0, 0.15)
    p["shin_l"] = (0.9, 0.0, 0.0)
    p["thigh_r"] = (-0.1, 0.0, -0.1)
    p["shin_r"] = (0.2, 0.0, 0.0)
    p["arm_l"] = (0.6, 0.0, -0.3)
    p["fore_l"] = (-1.4, 0.0, 0.0)
    p["arm_r"] = (-0.6, 0.0, 0.4)
    p["fore_r"] = (-1.9, 0.0, 0.3)
    return p, (0, 0, 0.22 - HIP_HEIGHT + 0.01 * math.sin(t))


# Upper body: only UPPER bones matter (the game filters them onto the legs' clip).

def _aim_pistol(p, lower=0.0):
    p["torso"] = (0.04, 0.0, 0.0)
    p["head"] = (0.0, 0.0, 0.0)
    p["arm_r"] = (-1.4 + lower, 0.0, 0.4)  # turned in: the hands meet on the centre line
    p["fore_r"] = (-0.2, 0.0, 0.0)
    p["hand_r"] = (0.0, 0.0, 0.0)
    p["arm_l"] = (-1.35 + lower, 0.0, 0.42)
    p["fore_l"] = (-0.25, 0.0, 0.25)
    p["hand_l"] = (0.0, 0.0, 0.0)


def _aim_rifle(p, lower=0.0):
    p["torso"] = (0.06, 0.0, -0.25)  # bladed: left shoulder toward the aim
    p["head"] = (0.05, 0.0, 0.2)
    p["arm_r"] = (-0.3 + lower, 0.0, 0.45)  # elbow out and down, grip hand at the chest, stock in the shoulder
    p["fore_r"] = (-1.6, 0.0, 0.35)
    p["hand_r"] = (0.0, 0.0, 0.0)
    p["arm_l"] = (-1.35 + lower, 0.0, 0.2)
    p["fore_l"] = (-0.2, 0.0, 0.35)
    p["hand_l"] = (0.0, 0.0, 0.0)


def aim_pistol(u):
    p = {}
    _aim_pistol(p, 0.02 * math.sin(u * math.tau))
    return p, (0, 0, 0)


def aim_rifle(u):
    p = {}
    _aim_rifle(p, 0.02 * math.sin(u * math.tau))
    return p, (0, 0, 0)


def carry_high(u):
    """High ready: elbows in, both hands at the chin, forearms up, muzzle to the sky (J 2026-11-03)."""
    t = u * math.tau
    p = {"torso": (0.15, 0.0, 0.0), "head": (-0.1, 0.0, 0.0)}
    p["arm_r"] = (-0.35 + 0.05 * math.sin(t), 0.0, -0.15)
    p["fore_r"] = (-2.3, 0.0, 0.25)
    p["hand_r"] = (0.0, 0.0, 0.0)
    p["arm_l"] = (-0.4 + 0.05 * math.sin(t), 0.0, 0.25)
    p["fore_l"] = (-2.2, 0.0, -0.45)
    p["hand_l"] = (0.0, 0.0, 0.0)
    return p, (0, 0, 0)


def carry_port(u):
    """Port arms: the long gun across the chest, right hand low at the grip, left hand high on the
    handguard, military style (J 2026-11-03)."""
    t = u * math.tau
    p = {"torso": (0.15, 0.0, 0.0), "head": (-0.1, 0.0, 0.0)}
    p["arm_r"] = (-0.25 + 0.05 * math.sin(t), 0.0, 0.1)
    p["fore_r"] = (-1.6, 0.0, -0.75)
    p["hand_r"] = (0.0, 0.0, 0.0)
    p["arm_l"] = (-0.6 + 0.05 * math.sin(t), 0.0, 0.35)
    p["fore_l"] = (-1.9, 0.0, -0.3)
    p["hand_l"] = (0.0, 0.0, 0.0)
    return p, (0, 0, 0)


def reload_pistol(u):
    """Gun tilts in, left hand drops to the belt for a mag and slaps it home."""
    p = {}
    _aim_pistol(p)
    tilt = _keys([(0.0, 0.0), (0.15, 0.6), (0.85, 0.6), (1.0, 0.0)], u)
    p["arm_r"] = (-1.4 + tilt, 0.0, 0.4 + 0.3 * tilt)
    p["fore_r"] = (-0.2 - 0.6 * tilt, 0.0, 0.0)
    reach = _keys([(0.0, 0.0), (0.2, 0.0), (0.4, 1.0), (0.6, 1.0), (0.8, 0.0), (1.0, 0.0)], u)
    p["arm_l"] = (_ease(-1.35, 0.25, reach), 0.0, _ease(0.42, -0.05, reach))
    p["fore_l"] = (_ease(-0.25, -0.5, reach), 0.0, _ease(0.25, 0.0, reach))
    return p, (0, 0, 0)


def reload_rifle(u):
    """Mag out, left hand to the vest pouch, new mag in, slap the charging handle."""
    p = {}
    _aim_rifle(p)
    tilt = _keys([(0.0, 0.0), (0.1, 0.45), (0.9, 0.45), (1.0, 0.0)], u)
    p["arm_r"] = (-0.3 + tilt, 0.0, 0.45)
    p["fore_r"] = (-1.6 - 0.3 * tilt, 0.0, 0.35)
    p["torso"] = (0.06 + 0.15 * tilt, 0.0, -0.25)
    reach = _keys([(0.0, 0.0), (0.15, 0.0), (0.35, 1.0), (0.55, 1.0), (0.75, 0.0), (0.85, 0.0), (0.92, 0.4),
                   (1.0, 0.0)], u)
    p["arm_l"] = (_ease(-1.35, -0.3, reach), 0.0, _ease(0.2, 0.05, reach))
    p["fore_l"] = (_ease(-0.2, -1.5, reach), 0.0, _ease(0.35, 0.0, reach))
    return p, (0, 0, 0)


def reload_shell(u):
    """One shell: left hand down to the belt, up under the receiver, push it in. Loops per shell."""
    p = {}
    _aim_rifle(p)
    p["arm_r"] = (-0.5, 0.0, 0.35)
    reach = _keys([(0.0, 0.0), (0.35, 1.0), (0.7, 0.0), (1.0, 0.0)], u)
    p["arm_l"] = (_ease(-0.9, 0.0, reach), 0.0, _ease(0.3, 0.0, reach))
    p["fore_l"] = (_ease(-0.8, -0.6, reach), 0.0, 0.0)
    return p, (0, 0, 0)


# name: (function, frames, loop)
CLIPS = {
    "idle": (idle, 48, True), "walk": (walk, 24, True), "run": (run, 16, True),
    "crouch_idle": (crouch_idle, 48, True), "crouch_walk": (crouch_walk, 28, True),
    "prone_idle": (prone_idle, 48, True), "crawl": (crawl, 32, True), "roll": (roll, 14, False),
    "downed": (downed, 48, True),
    "aim_pistol": (aim_pistol, 48, True), "aim_rifle": (aim_rifle, 48, True),
    "carry_high": (carry_high, 16, True), "carry_port": (carry_port, 16, True),
    "reload_pistol": (reload_pistol, 29, False), "reload_rifle": (reload_rifle, 58, False),
    "reload_shell": (reload_shell, 12, True),
}
LOOP_CLIPS = [n for n, (_, _, loop) in CLIPS.items() if loop]
WALK_SPEED = 1.4  # m/s the walk clip's stride matches at 1× (survivor_view.gd scales the clip by speed)
RUN_SPEED = 4.2
CRAWL_SPEED = 0.6


# ---- build ---------------------------------------------------------------------------------------

def build_mesh(rest):
    parts = []
    for bone, boxes in BOXES.items():
        mb = K.MeshBuilder(aging=0.0)
        with mb.transform(tuple(rest[bone])):
            for c, s, col in boxes:
                mb.box(c, s, col)
        obj = mb.to_object("part_" + bone)
        vg = obj.vertex_groups.new(name=bone)
        vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
        parts.append(obj)
    for o in bpy.context.scene.objects:
        o.select_set(o in parts)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = body.data.name = "survivor"
    return body


def build_armature(rest):
    arm_data = bpy.data.armatures.new("survivor_rig")
    rig = bpy.data.objects.new("survivor_rig", arm_data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for bone, (parent, _) in SKELETON.items():
        eb = arm_data.edit_bones.new(bone)
        eb.head = rest[bone]
        eb.tail = rest[bone] + Vector((0, 0, 0.08))  # straight up, no roll: rest frame = armature frame
        eb.roll = 0.0
        if parent:
            eb.parent = arm_data.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def bake_clips(rig):
    rig.animation_data_create()
    rest_rot = {b.name: b.matrix_local.to_3x3() for b in rig.data.bones}
    for name, (fn, frames, loop) in CLIPS.items():
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        rig.animation_data.action = action
        prev = {}
        last = frames if loop else frames - 1
        for f in range(last + 1):
            u = (f / frames) if loop else (f / max(1, frames - 1))
            pose, root = fn(u % 1.0 if loop else u)
            for bone in SKELETON:
                pb = rig.pose.bones[bone]
                pb.rotation_mode = "QUATERNION"
                r = rest_rot[bone]
                q_arm = Euler(pose.get(bone, (0.0, 0.0, 0.0)), "XYZ").to_quaternion()
                q = (r.inverted() @ q_arm.to_matrix() @ r).to_quaternion()
                if bone in prev:
                    q.make_compatible(prev[bone])
                prev[bone] = q
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=f)
                if bone == "pelvis":
                    pb.location = r.inverted() @ Vector(root)
                    pb.keyframe_insert("location", frame=f)
        action.frame_range = (0, last)
    rig.animation_data.action = None


if __name__ == "__main__":
    a = K.args()
    out = a[0] if a else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")
    K.reset(23)
    bpy.context.scene.render.fps = FPS
    rest = rest_positions()
    body = build_mesh(rest)
    K.bake_vertex_ao(body, distance=0.25, samples=32)
    rig = build_armature(rest)
    body.parent = rig
    mod = body.modifiers.new("rig", "ARMATURE")
    mod.object = rig
    bake_clips(rig)
    os.makedirs(out, exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(o in (body, rig))
    bpy.context.view_layer.objects.active = rig
    path = os.path.join(out, "survivor.glb")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_vertex_color="ACTIVE", export_normals=True, export_texcoords=False, export_materials="EXPORT",
        export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
        export_skins=True, export_def_bones=False, export_optimize_animation_size=False,
    )
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print(f"exported {path}  ({tris} tris, {len(CLIPS)} clips, loops: {', '.join(LOOP_CLIPS)})")
