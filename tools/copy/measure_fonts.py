#!/usr/bin/env python3
"""Measure the shipped typefaces. Run with tools/art/.venv/bin/python."""
from pathlib import Path
import argparse, hashlib, json
from PIL import ImageFont
ROOT = Path(__file__).resolve().parents[2]
SAMPLE = 'Du må gerne komme indenfor. Her dufter af træ og varme boller. Æblegrød, hygge, blåbær og små spirer.'
SLOTS = {
    'dialogue': ('AlegreyaSans-Medium.ttf', 20, 670, 3, 240),
    'shop': ('AlegreyaSans-Medium.ttf', 19, 304, 3, 110),
    'choice': ('AlegreyaSans-Bold.ttf', 18, 233, 1, 32),
    'name': ('Caprasimo-Regular.ttf', 20, 272, 1, 26),
    'button': ('Caprasimo-Regular.ttf', 22, 180, 1, 10),
}
def measure(root=ROOT):
    out = {'sample': SAMPLE, 'slots': {}}
    for slot, (file, size, width, lines, chars) in SLOTS.items():
        path = root / 'assets/fonts' / file
        font = ImageFont.truetype(str(path), size)
        average = font.getlength(SAMPLE) / len(SAMPLE)
        out['slots'][slot] = dict(font=file, font_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), size=size,
                                  width_px=width, lines=lines, max_chars=chars, average_char_px=round(average, 4),
                                  chars_per_line=int(width / average), sample_px=round(font.getlength(SAMPLE), 4))
    return out

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--check',action='store_true');a=ap.parse_args()
    path=Path(__file__).with_name('font_budget.json');actual=measure()
    if a.check:
        saved=json.loads(path.read_text());ok=saved['sample']==actual['sample'] and saved['slots'].keys()==actual['slots'].keys()
        for key,row in actual['slots'].items():
            old=saved['slots'].get(key,{})
            ok=ok and all(old.get(k)==row[k] for k in ('font','font_sha256','size','width_px','lines','max_chars')) and abs(old.get('sample_px',0)-row['sample_px'])<=2
        print('PASS font_budget_matches_fonts' if ok else 'FAIL font_budget_matches_fonts');return int(not ok)
    path.write_text(json.dumps(actual,ensure_ascii=False,indent=2)+'\n');print(path.relative_to(ROOT));return 0
if __name__=='__main__':raise SystemExit(main())
