#!/usr/bin/env python3
"""Editable base geometry derived from the supplied drawings.
Used by build_assets.py; no exporter or animation implementation lives here.
"""
from __future__ import annotations
import argparse
from dataclasses import dataclass, field
import json
import math
from pathlib import Path
import struct
from typing import Callable
import numpy as np

PALETTES = {
    'bat': {'body':'A599D0', 'light':'C7BDE5', 'inner':'D7AAC8', 'rim':'8575B2', 'belly':'CDC2E8'},
    'cat': {'body':'E9B17C', 'light':'F0C89F', 'inner':'E2A7A0', 'rim':'B58165', 'belly':'F9E5C7'},
    'bear': {'body':'BB987D', 'light':'D1B59A', 'inner':'DBAAA0', 'rim':'96725D', 'belly':'E7D2B4'},
    'rabbit': {'body':'EFE3D0', 'light':'F6EEDC', 'inner':'E5B2B6', 'rim':'BFB19E', 'belly':'FFF5E2'},
    'monkey': {'body':'B68B71', 'light':'E7C7A4', 'inner':'DDAEA0', 'rim':'8E685A', 'belly':'EDD2B3'},
    'capybara': {'body':'C1A07B', 'light':'DFC39B', 'inner':'D9B69A', 'rim':'94785E', 'belly':'D5B58F'},
    'fairy': {'body':'F2C9B0', 'light':'F8DCC8', 'inner':'DDA3AC', 'rim':'BB8D82', 'belly':'D0E7D3',
              'dress':'A6CEBE', 'petal':'C2DDCB', 'hair':'E9C57C', 'hair_light':'F5D99B',
              'wing':'D9C6E9', 'wing_inner':'EAD9EE', 'wing_rim':'B49ACE', 'gold':'E9C06B'},
}
COMMON = {'ink':'4E353C', 'eye':'FFF9EB', 'shine':'FFFFFF', 'cheek':'E8A0A3',
          'cheek_ink':'A86270', 'tongue':'E88E9C', 'tooth':'FFF8E8', 'nose':'AF737C'}

def srgb_linear(hex_color: str) -> np.ndarray:
    x = np.array([int(hex_color[i:i+2],16)/255 for i in (0,2,4)])
    return np.where(x <= .04045, x/12.92, ((x+.055)/1.055)**2.4)

def normalize(a: np.ndarray) -> np.ndarray:
    return a / np.maximum(np.linalg.norm(a, axis=-1, keepdims=True), 1e-12)

def smooth_normals(v: np.ndarray, f: np.ndarray) -> np.ndarray:
    n = np.zeros_like(v, dtype=float)
    fn = np.cross(v[f[:,1]]-v[f[:,0]], v[f[:,2]]-v[f[:,0]])
    for k in range(3): np.add.at(n, f[:,k], fn)
    return normalize(n)

@dataclass
class Shape:
    vertices: np.ndarray
    faces: np.ndarray
    color: str

@dataclass
class Group:
    name: str
    pivot: np.ndarray
    parent: int | None
    glossy: bool = False
    shapes: list[Shape] = field(default_factory=list)

class Model:
    def __init__(self, name: str):
        self.name=name
        self.palette={**COMMON, **PALETTES[name]}
        self.groups: list[Group]=[]
        self.lookup: dict[str,int]={}
        self.animations: list[dict]=[]
        self.group(name.title(), (0,0,0), None)
        self.group('Motion', (0,0,0), 0)

    def group(self, name: str, pivot, parent: int | str | None='Motion', glossy=False) -> int:
        if isinstance(parent,str): parent=self.lookup[parent]
        i=len(self.groups)
        self.groups.append(Group(name,np.array(pivot,dtype=float),parent,glossy))
        self.lookup[name]=i
        return i

    def add(self, group: int | str, v, f, color: str) -> None:
        if isinstance(group,str): group=self.lookup[group]
        v=np.asarray(v,dtype=float); f=np.asarray(f,dtype=np.int32)
        area=np.linalg.norm(np.cross(v[f[:,1]]-v[f[:,0]],v[f[:,2]]-v[f[:,0]]),axis=1)
        f=f[area>1e-12]
        if not len(f): raise ValueError('Empty shape')
        # Vertices are authored in rest-pose world coordinates; pivots stay editable.
        self.groups[group].shapes.append(Shape(v,f,self.palette.get(color,color)))

    def ellipsoid(self, group, center, radii, color='body', seg=28, rings=16, power=1.0, tilt=0.0):
        v,f=ellipsoid(center,radii,seg,rings,power,tilt)
        self.add(group,v,f,color)

    def tube(self, group, points, radius, color='body', sides=10, depth=None):
        v,f=tube(np.asarray(points,float),radius,sides,depth)
        self.add(group,v,f,color)

    def pillow(self, group, boundary, z, depth, color='body', shrink=1.0):
        v,f=pillow(np.asarray(boundary,float),z,depth,shrink)
        self.add(group,v,f,color)

    def track(self, clip, node, path, times, values):
        clip['tracks'].append({'node':self.lookup[node], 'path':path,
                               'times':np.asarray(times,dtype=np.float32),
                               'values':np.asarray(values,dtype=np.float32)})


