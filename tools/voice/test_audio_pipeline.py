#!/usr/bin/env python3
"""Independent duration, waveform, source-preservation and idempotency checks."""
import array,hashlib,json,math,subprocess,tempfile,unittest
from pathlib import Path
import generate_voice as voice
import synth_common as synth
ROOT=voice.ROOT
class AudioPipeline(unittest.TestCase):
    def test_pitch_preserves_duration(self):
        for pitch in [.74,1.0,1.32]:
            cmd=['ffmpeg','-v','error','-f','lavfi','-i','sine=frequency=440:sample_rate=22050:duration=2','-af',voice.pitch_filter(pitch,1.0),'-ac','1','-ar','22050','-f','s16le','-']
            pcm=subprocess.run(cmd,check=True,stdout=subprocess.PIPE).stdout
            self.assertAlmostEqual(len(pcm)/2/22050,2,delta=.04)
    def test_citizen_jitter_stable_and_bounded(self):
        values,pace,_=voice.presets()
        citizens=voice.copy_lint.entries(ROOT/'lua/social/citizens.lua','citizens')
        self.assertEqual(set(values),set(voice.copy_lint.ARCHETYPES))
        self.assertEqual(pace,.88)
        for npc,block in citizens.items():
            role=voice.copy_lint.field(block,'archetype');preset=values[role];p=voice.params(npc,'Sara')
            self.assertEqual(p,voice.params(npc,'Sara'))
            self.assertLessEqual(abs(p['pitch']/preset['pitch']-1),.04001)
            self.assertLessEqual(abs(p['rate']/preset['rate']-1),.03001)
    def test_all_masters_preserved(self):
        rows=json.loads((voice.BASE/'_user_recordings_v0/mapping.json').read_text())
        self.assertEqual(len(rows),14);self.assertEqual(sum(r['active'] for r in rows),11)
        for row in rows:self.assertEqual((ROOT/row['source']).read_bytes(),(voice.BASE/'_user_recordings_v0'/Path(row['source']).name).read_bytes())
    def test_generator_idempotent_and_protects_humans(self):
        files=list(voice.BASE.rglob('*.ogg'));before={p:(p.stat().st_mtime_ns,hashlib.sha256(p.read_bytes()).hexdigest()) for p in files}
        subprocess.run(['python3','-B',str(ROOT/'tools/voice/generate_voice.py')],check=True,stdout=subprocess.PIPE)
        self.assertEqual(before,{p:(p.stat().st_mtime_ns,hashlib.sha256(p.read_bytes()).hexdigest()) for p in files})
        self.assertFalse(list(voice.BASE.rglob('*.aiff')))
    def test_synth_pcm_reproducible(self):
        self.assertEqual(synth.synth('sfx','step_wood_1'),synth.synth('sfx','step_wood_1'))
        self.assertNotEqual(synth.synth('sfx','step_wood_1'),synth.synth('sfx','step_wood_2'))
    def test_waveforms_non_silent_unclipped_and_loop_seams(self):
        evidence=[]
        for kind in ['sfx','amb','music']:
            manifest=json.loads((ROOT/'assets/audio'/kind/'synth-manifest.json').read_text())
            for name,entry in manifest['files'].items():
                path=ROOT/'assets/audio'/kind/(name+'.ogg')
                decoded=subprocess.run(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ac','1','-ar','22050','-'],check=True,stdout=subprocess.PIPE).stdout
                pcm=array.array('f');pcm.frombytes(decoded)
                peak=max(abs(x) for x in pcm);rms=math.sqrt(sum(x*x for x in pcm)/len(pcm));seam=abs(pcm[-1]-pcm[0])
                self.assertGreater(rms,.00003,name);self.assertLess(peak,.8,name)
                self.assertAlmostEqual(len(pcm)/22050,entry['seconds'],delta=.03)
                if kind in ['amb','music']:self.assertLess(seam,.025,name)
                evidence.append(dict(kind=kind,id=name,seconds=len(pcm)/22050,peak=peak,rms=rms,seam_delta=seam))
        manifest=json.loads((voice.BASE/'manifest.json').read_text())
        for key,row in manifest['lines'].items():
            if row['kind']=='missing':continue
            path=ROOT/'assets/audio'/(key+'.ogg')
            decoded=subprocess.run(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ac','1','-ar','22050','-'],check=True,stdout=subprocess.PIPE).stdout
            pcm=array.array('f');pcm.frombytes(decoded)
            peak=max(abs(x) for x in pcm);rms=math.sqrt(sum(x*x for x in pcm)/len(pcm))
            self.assertGreater(rms,.0001,key);self.assertLess(peak,1.001,key)
            self.assertGreater(len(pcm)/22050,.3,key);self.assertLess(len(pcm)/22050,45,key)
            evidence.append(dict(kind='voice',id=key,source=row['kind'],seconds=len(pcm)/22050,peak=peak,rms=rms))
        out=ROOT/'docs/qa/mechanics/audio';out.mkdir(parents=True,exist_ok=True)
        (out/'waveforms.json').write_text(json.dumps({'method':'ffmpeg decoded mono 22050 Hz float samples; numeric analysis, not a listening review','files':evidence},indent=2)+'\n')
if __name__=='__main__':unittest.main()
