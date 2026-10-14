#!/usr/bin/env python3
"""check_farm_map.py - offline checker of data/maps/farm.map (package N01). No Godot needed.

It re-checks from the TEXT alone the facts the headless section `maps_farm` proves with the real engine, so a bad hand edit of the map
is caught in a second. Eleven groups: 1 header, 2 grid, 3 field (84 = 12 x 7), 4 expansion zone (42 cells), 5 home reserve and growth rows,
6 spawns / warps (+ the towns contract: ONE `town curfew=false` anchor, the five named posts, the dress flag `festival_now`), 7 objects on void,
8 light budget, 9 HUD / canopy band, 10 building slots, 11 a conservative reachability BFS (fences, trunks, shed, bin block; the Godot A* probe
of maps_farm is authoritative).

usage:  check_farm_map.py [MAP]          check a map (default: data/maps/farm.map of this repo); exit 0 = clean, 1 = findings
        check_farm_map.py --selftest     the baseline must be clean and EIGHT mutants of the map must each be caught
                                         (E1 cells moved into the reserve, 83 `f` cells, spawn from_home removed, a gap in the bridge, a growth
                                         marker on the wrong row, a post renamed, the town anchor missing, a Skovport lift marker back);
                                         prints `PASS farm_map_tool.selftest_catches_eight_mutants` or `FAIL ...`, exit 1 when one slips through
"""
import os, re, sys
from collections import deque

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT = os.path.join(HERE, '..', '..', 'data', 'maps', 'farm.map')
GROUND = set('.,;fpcd~=#')
INTER = {'node', 'sign', 'bed', 'mailbox', 'shipping_bin', 'tool_shed', 'warp', 'field_expansion', 'dig_spot', 'unique_spot', 'quest_spot', 'animal_yard', 'building_slot', 'home'}
BLOCK_FOOT = {'trunk_giant_b': (3, 3), 'tool_shed': (2, 2), 'shipping_bin': (2, 1)}     # (fx, fy): cells x-fx+1..x, y-fy+1..y
BLOCK_ART = {'fence_x', 'fence_z'}
VOID_OK = {'trunk_giant_a', 'trunk_giant_b', 'tent'}
LIGHTS_MAX = 12
HUD_ROWS = 8             # anti-diagonals between an interactive marker and the top of the map (canopy frame band, 140 px at zoom 0.4)


def parse(text):
    hdr, props, marks, g, o, sect = {}, {}, {}, [], [], None
    for line in text.splitlines():
        if not line.strip() or line.startswith('#') and sect is None:
            continue
        if line.startswith('@ground'):
            sect = 'g'; continue
        if line.startswith('@objects'):
            sect = 'o'; continue
        if sect == 'g':
            g.append(line)
        elif sect == 'o':
            o.append(line)
        elif line.startswith('@prop '):
            _, ch, art = line.split(None, 2)
            props[ch] = art.strip()
        elif line.startswith('@marker '):
            parts = line.split()
            kv = dict(p.split('=', 1) for p in parts[3:] if '=' in p)
            marks[parts[1]] = {'type': parts[2], **kv}
        elif line.startswith('@'):
            k, _, v = line[1:].partition(' ')
            hdr[k] = v.strip()
    return hdr, props, marks, g, o


def cells_of(spec):
    out = set()
    for part in spec.split(';'):
        m = re.fullmatch(r'(-?\d+)(?:\.\.(-?\d+))?,(-?\d+)(?:\.\.(-?\d+))?', part.strip())
        if not m:
            return None
        x0, x1, y0, y1 = int(m[1]), int(m[2] or m[1]), int(m[3]), int(m[4] or m[3])
        out |= {(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1)}
    return out


