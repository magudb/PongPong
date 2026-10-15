"""Small painted pieces and the large soft layers of the treetop city (V5 tasks 2, 4 and 5): pennants, hanging lantern, door lamp, flame frames, the
hanging bat, the front foliage clusters, the canopy frame, the sky gradient and the far trunk bars of the backdrop, a shared soft contact shadow.
All analytic (signed distances, periodic noise), deterministic (fixed seeds), straight-alpha RGBA.
"""
from __future__ import annotations
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage
import paint as P
import city_spec as S

BARK_DARK = P.rgb('5e3b20')
EDGE = np.array(P.OUTLINE_COLOR, np.float32) / 255.0
INKC = np.array(P.INK, np.float32) / 255.0


def _blank(h, w):
    return np.zeros((h, w, 4), np.float32)


def _full(h, w, col):
    return np.broadcast_to(col, (h, w, 3))


def _outline(out):
    return P.warm_outline(P.to_image(out), radius=2)


# ----------------------------------------------------------------------------------------------------------------------------
# pennants: a pole with a swallow-tailed flag, two frames of a gentle wave
# ----------------------------------------------------------------------------------------------------------------------------

def paint_pennant(name: str, frame: int):
    w, h = S.scaled(S.SIZES['pennant'][0]), S.scaled(S.SIZES['pennant'][1])
    col = P.rgb(S.PENNANTS[name])
    X, Y = P.grid(h, w)
    out = _blank(h, w)
    px = 11.0
    # pole: a slim wooden rod with a ball on top
    sd_pole = np.maximum(np.abs(X - px) - 2.6, Y - (h - 2.0))
    u = np.clip((X - px) / 2.6, -1, 1)
    pole = P.shade(_full(h, w, P.rgb('9c6a3e')), 1.05 + 0.25 * (-u))
    P.over(out, pole, P.cover(np.maximum(sd_pole, 6.0 - Y)))
    ball = np.sqrt((X - px) ** 2 + (Y - 6.0) ** 2) - 4.6
    P.over(out, P.shade(_full(h, w, P.rgb('e3b678')), 1.1), P.cover(ball))
    # flag: top edge and bottom edge waves, a notch at the tail
    ph = frame * math.pi
    x0, x1 = px + 2.6, w - 3.0
    L = x1 - x0
    t = np.clip((X - x0) / L, 0, 1)
    amp = 5.0 * t
    wave = amp * np.sin(2 * math.pi * 1.15 * t - ph + 0.5)
    ytop = 10.0 + wave
    ybot = 50.0 + wave * 1.1 - 6.0 * t * 0.0
    ymid = (ytop + ybot) / 2
    half = (ybot - ytop) / 2 * (1.0 - 0.18 * t)
    sd_flag = np.maximum(np.abs(Y - ymid) - half, np.maximum(x0 - X, X - x1))
    nd = 0.30 * L
    notch = (X - (x1 - nd)) / nd                                         # 0 .. 1 over the notch
    sd_notch = (half * np.clip(notch, 0, 1) * 1.15) - np.abs(Y - ymid)    # inside the V cut when positive
    inside_notch = np.where(X > x1 - nd, np.minimum(sd_notch, X - (x1 - nd)), -1e3)
    sd_flag = np.maximum(sd_flag, inside_notch * 0.9)
    fk = 1.02 + 0.16 * np.clip((ymid - Y) / np.maximum(half, 1), -1, 1) * 0.7 + 0.10 * np.sin(2 * math.pi * 1.15 * t - ph + 0.5 + 1.2)
    flag = P.shade(_full(h, w, col), fk)
    P.over(out, flag, P.cover(sd_flag))
    # a pale stripe along the pole side (the hem)
    hem = P.line_alpha(np.abs(X - (x0 + 2.0)), 3.0) * P.cover(sd_flag)
    P.over(out, _full(h, w, col * 0.72), hem * 0.5)
    return _outline(out), (px, h - 3.0)


# ----------------------------------------------------------------------------------------------------------------------------
# lanterns
# ----------------------------------------------------------------------------------------------------------------------------

