"""Model builders of the treetop city's 3D props (V5 tasks 2 and 4): the round huts, the Torvet stall, fire pit, tub halves, planters, log stack,
notice board, seed basket and the bat house.  Same geometry vocabulary as environment/props_traetoppen.py (PM: ellipsoids, tubes, boxes), metres,
Y up, azimuth 45 (the viewer looks along (-x, -z): +x faces screen right-down, +z screen left-down, so the FRONT of a prop is the direction (1, 0, 1)).

Proportions are written in SKETCH pixels of the Miljoeer v2 sheet and converted (horizontal: x K / 87.074, vertical: x K / (87.074 cos 36));
bake3d.fit then scales the model so the cropped sprite is the work order's size.  Shapes tagged with `mark_emit` are the lit door and windows of the
night layer (additive, like A1's house tiers).
"""
from __future__ import annotations
import math
import sys
from pathlib import Path
import numpy as np
from scipy.spatial.transform import Rotation

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / 'core'))
import artpaths                       # noqa: E402,F401
import geometry as geo                # noqa: E402
import props_traetoppen as pp         # noqa: E402
from props_traetoppen import PM, PropSpec, spec, WOOD, T   # noqa: E402
import city_spec as S                 # noqa: E402

PPM = 256 / (2 * 1.47)
COS = math.cos(math.radians(36.0))
FRONT = 45.0                          # azimuth (deg, in the xz plane: x = cos, z = sin) of the direction that faces the viewer


def hm(s: float) -> float:
    """horizontal sketch px -> metres"""
    return s * S.K_REF / PPM


def vm(s: float) -> float:
    """vertical sketch px -> metres"""
    return s * S.K_REF / (PPM * COS)


def rgbh(c: str):
    return np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], float)


def tint(c: str, k: float) -> str:
    v = np.clip(rgbh(c) * k, 0, 255).astype(int)
    return '%02X%02X%02X' % tuple(v)


class CM(PM):
    """PM with a hook that tags the LAST added shape as emissive (lit at night)."""

    def mark_emit(self, light: str) -> None:
        s = self.m.groups[self.g].shapes[-1]
        s.emit = True
        s.emit_color = light


def ring_points(r: float, y: float, n: int = 56, a0: float = 0.0, a1: float = 2 * math.pi, cx: float = 0.0, cz: float = 0.0):
    t = np.linspace(a0, a1, n)
    return np.c_[cx + r * np.cos(t), np.full(n, y), cz + r * np.sin(t)]


# --------------------------------------------------------------------------------------------------------------------------
# huts: round plank wall + valance + conical straw roof with ribs + arched door + two round windows (lit at night)
# --------------------------------------------------------------------------------------------------------------------------
WALL_A, WALL_B = 'D2A46C', 'C4975F'


