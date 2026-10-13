"""The nine NEW small props of the home/loot features (addendum 3.5, task 5): four loot chests, two additive glimmers, the builders' tent and two resource veins.

  chest_trae  chest_jern  chest_fe  chest_konge     closed loot chests (wood / iron / fairy / king).  The OPENED state is the same sprite darkened by the engine plus a sparkle
                                                    burst (honest stub: there is no open-lid art), see lua/config/props_features.lua `opened`.
  dig_glimmer   unique_glimmer                      ADDITIVE soft ground sprites (blend add): the shimmer over a dig spot / over a hand-placed unique spot
  tent                                              the builders' tent that stands beside the farm house while an upgrade is under construction (2 x 2 tiles)
  slate_vein   marble_vein                          resource node art for P19 (pickaxe nodes, 1 x 1)

3D props are HM models (home_kit) baked by bake_features_props.py with the same camera and outline as every house and furniture piece; the glimmers are painted soft sprites
(numpy), not meshes.  Every builder returns a PropDef.  Coordinates: metres, Y up, origin = ground point at the centre of the footprint; +X screen right-down, +Z screen left-down.
"""
from __future__ import annotations
import math
import numpy as np
from home_kit import HM, T
import geometry as geo


class PropDef:
    def __init__(self, pm, footprint=(1, 1), shadow=('ellipse', .5, .3), glow=None):
        self.pm, self.footprint, self.shadow, self.glow = pm, footprint, shadow, glow


# ----------------------------------------------------------------------------------------------------------------------------------------------
# chests: one chassis, four materials
# ----------------------------------------------------------------------------------------------------------------------------------------------
def _chest(body, body_tex, band, band_tex, W=.92, D=.6, hb=.5, lid=.2):
    """box body + curved lid + two straps + lock plate + four feet; returns the model (the lock and extras are added by the callers)"""
    pm = HM()
    pm.box((0, hb / 2 + .04, 0), (W, hb, D), body, body_tex, .26)
    pm.ell((0, hb + .04, 0), (W / 2, lid, D / 2), body, body_tex, .72, None, 26, 14)                 # curved lid
    for x in (-W * .32, W * .32):
        pm.box((x, hb / 2 + .04, 0), (.08, hb + .02, D + .03), band, band_tex, .3)                    # strap round the body
        pm.ell((x, hb + .04, 0), (.042, lid + .015, D / 2 + .016), band, band_tex, .72, None, 12, 12)   # ... and over the lid
    pm.box((0, hb + .02, D / 2 + .005), (W + .02, .05, .03), band, band_tex, .3)                        # lip between lid and body
    for sx in (-1, 1):
        for sz in (-1, 1):
            pm.box((sx * (W / 2 - .05), .03, sz * (D / 2 - .05)), (.1, .08, .1), band, band_tex, .4)   # feet
    return pm


def chest_trae() -> PropDef:
    """common wooden chest: honey boards, dull iron straps, a small brass lock"""
    pm = _chest('B88A52', 'plank_h', '5B4A6E', 'soft')
    pm.box((0, .44, .31), (.13, .17, .045), 'E3C372', 'gold', .45)                                      # lock plate
    pm.ell((0, .44, .335), (.025, .03, .01), '4A3A4D', 'soft', 1.0, None, 8, 6)                          # keyhole
    for sx in (-1, 1):
        for sy in (.2, .5):
            pm.ell((sx * .43, sy, .31), (.022, .022, .014), '9A94A4', 'soft', 1.0, None, 8, 6)           # nail heads on the straps' ends
    return PropDef(pm, (1, 1), ('ellipse', .62, .34))


