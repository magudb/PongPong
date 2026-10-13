#!/usr/bin/env python3
"""Validator of the A1 home art (an independent Python implementation of tests/sections/art_home.gd; F1's rule R19 proves the snapshot against the Lua in wave 3).

  python tools/art/features/home/isometric/validate_features_home.py [--assets assets | <stage>/assets]

One `PASS <id>` / `FAIL <id> <why>` line per check, exit 1 on any FAIL.  Checks: ids vs spec, footprints/layers vs the content snapshot, rotations + pivots inside images,
icons (130 + 32, ink ring, fill, night rims), home.json + rooms vs the snapshot, tier anchor, house mass, night layers, scaffolds, floors (no mipmaps), mirror_ok, props, byte budget.
Fix round (review of A1): furniture_looks_distinct (no two ids with an identical or near-identical r0 sprite / icon), house_ground_contact + scaffold_anchor_matches_tier +
furniture_ground_contact + ysort_from_footprint (the anchors are checked on PIXELS, not only as JSON arithmetic), symmetry_measured_consistent, float_layers_legendary_only, room_windows_contract.
"""
from __future__ import annotations
import argparse, hashlib, itertools, json, re, sys
from pathlib import Path
import numpy as np
from PIL import Image
import homepaths
from scipy.ndimage import binary_dilation

INK = np.array([43, 35, 64]); RIM = (0xe4, 0xef, 0xf5); NIGHT = (0x2f, 0x36, 0x54)
OK = []; BAD = []
HW, HH = 64.0, 37.6            # one tile = a diamond 128 x 75.2 px (36 degrees): +x = (+HW, +HH), +z = (-HW, +HH) per tile


def chk(name, cond, why=''):
    (OK if cond else BAD).append(name)
    print(('PASS ' if cond else 'FAIL ') + name + ('' if cond else ' ' + str(why)))


def lum(c):
    c = np.asarray(c, float) / 255.0; c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4); return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True); return (la + 0.05) / (lb + 0.05)


def ring(im):
    a = np.array(im.getchannel('A')); rgb = np.array(im.convert('RGB')).astype(int)
    return rgb[binary_dilation(a < 32, iterations=2) & (a >= 128)]


def fill(im):
    bb = im.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    return max(bb[2] - bb[0], bb[3] - bb[1]) / im.width if bb else 0


# ---------------------------------------------------------------- pixel helpers (fix round)
def alpha_of(path):
    return np.array(Image.open(path).convert('RGBA').getchannel('A'))


def extent(a, thr):
    """(left, right, top, bottom) pixel indices of the pixels with alpha >= thr, or None"""
    cols = np.where((a >= thr).any(0))[0]; rows = np.where((a >= thr).any(1))[0]
    return None if len(cols) == 0 else (int(cols[0]), int(cols[-1]), int(rows[0]), int(rows[-1]))


def alpha_at(a, x, y):
    x, y = int(round(x)), int(round(y))
    return int(a[y, x]) if 0 <= y < a.shape[0] and 0 <= x < a.shape[1] else -1


def corners_alpha(a, piv, rect, inset):
    """alpha under the four footprint corners (moved `inset` tiles towards the centre) projected from the pivot; rect = (xmin, zmin, xmax, zmax) in tiles around the pivot"""
    x0, z0, x1, z1 = rect
    return [alpha_at(a, piv[0] + HW * (x - z), piv[1] + HH * (x + z)) for x, z in ((x0 + inset, z0 + inset), (x1 - inset, z0 + inset), (x1 - inset, z1 - inset), (x0 + inset, z1 - inset))]


def base_edge_residual(a, piv, rect, thr=32, margin=16):
    """median (lowest opaque row of a column minus the predicted ground line) along the footprint's right-front base edge (x = xmax face, from the bottom corner to the right corner)"""
    x0, z0, x1, z1 = rect
    px, py = piv; res = []
    for x in range(int(px + HW * x1 + margin), int(px + HW * (x1 - z0) - margin)):
        if 0 <= x < a.shape[1]:
            rows = np.where(a[:, x] >= thr)[0]
            if len(rows):
                res.append(int(rows[-1]) - (py + HH * x1 - HH * (x - px - HW * x1) / HW))
    return float(np.median(res)) if res else None