def hut(cls: dict, roof_hex: str, name: str, raadhus: bool = False) -> PropSpec:
    """cls = a HUT_CLASSES row (or HUT_RAADHUS).  The proportions are solved from the TARGET sprite size so the fit stays near 1:
    eave radius = half the sprite width, wall radius 80 % of it, the visible wall band 22 % of the sprite height (the sketch's 23 %), the apex
    where the height says.  (The sketch draws the wall base flatter than a true 36 degree ellipse; the table height already says so.)"""
    W, H = S.scaled(cls['size'][0]), S.scaled(cls['size'][1])
    sv = math.sin(math.radians(S.ELEV))
    Re = (W - 7) / 2.0
    Rw = 0.80 * Re
    band = 0.22 * H
    he = band + sv * (Re - Rw)                      # screen px of the eave plane above the wall base centre
    apex = H - 4 - sv * Rw                          # screen px of the apex above the base centre
    ppv = PPM * COS                                 # screen px per metre of true vertical height
    wr, rr = Rw / PPM, Re / PPM
    wh = he / ppv + 0.08
    rh = (apex - he) / ppv
    pm = CM()
    n_st = int(max(16, round(2 * math.pi * wr / 0.30)))
    sw = 2 * math.pi * wr / n_st
    # plinth: a low stone ring the wall stands on
    pm.cyl((0, 0, 0), (0, 0.09, 0), wr + 0.05, wr + 0.05, '8A8494', 'stone', sides=48, n=2)
    # wall: vertical staves, two alternating tones (the sketch's plank wall), soft shaded
    for i in range(n_st):
        th = 2 * math.pi * (i + 0.5) / n_st
        c = (math.cos(th) * (wr - 0.04), wh / 2 + 0.05, math.sin(th) * (wr - 0.04))
        pm.box(c, (sw * 1.03, wh - 0.05, 0.14), WALL_A if i % 2 == 0 else WALL_B, 'soft', power=.34, rot=(0, 90 - math.degrees(th), 0), seg=14, rings=8)
    # valance: a scalloped cloth under the eave
    n_v = n_st * 2
    for i in range(n_v):
        th = 2 * math.pi * (i + 0.5) / n_v
        c = (math.cos(th) * (wr + 0.02), wh - 0.10, math.sin(th) * (wr + 0.02))
        pm.ell(c, (sw * 0.30, 0.12, 0.05), 'EFD9A0' if i % 2 == 0 else 'B07C3C', 'soft', seg=12, rings=8, rot=(0, 90 - math.degrees(th), 0))
    # door (on the front), a frame and a round step; handle
    a = math.radians(FRONT)
    dx, dz = math.cos(a), math.sin(a)
    dh = 0.34 * wh
    dw = dh * 0.66
    pm.ell((dx * (wr + 0.005), dh, dz * (wr + 0.005)), (dw + 0.07, dh + 0.06, 0.10), '5E3B20', 'soft', power=.55, rot=(0, 90 - FRONT, 0), seg=18, rings=12)
    pm.ell((dx * (wr + 0.045), dh - 0.01, dz * (wr + 0.045)), (dw, dh, 0.08), '7A4E2D' if not raadhus else '6B4A7A', 'soft', power=.55, rot=(0, 90 - FRONT, 0), seg=18, rings=12)
    pm.mark_emit('E89A40')
    pm.ell((dx * (wr + 0.12) - dz * dw * 0.55, dh * 0.95, dz * (wr + 0.12) + dx * dw * 0.55), (.035, .035, .03), 'E9C06B', 'soft', seg=8, rings=6)
    pm.ell((dx * (wr + 0.30), 0.04, dz * (wr + 0.30)), (0.34, 0.05, 0.22), '9A9AA6', 'stone', power=.5, rot=(0, 90 - FRONT, 0), seg=14, rings=8)
    # two round windows: a dark frame and a pane that glows at night
    for off in (-50, 50):
        wa = math.radians(FRONT + off)
        wx, wz = math.cos(wa), math.sin(wa)
        wy = wh * 0.44
        pm.ell((wx * (wr + 0.01), wy, wz * (wr + 0.01)), (0.25, 0.27, 0.07), '5E3B20', 'soft', rot=(0, 90 - FRONT - off, 0), seg=16, rings=10)
        pm.ell((wx * (wr + 0.05), wy, wz * (wr + 0.05)), (0.19, 0.21, 0.04), 'D9C58A', 'soft', rot=(0, 90 - FRONT - off, 0), seg=16, rings=10)
        pm.mark_emit('FFE08F')
    # roof: a cone with ribs, a lip ring and a finial
    y0 = wh - 0.08
    pm.cyl((0, y0, 0), (0, y0 + rh, 0), rr, 0.03, roof_hex, 'straw', sides=56, n=10)
    rib = tint(roof_hex, 0.84)
    n_r = 16 if rr < 2.0 else 20
    for i in range(n_r):
        th = 2 * math.pi * (i + 0.25) / n_r
        pts = []
        for t in np.linspace(0.02, 0.97, 9):
            rad = rr * (1 - t) * 1.012 + 0.012
            pts.append((math.cos(th) * rad, y0 + rh * t, math.sin(th) * rad))
        pm.tube(np.array(pts), np.linspace(0.022, 0.008, 9), rib, 'soft', sides=6)
    pm.tube(ring_points(rr * 0.992, y0 + 0.035, 72), 0.062, tint(roof_hex, 0.64), 'straw', sides=10)
    if raadhus:
        pm.tube(ring_points(rr * 0.80, y0 + rh * 0.20, 64), 0.05, 'E0B040', 'soft', sides=8)
    pm.ell((0, y0 + rh + 0.03, 0), (.11, .11, .11), '7A4E2D', 'soft', seg=14, rings=10)
    return spec(pm, name, shadow=None)


