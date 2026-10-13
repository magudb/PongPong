"""The 10 home tiers (Skur ... Slot), baked from the same geometry vocabulary as the farmhouse prop.

Anchor convention (identical for ALL tiers so a tier swap is an in-place texture swap):
    origin (0,0,0) = ground point at the centre of the DOOR, on the front plane z = 0.
    The building occupies z in [-D*T, 0] and x in [-(c+.5)*T, (W-c-.5)*T]  (W x D tiles, door in column c).
    Front = +z = screen left-down.  Porches / steps / eaves may overhang the front plane.
"""
from __future__ import annotations
import math
import numpy as np
from home_kit import HM, T, PAINTERS
import geometry as geo


class House:
    def __init__(self, tier, art_id, W, D, c, height, pm, notes=''):
        self.tier, self.art_id, self.W, self.D, self.c, self.height, self.pm, self.notes = tier, art_id, W, D, c, height, pm, notes

    @property
    def rect(self):          # tiles relative to the door anchor (xmin, zmin, xmax, zmax)
        return (-(self.c + .5), -float(self.D), self.W - self.c - .5, 0.0)


def _rect(W, D, c):
    return -(c + .5) * T, (W - c - .5) * T, -D * T, 0.0


FLOWERS = ('E58FA6', 'FBEAC8', 'B3436B', 'F2C14E', 'E58FA6', 'D9C8F4')


def flower_bed(pm, x0, x1, z, depth=.34, n=8, seed=1, soil='5E3F2A'):
    rng = np.random.default_rng(seed)
    pm.box(((x0 + x1) / 2, .09, z), (x1 - x0, .18, depth), soil, 'soil', power=.3)
    for i in range(n):
        x = x0 + (i + .5) / n * (x1 - x0) + rng.uniform(-.05, .05)
        zz = z + rng.uniform(-.08, .08)
        pm.ell((x, .26, zz), (.065, .07, .065), FLOWERS[i % len(FLOWERS)], 'soft', seg=10, rings=8)
        pm.ell((x, .17, zz), (.035, .08, .035), '5C9A52', 'soft', seg=8, rings=6)


def lantern(pm, x, y, z, col='FFD98A'):
    pm.cyl2((x, y + .35, z), (x, y + .12, z), .012, .012, '4A3A4D', 'soft', 6, 2)
    pm.emit_ell((x, y, z), (.075, .1, .075), col)
    pm.ell((x, y + .12, z), (.09, .025, .09), '4A3A4D', 'soft', seg=12, rings=6)
    pm.ell((x, y - .11, z), (.08, .02, .08), '4A3A4D', 'soft', seg=12, rings=6)


def barrel(pm, x, z, r=.24, h=.66, col='A47944'):
    pm.cyl2((x, 0, z), (x, h, z), r * .94, r * .94, col, 'plank_v', 16, 5)
    pm.ell((x, h * .5, z), (r * 1.02, h * .5, r * 1.02), col, 'plank_v', power=.7, seg=18, rings=10)
    for y in (.14, h - .14):
        pm.ell((x, y, z), (r * 1.04, .03, r * 1.04), '4A3A4D', 'soft', seg=18, rings=6)
    pm.ell((x, h + .01, z), (r * .9, .03, r * .9), '8C6B3F', 'plank_h', seg=16, rings=6)


def crate(pm, x, z, s=.42, col='C9A66B', rot=0):
    pm.box((x, s / 2, z), (s, s, s), col, 'plank_h', power=.3, rot=(0, rot, 0))
    pm.box((x, s / 2, z), (s * 1.02, .05, s * 1.02), '8C6B3F', 'plank_h', power=.3, rot=(0, rot, 0))


def chimney_brick(pm, x, z, y0, y1, w=.5, col='A8553B', cap='5B5468'):
    pm.box((x, (y0 + y1) / 2, z), (w, y1 - y0, w), col, 'brick', power=.25)
    pm.box((x, y1 + .05, z), (w + .12, .1, w + .12), cap, 'blocks', power=.3)
    pm.box((x, y1 + .14, z), (w * .62, .1, w * .62), '2B2340', 'soft', power=.3)


def stone_plinth(pm, x0, x1, z0, z1, h=.3, col='9A94A4', extra=.12):
    pm.box(((x0 + x1) / 2, h / 2, (z0 + z1) / 2), (x1 - x0 + extra * 2, h, z1 - z0 + extra * 2), col, 'blocks', power=.22)


# ---------------------------------------------------------------------------------------------------------------------------------
def tier1_skur() -> House:
    """skur - a lean-to tool shed of weathered boards under a patched roof.  2 x 2 tiles."""
    pm = HM(); W, D, c = 2, 2, 1
    x0, x1, z0, z1 = _rect(W, D, c); cx = (x0 + x1) / 2; cz = (z0 + z1) / 2
    hf, hb = 1.72, 2.25
    pm.box((cx, .12, cz), (x1 - x0 + .18, .24, z1 - z0 + .18), '8A8494', 'blocks', power=.3)          # mossy stone footing
    pm.box((cx, hf / 2 + .02, cz), (x1 - x0, hf, z1 - z0), '9C8665', 'plank_v', power=.2)             # front body (boards)
    pm.box((cx, (hb) / 2, z0 + .12), (x1 - x0, hb, .24), '8E7959', 'plank_v', power=.2)               # taller back wall
    for sx in (x0 + .02, x1 - .02):
        tri = geo.rounded_triangle([(z0 + .05 - cz, hf - .02), (z1 - .05 - cz, hf - .02), (z0 + .05 - cz, hb)], 4)       # side wedge under the sloped roof
        pm._gable_end(tri, sx, '8E7959', 'plank_v', 'x', cz)
    for k in range(4):                                                                              # battens
        pm.box((x0 + .35 + k * .45, hf / 2, z1 + .01), (.07, hf, .03), '6E5A41', 'wood', power=.3)
    slope = math.degrees(math.atan((hb - hf) / (z1 - z0))) + 1
    L = (z1 - z0 + .5) / math.cos(math.radians(slope)); y_mid = (hf + hb) / 2 + .14
    pm.box((cx, y_mid, cz), (x1 - x0 + .5, .10, L), '7A6652', 'shingle', power=.2, rot=(slope, 0, 0), pivot=(cx, y_mid, cz), L=2.6)
    pm.box((x0 + .55, y_mid + .17, z1 - .55), (.95, .05, .85), '7FB2C8', 'weave', power=.3, rot=(slope, 0, 0), pivot=(x0 + .55, y_mid + .17, z1 - .55))   # tarp patch
    pm.foliage((x1 - .35, y_mid + .20, z0 + .5), .24, ('7FA84F', 'A6CC6B', '5C8E3E'), 4, 3, .7)       # moss on the roof
    pm.cyl2((x0 + .38, hb + .1, z0 + .4), (x0 + .46, hb + 1.0, z0 + .45), .075, .07, '4A3A4D', 'soft', 10, 5)    # crooked stovepipe
    pm.ell((x0 + .46, hb + 1.05, z0 + .45), (.14, .04, .14), '4A3A4D', 'soft', seg=12, rings=6)
    pm.door('+z', (0.0, 0.0), w=.56, h=1.28, col='7A5A3C', frame='5E4730')
    pm.window('+x', (z0 + .62 + .9, 1.05, x1), w=.34, h=.34, frame='5E4730', shutters=None)
    barrel(pm, x0 + .3, .33, .22, .62)
    crate(pm, x1 + .05, .4, .36, rot=14)
    pm.box((.62, .04, .5), (.62, .08, .5), '9A94A4', 'blocks', power=.3)                              # doorstep
    pm.box((0, .04, .48), (.8, .08, .45), '9A94A4', 'blocks', power=.3)
    lantern(pm, .5, 1.45, .22)
    return House(1, 'skur', W, D, c, hb + 1.2, pm, 'lean-to, patched tarp, crooked stovepipe, barrel')


def log_wall(pm, x0, x1, z0, z1, rows, r, col, gap=.25, y0=.15, ends=True):
    """four log walls, corners overhanging; returns top y"""
    for k in range(rows):
        y = y0 + k * gap
        ov = .20 if k % 2 == 0 else .10
        pm.log((x0 - ov, y, z1 - r), (x1 + ov, y, z1 - r), r, r, col, 'bark2', 12, 2)               # front
        pm.log((x0 - ov, y, z0 + r), (x1 + ov, y, z0 + r), r, r, col, 'bark2', 12, 2)               # back
        ov2 = .10 if k % 2 == 0 else .20
        yy = y + gap / 2
        pm.log((x1 - r, yy, z0 - ov2), (x1 - r, yy, z1 + ov2), r, r, col, 'bark2', 12, 2)           # right (+x)
        pm.log((x0 + r, yy, z0 - ov2), (x0 + r, yy, z1 + ov2), r, r, col, 'bark2', 12, 2)           # left
    return y0 + rows * gap + gap / 2


