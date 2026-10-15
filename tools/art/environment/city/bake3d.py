"""VTK bake of the city's model props (huts, stall, fire pit, tub halves, planters, log stack, notice board, seed basket, bat house).

Same camera, lights, gamma and warm outline as every world sprite (tools/art/core/static_render.py: 36 degrees, 87.074 px/m, azimuth 45).
Differences to environment/bake_props.py (which bakes the P22 props and is NOT touched):
  * NO baked soft shadow: the sprite size is the table size of the work order (the engine draws the shadows)
  * `fit`: the model is scaled in x/z and in y (an affine fit of the proportions) until the cropped sprite is the TARGET size (+-1 px)
  * an optional additive `emit` layer from the shapes tagged `emit` (lit door and windows), trimmed to its own alpha bbox like A1's house tiers
"""
from __future__ import annotations
import math
import sys
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / 'core'))
import artpaths                       # noqa: E402,F401  (adds generator, core, environment to sys.path)
import static_render as sr            # noqa: E402
import build_assets as ba             # noqa: E402
import props_traetoppen as pp         # noqa: E402

ba.EXTRA_PATTERNS.update(pp.PROP_PATTERNS)
AZ = 45.0
PPM = sr.PX_PER_M


def cam_basis(az=AZ, elev=sr.ELEV):
    a, e = math.radians(az), math.radians(elev)
    d = -np.array([math.sin(a) * math.cos(e), math.sin(e), math.cos(a) * math.cos(e)])
    right = np.cross(d, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, d); up /= np.linalg.norm(up)
    return right, up


def project(p, az=AZ, elev=sr.ELEV):
    r, u = cam_basis(az, elev)
    p = np.asarray(p, float).reshape(-1, 3)
    return np.c_[p @ r * PPM, -(p @ u) * PPM]


def scale_model(m, sx: float, sy: float) -> None:
    S = np.array([sx, sy, sx])
    for g in m.groups:
        for s in g.shapes:
            s.vertices = s.vertices * S


def _flat_mesh(m, night: bool, tile=512):
    """model_mesh of the static renderer, but the night pass paints every non-emissive shape black and every emissive one in its light colour."""
    for g in m.groups:
        for s in g.shapes:
            if night:
                if getattr(s, 'emit', False):
                    s.color = getattr(s, 'emit_color', s.color)
                else:
                    s.color, s.pattern = '000000', 'soft'
    return sr.model_mesh(m, tile)


def emissive_to_additive(im: Image.Image) -> Image.Image:
    a = np.asarray(im, np.float32) / 255.0
    rgb = a[..., :3] * a[..., 3:4]
    mx = rgb.max(-1, keepdims=True)
    mx = np.where(mx < 0.06, 0.0, mx)                 # the black of the unlit shapes carries a hair of atlas bleed from the lit tiles: not a light
    from scipy import ndimage
    lab, n = ndimage.label(mx[..., 0] > 0)
    if n:
        areas = ndimage.sum(np.ones_like(lab), lab, index=np.arange(1, n + 1))
        small = np.isin(lab, np.where(areas < 60)[0] + 1)          # specks of bleed (a real light is a lit door or a window pane)
        mx[small] = 0.0
    out = np.zeros_like(a)
    out[..., :3] = np.where(mx > 1e-4, rgb / np.maximum(mx, 1e-4), 0)
    out[..., 3:4] = mx
    return Image.fromarray(np.uint8(np.clip(out * 255 + .5, 0, 255)), 'RGBA')


