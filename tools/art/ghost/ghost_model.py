"""The two ghost heroes of Traetoppen, Bu and Hviske (package G-ghost-art): a new rig FAMILY ('ghost') on the stock rig of the generator.

This module is the whole model: geometry, palette table, texture pattern and the glide hooks.  It follows the geometry vocabulary of
tools/art/generator/{geometry,additions}.py (Model, ellipsoid, tube, bezier, eyes/cheeks helpers) and the hook contract of
tools/art/generator/build_assets.py (BUILDERS / EXTRA_PATTERNS / EXTRA_CLIPS, m.slug, m.height, m.clip_set, m.patterns); nothing in the
generator, the pack or the 36 characters of P21 is edited.  tools/art/ghost/traetoppen_additions.py is the thin shim that exposes this
module under the module name the generator imports; the wardrobe package A2 imports THIS module (through PYTHONPATH) for the two bases.

THE GHOST (user: "Ghost is a friendly playable character"; the family eye and the face grammar of the Figurer v2 sheet are kept):
  * head   the pack's big round head, an ellipsoid (.64, .575, .45) at y 1.50
  * eyes   geometry.eyes() in spirit (a big oval, one dark pupil, a white glint, same group names Eye_L / Eye_R so the stock blink works) but
           FLATTENED to z .055: the stock eye bulges .098 out of the head, fine on fur, but a dark lump in the W / E rows on a white head.
           The eye is DARK with a white glint and has NO white sclera (the other 12 pack figures have one): cuter and more ghostly, a taste
           decision recorded in the README (user answer 2026-10-14: dark eyes stay)
  * cheeks blush + the three cheek strokes of the family (geometry.cheeks)
  * mouth  ONE smile for both heroes: a different mouth moves the side-view silhouette by a few pixels and would split the wardrobe layers
  * body   a legless bell: a surface of revolution with an ELLIPTICAL section (depth .84), a scalloped hem (5 scallops dropping .13), a rolled
           hem tube and a collar fold under the head.  No Foot_* groups exist, so make_rig builds no legs
  * arms   two stub mittens as the stock Arm_L / Arm_R groups (stock chain, stock swing)
  * wisp   a tapering curl on the stock Tail chain (5 bones): the only secondary motion a legless body has when it glides
  * HOVER  the hem's lowest lobes are modelled ~10 px (0.11 m) ABOVE the contract pivot: the near edge of a 0.66 m skirt standing on the
           ground projects 22 px BELOW the pivot and fails measure_cast's upright feet window (prototype v1: 222 px; a first small hover
           still gave 216.6 in the hit clip; this one passes at 214.2).  The shadow of chibi.tscn stays on the floor; the runtime adds a +-2.5 px bob
  * ONE silhouette: Bu and Hviske share the geometry; they differ by colour, hem trim, blush and Hviske's shy glance (pupils a little down, INSIDE
    the sclera-less eye so the outline stays the one of Bu).  1460 of 5 370 860 figure pixels differ (0.027 %), all in the face band (y 60-130) of
    the W / E rows: the garment layers of A2 can be shared (occluder_equality.py measures it on the baked sheets)

PUBLIC API (what the shim, A2 and the tests use)
  make_ghost(hero)        hero in HEROES -> geometry.Model('ghost'), slug 'ghost_<hero>', clip_set 'full', height 1.92
  BUILDERS                {'ghost_bu': ..., 'ghost_hviske': ...}
  HEROES                  hero id -> palette override of PALETTES['ghost'] (Bu = the base palette)
  HERO_PALETTE            hero id -> {role: hex} the palette table of the design (sheet / collar / hem / eye / pupil / blush / wisp), resolved
  GHOST_PATTERNS          EXTRA_PATTERNS fragment: {'sheet': quiet cloth weave with long folds, no fur strokes}
  GHOST_CLIP_HOOKS        EXTRA_CLIPS fragment: {'walk': glide(1.0), 'run': glide(1.35)}; a no-op for every model whose family is not 'ghost'
  is_ghost(m)             True for a Model of this family (A2's `ghost_<hero>_base` models keep the family name 'ghost' and so animate alike)
  GHOST_IDS               ('ghost_bu', 'ghost_hviske')
"""
from __future__ import annotations
import math
import numpy as np
from PIL import Image
import geometry as geo
from geometry import Model, PALETTES, cheeks, bezier, head_surface

