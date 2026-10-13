#!/usr/bin/env python3
"""MEASURE the symmetry class of the furniture pieces that their TEMPLATE declares as c4 or c2 (review fix: the classes used to be declared per template, never measured).

The rotation policy bakes only the DISTINCT views of a piece:  c4 = one view (r0), c2 = two (r0, r1), anything else = four.  A template declares its class
(`FSpec.sym`), but a plant with a teapot spout, a vase with a handle or a chandelier with six arms is NOT 4-fold symmetric, and a single baked view then
ignores the rotation in Indretning.  This tool bakes r0 r1 r2 r3 of every piece that DECLARES c4 or c2 (the same camera, shadow and ss as bake_furniture.py, main layer only,
the float layer of legendary pieces is a free-floating overlay and excluded), aligns two views by their pivots and calls them EQUAL when

    silhouette mismatch  = xor(alpha > 128) / union(alpha > 128)  at full resolution  < 4 %      (the shape: a 1-2 % mismatch is the facets of a lathe turned by 90 degrees)
    colour error         = mean abs RGB difference of the 4x4 block means (premultiplied) over the union  < 20/255     (the layout of colour: leaf clusters, spots, a spout; the fine
                           texture phase of a woven rug is averaged away)

and classifies the piece:   c4  r0 = r1 and r0 = r2          c2  r0 = r2 and r1 = r3          none  anything else (four true bakes).
The measured gap is wide: every piece that is symmetric by construction stays below 2 % / 15, every asymmetric one is above 4 % (or 30 and more on the other pair).

specs/symmetry_measured.json stores the result; spec_reader.symmetry() overrides the declared class with it (the declared class is never trusted on its own again).

  python measure_symmetry.py [--spec FILE] [--only ID ...] [--jobs 6] [--ss 2] [--write [FILE]] [--check [FILE]]

--write stores specs/symmetry_measured.json, --check exits 1 when the stored classes are not exactly the measured ones (produce_home.sh runs one of them before the furniture bake).
"""
from __future__ import annotations
import argparse, json, sys, time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import numpy as np
from PIL import Image
import homepaths

ERR_MAX = 20.0           # block-mean colour error on the 0..255 scale
SIL_MAX = 4.0            # silhouette mismatch in percent
DEFAULT_FILE = homepaths.SPECS / 'symmetry_measured.json'
PAIRS = (('r0_r1', 0, 1), ('r0_r2', 0, 2), ('r1_r3', 1, 3))


