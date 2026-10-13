#!/usr/bin/env python3
"""Interior shell pieces: cut-away back walls (3 styles x plain / pilaster / window, two orientations), corner posts, doormat + door lanterns,
and the 4 interior floor atlases (periodic 4x4, same recipe as the exterior ground tiles).

  python tools/art/features/home/isometric/bake_interior.py [--out <stage>/interior] [--ss 3]

Wall piece  = one tile long, pivot = centre of the tile edge on the floor line.  z-wall (r0) sits on the cell's back-right edge facing +z; the x-wall
(r1) is the SAME model yawed 90 deg (so its lighting is correct): sits on the back-left edge facing +x.  Patterns are periodic over exactly one tile,
so neighbouring segments join without seams.
"""
from __future__ import annotations
import argparse, json, math, sys, time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import numpy as np
import homepaths

STYLES = {
    'plank':  dict(h=2.55, upper=('plank_v', 'D9B77F'), lower=('plank_h', 'B88A52'), lower_h=.9, rail='8C6B3F', crown='7A4E2D', base='6B4126', post='8C6B3F', glass='A9D3E0', trim='7A4E2D', cut='B88A52'),
    'paper':  dict(h=3.0, upper=('damask', 'F1D9C8'), lower=('plank_h', 'FBF5E6'), lower_h=1.0, rail='E8D9B0', crown='E3C372', base='D8C9A0', post='FBF5E6', glass='A9D3E0', trim='FBF5E6', cut='F4E6C4'),
    'marble': dict(h=3.7, upper=('blocks', 'F2E6CC'), lower=('marble', 'F7F0E2'), lower_h=1.1, rail='E3C372', crown='E3C372', base='C9B8EE', post='F7F0E2', glass='C9D8F6', trim='F7F0E2', cut='E8DFCB'),
}


def wall_model(style, kind):
    from home_kit import HM, T, PAINTERS, ql
    import geometry as geo
    S = STYLES[style]; pm = HM(); h = S['h']; L = T + .004; t = .17
    hw = L / 2

    def face_box(x0, x1, y0, y1, color, pat, depth=0.0, span=None):
        """flat box on the wall face from x0..x1, y0..y1, front plane at z=depth, thickness .02..t; planar UV periodic over one tile (span = metres per texture)"""
        span = span or T
        pm_ = pm
        c = ((x0 + x1) / 2, (y0 + y1) / 2, depth - t / 2); size = (x1 - x0, y1 - y0, t)
        v, f = geo.ellipsoid(c, np.array(size) / 2, 14, 10, .12, 0.0)
        u = (v[:, 0] + T / 2) / T                      # every tile sees the same texture window -> neighbouring segments join seamlessly
        w = 1 - v[:, 1] / h
        uv = np.stack([np.clip(u, 0, 1), np.clip(w, 0, 1)], 1)
        base = pat.split('@')[0]
        pm._add(v, f, color, f'{base}@{T:.3f},{h:.3f}' if base in PAINTERS else pat, uv, True)

    lw = S['lower_h']
    # main wall body: lower wainscot + upper wall + cut-face cap
    face_box(-hw, hw, 0, lw, S['lower'][1], S['lower'][0], span=T)
    face_box(-hw, hw, lw - .02, h, S['upper'][1], S['upper'][0], span=T)
    face_box(-hw - .005, hw + .005, lw - .05, lw + .05, S['rail'], 'wood' if style == 'plank' else 'soft', depth=.03, span=T)       # chair rail
    face_box(-hw - .005, hw + .005, 0, .13, S['base'], 'wood' if style != 'marble' else 'marble', depth=.03, span=T)                    # baseboard
    face_box(-hw - .005, hw + .005, h - .16, h + .02, S['crown'], 'wood' if style != 'marble' else 'gold', depth=.05, span=T)          # crown
    pm.box((0, h + .035, -t / 2), (L + .01, .06, t + .01), S['cut'], 'soft', power=.2)                                                   # cut cap on top (lighter edge)
    if kind == 'b':      # pilaster / post at the left end of the tile
        pm.box((-hw + .09, h / 2, .02), (.18, h, .1), S['post'], 'wood' if style == 'plank' else ('marble' if style == 'marble' else 'painted'), power=.25)
        if style == 'marble':
            pm.ell((-hw + .09, h - .12, .03), (.14, .08, .09), 'E3C372', 'gold', .9, None, 12, 8); pm.ell((-hw + .09, .12, .03), (.14, .07, .09), 'E3C372', 'gold', .9, None, 12, 8)
        if style == 'paper': pm.ell((-hw + .09, h - .12, .03), (.12, .06, .08), 'E3C372', 'gold', .9, None, 12, 8)
    if kind == 'win':
        ww, wh, wy = .62, 1.05 + (.4 if style == 'marble' else 0), 1.05 + lw * .35
        pm.box((0, wy, .0), (ww + .24, wh + .24, .1), S['trim'], 'wood' if style == 'plank' else 'painted', power=.25)
        pm.box((0, wy, .03), (ww, wh, .06), S['glass'], 'glass', power=.2)
        pm.box((0, wy, .05), (ww * .94, wh * .94, .03), 'FFE9B0', 'emitn', power=.2)                  # night: warm light spills? (moonlight tint chosen in the engine)
        pm.box((0, wy, .07), (.04, wh, .03), S['trim'], 'soft', power=.3); pm.box((0, wy, .07), (ww, .04, .03), S['trim'], 'soft', power=.3)
        pm.box((0, wy - wh / 2 - .1, .1), (ww + .34, .06, .2), S['trim'], 'wood' if style == 'plank' else 'painted', power=.3)
        if style == 'marble': pm.ell((0, wy + wh / 2 + .02, .03), (ww / 2 + .12, .22, .06), S['trim'], 'marble', .8, None, 18, 10)
    return pm, S


