"""Cast v2: the eight builders of package V2-cast-art (Figurer v2 of the Style Guide review, design section 3.2 / 3.4).

  six NEW ids      bear_brumme  bat_natteblik  hedgehog_pip  owl_fru_ugle  capybara_sofus  fairy_birk_npc
  two RESTYLES     fairy_shopkeeper (Butiksfe Kloevermynte)   cat_morfar_mis      (same ids, same clip sets, new look)

Everything is built from the vocabulary of the generator (geometry.py / additions.py) and the helpers of P21's
tools/art/characters/traetoppen_additions.py, which is IMPORTED here (importlib, loaded under another name) and never edited.
The sketch colours live in ONE file, tools/art/cast_v2/palettes_v2.json (the builders read their hex from it).

What a builder may do (the whole style of the pack, nothing new): override the palette of a stock builder, recolour the shapes of a
group, scale a group, add ellipsoids / tubes in the same primitives, and set m.slug / m.height / m.base_height / m.clip_set through
finish().  No new rig, no new clip, no tone curve: the stock rig, the stock clips, the stock baker.
"""
import contextlib
import importlib.util
import json
import math
import sys
from pathlib import Path

import numpy as np

import geometry as geo
from geometry import Model, PALETTES, eyes, cheeks, bezier, head_surface
import additions as add

HERE = Path(__file__).resolve().parent
P21_FILE = HERE.parent / 'characters' / 'traetoppen_additions.py'
PALETTE_FILE = HERE / 'palettes_v2.json'
P21_MODULE_NAME = 'tt_p21_traetoppen_additions'

# ---------------------------------------------------------------------------------------------------------------------
# P21's module (imported, never edited) and the sketch palette
# ---------------------------------------------------------------------------------------------------------------------


def p21():
    """The module tools/art/characters/traetoppen_additions.py (P21), loaded from its file under another name (this package ships a
    module of the SAME name as the generator's hook: the caller's PYTHONPATH puts that one first)."""
    mod = sys.modules.get(P21_MODULE_NAME)
    if mod is None:
        spec = importlib.util.spec_from_file_location(P21_MODULE_NAME, P21_FILE)
        mod = importlib.util.module_from_spec(spec)
        sys.modules[P21_MODULE_NAME] = mod
        spec.loader.exec_module(mod)
    return mod


def palette_table() -> dict:
    return json.loads(PALETTE_FILE.read_text())['figures']


def pal(figure: str) -> dict:
    """The sketch hex of one figure, UPPER case (the generator's palettes are upper case; Model.add compares strings)."""
    def up(v):
        return [x.upper() for x in v] if isinstance(v, list) else v.upper()
    return {k: up(v) for k, v in palette_table()[figure].items()}


# ---------------------------------------------------------------------------------------------------------------------
# small helpers on top of the generator's Model
# ---------------------------------------------------------------------------------------------------------------------
def _all_shapes(m):
    return [sh for g in m.groups for sh in g.shapes]


@contextlib.contextmanager
def painted(m, pattern):
    """Every shape added inside the block gets this texture pattern (EXTRA_PATTERNS of P21: cloth, skin, wool, feather ...)."""
    before = {id(s) for s in _all_shapes(m)}
    yield
    for s in _all_shapes(m):
        if id(s) not in before:
            s.pattern = pattern


def group_shapes(m, name):
    return m.groups[m.lookup[name]].shapes


def recolor(m, group, old, new, only=None):
    """Recolour the shapes of one group (or of every group whose name starts with `group`) whose colour is `old` to `new`."""
    n = 0
    for g in m.groups:
        if not (g.name == group or g.name.startswith(group)):
            continue
        for i, sh in enumerate(g.shapes):
            if sh.color == old and (only is None or i in only):
                sh.color = new
                n += 1
    if n == 0:
        raise ValueError('recolor: no shape of %s has colour %s' % (group, old))
    return n


def recolor_all(m, old, new):
    """Recolour every shape of the model whose colour is `old` (palette overrides of an already finished builder, like P21's Morfar Mis)."""
    n = 0
    for sh in _all_shapes(m):
        if sh.color == old:
            sh.color = new
            n += 1
    if n == 0:
        raise ValueError('recolor_all: no shape has colour %s' % old)
    return n


