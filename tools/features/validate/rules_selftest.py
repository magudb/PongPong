#!/usr/bin/env python3
"""Self-test of the rule helpers of validate.py on small SYNTHETIC inputs: every rule must be seen failing on the defect it exists for (review F1 r1: rule N1 was vacuous for the
default stage path and every run stayed green).  No Godot, no Lua, no art venv: about a second.  Prints one `PASS <id>` / `FAIL <id>` line per check
(tests/lib/t.gd expect_tool_ids reads them; tests/sections/content_features.gd runs this file as `content_features.rules_selftest_*`).

    python3 -I tools/features/validate/rules_selftest.py

Checks
  n1_trap_is_real                         the first N1 filter (tests the ABSOLUTE path for _stage / reports) skips every file of a stage tree below tools/features/_stage
  n1_finds_old_name_below_stage_path      old_name_hits on such a tree finds the name in a Lua file and a CSV (and counts both files as visited)
  n1_prunes_build_output_below_root       a _stage / reports / __pycache__ directory BELOW the scan root is not scanned and not counted
  n1_clean_tree_has_no_hit                a tree without the name has no hit and every file is counted
  n1_visited_counter_exposes_vacuity      an empty / missing root counts 0 files (the rule compares the count with the number of Lua / CSV files it must see)
  sh1_*                                   open_weekdays: valid flea market passes; {5, 7}, a missing list, a day twice, a string, a float 5.5, a shop with days that is not the flea market, other days fail
  s10_*                                   dialogue shop buttons: right shop passes; a typo, another keeper's shop, a state without a button, a shop_id literal that is no shop, an action without literal fail
  mm1_*                                   map markers equal the loot tables: equal passes; wrong area id, chest count, creature count, a missing / extra unique spot, a boss in the wrong area fail
                                          (an area that has only a loot spot and no loot zone, like Hyggebyen, is legal and must have no chests or creatures)
Second fix round (review F1 r2):
  n1_*  (more)                            the old name in a .map text map, .svg, .tscn, .tres, .gdshader is found; the whole-repo scan prunes .git / .venv / .godot / tools/features/reports and the "Style Guide" export
  r21_*                                   loot.spots.*.requires: unknown quest, day_min 0 / text, tier 0 / 11, unknown key, empty quest list, an item source that names another quest fail
  q5_*                                    quest references: friendship npc, hearts 0 / 11, giver, objective npc, reward item, negative gold fail
  c19_* c20_*                             max_stack (furniture 9, keepsakes 1, blueprint 1, material 1..99) and decor >= 1
  sh2_*                                   shop numbers: stock < 1, restock above stock / text, price, period 0, price_mult 0, season_boost < 1 fail
  r7d_*                                   wardrobe equip_slots: the circlet on the z of the hat, a z that is text, the same item_slot + subslot, no name key fail
  k10_*                                   voice keys: voice/<speaker>/<line id>, a spoken line without one, another speaker's key, a line id that does not match its text key, one key for two texts fail
  k9_*                                    creature name keys: defined passes, an owner CSV that has not landed = pending, a typo / an owner without the row / a key that is not upper case fail
  d6_*                                    no text literal in Lua: the ten Danish descriptions would be found, comments / paths / ids are not text
"""
from __future__ import annotations
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import validate as v  # noqa: E402  (module level: constants and helpers only, nothing runs on import)

fails = 0


def check(cid, ok, detail=''):
    global fails
    print(('PASS ' if ok else 'FAIL ') + cid + (f'  ({detail})' if detail and not ok else ''), flush=True)
    fails += 0 if ok else 1


OLD = v.OLD_TOWN_NAME.capitalize()


def write(p: Path, text: str) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding='utf-8')


def old_filter_skips(fp: Path) -> bool:
    """the first N1 implementation: a test on the absolute path"""
    return bool({'_stage', 'reports', '__pycache__'} & set(fp.parts))


