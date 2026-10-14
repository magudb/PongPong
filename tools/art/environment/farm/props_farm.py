"""props_farm.py (tools/art/environment/farm) - the prop builders of the treetop farm KIT (package N03-farm-art; lifted from design3/farm/art/tools/characters/props_farm.py).

SAME vocabulary and renderer as props_traetoppen.py (PM: box / cyl / curve / ell / clump / pillow; metres, Y up, tile axes = world X and Z, footprint centred on the
origin = ground pivot; camera azimuth 45, so +X faces screen right-down and +Z screen left-down).

N03 bakes ONLY the ten farm-only props (TOWNS addendum 3.7, design_farm 10.2) - FARM_KIT below:

  trunk_giant_a  the standing trunk behind the house, on void cells         footprint 5x3  1227x2405 pivot (622, 2092)
  trunk_giant_b  the orchard trunk with the tree hollow (trae_hulning)       footprint 3x3  1274x2142 pivot (685, 1903)   SOLID
  trunk_under_a  pillar under the deck, the pivot is the deck plane          footprint 1x1   907x1352 pivot (454, 139)
  trunk_under_b  the second pillar                                          footprint 1x1   746x1306 pivot (371, 117)
  tool_shed      the shed (E opens the home chest)                          footprint 2x2   316x313  pivot (140, 246)
  shipping_bin   the bin with its lid open                                  footprint 2x1   226x182  pivot (100, 138)
  stake_sign     the field-expansion sign                                   footprint 1x1    84x124  pivot (38, 105)
  rope_stake_x / rope_stake_z   the rope between two stakes (the ring)      footprint 1x1    87x97   pivot (41, 72)
  build_stake    the empty building slot                                    footprint 1x1    76x118  pivot (35, 100)

The sizes / pivots are the MEASURED prototype (design3/farm/art/out/art_budget.txt) and the contract of tests/sections/art_farm.gd; FARM_CONTRACT below is that table.

NOT here: the seven props P22 bakes (coop_small, barn_small, animal_house, paw_prints, apple_tree, bench, signpost) and mailbox_red (the V amendment of P22): their builders are
kept as P22_REFERENCE (never registered, never baked by this package) so that check_reference() can prove the farm contract (footprints) is the one P22's builders produce.
The dress (N06), dock_x and warp_gate_stone (P22's forest-hub prop) are not shipped here either.

This file is loaded BY PATH by bake_farm_kit.py (the folder name `farm` shadows P22's props_farm.py if it ever lands on sys.path first; the driver removes its own folder from sys.path).
"""
from __future__ import annotations
import math
import numpy as np
import props_traetoppen as pp
from props_traetoppen import PM, spec, T, WOOD, _yaw, PropSpec

STONE = ('9A9AA6', 'B5B5C0', '7C7C8A')
RED_ROOF = 'A8553A'

# id -> (width, height, pivot x, pivot y, footprint x, footprint z)  - design3/farm/art/out/art_budget.txt (the measured prototype) + TOWNS addendum 3.7
FARM_CONTRACT = {
    'trunk_giant_a': (1227, 2405, 622, 2092, 5, 3),
    'trunk_giant_b': (1274, 2142, 685, 1903, 3, 3),
    'trunk_under_a': (907, 1352, 454, 139, 1, 1),
    'trunk_under_b': (746, 1306, 371, 117, 1, 1),
    'tool_shed': (316, 313, 140, 246, 2, 2),
    'shipping_bin': (226, 182, 100, 138, 2, 1),
    'stake_sign': (84, 124, 38, 105, 1, 1),
    'rope_stake_x': (87, 97, 41, 72, 1, 1),
    'rope_stake_z': (87, 97, 41, 72, 1, 1),
    'build_stake': (76, 118, 35, 100, 1, 1),
}


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


