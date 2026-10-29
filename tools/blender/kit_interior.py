"""Style 1.5 building interior kit -> assets/models/interior_*.glb

usage: blender -b --factory-startup --python tools/blender/kit_interior.py -- [out_dir] [name ...]

Pieces sit on a 1 m grid (the NavGrid cell). Origin = centre of the cell at floor level (z = 0); walls run
along +X and are drawn per cell by InteriorBuilder (game/interior/interior_builder.gd): a post in every wall
cell plus an arm (half a cell) toward each wall neighbour, so straight runs, corners and T junctions all close.
Storey height 3.2 m (kit_building.FLOOR). Colours are aged like the derelict buildings (decay ~0.6).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_common as K  # noqa: E402

K.PALETTE.update({
    "int_wall": "#b9ad9a", "int_wall_low": "#8f8577", "int_floor": "#6f665c", "int_floor_dark": "#5b534a",
    "int_cap": "#3b3631", "int_wood": "#7a5a3e", "int_wood_dark": "#5a4230", "int_fabric": "#5f6b70",
    "int_mattress": "#a59c88", "int_metal": "#6d7477", "int_tile": "#8e8a80",
})

STOREY = 3.2
WALL_T = 0.2
DOOR_H = 2.1
SILL, LINTEL = 0.9, 2.2


def wall_post(mb):
    mb.box((0, 0, STOREY / 2 + 0.15), (WALL_T, WALL_T, STOREY - 0.3), "int_wall")
    mb.box((0, 0, 0.15), (WALL_T + 0.02, WALL_T + 0.02, 0.3), "int_wall_low")  # skirting, as on the arms


def wall_arm(mb):
    """Half a cell of wall from the post toward +X, with a darker skirting band (reads as 'inside')."""
    mb.box((0.25 + WALL_T / 4, 0, STOREY / 2 + 0.15), (0.5 - WALL_T / 2, WALL_T, STOREY - 0.3), "int_wall")
    mb.box((0.25 + WALL_T / 4, 0, 0.15), (0.5 - WALL_T / 2, WALL_T + 0.02, 0.3), "int_wall_low")


def wall_window(mb):
    """A full cell of outer wall along X with a window: sill, lintel, dark broken glass, frame."""
    mb.box((0, 0, SILL / 2), (1.0, WALL_T, SILL), "int_wall")
    mb.box((0, 0, (LINTEL + STOREY) / 2), (1.0, WALL_T, STOREY - LINTEL), "int_wall")
    mb.box((-0.46, 0, (SILL + LINTEL) / 2), (0.08, WALL_T, LINTEL - SILL), "frame")
    mb.box((0.46, 0, (SILL + LINTEL) / 2), (0.08, WALL_T, LINTEL - SILL), "frame")
    mb.box((0, 0, SILL + 0.03), (1.0, WALL_T + 0.06, 0.06), "frame")
    mb.box((0, 0.02, (SILL + LINTEL) / 2 - 0.25), (0.84, 0.02, (LINTEL - SILL) * 0.55), "glass_dirty")


def doorway(mb):
    """Open door cell in a wall along X: jambs and lintel only, so the cell stays walkable."""
    mb.box((-0.45, 0, DOOR_H / 2), (0.1, WALL_T, DOOR_H), "int_wall")
    mb.box((0.45, 0, DOOR_H / 2), (0.1, WALL_T, DOOR_H), "int_wall")
    mb.box((0, 0, (DOOR_H + STOREY) / 2), (1.0, WALL_T, STOREY - DOOR_H), "int_wall")
    mb.box((0, 0, DOOR_H + 0.03), (0.84, WALL_T + 0.04, 0.06), "door")


def floor_tile(mb):
    mb.box((0, 0, -0.1), (1.0, 1.0, 0.2), "int_floor")


def stair_flight(mb):
    """4 m run, 1 m wide, from z = 0 at -X up to one storey at +X (builder rotates it per flight)."""
    steps = 16
    run = 4.0
    for i in range(steps):
        x = -run / 2 + (i + 0.5) * run / steps
        h = (i + 1) * STOREY / steps
        mb.box((x, 0, h / 2), (run / steps, 0.96, h), "int_tile" if i % 2 else "concrete")
    mb.box((0, 0.5, STOREY / 2 + 0.5), (run, 0.04, 0.05), "int_metal")  # handrail


def bed(mb):
    mb.box((0, 0, 0.2), (1.9, 0.9, 0.4), "int_wood_dark")
    mb.box((0.05, 0, 0.47), (1.75, 0.85, 0.16), "int_mattress")
    mb.box((-0.92, 0, 0.5), (0.08, 0.9, 0.7), "int_wood")


def table(mb):
    mb.box((0, 0, 0.74), (0.9, 0.7, 0.05), "int_wood")
    for x, y in [(-0.38, -0.28), (0.38, -0.28), (-0.38, 0.28), (0.38, 0.28)]:
        mb.box((x, y, 0.36), (0.06, 0.06, 0.72), "int_wood_dark")


def shelf(mb):
    """Tall cabinet against a wall (a search container)."""
    mb.box((0, 0, 0.9), (0.9, 0.4, 1.8), "int_wood")
    for z in (0.45, 0.9, 1.35):
        mb.box((0, -0.2, z), (0.86, 0.02, 0.03), "int_wood_dark")


def sofa(mb):
    mb.box((0, 0, 0.22), (1.8, 0.8, 0.44), "int_fabric")
    mb.box((0, 0.32, 0.55), (1.8, 0.16, 0.5), "int_fabric")
    mb.box((-0.85, 0, 0.4), (0.12, 0.8, 0.36), "int_fabric")
    mb.box((0.85, 0, 0.4), (0.12, 0.8, 0.36), "int_fabric")


def crate(mb):
    mb.box((0, 0, 0.3), (0.7, 0.7, 0.6), "board")
    mb.box((0, -0.36, 0.3), (0.7, 0.02, 0.08), "board_dark")


# name, builder, AO distance, aging
PIECES = [
    ("interior_wall_post", wall_post, 0.3, 0.6), ("interior_wall_arm", wall_arm, 0.3, 0.6),
    ("interior_wall_window", wall_window, 0.3, 0.6), ("interior_doorway", doorway, 0.3, 0.6),
    ("interior_floor", floor_tile, 0.3, 0.6),
    ("interior_stair", stair_flight, 0.4, 0.6),
    ("interior_bed", bed, 0.3, 0.6), ("interior_table", table, 0.3, 0.6), ("interior_shelf", shelf, 0.3, 0.6),
    ("interior_sofa", sofa, 0.3, 0.6), ("interior_crate", crate, 0.3, 0.6),
]


if __name__ == "__main__":
    a = K.args()
    out = a[0] if a else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")
    only = set(a[1:])
    for name, fn, ao_dist, aging in PIECES:
        if only and name not in only:
            continue
        K.reset(23)
        mb = K.MeshBuilder(aging=aging)
        fn(mb)
        obj = mb.to_object(name)
        K.bake_vertex_ao(obj, distance=ao_dist, samples=32)
        K.export_glb(obj, out, name)
