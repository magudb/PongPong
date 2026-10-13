"""Minimal read-only glTF 2.0/GLB sampler used for independent asset checks.

This validates and samples the exported bytes, not the geometry authoring objects.
It is not a replacement for Godot's importer or Khronos' full conformance validator.
"""
import json,struct,io
import numpy as np
from scipy.spatial.transform import Rotation
from PIL import Image

class Asset:
 def __init__(self,path):
  self.path=path;b=path.read_bytes();magic,version,length=struct.unpack_from('<4sII',b,0)
  if magic!=b'glTF' or version!=2 or length!=len(b):raise ValueError('Invalid GLB header')
  off=12;self.bin=None;self.doc=None
  while off<len(b):
   size,typ=struct.unpack_from('<I4s',b,off);off+=8;chunk=b[off:off+size];off+=size
   if typ==b'JSON':self.doc=json.loads(chunk)
   if typ==b'BIN\0':self.bin=chunk
  if self.doc is None or self.bin is None:raise ValueError('Missing chunk')
  self.parents={}
  for i,n in enumerate(self.doc['nodes']):
   for c in n.get('children',[]):
    if c in self.parents:raise ValueError('Multiple parents')
    self.parents[c]=i
  prim=self.doc['meshes'][0]['primitives'][0];self.attrs={k:self.acc(v) for k,v in prim['attributes'].items()};self.faces=self.acc(prim['indices']).reshape(-1,3)
 def acc(self,idx):
  a=self.doc['accessors'][idx];v=self.doc['bufferViews'][a['bufferView']]
  n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];dtype=np.dtype({5126:'<f4',5123:'<u2',5125:'<u4',5121:'u1'}[a['componentType']]);offset=v.get('byteOffset',0)+a.get('byteOffset',0)
  stride=v.get('byteStride',n*dtype.itemsize)
  if offset+(a['count']-1)*stride+n*dtype.itemsize>v.get('byteOffset',0)+v['byteLength']:raise ValueError('Accessor exceeds buffer view')
  return np.ndarray((a['count'],n),dtype=dtype,buffer=self.bin,offset=offset,strides=(stride,dtype.itemsize)).copy().squeeze() if n==1 else np.ndarray((a['count'],n),dtype=dtype,buffer=self.bin,offset=offset,strides=(stride,dtype.itemsize)).copy()
 def image(self,index=0):
  i=self.doc['images'][index];v=self.doc['bufferViews'][i['bufferView']];start=v.get('byteOffset',0)
  return Image.open(io.BytesIO(self.bin[start:start+v['byteLength']])).convert('RGB')
 def sample(self,clip=None,time=0):
  nodes=self.doc['nodes'];t=np.array([n.get('translation',[0,0,0]) for n in nodes],float);q=np.array([n.get('rotation',[0,0,0,1]) for n in nodes],float);s=np.array([n.get('scale',[1,1,1]) for n in nodes],float)
  if clip is not None:
   anim=next(x for x in self.doc['animations'] if x['name']==clip)
   for c in anim['channels']:
    sam=anim['samplers'][c['sampler']];tt=self.acc(sam['input']);vv=self.acc(sam['output']);tm=np.clip(time,tt[0],tt[-1]);i=min(max(int(np.searchsorted(tt,tm))-1,0),len(tt)-2);f=(tm-tt[i])/(tt[i+1]-tt[i]);a=vv[i];b=vv[i+1]
    path=c['target']['path'];nid=c['target']['node']
    if path=='rotation':
     if a@b<0:b=-b
     val=a*(1-f)+b*f;val/=np.linalg.norm(val);q[nid]=val
    elif path=='translation':t[nid]=a*(1-f)+b*f
    elif path=='scale':s[nid]=a*(1-f)+b*f
  local=np.tile(np.eye(4),(len(nodes),1,1));local[:,:3,:3]=Rotation.from_quat(q).as_matrix()*s[:,None,:];local[:,:3,3]=t
  matrices={}
  def world(i):
   if i not in matrices:matrices[i]=world(self.parents[i])@local[i] if i in self.parents else local[i]
   return matrices[i]
  skin=self.doc['skins'][0];ibm=self.acc(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
  transforms=np.array([world(i)@inv for i,inv in zip(skin['joints'],ibm)])
  v=self.attrs['POSITION'];n=self.attrs['NORMAL'];j=self.attrs['JOINTS_0'];w=self.attrs['WEIGHTS_0'];p=np.zeros_like(v);norm=np.zeros_like(n)
  # Inverse transpose handles eyelid scale in the same export.
  norm_mats=np.linalg.inv(transforms[:,:3,:3]).transpose(0,2,1)
  for k in range(4):
   mat=transforms[j[:,k]];p+=(np.einsum('nij,nj->ni',mat[:,:3,:3],v)+mat[:,:3,3])*w[:,k,None]
   norm+=np.einsum('nij,nj->ni',norm_mats[j[:,k]],n)*w[:,k,None]
  norm/=np.maximum(np.linalg.norm(norm,axis=1,keepdims=True),1e-10)
  return p,norm
