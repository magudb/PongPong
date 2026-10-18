#!/usr/bin/env python3
"""Manufacture native props/particles from the saved imagegen paintings only."""
from pathlib import Path
from io import BytesIO
import argparse, hashlib, json, re, sys
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'tools/art/features/dungeon'))
from make_weapons import trimmed, encoded, PRESET
HERE=Path(__file__).resolve().parent
OUT=ROOT/'assets/iso_props/farm_dress'
PIVOTS={'flower_box':[47,61],'garden_arch':[87,214],'fountain_small':[104,135],'royal_banner':[42,216], 'blossom_cluster':[61,58],'sunflower_row':[68,144],'leaf_pile':[60,47],'pumpkin_stack':[61,62],'snow_patch':[61,53],'bunting_x':[43,192],'vine_hang':[15,3],'pond_lily':[48,40]}

def build():
    prompts=json.loads((ROOT/'docs/art/farm-seasons/prompts.json').read_text())['items']
    files,props,sources={}, {}, {}
    for spec in prompts:
        source=ROOT/spec['source']
        image=trimmed(Image.open(source).convert('RGBA'))
        width,height=spec['size']
        margin=0 if spec['type']=='particle' else 2
        scale=min((width-margin*2)/image.width,(height-margin*2)/image.height)
        fitted=image.resize((max(1,round(image.width*scale)),max(1,round(image.height*scale))),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(width,height))
        canvas.alpha_composite(fitted,((width-fitted.width)//2,(height-fitted.height)//2))
        target=OUT/(spec['id']+'.webp')
        files[target]=encoded(canvas)
        files[target.with_suffix('.webp.import')]=PRESET.encode()
        sources[spec['id']]={'source':spec['source'],'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'size':spec['size'],'type':spec['type']}
        if spec['type']!='particle':
            catalog_id=spec.get('catalog_id',spec['id'])
            props[catalog_id]={'file':target.name,'size':spec['size'],'pivot':spec.get('pivot',PIVOTS.get(spec['id'])),'footprint':spec['footprint'],'illustration':spec['source']}
            assert props[catalog_id]['pivot'] is not None
    files[OUT/'props.json']=(json.dumps(props,indent=2)+'\n').encode()
    files[OUT/'props.json.import']=b'[remap]\nimporter="keep"\n'
    vram=sum(s['size'][0]*s['size'][1]*4 for s in sources.values())
    assert len(sources)==19 and len(props)==15 and vram<=4*1024*1024
    files[ROOT/'docs/art/farm-seasons/packing.json']=(json.dumps({'manufacturing':'alpha trim, uniform contain, centered placement, lossless WebP; no drawing or recolouring','sources':sources,'rgba_bytes':vram,'budget_bytes':4*1024*1024},indent=2)+'\n').encode()
    # Diagnostic montage only; backgrounds and labels never enter game textures.
    font=ImageFont.truetype(str(ROOT/'assets/fonts/IBMPlexMono-Regular.ttf'),14)
    sheet=Image.new('RGB',(4*390,5*440),'#f4e6c4');draw=ImageDraw.Draw(sheet)
    for i,spec in enumerate(prompts):
        x,y=(i%4)*390,(i//4)*440
        texture=Image.open(BytesIO(files[OUT/(spec['id']+'.webp')])).convert('RGBA')
        sheet.paste(texture,(x+(390-texture.width)//2,y+8),texture)
        draw.text((x+8,y+420),spec['id']+' '+str(spec['size']),font=font,fill='#2b2340')
    png=BytesIO();sheet.save(png,format='PNG');files[ROOT/'docs/art/farm-seasons/contact.png']=png.getvalue()
    return files

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');a=ap.parse_args();stale=[]
    for path,data in build().items():
        if a.check:
            if path.suffix=='.import' and path.exists() and path.name!='props.json.import':
                if not all(re.search('^'+re.escape(line)+'$',path.read_text(),re.M) for line in ['compress/mode=0','mipmaps/generate=false','process/fix_alpha_border=true']):stale.append(str(path.relative_to(ROOT)))
            elif path.suffix=='.png' and path.exists():
                with Image.open(path) as committed, Image.open(BytesIO(data)) as fresh:
                    if committed.mode!=fresh.mode or committed.size!=fresh.size or committed.tobytes()!=fresh.tobytes():stale.append(str(path.relative_to(ROOT)))
            elif not path.exists() or path.read_bytes()!=data:stale.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            if path.suffix!='.import' or not path.exists():path.write_bytes(data)
    if stale:raise SystemExit('stale: '+', '.join(stale))
    print('Twelve dress props, three tree variants and four painted particles '+('verified' if a.check else 'packed'))
if __name__=='__main__':main()
