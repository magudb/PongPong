#!/usr/bin/env python3
"""Manifest/import texture arithmetic. Optional --paths measures a residency list.

S3TC uses 4x4 blocks (DXT1 opaque / DXT5 alpha); uncompressed RGBA uses four
bytes per pixel. All mip levels count. Tiles follow their no-mip import preset.
"""
import argparse
import json
import math
import re
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
MB=1024*1024

def size(path):
    path=ROOT/path.removeprefix('res://')
    with Image.open(path) as im:
        width,height=im.size
        alpha=im.convert('RGBA').getextrema()[3]!=(255,255)
    config=Path(str(path)+'.import').read_text()
    compressed=bool(re.search(r'compress/mode\s*=\s*2\b',config))
    mip=bool(re.search(r'mipmaps/generate\s*=\s*true',config))
    total=0;w=width;h=height
    while True:
        total += math.ceil(w/4)*math.ceil(h/4)*(16 if alpha else 8) if compressed else w*h*4
        if not mip or (w==1 and h==1):break
        w=max(1,w//2);h=max(1,h//2)
    return {'path':str(path.relative_to(ROOT)),'width':width,'height':height,'compressed':compressed,'mips':mip,'bytes':total}

def budget(paths=None):
    catalog=json.loads((ROOT/'docs/art/style-audit/current/catalog.json').read_text())
    props={r['id']:r for r in catalog['props']}
    ids=[k for k in json.loads((ROOT/'assets/iso_props/farm/props.json').read_text()) if not k.startswith('_')]
    farm=[props[k]['path'] for k in ids]
    farm += [r['far'] for r in catalog['backdrops'] if r['theme']=='farm']
    farm += [str(p.relative_to(ROOT)) for p in (ROOT/'assets/backdrops').glob('farm_*') if p.suffix in ('.webp','.png')]
    rows=[size(p) for p in sorted(set(paths if paths is not None else farm))]
    # Authored reference envelope; actual ordinary/festival scenes are measured
    # by town_budgets in a real renderer, never inferred from this historic row.
    result={'textures':rows,'bytes':sum(r['bytes'] for r in rows),'mb':sum(r['bytes'] for r in rows)/MB,'reference_rows':{'ordinary':307.9,'festival_20':352.0,'nothing_freed_20':381.7,'process_cap':400.0,'ordinary_cap':320.0,'festival_cap':360.0}}
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--paths',type=Path);p.add_argument('--out',type=Path);a=p.parse_args()
    rows=json.loads(a.paths.read_text()) if a.paths else None
    result=budget(rows)
    if a.out:a.out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
    raise SystemExit(not (result['mb']<=20 if rows is None else True))
