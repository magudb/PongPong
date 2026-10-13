#!/usr/bin/env python3
"""Lineup of idle frames (one direction row, default SE) or bust portraits of a cast, for QA and docs.

  python tools/art/core/cast_sheet.py --root tools/art/_stage/masters/isometric_characters --out cast.png hobbit_pip squirrel
  python tools/art/core/cast_sheet.py --root NEW_DIR --root assets/isometric_characters --out next_to_pack.png fox hobbit_pip bear cat rabbit bat --cell 128
  python tools/art/core/cast_sheet.py --root NEW_DIR --portrait --out busts.png fairy_mayor fairy_baker

--root may be repeated (a character comes from the first root that has it): put the new cast next to the shipped pack
(plan 6.4: figure height within +/-10 % of bat, cat, bear, rabbit, fox, fairy).  --cell shrinks the 256 cell to game
scale (zoom 0.4 of a 256 cell is about 102 px).  Lifted from the art spike; changes (P08): repeatable --root,
portrait.webp or .png, portable font.
"""
import argparse, os, json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

import artpaths


def font(size):
    for p in ['/System/Library/Fonts/Helvetica.ttc', '/System/Library/Fonts/Supplemental/Arial.ttf',
              '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']:
        if os.path.exists(p): return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def find(roots, name, candidates):
    for r in roots:
        for c in candidates:
            p = Path(r) / name / c
            if p.exists(): return p
    return None


ap = argparse.ArgumentParser(description=__doc__.split('--root may')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
ap.add_argument('names', nargs='*'); ap.add_argument('--root', action='append'); ap.add_argument('--out', required=True)
ap.add_argument('--cols', type=int, default=6); ap.add_argument('--cell', type=int, default=256); ap.add_argument('--portrait', action='store_true'); ap.add_argument('--row', type=int, default=7)
ap.add_argument('--bg', default='#f4efe3'); a = ap.parse_args()
roots = a.root or [str(artpaths.masters_dir() / 'isometric_characters')]
names = a.names or sorted({p.name for r in roots if Path(r).is_dir() for p in Path(r).iterdir() if p.is_dir()})
C = a.cell; rows = (len(names) + a.cols - 1) // a.cols
fnt = font(13)
sheet = Image.new('RGBA', (C * a.cols, C * rows), a.bg); d = ImageDraw.Draw(sheet)
for i, n in enumerate(names):
    p = find(roots, n, ['portrait.webp', 'portrait.png'] if a.portrait else ['idle.png', 'idle.webp'])
    if p is None:
        raise SystemExit(f'{n}: no {"portrait" if a.portrait else "idle"} sheet in ' + ', '.join(map(str, roots)))
    im = Image.open(p).convert('RGBA')
    if not a.portrait: im = im.crop((0, a.row * 256, 256, a.row * 256 + 256))
    im = im.resize((C, C), Image.LANCZOS); x, y = (i % a.cols) * C, (i // a.cols) * C
    sheet.alpha_composite(im, (x, y)); d.text((x + 6, y + 4), n, fill=(43, 35, 64, 255), font=fnt)
Path(a.out).parent.mkdir(parents=True, exist_ok=True)
sheet.convert('RGB').save(a.out); print(a.out, sheet.size)
