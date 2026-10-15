"""props_town.py - Hyggebyen: the town's buildings (mushroom-house variants with signs), street furniture, the market quarter, the beehive
stand, the door mat, the roof-repair kit, the lantern colourways and the four crops the first export did not have.

SAME vocabulary and renderer as props_traetoppen.py (PM: box / cyl / curve / ell / clump / pillow; metres, Y up, tile axes = world X and Z,
footprint centred on the origin = ground pivot; camera azimuth 45, so +X faces screen right-down and +Z screen left-down).  Palette of the
style guide's Hyggebyen: rose E58FA6, lavender 9B86D6 / B9A9E8, mint 7FC8A5, cream FBF5E6, gold E3C372, honey wood B88A52.
Registers itself into props_traetoppen.PROPS, so `bake_props.py <id>` bakes it unchanged.
"""
from __future__ import annotations
import math
import numpy as np
import props_traetoppen as pp
from props_traetoppen import PM, spec, T, WOOD, PropSpec, LEAFG

ROSE, LAV, LAV2, MINT, CREAM, GOLD = 'E58FA6', '9B86D6', 'B9A9E8', '7FC8A5', 'FBF5E6', 'E3C372'


def _scale(m, k):
    """Scale a finished model about the ground origin (a bigger variant of a builder written for one tile size)."""
    for g in m.groups:
        for s in g.shapes:
            s.vertices = s.vertices * k


# ================================================================================================ signs
def _sign(pm: PM, x, z, symbol, board='E8D2A0', frame='7A4E2D', h=1.15):
    """A freestanding signboard on a post facing +z (the screen's lower-left face).  `symbol` draws on the board (+z face)."""
    pm.cyl((x, 0, z), (x, h + .35, z), .045, .04, WOOD['dark'], 'bark', 8, n=3)
    pm.box((x, h, z), (.74, .46, .06), board, 'plank', power=.3)
    for sx in (-1, 1):
        pm.box((x + sx * .39, h, z), (.05, .5, .08), frame, 'bark', power=.3)
    pm.box((x, h + .26, z), (.82, .05, .09), frame, 'bark', power=.3)
    pm.box((x, h - .26, z), (.82, .05, .09), frame, 'bark', power=.3)
    symbol(pm, x, h, z + .05)


def sym_loaf(pm, x, y, z):
    pm.ell((x, y, z), (.24, .11, .05), 'D9944A', 'straw', power=.9, seg=18, rings=10)
    for k in (-1, 0, 1):
        pm.box((x + k * .1, y + .03, z + .035), (.025, .1, .02), 'F2D9A0', 'soft', power=.3, rot=(0, 0, 24))


def sym_sprout(pm, x, y, z):
    pm.box((x, y - .06, z), (.025, .2, .02), '5C9A52', 'soft')
    for s in (-1, 1):
        pm.ell((x + s * .1, y + .06, z), (.1, .045, .02), '6FAA46', 'leaf', rot=(0, 0, s * 28), seg=10, rings=6)
    pm.ell((x, y - .17, z), (.14, .03, .02), '6B4A33', 'soil', seg=10, rings=6)


def sym_anvil(pm, x, y, z):
    pm.box((x, y - .1, z), (.2, .07, .03), '4A3A4D', 'stone', power=.3)
    pm.box((x, y - .02, z), (.3, .09, .03), '5B4A6E', 'stone', power=.3)
    pm.ell((x + .2, y - .01, z), (.1, .045, .02), '5B4A6E', 'stone', seg=10, rings=6)
    pm.box((x - .02, y + .12, z), (.05, .17, .02), WOOD['honey'], 'plank', rot=(0, 0, 25))
    pm.box((x - .09, y + .18, z), (.13, .07, .03), '7C7C8A', 'stone', rot=(0, 0, 25))


def sym_paw(pm, x, y, z):
    pm.ell((x, y - .05, z), (.1, .08, .02), '6B4A33', 'soft', seg=12, rings=8)
    for dx, dy in ((-.13, .06), (-.045, .12), (.045, .12), (.13, .06)):
        pm.ell((x + dx, y + dy - .03, z), (.04, .045, .02), '6B4A33', 'soft', seg=8, rings=6)


def sym_star(pm, x, y, z):
    for k in range(5):
        a = math.radians(90 + k * 72)
        pm.box((x + math.cos(a) * .07, y + math.sin(a) * .07, z), (.055, .17, .02), 'F2C14E', 'crystal', rot=(0, 0, math.degrees(a) - 90))
    pm.ell((x, y, z), (.07, .07, .02), 'FFE49A', 'crystal', seg=10, rings=6)


def sym_crown(pm, x, y, z):
    pm.box((x, y - .06, z), (.3, .09, .03), 'E9C06B', 'crystal', power=.4)
    for dx, hh in ((-.12, .15), (0, .2), (.12, .15)):
        pm.box((x + dx, y + hh / 2 - .03, z), (.06, hh, .03), 'E9C06B', 'crystal', power=.4)
        pm.ell((x + dx, y + hh - .02, z), (.035, .035, .02), 'E58FA6', 'soft', seg=8, rings=6)


def sym_clock(pm, x, y, z):
    pm.ell((x, y, z), (.2, .2, .02), 'FBF5E6', 'porcelain', seg=20, rings=10)
    pm.box((x, y + .06, z + .02), (.02, .13, .015), '2B2340', 'soft')
    pm.box((x + .04, y, z + .02), (.1, .02, .015), '2B2340', 'soft', rot=(0, 0, 20))


def _round_door(pm, x, z, color='7A4E2D', h=.52, w=.34):
    pm.ell((x, h + .1, z), (w, h, .12), color, 'plank', power=.75, seg=20, rings=12)
    pm.ell((x + .22 * (w / .34), h + .14, z + .09), (.04, .04, .03), 'E9C06B', 'crystal', seg=8, rings=6)


