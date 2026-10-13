#!/usr/bin/env python3
"""Numbers behind the cast gates of P21 (plan 6.4 item 2): figure height, outline colour and PIVOT placement of every character,
measured on the baked sheets and compared with the shipped pack.  Never a replacement for LOOKING at the contact sheets: it measures
NOTHING about eyes or faces (eye style and face grammar are judged on the contact sheets in tools/art/characters/review/).

  python tools/art/characters/measure_cast.py                          # roster in assets/isometric_characters vs the pack there
  python tools/art/characters/measure_cast.py --root tools/art/_stage/assets/isometric_characters [ids...]
  python tools/art/characters/measure_cast.py --check                  # exit 1: a PEOPLE-sized figure outside +/-10 % of the pack, a wrong outline,
                                                                       #         or ANY figure off the contract pivot (128, 200)
  python tools/art/characters/measure_cast.py --selftest               # proves the pivot check fires on synthetic shifted sheets (exit 1 if not)

What it measures (idle sheet, row SE = 7 and row S = 0, frame 0; alpha > 24 is "figure"):
  height_px   bounding-box height of the figure incl. hair / hats / ears (the pack fairy includes its bun)
  outline     the median RGB of the pixels whose alpha is 130..150 and which touch transparent pixels = the pack outline (75,60,73) at
              alpha .55 (glowing creatures are excluded: their halo is blended under the outline)
  ratio       height / pack reference, where the pack reference is the mean figure height of bear cat rabbit fox fairy (the four sketch
              characters minus the bat, whose 2.8 m wingspan makes its body height meaningless, plus fox and fairy)

People-sized characters (hobbits, squirrel, fairies, villagers) must be within +/-10 % of the pack mean; baby farm animals, small
creatures and the boss are sized by design (their target heights are listed in DESIGN_HEIGHT_M below) and are only reported.

The PIVOT check (review defect "no check ties a figure to the contract pivot (128, 200)"), on EVERY sheet of the folder, every frame:
  x   the camera orbits the vertical axis through the pivot, so the silhouettes of the 8 direction rows are rotations about that axis:
      the mean of the 8 bounding-box centres is the pivot x (127.5 in pixel-index terms) and the centres of opposed rows (S/N, SW/NE,
      W/E, NW/SE) are mirror images (sum 255).  Measured on the pack and all 36 new characters: mean 127.4 .. 127.6 in every clip
      and frame, mirror sums within 2.5 of 255.  Limits: mean +/-3 px, mirror +/-5 px (any sideways shift of 4 px / one shifted row).
  y   the lowest figure pixel of a row (soles, front toes, outline) vs the pivot y 200: the 8-row mean must be inside FEET_WINDOW of the
      body class and every single row inside ROW_FEET_LIMITS.  Measured: upright figures 201 .. 212 (hobbit 211, penguin 212), the
      quadruped rig (calf lamb puppy fawn, pack capybara) 218 .. 224.  Only grounded clips are held to y: jump / fall / land and the
      flight clips (takeoff hover fly flight_land) lift the figure by design.
"""
import argparse, json, sys
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE.parent / 'core'))
import artcontract as ac            # noqa: E402

PACK_REFERENCE = ['bear', 'cat', 'rabbit', 'fox', 'fairy']
PEOPLE = ['hobbit_pip', 'hobbit_moss', 'hobbit_bramble', 'squirrel', 'fairy_dusk', 'fairy_stardust', 'fairy_mayor', 'fairy_baker',
          'fairy_shopkeeper', 'fairy_king', 'fairy_wizard', 'fairy_lily', 'fairy_builder', 'fairy_furnisher', 'fairy_tailor',
          'mouse_pippin', 'cat_morfar_mis', 'bear_guard', 'rabbit_farmer', 'raccoon_smith', 'penguin_postman']
