"""props_farm.py - the prop builders of the treetop farm contract (TOWNS addendum RT16 task 2; lifted from design3/farm/art/tools/characters/props_farm.py).

SAME vocabulary and renderer as props_traetoppen.py (PM: box / cyl / curve / ell / clump / pillow; metres, Y up, tile axes = world X and Z,
footprint centred on the origin = ground pivot; camera azimuth 45, so +X faces screen right-down and +Z screen left-down).

P22 bakes ONLY the seven contract props of the farm (coop_small, barn_small, animal_house, paw_prints, apple_tree, bench, signpost) plus
mailbox_red (the V amendment: farm.map uses it before the city art exists) and warp_gate_stone (the stone gate prop of the forest hubs).  The ten
farm-only props (trunks, pillars, shed, bin, stakes), the dress and the greenhouse belong to N03 / N06 / N07 and are NOT here.

Contract sizes (checked by tests/sections/art_environment.gd  farm_contract_props_sizes_and_footprints):
  coop_small 350x295 pivot (155,218) 3x2    barn_small 472x424 (208,313) 4x3    animal_house 319x270 (143,199) 3x2    paw_prints 39x49 (16,29) 1x1
  apple_tree 359x398 (172,355) 1x1          bench 174x144 (78,107) 2x1          signpost 84x130 (38,112) 1x1
"""
from __future__ import annotations
import math
import numpy as np
import props_traetoppen as pp
from props_traetoppen import PM, spec, T, WOOD, PropSpec

STONE = ('9A9AA6', 'B5B5C0', '7C7C8A')
RED_ROOF = 'A8553A'
PLASTER = 'F1E2BE'


def _gable_roof(pm: PM, w, d, h, slope, color, overhang=.30, thick=.12, along='x'):
    """Gable roof over a w x d box whose walls are h high; ridge along X."""
    half = d * .5 + overhang
    run = half * math.cos(math.radians(slope))
    rise = half * math.sin(math.radians(slope))
    for s in (-1, 1):
        pm.box((0, h + rise * .5 + .05, s * run * .5), (w + overhang * 1.6, thick, half), color, 'roof', power=.25,
               rot=(s * slope, 0, 0), pivot=(0, h + rise * .5 + .05, s * run * .5))
    pm.cyl((-(w + overhang * 1.6) / 2, h + rise + .05, 0), ((w + overhang * 1.6) / 2, h + rise + .05, 0), .09, .09, '8B4E2F', 'roof', 10)
    return rise


def _gable_ends(pm: PM, w, d, h, rise, color):
    import geometry as geo
    tri = geo.rounded_triangle([(-d / 2 - .02, h - .02), (d / 2 + .02, h - .02), (0, h + rise + .06)], 5)
    for sx in (-1, 1):
        pm.pillow(tri, sx * (w / 2 - .02), .05, color, 'plank', rot=(0, 90, 0))

def mailbox_red() -> PropSpec:
    pm = PM()
    pm.cyl((0, 0, 0), (0, 1.05, 0), .06, .05, WOOD['dark'], 'bark', 10, n=3)
    pm.box((0, 1.0, 0), (.62, .09, .4), WOOD['honey'], 'plank', power=.3)
    pm.ell((0, 1.22, 0), (.34, .24, .22), 'C8463C', 'soft', power=.62, seg=22, rings=12)                                # the red box
    pm.box((0, 1.12, .17), (.26, .13, .06), '2B2340', 'soft', power=.4)                                               # letter slot
    pm.box((.36, 1.36, 0), (.04, .22, .03), '8B4E2F', 'bark', power=.3)                                                # flag pole
    pm.box((.36, 1.50, .08), (.04, .12, .16), 'F2C14E', 'soft', power=.3)                                              # flag
    pm.ell((0, .06, 0), (.22, .05, .22), '6E9A4A', 'leaf', power=.9)
    return spec(pm, 'mailbox_red', footprint=(1, 1), shadow=(.5, .2))

def bench() -> PropSpec:
    pm = PM()
    L = T * 1.7
    for sx in (-.38, .38):
        pm.box((sx * L, .22, 0), (.1, .44, T * .55), WOOD['dark'], 'bark', power=.3)
    pm.box((0, .46, 0), (L, .07, T * .5), WOOD['honey'], 'plank', power=.3)
    pm.box((0, .78, -T * .22), (L, .3, .06), WOOD['pale'], 'plank', power=.3, rot=(-8, 0, 0))
    for sx in (-.38, .38):
        pm.box((sx * L, .62, -T * .2), (.08, .62, .08), WOOD['dark'], 'bark', power=.3)
    return spec(pm, 'bench', footprint=(2, 1), shadow=(.9, .3))

