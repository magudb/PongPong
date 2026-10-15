#!/usr/bin/env python3
"""Bake every texture of the Traetoppen city set (package V5-art-city) into a STAGE folder of lossless PNG masters + props.json.

  python tools/art/environment/city/bake_city.py [--stage DIR] [--only id,id...] [--family painted|model|all] [--jobs N] [--ss 3]

The stage is a folder OUTSIDE the project or tools/art/_stage[/x] (artpaths guard).  Layout:  <stage>/masters/iso_props/city/<id>.png + props.json,
<stage>/masters/backdrops/treetop_sky.png, treetop_far.png.  install_city.py turns that into assets/iso_props/city/*.webp (lossless) and
assets/backdrops/treetop_*.webp.  This script never touches assets/.

props.json: the same shape ArtCatalog reads ({file, size, pivot, footprint, blend?, glow?}) + the city's own keys (kind, tile, night, wall_r, frames ...) and
a `_city` header with K, the hut mapping of the buildings of data/traetoppen/traetoppen.json and the usage contracts of the tiles.
"""
from __future__ import annotations
import argparse, json, math, os, re, sys, time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parents[1] / 'core'))
import artpaths                       # noqa: E402
import city_spec as S                 # noqa: E402
import paint as P                     # noqa: E402

ART = HERE.parents[1]
TILE_PX = 90.5                        # px of one ground tile edge along the screen x axis (128 / sqrt(2))


def ids_painted():
    ids = []
    ids += [S.disc_id(r) for r in S.DISCS]
    for w in S.TRUNKS:
        ids += [S.bark_id(w), S.foot_id(w), S.root_id(w)]
    for n in S.PENNANTS:
        ids += S.frames(f'pennant_{n}', 2)
    ids += ['lantern_hang', 'lamp_door', 'bridge_deck_tile_w43', 'bridge_deck_tile_w28', 'bridge_post', 'rope_tile', 'ladder_tile', 'lift_basket', 'lift_pulley']
    ids += S.frames('fire_flame', 3)
    ids += ['trunk_hole_owl', 'trunk_hole_owl_b', 'owl_shelf'] + S.frames('bat_hang', 2)
    ids += ['foliage_front_a', 'foliage_front_b', 'canopy_top_strip', 'treetop_sky', 'treetop_far', 'shadow_soft']
    return ids


def ids_model():
    return S.hut_ids() + ['market_stall_traetoppen', 'fire_pit', 'bath_tub_back', 'bath_tub_front', 'planter_box', 'planter_box_berry', 'log_stack',
                          'notice_board', 'seed_basket', 'bat_house_hanging']


ALL_IDS = ids_painted() + ids_model()


def _frame_of(sid: str) -> int:
    m = re.search(r'_f(\d+)$', sid)
    return int(m.group(1)) if m else 0


def _footprint_tiles(radius_px: float) -> list:
    n = max(1, int(math.ceil(2 * radius_px / TILE_PX)))
    return [n, n]


def _top_opaque_row(im: Image.Image, thr: int = 128) -> int:
    a = np.asarray(im.getchannel('A'))
    rows = np.where((a > thr).any(axis=1))[0]
    return int(rows[0]) if len(rows) else 0


# ----------------------------------------------------------------------------------------------------------------------------
# painted pieces
# ----------------------------------------------------------------------------------------------------------------------------

