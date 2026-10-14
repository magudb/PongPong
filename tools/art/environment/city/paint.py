"""Small numpy / Pillow painting toolkit of the city art (package V5-art-city).

The painted pieces of the city (platform discs, bark, bridge tiles, foliage, backdrops ...) are analytic: every shape is a signed distance in
pixels turned into an anti-aliased coverage, every texture is a periodic noise, so the same code renders any size (K) and tiles seamlessly.
The look target is the pack's: soft shading, a warm outline (75,60,73) at 55 % and 2 px on the finished sprite (static_render.warm_outline).
All colours are written as 'rrggbb'.  Arrays are float32 RGBA in 0..1 with STRAIGHT alpha unless a name says premultiplied.
"""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

HERE = Path(__file__).resolve().parent
CORE = HERE.parents[1] / 'core'
if str(CORE) not in sys.path:
    sys.path.insert(0, str(CORE))

OUTLINE_COLOR = (75, 60, 73)       # the pack's warm outline: world sprites
OUTLINE_ALPHA = .55
INK = (43, 35, 64)                 # the sketch's ink 2b2340 (icons / UI; the alternative outline of open question 12)


def rgb(c: str) -> np.ndarray:
    return np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def cover(sd, soft: float = 1.0):
    """Anti-aliased coverage of a signed distance in px (negative = inside)."""
    return np.clip(0.5 - sd / soft, 0.0, 1.0).astype(np.float32)


def ellipse_sd(X, Y, cx, cy, rx, ry):
    """First-order signed distance of an ellipse in px (accurate near the boundary, which is all the coverage needs)."""
    u = (X - cx) / rx
    v = (Y - cy) / ry
    f = u * u + v * v - 1.0
    g = np.sqrt((u / rx) ** 2 + (v / ry) ** 2) * 2.0 + 1e-9
    return f / g


def periodic_noise(h: int, w: int, cy: int, cx: int, seed: int) -> np.ndarray:
    """Smooth noise in -0.5..0.5 that wraps in both axes (cy x cx random cells bicubic-upsampled with wrap)."""
    rng = np.random.default_rng(seed)
    g = rng.random((cy, cx)).astype(np.float32)
    up = ndimage.zoom(g, (h / cy, w / cx), order=3, mode='grid-wrap', grid_mode=True)
    up = up[:h, :w]
    if up.shape != (h, w):
        up = np.pad(up, ((0, h - up.shape[0]), (0, w - up.shape[1])), mode='wrap')
    return up - 0.5


def fbm(h: int, w: int, seed: int, base: int = 4, octaves: int = 4, gain: float = .5) -> np.ndarray:
    """Periodic fractal noise (each octave doubles the cells), roughly -0.5..0.5."""
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        c = base * (2 ** o)
        out += amp * periodic_noise(h, w, min(c, h), min(c, w), seed * 131 + o)
        tot += amp
        amp *= gain
    return out / tot


def sample(tex: np.ndarray, x, y):
    """Nearest sample of a periodic texture at float pixel coordinates (wraps)."""
    h, w = tex.shape[:2]
    return tex[np.mod(y.astype(np.int64), h), np.mod(x.astype(np.int64), w)]


def over(dst: np.ndarray, src_rgb: np.ndarray, src_a: np.ndarray) -> None:
    """dst (H,W,4 straight alpha) <- src over dst, in place."""
    a = src_a[..., None].astype(np.float32)
    da = dst[..., 3:4]
    oa = a + da * (1 - a)
    safe = np.where(oa > 1e-6, oa, 1.0)
    dst[..., :3] = (src_rgb * a + dst[..., :3] * da * (1 - a)) / safe
    dst[..., 3:4] = oa


def to_image(arr: np.ndarray) -> Image.Image:
    return Image.fromarray(np.uint8(np.clip(arr * 255.0 + .5, 0, 255)), 'RGBA')


def from_image(im: Image.Image) -> np.ndarray:
    return np.asarray(im.convert('RGBA'), np.float32) / 255.0


def premul_resize(im: Image.Image, size, resample=Image.LANCZOS) -> Image.Image:
    import static_render as sr
    return sr.premul_resize(im, size, resample)


def warm_outline(im: Image.Image, radius: int = 2, color=OUTLINE_COLOR, alpha: float = OUTLINE_ALPHA) -> Image.Image:
    """The pack outline: MaxFilter on alpha, warm grey-violet, 55 % (identical to static_render.warm_outline)."""
    mask = im.getchannel('A')
    thick = mask.filter(ImageFilter.MaxFilter(radius * 2 + 1))
    out = Image.new('RGBA', im.size, tuple(color) + (0,))
    out.putalpha(thick.point(lambda p: int(p * alpha)))
    out.alpha_composite(im)
    return out


def grid(h: int, w: int):
    Y, X = np.mgrid[0:h, 0:w].astype(np.float32)
    return X + 0.5, Y + 0.5


def line_alpha(dist, width: float, soft: float = 1.0):
    """Coverage of a line of `width` px from a distance-to-centre-line in px."""
    return np.clip((width * 0.5 - dist) / soft + 0.5, 0.0, 1.0).astype(np.float32)


def shade(col: np.ndarray, k) -> np.ndarray:
    """Multiply a colour (…,3) by a brightness field k (…) with a warm bias: highlights drift yellow, shadows drift violet."""
    k = np.asarray(k, np.float32)[..., None]
    warm = np.array([1.0, 0.985, 0.94], np.float32)
    cool = np.array([0.94, 0.92, 1.0], np.float32)
    t = np.clip((k - 0.85) / 0.3, 0.0, 1.0)
    tint = cool * (1 - t) + warm * t
    return np.clip(col * k * tint, 0.0, 1.0)


def save_png(arr: np.ndarray, path) -> None:
    to_image(arr).save(path)
