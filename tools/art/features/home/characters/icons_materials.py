"""Building / crafting material icon BUILDERS (planks, stone blocks, glass, roof tiles, crystals, gold leaf, nails, rope, fabric rolls, paint pots ...).

ICONS = the 47 builders of the art spike, keyed by their spike names (plank_fyr, soem, sten_blokke ...); NEW = the five builders A1 added (four blueprint
rolls with a wax seal, the milk paint pot).  specs/material_icon_map.json maps them to the 32 content ids; bake_material_icons.py renders them with the
contract icon renderer (icons_contract.render_shapes).  The spike registered the builders into icons_traetoppen.ICONS (P23's icon module) as well: that
coupling is gone, A1 does not depend on P23."""
from __future__ import annotations
import math
import numpy as np
from home_kit import HM
import furniture_traetoppen as ft

ICONS = {}
NEW = {}


def reg(name):
    def d(fn): ICONS[name] = fn; return fn
    return d


def _planks(col, dark):
    def f():
        pm = HM()
        for k in range(4):
            pm.box((0, .07 + k * .15, (k % 2) * .03), (1.2, .13, .34), col if k % 2 else dark, 'wood', .3, rot=(0, 8 * (k % 3) - 6, 0))
        for k in range(4): pm.ell((.605, .07 + k * .15, (k % 2) * .03), (.012, .055, .14), _end(col), 'soft', 1.0, None, 8, 6)
        pm.box((0, .66, 0), (.1, .03, .5), 'D9C79B', 'weave', .3)
        return pm
    return f


def _end(c): return ft._mix(c, 'FFFFFF', .25)


for _k, (_w, _d) in {'plank_fyr': ('D6B27A', 'B58A52'), 'plank_eg': ('B88A52', '8C6B3F'), 'plank_birk': ('EBDDBF', 'C9B58E'), 'plank_valnoed': ('7A4E2D', '5A3B26'),
                      'plank_kirsebaer': ('A5523A', '7E3A28'), 'plank_ibenholt': ('3E3446', '2B2340'), 'plank_maane': ('C9D4EE', '9BA9D2')}.items():
    ICONS[_k] = _planks(_w, _d)


@reg('levende_ved')
def _living():
    pm = HM(); pm.tube2(np.array([(-.5, 0, 0), (-.1, .22, 0), (.3, .12, 0), (.55, .3, 0)]), [.1, .09, .08, .06], '8A6A42', 'bark2', 10)
    for k in range(4): pm.ell((.1 + k * .12, .42 + .06 * (k % 2), 0), (.13, .04, .09), ('6FAA46', '97C95E', '4F8A38')[k % 3], 'leaf', .9, (0, 0, 20 - 12 * k), 10, 8)
    return pm


@reg('sten_blokke')
def _stone():
    pm = HM()
    for k, (x, y, z) in enumerate([(-.3, .15, 0), (.3, .15, .02), (0, .45, 0)]): pm.box((x, y, z), (.58, .3, .42), ('B7B1BE', 'A7A0B0', 'C9C3CF')[k], 'blocks', .25, rot=(0, 6 * k, 0))
    return pm


@reg('mursten')
def _brick():
    pm = HM()
    for k, (x, y, z) in enumerate([(-.3, .1, 0), (.3, .1, .02), (-.1, .3, 0), (.5, .3, 0.02)]): pm.box((x, y, z), (.52, .19, .26), ('B5694A', 'A85A3A')[k % 2], 'brick', .25, rot=(0, 5 * k, 0))
    return pm


@reg('glas')
def _glass():
    pm = HM()
    for k in range(2): pm.box((-.15 + k * .25, .55, -.1 + k * .12), (.6, .9, .05), 'A9D3E0', 'glass', .25, rot=(0, 20, -8 + k * 6))
    pm.box((.1, .55, .1), (.66, .96, .04), 'D8EEF3', 'glass', .25, rot=(0, 20, 4))
    return pm


