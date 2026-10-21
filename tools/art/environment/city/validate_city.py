#!/usr/bin/env python3
"""Pure-Python validator of the installed city set (the second implementation of tests/sections/art_city.gd, P08-style checks for props):
sizes against the table at the Lua scale, pivot inside the image, footprint pair, tiles wrap, huts have additive trimmed night layers, lossless WebP only,
<= 70 MB RGBA8 + mips, nothing above 2048 px.   python tools/art/environment/city/validate_city.py [--assets assets] [--stage DIR] ; exit 1 on any failure.

--stage DIR validates the PNG masters of a stage instead of the installed WebP files (before install).
The installed check leaves out the copies a later art pack supersedes (they are not kept, review REND-10; art_city checks the files ArtCatalog draws).
"""
from __future__ import annotations
import argparse, json, re, sys
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import city_spec as S   # noqa: E402
sys.path.insert(0, str(HERE.parents[1] / 'drawn'))
import drawn_art   # noqa: E402

BUDGET_MB = 70.0


def webp_lossless(path: Path) -> tuple:
    b = path.read_bytes()
    if b[:4] != b'RIFF' or b[8:12] != b'WEBP':
        return False, 'not a RIFF WebP'
    pos, lossy, lossless = 12, False, False
    while pos + 8 <= len(b):
        fourcc = b[pos:pos + 4]
        size = int.from_bytes(b[pos + 4:pos + 8], 'little')
        lossy |= fourcc == b'VP8 '
        lossless |= fourcc == b'VP8L'
        pos += 8 + size + (size & 1)
    return (lossless and not lossy), ('lossy VP8' if lossy else ('no VP8L' if not lossless else ''))


def wrap_ratio(im: Image.Image, vertical: bool) -> float:
    a = np.asarray(im.convert('L'), np.float32)
    if not vertical:
        a = a.T
    seam = np.abs(a[0] - a[-1]).mean()
    inner = np.abs(np.diff(a, axis=0)).mean()
    return float(seam / max(inner, 0.01))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--assets', default=str(HERE.parents[3] / 'assets'))
    ap.add_argument('--stage', default=None)
    a = ap.parse_args()
    if a.stage:
        pdir = Path(a.stage) / 'masters' / 'iso_props' / 'city'
        bdir = Path(a.stage) / 'masters' / 'backdrops'
        ext = '.png'
    else:
        pdir = Path(a.assets) / 'iso_props' / 'city'
        bdir = Path(a.assets) / 'backdrops'
        ext = '.webp'
    root = Path(a.assets).resolve().parent
    superseded = []

    def gone(sid: str, f: Path) -> bool:
        """An installed copy a later art pack supersedes: not kept, not checked here."""
        if a.stage or not drawn_art.superseded(f.resolve(), root):
            return False
        superseded.append(sid)
        return True

    props = json.loads((pdir / 'props.json').read_text())
    props.pop('_results', None)
    k = S.K
    table = S.expected_sizes(k)
    fails, notes = [], []

    def fail(msg):
        fails.append(msg)

    total = 0.0
    biggest = 0
    for sid, want in table.items():
        if sid in ('treetop_sky', 'treetop_far'):
            continue
        e = props.get(sid)
        if e is None:
            fail(f'{sid}: not in props.json')
            continue
        f = pdir / Path(e['file']).with_suffix(ext).name
        if gone(sid, f):
            continue
        if not f.exists():
            fail(f'{sid}: {f.name} missing')
            continue
        im = Image.open(f)
        w, h = im.size
        if abs(w - want[0]) > 2 or abs(h - want[1]) > 2:
            fail(f'{sid}: {w}x{h} vs table {want}')
        if list(e['size']) != [w, h]:
            fail(f'{sid}: json size {e["size"]} vs file {w}x{h}')
        px, py = e['pivot']
        if not (0 <= px <= w and 0 <= py <= h):
            fail(f'{sid}: pivot {e["pivot"]} outside {w}x{h}')
        if len(e.get('footprint', [])) != 2:
            fail(f'{sid}: footprint {e.get("footprint")}')
        total += w * h * 4 * S.MIP
        biggest = max(biggest, w, h)
        if ext == '.webp':
            ok, why = webp_lossless(f)
            if not ok:
                fail(f'{sid}: {why}')
        if sid.startswith('trunk_bark_w') and wrap_ratio(im, True) > 1.8:
            fail(f'{sid}: tile does not wrap vertically')
        if sid.startswith('bridge_deck_tile_') and wrap_ratio(im, False) > 1.8:
            fail(f'{sid}: tile does not wrap in x')
        if sid in ('ladder_tile', 'rope_tile') and wrap_ratio(im, True) > 2.0:
            fail(f'{sid}: tile does not wrap vertically')
    for h in S.hut_ids():
        e = props.get(h, {})
        nid = e.get('night')
        if not nid or nid not in props:
            fail(f'{h}: no night layer')
            continue
        n = props[nid]
        f = pdir / Path(n['file']).with_suffix(ext).name
        if gone(nid, f):
            continue
        im = np.asarray(Image.open(f).convert('RGBA'), np.float32)
        total += im.shape[0] * im.shape[1] * 4 * S.MIP
        if n.get('blend') != 'add':
            fail(f'{nid}: not additive')
        alpha = im[..., 3]
        dim = ((alpha >= 48) & (im[..., :3].max(-1) < 120)).sum()
        ys, xs = np.where(alpha > 0)
        if dim or len(xs) < 200 or xs.min() > 1 or ys.min() > 1 or xs.max() < im.shape[1] - 2 or ys.max() < im.shape[0] - 2:
            fail(f'{nid}: dim pixels {dim}, lit {len(xs)}, not trimmed')
        off = e.get('night_offset', [-1, -1])
        dw, dh_ = e['size']
        if off[0] < 0 or off[1] < 0 or off[0] + im.shape[1] > dw or off[1] + im.shape[0] > dh_:
            fail(f'{nid}: offset {off} outside the day sprite')
    for b in ('treetop_sky', 'treetop_far'):
        f = bdir / (b + ext)
        if gone(b, f):
            continue
        if not f.exists():
            fail(f'{b}{ext} missing')
            continue
        im = Image.open(f)
        if list(im.size) != list(S.SIZES[b]):
            fail(f'{b}: {im.size} vs {S.SIZES[b]}')
        total += im.size[0] * im.size[1] * 4                      # sky and far are imported without mipmaps
        biggest = max(biggest, *im.size)
        if ext == '.webp':
            ok, why = webp_lossless(f)
            if not ok:
                fail(f'{b}: {why}')
    mb = total / 1e6
    if mb > BUDGET_MB:
        fail(f'memory {mb:.1f} MB > {BUDGET_MB} MB')
    if biggest > 2048:
        fail(f'a side of {biggest} px is above 2048')
    print(f'validate_city: K {k}, {len(table)} textures, {mb:.1f} MB RGBA8 + mips (sky / far without), largest side {biggest}'
          + (f'; {len(superseded)} superseded copies left to the painted packs' if superseded else ''))
    for m in fails:
        print('FAIL', m)
    print('PASS' if not fails else f'{len(fails)} FAILURES')
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
