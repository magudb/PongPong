#!/usr/bin/env python3
"""validate_farm.py - validator of the shipped farm kit (package N03-farm-art): a SECOND implementation of the checks of tests/sections/art_farm.gd, run by build_farm.sh after every bake.

  python tools/art/environment/farm/validate_farm.py [--root REPO] [-q]

One `PASS <id>` / `FAIL <id> <reason>` line per check, exit code 1 on any FAIL.  Reads assets/iso_props/farm, assets/backdrops, assets/iso_tiles and lua/config/props_extra.lua.
  kit_ids_exist            the ten ids, one png each, props.json lists exactly them, none of them in P22's props.json, nothing else in assets/iso_props/farm
  sizes_and_pivots         size = image size = the measured prototype table, the pivot is inside the image with painted contact near it, footprints = the contract
  props_extra_rows         the ten rows of design_farm.md 10.3 (footprint, solid shape + number, strips) are in lua/config/props_extra.lua
  art_budget_table         tools/art/environment/farm/art_budget.txt = the files
  backdrops                farm_far 2048x1024 seamless in x with a soft transparent top, farm_canopy 2048x360 solid on top and faded at the lower edge, NO farm_sky.* in assets/backdrops
  field_grass              576x336 = 4 x 4 periodic diamond cells of 144 x 84, tiles_farm.json, lighter than grass and textured
  imports                  the stubs / Godot's imports carry the presets (compress/mode 2 + mipmaps for props and backdrops, lossless without mipmaps for field_grass), write_farm_imports.audit
  vram_budget              kit <= 20 MB of texture memory (arithmetic from the import presets)
  reference_builders       the builders of the P22 contract props kept in props_farm.py as P22_REFERENCE have the contract footprints (needs the art venv, skipped without vtk)
  codex_additive           nothing outside the allow-list is touched: only files of this package exist in the farm folders, no farm_sky.*
The ids, footprints and contract are N03's (assets/iso_props/farm/props.json); the files checked are the ones the game draws: ArtCatalog's entry of each id. The painted
consistency pass repaints all ten and farm_far (same canvases and pivots, except the tool shed: PAINTED), and the superseded N03 bakes are not kept (review REND-10).
"""
from __future__ import annotations
import argparse
import importlib.util
import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
sys.path.insert(0, str(HERE))
import write_farm_imports as wfi     # noqa: E402
from art_budget import far_file     # noqa: E402
import drawn_art                    # noqa: E402  (tools/art/drawn, on the path through write_farm_imports)

KIT = {
    'trunk_giant_a': (1227, 2405, 622, 2092, 5, 3), 'trunk_giant_b': (1274, 2142, 685, 1903, 3, 3), 'trunk_under_a': (907, 1352, 454, 139, 1, 1),
    'trunk_under_b': (746, 1306, 371, 117, 1, 1), 'tool_shed': (316, 313, 140, 246, 2, 2), 'shipping_bin': (226, 182, 100, 138, 2, 1), 'stake_sign': (84, 124, 38, 105, 1, 1),
    'rope_stake_x': (87, 97, 41, 72, 1, 1), 'rope_stake_z': (87, 97, 41, 72, 1, 1), 'build_stake': (76, 118, 35, 100, 1, 1),
}
ROWS = {
    'trunk_giant_a': ('none', 0, 0), 'trunk_giant_b': ('footprint', 0, 12), 'trunk_under_a': ('none', 0, 0), 'trunk_under_b': ('none', 0, 0),
    'shipping_bin': ('footprint', 8, 0), 'tool_shed': ('footprint', 12, 6), 'stake_sign': ('circle', 10, 0), 'rope_stake_x': ('none', 0, 0),
    'rope_stake_z': ('none', 0, 0), 'build_stake': ('none', 0, 0),
}
P22_FOOTPRINTS = {'coop_small': (3, 2), 'barn_small': (4, 3), 'animal_house': (3, 2), 'bench': (2, 1), 'paw_prints': (1, 1), 'signpost': (1, 1), 'apple_tree': (1, 1), 'mailbox_red': (1, 1)}
# the painted consistency pass re-canvased the shed (approved in docs/art/style-audit); the prototype measured 316x313 (140,246), which props_farm.py keeps
PAINTED = {'tool_shed': (293, 320, 146, 236)}
MB = 1048576.0

fails = 0
quiet = False


def report(name: str, ok: bool, detail: str = '') -> None:
    global fails
    if not ok:
        fails += 1
    if not ok or not quiet:
        print(('PASS ' if ok else 'FAIL ') + name + ((' ' + detail) if detail else ''))


