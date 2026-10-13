import math
import numpy as np
def hexc(h): return tuple(int(h[i:i+2],16) for i in (0,2,4))
def lin(c):
    c=np.asarray(c,float)/255.0
    return np.where(c<=0.04045,c/12.92,((c+0.055)/1.055)**2.4)
def lum(c):
    r,g,b=lin(c); return 0.2126*r+0.7152*g+0.0722*b
def contrast(a,b):
    la,lb=lum(hexc(a) if isinstance(a,str) else a),lum(hexc(b) if isinstance(b,str) else b)
    if la<lb: la,lb=lb,la
    return (la+0.05)/(lb+0.05)
def lab(c):
    r,g,b=lin(hexc(c) if isinstance(c,str) else c)
    x=(0.4124564*r+0.3575761*g+0.1804375*b)/0.95047
    y=(0.2126729*r+0.7151522*g+0.0721750*b)
    z=(0.0193339*r+0.1191920*g+0.9503041*b)/1.08883
    f=lambda t: t**(1/3) if t>216/24389 else (24389/27*t+16)/116
    fx,fy,fz=f(x),f(y),f(z)
    return 116*fy-16,500*(fx-fy),200*(fy-fz)
def de2000(c1,c2):
    L1,a1,b1=lab(c1); L2,a2,b2=lab(c2)
    C1=math.hypot(a1,b1); C2=math.hypot(a2,b2); Cb=(C1+C2)/2
    G=0.5*(1-math.sqrt(Cb**7/(Cb**7+25**7)))
    a1p=(1+G)*a1; a2p=(1+G)*a2
    C1p=math.hypot(a1p,b1); C2p=math.hypot(a2p,b2)
    h1p=math.degrees(math.atan2(b1,a1p))%360; h2p=math.degrees(math.atan2(b2,a2p))%360
    dLp=L2-L1; dCp=C2p-C1p
    if C1p*C2p==0: dhp=0
    else:
        dhp=h2p-h1p
        if dhp>180: dhp-=360
        elif dhp<-180: dhp+=360
    dHp=2*math.sqrt(C1p*C2p)*math.sin(math.radians(dhp/2))
    Lbp=(L1+L2)/2; Cbp=(C1p+C2p)/2
    if C1p*C2p==0: hbp=h1p+h2p
    else:
        hbp=(h1p+h2p)/2 if abs(h1p-h2p)<=180 else ((h1p+h2p+360)/2 if h1p+h2p<360 else (h1p+h2p-360)/2)
    T=1-0.17*math.cos(math.radians(hbp-30))+0.24*math.cos(math.radians(2*hbp))+0.32*math.cos(math.radians(3*hbp+6))-0.20*math.cos(math.radians(4*hbp-63))
    dth=30*math.exp(-((hbp-275)/25)**2)
    Rc=2*math.sqrt(Cbp**7/(Cbp**7+25**7))
    Sl=1+0.015*(Lbp-50)**2/math.sqrt(20+(Lbp-50)**2); Sc=1+0.045*Cbp; Sh=1+0.015*Cbp*T
    Rt=-math.sin(math.radians(2*dth))*Rc
    return math.sqrt((dLp/Sl)**2+(dCp/Sc)**2+(dHp/Sh)**2+Rt*(dCp/Sc)*(dHp/Sh))
