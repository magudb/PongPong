#!/usr/bin/env python3
"""P1 reproducible live-data economy acceptance. No Godot process is started."""
import argparse
import contextlib
import hashlib
import io
import json
from pathlib import Path
import mc
import pacing

ROOT=Path(__file__).resolve().parents[2]

def binding():
    files=sorted([*ROOT.glob('lua/**/*.lua'),*Path(__file__).parent.glob('*.py'),ROOT/'tools/features/sim/balance_sim.py'])
    digest=hashlib.sha256()
    for path in files:
        digest.update(path.relative_to(ROOT).as_posix().encode()+b'\0'+path.read_bytes()+b'\0')
    return digest.hexdigest()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--n',type=int,default=64);ap.add_argument('--dives',type=int,default=1000);ap.add_argument('--report',type=Path);ap.add_argument('--check',action='store_true');ap.add_argument('--pace',choices=['plan','de30'],default='plan');args=ap.parse_args()
    if args.n<1 or args.dives<1 or (args.check and (args.n<32 or args.dives<1000)):ap.error('acceptance needs at least 32 saves per profile and 1,000 full dives')
    mc.set_pace(args.pace)
    world=mc.World()
    keep=pacing.simulate(args.n)
    free=pacing.simulate(args.n,free=True)
    uncapped=mc.full_dive(world,args.dives,0,False,details=True)
    capped=mc.full_dive(world,args.dives,0,True,details=True)
    with contextlib.redirect_stdout(io.StringIO()):bands=mc.band_stats(world,n=args.dives,mode='sell')
    checks=[]
    def within(id,value,low,high):checks.append(dict(id=id,ok=low<=value<=high,actual=value,min=low,max=high))
    within('P1_typical_castle_keep',keep['typical']['median'],220,280)
    within('P1_typical_castle_furniture_substitution',free['typical']['median'],180,230)
    within('P1_casual_castle_keep',keep['casual']['median'],650,780)
    within('P1_dedicated_castle_keep',keep['dedicated']['median'],115,160)
    within('P1_uncapped_full_dive',uncapped['mean'],2409*.8,2409*1.2)
    within('P1_capped_retains_value',capped['mean']/uncapped['mean'],.85,1)
    within('P1_cap_before_floor10',capped['cap_before_floor10'],0,.10)
    within('P1_glimmer_dust_sold_share',capped['dust_share'],0,.12)
    within('P1_band4_rare_per_floor',bands[('krystalgrotten',0.)]['rare_per_floor'],1,100)
    report=dict(source_binding=binding(),model='Named plan assumptions; independent Python RNG; no combat, navigation or player telemetry. Eight-minute dungeon runs and ten-minute home days are modelling units. All dng_ surplus sells at its actual full sell price. Free furniture is banked once and only replaces planned furniture purchases; both hooks are off by default in the plan model.',seed='pacing 100..100+n-1, full dive 77, band sample 1',pace=args.pace,keep=keep,free_furniture=free,uncapped=uncapped,capped=capped,checks=checks,passed=all(x['ok'] for x in checks))
    text=json.dumps(report,indent=2)+'\n'
    if args.report:args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(text)
    print(text,end='')
    return int(args.check and not report['passed'])

if __name__=='__main__':raise SystemExit(main())