def chest_jern() -> PropDef:
    """iron chest: dark steel plates, riveted bands, corner brackets, a heavy padlock"""
    pm = _chest('6E6A7E', 'blocks', '9A94A4', 'soft', W=.94, D=.62, hb=.5, lid=.19)
    for x in (-.44, .44):
        for z in (-.27, .27):
            pm.box((x, .3, z), (.07, .52, .07), '4A3A4D', 'soft', .3)                                    # corner posts
    for x in np.linspace(-.38, .38, 5):
        for y in (.18, .36):
            pm.ell((x, y, .318), (.02, .02, .012), 'D2D6E2', 'soft', 1.0, None, 8, 6)                    # rivets
    pm.box((0, .42, .325), (.17, .2, .05), 'B7B1BE', 'soft', .35)                                        # lock block
    pm.ell((0, .54, .335), (.07, .07, .03), '6E6A7E', 'soft', .9, None, 12, 8)                           # shackle
    pm.ell((0, .54, .34), (.04, .04, .03), '2B2340', 'soft', 1.0, None, 10, 6)
    pm.ell((0, .39, .355), (.025, .03, .012), '2B2340', 'soft', 1.0, None, 8, 6)
    return PropDef(pm, (1, 1), ('ellipse', .64, .36))


def chest_fe() -> PropDef:
    """fairy chest: rose-lavender wood, gold filigree bands, a ring of flowers on the lid and a glowing teal clasp"""
    pm = _chest('E9A6BA', 'painted', 'B6A6E6', 'painted', W=.9, D=.58, hb=.48, lid=.21)
    for x in (-.3, .3):
        pm.ell((x, .3, .3), (.05, .12, .02), 'E3C372', 'gold', .9, None, 10, 8)                          # gold filigree leaves on the front
        pm.ell((x * .62, .2, .303), (.04, .07, .018), 'E3C372', 'gold', .9, (0, 0, 28 * (1 if x > 0 else -1)), 10, 8)
    pm.ell((0, .42, .312), (.09, .1, .03), 'E3C372', 'gold', .9, None, 12, 10)                           # clasp setting
    pm.emit_ell((0, .42, .338), (.045, .055, .02), '6FD6C4', 1.0, None, 12, 8)                            # the glowing teal gem
    for k in range(7):                                                                                   # flower garland along the lid
        a = k / 6
        x = -.34 + a * .68; y = .55 + .185 * math.sin(a * math.pi) * .98
        pm.ell((x, y, .02), (.06, .05, .06), ('FBF5E6', 'F5C6D6', 'FBEAC8')[k % 3], 'soft', 1.0, None, 10, 8)
        pm.ell((x, y + .015, .02), (.022, .02, .022), 'F2C14E', 'soft', 1.0, None, 8, 6)
    for k, (x, z) in enumerate([(-.34, .2), (.32, .22), (0, -.12)]):                                      # tiny leaves between the flowers
        pm.ell((x, .62 + .02 * k, z), (.07, .018, .035), '6FAA46', 'leaf', .9, (0, 40 * k, 12), 10, 6)
    return PropDef(pm, (1, 1), ('ellipse', .6, .34), glow=('9BE7D8', 36, .30, (0, .42, .33)))


