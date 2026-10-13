#!/usr/bin/env python3
"""Bake the furniture catalogue: every item at every DISTINCT rotation (symmetry-aware), float layers, furniture.json.

  python tools/art/features/home/isometric/bake_furniture.py --spec tools/art/features/home/specs/furniture_art_spec.json --jobs 6 [--only bed_pine chair_oak] [--ss 3]

--out defaults to <stage>/furn (stage = tools/art/_stage/features_home).  The catalogue is the SPEC (spec_reader.py: 130 English ids), not the spike's furniture_catalog.

Output (PNG masters; export_home.py converts them to WebP):
  furniture/<id>_r<k>.png          main sprite, rotation k = baked yaw k*90 deg (k in the item's `baked` list only)
  furniture/<id>_r<k>_float.png    LEGENDARY floating bits (only tier 4 builds a 'float' layer; same crop + pivot, bobbed by the engine)
  furniture.json                   per item: layer, sym, baked[], rot{k: file, size, pivot, footprint, ysort, float?, glow?, interact_*, surface_slots}, surface, interact, hang
Icons are NOT made here any more (icons_contract.py renders them in contract style: the downsampled world sprite kept the warm world outline and the shadow).

Rotation policy (RV-A5; the class is the MEASURED one, spec_reader.symmetry() + specs/symmetry_measured.json): symmetry class sym  c4 -> 1 bake (r0)   c2 -> 2 bakes (r0, r1; r2 = r0, r3 = r1)   wall2 -> 2 bakes (r0 faces +z wall, r1 faces +x wall)
   none -> 4 TRUE bakes (r0 r1 r2 r3).  There is no mirror bake: flip_h of r0/r2 is only a DISK fallback for the ids of specs/mirror_ok.json, applied by export_home.py --mirror-fallback.
"""
from __future__ import annotations
import argparse, json, sys, time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import homepaths


def rot_vec(v, r):
    c, s = [(1, 0), (0, 1), (-1, 0), (0, -1)][r % 4]
    return [round(v[0] * c + v[1] * s, 3), round(-v[0] * s + v[1] * c, 3)]