def scale_group(m, group, k, about=None):
    """Scale every vertex of a group (ears) about `about` (default: the group pivot); k is a scalar or (kx, ky, kz)."""
    g = m.groups[m.lookup[group]]
    c = np.asarray(g.pivot if about is None else about, float)
    k = np.broadcast_to(np.asarray(k, float), (3,))
    for sh in g.shapes:
        sh.vertices = c + (sh.vertices - c) * k


def scale_shape(sh, k, about=None):
    c = sh.vertices.mean(axis=0) if about is None else np.asarray(about, float)
    sh.vertices = c + (sh.vertices - c) * np.broadcast_to(np.asarray(k, float), (3,))


def remove_shapes(m, group, pred):
    g = m.groups[m.lookup[group]]
    n0 = len(g.shapes)
    g.shapes = [sh for sh in g.shapes if not pred(sh.vertices.mean(axis=0))]
    return n0 - len(g.shapes)


def super_ring(cy, rx, rz, p=.88, n=44, cx=0.0, cz=0.0, grow=1.0):
    """A closed ring on the waist of a super-ellipsoid body (the stock bodies use exponent `power` p: x = rx cos^p, z = rz sin^p)."""
    a = np.linspace(0, 2 * math.pi, n + 1)
    c, s = np.cos(a), np.sin(a)
    return np.c_[cx + grow * rx * np.sign(c) * np.abs(c) ** p, np.full_like(a, cy), cz + grow * rz * np.sign(s) * np.abs(s) ** p]


def circle3(center, axis, radius, n=20):
    """A ring of radius `radius` around `axis` through `center` (stripes around a tail or a leg)."""
    ax = np.asarray(axis, float)
    ax = ax / np.linalg.norm(ax)
    ref = np.array([0., 0., 1.]) if abs(ax[2]) < .9 else np.array([1., 0., 0.])
    u = np.cross(ax, ref)
    u /= np.linalg.norm(u)
    w = np.cross(ax, u)
    a = np.linspace(0, 2 * math.pi, n + 1)
    return np.asarray(center, float)[None, :] + radius * (np.cos(a)[:, None] * u[None, :] + np.sin(a)[:, None] * w[None, :])


def add_iris(m, color, grow=.62, thick=.020, pattern='porcelain'):
    """A coloured iris on the sclera of both eyes (geometry.eyes() draws sclera + one dark pupil + two glints): a flat disc between the sclera
    and the pupil, centred on the pupil.  The pupil and the glints stay in front of it, so the eye still reads 'dark pupil with a white glint'."""
    for side in ('L', 'R'):
        g = m.groups[m.lookup['Eye_' + side]]
        sclera, pupil = g.shapes[0], g.shapes[1]
        lo, hi = sclera.vertices.min(axis=0), sclera.vertices.max(axis=0)
        rx, ry = (hi[0] - lo[0]) / 2 * grow, (hi[1] - lo[1]) / 2 * grow
        pc = pupil.vertices.mean(axis=0)
        m.ellipsoid(g.name, (pc[0], pc[1], hi[2] - .004), (rx, ry, thick), color, seg=26, rings=14)
        g.shapes[-1].pattern = pattern


def grow_pupils(m, k):
    """Bigger dark pupils (the sketch owl: gold disc with a big black pupil): scale the pupil ellipsoid in x / y about its centre."""
    for side in ('L', 'R'):
        scale_shape(m.groups[m.lookup['Eye_' + side]].shapes[1], (k, k, 1.0))


def tint_pupils(m, color):
    for side in ('L', 'R'):
        sh = m.groups[m.lookup['Eye_' + side]].shapes[1]
        sh.color = color


def top_y(m):
    return max(float(sh.vertices[:, 1].max()) for g in m.groups for sh in g.shapes)


def finish(m, slug, height, base=None, clip_set='villager', **kw):
    return p21().finish(m, slug, height=height, base=base, clip_set=clip_set, **kw)


