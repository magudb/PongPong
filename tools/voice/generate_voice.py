#!/usr/bin/env python3
"""Local macOS Sara placeholders; human recordings always win. No network calls."""
from pathlib import Path
import argparse,concurrent.futures,hashlib,json,re,shutil,subprocess,sys,tempfile
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/copy'))
import copy_lint
BASE=ROOT/'assets/audio/voice'
HUMAN=['mayor_lyra/greet_1','mayor_lyra/greet_2','mayor_lyra/lottery','mayor_lyra/hello','mayor_lyra/farm_status','baker_maja/greet','baker_maja/roof_trouble','baker_maja/thanks','baker_maja/cookie_talk','fairy_lily/greet','fairy_lily/cat_missing','fairy_lily/worried','smith_thorin/greet','smith_thorin/mining_talk']
FROZEN={
'mayor_lyra/greet_2':'Feernes Konge har udvalgt dig i det årlige lotteri!',
'mayor_lyra/lottery':'Du har vundet en fortryllet trækronsgård! Den venter på dig i skovens kroner.',
'mayor_lyra/hello':'Godt at se dig igen!', 'mayor_lyra/farm_status':'Din gård trives! Fortsæt det gode arbejde.',
'baker_maja/greet':'Hej der! Velkommen til mit lille bageri.',
'baker_maja/roof_trouble':'Åh nej, stormen i går beskadigede mit tag! Kan du hjælpe mig?',
'baker_maja/thanks':'Tak for hjælpen! Taget er som nyt igen.',
'baker_maja/cookie_talk':'Jeg bager de bedste småkager i hele den magiske by.',
'fairy_lily/greet':'Hej... vil du lege?', 'smith_thorin/greet':'Hrmf. Velkommen til smedjen.',
'smith_thorin/mining_talk':'Den mørke skov er fuld af sjældne malmsten... men også farer.'}
VERSION=1

def sha(data):return hashlib.sha256(data).hexdigest()
def fnv(text):
    value=2166136261
    for byte in text.encode():value=((value^byte)*16777619)&0xffffffff
    return value

def lines():
    rows,_=copy_lint.read_rows(ROOT);result={}
    for source in sorted((ROOT/'lua/dialogue').glob('*.lua')):
        for block in re.findall(r'\{[^{}]*\}',source.read_text()):
            key=re.search(r'text_key\s*=\s*"([^"]+)"',block);voice=re.search(r'voice_key\s*=\s*"([^"]+)"',block)
            if not key or not voice:continue
            k,v=key[1],voice[1]
            assert re.fullmatch(r'voice/[a-z0-9_]+/[a-z0-9_]+',v),v
            assert k in rows and rows[k]['da'],('Missing Danish text',k)
            text=copy_lint.loc.unescape_text(rows[k]['da'])
            row={'text_key':k,'text':text,'text_sha256':sha(text.encode()),'source':str(source.relative_to(ROOT))}
            assert v not in result or result[v]['text']==text,('Conflicting voice hook',v)
            result[v]=row
    return result

def presets():
    raw=(ROOT/'lua/config/voice_presets.lua').read_text();blocks=copy_lint.entries(ROOT/'lua/config/voice_presets.lua','archetypes')
    values={name:{key:float(re.search(r'\b'+key+r'\s*=\s*([\d.]+)',b)[1]) for key in ['pitch','rate']} for name,b in blocks.items()}
    pace=float(re.search(r'pace\s*=\s*([\d.]+)',raw)[1])
    respell=dict(re.findall(r'\[\s*"([^"]+)"\s*\]\s*=\s*"([^"]+)"',raw))
    return values,pace,respell

def params(npc,voice):
    citizens=copy_lint.entries(ROOT/'lua/social/citizens.lua','citizens');roster=copy_lint.entries(ROOT/'lua/config/npcs.lua','npcs');values,pace,respell=presets()
    role=copy_lint.field(citizens.get(npc,''),'archetype','')
    if role in values:p=values[role].copy()
    else:
        b=roster.get(npc,'');v=re.search(r'voice\s*=\s*\{([^}]+)\}',b)
        p={k:float(m[1]) if (m:=re.search(k+r'\s*=\s*([\d.]+)',v[1] if v else '')) else 1.0 for k in ['pitch','rate']}
    h=fnv(npc);p['pitch']*=1+((h&0xffff)/65535*2-1)*.04;p['rate']*=1+(((h>>16)&0xffff)/65535*2-1)*.03
    return dict(voice=voice,pitch=round(p['pitch'],6),rate=round(p['rate'],6),pace=pace,respell=respell,version=VERSION)

def pitch_filter(pitch,pace):return f'asetrate=22050*{pitch:.6f},aresample=44100,atempo={1/pitch:.8f},atempo={pace:.6f}'
def recorded():
    path=BASE/'RECORDED.txt'
    return {s.strip().removesuffix('.ogg') for s in path.read_text().splitlines() if s.strip() and not s.startswith('#')} if path.exists() else set()

