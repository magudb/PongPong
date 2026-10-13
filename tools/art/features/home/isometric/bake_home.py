#!/usr/bin/env python3
"""Bake the 10 exterior tiers (+ night emissive layer + construction scaffolds) with the shared prop camera.

  python tools/art/features/home/isometric/bake_home.py --only 1 --ss 2            (one tier, quick check; writes <out>/house_t01.png)
  python tools/art/features/home/isometric/bake_home.py --all --scaffold --ss 3 --jobs 6          (the 10 houses + 9 scaffolds, writes home.json)

--out defaults to <stage>/home_final with the stage tools/art/_stage/features_home ($TT_ART_STAGE overrides tools/art/_stage).

Per tier t (NN = 01..10):  house_tNN.png (day, outline, soft footprint shadow)  house_tNN_night.png (additive window/lamp layer, TRIMMED to its alpha bbox)
                           scaffold_toNN.png (construction scaffold around the NEW footprint + foundation + materials)
All share ONE pivot: the ground point at the door centre on the front plane.  The night layer is trimmed to the bbox of its non-zero alpha
(it is mostly empty: 5-48 KB of lights on a 950 x 1312 canvas); its position inside the day sprite is `night.offset` (px from the day sprite's top-left),
`night.size` its size.  Saves about 9 MB of texture memory at tiers 9-10.
"""
from __future__ import annotations
import argparse, json, sys, time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import homepaths


def bake_tier(args):
    t, out, ss = args
    import bake_lib as bl
    import home_traetoppen as ht
    import home_data as hd
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    h = ht.TIERS[t]()
    rect = h.rect
    r = bl.bake_model(h.pm, 0, ss=ss, shadow=('rect',), footprint=rect, want_emit=True, shadow_strength=.34, shadow_blur=9)
    nn = f'{t:02d}'
    r['main'].save(out / f'house_t{nn}.png', compress_level=6)
    meta = {'tier': t, 'id': hd.TIERS[t - 1][0], 'file': f'house_t{nn}.png', 'size': r['meta']['size'], 'pivot': r['meta']['pivot'],
            'footprint_tiles': [h.W, h.D], 'footprint_rect': list(rect), 'door_column': h.c, 'height_m': round(h.height, 2),
            'ysort': bl.ysort_px(rect), 'bake_seconds': r['meta']['bake_seconds']}
    if 'emit' in r:
        em = r['emit']
        box = em.getchannel('A').getbbox()             # None when a tier has no lights at all
        if box is not None:
            em.crop(box).save(out / f'house_t{nn}_night.png', compress_level=6)
            meta['night'] = {'file': f'house_t{nn}_night.png', 'blend': 'add', 'offset': [box[0], box[1]], 'size': [box[2] - box[0], box[3] - box[1]]}
    meta['total_seconds'] = round(time.time() - t0, 2)
    return t, meta


def bake_scaffold(args):
    t, out, ss = args
    import bake_lib as bl
    import home_scaffold as hs
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    sc = hs.scaffold_to(t)
    r = bl.bake_model(sc['pm'], 0, ss=ss, shadow=('rect',), footprint=sc['rect'], shadow_strength=.25, shadow_blur=8)
    nn = f'{t:02d}'
    r['main'].save(out / f'scaffold_to{nn}.png', compress_level=6)
    meta = {'file': f'scaffold_to{nn}.png', 'size': r['meta']['size'], 'pivot': r['meta']['pivot'], 'footprint_rect': list(sc['rect']),
            'ysort': bl.ysort_px(sc['rect']), 'bake_seconds': round(time.time() - t0, 2)}
    return t, meta


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--tiers', '--only', dest='tiers', type=int, nargs='*', help='tier numbers 1..10 (default: all)')
    ap.add_argument('--all', action='store_true')
    ap.add_argument('--out', default=None, help='output folder (default <stage>/home_final)')
    ap.add_argument('--ss', type=int, default=3); ap.add_argument('--jobs', type=int, default=5)
    ap.add_argument('--scaffold', action='store_true', help='also bake scaffold_toNN for tiers 2..10')
    ap.add_argument('--no-houses', action='store_true')
    a = ap.parse_args()
    import home_traetoppen as ht
    tiers = list(ht.TIERS) if a.all or not a.tiers else a.tiers
    bad = [t for t in tiers if t not in ht.TIERS]
    if bad:
        raise SystemExit(f'bake_home: unknown tier(s) {bad}; tiers are 1..{len(ht.TIERS)}')
    out = homepaths.assert_stage(a.out or homepaths.stage_root() / 'home_final'); out.mkdir(parents=True, exist_ok=True)
    mp = out / 'home.json'; meta = json.loads(mp.read_text()) if mp.exists() else {'tiers': {}, 'scaffold': {}}
    t0 = time.time()
    with ProcessPoolExecutor(min(a.jobs, max(1, len(tiers)))) as ex:
        if not a.no_houses:
            for t, m in ex.map(bake_tier, [(t, str(out), a.ss) for t in tiers]):
                meta['tiers'][str(t)] = m; print('tier', t, m['id'], m['size'], 'pivot', m['pivot'], f"{m['total_seconds']}s", flush=True)
        if a.scaffold:
            for t, m in ex.map(bake_scaffold, [(t, str(out), a.ss) for t in tiers if t >= 2]):
                meta['scaffold'][str(t)] = m; print('scaffold to', t, m['size'], f"{m['bake_seconds']}s", flush=True)
    mp.write_text(json.dumps(meta, indent=1))
    print('done in %.1fs -> %s' % (time.time() - t0, out))


if __name__ == '__main__':
    main()