def n1_tests(tmp: Path) -> None:
    repo = tmp / 'repo'
    tree = repo / 'tools' / 'features' / '_stage' / 'f1' / 'tree'             # where run_validate.sh puts the stage tree by default
    write(tree / 'lua' / 'data' / 'sets.lua', f'-- Themed sets of {OLD}\nkind = "config"\n')
    write(tree / 'localization' / 'finds.csv', f'keys,da,en\nFIND_AREA_X,"{OLD}","{OLD}"\n')
    write(tree / 'localization' / 'home.csv', 'keys,da,en\nHOME_X,"Hus","House"\n')
    check('n1_trap_is_real', all(old_filter_skips(p) for p in tree.rglob('*') if p.is_file()), 'the first filter would have looked at the tree')
    hits, seen = v.old_name_hits(tree, tree)
    check('n1_finds_old_name_below_stage_path', sorted(hits) == ['localization/finds.csv', 'lua/data/sets.lua'] and seen['.lua'] == 1 and seen['.csv'] == 2, f'{hits} {dict(seen)}')
    root = tmp / 'root2'
    write(root / 'lua' / 'a.lua', 'x = 1\n')
    write(root / '_stage' / 'p' / 'b.lua', f'x = "{OLD}"\n')
    write(root / 'reports' / 'r.json', f'"{OLD}"\n')
    write(root / '__pycache__' / 'c.json', f'"{OLD}"\n')
    write(root / 'docs' / 'reports_overview.md', 'a file whose NAME starts with reports is not a reports directory\n')
    hits, seen = v.old_name_hits(root, root)
    check('n1_prunes_build_output_below_root', hits == [] and seen['.lua'] == 1 and seen['.json'] == 0 and seen['.md'] == 1, f'{hits} {dict(seen)}')
    clean = tmp / 'clean'
    write(clean / 'lua' / 'a.lua', 'x = 1\n')
    write(clean / 'localization' / 'a.csv', 'keys,da,en\n')
    hits, seen = v.old_name_hits(clean, clean)
    check('n1_clean_tree_has_no_hit', hits == [] and seen['.lua'] == 1 and seen['.csv'] == 1, f'{hits} {dict(seen)}')
    hits, seen = v.old_name_hits(tmp / 'does_not_exist', tmp)
    check('n1_visited_counter_exposes_vacuity', hits == [] and seen['.lua'] == 0 and seen['.csv'] == 0, f'{hits} {dict(seen)}')
    # hit paths are reported relative to the base the caller gives
    hits, _ = v.old_name_hits(tree / 'lua', repo)
    check('n1_hit_paths_relative_to_base', hits == ['tools/features/_stage/f1/tree/lua/data/sets.lua'], str(hits))
    # review F1 r2: the text formats that N1 did not know (.map text maps of P04 / P11 / P19, .svg, scenes, resources, shaders)
    r3 = tmp / 'repo3'
    names = {'data/maps/town.map': f'name {OLD}\n', 'assets/a.svg': f'<title>{OLD}</title>\n', 'scenes/w.tscn': f'[node name="{OLD}"]\n', 'assets/t.tres': f'x = "{OLD}"\n', 'shaders/s.gdshader': f'// {OLD}\n'}
    for rel, text in names.items():
        write(r3 / rel, text)
    write(r3 / 'lua' / 'ok.lua', 'x = 1\n')
    hits, seen = v.old_name_hits(r3, r3)
    check('n1_finds_map_svg_tscn_tres_gdshader', sorted(hits) == sorted(names) and all(seen[x] == 1 for x in ('.map', '.svg', '.tscn', '.tres', '.gdshader')), f'{hits} {dict(seen)}')
    # the whole-repo scan: engine cache, git, virtual envs, scratch folders and the report folder are pruned, the user's design export is skipped, everything else is looked at
    r4 = tmp / 'repo4'
    write(r4 / 'data' / 'maps' / 'town.map', f'{OLD}\n')
    for pruned in ('.git/x.md', '.godot/x.json', 'tools/art/.venv/lib/x.py', '.playwright-mcp/x.md', 'tools/features/_stage/p/x.lua', 'tools/features/reports/x.json', 'node_modules/x.js', '.mimocode/x.md'):
        write(r4 / pruned, f'{OLD}\n')
    write(r4 / 'docs' / 'Style Guide v2.md', f'{OLD} (the design export keeps its own wording)\n')
    write(r4 / 'docs' / 'reports' / 'keep.md', f'{OLD}\n')                    # a folder called reports elsewhere IS scanned: only tools/features/reports is build output
    hits, seen = v.old_name_hits(r4, r4, skip_dirs=v.REPO_SKIP_DIRS, skip_rel=v.REPO_SKIP_REL)
    check('n1_repo_scan_prunes_git_venv_godot_reports', sorted(hits) == ['data/maps/town.map', 'docs/reports/keep.md'], str(hits))
    check('n1_repo_scan_skips_style_guide_export', 'docs/Style Guide v2.md' not in hits and seen['.md'] == 1, f'{hits} {dict(seen)}')
    check('n1_repo_scan_counts_map_files', seen['.map'] == 1, str(dict(seen)))
    from rename_town import TEXT_EXT
    check('n1_suffixes_are_the_rename_tools', set(v.SCAN_SUFFIXES) == set(TEXT_EXT) and {'.map', '.svg', '.tscn', '.tres'} <= set(v.SCAN_SUFFIXES), str(sorted(set(TEXT_EXT) ^ set(v.SCAN_SUFFIXES))))


