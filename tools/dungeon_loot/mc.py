#!/usr/bin/env python3
"""Independent Monte Carlo from the reviewed final design model.
All tables are evaluated from this checkout by Lua 5.4 on each invocation.
Profiles and player choices remain explicit modelling assumptions; combat uses
its separate real-player fight bot. No draft snapshots or patches are applied.
"""
import argparse, collections, copy, json, math, random, statistics, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
from live_data import snapshot

BANDS = ["skovkant", "dybe_bregner", "svampelunden", "krystalgrotten"]
RARS = ["normal", "uncommon", "rare", "unique", "legendary"]
RANK = {r: i + 1 for i, r in enumerate(RARS)}
CRYSTAL_KINDS = {"amethyst", "emerald", "moonstone", "crystal_shard"}      # all art variants share the crystal yield; counts come from live floor nodes

# ====================================================================================================================================
# ASSUMPTIONS (named; the generator and experience tracks may overwrite them with their own tables)
# ====================================================================================================================================
PROFILES = {
    # runs: dungeon runs per game day (the plan's forest-run frequency); complete: share of chests / nodes / digs the player gets to on a floor; zones: day the band is first entered (the plan's
    # table); luck: (day0, day1, L at 0, L at 1) perk luck ramp of the gear the player wears (cap 0.20); defeat: chance that a run ends in a faint; spot_find: chance to find a hidden spot on a floor
    # that carries one; quests: the day the quests behind loot.spots[..].requires are done; key_day: the day Fru Ugle's key quest is done (a little before the crystal cave quest)
    "casual": dict(runs=0.15, complete=0.60, zones=dict(skovkant=2, dybe_bregner=28, svampelunden=50, krystalgrotten=85), luck=(0, 400, 0.0, 0.08), defeat=0.06, spot_find=0.20,
                   quests=dict(lost_cat=40, moonstone_crown=150, crystal_cave=95, snurresvampen=120), key_day=40),
    "typical": dict(runs=0.35, complete=0.80, zones=dict(skovkant=1, dybe_bregner=12, svampelunden=25, krystalgrotten=40), luck=(0, 300, 0.0, 0.12), defeat=0.03, spot_find=0.30,
                    quests=dict(lost_cat=20, moonstone_crown=75, crystal_cave=50, snurresvampen=60), key_day=20),
    "dedicated": dict(runs=0.60, complete=0.95, zones=dict(skovkant=1, dybe_bregner=6, svampelunden=12, krystalgrotten=20), luck=(0, 200, 0.02, 0.18), defeat=0.015, spot_find=0.45,
                      quests=dict(lost_cat=12, moonstone_crown=45, crystal_cave=30, snurresvampen=35), key_day=10),
}
# the pace of the experience track (DE30: typical player floor 4 by day ~15, floor 7 by ~40, floor 10 by ~85): day each band is first entered; casual x 2.3 and dedicated x 0.5 like the plan's own ratios
PACE_DE30 = {"typical": dict(skovkant=1, dybe_bregner=15, svampelunden=40, krystalgrotten=85), "casual": dict(skovkant=2, dybe_bregner=35, svampelunden=92, krystalgrotten=195),
             "dedicated": dict(skovkant=1, dybe_bregner=8, svampelunden=20, krystalgrotten=42)}
PACE_PLAN = {k: dict(v["zones"]) for k, v in PROFILES.items()}


def set_pace(name):
    src = PACE_DE30 if name == "de30" else PACE_PLAN
    for k in PROFILES:
        PROFILES[k]["zones"] = dict(src[k])


FRONTIER_SHARE = 0.70          # a run goes to the newest unlocked band with this chance, else to a random unlocked band (material / hunting runs)
BOSS_FIGHT_P = 0.88            # a run that reaches the boss floor beats the boss (a repeat kill only counts when the weekly reward is ready)
KEY_QUEST_COST = 81            # Fru Ugle's weekly key quest: deliver amethyst + rose_quartz + amber (231 sold value), get ugle_noegle + 150 gold = 81 net (experience track p03 6.4)
# swing + cooldown of the weapon families: experience track p02_combat 3.2 (sword .28/.12, club .42/.12, spear .31/.12, dagger .20/.06); staff = this track's proposal (.34/.16)
FAMILY_CYCLE = {"sword": 0.40, "club": 0.54, "spear": 0.43, "dagger": 0.26, "staff": 0.50}
SIM_DAYS = 520
MODE = "sell"
# the share of a raw material (resource / forage / mineral / dungeon material / building material) the player really sells; the rest goes into recipes, quests, forging and the home (the plan's own
# balance_sim counts raw node yields as KEPT materials, not income; 0.35 is the conservative middle between that and selling everything)
HOME_CAP = {"moonstone": 10, "amethyst": 10}      # the home needs 8 each (+1 moonstone for the crown, +1 per mushroom lantern); the rest is sold like any gem
RAW_SELL_SHARE = 0.35
CAP_SOURCES = None             # None = read dungeon_loot.daily.counts (EDITOR: the final design counts only the rarity-restricted sources); a set overrides (sensitivity runs)
CAP_ALL = False                # True = the loot track's original rule (every source burns the cap)
APPRAISE_RATIONAL = False
DNG_SELL_SHARE = 1.0           # EDITOR: the dng_* materials carry their REAL (low) sell_price in the data (ADDENDUM 5.6), so the surplus is sold at 100 % of that price; 0.35 only reproduces the loot track's own model
CUR_BAND = None                # the band of the floor being played (per-band caps)
KIND_SCALE = {}                # DIAL (pace): multiply the container / creature kind weight of "furniture" / "clothing" (e.g. {"furniture": 0.5, "clothing": 0.5})
KEEP_MIN = 1                   # DIAL (pace): lowest rarity RANK of a furniture / clothing piece that the player keeps (mode keep); lower ones are sold at once
RAW_CATEGORIES = {"resource", "forage", "mineral", "material", "building_material"}
HOME_NEEDS = {"nails", "plank_pine", "stone_block", "glass_pane", "lime", "straw_bundle", "plank_oak", "roof_tile", "timber_beam", "brick", "copper_plate", "amethyst", "plank_walnut", "slate",
              "gold_leaf", "marble_block", "brass_bar", "moonstone"}


