#!/usr/bin/env python3
"""CORE copy and frozen voice text audit. Never generates or approves audio."""
import hashlib
import json
import re
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools/copy'))
import copy_lint
sys.path.insert(0, str(ROOT/'tools/loc'))
import csv_lint

def audit():
    rows, _ = copy_lint.read_rows(ROOT)
    findings = copy_lint.findings(ROOT)
    checks = {'lint_clean_core': not any(not f.get('legacy') for f in findings)}
    core = [v for v in rows.values() if v['file'] != 'localization/da.csv']
    checks['no_raw_keys_both_locales'] = all(v.get(lang) and v[lang] != v['keys'] for v in core for lang in ['da','en'])
    checks['boxes_fit'] = not any(f['rule']=='C2' and not f.get('legacy') for f in findings)
    pins = json.loads((ROOT/'tests/checkpoints/town/voice_frozen.json').read_text())['lines']
    checks['frozen_voice_text_hashes'] = len(pins)==11 and all(hashlib.sha256(rows[k]['da'].encode()).hexdigest()==p['da_sha256'] for k,p in pins.items())
    checks['citizen_slots_complete'] = not any(f['rule']=='C6' for f in findings)
    status = json.loads((ROOT/'docs/copy/review_status.json').read_text())
    hooks = csv_lint.voiced_keys(str(ROOT))
    checks['social_voice_rows_reviewed'] = all(copy_lint.voice_reviewed(status.get(rows[k]['file'],{}),rows[k]) for k in hooks if k.endswith('_V'))
    manifest = json.loads((ROOT/'assets/audio/voice/manifest.json').read_text())['lines']
    missing = set()
    valid_hashes = True
    for source in (ROOT/'lua/dialogue').glob('*.lua'):
        for block in re.findall(r'\{[^{}]*\}',source.read_text()):
            key = re.search(r'text_key\s*=\s*"([A-Z0-9_]+)"',block)
            voice = re.search(r'voice_key\s*=\s*"([^"]+)"',block)
            if not key or not voice: continue
            entry = manifest.get(voice[1],{})
            audio = ROOT/'assets/audio'/(voice[1]+'.ogg')
            if entry.get('kind') not in ('recorded','placeholder') or not audio.exists():
                missing.add(key[1]);continue
            expected = hashlib.sha256(copy_lint.loc.unescape_text(rows[key[1]]['da']).encode()).hexdigest()
            valid_hashes = valid_hashes and entry.get('text_sha256')==expected and entry.get('audio_sha256')==hashlib.sha256(audio.read_bytes()).hexdigest()
    checks['voice_assets_complete'] = not missing
    checks['voice_text_and_audio_hashes'] = valid_hashes
    return {'checks': checks, 'frozen_texts': len(pins), 'unrecorded_hooks': sorted(missing), 'legacy_findings': len([f for f in findings if f.get('legacy')]), 'note': 'Human text/audio remains protected. New social voice rows have exact bilingual AI reviews; synthetic placeholders retain provenance. Native-language/listening approval is not asserted.'}


if __name__=='__main__':
    result = audit()
    print(json.dumps(result, ensure_ascii=False))
    raise SystemExit(not all(result['checks'].values()))
