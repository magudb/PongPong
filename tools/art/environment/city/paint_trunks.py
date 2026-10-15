"""Trunks of the treetop city (V5 task 1): the vertically seamless bark tile (flat cylinder shading, dark band on the right 35 %), the foot arc where an
upper trunk meets a deck, the root flare where a lower trunk meets the ground, and the owl hole decals of the trunks (task 4).

Bark tile = `trunk_bark_w<W>`: W px wide (2 x rx x K), 512 px tall, periodic in y.  The engine repeats it with a Sprite2D region.  The foot sprite
continues the pattern: its first rows ARE the tile rows 0..neck-1, so an upper segment whose region ends at tile row 512 meets its foot without a jump.
"""
from __future__ import annotations
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import paint as P
import city_spec as S

BARK = P.rgb('9c6a3e')
BARK_DARK = P.rgb('5e3b20')
EDGE = np.array(P.OUTLINE_COLOR, np.float32) / 255.0


def cylinder_k(U):
    """Brightness across the trunk: a lit side that falls off gently and a darker band over the right 35 %."""
    lit = 1.10 - 0.20 * U
    band = P.smoothstep(0.615, 0.665, U)
    dark = 0.70 - 0.08 * np.clip((U - 0.65) / 0.35, 0, 1)
    return lit * (1 - band) + dark * band


