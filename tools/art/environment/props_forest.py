"""props_forest.py - Moerkeskoven (DUNGEON addendum 3.3, 7.5, 8.11; v2 sketch "Moerkeskoven, set oppefra, nat"): the forest set baked with the PROJECT camera.

  * a crown is a SPHERE (a circle under any camera): crown_{s,m,l}_{a,b} are spheres of leaf clumps resting on the ground, baked at the project's 36 degrees (no
    90 degree art, no new bake mode).  Disc radius R = 170 / 230 / 300 px, the sphere centre is 0.81 R above the sort pivot (= the ground contact point), the
    ground shadow is an ellipse squashed to sin(36) = .59 and offset (+48, +60) px;
  * bush_eyes_{a,b} (dark clump with two eye hollows; the additive eyes are eyes_glow), empty_bush, cave_ring / cave_ring_up (ground decals with a walkable rim),
    cave_stone_a..e, home_rope, runestone_dormant / _active, pond_lily, chest_noegle, the tornebaer pickup.

BAKED-COLOUR RULE of the night look (v2_environment 4.4): the world is multiplied by the forest grade 4d5e85 (x0.30 / 0.37 / 0.52), final = albedo x (ambient +
lights), so the albedo baked here is the sketch colour divided by the multiplier (path 3b3c5e -> c3a3b4, crown base 2e3556 -> 9890a5, crown highlight 46447a ->
e8b8ea, water 1c4a5a -> 5dc9ad).  Anything whose channel exceeds ambient x 255 (R > 77, G > 94, B > 133: runestone stone, lily pads, the chest, cave stones) cannot
be baked bright: it is clamped at the ceiling here and made readable by an ADDITIVE layer or by the lantern (rune_glow, pond_sheen, eyes_glow ...) or by an
unshaded actor (V8's ForestDress).  The renders are mapped through a colour ramp (a gradient map on the lit luminance) so the shading of the 3D bake survives and the
final colours land on the sketch palette; FOREST_PALETTE below is the table the test reads (tests/sections/art_environment.gd forest_albedo_within_ambient_headroom).
"""
from __future__ import annotations
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import props_traetoppen as pp
from props_traetoppen import PM, spec, PropSpec
import static_render as sr

AMBIENT = (0x4d, 0x5e, 0x85)           # the forest preset of lua/config/ambient.lua
PX = sr.PX_PER_M
SIN36 = math.sin(math.radians(36.0))


def hexrgb(c): return np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def albedo(final_hex, ambient=AMBIENT):
    """Baked colour for a wanted FINAL colour under the grade: final / ambient, capped at 255 (the headroom rule)."""
    f = hexrgb(final_hex); a = np.asarray(ambient, np.float32)
    return np.clip(f / a * 255.0, 0, 255)


def albedo_hex(final_hex, ambient=AMBIENT):
    return '%02X%02X%02X' % tuple(int(round(v)) for v in albedo(final_hex, ambient))


def over_ceiling(final_hex, ambient=AMBIENT):
    f = hexrgb(final_hex)
    return bool((f > np.asarray(ambient, np.float32) + .5).any())


# the sketch palette of the forest elements and what the bake is checked against: id -> final colours after the grade of the ramp stops, the expected mean
# FINAL colour of the opaque pixels and a tolerance per channel; `clamped` = the sketch colour is above the ceiling, an additive layer / the lantern carries it
FOREST_PALETTE = {
    'crown': {'ramp': ['262c4a', '2e3556', '38406a', '46447a'], 'mean': '353b62', 'tol': 30},
    'bush': {'ramp': ['1c2038', '2a2f4c', '363b5e'], 'mean': '2a2f4c', 'tol': 26},
    'cave_ring': {'ramp': ['3a3c58', '4b4d6e', '56587a'], 'mean': '4b4d6e', 'tol': 30},
    'cave_stone': {'ramp': ['4a4c70', '5d5f82', '6a6c90'], 'mean': '4d5e82', 'tol': 44, 'clamped': True},
    'runestone': {'ramp': ['4a4c70', '5d5f82', '6a6c90'], 'mean': '4d5e82', 'tol': 44, 'clamped': True},
    'pond_lily': {'ramp': ['2a6a52', '3f8f6a', '4c9e78'], 'mean': '3f8f6a', 'tol': 50, 'clamped': True},
}


