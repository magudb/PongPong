#!/usr/bin/env python3
"""Content validator of the feature pack (package F1, staged since the review: docs/features/STAGES.md).

Inputs: the STAGE TREE (tools/features/validate/stage.py: lua/, localization/, data/ assembled from the scattered repo files + the pending references),
a REAL-Lua dump of it (ser.lua, Lua 5.4), the dump of the project's REAL LuaRuntime (validate_godot.gd) and the art tooling of the repo (A1's tables, A2's later).
Exit code 0 only when there is no FAIL.  Normally started by run_validate.sh:

    python3 tools/features/validate/validate.py --features STAGE_TREE --repo REPO --stage f1|p13|p14|full --lua-dump F --repo-lua-dump F --pending-lua-dump F --godot-dump F
                                                [--art-home DIR --art-wardrobe DIR --art-python PY --fonts DIR] --report FILE

Generation is retired (RV-P6): the Lua and CSV files are hand-owned, so there is no rule "regeneration changes no byte".
"""
from __future__ import annotations
import argparse
import ast
import csv
import json
import math
import os
import random
import re
import runpy
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / 'src'))
sys.path.insert(0, str(HERE.parent))
import common as cm  # constants only (areas, npc/quest/shop universes, caps)
import rename_town as _rename_town  # the text suffixes the rename tool rewrites are the suffixes rule N1 scans

RARITIES = cm.RARITIES
PASS, FAIL, WARN = 'PASS', 'FAIL', 'WARN'


class Report:
    def __init__(self):
        self.rows = []
        self.counts = Counter()

    def check(self, name, ok, detail=''):
        st = PASS if ok else FAIL
        self.rows.append((st, name, str(detail)))
        self.counts[st] += 1
        return ok

    def warn(self, name, detail=''):
        self.rows.append((WARN, name, str(detail)))
        self.counts[WARN] += 1

    def info(self, name, detail=''):
        self.rows.append(('INFO', name, str(detail)))

    def text(self):
        out = []
        for st, name, d in self.rows:
            out.append(f'[{st:4}] {name}' + (f'  --  {d}' if d else ''))
        out.append('')
        out.append(f'RESULT: {self.counts[PASS]} passed, {self.counts[FAIL]} failed, {self.counts[WARN]} warnings')
        return '\n'.join(out)


R = Report()


# --------------------------------------------------------------------------------------------------------------------------------------
def norm(v):
    """normalise a decoded JSON value so real-Lua output and Godot output can be compared"""
    if isinstance(v, dict):
        if not v:
            return []
        return {str(k): norm(x) for k, x in v.items()}
    if isinstance(v, list):
        return [norm(x) for x in v]
    if isinstance(v, float) and v == int(v):
        return int(v)
    if isinstance(v, float):
        return round(v, 6)
    return v


def deep_diff(a, b, path='', out=None, limit=8):
    out = [] if out is None else out
    if len(out) >= limit:
        return out
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)):
            if k not in a:
                out.append(f'{path}.{k}: only in Godot')
            elif k not in b:
                out.append(f'{path}.{k}: only in real Lua')
            else:
                deep_diff(a[k], b[k], f'{path}.{k}', out, limit)
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            out.append(f'{path}: list length real={len(a)} godot={len(b)}')
        else:
            for i, (x, y) in enumerate(zip(a, b)):
                deep_diff(x, y, f'{path}[{i}]', out, limit)
    elif a != b:
        out.append(f'{path}: real={json.dumps(a, ensure_ascii=False)[:80]} godot={json.dumps(b, ensure_ascii=False)[:80]}')
    return out


def load_csv(path: Path):
    rows = []
    with path.open(encoding='utf-8', newline='') as f:
        rd = csv.reader(f)
        header = next(rd)
        for i, row in enumerate(rd, 2):
            rows.append((i, row))
    return header, rows


# --------------------------------------------------------------------------------------------------------------------------------------
# Rule helpers on plain data (FIX ROUND of review F1 r1).  They live at module level so that rules_selftest.py can run them on small synthetic inputs and watch them FAIL:
# a rule that was never seen failing is not a rule (N1 was vacuous for the default stage path and nobody noticed).
OLD_TOWN_NAME = 'fes' + 'by'                                 # lower case, built from parts: the retired town name is never written in this repository
SCAN_SUFFIXES = tuple(sorted(_rename_town.TEXT_EXT))         # ONE list for the rename tool and rule N1 (review F1 r2: .map, .svg, .tscn, .tres were missing from both)
SKIP_DIRS = ('_stage', 'reports', '__pycache__')             # build output BELOW a scan root: stage tree + project copy, reports, bytecode
# the whole-repo scan of N1 (review F1 r2): everything that is not the engine cache, git, a virtual env or another tool's scratch folder.  tools/features/reports is build output; the user's design
# export ("Style Guide ...") is the only place that may keep its own wording and is skipped like in rename_town.py.
REPO_SKIP_DIRS = ('.git', '.godot', '.mimocode', '.playwright-mcp', '.venv', 'node_modules', '_stage', '__pycache__')
REPO_SKIP_REL = ('tools/features/reports',)
SKIP_NAMES_CONTAINING = tuple(_rename_town.SKIP_NAMES_CONTAINING)
SHOP_OPEN_DAYS = {'flea_market': [5, 6]}                     # PLAN_FEATURES section 3: Pippins Loppemarked is open Saturday + Sunday; weekday index 0 = Monday (TimeManager.weekday_index); every other shop is open daily


def old_name_hits(root_: Path, base: Path, old_name: str = OLD_TOWN_NAME, skip_dirs: tuple = SKIP_DIRS, skip_rel: tuple = ()):
    """(paths relative to `base` of the files that contain the retired town name, Counter of the files VISITED per suffix).
    Directories named in `skip_dirs` are pruned below the scan root only: the stage tree itself lives in tools/features/_stage/<stage>/tree, so the root's own path must never decide
    (the first version tested the absolute path, skipped every file of the tree and passed on a tree full of the old name).  `skip_rel` = paths relative to the scan root that are pruned
    too (tools/features/reports for the whole-repo scan).  Files whose name contains one of SKIP_NAMES_CONTAINING (the user's design export) are not scanned and not counted."""
    hits: list = []
    seen: Counter = Counter()
    if not root_.exists():
        return hits, seen
    for dirpath, dirnames, filenames in os.walk(root_):
        rel_dir = Path(dirpath).relative_to(root_).as_posix()
        dirnames[:] = sorted(d for d in dirnames if d not in skip_dirs and (f'{rel_dir}/{d}' if rel_dir != '.' else d) not in skip_rel)
        for fn in sorted(filenames):
            fp = Path(dirpath) / fn
            suffix = fp.suffix.lower()
            if suffix not in SCAN_SUFFIXES or any(k in fn for k in SKIP_NAMES_CONTAINING):
                continue
            seen[suffix] += 1
            try:
                if old_name in fp.read_text(encoding='utf-8').lower():
                    hits.append(fp.relative_to(base).as_posix())
            except (UnicodeDecodeError, OSError):
                continue
    return hits, seen


def _as_int(v):
    """a decoded number as int when it is one (3 or 3.0), else the value unchanged"""
    return int(v) if isinstance(v, float) and v == int(v) else v


def shop_schedule_problems(shops: dict) -> list:
    """open_weekdays: a non-empty list of distinct weekday indices 0..6 (0 = Monday).  Only the flea market has opening days and they are exactly Saturday + Sunday (5, 6):
    {5, 7} names a weekday that does not exist and would close the market on Sunday without any message."""
    probs = []
    for sid, s in shops.items():
        days = s.get('open_weekdays')
        if days is None:
            if sid in SHOP_OPEN_DAYS:
                probs.append((sid, 'open_weekdays is missing: the shop would be open every day', SHOP_OPEN_DAYS[sid]))
            continue
        if not isinstance(days, list) or not days:
            probs.append((sid, 'open_weekdays must be a non-empty list of weekday indices', days))
            continue
        ints = [_as_int(d) for d in days]
        bad = [d for d in ints if isinstance(d, bool) or not isinstance(d, int) or not 0 <= d <= 6]
        if bad:
            probs.append((sid, 'weekday index outside 0..6 (0 = Monday)', bad))
            continue
        if len(set(ints)) != len(ints):
            probs.append((sid, 'open_weekdays lists a day twice', ints))
        if sid not in SHOP_OPEN_DAYS:
            probs.append((sid, 'only the flea market has opening days; this shop is open daily', ints))
        elif sorted(ints) != SHOP_OPEN_DAYS[sid]:
            probs.append((sid, 'opening days differ from the plan', ints, SHOP_OPEN_DAYS[sid]))
    return probs


def dialogue_shop_problems(shops: dict, states: list, texts: dict) -> list:
    """The `open_shop` choices of the three builder dialogues.  `states` = [(npc, label, [(action, shop_id), ...])], one entry per flag state the project interpreter evaluated;
    `texts` = {file: Lua source}.  Every state offers a shop button, and every button names a real shop whose keeper is that npc (a typo made the Materials button open nothing).
    The Lua text is scanned too, so a branch that no flag state reaches cannot hide a wrong shop id: one `shop_id = "..."` per `action = "open_shop"`, each an existing shop."""
    probs = []
    for npc, label, choices in states:
        opens = [shop for action, shop in choices if action == 'open_shop']
        if not opens:
            probs.append((npc, label, 'no open_shop choice'))
        for shop in opens:
            if shop not in shops:
                probs.append((npc, label, 'open_shop names a shop that does not exist', shop))
            elif shops[shop].get('keeper') != npc:
                probs.append((npc, label, 'the shop belongs to another keeper', shop, shops[shop].get('keeper')))
    for fname, text in sorted(texts.items()):
        n_actions = len(re.findall(r'action\s*=\s*"open_shop"', text))
        literals = re.findall(r'shop_id\s*=\s*"([^"]*)"', text)
        if n_actions != len(literals):
            probs.append((fname, 'open_shop actions and shop_id literals differ', n_actions, len(literals)))
        probs += [(fname, 'shop_id literal is not a shop', lit) for lit in sorted(set(literals)) if lit not in shops]
    return probs


def _empty_to_dict(v):
    return {} if not v else v


def map_marker_problems(markers: dict, loot: dict) -> list:
    """data/features/map_markers.json (what the map authors P11 / P19 place) must equal the loot tables, per area: chests per container id == loot.zones.<area>.containers.<id>.count,
    creatures per visit == loot.zones.<area>.creatures, unique spots == the loot.spots of that zone, the boss is placed in exactly one area that has the chest tier of the boss.
    The areas are the loot zones plus the zones of the loot spots (Hyggebyen has a spot but no zone: no chests, no creatures there).
    Since generation was retired nothing else keeps the two files together."""
    probs = []
    areas = markers.get('areas') or {}
    zones = loot['zones']
    spots_by_zone: dict = defaultdict(list)
    for spot_id, sp in loot['spots'].items():
        spots_by_zone[sp['zone']].append(spot_id)
    generated = markers.get('v') == 2
    known = ({'farm', 'hyggebyen'} if generated else set(zones) | set(spots_by_zone))
    if set(areas) != known:
        probs.append(('areas differ from loot.zones + the zones of loot.spots', sorted(set(areas) ^ known)))
    boss_area = {}
    for zid in sorted(set(areas) & known):
        a, z = areas[zid], zones.get(zid, {})
        want_c = {cid: c['count'] for cid, c in _empty_to_dict(z.get('containers')).items()}
        got_c = {cid: _as_int(n) for cid, n in _empty_to_dict(a.get('containers')).items()}
        if got_c != want_c:
            probs.append((zid, 'chests / digging spots differ from loot.zones containers', got_c, want_c))
        want_cr = {cid: _as_int(n) for cid, n in _empty_to_dict(z.get('creatures')).items()}
        got_cr = {cid: _as_int(n) for cid, n in _empty_to_dict(a.get('creatures')).items()}
        if got_cr != want_cr:
            probs.append((zid, 'creatures per visit differ from loot.zones creatures', got_cr, want_cr))
        got_sp = list(a.get('unique_spots') or [])
        if sorted(got_sp) != sorted(spots_by_zone.get(zid, [])) or len(set(got_sp)) != len(got_sp):
            probs.append((zid, 'unique spots differ from loot.spots', sorted(got_sp), sorted(spots_by_zone.get(zid, []))))
        for cid in got_c:
            if cid not in loot['containers']:
                probs.append((zid, 'container id is not in loot.containers', cid))
        for cid in got_cr:
            if cid not in loot['creatures']:
                probs.append((zid, 'creature id is not in loot.creatures', cid))
        if a.get('boss'):
            boss_area.setdefault(a['boss'], []).append(zid)
    want_boss = {} if generated else loot.get('boss') or {}
    if set(boss_area) != set(want_boss) or any(len(v) != 1 for v in boss_area.values()):
        probs.append(('bosses placed in the areas differ from loot.boss', {k: v for k, v in boss_area.items()}, sorted(want_boss)))
    for bid, b in want_boss.items():
        for zid in boss_area.get(bid, []):
            if b.get('chest') not in _empty_to_dict(zones.get(zid, {}).get('containers')):
                probs.append((bid, 'the boss chest tier is not a container of its area', zid, b.get('chest')))
    return probs


# --------------------------------------------------------------------------------------------------------------------------------------
# Rule helpers of the SECOND fix round (review F1 r2): reference and number fields that no validator looked at (every one was shown to pass 93/93 with a real defect in it).
SPOT_REQUIRES_KEYS = ('quests', 'day_min', 'home_tier_min', 'items')
HEART_CAP = 10


def spot_requirement_problems(spots: dict, quest_ids, source_quest: dict, tiers: int = 10) -> list:
    """loot.spots.<id>.requires = { quests = {..}, day_min = n, home_tier_min = n }: the keepsake is only handed out when ALL hold.  An unknown quest id makes the keepsake unobtainable for ever
    (nobody can ever complete a quest that does not exist), day_min < 1 or a tier outside 1..10 is a typo, any other key is read by nobody.  The item's own `spot` source names the quest too
    (`source_quest` = {spot id: quest or None}): both sides must say the same quest."""
    probs = []
    for sid, sp in sorted(spots.items()):
        req = sp.get('requires')
        if req is None:
            if source_quest.get(sid):
                probs.append((sid, 'the item source names a quest but the spot has no requires.quests', source_quest[sid]))
            continue
        if not isinstance(req, dict) or not req:
            probs.append((sid, 'requires must be a non-empty table', req))
            continue
        for k in sorted(set(req) - set(SPOT_REQUIRES_KEYS)):
            probs.append((sid, 'unknown requirement (unsupported by the loot service)', k))
        if 'quests' in req:
            qs = req['quests']
            if not isinstance(qs, list) or not qs or not all(isinstance(q, str) for q in qs):
                probs.append((sid, 'requires.quests must be a non-empty list of quest ids', qs))
            else:
                probs += [(sid, 'requires.quests names a quest that does not exist: the keepsake could never be found', q) for q in qs if q not in quest_ids]
                if source_quest.get(sid) not in qs:
                    probs.append((sid, 'the spot source of the item names another quest than requires.quests', source_quest.get(sid), qs))
        elif source_quest.get(sid):
            probs.append((sid, 'the item source names a quest but the spot has no requires.quests', source_quest[sid]))
        if 'day_min' in req:
            d = _as_int(req['day_min'])
            if isinstance(d, bool) or not isinstance(d, int) or d < 1:
                probs.append((sid, 'requires.day_min must be an integer >= 1', req['day_min']))
        if 'home_tier_min' in req:
            t = _as_int(req['home_tier_min'])
            if isinstance(t, bool) or not isinstance(t, int) or not 1 <= t <= tiers:
                probs.append((sid, f'requires.home_tier_min must be an integer 1..{tiers}', req['home_tier_min']))
    return probs


