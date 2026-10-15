#!/usr/bin/env python3
"""Index social voice hooks. Does not synthesize, modify or publish any audio."""
from pathlib import Path
import argparse, json, sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/copy'))
import copy_lint

def render(root=ROOT):
    rows,_=copy_lint.read_rows(root);npcs=copy_lint.entries(root/'lua/config/npcs.lua','npcs')
    lines=['-- Generated social voice hooks; recordings remain a separate, approved task.','kind = "config"','','config = {','  voiced_index = {']
    for key in sorted(k for k in rows if k.endswith('_V')):
        npc=next((n for n in sorted(npcs,key=len,reverse=True) if any(key.startswith(p+n.upper()+'_') for p in ['SOC_','GIFT_','BDAY_'])),None)
        if npc is None:raise ValueError('Unknown speaker for '+key)
        line=key.removeprefix('SOC_'+npc.upper()+'_').lower()
        lines.append(f'      {{ id = "{line}", text_key = "{key}", voice_key = "voice/{npc}/{line}" }},')
    return '\n'.join(lines+['  },','}',''])

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--check',action='store_true');a=ap.parse_args()
    path=ROOT/'lua/dialogue/_voiced_social.lua';text=render()
    if a.check:
        ok=path.exists() and path.read_text()==text;print('PASS voiced_index_in_sync' if ok else 'FAIL voiced_index_in_sync');return int(not ok)
    path.write_text(text);print('Indexed',text.count('voice_key ='),'voice hooks; no audio generated');return 0
if __name__=='__main__':raise SystemExit(main())