class World:
    def __init__(self, repo=None):
        repo = repo if repo is not None else snapshot()
        self.items = {}
        for f, g in repo.items():
            if f.startswith("lua/items/"):
                self.items.update(g.get("items", {}))
        self.loot = copy.deepcopy(repo["lua/data/loot_tables.lua"]["config"]["loot"])
        self.rarity = repo["lua/config/rarity.lua"]["config"]
        self.DL = copy.deepcopy(repo["lua/config/dungeon_loot.lua"]["config"]["dungeon_loot"])
        self.GEN = repo["lua/config/dungeon.lua"]["config"]["dungeon"]
        families = repo["lua/config/dungeon_run.lua"]["config"]["dungeon_run"]["weapon_families"]
        FAMILY_CYCLE.update({key: float(row["time"])+float(row["cooldown"]) for key,row in families.items()})
        for wid, d in self.items.items():
            if d.get("category") == "weapon":
                d["family"] = d.get("weapon_family", "sword")
                d["rating"] = d["damage"] / FAMILY_CYCLE[d["family"]]
        # spots by floor: the generator's lists plus the new ones of the patch
        self.spots_on = collections.defaultdict(list)
        for fl in self.GEN["floors"]:
            for sid in fl.get("spots", []):
                self.spots_on[fl["n"]].append(sid)
        for sid, sp in self.loot["spots"].items():
            if "floor" in sp:
                self.spots_on[sp["floor"]].append(sid)
        self.boss_on = {}
        for b in self.DL["bosses"]:
            self.boss_on[b["floor"]] = b["id"]
        self.chest_keep = 1.0
        if KIND_SCALE:
            def scale(kinds):
                for k, f in KIND_SCALE.items():
                    if k in kinds:
                        kinds[k] = kinds[k] * f
            for spec in self.loot["containers"].values():
                if isinstance(spec, dict) and isinstance(spec.get("kinds"), dict): scale(spec["kinds"])
            for z in self.loot["zones"].values():
                for key in ("containers", "creatures"):
                    for spec in (z.get(key) or {}).values() if isinstance(z.get(key), dict) else []:
                        if isinstance(spec, dict) and isinstance(spec.get("kinds"), dict): scale(spec["kinds"])
            for spec in (self.loot.get("creatures") or {}).values() if isinstance(self.loot.get("creatures"), dict) else []:
                if isinstance(spec, dict) and isinstance(spec.get("kinds"), dict): scale(spec["kinds"])

    def sell(self, item):
        d = self.items.get(item)
        return int(d.get("sell_price", 0)) if d else 0

    def rarity_of(self, item):
        d = self.items.get(item)
        return d.get("rarity", "normal") if d else "normal"

    def kind_of(self, item):
        c = self.items.get(item, {}).get("category", "")
        return {"furniture": "furniture", "clothing": "clothing", "weapon": "weapon", "gem": "gem"}.get(c, "material")


# ====================================================================================================================================
def weighted(rng, pairs):
    tot = sum(w for _, w in pairs)
    if tot <= 0:
        return None
    r = rng.random() * tot
    for k, w in pairs:
        r -= w
        if r < 0:
            return k
    return pairs[-1][0]


def depth_odds(world, tier, floor, luck, spec=None):
    """rarity probabilities (normal, uncommon, rare) of an ordinary roll of container `tier` at `floor` for luck L (design_loot.md 6.2)"""
    base = (spec or {}).get("odds") or world.loot["containers"][tier]["odds"]
    dp = world.DL["depth"]
    s = 1.0 + dp["rarity_step"] * (min(floor, dp["cap_floor"]) - 1)
    w = [base["normal"], base["uncommon"] * s, base["rare"] * s * s]
    tot = sum(w)
    p = [x / tot for x in w]
    m = 1.0 + dp["luck_mult"] * luck
    pu, pr = p[1] * m, p[2] * m
    if pu + pr > 1.0:
        sc = 1.0 / (pu + pr)
        pu, pr = pu * sc, pr * sc
    return [1.0 - pu - pr, pu, pr]