FAMILY = 'ghost'
GHOST_IDS = ('ghost_bu', 'ghost_hviske')

# ---------------------------------------------------------------------------------------------------------------------
# palettes: body = the sheet, sheet_dark = collar fold, hem = the rolled hem trim, eye = the dark eye, ink = the pupil / smile line
# ---------------------------------------------------------------------------------------------------------------------
PALETTES[FAMILY] = dict(body='E6EFFF', light='FAFCFF', inner='D3E1F8', rim='A3B8E0', belly='F0F5FF',
                        sheet_dark='B9CEF2', hem='93BBEE', eye='34305A', ink='1B1633', wisp='DCE8FB')

HEROES = {
    # Bu ("Boo"): snow white sheet with sky-blue shadows, round dark eyes, a wide happy smile
    'bu': dict(),
    # Hviske ("whisper"): a lilac-white sheet with a rose hem, a shy glance (pupils a little down), pinker blush
    'hviske': dict(body='F6E7F6', light='FFF9FF', inner='E8D3EE', rim='C4A4D2', belly='FAF0FA', sheet_dark='E2BEE6', hem='F29DC2',
                   eye='3B2F5C', ink='1E1436', wisp='F0DCF4', cheek='F29AB2'),
}


def hero_palette(hero: str) -> dict:
    """The palette table of one hero: the family palette with the hero's overrides, plus the family-wide cheek colour."""
    if hero not in HEROES:
        raise ValueError(f"unknown ghost hero '{hero}' (known: {', '.join(HEROES)})")
    merged = {**geo.COMMON, **PALETTES[FAMILY], **HEROES[hero]}
    return {'sheet': merged['body'], 'collar': merged['sheet_dark'], 'hem': merged['hem'], 'eye': merged['eye'], 'pupil': merged['ink'],
            'blush': merged['cheek'], 'wisp': merged['wisp'], 'light': merged['light'], 'belly': merged['belly']}


HERO_PALETTE = {hero: hero_palette(hero) for hero in HEROES}


def _rgb(c): return np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], float)


def pat_sheet(color, size):
    """Soft cloth: a very quiet weave and long vertical folds, no fur strokes (the stock default pattern for 'body' is fur)."""
    rgb = _rgb(color)
    y, x = np.mgrid[0:1:complex(size), 0:1:complex(size)]
    rng = np.random.default_rng(int(color, 16) % 2147483647)
    folds = .018 * np.sin(2 * np.pi * (x * 3 + .15 * np.sin(y * 5))) + .02 * (.5 - y)
    weave = .006 * np.sin(x * size * .9) * np.sin(y * size * .9)
    var = folds + weave + .004 * rng.standard_normal((size, size))
    a = np.clip(rgb[None, None, :] * (1 + var)[:, :, None], 0, 255)
    return Image.fromarray(a.astype('uint8'), 'RGB')


GHOST_PATTERNS = {'sheet': pat_sheet}


def is_ghost(m) -> bool:
    return getattr(m, 'name', None) == FAMILY


def _ghost_glide(strength):
    """EXTRA_CLIPS hook for the BASE clip names walk / run (build_assets.make_clips calls EXTRA_CLIPS[name] for every clip, base ones too):
    a legless body does not step, it glides - the hips bob twice per cycle three times as far as the stock bob, the body leans into the
    motion, the mittens paddle together and the wisp sways twice as far.  A no-op for every model that is not the ghost."""
    def fn(m, r, t, duration, phase, q, translations, scales):
        if not is_ghost(m):
            return
        hip, spine, head = r.lookup['Hips'], r.lookup['Spine'], r.lookup['Head']
        translations[:, hip, 1] += .022 * strength * np.cos(phase * 2)
        q[:, spine, 0] += .05 * strength
        q[:, head, 0] -= .03 * strength
        q[:, spine, 2] *= 1.6
        for side, a, b, c in r.arms:
            sign = -1 if side == 'L' else 1
            q[:, a, 2] = sign * (.22 + .20 * strength * np.sin(phase * 2))
            q[:, a, 0] *= .4
        for ids in r.tails:
            for k, i in enumerate(ids):
                q[:, i, 1] *= 2.0
    return fn


