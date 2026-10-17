#!/usr/bin/env python3
"""Pack reviewed ghost-specific painted drapes; only crop/register source artwork."""
import hashlib
import json
from pathlib import Path
from PIL import Image
from wardrobe import ROOT, OUT, cells, pigments, save

SOURCE = ROOT/'tools/art/drawn/sources/wardrobe/ghost-drape'
UPPER = ['shirt_linen','shirt_knit','shirt_smock','shirt_vest','dress_sun','dress_gown','dress_pinafore','pants_trousers']
SHOES = ['shoes_boots','shoes_clogs','shoes_slippers','shoes_wellies']
WIDTH = [1,.97,.84,.94,1,.94,.84,.97]

def build():
    upper=cells(SOURCE/'upper.png',8,7)+cells(SOURCE/'upper-se.png',8,1)
    rear=cells(SOURCE/'upper-rear.png',8,3)
    for row in range(3): upper[(row+3)*8:(row+4)*8]=rear[row*8:(row+1)*8]
    shoes=cells(SOURCE/'shoes.png',4,8)
    paintings={family:[upper[row*8+column] for row in range(8)] for column,family in enumerate(UPPER)}
    paintings.update({family:[shoes[row*4+column] for row in range(8)] for column,family in enumerate(SHOES)})
    for family in ['pants_shorts','pants_breeches','pants_dungarees']:
        paintings[family]=paintings['pants_trousers']
    manifest=json.loads((OUT/'manifest.json').read_text())
    anatomy=json.loads((OUT/'tailoring.json').read_text())['bodies']
    for body in ['ghost_bu','ghost_hviske']:
        record=manifest['bodies'][body]
        record['source_palettes']={}
        for family,drawings in paintings.items():
            atlas=Image.new('RGBA',(256,2048));fits=[]
            for direction,drawing in enumerate(drawings):
                center=anatomy[body]['centers'][direction]
                if family.startswith('pants_'):width,top,bottom=92,179,199
                elif family.startswith('shoes_'):width,top,bottom=96,181,201
                else:width,top,bottom=99,137,198 if family.startswith('dress_') else 195
                width=round(width*WIDTH[direction]);x=round(center-width/2)
                box=[x,top,width,bottom-top];fits.append(box)
                view=Image.new('RGBA',(256,256))
                if family.startswith('shoes_'):
                    # Register each painted tab at its natural aspect ratio.
                    # Pair-wide resizing crushed long tabs into horizontal scraps.
                    for side in range(2):
                        start=round(drawing.width*side/2);end=round(drawing.width*(side+1)/2)
                        part=drawing.crop((start,0,end,drawing.height))
                        part=part.crop(part.getbbox())
                        part.thumbnail((14,20),Image.Resampling.LANCZOS)
                        cx=center+round((-34 if side==0 else 34)*WIDTH[direction])
                        view.alpha_composite(part,(round(cx-part.width/2),181))
                else:
                    view.alpha_composite(drawing.resize((width,bottom-top),Image.Resampling.LANCZOS),(x,top))
                atlas.paste(view,(0,direction*256))
            record['fits'][family]=fits
            record['source_palettes'][family]=pigments(drawings)
            save(atlas,OUT/record['layers'][family])
    for path in SOURCE.glob('*.png'):
        manifest['sources'][str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
    (OUT/'manifest.json').write_text(json.dumps(manifest,separators=(',',':'))+'\n')
    print('Packed 15 flowing ghost garment families, 8 directions, on both ghost bodies.')

if __name__=='__main__': build()
