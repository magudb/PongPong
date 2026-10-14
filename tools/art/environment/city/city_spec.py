#!/usr/bin/env python3
"""The numbers of the Traetoppen city art (package V5-art-city): ONE table, ONE scale constant.

Everything the bakers, the installer, the validator and the contact sheets need to agree on lives here, in sketch pixels of
`docs/Traetoppen Style Guide Review/Traetoppen Miljoeer v2.dc.html` (viewBox 1800 x 1240) and in the world pixels at the reference
scale K = 3.0 (the sizes of the work order).  The scale is NOT a literal in this file: it is read from `lua/config/traetoppen.lua`
(`scale = 3.0`, the ONE data constant of the city, V3's file), so a change of K there rescales the whole set linearly:

    size(id, K) = round(size_at_3(id) * K / 3.0)        (the tile height of the bark and the screen-space frames stay as they are)

  python tools/art/environment/city/city_spec.py [--k 2.4]      print the table (id, w x h, uses, MB RGBA8 + mipmaps) and the totals

Sizes are the sprite sizes INCLUDING the 2 px pack outline and EXCLUDING any baked shadow (the engine draws the shadows), within 2 px of the
work order's table (V5-art-city tasks 1-5).
"""
from __future__ import annotations
import math, re, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
LUA = REPO / 'lua' / 'config' / 'traetoppen.lua'
K_REF = 3.0                       # the scale the work order's table is written for
SQ = 0.5776                       # ellipse ratio of every ground circle of the sketch (sin 35.26 degrees)
RIM = 16.0                        # rim skirt thickness of every platform, sketch px
PX_PER_M = 256 / (2 * 1.47)       # 87.074 px per metre, the contract scale of every sprite
ELEV = 36.0
MIP = 4.0 / 3.0                   # mipmap overhead factor of the memory estimate


def read_k(path: Path = LUA) -> float:
    """`scale = 3.0` of lua/config/traetoppen.lua (top-level table traetoppen)."""
    m = re.search(r'^\s*scale\s*=\s*([0-9]+(?:\.[0-9]+)?)', path.read_text(), re.M)
    if not m:
        raise SystemExit(f'city_spec: no `scale = ...` in {path}')
    return float(m.group(1))


K = read_k()


def scaled(v, k: float | None = None) -> int:
    return int(round(v * (K if k is None else k) / K_REF))


# ----------------------------------------------------------------------------------------------------------------------------
# platforms: id = the sketch radius rx (rounded); (width, height) px at K=3, sketch rx / ry
# ----------------------------------------------------------------------------------------------------------------------------
DISCS = {
    171: dict(size=(1029, 642), rx=171.5, ry=99.0, uses=1, planks=(10, 17, 26)),
    184: dict(size=(1102, 684), rx=183.7, ry=106.1, uses=4, planks=(10, 18, 28)),
    196: dict(size=(1176, 726), rx=196.0, ry=113.1, uses=2, planks=(11, 19, 30)),
    306: dict(size=(1837, 1108), rx=306.2, ry=176.8, uses=1, planks=(14, 26, 40)),
}
# trunks: id = the bark width at K=3 (2 x rx x 3); the bark tile is 512 tall; foot height; root flare (w, h)
TRUNKS = {
    367: dict(rx=61.2, foot_h=137, root=(496, 281)),
    404: dict(rx=67.4, foot_h=147, root=(546, 301)),
    441: dict(rx=73.5, foot_h=158, root=(596, 320)),
    698: dict(rx=116.3, foot_h=232, root=(943, 453)),
}
BARK_H = 512
FOOT_NECK = 10.0                  # sketch px of straight bark above the base ellipse centre in the foot sprite (x K)