def paint_lantern():
    """Hanging lantern 54 x 96: a cord from the hook, a dark cap, a gold glass body with a light core, a dark base.  Pivot = the body's centre
    (the data point `at` of the sketch lantern is the centre of its 14 x 18 rect)."""
    w, h = S.scaled(S.SIZES['lantern_hang'][0]), S.scaled(S.SIZES['lantern_hang'][1])
    X, Y = P.grid(h, w)
    cx = w / 2.0
    out = _blank(h, w)
    s = w / 54.0
    body_c = h * 0.60
    bw, bh = 17 * s, 27 * s
    # cord and hook ring
    P.over(out, _full(h, w, P.rgb('7a5a3a')), P.cover(np.maximum(np.abs(X - cx) - 1.6, np.maximum(2 - Y, Y - (body_c - bh - 5 * s)))))
    ring = np.abs(np.sqrt((X - cx) ** 2 + (Y - 5.0 * s) ** 2) - 4.2 * s) - 1.4
    P.over(out, _full(h, w, P.rgb('7a5a3a')), P.cover(ring))
    # cap (trapezoid) and base
    cap_y0, cap_y1 = body_c - bh - 5 * s, body_c - bh + 2 * s
    t = np.clip((Y - cap_y0) / max(cap_y1 - cap_y0, 1), 0, 1)
    sd_cap = np.maximum(np.abs(X - cx) - (bw * 0.45 + (bw * 0.20 + 4 * s) * t), np.maximum(cap_y0 - Y, Y - cap_y1))
    P.over(out, P.shade(_full(h, w, P.rgb('5a4a62')), 1.05 + 0.2 * (-(X - cx) / bw)), P.cover(sd_cap))
    base_y0, base_y1 = body_c + bh - 2 * s, body_c + bh + 5 * s
    sd_base = np.maximum(np.abs(X - cx) - (bw + 3 * s), np.maximum(base_y0 - Y, Y - base_y1))
    P.over(out, P.shade(_full(h, w, P.rgb('5a4a62')), 1.0 + 0.2 * (-(X - cx) / bw)), P.cover(sd_base))
    # glass body: rounded rect, gold, light core, two thin bars
    r = 6.0 * s
    qx, qy = np.abs(X - cx) - (bw - r), np.abs(Y - body_c) - (bh - r)
    sd_body = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2) + np.minimum(np.maximum(qx, qy), 0) - r
    d = np.sqrt(((X - cx) / bw) ** 2 + ((Y - body_c) / bh) ** 2)
    glass = P.rgb('f2c14e') * (1 - np.clip(1.15 - d, 0, 1)[..., None]) + P.rgb('fff2c0') * np.clip(1.15 - d, 0, 1)[..., None]
    glass = glass * (1.0 + 0.10 * (-(X - cx) / bw))[..., None]
    P.over(out, np.clip(glass, 0, 1), P.cover(sd_body))
    bars = np.maximum(P.line_alpha(np.abs(X - (cx - bw * 0.36)), 1.6), P.line_alpha(np.abs(X - (cx + bw * 0.36)), 1.6)) * P.cover(sd_body + 2)
    P.over(out, _full(h, w, P.rgb('7a5a3a')), bars * 0.55)
    return _outline(out), (cx, body_c)


