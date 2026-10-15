#!/usr/bin/env python3
"""The review sheets of package V2-cast-art, written to tools/art/cast_v2/review_v2/ (the lead LOOKS at them; README.md names every one).

  python tools/art/cast_v2/review_v2.py                      # compare_<figure>.png x 13, contact_cast_v2.png (no window, no Godot)
  python tools/art/cast_v2/review_v2.py --ab                 # + outline_ink_vs_pack.png (bakes 14 idle frames twice: pack outline / guide ink; needs the stage GLBs it builds itself)
  python tools/art/cast_v2/review_v2.py --shots DIR          # + cast_next_to_pack_zoom04.png and cast_closeup_zoom09.png from the windowed run of
                                                             #   `tools/dev/run_windowed.sh --only=art_cast_v2 --out=DIR` (art_cast_v2_cast_zoom04.png, art_cast_v2_cast_closeup_zoom09.png)

Sources: the sketch panels are cut from docs/Traetoppen Style Guide Review/refs/figurer_v2_render.png (the user's export, read only); the baked figures come from
assets/isometric_characters (installed) and, for the two RESTYLES that are baked into the stage but not installed (see README "Install order"), from
tools/art/_stage/v2cast/assets - run tools/art/cast_v2/produce_cast_v2.sh first.  The four heroes of the sheet that A2 bakes (Rasmus, Bertil, Bodil, Kiki) are shown
next to the STOCK figure that stands in for them until A2 lands (fox, hobbit_pip, hobbit_pip, monkey); Hoppe is the pack rabbit.
Every PNG is converted to a 256-colour palette image (median cut) so that the folder stays small.
"""
import argparse
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ART = HERE.parent
REPO = ART.parents[1]
sys.path[:0] = [str(HERE), str(ART / 'generator'), str(ART / 'core')]
os.environ.setdefault('PYTHONDONTWRITEBYTECODE', '1')

RENDER = REPO / 'docs' / 'Trætoppen Style Guide Review' / 'refs' / 'figurer_v2_render.png'
CH = REPO / 'assets' / 'isometric_characters'
STAGE = ART / '_stage' / 'v2cast' / 'assets' / 'isometric_characters'
PORT = REPO / 'assets' / 'portraits'
OUT = HERE / 'review_v2'
BG = (231, 216, 182)
PAPER = (244, 230, 196)
INK = (43, 35, 64)
XS = [111, 548, 985]                       # left edge of the three card columns in the render (px)

# figure -> (render row, column, art id, note)
FIGURES = {
    'hoppe': (0, 0, 'rabbit', 'the pack rabbit: no new art (dE00 1.4)'),
    'brumme': (0, 1, 'bear_brumme', ''),
    'morfar_mis': (0, 2, 'cat_morfar_mis', 'RESTYLE in place (baked in the stage, installed on request)'),
    'natteblik': (1, 0, 'bat_natteblik', ''),
    'rasmus': (1, 1, 'fox', 'hero: A2 bakes fox_base; the stock fox stands in'),
    'bertil': (1, 2, 'hobbit_pip', 'hero: A2 bakes hobbit_pip_base; the stock hobbit stands in'),
    'bodil': (2, 0, 'hobbit_pip', 'hero: A2 bakes hobbit_bodil_base; the stock hobbit stands in'),
    'kloevermynte': (2, 1, 'fairy_shopkeeper', 'RESTYLE in place (baked in the stage, installed on request)'),
    'birk': (2, 2, 'fairy_birk_npc', ''),
    'pip': (3, 0, 'hedgehog_pip', ''),
    'fru_ugle': (3, 1, 'owl_fru_ugle', ''),
    'sofus': (3, 2, 'capybara_sofus', 'the one new body'),
    'kiki': (4, 0, 'monkey', 'hero: A2 bakes monkey_base; the stock monkey stands in'),
}
CAST = ['bear_brumme', 'bat_natteblik', 'hedgehog_pip', 'owl_fru_ugle', 'capybara_sofus', 'fairy_birk_npc', 'fairy_shopkeeper', 'cat_morfar_mis']
HEROES = [('Rasmus (fox)', 'fox'), ('Kiki (monkey)', 'monkey'), ('Bertil (hobbit_pip)', 'hobbit_pip'), ('Bodil (stand-in hobbit_pip)', 'hobbit_pip'),
          ('Kloevermynte (pack fairy)', 'fairy'), ('Birk (fairy_birk_npc)', 'fairy_birk_npc')]


