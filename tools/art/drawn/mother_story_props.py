#!/usr/bin/env python3
"""Manufacture cutout props from saved imagegen paintings; no illustration edits."""
from pathlib import Path
from io import BytesIO
import argparse
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
DOC = ROOT/'docs/art/dark-forest-story'
OUT = ROOT/'assets/iso_props/forest_mother'
PRESET = '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\ncompress/mode=0\nmipmaps/generate=true\nprocess/fix_alpha_border=true\n'

def build():
    files = {}
    manifest = {}
    packing = {'tool':'built-in imagegen','operation':'alpha trim, uniform contain, bottom anchor, lossless export','items':{}}
    for row in json.loads((DOC/'production-prompts.json').read_text())['requests']:
        source = ROOT/row['source']
        image = Image.open(source).convert('RGBA')
        alpha = image.getchannel('A').point(lambda value: value if value >= 16 else 0)
        image.putalpha(alpha)
        bounds = alpha.getbbox()
        assert bounds
        image = image.crop(bounds)
        scale = row['edge']/max(image.size)
        image = image.resize(tuple(max(1,round(n*scale)) for n in image.size),Image.Resampling.LANCZOS)
        size = 384 if row['edge'] > 192 else 192
        canvas = Image.new('RGBA',(size,size))
        canvas.alpha_composite(image,((size-image.width)//2,size-12-image.height))
        blob = BytesIO()
        canvas.save(blob,format='WEBP',lossless=True,exact=True)
        name = row['id']+'.webp'
        files[OUT/name] = blob.getvalue()
        files[(OUT/name).with_suffix('.webp.import')] = PRESET.encode()
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        manifest[row['id']] = {'file':name,'size':[size,size],'pivot':[size/2,size-12],'footprint':[1,1],'proj':'ortho','source':row['source'],'source_sha256':digest}
        packing['items'][row['id']] = {'source':row['source'],'source_sha256':digest,'source_bounds':bounds,'scale':scale,'canvas':[size,size],'pivot':[size/2,size-12]}
    files[OUT/'props.json'] = (json.dumps(manifest,indent=2)+'\n').encode()
    files[DOC/'packing.json'] = (json.dumps(packing,indent=2)+'\n').encode()
    return files

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    stale = []
    for path,data in build().items():
        if args.check:
            if path.suffix == '.import' and path.exists():
                text = path.read_text()
                if not all(line in text for line in ['compress/mode=0','mipmaps/generate=true','process/fix_alpha_border=true']): stale.append(str(path))
            elif not path.exists() or path.read_bytes() != data: stale.append(str(path))
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            if path.suffix != '.import' or not path.exists(): path.write_bytes(data)
    if stale: raise SystemExit('Stale story exports: '+', '.join(stale))
    print('Four painted mother-story props '+('verified' if args.check else 'packed'))

if __name__ == '__main__': main()
