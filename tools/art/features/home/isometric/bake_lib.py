#!/usr/bin/env python3
"""Shared baker core for houses, furniture and interior pieces (same camera/lights/outline as bake_props.py).

bake_model(model, rot=0, ...) renders ONE view of a HM model and returns
    {'main': RGBA, 'emit': RGBA|None, 'float': RGBA|None, 'glow': RGBA|None, 'meta': {...}}
All layers share ONE crop box and ONE pivot (the model origin = ground anchor), so they can be stacked 1:1 in the engine.

  main   the lit sprite with warm outline + soft contact shadow
  emit   ADDITIVE layer: only emissive shapes (windows, flames, crystals), flat colour, alpha = brightness (night lights)
  float  a second sprite with only the shapes tagged layer='float' (floating orbs, runes) so the engine can bob it
  glow   soft halo (separate file, additive, centre given in meta)
"""
from __future__ import annotations
import math, sys, time
from types import SimpleNamespace
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import homepaths  # noqa: F401  (puts home/characters:home/isometric:generator:core on sys.path in the contract order)
import static_render as sr            # tools/art/core (P08), used through the path only
import geometry as geo
import build_assets as ba
import home_kit as hk

AZ = 45.0
PPM = sr.PX_PER_M
T = sr.TILE_M


# The core static_render (P08) has no tile cache and no 'planar' guard in model_mesh (the home spike's copy had both); the pieces of this package
# build their atlas through the two functions below instead, so the shared renderer stays untouched (handoff note in the README).
_TILE_CACHE = {}


def _tile(color, pattern, tile):
    """painted albedo tile of (color, pattern) at `tile` px, cached; 'name@Lu,Lv' patterns are painted natively at the target size"""
    k = (color, pattern, tile)
    if k not in _TILE_CACHE:
        _TILE_CACHE[k] = ba.paint_tile(color, pattern, tile) if (pattern in ba.EXTRA_PATTERNS or '@' in pattern) else ba.paint_tile(color, pattern, 256).resize((tile, tile), Image.BICUBIC)
    return _TILE_CACHE[k]


def model_mesh(m, tile=512):
    """Static mesh of a whole geometry.Model (the icon baker of the material icons): pos, normals, uv, faces, atlas.  Planar-UV shapes keep their uv."""
    return mesh_from_shapes(collect_shapes(m), tile)


def cam_basis(az=AZ, elev=sr.ELEV):
    a, e = math.radians(az), math.radians(elev)
    d = -np.array([math.sin(a) * math.cos(e), math.sin(e), math.cos(a) * math.cos(e)])
    right = np.cross(d, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, d); up /= np.linalg.norm(up)
    return right, up


def project(p):
    """world metres -> px relative to the focus (0,0,0); +y screen down"""
    r, u = cam_basis()
    p = np.asarray(p, float).reshape(-1, 3)
    return np.c_[p @ r * PPM, -(p @ u) * PPM]


def tile_to_px(x_tiles, z_tiles, y_m=0.0):
    return project([x_tiles * T, y_m, z_tiles * T])[0]


def yaw_matrix(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])      # (x,z) -> (x c + z s, -x s + z c)


# ----------------------------------------------------------------------------------------------------------------------
def collect_shapes(model, layer=None, emissive_pass=False):
    out = []
    model = getattr(model, 'm', model)
    for g in model.groups:
        for s in g.shapes:
            lay = getattr(s, 'layer', 'main')
            if layer is not None and lay != layer: continue
            emit = getattr(s, 'emit', False)
            if getattr(s, 'night_only', False) and not emissive_pass: continue
            col, pat = s.color, getattr(s, 'pattern', 'soft')
            if emissive_pass and not emit: col, pat = '000000', 'emit'
            out.append(SimpleNamespace(vertices=s.vertices, faces=s.faces, color=col, pattern=pat,
                                       uv=getattr(s, 'uv', None), planar=getattr(s, 'planar', False), emit=emit))
    return out