def render(build, sx: float, sy: float, ss: int = 3, outline: bool = True, want_emit: bool = False, tile: int = 512):
    """build() -> PropSpec.  Returns dict(main=Image, emit=Image|None, pivot=(x, y), emit_offset=(x, y)|None)."""
    spec = build()
    m = spec.m
    scale_model(m, sx, sy)
    pos, nrm, uv, faces, atlas = sr.model_mesh(m, tile)
    scr = project(pos)
    pad = 10
    half_w = int(math.ceil(abs(scr[:, 0]).max() + pad))
    half_h = int(math.ceil(abs(scr[:, 1]).max() + pad))
    W, H = 2 * half_w + 2, 2 * half_h + 2
    kw = {}
    if spec.ambient is not None:
        kw['ambient'] = spec.ambient
    if spec.diffuse is not None:
        kw['diffuse'] = spec.diffuse
    im = sr.StaticRenderer(pos, nrm, uv, faces, atlas, **kw).render(W, H, az=AZ, focus=(0, 0, 0), ss=ss, elev=sr.ELEV)
    if outline:
        im = sr.warm_outline(im)
    bbox = im.getchannel('A').point(lambda v: 255 if v > 3 else 0).getbbox()
    x0, y0, x1, y1 = bbox[0] - 1, bbox[1] - 1, bbox[2] + 1, bbox[3] + 1
    cx, cy = W // 2, H // 2
    out = {'main': im.crop((x0, y0, x1, y1)), 'pivot': (cx - x0, cy - y0), 'emit': None, 'emit_offset': None}
    if want_emit:
        spec_n = build()
        scale_model(spec_n.m, sx, sy)
        if any(getattr(s, 'emit', False) for g in spec_n.m.groups for s in g.shapes):
            pos2, nrm2, uv2, faces2, atlas2 = _flat_mesh(spec_n.m, True, tile)
            rend = sr.StaticRenderer(pos2, nrm2, uv2, faces2, atlas2, ambient=1.0, diffuse=0.0)
            rend.actor.GetProperty().SetSpecular(0)
            em = emissive_to_additive(rend.render(W, H, az=AZ, focus=(0, 0, 0), ss=ss, elev=sr.ELEV)).crop((x0, y0, x1, y1))
            box = em.getchannel('A').getbbox()
            if box is not None:
                out['emit'] = em.crop(box)
                out['emit_offset'] = (box[0], box[1])
    return out


def _size(build, sx, sy, ss):
    r = render(build, sx, sy, ss=ss)
    return r['main'].size


def _jacobian(build, sx, sy, ss):
    """d(w, h) / d(sx, sy) by finite differences (w ~ a sx + const, h ~ b sx + c sy + const)."""
    w0, h0 = _size(build, sx, sy, ss)
    wx, hx = _size(build, sx * 1.15, sy, ss)
    wy, hy = _size(build, sx, sy * 1.15, ss)
    return np.array([[(wx - w0) / (0.15 * sx), (wy - w0) / (0.15 * sy)], [(hx - h0) / (0.15 * sx), (hy - h0) / (0.15 * sy)]], float), (w0, h0)


def fit(build, target, ss_fit: int = 1, tol: int = 1, iters: int = 5):
    """Find (sx, sy) so the cropped sprite is `target` = (w, h) px (+- tol): a damped 2-D Newton with a finite-difference Jacobian (the width is
    nearly sx alone, the height mixes the vertical extent and the ground ellipse).  Returns (sx, sy, jacobian)."""
    tw, th = target
    sx = sy = 1.0
    J = None
    for _ in range(iters):
        J, (w, h) = _jacobian(build, sx, sy, ss_fit)
        if abs(w - tw) <= tol and abs(h - th) <= tol:
            break
        d = np.linalg.solve(J, np.array([tw - w, th - h], float))
        sx = max(0.05, sx + float(d[0]))
        sy = max(0.05, sy + float(d[1]))
    return sx, sy, J


def bake(build, target, ss: int = 3, outline: bool = True, want_emit: bool = False, tol: int = 1):
    sx, sy, J = fit(build, target, tol=tol)
    # supersampled final bake at the fitted scale; Newton steps with the same Jacobian when the supersampled crop differs by more than the tolerance
    for _ in range(4):
        r = render(build, sx, sy, ss=ss, outline=outline, want_emit=want_emit)
        w, h = r['main'].size
        if abs(w - target[0]) <= tol and abs(h - target[1]) <= tol:
            break
        d = np.linalg.solve(J, np.array([target[0] - w, target[1] - h], float))
        sx = max(0.05, sx + float(d[0]))
        sy = max(0.05, sy + float(d[1]))
    r['size'] = r['main'].size
    r['scale'] = (sx, sy)
    return r