def ellipsoid(center, radii, seg=28, rings=16, power=1.0, tilt=0.0):
    seg=max(10,round(seg*(1.0 if seg>=34 else .85)));rings=max(6,round(rings*(1.0 if rings>=22 else .85)))
    def sp(a): return np.sign(a)*abs(a)**power
    verts=[[0,-1,0]]
    for j in range(1,rings):
        phi=-math.pi/2+math.pi*j/rings
        for i in range(seg):
            a=2*math.pi*i/seg
            verts.append([sp(math.cos(phi))*sp(math.cos(a)),sp(math.sin(phi)),sp(math.cos(phi))*sp(math.sin(a))])
    verts.append([0,1,0]); top=len(verts)-1
    faces=[]
    for i in range(seg):
        a=1+i;b=1+(i+1)%seg
        faces.append([0,a,b])
    for j in range(rings-2):
        for i in range(seg):
            a=1+j*seg+i;b=1+j*seg+(i+1)%seg;c=a+seg;d=b+seg
            faces.extend([[a,c,b],[b,c,d]])
    for i in range(seg):
        a=1+(rings-2)*seg+i;b=1+(rings-2)*seg+(i+1)%seg
        faces.append([a,top,b])
    v=np.array(verts,dtype=float)*np.array(radii)
    if tilt:
        c,s=math.cos(tilt),math.sin(tilt)
        v=v@np.array([[c,-s,0],[s,c,0],[0,0,1]]).T
    v+=center
    return v,np.array(faces,np.int32)


def bezier(points, count=22) -> np.ndarray:
    p=np.asarray(points,float);t=np.linspace(0,1,count)[:,None]
    return (1-t)**3*p[0]+3*(1-t)**2*t*p[1]+3*(1-t)*t*t*p[2]+t**3*p[3]


def tube(points, radius, sides=10, depth=None):
    """Sweep an elliptical cross-section along a mostly XY path; close both ends."""
    points=np.asarray(points,float); n=len(points)
    r=np.broadcast_to(np.asarray(radius,float),(n,))
    d=r if depth is None else np.broadcast_to(np.asarray(depth,float),(n,))
    tangents=normalize(np.gradient(points,axis=0))
    ref=np.tile(np.array([0.,0.,1.]),(n,1))
    near=np.abs(tangents[:,2])>.94
    ref[near]=np.array([1.,0.,0.])
    u=normalize(np.cross(tangents,ref)); w=normalize(np.cross(tangents,u))
    ang=np.arange(sides)*2*np.pi/sides
    verts=(points[:,None,:]+r[:,None,None]*np.cos(ang)[None,:,None]*u[:,None,:]
           +d[:,None,None]*np.sin(ang)[None,:,None]*w[:,None,:]).reshape((-1,3))
    faces=[]
    for j in range(n-1):
        for i in range(sides):
            a=j*sides+i;b=j*sides+(i+1)%sides;c=a+sides;dd=b+sides
            faces.extend([[a,b,c],[b,dd,c]])
    verts=np.vstack([verts,points[0],points[-1]])
    start,end=len(verts)-2,len(verts)-1
    for i in range(sides):
        faces.extend([[start,(i+1)%sides,i],
                      [end,(n-1)*sides+i,(n-1)*sides+(i+1)%sides]])
    return verts,np.array(faces,np.int32)


def pillow(boundary, z, depth, shrink=1.):
    """A closed softly bevelled planar outline. Boundary must be star-convex."""
    c=boundary.mean(axis=0); boundary=c+(boundary-c)*shrink
    # Force a counterclockwise XY boundary.
    area=np.sum(boundary[:,0]*np.roll(boundary[:,1],-1)-np.roll(boundary[:,0],-1)*boundary[:,1])
    if area<0: boundary=boundary[::-1]
    n=len(boundary)
    # Walk from back centre toward the rim then the front centre.
    levels=[(.06,-.90),(.68,-.70),(.94,-.36),(1.,0.),(.94,.36),(.68,.70),(.06,.90)]
    vv=[]
    for s,h in levels:
        pts=c+(boundary-c)*s
        vv.extend([[p[0],p[1],z+depth*h] for p in pts])
    vv.extend([[c[0],c[1],z-depth],[c[0],c[1],z+depth]])
    f=[]
    for j in range(len(levels)-1):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n;d=b+n;e=a+n
            f.extend([[a,b,e],[b,d,e]])
    bidx=len(vv)-2;fidx=len(vv)-1
    for i in range(n):
        f.extend([[bidx,(i+1)%n,i],[fidx,(len(levels)-1)*n+i,(len(levels)-1)*n+(i+1)%n]])
    return np.asarray(vv),np.asarray(f,dtype=np.int32)


