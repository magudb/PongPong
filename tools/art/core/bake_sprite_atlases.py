#!/usr/bin/env python3
"""Offline 2D-isometric sprite renderer using the generator's GLB rigs (VTK, orthographic, 36 degrees, 87.074 px/m).
Output is transparent RGBA PNG masters (bake) that export/export_game_assets.py turns into WebP; Godot needs no GLBs.

  python tools/art/core/bake_sprite_atlases.py fox                       # all clips of the model's clip set -> masters
  python tools/art/core/bake_sprite_atlases.py fox --clips idle           # only some clips (the folder is rebuilt: other sheets are removed)
  python tools/art/core/bake_sprite_atlases.py hobbit_pip --outline ink   # guide ink instead of the pack outline (icons/UI use)
  python tools/art/core/bake_sprite_atlases.py fox bat --bust-only        # only the 14 degree bust portrait -> masters/portraits/<id>.png

Lift changes (P08): this is the art spike's HOOKED baker (CLIP_SETS, attack/spin clips, bust portraits, --clips,
--outline) with only path and API changes: GLBs/rigs are read from tools/art/_stage/glb ($TT_ART_GLB or --glb), masters
go to tools/art/_stage/masters/isometric_characters ($TT_ART_MASTERS or --out), contract numbers come from artcontract,
cells.SetCells (deprecated since VTK 9.6) became ImportLegacyFormat, --bust-only was added for the 12 pack busts (P21).
The camera is reset every frame on purpose (bust() must not leak its zoom into later clips).

Fix round (P08 review): a bake REBUILDS the character's masters folder (earlier sheets and animations.json are deleted first, so a
shrunk clip set or a `--clips` re-bake leaves no stale sheet behind); `--clips` with an unknown clip name, or a bake that ends with no
clip at all, exits non-zero; animations.json now also carries `clip_set` and `flyer` (and `partial: true` after `--clips`) so the
masters-stage validator can check the role clip set; ids must be `[a-z0-9_]+`; the pack busts take their framing from
artcontract.BUST_FRAMING (m.portrait of a builder still wins), with an optional horizontal focus shift `dx`; busts without either
are framed by fit_bust(): the default window, zoomed out / shifted just enough that nothing touches the top or the sides.
"""
from __future__ import annotations
import os,sys,math,json,time,io,argparse
from pathlib import Path
import numpy as np
from PIL import Image,ImageFilter
import vtk
from vtk.util.numpy_support import numpy_to_vtk, numpy_to_vtkIdTypeArray, vtk_to_numpy

import artpaths
import artcontract as ac
from asset_io import Asset

GLB=artpaths.glb_dir()      # generator output: <id>.glb and <id>_rig.json ; override with --glb or $TT_ART_GLB
NAMES=ac.PACK_IDS
DIRECTIONS=ac.DIRECTIONS
ANGLES=ac.ANGLES
# duration visual reference: glTF animation sample clock; fps controls Godot playback, deliberately quantized
SPEC=ac.SPEC
FLIGHT=ac.FLIGHT
# TRAETOPPEN extension clips (only baked when the model's rig.json lists them; see traetoppen_additions.EXTRA_CLIPS)
EXTRA=ac.EXTRA
CLIP_SETS=ac.CLIP_SETS
SIZE=ac.CELL;SS=1
OUTLINE=dict(ac.OUTLINE)   # pack default; --outline ink -> guide ink #2b2340 (a copy: the contract dict stays untouched)
INK=dict(ac.INK)

def rig_stats(name,glb=None):
 p=Path(glb or GLB)/(name+'_rig.json')
 return json.loads(p.read_text())['stats'] if p.exists() else {}

def apply_glow(im,g):
 """Soft coloured halo baked behind glowing creatures: g=(hex,radius_px,strength)."""
 col=tuple(int(g[0][i:i+2],16) for i in (0,2,4));blur=im.getchannel('A').filter(ImageFilter.GaussianBlur(g[1]))
 halo=Image.new('RGBA',im.size,col+(0,));halo.putalpha(blur.point(lambda p:int(min(255,p*g[2]*.9))))
 halo.alpha_composite(im);return halo

