#!/usr/bin/env python3
"""Build the 12 textured, skinned chibi GLBs used by PongPong (TRAETOPPEN pristine generator base, owned by P08).

Python 3.10+; dependencies: numpy, scipy, Pillow.
All modelling, UVs, weights and animation are editable here; no network needed.
Coordinates: metres after normalization, Y up, +Z forward (Godot wrapper turns 180 degrees).
The output is real glTF 2.0 skinning, not animated rigid object pivots.

Lift history (tools/art/README.md has the full table).  This file is the art spike's build_assets.py (hooks TT_BUILDERS /
EXTRA_PATTERNS / EXTRA_CLIPS, m.slug, m.base_height, m.cam_scale, m.clip_set, ...) plus:
  * addendum 4.4 wardrobe patch (4 lines): export(m, out, rig=None, anim_from=None), rig = rig or make_rig(m),
    make_clips(anim_from or m, rig), scale = m.scale_fixed when present.  Default behaviour is byte-identical.
  * path change only: GLBs are generated into tools/art/_stage/glb (gitignored, hidden by tools/art/.gdignore) or into
    $TT_ART_GLB instead of assets/characters of the old 3D project; the 25 MB of GLBs are never committed.
  * hook import: a missing traetoppen_additions module still means "no extra builders", but a module that exists and
    fails to import (for example a broken builder file of the art packages) now raises instead of being swallowed.
Extra builder modules are found through PYTHONPATH (tools/art/characters of P21, or a shim of a feature package).
"""
from __future__ import annotations
import argparse, json, math, os, struct, io
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.spatial.transform import Rotation
from scipy.spatial import cKDTree
import geometry as geo
from additions import BUILDERS
try:  # TRAETOPPEN extension hook: extra characters/props/patterns live in traetoppen_additions.py
 from traetoppen_additions import BUILDERS as TT_BUILDERS, EXTRA_PATTERNS, EXTRA_CLIPS
except ModuleNotFoundError as _e:
 if _e.name!='traetoppen_additions':raise
 TT_BUILDERS={};EXTRA_PATTERNS={};EXTRA_CLIPS={}

NAMES=['bat','cat','bear','rabbit','fairy','monkey','capybara','fox','raccoon','penguin','hedgehog','frog']
ART=Path(__file__).resolve().parents[1]                                  # tools/art (this file lives in tools/art/generator)
BASE=ART.parents[1]                                                      # project root
ASSETS=Path(os.environ.get('TT_ART_GLB') or Path(os.environ.get('TT_ART_STAGE') or ART/'_stage')/'glb')   # generated GLB rigs, textures, *_rig.json (never committed)

class Rig:
 def __init__(self): self.names=[];self.p=[];self.parents=[];self.lookup={};self.group_rules={};self.legs=[];self.arms=[];self.tails=[];self.wings=[];self.ears=[]
 def add(self,name,p,parent=None):
  i=len(self.names);self.names.append(name);self.p.append(np.asarray(p,float));self.parents.append(self.lookup[parent] if isinstance(parent,str) else parent);self.lookup[name]=i;return i
 def local(self,i):return self.p[i]-(self.p[self.parents[i]] if self.parents[i] is not None else 0)

def line_weights(v,points,bone_ids):
 """Continuous weights across a chain; at most two nonzero influences."""
 points=np.array(points);j=np.zeros((len(v),4),np.uint16);w=np.zeros((len(v),4),np.float32)
 best=np.full(len(v),np.inf)
 if len(points)==1:j[:,0]=bone_ids[0];w[:,0]=1;return j,w
 for k in range(len(points)-1):
  d=points[k+1]-points[k];t=np.clip((v-points[k])@d/max(d@d,1e-10),0,1)
  dist=((v-(points[k]+t[:,None]*d))**2).sum(1);mask=dist<best
  j[mask,0]=bone_ids[k];j[mask,1]=bone_ids[k+1];w[mask,0]=1-t[mask];w[mask,1]=t[mask];best[mask]=dist[mask]
 return j,w