def corner_model(style):
    from home_kit import HM
    S = STYLES[style]; pm = HM(); h = S['h']
    pm.box((-.0, h / 2, -.0), (.3, h + .08, .3), S['post'], 'wood' if style == 'plank' else ('marble' if style == 'marble' else 'painted'), power=.22)
    pm.box((0, .08, 0), (.36, .16, .36), S['base'], 'soft', power=.25); pm.box((0, h + .04, 0), (.36, .1, .36), S['crown'], 'soft', power=.25)
    return pm, S


def bake_piece(job):
    style, kind, out, ss = job
    import bake_lib as bl
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    pm, S = wall_model(style, kind) if kind != 'corner' else corner_model(style)
    meta = {}
    for r in ((0, 1) if kind != 'corner' else (0,)):
        res = bl.bake_model(pm, 90 * r, ss=ss, tile=512, shadow=None, want_emit=(kind == 'win'), pad=2)
        base = f'wall_{style}_{kind}_r{r}' if kind != 'corner' else f'corner_{style}'
        res['main'].save(out / f'{base}.png', compress_level=6)
        meta[base] = {'file': f'{base}.png', 'size': res['meta']['size'], 'pivot': res['meta']['pivot'], 'height_m': S['h']}
        if 'emit' in res: res['emit'].save(out / f'{base}_night.png', compress_level=6); meta[base]['night'] = f'{base}_night.png'
    return meta