def tier2_hytte() -> House:
    """hytte - a honey log cabin with a stone chimney, shingle roof and a little porch roof.  3 x 2."""
    pm = HM(); W, D, c = 3, 2, 1
    x0, x1, z0, z1 = _rect(W, D, c); cx = (x0 + x1) / 2; cz = (z0 + z1) / 2
    pm.box((cx, .12, cz), (x1 - x0 + .35, .24, z1 - z0 + .35), '8A8494', 'blocks', power=.3)
    pm.box((cx, 1.0, cz), (x1 - x0 - .2, 2.0, z1 - z0 - .2), '5E4730', 'soft', power=.2)                  # dark core behind the logs
    top = log_wall(pm, x0, x1, z0, z1, 8, .15, 'C08F55', .25, .35)
    # gable ends in vertical boards
    th = 30; rise = (z1 - z0) / 2 * math.tan(math.radians(th))
    roof_top = pm.gable(x0 - .02, x1 + .02, z0, z1, top - .02, th, 'x', .5, .13, '8A5A3A', 'shingle', 'B88A52', 'plank_v', rcol='6B4126', ridge_r=.10)
    # stone chimney on the +x gable end
    ch_top = roof_top + .2
    pm.box((x1 - .02, ch_top / 2, cz), (.66, ch_top, .66), 'A7A0B0', 'blocks', power=.22)
    pm.box((x1 - .02, ch_top + .06, cz), (.80, .12, .80), '8A8494', 'blocks', power=.3)
    pm.box((x1 - .02, ch_top + .15, cz), (.46, .1, .46), '2B2340', 'soft', power=.3)
    # door + porch
    pm.box((0, 1.0, z1 - .05), (.84, 1.9, .14), '5E4730', 'wood', power=.3)
    pm.door('+z', (0.0, 0.0), w=.62, h=1.42, col='7A4E2D', frame='5E3B22', arch=False)
    for sx in (-.62, .62): pm.log((sx, 0, .62), (sx, 1.95, .62), .075, .07, '8A5A3A', 'bark2', 10, 3)
    pm.box((0, 2.05, .3), (1.55, .1, .96), '8A5A3A', 'shingle', power=.2, rot=(-10, 0, 0), pivot=(0, 2.05, .3), L=1.6)
    pm.box((0, .05, .45), (1.3, .1, .95), '9A94A4', 'blocks', power=.3)
    lantern(pm, -.55, 1.65, .58)
    pm.window('+z', (-1.1, 1.18, z1), w=.46, h=.52, frame='5E3B22', shutters='6B9A3E')
    pm.window('+x', (-.55, 1.2, x1 + .05), w=.4, h=.5, frame='5E3B22', shutters='6B9A3E')
    # wood pile + flower pot
    for r_ in range(3):
        for k in range(4 - r_):
            pm.log((x0 - .3 + r_ * .13, .09 + r_ * .17, .45 + (k + r_ * .5) * .17 - .1), (x0 - .3 + r_ * .13 + .7, .09 + r_ * .17, .45 + (k + r_ * .5) * .17 - .1), .075, .075, 'D6B27A', 'bark2', 8, 2) if False else \
                pm.log((x0 + .5 + (k + r_ * .5) * .17, .09 + r_ * .15, .34), (x0 + .5 + (k + r_ * .5) * .17, .09 + r_ * .15, .34 + .5), .075, .075, 'D6B27A', 'bark2', 8, 2)
    pm.cyl2((1.2, 0, .5), (1.2, .22, .5), .13, .1, 'C97A52', 'soft', 12, 3)
    pm.foliage((1.2, .38, .5), .14, ('7FB04F', 'A6CC6B', '5C8E3E'), 3, 5)
    return House(2, 'hytte', W, D, c, roof_top + 1.4, pm, 'honey log cabin, stone chimney, porch roof, wood pile')


def tier3_straatag() -> House:
    """straatag - whitewashed cottage under a deep golden thatch with an eyebrow window.  4 x 3."""
    pm = HM(); W, D, c = 4, 3, 2
    x0, x1, z0, z1 = _rect(W, D, c); cx = (x0 + x1) / 2; cz = (z0 + z1) / 2
    h = 1.95
    stone_plinth(pm, x0, x1, z0, z1, .32)
    pm.box((cx, h / 2 + .1, cz), (x1 - x0, h, z1 - z0), 'F6EBCB', 'plaster', power=.2)
    for sx in (x0, x1):
        for sz in (z0 + .08, z1 - .08): pm.box((sx, h / 2 + .12, sz), (.14, h + .02, .14), '6B4A33', 'wood', power=.3)
    pm.box((cx, h + .02, z1 - .05), (x1 - x0, .14, .12), '6B4A33', 'wood', power=.3)
    pm.box((x1 - .05, h + .02, cz), (.12, .14, z1 - z0), '6B4A33', 'wood', power=.3)
    th = 47; over = .5
    top = pm.gable(x0, x1, z0, z1, h + .08, th, 'x', over, .34, 'D3AE5C', 'thatch', 'F6EBCB', 'plaster', rcol='B08A44', ridge_r=.22)
    half = (z1 - z0) / 2 + over; rise = half * math.tan(math.radians(th)); y0 = h + .08
    surf = lambda z: y0 + .30 + rise * (1 - (z - cz) / half)
    # eyebrow window in the thatch
    ex, ez = .95, z1 - .15
    pm.box((ex, surf(ez) + .02, ez + .08), (.62, .46, .12), 'F6EBCB', 'plaster', power=.3, rot=(-(90 - th) + 2, 0, 0)) if False else None
    pm.ell((ex, surf(ez - .1) + .22, ez - .05), (.52, .26, .36), 'D3AE5C', 'thatch', power=.8, seg=22, rings=12, rot=(-th * .45, 0, 0))
    pm.box((ex, surf(ez - .05) + .08, ez + .1), (.40, .30, .06), 'A9D3E0', 'glass', power=.3, rot=(-th * .6, 0, 0))
    pm.box((ex, surf(ez - .05) + .08, ez + .13), (.36, .26, .03), 'FFD98A', 'emitn', power=.3, rot=(-th * .6, 0, 0))
    chimney_brick(pm, x0 + .6, cz - .1, h + .5, top + .55, .52)
    pm.door('+z', (0.0, 0.0), w=.64, h=1.42, col='6B9A3E', frame='FBF5E6', arch=True, glow=True)
    pm.window('+z', (-1.15, 1.2, z1), w=.5, h=.54, frame='FBF5E6', shutters='9B86D6')
    pm.window('+z', (1.25, 1.2, z1), w=.5, h=.54, frame='FBF5E6', shutters='9B86D6')
    pm.window('+x', (-.9, 1.2, x1), w=.46, h=.54, frame='FBF5E6', shutters='9B86D6')
    pm.window('+x', (.3, 1.2, x1), w=.46, h=.54, frame='FBF5E6', shutters='9B86D6')
    pm.box((.0, .05, .5), (1.0, .1, .95), '9A94A4', 'blocks', power=.3)
    flower_bed(pm, x0 + .2, -.55, z1 + .18, .3, 6, 2); flower_bed(pm, .6, x1 - .15, z1 + .18, .3, 6, 3)
    flower_bed(pm, x1 + .17, x1 + .17, z0 + 1.2, .3, 1, 4) if False else None
    barrel(pm, x0 + .25, z1 - .75, .2, .6)
    lantern(pm, .5, 1.78, .2)
    for i, (px, pz) in enumerate([(x0 + .25, z1 + .28), (x1 - .2, z1 + .28)]):                            # climbing roses on the corners
        pm.foliage((px, 1.1, pz - .1), .2, ('6FAA46', '97C95E', '4F8A38'), 4, 5 + i, .9)
        for k in range(5): pm.ell((px + (k % 3 - 1) * .1, .8 + k * .14, pz + .02), (.05, .05, .05), 'E58FA6', 'soft', seg=8, rings=6)
    return House(3, 'straatag', W, D, c, top + 1.0, pm, 'deep golden thatch, eyebrow window, roses, brick chimney')


def timber_front(pm, x0, x1, y0, y1, z, step, col='4A3326', t=.09, diag=True, face='+z'):
    """half-timber frame on a +z face between x0..x1, y0..y1 at depth z (posts every `step`, rails top/mid/bottom, diagonal braces)"""
    n = max(1, int(round((x1 - x0) / step)))
    xs = np.linspace(x0, x1, n + 1)
    for x in xs: pm.box((x, (y0 + y1) / 2, z + .02), (t, y1 - y0, .08), col, 'wood', power=.3)
    for y in (y0, (y0 + y1) / 2, y1): pm.box(((x0 + x1) / 2, y, z + .02), (x1 - x0, t, .08), col, 'wood', power=.3)
    if diag:
        for i in range(n):
            xm = (xs[i] + xs[i + 1]) / 2; ln = math.hypot(xs[i + 1] - xs[i], (y1 - y0) / 2)
            ang = math.degrees(math.atan2((y1 - y0) / 2, xs[i + 1] - xs[i])) * (1 if i % 2 == 0 else -1)
            pm.box((xm, y0 + (y1 - y0) * .25, z + .03), (ln, t * .8, .07), col, 'wood', power=.3, rot=(0, 0, ang))


def timber_side(pm, z0, z1, y0, y1, x, step, col='4A3326', t=.09):
    n = max(1, int(round((z1 - z0) / step)))
    zs = np.linspace(z0, z1, n + 1)
    for z in zs: pm.box((x + .02, (y0 + y1) / 2, z), (.08, y1 - y0, t), col, 'wood', power=.3)
    for y in (y0, (y0 + y1) / 2, y1): pm.box((x + .02, y, (z0 + z1) / 2), (.08, t, z1 - z0), col, 'wood', power=.3)
    for i in range(n):
        zm = (zs[i] + zs[i + 1]) / 2; ln = math.hypot(zs[i + 1] - zs[i], (y1 - y0) / 2)
        ang = math.degrees(math.atan2((y1 - y0) / 2, zs[i + 1] - zs[i])) * (1 if i % 2 == 0 else -1)
        pm.box((x + .03, y0 + (y1 - y0) * .25, zm), (.07, t * .8, ln), col, 'wood', power=.3, rot=(-ang, 0, 0))


