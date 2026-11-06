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

Clips (24 fps). Lower body / full body: idle, walk_f / b, run, crouch_idle, crouch_f / b, prone_idle, crawl, roll,
downed. Moving sideways the game turns the hips to the travel and twists the torso back to the aim (HipTwist), so
the legs only ever walk forward or backward.
Upper body (spine, head, arms, hands): aim_pistol, aim_rifle, carry_high (pistol / SMG sprint: high ready,
muzzle up), carry_port (long gun sprint: port arms, across the chest), reload_pistol, reload_rifle,
reload_shell. The gun hangs on hand_r; the game keeps it level in the aim pose (it measures the hand there).
Loop clips start and end on the same pose; the game sets their loop mode (LOOP_CLIPS below).
survivor.glb.import keeps generate_lods and create_shadow_meshes off: with them on, the Compatibility renderer
drew no shadow at all for the skinned body.
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
    # look 1: mustard work jacket, brown cargo pants, cap, beard
    "surv1_jacket": "#c99a2e", "surv1_pants": "#6a5038", "surv1_cap": "#36464f", "surv1_skin": "#c68a62",
    "surv1_beard": "#2e241c", "surv1_rig": "#3c3a2e",
    # look 2: red hoodie, charcoal pants, auburn ponytail, sling bag
    "surv2_hoodie": "#b0363d", "surv2_pants": "#3a3d44", "surv2_hair": "#8a4a26", "surv2_skin": "#efbf9a",
    "surv2_bag": "#5b4a3a",
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


def boxes_for(look):
    """A look's boxes: the same parts on the same bones, other clothes (J 2026-11-04: no two alike). All stay
    warm so survivors read against the cool, bleached city."""
    b = {k: list(v) for k, v in BOXES.items()}
    if look == 1:
        recol = {"surv_jacket": "surv1_jacket", "surv_pants": "surv1_pants", "surv_skin": "surv1_skin"}
        b = {k: [(c, sz, recol.get(col, col)) for c, sz, col in v] for k, v in b.items()}
        b["torso"] = [((0, 0, 0.27), (0.42, 0.25, 0.5), "surv1_jacket"), ((0, -0.128, 0.28), (0.3, 0.03, 0.22), "surv1_rig"),
                      ((0.09, -0.142, 0.24), (0.08, 0.02, 0.08), "surv_strap"), ((-0.09, -0.142, 0.24), (0.08, 0.02, 0.08), "surv_strap")]
        b["head"] = [((0, -0.01, 0.15), (0.22, 0.24, 0.26), "surv1_skin"), ((0, -0.02, 0.05), (0.2, 0.2, 0.1), "surv1_beard"),
                     ((0, 0.01, 0.29), (0.25, 0.26, 0.07), "surv1_cap"), ((0, -0.15, 0.27), (0.22, 0.08, 0.025), "surv1_cap")]
    elif look == 2:
        recol = {"surv_jacket": "surv2_hoodie", "surv_pants": "surv2_pants", "surv_skin": "surv2_skin"}
        b = {k: [(c, sz, recol.get(col, col)) for c, sz, col in v] for k, v in b.items()}
        b["torso"] = [((0, 0, 0.27), (0.36, 0.23, 0.5), "surv2_hoodie"), ((0, 0.13, 0.46), (0.22, 0.06, 0.12), "surv2_hoodie"),
                      ((0.12, 0.13, 0.14), (0.16, 0.08, 0.18), "surv2_bag"), ((0.05, -0.118, 0.3), (0.04, 0.02, 0.4), "surv_strap")]
        b["head"] = [((0, -0.01, 0.15), (0.21, 0.23, 0.25), "surv2_skin"), ((0, 0.02, 0.28), (0.225, 0.245, 0.06), "surv2_hair"),
                     ((0, 0.1, 0.19), (0.225, 0.06, 0.18), "surv2_hair"), ((0, 0.15, 0.1), (0.07, 0.06, 0.18), "surv2_hair")]
    return b


