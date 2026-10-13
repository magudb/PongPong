#!/usr/bin/env python3
"""Offline 2D-isometric sprite renderer using the previously-authored GLB rigs.
Output is transparent premultiplied-safe RGBA PNG atlases; Godot needs no GLBs.
"""
from __future__ import annotations
import os,sys,math,json,time,io,argparse
from pathlib import Path
import numpy as np
from PIL import Image,ImageFilter
import vtk
from vtk.util.numpy_support import numpy_to_vtk, numpy_to_vtkIdTypeArray, vtk_to_numpy

# All authoring inputs remain in the same source PongPong project.
SRC=Path(os.environ.get('PONG_SOURCE',str(Path(__file__).resolve().parents[2])))
sys.path.insert(0,str(SRC/'tools'/'characters'))
from asset_io import Asset

NAMES = ['bat','cat','bear','rabbit','fairy','monkey','capybara','fox','raccoon','penguin','hedgehog','frog']
DIRECTIONS=['S','SW','W','NW','N','NE','E','SE']
ANGLES=[0,45,90,135,180,225,270,315]
# duration visual reference: glTF animation sample clock; fps controls Godot playback, deliberately quantized
SPEC=[('idle',4,5,True),('walk',6,9,True),('run',6,12,True),
      ('jump',4,10,False),('fall',3,6,True),('land',3,11,False),
      ('celebrate',6,9,False),('interact',4,9,False),('hit',3,11,False),
      ('sleep',4,3,True),('talk',4,6,True)]
FLIGHT=[('takeoff',4,10,False),('hover',5,8,True),('fly',6,12,True),('flight_land',4,10,False)]
SIZE=256;SS=1

class Renderer:
 def __init__(self,name,size=256):
  self.name=name;self.asset=Asset(SRC/'assets'/'characters'/(name+'.glb'))
  self.size=size
  pos,normal=self.asset.sample()
  poly=vtk.vtkPolyData();self.poly=poly
  pts=vtk.vtkPoints();pts.SetData(numpy_to_vtk(pos.astype('float32'),deep=True));poly.SetPoints(pts)
  cells=vtk.vtkCellArray();faces=self.asset.faces
  packed=np.column_stack([np.full(len(faces),3),faces]).astype('int64');cells.SetCells(len(packed),numpy_to_vtkIdTypeArray(packed.ravel(),deep=True));poly.SetPolys(cells)
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
  self.cam.SetParallelScale(1.58 if name=='bat' else 1.47)
  self._last=None

 def frame(self,angle,clip,phase,shadow=False):
  a=self.asset
  anim=next((x for x in a.doc['animations'] if x['name']==clip),None)
  duration=0 if anim is None else max(float(a.acc(anim['samplers'][0]['input'])[-1]),.001)
  t=max(0,min(duration-.0002,phase*duration))
  pos,norm=a.sample(clip,t)
  self.poly.GetPoints().SetData(numpy_to_vtk(pos.astype('float32'),deep=True))
  n=numpy_to_vtk(norm.astype('float32'),deep=True);n.SetName('Normals');self.poly.GetPointData().SetNormals(n)
  self.poly.GetPoints().Modified();self.poly.GetPointData().Modified();self.poly.Modified()
  camera=self.cam;az=math.radians(angle);elev=math.radians(36)
  radius=8
  camera.SetPosition(radius*math.sin(az)*math.cos(elev),.95+radius*math.sin(elev),radius*math.cos(az)*math.cos(elev))
  camera.SetFocalPoint(0,.95,0);camera.SetViewUp(0,1,0);self.ren.ResetCameraClippingRange()
  self.win.Render();self.filt.Modified();self.filt.Update()
  rgba=vtk_to_numpy(self.filt.GetOutput().GetPointData().GetScalars()).reshape((self.size,self.size,4))[::-1].copy()
  color=rgba[:,:,:3].astype(np.float32)/255.0
  # Rendered texture and VTK lighting are linear; convert to sRGB for 2D texture use.
  srgb=np.where(color<=.0031308,color*12.92,1.055*np.power(color,1/2.4)-.055)
  rgba[:,:,:3]=np.uint8(np.clip(srgb*255+.5,0,255))
  output=Image.fromarray(rgba,'RGBA')
  # Warm outline enhances silhouette and recognizability at 64-96px on-screen.
  mask=output.getchannel('A')
  thicker=mask.filter(ImageFilter.MaxFilter(5))
  outline=Image.new('RGBA',output.size,(75,60,73,0))
  outline.putalpha(thicker.point(lambda p:int(p*.55)))
  outline.alpha_composite(output)
  return outline

 def close(self):
  self.win.Finalize()


def build(name,output,preview=False):
 start=time.monotonic()
 r=Renderer(name,SIZE)
 output=Path(output)/name;output.mkdir(parents=True,exist_ok=True)
 meta={'character':name,'cell_size':[SIZE,SIZE],'directions':DIRECTIONS,'animations':{},'pivot':[SIZE//2,200],'source':'GLB-to-sprite orthographic offline bake','orientation':'screen-down = S; clockwise rows S,SW,W,NW,N,NE,E,SE'}
 clips=SPEC+(FLIGHT if name in ['bat','fairy'] else [])
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
   sheet.crop((0,0,SIZE,SIZE)).save(output/'portrait.png')
 with open(output/'animations.json','w') as f:json.dump(meta,f,indent=2)
 r.close();print('COMPLETE',name,round(time.monotonic()-start,2),flush=True)

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('names',nargs='*',default=['fox']);parser.add_argument('--out',default=str(SRC/'assets/isometric_characters'));args=parser.parse_args()
 for name in args.names:build(name,args.out,preview=True)
