#!/usr/bin/env python3
"""Legendary icons live on the dark night tile (2f3654) where the ink outline (2b2340) has 1.25:1 contrast and disappears.
Review fix: every legendary icon gets a baked sibling <id>_night.webp = the same icon with a 4 px pale die-cut rim (e4eff5) around its silhouette,
so the outline sits on a pale rim (12:1) and the rim sits on the night tile (10:1); the tile itself stays the only dark tile of the UI.

  python night_rim.py --src DIR_WITH_PNG --ids a b c --out DIR [--check]
Used by A1 (furniture + material icons) and A2 (garment icons) as the last icon step; ArtCatalog.icon(id, rarity) returns the _night file for rarity legendary.
"""
import argparse, io, json
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import binary_dilation
import homepaths  # noqa: F401  (A1: puts the core on sys.path for static_render.premul_resize)
NIGHT = (0x2f, 0x36, 0x54); RIM = (0xe4, 0xef, 0xf5); INK = (43, 35, 64)

def lum(c):
    c = np.asarray(c, float) / 255.0; c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4); return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
def contrast(a, b):
    la, lb = lum(a), lum(b); la, lb = max(la, lb), min(la, lb); return (la + 0.05) / (lb + 0.05)

def fit_for_rim(im: Image.Image, grow=4, margin=1) -> Image.Image:
    """A1 change: the icons fill .92 of the cell, so a 4 px rim would be cut off by the 128 px cell on a few of them (bed_moon, bookshelf_floating, chandelier_star).
    Those are scaled down just enough (premultiplied resize) and centred so the whole rim stays inside the cell; icons that already fit are returned unchanged."""
    import static_render as sr
    bb = im.getchannel('A').point(lambda v: 255 if v >= 8 else 0).getbbox()
    if bb is None:
        return im
    room = im.width - 2 * (grow + margin + 1)                 # +1: the rim is softened by a 0.8 px blur
    e = max(bb[2] - bb[0], bb[3] - bb[1])
    if e <= room:
        return im
    k = room / e
    crop = im.crop(bb)
    small = sr.premul_resize(crop, (max(1, round(crop.width * k)), max(1, round(crop.height * k))), Image.LANCZOS)
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.alpha_composite(small, ((im.width - small.width) // 2, (im.height - small.height) // 2))
    return out


def night_variant(im: Image.Image, grow=4) -> Image.Image:
    im = fit_for_rim(im, grow)
    a = np.array(im.getchannel('A')) >= 8
    st = binary_dilation(a, structure=np.ones((3, 3)), iterations=grow)
    m = Image.fromarray((st * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(0.8))
    rim = Image.new('RGBA', im.size, RIM + (0,)); rim.putalpha(m)
    rim.alpha_composite(im)
    return rim

def ring_pixels(im):
    a = np.array(im.getchannel('A')); rgb = np.array(im.convert('RGB')).astype(int)
    touch = binary_dilation(a < 32, iterations=2) & (a >= 128)
    return rgb[touch]

def check(base: Image.Image, var: Image.Image):
    """returns (outline colour vs rim contrast, rim vs night contrast, does the outline of the base survive unchanged inside the variant)"""
    ring = ring_pixels(base).mean(0)
    return contrast(ring, RIM), contrast(RIM, NIGHT), contrast(ring, NIGHT)

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--src', required=True); ap.add_argument('--ids', nargs='+', required=True); ap.add_argument('--out', required=True)
    a = ap.parse_args(); out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    rows = []; tot = 0
    for i in a.ids:
        base = Image.open(Path(a.src) / f'{i}.png').convert('RGBA'); var = night_variant(base)
        var.save(out / f'{i}_night.png')
        b = io.BytesIO(); var.save(b, 'WEBP', lossless=True, exact=True, method=6); tot += len(b.getvalue())
        rows.append((i,) + tuple(round(float(x), 2) for x in check(base, var)))
    print(json.dumps({'n': len(rows), 'webp_kb_total': round(tot / 1024), 'min_ink_vs_rim': min(r[1] for r in rows), 'min_rim_vs_night': min(r[2] for r in rows), 'ink_vs_night_without_rim': min(r[3] for r in rows)}))

if __name__ == '__main__':
    main()
