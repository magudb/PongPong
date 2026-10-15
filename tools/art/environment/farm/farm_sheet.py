#!/usr/bin/env python3
"""farm_sheet.py - contact sheets of the farm kit (package N03-farm-art), the equivalents of the prototype's sheet_big.png / sheet_small.png.  Never judge art from a single frame.

  python tools/art/environment/farm/farm_sheet.py [--root REPO] --out DIR [--grade 4d5e85] [--pivots]

  sheet_big.png    the four trunks side by side (scaled to a common 520 px height), the bin for scale
  sheet_small.png  shed, bin, stake sign, both rope stakes, build stake at 2 x (game zoom 0.4 x 5), pivots optional
  sheet_field.png  field_grass next to grass and grass_flowers: 4 x 4 variant atlases and a 6 x 6 cell lay-out as the engine lays them (periodic, no seams)
  sheet_backdrops.png  farm_far.webp tiled twice (the seam in the middle) over a sky gradient + farm_canopy.webp above it
Reads the SOURCE files in assets/ (lossless PNG / WebP).  The tool that looks at the art AFTER the S3TC import is the windowed section (tests/sections/art_farm.gd run_windowed): it
reads the textures back out of the imported .s3tc.ctex and writes the same sheets (art_farm_contact_big.png / _small.png).
"""
from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
KIT = ['trunk_giant_a', 'trunk_giant_b', 'trunk_under_a', 'trunk_under_b', 'tool_shed', 'shipping_bin', 'stake_sign', 'rope_stake_x', 'rope_stake_z', 'build_stake']
BG = (205, 224, 232, 255)


def load(root: Path):
    man = json.loads((root / 'assets/iso_props/farm/props.json').read_text())
    return {i: (Image.open(root / 'assets/iso_props/farm' / f'{i}.png').convert('RGBA'), man[i]) for i in KIT}


def grade(im: Image.Image, hexcol: str) -> Image.Image:
    if not hexcol:
        return im
    g = np.array([int(hexcol[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0
    a = np.asarray(im, np.float32).copy()
    a[..., :3] *= g
    return Image.fromarray(np.uint8(np.clip(a, 0, 255)), 'RGBA')


def row_sheet(items, scale_to=None, fixed_scale=None, pivots=False, pad=24, height=560, label_h=20):
    cells = []
    for n, im, meta in items:
        s = fixed_scale if fixed_scale else min(1.0, scale_to / im.size[1])
        r = im.resize((max(1, int(im.size[0] * s)), max(1, int(im.size[1] * s))), Image.LANCZOS)
        cells.append((n, r, meta, s))
    W = sum(c[1].size[0] + pad for c in cells) + pad
    H = max(height, max(c[1].size[1] for c in cells) + 2 * label_h)
    sheet = Image.new('RGBA', (W, H), BG)
    d = ImageDraw.Draw(sheet)
    x = pad
    for n, r, meta, s in cells:
        y = H - label_h - r.size[1]
        sheet.alpha_composite(r, (x, y))
        d.text((x, H - label_h + 4), '%s %dx%d' % (n, meta['size'][0], meta['size'][1]), fill=(0, 0, 0, 255))
        if pivots:
            px, py = x + meta['pivot'][0] * s, y + meta['pivot'][1] * s
            d.line((px - 6, py, px + 6, py), fill=(255, 0, 255, 255), width=1)
            d.line((px, py - 6, px, py + 6), fill=(255, 0, 255, 255), width=1)
        x += r.size[0] + pad
    return sheet.convert('RGB')


def field_sheet(root: Path) -> Image.Image:
    tiles = {n: Image.open(root / 'assets/iso_tiles' / f'{n}.png').convert('RGBA') for n in ('grass', 'grass_flowers', 'field_grass')}
    W = 3 * 580 + 40
    sheet = Image.new('RGBA', (W, 340 + 560), (120, 150, 170, 255))
    for k, (n, im) in enumerate(tiles.items()):
        sheet.alpha_composite(im, (10 + k * 590, 0))
    # an engine-like lay-out: diamond cells (64, 38) apart, a 12 x 12 patch, the left half grass, the right half field_grass
    lay = Image.new('RGBA', (W, 560), (120, 150, 170, 255))
    for y in range(14):
        for x in range(14):
            name = 'field_grass' if 3 <= x <= 10 and 3 <= y <= 10 else 'grass'
            im = tiles[name]
            cx, cy = (x % 4) * 144, (y % 4) * 84
            cell = im.crop((cx, cy, cx + 144, cy + 84))
            lay.alpha_composite(cell, (int(W / 2 + (x - y) * 64 - 72), int(30 + (x + y) * 37.6 - 4)))
    sheet.alpha_composite(lay, (0, 340))
    return sheet.convert('RGB')


def backdrop_sheet(root: Path) -> Image.Image:
    far = Image.open(root / 'assets/backdrops/farm_far.webp').convert('RGBA')
    can = Image.open(root / 'assets/backdrops/farm_canopy.webp').convert('RGBA')
    W, H = far.size[0] * 2, far.size[1]
    y = np.linspace(0, 1, H)[:, None, None]
    top, bot = np.array([127, 192, 222]), np.array([234, 243, 220])
    sky = Image.fromarray(np.uint8(np.tile(top * (1 - y) + bot * y, (1, W, 1))), 'RGB').convert('RGBA')
    sky.alpha_composite(far, (0, 0))
    sky.alpha_composite(far, (far.size[0], 0))
    sky.alpha_composite(can, (0, 0))
    sky.alpha_composite(can, (can.size[0], 0))
    d = ImageDraw.Draw(sky)
    d.line((far.size[0], 0, far.size[0], H), fill=(255, 0, 255, 255), width=1)        # the seam
    return sky.convert('RGB').resize((W // 2, H // 2), Image.LANCZOS)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('  python ')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--root', default=str(REPO))
    ap.add_argument('--out', required=True)
    ap.add_argument('--grade', default='')
    ap.add_argument('--pivots', action='store_true')
    a = ap.parse_args()
    root, out = Path(a.root), Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    props = load(root)
    big = [(n, grade(props[n][0], a.grade), props[n][1]) for n in KIT[:4]] + [('shipping_bin', grade(props['shipping_bin'][0], a.grade), props['shipping_bin'][1])]
    # the trunks to a common height (they are 1300 - 2400 px tall); the bin is drawn at the SAME scale as trunk_giant_a for the size comparison
    s_big = 520.0 / props['trunk_giant_a'][0].size[1]
    big_cells = []
    for n, im, meta in big:
        big_cells.append((n, im, meta))
    row_sheet(big_cells, fixed_scale=s_big, pivots=a.pivots).save(out / 'sheet_big.png')
    small = [(n, grade(props[n][0], a.grade), props[n][1]) for n in KIT[4:]]
    row_sheet(small, fixed_scale=2.0, pivots=a.pivots, height=420).save(out / 'sheet_small.png')
    field_sheet(root).save(out / 'sheet_field.png')
    backdrop_sheet(root).save(out / 'sheet_backdrops.png')
    print('wrote sheet_big.png sheet_small.png sheet_field.png sheet_backdrops.png ->', out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