# ---------------------------------------------------------------------------------------------------------------------
# 1. BRUMME  (carpenter bear: stock bear + the sketch palette + a tool belt that fits the bear's body)
# ---------------------------------------------------------------------------------------------------------------------
def tool_belt_bear(m, y=.58, leather='4E3322', buckle='E9C06B', metal='C9CFDC'):
    """P21's tool_belt() is cut for the fairy bodice (a ring of radius .27 at y 1.07 would sit INSIDE the bear).  Same parts, sized to the
    bear's waist: a broad belt hugging the super-ellipsoid body, two pouches, a hammer on the right hip and a pencil."""
    bc, br, p = (0, .71, 0), (.47, .605, .35), .88
    k = (1 - ((y - bc[1]) / br[1]) ** 2) ** .5                       # waist radius factor at height y
    rx, rz = br[0] * k ** p * 1.035, br[2] * k ** p * 1.04
    ring = super_ring(y, rx, rz, p)
    bump = .088 * np.sqrt(np.clip(1 - (ring[:, 0] / .31) ** 2, 0, 1)) * (ring[:, 2] > 0)    # the cream belly patch (.30 wide, .078 deep) stands proud of the torso: the belt goes over it
    ring[:, 2] += bump
    m.tube('Body', ring, .045, leather, sides=8)
    zf = rz + .088
    m.ellipsoid('Body', (0, y, zf + .004), (.085, .07, .034), buckle, seg=14, rings=8)
    for s in (-1, 1):
        zp = rz * .86 + .05
        m.ellipsoid('Body', (s * .235, y - .105, zp), (.105, .135, .095), 'A06B3C', seg=18, rings=12)
        m.ellipsoid('Body', (s * .235, y - .02, zp + .006), (.112, .034, .10), leather, seg=14, rings=8)
    m.tube('Body', [[.43, y + .01, .10], [.49, y - .12, .12], [.52, y - .26, .13]], .021, '8A5A33', sides=7)         # hammer handle
    m.ellipsoid('Body', (.53, y - .31, .13), (.085, .052, .052), metal, seg=14, rings=10, tilt=.12)                    # hammer head
    m.tube('Body', [[-.09, y + .03, zf * .99], [-.12, y + .17, zf * .99 + .01]], .013, 'F2B63C', sides=6)            # pencil


def make_brumme():
    P = pal('brumme')
    with p21().palette('bear', dict(body=P['body'], light=P['muzzle'], inner=P['ear_inner'], belly=P['belly'])):
        m = geo.make_bear()
    base = top_y(m)
    # the stock builder paints the muzzle with the belly colour; the sketch has a lighter muzzle e9d2b0 on a d3a77a belly
    recolor(m, 'Head', P['belly'], P['muzzle'])
    with painted(m, 'cloth'):
        tool_belt_bear(m)
    with painted(m, 'skin'):                                          # the toe beans of the sketch: a pink pad and three light toes on the front of each foot
        for side in ('L', 'R'):
            s = -1 if side == 'L' else 1
            g = 'Foot_' + side
            m.ellipsoid(g, (s * .24, .105, .29), (.062, .052, .022), P['pads'][0], seg=14, rings=8)
            for dx in (-.065, 0, .065):
                m.ellipsoid(g, (s * .24 + dx, .185, .285), (.030, .034, .020), P['pads'][1], seg=12, rings=8)
    return finish(m, 'bear_brumme', height=1.95, base=base, clip_set='villager')


# ---------------------------------------------------------------------------------------------------------------------
# 2. NATTEBLIK  (stock bat, purple, bigger ears, brown eyes; the pack folder `bat` and the hostile bat stay untouched)
# ---------------------------------------------------------------------------------------------------------------------
def make_natteblik():
    P = pal('natteblik')
    with p21().palette('bat', dict(body=P['body'], light=P['belly'], inner=P['membrane'], rim='574773', belly=P['belly'])):
        m = geo.make_bat()
    base = top_y(m)
    # the stock builder paints wing membrane AND the ear lining with `inner`: the sketch has a pale lilac ear lining on a dark membrane
    recolor(m, 'Ear_', P['membrane'], P['ear_inner'])
    for side in ('L', 'R'):                                           # bigger ears (sketch: rounded, as tall as the head)
        scale_group(m, 'Ear_' + side, (1.30, 1.28, 1.30))
    tint_pupils(m, P['eyes'])                                         # brown eyes 4a2416 (glints stay white)
    # a lighter belly patch below the mouth (the stock bat is a head with wings: no belly of its own)
    hc, hr = (0, .89, 0), (.65, .60, .355)
    y = .50
    z = head_surface(hc, hr, 0, y)
    with painted(m, 'fur'):
        m.ellipsoid('Head', (0, y, z - .004), (.30, .16, .055), P['belly'], seg=26, rings=14)
    # the pack bat is drawn with a 1.58 camera half-height (1.6 * 1.47 / 1.58 = 1.49 m at the contract camera); Natteblik is a person-sized NPC: 1.56 m keeps the
    # idle SE figure at 95 % of the pack mean (the 1.49 m of the pack bat measured 91 % and rendered 89.6 % at zoom 0.4: on the edge of the +/-10 % gate)
    return finish(m, 'bat_natteblik', height=1.56, base=base, clip_set='npc_flyer')


