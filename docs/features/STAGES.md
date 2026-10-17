# STAGES - how the content validator reads a repo that is still being built

`tools/features/validate/run_validate.sh --stage f1|p13|p14|full` checks the whole feature content (102 rules) against a COMPLETE tree, in every wave, without skipping a rule.
The content lives in files that finish in different waves, so the validator does not read the repo directly: it assembles a **stage tree** and the files that a LATER package
has not delivered yet are replaced by **pending references** that F1 keeps. This file explains the design (review RV-P2) and how to use it.

## The problem it solves

F1's wave-3 gate has to prove the content, but the content refers to files that other packages finish later: the four legacy quests (`lost_cat`, `fix_roof`, `birthday_cake`,
`math_wizard_quiz`: P13, wave 4) must carry the reviewed rewards, and the dialogues of Oak, Zephyr and the Fairy King (P14, wave 5) must offer the four gating quests.
The first version of the validator read `lua/quests` and `lua/dialogue` directly: on a half-built repo it reported 7 passed, S8/S9/S12 failed and then crashed.
RV-P2 made the validator staged: the rules never change, only the origin of those seven files does.

| stage | the four legacy quests come from | the three dialogues come from | who runs it as a gate | extra rule |
|---|---|---|---|---|
| `f1` | `data/features/pending/lua/quests/` (reviewed rewards) | `data/features/pending/lua/dialogue/` (with the `quest_accept` branches) | F1 (wave 3) | Q1: the pending quests differ from the legacy baseline only in rewards |
| `p13` | the REAL `lua/quests/` (P13 merged the rewards) | pending | P13 (wave 4) | **Q3**: the repo rewards equal the reviewed pending rewards |
| `p14` | real | the REAL `lua/dialogue/` | P14 (wave 5) | **S13** runs against P14's files |
| `full` | real | real | F10 (wave 7) | same as p14 |

A stage never degrades: when a file the stage needs is missing the runner stops with `stage p14 needs lua/dialogue/fairy_king.lua` (exit 5).

## What the stage tree contains

`tools/features/validate/stage.manifest` (read by `stage.py`) maps the scattered repo files into the shape of the reviewed pack:

```
lua/items/{furniture,clothing,building_materials}.lua, lua/recipes/{furniture,materials}.lua, lua/shops/home_shops.lua, lua/data/**/*.lua (incl. starter_kit.lua)
lua/quests/{bogtraeet,moonstone_crown,snurresvampen,slotsdroemmen}.lua, lua/dialogue/{fairy_builder,fairy_furnisher,fairy_tailor}.lua      (F1's own files)
lua/config/rarity.lua                                                      (P10's file: the colours and caps the rules R17 / C17b read)
localization/{furniture,wardrobe,materials,home,finds,features_ui,features_quests,dialogue_builder}.csv + .import
data/features/** -> data/**                                                (map_markers.json, used_keys.txt, pending/lua/**, legacy_base/lua/**)
tools/art/features/home/specs/{furniture_art_spec,content_contract}.json -> data/   (A1's specs: rule C10b and R19)
tools/art/features/wardrobe/specs/*.json -> data/                          (A2's, wave 4; until then data/features/pending/art/*.json)
tools/loc/key_owners.json -> data/loc_key_owners.json                      (P03's key-level ownership table: rule K8)
staged: lua/quests/{lost_cat,fix_roof,birthday_cake,math_wizard_quiz}.lua  (real from p13, pending before)
staged: lua/dialogue/{guard_oak,fairy_wizard,fairy_king}.lua               (real from p14, pending before)
```

The assembled tree is `tools/features/_stage/<stage>/tree` (gitignored); `_stage.json` inside it names the origin of every file (`own`, `repo`, `pending`, `real`).

## What the runner does (in this order)

1. **stage.py** assembles the tree (`--src DIR` takes the files of F1 and of the repo from another repo-shaped tree first: the mutation test uses it).
2. A **project copy** `tools/features/_stage/project` (the repo without `tools/`, `docs/`, `tests/`, plus the stage tree on top; Godot NEVER opens the repo directory) is synced and imported when scripts changed.
3. **real Lua 5.4** (`luac5.4 -p`, `lua5.4 ser.lua`) evaluates every stage file, the repo's Lua and the pending references: the reference data for rule S5 (the project interpreter must read the same tables).
4. **validate_godot.gd** (Godot headless, throwaway HOME) loads the stage through the project's own LuaRuntime and dumps what it understood: item defs, config paths, the 29 builder flag states, the 13 offer flag states, accept + complete of all 8 quests through QuestManager and the Lua hooks.
5. **validate.py** runs all rules and writes `tools/features/reports/validation_report_<stage>.txt`; exit 0 only when nothing fails (warnings are listed: rule K9 lists the loot creature name keys that wait for their owner CSV, `forest.csv` of P19, until it lands).

