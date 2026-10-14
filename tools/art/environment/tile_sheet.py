#!/usr/bin/env python3
"""Contact sheet of ground terrains laid out the way the engine lays them (QA; never judge a tile from one atlas cell).

  python tools/art/environment/tile_sheet.py --root DIR_WITH_TILES --out sheet.png [--cols 12 --rows 8] [--grade 4d5e85] [--zoom 1.0] ids...
  ids may be separated by '+' to MIX terrains in one block (random cells), e.g. grass+grass_flowers  forest_floor_o+forest_floor_glow_o

Iso: cell (cx, cy) is drawn centred at ((cx - cy) * 64, (cx + cy) * 38); ortho: (cx * 96, cy * 56); both with atlas coords
(cx % 4, cy % 4) exactly like AreaTileSet / Iso.atlas_coords.  --grade multiplies the sheet like the world's CanvasModulate.
"""
import argparse, json, os, random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np


def font(size):
    for p in ['/System/Library/Fonts/Helvetica.ttc', '/System/Library/Fonts/Supplemental/Arial.ttf']:
        if os.path.exists(p): return ImageFont.truetype(p, size)
    return ImageFont.load_default()


class Atlases:
    def __init__(self, root):
        self.root = Path(root); self.meta = {}
        for f in sorted(self.root.glob('tiles*.json')):
            self.meta.update({k: v for k, v in json.loads(f.read_text()).items() if not k.startswith('_')})
        self.img = {}

    def tile(self, tid, cx, cy):
        m = self.meta[tid]
        if tid not in self.img: self.img[tid] = Image.open(self.root / m['file']).convert('RGBA')
        P = m['variants']; cw, ch = m['cell']
        i, j = cx % P[0], cy % P[1]
        return self.img[tid].crop((i * cw, j * ch, (i + 1) * cw, (j + 1) * ch)), m


def block(A, ids, cols, rows, seed=3, mark_cell=None):
    ids = ids.split('+')
    ortho = A.meta[ids[0]].get('proj') == 'ortho'
    rng = random.Random(seed)
    if ortho:
        W, H = cols * 96 + 16, rows * 56 + 8; off = (8, 4)
    else:
        W, H = (cols + rows) * 64 + 80, (cols + rows) * 38 + 50; off = ((rows) * 64 + 40, 25)
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cells = [(cx, cy) for cy in range(rows) for cx in range(cols)]
    cells.sort(key=lambda c: (c[0] + c[1], c[0]) if not ortho else (c[1], c[0]))
    for cx, cy in cells:
        tid = ids[rng.randrange(len(ids))] if len(ids) > 1 else ids[0]
        t, m = A.tile(tid, cx, cy)
        if ortho:
            x = off[0] + cx * 96 + 48 - t.width // 2; y = off[1] + cy * 56 + 28 - t.height // 2
        else:
            x = off[0] + (cx - cy) * 64 - t.width // 2; y = off[1] + (cx + cy) * 38 + 38 - t.height // 2
        im.alpha_composite(t, (int(x), int(y)))
    return im


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('ids', nargs='+'); ap.add_argument('--root', required=True); ap.add_argument('--out', required=True)
    ap.add_argument('--cols', type=int, default=8); ap.add_argument('--rows', type=int, default=6); ap.add_argument('--grade', default=None)
    ap.add_argument('--zoom', type=float, default=1.0); ap.add_argument('--bg', default='#e8e4dc'); ap.add_argument('--per-row', type=int, default=2)
    a = ap.parse_args()
    A = Atlases(a.root)
    blocks = [(i, block(A, i, a.cols, a.rows)) for i in a.ids]
    bw = max(b.width for _, b in blocks); bh = max(b.height for _, b in blocks) + 20
    per = a.per_row; nrows = (len(blocks) + per - 1) // per
    sheet = Image.new('RGBA', (bw * per, bh * nrows), a.bg); d = ImageDraw.Draw(sheet); f = font(14)
    for k, (tid, b) in enumerate(blocks):
        x, y = (k % per) * bw, (k // per) * bh
        d.text((x + 6, y + 3), tid, fill=(43, 35, 64, 255), font=f)
        sheet.alpha_composite(b, (x, y + 20))
    if a.grade:
        g = np.array([int(a.grade[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255
        arr = np.asarray(sheet.convert('RGB'), np.float32) * g[None, None, :]
        sheet = Image.fromarray(np.uint8(np.clip(arr, 0, 255)), 'RGB').convert('RGBA')
    if a.zoom != 1.0:
        sheet = sheet.resize((int(sheet.width * a.zoom), int(sheet.height * a.zoom)), Image.LANCZOS)
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(a.out); print(a.out, sheet.size)


if __name__ == '__main__':
    main()
