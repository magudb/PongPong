"""Parametric furniture: ONE template function per piece type  x  a Style (materials/palette + rarity tier) = many catalogue items.

    spec = TEMPLATES['bed'](Style(tier=2, wood='walnut', fabric='plum'), size='double')

Rarity ladder (tier): 0 normal = plain wood/cloth
                      1 uncommon = painted / trimmed, cushions, two-tone
                      2 rare = carved + inlaid + brass/gold hardware, patterned fabric
                      3 unique = a different silhouette / hand-made quirk (living wood, mushrooms, shells, owls ...)
                      4 legendary = magic: additive glow, floating bits (layer 'float' -> bobs in engine), crystals, sparkle shader
Symmetry: `FSpec.sym` (c4 | c2 | wall2 | none) is what the template DECLARES.  It is not trusted: isometric/measure_symmetry.py bakes the four views of every piece that declares c4 or c2 and
spec_reader.symmetry() replaces the declared class by the measured one (specs/symmetry_measured.json; 15 of 41 declarations were wrong).
Style keys are honoured at EVERY tier (a template that ignored `fabric`, `stone` or `wood` at some tier shipped twins: curtain_green = curtain_natural, fireplace_slate = fireplace_marble,
floor_lamp_birch = floor_lamp_iron); tests/sections/art_home.gd furniture_looks_distinct fails on any two ids with the same picture.
Coordinates (metres, Y up): origin = footprint centre on the floor; front = +z (screen left-down); footprint = (fx, fz) tiles at rotation 0.
Wall items hang on the plane z = -depth/2 (back), facing +z.
"""
from __future__ import annotations
import math
import numpy as np
import geometry as geo
from home_kit import HM, T, PAINTERS
import home_kit as hk

# ----------------------------------------------------------------------------------------------------------------------------------
# palettes (the material dict).  Everything is data: materials.json is exported from these.
# ----------------------------------------------------------------------------------------------------------------------------------
WOODS = {
    'pine':     dict(main='D6B27A', dark='B58A52', light='ECD3A2'),
    'oak':      dict(main='B88A52', dark='8C6B3F', light='D4AA74'),
    'birch':    dict(main='EBDDBF', dark='C9B58E', light='F8F0DC'),
    'walnut':   dict(main='7A4E2D', dark='5A3B26', light='9C6A42'),
    'cherry':   dict(main='A5523A', dark='7E3A28', light='C97356'),
    'ebony':    dict(main='4A3F5C', dark='352D48', light='6E6286'),
    'mossy':    dict(main='8E7C58', dark='6B5B3C', light='AA9B70'),
    'moonwood': dict(main='C9D4EE', dark='9BA9D2', light='EAF0FB'),
    'living':   dict(main='8A6A42', dark='6B4E2E', light='AD8D5C'),
}
PAINTS = {   # Trætoppen / Hyggebyen guide colours (milk paint)
    'mosgroen': ('8DB86A', 'mosgroen'), 'himmel': ('A9D3E0', 'himmel'), 'rose': ('E58FA6', 'rose'), 'lavendel': ('B6A6E6', 'lavendel'),
    'honning': ('E8B04A', 'honning'), 'kridt': ('FBF5E6', 'kridt'), 'tornebaer': ('B3436B', 'tornebaer'), 'mynte': ('7FC8A5', 'mynte'),
}
FABRICS = {  # (colour, pattern, key)
    'natur': ('E9DCC0', 'weave', 'natur'), 'roed': ('B8503A', 'weave', 'roed'), 'blaa': ('6F8FBF', 'stripe', 'blaa'),
    'groen': ('6F9A52', 'quilt', 'groen'), 'bordeaux': ('8E3A55', 'velvet', 'bordeaux'), 'blommevelour': ('6A4C8C', 'velvet', 'blommevelour'),
    'guld': ('D8B25A', 'damask', 'guld'), 'rosendamask': ('D68AA0', 'damask', 'rosendamask'), 'kongeblaa': ('3F5FA0', 'damask', 'kongeblaa'),
    'maane': ('B8C6EE', 'velvet', 'maane'),
}
METALS = {'jern': ('4A3A4D', 'jern'), 'messing': ('D9A441', 'messing'), 'guld': ('E3C372', 'guld'), 'soelv': ('C9D2E0', 'soelv'), 'kobber': ('D98A5A', 'kobber')}
CRYSTALS = {'maanesten': ('CFE0FF', 'EAF3FF'), 'ametyst': ('A57BE0', 'D2B4F5'), 'smaragd': ('48B97F', '9BE7BC'), 'rosenkvarts': ('E58FA6', 'FFD0DE'), 'ravgul': ('F2C14E', 'FFE49A')}
STONES = {'granit': ('9A9AA6', 'granit'), 'marmor': ('F0EAE0', 'marmor'), 'skifer': ('6E7A98', 'skifer'), 'kalksten': ('D8CDB4', 'kalksten')}
STONE_TEX = {'granit': 'blocks', 'marmor': 'marble', 'skifer': 'blocks', 'kalksten': 'blocks'}      # painter of each stone: the style key decides colour AND texture
RARITY = ['normal', 'uncommon', 'rare', 'unique', 'legendary']


class Style:
    def __init__(self, tier=0, wood='pine', paint=None, fabric='natur', metal=None, crystal=None, stone=None, accent=None):
        self.t = tier; self.wood = wood; self.w = WOODS[wood]
        self.paint_key = paint; self.paint = PAINTS[paint][0] if paint else None
        self.fab_key = fabric; self.fab, self.fab_tex, _ = FABRICS[fabric]
        self.metal_key = metal or ('guld' if tier >= 3 else ('messing' if tier == 2 else 'jern'))
        self.metal = METALS[self.metal_key][0]
        self.crys_key = crystal or 'maanesten'; self.crys = CRYSTALS[self.crys_key]
        self.stone_key = stone or 'granit'; self.stone = STONES[self.stone_key][0]; self.stone_tex = STONE_TEX[self.stone_key]
        self.acc = accent or ('E3C372' if tier >= 2 else self.w['dark'])

    @property
    def body(self): return self.paint or self.w['main']
    @property
    def btex(self): return 'painted' if self.paint else 'wood'
    @property
    def dark(self): return _mix(self.paint, '2B2340', .35) if self.paint else self.w['dark']
    @property
    def light(self): return _mix(self.paint, 'FFFFFF', .35) if self.paint else self.w['light']
    @property
    def trim(self): return 'FBF5E6' if (self.paint and self.paint_key != 'kridt') else (self.w['dark'] if not self.paint else '8C6B3F')
    @property
    def glow_col(self): return self.crys[1]


def _mix(a, b, k):
    ca = np.array([int(a[i:i + 2], 16) for i in (0, 2, 4)], float); cb = np.array([int(b[i:i + 2], 16) for i in (0, 2, 4)], float)
    return ''.join('%02X' % int(round(v)) for v in ca * (1 - k) + cb * k)


class FSpec:
    def __init__(self, pm, fp, height, layer='floor', category='', sym='none', glow=None, surface=None, interact=None, hang=None, notes=''):
        self.pm, self.fp, self.height, self.layer, self.category, self.sym = pm, fp, height, layer, category, sym
        self.glow, self.surface, self.interact, self.hang, self.notes = glow, surface, interact, hang, notes


# ----------------------------------------------------------------------------------------------------------------------------------
# ornament helpers shared by all templates (the generic part of the rarity ladder)
# ----------------------------------------------------------------------------------------------------------------------------------
def leg(pm, S, x, z, h, r=.05):
    if S.t == 0 or S.t == 1 and not S.paint:
        pm.cyl2((x, 0, z), (x, h, z), r, r * .75, S.dark, 'wood', 10, 3)
    else:
        prof = [(0, .75), (.12, 1.05), (.2, .62), (.5, .88), (.62, .6), (.8, 1.1), (.9, .8), (1, .95)]
        pm.lathe(x, z, [(y * h, rr * r) for y, rr in prof], S.body if S.t < 3 else S.dark, S.btex, 12)


def knob(pm, x, y, z, S, r=.035, face='+z'):
    pm.ell((x, y, z), (r, r, r), S.metal, 'gold' if S.t >= 2 else 'soft', seg=10, rings=8)


def finial(pm, x, y, z, S, r=.05):
    if S.t >= 2:
        pm.ell((x, y + r * .6, z), (r, r * 1.25, r), S.acc, 'gold', seg=12, rings=8)
    elif S.t == 1:
        pm.ell((x, y + r * .5, z), (r * .9, r * .9, r * .9), S.dark, 'soft', seg=10, rings=8)


def edge_trim(pm, S, c, size, power=.3):
    pm.box(c, size, S.trim if S.t == 1 else S.dark, 'wood' if S.t != 1 or not S.paint else 'painted', power)


def inlay_panel(pm, S, c, size, face='+z'):
    """rare+: light wood panel with a thin gold border and a diamond"""
    cx, cy, cz = c; sx, sy, sz = size
    o = .012
    if face == '+z':
        pm.box((cx, cy, cz), (sx, sy, .02), S.w['light'] if not S.paint else S.light, 'wood', .35)
        pm.box((cx, cy, cz + o), (sx * .86, sy * .86, .014), S.dark, 'wood', .35)
        pm.box((cx, cy, cz + 2 * o), (sx * .78, sy * .78, .012), S.w['light'] if not S.paint else S.light, 'wood', .35)
        pm.box((cx, cy, cz + 3 * o), (sx * .22, sy * .22, .012), S.acc, 'gold', .4, rot=(0, 0, 45))
    else:
        pm.box((cx, cy, cz), (.02, sy, sz), S.w['light'] if not S.paint else S.light, 'wood', .35)
        pm.box((cx + o, cy, cz), (.014, sy * .86, sz * .86), S.dark, 'wood', .35)
        pm.box((cx + 2 * o, cy, cz), (.012, sy * .78, sz * .78), S.w['light'] if not S.paint else S.light, 'wood', .35)
        pm.box((cx + 3 * o, cy, cz), (.012, sy * .22, sz * .22), S.acc, 'gold', .4, rot=(45, 0, 0))


def sparkle(pm, c, r=.05, col='FFF4B8'):
    """4-point star made of two crossed thin ellipsoids (emissive)"""
    x, y, z = c
    pm.emit_ell((x, y, z), (r * 2.2, r * .35, r * .35), col, 1.0, None, 10, 6)
    pm.emit_ell((x, y, z), (r * .35, r * 2.2, r * .35), col, 1.0, None, 10, 6)
    pm.emit_ell((x, y, z), (r * .6, r * .6, r * .6), 'FFFFFF', 1.0, None, 10, 6)