LOOKS = 3  # survivor.glb holds survivor_0 .. survivor_2, one skeleton and one set of clips for all


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
    # Shooting stance (J 2026-11-03): left foot ahead, right foot a step back and turned out, knees soft.
    p["thigh_l"] = (-0.14, 0.0, 0.05)
    p["shin_l"] = (0.12, 0.0, 0.0)
    p["thigh_r"] = (0.3, 0.0, -0.35)
    p["shin_r"] = (0.18, 0.0, 0.0)
    _arms_down(p)
    return p, (0, 0, -0.03 + 0.005 * math.sin(t))


def walk(u):
    """The game's walk is brisk (4.5 m/s, a light jog): long strides, a clear knee lift, some bounce."""
    t = u * math.tau
    p = {"pelvis": (0.06, 0.0, 0.1 * math.sin(t)), "torso": (0.08, 0.0, -0.1 * math.sin(t))}
    _legs(p, t, 0.6, 1.15, lift=0.05)
    _arms_down(p, 0.3 * math.sin(t))
    return p, (0, 0, -0.02 + 0.02 * abs(math.cos(t)))


def run(u):
    t = u * math.tau
    p = {"pelvis": (0.1, 0.0, 0.1 * math.sin(t)), "torso": (0.2, 0.0, -0.12 * math.sin(t)), "head": (-0.15, 0, 0)}
    _legs(p, t, 0.75, 1.5, lift=0.15)
    _arms_down(p, 0.6 * math.sin(t))
    p["fore_l"] = p["fore_r"] = (-1.2, 0.0, 0.0)
    return p, (0, 0, -0.06 + 0.05 * abs(math.cos(t)))


def walk_b(u):
    """Backing away: the forward walk played in reverse."""
    return walk(1.0 - u)


CROUCH_DROP = 0.34  # squat (crouch walk)
KNEEL_HIP = 0.5    # kneeling: the right knee on the ground


def _kneel(p, sway=0.0):
    """Kneeling to shoot (J 2026-11-03): right knee on the floor, shin flat behind; left foot planted ahead,
    knee up."""
    p["pelvis"] = (0.0, 0.0, 0.0)
    p["torso"] = (0.12 + sway, 0.0, 0.0)
    p["head"] = (-0.1, 0.0, 0.0)
    p["thigh_r"] = (0.12, 0.0, -0.1)
    p["shin_r"] = (math.pi / 2 - 0.05, 0.0, 0.0)
    p["thigh_l"] = (-1.45, 0.0, 0.05)
    p["shin_l"] = (1.5, 0.0, 0.0)


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
    _kneel(p, 0.02 * math.sin(t))
    _arms_down(p)
    return p, (0, 0, KNEEL_HIP - HIP_HEIGHT)


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


def crouch_b(u):
    return crouch_walk(1.0 - u)


PRONE_HIP = 0.16


def _prone(p, t=0.0, crawl=0.0):
    """Prone to shoot (J 2026-11-03): face down, propped on both elbows, chest up, the stock in the right
    shoulder and the head behind the sights. The left hand comes from the IK."""
    p["pelvis"] = (math.pi / 2, 0.0, 0.05 * crawl * math.sin(t))
    p["torso"] = (-0.32, 0.0, 0.08 * crawl * math.sin(t))  # chest raised on the elbows
    p["head"] = (-0.75, 0.0, 0.0)  # looks ahead along the barrel
    # Legs apart (ry spreads, rz twists), knees drawn up sideways when crawling; feet turned so the toes point
    # out and the insides of the boots lie on the floor (J 2026-11-03).
    p["thigh_l"] = (0.0, -0.22 - 0.5 * crawl * max(0.0, math.sin(t)), 0.0)
    p["thigh_r"] = (0.0, 0.22 + 0.5 * crawl * max(0.0, -math.sin(t)), 0.0)
    p["shin_l"] = (0.9 * crawl * max(0.0, math.sin(t)), 0.0, 1.35)
    p["shin_r"] = (0.9 * crawl * max(0.0, -math.sin(t)), 0.0, -1.35)
    # Upper arms down to the elbows on the floor, a little ahead of and outside the shoulders; forearms up
    # and in, so the right hand holds the grip with the stock in the shoulder
    # (solved by FK: elbow 7 cm off the floor just ahead of the shoulder, grip hand 0.28 m ahead of it)
    p["arm_l"] = (-1.9 - 0.3 * crawl * math.sin(t), -0.6, 0.0)
    p["arm_r"] = (-1.9 + 0.3 * crawl * math.sin(t), 0.6, 0.0)
    p["fore_l"] = (-2.05, 0.0, 0.4)
    p["fore_r"] = (-2.05, 0.0, -0.4)