# designed target heights in metres (m.height of the builders): animals and creatures are deliberately smaller / bigger than people
DESIGN_HEIGHT_M = {'chick': 1.05, 'hen': 1.35, 'duck': 1.1, 'kitten': 1.3, 'bunny': 1.45, 'fox_cub': 1.55, 'lamb': 1.35, 'calf': 1.55,
                   'owl': 1.4, 'puppy': 1.25, 'fawn': 1.5, 'ugleoje': 1.75, 'tornebusk': 1.8, 'lysesvamp': 1.2, 'snurresvamp': 2.1}
TOLERANCE = 0.10
GLOWING = ['lysesvamp']
SPRITE_ALPHA = 24

# --- the pivot contract (see the docstring) --------------------------------------------------------------------------
PIVOT_X_CENTRE = ac.PIVOT[0] - 0.5            # bbox centre (pixel indices) of a figure standing on the pivot: 127.5
PIVOT_X_TOL = 3.0                              # limit of |mean of the 8 row centres - 127.5|
MIRROR_TOL = 5.0                               # limit of |centre(row) + centre(opposed row) - 255|
QUADRUPEDS = ['calf', 'lamb', 'puppy', 'fawn', 'capybara']     # the quadruped rig: its body is long, the lowest pixel sits lower
FLYERS = ['bat']                                                # a 2.8 m wingspan: the wing tips set the lowest / highest pixel of a row
# 8-row mean of the lowest figure pixel, window by body class (pivot y 200 +): upright measured 198.1 .. 212.8, quadruped 215.1 .. 224.4,
# glowing (the baked halo is blended below the feet) 214.1 .. 217.0, bat 201.5 .. 207.9
FEET_WINDOW = {'upright': (ac.PIVOT[1] - 3, ac.PIVOT[1] + 16), 'quadruped': (ac.PIVOT[1] + 12, ac.PIVOT[1] + 28),
               'glow': (ac.PIVOT[1] + 8, ac.PIVOT[1] + 22), 'flyer': (ac.PIVOT[1] - 3, ac.PIVOT[1] + 16)}
# every single row of every grounded frame: upright measured 194 .. 224, quadruped 209 .. 239, glowing 212 .. 218, bat 185 .. 217
ROW_FEET_LIMITS = {'upright': (ac.PIVOT[1] - 12, ac.PIVOT[1] + 26), 'quadruped': (ac.PIVOT[1] + 6, ac.PIVOT[1] + 44),
                   'glow': (ac.PIVOT[1] + 4, ac.PIVOT[1] + 32), 'flyer': (ac.PIVOT[1] - 22, ac.PIVOT[1] + 26)}
# clips that lift the figure off the ground by design: x is still checked, y is not
AIRBORNE_CLIPS = ['jump', 'fall', 'land', 'takeoff', 'hover', 'fly', 'flight_land']


def sheet(root: Path, cid: str, clip: str = 'idle'):
    for ext in ('.webp', '.png'):
        p = root / cid / (clip + ext)
        if p.exists():
            return Image.open(p).convert('RGBA')
    return None


def cell(sh: Image.Image, row: int, frame: int = 0) -> np.ndarray:
    return np.asarray(sh.crop((frame * 256, row * 256, frame * 256 + 256, row * 256 + 256)))


def figure_height(a: np.ndarray) -> int:
    ys = np.where((a[..., 3] > SPRITE_ALPHA).any(axis=1))[0]
    return int(ys.max() - ys.min() + 1) if len(ys) else 0


def outline_rgb(a: np.ndarray):
    """Median colour of the isolated outline pixels (alpha 130..150 next to alpha 0)."""
    al = a[..., 3].astype(int)
    band = (al >= 130) & (al <= 150)
    near_clear = np.zeros_like(band)
    clear = al == 0
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        near_clear |= np.roll(clear, (dy, dx), axis=(0, 1))
    m = band & near_clear
    if m.sum() < 30:
        return None, int(m.sum())
    return np.median(a[..., :3][m].astype(int), axis=0).astype(int).tolist(), int(m.sum())


