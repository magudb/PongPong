"""Home + furniture kit: painted patterns with REAL-WORLD texel size, and the HM builder (planar-UV boxes, roofs, towers).

Why patterns carry a size:  `brick@4.20` means "this texture square spans 4.20 m".  Bricks, shingles, planks and weave therefore keep
the same physical size on a 1 m chair and a 9 m castle wall (the shipped cylinder-UV mapping stretches textures with the shape size).
`name@Lu,Lv` gives an anisotropic texture (cylinders: Lu = circumference, Lv = height).

Coordinates: metres, Y up, origin = ground point, +X faces screen right-down, +Z faces screen left-down (front of a house / piece).
"""
from __future__ import annotations
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.spatial.transform import Rotation
import geometry as geo
import build_assets as ba
import props_traetoppen as pp
from props_traetoppen import PM, T, WOOD, _rgb, _noise, _fin, _seeded

# ----------------------------------------------------------------------------------------------------------------------
# patterns:  painter(color_hex, size_px, Lu_m, Lv_m) -> PIL RGB
# ----------------------------------------------------------------------------------------------------------------------
PAINTERS = {}


def _sd(color, salt):
    return np.random.default_rng((int(color, 16) * 7919 + sum(ord(c) * 131 for c in salt)) % 2147483647)



def painter(fn):
    PAINTERS[fn.__name__[4:]] = fn
    return fn


def _grid(size):
    y, x = np.mgrid[0:1:complex(size), 0:1:complex(size)]
    return x, y


def _shade(rgb, k):
    return np.clip(rgb[None, None, :] * k[:, :, None], 0, 255)


def _mortar(img, mask, strength, tint=(60, 50, 56)):
    """darken where mask (0..1) is high"""
    t = np.array(tint, float)[None, None, :]
    return img * (1 - mask[:, :, None] * strength) + t * (mask[:, :, None] * strength)


@painter
def pat_plank_h(color, size, Lu=1., Lv=1., board=.16):
    """horizontal boards, `board` metres high (also used for furniture panels)"""
    rgb = _rgb(color); rng = _sd(color, 'h'); x, y = _grid(size)
    n = max(2, int(round(Lv / board))); idx = np.floor(y * n).astype(int)
    tone = np.array([rng.uniform(-.07, .06) for _ in range(n + 1)])[idx]
    grain = .05 * np.sin(x * 2 * math.pi * Lu * 3.2 + 7 * _noise(size, 7, rng)) + .035 * _noise(size, 36, rng)
    fr = (y * n) % 1
    seam = np.exp(-(np.minimum(fr, 1 - fr) ** 2) / (2 * .035 ** 2))
    k = 1 + tone + grain - seam * .30 + .05 * (.5 - y)
    im = _fin(_shade(rgb, k)); d = ImageDraw.Draw(im)
    nail = tuple(int(c * .55) for c in rgb)
    for b in range(n):
        for nx in (.03, .97):
            d.ellipse((nx * size - 1.5, (b + .5) / n * size - 1.5, nx * size + 1.5, (b + .5) / n * size + 1.5), fill=nail)
    return im


@painter
def pat_plank_v(color, size, Lu=1., Lv=1., board=.16):
    rgb = _rgb(color); rng = _sd(color, 'v'); x, y = _grid(size)
    n = max(2, int(round(Lu / board))); idx = np.floor(x * n).astype(int)
    tone = np.array([rng.uniform(-.08, .07) for _ in range(n + 1)])[idx]
    grain = .05 * np.sin(y * 2 * math.pi * Lv * 2.4 + 6 * _noise(size, 6, rng)) + .03 * _noise(size, 30, rng)
    seam = np.exp(-(np.minimum((x * n) % 1, 1 - (x * n) % 1) ** 2) / (2 * .035 ** 2))
    k = 1 + tone + grain - seam * .34 + .05 * (.5 - y)
    return _fin(_shade(rgb, k))


@painter
def pat_wood(color, size, Lu=1., Lv=1.):
    """fine furniture wood: long grain along u with rings and a few knots"""
    rgb = _rgb(color); rng = _sd(color, 'w'); x, y = _grid(size)
    warp = 6 * _noise(size, 5, rng)
    rings = np.sin((y * Lv * 26 + warp) * 2 * math.pi / 1.0) * .045
    fine = .035 * _noise(size, 48, rng) + .02 * rng.standard_normal((size, size))
    k = 1 + rings + fine + .05 * (.5 - y)
    im = _fin(_shade(rgb, k)); d = ImageDraw.Draw(im)
    for _ in range(2):
        cx, cy = rng.integers(40, size - 40, 2); r = int(rng.integers(6, 11))
        for q in range(4):
            d.ellipse((cx - r - q * 3, cy - (r + q * 3) * .6, cx + r + q * 3, cy + (r + q * 3) * .6), outline=tuple(int(c * .74) for c in rgb), width=1)
    return im