def mushroom_house(cap=ROSE, spot=CREAM, stem='F4E6C4', door='7A4E2D', scale=1.0, name='house', chimney=True, spots=12, glow=('FFD98A', 20, .22),
                   stem_h=1.55, cap_r=1.55, cap_h=.78, footprint=(2, 2), shadow=(1.7, .8), extra=None, spot_seed=5, trim=None):
    """The base of every Hyggebyen building: the verified mushroom house (stem + cap + spots + round door + glowing window) with options."""
    pm = PM()
    pm.cyl((0, 0, 0), (0, stem_h, 0), .98, .78, stem, 'soft', sides=24, n=8)
    pm.ell((0, stem_h + .07, 0), (cap_r, cap_h, cap_r), cap, 'soft', power=.9, seg=36, rings=20)
    pm.ell((0, stem_h - .12, 0), (cap_r - .1, .12, cap_r - .1), 'E9C9B5', 'soft', seg=30, rings=8)           # gills
    if trim:
        pm.ell((0, stem_h + .0, 0), (cap_r + .02, .07, cap_r + .02), trim, 'crystal', power=.6, seg=36, rings=8)
    for i in range(spots):
        a = i * 2.4; e = .35 + .55 * ((i * 37) % 10) / 10
        c = np.array([math.cos(a) * math.cos(e) * (cap_r - .02), stem_h + .07 + math.sin(e) * (cap_h - .01), math.sin(a) * math.cos(e) * (cap_r - .02)])
        pm.ell(c, (.20, .06, .20), spot, 'soft', seg=14, rings=8)
    _round_door(pm, 0, .92, door)                                                      # round door on +z (screen lower-left)
    pm.ell((.9, .95, .12), (.12, .30, .30), 'FFE08F', 'glassglow', power=.8)         # glowing window on +x (screen lower-right)
    pm.ell((.97, .95, .12), (.08, .36, .36), '7A4E2D', 'plank', power=.8, seg=16, rings=10)
    pm.ell((.99, .95, .12), (.06, .30, .30), 'FFE08F', 'glassglow', power=.8, seg=16, rings=10)
    if chimney:
        pm.cyl((.5, 2.1, -.5), (.55, 2.75, -.55), .12, .1, '8A8494', 'stone', 12)
        pm.ell((.55, 2.78, -.55), (.15, .05, .15), '5B5468', 'stone', seg=12, rings=6)
    if extra:
        extra(pm)
    if scale != 1.0:
        _scale(pm.m, scale)
    return spec(pm, name, footprint=footprint, shadow=(shadow[0] * scale, shadow[1] * scale), glow=glow)


# ================================================================================================ buildings
def house_bakery() -> PropSpec:
    def extra(pm):
        # taller chimney with a puff of smoke, loaves on a little shelf, the loaf sign
        pm.cyl((.5, 2.1, -.5), (.55, 3.05, -.55), .15, .12, 'B5693F', 'roof', 12)
        pm.ell((.55, 3.08, -.55), (.19, .06, .19), '5B5468', 'stone', seg=12, rings=6)
        for dx, dy, r in ((.05, 3.35, .14), (.18, 3.62, .19), (.34, 3.95, .24)):
            pm.ell((.55 + dx, dy, -.55 + dx * .3), (r, r * .85, r), 'F6F2F6', 'soft', seg=14, rings=8)
        pm.box((-.62, .06, 1.3), (.2, .12, .5), WOOD['honey'], 'plank')
        for i in range(3):
            pm.ell((-.62, .2, 1.18 + i * .16), (.1, .07, .06), 'D9944A', 'straw', seg=10, rings=6)
        _sign(pm, .95, 1.35, sym_loaf)
    return mushroom_house('F0B58C', CREAM, name='house_bakery', extra=extra, chimney=False, glow=('FFD98A', 24, .28))


def house_seedshop() -> PropSpec:
    def extra(pm):
        # seedling crates by the door (green sprouts), a watering can, the sprout sign
        for i, x in enumerate((-.75, -1.05)):
            pm.box((x, .15, 1.08 + i * .22), (.34, .3, .34), WOOD['honey'], 'plank', power=.28)
            for k in range(3):
                pm.clump((x - .08 + k * .08, .38, 1.02 + i * .22 + (k % 2) * .06), .11, LEAFG, 'leaf', n=2, seed=k + i * 4)
        pm.cyl((-.55, 0, 1.4), (-.55, .24, 1.4), .1, .08, '7FA9C4', 'plank', 12, n=2)
        pm.curve([(-.55, .2, 1.4), (-.4, .22, 1.46), (-.34, .3, 1.5)], .018, .015, '7FA9C4', 'plank', 6, n=6)
        _sign(pm, .95, 1.35, sym_sprout, board='E3F2D4')
    return mushroom_house(MINT, CREAM, name='house_seedshop', extra=extra, chimney=True, spot_seed=8)


def house_smithy() -> PropSpec:
    def extra(pm):
        # a big stone chimney glowing at the top, an anvil on a stump and a barrel by the door, the anvil sign
        pm.cyl((.5, 1.9, -.5), (.58, 3.25, -.58), .22, .17, '6E6985', 'stone', 14)
        pm.ell((.58, 3.28, -.58), (.26, .07, .26), '4A3A4D', 'stone', seg=14, rings=6)
        pm.ell((.58, 3.25, -.58), (.14, .05, .14), 'FF9A4A', 'glassglow', seg=12, rings=6)
        pm.cyl((-.8, 0, 1.2), (-.8, .38, 1.2), .2, .18, '7A4E2D', 'bark', 12, n=3)
        pm.box((-.8, .5, 1.2), (.42, .12, .2), '4A3A4D', 'stone', power=.3)
        pm.box((-.8, .62, 1.2), (.26, .1, .17), '5B4A6E', 'stone', power=.3)
        pm.ell((-.55, .6, 1.2), (.11, .05, .07), '5B4A6E', 'stone', seg=10, rings=6)
        pm.cyl((-1.25, 0, .85), (-1.25, .55, .85), .22, .2, WOOD['honey'], 'plank', 14, n=3)
        pm.cyl((-1.25, .45, .85), (-1.25, .48, .85), .23, .23, WOOD['dark'], 'bark', 14, n=2)
        _sign(pm, .95, 1.35, sym_anvil, board='D8CCE0')
    return mushroom_house('8A8CA8', 'C9CBE0', stem='D9CDBA', door='4A3A4D', name='house_smithy', extra=extra, chimney=False, glow=('FF9A4A', 24, .30), spot_seed=11)


