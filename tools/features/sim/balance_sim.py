#!/usr/bin/env python3
"""Balance simulation for home tiers, drop rates and the shop economy.

Reads the DATA (real-Lua dumps of the stage tree and of the repo's lua/; both are written by tools/features/validate/run_validate.sh into tools/features/reports/), never a generator.
Deterministic (expected values), no RNG except where stated.  Every assumption is a named constant in the ASSUMPTIONS block and is printed with the results.

    python3 tools/features/sim/balance_sim.py [--lua-dump F] [--repo-lua-dump F] [--out F] [--json F] [--crops plan|repo|both] [--quests repo|stage]
    tools/features/sim/run_balance.sh [--quests repo|stage]            # runs the validator's dumps first, then the sim, writes tools/features/reports/balance_output_<quests>.txt

--quests repo   the quests that REALLY exist in the repo now (until P13 lands lost_cat is the legacy REPEATABLE quest: about one hour less than the reviewed figure)
--quests stage  the reviewed quests of the stage tree (what P13 delivers: lost_cat one-shot with the reviewed rewards) = the figures of docs/features/BALANCE.md
Prices (items, shops, crops) are always the repo's: rerun after P12 has its real prices.
"""
from __future__ import annotations
import argparse
import json
import math
import sys
from collections import OrderedDict, defaultdict
from pathlib import Path

# ====================================================================================================================================
# ASSUMPTIONS (all of them; change here, re-run)
# ====================================================================================================================================
REAL_MIN_PER_DAY = 10.0                    # CLOCK_26: 06:00-02:00 (20 game hours) at 2 game minutes per real second = 600 s
DAYS_PER_HOUR = 60.0 / REAL_MIN_PER_DAY    # 6.000 game days per real hour
SEASONS = ['foraar', 'sommer', 'efteraar', 'vinter']
# crop tables: PLAN 3.10 (binding for the 2D rewrite) and the CURRENT repo (lua/items/crops.lua + game_balance.lua); seed, grow days, seasons, sell
CROPS_PLAN = {
    'turnip':     (20, 4, ('foraar', 'sommer'), 45),
    'carrot':     (20, 4, ('foraar', 'sommer', 'efteraar'), 65),
    'strawberry': (45, 4, ('foraar',), 55),
    'sunflower':  (30, 7, ('sommer', 'efteraar'), 70),
    'catnip':     (35, 5, ('foraar', 'sommer'), 55),
    'pumpkin':    (60, 10, ('efteraar',), 160),
    'moonflower': (120, 12, ('sommer', 'efteraar'), 180),
}
CROPS_REPO = {   # filled from the repo dump at run time (seed price, stages x days_per_stage, seasons, sell price)
}
PROFILES = OrderedDict([
    # plots_cap: plots tended at full stretch; tau: days to 63 percent of the cap; eff: share of days a plot is watered on time; runs: forest runs per day;
    # dig_share: share of the day's dig spots dug during a run; zones: day each forest area is first visited; invest_scale: stretches the fixed purchase schedule;
    # lifestyle: share of net income spent on furniture/clothes/gifts/etc. (reduces money available for the home); quests: share of the repeatable quests done
    ('casual',    dict(plots_cap=30, tau=25, eff=0.55, runs=0.15, dig_share=0.35, zones=dict(skovkant=2, dybe_bregner=28, svampelunden=50, krystalgrotten=85), invest_scale=1.6, lifestyle=0.30, quests=0.15,
                       crops=('turnip', 'carrot', 'pumpkin', 'sunflower'), gate_days=dict(intro_lottery=3, first_animal=45, crystal_cave=95, snurresvampen=120, moonstone_crown=150, mayor_hearts_per_day=1 / 16, fairy_friendship=60))),
    ('typical',   dict(plots_cap=70, tau=20, eff=0.70, runs=0.35, dig_share=0.50, zones=dict(skovkant=1, dybe_bregner=12, svampelunden=25, krystalgrotten=40), invest_scale=1.0, lifestyle=0.25, quests=0.30,
                       crops=('turnip', 'carrot', 'pumpkin', 'sunflower', 'strawberry', 'catnip'), gate_days=dict(intro_lottery=2, first_animal=20, crystal_cave=50, snurresvampen=60, moonstone_crown=75, mayor_hearts_per_day=1 / 10, fairy_friendship=30))),
    ('dedicated', dict(plots_cap=110, tau=15, eff=0.85, runs=0.60, dig_share=0.70, zones=dict(skovkant=1, dybe_bregner=6, svampelunden=12, krystalgrotten=20), invest_scale=0.7, lifestyle=0.20, quests=0.50,
                       crops=('turnip', 'carrot', 'pumpkin', 'sunflower', 'strawberry', 'catnip', 'moonflower'), gate_days=dict(intro_lottery=1, first_animal=12, crystal_cave=30, snurresvampen=35, moonstone_crown=45, mayor_hearts_per_day=1 / 7, fairy_friendship=18))),
])
INVEST = [(8, 400), (20, 600), (28, 500), (40, 650), (55, 800), (80, 1200), (110, 1500), (160, 2500)]   # day, gold: iron hoe, gold can, iron pickaxe, coop+chick, field expansion, barn+animals, sword/tools, more animals
# per full clear of an area (PLAN 4.3 node counts x repo sell prices); respawn ore_respawn_days = 3 (game_balance.adventure)
NODE_YIELD = {
    'skovkant':       dict(gold=70, items={'moss': 2, 'wood': 4}),
    'dybe_bregner':   dict(gold=60, items={'moonstone': 1.0}),
    'svampelunden':   dict(gold=170, items={'rare_mushroom': 2}),
    'krystalgrotten': dict(gold=0, items={'amethyst': 3, 'emerald': 2, 'moonstone': 1.0, 'iron_ore': 2, 'copper_ore': 1, 'gold_ore': 1}),
}
NODE_RESPAWN = 3
BOSS_REPEAT_DAYS = 7
SELF_CRAFT_DISCOUNT = {'plank_pine': 0.6, 'timber_beam': 0.6, 'stone_block': 0.6, 'lime': 0.6, 'rope': 0.6}   # part of these comes from the player's own wood/stone/moss
QUEST_ONESHOT_EXTRA = 0.0   # gold of one-shot quests is added via the quest table below
ZONE_ORDER = ['skovkant', 'dybe_bregner', 'svampelunden', 'krystalgrotten']
PRICES_ASSUMED = {'copper_ore': (35, 14), 'moonstone': (440, 220), 'wool': (30, 12)}   # PLAN items not yet in the repo
HYGGE_PER_GOLD = 0.0150      # decor points per gold spent on furniture (from the shop price list: normal 17.8, uncommon 14, rare 6.1 per 1000 gold)
FURNITURE_SHARE = 0.55       # of the lifestyle budget
SIM_DAYS = 1500
QUEST_NET = 0.60             # share of a repeatable quest's gold that is NOT eaten by the goods it asks for (turnips, ore, ...)
QUEST_START_DAY = 8          # repeatable quests start flowing after the first week


