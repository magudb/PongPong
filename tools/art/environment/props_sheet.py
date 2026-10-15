#!/usr/bin/env python3
"""Contact sheet of baked props (QA; never judge a prop from a single image).

  python tools/art/environment/props_sheet.py --root DIR_WITH_props.json --out sheet.png [--cols 6] [--cell 300] [--bg '#a9c97a'] [--grade 4d5e85]
                                              [--scale 1.0] [--prefix crown_] [--pivots] [names...]

Each prop is drawn with its ground pivot on a common baseline, glow halos and `blend: add` props additively.  --grade multiplies the
sheet like the world's CanvasModulate (the night look: 4d5e85), --pivots marks the pivot with a red cross and the footprint diamond.
"""
import argparse, json, os
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont


def font(size):
    for p in ['/System/Library/Fonts/Helvetica.ttc', '/System/Library/Fonts/Supplemental/Arial.ttf']:
        if os.path.exists(p): return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def additive(sheet, layer, strength=1.0):
    base = np.asarray(sheet, np.float32) / 255.0; l = np.asarray(layer, np.float32) / 255.0
    base[..., :3] = np.clip(base[..., :3] + l[..., :3] * l[..., 3:4] * strength, 0, 1)
    return Image.fromarray(np.uint8(base * 255 + .5), 'RGBA')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('names', nargs='*'); ap.add_argument('--root', required=True); ap.add_argument('--out', required=True)
    ap.add_argument('--cols', type=int, default=6); ap.add_argument('--cell', type=int, default=300); ap.add_argument('--bg', default='#a9c97a')
    ap.add_argument('--scale', type=float, default=1.0); ap.add_argument('--prefix', default=''); ap.add_argument('--grade', default=None)
    ap.add_argument('--pivots', action='store_true'); ap.add_argument('--meta', default='props.json')
    a = ap.parse_args()
    root = Path(a.root); meta = json.loads((root / a.meta).read_text())
    names = a.names or [n for n in meta if not n.startswith('_') and n.startswith(a.prefix)]
    C = a.cell; rows = (len(names) + a.cols - 1) // a.cols
    sheet = Image.new('RGBA', (C * a.cols, C * rows), a.bg); f = font(12)
    add_layers = []
    for i, n in enumerate(names):
        m = meta[n]; im = Image.open(root / m['file']).convert('RGBA')
        if a.scale != 1.0: im = im.resize((max(1, int(im.width * a.scale)), max(1, int(im.height * a.scale))), Image.LANCZOS)
        px, py = int(m['pivot'][0] * a.scale), int(m['pivot'][1] * a.scale)
        x = (i % a.cols) * C + C // 2 - px; y = (i // a.cols) * C + int(C * .72) - py
        layer = Image.new('RGBA', sheet.size, (0, 0, 0, 0))
        if m.get('blend') == 'add':
            layer.paste(im, (x, y)); sheet = additive(sheet, layer)
        else:
            if 'glow' in m:
                g = Image.open(root / m['glow']['file']).convert('RGBA'); gx, gy = m['glow']['center']
                gl = Image.new('RGBA', sheet.size, (0, 0, 0, 0))
                gl.paste(g, (int(x + gx * a.scale - g.width / 2), int(y + gy * a.scale - g.height / 2)))
                add_layers.append(gl)
            layer.paste(im, (x, y)); sheet = Image.alpha_composite(sheet, layer)
        d = ImageDraw.Draw(sheet)
        if a.pivots:
            cx, cy = (i % a.cols) * C + C // 2, (i // a.cols) * C + int(C * .72)
            d.line((cx - 8, cy, cx + 8, cy), fill=(255, 0, 0, 255), width=2); d.line((cx, cy - 8, cx, cy + 8), fill=(255, 0, 0, 255), width=2)
            fx, fz = m.get('footprint', [1, 1]); s = a.scale
            pts = [(cx + 64 * s * (x - z), cy + 38 * s * (x + z)) for x, z in ((-fx / 2, -fz / 2), (fx / 2, -fz / 2), (fx / 2, fz / 2), (-fx / 2, fz / 2))]
            d.polygon(pts, outline=(255, 0, 0, 200))
        d.text(((i % a.cols) * C + 4, (i // a.cols) * C + 3), '%s %dx%d' % (n, m['size'][0], m['size'][1]), fill=(43, 35, 64, 255), font=f)
    if a.grade:
        g = np.array([int(a.grade[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255
        arr = np.asarray(sheet.convert('RGB'), np.float32) * g[None, None, :]
        sheet = Image.fromarray(np.uint8(np.clip(arr, 0, 255)), 'RGB').convert('RGBA')
    for gl in add_layers:
        sheet = additive(sheet, gl, .75)
    sheet.convert('RGB').save(a.out); print(a.out, sheet.size)


if __name__ == '__main__':
    main()
