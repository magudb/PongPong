#!/usr/bin/env python3
"""Prove named checks reject real producer regressions in isolated COW clones."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
from prove_extension import ROOT, binding
REPORT=ROOT/'docs/qa/m1b-milestone/loop-mutants.json'
MUTANTS=[
 ('hours','scripts/towns/hours.gd','return bool(GameData.cfg("towns.hours_enabled", true))','return false','l05_closed_before_open'),
 ('projection','data/maps/int_froebutikken.map','@projection iso','@projection ortho','l04_zone_and_running_clock'),
 ('free','scripts/towns/town_director.gd','\t\tactor.queue_free()','\t\tpass # negative control: retain actor','l02_citizens_freed_on_exit'),
 ('escape','scripts/social/social_manager.gd','\tif not completed:','\tif false:','l03_esc_first_line_no_heart'),
 ('digest','tests/lib/town_loop/digest_volatile.json','"/meta/summary"','"/meta/summary","/economy"','digest_has_teeth_gold'),
 ('order','scripts/social/social_manager.gd','const SECTION_ORDER := 60','const SECTION_ORDER := 10','l13_social_section_order'),
 ('closed-door','scripts/towns/door_2d.gd','\tif not is_open():','\tif false:','l05_closed_door_does_not_travel')]

def prove():
    captured=binding(); evidence=ROOT/'docs/qa/m1b-milestone/mutants';evidence.mkdir(parents=True,exist_ok=True)
    results={}
    for name,path,old,new,target in [('baseline','','','','')]+MUTANTS:
        with tempfile.TemporaryDirectory(prefix='pongpong-town-mutant-') as tmp:
            clone=Path(tmp)/'project'
            subprocess.run(['/bin/cp','-cR',str(ROOT),str(clone)],check=True)
            (clone/'.git').unlink(missing_ok=True)
            if path:
                p=clone/path;text=p.read_text();assert text.count(old)==1,(name,text.count(old));p.write_text(text.replace(old,new))
            env=os.environ.copy();env.pop('TOWN_LOOP_WAVE',None);env['GODOT_EXTRA_ARGS']='--fixed-fps 60'
            with (evidence/(name+'.log')).open('w') as log:
                result=subprocess.run(['tests/run_playtest.sh','--strict','--no-boot','--sections-dir=res://tests/lib/town_loop/mutation_sections','--only=town_mutants','--report=mutant.json'],cwd=clone,env=env,stdout=log,stderr=subprocess.STDOUT)
            data=json.loads((clone/'mutant.json').read_text());(evidence/(name+'.json')).write_text(json.dumps(data,indent=2)+'\n')
            log=(evidence/(name+'.log')).read_text()
            clean=not data.get('engine') and not data.get('problems') and 'SCRIPT ERROR' not in log and 'ERROR:' not in log
            caught=result.returncode==0 if name=='baseline' else result.returncode!=0 and ('FAIL  town_mutants.'+target) in log
            assert clean and caught,(name,'failed to catch the named regression cleanly')
            results[name]={'caught':caught,'check':target or 'all probes green'}
    # P24 does not ship with M1b. Installing its hook must add this mutant.
    assert 'cue_log' not in (ROOT/'scripts/autoload/audio_manager.gd').read_text(), 'Audio hook installed: add cue-without-log mutant'
    report={'result':'pass','binding':captured,'mutants':results,'skipped':{'audio':'P24 cue_log capability is not installed'},'note':'Each producer is changed on a fresh clone. The unmodified probes pass first; each mutant must fail its named behavioural check without engine errors.'}
    REPORT.write_text(json.dumps(report,indent=2)+'\n');return report
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args()
    try:
        if a.check:
            r=json.loads(REPORT.read_text());assert r['result']=='pass' and r['binding']==binding(),'Mutant proof is stale; rerun prove_mutants.py'
        else:r=prove()
        print(json.dumps(r))
    except (OSError,ValueError,AssertionError) as e:
        print(json.dumps({'result':'fail','error':str(e)}));raise SystemExit(1)
