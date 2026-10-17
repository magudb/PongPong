#!/usr/bin/env python3
"""Export the eleven Natlys scenes; all dialogue remains unvoiced draft copy."""
from pathlib import Path
import argparse
import csv
import io
import json
from build_festivals import lua, KEEP
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
def build():
    authors=json.loads((HERE/'natlys.json').read_text())
    assert len(authors)==11
    rows=[];events={}
    for eid,a in authors.items():
        prefix='GF_EVENT_'+eid.removeprefix('ev_').upper()+'_'
        rows.append([prefix+'TITLE',*a['title']])
        meta={'npc':a['npc'],'hearts':a['hearts'],'trigger':'talk','once':True,'area':a['area'],
              'title_key':prefix+'TITLE','cooldown_days':1,'when':a['when']}
        if a.get('after'):meta['after']=a['after']
        steps=[{'act':'camera','focus':'mark:'+a['mark'],'zoom':.65,'time':.25}]
        for actor in [a['npc']]+a.get('actors',[]):
            steps.append({'act':'face','who':actor,'dir':'S'})
        for i,line in enumerate(a['lines'],1):
            line=line if isinstance(line,dict) else {'text':line}
            key=prefix+str(i)
            rows.append([key,*line['text']])
            steps.append({'act':'say','who':line.get('who',a['npc']),'text_key':key,
                          **({'when':line['when']} if line.get('when') else {})})
            if i==2:steps.append({'act':'emote','who':a['npc'],'kind':'heart'})
        if a.get('gift'):steps.append({'act':'give',**a['gift']})
        if a.get('flag'):steps.append({'act':'flag','key':a['flag'],'value':True})
        steps += [{'act':'camera','focus':'player','zoom':.4,'time':.25},{'act':'end'}]
        events[eid]={'meta':meta,'steps':steps,'rewards':{'points':a.get('points',40)}}
    out=io.StringIO(newline='');w=csv.writer(out,lineterminator='\n');w.writerow(['keys','da','en']);w.writerows(rows)
    files={ROOT/'lua/events/ghostfam/natlys.lua':'-- Generated from tools/social/content/natlys.json.\nkind = "registry"\nregistry = "events"\nevents = '+lua(events)+'\n',ROOT/'localization/ghostfamily_events.csv':out.getvalue()}
    for p in list(files):files[p.with_suffix(p.suffix+'.import')]=KEEP
    return files,len(rows)
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
    files,n=build();stale=[]
    for path,data in files.items():
        if args.check:
            if not path.exists() or path.read_text()!=data:stale.append(str(path.relative_to(ROOT)))
        else:path.parent.mkdir(parents=True,exist_ok=True);path.write_text(data)
    if stale:raise SystemExit('stale: '+', '.join(stale))
    print(f'Eleven Natlys events and {n} rows '+('verified' if args.check else 'exported'))
if __name__=='__main__':main()
