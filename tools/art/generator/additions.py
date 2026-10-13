"""Five additional original chibi animal designs, using the same geometry vocabulary."""
import math
import numpy as np
from geometry import Model, PALETTES, eyes, cheeks, arms, feet, bezier, rounded_triangle, head_surface

PALETTES.update({
 'fox':dict(body='ECA56C',light='FFE8C6',inner='DDA5A4',rim='80564F',belly='FFF1D8'),
 'raccoon':dict(body='ABA7B0',light='E3DDE0',inner='D8ADB8',rim='5E5367',belly='EAE4E5'),
 'penguin':dict(body='647084',light='FFF4DC',inner='E6B086',rim='424855',belly='FFF4DC',beak='EFBA76'),
 'hedgehog':dict(body='E2BC96',light='F4DBB7',inner='D8A59B',rim='866552',belly='F9E7C7',spike='AD8064'),
 'frog':dict(body='8BC394',light='D5E9AD',inner='ADD3A2',rim='578468',belly='E4EEBD'),
})

def muzzle(m,hc,hr,fox=False):
 y=hc[1]-.19; z=head_surface(hc,hr,0,y)
 if fox:
  for s in [-1,1]:
   m.ellipsoid('Head',(s*.24,y+.02,z-.037),(.235,.163,.095),'belly',seg=28,rings=18,tilt=s*.22)
 m.ellipsoid('Head',(0,y,z+.02),(.205,.138,.129),'light',seg=28,rings=18)
 m.ellipsoid('Head',(0,y+.041,z+.146),(.060,.043,.027),'rim',seg=22,rings=14)
 m.ellipsoid('Head',(-.016,y+.055,z+.169),(.015,.012,.006),'shine',seg=12,rings=8)
 for s in [-1,1]:
  p=bezier([[0,y+.019,z+.153],[s*.024,y-.066,z+.160],[s*.098,y-.058,z+.147],[s*.108,y-.022,z+.125]],14)
  m.tube('Head',p,.008,'rim',sides=8)

def body(m,hc,hr):
 m.group('Body',(0,.73,0));m.ellipsoid('Body',(0,.77,0),(.449,.633,.333),'body',seg=36,rings=22,power=.88)
 m.ellipsoid('Body',(0,.72,.306),(.287,.390,.071),'belly',seg=28,rings=18)
 m.group('Head',(0,hc[1]-.32,0));m.ellipsoid('Head',hc,hr,'body',seg=40,rings=26)

def tuft_ears(m,hc):
 for side,s in [('L',-1),('R',1)]:
  g=m.group('Ear_'+side,(s*.395,hc[1]+.39,-.02),'Head')
  tri=rounded_triangle([(s*.22,hc[1]+.37),(s*.59,hc[1]+.98),(s*.64,hc[1]+.31)],7)
  m.pillow(g,tri,-.02,.106,'body'); c=tri.mean(axis=0)
  m.pillow(g,c+(tri-c)*[.58,.66]+[0,.025],.086,.014,'inner')

def round_ears(m,hc,small=False):
 for side,s in [('L',-1),('R',1)]:
  g=m.group('Ear_'+side,(s*.41,hc[1]+.43,-.03),'Head')
  r=.145 if small else .18
  m.ellipsoid(g,(s*.43,hc[1]+.46,-.025),(r,r*1.08,.104),'body',seg=24,rings=16)
  m.ellipsoid(g,(s*.43,hc[1]+.48,.065),(r*.63,r*.69,.023),'inner',seg=20,rings=12)

def colored_tail(m,points,radii):
 g=m.group('Tail',points[0]);m.tube(g,points,radii,'body',sides=16)
 shape=m.groups[g].shapes[-1]
 shape.uv=np.vstack([np.array([[k/16,j/(len(points)-1)] for j in range(len(points)) for k in range(16)]),[[.5,0],[.5,1]]])
 shape.pattern='tail_'+m.name
 shape.path=np.array(points)

def make_fox():
 m=Model('fox');hc=(0,1.61,.025);hr=(.62,.54,.408)
 body(m,hc,hr);tuft_ears(m,hc)
 eyes(m,hc,hr,x=.239,y_offset=.095,size=(.181,.211),asym=.018)
 muzzle(m,hc,hr,True);cheeks(m,hc,hr,x=.413,y_offset=-.091)
 arms(m,y=.94,spread=.285);feet(m,spread=.23,color='rim')
 p=bezier([[.31,.43,-.15],[.95,.27,-.26],[1.20,.74,-.24],[1.10,1.46,-.20]],36)
 t=np.linspace(0,1,len(p));r=.090+.145*np.sin(np.pi*t)**.85;r[-4:]=[.089,.068,.041,.008]
 colored_tail(m,p,r)
 return m