GHOST_CLIP_HOOKS = {'walk': _ghost_glide(1.0), 'run': _ghost_glide(1.35)}


# ---------------------------------------------------------------------------------------------------------------------
# geometry
# ---------------------------------------------------------------------------------------------------------------------
def ring_path(center, rx, rz, n=40, y_fn=None):
    t = np.linspace(0, 2 * math.pi, n + 1)
    y = center[1] + (y_fn(t) if y_fn is not None else np.zeros_like(t))
    return np.c_[center[0] + rx * np.cos(t), y, center[2] + rz * np.sin(t)]


def bell(m, group, ys, rs, depth=.84, n=48, lobes=6, lobe_drop=.075, lobe_out=.045, color='body', hem_from=.62):
    """Surface of revolution y -> radius with an elliptical section (z = depth * x) and a scalloped hem: from `hem_from` (0..1 of the
    way down the profile) the lower edge hangs lower and bulges out at `lobes` evenly spaced lobes.  Closed underneath."""
    ys, rs = np.asarray(ys, float), np.asarray(rs, float)
    m_ = len(ys)
    t = np.linspace(0, 1, m_)
    fine = 5 * m_
    tf = np.linspace(0, 1, fine)
    yf = np.interp(tf, t, ys)
    # smooth the radius (np.interp is piecewise linear) by a short moving average
    rf = np.interp(tf, t, rs)
    k = 9
    pad = np.pad(rf, (k, k), mode='edge')
    rf = np.convolve(pad, np.ones(2 * k + 1) / (2 * k + 1), mode='valid')
    verts = []
    for j in range(fine):
        u = tf[j]
        w = np.clip((u - hem_from) / (1 - hem_from), 0, 1)
        for i in range(n):
            a = 2 * math.pi * i / n
            lobe = .5 + .5 * math.cos(lobes * a)
            r = rf[j] * (1 + lobe_out * w ** 2 * (lobe - .5) * 2 + .0)
            y = yf[j] - lobe_drop * (w ** 3) * lobe
            verts.append([r * math.cos(a), y, r * depth * math.sin(a)])
    verts = np.array(verts)
    faces = []
    for j in range(fine - 1):
        for i in range(n):
            a = j * n + i; b = j * n + (i + 1) % n; c = a + n; d = b + n
            faces.extend([[a, c, b], [b, c, d]])
    # top cap (hidden under the head) and bottom cap (the underside, never seen from above)
    top = np.array([[0, yf[0], 0]]); bot = np.array([[0, yf[-1] + .02, 0]])
    verts = np.vstack([verts, top, bot])
    ti, bi = len(verts) - 2, len(verts) - 1
    for i in range(n):
        faces.append([ti, i, (i + 1) % n])
        faces.append([bi, (fine - 1) * n + (i + 1) % n, (fine - 1) * n + i])
    f = np.array(faces, np.int32)
    # orient normals outwards: test one side face
    v = verts
    fn = np.cross(v[f[0, 1]] - v[f[0, 0]], v[f[0, 2]] - v[f[0, 0]])
    if np.dot(fn, np.array([v[f[0, 0], 0], 0, v[f[0, 0], 2]])) < 0:
        f = f[:, ::-1]
    m.add(group, verts, f, color)
    return rf, yf


def ghost_eyes(m, hc, hr, x=.225, y_offset=.075, size=(.185, .225), shy=False):
    """The family's eye (a big oval, one dark pupil, a white glint) but FLATTER than geometry.eyes(): the stock eye bulges .098 out of the head,
    which is fine on fur and reads as a dark lump on a white head in the W / E rows.  Same group names (Eye_L / Eye_R), so the stock blink works."""
    for side, sign in (('L', -1), ('R', 1)):
        ex = sign * x; ey = hc[1] + y_offset + (.012 if sign < 0 else 0)
        ez = head_surface(hc, hr, ex, ey) - .02
        g = m.group('Eye_' + side, (ex, ey, ez), 'Head', glossy=True)
        rx, ry = size
        m.ellipsoid(g, (ex, ey, ez + .012), (rx, ry, .055), 'eye', seg=28, rings=16, tilt=sign * .075)
        px = ex + (.012 if sign < 0 else -.006); py = ey - .01
        if shy:                                   # Hviske looks a little down and to the side: still INSIDE the eye, so the silhouette stays the one of Bu
            px += .026; py -= .030
        m.ellipsoid(g, (px, py, ez + .052), (.098, .122, .020), 'ink', seg=24, rings=14, tilt=sign * .03)
        m.ellipsoid(g, (px - .030, py + .050, ez + .078), (.034, .038, .008), 'shine', seg=12, rings=8)
        m.ellipsoid(g, (px + .036, py - .042, ez + .074), (.015, .017, .005), 'shine', seg=10, rings=6)