def chest_konge() -> PropDef:
    """king's chest: dark walnut, plates of beaten gold, a crown on the lid, three gems, gold ball feet"""
    pm = HM(); W, D, hb, lid = 1.02, .68, .52, .22
    pm.box((0, hb / 2 + .07, 0), (W, hb, D), '5A3B26', 'wood', .26)
    pm.ell((0, hb + .07, 0), (W / 2, lid, D / 2), '5A3B26', 'wood', .72, None, 28, 14)
    for x in (-W * .34, W * .34):
        pm.box((x, hb / 2 + .07, 0), (.12, hb + .02, D + .03), 'E3C372', 'gold', .3)
        pm.ell((x, hb + .07, 0), (.062, lid + .016, D / 2 + .016), 'E3C372', 'gold', .72, None, 12, 12)
    pm.box((0, hb + .05, D / 2 + .005), (W + .03, .07, .035), 'E3C372', 'gold', .3)                       # gold lip
    pm.box((0, .07 + .06, D / 2 + .005), (W + .03, .08, .035), 'E3C372', 'gold', .3)                      # gold base rail
    for sx in (-1, 1):
        for sz in (-1, 1):
            pm.ell((sx * (W / 2 - .06), .06, sz * (D / 2 - .06)), (.07, .07, .07), 'E3C372', 'gold', 1.0, None, 12, 8)   # gold ball feet
    pm.box((0, .4, D / 2 + .012), (.38, .26, .03), '6A4C8C', 'velvet', .35)                               # purple velvet panel
    pm.box((0, .4, D / 2 + .028), (.4, .28, .012), 'E3C372', 'gold', .3)
    pm.box((0, .4, D / 2 + .034), (.34, .22, .01), '6A4C8C', 'velvet', .35)
    # crown on the front panel: band + five points + jewels
    pm.box((0, .34, D / 2 + .05), (.24, .07, .03), 'F2D58A', 'gold', .4)
    for k, x in enumerate((-.1, -.05, 0, .05, .1)):
        h = .14 if k == 2 else (.1 if k % 2 == 0 else .08)
        pm.ell((x, .37 + h / 2, D / 2 + .05), (.026, h / 2, .014), 'F2D58A', 'gold', .9, None, 8, 8)
        pm.ell((x, .37 + h, D / 2 + .05), (.016, .016, .014), 'B3436B' if k % 2 == 0 else '6FD6C4', 'soft', 1.0, None, 8, 6)
    for k, (c, x) in enumerate((('B3436B', -.22), ('3F5FA0', 0.0), ('48B97F', .22))):                   # three gems on the lid
        pm.ell((x, hb + lid * .92 + .075, .0), (.07, .05, .07), 'E3C372', 'gold', 1.0, None, 12, 8)
        pm.ell((x, hb + lid * .92 + .105, .0), (.05, .06, .05), c, 'crystalf@0.4', 1.0, None, 10, 8)
    pm.ell((0, .27, D / 2 + .028), (.045, .05, .018), 'F2D58A', 'gold', 1.0, None, 10, 8)                 # keyhole boss
    pm.ell((0, .25, D / 2 + .042), (.016, .022, .01), '2B2340', 'soft', 1.0, None, 8, 6)
    return PropDef(pm, (1, 1), ('ellipse', .7, .38), glow=('F2D58A', 42, .32, (0, .5, .3)))


# ----------------------------------------------------------------------------------------------------------------------------------------------
# tent
# ----------------------------------------------------------------------------------------------------------------------------------------------
def tent() -> PropDef:
    """the builders' ridge tent (rose and cream stripes) with a dark open door flap, guy ropes, pegs, a lantern and a bundle of poles; 2 x 2 tiles"""
    pm = HM(); L = 1.7; Wd = 1.3; hr = 1.25
    x0, x1, z0, z1 = -L / 2, L / 2, -Wd / 2, Wd / 2
    # two canvas slopes: boxes tilted about the ridge (ridge along x); the door is the +x gable end (faces screen right-down)
    th = math.degrees(math.atan2(hr, Wd / 2)); slant = math.hypot(hr, Wd / 2)
    for s in (-1, 1):
        c = (0, hr / 2 + .02, s * Wd / 4)
        pm.box(c, (L + .1, .04, slant), 'E58FA6', 'stripe', power=.2, rot=(s * th, 0, 0), pivot=c)
    pm.cyl2((x0 - .06, hr + .045, 0), (x1 + .06, hr + .045, 0), .035, .035, 'B88A52', 'wood', 8, 2)        # ridge pole poking out at both ends
    # back gable (-x): canvas triangle; front gable (+x): dark opening + two folded-back flaps
    tri = geo.rounded_triangle([(-Wd / 2 + .02, 0), (Wd / 2 - .02, 0), (0, hr - .04)], 4)
    pm._gable_end(tri, x0 + .01, 'F4E6C4', 'weave', 'x', 0)
    pm._gable_end(tri, x1 - .01, '2B2340', 'soft', 'x', 0)                                                  # the dark inside
    for s in (-1, 1):                                                                                       # flaps rolled to the sides
        pm.cyl2((x1 + .02, .04, s * (Wd / 2 - .06)), (x1 + .06, hr * .62, s * (Wd / 2 - .22)), .045, .035, 'E58FA6', 'weave', 10, 4)
        pm.box((x1 + .03, hr * .3, s * (Wd / 2 - .17)), (.03, hr * .55, .16), 'F4E6C4', 'weave', .3, rot=(s * 14, 0, 0))
    pm.box((x1 + .04, .02, 0), (.28, .03, .5), '8C6B3F', 'plank_h', .3)                                      # a plank as doormat
    # guy ropes + pegs at the four corners
    for sx in (-1, 1):
        for sz in (-1, 1):
            p0 = (sx * (L / 2 + .05), hr * .55, sz * Wd * .3); p1 = (sx * (L / 2 + .55), .05, sz * (Wd / 2 + .65))
            pm.cyl2(p0, p1, .009, .009, 'D9C79B', 'soft', 5, 3)
            pm.cyl2((p1[0], .1, p1[2]), (p1[0], -.02, p1[2]), .02, .016, 'B88A52', 'wood', 6, 2)
    pm.cyl2((x0 - .08, 0, Wd * .5 + .14), (x0 - .08, .46, Wd * .5 + .14), .15, .15, 'A47944', 'plank_v', 12, 4)    # barrel beside the tent
    pm.ell((x0 - .08, .46, Wd * .5 + .14), (.14, .02, .14), '8C6B3F', 'plank_h', 1.0, None, 12, 6)
    pm.box((x0 - .42, .17, Wd * .5 + .02), (.34, .34, .34), 'C9A66B', 'plank_h', .3, rot=(0, 18, 0))          # crate
    pm.box((x0 - .42, .17, Wd * .5 + .02), (.36, .05, .36), '8C6B3F', 'plank_h', .3, rot=(0, 18, 0))
    pm.cyl2((x1 + .5, 0, -Wd * .5 - .1), (x1 + .5, .85, -Wd * .5 - .1), .022, .02, '4A3A4D', 'soft', 6, 2)         # lantern post next to the door
    pm.cyl2((x1 + .5, .82, -Wd * .5 - .1), (x1 + .5, .82, -Wd * .5 + .12), .015, .015, '4A3A4D', 'soft', 6, 2)
    from home_traetoppen import lantern
    lantern(pm, x1 + .5, .66, -Wd * .5 + .12)
    pm.cyl2((0, hr + .05, 0), (0, hr + .5, 0), .012, .012, '4A3A4D', 'soft', 6, 2)                          # little flag
    pm.box((.12, hr + .42, 0), (.22, .13, .01), '6B9A3E', 'weave', .3)
    return PropDef(pm, (2, 2), ('rect',))


