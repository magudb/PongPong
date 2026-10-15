#!/usr/bin/env python3
"""Numbers behind the cast gates of package V2-cast-art, on the eight cast ids.  The gates of P21 are REUSED, not copied: every function that
measures (figure height, outline colour, the pivot contract, the body classes) is imported from tools/art/characters/measure_cast.py (P21's file,
never edited); this file adds only what the v2 cast needs on top - the CIEDE2000 palette gate against the Figurer v2 sketch and the ink bust check.

  python tools/art/cast_v2/measure_cast_v2.py                       # heights + outline + pivot of the eight ids (assets/isometric_characters, then the stage)
  python tools/art/cast_v2/measure_cast_v2.py --check               # exit 1 on any problem (height outside +/-10 % of the pack mean, wrong outline, off the pivot)
  python tools/art/cast_v2/measure_cast_v2.py --root STAGE/assets/isometric_characters bear_brumme     # explicit folders / ids
  python tools/art/cast_v2/measure_cast_v2.py palette [--root ...]  # palette gate: dominant region of the idle-S frame, dE00 <= 6 against the sketch fill
  python tools/art/cast_v2/measure_cast_v2.py busts [--root ...]    # the busts: 256 x 256, top / left / right clear, guide ink outline (43, 35, 64)
  python tools/art/cast_v2/measure_cast_v2.py render IDS... --stage DIR   # build the GLBs of the ids into DIR and bake ONLY idle S + SE (no install, no export)

Gates (design section 3.2 / 3.4, work order tasks 5 and 6):
  height   idle SE bounding box within +/-10 % of the mean of the pack's bear cat rabbit fox fairy (167 px): display_scale stays 1.0.  Brumme's SKETCH is
           10.2 % short and Hoppe's ears 8 % tall: relative sizes of a shape-sketch sheet are not binding, nothing is scaled individually.
  outline  the world sheets keep the pack outline (75, 60, 73) at alpha .55
  pivot    EVERY frame of EVERY clip stands on the pivot (128, 200): mean of the 8 row centres x 127.5 +/- 3, opposed rows mirrored, feet line inside the
           window of the body class (a bat flies: the flyer window)
  palette  single-region figures (bear, owl, capybara, cat, the pack rabbit): the dominant region of the idle-S frame (the most common opaque colour)
           within CIEDE2000 6 of the sketch fill (the bake darkens a palette colour by 0.92 - 0.97: dE00 1.4 - 4.4 on screen); multi-region figures
           (fairies, hedgehog, bat): region by region on the PALETTE HEX the builder bakes (every sketch region must exist in the model within dE00 6);
           every figure of this package gets the palette-hex check as well - no tone curve is added anywhere.
"""
import argparse
import importlib.util
import json
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ART = HERE.parent
REPO = ART.parents[1]
sys.path[:0] = [str(ART / 'core'), str(ART / 'generator'), str(HERE)]

import artcontract as ac            # noqa: E402


def _load_measure_cast():
    """tools/art/characters/measure_cast.py (P21), loaded from its file: its functions are the cast gates."""
    spec = importlib.util.spec_from_file_location('tt_p21_measure_cast', ART / 'characters' / 'measure_cast.py')
    mod = importlib.util.module_from_spec(spec)
    sys.modules['tt_p21_measure_cast'] = mod
    spec.loader.exec_module(mod)
    return mod


mc = _load_measure_cast()

NEW_IDS = ['bear_brumme', 'bat_natteblik', 'hedgehog_pip', 'owl_fru_ugle', 'capybara_sofus', 'fairy_birk_npc']
RESTYLE_IDS = ['fairy_shopkeeper', 'cat_morfar_mis']
CAST_IDS = NEW_IDS + RESTYLE_IDS
# a bat flies: its lowest pixel is a wing tip or a foot, the flyer windows of P21 apply (measure_cast.FLYERS lists only the pack bat)
mc.FLYERS.extend(i for i in ('bat_natteblik',) if i not in mc.FLYERS)
# the eight are people-sized: the height gate applies to them (measure_cast.PEOPLE lists P21's 21; the restyled two are in it already)
mc.PEOPLE.extend(i for i in CAST_IDS if i not in mc.PEOPLE)

INK_OUTLINE = tuple(ac.INK['color'])     # (43, 35, 64)
PALETTE_DE_LIMIT = 6.0