# ---------------------------------------------------------------------------------------------------------------------
# 3. PIP  (postman hedgehog: stock hedgehog + the sketch palette + Pippin's satchel and strap, mirrored + a letter in the paws)
# ---------------------------------------------------------------------------------------------------------------------
def make_pip():
    P = pal('pip')
    with p21().palette('hedgehog', dict(body=P['face'], light=P['face'], belly=P['face'], inner='E8B4B8', rim='5E3B20', spike=P['spines'])):
        m = add.make_hedgehog()
    base = top_y(m)
    hands = 'E0C4A0'                                                  # the sketch's hands and ears are a little darker than the face
    recolor(m, 'Body', P['face'], P['belly_ring'], only=[0])          # the torso is the brown belly ring; the belly patch (shape 1) stays cream
    recolor(m, 'Foot_', P['face'], P['feet'])
    recolor(m, 'Arm_', P['face'], hands)
    recolor(m, 'Ear_', P['face'], hands)
    bc, br = (0, .77, 0), (.449, .633, .333)
    with painted(m, 'cloth'):
        # satchel + strap: the code of make_pippin (P21, same torso), mirrored: strap from the viewer's left shoulder to the right hip, bag on the right hip
        waypoints = [(-.33, 1.27), (-.22, 1.15), (-.10, 1.02), (.01, .88), (.12, .75), (.23, .63), (.31, .54)]
        pts = np.array([[x, y, head_surface(bc, br, x, y) + .042] for x, y in waypoints])
        m.tube('Body', pts, .075, '7A4E2D', sides=10, depth=.030)
        sx, sy = .40, .50
        sz = head_surface(bc, br, sx, sy) + .03
        m.ellipsoid('Body', (sx, sy - .03, sz), (.165, .155, .105), P['satchel'], seg=22, rings=14)
        m.ellipsoid('Body', (sx, sy + .075, sz + .02), (.172, .075, .112), '4A78AE', seg=20, rings=10)       # flap
        m.ellipsoid('Body', (sx - .01, sy + .02, sz + .10), (.036, .042, .018), 'E9C06B', seg=10, rings=8)  # clasp
        # the letter in his paws: a flat white envelope with a flap line and a red seal
        m.ellipsoid('Body', (0, .72, .405), (.165, .105, .022), 'FFFDF6', seg=20, rings=10, power=.5)
        m.tube('Body', [[-.15, .815, .426], [0, .735, .432], [.15, .815, .426]], .008, 'C9C4D2', sides=6)
        m.ellipsoid('Body', (0, .715, .440), (.036, .036, .016), P['seal'], seg=14, rings=8)
    return finish(m, 'hedgehog_pip', height=1.9, base=base, clip_set='villager')


# ---------------------------------------------------------------------------------------------------------------------
# 4. FRU UGLE  (the owl of P21's make_owl: chevrons and facial discs exist; sketch palette, gold eye rings, clip set villager so she can talk)
# ---------------------------------------------------------------------------------------------------------------------
def make_fru_ugle():
    P = pal('fru_ugle')
    with p21().palette('owl', dict(body=P['body'], light=P['discs'][0], inner='E3A9A0', rim='5E4636', belly=P['discs'][1], beak=P['beak'],
                                   feather=P['wings'], eye=P['eye_rings'])):
        m = p21().make_owl(False)
    grow_pupils(m, 1.7)                                               # gold disc with a big black pupil
    return finish(m, 'owl_fru_ugle', height=1.95, clip_set='villager', patterns={'feather': 'feather'})