def ramp_post(final_stops, ambient=AMBIENT, lo=2, hi=98):
    """A gradient map: the lit luminance of the render (percentiles lo..hi of the opaque pixels) selects a colour on the ramp whose stops are FINAL colours
    under the grade (converted to albedo here).  Keeps the 3D shading and puts the colours on the sketch palette."""
    if final_stops and isinstance(final_stops[0], (tuple, list)):          # explicit positions: [(t, hex), ...]
        xs = np.array([t for t, _ in final_stops], np.float32)
        stops = np.stack([albedo(c, ambient) for _, c in final_stops])
    else:
        stops = np.stack([albedo(c, ambient) for c in final_stops])
        xs = np.linspace(0, 1, len(stops))

    def post(im: Image.Image) -> Image.Image:
        a = np.asarray(im, np.float32) / 255.0
        m = a[..., 3] > .5
        lum = .2126 * a[..., 0] + .7152 * a[..., 1] + .0722 * a[..., 2]
        l0, l1 = np.percentile(lum[m], [lo, hi])
        t = np.clip((lum - l0) / max(l1 - l0, 1e-4), 0, 1)
        rgb = np.stack([np.interp(t, xs, stops[:, k]) for k in range(3)], -1) / 255.0
        out = np.concatenate([rgb, a[..., 3:4]], -1)
        return Image.fromarray(np.uint8(np.clip(out * 255 + .5, 0, 255)), 'RGBA')
    return post


def night_outline(radius=6, final='14112a', alpha=1.0):
    return {'radius': radius, 'color': tuple(int(v) for v in albedo(final)), 'alpha': alpha}


def ground_shadow(rx_px, off=(48, 60), final='07060f', alpha=.85, blur=5):
    """Baked ground shadow: an ellipse squashed to sin(36 degrees) (a disc on the ground seen from the project camera).  `off` is the offset in GROUND px
    (the sketch's (16, 20) x K=3 = (48, 60)), drawn on the screen as (48, 60 x .588) like every ground vector of the project (Iso.to_screen)."""
    col = tuple(int(v) for v in albedo(final))

    def under(W, H, cx, cy):
        sh = Image.new('L', (W, H), 0)
        oy = off[1] * SIN36
        ImageDraw.Draw(sh).ellipse((cx + off[0] - rx_px, cy + oy - rx_px * SIN36, cx + off[0] + rx_px, cy + oy + rx_px * SIN36), fill=int(255 * alpha))
        sh = sh.filter(ImageFilter.GaussianBlur(blur))
        out = Image.new('RGBA', (W, H), col + (0,)); out.putalpha(sh)
        return out
    return under


def _fib(n):
    """n points spread over the unit sphere."""
    i = np.arange(n) + .5
    phi = np.arccos(1 - 2 * i / n); th = math.pi * (1 + 5 ** .5) * i
    return np.stack([np.cos(th) * np.sin(phi), np.cos(phi), np.sin(th) * np.sin(phi)], -1)


VIEW = np.array([math.sin(math.radians(45)) * math.cos(math.radians(36)), math.sin(math.radians(36)), math.cos(math.radians(45)) * math.cos(math.radians(36))])



def _screen_extent(m):
    """Screen extent (px) of a model from the project camera (az 45, elev 36): (x_half, top, bottom) relative to the ground origin; y grows downwards."""
    a, e = math.radians(45.0), math.radians(36.0)
    d = -np.array([math.sin(a) * math.cos(e), math.sin(e), math.cos(a) * math.cos(e)])
    right = np.cross(d, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, d); up /= np.linalg.norm(up)
    v = np.concatenate([s.vertices for g in m.groups for s in g.shapes])
    x = v @ right * PX; y = -(v @ up) * PX
    return float(np.abs(x).max()), float(y.min()), float(y.max())