# ----------------------------------------------------------------------------------------------------------------------------------------------
# veins (pickaxe resource nodes)
# ----------------------------------------------------------------------------------------------------------------------------------------------
def slate_vein() -> PropDef:
    """a layered outcrop: stacked blue-grey strata with pale cut edges, tilted plates fanning out of the pile, chips and loose slabs at the foot"""
    pm = HM(); rng = np.random.default_rng(7)
    strata = [(.70, .46, .16, '5F6C8E', 8), (.62, .42, .16, '7C88A8', -6), (.54, .36, .15, '67738F', 14), (.44, .30, .15, '8895B5', -10), (.32, .24, .13, '727FA0', 6)]
    y = .0
    for k, (w, d, h, col, ry) in enumerate(strata):
        pm.box((0, y + h / 2, 0), (w, h, d), col, 'stone', .22, rot=(0, ry, 0))                       # one stratum (planar stone texture, hard edges)
        pm.box((0, y + h - .012, 0), (w * .985, .035, d * .985), 'B9C3DC', 'soft', .24, rot=(0, ry, 0))     # its pale top edge
        y += h
    for k, (x, z, w, h, ry, tilt) in enumerate([(-.42, .16, .34, .62, 28, -16), (.4, .12, .3, .5, -24, 18), (.05, .34, .3, .42, 6, -8)]):
        col = ('6E7A98', '7C88A8', '5F6C8E')[k]
        pm.box((x, h / 2 + .03, z), (w, h, .08), col, 'stone', .3, rot=(0, ry, tilt))                  # a plate fanning out of the pile
        pm.box((x, h + .03, z), (w * .96, .03, .09), 'B9C3DC', 'soft', .3, rot=(0, ry, tilt))
    for k in range(5):                                                                                       # loose slabs and chips at the foot
        a = rng.uniform(0, 6.28); r = rng.uniform(.5, .68)
        pm.box((math.cos(a) * r, .035 + .02 * (k % 2), math.sin(a) * r * .8), (.24, .05, .17), '6E7A98', 'stone', .3, rot=(0, math.degrees(a) * 1.7, 4 * k))
    return PropDef(pm, (1, 1), ('ellipse', .8, .42))