def house_animalstore() -> PropSpec:
    def extra(pm):
        # hay bales, a little pen fence with a trough, the paw sign
        for i, (x, z) in enumerate(((-.85, 1.1), (-1.15, .75))):
            pm.box((x, .22, z), (.46, .4, .34), 'E3C372', 'straw', power=.3, rot=(0, 20 + i * 40, 0))
            pm.box((x, .22, z), (.5, .05, .36), 'C9A66B', 'straw', power=.3, rot=(0, 20 + i * 40, 0))
        for sx in (-1, 1):
            pm.cyl((.4 + sx * .45, 0, 1.38), (.4 + sx * .45, .5, 1.38), .045, .04, WOOD['dark'], 'bark', 8, n=2)
        for y in (.22, .42):
            pm.box((.4, y, 1.38), (.95, .05, .05), WOOD['honey'], 'plank', power=.3)
        pm.box((.4, .1, 1.1), (.7, .12, .2), WOOD['dark'], 'bark', power=.3)
        pm.box((.4, .14, 1.1), (.6, .05, .14), '8FD2E6', 'soft', power=.3)
        _sign(pm, 1.35, .95, sym_paw, board='EDE0B8')
    return mushroom_house('E3C372', 'FFF3C8', stem='F1E2BE', door='8B4E2F', name='house_animalstore', extra=extra, chimney=True, spot_seed=13)


def tower_wizard() -> PropSpec:
    pm = PM()
    pm.cyl((0, 0, 0), (0, 3.3, 0), .92, .68, 'D6CBEA', 'soft', sides=24, n=10)
    pm.ell((0, 3.38, 0), (1.12, .16, 1.12), '8F7AC8', 'soft', seg=26, rings=8)                    # balcony ring under the cap
    # tall pointed cap: a stack of shrinking ellipsoids (a soft cone) with a droopy tip
    for i, (y, r, h) in enumerate(((3.55, 1.05, .45), (4.0, .85, .5), (4.5, .62, .5), (5.0, .42, .5), (5.45, .26, .42))):
        pm.ell((0, y, 0), (r, h, r), LAV if i % 2 == 0 else '8F7AC8', 'soft', power=.85, seg=28, rings=14)
    pm.curve([(0, 5.55, 0), (.18, 5.95, 0), (.42, 6.0, 0), (.55, 5.8, 0)], .13, .05, LAV, 'soft', 10, n=12)
    pm.ell((.55, 5.72, 0), (.08, .08, .08), 'F2C14E', 'crystal', seg=10, rings=8)
    rng = np.random.default_rng(3)
    for i in range(10):                                                                                # golden stars on the cap
        a = rng.uniform(0, 6.28); y = rng.uniform(3.7, 5.2); r = 1.0 - (y - 3.55) * .38
        pm.ell((math.cos(a) * max(r, .3), y, math.sin(a) * max(r, .3)), (.09, .09, .05), 'F2C14E', 'crystal', seg=8, rings=6)
    _round_door(pm, 0, .86, '5B4A6E', h=.55, w=.34)
    for (y, ang) in ((1.9, 40), (2.7, 320)):                                                           # two round glowing windows on the +x side
        ar = math.radians(ang)
        pm.ell((math.cos(ar) * .86, y, math.sin(ar) * .86), (.14, .17, .14), 'FFE08F', 'glassglow', power=.8, rot=(0, -ang, 0))
        pm.ell((math.cos(ar) * .9, y, math.sin(ar) * .9), (.10, .21, .21), '5B4A6E', 'stone', power=.8, rot=(0, -ang, 0), seg=14, rings=8)
        pm.ell((math.cos(ar) * .92, y, math.sin(ar) * .92), (.07, .16, .16), 'FFE08F', 'glassglow', power=.8, rot=(0, -ang, 0), seg=14, rings=8)
    for k in range(3):                                                                                  # moss at the foot
        pm.clump((-.8 + k * .08, .2 + k * .05, .5 - k * .35), .2, ('6E9A4A', '8CB866', '587F3A'), 'leaf', n=3, seed=k + 20, squash=.7)
    _sign(pm, .95, 1.35, sym_star, board='D8CCE8')
    return spec(pm, 'tower_wizard', footprint=(2, 2), shadow=(1.5, .75), glow=('C8B0FF', 26, .30, (0, 2.4, 0)))