def make_rig(m):
 r=Rig();r.add('Root',[0,0,0]);r.add('Hips',[0,.64,0],'Root')
 bp=m.groups[m.lookup['Body']].pivot if 'Body'in m.lookup else np.array([0,.75,0])
 r.add('Spine',bp+[0,.20,0],'Hips')
 hp=m.groups[m.lookup['Head']].pivot;r.add('Head',hp,'Spine')
 r.group_rules['Body']=('chain',[r.p[r.lookup['Hips']],r.p[r.lookup['Spine']]],[r.lookup['Hips'],r.lookup['Spine']])
 r.group_rules['Head']=('rigid',r.lookup['Head'])
 for g in m.groups:
  n=g.name
  if n.startswith('Eye_'):
   i=r.add(n,g.pivot,'Head');r.group_rules[n]=('rigid',i)
  elif n.startswith('Ear_'):
   allv=np.vstack([s.vertices for s in g.shapes]);tip=allv[allv[:,1].argmax()]
   a=r.add(n,g.pivot,'Head');b=r.add(n+'_Tip',g.pivot*.40+tip*.60,n)
   r.group_rules[n]=('chain',[g.pivot,r.p[b]],[a,b]);r.ears.append((a,b))
  elif n.startswith('Arm_'):
   side=n[-1];s=-1 if side=='L' else 1
   start=g.pivot.copy()
   if m.name=='fairy': end=np.array([s*.474,.985,.098]);middle=(start+end)*.5+np.array([0,-.025,0])
   else: end=start+np.array([s*.025,-.355,.075]);middle=start+np.array([s*.012,-.19,.040])
   a=r.add('UpperArm_'+side,start,'Spine');b=r.add('Forearm_'+side,middle,'UpperArm_'+side);c=r.add('Hand_'+side,end,'Forearm_'+side)
   r.group_rules[n]=('chain',[start,middle,end],[a,b,c]);r.arms.append((side,a,b,c))
  elif n.startswith('Foot_') or n.startswith('HindFoot_'):
   ankle=g.pivot.copy();ankle[1]=.17 if m.name!='bat' else .09
   if m.name=='fairy':ankle[2]=.025
   hip=ankle+np.array([0,.44,0]);knee=ankle+np.array([0,.22,0])
   if m.name=='bat':hip=ankle+np.array([0,.20,0]);knee=ankle+np.array([0,.10,0])
   a=r.add('Thigh_'+n,hip,'Hips');b=r.add('Shin_'+n,knee,'Thigh_'+n);c=r.add(n,ankle,'Shin_'+n)
   r.group_rules[n]=('leg',[hip,knee,ankle],[a,b,c]);r.legs.append((n,a,b,c,.22 if m.name!='bat' else .10))
   # A single closed sleeve spans the joints and deforms with both segments.
   if m.name not in ['fairy','bat','penguin'] and getattr(m,'leg_sleeve',True):
    pts=np.linspace(hip+np.array([0,.035,0]),ankle,15);rad=np.linspace(.103,.088,len(pts))*getattr(m,'leg_radius',1.0)
    if m.name=='capybara':rad*=1.08
    m.tube(n,pts,rad,getattr(m,'leg_color','body'),sides=14)
  elif n=='Tail':
   shape=g.shapes[0];v=shape.vertices
   if hasattr(shape,'path'): path=shape.path
   elif len(v)>130 and (len(v)-2)%12==0:path=v[:-2].reshape(-1,12,3).mean(1)
   else:path=np.stack([g.pivot,g.pivot+(v.mean(0)-g.pivot)*1.5])
   distances=np.r_[0,np.cumsum(np.linalg.norm(np.diff(path,axis=0),axis=1))]
   if distances[-1]<.02:distances[-1]=.02
   samples=np.linspace(0,distances[-1],5);p=np.stack([np.interp(samples,distances,path[:,k]) for k in range(3)],axis=1)
   ids=[]
   for k in range(5):ids.append(r.add('Tail_%02d'%k,p[k],'Hips' if k==0 else 'Tail_%02d'%(k-1)))
   r.group_rules[n]=('chain',p,ids);r.tails.append(ids)
  elif n.startswith('Wing_'):
   s=-1 if n[-1]=='L' else 1
   allv=np.vstack([sh.vertices for sh in g.shapes]);tip=allv[np.argmax(allv[:,0]*s)]
   ps=[g.pivot,g.pivot*.52+tip*.48,g.pivot*.15+tip*.85];ids=[]
   for k,p in enumerate(ps):ids.append(r.add(n+'_%d'%k,p,'Spine' if k==0 else n+'_%d'%(k-1)))
   r.group_rules[n]=('chain',ps,ids);r.wings.append((s,ids))
 if 'Wand'in m.lookup:r.group_rules['Wand']=('rigid',r.lookup['Hand_R'])
 return r