def compare_views(a: Image.Image, pa, b: Image.Image, pb):
    """(colour error /255 of the 4x4 block means over the union, silhouette mismatch %) of two RGBA sprites aligned by their pivots"""
    m = 8                                                                    # (wall and ceiling pieces carry the pivot BELOW the sprite: the canvas is laid out from the pivot)
    cx = max(pa[0], pb[0]) + m; cy = max(pa[1], pb[1]) + m
    W = (cx + max(a.width - pa[0], b.width - pb[0], 0) + m + 3) // 4 * 4; H = (cy + max(a.height - pa[1], b.height - pb[1], 0) + m + 3) // 4 * 4

    def canvas(im, piv):
        c = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        c.alpha_composite(im, (cx - piv[0], cy - piv[1]))
        return np.asarray(c, np.float32)
    A, B = canvas(a, pa), canvas(b, pb)
    uni = (A[..., 3] > 128) | (B[..., 3] > 128)
    sil = np.logical_xor(A[..., 3] > 128, B[..., 3] > 128).sum() / max(1, uni.sum())

    def blocks(X):                                                           # premultiplied 4x4 block means
        X = np.concatenate([X[..., :3] * (X[..., 3:] / 255.0), X[..., 3:]], -1)
        return X.reshape(H // 4, 4, W // 4, 4, 4).mean((1, 3))
    A4, B4 = blocks(A), blocks(B)
    ub = (A4[..., 3] > 128) | (B4[..., 3] > 128)
    err = np.abs(A4[..., :3] - B4[..., :3]).mean(-1)[ub].mean() if ub.any() else 0.0
    return float(err), float(sil * 100)


def equal(err_sil) -> bool:
    return err_sil[0] < ERR_MAX and err_sil[1] < SIL_MAX


def classify(declared: str, pairs: dict) -> str:
    """the measured class from the three pair measurements {'r0_r1': [err, sil], 'r0_r2': [...], 'r1_r3': [...]} (see the module doc)"""
    e01, e02, e13 = equal(pairs['r0_r1']), equal(pairs['r0_r2']), equal(pairs['r1_r3'])
    if declared == 'c4' and e01 and e02:
        return 'c4'
    if e02 and e13:
        return 'c2'
    return 'none'


def _bake_views(item, ss, tile=256):
    """the four main-layer views of one item, baked exactly like bake_furniture.bake_item (same shadow / footprint / ss)"""
    import bake_lib as bl, spec_reader as sp
    spec = sp.build(item)
    views = {}
    for r in range(4):
        fx, fz = spec.fp if r % 2 == 0 else spec.fp[::-1]
        rect = (-fx / 2, -fz / 2, fx / 2, fz / 2)
        shadow = None if spec.layer in ('wall', 'ceiling') else (('ellipse', .2, .2) if spec.layer == 'tabletop' else ('rect',))
        res = bl.bake_model(spec.pm, 90 * r, ss=ss, tile=tile, shadow=shadow, footprint=rect if shadow and shadow[0] == 'rect' else None, glow=spec.glow,
                            shadow_strength={'rug': .12, 'tabletop': .26}.get(spec.layer, .30), shadow_blur=5)
        views[r] = (res['main'], list(res['meta']['pivot']))
    return views


def measure_item(job):
    item, ss = job
    import spec_reader as sp
    declared = sp.declared_symmetry(item)
    views = _bake_views(item, ss)
    pairs = {}
    for name, ra, rb in PAIRS:
        e, s = compare_views(views[ra][0], views[ra][1], views[rb][0], views[rb][1])
        pairs[name] = [round(e, 2), round(s, 2)]
    return {'id': item['id'], 'template': item['template'], 'rarity': item['rarity'], 'declared': declared, 'class': classify(declared, pairs), 'pairs': pairs}


def measure(items: list, jobs: int = 6, ss: int = 2) -> dict:
    """{id: entry} for every item that DECLARES c4 or c2 (the others are four-view pieces already and are not measured)"""
    import spec_reader as sp
    todo = [i for i in items if sp.declared_symmetry(i) in ('c4', 'c2')]
    out = {}
    with ProcessPoolExecutor(jobs) as ex:
        for m in ex.map(measure_item, [(i, ss) for i in todo], chunksize=1):
            out[m['id']] = m
    return out


def document(res: dict) -> dict:
    n_wrong = sum(1 for m in res.values() if m['class'] != m['declared'])
    return {'v': 1,
            'method': 'r0 r1 r2 r3 of every piece that its template declares c4 or c2, baked like bake_furniture.py (main layer), compared aligned by the pivots; measured by tools/art/features/home/isometric/measure_symmetry.py',
            'rule': f'two views (aligned by the pivots) are equal when silhouette mismatch < {SIL_MAX:g}% (full resolution) and the colour error of the 4x4 block means < {ERR_MAX:g}/255; c4 = r0=r1 and r0=r2; c2 = r0=r2 and r1=r3; otherwise none (four true views)',
            'declared_but_asymmetric': n_wrong,
            'items': {i: {k: m[k] for k in ('template', 'rarity', 'declared', 'class', 'pairs')} for i, m in sorted(res.items())}}


def dumps(doc: dict) -> str:
    """the document with one line per item (the nested pair lists stay on that line)"""
    head = {k: v for k, v in doc.items() if k != 'items'}
    lines = [json.dumps(head, indent=1)[:-2] + ',', ' "items": {']
    items = list(doc['items'].items())
    for n, (i, e) in enumerate(items):
        lines.append(f'  {json.dumps(i)}: {json.dumps(e)}' + (',' if n < len(items) - 1 else ''))
    lines += [' }', '}']
    return '\n'.join(lines) + '\n'


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--spec', default=str(homepaths.SPECS / 'furniture_art_spec.json'))
    ap.add_argument('--only', nargs='*'); ap.add_argument('--jobs', type=int, default=6); ap.add_argument('--ss', type=int, default=2)
    ap.add_argument('--write', metavar='FILE', nargs='?', const=str(DEFAULT_FILE)); ap.add_argument('--check', metavar='FILE', nargs='?', const=str(DEFAULT_FILE))
    a = ap.parse_args()
    import spec_reader as sp
    items = sp.load(a.spec)
    if a.only:
        items = [i for i in items if i['id'] in a.only]
    t0 = time.time()
    res = measure(items, a.jobs, a.ss)
    keep = sum(1 for m in res.values() if m['class'] == m['declared'])
    print(f'{len(res)} pieces declare c4 or c2: {keep} are symmetric as declared, {len(res) - keep} are NOT ({time.time() - t0:.0f}s)')
    for m in sorted(res.values(), key=lambda m: (m['class'] == m['declared'], m['id'])):
        flag = '   ' if m['class'] == m['declared'] else 'NO '
        print(f"  {flag}{m['id']:<28} {m['rarity']:<9} declared {m['declared']:<3} measured {m['class']:<4} " + '  '.join(f"{k} {v[0]:5.1f}/{v[1]:5.2f}%" for k, v in m['pairs'].items()))
    if a.write:
        Path(a.write).write_text(dumps(document(res))); print('wrote', a.write)
    if a.check:
        have = {i: e['class'] for i, e in json.loads(Path(a.check).read_text())['items'].items()}
        want = {i: m['class'] for i, m in res.items()}
        same = have == want if not a.only else all(have.get(i) == c for i, c in want.items())
        print('check:', 'symmetry_measured.json equals the measured classes' if same else f'MISMATCH {sorted(i for i in set(have) | set(want) if have.get(i) != want.get(i))}')
        raise SystemExit(0 if same else 1)


if __name__ == '__main__':
    main()
