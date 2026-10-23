#!/usr/bin/env python3
"""Register painted clothing turnarounds to each shipped hero's body canvas.

Artwork comes from saved imagegen paintings. This packs static directional fits;
the live shaders use the existing stock puppet field and animation clock. No
original character, portrait or inventory icon is modified.
"""
from pathlib import Path
import json
import hashlib
import io
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from pack import fitted, puppet, ensure_policy
from held_equipment import GRIPS, track

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT/'tools/art/drawn/sources/wardrobe'
OUT = ROOT/'assets/wardrobe'
DOC = ROOT/'docs/art/wardrobe'
# Individual body proportions, never a shared stretched character rig.
# shirt=(x,y,w,h), hips=(x,y,w,h), feet=(x,y,w,h), head=(x,y,w,h).
FITS = {
 'fox':dict(shirt=[86,143,86,39],hips=[94,177,70,23],feet=[94,187,70,18],head=[76,48,105,47],face=94,centers=[128,121,124,128,128,128,132,135]),
 'monkey':dict(shirt=[87,143,82,44],hips=[97,179,62,22],feet=[91,188,74,17],head=[71,51,114,45],face=98,centers=[128,121,128,130,128,126,128,135]),
 'fairy':dict(shirt=[96,127,64,49],hips=[103,173,50,23],feet=[98,189,60,15],head=[77,42,102,50],face=90,centers=[128,121,127,131,128,125,129,135]),
 'fairy_birk':dict(shirt=[96,115,64,64],hips=[103,175,50,24],feet=[100,189,56,15],head=[79,42,98,47],face=82,centers=[128,121,128,130,128,126,128,135]),
 'hobbit_pip':dict(shirt=[91,128,74,55],hips=[99,179,58,23],feet=[95,187,66,17],head=[57,38,142,51],face=90,centers=[128,123,129,130,128,126,127,133]),
 'hobbit_bodil':dict(shirt=[92,115,72,62],hips=[101,174,54,26],feet=[97,187,62,17],head=[63,40,130,49],face=80,centers=[128,123,130,130,128,126,126,133]),
 'ghost_bu':dict(shirt=[81,137,94,39],hips=[91,173,75,15],feet=[90,188,79,17],head=[89,42,78,39],face=82,centers=[128,129,135,133,128,125,121,125]),
 'ghost_hviske':dict(shirt=[81,137,94,39],hips=[91,173,75,15],feet=[90,188,79,17],head=[89,42,78,39],face=82,centers=[128,129,135,133,128,125,121,125]),
}
# New safe-base paintings have their own reviewed hand centres. Stock grip
# points can land on a thigh here, exposing skin through a gown or trousers.
SAFE_GRIPS = {
 'fairy':[[95,153],[92,153],[134,157],[93,153],[161,154],[166,155],[130,158],[163,154]],
 'fairy_birk':[[95,157],[103,155],[133,157],[105,154],[162,157],[153,155],[122,157],[153,156]],
 'hobbit_pip':[[95,157],[100,155],[122,158],[103,158],[158,158],[157,158],[134,158],[155,156]],
 'hobbit_bodil':[[95,157],[100,155],[122,157],[105,157],[156,157],[156,157],[134,157],[157,156]],
}

def rows(alpha):
    occupied=ndimage.binary_closing(alpha.sum(1)>alpha.shape[1]*.015,structure=np.ones(5))
    labels,_=ndimage.label(occupied)
    return [(s[0].start,s[0].stop) for s in ndimage.find_objects(labels) if s[0].stop-s[0].start>12]

def cells(path, columns, expected_rows):
    """Whole components stay together, including paired footwear and ornaments."""
    pixels=np.array(Image.open(path).convert('RGBA'));alpha=pixels[:,:,3]>24
    bands=rows(alpha)
    assert len(bands)==expected_rows,(path,len(bands),expected_rows)
    centers=[(a+b)/2 for a,b in bands]
    labels,_=ndimage.label(alpha)
    boxes=ndimage.find_objects(labels)
    owners=np.zeros(len(boxes)+1,dtype=np.int16)
    for label,box in enumerate(boxes,1):
        if box is None:continue
        y=(box[0].start+box[0].stop)/2;x=(box[1].start+box[1].stop)/2
        row=min(range(expected_rows),key=lambda i:abs(centers[i]-y))
        col=min(columns-1,int(x/pixels.shape[1]*columns))
        owners[label]=row*columns+col+1
    assigned=owners[labels]
    result=[]
    for index in range(columns*expected_rows):
        mask=(assigned==index+1)&alpha
        y,x=np.where(mask);assert len(x)>40,(path,index)
        box=(max(0,int(x.min())-1),max(0,int(y.min())-1),min(pixels.shape[1],int(x.max())+2),min(pixels.shape[0],int(y.max())+2))
        x0,y0,x1,y1=box;crop=pixels[y0:y1,x0:x1].copy()
        crop[:,:,3] *= mask[y0:y1,x0:x1]
        crop[crop[:,:,3]==0,:3]=0
        result.append(Image.fromarray(crop))
    return result

