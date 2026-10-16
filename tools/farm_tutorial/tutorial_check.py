#!/usr/bin/env python3
"""Check the installed first-morning Lua/CSV references and mutation controls."""
from __future__ import annotations
import argparse
import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def check(root: Path, replacements: dict[str, str] | None = None) -> list[str]:
    replacements = replacements or {}
    def read(path: str) -> str:
        return replacements.get(path, (root / path).read_text())
    issues = []
    keys = set()
    for path in (root / 'localization').glob('*.csv'):
        for row in csv.reader(path.open()):
            if row and re.fullmatch(r'[A-Z][A-Z0-9_]+', row[0]):
                keys.add(row[0])
    for row in csv.DictReader(read('localization/farm_tutorial.csv').splitlines()):
        key = row['keys']
        limit = 90 if key.startswith('TUT_') else 32 if 'CHOICE' in key else 160
        if key.endswith('_TITLE'):
            limit = 28
        for locale in ['da', 'en']:
            text = row[locale]
            if not text or len(text) > limit:
                issues.append(f'{key}/{locale}: empty or >{limit} characters')
        if re.findall(r'%[sd]', row['da']) != re.findall(r'%[sd]', row['en']):
            issues.append(f'{key}: placeholder mismatch')
    tutorial = read('lua/farm/farm_tutorial.lua')
    farm = read('data/maps/farm.map')
    npcs = read('lua/config/npcs.lua')
    lua_sources = [tutorial, read('lua/farm/farm_intro_pip.lua'), read('lua/farm/farm_intro_pip_bye.lua'), read('lua/quests/forste_dage.lua')]
    for source in lua_sources:
        for key in re.findall(r'(?:text_key|description_key|speaker_name_key|\bkey)\s*=\s*"([A-Z0-9_]+)"', source):
            if key not in keys:
                issues.append(f'unknown text key {key}')
    for npc in re.findall(r'\bnpc\s*=\s*"(\w+)"', tutorial):
        if not re.search(r'\b' + re.escape(npc) + r'\s*=\s*{', npcs):
            issues.append(f'unknown npc {npc}')
    for post in re.findall(r'\bpost\s*=\s*"(\w+)"', tutorial):
        if not re.search(r'\bname=' + re.escape(post) + r'(?:\s|$)', farm):
            issues.append(f'unknown post {post}')
    for quest in re.findall(r'\bquest\s*=\s*"(\w+)"', tutorial):
        if not (root / 'lua/quests' / f'{quest}.lua').exists():
            issues.append(f'unknown quest {quest}')
    for dialogue in re.findall(r'kind\s*=\s*"dialogue"\s*,\s*id\s*=\s*"(\w+)"', tutorial):
        if not (root / 'lua/farm' / f'{dialogue}.lua').exists():
            issues.append(f'unknown dialogue {dialogue}')
    if '"slot_7"' not in tutorial:
        issues.append('starter seeds must use current slot seven')
    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', nargs='?', type=Path, default=ROOT)
    parser.add_argument('--selftest', action='store_true')
    args = parser.parse_args()
    problems = check(args.root)
    for problem in problems:
        print('FAIL', problem)
    if problems:
        return 1
    if args.selftest:
        path = 'lua/farm/farm_tutorial.lua'
        base = (args.root / path).read_text()
        mutants = [('npc', 'npc = "postman_pip"', 'npc = "unknown_npc"'), ('post', 'post = "pip_mailbox"', 'post = "unknown_post"'), ('quest', 'quest = "forste_dage"', 'quest = "unknown_quest"'), ('dialogue', 'id = "farm_intro_pip"', 'id = "unknown_dialogue"'), ('key', 'key = "TUT_HINT_HOE"', 'key = "TUT_UNKNOWN_KEY"')]
        for label, old, new in mutants:
            caught = check(args.root, {path: base.replace(old, new)})
            print(('PASS' if caught else 'FAIL'), 'mutant_' + label)
            if not caught:
                return 1
    print('PASS tutorial references, copy boxes and starter bindings')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