def bake_painted(sid: str):
    import paint_platforms as PP, paint_trunks as PT, paint_bridge as PB, paint_decor as PD
    meta: dict = {}
    im = None
    pivot = None
    if sid.startswith('platform_disc_'):
        r = int(sid.rsplit('_', 1)[1])
        im, pivot = PP.paint_disc(r)
        d = S.DISCS[r]
        meta = {'kind': 'platform_disc', 'rx': d['rx'], 'ry': d['ry'], 'rim': S.RIM, 'uses': d['uses'], 'footprint': [0, 0],
                'note': 'pivot = the centre of the top ellipse; draw at z = rank - 4 in a non-sorted node; no trunk hole'}
    elif sid.startswith('trunk_bark_w'):
        w = int(sid.split('w')[-1])
        im = PT.paint_bark(w)
        pivot = (im.width / 2.0, im.height / 2.0)
        meta = {'kind': 'trunk_bark', 'tile': 'y', 'rx': S.TRUNKS[w]['rx'], 'footprint': [0, 0],
                'note': 'vertically seamless; repeat with a Sprite2D region (texture_repeat); end an upper segment at tile row 512 so its foot continues the pattern'}
    elif sid.startswith('trunk_foot_w'):
        w = int(sid.split('w')[-1])
        im, pivot = PT.paint_foot(w)
        meta = {'kind': 'trunk_foot', 'bark': S.bark_id(w), 'neck_px': int(round(S.FOOT_NECK * S.K)), 'footprint': [0, 0],
                'note': 'pivot = the centre of the trunk base ellipse; the first rows are bark tile rows 0..neck'}
    elif sid.startswith('trunk_root_w'):
        w = int(sid.split('w')[-1])
        im, pivot = PT.paint_root(w)
        meta = {'kind': 'trunk_root', 'bark': S.bark_id(w), 'footprint': [0, 0],
                'note': 'ground-contact flare of a lower trunk; pivot = the centre of the ground ellipse'}
    elif sid.startswith('pennant_'):
        base = re.sub(r'_f\d+$', '', sid)
        name = base.split('_')[1]
        frame = _frame_of(sid)
        im, pivot = PD.paint_pennant(name, frame)
        meta = {'kind': 'pennant', 'colour': S.PENNANTS[name], 'footprint': [1, 1]}
        if frame == 0:
            meta.update({'frames': S.frames(base, 2), 'fps': 2.0})
    elif sid == 'lantern_hang':
        im, pivot = PD.paint_lantern()
        meta = {'kind': 'lantern', 'footprint': [1, 1], 'note': 'pivot = the centre of the glass body (the sketch point of a hanging lantern); halo = fx/glow_soft'}
    elif sid == 'lamp_door':
        im, pivot = PD.paint_lamp_door()
        meta = {'kind': 'lantern', 'footprint': [1, 1], 'note': 'pivot = the lamp centre; halo = fx/glow_soft'}
    elif sid.startswith('bridge_deck_tile_'):
        kind = sid.rsplit('_', 1)[1]
        im = PB.paint_deck_tile(kind)
        pivot = (im.width / 2.0, im.height / 2.0)
        meta = {'kind': 'bridge_deck', 'tile': 'x', 'footprint': [0, 0],
                'note': 'Line2D tile: X runs along the bridge, Y across; planks are vertical bars; periodic in x'}
    elif sid == 'bridge_post':
        im, pivot = PB.paint_post()
        meta = {'kind': 'post', 'footprint': [1, 1], 'note': 'pivot = the foot; the rail rope ties at 72 px (24 sketch px) above it'}
    elif sid == 'rope_tile':
        im = PB.paint_rope_tile()
        pivot = (im.width / 2.0, im.height / 2.0)
        meta = {'kind': 'rope', 'tile': 'y', 'footprint': [0, 0], 'note': 'a vertical twisted rope, periodic in y: Sprite2D region + repeat (the lift rope)'}
    elif sid == 'ladder_tile':
        im = PB.paint_ladder_tile()
        pivot = (im.width / 2.0, im.height / 2.0)
        meta = {'kind': 'ladder', 'tile': 'y', 'footprint': [0, 0], 'rungs_per_tile': 2, 'note': 'two rails and two rungs (56 px pitch); periodic in y'}
    elif sid == 'lift_basket':
        im, pivot = PB.paint_basket()
        meta = {'kind': 'lift', 'footprint': [1, 1], 'note': 'pivot = the bottom centre (the basket point of the data); the rope Line2D runs down its centre line'}
    elif sid == 'lift_pulley':
        im, pivot = PB.paint_pulley()
        meta = {'kind': 'lift', 'footprint': [1, 1], 'note': 'pivot = the wheel centre'}
    elif sid.startswith('fire_flame'):
        f = _frame_of(sid)
        im, pivot = PD.paint_flame(f)
        meta = {'kind': 'flame', 'blend': 'add', 'footprint': [1, 1], 'note': 'additive; pivot = the base centre of the flame'}
        if f == 0:
            meta.update({'frames': S.frames('fire_flame', 3), 'fps': 8.0})
    elif sid in ('trunk_hole_owl', 'trunk_hole_owl_b'):
        im, pivot = PT.paint_owl_hole('a' if sid == 'trunk_hole_owl' else 'b')
        meta = {'kind': 'decal', 'footprint': [0, 0], 'note': 'a decal on the trunk face; pivot = the centre of the hole (the owl is drawn inside)'}
    elif sid == 'owl_shelf':
        im, pivot = PT.paint_owl_shelf()
        meta = {'kind': 'decal', 'footprint': [0, 0], 'note': 'the ledge under the hole; pivot = the top-surface centre'}
    elif sid.startswith('bat_hang'):
        f = _frame_of(sid)
        im, pivot = PD.paint_bat(f)
        meta = {'kind': 'bat', 'footprint': [1, 1], 'note': 'static sleeping bat (the pack has no hang clip: honest stub); pivot = the hook at the top centre'}
        if f == 0:
            meta.update({'frames': S.frames('bat_hang', 2), 'fps': 1.0})
    elif sid.startswith('foliage_front_'):
        im, pivot = PD.paint_foliage(sid[-1])
        meta = {'kind': 'foliage', 'alpha_baked': 0.5, 'footprint': [0, 0], 'note': 'five leaf circles at alpha .5 baked; draw at z 155 (trunk F) / 165 (trunk G)'}
    elif sid == 'canopy_top_strip':
        im = PD.paint_canopy()
        pivot = (im.width / 2.0, 0.0)
        meta = {'kind': 'canopy', 'footprint': [0, 0], 'note': 'screen-space frame for CanvasLayer 3: periodic in x, 2048 wide (draw at viewport_width / 2048)'}
    elif sid == 'treetop_sky':
        im = P.to_image(np.dstack([np.asarray(PD.paint_sky(), np.float32) / 255.0, np.ones((S.SIZES['treetop_sky'][1], S.SIZES['treetop_sky'][0]), np.float32)]))
    elif sid == 'treetop_far':
        im = PD.paint_far()
    elif sid == 'shadow_soft':
        im, pivot = PD.paint_shadow_soft()
        meta = {'kind': 'shadow', 'footprint': [1, 1], 'note': 'optional shared soft contact shadow, scaled per object by the engine; pivot = centre'}
    else:
        raise SystemExit(f'bake_city: no painter for {sid}')
    if pivot is None:
        pivot = (im.width / 2.0, im.height / 2.0)
    return im, pivot, meta