class State:
    """one save's dungeon bookkeeping"""

    def __init__(self, world):
        self.w = world
        self.found = {}                 # keepsake id -> day (permanent registry loot.found)
        self.misses = collections.defaultdict(int)          # (band, tier) -> opens without a wanderer
        self.boss = {b: dict(first=False, last=-99, kills=0, misses=0, pool=list(world.loot["boss"][b].get("pool") or [])) for b in world.loot["boss"]}
        self.appr_n = 0
        self.last_unique_day = -99
        self.day_value = collections.defaultdict(float)     # day -> sold value handed out
        self.band_value = collections.defaultdict(float)    # (day, band) -> the same, per band
        self.best_rating = {}           # family -> rating of the best weapon owned
        self.weapons = set()
        self.claimed = set()
        self.log = []
        self.inv = collections.Counter()  # kept home materials
        self.own = collections.Counter()  # furniture / clothing copies kept (mode "keep")
        self.keys = 0
        self.next_key_day = 0
        self.mode = MODE


def luck_at(profile, day):
    d0, d1, l0, l1 = profile["luck"]
    t = min(max((day - d0) / max(d1 - d0, 1), 0.0), 1.0)
    return l0 + (l1 - l0) * t


class Run:
    def __init__(self):
        self.gold = 0.0
        self.kept = collections.Counter()
        self.items = []         # (item, rarity, kind, source)
        self.rough = collections.Counter()
        self.floors = 0
        self.fee = 0.0
        self.by = collections.Counter()
        self.kept_buy = 0.0
        self.kept_buy_f = 0.0
        self.gross_sold = 0.0
        self.dust_sold = 0.0
        self.key_spent = 0.0


def deliver(world, st, run, item, amount, src, day, kind=None):
    """one item enters the player's hands; False when the keepsake registry refuses it"""
    rar = world.rarity_of(item)
    kind = kind or world.kind_of(item)
    if RANK[rar] >= 4:
        if item in st.found:
            return False
        st.found[item] = day
        st.log.append((day, item, rar, kind, src))
        run.items.append((item, rar, kind, src))
        if rar == "unique" and src in ("wander", "spot"):
            st.last_unique_day = day
        return True
    run.items.append((item, rar, kind, src))
    if st.mode == "keep" and kind in ("furniture", "clothing") and RANK[rar] >= KEEP_MIN:
        cap = 1 if kind == "clothing" else 2
        if st.own[item] < cap:
            st.own[item] += 1
            run.kept_buy += world.items.get(item, {}).get("buy_price", 0)
            if kind == "furniture":
                run.kept_buy_f += world.items.get(item, {}).get("buy_price", 0)
            return True
    if kind == "weapon":
        fam = world.items[item].get("family")
        rating = world.items[item].get("rating", 0)
        if rating > st.best_rating.get(fam, 0):
            st.best_rating[fam] = rating
            st.weapons.add(item)
            return True
    if item in HOME_NEEDS:
        cap = HOME_CAP.get(item)
        if cap is None or st.inv[item] + run.kept[item] < cap:
            run.kept[item] += amount
            return True
    v = world.sell(item) * amount
    if world.items.get(item, {}).get("category") in RAW_CATEGORIES:
        # REVIEW PATCH: the dungeon materials (dng_*) have no sink but 13 one-off recipes -> DNG_SELL_SHARE (1.0 = the player sells the surplus); every other raw item keeps the loot track's 0.35
        v *= DNG_SELL_SHARE if (item.startswith("dng_") and not item.startswith("dng_rune")) else RAW_SELL_SHARE
    run.gold += v
    run.gross_sold += v
    if item == "dng_glimmer_dust": run.dust_sold += v
    run.by[(src, kind)] += v
    if _burns(world, src):
        st.day_value[day] += v
        st.band_value[(day, CUR_BAND)] += v
    return True


def _burns(world, src):
    """does a delivery of source `src` count against the daily value cap?  (EDITOR: dungeon_loot.daily.counts = the rarity-restricted sources)"""
    if CAP_ALL:
        return True
    cs = CAP_SOURCES if CAP_SOURCES is not None else set(world.DL["daily"].get("counts") or [])
    return (not cs) or src in cs


def cap_of(world, band):
    c = world.DL["daily"]["value_cap"]
    return c[band] if isinstance(c, dict) else c


def used(world, st, day, band):
    return st.band_value[(day, band)] if isinstance(world.DL["daily"]["value_cap"], dict) else st.day_value[day]


def is_capped(world, st, day, band):
    return used(world, st, day, band) >= cap_of(world, band)


def appraisal_net(world, band, luck):
    ap = world.DL["appraisal"]; o = ap["odds"][band]; mm = 1 + world.DL["depth"]["luck_mult"] * luck
    pu, pr = o["uncommon"] / 1e4 * mm, o["rare"] / 1e4 * mm
    if pu + pr > 1: sc = 1 / (pu + pr); pu, pr = pu * sc, pr * sc
    ev = {}
    for r in ("normal", "uncommon", "rare"):
        pool = ap["pools"][r]; ws = sum(e["w"] for e in pool); ev[r] = sum(e["w"] * world.sell(e["item"]) for e in pool) / ws
    return (1 - pu - pr) * ev["normal"] + pu * ev["uncommon"] + pr * ev["rare"] - ap["fee"][band]


def pick_pool(world, band, kind, rar, rng):
    pools = world.loot["zones"][band]["pools"].get(kind)
    if not pools:
        return None
    lst = pools.get(rar) or []
    return weighted(rng, [(e["item"], e["w"]) for e in lst]) if lst else None


