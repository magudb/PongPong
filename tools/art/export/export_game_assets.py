#!/usr/bin/env python3
"""Turn the lossless PNG masters into the game-ready asset tree (WebP q97 method 4 sprites, lossless icons, PNG tiles/props).

  python tools/art/export/export_game_assets.py --src tools/art/_stage/masters --dst tools/art/_stage/assets
         [--only ID ...] [--only-icons NAME ...] [--classes characters,portraits,tiles,props,icons,keyart] [--glb DIR] [--jobs N]

SRC and DST both mirror res://assets and must be OUTSIDE every folder Godot scans (the default is tools/art/_stage,
hidden by tools/art/.gdignore; a scanned destination is refused).  This script never writes into the project's assets/:
export/install_assets.py copies the staged result to the contract paths.

  masters/isometric_characters/<id>/*.png + animations.json
      -> assets/isometric_characters/<id>/<clip>.webp  portrait.webp  animations.json  <clip>.webp.import (S3TC stub)
         animations.json gets role, clip_set, family, flyer, portrait, display_scale (1.0), glow from the generator's rig stats
         ONLY the sheets that animations.json names (plus portrait) are exported: a stale *.png in the masters folder is ignored
         assets/isometric_characters/manifest_traetoppen.json lists the exported characters (install merges it)
  masters/portraits/<id>.png         -> assets/portraits/<id>.webp                     (bust portraits of the 12 pack characters)
  masters/iso_tiles/*.png|json       -> copied; atlases get a no-mipmap stub (review R.1)
  masters/iso_props/**               -> copied
  masters/icons/items/*.png          -> assets/icons/items/<id>.webp  LOSSLESS (+ icons.json with .webp names)
  masters/ui/keyart/**.png           -> assets/ui/keyart/**.webp       (q97)

Lifted from the art spike's export_game_assets.py.  Changes (P08): destinations follow the contract paths of plan 6.2
(icons/items instead of ui/icons, portraits, keyart), the S3TC import stub is written next to every character clip sheet
(review R.7), the tree is staged outside Godot's reach (R.8), display_scale is 1.0 unless a model sets cam_scale (the
spike's 1.47/cam_scale was inverted; any other value is reported and rejected by validate_new_assets.py).
Fix round (P08 review): only the sheets listed in animations.json are converted (a clip set that shrank or a --clips re-bake can
no longer ship unlisted sheets with S3TC stubs); a listed sheet that is missing is an error; character ids must be [a-z0-9_]+;
the baker's `partial` flag is dropped (an incomplete export then fails the role clip-set validation instead of passing it).
"""
import argparse, json, shutil, sys, time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from PIL import Image

sys.path.append(str(Path(__file__).resolve().parents[1] / 'core'))
import artpaths                       # noqa: E402
import artcontract as ac              # noqa: E402
sys.path.append(str(Path(__file__).resolve().parent))
import import_stubs                   # noqa: E402


def webp(src, dst, q=ac.WEBP_QUALITY, lossless=False):
    im = Image.open(src).convert('RGBA')
    if lossless:
        im.save(dst, 'WEBP', lossless=True, quality=100, method=ac.WEBP_METHOD)
    else:
        im.save(dst, 'WEBP', quality=q, method=ac.WEBP_METHOD, alpha_quality=100)
    return Path(dst).stat().st_size


def _job(t):
    (src, dst, q, lossless), key = t
    return key, webp(src, dst, q, lossless)


def infer_clip_set(clips):
    """Best clip-set guess for a folder whose rig stats are unknown: the set whose clip list equals the folder's clips."""
    cs = set(clips)
    for name, want in ac.CLIP_SETS.items():
        if want is not None and cs == set(want):
            return name
    return 'full'


def rig_stats(glb: Path, cid: str):
    p = glb / f'{cid}_rig.json'
    return json.loads(p.read_text())['stats'] if p.exists() else None


