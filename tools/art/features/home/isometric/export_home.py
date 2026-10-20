#!/usr/bin/env python3
"""Turn the PNG masters (houses, furniture, interior pieces, floors, icons, props) into the game-ready res://assets tree + json contracts (addendum 3.5).

  python tools/art/features/home/isometric/export_home.py [--work <stage>] [--dst <stage>/assets] [--write-specs] [--mirror-fallback]

--work defaults to tools/art/_stage/features_home (the tree produce_home.sh fills), --dst to <work>/assets.  Writes (every `file` in a json is RELATIVE TO THAT JSON):

  iso_props/home/{house_tNN,house_tNN_night,scaffold_toNN}.webp + home.json         tiers[] without gold/materials/Danish text (those are lua/data/home_tiers.lua + home.csv)
  iso_props/furniture/<id>_r<k>[_float].webp + furniture.json                        TRUE views of every distinct rotation (symmetry MEASURED); _float only on the legendary pieces; specs/mirror_ok.json is measured on these files
  iso_props/interior/*.webp + interior.json     iso_props/fx/glow_soft.webp          iso_props/features/*.webp + props.json (the nine new props)
  iso_tiles/floor_{stone,plank,parquet,marble}.png + tiles_floors.json
  <texture>.import                                                                   the stub of the project's texture import policy (tools/import/write_import_stubs.py, review REND-03:
                                                                                     S3TC + mipmaps for houses, furniture, interior pieces and props, the floors lossless WITHOUT mipmaps;
                                                                                     the lossless icons need none), so a new texture imports with its preset on the FIRST import
  data/home/rooms/room_tNN.json                                                      rows, cells, floor, wall_style, door, spawn, windows, max_furniture, zoom_fit
  icons/home/<furniture id>.webp  <material id>.webp (lossless 128x128)  <legendary id>_night.webp (pale die-cut rim, night_rim.py)
  lua/config/props_features.lua                                                      gameplay entries of the nine props (generated from features_props.GAMEPLAY + the baked footprints)
  export_stats.json                                                                  bytes per group (the budget: about 9.2 MB)

--write-specs stores the measured specs/mirror_ok.json.  --mirror-fallback is the DISK FALLBACK of RV-A5: the r1/r3 files of the ids in specs/mirror_ok.json are not written
and their entries say `mirror_of` + `flip_h` instead (about 0.7 MB smaller); the default ships every true rotation.
"""
from __future__ import annotations
import argparse, io, json, shutil, sys, time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import numpy as np
from PIL import Image
import homepaths
sys.path.insert(0, str(homepaths.REPO / 'tools/import'))
from write_import_stubs import stub_for   # noqa: E402  the one texture import policy

Q_HOUSE, Q_SCAFFOLD, Q_FURN, Q_INTERIOR, Q_PROP = 92, 90, 94, 94, 94
NIGHT_RIM = '_night'

def conv(job):
    src, dst, q, lossless = job
    im = Image.open(src).convert('RGBA')
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    if lossless:
        im.save(dst, 'WEBP', lossless=True, quality=100, method=6)
    else:
        im.save(dst, 'WEBP', quality=q, method=4, alpha_quality=100, lossless=False)
    return str(dst), Path(dst).stat().st_size


def sw(name: str) -> str:
    return str(name).replace('.png', '.webp')


def write_json(path: Path, doc) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + '\n', encoding='utf-8')