def floaters(pm, S, c, spread=(.5, .35, .5), n=6, seed=1, r=.045, col=None, stars=True):
    """legendary: floating motes + stars on the 'float' layer (the engine bobs this layer)"""
    rng = np.random.default_rng(seed); col = col or S.glow_col
    old = pm.layer; pm.layer = 'float'
    for i in range(n):
        p = (c[0] + rng.uniform(-1, 1) * spread[0], c[1] + rng.uniform(-1, 1) * spread[1], c[2] + rng.uniform(-1, 1) * spread[2])
        if stars and i % 2 == 0: sparkle(pm, p, r * (.8 + .6 * rng.random()), 'FFF4B8')
        else: pm.emit_ell(p, (r * .8, r * .8, r * .8), col, 1.0, None, 10, 8)
    pm.layer = old


def crystal(pm, S, x, z, h=.4, r=.05, tilt=(0, 0), y0=0.0, emit=False):
    """a six-sided crystal spike (tube with a pointed tip)"""
    from scipy.spatial.transform import Rotation
    R = Rotation.from_euler('xyz', [tilt[0], 0, tilt[1]], degrees=True).as_matrix()
    pts = np.array([[0, 0, 0], [0, h * .78, 0], [0, h, 0]]) @ R.T + [x, y0, z]
    col = S.crys[0]
    if emit: pm.tube(pts, [r, r * .95, .006], S.crys[1], 'emit', 6)
    else: pm.tube(pts, [r, r * .95, .006], col, 'crystalf@%.2f' % max(h, .3), 6)


def glow_of(S, c, rad=34, strength=.6, col=None):
    return (col or S.glow_col, rad, strength, c)


# ----------------------------------------------------------------------------------------------------------------------------------
# TEMPLATES
# ----------------------------------------------------------------------------------------------------------------------------------
def bed(S, size='double') -> FSpec:
    pm = HM(); dbl = size == 'double'
    fx, fz = (2, 3) if dbl else (1, 2); W = fx * T - .16; L = fz * T - .14; zb = -L / 2
    hl = .2
    for sx in (-1, 1):
        for sz_ in (-1, 1): leg(pm, S, sx * (W / 2 - .06), sz_ * (L / 2 - .06), hl, .05)
    pm.box((0, hl + .15, 0), (W, .28, L), S.body, S.btex, .26)                                          # frame
    if S.t >= 1: pm.box((0, hl + .31, 0), (W + .02, .05, L + .02), S.trim, 'painted' if S.paint else 'wood', .3)
    pm.box((0, hl + .43, .06), (W - .1, .26, L - .22), 'F4EAD0', 'weave', .45)                          # mattress
    # blanket over the lower 2/3
    fab = S.fab; ftex = S.fab_tex
    bl = L * .62
    pm.box((0, hl + .58, L / 2 - bl / 2 - .08), (W - .02, .16, bl), fab, ftex, .5)
    pm.box((0, hl + .67, L / 2 - bl - .0), (W - .02, .1, .16), _mix(fab, 'FFFFFF', .35), 'weave', .6)       # folded cuff
    for i in range(2 if dbl else 1):
        px = (-.4 + i * .8) if dbl else 0
        pm.ell((px, hl + .66, zb + .38), (.36 if dbl else .3, .11, .24), 'FBF5E6', 'weave', .85, None, 18, 12)
    # headboard (back = -z) and footboard
    hh = 1.15
    pm.box((0, hl + hh / 2 + .1, zb + .06), (W + .04, hh, .1), S.body, S.btex, .24)
    pm.box((0, hl + .32, L / 2 - .05), (W + .04, .5, .08), S.body, S.btex, .24)
    for sx in (-1, 1):
        pm.box((sx * (W / 2 + .0), hl + hh * .5 + .1, zb + .06), (.1, hh + .12, .1), S.dark if S.t != 1 else S.trim, 'wood', .25)
        pm.box((sx * (W / 2 + .0), hl + .45, L / 2 - .05), (.1, .72, .1), S.dark if S.t != 1 else S.trim, 'wood', .25)
        finial(pm, sx * W / 2, hl + hh + .14, zb + .06, S, .055); finial(pm, sx * W / 2, hl + .78, L / 2 - .05, S, .05)
    if S.t == 1: pm.ell((0, hl + hh + .14, zb + .06), (W / 2 + .02, .18, .06), S.body, 'painted', .8)         # arched headboard cap
    if S.t == 2:
        inlay_panel(pm, S, (0, hl + hh * .55, zb + .115), (W * .7, hh * .52, .02))
        pm.ell((0, hl + hh + .2, zb + .06), (W * .22, .16, .07), S.acc, 'gold', .8)
    sleep = (0, L * .1)
    glow = None
    if S.t == 3:   # unique: mushroom canopy bed
        cy_ = hl + 2.15; cz_ = zb + L * .2; rx_, rz_ = W * .52 + .1, L * .24
        pm.cyl2((0, hl + .9, cz_), (0, cy_, cz_), .1, .08, 'F4E6C4', 'soft', 12, 3)
        pm.ell((0, cy_ + .08, cz_), (rx_, .36, rz_), 'E58FA6', 'soft', .9, None, 30, 18)
        pm.ell((0, cy_ - .02, cz_), (rx_ * .96, .05, rz_ * .96), 'F4DDD0', 'soft', .8, None, 24, 8)
        rng = np.random.default_rng(3)
        for i in range(8):
            a = rng.uniform(0, 6.28); e = rng.uniform(.25, .85)
            pm.ell((math.cos(a) * math.cos(e) * rx_ * .96, cy_ + .08 + math.sin(e) * .35, cz_ + math.sin(a) * math.cos(e) * rz_ * .96), (.11, .035, .11), 'FBF5E6', 'soft', 1, None, 12, 8)
    if S.t == 4:   # legendary: moon canopy + stars
        for sx in (-1, 1): pm.cyl2((sx * (W / 2 + .05), hl, zb + .06), (sx * (W / 2 + .05), hl + 2.1, zb + .06), .045, .04, S.metal, 'gold', 10, 3)
        pm.box((0, hl + 2.1, zb + .06), (W + .2, .06, .08), S.metal, 'gold', .3)
        for k in range(7):
            x_ = -W / 2 + k * W / 6
            pm.ell((x_, hl + 1.45, zb + .1), (.07, .65 + .1 * (k % 2), .02), 'DCE6FA', 'glassglow', .9, None, 10, 8)
        pm.ell((0, hl + 1.55, zb + .1), (W * .5, .35, .02), 'C9D8F6', 'glassglow', .9, None, 16, 8)
        glow = glow_of(S, (0, hl + 1.2, zb + .3), 70, .5)
        floaters(pm, S, (0, hl + 1.5, zb + L * .3), (W * .45, .6, L * .3), 8, 11)
    return FSpec(pm, (fx, fz), hl + hh + .12 if S.t != 3 else 2.4, 'floor', 'bed', 'none', glow, None, {'type': 'sleep', 'anchor': [0.0, 0.0], 'from': [0.0, 1.0]}, None)


def table(S, size='dining') -> FSpec:
    pm = HM(); round_ = size == 'round'
    fx, fz = {'round': (1, 1), 'dining': (2, 1), 'long': (3, 1)}[size]
    W = fx * T - .14; D = fz * T - .16; h = .76
    rx = [-1, 1]
    if S.t == 3:   # unique: tree-stump table with roots and toadstools
        r = min(W, D) * .55 if round_ else D * .56
        n = 1 if round_ else (2 if fx == 2 else 3)
        for i in range(n):
            cx_ = 0 if n == 1 else (i - (n - 1) / 2) * (W / n)
            pm.lathe(cx_, 0, [(y * (h - .03), rr) for y, rr in [(0, r * .95), (.05, r * .8), (.35, r * .7), (.75, r * .78), (.95, r * 1.0), (1, r * 1.0)]], '8A6A42', 'bark2', 20)
            pm.tube2(np.array([(cx_ - r * .1, .62, 0), (cx_ - r * .6, .3, 0), (cx_ - r * 1.1, 0, .05)]), [.09, .07, .04], '8A6A42', 'bark2', 8)
            pm.tube2(np.array([(cx_ + r * .1, .5, r * .3), (cx_ + r * .4, .2, r * .8), (cx_ + r * .5, 0, r * 1.05)]), [.08, .05, .03], '8A6A42', 'bark2', 8)
        if not round_: pm.box((0, h - .02, 0), (W, .08, D * .94), '8A6A42', 'wood', .35)
        pm.ell((0, h + .01, 0), ((r if round_ else W / 2) * .98, .05, (r if round_ else D / 2) * .94), 'C9A66B', 'wood', 1.0, None, 28, 8)
        for k in range(3): pm.ell((0, h + .04 + k * .0, 0), ((r if round_ else W / 2 * .8) * (1 - k * .25), .01, (r if round_ else D / 2 * .8) * (1 - k * .25)), '9C7A4A' if k % 2 == 0 else 'C9A66B', 'soft', 1.0, None, 24, 6)
        for sx, sz_, s_ in ((W / 2 - .12, D / 2 - .12, 1.0), (-W / 2 + .2, D / 2 - .1, .7)):
            pm.cyl2((sx, h + .03, sz_), (sx, h + .18 * s_ + .03, sz_), .03 * s_, .025 * s_, 'F4E6C4', 'soft', 8, 2)
            pm.ell((sx, h + .22 * s_, sz_), (.1 * s_, .06 * s_, .1 * s_), 'E58FA6', 'soft', .9, None, 14, 8)
        return FSpec(pm, (fx, fz), h + .12, 'floor', 'table', 'c2' if not round_ else 'c4', None, {'height': h + .05, 'slots': _slots(fx, fz)}, None)
    top_c = S.body if S.t != 2 else S.w['main']
    if round_:
        r = .5
        pm.ell((0, h, 0), (r, .04, r), top_c, S.btex, 1.0, None, 32, 10)
        pm.lathe(0, 0, [(0, .22), (.04, .12), (.5, .07), (.9, .09), (1, .2)], S.body if S.t != 2 else S.w['dark'], S.btex, 16, y0=0, scale=h - .04)
        if S.t >= 1: pm.ell((0, h + .035, 0), (r * 1.01, .015, r * 1.01), S.trim if S.t == 1 else S.dark, 'wood', 1.0, None, 32, 6)
        if S.t == 2:
            pm.ell((0, h + .05, 0), (r * .85, .012, r * .85), S.dark, 'wood', 1.0, None, 32, 6); pm.ell((0, h + .06, 0), (r * .6, .012, r * .6), S.w['light'], 'wood', 1.0, None, 32, 6)
            pm.ell((0, h + .07, 0), (r * .2, .012, r * .2), S.acc, 'gold', 1.0, None, 20, 6)
    else:
        pm.box((0, h, 0), (W, .07, D), top_c, S.btex, .3)
        pm.box((0, h - .12, 0), (W - .22, .11, D - .22), S.body, S.btex, .26)
        for sx in rx:
            for sz_ in rx: leg(pm, S, sx * (W / 2 - .1), sz_ * (D / 2 - .1), h - .04, .055)
        if S.t >= 1: pm.box((0, h + .04, 0), (W + .01, .03, D + .01), S.trim if S.t == 1 else S.dark, 'wood', .3)
        if S.t == 2:
            pm.box((0, h + .05, 0), (W * .86, .012, D * .72), S.w['light'], 'wood', .3); pm.box((0, h + .06, 0), (W * .8, .012, D * .62), S.dark, 'wood', .3)
            pm.box((0, h + .07, 0), (W * .74, .012, D * .54), S.w['light'], 'wood', .3); pm.box((0, h + .08, 0), (W * .22, .012, D * .4), S.acc, 'gold', .4, rot=(0, 45, 0))
            for k in range(int(W / .2)): pm.ell((-W / 2 + .15 + k * .2, h - .2, D / 2 - .1), (.045, .06, .02), S.acc, 'gold', .9, None, 10, 8)
        if S.t == 4:
            pm.box((0, h + .06, 0), (W * .8, .03, D * .72), S.crys[0], 'crystalf@1.4', .35)
            pm.box((0, h + .075, 0), (W * .6, .012, D * .5), S.crys[1], 'emit', .35)
    glow = None
    if S.t == 4:
        glow = glow_of(S, (0, h + .3, 0), 60, .45)
        floaters(pm, S, (0, h + .55, 0), (W * .3, .25, D * .3), 5, 5)
        pm.ell((0, h + .18, 0), (.14, .14, .14), S.crys[1], 'emit', 1.0, None, 14, 10)
    return FSpec(pm, (fx, fz), h + .12, 'floor', 'table', 'c4' if round_ else 'c2', glow, {'height': h + .08, 'slots': _slots(fx, fz)}, None)


