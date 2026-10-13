#!/usr/bin/env python3
"""Bake the nine NEW small props (characters/features_props.py): chest_trae chest_jern chest_fe chest_konge dig_glimmer unique_glimmer tent slate_vein marble_vein.

  python tools/art/features/home/isometric/bake_features_props.py [--out DIR] [--only id ...] [--ss 3]       (--out defaults to <stage>/features_props)

Per prop: <id>.png (straight-alpha RGBA, outline + soft contact shadow baked in, ground pivot recorded), <id>_glow.png (additive halo, only lit props)
props.json in the shape of assets/iso_props/props.json: {id: {file, size:[w,h], pivot:[x,y], footprint:[tx,tz], glow?:{file, center, color, size}, blend?:'add'}}.
The glimmers are additive soft sprites painted procedurally (features_props.glimmer): `blend: "add"`, no shadow, no outline.  `file`/`glow.file` are relative to the json.
"""
from __future__ import annotations
import argparse, json, time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import homepaths


def bake_one(job):
    pid, out, ss = job
    import bake_lib as bl, features_props as fp
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    if pid in fp.GLIMMERS:
        img, pivot, foot = fp.glimmer(fp.GLIMMERS[pid])
        img.save(out / f'{pid}.png', compress_level=6)
        return pid, {'file': f'{pid}.png', 'size': list(img.size), 'pivot': list(pivot), 'footprint': list(foot), 'blend': 'add', 'bake_seconds': round(time.time() - t0, 2)}
    d = fp.PROPS3D[pid]()
    fx, fz = d.footprint
    kw = dict(shadow_strength=.30, shadow_blur=5)
    shadow = d.shadow
    res = bl.bake_model(d.pm, 0, ss=ss, shadow=shadow, footprint=(-fx / 2, -fz / 2, fx / 2, fz / 2) if shadow[0] == 'rect' else None, glow=d.glow, **kw)
    res['main'].save(out / f'{pid}.png', compress_level=6)
    meta = {'file': f'{pid}.png', 'size': res['meta']['size'], 'pivot': res['meta']['pivot'], 'footprint': [fx, fz]}
    if 'glow' in res:
        res['glow'].save(out / f'{pid}_glow.png')
        g = res['meta']['glow']
        meta['glow'] = {'file': f'{pid}_glow.png', 'center': g['center'], 'color': g['color'], 'size': g['size'], 'blend': 'add'}
    meta['bake_seconds'] = round(time.time() - t0, 2)
    return pid, meta


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--out', default=None); ap.add_argument('--only', nargs='*'); ap.add_argument('--ss', type=int, default=3); ap.add_argument('--jobs', type=int, default=5)
    a = ap.parse_args()
    import features_props as fp
    ids = [i for i in fp.ORDER if not a.only or i in a.only]
    if a.only and set(a.only) - set(fp.ORDER):
        raise SystemExit(f'bake_features_props: unknown ids {sorted(set(a.only) - set(fp.ORDER))}; known: {fp.ORDER}')
    out = homepaths.assert_stage(a.out or homepaths.stage_root() / 'features_props'); out.mkdir(parents=True, exist_ok=True)
    mp = out / 'props.json'
    meta = json.loads(mp.read_text()) if (a.only and mp.exists()) else {}
    meta['_contract'] = {'tile': [128, 76], 'px_per_m': 87.074, 'pivot': 'ground origin (footprint centre), px from the PNG top-left',
                         'files': 'relative to this json', 'blend': 'props with blend "add" are additive soft sprites (dig_glimmer, unique_glimmer): draw with CanvasItemMaterial BLEND_MODE_ADD'}
    t0 = time.time()
    with ProcessPoolExecutor(min(a.jobs, len(ids))) as ex:
        for pid, m in ex.map(bake_one, [(i, str(out), a.ss) for i in ids]):
            meta[pid] = m; print(f"{pid:<15} {m['size']} pivot {m['pivot']}  {m['bake_seconds']}s", flush=True)
    meta = {k: meta[k] for k in ['_contract'] + fp.ORDER if k in meta}
    mp.write_text(json.dumps(meta, indent=1))
    print('baked %d props in %.1fs -> %s' % (len(ids), time.time() - t0, out))


if __name__ == '__main__':
    main()