# ------------------------------------------------------------------------------------------------ the great trunks
def trunk_giant(seed=11, base_r=3.3, top_r=2.5, height=30.0, footprint=(5, 3), hollow=False) -> PropSpec:
    """A standing giant trunk with root buttresses and leaf masses near its top; origin = footprint centre on the deck plane."""
    P = dict(leaf=('86A646', 'BCCB5C', '5C8A3C'), dark=('4A7A3C', '5E8F44', '386A34'), bark='8A5A3A', bark2='6A4428')
    pm = PM()
    rng = np.random.default_rng(seed)
    pm.curve([(0, -.4, 0), (.3, height * .33, .12), (-.25, height * .66, -.08), (0, height, 0)], base_r, top_r, P['bark'], 'bark', 22, n=48)
    # root buttresses that reach the deck: fan towards +x / +z (the visible side) and the back
    for a in range(0, 360, 36):
        ar = math.radians(a + rng.uniform(-9, 9))
        d = np.array([math.cos(ar), 0, math.sin(ar)])
        reach = base_r * rng.uniform(1.55, 2.1)
        pm.curve([d * base_r * .55 + [0, 4.4, 0], d * base_r * 1.0 + [0, 1.8, 0], d * reach * .85 + [0, .35, 0], d * reach + [0, .0, 0]],
                 base_r * .28, base_r * .09, P['bark2'] if a % 72 else P['bark'], 'bark', 10, n=18)
    # limbs with leaf masses at 11 .. 22 m and a crown ring at the top
    for i, (hh, a, r) in enumerate([(height * .36, 40, 4.0), (height * .47, 150, 4.6), (height * .57, 250, 4.2), (height * .68, 330, 3.8), (height * .78, 90, 4.4)]):
        ar = math.radians(a)
        d = np.array([math.cos(ar), 0, math.sin(ar)])
        pm.curve([(0, hh, 0), d * r * .45 + [0, hh + 1.1, 0], d * r * .8 + [0, hh + 1.6, 0]], .75, .26, P['bark'], 'bark', 9, n=12)
        pm.clump(tuple(d * r + [0, hh + 2.1, 0]), rng.uniform(1.8, 2.4), P['leaf'] if i % 2 else P['dark'], 'leaf', n=5, seed=seed * 7 + i, seg=18, rings=10)
    for i in range(16):
        a = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(2.0, 6.2)
        pm.clump((math.cos(a) * rr, height - .5 + rng.uniform(-1.4, 3.0), math.sin(a) * rr), rng.uniform(1.6, 2.6), P['leaf'] if i % 3 else P['dark'], 'leaf', n=5,
                 seed=seed * 13 + i, seg=18, rings=10)
    if hollow:   # the tree hollow (trae_hulning): a dark opening on the face that looks at the camera, a mossy lip under it
        # (the prototype put the hole INSIDE the trunk at 1.7 m, between the root buttresses: it never showed; this one sits above the buttresses, flat against the front face)
        ang = 52.0
        n = np.array([math.cos(math.radians(ang)), 0, math.sin(math.radians(ang))])
        surface = base_r * .955                                                    # the trunk radius at 3.5 m
        pm.ell(n * (surface - .02) + [0, 3.5, 0], (.18, 1.08, .78), '4A2E1C', 'bark', power=.9, rot=(0, -ang, 0), seg=26, rings=16)     # the dark bark rim of the opening
        pm.ell(n * (surface + .03) + [0, 3.55, 0], (.14, .92, .60), '2B2340', 'soft', power=.8, rot=(0, -ang, 0), seg=26, rings=16)    # the opening itself (flat, a little proud of the bark)
        t = np.array([-math.sin(math.radians(ang)), 0, math.cos(math.radians(ang))])                                          # tangent: the moss sits on the lower left of the rim
        pm.ell(n * (surface + .02) + t * -.42 + [0, 2.75, 0], (.2, .08, .32), '6E9A4A', 'leaf', power=.9, rot=(0, -ang, 0), seg=14, rings=8)
        pm.ell(n * (surface + .02) + t * -.12 + [0, 2.66, 0], (.16, .06, .22), '8CB866', 'leaf', power=.9, rot=(0, -ang, 0), seg=12, rings=8)
    return spec(pm, f'trunk_giant_{seed}', footprint=footprint, shadow=None, canvas_pad=24)


def trunk_giant_a() -> PropSpec:
    s = trunk_giant(11, 3.0, 2.4, 22.0, (5, 3), False)
    s.name = 'trunk_giant_a'
    return s


def trunk_giant_b() -> PropSpec:
    s = trunk_giant(23, 2.5, 2.0, 19.0, (3, 3), True)
    s.name = 'trunk_giant_b'
    return s


def trunk_under(seed=7, r0=2.7, r1=3.2) -> PropSpec:
    """The pillar BELOW a platform: origin = the deck plane (its flat top is hidden by the deck, z -11), the trunk and hanging roots go down."""
    P = dict(bark='8A5A3A', bark2='6A4428')
    pm = PM()
    rng = np.random.default_rng(seed)
    pm.curve([(0, .2, 0), (.4, -4, .15), (-.3, -9, -.15), (0, -15, 0)], r0, r1, P['bark'], 'bark', 22, n=40)
    for a in range(0, 360, 45):
        ar = math.radians(a + rng.uniform(-10, 10))
        d = np.array([math.cos(ar), 0, math.sin(ar)])
        pm.curve([d * r0 * .6 + [0, -1.0, 0], d * r0 * 1.35 + [0, -4.5, 0], d * r0 * 1.7 + [0, -6.5, 0], d * r0 * 1.85 + [0, -11, 0]], .6, .2, P['bark2'], 'bark', 9, n=16)
    # a few moss tufts where the trunk leaves the deck
    for i in range(5):
        a = rng.uniform(0, 6.28)
        pm.clump((math.cos(a) * r0 * .95, -.5 - rng.uniform(0, 1.2), math.sin(a) * r0 * .95), .38, ('6E9A4A', '8CB866', '587F3A'), 'leaf', n=3, seed=i + 5, squash=.7)
    return spec(pm, f'trunk_under_{seed}', footprint=(1, 1), shadow=None, canvas_pad=16)