def marble_vein() -> PropDef:
    """a raw marble outcrop: three angular cream blocks, lavender-grey veins running over their faces, a polished top, chipped pieces at the foot"""
    pm = HM()
    blocks = [((0, .27, 0), (.78, .54, .56), 14, 'F2EBDD'), ((.34, .5, -.08), (.46, .42, .4), -22, 'F7F0E2'), ((-.3, .44, .1), (.4, .36, .34), 30, 'E8DFCB')]
    for c, sz, ry, col in blocks:
        pm.box(c, sz, col, 'marble', .2, rot=(0, ry, 0))
        pm.box((c[0], c[1] + sz[1] / 2 - .01, c[2]), (sz[0] * .97, .03, sz[2] * .97), 'FBF5E6', 'soft', .24, rot=(0, ry, 0))           # polished top
    # veins: thin darker bars proud of the front faces (screen left-down = +z, right-down = +x), following the block's yaw
    for k, (x, y, z, ln, ry, tilt) in enumerate([(-.06, .3, .31, .5, 14, 28), (.22, .16, .3, .34, 14, -34), (.52, .5, .08, .32, -22, 40), (.36, .42, .18, .22, -22, -20),
                                                  (-.42, .46, .26, .26, 30, 22), (-.2, .56, .22, .2, 30, -30)]):
        pm.box((x, y, z), (ln, .04, .03), 'A99BC8' if k % 2 == 0 else '8E93B4', 'soft', .4, rot=(0, ry, tilt))
    for k in range(3):                                                                                       # chipped blocks
        pm.box((.58 + .12 * k, .08, -.38 + .24 * k), (.2, .16, .16), 'E8DFCB', 'marble', .26, rot=(0, 15 + 20 * k, 0))
    pm.box((-.58, .075, .32), (.22, .15, .17), 'F2EBDD', 'marble', .26, rot=(0, -20, 0))
    return PropDef(pm, (1, 1), ('ellipse', .8, .42))


# ----------------------------------------------------------------------------------------------------------------------------------------------
# glimmers (painted additive sprites)
# ----------------------------------------------------------------------------------------------------------------------------------------------
def _star(img, cx, cy, r, strength, sq=1.0):
    """add a soft 4-point star of radius r (px) to the float image `img` (H, W) at (cx, cy); sq squashes the vertical arm"""
    h, w = img.shape
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = (x - cx) / r, (y - cy) / (r * sq)
    core = np.exp(-(dx * dx + dy * dy) * 14)
    arm_x = np.exp(-(dy * dy) * 160) * np.exp(-np.abs(dx) * 3.2) * (np.abs(dx) < 1.0)
    arm_y = np.exp(-(dx * dx) * 160) * np.exp(-np.abs(dy) * 3.2) * (np.abs(dy) < 1.0)
    img += strength * np.clip(core + .55 * (arm_x + arm_y), 0, 1.3)


