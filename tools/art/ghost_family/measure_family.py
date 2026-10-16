#!/usr/bin/env python3
"""measure_family.py  (python -I; numpy + Pillow)  THE art gates of the ghost family as one program with an exit code (final edit; the first draft only printed numbers and had no --check).

  measure_family.py ROOT [--pack-root DIR] [--repo-art DIR] [--ambient FILE] [--pristine DIR] [--hero-base-root DIR] [--check] [--painted] [--json OUT] [--selftest]   (design6: --painted widens G4 to 10 dE00;
  final edit: G5 is ALSO measured against the silhouette the player's ghost really draws, ghost_bu_base / ghost_hviske_base, see --hero-base-root)

ROOT = a folder with <id>/idle.(webp|png) and the other clips (assets/isometric_characters of a clone or of the repo).  The six ghosts: ghost_bu (Pedro), ghost_hviske, ghostfam_dyne / _gnist / _silke / _blund.
It IMPORTS tools/art/characters/measure_cast.py (the P21 gate: pack reference, outline, pivot and feet window) instead of re-implementing it, because measure_cast only gates the ids of ITS OWN
PEOPLE / DESIGN_HEIGHT_M lists and prints 'ok' for any other id at any height (measured: Blund at 70 % of the pack shows 'ok').  Gates (exit 1 with --check when any fails):

  G1 height    Dyne, Gnist, Silke within +-10 % of the pack mean (measure_cast.TOLERANCE; the pack mean is MEASURED from the pack in --pack-root: it was 167.4 px before the drawn roster of main
               0be6efd and is 169.8 px now, so the margin of the tallest member moves with main: the tool prints the margin in px); Blund is sized by design (a band of 60-80 % of the pack is checked)
  G2 outline   the baked outline equals the pack outline (+-8 per channel), measure_cast.measure
  G3 pivot     measure_cast.pivot_check_folder on every sheet and frame of the six (x +-3 px, mirrored rows, feet window 197..216 for every grounded clip, row limits)
  G4 palette   the dominant colour of the idle S frame is within CIEDE2000 <= 6 of the declared body hex (the finished sheets are measured: the storybook pass shifts colour by up to ~3.6)
  G5 shape     DISTINCTNESS, grade independent (the CanvasModulate grade multiplies every sprite; 17:00-24:00 and 06:00-06:55 are the hours the family is out and under the night keyframes the
               colour distance of the colour-only pairs falls from >= 12 to 5-8, so a gate on baked colour alone is not a guarantee): for every pair of the six ghosts except Pedro - Hviske (the two
               heroes' own twin design, exempt) the silhouette IoU of idle S and idle SE is <= 0.80, and over ALL EIGHT directions it is <= 0.85 (no near-identical outline in any direction)
               FINAL EDIT (reviewer B major 3): the player's ghost draws `<skin>_base` (A2's wardrobe-ready 3D base: GHOST_ADDENDUM 4.3), NOT the stock sheet ghost_bu / ghost_hviske that pack_ghosts.py may paint,
               so every pair of a family member with Pedro or Hviske is gated against BOTH silhouettes (the larger IoU counts): `ghost_bu_base` / `ghost_hviske_base` in --hero-base-root (default ROOT) when the folder exists
  G6 graded    a pair that is NOT shape-distinct must be colour-distinct at every sampled hour of lua/config/ambient.lua (both presets, four seasons, clear and rain): graded CIEDE2000 >= 12.
               The lowest graded distance of every pair is printed either way (information: what the player sees at 19:00, 20:30, 22:00).
  G7 finish    with --pristine DIR (the stage copy of the folders BEFORE the storybook pass, layout DIR/<id>/*.webp or DIR/isometric_characters/<id>/*.webp): every finished sheet equals its pristine
               master on the alpha channel (the pass never moves a contour pixel) and differs on RGB (mean |dRGB| of the opaque pixels > 2.0: the pass has run, exactly once)."""
