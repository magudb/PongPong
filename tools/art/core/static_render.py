#!/usr/bin/env python3
"""Static (unrigged) renderer: bakes a geometry.Model (props, tiles) with the SAME camera, lights, gamma and outline as the
character baker (bake_sprite_atlases.py), so everything shares one soft rendered look and one pixel-per-metre scale.

Contract (matches the character sheets):
  * orthographic camera, 36 degrees elevation, 87.07 px per metre (parallel scale 1.47 for a 256 px cell)
  * az=45 degrees by default: the ground square of a tile is seen as a diamond 128 x 75.2 px (TILE_M = 1.0394 m edge)
  * lights are defined in camera space (key light from upper left), rotated with the camera azimuth
  * output is straight-alpha RGBA, thin warm outline on request (props yes, ground tiles no)

Lift changes (P08): the generator is found through artpaths (PYTHONPATH wins) instead of PONG_SOURCE/tools/characters;
cells.SetCells (deprecated since VTK 9.6) became cells.ImportLegacyFormat; contract numbers come from artcontract.
Used by the environment/icons bakers of P22/P23 and the feature packages through PYTHONPATH=tools/art/core.
"""
from __future__ import annotations
import math, sys, os
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter, ImageDraw
import vtk
from vtk.util.numpy_support import numpy_to_vtk, numpy_to_vtkIdTypeArray, vtk_to_numpy

import artpaths  # noqa: F401  (adds tools/art/generator and tools/art/core to sys.path)
import artcontract as ac
import geometry as geo
import build_assets as ba

PX_PER_M = ac.PX_PER_M              # 87.074 px per metre, identical to the character baker
ELEV = ac.ELEV_DEG
TILE_W, TILE_H = 128, 76             # engine tile size (diamond); true 36 deg ratio is 128 x 75.2
TILE_M = TILE_W / (math.sqrt(2) * PX_PER_M)   # 1.0394 m tile edge
LIGHTS = [((-3, 6, 6), .74), ((4, 4, 4), .31), ((3, 3, -3), .56)]   # character baker, camera-space (az = 0)


