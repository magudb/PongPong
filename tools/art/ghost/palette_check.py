#!/usr/bin/env python3
"""palette_check.py ROOT ID HEX  -> CIEDE2000 between the declared palette hex and the dominant (median) colour of the figure of the idle S frame.

  tools/art/.venv/bin/python -I tools/art/ghost/palette_check.py assets/isometric_characters ghost_bu E6EFFF      # dE00 1.3  (gate <= 6)
  tools/art/.venv/bin/python -I tools/art/ghost/palette_check.py assets/isometric_characters ghost_hviske F6E7F6  # dE00 1.1

Only fully opaque pixels count (not the outline blend); the figure's brightest 45 % of them are the sheet (head + bell), their median is "the
dominant colour".  The art spec's palette gate is dE00 <= 6 (the bake darkens by 0.92-0.97: lights 0.74 + 0.31 + 0.56 and ambient .44).  Importable:
`de2000`, `srgb2lab`, `dominant_colour(cell)`, `palette_de(root, cid, hex)`.  Lifted from design4/scripts/palette_check.py (python -I; numpy + Pillow).
"""
import math
import sys
from pathlib import Path
import numpy as np
from PIL import Image

DE_GATE = 6.0


def srgb2lab(rgb):
    c = np.asarray(rgb, float) / 255.0
    c = np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)
    M = np.array([[.4124564, .3575761, .1804375], [.2126729, .7151522, .0721750], [.0193339, .1191920, .9503041]])
    xyz = M @ c / np.array([.95047, 1.0, 1.08883])
    f = np.where(xyz > .008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.array([116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])])


def de2000(l1, l2):
    L1, a1, b1 = l1; L2, a2, b2 = l2
    C1, C2 = math.hypot(a1, b1), math.hypot(a2, b2); Cb = (C1 + C2) / 2
    G = .5 * (1 - math.sqrt(Cb ** 7 / (Cb ** 7 + 25 ** 7)))
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360; h2p = math.degrees(math.atan2(b2, a2p)) % 360
    dLp = L2 - L1; dCp = C2p - C1p
    dh = h2p - h1p
    if C1p * C2p == 0: dh = 0
    elif dh > 180: dh -= 360
    elif dh < -180: dh += 360
    dHp = 2 * math.sqrt(C1p * C2p) * math.sin(math.radians(dh / 2))
    Lbp = (L1 + L2) / 2; Cbp = (C1p + C2p) / 2
    hs = h1p + h2p
    if C1p * C2p == 0: hbp = hs
    elif abs(h1p - h2p) <= 180: hbp = hs / 2
    else: hbp = (hs + 360) / 2 if hs < 360 else (hs - 360) / 2
    T = 1 - .17 * math.cos(math.radians(hbp - 30)) + .24 * math.cos(math.radians(2 * hbp)) + .32 * math.cos(math.radians(3 * hbp + 6)) - .20 * math.cos(math.radians(4 * hbp - 63))
    dth = 30 * math.exp(-(((hbp - 275) / 25) ** 2))
    Rc = 2 * math.sqrt(Cbp ** 7 / (Cbp ** 7 + 25 ** 7))
    Sl = 1 + .015 * (Lbp - 50) ** 2 / math.sqrt(20 + (Lbp - 50) ** 2); Sc = 1 + .045 * Cbp; Sh = 1 + .015 * Cbp * T
    Rt = -math.sin(math.radians(2 * dth)) * Rc
    return math.sqrt((dLp / Sl) ** 2 + (dCp / Sc) ** 2 + (dHp / Sh) ** 2 + Rt * (dCp / Sc) * (dHp / Sh))


def dominant_colour(cell):
    """Median RGB of the brightest 45 % of the fully opaque pixels of a 256 x 256 RGBA cell (an ndarray H x W x 4)."""
    mask = cell[..., 3] == 255
    px = cell[mask][:, :3].astype(float)
    lum = px @ np.array([.299, .587, .114])
    sel = px[lum >= np.percentile(lum, 55)]
    return np.median(sel, axis=0)


def palette_de(root, cid, hexv):
    """(dE00, dominant rgb tuple, wanted rgb tuple) of the idle S frame (row 0, frame 0) of `cid` under `root`."""
    p = Path(root) / cid / 'idle.png'
    if not p.exists():
        p = Path(root) / cid / 'idle.webp'
    cell = np.asarray(Image.open(p).convert('RGBA').crop((0, 0, 256, 256)))
    med = dominant_colour(cell)
    want = np.array([int(hexv[i:i + 2], 16) for i in (0, 2, 4)], float)
    return de2000(srgb2lab(want), srgb2lab(med)), tuple(int(x) for x in med), tuple(int(x) for x in want)


if __name__ == '__main__':
    root, cid, hexv = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
    de, med, want = palette_de(root, cid, hexv)
    print(f'{cid}: declared #{hexv.upper()} {want}  dominant baked {med}  CIEDE2000 {de:.1f}')