def _slots(fx, fz):
    return [[round(x, 2), round(z, 2)] for x in np.linspace(-(fx - 1) / 2, (fx - 1) / 2, fx) for z in np.linspace(-(fz - 1) / 2, (fz - 1) / 2, fz)]


def chair(S) -> FSpec:
    pm = HM(); W = .62; seat = .46
    if S.t == 3:   # unique: tree-stump armchair with a leaf back
        pm.lathe(0, 0, [(0, .3), (.1, .26), (.6, .24), (.9, .29), (1, .31)], '8A6A42', 'bark2', 16, scale=.5)
        pm.ell((0, .5, 0), (.32, .05, .32), 'C9A66B', 'wood', 1.0, None, 20, 8)
        pm.cyl2((0, .5, 0), (0, .52, 0), .0, .0, '8A6A42', 'soft') if False else None
        pm.cyl2((0, .5, -.24), (0, .9, -.3), .05, .04, '6B8A3A', 'soft', 8, 3)
        for k in range(5):
            a = -.8 + k * .4
            pm.ell((math.sin(a) * .2, .92 + .06 * math.cos(a * 2), -.3 - .02 * abs(k - 2)), (.17, .34, .035), ('6FAA46', '97C95E', '4F8A38')[k % 3], 'leaf', .85, (-8, -a * 40, a * 28), 14, 10)
        pm.ell((0, .56, .02), (.26, .06, .26), S.fab, S.fab_tex, .9, None, 16, 8)
        return FSpec(pm, (1, 1), 1.3, 'floor', 'chair', 'none', None, None, {'type': 'sit', 'anchor': [0, 0], 'from': [0, 1]})
    for sx in (-1, 1):
        for sz_ in (-1, 1): leg(pm, S, sx * (W / 2 - .06), sz_ * (W / 2 - .06), seat, .035)
    pm.box((0, seat, 0), (W, .06, W), S.body, S.btex, .3)
    for sx in (-1, 1): pm.box((sx * (W / 2 - .04), 1.0 if S.t != 4 else 1.25, -W / 2 + .05), (.06, 1.0 - seat + (0 if S.t != 4 else .25), .06), S.dark if S.t != 1 else S.body, 'wood', .3) if False else None
    bh = 1.0 if S.t != 4 else 1.22
    for sx in (-1, 1): pm.cyl2((sx * (W / 2 - .05), seat, -W / 2 + .05), (sx * (W / 2 - .05), bh, -W / 2 + .05), .035, .03, S.body if S.t else S.dark, S.btex, 10, 3)
    pm.box((0, bh - .12, -W / 2 + .05), (W - .04, .13, .05), S.body, S.btex, .3)                              # top rail
    for k in range(3 if S.t < 2 else 0): pm.box((-.15 + k * .15, (seat + bh) / 2 + .1, -W / 2 + .05), (.06, bh - seat - .3, .03), S.body, S.btex, .3)
    if S.t >= 2:
        pm.box((0, (seat + bh) / 2 + .02, -W / 2 + .05), (.3, bh - seat - .25, .04), S.body, 'wood', .35)
        pm.ell((0, (seat + bh) / 2 + .02, -W / 2 + .08), (.1, .16, .02), S.acc, 'gold', .9)
        pm.ell((0, bh - .02, -W / 2 + .05), (.13, .07, .04), S.body, 'wood', .8)
    if S.t >= 1: pm.box((0, seat + .06, .02), (W - .08, .09, W - .1), S.fab, S.fab_tex, .6)                  # seat cushion
    for sx in (-1, 1): finial(pm, sx * (W / 2 - .05), bh, -W / 2 + .05, S, .045)
    glow = None
    if S.t == 4:
        crystal(pm, S, 0, -W / 2 + .05, .32, .045, y0=bh, emit=False); crystal(pm, S, -.14, -W / 2 + .05, .2, .035, (0, 12), y0=bh - .02); crystal(pm, S, .14, -W / 2 + .05, .2, .035, (0, -12), y0=bh - .02)
        glow = glow_of(S, (0, bh + .1, -W / 2), 44, .45); floaters(pm, S, (0, bh + .2, 0), (.28, .2, .2), 4, 8)
    return FSpec(pm, (1, 1), bh + .08, 'floor', 'chair', 'none', glow, None, {'type': 'sit', 'anchor': [0, 0], 'from': [0, 1]})


def sofa(S, seats=2) -> FSpec:
    pm = HM(); fx = seats; W = fx * T - .1; D = .98; sh = .42
    fab, ftex = S.fab, S.fab_tex
    if S.t == 3:   # unique: giant-leaf sofa
        pm.box((0, .3, 0), (W, .3, D), '8A6A42', 'bark2', .3)
        for i in range(seats): pm.ell((-W / 2 + (i + .5) * W / seats, .56, .1), (W / seats / 2 - .03, .12, D / 2 - .12), '6FAA46', 'leaf', .9, None, 18, 10)
        for k in range(seats * 2 + 1):
            x_ = -W / 2 + .05 + k * (W - .1) / (seats * 2)
            pm.ell((x_, 1.0 + .06 * math.sin(k), -D / 2 + .1), (.22, .55 + .08 * (k % 2), .05), ('6FAA46', '97C95E', '4F8A38')[k % 3], 'leaf', .85, (-8, 0, (k - seats) * 9), 14, 10)
        for sx in (-1, 1): pm.ell((sx * (W / 2 - .05), .6, 0), (.1, .35, D / 2 - .06), '8A6A42', 'bark2', .6)
        pm.ell((0, .62, .3), (.3, .05, .02), 'FBF5E6', 'soft') if False else None
        return FSpec(pm, (fx, 1), 1.6, 'floor', 'sofa', 'none', None, None, {'type': 'sit', 'anchor': [0, 0], 'from': [0, 1], 'seats': seats})
    for sx in (-1, 1):
        for sz_ in (-1, 1): leg(pm, S, sx * (W / 2 - .08), sz_ * (D / 2 - .08), .14, .045)
    pm.box((0, .27, 0), (W, .28, D), S.body, S.btex, .26)                                                      # base frame
    for i in range(seats):                                                                                       # seat cushions
        x_ = -W / 2 + (i + .5) * (W - .3) / seats + .15
        pm.box((x_, .52, .08), ((W - .3) / seats - .03, .2, D - .3), fab, ftex, .6)
    pm.box((0, .72, -D / 2 + .13), (W - .26, .5, .24), fab, ftex, .55)                                          # back cushion
    pm.box((0, .78, -D / 2 + .06), (W, .66, .14), S.body, S.btex, .3)                                           # back frame
    for sx in (-1, 1): pm.box((sx * (W / 2 - .1), .52, .0), (.2, .42, D - .1), fab, ftex, .6)                 # arms
    if S.t >= 1:
        for i in range(seats * 3):
            x_ = -W / 2 + .3 + i * (W - .6) / (seats * 3 - 1)
            pm.ell((x_, .84, -D / 2 + .25), (.022, .022, .022), S.metal if S.t >= 2 else S.dark, 'soft', 1.0, None, 8, 6)
        for sx in (-1, 1): pm.ell((sx * (W / 2 - .38), .68, .0), (.16, .16, .08), _mix(fab, 'FFFFFF', .3), 'quilt' if S.t < 2 else 'damask', .8, (0, 25 * sx, 0), 14, 10)
    if S.t == 2: pm.box((0, .42, D / 2 - .03), (W - .1, .05, .04), S.acc, 'gold', .3); pm.box((0, 1.12, -D / 2 + .06), (W - .3, .06, .1), S.acc, 'gold', .3)
    glow = None
    if S.t == 4:
        pm.ell((0, .14, 0), (W * .5, .12, D * .5), S.crys[1], 'emit', .9, None, 24, 10)
        glow = glow_of(S, (0, .2, 0), 70, .45); floaters(pm, S, (0, 1.0, 0), (W * .4, .3, .3), 7, 21)
    return FSpec(pm, (fx, 1), 1.12, 'floor', 'sofa', 'none', glow, None, {'type': 'sit', 'anchor': [0, 0], 'from': [0, 1], 'seats': seats})