def project_pt(p):
    """Screen px of a world point (metres) from the project camera relative to the ground origin (x right, y down)."""
    a, e = math.radians(45.0), math.radians(36.0)
    d = -np.array([math.sin(a) * math.cos(e), math.sin(e), math.cos(a) * math.cos(e)])
    right = np.cross(d, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, d); up /= np.linalg.norm(up)
    p = np.asarray(p, float)
    return float(p @ right * PX), float(-(p @ up) * PX)


def fit_disc(pm, R_px, width_only=False, centre_above=None):
    """Scale a finished sphere-like model about the ground origin so its screen silhouette is a disc of radius R_px (the average of its half width and
    half height; width_only: the half width): the clump bumps stick out of the nominal sphere, and the generator's `crown_covers` arithmetic needs the real radius.
    centre_above (px): then lift / lower the model so that the centre of the silhouette sits that far above the ground origin (the sort pivot): the contract of a
    crown is 'sphere centre 0.81 R above the pivot'."""
    xh, top, bot = _screen_extent(pm.m)
    r_now = xh if width_only else (xh + (bot - top) / 2) / 2
    k = R_px / r_now
    for g in pm.m.groups:
        for s in g.shapes:
            s.vertices = s.vertices * k
    if centre_above is not None:
        xh, top, bot = _screen_extent(pm.m)
        lift_px = (-(top + bot) / 2) - centre_above          # > 0: the centre is too high; screen y grows downwards
        dy = -lift_px / (math.cos(math.radians(36.0)) * PX)
        for g in pm.m.groups:
            for s in g.shapes:
                s.vertices = s.vertices + np.array([0.0, dy, 0.0])
    return k


# ================================================================================================ crowns
CROWN_R = {'s': 170, 'm': 230, 'l': 300}


def crown(size='m', variant='a') -> PropSpec:
    R = CROWN_R[size]
    OUT = 6
    Rm = (R - OUT) / PX                               # sphere radius in metres: the silhouette incl. the 6 px outline is the disc R
    seed = {'s': 11, 'm': 23, 'l': 37}[size] * (1 if variant == 'a' else 3) + (0 if variant == 'a' else 5)
    rng = np.random.default_rng(seed)
    pm = PM()
    tones = ('8E86B0', 'A39CC4', '776F9A')           # mid greys-violet; the ramp below decides the final colours
    pm.ell((0, Rm, 0), (Rm * .93,) * 3, tones[2], 'leaf', seg=26, rings=16)
    n = {'s': 40, 'm': 58, 'l': 84}[size]
    pts = _fib(n)
    rc = Rm * {'s': .36, 'm': .32, 'l': .28}[size]
    for k, p in enumerate(pts):
        if float(p @ VIEW) < -.3:
            continue                                  # hidden side: the core fills it
        r = rc * rng.uniform(.8, 1.2)
        c = np.array([0, Rm, 0]) + p * (Rm - r * .62)
        up = float(p @ np.array([-.5, .75, .45]))     # how much the surface faces the upper-left key light: seeds the clump variation
        cols = (tones[1], tones[0], tones[2]) if up > .35 else ((tones[0], tones[2], tones[1]) if up > -.2 else (tones[2], tones[2], tones[0]))
        pm.clump(tuple(c), r, cols, 'leaf', n=3, seed=int(seed * 100 + k), squash=.92, seg=14, rings=9)
    fit_disc(pm, R - OUT, centre_above=.81 * R - OUT * .5)     # the silhouette incl. the outline is the disc R, its centre .81 R above the pivot
    ramp = ramp_post(FOREST_PALETTE['crown']['ramp'], lo=4, hi=99)
    return spec(pm, f'crown_{size}_{variant}', footprint=(1, 1), shadow=None, canvas_pad=R // 3 + 50, outline=night_outline(OUT), post=ramp,
                under=ground_shadow(R), ss=2 if size == 'l' else 3,
                extra={'proj': 'iso', 'disc': {'radius': R, 'center_above_pivot': round(.81 * R), 'shadow_offset_ground': [48, 60], 'shadow_offset_screen': [48, round(60 * SIN36)], 'shadow_squash': round(SIN36, 3)},
                       'palette': 'crown', 'grade': '4d5e85', 'ground_collider_r': round(.75 * R)})