def shop(**kw):
    d = {'keeper': 'pippin_boegeknop', 'stock': {}, 'rotation': []}
    d.update(kw)
    return d


def sh1_tests() -> None:
    def probs(flea_days, others=None, **flea_kw):
        shops = {'furniture_shop': shop(), 'tailor_shop': shop(), 'builder_yard': shop(), 'flea_market': shop(**flea_kw)}
        if flea_days is not None:
            shops['flea_market']['open_weekdays'] = flea_days
        for sid, days in (others or {}).items():
            shops[sid]['open_weekdays'] = days
        return v.shop_schedule_problems(shops)
    check('sh1_valid_schedule_passes', probs([5, 6]) == [] and probs([6, 5]) == [] and probs([5.0, 6.0]) == [], str(probs([5, 6])))
    check('sh1_weekday_seven_fails', len(probs([5, 7])) == 1 and probs([5, 7])[0][1].startswith('weekday index outside'), str(probs([5, 7])))
    check('sh1_negative_day_fails', bool(probs([-1, 6])), '')
    check('sh1_missing_list_fails', bool(probs(None)), 'the flea market without open_weekdays would be open every day')
    check('sh1_day_twice_fails', bool(probs([5, 5, 6])), '')
    check('sh1_string_day_fails', bool(probs(['5', 6])) and bool(probs([5.5, 6])) and bool(probs([True, 6])), '')
    check('sh1_empty_list_fails', bool(probs([])), '')
    check('sh1_other_days_fail', bool(probs([4, 6])) and bool(probs([5])) and bool(probs([5, 6, 0])), '')
    check('sh1_other_shop_with_days_fails', bool(probs([5, 6], {'tailor_shop': [0, 1]})), '')


REAL_SHOPS = {'furniture_shop': {'keeper': 'fairy_furnisher'}, 'tailor_shop': {'keeper': 'fairy_tailor'}, 'builder_yard': {'keeper': 'fairy_builder'}, 'flea_market': {'keeper': 'pippin_boegeknop'}}


def s10_tests() -> None:
    lit = 'choices = { { id = "materials", action = "open_shop", shop_id = "builder_yard" }, { id = "bye", action = "close" } }'
    ok_states = [('fairy_builder', 'idle_1', [('open_shop', 'builder_yard'), ('close', '')]), ('fairy_tailor', 'dialogue', [('open_shop', 'tailor_shop')])]
    check('s10_right_shops_pass', v.dialogue_shop_problems(REAL_SHOPS, ok_states, {'lua/dialogue/fairy_builder.lua': lit}) == [], '')
    typo = [('fairy_builder', 'idle_1', [('open_shop', 'builder_yardx')])]
    check('s10_typo_in_state_fails', len(v.dialogue_shop_problems(REAL_SHOPS, typo, {})) == 1, '')
    check('s10_typo_in_literal_fails', bool(v.dialogue_shop_problems(REAL_SHOPS, [], {'f.lua': lit.replace('builder_yard', 'builder_yardx')})), '')
    other = [('fairy_tailor', 'dialogue', [('open_shop', 'furniture_shop')])]
    check('s10_other_keepers_shop_fails', len(v.dialogue_shop_problems(REAL_SHOPS, other, {})) == 1, 'the tailor must open the tailor shop')
    check('s10_state_without_button_fails', len(v.dialogue_shop_problems(REAL_SHOPS, [('fairy_builder', 'done_5', [('close', '')])], {})) == 1, '')
    check('s10_empty_shop_id_fails', len(v.dialogue_shop_problems(REAL_SHOPS, [('fairy_builder', 'idle_1', [('open_shop', '')])], {})) == 1, '')
    check('s10_action_without_literal_fails', bool(v.dialogue_shop_problems(REAL_SHOPS, [], {'f.lua': 'x = { action = "open_shop" }'})), '')
    check('s10_literal_without_action_fails', bool(v.dialogue_shop_problems(REAL_SHOPS, [], {'f.lua': 'x = { shop_id = "builder_yard" }'})), '')