def prone_idle(u):
    p = {}
    _prone(p)
    return p, (0, 0, PRONE_HIP - HIP_HEIGHT)


def crawl(u):
    """Leopard crawl (J bug 15): flat on the elbows and knees, the rifle cradled across both forearms; the
    elbows reach forward in turn and the opposite knee comes up beside the hip."""
    t = u * math.tau
    s = math.sin(t)
    p = {"pelvis": (math.pi / 2, 0.0, 0.06 * s), "torso": (-0.12, 0.0, 0.1 * s), "head": (-0.6, 0.0, -0.1 * s)}
    # forearms flat and turned in under the chest, so the rifle lies across them; elbows step forward in turn
    p["arm_l"] = (-1.75 - 0.35 * max(0.0, s), -0.55, 0.0)
    p["arm_r"] = (-1.75 - 0.35 * max(0.0, -s), 0.55, 0.0)
    p["fore_l"] = (-0.35, 0.0, 1.25)
    p["fore_r"] = (-0.35, 0.0, -1.25)
    # knees drawn up sideways in turn (frog kick), toes out
    p["thigh_l"] = (-0.45 * max(0.0, -s), -0.3 - 0.55 * max(0.0, -s), 0.0)
    p["thigh_r"] = (-0.45 * max(0.0, s), 0.3 + 0.55 * max(0.0, s), 0.0)
    p["shin_l"] = (0.2 + 1.3 * max(0.0, -s), 0.0, 1.35)
    p["shin_r"] = (0.2 + 1.3 * max(0.0, s), 0.0, -1.35)
    return p, (0, 0, PRONE_HIP - 0.04 - HIP_HEIGHT + 0.015 * abs(s))


def prone_roll(u, side):
    """A log roll sideways while prone (J bug 14): arms and rifle pulled in to the chest, legs together, one full
    turn about the body's long axis. side = +1 toward the left (+X), -1 right; the game moves the body."""
    turn = _keys([(0.0, 0.0), (0.1, 0.3), (0.85, math.tau - 0.2), (1.0, math.tau)], u) * -side
    tuck = _keys([(0.0, 0.0), (0.15, 1.0), (0.85, 1.0), (1.0, 0.0)], u)
    p = {}
    _prone(p)
    p["pelvis"] = (math.pi / 2, turn, 0.0)
    p["torso"] = (-0.32 * (1 - tuck), 0.0, 0.0)
    p["head"] = (-0.75 * (1 - tuck), 0.0, 0.0)
    for sd, sign in (("l", 1.0), ("r", -1.0)):
        p[f"thigh_{sd}"] = (0.0, -0.22 * sign * (1 - tuck), 0.0)
        p[f"shin_{sd}"] = (0.0, 0.0, 1.35 * sign * (1 - tuck))
        p[f"arm_{sd}"] = (_ease(-1.9, -1.2, tuck), -0.6 * sign * (1 - tuck), 0.0)
        p[f"fore_{sd}"] = (_ease(-2.05, -2.4, tuck), 0.0, 0.4 * sign)
    return p, (0, 0, PRONE_HIP - HIP_HEIGHT + 0.08 * math.sin(math.pi * u))


def prone_roll_l(u):
    return prone_roll(u, 1.0)


def prone_roll_r(u):
    return prone_roll(u, -1.0)


# ---- getting down and up (J bugs 11, 12): eased blends through key poses ----

def _blend(a, b, k):
    """Pose a → b at k (0..1), bone by bone; a pose is (bone rotations, root offset)."""
    pa, ra = a
    pb, rb = b
    p = {}
    for bone in set(pa) | set(pb):
        x = pa.get(bone, (0.0, 0.0, 0.0))
        y = pb.get(bone, (0.0, 0.0, 0.0))
        p[bone] = tuple(x[i] + (y[i] - x[i]) * k for i in range(3))
    return p, tuple(ra[i] + (rb[i] - ra[i]) * k for i in range(3))