# figure -> (art id, the sketch fill of its dominant region, 'single' = dominant-region gate on the screen, 'multi' = region by region on the palette hex)
# (design_v2.md section 3.2 / 3.4; the regions are the keys of palettes_v2.json)
FIGURES = {
    'brumme':       ('bear_brumme', 'body', 'single'),
    'natteblik':    ('bat_natteblik', 'body', 'multi'),
    'pip':          ('hedgehog_pip', 'spines', 'multi'),
    'fru_ugle':     ('owl_fru_ugle', 'body', 'single'),
    'sofus':        ('capybara_sofus', 'body', 'single'),
    'birk':         ('fairy_birk_npc', 'tunic', 'multi'),
    'kloevermynte': ('fairy_shopkeeper', 'hair', 'multi'),
    'morfar_mis':   ('cat_morfar_mis', 'body', 'single'),
    'hoppe':        ('rabbit', 'body', 'single'),        # the pack rabbit, no new art
}
# the A2 heroes (wardrobe bases): checked by tools/art/features/wardrobe, listed here so that the table of the design is complete
HERO_FIGURES = {'rasmus': 'fox_base', 'bertil': 'hobbit_pip_base', 'bodil': 'hobbit_bodil_base', 'kiki': 'monkey_base'}


# ---------------------------------------------------------------------------------------------------------------------
# CIEDE2000 (Sharma, Wu, Dalal 2005), vectorised, D65
# ---------------------------------------------------------------------------------------------------------------------
def srgb_to_lab(rgb):
    c = np.asarray(rgb, float).reshape(-1, 3) / 255.0
    lin = np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)
    m = np.array([[.4124564, .3575761, .1804375], [.2126729, .7151522, .0721750], [.0193339, .1191920, .9503041]])
    xyz = lin @ m.T / np.array([.95047, 1.0, 1.08883])
    f = np.where(xyz > 216 / 24389, np.cbrt(xyz), (24389 / 27 * xyz + 16) / 116)
    return np.stack([116 * f[:, 1] - 16, 500 * (f[:, 0] - f[:, 1]), 200 * (f[:, 1] - f[:, 2])], axis=1)


def hex_rgb(h):
    h = h.lstrip('#')
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def ciede2000(lab1, lab2):
    lab1, lab2 = np.atleast_2d(lab1).astype(float), np.atleast_2d(lab2).astype(float)
    L1, a1, b1 = lab1[:, 0], lab1[:, 1], lab1[:, 2]
    L2, a2, b2 = lab2[:, 0], lab2[:, 1], lab2[:, 2]
    C1, C2 = np.hypot(a1, b1), np.hypot(a2, b2)
    Cb = (C1 + C2) / 2
    G = .5 * (1 - np.sqrt(Cb ** 7 / (Cb ** 7 + 25 ** 7)))
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = np.hypot(a1p, b1), np.hypot(a2p, b2)
    h1p = np.degrees(np.arctan2(b1, a1p)) % 360
    h2p = np.degrees(np.arctan2(b2, a2p)) % 360
    dLp, dCp = L2 - L1, C2p - C1p
    dh = h2p - h1p
    dh = np.where(dh > 180, dh - 360, np.where(dh < -180, dh + 360, dh))
    dh = np.where(C1p * C2p == 0, 0, dh)
    dHp = 2 * np.sqrt(C1p * C2p) * np.sin(np.radians(dh / 2))
    Lbp, Cbp = (L1 + L2) / 2, (C1p + C2p) / 2
    hs = h1p + h2p
    hbp = np.where(C1p * C2p == 0, hs, np.where(np.abs(h1p - h2p) <= 180, hs / 2, np.where(hs < 360, (hs + 360) / 2, (hs - 360) / 2)))
    T = 1 - .17 * np.cos(np.radians(hbp - 30)) + .24 * np.cos(np.radians(2 * hbp)) + .32 * np.cos(np.radians(3 * hbp + 6)) - .20 * np.cos(np.radians(4 * hbp - 63))
    dTh = 30 * np.exp(-(((hbp - 275) / 25) ** 2))
    Rc = 2 * np.sqrt(Cbp ** 7 / (Cbp ** 7 + 25 ** 7))
    Sl = 1 + .015 * (Lbp - 50) ** 2 / np.sqrt(20 + (Lbp - 50) ** 2)
    Sc, Sh = 1 + .045 * Cbp, 1 + .015 * Cbp * T
    Rt = -np.sin(np.radians(2 * dTh)) * Rc
    return np.sqrt((dLp / Sl) ** 2 + (dCp / Sc) ** 2 + (dHp / Sh) ** 2 + Rt * (dCp / Sc) * (dHp / Sh))


