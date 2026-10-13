#!/usr/bin/env python3
"""Regenerates the review sheets of package P21 into tools/art/characters/review/ from the INSTALLED assets (what the game loads).

  python tools/art/characters/review_sheets.py                              # the sheets that need no window (contact sheets, animation rows, portraits, feet)
  python tools/art/characters/review_sheets.py --screenshots DIR            # + the windowed cast screenshots of `tools/dev/run_windowed.sh --only=art_characters --out=DIR`
  python tools/art/characters/review_sheets.py --only anim_hobbits_rows_S_SE detail_hobbit_feet_x4

The quality gates of the work order are judged by a human on these pictures (README.md of this folder names the sheet of every gate):
  gate 2  contact_cast_next_to_pack_S / _SE, contact_busts            the whole cast at game scale next to bear cat rabbit bat fox fairy
  gate 3  cast_pack_and_new_zoom04, cast_closeup_1..4                 windowed, Camera zoom 0.4 (and 0.9) on grass, 1280 x 720  (needs --screenshots)
  gate 4  anim_*                                                      rows S and SE of the hobbits, squirrel, fairy NPCs, villagers, quadrupeds; the boss spin from all 8 sides
  gate 5  detail_hobbit_feet_x4 (+ _before)                           the hobbits' feet at the true game scale, magnified 4x (needs --screenshots)
  gate 6  portraits_96px, portraits_150px, pack_busts_new_vs_old      the busts at the sizes the dialogue box uses

Every PNG is converted to a 256-colour palette image (PIL median cut, optimised): the contact sheets stay below ~400 KB each, the whole folder a few MB.
Needs the project venv (Pillow).  Nothing here is read by the game (tools/art/.gdignore hides the folder from Godot).
"""
import argparse, os, subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
CORE = HERE.parent / 'core'
sys.path.insert(0, str(CORE))
import artcontract as ac            # noqa: E402

NEW = ['hobbit_pip', 'hobbit_moss', 'hobbit_bramble', 'squirrel', 'fairy_dusk', 'fairy_stardust', 'fairy_mayor', 'fairy_baker', 'fairy_shopkeeper',
       'fairy_king', 'fairy_wizard', 'fairy_lily', 'fairy_builder', 'fairy_furnisher', 'fairy_tailor', 'mouse_pippin', 'cat_morfar_mis', 'bear_guard',
       'rabbit_farmer', 'raccoon_smith', 'penguin_postman', 'chick', 'hen', 'duck', 'kitten', 'bunny', 'fox_cub', 'lamb', 'calf', 'owl', 'puppy', 'fawn',
       'ugleoje', 'tornebusk', 'lysesvamp', 'snurresvamp']
NEXT_TO = ['bear', 'cat', 'rabbit', 'bat', 'fox', 'fairy']          # the pack characters of gate 2
BG = (244, 239, 227)