# ================================================================================================ bushes
def _bush(r_px, name, seed, hollows=True):
    pm = PM()
    rng = np.random.default_rng(seed)
    Rm = r_px / PX
    tones = ('7C7494', '8E86B0', '675F84')
    pm.ell((0, Rm * .62, 0), (Rm * .95, Rm * .62, Rm * .95), tones[2], 'leaf', seg=22, rings=14)
    for k, p in enumerate(_fib(60)):
        if p[1] < -.1 or float(p @ VIEW) < -.25:
            continue
        r = Rm * rng.uniform(.2, .3)
        c = np.array([0, Rm * .55, 0]) + p * np.array([Rm * .82, Rm * .58, Rm * .82]) - np.array([0, r * .2, 0])
        pm.clump(tuple(c), r, (tones[1], tones[0], tones[2]), 'leaf', n=3, seed=seed * 50 + k, squash=.9, seg=14, rings=9)
    mid = None
    if hollows:
        # two dark eye hollows facing the camera (the pink eyes are the additive eyes_glow of DR3, drawn into these sockets)
        fz = np.array([math.sin(math.radians(45)), 0, math.cos(math.radians(45))])
        side = np.array([fz[2], 0, -fz[0]])
        for sgn in (-1, 1):
            c = fz * Rm * .72 + side * sgn * Rm * .24 + np.array([0, Rm * .72, 0])
            pm.ell(tuple(c), (Rm * .11, Rm * .09, Rm * .06), '1A1830', 'soft', seg=14, rings=8, rot=(0, 45, 0))
        mid = fz * Rm * .72 + np.array([0, Rm * .72, 0])
    k = fit_disc(pm, r_px - 5, width_only=True)       # an oblate clump: the half WIDTH is the radius the sketch gives (r 40 / 30 x K)
    extra = {'proj': 'iso', 'palette': 'bush', 'grade': '4d5e85'}
    if mid is not None:
        ex, ey = project_pt(mid * k)
        extra['eyes'] = {'prop': 'eyes_glow', 'offset_from_pivot': [round(ex), round(ey)], 'separation_px': round(2 * Rm * .24 * k * 87.074 * .9)}
    return spec(pm, name, footprint=(1, 1), shadow=None, canvas_pad=40, outline=night_outline(5), post=ramp_post(FOREST_PALETTE['bush']['ramp']),
                under=ground_shadow(r_px * .95, off=(30, 36), alpha=.8), extra=extra)


def bush_eyes_a(): return _bush(130, 'bush_eyes_a', 3)
def bush_eyes_b(): return _bush(128, 'bush_eyes_b', 5)
def empty_bush(): return _bush(120, 'empty_bush', 9, hollows=False)


# ================================================================================================ the Hulen and its stones
RIGHT = np.array([math.sqrt(.5), 0.0, -math.sqrt(.5)])      # the ground direction that points to the screen's right (camera azimuth 45)
DEPTH = np.array([math.sqrt(.5), 0.0, math.sqrt(.5)])       # the ground direction that points down the screen (towards the camera)


def _ring_stones(pm, A, B, n, rr, tones, seed, y=.1):
    """Stones on a screen-aligned ground ellipse: semi axes A (screen horizontal) and B (ground depth) in metres."""
    rng = np.random.default_rng(seed)
    for i in range(n):
        a = 2 * math.pi * (i + rng.uniform(-.15, .15)) / n
        r = rr * rng.uniform(.8, 1.15)
        p = RIGHT * math.cos(a) * A + DEPTH * math.sin(a) * B
        pm.ell((p[0], y, p[2]), (r, r * .62, r * .9), tones[i % len(tones)], 'stone', power=.75, rot=(0, rng.uniform(0, 90), 0), seg=14, rings=9)


