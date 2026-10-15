#!/usr/bin/env python3
"""Ground tiles, painted + rendered with the character camera and lights (VTK) so the relief shades like the sprites.

Every terrain is a PERIODIC painted canvas of P x P tiles (4 x 4).  Tile (i, j) is the sub-square [i, i+1) x [j, j+1) of that canvas,
rendered as a heightfield from the 36-degree camera.  Because the canvas wraps, tile (x mod P, y mod P) is seamless against ANY
neighbour (16 variants per terrain, no edge rules to author).  Every tile carries ~1.4 px of overscan so neighbours overlap and no
hairline appears between them.

  iso    az 45 degrees, tile 128 x 76 (a true 36 degree diamond is 128 x 75.2), atlas cell 144 x 84, diamond mask    (plan 6.2)
  ortho  az 0, tile 96 x 56 (edge 1.1025 m x 1.0941 m at 87.074 px/m), atlas cell 112 x 64, rectangular mask           (NEW, P22 task 2)

The ortho bake is the same code with the camera turned to azimuth 0: the ground square of a tile is then a 96 x 56 rectangle
(width = edge * 87.074, height = edge * sin 36 * 87.074).  The tile is meshed 1.1025 m wide and 1.0941 m deep so it is EXACTLY
96 x 56 px and the engine lattice (step 96 / 56) matches the render to the pixel (the iso tile keeps the spike's 0.8 px mismatch).

Colours of the forest / cave terrains follow the baked-colour rule of the night look (DUNGEON addendum 7.5, v2_environment 4.4):
final = albedo x ambient, so the albedo painted here is the sketch colour divided by the ambient multiplier (forest 4d5e85, cave 343b5c).

  tools/art/produce_all.sh --only=tiles            (what the pipeline calls: bake_tiles.py --all --out <masters>/iso_tiles)
  python tools/art/environment/bake_tiles.py [--iso | --ortho] [names...] --out DIR [--ss 3]
Output: <terrain>.png atlas (iso) / ortho_<terrain>.png (ortho) + tiles.json (merged with what is already in DIR).
"""
from __future__ import annotations
import argparse, json, math, sys, time
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageChops
from scipy import ndimage

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'core'))
import artpaths                       # noqa: E402,F401  (adds tools/art/generator, core, environment to sys.path)
import static_render as sr            # noqa: E402

P = 4                          # periodic variants per axis
CELL_W, CELL_H = 144, 84       # iso atlas cell (diamond is 128 x 75.2, plus overscan and relief headroom)
OCELL_W, OCELL_H = 112, 64     # ortho atlas cell (rectangle is 96 x 56, plus overscan and relief headroom)
ORTHO_W, ORTHO_H = 96, 56
RES = 256                      # canvas pixels per tile
OVERSCAN = .06                 # mesh margin (hides rim shading); the alpha mask below keeps only ~1.4 px of it

# the ortho tile in metres: 96 px wide, 56 px deep seen from 36 degrees
ORTHO_TX = ORTHO_W / sr.PX_PER_M
ORTHO_TZ = ORTHO_H / (sr.PX_PER_M * math.sin(math.radians(sr.ELEV)))

# ambient multipliers of the zone presets (lua/config/ambient.lua): final = albedo x ambient
AMBIENT_FOREST = (0x4d, 0x5e, 0x85)
AMBIENT_CAVE = (0x34, 0x3b, 0x5c)


def hexrgb(c): return np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def albedo_for(final_hex, ambient=AMBIENT_FOREST):
    """The baked colour (hex) that shows as `final_hex` under the ambient grade: final / ambient per channel, capped at 255."""
    f = hexrgb(final_hex)
    a = np.asarray(ambient, np.float32)
    return '%02X%02X%02X' % tuple(int(round(v)) for v in np.clip(f / a * 255.0, 0, 255))


def pnoise(n, cells, rng, order=3):
    """Periodic value noise in [-.5,.5], n x n, `cells` random lattice points per side."""
    r = rng.random((cells, cells)).astype(np.float32)
    z = ndimage.zoom(r, n / cells, order=order, mode='grid-wrap', grid_mode=True)
    z = z[:n, :n]
    return (z - z.min()) / max(z.max() - z.min(), 1e-6) - .5


def wrap_draw(canvas_size, fn):
    """Call fn(dx, dy) for the 9 wrapped offsets so strokes crossing an edge reappear on the opposite one."""
    for dx in (-canvas_size, 0, canvas_size):
        for dy in (-canvas_size, 0, canvas_size):
            fn(dx, dy)