def house_king_treetop() -> PropSpec:
    def extra(pm):
        # gold trim, a little flag, the crown sign above the door, a porch step and two torches
        pm.cyl((0, 3.55, 0), (0, 4.35, 0), .035, .03, WOOD['dark'], 'bark', 6, n=3)
        pm.box((.2, 4.2, 0), (.38, .22, .03), 'F2C14E', 'straw', power=.3)
        pm.ell((0, 4.38, 0), (.06, .06, .06), 'E9C06B', 'crystal', seg=8, rings=6)
        pm.box((0, .07, 1.35), (1.2, .14, .55), '9A9AA6', 'stone', power=.3)
        pm.box((0, .2, 1.18), (.9, .12, .3), 'B5B5C0', 'stone', power=.3)
        pm.box((0, 1.45, 1.12), (.5, .07, .12), '8B4E2F', 'bark', power=.3)
        sym_crown(pm, 0, 1.78, 1.12)
        for s in (-1, 1):
            pm.cyl((s * .62, 0, 1.18), (s * .62, .95, 1.18), .035, .03, WOOD['dark'], 'bark', 6, n=3)
            pm.ell((s * .62, 1.0, 1.18), (.07, .1, .07), 'FFD98A', 'glassglow', power=.8)
    return mushroom_house('8F70D2', 'F2C14E', stem='F4E6C4', door='6B4126', name='house_king_treetop', extra=extra, chimney=False, trim='E9C06B', spots=14,
                          glow=('FFD98A', 26, .3), footprint=(3, 3), spot_seed=21, shadow=(1.9, .9), scale=1.45)


def house_town_hall() -> PropSpec:
    def extra(pm):
        # a clock above the door, a little bell turret on the cap, a flag, steps and two flower boxes
        sym_clock(pm, 0, 1.78, 1.1)
        pm.cyl((0, 3.0, 0), (0, 3.6, 0), .3, .28, 'D6CBEA', 'soft', 16, n=3)                     # cupola with four dark arch windows
        for k in range(4):
            ar = math.radians(k * 90 + 45)
            pm.ell((math.cos(ar) * .29, 3.3, math.sin(ar) * .29), (.06, .13, .06), '5B4A6E', 'soft', seg=10, rings=6, rot=(0, -math.degrees(ar), 0))
        pm.ell((0, 3.78, 0), (.36, .26, .36), 'E9C06B', 'crystal', power=.8, seg=18, rings=10)    # gold onion dome
        pm.ell((0, 4.02, 0), (.06, .1, .06), 'E9C06B', 'crystal', seg=8, rings=6)
        pm.cyl((0, 4.05, 0), (0, 4.75, 0), .03, .03, WOOD['dark'], 'bark', 6, n=3)
        pm.box((.2, 4.58, 0), (.38, .24, .03), ROSE, 'straw', power=.3)
        pm.box((0, .07, 1.35), (1.3, .14, .55), '9A9AA6', 'stone', power=.3)
        pm.box((0, .2, 1.18), (.95, .12, .3), 'B5B5C0', 'stone', power=.3)
        for sx in (-1, 1):
            pm.box((sx * .7, .5, 1.1), (.4, .14, .18), WOOD['honey'], 'plank')
            for k in range(3):
                pm.ell((sx * .7 - .12 + k * .12, .62, 1.1), (.05, .06, .05), (ROSE, CREAM, 'F2C14E')[k], 'soft', seg=8, rings=6)
    return mushroom_house('F0D3E6', CREAM, stem='F4E6C4', door='6B4126', name='house_town_hall', extra=extra, chimney=False, trim=ROSE, spots=14,
                          glow=('FFD98A', 26, .3), footprint=(3, 3), spot_seed=17, shadow=(1.9, .9), scale=1.45)


# ================================================================================================ street furniture
def well() -> PropSpec:
    pm = PM()
    pm.cyl((0, 0, 0), (0, .6, 0), .56, .54, 'C9BDE0', 'stone', 22, n=4)
    pm.ell((0, .6, 0), (.6, .06, .6), 'DCD2EE', 'stone', seg=24, rings=6)
    pm.cyl((0, .5, 0), (0, .62, 0), .44, .44, '2B3A5A', 'soft', 20, n=2)                        # dark water
    pm.ell((0, .62, 0), (.36, .02, .36), '5FA9BE', 'glassglow', seg=18, rings=4)
    for sx in (-1, 1):
        pm.cyl((sx * .55, .45, 0), (sx * .55, 1.55, 0), .06, .05, WOOD['dark'], 'bark', 8, n=4)
    pm.cyl((-.6, 1.4, 0), (.6, 1.4, 0), .045, .045, WOOD['dark'], 'bark', 8, n=3)                # windlass beam
    for s in (-1, 1):                                                                              # small gable roof
        pm.box((0, 1.78, s * .28), (1.5, .08, .6), 'B5693F', 'roof', power=.25, rot=(s * 34, 0, 0), pivot=(0, 1.78, s * .28))
    pm.cyl((-.62, 1.84, 0), (.62, 1.84, 0), .06, .06, '8B4E2F', 'roof', 8, n=3)
    pm.curve([(0, 1.4, .0), (0, 1.1, .05), (0, .85, .08)], .012, .012, 'C9A66B', 'straw', 6, n=6)   # rope + bucket
    pm.cyl((0, .62, .08), (0, .84, .08), .1, .09, WOOD['honey'], 'plank', 10, n=2)
    return spec(pm, 'well', footprint=(1, 1), shadow=(.95, .4))


def fountain() -> PropSpec:
    pm = PM()
    pm.cyl((0, 0, 0), (0, .52, 0), 1.25, 1.18, 'C9BDE0', 'stone', 30, n=4)                     # basin wall
    pm.cyl((0, .46, 0), (0, .62, 0), 1.3, 1.3, 'DCD2EE', 'stone', 30, n=2)                     # rim
    pm.cyl((0, .5, 0), (0, .58, 0), 1.08, 1.08, '8FD2E6', 'glassglow', 28, n=2)                # the water
    pm.cyl((0, .55, 0), (0, 1.3, 0), .2, .15, 'D7CCEA', 'stone', 14, n=4)                       # pedestal
    pm.ell((0, 1.34, 0), (.62, .11, .62), 'DCD2EE', 'stone', seg=24, rings=8)                   # upper bowl
    pm.cyl((0, 1.3, 0), (0, 1.9, 0), .09, .07, 'D7CCEA', 'stone', 12, n=3)
    pm.ell((0, 1.96, 0), (.3, .07, .3), 'DCD2EE', 'stone', seg=18, rings=6)
    pm.ell((0, 2.2, 0), (.11, .3, .11), 'BFE6F2', 'glassglow', power=.9)                        # the jet
    for i in range(8):                                                                             # falling arcs into the basin
        a = i * math.pi / 4
        pm.curve([(0, 2.1, 0), (math.cos(a) * .3, 2.2, math.sin(a) * .3), (math.cos(a) * .72, 1.55, math.sin(a) * .72)], .035, .018, 'BFE6F2', 'glassglow', 6, n=10)
    for i in range(6):                                                                             # little blossom tufts on the rim
        a = i * 1.05 + .3
        pm.clump((math.cos(a) * 1.28, .66, math.sin(a) * 1.28), .12, ('F6C6D6', 'FBE3EA', 'E58FA6'), 'leaf', n=2, seed=i, squash=.8)
    return spec(pm, 'fountain', footprint=(2, 2), shadow=(1.6, .75), glow=('BFE6F2', 24, .25, (0, 1.9, 0)))