# --------------------------------------------------------------------------------------------------------------------------
# the Torvet stall: P22's market_stall recoloured (striped awning e3c372, cream)
# --------------------------------------------------------------------------------------------------------------------------
def stall() -> PropSpec:
    import props_town as pt
    sp = pt.market_stall(awning=('E3C372', 'F6E9C4'), wares='veg', name='market_stall_traetoppen')
    sp.glow = None
    sp.shadow = None
    return sp


# --------------------------------------------------------------------------------------------------------------------------
# fire pit: a ring of stones and crossed logs (the flame is an additive painted layer)
# --------------------------------------------------------------------------------------------------------------------------
def fire_pit() -> PropSpec:
    pm = PM()
    R = 1.0
    for i in range(12):
        a = 2 * math.pi * (i + 0.5) / 12
        c = (math.cos(a) * R, 0.15, math.sin(a) * R)
        pm.ell(c, (0.26, 0.17, 0.21), ('8E8E9C', 'A4A4B2', '7C7C8A')[i % 3], 'stone', power=.8, rot=(0, math.degrees(-a), 0), seg=18, rings=12)
    for i in range(9):                                                                                # a second, narrower course
        a = 2 * math.pi * (i + 0.2) / 9
        c = (math.cos(a) * (R - 0.03), 0.42, math.sin(a) * (R - 0.03))
        pm.ell(c, (0.24, 0.15, 0.20), ('9A9AA6', '8E8E9C', 'ADADBA')[i % 3], 'stone', power=.8, rot=(0, math.degrees(-a), 0), seg=18, rings=12)
    pm.ell((0, 0.06, 0), (R * 0.9, 0.05, R * 0.9), '3E3A44', 'soft', seg=30, rings=6)                 # the ash bed
    for k, (ay, ln) in enumerate(((20, 0.95), (95, 0.9), (160, 0.85), (-50, 0.8))):
        pm.cyl((-ln * 0.5, 0.20, 0.0), (ln * 0.5, 0.20, 0.0), 0.085, 0.07, '6B4126', 'bark', sides=10, n=3, rot=(0, ay, 8 + 4 * k), center=(0, 0.20, 0))
    for k in range(3):
        pm.cyl((-0.3, 0.40, 0.0), (0.3, 0.40, 0.0), 0.07, 0.06, '4A2F1E', 'bark', sides=10, n=3, rot=(0, 60 * k, 20))
    pm.ell((0, 0.28, 0), (0.35, 0.10, 0.35), 'D9602B', 'soft', seg=18, rings=8)                      # glowing coals
    return spec(pm, 'fire_pit', shadow=None)


# --------------------------------------------------------------------------------------------------------------------------
# the tub in two halves (Sofus sits BETWEEN them): the back half = far staves + far rim + the far half of the water, the front half = the near ones
# --------------------------------------------------------------------------------------------------------------------------
TUB_R = 1.42
TUB_H = 0.42
TUB_WATER = 0.25


def _cam_dot(c):
    return c[0] * math.cos(math.radians(FRONT)) + c[2] * math.sin(math.radians(FRONT))


def _add_filtered(pm, v, f, color, pat, keep):
    cen = v[f].mean(axis=1)
    sel = np.array([keep(c) for c in cen])
    if sel.any():
        pm._add(v, f[sel], color, pat)