def ysort_of(rect):
    x0, z0, x1, z1 = rect
    kx, kz = (x0, z1) if (x1 - x0) >= (z1 - z0) else (x1, z0)
    return [round(HW * (kx - kz), 1), round(HH * (kx + kz), 1)]


def rgba(path):
    return np.asarray(Image.open(path).convert('RGBA'), np.int16)


def union_diff(A, B):
    """(mean abs RGB difference over the union of the opaque pixels, silhouette mismatch %) of two equally sized RGBA arrays"""
    ua, ub = A[..., 3] > 128, B[..., 3] > 128; uni = ua | ub
    if not uni.any(): return 0.0, 0.0
    return float(np.abs(A[..., :3] - B[..., :3]).mean(-1)[uni].mean()), float((ua ^ ub).sum() / uni.sum() * 100)


NEAR_DUP_MEAN = 2.0        # two different ids closer than this (mean abs RGB over the union, silhouette within 1 %) are the same picture (the closest legitimate pair is 4.7)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0]); ap.add_argument('--assets', default=str(homepaths.REPO / 'assets')); a = ap.parse_args()
    R = Path(a.assets)
    import spec_reader as sp
    spec = sp.load(); S = sp.by_id(spec); C = json.loads((homepaths.SPECS / 'content_contract.json').read_text())
    fj = json.loads((R / 'iso_props/furniture/furniture.json').read_text())['items']
    # ---- furniture: ids, files, pivots, footprints --------------------------------------------------------------------------------
    chk('furniture_ids_equal_spec', sorted(fj) == sorted(S) and sorted(S) == sorted(C['furniture']), set(fj) ^ set(S))
    bad, mains, floats = [], 0, 0
    for i, e in fj.items():
        it = S.get(i); c = C['furniture'].get(i)
        if not it or not c: continue
        if list(e['footprint']) != list(c['footprint']) or e['layer'] != c['layer'] or e['template'] != c['template']: bad.append(f'{i}: snapshot')
        for k in sp.rotations_needed(e['sym']):
            ent = e['rot'].get(str(k))
            if ent is None or 'file' not in ent: bad.append(f'{i}: r{k} missing'); continue
            f = R / 'iso_props/furniture' / ent['file']
            if not f.exists(): bad.append(f'{i}: {ent["file"]} not on disk'); continue
            w, h = Image.open(f).size; mains += 1
            px, py = ent['pivot']
            # floor / rug / tabletop pieces stand on their pivot (inside the sprite); wall and ceiling pieces carry the ground anchor BELOW the sprite on the same vertical line (contract: 'on the wall plane below the item centre')
            inside = (0 <= px < w) and ((0 <= py < h) if e['layer'] in ('floor', 'rug', 'tabletop') else (h - 1 <= py < h + 400))
            if [w, h] != ent['size'] or not inside: bad.append(f'{i}: r{k} size/pivot')
            if 'float' in ent:
                floats += 1
                if not (R / 'iso_props/furniture' / ent['float']['file']).exists(): bad.append(f'{i}: float file')
    chk('furniture_files', not bad and mains > 0, bad[:5])
    # 79 four-view pieces x 4 + 18 c2 x 2 + 14 c4 x 1 + 19 wall pieces x 2 = 404 main sprites; the 11 legendary pieces carry one float layer per baked rotation = 38
    chk('furniture_sprite_counts', (mains, floats) == (404, 38), (mains, floats))
    fbad = [f'{i}: float layers {[k for k, r in e["rot"].items() if "float" in r]} on a {e["rarity"]} piece' for i, e in fj.items()
            if any(('float' in r) != (e['rarity'] == 'legendary') for r in e['rot'].values())]
    chk('float_layers_legendary_only', not fbad and sum(1 for e in fj.values() if e['rarity'] == 'legendary') == 11, fbad[:4])
    import measure_symmetry as ms
    sm = json.loads((homepaths.SPECS / 'symmetry_measured.json').read_text())['items']; sbad = []
    for i, m in sm.items():
        if i not in fj: sbad.append(f'{i}: not a piece'); continue
        if ms.classify(m['declared'], {k: v for k, v in m['pairs'].items()}) != m['class']: sbad.append(f'{i}: class {m["class"]} does not follow from its measured pairs')
        if fj[i]['sym'] != m['class']: sbad.append(f'{i}: furniture.json sym {fj[i]["sym"]} != measured {m["class"]}')
    for i, e in fj.items():
        if e['sym'] in ('c4', 'c2') and i not in sm: sbad.append(f'{i}: ships as {e["sym"]} without a measurement')
    chk('symmetry_measured_consistent', not sbad and len(sm) == 41, sbad[:4])
    # ---- furniture anchors on PIXELS: the ground point of every sprite must be where the footprint is (a shifted pivot or a wrong y-sort key passes the size/pivot-inside checks) --------------------------
    gbad = []
    for i, e in fj.items():
        for k, ent in e['rot'].items():
            a = alpha_of(R / 'iso_props/furniture' / ent['file']); px, py = ent['pivot']; fx, fz = ent['footprint']; ex = extent(a, 24); tag = f'{i} r{k}'
            if e['layer'] in ('floor', 'rug'):
                S_ = fx / 2 + fz / 2; low = ex[3] - (py + HH * S_); lef = ex[0] - (px - HW * S_); rig = ex[1] - (px + HW * S_)
                cor = corners_alpha(a, ent['pivot'], (-fx / 2, -fz / 2, fx / 2, fz / 2), .3)
                if min(cor) < 16 or not (-18 <= low <= 3 and -8 <= lef <= 34 and -34 <= rig <= 7): gbad.append(f'{tag}: corners {cor} low {low:.0f} left {lef:.0f} right {rig:.0f}')
                if e['layer'] == 'floor' and (abs(ent['ysort'][0] - ysort_of((-fx / 2, -fz / 2, fx / 2, fz / 2))[0]) > .15 or abs(ent['ysort'][1] - ysort_of((-fx / 2, -fz / 2, fx / 2, fz / 2))[1]) > .15):
                    gbad.append(f'{tag}: ysort {ent["ysort"]} != key corner of the footprint {ysort_of((-fx / 2, -fz / 2, fx / 2, fz / 2))}')
            elif e['layer'] == 'tabletop':
                if not (8 <= ex[3] - py <= 18 and -22 <= ex[0] - px <= -12 and 13 <= ex[1] - px <= 23): gbad.append(f'{tag}: tabletop shadow low {ex[3] - py} left {ex[0] - px} right {ex[1] - px}')
            else:                                                       # wall / ceiling: the pivot is the ground point BELOW the sprite on its vertical centre line
                gap = py - ex[3]; cx = (ex[0] + ex[1]) / 2 - px
                lo, hi = (30, 125) if e['layer'] == 'wall' else (105, 145)
                if not (lo <= gap <= hi and abs(cx) <= 16): gbad.append(f'{tag}: {e["layer"]} piece gap below the sprite {gap}, centre offset {cx:.1f}')
    chk('furniture_ground_contact', not gbad, gbad[:4])
    # ---- icons --------------------------------------------------------------------------------------------------------------------
    ids = list(S) + list(C['materials']); badi, rings, fills = [], [], []
    for i in ids:
        f = R / 'icons/home' / f'{i}.webp'
        if not f.exists(): badi.append(f'{i} missing'); continue
        im = Image.open(f)
        if im.size != (128, 128) or im.mode != 'RGBA': badi.append(f'{i} {im.size} {im.mode}'); continue
        r = ring(im); fl = fill(im)
        rings.append(0 if len(r) == 0 else float(np.abs(r.mean(0) - INK).max())); fills.append(fl)
    chk('icons_complete', not badi and len(ids) == 162, badi[:5])
    chk('icons_ink_outline', bool(rings) and max(rings) <= 24 and 0.86 <= min(fills) and max(fills) <= 0.95, (max(rings or [0]), min(fills or [0]), max(fills or [0])))
    leg = sorted(i for i, e in C['furniture'].items() if e['rarity'] == 'legendary'); worst = 99; probs = []
    for i in leg:
        f = R / 'icons/home' / f'{i}_night.webp'
        if not f.exists(): probs.append(f'{i}_night missing'); continue
        base = Image.open(R / 'icons/home' / f'{i}.webp'); nv = Image.open(f).convert('RGBA')
        worst = min(worst, contrast(ring(base).mean(0), RIM), contrast(RIM, NIGHT))
        rr = ring(nv); al = np.array(nv.getchannel('A'))
        if len(rr) == 0 or np.abs(rr.mean(0) - np.array(RIM)).max() > 24: probs.append(f'{i}_night rim colour')
        if max(al[0].max(), al[-1].max(), al[:, 0].max(), al[:, -1].max()) > 24: probs.append(f'{i}_night rim touches the cell border')
    chk('icons_night_rim', len(leg) == 11 and not probs and worst >= 7, (len(leg), probs[:3], worst))
    # ---- no two distinct ids may look the same (a template that ignores its style key at some tier ships twin sprites and twin icons) -------------------------------------------------
    dup = []; seen_s = {}; seen_i = {}
    for i in S:
        ent = fj[i]['rot']['0']; arr = rgba(R / 'iso_props/furniture' / ent['file'])
        h = hashlib.sha256(arr.astype(np.uint8).tobytes() + bytes(str(ent['pivot']), 'ascii')).hexdigest()
        if h in seen_s: dup.append(f'{i} == {seen_s[h]} (r0 sprite, identical)')
        seen_s[h] = i
    icons = {}
    for i in ids:
        f = R / 'icons/home' / f'{i}.webp'
        if f.exists():
            icons[i] = rgba(f); h = hashlib.sha256(icons[i].astype(np.uint8).tobytes()).hexdigest()
            if h in seen_i: dup.append(f'{i} == {seen_i[h]} (icon, identical)')
            seen_i[h] = i
    closest = (99.0, '')
    for a_, b_ in itertools.combinations(list(S), 2):
        if S[a_]['template'] != S[b_]['template']: continue
        ea, eb = fj[a_]['rot']['0'], fj[b_]['rot']['0']
        if a_ in icons and b_ in icons:
            d, sil = union_diff(icons[a_], icons[b_]); closest = min(closest, (d, f'icon {a_} ~ {b_}'))
            if d < NEAR_DUP_MEAN and sil < 1: dup.append(f'{a_} ~ {b_} (icon, mean diff {d:.2f}/255, silhouette {sil:.2f} %)')
        if ea['size'] == eb['size'] and ea['pivot'] == eb['pivot']:
            d, sil = union_diff(rgba(R / 'iso_props/furniture' / ea['file']), rgba(R / 'iso_props/furniture' / eb['file'])); closest = min(closest, (d, f'sprite {a_} ~ {b_}'))
            if d < NEAR_DUP_MEAN and sil < 1: dup.append(f'{a_} ~ {b_} (r0 sprite, mean diff {d:.2f}/255, silhouette {sil:.2f} %)')
    chk('furniture_looks_distinct', not dup, dup[:5])
    print(f'  (closest legitimate pair: {closest[1]} at {closest[0]:.1f}/255)')
    # ---- houses -------------------------------------------------------------------------------------------------------------------
    hj = json.loads((R / 'iso_props/home/home.json').read_text()); T = hj['tiers']; H = R / 'iso_props/home'
    areas, heights, fps, anchors, scaf = [], [], [], [], 0
    for t, c in zip(T, C['tiers']):
        e = t['exterior']; im = Image.open(H / e['day']).convert('RGBA'); al = np.array(im.getchannel('A')) > 128
        ys = np.where(al.any(1))[0]; areas.append(int(al.sum())); heights.append(int(ys.max() - ys.min() + 1)); fps.append(t['footprint_tiles'][0] * t['footprint_tiles'][1])
        r = t['footprint_rect']; anchors.append(r[3] == 0.0 and r[0] == -(t['door_column'] + .5) and r[1] == -float(t['footprint_tiles'][1]) and 0 <= e['pivot'][0] < im.width and 0 <= e['pivot'][1] < im.height)
        if t['tier'] > 1: scaf += int((H / t['scaffold_from_previous']['file']).exists())
    chk('tier_anchor_identical', all(anchors) and len(T) == 10, anchors)
    chk('house_mass_monotonic', all(b > a for a, b in zip(areas, areas[1:])) and all(b > a for a, b in zip(fps, fps[1:])), (areas, fps))
    chk('scaffolds_nine', scaf == 9 and 'scaffold_from_previous' not in T[0], scaf)
    # ---- the anchor on PIXELS (a pivot, scaffold pivot or y-sort key that is shifted still satisfies 'inside the image') -----------------------------------------------------------------
    hbad, sbad_, frames = [], [], []
    for t in T:
        e = t['exterior']; rect = t['footprint_rect']; x0, z0, x1, z1 = rect; tag = f'tier {t["tier"]}'
        a = alpha_of(H / e['day']); ex = extent(a, 32); cor = corners_alpha(a, e['pivot'], rect, .25)
        L = (e['pivot'][0] + HW * x0) - ex[0]; Rr = ex[1] - (e['pivot'][0] + HW * (x1 - z0)); B = ex[3] - (e['pivot'][1] + HH * (x1 + z1)); med = base_edge_residual(a, e['pivot'], rect)
        if min(cor) < 200 or med is None or not (-3 <= med <= 17 and -20 <= B <= 50 and -20 <= L <= 70 and -20 <= Rr <= 70): hbad.append(f'{tag}: corners {cor} base-edge residual {med} low {B:.0f} left {L:.0f} right {Rr:.0f}')
        if any(abs(u - v) > .15 for u, v in zip(e['ysort'], ysort_of(rect))): hbad.append(f'{tag}: ysort {e["ysort"]} != key corner of the footprint {ysort_of(rect)}')
        sc = t.get('scaffold_from_previous')
        if sc:       # the scaffold is drawn around the NEW footprint at the same ground anchor as the house of this tier: same y-sort key, frame at a constant distance from the footprint corners
            a2 = alpha_of(H / sc['file']); e2 = extent(a2, 32); cor2 = corners_alpha(a2, sc['pivot'], rect, .25)
            fr = ((sc['pivot'][0] + HW * x0) - e2[0], e2[1] - (sc['pivot'][0] + HW * (x1 - z0)), e2[3] - (sc['pivot'][1] + HH * (x1 + z1))); frames.append(fr)
            if sc['ysort'] != e['ysort'] or min(cor2) < 200: sbad_.append(f'{tag}: scaffold ysort {sc["ysort"]} vs house {e["ysort"]}, corners {cor2}')
    for n, fr in enumerate(frames):         # the frame stands a constant distance outside the footprint corners (left 120, right 91 px; the foundation about 80-87 px below the front corner)
        if not (112 <= fr[0] <= 128 and 83 <= fr[1] <= 99 and 74 <= fr[2] <= 96): sbad_.append(f'scaffold to tier {n + 2}: frame distances {fr} (left, right, bottom)')
    if frames and (np.ptp([f[0] for f in frames]) > 4 or np.ptp([f[1] for f in frames]) > 4 or np.ptp([f[2] for f in frames]) > 10): sbad_.append(f'scaffold frames are not at one distance from their footprints: {frames}')
    chk('house_ground_contact', not hbad and len(T) == 10, hbad[:4])
    chk('scaffold_anchor_matches_tier', not sbad_ and len(frames) == 9, sbad_[:4])
    nbad = []
    for t in T:
        e = t['exterior']
        if not e.get('night'): nbad.append(f'tier {t["tier"]}: no night layer'); continue
        nm = Image.open(H / e['night']).convert('RGBA'); a = np.array(nm.getchannel('A')); rgb = np.array(nm)[..., :3]
        full = (a > 0).any(0)[0] and (a > 0).any(0)[-1] and (a > 0).any(1)[0] and (a > 0).any(1)[-1]
        vis = a >= 48
        if list(nm.size) != e['night_size'] or not full: nbad.append(f'tier {t["tier"]}: not trimmed')
        if vis.any() and rgb[vis].max(-1).min() < 120: nbad.append(f'tier {t["tier"]}: not additive-normalised')
        if e.get('night_blend') != 'add' or e['night_offset'][0] + nm.width > e['size'][0] or e['night_offset'][1] + nm.height > e['size'][1]: nbad.append(f'tier {t["tier"]}: placement')
    chk('night_layers_additive_trimmed', not nbad, nbad[:4])
    # ---- contract vs the content snapshot -----------------------------------------------------------------------------------------
    bad = []; ps = {int(k): v['back_rows'] for k, v in hj['platform_stages'].items()}
    for t, c in zip(T, C['tiers']):
        rm = json.loads((R / 'data/home/rooms' / f'room_t{t["tier"]:02d}.json').read_text())
        n = max(rm['rows']) + len(rm['rows']); zf = round(.85 * min(1280 / (n * 64), 720 / (n * 38 + 280)), 2)
        if (t['platform']['back_rows'], ps[t['platform']['stage']]) != (c['platform_back_rows'],) * 2: bad.append(f'{t["tier"]}: platform rows')
        if rm['max_furniture'] != c['capacity'] or rm['floor'] != c['floor'] or rm['wall_style'] != c['walls'] or t['interior']['floor'] != c['floor']: bad.append(f'{t["tier"]}: room')
        if abs(rm['zoom_fit'] - zf) > .005: bad.append(f'{t["tier"]}: zoom_fit')
        w = rm['windows']; wb = rm.get('windows_by_wall', {}); nz = len(rm['rows'])
        if not rm.get('_contract', {}).get('windows') or wb.get('back_right_z0') != w['z'] or wb.get('back_left_x0') != w['x'] \
                or not all(0 < v < rm['rows'][0] - 1 for v in w['z']) or not all(0 < v < nz - 1 for v in w['x']) or not w['z'] or not w['x']: bad.append(f'{t["tier"]}: windows contract / ranges')
        if Path(t['exterior']['day']).stem != c['exterior'] or Path(t['exterior']['night']).stem != c['night'] or (t.get('scaffold_from_previous') and Path(t['scaffold_from_previous']['file']).stem != c['scaffold']): bad.append(f'{t["tier"]}: file names')
        if any(g not in fj for g in c['gift_items']): bad.append(f'{t["tier"]}: gift item without sprite')
    chk('room_windows_contract', not [b for b in bad if 'windows' in b], [b for b in bad if 'windows' in b][:3])
    bad = [b for b in bad if 'windows' not in b]
    chk('contract_matches_snapshot', not bad and [x['capacity'] for x in C['tiers']] == [11, 16, 19, 26, 30, 38, 46, 57, 65, 74], bad[:4])
    # ---- floors, props, mirror, budget --------------------------------------------------------------------------------------------
    fl = [R / 'iso_tiles' / f'floor_{n}.png' for n in ('stone', 'plank', 'parquet', 'marble')]
    imp = lambda f: f.with_name(f.name + '.import')
    chk('floors_no_mipmaps', all(f.exists() and Image.open(f).size == (576, 336) and imp(f).exists() and 'mipmaps/generate=false' in imp(f).read_text() and 'compress/mode=0' in imp(f).read_text() for f in fl), [f.name for f in fl if not imp(f).exists()])
    pj = json.loads((R / 'iso_props/features/props.json').read_text()); want = ['chest_trae', 'chest_jern', 'chest_fe', 'chest_konge', 'dig_glimmer', 'unique_glimmer', 'tent', 'slate_vein', 'marble_vein']
    chk('props_manifest', all(p in pj and (R / 'iso_props/features' / pj[p]['file']).exists() and 0 <= pj[p]['pivot'][0] < pj[p]['size'][0] and 0 <= pj[p]['pivot'][1] < pj[p]['size'][1] for p in want), [p for p in want if p not in pj])
    mo = json.loads((homepaths.SPECS / 'mirror_ok.json').read_text())['mirror_ok']
    import measure_mirror as mm
    res = mm.measure(R / 'iso_props/furniture', spec)
    chk('mirror_ok_measured', sorted(mo) == sorted(res['ok']) and not [i for i in mo if S[i]['rarity'] in ('unique', 'legendary')], sorted(set(mo) ^ set(res['ok'])))
    tot = sum(f.stat().st_size for d in ('iso_props/home', 'iso_props/furniture', 'iso_props/interior', 'iso_props/fx', 'iso_props/features', 'icons/home', 'data/home') for f in (R / d).rglob('*') if f.is_file() and f.suffix not in ('.import', '.uid'))
    tot += sum(f.stat().st_size for f in (R / 'iso_tiles').glob('floor_*.png'))
    chk('byte_budget', tot <= 12_000_000, f'{tot / 1e6:.2f} MB')
    print(f'validate_features_home: {len(OK)} passed, {len(BAD)} failed, {tot / 1e6:.2f} MB')
    sys.exit(1 if BAD else 0)


if __name__ == '__main__':
    main()