def door_pieces(out, ss):
    import bake_lib as bl
    from home_kit import HM, T
    from home_traetoppen import lantern
    out = Path(out)
    meta = {}
    pm = HM()                                    # doormat: flat rug, 1 tile wide
    pm.box((0, .02, 0), (T * .86, .04, T * .62), '8DB86A', 'carpet', .3, L=T)
    pm.box((0, .045, 0), (T * .7, .02, T * .46), 'F4E6C4', 'weave', .3, L=T)
    res = bl.bake_model(pm, 0, ss=ss, shadow=None, pad=2)
    res['main'].save(out / 'doormat_r0.png'); meta['doormat_r0'] = {'file': 'doormat_r0.png', 'size': res['meta']['size'], 'pivot': res['meta']['pivot']}
    res = bl.bake_model(pm, 90, ss=ss, shadow=None, pad=2); res['main'].save(out / 'doormat_r1.png'); meta['doormat_r1'] = {'file': 'doormat_r1.png', 'size': res['meta']['size'], 'pivot': res['meta']['pivot']}
    pm = HM()                                    # door post with hanging lantern (flanks the exit)
    pm.cyl2((0, 0, 0), (0, 1.9, 0), .06, .05, '7A4E2D', 'wood', 10, 3)
    pm.cyl2((0, 1.85, 0), (.3, 1.95, 0), .03, .03, '4A3A4D', 'soft', 8, 3)
    lantern(pm, .3, 1.62, 0)
    res = bl.bake_model(pm, 0, ss=ss, shadow=('ellipse', .3, .16), glow=('FFD98A', 40, .6, (.3, 1.62, 0)), pad=4)
    res['main'].save(out / 'door_post.png'); meta['door_post'] = {'file': 'door_post.png', 'size': res['meta']['size'], 'pivot': res['meta']['pivot'], 'glow': res['meta']['glow']}
    return meta


