#!/usr/bin/env python3
"""Danish copy checks C1-C10. Exit 0 clean, 1 findings, 2 unreadable input.

Uses the localization loader's CSV ordering, escaping and placeholder rules.
Legacy findings remain visible and become fatal under --strict. --files limits
row checks; roster, review status and voice index checks always cover the root.
"""
from pathlib import Path
import argparse, hashlib, importlib.util, json, re, sys
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('loc_csv_lint',ROOT/'tools/loc/csv_lint.py')
loc=importlib.util.module_from_spec(spec);spec.loader.exec_module(loc)
BANNED=['PongPong','Lyra','Mjau','Eventyrskoven','fes'+'by']
ONOMATOPOEIA=['hrmf','hmpf','grrr','argh']
ARCHETYPES=['child','wanderer','fairy','shopkeeper','gardener','watcher','elder','craftsman']
LEGACY_OWNERS={'DIALOGUE_':'P14','QUEST_':'P13','OBJ_':'P13'}

def entries(path, table):
    """Literal named entries, using the existing lint's comment/string scanner.

    Does not execute Lua. The brace scanner handles nested tables and braces in
    quoted strings. Only roster metadata is inspected, never executable blocks.
    """
    if not path.exists():return {}
    raw=path.read_text();clean=loc._strip_lua_noise(raw)
    m=re.search(r'\b'+re.escape(table)+r'\s*=\s*\{',clean)
    if not m:return {}
    result={};pos=m.end();depth=1
    while pos<len(clean) and depth:
        if depth==1:
            found=re.match(r'\s*,?\s*([a-zA-Z_][a-zA-Z_0-9]*)\s*=\s*\{',clean[pos:])
            if found:
                start=pos+found.end();end=start;inner=1
                while end<len(clean) and inner:
                    inner+=(clean[end]=='{')-(clean[end]=='}');end+=1
                result[found.group(1)]=raw[start:end-1];pos=end;continue
        depth+=(clean[pos]=='{')-(clean[pos]=='}');pos+=1
    return result

def field(block,key,default=''):
    m=re.search(r'\b'+key+r'\s*=\s*"([^"]*)"',block);return m.group(1) if m else default

def read_rows(root):
    effective={};all_rows=[]
    for file in loc.list_csv_files(root/'localization'):
        path=root/'localization'/file;header,rows=loc.read_csv(path)
        for line,cells in rows:
            if len(cells)!=len(header) or not cells or not loc.KEY_RX.fullmatch(cells[0]):continue
            row=dict(zip(header,cells));row.update(file='localization/'+file,line=line)
            all_rows.append(row);effective[cells[0]]=row
    return effective,all_rows

def voice_reviewed(record,row):
    """A whole-file review or an exact bilingual row review can unlock TTS.

    Row hashes deliberately cover both languages. Editing either translation
    invalidates the approval while the rest of its CSV can remain a draft.
    """
    if isinstance(record,str):return record in ('ai_reviewed','native_reviewed')
    if record.get('status') in ('ai_reviewed','native_reviewed'):return True
    approval=record.get('voice_reviews',{}).get(row.get('keys',''),{})
    return approval.get('status') in ('ai_reviewed','native_reviewed') and bool(approval.get('reviewed_by')) and all(approval.get(language+'_sha256')==hashlib.sha256(row.get(language,'').encode()).hexdigest() for language in ('da','en'))

def slot_of(key):
    if 'CHOICE' in key or re.search(r'_TOPIC_\d+$',key):return 'choice'
    if key.startswith('NPC_'):return 'name'
    if key.startswith('SHOP_') and key.endswith('_GREETING'):return 'shop'
    if key.startswith(('DLG_','DIALOGUE_','SOC_')) and not key.startswith(('SOC_SYS_','SOC_EV_','SOC_ARCH_NAME_')):return 'dialogue'
    return ''

