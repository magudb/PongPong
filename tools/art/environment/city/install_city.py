#!/usr/bin/env python3
"""Install the baked city set (stage masters) into the project: lossless WebP sprites + props.json under assets/iso_props/city/, the two backdrops as
assets/backdrops/treetop_sky.webp / treetop_far.webp.  It writes ONLY the paths package V5-art-city owns:

    assets/iso_props/city/**        assets/backdrops/treetop_*

and refuses to write anywhere else (NEVER touches any pre-existing asset: Codex restyles those).  Sprites are LOSSLESS WebP (the contract: props lossless, mipmaps
on by the project default).  The two backdrop layers (sky stretched, far magnified by the parallax) get a hand-written `.import` stub WITHOUT mipmaps, written
BEFORE the first import (Godot honours it; it adds the uid): that is the 4.1 MB the memory budget needs (check art_city.vram_budget reads the flags).

  python tools/art/environment/city/install_city.py --stage DIR [--repo REPO] [--dry-run]
"""
from __future__ import annotations
import argparse, json, sys
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parents[1] / 'core'))
import artpaths     # noqa: E402

NO_MIPS_STUB = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate=false
process/fix_alpha_border=true
"""
BACKDROPS = ('treetop_sky', 'treetop_far')


def save_webp(src: Path, dst: Path) -> int:
    im = Image.open(src).convert('RGBA')
    im.save(dst, 'WEBP', lossless=True, quality=100, method=4, exact=True)
    return dst.stat().st_size


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('  python')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--stage', required=True)
    ap.add_argument('--repo', default=str(HERE.parents[3]))
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()
    stage = Path(a.stage)
    repo = Path(a.repo).resolve()
    masters = stage / 'masters'
    src = masters / 'iso_props' / 'city'
    dst = repo / 'assets' / 'iso_props' / 'city'
    bd = repo / 'assets' / 'backdrops'
    props = json.loads((src / 'props.json').read_text())
    props.pop('_results', None)
    total = 0
    written = []
    dst.mkdir(parents=True, exist_ok=True) if not a.dry_run else None
    keep = {'props.json'}
    for k, e in list(props.items()):
        if k.startswith('_'):
            continue
        f = e['file']
        wname = f[:-4] + '.webp'
        keep.add(wname)
        e['file'] = wname
        if not a.dry_run:
            total += save_webp(src / f, dst / wname)
        written.append(wname)
    if not a.dry_run:
        (dst / 'props.json').write_text(json.dumps(props, indent=1))
    # backdrops
    for b in BACKDROPS:
        p = masters / 'backdrops' / f'{b}.png'
        if not p.exists():
            raise SystemExit(f'install_city: {p} is missing (bake the backdrops first)')
        out = bd / f'{b}.webp'
        assert out.name.startswith('treetop_')                           # ownership guard: assets/backdrops/treetop_*
        if not a.dry_run:
            total += save_webp(p, out)
            imp = bd / f'{b}.webp.import'
            if not imp.exists() or 'mipmaps/generate=false' not in imp.read_text():
                if not imp.exists():
                    imp.write_text(NO_MIPS_STUB)
                else:
                    t = imp.read_text().replace('mipmaps/generate=true', 'mipmaps/generate=false')
                    imp.write_text(t)
        written.append(f'backdrops/{b}.webp')
    # stale files of the owned folder (a sprite that is no longer in the set), with their .import
    stale = []
    if dst.exists():
        for f in sorted(dst.iterdir()):
            base = f.name[:-7] if f.name.endswith('.import') else f.name
            if base not in keep and f.name != 'props.json' and not f.name.endswith('.uid'):
                stale.append(f.name)
                if not a.dry_run:
                    f.unlink()
    print('installed %d files (%.1f MB lossless WebP)%s; stale removed: %s' % (len(written), total / 1e6, ' [dry run]' if a.dry_run else '', stale or 'none'))


if __name__ == '__main__':
    main()