# ---------------------------------------------------------------------------------------------------------------------
# 5. SOFUS  (the ONE new body: an upright capsule on add.body's rig, dark muzzle patch, orange with a leaf on the head)
# ---------------------------------------------------------------------------------------------------------------------
def _sofus_palette():
    P = pal('sofus')
    PALETTES['sofus'] = dict(body=P['body'], light=P['belly'], inner=P['muzzle_hands_feet'], rim='7C5236', belly=P['belly'], eye='2B2340',
                             muzzle=P['muzzle_hands_feet'], hand=P['muzzle_hands_feet'], orange=P['orange'], leaf=P['leaf'], brow='B07A4A')
    return P


def make_sofus():
    P = _sofus_palette()
    m = Model('sofus')
    hc, hr = (0, 1.40, .04), (.53, .46, .42)
    m.group('Body', (0, .80, 0))
    m.ellipsoid('Body', (0, .88, 0), (.53, .82, .42), 'body', seg=40, rings=24, power=.80)
    m.ellipsoid('Body', (0, .56, .395), (.33, .28, .06), 'belly', seg=28, rings=16, power=.85)           # the cream belly
    for s in (-1, 1):                                                                                         # fur strokes on the flanks (sketch: two short curves)
        m.tube('Body', [[s * .50, 1.00, .22], [s * .54, .80, .20], [s * .50, .62, .21]], .012, 'brow', sides=6)
    m.group('Head', (0, hc[1] - .32, 0))
    m.ellipsoid('Head', hc, hr, 'body', seg=40, rings=26, power=.85)
    for side, s in (('L', -1), ('R', 1)):                                                                     # two small round ears at the top corners
        g = m.group('Ear_' + side, (s * .37, 1.68, -.03), 'Head')
        m.ellipsoid(g, (s * .385, 1.78, -.03), (.150, .160, .10), 'body', seg=24, rings=16)
        m.ellipsoid(g, (s * .385, 1.785, .045), (.085, .09, .032), 'muzzle', seg=18, rings=12)
    eyes(m, hc, hr, x=.265, y_offset=.085, size=(.105, .125), asym=.008)                                      # sketch: dark eyes with a white glint, no white
    cheeks(m, hc, hr, x=.415, y_offset=-.165)
    # the dark muzzle patch: a rounded square in the middle of the face, two nostrils, a short philtrum and a wide smile
    y = 1.14
    z = head_surface(hc, hr, 0, y)
    m.ellipsoid('Head', (0, y, z - .002), (.285, .235, .075), 'muzzle', seg=32, rings=18, power=.62)
    for s in (-1, 1):
        m.ellipsoid('Head', (s * .095, y + .105, z + .068), (.03, .022, .012), 'ink', seg=12, rings=8)
    m.tube('Head', [[0, y + .075, z + .074], [0, y + .0, z + .078]], .010, 'ink', sides=6)
    m.tube('Head', bezier([[-.115, y - .06, z + .068], [-.06, y - .135, z + .085], [.06, y - .135, z + .085], [.115, y - .06, z + .068]], 14), .011, 'ink', sides=6)
    # the orange with its leaf, balanced on the head
    ox, oy, oz = 0.0, 1.90, .02
    m.ellipsoid('Head', (ox, oy, oz), (.175, .16, .175), 'orange', seg=28, rings=18)
    m.tube('Head', [[ox, oy + .15, oz], [ox + .01, oy + .19, oz]], .012, 'leaf', sides=6)
    m.ellipsoid('Head', (ox + .085, oy + .205, oz), (.115, .028, .055), 'leaf', seg=18, rings=10, tilt=.5)
    # arms: the stock rig wants Arm_L / Arm_R groups; only the small dark hands show, held at the top of the belly
    for side, s in (('L', -1), ('R', 1)):
        g = m.group('Arm_' + side, (s * .20, 1.05, .30))
        m.ellipsoid(g, (s * .17, .79, .43), (.105, .085, .075), 'hand', seg=20, rings=12)
        m.ellipsoid(g, (s * .20, .90, .36), (.07, .13, .07), 'body', seg=16, rings=10)
    # wide flat feet
    for side, s in (('L', -1), ('R', 1)):
        g = m.group('Foot_' + side, (s * .27, .27, .03))
        m.ellipsoid(g, (s * .27, .085, .17), (.175, .095, .205), 'hand', seg=24, rings=14, power=.85)
    m.leg_color = 'body'
    return finish(m, 'capybara_sofus', height=1.9, clip_set='villager')