def paint_lamp_door():
    """Door lamp 54 x 54: a round gold lantern on a short bracket (pivot = the lamp centre)."""
    w, h = S.scaled(S.SIZES['lamp_door'][0]), S.scaled(S.SIZES['lamp_door'][1])
    X, Y = P.grid(h, w)
    c = (w * 0.56, h * 0.58)
    out = _blank(h, w)
    s = w / 54.0
    # bracket: an arm to the upper left
    ln = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(ln)
    d.line([(c[0] - 14 * s, c[1] - 14 * s), (c[0] - 2 * s, c[1] - 16 * s)], fill=255, width=max(2, int(3 * s)))
    d.line([(c[0] - 14 * s, c[1] - 24 * s), (c[0] - 14 * s, c[1] - 6 * s)], fill=255, width=max(2, int(3 * s)))
    arm = np.asarray(ln.filter(ImageFilter.GaussianBlur(0.5)), np.float32) / 255.0
    P.over(out, _full(h, w, P.rgb('5a4a62')), np.clip(arm * 1.3, 0, 1))
    r = 14.5 * s
    dd = np.sqrt((X - c[0]) ** 2 + (Y - c[1]) ** 2)
    glass = P.rgb('f2c14e') * (1 - np.clip(1.1 - dd / r, 0, 1)[..., None]) + P.rgb('fff2c0') * np.clip(1.1 - dd / r, 0, 1)[..., None]
    P.over(out, np.clip(glass * (1.0 + 0.10 * (-(X - c[0]) / r))[..., None], 0, 1), P.cover(dd - r))
    ring = P.line_alpha(np.abs(dd - r * 0.95), 2.4 * s) * P.cover(dd - r - 1)
    P.over(out, _full(h, w, P.rgb('5a4a62')), ring * 0.85)
    cap = P.cover(np.maximum(np.abs(X - c[0]) - r * 0.55, np.abs(Y - (c[1] - r * 0.95)) - 2.5 * s))
    P.over(out, _full(h, w, P.rgb('5a4a62')), cap)
    return _outline(out), c


# ----------------------------------------------------------------------------------------------------------------------------
# fire: three additive flame frames
# ----------------------------------------------------------------------------------------------------------------------------

def paint_flame(frame: int):
    """120 x 168 additive flame: layered tongues (orange, gold, pale core) with a soft halo; the three frames flicker differently (lean, height of every tongue).
    Pivot = the base centre."""
    w, h = S.scaled(S.SIZES['fire_flame'][0]), S.scaled(S.SIZES['fire_flame'][1])
    X, Y = P.grid(h, w)
    cx, base = w / 2.0, h - 12.0
    out = _blank(h, w)
    layers = [(1.00, 1.00, 'ff6a28', 0.95), (0.72, 0.88, 'ffa63a', 0.95), (0.46, 0.70, 'ffd86a', 0.97), (0.22, 0.46, 'fff4cc', 1.0)]
    # (centre offset px, height fraction, width px) of the tongues, per frame
    tongues = [
        [(0, 1.00, 27), (-27, 0.66, 19), (26, 0.78, 20), (-45, 0.34, 12), (44, 0.40, 12)],
        [(2, 0.90, 27), (-26, 0.82, 20), (27, 0.60, 19), (-44, 0.40, 12), (45, 0.30, 11)],
        [(-2, 0.96, 27), (-27, 0.58, 19), (26, 0.86, 20), (-44, 0.30, 11), (44, 0.44, 12)],
    ][frame]
    lean = (-0.10, 0.14, -0.02)[frame]
    for hk, wk, hexc, a in layers:
        cov = np.zeros((h, w), np.float32)
        for ti, (dx, hs, wd) in enumerate(tongues):
            ln = (base - 14.0) * hs * hk
            t = np.clip((base - Y) / ln, -0.2, 1.2)
            tc = np.clip(t, 0.0, 1.0)
            sway = lean * 34.0 * tc ** 1.6 + 5.0 * np.sin(tc * 5.0 + frame * 2.0 + ti) * tc + dx * (1.0 - 0.25 * tc)
            # a teardrop: full width low down, narrowing to a lick at the tip
            prof = (1.0 - tc) ** 0.7 * (0.55 + 0.45 * np.clip(tc * 6.0, 0, 1))
            wid = wd * wk * prof
            sd = np.abs(X - (cx + sway)) - wid
            sd = np.maximum(sd, Y - (base + 3.0))
            cov = np.maximum(cov, P.cover(sd, 1.8) * ((t < 1.0) & (t > -0.05)))
        P.over(out, _full(h, w, P.rgb(hexc)), cov * a)
    gd = np.sqrt(((X - cx) / (w * 0.55)) ** 2 + ((Y - (base - 16)) / (h * 0.38)) ** 2)
    glow = np.clip(1.0 - gd, 0, 1) ** 2 * 0.30
    P.over(out, _full(h, w, P.rgb('ff9a3c')), glow * (1 - out[..., 3]))
    # additive convention: straight alpha = brightness, colours normalised (like A1's night layers)
    a = out[..., 3:4]
    rgb = out[..., :3] * a
    mx = rgb.max(-1, keepdims=True)
    res = np.zeros_like(out)
    res[..., :3] = np.where(mx > 1e-4, rgb / np.maximum(mx, 1e-4), 0)
    res[..., 3:4] = mx
    return P.to_image(res), (cx, base)


