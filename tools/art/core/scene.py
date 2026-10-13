#!/usr/bin/env python3
"""Pillow stand-in for the Godot iso renderer (QA + key art): tile atlas lookup, y-sorted props and characters, final zoom.

Engine contract this mirrors (all sizes are baked px):
  cell (cx,cy) -> screen  sx = (cx-cy)*64,  sy = (cx+cy)*37.6        (engine TileSet tile_size 128x76)
  tile sprite: atlas[(cx%P, cy%P)] (CELL 144x84) drawn centred on the cell centre
  prop sprite: pivot px at the cell centre (+ optional sub-cell offset in tiles)
  character sprite (256 cell, pivot 128,200): frame rect (frame*256, dir_row*256) drawn so pivot sits on the cell centre
  camera zoom 0.6 on a 1920x1080 canvas => compose at 3200x1800 and downscale (what Godot's mipmapped linear filter does)

Lifted unchanged from the art spike (P08 core).  NOTE: the engine tile is 128x76 (Iso.TILE_H = 76, plan D3); HW/HH below
are the baked diamond 64 x 37.6 used by the spike's compositor, a QA/key-art stand-in, never the runtime tile size.
Characters are drawn with scale=1.0: sprites are never scaled individually (plan D4); a scale argument exists only to
compose zoomed key art.
"""
from __future__ import annotations
import json, math
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter
import numpy as np

HW, HH = 64.0, 37.6
DIRS = ['S', 'SW', 'W', 'NW', 'N', 'NE', 'E', 'SE']


def cell_to_screen(cx, cy):
    return ((cx - cy) * HW, (cx + cy) * HH)


class Assets:
    def __init__(self, tiles=None, props=None, chars=None, shadow=None):
        self.tile_root = Path(tiles) if tiles else None
        self.prop_root = Path(props) if props else None
        self.char_roots = [Path(c) for c in (chars if isinstance(chars, (list, tuple)) else [chars])] if chars else []
        self.cache = {}
        self.tmeta = json.loads((self.tile_root / 'tiles.json').read_text()) if self.tile_root else {}
        self.pmeta = json.loads((self.prop_root / 'props.json').read_text()) if self.prop_root else {}
        self.shadow = Image.open(shadow).convert('RGBA') if shadow else None

    def img(self, path):
        if path not in self.cache: self.cache[path] = Image.open(path).convert('RGBA')
        return self.cache[path]

    def tile(self, terrain, cx, cy):
        m = self.tmeta[terrain]; P = m['variants'][0]; cw, ch = m['cell']
        a = self.img(self.tile_root / m['file']); i, j = cx % P, cy % P
        return a.crop((i * cw, j * ch, (i + 1) * cw, (j + 1) * ch))

    def prop(self, name):
        m = self.pmeta[name]
        return self.img(self.prop_root / m['file']), m

    def char_frame(self, cid, clip, frame, direction):
        for root in self.char_roots:
            d = root / cid
            if not d.exists(): continue
            anim = json.loads((d / 'animations.json').read_text())['animations']
            sheet = anim[clip]['sheet']
            base = d / sheet
            if not base.exists(): base = d / (clip + '.png')
            if not base.exists(): base = d / (clip + '.webp')
            sh = self.img(base)
            n = anim[clip]['frames']; f = frame % n
            return sh.crop((f * 256, direction * 256, f * 256 + 256, direction * 256 + 256))
        raise FileNotFoundError(cid)


