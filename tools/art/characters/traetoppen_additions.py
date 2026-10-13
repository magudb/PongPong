"""TRAETOPPEN gap-fill characters, NPCs, farm animals and enemies.

Same geometry vocabulary as geometry.py / additions.py (Model, ellipsoid, tube, pillow, eyes, cheeks, ...).
Nothing in the 12 shipped characters is redrawn; every builder here either
  * builds a NEW species from the same primitives (hobbit, squirrel, mouse, chick, lamb, mushroom, ...), or
  * re-runs an existing builder under a temporary palette override and adds accessories (NPC fairies, villagers).

Conventions
  m.name      rig family (decides rig special cases: 'fairy','bat','penguin','capybara' are special-cased by build_assets)
  m.slug      output id (file names, folder name in assets/isometric_characters/<slug>/)
  m.height    target model height in metres after export (default 1.95)
  m.cam_scale optional orthographic camera half-height (default 1.47) so tall/wide models are not clipped
  m.clip_set  key of bake_sprite_atlases.CLIP_SETS (which clips are baked) -> keeps atlases small
  m.extra_clips  [(name,duration,loop)] of EXTRA_CLIPS to export (attack, spin)
"""
import contextlib
import math
import numpy as np
from PIL import Image, ImageDraw
import geometry as geo
from geometry import (Model, PALETTES, eyes, cheeks, arms, feet, bezier, rounded_triangle, head_surface,
                      mouth_open)
import additions as add

# ---------------------------------------------------------------------------------------------------------------------
# palettes for new families
# ---------------------------------------------------------------------------------------------------------------------
PALETTES.update({
    'hobbit': dict(body='F2CBA8', light='F9DFC6', inner='E7A9A0', rim='BE8B6B', belly='F6DCC0', nose='D9967F',
                   tunic='78B05A', tunic_dark='55883F', hair='B8733A', hair_light='DB9A58', foot_hair='B8733A', foot_hair_light='E3A862', toe='E9B994',
                   belt='6A4A2E', gold='E9C06B', scarf='F2C14E', trouser='8A6445', vest='6E8F4A'),
    'squirrel': dict(body='D98A4A', light='FFE8C6', inner='E3A9A0', rim='7A4A33', belly='FFF0D8', tail_tip='FFE3BC'),
    'mouse': dict(body='C9A582', light='F3E2CC', inner='EAB1B2', rim='8C6A53', belly='F8EBDA', hat='7C8F4A',
                  hat_dark='5E6F37', scarf='C4506A', strap='8A5A30', leather='B58049', gold='E3C372'),
    'chick': dict(body='FFD966', light='FFF0A8', inner='F4A25C', rim='D9A23E', belly='FFF3BD', beak='F59A3E',
                  comb='E5738A', foot='F0953C'),
    'lamb': dict(body='F6EEDC', light='FFFAF0', inner='E9B3B6', rim='8A6C58', belly='FFF7E8', wool='F8F1E3',
                 wool_dark='EFE5D0', face='C9A58C', leg='6E5648'),
    'mushroom': dict(body='F5E6CF', light='FFF4E0', inner='E5B2B6', rim='8C6A5A', belly='FFF4E0', cap='B3436B',
                     cap_dark='8E2F52', spot='FFF2D8', gill='E9C9B5'),
    'thornbush': dict(body='3F6B4E', light='7FB08A', inner='B3436B', rim='233F31', belly='5F8F6B', thorn='C9B27A',
                      berry='B3436B', berry_light='E58FA6', eye='F2C14E'),
    'owl': dict(body='8A6B55', light='D9C3A2', inner='E3A9A0', rim='5E4636', belly='EBD9BA', beak='F0B05A',
                feather='A5805F', eye='FFF9EB'),
})
PALETTES['cow'] = dict(body='F7F0E4', light='FFFAF0', inner='E9B3B6', rim='4B3A33', belly='FFF4E6', patch='5B4338',
                       horn='E8D9B8', muzzle='F2B8B8', leg='4B3A33')

PALETTES['puppy'] = dict(body='D9A877', light='F6E2C0', inner='E9B3B6', rim='7A5237', belly='F6E2C0', ear='8A5A3A', nose='3A2A30')
PALETTES['fawn'] = dict(body='CFA06E', light='F8EBD2', inner='E9B3B6', rim='7A5237', belly='F8EBD2', spot='FFF6E4', leg='A87E52', nose='3A2A30')

HEADS = {  # head centre/radii of the shipped builders, needed to place hats/glasses/beards on recoloured animals
    'cat': ((0, 1.76, .015), (.65, .545, .42)), 'bear': ((0, 1.52, .008), (.615, .555, .40)),
    'rabbit': ((0, 1.67, .012), (.602, .533, .42)), 'fox': ((0, 1.61, .025), (.62, .54, .408)),
    'raccoon': ((0, 1.60, .02), (.618, .537, .409)), 'penguin': ((0, 1.43, .02), (.591, .521, .397)),
    'hedgehog': ((0, 1.55, .08), (.567, .514, .380)), 'frog': ((0, 1.40, .015), (.692, .437, .368)),
    'fairy': ((0, 1.72, .028), (.555, .507, .410)), 'monkey': ((0, 1.64, .014), (.595, .544, .409)),
}


@contextlib.contextmanager
def palette(family, overrides):
    """Temporarily override a family palette while a stock builder runs (Model copies it in __init__)."""
    old = PALETTES.get(family)
    PALETTES[family] = {**(old or {}), **overrides}
    try:
        yield
    finally:
        if old is None:
            del PALETTES[family]
        else:
            PALETTES[family] = old


def ell(c, r, az, el, k=1.0):
    """Point on an ellipsoid: az (deg) 0 = front (+z), el (deg) 90 = top."""
    a, e = math.radians(az), math.radians(el)
    return np.array([c[0] + k * r[0] * math.cos(e) * math.sin(a), c[1] + k * r[1] * math.sin(e),
                     c[2] + k * r[2] * math.cos(e) * math.cos(a)])


def ring_path(center, rx, rz, n=28, y_wobble=0.0, close=True):
    t = np.linspace(0, 2 * math.pi, n + (1 if close else 0), endpoint=not close if False else True)
    return np.c_[center[0] + rx * np.cos(t), center[1] + y_wobble * np.cos(3 * t), center[2] + rz * np.sin(t)]


def top_y(m):
    return max(float(sh.vertices[:, 1].max()) for g in m.groups for sh in g.shapes)


def finish(m, slug, height=None, cam_scale=None, clip_set='full', extra=None, patterns=None, base=None, **kw):
    """base: height of the stock model BEFORE accessories were added; keeps pixels-per-metre identical to the stock character."""
    m.slug = slug
    if height: m.height = height
    if base: m.base_height = base
    if cam_scale: m.cam_scale = cam_scale
    m.clip_set = clip_set
    if extra: m.extra_clips = extra
    if patterns: m.patterns = patterns
    for k, v in kw.items(): setattr(m, k, v)
    return m


# ---------------------------------------------------------------------------------------------------------------------
# extra texture patterns (called from build_assets.paint_tile)
# ---------------------------------------------------------------------------------------------------------------------
def _rgb(c): return np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], float)


def _base(color, size, noise=.008, grad=.03):
    rgb = _rgb(color)
    y, x = np.mgrid[0:1:complex(size), 0:1:complex(size)]
    rng = np.random.default_rng(int(color, 16) % 2147483647)
    var = .02 * np.cos(2 * np.pi * x) + grad * (.5 - y) + noise * rng.standard_normal((size, size))
    return rgb, x, y, rng, var


def _img(a): return Image.fromarray(np.clip(a, 0, 255).astype('uint8'), 'RGB')


def pat_cloth(color, size):
    rgb, x, y, rng, var = _base(color, size, .006)
    weave = .018 * (np.sin(x * size * 1.05) * np.sin(y * size * 1.05))
    return _img(rgb[None, None, :] * (1 + var + weave)[:, :, None])


def pat_skin(color, size):
    rgb, x, y, rng, var = _base(color, size, .004, .02)
    return _img(rgb[None, None, :] * (1 + var * .7)[:, :, None])


def pat_wool(color, size):
    rgb, x, y, rng, var = _base(color, size, .01)
    im = _img(rgb[None, None, :] * (1 + var)[:, :, None])
    d = ImageDraw.Draw(im)
    for i in range(180):
        px, py = int(rng.integers(4, size - 4)), int(rng.integers(4, size - 4))
        c = tuple(np.clip(rgb * (1 + rng.uniform(-.06, .03)), 0, 255).astype(int))
        d.arc((px - 6, py - 6, px + 6, py + 6), int(rng.integers(0, 360)), int(rng.integers(0, 360)) + 140, fill=c, width=2)
    return im