class Canvas:
    def __init__(self, base_rgb, seed, P=P):
        self.n = P * RES; self.P = P
        self.rng = np.random.default_rng(seed)
        self.rgb = np.ones((self.n, self.n, 3), np.float32) * np.asarray(base_rgb, np.float32)
        self.h = np.zeros((self.n, self.n), np.float32)
        self.layers = []

    def tint(self, amount, cells, lo_hi=(.88, 1.12), per_channel=None):
        nz = pnoise(self.n, cells, self.rng) * 2 * amount
        k = 1 + nz
        self.rgb *= k[:, :, None]
        return self

    def shade_hue(self, color, cells, strength):
        """Blend toward `color` where periodic noise is high (painterly colour patches)."""
        w = np.clip(pnoise(self.n, cells, self.rng) * 2 + .5, 0, 1) ** 1.5 * strength
        self.rgb = self.rgb * (1 - w[:, :, None]) + hexrgb(color)[None, None, :] * w[:, :, None]
        return self

    def image(self):
        return Image.fromarray(np.uint8(np.clip(self.rgb, 0, 255)), 'RGB')

    def paint(self, painter):
        """painter(draw: ImageDraw (RGBA), rng, n) draws strokes with wrap helper; result alpha-composited onto rgb."""
        layer = Image.new('RGBA', (self.n, self.n), (0, 0, 0, 0)); d = ImageDraw.Draw(layer, 'RGBA')
        painter(d, self.rng, self.n)
        base = Image.fromarray(np.uint8(np.clip(self.rgb, 0, 255)), 'RGB').convert('RGBA'); base.alpha_composite(layer)
        self.rgb = np.asarray(base.convert('RGB'), np.float32)
        return self


# ----------------------------------------------------------------------------------------------------------------------
# iso terrain recipes (the verified spike set: unchanged)
# ----------------------------------------------------------------------------------------------------------------------
def blades(d, rng, n, count, palette, length=(6, 13), width=2, alpha=(110, 200), lean=.35):
    cols = [tuple(int(v) for v in hexrgb(c)) for c in palette]

    def one(dx, dy, x, y, L, c, a, bend):
        d.line([(x + dx, y + dy), (x + dx + bend * L * .5, y + dy - L * .55), (x + dx + bend * L, y + dy - L)], fill=c + (a,), width=width, joint='curve')
    for i in range(count):
        x, y = rng.uniform(0, n), rng.uniform(0, n); L = rng.uniform(*length); c = cols[rng.integers(len(cols))]
        a = int(rng.integers(*alpha)); bend = rng.uniform(-lean, lean)
        wrap_draw(n, lambda dx, dy: one(dx, dy, x, y, L, c, a, bend)) if (x < 20 or y < 20 or x > n - 20 or y > n - 20) else one(0, 0, x, y, L, c, a, bend)


def dots(d, rng, n, count, palette, r=(2, 4), alpha=(200, 255)):
    cols = [tuple(int(v) for v in hexrgb(c)) for c in palette]
    for i in range(count):
        x, y = rng.uniform(0, n), rng.uniform(0, n); rr = rng.uniform(*r); c = cols[rng.integers(len(cols))]; a = int(rng.integers(*alpha))
        wrap_draw(n, lambda dx, dy: d.ellipse((x + dx - rr, y + dy - rr, x + dx + rr, y + dy + rr), fill=c + (a,)))


def flowers(d, rng, n, count, palette, petal=3.2):
    cols = [tuple(int(v) for v in hexrgb(c)) for c in palette]
    for i in range(count):
        x, y = rng.uniform(10, n - 10), rng.uniform(10, n - 10); c = cols[rng.integers(len(cols))]
        for k in range(5):
            a = k * 2 * math.pi / 5; px, py = x + math.cos(a) * petal * 1.0, y + math.sin(a) * petal * 1.0
            d.ellipse((px - petal * .8, py - petal * .8, px + petal * .8, py + petal * .8), fill=c + (255,))
        d.ellipse((x - petal * .55, y - petal * .55, x + petal * .55, y + petal * .55), fill=(250, 214, 110, 255))


GRASS_STYLES = {
    'farm': dict(base='98C363', hue1='B8D77A', hue2='7FB252', blades=['6FA84A', '86BC55', 'AED36D', '5C9B43', 'C6E08A'], flowers=['FFFFFF', 'F7E39B', 'F4B6C8', 'D9C8F4']),
    'hyggebyen': dict(base='A9CFA6', hue1='C9E3B8', hue2='8FBFA6', blades=['7DB08E', '94C69C', 'BDE0B0', '6AA588', 'D5EBC2'], flowers=['FFFFFF', 'F4B6C8', 'E58FA6', 'D9C8F4', 'B9A9E8']),
}