def color_rgb(c):return np.array([int(c[i:i+2],16) for i in (0,2,4)],float)

def pattern_for(m,g,shape):
 if hasattr(shape,'pattern'):return shape.pattern
 color=shape.color;p=m.palette
 for key,pat in getattr(m,'patterns',{}).items():
  if color==p.get(key):return pat
 if g.name.startswith('Wing'):return 'silk'
 if color in [p.get('hair'),p.get('hair_light')]:return 'hair'
 if color in [p.get('dress'),p.get('petal')]:return 'petal'
 if color==p['cheek']:return 'blush'
 if color==p['eye']:return 'porcelain'
 if color in [p['ink'],p['shine'],p['tooth'],p['cheek_ink']]:return 'clean'
 if g.name.startswith('Ear') and color==p['inner']:return 'velvet'
 return 'fur'

def paint_tile(color,pattern,size=256):
 if pattern in EXTRA_PATTERNS:return EXTRA_PATTERNS[pattern](color,size)
 rgb=color_rgb(color);y,x=np.mgrid[0:1:complex(size),0:1:complex(size)]
 rng=np.random.default_rng(int(color,16)%2147483647)
 # Hand-painted-style colour variation is part of the image, not a shader.
 variation=.023*np.cos(2*np.pi*x)+.030*(.5-y)+.008*rng.standard_normal((size,size))
 if pattern in ['clean','porcelain']:variation*=.12
 if pattern=='hair':variation+=.028*np.sin(2*np.pi*(x*11+.1*np.sin(y*9)))
 if pattern=='silk':variation+=.018*np.sin(x*15-y*8)
 a=np.clip(rgb[None,None,:]*(1+variation[:,:,None]),0,255)
 if pattern=='tail_fox':
  edge=.76+.035*np.cos(x*math.pi*10)
  fac=np.clip((y-edge)*70+.5,0,1)[:,:,None]
  a=a*(1-fac)+color_rgb('FFF0D8')[None,None,:]*fac
 if pattern=='tail_raccoon':
  f=((y*.96+.02)*5)%1
  fac=np.clip((np.cos(f*2*np.pi)-.02)*16+.5,0,1)[:,:,None]
  a=a*(1-fac)+color_rgb('665A70')[None,None,:]*fac
 im=Image.fromarray(a.astype('uint8'),'RGB');d=ImageDraw.Draw(im)
 if pattern in ['fur','velvet']:
  for i in range(130 if pattern=='fur' else 45):
   px=int(rng.integers(5,size-5));py=int(rng.integers(5,size-9));delta=rng.uniform(-.07,.07)
   c=tuple(np.clip(rgb*(1+delta),0,255).astype(int))
   d.line([(px,py),(px+int(rng.integers(-2,3)),py+int(rng.integers(3,7)))],fill=c,width=1)
 if pattern in ['silk','petal']:
  tint=tuple(np.clip(rgb*1.035+2,0,255).astype(int))
  for i in range(5):
   px=25+i*43
   pts=[(int(px+12*math.sin(t/size*math.pi*2+i)),t) for t in range(0,size,4)]
   d.line(pts,fill=tint,width=2)
 return im

