#!/usr/bin/env python3
"""Contact sheets of the A1 art (task 8: never single frames).  They are drawn from the EXPORTED tree (WebP), i.e. from what ships.

  python tools/art/features/home/isometric/sheets.py [--assets <stage>/assets | assets] [--out <stage>/sheets] [names ...]

names (default: all):
  tiers_contact_sheet     the 10 houses side by side at true scale on one ground line, footprint diamonds drawn
  tiers_strip_night       the 10 houses at night: the day sprite graded to the night navy with the additive window layer on top
  scaffolds               house N-1 with scaffold_toN drawn over it (the construction state), tiers 2..10
  ladder_<template>       one sheet per template: rows = the five rarities, the items of every EXISTING (template, rarity) cell side by side (91 of 110 cells exist)
  interior_wall_pieces    the wall styles x (plain, pilaster, window), both orientations, corner posts, door pieces, window at night; the four floors
  material_icons          the 32 material icons on kridt (chalk) + on night
  furniture_icons_130     the 130 furniture icons on kridt
  legendary_icons_on_night  the 11 legendary icons: plain on the night tile vs the _night variant with its pale rim
  props                   the nine new props on grass (day) and on night, additive glimmers composited
"""
from __future__ import annotations
import argparse, json, math, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import homepaths

KRIDT = (251, 245, 230); INK = (43, 35, 64); GRASS = (169, 211, 160); NIGHT = (47, 54, 84); NIGHT_NAVY = (28, 33, 56)
RARITY = ['normal', 'uncommon', 'rare', 'unique', 'legendary']


def font(size=14):
    for p in ('/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf', '/System/Library/Fonts/Supplemental/Arial.ttf', '/Library/Fonts/Arial.ttf'):
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def load(root: Path, rel: str) -> Image.Image:
    return Image.open(root / rel).convert('RGBA')


def paste_pivot(sheet, im, pivot, at):
    """alpha-composite `im` so that its pivot lands on `at` (x, y)"""
    sheet.alpha_composite(im, (int(at[0] - pivot[0]), int(at[1] - pivot[1])))


def tiers_contact_sheet(root, out):
    hj = json.loads((root / 'iso_props/home/home.json').read_text())['tiers']
    f = font(20); HW, HH = 64.0, 37.6
    ims = [(t['tier'], load(root, 'iso_props/home/' + t['exterior']['day']), t) for t in hj]
    gap = 40
    W = sum(i.width for _, i, _ in ims) + gap * (len(ims) + 1)
    up = max(t['exterior']['pivot'][1] for _, _, t in ims) + 60
    dn = max(i.height - t['exterior']['pivot'][1] for _, i, t in ims) + 140
    sheet = Image.new('RGBA', (W, up + dn), GRASS + (255,)); d = ImageDraw.Draw(sheet, 'RGBA')
    x = gap
    for n, im, t in ims:
        px, py = x + t['exterior']['pivot'][0], up
        r = t['footprint_rect']
        cell = lambda a, b: ((a - b) * HW, (a + b) * HH)
        pts = [cell(r[0], r[1]), cell(r[2], r[1]), cell(r[2], r[3]), cell(r[0], r[3])]
        d.polygon([(px + a, py + b) for a, b in pts], fill=(255, 255, 255, 38), outline=INK + (120,))
        sheet.alpha_composite(im, (x, up - t['exterior']['pivot'][1]))
        d.ellipse((px - 4, py - 4, px + 4, py + 4), fill=(179, 67, 107, 255))
        d.text((x, up + dn - 110), f"{n}. {t['id']}", fill=INK + (255,), font=f)
        d.text((x, up + dn - 80), f"{t['footprint_tiles'][0]}x{t['footprint_tiles'][1]} tiles, {t['height_m']} m, {im.width}x{im.height}px", fill=INK + (255,), font=f)
        x += im.width + gap
    sheet.convert('RGB').save(out / 'tiers_contact_sheet.png')