def markers_and_loot():
    loot = {
        'containers': {'trae': {}, 'dig': {}, 'konge': {}},
        'creatures': {'bat': {}},
        'zones': {
            'farm': {'containers': {'dig': {'count': 2}}, 'creatures': []},
            'wood': {'containers': {'trae': {'count': 3}, 'konge': {'count': 1}}, 'creatures': {'bat': 2}},
        },                                                                  # 'town' has a loot spot but no zone (like Hyggebyen)
        'spots': {'s1': {'zone': 'wood'}, 's2': {'zone': 'wood'}, 's3': {'zone': 'town'}},
        'boss': {'king': {'chest': 'konge'}},
    }
    markers = {'areas': {
        'farm': {'containers': {'dig': 2}, 'creatures': {}, 'unique_spots': []},
        'wood': {'containers': {'trae': 3, 'konge': 1}, 'creatures': {'bat': 2}, 'unique_spots': ['s1', 's2'], 'boss': 'king'},
        'town': {'containers': {}, 'creatures': {}, 'unique_spots': ['s3']},
    }}
    return markers, loot


def broken_later(m, l, fn):
    import copy
    mm, ll = copy.deepcopy(m), copy.deepcopy(l)
    fn(mm, ll)
    return v.map_marker_problems(mm, ll)


def mm1_tests() -> None:
    import copy
    m, l = markers_and_loot()
    check('mm1_equal_passes', v.map_marker_problems(m, l) == [], str(v.map_marker_problems(m, l)))
    check('mm1_chest_in_a_zoneless_area_fails', bool(broken_later(m, l, lambda mm, ll: mm['areas']['town']['containers'].update({'dig': 1}))), '')

    def broken(fn):
        mm, ll = copy.deepcopy(m), copy.deepcopy(l)
        fn(mm, ll)
        return v.map_marker_problems(mm, ll)
    check('mm1_area_of_a_spot_zone_is_required', bool(broken(lambda mm, ll: mm['areas'].pop('town'))), 'a spot in a zone without an area')
    check('mm1_wrong_area_id_fails', bool(broken(lambda mm, ll: mm['areas'].update({'townx': mm['areas'].pop('town')}))), '')
    check('mm1_missing_area_fails', bool(broken(lambda mm, ll: mm['areas'].pop('farm'))), '')
    check('mm1_chest_count_fails', bool(broken(lambda mm, ll: mm['areas']['wood']['containers'].update({'trae': 4}))), '')
    check('mm1_missing_container_fails', bool(broken(lambda mm, ll: mm['areas']['wood']['containers'].pop('konge'))), '')
    check('mm1_creature_count_fails', bool(broken(lambda mm, ll: mm['areas']['wood']['creatures'].update({'bat': 3}))), '')
    check('mm1_missing_spot_fails', bool(broken(lambda mm, ll: mm['areas']['wood']['unique_spots'].remove('s2'))), '')
    check('mm1_extra_spot_fails', bool(broken(lambda mm, ll: mm['areas']['town']['unique_spots'].append('s9'))), '')
    check('mm1_spot_in_wrong_area_fails', bool(broken(lambda mm, ll: ll['spots']['s1'].update({'zone': 'town'}))), '')
    check('mm1_boss_missing_fails', bool(broken(lambda mm, ll: mm['areas']['wood'].pop('boss'))), '')
    check('mm1_boss_without_chest_fails', bool(broken(lambda mm, ll: (mm['areas']['farm'].update({'boss': 'king'}), mm['areas']['wood'].pop('boss')))), '')
    check('mm1_unknown_container_fails', bool(broken(lambda mm, ll: (mm['areas']['farm']['containers'].update({'gold': 1}), ll['zones']['farm']['containers'].update({'gold': {'count': 1}})))), '')