def wardrobe(S, size='wide') -> FSpec:
    pm = HM(); fx = 2 if size == 'wide' else 1; W = fx * T - .12; D = .78; H = 2.15
    if S.t == 3:   # unique: hollow-log wardrobe with a hobbit door
        r = .6 if fx == 2 else .45
        pm.lathe(0, 0, [(y * (H - .15), rr) for y, rr in [(0, r * .94), (.04, r), (.5, r * .96), (.96, r * 1.02), (1, r * .96)]], '8A6A42', 'bark2', 24)
        pm.ell((0, H - .1, 0), (r * 1.04, .08, r * 1.04), 'C9A66B', 'wood', 1.0, None, 24, 8)
        pm.ell((0, H - .02, 0), (r * .9, .1, r * .9), '6FAA46', 'leaf', 1.0, None, 20, 8)
        pm.ell((0, 1.0, r * .97), (.44, .58, .08), 'C9A66B', 'wood', .8, None, 20, 12)
        pm.ell((0, 1.0, r * 1.0), (.36, .5, .09), '5E8F44', 'plank_v', .8, None, 20, 12)
        pm.ell((.16, 1.0, r * 1.07), (.045, .045, .035), 'E3C372', 'gold')
        pm.ell((-.2, 1.72, r * .97), (.11, .14, .06), '3B3552', 'glass', .8); pm.ell((-.2, 1.72, r * 1.0), (.08, .1, .03), 'FFD98A', 'emitn', .8)
        for k in range(4): pm.foliage((-r * .5 + k * r * .35, H, 0), .17, ('6FAA46', '97C95E', '4F8A38'), 3, 70 + k, .7)
        return FSpec(pm, (fx, 1), H + .3, 'floor', 'wardrobe', 'none', None, None, {'type': 'storage', 'anchor': [0, .8]})
    for sx in (-1, 1):
        for sz_ in (-1, 1): pm.box((sx * (W / 2 - .07), .06, sz_ * (D / 2 - .07)), (.12, .12, .12), S.dark, 'wood', .3)
    pm.box((0, H / 2 + .1, 0), (W, H - .2, D), S.body, S.btex, .22)
    pm.box((0, H - .02, 0), (W + .08, .1, D + .06), S.dark if S.t != 1 else S.trim, 'wood', .3)                 # crown
    pm.box((0, .17, D / 2 - .01), (W + .03, .14, .05), S.dark if S.t != 1 else S.trim, 'wood', .3)
    nd = 2 if fx == 2 else 1; dw = W / nd
    for i in range(nd):
        cx_ = -W / 2 + (i + .5) * dw
        pm.box((cx_, 1.12, D / 2 + .01), (dw - .08, 1.8, .03), S.body, S.btex, .3)
        pm.box((cx_, 1.12, D / 2 + .035), (dw - .2, 1.55, .02), S.light if S.t != 0 else S.w['light'], S.btex, .3)
        if S.t != 2: pm.box((cx_, 1.12, D / 2 + .05), (dw - .3, 1.42, .015), S.body, S.btex, .3)
        if S.t == 2: inlay_panel(pm, S, (cx_, 1.35, D / 2 + .045), (dw - .28, 1.0, .02))
        knob(pm, cx_ + (-1 if i == 0 and nd == 2 else 1) * (dw / 2 - .12) * (1 if nd == 2 else 1) * -1 if nd == 2 else cx_ + dw / 2 - .12, 1.1, D / 2 + .075, S, .035)
    pm.box((0, 1.12, D / 2 + .012), (.02, 1.8, .03), S.dark, 'wood', .3) if nd == 2 else None
    if S.t >= 2:
        for k in range(5): pm.ell((-W / 2 + .25 + k * (W - .5) / 4, H + .08, D / 2 - .02), (.08, .09, .035), S.acc, 'gold', .9, None, 10, 8)
        pm.ell((0, H + .12, D / 2 - .02), (.18, .15, .05), S.acc, 'gold', .9)
    glow = None
    if S.t == 4:
        crystal(pm, S, 0, 0, .45, .07, y0=H + .08); crystal(pm, S, -.25, 0, .3, .05, (0, 14), y0=H + .08); crystal(pm, S, .25, 0, .3, .05, (0, -14), y0=H + .08)
        pm.ell((0, 1.15, D / 2 + .06), (.05, .09, .02), 'FFF4B8', 'emit', .9)
        glow = glow_of(S, (0, H + .3, 0), 64, .45); floaters(pm, S, (0, H + .5, 0), (W * .35, .3, .2), 6, 31)
    return FSpec(pm, (fx, 1), H + .1, 'floor', 'wardrobe', 'none', glow, None, {'type': 'storage', 'anchor': [0, .8]})


BOOKCOLS = ['B8503A', '6F8FBF', '6F9A52', 'D8B25A', '8E3A55', 'E9DCC0', '9B86D6', 'E58FA6', '5E8F9A', 'C97A52']


def books_row(pm, x0, x1, y, z, depth, rng, h0=.28, hv=.1):
    x = x0
    while x < x1 - .06:
        w = rng.uniform(.04, .09); h = h0 + rng.uniform(-hv, hv); col = BOOKCOLS[rng.integers(len(BOOKCOLS))]
        tilt = rng.uniform(-10, 10) if rng.random() < .12 else 0
        if x + w > x1: break
        pm.box((x + w / 2, y + h / 2, z), (w, h, depth), col, 'weave', .3, rot=(0, 0, tilt))
        x += w + .004


def bookshelf(S, size='wide') -> FSpec:
    pm = HM(); fx = 2 if size == 'wide' else 1; W = fx * T - .14; D = .42; H = 2.0; rng = np.random.default_rng(7 + S.t)
    if S.t == 3:   # unique: tree-shaped shelf: trunk with branch-shelves and a leafy crown
        pm.lathe(0, 0, [(0, .3), (.06, .2), (.5, .16), (1, .12)], '8A6A42', 'bark2', 14, scale=H)
        for i, (y, a) in enumerate([(.5, 25), (.9, -30), (1.3, 40), (1.65, -20)]):
            ar = math.radians(a); L_ = .75 - i * .08
            pm.tube2(np.array([(0, y, 0), (math.sin(ar) * L_ * .5, y + .04, math.cos(ar) * L_ * .3), (math.sin(ar) * L_, y + .02, math.cos(ar) * L_ * .4)]), [.05, .04, .03], '8A6A42', 'bark2', 8)
            pm.box((math.sin(ar) * L_ * .9, y + .06, math.cos(ar) * L_ * .35), (.5, .04, .24), 'C9A66B', 'wood', .3, rot=(0, -a * .4, 0))
            books_row(pm, math.sin(ar) * L_ * .9 - .2, math.sin(ar) * L_ * .9 + .2, y + .08, math.cos(ar) * L_ * .35, .14, rng, .2, .05)
        pm.foliage((0, H + .15, 0), .5, ('6FAA46', '97C95E', '4F8A38'), 6, 77, .8)
        pm.foliage((.35, H - .05, .1), .3, ('6FAA46', '97C95E', '4F8A38'), 4, 78, .8)
        return FSpec(pm, (fx, 1), H + .6, 'floor', 'bookshelf', 'none', None, None, None)
    pm.box((0, H / 2, -D / 2 + .02), (W, H, .04), S.dark if S.t != 1 else S.body, S.btex, .3)               # back
    for sx in (-1, 1): pm.box((sx * (W / 2 - .03), H / 2, 0), (.06, H, D), S.body, S.btex, .26)
    ys = [.08, .55, 1.0, 1.45, 1.9]
    for y in ys: pm.box((0, y, 0), (W, .05, D), S.body, S.btex, .3)
    for i, y in enumerate(ys[:-1]):
        books_row(pm, -W / 2 + .06, W / 2 - .06, y + .03, 0, D - .1, rng, .3 if i % 2 == 0 else .26, .07)
        if i == 2 and S.t >= 1: pm.ell((-W / 2 + .2, y + .13, 0), (.1, .1, .1), '6FAA46', 'leaf', 1.0, None, 10, 8)
    pm.box((0, H + .02, 0), (W + .06, .06, D + .04), S.dark if S.t != 1 else S.trim, 'wood', .3)
    if S.t >= 2:
        for sx in (-1, 1): pm.ell((sx * (W / 2 - .03), H + .12, 0), (.06, .12, .06), S.acc, 'gold', .9)
        pm.box((0, H + .12, D / 2 - .02), (W - .2, .09, .03), S.acc, 'gold', .4)
        for k in range(int(W / .24)): pm.ell((-W / 2 + .2 + k * .24, H + .06, D / 2 - .01), (.05, .05, .02), S.acc, 'gold', .9, None, 10, 8)
        pm.box((0, .02, D / 2 - .02), (W, .07, .04), S.dark, 'wood', .3)
    glow = None
    if S.t == 4:
        pm.emit_ell((0, H + .35, 0), (.1, .1, .1), S.crys[1], 1.0, None, 12, 10)
        glow = glow_of(S, (0, 1.2, 0), 70, .4)
        old = pm.layer; pm.layer = 'float'
        for k in range(5):
            a = k * 1.25; pm.box((math.cos(a) * W * .38, H + .5 + .12 * math.sin(a * 2), math.sin(a) * .25 + .15), (.2, .26, .06), BOOKCOLS[k * 2 % 10], 'weave', .3, rot=(0, math.degrees(a), 12))
        pm.layer = old
        floaters(pm, S, (0, H + .5, .2), (W * .4, .3, .2), 5, 41)
    return FSpec(pm, (fx, 1), H + .12, 'floor', 'bookshelf', 'none', glow, None, None)


def rug(S, shape='rect') -> FSpec:
    pm = HM()
    fx, fz = {'rect': (3, 2), 'round': (2, 2), 'runner': (3, 1)}[shape]
    W = fx * T - .1; D = fz * T - .1; th = .035
    col = S.fab; tex = S.fab_tex
    if S.t == 0: tex = 'weave'
    if S.t == 1 and tex in ('weave', 'velvet'): tex = 'stripe'
    if S.t >= 2: tex = 'carpet'
    if shape == 'round' or S.t == 3:
        r = W / 2
        if S.t == 3:   # unique: flower-shaped rug with petals and a green centre / mossy
            for k in range(8):
                a = k * math.pi / 4
                pm.ell((math.cos(a) * r * .55, th, math.sin(a) * r * .55), (r * .5, th, r * .3), ('E58FA6', 'F4B6C8')[k % 2], 'velvet', 1.0, (0, -math.degrees(a), 0), 18, 8)
            pm.ell((0, th * 1.6, 0), (r * .42, th, r * .42), 'F2C14E', 'velvet', 1.0, None, 22, 8)
            for k in range(7): pm.ell((math.cos(k * .9) * r * .22, th * 2.4, math.sin(k * .9) * r * .22), (.05, .02, .05), 'E8A030', 'soft', 1.0, None, 8, 6)
            return FSpec(pm, (fx, fz), .06, 'rug', 'rug', 'c4', None, None, None)
        pm.ell((0, th, 0), (r, th, r), col, tex, 1.0, None, 36, 8)
        pm.ell((0, th * 1.5, 0), (r * .8, th * .7, r * .8), _mix(col, 'FBF5E6', .5), 'weave', 1.0, None, 36, 8)
        pm.ell((0, th * 2, 0), (r * .55, th * .6, r * .55), _mix(col, '2B2340', .1), tex if S.t >= 1 else 'weave', 1.0, None, 36, 8)
    else:
        pm.box((0, th, 0), (W, th * 2, D), col, tex, .35, L=max(W, D))
        pm.box((0, th * 1.6, 0), (W * .84, th * 1.2, D * .78), _mix(col, 'FBF5E6', .45) if S.t < 2 else _mix(col, '2B2340', .15), tex if S.t >= 1 else 'weave', .35, L=max(W, D) * .84)
        for sx in (-1, 1):
            for k in range(int(D / .13)): pm.box((sx * (W / 2 + .06), th, -D / 2 + .08 + k * .13), (.14, .012, .025), 'F4E6C4', 'weave', .5)   # fringe
    glow = None
    if S.t == 4:   # legendary: magic circle carpet
        r = min(W, D) * .42
        pm.ell((0, th * 3, 0), (r, .008, r), S.crys[1], 'emit', 1.0, None, 30, 6); pm.ell((0, th * 3.5, 0), (r * .86, .008, r * .86), S.crys[0], 'soft', 1.0, None, 30, 6)
        for k in range(8):
            a = k * math.pi / 4; pm.emit_ell((math.cos(a) * r * .93, th * 4, math.sin(a) * r * .93), (.06, .008, .06), 'FFF4B8', 1.0, None, 8, 6)
        glow = glow_of(S, (0, .05, 0), 80, .38); floaters(pm, S, (0, .55, 0), (r * .5, .35, r * .5), 6, 61)
    return FSpec(pm, (fx, fz), .06, 'rug', 'rug', 'c2', glow, None, None)