def load_json(p: Path):
    return json.loads(p.read_text()) if p.is_file() else None


def img(p: Path):
    return Image.open(p).convert('RGBA') if p.is_file() else None


def drawn(root: Path, i: str) -> tuple:
    """(entry, file) the game draws for a kit id: N03's own, or the entry of the painted pack that supersedes it."""
    e = drawn_art.catalog(root).get(i)
    return (e, e['_dir'] / e['file']) if e else (None, None)


def contract(root: Path, i: str) -> tuple:
    """KIT's (w, h, pivot x, pivot y, fx, fz), with the painted canvas where a painted pack draws the id and re-canvased it."""
    w, h, px, py, fx, fz = KIT[i]
    e, _f = drawn(root, i)
    if e and e['_dir'] != root / 'assets/iso_props/farm' and i in PAINTED:
        w, h, px, py = PAINTED[i]
    return w, h, px, py, fx, fz


def props_extra_rows(root: Path) -> dict:
    """id -> (fx, fz, shape, number, strips) from lua/config/props_extra.lua (the rows are one line each)."""
    txt = (root / 'lua/config/props_extra.lua').read_text()
    out = {}
    for m in re.finditer(r'^\s*(\w+)\s*=\s*\{\s*footprint\s*=\s*\{\s*(\d+),\s*(\d+)\s*\},\s*solid\s*=\s*\{\s*shape\s*=\s*"(\w+)"(?:,\s*(?:pad|radius)\s*=\s*(\d+))?\s*\},\s*strips\s*=\s*(\d+)', txt, re.M):
        out[m.group(1)] = (int(m.group(2)), int(m.group(3)), m.group(4), int(m.group(5) or 0), int(m.group(6)))
    return out


def check_kit(root: Path) -> None:
    d = root / 'assets/iso_props/farm'
    man = load_json(d / 'props.json') or {}
    ids = {k for k in man if not k.startswith('_')}
    p22 = load_json(root / 'assets/iso_props/props.json') or {}
    stray = [f.name for f in d.iterdir() if f.is_file() and f.name not in {'props.json'} | {i + '.png' for i in KIT} | {i + '.png.import' for i in KIT}] if d.is_dir() else ['(no folder)']
    shadow = [i for i in KIT if i in p22]
    missing = [i for i in KIT if not (d / f'{i}.png').is_file() and not drawn_art.superseded((d / f'{i}.png').resolve(), root)]
    report('kit_ids_exist', ids == set(KIT) and not missing and not shadow and not stray, 'manifest %s missing %s in P22 manifest %s stray %s' % (sorted(ids ^ set(KIT)), missing, shadow, stray))
    bad = []
    for i in KIT:
        w, h, px, py, fx, fz = contract(root, i)
        e, f = drawn(root, i) if i in man else (None, None)
        im = img(f) if f else None
        if e is None or im is None:
            bad.append(f'{i}: missing')
            continue
        if list(im.size) != e['size'] or im.size != (w, h):
            bad.append(f'{i}: size {im.size} manifest {e["size"]} contract {(w, h)}')
        if e['pivot'] != [px, py]:
            bad.append(f'{i}: pivot {e["pivot"]} contract {[px, py]}')
        elif not (0 <= px < w and 0 <= py < h):
            bad.append(f'{i}: the pivot is outside the image')
        else:
            # a rope's ground centre is between its two posts: allow that opening and narrow pencil contours, never a floating body (art_farm.gd)
            r = 12 if i.startswith('rope_stake_') else 2
            a = np.asarray(im, np.float32)[max(0, py - r):py + r + 1, max(0, px - r):px + r + 1, 3]
            yy, xx = np.mgrid[max(0, py - r) - py:min(h, py + r + 1) - py, max(0, px - r) - px:min(w, px + r + 1) - px]
            if not (a[yy * yy + xx * xx <= r * r] >= 0.12 * 255).any():
                bad.append(f'{i}: no painted contact near the ground pivot')
        if tuple(e['footprint']) != (fx, fz):
            bad.append(f'{i}: footprint {e["footprint"]} contract {(fx, fz)}')
    report('sizes_and_pivots', not bad, '; '.join(bad[:4]))
    rows = props_extra_rows(root)
    bad = []
    for i, (shape, num, strips) in ROWS.items():
        r = rows.get(i)
        c = KIT[i]
        if r is None:
            bad.append(f'{i}: no row')
        elif r != (c[4], c[5], shape, num, strips):
            bad.append(f'{i}: row {r} design_farm 10.3 {(c[4], c[5], shape, num, strips)}')
    report('props_extra_rows', not bad, '; '.join(bad[:4]))


