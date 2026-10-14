"""props_images.py - the props that are PAINTED (Pillow / numpy), not 3D bakes: the additive decals and fx of Moerkeskoven and the experience layer, the
seamless ground textures of V8's SoftGround, the soft atmosphere layers.  Registered into bake_props.IMAGE_PROPS; the manifest entry says what they are:

  blend "add"        an additive soft sprite (CanvasItemMaterial BLEND_MODE_ADD) - every colour above the ambient ceiling (R > 77, G > 94, B > 133 under the forest grade
                     4d5e85) lives in an additive layer, never baked bright (DUNGEON addendum 7.5)
  frames / fps       a horizontal strip of N frames of frame_size px (pond_ripple, eyes_glow); the pivot is that of frame 0
  seamless true      a 256 px texture that repeats in both directions (path_tile_o, pond_water_o, floor_patch_*): SoftGround maps it over a mask; never placed as a sprite
  alpha_hint         the opacity the consumer is meant to draw the sprite with (mist_patch: 0.06 of a full-strength mask)
All ground decals use the project camera: a ground circle is an ellipse squashed to sin(36 degrees) = .588.
"""
from __future__ import annotations
import math
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import props_traetoppen as pp
import bake_tiles as bt
from props_forest import albedo_hex, hexrgb, GLYPH, SLAB

SQ = math.sin(math.radians(36.0))


@dataclass
class ImageProp:
    image: Image.Image
    pivot: tuple
    footprint: tuple = (1, 1)
    extra: dict = field(default_factory=dict)


def _rgba(arr):
    return Image.fromarray(np.uint8(np.clip(arr * 255 + .5, 0, 255)), 'RGBA')


def _radial(size, profile, color, center=None):
    """RGBA: colour `color` (hex), alpha = profile(r) with r the normalised radius (1 at the edge of the half extents)."""
    w, h = size
    cx, cy = (w / 2, h / 2) if center is None else center
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.hypot((x + .5 - cx) / (w / 2), (y + .5 - cy) / (h / 2))
    a = np.clip(profile(r), 0, 1)
    out = np.zeros((h, w, 4), np.float32); out[..., :3] = hexrgb(color) / 255.0; out[..., 3] = a
    return _rgba(out)


def _ss_draw(size, painter, ss=3, blur=0.0):
    """Draw with `painter(ImageDraw, ss)` on a supersampled RGBA canvas (coordinates x ss) and downsample: antialiased shapes."""
    w, h = size
    big = Image.new('RGBA', (w * ss, h * ss), (0, 0, 0, 0))
    painter(ImageDraw.Draw(big, 'RGBA'), ss)
    out = big.resize((w, h), Image.LANCZOS)
    return out.filter(ImageFilter.GaussianBlur(blur)) if blur else out