def floor_lamp(S) -> FSpec:
    pm = HM(); h = 1.65
    if S.t == 3:   # unique: giant glowing mushroom
        pm.lathe(0, 0, [(0, .16), (.1, .1), (.6, .07), (1, .08)], 'F4E6C4', 'soft', 14, scale=1.1)
        pm.ell((0, 1.18, 0), (.46, .24, .46), 'E58FA6', 'soft', .9, None, 26, 14)
        pm.ell((0, 1.1, 0), (.42, .08, .42), 'FFE7B0', 'emit', .9, None, 22, 8)
        for k in range(7):
            a = k * 2.4; pm.ell((math.cos(a) * .3, 1.28 + .05 * (k % 3), math.sin(a) * .3), (.07, .02, .07), 'FBF5E6', 'soft', 1.0, None, 10, 6)
        return FSpec(pm, (1, 1), 1.5, 'floor', 'lighting', 'c4', glow_of(S, (0, 1.05, 0), 70, .6, 'FFD98A'), None, None)
    wooden = S.t == 0 and S.wood != 'pine'          # tier 0: the default pine style is the wrought-iron lamp; any other `wood` key gives a turned-wood stand (birch = pale)
    base = S.metal if S.t >= 1 else ('4A3A4D' if not wooden else S.w['dark'])
    pm.ell((0, .03, 0), (.2, .035, .2), base, 'gold' if S.t >= 2 else ('wood' if wooden else 'soft'), 1.0, None, 18, 6)
    if S.t >= 2: pm.lathe(0, 0, [(0, .05), (.1, .03), (.3, .05), (.45, .028), (.7, .04), (1, .03)], S.metal, 'gold', 12, y0=.05, scale=h - .45)
    elif wooden: pm.lathe(0, 0, [(0, .045), (.12, .03), (.32, .042), (.46, .028), (.7, .036), (1, .03)], S.w['main'], 'wood', 12, y0=.05, scale=h - .45)
    else: pm.cyl2((0, .05, 0), (0, h - .35, 0), .028, .025, base, 'soft', 10, 3)
    sh_col = {0: 'F4E6C4', 1: S.paint or 'E8B04A', 2: S.fab, 4: 'DCE6FA'}.get(S.t, 'F4E6C4')
    sh_tex = 'weave' if S.t != 2 else 'damask'
    pm.lathe(0, 0, [(0, .3), (.45, .26), (1, .14)], sh_col, sh_tex, 22, y0=h - .45, scale=.5)
    pm.ell((0, h - .24, 0), (.2, .12, .2), 'FFE7B0', 'emit', .9, None, 16, 10)
    if S.t >= 2:
        for k in range(10):
            a = k * 6.28 / 10; pm.ell((math.cos(a) * .29, h - .47, math.sin(a) * .29), (.015, .05, .015), S.acc, 'gold', 1.0, None, 8, 6)
    glow = glow_of(S, (0, h - .25, 0), 66 if S.t != 4 else 80, .6, 'FFD98A' if S.t != 4 else S.glow_col)
    if S.t == 4:
        floaters(pm, S, (0, h + .25, 0), (.3, .2, .3), 5, 71)
    return FSpec(pm, (1, 1), h + .2, 'floor', 'lighting', 'c4', glow, None, None)


def fireplace(S) -> FSpec:
    pm = HM(); fx = 2; W = fx * T - .1; D = .72; H = 2.15
    stone = S.stone if S.t != 1 else (S.paint or 'FBF5E6'); stex = S.stone_tex if S.t != 1 else 'painted'      # tiers 0 and 2 follow the `stone` style key (marble = F0EAE0 marble, slate = 6E7A98 slabs)
    if S.t >= 3: stone, stex = ('9A9AA6', 'blocks') if S.t == 3 else ('F7F0E2', 'marble')
    # surround
    for sx in (-1, 1): pm.box((sx * (W / 2 - .24), .8, 0), (.48, 1.6, D), stone, stex, .22)
    pm.box((0, 1.55, 0), (W, .3, D), stone, stex, .22)
    pm.box((0, 1.78, .02), (W + .16, .1, D + .1), S.w['dark'] if S.t != 1 else 'FBF5E6', 'wood', .3)       # mantel
    pm.box((0, H / 2 + .88, -.05), (W - .5, H - 1.75, D - .1), stone, stex, .2)                              # chimney breast
    pm.box((0, .06, .1), (W + .1, .12, D + .22), '9A94A4', 'blocks', .28)                                   # hearth slab
    pm.box((0, .7, -D / 2 + .06), (W - .9, 1.3, .1), '2B2340', 'soft', .2)                                  # back of the firebox
    # logs + fire
    for k, (x_, y_, r_) in enumerate([(-.3, .14, .07), (.0, .18, .08), (.28, .14, .07)]):
        pm.log((x_, y_, -.08), (x_ + .08 * (k - 1), y_, .22), r_, r_ * .9, '6B4126', 'bark2', 10, 2)
    fc = ('FFB347', 'FFD98A', 'FF8A3C') if S.t != 4 else ('BFE6FF', 'FFFFFF', '8FA9F2')
    for k, (x_, h_, w_) in enumerate([(-.22, .55, .17), (0, .8, .22), (.22, .5, .15), (.05, .4, .12)]):
        old = pm.layer
        pm.lathe(x_, .04 + .03 * k, [(0, w_ * .75), (.18, w_ * 1.0), (.5, w_ * .7), (.8, w_ * .32), (1, .01)], fc[k % 3], 'emit', 12, y0=.24, scale=h_)
    if S.t == 3:   # unique: cauldron hearth with green brew
        pm.ell((0, .72, .02), (.36, .26, .34), '3A3445', 'soft', .8, None, 20, 12)
        pm.ell((0, .92, .02), (.31, .04, .29), '6FE090', 'emit', 1.0, None, 20, 6)
        for k in range(4): pm.emit_ell((math.cos(k * 1.6) * .14, 1.02 + .05 * k, math.sin(k * 1.6) * .12), (.045, .045, .045), '9BFFB5', 1.0, None, 8, 6)
        pm.cyl2((-.34, 1.25, .0), (.34, 1.25, .0), .02, .02, '3A3445', 'soft', 6, 2)
    if S.t >= 2:
        for sx in (-1, 1): pm.ell((sx * (W / 2 - .24), 1.72, D / 2 + .02), (.1, .08, .06), S.acc, 'gold', .9)
        pm.box((0, 1.5, D / 2 + .01), (W - .8, .08, .03), S.acc, 'gold', .3)
    if S.t == 1:
        for k in range(3): pm.ell((-.35 + k * .35, 1.96, .02), (.07, .12, .07), ('E58FA6', 'F2C14E', '9B86D6')[k], 'soft', .9)
    glow = glow_of(S, (0, .5, .2), 90, .55 if S.t != 4 else .5, 'FFB347' if S.t != 4 else 'BFE6FF')
    if S.t == 4: floaters(pm, S, (0, 1.1, .1), (.35, .35, .15), 6, 81, col='BFE6FF')
    return FSpec(pm, (fx, 1), H, 'floor', 'fireplace', 'none', glow, None, {'type': 'warm', 'anchor': [0, 1.0]})


def chest(S) -> FSpec:
    pm = HM(); W = .86; D = .56
    if S.t == 3:   # unique: giant snail-shell chest
        pm.ell((0, .22, .0), (.45, .2, .3), '9BC27A', 'soft', .9, None, 22, 12)
        pm.ell((.12, .46, -.06), (.3, .3, .24), 'D6B27A', 'plank_v', .95, (0, 0, 0), 22, 14)
        for k in range(3): pm.ell((.12, .46, -.06 + .0), (.3 - k * .08, .3 - k * .08, .245), ('E8B04A', 'C9884A', 'E8B04A')[k], 'soft', 1.0, None, 20, 12) if False else None
        pm.ell((.12, .44, .0), (.06, .06, .26), 'C9884A', 'soft', 1.0, None, 10, 8)
        pm.box((.14, .22, .18), (.42, .3, .2), '6B4126', 'wood', .3)
        pm.ell((-.44, .3, .22), (.07, .12, .05), '9BC27A', 'soft', .9); pm.ell((-.38, .3, .26), (.06, .11, .05), '9BC27A', 'soft', .9)
        pm.ell((-.44, .43, .22), (.03, .03, .03), '2B2340', 'soft'); pm.ell((-.38, .42, .26), (.03, .03, .03), '2B2340', 'soft')
        return FSpec(pm, (1, 1), .8, 'floor', 'chest', 'none', None, None, {'type': 'storage', 'anchor': [0, 1.0]})
    pm.box((0, .27, 0), (W, .5, D), S.body, S.btex, .26)
    pm.ell((0, .54, 0), (W / 2, .2, D / 2), S.body, S.btex, .72, None, 26, 14)                               # curved lid
    band = S.metal if S.t >= 1 else '5B4A6E'
    for x_ in (-.3, .3):
        pm.box((x_, .27, 0), (.07, .52, D + .02), band, 'soft' if S.t < 2 else 'gold', .3)
        pm.ell((x_, .54, 0), (.036, .205, D / 2 + .02), band, 'soft' if S.t < 2 else 'gold', .72, None, 12, 12)
    pm.box((0, .42, D / 2 + .01), (.12, .15, .04), S.metal if S.t >= 1 else 'E9C06B', 'gold', .4)
    for sx in (-1, 1):
        for sz_ in (-1, 1): pm.box((sx * (W / 2 - .04), .03, sz_ * (D / 2 - .04)), (.08, .06, .08), S.dark, 'wood', .4)
    if S.t == 2: inlay_panel(pm, S, (0, .24, D / 2 + .01), (.4, .26, .02)); [pm.ell((sx * (W / 2 - .02), .5, D / 2), (.02, .02, .02), S.acc, 'gold', 1.0, None, 8, 6) for sx in (-1, 1)]
    glow = None
    if S.t == 4:
        pm.box((0, .66, 0), (.7, .03, D * .8), S.crys[1], 'emit', .3) if False else None
        pm.ell((0, .6, 0), (.3, .035, .16), 'FFE49A', 'emit', 1.0, None, 14, 6)
        pm.ell((0, .42, D / 2 + .03), (.05, .07, .02), 'FFF4B8', 'emit', 1.0)
        crystal(pm, S, -.25, 0, .3, .04, (0, 14), y0=.62); crystal(pm, S, .25, 0, .26, .04, (0, -14), y0=.62)
        glow = glow_of(S, (0, .6, 0), 54, .45); floaters(pm, S, (0, .95, 0), (.3, .22, .2), 6, 91, col='FFE49A')
    return FSpec(pm, (1, 1), .85, 'floor', 'chest', 'none', glow, None, {'type': 'storage', 'anchor': [0, 1.0]})


