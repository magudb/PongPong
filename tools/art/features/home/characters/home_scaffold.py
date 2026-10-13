"""Construction scaffold sprite for 'tier N-1 -> tier N' upgrades.

Wraps the NEW footprint (front + right faces, the ones the camera sees) with timber poles, ledgers, plank decks, braces and a ladder,
shows a stone foundation + a few courses of the new walls, tarps, a hoist with a hanging crate and the building materials (planks, stones, sacks).
Same anchor as every house tier, so it is drawn ON TOP of house_t(N-1) (y-sorted at its own front-left corner).
"""
from __future__ import annotations
import math
import numpy as np
from home_kit import HM, T
import home_traetoppen as ht

POLE = 'B88A52'; POLE_D = '8C6B3F'; PLANK = 'D6B27A'; ROPE = 'D9C79B'


def _pole(pm, x, z, h, r=.045):
    pm.log((x, -.02, z), (x, h, z), r, r * .92, POLE, 'bark2', 8, 3)
    pm.ell((x, -.01, z), (r * 2.2, .03, r * 2.2), '6E5A41', 'soft', seg=10, rings=6)


def _ledger_x(pm, x0, x1, y, z, r=.035):
    pm.log((x0, y, z), (x1, y, z), r, r, POLE_D, 'bark2', 8, 2)


def _ledger_z(pm, z0, z1, y, x, r=.035):
    pm.log((x, y, z0), (x, y, z1), r, r, POLE_D, 'bark2', 8, 2)


def _brace_x(pm, xa, xb, ya, yb, z):
    ln = math.hypot(xb - xa, yb - ya); ang = math.degrees(math.atan2(yb - ya, xb - xa))
    pm.box(((xa + xb) / 2, (ya + yb) / 2, z + .04), (ln, .06, .05), POLE_D, 'wood', power=.3, rot=(0, 0, ang))


def _brace_z(pm, za, zb, ya, yb, x):
    ln = math.hypot(zb - za, yb - ya); ang = math.degrees(math.atan2(yb - ya, zb - za))
    pm.box((x + .04, (ya + yb) / 2, (za + zb) / 2), (.05, .06, ln), POLE_D, 'wood', power=.3, rot=(-ang, 0, 0))