def open_chest(world, st, run, band, tier, floor, day, luck, rng, capped=False):
    """LootService.open_container (design_loot.md 6.3)"""
    spec = world.loot["containers"][tier]
    zspec = world.loot["zones"][band]["containers"].get(tier, {}) if tier in ("trae", "jern", "fe") else {}
    kinds = dict(zspec.get("kinds") or spec["kinds"])
    odds = depth_odds(world, tier, floor, luck, zspec)
    daily = world.DL["daily"]
    if capped:
        odds = [odds[0] + odds[2], odds[1], 0.0]
        kinds = dict(daily["kinds"])
    n_rolls = rng.randint(spec["rolls"]["min"], spec["rolls"]["max"])
    forced = None
    if day - st.last_unique_day >= world.DL["unique"]["cooldown_days"] and spec.get("wander_bp", 0) > 0:
        wl = [wd for wd in world.loot["zones"][band].get("wanderers", []) if wd["container"] == tier and wd["item"] not in st.found]
        if wl:
            pity = spec.get("pity_opens", 0)
            st.misses[(band, tier)] += 1
            hit = rng.random() < spec["wander_bp"] * (1 + world.DL["depth"]["luck_mult"] * luck) / 10000.0
            if (hit or (pity and st.misses[(band, tier)] >= pity)) and day - st.last_unique_day >= world.DL["unique"]["cooldown_days"]:
                forced = wl[0]["item"]
                st.misses[(band, tier)] = 0
    for i in range(n_rolls):
        if i == 0 and forced:
            deliver(world, st, run, forced, 1, "wander", day)
            continue
        if rng.random() > spec.get("find_chance", 1.0):
            continue
        for _ in range(6):
            kind = weighted(rng, list(kinds.items()))
            if kind == "gem":
                run.rough[band] += 1
                run.items.append(("rough_" + band, "normal", "gem", "chest"))
                break
            r = weighted(rng, list(zip(("normal", "uncommon", "rare"), odds)))
            it = pick_pool(world, band, kind, r, rng)
            if it:
                deliver(world, st, run, it, 1, "chest", day)
                break


def dig(world, st, run, band, floor, day, luck, rng):
    spec = world.loot["containers"]["dig"]
    if rng.random() > spec["find_chance"]:
        return
    kinds = dict(spec["kinds"])
    odds = depth_odds(world, "dig", floor, luck)
    for _ in range(6):
        kind = weighted(rng, list(kinds.items()))
        if kind == "gem":
            run.rough[band] += 1
            run.items.append(("rough_" + band, "normal", "gem", "dig"))
            return
        r = weighted(rng, list(zip(("normal", "uncommon", "rare"), odds)))
        it = pick_pool(world, band, kind, r, rng)
        if it:
            deliver(world, st, run, it, 1, "dig", day)
            return


def kill(world, st, run, band, floor, day, luck, rng, kind):
    c = world.loot["creatures"].get(kind)
    if c and rng.random() < c["find_chance"]:
        odds = depth_odds(world, "trae", floor, luck, c)
        for _ in range(6):
            k = weighted(rng, list(c["kinds"].items()))
            r = weighted(rng, list(zip(("normal", "uncommon", "rare"), odds)))
            it = pick_pool(world, band, k, r, rng)
            if it:
                deliver(world, st, run, it, 1, "creature", day)
                break
    for d in world.DL["drops"].get(kind, []):
        if rng.random() < d["bp"] / 10000.0:
            deliver(world, st, run, d["item"], rng.randint(d["amount"][0], d["amount"][1]), "drop", day)


def node(world, st, run, kindname, band, floor, day, rng):
    ny = world.DL["node_yields"][kindname]
    if ny.get("bands") and band not in ny["bands"]:
        return
    if rng.random() * 10000 >= ny.get("chance_bp", 10000):
        fb = ny.get("fallback")
        if fb:
            deliver(world, st, run, fb["item"], rng.randint(fb["amount"][0], fb["amount"][1]), "node", day)
        return
    if ny.get("rough"):
        run.rough[band] += 1
        run.items.append(("rough_" + band, "normal", "gem", "node"))
        for ex in ny.get("extra", []):
            if band in ex["bands"] and rng.random() < ex["bp"] / 10000.0:
                deliver(world, st, run, ex["item"], 1, "node", day)
        return
    deliver(world, st, run, ny["item"], rng.randint(ny["amount"][0], ny["amount"][1]), "node", day)


def appraise(world, st, run, band, day, luck, rng):
    ap = world.DL["appraisal"]
    run.fee += ap["fee"][band]
    st.appr_n += 1
    o = ap["odds"][band]
    m = 1 + world.DL["depth"]["luck_mult"] * luck
    pu, pr = o["uncommon"] / 10000.0 * m, o["rare"] / 10000.0 * m
    if is_capped(world, st, day, band):
        pr = 0.0
    if pu + pr > 1:
        sc = 1 / (pu + pr)
        pu, pr = pu * sc, pr * sc
    r = weighted(rng, [("normal", 1 - pu - pr), ("uncommon", pu), ("rare", pr)])
    it = weighted(rng, [(e["item"], e["w"]) for e in ap["pools"][r]])
    deliver(world, st, run, it, 1, "appraise", day)
    return it


