#!/usr/bin/env python3
"""CORE copy and frozen voice text audit. Never generates or approves audio."""
import hashlib
import json
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
    missing = sorted(k for k in hooks if k not in pins)
    checks['draft_voice_hooks_are_unrecorded'] = all(not status[rows[k]['file']]['voice_frozen'] for k in missing)
    return {'checks': checks, 'frozen_texts': len(pins), 'unrecorded_hooks': missing, 'legacy_findings': len([f for f in findings if f.get('legacy')]), 'note': 'New copy remains draft; no new recording or native-language approval is asserted.'}

if __name__=='__main__':
    result = audit()
    print(json.dumps(result, ensure_ascii=False))
    raise SystemExit(not all(result['checks'].values()))
