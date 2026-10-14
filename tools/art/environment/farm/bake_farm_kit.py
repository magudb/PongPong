#!/usr/bin/env python3
"""bake_farm_kit.py - bakes the ten farm-only props of the treetop farm (package N03-farm-art) with P22's prop baker (bake_props.py): soft CG, camera 36 degrees / az 45,
87.074 px per metre, warm pack outline, ground-origin pivot, soft contact shadow where the spec asks for one.

  python tools/art/environment/farm/bake_farm_kit.py [ids...] [--out DIR] [--ss 3] [--list]

Default out: <N03 stage>/masters/iso_props_farm (tools/art/_stage/n03, gitignored and hidden from Godot).  Writes <id>.png and props.json (the manifest ArtCatalog reads once it is
installed as assets/iso_props/farm/props.json: {id: {file, size, pivot, footprint, elev}}).  Prints size, pivot and seconds of every prop and compares them with the contract table
(FARM_CONTRACT of props_farm.py = the measured prototype, design3/farm/art/out/art_budget.txt); a deviation is printed as DEVIATION and makes the exit code 1.
This script only ever writes under --out: it never touches assets/ (install_farm.py does, for its allow-list only) and never bakes a P22 id.
"""
from __future__ import annotations
import argparse
import json
import sys
import time
from pathlib import Path

import farm_common as fc                       # noqa: E402  (before prepare_path: this folder leaves sys.path there)

kit = fc.load_kit()
import bake_props as bp                         # noqa: E402  P22's baker (its builders are loaded lazily by load_registry(), which we never call)
import static_render as sr                      # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('  python ')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('names', nargs='*')
    ap.add_argument('--out', default=None)
    ap.add_argument('--ss', type=int, default=3)
    ap.add_argument('--list', action='store_true')
    ap.add_argument('--stage', default=None)
    a = ap.parse_args()
    if a.list:
        for n in kit.FARM_KIT:
            print(n, kit.FARM_CONTRACT[n])
        return 0
    out = Path(a.out) if a.out else fc.masters(fc.stage_root(a.stage))['props']
    out.mkdir(parents=True, exist_ok=True)
    names = a.names or list(kit.FARM_KIT)
    unknown = [n for n in names if n not in kit.FARM_KIT]
    if unknown:
        raise SystemExit(f'ERROR: {unknown} are not farm-kit ids (this package bakes only {", ".join(kit.FARM_KIT)}; the P22 props are never baked here)')
    metap = out / 'props.json'
    meta = json.loads(metap.read_text()) if metap.exists() else {}
    meta['_contract'] = {'tile': [sr.TILE_W, sr.TILE_H], 'tile_edge_m': round(sr.TILE_M, 4), 'px_per_m': round(sr.PX_PER_M, 3),
                         'camera': 'orthographic, az 45, elevation 36', 'pivot': 'ground origin (footprint centre), px from PNG top-left',
                         'files': 'relative to this json', 'package': 'N03-farm-art',
                         'import': 'compress/mode=2 (S3TC), mipmaps on - written by tools/art/environment/farm/write_farm_imports.py'}
    bad = 0
    t_all = time.time()
    for n in names:
        t0 = time.time()
        m, _ = bp.bake_prop(n, kit.FARM_KIT[n](), out, a.ss)
        m.pop('_origin_shift', None)
        meta[n] = m
        want = kit.FARM_CONTRACT[n]
        got = (m['size'][0], m['size'][1], m['pivot'][0], m['pivot'][1], m['footprint'][0], m['footprint'][1])
        flag = 'ok' if tuple(got) == tuple(want) else 'DEVIATION from the contract %s' % (want,)
        bad += tuple(got) != tuple(want)
        print('%-14s %dx%d pivot (%d,%d) footprint %dx%d  %.1fs  %s' % ((n,) + got + (time.time() - t0, flag)), flush=True)
    metap.write_text(json.dumps(dict(sorted(meta.items(), key=lambda kv: (kv[0] != '_contract', kv[0]))), indent=1))
    print('baked %d prop(s) in %.1f s -> %s' % (len(names), time.time() - t_all, out))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
