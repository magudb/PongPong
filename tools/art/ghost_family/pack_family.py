#!/usr/bin/env python3
"""Pack the four painted Natlys NPCs. Existing heroes and the drawn packer stay unchanged.
Run with tools/art/.venv/bin/python tools/art/ghost_family/pack_family.py.
Glide/hover adapted from design6/FINAL/family/art/pack_ghosts.py.
"""
import importlib.util
import argparse
import json
from pathlib import Path
import math
import numpy as np
from PIL import Image
from scipy import ndimage
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location('drawn_pack', ROOT / 'tools/art/drawn/pack.py')
pack = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pack)
IDS = ['ghostfam_dyne', 'ghostfam_gnist', 'ghostfam_silke', 'ghostfam_blund']
HEIGHTS = dict(zip(IDS, [163,182,158,114]))
HOVER = dict.fromkeys(IDS,4)
_stock_puppet = pack.puppet
_stock_fitted = pack.fitted
_current = {'id': None}
XX, YY = pack.XX, pack.YY


def ghost_puppet(base, clip, frame, frames, height, feet):
    if clip not in ('walk', 'run'):
        return _stock_puppet(base, clip, frame, frames, height, feet)
    phase = frame / max(frames, 1)
    wave = math.sin(phase * math.tau)
    sway = math.sin(phase * math.tau + math.pi / 2)
    u = (XX - 127.5) / (height * .5)
    v = (YY - (feet - height)) / height
    hem = np.clip((v - .62) / .36, 0, 1)
    arms = np.exp(-((np.abs(u) - .7) / .3) ** 2 - ((v - .69) / .16) ** 2)
    head = np.exp(-((v - .3) / .35) ** 4)
    amp = 3.0 if clip == 'walk' else 4.5
    dx = hem * sway * amp * .6 + head * wave * .8
    dy = arms * np.sign(u) * wave * 3.0
    sy = 1 - abs(wave) * .012
    lift = 2.0 + 2.0 * wave if clip == 'walk' else 3.0 + 3.0 * wave
    lean = wave * .02
    sample_y = feet + (YY - feet + lift - dy) / sy
    sample_x = 127.5 + (XX - 127.5 - dx - (feet - YY) * lean)
    a = np.asarray(base, dtype=np.float32) / 255
    a[:, :, :3] *= a[:, :, 3:4]
    result = np.stack([ndimage.map_coordinates(a[:, :, k], [sample_y, sample_x], order=1, mode='constant', cval=0) for k in range(4)], axis=-1)
    result[:, :, :3] /= np.maximum(result[:, :, 3:4], 1 / 255)
    return pack.outlined(Image.fromarray(np.uint8(np.clip(result * 255, 0, 255))))


def fitted_with_hover(image, height, feet):
    return _stock_fitted(image, height, feet - HOVER.get(_current['id'], 0))


def install_hooks():
    pack.HEIGHTS.update(HEIGHTS)
    pack.puppet = ghost_puppet
    pack.fitted = fitted_with_hover


def bootstrap_animations(out: Path, cid: str):
    """a missing animations.json of an NPC FAMILY folder is made from the villager clip set; the two player ghosts (11 clips, role player) are G-ghost-art's folders and are never bootstrapped"""
    folder = out / cid
    target = folder / 'animations.json'
    if target.exists():
        return
    if not cid.startswith('ghostfam_'):
        raise SystemExit(f'{target} does not exist: the player ghost folders belong to G-ghost-art (11 clips, role player); pack them over its installed folders')
    src = json.loads((ROOT / 'assets/isometric_characters/cat_morfar_mis/animations.json').read_text())
    src.update({'character': cid, 'family': 'ghost', 'clip_set': 'villager', 'flyer': False, 'role': 'npc', 'display_scale': 1.0, 'portrait': 'portrait.webp'})
    src.pop('illustration', None)
    folder.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(src, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', nargs='+', choices=IDS)
    args = parser.parse_args()
    install_hooks()
    views = pack.extract(HERE / 'sources/family_turnarounds.png', 4, 4)
    backs = pack.extract(HERE / 'sources/family_rears.png', 2, 2)
    silke = pack.extract(HERE / 'sources/silke_refined.png', 1, 5)
    for index, cid in enumerate(IDS):
        if args.only and cid not in args.only:
            continue
        bootstrap_animations(pack.CHARACTERS, cid)
        _current['id'] = cid
        drawings, north = (silke[:4], silke[4]) if cid == 'ghostfam_silke' else (views[index*4:index*4+4], backs[index])
        source = 'silke_refined' if cid == 'ghostfam_silke' else 'family_turnarounds'
        north_source = 'silke_refined' if cid == 'ghostfam_silke' else 'family_rears'
        pack.character(cid, drawings, source, north, north_source)
        path = pack.CHARACTERS / cid / 'animations.json'
        meta = json.loads(path.read_text())
        meta['illustration']['source'] = 'tools/art/ghost_family/sources/'+source+'.png'
        meta['illustration']['north_source'] = 'tools/art/ghost_family/sources/'+north_source+'.png'
        path.write_text(json.dumps(meta, indent=2)+'\n')
    path = ROOT / 'assets/isometric_characters/manifest_traetoppen.json'
    manifest = json.loads(path.read_text())
    for cid in IDS:
        meta = json.loads((pack.CHARACTERS/cid/'animations.json').read_text())
        manifest['characters'][cid] = {k: meta[k] for k in ['role','clip_set','family','flyer','display_scale','portrait','animations']}
    path.write_text(json.dumps(manifest,indent=1)+'\n')

if __name__ == '__main__':
    main()
