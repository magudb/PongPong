"""Static prop builders in the same geometry vocabulary (Model + ellipsoid/tube) as the characters.

Coordinates: metres, Y up, tile axes = world X and Z, footprint centred on the origin (0,0,0) = ground pivot.
The bake camera sits at azimuth 45 deg, so +X faces screen right-down and +Z faces screen left-down.
One tile edge = TILE_M metres (1.0394).  Every builder returns a PropSpec (model + bake metadata).
"""
from __future__ import annotations
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.spatial.transform import Rotation
import geometry as geo
from geometry import Model, PALETTES, bezier

PALETTES['prop'] = dict(body='9A7A5A', light='C9B08A', inner='B08A6A', rim='6A4A30', belly='D8C09A')
T = 128 / (math.sqrt(2) * 87.0744)   # tile edge in metres


# ----------------------------------------------------------------------------------------------------------------------
# patterns (painted albedo for props); signature (color_hex, size) -> PIL RGB
# ----------------------------------------------------------------------------------------------------------------------
def _rgb(c): return np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], float)


def _noise(size, cells, rng):
    n = rng.random((cells, cells)).astype(np.float32)
    return np.asarray(Image.fromarray(np.uint8(n * 255)).resize((size, size), Image.BICUBIC), np.float32) / 255 - .5


def _fin(a): return Image.fromarray(np.clip(a, 0, 255).astype('uint8'), 'RGB')


def _seeded(color): return np.random.default_rng(int(color, 16) % 2147483647)


