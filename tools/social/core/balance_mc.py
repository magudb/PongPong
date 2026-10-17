#!/usr/bin/env python3
"""Monte Carlo of the social economy (hearts pace, gift economy, time budget, exploit ceilings) for the numbers of lua/social/social.lua - package S-core.

It plays 3 player profiles x N seeds x 336 game days (3 years) over the REAL data: a JSON dump of citizens (tiers), gift tastes, item prices, festivals and the
social config (tests/lib/social/dump_social_json.gd writes it from the live LuaRuntime; tests/lib/social/fixtures/design_dump.json is the pinned design snapshot).
Every constant is READ from the dump (M), taken from the plan (S) or an ASSUMPTION (A, flagged and parameterised in PROFILES). The rolls use the same portable
mixer as the game (social_rng_mirror.py), so a run is reproducible: the same data gives the same numbers on every machine.

TWO AVAILABILITY VARIANTS (the section asserts the claims in both):
  free   the designers' model: the player may talk to ANYBODY every day;
  mixed  town visits at random hours, half in the daytime (09-17) and half in the evening (17 to half an hour before the live day ends); a citizen is reachable when he stands outdoors, walks, or - a
         keeper - stands at his counter (the `talk` cells), table = availability.py (the routines of the towns track; until T-routes lands the pinned design snapshot).
EVENTS: lean = heart events of tier A at 4 and 8 hearts (the LEAN content scope); four = tier A at 4, 6, 8, 10 (S-heart-content); target = the ROADMAP rows.

    python3 -I balance_mc.py --dump=FILE [--variant=free|mixed] [--availability=FILE] [--events=lean|four|target] [--runs=100] [--days=336] [--jobs=N] [--json=OUT] [--quiet]
    python3 -I balance_mc.py ... --bounds=FILE --check          assert the claims against the ratcheted bounds (exit 1 on a violation)
    python3 -I balance_mc.py ... --bounds=FILE --write-bounds   the FIRST accepted run: write the bounds file (measured + margin, never above the design limits)
    python3 -I balance_mc.py ... --bounds=FILE --ratchet        a later run: every bound may only get TIGHTER (measured + margin when that is lower), never looser

THE CLAIMS (CLAIM_LIMITS below are the design's numbers; the ratcheted bounds file sits at or under them): weekly chat alone reaches 8 hearts on day 50; the fastest
possible 10 hearts is day 32; a typical player (2.6 talks per original nine-minute day, scaled with the live clock) with the lean events reaches 8 hearts with a tier A citizen with median <= 80 / p90 <= 115 in
BOTH variants, with four events <= 75 / <= 110; gifts are <= 25 % of all points for a dedicated player; the typical profile spends <= 25 % of a game week on it; and no
tier A or B citizen is `never` reached by the typical profile in more than 2 % of the runs in the mixed variant.
"""
import argparse
import collections
import json
import multiprocessing
import os
import statistics as st
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from social_rng_mirror import roll   # noqa: E402
import availability as AV            # noqa: E402

SEASONS = ['foraar', 'sommer', 'efteraar', 'vinter']
DPS = 28
YEAR = DPS * len(SEASONS)
PROFILES = {
    # talks = mean conversations per game day (A: calibrated to a share of the 10 real minutes of a day at 32 s per visit: casual ~5 %, typical ~15 %, dedicated ~35 %);
    # seek = how strongly the player prefers an NPC whose weekly chat is still open; gift_p = chance to give a gift when allowed; cls = quality of the chosen gift
    'casual': dict(talks=0.9, seek=1.5, gift_p=0.08, cls={'love': .05, 'like': .15, 'neutral': .60, 'dislike': .15, 'hate': .05}, p_bday=0.20, p_fest=0.5, ev=0.5, rare={'uncommon': .05, 'rare': .01}),
    'typical': dict(talks=2.6, seek=3.0, gift_p=0.30, cls={'love': .20, 'like': .30, 'neutral': .40, 'dislike': .07, 'hate': .03}, p_bday=0.60, p_fest=0.8, ev=0.9, rare={'uncommon': .10, 'rare': .03}),
    'dedicated': dict(talks=5.5, seek=6.0, gift_p=0.85, cls={'love': .60, 'like': .30, 'neutral': .10, 'dislike': 0, 'hate': 0}, p_bday=0.95, p_fest=1.0, ev=1.0, rare={'uncommon': .15, 'rare': .08}),
}
TIER_W = {'A': 3.0, 'B': 2.0, 'C': 0.5}
EVENT_SETS = {
    'lean': {'A': [4, 8], 'B': [], 'C': []},
    'four': {'A': [4, 6, 8, 10], 'B': [], 'C': []},
    'target': {'A': [2, 4, 6, 8, 10], 'B': [4, 8], 'C': []},
}
EVENT_POINTS = 40
QUEST_HEARTS = [('pippin_boegeknop', 2, 40), ('fairy_king', 2, 150), ('fairy_wizard', 2, 120), ('guard_oak', 2, 100), ('fairy_king', 3, 300)]   # (npc, hearts, typical day) S: lua/quests/*.lua rewards.friendship
T_CHAT, T_GIFT, T_WALK = 20.0, 25.0, 12.0     # seconds (A)
DESIGN_DAY_REAL_SECONDS = 540.0  # Original profile calibration: 06:00–24:00 at 2 game min/s
HEARTS = (2, 4, 8, 10)