# ====================================================================================================================================
def load(args):
    mine = {d['file']: d['globals'] for d in json.loads(Path(args.lua_dump).read_text())}
    repo = {d['file']: d['globals'] for d in json.loads(Path(args.repo_lua_dump).read_text())}
    if args.quests == 'stage':
        repo = dict(repo)
        repo.update({f: g for f, g in mine.items() if f.startswith('lua/quests/')})     # the reviewed quests replace the repo's
    return mine, repo


class World:
    def __init__(self, mine, repo, crops_mode, cost_scale=None):
        self.items = {}
        for f, g in repo.items():
            if f.startswith('lua/items/'):
                self.items.update(g.get('items', {}))
        for f, g in mine.items():
            if f.startswith('lua/items/'):
                self.items.update(g.get('items', {}))
        for k, (b, s) in PRICES_ASSUMED.items():
            self.items.setdefault(k, dict(buy_price=b, sell_price=s))
        self.home = mine['lua/data/home_tiers.lua']['config']['home']
        self.loot = mine['lua/data/loot_tables.lua']['config']['loot']
        self.shops = mine['lua/shops/home_shops.lua']['shops']
        self.recipes = {**mine['lua/recipes/furniture.lua']['recipes'], **mine['lua/recipes/materials.lua']['recipes']}
        self.rarity = mine['lua/config/rarity.lua']['config']
        self.sets = mine['lua/data/sets.lua']['config']
        bal = repo['lua/config/game_balance.lua']['config']
        self.bal = bal
        # the knob economy.home_cost_scale of game_balance.lua (P10) scales the GOLD price of every tier; --home-cost-scale overrides it for a what-if run
        self.cost_scale = float(cost_scale if cost_scale is not None else (bal.get('economy') or {}).get('home_cost_scale', 1.0))
        if self.cost_scale != 1.0:
            self.home = json.loads(json.dumps(self.home))
            for tier in self.home['tiers']:
                if tier.get('cost'):
                    tier['cost']['gold'] = int(round(tier['cost']['gold'] * self.cost_scale))
        self.quests = {f.split('/')[-1][:-4]: g for f, g in repo.items() if f.startswith('lua/quests/')}
        if crops_mode == 'plan':
            self.crops = dict(CROPS_PLAN)
        else:
            self.crops = {}
            for cid, c in bal['crops'].items():
                seed = self.items[cid + '_seeds']['buy_price']
                self.crops[cid] = (seed, c['stages'] * c['days_per_stage'], tuple(c['seasons']), c['sell_price'])
        self.crops_mode = crops_mode

    def buy(self, i):
        return self.items[i]['buy_price']

    def sell(self, i):
        return self.items[i]['sell_price']


# ====================================================================================================================================
# farm
# ====================================================================================================================================
def best_crop(world, prof, season):
    best = None
    for cid, (seed, days, seasons, sell) in world.crops.items():
        if cid not in prof['crops'] or season not in seasons:
            continue
        cycle = days / prof['eff'] + 1.0
        usable = max(0.0, 28 - days * 0.5) / 28
        ppd = (sell - seed) / cycle * usable
        if best is None or ppd > best[1]:
            best = (cid, ppd)
    return best or (None, 0.0)


def plots(prof, day):
    return max(5.0, prof['plots_cap'] * (1 - math.exp(-day / prof['tau'])))


# ====================================================================================================================================
# loot expectations
# ====================================================================================================================================
def pool_value(world, zone, kind, rar):
    """expected sell value of one draw from pools[kind][rar] and expected material counts"""
    pool = world.loot['zones'][zone]['pools'][kind][rar]
    tw = sum(e['w'] for e in pool)
    if tw == 0:
        return None
    val = sum(e['w'] * world.sell(e['item']) for e in pool) / tw
    mats = {e['item']: e['w'] / tw for e in pool} if kind == 'material' else {}
    return val, mats


def roll_ev(world, zone, odds, kinds, find):
    """expected result of ONE ordinary roll: (sell value of furniture/clothing found, {material: count}, P(rare+ item), P(any item))"""
    val, mats, p_rare = 0.0, defaultdict(float), 0.0
    for rar, o in odds.items():
        if o <= 0:
            continue
        pr = o / 10000.0
        avail = {k: w for k, w in kinds.items() if pool_value(world, zone, k, rar)}
        tw = sum(avail.values())
        for k, w in avail.items():
            pk = w / tw
            v, m = pool_value(world, zone, k, rar)
            if k == 'material':
                for mid, c in m.items():
                    mats[mid] += find * pr * pk * c
                val += find * pr * pk * 0.0
            else:
                val += find * pr * pk * v
            if rar in ('rare',):
                p_rare += find * pr * pk
    return val, dict(mats), p_rare, find