# ------------------------------------------------------------------------------------------------ the yard
def tool_shed() -> PropSpec:
    pm = PM()
    w, d, h = T * 1.9, T * 1.7, 1.75
    pm.box((0, .1, 0), (w + .18, .2, d + .18), '8A8494', 'stone', power=.3)
    pm.box((0, h / 2 + .1, 0), (w, h, d), 'C9A66B', 'plank', power=.22)
    for sx in (-1, 1):
        for sz in (-1, 1):
            pm.box((sx * (w / 2 - .02), h / 2 + .1, sz * (d / 2 - .02)), (.13, h + .04, .13), WOOD['dark'], 'bark', power=.3)
    # mono-pitch roof sloping to +z (the door side drips towards the yard)
    slope = 16
    pm.box((0, h + .28, 0), (w + .5, .12, d + .5), '7A4E2D', 'roof', power=.25, rot=(slope, 0, 0), pivot=(0, h + .28, 0))
    pm.box((0, h + .20, 0), (w + .42, .08, d + .42), WOOD['dark'], 'bark', power=.3, rot=(slope, 0, 0), pivot=(0, h + .2, 0))
    # door + window on +z, tools leaning on +x
    pm.box((-.28, .85, d / 2 + .02), (.62, 1.32, .08), '6B4126', 'plank', power=.3)
    pm.ell((-.08, .85, d / 2 + .08), (.05, .05, .03), 'E9C06B', 'crystal', seg=10, rings=6)
    pm.box((.5, 1.08, d / 2 + .03), (.5, .5, .06), WOOD['dark'], 'bark', power=.25)
    pm.box((.5, 1.08, d / 2 + .06), (.42, .42, .05), 'FFE08F', 'glassglow', power=.26)
    for i, (z, tilt) in enumerate(((-.3, 12), (.05, 8), (.4, 14))):
        pm.cyl((w / 2 + .10, .15, z), (w / 2 + .03 + .0, 1.55, z + .0), .03, .025, WOOD['pale'], 'bark', 8, n=3)
        pm.box((w / 2 + .1, .13 + i * .02, z), (.05, .05, .32), '7C7C8A', 'stone', power=.3)
    pm.cyl((w / 2 + .38, .0, -.55), (w / 2 + .38, .62, -.55), .24, .22, WOOD['honey'], 'plank', 16, n=3)          # barrel
    pm.cyl((w / 2 + .38, .60, -.55), (w / 2 + .38, .64, -.55), .22, .22, WOOD['dark'], 'bark', 16, n=2)
    return spec(pm, 'tool_shed', footprint=(2, 2), shadow=(1.7, .9), canvas_pad=14)


def shipping_bin() -> PropSpec:
    """The shipping bin, lid OPEN: a crate with iron straps, a rim round a dark hollow with a few vegetables in it, the lid hinged up at the back, the coin emblem on the front."""
    pm = PM()
    L, Wd, H = T * 1.9, T * .82, .82
    pm.box((0, H / 2, 0), (L, H, Wd), WOOD['honey'], 'plank', power=.28)
    for x in (-L * .38, 0, L * .38):
        pm.box((x, H / 2, 0), (.07, H + .02, Wd + .03), '5B4A6E', 'stone', power=.3)                                   # iron straps
    # the opening: a dark hollow that sits ABOVE the rounded top face (the prototype's lay inside it and was hidden: the bin read as closed), framed by a four-plank rim
    pm.box((0, H + .005, 0), (L - .20, .06, Wd - .17), '2B2340', 'soft', power=.3)
    for sz in (-1, 1):
        pm.box((0, H + .035, sz * (Wd / 2 - .045)), (L - .02, .07, .09), WOOD['pale'], 'plank', power=.3)
    for sx in (-1, 1):
        pm.box((sx * (L / 2 - .045), H + .035, 0), (.09, .07, Wd - .02), WOOD['pale'], 'plank', power=.3)
    for (x, z, r, c) in ((-.22, .02, .10, 'EE8A2E'), (.02, -.03, .09, '8FBF4E'), (.24, .03, .10, 'D95F4A')):                # what has been put in
        pm.ell((x, H + .06, z), (r, r * .85, r), c, 'soft', power=.9, seg=14, rings=9)
    # open lid hinged at the back (-z)
    pm.box((0, H + .26, -Wd / 2 - .02), (L, .08, Wd * .62), WOOD['pale'], 'plank', power=.28, rot=(-62, 0, 0), pivot=(0, H, -Wd / 2))
    pm.ell((0, .46, Wd / 2 + .04), (.2, .2, .03), 'E9C06B', 'crystal', power=.6, seg=18, rings=10)                      # coin emblem
    pm.ell((0, .46, Wd / 2 + .075), (.12, .12, .02), 'FFE49A', 'crystal', power=.6, seg=14, rings=8)
    return spec(pm, 'shipping_bin', footprint=(2, 1), shadow=(1.2, .5))


