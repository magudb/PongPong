"""Platform discs of the treetop city (V5 task 1): radial planks (#c9925a, joints #a06a3a) on an ellipse of ratio .5776 and a 16 px rim skirt.

The disc has NO trunk hole (the trunk covers it).  Sprite = exactly the table size, pivot = the ellipse centre of the TOP surface.  The sprite is
painted analytically at final resolution (signed distances for the AA, periodic noise for the grain), then given the pack's warm outline.
"""
from __future__ import annotations
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import paint as P
import city_spec as S

PLANK = P.rgb('c9925a')
JOINT = P.rgb('a06a3a')
RIM_COL = P.rgb('8c5a30')
RIM_DARK = P.rgb('6e4626')
NAIL = P.rgb('7a4e2d')


def paint_disc(r: int, outline: bool = True):
    d = S.DISCS[r]
    W, H = S.scaled(d['size'][0]), S.scaled(d['size'][1])
    inset = 2.6
    rx = W / 2.0 - inset
    ry = rx * d['ry'] / d['rx']
    cx = W / 2.0
    cy = inset + ry
    depth = H - inset - (cy + ry)                      # rim skirt depth in px (about 16 sketch px x K)
    X, Y = P.grid(H, W)
    sd_top = P.ellipse_sd(X, Y, cx, cy, rx, ry)
    cov_top = P.cover(sd_top)
    # the rim: the top ellipse swept straight down by `depth`; only the front half shows below the top surface
    sd_low = P.ellipse_sd(X, Y, cx, cy + depth, rx, ry)
    sd_strip = np.maximum(np.maximum(np.abs(X - cx) - rx, cy - Y), Y - (cy + depth))
    sd_sweep = np.minimum(sd_low, sd_strip)
    cov_sweep = P.cover(sd_sweep)
    cov_all = np.maximum(cov_top, cov_sweep)
    rim_mask = np.clip(cov_all - cov_top, 0, 1)

    u = (X - cx) / rx
    v = (Y - cy) / ry
    r_n = np.sqrt(u * u + v * v)
    ang = np.arctan2(v, u)                              # world angle on the disc plane
    # ---- top surface: three rings of radial planks, staggered
    edges = [0.0, 0.34, 0.66, 1.0]
    counts = d['planks']
    col = np.zeros((H, W, 3), np.float32)
    ring = np.clip(np.searchsorted(edges, r_n, side='right') - 1, 0, 2)
    plank_j = np.zeros((H, W), np.int64)
    across = np.zeros((H, W), np.float32)
    rng = np.random.default_rng(1000 + r)
    tones = [rng.uniform(-.07, .06, n) for n in counts]
    offsets = [0.0, math.pi / counts[1], 0.5 * math.pi / counts[2]]
    tone = np.zeros((H, W), np.float32)
    for i in range(3):
        m = ring == i
        step = 2 * math.pi / counts[i]
        a = np.mod(ang[m] + offsets[i] + 2 * math.pi, 2 * math.pi) / step
        j = np.floor(a).astype(np.int64)
        j = np.clip(j, 0, counts[i] - 1)
        plank_j[m] = j + 100 * i
        across[m] = (a - np.floor(a)).astype(np.float32)
        tone[m] = tones[i][j]
    grain_tex = P.fbm(256, 256, 7 + r, base=6, octaves=3)
    fine_tex = P.periodic_noise(256, 256, 64, 64, 11 + r)
    # grain runs along the radius: sample with x from the across coordinate (fine), y from the radius (slow)
    gx = across * 90.0 + plank_j * 31.0
    gy = r_n * rx / 7.0 + plank_j * 17.0
    g1 = P.sample(grain_tex, gx, gy)
    g2 = P.sample(fine_tex, gx * 2.3, gy * 0.35)
    k = 1.0 + tone + 0.14 * g1 + 0.05 * g2
    # soft key light from the upper left on the flat deck: a very gentle ramp, plus a catch-light along the outer edge
    k = k * (1.0 + 0.045 * (-u * 0.7 - v * 0.8))
    k = k * (1.0 + 0.10 * P.smoothstep(0.955, 0.995, r_n) * (1 - P.smoothstep(0.995, 1.0, r_n)))
    top_rgb = P.shade(np.broadcast_to(PLANK, (H, W, 3)), k)
    # ---- joints: radial seams of each ring and the two ring seams, constant screen width
    seam = np.zeros((H, W), np.float32)
    for i in range(3):
        n = counts[i]
        step = 2 * math.pi / n
        a_local = np.mod(ang + offsets[i] + 2 * math.pi, step)       # angle from the previous seam
        d_ang = np.minimum(a_local, step - a_local)
        # distance in screen px of a point from the ray of its nearest seam: |g| / |grad g|
        th = ang - np.where(a_local < step - a_local, a_local, -(step - a_local))
        g = u * np.sin(th) - v * np.cos(th)
        gr = np.sqrt((np.sin(th) / rx) ** 2 + (np.cos(th) / ry) ** 2) + 1e-9
        dist = np.abs(g) / gr
        in_ring = (r_n >= edges[i]) & (r_n < edges[i + 1])
        seam = np.maximum(seam, P.line_alpha(dist, 1.7) * in_ring)
    for e in edges[1:3]:
        gg = r_n - e
        gr = np.sqrt((u / np.maximum(r_n, 1e-6) / rx) ** 2 + (v / np.maximum(r_n, 1e-6) / ry) ** 2) + 1e-9
        seam = np.maximum(seam, P.line_alpha(np.abs(gg) / gr, 2.0))
    top_rgb = top_rgb * (1 - seam[..., None] * 0.82) + JOINT[None, None, :] * (seam[..., None] * 0.82)
    # ---- nails: two per plank end on the outer ring and the middle ring
    img_nail = Image.new('L', (W, H), 0)
    dn = ImageDraw.Draw(img_nail)
    for i, rr in ((2, 0.955), (1, 0.675), (0, 0.345)):
        n = counts[i]
        for jx in range(n):
            for t in (0.22, 0.78):
                a0 = (jx + t) * 2 * math.pi / n - offsets[i]
                px = cx + rx * rr * math.cos(a0)
                py = cy + ry * rr * math.sin(a0)
                rad = 2.6
                dn.ellipse((px - rad, py - rad * 0.8, px + rad, py + rad * 0.8), fill=255)
    nail = np.asarray(img_nail, np.float32) / 255.0
    nail = np.asarray(Image.fromarray(np.uint8(nail * 255)).filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255.0
    top_rgb = top_rgb * (1 - nail[..., None] * 0.55) + NAIL[None, None, :] * (nail[..., None] * 0.55)
    # ---- rim skirt: cylinder shading (left lighter), vertical staves that crowd toward the sides, a top highlight and a dark lower edge
    yy = np.clip((Y - (cy + ry * np.sqrt(np.clip(1 - u * u, 0, 1)))) / max(depth, 1.0), 0, 1)   # 0 at the top lip .. 1 at the bottom
    xs = np.clip(u, -0.999, 0.999)
    shade_c = 0.80 + 0.34 * (-xs) * 0.9 + 0.04
    kr = shade_c * (1.10 - 0.30 * yy)
    kr = kr * (1.0 + 0.10 * P.smoothstep(0.12, 0.0, yy))
    stave = np.zeros((H, W), np.float32)
    n_staves = 44 if r != 306 else 62
    th_s = np.arccos(np.clip(u, -1, 1))
    for kst in range(n_staves + 1):
        xk = cx + rx * math.cos(kst * math.pi / n_staves)
        stave = np.maximum(stave, P.line_alpha(np.abs(X - xk), 1.5))
    bark_tex = P.fbm(256, 256, 31 + r, base=5, octaves=3)
    kr = kr * (1 + 0.16 * P.sample(bark_tex, X * 1.0 + 40, Y * 6.0))
    rim_rgb = P.shade(np.broadcast_to(RIM_COL, (H, W, 3)), kr)
    rim_rgb = rim_rgb * (1 - stave[..., None] * 0.38) + RIM_DARK[None, None, :] * (stave[..., None] * 0.38)
    groove = P.line_alpha(np.abs(yy - 0.52) * depth, 1.6)
    rim_rgb = rim_rgb * (1 - groove[..., None] * 0.30)
    # ---- compose: top over rim
    out = np.zeros((H, W, 4), np.float32)
    P.over(out, rim_rgb, rim_mask * np.clip(cov_sweep, 0, 1))
    P.over(out, top_rgb, cov_top)
    # contour where the top surface meets the rim (the front half only) and a soft dark line under the lip
    contour = P.line_alpha(np.abs(sd_top), 2.3) * (Y > cy - 2) * (cov_all > 0.5)
    lip_rgb = np.broadcast_to(RIM_DARK, (H, W, 3))
    P.over(out, lip_rgb, contour * 0.55)
    im = P.to_image(out)
    if outline:
        im = P.warm_outline(im)
    return im, (W / 2.0, cy)


if __name__ == '__main__':
    import sys, time
    outdir = sys.argv[1]
    for r in S.DISCS:
        t0 = time.time()
        im, piv = paint_disc(r)
        im.save(f'{outdir}/platform_disc_{r}.png')
        print(r, im.size, piv, f'{time.time() - t0:.1f}s')
