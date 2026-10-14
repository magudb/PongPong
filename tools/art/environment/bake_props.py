#!/usr/bin/env python3
"""Bake static props to cropped transparent PNGs + one props.json with pivots (P22).

  tools/art/produce_all.sh --only=props [ids...]         (what the pipeline calls: bake_props.py --all|ids --out <masters>/iso_props)
  python tools/art/environment/bake_props.py [--all] [ids...] --out DIR [--ss 3] [--list]

Two kinds of prop share the manifest:
  * MODEL props   builders in props_traetoppen.py (the verified spike set), props_farm.py (contract props of the treetop farm),
                  props_town.py (Hyggebyen buildings and street furniture, the new crops), props_forest.py (Moerkeskoven crowns, bushes,
                  runestone, cave ring ...).  Rendered by static_render.py with the character camera (36 degrees, az 45 for iso art), a warm
                  outline and an optional soft contact shadow; same scale as characters and tiles (87.074 px / m).
  * IMAGE props   painted with Pillow (props_images.py): additive decals and fx (telegraph rings, halos, sparkles, lantern light),
                  seamless ground textures, mist.  They are NOT 3D bakes: they carry `kind` in the manifest.

Output per prop: <id>.png (straight-alpha RGBA, outline + soft contact shadow baked in, ground pivot recorded) and, for glowing props,
<id>_glow.png (additive halo).  props.json: {id: {file, size, pivot, footprint, elev, [glow], [blend], [proj], ...}}.
A sprite is placed with `Sprite2D centered = false, offset = -pivot` under a node at the ground origin; a `blend: add` prop is additive.
"""
from __future__ import annotations
import argparse, importlib, json, math, sys, time
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'core'))
import artpaths                       # noqa: E402,F401  (adds generator, core, environment to sys.path)
import static_render as sr            # noqa: E402
import build_assets as ba             # noqa: E402
import props_traetoppen as pp         # noqa: E402

ba.EXTRA_PATTERNS.update(pp.PROP_PATTERNS)          # the painted albedo patterns of the props (the generator hook, no dependency on P21's file)

AZ = 45.0
MODULES = ['props_farm', 'props_town', 'props_forest']       # register into pp.PROPS on import
IMAGE_MODULES = ['props_images']                              # register into IMAGE_PROPS (name -> callable returning a props_images.ImageProp)
IMAGE_PROPS: dict = {}


def load_registry():
    for m in MODULES:
        importlib.import_module(m)
    for m in IMAGE_MODULES:
        mod = importlib.import_module(m)
        IMAGE_PROPS.update(mod.IMAGE_PROPS)
    return pp.PROPS, IMAGE_PROPS


def cam_basis(az=AZ, elev=sr.ELEV):
    a, e = math.radians(az), math.radians(elev)
    d = -np.array([math.sin(a) * math.cos(e), math.sin(e), math.cos(a) * math.cos(e)])
    right = np.cross(d, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, d); up /= np.linalg.norm(up)
    return right, up


def project(p, az=AZ, elev=sr.ELEV):
    r, u = cam_basis(az, elev)
    return np.c_[p @ r * sr.PX_PER_M, -(p @ u) * sr.PX_PER_M]     # px, screen y down, focus at (0,0)


def _outline(im, spec):
    if spec.outline is True:
        return sr.warm_outline(im)
    if isinstance(spec.outline, dict):
        o = spec.outline
        return sr.warm_outline(im, radius=o.get('radius', 2), color=tuple(o.get('color', (75, 60, 73))), alpha=o.get('alpha', .55))
    return im