import argparse, importlib.util, itertools, json, math, re, sys
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ART = HERE.parent                                   # tools/art when this file lives in tools/art/ghost_family/
IDS = {'Pedro': 'ghost_bu', 'Hviske': 'ghost_hviske', 'Dyne': 'ghostfam_dyne', 'Gnist': 'ghostfam_gnist', 'Silke': 'ghostfam_silke', 'Blund': 'ghostfam_blund'}
FAMILY = ['Dyne', 'Gnist', 'Silke', 'Blund']
ADULTS = ['Dyne', 'Gnist', 'Silke']
DECLARED = {'Pedro': 'E6EFFF', 'Hviske': 'F6E7F6', 'Dyne': 'FFF4DC', 'Gnist': 'CBE8C0', 'Silke': 'A4EFE6', 'Blund': 'FFF3A8'}
EXEMPT = {frozenset(('Pedro', 'Hviske'))}
IOU_S_SE_MAX, IOU_8_MAX, DE_MIN_GRADED, DE_PALETTE_MAX = 0.80, 0.85, 12.0, 6.0
BLUND_BAND = (0.60, 0.80)
# fall-back copy of lua/config/ambient.lua (main 0be6efd) when the file is not found; the tool prefers the file
AMBIENT_FALLBACK = {
    'farm': [(0, '576199'), (5, '6b75ad'), (6.5, 'ffd6bd'), (8.5, 'fffcf2'), (17, 'fff7eb'), (19, 'ffbd94'), (20.5, '9480b8'), (22, '5e689e'), (24, '576199')],
    'hyggebyen': [(0, '5a5a98'), (5, '7a78b4'), (6.5, 'ffd0dc'), (8.5, 'fbf4ff'), (17, 'f7efff'), (19, 'ffb8cc'), (20.5, 'a58bd0'), (22, '625d9c'), (24, '5a5a98')]}
SEASON_FALLBACK = {'foraar': 'ffffff', 'sommer': 'fff3d8', 'efteraar': 'ffdcb4', 'vinter': 'dae8ff'}
WEATHER_FALLBACK = {'klart': 'ffffff', 'regn': 'd4dbe8'}
HOURS = [6.0, 6.5, 17.0, 18.0, 19.0, 19.5, 20.5, 22.0, 23.5]          # the hours the family is outdoors (design_ghostfamily.md 4.4)


# ------------------------------------------------------------------------------------------------------------------------------------------------ colour
def srgb2lab(rgb):
    c = np.asarray(rgb, float) / 255.0
    c = np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)
    M = np.array([[.4124564, .3575761, .1804375], [.2126729, .7151522, .0721750], [.0193339, .1191920, .9503041]])
    xyz = M @ c / np.array([.95047, 1.0, 1.08883])
    f = np.where(xyz > .008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.array([116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])])


def de2000(l1, l2):
    L1, a1, b1 = l1; L2, a2, b2 = l2
    C1, C2 = math.hypot(a1, b1), math.hypot(a2, b2); Cb = (C1 + C2) / 2
    G = .5 * (1 - math.sqrt(Cb ** 7 / (Cb ** 7 + 25 ** 7)))
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360; h2p = math.degrees(math.atan2(b2, a2p)) % 360
    dLp = L2 - L1; dCp = C2p - C1p
    dh = h2p - h1p
    if C1p * C2p == 0: dh = 0
    elif dh > 180: dh -= 360
    elif dh < -180: dh += 360
    dHp = 2 * math.sqrt(C1p * C2p) * math.sin(math.radians(dh / 2))
    Lbp = (L1 + L2) / 2; Cbp = (C1p + C2p) / 2
    hs = h1p + h2p
    if C1p * C2p == 0: hbp = hs
    elif abs(h1p - h2p) <= 180: hbp = hs / 2
    else: hbp = (hs + 360) / 2 if hs < 360 else (hs - 360) / 2
    T = 1 - .17 * math.cos(math.radians(hbp - 30)) + .24 * math.cos(math.radians(2 * hbp)) + .32 * math.cos(math.radians(3 * hbp + 6)) - .20 * math.cos(math.radians(4 * hbp - 63))
    dth = 30 * math.exp(-(((hbp - 275) / 25) ** 2))
    Rc = 2 * math.sqrt(Cbp ** 7 / (Cbp ** 7 + 25 ** 7))
    Sl = 1 + .015 * (Lbp - 50) ** 2 / math.sqrt(20 + (Lbp - 50) ** 2); Sc = 1 + .045 * Cbp; Sh = 1 + .015 * Cbp * T
    Rt = -math.sin(math.radians(2 * dth)) * Rc
    return math.sqrt((dLp / Sl) ** 2 + (dCp / Sc) ** 2 + (dHp / Sh) ** 2 + Rt * (dCp / Sc) * (dHp / Sh))