def rounded_triangle(points, samples=6):
    """Round each vertex with a short quadratic corner, retaining a triangular tip."""
    p=np.array(points,float);out=[]
    for i in range(len(p)):
        a=p[i]*.89+p[(i-1)%len(p)]*.11
        b=p[i]*.89+p[(i+1)%len(p)]*.11
        for t in np.linspace(0,1,samples,endpoint=False):
            out.append((1-t)**2*a+2*(1-t)*t*p[i]+t*t*b)
    return np.array(out)


def head_surface(center,radii,x,y):
    a=1-((x-center[0])/radii[0])**2-((y-center[1])/radii[1])**2
    return center[2]+radii[2]*math.sqrt(max(a,.02))


def eyes(m: Model, hc, hr, x=.25, y_offset=.12, size=(.192,.223), asym=.025):
    for side,sign in [('L',-1),('R',1)]:
        ex=sign*x; ey=hc[1]+y_offset+(asym if sign<0 else 0)
        ez=head_surface(hc,hr,ex,ey)-.017
        pivot=(ex,ey,ez)
        g=m.group('Eye_'+side,pivot,'Head',glossy=True)
        rx,ry=size;ry=ry*(1.015 if sign<0 else .985)
        m.ellipsoid(g,(ex,ey,ez+.012),(rx,ry,.098),'eye',seg=28,rings=16,tilt=sign*.075)
        px=ex+(.012 if sign<0 else -.006);py=ey-.007
        m.ellipsoid(g,(px,py,ez+.118),(.076,.091,.027),'ink',seg=24,rings=14,tilt=sign*.03)
        m.ellipsoid(g,(px-.021,py+.034,ez+.144),(.024,.027,.009),'shine',seg=12,rings=8)
        m.ellipsoid(g,(px+.027,py-.026,ez+.143),(.010,.012,.005),'shine',seg=10,rings=6)


def cheeks(m: Model,hc,hr, x=.40,y_offset=-.13):
    y=hc[1]+y_offset
    for sign in [-1,1]:
        cx=sign*x; z=head_surface(hc,hr,cx,y)+.007
        m.ellipsoid('Head',(cx,y,z),(.093,.060,.015),'cheek',seg=20,rings=10)
        for k in [-1,0,1]:
            xx=cx+k*.034
            pts=[]
            for t in np.linspace(0,1,5):
                yy=y+.049-t*.085
                xxx=xx+sign*.009*t
                pts.append([xxx,yy,head_surface(hc,hr,xxx,yy)+.023])
            m.tube('Head',pts,.008,'cheek_ink',sides=7)


def mouth_open(m: Model,hc,hr, wide=False):
    y=hc[1]-.19;z=head_surface(hc,hr,0,y)
    rx=.148 if wide else .091;ry=.094 if wide else .110
    m.ellipsoid('Head',(0,y,z+.008),(rx,ry,.022),'ink',seg=26,rings=14)
    m.ellipsoid('Head',(.007,y-.043,z+.030),(rx*.64,.038,.008),'tongue',seg=20,rings=10)
    count=4 if wide else 3
    for i in range(count):
        xx=(i-(count-1)/2)*(.051 if wide else .044)
        m.ellipsoid('Head',(xx,y+ry*.54,z+.029),(.025 if wide else .021,.030,.012),'tooth',seg=12,rings=8,power=.58)
    if wide:
        for sign in [-1,1]:
            shape=rounded_triangle([(sign*.113,y+.054),(sign*.079,y+.054),(sign*.092,y-.017)],4)
            m.pillow('Head',shape,z+.026,.011,'tooth')


def feet(m: Model,body_bottom=.16,spread=.24,color='body',small=False):
    for side,sign in [('L',-1),('R',1)]:
        c=(sign*spread,.16,.12)
        g=m.group('Foot_'+side,(sign*spread,.27,.03))
        r=(.112,.16,.178) if not small else (.065,.14,.10)
        m.ellipsoid(g,c,r,color,seg=22,rings=14,power=.85)


def arms(m: Model, y=1.02, spread=.285):
    for side,sign in [('L',-1),('R',1)]:
        g=m.group('Arm_'+side,(sign*spread,y+.18,.215))
        m.ellipsoid(g,(sign*spread,y,.29),(.105,.224,.132),'body',seg=24,rings=16,tilt=-sign*.12)
        if m.name=='monkey':
            m.ellipsoid(g,(sign*spread,y-.159,.310),(.080,.087,.103),'light',seg=22,rings=14)