def scaffold_to(t: int):
    h = ht.TIERS[t]()
    W, D, c = h.W, h.D, h.c
    x0, x1, z0, z1 = ht._rect(W, D, c)
    rect_t = h.rect
    hs = float(np.clip(h.height * .62, 2.6, 7.6))
    levels = [round(v, 2) for v in np.arange(1.9, hs + .1, 1.95)]
    m = .5
    pm = HM()
    # foundation + first courses of the NEW walls on the front and right edges
    pm.box(((x0 + x1) / 2, .07, (z0 + z1) / 2), (x1 - x0 + .5, .14, z1 - z0 + .5), '8A8494', 'blocks', power=.25)          # new foundation slab
    for xx in np.arange(x0 + .3, x1, 1.2): pm.box((xx, .3, z1 - .1), (.14, .32, .2), POLE_D, 'wood', power=.3)                  # sill stubs
    for zz in np.arange(z0 + .3, z1, 1.2): pm.box((x1 - .1, .3, zz), (.2, .32, .14), POLE_D, 'wood', power=.3)
    pm.box(((x0 + x1) / 2, .22, z1 - .1), (x1 - x0, .1, .16), POLE_D, 'wood', power=.3); pm.box((x1 - .1, .22, (z0 + z1) / 2), (.16, .1, z1 - z0), POLE_D, 'wood', power=.3)
    # poles
    px = list(np.arange(x0 - m, x1 + m + .01, 1.45)); px[-1] = x1 + m if abs(px[-1] - (x1 + m)) < .3 else px[-1]
    pz = list(np.arange(z0 - m, z1 + m + .01, 1.45))
    zf, xr = z1 + m, x1 + m
    if px[-1] < x1 + m - .3: px.append(x1 + m)
    if pz[-1] < z1 + m - .3: pz.append(z1 + m)
    for x in px: _pole(pm, x, zf, hs + .4)
    for z in pz[:-1]: _pole(pm, xr, z, hs + .4)
    for y in levels:
        _ledger_x(pm, px[0], px[-1], y, zf); _ledger_x(pm, px[0], px[-1], y - .95, zf)
        _ledger_z(pm, pz[0], pz[-1], y, xr); _ledger_z(pm, pz[0], pz[-1], y - .95, xr)
        # plank decks (walkways) along both faces
        n = int((px[-1] - px[0]) / .55)
        for i in range(n):
            pm.box((px[0] + (i + .5) * (px[-1] - px[0]) / n, y + .04, zf + .12), ((px[-1] - px[0]) / n * .93, .05, .62), PLANK if i % 2 else 'C9A66B', 'plank_h', power=.28)
        n = int((pz[-1] - pz[0]) / .55)
        for i in range(n):
            pm.box((xr + .12, y + .04, pz[0] + (i + .5) * (pz[-1] - pz[0]) / n), (.62, .05, (pz[-1] - pz[0]) / n * .93), PLANK if i % 2 else 'C9A66B', 'plank_h', power=.28)
        # railing posts + top rail on the outer edge of each deck
        _ledger_x(pm, px[0], px[-1], y + .9, zf + .42, .025); _ledger_z(pm, pz[0], pz[-1], y + .9, xr + .42, .025)
        for x in px[::2]: pm.log((x, y, zf + .42), (x, y + .9, zf + .42), .022, .022, POLE_D, 'bark2', 6, 2)
        for z in pz[::2]: pm.log((xr + .42, y, z), (xr + .42, y + .9, z), .022, .022, POLE_D, 'bark2', 6, 2)
    # diagonal braces on the lowest bays
    for i in range(0, len(px) - 1, 2):
        _brace_x(pm, px[i], px[i + 1], .05, levels[0] if levels else 1.9, zf) if i % 4 == 0 else _brace_x(pm, px[i + 1], px[i], .05, levels[0], zf)
    for i in range(0, len(pz) - 2, 2): _brace_z(pm, pz[i], pz[i + 1], .05, levels[0], xr)
    # ladder on the front-left bay
    lx = px[0] + .72
    for sx in (-.2, .2): pm.log((lx + sx, 0, zf + .55), (lx + sx, levels[0] + .9, zf + .22), .028, .028, 'C9A66B', 'bark2', 6, 2)
    for k in range(9):
        t_ = (k + .5) / 9; pm.log((lx - .2, t_ * (levels[0] + .9), zf + .55 - t_ * .33), (lx + .2, t_ * (levels[0] + .9), zf + .55 - t_ * .33), .018, .018, 'C9A66B', 'bark2', 6, 2)
    # tarp over one upper bay (cloth hanging from the top deck) + pennant bunting
    ytop = levels[-1]
    if len(levels) >= 2:
        i = min(2, len(px) - 2)
        pm.box(((px[i] + px[i + 1]) / 2, ytop - .6 + .9 - .9, zf + .5), (px[i + 1] - px[i] - .1, 1.3, .035), 'F4E6C4', 'weave', power=.3)
        pm.ell(((px[i] + px[i + 1]) / 2, ytop - 1.25, zf + .5), ((px[i + 1] - px[i]) / 2 - .06, .12, .02), 'F4E6C4', 'weave', power=.8)
    cols = ('6B9A3E', 'E8B04A', 'E58FA6', '9B86D6')
    ytf = ytop + .95
    for k in range(len(px) * 2):
        xx = px[0] + (k + .5) * (px[-1] - px[0]) / (len(px) * 2)
        pm.ell((xx, ytf - .02 - .06 * math.sin(k * 1.3), zf + .45), (.07, .1, .015), cols[k % 4], 'weave', power=.9, seg=8, rings=6, rot=(0, 0, 180))
    # hoist beam with hanging crate on the top level (right end)
    hx = px[-1] - .6
    pm.log((hx, ytop + .1, zf + .1), (hx, ytop + 1.1, zf + .1), .04, .04, POLE_D, 'bark2', 6, 2)
    pm.log((hx, ytop + 1.1, zf + .1), (hx, ytop + 1.1, zf + 1.3), .035, .035, POLE_D, 'bark2', 6, 2)
    pm.log((hx, ytop + 1.1, zf + 1.3), (hx, ytop + .1, zf + 1.3), .008, .008, ROPE, 'soft', 5, 2)
    pm.box((hx, ytop - .18, zf + 1.3), (.42, .34, .42), 'C9A66B', 'plank_h', power=.3)
    pm.box((hx, ytop - .18, zf + 1.3), (.44, .05, .44), POLE_D, 'wood', power=.3)
    # materials on the ground in front: planks, stone blocks, sacks, barrel, wheelbarrow-ish crate
    for k in range(5): pm.box((x0 + .5, .07 + k * .12, zf + 1.0 + (k % 2) * .03), (1.5, .1, .38), 'D6B27A' if k % 2 else 'C9A66B', 'plank_h', power=.28, rot=(0, 90 * 0, 0))
    for k in range(6): pm.box((x0 + 2.1 + (k % 3) * .42, .16 + (k // 3) * .30, zf + .95 + (k % 2) * .05), (.4, .27, .27), 'B7B1BE', 'blocks', power=.28, rot=(0, 7 * k, 0))
    for k in range(3): pm.ell((xr + 1.0, .17, pz[len(pz) // 2] + k * .5 - .5), (.26, .17, .22), 'E9D6A8', 'weave', power=.9, rot=(0, 15 * k, 0))
    ht.barrel(pm, xr + 1.0, pz[-1] + .1, .2, .55)
    ht.lantern(pm, px[1], levels[0] + .3, zf + .45)
    return {'pm': pm, 'rect': tuple(rect_t), 'height': hs}