def hx(h): return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def dominant(cell):
    """median colour of the brightest 45 % of the fully opaque pixels of the idle S figure (the rule of palette_check.py)"""
    mask = cell[..., 3] == 255
    px = cell[mask][:, :3].astype(float)
    lum = px @ np.array([.299, .587, .114])
    return np.median(px[lum >= np.percentile(lum, 55)], axis=0)


def parse_ambient(path):
    """presets farm / hyggebyen (keys), season tints and weather tints from lua/config/ambient.lua by regex (the file is data, not code)"""
    if not path or not Path(path).exists():
        return AMBIENT_FALLBACK, SEASON_FALLBACK, WEATHER_FALLBACK, 'embedded copy of lua/config/ambient.lua'
    t = Path(path).read_text()
    out = {}
    for name in ('farm', 'hyggebyen'):
        i = t.index(f'\n      {name} = {{')
        j = t.index('glow = {', i)
        out[name] = [(float(h), c) for h, c in re.findall(r'hour = ([\d.]+), color = "([0-9a-fA-F]{6})"', t[i:j])]

    def block(name):
        i = t.index(f'\n    {name} = {{')
        j = t.index('}', i)
        return dict(re.findall(r'(\w+) = "([0-9a-fA-F]{6})"', t[i:j]))
    season, weather = block('season'), block('weather')
    weather = {k: v for k, v in weather.items() if k in ('klart', 'regn')}
    return out, season, weather, str(path)


def preset_at(keys, h):
    h = h % 24
    for (ha, ca), (hb, cb) in zip(keys, keys[1:]):
        if ha <= h <= hb:
            t = (h - ha) / (hb - ha); t = t * t * (3 - 2 * t)
            return hx(ca) * (1 - t) + hx(cb) * t
    return hx(keys[-1][1])


# ------------------------------------------------------------------------------------------------------------------------------------------------ sheets
def sheet(root, cid, clip='idle'):
    for ext in ('.webp', '.png'):
        p = Path(root) / cid / (clip + ext)
        if p.exists():
            return Image.open(p).convert('RGBA')
    return None


def rows(sh):
    a = np.asarray(sh)
    return [a[r * 256:(r + 1) * 256, 0:256] for r in range(8)]


def iou(a, b):
    A, B = a[..., 3] > 24, b[..., 3] > 24
    return float((A & B).sum() / (A | B).sum())


# ------------------------------------------------------------------------------------------------------------------------------------------------ the pure gate functions (also used by --selftest)
def shape_distinct(iou_s, iou_se, iou8):
    return max(iou_s, iou_se) <= IOU_S_SE_MAX + 1e-9 and iou8 <= IOU_8_MAX + 1e-9


def pair_ok(shape_ok, graded_min):
    """G5 + G6: a pair passes when its shapes are distinct, else when the graded colour distance never falls below DE_MIN_GRADED"""
    return shape_ok or graded_min >= DE_MIN_GRADED


def selftest():
    cases = [('two ghosts of the same outline (IoU 1.0) with a graded colour of 5', shape_distinct(1.0, 1.0, 1.0), 5.0, False),
             ('Silke - Pedro of the first draft (IoU .86 / .84) and graded dE 6.4', shape_distinct(.86, .84, .86), 6.4, False),
             ('the same pair but colour-distinct at every hour (dE 13)', shape_distinct(.86, .84, .86), 13.0, True),
             ('S / SE distinct (.78 / .74) but one direction near-identical (.90)', shape_distinct(.78, .74, .90), 7.0, False),
             ('S / SE .80 exactly and all eight .81', shape_distinct(.80, .79, .81), 3.0, True),
             ('S .81', shape_distinct(.81, .70, .81), 3.0, False)]
    bad = 0
    for name, sh, g, want in cases:
        got = pair_ok(sh, g)
        ok = got == want
        bad += 0 if ok else 1
        print(f'  {name:78s} -> {"pass" if got else "FAIL"}  {"ok" if ok else "WRONG"}')
    print('measure_family --selftest:', 'the distinctness gate is wrong in %d case(s)' % bad if bad else 'the distinctness gate fires on every near-identical pair and accepts the distinct ones')
    return 1 if bad else 0