def pigments(drawings):
    """Three actual chroma families; retain painted RGB, grain and warm ink."""
    pixels=np.concatenate([np.array(im).reshape(-1,4) for im in drawings]).astype(float)/255
    rgb=pixels[pixels[:,3]>.9,:3]
    rgb=rgb[np.dot(rgb,[.299,.587,.114])>.32][::11]
    if len(rgb)>4000:rgb=rgb[::int(np.ceil(len(rgb)/4000))]
    assert len(rgb)>10
    chroma=rgb/np.maximum(rgb.max(1,keepdims=True),.001)
    seeds=[int(np.argmin(np.linalg.norm(chroma-np.median(chroma,axis=0),axis=1)))]
    for _ in range(2):seeds.append(int(np.argmax(np.min([np.sum((chroma-chroma[i])**2,axis=1) for i in seeds],axis=0))))
    means=chroma[seeds].copy()
    for _ in range(12):
        labels=np.argmin(np.sum((chroma[:,None,:]-means[None,:,:])**2,axis=2),axis=1)
        for i in range(3):
            if np.any(labels==i):means[i]=chroma[labels==i].mean(0)
    order=sorted(range(3),key=lambda i:-np.sum(labels==i))
    result=[rgb[labels==i].mean(0) if np.any(labels==i) else rgb.mean(0) for i in order]
    # Highlights of the same fabric are not a second dye region. Replace
    # near-identical chroma clusters with the distinct band/brass pigments.
    alternatives=[np.array(c) for c in [[.42,.53,.38],[.77,.55,.24],[.91,.84,.69],[.48,.31,.18]]]
    chosen=[result[0]]
    chrom=lambda c:c/max(c.max(),.001)
    for candidate in result[1:]:
        if min(np.linalg.norm(chrom(candidate)-chrom(c)) for c in chosen)<.18:
            candidate=max(alternatives,key=lambda a:min(np.linalg.norm(chrom(a)-chrom(c)) for c in chosen))
        chosen.append(candidate)
    return [[round(float(v),5) for v in c] for c in chosen]

def save(image,path):
    path.parent.mkdir(parents=True,exist_ok=True)
    encoded=io.BytesIO();image.save(encoded,format='WEBP',lossless=True,method=2,exact=True)
    if not path.exists() or path.read_bytes()!=encoded.getvalue():path.write_bytes(encoded.getvalue())
    ensure_policy(path)

def rect(body, family, direction):
    fit=FITS[body]
    if family.startswith('hat_') or family.startswith('circlet_'):key='head'
    elif family.startswith('pants_'):key='hips'
    elif family.startswith('shoes_'):key='feet'
    else:key='shirt'
    x,y,w,h=fit[key];shift=fit['centers'][direction]-128
    factor=[1,.94,.78,.90,1,.90,.78,.94][direction] if key!='head' else [1,.98,.92,.98,1,.98,.92,.98][direction]
    width=round(w*factor);x=round(x+(w-width)/2+shift);w=width
    if family=='pants_dungarees':y=fit['shirt'][1]+5;h=fit['hips'][1]+fit['hips'][3]-y
    if family.startswith('dress_'):
        x-=5;w+=10;y-=1;h=197-y if family!='dress_gown' else 201-y
        if body.startswith('ghost'):h=47
    if family=='shirt_smock':h+=4
    if family=='shirt_vest':x+=3;w-=6
    if family=='hat_wizard':y-=22;h+=22
    if family=='hat_chef':y-=12;h+=12
    if family=='hat_hood':h=fit['shirt'][1]-y+9
    if family.startswith('circlet_'):y+=h-19;h=23
    if family.startswith('neck'):
        x=round(fit['centers'][direction]-w*.22);y=fit['shirt'][1]-3;w=round(w*.44);h=25
    if family.startswith('ears_'):
        x=fit['head'][0]+shift+5;y=fit['face']+22;w=fit['head'][2]-10;h=14
    if family.startswith('bracelet_') or family.startswith('wrist_'):
        gx,gy=SAFE_GRIPS.get(body,GRIPS[body])[direction];x=gx-8;y=gy-9;w=17;h=10
    return [x,y,w,h]