def plant(S, kind='fern') -> FSpec:
    pm = HM(); G = ('6FAA46', '97C95E', '4F8A38')
    if S.t == 3:   # unique: bonsai in a teapot
        pm.lathe(0, 0, [(0, .16), (.15, .24), (.55, .25), (.85, .15), (1, .1)], 'FBF5E6', 'soft', 18, scale=.34)
        pm.curve([(.28, .22, 0), (.42, .26, 0), (.4, .14, 0), (.32, .1, 0)], .04, .03, 'FBF5E6', 'soft', 10, 10) if False else None
        pm.tube2(np.array([(-.3, .2, 0), (-.42, .27, 0), (-.34, .34, 0)]), [.035, .03, .045], 'FBF5E6', 'soft', 8)
        pm.ell((0, .36, 0), (.1, .03, .1), 'FBF5E6', 'soft', 1.0, None, 14, 6)
        pm.tube2(np.array([(0, .35, 0), (.05, .55, .02), (-.1, .72, 0), (.08, .9, -.02)]), [.05, .04, .035, .025], '8A6A42', 'bark2', 8)
        for p_, r_ in (((.14, .95, 0), .2), ((-.2, .78, .02), .17), ((.1, 1.12, .04), .15)): pm.foliage(p_, r_, G, 4, int(r_ * 100), .75)
        return FSpec(pm, (1, 1), 1.3, 'floor', 'plant', 'c4', None, None, None)
    pot = {0: 'C97A52', 1: S.paint or 'E58FA6', 2: '6F8FBF', 4: 'DCE6FA'}[S.t]
    pm.lathe(0, 0, [(0, .15), (.08, .2), (.7, .27), (.9, .3), (1, .31)], pot, 'painted' if S.t else 'soft', 20, scale=.62)
    pm.ell((0, .43, 0), (.3, .035, .3), _mix(pot, 'FFFFFF', .2) if S.t < 2 else S.acc, 'gold' if S.t >= 2 else 'soft', 1.0, None, 20, 6)
    pm.ell((0, .42, 0), (.26, .02, .26), '5E3F2A', 'soil', 1.0, None, 16, 6)
    n = 5 if S.t < 2 else 7; rng = np.random.default_rng(5)
    for k in range(n):
        a = k * 6.28 / n + .3; r_ = .26 + .06 * (k % 2)
        pm.foliage((math.cos(a) * r_ * .5, .8 + .22 * (k % 3), math.sin(a) * r_ * .5), .2 + .03 * (k % 2), G, 4, 40 + k, .8)
    if S.t >= 1:
        for k in range(6 + 3 * S.t):
            a = rng.uniform(0, 6.28); e = rng.uniform(.4, 1.0)
            pm.ell((math.cos(a) * .34 * e, .75 + .45 * rng.random() + .15, math.sin(a) * .34 * e + .05), (.055, .055, .055), ('E58FA6', 'FBEAC8', 'F2C14E', 'D9C8F4')[k % 4], 'soft', 1.0, None, 8, 6)
    glow = None
    if S.t == 4:
        pm.curve([(0, .4, 0), (.05, .8, 0), (-.04, 1.2, 0), (0, 1.5, 0)], .04, .03, '5C9A52', 'soft', 8, 10)
        for k in range(8):
            a = k * .785; pm.emit_ell((math.cos(a) * .18, 1.52, math.sin(a) * .18), (.13, .03, .07), 'E8F0FF', .9, (0, -math.degrees(a), 0), 12, 8)
        pm.emit_ell((0, 1.54, 0), (.08, .06, .08), 'FFE49A', 1.0)
        glow = glow_of(S, (0, 1.5, 0), 58, .6, 'CFE0FF'); floaters(pm, S, (0, 1.3, 0), (.35, .3, .35), 6, 99, col='FFE49A')
    return FSpec(pm, (1, 1), 1.5 if S.t != 4 else 1.7, 'floor', 'plant', 'c4', glow, None, None)


def clock(S) -> FSpec:
    pm = HM(); W = .66; D = .4; H = 2.1
    if S.t == 3:   # unique: owl clock (tall owl-shaped case with big eyes)
        pm.ell((0, 1.0, 0), (.38, 1.0, .26), '9A7A5A', 'bark2', .85, None, 26, 16)
        pm.ell((0, 1.45, .12), (.3, .3, .2), 'D9C3A2', 'soft', .9, None, 22, 12)
        for sx in (-1, 1):
            pm.ell((sx * .15, 1.52, .24), (.13, .13, .04), 'FFF9EB', 'soft', 1.0, None, 16, 10); pm.ell((sx * .15, 1.52, .27), (.07, .07, .03), '2B2340', 'soft', 1.0, None, 12, 8)
        pm.ell((0, 1.38, .3), (.05, .07, .05), 'F0B05A', 'soft', .9)
        pm.ell((0, .9, .2), (.17, .5, .08), 'EBD9BA', 'soft', .9, None, 16, 12)
        pm.ell((0, 1.07, .26), (.12, .12, .03), 'FBF5E6', 'soft', 1.0, None, 16, 8); pm.box((0, 1.1, .29), (.02, .08, .01), '2B2340', 'soft', .3)
        for sx in (-1, 1): pm.ell((sx * .2, 1.92, 0), (.07, .16, .06), '9A7A5A', 'bark2', .8, (0, 0, sx * 18), 10, 8)
        for sx in (-1, 1): pm.ell((sx * .12, .06, .15), (.1, .05, .12), 'F0B05A', 'soft', .9)
        return FSpec(pm, (1, 1), 2.15, 'floor', 'clock', 'none', None, None, None)
    pm.box((0, .1, 0), (W + .08, .2, D + .06), S.dark if S.t != 1 else S.body, S.btex, .3)
    pm.box((0, 1.0, 0), (W - .12, 1.7, D - .08), S.body, S.btex, .24)
    pm.box((0, 1.0, D / 2 - .03), (W - .26, 1.2, .05), S.dark, 'wood', .3)
    pm.box((0, 1.0, D / 2 - .0), (W - .38, 1.05, .03), '9AC9D8' if S.t != 4 else 'C9D8F6', 'glass', .3)
    pm.cyl2((0, 1.5, D / 2 - .04), (0, .75, D / 2 - .04), .012, .012, S.metal, 'gold', 6, 2); pm.ell((0, .72, D / 2 - .04), (.1, .1, .02), S.metal, 'gold', 1.0, None, 14, 8)
    pm.box((0, 1.95, 0), (W + .06, .45, D + .02), S.body, S.btex, .26)
    pm.ell((0, 1.92, D / 2 + .0), (.25, .25, .04), S.metal if S.t >= 1 else S.dark, 'gold' if S.t >= 1 else 'wood', 1.0, None, 22, 10)
    pm.ell((0, 1.92, D / 2 + .025), (.21, .21, .03), 'FBF5E6', 'soft', 1.0, None, 22, 10)
    pm.box((0, 1.96, D / 2 + .05), (.018, .13, .01), '2B2340', 'soft', .3); pm.box((.05, 1.92, D / 2 + .05), (.1, .018, .01), '2B2340', 'soft', .3, rot=(0, 0, 30))
    pm.box((0, 2.22, 0), (W + .12, .08, D + .08), S.dark if S.t != 1 else S.trim, 'wood', .3)
    if S.t >= 2:
        pm.ell((0, 2.34, 0), (.1, .1, .07), S.acc, 'gold', .9); pm.ell((-W / 2 - .0, 2.24, D / 2), (.05, .1, .05), S.acc, 'gold') ; pm.ell((W / 2, 2.24, D / 2), (.05, .1, .05), S.acc, 'gold')
    glow = None
    if S.t == 4:
        pm.ell((0, 1.92, D / 2 + .035), (.16, .16, .02), 'EAF3FF', 'emit', 1.0, None, 18, 8); pm.ell((0, .72, D / 2 - .02), (.09, .09, .02), 'FFF4B8', 'emit', 1.0, None, 12, 8)
        glow = glow_of(S, (0, 1.9, .2), 60, .45); floaters(pm, S, (0, 2.45, 0), (.3, .25, .15), 5, 105)
    return FSpec(pm, (1, 1), 2.4, 'floor', 'clock', 'none', glow, None, None)


def throne(S) -> FSpec:
    pm = HM(); W = .86; D = .8; H = 2.2
    if S.t == 3:   # unique: throne grown from living roots
        for k in range(7):
            a = -1.2 + k * .4; x_ = math.sin(a) * .42; z_ = -.12 - .2 * math.cos(a)
            pm.tube2(np.array([(x_ * 1.15, 0, z_ * 1.3), (x_, .7 + .15 * (k % 2), z_), (x_ * .8, 1.6 + .2 * math.cos(k), z_ * .9 - .08), (x_ * .5, 2.1 + .1 * (k % 3), z_ * .8 - .1)]), [.09, .075, .06, .03], '8A6A42', 'bark2', 8)
        pm.ell((0, .5, .0), (.42, .08, .4), '8A6A42', 'bark2', .9, None, 22, 10); pm.ell((0, .62, .0), (.36, .1, .34), S.fab, S.fab_tex, .9, None, 18, 10)
        for sx in (-1, 1): pm.tube2(np.array([(sx * .45, .1, .1), (sx * .5, .55, .1), (sx * .44, .82, .05)]), [.07, .06, .05], '8A6A42', 'bark2', 8)
        pm.foliage((0, 2.1, -.28), .28, ('6FAA46', '97C95E', '4F8A38'), 5, 103, .8)
        for k in range(6): pm.ell((math.cos(k * 1.1) * .25, 2.12 + .08 * (k % 2), -.28 + math.sin(k * 1.1) * .15), (.05, .05, .05), 'E58FA6', 'soft', 1.0, None, 8, 6)
        return FSpec(pm, (1, 1), 2.4, 'floor', 'throne', 'none', None, None, {'type': 'sit', 'anchor': [0, 0], 'from': [0, 1]})
    pm.box((0, .22, 0), (W, .4, D), S.body, S.btex, .26)
    pm.box((0, .5, .06), (W - .12, .18, D - .2), S.fab, S.fab_tex, .6)
    pm.box((0, 1.2, -D / 2 + .08), (W - .04, 2.0, .14), S.body, S.btex, .24)
    pm.box((0, 1.2, -D / 2 + .16), (W - .26, 1.7, .05), S.fab, S.fab_tex, .5)
    for sx in (-1, 1):
        pm.box((sx * (W / 2 - .06), .72, .0), (.12, .36, D - .14), S.body, S.btex, .3); pm.box((sx * (W / 2 - .06), .96, .0), (.16, .08, D - .04), S.dark, 'wood', .3)
        pm.ell((sx * (W / 2 - .06), 1.04, D / 2 - .02), (.07, .07, .07), S.metal, 'gold' if S.t else 'soft', 1.0, None, 10, 8)
        pm.cyl2((sx * (W / 2 - .02), 2.1, -D / 2 + .08), (sx * (W / 2 - .02), 2.34, -D / 2 + .08), .05, .02, S.metal, 'gold', 8, 2)
    pm.ell((0, 2.34, -D / 2 + .1), (.34, .26, .06), S.metal if S.t else S.dark, 'gold' if S.t else 'wood', .9, None, 20, 10)
    if S.t >= 2:
        pm.ell((0, 2.38, -D / 2 + .15), (.1, .1, .03), 'B3436B', 'soft', 1.0, None, 12, 8)
        for k in range(5): pm.ell((-.28 + k * .14, 2.62 - .16 * (k % 2 == 0) - .0, -D / 2 + .1), (.05, .1, .05), S.acc, 'gold', .9, None, 8, 8) if False else None
        for k in range(3): pm.ell((0 + (k - 1) * .2, 2.62 - (k != 1) * .1, -D / 2 + .1), (.04, .09, .03), S.acc, 'gold', .9)
    glow = None
    if S.t == 4:
        for k, (x_, h_, tl) in enumerate([(-.22, .5, 14), (0, .72, 0), (.22, .5, -14), (-.4, .34, 24), (.4, .34, -24)]):
            crystal(pm, S, x_, -D / 2 + .08, h_, .06, (0, tl), y0=2.15)
        glow = glow_of(S, (0, 2.3, -.2), 80, .5); floaters(pm, S, (0, 2.0, 0), (.5, .5, .3), 8, 111)
    return FSpec(pm, (1, 1), 2.9 if S.t == 4 else 2.7, 'floor', 'throne', 'none', glow, None, {'type': 'sit', 'anchor': [0, 0], 'from': [0, 1]})