def make_cat() -> Model:
    m=Model('cat');hc=(0,1.76,.015);hr=(.65,.545,.42)
    m.group('Body',(0,.82,0));m.ellipsoid('Body',(0,.83,0),(.465,.715,.35),'body',seg=36,rings=22,power=.86)
    m.ellipsoid('Body',(0,.77,.329),(.290,.410,.088),'belly',seg=28,rings=18)
    m.group('Head',(0,1.42,0));m.ellipsoid('Head',hc,hr,'body',seg=40,rings=26,power=.98)
    for side,sign in [('L',-1),('R',1)]:
        g=m.group('Ear_'+side,(sign*.40,2.11,0),'Head')
        tri=rounded_triangle([(sign*.20,2.11),(sign*.575,2.62),(sign*.63,2.08)],6)
        m.pillow(g,tri,-.005,.11,'body')
        # Inner ear is set into the front face rather than a separate floating fin.
        center=tri.mean(axis=0);inner=center+(tri-center)*np.array([.60,.64]);inner[:,1]+=.025
        m.pillow(g,inner,.095,.013,'inner')
    eyes(m,hc,hr,x=.249,y_offset=.085,size=(.199,.217),asym=.025)
    cheeks(m,hc,hr,x=.387,y_offset=-.15);mouth_open(m,hc,hr)
    arms(m,y=1.00,spread=.279);feet(m,spread=.24)
    g=m.group('Tail',(.365,.48,-.08))
    path=bezier([(.365,.48,-.12),(.83,.66,-.18),(1.18,1.15,-.10),(1.15,1.47,.015)],28)
    tt=np.linspace(0,1,len(path));rad=.069+.020*np.sin(np.pi*tt)
    rad[-3:]=[.061,.043,.004]
    m.tube(g,path,rad,'body',sides=12)
    m.ellipsoid(g,path[-3],(.06,.077,.062),'light',seg=16,rings=10,tilt=-.1)
    return m


def make_bear() -> Model:
    m=Model('bear');hc=(0,1.52,.008);hr=(.615,.555,.40)
    m.group('Body',(0,.72,0));m.ellipsoid('Body',(0,.71,0),(.47,.605,.35),'body',seg=34,rings=22,power=.88)
    m.ellipsoid('Body',(0,.65,.327),(.30,.39,.078),'belly',seg=28,rings=18)
    m.group('Head',(0,1.20,0));m.ellipsoid('Head',hc,hr,'body',seg=40,rings=26)
    for side,sign in [('L',-1),('R',1)]:
        g=m.group('Ear_'+side,(sign*.412,1.96,-.016),'Head')
        m.ellipsoid(g,(sign*.412,2.02,-.016),(.17,.20,.112),'body',seg=26,rings=18,tilt=-sign*.16)
        m.ellipsoid(g,(sign*.412,2.04,.080),(.106,.126,.032),'inner',seg=22,rings=14,tilt=-sign*.16)
    eyes(m,hc,hr,x=.244,y_offset=.13,size=(.176,.206),asym=.020)
    cheeks(m,hc,hr,x=.397,y_offset=-.135)
    yy=hc[1]-.205;zz=head_surface(hc,hr,0,yy)
    m.ellipsoid('Head',(0,yy,zz+.007),(.245,.156,.092),'belly',seg=32,rings=18)
    m.ellipsoid('Head',(0,yy+.022,zz+.094),(.058,.047,.026),'ink',seg=22,rings=14)
    m.ellipsoid('Head',(-.016,yy+.038,zz+.117),(.014,.011,.004),'light',seg=10,rings=6)
    m.tube('Head',[[0,yy,zz+.104],[0,yy-.048,zz+.101]],.008,'ink',sides=8)
    for s in [-1,1]:
        p=bezier([[0,yy-.047,zz+.101],[s*.021,yy-.074,zz+.095],[s*.064,yy-.068,zz+.085],[s*.079,yy-.043,zz+.077]],12)
        m.tube('Head',p,.008,'ink',sides=7)
    arms(m,y=.88,spread=.279);feet(m,spread=.24)
    g=m.group('Tail',(.40,.41,-.17))
    m.ellipsoid(g,(.47,.44,-.22),(.155,.148,.146),'body',seg=22,rings=14)
    return m