def mask_for(body,base,direction):
    fit=FITS[body]
    anatomy=json.loads((OUT/'tailoring.json').read_text())['bodies'][body]
    center=anatomy['centers'][direction]
    head_center=anatomy['head_centers'][direction]
    mask=Image.new('L',(256,256));draw=ImageDraw.Draw(mask)
    # Face/chin follow the head, not the canvas centre or the old shirt box.
    head_width=fit['head'][2]-16
    draw.ellipse((head_center-head_width/2,fit['face']-12,
                  head_center+head_width/2,anatomy['neck']+3),fill=255)
    hands=Image.new('L',(256,256));hd=ImageDraw.Draw(hands)
    gx,gy=SAFE_GRIPS.get(body,GRIPS[body])[direction]
    if direction not in [3,4,5]:
        hd.ellipse((gx-8,gy-8,gx+8,gy+8),fill=255)
        if direction in [0,1,7]:
            other=2*center-gx
            hd.ellipse((other-8,gy-8,other+8,gy+8),fill=255)
    hand_pixels=np.array(hands)
    rgb=np.array(base).astype(int)
    if body in SAFE_GRIPS:
        skin=(rgb[:,:,0]-rgb[:,:,1]>22)&(rgb[:,:,1]-rgb[:,:,2]>18)&(rgb[:,:,0]>170)
        skin=ndimage.binary_dilation(skin,iterations=1)
        hand_pixels[~skin]=0
    elif body=='fox':
        # Brown paws, not a circular orange forearm cut through the fabric.
        paw=(rgb[:,:,0]-rgb[:,:,1]>12)&(rgb[:,:,1]-rgb[:,:,2]>10)&(rgb[:,:,0]<170)
        hand_pixels[~ndimage.binary_dilation(paw,iterations=1)]=0
    mask=Image.fromarray(np.maximum(np.array(mask),hand_pixels));draw=ImageDraw.Draw(mask)
    if body=='fox':
        cx=head_center
        for poly in [[(cx-55,91),(cx-51,28),(cx-8,74)],[(cx+15,74),(cx+58,28),(cx+66,94)]]:
            draw.polygon(poly,fill=255)
    if body=='monkey':
        for x in [head_center-56,head_center+56]:draw.ellipse((x-21,91,x+21,138),fill=255)
    if body=='fairy':draw.ellipse((139,28,176,66),fill=255)
    a=np.array(mask)
    if body in ['fairy','fairy_birk'] and direction in [3,4,5]:
        wings=(rgb[:,:,2]>rgb[:,:,0]+8)&(np.indices(a.shape)[0]>100)
        a[wings]=255
    if body=='hobbit_bodil':
        yy,xx=np.indices(a.shape);braids=((xx<106)|(xx>151))&(yy>100)&(yy<187)&(rgb[:,:,0]>rgb[:,:,1]*1.16)&(rgb[:,:,0]>rgb[:,:,2]*1.25)
        a[braids]=255
    if body.startswith('hobbit'):
        yy,xx=np.indices(a.shape);a[(yy>=193)&(xx>77)&(xx<179)]=255
    result=Image.new('RGBA',(256,256),(255,255,255,0));result.putalpha(Image.fromarray(a));return result


def build_masks():
    """Technical alpha masks only; never repaint the generated character art."""
    manifest=json.loads((OUT/'manifest.json').read_text())
    for body,record in manifest['bodies'].items():
        path=OUT/record['base'] if record['base'] else ROOT/'assets/isometric_characters'/body/'idle.webp'
        source=Image.open(path).convert('RGBA')
        mask=Image.new('RGBA',(256,2048))
        for direction in range(8):
            base=source.crop((0,direction*256,256,direction*256+256))
            mask.paste(mask_for(body,base,direction),(0,direction*256))
        save(mask,OUT/record['mask'])
        print(body,'technical face/paw/hair occlusion',flush=True)