@reg('tagsten')
def _rooftile():
    pm = HM()
    for k in range(3): pm.ell((0, .12 + k * .1, k * .02), (.5, .07, .26), ('B8502F', 'A04426', 'C25E3A')[k], 'rooftile', .6, (0, 0, 0), 14, 8)
    for k in range(3): pm.ell((0, .12 + k * .1 + .04, k * .02), (.4, .035, .22), ('C25E3A', 'B8502F', 'D06A44')[k], 'rooftile', .6, (0, 0, 0), 14, 8)
    return pm


@reg('straa_bundt')
def _thatch():
    pm = HM(); pm.cyl2((-.55, .3, 0), (.55, .3, 0), .24, .24, 'D3AE5C', 'thatch', 14, 4)
    for x in (-.3, .3): pm.ell((x, .3, 0), (.04, .26, .26), 'D9C79B', 'weave', 1.0, None, 8, 8)
    pm.ell((.56, .3, 0), (.02, .24, .24), 'C49A3E', 'thatch', 1.0, None, 14, 8); pm.ell((-.56, .3, 0), (.02, .24, .24), 'C49A3E', 'thatch', 1.0, None, 14, 8)
    return pm


@reg('bjaelke')
def _beam():
    pm = HM(); pm.box((0, .2, 0), (1.3, .26, .26), '8C6B3F', 'wood', .3)
    pm.box((.25, .34, 0), (.1, .06, .27), '7A4E2D', 'wood', .3); pm.box((-.4, .2, 0), (.06, .27, .27), '6B4126', 'wood', .3)
    return pm


@reg('marmor_blok')
def _marble():
    pm = HM(); pm.box((0, .25, 0), (.8, .5, .55), 'F7F0E2', 'marble', .22, rot=(0, 18, 0)); pm.box((.18, .56, 0), (.4, .12, .3), 'E8DFCB', 'marble', .3, rot=(0, 18, 0))
    return pm


@reg('skifer')
def _slate():
    pm = HM()
    for k in range(4): pm.box((-.2 + k * .14, .3 + .02 * k, 0), (.5, .64, .05), ('6E7A98', '5F6C8E', '7C88A8', '67738F')[k], 'slate', .3, rot=(0, 0, -10 + 6 * k))
    return pm


@reg('kobber_plade')
def _copper():
    pm = HM(); pm.box((0, .1, 0), (.9, .06, .6), '6FB5A0', 'copper', .3, rot=(0, 14, 0)); pm.box((.1, .2, .05), (.8, .05, .55), 'D98A5A', 'copper', .3, rot=(0, 6, 0))
    return pm


for _c, (_a, _b) in ft.CRYSTALS.items():
    def _mk(a=_a, b=_b):
        def f():
            pm = HM()
            for k, (x, z, h, t) in enumerate([(0, 0, 1.0, 0), (.22, .05, .7, 14), (-.24, .02, .75, -16)]):
                from scipy.spatial.transform import Rotation
                R = Rotation.from_euler('xyz', [0, 0, t], degrees=True).as_matrix()
                pts = np.array([[0, 0, 0], [0, h * .78, 0], [0, h, 0]]) @ R.T + [x, 0, z]
                pm.tube(pts, [.15, .14, .008], a if k % 2 == 0 else b, 'crystalf@1.0', 6)
            return pm
        return f
    ICONS['crystal_' + _c] = _mk()


@reg('bladguld')
def _leaf():
    pm = HM()
    for k in range(4): pm.box((0, .03 + .035 * k, 0), (.55, .015, .55), 'E3C372' if k % 2 else 'F2D58A', 'gold', .4, rot=(0, 12 * k, 0))
    pm.box((0, .0, 0), (.6, .03, .6), 'F4E6C4', 'weave', .3); pm.emit_ell((.22, .22, .1), (.04, .04, .04), 'FFF4B8', 1.0, None, 8, 6)
    return pm


@reg('soem')
def _nails():
    pm = HM(); rng = np.random.default_rng(3)
    for k in range(10):
        x, z = rng.uniform(-.3, .3), rng.uniform(-.2, .2); a = rng.uniform(0, 180)
        pm.cyl2((x, .05, z), (x + .25 * math.cos(math.radians(a)), .06, z + .25 * math.sin(math.radians(a))), .02, .014, '6E6A7E', 'soft', 6, 2)
        pm.ell((x, .06, z), (.045, .02, .045), '8E93A6', 'soft', 1.0, None, 8, 6)
    return pm