def coop_small() -> PropSpec:
    pm = PM()
    w, d, h = T * 2.5, T * 1.7, 1.15
    for sx in (-1, 1):
        for sz in (-1, 1):
            pm.cyl((sx * (w / 2 - .12), 0, sz * (d / 2 - .12)), (sx * (w / 2 - .12), .42, sz * (d / 2 - .12)), .07, .07, WOOD['dark'], 'bark', 8, n=2)
    pm.box((0, .42 + h / 2, 0), (w, h, d), 'E8CFA0', 'plank', power=.22)
    rise = _gable_roof(pm, w, d, .42 + h, 28, RED_ROOF, overhang=.28)
    _gable_ends(pm, w, d, .42 + h, rise, 'E8CFA0')
    pm.ell((-.2, .78, d / 2 + .02), (.2, .26, .05), '2B2340', 'soft', power=.8, seg=20, rings=12)                       # round pop-hole
    pm.box((-.2, .24, d / 2 + .42), (.34, .05, .85), WOOD['honey'], 'plank', power=.3, rot=(-18, 0, 0), pivot=(-.2, .42, d / 2 + .02))  # ramp
    pm.box((w / 2 + .12, .86, .05), (.3, .38, .5), WOOD['honey'], 'plank', power=.3)                                    # nest box on the side
    pm.box((w / 2 + .12, 1.08, .05), (.36, .06, .58), '7A4E2D', 'roof', power=.3)
    return spec(pm, 'coop_small', footprint=(3, 2), shadow=(1.9, .9), canvas_pad=14)

def barn_small() -> PropSpec:
    pm = PM()
    w, d, h = T * 3.5, T * 2.5, 2.2
    pm.box((0, .08, 0), (w + .2, .16, d + .2), '8A8494', 'stone', power=.3)
    pm.box((0, h / 2 + .1, 0), (w, h, d), 'B9553F', 'plank', power=.22)
    for sx in (-1, 1):
        for sz in (-1, 1):
            pm.box((sx * (w / 2 - .03), h / 2 + .1, sz * (d / 2 - .03)), (.15, h + .04, .15), 'F6EAD0', 'bark', power=.3)
    rise = _gable_roof(pm, w, d, h + .1, 32, '7A4E2D', overhang=.34)
    _gable_ends(pm, w, d, h + .1, rise, 'B9553F')
    # double doors on +z with white X braces + hay loft hatch
    pm.box((0, 1.05, d / 2 + .02), (1.5, 1.85, .08), '8B3F2E', 'plank', power=.3)
    for s in (-1, 1):
        pm.box((s * .37, 1.05, d / 2 + .07), (.06, 2.1, .05), 'F6EAD0', 'bark', power=.3, rot=(0, 0, s * 20))
    pm.box((0, 1.05, d / 2 + .07), (1.55, .07, .05), 'F6EAD0', 'bark', power=.3)
    pm.box((0, 2.0, d / 2 + .02), (.62, .5, .08), WOOD['dark'], 'bark', power=.3)
    pm.box((0, 2.0, d / 2 + .06), (.5, .38, .05), 'E3C372', 'straw', power=.3)
    return spec(pm, 'barn_small', footprint=(4, 3), shadow=(2.6, 1.3), canvas_pad=16)

def animal_house() -> PropSpec:
    pm = PM()
    w, d, h = T * 2.3, T * 1.6, 1.0
    pm.box((0, .1, 0), (w + .14, .2, d + .14), '8A8494', 'stone', power=.3)
    pm.box((0, h / 2 + .2, 0), (w, h, d), 'F1E2BE', 'plank', power=.22)
    rise = _gable_roof(pm, w, d, h + .2, 36, 'D9B66A', overhang=.32)
    _gable_ends(pm, w, d, h + .2, rise, 'F1E2BE')
    for s in (-1, 1):
        pm.ell((s * .5, .7, d / 2 + .03), (.17, .21, .05), '2B2340', 'soft', power=.8, seg=18, rings=10)             # two arched openings
        pm.ell((s * .5, .95, d / 2 + .07), (.22, .06, .06), WOOD['dark'], 'bark', seg=12, rings=6)
    pm.ell((0, 1.4, d / 2 + .02), (.14, .14, .04), 'FFE08F', 'glassglow', seg=14, rings=8)
    return spec(pm, 'animal_house', footprint=(3, 2), shadow=(1.7, .8), canvas_pad=14)

