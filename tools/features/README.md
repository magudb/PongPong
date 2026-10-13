# tools/features - the toolbox of the feature content (package F1)

The feature content (home tiers, furniture, clothing, materials, recipes, shops, loot, sets, four quests, builder dialogues, 906 CSV rows) is HAND-OWNED since the one-time copy of the reviewed pack:
generation is retired (review RV-P6), nothing regenerates the Lua or the CSVs.  These tools check, port and measure that content.  Docs: `docs/features/` (`DELTAS.md` what differs from the pack,
`STAGES.md` how the validator reads a half-built repo, `BALANCE.md` the pacing model, `SCHEMA.md` the data schema, `evidence/` the review pictures).

| tool | what it does | who runs it |
|---|---|---|
| `validate/run_validate.sh --stage f1\|p13\|p14\|full` | the staged content validator: 102 rules against a complete tree (real Lua 5.4 + the project's LuaRuntime in Godot + A1's art tables); report in `tools/features/reports/` | F1 (f1), P13 (p13), P14 (p14), F10 (full) as the content gate |
| `validate/mutation_test.py [--jobs N]` | applies one deliberate defect at a time to a COPY and expects the named rule to fail (48 mutants incl. the 26 of the review; the crash guard is not a detection); needs a green control run first | F1, whenever a rule changes |
| `validate/rules_selftest.py` | the rule helpers of N1 / SH1 / S10 / MM1 / R21 / Q5 / C19 / C20 / SH2 / R7d / K10 / K9 / D6 on synthetic defects (104 PASS/FAIL ids, no Godot, about a second); `tests/sections/content_features.gd` runs it | harness, F1 whenever a rule helper changes |
| `validate/stage_selftest.py` | three green stages on simulated repos + three negative controls (P13 not landed, P14 forgot the offer, P14 absent) | F1, whenever stage.manifest or the stage rules change |
| `add_autoload.py [NAME ...]` | appends the feature autoload lines to `project.godot` AFTER AnimalHusbandry: only when the script exists and the entry is absent, idempotent, flock + atomic rename, refuses any other edit (exception E1) | F2 `HomeManager`, F3 `FurnitureManager`, F5 `WardrobeManager`, F4 `LootService`, F9 `CollectionLog`: as the LAST task of each |
| `test_add_autoload.py` | self-test of the tool on COPIES (22 checks incl. 10 parallel runs, a name given twice, a missing or unreadable --project); `tests/sections/content_features.gd` runs it | harness |
| `merge_pending_rewards.py [--check]` | copies the reviewed `rewards = {...}` block of `lost_cat`, `fix_roof`, `birthday_cake`, `math_wizard_quiz` from `data/features/pending/lua/quests` into the quests P13 rewrote; idempotent | P13 after its rewrite (its gate runs `--check` and `--stage p13`) |
| `rename_town.py --old NAME [--apply]` | renames the fairy town in text files (variants, genitive, ids, keys; .map / .svg / scenes / resources included); the old name is an ARGUMENT, never written in the repo; refuses an empty, blank or shorter-than-3 name | whoever renames a town again |
| `test_rename_town.py` | self-test of the rename tool on temp copies (8 checks: the guards, the variants, .map / .svg / .tscn / .tres, what must stay untouched); `tests/sections/content_features.gd` runs it | harness |
| `retier_wardrobe_sets.py [--apply]` | re-tiers wardrobe-set bonus rows that cannot be reached by wearing (rule R15) from the validator's dump | F1 after content edits |
| `make_content_contract.py` | regenerates the snapshot that A1 / A2 test their art against (`tools/art/features/home/specs/content_contract.json`, A1's file: hand the output to A1; rule R19 proves it equals the Lua) | F1 / A1 |
| `sim/run_balance.sh [--quests repo\|stage]` | the pacing model against the repo as it is now; output in `tools/features/reports/` | F1 when P12 / P13 landed; not a gate |

`src/common.py`, `src/src_clothing.py`: the constants and design tables the validator imports (areas, NPC / quest / shop universes, perk caps, the garment designs of the art).  `colour.py`: CIEDE2000 and contrast.
`validate/art_snapshot.json`, `validate/font_coverage.json`: read-only fallbacks of the live art tables / fonts (`validate.py --refresh-snapshot` rewrites them).
`validate/stage.manifest` + `stage.py`: which repo files form the stage tree.  `validate/validate_godot.gd`: the Godot side (a consumer of LuaRuntime, QuestManager, EconomyManager, GameManager: see STAGES.md).

Gitignored: `tools/features/_stage/` (stage trees and the project copy), `tools/features/reports/` (dumps, reports).  Python: `tools/art/.venv/bin/python` (numpy + fontTools); the validator also needs `lua5.4` / `luac5.4` (`brew install lua`).

## Tests of the content inside the playtest harness

`tests/run_playtest.sh --only=content_features` (section `tests/sections/content_features.gd`, helpers `tests/lib/features/`):

* `fresh.gd` `Fresh.new_game(t)`: the harness's own new-game helper + QuestManager reset + `reset()` of every feature manager that exists + seeding.  Every section from wave 3 on starts from it.
* `grant.gd` `Grant.requirements(n)`: gives everything tier `n` asks for (gold, materials, quests - the dialogue-offered ones THROUGH the dialogue -, hearts, hygge) only through the public APIs.
* `auto_furnish.gd` `AutoFurnish.fill(target)`: fills a room through `EconomyManager.add_item` -> the furniture store -> `place_from_stock` until a hygge target is met; it reads the score through the BINDING accessor `FurnitureManager.hygge_score()` (PLAN_FEATURES.md section 3 task 4, RF16) and nothing else.
* `room_model.gd` `FeatureRoom`, `fake_furniture.gd` `FakeFurnitureManager`: the data-level placement rules (room cells of A1, footprint / layer / interaction of the item defs, door and path rules) and a stand-in furniture store, so these helpers can be proven before F3's real grid exists (F3 replaces the stand-in via `Svc.override`, not the helpers).
* `content_validator.gd` `ContentValidator`: the Lua-level rules against what the game loaded (items, loc keys, keepsake sources both ways, shops, recipes loop, sets, tiers, starter kit, hearts) and, as static functions on plain data that the section also runs on broken copies,
  `shop_schedule_problems` (open_weekdays), `dialogue_shop_problems` (the shop buttons of the three builder dialogues), `map_marker_problems` (map_markers.json == the loot tables), and (fix round 2) `spot_requirement_problems`, `quest_reference_problems`, `stack_problems`, `shop_stock_problems`, `equip_slot_problems`, `voice_key_problems`, `text_literal_problems`, `creature_key_problems`.
