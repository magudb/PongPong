#!/usr/bin/env python3
"""install_farm.py - copy the baked farm kit from the N03 stage to the project, ADDITIVELY and to an allow-list only (package N03-farm-art).

  python tools/art/environment/farm/install_farm.py [--stage DIR] [--repo DIR] [--dry-run]

Destinations (everything else is refused):
  assets/iso_props/farm/<ten ids>.png + props.json        (a folder only this package writes: ArtCatalog reads iso_props/*/props.json)
  assets/backdrops/farm_far.webp, farm_canopy.webp         NEVER farm_sky.* (Codex's painted farm_sky.png is the farm sky; a .webp here would shadow it - lead amendment M1a)
  assets/iso_tiles/field_grass.png, tiles_farm.json        (ArtCatalog reads every tiles_*.json next to tiles.json)
Codex guardrail: a destination that is not on the list is never written, and nothing is ever deleted; an existing file of the list is overwritten only when its bytes differ.
Godot's `.import` files are written by write_farm_imports.py (stubs) and pulled back from a clone after the first import (impl/tools/pull_meta.sh).
"""
from __future__ import annotations
import argparse
import filecmp
import shutil
import sys
from pathlib import Path

import farm_common as fc                       # noqa: E402


def plan(stage: Path, repo: Path) -> list:
    m = fc.masters(stage)
    pairs = []
    for i in fc.KIT_IDS:
        pairs.append((m['props'] / f'{i}.png', repo / 'assets/iso_props/farm' / f'{i}.png'))
    pairs.append((m['props'] / 'props.json', repo / 'assets/iso_props/farm/props.json'))
    for f in fc.BACKDROP_FILES:
        pairs.append((m['backdrops'] / f, repo / 'assets/backdrops' / f))
    for f in fc.TILE_FILES:
        pairs.append((m['tiles'] / f, repo / 'assets/iso_tiles' / f))
    return pairs


def check_allowed(dst: Path, repo: Path) -> None:
    rel = dst.resolve().relative_to(repo.resolve()).as_posix()
    ok = (rel.startswith('assets/iso_props/farm/') or rel in ('assets/backdrops/farm_far.webp', 'assets/backdrops/farm_canopy.webp',
                                                              'assets/iso_tiles/field_grass.png', 'assets/iso_tiles/tiles_farm.json'))
    if not ok or 'farm_sky' in rel:
        raise SystemExit('ERROR: refusing to write %s (not on the N03 allow-list; this package is strictly additive)' % rel)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('  python ')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--stage', default=None)
    ap.add_argument('--repo', default=str(fc.REPO))
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()
    repo = Path(a.repo)
    if not (repo / 'project.godot').exists():
        raise SystemExit('ERROR: %s is not a Godot project folder' % repo)
    stage = fc.stage_root(a.stage)
    pairs = plan(stage, repo)
    missing = [str(s) for s, _ in pairs if not s.is_file()]
    if missing:
        raise SystemExit('ERROR: not baked yet (run build_farm.sh): %s' % missing)
    n_copy = n_same = 0
    for src, dst in pairs:
        check_allowed(dst, repo)
        if dst.exists() and filecmp.cmp(src, dst, shallow=False):
            n_same += 1
            continue
        n_copy += 1
        if not a.dry_run:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
    print('install_farm%s: %d file(s) copied, %d identical -> %s' % (' (dry run)' if a.dry_run else '', n_copy, n_same, repo / 'assets'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
