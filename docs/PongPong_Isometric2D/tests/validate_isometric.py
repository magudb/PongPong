#!/usr/bin/env python3
"""Standalone PNG atlas/scene validator, needs Pillow and NumPy (not Godot runtime)."""
import sys,json,re
from pathlib import Path
import numpy as np
from PIL import Image
PROJECT=Path(__file__).resolve().parents[1]
ASSETS=PROJECT/'assets/isometric_characters'
SCENES=PROJECT/'scenes/isometric'
NAMES=['bat','cat','bear','rabbit','fairy','monkey','capybara','fox','raccoon','penguin','hedgehog','frog']
BASE=['idle','walk','run','jump','fall','land','celebrate','interact','hit','sleep','talk']
FLY=['takeoff','hover','fly','flight_land']
all_valid=True;clips=0;frame_count=0;failures=[];warnings=[]
for name in NAMES:
 mpath=ASSETS/name/'animations.json'
 if not mpath.is_file(): failures.append('Missing '+str(mpath));continue
 meta=json.loads(mpath.read_text())
 if meta['directions']!=['S','SW','W','NW','N','NE','E','SE']:failures.append('wrong directions: '+name)
 if meta['pivot']!=[128,200]:failures.append('wrong anchor: '+name)
 expected=set(BASE+(FLY if name in ['bat','fairy'] else []))
 if set(meta['animations'])!=expected:failures.append(name+': animation set mismatch')
 for clip,info in meta['animations'].items():
  path=ASSETS/name/info.get('sheet',clip+'.png')
  if not path.exists():failures.append('missing '+str(path));continue
  with Image.open(path) as im:
   w,h=im.size
   if (w,h)!=(info['frames']*256,8*256):failures.append('bad size: '+str(path))
   if im.mode!='RGBA':failures.append('not RGBA: '+str(path))
   alpha=np.asarray(im.getchannel('A'))
   if alpha.max()!=255 or alpha.min()!=0:failures.append('unexpected alpha: '+str(path))
   # Detect clipping: any non-trivial painted pixels at the atlas cell boundary.
   for d in range(8):
    for n in range(info['frames']):
     tile=alpha[d*256:(d+1)*256,n*256:(n+1)*256]
     frame_count+=1
     if not np.any(tile>40):failures.append(f'empty: {name} {clip} dir{d} frame{n}');continue
     if (tile[0,:]>16).any() or (tile[-1,:]>16).any() or (tile[:,0]>16).any() or (tile[:,-1]>16).any():
      failures.append(f'cropped: {name} {clip} dir{d} frame{n}')
   if clip in ['walk','run','fly','hover','idle']:
    a=np.asarray(im.crop((0,0,256,256)).convert('RGB'),np.int16)
    b=np.asarray(im.crop((256,0,512,256)).convert('RGB'),np.int16)
    if np.mean(np.abs(a-b))<0.01:warnings.append('little motion in '+name+' '+clip)
  clips+=1
 # Individual scenes and the three core scripts.
 scene=SCENES/'characters'/f'{name}.tscn'
 if not scene.is_file():failures.append('missing '+str(scene))
for s in SCENES.rglob('*.tscn'):
 data=s.read_text()
 for path in re.findall(r'path="(res://[^"]+)"',data):
  resource=PROJECT/path[len('res://'):]
  if not resource.is_file():failures.append('bad scene path '+str(s)+' '+path)
for filepath in ['scripts/isometric/iso_chibi_sprite_2d.gd','scripts/isometric/iso_player_controller_2d.gd','scripts/isometric/iso_wanderer_2d.gd','scripts/isometric/isometric_ground_2d.gd','scripts/isometric/isometric_demo.gd']:
 if not (PROJECT/filepath).is_file():failures.append('missing script: '+filepath)
manifest=json.loads((ASSETS/'manifest.json').read_text())
if set(manifest['animations_by_character'])!=set(NAMES):failures.append('manifest mismatch')
if not (PROJECT/'project.godot').read_text().find('run/main_scene="res://scenes/isometric/demo_isometric_2d.tscn"')>=0:failures.append('incorrect main scene')
if failures:
 print('FAILURES:',len(failures),'\n'+'\n'.join(failures[:75]))
 sys.exit(1)
print('PASS: characters',len(NAMES),'atlases',clips,'directional frames',frame_count,'Godot scene paths valid')
if warnings:print('WARNINGS:',warnings[:20])