# huts: the cheap scheme, 3 wall sizes x 3 roof colours + the lavender Raadhus = 10 sprites for the 14 uses.
# size = (w, h) px at K=3; wall_r, wall_h, roof_rx, roof_h in sketch px (the proportions of the model; the bake fits the size)
HUT_CLASSES = {
    's': dict(size=(287, 284), wall_r=36.7, wall_h=35.0, roof_rx=47.8, roof_h=55.0),
    'm': dict(size=(383, 374), wall_r=49.0, wall_h=44.0, roof_rx=63.7, roof_h=70.0),
    'l': dict(size=(459, 384), wall_r=58.8, wall_h=44.0, roof_rx=76.4, roof_h=70.0),
}
ROOFS = {'straw': 'c9a052', 'moss': '8fb85a', 'dark': 'b88a3e'}
HUT_RAADHUS = dict(size=(497, 480), wall_r=63.7, wall_h=52.0, roof_rx=82.8, roof_h=88.0, fill='9b86d6')
# which sprite draws which building of data/traetoppen/traetoppen.json (V4 reads it from props.json `_city.hut_of`)
HUT_OF = {'h1': 'hut_m_straw', 'h2': 'hut_s_moss', 'h3': 'hut_m_straw', 'h4': 'hut_s_straw', 'h5': 'hut_s_moss', 'h6': 'hut_l_dark',
          'h7': 'hut_l_straw', 'h8': 'hut_m_straw', 'h9': 'hut_m_moss', 'h10': 'hut_m_straw', 'h11': 'hut_m_straw', 'h12': 'hut_s_moss',
          'h13': 'hut_m_dark', 'raadhus': 'hut_raadhus'}
PENNANTS = {'pink': 'e58fa6', 'blue': '6fa8e0', 'gold': 'f2c14e', 'mint': '6fd6c4'}

# single-size parts: id -> (w, h) px at K=3, scales with K unless listed in FIXED
SIZES = {
    'pennant': (66, 102), 'lantern_hang': (54, 96), 'lamp_door': (54, 54),
    'bridge_deck_tile_w43': (129, 128), 'bridge_deck_tile_w28': (85, 128), 'bridge_post': (30, 84), 'rope_tile': (30, 186),
    'ladder_tile': (60, 112), 'lift_basket': (145, 90), 'lift_pulley': (72, 72),
    'market_stall_traetoppen': (252, 240), 'fire_pit': (216, 168), 'fire_flame': (120, 168), 'bath_tub_back': (276, 120), 'bath_tub_front': (276, 120),
    'planter_box': (168, 150), 'log_stack': (240, 150), 'notice_board': (168, 216), 'seed_basket': (90, 72),
    'trunk_hole_owl': (180, 228), 'owl_shelf': (204, 66), 'bat_house_hanging': (348, 573), 'bat_hang': (84, 102),
    'foliage_front': (1020, 720), 'canopy_top_strip': (2048, 320), 'treetop_sky': (16, 1024), 'treetop_far': (2048, 1024),
    'shadow_soft': (256, 128),
}
# DEVIATION (reported): the work order says canopy_top_strip 2560 x 400 at scale .5, but it also says nothing above 2048 px on a side except the Torvet disc and
# the whole set must stay <= 70 MB; the strip is baked 2048 x 320 (the same shape N03 uses for farm_canopy) and drawn at viewport_width / 2048.
CANOPY_ORDER_SIZE = (2560, 400)
# these do not scale with K: screen-space frames and backdrops (their size is a texture budget, not a world size), the bark tile height
FIXED = {'canopy_top_strip', 'treetop_sky', 'treetop_far', 'shadow_soft'}

# ----------------------------------------------------------------------------------------------------------------------------
# pieces of the ids: every file the set ships and its bake family
# ----------------------------------------------------------------------------------------------------------------------------


def disc_id(r: int) -> str:
    return f'platform_disc_{r}'


def bark_id(w: int) -> str:
    return f'trunk_bark_w{w}'


def foot_id(w: int) -> str:
    return f'trunk_foot_w{w}'


