#!/usr/bin/env python3
"""Independent policy/pace checks over a dump of the actual Godot Lua registries."""
import argparse,json
from pathlib import Path
RARITIES=['normal','uncommon','rare','unique','legendary']
def validate(data):
    errors=[];pace=[];cfg=data['seek'];ladder=cfg['ladder'];items=data['items'];prizes=set();normal_value=0;fallback_value=0;previous=0
    def check(ok,message):
        if not ok:errors.append(message)
    check(len(ladder)==5,'five rarity steps required')
    for i,step in enumerate(ladder):
        item=items.get(step['item'],{});rarity=RARITIES[i] if i<5 else ''
        check(item.get('category')=='furniture' and item.get('furniture_type')=='lamp',step['item']+': lamp item required')
        check(step.get('rarity')==rarity and item.get('rarity')==rarity,step['item']+': rarity mismatch')
        count=step['finds'];check(count>previous,'find thresholds must increase');previous=count
        value=item.get('sell_price',0);normal_value+=value
        check(value<=400,step['item']+': reward exceeds prize cap')
        prizes.add(step['item'])
        if rarity in ('unique','legendary'):
            check(item.get('max_stack')==1 and value==0,step['item']+': keepsake ownership contract')
            fallback=items.get(step.get('fallback'),{})
            check(fallback.get('rarity')=='rare' and fallback.get('max_stack',0)>1 and fallback.get('sell_price',0)>0 and not fallback.get('protected',False),step['item']+': rare sellable fallback required')
            check(fallback.get('sell_price',0)<=400,step['item']+': fallback exceeds prize cap')
            fallback_value+=fallback.get('sell_price',0)
            prizes.add(step.get('fallback'))
        pace.append(dict(finds=count,typical_game_weeks=count/4,dedicated_game_weeks=count/12,typical_real_hours=count/4*data['week_real_minutes']/60,dedicated_real_hours=count/12*data['week_real_minutes']/60))
    check(normal_value<=370,'sellable ladder exceeds 370 gold')
    check(normal_value+fallback_value<=900,'fallback ladder exceeds 900 gold')
    for key,recipe in data['recipes'].items():
        check(not prizes.intersection(recipe.get('ingredients',{})),key+': ladder item is a recipe ingredient')
    check(not prizes.intersection(row.get('item') for row in data['set_rewards']),'ladder repeats a set capstone')
    check(cfg['daily_cap']==2 and cfg['find_points']==5,'find reward/cap differs from approved design')
    check(set(cfg['flags'].values())=={'int'} and len(cfg['flags'])==6 and all(k.startswith('ghostfam_seek_') for k in cfg['flags']),'six scalar flags required')
    return dict(ok=not errors,errors=errors,items=len(items),recipes=len(data['recipes']),sellable_gold=normal_value,worst_fallback_gold=normal_value+fallback_value,pace=pace)
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--input',type=Path,required=True);ap.add_argument('--out',type=Path);args=ap.parse_args()
    report=validate(json.loads(args.input.read_text()))
    if args.out:args.out.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,sort_keys=True))
    raise SystemExit(0 if report['ok'] else 1)
if __name__=='__main__':main()
