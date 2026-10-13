#!/usr/bin/env python3
"""Bake the 32 material icons in contract style (ids == lua item ids of lua/items/building_materials.lua).

  python tools/art/features/home/isometric/bake_material_icons.py [--out DIR] [--only id ...] [--jobs 4]

specs/material_icon_map.json maps the builders of characters/icons_materials.py (47 spike builders + 5 new ones) to the 32 content ids; every id is baked with the
same renderer and camera as the furniture icons (icons_contract.render_shapes: az 28 / el 30, no shadow, ink outline radius 2, fill .92), so the 162 icons are one family.
--out defaults to <stage>/mat_icons.
"""
from __future__ import annotations
import argparse, json, sys, time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import homepaths


def load_map(path=None) -> dict:
    """{content id: builder name} from material_icon_map.json (spike builders + new builders)"""
    m = json.loads(Path(path or homepaths.SPECS / 'material_icon_map.json').read_text(encoding='utf-8'))
    out = {cid: b for b, cid in m['map'].items()}
    out.update({cid: b for b, cid in m['new'].items()})
    if len(out) != len(m['map']) + len(m['new']):
        raise SystemExit('material_icon_map.json: two builders map to the same content id')
    return out


def job(a):
    cid, builder, out, ss, fill = a
    import bake_lib as bl, icons_contract as ic, icons_materials as im
    fn = im.ICONS.get(builder) or im.NEW.get(builder)
    if fn is None:
        raise SystemExit(f'no icon builder {builder!r} for {cid}')
    pm = fn()
    t0 = time.time()
    img = ic.render_shapes(bl.collect_shapes(pm, 'main'), bl.collect_shapes(pm, 'float'), 128, ss, fill)
    img.save(Path(out) / f'{cid}.png', compress_level=9)
    return cid, round(time.time() - t0, 2)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--out', default=None); ap.add_argument('--only', nargs='*'); ap.add_argument('--jobs', type=int, default=4)
    ap.add_argument('--ss', type=int, default=4); ap.add_argument('--fill', type=float, default=.92)
    a = ap.parse_args()
    out = Path(a.out) if a.out else homepaths.stage_root() / 'mat_icons'
    out.mkdir(parents=True, exist_ok=True)
    ids = load_map()
    if a.only:
        unknown = sorted(set(a.only) - set(ids))
        if unknown:
            raise SystemExit(f'bake_material_icons: unknown material ids {unknown}')
        ids = {k: v for k, v in ids.items() if k in a.only}
    t0 = time.time()
    with ProcessPoolExecutor(a.jobs) as ex:
        meta = dict(ex.map(job, [(cid, b, str(out), a.ss, a.fill) for cid, b in sorted(ids.items())], chunksize=2))
    (out / 'materials_icons.json').write_text(json.dumps(meta, indent=1))
    print(len(meta), 'icons in %.1fs' % (time.time() - t0), 'max', max(meta.values()), '->', out)


if __name__ == '__main__':
    main()
