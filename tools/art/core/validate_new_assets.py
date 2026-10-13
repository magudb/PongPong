#!/usr/bin/env python3
"""MANDATORY QA after every character bake: sheet geometry, animations.json consistency, blank frames and CLIPPING.

  python tools/art/core/validate_new_assets.py --root tools/art/_stage/masters/isometric_characters [ids...]
  python tools/art/core/validate_new_assets.py --root assets/isometric_characters bear_guard hobbit_pip
  python tools/art/core/validate_new_assets.py --portraits tools/art/_stage/masters/portraits [pack ids...]     # the 12 pack busts

Per clip sheet: size must be (256 x frames, 256 x 8), no blank frame (all alpha 0), no opaque pixel on the cell border
(alpha > 24 means the figure is cut off by its cell).  Per character folder: animations.json is readable and lists at least
one clip, INCLUDING `idle` (every role has it), cell [256,256], pivot [128,200], the eight directions in contract order,
every clip a positive frame count and fps, every declared sheet exists and is named after its folder, no sheet of the folder
is left unlisted (a stale sheet would be exported and installed), the portrait exists, is 256 x 256 and is not cut at the top
or the sides.  When animations.json carries a `clip_set` (the baker writes it, the exporter too) the clip set of the role
(plan 6.2) must be complete - unless the bake was a partial `--clips` bake - and for exporter-written folders `display_scale`
must be 1.0 (sprites are never scaled individually).

--portraits DIR checks bust portraits <pack id>.png|webp: 256 x 256, not blank, and not cut at the top or at the left/right
edge (the bottom edge is cut at the torso by design).

Never prints a traceback for a broken folder: unreadable / malformed animations.json or an unreadable image is a FAIL line.
Exit code 1 when any folder has a problem, 2 when nothing could be checked.  Lifted from the art spike's
validate_new_assets.py; the three original checks are unchanged, the rest is new.
"""
import argparse, json, sys
from pathlib import Path
import numpy as np
from PIL import Image

import artpaths
import artcontract as ac

SHEET_SUFFIXES = ('.png', '.webp')
NOT_SHEETS = ('portrait', 'full_idle')            # files of a character folder that are not clip sheets


def edge_alpha(al: np.ndarray, edges) -> dict:
    """Max alpha on the named borders of a cell ('top', 'bottom', 'left', 'right')."""
    sides = {'top': al[0], 'bottom': al[-1], 'left': al[:, 0], 'right': al[:, -1]}
    return {e: int(sides[e].max()) for e in edges}


def check_portrait_image(f: Path) -> list:
    """Size, blank and cut-off checks of one bust image (character portrait or pack bust).  Returns a list of problems."""
    try:
        im = Image.open(f)
        im.load()
    except Exception as e:                                  # noqa: BLE001 - any decoder error is a FAIL line, not a traceback
        return [f'{f.name}: unreadable image ({type(e).__name__}: {e})']
    if im.size != (ac.CELL, ac.CELL):
        return [f'{f.name} is {im.size}, expected {(ac.CELL, ac.CELL)}']
    al = np.asarray(im.convert('RGBA'))[..., 3]
    if al.max() == 0:
        return [f'{f.name}: blank']
    cut = {e: a for e, a in edge_alpha(al, ac.PORTRAIT_CHECKED_EDGES).items() if a > ac.BORDER_ALPHA_MAX}
    if cut:
        return [f'{f.name}: CLIPPED at the {"/".join(cut)} edge (border alpha {max(cut.values())}; frame it with m.portrait = {{half, dy, dx}} or artcontract.BUST_FRAMING)']
    return []


