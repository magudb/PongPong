#!/usr/bin/env python3
"""Validator of P22's shipped art (a second implementation of the checks of tests/sections/art_environment.gd; run by build_all.sh after every bake).

  python tools/art/environment/validate_environment.py [--root REPO] [-q]

One `PASS <id>` / `FAIL <id> <reason>` line per check, exit code 1 on any FAIL.  Reads assets/iso_tiles, assets/iso_props, assets/backdrops and lua/config/props_extra.lua.
  tiles_manifest        tiles.json lists the 17 diamond + 7 ortho terrains of AreaTileSet, atlas size = variants x cell, ortho entries carry proj + tile
  tiles_no_mipmaps      every tile atlas has an import stub without mipmaps (compress/mode 0, mipmaps/generate false)
  props_manifest        every prop file exists, size and pivot are inside the image, footprints are positive ints, glow files exist, no foreign (N03 / V5 / A1) ids, no dropped walls
  farm_contract         coop_small 350x295 (155,218) 3x2 ... signpost 84x130 (38,112) 1x1 (TOWNS addendum RT16 task 2)
  crowns                crown_{s,m,l}_{a,b}: disc radius 170 / 230 / 300 (+-6 %), centre .81 R above the pivot (+-.05 R), baked shadow squash .59 (+-.06), size within 12 % of the table
  forest_albedo         mean opaque colour x the forest grade 4d5e85 equals the sketch colour of FOREST_PALETTE within its tolerance; clamped props carry `clamped`, emissive props `blend add`
  textures_seamless     path_tile_o, pond_water_o, floor_patch_*: 256 px, the wrap-around edge step is below the step inside the image
  backdrops             hyggebyen / forest sky 1920 x 1080 + far 2048 x 1280 seamless in x
  props_extra_rows      every manifest id has a row in lua/config/props.lua or props_extra.lua and the footprint of the row equals the baked one
"""
import argparse, json, re, sys
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]

ISO_TERRAINS = ['grass', 'grass_flowers', 'grass_hyggebyen', 'grass_hyggebyen_flowers', 'soil_tilled', 'soil_watered', 'path_dirt', 'deck_farm', 'deck_hyggebyen',
                'cobble_hyggebyen', 'forest_floor', 'forest_floor_glow', 'void_haze', 'water_0', 'water_1', 'water_2', 'water_3']
ORTHO_TERRAINS = ['forest_floor_o', 'forest_floor_glow_o', 'moss_path_o', 'bog_o', 'cave_floor_o', 'crystal_floor_o', 'wall_void_o']
FOREIGN = ['trunk_giant_a', 'trunk_giant_b', 'trunk_under_a', 'trunk_under_b', 'tool_shed', 'shipping_bin', 'stake_sign', 'rope_stake_x', 'rope_stake_z', 'build_stake',
           'dock_x', 'field_grass', 'farm_sky', 'farm_far', 'farm_canopy', 'platform_disc_171']
DROPPED = ['forest_wall_a', 'forest_wall_b', 'forest_wall_c', 'cave_wall_a', 'cave_wall_b']
FARM_CONTRACT = {'coop_small': ([350, 295], [155, 218], [3, 2]), 'barn_small': ([472, 424], [208, 313], [4, 3]), 'animal_house': ([319, 270], [143, 199], [3, 2]),
                 'paw_prints': ([39, 49], [16, 29], [1, 1]), 'apple_tree': ([359, 398], [172, 355], [1, 1]), 'bench': ([174, 144], [78, 107], [2, 1]),
                 'signpost': ([84, 130], [38, 112], [1, 1])}
CROWN_TABLE = {'s': (170, 400, 420), 'm': (230, 530, 550), 'l': (300, 670, 690)}
AMBIENT = np.array([0x4d, 0x5e, 0x85], np.float32)
PALETTE = {'crown': ('353b62', 30), 'bush': ('2a2f4c', 26), 'cave_ring': ('4b4d6e', 30), 'cave_stone': ('4d5e82', 44), 'runestone': ('4d5e82', 44), 'pond_lily': ('3f8f6a', 50)}

fails = 0
quiet = False


def result(cid, ok, why=''):
    global fails
    if not ok:
        fails += 1
    if not ok or not quiet:
        print(('PASS ' if ok else 'FAIL ') + cid + ((' ' + why) if why else ''))


def load(p):
    return json.loads(Path(p).read_text())


def img(p):
    return Image.open(p).convert('RGBA')


def hexrgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def check_tiles(root):
    tj = load(root / 'assets/iso_tiles/tiles.json')
    miss = [t for t in ISO_TERRAINS + ORTHO_TERRAINS if t not in tj]
    bad = []
    for tid in ISO_TERRAINS + ORTHO_TERRAINS:
        e = tj.get(tid)
        if not e:
            continue
        f = root / 'assets/iso_tiles' / e['file']
        if not f.exists():
            bad.append(f'{tid}: no file'); continue
        w, h = img(f).size
        if [w, h] != [e['variants'][0] * e['cell'][0], e['variants'][1] * e['cell'][1]]:
            bad.append(f'{tid}: atlas {w}x{h} != variants x cell')
        if tid in ORTHO_TERRAINS and (e.get('proj') != 'ortho' or e.get('tile') != [96, 56] or e['cell'] != [112, 64]):
            bad.append(f'{tid}: ortho entry wrong {e}')
        if tid in ISO_TERRAINS and (e['cell'] != [144, 84] or e['variants'] != ([2, 2] if tid.startswith('water_') else [4, 4])):
            bad.append(f'{tid}: iso entry wrong {e}')
    result('tiles_manifest', not miss and not bad, f'missing {miss} {bad[:3]}')
    stubs = []
    for tid in ISO_TERRAINS + ORTHO_TERRAINS:
        e = tj.get(tid)
        if not e:
            continue
        imp = root / 'assets/iso_tiles' / (e['file'] + '.import')
        t = imp.read_text() if imp.exists() else ''
        if 'mipmaps/generate=false' not in t or 'compress/mode=0' not in t:
            stubs.append(tid)
    result('tiles_no_mipmaps', not stubs, f'atlases without the no-mipmap stub: {stubs}')


def check_props(root, pj):
    bad = []
    for pid, e in pj.items():
        if pid.startswith('_'):
            continue
        f = root / 'assets/iso_props' / e['file']
        if not f.exists():
            bad.append(f'{pid}: no file'); continue
        w, h = img(f).size
        if e['size'] != [w, h]:
            bad.append(f'{pid}: size {e["size"]} != image {w}x{h}')
        px, py = e['pivot']
        if not (0 <= px < w and 0 <= py < h):
            bad.append(f'{pid}: pivot {e["pivot"]} outside {w}x{h}')
        if not all(isinstance(v, int) and v >= 1 for v in e['footprint']):
            bad.append(f'{pid}: footprint {e["footprint"]}')
        g = e.get('glow')
        if g and not (root / 'assets/iso_props' / g['file']).exists():
            bad.append(f'{pid}: glow file missing')
    foreign = [p for p in pj if p in FOREIGN]
    dropped = [p for p in pj if p in DROPPED]
    result('props_manifest', not bad and not foreign and not dropped, f'{bad[:4]} foreign {foreign} dropped walls {dropped}')


def check_farm(pj):
    bad = []
    for pid, (size, pivot, fp) in FARM_CONTRACT.items():
        e = pj.get(pid)
        if not e or e['size'] != size or e['pivot'] != pivot or e['footprint'] != fp:
            bad.append(f'{pid}: {e and (e["size"], e["pivot"], e["footprint"])} != {(size, pivot, fp)}')
    result('farm_contract', not bad, '; '.join(bad))


def disc_measure(root, e):
    im = np.asarray(img(root / 'assets/iso_props' / e['file']), np.float32)
    a = im[..., 3]
    ys, xs = np.where(a > 230)
    px, py = e['pivot']
    rx = (xs.max() - xs.min()) / 2.0
    ry = (ys.max() - ys.min()) / 2.0
    cy = -(ys.min() + ys.max()) / 2.0 + py                      # centre height above the pivot
    return rx, ry, cy, im


def check_crowns(root, pj):
    bad = []
    for s, (R, tw, th) in CROWN_TABLE.items():
        for v in ('a', 'b'):
            pid = f'crown_{s}_{v}'
            e = pj.get(pid)
            if not e:
                bad.append(f'{pid}: missing'); continue
            rx, ry, cy, im = disc_measure(root, e)
            r = (rx + ry) / 2
            if abs(r - R) / R > .06:
                bad.append(f'{pid}: disc radius {r:.0f} vs {R}')
            if abs(cy - .81 * R) > .06 * R:
                bad.append(f'{pid}: centre {cy:.0f} px above the pivot vs {.81 * R:.0f}')
            w, h = e['size']
            if abs(w - tw) / tw > .12 or abs(h - th) / th > .12:
                bad.append(f'{pid}: size {w}x{h} vs about {tw}x{th}')
            d = e.get('disc', {})
            if d.get('radius') != R or abs(d.get('shadow_squash', 0) - .588) > .01:
                bad.append(f'{pid}: manifest disc {d}')
            # the baked shadow: below the model the dark ellipse reaches (offset_y + squash * R) below the pivot
            a = im[..., 3]; py = e['pivot'][1]
            low = np.where(a > 20)[0].max() - py
            want = 60 * .588 + .588 * R
            if abs(low - want) > .08 * R:
                bad.append(f'{pid}: shadow bottom {low:.0f} px below the pivot vs {want:.0f} (squash .59, offset 60 ground px)')
            if e.get('elev') != 36.0:
                bad.append(f'{pid}: elev {e.get("elev")}')
    result('crowns', not bad, '; '.join(bad[:5]))


