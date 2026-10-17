"""Inject actual dungeon Monte Carlo days into the plan's home balance model.

This is a model of named farming, run frequency and spending assumptions, not
play telemetry or a combat simulation. Free furniture only replaces the day's
planned furniture purchase; it is neither sold nor added to the wallet twice.
"""
import copy
import importlib.util
import statistics
from pathlib import Path
import mc
from live_data import snapshot

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('plan_balance',ROOT/'tools/features/sim/balance_sim.py')
balance=importlib.util.module_from_spec(spec);spec.loader.exec_module(balance)

def inject(world, daily):
    world.forest_day=lambda day:daily.get(day,{})
    return world

def simulate(n=32, free=False, seed=100):
    data=snapshot();dungeon=mc.World(data)
    original=(balance.FREE_FURN_REPLACES,balance.FREE_FURN_RATE)
    balance.FREE_FURN_REPLACES=free;balance.FREE_FURN_RATE=1.0 if free else 0.0
    results={}
    try:
        for name,profile in balance.PROFILES.items():
            days=[];replacement=[];runs=[]
            for i in range(n):
                life=mc.lifetime(dungeon,name,seed+i,days=balance.SIM_DAYS,mode='keep')
                world=inject(balance.World(data,data,'plan'),life['daily'])
                result=balance.simulate(world,name,copy.deepcopy(profile))
                days.append(result['done'].get(10,balance.SIM_DAYS+1))
                replacement.append(result['stats'].get('free_furniture_substitution',0));runs.append(life['runs'])
            results[name]=dict(median=statistics.median(days),mean=statistics.mean(days),min=min(days),max=max(days),samples=n,mean_replaced=statistics.mean(replacement))
    finally:balance.FREE_FURN_REPLACES,balance.FREE_FURN_RATE=original
    return results

if __name__=='__main__':
    import argparse,json
    ap=argparse.ArgumentParser();ap.add_argument('--n',type=int,default=32);ap.add_argument('--free-furniture',action='store_true');args=ap.parse_args()
    print(json.dumps(simulate(args.n,args.free_furniture),indent=2))
