#!/usr/bin/env python3
"""Export the 51 dungeon icons from the saved imagegen paintings.

This is asset manufacturing: uniform contain, alpha packing and the established
technical night rim. It never invents an illustration or recolours a source.
"""
from pathlib import Path
from io import BytesIO
import argparse
import hashlib
import json
import re
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from make_weapons import ROOT, ICONS, PRESET, contained, trimmed, encoded

HERE = Path(__file__).resolve().parent
DOC = ROOT / 'docs/art/dungeon-loadout'
sys.path.insert(0,str(ROOT/'tools/dungeon_loot'))
from live_data import snapshot

def build():
    live = snapshot()
    definitions = {}
    for filename in ['weapons','gems','dungeon_materials']:
        definitions.update(live['lua/items/'+filename+'.lua']['items'])
    assert len(definitions) == 51
    tiers = live['lua/config/rarity.lua']['config']['rarity_tiers']
    files = {}
    manifest = {'version':1,'size':[128,128],'source_tool':'built-in imagegen','items':{}}
    for item,definition in sorted(definitions.items()):
        rarity = definition.get('rarity','normal')
        source = ROOT / 'tools/art/drawn/sources' / ('dungeon_weapons' if item.startswith('wpn_') else 'dungeon_icons') / (item+'.png')
        if item.startswith('wpn_'):
            icon = Image.open(ICONS/(item+'.webp')).convert('RGBA')
        else:
            icon = contained(trimmed(Image.open(source).convert('RGBA')),108)
            target = ICONS/(item+'.webp')
            files[target] = encoded(icon)
            files[target.with_suffix('.webp.import')] = PRESET.encode()
        spec = {'file':item+'.webp','rarity':rarity,'source':str(source.relative_to(ROOT)),
                'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                'ring':tiers[rarity]['ui']['ring']}
        if rarity == 'legendary':
            spec['night'] = item+'_night.webp'
            if not item.startswith('wpn_'):
                rim = Image.new('RGBA',icon.size,(228,239,245,255))
                rim.putalpha(icon.getchannel('A').filter(ImageFilter.MaxFilter(9)))
                rim.alpha_composite(icon)
                target = ICONS/spec['night']
                files[target] = encoded(rim)
                files[target.with_suffix('.webp.import')] = PRESET.encode()
        manifest['items'][item] = spec
    assert sum('night' in v for v in manifest['items'].values()) == 7
    # Inspection pages show both native and small icons on day/night panels.
    # The coloured UI tiles are diagnostics, never baked into the game icons.
    font = ImageFont.truetype(str(ROOT/'assets/fonts/IBMPlexMono-Regular.ttf'),11)
    contact = Image.new('RGB',(10*202,6*352),(244,230,196))
    draw = ImageDraw.Draw(contact)
    for index,(item,spec) in enumerate(manifest['items'].items()):
        x,y = (index%10)*202,(index//10)*352
        for row in range(2):
            yy = y+row*176
            draw.rectangle((x,yy,x+201,yy+175),fill='#2f3654' if row else '#f4e6c4')
            ui = tiers[spec['rarity']]['ui']
            draw.rounded_rectangle((x+4,yy+4,x+140,yy+140),radius=10,fill='#'+ui['fill'],outline='#'+ui['ring'],width=3)
            path = ICONS/(spec.get('night',spec['file']) if row else spec['file'])
            data = files.get(path)
            picture = Image.open(BytesIO(data) if data is not None else path).convert('RGBA')
            contact.paste(picture,(x+8,yy+8),picture)
            small = picture.resize((64,64),Image.Resampling.LANCZOS)
            contact.paste(small,(x+138,yy+44),small)
            draw.text((x+4,yy+145),item.removeprefix('wpn_').removeprefix('dng_'),fill='#e4eff5' if row else '#2b2340',font=font)
    output = BytesIO()
    contact.save(output,format='PNG')
    files[HERE/'review/icons_contact.png'] = output.getvalue()
    files[HERE/'manifest.json'] = (json.dumps(manifest,indent=2)+'\n').encode()
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
                preset = path.read_text()
                if not all(re.search(r'^'+re.escape(line)+r'\s*$',preset,re.M) for line in
                           ['compress/mode=0','mipmaps/generate=false','process/fix_alpha_border=true']): bad.append(str(path.relative_to(ROOT)))
            elif not path.exists() or path.read_bytes() != data: bad.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            if path.suffix != '.import' or not path.exists(): path.write_bytes(data)
    if bad: raise SystemExit('stale: '+', '.join(bad))
    print('51 dungeon icons and seven night variants '+('verified' if args.check else 'packed'))

if __name__ == '__main__': main()