# ---------------------------------------------------------------------------------------------------------------------
# 6. BIRK  (male fairy: the stock fairy rig with a short-haired head and a leaf cap; clip set npc_flyer)
# ---------------------------------------------------------------------------------------------------------------------
def _fairy(overrides):
    with p21().palette('fairy', overrides):
        m = geo.make_fairy()
    m._base_h = top_y(m)
    return m


def _strip_fairy_hair(m):
    """The stock fairy head carries a bun with a flower (x < -.15, y > 2.2) and two long side locks (|x| .49, y 1.99): neither suits Birk."""
    p21().strip_fairy_bun(m)
    remove_shapes(m, 'Head', lambda c: abs(c[0]) > .45 and 1.9 < c[1] < 2.1 and c[2] > .0)


def make_birk():
    P = pal('birk')
    m = _fairy(dict(body='F6D3C0', light='F9E0D0', hair=P['fringe'], hair_light='DDA25A', dress=P['tunic'], petal='5C8A33', gold='E3C372',
                    wing=P['wings'], wing_inner='E8F3F9', wing_rim='9DBFD3'))
    _strip_fairy_hair(m)
    hc, hr = p21().HEADS['fairy']
    # boots: the stock fairy shoes are painted with the dress colour; the sketch has brown boots 5e3b20 (the gold buckle stays)
    recolor(m, 'Foot_', P['tunic'], P['belt_boots'])
    with painted(m, 'cloth'):
        m.tube('Body', super_ring(1.0, .300, .256, p=1.0, n=40), .030, P['belt_boots'], sides=8)                # the belt
        m.ellipsoid('Body', (0, 1.0, .262), (.052, .048, .022), 'E3C372', seg=14, rings=8)                         # and its buckle
        # the leaf cap: a snug dome on the crown (the stock fringe stays in front of it, like the zigzag fringe of the sketch), a pointed leaf peak
        # over the forehead and a sprout curling up from the top
        top = hc[1] + hr[1]
        m.ellipsoid('Head', (hc[0], top - .03, hc[2] - .07), (hr[0] * .98, .27, hr[2] * 1.0), P['cap'], seg=34, rings=20, power=.9)
        m.ellipsoid('Head', (hc[0], top + .045, hc[2] + .20), (.27, .04, .22), P['cap'], seg=24, rings=10, tilt=.10)
        m.tube('Head', bezier([[0, top + .18, hc[2] - .07], [.02, top + .33, hc[2] - .05], [.10, top + .42, hc[2] - .04], [.20, top + .40, hc[2] - .03]], 12),
               np.linspace(.028, .010, 12), '4F7A2C', sides=7)
    p21().set_wand(m, p21().wand_none)
    add_iris(m, P['irises'])
    return p21().finish(m, 'fairy_birk_npc', height=1.95, base=m._base_h, clip_set='npc_flyer')


# ---------------------------------------------------------------------------------------------------------------------
# RESTYLE: Butiksfe Kloevermynte (fairy_shopkeeper) - the sketch's lavender hood-bob, coronet of beads, pink dress; the pouch stays
# ---------------------------------------------------------------------------------------------------------------------
def make_kloevermynte():
    P = pal('kloevermynte')
    m = _fairy(dict(body=P['skin'], light='F9E0D0', hair=P['hair'], hair_light=P['hair_rim'], dress=P['dress'], petal='F0A8B6', gold=P['coronet'][0],
                    wing=P['wings'], wing_inner='E8F3F9', wing_rim='9DBFD3'))
    p21().strip_fairy_bun(m)
    hc, hr = p21().HEADS['fairy']
    # hood-bob: the hair swings round the face and down to the jaw on both sides, a fuller shell behind
    with painted(m, 'hair'):
        for s in (-1, 1):
            m.ellipsoid('Head', (s * .50, 1.80, .03), (.19, .42, .24), 'hair', seg=26, rings=16, tilt=-s * .06)
        m.ellipsoid('Head', (0, 1.76, -.17), (.64, .62, .44), 'hair', seg=34, rings=22)
        # the coronet of the sketch: gold, white, gold beads along the front of the hood
        for az, el, col, r in [(-30, 58, P['coronet'][0], .078), (0, 66, P['coronet'][1], .088), (30, 58, P['coronet'][0], .078)]:
            c = p21().ell(hc, (hr[0] * 1.12, hr[1] * 1.12, hr[2] * 1.12), az, el)
            c[2] += .16
            m.ellipsoid('Head', c, (r, r, r), col, seg=16, rings=10)
    add_iris(m, P['hair_rim'])                                        # the sketch's violet irises (5d4fa3)
    p21().pouch(m)
    p21().set_wand(m, p21().wand_none)
    return p21().finish(m, 'fairy_shopkeeper', height=1.92, clip_set='npc_flyer', base=m._base_h)