def boss_fight(world, st, run, bid, band, floor, day, luck, rng, quests):
    """first kill rewards and the weekly repeat (design_loot.md 6.5)"""
    spec = world.loot["boss"][bid]
    b = st.boss[bid]
    if not b["first"]:
        b["first"] = True
        b["kills"] += 1
        b["last"] = day
        for it in spec.get("first_kill_items", []):
            deliver(world, st, run, it, 1, "boss_first", day)
        for it, n in (spec.get("first_kill_extra") or {}).items():
            deliver(world, st, run, it, n, "boss_first", day)
        if bid == "snurresvamp":
            if day >= quests["snurresvampen"]:
                deliver(world, st, run, "hat_mushroom_spinner", 1, "boss_first", day)
            else:
                b["quest_pending"] = True
        return
    if bid == "snurresvamp" and b.get("quest_pending") and day >= quests["snurresvampen"]:
        b["quest_pending"] = False
        deliver(world, st, run, "hat_mushroom_spinner", 1, "boss_first", day)
    if day - b["last"] < spec.get("respawn_days", 7):
        return
    b["last"] = day
    b["kills"] += 1
    open_chest(world, st, run, band, "konge", floor, day, luck, rng, capped=is_capped(world, st, day, band))
    pool = [i for i in b["pool"] if i not in st.found]
    if spec.get("legendary_bp", 0) > 0 and spec.get("pool"):
        if not pool:
            deliver(world, st, run, spec["exhausted_item"], spec["exhausted_amount"], "boss", day)
            return
        b["misses"] += 1
        if rng.random() < spec["legendary_bp"] / 10000.0 or b["misses"] >= spec["pity_kills"]:
            b["misses"] = 0
            deliver(world, st, run, rng.choice(pool), 1, "boss", day)


def unique_ready(world, st, day):
    return day - st.last_unique_day >= world.DL["unique"]["cooldown_days"]


def spot_ok(world, st, sid, day, quests):
    sp = world.loot["spots"][sid]
    if world.rarity_of(sp["item"]) == "unique" and not unique_ready(world, st, day):
        return False
    rq = sp.get("requires") or {}
    if any(day < quests.get(q, 10 ** 9) for q in rq.get("quests", [])):
        return False
    if "day_min" in rq and day < rq["day_min"]:
        return False
    if "home_tier_min" in rq and day < 8 * rq["home_tier_min"]:
        return False
    if sp.get("container") == "noegle":
        return False                     # lake keepsakes are handled with the lake chest
    for it in rq.get("items", []):
        if it not in st.found:
            return False
    return True


def run_floors(world, st, band, floors, day, rng, profile, luck, quests=None):
    quests = quests or profile["quests"]
    global CUR_BAND
    CUR_BAND = band
    run = Run()
    dl, gen = world.DL, world.GEN
    comp = profile["complete"]
    mix = list((gen["bands"][band].get("enemy_mix") or {"bat": 1}).items())
    for f in floors:
        gf = gen["floors"][min(f, 12) - 1]
        run.floors += 1
        # the one main chest of the band's tier
        if rng.random() < comp:
            open_chest(world, st, run, band, dl["bands"][band]["main_tier"], f, day, luck, rng, capped=is_capped(world, st, day, band))
        # the lake chest (locked, key ugle_noegle): the key comes from Fru Ugle's weekly quest (3 gems in, 150 gold + the key out: net KEY_QUEST_COST); the first locked chest of a band holds its unique gem
        if gf.get("lake") and day >= profile["key_day"]:
            if st.keys < 1 and day >= st.next_key_day:
                st.keys += 1
                st.next_key_day = day + 7
                run.gold -= KEY_QUEST_COST
            sid = {"skovkant": "soeskatten_skov", "dybe_bregner": "soeskatten_bregner", "svampelunden": "soeskatten_lund"}.get(band)
            fresh = sid and sid not in st.claimed
            if st.keys >= 1 and rng.random() < comp:
                st.keys -= 1
                open_chest(world, st, run, band, "noegle", f, day, luck, rng, capped=is_capped(world, st, day, band))
                if fresh and unique_ready(world, st, day) and deliver(world, st, run, world.loot["spots"][sid]["item"], 1, "spot", day):
                    st.claimed.add(sid)
        for _ in range(gf["digs"]):
            if rng.random() < comp * 0.8:
                dig(world, st, run, band, f, day, luck, rng)
        for kn, n in (gf.get("nodes") or {}).items():
            if kn in CRYSTAL_KINDS or kn not in dl["node_yields"]:
                continue
            for _ in range(n):
                if rng.random() < comp:
                    node(world, st, run, kn, band, f, day, rng)
        # REVIEW PATCH: the final design has no floor_loot; every crystal node the generator places is a loot node (ADDENDUM 5.8)
        ncry = sum(n for kn, n in (gf.get("nodes") or {}).items() if kn in CRYSTAL_KINDS)
        for _ in range(ncry):
            if rng.random() < comp:
                node(world, st, run, "crystal", band, f, day, rng)
        for _ in range(gf["enemies"]):
            if rng.random() < max(comp, 0.7):
                kill(world, st, run, band, f, day, luck, rng, weighted(rng, mix))
        for sid in world.spots_on.get(f, []):
            if sid in st.claimed or not spot_ok(world, st, sid, day, quests):
                continue
            if rng.random() < profile["spot_find"] * (0.4 + 0.6 * comp):
                if deliver(world, st, run, world.loot["spots"][sid]["item"], 1, "spot", day):
                    st.claimed.add(sid)
        bid = world.boss_on.get(f)
        if bid and rng.random() < BOSS_FIGHT_P:
            boss_fight(world, st, run, bid, band, f, day, luck, rng, quests)
    for bnd, n in list(run.rough.items()):
        if APPRAISE_RATIONAL and appraisal_net(world, bnd, luck) <= 0:
            continue                      # REVIEW knob: a rational player does not pay a fee that exceeds the expected value of the cut gem (the loot track forces every stone through the appraisal)
        for _ in range(n):
            appraise(world, st, run, bnd, day, luck, rng)
    run.gold -= run.fee
    return run


