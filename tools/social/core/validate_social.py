#!/usr/bin/env python3
"""Validator of the social data - package S-core. The Python twin of tests/lib/social/social_validator.gd (rules SV1..SV12 and SV14; SV13 is S-marriage's gate
rule): it reads the JSON dump of the REAL data (tests/lib/social/dump_social_json.gd; tests/lib/social/fixtures/design_dump.json is the pinned design snapshot)
and checks what the game would otherwise only find out at run time.

    python3 -I tools/social/core/validate_social.py DUMP.json [--routes=ROUTES.json] [--stats] [--strict-skips]
    exit 0 = no errors (warnings are printed), 1 = errors

Rules (an error starts with its code, "ERROR SV3: ..."):
  SV1   citizens / gift_tastes rows name real NPCs
  SV2   tier A | B | C, the archetype has a taste row, every social.role_archetype value is an archetype
  SV3   birthdays: real dates, not ON or BESIDE a festival day, one per day, at least 2 days apart (the year wraps)
  SV4   (warning) a friend without a citizens row uses the derived defaults
  SV5   taste selectors resolve (an item id, category: ftype: slot: set: rarity:)
  SV6   no selector in two classes of one row
  SV7   at least 3 GIFTABLE loved items per friend (warning below 6 liked)
  SV8   citizens extras: unlock {quest | day}, keeper sample {item exists, normal rarity, sell <= 20 g, from_hearts 1..10}
  SV9   festivals: real date, window inside day_start..day_end_hour - 1 (25.0 on the 26 hour day; CLOCK_26), host is an NPC, area / spot / closes, activity kinds and
        selectors, stays_open shops exist
  SV10  events: npc, hearts 1..10, step vocabulary, speakers, text keys, 1..3 choice options, give items, reward points <= one heart
  SV11  festival roster (ghost family amendment AGF17): first / guests / leave_early ids exist, a `first` member IS a home citizen of the area and a guest is NOT, nobody
        twice, max_attendees + 1 + len(first) + len(guests) <= towns.max_live_visuals_festival, leave_early >= 1.5 x the route time + 15 minutes measured from the
        deadline (needs --routes; without it the rule is reported as NOT evaluated, never silently passed)
  SV12  the when= specs of events resolve (the grammar of SocialManager.eval_when)
  SV14  contest reward caps: first prize <= min(2 x the cheapest winning entry of its category, 400 g), second <= 0.7 x first, third <= 0.4 x first, never a keepsake,
        rarity <= rare, the item exists. "Cheapest winning entry": entry score = sell value x (1 + 0.5 x rarity rank); the first NPC bar is the best score of the
        category; with the jitter (+-15 %) at its worst for the bar and its best for the entrant an item wins when score x 1.15 >= best x 0.85; the cheapest such
        entry's sell value is the base of the cap.
--routes: {"default_route_minutes": 40, "route_minutes": {"<npc>": {"<spot>": minutes}}, "shop_open_hour": {"<shop>": hour}}
"""
import json
import re
import sys

STEP_ACTS = ['fade', 'stand', 'walk', 'face', 'camera', 'clip', 'emote', 'say', 'choice', 'give', 'points', 'flag', 'wait', 'time', 'sfx', 'end']
ACTIVITY_KINDS = ['contest', 'potluck', 'market', 'feast', 'wish', 'dance', 'scene']
NEVER_CATEGORIES = ('quest', 'special', 'animal', 'building', 'blueprint')
KEEPSAKES = ('unique', 'legendary')
PRIZE_RARITIES = ('normal', 'uncommon', 'rare')
RARITY_RANK = {'normal': 0, 'uncommon': 1, 'rare': 2}
AREAS = ('traetoppen', 'hyggebyen', 'farm')
CLASS_ORDER = ('hate', 'dislike', 'love', 'like')
WHEN_KINDS = ('quest', 'done', 'flag', 'night', 'at', 'away', 'open', 'hearts', 'fest', 'hour', 'weekday', 'season', 'birthday', 'stage')
JITTER = 0.15


