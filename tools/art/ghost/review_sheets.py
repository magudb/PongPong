#!/usr/bin/env python3
"""Regenerates the review sheets of tools/art/ghost/review/ from the INSTALLED assets (assets/isometric_characters) and, for gamezoom_check, from the real windowed run.

  tools/art/.venv/bin/python -I tools/art/ghost/review_sheets.py                    # contact_sheet_ghost.png + sketch_vs_baked.png (+ gamezoom_check.png when --shots is given)
  tools/art/.venv/bin/python -I tools/art/ghost/review_sheets.py --shots DIR         # DIR = the --out folder of: tools/dev/run_windowed.sh --only=art_ghost --out=DIR
  tools/art/.venv/bin/python -I tools/art/ghost/review_sheets.py --only contact      # contact | sketch | gamezoom

  contact_sheet_ghost.png   rows: Bu 8 directions (idle frame 0) | Hviske 8 directions | walk SE 6 frames + run SW 2 frames of each hero | Bu's other clips | the two 14 degree busts
                            (never judge a character from one frame: plan 6.4)
  sketch_vs_baked.png       top row: the Figurer v2 cards of Rasmus, Bertil, Kloevermynte (crops of docs/Traetoppen Style Guide Review/refs/figurer_v2_render.png) and a SKETCH-STYLE drawing of Bu
                            made here with the sheet's rules (thick ink, flat fills, big eyes with a glint, blush, three cheek strokes); bottom row: the BAKED fox, hobbit_pip, fairy and
                            both ghosts (idle S, 1:1) on the same card colours.  It shows how much softer the whole baked roster is than the flat cards: the ghost no more than the others
  gamezoom_check.png        the real windowed screenshots of tests/sections/art_ghost.gd (1280 x 720, Camera zoom 0.4 / 0.9 / night 23:00) cropped to the cast; the zoom 0.4 crops are
                            magnified x2 with nearest neighbour so that the true screen pixels are visible.  The cast layout (CAST rows) is the one of the section's run_windowed

The labels are English (developer tooling, not player copy).  Lifted from design4/scripts/{contact_ghosts,compose_checks}.py: same layout, repo-relative paths, the real section's shots,
Pillow + numpy only.  The PNGs are kept small (< 900 KB: the section checks it); they are hidden from Godot by tools/art/.gdignore.
"""
import argparse, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
ASSETS = REPO / 'assets' / 'isometric_characters'
REVIEW = HERE / 'review'
FONTS = REPO / 'assets' / 'fonts'
GUIDE = REPO / 'docs' / 'Trætoppen Style Guide Review' / 'refs' / 'figurer_v2_render.png'
INK = (43, 35, 64)
PAPER = (233, 226, 208)
DIRS = ['S', 'SW', 'W', 'NW', 'N', 'NE', 'E', 'SE']
MAX_BYTES = 880000


def fonts():
    cap = ImageFont.truetype(str(FONTS / 'Caprasimo-Regular.ttf'), 24)
    cap19 = ImageFont.truetype(str(FONTS / 'Caprasimo-Regular.ttf'), 19)
    small = ImageFont.truetype(str(FONTS / 'AlegreyaSans-Bold.ttf'), 15)
    return cap, cap19, small


def sheet(cid, clip):
    for ext in ('.webp', '.png'):
        p = ASSETS / cid / (clip + ext)
        if p.exists():
            return Image.open(p).convert('RGBA')
    raise SystemExit(f'ERROR: no sheet {cid}/{clip} under {ASSETS}')


def cell(cid, clip, frame, row):
    return sheet(cid, clip).crop((frame * 256, row * 256, frame * 256 + 256, row * 256 + 256))


def grass(w, h):
    im = Image.new('RGB', (w, h), (169, 201, 122))
    d = ImageDraw.Draw(im)
    for k in range(-h, w, 44):
        d.polygon([(k, 0), (k + 22, 0), (k + 22 + h, h), (k + h, h)], fill=(156, 191, 108))
    return im


def put(canvas, c, x, y, scale=1.0, bg=None):
    s = int(256 * scale)
    c = c.resize((s, s), Image.LANCZOS) if scale != 1 else c
    if bg is not None:
        canvas.paste(bg.crop((x, y, x + s, y + s)), (x, y))
    canvas.alpha_composite(c, (x, y))