# ----------------------------------------------------------------------------------------------------- second fix round (review F1 r2)
QUESTS = {'lost_cat', 'moonstone_crown'}
SPOTS = {'cat': {'zone': 'dybe', 'requires': {'quests': ['lost_cat']}}, 'day': {'zone': 'farm', 'requires': {'day_min': 14}}, 'tier': {'zone': 'farm', 'requires': {'home_tier_min': 3}}, 'plain': {'zone': 'farm'}}
SRC_Q = {'cat': 'lost_cat'}


def spots_with(**changes):
    import copy
    sp = copy.deepcopy(SPOTS)
    for k, val in changes.items():
        if val is None:
            sp.pop(k, None)
        else:
            sp[k] = val
    return sp


def r21_tests() -> None:
    ok = v.spot_requirement_problems(SPOTS, QUESTS, SRC_Q)
    check('r21_valid_passes', ok == [], str(ok))
    check('r21_unknown_quest_fails', bool(v.spot_requirement_problems(spots_with(cat={'zone': 'd', 'requires': {'quests': ['lost_catx']}}), QUESTS, {'cat': 'lost_catx'})), 'the keepsake could never be found')
    check('r21_day_min_zero_or_text_fails', bool(v.spot_requirement_problems(spots_with(day={'zone': 'f', 'requires': {'day_min': 0}}), QUESTS, SRC_Q)) and bool(v.spot_requirement_problems(spots_with(day={'zone': 'f', 'requires': {'day_min': '14'}}), QUESTS, SRC_Q))
          and bool(v.spot_requirement_problems(spots_with(day={'zone': 'f', 'requires': {'day_min': True}}), QUESTS, SRC_Q)), '')
    check('r21_tier_zero_and_eleven_fail', bool(v.spot_requirement_problems(spots_with(tier={'zone': 'f', 'requires': {'home_tier_min': 11}}), QUESTS, SRC_Q)) and bool(v.spot_requirement_problems(spots_with(tier={'zone': 'f', 'requires': {'home_tier_min': 0}}), QUESTS, SRC_Q)), '')
    check('r21_unknown_key_fails', bool(v.spot_requirement_problems(spots_with(day={'zone': 'f', 'requires': {'day_min': 14, 'season': 'vinter'}}), QUESTS, SRC_Q)), '')
    check('r21_empty_quest_list_fails', bool(v.spot_requirement_problems(spots_with(cat={'zone': 'd', 'requires': {'quests': []}}), QUESTS, {})), '')
    check('r21_source_names_other_quest_fails', bool(v.spot_requirement_problems(SPOTS, QUESTS, {'cat': 'moonstone_crown'})), 'the item source and the spot must name the same quest')
    check('r21_source_quest_without_requires_fails', bool(v.spot_requirement_problems(SPOTS, QUESTS, {'cat': 'lost_cat', 'plain': 'lost_cat'})), '')
    check('r21_requires_not_a_table_fails', bool(v.spot_requirement_problems(spots_with(day={'zone': 'f', 'requires': 14}), QUESTS, SRC_Q)) and bool(v.spot_requirement_problems(spots_with(day={'zone': 'f', 'requires': {}}), QUESTS, SRC_Q)), '')


NPCS = {'fairy_king', 'fairy_wizard'}
ITEMS = {'circlet_moon_crown', 'fairy_dust'}


def quest(**kw):
    q = {'rewards': {'gold': 100, 'items': {'circlet_moon_crown': 1}, 'friendship': {'fairy_king': 2}}, 'objectives': [{'id': 'a', 'npc': 'fairy_king'}], 'meta': {'giver': 'fairy_king'}}
    for k, val in kw.items():
        grp, key = k.split('__')
        q[grp][key] = val
    return {'q': q}


