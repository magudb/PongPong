#!/usr/bin/env python3
"""Compare two baked character folders clip by clip (the P08 gate: the fox rebuilt from source equals the shipped pack).

  python tools/art/core/compare_sheets.py REBUILT_DIR PACK_DIR [--clips idle walk ...] [--max-mean 0.01]
                                          [--out compare.png] [--rows 0 7] [--frames 4]

For every clip present in both folders (PNG masters or WebP) it prints
  * mean : mean absolute error over the NON-TRANSPARENT pixels (alpha > 0 in either sheet), premultiplied RGBA, 0..1.
           This is the strict number the gate uses ("identical within 1 % mean error").
  * all  : the same error averaged over every pixel of the sheet (dominated by empty background, so much smaller).
  * p99  : 99th percentile of the per-pixel error over the non-transparent pixels, and the share of pixels off by more than 8/255.
  * meta : animations.json frames/fps/loop of the clip must be equal.
Exit code 1 when any clip is above --max-mean or the metadata differs.  --out writes a sheet: pack | rebuilt | 8x difference.
The pack stores lossy WebP (q97), a fresh bake is lossless PNG: a floor of a few tenths of a percent is encoding, not drift.
"""
import argparse, json, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

import artpaths


def load(d: Path, clip: str):
    for ext in ('.png', '.webp'):
        p = d / (clip + ext)
        if p.exists():
            return Image.open(p).convert('RGBA')
    return None


def premul(im: Image.Image) -> np.ndarray:
    a = np.asarray(im, np.float32) / 255.0
    a[..., :3] *= a[..., 3:4]
    return a


def compare(ra: np.ndarray, rb: np.ndarray):
    diff = np.abs(ra - rb)                       # H x W x 4, 0..1
    px = diff.mean(axis=2)                       # per-pixel mean over the four channels
    mask = (ra[..., 3] > 0) | (rb[..., 3] > 0)
    n = int(mask.sum())
    mean = float(px[mask].mean()) if n else 0.0
    allm = float(px.mean())
    p99 = float(np.percentile(px[mask], 99)) if n else 0.0
    off8 = float((diff.max(axis=2)[mask] > 8 / 255).mean()) if n else 0.0
    return mean, allm, p99, off8, n


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('Exit code')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('rebuilt'); ap.add_argument('pack')
    ap.add_argument('--clips', nargs='*'); ap.add_argument('--max-mean', type=float, default=0.01)
    ap.add_argument('--out'); ap.add_argument('--rows', nargs='*', type=int, default=[0, 7]); ap.add_argument('--frames', type=int, default=4)
    a = ap.parse_args()
    A, B = Path(a.rebuilt), Path(a.pack)
    ma = json.loads((A / 'animations.json').read_text())['animations']
    mb = json.loads((B / 'animations.json').read_text())['animations']
    clips = a.clips or [c for c in mb if c in ma]
    if not clips:
        print('ERROR: no common clips'); sys.exit(2)
    bad = 0; worst = 0.0; strips = []
    print(f'{"clip":<12}{"mean":>9}{"all":>9}{"p99":>9}{">8/255":>9}  meta')
    for clip in clips:
        ia, ib = load(A, clip), load(B, clip)
        if ia is None or ib is None:
            print(f'{clip:<12} MISSING in {"rebuilt" if ia is None else "pack"}'); bad += 1; continue
        if ia.size != ib.size:
            print(f'{clip:<12} SIZE {ia.size} != {ib.size}'); bad += 1; continue
        ra, rb = premul(ia), premul(ib)
        mean, allm, p99, off8, n = compare(ra, rb)
        meta_eq = all(ma[clip].get(k) == mb[clip].get(k) for k in ('frames', 'fps', 'loop'))
        ok = mean <= a.max_mean and meta_eq
        bad += (not ok); worst = max(worst, mean)
        print(f'{clip:<12}{mean * 100:8.3f}%{allm * 100:8.3f}%{p99 * 100:8.2f}%{off8 * 100:8.2f}%  {"equal" if meta_eq else "DIFFERENT"}{"" if ok else "   <-- FAIL"}')
        if a.out:
            for r in a.rows:
                for f in range(min(a.frames, ia.width // 256)):
                    box = (f * 256, r * 256, f * 256 + 256, r * 256 + 256)
                    d = np.clip(np.abs(ra - rb)[box[1]:box[3], box[0]:box[2], :3].max(axis=2) * 8, 0, 1)
                    dimg = Image.fromarray(np.uint8(d * 255)).convert('RGBA')
                    strips.append((f'{clip} r{r} f{f}', ib.crop(box), ia.crop(box), dimg))
    print(f'worst clip: {worst * 100:.3f} % (limit {a.max_mean * 100:.1f} %)  ->  {"PASS" if bad == 0 else "FAIL"}')
    if a.out and strips:
        cols = min(len(strips), 4)
        rows = (len(strips) + cols - 1) // cols
        cw = 256 * 3 + 8
        sheet = Image.new('RGBA', (cols * cw, rows * 274), '#f4efe3')
        d = ImageDraw.Draw(sheet)
        for i, (label, pk, rb_, df) in enumerate(strips):
            x, y = (i % cols) * cw, (i // cols) * 274
            d.text((x + 4, y + 2), f'{label}: pack | rebuilt | 8x diff', fill=(60, 50, 70, 255))
            sheet.alpha_composite(pk, (x, y + 16)); sheet.alpha_composite(rb_, (x + 256, y + 16))
            dd = Image.new('RGBA', (256, 256), (20, 20, 30, 255)); dd.alpha_composite(df.convert('RGBA'), (0, 0))
            sheet.alpha_composite(dd, (x + 512, y + 16))
        Path(a.out).parent.mkdir(parents=True, exist_ok=True)
        sheet.convert('RGB').save(a.out); print('wrote', a.out, sheet.size)
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