@painter
def pat_painted(color, size, Lu=1., Lv=1.):
    """milk paint: soft streaky brush strokes, slightly lighter at the edges of strokes"""
    rgb = _rgb(color); rng = _sd(color, 'p'); x, y = _grid(size)
    stroke = np.asarray(Image.fromarray(np.uint8((rng.random((size // 3, 10)) * 255))).resize((size, size), Image.BICUBIC), np.float32) / 255 - .5
    k = 1 + .045 * stroke + .015 * rng.standard_normal((size, size)) + .04 * (.5 - y) + .02 * np.cos(2 * math.pi * x)
    return _fin(_shade(rgb, k))


@painter
def pat_plaster(color, size, Lu=1., Lv=1.):
    rgb = _rgb(color); rng = _sd(color, 'l'); x, y = _grid(size)
    k = 1 + .05 * _noise(size, 7, rng) + .035 * _noise(size, 26, rng) + .018 * rng.standard_normal((size, size)) + .05 * (.5 - y)
    im = _fin(_shade(rgb, k)); d = ImageDraw.Draw(im, 'RGBA')
    for _ in range(int(size * .22)):  # trowel arcs
        cx, cy = rng.integers(0, size, 2); r = int(rng.integers(14, 40))
        d.arc((cx - r, cy - r * .5, cx + r, cy + r * .5), 200, 330, fill=tuple(int(np.clip(c * 1.06, 0, 255)) for c in rgb) + (70,), width=2)
    return im


@painter
def pat_brick(color, size, Lu=1., Lv=1., bw=.26, bh=.085):
    rgb = _rgb(color); rng = _sd(color, 'b'); x, y = _grid(size)
    bw = Lu / max(1, round(Lu / bw)); rows = max(2, int(Lv / bh)); r = np.floor(y * rows).astype(int); col = (x * Lu / bw + (r % 2) * .5)
    c = np.floor(col).astype(int); h = np.array([[rng.uniform(-.1, .09) for _ in range(int(Lu / bw) + 3)] for _ in range(rows + 1)])
    tone = h[r, np.clip(c, 0, h.shape[1] - 1)]
    fx = col % 1; fy = (y * rows) % 1
    edge = np.minimum(np.minimum(fx, 1 - fx) * bw / .012, np.minimum(fy, 1 - fy) * bh / .012)
    m = np.clip(1 - edge, 0, 1)
    k = 1 + tone + .04 * _noise(size, 40, rng) + .02 * rng.standard_normal((size, size)) + .04 * (.5 - y)
    return _fin(_mortar(_shade(rgb, k), m, .72, (206, 190, 170)))


@painter
def pat_blocks(color, size, Lu=1., Lv=1., bw=.5, bh=.27):
    """ashlar stone blocks with soft mortar, chips and moss-free speckle"""
    rgb = _rgb(color); rng = _sd(color, 's'); x, y = _grid(size)
    bw = Lu / max(1, round(Lu / bw)); rows = max(2, int(Lv / bh)); r = np.floor(y * rows).astype(int)
    off = np.round(np.array([rng.uniform(0, 1) for _ in range(rows + 1)]) * 2) / 2
    off = off[r]
    col = x * Lu / bw + off; c = np.floor(col).astype(int)
    h = np.array([[rng.uniform(-.09, .08) for _ in range(int(Lu / bw) + 4)] for _ in range(rows + 1)])
    tone = h[r, np.clip(c, 0, h.shape[1] - 1)]
    fx = col % 1; fy = (y * rows) % 1
    edge = np.minimum(np.minimum(fx, 1 - fx) * bw / .018, np.minimum(fy, 1 - fy) * bh / .018)
    m = np.clip(1 - edge, 0, 1)
    k = 1 + tone + .07 * _noise(size, 10, rng) + .035 * _noise(size, 34, rng) + .02 * rng.standard_normal((size, size)) + .06 * (.5 - y)
    return _fin(_mortar(_shade(rgb, k), m, .55, (92, 84, 98)))


@painter
def pat_thatch(color, size, Lu=1., Lv=1.):
    rgb = _rgb(color); rng = _sd(color, 't')
    im = Image.new('RGB', (size, size), tuple(int(c) for c in rgb * .93)); d = ImageDraw.Draw(im)
    for i in range(int(size * 4.2)):
        x0 = rng.uniform(-8, size + 8); y0 = rng.uniform(-10, size); L = rng.uniform(40, 120); k = rng.uniform(.80, 1.16)
        d.line((x0, y0, x0 + rng.uniform(-4, 4), y0 + L), fill=tuple(int(np.clip(v * k, 0, 255)) for v in rgb), width=int(rng.integers(2, 4)))
    # horizontal binding courses
    rows = max(2, int(Lv / .34))
    for r in range(1, rows):
        yy = r / rows * size
        d.line((0, yy, size, yy), fill=tuple(int(v * .62) for v in rgb), width=2)
    return im.filter(ImageFilter.GaussianBlur(.5))


@painter
def pat_shingle(color, size, Lu=1., Lv=1., sw=.17, sh=.2):
    """rounded wooden shingles, staggered rows, per-shingle tone"""
    rgb = _rgb(color); rng = _sd(color, 'g')
    im = Image.new('RGB', (size, size), tuple(int(c * .55) for c in rgb)); d = ImageDraw.Draw(im)
    rows = max(3, int(Lv / sh * 1.5)); ph = size / rows; pw = size * sw / Lu
    for r in range(rows):
        off = (r % 2) * pw / 2
        for cx in np.arange(-pw + off, size + pw, pw):
            k = rng.uniform(.82, 1.12); c = tuple(int(np.clip(v * k, 0, 255)) for v in rgb)
            d.rounded_rectangle((cx + 1, r * ph - ph * .1, cx + pw - 1, r * ph + ph * 1.25), radius=int(pw * .35), fill=c, outline=tuple(int(v * .62) for v in rgb))
    return im


@painter
def pat_rooftile(color, size, Lu=1., Lv=1., tw=.22, th=.20):
    """fish-scale / curved clay tiles"""
    rgb = _rgb(color); rng = _sd(color, 'r')
    im = Image.new('RGB', (size, size), tuple(int(c * .58) for c in rgb)); d = ImageDraw.Draw(im)
    rows = max(3, int(Lv / th)); ph = size / rows; pw = size * tw / Lu
    for r in range(rows):
        off = (r % 2) * pw / 2
        for cx in np.arange(-pw + off, size + pw, pw):
            k = rng.uniform(.86, 1.10); c = tuple(int(np.clip(v * k, 0, 255)) for v in rgb)
            d.pieslice((cx, r * ph - ph * .25, cx + pw, r * ph + ph * 1.5), 0, 180, fill=c, outline=tuple(int(v * .6) for v in rgb))
            d.arc((cx + pw * .12, r * ph + ph * .05, cx + pw * .88, r * ph + ph * 1.2), 20, 160, fill=tuple(int(np.clip(v * 1.15, 0, 255)) for v in rgb), width=1)
    return im


@painter
def pat_slate(color, size, Lu=1., Lv=1., sw=.30, sh=.17):
    rgb = _rgb(color); rng = _sd(color, 'z')
    im = Image.new('RGB', (size, size), tuple(int(c * .5) for c in rgb)); d = ImageDraw.Draw(im)
    rows = max(3, int(Lv / sh)); ph = size / rows; pw = size * sw / Lu
    for r in range(rows):
        off = (r % 2) * pw / 2
        for cx in np.arange(-pw + off, size + pw, pw):
            k = rng.uniform(.84, 1.14); c = tuple(int(np.clip(v * k, 0, 255)) for v in rgb)
            d.rectangle((cx + 1, r * ph, cx + pw - 1, r * ph + ph * 1.35), fill=c, outline=tuple(int(v * .55) for v in rgb))
            d.line((cx + 2, r * ph + 2, cx + pw - 3, r * ph + 2), fill=tuple(int(np.clip(v * 1.22, 0, 255)) for v in rgb))
    return im


@painter
def pat_copper(color, size, Lu=1., Lv=1.):
    """verdigris standing-seam metal roof"""
    rgb = _rgb(color); rng = _sd(color, 'c'); x, y = _grid(size)
    seams = max(3, int(Lu / .5)); sx = (x * seams) % 1
    seam = np.exp(-(np.minimum(sx, 1 - sx) ** 2) / (2 * .03 ** 2))
    streak = np.asarray(Image.fromarray(np.uint8(rng.random((8, size // 2)) * 255)).resize((size, size), Image.BICUBIC), np.float32) / 255 - .5
    k = 1 + .10 * streak + .05 * _noise(size, 20, rng) + seam * .10 + .05 * (.5 - y)
    im = _fin(_shade(rgb, k))
    return im


@painter
def pat_marble(color, size, Lu=1., Lv=1.):
    rgb = _rgb(color); rng = _sd(color, 'm'); x, y = _grid(size)
    warp = 3.2 * _noise(size, 6, rng) + 1.2 * _noise(size, 14, rng)
    vein = np.abs(np.sin((x * 2.2 + y * 1.3 + warp * .35) * math.pi)) ** 38
    vein2 = np.abs(np.sin((x * 4.1 - y * 1.6 + warp * .5) * math.pi)) ** 60
    k = 1 + .025 * _noise(size, 10, rng) - .075 * vein - .045 * vein2 + .04 * (.5 - y)
    return _fin(_shade(rgb, k))


@painter
def pat_gold(color, size, Lu=1., Lv=1.):
    """beaten gilt: warm bands + hammer dents + a bright sweep"""
    rgb = _rgb(color); rng = _sd(color, 'G'); x, y = _grid(size)
    sweep = np.exp(-((x + y * .6 - .45) ** 2) / .012) * .32 + np.exp(-((x + y * .6 - .85) ** 2) / .006) * .18
    dents = _noise(size, 28, rng) * .035
    k = 1 + sweep + dents - .12 * y
    return _fin(_shade(rgb, k))


@painter
def pat_weave(color, size, Lu=1., Lv=1.):
    """plain cloth weave"""
    rgb = _rgb(color); rng = _sd(color, 'f'); x, y = _grid(size)
    f = max(8, int(Lu * 70)); wx = (np.sin(x * f * 2 * math.pi) * np.sin(y * f * 2 * math.pi)) * .05
    k = 1 + wx + .05 * _noise(size, 9, rng) + .02 * rng.standard_normal((size, size)) + .05 * (.5 - y)
    return _fin(_shade(rgb, k))


@painter
def pat_velvet(color, size, Lu=1., Lv=1.):
    rgb = _rgb(color); rng = _sd(color, 'V'); x, y = _grid(size)
    k = 1 + .09 * _noise(size, 5, rng) + .05 * _noise(size, 18, rng) + .012 * rng.standard_normal((size, size)) + .06 * (.5 - y)
    return _fin(_shade(rgb, k))


@painter
def pat_stripe(color, size, Lu=1., Lv=1.):
    """cloth with cream stripes (the 'color' is the main colour)"""
    rgb = _rgb(color); x, y = _grid(size); rng = _sd(color, 'S')
    n = max(3, int(Lu / .09)); s = ((x * n) % 1 < .38).astype(np.float32)
    cream = np.array([246, 236, 212], float)
    img = rgb[None, None, :] * (1 - s[:, :, None] * .0) * 1.0
    img = img * (1 - s[:, :, None]) + (rgb * .35 + cream * .65)[None, None, :] * s[:, :, None]
    k = 1 + .04 * _noise(size, 9, rng) + .012 * rng.standard_normal((size, size)) + .05 * (.5 - y)
    return _fin(np.clip(img * k[:, :, None], 0, 255))


@painter
def pat_quilt(color, size, Lu=1., Lv=1.):
    """patchwork quilt: diamond cells in the colour + two lighter tints, stitched"""
    rgb = _rgb(color); rng = _sd(color, 'q'); x, y = _grid(size)
    n = max(3, int(Lu / .16)); u = x * n; v = y * n
    cu, cv = np.floor(u + v), np.floor(u - v)
    tone = np.array([rng.uniform(.82, 1.22) for _ in range(4)])[((cu + 2 * cv).astype(int)) % 4]
    k = tone + .03 * rng.standard_normal((size, size))
    img = _shade(rgb, k)
    ed = np.minimum(np.abs((u + v) % 1 - .5), np.abs((u - v) % 1 - .5))
    img = img * (1 - np.clip(1 - ed / .06, 0, 1)[:, :, None] * .14)
    return _fin(img)


@painter
def pat_damask(color, size, Lu=1., Lv=1.):
    rgb = _rgb(color); rng = _sd(color, 'D'); x, y = _grid(size)
    n = max(3, int(Lu / .14)); u = (x * n) % 1 - .5; v = (y * n) % 1 - .5
    cell = (np.floor(x * n) + np.floor(y * n)) % 2
    leaf = np.exp(-((np.abs(u) * 2.2) ** 2 + (v * 1.2) ** 2) / .06) * (1 - cell) + np.exp(-((u * 1.2) ** 2 + (np.abs(v) * 2.2) ** 2) / .06) * cell
    k = 1 + .10 * np.clip(leaf, 0, 1) + .03 * _noise(size, 12, rng) + .04 * (.5 - y)
    return _fin(_shade(rgb, k))


@painter
def pat_carpet(color, size, Lu=1., Lv=1.):
    """woven rug: border band + motif diamonds (colour is the field)"""
    rgb = _rgb(color); rng = _sd(color, 'C'); x, y = _grid(size)
    edge = np.minimum(np.minimum(x, 1 - x) * Lu, np.minimum(y, 1 - y) * Lv)
    border = ((edge > .10) & (edge < .20)).astype(np.float32); border2 = ((edge > .24) & (edge < .27)).astype(np.float32)
    cx = (x * Lu / .34) % 1 - .5; cy = (y * Lv / .34) % 1 - .5
    dia = ((np.abs(cx) + np.abs(cy)) < .22).astype(np.float32) * (edge > .32)
    pale = np.array([246, 232, 200], float); acc = rgb * .55
    img = rgb[None, None, :] * np.ones((size, size, 1))
    img = img * (1 - border[:, :, None]) + pale[None, None, :] * border[:, :, None]
    img = img * (1 - border2[:, :, None]) + acc[None, None, :] * border2[:, :, None]
    img = img * (1 - dia[:, :, None] * .85) + (rgb * .6 + pale * .4)[None, None, :] * dia[:, :, None] * .85
    k = 1 + .045 * rng.standard_normal((size, size)) + .04 * _noise(size, 12, rng)
    wx = np.sin(x * Lu * 160) * np.sin(y * Lv * 160) * .03
    return _fin(img * (k + wx)[:, :, None])


@painter
def pat_emit(color, size, Lu=1., Lv=1.):
    return Image.new('RGB', (size, size), tuple(int(c) for c in _rgb(color)))


@painter
def pat_emitn(color, size, Lu=1., Lv=1.):
    return Image.new('RGB', (size, size), tuple(int(c) for c in _rgb(color)))


@painter
def pat_glass(color, size, Lu=1., Lv=1.):
    rgb = _rgb(color); x, y = _grid(size)
    k = 1 + .22 * np.exp(-((x - y * .7 - .25) ** 2) / .02) + .10 * np.exp(-((x - y * .7 - .6) ** 2) / .004) - .12 * y
    return _fin(_shade(rgb, k))


@painter
def pat_crystalf(color, size, Lu=1., Lv=1.):
    """faceted crystal: strong light/dark facets"""
    rgb = _rgb(color); rng = _sd(color, 'X'); x, y = _grid(size)
    f = np.abs(np.sin(x * 7 + y * 2) * np.cos(y * 5 - x * 3)); k = 1 + .30 * (f - .4) + .22 * (.5 - y) + .10 * np.exp(-((x - .3) ** 2) / .01)
    return _fin(_shade(rgb, k))


@painter
def pat_moss(color, size, Lu=1., Lv=1.):
    rgb = _rgb(color); rng = _sd(color, 'M')
    base = Image.new('RGB', (size, size), tuple(int(c) for c in rgb)); d = ImageDraw.Draw(base, 'RGBA')
    for i in range(int(size * 1.2)):
        px, py = rng.integers(0, size, 2); r = int(rng.integers(3, 9)); k = rng.uniform(.8, 1.2)
        d.ellipse((px - r, py - r * .8, px + r, py + r * .8), fill=tuple(int(np.clip(v * k, 0, 255)) for v in rgb) + (int(rng.integers(90, 200)),))
    return base.filter(ImageFilter.GaussianBlur(.8))


@painter
def pat_bark2(color, size, Lu=1., Lv=1.):
    return pp.pat_bark(color, size)


@painter
def pat_soft(color, size, Lu=1., Lv=1.):
    rgb = _rgb(color); rng = _sd(color, 'o'); x, y = _grid(size)
    k = 1 + .02 * np.cos(2 * math.pi * x) + .03 * (.5 - y) + .008 * rng.standard_normal((size, size))
    return _fin(_shade(rgb, k))


@painter
def pat_scene(color, size, Lu=1., Lv=1.):
    """a naive painted landscape (for picture frames): sky gradient, hills, sun or moon, a tree; the colour seeds palette and layout"""
    rng = _sd(color, 'scene'); rgb = _rgb(color)
    night = rng.random() < .35
    top = np.array([28, 33, 70], float) if night else rgb * .55 + np.array([120, 160, 200]) * .45
    bot = np.array([90, 70, 120], float) if night else np.array([250, 226, 180], float)
    y = np.linspace(0, 1, size)[:, None, None]
    img = (top * (1 - y) + bot * y) * np.ones((1, size, 1))
    im = Image.fromarray(np.uint8(np.clip(img, 0, 255)), 'RGB'); d = ImageDraw.Draw(im)
    sx, sy = rng.uniform(.2, .8) * size, rng.uniform(.18, .34) * size
    d.ellipse((sx - size * .07, sy - size * .07, sx + size * .07, sy + size * .07), fill=(255, 244, 200) if night else (255, 226, 140))
    for k, (base, col) in enumerate([(.62, (96, 130, 110) if night else (140, 178, 120)), (.74, (60, 98, 84) if night else (96, 150, 86))]):
        pts = [(0, size)]
        for i in range(0, 9):
            pts.append((i / 8 * size, (base + .06 * math.sin(i * 1.3 + rng.uniform(0, 6)) - .04 * k) * size))
        pts.append((size, size)); d.polygon(pts, fill=col)
    tx = rng.uniform(.2, .8) * size; th = size * .26
    d.rectangle((tx - 3, size * .72 - th * .4, tx + 3, size * .72 + 6), fill=(90, 60, 40))
    d.ellipse((tx - th * .32, size * .72 - th * .95, tx + th * .32, size * .72 - th * .25), fill=(54, 100, 70) if night else (70, 130, 70))
    if rng.random() < .6:
        hx = rng.uniform(.15, .65) * size; d.rectangle((hx, size * .78, hx + 26, size * .78 + 20), fill=(236, 220, 190)); d.polygon([(hx - 4, size * .78), (hx + 13, size * .78 - 14), (hx + 30, size * .78)], fill=(180, 90, 60))
    return im.filter(ImageFilter.GaussianBlur(.7))


_QL = [.25 * 1.35 ** k for k in range(14)]


def ql(L):
    """quantise a texture span (m) to a geometric ladder so that many shapes share one painted tile (big bake-time saver)"""
    return min(_QL, key=lambda q: abs(math.log(q / max(L, .05))))


class PatternRegistry(dict):
    """dict that also resolves 'name@Lu[,Lv]' lazily (replaces build_assets.EXTRA_PATTERNS in place so paint_tile sees it)."""
    def _resolve(self, key):
        if '@' not in key: return None
        base, dims = key.split('@', 1)
        if base not in PAINTERS: return None
        parts = [float(v) for v in dims.split(',')]
        Lu = parts[0]; Lv = parts[1] if len(parts) > 1 else parts[0]
        return lambda color, size: PAINTERS[base](color, size, Lu, Lv)

    def __contains__(self, key):
        return dict.__contains__(self, key) or (isinstance(key, str) and self._resolve(key) is not None)

    def __getitem__(self, key):
        if dict.__contains__(self, key): return dict.__getitem__(self, key)
        f = self._resolve(key)
        if f is None: raise KeyError(key)
        return f


def install():
    if not isinstance(ba.EXTRA_PATTERNS, PatternRegistry):
        ba.EXTRA_PATTERNS = PatternRegistry(ba.EXTRA_PATTERNS)
    ba.EXTRA_PATTERNS.update(pp.PROP_PATTERNS)
    import traetoppen_additions as tt
    for k, v in ba.EXTRA_PATTERNS.items(): tt.EXTRA_PATTERNS[k] = v    # bake_props style imports keep working
    return ba.EXTRA_PATTERNS


for _k in list(PAINTERS):
    ba.EXTRA_PATTERNS.setdefault(_k, (lambda c, sz, k=_k: PAINTERS[k](c, sz, 1., 1.)))
install()


# ----------------------------------------------------------------------------------------------------------------------
# builder
# ----------------------------------------------------------------------------------------------------------------------
class HM(PM):
    """PM + planar-UV boxes with physical texel size, layers (main / float) and emissive tagging."""

    def __init__(self):
        super().__init__(); self.layer = 'main'

    def _add(self, v, f, color, pat, uv=None, planar=False):
        self.m.add(self.g, v, f, color)
        s = self.m.groups[self.g].shapes[-1]; s.pattern = pat; s.layer = self.layer
        s.emit = pat.startswith('emit'); s.night_only = pat.startswith('emitn'); s.planar = planar
        if uv is not None: s.uv = uv

    def box(self, c, size, color, tex='soft', power=.24, rot=None, pivot=None, seg=22, rings=14, L=None, ang=0.0):
        """Rounded box with PLANAR uv (physical texel size).  `tex` is a painter name ('plaster', 'brick', ...) or a literal pattern."""
        c = np.asarray(c, float); size = np.asarray(size, float)
        v, f = geo.ellipsoid(c, size / 2, seg, rings, power, 0.0)
        if tex in ('emit', 'emitn') or '@' in tex:
            self._add(self._rot(v, np.asarray(pivot if pivot is not None else c, float), rot), f, color, tex); return
        if tex not in PAINTERS:
            self._add(self._rot(v, np.asarray(pivot if pivot is not None else c, float), rot), f, color, tex); return
        n = geo.smooth_normals(v, f); L = ql(float(L or max(size.max(), .3))); rel = v - c
        ax = np.argmax(np.abs(n), axis=1)
        u = np.where(ax == 1, rel[:, 0], np.where(ax == 0, rel[:, 2], rel[:, 0])) / L + .5
        w = np.where(ax == 1, rel[:, 2], rel[:, 1]) / L + .5
        w = np.where(ax == 1, w, 1 - w)
        uv = np.stack([u, w], 1)
        self._add(self._rot(v, np.asarray(pivot if pivot is not None else c, float), rot), f, color, f'{tex}@{L:.2f}', uv, True)

    def ell(self, c, r, color, pat='soft', power=1.0, rot=None, seg=26, rings=16, pivot=None):
        if pat in PAINTERS: pat = f'{pat}@{ql(max(max(r) * 2, .3)):.2f}'
        super().ell(c, r, color, pat, power, rot, seg, rings, pivot)

    def cyl2(self, p0, p1, r0, r1, color, tex='soft', sides=18, n=6, **kw):
        """tube with texture sized from the surface: Lu = circumference, Lv = length"""
        h = float(np.linalg.norm(np.asarray(p1, float) - np.asarray(p0, float)))
        pat = f'{tex}@{ql(2 * math.pi * max(r0, r1)):.2f},{ql(max(h, .05)):.2f}' if tex in PAINTERS else tex
        self.cyl(p0, p1, r0, r1, color, pat, sides, n, **kw)

    def tube2(self, pts, radii, color, tex='soft', sides=14, **kw):
        pts = np.asarray(pts, float)
        h = float(np.linalg.norm(np.diff(pts, axis=0), axis=1).sum()); r = float(np.max(radii))
        pat = f'{tex}@{ql(2 * math.pi * r):.2f},{ql(max(h, .05)):.2f}' if tex in PAINTERS else tex
        self.tube(pts, radii, color, pat, sides, **kw)

    def sphere(self, c, r, color, tex='soft', seg=20, rings=14):
        self.ell(c, (r, r, r), color, tex, 1.0, None, seg, rings)

    def emit(self, c, size, color, power=.3, rot=None):
        """lit/emissive box: baked bright in the day sprite AND written to the additive night layer"""
        self.box(c, size, color, 'emit', power, rot)

    def emit_ell(self, c, r, color, power=1.0, rot=None, seg=18, rings=12):
        super().ell(c, r, color, 'emit', power, rot, seg, rings)

    # ---- architecture helpers --------------------------------------------------------------------------------------------
    def gable(self, x0, x1, z0, z1, y0, slope, ridge='x', over=.30, thick=.12, col='B5693F', tex='rooftile', gcol='F1E2BE', gtex='plaster',
              rcol=None, cap=True, ends=True, ridge_r=.09):
        """Gable roof over the box [x0,x1]x[z0,z1] starting at height y0.  ridge='x' (slopes face +-z) or 'z' (slopes face +-x).
        Returns the ridge height."""
        w, d = x1 - x0, z1 - z0
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        if ridge == 'x':
            half = d / 2 + over; ln = w + 2 * over
        else:
            half = w / 2 + over; ln = d + 2 * over
        th = math.radians(slope); slant = half / math.cos(th); run = half; rise = half * math.tan(th)
        for s in (-1, 1):
            if ridge == 'x':
                c = (cx, y0 + rise * .5 + thick * .4, cz + s * run * .5)
                self.box(c, (ln, thick, slant), col, tex, power=.22, rot=(s * slope, 0, 0), pivot=c, L=max(ln, slant) * .8)
            else:
                c = (cx + s * run * .5, y0 + rise * .5 + thick * .4, cz)
                self.box(c, (slant, thick, ln), col, tex, power=.22, rot=(0, 0, -s * slope), pivot=c, L=max(ln, slant) * .8)
        top = y0 + rise + thick * .5
        if cap:
            if ridge == 'x': self.cyl2((cx - ln / 2, top, cz), (cx + ln / 2, top, cz), ridge_r, ridge_r, rcol or col, 'soft', 10, 2)
            else: self.cyl2((cx, top, cz - ln / 2), (cx, top, cz + ln / 2), ridge_r, ridge_r, rcol or col, 'soft', 10, 2)
        if ends:
            if ridge == 'x':
                tri = geo.rounded_triangle([(z0 - cz - .01, y0 - .02), (z1 - cz + .01, y0 - .02), (0, y0 + (d / 2) * math.tan(th) + .02)], 5)
                for sx in (x0, x1): self._gable_end(tri, sx, gcol, gtex, 'x', cz)
            else:
                tri = geo.rounded_triangle([(x0 - .01, y0 - .02), (x1 + .01, y0 - .02), (cx, y0 + (w / 2) * math.tan(th) + .02)], 5)
                for sz in (z0, z1): self._gable_end(tri, sz, gcol, gtex, 'z', 0)
        return top

    def _gable_end(self, tri, pos, col, tex, ridge, off):
        tri = np.asarray(tri, float).copy()
        if ridge == 'x': tri[:, 0] *= -1          # the XY pillow is rotated 90 deg about y: z' = -x
        v, f = geo.pillow(tri, pos if ridge == 'z' else 0.0, .05, 1.0)
        if ridge == 'x':   # boundary is in (z,y); rotate the XY pillow 90 deg about y, then move to x=pos / z=off
            v = self._rot(v, np.zeros(3), (0, 90, 0)); v = v + np.array([pos, 0, off])
        pat = f'{tex}@2.0' if tex in PAINTERS else tex
        self._add(v, f, col, pat)

    def cone(self, c, r, h, col, tex='rooftile', y=0.0, tip=.03, sides=24, n=6, rim=True, rim_col=None):
        """conical roof of radius r, rim included; c=(x,z)"""
        slant = math.hypot(r, h)
        self.cyl2((c[0], y, c[1]), (c[0], y + h, c[1]), r, tip, col, tex, sides, n)
        if rim:
            self.ell((c[0], y + .02, c[1]), (r * 1.02, .05, r * 1.02), rim_col or col, 'soft', seg=sides, rings=6)

    def tower(self, c, r, h, col, tex='blocks', roof=None, roof_h=None, roof_col='7A8FC0', roof_tex='slate', base_col=None, battlement=False,
              slits=3, slit_col='2B2340', ring=None):
        cx, cz = c
        self.cyl2((cx, 0, cz), (cx, h, cz), r, r * .97, col, tex, 28, 5)
        self.ell((cx, .06, cz), (r * 1.06, .12, r * 1.06), base_col or col, 'blocks', seg=28, rings=6)
        if ring: self.ell((cx, h - .05, cz), (r * 1.08, .09, r * 1.08), ring, 'soft', seg=28, rings=6)
        for i in range(slits):
            yy = h * (.35 + .22 * i)
            self.ell((cx + .0, yy, cz + r * .97), (.05, .17, .05), slit_col, 'soft', seg=10, rings=8)
        if battlement:
            for k in range(10):
                a = k * 2 * math.pi / 10
                self.box((cx + math.cos(a) * r * .94, h + .14, cz + math.sin(a) * r * .94), (.26, .30, .26), col, tex, power=.25, rot=(0, -math.degrees(a), 0))
        if roof_h:
            self.cone((cx, cz), r * 1.18, roof_h, roof_col, roof_tex, y=h - .02)

    def crenellations(self, x0, x1, z0, z1, y, col, tex='blocks', size=(.3, .32, .26), gap=.55, faces=('z1', 'x1', 'z0', 'x0'), skip=None):
        sx, sy, sz = size
        for face in faces:
            if face in ('z1', 'z0'):
                zz = z1 - .1 if face == 'z1' else z0 + .1
                for xx in np.arange(x0 + .25, x1 - .15, gap): self.box((xx, y + sy / 2, zz), (sx, sy, sz), col, tex, power=.24)
            else:
                xx = x1 - .1 if face == 'x1' else x0 + .1
                for zz in np.arange(z0 + .25, z1 - .15, gap): self.box((xx, y + sy / 2, zz), (sz, sy, sx), col, tex, power=.24)

    def window(self, face, pos, w=.52, h=.62, frame='7A4E2D', glass='A9D3E0', glow=True, mull=True, sill=True, shutters=None, ftex='wood', arch=False, light='FFD98A'):
        """Window on a vertical face: face '+z' (front, screen left-down) or '+x' (screen right-down).  pos=(a, y, depth): a runs along the face.
        Day: glass pane.  Night: an additive 'emitn' pane in front of it (only written to the emissive layer)."""
        a, y, dep = pos
        if face == '+z':
            self.box((a, y, dep + .02), (w + .14, h + .14, .08), frame, ftex, power=.25)
            if arch: self.ell((a, y + h / 2 + .02, dep + .05), (w / 2 + .07, .14, .05), frame, 'soft')
            self.box((a, y, dep + .06), (w, h, .05), glass, 'glass', power=.26)
            if glow: self.box((a, y, dep + .075), (w * .96, h * .96, .03), light, 'emitn', power=.26)
            if mull:
                self.box((a, y, dep + .095), (.04, h, .03), frame, 'soft', power=.3); self.box((a, y, dep + .095), (w, .04, .03), frame, 'soft', power=.3)
            if sill: self.box((a, y - h / 2 - .09, dep + .10), (w + .22, .06, .17), frame, ftex, power=.3)
            if shutters:
                for s_ in (-1, 1): self.box((a + s_ * (w / 2 + .20), y, dep + .06), (.17, h + .06, .05), shutters, 'plank_v', power=.3)
        else:
            self.box((dep + .02, y, a), (.08, h + .14, w + .14), frame, ftex, power=.25)
            self.box((dep + .06, y, a), (.05, h, w), glass, 'glass', power=.26)
            if glow: self.box((dep + .075, y, a), (.03, h * .96, w * .96), light, 'emitn', power=.26)
            if mull:
                self.box((dep + .095, y, a), (.03, h, .04), frame, 'soft', power=.3); self.box((dep + .095, y, a), (.03, .04, w), frame, 'soft', power=.3)
            if sill: self.box((dep + .10, y - h / 2 - .09, a), (.17, .06, w + .22), frame, ftex, power=.3)
            if shutters:
                for s_ in (-1, 1): self.box((dep + .06, y, a + s_ * (w / 2 + .20)), (.05, h + .06, .17), shutters, 'plank_v', power=.3)

    def door(self, face, pos, w=.62, h=1.34, col='6B4126', frame='7A4E2D', knob='E9C06B', arch=False, glow=False, light='FFD98A', double=False):
        a, dep = pos
        if face == '+z':
            self.box((a, h / 2, dep + .02), (w + .16, h + .1, .08), frame, 'wood', power=.25)
            if arch: self.ell((a, h + .02, dep + .02), (w / 2 + .08, .2, .08), frame, 'soft', power=.8)
            self.box((a, h / 2 - .02, dep + .07), (w, h - .04, .07), col, 'plank_v', power=.26)
            if arch: self.ell((a, h - .04, dep + .07), (w / 2, .22, .06), col, 'plank_v', power=.7)
            if double: self.box((a, h / 2 - .02, dep + .115), (.035, h - .08, .03), frame, 'soft', power=.3)
            if glow: self.box((a, h * .72, dep + .125), (w * .46, h * .2, .03), light, 'emitn', power=.3); self.box((a, h * .72, dep + .115), (w * .5, h * .22, .03), 'A9D3E0', 'glass', power=.3)
            self.ell((a + w * .32, h * .5, dep + .12), (.04, .04, .03), knob, 'gold', seg=10, rings=6)
        else:
            self.box((dep + .02, h / 2, a), (.08, h + .1, w + .16), frame, 'wood', power=.25)
            self.box((dep + .07, h / 2 - .02, a), (.07, h - .04, w), col, 'plank_v', power=.26)
            self.ell((dep + .12, h * .5, a + w * .32), (.03, .04, .04), knob, 'gold', seg=10, rings=6)


def _axis_uv(v, p0, p1, Lu_m, Lv_m):
    """uv for a straight tube p0->p1: u = angle around the axis (0..1), v = along-axis fraction (0 at p1 .. 1 at p0, matching the vertical convention)"""
    p0 = np.asarray(p0, float); p1 = np.asarray(p1, float)
    ax = p1 - p0; L = np.linalg.norm(ax); ax /= L
    ref = np.array([0., 1., 0.]) if abs(ax[1]) < .9 else np.array([1., 0., 0.])
    e1 = np.cross(ax, ref); e1 /= np.linalg.norm(e1); e2 = np.cross(ax, e1)
    rel = v - p0
    t = rel @ ax / L
    ang = np.arctan2(rel @ e2, rel @ e1) / (2 * math.pi) + .5
    return np.stack([ang, 1 - np.clip(t, 0, 1)], 1)


def _log(self, p0, p1, r0, r1, color, tex='bark2', sides=14, n=3, taper=None):
    """straight log/beam/column along any axis with axis-aligned uv (bark streaks run along the log)"""
    p0 = np.asarray(p0, float); p1 = np.asarray(p1, float)
    t = np.linspace(0, 1, n)[:, None]; pts = p0 * (1 - t) + p1 * t
    v, f = geo.tube(pts, np.linspace(r0, r1, n), sides)
    L = float(np.linalg.norm(p1 - p0))
    uv = _axis_uv(v, p0, p1, 1, 1)
    pat = f'{tex}@{ql(2 * math.pi * max(r0, r1)):.2f},{ql(max(L, .05)):.2f}' if tex in PAINTERS else tex
    self._add(v, f, color, pat, uv, False)


HM.log = _log


def _clump_fol(self, c, r, colors=('7FB04F', 'A6CC6B', '5C8E3E'), n=6, seed=1, squash=.82):
    PM.clump(self, c, r, colors, 'leaf', n=n, seed=seed, squash=squash, seg=18, rings=10)


HM.foliage = _clump_fol


# ---- flat slabs (hard-edged trapezoids) for hip roofs, mansards, pyramids ----------------------------------------------
def _slab(self, P, thick, color, tex='soft', L=None, up=(0, 1, 0)):
    """planar slab from 4 corners P0..P3 (P0->P1 along the base edge, P0->P3 up the slope); extruded INWARD by `thick`. Sharp edges."""
    P = np.asarray(P, float)
    n = np.cross(P[1] - P[0], P[3] - P[0]); ln = np.linalg.norm(n)
    if ln < 1e-9: n = np.cross(P[1] - P[0], P[2] - P[0]); ln = np.linalg.norm(n)
    n /= ln
    if n @ np.asarray(up, float) < 0: n = -n
    Q = P - n * thick
    e1 = (P[1] - P[0]); e1 /= max(np.linalg.norm(e1), 1e-9)
    e2 = P[3] - P[0]; e2 = e2 - e1 * (e2 @ e1); e2 /= max(np.linalg.norm(e2), 1e-9)
    L = ql(float(L or max(np.linalg.norm(P[1] - P[0]), np.linalg.norm(P[3] - P[0]), np.linalg.norm(P[2] - P[0])) * 1.02))
    faces_idx = [([P[0], P[1], P[2], P[3]], n), ([Q[0], Q[3], Q[2], Q[1]], -n)]
    for i in range(4):
        j = (i + 1) % 4
        sn = np.cross(P[j] - P[i], -n); sn = sn / max(np.linalg.norm(sn), 1e-9)
        faces_idx.append(([P[i], Q[i], Q[j], P[j]], sn))
    V, F, UV = [], [], []
    for quad, nn in faces_idx:
        base = len(V)
        for p in quad:
            V.append(p); rel = p - P[0]
            UV.append([(rel @ e1) / L, 1 - (rel @ e2) / L])
        F += [[base, base + 1, base + 2], [base, base + 2, base + 3]]
    V = np.array(V); F = np.array(F, np.int32)
    # make every triangle wind so its normal agrees with the intended face normal (smooth_normals uses winding)
    fixed = []
    for k, tri in enumerate(F):
        nn = faces_idx[k // 2][1]; cn = np.cross(V[tri[1]] - V[tri[0]], V[tri[2]] - V[tri[0]])
        fixed.append(tri if cn @ nn >= 0 else tri[::-1])
    self._add(V, np.array(fixed, np.int32), color, f'{tex}@{L:.2f}' if tex in PAINTERS else tex, np.clip(np.array(UV), 0, 1), True)


HM.slab = _slab


def _frustum(self, ra, ya, rb, yb, thick, color, tex='rooftile', L=None, sides=('f', 'r', 'b', 'l')):
    """roof/wall frustum between rectangle ra=(x0,x1,z0,z1) at y=ya and rb at y=yb (rb may collapse to a ridge or a point = hip / pyramid)"""
    xa0, xa1, za0, za1 = ra; xb0, xb1, zb0, zb1 = rb
    A = {'fl': (xa0, ya, za1), 'fr': (xa1, ya, za1), 'br': (xa1, ya, za0), 'bl': (xa0, ya, za0)}
    B = {'fl': (xb0, yb, zb1), 'fr': (xb1, yb, zb1), 'br': (xb1, yb, zb0), 'bl': (xb0, yb, zb0)}
    quads = {'f': ('fl', 'fr'), 'r': ('fr', 'br'), 'b': ('br', 'bl'), 'l': ('bl', 'fl')}
    for s_ in sides:
        a, b = quads[s_]
        self.slab([A[a], A[b], B[b], B[a]], thick, color, tex, L, up=(0, 1, 0))


HM.frustum = _frustum


def _hip(self, x0, x1, z0, z1, y0, rise, over=.3, thick=.12, col='6E7A98', tex='slate', L=None, ridge_cap=None):
    w, d = x1 - x0 + 2 * over, z1 - z0 + 2 * over
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    rl = max(0.0, (w - d) / 2) if w >= d else 0.0
    rw = max(0.0, (d - w) / 2) if d > w else 0.0
    ra = (x0 - over, x1 + over, z0 - over, z1 + over)
    rb = (cx - rl, cx + rl, cz - rw, cz + rw)
    self.frustum(ra, y0, rb, y0 + rise, thick, col, tex, L)
    return y0 + rise


HM.hip = _hip


def _banner(self, x, y, z, w, h, color, face='+z', trim='E3C372'):
    if face == '+z':
        self.box((x, y, z), (w, h, .035), color, 'damask', power=.3)
        self.box((x, y + h / 2 - .02, z + .01), (w + .06, .05, .05), trim, 'gold', power=.3)
        self.ell((x, y - h / 2 - .02, z + .005), (w * .5, .12, .02), color, 'damask', power=.8)
        self.ell((x, y, z + .03), (w * .22, w * .22, .015), trim, 'gold')
    else:
        self.box((x, y, z), (.035, h, w), color, 'damask', power=.3)
        self.box((x + .01, y + h / 2 - .02, z), (.05, .05, w + .06), trim, 'gold', power=.3)
        self.ell((x + .005, y - h / 2 - .02, z), (.02, .12, w * .5), color, 'damask', power=.8)
        self.ell((x + .03, y, z), (.015, w * .22, w * .22), trim, 'gold')


HM.banner = _banner


def _flag(self, x, y, z, h=1.2, col='6B9A3E', trim='E3C372', length=.7, dirx=1):
    self.cyl2((x, y, z), (x, y + h, z), .025, .02, '4A3A4D', 'soft', 8, 2)
    self.ell((x, y + h + .03, z), (.05, .05, .05), trim, 'gold')
    self.box((x + dirx * length / 2, y + h - .22, z), (length, .32, .025), col, 'damask', power=.3, rot=(0, 0, dirx * -4))
    self.ell((x + dirx * (length + .05), y + h - .22, z), (.12, .16, .02), col, 'damask', power=.8)


HM.flag = _flag


def _lathe(self, cx, cz, profile, color, tex='soft', sides=24, y0=0.0, scale=1.0):
    """surface of revolution around the vertical axis through (cx,cz).  profile = [(y, radius), ...] bottom->top (radius 0 closes the tip)."""
    pts = np.array([(cx, y0 + y * scale, cz) for y, _ in profile], float)
    rad = np.array([max(r * scale, .004) for _, r in profile], float)
    h = float(pts[-1, 1] - pts[0, 1]); pat = f'{tex}@{ql(2 * math.pi * rad.max()):.2f},{ql(max(h, .05)):.2f}' if tex in PAINTERS else tex
    self.tube(pts, rad, color, pat, sides)


HM.lathe = _lathe