# ------------------------------------------------------------------------------------------------------------------------------------------------ main
def load_measure_cast(art):
    p = Path(art) / 'characters' / 'measure_cast.py'
    if not p.exists():
        return None
    sys.path.insert(0, str(Path(art) / 'core'))
    spec = importlib.util.spec_from_file_location('measure_cast', p)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('  G1 height')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('root', nargs='?')
    ap.add_argument('--pack-root', help='folder with the pack characters (default ROOT)')
    ap.add_argument('--repo-art', default=str(ART), help='the tools/art folder that holds characters/measure_cast.py (default: the parent of this script)')
    ap.add_argument('--ambient', help='lua/config/ambient.lua (default: <repo>/lua/config/ambient.lua next to --repo-art, else the embedded copy)')
    ap.add_argument('--pristine', help='stage copy of the folders before the storybook finish (G7)')
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--hero-base-root', help='folder with ghost_bu_base / ghost_hviske_base (A2-art-wardrobe, the sprites the player\'s ghost really draws); default ROOT; absent folders are skipped with a printed line')
    ap.add_argument('--painted', action='store_true', help='design6: the sheets are imagegen PAINTINGS packed by pack_ghosts.py: pastel watercolour is not a flat hex, so the palette gate G4 is widened from 6 to 10 dE00 (all other gates unchanged)')
    ap.add_argument('--selftest', action='store_true')
    ap.add_argument('--json')
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if not a.root:
        ap.error('ROOT is required')
    root = Path(a.root)
    pack = Path(a.pack_root) if a.pack_root else root
    problems, report = [], {}
    global DE_PALETTE_MAX
    if a.painted:
        DE_PALETTE_MAX = 10.0
    mc = load_measure_cast(a.repo_art)
    if mc is None:
        problems.append(f'measure_cast.py not found under {a.repo_art}/characters (pass --repo-art)')
    # ---- G1 / G2 / G3
    if mc:
        ref = {c: mc.measure(pack, c) for c in mc.PACK_REFERENCE}
        if any(v is None for v in ref.values()):
            problems.append(f'pack reference characters missing in {pack}')
        else:
            pack_mean = float(np.mean([v['height_se'] for v in ref.values()]))
            pack_out = ref['bear']['outline']
            report['pack_mean'] = pack_mean
            print('pack reference: ' + ', '.join('%s %d' % (c, v['height_se']) for c, v in ref.items()) + f' -> mean {pack_mean:.1f} px, outline {pack_out}')
            print(f'{"id":16s} {"h_SE":>5s} {"h_S":>4s} {"ratio":>6s} {"margin px":>10s}  {"outline":14s} G1/G2')
            for name, cid in IDS.items():
                m = mc.measure(root, cid)
                if m is None:
                    problems.append(f'{cid}: idle sheet missing in {root}'); continue
                ratio = m['height_se'] / pack_mean
                lim = (1 + mc.TOLERANCE) * pack_mean if ratio >= 1 else (1 - mc.TOLERANCE) * pack_mean
                margin = abs(lim - m['height_se'])
                verdict = []
                if name in ADULTS and abs(ratio - 1) > mc.TOLERANCE:
                    verdict.append(f'HEIGHT {100 * (ratio - 1):+.1f} % outside +-{100 * mc.TOLERANCE:.0f} %')
                    problems.append(f'{cid}: height {m["height_se"]} px = {100 * ratio:.1f} % of the pack mean {pack_mean:.1f} (limit +-{100 * mc.TOLERANCE:.0f} %)')
                if name == 'Blund' and not BLUND_BAND[0] <= ratio <= BLUND_BAND[1]:
                    verdict.append('child outside its designed band')
                    problems.append(f'{cid}: the child is {100 * ratio:.1f} % of the pack, designed {100 * BLUND_BAND[0]:.0f}-{100 * BLUND_BAND[1]:.0f} %')
                oc = m['outline']
                if oc is None or max(abs(oc[i] - pack_out[i]) for i in range(3)) > 8:
                    verdict.append(f'OUTLINE {oc} != pack {pack_out}')
                    problems.append(f'{cid}: outline {oc} differs from the pack outline {pack_out}')
                print(f'{cid:16s} {m["height_se"]:5d} {m["height_s"]:4d} {100 * ratio:5.1f}% {margin:10.1f}  {str(oc):14s} {"; ".join(verdict) or "ok"}')
                report.setdefault('heights', {})[cid] = dict(h_se=m['height_se'], ratio=round(ratio, 4), margin_px=round(margin, 1))
            print('\npivot (128, 200), feet window and row limits, every sheet and frame of the folder:')
            for name, cid in IDS.items():
                if not (root / cid).is_dir():
                    continue
                pr, ns, nf, st = mc.pivot_check_folder(root, cid)
                sx = '%.1f..%.1f' % st['x'] if st['x'] else '-'
                sy = '%.1f..%.1f' % st['y'] if st['y'] else '-'
                print(f'  {cid:16s} sheets {ns:2d} frames {nf:3d}  x {sx:11s} feet {sy:13s} {"; ".join(pr[:3]) or "ok"}')
                problems += [f'{cid} {x}' for x in pr]
    # ---- G4 palette
    print('\npalette: dominant colour of the idle S frame against the declared body hex (CIEDE2000, gate <= %.0f):' % DE_PALETTE_MAX)
    cells = {}
    for name, cid in IDS.items():
        sh = sheet(root, cid)
        if sh is None:
            continue
        cells[name] = rows(sh)
    base_root = Path(a.hero_base_root) if a.hero_base_root else root
    base_cells = {}
    for name in ('Pedro', 'Hviske'):
        shb = sheet(base_root, IDS[name] + '_base')
        if shb is not None:
            base_cells[name] = rows(shb)
    print('on-screen hero silhouettes (ghost_*_base of %s): %s' % (base_root, ', '.join(IDS[n] + '_base' for n in base_cells) if base_cells else 'none present (the stock sheets are the hero reference; the gate re-runs against the bases once A2 has landed)'))
    dom = {}
    for name, rr in cells.items():
        d = dominant(rr[0]); dom[name] = d
        de = de2000(srgb2lab(hx(DECLARED[name])), srgb2lab(d))
        print(f'  {IDS[name]:16s} declared #{DECLARED[name]}  baked {tuple(int(x) for x in d)}  dE00 {de:4.1f}' + ('' if de <= DE_PALETTE_MAX else '   FAIL'))
        report.setdefault('palette_de', {})[IDS[name]] = round(de, 2)
        if de > DE_PALETTE_MAX:
            problems.append(f'{IDS[name]}: baked dominant colour is {de:.1f} dE00 from the declared #{DECLARED[name]} (gate {DE_PALETTE_MAX:.0f})')
    # ---- G5 / G6 shape and graded colour
    amb = a.ambient
    if not amb:
        cand = Path(a.repo_art).resolve().parents[1] / 'lua' / 'config' / 'ambient.lua'
        cand2 = root.resolve().parents[1] / 'lua' / 'config' / 'ambient.lua'
        amb = str(cand) if cand.exists() else (str(cand2) if cand2.exists() else None)
    presets, seasons, weathers, amb_src = parse_ambient(amb)
    print(f'\nshape distinctness (idle pose, alpha > 24, aligned on the cell pivot): gate IoU(S), IoU(SE) <= {IOU_S_SE_MAX:.2f} and all eight directions <= {IOU_8_MAX:.2f}; graded colour from {amb_src}')
    print(f'{"pair":16s} {"S":>5s} {"SE":>5s} {"max8":>5s} {"dE baked":>9s} {"dE graded min":>14s} {"worst case":28s} verdict')
    pairs = {}
    for A, B in itertools.combinations(IDS, 2):
        if A not in cells or B not in cells:
            continue
        i_all = [iou(x, y) for x, y in zip(cells[A], cells[B])]
        on_screen = ''
        for ha, hb in ((A, B), (B, A)):                      # a hero in the pair: ALSO measure the sprite the player really sees (the pair of two heroes is exempt anyway)
            if ha in base_cells and hb not in ('Pedro', 'Hviske'):
                ib = [iou(x, y) for x, y in zip(base_cells[ha], cells[hb])]
                on_screen = f' (on-screen {IDS[ha]}_base: S {ib[0]:.2f} SE {ib[7]:.2f} max8 {max(ib):.2f})'
                i_all = [max(u, v) for u, v in zip(i_all, ib)]
        i_s, i_se, i8 = i_all[0], i_all[7], max(i_all)
        de_b = de2000(srgb2lab(dom[A]), srgb2lab(dom[B]))
        gmin, gwhere = 1e9, ''
        for pname, keys in presets.items():
            for sname, stint in seasons.items():
                for wname, wtint in weathers.items():
                    for h in HOURS:
                        g = preset_at(keys, h) / 255.0 * hx(stint) / 255.0 * hx(wtint) / 255.0
                        d = de2000(srgb2lab(np.clip(dom[A] * g, 0, 255)), srgb2lab(np.clip(dom[B] * g, 0, 255)))
                        if d < gmin:
                            gmin, gwhere = d, f'{pname} {sname} {wname} {h:g}h'
        sd = shape_distinct(i_s, i_se, i8)
        exempt = frozenset((A, B)) in EXEMPT
        ok = pair_ok(sd, gmin) or exempt
        tag = 'ok (shape)' if sd else ('ok (colour carries it)' if pair_ok(sd, gmin) else 'FAIL')
        if exempt:
            tag = "exempt: the two heroes' own twin design"
        print(f'{A + " - " + B:16s} {i_s:5.2f} {i_se:5.2f} {i8:5.2f} {de_b:9.1f} {gmin:14.1f} {gwhere:28s} {tag}{on_screen}')
        pairs[f'{A}-{B}'] = dict(iou_s=round(i_s, 3), iou_se=round(i_se, 3), iou8=round(i8, 3), de_baked=round(de_b, 2), de_graded_min=round(gmin, 2), worst=gwhere, ok=bool(ok))
        if not ok:
            problems.append(f'distinctness: {A} - {B}: IoU S {i_s:.2f} SE {i_se:.2f} (all eight {i8:.2f}) and the graded colour falls to dE {gmin:.1f} at {gwhere}')
    report['pairs'] = pairs
    # ---- G7 finish
    if a.pristine:
        pr = Path(a.pristine)
        if (pr / 'isometric_characters').is_dir():
            pr = pr / 'isometric_characters'
        print('\nstorybook finish (G7): finished sheet against the pristine stage master (alpha must be equal, RGB must differ):')
        for name in FAMILY:
            cid = IDS[name]
            for p in sorted((pr / cid).glob('*.webp')):
                f = root / cid / p.name
                if not f.exists():
                    problems.append(f'{cid}/{p.name}: finished sheet missing'); continue
                A_, B_ = np.asarray(Image.open(p).convert('RGBA')).astype(int), np.asarray(Image.open(f).convert('RGBA')).astype(int)
                if A_.shape != B_.shape:
                    problems.append(f'{cid}/{p.name}: size changed {A_.shape} -> {B_.shape}'); continue
                a_mask, b_mask = A_[..., 3] > 24, B_[..., 3] > 24
                flips = int((a_mask != b_mask).sum())
                op = a_mask & b_mask
                drgb = float(np.abs(A_[..., :3] - B_[..., :3])[op].mean()) if op.any() else 0.0
                bad = []
                if flips > 0:
                    bad.append(f'{flips} alpha pixels moved')
                    problems.append(f'{cid}/{p.name}: the finish moved {flips} contour pixels')
                if drgb <= 2.0:
                    bad.append('NOT finished (mean dRGB %.2f)' % drgb)
                    problems.append(f'{cid}/{p.name}: not finished (mean |dRGB| {drgb:.2f} <= 2.0)')
                if p.name == 'idle.webp' or bad:
                    print(f'  {cid}/{p.name:14s} alpha flips {flips}  mean |dRGB| {drgb:5.1f}  {"; ".join(bad) or "ok"}')
    else:
        print('\n(G7 skipped: no --pristine)')
    if a.json:
        Path(a.json).write_text(json.dumps(report, indent=1))
    print(f'\nmeasure_family: {len(problems)} problem(s)')
    for p in problems:
        print('  PROBLEM', p)
    return 1 if (problems and a.check) else 0


if __name__ == '__main__':
    sys.exit(main())
