#!/usr/bin/env python3
"""Which asymmetric furniture pieces may be drawn as a MIRROR of the other rotation?  (RV-A5; lifted from FR/tools/measure_mirror_reference.py)

ROTATION POLICY: all 130 items ship TRUE bakes of every distinct view (404 main sprites + 38 float layers; the symmetry class of each piece is MEASURED, measure_symmetry.py).  Mirroring (flip_h of r0 for r1, flip_h of r2 for r3) is only a DISK
FALLBACK, and only for the ids of specs/mirror_ok.json, which THIS tool generates with a measured rule - it is never decided by template name (the first plan
whitelisted whole templates from an 11-piece sample and was wrong for chest_snail 34/255, chair_stump, sofa_leaf, throne_root, bed_rose_single).

THE RULE (all of it, for every piece with sym == 'none', i.e. four distinct views):
    mean RGB error  < 8/255   AND   silhouette mismatch < 1 %      on BOTH pairs   flip_h(r0) vs r1   and   flip_h(r2) vs r3
    never unique / legendary (keepsakes are one per save and carry the art budget)
    never patterned fabric (stripe, quilt or damask cloth: a mirrored pattern is a different pattern)
The error is measured over the pixels where both sprites are opaque (alpha > 200) after the pivots are aligned; the silhouette mismatch is
xor(alpha > 128) / union(alpha > 128).

  python measure_mirror.py [--dir assets/iso_props/furniture] [--spec FILE] [--write specs/mirror_ok.json] [--check] [--reference specs/mirror_ok.measured.json]

--dir is a folder with furniture.json + the exported WebP sprites (default: the repo's assets/iso_props/furniture).  --write stores the measured list,
--check exits 1 when the stored list is not exactly the measured one (the test art_home.mirror_ok_measured does the same inside Godot).
"""
from __future__ import annotations
import argparse, json, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageOps
import homepaths

MEAN_MAX = 8.0            # mean RGB error on the 0..255 scale
SIL_MAX = 1.0             # silhouette mismatch in percent
PATTERNED = {'stripe', 'quilt', 'damask'}       # fabric painters whose pattern would be mirrored (furniture_traetoppen.FABRICS)
KEEPSAKES = ('unique', 'legendary')


def _canvas(im, piv, W, H, cx, cy):
    c = Image.new('RGBA', (W, H), (0, 0, 0, 0)); c.alpha_composite(im, (cx - piv[0], cy - piv[1])); return c


def compare(root: Path, entry: dict, ra: int, rb: int):
    """(mean RGB error /255, silhouette mismatch %) of flip_h(r<ra>) against the true r<rb> of one item (entry = furniture.json item)"""
    ea, eb = entry['rot'][str(ra)], entry['rot'][str(rb)]
    a = Image.open(root / ea['file']).convert('RGBA'); pa = list(ea['pivot'])
    a = ImageOps.mirror(a); pa[0] = a.width - pa[0]
    b = Image.open(root / eb['file']).convert('RGBA'); pb = list(eb['pivot'])
    # laid out from the pivots (a wall or ceiling piece carries its pivot BELOW the sprite: a canvas centred on the image would place it at a negative offset = nothing)
    cx = max(pa[0], pb[0]) + 8; cy = max(pa[1], pb[1]) + 8
    W = cx + max(a.width - pa[0], b.width - pb[0], 0) + 8; H = cy + max(a.height - pa[1], b.height - pb[1], 0) + 8
    A = np.asarray(_canvas(a, pa, W, H, cx, cy), np.float32); B = np.asarray(_canvas(b, pb, W, H, cx, cy), np.float32)
    both = (A[..., 3] > 200) & (B[..., 3] > 200); uni = (A[..., 3] > 128) | (B[..., 3] > 128)
    d = np.abs(A[..., :3] - B[..., :3]).mean(-1)
    sil = np.logical_xor(A[..., 3] > 128, B[..., 3] > 128).sum() / max(1, uni.sum())
    return float(d[both].mean()) if both.any() else 0.0, float(sil * 100)


def fabric_pattern(item: dict) -> str:
    import furniture_traetoppen as ft
    return ft.FABRICS[item['style'].get('fabric', 'natur')][1]