# the claims the section asserts, as upper limits (a median / p90 in days, a share in 0..1) - the DESIGN's numbers; the bounds file may only be at or under them
CLAIM_LIMITS = {
    'lean.free.A8.median': 80, 'lean.free.A8.p90': 115, 'lean.mixed.A8.median': 80, 'lean.mixed.A8.p90': 115,
    'four.free.A8.median': 75, 'four.free.A8.p90': 110, 'four.mixed.A8.median': 75, 'four.mixed.A8.p90': 110,
    'dedicated.gift_share': 0.25, 'typical.social_time': 0.25, 'mixed.never_AB_8h': 0.02, 'mixed.never_AB_4h_citizen': 0.02,
    'mixed.never_AB_8h_citizen': 0.05,          # S-core's own guard (the design pins the 2 % claim at the tier / 4 heart level; Rasmus sits at 3 % at 8 hearts)
}
MARGIN_DAYS = 4          # a bound sits at most this many days (or 2 percentage points for a share) above what the run measured: the margin cannot silently grow


def pct(xs, q):
    xs = sorted(xs)
    if not xs:
        return None
    return xs[min(len(xs) - 1, int(q * len(xs)))]


_MODEL = None      # the model the forked workers of Model.play_all play (set just before the fork)


def _play_task(task):
    return _MODEL.play(task[0], task[1])