def build():
    spec=json.loads((DOC/'prompts.json').read_text())
    normal={};ghost={};sources={}
    for name,columns in spec['garment_columns'].items():
        path=ROOT/spec['selected_garments'][name];nrows=7 if name=='ghost_lower' else 8
        drawings=cells(path,len(columns),nrows)
        if name=='ghost_lower':drawings+=cells(ROOT/spec['ghost_lower_se_source'],len(columns),1)
        target=ghost if name.startswith('ghost') else normal
        for col,description in enumerate(columns):
            family=description.split(' ',1)[0]
            target[family]=[drawings[row*len(columns)+col] for row in range(8)]
        sources[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
    assert len(normal)==30 and len(ghost)==16
    manifest={'version':1,'canvas':[256,256],'anchor':[128,200],'directions':['S','SW','W','NW','N','NE','E','SE'],
              'animation':'existing body clock; same inverse puppet field in wardrobe_motion.gdshaderinc',
              'sources':sources,'designs':{family:{'source_palette':pigments(drawings)} for family,drawings in normal.items()},'bodies':{}}
    for body,fit in FITS.items():
        height=160 if body.startswith('ghost') else 168
        bases=[];base_path=spec['selected_bases'].get(body)
        if base_path:
            bases=[fitted(im,height,200) for im in cells(ROOT/base_path,4,2)]
            manifest['sources'][base_path]=hashlib.sha256((ROOT/base_path).read_bytes()).hexdigest()
        else:
            idle=Image.open(ROOT/'assets/isometric_characters'/body/'idle.webp').convert('RGBA')
            bases=[idle.crop((0,d*256,256,d*256+256)) for d in range(8)]
        combined=Image.new('RGBA',(256,2048));mask=Image.new('RGBA',(256,2048))
        for direction,base in enumerate(bases):
            combined.paste(base,(0,direction*256));mask.paste(mask_for(body,base,direction),(0,direction*256))
        eye_y=92 if body in ['fairy_birk','hobbit_bodil'] else 102 if body in ['fairy','hobbit_pip'] else 117
        record={'height':height,'base':f'{body}/base.webp' if base_path else '', 'mask':f'{body}/occluder.webp','face_rect':[106,eye_y-6,44,24],'layers':{},'fits':{}}
        if base_path:save(combined,OUT/record['base'])
        save(mask,OUT/record['mask'])
        if base_path:
            metadata=json.loads((ROOT/'assets/isometric_characters'/body/'animations.json').read_text())
            record['held_clips']={}
            record['hand_size']=10
            for clip,animation in metadata['animations'].items():
                if clip=='sleep':continue
                poses=[]
                for direction,base in enumerate(bases):
                    reference=np.array(base)
                    frames=[]
                    for frame in range(animation['frames']):
                        painted=np.array(puppet(base,clip,frame,animation['frames'],height,200))
                        grip=track(reference,painted,SAFE_GRIPS[body][direction])
                        frames.append({'grip':grip,'depth':'rear' if direction in [3,4,5] else 'front'})
                    poses.append(frames)
                record['held_clips'][clip]=poses
        for family,drawings in normal.items():
            selected=ghost.get(family,drawings) if body.startswith('ghost') else drawings
            atlas=Image.new('RGBA',(256,2048));fits=[]
            for direction,drawing in enumerate(selected):
                box=rect(body,family,direction);x,y,w,h=box
                view=Image.new('RGBA',(256,256))
                view.alpha_composite(drawing.resize((w,h),Image.Resampling.LANCZOS),(x,y))
                atlas.paste(view,(0,direction*256));fits.append(box)
            filename=f'{body}/{family}.webp';save(atlas,OUT/filename)
            record['layers'][family]=filename;record['fits'][family]=fits
        manifest['bodies'][body]=record
        print(body,len(record['layers']),'fitted families',flush=True)
    extra=ROOT/spec['ghost_lower_se_source'];manifest['sources'][str(extra.relative_to(ROOT))]=hashlib.sha256(extra.read_bytes()).hexdigest()
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'manifest.json').write_text(json.dumps(manifest,separators=(',',':'))+'\n')
    print('Packed all 30 garment families on all eight heroes; stock assets untouched.')
    if spec.get('ghost_drape'):
        from ghost_drape import build as build_ghost_drape
        build_ghost_drape()

if __name__=='__main__':
    import sys
    build_masks() if '--masks-only' in sys.argv else build()
