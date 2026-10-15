#!/usr/bin/env python3
"""Availability of the citizens for the `mixed` variant of the balance Monte Carlo (balance_mc.py): when can the player actually TALK to a citizen?

A citizen is TALKABLE at an hour of a weekday (clear or rainy) when he stands outdoors, walks (in transit, outdoors) or - a keeper - stands at his counter
(the `talk` host cells of design decision DT53 sit on the customer cells in front of every counter band). He is NOT talkable inside a building away from
his counter ('room' / 'inside'), asleep, or away ('away': out in the forest, at the field ...).

THE TABLE (JSON, schema version 1) is built from the routines of the towns track:

    {"version": 1, "source": "<where it came from>", "talkable_kinds": ["outdoor", "walk", "counter"],
     "npcs": {"<npc id>": {"<weekday 0..6>": {"klart": [[kind, t0, t1], ...], "regn": [[kind, t0, t1], ...]}}}}

kind is one of outdoor walk counter room inside away; t0 / t1 are game hours on the 6..26 axis (t1 exclusive). Producers:
  * tools/social/core/build_availability_snapshot.py - the DESIGN snapshot (the python mirror of the 30 routines of the design phase), pinned in
    tests/lib/social/fixtures/availability_design.json: what the section uses until the real routines (T-routes, wave 5) can be sampled;
  * a driver that samples Routines.where_is over a day (the same schema) replaces it when the real routines exist (handoff to T-routes / S-qa).

usage as a library:  table = load(path);  talkable(table, "baker_maja", 2, 14.5, False)
"""
import json

DEFAULT_KINDS = ('outdoor', 'walk', 'counter')


def load(path):
    with open(path, encoding='utf-8') as f:
        table = json.load(f)
    if table.get('version') != 1 or 'npcs' not in table:
        raise ValueError('%s is not an availability table of version 1' % path)
    return table


def talkable_kinds(table):
    return tuple(table.get('talkable_kinds', DEFAULT_KINDS))


def spans(table, npc, weekday, rain):
    day = table['npcs'].get(npc, {}).get(str(weekday), {})
    return day.get('regn' if rain else 'klart', [])


def _merged(table, npc, weekday, rain):
    """The talkable intervals of one (citizen, weekday, weather), merged and memoised on the table (a Monte Carlo asks millions of times)."""
    memo = table.setdefault('_merged', {})
    key = (npc, weekday, rain)
    if key not in memo:
        kinds = talkable_kinds(table)
        iv = sorted((t0, t1) for kind, t0, t1 in spans(table, npc, weekday, rain) if kind in kinds)
        out = []
        for a, b in iv:
            if out and a <= out[-1][1]:
                out[-1][1] = max(out[-1][1], b)
            else:
                out.append([a, b])
        memo[key] = out
    return memo[key]


def talkable(table, npc, weekday, hour, rain):
    for t0, t1 in _merged(table, npc, weekday, rain):
        if t0 <= hour < t1:
            return True
    return False


def talkable_hours_per_week(table, npc, rain=False):
    """Hours per week the citizen is talkable between 06:00 and 23:30 (a sanity number for reports)."""
    kinds = talkable_kinds(table)
    total = 0.0
    for wd in range(7):
        for kind, t0, t1 in spans(table, npc, wd, rain):
            if kind in kinds:
                total += max(0.0, min(t1, 23.5) - max(t0, 6.0))
    return total