def bark_field(U, Y, wpx: int, seed: int):
    """RGB + groove mask of the bark at normalised across-coordinates U (0..1) and tile rows Y (periodic in 512)."""
    H = S.BARK_H
    tex_a = P.periodic_noise(H, wpx, 8, max(8, wpx // 8), seed)
    tex_b = P.periodic_noise(H, wpx, 16, max(8, wpx // 3), seed + 1)
    tex_c = P.periodic_noise(H, wpx, 48, max(8, wpx // 14), seed + 2)
    xi = np.clip(U * (wpx - 1), 0, wpx - 1)
    n = P.sample(tex_a, xi, Y) * 0.55 + P.sample(tex_b, xi, Y) * 0.28 + P.sample(tex_c, xi, Y) * 0.17
    k = cylinder_k(U) * (1.0 + 0.24 * n)
    rng = np.random.default_rng(seed + 9)
    nl = max(4, int(round(wpx / 62)))
    groove = np.zeros_like(U, dtype=np.float32)
    for i in range(nl):
        x0 = (i + 0.5 + rng.uniform(-.28, .28)) / nl
        m1 = int(rng.integers(1, 4))
        m2 = m1 + int(rng.integers(2, 5))
        a1 = rng.uniform(5, 9) / wpx
        a2 = rng.uniform(1.5, 3.5) / wpx
        ph1, ph2 = rng.uniform(0, 6.283, 2)
        xl = x0 + a1 * np.sin(2 * math.pi * m1 * Y / H + ph1) + a2 * np.sin(2 * math.pi * m2 * Y / H + ph2)
        d = np.abs(U - xl) * wpx
        # a groove is a thin dark line with a pale lip on its lit side
        groove = np.maximum(groove, P.line_alpha(d, 3.2))
    col = P.shade(np.broadcast_to(BARK, U.shape + (3,)), k)
    col = col * (1 - groove[..., None] * 0.5) + BARK_DARK * (groove[..., None] * 0.5)
    return col, groove


def paint_bark(w: int, outline: bool = True):
    wpx = S.scaled(w)
    H = S.BARK_H
    X, Y = P.grid(H, wpx)
    U = X / wpx
    col, _ = bark_field(U, Y, wpx, 101 + w)
    # the trunk's own edges: 10 px of ambient darkening and a 3 px ink-ish stroke (the pack outline colour, nearly opaque)
    dl = X
    dr = wpx - X
    de = np.minimum(dl, dr)
    ao = 1.0 - 0.20 * P.smoothstep(14, 0, de)
    col = col * ao[..., None]
    stroke = P.line_alpha(de - 1.3, 3.0)
    col = col * (1 - stroke[..., None] * 0.85) + EDGE * (stroke[..., None] * 0.85)
    out = np.dstack([col, np.ones((H, wpx), np.float32)])
    return P.to_image(out)


def tile_seam_error(im: Image.Image) -> tuple:
    """(mean abs luma step across the wrap seam, mean abs luma step between neighbouring rows inside the tile): the tile is seamless when
    the first is not larger than about the second."""
    a = np.asarray(im.convert('L'), np.float32)
    seam = np.abs(a[0] - a[-1]).mean()
    inner = np.abs(np.diff(a, axis=0)).mean()
    return float(seam), float(inner)


def _foot_alpha(wpx: int, h: int, neck: int):
    X, Y = P.grid(h, wpx)
    rx = wpx / 2.0
    ry = rx * S.SQ
    sd_el = P.ellipse_sd(X, Y, wpx / 2.0, float(neck), rx, ry)
    sd_rect = np.abs(X - wpx / 2.0) - rx                                        # the straight neck above the centre line (open at the top)
    sd = np.where(Y < neck, sd_rect, sd_el)
    return P.cover(sd), sd_el, X, Y, rx, ry


def paint_foot(w: int, outline: bool = True):
    wpx = S.scaled(w)
    h = S.scaled(S.TRUNKS[w]['foot_h'])
    neck = int(round(S.FOOT_NECK * S.K))
    bark = np.asarray(paint_bark(w, outline=False), np.float32) / 255.0      # same tile: rows 0..h-1 continue an upper trunk
    col = bark[:h, :, :3].copy()
    cov, sd_el, X, Y, rx, ry = _foot_alpha(wpx, h, neck)
    # the arc: ambient darkening toward the cut edge, a contact shadow under the lip, a stroke
    below = (Y >= neck).astype(np.float32)
    ao = 1.0 - 0.28 * P.smoothstep(16, 0, -sd_el) * below
    col = col * ao[..., None]
    stroke = P.line_alpha(np.abs(sd_el + 1.5), 3.0) * below
    col = col * (1 - stroke[..., None] * 0.85) + EDGE * (stroke[..., None] * 0.85)
    out = np.dstack([col, cov])
    return P.to_image(out), (wpx / 2.0, float(neck))


def paint_root(w: int, outline: bool = True):
    """Ground-contact flare of a lower trunk: the straight trunk (width w) widens to 1.35 w over `neck` px and ends in a lobed ground ellipse."""
    wpx = S.scaled(w)
    W, H = S.scaled(S.TRUNKS[w]['root'][0]), S.scaled(S.TRUNKS[w]['root'][1])
    cx = W / 2.0
    fw = W / 2.0 - 1.0
    ry = fw * S.SQ
    yc = H - 1.0 - ry                                    # y of the base ellipse centre = the pivot
    X, Y = P.grid(H, W)
    t = np.clip(Y / max(yc, 1.0), 0, 1)
    ease = t ** 2.3
    hw = wpx / 2.0 + (fw - wpx / 2.0) * ease
    # three root lobes at the ground: the ellipse's lower arc is bumped outward
    ang = np.arctan2((Y - yc) / ry, (X - cx) / fw)
    lobes = 1.0 + 0.05 * np.cos(ang * 5.0 + 0.6) * P.smoothstep(0.0, ry * 0.9, Y - yc)
    sd_el = P.ellipse_sd(X, Y, cx, yc, fw * lobes, ry * lobes)
    sd_flare = np.abs(X - cx) - hw
    sd = np.where(Y < yc, sd_flare, sd_el)
    cov = P.cover(sd)
    # bark: the tile stretched across the flare so the grooves fan out
    Uc = np.clip((X - cx) / (2.0 * np.maximum(hw, 1.0)) + 0.5, 0, 1)
    Yb = Y + 7
    col, groove = bark_field(Uc, Yb, wpx, 101 + w)
    edge_d = np.maximum(hw - np.abs(X - cx), 0)
    ao = 1.0 - 0.22 * P.smoothstep(16, 0, edge_d)
    below = P.smoothstep(0.0, 14.0, Y - yc)
    ao = ao * (1.0 - 0.22 * P.smoothstep(18, 0, -sd_el) * (Y >= yc))
    col = col * ao[..., None]
    stroke = P.line_alpha(np.abs(sd + 1.5), 3.0)
    col = col * (1 - stroke[..., None] * 0.85) + EDGE * (stroke[..., None] * 0.85)
    out = np.dstack([col, cov])
    return P.to_image(out), (cx, yc)


# ---------------------------------------------------------------------------------------------------------------------------
# owl holes and the shelf under them (task 4)
# ---------------------------------------------------------------------------------------------------------------------------

def paint_owl_hole(variant: str = 'a', outline: bool = True):
    W, H = S.scaled(S.SIZES['trunk_hole_owl'][0]), S.scaled(S.SIZES['trunk_hole_owl'][1])
    X, Y = P.grid(H, W)
    cx, cy = W / 2.0, H / 2.0 + 2
    rx, ry = W / 2.0 - 5, H / 2.0 - 5
    sd_o = P.ellipse_sd(X, Y, cx, cy, rx, ry)                     # outer lip
    sd_h = P.ellipse_sd(X, Y, cx, cy + 3, rx - 17, ry - 17)       # the hole
    cov_o = P.cover(sd_o)
    cov_h = P.cover(sd_h)
    out = np.zeros((H, W, 4), np.float32)
    u = (X - cx) / rx
    v = (Y - cy) / ry
    # lip: a thick bark ring, lighter on the upper left, darker lower right (it stands proud of the trunk)
    lip_k = 1.02 + 0.18 * (-u * 0.6 - v * 0.8)
    lip = P.shade(np.broadcast_to(P.rgb('b4814c' if variant == 'a' else 'a9784a'), (H, W, 3)), lip_k)
    ring_dark = P.line_alpha(np.abs(sd_o + 3.0), 3.0)
    lip = lip * (1 - ring_dark[..., None] * 0.28)
    P.over(out, lip, cov_o)
    # inside: warm dark wood that lightens toward the bottom (the floor of the hole) with a soft shadow under the upper lip
    hv = (Y - (cy + 3)) / (ry - 17)
    inner_k = 0.72 + 0.40 * np.clip(hv * 0.5 + 0.5, 0, 1) ** 1.6
    inner = P.shade(np.broadcast_to(P.rgb('7a5636'), (H, W, 3)), inner_k)
    shadow_top = 1.0 - 0.38 * P.smoothstep(0.55, -0.9, hv)
    inner = inner * shadow_top[..., None]
    edge_in = P.line_alpha(np.abs(sd_h + 1.3), 2.8)
    inner = inner * (1 - edge_in[..., None] * 0.6) + EDGE * (edge_in[..., None] * 0.6)
    P.over(out, inner, cov_h)
    if variant == 'b':
        # moss and a small cap mushroom on the top lip
        rng = np.random.default_rng(5)
        mask = Image.new('L', (W, H), 0)
        d = ImageDraw.Draw(mask)
        for i in range(9):
            a = math.radians(200 + i * 15 + rng.uniform(-4, 4))
            px, py = cx + math.cos(a) * (rx - 7), cy + math.sin(a) * (ry - 7)
            r = rng.uniform(9, 15)
            d.ellipse((px - r, py - r * .8, px + r, py + r * .8), fill=255)
        mask = np.asarray(mask.filter(ImageFilter.GaussianBlur(1.5)), np.float32) / 255.0 * cov_o
        moss = P.shade(np.broadcast_to(P.rgb('7fa24a'), (H, W, 3)), 1.0 + 0.2 * P.fbm(H, W, 55, 8, 3))
        P.over(out, moss, mask * 0.95)
    im = P.to_image(out)
    return (P.warm_outline(im) if outline else im), (cx, cy)


def paint_owl_shelf(outline: bool = True):
    W, H = S.scaled(S.SIZES['owl_shelf'][0]), S.scaled(S.SIZES['owl_shelf'][1])
    X, Y = P.grid(H, W)
    cx = W / 2.0
    out = np.zeros((H, W, 4), np.float32)
    # a curved plank ledge: top surface (ellipse sliver) + a thick front edge (boat-shaped)
    top_cy, top_ry = H * 0.40, H * 0.30
    rx = W * 0.43
    sd_top = P.ellipse_sd(X, Y, cx - W * 0.05, top_cy, rx, top_ry)
    sd_front = P.ellipse_sd(X, Y, cx - W * 0.05, top_cy + 1.0, rx, top_ry + 14)
    sd_front = np.maximum(sd_front, top_cy - Y)           # only below the centre line
    cov_front = P.cover(sd_front)
    cov_top = P.cover(sd_top)
    kf = 0.78 + 0.25 * (-(X - cx) / rx) * 0.5
    front = P.shade(np.broadcast_to(P.rgb('8a5a32'), (H, W, 3)), kf * (1.05 - 0.28 * np.clip((Y - top_cy) / 18, 0, 1)))
    P.over(out, front, cov_front)
    tk = 1.0 + 0.10 * P.fbm(H, W, 66, 6, 2) + 0.06 * (-(X - cx) / rx)
    top = P.shade(np.broadcast_to(P.rgb('c9925a'), (H, W, 3)), tk)
    P.over(out, top, cov_top)
    edge = P.line_alpha(np.abs(sd_top) , 2.0) * (Y > top_cy)
    P.over(out, np.broadcast_to(BARK_DARK, (H, W, 3)), edge * 0.5)
    # a leafy sprig at the right end
    leaf = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(leaf)
    lx, ly = cx + W * 0.30, top_cy + 3
    for ang, ln in ((-35, 30), (10, 34), (45, 24)):
        a = math.radians(ang)
        tipx, tipy = lx + math.cos(a) * ln, ly + math.sin(a) * ln * 0.55 - 10
        mx, my = (lx + tipx) / 2, (ly + tipy) / 2
        d.polygon([(lx, ly), (mx - 4, my - 10), (tipx, tipy), (mx + 4, my + 6)], fill=255)
    leafm = np.asarray(leaf.filter(ImageFilter.GaussianBlur(0.7)), np.float32) / 255.0
    P.over(out, P.shade(np.broadcast_to(P.rgb('6b9a3e'), (H, W, 3)), 1.05), leafm)
    im = P.to_image(out)
    return (P.warm_outline(im) if outline else im), (cx, top_cy)


if __name__ == '__main__':
    import sys
    outdir = sys.argv[1]
    for w in S.TRUNKS:
        bi = paint_bark(w)
        bi.save(f'{outdir}/trunk_bark_w{w}.png')
        print('bark', w, bi.size, 'seam/inner', tile_seam_error(bi))
        fi, fp = paint_foot(w)
        fi.save(f'{outdir}/trunk_foot_w{w}.png')
        print('foot', w, fi.size, fp)
        ri, rp = paint_root(w)
        ri.save(f'{outdir}/trunk_root_w{w}.png')
        print('root', w, ri.size, rp)
    for v in 'ab':
        oi, op = paint_owl_hole(v)
        oi.save(f'{outdir}/trunk_hole_owl_{v}.png')
        print('owl', v, oi.size, op)
    si, sp = paint_owl_shelf()
    si.save(f'{outdir}/owl_shelf.png')
    print('shelf', si.size, sp)