def measure(root: Path, cid: str):
    sh = sheet(root, cid)
    if sh is None:
        return None
    best = {}
    for row, name in ((7, 'se'), (0, 's')):
        a = cell(sh, row)
        best[name] = figure_height(a)
    rgb, n = outline_rgb(cell(sh, 7))
    return {'height_se': best['se'], 'height_s': best['s'], 'outline': rgb, 'outline_px': n}


def body_class(cid: str) -> str:
    if cid in QUADRUPEDS:
        return 'quadruped'
    if cid in GLOWING:
        return 'glow'
    return 'flyer' if cid in FLYERS else 'upright'


def row_boxes(sh: np.ndarray, frame: int):
    """[(top, bottom, left, right)] of the 8 direction rows of one frame of a sheet (alpha array, H x W); None for an empty cell."""
    out = []
    for row in range(8):
        cell_a = sh[row * ac.CELL:(row + 1) * ac.CELL, frame * ac.CELL:(frame + 1) * ac.CELL] > SPRITE_ALPHA
        ys = np.where(cell_a.any(axis=1))[0]
        xs = np.where(cell_a.any(axis=0))[0]
        out.append((int(ys.min()), int(ys.max()), int(xs.min()), int(xs.max())) if len(ys) else None)
    return out


def pivot_problems(boxes, cls: str, check_y: bool = True) -> list:
    """Problems of one frame (8 row boxes from row_boxes) against the pivot contract; [] when the figure stands where it should."""
    if any(b is None for b in boxes):
        return ['blank row']
    out = []
    cx = [(b[2] + b[3]) / 2.0 for b in boxes]
    mean_cx = sum(cx) / 8.0
    if abs(mean_cx - PIVOT_X_CENTRE) > PIVOT_X_TOL:
        out.append('figure is %+.1f px off the pivot x (8-row mean of the bbox centres %.1f, want %.1f +/- %.0f)' % (
            mean_cx - PIVOT_X_CENTRE, mean_cx, PIVOT_X_CENTRE, PIVOT_X_TOL))
    for r in range(4):
        dev = cx[r] + cx[r + 4] - 2 * PIVOT_X_CENTRE
        if abs(dev) > MIRROR_TOL:
            out.append('rows %s/%s are not mirror images about the pivot (centres %.1f + %.1f, off by %+.1f px)' % (
                ac.DIRECTIONS[r], ac.DIRECTIONS[r + 4], cx[r], cx[r + 4], dev))
    if check_y:
        bottoms = [b[1] for b in boxes]
        mean_b = sum(bottoms) / 8.0
        lo, hi = FEET_WINDOW[cls]
        if not lo <= mean_b <= hi:
            out.append('feet line %.1f is outside %d..%d (%s, pivot y %d)' % (mean_b, lo, hi, cls, ac.PIVOT[1]))
        rlo, rhi = ROW_FEET_LIMITS[cls]
        bad = [ac.DIRECTIONS[i] + ':' + str(bottoms[i]) for i in range(8) if not rlo <= bottoms[i] <= rhi]
        if bad:
            out.append('lowest pixel of row(s) %s outside %d..%d' % (' '.join(bad), rlo, rhi))
    return out


