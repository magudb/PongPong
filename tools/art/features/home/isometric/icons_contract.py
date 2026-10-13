#!/usr/bin/env python3
"""Contract-style icons for the 130 furniture items AND the 32 material items (review fix RV-A3 for critic finding ART-3).

The 130 furniture icons of the first addendum came from bake_furniture.make_icon(): a downsampled WORLD sprite.  That keeps the world sprite's warm
mid-tone outline (75,60,73 @55 %) and the baked ground shadow (counted in the fit bbox), so the icons did not match the 60 contract icons
(ink 2b2340, 2 px, no shadow).  This renderer draws every item the way the 60 cast icons are drawn: icon camera az 28 / el 30, NO shadow, NO world
outline, fit to main + float shapes at `fill` (.92), ink outline radius 2 alpha .95 colour 2b2340, then the legendary float layer (sparkles)
composited.  The material icons (bake_material_icons.py) use the same renderer so that all 162 icons are one family.

  python tools/art/features/home/isometric/icons_contract.py --spec tools/art/features/home/specs/furniture_art_spec.json --out DIR [--only id ...] [--fill .92] [--ss 4] [--jobs 6]

Measured by the review: 130 icons, 12 s wall on 6 workers, 1.20 MB lossless WebP (9.2 KB avg), outer ring within 24/255 of the ink colour 130/130,
bbox fill 0.906-0.923 (cast icons 0.875).
"""
from __future__ import annotations
import argparse, json, math, sys, time
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor
import homepaths
import numpy as np
from PIL import Image

INK = (43, 35, 64)
AZ, EL = 28.0, 30.0


def basis(az, el):
    a, e = math.radians(az), math.radians(el)
    d = -np.array([math.sin(a) * math.cos(e), math.sin(e), math.cos(a) * math.cos(e)])
    r = np.cross(d, [0, 1, 0]); r /= np.linalg.norm(r); u = np.cross(r, d); u /= np.linalg.norm(u)
    return r, u


def render_shapes(main_sh, float_sh=(), size=128, ss=4, fill=.92):
    """RGBA icon (size x size) of the given main shapes (+ float shapes, drawn flat and bright) in the contract style."""
    import bake_lib as bl, static_render as sr
    pos, nrm, uv, faces, atlas = bl.mesh_from_shapes(list(main_sh), 256)
    r, u = basis(AZ, EL)
    # fit on main + float (sparkles of the legendary pieces must not be clipped by the cell)
    allv = np.concatenate([pos] + ([bl.mesh_from_shapes(list(float_sh), 64)[0]] if float_sh else []))
    sx, sy = allv @ r, allv @ u
    cx, cy = (sx.max() + sx.min()) / 2, (sy.max() + sy.min()) / 2
    ext = max(sx.max() - sx.min(), sy.max() - sy.min())
    # the icon fills the cell: ppm so the main object spans `fill` of the cell, leaving 3 px for the outline on each side
    ppm = (size - 6) * fill / ext
    focus = r * cx + u * cy
    rend = sr.StaticRenderer(pos, nrm, uv, faces, atlas)
    im = rend.render(size, size, az=AZ, focus=tuple(focus), ss=ss, ppm=ppm, elev=EL)
    if float_sh:
        p2, n2, uv2, f2, a2 = bl.mesh_from_shapes(list(float_sh), 256)
        im2 = sr.StaticRenderer(p2, n2, uv2, f2, a2, ambient=1.0, diffuse=0.0).render(size, size, az=AZ, focus=tuple(focus), ss=ss, ppm=ppm, elev=EL)
        im.alpha_composite(im2)
    return sr.warm_outline(im, radius=2, color=INK, alpha=.95)


def icon_for(item, size=128, ss=4, fill=.92):
    import bake_lib as bl, spec_reader as sp
    spec = sp.build(item)
    return render_shapes(bl.collect_shapes(spec.pm, 'main'), bl.collect_shapes(spec.pm, 'float'), size, ss, fill), spec


def job(a):
    item, out, ss, fill = a
    im, spec = icon_for(item, ss=ss, fill=fill)
    f = Path(out) / f"{item['id']}.png"
    im.save(f, compress_level=9)
    return item['id'], f.stat().st_size


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--spec', default=str(homepaths.SPECS / 'furniture_art_spec.json'))
    ap.add_argument('--out', default=None, help='default <stage>/icons_furn')
    ap.add_argument('--only', nargs='*'); ap.add_argument('--fill', type=float, default=.92); ap.add_argument('--ss', type=int, default=4); ap.add_argument('--jobs', type=int, default=6)
    a = ap.parse_args()
    import spec_reader as sp
    items = sp.load(a.spec)
    if a.only: items = [i for i in items if i['id'] in a.only]
    out = Path(a.out) if a.out else homepaths.stage_root() / 'icons_furn'
    out.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    with ProcessPoolExecutor(a.jobs) as ex:
        res = list(ex.map(job, [(i, str(out), a.ss, a.fill) for i in items], chunksize=2))
    print(f'{len(res)} icons in {time.time() - t0:.0f}s wall -> {out}')


if __name__ == '__main__':
    main()
