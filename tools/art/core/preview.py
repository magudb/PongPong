#!/usr/bin/env python3
"""Quick look: (re)build the named characters and render a contact sheet of single frames. Authoring aid only.

  python tools/art/core/preview.py hobbit_pip squirrel --angles 0 315 --clip idle --out sheet.png

Builds each model into the stage GLB folder with build_assets.export, then renders single frames with the baker's
Renderer.  Needs the builder modules on PYTHONPATH (tools/art/characters of P21 for new characters).
Lifted from the art spike; changes (P08): paths only (GLBs in tools/art/_stage/glb, sheet in tools/art/_stage/previews).
"""
import sys, argparse, os
from pathlib import Path
import artpaths
from PIL import Image, ImageDraw, ImageFont
import build_assets as ba
import bake_sprite_atlases as bk


def font(size):
    for p in ['/System/Library/Fonts/Helvetica.ttc', '/System/Library/Fonts/Supplemental/Arial.ttf',
              '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('Builds each')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('names', nargs='+'); ap.add_argument('--angles', nargs='*', type=float, default=[0, 315])
    ap.add_argument('--clip', default='idle'); ap.add_argument('--phase', type=float, default=0.0)
    ap.add_argument('--out', default=str(artpaths.DEFAULT_STAGE / 'previews' / 'preview.png')); ap.add_argument('--nobuild', action='store_true')
    ap.add_argument('--bg', default='#f4efe3'); ap.add_argument('--scale', type=float, default=1.0)
    a = ap.parse_args()
    cells = []
    for name in a.names:
        if not a.nobuild:
            maker = ba.TT_BUILDERS.get(name) or ba.BUILDERS.get(name, getattr(ba.geo, 'make_' + name, None))
            if maker is None:
                raise SystemExit(f'unknown character {name}: not in generator BUILDERS nor in TT_BUILDERS (is the builder module on PYTHONPATH?)')
            ba.export(maker(), ba.ASSETS)
        r = bk.Renderer(name, 256)
        row = []
        for ang in a.angles:
            row.append(r.frame(ang, a.clip, a.phase))
        r.close()
        cells.append((name, row))
    S = int(256 * a.scale)
    W = S * len(a.angles); H = S * len(cells)
    sheet = Image.new('RGBA', (W, H), a.bg)
    d = ImageDraw.Draw(sheet)
    f = font(14)
    for y, (name, row) in enumerate(cells):
        for x, im in enumerate(row):
            if a.scale != 1.0: im = im.resize((S, S), Image.LANCZOS)
            sheet.alpha_composite(im, (x * S, y * S))
        d.text((6, y * S + 4), name, fill=(60, 50, 70, 255), font=f)
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(a.out)
    print(a.out, sheet.size)


if __name__ == '__main__':
    main()