# ----------------------------------------------------------------------------------------------------------------------------
# model (VTK) pieces
# ----------------------------------------------------------------------------------------------------------------------------

def bake_model(sid: str, ss: int):
    import bake3d as B, models_city as M
    ppv = M.PPM * M.COS
    outline = True
    night = None
    if sid.startswith('hut_'):
        if sid == 'hut_raadhus':
            cls, fill, rd = S.HUT_RAADHUS, S.HUT_RAADHUS['fill'], True
            build = lambda: M.hut(cls, fill, sid, raadhus=True)
            wall_r = cls['wall_r']
        else:
            _, c, r = sid.split('_')
            cls, fill, rd = S.HUT_CLASSES[c], S.ROOFS[r], False
            build = lambda: M.hut(cls, fill, sid)
            wall_r = cls['wall_r']
        target = (S.scaled(cls['size'][0]), S.scaled(cls['size'][1]))
        r = B.bake(build, target, ss=ss, want_emit=True)
        im, piv = r['main'], r['pivot']
        fit_scale = [round(r['scale'][0], 3), round(r['scale'][1], 3)]
        wr_px = 0.80 * (target[0] - 7) / 2.0
        meta = {'kind': 'hut', 'fit': fit_scale, 'wall_r': wall_r, 'wall_r_px': round(wr_px, 1), 'roof_fill': fill, 'footprint': _footprint_tiles(wr_px),
                'apex': [piv[0], _top_opaque_row(im) + 7],
                'note': 'wall + roof + door as one sprite; pivot = the wall-circle centre on the floor; draw the pennant at `apex`'}
        if r['emit'] is not None:
            night = (r['emit'], r['emit_offset'])
        return im, piv, meta, night
    if sid == 'market_stall_traetoppen':
        build, target = M.stall, (S.scaled(252), S.scaled(240))
        meta = {'kind': 'stall', 'footprint': [2, 1], 'note': 'P22 market_stall recoloured: striped awning e3c372 / cream; pivot = the ground centre'}
    elif sid == 'fire_pit':
        build, target = M.fire_pit, (S.scaled(216), S.scaled(168))
        meta = {'kind': 'fire', 'footprint': [2, 2], 'note': 'stone ring + logs; draw fire_flame (additive) with the same pivot'}
    elif sid in ('bath_tub_back', 'bath_tub_front'):
        return _bake_tub(sid, ss)
    elif sid in ('planter_box', 'planter_box_berry'):
        kind = 'herb' if sid == 'planter_box' else 'berry'
        build, target = (lambda: M.planter(kind)), (S.scaled(168), S.scaled(150))
        meta = {'kind': 'planter', 'variant': kind, 'footprint': [1, 1], 'note': 'raised bed; the kind (herb / berry) is the node kind of the kitchen gardens'}
    elif sid == 'log_stack':
        build, target = M.log_stack, (S.scaled(240), S.scaled(150))
        meta = {'kind': 'timber', 'footprint': [2, 1], 'note': 'Brumme\'s timber stack; the cut ends face screen right-down'}
    elif sid == 'notice_board':
        build, target = M.notice_board, (S.scaled(168), S.scaled(216))
        meta = {'kind': 'board', 'footprint': [1, 1], 'note': 'the Raadhus notice board facing the viewer'}
    elif sid == 'seed_basket':
        build, target = M.seed_basket, (S.scaled(90), S.scaled(72))
        meta = {'kind': 'basket', 'footprint': [1, 1], 'note': 'Hoppe\'s seed basket'}
    elif sid == 'bat_house_hanging':
        build, target = M.bat_house, (S.scaled(348), S.scaled(573))
        meta = {'kind': 'bat_house', 'footprint': [1, 1], 'note': 'drum with the door on top, cone below; pivot = the cone tip (the `tip_y` of the data); hang bat_hang under it'}
    else:
        raise SystemExit(f'bake_city: no model for {sid}')
    r = B.bake(build, target, ss=ss)
    meta['fit'] = [round(r['scale'][0], 3), round(r['scale'][1], 3)]
    return r['main'], r['pivot'], meta, None


