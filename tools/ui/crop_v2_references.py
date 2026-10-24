#!/usr/bin/env python3
"""Extract the four HUD boxes from the chosen Miljøer v2 render.

The mock's four item placeholders were superseded by approved painted icons.
For the hotbar chrome comparison only, cover the inner 40px of those four slots
in BOTH inputs. Borders, fills outside the icon area, digits and counts remain.
The unmodified crops and full painted-world captures are kept for inspection.
The banner is captured separately on the mock's green background so terrain
art does not dominate the typography comparison. Crop its ink/chalk bounds.
"""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'docs/Trætoppen Style Guide Review/refs/miljoer_v2_render.png'
REGIONS = {'date': (107,606,360,678), 'chip': (1374,606,1654,656),
           # The tray begins at x=608; starting at 609 shifts every 2px
           # slot outline against the runtime crop by one pixel.
           'hotbar': (608,1575,1152,1657), 'banner': (785,600,975,652)}

def glyph_bounds(im):
    mask = Image.new('L', im.size)
    mask.putdata([255 if any(max(abs(p[c]-q[c]) for c in range(3)) < 15
                 for q in [(43,35,64),(255,253,246)]) else 0 for p in im.get_flattened_data()])
    box = mask.getbbox()
    if box is None:
        raise ValueError('Banner has no ink or chalk pixels')
    return im.crop((max(0,box[0]-1),max(0,box[1]-1),min(im.width,box[2]+1),min(im.height,box[3]+1)))

def chrome(im):
    im = im.copy()
    draw = ImageDraw.Draw(im)
    for i in range(4):
        draw.rectangle((22+i*66,22,61+i*66,61),fill=(244,230,196))
    return im

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--shots',type=Path)
    ap.add_argument('--refs',type=Path,default=ROOT/'tests/checkpoints/guide_ref_v2')
    args=ap.parse_args()
    args.refs.mkdir(parents=True,exist_ok=True)
    source=Image.open(SOURCE).convert('RGB')
    for name,box in REGIONS.items():
        reference=source.crop(box)
        reference.save(args.refs/f'city_hud_{name}.png')
        if not args.shots:
            continue
        shot=Image.open(args.shots/f'hud_v2_{name}.png').convert('RGB')
        if name=='banner':
            reference,shot=glyph_bounds(reference),glyph_bounds(shot)
        elif name=='hotbar':
            reference,shot=chrome(reference),chrome(shot)
        reference.save(args.shots/f'reference_{name}.png')
        shot.save(args.shots/f'comparison_{name}.png')

if __name__=='__main__':
    main()
