#!/usr/bin/env python3
"""bake_farm_tiles.py - the farm's own terrain atlas `field_grass` (package N03-farm-art): the UNTILLED look of an `f` cell - the farm grass, a little lighter and warmer, with faint
furrow lines and soil specks - baked with P22's tile baker (bake_tiles.py): periodic 4 x 4 variants of a 144 x 84 cell like every iso terrain (atlas 576 x 336), plus tiles_farm.json.

  python tools/art/environment/farm/bake_farm_tiles.py [--out DIR] [--ss 3]

Default out: <N03 stage>/masters/iso_tiles.  Writes field_grass.png and tiles_farm.json ({field_grass: {file, variants [4,4], cell [144,84]}}; ArtCatalog reads every tiles_*.json
next to tiles.json).  FarmView applies the terrain to every farmable cell (P06 amendment); the atlas is imported WITHOUT mipmaps (periodic cells would bleed at mip >= 1).
The recipe shares P22's farm grass base (GRASS_STYLES['farm']) so a `.` cell and an `f` cell sit next to each other without a seam of colour or of blades.
"""
from __future__ import annotations
import argparse
import json
import math
import sys
import time
from pathlib import Path

import farm_common as fc                       # noqa: E402

fc.prepare_path()
import numpy as np                              # noqa: E402
import bake_tiles as bt                         # noqa: E402  P22's tile baker


def terrain_field_grass() -> 'bt.Canvas':
    st = bt.GRASS_STYLES['farm']
    cv = bt.Canvas(bt.hexrgb('A6C96B'), 31)
    cv.tint(.06, 5).tint(.04, 14).shade_hue('C2D985', 7, .5).shade_hue('9DBD60', 9, .4)
    cv.paint(lambda d, r, n: bt.blades(d, r, n, 3600, st['blades'], (4, 9), 2, (70, 140)))
    # furrow lines: 5 per tile along x, faint
    rows = bt.P * 5
    yy = (np.arange(cv.n)[:, None] / cv.n * rows)
    wave = np.repeat(np.sin(yy * 2 * math.pi).astype(np.float32), cv.n, axis=1)
    cv.rgb *= (1 + wave[:, :, None] * -.05)
    cv.h = (wave * .012 + bt.pnoise(cv.n, 22, np.random.default_rng(99)) * .02).astype(np.float32)
    fr = np.random.default_rng(17)
    cv.paint(lambda d, r, n: bt.dots(d, fr, n, 260, ['8C6746', '7E5A3C', 'B09468'], (1, 3), (60, 130)))
    return cv


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('  python ')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--out', default=None)
    ap.add_argument('--stage', default=None)
    ap.add_argument('--ss', type=int, default=3)
    a = ap.parse_args()
    out = Path(a.out) if a.out else fc.masters(fc.stage_root(a.stage))['tiles']
    out.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    meta = {'field_grass': bt.bake_terrain('field_grass', terrain_field_grass(), out, a.ss)}
    (out / 'tiles_farm.json').write_text(json.dumps(meta, indent=1))
    print('baked field_grass %.1fs -> %s' % (time.time() - t0, meta['field_grass']))
    return 0


if __name__ == '__main__':
    sys.exit(main())