class Validator:
    def __init__(self, data, routes=None):
        self.d = data
        self.routes = routes
        self.errors, self.warnings, self.skipped = [], [], []
        self.items = data.get('items', {})
        self.npcs = data.get('npcs', {})
        self.cz = data.get('citizens', {})
        self.tastes = data.get('gift_tastes', {})
        self.fests = data.get('festivals', {})
        self.events = data.get('events', {})
        self.shops = data.get('shops', {})
        t = data.get('time', {})
        self.seasons = list(t.get('seasons', ['foraar', 'sommer', 'efteraar', 'vinter']))
        self.dps = int(t.get('days_per_season', 28))
        self.day_start = int(t.get('day_start_hour', 6))
        self.day_end = int(t.get('day_end_hour', 26))
        self.social = data.get('social', {})
        self.stats = {}
        self.cats = {i['category'] for i in self.items.values() if i.get('category')}
        self.ftypes = {i['furniture_type'] for i in self.items.values() if i.get('furniture_type')}
        self.slots = {i['slot'] for i in self.items.values() if i.get('slot')}
        self.sets = {i['set'] for i in self.items.values() if i.get('set')}
        self.giftable_ids = sorted(i for i, d in self.items.items() if self.giftable(d))
        self.friends = sorted(n for n, r in self.npcs.items() if r.get('friendship') or 'unlock' in self.cz.get(n, {}))

    # ------------------------------------------------------------ helpers
    def e(self, code, msg):
        self.errors.append('%s: %s' % (code, msg))

    def w(self, code, msg):
        self.warnings.append('%s: %s' % (code, msg))

    @staticmethod
    def giftable(d):
        if d.get('rarity', 'normal') in KEEPSAKES or d.get('protected'):
            return False
        if 'giftable' in d:
            return bool(d['giftable'])
        if d.get('category') in NEVER_CATEGORIES:
            return False
        return d.get('sell_price', 0) > 0

    def td(self, season, day):
        return self.seasons.index(season) * self.dps + day

    def sels_of(self, iid):
        d = self.items.get(iid, {})
        s = {iid: 4}
        if d.get('furniture_type'):
            s['ftype:' + d['furniture_type']] = 3
        if d.get('slot'):
            s['slot:' + d['slot']] = 3
        if d.get('set'):
            s['set:' + d['set']] = 3
        if d.get('category'):
            s['category:' + d['category']] = 2
        s['rarity:' + d.get('rarity', 'normal')] = 1
        return s

    def taste(self, npc, iid):
        sels = self.sels_of(iid)
        arch = self.cz.get(npc, {}).get('archetype', 'wanderer')
        for row in (self.tastes.get('npcs', {}).get(npc, {}), self.tastes.get('archetypes', {}).get(arch, {}), self.tastes.get('universal', {})):
            best, bs, br = None, 0, 99
            for ci, cls in enumerate(CLASS_ORDER):
                for ent in row.get(cls, []):
                    if ent in sels:
                        sp = sels[ent]
                        if sp > bs or (sp == bs and ci < br):
                            best, bs, br = cls, sp, ci
            if best:
                return best
        return 'neutral'

    def sel_ok(self, sel):
        if ':' in sel:
            kind, value = sel.split(':', 1)
            return {'category': value in self.cats, 'ftype': value in self.ftypes, 'slot': value in self.slots, 'set': value in self.sets,
                    'rarity': value in ('normal', 'uncommon', 'rare')}.get(kind, False)
        return sel in self.items

    def cheapest_winning_entry(self, select):
        best, entries = 0.0, []
        for iid, d in self.items.items():
            if self.giftable(d) and select in self.sels_of(iid):
                sell = float(d.get('sell_price', 0))
                score = sell * (1.0 + 0.5 * RARITY_RANK.get(d.get('rarity', 'normal'), 0))
                entries.append((sell, score))
                best = max(best, score)
        cheapest = 0.0
        for sell, score in entries:
            if score * (1.0 + JITTER) >= best * (1.0 - JITTER) and (cheapest == 0.0 or sell < cheapest):
                cheapest = sell
        return cheapest

    # ------------------------------------------------------------ run
    def run(self):
        self.stats.update(friends=len(self.friends), citizens=len(self.cz), festivals=len(self.fests), events=len(self.events), giftable_items=len(self.giftable_ids))
        self.no_tastes = not (self.tastes.get('universal') or self.tastes.get('archetypes') or self.tastes.get('npcs'))
        if self.no_tastes:
            self.skipped.append('SV2 / SV5 / SV6 / SV7: no gift_tastes data in the tree (lua/social/gift_tastes.lua is S-data\'s, wave 5): the archetype, selector and loved-item rules were NOT evaluated')
        self.sv1_sv2_sv4()
        self.sv3()
        if not self.no_tastes:
            self.sv5_sv6()
            self.sv7()
        self.sv8()
        self.sv9()
        self.sv10()
        self.sv11()
        self.sv12()
        self.sv14()
        return self

    def sv1_sv2_sv4(self):
        arch = self.tastes.get('archetypes', {})
        for n, r in self.cz.items():
            if n not in self.npcs:
                self.e('SV1', 'citizens row %s has no npcs.lua row' % n)
            if r.get('tier') not in ('A', 'B', 'C'):
                self.e('SV2', '%s: tier %s' % (n, r.get('tier')))
            if not self.no_tastes and r.get('archetype') not in arch:
                self.e('SV2', '%s: archetype %s has no taste row' % (n, r.get('archetype')))
        for n in self.friends:
            if n not in self.cz:
                self.w('SV4', '%s can reach hearts but has no citizens row (derived defaults apply)' % n)
        for n in self.tastes.get('npcs', {}):
            if n not in self.npcs:
                self.e('SV1', 'gift_tastes.npcs.%s is no NPC' % n)
        for role, a in self.social.get('role_archetype', {}).items():
            if not self.no_tastes and arch and a not in arch:
                self.e('SV2', 'social.role_archetype.%s = %s has no taste row' % (role, a))

    def sv3(self):
        fdays = {}
        for fid, f in self.fests.items():
            m = f.get('meta', {})
            if m.get('season') in self.seasons:
                fdays[self.td(m['season'], int(m.get('day', 0)))] = fid
        year = len(self.seasons) * self.dps
        by_day = {}
        for n, r in self.cz.items():
            b = r.get('birthday')
            if not isinstance(b, dict):
                self.w('SV3', '%s: no birthday (derived)' % n)
                continue
            season, day = b.get('season'), int(b.get('day', 0))
            if season not in self.seasons or day < 1 or day > self.dps:
                self.e('SV3', '%s: bad date %s' % (n, b))
                continue
            t = self.td(season, day)
            by_day.setdefault(t, []).append(n)
            for off in (-1, 0, 1):
                raw = t + off
                other = (raw - 1) % year + 1
                if other in fdays:
                    where = 'on' if off == 0 else 'beside'
                    if 1 <= raw <= year:
                        self.e('SV3', '%s: birthday %s %d is %s the day of %s' % (n, season, day, where, fdays[other]))
                    else:
                        self.w('SV3', '%s: birthday %s %d is %s the day of %s across the new year (the planner did not wrap)' % (n, season, day, where, fdays[other]))
        days = sorted(by_day)
        for t in days:
            if len(by_day[t]) > 1:
                self.e('SV3', 'two birthdays on day %d: %s' % (t, by_day[t]))
        if len(days) > 1:
            for i, t in enumerate(days):
                nxt = days[(i + 1) % len(days)]
                gap = (nxt - t) % year
                if 0 < gap < 2:
                    msg = 'birthdays only %d day(s) apart (%s and %s)' % (gap, by_day[t], by_day[nxt])
                    if nxt > t:
                        self.e('SV3', msg)
                    else:
                        self.w('SV3', msg + ' across the new year')

    def rows(self):
        yield 'universal', self.tastes.get('universal', {})
        for k, v in self.tastes.get('archetypes', {}).items():
            yield 'arch:' + k, v
        for k, v in self.tastes.get('npcs', {}).items():
            yield 'npc:' + k, v

    def sv5_sv6(self):
        for name, row in self.rows():
            seen = {}
            for cls in ('love', 'like', 'dislike', 'hate'):
                for s in row.get(cls, []):
                    if not self.sel_ok(s):
                        self.e('SV5', '%s.%s: selector %s resolves to nothing' % (name, cls, s))
                    if s in seen and seen[s] != cls:
                        self.e('SV6', '%s: %s stands in %s and %s' % (name, s, seen[s], cls))
                    seen[s] = cls
                    if ':' not in s and s in self.items and not self.giftable(self.items[s]) and cls in ('love', 'like'):
                        self.w('SV5', '%s.%s: %s can never be given (not giftable)' % (name, cls, s))

    def sv7(self):
        for n in self.friends:
            loved = sum(1 for i in self.giftable_ids if self.taste(n, i) == 'love')
            liked = sum(1 for i in self.giftable_ids if self.taste(n, i) == 'like')
            if loved < 3:
                self.e('SV7', '%s: only %d giftable loved items' % (n, loved))
            if liked < 6:
                self.w('SV7', '%s: only %d giftable liked items' % (n, liked))

    def sv8(self):
        for n, r in self.cz.items():
            if 'unlock' in r:
                u = r['unlock']
                if not isinstance(u, dict) or not u or ('quest' not in u and 'day' not in u):
                    self.e('SV8', '%s: unlock needs a quest and / or a day' % n)
            if 'sample' in r:
                s = r['sample'] if isinstance(r['sample'], dict) else {}
                item = str(s.get('item', ''))
                if item not in self.items:
                    self.e('SV8', '%s: sample item %s does not exist' % (n, item))
                else:
                    d = self.items[item]
                    if d.get('rarity', 'normal') != 'normal':
                        self.e('SV8', '%s: sample %s is %s, samples are normal items' % (n, item, d.get('rarity')))
                    if d.get('sell_price', 0) > 20:
                        self.e('SV8', '%s: sample %s sells for %s g, samples are <= 20 g' % (n, item, d.get('sell_price')))
                fh = int(s.get('from_hearts', 0))
                if fh < 1 or fh > 10:
                    self.e('SV8', '%s: sample from_hearts %d is not 1..10' % (n, fh))
                if not self.npcs.get(n, {}).get('shop_id'):
                    self.w('SV8', '%s: a sample without a shop_id never reaches the player' % n)

    def sv9(self):
        used = {}
        limit = float(self.day_end - 1)
        for fid, f in self.fests.items():
            m = f.get('meta', {})
            season, day = m.get('season'), int(m.get('day', 0))
            if season not in self.seasons or day < 1 or day > self.dps:
                self.e('SV9', '%s: bad date %s %d' % (fid, season, day))
            key = '%s:%d' % (season, day)
            if key in used:
                self.e('SV9', '%s and %s on the same day %s' % (fid, used[key], key))
            used[key] = fid
            if (day - 1) % 7 < 5:
                self.w('SV9', '%s falls on a weekday (%d)' % (fid, (day - 1) % 7))
            frm, to = float(m.get('from', 0)), float(m.get('to', 0))
            if not (float(self.day_start) <= frm < to <= limit):
                self.e('SV9', '%s: window %s-%s must lie inside %d:00..%s (day_end_hour %d, the bed hold keeps one hour before the pass-out)' % (fid, frm, to, self.day_start, limit, self.day_end))
            if to - frm < 5.0:
                self.w('SV9', '%s: window shorter than 5 game hours' % fid)
            if m.get('host') not in self.npcs:
                self.e('SV9', '%s: host %s is no NPC' % (fid, m.get('host')))
            if m.get('area') not in AREAS:
                self.e('SV9', '%s: area %s' % (fid, m.get('area')))
            if not m.get('spot'):
                self.e('SV9', '%s: no spot (fest_<spot>_host)' % fid)
            if m.get('closes', 'all') not in ('all', 'none'):
                self.e('SV9', '%s: closes must be all or none' % fid)
            for a in f.get('activities', []):
                if a.get('kind') not in ACTIVITY_KINDS:
                    self.e('SV9', '%s.%s: kind %s' % (fid, a.get('id', '?'), a.get('kind')))
                if a.get('kind') in ('contest', 'potluck') and not self.sel_ok(str(a.get('select', ''))):
                    self.e('SV9', '%s.%s: select %s' % (fid, a.get('id', '?'), a.get('select')))
                if a.get('kind') == 'market' and a.get('shop') not in self.shops:
                    self.w('SV9', '%s.%s: market shop %s is not defined yet (the activity stays hidden)' % (fid, a.get('id', '?'), a.get('shop')))
            for s in m.get('stays_open', []):
                if s not in self.shops:
                    self.e('SV9', '%s: stays_open names unknown shop %s' % (fid, s))
            for k in ('opening', 'finale'):
                sc = f.get('scenes', {}).get(k)
                if sc and sc not in self.events:
                    self.w('SV9', '%s: scene %s is not authored yet (the generic scene is used)' % (fid, sc))
            host_shop = self.npcs.get(m.get('host'), {}).get('shop_id')
            for s in m.get('stays_open', []):
                if host_shop and host_shop == s:
                    self.w('SV9', '%s: the host %s keeps the shop %s that stays open (he stands on the stage: the shop would have no keeper)' % (fid, m.get('host'), s))

    def sv10(self):
        key = re.compile(r'^[A-Z0-9_]+$')
        for eid, ev in self.events.items():
            m = ev.get('meta', {})
            chain, cursor = set(), eid
            while cursor:
                if cursor not in self.events:
                    self.e('SV10', '%s: unknown prerequisite %s' % (eid,cursor)); break
                if cursor in chain:
                    self.e('SV10', '%s: cyclic event prerequisite %s' % (eid,cursor)); break
                chain.add(cursor)
                cursor = self.events[cursor].get('meta', {}).get('after', '')
            if m.get('npc') and m['npc'] not in self.npcs:
                self.e('SV10', '%s: npc %s' % (eid, m['npc']))
            if m.get('hearts') is not None and not (1 <= int(m['hearts']) <= 10):
                self.e('SV10', '%s: hearts %s' % (eid, m['hearts']))
            for st in ev.get('steps', []):
                act = st.get('act')
                if act not in STEP_ACTS:
                    self.e('SV10', '%s: unknown step %s' % (eid, act))
                if act == 'say':
                    if st.get('who') != 'player' and st.get('who') not in self.npcs:
                        self.e('SV10', '%s: speaker %s' % (eid, st.get('who')))
                    if not key.match(str(st.get('text_key', ''))):
                        self.e('SV10', '%s: key %s' % (eid, st.get('text_key')))
                if act == 'choice' and not (1 <= len(st.get('options', [])) <= 3):
                    self.e('SV10', '%s: choice with %d options' % (eid, len(st.get('options', []))))
                if act == 'give' and st.get('item') not in self.items:
                    self.e('SV10', '%s: give %s' % (eid, st.get('item')))
            if int(ev.get('rewards', {}).get('points', 0)) > 100:
                self.e('SV10', '%s: reward points %s > one heart' % (eid, ev['rewards']['points']))

    def home_citizens(self, area):
        return sorted(n for n, r in self.npcs.items() if r.get('home_area') == area)

    def sv11(self):
        cap = int(self.social.get('festival', {}).get('max_attendees', 15))
        max_live = int(self.d.get('towns', {}).get('max_live_visuals_festival', 20))
        needs_routes = False
        measured = 0
        for fid, f in self.fests.items():
            m = f.get('meta', {})
            area, host = m.get('area', ''), m.get('host', '')
            home = self.home_citizens(area)
            first, guests = list(m.get('first', [])), list(m.get('guests', []))
            seen = {host: 'host'}
            for x in first:
                if x not in self.npcs:
                    self.e('SV11', '%s: first member %s is no NPC' % (fid, x))
                elif x not in home:
                    self.e('SV11', '%s: first member %s is not a home citizen of %s (a first member is removed from the ordered pool of the area)' % (fid, x, area))
                if x in seen:
                    self.e('SV11', '%s: %s appears twice in the roster (%s and first)' % (fid, x, seen[x]))
                seen[x] = 'first'
            for g in guests:
                if g not in self.npcs:
                    self.e('SV11', '%s: guest %s is no NPC' % (fid, g))
                elif g in home:
                    self.e('SV11', '%s: guest %s IS a home citizen of %s (a guest comes from another area)' % (fid, g, area))
                if g in seen:
                    self.e('SV11', '%s: %s appears twice in the roster (%s and guests)' % (fid, g, seen[g]))
                seen[g] = 'guests'
            crowd = cap + 1 + len(first) + len(guests)
            if crowd > max_live:
                self.e('SV11', '%s: crowd %d (max_attendees %d + host + %d first + %d guests) is above towns.max_live_visuals_festival %d' % (fid, crowd, cap, len(first), len(guests), max_live))
            frm, to = float(m.get('from', 0)), float(m.get('to', 0))
            stays = list(m.get('stays_open', []))
            for who, hours in m.get('leave_early', {}).items():
                hours = float(hours)
                if who not in self.npcs:
                    self.e('SV11', '%s: leave_early names %s, who is no NPC' % (fid, who))
                    continue
                if hours <= 0.0 or hours > to - frm:
                    self.e('SV11', '%s: leave_early %s = %s is not within the window (%s hours)' % (fid, who, hours, to - frm))
                    continue
                if self.routes is None:
                    needs_routes = True
                    continue
                shop = self.npcs.get(who, {}).get('shop_id', '')
                minutes = self.route_minutes(who, m.get('spot', ''))
                if minutes < 0:
                    self.w('SV11', '%s: no route from the %s stage to the counter of %s: leave_early not measured' % (fid, m.get('spot'), who))
                    continue
                deadline = to
                if m.get('closes', 'all') == 'none' or shop in stays:
                    open_h = self.routes.get('shop_open_hour', {}).get(shop)
                    if open_h is not None:
                        oh = float(open_h) + 24.0 if float(open_h) < self.day_start else float(open_h)
                        deadline = min(to, oh)
                need = (1.5 * minutes + 15.0) / 60.0 + (to - deadline)
                measured += 1
                if hours + 1e-9 < need:
                    self.e('SV11', '%s: leave_early %s = %s h is shorter than 1.5 x the %s min walk + 15 min measured from the deadline %s (needs %.2f h)' % (fid, who, hours, minutes, deadline, need))
        self.stats['leave_early_measured'] = measured
        if needs_routes:
            self.skipped.append('SV11: leave_early walk rule not evaluated (no --routes table: the route table of the towns track, T-routes, is not available to this run)')

    def route_minutes(self, npc, spot):
        r = self.routes or {}
        by_npc = r.get('route_minutes', {}).get(npc, {})
        if spot in by_npc:
            return float(by_npc[spot])
        if 'default_route_minutes' in r:
            return float(r['default_route_minutes'])
        return -1.0

    def when_errors(self, spec):
        out = []
        if not spec.strip():
            return out
        for part in spec.split('&'):
            term = part.strip()
            if not term:
                out.append("empty term in '%s'" % spec)
                continue
            body = term[1:].strip() if term.startswith('!') else term
            p = body.split(':', 2)
            kind = p[0].strip()
            arg = p[1].strip() if len(p) > 1 else ''
            rest = p[2].strip() if len(p) > 2 else ''
            if kind not in WHEN_KINDS:
                out.append("unknown kind in '%s'" % term)
                continue
            if kind == 'hearts':
                if self.npcs and arg not in self.npcs:
                    out.append("hearts: unknown npc '%s' in '%s'" % (arg, term))
                if not re.fullmatch(r'-?\d+', rest) or not (0 <= int(rest) <= int(self.social.get('heart_cap', 10))):
                    out.append("hearts: '%s' needs hearts:<npc>:<0..%s> in '%s'" % (rest, self.social.get('heart_cap', 10), term))
            elif kind == 'stage':
                if self.npcs and arg not in self.npcs:
                    out.append("stage: unknown npc '%s' in '%s'" % (arg, term))
                if rest not in self.social.get('stage_order', []) and rest not in self.social.get('rs_stages', []):
                    out.append("stage: unknown stage '%s' in '%s'" % (rest, term))
            elif kind in ('birthday', 'at', 'away'):
                if self.npcs and arg not in self.npcs:
                    out.append("%s: unknown npc '%s' in '%s'" % (kind, arg, term))
            elif kind == 'fest':
                if not arg:
                    out.append("fest: needs an id or any in '%s'" % term)
                elif arg != 'any' and self.fests and arg not in self.fests:
                    out.append("fest: unknown festival '%s' in '%s'" % (arg, term))
            elif kind == 'hour':
                ab = arg.split('-')
                try:
                    a, b = float(ab[0]), float(ab[1])
                    if len(ab) != 2:
                        raise ValueError
                    if not (0.0 <= a <= 26.0 and 0.0 <= b <= 26.0):
                        out.append("hour: hours are 0..26 in '%s'" % term)
                except (ValueError, IndexError):
                    out.append("hour: needs hour:<a>-<b> in '%s'" % term)
            elif kind == 'weekday':
                if not arg:
                    out.append("weekday: needs a list in '%s'" % term)
                for w in [x for x in arg.split(',') if x]:
                    if not re.fullmatch(r'\d+', w) or int(w) > 6:
                        out.append("weekday: '%s' is not 0..6 in '%s'" % (w, term))
            elif kind == 'season':
                if not arg:
                    out.append("season: needs a list in '%s'" % term)
                for s in [x for x in arg.split(',') if x]:
                    if s not in self.seasons:
                        out.append("season: unknown season '%s' in '%s'" % (s, term))
            elif kind == 'open':
                if not arg:
                    out.append("open: needs a shop id in '%s'" % term)
                elif self.shops and arg not in self.shops:
                    out.append("open: unknown shop '%s' in '%s'" % (arg, term))
            elif kind in ('quest', 'done', 'flag'):
                if not arg:
                    out.append("%s: needs an id in '%s'" % (kind, term))
        return out

    def sv12(self):
        for eid, ev in self.events.items():
            for row in [ev.get('meta', {})] + ev.get('steps', []):
                spec = str(row.get('when', ''))
                if spec:
                    for msg in self.when_errors(spec):
                        self.e('SV12', '%s: when=%s: %s' % (eid, spec, msg))

    @staticmethod
    def prize_value(items, entry):
        ids, value = [], 0.0
        if isinstance(entry, str):
            ids.append(entry)
            value = float(items.get(entry, {}).get('sell_price', 0))
        elif isinstance(entry, dict):
            if 'item' in entry:
                ids.append(str(entry['item']))
                value = float(items.get(str(entry['item']), {}).get('sell_price', 0)) * max(int(entry.get('amount', 1)), 1)
            for k, n in (entry.get('items') or {}).items():
                ids.append(str(k))
                value += float(items.get(str(k), {}).get('sell_price', 0)) * int(n)
        return ids, value

    def sv14(self):
        checked = 0
        for fid, f in self.fests.items():
            contests = [a for a in f.get('activities', []) if a.get('kind') == 'contest']
            for act in contests:
                rewards = act.get('rewards') or f.get('rewards', {}).get('contest', {})
                label = '%s.%s' % (fid, act.get('id', '?'))
                if not rewards:
                    self.w('SV14', '%s: a contest without rewards.contest first / second / third' % label)
                    continue
                checked += 1
                values = {}
                for place in ('first', 'second', 'third'):
                    if place not in rewards:
                        if place == 'first':
                            self.e('SV14', '%s: no first prize' % label)
                        continue
                    ids, value = self.prize_value(self.items, rewards[place])
                    if not ids:
                        self.e('SV14', '%s: %s prize names no item' % (label, place))
                    for pid in ids:
                        d = self.items.get(pid)
                        if d is None:
                            self.e('SV14', '%s: %s prize %s does not exist' % (label, place, pid))
                            continue
                        r = d.get('rarity', 'normal')
                        if r in KEEPSAKES or d.get('protected'):
                            self.e('SV14', '%s: %s prize %s is a keepsake' % (label, place, pid))
                        elif r not in PRIZE_RARITIES:
                            self.e('SV14', '%s: %s prize %s has rarity %s (at most rare)' % (label, place, pid, r))
                    values[place] = value
                if 'first' not in values:
                    continue
                cheapest = self.cheapest_winning_entry(str(act.get('select', '')))
                if cheapest <= 0.0:
                    self.e('SV14', '%s: the contest category %s has no giftable entry' % (label, act.get('select')))
                    continue
                cap = min(2.0 * cheapest, 400.0)
                if values['first'] > cap + 1e-6:
                    self.e('SV14', '%s: first prize %s g is above min(2 x the cheapest winning entry %s g, 400 g) = %s g' % (label, values['first'], cheapest, cap))
                if 'second' in values and values['second'] > 0.7 * values['first'] + 1e-6:
                    self.e('SV14', '%s: second prize %s g is above 0.7 x the first (%s g)' % (label, values['second'], values['first']))
                if 'third' in values and values['third'] > 0.4 * values['first'] + 1e-6:
                    self.e('SV14', '%s: third prize %s g is above 0.4 x the first (%s g)' % (label, values['third'], values['first']))
        self.stats['contests_checked'] = checked


def main(argv):
    args = [a for a in argv[1:] if not a.startswith('--')]
    if not args:
        print(__doc__)
        return 2
    routes = None
    for a in argv[1:]:
        if a.startswith('--routes='):
            with open(a[len('--routes='):], encoding='utf-8') as f:
                routes = json.load(f)
    with open(args[0], encoding='utf-8') as f:
        data = json.load(f)
    v = Validator(data, routes).run()
    s = v.stats
    print('friends=%d citizens=%d festivals=%d events=%d giftable items=%d of %d' % (s['friends'], s['citizens'], s['festivals'], s['events'], s['giftable_items'], len(v.items)))
    if '--stats' in argv:
        print('stats: %s' % s)
    for w in v.warnings:
        print('WARN', w)
    for sk in v.skipped:
        print('SKIP', sk)
    for e in v.errors:
        print('ERROR', e)
    print('%d error(s), %d warning(s), %d skipped' % (len(v.errors), len(v.warnings), len(v.skipped)))
    if '--strict-skips' in argv and v.skipped:
        return 1
    return 1 if v.errors else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