def tier4_bindingsvaerk() -> House:
    """bindingsvaerk - half-timbered house, red clay tiles, cross gable and a little porch.  5 x 3."""
    pm = HM(); W, D, c = 5, 3, 2
    x0, x1, z0, z1 = _rect(W, D, c); cx = (x0 + x1) / 2; cz = (z0 + z1) / 2
    h = 2.7; plaster = 'F6ECD2'; frame = '4A3326'
    stone_plinth(pm, x0, x1, z0, z1, .38, '9A94A4')
    pm.box((cx, h / 2 + .1, cz), (x1 - x0, h, z1 - z0), plaster, 'plaster', power=.2)
    timber_front(pm, x0 + .12, x1 - .12, .42, h + .05, z1, 1.05, frame)
    timber_side(pm, z0 + .12, z1 - .12, .42, h + .05, x1, 1.05, frame)
    for sx in (x0, x1):
        pm.box((sx, h / 2 + .1, z1 - .06), (.16, h + .1, .16), frame, 'wood', power=.3)
    th = 38; over = .42
    top = pm.gable(x0, x1, z0, z1, h + .1, th, 'x', over, .13, 'B8502F', 'rooftile', plaster, 'plaster', rcol='8C3A24', ridge_r=.10)
    # wall dormer (kvist) flush with the front wall over the right half
    gx0, gx1 = .55, 2.05; kh = .95
    pm.box(((gx0 + gx1) / 2, h + .1 + kh / 2, z1 - .45), (gx1 - gx0, kh, .9), plaster, 'plaster', power=.2)
    timber_front(pm, gx0 + .08, gx1 - .08, h + .16, h + .1 + kh - .04, z1 - .0, .75, frame, diag=False)
    ktop = pm.gable(gx0 - .05, gx1 + .05, z1 - 1.5, z1, h + .1 + kh, 38, 'z', .25, .13, 'B8502F', 'rooftile', plaster, 'plaster', rcol='8C3A24', ridge_r=.10, ends=True)
    pm.window('+z', (1.3, h + .1 + kh * .52, z1), w=.4, h=.46, frame='FBF5E6', shutters=None)
    chimney_brick(pm, x0 + .7, cz - .2, h + .6, top + .65, .55, 'A8553B')
    chimney_brick(pm, x1 - .8, cz - .5, h + .6, top + .45, .5, 'A8553B')
    # porch
    for sx in (-.62, .62): pm.box((sx, .95, z1 + .72), (.12, 1.9, .12), frame, 'wood', power=.3)
    pm.box((0, 2.0, z1 + .38), (1.5, .12, 1.0), frame, 'wood', power=.3)
    pm.gable(-.75, .75, z1 - .1, z1 + .85, 2.06, 32, 'z', .12, .1, 'B8502F', 'rooftile', plaster, 'plaster', rcol='8C3A24', cap=True, ridge_r=.07)
    pm.door('+z', (0.0, z1), w=.66, h=1.46, col='5E8F44', frame='FBF5E6', glow=True)
    pm.box((0, .05, .8), (1.3, .1, .8), '9A94A4', 'blocks', power=.3)
    # windows
    for wx in (-1.9, -.95, 1.0, 2.0): pm.window('+z', (wx, 1.45, z1), w=.46, h=.58, frame='FBF5E6', shutters='B8502F' if wx > 0 else '5E8F44')
    for wz in (-2.3, -1.2, -.15): pm.window('+x', (wz - .2, 1.45, x1), w=.46, h=.58, frame='FBF5E6', shutters='B8502F')
    flower_bed(pm, x0 + .2, -1.4, z1 + .2, .3, 5, 6); flower_bed(pm, 2.15, x1 - .1, z1 + .2, .3, 4, 7)
    lantern(pm, -.5, 1.72, z1 + .65)
    barrel(pm, x0 + .2, z1 + .45, .2, .58)
    return House(4, 'bindingsvaerk', W, D, c, ktop + 1.0, pm, 'timber frame, clay tiles, cross gable, porch')


def tier5_gaarden() -> House:
    """gaarden - a yellow two-storey farmhouse with a dormer row, porch and a barn wing.  5 x 4."""
    pm = HM(); W, D, c = 5, 4, 2
    x0, x1, z0, z1 = _rect(W, D, c); cx = (x0 + x1) / 2; cz = (z0 + z1) / 2
    yel = 'EBC96E'; white = 'FBF5E6'; roof = 'A94A32'
    mx1 = 1.0                                                                                       # main block [x0, mx1], barn [mx1, x1]
    stone_plinth(pm, x0, x1, z0, z1, .42, '9A94A4', .1)
    hm = 4.3
    pm.box(((x0 + mx1) / 2, hm / 2 + .1, cz), (mx1 - x0, hm, z1 - z0), yel, 'plaster', power=.2)
    pm.box(((x0 + mx1) / 2, 2.35, z1 + .01), (mx1 - x0 + .06, .12, .06), white, 'soft', power=.3)
    for sx in (x0, mx1): pm.box((sx, hm / 2 + .1, z1 - .02), (.2, hm, .2), white, 'plaster', power=.3)
    top = pm.gable(x0, mx1, z0, z1, hm + .1, 35, 'x', .42, .13, roof, 'rooftile', yel, 'plaster', rcol='7A3220', ridge_r=.10)
    half = (z1 - z0) / 2 + .42; y0 = hm + .1; rise = half * math.tan(math.radians(35)); surf = lambda z: y0 + .12 + rise * (1 - (z - cz) / half)
    for dx in (-1.55, -.35):                                                                         # roof dormers
        zz = z1 - .55
        pm.box((dx, surf(zz) + .42, zz + .12), (.72, .78, .5), yel, 'plaster', power=.25)
        pm.gable(dx - .36, dx + .36, zz - .15, zz + .38, surf(zz) + .72, 36, 'z', .12, .08, roof, 'rooftile', yel, 'plaster', cap=False)
        pm.window('+z', (dx, surf(zz) + .44, zz + .32), w=.36, h=.42, frame=white, sill=False)
    chimney_brick(pm, x0 + .55, cz - .4, hm + .5, top + .55, .56, 'A8553B')
    chimney_brick(pm, mx1 - .6, cz - .4, hm + .5, top + .55, .56, 'A8553B')
    pm.door('+z', (0.0, 0.0), w=.7, h=1.5, col='5E8F44', frame=white, glow=True)
    for wx in (-1.9, -1.2): pm.window('+z', (wx, 1.4, z1), w=.5, h=.66, frame=white, shutters='5E8F44')
    for wx in (-1.9, -1.2, -.5, .25): pm.window('+z', (wx, 3.4, z1), w=.46, h=.62, frame=white, shutters='B8502F')
    # porch on two posts
    for sx in (-.78, .78): pm.box((sx, 1.05, .85), (.13, 2.1, .13), white, 'plaster', power=.3)
    pm.box((0, 2.12, .45), (1.8, .12, 1.0), white, 'plaster', power=.3)
    pm.box((0, 2.32, .45), (1.9, .12, 1.1), roof, 'rooftile', power=.25, rot=(-12, 0, 0), pivot=(0, 2.3, .45), L=1.6)
    pm.box((0, .07, .65), (1.8, .14, 1.15), '9A94A4', 'blocks', power=.3)
    lantern(pm, .62, 1.78, .78)
    # barn wing (right, nearer the camera): lower, red-brown boards, big doors, hayloft
    bx0, bx1 = mx1 + .02, x1; bh = 2.8; bw = bx1 - bx0; bcx = (bx0 + bx1) / 2
    pm.box((bcx, bh / 2 + .1, cz), (bw, bh, z1 - z0), 'B0613F', 'plank_v', power=.2)
    pm.gable(bx0, bx1, z0, z1, bh + .1, 30, 'x', .3, .12, '7A5A44', 'shingle', 'B0613F', 'plank_v', rcol='5E4730', ridge_r=.09)
    pm.box((bcx, 1.0, z1 + .04), (bw * .8, 1.8, .08), '8C4A33', 'plank_v', power=.2)
    pm.box((bcx, 1.0, z1 + .09), (.06, 1.7, .05), '5E4730', 'wood', power=.3)
    for sgn in (-1, 1): pm.box((bcx + sgn * bw * .2, 1.0, z1 + .1), (bw * .36, .06, .05), '5E4730', 'wood', power=.3, rot=(0, 0, sgn * 38))
    pm.box((bcx, 2.45, z1 + .05), (bw * .4, .55, .08), '5E4730', 'plank_v', power=.25)
    pm.window('+x', (-1.7, 2.0, x1), w=.4, h=.5, frame='5E4730', shutters=None)
    pm.window('+x', (-.3, 1.5, x1), w=.4, h=.5, frame='5E4730', shutters=None)
    for k in range(3): pm.box((x1 + .1 + k * .02, .22 + k * .42 - (0 if k < 2 else .0), z1 - .6 + (k > 1) * -.2), (.7, .4, .42), 'E3C372', 'straw', power=.3, rot=(0, 8 * k, 0)) if k < 2 else pm.box((x1 + .1, .84 + .0, z1 - .75), (.7, .4, .42), 'E3C372', 'straw', power=.3, rot=(0, 10, 0))
    pm.cyl2((cx - 1.2, top, cz), (cx - 1.2, top + .7, cz), .02, .02, '4A3A4D', 'soft', 6, 2)
    pm.ell((cx - 1.2, top + .75, cz), (.18, .12, .04), 'E3C372', 'gold', seg=10, rings=8)
    flower_bed(pm, x0 + .15, -1.0, z1 + .2, .3, 4, 9)
    return House(5, 'gaarden', W, D, c, top + 1.0, pm, 'yellow two-storey farmhouse, dormers, porch, barn wing')