def check(text):
    F = []
    hdr, props, marks, G, O = parse(text)
    H, W = len(G), len(G[0]) if G else 0
    # 1 header
    want = {'id': 'farm', 'title': 'ZONE_FARM', 'projection': 'iso', 'zone': 'farm', 'ambient': 'farm', 'flight': 'true', 'music': 'farm_theme'}
    for k, v in want.items():
        if hdr.get(k) != v:
            F.append(f'header {k}: {hdr.get(k)!r} != {v!r}')
    # 2 grid
    if len(O) != H or any(len(r) != W for r in G) or any(len(r) != W for r in O):
        F.append(f'ground / objects grids are not the same rectangle ({H} rows ground, {len(O)} objects)')
        return F
    bad = {c for r in G for c in r if c not in GROUND}
    if bad:
        F.append(f'unknown ground chars {sorted(bad)}')
    gc = lambda x, y: G[y][x] if 0 <= x < W and 0 <= y < H else '#'
    obj = {}
    for y, r in enumerate(O):
        for x, c in enumerate(r):
            if c != '.':
                obj[(x, y)] = c
                if c != '@' and c not in props and c not in marks:
                    F.append(f'undeclared object char {c!r} at {x},{y}')
    kind = lambda c: ('@' if c == '@' else marks[c]['type'] if c in marks else props.get(c, '?'))
    ismark = lambda c: c in marks
    # 3 field
    f = {(x, y) for y in range(H) for x in range(W) if G[y][x] == 'f'}
    if len(f) != 84:
        F.append(f'field cells {len(f)} != 84')
    if f:
        xs, ys = [c[0] for c in f], [c[1] for c in f]
        if (max(xs) - min(xs) + 1, max(ys) - min(ys) + 1) != (12, 7):
            F.append(f'field bbox {max(xs) - min(xs) + 1} x {max(ys) - min(ys) + 1} != 12 x 7')
    # door / home
    homes = [p for p, c in obj.items() if ismark(c) and kind(c) == 'home']
    if len(homes) != 1:
        F.append(f'{len(homes)} home markers')
        return F
    D = homes[0]
    # 4 expansion
    ex = [(p, marks[c]) for p, c in obj.items() if ismark(c) and kind(c) == 'field_expansion']
    if len(ex) != 1:
        F.append(f'{len(ex)} field_expansion markers')
    else:
        p, m = ex[0]
        cs = cells_of(m.get('cells', ''))
        if cs is None or len(cs) != 42:
            F.append(f'expansion cells {None if cs is None else len(cs)} != 42')
        else:
            if any(gc(x, y) != '.' for x, y in cs):
                F.append('expansion cells are not all plain `.` ground (they must be grass, not f, not deck, not void)')
            if any(abs(x - D[0]) <= 9 and -9 <= y - D[1] <= 2 for x, y in cs):
                F.append('expansion cells overlap the home reserve zone')
            if cs & f:
                F.append('expansion cells overlap the field')
        if m.get('price') != '800':
            F.append(f'expansion price {m.get("price")} != 800')
    # 5 reserve + growth
    for y in range(D[1] - 2, D[1] + 1):
        for x in range(D[0] - 4, D[0] + 5):
            if gc(x, y) != 'd':
                F.append(f'reserve base cell {x - D[0]},{y - D[1]} is not deck')
            c = obj.get((x, y))
            if c and (x, y) != D:
                F.append(f'reserve base cell {x - D[0]},{y - D[1]} carries object {c!r} ({kind(c)})')
    for st in (1, 2, 3):
        row = D[1] - 2 - st
        for x in range(D[0] - 4, D[0] + 5):
            if gc(x, row) != '#':
                F.append(f'growth row {st} cell {x - D[0]},{row - D[1]} is not void at start')
            if (x, row) in obj and kind(obj[(x, row)]) != 'growth':
                F.append(f'growth row {st} carries an object at {x - D[0]},{row - D[1]}')
    gm = {int(m['stage']): cells_of(m['cells']) for m in marks.values() if m['type'] == 'growth'}
    for st in (1, 2, 3):
        want_c = {(x, D[1] - 2 - st) for x in range(D[0] - 4, D[0] + 5)}
        if gm.get(st) != want_c:
            F.append(f'growth marker stage {st} does not name row D-{2 + st} x D-4..D+4')
    # 6 spawns, warps
    names = {m.get('name') for m in marks.values() if m['type'] == 'spawn'}
    if not any(c == '@' for c in obj.values()):
        F.append('no default spawn `@`')
    for need in ('from_home', 'from_traetoppen'):
        if need not in names:
            F.append(f'spawn {need} missing')
    if any(n and n.startswith('from_skov') or n == 'from_forest' for n in names):
        F.append('a forest spawn exists (the Skovport is removed)')
    sp = {marks[c]['name']: p for p, c in obj.items() if ismark(c) and kind(c) == 'spawn' and 'name' in marks[c]}
    if 'from_home' in sp and sp['from_home'] != (D[0], D[1] + 2):
        F.append(f'from_home is {sp["from_home"]}, must be door + (0, 2) = {(D[0], D[1] + 2)}')
    for p, c in obj.items():
        if ismark(c) and kind(c) == 'warp':
            m = marks[c]
            if not m.get('to') or not m.get('spawn'):
                F.append(f'warp at {p} lacks to= or spawn=')
            if m.get('to') != 'traetoppen':
                F.append(f'warp at {p} goes to {m.get("to")} (only traetoppen is allowed: the forest is entered by the Skovlift)')
            if gc(*p) != '=':
                F.append(f'warp at {p} is not on a bridge plank')
        if ismark(c) and kind(c) == 'lift':
            F.append(f'lift marker at {p} (the Skovport is removed)')
    # 6b the towns track's contract: ONE `town curfew=false` anchor and the five named posts on walkable ground
    towns = [(p, marks[c]) for p, c in obj.items() if ismark(c) and kind(c) == 'town']
    if len(towns) != 1 or towns[0][1].get('curfew') != 'false':
        F.append(f'{len(towns)} town markers (exactly one `town curfew=false` is the anchor of the towns director)')
    post_names = sorted(marks[c].get('name', '') for c in obj.values() if ismark(c) and kind(c) == 'post')
    if post_names != sorted(['bench_a', 'field_edge', 'hoppe_fence', 'pip_mailbox', 'porch']):
        F.append(f'post names {post_names} differ from the five of the social contract')
    for p, c in obj.items():
        if ismark(c) and kind(c) == 'post' and gc(*p) in '#~=':
            F.append(f'post {marks[c].get("name")} is not on walkable ground')
    # 6c the social contract of the dress markers: exactly one condition, and the festival condition is the WORLD FLAG `festival_now`
    # (the id of the festival that is ACTIVE now, empty otherwise - SocialManager writes it); `festival_today` is a METHOD, never a flag (DT14)
    dress = [(p, marks[c]) for p, c in obj.items() if ismark(c) and kind(c) == 'dress']
    if len(dress) != 16:
        F.append(f'{len(dress)} dress markers, the prototype has 16')
    for p, m in dress:
        conds = [k for k in ('tier', 'season', 'event') if k in m]
        if len(conds) != 1 or not m.get('prop'):
            F.append(f'dress marker at {p[0] - D[0]},{p[1] - D[1]} must carry a prop and exactly one of tier / season / event (has {conds})')
        if 'event' in m and m['event'] != 'festival_now':
            F.append(f'dress marker at {p[0] - D[0]},{p[1] - D[1]} reads event={m["event"]}: the world flag is `festival_now`')
    if 'festival_today' in text:
        F.append('`festival_today` appears in the map (it is a method of the social track, not a world flag)')
    # 7 objects on void
    for p, c in obj.items():
        if gc(*p) == '#' and c != '@':
            nm = props.get(c) or marks.get(c, {}).get('type')
            if nm not in VOID_OK and nm not in ('underdeck', 'growth'):
                F.append(f'object {nm} stands on void at {p[0] - D[0]},{p[1] - D[1]}')
    # 8 lights
    lights = sum(1 for c in obj.values() if props.get(c) == 'lantern_post' or (ismark(c) and kind(c) == 'light'))
    if lights > LIGHTS_MAX:
        F.append(f'{lights} lights > {LIGHTS_MAX}')
    # 9 HUD / canopy band
    vtop = min(x + y for y in range(H) for x in range(W) if G[y][x] != '#')
    for p, c in obj.items():
        if ismark(c) and kind(c) in INTER and (p[0] + p[1]) - vtop < HUD_ROWS:
            F.append(f'interactive {kind(c)} at {p[0] - D[0]},{p[1] - D[1]} is only {(p[0] + p[1]) - vtop} anti-diagonals below the top (< {HUD_ROWS})')
    # 10 building slots free
    for p, c in obj.items():
        if ismark(c) and kind(c) == 'building_slot':
            fx, fy = {'coop': (3, 2), 'barn': (4, 3), 'house': (3, 2)}.get(marks[c].get('type', ''), (0, 0))
            if not fx:
                F.append(f'building_slot {p} has unknown type {marks[c].get("type")}')
            for x in range(p[0] - fx + 1, p[0] + 1):
                for y in range(p[1] - fy + 1, p[1] + 1):
                    if (x, y) != p and (x, y) in obj:
                        F.append(f'slot {marks[c].get("type")} footprint holds {kind(obj[(x, y)])} at {x - D[0]},{y - D[1]}')
                    if gc(x, y) in '#~':
                        F.append(f'slot {marks[c].get("type")} footprint cell {x - D[0]},{y - D[1]} is not ground')
    gh = [p for p, c in obj.items() if ismark(c) and kind(c) == 'greenhouse_slot']
    for p in gh:
        for x in range(p[0] - 3, p[0] + 1):
            for y in range(p[1] - 2, p[1] + 1):
                if (x, y) != p and (x, y) in obj:
                    F.append(f'greenhouse slot footprint holds {kind(obj[(x, y)])}')
    # 11 reachability (conservative): 8-neighbour BFS, no corner cutting, blocked cells = fences, trunk_giant_b, shed, bin
    blocked = set()
    for p, c in obj.items():
        art = props.get(c) or (marks[c].get('prop') if ismark(c) else None)
        nm = props.get(c) or (kind(c) if ismark(c) else None)
        if art in BLOCK_ART:
            blocked.add(p)
        key = art if art in BLOCK_FOOT else (nm if nm in BLOCK_FOOT else None)
        if key:
            fx, fy = BLOCK_FOOT[key]
            blocked |= {(x, y) for x in range(p[0] - fx + 1, p[0] + 1) for y in range(p[1] - fy + 1, p[1] + 1)}
    walk = lambda x, y: gc(x, y) not in '#~' and (x, y) not in blocked
    start = next((p for p, c in obj.items() if c == '@'), None)
    if start is None:
        return F
    seen, dq = {start}, deque([start])
    while dq:
        x, y = dq.popleft()
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if (dx or dy) and walk(x + dx, y + dy) and (x + dx, y + dy) not in seen:
                    if dx and dy and not (walk(x + dx, y) and walk(x, y + dy)):
                        continue
                    seen.add((x + dx, y + dy)); dq.append((x + dx, y + dy))
    for p, c in obj.items():
        if ismark(c) and kind(c) in INTER | {'post'}:
            if not any((p[0] + dx, p[1] + dy) in seen for dx in range(-2, 3) for dy in range(-2, 3)):
                F.append(f'{kind(c)} at {p[0] - D[0]},{p[1] - D[1]} is not reachable from the default spawn')
    miss = [c for c in f if c not in seen]
    if miss:
        F.append(f'{len(miss)} field cells are not reachable (the gate?)')
    return F


