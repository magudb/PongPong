#!/usr/bin/env python3
"""Contact sheets of the city set (V5): `pieces` = every sprite on grass at game scale (zoom 0.4 and 0.2 versions), `composite` = one platform with hut, bridge
and trunk next to the sketch crop.  Pillow only; reads the STAGE masters (or an installed assets tree with --assets).

  python tools/art/environment/city/sheets.py pieces    --stage DIR --out DIR2 [--zoom 0.4]
  python tools/art/environment/city/sheets.py composite --stage DIR --out FILE
"""
from __future__ import annotations
import argparse, json, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
GRASS = (143, 184, 90, 255)


class Tree:
    """Loads PNG masters (stage) or WebP (assets) of the city set + props.json."""

    def __init__(self, root: Path):
        self.dir = root
        self.props = json.loads((root / 'props.json').read_text())

    def img(self, sid: str) -> Image.Image:
        f = self.props[sid]['file']
        for cand in (f, f.replace('.png', '.webp'), f.replace('.webp', '.png')):
            p = self.dir / cand
            if p.exists():
                return Image.open(p).convert('RGBA')
        raise FileNotFoundError(f)

    def piv(self, sid: str):
        return tuple(self.props[sid]['pivot'])


def put(canvas: Image.Image, im: Image.Image, at, pivot, zoom: float) -> None:
    """Draw `im` so its pivot lands on `at` (canvas px) at the given zoom."""
    if zoom != 1.0:
        im = im.resize((max(1, int(round(im.width * zoom))), max(1, int(round(im.height * zoom)))), Image.LANCZOS)
    x, y = int(round(at[0] - pivot[0] * zoom)), int(round(at[1] - pivot[1] * zoom))
    canvas.alpha_composite(im, (x, y)) if x >= 0 and y >= 0 else canvas.paste(im, (x, y), im)


def additive(canvas: Image.Image, layer: Image.Image, at, zoom: float) -> None:
    if zoom != 1.0:
        layer = layer.resize((max(1, int(round(layer.width * zoom))), max(1, int(round(layer.height * zoom)))), Image.LANCZOS)
    a = np.asarray(canvas, np.float32) / 255.0
    l = np.asarray(layer, np.float32) / 255.0
    x, y = int(at[0]), int(at[1])
    h, w = l.shape[:2]
    reg = a[y:y + h, x:x + w, :3]
    reg += l[..., :3] * l[..., 3:4]
    canvas.paste(Image.fromarray(np.uint8(np.clip(a, 0, 1) * 255), 'RGBA'))


def label(canvas: Image.Image, text: str, at):
    ImageDraw.Draw(canvas).text(at, text, fill=(30, 24, 40, 255))


def pieces(t: Tree, out: Path, zooms=(0.4, 0.2)) -> list:
    ids = [k for k in t.props if not k.startswith('_')]
    singles = [i for i in ids if t.props[i].get('kind') not in ('hut_night',) and not i.startswith('platform_disc') and not i.startswith('trunk_bark')
               and not i.startswith('foliage') and i != 'canopy_top_strip']
    paths = []
    for z in zooms:
        canvas = Image.new('RGBA', (1400, 1100), GRASS)
        # a mild grass pattern so scale is readable
        d = ImageDraw.Draw(canvas)
        for gx in range(0, 1400, 64):
            d.line([(gx, 0), (gx, 1100)], fill=(138, 178, 85, 255))
        x, y, rowh = 20, 20, 0
        for sid in singles:
            im = t.img(sid)
            piv = t.piv(sid)
            w, h = int(im.width * z) + 16, int(im.height * z) + 22
            if x + w > 1380:
                x, y, rowh = 20, y + rowh + 6, 0
            blend = t.props[sid].get('blend') == 'add'
            if blend:
                base = Image.new('RGBA', (w, h), (50, 44, 52, 255))
                additive(base, im.resize((max(1, int(im.width * z)), max(1, int(im.height * z))), Image.LANCZOS), (8, 4), 1.0)
                canvas.paste(base, (x, y))
            else:
                put(canvas, im, (x + 8 + piv[0] * z, y + 4 + piv[1] * z), piv, z)
            label(canvas, sid[:26], (x, y + h - 14))
            x += w
            rowh = max(rowh, h)
        p = out / f'pieces_zoom{str(z).replace(".", "")}.png'
        canvas.convert('RGB').save(p)
        paths.append(p)
    return paths