def q5_tests() -> None:
    check('q5_valid_passes', v.quest_reference_problems(quest(), NPCS, ITEMS) == [], str(v.quest_reference_problems(quest(), NPCS, ITEMS)))
    check('q5_unknown_friendship_npc_fails', bool(v.quest_reference_problems(quest(rewards__friendship={'fairy_kingx': 2}), NPCS, ITEMS)), 'paid to nobody')
    check('q5_hearts_out_of_range_fails', bool(v.quest_reference_problems(quest(rewards__friendship={'fairy_king': 0}), NPCS, ITEMS)) and bool(v.quest_reference_problems(quest(rewards__friendship={'fairy_king': 11}), NPCS, ITEMS))
          and bool(v.quest_reference_problems(quest(rewards__friendship={'fairy_king': 'two'}), NPCS, ITEMS)), '')
    check('q5_unknown_giver_fails', bool(v.quest_reference_problems(quest(meta__giver='fairy_kingx'), NPCS, ITEMS)), '')
    check('q5_unknown_objective_npc_fails', bool(v.quest_reference_problems({'q': {**quest()['q'], 'objectives': [{'id': 'a', 'npc': 'nobody'}]}}, NPCS, ITEMS)), '')
    check('q5_unknown_reward_item_fails', bool(v.quest_reference_problems(quest(rewards__items={'circlet_moon_crownx': 1}), NPCS, ITEMS)) and bool(v.quest_reference_problems(quest(rewards__items={'fairy_dust': 0}), NPCS, ITEMS)), '')
    check('q5_negative_gold_fails', bool(v.quest_reference_problems(quest(rewards__gold=-5), NPCS, ITEMS)), '')


def c19_tests() -> None:
    fur = {'bed': {'rarity': 'normal', 'max_stack': 9, 'decor': 2}, 'moon': {'rarity': 'legendary', 'max_stack': 1, 'decor': 40}}
    mat = {'nails': {'category': 'building_material', 'max_stack': 99}, 'bp': {'category': 'blueprint', 'max_stack': 1}}
    check('c19_valid_passes', v.stack_problems(fur, mat) == [], str(v.stack_problems(fur, mat)))
    check('c19_bed_99_fails', bool(v.stack_problems({**fur, 'bed': {**fur['bed'], 'max_stack': 99}}, mat)), '')
    check('c19_bed_8_fails', bool(v.stack_problems({**fur, 'bed': {**fur['bed'], 'max_stack': 8}}, mat)), '')
    check('c19_keepsake_9_fails', bool(v.stack_problems({**fur, 'moon': {**fur['moon'], 'max_stack': 9}}, mat)), '')
    check('c19_missing_or_text_max_stack_fails', bool(v.stack_problems({'bed': {'rarity': 'normal'}}, {})) and bool(v.stack_problems({'bed': {'rarity': 'normal', 'max_stack': '9'}}, {})), '')
    check('c19_blueprint_not_1_fails', bool(v.stack_problems(fur, {'bp': {'category': 'blueprint', 'max_stack': 2}})), '')
    check('c19_material_zero_or_100_fails', bool(v.stack_problems(fur, {'n': {'category': 'building_material', 'max_stack': 0}})) and bool(v.stack_problems(fur, {'n': {'category': 'building_material', 'max_stack': 100}})), '')
    check('c20_valid_passes', v.decor_problems(fur) == [], '')
    check('c20_decor_zero_fails', bool(v.decor_problems({**fur, 'moon': {**fur['moon'], 'decor': 0}})), 'a legendary piece with decor 0')
    check('c20_decor_negative_or_text_fails', bool(v.decor_problems({'a': {'decor': -1}})) and bool(v.decor_problems({'a': {'decor': '3'}})) and bool(v.decor_problems({'a': {}})), '')
    check('c20_decor_float_whole_passes', v.decor_problems({'a': {'decor': 3.0}}) == [], '')