def pivot_check_folder(root: Path, cid: str):
    """Every sheet and frame of one character folder against the pivot contract.  Returns (problems, sheets checked, frames checked, stats)."""
    meta_f = root / cid / 'animations.json'
    clips = None
    if meta_f.exists():
        try:
            clips = list(json.loads(meta_f.read_text()).get('animations', {}).keys())
        except (ValueError, OSError):
            clips = None
    if clips is None:
        clips = ['idle']
    problems, n_sheets, n_frames = [], 0, 0
    means_x, means_y = [], []
    cls = body_class(cid)
    for clip in clips:
        sh = sheet(root, cid, clip)
        if sh is None:
            problems.append('%s: sheet missing' % clip)
            continue
        a = np.asarray(sh)[..., 3]
        n_sheets += 1
        for f in range(a.shape[1] // ac.CELL):
            n_frames += 1
            boxes = row_boxes(a, f)
            probs = pivot_problems(boxes, cls, check_y=clip not in AIRBORNE_CLIPS)
            if all(b is not None for b in boxes):
                means_x.append(sum((b[2] + b[3]) / 2.0 for b in boxes) / 8.0)
                if clip not in AIRBORNE_CLIPS:
                    means_y.append(sum(b[1] for b in boxes) / 8.0)
            for pr in probs:
                if len(problems) < 8:
                    problems.append('%s f%d: %s' % (clip, f, pr))
    stats = {'x': (min(means_x), max(means_x)) if means_x else None, 'y': (min(means_y), max(means_y)) if means_y else None}
    return problems, n_sheets, n_frames, stats


def selftest() -> int:
    """The pivot check must accept a figure on the pivot and fire on every kind of misplacement (synthetic sheets, no assets needed)."""
    def fake_figure(dx=0, dy=0, row_dx=None, cls='upright'):
        """A 8-row, 1-frame alpha sheet: an ellipse standing with its sole on the pivot (shifted by dx/dy, row_dx = {row: extra dx})."""
        a = np.zeros((ac.CELL * 8, ac.CELL), np.uint8)
        foot_y = 205 + (14 if cls == 'quadruped' else 0)
        yy, xx = np.mgrid[0:ac.CELL, 0:ac.CELL]
        for row in range(8):
            sx = dx + (row_dx or {}).get(row, 0)
            # a body that is wider in the direction it faces (so rows differ), mirrored about the pivot for the opposed row
            lean = 12 * np.sin(np.radians(45 * row))
            ell = (((xx - (PIVOT_X_CENTRE + lean + sx)) / 40.0) ** 2 + ((yy - (foot_y + dy - 70)) / 70.0) ** 2) <= 1.0
            a[row * ac.CELL:(row + 1) * ac.CELL][ell] = 255
        return a
    cases = [  # name, sheet, class, expected "should be flagged"
        ('on the pivot (upright)', fake_figure(), 'upright', False),
        ('on the pivot (quadruped)', fake_figure(cls='quadruped'), 'quadruped', False),
        ('shifted 2 px sideways (inside the tolerance)', fake_figure(dx=2), 'upright', False),
        ('shifted 8 px sideways', fake_figure(dx=8), 'upright', True),
        ('shifted -10 px sideways', fake_figure(dx=-10), 'upright', True),
        ('ONE row shifted 12 px sideways', fake_figure(row_dx={2: 12}), 'upright', True),
        ('shifted 20 px down', fake_figure(dy=20), 'upright', True),
        ('shifted 20 px up', fake_figure(dy=-20), 'upright', True),
        ('quadruped sheet checked as upright', fake_figure(cls='quadruped'), 'upright', True),
    ]
    bad = 0
    for name, a, cls, expect in cases:
        probs = pivot_problems(row_boxes(a, 0), cls)
        ok = bool(probs) == expect
        bad += 0 if ok else 1
        print('%-48s %s  %s' % (name, 'flagged' if probs else 'accepted', 'ok' if ok else 'WRONG (expected %s)' % ('flagged' if expect else 'accepted')))
    print('measure_cast --selftest: %s' % ('the pivot check is blind to %d case(s)' % bad if bad else 'the pivot check accepts a figure on the pivot and flags every misplacement'))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('What it measures')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('ids', nargs='*')
    ap.add_argument('--root', action='append', help='folder(s) with <id>/idle.(webp|png); default assets/isometric_characters')
    ap.add_argument('--pack-root', default=str(REPO / 'assets' / 'isometric_characters'))
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--selftest', action='store_true', help='run the pivot check on synthetic sheets (it must accept a figure on the pivot and flag every shifted one)')
    ap.add_argument('--no-pivot', action='store_true', help='skip the pivot check of every sheet (it reads all clips and takes a few seconds)')
    ap.add_argument('--json', help='also write the measurements here')
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    roots = [Path(r) for r in a.root] if a.root else [REPO / 'assets' / 'isometric_characters']
    pack = Path(a.pack_root)
    ids = a.ids or (PEOPLE + [i for i in DESIGN_HEIGHT_M])
    ref = {c: measure(pack, c) for c in PACK_REFERENCE}
    if any(v is None for v in ref.values()):
        print('ERROR: pack reference characters missing in', pack); return 2
    pack_mean = float(np.mean([v['height_se'] for v in ref.values()]))
    pack_out = ref['bear']['outline']
    print('pack reference (idle SE, alpha>%d): %s  -> mean %.1f px; pack outline %s' % (
        SPRITE_ALPHA, ', '.join('%s %d' % (c, v['height_se']) for c, v in ref.items()), pack_mean, pack_out))
    print('%-18s %6s %6s %7s  %-16s %s' % ('id', 'h_se', 'h_s', 'ratio', 'outline', 'verdict'))
    bad, rows = 0, {}
    for cid in ids:
        m = None
        for r in roots:
            m = measure(r, cid)
            if m:
                break
        if m is None:
            print('%-18s MISSING' % cid); bad += 1; continue
        ratio = m['height_se'] / pack_mean
        oc = m['outline']
        verdict = []
        if cid in PEOPLE:
            if abs(ratio - 1) > TOLERANCE:
                verdict.append('HEIGHT %+.0f%% (limit +/-%d%%)' % ((ratio - 1) * 100, TOLERANCE * 100)); bad += 1
        elif cid in DESIGN_HEIGHT_M:
            verdict.append('design %.2f m' % DESIGN_HEIGHT_M[cid])
        if cid not in GLOWING:
            if oc is None:
                verdict.append('no outline pixels found')
            elif max(abs(oc[i] - pack_out[i]) for i in range(3)) > 8:
                verdict.append('OUTLINE %s != pack %s' % (oc, pack_out)); bad += 1
        rows[cid] = dict(m, ratio=round(ratio, 3))
        print('%-18s %6d %6d %6.0f%%  %-16s %s' % (cid, m['height_se'], m['height_s'], ratio * 100, oc if oc else '-', '; '.join(verdict) or 'ok'))
    pivot_bad = 0
    if not a.no_pivot:
        # the 12 pack characters are the contract by example: the check must accept them too (they are also the proof it is not too tight)
        pivot_ids = list(ids) if a.ids else list(ids) + list(ac.PACK_IDS)
        print()
        print('pivot (128, 200): x = 8-row mean of the bbox centres (want %.1f +/- %.0f) and opposed rows mirrored; y = 8-row mean of the lowest pixel'
              % (PIVOT_X_CENTRE, PIVOT_X_TOL))
        print('%-18s %-9s %7s %9s %17s %17s  %s' % ('id', 'class', 'sheets', 'frames', 'x mean min..max', 'feet y min..max', 'verdict'))
        for cid in pivot_ids:
            res = None
            for r in roots + ([pack] if cid in ac.PACK_IDS else []):
                if (r / cid).is_dir():
                    res = pivot_check_folder(r, cid)
                    break
            if res is None:
                print('%-18s MISSING' % cid); pivot_bad += 1; continue
            probs, n_sheets, n_frames, st = res
            sx = '%.1f..%.1f' % st['x'] if st['x'] else '-'
            sy = '%.1f..%.1f' % st['y'] if st['y'] else '-'
            print('%-18s %-9s %7d %9d %17s %17s  %s' % (cid, body_class(cid), n_sheets, n_frames, sx, sy, '; '.join(probs[:3]) if probs else 'ok'))
            if probs:
                pivot_bad += 1
    if a.json:
        Path(a.json).write_text(json.dumps({'pack_mean_height': pack_mean, 'pack_outline': pack_out, 'rows': rows}, indent=1))
    bad += pivot_bad
    print('measure_cast: %s' % ('%d problem(s)' % bad if bad else 'all people-sized figures within +/-%d%% of the pack, outline equal%s'
                                % (TOLERANCE * 100, '' if a.no_pivot else ', every figure on the pivot (128, 200)')))
    return 1 if (bad and a.check) else 0


if __name__ == '__main__':
    sys.exit(main())
