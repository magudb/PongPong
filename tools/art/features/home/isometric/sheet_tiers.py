#!/usr/bin/env python3
"""contact sheet: tiers side by side at TRUE scale, pivots on one ground line, footprint diamonds drawn"""
import sys, json, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import homepaths
# usage: sheet_tiers.py <folder with home.json + the house PNG masters, e.g. <stage>/home_final> OUT.png [tier ...]   (sheets.py draws the same sheet from the exported WebP tree)
root = Path(sys.argv[1]); out = sys.argv[2]; tiers = [int(x) for x in sys.argv[3:]] or list(range(1, 11))
meta = json.loads((root / 'home.json').read_text())['tiers']
T = 128 / math.sqrt(2) / 87.0744 * 87.0744 / 1.0  # tile edge in px along screen axes handled below
HW, HH = 64.0, 37.6
def cell_px(x, z): return ((x - z) * HW, (x + z) * HH)
ims = [(t, Image.open(root / meta[str(t)]['file']).convert('RGBA'), meta[str(t)]) for t in tiers if str(t) in meta]
gap = 40
W = sum(i.width for _, i, _ in ims) + gap * (len(ims) + 1); up = max(m['pivot'][1] for _, _, m in ims) + 60; dn = max(i.height - m['pivot'][1] for _, i, m in ims) + 140
H = up + dn
sheet = Image.new('RGBA', (W, H), (169, 211, 160, 255)); d = ImageDraw.Draw(sheet, 'RGBA')
try: f = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf', 22)
except Exception: f = ImageFont.load_default()
x = gap
for t, im, m in ims:
    px, py = x + m['pivot'][0], up
    r = m['footprint_rect']
    pts = [cell_px(r[0], r[1]), cell_px(r[2], r[1]), cell_px(r[2], r[3]), cell_px(r[0], r[3])]
    d.polygon([(px + a, py + b) for a, b in pts], fill=(255, 255, 255, 38), outline=(43, 35, 64, 120))
    sheet.alpha_composite(im, (x, up - m['pivot'][1]))
    d.ellipse((px - 4, py - 4, px + 4, py + 4), fill=(179, 67, 107, 255))
    d.text((x, up + dn - 110), f"{t}. {m['id']}", fill=(43, 35, 64, 255), font=f)
    d.text((x, up + dn - 80), f"{m['footprint_tiles'][0]}x{m['footprint_tiles'][1]} fl, {m['height_m']} m, {im.width}x{im.height}px", fill=(43, 35, 64, 255), font=f)
    x += im.width + gap
sheet.convert('RGB').save(out)
print(sheet.size)
