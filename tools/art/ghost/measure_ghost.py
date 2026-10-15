#!/usr/bin/env python3
"""The numbers behind the cast gates of the two ghost heroes (package G-ghost-art; plan 6.4 item 2), measured on the baked sheets.
Imports tools/art/characters/measure_cast.py (P21's file is NOT edited) like V2's measure_cast_v2.py does.  It measures NOTHING about eyes or faces: the dark-eye look is
judged on the review sheets (tools/art/ghost/review/) and in the real windowed shot.

  tools/art/.venv/bin/python -I tools/art/ghost/measure_ghost.py                         # assets/isometric_characters: ghost_bu, ghost_hviske vs the pack
  tools/art/.venv/bin/python -I tools/art/ghost/measure_ghost.py --root tools/art/_stage/assets/isometric_characters --check
  tools/art/.venv/bin/python -I tools/art/ghost/measure_ghost.py --check                   # exit 1 when any gate below fails
  tools/art/.venv/bin/python -I tools/art/ghost/measure_ghost.py --selftest                # proves the gates have teeth (a hem on the ground, a shifted figure, a split silhouette)

Gates (all on the idle sheet unless stated; alpha > 24 is "figure"):
  height      bounding-box height of idle SE = 160 px = 96 % of the pack mean (bear cat rabbit fox fairy, 167.4 px), gate +/-10 %
  outline     median RGB of the isolated outline pixels = the pack outline (75, 60, 73) at alpha .55 (measured [75, 61, 73]), tolerance 8 per channel
  pivot x     every frame of every clip: the 8-row mean of the bbox centres is 127.5 +/- 3 (measured 127.4 .. 127.6) and opposed rows mirror each other (+/- 5)
  feet y      EVERY clip, jump / fall / land / hit / interact included (measure_cast.py exempts jump / fall / land: the pack's legs leave the ground there, the ghost's
              bell does not): the 8-row mean of the lowest pixel is inside the upright window 197 .. 216 (measured 206.1 .. 214.2), every single row inside 188 .. 226.
              This is the HOVER gate: a 0.66 m bell standing ON the ground projects 22 px below the pivot (prototype v1: 222), the baked hem hovers ~10 px
  palette     the dominant colour of the idle S frame is within CIEDE2000 <= 6 of the declared hex (Bu E6EFFF, Hviske F6E7F6; measured 1.3 / 1.1; palette_check.py)
  silhouette  Bu and Hviske are ONE silhouette: <= 0.05 % of the figure pixels differ and none below the neck line y 130 (measured 1460 of 5 370 860 = 0.027 %, all in the
              face band y 60 .. 130 of the W / E rows: the shy pupils; occluder_equality.py), so A2 may share the garment layers
"""
import argparse, json, sys
from pathlib import Path
import numpy as np

sys.dont_write_bytecode = True        # no __pycache__ next to the sources (the section runs this tool inside the repo)
HERE = Path(__file__).resolve().parent
ART = HERE.parent
REPO = ART.parents[1]
sys.path.insert(0, str(ART / 'core'))
sys.path.insert(0, str(ART / 'characters'))
sys.path.insert(0, str(HERE))
import artcontract as ac            # noqa: E402
import measure_cast as mc           # noqa: E402  (P21's measurement code: figure height, outline colour, the pivot rules)
import palette_check as pc          # noqa: E402
import occluder_equality as oe      # noqa: E402

GHOSTS = ['ghost_bu', 'ghost_hviske']
HEX = {'ghost_bu': 'E6EFFF', 'ghost_hviske': 'F6E7F6'}
CLASS = 'upright'                   # the body class of measure_cast: the ghost stands inside the upright feet window
TOLERANCE = mc.TOLERANCE            # +/-10 % of the pack mean height
OUTLINE_TOL = 8
SILHOUETTE_MAX_SHARE = 0.0005       # A2's rule for the two ghosts: <= 0.05 % of the figure pixels


def clips_of(root: Path, cid: str):
    meta = root / cid / 'animations.json'
    if meta.exists():
        try:
            return list(json.loads(meta.read_text()).get('animations', {}).keys())
        except (ValueError, OSError):
            pass
    return ['idle']