def pat_bark(color, size):
    rgb = _rgb(color); rng = _seeded(color); y, x = np.mgrid[0:1:complex(size), 0:1:complex(size)]
    streak = _noise(size, 14, rng)
    streak = np.asarray(Image.fromarray(np.uint8((streak + .5) * 255)).resize((size // 8, size), Image.BICUBIC).resize((size, size), Image.BICUBIC), np.float32) / 255 - .5
    v = 1 + .22 * streak + .06 * np.sin(x * 60 + 3 * streak) + .02 * rng.standard_normal((size, size)) + .06 * (.5 - y)
    return _fin(rgb[None, None, :] * v[:, :, None])


def pat_plank(color, size):
    rgb = _rgb(color); rng = _seeded(color); y, x = np.mgrid[0:1:complex(size), 0:1:complex(size)]
    boards = 6; idx = np.floor(y * boards)
    tone = np.array([rng.uniform(-.06, .05) for _ in range(boards + 1)])[idx.astype(int)]
    grain = .05 * np.sin(x * 40 + 6 * _noise(size, 6, rng)) + .03 * _noise(size, 30, rng)
    seam = np.exp(-((y * boards - np.round(y * boards)) ** 2) / (2 * (.045) ** 2)) * .35
    v = 1 + tone + grain - seam
    a = rgb[None, None, :] * v[:, :, None]
    im = _fin(a); d = ImageDraw.Draw(im)
    for b in range(boards):
        for nx in (.07, .93):
            d.ellipse((nx * size - 2, (b + .5) / boards * size - 2, nx * size + 2, (b + .5) / boards * size + 2), fill=tuple(int(c * .55) for c in rgb))
    return im


def pat_stone(color, size):
    rgb = _rgb(color); rng = _seeded(color); y, x = np.mgrid[0:1:complex(size), 0:1:complex(size)]
    v = 1 + .22 * _noise(size, 8, rng) + .10 * _noise(size, 24, rng) + .03 * rng.standard_normal((size, size)) + .10 * (.5 - y)
    im = _fin(rgb[None, None, :] * v[:, :, None]); d = ImageDraw.Draw(im)
    for i in range(7):
        x0, y0 = rng.integers(10, size - 10, 2); pts = [(int(x0), int(y0))]
        for k in range(4): pts.append((pts[-1][0] + int(rng.integers(-18, 18)), pts[-1][1] + int(rng.integers(4, 22))))
        d.line(pts, fill=tuple(int(c * .72) for c in rgb), width=1)
    return im


def pat_leaf(color, size):
    rgb = _rgb(color); rng = _seeded(color)
    base = Image.new('RGB', (size, size), tuple(int(c) for c in rgb)); d = ImageDraw.Draw(base, 'RGBA')
    for i in range(int(size * 1.4)):
        px, py = rng.integers(0, size, 2); r = int(rng.integers(5, 15)); k = rng.uniform(.82, 1.14)
        c = tuple(int(np.clip(v * k * (1 + (j == 1) * rng.uniform(-.02, .05)), 0, 255)) for j, v in enumerate(rgb)) + (int(rng.integers(90, 190)),)
        d.ellipse((px - r, py - r * .75, px + r, py + r * .75), fill=c)
    for i in range(int(size * .35)):
        px, py = rng.integers(0, size, 2); d.line((px, py, px + int(rng.integers(-6, 7)), py - int(rng.integers(5, 14))), fill=tuple(int(np.clip(v * 1.13, 0, 255)) for v in rgb) + (150,), width=2)
    return base.filter(ImageFilter.GaussianBlur(.6))


def pat_roof(color, size):
    rgb = _rgb(color); rng = _seeded(color)
    im = Image.new('RGB', (size, size), tuple(int(c) for c in rgb)); d = ImageDraw.Draw(im)
    rows = 9; h = size / rows
    for r in range(rows):
        off = (r % 2) * (size / 12)
        for cx in np.arange(-size / 6 + off, size + size / 6, size / 6):
            k = rng.uniform(.88, 1.1)
            c = tuple(int(np.clip(v * k, 0, 255)) for v in rgb)
            d.pieslice((cx - size / 12, r * h - h * .1, cx + size / 12, r * h + h * 2.0), 0, 180, fill=c, outline=tuple(int(v * .66) for v in rgb))
    return im


def pat_straw(color, size):
    rgb = _rgb(color); rng = _seeded(color)
    im = Image.new('RGB', (size, size), tuple(int(c) for c in rgb)); d = ImageDraw.Draw(im)
    for i in range(int(size * 1.6)):
        x0, y0 = rng.integers(0, size, 2); L = int(rng.integers(10, 34)); k = rng.uniform(.82, 1.14)
        d.line((x0, y0, x0 + L // 3, y0 + L), fill=tuple(int(np.clip(v * k, 0, 255)) for v in rgb), width=2)
    return im


def pat_soil(color, size):
    rgb = _rgb(color); rng = _seeded(color)
    v = 1 + .2 * _noise(size, 10, rng) + .08 * _noise(size, 40, rng) + .03 * rng.standard_normal((size, size))
    return _fin(rgb[None, None, :] * v[:, :, None])


def pat_crystal(color, size):
    rgb = _rgb(color); y, x = np.mgrid[0:1:complex(size), 0:1:complex(size)]
    v = 1 + .22 * np.sin(x * 14) * .5 + .26 * (.5 - y) + .12 * np.exp(-((x - .35) ** 2) * 40)
    return _fin(rgb[None, None, :] * v[:, :, None])


def pat_glassglow(color, size):
    rgb = _rgb(color); y, x = np.mgrid[0:1:complex(size), 0:1:complex(size)]
    v = 1.0 + .25 * np.exp(-(((x - .5) ** 2 + (y - .5) ** 2) * 9)) - .10 * y
    return _fin(np.minimum(rgb[None, None, :] * v[:, :, None], 255))


PROP_PATTERNS = {'bark': pat_bark, 'plank': pat_plank, 'stone': pat_stone, 'leaf': pat_leaf, 'roof': pat_roof, 'straw': pat_straw,
                 'soil': pat_soil, 'crystal': pat_crystal, 'glassglow': pat_glassglow}


# ----------------------------------------------------------------------------------------------------------------------
class PropSpec:
    """A baked prop: model + bake metadata.  Extras (all optional, defaults reproduce the spike bake exactly):
       elev/az          camera of the bake (default: the project camera, 36 degrees elevation, azimuth 45)
       ambient/diffuse  StaticRenderer material (default .44 / .59); the night-look props use a softer key
       outline          True = the pack outline (75,60,73 @ .55, 2 px); a dict {radius, color, alpha} overrides it; False = none
       post             callable(RGBA image) -> RGBA image applied to the render before the outline (a baked colour ramp)
       under            callable(W, H, cx, cy) -> RGBA layer composited UNDER the model (a baked ground shadow of its own)
       ss               supersampling override (the giant crown needs 2)
       extra            extra keys merged into the props.json entry (blend, proj, seamless, tier ...)"""
    def __init__(self, name, m, footprint=(1, 1), glow=None, shadow=None, outline=True, canvas_pad=10, kind='prop', cell=None, pivot=None,
                 elev=None, az=None, ambient=None, diffuse=None, under=None, ss=None, extra=None, post=None):
        self.name, self.m, self.footprint, self.glow, self.shadow = name, m, footprint, glow, shadow
        self.outline, self.canvas_pad, self.kind, self.cell, self.pivot = outline, canvas_pad, kind, cell, pivot
        self.elev, self.az, self.ambient, self.diffuse, self.under, self.ss, self.extra, self.post = elev, az, ambient, diffuse, under, ss, (extra or {}), post


class PM:
    """Tiny prop maker around geometry.Model."""
    def __init__(self):
        self.m = Model('prop'); self.g = self.m.lookup['Motion']

    def _add(self, v, f, color, pat):
        self.m.add(self.g, v, f, color)
        s = self.m.groups[self.g].shapes[-1]; s.pattern = pat

    @staticmethod
    def _rot(v, center, rot):
        if rot is None or (np.asarray(rot) == 0).all(): return v
        R = Rotation.from_euler('xyz', rot, degrees=True).as_matrix()
        return (v - center) @ R.T + center

    def ell(self, c, r, color, pat='soft', power=1.0, rot=None, seg=26, rings=16, pivot=None):
        v, f = geo.ellipsoid(c, r, seg, rings, power, 0.0)
        self._add(self._rot(v, np.asarray(pivot if pivot is not None else c, float), rot), f, color, pat)

    def box(self, c, size, color, pat='plank', power=.34, rot=None, seg=22, rings=14, pivot=None):
        self.ell(c, np.asarray(size, float) / 2, color, pat, power, rot, seg, rings, pivot)

    def tube(self, pts, radii, color, pat='soft', sides=14, depth=None, rot=None, center=None):
        pts = np.asarray(pts, float)
        v, f = geo.tube(pts, radii, sides, depth)
        self._add(self._rot(v, np.asarray(center if center is not None else pts.mean(0), float), rot), f, color, pat)

    def cyl(self, p0, p1, r0, r1, color, pat='soft', sides=16, n=6, **kw):
        t = np.linspace(0, 1, n)[:, None]; pts = np.asarray(p0, float) * (1 - t) + np.asarray(p1, float) * t
        self.tube(pts, np.linspace(r0, r1, n), color, pat, sides, **kw)

    def curve(self, ctrl, r0, r1, color, pat='soft', sides=10, n=18):
        c = [np.asarray(q, float) for q in ctrl]
        if len(c) == 3: c = [c[0], c[0] + 2 / 3 * (c[1] - c[0]), c[2] + 2 / 3 * (c[1] - c[2]), c[2]]
        elif len(c) == 2: c = [c[0], c[0] + (c[1] - c[0]) / 3, c[0] + 2 * (c[1] - c[0]) / 3, c[1]]
        p = bezier(c, n); self.tube(p, np.linspace(r0, r1, n), color, pat, sides)

    def pillow(self, boundary, z, depth, color, pat='soft', rot=None):
        v, f = geo.pillow(np.asarray(boundary, float), z, depth, 1.0)
        self._add(self._rot(v, np.zeros(3), rot), f, color, pat)

    def clump(self, c, r, colors, pat='leaf', n=7, seed=1, squash=.82, seg=20, rings=12):
        """A puffy foliage mass: central blob + satellites, painted with 3 greens."""
        rng = np.random.default_rng(seed)
        self.ell(c, (r, r * squash, r), colors[0], pat, seg=seg, rings=rings)
        for i in range(n):
            a = rng.uniform(0, 2 * math.pi); e = rng.uniform(-.1, .9)
            d = np.array([math.cos(a) * math.cos(e), math.sin(e), math.sin(a) * math.cos(e)]) * r * .78
            rr = r * rng.uniform(.5, .72)
            col = colors[(i + 1) % len(colors)] if e < .45 else colors[1 % len(colors)]
            self.ell(np.asarray(c) + d * [1, squash, 1], (rr, rr * squash, rr), col, pat, seg=seg, rings=rings)


def spec(pm: PM, name, **kw) -> PropSpec:
    return PropSpec(name, pm.m, **kw)


# ----------------------------------------------------------------------------------------------------------------------
# trees
# ----------------------------------------------------------------------------------------------------------------------
TREE_PAL = {
    'farm': dict(leaf=('7FB04F', 'A6CC6B', '5C8E3E'), bark='7A4E2D', bark2='5E3B22'),
    'hyggebyen': dict(leaf=('E39BB8', 'F5C6D6', 'C57A9C'), bark='7C5A4A', bark2='5C3F34'),
    'forest': dict(leaf=('2E5F57', '3F7A69', '1F433F'), bark='4A3A4D', bark2='342836'),
    'autumn': dict(leaf=('D98A3A', 'EDB255', 'B5642A'), bark='7A4E2D', bark2='5E3B22'),
}


def tree_oak(zone='farm', seed=1, scale=1.0, height=3.9) -> PropSpec:
    P = TREE_PAL[zone]; pm = PM(); rng = np.random.default_rng(seed)
    trunk_h = 1.9 * scale
    pm.curve([(0, 0, 0), (.06, trunk_h * .4, .03), (-.05, trunk_h * .8, -.02), (0, trunk_h * 1.05, 0)], .34 * scale, .17 * scale, P['bark'], 'bark', 14)
    for a in (20, 110, 200, 290):
        ar = math.radians(a + rng.uniform(-12, 12)); d = np.array([math.cos(ar), 0, math.sin(ar)])
        pm.curve([d * .12 * scale + [0, .75 * scale, 0], d * .3 * scale + [0, .30 * scale, 0], d * .52 * scale + [0, .08 * scale, 0], d * .72 * scale + [0, 0.0, 0]], .13 * scale, .045 * scale, P['bark'], 'bark', 9, n=10)
    for br in (-1, 1):   # a couple of limbs into the crown
        pm.curve([(0, trunk_h * .8, 0), (br * .25 * scale, trunk_h * 1.05, .05), (br * .55 * scale, trunk_h * 1.3, .1)], .11 * scale, .05 * scale, P['bark'], 'bark', 8, n=8)
    base = trunk_h * 1.25
    centers = [(0, base + .95, 0, 1.15), (.85, base + .55, .25, .85), (-.8, base + .65, -.2, .9), (.15, base + 1.65, .1, .85), (-.35, base + .5, .85, .78),
               (.55, base + .6, -.85, .78), (-.15, base + 1.15, -.65, .72), (.75, base + 1.25, .7, .7)]
    for i, (x, y, z, r) in enumerate(centers):
        pm.clump((x * scale, y * scale, z * scale), r * scale, P['leaf'], 'leaf', n=6, seed=seed * 31 + i)
    return spec(pm, f'tree_oak_{zone}_{seed}', footprint=(1, 1), shadow=(1.5, .55))


def tree_pine(zone='forest', seed=1, scale=1.0) -> PropSpec:
    P = TREE_PAL[zone]; pm = PM()
    pm.cyl((0, 0, 0), (0, 1.1 * scale, 0), .22 * scale, .15 * scale, P['bark'], 'bark', 10)
    y = .75 * scale; r = 1.0 * scale
    for t in range(5):
        h = (1.2 - t * .1) * scale
        pm.cyl((0, y, 0), (0, y + h, 0), r, .02, P['leaf'][t % 2], 'leaf', sides=18, n=5)
        # drooping skirt for a soft hand-painted silhouette
        pm.tube(np.array([(0, y + .04, 0), (0, y + .09, 0)]), [r * 1.02, r * .96], P['leaf'][2], 'leaf', 20, depth=[r * 1.02, r * .96])
        y += h * .55; r *= .78
    return spec(pm, f'tree_pine_{zone}_{seed}', footprint=(1, 1), shadow=(1.2, .5))


def tree_twisted(seed=1, face=True) -> PropSpec:
    """Moerkeskoven tree: crooked trunk, a few dark clumps, sleepy glowing owl-eyes in a knot-hole."""
    P = TREE_PAL['forest']; pm = PM()
    pm.curve([(0, 0, 0), (.35, 1.0, .1), (-.3, 2.0, -.1), (.1, 3.0, 0)], .48, .2, P['bark'], 'bark', 16, n=24)
    for a in (0, 100, 190, 280):
        ar = math.radians(a); d = np.array([math.cos(ar), 0, math.sin(ar)])
        pm.curve([d * .2 + [0, 1.0, 0], d * .55 + [0, .35, 0], d * .9 + [0, .05, 0], d * 1.2 + [0, 0, 0]], .2, .06, P['bark'], 'bark', 9, n=12)
    for sgn, hgt in ((-1, 2.3), (1, 2.6)):
        pm.curve([(.05, hgt - .6, 0), (sgn * .6, hgt - .1, .1), (sgn * 1.0, hgt + .5, 0), (sgn * 1.2, hgt + .95, -.05)], .14, .05, P['bark'], 'bark', 8, n=12)
    for i, (x, y, z, r) in enumerate([(.1, 3.5, 0, .85), (-.9, 3.3, .1, .6), (1.1, 3.55, -.1, .62), (.35, 4.0, .5, .5)]):
        pm.clump((x, y, z), r, P['leaf'], 'leaf', n=5, seed=seed * 11 + i)
    if face:
        zf = .5
        for s in (-1, 1):
            pm.ell((.2 + s * .15, 1.30, .43), (.10, .13, .05), 'F2C14E', 'glassglow', rot=(0, 0, 0))
            pm.ell((.2 + s * .15, 1.30, .47), (.04, .07, .03), '2B2340', 'soft')
        pm.curve([(.05, 1.0, .46), (.14, .96, .50), (.27, .96, .50), (.36, 1.0, .46)], .02, .02, '2B2340', 'soft', 6, n=8)
    return spec(pm, f'tree_twisted_{seed}', footprint=(1, 1), shadow=(1.4, .5), glow=('F2C14E', 22, .35) if face else None)


def tree_giant(seed=5) -> PropSpec:
    """Key-art tree: huge trunk below the farm platform + a ring of foliage masses around/behind it (origin = platform centre)."""
    P = dict(leaf=('86A646', 'BCCB5C', '5C8A3C'), dark=('4A7A3C', '5E8F44', '386A34'), bark='9A6642')
    pm = PM(); rng = np.random.default_rng(seed)
    pm.curve([(0, -22, 0), (.8, -12, .3), (-.5, -4, -.2), (0, -.2, 0)], 4.2, 3.0, P['bark'], 'bark', 28, n=40)
    for a in range(0, 360, 40):                                    # hanging root columns / buttresses around the trunk
        ar = math.radians(a + rng.uniform(-10, 10)); d = np.array([math.cos(ar), 0, math.sin(ar)])
        pm.curve([d * 1.5 + [0, -1.0, 0], d * 2.6 + [0, -4.5, 0], d * 3.6 + [0, -9.0, 0], d * 4.2 + [0, -14, 0]], .55, .25, P['bark'], 'bark', 10, n=16)
    # foliage ring: back half dense and tall, front corners low and sparse
    placed = 0
    for i in range(70):
        a = rng.uniform(0, 2 * math.pi); r = rng.uniform(6.3, 11.5); x, z = math.cos(a) * r, math.sin(a) * r
        front = (x + z) > 4.0                                         # +x/+z faces the camera
        if front and r < 8.8: continue
        y = rng.uniform(-.8, 3.6) if front else rng.uniform(.8, 8.2)
        rad = rng.uniform(1.3, 2.2) * (.8 if front else 1.15)
        pm.clump((x, y, z), rad, P['leaf'] if (front or y > 4.0 or i % 3 == 0) else P['dark'], 'leaf', n=4, seed=i * 3 + 1, seg=18, rings=10); placed += 1
    for i in range(14):                                                # inner back dome
        a = rng.uniform(math.pi * .75, math.pi * 1.75); r = rng.uniform(2.5, 5.8)
        pm.clump((math.cos(a) * r, rng.uniform(5.5, 9.0), math.sin(a) * r), rng.uniform(1.6, 2.4), P['dark'] if i % 2 else P['leaf'], 'leaf', n=4, seed=400 + i, seg=18, rings=10)
    return spec(pm, 'tree_giant_crown', footprint=(9, 9), shadow=None, canvas_pad=20, ss=2)


# ----------------------------------------------------------------------------------------------------------------------
# bushes, rocks, ore, crystals, mushrooms
# ----------------------------------------------------------------------------------------------------------------------
def bush(zone='farm', berries=False, seed=1) -> PropSpec:
    P = TREE_PAL[zone]; pm = PM()
    for i, (x, z, r) in enumerate([(0, 0, .52), (.45, .2, .38), (-.42, .15, .4), (.1, -.38, .36), (-.1, .42, .34)]):
        pm.clump((x, r * .7, z), r, P['leaf'], 'leaf', n=4, seed=seed * 7 + i, squash=.8)
    if berries:
        rng = np.random.default_rng(seed)
        for i in range(10):
            a = rng.uniform(0, 6.28); e = rng.uniform(.1, .9)
            pm.ell((math.cos(a) * math.cos(e) * .55, .45 + math.sin(e) * .4, math.sin(a) * math.cos(e) * .55), (.055, .055, .055), 'B3436B', 'soft', seg=12, rings=8)
    return spec(pm, f'bush_{zone}{"_berry" if berries else ""}_{seed}', shadow=(.85, .4))


def rock(kind='grey', seed=1, scale=1.0, mossy=False) -> PropSpec:
    cols = {'grey': ('9A9AA6', 'B5B5C0', '7C7C8A'), 'dark': ('555069', '6E6985', '3E3A50'), 'warm': ('B09A86', 'C9B6A2', '8F7A68')}[kind]
    pm = PM(); rng = np.random.default_rng(seed)
    pm.ell((0, .30 * scale, 0), (.62 * scale, .36 * scale, .52 * scale), cols[0], 'stone', power=.78, rot=(0, rng.uniform(0, 90), 0))
    pm.ell((.42 * scale, .2 * scale, .18 * scale), (.34 * scale, .24 * scale, .3 * scale), cols[1], 'stone', power=.8, rot=(0, 30, 0))
    pm.ell((-.38 * scale, .17 * scale, -.2 * scale), (.28 * scale, .18 * scale, .24 * scale), cols[2], 'stone', power=.8)
    if mossy:
        pm.ell((-.05 * scale, .62 * scale, 0), (.40 * scale, .12 * scale, .34 * scale), '6E9A4A', 'leaf', power=.9)
    return spec(pm, f'rock_{kind}_{seed}{"_moss" if mossy else ""}', shadow=(.9 * scale, .4 * scale))


ORE = {'iron': ('B5694A', 'D9926B'), 'gold': ('E9C06B', 'FFE49A'), 'copper': ('D98A5A', 'F2AE7C'), 'silver': ('C9D2E0', 'F0F4FA')}


def ore_node(kind='iron', seed=1) -> PropSpec:
    cols = ORE[kind]; pm = PM(); rng = np.random.default_rng(seed)
    pm.ell((0, .3, 0), (.66, .38, .56), '6E6985', 'stone', power=.75)
    pm.ell((.36, .22, .22), (.34, .24, .3), '857FA0', 'stone', power=.8)
    for i in range(9):
        a = rng.uniform(0, 6.28); e = rng.uniform(.25, .95)
        c = np.array([math.cos(a) * math.cos(e) * .6, .3 + math.sin(e) * .36, math.sin(a) * math.cos(e) * .5])
        pm.ell(c, (.15, .12, .15), cols[i % 2], 'crystal', power=.7, rot=(rng.uniform(0, 60), rng.uniform(0, 90), 0), seg=14, rings=10)
    return spec(pm, f'ore_{kind}_{seed}', shadow=(.9, .42), glow=(cols[1], 14, .18) if kind in ('gold', 'silver') else None)


CRYSTALS = {'amethyst': ('A57BE0', 'D2B4F5'), 'emerald': ('48B97F', '9BE7BC'), 'moonstone': ('B8D4F2', 'F2F8FF'), 'berry': ('D6638C', 'F5A8C4')}


def crystal(kind='amethyst', seed=1, scale=1.0) -> PropSpec:
    cols = CRYSTALS[kind]; pm = PM(); rng = np.random.default_rng(seed)
    pm.ell((0, .06, 0), (.5, .14, .42), '4E4866', 'stone', power=.8)
    specs = [(0, 0, 0, 1.45, .15, 0, 0), (.25, .05, .1, 1.0, .11, 18, 20), (-.28, 0, .05, 1.1, .12, -22, -10), (.1, 0, -.25, .85, .1, 10, -25), (-.1, 0, .28, .7, .09, -5, 28), (.4, 0, -.1, .55, .08, 25, 8)]
    for x, y, z, h, r, tx, tz in specs:
        h *= scale; r *= scale
        top = np.array([0, h, 0]); R = Rotation.from_euler('xyz', [tx, 0, tz], degrees=True).as_matrix()
        pts = np.array([[0, 0, 0], [0, h * .78, 0], [0, h * 1.0, 0]]) @ R.T + [x * scale, .08, z * scale]
        pm.tube(pts, [r, r * .95, .008], cols[0] if (x + z) > 0 else cols[1], 'crystal', sides=6, center=pts[0], rot=(0, rng.uniform(0, 60), 0))
    return spec(pm, f'crystal_{kind}_{seed}', shadow=(.8, .36), glow=(cols[1], 26, .55))


def glow_mushrooms(kind='teal', seed=1) -> PropSpec:
    cols = {'teal': ('6FD6C4', 'E8FFF8', 'CFEFE6'), 'pink': ('E58FA6', 'FFE6EE', 'F3D5DC'), 'blue': ('8FA9F2', 'EAF0FF', 'D6DFF7')}[kind]
    pm = PM(); rng = np.random.default_rng(seed)
    for i, (x, z, s) in enumerate([(0, 0, 1.0), (.42, .15, .7), (-.35, .2, .75), (.12, -.38, .55), (-.18, -.3, .45)]):
        h = .62 * s
        pm.curve([(x, 0, z), (x + .03, h * .5, z), (x, h, z)], .075 * s, .06 * s, cols[2], 'soft', 10, n=6)
        pm.ell((x, h + .02, z), (.34 * s, .17 * s, .34 * s), cols[0], 'soft', power=.9, seg=24, rings=12)
        pm.ell((x, h - .05, z), (.28 * s, .05 * s, .28 * s), cols[2], 'soft', seg=16, rings=6)
        for k in range(5):
            a = rng.uniform(0, 6.28); e = rng.uniform(.5, 1.2)
            pm.ell((x + math.cos(a) * math.cos(e) * .3 * s, h + .02 + math.sin(e) * .165 * s, z + math.sin(a) * math.cos(e) * .3 * s), (.05 * s, .02 * s, .05 * s), cols[1], 'soft', seg=10, rings=6)
    return spec(pm, f'glowmush_{kind}_{seed}', shadow=(.7, .32), glow=(cols[0], 30, .7))


# ----------------------------------------------------------------------------------------------------------------------
# furniture-ish: fence, scarecrow, bridge, lantern, chest
# ----------------------------------------------------------------------------------------------------------------------
WOOD = dict(honey='B88A52', dark='7A4E2D', pale='D6B27A')


def fence(axis='x', gate=False) -> PropSpec:
    pm = PM(); L = T
    for sx in (-.5, .5):
        pm.cyl((sx * L, 0, 0), (sx * L, .92, 0), .075, .06, WOOD['dark'], 'bark', 10)
        pm.ell((sx * L, .96, 0), (.085, .06, .085), WOOD['pale'], 'plank', seg=12, rings=8)
    for y in (.35, .66):
        pm.box((0, y, 0), (L * 1.0, .085, .07), WOOD['honey'], 'plank', power=.35)
    if gate:
        pm.box((0, .5, 0), (L * .08, .55, .06), WOOD['pale'], 'plank')
    sp = spec(pm, f'fence_{axis}{"_gate" if gate else ""}', shadow=(.55, .18))
    if axis == 'z': _yaw(pm.m, 90)
    return sp


def _yaw(m, deg):
    R = Rotation.from_euler('y', deg, degrees=True).as_matrix()
    for g in m.groups:
        for s in g.shapes: s.vertices = s.vertices @ R.T


def scarecrow() -> PropSpec:
    pm = PM()
    pm.cyl((0, 0, 0), (0, 1.75, 0), .07, .06, WOOD['dark'], 'bark', 8)
    pm.cyl((-.62, 1.32, 0), (.62, 1.32, 0), .05, .05, WOOD['dark'], 'bark', 8)
    pm.ell((0, 1.05, 0), (.34, .46, .26), '7A9CC4', 'straw', power=.9)          # patched tunic (blue)
    pm.ell((.14, .95, .2), (.1, .09, .04), 'E8B04A', 'straw')                    # patch
    pm.ell((0, 1.72, 0), (.24, .26, .22), 'E9D6A8', 'straw')                     # sack head
    for s in (-1, 1):
        pm.ell((s * .09, 1.76, .2), (.045, .05, .02), '2B2340', 'soft', seg=10, rings=8)
        pm.ell((s * .62, 1.30, 0), (.1, .08, .08), 'E3C372', 'straw')            # straw hands
    pm.curve([(-.08, 1.64, .21), (-.03, 1.60, .22), (.03, 1.60, .22), (.08, 1.64, .21)], .012, .012, '2B2340', 'soft', 6, n=8)
    pm.ell((0, 1.97, 0), (.46, .045, .46), 'E3C372', 'straw', seg=24, rings=8)   # straw hat
    pm.ell((0, 2.06, 0), (.24, .14, .24), 'E3C372', 'straw')
    pm.tube(np.array([(.24, 2.0, 0), (.0, 2.0, .24)]), .0, 'B3436B', 'soft', 4) if False else None
    return spec(pm, 'scarecrow', shadow=(.6, .25))


def rope_bridge(axis='x', post=True) -> PropSpec:
    pm = PM(); L = T
    for i in range(8):
        x = -L / 2 + (i + .5) * L / 8
        pm.box((x, 0, 0), (L / 8 * .86, .07, T * .92), WOOD['honey'] if i % 2 else WOOD['pale'], 'plank', power=.32)
    for z in (-T * .46, T * .46):
        pm.curve([(-L / 2, .62, z), (-L / 4, .50, z), (L / 4, .50, z), (L / 2, .62, z)], .028, .028, 'C9A66B', 'straw', 8, n=14)
        if post:
            pm.cyl((-L / 2, -.05, z), (-L / 2, .85, z), .065, .055, WOOD['dark'], 'bark', 8)
    sp = spec(pm, f'bridge_{axis}', shadow=(.6, .22))
    if axis == 'z': _yaw(pm.m, 90)
    return sp


def lantern_post(color='FFD98A') -> PropSpec:
    pm = PM()
    pm.cyl((0, 0, 0), (0, 2.1, 0), .08, .06, WOOD['dark'], 'bark', 10)
    pm.curve([(0, 2.05, 0), (.15, 2.3, 0), (.38, 2.32, 0), (.52, 2.18, 0)], .035, .03, '4A3A4D', 'soft', 8, n=10)
    pm.cyl((.52, 2.2, 0), (.52, 2.05, 0), .015, .015, '4A3A4D', 'soft', 6, n=2)
    pm.ell((.52, 1.88, 0), (.15, .20, .15), color, 'glassglow', power=.8)
    pm.ell((.52, 2.10, 0), (.19, .045, .19), '4A3A4D', 'soft', seg=14, rings=6)
    pm.ell((.52, 1.68, 0), (.17, .04, .17), '4A3A4D', 'soft', seg=14, rings=6)
    return spec(pm, 'lantern_post', shadow=(.4, .16), glow=(color, 46, .75))


def lantern_hand(color='FFD98A') -> PropSpec:
    pm = PM()
    pm.curve([(0, .62, 0), (0, .5, 0), (0, .44, 0)], .01, .01, '4A3A4D', 'soft', 6, n=4)
    pm.ell((0, .24, 0), (.14, .19, .14), color, 'glassglow', power=.8)
    pm.ell((0, .43, 0), (.17, .04, .17), '4A3A4D', 'soft', seg=14, rings=6)
    pm.ell((0, .05, 0), (.15, .035, .15), '4A3A4D', 'soft', seg=14, rings=6)
    return spec(pm, 'lantern_hand', glow=(color, 40, .9), shadow=None)


def chest(open_=False) -> PropSpec:
    pm = PM()
    pm.box((0, .27, 0), (.9, .54, .6), WOOD['honey'], 'plank', power=.3)
    for x in (-.28, .28): pm.box((x, .27, 0), (.07, .56, .63), '5B4A6E', 'stone', power=.3)
    lid_rot = (0, 0, 0)
    if not open_:
        pm.tube(np.array([(-.45, .54, 0), (.45, .54, 0)]), .30, WOOD['honey'], 'plank', 16, depth=.30) if False else None
        pm.ell((0, .56, 0), (.45, .22, .30), WOOD['honey'], 'plank', power=.7, seg=24, rings=12)
        for x in (-.28, .28): pm.ell((x, .56, 0), (.037, .235, .315), '5B4A6E', 'stone', power=.7, seg=12, rings=10)
        pm.box((0, .46, .31), (.1, .13, .05), 'E9C06B', 'crystal', power=.5)
    else:
        pm.ell((0, 1.0, -.38), (.45, .22, .30), WOOD['honey'], 'plank', power=.7, rot=(-70, 0, 0), seg=24, rings=12, pivot=(0, .55, -.3))
        pm.ell((0, .56, 0), (.40, .05, .26), 'E9C06B', 'crystal', power=.8)
        for i in range(7):
            pm.ell((np.cos(i * 2.4) * .22, .6 + .02 * (i % 2), np.sin(i * 2.4) * .12), (.07, .02, .07), 'FFE49A', 'crystal', seg=10, rings=6)
    return spec(pm, f'chest_{"open" if open_ else "closed"}', shadow=(.7, .3), glow=('FFE49A', 30, .35) if open_ else None)


# ----------------------------------------------------------------------------------------------------------------------
# buildings
# ----------------------------------------------------------------------------------------------------------------------
def house_farm() -> PropSpec:
    pm = PM(); w, d, h = T * 2.6, T * 2.2, 1.9
    pm.box((0, h / 2, 0), (w, h, d), 'F1E2BE', 'plank', power=.22)                                  # plaster + board walls
    for sx in (-1, 1):
        for sz in (-1, 1):
            pm.box((sx * (w / 2 - .02), h / 2, sz * (d / 2 - .02)), (.14, h + .04, .14), WOOD['dark'], 'bark', power=.3)   # corner posts
    pm.box((0, h - .08, d / 2), (w, .12, .08), WOOD['dark'], 'bark', power=.3)                       # eave beams
    pm.box((w / 2, h - .08, 0), (.08, .12, d), WOOD['dark'], 'bark', power=.3)
    pm.box((0, .06, 0), (w + .18, .14, d + .18), '8A8494', 'stone', power=.3)                        # stone plinth
    slope = 34; half = d * .5 + .30; run = half * math.cos(math.radians(slope)); rise = half * math.sin(math.radians(slope))
    for s in (-1, 1):                                                                                # gable roof, ridge along X
        pm.box((0, h + rise * .5 + .05, s * run * .5), (w + .5, .12, half), 'B5693F', 'roof', power=.25,
               rot=(s * slope, 0, 0), pivot=(0, h + rise * .5 + .05, s * run * .5))
    pm.cyl((-(w + .5) / 2, h + rise + .05, 0), ((w + .5) / 2, h + rise + .05, 0), .09, .09, '8B4E2F', 'roof', 10)
    tri = geo.rounded_triangle([(-d / 2 - .02, h - .02), (d / 2 + .02, h - .02), (0, h + rise + .06)], 5)
    for sx in (-1, 1):                                                                               # gable end walls
        pm.pillow(tri, sx * (w / 2 - .02), .05, 'F1E2BE', 'plank', rot=(0, 90, 0))
    pm.box((-w * .28, h + rise + .5, -d * .06), (.34, 1.0, .34), '8A8494', 'stone', power=.3)         # chimney
    pm.ell((-w * .28, h + rise + 1.02, -d * .06), (.22, .06, .22), '5B5468', 'stone', seg=12, rings=6)
    pm.box((-.3, .72, d / 2 + .02), (.62, 1.34, .08), '6B4126', 'plank', power=.3)                   # door on +z face
    pm.ell((-.1, .72, d / 2 + .07), (.05, .05, .03), 'E9C06B', 'crystal', seg=10, rings=6)
    pm.box((-.3, 1.43, d / 2 + .03), (.76, .14, .1), WOOD['dark'], 'bark', power=.3)
    pm.box((.78, 1.0, d / 2 + .03), (.62, .60, .06), WOOD['dark'], 'bark', power=.25)               # window on +z face
    pm.box((.78, 1.0, d / 2 + .06), (.52, .50, .05), 'FFE08F', 'glassglow', power=.26)
    pm.box((w / 2 + .03, 1.0, .0), (.06, .62, .64), WOOD['dark'], 'bark', power=.25)                 # window on +x face
    pm.box((w / 2 + .06, 1.0, .0), (.05, .52, .54), 'FFE08F', 'glassglow', power=.26)
    pm.box((.78, .62, d / 2 + .14), (.6, .12, .16), WOOD['honey'], 'plank')                         # flower box
    for i in range(5): pm.ell((.58 + i * .1, .72, d / 2 + .14), (.055, .06, .055), ('E58FA6', 'FBEAC8', 'B3436B', 'F2C14E', 'E58FA6')[i], 'soft', seg=10, rings=8)
    pm.box((-.3, .04, d / 2 + .38), (.9, .08, .5), '9A9AA6', 'stone', power=.3)                       # doorstep
    return spec(pm, 'house_farm', footprint=(3, 2), shadow=(2.4, 1.0))


def house_mushroom(cap='E58FA6', spot='FBF5E6', stem='F4E6C4') -> PropSpec:
    pm = PM()
    pm.cyl((0, 0, 0), (0, 1.55, 0), .98, .78, stem, 'plank' if False else 'soft', sides=24, n=8)
    pm.ell((0, 1.62, 0), (1.55, .78, 1.55), cap, 'soft', power=.9, seg=36, rings=20)
    pm.ell((0, 1.43, 0), (1.45, .12, 1.45), 'E9C9B5', 'soft', seg=30, rings=8)
    rng = np.random.default_rng(5)
    for i in range(12):
        a = i * 2.4; e = .35 + .55 * ((i * 37) % 10) / 10
        c = np.array([math.cos(a) * math.cos(e) * 1.53, 1.62 + math.sin(e) * .77, math.sin(a) * math.cos(e) * 1.53])
        pm.ell(c, (.20, .06, .20), spot, 'soft', seg=14, rings=8)
    # round door on +z (screen left) and window on +x (screen right)
    pm.ell((0, .62, .92), (.34, .52, .12), '7A4E2D', 'plank', power=.75, seg=20, rings=12)
    pm.ell((.04, .66, 1.01), (.04, .04, .03), 'E9C06B', 'crystal', seg=8, rings=6)
    pm.ell((.9, .95, .12), (.12, .30, .30), 'FFE08F', 'glassglow', power=.8)
    pm.ell((.97, .95, .12), (.08, .36, .36), '7A4E2D', 'plank', power=.8, seg=16, rings=10)
    pm.ell((.99, .95, .12), (.06, .30, .30), 'FFE08F', 'glassglow', power=.8, seg=16, rings=10)
    pm.cyl((.5, 2.1, -.5), (.55, 2.75, -.55), .12, .1, '8A8494', 'stone', 12)
    pm.ell((.55, 2.78, -.55), (.15, .05, .15), '5B5468', 'stone', seg=12, rings=6)
    return spec(pm, 'house_mushroom_' + cap, footprint=(2, 2), shadow=(1.7, .8), glow=('FFD98A', 20, .22))


def platform_edge(face='sw', style='farm') -> PropSpec:
    """Wooden facade hanging below the deck edge. face: sw (+z edge), se (+x edge), corner (both)."""
    pm = PM(); depth = 1.25; half = T / 2
    wood = ('B88A52', 'A47944', '7A4E2D') if style == 'farm' else ('C9A9D6', 'B592C6', '6A5A87')

    def facade(pos, along, n=4):
        for i in range(n):
            u = -T / 2 + (i + .5) * T / n
            hh = depth - .10 * ((i * 5) % 3) / 2
            c = np.array(pos) + np.array(along) * u
            sz = (T / n * .94, hh, .12) if along[0] != 0 else (.12, hh, T / n * .94)
            pm.box((c[0], -hh / 2 + .04, c[2]), sz, wood[i % 2], 'bark', power=.3)
        # two horizontal cross beams make it read as carpentry
        for y in (-.30, -depth + .22):
            sz = (T + .02, .12, .16) if along[0] != 0 else (.16, .12, T + .02)
            pm.box((pos[0], y, pos[2]), sz, wood[2], 'bark', power=.3)
    if face in ('sw', 'corner'):
        facade((0, 0, half + .02), (1, 0, 0))
        pm.box((0, .07, half + .02), (T + .02, .14, .18), wood[2], 'bark', power=.3)
    if face in ('se', 'corner'):
        facade((half + .02, 0, 0), (0, 0, 1))
        pm.box((half + .02, .07, 0), (.18, .14, T + .02), wood[2], 'bark', power=.3)
    if face == 'corner':
        pm.cyl((half + .02, -depth + .04, half + .02), (half + .02, .16, half + .02), .11, .10, wood[2], 'bark', 10)
    # soft moss tufts along the lower edge instead of spiky roots
    for i in range(2):
        u = -T / 2 + (i + .5) * T / 2
        pos = (u, -depth + .02, half + .06) if face != 'se' else (half + .06, -depth + .02, u)
        pm.clump(pos, .13, ('6E9A4A', '8CB866', '587F3A'), 'leaf', n=3, seed=i + 3, squash=.7)
    return spec(pm, f'platform_{face}_{style}', footprint=(1, 1), shadow=None)


# ----------------------------------------------------------------------------------------------------------------------
# crops: 4 plants x 4 growth stages (0 seed, 1 sprout, 2 growing, 3 ripe)
# ----------------------------------------------------------------------------------------------------------------------
LEAFG = ('6FAA46', '97C95E', '4F8A38')


def _leaf(pm, base, ang, length, width, tilt, colors=LEAFG, k=0):
    a = math.radians(ang)
    d = np.array([math.cos(a), 0, math.sin(a)])
    tip = np.array(base) + d * length * math.cos(math.radians(tilt)) + [0, length * math.sin(math.radians(tilt)), 0]
    mid = (np.array(base) + tip) / 2 + [0, .02, 0]
    pm.curve([base, np.array(base) + d * length * .35 + [0, length * .35 * math.sin(math.radians(tilt)) + .03, 0], tip - d * .02 + [0, .03, 0], tip], width, .004, colors[k % 3], 'leaf', 8, n=8)


def crop(kind='turnip', stage=3) -> PropSpec:
    pm = PM()
    if stage <= 1: pm.ell((0, .02, 0), (.2, .05, .17), '6B4A33', 'soil', seg=16, rings=8)  # small seed mound
    if stage == 0:
        for i in range(3): pm.ell((math.cos(i * 2.1) * .08, .06, math.sin(i * 2.1) * .07), (.022, .016, .03), 'E3C372', 'soft', seg=8, rings=6)
        return spec(pm, f'crop_{kind}_{stage}', shadow=(.4, .16), outline=True)
    n_leaf = {1: 2, 2: 5, 3: 7}[stage]; sc = {1: .35, 2: .7, 3: 1.0}[stage]
    if kind == 'turnip':
        if stage == 3:
            pm.ell((0, .17, 0), (.20, .20, .20), 'F3E6F0', 'soft', seg=18, rings=12)
            pm.ell((0, .27, 0), (.19, .11, .19), '9B6BA8', 'soft', seg=18, rings=10)
        for i in range(n_leaf): _leaf(pm, (0, .18 if stage == 3 else .06, 0), i * 360 / n_leaf + 20, .38 * sc, .05, 55 - 10 * (i % 2), k=i)
    elif kind == 'carrot':
        if stage == 3: pm.ell((0, .1, 0), (.1, .07, .1), 'F08A3C', 'soft', seg=14, rings=8)
        for i in range(n_leaf + 2):
            a = i * 360 / (n_leaf + 2); ar = math.radians(a)
            tip = (math.cos(ar) * .16 * sc, .12 + .5 * sc, math.sin(ar) * .16 * sc)
            pm.curve([(0, .08, 0), (math.cos(ar) * .04, .2 + .1 * sc, math.sin(ar) * .04), (tip[0] * .8, tip[1] * .8, tip[2] * .8), tip], .016, .004, LEAFG[i % 3], 'leaf', 6, n=8)
            pm.ell(tip, (.055 * sc + .01, .04 * sc + .01, .055 * sc + .01), LEAFG[(i + 1) % 3], 'leaf', seg=10, rings=6)
    elif kind == 'pumpkin':
        if stage == 3:
            for k in range(5):
                pm.ell((0, .24, 0), (.34, .26, .34), 'EE8A2E' if k % 2 == 0 else 'E3772A', 'soft', power=.9, rot=(0, k * 36, 0), seg=22, rings=14)
            pm.cyl((0, .46, 0), (.04, .62, .02), .05, .035, '6B8A3A', 'soft', 8, n=4)
        pm.curve([(.2, .06, .1), (.45, .08, .3), (.55, .07, .0), (.3, .06, -.25)], .018, .01, '6B8A3A', 'soft', 6, n=10) if stage >= 2 else None
        for i in range(n_leaf):
            ar = math.radians(i * 360 / n_leaf + 10); c = np.array([math.cos(ar) * (.35 if stage > 1 else .16) * sc, .2 + .08 * sc, math.sin(ar) * (.35 if stage > 1 else .16) * sc])
            pm.ell(c, (.18 * sc + .03, .02, .15 * sc + .03), LEAFG[i % 3], 'leaf', seg=12, rings=6, rot=(8, -i * 51, 6))
    elif kind == 'moonflower':
        h = {1: .18, 2: .62, 3: .9}[stage]
        pm.curve([(0, .05, 0), (.03, h * .5, 0), (-.02, h * .8, 0), (0, h, 0)], .028, .02, '5C9A52', 'soft', 8, n=10)
        for i in range(n_leaf - 1 if stage > 1 else 2): _leaf(pm, (0, .08 + i * .06 * (1 if stage > 1 else 0), 0), i * 137, .3 * sc + .05, .045, 30, k=i)
        if stage == 3:
            for i in range(8):
                ar = math.radians(i * 45)
                pm.ell((math.cos(ar) * .16, h + .06, math.sin(ar) * .16), (.12, .03, .07), 'E8F0FF' if i % 2 else 'CFE0FF', 'glassglow', rot=(0, -i * 45, 0), seg=14, rings=8, power=.85)
            pm.ell((0, h + .07, 0), (.08, .06, .08), 'FFE49A', 'crystal', seg=12, rings=8)
        elif stage == 2:
            pm.ell((0, h + .03, 0), (.06, .09, .06), 'CFE0FF', 'glassglow')
    glow = ('CFE0FF', 26, .55) if (kind == 'moonflower' and stage == 3) else None
    return spec(pm, f'crop_{kind}_{stage}', shadow=(.4, .16), glow=glow)


# ----------------------------------------------------------------------------------------------------------------------
PROPS = {
    'tree_giant_crown': tree_giant,
    'tree_oak_farm': lambda: tree_oak('farm', 1), 'tree_oak_farm_b': lambda: tree_oak('farm', 2, .9), 'tree_blossom_hyggebyen': lambda: tree_oak('hyggebyen', 3),
    'tree_pine_forest': lambda: tree_pine('forest', 1), 'tree_pine_forest_b': lambda: tree_pine('forest', 2, .82), 'tree_twisted': lambda: tree_twisted(1, True),
    'bush_farm': lambda: bush('farm', False), 'bush_berry': lambda: bush('farm', True, 2), 'bush_forest': lambda: bush('forest', False, 3),
    'rock_grey': lambda: rock('grey', 1), 'rock_mossy': lambda: rock('warm', 2, 1.1, True), 'rock_dark': lambda: rock('dark', 3, .8),
    'ore_iron': lambda: ore_node('iron'), 'ore_gold': lambda: ore_node('gold', 2), 'ore_copper': lambda: ore_node('copper', 3),
    'crystal_amethyst': lambda: crystal('amethyst'), 'crystal_moonstone': lambda: crystal('moonstone', 2), 'crystal_emerald': lambda: crystal('emerald', 3),
    'glowmush_teal': lambda: glow_mushrooms('teal'), 'glowmush_pink': lambda: glow_mushrooms('pink', 2), 'glowmush_blue': lambda: glow_mushrooms('blue', 3),
    'fence_x': lambda: fence('x'), 'fence_z': lambda: fence('z'), 'fence_gate_x': lambda: fence('x', True), 'scarecrow': scarecrow,
    'bridge_x': lambda: rope_bridge('x'), 'bridge_z': lambda: rope_bridge('z'), 'lantern_post': lantern_post, 'lantern_hand': lantern_hand,
    'chest_closed': lambda: chest(False), 'chest_open': lambda: chest(True),
    'house_farm': house_farm, 'house_mushroom_rose': lambda: house_mushroom('E58FA6'), 'house_mushroom_lavender': lambda: house_mushroom('9B86D6', 'FBF5E6', 'F4E6C4'),
    'house_mushroom_mint': lambda: house_mushroom('7FC8A5'),
    'platform_sw': lambda: platform_edge('sw'), 'platform_se': lambda: platform_edge('se'), 'platform_corner': lambda: platform_edge('corner'),
}
for _k in ('turnip', 'carrot', 'moonflower', 'pumpkin'):
    for _s in range(4):
        PROPS[f'crop_{_k}_{_s}'] = (lambda k=_k, s=_s: crop(k, s))