# =================================================================================================================================
def ivy(pm, pts, r=.16, seed=1, cols=('6FAA46', '97C95E', '4F8A38'), blossom=None):
    rng = np.random.default_rng(seed)
    for i, (x, y, z) in enumerate(pts):
        pm.foliage((x, y, z), r * rng.uniform(.8, 1.2), cols, 3, seed * 13 + i, .85)
        if blossom and rng.random() < .5:
            pm.ell((x + rng.uniform(-.1, .1), y + rng.uniform(-.1, .1), z + .12), (.05, .05, .05), blossom, 'soft', seg=8, rings=6)


def arch_slit(pm, x, y, z, face='+z', h=.46, w=.17, light='FFD98A'):
    """arched slit window bubble on a cylinder/wall surface at (x,y,z) facing +z or +x"""
    if face == '+z':
        pm.ell((x, y, z), (w, h / 2, .05), '3B3552', 'glass', power=.8, seg=14, rings=10)
        pm.ell((x, y, z + .035), (w * .78, h / 2 * .84, .03), light, 'emitn', power=.8, seg=14, rings=10)
    else:
        pm.ell((x, y, z), (.05, h / 2, w), '3B3552', 'glass', power=.8, seg=14, rings=10)
        pm.ell((x + .035, y, z), (.03, h / 2 * .84, w * .78), light, 'emitn', power=.8, seg=14, rings=10)


def round_tower(pm, c, r, h, col='C4BDCB', tex='blocks', roof_col='7A6FB8', roof_tex='rooftile', roof_h=2.6, bands=(.5,), windows=(.3, .56, .8), band_col=None,
                finial='gold', flag=None, battlement=False, dome=False, wnd_angles=(35, -35, 70)):
    cx, cz = c
    pm.cyl2((cx, 0, cz), (cx, h, cz), r, r * .98, col, tex, 28, 5)
    pm.ell((cx, .14, cz), (r * 1.08, .16, r * 1.08), '9A94A4', 'blocks', seg=28, rings=6)
    for b in bands: pm.ell((cx, h * b, cz), (r * 1.04, .06, r * 1.04), band_col or 'F6EBD3', 'soft', seg=28, rings=6)
    for i, wy in enumerate(windows):
        a = math.radians(wnd_angles[i % len(wnd_angles)] * (1 if i % 2 == 0 else -1) * .55 + 18)
        arch_slit(pm, cx + math.sin(a) * r * .985, h * wy, cz + math.cos(a) * r * .985, '+z' if math.cos(a) > .7 else '+x', h=.44)
    top = h
    if battlement:
        pm.ell((cx, h - .02, cz), (r * 1.14, .1, r * 1.14), col, 'blocks', seg=28, rings=6)
        for k in range(12):
            a = k * 2 * math.pi / 12
            pm.box((cx + math.cos(a) * r * 1.0, h + .17, cz + math.sin(a) * r * 1.0), (.28, .3, .24), col, 'blocks', power=.24, rot=(0, -math.degrees(a), 0))
        top = h + .35
    if dome:
        pm.ell((cx, h + .02, cz), (r * 1.1, .06, r * 1.1), 'E3C372', 'gold', seg=28, rings=6)
        prof = [(0, .96), (.12, 1.08), (.32, 1.0), (.5, .74), (.66, .42), (.8, .2), (.92, .09), (1.0, .01)]
        pm.lathe(cx, cz, [(y * roof_h * .95, rr * r) for y, rr in prof], roof_col, 'gold', 28, y0=h)
        pm.cyl2((cx, h + roof_h * .9, cz), (cx, h + roof_h * 1.2, cz), .035, .015, 'E3C372', 'gold', 8, 3)
        pm.ell((cx, h + roof_h * 1.22, cz), (.06, .06, .06), 'E3C372', 'gold')
        top = h + roof_h * 1.3
    elif roof_h:
        pm.cone((cx, cz), r * 1.2, roof_h, roof_col, roof_tex, y=h - .02, tip=.025, rim_col='F6EBD3')
        pm.ell((cx, h + roof_h + .02, cz), (.08, .08, .08), 'E3C372', 'gold')
        top = h + roof_h + .1
        if flag: pm.flag(cx, top, cz, 1.0, flag, length=.6)
    return top


def tier6_tarnhus() -> House:
    """taarnhus - stone-and-timber manor house with a round stair tower, a balcony over the portal and a slate roof.  6 x 4."""
    pm = HM(); W, D, c = 6, 4, 3
    x0, x1, z0, z1 = _rect(W, D, c); cx = (x0 + x1) / 2; cz = (z0 + z1) / 2
    bx0 = -1.95
    stone = 'BDB6C6'; plaster = 'F6EBD3'; frame = '5A3B26'
    pm.box(((bx0 + x1) / 2, .17, cz), (x1 - bx0 + .3, .34, z1 - z0 + .3), '9A94A4', 'blocks', power=.22)
    pm.box(((bx0 + x1) / 2, 1.5, cz), (x1 - bx0, 2.5, z1 - z0), stone, 'blocks', power=.18)            # stone ground floor
    pm.box(((bx0 + x1) / 2, 2.62, z1 + .0), (x1 - bx0 + .12, .16, .16), frame, 'wood', power=.3)
    pm.box(((bx0 + x1) / 2, 3.78, cz), (x1 - bx0, 2.3, z1 - z0), plaster, 'plaster', power=.18)          # plastered upper floor
    timber_front(pm, bx0 + .12, x1 - .12, 2.72, 4.88, z1, 1.05, frame, diag=False)
    timber_side(pm, z0 + .12, z1 - .12, 2.72, 4.88, x1, 1.05, frame)
    th = 40; over = .45
    top = pm.gable(bx0, x1, z0, z1, 4.95, th, 'x', over, .13, '5F6C8E', 'slate', plaster, 'plaster', rcol='3E4866', ridge_r=.11)
    half = (z1 - z0) / 2 + over; rise = half * math.tan(math.radians(th)); y0 = 4.95; cz_ = cz
    surf = lambda z: y0 + .13 + rise * (1 - (z - cz_) / half)
    for dx in (.7, 1.9):                                                                            # arched roof dormers
        zz = z1 - .5
        pm.box((dx, surf(zz) + .4, zz + .1), (.7, .75, .5), plaster, 'plaster', power=.25)
        pm.gable(dx - .36, dx + .36, zz - .15, zz + .36, surf(zz) + .7, 38, 'z', .12, .08, '5F6C8E', 'slate', plaster, 'plaster', cap=False)
        pm.window('+z', (dx, surf(zz) + .42, zz + .3), w=.34, h=.4, frame='FBF5E6', sill=False)
    chimney_brick(pm, x1 - .7, cz - .6, 5.2, top + .6, .6, 'A8553B')
    chimney_brick(pm, bx0 + 1.5, cz - .3, 5.2, top + .5, .55, 'A8553B')
    # stone portal + door, balcony above
    for sx in (-.52, .52): pm.box((sx, .95, z1 + .06), (.18, 1.9, .26), 'D8D2DE', 'blocks', power=.25)
    pm.ell((0, 1.78, z1 + .06), (.62, .34, .13), 'D8D2DE', 'blocks', power=.8)
    pm.door('+z', (0.0, 0.0), w=.8, h=1.62, col='3F6B4E', frame='D8D2DE', arch=True, glow=True)
    pm.box((0, .05, .55), (1.6, .1, 1.0), '9A94A4', 'blocks', power=.3); pm.box((0, .13, .3), (1.3, .1, .6), '9A94A4', 'blocks', power=.3)
    pm.box((0, 2.88, .5), (1.9, .12, 1.0), '8B6A44', 'wood', power=.3)                                       # balcony floor
    for sx in (-.86, .86): pm.box((sx, 2.5, .93), (.1, .8, .1), frame, 'wood', power=.3)
    for k in range(8): pm.box((-.82 + k * .235, 3.3, .98), (.05, .6, .05), frame, 'wood', power=.3)
    pm.box((0, 3.62, .98), (1.9, .07, .09), frame, 'wood', power=.3)
    for sx in (-.95, .95): pm.box((sx, 3.3, .5), (.05, .6, .05), frame, 'wood', power=.3)
    pm.box((.0, 3.62, .5), (.09, .07, 1.0), frame, 'wood', power=.3) if False else None
    pm.window('+z', (0, 3.85, z1), w=.66, h=1.15, frame='FBF5E6', shutters=None, mull=True)
    for wx in (-.1 + 1.3, 2.05): pm.window('+z', (wx, 1.55, z1), w=.46, h=.62, frame='F6EBD3', shutters=None)
    pm.window('+z', (-.85 + -.0, 1.55, z1), w=.46, h=.62, frame='F6EBD3', shutters=None) if False else None
    for wx in (1.35, 2.15): pm.window('+z', (wx, 3.85, z1), w=.46, h=.62, frame='FBF5E6', shutters='3F6B4E')
    pm.window('+z', (-1.2, 3.85, z1), w=.46, h=.62, frame='FBF5E6', shutters='3F6B4E')
    for wz in (-3.0, -1.8, -.6): pm.window('+x', (wz, 1.55, x1), w=.46, h=.62, frame='F6EBD3'); pm.window('+x', (wz, 3.85, x1), w=.46, h=.62, frame='FBF5E6', shutters='3F6B4E')
    # round tower at the left-front corner
    tcx, tcz, tr = -2.82, z1 - .8, .82
    ttop = round_tower(pm, (tcx, tcz), tr, 6.2, 'C9C2D2', 'blocks', '7A6FB8', 'rooftile', 3.0, bands=(.42, .86), windows=(.2, .46, .7), flag='6B9A3E')
    ivy(pm, [(tcx + tr * .78, .5 + k * .62, tcz + tr * .62 + .03) for k in range(6)] + [(tcx + tr * 1.0, .7 + k * .75, tcz + tr * .1) for k in range(5)], .17, 3, blossom='E58FA6')
    flower_bed(pm, x1 - 1.2, x1 - .1, z1 + .2, .3, 4, 11); flower_bed(pm, -1.7, -.75, z1 + .2, .3, 3, 12)
    lantern(pm, .7, 1.95, .25); lantern(pm, -.7, 1.95, .25)
    return House(6, 'taarnhus', W, D, c, ttop + 1.1, pm, 'stone+timber manor, round stair tower, balcony, slate roof')