class Model:
    def __init__(self, dump, variant, availability, events):
        self.D = dump
        time = dump['time']
        self.day_end = float(time.get('day_end_hour', 24))
        self.day_seconds = (self.day_end - float(time.get('day_start_hour', 6))) * 3600 / (float(time.get('minutes_per_real_second', 2)) * 60)
        self.visit_scale = self.day_seconds / DESIGN_DAY_REAL_SECONDS
        self.week_minutes = self.day_seconds * 7 / 60
        self.soc = dump['social']
        self.G = self.soc['gifts']
        self.PPH = self.soc['points_per_heart']
        self.CAP = self.soc['heart_cap'] * self.PPH
        self.items, self.cz, self.tastes, self.npcs = dump['items'], dump['citizens'], dump['gift_tastes'], dump['npcs']
        self.friends = sorted(n for n, r in self.npcs.items() if r.get('friendship') or 'unlock' in self.cz.get(n, {}))
        self.tier = {n: self.cz.get(n, {}).get('tier', 'C') for n in self.friends}
        self.bday = {n: SEASONS.index(self.cz[n]['birthday']['season']) * DPS + self.cz[n]['birthday']['day'] for n in self.friends if n in self.cz}
        self.fest_days = sorted((SEASONS.index(f['meta']['season']) * DPS + f['meta']['day'], f['meta']['host']) for f in dump['festivals'].values())
        self.variant, self.av, self.events = variant, availability, EVENT_SETS[events]
        if variant == 'mixed':
            missing = sorted(set(self.friends) - set(availability['npcs']))
            if missing:
                raise ValueError('Availability is missing current citizens: '+', '.join(missing)+'. Re-export the live routines.')
            empty = [n for n in self.friends if not any(spans for day in availability['npcs'][n].values() for spans in day.values())]
            if empty:
                raise ValueError('Availability has no routine spans for: '+', '.join(empty))
        self.rain_p = {s: dump['time']['weather_chances'][s].get('regn', 0) + dump['time']['weather_chances'][s].get('torden', 0) for s in SEASONS}
        self.gi = sorted(i for i in self.items if self._giftable(i))
        self.cost_by_class = {}
        for n in self.friends:
            by = collections.defaultdict(list)
            for i in self.gi:
                by[self._taste(n, i)].append(self.items[i].get('sell_price', 0))
            self.cost_by_class[n] = {c: (sum(sorted(v)[:max(1, len(v) // 4)]) / max(1, len(v[:max(1, len(v) // 4)])) if v else 0) for c, v in by.items()}

    def _giftable(self, i):
        d = self.items[i]
        if d.get('rarity', 'normal') in ('unique', 'legendary') or d.get('protected'):
            return False
        if 'giftable' in d:
            return d['giftable']
        if d.get('category') in ('quest', 'special', 'animal', 'building', 'blueprint'):
            return False
        return d.get('sell_price', 0) > 0

    def _sels(self, i):
        d = self.items[i]
        s = {i: 4}
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

    def _match(self, row, sels):
        best, bs, br = None, 0, 99
        for ci, c in enumerate(('hate', 'dislike', 'love', 'like')):
            for e in row.get(c, []):
                if e in sels:
                    sp = sels[e]
                    if sp > bs or (sp == bs and ci < br):
                        best, bs, br = c, sp, ci
        return best

    def _taste(self, n, i):
        s = self._sels(i)
        arch = self.cz.get(n, {}).get('archetype', 'wanderer')
        for row in (self.tastes['npcs'].get(n, {}), self.tastes['archetypes'].get(arch, {}), self.tastes['universal']):
            m = self._match(row, s)
            if m:
                return m
        return 'neutral'

    def visit_hour(self, seed, day, j):
        if self.variant != 'mixed':
            return None
        u = roll(seed, [day, 'vh', j])
        return (9.0 + 8.0 * roll(seed, [day, 'vh2', j])) if u < 0.5 else (17.0 + (self.day_end - 0.5 - 17.0) * roll(seed, [day, 'vh3', j]))

    def talkable(self, n, wd, hour, rain, hearts=None):
        return AV.talkable(self.av, n, wd, hour, rain, hearts)

    def play(self, profile, seed):
        P, G, PPH, CAP = PROFILES[profile], self.G, self.PPH, self.CAP
        friends, tier, cz = self.friends, self.tier, self.cz
        pts = {n: 0 for n in friends}
        wk_chat = {n: -1 for n in friends}
        gw = {n: (-1, 0) for n in friends}
        gd = {n: 0 for n in friends}
        ev_done = collections.defaultdict(set)
        reach = {n: {h: None for h in HEARTS} for n in friends}
        src = collections.Counter()
        last = {n: {} for n in friends}
        secs_week = collections.defaultdict(float)
        gold = collections.Counter()
        gifts_given = 0
        met = set()
        r = lambda *parts: roll(seed, list(parts))      # noqa: E731

        def add(n, p, s, day):
            if p <= 0:
                return
            pts[n] = min(CAP, pts[n] + p)
            src[s] += p
            h = pts[n] // PPH
            for hh in HEARTS:
                if h >= hh and reach[n][hh] is None:
                    reach[n][hh] = day

        for day in range(1, self.days + 1):
            week = (day - 1) // 7
            talks = P['talks'] * self.visit_scale
            k = int(talks) + (1 if r(day, 'k') < talks - int(talks) else 0)
            pool = [n for n in friends if not ('unlock' in cz.get(n, {}) and day < 60)]
            chosen = []
            wd = (day - 1) % 7
            rain = r(day, 'wx') < self.rain_p[SEASONS[((day - 1) % YEAR) // DPS]]
            current_hearts = {n: pts[n] // PPH for n in friends}
            for j in range(k):
                hr = self.visit_hour(seed, day, j)
                cand = [n for n in pool if n not in chosen and (hr is None or self.talkable(n, wd, hr, rain, current_hearts))]
                ws = [(TIER_W[tier[n]] * (P['seek'] if wk_chat[n] != week else 1.0), n) for n in cand]
                tot = sum(w for w, _ in ws)
                if not ws:
                    continue
                u = r(day, 'pick', j) * tot
                acc = 0
                for w, n in ws:
                    acc += w
                    if u < acc:
                        chosen.append(n)
                        break
            for fd, fh in self.fest_days:
                if fd == day and r(fh, day, 'fest') < P['p_fest'] and fh in pool and fh not in chosen:
                    add(fh, self.soc['festival']['attend_points'], 'festival', day)
            for n in chosen:
                tt = tier[n]
                met.add(n)
                secs_week[week] += T_WALK + T_CHAT
                if wk_chat[n] != week:
                    wk_chat[n] = week
                    add(n, self.soc['chat_points'], 'chat', day)
                h = pts[n] // PPH
                for eh in self.events[tt]:
                    if h >= eh and eh not in ev_done[n] and r(n, day, 'ev', eh) < P['ev']:
                        ev_done[n].add(eh)
                        add(n, EVENT_POINTS, 'event', day)
                        secs_week[week] += 60.0
                is_b = self.bday.get(n) == (day - 1) % YEAR + 1
                wg = gw[n][1] if gw[n][0] == week else 0
                if gd[n] != day and (wg < G['per_week'] or is_b) and r(n, day, 'gift') < (P['gift_p'] if not is_b else max(P['gift_p'], P['p_bday'])):
                    u = r(n, day, 'cls')
                    acc = 0
                    cls = 'neutral'
                    for c, pr in P['cls'].items():
                        acc += pr
                        if u < acc:
                            cls = c
                            break
                    u2 = r(n, day, 'rar')
                    rar = 1.0
                    if u2 < P['rare']['rare']:
                        rar = G['rarity_rare']
                    elif u2 < P['rare']['rare'] + P['rare']['uncommon']:
                        rar = G['rarity_uncommon']
                    base = G[cls]
                    mult = rar * (G['birthday_mult'] if is_b else 1.0)
                    if last[n].get(cls) is not None and day - last[n][cls] < G['repeat_days'] and cls in ('love', 'like'):
                        mult *= G['repeat_mult']
                    gain = min(G['max_points'], int(round(base * mult))) if base > 0 else 0
                    last[n][cls] = day
                    add(n, gain, 'gift_birthday' if is_b else 'gift', day)
                    gd[n] = day
                    if not is_b:
                        gw[n] = (week, wg + 1)
                    gifts_given += 1
                    secs_week[week] += T_GIFT
                    gold[n] += self.cost_by_class[n].get(cls, 0)
        for n, h, d in QUEST_HEARTS:
            if n in pts and d <= self.days and r(n, d, 'q') < 0.9:
                add(n, h * PPH, 'quest', d)
        return dict(pts=pts, reach=reach, src=src, secs=secs_week, gold=gold, gifts=gifts_given, met=len(met))

    def play_all(self, runs, jobs):
        """Every (profile, seed) game in the order profile-major, seed-minor. A game depends on nothing but (profile, seed) and the model, so the games can be
        spread over `jobs` forked workers: the results come back in the same order and the numbers are byte for byte the sequential ones."""
        tasks = [(prof, 1000 + run) for prof in PROFILES for run in range(runs)]
        if jobs <= 1 or len(tasks) < 8:
            return [self.play(prof, seed) for prof, seed in tasks]
        global _MODEL
        _MODEL = self
        with multiprocessing.get_context('fork').Pool(jobs) as pool:
            return pool.map(_play_task, tasks, chunksize=max(1, len(tasks) // (jobs * 4)))

    def run(self, runs, days, jobs=1):
        self.days = days
        friends, tier = self.friends, self.tier
        out = {}
        never_npc = {}
        games = iter(self.play_all(runs, jobs))
        for prof in PROFILES:
            reach_days = {t: {h: [] for h in HEARTS} for t in 'ABC'}
            never = {t: {h: 0 for h in HEARTS} for t in 'ABC'}
            per_never = {n: {4: 0, 8: 0} for n in friends}
            total_h, shares, week_mean, week_peak = [], collections.Counter(), [], []
            for run in range(runs):
                res = next(games)
                for n in friends:
                    for h in HEARTS:
                        d = res['reach'][n][h]
                        if d is None:
                            never[tier[n]][h] += 1
                            if h in (4, 8):
                                per_never[n][h] += 1
                        else:
                            reach_days[tier[n]][h].append(d)
                total_h.append(sum(p // self.PPH for p in res['pts'].values()))
                for s, v in res['src'].items():
                    shares[s] += v
                week_peak.append(max(res['secs'].values()) / 60.0 / self.week_minutes)
                week_mean.append(sum(res['secs'].values()) / len(res['secs']) / 60.0 / self.week_minutes)
            tot = sum(shares.values())
            out[prof] = dict(
                reach={t: {h: dict(median=pct(reach_days[t][h], .5), p10=pct(reach_days[t][h], .1), p90=pct(reach_days[t][h], .9),
                                   never=never[t][h] / (runs * max(1, sum(1 for n in friends if tier[n] == t)))) for h in HEARTS} for t in 'ABC'},
                hearts_total=st.mean(total_h), share={s: round(v / tot, 4) for s, v in shares.items()}, week_mean=st.mean(week_mean), week_peak=st.mean(week_peak))
            never_npc[prof] = {n: {str(h): per_never[n][h] / runs for h in (4, 8)} for n in friends}
        return out, never_npc

    def ceilings(self):
        G, PPH, CAP = self.G, self.PPH, self.CAP
        chat = self.soc['chat_points']
        best_gift = min(G['max_points'], int(round(G['love'] * G['rarity_rare'])))
        per_week = chat + G['per_week'] * best_gift
        fastest_weeks = CAP / per_week
        return dict(best_gift=best_gift, per_week=per_week, fastest_10_hearts_day=round(fastest_weeks * 7),
                    chat_only_8_day=int((8 * PPH / chat - 1) * 7 + 1), chat_only_10_day=int(CAP / chat * 7 - 6),
                    birthday_best=min(G['max_points'], int(round(G['love'] * G['rarity_rare'] * G['birthday_mult']))), repeat_halves=int(G['love'] * G['repeat_mult']))


def claims_of(model, out, never_npc, events, variant):
    t = out['typical']
    a8 = t['reach']['A'][8]
    typical_never = never_npc['typical']
    ab = [n for n in model.friends if model.tier[n] in 'AB']
    return {
        '%s.%s.A8.median' % (events, variant): a8['median'], '%s.%s.A8.p90' % (events, variant): a8['p90'],
        'dedicated.gift_share': round(sum(v for s, v in out['dedicated']['share'].items() if s.startswith('gift')) / max(sum(out['dedicated']['share'].values()), 1e-9), 4),
        'typical.social_time': round(t['week_mean'], 4),
        # the share of (citizen, run) pairs of a tier that never reach 8 hearts; the worst single citizen at 4 hearts (the claim) and at 8 hearts (an own guard of S-core)
        '%s.never_AB_8h' % variant: round(max(t['reach'][tier]['8']['never'] if '8' in t['reach'][tier] else t['reach'][tier][8]['never'] for tier in 'AB'), 4),
        '%s.never_AB_4h_citizen' % variant: round(max((typical_never[n]['4'] for n in ab), default=0.0), 4),
        '%s.never_AB_8h_citizen' % variant: round(max((typical_never[n]['8'] for n in ab), default=0.0), 4),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--dump', required=True)
    ap.add_argument('--variant', choices=['free', 'mixed'], default='free')
    ap.add_argument('--availability', default=os.path.join(HERE, '..', '..', '..', 'tests', 'lib', 'social', 'fixtures', 'availability_design.json'))
    ap.add_argument('--events', choices=sorted(EVENT_SETS), default='lean')
    ap.add_argument('--runs', type=int, default=100)
    ap.add_argument('--days', type=int, default=336)
    ap.add_argument('--json')
    ap.add_argument('--quiet', action='store_true')
    ap.add_argument('--jobs', type=int, default=0, help='worker processes (0 = up to 4 of the cores, 1 = sequential); the numbers do not depend on it')
    ap.add_argument('--bounds')
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--write-bounds', action='store_true')
    ap.add_argument('--ratchet', action='store_true')
    a = ap.parse_args()
    with open(a.dump, encoding='utf-8') as f:
        dump = json.load(f)
    table = AV.load(a.availability) if a.variant == 'mixed' else None
    model = Model(dump, a.variant, table, a.events)
    jobs = a.jobs if a.jobs > 0 else min(4, os.cpu_count() or 1)
    out, never_npc = model.run(a.runs, a.days, jobs)
    ceil = model.ceilings()
    claims = claims_of(model, out, never_npc, a.events, a.variant)
    result = {'variant': a.variant, 'events': a.events, 'runs': a.runs, 'days': a.days, 'friends': len(model.friends), 'tiers': dict(collections.Counter(model.tier.values())),
              'giftable': len(model.gi), 'profiles': out, 'never_8h_by_npc': never_npc['typical'], 'ceilings': ceil, 'claims': claims,
              'availability_source': (table or {}).get('source', ''),
              'assumptions': {'day_real_seconds': model.day_seconds, 'week_real_minutes': model.week_minutes, 'mean_talks_per_day': {p: round(v['talks'] * model.visit_scale, 4) for p, v in PROFILES.items()}, 'day_visits': [9, 17], 'evening_visits': [17, model.day_end - .5], 'visit_mix': [.5, .5], 'seconds_per_chat': T_CHAT, 'seconds_per_walk': T_WALK, 'seconds_per_gift': T_GIFT}}
    if not a.quiet:
        print('friends=%d tiers=%s giftable=%d runs=%d days=%d variant=%s events=%s' % (result['friends'], result['tiers'], result['giftable'], a.runs, a.days, a.variant, a.events))
        for prof, o in out.items():
            print('\n=== %s: total hearts after %d days = %.0f; mean weekly social time = %.0f%% of a game week (peak week %.0f%%)' % (prof, a.days, o['hearts_total'], o['week_mean'] * 100, o['week_peak'] * 100))
            print('    sources of points: ' + ', '.join('%s %.0f%%' % (k, v * 100) for k, v in sorted(o['share'].items(), key=lambda kv: -kv[1])))
            for t_ in 'ABC':
                print('    tier %s: ' % t_ + ' | '.join('%dh: day %s (p10 %s, p90 %s, never %.0f%%)' % (h, o['reach'][t_][h]['median'], o['reach'][t_][h]['p10'], o['reach'][t_][h]['p90'], o['reach'][t_][h]['never'] * 100) for h in HEARTS))
        print('\n=== ceilings (no randomness): %s' % ceil)
        print('=== claims: %s' % claims)
    if a.json:
        with open(a.json, 'w', encoding='utf-8') as f:
            json.dump(result, f, separators=(',', ':'), ensure_ascii=False)
    if a.bounds and (a.check or a.write_bounds or a.ratchet):
        return bounds_main(a, claims, ceil)
    return 0


def limit_for(key):
    """The design limit of a claim key; the same limit for both variants where the table has a `mixed.*` / `free.*` twin only once (never_AB_8h)."""
    return CLAIM_LIMITS.get(key)


def bounds_main(a, claims, ceil):
    bounds = {}
    if os.path.exists(a.bounds):
        with open(a.bounds, encoding='utf-8') as f:
            bounds = json.load(f)
    claim_bounds = bounds.setdefault('claims', {})
    bounds.setdefault('version', 1)
    bounds.setdefault('margin_days', MARGIN_DAYS)
    bad = 0
    for key, value in claims.items():
        limit = limit_for(key)
        if limit is None or value is None:
            continue
        margin = MARGIN_DAYS if limit > 1 else 0.02
        proposal = min(limit, value + margin)
        if a.write_bounds and key not in claim_bounds:
            claim_bounds[key] = round(proposal, 4)
        if a.ratchet and key in claim_bounds:
            claim_bounds[key] = round(min(claim_bounds[key], proposal), 4)      # tighter only
        if a.check:
            have = claim_bounds.get(key)
            if have is None or value > have:
                print('FAIL %s measured %s is above the ratcheted bound %s' % (key, value, have))
                bad += 1
            else:
                print('PASS %s measured %s <= bound %s (design limit %s)' % (key, value, have, limit))
    if a.check:
        want = {'fastest_10_hearts_day': 32, 'chat_only_8_day': 50}
        for k, v in want.items():
            ok = ceil.get(k) == v
            print('%s ceilings.%s = %s (design %s)' % ('PASS' if ok else 'FAIL', k, ceil.get(k), v))
            bad += 0 if ok else 1
    if a.write_bounds or a.ratchet:
        with open(a.bounds, 'w', encoding='utf-8') as f:
            json.dump(bounds, f, indent=1, sort_keys=True)
            f.write('\n')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
