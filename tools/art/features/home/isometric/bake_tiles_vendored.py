# VENDORED, DO NOT EDIT (package A1-art-home): copy of tools/isometric/bake_tiles.py of the art spike, the file P22 lifts into tools/art/environment.
# A1 needs only its Canvas / pnoise / terrain_cobble / bake_terrain to paint the four interior floor atlases (bake_interior.py), and must not depend on
# P22 (wave 4).  The only two edits are marked VENDORING CHANGE below (import path, no default --out); re-vendor instead of editing.
#!/usr/bin/env python3
"""Isometric ground tiles, painted + rendered with the character camera/lights (VTK) so relief shades like the sprites.

Every terrain is a PERIODIC painted canvas of P x P tiles (default 4 x 4).  Tile (i, j) is the sub-square [i, i+1) x [j, j+1) of
that canvas, rendered as a heightfield from the 36-degree camera into a diamond.  Because the canvas wraps, tile (x mod P, y mod P) is
seamless against ANY neighbour (16 variants per terrain, zero authoring of edge rules).  Every tile is baked with a 3.5 % overscan so
neighbouring diamonds overlap by ~2 px (no hairline seams from texture filtering).

  python tools/isometric/bake_tiles.py --all --out assets/iso_tiles
Output: <terrain>.png atlas (P*CELL_W x P*CELL_H) + tiles.json
"""
from __future__ import annotations
import argparse, json, math, sys, time
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops
from scipy import ndimage
import homepaths  # noqa: F401  (VENDORING CHANGE 1 of 2: the spike put tools/characters + tools/isometric on sys.path by hand)
import static_render as sr

P = 4                   # periodic variants per axis
CELL_W, CELL_H = 144, 84    # atlas cell (diamond is 128 x 75-76, plus overscan and relief headroom)
RES = 256               # canvas pixels per tile
OVERSCAN = .06             # mesh margin (hides rim shading); the alpha mask below keeps only ~1.4 px of it


def hexrgb(c): return np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


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
# terrain recipes
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
    rng = np.random.default_rng(seed + 100)
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


TERRAINS = {
    'grass': lambda: terrain_grass('lush'), 'grass_flowers': lambda: terrain_grass('flowers'), 'grass_hyggebyen': lambda: terrain_grass('lush', 'hyggebyen'), 'grass_hyggebyen_flowers': lambda: terrain_grass('flowers', 'hyggebyen'), 'soil_tilled': lambda: terrain_soil(False),
    'soil_watered': lambda: terrain_soil(True), 'path_dirt': terrain_path, 'deck_farm': lambda: terrain_deck('farm'), 'deck_hyggebyen': lambda: terrain_deck('hyggebyen', 9),
    'cobble_hyggebyen': terrain_cobble, 'forest_floor': lambda: terrain_forest(False), 'forest_floor_glow': lambda: terrain_forest(True), 'void_haze': terrain_void,
}
for _f in range(4): TERRAINS[f'water_{_f}'] = (lambda f=_f: terrain_water(f))


# ----------------------------------------------------------------------------------------------------------------------
def tile_mesh(cv: Canvas, i, j, grid=40, amp=1.0):
    """Heightfield for tile (i,j) (indices into the periodic canvas), expanded by OVERSCAN, UV into the canvas (wraps)."""
    Pn = cv.P; T = sr.TILE_M; m = OVERSCAN
    u = np.linspace(-.5 - m, .5 + m, grid); v = np.linspace(-.5 - m, .5 + m, grid)
    U, V = np.meshgrid(u, v)                                   # U along +x, V along +z
    cu = (i + .5 + U) / Pn; cv_ = (j + .5 + V) / Pn             # canvas coords in tile units / P
    rows = (cv_ % 1.0) * cv.n; cols = (cu % 1.0) * cv.n
    H = ndimage.map_coordinates(cv.h, [rows, cols], order=1, mode='grid-wrap') * amp
    pos = np.stack([U * T, H, V * T], -1).reshape(-1, 3)
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
    dhdx = (hs(e * Pn, 0) - hs(-e * Pn, 0)) / (2 * e * Pn * T)
    dhdz = (hs(0, e * Pn) - hs(0, -e * Pn)) / (2 * e * Pn * T)
    n = np.stack([-dhdx, np.ones_like(dhdx), -dhdz], -1); n /= np.linalg.norm(n, axis=-1, keepdims=True)
    n = n.reshape(-1, 3)
    # winding: make face normals point up (+y)
    fn = np.cross(pos[faces[:, 1]] - pos[faces[:, 0]], pos[faces[:, 2]] - pos[faces[:, 0]])
    if fn[:, 1].mean() < 0: faces = faces[:, ::-1]
    return pos, n, uv, faces