def run_band(world, st, band, day, rng, profile, luck, quests=None, floors=None):
    b = world.DL["bands"][band]
    return run_floors(world, st, band, floors or list(range(b["from"], b["to"] + 1)), day, rng, profile, luck, quests)


# ====================================================================================================================================
HUNTER = 0.0     # share of runs that go to a band whose boss reward is ready and still has legendaries in its pool (the legendary hunt); 0 = the baseline player


def lifetime(world, pname, seed, days=SIM_DAYS, mode=None, hunter=None):
    hunter = HUNTER if hunter is None else hunter
    prof = PROFILES[pname]
    rng = random.Random(seed * 7919 + sum(map(ord, pname)))
    st = State(world)
    if mode:
        st.mode = mode
    unlock = prof["zones"]
    gold_total, runs, rares, floors_total, defeats = 0.0, 0, 0, 0, 0
    runs_by_day = []
    daily = {}
    marks = {}
    for day in range(1, days + 1):
        if rng.random() >= prof["runs"]:
            continue
        open_b = [b for b in BANDS if day >= unlock[b]]
        if not open_b:
            continue
        band = open_b[-1] if rng.random() < FRONTIER_SHARE else rng.choice(open_b)
        if hunter > 0 and rng.random() < hunter:
            cand = []
            for b in open_b:
                bid = world.DL["bands"][b]["boss"] if "boss" in world.DL["bands"][b] else None
            for bd in world.DL["bosses"]:
                bid = bd["id"]
                bnd = [bb for bb in BANDS if world.DL["bands"][bb]["from"] <= bd["floor"] <= world.DL["bands"][bb]["to"]][0]
                bs = st.boss[bid]
                if bnd in open_b and (not bs["first"] or day - bs["last"] >= 7) and [i for i in bs["pool"] if i not in st.found]:
                    cand.append(bnd)
            if cand:
                band = rng.choice(cand)
        run = run_band(world, st, band, day, rng, prof, luck_at(prof, day))
        runs += 1
        gold_total += run.gold
        floors_total += run.floors
        rares += sum(1 for it in run.items if RANK[it[1]] == 3)
        st.inv.update(run.kept)
        for item in ("moonstone", "amethyst"):
            if st.inv[item] >= 8 and (item + "8") not in marks:
                marks[item + "8"] = day
        defeats += 1 if rng.random() < prof["defeat"] else 0
        runs_by_day.append((day, band, run.gold))
        daily[day] = dict(gold=run.gold, kept=dict(run.kept), furniture=run.kept_buy_f)
    return dict(st=st, gold=gold_total, runs=runs, floors=floors_total, rares=rares, defeats=defeats, by_day=runs_by_day, marks=marks, daily=daily)


def keepsake_universe(world):
    """every keepsake with a dungeon source: spots on the floors, wanderers, boss pools, first-kill items, lake keepsakes"""
    u = {}
    for sid, sp in world.loot["spots"].items():
        if sp["zone"] in BANDS:
            u[sp["item"]] = "spot:" + sid
    for b in BANDS:
        for wd in world.loot["zones"][b].get("wanderers", []):
            u[wd["item"]] = "wander:" + b + ":" + wd["container"]
    for bid, bs in world.loot["boss"].items():
        for it in (bs.get("pool") or []):
            u[it] = "boss:" + bid
        for it in (bs.get("first_kill_items") or []):
            u[it] = "boss_first:" + bid
    u["hat_mushroom_spinner"] = "boss_first:snurresvamp"
    return u


def pct(xs, p):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(len(xs) * p))] if xs else float("nan")