def tier7_landsted() -> House:
    """landsted - a symmetrical white country house: 4-column portico with a pediment, mansard roof, balustrade, urns.  7 x 4."""
    pm = HM(); W, D, c = 7, 4, 3
    x0, x1, z0, z1 = _rect(W, D, c); cx = 0.0; cz = (z0 + z1) / 2
    white = 'FBF5E6'; blue = 'A9D3E0'; stone = 'D8D2DE'
    pm.box((cx, .2, cz), (x1 - x0 + .36, .4, z1 - z0 + .36), '9A94A4', 'blocks', power=.22)
    h = 4.6
    pm.box((cx, h / 2 + .3, cz), (x1 - x0 - .1, h, z1 - z0 - .1), white, 'plaster', power=.16)             # main block
    for k in (-1, 1): pm.box((k * (x1 - .35), h / 2 + .3, z1 - .02), (.5, h, .12), blue, 'painted', power=.2)  # painted corner pilasters
    pm.box((cx, 2.66, z1 + .0), (x1 - x0 + .0, .14, .1), blue, 'painted', power=.3)                          # storey band
    pm.box((cx, h + .32, z1 + .02), (x1 - x0 + .1, .16, .22), stone, 'soft', power=.3)                       # cornice
    pm.box((x1 + .01, h + .32, cz), (.22, .16, z1 - z0 + .1), stone, 'soft', power=.3)
    # mansard roof: steep lower frustum + shallow hip, dormers
    ra = (x0 - .25, x1 + .25, z0 - .25, z1 + .25); rb = (x0 + .95, x1 - .95, z0 + .95, z1 - .95)
    y_a = h + .4; y_b = y_a + 1.25
    pm.frustum(ra, y_a, rb, y_b, .13, '55607E', 'slate', 2.2)
    top = pm.hip(rb[0] + .02, rb[1] - .02, rb[2] + .02, rb[3] - .02, y_b - .03, .55, .1, .12, '4A5470', 'slate', 2.2)
    for dx in (-2.5, -1.2 + 2.4 * 0, 1.2, 2.5):
        if abs(dx) < 1.0: continue
        zf = z1 + .25 - .5 * 1.0
        pm.box((dx, y_a + .62, zf + .22), (.62, .78, .42), white, 'plaster', power=.25)
        pm.gable(dx - .33, dx + .33, zf - .3, zf + .45, y_a + .98, 36, 'z', .1, .08, '4A5470', 'slate', white, 'plaster', cap=False)
        pm.window('+z', (dx, y_a + .62, zf + .4), w=.34, h=.5, frame=blue, sill=False)
    for sx in (-2.2, 2.2): chimney_brick(pm, sx, cz - .5, y_b - .3, y_b + .8, .6, 'B8704F')
    # portico: stairs, 4 columns, pediment
    for k, (sw, sz_) in enumerate([(2.5, 1.45), (2.2, 1.15), (1.9, .85)]): pm.box((0, .09 + k * .16, z1 + sz_ * .5), (sw + .2, .18 + k * .0, sz_), stone, 'blocks', power=.3) if False else pm.box((0, .45 + k * .0, 0), (0, 0, 0), stone, 'blocks') if False else None
    for k in range(3): pm.box((0, .1 + k * .17, z1 + .5 + (2 - k) * .28 + .0), (2.4 - k * .05, .17, 1.0 + (2 - k) * .26 - .2 + .0), stone, 'blocks', power=.28)
    pm.box((0, .62, z1 + .38), (2.4, .1, 1.1), stone, 'blocks', power=.28)
    for sx in (-1.0, -.33, .33, 1.0):
        pm.cyl2((sx, .62, z1 + .78), (sx, 3.45, z1 + .78), .15, .13, white, 'marble', 20, 4)
        pm.ell((sx, .66, z1 + .78), (.2, .06, .2), white, 'marble', seg=18, rings=6); pm.ell((sx, 3.5, z1 + .78), (.2, .08, .2), white, 'marble', seg=18, rings=6)
    pm.box((0, 3.62, z1 + .38), (2.5, .28, 1.2), white, 'marble', power=.25)
    ped = geo.rounded_triangle([(-1.35, 3.72), (1.35, 3.72), (0, 4.55)], 5)
    v, f = geo.pillow(np.asarray(ped, float), z1 + .98, .09, 1.0); pm._add(v, f, white, 'marble@2.8')
    ped2 = geo.rounded_triangle([(-1.05, 3.84), (1.05, 3.84), (0, 4.36)], 5)
    v, f = geo.pillow(np.asarray(ped2, float), z1 + 1.04, .06, 1.0); pm._add(v, f, 'A9D3E0', 'painted@2.4')
    pm.ell((0, 4.02, z1 + 1.13), (.2, .2, .03), 'E3C372', 'gold', seg=14, rings=10)
    pm.door('+z', (0.0, z1 - .05), w=.95, h=1.95, col='5E8F9A', frame=white, arch=True, glow=True, double=True)
    for sx in (-1.45, 1.45):
        pm.cyl2((sx, .62, z1 + 1.0), (sx, 1.0, z1 + 1.0), .17, .13, 'C97A52', 'soft', 14, 3)                  # urns with flowers
        pm.foliage((sx, 1.15, z1 + 1.0), .24, ('6FAA46', '97C95E', '4F8A38'), 4, 6)
        for k in range(5): pm.ell((sx + (k - 2) * .09, 1.25 + (k % 2) * .08, z1 + 1.08), (.06, .06, .06), 'E58FA6', 'soft', seg=8, rings=6)
    # windows: two floors, tall French windows below
    for wx in (-3.0, -2.15, -1.7, 1.7, 2.15, 3.0)[::1]:
        if abs(wx) in (1.7, 2.15) and False: continue
    for wx in (-3.0, -2.0, 2.0, 3.0): pm.window('+z', (wx, 1.8, z1), w=.55, h=1.2, frame=white, shutters=blue, ftex='painted')
    for wx in (-3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0): pm.window('+z', (wx, 3.7, z1), w=.5, h=.82, frame=white, shutters=blue, ftex='painted') if abs(wx) > 1.2 else None
    for wz in (-3.4, -2.4, -1.4, -.4): pm.window('+x', (wz, 1.8, x1), w=.55, h=1.2, frame=white, shutters=blue, ftex='painted'); pm.window('+x', (wz, 3.7, x1), w=.5, h=.82, frame=white, shutters=blue, ftex='painted')
    # balustrade along the cornice with urns
    for xx in np.arange(x0 + .3, x1 - .2, .4):
        if abs(xx) < 1.5: continue
        pm.ell((xx, h + .85, z1 + .05), (.07, .2, .07), white, 'marble', seg=10, rings=8)
    pm.box(((x0 + -1.6) / 2 - .0, h + 1.12, z1 + .05), (abs(-1.6 - x0) - .1, .08, .12), white, 'marble', power=.3) if False else None
    for sx in (-2.7, 2.7): pm.ell((sx, h + 1.15, z1 + .05), (.16, .2, .16), 'E3C372', 'gold', seg=12, rings=8)
    lantern(pm, -1.25, 2.1, z1 + .38); lantern(pm, 1.25, 2.1, z1 + .38)
    for sx in (-3.2, 3.2): ivy(pm, [(sx, .6 + k * .5, z1 + .08) for k in range(4)], .16, 20 + int(sx), blossom='E58FA6')
    # belvedere tower + cupola on the mansard hip (A1 re-bake, RV-A9 stretch goal): the roofline of tier 7 now stands above the tower of tier 6 instead of dipping below it
    tb = 1.8                                                                                              # square belvedere tower under the cupola: white plaster, blue corner posts, a window on each visible face
    pm.box((0, top + tb / 2 - .06, cz), (1.5, tb + .1, 1.5), white, 'plaster', power=.16)
    for ax in (-1, 1):
        for az_ in (-1, 1): pm.box((ax * .75, top + tb / 2 - .06, cz + az_ * .75), (.14, tb + .1, .14), blue, 'painted', power=.25)
    pm.window('+z', (0, top + tb * .55, cz + .75), w=.44, h=.7, frame=white, arch=True, sill=True)
    pm.window('+x', (cz, top + tb * .55, .75), w=.44, h=.7, frame=white, arch=True, sill=True)
    pm.box((0, top + tb - .02, cz), (1.74, .1, 1.74), stone, 'soft', power=.25)                           # cornice of the tower
    cy0 = top + tb - .04
    pm.ell((0, cy0 + .05, cz), (.76, .1, .76), stone, 'soft', seg=22, rings=6)
    pm.cyl2((0, cy0, cz), (0, cy0 + .98, cz), .62, .6, white, 'plaster', 22, 3)
    for ang in range(0, 360, 90):
        a = math.radians(ang); pm.box((math.sin(a) * .6, cy0 + .5, cz + math.cos(a) * .6), (.1, .98, .1), blue, 'painted', power=.3)   # corner posts of the drum
    pm.window('+z', (0, cy0 + .5, cz + .56), w=.3, h=.5, frame=white, arch=True, shutters=None, sill=False)
    pm.window('+x', (cz, cy0 + .5, .56), w=.3, h=.5, frame=white, arch=True, shutters=None, sill=False)
    pm.ell((0, cy0 + 1.02, cz), (.74, .09, .74), stone, 'soft', seg=22, rings=6)
    pm.lathe(0, cz, [(0, .68), (.08, .72), (.38, .62), (.68, .4), (.88, .18), (1.0, .0)], '6FB5A0', 'copper', 22, y0=cy0 + 1.06, scale=1.0)
    pm.ell((0, cy0 + 2.1, cz), (.07, .09, .07), 'E3C372', 'gold', seg=10, rings=8)
    pm.flag(0, cy0 + 2.14, cz, 0.75, '6B9A3E', length=.6)
    return House(7, 'landsted', W, D, c, top + 1.0, pm, 'white villa, pedimented portico, mansard roof, urns')