def font(size):
    for p in ['/System/Library/Fonts/Helvetica.ttc', '/System/Library/Fonts/Supplemental/Arial.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def save_small(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.convert('RGB').quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(path, optimize=True)
    print('%-34s %5d x %-5d %4d KB' % (path.name, im.width, im.height, path.stat().st_size // 1024))


def panel(row: int, col: int) -> Image.Image:
    im = Image.open(RENDER).convert('RGB')
    x0, y0 = XS[col] + 2, int(487 + 590.5 * row) + 1
    return im.crop((x0, y0, x0 + 401, y0 + 358))


def root_of(cid: str):
    """The folder holding the freshest art of an id: the stage for the restyled two (when baked), else the installed folder."""
    if cid in ('fairy_shopkeeper', 'cat_morfar_mis') and (STAGE / cid / 'idle.webp').exists():
        return STAGE
    return CH


def cell(cid: str, row: int, frame: int = 0, clip: str = 'idle') -> Image.Image:
    sh = Image.open(root_of(cid) / cid / (clip + '.webp')).convert('RGBA')
    return sh.crop((frame * 256, row * 256, frame * 256 + 256, row * 256 + 256))


def bust(cid: str) -> Image.Image:
    for p in (PORT / (cid + '.webp'), root_of(cid) / cid / 'portrait.webp'):
        if p.exists():
            return Image.open(p).convert('RGBA')
    raise SystemExit('no bust for ' + cid)


def on_bg(img: Image.Image, bg=BG) -> Image.Image:
    b = Image.new('RGB', img.size, bg)
    b.paste(img, (0, 0), img)
    return b


def compare_sheets() -> None:
    f = font(13)
    for key, (r, c, cid, note) in FIGURES.items():
        sh = Image.new('RGB', (401 + 10 + 3 * 266, 358), PAPER)
        sh.paste(panel(r, c), (0, 0))
        d = ImageDraw.Draw(sh)
        d.text((6, 4), 'Figurer v2: %s' % key, fill=INK, font=f)
        for j, im in enumerate([bust(cid), cell(cid, 0), cell(cid, 7)]):
            sh.paste(on_bg(im), (411 + j * 266, 14))
        src = 'stage' if root_of(cid) == STAGE else 'installed'
        d.text((411, 1), '%s  (%s)   bust (ink outline) | idle S | idle SE' % (cid, src), fill=INK, font=f)
        if note:
            d.text((411, 288), note, fill=INK, font=f)
        d.text((411, 306), 'soft CG render of the stock rig: the sheet is a shape sketch (formskitse), poses are upright', fill=(90, 80, 110), font=f)
        save_small(sh, OUT / ('compare_%s.png' % key))


def contact_sheet() -> None:
    f = font(13)
    S = 192
    cols = [('bust', None), ('idle S', (0, 0, 'idle')), ('idle SE', (7, 0, 'idle')), ('idle W', (2, 0, 'idle')), ('talk f2 SE', (7, 2, 'talk')), ('walk / hover f3 SE', (7, 3, None))]
    sh = Image.new('RGB', (S * len(cols) + 140, (S + 6) * len(CAST) + 24), PAPER)
    d = ImageDraw.Draw(sh)
    for ci, (title, _) in enumerate(cols):
        d.text((140 + ci * S + 4, 4), title, fill=INK, font=f)
    for ri, cid in enumerate(CAST):
        y = 22 + ri * (S + 6)
        d.text((6, y + S // 2 - 8), cid, fill=INK, font=f)
        for ci, (title, spec) in enumerate(cols):
            if spec is None:
                im = bust(cid)
            else:
                row, frame, clip = spec
                if clip is None:
                    clip = 'hover' if 'hover' in __import__('json').loads((root_of(cid) / cid / 'animations.json').read_text())['animations'] else 'walk'
                try:
                    im = cell(cid, row, frame, clip)
                except FileNotFoundError:
                    continue
            sh.paste(on_bg(im.resize((S, S), Image.LANCZOS)), (140 + ci * S, y))
    save_small(sh, OUT / 'contact_cast_v2.png')


# ---------------------------------------------------------------------------------------------------------------------
# the outline A/B: the same GLB baked with the pack outline (75,60,73) .55 and with the guide ink (43,35,64) .92
# ---------------------------------------------------------------------------------------------------------------------
def outline_ab() -> None:
    import artpaths
    stage = artpaths.assert_stage_dir(ART / '_stage' / 'v2cast_ab')
    glb = stage / 'glb'
    os.environ['TT_ART_GLB'] = str(glb)
    glb.mkdir(parents=True, exist_ok=True)
    import build_assets as ba
    import bake_sprite_atlases as bk
    import artcontract as ac
    ids = [cid for _, cid in HEROES] + CAST
    frames = {}
    for cid in dict.fromkeys(ids):
        maker = ba.TT_BUILDERS.get(cid) or ba.BUILDERS.get(cid, getattr(ba.geo, 'make_' + cid, None))
        ba.export(maker(), glb)
        r = bk.Renderer(cid, 256, glb)
        pair = {}
        for name, outline in (('pack', ac.OUTLINE), ('ink', ac.INK)):
            bk.OUTLINE.update(outline)
            pair[name] = r.frame(315, 'idle', 0.0)
        bk.OUTLINE.update(ac.OUTLINE)
        r.close()
        frames[cid] = pair
    grass = (143, 179, 92)
    f = font(12)
    labels = [(l, c) for l, c in HEROES] + [(c, c) for c in CAST]
    # block 1: game zoom 0.4 (a 256 cell is 102 px), pack | ink side by side on grass, magnified 2x with nearest neighbour so that a human can see the pixels
    cw, ch = 2 * 108, 112
    cols = 5
    rows = (len(labels) + cols - 1) // cols
    block = Image.new('RGB', (cw * cols, ch * rows), grass)
    for i, (label, cid) in enumerate(labels):
        x, y = (i % cols) * cw, (i // cols) * ch
        for j, name in enumerate(('pack', 'ink')):
            small = frames[cid][name].resize((102, 102), Image.LANCZOS)
            block.paste(small, (x + j * 108 + 3, y + 6), small)
        ImageDraw.Draw(block).text((x + 4, y + 1), label[:28], fill=INK, font=f)
    block = block.resize((block.width * 2, block.height * 2), Image.NEAREST)
    # block 2: four figures at 1:1 (pack | ink)
    sel = ['bear_brumme', 'fairy_birk_npc', 'hedgehog_pip', 'capybara_sofus']
    big = Image.new('RGB', (2 * 256 * 2, 256 * 2), grass)
    for i, cid in enumerate(sel):
        for j, name in enumerate(('pack', 'ink')):
            big.paste(frames[cid][name], ((i % 2) * 512 + j * 256, (i // 2) * 256), frames[cid][name])
    W = max(block.width, big.width)
    sh = Image.new('RGB', (W, block.height + big.height + 60), PAPER)
    d = ImageDraw.Draw(sh)
    ff = font(14)
    d.text((8, 6), 'Outline A/B, idle SE: LEFT of every pair = the pack outline (75,60,73) alpha .55 (what the world sprites use), RIGHT = the guide ink #2b2340 alpha .92', fill=INK, font=ff)
    d.text((8, 24), 'Top: game zoom 0.4 on grass, magnified 2x. Heroes (stock stand-ins until A2 bakes its bases) first, then the eight NPCs. The world outline stays the pack\'s until the user decides.', fill=INK, font=ff)
    sh.paste(block, (0, 48))
    d.text((8, 48 + block.height + 2), 'Below: 1:1 (pack | ink) of Brumme, Birk, Pip, Sofus.', fill=INK, font=ff)
    sh.paste(big, (0, 48 + block.height + 22))
    save_small(sh, OUT / 'outline_ink_vs_pack.png')


def shots(dirpath: Path) -> None:
    for src, dst in (('art_cast_v2_cast_zoom04.png', 'cast_next_to_pack_zoom04.png'), ('art_cast_v2_cast_closeup_zoom09.png', 'cast_closeup_zoom09.png')):
        p = dirpath / src
        if not p.exists():
            raise SystemExit('missing screenshot %s (run tools/dev/run_windowed.sh --only=art_cast_v2 --out=DIR)' % p)
        save_small(Image.open(p), OUT / dst)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('Sources:')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--ab', action='store_true')
    ap.add_argument('--shots', metavar='DIR')
    a = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    compare_sheets()
    contact_sheet()
    if a.ab:
        outline_ab()
    if a.shots:
        shots(Path(a.shots))
    return 0


if __name__ == '__main__':
    sys.exit(main())