def _through(keys, u):
    """[(u, pose), ...] with smoothstep easing between consecutive poses."""
    for (u0, a), (u1, b) in zip(keys, keys[1:]):
        if u <= u1:
            k = max(0.0, min(1.0, (u - u0) / max(1e-6, u1 - u0)))
            return _blend(a, b, k * k * (3 - 2 * k))
    return keys[-1][1]


def _kneel_both():
    """Both knees on the floor, hands at the thighs."""
    p = {"torso": (0.2, 0.0, 0.0), "head": (0.1, 0.0, 0.0)}
    for sd in "lr":
        p[f"thigh_{sd}"] = (0.1, 0.0, 0.0)
        p[f"shin_{sd}"] = (math.pi / 2 - 0.05, 0.0, 0.0)
    _arms_down(p)
    return p, (0, 0, KNEEL_HIP - HIP_HEIGHT)


def _hands_down():
    """On the knees, leaning forward onto both hands, about to lie down."""
    p = {"pelvis": (0.65, 0.0, 0.0), "torso": (0.45, 0.0, 0.0), "head": (-0.6, 0.0, 0.0)}
    for sd in "lr":
        p[f"thigh_{sd}"] = (-0.55, 0.0, 0.0)
        p[f"shin_{sd}"] = (2.0, 0.0, 0.0)
        p[f"arm_{sd}"] = (-1.05, 0.0, 0.0)
        p[f"fore_{sd}"] = (-0.15, 0.0, 0.0)
    return p, (0, 0, 0.42 - HIP_HEIGHT)


def _pose(fn):
    return fn(0.0)


def go_prone(u):
    """Standing to prone: down on the knees, hands to the floor, then flat behind the sights (not a fall)."""
    return _through([(0.0, _pose(idle)), (0.35, _kneel_both()), (0.65, _hands_down()), (1.0, _pose(prone_idle))], u)


def crouch_to_prone(u):
    return _through([(0.0, _pose(crouch_idle)), (0.45, _hands_down()), (1.0, _pose(prone_idle))], u)


def prone_to_stand(u):
    return _through([(0.0, _pose(prone_idle)), (0.35, _hands_down()), (0.65, _kneel_both()), (1.0, _pose(idle))], u)


def prone_to_crouch(u):
    return _through([(0.0, _pose(prone_idle)), (0.5, _hands_down()), (1.0, _pose(crouch_idle))], u)


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
    """Down on the back, propped on one elbow, a hand pressed to the wound; never still (J bug 6): heavy breaths,
    the head lolling, the bent leg pushing and sliding, the wounded side curling now and then."""
    t = u * math.tau
    breath = math.sin(3 * t)
    p = {"pelvis": (-1.35, 0.0, 0.1 + 0.06 * math.sin(t)),
         "torso": (0.55 + 0.06 * breath + 0.1 * max(0.0, math.sin(t + 1.0)), 0.0, -0.1 + 0.12 * math.sin(t)),
         "head": (0.35 + 0.15 * math.sin(2 * t), 0.0, 0.35 * math.sin(t + 0.5))}
    p["thigh_l"] = (-0.5 - 0.3 * max(0.0, math.sin(t)), 0.0, 0.15)
    p["shin_l"] = (0.9 + 0.5 * max(0.0, math.sin(t)), 0.0, 0.0)
    p["thigh_r"] = (-0.1 - 0.15 * max(0.0, -math.sin(t)), 0.0, -0.1)
    p["shin_r"] = (0.2 + 0.3 * max(0.0, -math.sin(t)), 0.0, 0.0)
    p["arm_l"] = (0.6 + 0.08 * breath, 0.0, -0.3)
    p["fore_l"] = (-1.4, 0.0, 0.0)
    p["arm_r"] = (-0.6 + 0.1 * math.sin(2 * t), 0.0, 0.4)
    p["fore_r"] = (-1.9 - 0.15 * math.sin(3 * t), 0.0, 0.3)
    return p, (0, 0, 0.22 - HIP_HEIGHT + 0.015 * breath)


