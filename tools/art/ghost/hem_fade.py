#!/usr/bin/env python3
"""hem_fade.py SRC_MASTERS ID DST_MASTERS NEWID [--px 16] [--min 0.30]      A DOCUMENTED NON-FEATURE: the translucent hem experiment, REJECTED.  Nothing calls this.

What it did: copied the masters of ID to NEWID and multiplied the alpha of the lowest `px` rows of every frame (rows from the lowest figure pixel up) by a smooth ramp from
`min` at the bottom edge to 1.0, in every clip and direction, so the hem of the bell fades into the ground like mist.  Screen-space on purpose: the camera is orthographic at 36
degrees, so "the bottom of the figure on the screen" is the hem in all eight directions.  The outline (already composited by the baker) fades with the sheet.

Verdict (design4, repeated in tools/art/ghost/README.md): built, baked (a 5.6 px band at zoom 0.4), exported through the same exporter (WebP alpha_quality 100), imported as S3TC
(compress/mode=2, fix_alpha_border=true; DXT5 keeps 8 interpolated alpha levels per 4 x 4 block, so the ramp survives) and compared in the real game next to the opaque hem at
zoom 0.4 and 0.9: NO visible difference at game scale, and it dims the scalloped trim.  REJECTED; the shipped sheets are opaque.  If it is ever wanted: a `hem_fade` stat in the
baker (P08) applied after the outline, the validator unchanged (it only checks the cell border), S3TC fine.  Kept as a record, like design4/scripts/hem_fade.py it was lifted from.
Run with python -I (Pillow + numpy only).
"""
import json, shutil, sys
from pathlib import Path
from PIL import Image
import numpy as np

src, cid, dst, new = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3]), sys.argv[4]
px = int(sys.argv[sys.argv.index('--px') + 1]) if '--px' in sys.argv else 16
amin = float(sys.argv[sys.argv.index('--min') + 1]) if '--min' in sys.argv else .30
out = dst / new
if out.exists():
    shutil.rmtree(out)
out.mkdir(parents=True)
for f in (src / cid).iterdir():
    if f.suffix == '.png' and f.name not in ('full_idle.png',):
        im = Image.open(f).convert('RGBA')
        a = np.asarray(im).copy()
        w, h = im.size
        for r in range(h // 256):
            for c in range(w // 256):
                cell = a[r * 256:(r + 1) * 256, c * 256:(c + 1) * 256]
                ys = np.where(cell[..., 3] > 24)[0]
                if len(ys) == 0:
                    continue
                yb = ys.max()
                for y in range(max(0, yb - px), yb + 1):
                    t = (yb - y) / px                       # 0 at the bottom edge .. 1 px rows up
                    k = amin + (1 - amin) * (t * t * (3 - 2 * t))
                    cell[y, :, 3] = (cell[y, :, 3] * k).astype('uint8')
        Image.fromarray(a, 'RGBA').save(out / f.name, compress_level=6)
meta = json.load(open(src / cid / 'animations.json'))
meta['character'] = new
json.dump(meta, open(out / 'animations.json', 'w'), indent=2)
print('wrote', out)
