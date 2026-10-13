#!/usr/bin/env python3
"""Quick rarity-ladder PREVIEW of a template with the default style ladder (each template baked in 5 tiers, r0 view):

  python tools/art/features/home/isometric/ladder.py OUT.png template[:kw=val,...] ...

This is the spike's design tool.  The ladders of the SHIPPED items (every existing (template, rarity) cell of the spec) are drawn by sheets.py (ladder_<template>.png).
"""
import sys, json, math, time
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor
import homepaths

DEFAULT_STYLES = [dict(tier=0, wood='pine'), dict(tier=1, wood='pine', paint='himmel', fabric='roed'), dict(tier=2, wood='walnut', fabric='bordeaux'),
                  dict(tier=3, wood='living', fabric='groen'), dict(tier=4, wood='moonwood', fabric='maane', metal='soelv')]


def job(a):
    tpl, kw, sty, rot, ss = a
    import bake_lib as bl, furniture_traetoppen as ft
    S = ft.Style(**sty); spec = ft.TEMPLATES[tpl](S, **kw)
    fx, fz = spec.fp if rot % 2 == 0 else spec.fp[::-1]
    rect = (-fx / 2, -fz / 2, fx / 2, fz / 2)
    t0 = time.time()
    r = bl.bake_model(spec.pm, 90 * rot, ss=ss, shadow=('rect',) if spec.layer != 'wall' else None, footprint=rect if spec.layer != 'wall' else None, want_emit=False,
                      glow=spec.glow, shadow_strength=.3, shadow_blur=6, tile=256)
    return r, spec, time.time() - t0


def main():
    from PIL import Image, ImageDraw, ImageFont
    out = sys.argv[1]; items = sys.argv[2:]
    rows = []
    jobs = []
    for it in items:
        tpl, _, kws = it.partition(':'); kw = {}
        for p in [x for x in kws.split(',') if x]:
            k, v = p.split('='); kw[k] = int(v) if v.isdigit() else v
        for sty in DEFAULT_STYLES: jobs.append((tpl, kw, sty, int(kw.pop('rot', 0)) if False else 0, 2))
    with ProcessPoolExecutor(6) as ex: res = list(ex.map(job, jobs))
    f = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf', 18)
    n = len(DEFAULT_STYLES); cw = max(r['main'].width for r, _, _ in res) + 24; ch = max(r['main'].height for r, _, _ in res) + 46
    sheet = Image.new('RGBA', (cw * n, ch * len(items)), (232, 220, 190, 255)); d = ImageDraw.Draw(sheet)
    names = ['normal', 'uncommon', 'rare', 'unique', 'legendary']
    for i, (r, spec, secs) in enumerate(res):
        row, col = divmod(i, n); x = col * cw + 12; y = row * ch
        im = r['main']; px, py = r['meta']['pivot']
        # additive glow
        sheet.alpha_composite(im, (x + (cw - im.width) // 2, y + ch - 30 - im.height))
        if 'float' in r: sheet.alpha_composite(r['float'], (x + (cw - im.width) // 2, y + ch - 30 - im.height))
        d.text((x, y + ch - 26), f"{items[row].split(':')[0]}  {names[col]}  {secs:.1f}s {im.width}x{im.height}", fill=(43, 35, 64, 255), font=f)
    sheet.convert('RGB').save(out); print(sheet.size)


if __name__ == '__main__': main()