MUTANTS = [
    ('expansion cells moved into the home reserve', lambda t: re.sub(r'(field_expansion id=east cells=)[^ ]+', r'\g<1>31..36,13..19', t)),
    ('83 field cells (one f turned into grass)', lambda t: t.replace('f', '.', 1) if False else re.sub(r'(@ground\n(?:.*\n)*?[^\n]*?)f', r'\1.', t, count=1)),
    ('spawn from_home removed', lambda t: t.replace('spawn name=from_home', 'spawn name=from_hom', 1)),
    ('a gap in the hanging bridge', lambda t: _gap(t)),
    ('growth marker of stage 2 on the wrong row', lambda t: re.sub(r'(growth stage=2 cells=\d+\.\.\d+,)(\d+)', lambda m: m[1] + str(int(m[2]) - 3), t)),
    ('the post pip_mailbox is renamed (the towns routines would find no post)', lambda t: t.replace('post name=pip_mailbox', 'post name=pip_mailbxo', 1)),
    ('the towns director anchor is missing', lambda t: t.replace('@marker T town curfew=false', '@marker T dummy', 1)),
    ('a Skovport lift marker is back', lambda t: t.replace('@marker x field_expansion', '@marker Y lift entry=skovport prop=warp_gate_stone\n@marker x field_expansion', 1)),
]


