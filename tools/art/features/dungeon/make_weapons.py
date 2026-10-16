#!/usr/bin/env python3
"""Manufacture atlases/icons from imagegen paintings; no drawing or recolouring.

The approved stock atlas and all body sockets stay byte-identical. These new
sources are separate eight-view objects, fitted into the existing 128 px cells.
"""
from pathlib import Path
from io import BytesIO
import argparse
import re
import hashlib
import json
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
SOURCES = ROOT / 'tools/art/drawn/sources/dungeon_weapons'
OUT = ROOT / 'assets/held_equipment/dungeon'
ICONS = ROOT / 'assets/icons/items'
DOC = ROOT / 'docs/art/dungeon-loadout'
PRESET = '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\ncompress/mode=0\nmipmaps/generate=false\nprocess/fix_alpha_border=true\n'
LAYOUT = {
    'wpn_dagger_thorn': (65,.82), 'wpn_dagger_flint': (65,.82),
    'wpn_dagger_moonshard': (65,.82), 'wpn_dagger_bee': (65,.80),
    'wpn_sword_forest_steel': (86,.81), 'wpn_sword_candle': (86,.81),
    'wpn_sword_moon': (86,.81), 'wpn_club_spruce': (100,.84),
    'wpn_club_oak': (100,.84), 'wpn_club_mushroom': (100,.78),
    'wpn_club_thornberry': (100,.84), 'wpn_club_trunk': (108,.84),
    'wpn_spear_twig': (132,.60), 'wpn_spear_iron': (132,.60),
    'wpn_spear_thistle': (132,.65), 'wpn_spear_owl': (132,.65),
    'wpn_spear_root': (132,.62), 'wpn_staff_branch': (125,.60),
    'wpn_staff_hazel': (125,.64), 'wpn_staff_light': (125,.64),
    'wpn_staff_ember': (125,.60), 'wpn_staff_star': (125,.65),
}
LEGENDARY = {'wpn_sword_moon','wpn_club_trunk','wpn_spear_root','wpn_staff_star'}

def encoded(image):
    data = BytesIO()
    image.save(data,format='WEBP',lossless=True,exact=True)
    return data.getvalue()

def trimmed(image):
    pixels = np.array(image)
    # Transparent RGB is not art. Discard subvisible manufacturing fringes,
    # retaining the painted object's antialiased alpha and physical colours.
    pixels[pixels[:,:,3] < 16] = 0
    image = Image.fromarray(pixels)
    bounds = image.getchannel('A').getbbox()
    assert bounds, 'empty source cell'
    return image.crop(bounds)

def contained(image, edge):
    scale = min(edge/image.width,edge/image.height)
    resized = image.resize((max(1,round(image.width*scale)),max(1,round(image.height*scale))),Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA',(128,128))
    canvas.alpha_composite(resized,((128-resized.width)//2,(128-resized.height)//2))
    return canvas

def build():
    files = {}
    manifest = {'version':1,'directions':['S','SW','W','NW','N','NE','E','SE'],'items':{}}
    sources = {}
    review = Image.new('RGB',(8*148,len(LAYOUT)*158),(244,230,196))
    draw = ImageDraw.Draw(review)
    for index,(item,(height,grip_fraction)) in enumerate(LAYOUT.items()):
        path = SOURCES / (item+'.png')
        master = Image.open(path).convert('RGBA')
        sources[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
        atlas = Image.new('RGBA',(512,256))
        views = []
        icon = None
        for direction in range(8):
            column,row = direction%4,direction//4
            box = tuple(round(v) for v in (column*master.width/4,row*master.height/2,(column+1)*master.width/4,(row+1)*master.height/2))
            painting = trimmed(master.crop(box))
            cell = contained(painting,112)
            pixels = np.array(cell)
            ys,xs = np.where(pixels[:,:,3] > 80)
            assert len(xs) > 100, (item,direction)
            grip_y = round(ys.min()+(ys.max()-ys.min())*grip_fraction)
            grip_xs = np.where(pixels[grip_y,:,3] > 80)[0]
            assert len(grip_xs), (item,direction,grip_y)
            grip_x = int(np.median(grip_xs))
            assert pixels[grip_y,grip_x,3] > 80, (item,direction,'grip in empty gap')
            views.append({'rect':[column*128,row*128,128,128],'grip':[grip_x,grip_y],'height':int(ys.max()-ys.min()+1)})
            atlas.alpha_composite(cell,(column*128,row*128))
            review.paste(cell,(direction*148+10,index*158+20),cell)
            gx,gy = direction*148+10+grip_x,index*158+20+grip_y
            draw.ellipse((gx-3,gy-3,gx+3,gy+3),fill=(227,195,114),outline=(43,35,64))
            if direction == 0: icon = contained(painting,108)
        texture = OUT / (item+'.webp')
        manifest['items'][item] = {'height':height,'atlas':'res://'+str(texture.relative_to(ROOT)),'source':str(path.relative_to(ROOT)),'views':views}
        files[texture] = encoded(atlas)
        files[texture.with_suffix('.webp.import')] = PRESET.encode()
        icon_path = ICONS / (item+'.webp')
        files[icon_path] = encoded(icon)
        files[icon_path.with_suffix('.webp.import')] = PRESET.encode()
        if item in LEGENDARY:
            # Technical night-edge mask, matching the existing icon contract.
            rim = Image.new('RGBA',icon.size,(228,239,245,255))
            rim.putalpha(icon.getchannel('A').filter(ImageFilter.MaxFilter(9)))
            rim.alpha_composite(icon)
            night = ICONS / (item+'_night.webp')
            files[night] = encoded(rim)
            files[night.with_suffix('.webp.import')] = PRESET.encode()
        draw.text((8,index*158+3),item,fill=(43,35,64))
    files[OUT/'manifest.json'] = (json.dumps(manifest,separators=(',',':'))+'\n').encode()
    files[DOC/'weapon-packing.json'] = (json.dumps({'sources':sources,'native_cell':[128,128],'manufacturing':'alpha crop, uniform contain, atlas placement; no painting/recolouring','layout':LAYOUT,'items':22,'views':176},indent=2)+'\n').encode()
    png = BytesIO()
    review.save(png,format='PNG')
    files[HERE/'review/weapons_grips.png'] = png.getvalue()
    return files

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    files = build()
    bad = []
    for path,data in files.items():
        if args.check:
            if path.suffix == '.import' and path.exists():
                # Godot adds uid/destination metadata on import. Check the
                # manufacturing preset while preserving that engine metadata.
                preset = path.read_text()
                valid = all(re.search(r'^'+re.escape(line)+r'\s*$',preset,re.M) for line in
                            ['compress/mode=0','mipmaps/generate=false','process/fix_alpha_border=true'])
                if not valid: bad.append(str(path.relative_to(ROOT)))
            elif not path.exists() or path.read_bytes() != data: bad.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            if path.suffix != '.import' or not path.exists(): path.write_bytes(data)
    if bad: raise SystemExit('stale: '+', '.join(bad))
    print('22 weapons, 176 directional views, 22 icons and 4 night icons '+('verified' if args.check else 'packed'))

if __name__ == '__main__': main()