def night_grade(day: Image.Image, night: Image.Image | None, offset) -> Image.Image:
    """the house as the engine paints it at night: CanvasModulate-like navy multiply, then the additive window layer"""
    a = np.asarray(day, np.float32) / 255.0
    k = np.array([.42, .48, .78], np.float32)
    rgb = a[..., :3] * k
    out = np.concatenate([rgb, a[..., 3:]], -1)
    if night is not None:
        n = np.asarray(night, np.float32) / 255.0
        x0, y0 = offset
        h, w = n.shape[:2]
        reg = out[y0:y0 + h, x0:x0 + w, :3]
        out[y0:y0 + h, x0:x0 + w, :3] = np.clip(reg + n[..., :3] * n[..., 3:], 0, 1)
    return Image.fromarray(np.uint8(np.clip(out * 255 + .5, 0, 255)), 'RGBA')


def tiers_strip_night(root, out):
    hj = json.loads((root / 'iso_props/home/home.json').read_text())['tiers']
    items = []
    for t in hj:
        e = t['exterior']
        day = load(root, 'iso_props/home/' + e['day'])
        nt = load(root, 'iso_props/home/' + e['night']) if e.get('night') else None
        items.append((t, night_grade(day, nt, e.get('night_offset', (0, 0)))))
    gap = 30
    W = sum(i.width for _, i in items) + gap * (len(items) + 1)
    H = max(i.height for _, i in items) + 70
    sheet = Image.new('RGBA', (W, H), NIGHT_NAVY + (255,)); d = ImageDraw.Draw(sheet); f = font(20)
    x = gap
    for t, im in items:
        sheet.alpha_composite(im, (x, H - 50 - im.height))
        d.text((x, H - 40), f"{t['tier']}. {t['id']}", fill=(228, 239, 245), font=f)
        x += im.width + gap
    sheet.convert('RGB').save(out / 'tiers_strip_night.png')


def scaffolds(root, out):
    hj = json.loads((root / 'iso_props/home/home.json').read_text())['tiers']
    cols = []
    for t in hj[1:]:
        prev = hj[t['tier'] - 2]; sc = t['scaffold_from_previous']
        h = load(root, 'iso_props/home/' + prev['exterior']['day']); hp = prev['exterior']['pivot']
        s = load(root, 'iso_props/home/' + sc['file']); sp = sc['pivot']
        up = max(hp[1], sp[1]) + 20; dn = max(h.height - hp[1], s.height - sp[1]) + 20
        lt = max(hp[0], sp[0]) + 20; rt = max(h.width - hp[0], s.width - sp[0]) + 20
        c = Image.new('RGBA', (lt + rt, up + dn), GRASS + (255,))
        c.alpha_composite(h, (lt - hp[0], up - hp[1])); c.alpha_composite(s, (lt - sp[0], up - sp[1]))
        ImageDraw.Draw(c).text((8, 6), f"{t['tier'] - 1} -> {t['tier']}", fill=INK, font=font(18))
        cols.append(c)
    W = sum(c.width for c in cols); H = max(c.height for c in cols)
    sheet = Image.new('RGB', (W, H), GRASS); x = 0
    for c in cols:
        sheet.paste(c.convert('RGB'), (x, H - c.height)); x += c.width
    sheet.save(out / 'scaffolds.png')


def _item_sprite(root, fj, iid):
    e = fj['items'][iid]; ent = e['rot']['0']
    base = root / 'iso_props/furniture'
    im = Image.open(base / ent['file']).convert('RGBA')
    if 'float' in ent:
        im.alpha_composite(Image.open(base / ent['float']['file']).convert('RGBA'))
    return im, ent['pivot']