def _cave_ring(up=False, name='cave_ring'):
    """The stone ring of the sketch: ellipse 5.5 x 6.6 cells (528 x 370 px), hole radii about 150 x 100 px.  Ground decal: low, rim walkable.
    The ellipses are rotated 45 degrees about y so that their axes are the SCREEN's (the camera looks along the ground diagonal)."""
    a_out, b_out = 264 / PX, 185 / (PX * SIN36)           # semi axes in metres: screen horizontal, ground depth
    a_in, b_in = 150 / PX, 100 / (PX * SIN36)
    rot = (0, 45, 0)
    pm = PM()
    tones = ('B2AAC8', 'C4BCDA', 'A09AB8', 'D2CCE4')
    pm.ell((0, .06, 0), (a_out, .1, b_out), tones[2], 'stone', power=.92, seg=40, rings=10, rot=rot)
    pm.ell((0, .13, 0), (a_out - .12, .06, b_out - .12), tones[0], 'stone', power=.92, seg=40, rings=8, rot=rot)
    _ring_stones(pm, a_out * .93, b_out * .93, 30, .24, tones, 2)
    _ring_stones(pm, a_in * 1.12, b_in * 1.12, 22, .22, tones, 4, y=.16)
    if up:
        # the way up: the hole is a pale well of light with three concentric steps
        for k, (s, c) in enumerate(((1.0, 'D8D2EE'), (.78, 'C0B8DE'), (.56, 'A89FD0'))):
            pm.ell((0, .12 + k * .015, 0), (a_in * s, .03, b_in * s), c, 'stone', power=.92, seg=36, rings=6, rot=rot)
        pm.ell((0, .2, 0), (a_in * .34, .025, b_in * .34), 'F2EEFF', 'porcelain', power=.92, seg=28, rings=6, rot=rot)
    else:
        pm.ell((0, .15, 0), (a_in, .03, b_in), '2A2640', 'soft', power=.92, seg=36, rings=6, rot=rot)
        pm.ell((0, .19, 0), (a_in * .78, .03, b_in * .78), '0C0A18', 'soft', power=.92, seg=36, rings=6, rot=rot)
    stops = [(0, '0a0a14'), (.1, '1a1c30'), (.3, '3a3c58'), (.6, '4b4d6e'), (1, '5c5e80')] if not up else [(0, '3a3c60'), (.3, '484a70'), (.65, '5a5c80'), (1, '7a7ca0')]
    return spec(pm, name, footprint=(1, 1), shadow=None, canvas_pad=30, outline=night_outline(4, '14112a', .9), post=ramp_post(stops, lo=1, hi=99),
                extra={'proj': 'iso', 'palette': 'cave_ring', 'grade': '4d5e85', 'decal': True, 'ring': {'outer_px': [528, 370], 'hole_px': [300, 200]}})


def cave_ring(): return _cave_ring(False, 'cave_ring')
def cave_ring_up(): return _cave_ring(True, 'cave_ring_up')


def cave_stone(seed=1, name='cave_stone_a'):
    rng = np.random.default_rng(seed)
    pm = PM()
    tone = ('C8CCE8', 'DADCF2', 'B4B8D8')
    pm.ell((0, .27, 0), (.5, .3, .42), tone[0], 'stone', power=.72, rot=(0, rng.uniform(0, 90), 0))
    pm.ell((.28 * rng.choice([-1, 1]), .18, .12), (.28, .2, .26), tone[1], 'stone', power=.75, rot=(0, rng.uniform(0, 90), 0))
    pm.ell((-.2, .12, -.2), (.2, .13, .18), tone[2], 'stone', power=.75)
    if seed % 2 == 0:
        pm.ell((0, .5, 0), (.3, .05, .26), '6E9A7A', 'leaf', power=.9)                         # a moss cap on every second stone
    return spec(pm, name, footprint=(1, 1), shadow=None, canvas_pad=14, outline=night_outline(3, '14112a', .8),
                post=ramp_post(FOREST_PALETTE['cave_stone']['ramp'], lo=1, hi=99), under=ground_shadow(48, off=(14, 14), alpha=.7, blur=4),
                extra={'proj': 'iso', 'palette': 'cave_stone', 'grade': '4d5e85', 'clamped': True})