def bake_prop(name, spec, out: Path, ss=3, tile=512):
    t0 = time.time()
    m = spec.m
    az = AZ if spec.az is None else spec.az
    elev = sr.ELEV if spec.elev is None else spec.elev
    ss = spec.ss or ss
    pos, nrm, uv, faces, atlas = sr.model_mesh(m, tile)
    scr = project(pos, az, elev)
    pad = spec.canvas_pad + 6
    sh_rx = sh_ry = 0
    if spec.shadow:
        sh_rx = spec.shadow[0] * sr.PX_PER_M * 1.25; sh_ry = spec.shadow[1] * sr.PX_PER_M * math.sin(math.radians(sr.ELEV)) * 1.25
    half_w = int(max(abs(scr[:, 0]).max() + pad, sh_rx + pad)); half_h = int(max(abs(scr[:, 1]).max() + pad, sh_ry + pad + 10))
    W, H = 2 * half_w + 2, 2 * half_h + 2
    kw = {}
    if spec.ambient is not None: kw['ambient'] = spec.ambient
    if spec.diffuse is not None: kw['diffuse'] = spec.diffuse
    renderer = sr.StaticRenderer(pos, nrm, uv, faces, atlas, **kw)
    im = renderer.render(W, H, az=az, focus=(0, 0, 0), ss=ss, elev=elev)
    post = spec.post
    if post is not None:
        im = post(im)
    im = _outline(im, spec)
    canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cx, cy = W // 2, H // 2          # focus (ground origin) lands at the image centre
    if spec.under is not None:
        canvas.alpha_composite(spec.under(W, H, cx, cy))
    if spec.shadow:
        canvas.alpha_composite(sr.soft_shadow((W, H), (cx, cy), sh_rx / 1.25, sh_ry / 1.25, .30, 5, (int(sh_rx * .10), int(sh_ry * .12))))
    canvas.alpha_composite(im)
    bbox = canvas.getchannel('A').point(lambda v: 255 if v > 3 else 0).getbbox()
    x0, y0, x1, y1 = bbox[0] - 1, bbox[1] - 1, bbox[2] + 1, bbox[3] + 1
    canvas = canvas.crop((x0, y0, x1, y1))
    pivot = [cx - x0, cy - y0]
    canvas.save(out / f'{name}.png', compress_level=6)
    meta = {'file': f'{name}.png', 'size': list(canvas.size), 'pivot': pivot, 'footprint': list(spec.footprint), 'elev': elev}
    if spec.glow:
        col, rad, strength = spec.glow[:3]
        gy = (spec.glow[3] if len(spec.glow) > 3 else (0, max(float(pos[:, 1].max()) * .5, .25), 0))
        gp = project(np.array([gy]), az, elev)[0]
        halo = sr.glow_halo(col, rad, strength)
        halo.save(out / f'{name}_glow.png')
        meta['glow'] = {'file': f'{name}_glow.png', 'center': [int(cx + gp[0] - x0), int(cy + gp[1] - y0)], 'color': '#' + col, 'size': list(halo.size)}
    meta.update(spec.extra)
    meta['_origin_shift'] = [x0, y0, cx, cy]       # consumed by the crown / decal bookkeeping below, removed before the json is written
    return meta, canvas


def bake_image_prop(name, ip, out: Path):
    """An ImageProp (props_images.py): a PIL RGBA image + pivot + manifest extras (and an optional glow halo)."""
    t0 = time.time()
    im = ip.image.convert('RGBA')
    im.save(out / f'{name}.png', compress_level=6)
    meta = {'file': f'{name}.png', 'size': list(im.size), 'pivot': [int(ip.pivot[0]), int(ip.pivot[1])], 'footprint': list(ip.footprint)}
    meta.update(ip.extra)
    return meta, im


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('  tools/art/produce_all.sh')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('names', nargs='*'); ap.add_argument('--all', action='store_true')
    ap.add_argument('--out', default=None, help='default: <masters>/iso_props (tools/art/_stage/masters/iso_props)'); ap.add_argument('--ss', type=int, default=3)
    ap.add_argument('--meta', default='props.json'); ap.add_argument('--list', action='store_true', help='print the registered ids and exit')
    a = ap.parse_args()
    models, images = load_registry()
    if a.list:
        for n in models: print('model', n)
        for n in images: print('image', n)
        return
    out = Path(a.out) if a.out else artpaths.masters_dir() / 'iso_props'
    out.mkdir(parents=True, exist_ok=True)
    names = list(models) + list(images) if a.all or not a.names else a.names
    unknown = [n for n in names if n not in models and n not in images]
    if unknown:
        raise SystemExit(f'ERROR: unknown prop id {unknown} (--list shows the {len(models) + len(images)} registered ids)')
    metap = out / a.meta
    meta = json.loads(metap.read_text()) if metap.exists() else {}
    meta['_contract'] = {'tile': [sr.TILE_W, sr.TILE_H], 'tile_edge_m': round(sr.TILE_M, 4), 'px_per_m': round(sr.PX_PER_M, 3),
                         'camera': 'orthographic, az 45, elevation 36', 'pivot': 'ground origin (footprint centre), px from PNG top-left',
                         'files': 'relative to this json',
                         'blend': 'props with blend "add" are additive soft sprites: draw with CanvasItemMaterial BLEND_MODE_ADD',
                         'seamless': 'props with seamless true are 256 px repeating ground textures (texture repeat), not placed sprites'}
    for n in names:
        if n in models:
            m, _ = bake_prop(n, models[n](), out, a.ss)
            m.pop('_origin_shift', None)
        else:
            m, _ = bake_image_prop(n, images[n](), out)
        meta[n] = m
        print(n, m['size'], m['pivot'], flush=True)
    metap.write_text(json.dumps(dict(sorted(meta.items(), key=lambda kv: (kv[0] != '_contract', kv[0]))), indent=1))


if __name__ == '__main__':
    main()
