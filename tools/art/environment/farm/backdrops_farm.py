#!/usr/bin/env python3
"""backdrops_farm.py - the treetop backdrop layers of the farm (package N03-farm-art; the prototype is design3/farm/art/backdrops_farm.py, flat blobs; this is the painted-volume pass).  Writes

    farm_far.webp     2048 x 1024   seamless far canopy: three depths of shaded trunks (haze, mid, near), a continuous leaf band along the top built from many small form-shaded
                                    leaf blobs, mist in the lower third and a soft top edge (Parallax2D "Far", scroll 0.5, repeated in x, drawn scaled 1.5)
    farm_canopy.webp  2048 x  360   foreground leaf frame with hanging vines and a faded lower edge (a CanvasLayer strip along the top of the screen; N02's canopy handler draws it)

  python tools/art/environment/farm/backdrops_farm.py [--out DIR] [--previews DIR]

Default out: <N03 stage>/masters/backdrops (install_farm.py copies the two files to assets/backdrops).  Everything is drawn with wrap-around in x and blurred with a wrapping blur
(PIL's own blur clamps at the image edge and would leave a seam where the layer repeats).  Palette = the style guide's Himmel a9d3e0 / Mosgroen 6b9a3e / Pergament f4e6c4; the guide's
sketch (miljoer_v2: huge trunks, a green forest of vertical stripes behind them, a leaf canopy with vines along the top) is the reference for the composition.

NO farm_sky.webp is written, ever (lead amendment M1a, 2026-10-14): Codex's painted assets/backdrops/farm_sky.png is the farm sky and ArtCatalog loads <theme>_sky.webp first, so a webp
here would shadow it.  A plain gradient sky is painted in memory for the preview composites only (PNG, previews folder, named preview_*).

Deviation from the prototype (said plainly in the README and the report): the prototype's far layer was 70 flat ellipses on straight rectangles; the contract (size, seamless in x,
distant trunks, leaf masses, mist, soft top edge, faded canopy edge) is unchanged, the look is not.  Same size, so the memory budget is the same.
"""
from __future__ import annotations
import argparse
import math
import sys
from pathlib import Path

import farm_common as fc                       # noqa: E402

import numpy as np                              # noqa: E402
from PIL import Image, ImageDraw, ImageFilter   # noqa: E402

W, H = 2048, 1024
HAZE = (226, 240, 220)


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def wrap_blur(img: Image.Image, radius: float) -> Image.Image:
    """GaussianBlur that wraps in x: three copies side by side are blurred and the middle one is cut out, so the layer repeats without a seam."""
    w, h = img.size
    big = Image.new('RGBA', (3 * w, h))
    for k in range(3):
        big.paste(img, (k * w, 0))
    return big.filter(ImageFilter.GaussianBlur(radius)).crop((w, 0, 2 * w, h))


def ramp(dark, mid, light, s):
    s = min(max(s, 0.0), 1.0)
    if s < .5:
        k = s * 2
        return tuple(int(dark[i] + (mid[i] - dark[i]) * k) for i in range(3))
    k = (s - .5) * 2
    return tuple(int(mid[i] + (light[i] - mid[i]) * k) for i in range(3))


def trunk_layer(rng, xs, widths, top, dark, light, alpha, taper=.12, flare=True, height=H):
    """Shaded, streaked tree trunks (cylinder profile lit from the left, vertical bark streaks, a root flare at the foot), wrapped in x.  Returns float RGBA (rgb and alpha 0..255)."""
    out = np.zeros((height, W, 4), np.float32)
    yy = np.arange(height, dtype=np.float32)[:, None]
    dark = np.array(dark, np.float32)
    light = np.array(light, np.float32)
    for x, w in zip(xs, widths):
        seed = int(rng.integers(0, 1 << 30))
        r2 = np.random.default_rng(seed)
        n1 = np.convolve(r2.random(int(w) + 8).astype(np.float32), np.ones(3) / 3, mode='same')
        sway = 6 * np.sin(yy / 170.0 + seed % 7)
        grow = 1 - taper * (1 - ((yy - top) / (height - top)).clip(0, 1))
        foot = 1 + 0.55 * (((yy - (height - 260)) / 260).clip(0, 1) ** 2) if flare else 1.0
        wy = w * grow * foot
        for ox in (-W, 0, W):
            lo, hi = int(x + ox - w * 1.6), int(x + ox + w * 1.6)
            if hi < 0 or lo > W:
                continue
            sl = slice(max(lo, 0), min(hi, W))
            xs_ = np.arange(sl.start, sl.stop, dtype=np.float32)[None, :]
            t = (xs_ - (x + ox + sway - wy / 2)) / np.maximum(wy, 1)           # 0 left edge .. 1 right edge
            inside = ((t >= 0) & (t <= 1) & (yy >= top)).astype(np.float32)
            edge = (np.minimum(t, 1 - t) * wy / 3.0).clip(0, 1)                # 3 px soft edge
            a = inside * edge * alpha
            tc = t.clip(0, 1)
            streak = n1[(tc * (len(n1) - 1)).astype(np.int32)]
            shade = (1.05 - .55 * tc ** 1.4 - .10 * (tc < .12) + (streak - .5) * .35 + .06 * np.sin(tc * 40 + yy / 120.0)).clip(.25, 1.25)
            mix = (shade - .25).clip(0, 1)[..., None]
            col = dark * (1 - mix) + light * mix
            cur = out[:, sl]
            ca = cur[..., 3:4]
            na = a[..., None] + ca * (1 - a[..., None])
            cur[..., :3] = (col * a[..., None] + cur[..., :3] * ca * (1 - a[..., None])) / np.maximum(na, 1e-5)
            cur[..., 3:4] = na
    out[..., 3] *= 255.0
    return out


