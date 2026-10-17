#!/usr/bin/env python3
"""Fit saved imagegen paintings into native icon cells; no drawing/recolouring."""
from pathlib import Path
import argparse, hashlib, json, re, sys
from PIL import Image
ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools/art/features/dungeon'))
from make_weapons import contained, trimmed, encoded, PRESET

def build():
    files, manifest = {}, {'version': 1, 'size': [128,128], 'source_tool': 'built-in imagegen', 'items': {}}
    for item in ['hjertebuket','loefteagern']:
        source = ROOT / 'tools/art/drawn/sources/relationships' / (item+'.png')
        target = ROOT / 'assets/icons/items' / (item+'.webp')
        files[target] = encoded(contained(trimmed(Image.open(source).convert('RGBA')),108))
        files[target.with_suffix('.webp.import')] = PRESET.encode()
        manifest['items'][item] = {'file': target.name, 'rarity':'normal', 'source':str(source.relative_to(ROOT)), 'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
    files[ROOT / 'tools/art/features/social/relationships.json'] = (json.dumps(manifest,indent=2)+'\n').encode()
    return files

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args();stale=[]
    for path,data in build().items():
        if args.check:
            if path.suffix == '.import' and path.exists():
                if not all(re.search('^'+re.escape(line)+'$' ,path.read_text(),re.M) for line in ['compress/mode=0','mipmaps/generate=false','process/fix_alpha_border=true']): stale.append(str(path))
            elif not path.exists() or path.read_bytes()!=data: stale.append(str(path))
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            if path.suffix!='.import' or not path.exists():path.write_bytes(data)
    if stale:raise SystemExit('stale: '+', '.join(stale))
    print('Two painted relationship icons '+('verified' if args.check else 'packed'))
if __name__=='__main__':main()
