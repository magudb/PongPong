#!/usr/bin/env python3
"""Proves the content validator is live: applies ONE deliberate defect at a time to a COPY of the files the validator reads and expects the named rule to FAIL.

    python3 tools/features/validate/mutation_test.py [--jobs N] [--only ID,ID] [--keep]

How: the stage manifest says which repo files feed the stage tree; they are copied (about 3 MB) into $WORK/s<i> (a repo-shaped tree), the mutant is applied there and
`run_validate.sh --stage f1 --src $WORK/s<i>` runs the whole pipeline (real Lua, project LuaRuntime in Godot, all rules) against it.  The repo itself is never touched.
Before the mutants a CONTROL run proves the unmutated copy is green (a mutation test on a red validator proves nothing).
Each worker owns a project copy ($WORK/w<i>, an APFS clone of the first one made with `cp -Rc`, so the import is paid once).
Mutants: the 26 of the reviewed pack (17 of the first pack + R15, R16, R17, R18, R20, K7, K8, S13, Q4) + 4 for the rules this package added (SK1, SK2, FG1, N1)
+ 8 of the fix round after review F1 r1 (N1 in a Lua file below the default stage path, S10 x3, SH1, R7 unknown stock id, MM1 x2)
+ 10 of the second fix round after review F1 r2 (R21 x2, Q5, C19, C20, SH2, R7d, K10, K9, D6).  N1 on .map / .svg / .tscn / .tres is proven in rules_selftest.py: the stage tree holds no such file,
and the whole-repo scan of N1 reads the real repo, which a mutant copy cannot change.
A mutant is CAUGHT only when the rule named in front of it fails (token compare: `S1` is not `S10`).  The crash guard `X validator crashed` is NOT a detection: a mutant that only crashes the
validator is reported as MISSED ("only the crash guard fired") - the rule that should name the defect does not exist or does not run.
The default --work lives under tools/features/_stage (like a normal run_validate.sh), which is exactly the path that made rule N1 vacuous: it is deliberately not overridden here.
Exit 0 only when the control is green and every mutant is caught.
"""
from __future__ import annotations
import argparse
import concurrent.futures as cf
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

FEAT = Path(__file__).resolve().parents[1]                 # tools/features
REPO = FEAT.parents[1]
HERE = Path(__file__).resolve().parent
OLD_TOWN = 'Fes' + 'by'                                       # the retired town name is never written out


def sub(old: str, new: str, count: int = 1):
    return lambda t: t.replace(old, new, count)


def resub(pattern: str, repl: str):
    return lambda t: re.sub(pattern, repl, t, count=1)