class Renderer:
 def __init__(self,name,size=256,glb=None):
  self.glb=Path(glb or GLB);self.name=name;self.asset=Asset(self.glb/(name+'.glb'));self.stats=rig_stats(name,self.glb)
  self.size=size
  pos,normal=self.asset.sample()
  poly=vtk.vtkPolyData();self.poly=poly
  pts=vtk.vtkPoints();pts.SetData(numpy_to_vtk(pos.astype('float32'),deep=True));poly.SetPoints(pts)
  cells=vtk.vtkCellArray();faces=self.asset.faces
  packed=np.column_stack([np.full(len(faces),3),faces]).astype('int64');cells.ImportLegacyFormat(numpy_to_vtkIdTypeArray(packed.ravel(),deep=True));poly.SetPolys(cells)
  norms=numpy_to_vtk(normal.astype('float32'),deep=True);norms.SetName('Normals');poly.GetPointData().SetNormals(norms)
  uv=self.asset.attrs['TEXCOORD_0'].astype('float32').copy();uv[:,1]=1-uv[:,1];tv=numpy_to_vtk(uv,deep=True);tv.SetName('UV');poly.GetPointData().SetTCoords(tv)
  img=np.asarray(self.asset.image()).astype('float32')/255.0
  linear=np.where(img<=.04045,img/12.92,((img+.055)/1.055)**2.4)
  data=vtk.vtkImageData();h,w=img.shape[:2];data.SetDimensions(w,h,1)
  arr=numpy_to_vtk(np.uint8(np.clip(linear[::-1]*255+.5,0,255)).reshape(-1,3).copy(),deep=True);arr.SetNumberOfComponents(3);data.GetPointData().SetScalars(arr)
  tex=vtk.vtkTexture();tex.SetInputData(data);tex.InterpolateOn();tex.RepeatOff()
  self.tex=tex
  mapper=vtk.vtkPolyDataMapper();mapper.SetInputData(poly)
  actor=vtk.vtkActor();actor.SetMapper(mapper);actor.SetTexture(tex);self.actor=actor
  p=actor.GetProperty();p.SetAmbient(.44);p.SetDiffuse(.59);p.SetSpecular(.03);p.SetSpecularPower(24);p.SetInterpolationToPhong()
  ren=vtk.vtkRenderer();ren.AddActor(actor);self.ren=ren
  ren.SetBackground(0,0,0);ren.SetBackgroundAlpha(0);ren.AutomaticLightCreationOff()
  win=vtk.vtkRenderWindow();win.SetOffScreenRendering(True);win.SetSize(size,size);win.AddRenderer(ren);win.SetAlphaBitPlanes(1);win.SetMultiSamples(4);win.SetUseSRGBColorSpace(False);self.win=win
  for loc,intensity in [((-3,6,6),.74),((4,4,4),.31),((3,3,-3),.56)]:
   light=vtk.vtkLight();light.SetLightTypeToSceneLight();light.SetPosition(*loc);light.SetFocalPoint(0,1,0);light.SetIntensity(intensity);ren.AddLight(light)
  filt=vtk.vtkWindowToImageFilter();filt.SetInput(win);filt.SetInputBufferTypeToRGBA();filt.ReadFrontBufferOff();self.filt=filt
  self.cam=ren.GetActiveCamera()
  # Character framing in identical square sprite cells, with feet at a consistent visual pivot.
  self.cam.SetFocalPoint(0,.95,0)
  self.cam.SetViewUp(0,1,0);self.cam.ParallelProjectionOn()
  self.base_scale=self.stats.get('cam_scale') or (1.58 if name=='bat' else 1.47)
  self.cam.SetParallelScale(self.base_scale)
  self._last=None

 def frame(self,angle,clip,phase,shadow=False,elev=None,focus=None,scale=None,dx=0.0):
  a=self.asset
  anim=next((x for x in a.doc['animations'] if x['name']==clip),None)
  duration=0 if anim is None else max(float(a.acc(anim['samplers'][0]['input'])[-1]),.001)
  t=max(0,min(duration-.0002,phase*duration))
  pos,norm=a.sample(clip,t)
  self.poly.GetPoints().SetData(numpy_to_vtk(pos.astype('float32'),deep=True))
  n=numpy_to_vtk(norm.astype('float32'),deep=True);n.SetName('Normals');self.poly.GetPointData().SetNormals(n)
  self.poly.GetPoints().Modified();self.poly.GetPointData().Modified();self.poly.Modified()
  camera=self.cam;az=math.radians(angle);el=math.radians(36 if elev is None else elev)
  radius=8;fy=.95 if focus is None else focus
  camera.SetParallelScale(scale if scale is not None else self.base_scale)   # always reset: bust() must not leak its zoom into later clips
  rx,rz=math.cos(az)*dx,-math.sin(az)*dx   # dx: focus shift along the camera's right axis (metres); 0 for every clip sheet
  camera.SetPosition(rx+radius*math.sin(az)*math.cos(el),fy+radius*math.sin(el),rz+radius*math.cos(az)*math.cos(el))
  camera.SetFocalPoint(rx,fy,rz);camera.SetViewUp(0,1,0);self.ren.ResetCameraClippingRange()
  self.win.Render();self.filt.Modified();self.filt.Update()
  rgba=vtk_to_numpy(self.filt.GetOutput().GetPointData().GetScalars()).reshape((self.size,self.size,4))[::-1].copy()
  color=rgba[:,:,:3].astype(np.float32)/255.0
  # Rendered texture and VTK lighting are linear; convert to sRGB for 2D texture use.
  srgb=np.where(color<=.0031308,color*12.92,1.055*np.power(color,1/2.4)-.055)
  rgba[:,:,:3]=np.uint8(np.clip(srgb*255+.5,0,255))
  output=Image.fromarray(rgba,'RGBA')
  # Warm outline enhances silhouette and recognizability at 64-96px on-screen.
  mask=output.getchannel('A')
  thicker=mask.filter(ImageFilter.MaxFilter(OUTLINE['kernel']))
  outline=Image.new('RGBA',output.size,tuple(OUTLINE['color'])+(0,))
  outline.putalpha(thicker.point(lambda p:int(p*OUTLINE['alpha'])))
  outline.alpha_composite(output)
  g=self.stats.get('glow')
  return apply_glow(outline,g) if g else outline

 def fit_bust(self,angle,fy,half,margin=None):
  """Automatic bust framing: the DEFAULT window (half = visible half-height in metres) unless the figure would touch the top or a
  side border; then the smallest change that clears them: zoom out (half) just enough, then shift the focus sideways (dx, metres to
  the camera's right) as little as possible.  Measured on a wide render of the same camera.  Returns (half, dx).  The bottom edge is
  free: a bust is cut at the torso by design."""
  m=ac.BUST_MARGIN_M if margin is None else margin;n=self.size;wide=3.0;pxm=n/(2*wide)
  a=np.asarray(self.frame(angle,'idle',0.0,elev=14,focus=fy,scale=wide))[...,3]>ac.BORDER_ALPHA_MAX
  rows=np.where(a.any(axis=1))[0]
  if len(rows)==0:return half,0.0
  top=(n/2-rows.min())/pxm                       # highest point of the figure above the focus (m)
  for _ in range(5):
   inwin=[r for r in range(n) if abs((n/2-r-.5)/pxm)<=half]   # rows the bust window shows
   cols=np.where(a[inwin].any(axis=0))[0] if inwin else []
   if len(cols)==0:return half,0.0
   x0=(cols.min()-n/2)/pxm;x1=(cols.max()+1-n/2)/pxm
   need=max((x1-x0)/2+m,top+m)
   if need<=half+1e-6:break
   half=need                                      # zoom out; the window shows more rows, so measure again
  return half,min(max(0.0,x1+m-half),x0-m+half)   # focus shift closest to 0 that keeps both sides clear

 def bust(self,angle=14,clip='idle'):
  """Dialogue/journal portrait: head-and-shoulders, camera closer and lower (14 deg elevation), same lights/outline.
  Framing: m.portrait of the builder ({half, dy, dx}), else artcontract.BUST_FRAMING[id], else the default window with fit_bust()."""
  st=self.stats;k=st.get('scale_from_source',.8);head=[b for b in json.loads((self.glb/(self.name+'_rig.json')).read_text())['bones'] if b['name']=='Head'][0]['rest_position'][1]
  pt=st.get('portrait') or ac.BUST_FRAMING.get(self.name);fy=head+.36*k*1.1+(pt or {}).get('dy',0)*k;default=max(.85,1.25*k)
  if pt is None:half,dx=self.fit_bust(angle,fy,default)
  else:half,dx=pt.get('half',default),pt.get('dx',0.0)
  return self.frame(angle,clip,0.0,elev=14,focus=fy,scale=half,dx=dx)

 def close(self):
  self.win.Finalize()