def quest_reference_problems(quests: dict, npcs, items) -> list:
    """quests = {quest id: {'rewards': {...}, 'objectives': [...], 'meta': {...}}}.  Every npc a quest names must exist in lua/config/npcs.lua (a reward `friendship = { fairy_kingx = 2 }` pays
    nobody and nothing says so), hearts are integers 1..10, reward items exist, the giver and every objective `npc` exist."""
    probs = []
    for qid, q in sorted(quests.items()):
        rw = q.get('rewards') or {}
        for npc, hearts in sorted((rw.get('friendship') or {}).items()):
            if npc not in npcs:
                probs.append((qid, 'rewards.friendship names an npc that does not exist', npc))
            h = _as_int(hearts)
            if isinstance(h, bool) or not isinstance(h, int) or not 1 <= h <= HEART_CAP:
                probs.append((qid, 'rewards.friendship hearts must be an integer 1..10', npc, hearts))
        for item, n in sorted((rw.get('items') or {}).items()):
            if item not in items:
                probs.append((qid, 'rewards.items names an item that does not exist', item))
            nn = _as_int(n)
            if isinstance(nn, bool) or not isinstance(nn, int) or nn < 1:
                probs.append((qid, 'rewards.items amount must be an integer >= 1', item, n))
        g = _as_int(rw.get('gold', 0))
        if isinstance(g, bool) or not isinstance(g, int) or g < 0:
            probs.append((qid, 'rewards.gold must be an integer >= 0', rw.get('gold')))
        giver = (q.get('meta') or {}).get('giver')
        if giver is not None and giver not in npcs:
            probs.append((qid, 'meta.giver is not an npc', giver))
        for o in q.get('objectives') or []:
            if o.get('npc') is not None and o['npc'] not in npcs:
                probs.append((qid, o.get('id'), 'objective names an npc that does not exist', o['npc']))
    return probs


def stack_problems(furniture: dict, materials: dict) -> list:
    """max_stack: ordinary furniture 9 (loot.duplicates and the furniture store assume it), keepsakes 1; blueprints 1, other materials 1..99.  A typo (99 on a bed, 8 on a lamp) is a balance change
    nobody decided; a missing or non-integer max_stack lets the store fall back to a default."""
    probs = []
    for iid, e in sorted(furniture.items()):
        want = 1 if e.get('rarity') in ('unique', 'legendary') else 9
        ms = _as_int(e.get('max_stack'))
        if isinstance(ms, bool) or ms != want:
            probs.append((iid, 'furniture max_stack', e.get('max_stack'), want))
    for iid, e in sorted(materials.items()):
        ms = _as_int(e.get('max_stack'))
        if isinstance(ms, bool) or not isinstance(ms, int) or not 1 <= ms <= 99 or (e.get('category') == 'blueprint' and ms != 1):
            probs.append((iid, 'material max_stack', e.get('max_stack'), 1 if e.get('category') == 'blueprint' else '1..99'))
    return probs


def decor_problems(furniture: dict) -> list:
    """decor (the hygge points of a piece) is an integer >= 1: a piece with 0 adds nothing to the room and cannot be told from a decoration bug."""
    probs = []
    for iid, e in sorted(furniture.items()):
        d = _as_int(e.get('decor'))
        if isinstance(d, bool) or not isinstance(d, int) or d < 1:
            probs.append((iid, 'decor must be an integer >= 1', e.get('decor')))
    return probs


def shop_stock_problems(shops: dict) -> list:
    """Fixed stock rows `{ stock = n, restock = n }` (ShopSystem: `stock` the most a shelf holds, `restock` the units that come back every morning, never above `stock`) and the numbers of the
    rotation rows.  A negative stock makes ShopSystem clamp silently, restock > stock is a promise the shelf cannot keep."""
    probs = []
    for sid, s in sorted(shops.items()):
        for iid, row in sorted(_empty_to_dict(s.get('stock')).items()):
            st, rs = _as_int(row.get('stock')), _as_int(row.get('restock', row.get('stock')))
            if isinstance(st, bool) or not isinstance(st, int) or st < 1:
                probs.append((sid, iid, 'stock must be an integer >= 1', row.get('stock')))
            elif isinstance(rs, bool) or not isinstance(rs, int) or rs < 0 or rs > st:
                probs.append((sid, iid, 'restock must be an integer 0..stock', row.get('restock')))
            if 'price' in row:
                pr = _as_int(row['price'])
                if isinstance(pr, bool) or not isinstance(pr, int) or pr < 0:
                    probs.append((sid, iid, 'price must be an integer >= 0', row['price']))
        for slot in s.get('rotation') or []:
            pe = _as_int(slot.get('period'))
            if isinstance(pe, bool) or not isinstance(pe, int) or pe < 1:
                probs.append((sid, slot.get('id'), 'period must be an integer >= 1', slot.get('period')))
            pm, sb = slot.get('price_mult'), slot.get('season_boost', 1)
            if isinstance(pm, bool) or not isinstance(pm, (int, float)) or pm <= 0:
                probs.append((sid, slot.get('id'), 'price_mult must be a number > 0', pm))
            if isinstance(sb, bool) or not isinstance(sb, (int, float)) or sb < 1:
                probs.append((sid, slot.get('id'), 'season_boost must be a number >= 1 (1 = no boost)', sb))
    return probs


def equip_slot_problems(equip_slots: dict) -> list:
    """wardrobe.equip_slots: `z` is the draw order above the body and must be a distinct integer per slot (two slots with the same z flicker over each other: the circlet and the hat exclude each other
    on purpose, but they still need their own layer); every slot names a loc key and a clothing slot; item_slot + subslot is unique."""
    probs = []
    seen_z, seen_key = {}, {}
    for sid, e in sorted(equip_slots.items()):
        z = _as_int(e.get('z'))
        if isinstance(z, bool) or not isinstance(z, int):
            probs.append((sid, 'z must be an integer', e.get('z')))
        elif z in seen_z:
            probs.append((sid, 'z equals the z of another slot', z, seen_z[z]))
        else:
            seen_z[z] = sid
        k = (e.get('item_slot'), e.get('subslot'))
        if k in seen_key:
            probs.append((sid, 'item_slot + subslot equals another slot', k, seen_key[k]))
        seen_key[k] = sid
        if not e.get('name_key'):
            probs.append((sid, 'name_key is missing'))
    return probs


VOICE_LINE = re.compile(r'id\s*=\s*"([^"]+)"\s*,\s*text_key\s*=\s*"([A-Z0-9_]+)"\s*,\s*voice_key\s*=\s*"([^"]*)"')


def voice_key_problems(texts: dict) -> list:
    """The voiced lines of the three feature dialogues: every spoken line (`text_key = "DLG_..."`, not a DLG_CHOICE_ button) also has a `voice_key`, the key is `voice/<speaker>/<line id>` (the file name of the voice
    clip P24 generates), the line id is the text key without its `DLG_<NPC>_` prefix in lower case, and one voice key never serves two different texts.  K5 only knew the builder."""
    probs, by_voice = [], {}
    for fname, text in sorted(texts.items()):
        speakers = [(m.start(), m.group(1)) for m in re.finditer(r'speaker\s*=\s*"([^"]+)"', text)]
        blocks = list(VOICE_LINE.finditer(text))
        n_text = len(re.findall(r'text_key\s*=\s*"DLG_(?!CHOICE_)', text))          # the spoken lines; the buttons (DLG_CHOICE_*, DIALOGUE_CHOICE_*) are not voiced
        if n_text != len(blocks):
            probs.append((fname, 'a dialogue line without voice_key (or a block that is not  id, text_key, voice_key  in this order)', n_text, len(blocks)))
        for m in blocks:
            before = [sp for pos, sp in speakers if pos < m.start()]
            line_id, text_key, voice = m.groups()
            if not before:
                probs.append((fname, line_id, 'no speaker before the line'))
                continue
            speaker = before[-1]
            if voice != f'voice/{speaker}/{line_id}':
                probs.append((fname, 'voice_key must be voice/<speaker>/<line id>', voice, f'voice/{speaker}/{line_id}'))
            want_text = f"DLG_{speaker.removeprefix('fairy_').upper()}_{line_id.upper()}"
            if text_key != want_text:
                probs.append((fname, 'the line id does not match its text key', line_id, text_key, want_text))
            by_voice.setdefault(voice, set()).add(text_key)
    probs += [(v, 'one voice key serves different texts', sorted(t)) for v, t in sorted(by_voice.items()) if len(t) > 1]
    return probs


def lua_string_literals(text: str) -> list:
    """every string literal of a Lua source, comments skipped (a `--` inside a string is part of the string)"""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '-' and text.startswith('--', i):
            j = text.find('\n', i)
            i = n if j < 0 else j
            continue
        if c in '"\'':
            j, buf = i + 1, ''
            while j < n and text[j] != c and text[j] != '\n':
                if text[j] == '\\' and j + 1 < n:
                    buf += text[j:j + 2]
                    j += 2
                    continue
                buf += text[j]
                j += 1
            out.append(buf)
            i = j + 1
            continue
        i += 1
    return out


def marker_parameters(fname, text):
    return fname == "lua/config/dungeon.lua" and re.fullmatch(r"[a-z_]+=[A-Za-z0-9_:.+-]+(?: [a-z_]+=[A-Za-z0-9_:.+-]+)*", text) is not None


def text_literal_problems(texts: dict) -> list:
    """Working rule 3: Danish / English text lives in the localization CSVs, never as a literal in code or Lua.  A text literal = a string with a space and a run of 3 letters; ids, keys,
    colours, template names and paths have no spaces.  (The quests carried ten `description = "Sæt 6 unikke ..."` copies next to their description_key: dead text nobody read.)"""
    probs = []
    for fname, text in sorted(texts.items()):
        for lit in lua_string_literals(text):
            if ' ' in lit and re.search(r'[A-Za-zæøåÆØÅ]{3}', lit) and not marker_parameters(fname, lit):
                probs.append((fname, lit))
    return probs


def creature_key_problems(creatures: dict, defined, owner_of, owner_exists):
    """loot.creatures.<id>.name_key: the name the loot feed shows for a creature.  The key is DEFINED (a CSV of the repo has the row), or its owner (tools/loc/key_owners.json) is a CSV that a later
    package has not delivered yet (a documented PENDING key: the owner is told by a handoff), else it is a defect: no owner = a typo or a key family nobody claimed; an owner that exists but has
    no row = the owner forgot it.  Returns (problems, pending [(creature id, key, owner file)])."""
    probs, pending = [], []
    for cid, c in sorted(creatures.items()):
        k = c.get('name_key')
        if not isinstance(k, str) or not re.fullmatch(r'[A-Z0-9_]+', k):
            probs.append((cid, 'name_key is not a localisation key', k))
        elif defined(k):
            continue
        else:
            ow = owner_of(k)
            if ow is None:
                probs.append((cid, k, 'no CSV owns this key in tools/loc/key_owners.json (typo, or add the key family there)'))
            elif owner_exists(ow):
                probs.append((cid, k, f'{ow} exists but has no row for it'))
            else:
                pending.append((cid, k, ow))
    return probs, pending


# --------------------------------------------------------------------------------------------------------------------------------------
def art_support(args):
    """what the art tooling supports right now: parsed from the LIVE sources of the repo (A1's tables tools/art/features/home/characters, A2's garments tools/art/features/wardrobe once it lands),
    else from the committed snapshot art_snapshot.json (written by `validate.py --refresh-snapshot`, never by a normal run).  Every source is reported by an INFO row."""
    snap_path = HERE / 'art_snapshot.json'
    snap = json.loads(snap_path.read_text(encoding='utf-8'))
    sup = {}
    live = []
    try:
        if not args.art_home or not (Path(args.art_home) / 'characters' / 'furniture_traetoppen.py').exists():
            raise FileNotFoundError('home art tables missing')
        ftp = Path(args.art_home) / 'characters' / 'furniture_traetoppen.py'
        tree = ast.parse(ftp.read_text(encoding='utf-8'))
        want = {'WOODS', 'PAINTS', 'FABRICS', 'METALS', 'CRYSTALS', 'STONES', 'TEMPLATES'}
        for n in tree.body:
            if isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name) and n.targets[0].id in want:
                sup[n.targets[0].id.lower()] = sorted(ast.literal_eval(k) for k in n.value.keys)
            if isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name) and n.targets[0].id == 'RARITY':
                sup['rarity_ladder'] = ast.literal_eval(n.value)
        hd = runpy.run_path(str(Path(args.art_home) / 'characters' / 'home_data.py'))
        sup['home'] = dict(tier_ids=[t[0] for t in hd['TIERS']], rows={str(k): v for k, v in hd['ROWS'].items()}, floor={str(k): v for k, v in hd['FLOOR'].items()},
                           wall={str(k): v for k, v in hd['WALL'].items()}, platform_stage=hd['PLATFORM_STAGE'])
        live.append(f'home art tables {Path(args.art_home).as_posix()}/characters (live)')
    except Exception as e:  # noqa: BLE001
        sup.update({k: v for k, v in snap.items() if k in ('woods', 'paints', 'fabrics', 'metals', 'crystals', 'stones', 'templates', 'rarity_ladder', 'home')})
        live.append(f'home art tables from the committed snapshot ({repr(e)[:60]})')
    try:
        wgp = Path(args.art_wardrobe) / 'characters' / 'wardrobe_garments.py' if args.art_wardrobe else None
        if not wgp or not wgp.exists():
            raise FileNotFoundError('wardrobe art tables not landed yet (A2, wave 4)')
        tree = ast.parse(wgp.read_text(encoding='utf-8'))
        garm = {}
        for n in tree.body:
            if isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name) and n.targets[0].id == 'GARMENTS':
                for k, v in zip(n.value.keys, n.value.values):
                    slot = None
                    for kw in v.keywords:
                        if kw.arg == 'slot':
                            slot = ast.literal_eval(kw.value)
                    garm[ast.literal_eval(k)] = slot
        sup['garments'] = garm
        live.append(f'wardrobe garments {wgp.as_posix()} (live)')
    except Exception as e:  # noqa: BLE001
        sup['garments'] = snap['garments']
        live.append(f'wardrobe garments from the committed snapshot until A2 lands tools/art/features/wardrobe ({str(e)[:60]})')
    sup['sources'] = live
    if args.refresh_snapshot:
        keep = {k: v for k, v in sup.items() if k != 'sources'}
        snap_path.write_text(json.dumps(keep, indent=1, ensure_ascii=False), encoding='utf-8')
    return sup


def font_coverage(args):
    """(codepoints of Alegreya Sans, codepoints of Caprasimo, label).  Live fonts when --fonts has ttf files (P07: assets/fonts), else the committed snapshot font_coverage.json
    (run-length ranges; refreshed with --refresh-snapshot).  P07 lands the fonts in the same wave as F1, so the validator must not depend on their timing."""
    snap_path = HERE / 'font_coverage.json'
    ttfs = sorted(Path(args.fonts).glob('*.ttf')) if args.fonts and Path(args.fonts).is_dir() else []
    if ttfs:
        from fontTools.ttLib import TTFont
        cps = {f.name: set(TTFont(str(f)).getBestCmap().keys()) for f in ttfs}
        body = set().union(*(v for k, v in cps.items() if k.startswith('Alegreya')))
        head = cps.get('Caprasimo-Regular.ttf', set())
        if args.refresh_snapshot and body and head:
            def runs(s):
                out, cur = [], None
                for c in sorted(s):
                    if cur and c == cur[1] + 1:
                        cur[1] = c
                    else:
                        cur = [c, c]
                        out.append(cur)
                return out
            snap_path.write_text(json.dumps({'_doc': 'codepoint ranges [first, last] of the union of the Alegreya Sans files and of Caprasimo-Regular; written by validate.py --refresh-snapshot from assets/fonts',
                                             'alegreya': runs(body), 'caprasimo': runs(head)}), encoding='utf-8')
        return body, head, f'{len(ttfs)} live ttf files in {Path(args.fonts).as_posix()}'
    snap = json.loads(snap_path.read_text(encoding='utf-8'))
    expand = lambda rr: {c for a_, b_ in rr for c in range(a_, b_ + 1)}  # noqa: E731
    return expand(snap['alegreya']), expand(snap['caprasimo']), 'the committed snapshot font_coverage.json (the OFL files of the UI spike; P07 puts them in assets/fonts)'