def make_rabbit() -> Model:
    m=Model('rabbit');hc=(0,1.67,.012);hr=(.602,.533,.42)
    m.group('Body',(0,.79,0));m.ellipsoid('Body',(0,.78,0),(.427,.662,.335),'body',seg=34,rings=22,power=.87)
    m.ellipsoid('Body',(0,.72,.310),(.279,.39,.069),'belly',seg=26,rings=18)
    m.group('Head',(0,1.34,0));m.ellipsoid('Head',hc,hr,'body',seg=40,rings=26)
    for side,sign in [('L',-1),('R',1)]:
        g=m.group('Ear_'+side,(sign*.34,2.07,0),'Head')
        ctrl=[(-.34,2.07,-.014),(-.42,2.88,-.014),(-.91,2.72,.016),(-.86,2.39,.05)] if sign<0 else [(.34,2.07,-.02),(.47,2.39,-.04),(.58,2.78,-.02),(.56,2.83,.0)]
        p=bezier(ctrl,26);t=np.linspace(0,1,len(p))
        r=.115+.024*np.sin(np.pi*t);r[-4:]=[.104,.085,.052,.004]
        d=r*.62
        m.tube(g,p,r,'body',sides=16,depth=d)
        inner=p[3:-2].copy();inner[:,2]+=d[3:-2]+.008
        rr=r[3:-2]*.49;rr[0]=.018;rr[-1]=.010
        m.tube(g,inner,rr,'inner',sides=10,depth=np.full(len(inner),.014))
    eyes(m,hc,hr,x=.223,y_offset=.103,size=(.173,.218),asym=.035)
    cheeks(m,hc,hr,x=.354,y_offset=-.128)
    yy=hc[1]-.12;zz=head_surface(hc,hr,0,yy)
    tri=rounded_triangle([(-.049,yy+.027),(.049,yy+.027),(0,yy-.030)],5)
    m.pillow('Head',tri,zz+.023,.019,'nose')
    m.tube('Head',[[0,yy-.025,zz+.032],[0,yy-.091,zz+.017]],.009,'ink',sides=8)
    for sign in [-1,1]:
        p=bezier([[0,yy-.070,zz+.018],[sign*.065,yy-.165,zz+.030],[sign*.142,yy-.118,zz+.019],[sign*.145,yy-.061,zz+.006]],18)
        m.tube('Head',p,.010,'ink',sides=8)
    ty=yy-.145;tz=head_surface(hc,hr,0,ty)
    m.ellipsoid('Head',(0,ty,tz+.04),(.073,.068,.023),'ink',seg=20,rings=12)
    for sign in [-1,1]:
        m.ellipsoid('Head',(sign*.024,ty+.006,tz+.063),(.021,.049,.012),'tooth',seg=14,rings=10,power=.58,tilt=sign*.045)
    arms(m,y=.97,spread=.263);feet(m,spread=.221)
    g=m.group('Tail',(.35,.46,-.17))
    m.ellipsoid(g,(.43,.49,-.23),(.163,.172,.153),'light',seg=24,rings=16)
    for off in [(.08,.04,0),(-.04,.11,-.02),(.03,-.09,-.01),(.06,-.01,.10)]:
        c=np.array([.43,.49,-.23])+off
        m.ellipsoid(g,c,(.093,.090,.087),'light',seg=16,rings=10)
    return m


def make_bat() -> Model:
    m=Model('bat');hc=(0,.89,0);hr=(.65,.60,.355)
    m.group('Head',(0,.89,0));m.ellipsoid('Head',hc,hr,'body',seg=40,rings=26,power=.92)
    for side,sign in [('L',-1),('R',1)]:
        g=m.group('Ear_'+side,(sign*.32,1.34,-.018),'Head')
        if sign<0: ctrl=[(-.32,1.34,-.025),(-.37,1.65,-.04),(-.52,1.96,-.03),(-.53,2.035,-.025)]
        else: ctrl=[(.32,1.34,-.025),(.46,1.62,-.045),(.64,1.84,-.03),(.65,1.89,-.02)]
        p=bezier(ctrl,22);t=np.linspace(0,1,len(p))
        rr=.11*(1-.48*t);rr[-3:]=[.041,.020,.002]
        m.tube(g,p,rr,'body',sides=14,depth=rr*.57)
        pp=p[3:-3].copy();pp[:,2]+=rr[3:-3]*.57+.007
        m.tube(g,pp,rr[3:-3]*.45,'inner',sides=10,depth=np.full(len(pp),.009))
    eyes(m,hc,hr,x=.245,y_offset=.11,size=(.192,.219),asym=.027)
    cheeks(m,hc,hr,x=.387,y_offset=-.16);mouth_open(m,hc,hr,wide=True)
    for side,sign in [('L',-1),('R',1)]:
        g=m.group('Wing_'+side,(sign*.50,.94,-.085))
        top=bezier([[.50,1.105],[.92,1.12],[1.46,1.44],[1.74,1.67]],22)
        bottom=bezier([[1.74,1.67],[1.88,.43],[.98,.32],[.54,.49]],26)
        boundary=np.vstack([top,bottom[1:],np.array([[.50,.76]])]);boundary[:,0]*=sign
        m.pillow(g,boundary,-.095,.049,'inner')
        outline=np.vstack([boundary,boundary[:1]])
        m.tube(g,np.c_[outline,np.full(len(outline),-.071)],.025,'rim',sides=8)
        rib=bezier([[sign*.54,.79,-.026],[sign*.93,.76,-.029],[sign*1.48,1.04,-.045],[sign*1.74,1.67,-.068]],26)
        m.tube(g,rib,.018,'rim',sides=8)
        m.ellipsoid(g,(sign*1.74,1.67,-.064),(.032,.049,.031),'rim',seg=14,rings=10)
    for side,sign in [('L',-1),('R',1)]:
        g=m.group('Foot_'+side,(sign*.17,.32,0))
        p=bezier([[sign*.17,.35,0],[sign*.17,.25,.01],[sign*.19,.13,.07],[sign*.19,.074,.11]],12)
        m.tube(g,p,.032,'rim',sides=10)
        m.ellipsoid(g,(sign*.19,.06,.116),(.098,.06,.075),'rim',seg=18,rings=10)
    return m



