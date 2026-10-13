#!/usr/bin/env python3
"""Review fix C2: 11 of 22 wardrobe-set bonus rows could never trigger because the bonus counts WORN pieces and at most 7 pieces (6 with a dress) can be worn.
Rewrites the `pieces` of unreachable rows of lua/data/sets.lua wardrobe_sets in place (perks stay, rows are compressed under the wearable maximum M):
  compress from the top (new_i = min(pieces_i, M-(k-i))); if that would push the first row below its own count, keep the first and the top row only.
  python tools/features/retier_wardrobe_sets.py [--features DIR] [--apply]      (reads reports/lua_dump.json of tools/features: run tools/features/validate/run_validate.sh first;
                                                                                 with --apply it rewrites lua/data/sets.lua of --repo, default this repo)
Applied once (CD13, review RV-C2); kept as the way to re-tier after content edits.  The validator rule R15 is the check that says whether it is needed.
"""
import argparse, itertools, json, re
from pathlib import Path

def wearable_max(members, clo, slots, excl):
    by = {}
    for m in members:
        it = clo[m]; by.setdefault(it['subslot'] if it['slot'] == 'jewellery' else it['slot'], []).append(m)
    have = [s for s in slots if s in by]
    best = 0
    for r in range(len(have) + 1):
        for combo in itertools.combinations(have, r):
            if any(a in combo and b in combo for a, b in excl): continue
            best = max(best, len(combo))
    return best

def retier(rows, M):
    if all(r['pieces'] <= M for r in rows): return rows, False
    k = len(rows); first = rows[0]['pieces']; new = []; cap = M
    for i in reversed(range(k)):
        p = min(rows[i]['pieces'], cap); new.append(p); cap = p - 1
    new.reverse()
    if new[0] >= first:
        return [dict(r, pieces=p) for r, p in zip(rows, new)], True
    return [dict(rows[0]), dict(rows[-1], pieces=M)], True

def fmt_row(r):
    keys = ['pieces'] + [k for k in r if k != 'pieces']
    parts = []
    for k in keys:
        v = r[k]; parts.append(f'{k} = {v:g}' if isinstance(v, float) else f'{k} = {v}')
    return '{ ' + ', '.join(parts) + ' }'

def main():
    HERE = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser(); ap.add_argument('--features', default=str(HERE)); ap.add_argument('--repo', default=str(HERE.parents[1])); ap.add_argument('--apply', action='store_true'); a = ap.parse_args()
    F = Path(a.features); REPO = Path(a.repo)
    D = {d['file']: d for d in json.load(open(F / 'reports' / 'lua_dump.json'))}
    sets = D['lua/data/sets.lua']['globals']['config']['wardrobe_sets']
    clo = D['lua/items/clothing.lua']['globals']['items']
    rules = D['lua/data/wardrobe_rules.lua']['globals']['config']['wardrobe']
    slots = list(rules['equip_slots']); excl = [tuple(x) for x in rules['exclusive']]
    text = (REPO / 'lua/data/sets.lua').read_text()
    head, tail = text.split('wardrobe_sets = {', 1)
    changed = {}
    for sid, s in sets.items():
        M = wearable_max(s['members'], clo, slots, excl)
        rows, ch = retier(s['bonuses'], M)
        if not ch: continue
        changed[sid] = (M, [r['pieces'] for r in s['bonuses']], [r['pieces'] for r in rows])
        # rewrite this set's bonuses block inside the wardrobe_sets text
        m = re.search(r'(    ' + sid + r' = \{.*?      bonuses = \{\n)(.*?)(      \},\n)', tail, re.S)
        assert m, sid
        new_rows = ''.join('        ' + fmt_row(r) + ',\n' for r in rows)
        tail = tail[:m.start(2)] + new_rows + tail[m.end(2):]
    print(json.dumps(changed, indent=1))
    if a.apply:
        (REPO / 'lua/data/sets.lua').write_text(head + 'wardrobe_sets = {' + tail)
        print('applied to', REPO / 'lua/data/sets.lua')

if __name__ == '__main__':
    main()