@reg('reb')
def _rope():
    pm = HM()
    for k in range(3): pm.tube2(np.array([(math.cos(a) * (.4 - .04 * k), .08 + .09 * k, math.sin(a) * (.4 - .04 * k)) for a in np.linspace(0, 6.28, 14)]), [.06] * 14, 'D9C79B', 'weave', 8)
    return pm


@reg('traad')
def _thread():
    pm = HM(); pm.cyl2((0, 0, 0), (0, .08, 0), .24, .24, '8C6B3F', 'wood', 14, 2); pm.cyl2((0, .08, 0), (0, .5, 0), .17, .17, '9B86D6', 'weave', 14, 3); pm.cyl2((0, .5, 0), (0, .58, 0), .24, .24, '8C6B3F', 'wood', 14, 2)
    return pm


@reg('messing_barre')
def _brass():
    pm = HM(); pm.box((0, .12, 0), (.9, .22, .36), 'D9A441', 'gold', .25, rot=(0, 18, 0)); pm.box((0, .27, 0), (.6, .1, .22), 'F2D58A', 'gold', .3, rot=(0, 18, 0))
    return pm


@reg('fernis')
def _varnish():
    pm = HM(); pm.lathe(0, 0, [(0, .22), (.1, .26), (.55, .26), (.7, .12), (.8, .08), (1, .09)], 'D98A3A', 'glass', 14, scale=.9); pm.cyl2((0, .9, 0), (0, 1.0, 0), .11, .1, '8C6B3F', 'wood', 10, 2)
    pm.box((0, .35, .26), (.3, .24, .02), 'F4E6C4', 'weave', .3)
    return pm


@reg('kalk')
def _lime():
    pm = HM(); pm.ell((0, .3, 0), (.34, .38, .26), 'F1E8D2', 'weave', .85, None, 14, 10); pm.box((0, .6, 0), (.4, .07, .3), 'E8DFCB', 'weave', .5); pm.box((0, .35, .26), (.22, .16, .02), '6F8FBF', 'soft', .3)
    return pm


for _f, (_c, _t, _) in ft.FABRICS.items():
    def _mkf(c=_c, t=_t):
        def f():
            pm = HM(); pm.cyl2((-.45, .3, 0), (.45, .3, 0), .3, .3, c, t, 16, 4)
            for x in (-.45, .45): pm.ell((x, .3, 0), (.03, .22, .22), ft._mix(c, 'FFFFFF', .3), 'weave', 1.0, None, 12, 8)
            pm.box((.2, .03, .42), (.5, .03, .3), c, t, .4, rot=(0, 10, 0))
            return pm
        return f
    ICONS['stof_' + _f] = _mkf()

for _p, (_c, _n) in ft.PAINTS.items():
    def _mkp(c=_c):
        def f():
            pm = HM(); pm.cyl2((0, 0, 0), (0, .5, 0), .3, .3, '8E93A6', 'soft', 16, 3); pm.ell((0, .5, 0), (.28, .04, .28), c, 'painted', 1.0, None, 16, 6)
            pm.ell((.24, .38, .0), (.03, .16, .05), c, 'painted', 1.0, None, 8, 8); pm.ell((0, .5, .0), (.31, .03, .31), '6E6A7E', 'soft', 1.0, None, 16, 6)
            pm.curve([(-.3, .5, 0), (-.3, .8, 0), (.3, .8, 0), (.3, .5, 0)], .02, .02, '6E6A7E', 'soft', 6, 12)
            return pm
        return f
    ICONS['maling_' + _p] = _mkp()


# ----------------------------------------------------------------------------------------------------------------------------------
# NEW builders of A1 (not in the spike): the four blueprints of lua/items/building_materials.lua and the milk paint pot
# ----------------------------------------------------------------------------------------------------------------------------------
def _new(name):
    def d(fn): NEW[name] = fn; return fn
    return d


