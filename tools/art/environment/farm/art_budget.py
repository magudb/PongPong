#!/usr/bin/env python3
"""art_budget.py - the size / texture-memory table of the shipped farm kit (package N03-farm-art), read from the PNG / WebP files.

  python tools/art/environment/farm/art_budget.py [--root REPO] [--write]      --write refreshes tools/art/environment/farm/art_budget.txt

Same table as the prototype's design3/farm/scripts/art_budget.py (kind id w h pivot MB), with the lossless column of that table and the S3TC column of the order:
  lossless  RGBA8 = 4 bytes per pixel, +1/3 for the mipmap chain of props and backdrops (the .import of this package keeps mipmaps), field_grass has no mipmaps
  s3tc      DXT5 = 1 byte per pixel (+1/3 mipmaps) for the ten props and the two backdrops (compress/mode=2 stubs), field_grass stays lossless
The prototype measured the kit in a window (RENDER_TEXTURE_MEM_USED): 65.5 MB lossless / 15.8 MB with S3TC, mean error 0.85-1.7 / 255.  tests/sections/art_farm.gd re-measures it
(windowed) and asserts the arithmetic here (headless).  Rows of the table are the contract of art_farm.sizes_match_art_budget_table.
Each row reads the file the game draws: a kit id or farm_far that a later art pack repaints is measured in its painted file (the N03 copy is not kept, review REND-10).
"""
from __future__ import annotations
import argparse
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
sys.path.insert(0, str(HERE.parents[1] / 'drawn'))
import drawn_art   # noqa: E402
KIT_IDS = ['trunk_giant_a', 'trunk_giant_b', 'trunk_under_a', 'trunk_under_b', 'tool_shed', 'shipping_bin', 'stake_sign', 'rope_stake_x', 'rope_stake_z', 'build_stake']
TRUNKS = KIT_IDS[:4]
MB = 1048576.0


def rows(root: Path) -> list:
    out = []
    for i in sorted(KIT_IDS):
        w, h = Image.open(drawn_art.drawn_file(i, root)).size
        out.append(('props', i, w, h, drawn_art.catalog(root)[i]['pivot'], w * h * 4 * 4 / 3 / MB, w * h * 1 * 4 / 3 / MB))
    for f in ('farm_canopy.webp', 'farm_far.webp'):
        w, h = Image.open(far_file(root, f)).size
        out.append(('back', f, w, h, None, w * h * 4 * 4 / 3 / MB, w * h * 1 * 4 / 3 / MB))
    w, h = Image.open(root / 'assets/iso_tiles/field_grass.png').size
    out.append(('tiles', 'field_grass.png', w, h, None, w * h * 4 / MB, w * h * 4 / MB))
    return out


def far_file(root: Path, f: str) -> Path:
    """assets/backdrops/<f>, or the painted backdrop_<name> prop that supersedes it."""
    path = root / 'assets/backdrops' / f
    return drawn_art.drawn_file('backdrop_' + f.removesuffix('.webp'), root) if drawn_art.superseded(path.resolve(), root) else path


def table(rs: list) -> str:
    lines = ['%-6s %-18s %6s %6s %-14s %9s %9s' % ('kind', 'id', 'w', 'h', 'pivot', 'MB', 'MB s3tc')]
    for k, i, w, h, pv, m, s in rs:
        lines.append('%-6s %-18s %6d %6d %-14s %9.2f %9.2f' % (k, i, w, h, str(pv) if pv else '-', m, s))
    lines.append('')
    tot = {}
    for k, i, w, h, pv, m, s in rs:
        t = tot.setdefault(k, [0.0, 0.0])
        t[0] += m
        t[1] += s
    trunks = sum(r[5] for r in rs if r[1] in TRUNKS)
    trunks_s = sum(r[6] for r in rs if r[1] in TRUNKS)
    props = tot['props'][0] - trunks
    props_s = tot['props'][1] - trunks_s
    for k in ('props', 'back', 'tiles'):
        lines.append('%-6s total %7.2f MB lossless  %7.2f MB s3tc' % (k, tot[k][0], tot[k][1]))
    lines.append('kit    total %7.2f MB lossless  %7.2f MB s3tc   (trunks %.1f / %.1f, other props %.1f / %.1f, backdrops %.1f / %.1f, field_grass %.2f)' % (
        sum(v[0] for v in tot.values()), sum(v[1] for v in tot.values()), trunks, trunks_s, props, props_s, tot['back'][0], tot['back'][1], tot['tiles'][0]))
    lines.append('prototype (measured in a window, with the 1024 x 1024 farm_sky this package does not ship): 65.5 MB lossless, 15.8 MB with S3TC; budget kit <= 20 MB compressed')
    return '\n'.join(lines) + '\n'


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('  python ')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--root', default=str(REPO))
    ap.add_argument('--write', action='store_true')
    a = ap.parse_args()
    txt = table(rows(Path(a.root)))
    print(txt, end='')
    if a.write:
        (HERE / 'art_budget.txt').write_text(txt)
        print('written', HERE / 'art_budget.txt')
    return 0


if __name__ == '__main__':
    sys.exit(main())