# ---------------------------------------------------------------------------------------------------------------------
# RESTYLE: Morfar Mis - the old grey cat of P21 (sardine and old-man brows stay), body / belly / ear lining moved onto the sketch hex (a7adb9 / e7e3ea / f2b8c6:
# the old A9A6B8 is dE00 5.9 from the sketch fill on the palette and 6.5 - 7.3 on the screen, over the gate of 6), green irises c9d97a, tabby stripes 7d8494
# ---------------------------------------------------------------------------------------------------------------------
def make_morfar_mis():
    P = pal('morfar_mis')
    m = p21().make_morfar_mis()                                       # the P21 cat: grey, sardine across the mouth, bushy brows
    base = m.base_height
    for old, new in (('A9A6B8', P['body']), ('F1EEF7', P['belly']), ('D9A9B4', P['ear_inner'])):    # P21's palette -> the sketch's
        recolor_all(m, old, new)
    add_iris(m, P['irises'], grow=.66)
    stripe = P['stripes']
    with painted(m, 'fur'):
        for s in (-1, 1):                                             # forelegs (the stock rig's arms, ellipsoid centre (.279, 1.0, .29), radii .105 .224 .132): three bars each
            for yy in (.93, .86, .79):
                k = (1 - ((yy - 1.0) / .224) ** 2) ** .5
                m.tube('Arm_' + ('L' if s < 0 else 'R'), super_ring(yy, .105 * k + .010, .132 * k + .010, p=1.0, n=18, cx=s * .279 + s * (1.0 - yy) * .12, cz=.29), .011, stripe, sides=6)
            for yy in (.29, .22):                                     # hind legs: two bars each, where the leg leaves the body
                m.tube('Foot_' + ('L' if s < 0 else 'R'), super_ring(yy, .100, .100, p=1.0, n=18, cx=s * .24, cz=.05), .012, stripe, sides=6)
        tail = group_shapes(m, 'Tail')[0]
        rings = tail.vertices[:-2].reshape(-1, 12, 3)                 # the tail is a tube of 28 rings x 12 sides (+ 2 cap points)
        path = rings.mean(1)
        for i in range(3, len(path) - 3, 3):                          # tail bars: a ring round the tail tube, perpendicular to its path
            tang = path[i + 1] - path[i - 1]
            m.tube('Tail', circle3(path[i], tang, float(np.linalg.norm(rings[i][0] - path[i])) + .010, 16), .011, stripe, sides=6)
    return p21().finish(m, 'cat_morfar_mis', height=1.95, base=base, clip_set='villager')


# ---------------------------------------------------------------------------------------------------------------------
NEW_IDS = ['bear_brumme', 'bat_natteblik', 'hedgehog_pip', 'owl_fru_ugle', 'capybara_sofus', 'fairy_birk_npc']
RESTYLE_IDS = ['fairy_shopkeeper', 'cat_morfar_mis']
CAST_IDS = NEW_IDS + RESTYLE_IDS

CAST_BUILDERS = {'bear_brumme': make_brumme, 'bat_natteblik': make_natteblik, 'hedgehog_pip': make_pip, 'owl_fru_ugle': make_fru_ugle,
                 'capybara_sofus': make_sofus, 'fairy_birk_npc': make_birk, 'fairy_shopkeeper': make_kloevermynte, 'cat_morfar_mis': make_morfar_mis}
