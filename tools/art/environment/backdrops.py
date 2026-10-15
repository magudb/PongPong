#!/usr/bin/env python3
"""Backdrops of the floating-treetop look (P22 task 4; acceptance 2 'visible sky'): <theme>_sky.webp (a gradient sky with soft clouds, 1920 x 1080) and
<theme>_far.webp (a blurred far canopy, seamless horizontally, 2048 x 1280 with a soft transparent top edge) used by IsoArea as two Parallax2D layers behind the platform
(ArtCatalog.backdrop(theme)).  Painted with Pillow / numpy, deterministic (fixed seeds).

  python tools/art/environment/backdrops.py [--out assets/backdrops] [--preview DIR] [themes...]       themes: hyggebyen forest (default: both)

THEMES OF THIS PACKAGE: hyggebyen = lavender dusk, forest = night navy with haze (the iso fallback of Moerkeskoven; the ortho floors have no backdrop).
NOT HERE: the farm (farm_sky / farm_far / farm_canopy) belongs to N03-farm-art (TOWNS addendum RT16 carve-out) and the treetop city (treetop_*) to V5; until
those land ArtCatalog serves the painted placeholder gradient for `farm` / `treetop` and lists them in missing().
The files are written straight to assets/backdrops/ (a backdrop is not a baked sprite: there is no master / export step; WebP q92, imported with mipmaps by
the project default).
"""
from __future__ import annotations
import argparse
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
SKY_W, SKY_H = 1920, 1080
FAR_W, FAR_H = 2048, 1280


def hexrgb(c): return np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


THEMES = {
    # lavender dusk: the guide's Hyggebyen palette (lavender / rose) over a warm horizon
    'hyggebyen': dict(sky=[(0.0, '8f84d6'), (.38, 'b9a6e8'), (.72, 'e9c6e6'), (1.0, 'fbe0d8')], cloud=(255, 236, 246), cloud2=(255, 214, 226), cloud_a=.5, sun=('ffe3c8', .55, .86),
                      stars=0, far=('a98fd0', '8e78c4', 'c9b2e6'), mist='f2dff0', far_alpha=.92, seed=11),
    # night navy with haze: the forest grade of the sketch (#1c2138 clear colour), a little lantern-teal in the mist
    'forest': dict(sky=[(0.0, '0c1124'), (.45, '161d36'), (.8, '24304e'), (1.0, '34506a')], cloud=(78, 96, 140), cloud2=(60, 84, 110), cloud_a=.35, sun=('6fd6c4', .16, .95),
                   stars=140, far=('1c2a40', '26364e', '2f4a5a'), mist='3a5c6a', far_alpha=.95, seed=23),
}


def gradient(stops, w, h):
    t = np.linspace(0, 1, h, dtype=np.float32)
    xs = [s[0] for s in stops]
    cols = np.stack([hexrgb(s[1]) for s in stops])
    col = np.stack([np.interp(t, xs, cols[:, k]) for k in range(3)], -1)
    return np.repeat(col[:, None, :], w, 1)


def soft_blobs(size, color, boxes, blur, alpha):
    layer = Image.new('RGBA', size, tuple(color) + (0,)); m = Image.new('L', size, 0); d = ImageDraw.Draw(m)
    for b in boxes:
        d.ellipse(b, fill=255)
    m = m.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * alpha)); layer.putalpha(m)
    return layer


def sky(theme: str) -> Image.Image:
    p = THEMES[theme]
    rng = np.random.default_rng(p['seed'])
    arr = gradient(p['sky'], SKY_W, SKY_H)
    im = Image.fromarray(np.uint8(np.clip(arr, 0, 255)), 'RGB').convert('RGBA')
    # a glow near the horizon (the sun behind the canopy for the dusk, a pale lantern-teal haze for the night)
    gc, ga, gy = p['sun']
    glow = Image.new('RGBA', (SKY_W, SKY_H), tuple(int(v) for v in hexrgb(gc)) + (0,)); m = Image.new('L', (SKY_W, SKY_H), 0)
    ImageDraw.Draw(m).ellipse((SKY_W * .15, SKY_H * (gy - .22), SKY_W * .85, SKY_H * (gy + .22)), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(120)).point(lambda v: int(v * ga)); glow.putalpha(m)
    im.alpha_composite(glow)
    # soft cloud banks: long flat blobs in two layers (the second one smaller, more transparent)
    for k, (n, wmin, wmax, col, al) in enumerate(((9, 420, 900, p['cloud'], p['cloud_a']), (12, 220, 520, p['cloud2'], p['cloud_a'] * .7))):
        for _ in range(n):
            cx, cy = rng.uniform(0, SKY_W), rng.uniform(SKY_H * .08, SKY_H * .78)
            sx = rng.uniform(wmin, wmax); sy = sx * rng.uniform(.12, .2)
            boxes = [(cx - sx / 2 + j * sx * .22, cy - sy * (1 - .5 * abs(j - 2) / 3), cx + sx / 2 + j * sx * .22, cy + sy * (1 - .5 * abs(j - 2) / 3)) for j in range(-2, 3)]
            im.alpha_composite(soft_blobs((SKY_W, SKY_H), col, boxes, 26 + 10 * k, al))
    if p['stars']:
        st = Image.new('RGBA', (SKY_W, SKY_H), (0, 0, 0, 0)); d = ImageDraw.Draw(st)
        for _ in range(p['stars']):
            x, y = rng.uniform(0, SKY_W), rng.uniform(0, SKY_H * .7); r = rng.uniform(.8, 2.2)
            d.ellipse((x - r, y - r, x + r, y + r), fill=(220, 230, 255, int(rng.uniform(70, 190))))
        im.alpha_composite(st.filter(ImageFilter.GaussianBlur(.7)))
    return im.convert('RGB')


