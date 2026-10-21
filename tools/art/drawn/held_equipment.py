#!/usr/bin/env python3
"""Pack the imagegen tool turnarounds and fit grips to the shipped body frames.

The paintings and stock bodies are inputs. This packs their alpha and records
body-specific sockets; it never redraws/recolors a body or uses inventory icons.
"""
from pathlib import Path
import hashlib
import json
import sys
import numpy as np
from PIL import Image
from scipy.signal import correlate2d

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'tools/art/drawn/sources/held_equipment/tools.png'
CARE = ROOT / 'tools/art/drawn/sources/held_equipment/care-tools.png'
OUT = ROOT / 'assets/held_equipment'
# Reviewed points in each body's own 256px idle canvas, in S..SE order.
# No runtime mirroring or universal body offset is involved.
GRIPS = {
    'fox': [[82,170],[70,171],[91,173],[88,175],[158,170],[186,171],[167,173],[176,171]],
    'monkey': [[83,180],[77,181],[100,181],[92,179],[167,181],[164,174],[155,181],[170,181]],
    'fairy': [[100,156],[91,156],[122,163],[112,163],[151,163],[167,163],[138,163],[164,156]],
    'fairy_birk': [[105,171],[95,168],[129,171],[99,171],[166,169],[152,169],[126,170],[154,169]],
    'hobbit_pip': [[87,167],[99,165],[120,168],[106,170],[162,168],[159,168],[136,168],[158,168]],
    'hobbit_bodil': [[95,159],[82,158],[121,159],[105,158],[155,159],[170,158],[135,159],[170,159]],
    'ghost_bu': [[88,163],[76,162],[112,161],[95,164],[160,161],[179,161],[143,161],[176,162]],
    'ghost_hviske': [[88,163],[76,162],[112,161],[95,164],[160,161],[179,161],[143,161],[176,162]],
}
ITEMS = [('hoe_wooden',100),('hoe_iron',100),
         ('watering_can_copper',56),('watering_can_gold',60),
         ('pickaxe_wooden',100),('pickaxe_copper',100),('pickaxe_iron',100),
         ('axe_wooden',82),('scythe',120),('fishing_rod',132),
         ('sword_rusty',86),('iron_sword',86),('brush',58),('milking_pail',60)]
sys.path.insert(0, str(ROOT / 'tools/import'))
from write_import_stubs import ensure_policy   # noqa: E402  the one texture import policy (atlas: lossless, no mipmaps)