def _tile_strip(tile: Image.Image, length: float, width: float) -> Image.Image:
    """A Line2D-style strip: the tile (X along, Y across) scaled so its height = width, repeated along `length`."""
    sc = width / tile.height
    tw = max(1, int(round(tile.width * sc)))
    th = max(1, int(round(width)))
    one = tile.resize((tw, th), Image.LANCZOS)
    n = int(length // tw) + 2
    strip = Image.new('RGBA', (tw * n, th), (0, 0, 0, 0))
    for i in range(n):
        strip.alpha_composite(one, (i * tw, 0))
    return strip.crop((0, 0, int(length), th))


def _bridge(canvas: Image.Image, t: Tree, a, b, width_px: float, z: float, post=True) -> None:
    """a -> b in canvas px: deck tile strip rotated onto the line, posts and sagging ropes on both sides (what V3's BridgeStrip builds from the tiles)."""
    import math
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy)
    ang = math.degrees(math.atan2(dy, dx))
    wid = 'bridge_deck_tile_w43' if width_px / z > 36 * 3 else 'bridge_deck_tile_w28'
    strip = _tile_strip(t.img(wid), length, width_px)
    big = Image.new('RGBA', (int(length) + 8, int(width_px) + 8), (0, 0, 0, 0))
    big.alpha_composite(strip, (4, 4))
    rot = big.rotate(-ang, expand=True, resample=Image.BICUBIC)
    cx, cy = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    canvas.alpha_composite(rot, (int(cx - rot.width / 2), int(cy - rot.height / 2))) if cx - rot.width / 2 >= 0 and cy - rot.height / 2 >= 0 else canvas.paste(rot, (int(cx - rot.width / 2), int(cy - rot.height / 2)), rot)
    if not post:
        return
    nx, ny = -dy / length, dx / length
    draw = ImageDraw.Draw(canvas)
    postim = t.img('bridge_post')
    spans = max(2, int(round(length / (46 * 3 * z))))
    for side in (-1, 1):
        pts = []
        for i in range(spans + 1):
            f = i / spans
            bx = a[0] + dx * f + nx * side * width_px / 2
            by = a[1] + dy * f + ny * side * width_px / 2
            put(canvas, postim, (bx, by), t.piv('bridge_post'), z)
            pts.append((bx, by - 72 * z))
            if i < spans:
                f2 = (i + 0.5) / spans
                pts.append((a[0] + dx * f2 + nx * side * width_px / 2, a[1] + dy * f2 + ny * side * width_px / 2 - 72 * z + 14 * z))
        draw.line(pts, fill=(176, 138, 82, 255), width=max(2, int(6 * z)))