# (name, repo-relative file, transform) - the leading token of the name is the rule that must fail
MUTATIONS = [
    ('W1 weapon damage thirty percent too high', 'lua/items/weapons.lua', sub('damage = 3,', 'damage = 4,')),
    ('W5 forge ingredients cost the full buy price', 'lua/recipes/dungeon.lua', sub('ingredients = { wood = 5, dng_forest_thread = 2, stone = 2 }', 'ingredients = { wood = 16 }')),
    ('R7 legendary enters smithy rotation', 'lua/shops/smithy.lua', sub('pool = { "wpn_dagger_thorn",', 'pool = { "wpn_sword_moon", "wpn_dagger_thorn",')),
    ('G3 unique enters appraisal pool', 'lua/config/dungeon_loot.lua', sub('normal = { { item = "gem_rock_crystal",', 'normal = { { item = "gem_rune_heart", w = 10 }, { item = "gem_rock_crystal",')),
    ('K1 orphan rune shard', 'lua/data/loot_tables.lua', sub('first_kill_items = { "dng_rune_snurre" }', 'first_kill_items = {  }')),
    ('DB4 lake spot on wrong floor', 'lua/data/loot_tables.lua', sub('floor = 3,', 'floor = 4,')),
    ('DB2 boss disagrees with generator floor', 'lua/config/bosses.lua', sub('floor = 4,', 'floor = 5,')),
    ('M2 material sells above twenty-five percent', 'lua/items/dungeon_materials.lua', sub('sell_price = 2,', 'sell_price = 4,')),
    ('DB5 orphan node yield', 'lua/config/dungeon_loot.lua', sub('node_yields = {', 'node_yields = { orphan_probe = { item = "wood", amount = { 1, 1 } },')),
    ('S1 syntax error', 'lua/items/clothing.lua', sub('kind = "items"', 'kind = "items" }')),
    ('I1 duplicate item id', 'lua/items/furniture.lua', sub('  chair_pine = {', '  bed_pine = {')),
    ('C1 rarity split', 'lua/items/furniture.lua', sub('rarity = "legendary"', 'rarity = "unique"')),
    ('C5 unknown art template', 'lua/items/furniture.lua', sub('template = "bed"', 'template = "bunkbed"')),
    ('C8 clothing layer not in the wardrobe art', 'lua/items/clothing.lua', sub('layer = "hat_straw"', 'layer = "hat_top"')),
    ('C11 price monotonicity', 'lua/items/furniture.lua', resub(r'(  bed_walnut = \{[\s\S]*?buy_price = )\d+(,\s+sell_price = )\d+(,\s+worth = )\d+', r'\g<1>90\g<2>30\g<3>90')),
    ('C13 sell above buy', 'lua/items/furniture.lua', resub(r'(  bed_pine = \{[\s\S]*?sell_price = )\d+', r'\g<1>999')),
    ('C15 orphan set', 'lua/items/furniture.lua', sub('set = "svampehytten"', 'set = "svampehyttenx"')),
    ('R3 unique without source', 'lua/items/furniture.lua', sub('{ kind = "spot", zone = "svampelunden", spot = "svampering" }', '{ kind = "spot", zone = "svampelunden", spot = "nowhere" }')),
    ('R7 keepsake sold in a shop', 'lua/shops/home_shops.lua', sub('bed_pine = { stock = 3, restock = 2 }', 'bed_pine = { stock = 3, restock = 2 },\n      bed_moon = { stock = 1, restock = 1 }')),
    ('R9 odds do not sum', 'lua/data/loot_tables.lua', sub('odds = { normal = 7800, rare = 100, uncommon = 2100 }', 'odds = { normal = 7800, rare = 100, uncommon = 2000 }')),
    ('R13 tier gold not increasing', 'lua/data/home_tiers.lua', sub('gold = 900,', 'gold = 100,')),
    ('K1 missing loc key', 'localization/furniture.csv', sub('ITEM_BED_PINE_DESC', 'ITEM_BED_PINE_DESCX')),
    ('D1 English leftover in Danish', 'localization/wardrobe.csv', sub('Stråhat","Straw hat"', 'Stråhat with your hat","Straw hat"')),
    ('D1 TODO marker', 'localization/home.csv', sub('HOME_TIER_1,Skur,Shed', 'HOME_TIER_1,Skur TODO,Shed')),
    ('L6 forbidden Lua construct', 'lua/quests/bogtraeet.lua', sub('function on_accept(context)', 'function on_accept(context)\n  for i = 1, 3 do end')),
    ('R15 unreachable wardrobe set tier', 'lua/data/sets.lua', sub('{ pieces = 4, energy = 5, speed = 0.01 }', '{ pieces = 9, energy = 5, speed = 0.01 }')),
    ('R16 implemented baking falsely marked stub', 'lua/data/home_tiers.lua', sub('oven = "real"', 'oven = "stub"')),
    ('R17 unique label back at the damage colour', 'lua/config/rarity.lua', sub('label = "7d2e59"', 'label = "a8456a"')),
    ('R18 garment that can be owned twice', 'lua/items/clothing.lua', sub('max_stack = 1,', 'max_stack = 2,')),
    ('K7 whisper key missing', 'localization/features_ui.csv', sub('SHOP_UI_CLOSED_TODAY,', 'SHOP_UI_CLOSED_TODAYX,')),
    ('K8 key defined in the wrong file', 'localization/home.csv', sub('HOME_TIER_2_GATE,', 'WARDROBE_UI_TIER_2_GATE,')),
    ('S13 giver dialogue forgets the quest', 'data/features/pending/lua/dialogue/guard_oak.lua', sub('quest_id = "snurresvampen"', 'quest_id = "forest_patrol"')),
    ('Q4 objective nobody can complete', 'lua/quests/snurresvampen.lua', sub('on = "area_changed"', 'on = "manual"')),
    ('R20 unique garment looks like the uncommon one', 'lua/items/clothing.lua', sub('palette = { "6FD6C4", "F2C14E", "FBF5E6" }', 'palette = { "E3C372", "6FD6C4", "E3C372" }')),
    ('R6 money loop in a recipe', 'lua/recipes/furniture.lua', sub('ingredients = { plank_pine = 4, nails = 3, fabric_plain = 2 }', 'ingredients = { nails = 1 }')),
    # the rules of this package (starter kit CD3, friend gates, CD2 rename)
    ('SK1 starter kit names a piece that does not exist', 'lua/data/starter_kit.lua', sub('"chest_pine"', '"chest_pinex"')),
    ('SK2 starter kit overfills the shed', 'lua/data/starter_kit.lua', sub('chair_pine = 2,', 'chair_pine = 9, plant_fern = 9,')),
    ('FG1 friend gate nobody can earn', 'lua/data/home_tiers.lua', sub('friendship = { mayor_lyra = 4 }', 'friendship = { mayor_lyra = 14 }')),
    ('N1 the retired town name creeps back', 'localization/finds.csv', sub('FIND_AREA_HYGGEBYEN,"Hyggebyen"', f'FIND_AREA_HYGGEBYEN,"{OLD_TOWN}"')),
    # the fix round after review F1 r1 (each one was UNDETECTED or detected only by the crash guard before)
    ('N1 the retired name in a Lua comment of the stage tree', 'lua/data/sets.lua', sub('-- Themed sets.', f'-- Themed sets of {OLD_TOWN}.')),
    ('S10 builder button opens a shop that does not exist', 'lua/dialogue/fairy_builder.lua', sub('shop_id = "builder_yard"', 'shop_id = "builder_yardx"')),
    ('S10 builder branch without a shop button', 'lua/dialogue/fairy_builder.lua', resub(r'action = "open_shop",\n\s+shop_id = "builder_yard",', 'action = "close",')),
    ('S10 tailor opens the furniture shop', 'lua/dialogue/fairy_tailor.lua', sub('shop_id = "tailor_shop"', 'shop_id = "furniture_shop"')),
    ('SH1 flea market opening days name a weekday that does not exist', 'lua/shops/home_shops.lua', sub('open_weekdays = { 5, 6 }', 'open_weekdays = { 5, 7 }')),
    ('R7 shop stock names an item that does not exist', 'lua/shops/home_shops.lua', sub('bed_pine = { stock = 3, restock = 2 }', 'bed_pinex = { stock = 3, restock = 2 }')),
    ('MM1 map marker area id does not match the loot zone', 'data/features/map_markers.json', sub('"hyggebyen"', '"hyggebyenx"')),
    ('MM1 map marker chest count differs from the loot table', 'data/features/map_markers.json', resub(r'("farm"[\s\S]*?"dig": )2', r'\g<1>4')),
    # the second fix round after review F1 r2 (each of these passed 93 of 93 before: a reference or a number that no rule read)
    ('R21 loot spot requires a quest that does not exist', 'lua/data/loot_tables.lua', sub('requires = { quests = { "lost_cat" } }', 'requires = { quests = { "lost_catx" } }')),
    ('R21 loot spot day_min 0', 'lua/data/loot_tables.lua', sub('requires = { day_min = 14 }', 'requires = { day_min = 0 }')),
    ('Q5 quest pays hearts to an npc that does not exist', 'lua/quests/moonstone_crown.lua', sub('friendship = { fairy_king = 2 }', 'friendship = { fairy_kingx = 2 }')),
    ('C19 an ordinary bed stacks to 99', 'lua/items/furniture.lua', resub(r'(  bed_pine = \{[\s\S]*?max_stack = )9', r'\g<1>99')),
    ('C20 a legendary piece with no hygge points', 'lua/items/furniture.lua', resub(r'(  bed_moon = \{[\s\S]*?decor = )\d+', r'\g<1>0')),
    ('SH2 shop shelf with a negative stock', 'lua/shops/home_shops.lua', sub('bed_pine = { stock = 3, restock = 2 }', 'bed_pine = { stock = -3, restock = 2 }')),
    ('R7d the circlet is drawn on the z of the hat', 'lua/data/wardrobe_rules.lua', sub('subslot = "circlet", z = 41', 'subslot = "circlet", z = 40')),
    ('K10 furnisher voice key does not follow voice/<speaker>/<line id>', 'lua/dialogue/fairy_furnisher.lua', sub('voice/fairy_furnisher/greet', 'voice/fairy_furnisher/gret')),
    ('K9 loot creature name key that no CSV owns', 'lua/data/loot_tables.lua', sub('name_key = "ENEMY_BAT"', 'name_key = "ENEMYBAT"')),
    ('D6 a Danish description literal creeps back into a quest', 'lua/quests/bogtraeet.lua', sub('description_key = "OBJ_BOGTRAEET_RETURN_TO_ZEPHYR",', 'description = "Fortæl Zephyr, at du kan regne",\n    description_key = "OBJ_BOGTRAEET_RETURN_TO_ZEPHYR",')),
]