def check_table(root: Path) -> None:
    t = HERE / 'art_budget.txt'
    txt = t.read_text() if t.is_file() else ''
    rows = {}
    for m in re.finditer(r'^(props|back|tiles)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\[\d+, \d+\]|-)', txt, re.M):
        rows[m.group(2)] = (int(m.group(3)), int(m.group(4)), m.group(5))
    bad = []
    for i in KIT:
        w, h, px, py, _fx, _fz = contract(root, i)
        if rows.get(i) != (w, h, f'[{px}, {py}]'):
            bad.append(f'{i}: table {rows.get(i)}')
    for f, (w, h, folder) in {'farm_far.webp': (2048, 1024, 'assets/backdrops'), 'farm_canopy.webp': (2048, 360, 'assets/backdrops'), 'field_grass.png': (576, 336, 'assets/iso_tiles')}.items():
        im = img(far_file(root, f) if folder == 'assets/backdrops' else root / folder / f)
        if im is None or im.size != (w, h) or rows.get(f, (0, 0))[:2] != (w, h):
            bad.append(f'{f}: file {None if im is None else im.size} table {rows.get(f)}')
    report('art_budget_table', not bad, '; '.join(bad[:4]))


def premult(im: Image.Image) -> np.ndarray:
    a = np.asarray(im, np.float32)
    return np.concatenate([a[..., :3] * a[..., 3:4] / 255.0, a[..., 3:4]], axis=2)


