#!/usr/bin/env python3
"""Offline structural and CPU skinning checks of generated GLBs. Godot runtime tests are separate.

  python tools/art/generator/validate_assets.py [--manifest manifest.json] [--only fox bat] [--glb DIR] [--report FILE]

Lift changes (P08, paths and CLI only; every check is unchanged): reads tools/art/_stage/glb ($TT_ART_GLB) instead of
assets/characters, writes its report to tools/art/_stage/glb/validation.json, can validate one manifest (build_assets.py
--manifest) or a subset, and the scan of the old project's res:// references was dropped (not a property of a GLB).
"""
from pathlib import Path
import json,hashlib,sys,re,os,argparse
import numpy as np
from asset_io import Asset
ART=Path(__file__).resolve().parents[1]
GLB=Path(os.environ.get('TT_ART_GLB') or Path(os.environ.get('TT_ART_STAGE') or ART/'_stage')/'glb')

def validate(glb=GLB,manifest_name='manifest.json',only=None,report_path=None):
 glb=Path(glb);manifest=json.loads((glb/manifest_name).read_text());results=[];sample_count=0
 for record in manifest['characters']:
  if only and record['name'] not in only:continue
  name=record['name'];path=glb/record['file'];a=Asset(path);d=a.doc
  assert len(d['skins'])==1 and len(d['meshes'])==1
  assert not any('uri' in x for x in d.get('buffers',[])+d.get('images',[])), 'External dependency in GLB'
  pos=a.attrs['POSITION'];norm=a.attrs['NORMAL'];weights=a.attrs['WEIGHTS_0'];joints=a.attrs['JOINTS_0'];uv=a.attrs['TEXCOORD_0']
  assert all(np.isfinite(x).all() for x in [pos,norm,weights,uv])
  assert np.allclose(weights.sum(1),1,atol=2e-6) and weights.min()>=0
  assert joints.max()<len(d['skins'][0]['joints'])
  assert np.allclose(np.linalg.norm(norm,axis=1),1,atol=2e-4)
  assert a.faces.min()>=0 and a.faces.max()<len(pos)
  assert uv.min()>=0 and uv.max()<=1
  areas=np.linalg.norm(np.cross(pos[a.faces[:,1]]-pos[a.faces[:,0]],pos[a.faces[:,2]]-pos[a.faces[:,0]]),axis=1)
  assert areas.min()>1e-12, 'Degenerate triangle'
  rest,_=a.sample();bind_error=float(np.abs(rest-pos).max());assert bind_error<3e-6
  assert (np.count_nonzero(weights>.001,axis=1)>1).sum()>100, 'No meaningful deformation weights'
  for i,suffix in [(0,'basecolor'),(1,'orm')]:
   img=a.image(i);assert img.size[0]>=1024 and img.size[0]==img.size[1]
   v=d['bufferViews'][d['images'][i]['bufferView']];b=a.bin[v['byteOffset']:v['byteOffset']+v['byteLength']]
   assert b==(path.parent/(name+'_'+suffix+'.png')).read_bytes(), 'External texture differs from embedded texture'
  for x in d['accessors']:
   assert x['count']>0
  for i,view in enumerate(d['bufferViews']):
   assert view.get('byteOffset',0)%4==0
   assert view.get('byteOffset',0)+view['byteLength']<=d['buffers'][0]['byteLength']
  clip_results=[]
  for clip in d['animations']:
   duration=0
   for channel in clip['channels']:
    sam=clip['samplers'][channel['sampler']];tt=a.acc(sam['input']);vv=a.acc(sam['output']);assert (np.diff(tt)>0).all() and len(tt)==len(vv)
    assert np.isfinite(vv).all();duration=max(duration,float(tt[-1]))
    if channel['target']['path']=='rotation':assert np.allclose(np.linalg.norm(vv,axis=1),1,atol=2e-5)
   maximum=0;minimum_y=100;bound=0
   for t in np.linspace(0,duration,9):
    p,n=a.sample(clip['name'],t);sample_count+=1
    assert np.isfinite(p).all() and np.isfinite(n).all()
    maximum=max(maximum,float(np.linalg.norm(p-pos,axis=1).max()));minimum_y=min(minimum_y,float(p[:,1].min()));bound=max(bound,float(np.abs(p).max()))
    assert bound<5.0,'Exploded skeletal pose'
   first,_=a.sample(clip['name'],0);last,_=a.sample(clip['name'],duration)
   loop_error=float(np.abs(first-last).max()) if clip.get('extras',{}).get('loop') else None
   if loop_error is not None:assert loop_error<5e-5,'Discontinuous animation loop'
   assert maximum>1e-4,'Animation contains no visible movement'
   clip_results.append({'clip':clip['name'],'sampled_frames':9,'max_vertex_motion_m':round(maximum,5),'minimum_vertex_y_m':round(minimum_y,5),'loop_seam_error_m':loop_error})
  results.append({'name':name,'status':'PASS','sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'vertices':len(pos),'triangles':len(a.faces),'bones':len(d['skins'][0]['joints']),'bind_pose_max_error_m':bind_error,'clips':clip_results})
  print('PASS',name,len(d['animations']),'clips',flush=True)
 report={'status':'PASS','test_scope':'GLB structure, textures, bind matrices, weights, numerical animation sampling, loop seams. Not a full Khronos conformance test or Godot runtime test.','characters':len(results),'animation_clips':sum(len(r['clips']) for r in results),'sampled_poses':sample_count,'results':results}
 out=Path(report_path) if report_path else glb/'validation.json';out.write_text(json.dumps(report,indent=2));print('REPORT',out)
 return report
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--glb',default=str(GLB));ap.add_argument('--manifest',default='manifest.json');ap.add_argument('--only',nargs='*');ap.add_argument('--report');a=ap.parse_args()
 validate(a.glb,a.manifest,a.only,a.report)