def home_rope():
    """The last floor's way home: a rope that hangs down from the dark above, knotted, anchored to a ring of three stones.  Pale + a soft glow so it is found."""
    pm = PM()
    tone = ('D2CAB8', 'E8E0CC', 'BEB6A2')
    for k in range(3):
        a = k * 2.1 + .4
        pm.ell((math.cos(a) * .42, .15, math.sin(a) * .42), (.22, .15, .19), 'B2B6D2', 'stone', power=.75, rot=(0, k * 40, 0))
    pm.curve([(0, 0, 0), (.04, 1.2, 0), (-.04, 2.6, 0), (.02, 4.6, 0)], .07, .055, tone[0], 'straw', 8, n=30)
    for k in range(6):                                                                                  # knots
        pm.ell((.02 * (-1) ** k, .5 + k * .7, 0), (.1, .08, .1), tone[1 + k % 2], 'straw', seg=10, rings=6)
    pm.curve([(0, .1, 0), (.3, .12, .2), (.45, .1, .05), (.25, .08, -.2), (.0, .1, 0)], .05, .05, tone[2], 'straw', 6, n=18)   # the coil at the foot
    return spec(pm, 'home_rope', footprint=(1, 1), shadow=None, canvas_pad=14, outline=night_outline(3, '14112a', .8), post=ramp_post(['484a68', '6a6c8e', '7c7e9e'], lo=1, hi=99),
                under=ground_shadow(44, off=(12, 12), alpha=.7, blur=4), glow=('FFE9A8', 40, .55, (0, 1.4, 0)),
                extra={'proj': 'iso', 'palette': 'cave_stone', 'grade': '4d5e85', 'clamped': True})


# ================================================================================================ runestone
GLYPH = [((0, -.62), (0, .62)), ((0, .2), (.36, .62)), ((0, -.08), (-.34, .36)), ((0, -.5), (.3, -.18))]     # a rune: stem, two branches, a flag (unit units)
SLAB = (1.25, 1.38, .45)             # w, h, d (m): about 130 x 190 px


def runestone(active=False):
    pm = PM()
    w, h, d = SLAB
    tone = ('C4C8E6', 'D6D8F0')
    pm.box((0, h / 2, 0), (w, h, d), tone[0], 'stone', power=.28, rot=(0, -8, 0), seg=24, rings=16)
    pm.ell((0, h + .02, 0), (w * .46, .08, d * .46), tone[1], 'stone', power=.7, rot=(0, -8, 0), seg=18, rings=6)
    pm.ell((.05, .06, d * .5 + .06), (w * .45, .12, .3), '6E9A7A', 'leaf', power=.9, rot=(0, -8, 0))       # moss at the foot
    col = 'F2F6FF' if active else '3A3E5C'                    # the glyph, engraved on the +z face: dark when dormant, a pale inlay when active
    for (x0, y0), (x1, y1) in GLYPH:
        for t in np.linspace(0, 1, 9):
            x = x0 + (x1 - x0) * t; y = y0 + (y1 - y0) * t
            pm.ell((x * w * .5 * .9, h * .54 + y * h * .3, d * .5 + .035), (.062, .062, .035), col, 'porcelain' if active else 'soft', seg=8, rings=5, rot=(0, -8, 0))
    return spec(pm, 'runestone_active' if active else 'runestone_dormant', footprint=(1, 1), shadow=None, canvas_pad=20, outline=night_outline(4, '14112a', .9),
                post=ramp_post(FOREST_PALETTE['runestone']['ramp'], lo=1, hi=99), under=ground_shadow(70, off=(22, 24), alpha=.8, blur=5),
                extra={'proj': 'iso', 'palette': 'runestone', 'grade': '4d5e85', 'clamped': True, 'glyph': '6fd6c4', 'state': 'active' if active else 'dormant'})


# ================================================================================================ pond lily, chest, thorn-berry
def pond_lily():
    """One lily pad with a notch and a tiny bud, about 60 x 38 px.  The pad green (3f8f6a, G 143 > 94) is above the ceiling: clamped, the pond sheen carries the glow."""
    pm = PM()
    pm.ell((0, .02, 0), (.34, .02, .33), 'B8D8B4', 'leaf', seg=22, rings=4)
    pm.ell((.1, .045, .0), (.05, .02, .05), 'F6C6D6', 'soft', seg=10, rings=5)
    pm.box((-.18, .03, .12), (.2, .03, .04), '8CB88C', 'leaf', rot=(0, 28, 0))
    return spec(pm, 'pond_lily', footprint=(1, 1), shadow=None, canvas_pad=3, outline=night_outline(2, '14112a', .8), post=ramp_post(FOREST_PALETTE['pond_lily']['ramp'], lo=1, hi=99),
                extra={'proj': 'iso', 'palette': 'pond_lily', 'grade': '4d5e85', 'clamped': True})