def mass(d, rng, cx, cy, rx, ry, count, pal, alpha=240, rmin=9, rmax=22):
    """A foliage mass: many small leaf blobs scattered in an ellipse, tone by position (lit upper left, dark underside) so that it reads as ONE volume; wrapped in x."""
    dark, mid, light = pal
    blobs = []
    for _ in range(count):
        a = rng.uniform(0, 2 * math.pi)
        rr = math.sqrt(rng.uniform(0, 1)) ** .85
        px, py = cx + math.cos(a) * rx * rr, cy + math.sin(a) * ry * rr
        nx, ny = (px - cx) / rx, (py - cy) / ry
        s = .52 + .5 * (-ny * .75 - nx * .35) + rng.uniform(-.16, .16)
        blobs.append((py, px, rng.uniform(rmin, rmax), ramp(dark, mid, light, s)))
    blobs.sort()
    for ox in (-W, 0, W):
        if cx + ox + rx * 1.1 < 0 or cx + ox - rx * 1.1 > W:
            continue
        for py, px, r, col in blobs:
            x = px + ox
            d.ellipse((x - r - 1.5, py - r * .82 - 1.5, x + r + 1.5, py + r * .82 + 1.5), fill=tuple(int(c * .72) for c in col) + (int(alpha * .6),))
            d.ellipse((x - r, py - r * .82, x + r, py + r * .82), fill=col + (alpha,))


