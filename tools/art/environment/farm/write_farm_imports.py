#!/usr/bin/env python3
"""write_farm_imports.py - the Godot `.import` stubs of the farm kit (package N03-farm-art, TOWNS addendum TE9 / DT29) and the audit that keeps them honest.

Why this package writes its own stubs: tools/import/write_import_stubs.py (P05) covers only the character sheets, the tile atlases and the wardrobe layers, so assets/iso_props/**
and assets/backdrops/** would stay lossless (kit 65.5 MB; the city peak 357.6 MB).  A hand-written minimal stub is honoured on the very first import in Godot 4.7.2 (a 1227 x 2405
image with compress/mode=2 imports to a ~3.95 MB .s3tc.ctex).  The stub is the same minimal one as the character sheets:

  the ten props (assets/iso_props/farm/<id>.png)      [remap] importer="texture" type="CompressedTexture2D"
  farm_far.webp, farm_canopy.webp (assets/backdrops)  [params] compress/mode=2  compress/high_quality=false  mipmaps/generate=true  process/fix_alpha_border=true
  field_grass.png (assets/iso_tiles)                  the TILE stub of P05 / P08: compress/mode=0  mipmaps/generate=false  process/fix_alpha_border=true  (periodic cells bleed at mip >= 1)

(project.godot already has import_s3tc_bptc=true; BPTC does not exist in the Compatibility renderer on macOS, S3TC does.)  Godot adds uid / path / dest_files itself on the first
import; an existing `.import` that already carries the wanted preset (the complete file Godot wrote) is never touched, so the Godot-assigned uid survives.

  python tools/art/environment/farm/write_farm_imports.py            write every missing / stale stub
  python tools/art/environment/farm/write_farm_imports.py --check    audit: exit 1 on ANY mismatch (and on a farm_sky.* file, which this package must never ship)
  options: --root DIR (another project root, tests)
"""
from __future__ import annotations
import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]

KIT_IDS = ['trunk_giant_a', 'trunk_giant_b', 'trunk_under_a', 'trunk_under_b', 'tool_shed', 'shipping_bin', 'stake_sign', 'rope_stake_x', 'rope_stake_z', 'build_stake']

VRAM_STUB = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
mipmaps/generate=true
process/fix_alpha_border=true
"""

TILE_STUB = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate=false
process/fix_alpha_border=true
"""

VRAM_WANT = {'compress/mode': '2', 'compress/high_quality': 'false', 'mipmaps/generate': 'true'}
TILE_WANT = {'compress/mode': '0', 'mipmaps/generate': 'false'}


def targets(root: Path) -> list:
    """[(asset path, stub text, wanted params)] of everything this package ships."""
    out = []
    for i in KIT_IDS:
        out.append((root / 'assets/iso_props/farm' / f'{i}.png', VRAM_STUB, VRAM_WANT))
    for f in ('farm_far.webp', 'farm_canopy.webp'):
        out.append((root / 'assets/backdrops' / f, VRAM_STUB, VRAM_WANT))
    out.append((root / 'assets/iso_tiles/field_grass.png', TILE_STUB, TILE_WANT))
    return out


def params_of(imp: Path) -> dict:
    out = {}
    section = ''
    for line in imp.read_text(encoding='utf-8', errors='replace').splitlines():
        line = line.strip()
        m = re.match(r'^\[(.+)\]$', line)
        if m:
            section = m.group(1)
        elif section == 'params' and '=' in line:
            k, v = line.split('=', 1)
            out[k.strip()] = v.strip()
    return out


def problems(asset: Path, want: dict) -> list:
    imp = asset.with_name(asset.name + '.import')
    if not asset.is_file():
        return ['%s: the asset itself is missing' % asset.name]
    if not imp.is_file():
        return ['%s: no .import (write the stub BEFORE the first import)' % asset.name]
    p = params_of(imp)
    return ['%s: %s=%s, wanted %s' % (asset.name, k, p.get(k), v) for k, v in want.items() if p.get(k) != v]


def audit(root: Path) -> list:
    bad = []
    for asset, _stub, want in targets(root):
        bad += problems(asset, want)
    for sky in (root / 'assets/backdrops').glob('farm_sky*'):
        if sky.suffix == '.webp' or sky.name.endswith('.webp.import'):
            bad.append('%s: this package must never ship a farm_sky.webp (it would shadow the painted farm_sky.png)' % sky.name)
    return bad


def write(root: Path, quiet: bool = False) -> int:
    n = 0
    for asset, stub, want in targets(root):
        if not asset.is_file():
            if not quiet:
                print('skip (asset not installed):', asset.name)
            continue
        imp = asset.with_name(asset.name + '.import')
        if imp.is_file() and not problems(asset, want):
            continue
        imp.write_text(stub)
        n += 1
        if not quiet:
            print('wrote', imp.relative_to(root))
    return n


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('  python ')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--root', default=str(REPO))
    ap.add_argument('-q', '--quiet', action='store_true')
    a = ap.parse_args()
    root = Path(a.root)
    if a.check:
        bad = audit(root)
        for b in bad:
            print('FAIL', b)
        print('write_farm_imports --check: %s' % ('%d problem(s)' % len(bad) if bad else 'ok (%d files carry their preset)' % len(targets(root))))
        return 1 if bad else 0
    n = write(root, a.quiet)
    print('write_farm_imports: %d stub(s) written' % n)
    return 0


if __name__ == '__main__':
    sys.exit(main())