def srgb_to_lin(a):
    a = np.asarray(a, np.float32)
    return np.where(a <= .04045, a / 12.92, ((a + .055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    return np.where(c <= .0031308, c * 12.92, 1.055 * np.power(np.maximum(c, 0), 1 / 2.4) - .055)


def rot_y(p, az):
    c, s = math.cos(math.radians(az)), math.sin(math.radians(az))
    return np.array([p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c])


def premul_resize(im: Image.Image, size, resample=Image.LANCZOS):
    a = np.asarray(im, np.float32) / 255.0
    a[..., :3] *= a[..., 3:4]
    pm = Image.fromarray(np.uint8(np.clip(a * 255 + .5, 0, 255)), 'RGBA')
    chans = [Image.fromarray(np.uint8(np.clip(a[..., k] * 255 + .5, 0, 255))).resize(size, resample) for k in range(4)]
    r = np.stack([np.asarray(c, np.float32) / 255 for c in chans], -1)
    alpha = r[..., 3:4]
    r[..., :3] = np.where(alpha > 1e-4, r[..., :3] / np.maximum(alpha, 1e-4), 0)
    return Image.fromarray(np.uint8(np.clip(r * 255 + .5, 0, 255)), 'RGBA')


# ----------------------------------------------------------------------------------------------------------------------
# mesh extraction from a geometry.Model (static; no skin)
# ----------------------------------------------------------------------------------------------------------------------
def model_mesh(m, tile=512):
    """Return pos, normals, uv, faces, atlas PIL image. Same UV/atlas convention as build_assets.collect(), larger tiles."""
    keys = []
    for g in m.groups:
        for s in g.shapes:
            key = (s.color, ba.pattern_for(m, g, s))
            if key not in keys: keys.append(key)
    grid = 4 if len(keys) <= 16 else (8 if len(keys) <= 64 else 12)
    atlas = Image.new('RGB', (grid * tile, grid * tile), (128, 128, 128))
    for i, (color, pattern) in enumerate(keys):
        t = ba.paint_tile(color, pattern, tile) if pattern in ba.EXTRA_PATTERNS else ba.paint_tile(color, pattern, 256).resize((tile, tile), Image.BICUBIC)
        atlas.paste(t, ((i % grid) * tile, (i // grid) * tile))
    P, N, UV, F = [], [], [], []
    off = 0
    pad = 6 / 256
    for g in m.groups:
        for s in g.shapes:
            v, f = s.vertices, s.faces
            n = geo.smooth_normals(v, f)
            uv = ba.shape_uv(s)
            vp, np_, uvp, ff = list(v), list(n), list(uv), []
            for tri in f:
                tri = tri.copy(); tu = uv[tri, 0]
                if np.ptp(tu) > .65:
                    high = tu > .5
                    for k, vi in enumerate(tri):
                        newuv = uv[vi].copy(); newuv[0] = 1.0 if high.sum() >= 2 else 0.0
                        if (high.sum() >= 2 and not high[k]) or (high.sum() < 2 and high[k]):
                            tri[k] = len(vp); vp.append(v[vi]); np_.append(n[vi]); uvp.append(newuv)
                ff.append(tri)
            uvp = np.array(uvp)
            tidx = keys.index((s.color, ba.pattern_for(m, g, s)))
            tx, ty = tidx % grid, tidx // grid
            uvp[:, 0] = (tx + pad + uvp[:, 0] * (1 - 2 * pad)) / grid
            uvp[:, 1] = (ty + pad + uvp[:, 1] * (1 - 2 * pad)) / grid
            P.append(np.array(vp)); N.append(np.array(np_)); UV.append(uvp); F.append(np.array(ff) + off)
            off += len(vp)
    return np.concatenate(P), np.concatenate(N), np.concatenate(UV), np.concatenate(F), atlas


class StaticRenderer:
    def __init__(self, pos, normals, uv, faces, image: Image.Image, repeat=False, ambient=.44, diffuse=.59):
        poly = vtk.vtkPolyData(); self.poly = poly
        pts = vtk.vtkPoints(); pts.SetData(numpy_to_vtk(pos.astype('float32'), deep=True)); poly.SetPoints(pts)
        cells = vtk.vtkCellArray(); packed = np.column_stack([np.full(len(faces), 3), faces]).astype('int64')
        cells.ImportLegacyFormat(numpy_to_vtkIdTypeArray(packed.ravel(), deep=True)); poly.SetPolys(cells)
        nn = numpy_to_vtk(normals.astype('float32'), deep=True); nn.SetName('Normals'); poly.GetPointData().SetNormals(nn)
        uvv = uv.astype('float32').copy(); uvv[:, 1] = 1 - uvv[:, 1]
        tv = numpy_to_vtk(uvv, deep=True); tv.SetName('UV'); poly.GetPointData().SetTCoords(tv)
        img = np.asarray(image.convert('RGB'), np.float32) / 255.0
        lin = srgb_to_lin(img)
        data = vtk.vtkImageData(); h, w = img.shape[:2]; data.SetDimensions(w, h, 1)
        arr = numpy_to_vtk(np.uint8(np.clip(lin[::-1] * 255 + .5, 0, 255)).reshape(-1, 3).copy(), deep=True)
        arr.SetNumberOfComponents(3); data.GetPointData().SetScalars(arr)
        tex = vtk.vtkTexture(); tex.SetInputData(data); tex.InterpolateOn(); tex.MipmapOn()
        (tex.RepeatOn if repeat else tex.RepeatOff)()
        mapper = vtk.vtkPolyDataMapper(); mapper.SetInputData(poly)
        actor = vtk.vtkActor(); actor.SetMapper(mapper); actor.SetTexture(tex)
        p = actor.GetProperty(); p.SetAmbient(ambient); p.SetDiffuse(diffuse); p.SetSpecular(.03); p.SetSpecularPower(24); p.SetInterpolationToPhong()
        self.actor = actor; self.tex = tex
        self.ren = vtk.vtkRenderer(); self.ren.AddActor(actor)
        self.ren.SetBackground(0, 0, 0); self.ren.SetBackgroundAlpha(0); self.ren.AutomaticLightCreationOff()

    def render(self, w, h, az=45.0, focus=(0, 0, 0), cell_h_px=None, ss=3, lights=LIGHTS, extra_lights=None, ppm=None, elev=None):
        """Render a w x h px final image (supersampled by ss). focus is the world point mapped to the image centre."""
        win = vtk.vtkRenderWindow(); win.SetOffScreenRendering(True); win.SetSize(w * ss, h * ss); win.AddRenderer(self.ren)
        win.SetAlphaBitPlanes(1); win.SetMultiSamples(0); win.SetUseSRGBColorSpace(False)
        for old in list(self.ren.GetLights()): self.ren.RemoveLight(old)
        for loc, inten in lights:
            L = vtk.vtkLight(); L.SetLightTypeToSceneLight(); L.SetPosition(*(np.array(focus) + rot_y(loc, az)))
            L.SetFocalPoint(*focus); L.SetIntensity(inten); self.ren.AddLight(L)
        cam = self.ren.GetActiveCamera(); a = math.radians(az); e = math.radians(ELEV if elev is None else elev); R = 40
        cam.ParallelProjectionOn(); cam.SetViewUp(0, 1, 0)
        cam.SetFocalPoint(*focus)
        cam.SetPosition(focus[0] + R * math.sin(a) * math.cos(e), focus[1] + R * math.sin(e), focus[2] + R * math.cos(a) * math.cos(e))
        cam.SetParallelScale(h / 2 / (ppm or PX_PER_M))
        self.ren.ResetCameraClippingRange(); cam.SetClippingRange(1, 90)
        win.Render()
        f = vtk.vtkWindowToImageFilter(); f.SetInput(win); f.SetInputBufferTypeToRGBA(); f.ReadFrontBufferOff(); f.Update()
        rgba = vtk_to_numpy(f.GetOutput().GetPointData().GetScalars()).reshape((h * ss, w * ss, 4))[::-1].copy()
        win.Finalize()
        col = rgba[..., :3].astype(np.float32) / 255
        rgba[..., :3] = np.uint8(np.clip(lin_to_srgb(col) * 255 + .5, 0, 255))
        im = Image.fromarray(rgba, 'RGBA')
        return premul_resize(im, (w, h)) if ss > 1 else im


def warm_outline(im: Image.Image, radius=2, color=(75, 60, 73), alpha=.55) -> Image.Image:
    """Same outline recipe as the character baker (MaxFilter 5 on alpha, warm grey-violet, 55 %)."""
    mask = im.getchannel('A')
    k = radius * 2 + 1
    thick = mask.filter(ImageFilter.MaxFilter(k))
    out = Image.new('RGBA', im.size, color + (0,))
    out.putalpha(thick.point(lambda p: int(p * alpha)))
    out.alpha_composite(im)
    return out


def soft_shadow(size, center, rx, ry, strength=.30, blur=6, offset=(0, 0), color=(43, 35, 64)):
    sh = Image.new('L', size, 0)
    d = ImageDraw.Draw(sh)
    cx, cy = center[0] + offset[0], center[1] + offset[1]
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=int(255 * strength))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new('RGBA', size, color + (0,)); out.putalpha(sh)
    return out


def glow_halo(color_hex, radius, strength=1.0, size=None):
    size = size or int(radius * 4)
    c = tuple(int(color_hex[i:i + 2], 16) for i in (0, 2, 4))
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    d = np.hypot(x - size / 2, y - size / 2) / radius
    a = np.clip(np.exp(-d * d * 1.6) * strength, 0, 1)
    img = np.zeros((size, size, 4), np.uint8); img[..., :3] = c; img[..., 3] = np.uint8(a * 255)
    return Image.fromarray(img, 'RGBA')