def check_meta(d: Path, meta) -> list:
    """Checks that only need animations.json (and the files it names)."""
    if not isinstance(meta, dict):
        return [f'animations.json is not an object ({type(meta).__name__})']
    problems = []
    if meta.get('cell_size') != [ac.CELL, ac.CELL]:
        problems.append(f'cell_size {meta.get("cell_size")} != {[ac.CELL, ac.CELL]}')
    if meta.get('pivot') != list(ac.PIVOT):
        problems.append(f'pivot {meta.get("pivot")} != {list(ac.PIVOT)}')
    if meta.get('directions') != ac.DIRECTIONS:
        problems.append(f'directions {meta.get("directions")} != {ac.DIRECTIONS}')
    anims = meta.get('animations')
    if not isinstance(anims, dict) or not anims:
        problems.append('no clips: animations.json lists no animation (a character needs at least idle)')
        anims = {}
    elif 'idle' not in anims:
        problems.append('no idle clip (every role needs idle)')
    for clip, spec in anims.items():
        if not isinstance(spec, dict):
            problems.append(f'{clip}: clip entry is not an object')
            continue
        if not (isinstance(spec.get('frames'), int) and not isinstance(spec.get('frames'), bool) and spec['frames'] > 0):
            problems.append(f'{clip}: bad frames {spec.get("frames")}')
        if not (isinstance(spec.get('fps'), (int, float)) and not isinstance(spec.get('fps'), bool) and spec['fps'] > 0):
            problems.append(f'{clip}: bad fps {spec.get("fps")}')
        if not isinstance(spec.get('loop'), bool):
            problems.append(f'{clip}: loop is not a bool')
        sheet = spec.get('sheet')
        if not isinstance(sheet, str) or not sheet:
            problems.append(f'{clip}: no sheet name')
        elif Path(sheet).name != sheet or Path(sheet).suffix not in SHEET_SUFFIXES:
            problems.append(f'{clip}: bad sheet name {sheet!r} (a .png/.webp file in the character folder)')
    portrait = meta.get('portrait')
    if portrait:
        pf = d / portrait if isinstance(portrait, str) and Path(portrait).name == portrait else None
        if pf is None:
            problems.append(f'bad portrait name {portrait!r}')
        elif not pf.exists():
            problems.append(f'portrait {portrait} missing')
        else:
            problems += check_portrait_image(pf)
    # exporter/baker-written folders: role / clip set / flight / scale contract
    clip_set = meta.get('clip_set')
    if clip_set is not None:
        if clip_set not in ac.CLIP_SETS:
            problems.append(f'unknown clip_set {clip_set}')
        elif not meta.get('partial'):                       # a --clips bake is partial on purpose
            want = ac.CLIP_SETS[clip_set]
            want = list(want) if want is not None else list(ac.FULL_CLIPS)
            if clip_set == 'full' and meta.get('flyer'):
                want += ac.FLIGHT_CLIPS
            missing = [c for c in want if c not in anims]
            if missing:
                problems.append(f'clip set {clip_set} needs {missing}')
            if meta.get('role') and meta['role'] != ac.ROLE_OF_CLIP_SET[clip_set]:
                problems.append(f'role {meta["role"]} != {ac.ROLE_OF_CLIP_SET[clip_set]} (clip set {clip_set})')
    if 'role' in meta and meta.get('display_scale', 1.0) != 1.0:
        problems.append(f'display_scale {meta["display_scale"]} != 1.0 (sprites are never scaled individually: '
                        f'size the model with m.height/m.base_height, not m.cam_scale)')
    return problems


def unlisted_sheets(d: Path, meta) -> list:
    """Sheet images in the folder that animations.json does not list (they would be exported and installed as dead weight)."""
    if not isinstance(meta, dict) or not isinstance(meta.get('animations'), dict):
        return []
    listed = {spec.get('sheet') for spec in meta['animations'].values() if isinstance(spec, dict)}
    listed.add(meta.get('portrait'))
    return sorted(f.name for f in d.iterdir() if f.is_file() and f.suffix in SHEET_SUFFIXES and f.stem not in NOT_SHEETS and f.name not in listed)