def terrain_grass(variant='lush', style='farm'):
    """variant only ADDS flowers after the shared base (same seed/rng order) so 'grass' and 'grass_flowers' tiles mix without seams."""
    st = GRASS_STYLES[style]
    cv = Canvas(hexrgb(st['base']), 1 if style == 'farm' else 21)
    cv.tint(.07, 5).tint(.045, 14).shade_hue(st['hue1'], 7, .55).shade_hue(st['hue2'], 9, .45)
    cv.paint(lambda d, r, n: blades(d, r, n, 5200, st['blades'], (5, 11), 2, (70, 150)))
    cv.h = (pnoise(cv.n, 22, np.random.default_rng(99)) * .03).astype(np.float32)
    fr = np.random.default_rng(7)          # decoration rng is independent of the base rng
    if variant == 'flowers':
        cv.paint(lambda d, r, n: flowers(d, fr, n, 70, st['flowers']))
        cv.paint(lambda d, r, n: dots(d, fr, n, 40, st['blades'][:2], (3, 6), (90, 160)))
    else:
        cv.paint(lambda d, r, n: flowers(d, fr, n, 14, st['flowers'][:2]))
    return cv


def terrain_soil(wet=False, seed=2):
    cv = Canvas(hexrgb('6B4A30' if not wet else '3F2C1D'), seed)
    cv.tint(.08, 6).tint(.06, 24)
    rows = P * 6                      # 6 furrows per tile along x
    yy = (np.arange(cv.n)[:, None] / cv.n * rows)
    wave = np.sin(yy * 2 * math.pi).astype(np.float32)
    wave = np.repeat(wave, cv.n, axis=1)
    cv.rgb *= (1 + wave[:, :, None] * (-.12 if not wet else -.16))
    cv.h = (wave * .035 + pnoise(cv.n, 40, cv.rng) * .014).astype(np.float32)
    cv.paint(lambda d, r, n: dots(d, r, n, 900, ['7E5A3C', '503522', '8C6746'] if not wet else ['5A402B', '2C1E14', '6A4E38'], (1, 3), (80, 170)))
    if wet:
        cv.paint(lambda d, r, n: dots(d, r, n, 120, ['7FA9C4'], (2, 5), (30, 70)))
    return cv


def terrain_path(seed=3):
    cv = Canvas(hexrgb('D9BE8C'), seed)
    cv.tint(.06, 6).tint(.05, 20).shade_hue('E9D3A3', 8, .5).shade_hue('C4A672', 10, .35)
    cv.paint(lambda d, r, n: dots(d, r, n, 520, ['EBD9B0', 'B8996A', 'A98B60', 'F3E6C4'], (2, 6), (140, 235)))
    cv.paint(lambda d, r, n: blades(d, r, n, 260, ['8DB45C', '6FA84A'], (5, 9), 2, (80, 150)))
    cv.h = (pnoise(cv.n, 30, cv.rng) * .02).astype(np.float32)
    return cv


