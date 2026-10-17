"""Dungeon data checks on evaluated Lua, independent of the runtime roll code.

The legacy furniture/art catalogue rules retain their narrower field contracts.
This module covers every new dungeon item and all live generator tables.
"""
from collections import defaultdict
import re

COMMON = ('normal', 'uncommon', 'rare')
KEEPSAKES = ('unique', 'legendary')
SWORD_DAMAGE = dict(zip(COMMON + KEEPSAKES, (5, 12, 22, 30, 42)))
FACTORS = dict(sword=1, dagger=.65, club=1.35, spear=1.08, staff=1.125)


def validate(records):
    rows = {}
    def check(rule, problems):
        rows[rule] = problems
    def table(path, key):
        return records[path]['config'][key]
    items, shops, recipes = {}, {}, {}
    for path, values in records.items():
        if path.startswith('lua/items/'): items.update(values.get('items', {}))
        if path.startswith('lua/shops/'): shops.update(values.get('shops', {}))
        if path.startswith('lua/recipes/'): recipes.update(values.get('recipes', {}))
    weapons = records['lua/items/weapons.lua']['items']
    gems = records['lua/items/gems.lua']['items']
    materials = records['lua/items/dungeon_materials.lua']['items']
    extra = {**weapons, **gems, **materials}
    dl = table('lua/config/dungeon_loot.lua', 'dungeon_loot')
    gen = table('lua/config/dungeon.lua', 'dungeon')
    run = table('lua/config/dungeon_run.lua', 'dungeon_run')
    bosses = table('lua/config/bosses.lua', 'bosses')
    loot = table('lua/data/loot_tables.lua', 'loot')
    bands, floors = dl['bands'], gen['floors']
    yields = dl['node_yields']
    placed = set()
    floor_nodes = defaultdict(set)
    for floor in floors:
        kinds = {k for k,n in (floor.get('nodes') or {}).items() if n > 0}
        for anchor in floor.get('anchors') or []:
            if anchor.get('marker') == 'node' and anchor.get('count', 1) > 0:
                match = re.search(r'(?:^|\s)kind=([a-z_]+)', anchor.get('params', ''))
                if match: kinds.add(match[1])
        placed.update(kinds)
        floor_nodes[floor['band']].update(kinds)
    aliases = {v['alias'] for v in yields.values() if v.get('alias')}
    def resolved(kind):
        seen = set()
        while kind in yields and kind not in seen:
            seen.add(kind)
            row = yields[kind]
            if not row.get('alias'): return row
            kind = row['alias']
        return None
    def yield_items(row, band):
        if row is None: return set()
        found = {row['item']} if row.get('item') else set()
        if row.get('rough'): found.add(bands[band]['rough'])
        if row.get('fallback'): found.add(row['fallback']['item'])
        for e in row.get('extra') or []:
            if not e.get('bands') or band in e['bands']: found.add(e['item'])
        return found

    check('W1 weapon damage follows the independent rarity/family curve', [i for i,e in weapons.items() if e.get('weapon_family') not in FACTORS or abs(e.get('damage',0)-SWORD_DAMAGE.get(e.get('rarity'),0)*FACTORS.get(e.get('weapon_family'),0)) > .5])
    allowed_effects = set(run['weapon_effects'])
    check('W2 weapon fields and effects match combat capabilities', [i for i,e in weapons.items() if e.get('category') != 'weapon' or e.get('max_stack') != 1 or e.get('stamina_cost') != 0 or (e.get('rarity') in ('rare',)+KEEPSAKES) != bool(e.get('effect')) or (e.get('effect') and e['effect'].get('id') not in allowed_effects)])
    check('W3 dungeon keepsakes are protected and never sellable', [i for i,e in extra.items() if e['rarity'] in KEEPSAKES and (e.get('buy_price') != 0 or e.get('sell_price') != 0 or not e.get('protected') or not e.get('hint_key'))])
    check('C13 dungeon ordinary items have valid nominal and sell prices', [i for i,e in extra.items() if e['rarity'] in COMMON and not e.get('rough') and not (0 < e.get('sell_price',0) < e.get('buy_price',0))])
    check('C18 every dungeon item has a usable acquire/source route', [i for i,e in extra.items() if not e.get('acquire') or not e.get('sources')])

    pool_locations = defaultdict(set)
    pool_problems = []
    for zone,z in loot['zones'].items():
        for kind,pools in z['pools'].items():
            for rarity,pool in pools.items():
                for entry in pool:
                    item = entry.get('item'); e = items.get(item,{})
                    pool_locations[item].add(zone)
                    if e.get('rarity') != rarity or rarity in KEEPSAKES or not isinstance(entry.get('w'),int) or entry['w'] <= 0: pool_problems.append((zone,kind,rarity,item))
    check('R1 dungeon pool ids, rarities and weights are valid', pool_problems)
    problems = []
    for i,e in extra.items():
        declared = {s['zone'] for s in e['sources'] if s['kind']=='find' and not s.get('container')}
        expected = {e['appraise_band']} if e.get('rough') else pool_locations[i]
        if e['rarity'] in COMMON and declared != expected: problems.append((i,sorted(declared),sorted(expected)))
    check('R2 dungeon find sources mirror the actual pools and band rough rolls',problems)
    problems = []
    for i,e in extra.items():
        for source in e['sources']:
            kind = source['kind']
            if kind == 'spot':
                spot = loot['spots'].get(source.get('spot'),{})
                if spot.get('item')!=i or spot.get('zone')!=source.get('zone'):problems.append((i,source))
            elif kind == 'boss':
                boss = loot['boss'].get(source.get('enemy'),{})
                pool = boss.get('first_kill_items',[]) if source.get('first_kill') else boss.get('pool',[])
                if i not in pool:problems.append((i,source))
            elif kind == 'find' and source.get('container'):
                wander = loot['zones'].get(source.get('zone'),{}).get('wanderers',[])
                if not any(w['item']==i and w['container']==source['container'] for w in wander):problems.append((i,source))
            elif kind == 'creature':
                if not any(row.get('item')==i and 0<row.get('bp',0)<=10000 for row in dl['drops'].get(source.get('enemy'),[])):problems.append((i,'creature drop mirror',source))
            elif kind not in ('find','node','appraisal','drop','craft','shop'):problems.append((i,'unknown source',kind))
    for boss,b in loot['boss'].items():
        for i in list(b.get('pool') or [])+list(b.get('first_kill_items') or []):
            if i not in items or not any(s.get('kind')=='boss' and s.get('enemy')==boss for s in items[i].get('sources',[])):problems.append((boss,'missing reverse boss source',i))
    check('R3 dungeon fixed sources and boss rewards mirror both directions',problems)
    problems = []
    for i,e in extra.items():
        if e['rarity'] in KEEPSAKES and any(s['kind'] in ('shop','craft','appraisal') for s in e['sources']):problems.append((i,'keepsake in generic source'))
        for source in e['sources']:
            if source['kind']=='craft':
                r=recipes.get(source.get('recipe'),{})
                if r.get('output',{}).get('item')!=i:problems.append((i,'recipe mirror',source))
    check('W4 weapons and gems keep fixed rewards separate from crafting and shops',problems)
    problems=[]
    for rid,r in records['lua/recipes/dungeon.lua']['recipes'].items():
        output=items.get(r.get('output',{}).get('item'),{})
        cost=0
        for i,n in r.get('ingredients',{}).items():
            e=items.get(i,{})
            cost+=n*(e.get('buy_price',0) or dl['limits']['recipe_unbuyable_mult']*e.get('sell_price',0))
            if not e or not isinstance(n,int) or n<=0:problems.append((rid,'ingredient',i,n))
        buy=output.get('buy_price',0)*r.get('output',{}).get('amount',0)
        sell=output.get('sell_price',0)*r.get('output',{}).get('amount',0)
        if not (.45*buy<=cost<=.85*buy and sell<cost) or output.get('rarity') in KEEPSAKES or r.get('station') not in ('snedkerbord','smedje'):problems.append((rid,'cost/station',cost,buy,sell))
    check('W5 forge recipes cost 45-85 percent with configured unbuyable valuation',problems)
    problems=[(i,'unknown shop',source.get('shop')) for i,e in extra.items() for source in e['sources'] if source['kind']=='shop' and source.get('shop') not in shops]
    for shop,s in shops.items():
        stock=set(s.get('stock') or {})
        for r in s.get('rotation') or []:stock.update(r.get('pool') or [])
        for i in stock:
            if i in extra and (extra[i]['rarity'] in KEEPSAKES or not any(x['kind']=='shop' and x.get('shop')==shop for x in extra[i]['sources'])):problems.append((shop,i))
        for i,e in extra.items():
            if any(x['kind']=='shop' and x.get('shop')==shop for x in e['sources']) and i not in stock:problems.append((i,'missing shop stock',shop))
    check('R7 dungeon shop sources mirror stock and exclude keepsakes',problems)
    rough={i:e for i,e in gems.items() if e.get('rough')}
    check('G1 one unsellable rough gem per band', [] if len(rough)==len(bands) and all(e.get('appraise_band')==b and i in rough and e.get('category')=='gem' and e.get('max_stack')==99 and e.get('buy_price')==0 and e.get('sell_price')==0 for b,v in bands.items() for i,e in [(v['rough'],gems.get(v['rough'],{}))]) else ['rough/band mismatch'])
    themes=set(dl['lantern_gem']['unit'])
    check('G2 lantern gem themes and tints are supported', [i for i,e in gems.items() if not e.get('rough') and (e.get('category')!='gem' or e.get('max_stack')!=(1 if e.get('rarity') in KEEPSAKES else 99) or not re.fullmatch('[0-9a-fA-F]{6}',e.get('lantern',{}).get('tint','')) or not set(e.get('lantern',{}).get('themes',[]))<=themes)])
    problems=[]
    for band,odds in dl['appraisal']['odds'].items():
        if band not in bands or sum(odds.values())!=10000:problems.append((band,'odds'))
        for rarity,weight in odds.items():
            pool=dl['appraisal']['pools'].get(rarity,[])
            if weight>0 and not pool:problems.append((band,'empty pool',rarity))
    for rarity,pool in dl['appraisal']['pools'].items():
        for ent in pool:
            e=items.get(ent['item'],{})
            if rarity not in COMMON or e.get('rarity')!=rarity or e.get('rough') or e.get('category') not in ('gem','resource','building_material','material') or ent.get('w',0)<=0:problems.append(('appraisal',rarity,ent))
    for i,e in gems.items():
        for s in e['sources']:
            if s['kind']=='appraisal' and (s.get('zone') not in dl['appraisal']['odds'] or not any(x['item']==i for x in dl['appraisal']['pools'].get(e['rarity'],[]))):problems.append((i,'appraisal mirror'))
    check('G3 appraisal only produces ordinary cut gems with valid band odds',problems)
    problems=[]
    for i,e in extra.items():
        for source in e['sources']:
            if source['kind']=='node':
                node=source.get('node');band=source.get('zone')
                available=floor_nodes.get(band,set())
                can_place=node in available or any(yields.get(k,{}).get('alias')==node for k in available)
                if not can_place or i not in yield_items(resolved(node),band):problems.append((i,source))
    problems.extend((i,'material fields') for i,e in materials.items() if e.get('category')!='material' or e.get('group')!='dungeon' or e.get('max_stack')!=(1 if e.get('rarity') in KEEPSAKES else 99))
    check('M1 node material sources resolve to placed generator nodes and real yields',problems)
    check('M2 dungeon materials sell at most the configured share of nominal buy', [i for i,e in materials.items() if e['rarity'] in COMMON and e['sell_price']>e['buy_price']*dl['limits']['material_sell_max_pct']/100])
    shards={i for i,e in materials.items() if i.startswith('dng_rune_')}
    first=[i for b in loot['boss'].values() for i in b.get('first_kill_items') or [] if i.startswith('dng_rune_')]
    vault=loot['spots'].get('runehvaelvingen',{})
    check('K1 three first-kill shards are all required and consumed by the vault', [] if len(shards)==3 and len(first)==3 and set(first)==shards==set(vault.get('consume',[]))==set(vault.get('requires',{}).get('items',[])) and len({s.get('enemy') for i in shards for s in materials[i]['sources'] if s.get('first_kill')})==3 else ['orphan/duplicate shard or incomplete vault requirement'])
    expected={f['n']:f['band'] for f in floors}
    actual={n:b for b,v in bands.items() for n in range(v['from'],v['to']+1)}
    check('DB1 all twelve floor bands agree between layout and loot', [] if expected==actual and sorted(expected)==list(range(1,gen['max_floor']+1)) and set(bands)==set(gen['bands']) and all(v['from']==gen['bands'][b]['first'] and v['to']==gen['bands'][b]['last'] for b,v in bands.items()) else ['floor/band mismatch'])
    expected_boss={f['boss']:f['n'] for f in floors if f.get('boss')}
    check('DB2 boss ids and floors agree across all five tables', [] if expected_boss=={b['id']:b['floor'] for b in dl['bosses']}=={k:v['floor'] for k,v in loot['boss'].items()}=={k:v['floor'] for k,v in bosses.items()} and set(expected_boss)==set(run['boss_kinds']) else ['boss/floor mismatch'])
    check('DB3 each band main chest tier agrees with its generated floor', [b for b,v in bands.items() if v['main_tier']!=gen['bands'][b]['chest_tier'] or v['main_tier'] not in loot['containers']])
    problems=[]; seen=set()
    for floor in floors:
        for sid in floor.get('spots') or []:
            spot=loot['spots'].get(sid,{})
            if sid in seen or spot.get('zone')!=floor['band'] or spot.get('floor',floor['n'])!=floor['n']:problems.append((floor['n'],sid))
            seen.add(sid)
    for sid,spot in loot['spots'].items():
        if spot['zone'] in bands and sid not in seen and not (spot.get('container')=='noegle' and spot.get('floor') in expected and floors[spot['floor']-1].get('lake')=='noegle' and expected[spot['floor']]==spot['zone']):problems.append((sid,'no generated placement'))
        requires=spot.get('requires') or {}
        for i in list(requires.get('items') or [])+list(spot.get('consume') or []):
            if i not in items:problems.append((sid,'unknown required/consumed item',i))
    check('DB4 every forest spot has exactly one placement in its band',problems)
    problems=[]
    for kind in placed|set(yields):
        row=resolved(kind)
        if row is None:problems.append((kind,'missing yield or cyclic alias'))
        elif kind not in placed and kind not in aliases:problems.append((kind,'yield has no placed node or alias'))
        elif row.get('item') and row['item'] not in items:problems.append((kind,'unknown yield item'))
    check('DB5 generator nodes and anchors have reachable, non-orphan yields',problems)
    return rows