def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def prepare_src(dst: Path, stage: str = 'f1') -> None:
    if dst.exists():
        shutil.rmtree(dst)
    r = sh([sys.executable, '-I', str(HERE / 'stage.py'), '--repo', str(REPO), '--stage', stage, '--list'])
    if r.returncode:
        raise SystemExit('stage.py --list failed: ' + r.stderr)
    for rel in sorted(set(r.stdout.split())):
        s = REPO / rel
        d = dst / rel
        d.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(s, d)


def run_pipeline(src: Path, work: Path, reports: Path) -> tuple[int, str]:
    env = {**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'}
    r = sh(['bash', str(HERE / 'run_validate.sh'), '--stage', 'f1', '--src', str(src), '--work', str(work), '--reports', str(reports)], env=env, timeout=1500)
    return r.returncode, r.stdout + r.stderr


def run_one(i: int, name: str, rel: str, fn, root: Path) -> tuple[str, bool, str]:
    src, work, rep = root / f's{i}', root / f'w{i}', root / f'r{i}'
    prepare_src(src)
    p = src / rel
    t = p.read_text(encoding='utf-8')
    n = fn(t)
    if n == t:
        return name, False, f'MUTATION DID NOT CHANGE {rel} (the anchor text is gone: update mutation_test.py)'
    p.write_text(n, encoding='utf-8')
    rc, out = run_pipeline(src, work, rep)
    want = name.split()[0]
    failed = [ln for ln in out.split('\n') if ln.startswith('[FAIL]')]
    rule_of = lambda ln: (ln.split() + ['', ''])[1]                      # noqa: E731  '[FAIL] S10 text' -> 'S10' (token compare: S1 must not match S10)
    hit = any(rule_of(ln) == want for ln in failed) or (want == 'S1' and 'luac FAILED' in out)
    crashed = any(rule_of(ln) == 'X' for ln in failed)
    # review F1 r1: the crash guard is NOT a detection.  A defect that only crashes the validator means no rule names it (and every rule after the crash did not run).
    detail = f"exit {rc}; failing: {[ln[7:32] for ln in failed][:6]}"
    if not hit and crashed:
        detail = 'ONLY the crash guard (X validator crashed) fired, rule ' + want + ' did not: ' + detail
    return name, hit, detail


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--jobs', type=int, default=3)
    ap.add_argument('--only', default='')
    ap.add_argument('--keep', action='store_true')
    ap.add_argument('--work', default=os.environ.get('TT_FEATURES_MUT_WORK', str(FEAT / '_stage' / 'mut')))
    a = ap.parse_args()
    root = Path(a.work)
    if root.exists():
        shutil.rmtree(root)
    root.mkdir(parents=True)
    # control: the unmutated copy must be green, and it builds the project copy that the workers clone
    prepare_src(root / 's0')
    rc, out = run_pipeline(root / 's0', root / 'w0', root / 'r0')
    res = re.search(r'RESULT: (\d+) passed, (\d+) failed', out)
    print(f"[CONTROL] unmutated copy: exit {rc}, {res.group(0) if res else 'no result line'}")
    if rc != 0:
        print(out[-3000:])
        return 1
    only = {x for x in a.only.split(',') if x}
    todo = [(i, m) for i, m in enumerate(MUTATIONS) if not only or m[0].split()[0] in only]
    workers = max(1, a.jobs)
    for w in range(1, workers):
        subprocess.run(['cp', '-Rc', str(root / 'w0'), str(root / f'w{w}')], check=True)
    results = []

    # one slot = one worker directory set: work dir w<slot> is the project copy, s<slot>/r<slot> are scratch
    def worker(slot: int, items):
        out_rows = []
        for idx, (name, rel, fn) in items:
            row = run_one(slot, name, rel, fn, root)
            out_rows.append((idx, row))
            tag = 'CAUGHT' if row[1] else 'MISSED'
            print(f'[{tag}] {row[0]}   ({row[2]})', flush=True)
        return out_rows

    chunks = [todo[k::workers] for k in range(workers)]
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        futs = [ex.submit(worker, k, chunks[k]) for k in range(workers)]
        for f in futs:
            results += f.result()
    results.sort()
    caught = sum(1 for _, r in results if r[1])
    print(f'MUTATION TEST: {caught} of {len(results)} mutants caught')
    if not a.keep:
        shutil.rmtree(root, ignore_errors=True)
    return 0 if caught == len(results) else 1


if __name__ == '__main__':
    sys.exit(main())