def export_characters(src: Path, dst: Path, glb: Path, only, quality, jobs, warn):
    root = src / 'isometric_characters'
    if not root.is_dir():
        return {}, {}
    manifest = {'format_version': 2, 'cell_size': [ac.CELL, ac.CELL], 'pivot': list(ac.PIVOT), 'directions': ac.DIRECTIONS,
                'rendering': 'orthographic isometric, 36 degree camera elevation, 87.07 px/m', 'characters': {}}
    totals, work = {}, []
    for d in sorted(p for p in root.iterdir() if p.is_dir() and (p / 'animations.json').exists()):
        if only and d.name not in only:
            continue
        if not ac.valid_id(d.name):
            raise SystemExit(f'ERROR: masters folder "{d.name}" is not a valid character id ([a-z0-9_]+, lower case): refusing to export it')
        meta = json.loads((d / 'animations.json').read_text())
        sources = {}                                 # clip -> master PNG named by animations.json
        for k, v in meta['animations'].items():
            sheet = v.get('sheet')
            if not isinstance(sheet, str) or Path(sheet).name != sheet:
                raise SystemExit(f'ERROR: {d.name}/animations.json: clip {k} has a bad sheet name {sheet!r}')
            if not (d / sheet).is_file():
                raise SystemExit(f'ERROR: {d.name}: animations.json lists {k} -> {sheet} but {d / sheet} does not exist (re-bake the character)')
            sources[k] = d / sheet
        out = dst / 'isometric_characters' / d.name
        if out.exists():                      # a stage folder is rebuilt from the masters, never merged with older bakes
            shutil.rmtree(out)
        out.mkdir(parents=True)
        for k, f in sources.items():          # only what animations.json names: unlisted *.png of the folder (stale bakes) stay behind
            work.append(((str(f), str(out / (k + '.webp')), quality, False), d.name))
        if (d / 'portrait.png').exists():
            work.append(((str(d / 'portrait.png'), str(out / 'portrait.webp'), quality, False), d.name))
        for k, v in meta['animations'].items():
            v['sheet'] = k + '.webp'
        meta.pop('partial', None)             # the baker's --clips flag: an incomplete export must fail the clip-set validation
        st = rig_stats(glb, d.name)
        if st is None:
            warn(f'{d.name}: no {d.name}_rig.json in {glb}: role/flyer/glow guessed from the clip list')
            st = {}
        clip_set = st.get('clip_set') or meta.get('clip_set') or infer_clip_set(meta['animations'])
        meta['role'] = ac.ROLE_OF_CLIP_SET.get(clip_set, 'player')
        meta['clip_set'] = clip_set
        meta['family'] = st.get('family') or meta.get('family', d.name)
        meta['portrait'] = 'portrait.webp'
        if not (d / 'portrait.png').exists():
            warn(f'{d.name}: no portrait.png in the masters (bake with preview on); animations.json still names portrait.webp')
        meta['flyer'] = bool(st.get('flyer') or meta.get('flyer')) or any(c in meta['animations'] for c in ac.FLIGHT_CLIPS)
        cam = st.get('cam_scale')
        meta['display_scale'] = 1.0 if not cam else round(cam / ac.CAM_HALF_HEIGHT_M, 4)
        if cam:
            warn(f'{d.name}: cam_scale {cam} gives display_scale {meta["display_scale"]}; the contract says 1.0 (sprites are never scaled '
                 f'individually): size the model with m.height/m.base_height instead')
        if st.get('glow'):
            meta['glow'] = {'color': '#' + st['glow'][0], 'radius_px': st['glow'][1], 'strength': st['glow'][2]}
        (out / 'animations.json').write_text(json.dumps(meta, indent=1))
        manifest['characters'][d.name] = {k: meta[k] for k in ('role', 'clip_set', 'family', 'flyer', 'display_scale', 'portrait')}
        manifest['characters'][d.name]['animations'] = meta['animations']
        totals[d.name] = 0
    t0 = time.time()
    with ProcessPoolExecutor(jobs) as ex:
        for cid, nbytes in ex.map(_job, work):
            totals[cid] = totals.get(cid, 0) + nbytes
    print('encoded %d character sheets in %.0f s (WebP q%d method %d)' % (len(work), time.time() - t0, quality, ac.WEBP_METHOD))
    stubs = {}
    for cid in totals:
        stubs[cid] = import_stubs.write_character_stubs(dst / 'isometric_characters' / cid)
    if manifest['characters']:
        (dst / 'isometric_characters').mkdir(parents=True, exist_ok=True)
        (dst / 'isometric_characters' / 'manifest_traetoppen.json').write_text(json.dumps(manifest, indent=1))
    return totals, stubs