def _crate(pm, x, z, items):
    pm.box((x, .98, z), (.34, .16, .26), WOOD['dark'], 'plank', power=.3)
    for i, (c, r) in enumerate(items):
        pm.ell((x - .09 + (i % 3) * .09, 1.1, z - .05 + (i // 3) * .1), (r, r, r), c, 'soft', seg=10, rings=8)


def wares_veg(pm, L, D):
    _crate(pm, -L * .32, D * .12, [('F08A3C', .06)] * 6)
    _crate(pm, -L * .05, D * .12, [('C8463C', .06)] * 6)
    _crate(pm, L * .22, D * .12, [('97C95E', .07)] * 4 + [('E3C372', .05)] * 2)
    pm.cyl((L * .38, .96, D * .12), (L * .38, 1.22, D * .12), .1, .09, WOOD['honey'], 'plank', 10, n=2)


def wares_furniture(pm, L, D):
    pm.box((-L * .3, 1.15, D * .1), (.26, .04, .24), WOOD['pale'], 'plank', power=.3)             # a tiny stool + chair
    for sx in (-1, 1):
        for sz in (-1, 1):
            pm.box((-L * .3 + sx * .1, 1.04, D * .1 + sz * .09), (.03, .2, .03), WOOD['dark'], 'bark')
    pm.box((-L * .02, 1.14, D * .1), (.22, .04, .22), WOOD['honey'], 'plank')
    pm.box((-L * .02, 1.3, D * .1 - .1), (.22, .26, .03), WOOD['honey'], 'plank')
    pm.cyl((L * .22, 1.0, D * .1), (L * .22, 1.28, D * .1), .13, .13, 'C9A9D6', 'straw', 14, n=2)    # rolled rug
    pm.ell((L * .22, 1.28, D * .1), (.13, .02, .13), 'E8D2F0', 'straw', seg=12, rings=4)
    pm.cyl((L * .38, .98, D * .14), (L * .38, 1.5, D * .14), .02, .02, WOOD['dark'], 'bark', 6, n=3)  # a little lamp
    pm.ell((L * .38, 1.58, D * .14), (.1, .09, .1), 'FFE49A', 'glassglow', seg=10, rings=8)


def wares_tailor(pm, L, D):
    for i, c in enumerate(('E58FA6', '9B86D6', '7FC8A5', 'F2C14E')):                              # bolts of cloth
        pm.cyl((-L * .36 + i * .16, 1.0, D * .12), (-L * .36 + i * .16, 1.3, D * .12), .07, .07, c, 'straw', 12, n=2)
        pm.ell((-L * .36 + i * .16, 1.3, D * .12), (.07, .015, .07), c, 'straw', seg=10, rings=4)
    pm.cyl((L * .26, .96, D * .1), (L * .26, 1.55, D * .1), .025, .025, WOOD['dark'], 'bark', 6, n=3)  # dress form
    pm.ell((L * .26, 1.5, D * .1), (.1, .2, .1), 'E8D2F0', 'straw', seg=12, rings=8)
    pm.ell((L * .26, 1.3, D * .1), (.15, .12, .15), 'B9A9E8', 'straw', seg=12, rings=8)
    pm.curve([(L * .1, 1.9, 0), (L * .1, 1.6, D * .15), (L * .13, 1.4, D * .18)], .02, .015, 'F6C6D6', 'straw', 6, n=8)   # a ribbon from the awning


WARES = {'veg': wares_veg, 'furniture': wares_furniture, 'tailor': wares_tailor}


def market_stall(awning=(ROSE, CREAM), wares='veg', name='market_stall') -> PropSpec:
    pm = PM()
    L, D = T * 1.85, T * .8
    for sx in (-1, 1):
        for sz in (-1, 1):
            pm.cyl((sx * L / 2, 0, sz * D / 2), (sx * L / 2, 2.0 if sz > 0 else 2.3, sz * D / 2), .05, .045, WOOD['dark'], 'bark', 8, n=4)
    pm.box((0, .5, D * .1), (L, .8, D * .55), WOOD['honey'], 'plank', power=.26)               # counter
    pm.box((0, .93, D * .1), (L + .06, .06, D * .62), WOOD['pale'], 'plank', power=.3)
    pm.box((0, .96, -D * .38), (L - .1, .26, .06), WOOD['dark'], 'bark', power=.3)               # back shelf board
    n = 8
    for i in range(n):                                                                             # striped awning sloping down to the front (+z)
        x = -L / 2 + (i + .5) * L / n
        pm.box((x, 2.16, 0), (L / n * .98, .05, D * 1.5), awning[i % 2], 'straw', power=.28, rot=(16, 0, 0), pivot=(x, 2.16, 0))
    for i in range(n):                                                                             # scalloped valance
        x = -L / 2 + (i + .5) * L / n
        pm.ell((x, 1.9, D * .72), (L / n * .5, .09, .035), awning[i % 2], 'straw', seg=12, rings=6)
    WARES[wares](pm, L, D)
    pm.ell((0, 1.85, D * .76), (.07, .1, .07), 'FFD98A', 'glassglow', power=.8)
    return spec(pm, name, footprint=(2, 1), shadow=(1.25, .62), glow=('FFD98A', 18, .15, (0, 1.85, D * .76)))


def plank_stack() -> PropSpec:
    pm = PM()
    L = T * 1.7
    for x in (-L * .36, L * .36):                                                                  # trestles
        pm.box((x, .16, 0), (.08, .32, T * .55), WOOD['dark'], 'bark', power=.3)
    for i in range(5):                                                                             # stacked planks
        pm.box((0, .38 + i * .085, 0), (L, .07, T * .42 + (i % 2) * .04), WOOD['honey'] if i % 2 else WOOD['pale'], 'plank', power=.28)
    for i in range(3):
        pm.box((0, .83, -.12 + i * .12), (L * .6, .06, .1), WOOD['pale'], 'plank', power=.28)
    pm.cyl((L * .1, .98, .05), (L * .1, .98, -.3), .1, .1, 'B88A52', 'bark', 12, n=2)               # a log on top
    pm.cyl((.35, .12, T * .5), (-.2, .12, T * .5 + .1), .13, .13, '7A4E2D', 'bark', 12, n=3)        # a log at the foot
    pm.box((-L * .3, .06, T * .36), (.3, .03, .2), 'E9D3A3', 'straw', power=.4)                     # sawdust
    return spec(pm, 'plank_stack', footprint=(2, 1), shadow=(1.0, .45))


def wheat_sack() -> PropSpec:
    pm = PM()
    pm.ell((0, .3, 0), (.34, .32, .3), 'D9C28A', 'straw', power=.85, seg=22, rings=14)
    pm.ell((0, .56, 0), (.14, .1, .13), 'C9A66B', 'straw', seg=14, rings=8)                         # tied neck
    pm.ell((0, .5, 0), (.16, .03, .15), 'B5693F', 'straw', seg=14, rings=4)                         # the string
    for k in range(7):                                                                              # wheat ears sticking out
        a = k * 0.9
        base = np.array([math.cos(a) * .05, .58, math.sin(a) * .05])
        tip = np.array([math.cos(a) * .2, .98 + (k % 3) * .06, math.sin(a) * .2])
        pm.curve([base, (base + tip) / 2 + [0, .08, 0], tip], .012, .008, 'D9B85A', 'straw', 5, n=8)
        pm.ell(tip, (.025, .07, .025), 'E3C372', 'straw', seg=8, rings=6)
    return spec(pm, 'wheat_sack', footprint=(1, 1), shadow=(.5, .22))


def beehive_stand() -> PropSpec:
    pm = PM()
    for sx in (-1, 1):
        for sz in (-1, 1):
            pm.cyl((sx * .38, 0, sz * .26), (sx * .38, .55, sz * .26), .045, .04, WOOD['dark'], 'bark', 8, n=3)
    pm.box((0, .58, 0), (1.0, .07, .7), WOOD['honey'], 'plank', power=.3)
    for x in (-.24, .24):                                                                          # straw skeps
        for k, (y, r, h) in enumerate(((.78, .27, .1), (.92, .24, .1), (1.04, .2, .09), (1.14, .15, .08), (1.21, .08, .06))):
            pm.ell((x, y, 0), (r, h, r), 'E3C372' if k % 2 == 0 else 'D9B15A', 'straw', seg=18, rings=8)
        pm.ell((x, .72, .22), (.07, .05, .04), '2B2340', 'soft', seg=10, rings=6)                  # entrance
    for x, y, z in ((.05, 1.0, .35), (-.4, .95, .4), (.45, 1.15, .3)):                               # bees
        pm.ell((x, y, z), (.025, .02, .03), 'F2C14E', 'soft', seg=8, rings=6)
        pm.ell((x, y + .005, z), (.026, .012, .012), '2B2340', 'soft', seg=8, rings=6)
    pm.clump((.6, .12, .4), .15, ('F6C6D6', 'FBE3EA', 'E58FA6'), 'leaf', n=2, seed=3, squash=.8)       # a few flowers at the foot
    pm.clump((-.62, .1, .42), .13, ('B9A9E8', 'D9C8F4', '9B86D6'), 'leaf', n=2, seed=4, squash=.8)
    return spec(pm, 'beehive_stand', footprint=(1, 1), shadow=(.75, .35))


def _flagstones(layout, name, tone=('A99FBF', 'B9AFD0', '9C92B3', 'C4B4C8')):
    pm = PM()
    for i, (x, z, rx, rz, rot) in enumerate(layout):
        pm.ell((x, .035, z), (rx, .035, rz), tone[i % len(tone)], 'stone', power=.7, rot=(0, rot, 0), seg=18, rings=8)
    return spec(pm, name, footprint=(1, 1), shadow=None)


def stone_path_a() -> PropSpec:       # a run along x (screen lower-right)
    return _flagstones([(-.32, -.04, .26, .2, 12), (.02, .06, .27, .22, -8), (.36, -.03, .24, .2, 20), (-.02, -.3, .18, .13, 0), (.2, .34, .17, .12, 30)], 'stone_path_a')


def stone_path_b() -> PropSpec:       # a run along z (screen lower-left)
    return _flagstones([(-.03, -.34, .2, .26, 8), (.05, .0, .22, .27, -14), (-.02, .36, .2, .24, 22), (-.32, .12, .12, .18, 0), (.3, -.18, .13, .17, 40)], 'stone_path_b')


def stone_path_c() -> PropSpec:       # a loose scatter / junction
    return _flagstones([(-.3, -.28, .22, .18, 18), (.18, -.32, .2, .16, -10), (.0, .0, .25, .21, 5), (-.33, .3, .18, .15, 30), (.31, .27, .21, .17, -22)], 'stone_path_c')


def bed() -> PropSpec:
    """The door mat in front of the farmhouse (the `bed` marker's prop): a woven oval mat with two stripes and a tiny acorn charm."""
    pm = PM()
    pm.ell((0, .03, 0), (.52, .03, .36), 'C9A66B', 'straw', power=.7, seg=28, rings=6)
    pm.ell((0, .055, 0), (.44, .02, .29), 'E8D2A0', 'straw', power=.8, seg=28, rings=6)
    for z in (-.14, .14):
        pm.ell((0, .07, z), (.38, .012, .035), ROSE, 'straw', seg=20, rings=4)
    pm.ell((0, .075, 0), (.2, .012, .09), LAV2, 'straw', seg=20, rings=4)
    pm.ell((.3, .1, .06), (.05, .04, .05), '8B4E2F', 'bark', seg=10, rings=6)                         # the acorn charm
    pm.ell((.3, .13, .06), (.056, .02, .056), 'B5693F', 'bark', seg=10, rings=4)
    return spec(pm, 'bed', footprint=(1, 1), shadow=None)


def roof_patch() -> PropSpec:
    """The repair kit of the bakery roof quest: a ladder leaning on the wall, a bundle of shingles, a bucket and a hammer."""
    pm = PM()
    for z in (-.14, .14):                                                                          # ladder rails along x, leaning to -x
        pm.cyl((.1, 0, z), (-.2, 1.5, z), .035, .03, WOOD['dark'], 'bark', 8, n=4)
    for i in range(6):
        t = (i + .6) / 6.4
        pm.cyl((.1 - .3 * t, 1.5 * t, -.14), (.1 - .3 * t, 1.5 * t, .14), .022, .022, WOOD['honey'], 'plank', 6, n=2)
    for i in range(4):                                                                             # shingle bundle
        pm.box((.5, .06 + i * .055, .3), (.4, .05, .3), 'B5693F', 'roof', power=.25, rot=(0, 8 * i, 0))
    pm.box((.5, .13, .3), (.42, .03, .04), '8B4E2F', 'bark', power=.3)
    pm.cyl((.62, 0, -.3), (.58, .34, -.3), .15, .17, '7C7C8A', 'stone', 14, n=3)                    # bucket
    pm.ell((.6, .35, -.3), (.17, .03, .17), '4A3A4D', 'soft', seg=14, rings=4)
    pm.curve([(.44, .35, -.3), (.6, .62, -.3), (.76, .35, -.3)], .012, .012, '5B4A6E', 'soft', 6, n=8)
    pm.box((.1, .04, .62), (.34, .035, .06), WOOD['honey'], 'plank')                                # hammer
    pm.box((.26, .08, .62), (.1, .09, .06), '7C7C8A', 'stone', power=.3)
    return spec(pm, 'roof_patch', footprint=(1, 1), shadow=(.9, .4))


# ================================================================================================ crops (4 art stages; 0 seed, 1 sprout, 2 growing, 3 ripe)
SEED_COLOUR = {'strawberry': 'C8463C', 'sunflower': '3B2F2F', 'catnip': 'B9A9E8', 'glow_berry': '8FA9F2'}


def crop_new(kind='strawberry', stage=3) -> PropSpec:
    pm = PM()
    if stage <= 1:
        pm.ell((0, .02, 0), (.2, .05, .17), '6B4A33', 'soil', seg=16, rings=8)
    if stage == 0:
        for i in range(3):
            pm.ell((math.cos(i * 2.1) * .08, .06, math.sin(i * 2.1) * .07), (.022, .016, .03), SEED_COLOUR[kind], 'soft', seg=8, rings=6)
        return spec(pm, f'crop_{kind}_{stage}', shadow=(.4, .16))
    n_leaf = {1: 2, 2: 5, 3: 7}[stage]; sc = {1: .35, 2: .7, 3: 1.0}[stage]
    glow = None
    if kind == 'strawberry':
        for i in range(n_leaf):
            ar = math.radians(i * 360 / n_leaf + 15)
            pm.ell((math.cos(ar) * .15 * sc, .1 + .04 * sc, math.sin(ar) * .15 * sc), (.16 * sc + .03, .035, .12 * sc + .03), LEAFG[i % 3], 'leaf', seg=12, rings=6, rot=(10, -i * 51, 6))
        if stage == 2:
            for i in range(4):
                ar = math.radians(i * 90 + 30)
                pm.ell((math.cos(ar) * .2, .14, math.sin(ar) * .2), (.04, .02, .04), 'FFFFFF', 'soft', seg=8, rings=6)
                pm.ell((math.cos(ar) * .2, .15, math.sin(ar) * .2), (.015, .015, .015), 'F2C14E', 'soft', seg=6, rings=4)
        if stage == 3:
            for i in range(6):
                ar = math.radians(i * 60 + 10); rr = .22 + (i % 2) * .05
                p = (math.cos(ar) * rr, .12, math.sin(ar) * rr)
                pm.ell(p, (.06, .075, .06), 'D93A4A', 'soft', power=.85, seg=12, rings=8)
                pm.ell((p[0], p[1] + .07, p[2]), (.04, .015, .04), '6FAA46', 'leaf', seg=8, rings=4)
                for sd in range(3):
                    pm.ell((p[0] + (sd - 1) * .018, p[1], p[2] + .05), (.006, .008, .005), 'F2D9A0', 'soft', seg=6, rings=4)
    elif kind == 'sunflower':
        h = {1: .2, 2: .8, 3: 1.45}[stage]
        pm.curve([(0, .04, 0), (.03, h * .5, 0), (-.02, h * .85, 0), (0, h, 0)], .035 * (.6 + .4 * sc), .028 * (.6 + .4 * sc), '5C9A52', 'soft', 8, n=12)
        for i in range(n_leaf - 1 if stage > 1 else 2):
            ar = math.radians(i * 137)
            y = .1 + (h * .6) * (i / max(n_leaf - 1, 1))
            d = np.array([math.cos(ar), 0, math.sin(ar)])
            pm.curve([(0, y, 0), d * .14 * sc + [0, y + .04, 0], d * .3 * sc + [0, y - .02, 0]], .04 * sc, .01, LEAFG[i % 3], 'leaf', 8, n=8)
        if stage == 2:
            pm.ell((0, h + .06, 0), (.1, .08, .1), '6FAA46', 'leaf', seg=12, rings=8)
        if stage == 3:
            for k in range(14):                                                                     # petals around a dark disc, facing +z (screen lower-left)
                a = k * 2 * math.pi / 14
                pm.ell((math.cos(a) * .22, h + .02 + math.sin(a) * .22, .05), (.1, .035, .03), 'F2C14E' if k % 2 == 0 else 'F7D36A', 'crystal', rot=(0, 0, math.degrees(a)), seg=8, rings=5)
            pm.ell((0, h + .02, .05), (.17, .17, .06), '6B4A33', 'soil', seg=16, rings=10)
            pm.ell((0, h + .02, .09), (.11, .11, .03), '4A3322', 'soil', seg=14, rings=8)
    elif kind == 'catnip':
        gl = ('8FB39A', 'A9C7AE', '6F9A86')
        for i in range(n_leaf + 2):
            ar = math.radians(i * 360 / (n_leaf + 2) + 20)
            d = np.array([math.cos(ar), 0, math.sin(ar)])
            L = (.26 + (i % 3) * .05) * sc
            pm.curve([(0, .06, 0), d * L * .5 + [0, .12 + .16 * sc, 0], d * L + [0, .1 + .22 * sc, 0]], .035 * sc + .008, .006, gl[i % 3], 'leaf', 7, n=8)
        if stage == 3:
            for i in range(5):
                ar = math.radians(i * 72 + 8)
                x, z = math.cos(ar) * .1, math.sin(ar) * .1
                pm.curve([(x * .3, .12, z * .3), (x, .28, z), (x * 1.3, .5 + (i % 2) * .06, z * 1.3)], .012, .01, '6F9A86', 'soft', 5, n=8)
                for k in range(4):
                    pm.ell((x * 1.3, .42 + (i % 2) * .06 + k * .04, z * 1.3), (.04 - k * .004, .025, .04 - k * .004), 'B9A9E8' if k % 2 == 0 else '9B86D6', 'soft', seg=8, rings=6)
    elif kind == 'glow_berry':
        for i in range(n_leaf):
            ar = math.radians(i * 360 / n_leaf + 5)
            pm.ell((math.cos(ar) * .17 * sc, .1 + .05 * sc, math.sin(ar) * .17 * sc), (.17 * sc + .03, .03, .11 * sc + .03), ('4F8A6A', '6FAA8A', '3F7A5A')[i % 3], 'leaf', seg=12, rings=6, rot=(12, -i * 51, 8))
        if stage == 2:
            for i in range(3):
                ar = math.radians(i * 120)
                pm.ell((math.cos(ar) * .15, .2, math.sin(ar) * .15), (.04, .04, .04), '8FA9F2', 'soft', seg=8, rings=6)
        if stage == 3:
            glow = ('9FB4FF', 26, .5)
            for i in range(8):
                ar = math.radians(i * 45 + 12); rr = .12 + (i % 3) * .06
                p = (math.cos(ar) * rr, .22 + (i % 2) * .1, math.sin(ar) * rr)
                pm.curve([(0, .12, 0), (p[0] * .6, p[1] + .08, p[2] * .6), p], .012, .01, '3F7A5A', 'soft', 5, n=8)
                pm.ell(p, (.065, .065, .065), 'B9C8FF', 'glassglow', power=.9, seg=12, rings=8)
                pm.ell((p[0] - .02, p[1] + .02, p[2] + .03), (.02, .02, .02), 'FFFFFF', 'soft', seg=6, rings=4)
    return spec(pm, f'crop_{kind}_{stage}', shadow=(.4, .16), glow=glow)


# ================================================================================================ registry
def lantern_colour(color, tag):
    def f():
        s = pp.lantern_post(color)
        s.name = 'lantern_post_' + tag
        return s
    return f


TOWN_PROPS = {
    'house_town_hall': house_town_hall, 'house_bakery': house_bakery, 'house_seedshop': house_seedshop, 'house_smithy': house_smithy,
    'house_animalstore': house_animalstore, 'tower_wizard': tower_wizard, 'house_king_treetop': house_king_treetop,
    'well': well, 'fountain': fountain, 'market_stall': market_stall,
    'market_stall_furniture': lambda: market_stall((MINT, CREAM), 'furniture', 'market_stall_furniture'),
    'market_stall_tailor': lambda: market_stall((LAV2, 'F6E3A0'), 'tailor', 'market_stall_tailor'),
    'plank_stack': plank_stack, 'wheat_sack': wheat_sack, 'beehive_stand': beehive_stand,
    'stone_path_a': stone_path_a, 'stone_path_b': stone_path_b, 'stone_path_c': stone_path_c, 'bed': bed, 'roof_patch': roof_patch,
    'lantern_post_rose': lantern_colour('FFB8CC', 'rose'), 'lantern_post_lavender': lantern_colour('D2C0FF', 'lavender'), 'lantern_post_mint': lantern_colour('B8F0D4', 'mint'),
}
for _k in ('strawberry', 'sunflower', 'catnip', 'glow_berry'):
    for _s in range(4):
        TOWN_PROPS[f'crop_{_k}_{_s}'] = (lambda k=_k, s=_s: crop_new(k, s))
pp.PROPS.update(TOWN_PROPS)