def write_stubs(dst: Path) -> list:
    """The `.import` stub of every texture of the stage tree `dst` (laid out like res://assets), from the project's import policy: written BEFORE the
    first godot --import. install_home.py copies a stub only for a texture the repo does not have yet and holds an existing .import to the same policy."""
    wrote = []
    for f in sorted(Path(dst).rglob('*')):
        if f.suffix in ('.png', '.webp'):
            stub = stub_for(homepaths.REPO / 'assets' / f.relative_to(dst))
            if stub:
                f.with_name(f.name + '.import').write_text(stub); wrote.append(f.name)
    return wrote


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--work', default=None); ap.add_argument('--dst', default=None)
    ap.add_argument('--spec', default=str(homepaths.SPECS / 'furniture_art_spec.json'))
    ap.add_argument('--write-specs', action='store_true', help='store the measured mirror list in specs/mirror_ok.json')
    ap.add_argument('--mirror-fallback', action='store_true')
    ap.add_argument('--jobs', type=int, default=6)
    a = ap.parse_args()
    W = homepaths.assert_stage(a.work or homepaths.stage_root())
    D = homepaths.assert_stage(a.dst or W / 'assets')
    import home_data as hd, spec_reader as sp, night_rim as nr, measure_mirror as mm, features_props as fp
    t0 = time.time(); jobs = []; groups = {}
    if D.exists():
        shutil.rmtree(D)                                                           # a stage output is rebuilt from scratch: no stale file survives
    for sub in ('iso_props/home', 'iso_props/furniture', 'iso_props/interior', 'iso_props/fx', 'iso_props/features', 'iso_tiles', 'icons/home', 'data/home/rooms', 'lua/config'):
        (D / sub).mkdir(parents=True, exist_ok=True)
    spec_items = sp.load(a.spec); spec_by_id = sp.by_id(spec_items)
    contract = json.loads((homepaths.SPECS / 'content_contract.json').read_text())

    # ---- houses -----------------------------------------------------------------------------------------------------------------
    hj = json.loads((W / 'home_final' / 'home.json').read_text())
    for t, m in hj['tiers'].items():
        jobs.append((str(W / 'home_final' / m['file']), str(D / 'iso_props/home' / sw(m['file'])), Q_HOUSE, False, 'houses')); m['file'] = sw(m['file'])
        if 'night' in m:
            jobs.append((str(W / 'home_final' / m['night']['file']), str(D / 'iso_props/home' / sw(m['night']['file'])), Q_HOUSE, False, 'houses_night')); m['night']['file'] = sw(m['night']['file'])
    for t, m in hj['scaffold'].items():
        jobs.append((str(W / 'home_final' / m['file']), str(D / 'iso_props/home' / sw(m['file'])), Q_SCAFFOLD, False, 'scaffolds')); m['file'] = sw(m['file'])
    tiers = hd.tiers_json(hj['tiers'], hj['scaffold'])
    write_json(D / 'iso_props/home/home.json', {
        '_contract': {'files': 'relative to this json',
                      'anchor': 'ground point at the centre of the DOOR on the front plane (z=0); every tier shares it, so tier swaps are in-place texture swaps',
                      'footprint_rect': 'tiles relative to the anchor: [xmin, zmin, xmax, zmax]; +x = screen right-down, +z = screen left-down (front)',
                      'night': 'ADDITIVE layer (BLEND_MODE_ADD), TRIMMED to the bbox of its lights: exterior.night_offset = px from the top-left of the day sprite, exterior.night_size = its size; same pivot as the day sprite',
                      'ysort': 'px offset from the pivot to the y-sort key point (left-front corner if W>=D)',
                      'platform_back_rows': 'extra deck rows added BEHIND the door row (towards -z); front edges + all farm coordinates stay identical',
                      'money': 'none here: costs, days, materials and gates are lua/data/home_tiers.lua; names are localization/home.csv'},
        'platform_stages': {str(k): v for k, v in hd.PLATFORM_STAGES.items()}, 'tiers': tiers})
    for t in range(1, 11):
        write_json(D / f'data/home/rooms/room_t{t:02d}.json', hd.room(t))

    # ---- furniture --------------------------------------------------------------------------------------------------------------
    fj = json.loads((W / 'furn' / 'furniture.json').read_text())
    items = {}
    for iid, m in fj['items'].items():
        e = {k: m[k] for k in ('template', 'category', 'layer', 'rarity', 'tier', 'sym', 'footprint', 'height_m', 'baked', 'rot_map') if k in m}
        for k in ('surface', 'interact', 'hang_m'):
            if k in m: e[k] = m[k]
        e['rot'] = {}
        for r, ent in m['rot'].items():
            ne = {k: v for k, v in ent.items() if k not in ('file', 'float')}
            ne['file'] = sw(Path(ent['file']).name)
            jobs.append((str(W / 'furn' / ent['file']), str(D / 'iso_props/furniture' / ne['file']), Q_FURN, False, 'furniture'))
            if 'float' in ent:
                nf = dict(ent['float']); nf['file'] = sw(Path(ent['float']['file']).name); ne['float'] = nf
                jobs.append((str(W / 'furn' / ent['float']['file']), str(D / 'iso_props/furniture' / nf['file']), Q_FURN, False, 'furniture'))
            e['rot'][r] = ne
        e['icon'] = f'../../icons/home/{iid}.webp'
        items[iid] = e
    fur_json = {'_contract': {'files': 'relative to this json', 'tile': [128, 76], 'px_per_m': 87.074,
                              'rotation': 'yaw k*90 deg about +Y; r0 front faces +z (screen left-down), r1 faces +x (screen right-down); rot_map[k] = [baked rotation index, flip_h]',
                              'pivot': 'ground point at the footprint centre (wall items: on the wall plane below the item centre)',
                              'float': 'floating bits of the LEGENDARY pieces only (the 11 legendary ids carry one per baked rotation; unique pieces have none: their cue is shape and palette): same crop + pivot as the main sprite, bobbed by the engine (bob_px / bob_seconds)',
                              'glow': 'additive tint of iso_props/fx/glow_soft.webp at `center` (px in the sprite), scaled to radius_px',
                              'mirror_ok': 'true = this piece MAY be drawn as flip_h of the other rotation (disk fallback, measured by measure_mirror.py); the true files exist anyway unless exported with --mirror-fallback',
                              'icon': 'relative path of the 128x128 icon (and <id>_night.webp for legendary pieces)'},
                'items': items}
    # shared additive halo (tinted + scaled by the engine -> no per-item halo files)
    n = 256; y, x = np.mgrid[0:n, 0:n].astype(np.float32); d = np.hypot(x - n / 2, y - n / 2) / (n / 2); al = np.clip(np.exp(-d * d * 3.2) * (1 - np.clip(d, 0, 1) ** 4), 0, 1)
    halo = np.zeros((n, n, 4), np.uint8); halo[..., :3] = 255; halo[..., 3] = np.uint8(al * 255)
    Image.fromarray(halo, 'RGBA').save(D / 'iso_props/fx/glow_soft.webp', 'WEBP', lossless=True)
    groups['fx'] = (D / 'iso_props/fx/glow_soft.webp').stat().st_size

    # ---- interior ---------------------------------------------------------------------------------------------------------------
    ij = json.loads((W / 'interior/interior/interior.json').read_text())
    for grp in ('walls', 'door'):
        for k, m in ij[grp].items():
            jobs.append((str(W / 'interior/interior' / m['file']), str(D / 'iso_props/interior' / sw(m['file'])), Q_INTERIOR, False, 'interior')); m['file'] = sw(m['file'])
            if 'night' in m:
                jobs.append((str(W / 'interior/interior' / m['night']), str(D / 'iso_props/interior' / sw(m['night'])), Q_INTERIOR, False, 'interior')); m['night'] = sw(m['night'])
    ij.pop('floors', None)
    ij = {'_contract': {'files': 'relative to this json', 'wall': 'one tile long, pivot = centre of the tile edge on the floor line; r0 sits on the cell back-right edge facing +z, r1 (the same model yawed 90) on the back-left edge facing +x',
                        'night': 'wall pieces with a window carry <piece>_night (additive)'}, **ij}
    write_json(D / 'iso_props/interior/interior.json', ij)

    # ---- floors (atlases are copied as PNG: lossless, no mipmaps) ----------------------------------------------------------------
    for f in (W / 'interior/tiles').glob('floor_*.png'):
        shutil.copy(f, D / 'iso_tiles' / f.name); groups['floors'] = groups.get('floors', 0) + f.stat().st_size
    tj = json.loads((W / 'interior/tiles/tiles.json').read_text())
    for k, v in tj.items():
        if isinstance(v, dict): v.pop('seconds', None)
    write_json(D / 'iso_tiles/tiles_floors.json', tj)

    # ---- new props --------------------------------------------------------------------------------------------------------------
    pj = json.loads((W / 'features_props/props.json').read_text())
    for pid, m in pj.items():
        if pid.startswith('_'): continue
        lossless = m.get('blend') == 'add'
        jobs.append((str(W / 'features_props' / m['file']), str(D / 'iso_props/features' / sw(m['file'])), Q_PROP, lossless, 'props')); m['file'] = sw(m['file'])
        m.pop('bake_seconds', None)
        if 'glow' in m:
            jobs.append((str(W / 'features_props' / m['glow']['file']), str(D / 'iso_props/features' / sw(m['glow']['file'])), Q_PROP, True, 'props')); m['glow']['file'] = sw(m['glow']['file'])
    write_json(D / 'iso_props/features/props.json', pj)

    # ---- icons: furniture + materials (lossless) + the night variants of the legendary pieces ---------------------------------------
    icon_src = {}
    for f in (W / 'icons_furn').glob('*.png'): icon_src[f.stem] = f
    for f in (W / 'mat_icons').glob('*.png'): icon_src[f.stem] = f
    for iid, f in sorted(icon_src.items()):
        jobs.append((str(f), str(D / 'icons/home' / f'{iid}.webp'), 100, True, 'icons'))
    legendary = sorted(i for i, e in contract['furniture'].items() if e['rarity'] == 'legendary')
    for iid in legendary:
        var = nr.night_variant(Image.open(icon_src[iid]).convert('RGBA'))
        dst = D / 'icons/home' / f'{iid}{NIGHT_RIM}.webp'
        var.save(dst, 'WEBP', lossless=True, quality=100, method=6)
        groups['icons_night'] = groups.get('icons_night', 0) + dst.stat().st_size

    with ProcessPoolExecutor(a.jobs) as ex:
        for (dst, size), job in zip(ex.map(conv, [j[:4] for j in jobs], chunksize=8), jobs):
            groups[job[4]] = groups.get(job[4], 0) + size

    # ---- mirror list: measured on the exported WebP sprites, then furniture.json -------------------------------------------------
    res = mm.measure(D / 'iso_props/furniture', spec_items) if False else None
    write_json(D / 'iso_props/furniture/furniture.json', fur_json)                    # provisional (measure_mirror reads it)
    res = mm.measure(D / 'iso_props/furniture', spec_items)
    ok = set(res['ok'])
    for iid, e in items.items():
        if iid in ok: e['mirror_ok'] = True
    if a.write_specs:
        (homepaths.SPECS / 'mirror_ok.json').write_text(json.dumps(mm.document(res), indent=1) + '\n'); print('wrote specs/mirror_ok.json:', len(ok), 'ids')
    if a.mirror_fallback:
        saved = 0
        for iid in sorted(ok):
            e = items[iid]
            for r, src in (('1', '0'), ('3', '2')):
                ent = e['rot'][r]; f = D / 'iso_props/furniture' / ent['file']; saved += f.stat().st_size; f.unlink()
                ent.pop('file'); ent['mirror_of'] = int(src); ent['flip_h'] = True; ent['pivot'] = [ent['size'][0] - ent['pivot'][0], ent['pivot'][1]]
            e['baked'] = [0, 2]; e['rot_map'] = [[0, False], [0, True], [2, False], [2, True]]
        groups['furniture'] -= saved; print('mirror fallback: %d ids, %.2f MB of sprites not written' % (len(ok), saved / 1e6))
    write_json(D / 'iso_props/furniture/furniture.json', fur_json)
    write_stubs(D)

    # ---- lua/config/props_features.lua ---------------------------------------------------------------------------------------------
    (D / 'lua/config/props_features.lua').write_text(props_lua(pj, fp), encoding='utf-8')

    tot = sum(groups.values())
    write_json(D / 'export_stats.json', {k: v for k, v in groups.items()} | {'total_bytes': tot})
    print('export %.1fs  total %.2f MB  ' % (time.time() - t0, tot / 1e6) + '  '.join(f'{k} {v / 1e6:.2f} MB' for k, v in groups.items()))