# ----------------------------------------------------------------------------------------------------------------------------
# the hanging bat (static, 2-frame sway): head down, wings wrapped, feet on a short rope
# ----------------------------------------------------------------------------------------------------------------------------

def paint_bat(frame: int):
    w, h = S.scaled(S.SIZES['bat_hang'][0]), S.scaled(S.SIZES['bat_hang'][1])
    out = _blank(h, w)
    ss = 4
    W, H = w * ss, h * ss
    X, Y = P.grid(H, W)
    cx = W / 2.0
    s = ss * w / 84.0
    ang = math.radians((-3.0, 3.0)[frame])
    # rotate coordinates about the hook (top centre) for the sway
    ox, oy = cx, 4.0 * s
    dx, dy = X - ox, Y - oy
    Xr = ox + dx * math.cos(ang) + dy * math.sin(ang)
    Yr = oy - dx * math.sin(ang) + dy * math.cos(ang)
    big = _blank(H, W)
    body_c = (cx, 52 * s)
    cloak = P.ellipse_sd(Xr, Yr, body_c[0], body_c[1] - 6 * s, 24 * s, 34 * s)
    wing_l = P.ellipse_sd(Xr, Yr, cx - 20 * s, body_c[1] - 4 * s, 11 * s, 30 * s)
    wing_r = P.ellipse_sd(Xr, Yr, cx + 20 * s, body_c[1] - 4 * s, 11 * s, 30 * s)
    head = P.ellipse_sd(Xr, Yr, cx, 74 * s, 17 * s, 16 * s)
    ear_l = np.maximum(np.abs((Xr - (cx - 15 * s)) * 0.9 + (Yr - 86 * s) * 0.5) - 5 * s, np.maximum(Yr - 98 * s, 80 * s - Yr))
    ear_r = np.maximum(np.abs((Xr - (cx + 15 * s)) * 0.9 - (Yr - 86 * s) * 0.5) - 5 * s, np.maximum(Yr - 98 * s, 80 * s - Yr))
    purple = P.rgb('8c7aa8')
    dark = P.rgb('6b5b8a')
    for sd, col, k in ((wing_l, dark, 1.0), (wing_r, dark, 0.92), (ear_l, dark, 1.0), (ear_r, dark, 0.92)):
        P.over(big, _full(H, W, col), P.cover(sd, ss * 0.9) * k)
    cl = np.clip((Xr - cx) / (24 * s), -1, 1)
    P.over(big, P.shade(_full(H, W, purple), 1.06 + 0.22 * (-cl)), P.cover(cloak, ss * 0.9))
    P.over(big, P.shade(_full(H, W, purple), 1.10 + 0.20 * (-np.clip((Xr - cx) / (17 * s), -1, 1))), P.cover(head, ss * 0.9))
    # the rope and two little feet at the top
    P.over(big, _full(H, W, P.rgb('4a3a4d')), P.cover(np.maximum(np.abs(Xr - cx) - 1.6 * s, np.maximum(-Yr, Yr - 18 * s)), ss * 0.9))
    for sx in (-1, 1):
        P.over(big, _full(H, W, dark), P.cover(np.sqrt((Xr - (cx + sx * 6 * s)) ** 2 + (Yr - 16 * s) ** 2) - 3.4 * s, ss * 0.9))
    # face: two eyes and a tiny mouth
    for sx in (-1, 1):
        P.over(big, _full(H, W, INKC), P.cover(np.sqrt((Xr - (cx + sx * 7 * s)) ** 2 + (Yr - 74 * s) ** 2) - 2.9 * s, ss * 0.9))
        P.over(big, _full(H, W, np.ones(3, np.float32)), P.cover(np.sqrt((Xr - (cx + sx * 7 * s + 1 * s)) ** 2 + (Yr - 73 * s) ** 2) - 0.9 * s, ss * 0.9))
    P.over(big, _full(H, W, INKC), P.cover(np.maximum(np.abs(Xr - cx) - 2.4 * s, np.abs(Yr - 82 * s) - 0.8 * s), ss * 0.9))
    im = P.premul_resize(P.to_image(big), (w, h))
    return P.warm_outline(im, radius=2), (w / 2.0, 4.0)


