"""Procedural-bridge parts of the treetop city (V5 task 3): deck tiles, rail post, rope tile, ladder tile, lift basket and pulley.

NO per-bridge art: V3's BridgeStrip builds all nine bridges from these tiles (Line2D deck with a tiled texture, ropes, a post every ~46 sketch px).
Orientation contract of the deck tile: a Godot Line2D maps the tile's X axis ALONG the line and its Y axis ACROSS the width, so the planks are
vertical bars of the tile (each plank spans the whole tile height) and the first / last 9 % of the height are the two edge beams.  The tile is
periodic in x (the plank gaps sit on tile multiples).
"""
from __future__ import annotations
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import paint as P
import city_spec as S

PLANK = P.rgb('c9925a')
JOINT = P.rgb('a06a3a')
BEAM = P.rgb('9a6a3c')
BARK_DARK = P.rgb('5e3b20')
EDGE = np.array(P.OUTLINE_COLOR, np.float32) / 255.0


def paint_deck_tile(kind: str):
    """kind 'w43' -> 129 x 128 (5 planks), 'w28' -> 85 x 128 (2 planks).  Periodic in x."""
    w, h = S.scaled(S.SIZES['bridge_deck_tile_' + kind][0]), S.scaled(S.SIZES['bridge_deck_tile_' + kind][1])
    n = 5 if kind == 'w43' else 2
    X, Y = P.grid(h, w)
    pitch = w / n
    rng = np.random.default_rng(300 + w)
    tones = rng.uniform(-.06, .05, n)
    j = np.floor(X / pitch).astype(int) % n
    local = (X - np.floor(X / pitch) * pitch) / pitch
    beam_h = max(8.0, 0.085 * h)
    in_beam = (Y < beam_h) | (Y > h - beam_h)
    grain_a = P.periodic_noise(h, w, 4, max(4, w // 5), 17 + w)
    grain_b = P.periodic_noise(h, w, 12, max(8, w // 2), 19 + w)
    gv = P.sample(grain_a, X, Y) * 0.6 + P.sample(grain_b, X * 1.7, Y * 0.5) * 0.4
    k = 1.0 + tones[j] + 0.20 * gv
    # soft cross shading: each plank a touch lighter on its left edge
    k = k * (1.0 + 0.06 * (0.5 - local))
    col = P.shade(np.broadcast_to(PLANK, (h, w, 3)), k)
    # gaps between planks (periodic: the distance to the nearest multiple of the pitch)
    dgap = np.abs(((X + pitch / 2) % pitch) - pitch / 2)
    gap = P.line_alpha(dgap, 2.6)
    col = col * (1 - gap[..., None] * 0.8) + JOINT * (gap[..., None] * 0.8)
    # nails: two per plank near each beam
    nails = np.zeros((h, w), np.float32)
    for jx in range(n):
        for yy in (beam_h + 7, h - beam_h - 7):
            for fx in (0.28, 0.72):
                dx, dy = X - (jx + fx) * pitch, Y - yy
                nails = np.maximum(nails, P.cover(np.sqrt(dx * dx + dy * dy) - 1.8))
    col = col * (1 - nails[..., None] * 0.55) + BARK_DARK * (nails[..., None] * 0.55)
    # edge beams: darker boards along the whole length, a lit upper edge
    bk = 1.0 + 0.12 * P.sample(P.periodic_noise(h, w, 2, max(4, w // 6), 5 + w), X, Y) * 2
    top_lit = P.smoothstep(beam_h * 0.45, 0, Y) * 0.12 + P.smoothstep(h - beam_h * 0.45, h, Y) * -0.18
    beam = P.shade(np.broadcast_to(BEAM, (h, w, 3)), bk + top_lit)
    bdist = np.minimum(np.abs(Y - beam_h), np.abs(Y - (h - beam_h)))
    bline = P.line_alpha(bdist, 2.2)
    mask_b = in_beam.astype(np.float32)
    col = col * (1 - mask_b[..., None]) + beam * mask_b[..., None]
    col = col * (1 - bline[..., None] * 0.55) + BARK_DARK * (bline[..., None] * 0.55)
    out = np.dstack([col, np.ones((h, w), np.float32)])
    return P.to_image(out)


def tile_seam_error_x(im: Image.Image) -> tuple:
    a = np.asarray(im.convert('L'), np.float32)
    return float(np.abs(a[:, 0] - a[:, -1]).mean()), float(np.abs(np.diff(a, axis=1)).mean())


def paint_post():
    """The rail post of bridges and platform rings: pivot = its foot (bottom centre)."""
    w, h = S.scaled(S.SIZES['bridge_post'][0]), S.scaled(S.SIZES['bridge_post'][1])
    X, Y = P.grid(h, w)
    cx = w / 2.0
    out = np.zeros((h, w, 4), np.float32)
    body_hw = w * 0.20
    cap_hw = w * 0.34
    cap_h = h * 0.13
    # cylinder body (slightly tapered: thicker at the foot)
    hw = body_hw * (0.92 + 0.08 * Y / h)
    sd_body = np.maximum(np.abs(X - cx) - hw, np.maximum(cap_h * 0.5 - Y, Y - (h - 1.5)))
    u = np.clip((X - cx) / hw, -1, 1)
    kb = 1.03 + 0.30 * (-u) - 0.10 * (Y / h)
    grain = P.sample(P.periodic_noise(h, w, 4, 6, 77), X * 1.0, Y * 0.5)
    body = P.shade(np.broadcast_to(P.rgb('a06a3a'), (h, w, 3)), kb + 0.12 * grain)
    P.over(out, body, P.cover(sd_body))
    # a rope groove just below the cap (where the rail rope is tied)
    groove = P.line_alpha(np.abs(Y - h * 0.24), 2.2) * P.cover(sd_body)
    P.over(out, np.broadcast_to(BARK_DARK, (h, w, 3)), groove * 0.55)
    # cap: a small proud disc seen from the side
    sd_cap = np.maximum(np.abs(X - cx) - cap_hw, np.abs(Y - cap_h * 0.55) - cap_h * 0.55)
    sd_cap = sd_cap - 2.0 * (1 - np.abs(u))        # rounded
    cu = np.clip((X - cx) / cap_hw, -1, 1)
    cap = P.shade(np.broadcast_to(P.rgb('c9925a'), (h, w, 3)), 1.02 + 0.22 * (-cu) - 0.08 * (Y / cap_h))
    P.over(out, cap, P.cover(sd_cap))
    im = P.warm_outline(P.to_image(out), radius=2)
    return im, (cx, h - 2.0)


def paint_rope_tile():
    """A vertical twisted rope, 30 x 186, seamless in y (the strand period divides the height). Pivot = tile top centre."""
    w, h = S.scaled(S.SIZES['rope_tile'][0]), S.scaled(S.SIZES['rope_tile'][1])
    X, Y = P.grid(h, w)
    cx = w / 2.0
    hw = w * 0.20
    sd = np.abs(X - cx) - hw
    cov = P.cover(sd)
    u = np.clip((X - cx) / hw, -1, 1)
    period = h / 6.0
    ph = ((Y + (X - cx) * 1.15) / period) % 1.0
    twist = P.smoothstep(0.0, 0.12, ph) * (1 - P.smoothstep(0.34, 0.46, ph))     # one dark groove per strand period
    twist = np.maximum(twist, 0.0)
    kr = 1.02 + 0.28 * (-u) * 0.9
    base = P.shade(np.broadcast_to(P.rgb('c9a66b'), (h, w, 3)), kr)
    groove = P.line_alpha(np.abs(((ph + 0.5) % 1.0) - 0.5) * period * 0.9, 3.0)
    col = base * (1 - groove[..., None] * 0.35) + BARK_DARK * (groove[..., None] * 0.35)
    stroke = P.line_alpha(np.abs(sd + 1.2), 2.2)
    col = col * (1 - stroke[..., None] * 0.7) + EDGE * (stroke[..., None] * 0.7)
    out = np.dstack([col, cov])
    return P.to_image(out)


def paint_ladder_tile():
    """60 x 112: two rails and two rungs per tile (rung pitch 56 px), seamless in y. The tile is tiled vertically (region + repeat)."""
    w, h = S.scaled(S.SIZES['ladder_tile'][0]), S.scaled(S.SIZES['ladder_tile'][1])
    X, Y = P.grid(h, w)
    rail_w = w * 0.17
    out = np.zeros((h, w, 4), np.float32)
    rung_h = h * 0.10
    rung_cov = np.zeros((h, w), np.float32)
    for yc in (h * 0.25, h * 0.75):
        dyr = np.abs(Y - yc)
        # periodic in y: also test the wrapped neighbour
        dyr = np.minimum(dyr, np.minimum(np.abs(Y - yc - h), np.abs(Y - yc + h)))
        rung_cov = np.maximum(rung_cov, P.cover(np.maximum(dyr - rung_h / 2, np.abs(X - w / 2) - (w / 2 - rail_w * 0.5))))
    rung_col = P.shade(np.broadcast_to(P.rgb('c9925a'), (h, w, 3)), 1.0 + 0.2 * (0.5 - (np.abs(((Y % (h / 2)) - h / 4)) / (rung_h / 2)).clip(0, 1)) * 0.6)
    # rails
    for side in (-1, 1):
        rcx = w / 2 + side * (w / 2 - rail_w / 2)
        sd = np.abs(X - rcx) - rail_w / 2
        u = np.clip((X - rcx) / (rail_w / 2), -1, 1)
        rail_col = P.shade(np.broadcast_to(P.rgb('a06a3a'), (h, w, 3)), 1.0 + 0.28 * (-u))
        P.over(out, rail_col, P.cover(sd))
    P.over(out, rung_col, rung_cov)
    # nails on the rails at each rung and strokes
    for yc in (h * 0.25, h * 0.75):
        for side in (-1, 1):
            rcx = w / 2 + side * (w / 2 - rail_w / 2)
            dd = np.sqrt((X - rcx) ** 2 + (Y - yc) ** 2)
            P.over(out, np.broadcast_to(BARK_DARK, (h, w, 3)), P.cover(dd - 1.6) * 0.7)
    a = out[..., 3]
    edge = np.clip(ndimage_dilate(a, 2) - a, 0, 1)
    P.over(out, np.broadcast_to(EDGE, (h, w, 3)), edge * 0.85)
    return P.to_image(out)


def ndimage_dilate(a, r):
    from scipy import ndimage
    return ndimage.grey_dilation(a, size=(r * 2 + 1, r * 2 + 1), mode='nearest')


def paint_basket():
    """Lift basket 145 x 90: woven trapezoid with a rim and a rope bail; pivot = bottom centre."""
    w, h = S.scaled(S.SIZES['lift_basket'][0]), S.scaled(S.SIZES['lift_basket'][1])
    X, Y = P.grid(h, w)
    cx = w / 2.0
    out = np.zeros((h, w, 4), np.float32)
    rim_y, rim_ry = h * 0.36, h * 0.12
    rx_top = w * 0.46
    rx_bot = w * 0.33
    # body: trapezoid from the rim down to the bottom, rounded bottom corners
    t = np.clip((Y - rim_y) / (h - 3 - rim_y), 0, 1)
    hw = rx_top + (rx_bot - rx_top) * t
    sd_body = np.maximum(np.abs(X - cx) - hw, np.maximum(rim_y - Y, Y - (h - 3)))
    # lower rim ellipse bulge: the bottom edge is a slight arc
    sd_arc = P.ellipse_sd(X, Y, cx, h - 3 - rim_ry * 0.9, rx_bot, rim_ry * 0.9)
    cov_body = P.cover(np.where(Y > h - 3 - rim_ry * 0.9, np.maximum(sd_arc, np.abs(X - cx) - hw), sd_body))
    u = np.clip((X - cx) / np.maximum(hw, 1), -1, 1)
    # weave: diagonal cross-hatch bands
    d1 = np.abs(((X + Y * 1.0) % 14.0) - 7.0)
    d2 = np.abs(((X - Y * 1.0) % 14.0) - 7.0)
    weave = np.minimum(P.line_alpha(d1, 1.7), 1.0) * 0.5 + np.minimum(P.line_alpha(d2, 1.7), 1.0) * 0.5
    kb = 1.0 + 0.26 * (-u) - 0.10 * t
    body = P.shade(np.broadcast_to(P.rgb('d9a066'), (h, w, 3)), kb)
    body = body * (1 - weave[..., None] * 0.28) + P.rgb('9a6a3c') * (weave[..., None] * 0.28)
    P.over(out, body, cov_body)
    # rim: an ellipse ring, dark inside, lit lip
    sd_rim_o = P.ellipse_sd(X, Y, cx, rim_y, rx_top + 3, rim_ry + 2)
    sd_rim_i = P.ellipse_sd(X, Y, cx, rim_y + 1, rx_top - 7, rim_ry - 3)
    lip = P.shade(np.broadcast_to(P.rgb('e3b678'), (h, w, 3)), 1.0 + 0.2 * (-u))
    P.over(out, lip, P.cover(sd_rim_o))
    inside = P.shade(np.broadcast_to(P.rgb('6e4626'), (h, w, 3)), 0.85 + 0.25 * np.clip((Y - rim_y) / rim_ry, -1, 1))
    P.over(out, inside, P.cover(sd_rim_i))
    # bail: two ropes from the rim ends up to a point on the centre line
    ln = Image.new('L', (w, h), 0)
    dl = ImageDraw.Draw(ln)
    for sx in (-1, 1):
        dl.line([(cx + sx * (rx_top - 3), rim_y - 1), (cx, 1.5)], fill=255, width=3)
    lnm = np.asarray(ln.filter(ImageFilter.GaussianBlur(0.5)), np.float32) / 255.0
    P.over(out, np.broadcast_to(P.rgb('b08a52'), (h, w, 3)), np.clip(lnm * 1.4, 0, 1))
    im = P.warm_outline(P.to_image(out), radius=2)
    return im, (cx, h - 2.0)


def paint_pulley():
    """Pulley wheel 72 x 72 on a bracket; pivot = the wheel centre (where the rope runs over)."""
    w, h = S.scaled(S.SIZES['lift_pulley'][0]), S.scaled(S.SIZES['lift_pulley'][1])
    X, Y = P.grid(h, w)
    c = (w / 2.0, h * 0.56)
    out = np.zeros((h, w, 4), np.float32)
    # bracket: a bent iron strap over the wheel
    ln = Image.new('L', (w, h), 0)
    dl = ImageDraw.Draw(ln)
    dl.line([(c[0] - 17, c[1]), (c[0] - 17, h * 0.2), (c[0], h * 0.06), (c[0] + 17, h * 0.2), (c[0] + 17, c[1])], fill=255, width=5, joint='curve')
    brk = np.asarray(ln.filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255.0
    P.over(out, P.shade(np.broadcast_to(P.rgb('6a5a6a'), (h, w, 3)), 1.0), np.clip(brk * 1.4, 0, 1))
    # wheel: wooden disc with a groove, spokes and a hub
    r = w * 0.30
    d = np.sqrt((X - c[0]) ** 2 + (Y - c[1]) ** 2)
    u = (X - c[0]) / r
    wheel = P.shade(np.broadcast_to(P.rgb('b88a52'), (h, w, 3)), 1.05 + 0.25 * (-u) * 0.8 - 0.15 * ((Y - c[1]) / r))
    P.over(out, wheel, P.cover(d - r))
    groove = P.line_alpha(np.abs(d - r * 0.78), 3.0) * P.cover(d - r)
    P.over(out, np.broadcast_to(BARK_DARK, (h, w, 3)), groove * 0.6)
    ang = np.arctan2(Y - c[1], X - c[0])
    spoke = np.zeros_like(d)
    for k in range(6):
        a0 = k * math.pi / 3 + 0.3
        dist = np.abs((X - c[0]) * math.sin(a0) - (Y - c[1]) * math.cos(a0))
        spoke = np.maximum(spoke, P.line_alpha(dist, 2.2) * (d < r * 0.76) * (np.cos(ang - a0) > 0))
    P.over(out, np.broadcast_to(BARK_DARK, (h, w, 3)), spoke * 0.55)
    hub = P.cover(d - r * 0.22)
    P.over(out, P.shade(np.broadcast_to(P.rgb('6a5a6a'), (h, w, 3)), 1.1 + 0.2 * (-u)), hub)
    im = P.warm_outline(P.to_image(out), radius=2)
    return im, c


if __name__ == '__main__':
    import sys
    outdir = sys.argv[1]
    for kind in ('w43', 'w28'):
        im = paint_deck_tile(kind)
        im.save(f'{outdir}/bridge_deck_tile_{kind}.png')
        print(kind, im.size, 'seam/inner', tile_seam_error_x(im))
    im, pv = paint_post(); im.save(f'{outdir}/bridge_post.png'); print('post', im.size, pv)
    im = paint_rope_tile(); im.save(f'{outdir}/rope_tile.png'); print('rope', im.size)
    im = paint_ladder_tile(); im.save(f'{outdir}/ladder_tile.png'); print('ladder', im.size)
    im, pv = paint_basket(); im.save(f'{outdir}/lift_basket.png'); print('basket', im.size, pv)
    im, pv = paint_pulley(); im.save(f'{outdir}/lift_pulley.png'); print('pulley', im.size, pv)