def track(reference, frame, authored):
    """Match the authored hand's local painted patch in the actual baked frame.

    Search stays local: no face, opposite hand or distant garment can win. These
    are offline, explicit per-frame records; no matching runs during gameplay.
    """
    x,y = authored
    alpha = reference[:,:,3]
    if alpha[y,x] < 80:
        ys,xs = np.where(alpha[max(8,y-5):min(248,y+6),max(8,x-5):min(248,x+6)] > 120)
        if len(xs):
            xs += max(8,x-5); ys += max(8,y-5)
            nearest = np.argmin((xs-x)**2+(ys-y)**2);x,y=int(xs[nearest]),int(ys[nearest])
    radius=4; search=22
    template=reference[y-radius:y+radius+1,x-radius:x+radius+1].astype(float)/255
    window=frame[y-search-radius:y+search+radius+1,x-search-radius:x+search+radius+1].astype(float)/255
    # Premultiply to ignore arbitrary transparent RGB in the source paintings.
    template[:,:,:3] *= template[:,:,3:4];window[:,:,:3] *= window[:,:,3:4]
    score=np.zeros((search*2+1,search*2+1))
    weights=np.ones(template.shape[:2])
    for channel in range(4):
        patch=template[:,:,channel];values=window[:,:,channel]
        score += correlate2d(values*values,weights,mode='valid')-2*correlate2d(values,patch,mode='valid')+np.sum(patch*patch)
    yy,xx=np.mgrid[-search:search+1,-search:search+1]
    score += .002*(xx*xx+yy*yy)
    centers=window[radius:-radius,radius:-radius,3]
    score[centers < .32] = np.inf
    assert np.isfinite(score).any(), authored
    dy,dx=np.unravel_index(np.argmin(score),score.shape)
    return [int(x+dx-search),int(y+dy-search)]

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    atlas=Image.open(SOURCE).convert('RGBA')
    assert atlas.size==(1536,1024)
    # Companion paintings use four columns/four rows: eight brush views, then
    # eight pail views. Packing changes only their resolution and atlas address.
    care=Image.open(CARE).convert('RGBA')
    assert care.width == care.height
    cell=care.width/4
    combined=Image.new('RGBA',(1792,1024))
    combined.paste(atlas,(0,0))
    for item in range(2):
        for direction in range(8):
            index=item*8+direction; x=index%4*cell; y=index//4*cell
            combined.paste(care.crop((x,y,x+cell,y+cell)).resize((128,128),Image.Resampling.LANCZOS),((12+item)*128,direction*128))
    atlas=combined
    pixels=np.array(atlas);pixels[pixels[:,:,3]<24]=0
    pixels[:,:,3]=np.where(pixels[:,:,3]>=248,255,pixels[:,:,3])
    Image.fromarray(pixels).save(OUT/'tools.webp',lossless=True,exact=True)
    ensure_policy(OUT/'tools.webp')
    manifest={'version':1,'canvas':[256,256],'anchor':[128,200],
              'directions':['S','SW','W','NW','N','NE','E','SE'],
              'source':str(SOURCE.relative_to(ROOT)),
              'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'care_source':str(CARE.relative_to(ROOT)),
              'care_source_sha256':hashlib.sha256(CARE.read_bytes()).hexdigest(),
              'items':{},'bodies':{}}
    for col,(item,height) in enumerate(ITEMS):
        views=[]
        for direction in range(8):
            a=pixels[direction*128:(direction+1)*128,col*128:(col+1)*128,3]
            y,x=np.where(a>80);assert len(x)>150
            water=item.startswith('watering') or item == 'milking_pail'
            grip_y=int(y.min()+(y.max()-y.min())*(.12 if water else .80))
            xs=np.where(a[max(0,grip_y-2):grip_y+3].max(axis=0)>80)[0]
            grip=[int(np.median(xs)),grip_y]
            views.append({'rect':[col*128,direction*128,128,128], 'grip':grip,
                          'height':int(y.max()-y.min()+1)})
        manifest['items'][item]={'height':height,'views':views}
    count=0
    for body,points in GRIPS.items():
        folder=ROOT/'assets/isometric_characters'/body
        metadata=json.loads((folder/'animations.json').read_text())
        idle=np.array(Image.open(folder/'idle.webp').convert('RGBA'))
        clips={}
        for clip,spec in metadata['animations'].items():
            if clip == 'sleep':
                continue # equipment is put away, not fitted to sleeping poses
            sheet=np.array(Image.open(folder/spec['sheet']).convert('RGBA'))
            poses=[]
            for d in range(8):
                row=[]; reference=idle[d*256:(d+1)*256,:256]
                for f in range(spec['frames']):
                    frame=sheet[d*256:(d+1)*256,f*256:(f+1)*256]
                    grip=track(reference,frame,points[d])
                    assert frame[grip[1],grip[0],3]>40,(body,clip,d,f,grip)
                    row.append({'grip':grip,'depth':'rear' if d in [3,4,5] else 'front'})
                    count+=1
                poses.append(row)
            clips[clip]=poses
        manifest['bodies'][body]={'clips':clips}
    (OUT/'manifest.json').write_text(json.dumps(manifest,separators=(',',':'))+'\n')
    print(f'Packed {len(ITEMS)*8} dedicated held paintings and {count} body-specific frame poses; stock art untouched')

if __name__=='__main__':main()