def mesh_from_shapes(shapes, tile=512):
    keys = []
    for s in shapes:
        k = (s.color, s.pattern)
        if k not in keys: keys.append(k)
    n = len(keys)
    grid = 4 if n <= 16 else (8 if n <= 64 else 12)
    atlas = Image.new('RGB', (grid * tile, grid * tile), (128, 128, 128))
    for i, (color, pattern) in enumerate(keys):
        atlas.paste(_tile(color, pattern, tile), ((i % grid) * tile, (i // grid) * tile))
    P, N, UV, F = [], [], [], []
    off = 0; pad = 6 / 256
    for s in shapes:
        v, f = s.vertices, s.faces
        nrm = geo.smooth_normals(v, f)
        uv = s.uv.copy() if s.uv is not None else ba.shape_uv(SimpleNamespace(vertices=v, faces=f))
        vp, np_, uvp, ff = list(v), list(nrm), list(uv), []
        for tri in f:
            tri = tri.copy(); tu = uv[tri, 0]
            if np.ptp(tu) > .65 and not s.planar:
                high = tu > .5
                for k, vi in enumerate(tri):
                    newuv = uv[vi].copy(); newuv[0] = 1.0 if high.sum() >= 2 else 0.0
                    if (high.sum() >= 2 and not high[k]) or (high.sum() < 2 and high[k]):
                        tri[k] = len(vp); vp.append(v[vi]); np_.append(nrm[vi]); uvp.append(newuv)
            ff.append(tri)
        uvp = np.array(uvp)
        tidx = keys.index((s.color, s.pattern)); tx, ty = tidx % grid, tidx // grid
        uvp[:, 0] = (tx + pad + np.clip(uvp[:, 0], 0, 1) * (1 - 2 * pad)) / grid
        uvp[:, 1] = (ty + pad + np.clip(uvp[:, 1], 0, 1) * (1 - 2 * pad)) / grid
        P.append(np.array(vp)); N.append(np.array(np_)); UV.append(uvp); F.append(np.array(ff) + off)
        off += len(vp)
    return np.concatenate(P), np.concatenate(N), np.concatenate(UV), np.concatenate(F), atlas


def rotate_mesh(pos, nrm, deg):
    if deg % 360 == 0: return pos, nrm
    R = yaw_matrix(deg)
    return pos @ R.T, nrm @ R.T


def render_layer(shapes, deg, W, H, ss, emissive=False, tile=512):
    pos, nrm, uv, faces, atlas = mesh_from_shapes(shapes, tile)
    pos, nrm = rotate_mesh(pos, nrm, deg)
    rend = sr.StaticRenderer(pos, nrm, uv, faces, atlas, ambient=1.0 if emissive else .44, diffuse=0.0 if emissive else .59)
    if emissive: rend.actor.GetProperty().SetSpecular(0)
    return rend.render(W, H, az=AZ, focus=(0, 0, 0), ss=ss), pos


def emissive_to_additive(im: Image.Image) -> Image.Image:
    a = np.asarray(im, np.float32) / 255.0
    rgb = a[..., :3] * a[..., 3:4]
    mx = rgb.max(-1, keepdims=True)
    out = np.zeros_like(a)
    out[..., :3] = np.where(mx > 1e-4, rgb / np.maximum(mx, 1e-4), 0)
    out[..., 3:4] = mx
    return Image.fromarray(np.uint8(np.clip(out * 255 + .5, 0, 255)), 'RGBA')


def footprint_shadow(size, center_px, rect_tiles, strength=.30, blur=6, inset=.12, offset=(0, 0), color=(43, 35, 64)):
    """soft shadow diamond for a rectangular footprint (xmin,zmin,xmax,zmax) in tiles around the pivot"""
    x0, z0, x1, z1 = rect_tiles
    pts = [tile_to_px(x0 + inset, z0 + inset), tile_to_px(x1 - inset, z0 + inset), tile_to_px(x1 - inset, z1 - inset), tile_to_px(x0 + inset, z1 - inset)]
    pts = [(center_px[0] + p[0] + offset[0], center_px[1] + p[1] + offset[1]) for p in pts]
    sh = Image.new('L', size, 0); ImageDraw.Draw(sh).polygon(pts, fill=int(255 * strength))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new('RGBA', size, color + (0,)); out.putalpha(sh)
    return out


def bake_model(model, rot=0, *, ss=3, tile=512, outline=True, shadow=None, footprint=None, pad=10, glow=None, glow_at=None,
               want_emit=False, outline_color=(75, 60, 73), outline_alpha=.55, shadow_strength=.30, shadow_blur=6, sort_footprint=None):
    """rot: yaw degrees about +Y applied to the whole model (0,90,180,270).  shadow: None | ('ellipse', rx_m, ry_m) | ('rect',) uses footprint (xmin,zmin,xmax,zmax tiles, ALREADY rotated)."""
    t0 = time.time()
    main_sh = [s for s in collect_shapes(model, 'main')]
    float_sh = collect_shapes(model, 'float')
    # extents from all shapes (rotated)
    allv = np.concatenate([s.vertices for s in main_sh + float_sh]) @ yaw_matrix(rot).T
    scr = project(allv)
    ext_x = abs(scr[:, 0]).max() + pad + 6; ext_y_up = -scr[:, 1].min() + pad + 6; ext_y_dn = scr[:, 1].max() + pad + 6
    if footprint is not None and shadow is not None:
        corners = [tile_to_px(footprint[0], footprint[1]), tile_to_px(footprint[2], footprint[1]), tile_to_px(footprint[2], footprint[3]), tile_to_px(footprint[0], footprint[3])]
        cs = np.array(corners); ext_x = max(ext_x, abs(cs[:, 0]).max() + pad + 8); ext_y_dn = max(ext_y_dn, cs[:, 1].max() + pad + 8); ext_y_up = max(ext_y_up, -cs[:, 1].min() + pad)
    if shadow is not None and shadow[0] == 'ellipse':
        ext_x = max(ext_x, shadow[1] * PPM * 1.25 + pad); ext_y_dn = max(ext_y_dn, shadow[2] * PPM * math.sin(math.radians(sr.ELEV)) * 1.25 + pad + 10)
    half_w = int(math.ceil(ext_x)); up = int(math.ceil(ext_y_up)); dn = int(math.ceil(ext_y_dn))
    W = 2 * half_w + 2; Hh = up + dn + 2; cx = half_w + 1; cy = up + 1
    # render with the focus at the ground origin; the renderer centres focus in the image -> render a symmetric canvas of height 2*max(up,dn)
    Hs = 2 * max(up, dn) + 2; cy_s = Hs // 2
    im_main, _ = render_layer(main_sh, rot, W, Hs, ss, tile=tile)
    if outline: im_main = sr.warm_outline(im_main, color=outline_color, alpha=outline_alpha)
    canvas = Image.new('RGBA', (W, Hs), (0, 0, 0, 0))
    if shadow is not None:
        if shadow[0] == 'ellipse':
            rx, ry = shadow[1] * PPM, shadow[2] * PPM * math.sin(math.radians(sr.ELEV))
            canvas.alpha_composite(sr.soft_shadow((W, Hs), (cx, cy_s), rx, ry, shadow_strength, shadow_blur, (int(rx * .08), int(ry * .12))))
        else:
            canvas.alpha_composite(footprint_shadow((W, Hs), (cx, cy_s), footprint, shadow_strength, shadow_blur, offset=(2, 3)))
    canvas.alpha_composite(im_main)
    layers = {'main': canvas}
    if float_sh:
        im_f, _ = render_layer(float_sh, rot, W, Hs, ss, tile=tile)
        layers['float'] = sr.warm_outline(im_f, color=outline_color, alpha=outline_alpha) if outline else im_f
    if want_emit:
        em_sh = collect_shapes(model, None, emissive_pass=True)
        if any(s.emit for s in em_sh):
            im_e, _ = render_layer(em_sh, rot, W, Hs, ss, emissive=True, tile=tile)
            layers['emit'] = emissive_to_additive(im_e)
    # crop box from the visible layers
    union = canvas.getchannel('A').point(lambda v: 255 if v > 3 else 0)
    if 'float' in layers:
        union = Image.fromarray(np.maximum(np.asarray(union), np.asarray(layers['float'].getchannel('A').point(lambda v: 255 if v > 3 else 0))))
    bbox = union.getbbox(); x0, y0, x1, y1 = bbox[0] - 1, bbox[1] - 1, bbox[2] + 1, bbox[3] + 1
    out = {k: v.crop((x0, y0, x1, y1)) for k, v in layers.items()}
    pivot = [cx - x0, cy_s - y0]
    meta = {'size': list(out['main'].size), 'pivot': pivot, 'bake_seconds': round(time.time() - t0, 2)}
    if glow:
        col, rad, strength = glow[:3]
        gy = glow[3] if len(glow) > 3 else (0, .5, 0)
        gp = project(np.asarray([gy], float) @ yaw_matrix(rot).T)[0]
        halo = sr.glow_halo(col, rad, strength)
        out['glow'] = halo
        meta['glow'] = {'file': None, 'center': [int(cx + gp[0] - x0), int(cy_s + gp[1] - y0)], 'color': '#' + col, 'size': list(halo.size)}
    return out | {'meta': meta}


def key_corner(rect):
    """y-sort key (in tiles relative to the pivot) for a footprint rect (xmin,zmin,xmax,zmax): left-front corner if W>=D else right-back corner"""
    x0, z0, x1, z1 = rect
    return (x0, z1) if (x1 - x0) >= (z1 - z0) else (x1, z0)


def ysort_px(rect):
    kx, kz = key_corner(rect)
    p = tile_to_px(kx, kz)
    return [round(float(p[0]), 1), round(float(p[1]), 1)]