def font(size):
    for p in ['/System/Library/Fonts/Helvetica.ttc', '/System/Library/Fonts/Supplemental/Arial.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def save_small(im: Image.Image, path: Path) -> None:
    """RGB -> 256-colour palette PNG (median cut, no dither), optimised."""
    path.parent.mkdir(parents=True, exist_ok=True)
    im.convert('RGB').quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(path, optimize=True)
    print('%-44s %5d x %-5d %4d KB' % (path.name, im.width, im.height, path.stat().st_size // 1024))


def run_tool(script: str, args: list, out: Path, tmp: Path) -> None:
    """core/cast_sheet.py or core/contact_sheet.py into a temporary file, then the small-PNG save."""
    t = tmp / ('tmp_' + out.name)
    subprocess.run([sys.executable, str(CORE / script)] + args + ['--out', str(t)], check=True, stdout=subprocess.DEVNULL)
    save_small(Image.open(t), out)
    t.unlink()


def portrait_files(root: Path, portraits: Path, pack_first: bool = False, pack=None):
    """[(label, file)] of the 36 new characters (their own portrait.webp) and the pack busts (assets/portraits/<id>.webp, TTPortraits' first choice)."""
    new = [(c, root / c / 'portrait.webp') for c in NEW]
    old = [(c + ' (pack)', portraits / (c + '.webp')) for c in (pack or ac.PACK_IDS)]
    return old + new if pack_first else new + old


def portrait_sheet(root: Path, portraits: Path, size: int, cols: int, out: Path, pack_first: bool = False, pack=None) -> None:
    items = portrait_files(root, portraits, pack_first, pack)
    rows = (len(items) + cols - 1) // cols
    f = font(12 if size < 120 else 13)
    sheet = Image.new('RGB', (size * cols, (size + 16) * rows), BG)
    d = ImageDraw.Draw(sheet)
    for i, (label, p) in enumerate(items):
        im = Image.open(p).convert('RGBA').resize((size, size), Image.LANCZOS)
        x, y = (i % cols) * size, (i // cols) * (size + 16)
        d.text((x + 4, y + 1), label, fill=(43, 35, 64), font=f)
        sheet.paste(im, (x, y + 16), im)
    save_small(sheet, out)


def pack_busts_sheet(root: Path, portraits: Path, out: Path) -> None:
    """Per pack character: the NEW head-and-shoulders bust (assets/portraits/<id>.webp) above the OLD full-body crop (<id>/portrait.webp of the pack folder)."""
    cell, cols = 200, 6
    f = font(13)
    sheet = Image.new('RGB', (cell * cols, cell * 4), BG)
    d = ImageDraw.Draw(sheet)
    for i, c in enumerate(ac.PACK_IDS):
        x, y = (i % cols) * cell, (i // cols) * cell * 2
        new = Image.open(portraits / (c + '.webp')).convert('RGBA').resize((cell, cell), Image.LANCZOS)
        old = Image.open(root / c / 'portrait.webp').convert('RGBA').resize((cell, cell), Image.LANCZOS)
        sheet.paste(new, (x, y), new)
        sheet.paste(old, (x, y + cell), old)
        d.text((x + 6, y + 4), c + ' (bust)', fill=(43, 35, 64), font=f)
        d.text((x + 6, y + cell + 4), c + ' (old crop)', fill=(43, 35, 64), font=f)
    save_small(sheet, out)


# the cast screenshot is laid out by tests/sections/art_characters.gd (CAST_ROWS, CAST_STEP) at Camera zoom 0.4, camera at the origin, 1280 x 720:
# column c of row r stands at x = 640 + 0.4 * (-240 * 5.5 + 240 * c) = 112 + 96 c, feet at y = 360 + 0.4 * (-250 * 1.5 + 250 * r) = 210 + 100 r
HOBBIT_COLUMNS = [6, 7, 8, 9]          # hobbit_pip, hobbit_moss, hobbit_bramble, squirrel in row 0 of the cast screenshot


def feet_crop(shot: Path, out: Path) -> None:
    """The four figures of row 0 (3 hobbits + the squirrel) cut out of the REAL zoom-0.4 screenshot and magnified 4x with nearest neighbour."""
    im = Image.open(shot).convert('RGB')
    k = im.width / 1280.0
    tiles = []
    for c in HOBBIT_COLUMNS:
        cx, fy = (112 + 96 * c) * k, 210 * k
        tiles.append(im.crop((int(cx - 45 * k), int(fy - 75 * k), int(cx + 45 * k), int(fy + 15 * k))))
    w, h = tiles[0].size
    strip = Image.new('RGB', (w * len(tiles), h))
    for i, t in enumerate(tiles):
        strip.paste(t, (i * w, 0))
    save_small(strip.resize((strip.width * 4, strip.height * 4), Image.NEAREST), out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('The quality gates')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--root', default=str(REPO / 'assets' / 'isometric_characters'))
    ap.add_argument('--portraits', default=str(REPO / 'assets' / 'portraits'))
    ap.add_argument('--out', default=str(HERE / 'review'))
    ap.add_argument('--screenshots', help='--out dir of the windowed art_characters run: adds the cast screenshots and the feet crop')
    ap.add_argument('--feet-before', metavar='PNG', help='a cast_pack_and_new_zoom04 screenshot taken BEFORE the hobbit feet fix: written as detail_hobbit_feet_x4_before.png (a one-off, the old sheets are not reproducible)')
    ap.add_argument('--only', nargs='*', help='sheet names (without .png) to regenerate; default all that can be made')
    a = ap.parse_args()
    root, portraits, out = Path(a.root), Path(a.portraits), Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    want = (lambda n: not a.only or n in a.only)

    def cast(name, extra):
        if want(name):
            run_tool('cast_sheet.py', ['--root', str(root), '--cell', '128', '--cols', '10'] + extra + NEXT_TO + NEW, out / (name + '.png'), out)
    cast('contact_cast_next_to_pack_S', ['--row', '0'])
    cast('contact_cast_next_to_pack_SE', [])
    if want('contact_busts'):      # the busts the dialogue box shows: the pack ones from assets/portraits (the new head-and-shoulders busts), the new ones from their folder
        portrait_sheet(root, portraits, 128, 10, out / 'contact_busts.png', pack_first=True, pack=NEXT_TO)

    def rows(name, chars, clips, rws, maxcols, scale='0.4'):
        if want(name):
            run_tool('contact_sheet.py', ['--root', str(root), '--chars'] + chars + ['--clips'] + clips + ['--rows'] + [str(r) for r in rws]
                     + ['--scale', scale, '--maxcols', str(maxcols)], out / (name + '.png'), out)
    rows('anim_hobbits_rows_S_SE', ['hobbit_pip', 'hobbit_moss', 'hobbit_bramble'], ['idle', 'walk', 'run', 'talk', 'hit'], [0, 7], 6)
    rows('anim_squirrel_rows_S_SE', ['squirrel'], ['walk', 'run', 'talk', 'hit'], [0, 7], 6)
    rows('anim_fairy_npcs_rows_S_SE', ['fairy_mayor', 'fairy_lily', 'fairy_builder', 'fairy_furnisher', 'fairy_tailor'], ['hover', 'talk', 'celebrate', 'interact'], [0, 7], 6)
    rows('anim_villagers_rows_S_SE', ['mouse_pippin', 'cat_morfar_mis', 'bear_guard', 'rabbit_farmer', 'raccoon_smith', 'penguin_postman'], ['walk', 'talk'], [0, 7], 6)
    rows('anim_quadrupeds', ['puppy', 'lamb', 'calf'], ['walk', 'run', 'hit'], [0, 7], 6)
    rows('anim_boss_spin_all_8_sides', ['snurresvamp'], ['spin'], list(range(8)), 8)
    rows('anim_boss_attack_hit_walk', ['snurresvamp'], ['attack', 'hit', 'walk'], [0, 7], 6)

    if want('portraits_96px'):
        portrait_sheet(root, portraits, 96, 12, out / 'portraits_96px.png')
    if want('portraits_150px'):
        portrait_sheet(root, portraits, 150, 8, out / 'portraits_150px.png')
    if want('pack_busts_new_vs_old'):
        pack_busts_sheet(root, portraits, out / 'pack_busts_new_vs_old.png')

    if a.screenshots:
        shots = Path(a.screenshots)
        names = {'cast_pack_and_new_zoom04': 'art_characters_cast_pack_and_new_zoom04.png',
                 'cast_closeup_1_pack_and_mayor_to_lily': 'art_characters_cast_closeup_1_pack_and_mayor_to_lily.png',
                 'cast_closeup_2_players_and_builder_to_oak': 'art_characters_cast_closeup_2_players_and_builder_to_oak.png',
                 'cast_closeup_3_rosa_to_animals': 'art_characters_cast_closeup_3_rosa_to_animals.png',
                 'cast_closeup_4_farm_animals_and_pack': 'art_characters_cast_closeup_4_farm_animals_and_pack.png'}
        for name, src in names.items():
            if want(name):
                if not (shots / src).exists():
                    print('MISSING screenshot', shots / src); return 2
                save_small(Image.open(shots / src), out / (name + '.png'))
        if want('detail_hobbit_feet_x4'):
            feet_crop(shots / names['cast_pack_and_new_zoom04'], out / 'detail_hobbit_feet_x4.png')
    if a.feet_before and want('detail_hobbit_feet_x4_before'):
        feet_crop(Path(a.feet_before), out / 'detail_hobbit_feet_x4_before.png')
    if not a.screenshots:
        print('(no --screenshots DIR: the windowed cast screenshots and the feet crop were not regenerated)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