def _blueprint(seal, seal_dark, ribbon):
    """a rolled plan: parchment cylinder with visible spiral ends, a ribbon band and a wax seal in the colour of the blueprint"""
    def f():
        pm = HM()
        pm.cyl2((-.5, .26, 0), (.5, .26, 0), .2, .2, 'F4E6C4', 'weave', 18, 4)                                   # the rolled sheet
        for x in (-.5, .5):
            pm.ell((x, .26, 0), (.03, .21, .21), 'E8D9B0', 'weave', 1.0, None, 14, 10)                           # end caps
            pm.ell((x + (.02 if x > 0 else -.02), .26, 0), (.015, .13, .13), 'D8C69A', 'soft', 1.0, None, 12, 8)   # inner spiral turn
            pm.ell((x + (.03 if x > 0 else -.03), .26, 0), (.012, .06, .06), 'B8A472', 'soft', 1.0, None, 10, 8)
        pm.box((0, .26, 0), (.07, .43, .43), ribbon, 'weave', .4)                                                 # ribbon band around the middle
        pm.ell((.0, .06, .0), (.5, .03, .22), 'F1E4C0', 'weave', .5, None, 16, 6)                                 # a loose corner of the sheet under the roll
        pm.ell((.1, .38, .21), (.13, .13, .045), seal, 'gold' if seal == 'E3C372' else 'soft', 1.0, None, 16, 10)  # wax seal on the ribbon
        pm.ell((.1, .38, .245), (.085, .085, .02), seal_dark, 'soft', 1.0, None, 14, 8)
        pm.ell((.1, .38, .262), (.03, .03, .01), seal, 'soft', 1.0, None, 8, 6)
        for k in range(3):                                                                                           # wax drips
            pm.ell((.04 + k * .06, .27 - .02 * k, .215), (.02, .045 + .01 * k, .02), seal, 'soft', 1.0, None, 8, 6)
        return pm
    return f


for _n, (_seal, _dark, _rib) in {'blueprint_kongelig': ('6A4C8C', '4B3466', 'E3C372'),        # royal: plum wax, gold ribbon
                                 'blueprint_solstuen': ('E8B04A', 'B9822B', 'E58FA6'),         # sun room: honey wax, rose ribbon
                                 'blueprint_troldmanden': ('3F5FA0', '28407A', 'B6A6E6'),      # wizard: night-blue wax, lavender ribbon
                                 'blueprint_mestermurer': ('B5694A', '8A4A30', '6E7A98')}.items():   # master mason: brick wax, slate ribbon
    NEW[_n] = _blueprint(_seal, _dark, _rib)


@_new('milk_paint')
def _milk_paint():
    """a squat enamel pot of creamy milk paint with a pale mint drip, a wire handle and a stirring stick across the rim"""
    pm = HM()
    pm.cyl2((0, 0, 0), (0, .46, 0), .3, .31, 'C9D8D2', 'soft', 18, 3)                                              # pot body (pale blue-grey enamel)
    pm.ell((0, .02, 0), (.31, .035, .31), 'A8B8B2', 'soft', 1.0, None, 18, 6)                                        # foot ring
    pm.ell((0, .46, 0), (.325, .035, .325), '8FA39C', 'soft', 1.0, None, 18, 6)                                      # rolled rim
    pm.ell((0, .465, 0), (.285, .02, .285), 'FBF5E6', 'painted', 1.0, None, 18, 6)                                   # milk paint surface
    pm.ell((.2, .30, .22), (.05, .17, .03), 'FBF5E6', 'painted', 1.0, None, 10, 8)                                   # drip down the front
    pm.ell((.2, .12, .235), (.045, .045, .03), 'FBF5E6', 'painted', 1.0, None, 10, 8)
    pm.ell((-.18, .30, .24), (.035, .11, .025), '7FC8A5', 'painted', 1.0, None, 8, 8)                                # a mint drip: the colour that goes in
    pm.curve([(-.31, .46, 0), (-.31, .8, 0), (.31, .8, 0), (.31, .46, 0)], .018, .018, '6E6A7E', 'soft', 6, 12)      # wire handle
    pm.cyl2((-.34, .5, .1), (.3, .56, -.05), .03, .026, 'B88A52', 'wood', 8, 3)                                      # stirring stick resting on the rim
    pm.ell((.3, .56, -.05), (.07, .02, .05), 'FBF5E6', 'painted', 1.0, None, 8, 6)                                   # paint on the stick
    return pm