def make_raccoon():
 m=Model('raccoon');hc=(0,1.60,.02);hr=(.618,.537,.409)
 body(m,hc,hr);round_ears(m,hc)
 for s in [-1,1]:
  m.ellipsoid('Head',(s*.231,1.718,.352),(.275,.215,.087),'rim',seg=30,rings=18,tilt=-s*.11)
 eyes(m,(0,1.60,.068),hr,x=.238,y_offset=.095,size=(.162,.187),asym=.017)
 muzzle(m,hc,hr);cheeks(m,hc,hr,x=.412,y_offset=-.125)
 arms(m,y=.94,spread=.281);feet(m,spread=.23,color='rim')
 p=bezier([[.32,.46,-.17],[.72,.26,-.34],[1.02,.45,-.29],[1.08,1.20,-.23]],34)
 t=np.linspace(0,1,len(p));r=.14+.035*np.sin(np.pi*t);r[-4:]=[.119,.093,.062,.009]
 colored_tail(m,p,r)
 return m

def make_penguin():
 m=Model('penguin');hc=(0,1.43,.02);hr=(.591,.521,.397)
 body(m,hc,hr)
 # Joined pale facial lobes leave a heart-shaped crown.
 for s in [-1,1]:
  m.ellipsoid('Head',(s*.192,1.45,.301),(.291,.366,.123),'light',seg=32,rings=20)
 eyes(m,(0,1.45,.073),hr,x=.225,y_offset=.086,size=(.165,.188),asym=.015)
 m.ellipsoid('Head',(0,1.279,.457),(.135,.080,.130),'beak',seg=26,rings=16,power=.82)
 m.ellipsoid('Head',(0,1.225,.454),(.094,.033,.111),'inner',seg=24,rings=12)
 cheeks(m,(0,1.43,.06),hr,x=.371,y_offset=-.126)
 for side,s in [('L',-1),('R',1)]:
  g=m.group('Arm_'+side,(s*.407,1.04,.012))
  m.ellipsoid(g,(s*.474,.82,.035),(.137,.31,.090),'body',seg=28,rings=18,tilt=s*.31)
  g=m.group('Foot_'+side,(s*.23,.19,.07))
  m.ellipsoid(g,(s*.235,.09,.13),(.175,.09,.23),'beak',seg=26,rings=14,power=.78)
  for k in [-1,0,1]:
   m.ellipsoid(g,(s*.235+k*.086,.075,.283),(.059,.055,.090),'beak',seg=16,rings=10)
 g=m.group('Tail',(0,.39,-.27));m.ellipsoid(g,(0,.35,-.36),(.18,.16,.215),'body',seg=24,rings=16)
 return m

def make_hedgehog():
 m=Model('hedgehog');hc=(0,1.55,.08);hr=(.567,.514,.380)
 body(m,hc,hr)
 # Soft spines on the rear hemisphere, never across the face.
 m.ellipsoid('Head',(0,1.61,-.134),(.637,.567,.410),'spike',seg=36,rings=24)
 m.ellipsoid('Head',hc,hr,'body',seg=40,rings=26)
 round_ears(m,hc,True)
 for j in range(4):
  phi=.26+j*.40
  for k in range(12):
   theta=2*math.pi*(k+.35*(j%2))/12
   v=np.array([math.sin(phi)*math.cos(theta),math.cos(phi),math.sin(phi)*math.sin(theta)])
   if v[2]>.18:continue
   c=np.array([v[0]*.58,1.61+v[1]*.515,-.134+v[2]*.39]);p=np.array([c+v*t for t in [0,.055,.11,.16]])
   m.tube('Head',p,[.088,.076,.045,.008],'rim' if k%3==0 else 'spike',sides=10)
 eyes(m,hc,hr,x=.222,y_offset=.107,size=(.166,.194),asym=.022)
 muzzle(m,hc,hr);cheeks(m,hc,hr,x=.365,y_offset=-.128)
 arms(m,y=.94,spread=.282);feet(m,spread=.23)
 return m

def make_frog():
 m=Model('frog');hc=(0,1.40,.015);hr=(.692,.437,.368)
 body(m,hc,hr)
 for s in [-1,1]:
  m.ellipsoid('Head',(s*.306,1.750,.037),(.237,.254,.218),'body',seg=30,rings=20)
 eyes(m,(0,1.620,.035),(.66,.52,.39),x=.301,y_offset=.162,size=(.17,.196),asym=.01)
 cheeks(m,hc,hr,x=.467,y_offset=-.054)
 for s in [-1,1]:m.ellipsoid('Head',(s*.064,1.454,.382),(.012,.016,.010),'rim',seg=12,rings=10)
 p=bezier([[-.234,1.303,.364],[-.13,1.18,.410],[.13,1.18,.410],[.234,1.303,.364]],28)
 m.tube('Head',p,.010,'rim',sides=8)
 arms(m,y=.94,spread=.28);feet(m,spread=.25)
 for side,s in [('L',-1),('R',1)]:
  for k in [-1,0,1]:m.ellipsoid('Foot_'+side,(s*.25+k*.079,.07,.259),(.052,.062,.103),'light',seg=18,rings=12)
 return m

BUILDERS={x:globals()['make_'+x] for x in ['fox','raccoon','penguin','hedgehog','frog']}
