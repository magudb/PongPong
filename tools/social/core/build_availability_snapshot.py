#!/usr/bin/env python3
"""Builds the DESIGN availability snapshot (tests/lib/social/fixtures/availability_design.json) from the python mirror of the 30 routines of the towns design
phase (model.py / plans.py / sim.py + proto/routes.json). One-off provenance tool: the snapshot is committed, so nothing in the game or the harness needs
the design folder; run it only to regenerate the snapshot.

    python3 -B -I tools/social/core/build_availability_snapshot.py --towns <design3/towns_scripts> --out tests/lib/social/fixtures/availability_design.json

A segment is classified like the design review did: a move between two outdoor places is 'walk' (in transit), a move to / from 'nowhere' or an away: block is 'away', a stay
at a counter post (.counter .tub .throne .t_stall .e_bat_window .mayor_desk) is 'counter', a stay inside an int_<building> room is 'room', everything else outdoors is 'outdoor'.
Hours are clipped to 06:00..23:30 (the design day) like the review's measurement, so the numbers of the Monte Carlo reproduce exactly.
"""
import argparse
import collections
import json
import os
import sys

COUNTER_SUFFIX = ('.counter', '.tub', '.throne', '.t_stall', '.e_bat_window', '.mayor_desk')


def kind_of(seg):
    if seg['kind'] == 'move':
        a, b = seg['from'], seg['to']
        if a == 'nowhere' or b == 'nowhere' or a.startswith('away:') or b.startswith('away:'):
            return 'away'
        return 'walk'
    place, act = seg['place'], seg['act']
    if place == 'nowhere' or place.startswith('away:'):
        return 'away'
    area = place.split('.')[0]
    if place.endswith(COUNTER_SUFFIX):
        return 'counter'
    if area.startswith('int_'):
        return 'room'
    if act == 'inside':
        return 'inside'
    return 'outdoor'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--towns', required=True, help='design3/towns_scripts (model.py plans.py sim.py proto/routes.json)')
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    sys.path.insert(0, a.towns)
    import model as M            # noqa: E402
    import sim as S              # noqa: E402
    routes = S.Routes(os.path.join(a.towns, 'proto', 'routes.json'))
    npcs = collections.OrderedDict()
    for npc in sorted(M.CITIZENS):
        per_day = {}
        for wd in range(7):
            per_weather = {}
            for weather in ('klart', 'regn'):
                _name, blocks = S.blocks_for(npc, wd, weather, 5)
                segs = S.timeline(blocks, routes, None, '')
                rows = []
                for s in segs:
                    t0, t1 = max(6.0, s['t0']), min(23.5, s['t1'])
                    if t1 > t0:
                        rows.append([kind_of(s), round(t0, 4), round(t1, 4)])
                per_weather[weather] = rows
            per_day[str(wd)] = per_weather
        npcs[npc] = per_day
    out = {'version': 1, 'source': 'design3 towns model (python mirror of the 30 routines, hearts 5), sampled by build_availability_snapshot.py', 'talkable_kinds': ['outdoor', 'walk', 'counter'], 'npcs': npcs}
    with open(a.out, 'w', encoding='utf-8') as f:
        json.dump(out, f, separators=(',', ':'), ensure_ascii=False)
        f.write('\n')
    print('wrote %s: %d citizens' % (a.out, len(npcs)))


if __name__ == '__main__':
    main()