def root_id(w: int) -> str:
    return f'trunk_root_w{w}'


def hut_ids() -> list:
    return [f'hut_{c}_{r}' for c in HUT_CLASSES for r in ROOFS] + ['hut_raadhus']


def frames(base: str, n: int) -> list:
    """First frame keeps the base id, the others are base_f1, base_f2 ..."""
    return [base] + [f'{base}_f{i}' for i in range(1, n)]


def expected_sizes(k: float | None = None) -> dict:
    """id -> (w, h) of every texture of the set at scale k (default: the Lua constant)."""
    k = K if k is None else k
    out = {}
    for r, d in DISCS.items():
        out[disc_id(r)] = (scaled(d['size'][0], k), scaled(d['size'][1], k))
    for w, d in TRUNKS.items():
        out[bark_id(w)] = (scaled(w, k), BARK_H)
        out[foot_id(w)] = (scaled(w, k), scaled(d['foot_h'], k))
        out[root_id(w)] = (scaled(d['root'][0], k), scaled(d['root'][1], k))
    for c, d in HUT_CLASSES.items():
        for r in ROOFS:
            out[f'hut_{c}_{r}'] = (scaled(d['size'][0], k), scaled(d['size'][1], k))
    out['hut_raadhus'] = (scaled(HUT_RAADHUS['size'][0], k), scaled(HUT_RAADHUS['size'][1], k))
    for n in PENNANTS:
        for f in frames(f'pennant_{n}', 2):
            out[f] = (scaled(SIZES['pennant'][0], k), scaled(SIZES['pennant'][1], k))
    for sid, (w, h) in SIZES.items():
        if sid in ('pennant', 'fire_flame', 'planter_box', 'trunk_hole_owl', 'bat_hang', 'foliage_front'):
            continue
        out[sid] = (w, h) if sid in FIXED else (scaled(w, k), scaled(h, k))
    for f in frames('fire_flame', 3):
        out[f] = (scaled(SIZES['fire_flame'][0], k), scaled(SIZES['fire_flame'][1], k))
    for f in ('planter_box', 'planter_box_berry'):
        out[f] = (scaled(SIZES['planter_box'][0], k), scaled(SIZES['planter_box'][1], k))
    for f in ('trunk_hole_owl', 'trunk_hole_owl_b'):
        out[f] = (scaled(SIZES['trunk_hole_owl'][0], k), scaled(SIZES['trunk_hole_owl'][1], k))
    for f in frames('bat_hang', 2):
        out[f] = (scaled(SIZES['bat_hang'][0], k), scaled(SIZES['bat_hang'][1], k))
    for f in ('foliage_front_a', 'foliage_front_b'):
        out[f] = (scaled(SIZES['foliage_front'][0], k), scaled(SIZES['foliage_front'][1], k))
    return out


def night_layers() -> list:
    """The huts carry one additive night layer each (trimmed to the bbox of its lights, so its size is NOT in the table)."""
    return [f'{h}_night' for h in hut_ids()]


def memory_mb(sizes: dict, night_px: dict | None = None) -> float:
    px = sum(w * h for (w, h) in sizes.values())
    if night_px:
        px += sum(night_px.values())
    return px * 4 * MIP / 1e6


def main() -> None:
    k = K
    if '--k' in sys.argv:
        k = float(sys.argv[sys.argv.index('--k') + 1])
    sizes = expected_sizes(k)
    print(f'K = {k}  (lua scale {K}, reference {K_REF})')
    big = 0
    for sid, (w, h) in sizes.items():
        print(f'{sid:28s} {w:5d} x {h:5d}   {w * h * 4 * MIP / 1e6:6.2f} MB')
        big = max(big, w, h)
    print(f'{len(sizes)} textures (+ {len(night_layers())} trimmed night layers), {memory_mb(sizes):.1f} MB RGBA8 + mips, largest side {big}')


if __name__ == '__main__':
    main()