# ----------------------------------------------------------------------------------------------------------------------------
# front foliage: five overlapping leaf circles at alpha .5 (drawn over trunks F and G like the sketch)
# ----------------------------------------------------------------------------------------------------------------------------

def paint_foliage(which: str):
    w, h = S.scaled(S.SIZES['foliage_front'][0]), S.scaled(S.SIZES['foliage_front'][1])
    X, Y = P.grid(h, w)
    out = _blank(h, w)
    rng = np.random.default_rng({'a': 71, 'b': 83}[which])
    # five circles, sketch radii 80-110 (x K), arranged like a cluster
    base = {'a': [(0.24, 0.42, 0.25), (0.50, 0.30, 0.26), (0.77, 0.44, 0.25), (0.37, 0.70, 0.26), (0.65, 0.71, 0.25)],
            'b': [(0.26, 0.60, 0.25), (0.51, 0.34, 0.26), (0.76, 0.46, 0.25), (0.62, 0.72, 0.26), (0.30, 0.30, 0.20)]}[which]
    greens = [P.rgb('6b9a3e'), P.rgb('5f8f36'), P.rgb('7aa84a'), P.rgb('4f7a2c'), P.rgb('6b9a3e')]
    leaf = P.fbm(h, w, 5 + len(which), 12, 4)
    for i, (fx, fy, fr) in enumerate(base):
        cx, cy, r = fx * w, fy * h, fr * h
        ang = np.arctan2(Y - cy, X - cx)
        wob = 1.0 + 0.045 * np.sin(ang * 9 + i * 1.3) + 0.03 * np.sin(ang * 17 + i * 0.7) + 0.02 * np.sin(ang * 31 + i)
        d = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2) / wob
        sd = d - r
        inner = np.clip(1.0 - d / r, 0, 1)
        k = 1.0 + 0.16 * (-(X - cx) / r) * 0.8 + 0.10 * (-(Y - cy) / r) * 0.6 + 0.35 * leaf
        col = P.shade(np.broadcast_to(greens[i], (h, w, 3)), k)
        a = P.cover(sd, 1.5) * 0.5
        # a faint darker rim like the sketch's circle outline
        rim = P.line_alpha(np.abs(sd + 2.0), 3.0) * P.cover(sd, 1.5)
        col = col * (1 - rim[..., None] * 0.35) + P.rgb('3b5a2a') * (rim[..., None] * 0.35)
        P.over(out, col, a)
    return P.to_image(out), (w / 2.0, h / 2.0)


# ----------------------------------------------------------------------------------------------------------------------------
# canopy frame (screen space) and the backdrop layers
# ----------------------------------------------------------------------------------------------------------------------------