def _bake_tub(sid: str, ss: int):
    """Both halves share ONE scale (fitted on the full width of the back half) and the pivot = the water-surface centre of the tub."""
    import bake3d as B, models_city as M
    half = sid.rsplit('_', 1)[1]
    W, H = S.scaled(276), S.scaled(120)
    back = lambda: M.tub('back')
    r0 = B.render(back, 1.0, 1.0, ss=1)
    sx = W / r0['main'].width
    for _ in range(3):
        rb = B.render(back, sx, sx, ss=1)
        sx *= W / rb['main'].width
    build = (lambda: M.tub(half))
    r = B.render(build, sx, sx, ss=ss, outline=True)
    im, piv = r['main'], r['pivot']
    # pivot = the water-surface centre: the model origin sits on the floor, the water is TUB_WATER above it
    pv = (piv[0], piv[1] - M.TUB_WATER * sx * M.PPM * M.COS)
    canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ox = (W - im.width) // 2
    # place the content so the pivot sits at 6 px (front) or leaves 8 px of the sprite below it (back)
    if half == 'back':
        oy = int(round(H - 8 - pv[1])) if pv[1] + 8 <= H else 0
        oy = max(0, min(oy, H - im.height))
    else:
        oy = max(0, int(round(7 - pv[1])))
    canvas.alpha_composite(im, (ox, oy))
    out_pivot = (pv[0] + ox, pv[1] + oy)
    meta = {'kind': 'tub', 'half': half, 'footprint': [2, 2], 'scale': round(sx, 4),
            'content_h': im.height,
            'note': 'both halves share the pivot = the water-surface centre of the tub; Sofus is drawn BETWEEN them (back, Sofus, front)'}
    return canvas, out_pivot, meta, None


# ----------------------------------------------------------------------------------------------------------------------------

def work(args):
    try:
        return _work(args)
    except Exception as exc:                      # name the id: a ProcessPool traceback does not
        raise RuntimeError(f'bake_city: {args[0]} failed: {exc!r}') from exc


def _work(args):
    sid, out, ss = args
    t0 = time.time()
    if sid in ids_model():
        im, pivot, meta, night = bake_model(sid, ss)
    else:
        im, pivot, meta = bake_painted(sid)
        night = None
    out = Path(out)
    sub = out / ('backdrops' if sid in ('treetop_sky', 'treetop_far') else 'iso_props/city')
    sub.mkdir(parents=True, exist_ok=True)
    im.save(sub / f'{sid}.png', compress_level=6)
    res = {'id': sid, 'size': list(im.size), 'pivot': [round(float(pivot[0]), 1), round(float(pivot[1]), 1)], 'meta': meta, 'seconds': round(time.time() - t0, 1)}
    if night is not None:
        nim, off = night
        nim.save(sub / f'{sid}_night.png', compress_level=6)
        res['night'] = {'size': list(nim.size), 'offset': [int(off[0]), int(off[1])]}
    return res