def available_clips(r,name):
 """(clip,frames,fps,loop) of every clip this model can bake: the 11 base clips, the flight clips of flyers, attack/spin when the rig has them."""
 clips=SPEC+(FLIGHT if r.stats.get('flyer') or name in ['bat','fairy'] else [])
 return clips+[(c,)+EXTRA[c] for c in EXTRA if any(a['name']==c for a in r.asset.doc['animations'])]

def select_clips(r,name,clip_filter):
 """-> (clips to bake, clip set name, partial).  Exits non-zero on an unknown clip name or when nothing would be baked."""
 avail=available_clips(r,name);names=[c[0] for c in avail]
 clip_set=r.stats.get('clip_set') or 'full'
 if clip_set not in CLIP_SETS:raise SystemExit(f"ERROR: {name}: unknown clip_set '{clip_set}' (known: {', '.join(CLIP_SETS)})")
 if clip_filter is not None:
  unknown=[c for c in clip_filter if c not in names]
  if unknown or not clip_filter:raise SystemExit(f"ERROR: {name}: --clips {','.join(clip_filter) or '(empty)'}: unknown clip(s) {unknown or '-'}; this model can bake: {', '.join(names)}")
  return [c for c in avail if c[0] in clip_filter],clip_set,True
 only=CLIP_SETS[clip_set]
 clips=[c for c in avail if c[0] in only] if only else list(avail)
 if not clips:raise SystemExit(f"ERROR: {name}: clip set '{clip_set}' ({', '.join(only or [])}) matches none of the clips this model can bake ({', '.join(names)})")
 return clips,clip_set,False