def _gap(t):
    """One plank in the middle of the HANGING bridge (the last nine `=` rows of the file) turns into void."""
    head, _, rest = t.partition('@ground\n')
    g, _, objs = rest.partition('@objects\n')
    rows = g.split('\n')
    plank_rows = [i for i, r in enumerate(rows) if '=' in r]
    hang = plank_rows[-9:]
    i = hang[4]
    rows[i] = rows[i].replace('=', '#', 1)
    return head + '@ground\n' + '\n'.join(rows) + '@objects\n' + objs


def main():
    a = sys.argv[1:]
    if a and a[0] == '--selftest':
        base = open(DEFAULT, encoding='utf-8').read()
        base_findings = check(base)
        print(f'baseline: {len(base_findings)} findings')
        for fnd in base_findings:
            print('   -', fnd)
        if base_findings:
            print('FAIL farm_map_tool.selftest_catches_eight_mutants (the baseline map is not clean)')
            return 1
        slipped = 0
        for name, fn in MUTANTS:
            f = check(fn(base))
            print(f'mutant {name}: {"CAUGHT (" + str(len(f)) + " findings, first: " + f[0] + ")" if f else "SLIPPED THROUGH"}')
            slipped += 0 if f else 1
        if len(MUTANTS) != 8:
            print(f'FAIL farm_map_tool.selftest_catches_eight_mutants (the table holds {len(MUTANTS)} mutants, not eight)')
            return 1
        print('SELFTEST', 'FAILED' if slipped else 'OK: baseline clean, all %d mutants caught' % len(MUTANTS))
        print(('FAIL' if slipped else 'PASS') + ' farm_map_tool.selftest_catches_eight_mutants')
        return 1 if slipped else 0
    path = a[0] if a else DEFAULT
    f = check(open(path, encoding='utf-8').read())
    for x in f:
        print('FINDING:', x)
    print('OK: farm.map passes every offline check' if not f else f'{len(f)} findings')
    return 1 if f else 0


if __name__ == '__main__':
    sys.exit(main())