def make_monkey() -> Model:
    m=Model('monkey'); hc=(0,1.64,.014); hr=(.595,.544,.409)
    m.group('Body',(0,.76,0));m.ellipsoid('Body',(0,.76,0),(.413,.642,.322),'body',seg=36,rings=22,power=.90)
    m.ellipsoid('Body',(0,.70,.290),(.267,.365,.065),'belly',seg=28,rings=18)
    m.group('Head',(0,1.31,0));m.ellipsoid('Head',hc,hr,'body',seg=40,rings=26)
    for side,sign in [('L',-1),('R',1)]:
        g=m.group('Ear_'+side,(sign*.553,1.70,-.01),'Head')
        m.ellipsoid(g,(sign*.640,1.72,-.02),(.241,.268,.136),'body',seg=28,rings=18)
        m.ellipsoid(g,(sign*.658,1.72,.092),(.165,.183,.043),'inner',seg=24,rings=16)
        # The two pale lobes produce the monkey's characteristic heart-like face mask.
        m.ellipsoid('Head',(sign*.215,1.74,.316),(.307,.322,.116),'light',seg=32,rings=22)
    m.ellipsoid('Head',(0,1.467,.350),(.336,.213,.133),'light',seg=32,rings=22)
    # Eyes sit in front of the raised face mask, not through it.
    fhc=(0,1.64,.065);fhr=(.60,.55,.425)
    eyes(m,fhc,fhr,x=.224,y_offset=.119,size=(.172,.193),asym=.024)
    cheeks(m,fhc,fhr,x=.358,y_offset=-.138)
    m.ellipsoid('Head',(0,1.516,.486),(.053,.038,.025),'rim',seg=18,rings=12)
    yy=1.393; zz=.475
    m.ellipsoid('Head',(0,yy,zz),(.135,.084,.025),'ink',seg=24,rings=16)
    m.ellipsoid('Head',(.008,yy-.036,zz+.025),(.083,.027,.009),'tongue',seg=18,rings=10)
    for x in [-.036,.012,.055]:
        m.ellipsoid('Head',(x,yy+.041,zz+.024),(.022,.018,.009),'tooth',seg=12,rings=8,power=.65)
    # A soft curl distinguishes the crown from the bear's round silhouette.
    p=bezier([[-.13,2.134,.035],[-.15,2.405,.065],[.24,2.37,.14],[.12,2.18,.15]],25)
    rr=np.linspace(.071,.012,len(p));m.tube('Head',p,rr,'body',sides=12)
    arms(m,y=.94,spread=.269);feet(m,spread=.215)
    for side in ['L','R']:
        for shape in m.groups[m.lookup['Foot_'+side]].shapes: shape.color=m.palette['light']
    g=m.group('Tail',(.32,.43,-.13))
    start=bezier([[.32,.43,-.13],[.88,.36,-.18],[1.31,.79,-.13],[1.24,1.04,-.07]],24)
    a=np.linspace(0,math.pi*1.77,43);r=np.linspace(.24,.037,len(a))
    curl=np.c_[1.0+r*np.cos(a),1.04+r*np.sin(a),np.linspace(-.07,.004,len(a))]
    p=np.vstack([start,curl[1:]])
    rr=np.full(len(p),.067);rr[-6:]=np.linspace(.065,.003,6)
    m.tube(g,p,rr,'body',sides=12)
    return m