def paint_canopy():
    """Leaf frame for the top edge of the screen: a solid green mass with pale light blobs, a scalloped lower edge and hanging vines.
    2048 x 320 (NOT the table's 2560 x 400: the 2048 side limit and the budget), periodic in x, used at screen width / 2048."""
    w, h = S.SIZES['canopy_top_strip']                                                    # 2048 x 320
    X, Y = P.grid(h, w)
    out = _blank(h, w)
    rng = np.random.default_rng(91)
    base = P.rgb('7aab48')
    # vertical gradient: a touch darker at the very top, lighter toward the scallops
    top_k = 0.92 + 0.16 * (Y / h)
    leafn = P.fbm(h, w, 13, 16, 4)
    col = P.shade(np.broadcast_to(base, (h, w, 3)), top_k + 0.20 * leafn)
    # large pale light blobs near the top (the sketch's crown highlights): periodic in x
    for k in range(8):
        cx = (k + 0.5) * w / 8 + rng.uniform(-30, 30)
        cy = rng.uniform(-10, 40)
        r = rng.uniform(70, 110)
        dx = np.minimum(np.abs(X - cx), w - np.abs(X - cx))
        d = np.sqrt(dx ** 2 + (Y - cy) ** 2)
        blob = P.cover(d - r, 3.0) * 0.42
        col = col * (1 - blob[..., None]) + P.rgb('b4d684') * blob[..., None]
    # the scalloped edge: a row of circles along the bottom (radius 62), alternating two sizes, periodic
    n = 16
    edge_y = h - 62.0
    sd = np.full((h, w), 1e3, np.float32)
    for k in range(n):
        cx = (k + 0.5) * w / n
        r = 62.0 + (6.0 if k % 2 else -4.0)
        dx = np.minimum(np.abs(X - cx), w - np.abs(X - cx))
        sd = np.minimum(sd, np.sqrt(dx ** 2 + (Y - (edge_y - 8 + (4 if k % 2 else 0))) ** 2) - r)
    sd = np.minimum(sd, edge_y - 40 - Y)          # everything above the circles' tops is solid
    sd = np.where(Y < edge_y - 8, np.minimum(sd, -1.0), sd)
    cov = P.cover(sd)
    # a darker band right above the scallop edge and a thin dark outline along it
    shade_edge = 1.0 - 0.18 * P.smoothstep(24, 0, -sd) * (sd < 0)
    col = col * shade_edge[..., None]
    stroke = P.line_alpha(np.abs(sd + 1.6), 3.4)
    col = col * (1 - stroke[..., None] * 0.55) + P.rgb('3b5a2a') * (stroke[..., None] * 0.55)
    out = np.dstack([np.clip(col, 0, 1), cov])
    # vines: six thin dark-green strands hanging below the edge, each with a leaf
    vines = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    dv = ImageDraw.Draw(vines)
    for k in range(6):
        x = (k + 0.5) * w / 6 + rng.uniform(-60, 60)
        y0 = edge_y - 6
        ln = rng.uniform(110, 230)
        pts = [(x + 6 * math.sin(t * 5 + k), y0 + t * min(ln, h - y0 - 2)) for t in np.linspace(0, 1, 18)]
        dv.line(pts, fill=(78, 112, 52, 255), width=4)
        tipx, tipy = pts[-1]
        dv.polygon([(tipx, tipy), (tipx + 14, tipy - 12), (tipx + 24, tipy + 2), (tipx + 10, tipy + 8)], fill=(98, 140, 64, 255))
    vim = np.asarray(vines.filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255.0
    P.over(out, vim[..., :3], vim[..., 3])
    return P.to_image(out)


def paint_sky():
    """16 x 1024 vertical gradient cfe0a8 > 9cbf74 > 4f6f3a (top to bottom)."""
    w, h = S.SIZES['treetop_sky']
    t = np.linspace(0, 1, h, dtype=np.float32)
    stops = [(0.0, P.rgb('cfe0a8')), (0.55, P.rgb('9cbf74')), (1.0, P.rgb('4f6f3a'))]
    col = np.zeros((h, 3), np.float32)
    for k in range(3):
        col[:, k] = np.interp(t, [s[0] for s in stops], [s[1][k] for s in stops])
    rng = np.random.default_rng(3)
    arr = np.repeat(col[:, None, :], w, 1)
    arr = arr + (rng.random((h, w, 1)).astype(np.float32) - 0.5) * (1.5 / 255.0)       # a hair of dither against banding
    return Image.fromarray(np.uint8(np.clip(arr * 255 + .5, 0, 255)), 'RGB')


def paint_far():
    """2048 x 1024 far layer: nine pale trunk bars (86a866 / 6f9152), a mist band (f4f1d8), a dark ground strip with five grass tufts.  Periodic in x."""
    w, h = S.SIZES['treetop_far']
    X, Y = P.grid(h, w)
    out = _blank(h, w)
    rng = np.random.default_rng(55)
    n = 9
    xs = (np.arange(n) + 0.5) * w / n + rng.uniform(-40, 40, n)
    ws = rng.uniform(70, 150, n)
    colour = [P.rgb('86a866'), P.rgb('6f9152')]
    for i in range(n):
        dx = np.minimum(np.abs(X - xs[i]), w - np.abs(X - xs[i]))
        sd = dx - ws[i] / 2
        c = colour[i % 2]
        u = np.clip((X - xs[i]) / (ws[i] / 2), -1, 1)
        k = 1.0 + 0.10 * (-u) - 0.05 * (Y / h)
        a = P.cover(sd, 1.5) * (0.80 + 0.12 * (i % 2))
        P.over(out, P.shade(np.broadcast_to(c, (h, w, 3)), k), a)
    # the mist band: 61 % .. 85 % of the height, strongest in the middle, soft
    mid = 0.73 * h
    mist = np.exp(-(((Y - mid) / (0.085 * h)) ** 2)) * (0.50 + 0.12 * P.fbm(h, w, 7, 4, 3))
    P.over(out, _full(h, w, P.rgb('f4f1d8')), np.clip(mist, 0, 0.6))
    # the ground strip: the bottom 8 % , dark green, with grass tufts
    gy = 0.918 * h
    gnoise = P.fbm(h, w, 9, 8, 3) * 6.0
    sd_g = gy + gnoise * (Y > gy - 10) - Y
    ground = P.shade(np.broadcast_to(P.rgb('2f5a28'), (h, w, 3)), 1.0 + 0.45 * (Y - gy) / (h - gy) * -1 + 0.2 * P.fbm(h, w, 12, 20, 3))
    P.over(out, ground, P.cover(sd_g, 1.6))
    tuft = np.zeros((h, w), np.float32)
    for k in range(5):
        cx = (k + 0.5) * w / 5 + rng.uniform(-30, 30)
        for blade in range(5):
            a = math.radians(-28 + blade * 14)
            L = rng.uniform(70, 110)
            for t in np.linspace(0, 1, 24):
                px = cx + math.sin(a) * L * t * (1.0 + 0.2 * t)
                py = gy - 8 - math.cos(a) * L * t
                dx = np.minimum(np.abs(X - px), w - np.abs(X - px))
                dd = np.sqrt(dx ** 2 + (Y - py) ** 2)
                tuft = np.maximum(tuft, P.cover(dd - (6.0 * (1 - t) + 1.2), 1.2))
    P.over(out, _full(h, w, P.rgb('3f7a34')), tuft)
    return P.to_image(out)


def paint_shadow_soft():
    """A soft contact shadow 256 x 128 (an ellipse of 2b2340 at 38 % with a gaussian edge) the engine scales per object."""
    w, h = S.SIZES['shadow_soft']
    X, Y = P.grid(h, w)
    d = np.sqrt(((X - w / 2) / (w * 0.40)) ** 2 + ((Y - h / 2) / (h * 0.40)) ** 2)
    a = np.clip(1.0 - d, 0, 1) ** 0.9
    a = np.clip(a * 1.6, 0, 1) * 0.38
    out = np.dstack([np.broadcast_to(INKC, (h, w, 3)), a.astype(np.float32)])
    return P.to_image(out), (w / 2.0, h / 2.0)


if __name__ == '__main__':
    import sys
    outdir = sys.argv[1]
    for n in S.PENNANTS:
        for f in (0, 1):
            im, pv = paint_pennant(n, f)
            im.save(f'{outdir}/pennant_{n}_{f}.png')
    paint_lantern()[0].save(f'{outdir}/lantern_hang.png')
    paint_lamp_door()[0].save(f'{outdir}/lamp_door.png')
    for f in range(3):
        paint_flame(f)[0].save(f'{outdir}/fire_flame_{f}.png')
    for f in range(2):
        paint_bat(f)[0].save(f'{outdir}/bat_hang_{f}.png')
    for wch in 'ab':
        paint_foliage(wch)[0].save(f'{outdir}/foliage_front_{wch}.png')
    paint_canopy().save(f'{outdir}/canopy_top_strip.png')
    paint_sky().save(f'{outdir}/treetop_sky.png')
    paint_far().save(f'{outdir}/treetop_far.png')
    paint_shadow_soft()[0].save(f'{outdir}/shadow_soft.png')