def sh2_tests() -> None:
    def shops(**kw):
        row = {'stock': 3, 'restock': 2}
        slot = {'id': 'x', 'period': 1, 'price_mult': 1.0, 'season_boost': 2.0}
        row.update(kw.get('row', {}))
        slot.update(kw.get('slot', {}))
        return {'s': {'stock': {'bed': row}, 'rotation': [slot]}}
    check('sh2_valid_passes', v.shop_stock_problems(shops()) == [] and v.shop_stock_problems({'flea': {'stock': [], 'rotation': []}}) == [], str(v.shop_stock_problems(shops())))
    check('sh2_negative_stock_fails', bool(v.shop_stock_problems(shops(row={'stock': -3}))), '')
    check('sh2_zero_stock_fails', bool(v.shop_stock_problems(shops(row={'stock': 0, 'restock': 0}))), '')
    check('sh2_restock_above_stock_fails', bool(v.shop_stock_problems(shops(row={'restock': 4}))), '')
    check('sh2_restock_text_or_negative_fails', bool(v.shop_stock_problems(shops(row={'restock': 'two'}))) and bool(v.shop_stock_problems(shops(row={'restock': -1}))), '')
    check('sh2_period_zero_fails', bool(v.shop_stock_problems(shops(slot={'period': 0}))), '')
    check('sh2_price_mult_zero_fails', bool(v.shop_stock_problems(shops(slot={'price_mult': 0}))), '')
    check('sh2_season_boost_below_one_fails', bool(v.shop_stock_problems(shops(slot={'season_boost': 0.5}))), '')
    check('sh2_negative_price_fails', bool(v.shop_stock_problems(shops(row={'price': -1}))), '')


def r7d_tests() -> None:
    slots = {'hat': {'item_slot': 'hat', 'z': 40, 'name_key': 'A'}, 'circlet': {'item_slot': 'jewellery', 'subslot': 'circlet', 'z': 41, 'name_key': 'B'}, 'shirt': {'item_slot': 'shirt', 'z': 20, 'name_key': 'C'}}
    check('r7d_valid_passes', v.equip_slot_problems(slots) == [], str(v.equip_slot_problems(slots)))
    check('r7d_same_z_fails', bool(v.equip_slot_problems({**slots, 'circlet': {**slots['circlet'], 'z': 40}})), 'the circlet on the z of the hat')
    check('r7d_z_not_a_number_fails', bool(v.equip_slot_problems({**slots, 'circlet': {**slots['circlet'], 'z': 'top'}})), '')
    check('r7d_same_item_slot_and_subslot_fails', bool(v.equip_slot_problems({**slots, 'cap': {'item_slot': 'hat', 'z': 42, 'name_key': 'D'}})), '')
    check('r7d_missing_name_key_fails', bool(v.equip_slot_problems({**slots, 'shirt': {'item_slot': 'shirt', 'z': 20}})), '')


GOOD_DLG = ('speaker = "fairy_furnisher"\nlines = { { id = "greet", text_key = "DLG_FURNISHER_GREET", voice_key = "voice/fairy_furnisher/greet" } }\n'
            'choices = { { id = "open_shop", text_key = "DLG_CHOICE_X", action = "open_shop" } }\n')


def k10_tests() -> None:
    check('k10_valid_passes', v.voice_key_problems({'f.lua': GOOD_DLG}) == [], str(v.voice_key_problems({'f.lua': GOOD_DLG})))
    check('k10_wrong_line_id_in_key_fails', bool(v.voice_key_problems({'f.lua': GOOD_DLG.replace('voice/fairy_furnisher/greet', 'voice/fairy_furnisher/gret')})), '')
    check('k10_spoken_line_without_voice_key_fails', bool(v.voice_key_problems({'f.lua': GOOD_DLG.replace(', voice_key = "voice/fairy_furnisher/greet"', '')})), '')
    check('k10_other_speakers_key_fails', bool(v.voice_key_problems({'f.lua': GOOD_DLG.replace('voice/fairy_furnisher/greet', 'voice/fairy_tailor/greet')})), '')
    check('k10_line_id_not_matching_text_key_fails', bool(v.voice_key_problems({'f.lua': GOOD_DLG.replace('DLG_FURNISHER_GREET', 'DLG_FURNISHER_HELLO')})), '')
    two = GOOD_DLG + 'lines = { { id = "greet", text_key = "DLG_FURNISHER_GREET2", voice_key = "voice/fairy_furnisher/greet" } }\n'
    check('k10_one_voice_key_for_two_texts_fails', bool(v.voice_key_problems({'f.lua': two})), '')
    check('k10_buttons_need_no_voice_key', 'DLG_CHOICE_X' in GOOD_DLG and v.voice_key_problems({'f.lua': GOOD_DLG}) == [], '')