def canopy_band(rng, y0, y1, rows, pal, alpha, rscale=1.0, extra=None, height=H):
    """The continuous leaf band along the top of a depth layer (masses side by side with gaps) + masses at given (x, y, rx, ry)."""
    img = Image.new('RGBA', (W, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, 'RGBA')
    for row in range(rows):
        y = y0 + (y1 - y0) * row / max(rows - 1, 1)
        n = int(W / (150 * rscale))
        for i in range(n):
            mass(d, rng, (i + rng.uniform(.1, .9)) * W / n, y + rng.uniform(-30, 30), rng.uniform(90, 150) * rscale, rng.uniform(55, 95) * rscale, int(70 * rscale * rscale + 40), pal, alpha,
                 7 * rscale, 17 * rscale)
    for (x, y, rx, ry) in (extra or []):
        mass(d, rng, x, y, rx, ry, int(rx * ry / 170), pal, alpha, 8 * rscale, 19 * rscale)
    return img


def tops(xs, ws, top, k=1.5):
    return [(x, top + 25, w * k, w * k * .6) for x, w in zip(xs, ws)]


def haze(img: Image.Image, h: float) -> Image.Image:
    a = np.asarray(img, np.float32).copy()
    a[..., :3] = a[..., :3] * (1 - h) + np.array(HAZE, np.float32) * h
    return Image.fromarray(np.uint8(np.clip(a, 0, 255)), 'RGBA')


def to_image(arr: np.ndarray) -> Image.Image:
    return Image.fromarray(np.uint8(np.clip(arr, 0, 255)), 'RGBA')


def far() -> Image.Image:
    rng = np.random.default_rng(7)
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    # --- depth A: the farthest trunks, blue-green haze
    xsA = np.linspace(40, W - 40, 13) + rng.uniform(-40, 40, 13)
    wA = rng.uniform(46, 84, 13)
    A = to_image(trunk_layer(rng, xsA, wA, 220, hexc('6d8a80'), hexc('a9c2b0'), .85))
    A.alpha_composite(canopy_band(rng, 130, 260, 2, (hexc('5e8f84'), hexc('7fae9a'), hexc('a9d2bc')), 215, .75, tops(xsA, wA, 190, 1.7)))
    img.alpha_composite(haze(A, .50))
    # --- depth B: mid
    xsB = np.linspace(110, W - 110, 7) + rng.uniform(-60, 60, 7)
    wB = rng.uniform(96, 150, 7)
    B = to_image(trunk_layer(rng, xsB, wB, 200, hexc('564b36'), hexc('a39a6c'), .93))
    B.alpha_composite(canopy_band(rng, 90, 250, 3, (hexc('3d7440'), hexc('5f9a55'), hexc('a2cc72')), 235, 1.0, tops(xsB, wB, 170, 1.6)))
    img.alpha_composite(haze(B, .26))
    # --- depth C: near, the richest colour
    xsC = np.linspace(250, W - 200, 4) + rng.uniform(-80, 80, 4)
    wC = rng.uniform(170, 240, 4)
    C = to_image(trunk_layer(rng, xsC, wC, 170, hexc('5b3f27'), hexc('b88a5a'), .97))
    C.alpha_composite(canopy_band(rng, 40, 190, 3, (hexc('367232'), hexc('5da043'), hexc('b5dc7c')), 240, 1.35, tops(xsC, wC, 120, 1.5)))
    img.alpha_composite(haze(C, .10))
    img = wrap_blur(img, 1.4)
    # soft top: the layer begins in the upper part of the screen, so its first 240 px fade in from nothing
    arr = np.asarray(img).copy()
    arr[..., 3] = np.uint8(arr[..., 3] * np.clip(np.arange(H) / 240.0, 0, 1)[:, None] ** 1.2)
    img = Image.fromarray(arr, 'RGBA')
    # mist: a light band that fades the lower third (so the far layer melts into the sky)
    a = np.zeros((H, W), np.float32)
    yy = np.arange(H)[:, None]
    a += np.clip((yy - 560) / 380.0, 0, 1) ** 1.2 * .92
    a += np.clip(1 - np.abs(yy - 360) / 90.0, 0, 1) * .14
    mist = np.zeros((H, W, 4), np.uint8)
    mist[..., 0], mist[..., 1], mist[..., 2] = HAZE
    mist[..., 3] = np.uint8(np.clip(a, 0, 1) * 255)
    img.alpha_composite(Image.fromarray(mist, 'RGBA'))
    return img


def canopy() -> Image.Image:
    """The foreground leaf frame: 4 rows of leaf masses along the top, hanging vines with leaf pairs, a faded lower edge."""
    Hc = 360
    rng = np.random.default_rng(11)
    pal = (hexc('3b7a33'), hexc('6b9a3e'), hexc('b6dc7a'))
    img = Image.new('RGBA', (W, Hc), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, 'RGBA')
    for row, (cy, rs, al) in enumerate(((16, 1.5, 255), (62, 1.35, 255), (108, 1.15, 245), (146, .95, 205))):
        n = int(W / (150 * rs))
        for i in range(n):
            mass(d, rng, (i + rng.uniform(.1, .9)) * W / n, cy + rng.uniform(-16, 16), rng.uniform(95, 140) * rs, rng.uniform(40, 62) * rs, int(60 * rs * rs + 40), pal, al, 7 * rs, 16 * rs)
    vine, leaf = hexc('3f7a30'), hexc('8fc255')
    for _ in range(20):                                       # hanging vines with leaf pairs
        x = rng.uniform(0, W)
        L = rng.uniform(60, 170)
        sway = rng.uniform(-10, 10)
        for ox in (-W, 0, W):
            pts = [(x + ox + sway * math.sin(k / 5.0 * math.pi), 125 + L * k / 5.0) for k in range(6)]
            d.line(pts, fill=vine + (235,), width=4, joint='curve')
            for k in range(1, 6):
                px, py = pts[k]
                d.ellipse((px - 13, py - 5, px - 1, py + 5), fill=leaf + (245,))
                d.ellipse((px + 1, py + 2, px + 13, py + 12), fill=tuple(int(c * .85) for c in leaf) + (245,))
    img = wrap_blur(img, 0.9)
    a = np.asarray(img).copy()
    fade = np.clip((Hc - np.arange(Hc)) / 90.0, 0, 1)[:, None]
    a[..., 3] = np.uint8(a[..., 3] * fade)
    return Image.fromarray(a, 'RGBA')


def preview_sky() -> Image.Image:
    """A plain gradient (preview composites only)."""
    y = np.linspace(0, 1, H)[:, None, None]
    top, bot = np.array([127, 192, 222]), np.array([234, 243, 220])
    return Image.fromarray(np.uint8(np.tile(top * (1 - y) + bot * y, (1, W, 1))), 'RGB').convert('RGBA')


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('  python ')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--out', default=None)
    ap.add_argument('--previews', default=None)
    ap.add_argument('--stage', default=None)
    a = ap.parse_args()
    m = fc.masters(fc.stage_root(a.stage))
    out = Path(a.out) if a.out else m['backdrops']
    prev = Path(a.previews) if a.previews else m['previews']
    out.mkdir(parents=True, exist_ok=True)
    prev.mkdir(parents=True, exist_ok=True)
    far_img = far()
    can_img = canopy()
    far_img.save(out / 'farm_far.webp', quality=90, method=4)
    can_img.save(out / 'farm_canopy.webp', quality=90, method=4)
    # previews (PNG, previews folder only): the far layer and the canopy frame on a plain gradient sky
    comp = preview_sky()
    comp.alpha_composite(far_img)
    comp.alpha_composite(can_img)
    comp.convert('RGB').save(prev / 'preview_far_and_canopy_on_sky.png')
    print('backdrops written to', out, '(farm_far.webp %s, farm_canopy.webp %s); preview in %s' % (far_img.size, can_img.size, prev))
    return 0


if __name__ == '__main__':
    sys.exit(main())