def chest_noegle():
    """The LAKE chest of floors 3 / 6 / 9 (sketch landmark 6): the chest shape recoloured moon-blue with a brass padlock; an unshaded actor (V8), so baked bright."""
    pm = PM()
    body, band, lid = 'A9C4E8', '5B6E9A', 'B9D0F0'
    pm.box((0, .27, 0), (.98, .54, .66), body, 'plank', power=.3)
    for x in (-.3, .3):
        pm.box((x, .27, 0), (.07, .56, .69), band, 'stone', power=.3)
    pm.ell((0, .56, 0), (.49, .24, .33), lid, 'plank', power=.7, seg=24, rings=12)
    for x in (-.3, .3):
        pm.ell((x, .56, 0), (.04, .255, .345), band, 'stone', power=.7, seg=12, rings=10)
    pm.box((0, .4, .35), (.16, .2, .06), 'E9C06B', 'crystal', power=.5)                                   # the lock plate
    pm.curve([(-.05, .5, .38), (-.06, .64, .38), (.06, .64, .38), (.05, .5, .38)], .02, .02, 'C9962B', 'crystal', 8, n=10)   # shackle
    pm.ell((0, .39, .39), (.03, .04, .02), '3A2E4A', 'soft', seg=8, rings=6)
    return spec(pm, 'chest_noegle', footprint=(1, 1), shadow=(.75, .32), glow=('BFD8FF', 30, .35),
                extra={'proj': 'iso', 'unshaded': True, 'tier': 'noegle'})


def tornebaer():
    """The thorn-berry pickup (DR3 drops it, +2 half hearts): three pink berries with tiny thorns and a leaf; unshaded."""
    pm = PM()
    for k, (x, y, z, r, c) in enumerate(((-.1, .12, .02, .11, 'E58FA6'), (.1, .12, -.02, .11, 'D6638C'), (0, .13, .13, .1, 'F0A3B8'))):
        pm.ell((x, y, z), (r, r, r), c, 'soft', seg=14, rings=10)
        for t in range(6):
            a = t * 1.05 + k
            pm.ell((x + math.cos(a) * r * .95, y + math.sin(a * 1.7) * r * .5, z + math.sin(a) * r * .95), (.012, .012, .012), 'B3436B', 'soft', seg=6, rings=4)
        pm.ell((x - r * .3, y + r * .45, z + r * .5), (.025, .02, .02), 'FFFFFF', 'soft', seg=6, rings=4)
    pm.ell((0, .27, 0), (.14, .03, .08), '6FAA46', 'leaf', rot=(0, 30, 15), seg=10, rings=6)
    return spec(pm, 'tornebaer', footprint=(1, 1), shadow=(.28, .12), glow=('E58FA6', 14, .5), extra={'proj': 'iso', 'unshaded': True})


FOREST_PROPS = {
    **{f'crown_{s}_{v}': (lambda s=s, v=v: crown(s, v)) for s in ('s', 'm', 'l') for v in ('a', 'b')},
    'bush_eyes_a': bush_eyes_a, 'bush_eyes_b': bush_eyes_b, 'empty_bush': empty_bush,
    'cave_ring': cave_ring, 'cave_ring_up': cave_ring_up,
    **{f'cave_stone_{c}': (lambda i=i, c=c: cave_stone(i + 1, f'cave_stone_{c}')) for i, c in enumerate('abcde')},
    'home_rope': home_rope, 'runestone_dormant': lambda: runestone(False), 'runestone_active': lambda: runestone(True),
    'pond_lily': pond_lily, 'chest_noegle': chest_noegle, 'tornebaer': tornebaer,
}
pp.PROPS.update(FOREST_PROPS)