def k9_tests() -> None:
    cre = {'bat': {'name_key': 'ENEMY_BAT'}, 'owl': {'name_key': 'ENEMY_UGLEOJE'}}
    owner = lambda k: 'forest.csv' if k.startswith('ENEMY_') else ('core.csv' if k.startswith('GAME_') else None)  # noqa: E731
    problems, pending = v.creature_key_problems(cre, lambda k: True, owner, lambda f: True)
    check('k9_defined_keys_pass', problems == [] and pending == [], str((problems, pending)))
    problems, pending = v.creature_key_problems(cre, lambda k: False, owner, lambda f: False)
    check('k9_owner_not_landed_is_pending_not_a_failure', problems == [] and sorted(k for _, k, _ in pending) == ['ENEMY_BAT', 'ENEMY_UGLEOJE'] and {f for _, _, f in pending} == {'forest.csv'}, str((problems, pending)))
    problems, pending = v.creature_key_problems(cre, lambda k: False, owner, lambda f: True)
    check('k9_owner_landed_without_the_row_fails', len(problems) == 2 and pending == [], str(problems))
    problems, _ = v.creature_key_problems({'bat': {'name_key': 'ENEMYBAT'}}, lambda k: False, owner, lambda f: False)
    check('k9_key_nobody_owns_fails', len(problems) == 1, str(problems))
    check('k9_not_an_upper_case_key_fails', bool(v.creature_key_problems({'bat': {'name_key': 'enemy bat'}}, lambda k: True, owner, lambda f: True)[0]) and bool(v.creature_key_problems({'bat': {}}, lambda k: True, owner, lambda f: True)[0]), '')
    problems, pending = v.creature_key_problems(cre, lambda k: k == 'ENEMY_BAT', owner, lambda f: False)
    check('k9_one_defined_one_pending', problems == [] and [k for _, k, _ in pending] == ['ENEMY_UGLEOJE'], str((problems, pending)))
    check('k9_empty_table_passes', v.creature_key_problems({}, lambda k: False, owner, lambda f: False) == ([], []), '')


def d6_tests() -> None:
    check('d6_clean_files_pass', v.text_literal_problems({'a.lua': 'id = "bogtraeet"\nkey = "OBJ_BOGTRAEET_RETURN_TO_ZEPHYR"\nvoice = "voice/fairy_builder/t02_done"\ncolor = "6FD6C4"\n'}) == [], '')
    check('d6_danish_description_fails', v.text_literal_problems({'q.lua': '  description = "Sæt 6 unikke eller legendariske møbler op i Slottet",\n'}) == [('q.lua', 'Sæt 6 unikke eller legendariske møbler op i Slottet')], '')
    check('d6_english_literal_fails', bool(v.text_literal_problems({'q.lua': 'title = "Find the moon stone"\n'})), '')
    check('d6_single_quoted_literal_fails', bool(v.text_literal_problems({'q.lua': "title = 'Find the moon stone'\n"})), '')
    check('d6_comment_is_skipped', v.text_literal_problems({'q.lua': '-- "Find the moon stone" is in the CSV\nx = 1 -- a "quoted phrase here" in a comment\n'}) == [], '')
    check('d6_double_dash_inside_a_string_is_not_a_comment', bool(v.text_literal_problems({'q.lua': 'x = "see -- the moon stone"\n'})), '')
    check('d6_short_phrases_without_letters_pass', v.text_literal_problems({'q.lua': 'x = "1 2"\ny = "a b"\n'}) == [], 'a space and three letters make a text')


def main() -> int:
    with tempfile.TemporaryDirectory(prefix='rules_selftest.') as d:
        n1_tests(Path(d))
    sh1_tests()
    s10_tests()
    mm1_tests()
    r21_tests()
    q5_tests()
    c19_tests()
    sh2_tests()
    r7d_tests()
    k10_tests()
    k9_tests()
    d6_tests()
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
