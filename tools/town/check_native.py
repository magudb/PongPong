#!/usr/bin/env python3
"""Score immutable UI references and the real room's unobscured blur strip.

The full captures/unmasked scores are retained. Portrait placeholders were
superseded by approved painted art. Dynamic hotbar icon interiors are masked
in both chrome inputs; slot geometry, outlines, shortcut digits remain scored.
Live stack counts are masked inside slot borders; shortcut digits and chrome stay scored.
Live money digits and energy fill are state-dependent and masked in the chip;
the owning HUD fixture also scores the full chip against matching mock values.
The full left background strip excludes the foreground keeper speech, portrait
and shop-panel edge. Those sharp UI regions are retained in the full captures.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import numpy as np
from scipy.ndimage import gaussian_filter
from PIL import Image, ImageDraw, ImageFilter
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('guide',ROOT/'tests/checkpoints/compare_guide.py')
guide=importlib.util.module_from_spec(spec);spec.loader.exec_module(guide)

def masked_score(reference,shot,masks,folder,name):
    original=guide.compare(str(reference),str(shot),frame_crop=False)
    a,b=original['ref_img'].copy(),original['shot_img'].copy()
    for box in masks:
        for im in [a,b]:ImageDraw.Draw(im).rectangle(box,fill=(244,230,196))
    ref=folder/(name+'_reference.png');actual=folder/(name+'_actual.png');a.save(ref);b.save(actual)
    scored=guide.compare(str(ref),str(actual),frame_crop=False)
    return {'full_mean':round(original['mean'],3),'mean':round(scored['mean'],3),'masks':masks}

def run(folder):
    report={}
    original=guide.compare(guide.bundled_ref('shop'),str(folder/'shop_ui_shop_fixture.png'))
    a,b=original['ref_img'],original['shot_img'];rp=folder/'shop_reference_full.png';sp=folder/'shop_actual_full.png';a.save(rp);b.save(sp)
    result=masked_score(rp,sp,[[62,342,398,669]],folder,'shop_ui');result.update(limit=18);result['ok']=result['mean']<=18;report['shop_guide']=result
    result=masked_score(ROOT/'tests/checkpoints/guide_ref_ui/dialogue_box.png',folder/'npc_dialogue_crop.png',[[34,34,179,179]],folder,'dialogue_ui');result.update(limit=15);result['ok']=result['mean']<=15;report['dialogue_guide']=result
    for part in ['date','chip','hotbar']:
        masks=([[22+i*66,22,61+i*66,61] for i in range(8)]+[[52+i*66,49,65+i*66,67] for i in range(8)]) if part=='hotbar' else ([[44,12,87,36],[153,21,258,28]] if part=='chip' else [])
        result=masked_score(ROOT/f'tests/checkpoints/guide_ref_v2/city_hud_{part}.png',folder/f'hud_v2_{part}.png',masks,folder,'city_'+part)
        result.update(limit=12);result['ok']=result['mean']<=12;report['city_hud_'+part]=result
    before=Image.open(folder/'town_loop_shop_backdrop.png').convert('RGB')
    after=Image.open(folder/'town_loop_S08_shop_panel.png').convert('RGB')
    box=(0,0,440,720)
    a,b=before.crop(box),after.crop(box)
    mask=np.ones((720,440),dtype=bool)
    foreground=[(52,230,408,332),(52,333,408,720),(431,0,440,720)]
    for x0,y0,x1,y1 in foreground:mask[y0:y1,x0:x1]=False
    # Normalised convolution excludes foreground colours from both Gaussian
    # fields, including their support near the mask edge (no UI colour bleed).
    a,b=np.asarray(a,dtype=float),np.asarray(b,dtype=float)
    def smooth(im,sigma):
        weight=gaussian_filter(mask.astype(float),sigma)
        return gaussian_filter(im*mask[:,:,None],(sigma,sigma,0))/np.maximum(weight[:,:,None],1e-6)
    low=float(np.abs(smooth(a,16)-smooth(b,16))[mask].mean())
    def energy(im):return float(np.abs(im-smooth(im,2))[mask].mean())
    high=energy(b)/max(energy(a),1e-6)
    report['live_interior_blur']={'box':box,'foreground_exclusions':foreground,'low_frequency_difference':round(low,3),'low_limit':12,'high_frequency_ratio':round(high,4),'high_limit':.6,'ok':low<=12 and high<=.6}
    (folder/'native-comparisons.json').write_text(json.dumps(report,indent=2)+'\n')
    return report

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--shots',type=Path,required=True);args=p.parse_args()
    result=run(args.shots);print(json.dumps(result));raise SystemExit(not all(row['ok'] for row in result.values()))