def tub(half: str) -> PropSpec:
    back = half == 'back'
    pm = PM()
    keep = (lambda c: _cam_dot(c) < 0.0) if back else (lambda c: _cam_dot(c) >= 0.0)
    n_st = 30
    sw = 2 * math.pi * TUB_R / n_st
    # the far half is seen from INSIDE: only the part above the water shows, so its staves start at the water level (the near half is the full wall)
    y0 = TUB_WATER - 0.05 if back else 0.0
    for i in range(n_st):
        th = 2 * math.pi * (i + 0.5) / n_st
        c = np.array([math.cos(th) * (TUB_R - 0.05), (y0 + TUB_H) / 2, math.sin(th) * (TUB_R - 0.05)])
        if not keep(c):
            continue
        pm.box(tuple(c), (sw * 1.04, TUB_H - y0, 0.13), 'B98657' if i % 2 == 0 else 'A8794B', 'soft', power=.32, rot=(0, 90 - math.degrees(th), 0), seg=12, rings=8)
    # bands (hoops) around the tub: two iron-brown rings (the back half only keeps the one above the water)
    for yb in ((TUB_H - 0.16,) if back else (0.14, TUB_H - 0.16)):
        pts = ring_points(TUB_R + 0.02, yb, 64)
        v, f = geo.tube(pts, 0.035, 8)
        _add_filtered(pm, v, f, '5E3B20', 'soft', keep)
    # rim: a thick lip all around
    v, f = geo.tube(ring_points(TUB_R, TUB_H, 80), 0.085, 12)
    _add_filtered(pm, v, f, 'D6A56A', 'soft', keep)
    # water: a flat disc below the rim
    v, f = geo.ellipsoid((0, TUB_WATER, 0), (TUB_R - 0.10, 0.025, TUB_R - 0.10), 40, 6, 1.0, 0.0)
    _add_filtered(pm, v, f, 'A9DCE8', 'glassglow', keep)
    return spec(pm, 'bath_tub_' + half, shadow=None)


# --------------------------------------------------------------------------------------------------------------------------
# planters: a raised box of boards with soil and herbs or berries
# --------------------------------------------------------------------------------------------------------------------------
def planter(kind: str = 'herb') -> PropSpec:
    pm = PM()
    L, h = 1.32, 0.34
    for sx, sz, sxs, szs in ((0, L / 2, L, 0.09), (0, -L / 2, L, 0.09), (L / 2, 0, 0.09, L), (-L / 2, 0, 0.09, L)):
        pm.box((sx, h / 2, sz), (sxs, h, szs) if sxs > szs else (sxs, h, szs), 'B98657', 'plank', power=.3)
    for sx, sz in ((-L / 2, -L / 2), (L / 2, -L / 2), (-L / 2, L / 2), (L / 2, L / 2)):
        pm.box((sx, h / 2 + 0.03, sz), (0.12, h + 0.06, 0.12), '7A4E2D', 'bark', power=.3)
    pm.box((0, h * 0.78, 0), (L - 0.1, 0.07, L - 0.1), '5B3A26', 'soil', power=.4)
    rng = np.random.default_rng(31 if kind == 'herb' else 37)
    if kind == 'herb':
        spots = [(-0.38, -0.30), (0.05, -0.38), (0.4, -0.2), (-0.3, 0.2), (0.15, 0.1), (0.42, 0.38), (-0.05, 0.42)]
        for i, (x, z) in enumerate(spots):
            col = ('6FAA46', '97C95E', '4F8A38')
            pm.clump((x, h + 0.22, z), 0.20 + 0.04 * (i % 3), col, 'leaf', n=4, seed=i + 5, squash=.9)
    else:
        spots = [(-0.30, -0.18), (0.25, -0.25), (0.05, 0.30)]
        for i, (x, z) in enumerate(spots):
            pm.clump((x, h + 0.30, z), 0.30, ('5C9A52', '7CBE5E', '3F7A3A'), 'leaf', n=5, seed=i + 9, squash=.85)
            for j in range(7):
                a = rng.uniform(0, 6.28)
                e = rng.uniform(0.0, 0.9)
                pm.ell((x + math.cos(a) * math.cos(e) * 0.30, h + 0.30 + math.sin(e) * 0.22, z + math.sin(a) * math.cos(e) * 0.30), (.05, .05, .05), 'B3436B', 'soft', seg=10, rings=8)
    return spec(pm, 'planter_box' + ('' if kind == 'herb' else '_berry'), shadow=None)