def _blob(layer, cx, cy, rx, ry, color, blur, alpha):
    """Composite one soft ellipse into `layer` (RGBA) touching only its bounding box (cheap, and never blurred against the canvas edge)."""
    m = int(blur * 3) + 2
    x0, y0 = int(cx - rx) - m, int(cy - ry) - m
    x1, y1 = int(cx + rx) + m, int(cy + ry) + m
    w, h = x1 - x0, y1 - y0
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).ellipse((m, m, w - m, h - m), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * alpha))
    small = Image.new('RGBA', (w, h), tuple(color) + (0,)); small.putalpha(mask)
    # clip to the layer
    cx0, cy0, cx1, cy1 = max(x0, 0), max(y0, 0), min(x1, layer.width), min(y1, layer.height)
    if cx1 <= cx0 or cy1 <= cy0:
        return
    small = small.crop((cx0 - x0, cy0 - y0, cx1 - x0, cy1 - y0))
    region = layer.crop((cx0, cy0, cx1, cy1)); region.alpha_composite(small)
    layer.paste(region, (cx0, cy0))


def far(theme: str) -> Image.Image:
    """A blurred far canopy: crown masses (soft ellipses) drawn with horizontal wrap so the left and right edges meet, denser towards the bottom, mist bands, and a transparent
    top edge so the sky stays visible above the treetops.  The layer repeats horizontally only."""
    p = THEMES[theme]
    rng = np.random.default_rng(p['seed'] + 100)
    W, H = FAR_W, FAR_H
    cols = [tuple(int(v) for v in hexrgb(c)) for c in p['far']]
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for i in range(120):
        x = rng.uniform(0, W); y = H * (.22 + .78 * rng.random() ** .8)
        r = rng.uniform(110, 300) * (.7 + .5 * y / H); c = cols[rng.integers(len(cols))]
        for dx in (-W, 0, W):
            _blob(layer, x + dx, y, r * 1.3, r * .8, c, 30, .62)
    mist = tuple(int(v) for v in hexrgb(p['mist']))
    for i in range(7):
        y = H * rng.uniform(.28, .95); w = rng.uniform(900, 1700); x = rng.uniform(0, W)
        for dx in (-W, 0, W):
            _blob(layer, x + dx, y, w / 2, 50, mist, 46, .4)
    a = np.asarray(layer, np.float32) / 255.0
    ramp = np.clip((np.arange(H, dtype=np.float32) / H - .14) / .26, 0, 1) ** 1.4
    a[..., 3] *= ramp[:, None] * p['far_alpha']
    blobs = Image.fromarray(np.uint8(np.clip(a * 255 + .5, 0, 255)), 'RGBA')
    # the bottom is solid: whatever the platform floats over never shows the clear colour
    solid_a = np.clip((np.arange(H, dtype=np.float32) / H - .62) / .3, 0, 1) * .96
    solid = np.zeros((H, W, 4), np.float32); solid[..., :3] = hexrgb(p['far'][1]) / 255.0; solid[..., 3] = solid_a[:, None]
    base = Image.fromarray(np.uint8(np.clip(solid * 255 + .5, 0, 255)), 'RGBA')
    return Image.alpha_composite(base, blobs)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('THEMES OF THIS PACKAGE')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('themes', nargs='*'); ap.add_argument('--out', default=str(REPO / 'assets' / 'backdrops')); ap.add_argument('--preview', default=None)
    a = ap.parse_args()
    themes = a.themes or list(THEMES)
    unknown = [t for t in themes if t not in THEMES]
    if unknown:
        raise SystemExit(f'ERROR: unknown theme {unknown} (this package paints {", ".join(THEMES)}; farm_* is N03, treetop_* is V5)')
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    for t in themes:
        s, f = sky(t), far(t)
        s.save(out / f'{t}_sky.webp', 'WEBP', quality=92, method=4)
        f.save(out / f'{t}_far.webp', 'WEBP', quality=92, method=4, alpha_quality=100)
        print(t, 'sky', s.size, (out / f'{t}_sky.webp').stat().st_size // 1024, 'KB', 'far', f.size, (out / f'{t}_far.webp').stat().st_size // 1024, 'KB')
        if a.preview:
            pv = Path(a.preview); pv.mkdir(parents=True, exist_ok=True)
            comp = Image.new('RGB', (SKY_W, SKY_H)); comp.paste(s, (0, 0))
            tile = Image.new('RGBA', (FAR_W * 2, FAR_H)); tile.paste(f, (0, 0)); tile.paste(f, (FAR_W, 0))        # two repeats: the seam must not show
            c2 = comp.convert('RGBA'); c2.alpha_composite(tile.crop((1024, 0, 1024 + SKY_W, FAR_H)).resize((SKY_W, int(FAR_H * 1.0))).crop((0, 0, SKY_W, SKY_H)), (0, int(SKY_H * .28)))
            c2.convert('RGB').resize((960, 540), Image.LANCZOS).save(pv / f'{t}_backdrop_preview.png')


if __name__ == '__main__':
    main()