def death(u):
    """Bleeding out (J bug 6): the propped arm gives, the body sinks flat on its back, the head rolls aside and
    the limbs go slack. One-shot; the last frame holds."""
    start = downed(0.0)
    flat = {"pelvis": (-1.55, 0.0, 0.15), "torso": (0.0, 0.0, -0.05), "head": (-0.1, 0.0, 0.7),
            "thigh_l": (-0.15, 0.0, 0.25), "shin_l": (0.3, 0.0, 0.0), "thigh_r": (0.05, 0.0, -0.2),
            "shin_r": (0.05, 0.0, 0.0), "arm_l": (0.3, 0.0, -0.9), "fore_l": (-0.3, 0.0, 0.0),
            "arm_r": (0.1, 0.0, 1.0), "fore_r": (-0.6, 0.0, 0.2)}
    slump = {"pelvis": (-1.45, 0.0, 0.2), "torso": (0.3, 0.0, -0.2), "head": (0.6, 0.0, 0.3),
             "thigh_l": (-0.4, 0.0, 0.2), "shin_l": (0.8, 0.0, 0.0), "thigh_r": (-0.1, 0.0, -0.1),
             "shin_r": (0.2, 0.0, 0.0), "arm_l": (0.9, 0.0, -0.5), "fore_l": (-0.8, 0.0, 0.0),
             "arm_r": (-0.3, 0.0, 0.6), "fore_r": (-1.2, 0.0, 0.2)}
    return _through([(0.0, start), (0.4, (slump, (0, 0, 0.17 - HIP_HEIGHT))),
                     (1.0, (flat, (0, 0, 0.12 - HIP_HEIGHT)))], u)


def downed_aim(u):
    """Down but fighting (J 2026-11-04): on the back, propped up on the left elbow, the pistol held out over the
    feet in the right hand (arm about level: the torso leans back 0.6, so the arm swings 0.97 forward)."""
    t = u * math.tau
    p = {"pelvis": (-1.35, 0.0, 0.05), "torso": (0.75 + 0.02 * math.sin(t), 0.0, -0.05), "head": (0.4, 0.0, 0.0)}
    p["thigh_l"] = (-0.45, 0.0, 0.15)
    p["shin_l"] = (0.8, 0.0, 0.0)
    p["thigh_r"] = (-0.1, 0.0, -0.1)
    p["shin_r"] = (0.2, 0.0, 0.0)
    p["arm_l"] = (0.7, 0.0, -0.35)
    p["fore_l"] = (-1.3, 0.0, 0.0)
    p["arm_r"] = (-0.97, 0.0, 0.2)
    p["fore_r"] = (-0.1, 0.0, 0.0)
    return p, (0, 0, 0.26 - HIP_HEIGHT + 0.01 * math.sin(t))


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
    p["torso"] = (0.06, 0.0, -0.6)  # bladed: left shoulder well toward the aim, so the left hand reaches the handguard
    p["head"] = (0.1, 0.0, 0.55)    # turned back to look along the barrel
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
    """The pistol comes in to the chest and tips up so the grip faces the left hand (which the game's IK walks
    through: mag out, drop, belt, new mag in, rack the slide)."""
    p = {}
    _aim_pistol(p)
    tilt = _keys([(0.0, 0.0), (0.12, 1.0), (0.85, 1.0), (1.0, 0.0)], u)
    p["arm_r"] = (-1.4 + 0.75 * tilt, 0.0, 0.4 + 0.25 * tilt)
    p["fore_r"] = (-0.2 - 0.9 * tilt, 0.0, 0.0)
    p["hand_r"] = (0.0, 0.0, 0.7 * tilt)  # roll the gun so the mag well faces the left hand
    p["head"] = (0.35 * tilt, 0.0, 0.0)  # looks down at the gun
    return p, (0, 0, 0)


