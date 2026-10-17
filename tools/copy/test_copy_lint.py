#!/usr/bin/env python3
"""Copy rule mutants with an isolated literal roster and tiny valid corpus."""
from pathlib import Path
import csv, json, tempfile
import copy_lint

def check(name,ok):
    print(('PASS ' if ok else 'FAIL ')+name)
    return not ok

def write_csv(root,rows):
    file=root/'localization/probe.csv'
    with file.open('w',newline='') as f:csv.writer(f).writerows([['keys','da','en']]+rows)
    status={'localization/probe.csv':dict(status='draft',rows=len(rows),reviewed_by='',date='',voice_frozen=False)}
    (root/'docs/copy/review_status.json').write_text(json.dumps(status))

def main():
    failures=0
    with tempfile.TemporaryDirectory(prefix='traetoppen-copy-') as folder:
        root=Path(folder)
        for d in ['localization','lua/config','lua/social','lua/dialogue','docs/copy']:(root/d).mkdir(parents=True,exist_ok=True)
        (root/'lua/config/npcs.lua').write_text('kind = "config"\nconfig = { npcs = { probe = { friendship = true, name_key = "NPC_PROBE" } } }')
        (root/'lua/social/citizens.lua').write_text('kind = "config"\nconfig = { citizens = { probe = { archetype = "elder" } } }')
        base=[['NPC_PROBE','Prøve','Probe'],['SOC_PROBE_FIRST_1','Velkommen til min lille krog.','Welcome to my little nook.']]
        base += [[f'SOC_ARCH_ELDER_GREET_{i}',f'Hilsen {i}.',f'Greeting {i}.'] for i in range(1,4)]
        base += [[f'SOC_ARCH_ELDER_GIFT_{c}_1','Tak for tanken.','Thank you for the thought.'] for c in ['LOVE','LIKE','NEUTRAL','DISLIKE','HATE']]
        base += [['SOC_ARCH_ELDER_BDAY_1','Du kom på min fødselsdag.','You came on my birthday.']]
        write_csv(root,base)
        failures+=check('valid_fixture_clean',not copy_lint.findings(root))
        write_csv(root,base+[['SOC_EV_SKIP','Spring over','Skip scene']])
        failures+=check('event_system_key_is_not_a_citizen',not copy_lint.findings(root))
        write_csv(root,base+[['SOC_UNKNOWN_GREET_1','Hej der.','Hello there.']])
        failures+=check('unknown_citizen_still_refused',any(r['rule']=='C6' for r in copy_lint.findings(root)))
        mutants=[('stale_name','C1',['DLG_PROBE_BAD','Lyra er her.','Lyra is here.']),('long_dialogue','C2',['DLG_PROBE_LONG','a'*300,'b'*300]),('voiced_digit','C3',['SOC_PROBE_GREET_1_V','Her er 3 frø.','Here are three seeds.']),('missing_voice_index','C10',['SOC_PROBE_GREET_1_V','Godt at se dig.','Good to see you.']),('placeholder_parity','C7',['DLG_PROBE_FMT','Du fandt %s.','You found %d.']),('child_safe','C4',['DLG_PROBE_RUDE','Du er en idiot.','You are an idiot.'])]
        for name,rule,extra in mutants:
            write_csv(root,base+[extra]);out=copy_lint.findings(root)
            failures+=check(name,any(r['rule']==rule for r in out))
        write_csv(root,[r for r in base if r[0]!='SOC_PROBE_FIRST_1'])
        failures+=check('missing_first_meeting',any(r['rule']=='C6' for r in copy_lint.findings(root)))
        write_csv(root,base)
        path=root/'docs/copy/review_status.json';data=json.loads(path.read_text());data['localization/missing.csv']=dict(status='draft',rows=0);path.write_text(json.dumps(data))
        failures+=check('missing_status_csv',any(r['rule']=='C8' for r in copy_lint.findings(root)))
        # Braces/comment markers inside strings must not corrupt roster parsing.
        file=root/'lua/config/npcs.lua';file.write_text('config = { npcs = { probe = { label = "{ -- }", friendship = true } } } -- }')
        failures+=check('literal_roster_scanner',set(copy_lint.entries(file,'npcs'))=={'probe'})
    return int(failures>0)
if __name__=='__main__':raise SystemExit(main())