def paw_prints() -> PropSpec:
    pm = PM()
    for i, (x, z) in enumerate(((-.3, -.2), (-.12, .0), (.1, -.05), (.3, .12))):
        pm.ell((x, .02, z), (.07, .015, .06), '5B4A6E', 'soft', seg=10, rings=6)
        for k in range(3):
            pm.ell((x + (k - 1) * .045, .02, z - .08), (.025, .012, .03), '5B4A6E', 'soft', seg=8, rings=5)
    return spec(pm, 'paw_prints', footprint=(1, 1), shadow=None, outline=False)

def warp_gate_stone() -> PropSpec:
    """Skovport: two stone posts with a lintel, moss, a lantern, and the rope ladder that leads down."""
    pm = PM()
    w = T * 1.5
    for sx in (-1, 1):
        pm.box((sx * w / 2, 1.05, 0), (.42, 2.1, .42), STONE[0], 'stone', power=.34)
        pm.clump((sx * w / 2, 2.1, 0), .32, ('6E9A4A', '8CB866', '587F3A'), 'leaf', n=3, seed=7 + sx, squash=.6)
    pm.box((0, 2.25, 0), (w + .6, .3, .46), STONE[1], 'stone', power=.34)
    for sx in (-.3, .3):
        pm.curve([(sx, 2.1, .1), (sx + .02, 1.1, .3), (sx, 0.05, .55)], .028, .028, 'C9A66B', 'straw', 8, n=14)
    for i in range(6):
        y = 1.8 - i * .3
        pm.box((0, y, .2 + (1.8 - y) * .12), (.62, .05, .06), WOOD['honey'], 'plank', power=.3)
    pm.ell((0, 1.95, -.05), (.12, .16, .12), 'FFD98A', 'glassglow', power=.8)
    return spec(pm, 'warp_gate_stone', footprint=(2, 1), shadow=(.9, .35), glow=('FFD98A', 36, .5, (0, 1.95, -.05)))

def signpost() -> PropSpec:
    pm = PM()
    pm.cyl((0, 0, 0), (0, 1.5, 0), .06, .05, WOOD['dark'], 'bark', 8, n=3)
    pm.box((.18, 1.32, 0), (.7, .24, .05), WOOD['pale'], 'plank', power=.3, rot=(0, 0, 4))
    pm.box((-.16, 1.02, 0), (.62, .22, .05), WOOD['honey'], 'plank', power=.3, rot=(0, 0, -5))
    return spec(pm, 'signpost', footprint=(1, 1), shadow=(.4, .15))

def apple_tree(season='sommer') -> PropSpec:
    s = pp.tree_oak('farm', 4, 1.0)
    pm = PM()
    pm.m = s.m
    pm.g = s.m.lookup['Motion']
    rng = np.random.default_rng(9)
    if season in ('sommer', 'efteraar'):
        col = 'C8463C' if season == 'efteraar' else 'B6D45A'
        for i in range(14):
            a = rng.uniform(0, 6.28)
            e = rng.uniform(-.1, .75)
            r = rng.uniform(1.55, 1.95)
            pm.ell((math.cos(a) * math.cos(e) * r, 3.1 + math.sin(e) * 1.1, math.sin(a) * math.cos(e) * r), (.11, .11, .11), col, 'soft', seg=10, rings=8)
    elif season == 'foraar':
        for i in range(30):
            a = rng.uniform(0, 6.28)
            e = rng.uniform(-.1, .85)
            r = rng.uniform(.8, 1.4)
            pm.ell((math.cos(a) * math.cos(e) * r, 3.0 + math.sin(e) * 1.1, math.sin(a) * math.cos(e) * r), (.1, .07, .1), 'F6C6D6', 'soft', seg=10, rings=6)
    s.name = 'apple_tree' if season == 'sommer' else 'apple_tree_' + season
    return s

FARM_PROPS = {
    'mailbox_red': mailbox_red, 'bench': bench, 'coop_small': coop_small, 'barn_small': barn_small, 'animal_house': animal_house,
    'paw_prints': paw_prints, 'warp_gate_stone': warp_gate_stone, 'signpost': signpost, 'apple_tree': lambda: apple_tree('sommer'),
}
pp.PROPS.update(FARM_PROPS)
