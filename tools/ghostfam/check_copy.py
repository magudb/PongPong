#!/usr/bin/env python3
"""Family copy contracts: tone, ungendered cousin/child, barks and literal keys."""
import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STEMS = {'da': ['skræm', 'bange', 'uhyggelig', 'frygt', 'gyser', 'forskrække', 'rædsel'],
         'en': ['scare', 'frighten', 'afraid', 'creepy', 'terrif', 'horror', 'spooky']}

def main():
    with (ROOT / 'localization/ghostfamily.csv').open() as file:
        rows = [row for row in csv.DictReader(file) if re.fullmatch('[A-Z0-9_]+', row.get('keys', ''))]
    errors = []
    for row in rows:
        key = row['keys']
        for lang in ['da', 'en']:
            text = row[lang]
            if any(stem in text.lower() for stem in STEMS[lang]):
                errors.append(key + ': tone (' + lang + ')')
            if '_BARK_' in key and not 3 <= len(text.split()) <= 5:
                errors.append(key + ': bark outside 3–5 words (' + lang + ')')
            gender = r'\b(fætter|kusine|søn|datter|dreng|pige)\b' if lang == 'da' else r'\b(son|daughter|boy|girl)\b'
            if '_KIN_' in key and re.search(gender, text, re.I):
                errors.append(key + ': gendered hero relation (' + lang + ')')
            pronoun = r'\b(han|hun|ham|hende)\b' if lang == 'da' else r'\b(he|she|him|her|his)\b'
            if '_BLUND_' in key and re.search(pronoun, text, re.I):
                errors.append(key + ': gendered child (' + lang + ')')
            if key == 'GHOSTFAM_KIN_STORY' and len(text) > 200:
                errors.append(key + ': story popup exceeds 200 characters (' + lang + ')')
    keys = set()
    for file in (ROOT / 'localization').glob('*.csv'):
        with file.open() as source:
            keys.update(row[0] for row in csv.reader(source) if row)
    for file in (ROOT / 'lua/dialogue').glob('ghostfam_*.lua'):
        for key in re.findall(r'(?:text_key|info_key|speaker_name_key)\s*=\s*"([^"]+)"', file.read_text()):
            if key not in keys:
                errors.append(file.name + ': missing ' + key)
    for error in errors:
        print('FAIL ' + error)
    print(f'Family copy: {len(rows)} rows, {len(errors)} problems; no tone allow-list')
    return bool(errors)

if __name__ == '__main__':
    raise SystemExit(main())
