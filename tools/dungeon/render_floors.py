#!/usr/bin/env python3
"""Renders generated floor map texts (generated *.map files) to PNG: 1 cell = 24 x 14 px (a quarter of the 96 x 56 ortho cell),
crown discs drawn with the same sphere geometry as the generator (R 170/230/300 px, centre 0.81 R above the anchor), markers as coloured dots.
Usage: render_floors.py out_dir png_dir  (uses the tools/art venv python: Pillow)"""
import sys, glob, os
from PIL import Image, ImageDraw

CW, CH = 24, 14
GROUND = {"m": "#2b3354", "n": "#2b3354", "o": "#2b3354", ".": "#2b3354", "g": "#2f6a6a", "p": "#4a4c78", "~": "#1c4a5a", "c": "#2b2f4f", "x": "#3f6aa0", "W": "#16122c", "#": "#0b0917"}
CROWN_R = [170, 230, 300]
MARK = {"chest": "#e3c372", "runestone": "#6fd6c4", "warp": "#f2c14e", "enemy": "#e58fa6", "node": "#5bd0e0", "dig_spot": "#b9946b", "unique_spot": "#ffffff",
        "light": "#bff5ea", "whisper": "#8a8fd0", "npc": "#f0b86e", "spawn": "#9b86d6", "quest_spot": "#ffd166"}

def parse(path):
    props, markers, ground, objects, hdr = {}, {}, [], [], {}
    sec = "h"
    for line in open(path, encoding="utf-8").read().split("\n"):
        if sec == "h":
            if line.startswith("@ground"): sec = "g"; continue
            if line.startswith("@prop "):
                p = line.split(" "); props[p[1]] = p[2]
            elif line.startswith("@marker "):
                p = line.split(" "); d = {"type": p[2]}
                for kv in p[3:]:
                    if "=" in kv: k, v = kv.split("=", 1); d[k] = v
                markers[p[1]] = d
            elif line.startswith("@"):
                k, _, v = line[1:].partition(" "); hdr[k] = v
        elif sec == "g":
            if line.startswith("@objects"): sec = "o"; continue
            ground.append(line)
        elif sec == "o":
            if line: objects.append(line)
    return hdr, props, markers, ground, objects

def render(path, out):
    hdr, props, markers, ground, objects = parse(path)
    h, w = len(ground), len(ground[0])
    im = Image.new("RGBA", (w * CW, h * CH), "#0b0917")
    d = ImageDraw.Draw(im, "RGBA")
    for y in range(h):
        for x in range(w):
            d.rectangle([x * CW, y * CH, (x + 1) * CW - 1, (y + 1) * CH - 1], fill=GROUND.get(ground[y][x], "#ff00ff"))
    crowns = []
    for y in range(h):
        for x in range(w):
            ch = objects[y][x]
            if ch in props:
                pid = props[ch]
                if pid.startswith("crown_"):
                    cls = "sml".index(pid[6]); crowns.append((y, x, cls, pid.endswith("_solid")))
                elif pid == "rock_dark":
                    d.ellipse([x * CW + 6, y * CH + 3, x * CW + 18, y * CH + 11], fill="#6a6f99")
                elif pid == "bush_forest":
                    d.ellipse([x * CW + 4, y * CH + 3, x * CW + 20, y * CH + 12], fill="#1d3a45")
                elif pid == "glowmush_teal":
                    d.ellipse([x * CW + 8, y * CH + 4, x * CW + 16, y * CH + 10], fill="#6fd6c4")
                elif pid == "pond_lily":
                    d.ellipse([x * CW + 6, y * CH + 3, x * CW + 18, y * CH + 10], fill="#3f8f6a")
    crowns.sort()
    for y, x, cls, solid in crowns:
        r = CROWN_R[cls] / 4.0
        cx = x * CW + CW / 2
        cy = y * CH + CH / 2 - (CROWN_R[cls] * 0.81) / 4.0
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(46, 53, 86, 215) if not solid else (70, 68, 122, 235), outline=(20, 17, 42, 255))
        r2 = r * 0.72
        d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=(56, 64, 106, 130))
        r3 = r * 0.34
        d.ellipse([cx - r * 0.55 - r3 / 2, cy - r * 0.55 - r3 / 2, cx - r * 0.55 + r3 / 2, cy - r * 0.55 + r3 / 2], fill=(70, 68, 122, 170))
    for y in range(h):
        for x in range(w):
            ch = objects[y][x]
            if ch == "@":
                d.ellipse([x * CW + 2, y * CH, x * CW + 22, y * CH + 14], outline="#ff9a3c", width=3)
            elif ch in markers:
                m = markers[ch]; t = m["type"]; col = MARK.get(t, "#ffffff")
                if t == "enemy" and "boss" in m: col = "#ff4f7a"; rr = 10
                elif t == "enemy" and "ambush" in m: col = "#f25a6a"; rr = 5
                elif t == "enemy" and "critter" in m: col = "#9be7d8"; rr = 4
                elif t == "warp": rr = 10
                elif t == "chest": rr = 7
                else: rr = 5
                d.ellipse([x * CW + 12 - rr, y * CH + 7 - rr, x * CW + 12 + rr, y * CH + 7 + rr], fill=col, outline="#000000")
    im.convert("RGB").save(out)
    return hdr

if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    for p in sorted(glob.glob(os.path.join(src, "*.map"))):
        out = os.path.join(dst, os.path.basename(p).replace(".map", ".png"))
        hdr = render(p, out)
        print(out, hdr.get("floor"), hdr.get("band"))