def glimmer(kind: str):
    """RGBA float-painted additive sprite: kind 'dig' (warm gold shimmer on the ground, 1 tile) or 'unique' (pale light pillar + ring + rising sparkles).
    Returns (PIL RGBA image, pivot (x, y), footprint, blend 'add').  RGB is the normalised colour, alpha the brightness (the engine blends additive)."""
    from PIL import Image
    rng = np.random.default_rng({'dig': 11, 'unique': 23}[kind])
    if kind == 'dig':
        W, H = 112, 72; cx, cy = W / 2, H * .56
        y, x = np.mgrid[0:H, 0:W].astype(np.float32)
        d = np.hypot((x - cx) / 40, (y - cy) / 21)                                                  # ground ellipse in the 36 degree view (2 : 1.1)
        L = np.exp(-d * d * 2.2) * .62 + np.exp(-((d - .82) ** 2) * 30) * .28                          # soft halo + a thin shimmering rim
        for (sx, sy, r, s) in [(-.30, -.1, 9, .95), (.26, -.18, 7, .8), (.05, .12, 11, 1.0), (.36, .1, 6, .65), (-.12, -.3, 6, .7)]:
            _star(L, cx + sx * 80, cy + sy * 42, r, s, .9)
        rgb = np.array([255, 222, 130], np.float32) / 255
        pivot = (int(cx), int(cy)); fp = (1, 1)
    else:
        W, H = 104, 176; cx, cy = W / 2, H - 38
        y, x = np.mgrid[0:H, 0:W].astype(np.float32)
        ring = np.exp(-(((np.hypot((x - cx) / 38, (y - cy) / 20)) - .9) ** 2) * 36) * .8        # ground ring
        halo = np.exp(-(np.hypot((x - cx) / 34, (y - cy) / 17) ** 2) * 2.4) * .4
        beam = np.exp(-(((x - cx) / (16 + (cy - y) * .06)) ** 2)) * np.clip((cy - y) / (cy), 0, 1) ** .7 * np.clip((y - 4) / 40, 0, 1) * .5
        L = ring + halo + beam
        for k in range(9):                                                                           # sparkles drifting up the beam
            t = (k + .5) / 9
            _star(L, cx + math.sin(t * 9 + 1) * 20 + rng.uniform(-4, 4), cy - t * (cy - 14), 5 + 5 * (1 - t) + (k % 3), .9 - .4 * t, 1.0)
        _star(L, cx, cy - 6, 13, 1.0, .8)
        rgb = np.array([226, 214, 255], np.float32) / 255
        pivot = (int(cx), int(cy)); fp = (1, 1)
    a = np.clip(L, 0, 1)
    out = np.zeros((H, W, 4), np.float32)
    out[..., :3] = rgb[None, None, :] * (.78 + .22 * np.clip(L, 0, 1)[..., None])
    out[..., 3] = a
    out[a < .004] = 0
    return Image.fromarray(np.uint8(np.clip(out * 255 + .5, 0, 255)), 'RGBA'), pivot, fp


# id -> builder  (3D props)   and   id -> glimmer kind
PROPS3D = {'chest_trae': chest_trae, 'chest_jern': chest_jern, 'chest_fe': chest_fe, 'chest_konge': chest_konge,
           'tent': tent, 'slate_vein': slate_vein, 'marble_vein': marble_vein}
GLIMMERS = {'dig_glimmer': 'dig', 'unique_glimmer': 'unique'}
ORDER = ['chest_trae', 'chest_jern', 'chest_fe', 'chest_konge', 'dig_glimmer', 'unique_glimmer', 'tent', 'slate_vein', 'marble_vein']

# gameplay entries -> lua/config/props_features.lua (export_home.py adds `art`, `footprint` and `blend`).  Ground px as in the plan (rock r=30, trunk r=26, house footprint padded 20).
_OPEN = {'modulate': .55, 'burst': 'sparkle'}
GAMEPLAY = {
    'chest_trae':  {'solid': {'shape': 'circle', 'radius': 24}, 'strips': 0, 'interact': 'chest', 'tier': 'trae', 'opened': _OPEN},
    'chest_jern':  {'solid': {'shape': 'circle', 'radius': 24}, 'strips': 0, 'interact': 'chest', 'tier': 'jern', 'opened': _OPEN},
    'chest_fe':    {'solid': {'shape': 'circle', 'radius': 24}, 'strips': 0, 'interact': 'chest', 'tier': 'fe', 'opened': _OPEN},
    'chest_konge': {'solid': {'shape': 'circle', 'radius': 26}, 'strips': 0, 'interact': 'chest', 'tier': 'konge', 'opened': _OPEN},
    'dig_glimmer': {'solid': {'shape': 'none'}, 'strips': 0, 'interact': 'dig'},
    'unique_glimmer': {'solid': {'shape': 'none'}, 'strips': 0, 'interact': 'unique_spot'},
    'tent': {'solid': {'shape': 'footprint', 'pad': 20}, 'strips': 0, 'interact': 'none'},
    'slate_vein': {'solid': {'shape': 'circle', 'radius': 30}, 'strips': 0, 'interact': 'node', 'node_kind': 'slate'},
    'marble_vein': {'solid': {'shape': 'circle', 'radius': 30}, 'strips': 0, 'interact': 'node', 'node_kind': 'marble'},
}
