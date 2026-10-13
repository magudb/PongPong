#!/usr/bin/env python3
"""Render exported GLB geometry/textures and CPU-sampled skinning. Not Godot screenshots.

Lift change (P08, paths only): reads the GLBs from tools/art/_stage/glb ($TT_ART_GLB) and writes the previews to
tools/art/_stage/previews/characters ($TT_ART_PREVIEWS) instead of the old project's assets/characters and docs/;
cells.SetCells (deprecated since VTK 9.6) became cells.ImportLegacyFormat.
"""
from pathlib import Path
import argparse,math,json,os
import numpy as np
from PIL import Image
import vtk
from vtk.util.numpy_support import numpy_to_vtk,numpy_to_vtkIdTypeArray
from asset_io import Asset
ART=Path(__file__).resolve().parents[1]
STAGE=Path(os.environ.get('TT_ART_STAGE') or ART/'_stage')
GLB=Path(os.environ.get('TT_ART_GLB') or STAGE/'glb')
OUT=Path(os.environ.get('TT_ART_PREVIEWS') or STAGE/'previews'/'characters')

def render(name,clip=None,time=0,angle=17,size=750,path=None):
 OUT.mkdir(parents=True,exist_ok=True)
 asset=Asset(GLB/(name+'.glb'));positions,normals=asset.sample(clip,time)
 poly=vtk.vtkPolyData();pts=vtk.vtkPoints();pts.SetData(numpy_to_vtk(positions.astype('float32'),deep=True));poly.SetPoints(pts)
 cells=vtk.vtkCellArray();packed=np.column_stack([np.full(len(asset.faces),3),asset.faces]).astype('int64');cells.ImportLegacyFormat(numpy_to_vtkIdTypeArray(packed.ravel(),deep=True));poly.SetPolys(cells)
 nn=numpy_to_vtk(normals.astype('float32'),deep=True);nn.SetName('Normals');poly.GetPointData().SetNormals(nn)
 uv=asset.attrs['TEXCOORD_0'].astype('float32').copy();uv[:,1]=1-uv[:,1];tv=numpy_to_vtk(uv,deep=True);tv.SetName('UV');poly.GetPointData().SetTCoords(tv)
 image=np.array(asset.image()).astype(float)/255;image=np.where(image<=.04045,image/12.92,((image+.055)/1.055)**2.4);image=np.uint8(image*255+.5)
 # Classic VTK Phong treats texture samples as linear; prelinearize, then encode render once.
 data=vtk.vtkImageData();h,ww=image.shape[:2];data.SetDimensions(ww,h,1);arr=numpy_to_vtk(image[::-1].reshape(-1,3).copy(),deep=True);arr.SetNumberOfComponents(3);data.GetPointData().SetScalars(arr)
 tex=vtk.vtkTexture();tex.SetInputData(data);tex.InterpolateOn();tex.RepeatOff()
 mapper=vtk.vtkPolyDataMapper();mapper.SetInputData(poly);actor=vtk.vtkActor();actor.SetMapper(mapper);actor.SetTexture(tex)
 p=actor.GetProperty();p.SetAmbient(.33);p.SetDiffuse(.69);p.SetSpecular(.06);p.SetSpecularPower(28);p.SetInterpolationToPhong()
 ren=vtk.vtkRenderer();ren.AddActor(actor);bg=np.array([.96,.955,.935]);ren.SetBackground(*np.where(bg<=.04045,bg/12.92,((bg+.055)/1.055)**2.4))
 win=vtk.vtkRenderWindow();win.SetOffScreenRendering(True);win.SetSize(size,size);win.AddRenderer(ren);win.SetMultiSamples(4);win.SetUseSRGBColorSpace(False);ren.AutomaticLightCreationOff()
 for pos,intensity in [((-3,6,6),.78),((4,3,4),.38),((3,4,-4),.60)]:
  light=vtk.vtkLight();light.SetLightTypeToSceneLight();light.SetPosition(*pos);light.SetFocalPoint(0,1,0);light.SetIntensity(intensity);ren.AddLight(light)
 stat=json.loads((GLB/(name+'_rig.json')).read_text())['stats'];lo,hi=stat['bounds_min'],stat['bounds_max'];cx=(lo[0]+hi[0])*.5;cy=(lo[1]+hi[1])*.5
 camera=ren.GetActiveCamera();a=math.radians(angle);camera.SetPosition(cx+7*math.sin(a),cy+1.05,7*math.cos(a));camera.SetFocalPoint(cx,cy-.035,0);camera.SetViewUp(0,1,0);camera.ParallelProjectionOn();camera.SetParallelScale(max((hi[1]-lo[1])*.61,(hi[0]-lo[0])*.56));ren.ResetCameraClippingRange();win.Render()
 filt=vtk.vtkWindowToImageFilter();filt.SetInput(win);filt.Update();output=path or OUT/(name+('_'+clip if clip else '')+'.png');png=vtk.vtkPNGWriter();png.SetFileName(str(output));png.SetInputConnection(filt.GetOutputPort());png.Write()
 a=np.asarray(Image.open(output).convert('RGB'),dtype=float)/255;a=np.where(a<=.0031308,12.92*a,1.055*np.power(a,1/2.4)-.055);Image.fromarray(np.uint8(np.clip(a*255+.5,0,255))).save(output)
 win.Finalize();print(output,flush=True)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('names',nargs='*');p.add_argument('--clip');p.add_argument('--time',type=float,default=0);p.add_argument('--size',type=int,default=750);args=p.parse_args()
 for name in args.names:render(name,args.clip,args.time,size=args.size)
