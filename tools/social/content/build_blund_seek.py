#!/usr/bin/env python3
"""Keep Blund's optional seek branch inside the literal-table Lua subset."""
from pathlib import Path
import argparse
ROOT=Path(__file__).resolve().parents[3]
START='  -- GF-seek: generated found/gift branches (build_blund_seek.py).\n'
END='  -- GF-seek end.\n'
def page(keys):
    lines=', '.join('{ text_key = "'+key+'" }' for key in keys)
    return '    return { speaker = "ghostfam_blund", speaker_name_key = "NPC_GHOSTFAM_BLUND",\n      lines = { '+lines+' },\n      choices = { { id = "goodbye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" } } }\n'
def build():
    block=START+'  local found_now = context.ghostfam_seek_found_now or 0\n  local gift_now = context.ghostfam_seek_gift_now or 0\n  if found_now > 0 or gift_now > 0 then\n    api.set_flag("ghostfam_seek_found_now", 0)\n    api.set_flag("ghostfam_seek_gift_now", 0)\n  end\n'
    for i in [1,2,3,4,5,14,15]:
        key='SEEK_GHOSTFAM_GIFT_'+str(i if i<10 else i-10)+('_OWNED' if i>10 else '')
        block+=f'  if gift_now == {i} then\n'+page(['SEEK_GHOSTFAM_FOUND_1',key])+'  end\n'
    for condition,key in [('found_now > 0 and context.talked_today','SEEK_GHOSTFAM_FOUND_4'),('found_now > 0 and race == "ghost"','SEEK_GHOSTFAM_FOUND_3'),('found_now == 2','SEEK_GHOSTFAM_FOUND_2'),('found_now > 0','SEEK_GHOSTFAM_FOUND_1'),('context.ghostfam_seek_again','SEEK_GHOSTFAM_FOUND_AGAIN_1')]:
        block+='  if '+condition+' then\n'+page([key])+'  end\n'
    return block+END

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
    path=ROOT/'lua/dialogue/ghostfam_blund.lua';source=path.read_text()
    if START not in source:raise SystemExit('missing generated seek markers')
    a=source.index(START);b=source.index(END,a)+len(END)
    desired=source[:a]+build()+source[b:]
    if args.check:
        if source!=desired:raise SystemExit('stale Blund seek branches')
    else:path.write_text(desired)
    print('Blund seek branches '+('verified' if args.check else 'exported'))
if __name__=='__main__':main()