def clock_face(pm, x, y, z, face='+z', r=.5):
    if face == '+z':
        pm.ell((x, y, z), (r * 1.12, r * 1.12, .04), 'E3C372', 'gold', seg=22, rings=10)
        pm.ell((x, y, z + .03), (r, r, .03), 'FBF5E6', 'soft', seg=22, rings=10)
        pm.box((x, y + r * .25, z + .06), (.045, r * .55, .02), '2B2340', 'soft', power=.3)
        pm.box((x + r * .2, y + .0, z + .06), (r * .42, .045, .02), '2B2340', 'soft', power=.3, rot=(0, 0, 25))
        for k in range(12):
            a = k * math.pi / 6
            pm.ell((x + math.sin(a) * r * .84, y + math.cos(a) * r * .84, z + .055), (.025, .025, .01), '2B2340', 'soft', seg=8, rings=6)
    else:
        pm.ell((x, y, z), (.04, r * 1.12, r * 1.12), 'E3C372', 'gold', seg=22, rings=10)
        pm.ell((x + .03, y, z), (.03, r, r), 'FBF5E6', 'soft', seg=22, rings=10)
        pm.box((x + .06, y + r * .25, z), (.02, r * .55, .045), '2B2340', 'soft', power=.3)
        pm.box((x + .06, y, z + r * .2), (.02, .045, r * .42), '2B2340', 'soft', power=.3, rot=(25, 0, 0))
        for k in range(12):
            a = k * math.pi / 6
            pm.ell((x + .055, y + math.cos(a) * r * .84, z + math.sin(a) * r * .84), (.01, .025, .025), '2B2340', 'soft', seg=8, rings=6)


def urn(pm, x, z, y=0.0, col='D8D2DE', plant=True):
    pm.cyl2((x, y, z), (x, y + .42, z), .17, .12, col, 'marble', 14, 3)
    pm.ell((x, y + .45, z), (.2, .05, .2), col, 'marble', seg=14, rings=6)
    if plant:
        pm.foliage((x, y + .62, z), .22, ('6FAA46', '97C95E', '4F8A38'), 4, 8)
        for k in range(5): pm.ell((x + (k - 2) * .08, y + .72 + (k % 2) * .06, z + .1), (.055, .055, .055), 'E58FA6', 'soft', seg=8, rings=6)


def steps(pm, cx, zfront, width, n=3, rise=.17, run=.34, col='D8D2DE', y0=0.0):
    for k in range(n):
        pm.box((cx, y0 + rise * (k + .5), zfront - (n - 1 - k) * run * .0 + (n - 1 - k) * run + .0), (width - k * .06, rise, run * (k + 1) + .3 - 0), col, 'blocks', power=.28) if False else None
    for k in range(n):
        d = (n - k) * run
        pm.box((cx, y0 + rise * (k + .5), zfront + d / 2 - .0), (width - k * .04, rise, d + .0), col, 'blocks', power=.28)


def tier8_herregard() -> House:
    """herregaard - red-brick manor: copper-green roofs, corner pavilions and a clock tower over the entrance.  7 x 5."""
    pm = HM(); W, D, c = 7, 5, 3
    x0, x1, z0, z1 = _rect(W, D, c); cz = (z0 + z1) / 2
    brick = 'B5694A'; white = 'FBF5E6'; cop = '6FB5A0'; copd = '4F9684'
    hb = 4.8
    stone_plinth(pm, x0, x1, z0, z1, .42, '9A94A4', .12)
    zf = -1.1                                                                                        # main block front plane (pavilions project to z1)
    pm.box((0, hb / 2 + .15, (z0 + zf) / 2), (x1 - x0, hb, zf - z0), brick, 'brick', power=.16)
    pm.box((0, 2.75, zf + .02), (x1 - x0 + .04, .13, .08), white, 'soft', power=.3)
    pm.box((0, hb + .18, zf + .04), (x1 - x0 + .08, .16, .2), white, 'soft', power=.3)
    ytop = pm.hip(x0, x1, z0, zf, hb + .2, 1.5, .35, .13, cop, 'copper', 3.0)
    for sx in (-2.2, 2.2): chimney_brick(pm, sx, cz - 1.0, hb + 1.0, hb + 2.4, .6, 'A8553B')
    # corner pavilions
    for sgn in (-1, 1):
        px0, px1 = (x0, x0 + 1.35) if sgn < 0 else (x1 - 1.35, x1); pcx = (px0 + px1) / 2; zp = -.45
        pm.box((pcx, (hb + .9) / 2 + .15, (z0 + 1.2 + zp) / 2), (px1 - px0, hb + .9, zp - z0 - 1.2), brick, 'brick', power=.16)
        for qx in (px0, px1): pm.box((qx, (hb + .9) / 2 + .15, zp), (.2, hb + .9, .2), white, 'plaster', power=.3)
        pm.box((pcx, hb + 1.08, zp + .02), (px1 - px0 + .1, .14, .22), white, 'soft', power=.3)
        pm.hip(px0, px1, zp - 2.2, zp, hb + 1.1, 1.7, .3, .13, copd, 'copper', 2.2)
        pm.ell((pcx, hb + 2.95, (zp - 2.2 + zp) / 2), (.07, .07, .07), 'E3C372', 'gold')
        for wy in (1.5, 3.45): pm.window('+z', (pcx, wy, zp), w=.55, h=.9 if wy < 2 else .8, frame=white, shutters='5E8F9A', arch=(wy > 2))
        xs = px1 if sgn > 0 else px0
        if sgn > 0:
            for wz in (-1.2, -2.3, -3.4):
                pass
    # central pavilion + clock tower
    cpx = 1.45; zc = z1
    pm.box((0, (hb + .55) / 2 + .15, (z0 + 1.0 + zc) / 2), (2 * cpx, hb + .55, zc - z0 - 1.0), 'F3E3C5', 'blocks', power=.16)
    for sx in (-cpx, cpx): pm.box((sx, (hb + .55) / 2 + .15, zc - .05), (.28, hb + .55, .22), white, 'blocks', power=.25)
    pm.box((0, hb + .78, zc), (2 * cpx + .2, .16, .22), white, 'soft', power=.3)
    pm.hip(-cpx, cpx, -3.6, zc, hb + .7, 1.6, .28, .13, cop, 'copper', 2.6)
    tw = .85; tz0, tz1 = -2.4, -.5
    pm.box((0, hb + 1.55 + 1.5, (tz0 + tz1) / 2), (2 * tw, 3.0, tz1 - tz0), 'F3E3C5', 'blocks', power=.16)
    for sx in (-tw, tw): pm.box((sx, hb + 3.0, tz1 - .02), (.2, 3.1, .2), white, 'blocks', power=.25)
    tt_ = pm.hip(-tw, tw, tz0, tz1, hb + 4.6, 2.2, .3, .13, cop, 'copper', 2.0)
    pm.cyl2((0, tt_, (tz0 + tz1) / 2), (0, tt_ + .8, (tz0 + tz1) / 2), .025, .02, '4A3A4D', 'soft', 6, 2)
    pm.ell((0, tt_ + .82, (tz0 + tz1) / 2), (.07, .07, .07), 'E3C372', 'gold'); pm.flag(0, tt_ + .8, (tz0 + tz1) / 2, .6, '6B9A3E', length=.5) if False else None
    clock_face(pm, 0, hb + 3.1, tz1 + .01, '+z', .56); clock_face(pm, tw + .01, hb + 3.1, (tz0 + tz1) / 2, '+x', .56)
    pm.window('+z', (0, hb + 4.3, tz1 + .0), w=.0, h=0, glow=False) if False else None
    # entrance
    steps(pm, 0, zc, 2.6, 3); pm.box((0, .62, zc + .35), (2.1, .08, .7), 'D8D2DE', 'blocks', power=.28) if False else None
    pm.door('+z', (0.0, zc - .0), w=1.0, h=1.9, col='3F6B4E', frame=white, arch=True, glow=True, double=True)
    pm.window('+z', (0, 3.4, zc), w=.7, h=1.1, frame=white, shutters=None, arch=True)
    pm.box((0, 2.55, zc + .38), (1.5, .1, .8), 'D8D2DE', 'blocks', power=.28)
    for k in range(7): pm.box((-.68 + k * .227, 2.92, zc + .74), (.05, .5, .05), white, 'marble', power=.3)
    pm.box((0, 3.2, zc + .74), (1.5, .07, .08), white, 'marble', power=.3)
    for sx in (-.6, .6): pm.box((sx, 2.25, zc + .6), (.1, .5, .1), white, 'marble', power=.3)
    for sx in (-1.55, 1.55): urn(pm, sx, zc + .55, .12)
    lantern(pm, -1.0, 2.25, zc + .1); lantern(pm, 1.0, 2.25, zc + .1)
    for wx in (-1.8, 1.8): pm.window('+z', (wx, 1.6, zf), w=.5, h=.9, frame=white, shutters='5E8F9A', arch=True); pm.window('+z', (wx, 3.55, zf), w=.5, h=.8, frame=white, shutters='5E8F9A')
    for wz in (-1.5, -2.6, -3.7, -4.7):
        pm.window('+x', (wz, 1.6, x1), w=.5, h=.9, frame=white, shutters='5E8F9A', arch=True); pm.window('+x', (wz, 3.55, x1), w=.5, h=.8, frame=white, shutters='5E8F9A')
    for sx in (-3.0, 3.0): ivy(pm, [(sx + (.0), .6 + k * .5, zp_ + .08) for k, zp_ in enumerate([-.35] * 5)], .16, int(abs(sx) * 7), blossom='E58FA6')
    flower_bed(pm, -3.2, -1.7, zc + .15, .3, 5, 21); flower_bed(pm, 1.7, 3.2, zc + .15, .3, 5, 22)
    return House(8, 'herregaard', W, D, c, tt_ + 1.6, pm, 'red-brick manor, copper roofs, clock tower, balcony')