# --------------------------------------------------------------------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--features', required=True)
    ap.add_argument('--repo', required=True)
    ap.add_argument('--lua-dump', required=True)
    ap.add_argument('--repo-lua-dump', required=True)
    ap.add_argument('--godot-dump', required=True)
    ap.add_argument('--art-home', help='tools/art/features/home of the repo (A1): the live home art tables')
    ap.add_argument('--art-wardrobe', help='tools/art/features/wardrobe of the repo (A2, wave 4): the live wardrobe garment table; absent = committed snapshot')
    ap.add_argument('--art-python', help='python of tools/art/.venv (numpy) for the footprint probes')
    ap.add_argument('--fonts', help='directory with the Alegreya Sans / Caprasimo ttf files (P07: assets/fonts); absent = committed glyph snapshot')
    ap.add_argument('--refresh-snapshot', action='store_true', help='rewrite art_snapshot.json / font_coverage.json from the live sources (a human decision, never part of a gate)')
    ap.add_argument('--report', required=True)
    ap.add_argument('--stage', default='f1', choices=['f1', 'p13', 'p14', 'full'])
    ap.add_argument('--pending-lua-dump')
    args = ap.parse_args()
    F = Path(args.features)
    repo = Path(args.repo)

    # ---------------------------------------------------------------- load
    dump = {d['file']: d for d in json.loads(Path(args.lua_dump).read_text())}
    repo_dump = {d['file']: d for d in json.loads(Path(args.repo_lua_dump).read_text())}
    god = json.loads(Path(args.godot_dump).read_text())
    mine = sorted(p.relative_to(F).as_posix() for p in (F / 'lua').rglob('*.lua'))
    G = lambda rel, name: (dump[rel]['globals'].get(name) if rel in dump else None)  # noqa: E731

    # ---------------------------------------------------------------- S: syntax / loading
    bad = []
    for rel in mine:
        r = subprocess.run(['luac5.4', '-p', str(F / rel)], capture_output=True, text=True)
        if r.returncode:
            bad.append(f'{rel}: {r.stderr.strip()[:100]}')
    R.check('S1 luac -p (real Lua syntax) on every new Lua file', not bad, f'{len(mine)} files' if not bad else bad)
    errs = [d['file'] for d in dump.values() if d.get('error')]
    R.check('S2 real Lua evaluates every file without error', not errs and len(dump) == len(mine), f'{len(dump)} evaluated, errors: {errs}')
    R.check('S3 project LuaRuntime reload_scripts() logged no engine errors', not god['load_errors'], god['load_errors'][:3])
    kinds_ok = []
    for rel in mine:
        pf = god['files'].get(rel, {}).get('parsed', {})
        kinds_ok.append((rel, pf.get('kind')))
    R.check('S4 LuaRuntime detects a kind for every file', all(k for _, k in kinds_ok), [r for r, k in kinds_ok if not k])
    # S5 deep equality of the data tables read by the project interpreter vs real Lua
    diffs = {}
    compared = 0
    for rel in mine:
        if rel.startswith('lua/dialogue/'):
            continue
        pf = god['files'][rel]['parsed']
        for name in ('items', 'config', 'shops', 'recipes', 'rewards', 'objectives', 'meta'):
            if name in dump[rel]['globals']:
                a = norm(dump[rel]['globals'][name])
                b = norm(pf.get(name, None))
                d = deep_diff(a, b, name)
                compared += 1
                if d:
                    diffs[f'{rel}:{name}'] = d
    R.check('S5 data parsed by the project interpreter == data of real Lua 5.4 (every table of every file)', not diffs, f'{compared} tables compared' if not diffs else dict(list(diffs.items())[:3]))
    expected_items = sum(len(row['globals'].get('items', {})) for rel,row in dump.items() if rel.startswith('lua/items/'))
    R.check('S6 every new item id is registered in LuaRuntime.get_item_def', not god['items_missing_in_runtime'] and god['items_declared'] == expected_items,
            f"{god['items_declared']} declared, missing: {god['items_missing_in_runtime'][:5]}")
    R.check('S7 LuaRuntime.get_config reaches the new data (home, rarity, loot, sets)', all(v is not None for v in god['config_probe'].values()), god['config_probe'])
    qs = god['quests']
    R.check('S8 the 8 quests are registered with their rewards', all(q['registered'] for q in qs.values()) and qs['lost_cat']['repeatable'] is False, {k: (v['gold'], list(v['reward_items'])) for k, v in qs.items()})
    # end-to-end quests through QuestManager + hooks
    e2e = god['quest_e2e']
    probs = []
    for q, r in e2e.items():
        rw = qs[q]['reward_items']
        if not r['accepted'] or not r['completed'] or r['errors']:
            probs.append((q, 'accept/complete/errors', r['accepted'], r['completed'], r['errors'][:1]))
        if r['gold_delta'] != qs[q]['gold']:
            probs.append((q, 'gold', r['gold_delta'], qs[q]['gold']))
        if {k: v for k, v in r['items'].items()} != {k: int(v) for k, v in rw.items()}:
            probs.append((q, 'items', r['items'], rw))
        if r.get('extra_items'):
            probs.append((q, 'items arrived that the quest does not list', r['extra_items']))
        if q not in ('lost_cat', 'fix_roof') and r['active_flag_after_accept'] is not True:
            probs.append((q, 'on_accept hook did not set the active flag', r['active_flag_after_accept']))
        if q != 'lost_cat' and r['done_flag_after_complete'] is not True:
            probs.append((q, 'completion hook did not set the done flag', r['done_flag_after_complete']))
        if q == 'lost_cat' and r['done_flag_after_complete'] is not False:
            probs.append((q, 'lost_cat_active must be cleared'))
    R.check('S12 end to end: accept + complete all 8 quests through QuestManager and the Lua hooks -> exact gold and items arrive, flags flip, no engine errors', not probs, probs[:3] or f'{len(e2e)} quests')
    # builder dialogue behaviour
    ok_d, why = True, []
    cases = {c['label']: c for c in god['builder_dialogue']}
    exp_idle = lambda t: [f'DLG_BUILDER_T{t:02d}_IDLE'] + ([f'DLG_BUILDER_T{t:02d}_OFFER'] if t < 10 else [])  # noqa: E731
    for t in range(1, 11):
        c = cases[f'idle_{t}']
        if c['lines'] != exp_idle(t) or c['speaker'] != 'fairy_builder':
            ok_d = False; why.append(('idle', t, c['lines']))
        want_up = t < 10
        if want_up != any(x.startswith('upgrade:home_upgrade') for x in c['choices']):
            ok_d = False; why.append(('upgrade-choice', t, c['choices']))
    for t in range(2, 11):
        if cases[f'building_{t}']['lines'] != [f'DLG_BUILDER_T{t:02d}_BUILDING']:
            ok_d = False; why.append(('building', t, cases[f'building_{t}']['lines']))
        if cases[f'done_{t}']['lines'] != [f'DLG_BUILDER_T{t:02d}_DONE']:
            ok_d = False; why.append(('done', t, cases[f'done_{t}']['lines']))
    if cases['unset']['lines'] != exp_idle(1):
        ok_d = False; why.append(('unset', cases['unset']['lines']))
    R.check('S9 builder dialogue: 29 flag combinations choose the right branch in the project interpreter', ok_d, why[:3])
    # S10 (the rule itself runs below, once the shop table is loaded)
    R.check('S11 quest availability hooks evaluate (slotsdroemmen needs home_tier 10; bogtraeet needs the three math flags)',
            god['is_available_slotsdroemmen_unset'] in (False, None) and god['is_available_slotsdroemmen_t10'] is True and god['is_available_bogtraeet_unset'] in (False, None)
            and god['is_available_bogtraeet_all_done'] is True,
            [god['is_available_slotsdroemmen_unset'], god['is_available_slotsdroemmen_t10'], god['is_available_bogtraeet_unset'], god['is_available_bogtraeet_all_done']])

    # REVIEW FIX (plan-consistency 1 / coverage 1): the feature quests that gate home tiers 8-10 must be ACCEPTABLE by talking to someone
    offers = {c['label']: c for c in god['dialogue_offers']}
    want = {'oak_unset': {'snurresvampen'}, 'oak_active': set(), 'oak_done': set(), 'wiz_unset': set(), 'wiz_math_all': {'bogtraeet'}, 'wiz_active': set(), 'wiz_done': set(),
            'king_unset': {'moonstone_crown'}, 'king_tier10': {'slotsdroemmen'}, 'king_tier10_active': set(), 'king_tier10_done': set(), 'king_moon_active': set(), 'king_moon_done_tier5': set()}
    bad = []
    for lab, acc in want.items():
        got = {a for a in offers[lab]['accepts'] if a in ('snurresvampen', 'bogtraeet', 'moonstone_crown', 'slotsdroemmen')}
        if got != acc:
            bad.append((lab, sorted(got), sorted(acc)))
    via = god['accept_via_dialogue']
    bad += [(v['npc'], v['quest'], 'not accepted through its dialogue choice') for v in via if not (v['choice'] and v['accepted'] and v['active'])]
    R.check('S13 the four feature quests (snurresvampen gates tier 8, moonstone_crown tier 9, bogtraeet, slotsdroemmen = the castle finale) are offered by the dialogue of their giver at the right time only, and accepting through the choice activates them',
            not bad, bad[:4] or f'{len(via)} accepted through dialogue, {len(want)} flag states checked')

    # ---------------------------------------------------------------- data tables
    items_fur = G('lua/items/furniture.lua', 'items')
    items_clo = G('lua/items/clothing.lua', 'items')
    items_mat = G('lua/items/building_materials.lua', 'items')
    recipes = {**G('lua/recipes/furniture.lua', 'recipes'), **G('lua/recipes/materials.lua', 'recipes')}
    shops = G('lua/shops/home_shops.lua', 'shops')
    home = G('lua/data/home_tiers.lua', 'config')['home']
    loot = G('lua/data/loot_tables.lua', 'config')['loot']
    sets_cfg = G('lua/data/sets.lua', 'config')
    rar_cfg = G('lua/config/rarity.lua', 'config')
    new_items = {**items_fur, **items_clo, **items_mat}
    dungeon_items = {**G('lua/items/weapons.lua', 'items'), **G('lua/items/gems.lua', 'items'), **G('lua/items/dungeon_materials.lua', 'items')}

    # S10 (FIX ROUND): the shop buttons of the three builder dialogues open REAL shops of THEIR keeper, in every flag state the project interpreter evaluated and in every shop_id literal of the Lua text
    def _button(s):
        parts = (s.split(':', 2) + ['', '', ''])[:3]
        return parts[1], parts[2]
    states = [('fairy_builder', c['label'], [_button(x) for x in c['choices']]) for c in god['builder_dialogue']]
    states += [(s['npc'], 'dialogue', [tuple((a.split(':', 1) + [''])[:2]) for a in s['actions']]) for s in god['shopkeepers']]
    dlg_texts = {rel: (F / rel).read_text(encoding='utf-8') for rel in ('lua/dialogue/fairy_builder.lua', 'lua/dialogue/fairy_furnisher.lua', 'lua/dialogue/fairy_tailor.lua')}
    sp_ = dialogue_shop_problems(shops, states, dlg_texts)
    R.check('S10 the shop buttons of the builder / furnisher / tailor dialogues open shops that exist and belong to the speaker: every flag state offers one, every shop_id literal of the Lua text is a shop',
            not sp_, sp_[:4] or f"{len(states)} dialogue states, {sum(t.count('shop_id') for t in dlg_texts.values())} shop_id literals")

    repo_items = {}
    for rel, d in repo_dump.items():
        if rel.startswith('lua/items/') and rel not in dump and d['globals'].get('items'):      # the items of OTHER packages (F1's own files are in the stage dump)
            repo_items.update(d['globals']['items'])
    # every localisation row of the repo that is NOT one of the eight F1 files: da.csv (legacy base) and the CSVs of the other packages (core.csv, ui.csv, economy.csv, ...)
    repo_da = {}
    own_csv = {p.name for p in (F / 'localization').glob('*.csv')}
    for csv_path in sorted((repo / 'localization').glob('*.csv')):
        if csv_path.name in own_csv:
            continue
        for i, row in load_csv(csv_path)[1]:
            if row and len(row) >= 2 and re.fullmatch(r'[A-Z0-9_]+', row[0] or ''):
                repo_da.setdefault(row[0], row[1])
    loot_items = {**repo_items, **new_items, **dungeon_items}
    external_items = set(cm.ITEMS_PLAN)
    all_items = set(new_items) | set(repo_items) | external_items

    # ---------------------------------------------------------------- I: ids
    ids_all = list(items_fur) + list(items_clo) + list(items_mat)
    dups = []
    for rel, indent in (('lua/items/furniture.lua', 2), ('lua/items/clothing.lua', 2), ('lua/items/building_materials.lua', 2), ('lua/recipes/furniture.lua', 2), ('lua/recipes/materials.lua', 2),
                        ('lua/shops/home_shops.lua', 2)):
        keys = re.findall(r'^ {%d}([a-z0-9_]+) = \{' % indent, (F / rel).read_text(encoding='utf-8'), re.M)
        dups += [(rel, k) for k, n in Counter(keys).items() if n > 1]
    all_text_ids = []
    for rel in ('lua/items/furniture.lua', 'lua/items/clothing.lua', 'lua/items/building_materials.lua'):
        all_text_ids += re.findall(r'^  ([a-z0-9_]+) = \{', (F / rel).read_text(encoding='utf-8'), re.M)
    dups += [('across item files', k) for k, n in Counter(all_text_ids).items() if n > 1]
    R.check('I1 item / recipe / shop ids are unique (textual scan: Lua itself silently merges duplicate keys) and the id count equals the evaluated count', not dups and len(all_text_ids) == len(ids_all), dups[:4] or f'{len(ids_all)} ids')
    clash = sorted(set(new_items) & set(repo_items))
    R.check('I2 no new item id clashes with an existing repo item id', not clash, clash)
    R.check('I3 ids use [a-z0-9_] only', all(re.fullmatch(r'[a-z][a-z0-9_]*', i) for i in ids_all) and all(re.fullmatch(r'[a-z][a-z0-9_]*', i) for i in recipes))
    R.check('I4 recipe ids unique across both recipe files', len(recipes) == len(G('lua/recipes/furniture.lua', 'recipes')) + len(G('lua/recipes/materials.lua', 'recipes')))

    # ---------------------------------------------------------------- localisation
    loc = {}
    loc_file = {}
    csv_rows = 0
    for p in sorted((F / 'localization').glob('*.csv')):
        header, rows = load_csv(p)
        if header != ['keys', 'da', 'en']:
            R.check(f'L0 header of {p.name}', False, header)
        if not (F / 'localization' / (p.name + '.import')).exists():
            R.check(f'L0 keep-import stub for {p.name}', False)
        for ln, row in rows:
            csv_rows += 1
            if len(row) != 3:
                R.check(f'L1 {p.name}:{ln} has 3 columns', False, row)
                continue
            k, da, en = row
            if k in loc:
                R.check(f'L2 duplicate key {k}', False, f'{p.name} and {loc_file[k]}')
            loc[k] = (da, en)
            loc_file[k] = p.name
    R.check('L1 every CSV row has exactly three columns and a keep-import stub exists', True, f'{csv_rows} rows in {len(list((F / "localization").glob("*.csv")))} files')
    R.check('L2 no duplicate loc key inside the new CSV files', len(loc) == csv_rows, f'{len(loc)} unique of {csv_rows}')
    dup_repo = sorted(set(loc) & set(repo_da))
    R.check('L3 no loc key of the eight F1 files collides with a key of any other CSV of the repo (da.csv legacy base, core.csv, ui.csv, ...)', not dup_repo, dup_repo[:8])
    R.check('L4 keys match ^[A-Z0-9_]+$', all(re.fullmatch(r'[A-Z0-9_]+', k) for k in loc))
    gcsv = god.get('csv', {})
    pycount = {p.name: sum(1 for _ in load_csv(p)[1]) for p in (F / 'localization').glob('*.csv')}
    R.check('L5 the engine\'s own FileAccess.get_csv_line reads every new CSV with the same row count, three non-empty columns and unique keys',
            gcsv and all(gcsv.get(n, {}).get('rows') == c and gcsv[n]['bad'] == 0 and gcsv[n]['unique'] == c for n, c in pycount.items()), {n: gcsv.get(n) for n in list(pycount)[:2]})
    have_key = lambda k: k in loc or k in repo_da  # noqa: E731


    # ---------------------------------------------------------------- Lua dialect lint (what PLAN P10 will reject) + top-level key collisions
    def code_only(text):
        outl = []
        for line in text.split('\n'):
            res, i, q = '', 0, None
            while i < len(line):
                c = line[i]
                if q:
                    if c == q:
                        q = None
                    i += 1
                    continue
                if c in '"\'':
                    q = c; i += 1; continue
                if c == '-' and line[i:i + 2] == '--':
                    break
                res += c; i += 1
            outl.append(res)
        return '\n'.join(outl)
    lintbad = []
    origins = {}
    if (F / '_stage.json').exists():
        origins = {k: v['origin'] for k, v in json.loads((F / '_stage.json').read_text(encoding='utf-8'))['files'].items()}
    real_files = sorted(rel for rel in mine if origins.get(rel) == 'real')      # P13's / P14's own rewrites (stage >= p13): their gate runs tools/lua/lint.gd, this regex lint is for the files F1 keeps
    pat = re.compile(r'\belse\b|\belseif\b|\bfor\b|\bwhile\b|\brepeat\b|\[\[|\blocal\s+function\b|\bfunction\s+\w+[.:]|#|\bstring\.|\bmath\.|\btable\.|\\|\.\.|\bnil\b')
    for rel in mine:
        if rel in real_files:
            continue
        code = code_only((F / rel).read_text(encoding='utf-8'))
        for m in pat.finditer(code):
            lintbad.append((rel, m.group(0), code[max(0, m.start() - 20):m.end() + 20].replace('\n', ' ')))
        # arithmetic in statements: + - * / % outside strings (negative number literals and ranges are fine)
        for ln in code.split('\n'):
            if re.search(r'[A-Za-z_)\]]\s*[+*/%]\s*[A-Za-z_(\d]|[A-Za-z_)\]]\s-\s[A-Za-z_(\d]', ln):
                lintbad.append((rel, 'arithmetic', ln.strip()[:60]))
    R.check('L6 P10 lint: no else/elseif/for/while/repeat/[[ ]]/local function/function M./#/string./math./table./escaped quotes/concat/arithmetic/nil outside strings in any Lua file of this package or its pending references',
            not lintbad, lintbad[:3] or (f'{len(mine) - len(real_files)} files' + (f'; {len(real_files)} real files of P13/P14 are linted by their own gate (tools/lua/lint.gd)' if real_files else '')))
    top = Counter()
    for rel in mine:
        if rel.startswith(('lua/data/', 'lua/config/')):
            for k in G(rel, 'config') or {}:
                top[k] += 1
    plan_keys = {'player', 'farm', 'crops', 'economy', 'adventure', 'time', 'ui', 'race_perks', 'combat', 'npcs', 'characters', 'props', 'props_extra', 'ambient', 'enemies', 'resource_nodes'}
    repo_cfg = {k for rel, d in repo_dump.items() if rel not in dump for k in (d['globals'].get('config') or {})}      # the config keys the other packages really define
    R.check('L7 top-level config keys of the new files are unique and collide neither with the PLAN keys nor with a config key that another file of the repo defines', all(v == 1 for v in top.values()) and not (set(top) & (plan_keys | repo_cfg)),
            dict(top) if not (set(top) & repo_cfg) else sorted(set(top) & repo_cfg))
    plan_items = {'scarecrow', 'lantern_post', 'fence', 'mushroom_lantern', 'honey_cake', 'pickaxe_copper', 'scythe', 'fishing_rod', 'iron_ingot', 'health_tonic', 'lantern_oil', 'fertilizer', 'fairy_dust_water',
                  'gem_bag', 'egg', 'duck_egg', 'milk', 'magic_herb', 'lucky_fur', 'wisdom_feather', 'flour', 'honey', 'apple', 'strawberry', 'strawberry_seeds', 'sunflower', 'sunflower_seeds', 'catnip', 'catnip_seeds', 'wild_flower', 'glow_mushroom', 'crystal_shard'}
    R.check('L8 no new item id collides with an item id the PLAN gives to P12 (so the packages can merge)', not (set(new_items) & plan_items), sorted(set(new_items) & plan_items))

    # ---------------------------------------------------------------- art support
    sup = art_support(args)
    R.info('art support read from', '; '.join(sup['sources']))

    # ---------------------------------------------------------------- C: catalog shape
    rar_f = Counter(e['rarity'] for e in items_fur.values())
    want_f = dict(normal=45, uncommon=33, rare=24, unique=17, legendary=11)
    R.check('C1 furniture: >= 130 items and rarity split 45/33/24/17/11', len(items_fur) >= 130 and dict(rar_f) == want_f, dict(rar_f))
    cat_tbl = defaultdict(Counter)
    for e in items_fur.values():
        cat_tbl[e['furniture_type']][e['rarity']] += 1
    R.info('furniture rarity x furniture_type', {c: [v[r] for r in RARITIES] + [sum(v.values())] for c, v in sorted(cat_tbl.items())})
    rar_c = Counter(e['rarity'] for e in items_clo.values())
    slot_c = Counter(e['slot'] for e in items_clo.values())
    want_slots = dict(hat=18, shirt=15, pants=14, dress=14, shoes=15, jewellery=20)
    R.check('C2 clothing: >= 96 items, slot counts 18/15/14/14/15/20', len(items_clo) >= 96 and dict(slot_c) == want_slots, dict(slot_c))
    R.check('C3 clothing rarity split 33/24/18/13/8 (same ladder as furniture)', dict(rar_c) == dict(normal=33, uncommon=24, rare=18, unique=13, legendary=8), dict(rar_c))
    slot_tbl = defaultdict(Counter)
    for e in items_clo.values():
        slot_tbl[e['slot']][e['rarity']] += 1
    R.info('clothing rarity x slot', {c: [v[r] for r in RARITIES] + [sum(v.values())] for c, v in sorted(slot_tbl.items())})
    sub_c = Counter(e.get('subslot') for e in items_clo.values() if e['slot'] == 'jewellery')
    R.check('C3b jewellery subslots (circlet/necklace/bracelet/earrings) all present', set(sub_c) == {'circlet', 'necklace', 'bracelet', 'earrings'}, dict(sub_c))
    # required fields
    need_f = ['name_key', 'description_key', 'category', 'furniture_type', 'rarity', 'buy_price', 'sell_price', 'worth', 'decor', 'footprint', 'placement', 'art', 'acquire', 'sources']
    need_c = ['name_key', 'description_key', 'category', 'slot', 'rarity', 'buy_price', 'sell_price', 'worth', 'art', 'acquire', 'sources', 'wearable']
    miss = [(i, k) for i, e in items_fur.items() for k in need_f if k not in e] + [(i, k) for i, e in items_clo.items() for k in need_c if k not in e]
    R.check('C4 every furniture/clothing item has all required fields', not miss, miss[:5])
    # art contract: furniture
    T = set(sup['templates'])
    badt, badm, badkw, badtier = [], [], [], []
    kwvalid = {'bed': ('size', {'single', 'double'}), 'table': ('size', {'round', 'dining', 'long'}), 'sofa': ('seats', {2, 3}), 'wardrobe': ('size', {'wide', 'narrow'}),
               'bookshelf': ('size', {'wide', 'narrow'}), 'rug': ('shape', {'rect', 'round', 'runner'}), 'painting': ('size', {'small', 'wide'})}
    for i, e in items_fur.items():
        a = e['art']
        if a['template'] not in T:
            badt.append((i, a['template']))
        if a['material'] not in set(sup['woods']) | set(sup['stones']):
            badm.append((i, 'material', a['material']))
        for k, sk in (('paint', 'paints'), ('fabric', 'fabrics'), ('metal', 'metals'), ('crystal', 'crystals'), ('stone', 'stones')):
            if k in a and a[k] not in sup[sk]:
                badm.append((i, k, a[k]))
        kw = kwvalid.get(a['template'])
        if kw and a.get(kw[0]) not in kw[1]:
            badkw.append((i, a))
        if not kw and any(k in a for k in ('size', 'seats', 'shape')):
            badkw.append((i, 'unexpected kw'))
        if a['tier'] != RARITIES.index(e['rarity']):
            badtier.append((i, a['tier'], e['rarity']))
    R.check('C5 every furniture art template is a template the home art tables bake (A1)', not badt, f'{len(T)} templates supported; bad: {badt[:4]}')
    R.check('C6 every furniture material / paint / fabric / metal / crystal / stone id exists in the art palettes (A1)', not badm, badm[:5])
    R.check('C7 template kwargs (size/seats/shape) valid; art tier == rarity ladder position', not badkw and not badtier, (badkw + badtier)[:4])
    # art contract: clothing
    gar = sup['garments']
    badl, badslot, badfb, badpal = [], [], [], []
    for i, e in items_clo.items():
        a = e['art']
        if a['status'] == 'existing':
            if a['layer'] not in gar:
                badl.append((i, a['layer']))
            elif gar[a['layer']] != a['slot']:
                badslot.append((i, a['layer'], gar[a['layer']], a['slot']))
        else:
            if a['fallback'] not in gar:
                badfb.append((i, a['fallback']))
            elif gar[a['fallback']] != a['slot']:
                badslot.append((i, 'fallback', a['fallback'], a['slot']))
        if not (isinstance(a['palette'], list) and len(a['palette']) == 3 and all(re.fullmatch(r'[0-9A-Fa-f]{6}', c) for c in a['palette'])):
            badpal.append(i)
        top = e['slot']
        okslot = {'hat': ('hat',), 'shirt': ('shirt',), 'pants': ('pants',), 'dress': ('dress',), 'shoes': ('shoes',), 'jewellery': ('circlet', 'necklace', 'bracelet', 'earrings')}[top]
        if a['slot'] not in okslot:
            badslot.append((i, 'item slot vs art slot', top, a['slot']))
        if top == 'jewellery' and a['slot'] != e.get('subslot'):
            badslot.append((i, 'subslot', e.get('subslot'), a['slot']))
    n_req = sum(1 for e in items_clo.values() if e['art']['status'] == 'requested')
    R.check('C8 clothing art: existing layers are garments of the wardrobe art with the same slot; requested layers have a working fallback', not badl and not badfb and not badslot,
            f'{len(items_clo) - n_req} existing-design items, {n_req} requested-design items; problems: {(badl + badfb + badslot)[:4]}')
    R.check('C9 clothing palettes are three 6-digit hex colours', not badpal, badpal[:4])
    import src_clothing as _sc
    badcol = [(i, e['art'].get('colors'), e['art'].get('pattern')) for i, e in items_clo.items()
              if len(e['art'].get('colors', [])) != 3 or any(c not in set(_sc.COLOR_IDS.values()) for c in e['art']['colors'])
              or [_sc.COLOR_IDS[h.upper()] for h in e['art']['palette']] != e['art']['colors'] or e['art'].get('pattern') not in set(_sc.PATTERN_OF.values())]
    R.check('C9c clothing art.colors / art.pattern ids exist and match the palette hex values', not badcol, badcol[:3])
    req_json = json.loads((F / 'data' / 'wardrobe_design_requests.json').read_text())['designs']
    used_req = {e['art']['layer'] for e in items_clo.values() if e['art']['status'] == 'requested'}
    R.check('C9b data/wardrobe_design_requests.json lists exactly the requested designs the catalogue uses', set(req_json) == used_req, f'{len(req_json)} requested designs')
    # footprints vs real spike geometry
    if args.art_python and args.art_home and Path(args.art_python).exists():
        try:
            pr = subprocess.run([args.art_python, '-I', str(HERE / 'probe_footprints.py'), str(Path(args.art_home))], capture_output=True, text=True, timeout=300)
            probe = json.loads(pr.stdout)
            mism = []
            for i, e in items_fur.items():
                a = e['art']
                kwd = {k: a[k] for k in ('size', 'seats', 'shape') if k in a}
                key = f"{a['template']}|{json.dumps(kwd, sort_keys=True)}|{a['tier']}"
                fp, layer, inter = probe[key]
                if list(e['footprint']) != fp or e['placement'] != layer or (e.get('interact') or None) != inter:
                    mism.append((i, e['footprint'], fp, e['placement'], layer, e.get('interact'), inter))
            R.check('C10 footprint / placement layer / interaction of every furniture item == what the art spike template function reports', not mism, f'{len(items_fur)} items probed; {mism[:3]}')
            pr2 = subprocess.run([args.art_python, '-I', str(HERE / 'probe_items.py'), str(Path(args.art_home)), str(F / 'data' / 'furniture_art_spec.json')], capture_output=True, text=True, timeout=600)
            built = json.loads(pr2.stdout)
            badb = [(i, v[4]) for i, v in built.items() if v[4]] + [(i, v[0], items_fur[i]['footprint']) for i, v in built.items() if not v[4] and v[0] != list(items_fur[i]['footprint'])]
            R.check('C10b every furniture item BUILDS with the art spike\'s real template function and its own Style (data/furniture_art_spec.json) and yields the footprint stored in the Lua', not badb and len(built) == len(items_fur),
                    f'{len(built)} items built; {badb[:3]}')
            gl = sum(v[3] for v in built.values())
            R.info('items with a glow layer in the spike build', f'{gl} of {len(built)} (legendary tier + lamps)')
        except Exception as ex:  # noqa: BLE001
            R.check('C10 footprint probe runs (art python + A1 tables)', False, repr(ex)[:150] + ' | ' + (pr.stderr[-200:] if 'pr' in dir() else ''))
    else:
        R.check('C10 footprint probe runs (art python + A1 tables)', False, 'no tools/art/.venv python or no tools/art/features/home: run tools/art/setup_env.sh')

    # ---------------------------------------------------------------- C: prices
    def monotone(items, groupkey, label):
        groups = defaultdict(lambda: defaultdict(list))
        for i, e in items.items():
            groups[groupkey(e)][e['rarity']].append(e['worth'])
        viol = []
        for g, byr in groups.items():
            prev = None
            for r in RARITIES:
                if r in byr:
                    if prev and min(byr[r]) <= max(prev[1]):
                        viol.append((g, prev[0], max(prev[1]), r, min(byr[r])))
                    prev = (r, byr[r])
        return viol
    v1 = monotone(items_fur, lambda e: e['art']['template'], 'furniture')
    v2 = monotone(items_clo, lambda e: e['art']['slot'], 'clothing')
    R.check('C11 price monotonicity: within every furniture template and every clothing art slot, the cheapest item of a higher rarity costs more than the dearest of the lower', not v1 and not v2, (v1 + v2)[:4])
    for nm, items in (('furniture', items_fur), ('clothing', items_clo)):
        means = [sum(e['worth'] for e in items.values() if e['rarity'] == r) / sum(1 for e in items.values() if e['rarity'] == r) for r in RARITIES]
        R.check(f'C12 mean worth strictly increases with rarity ({nm})', all(a < b for a, b in zip(means, means[1:])), [round(m) for m in means])
    badp = []
    for i, e in {**items_fur, **items_clo}.items():
        r = e['rarity']
        if r in ('normal', 'uncommon', 'rare'):
            if not (e['buy_price'] == e['worth'] and 0 < e['sell_price'] < e['buy_price']):
                badp.append((i, e['buy_price'], e['sell_price'], e['worth']))
        else:
            if not (e['buy_price'] == 0 and e['sell_price'] == 0 and e.get('protected') is True):
                badp.append((i, 'keepsake must have buy 0 / sell 0 / protected', e['buy_price'], e['sell_price']))
    R.check('C13 normal/uncommon/rare: buy == worth and 0 < sell < buy; unique/legendary: buy 0, sell 0, protected keepsakes', not badp, badp[:4])
    sell_ratio = {r: sorted({round(e['sell_price'] / e['buy_price'], 2) for e in {**items_fur, **items_clo}.values() if e['rarity'] == r and e['buy_price']}) for r in ('normal', 'uncommon', 'rare')}
    R.info('sell/buy ratio ranges (rounded to 5 gold)', {r: (v[0], v[-1]) for r, v in sell_ratio.items()})
    dmeans = [sum(e['decor'] for e in items_fur.values() if e['rarity'] == r) / sum(1 for e in items_fur.values() if e['rarity'] == r) for r in RARITIES]
    R.check('C14 decor score mean strictly increases with rarity', all(a < b for a, b in zip(dmeans, dmeans[1:])), [round(m, 1) for m in dmeans])
    sp_ = stack_problems(items_fur, items_mat)
    R.check('C19 max_stack: furniture 9 (keepsakes 1: loot.duplicates and the furniture store assume it), blueprints 1, other materials 1..99', not sp_, sp_[:4] or f'{len(items_fur)} furniture, {len(items_mat)} materials')
    dp_ = decor_problems(items_fur)
    R.check('C20 every furniture piece has decor >= 1 (integer hygge points), legendary pieces too', not dp_, dp_[:4] or f'{len(items_fur)} pieces, decor {min(e["decor"] for e in items_fur.values())}..{max(e["decor"] for e in items_fur.values())}')

    # ---------------------------------------------------------------- sets
    fsets, wsets = sets_cfg['furniture_sets'], sets_cfg['wardrobe_sets']
    probs = []
    for kind, S, items in (('furniture', fsets, items_fur), ('wardrobe', wsets, items_clo)):
        used = Counter(e['set'] for e in items.values() if 'set' in e)
        for sid in used:
            if sid not in S:
                probs.append((kind, 'item uses undefined set', sid))
        for sid, s in S.items():
            mem = s['members']
            if len(mem) < 4:
                probs.append((kind, 'set smaller than 4', sid, len(mem)))
            for m in mem:
                if m not in items or items[m].get('set') != sid:
                    probs.append((kind, 'member not tagged', sid, m))
            if sorted(mem) != sorted(i for i, e in items.items() if e.get('set') == sid):
                probs.append((kind, 'member list differs from items', sid))
            pcs = [b['pieces'] for b in s['bonuses']]
            if pcs != sorted(set(pcs)) or max(pcs) > len(mem):
                probs.append((kind, 'bonus pieces', sid, pcs, len(mem)))
            for b in s['bonuses']:
                for k in b:
                    if k != 'pieces' and k not in cm.PERKS:
                        probs.append((kind, 'unknown perk', sid, k))
            for key in (s['name_key'], s['description_key']):
                if key not in loc:
                    probs.append((kind, 'missing loc', key))
            cap = s.get('capstone')
            if cap:
                if cap not in mem or items[cap]['rarity'] != 'legendary':
                    probs.append((kind, 'capstone must be a legendary member', sid, cap))
                if not any(s2['kind'] == 'set_reward' and s2['set'] == sid for s2 in items[cap]['sources']):
                    probs.append((kind, 'capstone lacks set_reward source', sid))
    R.check('C15 sets: no orphan sets, every set has >= 4 members, members/bonuses/perk keys/loc keys/capstones consistent', not probs, probs[:5])
    R.check('C15b 10 furniture sets and 7 wardrobe sets', len(fsets) == 10 and len(wsets) == 7, (len(fsets), len(wsets)))
    R.info('set sizes', {**{f'F:{k}': len(v['members']) for k, v in fsets.items()}, **{f'W:{k}': len(v['members']) for k, v in wsets.items()}})

    # ---------------------------------------------------------------- perks
    badperk = []
    per_sub = defaultdict(lambda: defaultdict(float))
    for i, e in items_clo.items():
        pk = e.get('perks', {})
        if e['rarity'] == 'normal' and pk:
            badperk.append((i, 'normal must have no perks'))
        if e['rarity'] in ('uncommon', 'rare', 'unique', 'legendary') and not pk:
            badperk.append((i, 'missing perks'))
        n = len(pk)
        if e['rarity'] == 'uncommon' and n != 1:
            badperk.append((i, 'uncommon: exactly 1 perk'))
        if e['rarity'] == 'unique' and n != 2:
            badperk.append((i, 'unique: exactly 2 perks'))
        if e['rarity'] == 'legendary' and n != 2:
            badperk.append((i, 'legendary: exactly 2 perks'))
        for k, v in pk.items():
            if k not in cm.PERKS:
                badperk.append((i, 'unknown perk', k))
            per_sub[e.get('subslot') or e['slot']][k] = max(per_sub[e.get('subslot') or e['slot']][k], v)
    R.check('C16 clothing perks follow the rarity ladder (none / 1 / 1-2 / 2 / 2) and use only speed, energy, luck, discount', not badperk, badperk[:4])
    caps = rar_cfg['perk_caps']
    # best-in-slot sum: one hat or circlet, shirt + pants (or dress), shoes, necklace, bracelet, earrings
    best = {}
    for k in cm.PERKS:
        sl = {s: per_sub[s][k] for s in per_sub}
        body = max(sl['shirt'] + sl['pants'], sl['dress'])
        best[k] = round(max(sl['hat'], sl['circlet']) + body + sl['shoes'] + sl['necklace'] + sl['bracelet'] + sl['earrings'], 4)
    R.info('best-in-slot perk sum without sets (one of each worn slot)', best)
    over = {k: (best[k], caps[k]) for k in cm.PERKS if best[k] > caps[k] * 1.5}
    R.check('C17 perk sums stay inside 150 percent of the caps even with the best piece in every slot (the engine clamps to the cap)', not over, over)
    R.check('C17b perk_caps in lua/config/rarity.lua match the design (speed .15, energy 20, luck .20, discount .15, energy_total 60, discount_total .20)',
            caps == dict(speed=0.15, energy=20, luck=0.2, discount=0.15, energy_total=60, discount_total=0.2), caps)
    set_max = defaultdict(float)
    for S in (fsets, wsets):
        for s in S.values():
            top = s['bonuses'][-1]
            for k, v in top.items():
                if k != 'pieces':
                    set_max[k] += v
    R.info('sum of the top bonus of ALL sets (never reachable at once; engine clamps)', {k: round(v, 3) for k, v in set_max.items()})

    cov = {}
    emptyacq = [i for i, e in {**items_fur, **items_clo, **items_mat}.items() if not e['acquire']]
    for nm, items in (('furniture', items_fur), ('clothing', items_clo)):
        for r in RARITIES:
            sel = [e for e in items.values() if e['rarity'] == r]
            cov[f'{nm}/{r}'] = {k: sum(1 for e in sel if k in e['acquire']) for k in ('buy', 'build', 'find', 'reward')} | {'items': len(sel)}
    wrong = [k for k, v in cov.items() if k.split('/')[1] in ('normal', 'uncommon', 'rare') and (v['buy'] == 0 or v['find'] != v['items'])]
    R.check('C18 every item has an acquire route; every normal/uncommon/rare furniture and clothing item can be FOUND, and each family can be bought', not emptyacq and not wrong, emptyacq[:3] or cov)
    R.info('acquire coverage (buy/build/find/reward per rarity)', cov)

    # Dungeon contracts include the three new item categories and live generator.
    import dungeon_rules
    evaluated = {rel: row["globals"] for rel, row in repo_dump.items()}
    evaluated.update({rel: row["globals"] for rel, row in dump.items()})
    for name, problems in dungeon_rules.validate(evaluated).items():
        R.check(name, not problems, problems[:5])

    # ---------------------------------------------------------------- sources <-> loot / shops / recipes
    areas = set(cm.AREAS)                   # the area ids of PLAN 4.0; the fairy town is the area `hyggebyen` (rule N1 proves nothing else is left)
    zones = loot['zones']
    probs = []
    pool_items = defaultdict(set)         # item -> zones
    for z, zd in zones.items():
        if z not in areas:
            probs.append(('unknown zone', z))
        for kind, kp in zd['pools'].items():
            for rar, lst in kp.items():
                for ent in lst:
                    pool_items[ent['item']].add(z)
                    if ent['item'] not in loot_items:
                        probs.append(('pool item unknown', z, ent['item']))
                    elif loot_items[ent['item']]['rarity'] != rar:
                        probs.append(('pool rarity mismatch', z, ent['item'], rar))
                    if not (isinstance(ent['w'], int) and ent['w'] > 0):
                        probs.append(('weight', z, ent))
    R.check('R1 loot pools reference existing items in the right rarity slot with positive integer weights', not probs, probs[:4])
    # find sources <-> pools (both directions)
    mism = []
    for i, e in new_items.items():
        fz = {s['zone'] for s in e['sources'] if s['kind'] == 'find' and 'container' not in s}
        if e['rarity'] in ('normal', 'uncommon', 'rare'):
            if fz != pool_items.get(i, set()):
                mism.append((i, sorted(fz), sorted(pool_items.get(i, []))))
        elif pool_items.get(i):
            mism.append((i, 'keepsake in a random pool'))
    R.check('R2 every `find` source of an item == the zones whose loot pools contain it (and vice versa)', not mism, mism[:4])
    # unique / legendary source integrity
    spots, gifts = loot['spots'], loot['gifts']
    tgs, srs, qrs, boss = loot['tier_gifts'], loot['set_rewards'], loot['quest_rewards'], loot['boss']['snurresvamp']
    wand = {(w['item'], z, w['container']) for z, zd in zones.items() for w in zd.get('wanderers', [])}
    probs = []
    qfiles = {q for q in cm.QUESTS_REPO + cm.QUESTS_PLAN_NEW + cm.QUESTS_NEW}
    for i, e in {**items_fur, **items_clo}.items():
        if e['rarity'] not in ('unique', 'legendary'):
            continue
        ks = [s for s in e['sources'] if s['kind'] not in ('shop',)]
        if not ks:
            probs.append((i, 'no source'))
        if any(s['kind'] in ('shop', 'craft') for s in e['sources']):
            probs.append((i, 'keepsake sold/crafted'))
        for s in ks:
            k = s['kind']
            if k == 'spot':
                sp = spots.get(s['spot'])
                if not sp or sp['item'] != i or sp['zone'] != s['zone']:
                    probs.append((i, 'spot', s))
            elif k == 'gift':
                if not any(g['npc'] == s['npc'] and g['hearts'] == s['hearts'] and g['item'] == i for g in gifts) or s['npc'] not in cm.NPCS:
                    probs.append((i, 'gift', s))
            elif k == 'tier_gift':
                if not any(t['tier'] == s['tier'] and t['item'] == i for t in tgs):
                    probs.append((i, 'tier_gift', s))
            elif k == 'quest':
                if s['quest'] not in qfiles or i not in qrs.get(s['quest'], []):
                    probs.append((i, 'quest', s))
            elif k == 'set_reward':
                if not any(x['set'] == s['set'] and x['item'] == i for x in srs):
                    probs.append((i, 'set_reward', s))
            elif k == 'boss':
                inpool = i in boss['pool']
                first = i == 'hat_mushroom_spinner'
                if not (inpool or first):
                    probs.append((i, 'boss', s))
            elif k == 'find':
                if (i, s['zone'], s['container']) not in wand:
                    probs.append((i, 'wanderer', s))
            else:
                probs.append((i, 'unknown source kind', k))
    # reverse
    for sid, sp in spots.items():
        e = loot_items.get(sp['item'])
        if not e or not any(s['kind'] == 'spot' and s['spot'] == sid for s in e['sources']):
            probs.append(('spot without item source', sid))
        if sp['zone'] not in areas:
            probs.append(('spot zone', sid, sp['zone']))
    for g in gifts:
        if g['item'] not in new_items or g['npc'] not in cm.NPCS:
            probs.append(('gift', g))
    for t in tgs:
        if t['item'] not in new_items or not (5 <= t['tier'] <= 10):
            probs.append(('tier gift', t))
        if t['item'] not in (home['tiers'][t['tier'] - 1].get('gift_items') or []):
            probs.append(('tier gift missing in home_tiers', t))
    for q, its in qrs.items():
        qf = G(f'lua/quests/{q}.lua', 'rewards')
        if not qf:
            probs.append(('quest file missing', q)); continue
        for i in its:
            if i not in qf['items']:
                probs.append(('quest reward not in quest file', q, i))
    for i in boss['pool']:
        if i not in new_items or new_items[i]['rarity'] != 'legendary':
            probs.append(('boss pool', i))
    R.check('R3 every unique/legendary item has a valid fixed source (spot / gift / tier gift / quest / set reward / boss / wanderer) and every fixed source points back', not probs, probs[:5])
    # R21 (review F1 r2): the `requires` of a loot spot.  The quest ids are the quest FILES that exist (stage tree + repo), not a hand-kept list
    quest_ids = {Path(rel).stem for rel in mine if rel.startswith('lua/quests/')} | {Path(rel).stem for rel in repo_dump if rel.startswith('lua/quests/')}
    source_quest = {s_['spot']: s_.get('quest') for e in {**items_fur, **items_clo}.values() for s_ in e['sources'] if s_['kind'] == 'spot'}
    spr = spot_requirement_problems(spots, quest_ids, source_quest)
    R.check('R21 loot spot requirements: requires.quests name quest files that exist and match the quest of the item\'s spot source, day_min >= 1, home_tier_min 1..10, no unknown key',
            not spr, spr[:4] or f"{sum(1 for sp in spots.values() if sp.get('requires'))} of {len(spots)} spots have requirements, {len(quest_ids)} quest files known")
    # counts of source kinds for unique / legendary
    cnt = defaultdict(Counter)
    for i, e in {**items_fur, **items_clo}.items():
        if e['rarity'] in ('unique', 'legendary'):
            cnt[e['rarity']][e['sources'][0]['kind'] if e['sources'] else 'none'] += 1
    R.info('primary source kind of unique / legendary items', {k: dict(v) for k, v in cnt.items()})

    # recipes
    probs = []
    price = {i: (e['buy_price'], e['sell_price']) for i, e in {**new_items, **repo_items}.items()}
    ext_price = {'copper_ore': (35, 14), 'moonstone': (440, 220), 'wool': (30, 12)}
    price.update(ext_price)
    blueprint_flags = {i: e['unlock_flag'] for i, e in items_mat.items() if e.get('category') == 'blueprint'}
    for rid, r in recipes.items():
        out_item = r['output']['item']
        if out_item not in new_items:
            probs.append((rid, 'output unknown', out_item))
        for ing, n in r['ingredients'].items():
            if ing not in all_items or ing not in price:
                probs.append((rid, 'ingredient unknown', ing))
            if not isinstance(n, int) or n < 1:
                probs.append((rid, 'qty', ing))
        if r['station'] not in ('snedkerbord', 'vaev', 'smedje') or not (1 <= r['min_home_tier'] <= 10):
            probs.append((rid, 'station/tier'))
        if r.get('unlock_flag') and r['unlock_flag'] not in blueprint_flags.values():
            probs.append((rid, 'unlock_flag without blueprint', r['unlock_flag']))
        if not have_key(r['name_key']):
            probs.append((rid, 'name_key', r['name_key']))
    R.check('R4 recipes: outputs/ingredients exist, stations valid, unlock flags belong to a blueprint, names resolve', not probs, probs[:5])
    # item <-> recipe mirror
    probs = []
    for i, e in items_fur.items():
        craft = [s for s in e['sources'] if s['kind'] == 'craft']
        if bool(craft) != bool(e.get('recipe')):
            probs.append((i, 'craft source vs inline recipe'))
        if craft:
            rr = recipes.get(craft[0]['recipe'])
            if not rr or rr['output']['item'] != i or rr['ingredients'] != e['recipe']['ingredients'] or rr['station'] != e['recipe']['station']:
                probs.append((i, 'recipe mismatch'))
            if e['rarity'] == 'rare' and not (e['recipe'].get('unlock_flag') and rr.get('unlock_flag') == e['recipe']['unlock_flag']):
                probs.append((i, 'rare recipe needs blueprint'))
            if e['rarity'] != 'rare' and e['recipe'].get('unlock_flag'):
                probs.append((i, 'non-rare recipe with blueprint'))
        if e['rarity'] in ('unique', 'legendary') and craft:
            probs.append((i, 'keepsake craftable'))
    for i, e in items_mat.items():
        for s in e['sources']:
            if s['kind'] == 'craft':
                rr = recipes.get(s['recipe'])
                if not rr or rr['output']['item'] != i:
                    probs.append((i, 'material recipe'))
    R.check('R5 item.recipe / sources.craft mirror lua/recipes exactly (ingredients, station, blueprint flag)', not probs, probs[:5])
    # economy of recipes
    probs, ratios = [], []
    for rid, r in recipes.items():
        out_item = r['output']['item']
        cost = sum(price[k][0] * n for k, n in r['ingredients'].items())
        outv = new_items[out_item]
        if rid.startswith('build_'):
            ratio = cost / outv['buy_price']
            ratios.append(ratio)
            if not (outv['sell_price'] < cost < outv['buy_price']) or not (0.45 <= ratio <= 0.87):
                probs.append((rid, 'cost', cost, 'sell', outv['sell_price'], 'buy', outv['buy_price'], round(ratio, 2)))
        else:
            val_out = outv['sell_price'] * r['output']['amount']
            buyable = all(k in items_mat and items_mat[k]['sources'] and any(s['kind'] == 'shop' for s in items_mat[k]['sources']) or k in ('wood', 'stone', 'moss') for k in r['ingredients'])
            if buyable and val_out >= cost:
                probs.append((rid, 'money loop', val_out, cost))
            if outv['buy_price'] * r['output']['amount'] <= 0:
                probs.append((rid, 'zero value'))
    R.check('R6 no money loop in recipes: furniture sell < craft cost (buy prices of inputs) < buy price, cost ratio 45-87 percent; processing recipes never beat their inputs', not probs,
            f'{len(ratios)} furniture recipes, ratio min/mean/max {min(ratios):.2f}/{sum(ratios) / len(ratios):.2f}/{max(ratios):.2f}; {probs[:3]}')
    crafted_rare = [i for i, e in items_fur.items() if e['rarity'] == 'rare' and e.get('recipe')]
    R.info('craftable furniture by rarity', {r: sum(1 for e in items_fur.values() if e['rarity'] == r and e.get('recipe')) for r in RARITIES})

    # shops
    probs = []
    sell_floor = {}
    for sid, s in shops.items():
        if s['keeper'] not in cm.NPCS:
            probs.append((sid, 'keeper', s['keeper']))
        for k in (s['name_key'], s['greeting_key']):
            if not have_key(k):
                probs.append((sid, 'loc', k))
        in_stock = set(s['stock'])
        for i in s['stock']:
            if i not in new_items:
                probs.append((sid, 'stock item', i))
            elif new_items[i]['rarity'] in ('unique', 'legendary'):
                probs.append((sid, 'keepsake in stock', i))
        for slot in s['rotation']:
            pool = slot['pool']
            if len(set(pool)) != len(pool) or slot['pick'] > len(pool) or slot['pick'] < 1:
                probs.append((sid, slot['id'], 'pick/pool', slot['pick'], len(pool)))
            if set(pool) & in_stock:
                probs.append((sid, slot['id'], 'pool overlaps fixed stock'))
            for i in pool:
                if i not in new_items:
                    probs.append((sid, slot['id'], 'pool item', i)); continue
                r = new_items[i]['rarity']
                if r in ('unique', 'legendary'):
                    probs.append((sid, slot['id'], 'keepsake in rotation', i))
                if slot['rarity'] not in ('mixed', r):
                    probs.append((sid, slot['id'], 'rarity mismatch', i, r, slot['rarity']))
        # sources of items in this shop must match
    # every item that claims a shop source appears in that shop's stock or pool for the slot
    for i, e in new_items.items():
        for s in e['sources']:
            if s['kind'] != 'shop':
                continue
            sh = shops.get(s['shop'])
            if sh is None:
                probs.append((i, 'shop source names a shop that does not exist', s))
                continue
            slot = s['slot']
            if slot == 'fixed':
                ok = i in sh['stock']
            elif slot in ('daily', 'tri', 'weekly'):
                ok = any(i in sl['pool'] for sl in sh['rotation'] if sl['id'] in ({'daily': ('dagens_nye', 'dagens_tomme'), 'tri': ('tre_dages_udvalg',), 'weekly': ('ugens_sjaeldenhed', 'ugens_fine_varer')}[slot]))
            elif slot == 'weekly_blueprint':
                ok = any(i in sl['pool'] for sl in sh['rotation'] if sl['id'] == 'ugens_tegning')
            elif slot == 'weekend':
                ok = any(i in sl['pool'] for sl in sh['rotation'])
            else:
                ok = False
            if not ok:
                probs.append((i, 'shop source not in shop', s))
    # reverse: every rotation pool/stock item has the shop source
    for sid, s in shops.items():
        mem = set(s['stock']) | {i for sl in s['rotation'] for i in sl['pool']}
        for i in mem:
            if i not in new_items:
                continue                                          # an unknown id is reported above ('stock item' / 'pool item'): a clean failure, never a crash of the later rules
            if not any(x['kind'] == 'shop' and x['shop'] == sid for x in new_items[i]['sources']):
                probs.append((sid, 'item lacks shop source', i))
    R.check('R7 shops: keepers/loc keys exist, every stock/pool id is a real item, no keepsake is sold, stock/rotation pools match every item\'s `shop` sources in both directions', not probs, probs[:5])
    sch = shop_schedule_problems(shops)
    R.check('SH1 shop opening days: open_weekdays is a list of distinct weekday indices 0..6 (0 = Monday), only the flea market has any and they are exactly Saturday + Sunday (5, 6)', not sch,
            sch[:4] or {sid: s.get('open_weekdays', 'daily') for sid, s in shops.items()})
    ssp = shop_stock_problems(shops)
    R.check('SH2 shop numbers: fixed stock >= 1 and restock 0..stock (ShopSystem: the most a shelf holds / the units back every morning), price >= 0, rotation period >= 1, price_mult > 0, season_boost >= 1',
            not ssp, ssp[:4] or f"{sum(len(_empty_to_dict(s.get('stock'))) for s in shops.values())} fixed stock rows, {sum(len(s['rotation']) for s in shops.values())} rotation rows")
    # price floor: even with every discount at its cap the shop price stays above the sell price
    probs = []
    for sid, s in shops.items():
        sale = max([x['discount'] for x in s['price_curve']['sales']] + [0])
        fd = s['price_curve']['friend_discount']['per_heart'] * s['price_curve']['friend_discount']['max_hearts']
        for slot in s['rotation']:
            for i in slot['pool']:
                if i not in new_items:
                    continue                                      # reported by R7
                mult = s['buy_multiplier'] * slot['price_mult'] * (1 - min(sale + fd + 0.10, caps['discount_total']))
                if new_items[i]['buy_price'] * mult <= new_items[i]['sell_price']:
                    probs.append((sid, i, round(new_items[i]['buy_price'] * mult), new_items[i]['sell_price']))
    R.check('R8 price curve: buying at the cheapest possible price (sale + friend + hobbit, total capped) always costs more than selling back', not probs, probs[:3])

    # tabs: every item of a shop sits in exactly one tab; quantities are positive integers
    probs = []
    for sid, sh in shops.items():
        members = set(sh['stock']) | {i for sl in sh['rotation'] for i in sl['pool']}
        for slot in sh['rotation']:
            if not (isinstance(slot.get('qty'), int) and slot['qty'] >= 1):
                probs.append((sid, slot['id'], 'qty'))
        for i in members:
            if i not in new_items:
                continue                                          # reported by R7
            e = new_items[i]
            hits = [t['id'] for t in sh['tabs'] if (e.get('furniture_type') in t.get('furniture_types', [])) or (e.get('slot') in t.get('slots', [])) or (e.get('group') in t.get('groups', []))
                    or (e['category'] in t.get('categories', []))]
            if len(hits) != 1:
                probs.append((sid, i, 'tabs', hits))
        for t in sh['tabs']:
            if t['name_key'] not in loc:
                probs.append((sid, t['id'], 'tab loc'))
    R.check('R7b shops: every item sits in exactly one tab, tab names resolve, every rotation slot has a positive integer qty', not probs, probs[:5])
    wr = G('lua/data/wardrobe_rules.lua', 'config')['wardrobe']
    probs = []
    for i, e in items_clo.items():
        hit = [k for k, v in wr['equip_slots'].items() if v['item_slot'] == e['slot'] and v.get('subslot') == e.get('subslot')]
        if len(hit) != 1:
            probs.append((i, hit))
    for k, v in wr['equip_slots'].items():
        if v['name_key'] not in loc:
            probs.append((k, 'loc'))
    for a, b in wr['exclusive']:
        if a not in wr['equip_slots'] or b not in wr['equip_slots']:
            probs.append(('exclusive', a, b))
    R.check('R7c wardrobe rules: every clothing item maps to exactly one of the nine equipment slots; exclusions and slot names resolve', not probs, probs[:4])
    esp = equip_slot_problems(wr['equip_slots'])
    R.check('R7d wardrobe equip_slots: every slot has its own integer z (draw order above the body), a name key, and a unique item_slot + subslot', not esp, esp[:4] or {k: v['z'] for k, v in wr['equip_slots'].items()})

    # ---------------------------------------------------------------- loot odds
    probs = []
    for cid, c in loot['containers'].items():
        if sum(c['odds'].values()) != 10000:
            probs.append((cid, 'odds sum', sum(c['odds'].values())))
        if not (c['rolls']['min'] >= 1 and c['rolls']['max'] >= c['rolls']['min']):
            probs.append((cid, 'rolls'))
    for cid, c in loot['creatures'].items():
        if sum(c['odds'].values()) != 10000:
            probs.append((cid, 'odds sum', sum(c['odds'].values())))
    R.check('R9 loot: every container / creature rarity odds sum to 10000 basis points', not probs, probs)
    # realised odds by simulation of the documented algorithm
    rng = random.Random(20261012)

    def draw(zone, cont, ov, N):
        zd = zones[zone]
        odds = ov.get('odds') or loot['containers'][cont]['odds']
        kinds = ov.get('kinds') or loot['containers'][cont]['kinds']
        tally = Counter()
        for _ in range(N):
            r = rng.random() * 10000
            acc, rar = 0, None
            for k, v in odds.items():
                acc += v
                if r < acc:
                    rar = k; break
            if rar is None:
                tally['EMPTY'] += 1; continue
            kd = {k: w for k, w in kinds.items() if zd['pools'].get(k, {}).get(rar)}
            if not kd:
                tally['EMPTY'] += 1; continue
            tally[rar] += 1
        return tally
    probs, rows = [], []
    for z, zd in zones.items():
        for cont, spec in zd['containers'].items():
            base = loot['containers'][cont]
            ov = {k: spec[k] for k in ('odds', 'kinds') if k in spec}
            odds = ov.get('odds') or base['odds']
            t = draw(z, cont, ov, 40000)
            if t['EMPTY']:
                probs.append((z, cont, 'empty pool reached', t['EMPTY']))
            for rar, w in odds.items():
                got = t[rar] / 40000 * 10000
                if abs(got - w) > 160:
                    probs.append((z, cont, rar, w, round(got)))
            # every rarity with odds > 0 must have at least one non-empty kind pool
            for rar, w in odds.items():
                if w > 0 and not any(zd['pools'].get(k, {}).get(rar) for k in (ov.get('kinds') or base['kinds'])):
                    probs.append((z, cont, rar, 'no pool'))
    R.check('R10 realised rarity distribution of every zone x container equals the designed odds (40k simulated opens each, +-1.6 points); no empty pool is ever reached', not probs, probs[:5])
    # unique wanderers: each wanderer sits in a container of its zone with wander_bp > 0
    probs = []
    for z, zd in zones.items():
        for w in zd.get('wanderers', []):
            if w['container'] not in zd['containers'] or loot['containers'][w['container']]['wander_bp'] <= 0:
                probs.append((z, w))
    R.check('R11 every unique wanderer lives in a container of its zone that can roll wanderers', not probs, probs)
    # pool variety
    small = [(z, k, r, len(l)) for z, zd in zones.items() for k, kp in zd['pools'].items() for r, l in kp.items() if z != 'farm' and len(l) < {'furniture': 4, 'clothing': 4, 'material': 2, 'gem': 2, 'weapon': 2}[k] and any(
        (zd['containers'][c].get('odds') or loot['containers'][c]['odds']).get(r, 0) > 0 for c in zd['containers'])]
    R.check('R12 every forest zone has >= 4 furniture, >= 4 clothing and >= 2 material entries in each rarity it can roll', not small, small[:4])
    # FIX ROUND (review F1 r1): the marker list the map authors build from must stay equal to the loot tables (generation is retired, nothing else keeps them together)
    markers = json.loads((F / 'data' / 'map_markers.json').read_text(encoding='utf-8'))
    mm = map_marker_problems(markers, loot)
    R.check('MM1 data/features/map_markers.json == lua/data/loot_tables.lua: per area the chests / digging spots per container id, the creatures per visit, the unique spots (== loot.spots of the zone) and the boss placement',
            not mm, mm[:4] or f"{len(markers['areas'])} areas, {sum(sum(a.get('containers', {}).values()) for a in markers['areas'].values())} chests + digs, "
            f"{sum(len(a.get('unique_spots', [])) for a in markers['areas'].values())} unique spots, {len(loot['spots'])} loot spots")

    # ---------------------------------------------------------------- home tiers
    tiers = home['tiers']
    probs = []
    if len(tiers) != 10 or [t['tier'] for t in tiers] != list(range(1, 11)):
        probs.append('tier numbering')
    if [t['id'] for t in tiers] != sup['home']['tier_ids']:
        probs.append(('tier ids differ from art spike', [t['id'] for t in tiers], sup['home']['tier_ids']))
    gold = [t.get('cost', {}).get('gold', 0) for t in tiers]
    days = [t.get('cost', {}).get('days', 0) for t in tiers]
    cap = [t['perks']['furniture_capacity'] for t in tiers]
    sto = [t['perks']['storage_slots'] for t in tiers]
    en = [t['perks']['max_energy_bonus'] for t in tiers]
    if not all(a < b for a, b in zip(gold[1:], gold[2:])):
        probs.append(('gold not increasing', gold))
    if not all(a <= b for a, b in zip(days[1:], days[2:])):
        probs.append(('days not non-decreasing', days))
    for nm, seq in (('capacity', cap), ('storage', sto), ('energy', en)):
        if not all(a < b for a, b in zip(seq, seq[1:])):
            probs.append((nm + ' not increasing', seq))
    rows_ = sup['home']['rows']
    exp_cap = [int(sum(rows_[str(t)]) * .55) for t in range(1, 11)]
    if cap != exp_cap:
        probs.append(('capacity differs from spike room shapes', cap, exp_cap))
    for t in tiers:
        a = t['art']
        if a['floor'] != sup['home']['floor'][str(t['tier'])] or a['walls'] != sup['home']['wall'][str(t['tier'])] or a['platform_back_rows'] != sup['home']['platform_stage'][t['tier'] - 1]:
            probs.append(('art ids differ from spike', t['tier']))
        for k in ('name_key', 'description_key') + (('gate_hint_key',) if t['tier'] > 1 else ()):
            if k in t and t[k] not in loc:
                probs.append((t['tier'], 'loc', t[k]))
        for dk in t['dialogue'].values():
            if dk not in loc:
                probs.append((t['tier'], 'dialogue loc', dk))
        for m, n in t.get('cost', {}).get('materials', {}).items():
            if m not in all_items:
                probs.append((t['tier'], 'material', m))
        for r in t['perks']['rooms']:
            if f'HOME_ROOM_{r.upper()}' not in loc:
                probs.append((t['tier'], 'room loc', r))
        for u in t['perks']['unlocks']:
            if f'HOME_UNLOCK_{u.upper()}' not in loc or f'HOME_UNLOCK_{u.upper()}_DESC' not in loc:
                probs.append((t['tier'], 'unlock loc', u))
        rq = t.get('requires', {})
        for q in rq.get('quests', []):
            if q not in qfiles:
                probs.append((t['tier'], 'quest', q))
        for n in rq.get('friendship', {}):
            if n not in cm.NPCS:
                probs.append((t['tier'], 'npc', n))
        if rq.get('hygge') and rq['hygge'] > len(home['hygge_levels']) - 1:
            probs.append((t['tier'], 'hygge level'))
        for g in t.get('gift_items', []):
            if g not in new_items:
                probs.append((t['tier'], 'gift item', g))
    R.check('R13 home tiers: 10 tiers whose ids/floors/walls/platform/capacity match the home art spike; gold & capacity & storage & energy increase; build days never decrease; every key/material/quest/npc resolves', not probs, probs[:5])
    hy = home['hygge_levels']
    R.check('R14 hygge levels strictly ascending in decor points, energy and luck non-decreasing, names resolve',
            all(a['min_decor'] < b['min_decor'] and a['energy'] <= b['energy'] and a['luck'] <= b['luck'] for a, b in zip(hy, hy[1:])) and all(h['name_key'] in loc for h in hy), [(h['id'], h['min_decor']) for h in hy])
    R.info('home tiers (gold, days, capacity, storage, energy)', [(t['tier'], t.get('cost', {}).get('gold', 0), t.get('cost', {}).get('days', 0), t['perks']['furniture_capacity'], t['perks']['storage_slots'], t['perks']['max_energy_bonus']) for t in tiers])


    # ---------------------------------------------------------------- CD3: the starter kit (lua/data/starter_kit.lua, addendum 2.7)
    sk_cfg = (G('lua/data/starter_kit.lua', 'config') or {}).get('starter_kit')
    probs = []
    if not sk_cfg:
        probs.append('lua/data/starter_kit.lua defines no config.starter_kit')
        sk_cfg = {'wardrobe': {'worn': [], 'owned': []}, 'furniture': {'placed': [], 'stock': {}}}
    worn, owned = list(sk_cfg['wardrobe']['worn']), list(sk_cfg['wardrobe']['owned'])
    placed, stock = list(sk_cfg['furniture']['placed']), dict(sk_cfg['furniture']['stock'])
    for i in worn + owned:
        if i not in items_clo:
            probs.append(('garment does not exist', i))
        elif items_clo[i]['rarity'] != 'normal':
            probs.append(('starter garment must be normal', i, items_clo[i]['rarity']))
    for i in placed + list(stock):
        if i not in items_fur:
            probs.append(('furniture does not exist', i))
        elif items_fur[i]['rarity'] != 'normal':
            probs.append(('starter furniture must be normal', i, items_fur[i]['rarity']))
    eq = wr['equip_slots']
    slot_of = {}
    for i in worn:
        if i in items_clo:
            hit = [k for k, v in eq.items() if v['item_slot'] == items_clo[i]['slot'] and v.get('subslot') == items_clo[i].get('subslot')]
            slot_of[i] = hit[0] if hit else None
    if len(set(slot_of.values())) != len(slot_of) or None in slot_of.values():
        probs.append(('worn pieces need distinct equipment slots', slot_of))
    probs += [('worn pieces exclude each other', a_, b_) for a_, b_ in wr['exclusive'] if a_ in slot_of.values() and b_ in slot_of.values()]
    probs += [('a worn piece is also listed as owned spare', i) for i in worn if i in owned]
    probs += [('a starter piece is stocked and placed twice by mistake', i) for i in placed if i in stock]
    for i, n in stock.items():
        if not (isinstance(n, int) and 1 <= n <= items_fur.get(i, {}).get('max_stack', 9)):
            probs.append(('stock amount', i, n))
    R.check('SK1 starter_kit_ids_exist: every id of lua/data/starter_kit.lua exists in the right catalogue and is a normal piece; the worn pieces fill distinct equipment slots without an exclusion pair; no piece is listed twice',
            not probs, probs[:4] or f'worn {worn} owned {owned} placed {placed} stock {stock}')
    cap1 = home['tiers'][0]['perks']['furniture_capacity']
    n_pieces = len(placed) + sum(stock.values())
    decor_all = sum(items_fur[i]['decor'] for i in placed if i in items_fur) + sum(items_fur[i]['decor'] * n for i, n in stock.items() if i in items_fur)
    area_all = sum(items_fur[i]['footprint'][0] * items_fur[i]['footprint'][1] for i in placed + [k for k, n in stock.items() for _ in range(n)] if i in items_fur and items_fur[i]['placement'] == 'floor')
    room1 = sup['home']['rows']['1']
    probs = []
    if n_pieces > cap1:
        probs.append(('more pieces than the shed has furniture slots', n_pieces, cap1))
    if decor_all >= home['hygge_levels'][1]['min_decor']:
        probs.append(('the whole kit already reaches the first hygge level', decor_all, home['hygge_levels'][1]['min_decor']))
    if area_all > sum(room1):
        probs.append(('floor pieces cover more cells than the shed room has', area_all, sum(room1)))
    R.check('SK2 starter kit fits the shed: pieces <= furniture slots of tier 1, floor footprints <= room cells, the whole kit stays below the first hygge level (the player earns Lunt by buying)',
            not probs, probs or f'{n_pieces} pieces of {cap1} slots, {area_all} of {sum(room1)} floor cells, decor {decor_all} < {home["hygge_levels"][1]["min_decor"]}')

    # ---------------------------------------------------------------- friend gates (addendum V4 / DF3): every heart a gate or gift asks for can be earned
    npcs_cfg = {}
    for rel, d in repo_dump.items():
        if rel not in dump:
            npcs_cfg.update((d['globals'].get('config') or {}).get('npcs') or {})
    quest_hearts = defaultdict(int)
    for rel in mine:
        if rel.startswith('lua/quests/'):
            for npc_, n_ in ((G(rel, 'rewards') or {}).get('friendship') or {}).items():
                quest_hearts[npc_] += n_
    HEART_CAP = 10
    probs = []
    asks = [(f"tier {t['tier']} gate", n_, h_) for t in home['tiers'] for n_, h_ in (t.get('requires', {}).get('friendship') or {}).items()] + [(f"gift {g['item']}", g['npc'], g['hearts']) for g in gifts]
    for what, npc_, hearts in asks:
        chat = bool(npcs_cfg.get(npc_, {}).get('friendship'))
        if not (chat or quest_hearts.get(npc_)):
            probs.append((what, npc_, 'neither the weekly chat (npcs.lua friendship = true) nor a quest reward pays hearts'))
        if not (1 <= hearts <= HEART_CAP):
            probs.append((what, npc_, 'hearts outside 1..10', hearts))
        if npc_ not in npcs_cfg:
            probs.append((what, npc_, 'npc not in lua/config/npcs.lua'))
    R.check('FG1 every friendship gate of the home tiers and every friendship gift can be earned: its npc has friendship = true in npcs.lua (weekly chat heart) or a quest that pays hearts, and asks <= 10 hearts',
            not probs, probs[:4] or f'{len(asks)} gates/gifts, quest-paid hearts {dict(quest_hearts)}')

    # ---------------------------------------------------------------- Q5 (review F1 r2): the npc / item references of the quests (all quest files of the stage tree: the four feature quests and the four legacy ones)
    quests_all = {Path(rel).stem: dict(rewards=G(rel, 'rewards') or {}, objectives=G(rel, 'objectives') or [], meta=G(rel, 'meta') or {}) for rel in mine if rel.startswith('lua/quests/')}
    qrp = quest_reference_problems(quests_all, set(npcs_cfg), all_items)
    R.check('Q5 quest references: every npc a quest pays hearts to, names as giver or as an objective target exists in npcs.lua (hearts 1..10), every reward item exists, gold >= 0',
            not qrp, qrp[:4] or f"{len(quests_all)} quests, friendship rewards {sorted({n for q in quests_all.values() for n in (q['rewards'].get('friendship') or {})})}")

    # ---------------------------------------------------------------- CD2: the old town name is gone from every F1 file (the name is built from parts: it is never written in this repository)
    # FIX ROUND (review F1 r1, major): the build-output filter is judged on the path RELATIVE to the scan root.  The stage tree itself lives in tools/features/_stage/<stage>/tree, so a test on the
    # absolute path skipped every file of the tree (N1 was vacuous under the default --work).  The rule now also proves that it LOOKED: every Lua file and every CSV of the stage tree was visited.
    hits, seen_in_tree = old_name_hits(F, F)
    # review F1 r2: N1 reads the WHOLE repo, not three folders (the old name in data/maps/*.map of P04 / P11 / P19, an .svg or a scene of any package was neither renamed nor caught)
    repo_hits, seen_repo = old_name_hits(repo, repo, skip_dirs=REPO_SKIP_DIRS, skip_rel=REPO_SKIP_REL)
    hits += [h for h in repo_hits if h not in hits]
    n_lua_tree = sum(1 for _ in F.rglob('*.lua'))                 # every Lua file of the tree: lua/** plus the pending references and the legacy baseline under data/
    n_csv_tree = sum(1 for _ in F.rglob('*.csv'))
    looked = n_lua_tree > 0 and n_csv_tree > 0 and seen_in_tree['.lua'] == n_lua_tree and seen_in_tree['.csv'] == n_csv_tree
    looked_repo = all(seen_repo[x] > 0 for x in ('.lua', '.csv', '.gd', '.md', '.json', '.py', '.tscn'))      # the repo scan visited every kind of file the repo always holds (.map: rules_selftest proves the suffix)
    scanned_txt = (f"{seen_in_tree['.lua']} of {n_lua_tree} Lua and {seen_in_tree['.csv']} of {n_csv_tree} CSV files of the stage tree scanned; {sum(seen_repo.values())} text files of the repo "
                   f"({seen_repo['.map']} .map, {seen_repo['.svg']} .svg, {seen_repo['.tscn']} .tscn, {seen_repo['.tres']} .tres)")
    R.check('N1 the town is Hyggebyen everywhere: the retired name is in no text file of the stage tree and of the whole repo (Lua, CSV, json, md, scripts, scenes, resources, .map text maps, .svg), '
            'the area id is hyggebyen, and the scans really visited every Lua file and CSV of the stage tree and every kind of file of the repo',
            not hits and looked and looked_repo and 'FIND_AREA_HYGGEBYEN' in loc and 'hyggebyen' in cm.AREAS, hits[:5] or scanned_txt)

    # ---------------------------------------------------------------- references to loc keys from Lua
    refs = set()
    for i, e in new_items.items():
        for k in ('name_key', 'description_key', 'hint_key'):
            if k in e:
                refs.add(e[k])
    for s in shops.values():
        refs.update([s['name_key'], s['greeting_key']])
    for s in list(fsets.values()) + list(wsets.values()):
        refs.update([s['name_key'], s['description_key']])
    for c in loot['containers'].values():
        refs.add(c['name_key'])
    for z in zones.values():
        refs.add(z['name_key'])
    for sp in spots.values():
        refs.update([sp['name_key'], sp['hint_key']])
    for r in rar_cfg['rarity_tiers']['order']:
        refs.add(rar_cfg['rarity_tiers'][r]['name_key'])
    for q in ('bogtraeet', 'moonstone_crown', 'snurresvampen', 'slotsdroemmen'):
        refs.update([f'QUEST_{q.upper()}_TITLE', f'QUEST_{q.upper()}_DESC', f'QUEST_{q.upper()}_OFFER'])
        for o in G(f'lua/quests/{q}.lua', 'objectives'):
            refs.add(o['description_key'])
    P14_KEYS = {'NPC_FAIRY_KING', 'DLG_KING_GREET'}      # the king's own lines belong to P14's dialogue.csv; the pending reference module only needs them to compile
    for rel in mine:
        if rel.startswith('lua/dialogue/'):
            txt = (F / rel).read_text(encoding='utf-8')
            refs.update(k for k in re.findall(r'(?:text_key|speaker_name_key) = "([A-Z0-9_]+)"', txt) if k not in P14_KEYS and not k.isdigit())
    missing = sorted(k for k in refs if not have_key(k))
    R.check('K1 every localisation key referenced from the new Lua exists (new CSVs or legacy da.csv)', not missing, f'{len(refs)} keys referenced; missing: {missing[:6]}')
    # K7 keys that code packages use by name must exist (coverage 4); K8 every key has exactly one owning file (plan-consistency 8)
    used = [l.strip() for l in (F / 'data' / 'used_keys.txt').read_text(encoding='utf-8').splitlines() if l.strip() and not l.startswith('#')]
    R.check('K7 every localisation key that the addendum names in code (whispers, shop states, toasts) exists in a feature CSV', all(k in loc for k in used), [k for k in used if k not in loc])
    own = json.loads((F / 'data' / 'loc_key_owners.json').read_text(encoding='utf-8'))['files']
    item_ids = {}
    for fn, spec in own.items():
        for lf in spec.get('item_files', []):
            item_ids.setdefault(fn, set()).update(G(lf, 'items') or {})
    def owner_of(key):
        for fn, spec in own.items():
            if key in spec['exact']:
                return fn
        for fn, ids in item_ids.items():
            m = re.fullmatch(r'ITEM_([A-Z0-9_]+?)(?:_DESC|_HINT)?', key)
            if m and any(key == 'ITEM_' + i.upper() + sfx for i in ids for sfx in ('', '_DESC', '_HINT')):
                return fn
        best, bl = None, -1
        for fn, spec in own.items():
            for pf in spec['prefix']:
                if key.startswith(pf) and len(pf) > bl:
                    best, bl = fn, len(pf)
        return best
    wrong = []
    for p in sorted((F / 'localization').glob('*.csv')):
        for row in csv.reader(open(p, encoding='utf-8', newline='')):
            if row[0] != 'keys' and owner_of(row[0]) != p.name:
                wrong.append((p.name, row[0], owner_of(row[0])))
    R.check('K8 every key of the eight feature CSVs resolves to ITS OWN file in data/loc_key_owners.json (exact keys, then ITEM ids, then longest prefix) - the table P03 lints with', not wrong, wrong[:5])
    # K9 (review F1 r2): the name keys of the loot creatures (ENEMY_*).  They are owned by forest.csv of P19 (wave 5): defined, or PENDING behind an owner file that does not exist yet (a WARN row that
    # names the rows P19 must write), never a typo and never an owner that exists but forgot the row.
    ckp, cpending = creature_key_problems(loot['creatures'], have_key, owner_of, lambda fn: (repo / 'localization' / fn).exists() or (F / 'localization' / fn).exists())
    R.check('K9 every loot creature name_key is a localisation key that a CSV defines, or whose owning CSV (tools/loc/key_owners.json) has not landed yet (listed as a warning for its owner)', not ckp,
            ckp[:4] or f"{len(loot['creatures']) - len(cpending)} of {len(loot['creatures'])} defined")
    if cpending:
        R.warn('K9 pending: creature name keys wait for their owner CSV (handoff to its package)', '; '.join(f'{k} ({cid}) -> {ow}' for cid, k, ow in cpending))
    unused = sorted(k for k in loc if k not in refs and not k.startswith(('HOME_UI', 'FURN_UI', 'WARDROBE_UI', 'SHOP_UI', 'FIND_UI', 'HYGGE_LABEL', 'HYGGE_SCORE', 'HOME_GATE', 'PERK_', 'SOURCE_', 'WARDROBE_SLOT', 'WARDROBE_SUBSLOT', 'FURN_CAT',
                                                                         'HOME_ROOM', 'HOME_UNLOCK', 'HYGGE_', 'RECIPE_', 'DLG_', 'NPC_', 'OBJ_', 'FIND_CONTAINER', 'FIND_AREA', 'FIND_SPOT', 'RARITY_')))
    R.info('loc keys not referenced from Lua (items/hints are looked up by convention ITEM_<ID>)', len(unused))
    for i in new_items:
        for suffix in ('', '_DESC'):
            if 'ITEM_' + i.upper() + suffix not in loc:
                R.check(f'K2 ITEM_{i.upper()}{suffix} exists', False)
    # season coverage of the rotating shops
    probs = []
    for sid, shp in shops.items():
        if sid not in ('furniture_shop', 'tailor_shop'):
            continue
        pool = {i for sl in shp['rotation'] for i in sl['pool']} | set(shp['stock'])
        for se in cm.SEASONS:
            n = sum(1 for i in pool if se in new_items.get(i, {}).get('seasons', []))
            if n < 5:
                probs.append((sid, se, n))
    R.check('K4 every season has >= 5 tagged items in the rotation of furniture_shop and tailor_shop (the season boost has something to boost)', not probs, probs)
    vk = re.findall(r'voice_key = "([^"]+)"', (F / 'lua/dialogue/fairy_builder.lua').read_text(encoding='utf-8'))
    R.check('K5 every builder voice key follows voice/fairy_builder/t<NN>_<kind> and maps to one text_key', all(re.fullmatch(r'voice/fairy_builder/t\d\d_(idle|offer|building|done)', k) for k in vk), f'{len(vk)} uses of {len(set(vk))} distinct keys (the 28 branches repeat the same lines on purpose)')
    vkp = voice_key_problems({rel: (F / rel).read_text(encoding='utf-8') for rel in ('lua/dialogue/fairy_builder.lua', 'lua/dialogue/fairy_furnisher.lua', 'lua/dialogue/fairy_tailor.lua')})
    R.check('K10 every spoken line of the builder, furnisher and tailor dialogues has voice_key == voice/<speaker>/<line id>, a line id that matches its text key, and no voice key serves two texts',
            not vkp, vkp[:4] or 'builder, furnisher, tailor')
    dn, en_ = defaultdict(list), defaultdict(list)
    for i in new_items:
        da_, e_ = loc['ITEM_' + i.upper()]
        dn[da_.lower()].append(i); en_[e_.lower()].append(i)
    R.check('K6 every item has its own Danish and English display name (no two items share a name)', not [v for v in dn.values() if len(v) > 1] and not [v for v in en_.values() if len(v) > 1],
            [v for v in dn.values() if len(v) > 1][:3])
    # dialogue lines referenced by the builder module cover every tier line
    dtxt = (F / 'lua/dialogue/fairy_builder.lua').read_text(encoding='utf-8')
    dk = set(re.findall(r'text_key = "(DLG_[A-Z0-9_]+)"', dtxt))
    need = {f'DLG_BUILDER_T{t:02d}_{k}' for t in range(1, 11) for k in ('IDLE',)} | {f'DLG_BUILDER_T{t:02d}_OFFER' for t in range(1, 10)} | {
        f'DLG_BUILDER_T{t:02d}_{k}' for t in range(2, 11) for k in ('BUILDING', 'DONE')}
    R.check('K3 the builder dialogue module uses all 10 + 9 + 9 + 9 = 37 builder lines', need <= dk, sorted(need - dk))

    # ---------------------------------------------------------------- Danish quality
    eng = set('the with your you this that from will would could should which their there about into these those what when where who while because until'.split())
    probs, same, longs = [], [], []
    placeholders = lambda s: sorted(re.findall(r'%[sd]', s))  # noqa: E731
    for k, (da, en) in loc.items():
        low = re.findall(r"[a-zæøåA-ZÆØÅ']+", da.lower())
        if re.search(r'TODO|FIXME|XXX|lorem|ipsum|\?\?\?', da + en, re.I):
            probs.append((k, 'todo marker'))
        e = [w for w in low if w in eng]
        if e:
            probs.append((k, 'english words in Danish', e))
        if da != da.strip() or '  ' in da or '"' in da or '--' in da or '"' in en:
            probs.append((k, 'whitespace/quote'))
        if placeholders(da) != placeholders(en):
            probs.append((k, 'placeholder mismatch', da, en))
        if da.lower() == en.lower() and len(da.split()) >= 3:
            same.append(k)
        if len(da) > 140 and not k.endswith(('_DESC', '_HINT', '_IDLE', '_OFFER', '_BUILDING', '_DONE', '_GREET', '_GREETING', '_GATE', '_FMT')) and 'OFFER' not in k:
            longs.append((k, len(da)))
        if '%' in da and not k.endswith('_FMT') and not k.startswith(('WEFFECT_', 'WSTAT_', 'GEMFX_')):
            probs.append((k, '% in a non-_FMT key'))
    R.check('D1 no TODO markers, no English words in Danish text, clean whitespace, no ASCII quotes, identical placeholders in da and en', not probs, probs[:5])
    R.check('D2 Danish text differs from English for every phrase of 3+ words', not same, same[:5])
    R.info('D3 long Danish strings outside desc/hint/dialogue', longs[:5])
    body, head, font_src = font_coverage(args)
    chars_da = set(''.join(da for da, en in loc.values()))
    names = {k: da for k, (da, en) in loc.items() if k.startswith(('HOME_TIER_', 'FSET_', 'OUTFIT_', 'SHOP_'))}
    missing_body = sorted(c for c in chars_da if ord(c) not in body)
    missing_head = sorted(c for c in set(''.join(v for k, v in names.items() if not k.endswith(('_DESC', '_GREETING', '_GATE')))) if ord(c) not in head)
    R.check('D4 every character of every Danish string exists in Alegreya Sans; every heading/name character exists in Caprasimo (Æ Ø Å and „ “ » « – … render)', not missing_body and not missing_head,
            f'{len(chars_da)} distinct characters; missing body {missing_body}, missing heading {missing_head}; fonts: {font_src}')
    R.info('D4 special characters used', ''.join(sorted(c for c in chars_da if ord(c) > 127)))
    must = 'ÆØÅæøå„“»«–…’é'
    R.check('D4b both fonts contain Æ Ø Å æ ø å and the typographic marks „ “ » « – … ’ (needed even where no current string uses them)',
            all(ord(c) in body for c in must) and all(ord(c) in head for c in 'ÆØÅæøå'), [c for c in must if ord(c) not in body])
    # Danish literals inside the Lua files themselves (quest notifications, objective descriptions)
    lit = []
    for rel in mine:
        for m in re.finditer(r'"([^"]*)"', (F / rel).read_text(encoding='utf-8')):
            t = m.group(1)
            if ' ' in t and re.search(r'[A-Za-zæøåÆØÅ]{3}', t) and not marker_parameters(rel, t):
                ws = re.findall(r"[a-zæøå']+", t.lower())
                if [w for w in ws if w in eng]:
                    lit.append((rel, t))
    R.check('D5 Danish literals inside the Lua files contain no English words', not lit, lit[:3])
    # D6 (review F1 r2): working rule 3 - no Danish / English text as a literal in the Lua of THIS package (ten dead `description = "..."` copies sat in the four quests).  P13's / P14's own rewrites are theirs.
    own_lua = [rel for rel in mine if rel not in real_files and origins.get(rel, 'own') == 'own']
    tlp = text_literal_problems({rel: (F / rel).read_text(encoding='utf-8') for rel in own_lua})
    R.check('D6 no text literal (a string with a space) in any Lua file of this package: Danish and English text lives in the CSVs only', not tlp, tlp[:4] or f'{len(own_lua)} files')
    # quest amendments are rewards-only
    probs = []
    for q in ('lost_cat', 'fix_roof', 'birthday_cake', 'math_wizard_quiz'):
        new = (F / f'data/pending/lua/quests/{q}.lua').read_text(encoding='utf-8')     # the PENDING reference (every stage: the reviewed rewards that P13 merges)
        old = (F / f'data/legacy_base/lua/quests/{q}.lua').read_text(encoding='utf-8')     # the legacy files of the baseline commit (stored with the pending references: P13 rewrites the repo copies in wave 4)
        strip = lambda t: re.sub(r'^rewards = \{[\s\S]*?\n\}\n', '', t, flags=re.M)  # noqa: E731
        a, b = strip(new), strip(old)
        a = '\n'.join(l for l in a.split('\n') if 'FEATURES' not in l)
        if q == 'lost_cat':
            a = re.sub(r'^meta = \{[\s\S]*?\n\}\n', '', a, flags=re.M)
            b = re.sub(r'^meta = \{[\s\S]*?\n\}\n', '', b, flags=re.M)
            a = a.replace('Bring katten hjem til Pippin', 'Bring katten hjem til Lily')
        if re.sub(r'\n{2,}', '\n', a) != re.sub(r'\n{2,}', '\n', b):
            probs.append(q)
    R.check('Q1 the four pending (reviewed) quests differ from the legacy baseline files ONLY in rewards (lost_cat: also meta and the one objective text)', not probs, probs)
    if args.stage != 'f1':
        pend = {d['file']: d for d in json.loads(Path(args.pending_lua_dump).read_text())}
        bad3 = [q for q in ('lost_cat', 'fix_roof', 'birthday_cake', 'math_wizard_quiz')
                if norm(G(f'lua/quests/{q}.lua', 'rewards')) != norm(pend[f'data/pending/lua/quests/{q}.lua']['globals']['rewards'])]
        R.check(f'Q3 [{args.stage}] the rewards of the four merged quests in the REAL repo equal the reviewed pending rewards (P13 merged them)', not bad3, bad3)
    probs = []
    for q in ('bogtraeet', 'moonstone_crown', 'snurresvampen', 'slotsdroemmen'):
        obj = G(f'lua/quests/{q}.lua', 'objectives')
        ids = [o['id'] for o in obj]
        if len(ids) != len(set(ids)):
            probs.append((q, 'dup objective'))
        meta = G(f'lua/quests/{q}.lua', 'meta')
        if meta['repeatable'] is not False:
            probs.append((q, 'must not be repeatable (unique/legendary reward)'))
        if meta['giver'] not in cm.NPCS:
            probs.append((q, 'giver'))
    for q, its in qrs.items():
        m = G(f'lua/quests/{q}.lua', 'meta')
        if m['repeatable'] is not False:
            probs.append((q, 'reward quest repeatable'))
    R.check('Q2 quests that hand out unique/legendary/rare items are not repeatable; objective ids unique; givers exist', not probs, probs)
    # Q4 objective sanity (the validator feeds hand-made events, so reachability is checked by reading): every objective has a binding the PLAN's QuestManager really emits
    MAPS = {'farm', 'hyggebyen', 'home'}
    dungeon_layout = G('lua/config/dungeon.lua', 'config')['dungeon']
    MAPS.update(dungeon_layout['hub']['floor_prefix'] + str(n) for n in range(1, dungeon_layout['max_floor'] + 1))
    ZONES = {'farm', 'city', 'dark_forest', 'crystal_cave', 'mushroom_grove'}
    STATES = {'placed_by_rarity', 'hygge_level_at_least', 'home_tier_at_least'}
    nlev = len(home['hygge_levels'])
    probs = []
    for q in ('bogtraeet', 'moonstone_crown', 'snurresvampen', 'slotsdroemmen'):
        for o in G(f'lua/quests/{q}.lua', 'objectives'):
            on = o.get('on')
            if on == 'manual':
                probs.append((q, o['id'], 'manual objective with no completer'))
            elif on == 'zone_entered' and o.get('zone') not in ZONES:
                probs.append((q, o['id'], 'zone', o.get('zone')))
            elif on == 'area_changed' and o.get('area') not in MAPS:
                probs.append((q, o['id'], 'area', o.get('area')))
            elif on == 'state' and (o.get('state') not in STATES or o.get('min_level', 0) > nlev - 1):
                probs.append((q, o['id'], 'state', o.get('state'), o.get('min_level')))
            elif on == 'game_event' and o.get('min_level', 0) > nlev - 1:
                probs.append((q, o['id'], 'min_level beyond the hygge levels'))
            elif on not in ('item_gained', 'dialogue_started', 'enemy_defeated', 'game_event', 'zone_entered', 'area_changed', 'state', 'manual'):
                probs.append((q, o['id'], 'unknown on=', on))
        for o in G(f'lua/quests/{q}.lua', 'objectives'):
            if o.get('on') == 'game_event' and o.get('event') == 'furniture_placed':
                probs.append((q, o['id'], 'counting furniture_placed EVENTS lets one piece be placed six times: use on = "state"'))
        txt = (F / f'lua/quests/{q}.lua').read_text(encoding='utf-8')
        for m in re.finditer(r'api\.notification\("([^"]*)", "([^"]*)"\)', txt):
            for k in m.groups():
                if not re.fullmatch(r'[A-Z0-9_]+', k) or not have_key(k):
                    probs.append((q, 'notification must be two existing loc keys', k))
    R.check('Q4 feature quest objectives are completable with the events the PLAN emits (no manual, state queries known, areas/zones exist, no event counting) and toasts use loc keys', not probs, probs[:4])
    # R19 (plan-consistency 2b): A1's wave-2 art checks compare against data/content_contract.json - it must still equal the real Lua
    cc_p = F / 'data' / 'content_contract.json'
    if cc_p.exists():
        cc = json.loads(cc_p.read_text(encoding='utf-8'))
        probs = []
        for t, c in zip(home['tiers'], cc['tiers']):
            real = {'tier': t['tier'], 'capacity': t['perks']['furniture_capacity'], 'floor': t['art']['floor'], 'walls': t['art']['walls'], 'platform_back_rows': t['art']['platform_back_rows'], 'gift_items': t.get('gift_items', [])}
            if {k: c[k] for k in real} != real:
                probs.append(('tier', t['tier']))
        if set(cc['furniture']) != set(items_fur) or set(cc['materials']) != set(items_mat) or set(cc['garments']) != set(items_clo):
            probs.append('id sets differ')
        else:
            probs += [(i, 'furniture art/footprint/layer') for i, e in items_fur.items() if cc['furniture'][i] != {'template': e['art']['template'], 'rarity': e['rarity'], 'footprint': e['footprint'], 'layer': e['placement']}]
        R.check('R19 data/content_contract.json (what A1 and A2 test their art against) equals the real Lua: 10 tiers, 130 furniture, 32 materials, 96 garments', not probs, probs[:4])
    else:
        R.check('R19 data/content_contract.json exists', False)
    # R15 (coverage 2): wardrobe set bonuses must be reachable by WEARING (one item per equip slot, dress excludes shirt + pants, hat excludes circlet)
    import itertools
    wr = G('lua/data/wardrobe_rules.lua', 'config')['wardrobe']
    excl = [tuple(x) for x in wr['exclusive']]
    def wearable_max(members):
        by = set()
        for m in members:
            it = items_clo[m]
            by.add(it['subslot'] if it['slot'] == 'jewellery' else it['slot'])
        have_ = [sl for sl in wr['equip_slots'] if sl in by]
        best_ = 0
        for r in range(len(have_) + 1):
            for combo in itertools.combinations(have_, r):
                if not any(a in combo and b in combo for a, b in excl):
                    best_ = max(best_, len(combo))
        return best_
    probs = [(sid, [b['pieces'] for b in s['bonuses']], wearable_max(s['members'])) for sid, s in wsets.items() if max(b['pieces'] for b in s['bonuses']) > wearable_max(s['members'])]
    R.check('R15 every wardrobe_sets bonus row can be reached by WEARING pieces (max simultaneously wearable per set)', not probs, probs[:4] or {sid: wearable_max(s["members"]) for sid, s in wsets.items()})
    # R16 (coverage 3): stub / partial unlocks may not promise more than they do
    ust = home.get('unlock_status', {})
    promise = [r'\bbag\b', r'\bbage\b', r'\bbagning', r'vejrudsigt', r'vejret bliver', r'om det regner', r'alle dine venner', r'venskaberne vokser', r'kigger forbi hver uge']
    probs = [u for u in home['unlocks'] if u not in ust or ust[u] not in ('real', 'partial', 'stub')]
    for u in home['unlocks']:
        if ust.get(u) in ('partial', 'stub'):
            da_ = loc.get('HOME_UNLOCK_' + u.upper() + '_DESC', ('', ''))[0].lower()
            probs += [(u, 'promises', w) for w in promise if re.search(w, da_)]
    for k in loc:
        if k.startswith('DLG_BUILDER_'):
            da_ = loc[k][0].lower()
            probs += [(k, 'promises', w) for w in promise if re.search(w, da_)]
    R.check('R16 every unlock has a status (real / partial / stub) and the Danish copy of partial and stub unlocks and of the voiced builder lines does not promise a mechanic that does not exist', not probs, probs[:4])
    # R17 (art 2, coverage 5): rarity UI colours - legendary = the night tile, no label near the damage colour Tornebaer, no ring equal to the focus gold, labels readable
    import colour as clr
    rar_rank = {r: n for n, r in enumerate(['normal', 'uncommon', 'rare', 'unique', 'legendary'])}
    rt = rar_cfg['rarity_tiers']
    probs = []
    if rt['legendary']['ui'] != dict(fill='2f3654', ring='a9d3e0', label='2b2340', pip='f2c14e', icon_rim='e4eff5'):
        probs.append(('legendary ui is not the CD1 night tile', rt['legendary']['ui']))
    for r in rt['order']:
        u = rt[r]['ui']
        if u['ring'].lower() == 'e3c372':
            probs.append((r, 'ring is the focus gold'))
        if clr.de2000(u['label'], 'b3436b') < 10 and r != 'legendary':
            probs.append((r, 'label too close to Tornebaer', round(clr.de2000(u['label'], 'b3436b'), 1)))
        if r != 'legendary' and clr.contrast(u['label'], u['fill']) < 4.5:
            probs.append((r, 'label contrast', round(clr.contrast(u['label'], u['fill']), 2)))
        if r != 'legendary' and clr.contrast(u['label'], 'fbf5e6') < 4.5:
            probs.append((r, 'label contrast on parchment', round(clr.contrast(u['label'], 'fbf5e6'), 2)))
    leg = rt['legendary']['ui']
    if clr.contrast(leg['pip'], leg['fill']) < 7.0 or clr.contrast(leg['icon_rim'], leg['fill']) < 7.0 or clr.contrast('2b2340', leg['icon_rim']) < 7.0:
        probs.append(('legendary pip / rim contrast', round(clr.contrast(leg['pip'], leg['fill']), 2), round(clr.contrast(leg['icon_rim'], leg['fill']), 2)))
    R.check('R17 rarity UI colours: legendary is the night tile with a pale icon rim, no ring is the focus gold, no label is within CIEDE2000 10 of Tornebaer, labels >= 4.5:1, gold pips and rim >= 7:1 on night', not probs, probs[:4])
    # R20 (art 4): rarity has to be visible in the item's OWN colours, because in the world only the palette (and the aura of unique / legendary) is readable at game zoom
    import collections as _col
    by_design = _col.defaultdict(list)
    for i, e in items_clo.items():
        by_design[e['art']['layer']].append((e['rarity'], e['art']['palette'], i))
    probs = []
    for d_, lst in by_design.items():
        for a_ in lst:
            for b_ in lst:
                if rar_rank[a_[0]] > rar_rank[b_[0]] and max(clr.de2000(x, y) for x, y in zip(a_[1], b_[1])) < 8:
                    probs.append((d_, a_[2], a_[0], b_[2], b_[0]))
    R.check('R20 two garments of the same design but different rarity differ by CIEDE2000 >= 8 in at least one palette region (the rarity step is visible in the colours)', not probs, probs[:4])
    # R18 (plan-consistency 7): duplicates - garments are max_stack 1, so a found copy must have a defined outcome
    dup = loot.get('duplicates', {})
    probs = [i for i, e in items_clo.items() if e.get('max_stack') != 1]
    R.check('R18 every garment is max_stack 1 and loot.duplicates sells a copy that cannot be taken (clothing + furniture) with a message key that exists',
            not probs and set(dup.get('kinds', [])) >= {'clothing', 'furniture'} and dup.get('action') == 'sell' and have_key(dup.get('message_key', '')), probs[:3] or dup)

    Path(args.report).write_text(R.text(), encoding='utf-8')
    print(R.text())
    sys.exit(1 if R.counts[FAIL] else 0)


if __name__ == '__main__':
    try:
        main()
    except SystemExit:
        raise
    except Exception as ex:  # noqa: BLE001
        import traceback
        R.check('X validator crashed (a check could not run - the data is probably broken)', False, repr(ex)[:200])
        print(traceback.format_exc(), file=sys.stderr)
        rp = [a for a in sys.argv if a.startswith('--report')]
        path = sys.argv[sys.argv.index('--report') + 1] if '--report' in sys.argv else None
        if path:
            Path(path).write_text(R.text(), encoding='utf-8')
        print(R.text())
        sys.exit(1)