def ladders(root, out, only=None):
    fj = json.loads((root / 'iso_props/furniture/furniture.json').read_text())
    spec = json.loads((homepaths.SPECS / 'furniture_art_spec.json').read_text())['items']
    tpls = []
    for it in spec:
        if it['template'] not in tpls: tpls.append(it['template'])
    f = font(13); fh = font(18)
    made = []
    for tpl in tpls:
        if only and f'ladder_{tpl}' not in only: continue
        rows = {r: [it for it in spec if it['template'] == tpl and it['rarity'] == r] for r in RARITY}
        sprites = {i['id']: _item_sprite(root, fj, i['id']) for rs in rows.values() for i in rs}
        gap = 26; label_h = 64
        row_h = {r: (max(max(sprites[i['id']][0].height for i in rs) if rs else 0, 60) + label_h) for r, rs in rows.items()}
        row_w = {r: sum(sprites[i['id']][0].width + gap for i in rs) if rs else 220 for r, rs in rows.items()}
        W = max(row_w.values()) + 200; H = sum(row_h.values()) + 20
        sheet = Image.new('RGBA', (W, H), KRIDT + (255,)); d = ImageDraw.Draw(sheet)
        y = 10
        for r in RARITY:
            rs = rows[r]
            d.text((10, y + row_h[r] // 2 - 24), r, fill=INK, font=fh)
            d.line((0, y + row_h[r], W, y + row_h[r]), fill=(205, 185, 143), width=1)
            x = 180
            if not rs:
                d.rectangle((x, y + 12, x + 150, y + row_h[r] - 14), outline=(205, 185, 143), width=2)
                d.text((x + 28, y + row_h[r] // 2 - 8), 'no such piece', fill=(106, 90, 72), font=f)
            for it in rs:
                im, piv = sprites[it['id']]
                sheet.alpha_composite(im, (x, y + row_h[r] - label_h - im.height + 14))
                d.text((x, y + row_h[r] - 44), it['id'], fill=INK, font=f)
                d.text((x, y + row_h[r] - 28), f"{im.width}x{im.height}", fill=(106, 90, 72), font=f)
                x += im.width + gap
            y += row_h[r]
        sheet.convert('RGB').save(out / f'ladder_{tpl}.png'); made.append(f'ladder_{tpl}.png')
    return made


def interior_wall_pieces(root, out):
    ij = json.loads((root / 'iso_props/interior/interior.json').read_text())
    f = font(13); pieces = []
    for k, m in {**ij['walls'], **ij['door']}.items():
        pieces.append((k, load(root, 'iso_props/interior/' + m['file']), m['pivot'], m.get('night')))
    gap = 18
    colw = max(p[1].width for p in pieces) + gap
    per_row = 7
    rows = [pieces[i:i + per_row] for i in range(0, len(pieces), per_row)]
    rh = max(p[1].height for p in pieces) + 44
    floors = sorted((root / 'iso_tiles').glob('floor_*.png'))
    fl = [Image.open(p).convert('RGBA') for p in floors]
    H = rh * len(rows) + (fl[0].height + 36 if fl else 0)
    W = max(colw * per_row, sum(i.width + 12 for i in fl)) + 20
    sheet = Image.new('RGBA', (W, H), (214, 200, 168, 255)); d = ImageDraw.Draw(sheet)
    for ri, row in enumerate(rows):
        for ci, (k, im, piv, night) in enumerate(row):
            x = 10 + ci * colw; y = ri * rh
            sheet.alpha_composite(im, (x, y + rh - 40 - im.height))
            d.text((x, y + rh - 36), k, fill=INK, font=f)
    x = 10; y = rh * len(rows)
    for p, im in zip(floors, fl):
        sheet.alpha_composite(im, (x, y + 4)); d.text((x, y + im.height + 8), p.stem, fill=INK, font=f); x += im.width + 12
    sheet.convert('RGB').save(out / 'interior_wall_pieces.png')


def grid_icons(paths, names, out_png, bg, cols=10, size=128, label=True, extra=None):
    f = font(11)
    rows = math.ceil(len(paths) / cols); cell_h = size + (24 if label else 6)
    sheet = Image.new('RGBA', (cols * (size + 8) + 8, rows * cell_h + 8), bg + (255,)); d = ImageDraw.Draw(sheet)
    for i, (p, n) in enumerate(zip(paths, names)):
        im = Image.open(p).convert('RGBA')
        x = 8 + (i % cols) * (size + 8); y = 8 + (i // cols) * cell_h
        sheet.alpha_composite(im, (x, y))
        if label: d.text((x, y + size + 4), n[:20], fill=INK if sum(bg) > 400 else (228, 239, 245), font=f)
    sheet.convert('RGB').save(out_png)


def material_icons(root, out):
    contract = json.loads((homepaths.SPECS / 'content_contract.json').read_text())
    ids = sorted(contract['materials'])
    paths = [root / 'icons/home' / f'{i}.webp' for i in ids]
    grid_icons(paths, ids, out / 'material_icons.png', KRIDT, cols=8)
    grid_icons(paths, ids, out / 'material_icons_night.png', NIGHT, cols=8)


def furniture_icons(root, out):
    spec = json.loads((homepaths.SPECS / 'furniture_art_spec.json').read_text())['items']
    grid_icons([root / 'icons/home' / f"{i['id']}.webp" for i in spec], [i['id'] for i in spec], out / 'furniture_icons_130.png', KRIDT, cols=10)


def legendary_icons(root, out):
    contract = json.loads((homepaths.SPECS / 'content_contract.json').read_text())
    ids = sorted(i for i, e in contract['furniture'].items() if e['rarity'] == 'legendary')
    f = font(12)
    sheet = Image.new('RGBA', (len(ids) * 136 + 8, 2 * 148 + 12), NIGHT + (255,)); d = ImageDraw.Draw(sheet)
    for k, i in enumerate(ids):
        x = 8 + k * 136
        sheet.alpha_composite(load(root, f'icons/home/{i}.webp'), (x, 6)); sheet.alpha_composite(load(root, f'icons/home/{i}_night.webp'), (x, 150))
        d.text((x, 134), i[:18], fill=(228, 239, 245), font=f)
    sheet.convert('RGB').save(out / 'legendary_icons_on_night.png')


def props(root, out):
    pj = json.loads((root / 'iso_props/features/props.json').read_text())
    ids = [k for k in pj if not k.startswith('_')]
    f = font(14)
    ims = []
    for i in ids:
        m = pj[i]; ims.append((i, load(root, 'iso_props/features/' + m['file']), m))
    gap = 30; W = sum(im.width for _, im, _ in ims) + gap * (len(ims) + 1); H = max(max(im.height for _, im, _ in ims), 200) * 2 + 120
    sheet = Image.new('RGBA', (W, H), GRASS + (255,)); d = ImageDraw.Draw(sheet)
    half = H // 2
    d.rectangle((0, half, W, H), fill=NIGHT_NAVY + (255,))
    x = gap
    for i, im, m in ims:
        for night, y0 in ((False, half - 60), (True, H - 60)):
            piv = m['pivot']
            base = Image.new('RGBA', im.size, (0, 0, 0, 0))
            if m.get('blend') == 'add':
                a = np.asarray(im, np.float32) / 255
                layer = sheet.crop((x, y0 - piv[1], x + im.width, y0 - piv[1] + im.height))
                arr = np.asarray(layer, np.float32) / 255
                arr[..., :3] = np.clip(arr[..., :3] + a[..., :3] * a[..., 3:], 0, 1)
                sheet.paste(Image.fromarray(np.uint8(arr * 255 + .5), 'RGBA'), (x, y0 - piv[1]))
            else:
                sprite = im
                if night: sprite = night_grade(im, None, (0, 0))
                sheet.alpha_composite(sprite, (x, y0 - piv[1]))
                if 'glow' in m and night:
                    g = load(root, 'iso_props/features/' + m['glow']['file']); a = np.asarray(g, np.float32) / 255
                    cx, cy = m['glow']['center']; gx, gy = x + cx - g.width // 2, y0 - piv[1] + cy - g.height // 2
                    layer = sheet.crop((gx, gy, gx + g.width, gy + g.height)); arr = np.asarray(layer, np.float32) / 255
                    arr[..., :3] = np.clip(arr[..., :3] + a[..., :3] * a[..., 3:], 0, 1)
                    sheet.paste(Image.fromarray(np.uint8(arr * 255 + .5), 'RGBA'), (gx, gy))
        d.text((x, half - 50), i, fill=INK, font=f)
        d.text((x, H - 48), i, fill=(228, 239, 245), font=f)
        x += im.width + gap
    sheet.convert('RGB').save(out / 'props.png')


def distinct_pairs(root, out):
    """the pairs that shipped as pixel-identical twins before the fix round: sprite (x2) and icon of both ids, side by side"""
    fj = json.loads((root / 'iso_props/furniture/furniture.json').read_text())
    pairs = [('curtain_natural', 'curtain_green'), ('fireplace_marble', 'fireplace_slate'), ('floor_lamp_iron', 'floor_lamp_birch')]
    f = font(14); sc = 2
    cells = []
    for a, b in pairs:
        for iid in (a, b):
            ent = fj['items'][iid]['rot']['0']
            im = load(root, 'iso_props/furniture/' + ent['file']); im = im.resize((im.width * sc, im.height * sc), Image.LANCZOS)
            cells.append((iid, im, load(root, f'icons/home/{iid}.webp')))
    gap = 30; H = max(c[1].height for c in cells) + 128 + 70
    W = sum(max(c[1].width, 128) + gap for c in cells) + gap
    sheet = Image.new('RGBA', (W, H), KRIDT + (255,)); d = ImageDraw.Draw(sheet); x = gap
    for iid, im, ic in cells:
        w = max(im.width, 128)
        sheet.alpha_composite(im, (x, 10)); sheet.alpha_composite(ic, (x, 20 + max(c[1].height for c in cells)))
        d.text((x, H - 28), iid, fill=INK, font=f)
        x += w + gap
    sheet.convert('RGB').save(out / 'distinct_pairs.png')


def symmetry_views(root, out):
    """for each piece measure_symmetry.py found NOT to be symmetric as its template declared: the four rotations as the engine draws them (rot_map: baked index, flip)"""
    fj = json.loads((root / 'iso_props/furniture/furniture.json').read_text())['items']
    sm = json.loads((homepaths.SPECS / 'symmetry_measured.json').read_text())['items']
    ids = [i for i, m in sm.items() if m['class'] != m['declared']]
    f = font(13); gap = 16; rows = []
    for iid in ids:
        e = fj[iid]; views = []
        for k in range(4):
            idx, flip = e['rot_map'][k]; ent = e['rot'][str(idx)]
            im = load(root, 'iso_props/furniture/' + ent['file'])
            if 'float' in ent: im.alpha_composite(load(root, 'iso_props/furniture/' + ent['float']['file']))
            views.append((im, ent['pivot'], idx))
        up = max(v[1][1] for v in views); dn = max(max(v[0].height - v[1][1] for v in views), 8)
        lt = max(v[1][0] for v in views); rt = max(v[0].width - v[1][0] for v in views)
        rows.append((iid, e, views, up, dn, lt, rt))
    cw = max(r[5] + r[6] for r in rows) + gap
    W = 220 + 4 * cw; H = sum(r[3] + r[4] + 34 for r in rows) + 10
    sheet = Image.new('RGBA', (W, H), KRIDT + (255,)); d = ImageDraw.Draw(sheet); y = 6
    for iid, e, views, up, dn, lt, rt in rows:
        d.text((8, y + up // 2), f"{iid}", fill=INK, font=f); d.text((8, y + up // 2 + 16), f"{sm[iid]['declared']} -> {sm[iid]['class']}", fill=(106, 90, 72), font=f)
        for k, (im, piv, idx) in enumerate(views):
            x = 220 + k * cw + lt
            sheet.alpha_composite(im, (x - piv[0], y + up - piv[1]))
            d.text((x - lt, y + up + dn + 2), f"r{k} = baked r{idx}", fill=(106, 90, 72), font=f)
        d.line((0, y + up + dn + 26, W, y + up + dn + 26), fill=(205, 185, 143), width=1)
        y += up + dn + 34
    sheet.convert('RGB').save(out / 'symmetry_views.png')


ALL = ['tiers_contact_sheet', 'tiers_strip_night', 'scaffolds', 'ladders', 'interior_wall_pieces', 'material_icons', 'furniture_icons_130', 'legendary_icons_on_night', 'props', 'distinct_pairs', 'symmetry_views']


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0]); ap.add_argument('names', nargs='*')
    ap.add_argument('--assets', default=None); ap.add_argument('--out', default=None)
    a = ap.parse_args()
    root = Path(a.assets) if a.assets else homepaths.stage_root() / 'assets'
    out = Path(a.out) if a.out else homepaths.stage_root() / 'sheets'; out.mkdir(parents=True, exist_ok=True)
    want = a.names or ALL
    fns = {'tiers_contact_sheet': tiers_contact_sheet, 'tiers_strip_night': tiers_strip_night, 'scaffolds': scaffolds, 'interior_wall_pieces': interior_wall_pieces,
           'material_icons': material_icons, 'furniture_icons_130': furniture_icons, 'legendary_icons_on_night': legendary_icons, 'props': props,
           'distinct_pairs': distinct_pairs, 'symmetry_views': symmetry_views}
    for n in want:
        if n in fns: fns[n](root, out); print('sheet', n)
    ladder_names = [n for n in want if n.startswith('ladder_')]
    if 'ladders' in want or ladder_names:
        made = ladders(root, out, ladder_names or None); print('sheets', len(made), 'ladders')
    print('->', out)


if __name__ == '__main__':
    main()