def container_ev(world, zone, cid):
    spec = world.loot['zones'][zone]['containers'][cid]
    base = world.loot['containers'][cid]
    odds = spec.get('odds', base['odds'])
    kinds = spec.get('kinds', base['kinds'])
    find = spec.get('find_chance', base['find_chance'])
    rolls = (base['rolls']['min'] + base['rolls']['max']) / 2
    v, m, pr, pf = roll_ev(world, zone, odds, kinds, find)
    return dict(value=v * rolls, mats={k: c * rolls for k, c in m.items()}, p_rare_roll=pr, p_rare_open=1 - (1 - pr) ** rolls, rolls=rolls, base=base, spec=spec)


def creature_ev(world, zone, cid):
    c = world.loot['creatures'][cid]
    v, m, pr, pf = roll_ev(world, zone, c['odds'], c['kinds'], c['find_chance'])
    return dict(value=v, mats=m, p_rare_roll=pr)


def pity_expect(p, k):
    """expected number of tries until success when success is guaranteed at try k (k=0: no pity)"""
    if p <= 0:
        return float('inf') if k == 0 else float(k)
    if k <= 0:
        return 1 / p
    return sum((1 - p) ** n for n in range(k))


# ====================================================================================================================================
# simulation
# ====================================================================================================================================
def quests_gold(world, prof, day):
    """repeatable repo quests: gold per day = participation x net share x gold / (cooldown + 3 days to do it); dark-forest quests only once the forest is open"""
    if day < QUEST_START_DAY:
        return 0.0
    per_day = 0.0
    for qid, g in world.quests.items():
        meta, rew = g.get('meta', {}), g.get('rewards', {})
        gold = rew.get('gold', 0)
        if meta.get('repeatable'):
            if meta.get('requires_zone') and day < prof['zones']['dybe_bregner']:
                continue
            cd = max(meta.get('cooldown_days', 3), 3)
            per_day += prof['quests'] * QUEST_NET * gold / (cd + 3)
    return per_day


ONESHOT = ['intro_lottery', 'first_animal', 'fix_roof', 'birthday_cake', 'sword_upgrade', 'math_bakery_counts', 'math_harvest_puzzle', 'math_wizard_quiz']