def stake_sign() -> PropSpec:
    pm = PM()
    pm.cyl((0, 0, 0), (0, 1.25, 0), .05, .04, WOOD['dark'], 'bark', 8, n=3)
    pm.box((0, 1.1, 0), (.62, .42, .05), WOOD['pale'], 'plank', power=.3)
    pm.ell((0, 1.1, .04), (.14, .14, .02), 'E9C06B', 'crystal', power=.6, seg=16, rings=8)                             # coin
    pm.curve([(.0, 1.25, .04), (.2, 1.05, .06), (.34, .8, .04), (.3, .55, .02)], .035, .02, 'F2C14E', 'straw', 6, n=10)  # ribbon
    return spec(pm, 'stake_sign', footprint=(1, 1), shadow=(.4, .16))


def rope_stake(axis='x') -> PropSpec:
    pm = PM()
    L = T
    for sx in (-.5, .5):
        pm.cyl((sx * L, 0, 0), (sx * L, .62, 0), .05, .04, WOOD['dark'], 'bark', 8, n=3)
        pm.ell((sx * L, .64, 0), (.06, .04, .06), WOOD['pale'], 'plank', seg=10, rings=6)
    pm.curve([(-L / 2, .56, 0), (-L / 6, .44, 0), (L / 6, .44, 0), (L / 2, .56, 0)], .022, .022, 'C9A66B', 'straw', 8, n=12)
    sp = spec(pm, f'rope_stake_{axis}', footprint=(1, 1), shadow=(.4, .12))
    if axis == 'z':
        _yaw(pm.m, 90)
    return sp


def build_stake() -> PropSpec:
    pm = PM()
    pm.cyl((0, 0, 0), (0, 1.35, 0), .045, .035, WOOD['dark'], 'bark', 8, n=3)
    pm.box((.2, 1.18, 0), (.4, .26, .03), 'F2A34A', 'straw', power=.3)                                                   # orange pennant
    pm.curve([(0, 1.3, 0), (.2, 1.3, .0), (.42, 1.24, 0)], .02, .01, '8B4E2F', 'bark', 6, n=6)
    return spec(pm, 'build_stake', footprint=(1, 1), shadow=(.35, .14))


# the ten farm-only props this package bakes: id -> builder
FARM_KIT = {
    'trunk_giant_a': trunk_giant_a,
    'trunk_giant_b': trunk_giant_b,
    'trunk_under_a': lambda: trunk_under(7, 2.7, 3.2),
    'trunk_under_b': lambda: trunk_under(19, 2.2, 2.7),
    'tool_shed': tool_shed,
    'shipping_bin': shipping_bin,
    'stake_sign': stake_sign,
    'rope_stake_x': lambda: rope_stake('x'),
    'rope_stake_z': lambda: rope_stake('z'),
    'build_stake': build_stake,
}
assert set(FARM_KIT) == set(FARM_CONTRACT), 'FARM_KIT and FARM_CONTRACT must list the same ten ids'


# ================================================================================================ reference builders of the props P22 bakes (NOT baked here)
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


# id -> builder of the props P22 bakes; NEVER registered into props_traetoppen.PROPS and never baked by this package
P22_REFERENCE = {
    'mailbox_red': mailbox_red, 'bench': bench, 'coop_small': coop_small, 'barn_small': barn_small, 'animal_house': animal_house,
    'paw_prints': paw_prints, 'signpost': signpost, 'apple_tree': lambda: apple_tree('sommer'),
}

# the footprints the farm contract demands of the P22 props (TOWNS addendum RT16): the part of the order that this package only ASSERTS
P22_FOOTPRINTS = {'coop_small': (3, 2), 'barn_small': (4, 3), 'animal_house': (3, 2), 'bench': (2, 1), 'paw_prints': (1, 1), 'signpost': (1, 1), 'apple_tree': (1, 1),
                  'mailbox_red': (1, 1)}


def check_reference() -> list:
    """Problems of the reference builders (a list of text lines, empty = fine): every P22 contract prop is buildable here and has the contract footprint."""
    out = []
    for pid, fp in P22_FOOTPRINTS.items():
        s = P22_REFERENCE[pid]()
        if tuple(s.footprint) != fp:
            out.append('%s: reference builder footprint %s, contract %s' % (pid, tuple(s.footprint), fp))
    return out
