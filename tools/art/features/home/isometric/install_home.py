#!/usr/bin/env python3
"""Install the exported A1 tree into the repo - ONLY the paths package A1-art-home owns (tools/art/export/install_assets.py of P08 is limited to the six plan-6.2 dirs).

  python tools/art/features/home/isometric/install_home.py --stage <stage>/assets [--repo .] [--dry-run] [--keep-noise]

Owned destinations (everything else is refused, exit 2, nothing written):
  assets/iso_props/{home,furniture,interior,fx,features}/   mirrored: files that are not in the stage are removed together with their .import/.uid
  assets/icons/home/                                        mirrored
  assets/data/home/                                         mirrored (rooms/room_tNN.json)
  assets/iso_tiles/floor_*.png (+ .import) and tiles_floors.json     only these files of the folder; the folder itself belongs to P22
  lua/config/props_features.lua
Godot-generated `.import` / `.uid` files that already exist in the repo are kept and never overwritten (they hold the uid); a new stub from the stage is copied, and every installed
texture is then held to the project's import policy (tools/import/write_import_stubs.py, review REND-03: a stale .import gets the preset's params, its uid kept).
A file a later art pack supersedes (tools/art/drawn/fixture_recipes.json, review REND-10: the painted pack draws that id) is not installed.
"""
from __future__ import annotations
import argparse, shutil, sys
from pathlib import Path
import homepaths
sys.path.insert(0, str(homepaths.REPO / 'tools/import'))
sys.path.insert(0, str(homepaths.ART / 'drawn'))
from write_import_stubs import ensure_policy   # noqa: E402  the one texture import policy
import drawn_art                               # noqa: E402

DIRS = ['iso_props/home', 'iso_props/furniture', 'iso_props/interior', 'iso_props/fx', 'iso_props/features', 'icons/home', 'data/home']
META = ('.import', '.uid')


def is_meta(p: Path) -> bool:
    return p.suffix in META


KEEP_NOISE = False


def renderer_noise(a: Path, b: Path) -> bool:
    """True when two WebP images are the same bake up to renderer noise: same size, mean abs difference < 0.8/255 over RGBA, and fewer than 0.2 % of the pixels differ by more than 24 in a
    channel.  (The VTK bake is not byte-deterministic: two runs of the same code differ by a few levels on a few pixels; a changed colour, shape or pivot is orders of magnitude above this.)"""
    if a.suffix != '.webp' or b.suffix != '.webp':
        return False
    from PIL import Image
    import numpy as np
    A, B = Image.open(a).convert('RGBA'), Image.open(b).convert('RGBA')
    if A.size != B.size:
        return False
    d = np.abs(np.asarray(A, np.int16) - np.asarray(B, np.int16))
    return float(d.mean()) < 0.8 and float((d.max(-1) > 24).mean()) < 0.002


def same(a: Path, b: Path) -> bool:
    if not (a.exists() and b.exists()):
        return False
    if a.stat().st_size == b.stat().st_size and a.read_bytes() == b.read_bytes():
        return True
    return KEEP_NOISE and renderer_noise(a, b)


def superseded(path: Path, repo_assets: Path) -> bool:
    """`path` (or the texture of an .import) is a copy a later art pack supersedes: the painted pack draws that id, the copy is not kept."""
    texture = path.with_suffix('') if path.suffix == '.import' else path
    return drawn_art.superseded(texture.resolve(), repo_assets.parent)


def plan_dir(stage: Path, repo_assets: Path, rel: str):
    """(copies, removals) that make repo_assets/rel the mirror of stage/rel"""
    src, dst = stage / rel, repo_assets / rel
    copies, removals = [], []
    want = {p.relative_to(src) for p in src.rglob('*') if p.is_file() and not superseded(dst / p.relative_to(src), repo_assets)}
    for r in sorted(want):
        s, d = src / r, dst / r
        if is_meta(s) and d.exists():
            continue                                                  # Godot's own import file wins
        if not same(s, d):
            copies.append((s, d))
    if dst.exists():
        for p in sorted(dst.rglob('*')):
            if not p.is_file():
                continue
            r = p.relative_to(dst)
            if r in want:
                continue
            if is_meta(p) and (r.with_suffix('') if p.suffix == '.uid' else r.with_name(r.name[:-len('.import')])) in want:
                continue                                              # meta of a file that stays (a .gd.uid of a stage file never exists here)
            removals.append(p)
    return copies, removals


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--stage', required=True); ap.add_argument('--repo', default=str(homepaths.REPO)); ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--keep-noise', action='store_true', help='keep an installed WebP whose new bake differs by renderer noise only (the bake is not byte-deterministic): a clean git diff')
    a = ap.parse_args()
    global KEEP_NOISE
    KEEP_NOISE = a.keep_noise
    stage = Path(a.stage).resolve(); repo = Path(a.repo).resolve(); ra = repo / 'assets'
    if not (repo / 'project.godot').exists():
        raise SystemExit(f'install_home: {repo} is not a Godot project (no project.godot)')
    if not (stage / 'iso_props' / 'home' / 'home.json').exists():
        raise SystemExit(f'install_home: {stage} is not an A1 export tree (no iso_props/home/home.json)')
    if stage == ra or ra in stage.parents:
        raise SystemExit('install_home: the stage must not be inside assets/')
    copies, removals = [], []
    for rel in DIRS:
        c, r = plan_dir(stage, ra, rel); copies += c; removals += r
    # floors: only floor_* and tiles_floors.json of assets/iso_tiles
    for p in sorted((stage / 'iso_tiles').iterdir()):
        if not (p.name.startswith('floor_') or p.name == 'tiles_floors.json'):
            raise SystemExit(f'install_home: refusing {p} (not a floor_* file of A1)')
        d = ra / 'iso_tiles' / p.name
        if is_meta(p) and d.exists(): continue
        if not same(p, d): copies.append((p, d))
    lua_src = stage / 'lua' / 'config' / 'props_features.lua'
    if lua_src.exists() and not same(lua_src, repo / 'lua' / 'config' / 'props_features.lua'):
        copies.append((lua_src, repo / 'lua' / 'config' / 'props_features.lua'))
    owned_roots = [ra / d for d in DIRS] + [ra / 'iso_tiles', repo / 'lua' / 'config']
    for s, d in copies:                                               # the write guard: nothing outside the owned roots, ever
        if not any(root == d.parent or root in d.parents for root in owned_roots):
            raise SystemExit(f'install_home: {d} is outside the A1 paths')
    for p in removals:
        if not any(root in p.parents for root in [ra / d for d in DIRS]):
            raise SystemExit(f'install_home: refusing to delete {p}')
    print(f'install_home: {len(copies)} file(s) to write, {len(removals)} stale file(s) to remove' + (' (dry run)' if a.dry_run else ''))
    if a.dry_run:
        return
    for s, d in copies:
        d.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(s, d)
    for p in removals:
        p.unlink()
    for s, d in copies:
        if d.suffix in ('.png', '.webp'):
            ensure_policy(d, root=repo)
    for rel in DIRS:                                                  # prune empty dirs
        for p in sorted((ra / rel).rglob('*'), reverse=True):
            if p.is_dir() and not any(p.iterdir()):
                p.rmdir()
    print('install_home: done')


if __name__ == '__main__':
    main()