def clear_masters(folder):
 """A bake rebuilds the character folder: stale sheets/portraits and the old animations.json go (only *.png and animations.json, never anything else)."""
 for f in folder.iterdir():
  if f.is_file() and (f.suffix=='.png' or f.name=='animations.json'):f.unlink()

def check_id(name):
 if not ac.valid_id(name):raise SystemExit(f"ERROR: bad character id '{name}': ids are lower-case ASCII [a-z0-9_]+ (they are folder names)")

def build(name,output,preview=False,clip_filter=None,glb=None):
 check_id(name)
 start=time.monotonic()
 r=Renderer(name,SIZE,glb)
 clips,clip_set,partial=select_clips(r,name,clip_filter)   # fails BEFORE anything is rendered or deleted
 output=Path(output)/name;output.mkdir(parents=True,exist_ok=True);clear_masters(output)
 meta={'character':name,'cell_size':[SIZE,SIZE],'directions':DIRECTIONS,'animations':{},'pivot':[SIZE//2,200],'source':'GLB-to-sprite orthographic offline bake','orientation':'screen-down = S; clockwise rows S,SW,W,NW,N,NE,E,SE'}
 meta['family']=r.stats.get('family',name);meta['clip_set']=clip_set;meta['flyer']=bool(r.stats.get('flyer') or name in ['bat','fairy'])
 if partial:meta['partial']=True   # --clips: not the role's full set (the masters validator skips the role check, the exporter drops the flag)
 for clip,frames,fps,loop in clips:
  sheet=Image.new('RGBA',(SIZE*frames,SIZE*8))
  for di,angle in enumerate(ANGLES):
   for index in range(frames):
    rendered=r.frame(angle,clip,index/frames if loop else index/max(1,frames-1))
    sheet.paste(rendered,(index*SIZE,di*SIZE))
  sheet.save(output/(clip+'.png'),compress_level=6)
  meta['animations'][clip]={'frames':frames,'fps':fps,'loop':loop,'sheet':clip+'.png'}
  print(name,clip,round(time.monotonic()-start,1),flush=True)
  if preview and clip=='idle':
   sheet.crop((0,0,SIZE,SIZE)).save(output/'full_idle.png');r.bust().save(output/'portrait.png');meta['portrait']='portrait.png'
 if not meta['animations']:raise SystemExit(f'ERROR: {name}: no clip was baked')
 with open(output/'animations.json','w') as f:json.dump(meta,f,indent=2)
 r.close();print('COMPLETE',name,round(time.monotonic()-start,2),flush=True)

def bust_only(name,output,glb=None):
 """Only the head-and-shoulders bust (14 degree camera) as <output>/<name>.png - the 12 pack busts of P21."""
 check_id(name)
 r=Renderer(name,SIZE,glb);output=Path(output);output.mkdir(parents=True,exist_ok=True)
 (output/(name+'.png')).unlink(missing_ok=True)   # a failed render must not leave the previous bust behind
 r.bust().save(output/(name+'.png'));r.close();print('BUST',name,flush=True)

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__.split('Lift changes')[0],formatter_class=argparse.RawDescriptionHelpFormatter)
 parser.add_argument('names',nargs='*',default=['fox']);parser.add_argument('--out',default=None,help='output folder (default tools/art/_stage/masters/isometric_characters, busts: .../portraits)')
 parser.add_argument('--glb',default=None,help='folder with <id>.glb and <id>_rig.json (default tools/art/_stage/glb or $TT_ART_GLB)')
 parser.add_argument('--clips',default=None,help='comma list of clips to bake');parser.add_argument('--outline',default='pack',choices=['pack','ink'])
 parser.add_argument('--bust-only',action='store_true',help='bake only the 14 degree bust portrait of each name');args=parser.parse_args()
 if args.outline=='ink':OUTLINE.update(INK)
 masters=artpaths.masters_dir()
 for name in args.names:
  if args.bust_only:bust_only(name,args.out or masters/'portraits',args.glb)
  else:build(name,args.out or masters/'isometric_characters',preview=True,clip_filter=[c.strip() for c in args.clips.split(',') if c.strip()] if args.clips is not None else None,glb=args.glb)
