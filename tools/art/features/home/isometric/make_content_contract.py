#!/usr/bin/env python3
"""A1 needs the content numbers in wave 2, but lua/data and lua/items are F1's (wave 3).  Review fix: A1 ships specs/content_contract.json (this file, generated from the content pack at lift time),
A1's art_home checks compare the art against IT (no Lua needed, nothing SKIPped); F1's validator rule R19 proves the snapshot still equals the real Lua.
   python3 make_content_contract.py --features DIR [--out FILE]   (DIR needs reports/lua_dump.json from run_validate.sh)"""
import argparse, json
from pathlib import Path
ap = argparse.ArgumentParser(); ap.add_argument('--features', required=True); ap.add_argument('--out'); a = ap.parse_args()
F = Path(a.features)
D = {d['file']: d for d in json.loads((F / 'reports' / 'lua_dump.json').read_text())}
G = lambda f, n: D[f]['globals'][n]  # noqa: E731
home = G('lua/data/home_tiers.lua', 'config')['home']
fur = G('lua/items/furniture.lua', 'items'); mat = G('lua/items/building_materials.lua', 'items'); clo = G('lua/items/clothing.lua', 'items')
out = {'v': 1, 'tiers': [{'tier': t['tier'], 'capacity': t['perks']['furniture_capacity'], 'floor': t['art']['floor'], 'walls': t['art']['walls'], 'platform_back_rows': t['art']['platform_back_rows'],
                          'gift_items': t.get('gift_items', []), 'exterior': t['art']['exterior'], 'night': t['art']['night'], 'interior': t['art']['interior'], 'scaffold': t['art'].get('scaffold')} for t in home['tiers']],
       'furniture': {i: {'template': e['art']['template'], 'rarity': e['rarity'], 'footprint': e['footprint'], 'layer': e['placement']} for i, e in sorted(fur.items())},
       'materials': sorted(mat), 'garments': {i: {'slot': e['slot'], 'subslot': e.get('subslot'), 'rarity': e['rarity']} for i, e in sorted(clo.items())}}
p = Path(a.out) if a.out else F / 'data' / 'content_contract.json'
p.write_text(json.dumps(out, indent=1, ensure_ascii=False), encoding='utf-8'); print('wrote', p, len(out['furniture']), 'furniture', len(out['materials']), 'materials', len(out['garments']), 'garments')