# ------------------------------------------------------------------------------------------------ eyes, ripples, sheens
def eyes_glow():
    """The additive eyes of a bush in ambush (f25a6a is allowed for the eyes ONLY): two vertical ovals, a 2-frame pulse (frame 1 brighter, with a bigger halo)."""
    fw, fh = 128, 64
    frames = []
    for core_a, halo_a, halo_r in ((.78, .22, 26), (1.0, .42, 34)):
        im = Image.new('RGBA', (fw, fh), (0, 0, 0, 0))
        for sx in (-1, 1):
            cx = fw / 2 + sx * 26
            halo = _radial((halo_r * 2, halo_r * 2), lambda r, a=halo_a: a * np.clip(1 - r, 0, 1) ** 1.6, 'F25A6A')
            im.alpha_composite(halo, (int(cx - halo_r), int(fh / 2 - halo_r)))

            def paint(d, ss, cx=cx, ca=core_a):
                d.ellipse(((cx - 8) * ss, (fh / 2 - 12) * ss, (cx + 8) * ss, (fh / 2 + 12) * ss), fill=(242, 90, 106, int(255 * ca)))
                d.ellipse(((cx - 4) * ss, (fh / 2 - 7) * ss, (cx + 4) * ss, (fh / 2 + 7) * ss), fill=(255, 214, 220, int(255 * ca)))
            im.alpha_composite(_ss_draw((fw, fh), paint))
        frames.append(im)
    strip = Image.new('RGBA', (fw * 2, fh), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        strip.paste(f, (k * fw, 0))
    return ImageProp(strip, (fw // 2, fh // 2), extra={'blend': 'add', 'kind': 'fx', 'frames': 2, 'frame_size': [fw, fh], 'fps': 3, 'colour': 'f25a6a', 'proj': 'iso'})


def hulen_eyes():
    """Two yellow eyes in the dark mouth of the Hulen (additive, f2c14e)."""
    w, h = 96, 48
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for sx in (-1, 1):
        cx = w / 2 + sx * 17
        im.alpha_composite(_radial((44, 44), lambda r: .35 * np.clip(1 - r, 0, 1) ** 1.6, 'F2C14E'), (int(cx - 22), h // 2 - 22))

        def paint(d, ss, cx=cx):
            d.ellipse(((cx - 5) * ss, (h / 2 - 8) * ss, (cx + 5) * ss, (h / 2 + 8) * ss), fill=(242, 193, 78, 255))
            d.ellipse(((cx - 2.5) * ss, (h / 2 - 4) * ss, (cx + 2.5) * ss, (h / 2 + 4) * ss), fill=(255, 244, 200, 255))
        im.alpha_composite(_ss_draw((w, h), paint))
    return ImageProp(im, (w // 2, h // 2), extra={'blend': 'add', 'kind': 'fx', 'colour': 'f2c14e', 'proj': 'iso'})


def pond_ripple():
    """A ripple on the Moon pond: four frames of a ring that grows and fades (a ground circle: squashed .588).  Additive, soft mint."""
    fw, fh = 144, 90
    strip = Image.new('RGBA', (fw * 4, fh), (0, 0, 0, 0))
    for k in range(4):
        t = (k + .5) / 4
        rx = 18 + t * 52; a = (1 - t) ** 1.2 * .9
        strip.paste(_ss_draw((fw, fh), lambda d, ss, rx=rx, a=a: d.ellipse(((fw / 2 - rx) * ss, (fh / 2 - rx * SQ) * ss, (fw / 2 + rx) * ss, (fh / 2 + rx * SQ) * ss),
                                                                       outline=(190, 245, 232, int(255 * a)), width=3 * ss), blur=.6), (k * fw, 0))
    return ImageProp(strip, (fw // 2, fh // 2), extra={'blend': 'add', 'kind': 'fx', 'frames': 4, 'frame_size': [fw, fh], 'fps': 4, 'colour': 'bef5e8', 'proj': 'iso'})


def pond_sheen():
    """The mint sheen of the pond (sketch: r44 sketch px = 132 px): a soft additive ellipse."""
    w = 280; h = int(w * SQ)
    return ImageProp(_radial((w, h), lambda r: .55 * np.clip(1 - r, 0, 1) ** 1.8, '6FD6C4'), (w // 2, h // 2),
                     extra={'blend': 'add', 'kind': 'decal', 'colour': '6fd6c4', 'proj': 'iso'})


def rune_glow():
    """The glyph of the runestone (6fd6c4) as an additive layer with the SAME size and pivot as runestone_active: strokes + a soft halo.  Dormant: modulate it dim."""
    import bake_props as bp
    with tempfile.TemporaryDirectory() as td:
        meta, _ = bp.bake_prop('runestone_active', pp.PROPS['runestone_active'](), Path(td), ss=3)
    W, H = meta['size']; px, py = meta['pivot']
    w, h, d = SLAB
    pts = []
    for (x0, y0), (x1, y1) in GLYPH:
        seg = []
        for t in np.linspace(0, 1, 12):
            x = (x0 + (x1 - x0) * t) * w * .5 * .9; y = h * .54 + (y0 + (y1 - y0) * t) * h * .3; z = d * .5 + .035
            a = math.radians(-8)
            # Rotation.from_euler('xyz', (0, -8, 0)) turns about +y: x' = x cos + z sin, z' = -x sin + z cos
            xr = x * math.cos(a) + z * math.sin(a); zr = -x * math.sin(a) + z * math.cos(a)
            sx, sy = bp.project(np.array([[xr, y, zr]]))[0]
            seg.append((px + sx, py + sy))
        pts.append(seg)
    big = 3
    halo = Image.new('RGBA', (W * big, H * big), (0, 0, 0, 0)); core = Image.new('RGBA', (W * big, H * big), (0, 0, 0, 0))
    dh, dc = ImageDraw.Draw(halo), ImageDraw.Draw(core)
    for seg in pts:
        xy = [(x * big, y * big) for x, y in seg]
        dh.line(xy, fill=(111, 214, 196, 255), width=8 * big, joint='curve')
        dc.line(xy, fill=(180, 245, 232, 255), width=4 * big, joint='curve')
    halo = halo.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(7))
    core = core.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(.7))
    ha = np.asarray(halo, np.float32) / 255.0; ha[..., 3] *= .8
    out = Image.alpha_composite(_rgba(ha), core)
    soft = _radial((W, H), lambda r: .22 * np.clip(1 - r, 0, 1) ** 2, '6FD6C4', center=(px + 2, py - 100))     # a soft halo behind the stone's upper half
    out = Image.alpha_composite(soft, out)
    return ImageProp(out, (px, py), extra={'blend': 'add', 'kind': 'fx', 'colour': '6fd6c4', 'glyph': True, 'proj': 'iso'})


def firefly_dot():
    w = 24
    halo = _radial((w, w), lambda r: .25 * np.clip(1 - r, 0, 1) ** 1.2, 'F2E9A0')
    core = _radial((w, w), lambda r: np.clip(1 - r * 3.6, 0, 1) ** .6, 'F2E9A0')
    return ImageProp(Image.alpha_composite(halo, core), (w // 2, w // 2), extra={'blend': 'add', 'kind': 'fx', 'colour': 'f2e9a0', 'proj': 'iso'})


def lantern_light():
    """The lantern's light texture (512 px): 1.0 at the centre, 0.31 at 60 % of the radius, 0 at 100 % (the sketch's radial stops .32 / .10 / 0).  Opaque grey
    (the light's colour comes from the PointLight2D): brightness = the profile."""
    n = 512
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(x + .5 - n / 2, y + .5 - n / 2) / (n / 2)
    v = np.where(r >= 1, 0, np.interp(r, [0, .6, 1.0], [1.0, .31, 0.0]))
    out = np.zeros((n, n, 4), np.float32); out[..., 0] = out[..., 1] = out[..., 2] = v; out[..., 3] = 1.0
    return ImageProp(_rgba(out), (n // 2, n // 2), extra={'kind': 'light', 'texture': True, 'profile': [[0, 1.0], [.6, .31], [1.0, 0.0]], 'radius_px': n // 2, 'proj': 'iso'})


# ------------------------------------------------------------------------------------------------ seamless ground textures (256 px, repeat)
def _canvas256(base_hex, seed):
    return bt.Canvas(hexrgb(base_hex), seed, P=1)


def _finish(cv, extra):
    d = {'kind': 'texture', 'seamless': True, 'texture': True, 'repeat': True, 'proj': 'iso', 'size_px': 256}
    d.update(extra)
    return ImageProp(cv.image().convert('RGBA'), (128, 128), extra=d)


def path_tile_o():
    """The lit path (sketch #3b3c5e, baked c3a3b4): a soft mottle with pebbles and moss specks; V8 maps it over the smooth S-curve mask."""
    cv = _canvas256(albedo_hex('3b3c5e'), 31)
    cv.tint(.05, 3).tint(.035, 9).shade_hue(albedo_hex('45466a'), 4, .5).shade_hue(albedo_hex('33344f'), 5, .35)
    cv.paint(lambda d, r, n: bt.dots(d, r, n, 140, [albedo_hex(c) for c in ('45466a', '2e2f49', '4c4d72', '3a3b5b')], (1.5, 4), (110, 200)))
    cv.paint(lambda d, r, n: bt.blades(d, r, n, 120, [albedo_hex(c) for c in ('2d4a4a', '35544f', '264240')], (4, 8), 2, (60, 120)))
    return _finish(cv, {'palette': 'path', 'sketch': '3b3c5e', 'baked': albedo_hex('3b3c5e')})


def pond_water_o():
    """The Moon pond (sketch #1c4a5a, inner #235a6a, baked 5dc9ad): soft depth variation with faint ripple arcs."""
    cv = _canvas256(albedo_hex('1c4a5a'), 32)
    cv.tint(.04, 3).shade_hue(albedo_hex('235a6a'), 3, .6).shade_hue(albedo_hex('163c4a'), 4, .35)

    def ripples(d, r, n):
        c = tuple(int(v) for v in hexrgb(albedo_hex('2e7080')))
        for i in range(22):
            x, y = r.uniform(0, n), r.uniform(0, n); w = r.uniform(18, 46)
            bt.wrap_draw(n, lambda dx, dy: d.arc((x + dx - w, y + dy - w * .3, x + dx + w, y + dy + w * .3), 195, 345, fill=c + (120,), width=2))
    cv.paint(ripples)
    return _finish(cv, {'palette': 'water', 'sketch': '1c4a5a', 'baked': albedo_hex('1c4a5a')})


def floor_patch(variant='a'):
    """The lighter ground blobs of the sketch (#2a3352 over #232a45): a / b neutral lavender, c a teal-leaning glow patch.  Same stroke language as the floor tile."""
    seed = {'a': 41, 'b': 42, 'c': 43}[variant]
    base = {'a': '2a3352', 'b': '2c3354', 'c': '28405a'}[variant]
    cv = _canvas256(albedo_hex(base), seed)
    cv.tint(.06, 3).tint(.04, 10).shade_hue(albedo_hex('323b5e' if variant != 'c' else '2f5668'), 4, .55).shade_hue(albedo_hex('202845'), 5, .35)
    cv.paint(lambda d, r, n: bt.blades(d, r, n, 220, [albedo_hex(c) for c in ('1a2038', '3a4572', '262d4e')], (5, 11), 2, (60, 120)))
    if variant == 'c':
        cv.paint(lambda d, r, n: bt.dots(d, r, n, 50, [albedo_hex(c) for c in ('4a6a86', '3f7080', '5a6f9a')], (1.5, 3.2), (150, 240)))
    return _finish(cv, {'palette': 'floor_patch', 'sketch': base, 'baked': albedo_hex(base)})


# ------------------------------------------------------------------------------------------------ mist and the experience layer
def mist_patch(w, h, seed):
    """A drifting mist ellipse (#cfd6f2): a soft full-strength mask; the consumer draws it with alpha_hint (6 %)."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.hypot((x + .5 - w / 2) / (w / 2), (y + .5 - h / 2) / (h / 2))
    base = np.clip(1 - r, 0, 1) ** .7
    low = bt.pnoise(max(h, w), 6, rng)[:h, :w]
    a = np.clip(base * (.78 + .5 * low), 0, 1)
    out = np.zeros((h, w, 4), np.float32); out[..., :3] = hexrgb('E8ECFF') / 255.0; out[..., 3] = a
    return ImageProp(_rgba(out), (w // 2, h // 2), extra={'kind': 'decal', 'alpha_hint': 0.06, 'colour': 'cfd6f2', 'proj': 'iso'})


def _ring(rg, color, stroke, fill_a=.1, glow=14):
    """An additive ground ring decal of ground radius `rg` px: a squashed ellipse stroke + a faint inner fill + a soft outer glow.  Pivot = centre."""
    m = glow + stroke + 4
    w = int(2 * (rg + m)); h = int(2 * (rg * SQ + m * SQ) + 8)
    col = tuple(int(v) for v in hexrgb(color))
    rx, ry = rg, rg * SQ

    def paint(d, ss):
        cx, cy = w * ss / 2, h * ss / 2
        d.ellipse((cx - rx * ss, cy - ry * ss, cx + rx * ss, cy + ry * ss), fill=col + (int(255 * fill_a),))
        d.ellipse((cx - rx * ss, cy - ry * ss, cx + rx * ss, cy + ry * ss), outline=col + (255,), width=int(stroke * ss))

    def paint_halo(d, ss):
        cx, cy = w * ss / 2, h * ss / 2
        d.ellipse((cx - rx * ss, cy - ry * ss, cx + rx * ss, cy + ry * ss), outline=col + (150,), width=int(stroke * 2.2 * ss))
    im = _ss_draw((w, h), paint)
    halo = _ss_draw((w, h), paint_halo, blur=glow / 2)
    return ImageProp(Image.alpha_composite(halo, im), (w // 2, h // 2), extra={'blend': 'add', 'kind': 'decal', 'colour': color.lower(), 'radius_ground_px': rg, 'proj': 'iso'})


def telegraph_ring(rg):
    return _ring(rg, 'FBF5E6', 8, .10, 14)


def telegraph_line():
    """A line telegraph: a strip 96 px wide and 512 px long starting at the pivot (left centre) and pointing along +x; the consumer rotates it."""
    w, h = 512, 96
    col = (251, 245, 230)

    def paint(d, ss):
        d.rectangle((0, (h / 2 - 40) * ss, w * ss, (h / 2 + 40) * ss), fill=col + (28,))
        d.line((0, (h / 2 - 40) * ss, w * ss, (h / 2 - 40) * ss), fill=col + (255,), width=6 * ss)
        d.line((0, (h / 2 + 40) * ss, w * ss, (h / 2 + 40) * ss), fill=col + (255,), width=6 * ss)
        for k in range(5):                                                                              # chevrons pointing the way
            x = 70 + k * 100
            d.line([(x * ss, (h / 2 - 24) * ss), ((x + 24) * ss, h / 2 * ss), (x * ss, (h / 2 + 24) * ss)], fill=col + (150,), width=5 * ss)
    im = _ss_draw((w, h), paint)
    return ImageProp(Image.alpha_composite(_ss_draw((w, h), paint, blur=5), im), (0, h // 2), extra={'blend': 'add', 'kind': 'decal', 'colour': 'fbf5e6', 'direction': 'x', 'proj': 'iso'})


def boss_arena_ring():
    """The cream ring the boss sleeps inside: it wakes at 520 ground px; a thin ring with a very faint fill, additive."""
    return _ring(520, 'FBF5E6', 10, .03, 20)


def halo(color, r=128):
    w = r * 2
    return ImageProp(_radial((w, w), lambda q: .85 * np.clip(1 - q, 0, 1) ** 1.7, color), (r, r), extra={'blend': 'add', 'kind': 'fx', 'colour': color.lower(), 'proj': 'iso'})


def halo_violet():
    """Svampekongen: a violet halo with a gold inner ring."""
    r = 128; w = r * 2
    base = _radial((w, w), lambda q: .8 * np.clip(1 - q, 0, 1) ** 1.7, '7B6BB8')
    ring = _ss_draw((w, w), lambda d, ss: d.ellipse(((r - 74) * ss, (r - 74) * ss, (r + 74) * ss, (r + 74) * ss), outline=(232, 176, 74, 190), width=5 * ss), blur=2.5)
    return ImageProp(Image.alpha_composite(base, ring), (r, r), extra={'blend': 'add', 'kind': 'fx', 'colour': '7b6bb8', 'proj': 'iso'})


def _spark(d, cx, cy, ln, wd, col, ss, a=255):
    for ang in (0, 90):
        rr = math.radians(ang)
        dx, dy = math.cos(rr) * ln, math.sin(rr) * ln
        d.polygon([((cx + dx) * ss, (cy + dy) * ss), ((cx + dy * wd / ln) * ss, (cy - dx * wd / ln) * ss), ((cx - dx) * ss, (cy - dy) * ss), ((cx - dy * wd / ln) * ss, (cy + dx * wd / ln) * ss)], fill=col + (a,))


def crown_spark():
    """A little crown of sparkles floating over the Svampekonge (additive gold)."""
    w, h = 112, 80

    def paint(d, ss):
        for dx, dy, ln in ((-30, 28, 14), (0, 18, 22), (30, 28, 14)):
            _spark(d, w / 2 + dx, h / 2 + dy - 8, ln, 5, (242, 193, 78), ss)
        d.line([((w / 2 - 36) * ss, (h / 2 + 30) * ss), ((w / 2 + 36) * ss, (h / 2 + 30) * ss)], fill=(242, 193, 78, 200), width=4 * ss)
    im = _ss_draw((w, h), paint)
    return ImageProp(Image.alpha_composite(_ss_draw((w, h), paint, blur=4), im), (w // 2, h // 2), extra={'blend': 'add', 'kind': 'fx', 'colour': 'f2c14e', 'proj': 'iso'})


def fx_hit_spark():
    """The hit spark (DR0): a white-cream star of eight rays with a hot core; tinted by the weapon's rarity by the consumer."""
    n = 96

    def paint(d, ss):
        c = n * ss / 2
        for k in range(8):
            a = math.radians(k * 45 + 8)
            ln = (40 if k % 2 == 0 else 26) * ss
            d.polygon([(c + math.cos(a) * ln, c + math.sin(a) * ln), (c + math.cos(a + 1.5708) * 4 * ss, c + math.sin(a + 1.5708) * 4 * ss),
                       (c + math.cos(a + 3.1416) * 6 * ss, c + math.sin(a + 3.1416) * 6 * ss), (c + math.cos(a - 1.5708) * 4 * ss, c + math.sin(a - 1.5708) * 4 * ss)], fill=(255, 246, 226, 255))
        d.ellipse((c - 9 * ss, c - 9 * ss, c + 9 * ss, c + 9 * ss), fill=(255, 255, 255, 255))
    im = _ss_draw((n, n), paint)
    glow = _radial((n, n), lambda q: .5 * np.clip(1 - q, 0, 1) ** 1.5, 'FFE9B0')
    return ImageProp(Image.alpha_composite(glow, im), (n // 2, n // 2), extra={'blend': 'add', 'kind': 'fx', 'colour': 'fff6e2', 'proj': 'iso'})


def fx_heal_sparkle():
    """The heal sparkle: three four-point sparkles (pale mint, not red) rising together."""
    n = 96

    def paint(d, ss):
        for dx, dy, ln in ((0, 4, 26), (-24, 22, 14), (24, 26, 12)):
            _spark(d, n / 2 + dx, n / 2 + dy - 10, ln, 6, (190, 245, 228), ss)
            d.ellipse(((n / 2 + dx - 3) * ss, (n / 2 + dy - 13) * ss, (n / 2 + dx + 3) * ss, (n / 2 + dy - 7) * ss), fill=(255, 255, 255, 255))
    im = _ss_draw((n, n), paint)
    return ImageProp(Image.alpha_composite(_ss_draw((n, n), paint, blur=4), im), (n // 2, n // 2), extra={'blend': 'add', 'kind': 'fx', 'colour': 'bef5e4', 'proj': 'iso'})


IMAGE_PROPS = {
    'eyes_glow': eyes_glow, 'hulen_eyes': hulen_eyes, 'pond_ripple': pond_ripple, 'pond_sheen': pond_sheen, 'rune_glow': rune_glow,
    'firefly_dot': firefly_dot, 'lantern_light': lantern_light,
    'path_tile_o': path_tile_o, 'pond_water_o': pond_water_o,
    'floor_patch_a': lambda: floor_patch('a'), 'floor_patch_b': lambda: floor_patch('b'), 'floor_patch_c': lambda: floor_patch('c'),
    'mist_patch_a': lambda: mist_patch(1560, 300, 1), 'mist_patch_b': lambda: mist_patch(1800, 360, 2),
    'telegraph_ring_s': lambda: telegraph_ring(128), 'telegraph_ring_m': lambda: telegraph_ring(224), 'telegraph_ring_l': lambda: telegraph_ring(320),
    'telegraph_line': telegraph_line, 'boss_arena_ring': boss_arena_ring,
    'halo_amber': lambda: halo('E8B04A'), 'halo_violet': halo_violet, 'crown_spark': crown_spark,
    'fx_hit_spark': fx_hit_spark, 'fx_heal_sparkle': fx_heal_sparkle,
}
