#!/usr/bin/env python3
"""Build QA contact sheets only; never modify source or game artwork."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'docs/qa/ghostfam/contacts'
IDS = ['ghostfam_dyne', 'ghostfam_gnist', 'ghostfam_silke', 'ghostfam_blund']

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for cid in IDS:
        folder = ROOT / 'assets/isometric_characters' / cid
        meta = json.loads((folder / 'animations.json').read_text())
        canvas = Image.new('RGB', (8*148, 28+7*150), (246,241,230))
        draw = ImageDraw.Draw(canvas)
        draw.text((12,8), cid+' | idle frame zero + middle frame of every clip, all directions', fill=(65,52,67))
        samples = [('idle',0)] + [(clip,spec['frames']//2) for clip,spec in meta['animations'].items()]
        for row,(clip,frame) in enumerate(samples):
            sheet = Image.open(folder / meta['animations'][clip]['sheet']).convert('RGBA')
            for direction,name in enumerate(meta['directions']):
                cell = sheet.crop((frame*256,direction*256,(frame+1)*256,(direction+1)*256))
                cell.thumbnail((128,128),Image.Resampling.LANCZOS)
                x,y = direction*148,28+row*150
                canvas.paste(cell,(x+10,y),cell)
                draw.text((x+8,y+130),clip+' '+name+' f'+str(frame),fill=(65,52,67))
        canvas.save(OUT/(cid+'.png'),optimize=True)
        print(OUT/(cid+'.png'))

if __name__ == '__main__':
    main()