def bake_item(job):
    item, out, ss, tile = job
    import bake_lib as bl, spec_reader as sp
    out = Path(out); (out / 'furniture').mkdir(parents=True, exist_ok=True)
    t_all = time.time()
    spec = sp.build(item)
    sym = sp.symmetry(item, spec)
    baked = sp.rotations_needed(sym)
    meta = {'id': item['id'], 'template': item['template'], 'category': spec.category, 'layer': spec.layer, 'rarity': item['rarity'],
            'tier': item['tier'], 'sym': sym, 'footprint': list(spec.fp), 'height_m': round(spec.height, 2), 'baked': baked, 'rot': {}, 'bake_seconds': {}, 'png_bytes': 0}
    if spec.surface: meta['surface'] = {'height_m': spec.surface['height'], 'slots': spec.surface['slots']}
    if spec.interact: meta['interact'] = spec.interact
    if spec.hang is not None: meta['hang_m'] = round(spec.hang, 2)
    for r in baked:
        fx, fz = spec.fp if r % 2 == 0 else spec.fp[::-1]
        rect = (-fx / 2, -fz / 2, fx / 2, fz / 2)
        t0 = time.time(); c0 = time.process_time()
        # contact shadow: floor pieces + rugs get the soft footprint diamond; wall and ceiling pieces none; TABLETOP pieces (vase, lamp, candelabra) a small ellipse under their base -
        # the spike gave them the full-tile diamond, which would paint a one-tile grey patch on a tabletop (found on the ladder sheets)
        shadow = None if spec.layer in ('wall', 'ceiling') else (('ellipse', .2, .2) if spec.layer == 'tabletop' else ('rect',))
        res = bl.bake_model(spec.pm, 90 * r, ss=ss, tile=tile, shadow=shadow, footprint=rect if shadow and shadow[0] == 'rect' else None, glow=spec.glow,
                            shadow_strength={'rug': .12, 'tabletop': .26}.get(spec.layer, .30), shadow_blur=5)
        dt = time.time() - t0; dc = time.process_time() - c0
        base = f"{item['id']}_r{r}"
        res['main'].save(out / 'furniture' / f'{base}.png', compress_level=6); meta['png_bytes'] += (out / 'furniture' / f'{base}.png').stat().st_size
        ent = {'file': f'furniture/{base}.png', 'size': res['meta']['size'], 'pivot': res['meta']['pivot'], 'footprint': [fx, fz]}
        if spec.layer == 'floor': ent['ysort'] = bl.ysort_px(rect)
        if 'float' in res:
            res['float'].save(out / 'furniture' / f'{base}_float.png', compress_level=6); meta['png_bytes'] += (out / 'furniture' / f'{base}_float.png').stat().st_size
            ent['float'] = {'file': f'furniture/{base}_float.png', 'bob_px': 5, 'bob_seconds': 2.4}
        if spec.glow:
            g = res['meta']['glow']; ent['glow'] = {'color': g['color'], 'radius_px': spec.glow[1], 'strength': spec.glow[2], 'center': g['center'], 'blend': 'add'}
        if spec.interact:
            ent['interact_from'] = rot_vec(spec.interact.get('from', [0, 1]), r)
            ent['interact_anchor'] = rot_vec(spec.interact.get('anchor', [0, 0]), r)
        if spec.surface: ent['surface_slots'] = [rot_vec(s_, r) for s_ in spec.surface['slots']]
        meta['rot'][str(r)] = ent; meta['bake_seconds'][str(r)] = round(dt, 2); meta.setdefault('bake_cpu_seconds', {})[str(r)] = round(dc, 2)
    # rotation k (0..3) -> baked file index + mirrored flag: what the engine uses.  TRUE bakes only (mirrored is always False here).
    meta['rot_map'] = [[{'c4': 0, 'c2': r % 2, 'wall2': r % 2}.get(sym, r), False] for r in range(4)]
    meta['seconds'] = round(time.time() - t_all, 2)
    return meta


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--spec', default=str(homepaths.SPECS / 'furniture_art_spec.json'))
    ap.add_argument('--out', default=None, help='output folder (default <stage>/furn)')
    ap.add_argument('--jobs', type=int, default=6); ap.add_argument('--ss', type=int, default=3)
    ap.add_argument('--only', nargs='*'); ap.add_argument('--tile', type=int, default=256)
    a = ap.parse_args()
    import spec_reader as sp
    items = sp.load(a.spec)
    if a.only:
        unknown = sorted(set(a.only) - {i['id'] for i in items})
        if unknown:
            raise SystemExit(f'bake_furniture: ids not in the spec: {unknown}')
        items = [i for i in items if i['id'] in a.only]
    out = homepaths.assert_stage(a.out or homepaths.stage_root() / 'furn'); out.mkdir(parents=True, exist_ok=True)
    fj = out / 'furniture.json'
    res = json.loads(fj.read_text())['items'] if (a.only and fj.exists()) else {}      # a partial run updates the existing catalogue
    t0 = time.time()
    jobs = [(i, str(out), a.ss, a.tile) for i in items]
    with ProcessPoolExecutor(a.jobs) as ex:
        for m in ex.map(bake_item, jobs, chunksize=1):
            res[m['id']] = m; print(f"{m['id']:<24} {m['rarity']:<9} baked r{m['baked']}  {m['seconds']:>5.1f}s  {m['png_bytes'] / 1024:6.0f} KB", flush=True)
    order = [i['id'] for i in sp.load(a.spec)]
    res = {k: res[k] for k in order if k in res}
    fj.write_text(json.dumps({'_contract': {'tile': [128, 76], 'px_per_m': 87.074, 'rotation': 'yaw k*90 deg about +Y; r0 front faces +z (screen left-down), r1 faces +x (screen right-down)',
                                            'pivot': 'ground point at the footprint centre (wall items: on the wall plane below the item centre)'}, 'items': res}, indent=1, ensure_ascii=False))
    print(f'baked {len(items)} items in {time.time() - t0:.0f}s wall -> {out}')


if __name__ == '__main__':
    main()