def tier9_borg() -> House:
    """borg - a stone fortress: gatehouse, two round corner towers, crenellated curtain walls, a keep and banners.  9 x 5."""
    pm = HM(); W, D, c = 9, 5, 4
    x0, x1, z0, z1 = _rect(W, D, c); cz = (z0 + z1) / 2
    st = 'BDB6C6'; stl = 'D3CDDB'; roofc = '8C78C8'; slate = '5F6C8E'
    hw = 3.5; tk = .9
    pm.box((0, .16, cz), (x1 - x0 + .3, .32, z1 - z0 + .3), '9A94A4', 'blocks', power=.22)
    pm.box((0, hw / 2 + .1, z0 + tk / 2), (x1 - x0 - .6, hw, tk), st, 'blocks', power=.16)                       # back wall
    for sx in (x0 + .5, x1 - .5): pm.box((sx, hw / 2 + .1, cz), (tk, hw, z1 - z0 - .6), st, 'blocks', power=.16)   # side walls
    pm.crenellations(x0 + .5 - tk / 2, x1 - .5 + tk / 2, z0, z1, hw + .1, st, 'blocks', faces=('x1', 'x0', 'z0'), gap=.52)
    # great hall inside the courtyard
    pm.box((-1.2, 2.6, -2.9), (4.4, 4.4, 2.2), 'F3E3C5', 'plaster', power=.16)
    pm.gable(-3.4, 1.0, -4.0, -1.8, 4.8, 36, 'x', .3, .13, slate, 'slate', 'F3E3C5', 'plaster', rcol='3E4866', ridge_r=.11)
    for wx in (-2.7, -1.5, -.3): pm.window('+z', (wx, 3.0, -1.8), w=.45, h=.95, frame='FBF5E6', arch=True)
    # keep at the back right
    kx0, kx1, kz0, kz1 = 1.3, 3.8, -5.0, -2.6
    dk = 1.25                                                                                                  # keep raised by 1.25 m (A1 re-bake, RV-A9 stretch goal): tier 9 now stands above tier 8
    pm.box(((kx0 + kx1) / 2, 4.1 + dk / 2, (kz0 + kz1) / 2), (kx1 - kx0, 8.0 + dk, kz1 - kz0), stl, 'blocks', power=.16)
    pm.box(((kx0 + kx1) / 2, 7.05 + dk, (kz0 + kz1) / 2), (kx1 - kx0 + .5, .22, kz1 - kz0 + .5), stl, 'blocks', power=.22)
    pm.crenellations(kx0 - .25, kx1 + .25, kz0 - .25, kz1 + .25, 7.15 + dk, stl, 'blocks', gap=.5)
    for tx_, tz_ in ((kx0 - .1, kz1 + .05), (kx1 + .1, kz1 + .05), (kx1 + .1, kz0 - .05), (kx0 - .1, kz0 - .05)):
        pm.cyl2((tx_, 6.8 + dk, tz_), (tx_, 8.2 + dk, tz_), .3, .28, stl, 'blocks', 14, 3); pm.cone((tx_, tz_), .38, .95, roofc, 'rooftile', y=8.15 + dk)
    for wy in (3.0, 4.8, 6.1, 7.4):
        for wz in (-3.1, -4.1): pm.window('+x', (wz, wy, kx1), w=.34, h=.6, frame='FBF5E6', arch=True)
    for wx in (1.95, 3.1): pm.window('+z', (wx, 4.8, kz1), w=.34, h=.6, frame='FBF5E6', arch=True); pm.window('+z', (wx, 3.0, kz1), w=.34, h=.6, frame='FBF5E6', arch=True)
    pm.flag(2.55, 8.6 + dk, -3.8, 1.5, '6B9A3E', length=.85)
    # front curtain wall + gatehouse
    gx = 1.55
    for (a, b) in ((x0 + 1.5, -gx), (gx, x1 - 1.5)):
        pm.box(((a + b) / 2, hw / 2 + .1, -.4), (b - a, hw, .8), st, 'blocks', power=.16)
    pm.crenellations(x0 + 1.5, -gx, -.8, 0, hw + .1, st, 'blocks', faces=('z1',), gap=.5); pm.crenellations(gx, x1 - 1.5, -.8, 0, hw + .1, st, 'blocks', faces=('z1',), gap=.5)
    pm.box((0, 2.95, -1.0), (2 * gx, 5.6, 2.0), stl, 'blocks', power=.16)
    pm.box((0, 5.82, -1.0), (2 * gx + .5, .22, 2.5), stl, 'blocks', power=.22)
    pm.crenellations(-gx - .25, gx + .25, -2.25, .25, 5.9, stl, 'blocks', gap=.5, faces=('z1', 'x1', 'x0'))
    pm.box((0, 1.15, .02), (1.5, 2.3, .1), 'D8D2DE', 'blocks', power=.25)                                  # portal frame
    pm.ell((0, 2.3, .02), (.75, .55, .1), 'D8D2DE', 'blocks', power=.8)
    pm.box((0, 1.1, .06), (1.1, 2.1, .08), '5A3B26', 'plank_v', power=.25)
    pm.ell((0, 2.05, .06), (.55, .45, .08), '5A3B26', 'plank_v', power=.7)
    for k in range(5): pm.box((0, .35 + k * .38, .12), (1.1, .05, .04), '4A3A4D', 'soft', power=.3)
    pm.box((0, 1.5, .07), (.05, 2.4, .04), '4A3A4D', 'soft', power=.3)
    pm.door('+z', (0.0, 0.0), w=.0, h=.0, glow=False) if False else None
    pm.emit_ell((0, 1.6, .13), (.2, .0, .0), 'FFD98A') if False else None
    pm.window('+z', (0, 4.2, .05), w=.5, h=.85, frame='FBF5E6', shutters=None, arch=True)
    pm.banner(-1.15, 3.2, .1, .5, 1.5, '6B9A3E'); pm.banner(1.15, 3.2, .1, .5, 1.5, '6B9A3E')
    pm.banner(0, 5.1, .12, .0, 0, '6B9A3E') if False else None
    lantern(pm, -.95, 2.0, .35); lantern(pm, .95, 2.0, .35)
    steps(pm, 0, .0, 2.0, 2, .15, .3, '9A94A4')
    # round towers at the front corners (raised by 1.2 m like the keep: the tallest solid pixel of the sprite is the left tower's cone - A1 re-bake, RV-A9 stretch goal)
    for sgn in (-1, 1):
        tx = sgn * 3.6
        round_tower(pm, (tx, -.95), 1.05, 5.6 + 1.2, st, 'blocks', roofc, 'rooftile', 3.0, bands=(.5,), windows=(.25, .5, .72), flag='6B9A3E' if sgn > 0 else 'E58FA6', battlement=False, wnd_angles=(20, -30, 15))
    ivy(pm, [(-3.6 + 1.0, .5 + k * .55, -.95 + .5) for k in range(7)], .17, 31, blossom='E58FA6')
    ivy(pm, [(3.6 + .98, .5 + k * .5, -.95 + .55) for k in range(6)], .17, 32)
    flower_bed(pm, -2.7, -1.4, .55, .3, 4, 41); flower_bed(pm, 1.4, 2.7, .55, .3, 4, 42)
    return House(9, 'borg', W, D, c, 11.65, pm, 'stone fortress, gatehouse, round towers, keep, banners')