Needs `lua5.4` and `luac5.4` (`brew install lua`), `rsync`, the art venv python (`tools/art/setup_env.sh`: numpy for the footprint probes of A1's template functions, fontTools), Godot 4.7.2.
Run it from an APFS clone (`impl/tools/clone_run.sh`), as every Godot command of the build.

```
tools/features/validate/run_validate.sh --stage f1            # F1's gate: 102 rules, 0 failed, 1 warning (K9: three ENEMY_ keys wait for forest.csv of P19)
tools/features/validate/run_validate.sh --stage p13           # P13's gate (needs the merged rewards: python3 tools/features/merge_pending_rewards.py)
tools/features/validate/run_validate.sh --stage p14           # P14's gate
python3 tools/features/validate/stage_selftest.py             # 3 green stages on simulated repos + 3 negative controls (about 8 minutes)
python3 tools/features/validate/mutation_test.py --jobs 3     # one deliberate defect per run: every one must be caught (48 mutants; default --work under tools/features/_stage, the very path N1 once skipped)
python3 -I tools/features/validate/rules_selftest.py          # no Godot, about a second: the helpers of N1 / SH1 / S10 / MM1 / R21 / Q5 / C19 / C20 / SH2 / R7d / K10 / K9 / D6 on synthetic defects (104 checks)
```

## What the rules are (ids as printed)

S1-S13 syntax, real Lua vs the project interpreter, runtime registration, quests end to end, builder dialogue, offers; I1-I4 ids; L1-L8 localization files, lint dialect, config keys;
C1-C20 catalogue shape (C19 max_stack, C20 decor), art contract (templates, palettes, footprints by A1's real template functions), prices, sets, perks, acquisition; R1-R21 loot, recipes, shops (SH1 opening days, SH2 shelf numbers), wardrobe slots (R7d), spot requirements (R21), home tiers, hygge, keepsake sources both ways,
R15 wardrobe set bonuses reachable, R16 stub copy promises nothing, R17 rarity UI colours, R18 duplicates policy, R19 content contract equals the Lua, R20 rarity visible in the palette;
K1-K10 loc keys referenced / owned / used by code / creature names (K9) / voice keys (K10); D1-D6 Danish copy and glyphs, no text literal in Lua (D6); Q1-Q5 quests (Q5 npc / item references); **SK1, SK2 starter kit; FG1 friend gates; N1 the old town name is gone from the whole repo** (added by F1).

Fix round after review F1 r1 (the rules are unchanged in number except the two new ones):

* **N1** judges the build-output filter (`_stage`, `reports`, `__pycache__`) on the path RELATIVE to the scan root.  The stage tree lives in `tools/features/_stage/<stage>/tree`, and the first version tested the absolute path:
  every Lua file and CSV of the tree was skipped, so the rule passed on a tree full of the old name and `mutation_test.py` (default `--work`) missed its own N1 mutant.  The rule now also fails when it did not VISIT every Lua file and CSV of the stage tree.
* **S10** (extended): in every flag state the project interpreter evaluated (29 builder states + furnisher + tailor) there is an `open_shop` choice, it names a shop that exists and the speaker keeps it; every `shop_id` literal of the three
  Lua files is a shop and each `action = "open_shop"` has one.  (Before it only looked at the first action of the two shopkeepers.)
* **SH1** (new): `open_weekdays` is a non-empty list of distinct weekday indices 0..6 (0 = Monday); only the flea market has any and they are exactly `{5, 6}`.  `{5, 7}` used to pass and silently closed the market on Sunday.
* **MM1** (new): `data/features/map_markers.json` equals `lua/data/loot_tables.lua` per area (chests / digging spots per container id, creatures per visit, unique spots == `loot.spots` of the zone, boss placement).
  Since generation was retired nothing else kept the marker list that P11 / P19 build maps from in step with the loot tables.
* **R7** (hardened): a stock / pool id that is not an item, or an item source naming an unknown shop, is a clean R7 failure; the later rules (R7b, R8, K4) skip unknown ids instead of crashing.
* **mutation test**: the crash guard `X validator crashed` is no longer a detection (a defect that only crashes the validator is reported MISSED: no rule names it), and the rule is matched as a whole token (`S1` no longer matches `S10`).
* **rules_selftest.py** runs the helpers of N1 / SH1 / S10 / MM1 on small synthetic inputs, among them a stage tree below a `_stage` path with the old name inside (it must be found); `tests/sections/content_features.gd`
  runs it (`rules_selftest_*`) and repeats SH1 / S10 / MM1 against the real runtime data with negative controls (`shop_open_weekdays_valid`, `dialogue_shop_buttons_open_real_shops`, `map_markers_equal_loot_tables`).

## The managers the Godot driver talks to

`validate_godot.gd` is a consumer of other packages' public API; a change there must be mirrored in that file (it lives in `tools/features/validate/`, F1's):

* LuaRuntime: `reload_scripts`, `parse_lua_source`, `get_config`, `get_item_def`, `get_all_script_ids`, `get_dialogue`, and (private, for the `is_available` hooks) `_invoke_function`
* QuestManager: `get_quest_def`, `accept_quest`, `complete_quest`, `is_active`, `is_completed` (+ `active_quests` / `completed_quests` to forget a quest between runs)
* EconomyManager: `gold` (or `get_gold`), `count_item` (any store), `get_inventory_dict` (backpack)
* GameManager: `world_flags`, `set_flag`, `get_flag`

Rule S12 (accept + complete all 8 quests, exact gold and items, flags flip) also relies on the HOOK FLAGS that the quest Lua sets: `lost_cat_active` (cleared on completion), `birthday_cake_active` / `maja_birthday_done`,
`math_quiz_active` / `math_quiz_done`, `maja_roof_fixed` (fix_roof), and `<quest>_active` / `<quest>_done` for the four feature quests.  When P13 rewrites the four legacy quests it keeps these flags (the reference quests and the dialogue
offers read them) or changes the two tables `flag_names` / `done_names` in `validate_godot.gd` together with the quest: a rule that fails on a renamed flag is the correct behaviour, the fix belongs in one of the two files.

Parallel runs in one tree (the mutation test does it) need distinct `--work` and `--reports` directories: the default ones are shared.

## Snapshots (read-only in a normal run)

`validate/art_snapshot.json` (template / palette / garment tables) and `validate/font_coverage.json` (glyph ranges of Alegreya Sans and Caprasimo) are the fallback when the live source is not there:
the home tables are live (`tools/art/features/home`), the wardrobe garment table is the snapshot until A2 lands `tools/art/features/wardrobe`, the fonts are live once P07 put them in `assets/fonts`.
`validate.py --refresh-snapshot` rewrites them from the live sources; that is a human decision, never part of a gate.

## When a stage goes away

The pending references are a deliberate duplication. When P13 and P14 have landed and their gates run `p13` / `p14` green, `data/features/pending/lua/**` is only read by Q1 / Q3; delete the pending dialogue files
and the wardrobe art copies with the owner's blessing once `full` has been green for a wave.  `legacy_base` stays for Q1.

Fix round 2 after review F1 r2 (nine more rules, same stage design): **C19** max_stack, **C20** decor >= 1, **R21** `loot.spots.*.requires`, **SH2** shop numbers, **R7d** equipment slot z, **Q5** quest npc / item references,
**K9** loot creature name keys (a key whose owner CSV has not landed is a WARN row naming the rows, not a failure; once the owner CSV exists the row must be there), **K10** voice keys of the three dialogues, **D6** no text literal
in F1's Lua (judged on files with origin `own` only: P13's / P14's real rewrites and the pending references are not F1's). **N1** now scans every text file of the repo (the suffixes of `rename_town.py`: .map, .svg, .tscn, .tres included),
pruning `.git`, `.godot`, virtual envs, scratch folders and `tools/features/reports`; the user's "Style Guide" export is skipped.

### Dungeon inputs

All stages now require the three dungeon item files, forge recipes, smithy stock, dungeon item CSV and the four layout/combat/loot/boss config files listed in `stage.manifest`. They are real live inputs, including in the early historical stage; no pending dungeon snapshot is substituted. S5 compares their evaluated tables against LuaRuntime, and S6 checks the exact declared item count. The full stage has 125 passing rules, including W1-W5/G1-G3/M1-M2/K1/DB1-DB5 and expanded acquisition checks. P1 remains a separate mandatory model gate. Run mutation tests with `--jobs 1` to keep Godot processes sequential.