def measure(root: Path, spec_items: list) -> dict:
    """Run the rule over the folder `root` (furniture.json + sprites).  Returns {'ok': [ids], 'rejected': [{id, template, rarity, mean_err[2], sil_pct[2], reasons[]}], 'measured': n}"""
    meta = json.loads((root / 'furniture.json').read_text())['items']
    ok, rejected, n = [], [], 0
    for it in spec_items:
        m = meta.get(it['id'])
        if m is None or m['sym'] != 'none':
            continue
        n += 1
        a = compare(root, m, 0, 1); b = compare(root, m, 2, 3)
        reasons = []
        if it['rarity'] in KEEPSAKES:
            reasons.append('keepsake')
        if fabric_pattern(it) in PATTERNED:
            reasons.append(f"patterned fabric {it['style'].get('fabric', 'natur')} ({fabric_pattern(it)})")
        if max(a[0], b[0]) >= MEAN_MAX:
            reasons.append(f'mean_err {max(a[0], b[0]):.1f}/255 >= {MEAN_MAX:g}')
        if max(a[1], b[1]) >= SIL_MAX:
            reasons.append(f'silhouette_mismatch {max(a[1], b[1]):.1f}% >= {SIL_MAX:g}%')
        if reasons:
            rejected.append({'id': it['id'], 'template': it['template'], 'rarity': it['rarity'], 'mean_err': [round(a[0], 1), round(b[0], 1)],
                             'sil_pct': [round(a[1], 2), round(b[1], 2)], 'reasons': reasons})
        else:
            ok.append(it['id'])
    return {'ok': ok, 'rejected': rejected, 'measured': n}


def document(res: dict) -> dict:
    return {'v': 1, 'method': 'flip_h(r0) vs true r1 and flip_h(r2) vs true r3 of the 130-item bake with true rotations, measured on the exported WebP sprites by tools/art/features/home/isometric/measure_mirror.py',
            'rule': f'mean RGB error < {MEAN_MAX:g}/255 and silhouette mismatch < {SIL_MAX:g}% on BOTH pairs, never unique/legendary, never patterned fabric (stripe, quilt, damask)',
            'measured_asymmetric_items': res['measured'], 'mirror_ok': res['ok'], 'rejected': res['rejected'],
            'note': 'default policy is TRUE baked r1/r3 for everything; this list is only a disk fallback (export_home.py --mirror-fallback drops the r1/r3 files of these ids)'}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--dir', default=str(homepaths.REPO / 'assets' / 'iso_props' / 'furniture'))
    ap.add_argument('--spec', default=str(homepaths.SPECS / 'furniture_art_spec.json'))
    ap.add_argument('--write', metavar='FILE'); ap.add_argument('--check', metavar='FILE', nargs='?', const=str(homepaths.SPECS / 'mirror_ok.json'))
    ap.add_argument('--update-manifest', action='store_true', help='update optional mirror fallback flags to match the measured artwork; keep every true rotation')
    ap.add_argument('--reference', default=str(homepaths.SPECS / 'mirror_ok.measured.json'))
    a = ap.parse_args()
    import spec_reader as sp
    items = sp.load(a.spec)
    res = measure(Path(a.dir), items)
    print(f"{res['measured']} asymmetric pieces measured: {len(res['ok'])} may mirror, {len(res['rejected'])} may not")
    for r in res['rejected']:
        print('  no ', f"{r['id']:<26} {r['rarity']:<9} err {r['mean_err']} sil% {r['sil_pct']}  {'; '.join(r['reasons'])}")
    ref = Path(a.reference)
    if ref.exists():
        want = set(json.loads(ref.read_text())['mirror_ok']); got = set(res['ok'])
        print(f'  reference of the review (FR/artifacts/mirror_ok.measured.json): {len(want)} ids; here {len(got)}; only in reference {sorted(want - got)}; only here {sorted(got - want)}')
    if a.write:
        Path(a.write).write_text(json.dumps(document(res), indent=1) + '\n'); print('wrote', a.write)
    if a.update_manifest:
        manifest = Path(a.dir) / 'furniture.json'
        doc = json.loads(manifest.read_text())
        allowed = set(res['ok'])
        for iid, entry in doc['items'].items():
            if iid in allowed:
                entry['mirror_ok'] = True
            else:
                entry.pop('mirror_ok', None)
        manifest.write_text(json.dumps(doc, indent=1) + '\n')
        print('updated', manifest)
    if a.check:
        have = json.loads(Path(a.check).read_text())['mirror_ok']
        same = sorted(have) == sorted(res['ok'])
        print('check:', 'mirror_ok.json equals the measured list' if same else f'MISMATCH stored {len(have)} measured {len(res["ok"])}')
        raise SystemExit(0 if same else 1)


if __name__ == '__main__':
    main()
