#!/usr/bin/env python3
"""Pre-pack source gate: separated drawings and the authored width/height ladder."""
from pathlib import Path
import pack_family

HERE = Path(__file__).resolve().parent
TARGET = {'ghostfam_dyne': 1.04, 'ghostfam_gnist': .68, 'ghostfam_silke': .62, 'ghostfam_blund': .90}

def aspect_ok(aspect, target):
    return abs(aspect / target - 1) <= .12

def main():
    pack = pack_family.pack
    views = pack.extract(HERE/'sources/family_turnarounds.png',4,4)
    backs = pack.extract(HERE/'sources/family_rears.png',2,2)
    silke = pack.extract(HERE/'sources/silke_refined.png',1,5)
    errors = []
    for index,cid in enumerate(pack_family.IDS):
        front = silke[0] if cid == 'ghostfam_silke' else views[index*4]
        aspect = front.width / front.height
        print(f'{cid}: source aspect {aspect:.3f}, target {TARGET[cid]:.2f} ±12%')
        if not aspect_ok(aspect,TARGET[cid]):
            errors.append(cid+': redraw silhouette')
    if aspect_ok(.765,TARGET['ghostfam_silke']):
        errors.append('Negative control: former wide Silke must be rejected')
    if len(views)!=16 or len(backs)!=4 or len(silke)!=5:
        errors.append('Turnaround/rear view island count')
    for error in errors:
        print('FAIL '+error)
    print(f'Family source gate: {len(errors)} problems')
    return bool(errors)

if __name__ == '__main__':
    raise SystemExit(main())