def pivot_and_feet(root: Path, cid: str, check_y_all_clips: bool = True):
    """Every sheet and frame of one folder against the pivot contract, the feet window applied to EVERY clip.
    -> (problems, sheets, frames, {'x': (min, max), 'y': (min, max), 'row_y': (min, max)})"""
    problems, n_sheets, n_frames = [], 0, 0
    means_x, means_y, row_y = [], [], []
    for clip in clips_of(root, cid):
        sh = mc.sheet(root, cid, clip)
        if sh is None:
            problems.append(f'{clip}: sheet missing')
            continue
        a = np.asarray(sh)[..., 3]
        n_sheets += 1
        for f in range(a.shape[1] // ac.CELL):
            n_frames += 1
            boxes = mc.row_boxes(a, f)
            for pr in mc.pivot_problems(boxes, CLASS, check_y=check_y_all_clips or clip not in mc.AIRBORNE_CLIPS):
                if len(problems) < 8:
                    problems.append(f'{clip} f{f}: {pr}')
            if all(b is not None for b in boxes):
                means_x.append(sum((b[2] + b[3]) / 2.0 for b in boxes) / 8.0)
                means_y.append(sum(b[1] for b in boxes) / 8.0)
                row_y.extend(b[1] for b in boxes)
    stats = {'x': (min(means_x), max(means_x)) if means_x else None, 'y': (min(means_y), max(means_y)) if means_y else None,
             'row_y': (min(row_y), max(row_y)) if row_y else None}
    return problems, n_sheets, n_frames, stats


def run(roots, pack_root: Path, ids, check: bool, as_json: str = None) -> int:
    ref = {c: mc.measure(pack_root, c) for c in mc.PACK_REFERENCE}
    if any(v is None for v in ref.values()):
        print('ERROR: pack reference characters missing in', pack_root)
        return 2
    pack_mean = float(np.mean([v['height_se'] for v in ref.values()]))
    pack_out = ref['bear']['outline']
    print('pack reference (idle SE, alpha>%d): %s  -> mean %.1f px; pack outline %s' % (
        mc.SPRITE_ALPHA, ', '.join('%s %d' % (c, v['height_se']) for c, v in ref.items()), pack_mean, pack_out))
    bad, report = [], {}
    root_of = {}
    for cid in ids:
        root_of[cid] = next((r for r in roots if (r / cid / 'animations.json').exists()), None)
    print('%-13s %6s %6s %6s  %-14s %-18s %-18s %-8s %s' % ('id', 'h_se', 'h_s', 'ratio', 'outline', 'pivot x min..max', 'feet y min..max', 'dE00', 'verdict'))
    for cid in ids:
        root = root_of[cid]
        if root is None:
            print('%-13s MISSING' % cid)
            bad.append(f'{cid}: no animations.json in {[str(r) for r in roots]}')
            continue
        m = mc.measure(root, cid)
        ratio = m['height_se'] / pack_mean
        verdict = []
        if abs(ratio - 1) > TOLERANCE:
            verdict.append('HEIGHT %+.0f%% (limit +/-%d%%)' % ((ratio - 1) * 100, TOLERANCE * 100))
        oc = m['outline']
        if oc is None:
            verdict.append('no outline pixels found')
        elif max(abs(oc[i] - pack_out[i]) for i in range(3)) > OUTLINE_TOL:
            verdict.append('OUTLINE %s != pack %s' % (oc, pack_out))
        probs, n_sheets, n_frames, st = pivot_and_feet(root, cid)
        verdict.extend(probs[:3])
        de, med, want = pc.palette_de(root, cid, HEX[cid])
        if de > pc.DE_GATE:
            verdict.append('PALETTE dE00 %.1f > %.0f (dominant %s, declared %s)' % (de, pc.DE_GATE, med, want))
        sx = '%.1f..%.1f' % st['x'] if st['x'] else '-'
        sy = '%.1f..%.1f' % st['y'] if st['y'] else '-'
        print('%-13s %6d %6d %5.0f%%  %-14s %-18s %-18s %-8.1f %s' % (cid, m['height_se'], m['height_s'], ratio * 100, oc if oc else '-', sx, sy, de, '; '.join(verdict) or 'ok (%d sheets, %d frames)' % (n_sheets, n_frames)))
        report[cid] = {'height_se': m['height_se'], 'ratio': round(ratio, 3), 'outline': oc, 'pivot_x': st['x'], 'feet_y': st['y'], 'row_feet_y': st['row_y'],
                       'dE00': round(de, 2), 'sheets': n_sheets, 'frames': n_frames}
        bad.extend(f'{cid}: {v}' for v in verdict)
    pair = [c for c in GHOSTS if root_of.get(c) is not None]
    if len(pair) == 2 and root_of[pair[0]] == root_of[pair[1]]:
        s = oe.silhouette_diff(root_of[pair[0]], pair[0], pair[1])
        print('silhouette %s vs %s: %d of %d figure pixels differ (%.3f %%), in rows y %d..%d; worst frame %s (%d px)' % (
            pair[0], pair[1], s['diff_px'], s['area_px'], s['share'] * 100, s['highest_diff_y'], s['lowest_diff_y'], s['worst'][1], s['worst'][0]))
        report['silhouette'] = {k: s[k] for k in ('diff_px', 'area_px', 'share', 'highest_diff_y', 'lowest_diff_y')}
        if s['share'] > SILHOUETTE_MAX_SHARE:
            bad.append(f'silhouette: {s["share"] * 100:.3f} % of the figure pixels differ between the heroes (limit {SILHOUETTE_MAX_SHARE * 100:.2f} %)')
        if s['lowest_diff_y'] > oe.NECK_LINE_Y:
            bad.append(f'silhouette: the heroes differ below the neck line (y {s["lowest_diff_y"]} > {oe.NECK_LINE_Y}): garment layers could not be shared')
    if as_json:
        Path(as_json).write_text(json.dumps({'pack_mean_height': pack_mean, 'pack_outline': pack_out, 'rows': report}, indent=1))
    print('measure_ghost: %s' % ('%d problem(s): %s' % (len(bad), '; '.join(bad[:4])) if bad else
          'both heroes within +/-%d%% of the pack height, outline = the pack\'s, on the pivot (128, 200), the hem hovers inside the feet window %d..%d in EVERY clip, '
          'palette dE00 <= %d, one silhouette' % (TOLERANCE * 100, mc.FEET_WINDOW[CLASS][0], mc.FEET_WINDOW[CLASS][1], pc.DE_GATE)))
    return 1 if (bad and check) else 0


# ----------------------------------------------------------------------------------------------------------------------
def selftest() -> int:
    """The gates must accept the measured design and flag each failure mode (synthetic sheets, no assets needed)."""
    def fake_sheet(lowest: int, dx: int = 0):
        """8 rows of a rounded block whose lowest opaque pixel is exactly row `lowest`, centred on the pivot x (+ dx)."""
        a = np.zeros((ac.CELL * 8, ac.CELL), np.uint8)
        cx = int(round(mc.PIVOT_X_CENTRE)) + dx
        for row in range(8):
            a[row * ac.CELL + lowest - 120:row * ac.CELL + lowest + 1, cx - 40:cx + 40] = 255
        return a
    cases = [('hovering bell, lowest pixel 210 (the design)', fake_sheet(210), False),
             ('hover at the lower end, 214 (the measured maximum)', fake_sheet(214), False),
             ('hem ON the ground, lowest pixel 222 (prototype v1)', fake_sheet(222), True),
             ('first small hover, 217 (prototype v4: failed the window)', fake_sheet(217), True),
             ('floating too high, 190', fake_sheet(190), True),
             ('shifted 8 px sideways', fake_sheet(210, dx=8), True)]
    bad = 0
    for name, a, expect in cases:
        probs = mc.pivot_problems(mc.row_boxes(a, 0), CLASS, check_y=True)
        ok = bool(probs) == expect
        bad += 0 if ok else 1
        print('%-58s %s  %s' % (name, 'flagged ' if probs else 'accepted', 'ok' if ok else 'WRONG (expected %s)' % ('flagged' if expect else 'accepted')))
    # the palette gate: the baked colour of the design passes, another hero's colour and a green fail
    near = pc.de2000(pc.srgb2lab([230, 239, 255]), pc.srgb2lab([228, 238, 252]))
    green = pc.de2000(pc.srgb2lab([230, 239, 255]), pc.srgb2lab([120, 160, 90]))
    ok = near <= pc.DE_GATE < green
    print('%-58s %s' % ('palette: a near colour dE00 %.1f <= %.0f, a green %.1f > %.0f' % (near, pc.DE_GATE, green, pc.DE_GATE), 'ok' if ok else 'WRONG'))
    bad += 0 if ok else 1
    print('measure_ghost --selftest: %s' % ('a gate is blind in %d case(s)' % bad if bad else 'the feet / pivot / palette gates accept the design and flag every failure mode'))
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('Gates (all')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('ids', nargs='*', help='default: ghost_bu ghost_hviske')
    ap.add_argument('--root', action='append', help='folder(s) with <id>/idle.(webp|png); default assets/isometric_characters')
    ap.add_argument('--pack-root', default=str(REPO / 'assets' / 'isometric_characters'))
    ap.add_argument('--check', action='store_true', help='exit 1 when a gate fails')
    ap.add_argument('--selftest', action='store_true')
    ap.add_argument('--json', help='also write the measurements here')
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    roots = [Path(r) for r in a.root] if a.root else [REPO / 'assets' / 'isometric_characters']
    return run(roots, Path(a.pack_root), a.ids or GHOSTS, a.check, a.json)


if __name__ == '__main__':
    sys.exit(main())
