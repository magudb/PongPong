"""Deterministic quiet placeholder audio. No recordings or network models used."""
from pathlib import Path
import argparse,array,hashlib,json,math,random,subprocess,tempfile,wave
ROOT=Path(__file__).resolve().parents[2]
RATE=22050
TAU=math.tau
VERSION=2
TOWN='shop_bell door_open_wood door_locked_knock coin_clink heart_up gift_sparkle letter_rustle page_turn bath_splash town_bell festival_horn closing_bell bin_bell stage_up'.split()
DUNGEON='pickup_soft loot_rare loot_unique loot_legendary chest_open rune_activate hulen_descend telegraph_tick enemy_notice hit_soft hurt_soft bush_rustle lantern_low appraisal_reveal gem_set weapon_equip'.split()
SFX=[f'step_{s}_{i}' for s,n in [('grass',3),('dirt',3),('wood',3),('stone',3),('rope',2)] for i in range(1,n+1)]+TOWN+DUNGEON
AMBIENCE='farm_day farm_night town_day town_night shop_interior forest forest_night cave_drip rain'.split()
MUSIC='farm_theme city_theme forest_theme festival_foraar festival_sommer festival_efteraar festival_vinter dungeon_act1 dungeon_act2 dungeon_act3 dungeon_act4 boss boss_final rune_rest'.split()

def seed(name):return int.from_bytes(hashlib.sha256(name.encode()).digest()[:8],'little')
def tone(t,hz):return math.sin(TAU*hz*t)+.22*math.sin(TAU*hz*2*t)
def synth(kind,name):
    rng=random.Random(seed(name));duration=.22 if name.startswith('step_') else .8
    if kind=='amb':duration=25
    if kind=='music':duration=48
    n=int(RATE*duration);out=array.array('h');smooth=0.;scale=.13 if kind=='sfx' else .055
    base=110*2**((seed(name)%12)/12)
    noise_cues=['rustle','turn','splash','crack','open','knock','hurt','slash','dodge','impact']
    noisy=any(s in name for s in noise_cues) or name.startswith('step_')
    if name.startswith('step_'):base={'grass':125,'dirt':95,'wood':180,'stone':420,'rope':145}[name.split('_')[1]]*(.95+rng.random()*.1)
    for i in range(n):
        t=i/RATE
        if kind=='sfx':
            attack=min(1,t/.006);env=attack*math.exp(-t/(.045 if name.startswith('step_') else .17))
            smooth=.72*smooth+.28*rng.uniform(-1,1)
            v=(smooth*2+.25*tone(t,base)) if noisy else (tone(t,base*3)+.5*tone(t,base*3*1.5)+.25*tone(t,base*6))
            value=v*env*min(1,(duration-t)/.025)
        elif kind=='amb':
            smooth=.985*smooth+.015*rng.uniform(-1,1)
            # Wind/room air plus sparse, low-volume periodic chirps; no voices.
            pulse=max(0,math.sin(TAU*t/6))**18
            value=smooth*3+.09*pulse*math.sin(TAU*(1400 if 'night' in name else 2100)*t)
            if name=='rain':value=smooth*5+.12*rng.uniform(-1,1)
            if name=='shop_interior':value*=.25
            if name=='cave_drip':value=smooth*.4+.12*max(0,math.sin(TAU*t/8))**60*math.sin(TAU*600*t)
        else:
            # Original sparse pentatonic placeholder, 16 three-second bars.
            step=int(t/1.5);local=t%1.5;notes=[0,7,12,14,9,7,4,2]
            hz=base*2**(notes[(step+seed(name)%8)%8]/12)
            env=min(1,local/.04)*math.exp(-local/0.48)*min(1,(1.5-local)/.08)
            value=tone(t,hz)*env+.18*math.sin(TAU*base*t)*math.sin(math.pi*(t%6)/6)**2
        value=max(-.95,min(.95,value*scale));out.append(round(value*32767))
    if kind in ['amb','music']:
        # Circular one-second overlap removes the discontinuity, never paints silence.
        overlap=RATE
        for i in range(overlap):
            f=i/overlap;out[i]=round(out[n-overlap+i]*(1-f)+out[i]*f)
        del out[-overlap:]
    return out

def main(kind):
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');p.add_argument('--only');a=p.parse_args()
    names={'sfx':SFX,'amb':AMBIENCE,'music':MUSIC}[kind];base=ROOT/'assets/audio'/kind;base.mkdir(parents=True,exist_ok=True)
    manifest=base/'synth-manifest.json';old=json.loads(manifest.read_text()) if manifest.exists() else {}
    recipes={name:{'version':3 if kind=='amb' else VERSION,'seed':seed(name),'kind':kind} for name in names}
    if a.check:
        assert old.get('recipes')==recipes,'Recipes changed; regenerate'
        for name,entry in old['files'].items():assert (base/(name+'.ogg')).is_file() and hashlib.sha256((base/(name+'.ogg')).read_bytes()).hexdigest()==entry['sha256'],name
        assert set(old['files'])==set(names),'Missing recipe exports'
        print('PASS',kind,len(names),'placeholder recipes');return
    files={name:entry for name,entry in old.get('files',{}).items() if name in names}
    for name in names:
        if a.only and name!=a.only:continue
        target=base/(name+'.ogg');recipe=recipes[name]
        if old.get('recipes',{}).get(name)==recipe and target.exists() and files.get(name,{}).get('sha256')==hashlib.sha256(target.read_bytes()).hexdigest():continue
        pcm=synth(kind,name)
        with tempfile.TemporaryDirectory(prefix='traetoppen-synth-') as tmp:
            wav=Path(tmp)/'sample.wav';ogg=Path(tmp)/'sample.ogg'
            with wave.open(str(wav),'wb') as w:w.setparams((1,2,RATE,len(pcm),'NONE','not compressed'));w.writeframes(pcm.tobytes())
            subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-ac','1','-ar',str(RATE),'-c:a','libvorbis','-q:a','2',str(ogg)],check=True)
            pending=target.with_suffix('.ogg.tmp');pending.write_bytes(ogg.read_bytes());pending.replace(target)
        files[name]={'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'seconds':len(pcm)/RATE,'bytes':target.stat().st_size,'sample_rate':RATE,'channels':1,'pcm_sha256':hashlib.sha256(pcm.tobytes()).hexdigest()}
        print(kind,name,files[name]['bytes'],flush=True)
    manifest.write_text(json.dumps({'status':'synthesized placeholder','recipes':recipes,'files':dict(sorted(files.items()))},indent=2)+'\n')