def findings(root=ROOT,files=None):
    effective,all_rows=read_rows(root);out=[]
    limits=json.loads((ROOT/'tools/copy/font_budget.json').read_text())['slots']
    forbidden=json.loads((ROOT/'tools/copy/forbidden_words.json').read_text())
    selected={str(Path(p).resolve()) for p in files} if files else None
    def add(rule,row,msg,legacy=False):
        out.append(dict(rule=rule,file=row.get('file',''),line=row.get('line',0),key=row.get('keys',''),message=msg,legacy=legacy))
    for key,row in effective.items():
        if selected is not None and str((root/row['file']).resolve()) not in selected:continue
        legacy=row['file']=='localization/da.csv'
        for language in ('da','en'):
            text=loc.unescape_text(row.get(language,''))
            for name in BANNED:
                if re.search(r'(?i)(?<!\w)'+re.escape(name)+r'(?!\w)',text):add('C1',row,language+': stale name '+name,legacy)
            slot=slot_of(key)
            if slot and len(text)>limits[slot]['max_chars']:
                add('C2',row,f"{language}: {slot} has {len(text)} characters, limit {limits[slot]['max_chars']}",legacy)
            if key.endswith('_V') and ('%' in text or re.search(r'\d',text) or len(text.split())>14 or any(re.search(r'(?i)\b'+w+r'\b',text) for w in ONOMATOPOEIA)):
                add('C3',row,language+': voiced line needs <=14 words, no digits, percent signs or onomatopoeia',legacy)
            for word in forbidden[language]:
                if re.search(r'(?i)(?<!\w)'+re.escape(word)+r'(?!\w)',text):add('C4',row,language+': child-friendly wording required ('+word+')',legacy)
            for old,new in [('Maja','Bagerfe Rosmarin'),('Lyra','Borgmester Hyldeblomst'),('Mjau','Morfar Mis')]:
                if re.search(r'\b'+old+r'\b',text):add('C5',row,language+': use display name '+new,legacy)
        if not row.get('da') or not row.get('en') or loc.format_signature(row.get('da',''))!=loc.format_signature(row.get('en','')):
            add('C7',row,'Both languages need text and matching printf placeholders',legacy)
    # Social slots resolve in the same order as the live greeting selector.
    npcs=entries(root/'lua/config/npcs.lua','npcs');citizens=entries(root/'lua/social/citizens.lua','citizens')
    keys=set(effective)
    def pool(prefix,slot):return [k for k in keys if k.startswith(prefix+slot+'_')]
    for npc,block in npcs.items():
        if not re.search(r'\bfriendship\s*=\s*true\b',block):continue
        arch=field(citizens.get(npc,''),'archetype')
        prefixes=['SOC_'+npc.upper()+'_','SOC_ARCH_'+arch.upper()+'_','SOC_ANY_']
        def resolves(slot):return any(pool(p,slot) for p in prefixes)
        missing=[]
        if not pool(prefixes[0],'FIRST'):missing.append('FIRST')
        for taste in ['LOVE','LIKE','NEUTRAL','DISLIKE','HATE']:
            if not pool('GIFT_'+npc.upper()+'_',taste) and not resolves('GIFT_'+taste):missing.append('GIFT_'+taste)
        if not pool('BDAY_'+npc.upper()+'_','GREET') and not resolves('BDAY'):missing.append('BDAY')
        greetings=sum(len(pool(p,'GREET')) for p in prefixes)
        if missing or greetings<3:
            add('C6',{'file':'lua/config/npcs.lua','keys':npc},'Missing social cascade: '+', '.join(missing)+(f'; greetings {greetings}/3' if greetings<3 else ''))
    for key,row in effective.items():
        if key.startswith('SOC_') and not key.startswith(('SOC_SYS_','SOC_EV_','SOC_ARCH_','SOC_ANY_')):
            owner=next((npc for npc in sorted(npcs,key=len,reverse=True) if key.startswith('SOC_'+npc.upper()+'_')),None)
            if owner is None:add('C6',row,'Unknown citizen in social key')
            else:
                tail=key[len('SOC_'+owner.upper()+'_'):]
                if not re.fullmatch(r'(FIRST|GREET|CHAT|TOPIC|TOPIC_ANSWER|BARK|BIO)(_[A-Z0-9]+)*_\d+(_V)?',tail):
                    add('C6',row,'Invalid social slot or numbered variant')
    status_path=root/'docs/copy/review_status.json'
    status=json.loads(status_path.read_text()) if status_path.exists() else {}
    actual={'localization/'+p for p in loc.list_csv_files(root/'localization')}
    for file in sorted(actual|set(status)):
        row={'file':'docs/copy/review_status.json','keys':file};record=status.get(file,{})
        if file not in actual:add('C8',row,'Review status names a missing CSV');continue
        count=sum(1 for r in all_rows if r['file']==file)
        if record.get('status') not in ['draft','ai_reviewed','native_reviewed'] or record.get('rows')!=count:
            add('C8',row,'Missing/invalid review state or stale row count')
        if record.get('status')=='native_reviewed' and not record.get('reviewed_by'):add('C8',row,'Native review needs the user reviewer')
        if record.get('voice_frozen') and record.get('status')=='draft':add('C8',row,'Draft copy cannot be voice-frozen')
        for key,approval in record.get('voice_reviews',{}).items():
            reviewed=effective.get(key,{})
            valid=key.endswith('_V') and reviewed.get('file')==file and approval.get('status') in ('ai_reviewed','native_reviewed') and bool(approval.get('reviewed_by')) and all(approval.get(language+'_sha256')==hashlib.sha256(reviewed.get(language,'').encode()).hexdigest() for language in ('da','en'))
            if not valid:add('C8',{'file':file,'keys':key},'Stale, misplaced or incomplete voice-row review')
    seen={}
    for key,row in effective.items():
        if key.endswith('_V') or key.startswith('SOC_'):
            m=next((n for n in npcs if key.startswith('SOC_'+n.upper()+'_')),None)
            if m:
                normal=re.sub(r'\W+',' ',row.get('da','').lower()).strip();pair=(m,normal)
                if pair in seen:add('C9',row,'Duplicate citizen line: '+seen[pair])
                seen[pair]=key
    index=root/'lua/dialogue/_voiced_social.lua'
    indexed=set(re.findall(r'text_key\s*=\s*"([A-Z0-9_]+_V)"',index.read_text())) if index.exists() else set()
    voiced={k for k in keys if k.endswith('_V')}
    for key in sorted(voiced^indexed):add('C10',effective.get(key,{'keys':key,'file':'lua/dialogue/_voiced_social.lua'}),'Voiced row and index block must both exist')
    return out

def main(argv=None):
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--root',type=Path,default=ROOT);ap.add_argument('--files',nargs='+');ap.add_argument('--json',action='store_true');ap.add_argument('--strict',action='store_true');a=ap.parse_args(argv)
    try:out=findings(a.root.resolve(),a.files)
    except (OSError,ValueError,TypeError,KeyError) as e:print(str(e),file=sys.stderr);return 2
    if a.json:print(json.dumps(out,ensure_ascii=False))
    else:
        for f in out:print(f"{f['rule']} {'LEGACY ' if f['legacy'] else ''}{f['file']}:{f['line']} {f['key']}: {f['message']}")
        print(f'copy_lint: {len(out)} findings')
    return int(any(a.strict or not f['legacy'] for f in out))
if __name__=='__main__':raise SystemExit(main())