def build_props_json(results: list) -> dict:
    props: dict = {}
    props['_city'] = {
        'k': S.K, 'k_ref': S.K_REF, 'scale_source': 'lua/config/traetoppen.lua (traetoppen.scale)', 'outline': 'pack warm outline (75,60,73) 55 %, 2 px',
        'bark_tile_h': S.BARK_H, 'shadow': 'none baked (the engine draws shadows; shadow_soft is an optional shared one)',
        'hut_of': S.HUT_OF, 'ids': sorted(S.expected_sizes().keys()),
        'tiles': {'bridge_deck_tile_*': 'Line2D tile, X along the bridge', 'trunk_bark_w*': 'Sprite2D region + repeat, vertical', 'ladder_tile': 'region + repeat, vertical',
                  'rope_tile': 'region + repeat, vertical'},
        'frames': 'multi-frame pieces list their frame ids in `frames` on the first frame (base id, base_f1, base_f2)',
        'night': 'a hut\'s `night` entry is an ADDITIVE layer (blend add) trimmed to its lights: draw it at day_origin + night_offset with the same pivot rule (its pivot is relative to the trimmed image)',
    }
    for r in sorted(results, key=lambda x: x['id']):
        sid = r['id']
        if sid in ('treetop_sky', 'treetop_far'):
            continue                                              # backdrops are loaded by ArtCatalog.backdrop(), not as props
        e = {'file': f'{sid}.png', 'size': r['size'], 'pivot': r['pivot'], 'footprint': r['meta'].get('footprint', [1, 1])}
        for k, v in r['meta'].items():
            if k != 'footprint':
                e[k] = v
        if 'night' in r:
            nid = sid + '_night'
            e['night'] = nid
            e['night_offset'] = r['night']['offset']
            props[nid] = {'file': f'{nid}.png', 'size': r['night']['size'], 'pivot': [round(r['pivot'][0] - r['night']['offset'][0], 1), round(r['pivot'][1] - r['night']['offset'][1], 1)],
                          'footprint': e['footprint'], 'blend': 'add', 'kind': 'hut_night', 'night_of': sid, 'night_offset': r['night']['offset']}
        props[sid] = e
    return props


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('props.json:')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--stage', default=os.environ.get('TT_ART_STAGE'), help='stage folder (outside the project or tools/art/_stage[/x])')
    ap.add_argument('--only', default='', help='comma separated ids (default: everything)')
    ap.add_argument('--family', default='all', choices=['all', 'painted', 'model'])
    ap.add_argument('--jobs', type=int, default=4)
    ap.add_argument('--ss', type=int, default=3)
    ap.add_argument('--list', action='store_true')
    a = ap.parse_args()
    if a.list:
        print('\n'.join(ALL_IDS))
        return
    if not a.stage:
        raise SystemExit('bake_city: pass --stage DIR (outside the project, or tools/art/_stage/<name>) or set TT_ART_STAGE')
    stage = artpaths.assert_stage_dir(Path(a.stage), 'stage')
    out = stage / 'masters'
    ids = [i for i in a.only.split(',') if i] or ALL_IDS
    if a.family == 'painted':
        ids = [i for i in ids if i in ids_painted()]
    elif a.family == 'model':
        ids = [i for i in ids if i in ids_model()]
    unknown = [i for i in ids if i not in ALL_IDS]
    if unknown:
        raise SystemExit(f'bake_city: unknown ids {unknown}')
    t0 = time.time()
    jobs = [(i, str(out), a.ss) for i in ids]
    results = []
    with ProcessPoolExecutor(a.jobs) as ex:
        for r in ex.map(work, jobs):
            results.append(r)
            print('%-26s %4d x %-4d pivot %s  %.1fs%s' % (r['id'], r['size'][0], r['size'][1], r['pivot'], r['seconds'], '  +night %s' % r['night']['size'] if 'night' in r else ''), flush=True)
    # merge into the stage's props.json (a partial --only run keeps the other entries)
    pj = out / 'iso_props' / 'city' / 'props.json'
    old = json.loads(pj.read_text()) if pj.exists() else {}
    old_results = old.get('_results', {})
    for r in results:
        old_results[r['id']] = r
    props = build_props_json(list(old_results.values()))
    props['_results'] = old_results
    pj.parent.mkdir(parents=True, exist_ok=True)
    pj.write_text(json.dumps(props, indent=1, sort_keys=False))
    print('baked %d textures in %.0f s -> %s' % (len(results), time.time() - t0, out))


if __name__ == '__main__':
    main()