def atlas(m):
 keys=[]
 for g in m.groups:
  for s in g.shapes:
   key=(s.color,pattern_for(m,g,s))
   if key not in keys:keys.append(key)
 grid=4 if len(keys)<=16 else 8;size=grid*256
 image=Image.new('RGB',(size,size),(128,128,128));orm=Image.new('RGB',(size,size),(255,210,0));layout={}
 for i,(color,pattern) in enumerate(keys):
  x=(i%grid)*256;y=(i//grid)*256
  tile=paint_tile(color,pattern);image.paste(tile,(x,y));rough=.35 if pattern in ['clean','porcelain'] else (.61 if pattern=='silk' else .79)
  ImageDraw.Draw(orm).rectangle((x,y,x+255,y+255),fill=(255,int(rough*255),0))
  layout[str(i)]={'color_srgb':'#'+color,'pattern':pattern,'pixel_box':[x,y,x+256,y+256],'padding':6}
 buf=io.BytesIO();image.save(buf,format='PNG',optimize=True);a=buf.getvalue()
 buf=io.BytesIO();orm.save(buf,format='PNG',optimize=True);b=buf.getvalue()
 return keys,grid,a,b,layout

def shape_uv(s):
 if hasattr(s,'uv'):return s.uv.copy()
 v=s.vertices;lo=v.min(0);hi=v.max(0);rad=np.maximum((hi-lo)*.5,1e-6);p=(v-(hi+lo)*.5)/rad
 u=.5+np.arctan2(p[:,0],p[:,2])/(math.pi*2)
 # Cylindrical vertical coordinate gives friendly, editable UV islands.
 vv=(hi[1]-v[:,1])/max(hi[1]-lo[1],1e-6)
 return np.stack([u,vv],axis=1)

def collect(m,r,keys,grid,scale):
 arrays={k:[] for k in ['p','n','uv','j','w']};faces=[];offset=0;shapes=[]
 for g in m.groups:
  for si,s in enumerate(g.shapes):
   v=s.vertices;f=s.faces;n=geo.smooth_normals(v,f);uv=shape_uv(s)
   rule=r.group_rules.get(g.name,('rigid',r.lookup['Head']))
   if rule[0]=='rigid':
    j=np.zeros((len(v),4),np.uint16);j[:,0]=rule[1];w=np.zeros((len(v),4),np.float32);w[:,0]=1
   else:j,w=line_weights(v,rule[1],rule[2])
   # Duplicate UV seam vertices only, preserving smooth normals and weights.
   vp=list(v);np_=list(n);uvp=list(uv);jp=list(j);wp=list(w);ff=[]
   for tri in f:
    tri=tri.copy();tu=uv[tri,0]
    if np.ptp(tu)>.65:
     high=tu>.5
     for k,vi in enumerate(tri):
      newuv=uv[vi].copy();newuv[0]=1.0 if high.sum()>=2 else 0.0
      if (high.sum()>=2 and not high[k]) or (high.sum()<2 and high[k]):
       tri[k]=len(vp);vp.append(v[vi]);np_.append(n[vi]);uvp.append(newuv);jp.append(j[vi]);wp.append(w[vi])
    ff.append(tri)
   uvp=np.array(uvp);tile=keys.index((s.color,pattern_for(m,g,s)));tx=tile%grid;ty=tile//grid
   uvp[:,0]=(tx+(6+uvp[:,0]*244)/256)/grid;uvp[:,1]=(ty+(6+uvp[:,1]*244)/256)/grid
   arrays['p'].append(np.array(vp)*scale);arrays['n'].append(np.array(np_));arrays['uv'].append(uvp);arrays['j'].append(np.array(jp));arrays['w'].append(np.array(wp));faces.append(np.array(ff)+offset)
   shapes.append({'group':g.name,'part':si,'atlas_tile':tile,'vertex_start':offset,'vertex_count':len(vp)})
   offset+=len(vp)
 return {k:np.concatenate(a) for k,a in arrays.items()},np.concatenate(faces),shapes

class Writer:
 def __init__(self):
  self.bin=bytearray();self.doc={'asset':{'version':'2.0','generator':'PongPong chibi skeletal pipeline 2.0'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[],'meshes':[],'skins':[],'materials':[],'accessors':[],'bufferViews':[],'animations':[]}
 def view(self,blob,target=None):
  while len(self.bin)%4:self.bin.append(0)
  offset=len(self.bin);self.bin.extend(blob);view={'buffer':0,'byteOffset':offset,'byteLength':len(blob)}
  if target:view['target']=target
  self.doc['bufferViews'].append(view);return len(self.doc['bufferViews'])-1
 def acc(self,a,typ,component=5126,target=None):
  dtype={5126:'<f4',5123:'<u2',5125:'<u4'}[component];a=np.ascontiguousarray(a,dtype=dtype)
  view=self.view(a.tobytes(),target);v={'bufferView':view,'componentType':component,'count':len(a),'type':typ}
  if component==5126 and typ in ['SCALAR','VEC3']:
   v['min']=a.min(0).reshape(-1).tolist();v['max']=a.max(0).reshape(-1).tolist()
  self.doc['accessors'].append(v);return len(self.doc['accessors'])-1
 def save(self,path):
  self.doc['buffers']=[{'byteLength':len(self.bin)}];j=json.dumps(self.doc,separators=(',',':')).encode();j+=b' '*((-len(j))%4);b=bytes(self.bin);b+=b'\0'*((-len(b))%4)
  path.write_bytes(struct.pack('<4sII',b'glTF',2,12+8+len(j)+8+len(b))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(b),b'BIN\0')+b)

def make_clips(m,r):
 clips=[];spec=[('idle',3.2,True),('walk',.9,True),('run',.58,True),('jump',.36,False),('fall',.9,True),('land',.28,False),('celebrate',1.8,False),('talk',2.4,True),('interact',.9,False),('hit',.4,False),('sleep',3.6,True)]
 spec += [c for c in getattr(m,'extra_clips',[]) if c[0] in EXTRA_CLIPS]
 if m.name in ['bat','fairy']:spec += [('takeoff',.48,False),('hover',1.2,True),('fly',.72,True),('turn_left',.72,True),('turn_right',.72,True),('flight_land',.38,False)]
 for name,duration,loop in spec:
  t=np.linspace(0,duration,int(round(duration*30))+1);q=np.zeros((len(t),len(r.names),3));translations=np.tile(np.array([r.local(i) for i in range(len(r.names))]),(len(t),1,1));scales=np.ones((len(t),len(r.names),3));phase=t/duration*math.pi*2
  motion=name in ['walk','run'];flying=name in ['hover','fly','turn_left','turn_right','takeoff','flight_land'];run=name=='run';hip=r.lookup['Hips'];spine=r.lookup['Spine'];head=r.lookup['Head']
  bob=-.018+.008*np.sin(phase)
  if motion:bob=-.036+.016*np.cos(phase*2)
  if name in ['jump','land','hit','interact']:bob=-.10*np.sin(np.pi*t/duration)**2
  if name=='celebrate':bob=.045*np.sin(phase*2)**2-.018
  if flying:bob=.04*np.sin(phase)
  translations[:,hip,1]+=bob
  q[:,spine,0]=.016*np.cos(phase);q[:,head,1]=.035*np.sin(phase);q[:,head,2]=.018*np.sin(phase*.5) if not loop else .018*np.sin(phase)
  if motion:
   q[:,spine,2]=(.085 if m.name=='penguin' else .035)*np.sin(phase)
   q[:,head,2]=-q[:,spine,2]*.5;q[:,head,1]=.025*np.sin(phase)
   if run:q[:,spine,0]=.055
  if name=='talk':q[:,head,0]=.09*np.sin(phase*3);q[:,head,1]=.10*np.sin(phase)
  if name=='interact':q[:,spine,0]=.15*np.sin(np.pi*t/duration)**2
  if name=='sleep':q[:,head,0]=.18+.015*np.sin(phase);q[:,spine,0]=.10
  if name=='hit':q[:,spine,0]=-.25*np.sin(np.pi*t/duration);q[:,head,0]=-.10*np.sin(np.pi*t/duration)
  if name in EXTRA_CLIPS:EXTRA_CLIPS[name](m,r,t,duration,phase,q,translations,scales)
  if name in ['turn_left','turn_right']:q[:,spine,2]=.15 if name=='turn_left' else -.15;q[:,head,1]=.2 if name=='turn_left' else -.2
  for lname,a,b,c,length in r.legs:
   side=-1 if lname.endswith('L') else 1;legphase=phase+(0 if side==-1 else math.pi)
   if lname.startswith('Hind'):legphase+=math.pi
   if m.name in ['rabbit','frog'] and run:legphase=phase
   dz=np.zeros(len(t));lift=np.zeros(len(t))
   if motion:
    stride=.115 if not run else .155
    if m.name=='penguin':stride*=.6
    if m.name=='bat':stride*=.32
    dz=stride*np.sin(legphase);lift=(.055 if not run else .12)*np.maximum(np.cos(legphase),0)**1.5
   if flying:dz[:]=-.06;lift[:]=.14 if m.name!='bat' else .035
   if name in ['jump','fall']:dz[:]=-.07;lift[:]=.09
   if name=='celebrate':lift=.06*np.maximum(np.sin(phase*2),0)
   # Sagittal two-bone IK: feet remain level through knee flexion.
   dy=np.maximum(2*length+bob-lift,.02);dist=np.minimum(np.hypot(dy,dz),2*length*.9999)
   alpha=np.arctan2(dz,dy)+np.arccos(np.clip(dist/(2*length),-1,1));knee=2*np.arccos(np.clip(dist/(2*length),-1,1))
   q[:,a,0]=-alpha;q[:,b,0]=knee;q[:,c,0]=alpha-knee
  for side,a,b,c in r.arms:
   sign=-1 if side=='L' else 1;p=phase+(0 if sign==-1 else math.pi)
   if motion:q[:,a,0]=(.34 if not run else .62)*np.sin(p);q[:,b,0]=-.12-.14*np.maximum(-np.sin(p),0)
   else:q[:,a,2]=sign*.023*np.sin(phase);q[:,b,0]=-.045
   if name in ['jump','fall']:q[:,a,2]=sign*.23;q[:,b,0]=-.34
   if name in ['celebrate','talk','interact']:
    amp={'celebrate':.90,'talk':.22,'interact':.52}[name];env=1 if loop else np.sin(np.pi*t/duration)**2
    q[:,a,2]=sign*amp*env;q[:,a,0]=-.20*env;q[:,b,0]=-.22*env
   if flying:q[:,a,2]=sign*.13;q[:,b,0]=-.14
  for ids in r.tails:
   for k,i in enumerate(ids):q[:,i,1]=(.075 if motion else .035)*np.sin(phase-k*.47);q[:,i,2]=.018*np.sin(phase-k*.32)
  for a,b in r.ears:q[:,a,2]=.025*np.sin(phase+.4);q[:,b,0]=(.07 if motion else .035)*np.sin(phase-.7)
  for sign,ids in r.wings:
   flap=(.56 if flying else .085)*np.sin(phase*(2 if name=='hover' else 1))
   if name=='takeoff':flap=.56*np.sin(phase*2)*(t/duration)
   if name=='flight_land':flap=.50*np.sin(phase*2)*(1-t/duration)
   q[:,ids[0],1]=sign*(.15+flap);q[:,ids[1],1]=sign*.16*np.sin(phase-.6);q[:,ids[2],1]=sign*.09*np.sin(phase-1.0)
  for side in ['L','R']:
   key='Eye_'+side
   if key in r.lookup:
    i=r.lookup[key];blink=np.exp(-((t/duration-.72)/.023)**4)
    scales[:,i,1]=.065 if name=='sleep' else 1-.935*blink
  if loop:
   q[-1]=q[0];translations[-1]=translations[0];scales[-1]=scales[0]
  quats=Rotation.from_euler('xyz',q.reshape(-1,3)).as_quat().reshape(len(t),len(r.names),4)
  clips.append({'name':name,'duration':duration,'loop':loop,'t':t,'rotation':quats,'translation':translations,'scale':scales})
 return clips

def export(m,out,rig=None,anim_from=None):
 rig=rig or make_rig(m)  # WARDROBE: garments pass the BODY rig so bones/weights/animation are identical
 # Keep the feet at zero and the face at a comparable gameplay height.
 allv=np.vstack([s.vertices for g in m.groups for s in g.shapes]);height=allv[:,1].max()
 scale=1.95/height
 if m.name=='capybara':scale=1.48/height
 if m.name=='bat':scale=1.60/height
 if getattr(m,'height',None):scale=m.height/(getattr(m,'base_height',None) or height)  # base_height: height of the stock model before hats/crowns so px-per-metre stays constant
 if getattr(m,'scale_fixed',None):scale=m.scale_fixed  # WARDROBE: one px-per-unit scale for every body of a garment family
 slug=getattr(m,'slug',m.name)
 keys,grid,png,orm,layout=atlas(m);a,f,parts=collect(m,rig,keys,grid,scale)
 w=Writer();d=w.doc;d['nodes']=[{'name':slug.title(),'children':[1,2]},{'name':'CharacterMesh','mesh':0,'skin':0}]
 for i,n in enumerate(rig.names):
  nd={'name':n,'translation':(rig.local(i)*scale).tolist()};children=[2+k for k,p in enumerate(rig.parents) if p==i]
  if children:nd['children']=children
  d['nodes'].append(nd)
 ibm=np.tile(np.eye(4),(len(rig.names),1,1));ibm[:,:3,3]=-np.array(rig.p)*scale
 d['skins']=[{'name':slug.title()+'Rig','joints':list(range(2,2+len(rig.names))),'skeleton':2,'inverseBindMatrices':w.acc(ibm.transpose(0,2,1).reshape(-1,16),'MAT4')}]
 attributes={'POSITION':w.acc(a['p'],'VEC3',target=34962),'NORMAL':w.acc(a['n'],'VEC3',target=34962),'TEXCOORD_0':w.acc(a['uv'],'VEC2',target=34962),'JOINTS_0':w.acc(a['j'],'VEC4',5123,34962),'WEIGHTS_0':w.acc(a['w'],'VEC4',target=34962)}
 d['meshes']=[{'name':slug.title()+'_Skinned','primitives':[{'attributes':attributes,'indices':w.acc(f.reshape(-1),'SCALAR',5125 if len(a['p'])>65535 else 5123,34963),'material':0}]}]
 d['images']=[{'name':slug+'_basecolor','bufferView':w.view(png),'mimeType':'image/png'},{'name':slug+'_orm','bufferView':w.view(orm),'mimeType':'image/png'}]
 d['samplers']=[{'magFilter':9729,'minFilter':9987,'wrapS':33071,'wrapT':33071}];d['textures']=[{'source':0,'sampler':0},{'source':1,'sampler':0}]
 d['materials']=[{'name':slug+'_PaintedAtlas','pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':1,'metallicRoughnessTexture':{'index':1}},'doubleSided':False}]
 clips=make_clips(anim_from or m,rig)
 for clip in clips:
  an={'name':clip['name'],'samplers':[],'channels':[],'extras':{'loop':clip['loop']}}
  time=w.acc(clip['t'],'SCALAR')
  for i in range(len(rig.names)):
   for prop,typ in [('rotation','VEC4'),('translation','VEC3'),('scale','VEC3')]:
    data=clip[prop][:,i].copy()
    # Include rest rotations for crossfades, but only actual translations/scales.
    if prop=='translation' and i!=rig.lookup['Hips']:continue
    if prop=='scale' and not rig.names[i].startswith('Eye_'):continue
    if prop=='translation':data*=scale
    outacc=w.acc(data,typ);an['samplers'].append({'input':time,'output':outacc,'interpolation':'LINEAR'});an['channels'].append({'sampler':len(an['samplers'])-1,'target':{'node':2+i,'path':prop}})
  d['animations'].append(an)
 d['extras']={'character':m.name,'pipeline':'skinned_atlas_v2','forward':'+Z','up':'+Y','unit':'metre','copyright':'Original geometry based on user drawings and original additional designs','rest_bounds':[a['p'].min(0).tolist(),a['p'].max(0).tolist()]}
 out.mkdir(parents=True,exist_ok=True);w.save(out/(slug+'.glb'))
 (out/(slug+'_basecolor.png')).write_bytes(png);(out/(slug+'_orm.png')).write_bytes(orm)
 (out/(slug+'_uv_layout.json')).write_text(json.dumps({'size':grid*256,'tiles':layout,'parts':parts},indent=2))
 stat={'name':slug,'family':m.name,'file':slug+'.glb','vertices':len(a['p']),'triangles':len(f),'bones':len(rig.names),'deforming_vertices':int((np.count_nonzero(a['w']>.001,axis=1)>1).sum()),'texture_size':grid*256,'materials':1,'animations':[{'name':c['name'],'duration':c['duration'],'loop':c['loop']} for c in clips],'bounds_min':a['p'].min(0).tolist(),'bounds_max':a['p'].max(0).tolist(),'scale_from_source':scale,'flyer':m.name in ['bat','fairy'],'cam_scale':getattr(m,'cam_scale',None),'clip_set':getattr(m,'clip_set',None),'portrait':getattr(m,'portrait',None),'glow':getattr(m,'glow',None)}
 (out/(slug+'_rig.json')).write_text(json.dumps({'bones':[{'name':n,'parent':rig.names[rig.parents[i]] if rig.parents[i]!=None else None,'rest_position':(rig.p[i]*scale).tolist()} for i,n in enumerate(rig.names)],'stats':stat},indent=2))
 print(slug,stat['vertices'],'vertices',stat['triangles'],'triangles',stat['bones'],'bones',stat['deforming_vertices'],'weighted',flush=True)
 return stat

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=ASSETS);parser.add_argument('--only',nargs='*');parser.add_argument('--manifest',default='manifest.json');args=parser.parse_args();stats=[]
 for name in args.only or NAMES:
  maker=TT_BUILDERS.get(name) or BUILDERS.get(name,getattr(geo,'make_'+name,None));m=maker();stats.append(export(m,args.output))
 (args.output/args.manifest).write_text(json.dumps({'format_version':2,'characters':stats},indent=2))
if __name__=='__main__':main()