def piano(S) -> FSpec:
    pm = HM(); fx = 2; W = fx * T - .14; D = .62; H = 1.3
    pm.box((0, H / 2 + .08, -.05), (W, H - .1, D - .1), S.body if S.t != 0 else S.dark, S.btex, .24)
    pm.box((0, H + .04, -.05), (W + .06, .06, D), S.dark if S.t != 1 else S.trim, 'wood', .3)
    pm.box((0, .74, D / 2 - .06), (W - .08, .09, .36), S.body, S.btex, .3)                                     # key bed
    nk = int((W - .22) / .075)
    for k in range(nk):
        x_ = -(nk - 1) / 2 * .075 + k * .075
        pm.box((x_, .81, D / 2 - .02), (.068, .035, .3), 'FBF5E6', 'soft', .4)
    for k in range(nk - 1):
        if k % 7 in (2, 6): continue
        x_ = -(nk - 1) / 2 * .075 + k * .075 + .0375
        pm.box((x_, .845, D / 2 - .06), (.04, .04, .18), '2B2340', 'soft', .4)
    pm.box((0, 1.0, -.08), (W - .5, .52, .04), S.dark, 'wood', .3)                                              # music stand
    pm.box((0, 1.1, -.0), (.5, .3, .02), 'F4EAD0', 'weave', .4, rot=(-12, 0, 0))
    for sx in (-1, 1): pm.box((sx * (W / 2 - .05), .35, -.05), (.1, .7, D - .14), S.dark if S.t != 1 else S.body, S.btex, .3)
    for sx in (-1, 1):
        for sz_ in (-1, 1): pm.box((sx * (W / 2 - .08), .04, sz_ * (D / 2 - .12) - .05), (.1, .08, .1), S.dark, 'wood', .3)
    pm.cyl2((.0, 0, D / 2 + .32), (.0, .5, D / 2 + .32), .1, .09, S.dark, 'wood', 12, 2)                       # stool
    pm.ell((0, .52, D / 2 + .32), (.22, .06, .22), S.fab, S.fab_tex, .8, None, 16, 8)
    if S.t >= 2:
        for sx in (-1, 1): pm.ell((sx * (W / 2 - .15), .32, D / 2 - .0), (.07, .12, .05), S.acc, 'gold', .9)
        pm.box((0, 1.34, -.05), (W - .1, .035, D - .1), S.acc, 'gold', .3)
        inlay_panel(pm, S, (0, 1.0 - .22, D / 2 - .1 + .0), (.5, .0001, .02)) if False else None
    if S.t == 3:   # unique: toadstool piano — mushroom cap lid
        pm.ell((0, H + .35, -.05), (W / 2 + .1, .3, D / 2 + .12), 'E58FA6', 'soft', .9, None, 28, 14)
        for k in range(7): pm.ell((math.cos(k * 1.2) * W * .34, H + .55 + .03 * (k % 2), -.05 + math.sin(k * 1.2) * .16), (.09, .03, .09), 'FBF5E6', 'soft', 1.0, None, 10, 6)
    glow = None
    if S.t == 4:
        for k in range(nk): pm.box((-(nk - 1) / 2 * .075 + k * .075, .83, D / 2 - .02), (.05, .008, .28), S.crys[1], 'emit', .4) if k % 2 == 0 else None
        glow = glow_of(S, (0, .9, D / 2), 64, .42); floaters(pm, S, (0, H + .4, 0), (W * .35, .3, .2), 7, 121, stars=True)
    return FSpec(pm, (fx, 1), H + (.8 if S.t == 3 else .1), 'floor', 'piano', 'none', glow, None, {'type': 'play', 'anchor': [0, 1.0]})


# ---------------------------------------------------------------------------------------------------------------------------------
# wall-mounted (origin on the wall plane, centre of the item; the back of the item touches z = 0, items project towards +z)
# ---------------------------------------------------------------------------------------------------------------------------------
def painting(S, size='small') -> FSpec:
    pm = HM(); fx = 1 if size == 'small' else 2; W = fx * T - .22 if fx == 1 else 1.62; H = .78 if fx == 1 else .92; y0 = 1.25 + H / 2; d = .06
    pic = {0: 'C9A66B', 1: S.paint or '8DB86A', 2: 'B88A52', 3: '6FAA46', 4: 'A57BE0'}[S.t]
    if S.t == 3:   # unique: round porthole portrait in a leaf wreath
        r = .5
        pm.ell((0, y0, d), (r, r, .05), '8A6A42', 'wood', 1.0, None, 28, 8)
        pm.ell((0, y0, d + .03), (r * .86, r * .86, .03), pic, 'scene@1.0', 1.0, None, 28, 8)
        for k in range(14):
            a = k * 6.28 / 14; pm.ell((math.cos(a) * r * .98, y0 + math.sin(a) * r * .98, d + .04), (.1, .05, .03), ('6FAA46', '97C95E', '4F8A38')[k % 3], 'leaf', .9, (0, 0, math.degrees(a) + 90), 10, 8)
        return FSpec(pm, (fx, 1), y0 + r, 'wall', 'painting', 'wall2', None, None, None, hang=y0 - r)
    fr = S.w['dark'] if S.t == 0 else (S.paint or S.trim) if S.t == 1 else S.acc
    pm.box((0, y0, d / 2), (W + .12, H + .12, d), fr, 'gold' if S.t >= 2 else 'wood', .3)
    if S.t == 1: pm.box((0, y0, d + .005), (W + .02, H + .02, .02), 'FBF5E6', 'soft', .3)
    pm.box((0, y0, d + .02), (W - .08, H - .08, .03), pic, f'scene@{max(W, H):.2f}', .2, L=max(W, H))
    if S.t >= 2:
        for sx in (-1, 1):
            for sy in (-1, 1): pm.ell((sx * (W / 2 + .05), y0 + sy * (H / 2 + .05), d + .02), (.07, .07, .04), S.acc, 'gold', .9)
    glow = None
    if S.t == 4:
        pm.box((0, y0, d + .045), (W - .16, H - .16, .01), 'FFF0C8', 'emit', .2)
        glow = glow_of(S, (0, y0, d + .1), 60, .35); floaters(pm, S, (0, y0, d + .3), (W * .4, H * .4, .08), 6, 131)
    return FSpec(pm, (fx, 1), y0 + H / 2 + .2, 'wall', 'painting', 'wall2', glow, None, None, hang=y0 - H / 2 - .06)


def shelf(S) -> FSpec:
    pm = HM(); W = T - .16; y0 = 1.55; d = .3
    pm.box((0, y0, d / 2), (W, .05, d), S.body, S.btex, .3)
    for sx in (-1, 1): pm.box((sx * (W / 2 - .08), y0 - .12, .04), (.04, .22, .06), S.dark, 'wood', .3)
    rng = np.random.default_rng(9 + S.t)
    books_row(pm, -W / 2 + .06, -.04, y0 + .025, .12, .16, rng, .22, .05)
    pm.cyl2((.22, y0 + .02, .15), (.22, y0 + .16, .15), .06, .045, 'C97A52' if S.t == 0 else (S.paint or '6F8FBF'), 'soft', 12, 3)
    pm.foliage((.22, y0 + .26, .15), .1, ('6FAA46', '97C95E', '4F8A38'), 3, 4, .8)
    if S.t >= 2:
        pm.ell((0, y0 - .03, d - .02), (W / 2, .04, .02), S.acc, 'gold', .9)
        for k in range(4): pm.ell((-W / 2 + .1 + k * (W - .2) / 3, y0 - .06, d - .03), (.03, .04, .02), S.acc, 'gold', .9, None, 8, 6)
    if S.t == 3:   # unique: birdhouse shelf
        pm.box((0, y0 + .24, d * .5), (.3, .28, .22), 'E8B04A', 'plank_v', .3); pm.gable(-.2, .2, .1, .32, y0 + .38, 35, 'x', .06, .04, 'B5693F', 'shingle', 'E8B04A', 'plank_v', ends=True) if False else pm.ell((0, y0 + .46, d * .5), (.24, .12, .18), 'B5693F', 'shingle', .8)
        pm.ell((0, y0 + .24, d * .5 + .12), (.06, .06, .03), '2B2340', 'soft', 1.0, None, 10, 8)
    glow = None
    if S.t == 4:
        pm.emit_ell((-.05, y0 + .16, .15), (.07, .07, .07), S.crys[1], 1.0, None, 10, 8); glow = glow_of(S, (-.05, y0 + .16, .15), 40, .5)
        floaters(pm, S, (0, y0 + .4, .15), (.28, .15, .08), 4, 141)
    return FSpec(pm, (1, 1), y0 + .7, 'wall', 'shelf', 'wall2', glow, {'height': y0 + .05, 'slots': [[0, 0.0]]} if False else None, None, hang=y0 - .2)