_MASK = None


def diamond_mask(ov=1.4, ss=8):
    """Anti-aliased diamond (128 x 75.2 + ov px overscan) in a CELL_W x CELL_H image."""
    global _MASK
    if _MASK is None:
        k = math.sin(math.radians(sr.ELEV))
        hw, hh = 64 + ov, 64 * k + ov * k
        im = Image.new('L', (CELL_W * ss, CELL_H * ss), 0); cx, cy = CELL_W * ss / 2, CELL_H * ss / 2
        ImageDraw.Draw(im).polygon([(cx, cy - hh * ss), (cx + hw * ss, cy), (cx, cy + hh * ss), (cx - hw * ss, cy)], fill=255)
        _MASK = im.resize((CELL_W, CELL_H), Image.LANCZOS)
    return _MASK


def bake_terrain(name, cv: Canvas, out: Path, ss=3):
    img = cv.image()
    # mild sharpening keeps painted strokes crisp after the 3x supersample + downscale
    atlas = Image.new('RGBA', (cv.P * CELL_W, cv.P * CELL_H), (0, 0, 0, 0))
    first = None
    for j in range(cv.P):
        for i in range(cv.P):
            pos, n, uv, faces = tile_mesh(cv, i, j)
            r = sr.StaticRenderer(pos, n, uv, faces, img, repeat=True)
            tile = r.render(CELL_W, CELL_H, az=45.0, focus=(0, 0, 0), ss=ss)
            tile.putalpha(ImageChops.multiply(tile.getchannel('A'), diamond_mask()))
            atlas.paste(tile, (i * CELL_W, j * CELL_H))
    atlas.save(out / f'{name}.png', compress_level=6)
    return {'file': f'{name}.png', 'variants': [cv.P, cv.P], 'cell': [CELL_W, CELL_H]}


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('names', nargs='*'); ap.add_argument('--all', action='store_true')
    ap.add_argument('--out', required=True)   # VENDORING CHANGE 2 of 2: no default into assets/ (the spike's default was its own project)
    ap.add_argument('--ss', type=int, default=3)
    a = ap.parse_args(); out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    meta_p = out / 'tiles.json'; meta = json.loads(meta_p.read_text()) if meta_p.exists() else {}
    meta['_contract'] = {'tile_size': [sr.TILE_W, sr.TILE_H], 'atlas_cell': [CELL_W, CELL_H], 'variants': [P, P], 'overscan': OVERSCAN,
                         'rule': 'atlas_coords = Vector2i(cell.x %% %d, cell.y %% %d)  (periodic: any neighbour matches)' % (P, P),
                         'tile_edge_m': round(sr.TILE_M, 4), 'diamond_px': [128, 75.2]}
    for n in (list(TERRAINS) if a.all or not a.names else a.names):
        t0 = time.time(); cv = TERRAINS[n]()
        meta[n] = bake_terrain(n, cv, out, a.ss); meta[n]['seconds'] = round(time.time() - t0, 1)
        print(n, meta[n]['seconds'], flush=True)
    meta_p.write_text(json.dumps(meta, indent=1))


if __name__ == '__main__':
    main()