def simulate(world, pname, prof, verbose=False, purchases=True):
    loot = world.loot
    tiers = world.home['tiers']
    gd = prof['gate_days']
    inv = defaultdict(float)
    gold = 500.0                      # PLAN: starting gold
    built = 1
    building = None                  # (target tier, finish day)
    start_day = {1: 0}
    done_day = {1: 0}
    last_visit = {z: -99 for z in ZONE_ORDER}
    last_container = defaultdict(lambda: -99)
    boss_last = -99
    spent_home = 0.0
    furn_spend = 0.0
    cum_net = 0.0
    quest_day_gold = defaultdict(float)
    ledger = defaultdict(lambda: defaultdict(float))     # tier interval -> source -> gold
    log = []
    interval = 1
    wander_found = defaultdict(int)
    wander_avail = {z: len(zd.get('wanderers', [])) for z, zd in loot['zones'].items()}
    pity_wander = defaultdict(float)
    finds_sold = 0.0
    stats = defaultdict(float)
    invests = [(int(d * prof['invest_scale']), g) for d, g in INVEST]
    boss_kills = 0
    wealth = [0.0]
    money_ready, gate_ready, find_wait = {}, {}, {}
    for day in range(1, SIM_DAYS + 1):
        season = SEASONS[((day - 1) // 28) % 4]
        # ---------------- income
        crop, ppd = best_crop(world, prof, season)
        farm = plots(prof, day) * ppd
        forest = 0.0
        quests = quests_gold(world, prof, day)
        for q, d in (('intro_lottery', gd['intro_lottery']), ('first_animal', gd['first_animal'])):
            if day == d:
                quests += world.quests[q]['rewards']['gold']
        for q in ONESHOT[2:]:
            if day == int(20 + ONESHOT.index(q) * 12 / prof['invest_scale']):
                quests += world.quests[q]['rewards']['gold']
        if day == gd['crystal_cave']:
            quests += world.quests['crystal_cave']['rewards']['gold']
        if day == gd['snurresvampen']:
            quests += 1200
        if day == gd['moonstone_crown']:
            quests += 800
        gross_other = 0.0
        # forest run today?  (expected runs/day; the run goes to the most valuable unlocked area, rotating when its nodes have not respawned)
        runs_today = prof['runs']
        unlocked = [z for z in ZONE_ORDER if day >= prof['zones'][z]]
        for _ in range(1):
            if not unlocked or runs_today <= 0:
                break
            # choose area with the highest expected take
            best, bestv = None, -1
            for z in unlocked:
                recover = min(1.0, (day - last_visit[z]) / NODE_RESPAWN)
                ny = NODE_YIELD[z]
                v = ny['gold'] * recover
                for it, n in ny['items'].items():
                    v += n * recover * world.sell(it)
                if v > bestv:
                    best, bestv = z, v
            z = best
            zd = loot['zones'][z]
            recover = min(1.0, (day - last_visit[z]) / NODE_RESPAWN)
            value = NODE_YIELD[z]['gold'] * recover
            for it, n in NODE_YIELD[z]['items'].items():
                inv[it] += n * recover * runs_today
                ledger[interval]['mats_kept'] += n * recover * runs_today * world.sell(it)         # kept for the home; valued at SELL price, NOT spendable gold
            # containers
            for cid, spec in zd['containers'].items():
                base = loot['containers'][cid]
                n_av = spec['count'] * min(1.0, (day - last_container[(z, cid)]) / base['respawn_days'])
                if cid == 'dig':
                    n_av = spec['count'] * min(1.0, (day - last_container[(z, cid)]) / base['respawn_days'])
                    n_open = n_av * prof['dig_share']
                else:
                    n_open = n_av
                if n_open <= 0:
                    continue
                ev = container_ev(world, z, cid)
                last_container[(z, cid)] = day
                value += ev['value'] * n_open * runs_today
                for m, c in ev['mats'].items():
                    inv[m] += c * n_open * runs_today
                    ledger[interval]['mats_kept'] += c * n_open * runs_today * world.sell(m)
                stats[f'opens_{z}_{cid}'] += n_open * runs_today
                # wanderers (unique, one-time) with pity
                w_left = [w for w in zd.get('wanderers', []) if w['container'] == cid and wander_found[(z, w['item'])] == 0]
                if w_left and base['wander_bp'] > 0:
                    p = base['wander_bp'] / 10000
                    pity_wander[(z, cid)] += n_open * runs_today
                    k = base['pity_opens']
                    got = 0.0
                    # expected finds this run (fractional), forced by pity
                    hit = p * n_open * runs_today
                    if k and pity_wander[(z, cid)] >= k:
                        hit = max(hit, 1.0)
                    if hit > 0:
                        got = min(hit, len(w_left))
                        pity_wander[(z, cid)] *= max(0.0, 1 - got)
                        if got >= 0.999:
                            wander_found[(z, w_left[0]['item'])] = 1
                            stats['wanderers_found'] += 1
                            stats[f'wander_day_{z}'] = stats.get(f'wander_day_{z}') or day
            # creatures
            for cr, n in zd.get('creatures', {}).items():
                ev = creature_ev(world, z, cr)
                value += ev['value'] * n * runs_today
                for m, c in ev['mats'].items():
                    inv[m] += c * n * runs_today
                    ledger[interval]['mats_kept'] += c * n * runs_today * world.sell(m)
            # boss
            if z == 'dybe_bregner' and day - boss_last >= BOSS_REPEAT_DAYS and day >= gd['snurresvampen'] - 5:
                boss_last = day
                boss_kills += 1
                stats['boss_kills'] = boss_kills
            last_visit[z] = day
            forest = value
            finds_sold += value
        # sell-off of cheap finds = forest income (furniture/clothing finds sold at sell price + node gold)
        gross = farm + forest + quests
        ledger[interval]['farm'] += farm
        ledger[interval]['forest'] += forest
        ledger[interval]['quests'] += quests
        cum_net += gross
        # ---------------- spending: fixed purchases, lifestyle, home
        for d, g in invests:
            if day == d:
                gold -= g
        life = gross * prof['lifestyle']
        gold += gross - life
        furn_spend += life * FURNITURE_SHARE
        wealth.append(gold)
        # hygge level from furniture spend (decor points), capped by what the home can hold
        cap_pieces = tiers[built - 1]['perks']['furniture_capacity']
        decor = min(furn_spend * HYGGE_PER_GOLD, cap_pieces * 9.0)
        hygge_levels = world.home['hygge_levels']
        hlevel = max(i for i, h in enumerate(hygge_levels) if decor >= h['min_decor'])
        # finish construction
        if building and day >= building[1]:
            built = building[0]
            done_day[built] = day
            building = None
            interval = built
        # start next tier
        if purchases and not building and built < 10:
            t = tiers[built]            # index built == next tier
            nxt = built + 1
            req = t.get('requires', {})
            ok = True
            why = ''
            if 'intro_lottery' in req.get('quests', []) and day < gd['intro_lottery']:
                ok = False; why = 'intro'
            for q in req.get('quests', []):
                need = {'first_animal': gd['first_animal'], 'crystal_cave': gd['crystal_cave'], 'fairy_friendship': gd['fairy_friendship'], 'snurresvampen': gd['snurresvampen'],
                        'moonstone_crown': gd['moonstone_crown'], 'intro_lottery': gd['intro_lottery']}.get(q, 0)
                if day < need:
                    ok = False; why = f'quest {q}'
            for npc, h in req.get('friendship', {}).items():
                hearts = day * gd['mayor_hearts_per_day'] if npc == 'mayor_lyra' else (2 if day >= gd['moonstone_crown'] else 0)
                if hearts < h:
                    ok = False; why = f'friend {npc}'
            if req.get('hygge') and hlevel < req['hygge']:
                ok = False; why = 'hygge'
            cost = t['cost']
            need_gold = cost['gold']
            shortfall = {}
            mat_cost = 0.0
            for m, n in cost.get('materials', {}).items():
                lack = max(0.0, n - inv[m])
                if lack > 0:
                    shop = [s for s in world.items[m].get('sources', []) if s['kind'] == 'shop' and s['shop'] == 'builder_yard']
                    if shop:
                        unit = world.buy(m) * SELF_CRAFT_DISCOUNT.get(m, 1.0)
                        wait = {'fixed': 0, 'daily': 1, 'weekly': 4}.get(shop[0]['slot'], 0)
                        mat_cost += lack * unit
                        shortfall[m] = (lack, 'buy')
                    else:
                        shortfall[m] = (lack, 'find')
            if ok and nxt not in gate_ready:
                gate_ready[nxt] = day
            if gold >= need_gold + mat_cost and not any(v[1] == 'find' for v in shortfall.values()) and nxt not in money_ready:
                money_ready[nxt] = day
            if any(v[1] == 'find' for v in shortfall.values()) and gold >= need_gold + mat_cost:
                find_wait[nxt] = find_wait.get(nxt, 0) + 1
            if ok and not any(v[1] == 'find' for v in shortfall.values()) and gold >= need_gold + mat_cost:
                gold -= need_gold + mat_cost
                spent_home += need_gold + mat_cost
                for m, n in cost.get('materials', {}).items():
                    inv[m] = max(0.0, inv[m] - n)
                building = (nxt, day + cost['days'])
                start_day[nxt] = day
                log.append((day, nxt, need_gold, round(mat_cost), gold))
            elif verbose and day % 60 == 0:
                pass
        if purchases and built == 10 and not building:
            if 10 not in done_day:
                done_day[10] = day
            break
    return dict(start=start_day, done=done_day, ledger={k: dict(v) for k, v in ledger.items()}, log=log, stats=dict(stats), cum=cum_net, spent_home=spent_home, inv=dict(inv), wealth=wealth, money_ready=money_ready, gate_ready=gate_ready, find_wait=find_wait, hygge=hlevel)


# ====================================================================================================================================
TARGET_START = {2: 1, 3: 6, 4: 16, 5: 36, 6: 68, 7: 115, 8: 178, 9: 248, 10: 318}     # typical player: day the money for tier n is there (tier 10 done ~ day 323 = 48 h)


def round_nice(x):
    if x < 2000:
        return int(round(x / 50.0) * 50)
    if x < 10000:
        return int(round(x / 100.0) * 100)
    if x < 50000:
        return int(round(x / 250.0) * 250)
    return int(round(x / 500.0) * 500)


def material_gold(world, t):
    tot = 0.0
    for m, n in t['cost']['materials'].items():
        it = world.items[m]
        if any(s['kind'] == 'shop' and s['shop'] == 'builder_yard' for s in it.get('sources', [])):
            tot += n * it['buy_price'] * SELF_CRAFT_DISCOUNT.get(m, 1.0)
    return tot


def calibrate(world):
    prof = PROFILES['typical']
    r = simulate(world, 'typical', prof, purchases=False)
    W = r['wealth']
    used = 0.0
    out = {}
    for n in range(2, 11):
        d = TARGET_START[n]
        total = W[d] - used
        mats = material_gold(world, world.home['tiers'][n - 1])
        gold = round_nice(max(total - mats, 100))
        out[n] = dict(gold=gold, materials=round(mats), day=d, wealth=round(W[d]))
        used += gold + mats
    return out


# ====================================================================================================================================
def fmt_table(rows, header, widths=None):
    widths = widths or [max(len(str(r[i])) for r in rows + [header]) for i in range(len(header))]
    line = lambda r: '  '.join(str(c).rjust(w) if i else str(c).ljust(w) for i, (c, w) in enumerate(zip(r, widths)))  # noqa: E731
    return '\n'.join([line(header), '  '.join('-' * w for w in widths)] + [line(r) for r in rows])


def hours(d):
    return d / DAYS_PER_HOUR


def main():
    ap = argparse.ArgumentParser()
    here = Path(__file__).resolve().parent
    ap.add_argument('--lua-dump', default=str(here.parent / 'reports' / 'lua_dump.json'))
    ap.add_argument('--repo-lua-dump', default=str(here.parent / 'reports' / 'repo_lua_dump.json'))
    ap.add_argument('--quests', default='repo', choices=['repo', 'stage'])
    ap.add_argument('--home-cost-scale', type=float, default=None, help='what-if for economy.home_cost_scale (default: the value in lua/config/game_balance.lua)')
    ap.add_argument('--out')
    ap.add_argument('--json')
    ap.add_argument('--crops', default='both')
    ap.add_argument('--calibrate', action='store_true')
    args = ap.parse_args()
    mine, repo = load(args)
    if args.calibrate:
        w = World(mine, repo, 'plan', args.home_cost_scale)
        cal = calibrate(w)
        print('suggested gold per tier (typical profile, PLAN crops):')
        for n, v in cal.items():
            print(f"  tier {n:2d}: gold {v['gold']:7d}   materials ~{v['materials']:6d}   money ready on day {v['day']:3d}  (cumulative spendable {v['wealth']})")
        return
    out = []
    P = out.append
    summary = {}
    P('=' * 118)
    P('BALANCE SIMULATION  (expected values, deterministic).  1 game day = 10 real minutes -> 6.00 days per real hour.')
    P('=' * 118)
    P('ASSUMPTIONS')
    P('  start gold 500; crops: PLAN 3.10 table (primary) and the CURRENT repo crops.lua/game_balance.lua (sensitivity); winter has no crops (no crop lists vinter)')
    P('  plots(day) = cap * (1 - exp(-day/tau)), plot profit/day = (sell - seed) / (grow/eff + 1) * usable-share-of-season;  forest runs/day, areas unlocked per profile')
    P('  fixed purchases (day, gold) scaled by profile: ' + ', '.join(f'd{d}:{g}' for d, g in INVEST) + ';  lifestyle share spent on furniture/clothes/gifts (not on the home)')
    P('  forest run value = node yields of the area (respawn 3 days) + expected finds of its chests/digs/creatures from lua/data/loot_tables.lua (furniture/clothing sold at sell price,')
    P('  materials kept for the home); materials missing at upgrade time are bought at builder_yard prices (x0.6 for self-craftable planks/stone/lime/rope), gems/moonstone must be found')
    P('  hygge level = decor of furniture bought (0.015 per gold spent on furniture, 55 percent of the lifestyle budget), capped by 9 per placed piece of the home capacity')
    for mode in (['plan', 'repo'] if args.crops == 'both' else [args.crops]):
        world = World(mine, repo, mode, args.home_cost_scale)
        P('')
        P('#' * 118)
        P(f'CROP TABLE: {mode.upper()}  ' + ', '.join(f'{c}:{v[0]}/{v[1]}d/{v[3]}' for c, v in world.crops.items()))
        P('#' * 118)
        res = {}
        for pname, prof in PROFILES.items():
            res[pname] = simulate(world, pname, prof)
        summary[mode] = res
        # ---- A: time to afford every tier
        P('')
        P(f'A. TIME TO REACH EACH HOME TIER  [{mode} crops]   (start = money + gates + materials ready, build starts; done = start + build days)')
        tiers = world.home['tiers']
        header = ['tier', 'name', 'gold', 'mat. gold', 'days'] + [f'{p}: start d / done d / h' for p in PROFILES]
        rows = []
        for t in tiers[1:]:
            n = t['tier']
            row = [n, t['id'], t['cost']['gold'], round(sum(world.buy(m) * q for m, q in t['cost']['materials'].items() if m in world.items and 'buy_price' in world.items[m])), t['cost']['days']]
            for pname in PROFILES:
                r = res[pname]
                if n in r['done']:
                    row.append(f"{r['start'][n]:4d} / {r['done'][n]:4d} / {hours(r['done'][n]):5.1f}")
                else:
                    row.append('not reached in 900 days')
            rows.append(row)
        P(fmt_table(rows, header))
        P('')
        P(f'A2. WHAT BINDS EACH TIER (typical profile) [{mode} crops]: day the gold+materials are there / day every gate is open / day the build starts / days spent waiting for found gems')
        rows = []
        r = res['typical']
        for t in tiers[1:]:
            n = t['tier']
            rq = t.get('requires', {})
            gates = ', '.join(rq.get('quests', []) + [f'{k} {v} hearts' for k, v in rq.get('friendship', {}).items()] + ([f"hygge {rq['hygge']}"] if rq.get('hygge') else [])) or '-'
            binding = 'money' if r['money_ready'].get(n, 0) >= r['gate_ready'].get(n, 0) else 'gates'
            rows.append([n, t['id'], r['money_ready'].get(n, '-'), r['gate_ready'].get(n, '-'), r['start'].get(n, '-'), r['find_wait'].get(n, 0), binding, gates])
        P(fmt_table(rows, ['tier', 'name', 'money ready d', 'gates open d', 'start d', 'wait for gems d', 'binds', 'gates']))
        # ---- B: income per stage
        P('')
        P(f'B. EXPECTED GROSS INCOME PER REAL HOUR AT EACH STAGE (home tier held)  [{mode} crops]   (averages over the whole interval: winters have no crops, so intervals with a winter look poorer)')
        header = ['stage (tier held)'] + [f'{p}: gold/h  (farm / forest / quest %)  +materials found (sell value)' for p in PROFILES]
        rows = []
        for n in range(1, 10):
            row = [f'{n} {tiers[n - 1]["id"]}']
            for pname in PROFILES:
                r = res[pname]
                led = r['ledger'].get(n)
                if not led or n + 1 not in r['done'] or n not in r['done']:
                    row.append('-')
                    continue
                span = r['done'][n + 1] - r['done'][n]
                span = max(1, span)
                tot = led['farm'] + led['forest'] + led['quests']
                row.append(f"{tot / span * DAYS_PER_HOUR:7.0f}  ({led['farm'] / tot * 100:3.0f} / {led['forest'] / tot * 100:3.0f} / {led['quests'] / tot * 100:3.0f})  +{led.get('mats_kept', 0) / span * DAYS_PER_HOUR:4.0f} mats/h")
            rows.append(row)
        P(fmt_table(rows, header))
        # ---- C: totals
        P('')
        P(f'C. TOTALS  [{mode} crops]')
        rows = []
        for pname in PROFILES:
            r = res[pname]
            d10 = r['done'].get(10)
            rows.append([pname, d10 or 'n/a', f'{hours(d10):.1f}' if d10 else 'n/a', round(r['cum']), round(r['spent_home']), f"{r['spent_home'] / max(r['cum'], 1) * 100:.0f}%"])
        P(fmt_table(rows, ['profile', 'day tier 10 done', 'real hours', 'gross income until then', 'spent on home', 'share']))
        for pname in PROFILES:
            summary[mode][pname]['hours10'] = hours(res[pname]['done'][10]) if 10 in res[pname]['done'] else None
    # ====================================================================================================================================
    world = World(mine, repo, 'plan', args.home_cost_scale)
    loot = world.loot
    P('')
    P('#' * 118)
    P('D. DROP-RATE EXPECTATIONS (data: lua/data/loot_tables.lua; per container open / per dig / per kill)')
    P('#' * 118)
    rows = []
    rare_days = {}
    for z, zd in loot['zones'].items():
        for cid, spec in zd['containers'].items():
            base = loot['containers'][cid]
            ev = container_ev(world, z, cid)
            p_open = ev['p_rare_open']
            if cid == 'dig':
                p_open = ev['p_rare_roll']
            opens_per_day = spec['count'] / base['respawn_days']
            if cid == 'dig':
                opens_per_day = spec['count']  # respawn daily, the player digs a share of them
            e_rare = 1 / p_open if p_open > 0 else float('inf')
            n_w = len([w for w in zd.get('wanderers', []) if w['container'] == cid])
            wtxt = '-'
            if n_w and base['wander_bp'] > 0:
                p = base['wander_bp'] / 10000
                e1 = pity_expect(p, base['pity_opens'])
                wtxt = f"{e1:4.1f} opens ({n_w} wanderer{'s' if n_w > 1 else ''})"
            rows.append([z, cid, spec['count'], f"{ev['rolls']:.1f}", f"{ev['p_rare_open'] * 100:5.1f}%" if cid != 'dig' else f"{ev['p_rare_roll'] * 100:5.2f}%", f"{e_rare:6.1f}", f"{e_rare / max(opens_per_day, 1e-9):7.1f}", wtxt])
    P(fmt_table(rows, ['zone', 'container', 'count', 'rolls', 'P(rare+ item) per open/dig', 'opens to 1st rare', 'days to 1st rare (all opened)', 'unique wanderer: opens to 1st (pity)']))
    P('')
    P('creatures (per kill):')
    rows = []
    for z, zd in loot['zones'].items():
        for cr, n in zd.get('creatures', {}).items():
            ev = creature_ev(world, z, cr)
            c = loot['creatures'][cr]
            any_item = c['find_chance']
            rows.append([z, cr, n, f"{any_item * 100:.1f}%", f"{ev['p_rare_roll'] * 100:.2f}%", f"{1 / ev['p_rare_roll']:.0f}" if ev['p_rare_roll'] else 'inf', f'{ev["value"]:.1f}'])
    P(fmt_table(rows, ['zone', 'creature', 'per visit', 'P(any find) per kill', 'P(rare) per kill', 'kills to 1st rare', 'EV gold per kill']))
    P('')
    b = loot['boss']['snurresvamp']
    pb = b['legendary_bp'] / 10000
    P(f"boss {b['enemy']}: first kill = legendary hat via quest; repeat kills (every {b['respawn_days']} days): legendary chance {pb * 100:.0f}% per kill from {len(b['pool'])} items, pity {b['pity_kills']}")
    P(f"  expected kills to the FIRST pool legendary: {pity_expect(pb, b['pity_kills']):.1f}  (= {pity_expect(pb, b['pity_kills']) * b['respawn_days']:.0f} days);  to collect all {len(b['pool'])}: "
      f"{sum(pity_expect(pb, b['pity_kills']) for _ in b['pool']):.1f} kills (pity makes every item at most {b['pity_kills']} kills apart) = {sum(pity_expect(pb, b['pity_kills']) for _ in b['pool']) * b['respawn_days']:.0f} days")

    # ---- Monte Carlo of the documented draw algorithm (seeded) ------------------------------------------------------------------
    import random
    rng = random.Random(7)
    P('')
    P('Monte Carlo of the draw algorithm, 20000 trials per row (opens needed, median / 90th percentile / 99th percentile):')
    rows = []

    def pct(a, q):
        a = sorted(a)
        return a[min(len(a) - 1, int(q * len(a)))]
    for z, zd in loot['zones'].items():
        for cid, spec in zd['containers'].items():
            base = loot['containers'][cid]
            ev = container_ev(world, z, cid)
            p_rare = ev['p_rare_roll'] if cid == 'dig' else ev['p_rare_open']
            if p_rare <= 0:
                continue
            tr = []
            for _ in range(20000):
                n = 1
                while rng.random() > p_rare:
                    n += 1
                tr.append(n)
            wtxt = '-'
            n_w = len([w for w in zd.get('wanderers', []) if w['container'] == cid])
            if n_w and base['wander_bp'] > 0:
                p = base['wander_bp'] / 10000
                k = base['pity_opens']
                tw = []
                for _ in range(20000):
                    n = 1
                    while n < k and rng.random() > p:
                        n += 1
                    tw.append(n)
                wtxt = f'{pct(tw, .5)} / {pct(tw, .9)} / {pct(tw, .99)}'
            rows.append([z, cid, f'{pct(tr, .5)} / {pct(tr, .9)} / {pct(tr, .99)}', wtxt])
    P(fmt_table(rows, ['zone', 'container', 'first RARE item (opens)', 'first UNIQUE wanderer (opens, pity-capped)']))
    tb = []
    for _ in range(20000):
        n = 1
        while n < b['pity_kills'] and rng.random() > pb:
            n += 1
        tb.append(n)
    P(f"boss legendary pool: first legendary after {pct(tb, .5)} / {pct(tb, .9)} / {pct(tb, .99)} repeat kills (median / p90 / p99); never more than {b['pity_kills']}")
    # price curve examples
    P('')
    P('price curve example (furniture_shop, repeat surcharge +8 percent per copy up to +32 percent, season-end sale -15 percent on uncommon, friend discount 0.5 percent per heart up to 10):')
    rows = []
    fs = world.shops['furniture_shop']['price_curve']
    for iid in ('bed_pine', 'sofa_sky_two', 'bed_walnut'):
        bp = world.items[iid]['buy_price']
        cop = [round(bp * (1 + min(fs['repeat_surcharge']['step'] * n, fs['repeat_surcharge']['max']))) for n in range(5)]
        sale = round(bp * 0.85) if world.items[iid]['rarity'] == 'uncommon' else bp
        rows.append([iid, world.items[iid]['rarity'], bp, ' / '.join(map(str, cop)), sale, round(bp * (1 - 0.05)), world.items[iid]['sell_price']])
    P(fmt_table(rows, ['item', 'rarity', 'buy', 'copies 1..5', 'sale day (22-28)', 'with 10 hearts', 'sells back for']))
    # rarity ladder of what a player sees
    P('')
    P('E. RARITY OF FINDS PER ROLL (effective, wanderers included, per roll; unique/legendary never from chests except wanderers)')
    rows = []
    for z, zd in loot['zones'].items():
        for cid, spec in zd['containers'].items():
            base = loot['containers'][cid]
            odds = spec.get('odds', base['odds'])
            w = base['wander_bp'] / 10000 if any(x['container'] == cid for x in zd.get('wanderers', [])) else 0
            rows.append([z, cid, f"{odds['normal'] / 100 * (1 - w):5.1f}", f"{odds['uncommon'] / 100 * (1 - w):5.1f}", f"{odds['rare'] / 100 * (1 - w):5.1f}", f"{w * 100:5.1f}", '0.0'])
    P(fmt_table(rows, ['zone', 'container', 'normal %', 'uncommon %', 'rare %', 'unique % (wanderer, per OPEN)', 'legendary %']))
    # ====================================================================================================================================
    P('')
    P('#' * 118)
    P('F. SHOP PRICE CURVE vs SELL VALUES, CRAFT COST vs BUY (no infinite money loops)')
    P('#' * 118)
    items = world.items
    rows = []
    for r in ('normal', 'uncommon', 'rare'):
        for kind in ('furniture', 'clothing'):
            its = {i: e for i, e in items.items() if e.get('category') == kind and e.get('rarity') == r}
            if not its:
                continue
            ratios = [e['sell_price'] / e['buy_price'] for e in its.values()]
            cheapest = min(e['buy_price'] * 0.80 for e in its.values())
            rows.append([kind, r, len(its), f"{min(ratios):.2f}-{max(ratios):.2f}", f"{min(e['buy_price'] for e in its.values())}-{max(e['buy_price'] for e in its.values())}",
                         'yes' if all(e['buy_price'] * 0.80 > e['sell_price'] for e in its.values()) else 'NO'])
    P(fmt_table(rows, ['kind', 'rarity', 'items', 'sell/buy', 'buy price range', 'worst-case discounted buy (-20%) > sell?']))
    rec = [(rid, r) for rid, r in world.recipes.items() if rid.startswith('build_')]
    ratios = []
    worst = None
    for rid, r in rec:
        out_item = r['output']['item']
        cost = sum(world.buy(k) * n for k, n in r['ingredients'].items())
        e = items[out_item]
        ratios.append((cost / e['buy_price'], rid))
        loopmargin = e['sell_price'] - cost
        if worst is None or loopmargin > worst[0]:
            worst = (loopmargin, rid, cost, e['sell_price'])
    P('')
    P(f"furniture recipes: {len(rec)}; craft cost / buy price: min {min(ratios)[0]:.2f}  mean {sum(r for r, _ in ratios) / len(ratios):.2f}  max {max(ratios)[0]:.2f};  "
      f"best sell-minus-cost margin of any recipe = {worst[0]:.0f} gold ({worst[1]}: cost {worst[2]}, sell {worst[3]}) -> negative means no craft-and-sell loop")
    P('processing recipes (output value vs inputs):')
    rows = []
    for rid, r in world.recipes.items():
        if rid.startswith('build_'):
            continue
        o = r['output']
        cost_buy = sum(world.buy(k) * n for k, n in r['ingredients'].items())
        val = world.sell(o['item']) * o['amount']
        rows.append([rid, ' + '.join(f'{n} {k}' for k, n in r['ingredients'].items()), f"{o['amount']} {o['item']}", cost_buy, val, 'ok (value added)' if val >= 0 else ''])
    P(fmt_table(rows, ['recipe', 'inputs', 'output', 'inputs at buy price', 'output at sell price', 'note']))
    P('')
    P('shop rotation: expected items per shop slot and weekly spend to buy everything that appears (upper bound, no stock limits):')
    rows = []
    for sid, s in world.shops.items():
        for slot in s['rotation']:
            pool = slot['pool']
            avg = sum(items[i]['buy_price'] for i in pool) / len(pool) * slot['price_mult']
            per_week = slot['pick'] * (7 / slot['period'])
            rows.append([sid, slot['id'], f"every {slot['period']} d", f"{slot['pick']} of {len(pool)}", f"{avg:.0f}", f"{per_week * avg:.0f}"])
    P(fmt_table(rows, ['shop', 'slot', 'rotates', 'picks', 'avg price', 'gold to buy all offered per week']))
    # collection completion times
    P('')
    P('G. COLLECTION VALUE AND KEEPSAKES')
    fur = {i: e for i, e in items.items() if e.get('category') == 'furniture'}
    clo = {i: e for i, e in items.items() if e.get('category') == 'clothing'}
    tot_buyable = sum(e['buy_price'] for e in list(fur.values()) + list(clo.values()) if e['rarity'] in ('normal', 'uncommon', 'rare'))
    P(f"  buying every normal/uncommon/rare furniture + clothing item once costs {tot_buyable:,} gold; keepsakes (unique+legendary, never sold, never bought): "
      f"{sum(1 for e in list(fur.values()) + list(clo.values()) if e['rarity'] in ('unique', 'legendary'))} items worth {sum(e['worth'] for e in list(fur.values()) + list(clo.values()) if e['rarity'] in ('unique', 'legendary')):,} gold of reference value")
    home_total = sum(t.get('cost', {}).get('gold', 0) for t in world.home['tiers'])
    mixavg = sum(w * (sum(e['buy_price'] for e in fur.values() if e['rarity'] == r) / sum(1 for e in fur.values() if e['rarity'] == r)) for r, w in (('normal', .4), ('uncommon', .4), ('rare', .2)))
    P(f"  home tiers 2-10: {home_total:,} gold + materials.  Furnishing the castle to capacity ({world.home['tiers'][9]['perks']['furniture_capacity']} pieces) with a 40/40/20 normal/uncommon/rare mix of average prices "
      f"costs about {round(world.home['tiers'][9]['perks']['furniture_capacity'] * mixavg):,} gold: furniture is a second, parallel gold sink of the same size as the upgrades themselves.")
    text = '\n'.join(out)
    print(text)
    if args.out:
        Path(args.out).write_text(text + '\n', encoding='utf-8')
    if args.json:
        slim = {m: {p: dict(done=r['done'], start=r['start'], hours10=r['hours10'], cum=r['cum'], spent_home=r['spent_home']) for p, r in v.items()} for m, v in summary.items()}
        Path(args.json).write_text(json.dumps(slim, indent=1))


if __name__ == '__main__':
    main()