def composite(t: Tree, out: Path, sketch: Path | None = None) -> Path:
    """Platform A of the sketch (Hoppe's: two huts, tree T1, bridges B0 and B2, owl holes, lanterns) rebuilt from the baked pieces at world scale x z, next to the sketch
    crop at the same scale.  Sketch -> page pixels of refs/miljoer_v2_render.png: x' = 0.889 x + 79, y' = 0.889 y + 579."""
    import city_spec as S
    K = S.K
    z = 0.62
    sk_scale = K * z / 0.889                       # sketch crop px -> composite px
    CROP = (270, 565, 830, 960)                    # in page px
    W, H = int((CROP[2] - CROP[0]) * sk_scale), int((CROP[3] - CROP[1]) * sk_scale)
    centre_sk = (519.0, 190.0)
    page = lambda p: (0.889 * p[0] + 79, 0.889 * p[1] + 579)

    def to_c(p):                                   # sketch px -> composite px
        px, py = page(p)
        return ((px - CROP[0]) * sk_scale, (py - CROP[1]) * sk_scale)

    sky = Image.new('RGBA', (W, H), (190, 214, 150, 255))
    sky.alpha_composite(_far_crop(t, W, H))
    cx, cy = to_c(centre_sk)
    # trunk T1 (w367): the upper segment above the platform, the lower one below it
    bark = t.img('trunk_bark_w367')
    bw, bh = int(bark.width * z), int(bark.height * z)
    bark_s = bark.resize((bw, bh), Image.LANCZOS)
    foot = t.img('trunk_foot_w367')
    neck = t.props['trunk_foot_w367']['neck_px']
    # lower trunk first (below the disc), then the disc, then the upper trunk
    yy = cy
    while yy < H:
        sky.paste(bark_s, (int(cx - bw / 2), int(yy)), bark_s)
        yy += bh
    disc = t.img('platform_disc_184')
    put(sky, disc, (cx, cy), t.piv('platform_disc_184'), z)
    seg_end = cy - neck * z
    yy = seg_end - bh
    while yy > -bh:
        sky.paste(bark_s, (int(cx - bw / 2), int(yy)), bark_s)
        yy -= bh
    put(sky, foot, (cx, cy), t.piv('trunk_foot_w367'), z)
    # the owl hole of the sketch under platform A and its shelf
    put(sky, t.img('trunk_hole_owl'), to_c((519.0, 370.0)), t.piv('trunk_hole_owl'), z)
    put(sky, t.img('owl_shelf'), to_c((519.0, 395.0)), t.piv('owl_shelf'), z)
    # bridges B2 (A -> C, steep down-left) and B0 (A -> Upper, down-right), from the rim to the crop edge
    _bridge(sky, t, to_c((445.0, 281.0)), to_c((355.0, 513.0)), 46 * K * z, z)
    _bridge(sky, t, to_c((622.0, 271.0)), to_c((804.0, 375.0)), 43 * K * z, z)
    # rail posts along the front rim, huts H1 (straw, pink pennant) and H2 (moss), lanterns
    import numpy as _np
    for k in range(-7, 8):
        ang = _np.pi / 2 + k * 0.15
        put(sky, t.img('bridge_post'), (cx + _np.cos(ang) * 551 * z * 0.96, cy + _np.sin(ang) * 318 * z * 0.96), t.piv('bridge_post'), z)
    for hid, base in (('hut_m_straw', (408.0, 200.0)), ('hut_s_moss', (584.0, 247.0))):
        bx, by = to_c(base)
        put(sky, t.img(hid), (bx, by), t.piv(hid), z)
        if hid == 'hut_m_straw':
            ap = t.props[hid]['apex']; pv = t.piv(hid)
            put(sky, t.img('pennant_pink'), (bx + (ap[0] - pv[0]) * z, by + (ap[1] - pv[1]) * z), t.piv('pennant_pink'), z)
    for lp in ((433.2, 323.6), (349.8, 199.6), (564.7, 133.2), (690.4, 262.3)):
        put(sky, t.img('lantern_hang'), to_c(lp), t.piv('lantern_hang'), z)
    mine = sky.convert('RGB')
    mine.save(out)
    if sketch is not None and sketch.exists():
        sk = Image.open(sketch).convert('RGB').crop(CROP).resize((W, H), Image.LANCZOS)
        both = Image.new('RGB', (W * 2 + 24, H), (240, 235, 225))
        both.paste(sk, (0, 0)); both.paste(mine, (W + 24, 0))
        both.save(out.with_name(out.stem + '_vs_sketch.png'))
    return out


def _far_crop(t: Tree, W: int, H: int) -> Image.Image:
    far_p = t.dir.parent.parent.parent / 'masters' / 'backdrops' / 'treetop_far.png'
    if not far_p.exists():
        far_p = t.dir.parent.parent / 'backdrops' / 'treetop_far.webp'
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    if far_p.exists():
        far = Image.open(far_p).convert('RGBA')
        far = far.resize((int(far.width * 0.62), int(far.height * 0.62)), Image.LANCZOS)
        layer.alpha_composite(far.crop((100, 0, 100 + W, H)) if far.height >= H else far.crop((100, 0, 100 + W, far.height)), (0, 0))
    return layer


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('what', choices=['pieces', 'composite'])
    ap.add_argument('--stage', required=True)
    ap.add_argument('--assets', default=None, help='read an installed tree instead of the stage (assets/iso_props/city)')
    ap.add_argument('--out', required=True)
    ap.add_argument('--sketch', default=None)
    a = ap.parse_args()
    root = Path(a.assets) if a.assets else Path(a.stage) / 'masters' / 'iso_props' / 'city'
    t = Tree(root)
    out = Path(a.out)
    if a.what == 'pieces':
        out.mkdir(parents=True, exist_ok=True)
        print('\n'.join(str(p) for p in pieces(t, out)))
    else:
        out.parent.mkdir(parents=True, exist_ok=True)
        print(composite(t, out, Path(a.sketch) if a.sketch else None))


if __name__ == '__main__':
    main()
