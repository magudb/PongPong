#!/usr/bin/env python3
"""Copy the staged, game-ready tree to the contract paths of the project (plan 6.2) - and to NOTHING else.

  python tools/art/export/install_assets.py [--stage tools/art/_stage] [--classes characters,portraits,tiles,props,icons,keyart]
                                            [--only ID ...] [--only-icons NAME ...] [--dry-run]

Allowed destinations (artcontract.CONTRACT_DIRS), all under <project>/assets:
  isometric_characters/<new id>/   clip sheets, portrait.webp, animations.json, <clip>.webp.import   + manifest_traetoppen.json (merged)
  portraits/<id>.webp              bust portraits of the 12 pack characters
  iso_tiles/   iso_props/   icons/items/   ui/keyart/
Rules, all checked BEFORE the first file is written (any violation aborts with exit code 2 and nothing is copied):
  * the 12 pack characters (bat cat bear rabbit fairy monkey capybara fox raccoon penguin hedgehog frog) are never touched;
    only the head-and-shoulders busts of the pack go to assets/portraits/<id>.webp.  The guard is CASE-INSENSITIVE (a staged
    `Fox` / `FOX` is the shipped `fox` on a default APFS volume) and also compares the folders themselves (samefile); a character
    folder name must be [a-z0-9_]+
  * every destination is resolved and must stay inside assets/<contract dir>; anything else in the stage tree is refused
  * a character folder is mirrored: new/changed files are copied, stale clip sheets of that folder (and their .import) are removed;
    an existing .import that already carries the wanted preset keeps its Godot-assigned uid
  * a copy a later art pack supersedes (tools/art/drawn/fixture_recipes.json, review REND-10: the painted pack draws that id) is not installed
Prints what it did; --dry-run prints the plan only.
"""
import argparse, filecmp, json, shutil, sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1] / 'core'))
import artpaths                       # noqa: E402
import artcontract as ac              # noqa: E402
sys.path.append(str(Path(__file__).resolve().parent))
import import_stubs                   # noqa: E402
sys.path.append(str(Path(__file__).resolve().parents[1] / 'drawn'))
import drawn_art                      # noqa: E402

CLASS_DIRS = {'characters': 'isometric_characters', 'portraits': 'portraits', 'tiles': 'iso_tiles', 'props': 'iso_props',
              'icons': 'icons/items', 'keyart': 'ui/keyart'}
assert set(CLASS_DIRS.values()) == set(ac.CONTRACT_DIRS), 'CLASS_DIRS and artcontract.CONTRACT_DIRS drifted apart'


class InstallError(Exception):
    pass