def install_recordings(hooks):
    files=sorted((ROOT/'docs/audio').glob('*.mp3'));assert len(files)==14
    archive=BASE/'_user_recordings_v0';archive.mkdir(parents=True,exist_ok=True)
    (archive/'.gdignore').write_text('')
    mapping=[]
    for i,(source,slot) in enumerate(zip(files,HUMAN)):
        target=archive/source.name
        if target.exists():assert target.read_bytes()==source.read_bytes(),('Archived original differs',source)
        else:shutil.copyfile(source,target)
        active=slot in FROZEN;mapping.append(dict(index=i+1,source=str(source.relative_to(ROOT)),sha256=sha(source.read_bytes()),voice_key='voice/'+slot,active=active))
        if not active:continue
        key='voice/'+slot;assert hooks[key]['text']==FROZEN[slot],('Frozen human line changed',key,hooks[key]['text'])
        output=BASE/(slot+'.ogg');output.parent.mkdir(parents=True,exist_ok=True)
        # Never overwrite an installed human file. Removing it is an explicit re-conversion.
        if not output.exists():subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-ac','1','-ar','44100','-c:a','libvorbis','-q:a','4',str(output)],check=True)
    (archive/'README.md').write_text('# Original user recordings\n\nAll fourteen MP3s are byte-identical to docs/audio. Sorted mapping follows PLAN_2D R.5, based on its documented Danish ASR/duration investigation. Eleven current lines are converted without text or pitch edits; recordings 1, 11 and 12 retain retired names and stay archived. This implementation does not claim a fresh human listening review. See mapping.json.\n')
    (archive/'mapping.json').write_text(json.dumps(mapping,indent=2)+'\n')
    merged=recorded()|{'voice/'+slot for slot in FROZEN}
    (BASE/'RECORDED.txt').write_text('# Human recordings; never synthesize or overwrite these paths.\n'+'\n'.join(sorted(merged))+'\n')

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    for flag in ['check','dry-run','only-index','install-recordings']:ap.add_argument('--'+flag,action='store_true')
    ap.add_argument('--only');ap.add_argument('--voice',default='Sara');ap.add_argument('--workers',type=int,default=4)
    a=ap.parse_args();hooks=lines();effective_rows=copy_lint.read_rows(ROOT)[0];BASE.mkdir(parents=True,exist_ok=True)
    if a.install_recordings:install_recordings(hooks)
    real=recorded();path=BASE/'manifest.json';manifest=json.loads(path.read_text()) if path.exists() else {'lines':{}}
    selected={v:r for v,r in hooks.items() if (not a.only or v.split('/')[1]==a.only) and (not a.only_index or r['source'].endswith('_voiced_social.lua'))}
    review=json.loads((ROOT/'docs/copy/review_status.json').read_text())
    def job(pair):
        v,row=pair;target=ROOT/'assets/audio'/(v+'.ogg');entry=manifest['lines'].get(v,{})
        if v in real:
            assert target.is_file(),('Missing protected human recording',v)
            assert row['text']==FROZEN.get(v.removeprefix('voice/'),row['text']),('Frozen text changed',v)
            if a.check:assert entry.get('audio_sha256')==sha(target.read_bytes()),('Protected recording changed',v)
            return v,dict(row,kind='recorded',audio_sha256=sha(target.read_bytes()))
        p=params(v.split('/')[1],a.voice);fingerprint=sha(json.dumps(dict(text=row['text'],params=p),sort_keys=True).encode())
        valid=entry.get('fingerprint')==fingerprint and target.exists() and entry.get('audio_sha256')==sha(target.read_bytes())
        # CSV-selected social copy must complete the copy pass before the bulk bake.
        csv=effective_rows[row['text_key']]['file'].removeprefix('localization/')
        status=review.get('localization/'+csv,{})
        if row['text_key'].endswith('_V') and not copy_lint.voice_reviewed(status,effective_rows[row['text_key']]):
            if a.check:assert entry.get('kind')=='missing' and entry.get('text_sha256')==row['text_sha256'],('Stale deferred copy',v)
            return v,dict(row,kind='missing',reason='draft social copy; bake after copy review')
        if a.check:
            assert valid,('Stale or absent generated line',v)
            return v,entry
        if a.dry_run:return v,dict(row,kind='planned',params=p,regenerate=not valid)
        if valid:return v,entry
        target.parent.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='traetoppen-voice-') as tmp:
            source=Path(tmp)/'line.aiff';output=Path(tmp)/'line.ogg'
            spoken=row['text']
            for word,pronunciation in p['respell'].items():spoken=re.sub(r'(?<!\w)'+re.escape(word)+r'(?!\w)',lambda _m:pronunciation,spoken)
            subprocess.run(['say','-v',p['voice'],'-r',str(round(175*p['rate'])),'--data-format=BEI16@22050','-o',str(source),spoken],check=True)
            subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-af',pitch_filter(p['pitch'],p['pace']),'-ac','1','-ar','22050','-c:a','libvorbis','-q:a','2',str(output)],check=True)
            pending=target.with_suffix('.ogg.tmp');pending.write_bytes(output.read_bytes());pending.replace(target)
        print('generated',v,flush=True)
        return v,dict(row,kind='placeholder',params=p,fingerprint=fingerprint,audio_sha256=sha(target.read_bytes()))
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1,min(8,a.workers))) as pool:entries=dict(pool.map(job,selected.items()))
    if a.dry_run:print(json.dumps(entries,indent=2,ensure_ascii=False));return
    if a.check:
        assert set(manifest['lines'])==set(hooks),'Voice hooks and manifest differ'
        for v,row in hooks.items():assert manifest['lines'][v]['text_sha256']==row['text_sha256'],v
        print('PASS manifest_in_sync',len(selected),'lines');return
    manifest['lines'].update(entries)
    manifest['lines']={v:manifest['lines'][v] for v in sorted(hooks) if v in manifest['lines']}
    manifest.update(format=1,status='Human originals preserved; local Sara/synth placeholders; no native listening approval',missing={v:e.get('reason') for v,e in manifest['lines'].items() if e['kind']=='missing'})
    path.write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')
    print('Indexed',len(manifest['lines']),'lines;',len(manifest['missing']),'deferred;',sum(p.stat().st_size for p in BASE.rglob('*.ogg')),'bytes')
if __name__=='__main__':main()
