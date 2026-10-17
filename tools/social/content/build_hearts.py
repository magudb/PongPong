#!/usr/bin/env python3
"""Export the forty authored citizen heart scenes and 280 bilingual rows."""
from pathlib import Path
import argparse
import csv
import io
import json
import sys
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0,str(HERE))
from build_festivals import lua, KEEP
CHOICES = {
 '4': [('Vis mig det hele.','Show me everything.'),('Lad os begynde her.','Let us begin here.')],
 '6': [('Vi gør det sammen.','We will do it together.'),('Vis mig dit trick.','Show me your trick.')],
 '8': [('Jeg bliver lidt endnu.','I will stay a little longer.'),('Det tager jeg med mig.','I will carry that with me.')],
 '10':[('Her er også plads til dig.','There is room for you here too.'),('Vi mødes igen snart.','We will meet again soon.')],
}
def build():
    cast = json.loads((HERE/'hearts.json').read_text())
    assert len(cast) == 10
    rows = []
    files = {}
    for npc, author in cast.items():
        events = {}
        previous = ''
        for hearts, copy in author['scenes'].items():
            number = int(hearts)
            assert len(copy['lines']) == (5 if number in (4,8) else 3)
            prefix = 'HEART_'+npc.upper()+'_'+hearts+'_'
            event_id = 'ev_'+npc+'_h'+hearts
            rows.append([prefix+'TITLE',*copy['title']])
            meta = {'npc':npc,'hearts':number,'trigger':'talk','once':True,'area':author['area'],'title_key':prefix+'TITLE','cooldown_days':1,
                    'when':f'hearts:{npc}:{hearts}&hour:8-18&!fest:any&at:{npc}'}
            if previous: meta['after'] = previous
            steps = [{'act':'fade','to':'black','time':.15},{'act':'stand','who':npc,'mark':author['mark'],'facing':'S','clear_view':True}, {'act':'camera','focus':npc,'zoom':.7,'time':.25}, {'act':'face','who':npc,'dir':'S'},{'act':'fade','to':'clear','time':.15}]
            choice_at = 3 if number in (4,8) else 1
            for index, text in enumerate(copy['lines'],1):
                key = prefix+f'{index:02d}'
                rows.append([key,*text])
                steps.append({'act':'say','who':npc,'text_key':key})
                if index == choice_at:
                    options = []
                    for i, choice in enumerate(CHOICES[hearts],1):
                        key = prefix+'CHOICE_'+str(i)
                        rows.append([key,*choice])
                        options.append({'id':'stay' if i==1 else 'remember','text_key':key,'points':20 if i==1 else 10})
                    steps.append({'act':'choice','who':npc,'options':options})
            if number in (4,8): steps.insert(7,{'act':'emote','who':npc,'kind':'heart'})
            steps += [{'act':'give',**copy['gift']},{'act':'camera','focus':'player','zoom':.4,'time':.25},{'act':'end'}]
            assert len(steps) == (15 if number in (4,8) else 12)
            events[event_id] = {'meta':meta,'steps':steps,'rewards':{'points':40}}
            previous = event_id
        path = ROOT/'lua/events/hearts'/(npc+'.lua')
        files[path] = '-- Generated from tools/social/content/hearts.json; ordinary friendship scenes.\nkind = "registry"\nregistry = "events"\nevents = '+lua(events)+'\n'
    output = io.StringIO(newline=''); writer = csv.writer(output,lineterminator='\n')
    writer.writerow(['keys','da','en']);writer.writerows(rows)
    assert len(rows)==280 and len({r[0] for r in rows})==280
    files[ROOT/'localization/heart_events.csv'] = output.getvalue()
    for path in list(files): files[path.with_suffix(path.suffix+'.import')] = KEEP
    return files

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    stale=[]
    for path,text in build().items():
        if args.check:
            if not path.exists() or path.read_text()!=text:stale.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
    if stale: raise SystemExit('stale: '+', '.join(stale))
    print('Forty citizen heart scenes and 280 rows '+('verified' if args.check else 'exported'))
if __name__=='__main__':main()