# --------------------------------------------------------------------------------------------------------------------------
# Brumme's timber, the Raadhus notice board, Hoppe's seed basket
# --------------------------------------------------------------------------------------------------------------------------
def log_stack() -> PropSpec:
    """Brumme's timber: two courses of logs (3 + 2) lying almost along the SCREEN-horizontal direction (yawed 22 degrees from x, so the cut ends at +x show to the right)."""
    pm = PM()
    r = 0.27
    rows = [[-0.60, 0.0, 0.60], [-0.30, 0.30]]
    L = 2.75
    for ri, row in enumerate(rows):
        for z in row:
            y = r + ri * r * 1.66
            pm.cyl((-L / 2, y, z), (L / 2, y, z), r, r * 0.96, '8C5A32' if (ri + int(z * 10)) % 2 else '7A4E2D', 'bark', sides=18, n=4)
            pm.ell((L / 2 + 0.005, y, z), (0.02, r * 0.97, r * 0.97), 'E9D3A3', 'soft', seg=14, rings=10)
            pm.ell((L / 2 + 0.02, y, z), (0.012, r * 0.55, r * 0.55), 'D6BB84', 'soft', seg=14, rings=10)
            pm.ell((L / 2 + 0.03, y, z), (0.01, r * 0.18, r * 0.18), 'B89A64', 'soft', seg=10, rings=8)
    _yaw(pm.m, 22.0)
    return spec(pm, 'log_stack', shadow=None)


def notice_board() -> PropSpec:
    pm = PM()
    for sx in (-0.62, 0.62):
        pm.cyl((sx, 0, 0), (sx, 1.9, 0), 0.07, 0.065, '7A4E2D', 'bark', sides=10, n=4)
    pm.box((0, 1.28, 0.02), (1.5, 1.0, 0.10), 'C9925A', 'plank', power=.28)
    pm.box((0, 1.28, 0.075), (1.36, 0.86, 0.04), 'E3C788', 'soft', power=.3)
    pm.box((0, 1.82, 0.0), (1.78, 0.10, 0.20), 'A8693B', 'soft', power=.3)                       # a little peaked cap
    pm.box((0, 1.92, 0.0), (1.5, 0.10, 0.17), 'B5693F', 'roof', power=.3)
    rng = np.random.default_rng(3)
    notes = [(-0.42, 1.42, 'FBF5E6', .38, .34), (0.0, 1.50, 'F6E3A0', .34, .36), (0.40, 1.38, 'F2C9D6', .36, .3),
             (-0.35, 1.03, 'CFE6F2', .34, .3), (0.1, 1.08, 'FBF5E6', .38, .34), (0.46, 1.06, 'DDEEC4', .3, .28)]
    for x, y, col, w, h in notes:
        pm.box((x, y, 0.11), (w, h, 0.02), col, 'soft', power=.3, rot=(0, 0, rng.uniform(-6, 6)))
        pm.ell((x, y + h * 0.40, 0.125), (.025, .025, .02), 'B3436B', 'soft', seg=8, rings=6)
    sp = spec(pm, 'notice_board', shadow=None)
    _yaw(pm.m, FRONT)
    return sp


def _yaw(m, deg):
    R = Rotation.from_euler('y', deg, degrees=True).as_matrix()
    for g in m.groups:
        for s in g.shapes:
            s.vertices = s.vertices @ R.T


def seed_basket() -> PropSpec:
    pm = PM()
    pm.cyl((0, 0.0, 0), (0, 0.42, 0), 0.40, 0.55, 'C9A052', 'straw', sides=24, n=5)
    pm.tube(ring_points(0.555, 0.42, 40), 0.045, 'B88A3E', 'straw', sides=8)
    pm.ell((0, 0.38, 0), (0.50, 0.05, 0.50), '5B3A26', 'soil', seg=24, rings=6)
    for i, (x, z, ay) in enumerate(((-0.18, -0.06, 20), (0.08, 0.14, 110), (0.2, -0.12, 200), (-0.05, 0.2, 70))):
        pm.ell((x, 0.56, z), (0.075, 0.20, 0.075), 'F08A3C', 'soft', seg=12, rings=10, rot=(10, ay, 25))
        pm.clump((x - 0.02, 0.78, z), 0.075, ('6FAA46', '97C95E', '4F8A38'), 'leaf', n=2, seed=i + 1, squash=1.2)
    pm.curve([(-0.5, 0.45, 0), (-0.38, 0.92, 0), (0.38, 0.92, 0), (0.5, 0.45, 0)], 0.035, 0.035, 'B88A3E', 'straw', 8, n=16)
    sp = spec(pm, 'seed_basket', shadow=None)
    return sp


