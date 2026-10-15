"""Replay of the BUILT player E-query (scripts/world2d/player_stub_2d.gd nearest_interactable; Player2D keeps the same rule, D20):
a circle r = 45 ground px at the centre of the FACING cell, hosts whose 12-gon interaction ellipse (Interactable2D._ready, radius = half axes) overlaps it,
the host whose global_position is NEAREST TO THE PLAYER wins. Iso: iso_center(c) = ((x - y + 1) * 64, (x + y + 1) * 38); facing steps = Iso.DIR8_TO_CELL_STEP.
Lifted from D3/final_editor/se1/geom_lib.py (package T-towns-core); no dependency outside the standard library."""
from __future__ import annotations

import math

# Iso.DIR8_TO_CELL_STEP: S SW W NW N NE E SE
STEP = [(1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1), (1, 0)]
FACING_NAMES = ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
HALF_W = 64.0
HALF_H = 38.0
QUERY_RADIUS = 45.0


def ic(x: float, y: float) -> tuple[float, float]:
    """Layer-local centre of the iso cell (x, y) = Iso.iso_center (also valid for fractional cells)."""
    return ((x - y + 1) * HALF_W, (x + y + 1) * HALF_H)


def ellipse_pts(host: tuple[float, float], rad: tuple[float, float]) -> list[tuple[float, float]]:
    hx, hy = host
    return [(hx + math.cos(2 * math.pi * i / 12) * rad[0], hy + math.sin(2 * math.pi * i / 12) * rad[1]) for i in range(12)]


def circle_hits_poly(c: tuple[float, float], r: float, pts: list[tuple[float, float]]) -> bool:
    cx, cy = c
    inside = False
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        if (y1 > cy) != (y2 > cy) and cx < (x2 - x1) * (cy - y1) / (y2 - y1) + x1:
            inside = not inside
    if inside:
        return True
    best = 1e9
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        dx, dy = x2 - x1, y2 - y1
        t = max(0.0, min(1.0, ((cx - x1) * dx + (cy - y1) * dy) / (dx * dx + dy * dy)))
        best = min(best, math.hypot(cx - (x1 + t * dx), cy - (y1 + t * dy)))
    return best <= r


def select(player_xy: tuple[float, float], facing: int, cell: tuple[int, int], hosts: dict[str, tuple[tuple[float, float], tuple[float, float]]],
           r: float = QUERY_RADIUS) -> str | None:
    """hosts = {name: (centre_xy, half_axes)}; returns the selected host name or None (ties go to the host that comes first in `hosts`)."""
    tgt = ic(cell[0] + STEP[facing][0], cell[1] + STEP[facing][1])
    best, bd = None, 1e18
    for name, (cxy, rad) in hosts.items():
        if circle_hits_poly(tgt, r, ellipse_pts(cxy, rad)):
            d = math.dist(cxy, player_xy)
            if d < bd:
                best, bd = name, d
    return best
