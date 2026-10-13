#!/usr/bin/env python3
"""Regenerates the snapshot of the content numbers that A1 (and later A2) test their art against.

A1 needs the content numbers in wave 2, but lua/data and lua/items are F1's (wave 3): A1 ships tools/art/features/home/specs/content_contract.json (generated from the reviewed pack at lift time),
A1's art_home checks compare the art against IT (no Lua needed, nothing SKIPped); F1's validator rule R19 proves the snapshot still equals the real Lua.  When R19 fails because the Lua changed:

    tools/features/validate/run_validate.sh --stage f1            # writes tools/features/reports/lua_dump.json (real Lua 5.4)
    python3 tools/features/make_content_contract.py               # -> tools/features/reports/content_contract.json
    # hand the file to A1 (owner of tools/art/features/home/specs/content_contract.json): this package never writes outside its own files

    python3 tools/features/make_content_contract.py [--features DIR (default: tools/features)] [--out FILE]   (DIR needs reports/lua_dump.json)"""
import argparse
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ap = argparse.ArgumentParser()
ap.add_argument('--features', default=str(HERE))
ap.add_argument('--out')
a = ap.parse_args()
F = Path(a.features)
D = {d['file']: d for d in json.loads((F / 'reports' / 'lua_dump.json').read_text())}
G = lambda f, n: D[f]['globals'][n]  # noqa: E731
home = G('lua/data/home_tiers.lua', 'config')['home']
fur = G('lua/items/furniture.lua', 'items')
mat = G('lua/items/building_materials.lua', 'items')
clo = G('lua/items/clothing.lua', 'items')
out = {'v': 1, 'tiers': [{'tier': t['tier'], 'capacity': t['perks']['furniture_capacity'], 'floor': t['art']['floor'], 'walls': t['art']['walls'], 'platform_back_rows': t['art']['platform_back_rows'],
                          'gift_items': t.get('gift_items', []), 'exterior': t['art']['exterior'], 'night': t['art']['night'], 'interior': t['art']['interior'], 'scaffold': t['art'].get('scaffold')} for t in home['tiers']],
       'furniture': {i: {'template': e['art']['template'], 'rarity': e['rarity'], 'footprint': e['footprint'], 'layer': e['placement']} for i, e in sorted(fur.items())},
       'materials': sorted(mat), 'garments': {i: {'slot': e['slot'], 'subslot': e.get('subslot'), 'rarity': e['rarity']} for i, e in sorted(clo.items())}}
p = Path(a.out) if a.out else F / 'reports' / 'content_contract.json'
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(json.dumps(out, indent=1, ensure_ascii=False), encoding='utf-8')
print('wrote', p, len(out['furniture']), 'furniture', len(out['materials']), 'materials', len(out['garments']), 'garments')