# --------------------------------------------------------------------------------------------------------------------------
# the bat house: a staved drum with a dark door slot and a gold lamp on top, a zigzag band, a cone below ending in a short rope
# --------------------------------------------------------------------------------------------------------------------------
BAT_DRUM = '8C7AA8'
BAT_DRUM_B = '7E6C9C'
BAT_CONE = '6B5B8A'


def bat_house() -> PropSpec:
    pm = PM()
    Rd, Hd, Hc = 1.0, 1.35, 1.18
    ytip = 0.0
    y_cone_top = ytip + Hc
    y_top = y_cone_top + Hd
    # the cone (upside down): radius Rd*1.05 at the drum, 0.03 at the tip; ribs; a short rope under the tip
    pm.cyl((0, ytip, 0), (0, y_cone_top, 0), 0.03, Rd * 1.08, BAT_CONE, 'soft', sides=48, n=8)
    for i in range(14):
        th = 2 * math.pi * (i + 0.5) / 14
        pts = [(math.cos(th) * Rd * 1.08 * t, ytip + Hc * t, math.sin(th) * Rd * 1.08 * t) for t in np.linspace(0.05, 0.98, 8)]
        pm.tube(np.array(pts), 0.018, tint(BAT_CONE, 0.7), 'soft', sides=6)
    pm.cyl((0, ytip - 0.22, 0), (0, ytip + 0.05, 0), 0.025, 0.025, '4A3A4D', 'straw', sides=8, n=2)
    # the drum: staves, a zigzag band, a flat top with a lid ring
    n_st = 26
    sw = 2 * math.pi * Rd / n_st
    for i in range(n_st):
        th = 2 * math.pi * (i + 0.5) / n_st
        c = (math.cos(th) * (Rd - 0.04), y_cone_top + Hd / 2, math.sin(th) * (Rd - 0.04))
        pm.box(c, (sw * 1.03, Hd, 0.12), BAT_DRUM if i % 2 == 0 else BAT_DRUM_B, 'soft', power=.34, rot=(0, 90 - math.degrees(th), 0), seg=12, rings=8)
    for i in range(26):
        th = 2 * math.pi * (i + 0.5) / 26
        pm.ell((math.cos(th) * (Rd + 0.01), y_cone_top + Hd * 0.38 + (0.07 if i % 2 else -0.07), math.sin(th) * (Rd + 0.01)), (sw * 0.55, 0.045, 0.04), '5F4F7E', 'soft', seg=10, rings=6, rot=(0, 90 - math.degrees(th), 0))
    pm.tube(ring_points(Rd + 0.01, y_cone_top + 0.02, 64), 0.05, '6B5B8A', 'soft', sides=8)
    pm.tube(ring_points(Rd + 0.01, y_top - 0.02, 64), 0.05, '6B5B8A', 'soft', sides=8)
    pm.ell((0, y_top + 0.01, 0), (Rd * 0.96, 0.08, Rd * 0.96), '9A88B8', 'soft', seg=36, rings=6)
    # the door: a dark arched slot and a gold lamp beside it, on the front
    a = math.radians(FRONT)
    dx, dz = math.cos(a), math.sin(a)
    pm.ell((dx * (Rd + 0.02), y_cone_top + Hd * 0.66, dz * (Rd + 0.02)), (0.20, 0.30, 0.06), '2B2340', 'soft', power=.55, rot=(0, 90 - FRONT, 0), seg=16, rings=10)
    la = a + math.radians(26)
    pm.ell((math.cos(la) * (Rd + 0.03), y_cone_top + Hd * 0.62, math.sin(la) * (Rd + 0.03)), (0.075, 0.075, 0.05), 'F2C14E', 'glassglow', rot=(0, 90 - math.degrees(la), 0), seg=12, rings=8)
    sp = spec(pm, 'bat_house_hanging', shadow=None)
    sp.tip_y = ytip
    return sp
