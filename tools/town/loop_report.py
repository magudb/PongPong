#!/usr/bin/env python3
"""Turn the town loop's named checks and explicit skips into a wave gate table."""
import argparse
import json
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
GATES=json.loads((ROOT/'tests/lib/town_loop/gates.json').read_text())['waves']
def required(wave):
    out=[]
    for entry in GATES[wave]:
        for item in required(entry[1:]) if entry.startswith('@') else [entry]:
            if item not in out:out.append(item)
    return out

def report(log):
    checks={}
    for status,name in re.findall(r'\b(ok|FAIL)\s+town_loop\.([\w.]+)',log):
        checks[name]=checks.get(name,True) and status=='ok'
    skips=re.findall(r'\bskip\s+(.+)',log,re.I)
    table={}
    for wave in GATES:
        rows=[]
        for entry in required(wave):
            leg,_,exact=entry.partition('.')
            matching={name:ok for name,ok in checks.items() if name==exact or (not exact and name.lower().startswith(leg.lower()+'_'))}
            reasons=[s for s in skips if leg in s]
            rows.append({'required':entry,'ran':len(matching),'failed':[name for name,ok in matching.items() if not ok],'skipped_with_reason':reasons or ([] if matching else ['Required leg did not run'])})
        table[wave]=rows
    return table
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path,nargs='?');p.add_argument('--selftest',action='store_true');p.add_argument('--wave',choices=list(GATES),default='5b');p.add_argument('--out',type=Path);a=p.parse_args()
    if a.selftest:
        log='\n'.join('  ok    town_loop.'+(item.split('.',1)[1] if '.' in item else item.lower()+'_probe') for item in required('5b'))
        table=report(log)
        assert set(table)==set(GATES) and all(row['ran'] and not row['failed'] for row in table['5b'])
        assert any(not row['ran'] for row in table['7'])
        first=required('5b')[0].split('.',1)[1]
        bad=report(log+'\n  FAIL  town_loop.'+first+'\n  ok    town_loop.'+first)
        assert any(row['failed'] for row in bad['5b'])
        print('Every required wave/leg listed; missing and repeated failing checks retained.');raise SystemExit(0)
    if a.log is None:p.error('log is required unless --selftest is used')
    table=report(a.log.read_text());text=json.dumps(table,indent=2)+'\n'
    if a.out:a.out.write_text(text)
    print(text,end='');raise SystemExit(any(not row['ran'] or row['failed'] or row['skipped_with_reason'] for row in table[a.wave]))