def pat_feather(color, size):
    rgb, x, y, rng, var = _base(color, size, .008)
    im = _img(rgb[None, None, :] * (1 + var)[:, :, None])
    d = ImageDraw.Draw(im)
    dark = tuple(np.clip(rgb * .9, 0, 255).astype(int))
    for row in range(0, size, 18):
        for col in range(-9 * (row // 18 % 2), size, 18):
            d.arc((col, row, col + 18, row + 26), 20, 160, fill=dark, width=1)
    return im


def pat_tail_squirrel(color, size):
    rgb, x, y, rng, var = _base(color, size, .01)
    a = rgb[None, None, :] * (1 + var)[:, :, None]
    band = (.5 + .5 * np.sin(y * 34)) * .10
    a = a * (1 - band[:, :, None] * .5)
    fac = np.clip((y - .80) * 24 + .5, 0, 1)[:, :, None]
    a = a * (1 - fac) + _rgb('FFE3BC')[None, None, :] * fac
    return _img(a)


def pat_tail_mouse(color, size):
    rgb, x, y, rng, var = _base(color, size, .004)
    return _img(rgb[None, None, :] * (1 + var * .5)[:, :, None])


def pat_glow(color, size):
    rgb, x, y, rng, var = _base(color, size, .006)
    g = np.exp(-((x - .5) ** 2 + (y - .5) ** 2) * 6)
    a = rgb[None, None, :] * (1 + var * .4 + .35 * g)[:, :, None]
    return _img(a)


EXTRA_PATTERNS = {'cloth': pat_cloth, 'skin': pat_skin, 'wool': pat_wool, 'feather': pat_feather,
                  'tail_squirrel': pat_tail_squirrel, 'tail_mouse': pat_tail_mouse, 'glow': pat_glow}


# ---------------------------------------------------------------------------------------------------------------------
# extra animation clips (called from build_assets.make_clips)
# ---------------------------------------------------------------------------------------------------------------------
def clip_attack(m, r, t, duration, phase, q, translations, scales):
    """Wind-up (lean back), strike (lunge forward + arms/head thrust), recover."""
    u = t / duration
    amount = np.where(u < .35, -np.clip(u / .35, 0, 1) * .55,
                      np.where(u < .55, -.55 + np.clip((u - .35) / .20, 0, 1) * 1.65, 1.10 - np.clip((u - .55) / .45, 0, 1) * 1.10))
    hip, spine, head = r.lookup['Hips'], r.lookup['Spine'], r.lookup['Head']
    q[:, spine, 0] += .34 * amount
    q[:, head, 0] += .20 * amount
    translations[:, hip, 2] += .30 * np.maximum(amount, 0) - .08 * np.maximum(-amount, 0)
    translations[:, hip, 1] -= .05 * np.abs(amount)
    for side, a, b, c in r.arms:
        sign = -1 if side == 'L' else 1
        q[:, a, 2] = sign * .95 * np.maximum(amount, 0)
        q[:, a, 0] = -.9 * np.maximum(amount, 0) + .5 * np.maximum(-amount, 0)
        q[:, b, 0] = -.25 * np.maximum(amount, 0)
    for ids in r.tails:
        for k, i in enumerate(ids): q[:, i, 1] = .22 * amount * (1 + .3 * k)


def clip_spin(m, r, t, duration, phase, q, translations, scales):
    """Whole body yaws one full turn around the vertical axis (arms flung out). Row direction is irrelevant."""
    q[:, r.lookup['Root'], 1] = phase
    translations[:, r.lookup['Hips'], 1] += .05 * np.sin(phase * 2)
    for side, a, b, c in r.arms:
        sign = -1 if side == 'L' else 1
        q[:, a, 2] = sign * 1.15
        q[:, b, 0] = -.1


EXTRA_CLIPS = {'attack': clip_attack, 'spin': clip_spin}
ATTACK = ('attack', .42, False)
SPIN = ('spin', 1.1, True)


# ---------------------------------------------------------------------------------------------------------------------
# HOBBIT (3 skins)
# ---------------------------------------------------------------------------------------------------------------------
HOBBIT_SKINS = {
    'pip': dict(),  # leaf green tunic, ginger curls, yellow neckerchief
    'moss': dict(body='E9BC94', light='F4D3B3', rim='B38460', belly='F1D3B0', tunic='D09A45', tunic_dark='A97A2F',
                 hair='5F3F2A', hair_light='7E563A', foot_hair='3C2616', foot_hair_light='5F3F2A', toe='DDAA83', scarf='8CB15A', vest='6E8F4A', nose='CF8E78'),
    'bramble': dict(body='DDA67C', light='EEC39F', rim='A97650', belly='EBC49C', tunic='9A4E73', tunic_dark='763A57',
                    hair='2F2423', hair_light='4D3A36', foot_hair='211716', foot_hair_light='4D3A36', toe='CF9972', scarf='E8D6A8', vest='E8D6A8', nose='C98670',
                    belt='4B3328'),
}


def make_hobbit(skin='pip'):
    with palette('hobbit', HOBBIT_SKINS[skin]):
        m = Model('hobbit')
    hc = (0, 1.58, .02); hr = (.63, .545, .43)
    # --- tunic body, hem, collar, belt
    m.group('Body', (0, .74, 0))
    m.ellipsoid('Body', (0, .80, 0), (.47, .62, .36), 'tunic', seg=36, rings=22, power=.88)
    m.ellipsoid('Body', (0, .40, .01), (.53, .26, .41), 'tunic_dark', seg=32, rings=16, power=.8)  # flared hem
    m.ellipsoid('Body', (0, 1.14, .03), (.34, .10, .27), 'tunic_dark', seg=28, rings=12)             # collar
    p = ring_path((0, .66, 0), .445, .345, 32)
    m.tube('Body', p, .034, 'belt', sides=8)
    m.ellipsoid('Body', (0, .66, .352), (.075, .062, .03), 'gold', seg=18, rings=10)                 # buckle
    if skin == 'moss':   # mossy leaf shoulder-cape
        for sgn in (-1, 1):
            for k, (cx, cy, cz, rr) in enumerate([(.30, 1.07, .04, .16), (.42, .98, .02, .15), (.50, .88, -.02, .13)]):
                m.ellipsoid('Body', (sgn * cx, cy, cz), (rr, rr * .8, rr * .9), 'vest', seg=18, rings=10, power=.8)
    if skin == 'bramble':  # cream waistcoat front with two buttons
        m.ellipsoid('Body', (0, .88, .30), (.27, .40, .09), 'vest', seg=24, rings=14)
        for yy in (1.0, .82):
            m.ellipsoid('Body', (0, yy, .385), (.03, .03, .015), 'belt', seg=10, rings=6)
    if skin == 'pip':   # neckerchief
        m.tube('Body', ring_path((0, 1.12, .02), .27, .22, 24), .045, 'scarf', sides=8)
        m.ellipsoid('Body', (0, 1.04, .26), (.09, .12, .05), 'scarf', seg=14, rings=8)
    # --- head
    m.group('Head', (0, hc[1] - .32, 0))
    m.ellipsoid('Head', hc, hr, 'body', seg=40, rings=26)
    # pointy little ears
    for side, s in (('L', -1), ('R', 1)):
        g = m.group('Ear_' + side, (s * .50, 1.58, .0), 'Head')
        tri = rounded_triangle([(s * .46, 1.50), (s * .80, 1.76), (s * .55, 1.66)], 6)
        tri = rounded_triangle([(s * .46, 1.74), (s * .82, 1.88), (s * .56, 1.50)], 6)
        m.pillow(g, tri, .01, .06, 'body')
        c = tri.mean(axis=0); m.pillow(g, c + (tri - c) * .5, .06, .012, 'inner')
    eyes(m, hc, hr, x=.235, y_offset=.085, size=(.185, .21), asym=.02)
    cheeks(m, hc, hr, x=.40, y_offset=-.14)
    # round nose + gentle smile
    zn = head_surface(hc, hr, 0, hc[1] - .10)
    m.ellipsoid('Head', (0, hc[1] - .10, zn + .035), (.07, .06, .06), 'nose', seg=18, rings=12)
    pth = bezier([[-.11, hc[1] - .24, head_surface(hc, hr, -.11, hc[1] - .24) + .01],
                  [-.05, hc[1] - .31, head_surface(hc, hr, -.05, hc[1] - .31) + .02],
                  [.05, hc[1] - .31, head_surface(hc, hr, .05, hc[1] - .31) + .02],
                  [.11, hc[1] - .24, head_surface(hc, hr, .11, hc[1] - .24) + .01]], 20)
    m.tube('Head', pth, .010, 'ink', sides=8)
    # --- curly hair: back shell + curls on a shell around the skull, fringe over the forehead
    m.ellipsoid('Head', (hc[0], hc[1] + .07, hc[2] - .09), (hr[0] * 1.03, hr[1] * 1.0, hr[2] * .96), 'hair', seg=34, rings=22)
    rng = np.random.default_rng(7 + len(skin))
    rings = [(84, 1, .17), (66, 7, .165), (46, 11, .16), (26, 14, .15), (8, 14, .14), (-8, 12, .13)]
    for el, n, rad in rings:
        for k in range(n):
            az = 360 * (k + .5 * (rings.index((el, n, rad)) % 2)) / max(n, 1)
            azs = ((az + 180) % 360) - 180          # -180..180, 0 = front
            if abs(azs) < 60 and el < 40: continue  # keep the face clear
            if 62 < abs(azs) < 118 and el < 22: continue  # ear windows
            if el < 0 and abs(azs) < 100: continue
            col = 'hair_light' if (k % 3 == 0) else 'hair'
            c = ell(hc, hr, azs, el, 1.07)
            c[2] += -.03
            m.ellipsoid('Head', c, (rad, rad * .92, rad), col, seg=16, rings=10)
    for az, el, rad in [(-38, 52, .15), (-14, 58, .155), (12, 60, .15), (36, 54, .15), (-52, 44, .13), (52, 44, .13)]:
        c = ell(hc, hr, az, el, 1.07); c[2] -= .01
        m.ellipsoid('Head', c, (rad, rad * .95, rad * .9), 'hair', seg=16, rings=10)
    if skin == 'pip':  # a tiny flower tucked into the curls
        fc = ell(hc, hr, 40, 62, 1.14)
        for a in np.linspace(0, 2 * np.pi, 5, endpoint=False):
            m.ellipsoid('Head', fc + np.array([.05 * math.cos(a), .05 * math.sin(a), .03]), (.035, .04, .02), 'light', seg=12, rings=8)
        m.ellipsoid('Head', fc + np.array([0, 0, .045]), (.025, .025, .02), 'gold', seg=10, rings=8)
    if skin == 'bramble':  # berry sprig
        fc = ell(hc, hr, -42, 60, 1.14)
        for dx, dy in [(0, 0), (.06, .02), (.02, .07)]:
            m.ellipsoid('Head', fc + np.array([dx, dy, .03]), (.04, .04, .04), 'inner', seg=12, rings=8)
    # --- arms: sleeve + skin hand
    for side, s in (('L', -1), ('R', 1)):
        g = m.group('Arm_' + side, (s * .285, 1.18, .215))
        m.ellipsoid(g, (s * .285, .98, .29), (.115, .20, .14), 'tunic', seg=24, rings=14, tilt=-s * .12)
        m.ellipsoid(g, (s * .295, .80, .30), (.085, .085, .09), 'body', seg=18, rings=12)
    # --- big hairy feet (review gate 5, fix round 2): they must read as HAIRY HOBBIT FEET at game scale (40 % zoom, ~100 px figure),
    #     not as brown shoes.  The skin sole is unchanged (so the foot envelope, the height and A2's garment fit do not move); the fur now
    #     (1) is the colour of the head's curls (Pip: the same ginger as his hair) with every third tuft in the lighter curl colour, so the
    #     fur has a curly, lit-and-shaded texture instead of one flat colour; (2) covers the instep ALL the way to the toes and the
    #     flanks of the foot, so the skin colour no longer dominates the foot; (3) puts a little hair on the toes themselves (hairy
    #     toes are the hobbit trademark).  Three small skin toes still peek out in front.
    for side, s in (('L', -1), ('R', 1)):
        g = m.group('Foot_' + side, (s * .245, .27, .03))
        m.ellipsoid(g, (s * .25, .115, .215), (.175, .125, .31), 'body', seg=26, rings=16, power=.85)
        tufts = [(-.115, .02, .24, .085), (.115, .02, .24, .085), (0, .02, .27, .09),                       # ankle ruff
                 (-.125, .11, .22, .09), (.125, .11, .22, .09), (0, .11, .25, .095),                        # instep
                 (-.105, .22, .20, .09), (.105, .22, .20, .09), (0, .22, .22, .095),
                 (-.085, .32, .17, .085), (.085, .32, .17, .085), (0, .33, .185, .085),
                 (-.14, .16, .13, .075), (.14, .16, .13, .075), (-.15, .27, .10, .07), (.15, .27, .10, .07),
                 (-.095, .40, .135, .072), (.095, .40, .135, .072), (0, .42, .15, .076),                    # over the front of the foot, down to the toes
                 (-.19, .12, .09, .07), (.19, .12, .09, .07), (-.20, .26, .09, .07), (.20, .26, .09, .07),   # shaggy flanks: bumps that break the silhouette
                 (-.18, .39, .09, .062), (.18, .39, .09, .062)]
        for k, (dx, dz, dy, r) in enumerate(tufts):
            col = 'foot_hair_light' if k % 3 == 1 else 'foot_hair'
            m.ellipsoid(g, (s * .25 + dx, dy, dz), (r, r * .92, r * 1.02), col, seg=14, rings=9)
        for k in (-1, 0, 1):
            m.ellipsoid(g, (s * .25 + k * .075, .055, .50 - abs(k) * .02), (.050, .042, .062), 'toe', seg=12, rings=8)
            m.ellipsoid(g, (s * .25 + k * .075, .092, .485 - abs(k) * .02), (.042, .034, .044), 'foot_hair', seg=10, rings=7)   # hair on the toe
    m.leg_color = 'trouser'
    return finish(m, 'hobbit_' + skin, height=1.88,
                  patterns={'tunic': 'cloth', 'tunic_dark': 'cloth', 'vest': 'cloth', 'belt': 'cloth', 'scarf': 'cloth',
                            'body': 'skin', 'trouser': 'cloth', 'nose': 'skin', 'toe': 'skin',
                            'foot_hair': 'hair', 'foot_hair_light': 'hair'})


# ---------------------------------------------------------------------------------------------------------------------
# SQUIRREL
# ---------------------------------------------------------------------------------------------------------------------
def make_squirrel():
    m = Model('squirrel')
    hc = (0, 1.58, .025); hr = (.60, .53, .41)
    add.body(m, hc, hr)
    # small round tufted ears
    for side, s in (('L', -1), ('R', 1)):
        g = m.group('Ear_' + side, (s * .40, hc[1] + .42, -.03), 'Head')
        m.ellipsoid(g, (s * .42, hc[1] + .47, -.02), (.145, .17, .10), 'body', seg=24, rings=16)
        m.ellipsoid(g, (s * .42, hc[1] + .49, .06), (.09, .115, .022), 'inner', seg=20, rings=12)
        p = bezier([[s * .42, hc[1] + .56, -.02], [s * .43, hc[1] + .64, -.02], [s * .45, hc[1] + .72, -.02], [s * .47, hc[1] + .80, -.03]], 10)
        m.tube(g, p, np.linspace(.085, .008, len(p)), 'A5602F', sides=10)
    eyes(m, hc, hr, x=.232, y_offset=.09, size=(.178, .208), asym=.018)
    # cheek pouches + pale muzzle + buck teeth
    for s in (-1, 1):
        m.ellipsoid('Head', (s * .30, hc[1] - .20, .27), (.20, .15, .14), 'light', seg=24, rings=14)
    add.muzzle(m, hc, hr)
    yy = hc[1] - .19; zz = head_surface(hc, hr, 0, yy)
    for s in (-1, 1):
        m.ellipsoid('Head', (s * .026, yy - .105, zz + .115), (.032, .056, .018), 'tooth', seg=14, rings=10, power=.62, tilt=s * .03)
    cheeks(m, hc, hr, x=.42, y_offset=-.09)
    arms(m, y=.94, spread=.285)
    feet(m, spread=.23, color='rim')
    # big bushy S-tail rising behind the body and curling over the back
    path = bezier([[.12, .46, -.14], [.42, .30, -.95], [.62, 1.55, -1.10], [.18, 2.0, -.52]], 38)
    t = np.linspace(0, 1, len(path)); r = .085 + .20 * np.sin(np.pi * t) ** .8 + .03 * t
    r[-4:] = [r[-5] * .86, r[-5] * .66, r[-5] * .38, .02]
    add.colored_tail(m, path, r)
    return finish(m, 'squirrel', height=1.95)



# ---------------------------------------------------------------------------------------------------------------------
# ACCESSORIES (parametric; attach to the Head/Body group of any builder via HEADS)
# ---------------------------------------------------------------------------------------------------------------------
def hat_chef(m, hc, hr, color='FFFDF5'):
    top = hc[1] + hr[1] * .80
    m.tube('Head', ring_path((hc[0], top, hc[2] - .02), hr[0] * .74, hr[2] * .74, 26), .075, color, sides=10)
    m.ellipsoid('Head', (hc[0], top + .32, hc[2] - .02), (hr[0] * .86, .30, hr[2] * .86), color, seg=26, rings=16)
    for dx, dz in [(-.30, .10), (.30, .10), (0, -.28), (-.2, -.18), (.2, -.18)]:
        m.ellipsoid('Head', (hc[0] + dx, top + .44, hc[2] + dz), (.22, .20, .22), color, seg=18, rings=12)
    m.ellipsoid('Head', (hc[0], top + .62, hc[2]), (.34, .16, .30), color, seg=20, rings=12)


def hat_straw(m, hc, hr, color='E3C07A', band='B3436B'):
    top = hc[1] + hr[1] * .80
    m.ellipsoid('Head', (hc[0], top - .01, hc[2]), (hr[0] * 1.60, .055, hr[2] * 1.60), color, seg=30, rings=10)
    m.ellipsoid('Head', (hc[0], top + .12, hc[2]), (hr[0] * .80, .24, hr[2] * .80), color, seg=26, rings=14)
    m.tube('Head', ring_path((hc[0], top + .04, hc[2]), hr[0] * .81, hr[2] * .81, 26), .032, band, sides=8)


def hat_wizard(m, hc, hr, color='4C58A0', star='E9C06B', tall=1.0):
    """Pointed hat; `tall` scales the cone height (1.0 = the spike's 1.0 m cone).  Zephyr uses .66: with the full cone his figure
    was 16 % taller than the pack (gate: +/-10 %)."""
    top = hc[1] + hr[1] * .78
    m.ellipsoid('Head', (hc[0], top, hc[2]), (hr[0] * 1.30, .05, hr[2] * 1.30), color, seg=30, rings=10)
    pts = np.array([[hc[0] + .22 * tall * t ** 2, top + .02 + 1.0 * tall * t, hc[2] - .10 * t] for t in np.linspace(0, 1, 14)])
    rad = np.linspace(.50 * hr[0] / .55, .02, 14)
    m.tube('Head', pts, rad, color, sides=18)
    m.tube('Head', ring_path((hc[0], top + .06, hc[2]), hr[0] * .80, hr[2] * .80, 24), .03, star, sides=8)
    for k, (dx, dy) in enumerate([(.05, .35), (-.12, .55), (.12, .72)]):
        dy = dy * tall
        m.ellipsoid('Head', (hc[0] + dx + .08, top + dy, hc[2] + .30 - dy * .15), (.04, .04, .02), star, seg=10, rings=6)


def crown(m, hc, hr, gold='E9C06B', gem='B3436B'):
    top = hc[1] + hr[1] * .86
    m.tube('Head', ring_path((hc[0], top, hc[2] + .02), hr[0] * .78, hr[2] * .78, 28), .05, gold, sides=10)
    for k in range(5):
        a = k * 2 * math.pi / 5 + math.pi / 2
        x, z = hc[0] + hr[0] * .78 * math.cos(a), hc[2] + .02 + hr[2] * .78 * math.sin(a)
        pts = np.array([[x, top - .02, z], [x * 1.0, top + .14, z], [x * 1.0, top + .26, z]])
        m.tube('Head', pts, [.06, .045, .012], gold, sides=8)
        m.ellipsoid('Head', (x, top + .28, z), (.045, .045, .045), gem if k % 2 == 0 else 'FFFFFF', seg=10, rings=8)
    m.ellipsoid('Head', (hc[0], top + .01, hc[2] + .02 + hr[2] * .80), (.06, .06, .04), gem, seg=10, rings=8)


def helmet_acorn(m, hc, hr, color='9A6A3E', nub='6B4A2D'):
    top = hc[1] + hr[1] * .70
    m.ellipsoid('Head', (hc[0], top + .10, hc[2]), (hr[0] * 1.02, .36, hr[2] * 1.02), color, seg=30, rings=16)
    m.ellipsoid('Head', (hc[0], top + .45, hc[2]), (.07, .12, .07), nub, seg=10, rings=8)
    m.tube('Head', ring_path((hc[0], top - .04, hc[2]), hr[0] * 1.0, hr[2] * 1.0, 28), .045, nub, sides=8)


def beard(m, hc, hr, color='F3F0F6', size=1.0):
    y = hc[1] - hr[1] * .78
    m.ellipsoid('Head', (0, y - .02, hc[2] + .28), (.34 * size, .26 * size, .20), color, seg=26, rings=16)
    for s in (-1, 1):
        m.ellipsoid('Head', (s * .26 * size, y + .10, hc[2] + .23), (.17 * size, .20 * size, .14), color, seg=18, rings=12)
    m.ellipsoid('Head', (0, y - .26 * size, hc[2] + .26), (.20 * size, .30 * size, .15), color, seg=20, rings=12)
    m.ellipsoid('Head', (0, y - .50 * size, hc[2] + .24), (.11 * size, .22 * size, .10), color, seg=16, rings=10)
    for s in (-1, 1):  # moustache
        m.ellipsoid('Head', (s * .09, y + .20, hc[2] + .39), (.12 * size, .05, .06), color, seg=14, rings=8, tilt=s * .35)


def glasses(m, hc, hr, x=.215, y_off=.076, frame='E9C06B', rad=(.205, .225)):
    for s in (-1, 1):
        ex, ey = s * x, hc[1] + y_off + (.013 if s < 0 else 0)
        ez = head_surface(hc, hr, ex, ey) + .105
        t = np.linspace(0, 2 * math.pi, 28)
        m.tube('Head', np.c_[ex + rad[0] * np.cos(t), ey + rad[1] * np.sin(t), np.full_like(t, ez)], .014, frame, sides=7)
    ez = head_surface(hc, hr, 0, hc[1] + y_off + .1) + .11
    m.tube('Head', [[-x + rad[0] - .01, hc[1] + y_off + .09, ez], [0, hc[1] + y_off + .13, ez + .02], [x - rad[0] + .01, hc[1] + y_off + .09, ez]], .012, frame, sides=7)


def scarf(m, y, rx, rz, color, group='Body', z0=0.0):
    m.tube(group, ring_path((0, y, z0), rx, rz, 26), .055, color, sides=8)
    m.ellipsoid(group, (rx * .45, y - .16, z0 + rz * .90), (.07, .17, .05), color, seg=12, rings=8)


def head_ring(m, hc, hr, dy, color, r=.045, grow=1.03, group='Head'):
    """A band hugging the head ellipsoid at height hc+dy (headbands, hat bands)."""
    k = math.sqrt(max(1 - (dy / hr[1]) ** 2, .01)) * grow
    m.tube(group, ring_path((hc[0], hc[1] + dy, hc[2]), hr[0] * k, hr[2] * k, 30), r, color, sides=8)


def apron_body(m, y=.66, color='FFF6E0', trim='E58FA6', ry=.40, rx=.30, z=.30):
    """Apron/bib for stock add.body() species: a panel proud of the belly + waist tie."""
    m.ellipsoid('Body', (0, y, z), (rx, ry, .10), color, seg=24, rings=14)
    m.tube('Body', ring_path((0, y + ry * .55, 0), .47, .365, 30), .03, trim, sides=7)
    m.tube('Body', bezier([[-rx * .8, y + ry * .62, z + .07], [-rx * .3, y + ry * .74, z + .10], [rx * .3, y + ry * .74, z + .10], [rx * .8, y + ry * .62, z + .07]], 10), .018, trim, sides=6)


def strip_fairy_bun(m):
    """Remove the stock fairy hair bun + flower so a hat can sit there."""
    g = m.groups[m.lookup['Head']]
    keep = []
    for sh in g.shapes:
        c = sh.vertices.mean(axis=0)
        if c[0] < -.15 and c[1] > 2.2: continue
        keep.append(sh)
    g.shapes = keep


def set_wand(m, builder):
    g = m.lookup['Wand']
    m.groups[g].shapes = []
    builder(m, 'Wand')


def wand_spoon(m, g):
    m.tube(g, bezier([[.477, .951, .135], [.52, 1.10, .16], [.57, 1.25, .17], [.62, 1.34, .17]], 14), .022, 'B98A5A', sides=8)
    m.ellipsoid(g, (.645, 1.40, .17), (.075, .095, .028), 'B98A5A', seg=14, rings=10)


def wand_staff(m, g, top_color='6FD6C4'):
    m.tube(g, bezier([[.477, .90, .135], [.50, 1.40, .14], [.54, 1.90, .14], [.57, 2.25, .14]], 18), .026, '8A5A33', sides=8)
    m.ellipsoid(g, (.575, 2.34, .14), (.075, .11, .075), top_color, seg=14, rings=10)


def wand_none(m, g):
    m.ellipsoid(g, (.477, .99, .10), (.01, .01, .01), 'body', seg=8, rings=6)  # keep group non-empty for the rig


def apron(m, color='FFF6E0', trim='E58FA6'):
    m.ellipsoid('Body', (0, .93, .17), (.215, .24, .115), color, seg=24, rings=14)
    m.ellipsoid('Body', (0, .62, .21), (.30, .24, .12), color, seg=24, rings=14)
    m.tube('Body', bezier([[-.2, 1.12, .20], [-.07, 1.20, .27], [.07, 1.20, .27], [.2, 1.12, .20]], 12), .014, trim, sides=6)
    m.tube('Body', bezier([[-.28, .42, .29], [-.1, .38, .33], [.1, .38, .33], [.28, .42, .29]], 12), .016, trim, sides=6)


def pouch(m, color='C79A55', cord='E9C06B'):
    m.ellipsoid('Body', (.25, .62, .17), (.14, .15, .13), color, seg=18, rings=12)
    m.tube('Body', bezier([[.20, .76, .17], [.24, .79, .20], [.28, .79, .19], [.30, .76, .16]], 8), .012, cord, sides=6)
    m.ellipsoid('Body', (.25, .82, .17), (.045, .035, .04), cord, seg=10, rings=6)


def medallion(m, gold='E9C06B', stone='B3436B'):
    p = ring_path((0, 1.26, .0), .20, .17, 24)
    m.tube('Body', p, .018, gold, sides=7)
    m.ellipsoid('Body', (0, 1.00, .26), (.07, .09, .035), gold, seg=14, rings=10)
    m.ellipsoid('Body', (0, 1.00, .29), (.035, .05, .02), stone, seg=10, rings=8)


# --- accessories of the three feature NPC fairies and of Lily (addendum 4.4, review R.9) --------------------------------
def ribbon_bow(m, c, color, size=1.0, group='Head', knot='FFFFFF', tails=True):
    """A bow: two loops, a knot and two short tails, centred at c (head surface point, +z = out of the head)."""
    c = np.asarray(c, float)
    for s in (-1, 1):
        m.ellipsoid(group, c + np.array([s * .125 * size, .01 * size, .02]), (.115 * size, .085 * size, .045 * size), color,
                    seg=20, rings=12, tilt=s * .30)
    m.ellipsoid(group, c + np.array([0, 0, .045 * size]), (.05 * size, .05 * size, .04 * size), knot, seg=14, rings=10)
    if tails:
        for s in (-1, 1):
            m.tube(group, [c + np.array([s * .03 * size, -.02 * size, .04]), c + np.array([s * .09 * size, -.12 * size, .05]),
                           c + np.array([s * .13 * size, -.22 * size, .045])], [.032 * size, .028 * size, .02 * size], color,
                   sides=8, depth=.012)


def hat_hard(m, hc, hr, color='F2B63C', stripe='FFF3C4'):
    """Builder's hard hat: dome, short front peak, a raised centre ridge and a rim band.  The peak sits above the eye line (36 degree camera)."""
    top = hc[1] + hr[1] * .82
    m.ellipsoid('Head', (hc[0], top + .03, hc[2] - .01), (hr[0] * 1.10, .34, hr[2] * 1.18), color, seg=32, rings=20, power=.9)
    m.ellipsoid('Head', (hc[0], top - .07, hc[2] + .24), (hr[0] * .96, .030, .36), color, seg=28, rings=10)          # peak
    m.tube('Head', ring_path((hc[0], top - .07, hc[2] - .01), hr[0] * 1.08, hr[2] * 1.16, 30), .042, color, sides=8)    # rim band
    ridge = np.array([[hc[0], top + .05 + .31 * math.sin(math.pi * t) ** .6, hc[2] - .42 + .84 * t] for t in np.linspace(.04, .96, 16)])
    m.tube('Head', ridge, .062, stripe, sides=9)                                                                        # raised centre ridge
    m.ellipsoid('Head', (hc[0], top + .27, hc[2] + .26), (.085, .060, .060), 'FFF8E0', seg=14, rings=10)                # little lamp
    m.ellipsoid('Head', (hc[0], top + .27, hc[2] + .315), (.050, .040, .025), 'F2F2C8', seg=12, rings=8)


def tool_belt(m, leather='7A5237', buckle='E9C06B', metal='C9CFDC'):
    """A broad belt at the bodice waist with two pouches, a hammer loop and a pencil: all of it sits outside the dress surface."""
    m.tube('Body', ring_path((0, 1.07, .0), .268, .256, 34), .046, leather, sides=8)
    m.ellipsoid('Body', (0, 1.07, .262), (.062, .052, .028), buckle, seg=14, rings=8)
    for s in (-1, 1):                                           # two pouches left and right of the belly
        m.ellipsoid('Body', (s * .215, .96, .205), (.088, .12, .082), leather, seg=18, rings=12)
        m.ellipsoid('Body', (s * .215, 1.04, .212), (.095, .030, .088), 'B4875A', seg=14, rings=8)
    m.tube('Body', [[.255, .98, .075], [.300, .86, .090], [.322, .73, .095]], .020, '8A5A33', sides=7)               # hammer handle
    m.ellipsoid('Body', (.322, .70, .095), (.075, .048, .048), metal, seg=14, rings=10, tilt=.1)                        # hammer head
    m.tube('Body', [[-.07, 1.03, .245], [-.095, 1.15, .262]], .012, 'F2B63C', sides=6)                              # pencil


def wand_hammer(m, g):
    m.tube(g, bezier([[.477, .90, .135], [.50, 1.12, .14], [.53, 1.34, .14], [.55, 1.56, .14]], 14), .026, '8A5A33', sides=8)
    m.ellipsoid(g, (.56, 1.63, .14), (.15, .075, .075), 'C9CFDC', seg=16, rings=10)
    m.ellipsoid(g, (.44, 1.63, .14), (.045, .06, .06), '8E96A8', seg=12, rings=8)


def wand_ribbon(m, g, color='E58FA6', color2='F7C6D2'):
    """A short stick with two long curling ribbons (the furnisher's swatch ribbons)."""
    m.tube(g, bezier([[.477, .93, .135], [.50, 1.10, .14], [.52, 1.24, .14], [.54, 1.34, .14]], 12), .02, 'B98A5A', sides=8)
    for col, sgn, dz in ((color, 1, .0), (color2, -1, .03)):
        pts = bezier([[.54, 1.34, .14 + dz], [.54 + .32 * sgn, 1.52, .16 + dz], [.54 - .10 * sgn, 1.74, .18 + dz], [.54 + .22 * sgn, 1.94, .15 + dz]], 22)
        m.tube(g, pts, np.linspace(.050, .030, len(pts)), col, sides=8, depth=.012)


def measuring_tape(m, tape='F2D36B', tick='A67C3D'):
    """Neck loop of a tailor's measuring tape with two free ends hanging down the front and tick bands on the ends."""
    m.tube('Body', ring_path((0, 1.285, .005), .205, .190, 30), .034, tape, sides=8, depth=.016)
    for s, dx in ((-1, .09), (1, .12)):
        pts = bezier([[s * dx, 1.255, .205], [s * (dx + .02), 1.12, .245], [s * (dx + .04), .98, .262], [s * (dx + .05), .84, .268]], 14)
        m.tube('Body', pts, np.linspace(.040, .036, len(pts)), tape, sides=8, depth=.013)
        for k, t in enumerate(np.linspace(.12, .96, 6)):
            i = int(t * (len(pts) - 1))
            m.ellipsoid('Body', pts[i] + np.array([0, 0, .006]), (.034, .0085, .016), tick, seg=8, rings=6)
    m.ellipsoid('Body', (-.0, 1.268, .205), (.045, .045, .018), tick, seg=12, rings=8)                                  # the tape's metal tip


def wand_needle(m, g, steel='D5DAE6', thread='E58FA6'):
    """A giant sewing needle with an eye and a loose thread curling down from it."""
    m.tube(g, bezier([[.477, .90, .135], [.50, 1.30, .14], [.54, 1.86, .14], [.57, 2.26, .14]], 18), np.linspace(.030, .020, 18), steel, sides=8)
    m.ellipsoid(g, (.575, 2.33, .14), (.028, .060, .028), steel, seg=10, rings=8)
    t = np.linspace(0, 2 * math.pi, 20)
    m.tube(g, np.c_[.58 + .050 * np.cos(t), 2.47 + .100 * np.sin(t), np.full_like(t, .14)], .017, steel, sides=7)      # the eye
    thr = bezier([[.58, 2.47, .15], [.80, 2.42, .18], [.62, 2.10, .21], [.82, 1.86, .17]], 22)
    m.tube(g, thr, .016, thread, sides=7)
    m.ellipsoid(g, (.82, 1.82, .17), (.034, .034, .034), thread, seg=8, rings=6)                                       # knot


# ---------------------------------------------------------------------------------------------------------------------
# NAMED NPC FAIRIES (stock make_fairy under palette override + accessories)  => all keep m.name == 'fairy' (flight rig)
# ---------------------------------------------------------------------------------------------------------------------
FAIRY_SKINS = {   # player fairy skins that already exist as texture swaps in the source package (README: Meadow/Stardust/Dusk)
    'fairy_dusk': dict(dress='8198B8', petal='BCC8E0', wing='CFADCA', wing_inner='E7CFDF', wing_rim='A681A9'),
    'fairy_stardust': dict(dress='B0A1D6', petal='D2C7E7', wing='B6D5E8', wing_inner='D6E4EB', wing_rim='8CA6C5'),
}


def _fairy(overrides):
    with palette('fairy', overrides):
        m = geo.make_fairy()
    m._base_h = top_y(m)
    return m


def make_fairy_skin(name):
    m = _fairy(FAIRY_SKINS[name])
    return finish(m, name, height=1.95, clip_set='full', base=m._base_h)


def make_mayor():       # Borgmester Hyldeblomst
    m = _fairy(dict(hair='DAD6E8', hair_light='F2EFF8', dress='9B86D6', petal='B9A9E8', wing='E6DDF3', wing_inner='F7F2E8',
                    wing_rim='B49ACE', gold='E3C372'))
    hc, hr = HEADS['fairy']
    glasses(m, hc, hr)
    medallion(m)
    set_wand(m, lambda mm, g: wand_staff(mm, g, 'F7F2E8'))
    return finish(m, 'fairy_mayor', height=1.98, clip_set='npc_flyer', base=m._base_h)


def make_baker():       # Bagerfe Rosmarin
    m = _fairy(dict(hair='B27A4A', hair_light='CF9560', dress='F0B4B8', petal='F8D2D2', wing='F2D9E8', wing_inner='FBEFF4', wing_rim='D7A1C0'))
    strip_fairy_bun(m)
    hc, hr = HEADS['fairy']
    hat_chef(m, (hc[0], hc[1] + .02, hc[2]), hr)
    apron(m)
    set_wand(m, wand_spoon)
    return finish(m, 'fairy_baker', height=1.93, clip_set='npc_flyer', base=m._base_h)


def make_shopkeeper():  # butiksfe Kloevermynte
    m = _fairy(dict(hair='E8A5BE', hair_light='F5C7D6', dress='A8D8B9', petal='C9E8CF', wing='D7EFE0', wing_inner='A8D8B9',
                    wing_rim='6FB38C', gold='E3C372'))
    pouch(m)
    set_wand(m, wand_none)
    return finish(m, 'fairy_shopkeeper', height=1.92, clip_set='npc_flyer', base=m._base_h)


def make_king():        # Fekongen
    m = _fairy(dict(hair='ECE9F2', hair_light='FFFFFF', dress='5D4FA3', petal='8575C6', wing='F0DDA0', wing_inner='FAF0CC',
                    wing_rim='C9A24A', gold='E9C06B'))
    strip_fairy_bun(m)
    hc, hr = HEADS['fairy']
    beard(m, hc, hr, 'F4F1F8', 1.0)
    crown(m, (hc[0], hc[1] + .02, hc[2]), hr)
    medallion(m)
    set_wand(m, lambda mm, g: wand_staff(mm, g, 'B3436B'))
    return finish(m, 'fairy_king', height=2.08, clip_set='npc_flyer', base=m._base_h)


def make_wizard():      # fairy_wizard (math quiz)
    m = _fairy(dict(hair='C9CCDD', hair_light='EEF0F8', dress='3E4C8C', petal='5D6FB5', wing='B8D4EC', wing_inner='D8EAF6',
                    wing_rim='6FA0C9', gold='E9C06B'))
    strip_fairy_bun(m)
    hc, hr = HEADS['fairy']
    beard(m, hc, hr, 'E9ECF4', .85)
    hat_wizard(m, (hc[0], hc[1] + .02, hc[2]), hr, tall=.66)
    set_wand(m, lambda mm, g: wand_staff(mm, g, '6FD6C4'))
    return finish(m, 'fairy_wizard', height=2.0, clip_set='npc_flyer', base=m._base_h)


def make_lily():        # Fe-barnet Lily (review R.9: the one NPC the art spike never baked): a child, sunny dress, two big ribbons
    m = _fairy(dict(hair='C97B45', hair_light='E6A06A', dress='F3C04A', petal='F8DC86', wing='FBE5F0', wing_inner='FFF7EE',
                    wing_rim='E7A9C4', gold='E3C372'))
    # two ribbons tied round the stock side locks (the bun and its flower stay: a child keeps her bun)
    for s in (-1, 1):
        ribbon_bow(m, (s * .545, 2.10, .215), 'E85E8C', size=1.25, knot='FFE9F1')
    set_wand(m, wand_none)
    return finish(m, 'fairy_lily', height=1.80, clip_set='npc_flyer', base=m._base_h)


def make_builder():     # Toemrerfe Hasselnoed (addendum 4.4): hard hat + tool belt + hammer
    m = _fairy(dict(hair='7A4A2A', hair_light='9B6540', dress='D9873C', petal='EDB26B', wing='E2EFE6', wing_inner='F5FAF2',
                    wing_rim='8DB59C', gold='E3C372'))
    strip_fairy_bun(m)
    hc, hr = HEADS['fairy']
    hat_hard(m, (hc[0], hc[1] + .02, hc[2]), hr)
    tool_belt(m)
    set_wand(m, wand_hammer)
    return finish(m, 'fairy_builder', height=1.95, clip_set='npc_flyer', base=m._base_h)


def make_furnisher():   # Moebelfe Stokrose (addendum 4.4): apron + ribbons
    m = _fairy(dict(hair='A0522D', hair_light='C47445', dress='D4739A', petal='EFA7C2', wing='F6DDEA', wing_inner='FCEFF5',
                    wing_rim='C98BAF', gold='E3C372'))
    hc, hr = HEADS['fairy']
    apron(m, color='FFF2D6', trim='7FB59A')
    ribbon_bow(m, (-.34, 2.16, .30), '5FA98A', size=1.45, knot='FFF2D6')
    set_wand(m, wand_ribbon)
    return finish(m, 'fairy_furnisher', height=1.94, clip_set='npc_flyer', base=m._base_h)


def make_tailor():      # Skraedderfe Fingerboel (addendum 4.4): measuring tape + needle
    m = _fairy(dict(hair='2F2A4A', hair_light='4A4470', dress='6E7FC4', petal='9AA8E0', wing='DDE8F6', wing_inner='F2F7FC',
                    wing_rim='8FA6D2', gold='E3C372'))
    measuring_tape(m)
    set_wand(m, wand_needle)
    return finish(m, 'fairy_tailor', height=1.96, clip_set='npc_flyer', base=m._base_h)


# ---------------------------------------------------------------------------------------------------------------------
# MOUSE: Pippin Boegeknop (villager animal; lost-cat quest giver)
# ---------------------------------------------------------------------------------------------------------------------
def make_pippin():
    m = Model('mouse')
    hc = (0, 1.52, .025); hr = (.58, .52, .41)
    add.body(m, hc, hr)
    for side, s in (('L', -1), ('R', 1)):
        g = m.group('Ear_' + side, (s * .42, hc[1] + .34, -.03), 'Head')
        m.ellipsoid(g, (s * .52, hc[1] + .52, -.03), (.31, .33, .085), 'body', seg=28, rings=18, tilt=-s * .22)
        m.ellipsoid(g, (s * .52, hc[1] + .52, .04), (.21, .23, .025), 'inner', seg=22, rings=14, tilt=-s * .22)
    eyes(m, hc, hr, x=.225, y_offset=.085, size=(.172, .206), asym=.02)
    cheeks(m, hc, hr, x=.40, y_offset=-.13)
    y = hc[1] - .16; z = head_surface(hc, hr, 0, y)
    m.ellipsoid('Head', (0, y, z + .05), (.19, .13, .17), 'light', seg=26, rings=16)
    m.ellipsoid('Head', (0, y + .035, z + .215), (.06, .048, .045), 'inner', seg=14, rings=10)
    for s in (-1, 1):
        for k, dy in enumerate((.05, 0, -.05)):
            m.tube('Head', [[s * .13, y + .02 + dy * .3, z + .19], [s * .36, y + .04 + dy, z + .15], [s * .60, y + .06 + dy * 1.6, z + .02]], .006, 'rim', sides=5)
    for s in (-1, 1):
        m.ellipsoid('Head', (s * .024, y - .105, z + .17), (.03, .05, .016), 'tooth', seg=12, rings=8, power=.62)
    arms(m, y=.94, spread=.275)
    feet(m, spread=.22)
    g = m.group('Tail', (.28, .44, -.14))
    path = bezier([[.28, .44, -.14], [.85, .20, -.30], [1.05, .70, -.42], [.95, 1.12, -.30]], 30)
    m.tube(g, path, np.linspace(.055, .016, 30), 'inner', sides=12)
    # beech-bud hat, scarf and satchel
    top = hc[1] + hr[1] * .82
    m.ellipsoid('Head', (0, top + .13, hc[2] - .02), (.30, .34, .30), 'hat', seg=26, rings=16, power=.9)
    m.tube('Head', bezier([[0, top + .40, hc[2] - .02], [.03, top + .52, hc[2] + .02], [.10, top + .60, hc[2] + .10], [.20, top + .60, hc[2] + .14]], 10),
           np.linspace(.07, .012, 10), 'hat_dark', sides=8)
    m.tube('Head', ring_path((0, top - .02, hc[2] - .02), .335, .33, 26), .05, 'hat_dark', sides=8)
    scarf(m, 1.10, .43, .33, 'scarf')
    # satchel strap (review: the spike's strap was a thin tube floating INSIDE the stubby arms, so it read as a stick).  Now a broad flat band
    # that hugs the chest in the free gap between the two arms (x -0.2..0.2), crosses from the right shoulder to the left hip and carries a
    # real satchel (body + flap + gold clasp) in front of the hip.
    bc, br = (0, .77, 0), (.449, .633, .333)
    waypoints = [(.33, 1.27), (.22, 1.15), (.10, 1.02), (-.01, .88), (-.12, .75), (-.23, .63), (-.31, .54)]
    pts = np.array([[x, y, head_surface(bc, br, x, y) + .042] for x, y in waypoints])
    m.tube('Body', pts, .088, 'strap', sides=10, depth=.030)
    sx, sy = -.40, .50
    sz = head_surface(bc, br, sx, sy) + .03
    m.ellipsoid('Body', (sx, sy - .03, sz), (.165, .155, .105), 'leather', seg=22, rings=14)
    m.ellipsoid('Body', (sx, sy + .075, sz + .02), (.172, .075, .112), 'strap', seg=20, rings=10)       # flap
    m.ellipsoid('Body', (sx + .01, sy + .02, sz + .10), (.036, .042, .018), 'gold', seg=10, rings=8)    # clasp
    m.leg_color = 'body'
    return finish(m, 'mouse_pippin', height=1.9, clip_set='villager', patterns={'hat': 'cloth', 'hat_dark': 'cloth', 'scarf': 'cloth', 'strap': 'cloth', 'leather': 'cloth'})


# ---------------------------------------------------------------------------------------------------------------------
# RECOLOUR VILLAGERS (stock builder + palette + accessory); the cheap way to populate Hyggebyen
# ---------------------------------------------------------------------------------------------------------------------
def make_morfar_mis():     # the lost cat: grey old cat with a sardine
    with palette('cat', dict(body='A9A6B8', light='D3D0DE', inner='D9A9B4', rim='6D6A82', belly='F1EEF7')):
        m = geo.make_cat()
    base = top_y(m)
    hc, hr = HEADS['cat']
    y = hc[1] - .19; z = head_surface(hc, hr, 0, y)
    m.ellipsoid('Head', (.02, y - .005, z + .05), (.30, .05, .05), 'D9DEE8', seg=20, rings=10, tilt=.08)
    m.ellipsoid('Head', (-.34, y - .005, z + .05), (.07, .09, .035), 'AEB8CC', seg=12, rings=8)
    m.ellipsoid('Head', (.02, y + .02, z + .095), (.26, .02, .015), '7C8AA6', seg=12, rings=6)
    for s in (-1, 1):  # bushy old-man eyebrows
        m.ellipsoid('Head', (s * .245, hc[1] + .33, head_surface(hc, hr, s * .245, hc[1] + .33) + .02), (.14, .035, .05), 'F3F1F8', seg=14, rings=8, tilt=-s * .25)
    return finish(m, 'cat_morfar_mis', height=1.95, clip_set='villager', base=base)


def make_guard_oak():
    with palette('bear', dict(body='8E6B52', light='B79274', belly='D9BF9C', rim='6D4F3C')):
        m = geo.make_bear()
    base = top_y(m)
    hc, hr = HEADS['bear']
    helmet_acorn(m, hc, hr)
    scarf(m, 1.02, .42, .31, '4D7A3C')
    return finish(m, 'bear_guard', height=1.95, clip_set='villager', base=base, patterns={'4D7A3C': 'cloth', '9A6A3E': 'cloth'})


def make_farmer_rosa():
    with palette('rabbit', dict(body='C9A07A', light='E6CBA6', belly='F4E4CC', rim='9A7753')):
        m = geo.make_rabbit()
    base = top_y(m)
    hc, hr = HEADS['rabbit']
    hat_straw(m, (hc[0], hc[1] - .02, hc[2]), hr)
    apron_body(m, .60, 'E7D6A8', '6B9A3E', ry=.42, rx=.30, z=.27)
    return finish(m, 'rabbit_farmer', height=1.95, clip_set='villager', base=base, patterns={'E7D6A8': 'cloth', '6B9A3E': 'cloth'})


def make_smith():
    with palette('raccoon', dict(body='7C7487', light='C9C0CC', belly='D8D1DB', rim='3B3447')):
        m = add.make_raccoon()
    base = top_y(m)
    apron_body(m, .66, '5B4338', 'C9A27A')
    hc, hr = HEADS['raccoon']
    head_ring(m, hc, hr, .30, 'B3436B', r=.06)   # smith's headband
    return finish(m, 'raccoon_smith', height=1.95, clip_set='villager', base=base, patterns={'5B4338': 'cloth', 'C9A27A': 'cloth'})


def make_postman():
    with palette('penguin', dict(body='4F5C7A', rim='343C55')):
        m = add.make_penguin()
    base = top_y(m)
    hc, hr = HEADS['penguin']
    top = hc[1] + hr[1] * .72
    m.ellipsoid('Head', (0, top + .08, hc[2] + .02), (.46, .20, .44), '3E7D8F', seg=26, rings=12)
    m.ellipsoid('Head', (0, top - .02, hc[2] + .34), (.42, .05, .30), '2F6070', seg=20, rings=8)
    m.ellipsoid('Body', (-.28, .74, .22), (.16, .26, .10), 'D9B16A', seg=18, rings=12, tilt=.5)
    return finish(m, 'penguin_postman', height=1.85, clip_set='villager', base=base)


# ---------------------------------------------------------------------------------------------------------------------
# FARM ANIMALS
# ---------------------------------------------------------------------------------------------------------------------
def make_chick(adult=False, duck=False):
    pal = dict(body='FFFFFF', light='FFF6EA', belly='FFFFFF', rim='D9B48A', inner='F4A25C', comb='E5738A', beak='F59A3E') if adult else (dict(body='FFF0A0', light='FFF8CF', belly='FFF8CF', comb='F59A3E', beak='F59A3E', rim='E8C25E') if duck else {})
    with palette('chick', pal):
        m = Model('chick')
    hc = (0, 1.16, .03); hr = (.60, .55, .46)
    m.group('Body', (0, .62, 0))
    m.ellipsoid('Body', (0, .62, 0), (.47, .53, .42), 'body', seg=34, rings=22, power=.9)
    m.ellipsoid('Body', (0, .56, .33), (.30, .38, .08), 'belly', seg=26, rings=16)
    m.group('Head', (0, hc[1] - .30, 0))
    m.ellipsoid('Head', hc, hr, 'body', seg=40, rings=26, power=.96)
    eyes(m, hc, hr, x=.22, y_offset=.08, size=(.16, .19), asym=.02)
    cheeks(m, hc, hr, x=.38, y_offset=-.10)
    yb = hc[1] - .10; zb = head_surface(hc, hr, 0, yb)
    if duck:
        m.ellipsoid('Head', (0, yb - .02, zb + .13), (.19, .05, .17), 'beak', seg=22, rings=12, power=.8)
        m.ellipsoid('Head', (0, yb - .075, zb + .11), (.15, .035, .13), 'F28A35', seg=18, rings=10)
        m.ellipsoid('Head', (0, hc[1] + hr[1] * .92, hc[2] + .05), (.05, .09, .05), 'body', seg=10, rings=8)
    else:
        m.ellipsoid('Head', (0, yb + .01, zb + .10), (.115, .062, .15), 'beak', seg=22, rings=14, power=.85)
        m.ellipsoid('Head', (0, yb - .055, zb + .075), (.085, .035, .115), 'F28A35', seg=18, rings=10)
        ct = hc[1] + hr[1] * .92
        for dx, hh in [(-.10, .14), (0, .20), (.10, .14)]:
            m.ellipsoid('Head', (dx, ct + hh * .5 - .02, hc[2] + .08), (.075, hh, .07), 'comb', seg=14, rings=10)
    if adult:
        m.ellipsoid('Head', (0, yb - .20, zb + .06), (.05, .09, .04), 'comb', seg=12, rings=8)
    for side, s in (('L', -1), ('R', 1)):
        g = m.group('Arm_' + side, (s * .44, .88, .10))
        m.ellipsoid(g, (s * .46, .66, .08), (.115, .27, .21), 'rim' if adult else 'body', seg=22, rings=14, tilt=-s * .35)
        fg = m.group('Foot_' + side, (s * .20, .27, .05))
        m.ellipsoid(fg, (s * .20, .06, .17), (.15, .05, .20), 'foot', seg=18, rings=10)
        for k in (-1, 0, 1):
            m.ellipsoid(fg, (s * .20 + k * .075, .05, .33), (.035, .035, .08), 'foot', seg=10, rings=6)
    g = m.group('Tail', (0, .62, -.34))
    for k, (dx, dy) in enumerate([(-.1, 0), (0, .08), (.1, 0)]):
        m.ellipsoid(g, (dx, .66 + dy, -.42), (.07, .14, .07), 'rim' if adult else 'body', seg=12, rings=8, tilt=dx * 2)
    return finish(m, 'hen' if adult else ('duck' if duck else 'chick'), height=1.35 if adult else (1.1 if duck else 1.05), clip_set='farm_animal')


def _quad_frame(m, hc, hr, leg_color, hoof='4B3A33', leg_x=.28, zf=.34, zh=-.70):
    for prefix, z in (('Foot', zf), ('HindFoot', zh)):
        for side, s in (('L', -1), ('R', 1)):
            g = m.group(prefix + '_' + side, (s * leg_x, .375, z))
            m.ellipsoid(g, (s * leg_x, .17, z + .02), (.115, .17, .145), leg_color, seg=20, rings=14, power=.85)
            m.ellipsoid(g, (s * leg_x, .045, z + .05), (.10, .05, .13), hoof, seg=14, rings=8)
    m.leg_color = leg_color if len(leg_color) != 6 or leg_color in m.palette else 'body'


def make_lamb():
    m = Model('lamb')
    hc = (0, 1.12, .52); hr = (.42, .40, .38)
    m.group('Body', (0, .62, -.30))
    m.ellipsoid('Body', (0, .72, -.30), (.50, .46, .68), 'wool', seg=34, rings=22, power=.88)
    bc, br = (0, .72, -.30), (.50, .46, .68)
    for az, el, rr in [(0, 62, .24), (40, 50, .22), (-40, 50, .22), (90, 24, .22), (-90, 24, .22), (140, 40, .22), (-140, 40, .22),
                       (180, 56, .24), (60, 8, .22), (-60, 8, .22), (120, 10, .22), (-120, 10, .22), (20, 80, .2), (-20, 80, .2), (90, -14, .2), (-90, -14, .2)]:
        c = ell(bc, br, az, el, .96)
        m.ellipsoid('Body', c, (rr, rr * .92, rr), 'wool' if (az + el) % 3 else 'wool_dark', seg=14, rings=10)
    m.group('Head', (0, .96, .30))
    m.ellipsoid('Head', hc, hr, 'face', seg=34, rings=22)
    m.ellipsoid('Head', (0, hc[1] + .30, hc[2] - .10), (.30, .20, .27), 'wool', seg=20, rings=12)   # fringe
    for az, el in [(-30, 70), (30, 70), (0, 60)]:
        m.ellipsoid('Head', ell(hc, hr, az, el, 1.06), (.15, .13, .14), 'wool', seg=12, rings=8)
    for side, s in (('L', -1), ('R', 1)):
        g = m.group('Ear_' + side, (s * .36, hc[1] + .12, .35), 'Head')
        m.ellipsoid(g, (s * .56, hc[1] + .04, hc[2] - .05), (.24, .09, .13), 'face', seg=18, rings=12, tilt=s * .25)
        m.ellipsoid(g, (s * .56, hc[1] + .06, hc[2] - .02), (.17, .05, .09), 'inner', seg=14, rings=8, tilt=s * .25)
    eyes(m, hc, hr, x=.19, y_offset=.04, size=(.14, .165), asym=.01)
    cheeks(m, hc, hr, x=.31, y_offset=-.13)
    zn = head_surface(hc, hr, 0, hc[1] - .12)
    m.ellipsoid('Head', (0, hc[1] - .13, zn + .02), (.07, .05, .05), 'inner', seg=14, rings=10)
    m.tube('Head', bezier([[-.08, hc[1] - .22, zn - .02], [-.04, hc[1] - .27, zn], [.04, hc[1] - .27, zn], [.08, hc[1] - .22, zn - .02]], 10), .008, 'ink', sides=6)
    _quad_frame(m, hc, hr, 'leg')
    g = m.group('Tail', (0, .90, -.95))
    m.ellipsoid(g, (0, .88, -1.0), (.12, .12, .12), 'wool', seg=14, rings=10)
    m.leg_radius = .62
    return finish(m, 'lamb', height=1.35, clip_set='farm_animal', patterns={'wool': 'wool', 'wool_dark': 'wool'})


def make_calf():
    m = Model('cow')
    hc = (0, 1.14, .54); hr = (.44, .40, .40)
    m.group('Body', (0, .62, -.30))
    bc, br = (0, .70, -.30), (.48, .46, .70)
    m.ellipsoid('Body', bc, br, 'body', seg=36, rings=22, power=.86)
    for az, el, rr in [(30, 55, .20), (-120, 40, .24), (100, 15, .20), (-80, 25, .17), (170, 45, .19)]:
        c = ell(bc, br, az, el, .985)
        m.ellipsoid('Body', c, (rr, rr * .8, rr), 'patch', seg=14, rings=10, power=.8)
    m.group('Head', (0, .96, .30))
    m.ellipsoid('Head', hc, hr, 'body', seg=34, rings=22)
    zf = head_surface(hc, hr, 0, hc[1] - .18)
    m.ellipsoid('Head', (0, hc[1] - .20, zf + .02), (.27, .19, .20), 'muzzle', seg=26, rings=16, power=.8)
    for s in (-1, 1):
        m.ellipsoid('Head', (s * .09, hc[1] - .16, zf + .20), (.03, .022, .012), 'rim', seg=10, rings=6)
        m.ellipsoid('Head', (s * .24, hc[1] + .12, head_surface(hc, hr, s * .24, hc[1] + .12) - .01), (.15, .15, .06), 'patch', seg=16, rings=10, power=.8) if s > 0 else None
    for side, s in (('L', -1), ('R', 1)):
        g = m.group('Ear_' + side, (s * .38, hc[1] + .12, .35), 'Head')
        m.ellipsoid(g, (s * .56, hc[1] + .16, hc[2] - .04), (.20, .10, .13), 'body', seg=18, rings=12, tilt=s * .3)
        m.ellipsoid(g, (s * .56, hc[1] + .18, hc[2] - .01), (.13, .06, .09), 'inner', seg=14, rings=8, tilt=s * .3)
        m.ellipsoid(g, (s * .22, hc[1] + .42, hc[2] - .08), (.05, .12, .05), 'horn', seg=10, rings=8, tilt=-s * .3)
    eyes(m, hc, hr, x=.20, y_offset=.08, size=(.14, .165), asym=.01)
    cheeks(m, hc, hr, x=.33, y_offset=-.07)
    _quad_frame(m, hc, hr, 'leg', leg_x=.29)
    g = m.group('Tail', (0, .92, -1.0))
    m.tube(g, bezier([[0, .90, -.98], [0, .72, -1.15], [0, .45, -1.1], [0, .30, -1.08]], 12), .03, 'body', sides=8)
    m.ellipsoid(g, (0, .26, -1.08), (.06, .10, .06), 'patch', seg=10, rings=8)
    m.leg_radius = .7
    return finish(m, 'calf', height=1.55, clip_set='farm_animal')


def make_cub(kind):
    """Baby farm animals as scale+palette variants of shipped builders (cheapest possible: no new geometry)."""
    if kind == 'kitten':
        with palette('cat', dict(body='F4D6AE', light='FFF1DC', belly='FFF8EC', rim='C99A6D', inner='F0B8B4')):
            m = geo.make_cat()
        base = top_y(m); scarf(m, 1.02, .44, .36, 'B3436B'); m.ellipsoid('Body', (0, .9, .36), (.06, .06, .05), 'E9C06B', seg=10, rings=8)
        return finish(m, 'kitten', height=1.3, base=base, clip_set='farm_animal')
    if kind == 'bunny':
        with palette('rabbit', dict(body='F6EFE2', belly='FFFFFF', inner='F0B8C0')):
            m = geo.make_rabbit()
        base = top_y(m); scarf(m, 1.0, .40, .31, 'A8CFA0')
        return finish(m, 'bunny', height=1.45, base=base, clip_set='farm_animal')
    if kind == 'fox_cub':
        with palette('fox', dict(body='F0B27A', light='FFF1DA')):
            m = add.make_fox()
        base = top_y(m)
        return finish(m, 'fox_cub', height=1.55, base=base, clip_set='farm_animal')
    raise KeyError(kind)


def make_pup(kind='puppy'):
    """Quadruped baby (puppy / fawn): same frame as lamb/calf (Foot_* + HindFoot_* legs, quadruped IK in make_clips)."""
    m = Model(kind)
    pup = kind == 'puppy'
    hc = (0, 1.12 if pup else 1.20, .52); hr = (.44, .40, .40) if pup else (.38, .36, .36)
    bc, br = (0, .70, -.30), (.46, .44, .66) if pup else (.42, .42, .64)
    m.group('Body', (0, .62, -.30))
    m.ellipsoid('Body', bc, br, 'body', seg=34, rings=22, power=.88)
    m.ellipsoid('Body', (0, .60, .12), (.30, .34, .22), 'belly', seg=22, rings=14)
    if not pup:
        rng = np.random.default_rng(9)
        for i in range(12):
            az, el = rng.uniform(-70, 70), rng.uniform(25, 75)
            m.ellipsoid('Body', ell(bc, br, az + 180 * (i % 2), el, .985), (.07, .025, .07), 'spot', seg=10, rings=6)
    m.group('Head', (0, .96, .30))
    m.ellipsoid('Head', hc, hr, 'body', seg=34, rings=22)
    zf = head_surface(hc, hr, 0, hc[1] - .14)
    m.ellipsoid('Head', (0, hc[1] - .17, zf + .02), (.2, .14, .17), 'light', seg=22, rings=14)
    m.ellipsoid('Head', (0, hc[1] - .10, zf + .17), (.07, .05, .05), 'nose', seg=14, rings=10)
    for side, s in (('L', -1), ('R', 1)):
        g = m.group('Ear_' + side, (s * .34, hc[1] + .20, .40), 'Head')
        if pup:
            m.ellipsoid(g, (s * .45, hc[1] + .02, hc[2] - .04), (.13, .26, .11), 'ear', seg=18, rings=12, tilt=s * .15)
        else:
            tri = rounded_triangle([(s * .20, hc[1] + .24), (s * .46, hc[1] + .74), (s * .52, hc[1] + .22)], 6)
            m.pillow(g, tri, hc[2] - .1, .06, 'body')
            c = tri.mean(axis=0); m.pillow(g, c + (tri - c) * .5, hc[2] - .03, .02, 'inner')
    eyes(m, hc, hr, x=.18, y_offset=.07, size=(.13, .155), asym=.01)
    cheeks(m, hc, hr, x=.30, y_offset=-.08)
    _quad_frame(m, hc, hr, 'body' if pup else 'leg', leg_x=.27, hoof='7A5237' if pup else '3A2A30')
    g = m.group('Tail', (0, .92, -.96))
    if pup:
        m.tube(g, bezier([[0, .90, -.96], [0, 1.12, -1.12], [0, 1.30, -1.08], [0, 1.40, -.96]], 12), np.linspace(.07, .03, 12), 'body', sides=10)
    else:
        m.ellipsoid(g, (0, .92, -.99), (.07, .09, .10), 'spot', seg=12, rings=8)
    m.leg_radius = .6
    return finish(m, kind, height=1.25 if pup else 1.5, clip_set='farm_animal')


# ---------------------------------------------------------------------------------------------------------------------
# OWL (farm "baby_owl" + enemy "ugleoje")
# ---------------------------------------------------------------------------------------------------------------------
OWL_ENEMY = dict(body='3A3F66', light='5C6399', inner='2A2E4C', rim='1C2138', belly='4B5280', beak='F2C14E', feather='454B7A',
                 eye='F2C14E')


def make_owl(enemy=False):
    with palette('owl', OWL_ENEMY if enemy else {}):
        m = Model('owl')
    hc = (0, 1.30, .02); hr = (.64, .56, .44)
    m.group('Body', (0, .72, 0))
    m.ellipsoid('Body', (0, .72, 0), (.48, .62, .39), 'body', seg=36, rings=22, power=.88)
    m.ellipsoid('Body', (0, .66, .34), (.32, .44, .07), 'belly', seg=26, rings=16)
    for k, (y, w) in enumerate([(.95, .17), (.78, .20), (.60, .20), (.44, .16)]):   # breast chevrons
        m.ellipsoid('Body', (0, y, .385), (w, .035, .02), 'feather', seg=12, rings=8)
    m.group('Head', (0, hc[1] - .32, 0))
    m.ellipsoid('Head', hc, hr, 'body', seg=40, rings=26, power=.94)
    for s in (-1, 1):   # facial discs
        m.ellipsoid('Head', (s * .24, hc[1] + .04, head_surface(hc, hr, s * .24, hc[1] + .04) - .02), (.30, .30, .10), 'light', seg=28, rings=16)
    for side, s in (('L', -1), ('R', 1)):
        g = m.group('Ear_' + side, (s * .40, hc[1] + .36, -.02), 'Head')
        tri = rounded_triangle([(s * .22, hc[1] + .38), (s * .62, hc[1] + .92), (s * .66, hc[1] + .32)], 7)
        m.pillow(g, tri, -.02, .09, 'body')
    eyes(m, hc, hr, x=.245, y_offset=.04, size=(.215, .235), asym=.0)
    yb = hc[1] - .10; zb = head_surface(hc, hr, 0, yb)
    m.ellipsoid('Head', (0, yb, zb + .05), (.08, .115, .08), 'beak', seg=18, rings=12, power=.85, tilt=0)
    if not enemy:
        cheeks(m, hc, hr, x=.42, y_offset=-.10)
    arms(m, y=.80, spread=.40)
    for side, s in (('L', -1), ('R', 1)):
        for sh in m.groups[m.lookup['Arm_' + side]].shapes: sh.color = m.palette['feather']
        g = m.group('Foot_' + side, (s * .20, .27, .06))
        m.ellipsoid(g, (s * .20, .06, .13), (.14, .06, .20), 'beak', seg=18, rings=10)
        for k in (-1, 0, 1): m.ellipsoid(g, (s * .20 + k * .075, .055, .29), (.034, .034, .075), 'beak', seg=10, rings=6)
    g = m.group('Tail', (0, .45, -.30))
    m.ellipsoid(g, (0, .38, -.42), (.20, .09, .26), 'feather', seg=16, rings=10)
    return finish(m, 'ugleoje' if enemy else 'owl', height=1.75 if enemy else 1.4, extra=[ATTACK] if enemy else None,
                  clip_set='enemy' if enemy else 'farm_animal', patterns={'feather': 'feather'})


# ---------------------------------------------------------------------------------------------------------------------
# MUSHROOMS: Snurresvampen (boss, spins), Lysesvamp (glow critter)
# ---------------------------------------------------------------------------------------------------------------------
def make_mushroom(kind='boss'):
    pal = {} if kind == 'boss' else dict(cap='6FD6C4', cap_dark='3FA593', spot='F3FFFB', body='DDF5EA', light='F3FFFB', belly='F3FFFB', gill='A9E6D8', rim='5C8F86', inner='B9E8DE')
    with palette('mushroom', pal):
        m = Model('mushroom')
    fc, fr = (0, .64, 0), (.50, .66, .44)          # stem == face surface
    m.group('Body', (0, .64, 0))
    m.ellipsoid('Body', fc, fr, 'body', seg=34, rings=22, power=.92)
    m.group('Head', (0, 1.16, 0))
    capc = (0, 1.66, 0); capr = (.80, .40, .76)
    m.ellipsoid('Head', capc, capr, 'cap', seg=40, rings=24, power=.92)
    m.ellipsoid('Head', (0, 1.30, 0), (.74, .09, .70), 'gill', seg=34, rings=10)
    spots = [(0, 72, .13), (46, 64, .15), (-46, 64, .14), (96, 54, .14), (-96, 54, .16), (150, 58, .14), (-150, 58, .15), (180, 66, .13),
             (22, 42, .11), (-26, 38, .11), (72, 36, .12), (-76, 34, .11), (124, 36, .11), (-124, 34, .12), (0, 26, .10), (160, 26, .10), (-160, 24, .10)]
    for az, el, rr in spots:
        m.ellipsoid('Head', ell(capc, capr, az, el, .985), (rr, rr * .55, rr), 'spot', seg=14, rings=8, power=.9)
    eyes(m, fc, fr, x=.21, y_offset=.19, size=(.165, .19), asym=.015)
    cheeks(m, fc, fr, x=.33, y_offset=.0)
    if kind == 'boss':
        mouth_open(m, fc, (.50, .50, .44))
    else:
        yy = fc[1] - .02; zz = head_surface(fc, fr, 0, yy)
        m.tube('Head', bezier([[-.08, yy, zz + .01], [-.04, yy - .06, zz + .02], [.04, yy - .06, zz + .02], [.08, yy, zz + .01]], 10), .010, 'ink', sides=6)
    arms(m, y=.78, spread=.46)
    for side in ('L', 'R'):
        for sh in m.groups[m.lookup['Arm_' + side]].shapes: sh.color = m.palette['body']
    feet(m, spread=.22, color='rim' if kind == 'boss' else 'inner')
    if kind == 'boss':
        return finish(m, 'snurresvamp', height=2.1, extra=[ATTACK, SPIN], clip_set='boss', portrait={'half': 1.25, 'dy': -.55})
    return finish(m, 'lysesvamp', height=1.2, extra=[ATTACK], clip_set='critter', portrait={'half': .75, 'dy': -.3},
                  patterns={'cap': 'glow', 'body': 'glow'}, glow=('6FD6C4', 14, .85))


# ---------------------------------------------------------------------------------------------------------------------
# THORN CREATURE: Tornebusk
# ---------------------------------------------------------------------------------------------------------------------
def make_thornbush():
    m = Model('thornbush')
    bc, br = (0, .60, 0), (.56, .52, .50)
    hc = (0, 1.26, .02); hr = (.64, .56, .52)
    m.group('Body', (0, .62, 0))
    m.ellipsoid('Body', bc, br, 'body', seg=30, rings=18)
    m.group('Head', (0, hc[1] - .32, 0))
    m.ellipsoid('Head', hc, hr, 'body', seg=36, rings=22)
    rng = np.random.default_rng(11)

    def thorns(group, c, r, n, avoid_face):
        for i in range(n):
            az = rng.uniform(-180, 180); el = rng.uniform(-35, 85)
            if avoid_face and abs(az) < 58 and el < 52: continue
            p0 = ell(c, r, az, el, .96); d = (p0 - np.array(c)); d /= np.linalg.norm(d)
            L = rng.uniform(.14, .26)
            pts = np.array([p0 + d * L * t for t in (0, .35, .7, 1.0)])
            m.tube(group, pts, [.06, .045, .028, .006], 'thorn' if i % 3 else 'rim', sides=7)
    thorns('Head', hc, hr, 46, True)
    thorns('Body', bc, br, 26, False)
    for az, el in [(-70, 40), (-100, 10), (85, 30), (125, 48), (160, 20), (-150, 36), (0, 70), (30, 75)]:  # thornberries
        c = ell(hc, hr, az, el, 1.01)
        m.ellipsoid('Head', c, (.09, .09, .09), 'berry', seg=14, rings=10)
        m.ellipsoid('Head', c + np.array([.02, .03, .05]), (.025, .025, .02), 'berry_light', seg=8, rings=6)
    eyes(m, hc, hr, x=.23, y_offset=.08, size=(.17, .20), asym=.02)
    cheeks(m, hc, hr, x=.40, y_offset=-.14)
    mouth_open(m, hc, hr, wide=True)
    arms(m, y=.80, spread=.50)
    for side in ('L', 'R'):
        for sh in m.groups[m.lookup['Arm_' + side]].shapes: sh.color = m.palette['rim']
    feet(m, spread=.22, color='rim')
    return finish(m, 'tornebusk', height=1.8, extra=[ATTACK], clip_set='enemy')


# ---------------------------------------------------------------------------------------------------------------------
BUILDERS = {
    'hobbit_pip': lambda: make_hobbit('pip'),
    'hobbit_moss': lambda: make_hobbit('moss'),
    'hobbit_bramble': lambda: make_hobbit('bramble'),
    'squirrel': make_squirrel,
    'fairy_dusk': lambda: make_fairy_skin('fairy_dusk'),
    'fairy_stardust': lambda: make_fairy_skin('fairy_stardust'),
    'fairy_mayor': make_mayor, 'fairy_baker': make_baker, 'fairy_shopkeeper': make_shopkeeper, 'fairy_king': make_king,
    'fairy_wizard': make_wizard, 'fairy_lily': make_lily, 'fairy_builder': make_builder, 'fairy_furnisher': make_furnisher,
    'fairy_tailor': make_tailor, 'mouse_pippin': make_pippin,
    'cat_morfar_mis': make_morfar_mis, 'bear_guard': make_guard_oak, 'rabbit_farmer': make_farmer_rosa,
    'raccoon_smith': make_smith, 'penguin_postman': make_postman,
    'puppy': lambda: make_pup('puppy'), 'fawn': lambda: make_pup('fawn'),
    'chick': lambda: make_chick(False), 'hen': lambda: make_chick(True), 'duck': lambda: make_chick(False, True),
    'kitten': lambda: make_cub('kitten'), 'bunny': lambda: make_cub('bunny'), 'fox_cub': lambda: make_cub('fox_cub'), 'lamb': make_lamb, 'calf': make_calf,
    'owl': lambda: make_owl(False), 'ugleoje': lambda: make_owl(True),
    'snurresvamp': lambda: make_mushroom('boss'), 'lysesvamp': lambda: make_mushroom('critter'), 'tornebusk': make_thornbush,
}
