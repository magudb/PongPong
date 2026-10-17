#!/usr/bin/env python3
"""Pack retained imagegen paintings; crop/scale and calibrate ground anchors only.
No drawing or color changes. Run with tools/art/.venv/bin/python.
"""
import json
from pathlib import Path
from PIL import Image
import numpy as np
from scipy import ndimage
from pack import project_building, building_footprint

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'tools/art/drawn/sources/farm_completion'
OUT = ROOT / 'assets/iso_props/farm_completion'
ICONS = ROOT / 'assets/icons/items'

def trim(image):
    return image.crop(image.getchannel('A').getbbox())

def stage_sprites(image):
    # Read the four disconnected plants from the atlas; painted silhouettes can
    # cross nominal quarter-cell gutters. Crop complete plants without repainting.
    labels,count=ndimage.label(np.asarray(image.getchannel('A'))>8)
    sizes=np.bincount(labels.ravel())
    sizes[0]=0
    boxes=ndimage.find_objects(labels)
    components=[boxes[int(i)-1] for i in np.argsort(sizes)[-4:]]
    components.sort(key=lambda box:box[1].start)
    return [image.crop((max(0,x.start-2),max(0,y.start-2),min(image.width,x.stop+2),min(image.height,y.stop+2))) for y,x in components]

def save(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, 'WEBP', lossless=True, method=6)

def icon(image, name):
    drawing = trim(image)
    drawing.thumbnail((88,88), Image.Resampling.LANCZOS)
    target = Image.new('RGBA',(96,96))
    target.alpha_composite(drawing,((96-drawing.width)//2,(96-drawing.height)//2))
    save(target,ICONS/(name+'.webp'))

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for name, width, height in [('sprinkler',96,108),('preserves_jar',88,112),('keg',96,128)]:
        source = trim(Image.open(SOURCE/(name+'.png')).convert('RGBA'))
        source.thumbnail((width-8,height-8),Image.Resampling.LANCZOS)
        image=Image.new('RGBA',(width,height))
        image.alpha_composite(source,((width-source.width)//2,height-source.height-4))
        save(image,OUT/(name+'.webp'))
        manifest[name]={'file':name+'.webp','size':[width,height],'pivot':[width//2,height-16],'footprint':[1,1],'elev':36.0,'illustration':'tools/art/drawn/sources/farm_completion/'+name+'.png'}
        icon(source,name)
    icon(Image.open(SOURCE/'sprinkler.png').convert('RGBA'),'quality_sprinkler')
    planes=[[.064,.74],[.447,.953],[.978,.739]]
    greenhouse,pivot=project_building(Image.open(SOURCE/'greenhouse.png').convert('RGBA'),planes,building_footprint(4,3))
    save(greenhouse,OUT/'greenhouse.webp')
    manifest['greenhouse']={'file':'greenhouse.webp','size':list(greenhouse.size),'pivot':pivot,'footprint':[4,3],'elev':36.0,'source_ground_planes':planes,'illustration':'tools/art/drawn/sources/farm_completion/greenhouse.png'}
    # Register the two back-wall sill endpoints and corner to the 9x9 floor.
    walls=Image.open(SOURCE/'greenhouse_walls.png').convert('RGBA')
    scale_x=1152/1420
    scale_y=342/405
    walls=walls.resize((round(walls.width*scale_x),round(walls.height*scale_y)),Image.Resampling.LANCZOS)
    save(walls,OUT/'greenhouse_walls.webp')
    manifest['greenhouse_walls']={'file':'greenhouse_walls.webp','size':list(walls.size),'pivot':[round(768*scale_x),round(820*scale_y)],'footprint':[9,9],'elev':36.0,'illustration':'tools/art/drawn/sources/farm_completion/greenhouse_walls.png'}
    for crop, heights in [('snow_turnip',[36,56,76,88]),('snowdrop',[40,64,98,120]),('frost_kale',[36,56,80,100])]:
        strip=Image.open(SOURCE/(crop+'_stages.png')).convert('RGBA')
        drawings=stage_sprites(strip)
        for stage,height in enumerate(heights):
            drawing=drawings[stage]
            drawing.thumbnail((76,height-10),Image.Resampling.LANCZOS)
            image=Image.new('RGBA',(84,height))
            image.alpha_composite(drawing,((84-drawing.width)//2,height-drawing.height-4))
            name=f'crop_{crop}_{stage}'
            save(image,OUT/(name+'.webp'))
            manifest[name]={'file':name+'.webp','size':list(image.size),'pivot':[42,height-10],'footprint':[1,1],'elev':36.0,'illustration':'tools/art/drawn/sources/farm_completion/'+crop+'_stages.png'}
            if stage==3:
                icon(drawing,crop)
                icon(drawing,crop+'_seeds')
    for crop in ['turnip','carrot','pumpkin','moonflower','glow_berry','strawberry','sunflower','catnip','snow_turnip','snowdrop','frost_kale']:
        icon(Image.open(SOURCE/'preserves_jar.png').convert('RGBA'),'preserve_'+crop)
        icon(Image.open(SOURCE/'juice_bottle.png').convert('RGBA'),'juice_'+crop)
    for seed in ['snow_turnip_seeds','snowdrop_seeds','frost_kale_seeds']:
        icon(Image.open(SOURCE/(seed+'_icon.png')).convert('RGBA'),seed)
    (OUT/'props.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Packed',len(manifest),'painted props and crop stages, 32 item icons')

if __name__=='__main__':main()