def terrain_deck(style='farm', seed=4):
    base = 'C79B5E' if style == 'farm' else 'D6BEE0'
    cv = Canvas(hexrgb(base), seed)
    cv.tint(.05, 6)
    boards = P * 4; bh = cv.n / boards
    idx = (np.arange(cv.n)[:, None] // bh).astype(int)
    tone = np.array([cv.rng.uniform(-.09, .07) for _ in range(boards + 1)])[idx]
    cv.rgb *= (1 + np.repeat(tone, cv.n, axis=1))[:, :, None]
    grain = pnoise(cv.n, 12, cv.rng) * .5
    xs = np.arange(cv.n)[None, :]
    cv.rgb *= (1 + (np.sin(xs / 7.0 + grain * 14) * .035))[:, :, None]
    # board seams (dark) + end joints
    seam = np.zeros((cv.n, cv.n), np.float32)
    local = (np.arange(cv.n)[:, None] % bh) / bh
    seam[:] = np.exp(-((np.minimum(local, 1 - local)) ** 2) / (2 * .02 ** 2))
    cv.rgb *= (1 - seam[:, :, None] * .30)
    cv.h = (-seam * .02 + pnoise(cv.n, 30, cv.rng) * .004).astype(np.float32)

    def nails(d, rng, n):
        for b in range(boards):
            yc = (b + .5) * bh
            for tx in range(P):
                for fx in (.12, .88):
                    x = (tx + fx) * RES
                    d.ellipse((x - 2, yc - 2, x + 2, yc + 2), fill=(90, 66, 44, 200))
        for i in range(160):
            x, y = rng.uniform(0, n), rng.uniform(0, n)
            d.line((x, y, x + rng.uniform(8, 22), y), fill=(120, 84, 48, 70), width=1)
    cv.paint(nails)
    return cv


def terrain_water(frame=0, seed=5):
    cv = Canvas(hexrgb('7FC2CF'), seed, 2)
    cv.tint(.05, 4).shade_hue('A9DDE5', 5, .5).shade_hue('5FA9BE', 6, .4)
    ph = frame * 2 * math.pi / 4

    def ripples(d, r, n):
        for i in range(70):
            x, y = r.uniform(0, n), r.uniform(0, n); w = r.uniform(26, 60); a = ph + i
            dy = math.sin(a) * 2.0
            wrap_draw(n, lambda dx, ddy: d.arc((x + dx - w, y + ddy + dy - w * .28, x + dx + w, y + ddy + dy + w * .28), 195, 345, fill=(235, 250, 252, 120), width=2))
    cv.paint(ripples)
    cv.h = (np.sin(np.arange(cv.n)[None, :] / cv.n * 2 * math.pi * 2 + ph) * np.cos(np.arange(cv.n)[:, None] / cv.n * 2 * math.pi * 2) * .006).astype(np.float32)
    return cv


def terrain_cobble(seed=6, style='hyggebyen'):
    cv = Canvas(hexrgb('C9BDE0' if style == 'hyggebyen' else '9A9AA6'), seed)
    cv.tint(.03, 6)
    # voronoi-ish cobbles on a periodic canvas
    n = cv.n; k = 5 * P
    pts = (np.array([(i + .5 + (cv.rng.random() - .5) * .7, j + .5 + (cv.rng.random() - .5) * .7) for i in range(k) for j in range(k)]) * n / k)
    from scipy.spatial import cKDTree
    allp = np.vstack([pts + [ox, oy] for ox in (-n, 0, n) for oy in (-n, 0, n)])
    ids = np.tile(np.arange(len(pts)), 9)
    tree = cKDTree(allp)
    yy, xx = np.mgrid[0:n:2, 0:n:2]
    dist, nn = tree.query(np.c_[xx.ravel(), yy.ravel()], k=2)
    best = (dist[:, 0] ** 2).reshape(xx.shape); second = (dist[:, 1] ** 2).reshape(xx.shape); who = ids[nn[:, 0]].reshape(xx.shape)
    edge = (np.sqrt(second) - np.sqrt(best))
    hgt = np.clip(edge / 11.0, 0, 1) ** .6
    tone = np.array([cv.rng.uniform(-.08, .08) for _ in range(len(pts))])[who]
    palette = [hexrgb(c) for c in (['C9BDE0', 'D7CCEA', 'BDAEDA', 'E3C6D6'] if style == 'hyggebyen' else ['9A9AA6', 'A9A9B6', '8C8C99'])]
    cols = np.array([palette[int(i) % len(palette)] for i in range(len(pts))])[who]
    img = cols * (1 + tone[:, :, None]) * (.62 + .38 * hgt[:, :, None])
    img = Image.fromarray(np.uint8(np.clip(img, 0, 255)), 'RGB').resize((n, n), Image.BICUBIC)
    cv.rgb = np.asarray(img, np.float32)
    hg = np.asarray(Image.fromarray(np.uint8(hgt * 255)).resize((n, n), Image.BICUBIC), np.float32) / 255
    cv.h = (hg * .05 + pnoise(n, 30, cv.rng) * .004).astype(np.float32)
    return cv


def terrain_forest(glow=False, seed=7):
    cv = Canvas(hexrgb('46685A'), seed)
    cv.tint(.10, 5).tint(.07, 16).shade_hue('2F4A3E', 8, .55).shade_hue('5A7A60', 6, .35)
    cv.paint(lambda d, r, n: blades(d, r, n, 3600, ['2F4A3E', '5A8A6C', '3C6150', '6A9C7E'], (4, 9), 2, (70, 140)))

    def litter(d, r, n):
        cols = [(120, 84, 70), (90, 64, 74), (140, 104, 70)]
        for i in range(260):
            x, y = r.uniform(0, n), r.uniform(0, n); a = r.uniform(0, 6.28); L = r.uniform(5, 11); c = cols[r.integers(3)]
            wrap_draw(n, lambda dx, dy: d.ellipse((x + dx - L, y + dy - L * .45, x + dx + L, y + dy + L * .45), fill=c + (120,)))
        for i in range(34):   # roots
            x, y = r.uniform(0, n), r.uniform(0, n)
            pts = [(x, y)]
            for k in range(5): pts.append((pts[-1][0] + r.uniform(-18, 18), pts[-1][1] + r.uniform(4, 20)))
            wrap_draw(n, lambda dx, dy: d.line([(a + dx, b + dy) for a, b in pts], fill=(70, 52, 62, 150), width=3, joint='curve'))
    cv.paint(litter)
    cv.h = (pnoise(cv.n, 26, np.random.default_rng(98)) * .04).astype(np.float32)
    fr = np.random.default_rng(5 if glow else 6)
    cv.paint(lambda d, r, n: dots(d, fr, n, 120 if glow else 22, ['6FD6C4', 'B9F2E6', '8FA9F2'], (1.5, 3.2), (170, 255)))
    if glow:
        cv.paint(lambda d, r, n: dots(d, fr, n, 40, ['6FD6C4'], (7, 12), (22, 44)))
    return cv


def terrain_void(seed=8):
    cv = Canvas(hexrgb('C8DCE8'), seed)
    cv.tint(.04, 4).shade_hue('E6EEF4', 5, .65).shade_hue('A9C7DC', 6, .45)
    cv.h = np.zeros((cv.n, cv.n), np.float32)
    return cv


# ----------------------------------------------------------------------------------------------------------------------
# ortho terrain recipes (NEW): Moerkeskoven floor, bog, cave, crystal floor, dark border.  Painted in BAKED colours
# (sketch colour / ambient): see albedo_for().  The relief is small: these floors are meant to be lit by the engine lights.
# ----------------------------------------------------------------------------------------------------------------------
def terrain_forest_o(glow=False, seed=17):
    """Forest floor of the sketch: ground #232a45 with darker / lighter blobs (#2a3352), seen through the 4d5e85 grade.
    The glow variant shares the base (same seeds, rng order) and only ADDS glimmers and soft halos, so 'forest_floor_o' and
    'forest_floor_glow_o' cells mix without a seam (the same rule as grass / grass_flowers)."""
    base = albedo_for('232a45')                 # 747284
    lite = albedo_for('2a3352')                 # 8b8a9d
    dark = albedo_for('171c33')                 # a darker blob, still lavender
    cv = Canvas(hexrgb(base), seed)
    cv.tint(.08, 5).tint(.05, 16).shade_hue(lite, 6, .6).shade_hue(dark, 8, .55)
    stroke = [albedo_for(c) for c in ('141a30', '33406a', '1c2340', '3a4572', '101528')]
    cv.paint(lambda d, r, n: blades(d, r, n, 3400, stroke, (5, 12), 2, (80, 160)))

    def litter(d, r, n):
        cols = [tuple(int(v) for v in hexrgb(albedo_for(c))) for c in ('3a2c3e', '4a3442', '2b3248')]   # fallen leaves: warmer, still dark
        for i in range(210):
            x, y = r.uniform(0, n), r.uniform(0, n); L = r.uniform(5, 12); c = cols[r.integers(3)]
            wrap_draw(n, lambda dx, dy: d.ellipse((x + dx - L, y + dy - L * .45, x + dx + L, y + dy + L * .45), fill=c + (140,)))
        rc = tuple(int(v) for v in hexrgb(albedo_for('0f1326')))
        for i in range(26):   # roots
            x, y = r.uniform(0, n), r.uniform(0, n)
            pts = [(x, y)]
            for k in range(5): pts.append((pts[-1][0] + r.uniform(-18, 18), pts[-1][1] + r.uniform(4, 20)))
            wrap_draw(n, lambda dx, dy: d.line([(a + dx, b + dy) for a, b in pts], fill=rc + (150,), width=3, joint='curve'))
    cv.paint(litter)
    cv.h = (pnoise(cv.n, 26, np.random.default_rng(198)) * .035).astype(np.float32)
    fr = np.random.default_rng(15 if glow else 16)
    if glow:
        # glimmers cannot be baked bright (R 6f > 4d): they are the palest the ambient lets through; the teal comes from the lights
        cv.paint(lambda d, r, n: dots(d, fr, n, 150, [albedo_for(c) for c in ('4a6a86', '3f7080', '5a6f9a', '6a86a8')], (1.5, 3.4), (170, 255)))
        cv.paint(lambda d, r, n: dots(d, fr, n, 46, [albedo_for('2f6a70')], (7, 13), (34, 64)))
    else:
        cv.paint(lambda d, r, n: dots(d, fr, n, 24, [albedo_for(c) for c in ('2a3a5a', '33406a')], (1.5, 3.2), (130, 220)))
    return cv


def terrain_moss_path_o(seed=18):
    """The lit path of the sketch (#3b3c5e, dotted centre line #45466a, outline #14112a) as a TILE: the smooth S-curve is a decal
    (V8's SoftGround, path_tile_o); this tile is the collision / fallback look under it."""
    cv = Canvas(hexrgb(albedo_for('3b3c5e')), seed)       # c3a3b4
    cv.tint(.05, 5).tint(.035, 15).shade_hue(albedo_for('45466a'), 7, .5).shade_hue(albedo_for('33344f'), 9, .35)
    pebbles = [albedo_for(c) for c in ('45466a', '2e2f49', '4c4d72', '3a3b5b')]
    cv.paint(lambda d, r, n: dots(d, r, n, 420, pebbles, (2, 5), (110, 200)))
    moss = [albedo_for(c) for c in ('2d4a4a', '35544f', '264240')]
    cv.paint(lambda d, r, n: blades(d, r, n, 420, moss, (4, 8), 2, (60, 120)))
    cv.h = (pnoise(cv.n, 28, cv.rng) * .02).astype(np.float32)
    return cv


def terrain_bog_o(seed=19):
    """The Moon pond water (#1c4a5a, inner #235a6a) with a few lighter ripple arcs; ground_block."""
    cv = Canvas(hexrgb(albedo_for("1c4a5a")), seed)    # 5dc9ad (4 x 4 periodic variants like every ortho terrain)
    cv.tint(.04, 4).shade_hue(albedo_for('235a6a'), 5, .55).shade_hue(albedo_for('163c4a'), 6, .35)

    def ripples(d, r, n):
        c = tuple(int(v) for v in hexrgb(albedo_for('2e7080')))
        for i in range(46):
            x, y = r.uniform(0, n), r.uniform(0, n); w = r.uniform(24, 54)
            wrap_draw(n, lambda dx, dy: d.arc((x + dx - w, y + dy - w * .28, x + dx + w, y + dy + w * .28), 195, 345, fill=c + (130,), width=2))
    cv.paint(ripples)
    cv.h = (np.sin(np.arange(cv.n)[None, :] / cv.n * 2 * math.pi * 2) * np.cos(np.arange(cv.n)[:, None] / cv.n * 2 * math.pi * 2) * .006).astype(np.float32)
    return cv


def terrain_cave_o(crystal=False, seed=20):
    """Cave floor under the darker cave grade 343b5c: cold stone with cracks.  The crystal variant adds violet-blue facets (same base)."""
    base = albedo_for('1b2038', AMBIENT_CAVE)
    cv = Canvas(hexrgb(base), seed)
    cv.tint(.07, 6).tint(.05, 18).shade_hue(albedo_for('262c48', AMBIENT_CAVE), 7, .5).shade_hue(albedo_for('141830', AMBIENT_CAVE), 9, .45)

    def cracks(d, r, n):
        c = tuple(int(v) for v in hexrgb(albedo_for('0e1224', AMBIENT_CAVE)))
        for i in range(40):
            x, y = r.uniform(0, n), r.uniform(0, n)
            pts = [(x, y)]
            for k in range(5): pts.append((pts[-1][0] + r.uniform(-22, 22), pts[-1][1] + r.uniform(-22, 22)))
            wrap_draw(n, lambda dx, dy: d.line([(a + dx, b + dy) for a, b in pts], fill=c + (130,), width=2, joint='curve'))
        pebble = [albedo_for(c, AMBIENT_CAVE) for c in ('2a3050', '323a5c', '20263f')]
        cc = [tuple(int(v) for v in hexrgb(p)) for p in pebble]
        for i in range(260):
            x, y = r.uniform(0, n), r.uniform(0, n); rr = r.uniform(2, 6); col = cc[r.integers(3)]
            wrap_draw(n, lambda dx, dy: d.ellipse((x + dx - rr, y + dy - rr * .7, x + dx + rr, y + dy + rr * .7), fill=col + (150,)))
    cv.paint(cracks)
    cv.h = (pnoise(cv.n, 30, np.random.default_rng(220)) * .05).astype(np.float32)
    fr = np.random.default_rng(21 if crystal else 22)
    if crystal:
        cv.paint(lambda d, r, n: dots(d, fr, n, 90, [albedo_for(c, AMBIENT_CAVE) for c in ('4a4a90', '3a6a9a', '5a4a9a')], (2, 5), (150, 240)))
        cv.shade_hue(albedo_for('2c3a6a', AMBIENT_CAVE), 6, .4)
    else:
        cv.paint(lambda d, r, n: dots(d, fr, n, 20, [albedo_for('2e3a60', AMBIENT_CAVE)], (1.5, 3), (100, 180)))
    return cv


def terrain_wall_void_o(seed=23):
    """The dark map border: a flat navy floor with faint blotches (the dungeon floors do not use it; the fixtures' W cells do)."""
    cv = Canvas(hexrgb(albedo_for('10152a')), seed)       # 4a4538-ish after the grade: nearly black
    cv.tint(.05, 4).shade_hue(albedo_for('0c1022'), 6, .5).shade_hue(albedo_for('171d36'), 5, .4)
    cv.h = np.zeros((cv.n, cv.n), np.float32)
    return cv


TERRAINS = {
    'grass': lambda: terrain_grass('lush'), 'grass_flowers': lambda: terrain_grass('flowers'), 'grass_hyggebyen': lambda: terrain_grass('lush', 'hyggebyen'),
    'grass_hyggebyen_flowers': lambda: terrain_grass('flowers', 'hyggebyen'), 'soil_tilled': lambda: terrain_soil(False),
    'soil_watered': lambda: terrain_soil(True), 'path_dirt': terrain_path, 'deck_farm': lambda: terrain_deck('farm'), 'deck_hyggebyen': lambda: terrain_deck('hyggebyen', 9),
    'cobble_hyggebyen': terrain_cobble, 'forest_floor': lambda: terrain_forest(False), 'forest_floor_glow': lambda: terrain_forest(True), 'void_haze': terrain_void,
}
for _f in range(4): TERRAINS[f'water_{_f}'] = (lambda f=_f: terrain_water(f))

ORTHO_TERRAINS = {
    'forest_floor_o': lambda: terrain_forest_o(False), 'forest_floor_glow_o': lambda: terrain_forest_o(True), 'moss_path_o': terrain_moss_path_o,
    'bog_o': terrain_bog_o, 'cave_floor_o': lambda: terrain_cave_o(False), 'crystal_floor_o': lambda: terrain_cave_o(True), 'wall_void_o': terrain_wall_void_o,
}


def ortho_file(name: str) -> str:
    """res://assets/iso_tiles file of an ortho terrain id: forest_floor_o -> ortho_forest_floor.png."""
    return 'ortho_%s.png' % (name[:-2] if name.endswith('_o') else name)


# ----------------------------------------------------------------------------------------------------------------------
def tile_mesh(cv: Canvas, i, j, grid=40, amp=1.0, tx=None, tz=None):
    """Heightfield for tile (i,j) (indices into the periodic canvas), expanded by OVERSCAN, UV into the canvas (wraps).
    tx / tz = tile edge in metres along the canvas x / y (default: the iso tile edge for both)."""
    Pn = cv.P; Tx = tx or sr.TILE_M; Tz = tz or sr.TILE_M; m = OVERSCAN
    u = np.linspace(-.5 - m, .5 + m, grid); v = np.linspace(-.5 - m, .5 + m, grid)
    U, V = np.meshgrid(u, v)                                   # U along +x, V along +z
    cu = (i + .5 + U) / Pn; cv_ = (j + .5 + V) / Pn             # canvas coords in tile units / P
    rows = (cv_ % 1.0) * cv.n; cols = (cu % 1.0) * cv.n
    H = ndimage.map_coordinates(cv.h, [rows, cols], order=1, mode='grid-wrap') * amp
    pos = np.stack([U * Tx, H, V * Tz], -1).reshape(-1, 3)
    uv = np.stack([cu, cv_], -1).reshape(-1, 2)
    faces = []
    for a in range(grid - 1):
        for b in range(grid - 1):
            p0 = a * grid + b; p1 = p0 + 1; p2 = p0 + grid; p3 = p2 + 1
            faces += [[p0, p2, p1], [p1, p2, p3]]
    faces = np.array(faces, np.int32)
    # analytic normals from the periodic height canvas: identical on both sides of a tile border (no rim light seams)
    e = 1.0 / RES * .5

    def hs(du, dv):
        r = (((j + .5 + V + dv) / Pn) % 1.0) * cv.n; c = (((i + .5 + U + du) / Pn) % 1.0) * cv.n
        return ndimage.map_coordinates(cv.h, [r, c], order=1, mode='grid-wrap') * amp
    dhdx = (hs(e * Pn, 0) - hs(-e * Pn, 0)) / (2 * e * Pn * Tx)
    dhdz = (hs(0, e * Pn) - hs(0, -e * Pn)) / (2 * e * Pn * Tz)
    n = np.stack([-dhdx, np.ones_like(dhdx), -dhdz], -1); n /= np.linalg.norm(n, axis=-1, keepdims=True)
    n = n.reshape(-1, 3)
    # winding: make face normals point up (+y)
    fn = np.cross(pos[faces[:, 1]] - pos[faces[:, 0]], pos[faces[:, 2]] - pos[faces[:, 0]])
    if fn[:, 1].mean() < 0: faces = faces[:, ::-1]
    return pos, n, uv, faces


_MASK = {}


def diamond_mask(ov=1.4, ss=8):
    """Anti-aliased diamond (128 x 75.2 + ov px overscan) in a CELL_W x CELL_H image."""
    if 'iso' not in _MASK:
        k = math.sin(math.radians(sr.ELEV))
        hw, hh = 64 + ov, 64 * k + ov * k
        im = Image.new('L', (CELL_W * ss, CELL_H * ss), 0); cx, cy = CELL_W * ss / 2, CELL_H * ss / 2
        ImageDraw.Draw(im).polygon([(cx, cy - hh * ss), (cx + hw * ss, cy), (cx, cy + hh * ss), (cx - hw * ss, cy)], fill=255)
        _MASK['iso'] = im.resize((CELL_W, CELL_H), Image.LANCZOS)
    return _MASK['iso']


def rect_mask(ov=1.4, ss=8):
    """Anti-aliased rectangle (96 x 56 + ov px overscan on every side) in an OCELL_W x OCELL_H image."""
    if 'ortho' not in _MASK:
        im = Image.new('L', (OCELL_W * ss, OCELL_H * ss), 0); cx, cy = OCELL_W * ss / 2, OCELL_H * ss / 2
        hw, hh = ORTHO_W / 2 + ov, ORTHO_H / 2 + ov
        ImageDraw.Draw(im).rectangle([cx - hw * ss, cy - hh * ss, cx + hw * ss - 1, cy + hh * ss - 1], fill=255)
        _MASK['ortho'] = im.resize((OCELL_W, OCELL_H), Image.LANCZOS)
    return _MASK['ortho']


def bake_terrain(name, cv: Canvas, out: Path, ss=3, ortho=False):
    img = cv.image()
    cw, ch = (OCELL_W, OCELL_H) if ortho else (CELL_W, CELL_H)
    atlas = Image.new('RGBA', (cv.P * cw, cv.P * ch), (0, 0, 0, 0))
    for j in range(cv.P):
        for i in range(cv.P):
            if ortho:
                pos, n, uv, faces = tile_mesh(cv, i, j, tx=ORTHO_TX, tz=ORTHO_TZ)
            else:
                pos, n, uv, faces = tile_mesh(cv, i, j)
            r = sr.StaticRenderer(pos, n, uv, faces, img, repeat=True)
            tile = r.render(cw, ch, az=0.0 if ortho else 45.0, focus=(0, 0, 0), ss=ss)
            tile.putalpha(ImageChops.multiply(tile.getchannel('A'), rect_mask() if ortho else diamond_mask()))
            atlas.paste(tile, (i * cw, j * ch))
    fname = ortho_file(name) if ortho else f'{name}.png'
    atlas.save(out / fname, compress_level=6)
    meta = {'file': fname, 'variants': [cv.P, cv.P], 'cell': [cw, ch]}
    if ortho:
        meta['proj'] = 'ortho'
        meta['tile'] = [ORTHO_W, ORTHO_H]
    return meta


def contract():
    return {'tile_size': [sr.TILE_W, sr.TILE_H], 'atlas_cell': [CELL_W, CELL_H], 'variants': [P, P], 'overscan': OVERSCAN,
            'rule': 'atlas_coords = Vector2i(cell.x %% %d, cell.y %% %d)  (periodic: any neighbour matches)' % (P, P),
            'tile_edge_m': round(sr.TILE_M, 4), 'diamond_px': [128, 75.2],
            'ortho': {'tile_size': [ORTHO_W, ORTHO_H], 'atlas_cell': [OCELL_W, OCELL_H], 'camera': 'azimuth 0, elevation 36, rectangular mask',
                      'tile_edge_m': [round(ORTHO_TX, 4), round(ORTHO_TZ, 4)], 'files': 'ortho_<terrain id without _o>.png, tiles.json entries carry proj: ortho'},
            'ambient': {'forest': '4d5e85', 'cave': '343b5c', 'rule': 'ortho forest / cave terrains are baked as sketch colour / ambient (final = albedo x ambient)'}}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('  tools/art/produce_all.sh')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('names', nargs='*'); ap.add_argument('--all', action='store_true', help='every iso and ortho terrain')
    ap.add_argument('--iso', action='store_true', help='with --all: the diamond terrains only'); ap.add_argument('--ortho', action='store_true', help='with --all: the ortho terrains only')
    ap.add_argument('--out', default=None, help='default: <masters>/iso_tiles (tools/art/_stage/masters/iso_tiles)'); ap.add_argument('--ss', type=int, default=3)
    a = ap.parse_args()
    out = Path(a.out) if a.out else artpaths.masters_dir() / 'iso_tiles'
    out.mkdir(parents=True, exist_ok=True)
    meta_p = out / 'tiles.json'
    meta = json.loads(meta_p.read_text()) if meta_p.exists() else {}
    meta['_contract'] = contract()
    if a.names:
        names = a.names
    else:
        names = ([] if a.ortho and not a.iso else list(TERRAINS)) + ([] if a.iso and not a.ortho else list(ORTHO_TERRAINS))
    unknown = [n for n in names if n not in TERRAINS and n not in ORTHO_TERRAINS]
    if unknown:
        raise SystemExit(f'ERROR: unknown terrain {unknown}; known: {", ".join(list(TERRAINS) + list(ORTHO_TERRAINS))}')
    for n in names:
        t0 = time.time()
        ortho = n in ORTHO_TERRAINS
        cv = (ORTHO_TERRAINS if ortho else TERRAINS)[n]()
        meta[n] = bake_terrain(n, cv, out, a.ss, ortho)
        print(n, round(time.time() - t0, 1), flush=True)
    meta_p.write_text(json.dumps(dict(sorted(meta.items(), key=lambda kv: (kv[0] != '_contract', kv[0]))), indent=1))


if __name__ == '__main__':
    main()