def export_flat(src: Path, dst: Path, sub: str, ext_in: str, to_webp, lossless, only, quality, jobs):
    """Copy (or re-encode) assets/<sub>/** .  Returns bytes written."""
    s, o = src / sub, dst / sub
    if not s.is_dir():
        return None
    o.mkdir(parents=True, exist_ok=True)
    work, size = [], 0
    for f in sorted(p for p in s.rglob('*') if p.is_file() and not p.name.startswith('.')):
        rel = f.relative_to(s)
        if only and f.stem not in only and f.suffix != '.json':
            continue
        (o / rel).parent.mkdir(parents=True, exist_ok=True)
        if f.suffix == '.json':
            text = f.read_text()
            if to_webp:
                try:                                # icons.json etc.: point at the re-encoded files
                    data = json.loads(text)
                    text = json.dumps(_rewrite_ext(data), indent=1)
                except ValueError:
                    pass
            (o / rel).write_text(text); size += len(text)
        elif f.suffix == ext_in and to_webp:
            work.append(((str(f), str((o / rel).with_suffix('.webp')), quality, lossless), sub))
        else:
            shutil.copy(f, o / rel); size += f.stat().st_size
    with ProcessPoolExecutor(jobs) as ex:
        for _, nbytes in ex.map(_job, work):
            size += nbytes
    return size


def _rewrite_ext(x):
    if isinstance(x, dict):
        return {k: _rewrite_ext(v) for k, v in x.items()}
    if isinstance(x, list):
        return [_rewrite_ext(v) for v in x]
    if isinstance(x, str) and x.endswith('.png'):
        return x[:-4] + '.webp'
    return x


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('Lifted from')[0], formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--src', default=None, help='masters tree (default tools/art/_stage/masters)')
    ap.add_argument('--dst', default=None, help='game-ready tree (default tools/art/_stage/assets); must not be scanned by Godot')
    ap.add_argument('--glb', default=None, help='generator GLB/rig folder (default tools/art/_stage/glb)')
    ap.add_argument('--quality', type=int, default=ac.WEBP_QUALITY); ap.add_argument('--jobs', type=int, default=6)
    ap.add_argument('--only', nargs='*', help='character ids / portrait ids to export (default: every folder of the masters)')
    ap.add_argument('--only-icons', nargs='*', help='icon names to export (default: all icons of the masters; tiles, props and key art are always complete)')
    ap.add_argument('--classes', default='characters,portraits,tiles,props,icons,keyart', help='comma list of what to export (default all)')
    a = ap.parse_args()
    classes = set(c for c in a.classes.split(',') if c)
    stage = artpaths.Stage()
    src = Path(a.src) if a.src else stage.masters
    dst = artpaths.assert_stage_dir(Path(a.dst) if a.dst else stage.assets, 'export destination')
    glb = Path(a.glb) if a.glb else stage.glb
    warnings = []

    def warn(msg):
        warnings.append(msg); print('WARNING:', msg)

    dst.mkdir(parents=True, exist_ok=True)
    report = {}
    totals, stubs = export_characters(src, dst, glb, a.only, a.quality, a.jobs, warn) if 'characters' in classes else ({}, {})
    if totals:
        print('characters: %d exported, %.1f MB' % (len(totals), sum(totals.values()) / 1e6))
        for cid, n in totals.items():
            clips = [f for f in (dst / 'isometric_characters' / cid).glob('*.webp') if f.name != 'portrait.webp']
            print('  %-18s %6.2f MB  clips %-2d  stubs %d' % (cid, n / 1e6, len(clips), len(stubs.get(cid, []))))
    for sub, ext_in, to_webp, lossless, label, only in (('portraits', '.png', True, False, 'portraits', a.only),
                                                        ('iso_tiles', '.png', False, False, 'tiles', None),
                                                        ('iso_props', '.png', False, False, 'props', None),
                                                        ('icons/items', '.png', True, True, 'icons', a.only_icons),
                                                        ('ui/keyart', '.png', True, False, 'keyart', None)):
        if label not in classes:
            continue
        sz = export_flat(src, dst, sub, ext_in, to_webp, lossless, only, a.quality, a.jobs)
        if sz is not None:
            print('%s: %.2f MB' % (label, sz / 1e6))
    if a.only and classes & {'characters', 'portraits'}:            # asked for ids that were not found: that is an error, not "done"
        have = set(totals)
        if 'portraits' in classes and (src / 'portraits').is_dir():
            have |= {f.stem for f in (src / 'portraits').glob('*.png')}
        missing = [i for i in a.only if i not in have]
        if missing:
            raise SystemExit(f'ERROR: --only {" ".join(missing)}: nothing to export (no masters folder {src}/isometric_characters/<id> '
                             f'with an animations.json, and no bust {src}/portraits/<id>.png)')
    if 'tiles' in classes and (dst / 'iso_tiles').is_dir():
        import_stubs.write_tile_stubs(dst / 'iso_tiles')
    print('export done:', dst, '(%d warning%s)' % (len(warnings), '' if len(warnings) == 1 else 's'))


if __name__ == '__main__':
    main()