def reload_rifle(u):
    """The rifle comes off the shoulder, muzzle up and rolled so the mag well faces the left hand (the game's
    IK: mag out, drop, vest pouch, new mag in, pull the charging handle)."""
    p = {}
    _aim_rifle(p)
    tilt = _keys([(0.0, 0.0), (0.1, 1.0), (0.88, 1.0), (1.0, 0.0)], u)
    p["arm_r"] = (-0.3 + 0.35 * tilt, 0.0, 0.45)
    p["fore_r"] = (-1.6 - 0.45 * tilt, 0.0, 0.35)
    p["hand_r"] = (0.0, 0.0, 0.6 * tilt)
    p["torso"] = (0.06 + 0.2 * tilt, 0.0, -0.6 + 0.45 * tilt)  # squares up to the gun while reloading
    p["head"] = (0.05 + 0.35 * tilt, 0.0, 0.2)
    return p, (0, 0, 0)


def reload_shell(u):
    """The shotgun held low and rolled, loading port up toward the left hand (the game's IK: a shell from the
    belt into the port). Loops once per shell."""
    p = {}
    _aim_rifle(p)
    p["arm_r"] = (-0.15, 0.0, 0.45)
    p["fore_r"] = (-1.9, 0.0, 0.35)
    p["hand_r"] = (0.0, 0.0, 0.8)
    p["head"] = (0.4, 0.0, 0.2)
    return p, (0, 0, 0)


def switch(u):
    """Weapon switch (J bug 4): the right hand drops to the hip / over the shoulder for the other gun and brings
    it up to aim; the game swaps the gun model at the halfway point."""
    k = _keys([(0.0, 0.0), (0.45, 1.0), (0.55, 1.0), (1.0, 0.0)], u)
    p = {}
    _aim_rifle(p)
    p["torso"] = (0.06 + 0.1 * k, 0.0, -0.6 + 0.35 * k)
    p["head"] = (0.1 + 0.25 * k, 0.0, 0.55 - 0.3 * k)
    p["arm_r"] = (_ease(-0.3, 0.35, k), 0.0, _ease(0.45, -0.15, k))  # down and back to the holster / sling
    p["fore_r"] = (_ease(-1.6, -0.6, k), 0.0, _ease(0.35, 0.0, k))
    p["arm_l"] = (_ease(-1.35, -0.2, k), 0.0, _ease(0.2, -0.05, k))
    p["fore_l"] = (_ease(-0.2, -0.9, k), 0.0, 0.0)
    return p, (0, 0, 0)


def _guard(p):
    """Melee guard: weapon hand forward at the chest, the other up to fend off."""
    p["torso"] = (0.12, 0.0, 0.0)
    p["head"] = (0.0, 0.0, 0.0)
    p["arm_r"] = (-0.9, 0.0, 0.2)
    p["fore_r"] = (-1.0, 0.0, 0.0)
    p["hand_r"] = (0.0, 0.0, 0.0)
    p["arm_l"] = (-0.8, 0.0, 0.1)
    p["fore_l"] = (-1.3, 0.0, 0.0)
    p["hand_l"] = (0.0, 0.0, 0.0)


def slash_light(u):
    """Knife (J melee): a quick backhand cut right to left across the front; the blade crosses the aim at
    u = 0.27 (= MeleeConfig.windup_sec / swing_sec for the knife), then a short follow-through and back."""
    p = {}
    _guard(p)
    sweep = _keys([(0.0, 0.0), (0.15, -1.0), (0.27, 0.0), (0.42, 1.0), (1.0, 0.0)], u)  # -1 wound right, +1 across left
    reach = _keys([(0.0, 0.0), (0.15, 0.3), (0.27, 1.0), (0.42, 0.7), (1.0, 0.0)], u)
    p["torso"] = (0.12 + 0.08 * reach, 0.0, 0.35 * sweep)
    p["arm_r"] = (-0.9 - 0.6 * reach, 0.0, 0.2 + 0.85 * sweep)
    p["fore_r"] = (-1.0 + 0.85 * reach, 0.0, 0.3 * sweep)
    p["arm_l"] = (-0.8 + 0.3 * reach, 0.0, 0.1 - 0.3 * sweep)
    return p, (0, 0, 0)


