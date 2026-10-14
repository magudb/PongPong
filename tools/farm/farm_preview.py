#!/usr/bin/env python3
"""farm_preview.py - draws an AreaMap-style ASCII map as an isometric diamond picture (quick design iteration, NOT the engine look).
Cell (x, y) -> screen centre ((x - y + 1) * 64, (x + y + 1) * 38) like Iso.iso_center; the picture is scaled down by SCALE.
"""
from PIL import Image, ImageDraw, ImageFont

GROUND_COL = {
    ".": (150, 196, 98), ",": (170, 206, 110), ";": (170, 206, 110), "f": (176, 214, 120), "p": (214, 186, 130), "c": (200, 190, 200),
    "d": (186, 140, 86), "~": (96, 160, 214), "=": (205, 170, 110), "g": (150, 196, 98), "s": (232, 222, 200),
}
SKIRT_COL = (112, 74, 44)
SKIRT_COL2 = (140, 94, 56)
VOID_COL = (186, 224, 238)


def center(x, y, s):
    return ((x - y + 1) * 64 * s, (x + y + 1) * 38 * s)


def render(ground_rows, object_rows, markers, props, scale=0.2, path=None, growth_cells=None, reserve=None, extra_polys=None, labels=None, view_boxes=None, silhouette=None):
    h = len(ground_rows)
    w = max(len(r) for r in ground_rows)
    S = scale
    # bounds in px
    minx = center(0, h - 1, S)[0] - 64 * S - 10
    maxx = center(w - 1, 0, S)[0] + 64 * S + 10
    miny = center(0, 0, S)[1] - 38 * S - 40
    maxy = center(w - 1, h - 1, S)[1] + 38 * S + 40 + 140 * S
    W, H = int(maxx - minx), int(maxy - miny)
    img = Image.new("RGB", (W, H), VOID_COL)
    d = ImageDraw.Draw(img, "RGBA")
    ox, oy = -minx, -miny

    def P(x, y):
        cx, cy = center(x, y, S)
        return cx + ox, cy + oy

    def diamond(x, y, col, outline=None):
        cx, cy = P(x, y)
        hw, hh = 64 * S, 38 * S
        d.polygon([(cx, cy - hh), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)], fill=col, outline=outline)

    def gat(x, y):
        if x < 0 or y < 0 or y >= h or x >= len(ground_rows[y]):
            return "#"
        return ground_rows[y][x]

    # skirts first (they hang below the cells)
    for y in range(h):
        for x in range(w):
            ch = gat(x, y)
            if ch in "#=":
                continue
            cx, cy = P(x, y)
            hw, hh = 64 * S, 38 * S
            sk = 130 * S
            sw = gat(x, y + 1) == "#"
            se = gat(x + 1, y) == "#"
            if sw:   # SW face: edge from left corner to bottom corner
                d.polygon([(cx - hw, cy), (cx, cy + hh), (cx, cy + hh + sk), (cx - hw, cy + sk)], fill=SKIRT_COL)
            if se:   # SE face: edge from bottom corner to right corner
                d.polygon([(cx, cy + hh), (cx + hw, cy), (cx + hw, cy + sk), (cx, cy + hh + sk)], fill=SKIRT_COL2)
    # ground
    for y in range(h):
        for x in range(w):
            ch = gat(x, y)
            if ch == "#":
                continue
            if growth_cells and (x, y) in growth_cells:
                pass
            if ch == "=":
                diamond(x, y, GROUND_COL["="] + (150,), None)
                continue
            col = GROUND_COL.get(ch, (255, 0, 255))
            diamond(x, y, col, (60, 60, 40, 60) if ch == "f" else None)
    # growth rows hint
    if growth_cells:
        for (x, y), st in growth_cells.items():
            diamond(x, y, (255, 255, 255, 0), (200, 60, 60, 255) if st == 3 else ((220, 120, 60, 255) if st == 2 else (230, 180, 60, 255)))
    # reserve rect
    if reserve:
        x0, y0, x1, y1 = reserve
        pts = [P(x0 - 0.5, y0 - 0.5), P(x1 + 0.5, y0 - 0.5), P(x1 + 0.5, y1 + 0.5), P(x0 - 0.5, y1 + 0.5)]
        # P() uses cell centres; shift the corner by half a cell: corner (x-0.5, y-0.5) in cell units
        d.line(pts + [pts[0]], fill=(220, 40, 40, 255), width=2)
    # objects
    f = None
    try:
        f = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 11)
    except Exception:
        f = ImageFont.load_default()
    for y in range(h):
        for x in range(w):
            oc = object_rows[y][x] if y < len(object_rows) and x < len(object_rows[y]) else "."
            if oc == ".":
                continue
            cx, cy = P(x, y)
            kind = "spawn" if oc == "@" else (markers.get(oc, {}).get("marker") if oc in markers else ("prop:" + props[oc]["prop"] if oc in props else "?"))
            col = (40, 40, 40)
            r = 4
            if kind == "spawn":
                col = (255, 255, 255); r = 5
            elif str(kind).startswith("prop:"):
                a = kind[5:]
                col = (30, 110, 40) if "tree" in a or "bush" in a else ((120, 120, 120) if "rock" in a else ((150, 90, 40) if ("house" in a or "shed" in a or "coop" in a or "barn" in a or "bin" in a or "mail" in a) else (90, 60, 30)))
                r = 5
            elif kind == "light":
                col = (255, 220, 60); r = 3
            elif kind == "warp":
                col = (200, 40, 200); r = 6
            elif kind in ("sign", "bed", "quest_spot"):
                col = (255, 120, 20); r = 4
            elif kind == "growth":
                col = (255, 255, 255, 0); r = 1
            else:
                col = (20, 20, 160); r = 5
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col, outline=(0, 0, 0))
    if labels:
        for (x, y), t in labels.items():
            cx, cy = P(x, y)
            d.text((cx + 6, cy - 12), t, fill=(0, 0, 0), font=f)
    if view_boxes:
        for (cx_cell, cy_cell, wpx, hpx, col) in view_boxes:
            cx, cy = P(cx_cell, cy_cell)
            d.rectangle([cx - wpx * S / 2, cy - hpx * S / 2, cx + wpx * S / 2, cy + hpx * S / 2], outline=col, width=2)
    if silhouette:
        # (anchor cell x, y, left px, right px, up px): the tier-10 castle silhouette box (screen rect above the anchor)
        ax, ay, l, r, up = silhouette
        cx, cy = P(ax, ay)
        cx -= 32 * S
        cy += 19 * S
        d.rectangle([cx - l * S, cy - up * S, cx + r * S, cy], outline=(200, 0, 0, 255), width=1)
        d.rectangle([cx - l * S, cy - up * S, cx + r * S, cy], fill=(200, 0, 0, 30))
    if extra_polys:
        for poly, col in extra_polys:
            d.polygon([P(*p) for p in poly], outline=col)
    if path:
        img.save(path)
    return img