def make_capybara() -> Model:
    m=Model('capybara');hc=(0,1.16,.245);hr=(.604,.514,.442)
    m.group('Body',(0,.62,-.30))
    m.ellipsoid('Body',(0,.62,-.30),(.473,.455,.714),'body',seg=40,rings=24,power=.85)
    m.group('Head',(0,.94,.19));m.ellipsoid('Head',hc,hr,'body',seg=40,rings=26)
    for side,sign in [('L',-1),('R',1)]:
        g=m.group('Ear_'+side,(sign*.415,1.568,.11),'Head')
        m.ellipsoid(g,(sign*.432,1.650,.10),(.121,.147,.088),'body',seg=24,rings=16,tilt=-sign*.17)
        m.ellipsoid(g,(sign*.432,1.670,.175),(.073,.088,.023),'inner',seg=20,rings=12,tilt=-sign*.17)
    eyes(m,hc,hr,x=.297,y_offset=.137,size=(.147,.160),asym=.010)
    # Broad, rounded rectangular snout: no bear-like round button nose.
    m.ellipsoid('Head',(0,1.005,.587),(.427,.242,.237),'light',seg=36,rings=24,power=.73)
    for sign in [-1,1]:
        m.ellipsoid('Head',(sign*.137,1.117,.815),(.030,.021,.010),'rim',seg=14,rings=10,tilt=-sign*.23)
        cx=sign*.445;cy=1.037;cz=.567
        m.ellipsoid('Head',(cx,cy,cz),(.070,.046,.023),'cheek',seg=18,rings=12)
        for k in [-1,0,1]:
            xx=cx+k*.026
            m.tube('Head',[[xx,cy+.031,cz+.022],[xx+sign*.003,cy-.027,cz+.022]],.0065,'cheek_ink',sides=7)
    p=bezier([[-.175,.967,.809],[-.075,.918,.831],[.085,.918,.831],[.175,.967,.809]],20)
    m.tube('Head',p,.008,'rim',sides=8)
    for sign in [-1,1]:
        m.ellipsoid('Head',(sign*.021,.923,.822),(.019,.027,.009),'tooth',seg=12,rings=8,power=.68)
    for x in [-.07,0,.07]:
        p=bezier([[x,1.653,.15],[x-.025,1.750,.11],[x-.008,1.740,.08],[x+.018,1.705,.08]],14)
        m.tube('Head',p,np.linspace(.019,.003,len(p)),'body',sides=8)
    # Four short legs, with front and rear pairs animated out of phase.
    for prefix,z in [('Foot',.328),('HindFoot',-.715)]:
        for side,sign in [('L',-1),('R',1)]:
            g=m.group(prefix+'_'+side,(sign*.300,.375,z))
            m.ellipsoid(g,(sign*.30,.190,z+.029),(.142,.19,.186),'body',seg=24,rings=16,power=.81)
            for k in [-1,1]:
                x=sign*.30+k*.044
                m.tube(g,[[x,.079,z+.193],[x,.143,z+.203]],.0065,'rim',sides=7)
    return m


def petal_skirt(m: Model):
    n=42;layers=9;v=[]
    for j in range(layers):
        t=j/(layers-1)
        y=1.21-.77*t
        r=.181+.283*(math.sin(t*math.pi/2)**1.10)
        for k in range(n):
            a=2*math.pi*k/n
            rr=r*(1+.035*math.cos(7*a)*t)
            yy=y+.061*math.cos(7*a)*(t**5)
            v.append([rr*math.cos(a),yy,rr*.84*math.sin(a)])
    f=[]
    for j in range(layers-1):
        for k in range(n):
            a=j*n+k;b=j*n+(k+1)%n;c=a+n;d=b+n
            f.extend([[a,b,c],[b,d,c]])
    v.extend([[0,1.21,0],[0,.455,0]])
    for k in range(n):
        f.extend([[len(v)-2,(k+1)%n,k], [len(v)-1,(layers-1)*n+k,(layers-1)*n+(k+1)%n]])
    # Ensure the skirt's exterior normals point away from its axis.
    v=np.array(v);f=np.array(f)
    fn=np.cross(v[f[0,1]]-v[f[0,0]],v[f[0,2]]-v[f[0,0]])
    if np.dot(fn,np.array([v[f[0,0],0],0,v[f[0,0],2]]))<0:f=f[:,::-1]
    m.add('Body',v,f,'dress')
    # Raised curved petal seams on the skirt, softly contrasting rather than black.
    for k in range(7):
        a=(k+.5)*2*math.pi/7
        t=np.linspace(.16,.98,20)
        r=(.181+.283*(np.sin(t*math.pi/2)**1.10))*(1+.035*np.cos(7*a)*t)+.008
        y=1.21-.77*t+.061*np.cos(7*a)*(t**5)
        p=np.c_[r*np.cos(a),y,r*.84*np.sin(a)]
        m.tube('Body',p,.010,'petal',sides=7)