def slash_heavy(u):
    """Axe (J melee): both hands, raised over the right shoulder, chopped down across the front; the head crosses
    the aim at u = 0.31 (= windup_sec / swing_sec for the axe), then a heavy follow-through and recovery."""
    p = {}
    _guard(p)
    lift = _keys([(0.0, 0.0), (0.22, 1.0), (0.31, 0.15), (0.45, -0.45), (0.7, -0.3), (1.0, 0.0)], u)  # +1 overhead
    turn = _keys([(0.0, 0.0), (0.22, -1.0), (0.31, 0.0), (0.45, 0.8), (1.0, 0.0)], u)
    p["torso"] = (0.12 + 0.35 * max(0.0, -lift), 0.0, 0.45 * turn)
    p["head"] = (0.2 * max(0.0, -lift), 0.0, -0.25 * turn)
    for sd, side in (("r", 1.0), ("l", -1.0)):
        p[f"arm_{sd}"] = (-1.2 - 1.4 * max(0.0, lift) + 0.4 * max(0.0, -lift), 0.0, 0.25 * side + 0.45 * turn)
        p[f"fore_{sd}"] = (-0.9 + 0.6 * max(0.0, -lift), 0.0, 0.25 * side)
    return p, (0, 0, 0)


# name: (function, frames, loop)
CLIPS = {
    "idle": (idle, 48, True), "walk_f": (walk, 18, True), "walk_b": (walk_b, 18, True), "run": (run, 16, True),
    "crouch_idle": (crouch_idle, 48, True), "crouch_f": (crouch_walk, 28, True), "crouch_b": (crouch_b, 28, True),
    "prone_idle": (prone_idle, 48, True), "crawl": (crawl, 32, True), "roll": (roll, 14, False),
    "downed": (downed, 96, True), "downed_aim": (downed_aim, 48, True), "death": (death, 30, False),
    "go_prone": (go_prone, 16, False), "crouch_to_prone": (crouch_to_prone, 12, False),
    "prone_to_stand": (prone_to_stand, 16, False), "prone_to_crouch": (prone_to_crouch, 12, False),
    "prone_roll_l": (prone_roll_l, 15, False), "prone_roll_r": (prone_roll_r, 15, False),
    "aim_pistol": (aim_pistol, 48, True), "aim_rifle": (aim_rifle, 48, True),
    "carry_high": (carry_high, 16, True), "carry_port": (carry_port, 16, True),
    "reload_pistol": (reload_pistol, 29, False), "reload_rifle": (reload_rifle, 58, False),
    "reload_shell": (reload_shell, 12, True),
    "switch": (switch, 12, False), "slash_light": (slash_light, 12, False), "slash_heavy": (slash_heavy, 20, False),
}
LOOP_CLIPS = [n for n, (_, _, loop) in CLIPS.items() if loop]
# m/s each moving clip matches at 1× (survivor_view.gd CLIP_SPEED agrees and scales the clip by speed)
WALK_SPEED = 4.5
RUN_SPEED = 6.0
CROUCH_SPEED = 1.7
CRAWL_SPEED = 0.85


# ---- build ---------------------------------------------------------------------------------------

def build_mesh(rest, look=0):
    parts = []
    for bone, boxes in boxes_for(look).items():
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
    body.name = body.data.name = f"survivor_{look}"
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
    bodies = []
    for look in range(LOOKS):
        body = build_mesh(rest, look)
        K.bake_vertex_ao(body, distance=0.25, samples=32)
        bodies.append(body)
    rig = build_armature(rest)
    for body in bodies:
        body.parent = rig
        mod = body.modifiers.new("rig", "ARMATURE")
        mod.object = rig
    bake_clips(rig)
    os.makedirs(out, exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(o in bodies or o == rig)
    bpy.context.view_layer.objects.active = rig
    path = os.path.join(out, "survivor.glb")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_vertex_color="ACTIVE", export_normals=True, export_texcoords=False, export_materials="EXPORT",
        export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
        export_skins=True, export_def_bones=False, export_optimize_animation_size=False,
    )
    tris = [sum(len(p.vertices) - 2 for p in b.data.polygons) for b in bodies]
    print(f"exported {path}  ({LOOKS} looks, {tris} tris, {len(CLIPS)} clips, loops: {', '.join(LOOP_CLIPS)})")