def save_small(img: Image.Image, path: Path):
    """PNG, optimised; when it is still too big, 256 colours (the characters' review sheets are 256-colour PNGs too)."""
    img = img.convert('RGB')
    img.save(path, optimize=True)
    if path.stat().st_size > MAX_BYTES:
        img.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(path, optimize=True)
    print('wrote %s %s %d KB' % (path.relative_to(REPO), img.size, path.stat().st_size // 1024))


# ---------------------------------------------------------------------------------------------------------------------
def contact():
    cap, cap19, small = fonts()
    S, pad, left = 192, 8, 150
    W = left + 8 * (S + pad)
    H = 40 + 4 * (S + 24) + 2 * (S + 24) + 170
    img = Image.new('RGBA', (W, H), PAPER + (255,))
    d = ImageDraw.Draw(img)
    d.text((10, 6), 'Spoegelse: Bu and Hviske, idle frame 0, 8 directions (baked, 36 degrees, 256 px cells shown at 75 %)', font=cap, fill=INK)
    bg = grass(W, H).convert('RGBA')
    y = 44
    for name, cid in (('Bu', 'ghost_bu'), ('Hviske', 'ghost_hviske')):
        d.text((10, y + S // 2 - 10), name, font=cap, fill=INK)
        for r in range(8):
            x = left + r * (S + pad)
            img.paste(bg.crop((x, y, x + S, y + S)), (x, y))
            put(img, cell(cid, 'idle', 0, r), x, y, S / 256)
            d.text((x + 4, y + S + 2), DIRS[r], font=small, fill=INK)
        y += S + 24
    for name, cid in (('Bu walk SE', 'ghost_bu'), ('Hviske walk SE', 'ghost_hviske')):
        d.text((10, y + S // 2 - 10), name, font=small, fill=INK)
        for f in range(6):
            x = left + f * (S + pad)
            img.paste(bg.crop((x, y, x + S, y + S)), (x, y))
            put(img, cell(cid, 'walk', f, 7), x, y, S / 256)
            d.text((x + 4, y + S + 2), 'walk %d' % f, font=small, fill=INK)
        for f in range(2):
            x = left + (6 + f) * (S + pad)
            img.paste(bg.crop((x, y, x + S, y + S)), (x, y))
            put(img, cell(cid, 'run', f * 3, 1), x, y, S / 256)
            d.text((x + 4, y + S + 2), 'run SW %d' % (f * 3), font=small, fill=INK)
        y += S + 24
    clips = [('sleep', 0, 0), ('talk', 1, 7), ('celebrate', 2, 7), ('hit', 1, 7), ('jump', 2, 7), ('interact', 2, 7), ('fall', 1, 0), ('land', 1, 7)]
    d.text((10, y + S // 2 - 10), 'Bu: other clips', font=small, fill=INK)
    for i, (clip, fr, row) in enumerate(clips):
        x = left + i * (S + pad)
        img.paste(bg.crop((x, y, x + S, y + S)), (x, y))
        put(img, cell('ghost_bu', clip, fr, row), x, y, S / 256)
        d.text((x + 4, y + S + 2), '%s f%d %s' % (clip, fr, DIRS[row]), font=small, fill=INK)
    y += S + 24
    d.text((10, y + 60), 'bust (14 degrees)', font=small, fill=INK)
    for i, (cid, name) in enumerate((('ghost_bu', 'Bu'), ('ghost_hviske', 'Hviske'))):
        p = Image.open(ASSETS / cid / 'portrait.webp').convert('RGBA').resize((150, 150), Image.LANCZOS)
        x = left + i * 170
        d.rounded_rectangle((x - 2, y - 2, x + 152, y + 152), 12, outline=INK, width=2, fill=(226, 216, 244))
        img.alpha_composite(p, (x, y))
        d.text((x + 4, y + 154), name, font=small, fill=INK)
    save_small(img.crop((0, 0, W, y + 175)), REVIEW / 'contact_sheet_ghost.png')


# ---------------------------------------------------------------------------------------------------------------------
def ghost_sketch(w=300, h=270, scale=4):
    """Bu drawn with the rules of the Figurer v2 sheet: thick dark ink outline, flat fills, big dark eyes with a white glint, blush + three strokes."""
    W, H = w * scale, h * scale
    im = Image.new('RGB', (W, H), (207, 230, 242))
    d = ImageDraw.Draw(im)
    k = scale
    sheet_c = (238, 243, 255)
    shade = (199, 211, 238)
    line = 6 * k
    cx = W // 2
    d.line([(cx + 70 * k, 205 * k), (cx + 112 * k, 190 * k), (cx + 118 * k, 150 * k)], fill=INK, width=26 * k, joint='curve')
    d.line([(cx + 70 * k, 205 * k), (cx + 112 * k, 190 * k), (cx + 118 * k, 150 * k)], fill=sheet_c, width=16 * k, joint='curve')
    lobes = 5
    left, right = cx - 82 * k, cx + 82 * k
    hem = []
    for i in range(lobes * 2 + 1):
        t = i / (lobes * 2)
        x = left + (right - left) * t
        hem.append((x, 222 * k + (14 * k if i % 2 == 1 else 0)))
    body = [(cx - 50 * k, 120 * k), (cx - 78 * k, 190 * k)] + hem + [(cx + 78 * k, 190 * k), (cx + 50 * k, 120 * k)]
    d.polygon(body, fill=sheet_c, outline=INK)
    d.line(body + [body[0]], fill=INK, width=line, joint='curve')
    for sg in (-1, 1):
        d.ellipse((cx + sg * 80 * k - 18 * k, 168 * k - 20 * k, cx + sg * 80 * k + 18 * k, 168 * k + 24 * k), fill=sheet_c, outline=INK, width=5 * k)
    d.ellipse((cx - 72 * k, 38 * k, cx + 72 * k, 160 * k), fill=sheet_c, outline=INK, width=line)
    d.arc((cx - 52 * k, 128 * k, cx + 52 * k, 160 * k), 20, 160, fill=shade, width=5 * k)
    for sg in (-1, 1):
        ex = cx + sg * 30 * k
        d.ellipse((ex - 17 * k, 84 * k, ex + 17 * k, 126 * k), fill=(34, 30, 70), outline=INK, width=3 * k)
        d.ellipse((ex - 9 * k, 92 * k, ex - 1 * k, 104 * k), fill=(255, 255, 255))
        d.ellipse((ex + 5 * k, 112 * k, ex + 10 * k, 118 * k), fill=(255, 255, 255))
        bx = cx + sg * 50 * k
        d.ellipse((bx - 11 * k, 128 * k, bx + 11 * k, 140 * k), fill=(232, 160, 163))
        for j in (-1, 0, 1):
            d.line([(bx + j * 6 * k, 124 * k), (bx + j * 6 * k + sg * 2 * k, 140 * k)], fill=(168, 98, 112), width=2 * k)
    d.arc((cx - 12 * k, 118 * k, cx + 12 * k, 142 * k), 20, 160, fill=INK, width=3 * k)
    return im.resize((w, h), Image.LANCZOS)


def sketch():
    cap, cap19, small = fonts()
    if not GUIDE.exists():
        raise SystemExit(f'ERROR: {GUIDE} not found (the Figurer v2 render of the Style Guide)')
    g = Image.open(GUIDE).convert('RGB')
    cards = {'Rasmus': (548, 1076, 952, 1436), 'Bertil': (984, 1076, 1389, 1436), 'Kloevermynte': (548, 1666, 952, 2026)}
    CW, CH = 300, 270
    row1, bgs = [], {}
    for name, box in cards.items():
        im = g.crop(box).resize((CW, CH), Image.LANCZOS)
        bgs[name] = im.getpixel((12, 12))
        row1.append((name, im))
    row1.append(('Bu (our sketch, the sheet\'s rules)', ghost_sketch(CW, CH)))
    sketch_bg = (207, 230, 242)
    bakes = [('fox (Rasmus)', 'fox', bgs['Rasmus']), ('hobbit_pip (Bertil)', 'hobbit_pip', bgs['Bertil']), ('fairy (Kloevermynte)', 'fairy', bgs['Kloevermynte']),
             ('ghost_bu', 'ghost_bu', sketch_bg), ('ghost_hviske', 'ghost_hviske', sketch_bg)]
    row2 = []
    for name, cid, bg in bakes:
        im = Image.new('RGB', (CW, CH), bg).convert('RGBA')
        im.alpha_composite(sheet(cid, 'idle').crop((0, 0, 256, 256)), (int(CW / 2 - 128), int(CH * 0.90 - 200)))
        row2.append((name, im.convert('RGB')))
    n = max(len(row1), len(row2))
    canvas = Image.new('RGB', (CW * n + 10 * (n + 1), 70 + 2 * (CH + 36)), PAPER)
    d = ImageDraw.Draw(canvas)
    d.text((10, 8), 'Figurer v2 sketch cards (top) against the BAKED sprites (bottom), idle S, 1:1, same card colours', font=cap19, fill=INK)
    for i, (nm, im) in enumerate(row1):
        canvas.paste(im, (10 + i * (CW + 10), 44))
        d.text((14 + i * (CW + 10), 44 + CH + 4), 'sketch: ' + nm, font=small, fill=INK)
    for i, (nm, im) in enumerate(row2):
        canvas.paste(im, (10 + i * (CW + 10), 44 + CH + 36))
        d.text((14 + i * (CW + 10), 44 + 2 * CH + 40), 'baked: ' + nm, font=small, fill=INK)
    save_small(canvas, REVIEW / 'sketch_vs_baked.png')


# ---------------------------------------------------------------------------------------------------------------------
# crops of the 1280 x 720 shots of tests/sections/art_ghost.gd (CAST rows at Camera zoom 0.4: x 460..930, y 215..420; zoom 0.9: the cast fills the left 1000 x 450)
CROP04 = (440, 205, 950, 425)
CROP09 = (0, 0, 1000, 450)


def gamezoom(shots: Path):
    cap, cap19, small = fonts()
    names = {'a': 'art_ghost_cast_noon_zoom04.png', 'b': 'art_ghost_cast_noon_zoom09.png', 'c': 'art_ghost_cast_night_zoom04.png'}
    for k, n in names.items():
        if not (shots / n).exists():
            raise SystemExit(f'ERROR: {shots / n} missing: run tools/dev/run_windowed.sh --only=art_ghost --out={shots}')
    a = Image.open(shots / names['a']).convert('RGB').crop(CROP04)
    b = Image.open(shots / names['b']).convert('RGB').crop(CROP09)
    c = Image.open(shots / names['c']).convert('RGB').crop(CROP04)
    A = a.resize((a.size[0] * 2, a.size[1] * 2), Image.NEAREST)
    C = c.resize((c.size[0] * 2, c.size[1] * 2), Image.NEAREST)
    W = max(A.size[0], b.size[0]) + 20
    H = 10 + 40 + A.size[1] + 36 + 40 + C.size[1] + 36 + 40 + b.size[1] + 16
    canvas = Image.new('RGB', (W, H), PAPER)
    d = ImageDraw.Draw(canvas)
    y = 8
    d.text((10, y), 'Day 11:00, zoom 0.4 (windowed Godot, 1280 x 720; crop x2, nearest = true screen pixels)', font=cap19, fill=INK)
    y += 34
    canvas.paste(A, (10, y))
    y += A.size[1] + 4
    d.text((10, y), 'columns: fox, hobbit_pip, fairy (the pack) | Bu | Hviske      rows (top to bottom): facing SE, SW, S', font=small, fill=INK)
    y += 30
    d.text((10, y), 'Night 23:00, zoom 0.4, same crop: the night grade, NO baked glow (the glow is a light of G-ghost-play)', font=cap19, fill=INK)
    y += 34
    canvas.paste(C, (10, y))
    y += C.size[1] + 10
    d.text((10, y), 'Zoom 0.9 (about the dialogue scale), 1:1', font=cap19, fill=INK)
    y += 30
    canvas.paste(b, (10, y))
    save_small(canvas, REVIEW / 'gamezoom_check.png')


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('The labels are English')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--shots', help='--out folder of the windowed art_ghost run (adds gamezoom_check.png)')
    ap.add_argument('--only', choices=['contact', 'sketch', 'gamezoom'])
    a = ap.parse_args()
    REVIEW.mkdir(parents=True, exist_ok=True)
    if a.only in (None, 'contact'):
        contact()
    if a.only in (None, 'sketch'):
        sketch()
    if a.only == 'gamezoom' or (a.only is None and a.shots):
        if not a.shots:
            raise SystemExit('ERROR: gamezoom needs --shots DIR')
        gamezoom(Path(a.shots))
    return 0


if __name__ == '__main__':
    sys.exit(main())
