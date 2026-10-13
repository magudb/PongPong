import sys, io, json
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter
INK=np.array([43,35,64])
def ring_colour(im):
    """mean colour of the OUTERMOST opaque-ish ring (alpha>=128 pixels that touch an alpha<32 pixel)"""
    a=np.array(im.getchannel('A')).astype(int); rgb=np.array(im.convert('RGB')).astype(int)
    solid=a>=128; empty=a<32
    from scipy.ndimage import binary_dilation
    touch=binary_dilation(empty, iterations=2) & solid
    if touch.sum()==0: return None, 0
    return rgb[touch].mean(0), int(touch.sum())
def webp_bytes(im):
    b=io.BytesIO(); im.save(b,'WEBP',lossless=True,exact=True,method=6); return len(b.getvalue())
def fill_fraction(im):
    bb=im.getchannel('A').point(lambda v:255 if v>8 else 0).getbbox()
    return (bb[2]-bb[0])/im.width,(bb[3]-bb[1])/im.height
def audit(d):
    tot=0; bad=[]; fills=[]
    for f in sorted(Path(d).glob('*.png')):
        im=Image.open(f).convert('RGBA')
        c,n=ring_colour(im)
        tot+=webp_bytes(im)
        fw,fh=fill_fraction(im); fills.append(max(fw,fh))
        if c is None or np.abs(c-INK).max()>24: bad.append((f.stem,None if c is None else tuple(int(x) for x in c)))
    return dict(n=len(list(Path(d).glob('*.png'))), webp_total_kb=round(tot/1024), avg_kb=round(tot/1024/ max(1,len(fills)),1), ring_not_ink=len(bad), ring_bad_examples=bad[:6], fill_mean=round(float(np.mean(fills)),3), fill_min=round(float(np.min(fills)),3))
if __name__=='__main__':
    for d in sys.argv[1:]: print(d, json.dumps(audit(d)))
