#!/usr/bin/env python3
"""bob_probe.py ROOT ID CLIP ROW -> the top / bottom row of the figure (alpha > 24) per frame, so the vertical bob of a clip is a number (px of the 256 px cell).

  tools/art/.venv/bin/python -I tools/art/ghost/bob_probe.py assets/isometric_characters ghost_bu walk 7      # the glide: bottom bob 5 px (fox 3, hobbit 2)
  tools/art/.venv/bin/python -I tools/art/ghost/bob_probe.py assets/isometric_characters fox walk 7

The stock-rig walk of the ghost is a gentle glide (hips bob x3 of the stock bob): the baked bob is the only vertical motion the clip has (the runtime adds +-2.5 px,
G-ghost-play).  Importable: `bob(root, cid, clip, row) -> (tops, bottoms)`.  Lifted from design4/scripts/bob_probe.py.
"""
import sys
from pathlib import Path
from PIL import Image
import numpy as np


def bob(root, cid, clip, row):
    p = Path(root) / cid / f'{clip}.png'
    if not p.exists():
        p = Path(root) / cid / f'{clip}.webp'
    sh = Image.open(p).convert('RGBA')
    n = sh.size[0] // 256
    tops, bots = [], []
    for f in range(n):
        a = np.asarray(sh.crop((f * 256, row * 256, f * 256 + 256, row * 256 + 256)))[..., 3] > 24
        ys = np.where(a.any(axis=1))[0]
        tops.append(int(ys.min()))
        bots.append(int(ys.max()))
    return tops, bots


if __name__ == '__main__':
    root, cid, clip, row = Path(sys.argv[1]), sys.argv[2], sys.argv[3], int(sys.argv[4])
    tops, bots = bob(root, cid, clip, row)
    print(cid, clip, 'row', row, 'top', tops, 'bottom', bots, 'bob range top', max(tops) - min(tops), 'bottom', max(bots) - min(bots))
