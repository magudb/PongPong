#!/usr/bin/env python3
"""occluder_equality.py ROOT ID_A ID_B -> how identical the silhouettes (alpha > 24) of two baked heroes are, over every clip, all 8 directions and every frame.

  tools/art/.venv/bin/python -I tools/art/ghost/occluder_equality.py assets/isometric_characters ghost_bu ghost_hviske
  -> ghost_bu vs ghost_hviske: total differing silhouette pixels 1460 of 5370860 figure pixels (0.027 %), all inside the face band (y 60..130) ...

The wardrobe package A2 may share garment layers between two bases only when their occluder alpha is (nearly) identical.  The two ghost heroes are ONE silhouette on
purpose: they differ only by colour, hem trim, blush and Hviske's shy glance (pupils a little down).  Measured on the masters: 1460 of 5 370 860 figure pixels (0.027 %),
ALL of them in the face band (rows y 60..130) of the W / E direction rows; A2's rule is relaxed for the two ghosts to "<= 0.05 % and none below the neck line" (y > 130).
Importable: `silhouette_diff(root, a, b) -> dict`.  Lifted from design4/scripts/occluder_equality.py (python -I; Pillow + numpy).
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

NECK_LINE_Y = 130           # rows below this line (y in the 256 px cell) must be identical
FACE_BAND = (60, 130)       # the shy pupils live here


def silhouette_diff(root, a, b):
    root = Path(root)
    tot_diff = tot_area = 0
    worst = (0, '', 0.0)
    lowest_diff_y = -1          # the lowest cell row (y) at which ANY pair of frames differs
    highest_diff_y = 999
    for f in sorted((root / a).glob('*.png')) or sorted(p for p in (root / a).glob('*.webp') if p.name != 'portrait.webp'):
        if f.name in ('full_idle.png', 'portrait.png', 'portrait.webp'):
            continue
        sa = np.asarray(Image.open(f).convert('RGBA'))[..., 3] > 24
        sb = np.asarray(Image.open(root / b / f.name).convert('RGBA'))[..., 3] > 24
        n = sa.shape[1] // 256
        for r in range(8):
            for c in range(n):
                A = sa[r * 256:(r + 1) * 256, c * 256:(c + 1) * 256]
                B = sb[r * 256:(r + 1) * 256, c * 256:(c + 1) * 256]
                diff = A ^ B
                d = int(diff.sum())
                ar = int(A.sum())
                tot_diff += d
                tot_area += ar
                if d:
                    ys = np.where(diff.any(axis=1))[0]
                    lowest_diff_y = max(lowest_diff_y, int(ys.max()))
                    highest_diff_y = min(highest_diff_y, int(ys.min()))
                if d > worst[0]:
                    worst = (d, f'{f.stem} row {r} frame {c}', d / max(ar, 1))
    return {'diff_px': tot_diff, 'area_px': tot_area, 'share': tot_diff / max(tot_area, 1), 'worst': worst,
            'lowest_diff_y': lowest_diff_y, 'highest_diff_y': highest_diff_y if lowest_diff_y >= 0 else -1}


if __name__ == '__main__':
    root, a, b = sys.argv[1], sys.argv[2], sys.argv[3]
    r = silhouette_diff(root, a, b)
    print(f"{a} vs {b}: total differing silhouette pixels {r['diff_px']} of {r['area_px']} figure pixels ({r['share'] * 100:.3f} %); "
          f"worst frame {r['worst'][1]}: {r['worst'][0]} px ({r['worst'][2] * 100:.2f} % of that figure); the differing pixels lie in rows y {r['highest_diff_y']}..{r['lowest_diff_y']}")