def props_lua(pj: dict, fp) -> str:
    """lua/config/props_features.lua: one gameplay entry per new prop (footprint from the baked props.json, solid shape + interact from features_props.GAMEPLAY)."""
    def lua_val(v):
        if isinstance(v, bool): return 'true' if v else 'false'
        if isinstance(v, (int, float)): return str(v)
        if isinstance(v, str): return '"%s"' % v
        if isinstance(v, (list, tuple)): return '{ ' + ', '.join(lua_val(x) for x in v) + ' }'
        if isinstance(v, dict): return '{ ' + ', '.join(f'{k} = {lua_val(x)}' for k, x in v.items()) + ' }'
        raise TypeError(v)
    out = ['-- lua/config/props_features.lua  (package A1-art-home; GENERATED by tools/art/features/home/isometric/export_home.py from features_props.GAMEPLAY + the baked props.json)',
           '-- Gameplay entries of the nine new feature props, read by the area builder next to lua/config/props.lua and props_extra.lua (GameData merges all three).',
           '--   art       prop id in assets/iso_props/features/props.json        footprint  tiles {x, z}        solid  shape of the world body in ground px (circle radius, or the footprint padded)',
           '--   interact  what E / the marker handler does: chest | dig | unique_spot | node | none        strips  y-sort strips (0 = one sort key)        blend  "add" = additive soft sprite',
           '--   opened    chests only: the OPEN state is the same sprite darkened (modulate) plus a sparkle burst - there is no open-lid art (honest stub)',
           'kind = "config"', '', 'config = {', '  props_features = {']
    for pid in fp.ORDER:
        g = dict(fp.GAMEPLAY[pid]); m = pj[pid]
        entry = {'art': pid, 'footprint': m['footprint']} | g
        if m.get('blend') == 'add': entry['blend'] = 'add'
        out.append(f'    {pid} = {lua_val(entry)},')
    out += ['  },', '}', '']
    return '\n'.join(out)


if __name__ == '__main__':
    main()