def check_backdrops(root: Path) -> None:
    far = img(far_file(root, 'farm_far.webp'))
    can = img(root / 'assets/backdrops/farm_canopy.webp')
    if far is None or can is None:
        report('backdrops', False, 'farm_far.webp / farm_canopy.webp missing')
        return
    bad = []
    if far.size != (2048, 1024):
        bad.append(f'far {far.size}')
    if can.size != (2048, 360):
        bad.append(f'canopy {can.size}')
    p = premult(far)
    h, w = p.shape[:2]
    seam = np.abs(p[::8, 0] - p[::8, w - 1]).mean()
    across = np.abs(p[::8, 0] - p[::8, w // 2]).mean()
    if not (seam < 3.0 and across > 3 * seam):
        bad.append(f'far seam {seam:.2f} (limit 3.0), columns 0 / {w // 2} differ by {across:.1f}')
    al = np.asarray(far, np.float32)[..., 3] / 255
    rows = al.mean(1)
    # the layer starts in the middle of the screen: a transparent top row and a mean alpha that rises softly (art_farm.far_top_edge_soft)
    if not (rows[0] < 0.01 and rows.max() > 0.15 and np.abs(np.diff(rows)).max() < 0.12):
        bad.append(f'far top edge alpha rows 0/100/200/300 = {[round(float(rows[y]), 2) for y in (0, 100, 200, 300)]}')
    ac = np.asarray(can, np.float32)[..., 3] / 255
    top, mid, a200, a270, a300 = (ac[y].mean() for y in (0, 150, 200, 270, 300))
    if not (top > 0.8 and mid > 0.5 and a200 < mid and a270 < a200 and a300 < 0.15 and ac[-1].max() == 0 and ac[-30:].max() < 0.01):
        bad.append(f'canopy alpha rows 0/150/200/270/300 = {[round(float(v), 2) for v in (top, mid, a200, a270, a300)]}, last row max {ac[-1].max():.2f}')
    sky = [f.name for f in (root / 'assets/backdrops').glob('farm_sky*') if f.suffix == '.webp' or f.name.endswith('.webp.import')]
    if sky:
        bad.append(f'{sky} would shadow the painted farm_sky.png')
    report('backdrops', not bad, '; '.join(bad))


def atlas_stats(im: Image.Image) -> tuple:
    a = np.asarray(im, np.float32)
    m = a[..., 3] > 250
    rgb = a[..., :3][m]
    g = a[..., :3].mean(2)
    dy = np.abs(np.diff(g, axis=0))
    mm = m[1:] & m[:-1]
    return rgb.mean(0), float((rgb * [.2126, .7152, .0722]).sum(1).mean()), float(dy[mm].mean())


def check_field_grass(root: Path) -> None:
    fg = img(root / 'assets/iso_tiles/field_grass.png')
    gr = img(root / 'assets/iso_tiles/grass.png')
    meta = (load_json(root / 'assets/iso_tiles/tiles_farm.json') or {}).get('field_grass')
    bad = []
    if meta != {'file': 'field_grass.png', 'variants': [4, 4], 'cell': [144, 84]}:
        bad.append(f'tiles_farm.json {meta}')
    if fg is None or fg.size != (576, 336):
        bad.append(f'atlas {None if fg is None else fg.size}')
    else:
        a = np.asarray(fg)
        for j in range(4):
            for i in range(4):
                c = a[j * 84:(j + 1) * 84, i * 144:(i + 1) * 144, 3]
                if not (c[0, 0] == 0 and c[0, -1] == 0 and c[-1, 0] == 0 and c[-1, -1] == 0 and c[42, 72] == 255 and c[12, 72] == 255):
                    bad.append(f'cell ({i},{j}) is not a filled diamond')
        if gr is not None:
            (fr, fl, fd), (gr_, gl, gd) = atlas_stats(fg), atlas_stats(gr)
            dist = float(np.abs(fr - gr_).mean())
            # the painted field stays distinct and textured (art_farm.field_grass_distinct_from_grass)
            if not (dist >= 6.0 and fl > gl + 4.0 and fd > 0.25):
                bad.append(f'not distinct from grass: colour distance {dist:.1f}, luminance +{fl - gl:.1f}, vertical pigment variation {fd:.2f}')
    report('field_grass', not bad, '; '.join(bad[:4]))


def check_imports(root: Path) -> None:
    bad = wfi.audit(root)
    report('imports', not bad, '; '.join(bad[:4]))


def vram_estimate(root: Path) -> tuple:
    comp = loss = 0.0
    files = [(drawn(root, i)[1], wfi.VRAM_WANT) for i in KIT] + [(far_file(root, f), wfi.VRAM_WANT) for f in ('farm_far.webp', 'farm_canopy.webp')]
    for asset, want in files + [(root / 'assets/iso_tiles/field_grass.png', wfi.TILE_WANT)]:
        im = Image.open(asset)
        px = im.size[0] * im.size[1]
        mip = 4 / 3 if want.get('mipmaps/generate') == 'true' else 1.0
        bpp = 1.0 if want['compress/mode'] == '2' else 4.0
        comp += px * bpp * mip
        loss += px * 4.0 * mip
    return comp / MB, loss / MB


def check_vram(root: Path) -> None:
    comp, loss = vram_estimate(root)
    report('vram_budget', comp <= 20.0 and loss > 2.5 * comp, '%.1f MB with S3TC (budget 20) against %.1f MB lossless' % (comp, loss))


def check_reference() -> None:
    try:
        sys.path.insert(0, str(HERE))
        import farm_common as fc
        mod = fc.load_kit()
    except Exception as e:                                           # no vtk / numpy venv
        print('SKIP reference_builders (%s)' % str(e).splitlines()[0][:80])
        return
    bad = mod.check_reference()
    c = {i: tuple(v) for i, v in mod.FARM_CONTRACT.items()}
    if c != {i: v for i, v in KIT.items()}:
        bad.append('props_farm.FARM_CONTRACT differs from this validator\'s table')
    report('reference_builders', not bad, '; '.join(bad[:4]))


def check_additive(root: Path) -> None:
    allowed = {'assets/iso_props/farm', 'assets/backdrops', 'assets/iso_tiles'}
    bad = []
    for f in (root / 'assets/backdrops').iterdir():
        if f.name.startswith('farm_') and f.name not in {'farm_far.webp', 'farm_far.webp.import', 'farm_canopy.webp', 'farm_canopy.webp.import', 'farm_sky.png', 'farm_sky.png.import'}:
            bad.append(f.name)
    for f in (root / 'assets/iso_tiles').iterdir():
        if f.name.startswith('field_grass') and f.name not in {'field_grass.png', 'field_grass.png.import'}:
            bad.append(f.name)
    report('codex_additive', not bad and len(allowed) == 3, 'unexpected files %s' % bad)


def main() -> int:
    global quiet
    ap = argparse.ArgumentParser(description=__doc__.split('  python ')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--root', default=str(REPO))
    ap.add_argument('-q', '--quiet', action='store_true')
    a = ap.parse_args()
    quiet = a.quiet
    root = Path(a.root)
    check_kit(root)
    check_table(root)
    check_backdrops(root)
    check_field_grass(root)
    check_imports(root)
    check_vram(root)
    check_reference()
    check_additive(root)
    print('validate_farm: %d finding(s)' % fails)
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