def make_fairy() -> Model:
    m=Model('fairy');hc=(0,1.72,.028);hr=(.555,.507,.410)
    m.group('Body',(0,.92,0))
    m.ellipsoid('Body',(0,1.117,0),(.236,.296,.224),'dress',seg=28,rings=18)
    petal_skirt(m)
    m.ellipsoid('Body',(0,1.383,.008),(.100,.116,.093),'body',seg=22,rings=14)
    m.group('Head',(0,1.415,0))
    # Back hair shell remains behind the face; individual locks form the fringe.
    m.ellipsoid('Head',(0,1.779,-.105),(.591,.551,.401),'hair',seg=40,rings=26)
    m.ellipsoid('Head',hc,hr,'body',seg=40,rings=26)
    for side,sign in [('L',-1),('R',1)]:
        g=m.group('Ear_'+side,(sign*.49,1.72,.012),'Head')
        tri=rounded_triangle([(sign*.44,1.82),(sign*.710,1.88),(sign*.51,1.60)],7)
        m.pillow(g,tri,.010,.071,'body')
        center=tri.mean(axis=0);m.pillow(g,center+(tri-center)*.50,.068,.018,'inner')
        # Side locks and bun are rigidly attached to the head.
        m.ellipsoid('Head',(sign*.487,1.986,.09),(.144,.274,.177),'hair',seg=28,rings=18,tilt=-sign*.20)
    eyes(m,hc,hr,x=.215,y_offset=.076,size=(.168,.193),asym=.013)
    cheeks(m,hc,hr,x=.333,y_offset=-.151)
    m.ellipsoid('Head',(0,1.645,.442),(.036,.035,.035),'light',seg=18,rings=12)
    p=bezier([[-.078,1.536,.411],[-.034,1.471,.432],[.055,1.478,.427],[.087,1.542,.407]],22)
    m.tube('Head',p,.009,'ink',sides=8)
    # Rounded swept fringe, with a deliberate part rather than a solid helmet edge.
    for c,r,tilt in [((-.263,2.098,.293),(.218,.120,.127),.35),
                     ((-.063,2.145,.298),(.193,.115,.123),.07),
                     ((.169,2.093,.309),(.242,.122,.129),-.43)]:
        m.ellipsoid('Head',c,r,'hair',seg=28,rings=18,tilt=tilt)
    m.ellipsoid('Head',(-.265,2.329,-.103),(.241,.240,.218),'hair',seg=30,rings=20,tilt=.18)
    m.ellipsoid('Head',(-.243,2.385,.077),(.117,.135,.055),'hair_light',seg=22,rings=14,tilt=.35)
    # Five-petal flower at the bun; it can be recolored in the palette.
    flower=np.array([-.417,2.243,.196])
    for a in np.linspace(0,2*np.pi,5,endpoint=False):
        c=flower+np.array([.073*np.cos(a),.073*np.sin(a),0])
        m.ellipsoid('Head',c,(.049,.054,.025),'wing_inner',seg=16,rings=10,tilt=a)
    m.ellipsoid('Head',flower+[0,0,.023],(.035,.035,.023),'gold',seg=16,rings=10)
    for side,sign in [('L',-1),('R',1)]:
        g=m.group('Arm_'+side,(sign*.239,1.177,.011))
        m.ellipsoid(g,(sign*.285,1.166,.035),(.111,.117,.111),'petal',seg=22,rings=14)
        p=bezier([[sign*.283,1.134,.025],[sign*.375,1.047,.065],[sign*.440,.970,.093],[sign*.472,.986,.098]],18)
        m.tube(g,p,np.linspace(.071,.057,len(p)),'body',sides=12)
        m.ellipsoid(g,(sign*.473,.985,.097),(.077,.078,.072),'light',seg=22,rings=14)
        fg=m.group('Foot_'+side,(sign*.166,.483,.0))
        m.ellipsoid(fg,(sign*.166,.328,.018),(.065,.171,.071),'body',seg=22,rings=14)
        m.ellipsoid(fg,(sign*.175,.104,.089),(.101,.104,.171),'dress',seg=24,rings=16,power=.85)
        m.ellipsoid(fg,(sign*.182,.179,.198),(.041,.041,.046),'gold',seg=16,rings=10)
        wg=m.group('Wing_'+side,(sign*.149,1.140,-.219))
        top=bezier([[.164,1.157],[.328,1.73],[1.025,2.299],[1.159,1.984]],25)
        bot=bezier([[1.159,1.984],[1.373,1.462],[.661,1.145],[.164,1.157]],25)
        bound=np.vstack([top,bot[1:-1]]);bound[:,0]*=sign
        m.pillow(wg,bound,-.247,.064,'wing')
        outline=np.vstack([bound,bound[:1]])
        m.tube(wg,np.c_[outline,np.full(len(outline),-.231)],.018,'wing_rim',sides=8)
        c=bound.mean(axis=0);inner=c+(bound-c)*.72
        m.pillow(wg,inner,-.190,.021,'wing_inner')
        m.ellipsoid(wg,(sign*.706,.921,-.26),(.506,.253,.070),'wing',seg=30,rings=20,tilt=-sign*.39)
        m.ellipsoid(wg,(sign*.721,.936,-.201),(.341,.145,.020),'wing_inner',seg=26,rings=16,tilt=-sign*.39)
    # Wand follows the hand, not the world or the head.
    g=m.group('Wand',(.477,.985,.110),'Arm_R')
    p=bezier([[.477,.951,.135],[.55,1.166,.14],[.637,1.424,.14],[.704,1.609,.14]],18)
    m.tube(g,p,.019,'gold',sides=10)
    star=[]
    for i in range(10):
        a=math.pi/2+i*math.pi/5;r=.156 if i%2==0 else .075
        star.append([.725+r*math.cos(a),1.690+r*math.sin(a)])
    m.pillow(g,np.asarray(star),.144,.037,'gold')
    m.ellipsoid(g,(.699,1.733,.179),(.028,.033,.009),'tooth',seg=12,rings=8)
    return m