class IsoScene:
    def __init__(self, assets: Assets, width, height, origin=(0, 0), bg=(0, 0, 0, 0)):
        self.a = assets; self.W, self.H = width, height; self.origin = origin
        self.ground = []; self.sprites = []; self.overlays = []
        self.bg = bg; self.grade = None; self.emissive = set()

    def _scr(self, cx, cy):
        x, y = cell_to_screen(cx, cy)
        return x + self.origin[0], y + self.origin[1]

    def tile(self, terrain, cx, cy):
        self.ground.append((cx + cy, terrain, cx, cy))

    def prop(self, name, cx, cy, ox=0.0, oy=0.0, flip=False, xy=None):
        im, m = self.a.prop(name)
        x, y = xy if xy else self._scr(cx + ox, cy + oy)
        self.sprites.append((y + 0.001, 'prop', im, m, x, y, flip, name))

    def char(self, cid, cx, cy, clip='idle', frame=0, direction=0, scale=1.0, ox=0.0, oy=0.0, shadow=True, tint=None, xy=None):
        fr = self.a.char_frame(cid, clip, frame, direction)
        x, y = xy if xy else self._scr(cx + ox, cy + oy)
        self.sprites.append((y, 'char', fr, scale, x, y, shadow, tint, cid))

    def overlay(self, im, x, y, additive=False, alpha=1.0):
        self.overlays.append((im, x, y, additive, alpha))

    def render(self, final_size=None, zoom=1.0):
        canvas = Image.new('RGBA', (self.W, self.H), self.bg)
        for _, terrain, cx, cy in sorted(self.ground):
            x, y = self._scr(cx, cy)
            t = self.a.tile(terrain, cx, cy)
            if self.grade: t = _tint(t, self.grade)
            canvas.alpha_composite(t, (int(round(x - t.width / 2)), int(round(y - t.height / 2))))
        glows = []
        for s in sorted(self.sprites, key=lambda s: s[0]):
            if s[1] == 'prop':
                _, _, im, m, x, y, flip, name = s
                if flip: im = im.transpose(Image.FLIP_LEFT_RIGHT)
                if self.grade and name not in self.emissive: im = _tint(im, self.grade)
                px = m['pivot'][0] if not flip else im.width - m['pivot'][0]
                px0, py0 = int(round(x - px)), int(round(y - m['pivot'][1]))
                canvas.alpha_composite(im, (px0, py0)) if px0 >= 0 and py0 >= 0 and px0 + im.width <= self.W and py0 + im.height <= self.H else _paste(canvas, im, px0, py0)
                if 'glow' in m: glows.append((self.a.img(self.a.prop_root / m['glow']['file']), x - m['pivot'][0] + m['glow']['center'][0], y - m['pivot'][1] + m['glow']['center'][1]))
            else:
                _, _, fr, scale, x, y, shadow, tint, cid = s
                if shadow and self.a.shadow is not None:
                    sh = self.a.shadow
                    w, h = int(sh.width * scale), int(sh.height * scale)
                    _paste(canvas, sh.resize((w, h), Image.LANCZOS), int(x - w / 2), int(y - h / 2))
                if scale != 1.0:
                    fr = fr.resize((int(256 * scale), int(256 * scale)), Image.LANCZOS)
                if tint:
                    fr = _tint(fr, tint)
                elif self.grade and cid not in self.emissive:
                    fr = _tint(fr, self.grade)
                _paste(canvas, fr, int(round(x - 128 * scale)), int(round(y - 200 * scale)))
        for g, gx, gy in glows:
            _additive(canvas, g, int(gx - g.width / 2), int(gy - g.height / 2), .75)
        for im, x, y, add, al in self.overlays:
            (_additive if add else _alpha)(canvas, im, int(x), int(y), al)
        if final_size:
            canvas = canvas.resize(final_size, Image.LANCZOS)
        return canvas


def _paste(canvas, im, x, y):
    layer = Image.new('RGBA', canvas.size, (0, 0, 0, 0)); layer.paste(im, (x, y))
    canvas.alpha_composite(layer)


def _alpha(canvas, im, x, y, a=1.0):
    if a < 1.0:
        im = im.copy(); im.putalpha(im.getchannel('A').point(lambda v: int(v * a)))
    _paste(canvas, im, x, y)


def _additive(canvas, im, x, y, strength=1.0):
    layer = Image.new('RGBA', canvas.size, (0, 0, 0, 0)); layer.paste(im, (x, y))
    arr = np.asarray(layer, np.float32) / 255.0; base = np.asarray(canvas, np.float32) / 255.0
    add = arr[..., :3] * arr[..., 3:4] * strength
    base[..., :3] = np.clip(base[..., :3] + add, 0, 1)
    canvas.paste(Image.fromarray(np.uint8(base * 255 + .5), 'RGBA'))


def _tint(im, rgb):
    a = np.asarray(im, np.float32); a[..., :3] *= np.array(rgb, np.float32)[None, None, :]
    return Image.fromarray(np.uint8(np.clip(a, 0, 255)), 'RGBA')