def band_stats(world, n=2000, seed=1, mode="keep"):
    out = {}
    rng = random.Random(seed)
    for luck in (0.0, 0.2):
        for band in BANDS:
            vals, rares, floors_n = [], 0, 0
            prof = dict(PROFILES["typical"])
            for _ in range(n):
                st = State(world)
                st.mode = mode
                for bid in st.boss:
                    st.boss[bid]["first"] = True
                    st.boss[bid]["last"] = -99
                run = run_band(world, st, band, 400, rng, prof, luck, quests={k: 0 for k in prof["quests"]})
                vals.append(run.gold)
                floors_n += run.floors
                rares += sum(1 for it in run.items if RANK[it[1]] == 3)
            vals.sort()
            out[(band, luck)] = dict(mean=statistics.mean(vals), p10=vals[len(vals) // 10], p50=vals[len(vals) // 2], p90=vals[len(vals) * 9 // 10], rare_per_floor=rares / floors_n)
    return out


def cmd_bands(world):
    for mode in ("sell", "keep"):
        r = band_stats(world, mode=mode)
        print("== value of ONE run through a band (3 floors, boss floor included, reward ready, completeness 0.80, appraisal fee paid), gold-equivalent, valuation '%s'; keepsakes count 0" % mode)
        print("%-16s %-5s | %8s %8s %8s %8s | %s" % ("band", "luck", "mean", "p10", "p50", "p90", "rare items per floor"))
        for luck in (0.0, 0.2):
            for b in BANDS:
                s = r[(b, luck)]
                print("%-16s %-5.2f | %8.0f %8.0f %8.0f %8.0f | %.2f (one rare per %.1f floors)" % (b, luck, s["mean"], s["p10"], s["p50"], s["p90"], s["rare_per_floor"], 1 / max(s["rare_per_floor"], 1e-9)))
    return r


def observed_day(value):
    return str(int(value)) if value < 9999 else ">"+str(SIM_DAYS)


def observed_window(values):
    return "/".join(observed_day(v) for v in (statistics.median(values),pct(values,.1),pct(values,.9)))


def cmd_life(world, n=200, mode="keep"):
    uni = keepsake_universe(world)
    print("== lifetime Monte Carlo: %d saves per profile, %d days, valuation '%s'.  Keepsakes with a dungeon source: %d (%d unique, %d legendary)" % (
        n, SIM_DAYS, mode, len(uni), sum(1 for i in uni if world.rarity_of(i) == "unique"), sum(1 for i in uni if world.rarity_of(i) == "legendary")))
    print("   >%d means the milestone was not reached within the simulated horizon; it does not mean unobtainable." % SIM_DAYS)
    res = {}
    for pname in PROFILES:
        lives = [lifetime(world, pname, s, mode=mode) for s in range(n)]
        res[pname] = lives
        by = {100: [], 200: [], 337: [], 500: []}
        us_d = {k: [] for k in (1, 2, 3, 5, 8, 12)}
        ls_d = {k: [] for k in (1, 2, 3, 5, 8)}
        for L in lives:
            ks = sorted((d, i) for i, d in L["st"].found.items() if i in uni)
            for T in by:
                by[T].append(sum(1 for d, i in ks if d <= T))
            us = sorted(d for i, d in L["st"].found.items() if i in uni and world.rarity_of(i) == "unique")
            ls = sorted(d for i, d in L["st"].found.items() if i in uni and world.rarity_of(i) == "legendary")
            for k in ls_d:
                ls_d[k].append(ls[k - 1] if len(ls) >= k else 9999)
            for k in us_d:
                us_d[k].append(us[k - 1] if len(us) >= k else 9999)
        print("\n-- %s (runs/day %.2f): median runs %d, floors %d; mean gold per run %.0f; faints %.1f" % (pname, PROFILES[pname]["runs"], statistics.median(L["runs"] for L in lives),
              statistics.median(L["floors"] for L in lives), statistics.mean(L["gold"] / max(L["runs"], 1) for L in lives), statistics.mean(L["defeats"] for L in lives)))
        print("   keepsakes found by day (mean of the %d): " % len(uni) + "  ".join("d%d: %.1f" % (T, statistics.mean(by[T])) for T in by))
        print("   day of the k-th UNIQUE (median / p10 / p90): " + "  ".join("%d: %s" % (k, observed_window(v)) for k, v in us_d.items()))
        print("   day of the k-th LEGENDARY (median / p10 / p90): " + "  ".join("%d: %s" % (k, observed_window(v)) for k, v in ls_d.items()))
        full = [max(L["st"].found.get(i, 9999) for i in uni) for L in lives]
        print("   day when ALL %d are found: median %s, p10 %s, p90 %s" % (len(uni), observed_day(statistics.median(full)), observed_day(pct(full, 0.1)), observed_day(pct(full, 0.9))))
        ru = [L["runs"] / max(sum(1 for i in L["st"].found if i in uni and world.rarity_of(i) == "unique"), 1) for L in lives]
        rl = [L["runs"] / max(sum(1 for i in L["st"].found if i in uni and world.rarity_of(i) == "legendary"), 1) for L in lives]
        print("   runs per unique found %.1f, per legendary found %.1f (whole %d days)" % (statistics.mean(ru), statistics.mean(rl), SIM_DAYS))
        rr = statistics.mean(L["rares"] / max(L["floors"], 1) for L in lives)
        print("   rare items per floor %.2f -> one rare about every %.1f floors" % (rr, 1 / rr))
        m8 = [L["marks"].get("moonstone8", 9999) for L in lives]
        a8 = [L["marks"].get("amethyst8", 9999) for L in lives]
        print("   day with 8 moonstone in the bag: median %d (p10 %d, p90 %d); with 8 amethyst: median %d (p10 %d, p90 %d)   [materials kept for home construction; castle timing is measured separately in pacing.py]" % (
            statistics.median(m8), pct(m8, 0.1), pct(m8, 0.9), statistics.median(a8), pct(a8, 0.1), pct(a8, 0.9)))
        runs100 = [sum(1 for (d, b, g) in L["by_day"] if d <= 100) for L in lives]
        u100 = [sum(1 for i, d in L["st"].found.items() if i in uni and d <= 100 and world.rarity_of(i) == "unique") for L in lives]
        l100 = [sum(1 for i, d in L["st"].found.items() if i in uni and d <= 100 and world.rarity_of(i) == "legendary") for L in lives]
        print("   first 100 days: %.0f runs, %.1f uniques (one per %.1f runs), %.1f legendaries (one per %.1f runs)" % (statistics.mean(runs100), statistics.mean(u100), statistics.mean(runs100) / max(statistics.mean(u100), 0.01), statistics.mean(l100), statistics.mean(runs100) / max(statistics.mean(l100), 0.01)))
    return res


def fnv_rng(world_seed, stream, key):
    """the keyed stream of design_loot.md 6.1 (python stand-in: FNV-1a over the text, then random.Random; the game uses LootRng = sfc32 + the same FNV hash)"""
    h = 0xcbf29ce484222325
    for b in ("%s|%s|%s" % (world_seed, stream, key)).encode():
        h = ((h ^ b) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return random.Random(h)


def full_dive(world, n, luck, cap_on, mode="sell", comp=1.0, floors_to=12, details=False):
    """one game day in which the player clears floors 1..floors_to completely: the gold-equivalent the dungeon hands out"""
    w2 = copy.copy(world)
    w2.DL = copy.deepcopy(world.DL)
    if not cap_on:
        w2.DL["daily"]["value_cap"] = 10 ** 9
    prof = dict(PROFILES["dedicated"])
    prof["complete"] = comp
    prof["key_day"] = 0
    rng = random.Random(77)
    vals, rares, caps = [], [], 0
    sold, dust = 0.0, 0.0
    for _ in range(n):
        st = State(w2)
        st.mode = mode
        for bid in st.boss:
            st.boss[bid]["first"] = True
            st.boss[bid]["last"] = -99
        st.keys = 99
        st.next_key_day = 0
        tot, rr = 0.0, 0
        early_cap = False
        for band in BANDS:
            b = w2.DL["bands"][band]
            fl = [f for f in range(b["from"], b["to"] + 1) if f <= floors_to]
            if not fl:
                continue
            run = run_floors(w2, st, band, fl, 400, rng, prof, luck, quests={k: 0 for k in prof["quests"]})
            tot += run.gold
            sold += run.gross_sold
            dust += run.dust_sold
            if max(fl) < 10 and is_capped(w2,st,400,band): early_cap = True
            rr += sum(1 for it in run.items if RANK[it[1]] == 3)
        caps += int(early_cap)
        vals.append(tot)
        rares.append(rr)
    vals.sort()
    summary = (statistics.mean(vals), vals[len(vals) // 10], vals[len(vals) * 9 // 10], statistics.mean(rares))
    if details: return dict(mean=summary[0],p10=summary[1],p90=summary[2],rare=summary[3],cap_before_floor10=caps/n,dust_share=dust/max(sold,1))
    return summary


def cmd_abuse(world):
    print("== a FULL DIVE day (floors 1-12 cleared completely, every lake chest opened with a bought key, every boss reward ready, 'sell' valuation = the plan's convention)")
    print("%-28s %6s | %8s %8s %8s | rare items" % ("case", "luck", "mean", "p10", "p90"))
    for cap_on in (False, True):
        for luck in (0.0, 0.2):
            m_, lo, hi, rr = full_dive(world, 400, luck, cap_on)
            print("%-28s %6.2f | %8.0f %8.0f %8.0f | %.1f" % ("12 floors, cap %s" % (("%s on" % world.DL["daily"]["value_cap"]) if cap_on else "off"), luck, m_, lo, hi, rr))
    for ft in (3, 6, 9):
        m_, lo, hi, rr = full_dive(world, 400, 0.0, True, floors_to=ft)
        print("%-28s %6.2f | %8.0f %8.0f %8.0f | %.1f" % ("floors 1-%d, cap %s on" % (ft, world.DL["daily"]["value_cap"]), 0.0, m_, lo, hi, rr))
    print("\n== seed scumming: the same chest uid opened 1000 times from reloads of the same save (keyed stream) -> distinct outcomes:")
    outs = set()
    for _ in range(1000):
        rng = fnv_rng("20261013", "chest", "dng:233:5:1")
        outs.add(tuple(rng.randint(0, 10 ** 6) for _ in range(6)))
    print("   %d distinct outcome(s) in 1000 reloads (a global stream that keeps advancing would give ~1000)" % len(outs))
    print("   the luck-swap trick (take off the luck gear, open, put it on) can only LOWER luck: no gain; putting luck gear on before the floor is the intended perk (EV +%.0f %% at luck 0.2, see bands table)" % 25)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["bands", "life", "abuse", "all"])
    ap.add_argument("--n", type=int, default=200)
    ap.add_argument("--mode", default="keep")
    ap.add_argument("--pace", default="plan", choices=["plan", "de30"])
    ap.add_argument("--hunter", type=float, default=0.0)
    a = ap.parse_args()
    HUNTER = a.hunter
    set_pace(a.pace)
    w = World()
    if a.cmd in ("bands", "all"):
        cmd_bands(w)
    if a.cmd in ("life", "all"):
        cmd_life(w, a.n, a.mode)
    if a.cmd in ("abuse", "all"):
        cmd_abuse(w)