# ---------------------------------------------------------------------------------------------------------------------------------
def floor_recipes():
    import bake_tiles_vendored as bt
    import numpy as np
    from PIL import Image, ImageDraw
    P = bt.P

    def planks(base, light, dark, boards=4, seed=11):
        cv = bt.Canvas(bt.hexrgb(base), seed)
        cv.tint(.04, 6)
        n = P * boards; bh = cv.n / n
        idx = (np.arange(cv.n)[:, None] // bh).astype(int)
        tone = np.array([cv.rng.uniform(-.08, .07) for _ in range(n + 1)])[idx]
        cv.rgb *= (1 + np.repeat(tone, cv.n, axis=1))[:, :, None]
        grain = bt.pnoise(cv.n, 14, cv.rng) * .5; xs = np.arange(cv.n)[None, :]
        cv.rgb *= (1 + (np.sin(xs / 6.0 + grain * 12) * .03))[:, :, None]
        local = (np.arange(cv.n)[:, None] % bh) / bh
        seam = np.exp(-((np.minimum(local, 1 - local)) ** 2) / (2 * .018 ** 2)) * np.ones((1, cv.n))
        cv.rgb *= (1 - seam[:, :, None] * .34)
        # staggered butt joints
        d_ = ImageDraw.Draw(Image.new('L', (4, 4)))
        joints = np.zeros((cv.n, cv.n), np.float32)
        for b in range(n):
            for jx in range(P):
                x = int(((jx + (b * .37) % 1.0) * bt.RES) % cv.n)
                y0 = int(b * bh)
                joints[y0:int(y0 + bh), max(0, x - 1):x + 2] = 1
        cv.rgb *= (1 - joints[:, :, None] * .22)
        cv.h = (-seam * .012 + bt.pnoise(cv.n, 30, cv.rng) * .003).astype(np.float32)
        return cv

    def flagstone():
        cv = bt.terrain_cobble(31, 'grey')
        cv.rgb = cv.rgb * np.array([1.0, .98, .93])[None, None, :]
        return cv

    def parquet():
        cv = bt.Canvas(bt.hexrgb('8C5E3A'), 21); cv.tint(.04, 6)
        n = cv.n; step = bt.RES / 4
        yy, xx = np.mgrid[0:n, 0:n]
        cell_x = (xx // step).astype(int); cell_y = (yy // step).astype(int)
        diag = ((xx % step) + (yy % step)) / step
        tone = np.array([[cv.rng.uniform(-.12, .1) for _ in range(n // int(step) + 2)] for _ in range(n // int(step) + 2)])
        orient = ((cell_x + cell_y) % 2).astype(bool)
        k = 1 + tone[cell_y, cell_x]
        stripe = np.where(orient, (xx % step) / step, (yy % step) / step)
        plank = (np.floor(stripe * 3) % 2) * .05
        edge = np.exp(-((np.minimum(stripe * 3 % 1, 1 - stripe * 3 % 1)) ** 2) / (2 * .03 ** 2))
        cv.rgb *= (k + plank - edge * .3)[:, :, None]
        cv.rgb *= (1 + bt.pnoise(n, 20, cv.rng)[:, :, None] * .05)
        cv.h = (-edge * .01).astype(np.float32)
        return cv

    def marble_checker():
        cv = bt.Canvas(bt.hexrgb('F2EBDD'), 41); cv.tint(.03, 8)
        n = cv.n; step = bt.RES / 2
        yy, xx = np.mgrid[0:n, 0:n]
        chk = (((xx // step).astype(int) + (yy // step).astype(int)) % 2).astype(np.float32)
        colA = np.array([244, 238, 224], np.float32); colB = np.array([186, 176, 214], np.float32)
        img = colA[None, None, :] * (1 - chk[:, :, None]) + colB[None, None, :] * chk[:, :, None]
        vein = np.abs(np.sin((xx * .012 + yy * .006 + bt.pnoise(n, 6, cv.rng) * 3) * math.pi)) ** 30
        img *= (1 - vein[:, :, None] * .07)
        edge = np.exp(-((np.minimum(xx % step, step - xx % step)) ** 2) / (2 * 1.6 ** 2)) + np.exp(-((np.minimum(yy % step, step - yy % step)) ** 2) / (2 * 1.6 ** 2))
        img = img * (1 - np.clip(edge, 0, 1)[:, :, None] * .16) + 8 * bt.pnoise(n, 24, cv.rng)[:, :, None]
        cv.rgb = img.astype(np.float32); cv.h = (-np.clip(edge, 0, 1) * .004).astype(np.float32)
        return cv
    return {'floor_stone': flagstone, 'floor_plank': lambda: planks('D6B27A', 0, 0, 4, 11), 'floor_parquet': parquet, 'floor_marble': marble_checker}


def bake_floor(job):
    name, out, ss = job
    import bake_tiles_vendored as bt
    out = Path(out); t0 = time.time()
    cv = floor_recipes()[name]()
    meta = bt.bake_terrain(name, cv, out, ss); meta['seconds'] = round(time.time() - t0, 1)
    return name, meta


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--out', default=None, help='output folder (default <stage>/interior)'); ap.add_argument('--ss', type=int, default=3); ap.add_argument('--jobs', type=int, default=4)
    a = ap.parse_args(); out = homepaths.assert_stage(a.out or homepaths.stage_root() / 'interior'); (out / 'interior').mkdir(parents=True, exist_ok=True); (out / 'tiles').mkdir(parents=True, exist_ok=True)
    t0 = time.time(); meta = {'walls': {}, 'floors': {}}
    jobs = [(s, k, str(out / 'interior'), a.ss) for s in STYLES for k in ('a', 'b', 'win', 'corner')]
    with ProcessPoolExecutor(a.jobs) as ex:
        for m in ex.map(bake_piece, jobs): meta['walls'].update(m)
        for name, m in ex.map(bake_floor, [(n, str(out / 'tiles'), a.ss) for n in floor_recipes()]): meta['floors'][name] = m; print('floor', name, m['seconds'], 's', flush=True)
    meta['door'] = door_pieces(out / 'interior', a.ss)
    (out / 'interior' / 'interior.json').write_text(json.dumps(meta, indent=1))
    tj = out / 'tiles' / 'tiles.json'; tj.write_text(json.dumps({'_contract': {'tile_size': [128, 76], 'atlas_cell': [144, 84], 'variants': [4, 4]}, **meta['floors']}, indent=1))
    print('pieces', len(meta['walls']), 'in %.1fs' % (time.time() - t0))


if __name__ == '__main__':
    main()