def inside(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def same(a: Path, b: Path) -> bool:
    return b.exists() and a.stat().st_size == b.stat().st_size and filecmp.cmp(a, b, shallow=False)


def plan(stage_assets: Path, repo: Path, classes, only, only_icons=None):
    """Return a list of (src, dst) file copies and a list of removals; raise InstallError on any contract violation."""
    assets = repo / 'assets'
    copies, removals, errors = [], [], []
    manifest_ids = []

    def add(src: Path, dst: Path, cls_dir: str):
        root = assets / cls_dir
        if not inside(dst, root):
            errors.append(f'{src} would land outside {root}: {dst}')
        else:
            copies.append((src, dst))

    # nothing in the stage tree may sit outside the contract dirs we know (reported, not copied)
    for cls in classes:
        sub = CLASS_DIRS[cls]
        s = stage_assets / sub
        if not s.is_dir():
            continue
        if cls == 'characters':
            for d in sorted(p for p in s.iterdir() if p.is_dir()):
                if only and d.name not in only:
                    continue
                kind = ac.classify_id(d.name)
                if kind == 'pack':
                    errors.append(f'refusing to install pack character "{d.name}" (the 12 pack characters are never touched, whatever the '
                                  f'letter case; its bust portrait goes to assets/portraits via the portraits class)')
                    continue
                if kind == 'invalid':
                    errors.append(f'refusing character folder "{d.name}": ids are lower-case ASCII [a-z0-9_]+ (folder names)')
                    continue
                dest = assets / sub / d.name
                alias = next((pid for pid in ac.PACK_IDS if dest.exists() and (assets / sub / pid).exists()
                              and dest.samefile(assets / sub / pid)), None)
                if alias:                              # belt and braces: any other way a name can reach a pack folder
                    errors.append(f'refusing "{d.name}": it is the same folder as pack character "{alias}"')
                    continue
                names = set()
                for f in sorted(p for p in d.rglob('*') if p.is_file()):
                    rel = f.relative_to(d)
                    names.add(str(rel))
                    add(f, dest / rel, sub)
                if dest.is_dir():                    # mirror: stale sheets of THIS folder go, Godot-made .import of kept files stay
                    for old in sorted(dest.iterdir()):
                        if old.is_file() and old.suffix in ('.webp', '.png') and old.name not in names:
                            removals.append(old)
                            imp = old.with_name(old.name + '.import')
                            if imp.exists():
                                removals.append(imp)
                manifest_ids.append(d.name)
        else:
            for f in sorted(p for p in s.rglob('*') if p.is_file()):
                rel = f.relative_to(s)
                if cls == 'portraits' and only and f.stem not in only and f.suffix == '.webp':
                    continue
                if cls == 'icons' and only_icons and f.stem not in only_icons and f.suffix == '.webp':
                    continue
                if cls == 'portraits' and (f.suffix != '.webp' or f.stem not in ac.PACK_IDS or len(rel.parts) != 1):
                    errors.append(f'portraits: only <pack id>.webp busts of the 12 pack characters may be installed, got {rel}')
                    continue
                add(f, assets / sub / rel, sub)
    if errors:
        raise InstallError('\n'.join(errors))
    return copies, removals, manifest_ids


def merge_manifest(stage_assets: Path, repo: Path, ids, dry):
    src = stage_assets / 'isometric_characters' / 'manifest_traetoppen.json'
    dst = repo / 'assets' / 'isometric_characters' / 'manifest_traetoppen.json'
    if not src.exists() or not ids:
        return False
    new = json.loads(src.read_text())
    cur = json.loads(dst.read_text()) if dst.exists() else {k: v for k, v in new.items() if k != 'characters'} | {'characters': {}}
    for cid in ids:
        if cid in new['characters']:
            cur['characters'][cid] = new['characters'][cid]
    cur['characters'] = dict(sorted(cur['characters'].items()))
    text = json.dumps(cur, indent=1)
    if dst.exists() and dst.read_text() == text:
        return False
    if not dry:
        dst.write_text(text)
    return True


def install(stage_assets: Path, repo: Path, classes, only=None, dry=False, log=print, only_icons=None):
    stage_assets, repo = Path(stage_assets), Path(repo)
    if not (repo / 'project.godot').exists():
        raise InstallError(f'{repo} is not a Godot project folder (no project.godot)')
    copies, removals, ids = plan(stage_assets, repo, classes, only, only_icons)
    n_copy = n_same = n_stub_keep = n_superseded = 0
    for src, dst in copies:
        texture = dst.with_suffix('') if dst.suffix == '.import' else dst
        if drawn_art.superseded(texture.resolve(), repo):
            n_superseded += 1
            continue
        if dst.name.endswith('.import') and dst.exists():
            want = import_stubs.S3TC_WANT if 'isometric_characters' in dst.parts else import_stubs.TILE_WANT
            if import_stubs.has_preset(dst, want):          # keep the Godot-assigned uid
                n_stub_keep += 1
                continue
        if same(src, dst):
            n_same += 1
            continue
        n_copy += 1
        if not dry:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
    for f in removals:
        if not dry:
            f.unlink()
    changed_manifest = merge_manifest(stage_assets, repo, ids, dry)
    log(f'install{" (dry run)" if dry else ""}: {n_copy} file(s) copied, {n_same} identical, {n_stub_keep} existing .import kept, '
        f'{len(removals)} stale removed, {n_superseded} superseded left out, manifest_traetoppen.json {"updated" if changed_manifest else "unchanged"}'
        f' -> {repo / "assets"}')
    return {'copied': n_copy, 'identical': n_same, 'removed': len(removals), 'characters': ids, 'manifest': changed_manifest}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('Rules,')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--stage', default=None); ap.add_argument('--repo', default=str(artpaths.REPO))
    ap.add_argument('--classes', default=','.join(CLASS_DIRS)); ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--only', nargs='*', help='character / portrait ids to install (default: every folder of the stage)')
    ap.add_argument('--only-icons', nargs='*', help='icon names to install (default: all staged icons)')
    a = ap.parse_args()
    stage = artpaths.Stage(a.stage)
    classes = [c for c in a.classes.split(',') if c]
    bad = [c for c in classes if c not in CLASS_DIRS]
    if bad:
        raise SystemExit(f'unknown class {bad}; allowed: {", ".join(CLASS_DIRS)}')
    try:
        install(stage.assets, Path(a.repo), classes, a.only, a.dry_run, only_icons=a.only_icons)
    except InstallError as e:
        print('ERROR: install refused, nothing was written:\n' + str(e))
        sys.exit(2)


if __name__ == '__main__':
    main()