def check_character(root: Path, cid: str):
    d = root / cid
    mf = d / 'animations.json'
    if not mf.exists():
        return ['animations.json missing'], 0, set()
    try:
        meta = json.loads(mf.read_text())
    except (ValueError, OSError) as e:                      # JSONDecodeError is a ValueError
        return [f'animations.json unreadable ({type(e).__name__}: {e})'], 0, set()
    problems = check_meta(d, meta)
    anims = meta.get('animations') if isinstance(meta, dict) else None
    if not isinstance(anims, dict):
        return problems, 0, set()
    stale = unlisted_sheets(d, meta)
    if stale:
        problems.append(f'sheet(s) not listed in animations.json: {stale}')
    ext_seen = set()
    for clip, spec in anims.items():
        if not isinstance(spec, dict) or not isinstance(spec.get('sheet'), str) or not isinstance(spec.get('frames'), int) \
                or isinstance(spec.get('frames'), bool) or spec['frames'] < 1 or Path(spec['sheet']).name != spec['sheet']:
            continue                                        # already reported by check_meta
        f = d / spec['sheet']
        if not f.exists():
            problems.append(f'{clip}: missing {spec["sheet"]}')
            continue
        try:
            im = Image.open(f)
            im.load()
        except Exception as e:                              # noqa: BLE001
            problems.append(f'{clip}: unreadable {spec["sheet"]} ({type(e).__name__}: {e})')
            continue
        ext_seen.add(f.suffix)
        if im.size != (ac.CELL * spec['frames'], ac.CELL * 8):
            problems.append(f'{clip}: size {im.size} != {(ac.CELL * spec["frames"], ac.CELL * 8)}')
            continue
        al = np.asarray(im.convert('RGBA'))[..., 3]
        for r in range(8):
            for fr in range(spec['frames']):
                cell = al[r * ac.CELL:(r + 1) * ac.CELL, fr * ac.CELL:(fr + 1) * ac.CELL]
                if cell.max() == 0:
                    problems.append(f'{clip} r{r} f{fr}: blank')
                edge = max(cell[0].max(), cell[-1].max(), cell[:, 0].max(), cell[:, -1].max())
                if edge > ac.BORDER_ALPHA_MAX:
                    problems.append(f'{clip} r{r} f{fr}: CLIPPED (border alpha {edge})')
    return problems, len(anims), ext_seen


def check_pack_busts(root: Path, ids):
    """The 12 pack busts <id>.png|webp of a folder.  Returns [(id, problems)]."""
    out = []
    for cid in ids:
        if cid not in ac.PACK_IDS:
            out.append((cid, [f'{cid} is not one of the 12 pack ids ({" ".join(ac.PACK_IDS)})']))
            continue
        files = [root / (cid + ext) for ext in SHEET_SUFFIXES if (root / (cid + ext)).exists()]
        if not files:
            out.append((cid, [f'{cid}.png / {cid}.webp missing in {root}']))
            continue
        out.append((cid, check_portrait_image(files[0])))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('Never prints')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('ids', nargs='*')
    ap.add_argument('--root', default=str(artpaths.masters_dir() / 'isometric_characters'))
    ap.add_argument('--portraits', metavar='DIR', help='validate the pack bust portraits <id>.png|webp in DIR instead of character folders')
    a = ap.parse_args()
    if a.portraits:
        root = Path(a.portraits)
        if not root.is_dir():
            print(f'ERROR: {root} is not a folder')
            sys.exit(2)
        ids = a.ids or sorted({p.stem for p in root.iterdir() if p.is_file() and p.suffix in SHEET_SUFFIXES})
        if not ids:
            print(f'ERROR: no bust portraits in {root}')
            sys.exit(2)
        results = check_pack_busts(root, ids)
        bad = 0
        for cid, problems in results:
            print(('OK   ' if not problems else 'FAIL ') + cid, '| bust |', '; '.join(problems))
            bad += bool(problems)
        print(f'{len(ids) - bad}/{len(ids)} bust portraits valid')
        sys.exit(1 if bad else 0)
    root = Path(a.root)
    if not root.is_dir():
        print(f'ERROR: {root} is not a folder')
        sys.exit(2)
    ids = a.ids or sorted(p.name for p in root.iterdir() if p.is_dir() and (p / 'animations.json').exists())
    if not ids:
        print(f'ERROR: no character folders in {root}')
        sys.exit(2)
    bad = 0
    for cid in ids:
        try:
            problems, nclips, exts = check_character(root, cid)
        except Exception as e:                              # noqa: BLE001 - a malformed folder is a FAIL line, never a traceback
            problems, nclips, exts = [f'validator error ({type(e).__name__}: {e})'], 0, set()
        print(('OK   ' if not problems else 'FAIL ') + cid, '| clips', nclips, '|', sorted(exts), '|',
              '; '.join(problems[:4]) + (' ...' if len(problems) > 4 else ''))
        bad += bool(problems)
    print(f'{len(ids) - bad}/{len(ids)} character folders valid')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