def make_ghost(hero='bu'):
    """The model of one ghost hero (see the module docstring); `hero` is 'bu' or 'hviske'."""
    if hero not in HEROES:
        raise ValueError(f"unknown ghost hero '{hero}' (known: {', '.join(HEROES)})")
    over = HEROES[hero]
    old = PALETTES[FAMILY]
    PALETTES[FAMILY] = {**old, **over}
    try:
        m = Model(FAMILY)
    finally:
        PALETTES[FAMILY] = old
    hc = (0, 1.50, .02); hr = (.64, .575, .45)
    # ---------------- body: the bell, a collar fold under the head, the rolled hem
    m.group('Body', (0, .74, 0))
    ys = [1.16, 1.02, .90, .73, .58, .48, .41]
    rs = [.30, .36, .45, .54, .61, .66, .66]
    LOBES, DROP = 5, .13
    bell(m, 'Body', ys, rs, depth=.84, lobes=LOBES, lobe_drop=DROP, lobe_out=.05)
    m.tube('Body', ring_path((0, 1.08, .0), .38, .33, 36), .05, 'sheet_dark', sides=8)       # collar fold
    # rolled hem trim: a thin tube along the scalloped lower edge (same wave as the hem of the bell)
    hem_fn = lambda t: -DROP * (.5 + .5 * np.cos(LOBES * t))
    m.tube('Body', ring_path((0, .41 + .005, 0), .66 * 1.0, .66 * .84, 90, hem_fn), .028, 'hem', sides=8)
    # ---------------- head
    m.group('Head', (0, hc[1] - .32, 0))
    m.ellipsoid('Head', hc, hr, 'body', seg=40, rings=26)
    ghost_eyes(m, hc, hr, x=.225, y_offset=.075, size=(.185, .225), shy=(hero == 'hviske'))
    cheeks(m, hc, hr, x=.385, y_offset=-.150)
    # friendly mouth: ONE smile for both heroes (a different mouth changes the side-view silhouette by a few pixels and would split the wardrobe layers)
    pts = [[-.12, hc[1] - .235], [-.05, hc[1] - .315], [.05, hc[1] - .315], [.12, hc[1] - .235]]
    rad = .011
    p = bezier([[x, y, head_surface(hc, hr, x, y) + .012] for x, y in pts], 20)
    m.tube('Head', p, rad, 'ink', sides=8)
    # ---------------- stub mittens (stock Arm_L / Arm_R: chain Spine-armature, stock swing)
    for side, sg in (('L', -1), ('R', 1)):
        g = m.group('Arm_' + side, (sg * .44, 1.02, .22))
        m.ellipsoid(g, (sg * .53, .86, .27), (.125, .20, .15), 'body', seg=24, rings=16, tilt=-sg * .45)
    # ---------------- the wisp: a small curl behind the hem on the stock Tail chain (5 bones, sways when gliding)
    g = m.group('Tail', (0, .32, -.36))
    path = bezier([[.00, .52, -.52], [.18, .40, -.84], [.52, .62, -.90], [.44, 1.02, -.62]], 34)
    tt = np.linspace(0, 1, len(path)); r = .135 * (1 - tt) ** .70 + .028
    r[-3:] = [r[-4] * .62, r[-4] * .34, .008]
    m.tube(g, path, r, 'wisp', sides=12)
    m.slug = 'ghost_' + hero
    m.height = 1.92
    m.clip_set = 'full'
    m.patterns = {'body': 'sheet', 'wisp': 'sheet', 'hem': 'sheet', 'sheet_dark': 'sheet', 'light': 'sheet', 'belly': 'sheet', 'inner': 'sheet'}
    return m


BUILDERS = {'ghost_bu': lambda: make_ghost('bu'), 'ghost_hviske': lambda: make_ghost('hviske')}