def tier10_slot() -> House:
    """slot - the Fairy King's gift: cream marble palace, lavender roofs, gold domes, a tall central spire, lit gate and glowing windows.  9 x 6."""
    pm = HM(); W, D, c = 9, 6, 4
    x0, x1, z0, z1 = _rect(W, D, c); cz = (z0 + z1) / 2
    cream = 'F2E6CC'; marb = 'F7F0E2'; lav = '9B86D6'; lav2 = '8574C4'; teal = '7FC8A5'; gold = 'E3C372'
    pm.box((0, .2, cz), (x1 - x0 + .35, .4, z1 - z0 + .35), 'C9C3CF', 'blocks', power=.22)
    # keep (centre, behind) with the great spire
    kx = 1.9; kz0, kz1 = -5.5, -2.0; kh = 6.2
    pm.box((0, kh / 2 + .3, (kz0 + kz1) / 2), (2 * kx, kh, kz1 - kz0), cream, 'blocks', power=.15)
    pm.frustum((-kx - .3, kx + .3, kz0 - .3, kz1 + .3), kh + .3, (-.9, .9, kz0 + 1.3, kz1 - 1.3), kh + 1.9, .13, lav2, 'rooftile', 2.8)
    spire_top = round_tower(pm, (0, (kz0 + kz1) / 2 - .2), 1.05, kh + 1.2, marb, 'blocks', teal, 'rooftile', 3.4, bands=(.55, .85), windows=(.45, .7, .88), band_col=gold, flag='6B9A3E', wnd_angles=(25, -25, 35))
    pm.ell((0, spire_top + .12, (kz0 + kz1) / 2 - .2), (.16, .16, .04), gold, 'gold')
    for wy in (3.4, 5.4): [pm.window('+x', (wz, wy, kx), w=.4, h=.85, frame='FBF5E6', arch=True) for wz in (-3.0, -4.3)]
    # side wings (two storeys, lavender hip roofs) and the front palace block
    for sgn in (-1, 1):
        wx0, wx1 = (-3.5, -1.7) if sgn < 0 else (1.7, 3.5)
        pm.box(((wx0 + wx1) / 2, 2.55, -1.6), (wx1 - wx0, 4.5, 3.2), cream, 'blocks', power=.15)
        pm.hip(wx0, wx1, -3.2, 0.0, 4.8, 1.6, .3, .13, lav, 'rooftile', 3.0)
        pm.box(((wx0 + wx1) / 2, 4.82, .05), (wx1 - wx0 + .1, .14, .22), marb, 'soft', power=.3)
        for wx in ((wx0 + wx1) / 2 - .35, (wx0 + wx1) / 2 + .35): pass
        xs = (wx0 + wx1) / 2
        pm.window('+z', (xs, 1.65, 0.0), w=.55, h=1.15, frame='FBF5E6', shutters=teal, arch=True); pm.window('+z', (xs, 3.5, 0.0), w=.5, h=.85, frame='FBF5E6', shutters=teal, arch=True)
    # connecting back wings (slightly lower)
    for sgn in (-1, 1):
        bx0, bx1 = (-3.6, -1.7) if sgn < 0 else (1.7, 3.6)
        pm.box(((bx0 + bx1) / 2, 2.2, -4.7), (bx1 - bx0, 3.6, 3.0), cream, 'blocks', power=.15)
        pm.hip(bx0, bx1, -6.2, -3.2, 4.0, 1.4, .3, .13, lav2, 'rooftile', 3.0)
    # gate pavilion (centre front)
    gx = 1.45; gh = 5.4
    pm.box((0, gh / 2 + .2, -1.4), (2 * gx, gh, 2.8), marb, 'blocks', power=.15)
    for sx in (-gx, gx): pm.box((sx, gh / 2 + .2, -.06), (.3, gh, .22), 'FBF5E6', 'marble', power=.25)
    pm.box((0, gh + .3, -.02), (2 * gx + .15, .2, .26), 'FBF5E6', 'soft', power=.3)
    ped = geo.rounded_triangle([(-gx - .15, gh + .38), (gx + .15, gh + .38), (0, gh + 1.55)], 5)
    v, f = geo.pillow(np.asarray(ped, float), 0.06, .1, 1.0); pm._add(v, f, marb, 'marble@3.2')
    ped2 = geo.rounded_triangle([(-gx + .15, gh + .5), (gx - .15, gh + .5), (0, gh + 1.25)], 5)
    v, f = geo.pillow(np.asarray(ped2, float), .13, .06, 1.0); pm._add(v, f, 'C9B8EE', 'painted@2.4')
    pm.ell((0, gh + .85, .2), (.22, .22, .03), gold, 'gold', seg=14, rings=10)
    pm.gable(-gx, gx, -2.8, 0, gh + .35, 34, 'x', .2, .12, lav2, 'rooftile', marb, 'blocks', rcol='6C5AA8', ends=False) if False else None
    pm.hip(-gx, gx, -2.8, -.1, gh + .3, 1.25, .2, .12, lav2, 'rooftile', 2.8)
    # grand arched gate with golden doors + balcony
    pm.box((0, 1.5, .05), (1.9, 3.0, .12), 'D8D2DE', 'marble', power=.25)
    pm.ell((0, 3.0, .05), (.95, .75, .12), 'D8D2DE', 'marble', power=.8)
    pm.box((0, 1.4, .1), (1.5, 2.7, .1), gold, 'gold', power=.25)
    pm.ell((0, 2.7, .1), (.75, .6, .1), gold, 'gold', power=.8)
    pm.box((0, 1.4, .17), (.05, 2.6, .05), 'B88F3F', 'gold', power=.3)
    pm.ell((0, 2.3, .16), (.55, .5, .02), 'FFD98A', 'emitn', power=.9)
    pm.ell((0, 3.15, .16), (.0001, .0001, .0001), 'FFD98A', 'soft') if False else None
    pm.box((0, 3.95, .25), (2.4, .12, .8), marb, 'marble', power=.3)
    for k in range(9): pm.box((-1.1 + k * .275, 4.3, .6), (.05, .55, .05), gold, 'gold', power=.3)
    pm.box((0, 4.62, .6), (2.4, .07, .08), gold, 'gold', power=.3)
    pm.window('+z', (0, 4.75, .0), w=.0, h=.0, glow=False) if False else None
    pm.window('+z', (-.6, 4.9, 0.0), w=.36, h=.8, frame='FBF5E6', arch=True, shutters=None); pm.window('+z', (.6, 4.9, 0.0), w=.36, h=.8, frame='FBF5E6', arch=True, shutters=None)
    # grand staircase with gold rails
    steps(pm, 0, .0, 3.2, 4, .17, .34, 'F1E8D8')
    for sx in (-1.55, 1.55): pm.box((sx, .55, .6), (.08, .06, 1.3), gold, 'gold', power=.3, rot=(-25, 0, 0)); pm.cyl2((sx, 0, 1.2), (sx, .7, 1.2), .05, .04, gold, 'gold', 8, 2); pm.ell((sx, .75, 1.2), (.08, .08, .08), gold, 'gold')
    for sx in (-2.0, 2.0): urn(pm, sx, .6, .0)
    # towers: gold onion domes at the front, lavender cones at the back corners
    for sgn in (-1, 1):
        round_tower(pm, (sgn * 3.9, -.95), 1.0, 5.4, marb, 'blocks', 'E3C372', 'gold', 2.0, bands=(.45, .8), windows=(.22, .5, .72), band_col=gold, dome=True, wnd_angles=(25, -25, 30))
        round_tower(pm, (sgn * 3.8, -5.3), .95, 7.0, cream, 'blocks', lav if sgn < 0 else teal, 'rooftile', 3.2, bands=(.5, .85), windows=(.3, .55, .8), band_col=gold, flag='E58FA6' if sgn < 0 else '6B9A3E', wnd_angles=(30, -30, 25))
    # banners + lit windows on the palace faces + blossom + ivy
    pm.banner(-1.0, 3.3, .22, .48, 1.5, '6B9A3E'); pm.banner(1.0, 3.3, .22, .48, 1.5, '6B9A3E')
    for sgn in (-1, 1):
        ivy(pm, [(sgn * 2.55 + (k % 2) * .3 * sgn, .5 + k * .45, .1) for k in range(7)], .16, 50 + sgn, blossom='E58FA6')
    for wz in (-1.0, -2.2): pm.window('+x', (wz, 1.65, 3.5), w=.5, h=1.0, frame='FBF5E6', shutters=teal, arch=True); pm.window('+x', (wz, 3.5, 3.5), w=.46, h=.85, frame='FBF5E6', shutters=teal, arch=True)
    for k in range(6):                                                                      # fairy lights drifting around the spire
        a = k * 1.1; pm.emit_ell((math.cos(a) * 1.8, spire_top - 1.2 - (k % 3) * .6, (kz0 + kz1) / 2 - .2 + math.sin(a) * 1.8 + .6), (.07, .07, .07), 'FFF0A8', 1.0, None, 10, 8)
    lantern(pm, -1.1, 2.4, .5); lantern(pm, 1.1, 2.4, .5)
    flower_bed(pm, -3.3, -2.2, 1.0, .3, 4, 61); flower_bed(pm, 2.2, 3.3, 1.0, .3, 4, 62)
    return House(10, 'slot', W, D, c, spire_top + 1.5, pm, 'cream marble palace, gold domes, lavender roofs, lit gate, great spire')


TIERS = {1: tier1_skur, 2: tier2_hytte, 3: tier3_straatag, 4: tier4_bindingsvaerk, 5: tier5_gaarden, 6: tier6_tarnhus, 7: tier7_landsted, 8: tier8_herregard, 9: tier9_borg, 10: tier10_slot}