def de00_hex(h1, h2) -> float:
    return float(ciede2000(srgb_to_lab(hex_rgb(h1)), srgb_to_lab(hex_rgb(h2)))[0])


# ---------------------------------------------------------------------------------------------------------------------
# palette gate
# ---------------------------------------------------------------------------------------------------------------------
def region_hex(figure: str, region: str):
    """The sketch hex of a region of palettes_v2.json: a string, or the first of a list."""
    v = json.loads((HERE / 'palettes_v2.json').read_text())['figures'][figure][region]
    return v[0] if isinstance(v, list) else v


def dominant_colour(cell: np.ndarray, bins: int = 24):
    """The dominant region of an RGBA cell: the most common colour among the fully opaque pixels (the outline is half transparent; eyes, cheeks and
    glints are small), as the mean of the biggest bin of a 24-level RGB histogram and its direct neighbours.  Returns (rgb, share of opaque pixels)."""
    a = cell[..., 3] >= 250
    px = cell[..., :3][a].astype(int)
    if len(px) == 0:
        return None, 0.0
    q = (px * bins // 256)
    key = q[:, 0] * bins * bins + q[:, 1] * bins + q[:, 2]
    counts = np.bincount(key, minlength=bins ** 3)
    # smooth over the 27 neighbours so that a shaded region (a gradient across two bins) counts as one region
    cube = counts.reshape(bins, bins, bins).astype(float)
    padded = np.pad(cube, 1)
    smooth = sum(padded[1 + i:bins + 1 + i, 1 + j:bins + 1 + j, 1 + k:bins + 1 + k] for i in (-1, 0, 1) for j in (-1, 0, 1) for k in (-1, 0, 1))
    best = np.unravel_index(int(np.argmax(smooth)), smooth.shape)
    centre = (np.array(best) + .5) * 256 / bins
    near = (np.abs(px - centre).max(axis=1) <= 256 / bins * 1.5)
    return px[near].mean(axis=0), float(near.sum()) / len(px)


def region_screen(cell: np.ndarray, figure: str, assign_limit: float = 9.0):
    """Region by region on the SCREEN: every fully opaque pixel of the idle-S frame is assigned to the sketch region of the figure whose hex is nearest
    (CIEDE2000, at most `assign_limit` away: eyes, cheeks and outline pixels belong to no region); a region's colour is the median of its pixels.
    Returns [(region, hex, pixels, median hex or None, dE00 or None)]."""
    regions = []
    for rname, v in json.loads((HERE / 'palettes_v2.json').read_text())['figures'][figure].items():
        for hx in (v if isinstance(v, list) else [v]):
            regions.append((rname, hx))
    px = cell[..., :3][cell[..., 3] >= 250].astype(int)
    if len(px) == 0:
        return [(r, h, 0, None, None) for r, h in regions]
    lab = srgb_to_lab(px)
    labs = srgb_to_lab([hex_rgb(h) for _, h in regions])
    d = np.stack([ciede2000(lab, np.broadcast_to(labs[i], lab.shape)) for i in range(len(regions))], axis=1)
    nearest, dmin = d.argmin(axis=1), d.min(axis=1)
    out = []
    for i, (rname, hx) in enumerate(regions):
        sel = (nearest == i) & (dmin <= assign_limit)
        n = int(sel.sum())
        if n < 25:
            out.append((rname, hx, n, None, None))
            continue
        med = np.median(px[sel], axis=0)
        out.append((rname, hx, n, '#%02x%02x%02x' % tuple(int(round(c)) for c in med), float(ciede2000(srgb_to_lab(med), srgb_to_lab(hex_rgb(hx)))[0])))
    return out


def idle_cell(root: Path, cid: str, row: int = 0, frame: int = 0):
    sh = mc.sheet(root, cid)
    return None if sh is None else mc.cell(sh, row, frame)


def build_palette(cid: str) -> set:
    """The colours of every shape of the model a builder produces (= the tiles of its baked colour atlas): the palette hex the bake starts from."""
    os.environ.setdefault('PYTHONDONTWRITEBYTECODE', '1')
    import build_assets as ba          # noqa: E402  (needs the shim first on sys.path: done below)
    maker = ba.TT_BUILDERS[cid]
    m = maker()
    return {sh.color.upper() for g in m.groups for sh in g.shapes}


def palette_rows(roots, ids=None):
    """[(figure, id, region, sketch hex, kind, measured, dE00, verdict)] of the palette gate."""
    figures = json.loads((HERE / 'palettes_v2.json').read_text())['figures']
    rows = []
    for fig, (cid, region, kind) in FIGURES.items():
        if ids and cid not in ids:
            continue
        sketch = region_hex(fig, region)
        # (1) the dominant region on the idle-S frame, in every case (reported; GATED for single-region figures)
        cell = None
        for r in roots:
            cell = idle_cell(r, cid)
            if cell is not None:
                break
        if cell is None:
            rows.append((fig, cid, region, sketch, kind, None, None, 'MISSING idle sheet'))
            continue
        dom, share = dominant_colour(cell)
        de = float(ciede2000(srgb_to_lab(dom), srgb_to_lab(hex_rgb(sketch)))[0])
        ok = de <= PALETTE_DE_LIMIT
        rows.append((fig, cid, region, sketch, 'screen-' + kind, '#%02x%02x%02x (%.0f%% of the opaque pixels)' % (round(dom[0]), round(dom[1]), round(dom[2]), share * 100), de,
                     'ok' if ok or kind == 'multi' else 'FAIL'))
        # (2) every figure this package bakes: every sketch region of the figure exists in the baked model within dE00 6 (region by region on the palette hex;
        #     for the multi-region figures this IS the gate)
        if cid in NEW_IDS + RESTYLE_IDS:
            colours = build_palette(cid)
            lab_model = srgb_to_lab([hex_rgb(c) for c in colours])
            for rname, v in figures[fig].items():
                for hx in (v if isinstance(v, list) else [v]):
                    de2 = float(ciede2000(lab_model, np.broadcast_to(srgb_to_lab(hex_rgb(hx)), lab_model.shape)).min())
                    rows.append((fig, cid, rname, hx, 'palette-hex', 'model tile', de2, 'ok' if de2 <= PALETTE_DE_LIMIT else 'FAIL'))
    return rows


def cmd_palette(a):
    roots = [Path(r) for r in a.root] if a.root else default_roots()
    ids = a.ids or None
    rows = palette_rows(roots, ids)
    bad = 0
    print('%-13s %-17s %-12s %-8s %-13s %-34s %6s  %s' % ('figure', 'id', 'region', 'sketch', 'kind', 'measured', 'dE00', 'verdict'))
    for fig, cid, region, sketch, kind, meas, de, verdict in rows:
        print('%-13s %-17s %-12s #%-7s %-13s %-34s %6s  %s' % (fig, cid, region, sketch, kind, meas or '-', '-' if de is None else '%.1f' % de, verdict))
        bad += verdict.startswith(('FAIL', 'MISSING'))
    if a.regions:
        print('\nregion by region on the idle-S frame (pixels nearest to each sketch region; informational, the bake darkens by 0.92 - 0.97):')
        for fig, (cid, _, _) in FIGURES.items():
            if ids and cid not in ids:
                continue
            cell = next((c for c in (idle_cell(r, cid) for r in roots) if c is not None), None)
            if cell is None:
                continue
            for rname, hx, n, med, de in region_screen(cell, fig):
                print('  %-13s %-12s #%s  %6d px  %s' % (fig, rname, hx, n, 'median %s  dE00 %.1f' % (med, de) if med else 'too few pixels (hidden or tiny)'))
    for fig, base in HERO_FIGURES.items():
        have = any((r / base / 'idle.webp').exists() for r in roots)
        print('%-13s %-17s SKIP: %s' % (fig, base, 'checked by tools/art/features/wardrobe (art_wardrobe.hero_palettes_within_de, package A2)' if not have
                                       else 'baked (%s exists): its gate lives in package A2' % base))
    print('measure_cast_v2 palette: %s' % ('%d problem(s)' % bad if bad else 'every figure within CIEDE2000 %.0f (single-region on the screen, multi-region region by region on the palette hex)' % PALETTE_DE_LIMIT))
    return 1 if (bad and a.check) else 0


# ---------------------------------------------------------------------------------------------------------------------
# busts
# ---------------------------------------------------------------------------------------------------------------------
def bust_outline(path: Path):
    """The ink outline of a bust: the median colour of the isolated outline pixels (alpha 130 .. 245 next to a clear pixel).  With the pack outline
    (75,60,73) at alpha .55 these pixels sit at alpha ~140; the ink outline is alpha .92: ~235."""
    im = np.asarray(Image.open(path).convert('RGBA'))
    al = im[..., 3].astype(int)
    clear = al == 0
    near = np.zeros_like(clear)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        near |= np.roll(clear, (dy, dx), axis=(0, 1))
    band = (al >= 200) & (al <= 250) & near
    if band.sum() < 30:
        return None, int(band.sum())
    return np.median(im[..., :3][band].astype(int), axis=0).astype(int).tolist(), int(band.sum())


def cmd_busts(a):
    roots = [Path(r) for r in a.root] if a.root else default_roots()
    ids = a.ids or CAST_IDS
    bad = 0
    for cid in ids:
        f = next((r / cid / 'portrait.webp' for r in roots if (r / cid / 'portrait.webp').exists()), None)
        if f is None:
            print('%-18s MISSING portrait.webp' % cid); bad += 1; continue
        im = Image.open(f)
        al = np.asarray(im.convert('RGBA'))[..., 3]
        probs = []
        if im.size != (256, 256):
            probs.append('size %s' % (im.size,))
        for edge, line in (('top', al[0]), ('left', al[:, 0]), ('right', al[:, -1])):
            if line.max() > ac.BORDER_ALPHA_MAX:
                probs.append('cut at the %s edge (alpha %d)' % (edge, line.max()))
        rgb, n = bust_outline(f)
        if rgb is None or max(abs(rgb[i] - INK_OUTLINE[i]) for i in range(3)) > 10:
            probs.append('outline %s is not the guide ink %s' % (rgb, INK_OUTLINE))
        print('%-18s %s  outline %s (%d px)  %s' % (cid, im.size, rgb, n, '; '.join(probs) or 'ok'))
        bad += bool(probs)
    print('measure_cast_v2 busts: %s' % ('%d problem(s)' % bad if bad else 'every bust is 256 x 256, clear at top / left / right, baked with the guide ink outline'))
    return 1 if (bad and a.check) else 0


# ---------------------------------------------------------------------------------------------------------------------
# heights / outline / pivot (P21's functions)
# ---------------------------------------------------------------------------------------------------------------------
def default_roots():
    """The stage of produce_cast_v2.sh first (the freshest bake of every id, incl. the two restyles that are not installed), then the installed folders."""
    roots = [REPO / 'assets' / 'isometric_characters']
    stage = ART / '_stage' / 'v2cast' / 'assets' / 'isometric_characters'
    if stage.is_dir():
        roots.insert(0, stage)
    return roots


def cmd_measure(a):
    roots = [Path(r) for r in a.root] if a.root else default_roots()
    pack = Path(a.pack_root)
    ids = a.ids or CAST_IDS
    ref = {c: mc.measure(pack, c) for c in mc.PACK_REFERENCE}
    if any(v is None for v in ref.values()):
        print('ERROR: pack reference characters missing in', pack); return 2
    pack_mean = float(np.mean([v['height_se'] for v in ref.values()]))
    pack_out = ref['bear']['outline']
    print('pack reference (idle SE, alpha>%d): %s  -> mean %.1f px; pack outline %s' % (mc.SPRITE_ALPHA, ', '.join('%s %d' % (c, v['height_se']) for c, v in ref.items()), pack_mean, pack_out))
    print('%-18s %6s %6s %7s  %-16s %s' % ('id', 'h_se', 'h_s', 'ratio', 'outline', 'verdict'))
    bad, rows = 0, {}
    for cid in ids:
        m = next((x for x in (mc.measure(r, cid) for r in roots) if x), None)
        if m is None:
            print('%-18s MISSING' % cid); bad += 1; continue
        ratio = m['height_se'] / pack_mean
        verdict = []
        if abs(ratio - 1) > mc.TOLERANCE:
            verdict.append('HEIGHT %+.0f%% (limit +/-%d%%)' % ((ratio - 1) * 100, mc.TOLERANCE * 100)); bad += 1
        oc = m['outline']
        if oc is None:
            verdict.append('no outline pixels found'); bad += 1
        elif max(abs(oc[i] - pack_out[i]) for i in range(3)) > 8:
            verdict.append('OUTLINE %s != pack %s' % (oc, pack_out)); bad += 1
        rows[cid] = dict(m, ratio=round(ratio, 3))
        print('%-18s %6d %6d %6.0f%%  %-16s %s' % (cid, m['height_se'], m['height_s'], ratio * 100, oc if oc else '-', '; '.join(verdict) or 'ok'))
    pivot_bad = 0
    if not a.no_pivot:
        print('\npivot (128, 200): x = 8-row mean of the bbox centres (want %.1f +/- %.0f), opposed rows mirrored; y = 8-row mean of the lowest pixel' % (mc.PIVOT_X_CENTRE, mc.PIVOT_X_TOL))
        print('%-18s %-9s %7s %9s %17s %17s  %s' % ('id', 'class', 'sheets', 'frames', 'x mean min..max', 'feet y min..max', 'verdict'))
        for cid in ids:
            res = None
            for r in roots:
                if (r / cid).is_dir():
                    res = mc.pivot_check_folder(r, cid)
                    break
            if res is None:
                print('%-18s MISSING' % cid); pivot_bad += 1; continue
            probs, n_sheets, n_frames, st = res
            sx = '%.1f..%.1f' % st['x'] if st['x'] else '-'
            sy = '%.1f..%.1f' % st['y'] if st['y'] else '-'
            print('%-18s %-9s %7d %9d %17s %17s  %s' % (cid, mc.body_class(cid), n_sheets, n_frames, sx, sy, '; '.join(probs[:3]) if probs else 'ok'))
            pivot_bad += bool(probs)
    bad += pivot_bad
    if a.json:
        Path(a.json).write_text(json.dumps({'pack_mean_height': pack_mean, 'pack_outline': pack_out, 'rows': rows}, indent=1))
    print('measure_cast_v2: %s' % ('%d problem(s)' % bad if bad else 'the eight cast figures are within +/-%d%% of the pack, outline equal, every frame on the pivot (128, 200)' % (mc.TOLERANCE * 100)))
    return 1 if (bad and a.check) else 0


# ---------------------------------------------------------------------------------------------------------------------
# render: build + bake only the idle S / SE frames of some ids (restyle gate without installing anything; a window-free, headless call)
# ---------------------------------------------------------------------------------------------------------------------
def cmd_render(a):
    stage = Path(a.stage)
    import artpaths
    stage = artpaths.assert_stage_dir(stage)
    glb, masters = stage / 'glb', stage / 'masters' / 'isometric_characters'
    os.environ['TT_ART_GLB'] = str(glb)
    import build_assets as ba
    import bake_sprite_atlases as bk
    glb.mkdir(parents=True, exist_ok=True)
    for cid in a.ids:
        ba.export(ba.TT_BUILDERS[cid](), glb)
        r = bk.Renderer(cid, 256, glb)
        out = masters / cid
        out.mkdir(parents=True, exist_ok=True)
        # a one-frame 'idle' sheet: 8 rows (directions), frame 0 only, in the sheet layout the measure functions read
        sheet = Image.new('RGBA', (256, 256 * 8))
        for di, ang in enumerate(ac.ANGLES):
            sheet.paste(r.frame(ang, 'idle', 0.0), (0, di * 256))
        sheet.save(out / 'idle.png')
        r.close()
        print('rendered', cid, '->', out / 'idle.png')
    return 0


def cmd_selftest():
    """The palette gate must have teeth: published CIEDE2000 test pairs (Sharma, Wu, Dalal 2005), a figure in its sketch colour (shaded by the bake's 0.95) passes,
    the same figure in another colour (P21's Oak bear) fails, and a half-hidden dominant region does not fool the histogram."""
    bad = 0
    pairs = [((50.0, 2.6772, -79.7751), (50.0, 0.0, -82.7485), 2.0425), ((50.0, 3.1571, -77.2803), (50.0, 0.0, -82.7485), 2.8615),
             ((50.0, 2.8361, -74.0200), (50.0, 0.0, -82.7485), 3.4412), ((60.2574, -34.0099, 36.2677), (60.4626, -34.1751, 39.4387), 1.2644),
             ((2.0776, 0.0795, -1.1350), (0.9033, -0.0636, -0.5514), 0.9082)]
    for a, b, want in pairs:
        got = float(ciede2000(np.array(a), np.array(b))[0])
        ok = abs(got - want) < .001
        bad += 0 if ok else 1
        print('CIEDE2000 test pair %-34s %.4f (published %.4f)  %s' % (a, got, want, 'ok' if ok else 'WRONG'))

    def cell_of(hx, shade=1.0, size=64):
        c = np.zeros((size, size, 4), np.uint8)
        c[..., :3] = np.round(np.array(hex_rgb(hx)) * shade).astype(np.uint8)
        c[..., 3] = 255
        return c
    for label, hx, shade, want_pass in (('Brumme body, shaded by the bake (x .95)', 'b98657', .95, True), ('Brumme body exact', 'b98657', 1.0, True),
                                       ("P21's Oak bear body 8e6b52 against Brumme's sketch fill", '8e6b52', 1.0, False),
                                       ('a pink instead of the brown', 'e88f9f', 1.0, False)):
        dom, _ = dominant_colour(cell_of(hx, shade))
        de = float(ciede2000(srgb_to_lab(dom), srgb_to_lab(hex_rgb('b98657')))[0])
        ok = (de <= PALETTE_DE_LIMIT) == want_pass
        bad += 0 if ok else 1
        print('%-58s dE00 %5.1f -> %s  %s' % (label, de, 'accepted' if de <= PALETTE_DE_LIMIT else 'flagged', 'ok' if ok else 'WRONG'))
    mixed = cell_of('b98657')
    mixed[:20] = cell_of('ffffff')[:20]                               # a fifth of the cell is white (eyes, belly): the dominant region is still the body
    dom, share = dominant_colour(mixed)
    ok = float(ciede2000(srgb_to_lab(dom), srgb_to_lab(hex_rgb('b98657')))[0]) <= 1.0
    bad += 0 if ok else 1
    print('dominant region with a white fifth: %s share %.0f%%  %s' % (dom.round().tolist(), share * 100, 'ok' if ok else 'WRONG'))
    print('measure_cast_v2 --selftest: %s' % ('the palette gate is blind in %d case(s)' % bad if bad else 'the palette gate accepts the sketch colour (also shaded) and flags another colour; the CIEDE2000 numbers equal the published pairs'))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('Gates (design')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('words', nargs='*', help="'palette' | 'busts' | 'render' as the first word, then ids; no command word = heights, outline and pivot")
    ap.add_argument('--root', action='append', help='folder(s) with <id>/idle.(webp|png); default assets/isometric_characters, then the stage of produce_cast_v2.sh')
    ap.add_argument('--pack-root', default=str(REPO / 'assets' / 'isometric_characters'))
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--no-pivot', action='store_true')
    ap.add_argument('--selftest', action='store_true', help='the palette gate on synthetic cells and the published CIEDE2000 pairs')
    ap.add_argument('--regions', action='store_true', help='palette: also print the region-by-region screen measurement of the idle-S frame')
    ap.add_argument('--json')
    ap.add_argument('--stage', default=str(ART / '_stage' / 'v2cast_render'))
    a = ap.parse_intermixed_args()          # `palette --check --root DIR ids...`: options and ids in any order
    if a.selftest:
        return cmd_selftest()
    cmd = None
    if a.words and a.words[0] in ('palette', 'busts', 'render'):
        cmd, a.ids = a.words[0], a.words[1:]
    else:
        a.ids = a.words
    # the generator hook must resolve to THIS folder's shim (same rule as produce_cast_v2.sh): ours first on sys.path
    sys.path[:0] = [str(HERE)]
    if cmd == 'palette':
        return cmd_palette(a)
    if cmd == 'busts':
        return cmd_busts(a)
    if cmd == 'render':
        return cmd_render(a)
    return cmd_measure(a)


if __name__ == '__main__':
    sys.exit(main())
