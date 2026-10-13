#!/usr/bin/env python3
"""Compose contact sheets from baked sprite sheets (authoring aid / QA). Never judge art from a single frame.

  python tools/art/core/contact_sheet.py --root tools/art/_stage/masters/isometric_characters --chars snurresvamp --clips idle attack spin --rows 0 7 --out out.png
  python tools/art/core/contact_sheet.py --root DIR_A --root DIR_B --chars fox hobbit_pip --clips idle walk --rows 0 7 --out next_to_pack.png

--root may be repeated (a character is taken from the first root that has it), so a new cast can be shown next to the
shipped pack without copying anything.  Rows are the 8 directions S SW W NW N NE E SE (0..7).  Lifted from the art spike;
changes (P08): repeatable --root, default root = the stage masters, a portable font fallback.
"""
import argparse, json, os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

import artpaths


def font(size):
    for p in ['/System/Library/Fonts/Helvetica.ttc', '/System/Library/Fonts/Supplemental/Arial.ttf',
              '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']:
        if os.path.exists(p): return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def load_sheet(roots, char, clip):
    for root in roots:
        for ext in ('.webp', '.png'):
            p = Path(root) / char / (clip + ext)
            if p.exists(): return Image.open(p).convert('RGBA')
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('--root may')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--root', action='append'); ap.add_argument('--chars', nargs='+', required=True)
    ap.add_argument('--clips', nargs='+', default=['idle', 'walk']); ap.add_argument('--rows', nargs='+', type=int, default=[0])
    ap.add_argument('--scale', type=float, default=.5); ap.add_argument('--out', required=True); ap.add_argument('--bg', default='#f4efe3')
    ap.add_argument('--maxcols', type=int, default=10)
    a = ap.parse_args()
    roots = a.root or [str(artpaths.masters_dir() / 'isometric_characters')]
    S = int(256 * a.scale); f = font(13)
    lines = []
    for ch in a.chars:
        for clip in a.clips:
            sh = load_sheet(roots, ch, clip)
            if sh is None: continue
            n = sh.width // 256
            for r in a.rows:
                strip = [sh.crop((i * 256, r * 256, i * 256 + 256, r * 256 + 256)).resize((S, S), Image.LANCZOS) for i in range(min(n, a.maxcols))]
                lines.append((f'{ch} / {clip} / row {r}', strip))
    if not lines:
        raise SystemExit('nothing to draw: no sheet found for the given --chars/--clips in ' + ', '.join(roots))
    W = max(len(s) for _, s in lines) * S; H = len(lines) * (S + 18)
    out = Image.new('RGBA', (W, H), a.bg); d = ImageDraw.Draw(out)
    for y, (label, strip) in enumerate(lines):
        d.text((4, y * (S + 18) + 1), label, fill=(60, 50, 70, 255), font=f)
        for x, im in enumerate(strip):
            out.alpha_composite(im, (x * S, y * (S + 18) + 16))
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    out.convert('RGB').save(a.out); print(a.out, out.size)


if __name__ == '__main__':
    main()