def mean_final(root, e):
    im = np.asarray(img(root / 'assets/iso_props' / e['file']), np.float32)
    m = im[..., 3] > 240
    return im[..., :3][m].mean(0) * AMBIENT / 255.0


def check_albedo(root, pj):
    bad = []
    for pid, e in pj.items():
        pal = e.get('palette') if not pid.startswith('_') else None
        if pal not in PALETTE or e.get('kind') == 'texture':
            continue
        want, tol = PALETTE[pal]
        m = mean_final(root, e)
        if np.abs(m - hexrgb(want)).max() > tol:
            bad.append(f'{pid}: mean final {"%02x%02x%02x" % tuple(int(v) for v in m)} vs {want} +-{tol}')
    for pid in ('eyes_glow', 'rune_glow', 'pond_sheen', 'hulen_eyes', 'firefly_dot', 'halo_amber', 'halo_violet', 'crown_spark', 'fx_hit_spark', 'fx_heal_sparkle',
                'telegraph_ring_s', 'telegraph_ring_m', 'telegraph_ring_l', 'telegraph_line', 'boss_arena_ring', 'pond_ripple'):
        if pj.get(pid, {}).get('blend') != 'add':
            bad.append(f'{pid}: emissive but not additive')
    for pid in ('cave_stone_a', 'runestone_dormant', 'runestone_active', 'pond_lily'):
        if not pj.get(pid, {}).get('clamped'):
            bad.append(f'{pid}: above the ceiling but not marked clamped')
    result('forest_albedo', not bad, '; '.join(bad[:5]))


def wrap_step(im):
    a = np.asarray(im.convert('RGB'), np.float32)
    inner = (np.abs(a[:, 1:] - a[:, :-1]).mean() + np.abs(a[1:] - a[:-1]).mean()) / 2
    edge = (np.abs(a[:, 0] - a[:, -1]).mean() + np.abs(a[0] - a[-1]).mean()) / 2
    return edge, inner


def check_textures(root, pj):
    bad = []
    for pid in ('path_tile_o', 'pond_water_o', 'floor_patch_a', 'floor_patch_b', 'floor_patch_c'):
        e = pj.get(pid)
        if not e or e['size'] != [256, 256] or not e.get('seamless'):
            bad.append(f'{pid}: not a 256 px seamless texture'); continue
        edge, inner = wrap_step(img(root / 'assets/iso_props' / e['file']))
        if edge > inner * 1.6 + 1.0:
            bad.append(f'{pid}: wrap step {edge:.1f} vs inner {inner:.1f}')
    result('textures_seamless', not bad, '; '.join(bad))


def check_backdrops(root):
    bad = []
    for t in ('hyggebyen', 'forest'):
        s, f = root / f'assets/backdrops/{t}_sky.webp', root / f'assets/backdrops/{t}_far.webp'
        if not s.exists() or not f.exists():
            bad.append(f'{t}: missing'); continue
        if Image.open(s).size != (1920, 1080) or Image.open(f).size != (2048, 1280):
            bad.append(f'{t}: sizes {Image.open(s).size} {Image.open(f).size}')
        a = np.asarray(Image.open(f).convert('RGBA'), np.float32)
        if np.abs(a[:, 0] - a[:, -1]).mean() > 6:
            bad.append(f'{t}: far layer not seamless in x')
    result('backdrops', not bad, '; '.join(bad))


def check_lua(root, pj):
    src = (root / 'lua/config/props.lua').read_text() + '\n' + (root / 'lua/config/props_extra.lua').read_text() + '\n' + (root / 'lua/config/props_features.lua').read_text()   # GameData merge order
    rows = {}
    for m in re.finditer(r'^\s*([a-z0-9_]+) = \{(.*)\},?\s*$', src, re.M):
        rows[m.group(1)] = m.group(2)
    bad = []
    for pid, e in pj.items():
        if pid.startswith('_'):
            continue
        row = rows.get(pid)
        if row is None:
            bad.append(f'{pid}: no row'); continue
        fp = re.search(r'footprint = \{ (\d+), (\d+) \}', row)
        art = re.search(r'art = "([a-z0-9_]+)"', row)
        if fp and not art and [int(fp.group(1)), int(fp.group(2))] != e['footprint']:
            bad.append(f'{pid}: footprint row {fp.groups()} vs baked {e["footprint"]}')
    result('props_extra_rows', not bad, '; '.join(bad[:6]))


def main():
    global quiet
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--root', default=str(REPO)); ap.add_argument('-q', action='store_true')
    a = ap.parse_args()
    quiet = a.q
    root = Path(a.root)
    pj = load(root / 'assets/iso_props/props.json')
    check_tiles(root); check_props(root, pj); check_farm(pj); check_crowns(root, pj); check_albedo(root, pj); check_textures(root, pj); check_backdrops(root); check_lua(root, pj)
    print('validate_environment: %d finding(s)' % fails)
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