def curtain(S) -> FSpec:
    pm = HM(); W = T - .12; y0 = 1.05; H = 1.55; d = .1
    pm.cyl2((-W / 2 - .05, y0 + H, d), (W / 2 + .05, y0 + H, d), .02, .02, S.metal if S.t else S.dark, 'gold' if S.t >= 2 else 'wood', 8, 2)
    for sx in (-1, 1): pm.ell((sx * (W / 2 + .06), y0 + H, d), (.04, .04, .04), S.metal if S.t else S.dark, 'gold' if S.t >= 2 else 'wood')
    col = S.fab; tex = S.fab_tex if S.t >= 1 else 'weave'                                                  # tier 0 = plain woven cloth in the colour of the `fabric` key
    if S.t == 3: col, tex = '6FAA46', 'leaf'
    for sx in (-1, 1):
        for k in range(3):
            x_ = sx * (W / 2 - .09 - k * .09 + .02 * 0)
            pm.ell((sx * (W / 2 - .1 - k * .1), y0 + H * .5 - .02 * k, d + .02 * k), (.07, H / 2 - .05 * k * 0, .05), _mix(col, '2B2340', .06 * (k % 2)), tex, .85, None, 12, 12) if False else \
                pm.box((sx * (W / 2 - .1 - k * .1), y0 + H / 2 - .02, d + .01 * k), (.1, H, .05), _mix(col, '2B2340', .07 * (k % 2)), tex, .6)
        pm.ell((sx * (W / 2 - .1), y0 + H * .42, d + .04), (.09, .03, .05), S.acc if S.t >= 2 else 'F4E6C4', 'gold' if S.t >= 2 else 'weave', .9)
    pm.ell((0, y0 + H - .12, d + .03), (W / 2, .1, .05), col, tex, .8)
    glow = None
    if S.t == 4:
        for k in range(10): pm.emit_ell((-.35 + (k % 5) * .17, y0 + H * .3 + (k // 5) * .35, d + .08), (.03, .03, .03), 'FFF4B8', 1.0, None, 8, 6)
        glow = glow_of(S, (0, y0 + H / 2, d + .1), 50, .3)
    return FSpec(pm, (1, 1), y0 + H + .1, 'wall', 'curtain', 'wall2', glow, None, None, hang=y0)


def sconce(S) -> FSpec:
    pm = HM(); y0 = 1.75
    pm.box((0, y0, .03), (.12, .28, .05), S.metal if S.t else '4A3A4D', 'gold' if S.t >= 2 else 'soft', .3)
    pm.tube2(np.array([(0, y0 - .05, .05), (0, y0 - .05, .2), (0, y0 + .02, .26)]), [.02, .02, .02], S.metal if S.t else '4A3A4D', 'gold' if S.t >= 2 else 'soft', 8)
    pm.cyl2((0, y0 + .0, .27), (0, y0 + .1, .27), .045, .04, 'F4E6C4', 'weave', 10, 2)
    pm.emit_ell((0, y0 + .15, .27), (.04, .07, .04), 'FFD98A' if S.t != 4 else S.glow_col, 1.0, None, 10, 8)
    if S.t == 3: pm.ell((0, y0 + .02, .27), (.12, .12, .06), '6FD6C4', 'emit', .8, None, 12, 8)
    glow = glow_of(S, (0, y0 + .15, .27), 46 if S.t != 4 else 60, .6, 'FFD98A' if S.t != 4 else S.glow_col)
    if S.t == 4: floaters(pm, S, (0, y0 + .3, .3), (.15, .1, .1), 3, 151)
    return FSpec(pm, (1, 1), y0 + .5, 'wall', 'lighting', 'wall2', glow, None, None, hang=y0 - .15)


# ---------------------------------------------------------------------------------------------------------------------------------
# tabletop + ceiling
# ---------------------------------------------------------------------------------------------------------------------------------
def vase(S) -> FSpec:
    pm = HM(); col = {0: 'C97A52', 1: S.paint or 'E58FA6', 2: '6F8FBF', 3: 'F4E6C4', 4: 'DCE6FA'}[S.t]
    pm.lathe(0, 0, [(0, .08), (.1, .13), (.45, .16), (.75, .08), (.9, .06), (1, .09)], col, 'painted' if S.t else 'soft', 16, scale=.34)
    if S.t >= 2: pm.ell((0, .34, 0), (.1, .02, .1), S.acc, 'gold', 1.0, None, 14, 6)
    G = ('6FAA46', '97C95E', '4F8A38')
    if S.t == 3:
        for k in range(3): pm.cyl2((k * .04 - .04, .33, 0), (k * .08 - .08, .55, 0), .008, .008, '6B8A3A', 'soft', 5, 2); pm.ell((k * .08 - .08, .58, 0), (.045, .045, .045), 'F2C14E', 'soft')
    else:
        pm.foliage((0, .42, 0), .12, G, 3, 8, .8)
        for k in range(3 + S.t): pm.ell((math.cos(k * 2) * .09, .46 + .05 * k % 3, math.sin(k * 2) * .09), (.04, .04, .04), ('E58FA6', 'FBEAC8', 'F2C14E', 'D9C8F4')[k % 4], 'soft')
    glow = None
    if S.t == 4: pm.emit_ell((0, .62, 0), (.08, .08, .08), 'FFF4B8'); glow = glow_of(S, (0, .6, 0), 30, .45); floaters(pm, S, (0, .75, 0), (.12, .12, .12), 3, 161)
    return FSpec(pm, (1, 1), .7, 'tabletop', 'decor', 'c4', glow, None, None)


def table_lamp(S) -> FSpec:
    pm = HM(); base = {0: 'C97A52', 1: S.paint or 'A9D3E0', 2: S.metal, 3: 'F4E6C4', 4: 'DCE6FA'}[S.t]
    pm.lathe(0, 0, [(0, .1), (.1, .13), (.4, .08), (.8, .05), (1, .04)], base, 'gold' if S.t == 2 else 'painted', 14, scale=.3)
    sh = {0: 'F4E6C4', 1: 'FBF5E6', 2: S.fab, 3: 'E58FA6', 4: 'DCE6FA'}[S.t]
    pm.lathe(0, 0, [(0, .17), (.5, .14), (1, .08)], sh, 'weave' if S.t != 2 else 'damask', 18, y0=.28, scale=.22)
    pm.emit_ell((0, .38, 0), (.07, .07, .07), 'FFE7B0', 1.0, None, 10, 8)
    if S.t == 3: pm.ell((0, .32, 0), (.2, .12, .2), 'E58FA6', 'soft', .9, None, 16, 10); pm.emit_ell((0, .28, 0), (.17, .04, .17), 'FFE7B0', .9, None, 14, 6)
    glow = glow_of(S, (0, .38, 0), 46 if S.t != 4 else 58, .6 if S.t != 4 else .7, 'FFD98A' if S.t != 4 else S.glow_col)
    if S.t == 4: floaters(pm, S, (0, .6, 0), (.15, .12, .15), 3, 171)
    return FSpec(pm, (1, 1), .6, 'tabletop', 'lighting', 'c4', glow, None, None)


def candelabra(S) -> FSpec:
    pm = HM(); m = S.metal if S.t else '4A3A4D'; tx = 'gold' if S.t >= 2 else 'soft'
    pm.lathe(0, 0, [(0, .1), (.08, .06), (.5, .03), (1, .03)], m, tx, 12, scale=.36)
    n = 1 if S.t == 0 else 3
    for k in range(n):
        x_ = (k - (n - 1) / 2) * .12
        if n > 1: pm.tube2(np.array([(0, .22, 0), (x_ * .6, .3, 0), (x_, .34, 0)]), [.012, .012, .012], m, tx, 6)
        pm.cyl2((x_, .34 if n > 1 else .3, 0), (x_, .46 if n > 1 else .42, 0), .022, .022, 'FBF5E6', 'soft', 8, 2)
        pm.emit_ell((x_, .5 if n > 1 else .46, 0), (.022, .04, .022), 'FFD98A' if S.t != 4 else 'BFE6FF', 1.0, None, 8, 6)
    if S.t == 3: pm.ell((0, .06, 0), (.12, .08, .1), 'F4E6C4', 'soft', .9)
    glow = glow_of(S, (0, .48, 0), 40, .6, 'FFD98A' if S.t != 4 else 'BFE6FF')
    return FSpec(pm, (1, 1), .62, 'tabletop', 'lighting', 'c4', glow, None, None)


def chandelier(S) -> FSpec:
    pm = HM(); y = 2.15; m = S.metal if S.t else '4A3A4D'; tx = 'gold' if S.t >= 2 else 'soft'
    pm.cyl2((0, y, 0), (0, y + .6, 0), .012, .012, m, tx, 6, 2)
    pm.ell((0, y - .02, 0), (.12, .1, .12), m, tx, .9, None, 14, 8)
    n = 4 if S.t < 2 else 6
    for k in range(n):
        a = k * 6.28 / n
        pm.tube2(np.array([(0, y - .05, 0), (math.cos(a) * .2, y - .1, math.sin(a) * .2), (math.cos(a) * .32, y + .0, math.sin(a) * .32)]), [.014, .014, .014], m, tx, 6)
        pm.cyl2((math.cos(a) * .32, y, math.sin(a) * .32), (math.cos(a) * .32, y + .08, math.sin(a) * .32), .02, .02, 'FBF5E6', 'soft', 8, 2)
        pm.emit_ell((math.cos(a) * .32, y + .12, math.sin(a) * .32), (.025, .045, .025), 'FFD98A' if S.t != 4 else S.glow_col, 1.0, None, 8, 6)
    if S.t >= 2:
        for k in range(8): pm.ell((math.cos(k * .785) * .18, y - .2, math.sin(k * .785) * .18), (.02, .06, .02), 'DCE6FA', 'crystalf', .9, None, 8, 6)
    if S.t == 3:   # unique: lantern-flower chandelier
        for k in range(5): pm.ell((math.cos(k * 1.26) * .3, y - .12, math.sin(k * 1.26) * .3), (.1, .14, .1), ('E58FA6', 'F2C14E', '9B86D6')[k % 3], 'soft', .85, None, 12, 8); pm.emit_ell((math.cos(k * 1.26) * .3, y - .16, math.sin(k * 1.26) * .3), (.05, .06, .05), 'FFE7B0')
    glow = glow_of(S, (0, y + .1, 0), 110 if S.t != 4 else 130, .55, 'FFD98A' if S.t != 4 else S.glow_col)
    if S.t == 4: floaters(pm, S, (0, y + .2, 0), (.5, .3, .5), 8, 181)
    return FSpec(pm, (1, 1), y + .7, 'ceiling', 'lighting', 'c4', glow, None, None)


TEMPLATES = {'bed': bed, 'table': table, 'chair': chair, 'sofa': sofa, 'wardrobe': wardrobe, 'bookshelf': bookshelf, 'rug': rug, 'floor_lamp': floor_lamp,
             'fireplace': fireplace, 'chest': chest, 'plant': plant, 'clock': clock, 'throne': throne, 'piano': piano, 'painting': painting, 'shelf': shelf,
             'curtain': curtain, 'sconce': sconce, 'vase': vase, 'table_lamp': table_lamp, 'candelabra': candelabra, 'chandelier': chandelier}
