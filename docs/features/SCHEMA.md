# SCHEMA - home upgrades, furniture and clothing (Trætoppen)

> **REPO NOTE (package F1, wave 3).** This is the SCHEMA.md of the reviewed content pack, copied unchanged below this note.  The pack was a drop-in directory; in the repo the files are scattered
> over the packages' folders and **generation is retired** (review RV-P6: the Lua and CSV files are hand-owned, nothing regenerates them, there is no rule "regeneration changes no byte").
> Read the paths of sections 1 and 8 with this table:
>
> | in the pack | in the repo |
> |---|---|
> | `lua/items/{furniture,clothing,building_materials}.lua`, `lua/recipes/{furniture,materials}.lua`, `lua/shops/home_shops.lua`, `lua/data/*.lua` (+ `starter_kit.lua`, CD3) | same paths |
> | `lua/quests/{bogtraeet,moonstone_crown,snurresvampen,slotsdroemmen}.lua`, `lua/dialogue/{fairy_builder,fairy_furnisher,fairy_tailor}.lua` | same paths (F1 owns them since wave 3) |
> | `lua/quests/{lost_cat,fix_roof,birthday_cake,math_wizard_quiz}.lua`, `lua/dialogue/{guard_oak,fairy_wizard,fairy_king}.lua` | PENDING REFERENCES in `data/features/pending/lua/**` until P13 / P14 merge them (`tools/features/merge_pending_rewards.py`, validator rules Q3 / S13) |
> | `lua/config/rarity.lua` | same path, owned by P10 |
> | `localization/*.csv` + `.csv.import` | same paths (8 files) |
> | `data/map_markers.json`, `data/used_keys.txt` | `data/features/` |
> | `data/furniture_art_spec.json`, `data/content_contract.json` | `tools/art/features/home/specs/` (A1) |
> | `data/wardrobe_art_spec.json`, `data/wardrobe_design_requests.json` | `tools/art/features/wardrobe/specs/` (A2, wave 4); until then `data/features/pending/art/` |
> | `data/loc_key_owners.json` | `tools/loc/key_owners.json` (P03) |
> | `tools/validate/` (`run_validate.sh`, `mutation_test.py`), `tools/sim/` | `tools/features/validate/`, `tools/features/sim/` (staged validator: `docs/features/STAGES.md`) |
> | `tools/src/` (generator) | only the constants the validator imports: `tools/features/src/{common,src_clothing}.py` |
> | `reports/` | `tools/features/reports/` (gitignored) |
>
> **Statements below that describe the pack, not the repo** (the text stays as reviewed; this note corrects them):
>
> * Section 8 (commands AND numbers): `tools/validate/run_validate.sh # generate + copy the repo ...`, `tools/validate/mutation_test.py`, `tools/sim/balance_sim.py`, "77 passed", "17 of 17 caught" are the first pack's. In the repo the commands are
>   `tools/features/validate/run_validate.sh --stage f1` (no generation step: it assembles the stage tree and checks it), `python3 tools/features/validate/mutation_test.py`, `python3 -I tools/features/validate/rules_selftest.py`
>   (no Godot: the rule helpers seen failing), `tools/features/sim/run_balance.sh`; the repo's numbers are 102 rules and 48 mutants (`docs/features/STAGES.md`, `docs/features/DELTAS.md`).
> * "`tools/` regenerates and validates everything" (opening paragraph) and the `tools/src/` row of section 1: generation is retired; `tools/features/src/` only holds the constants the validator imports.
> * "Town name" paragraph (corrected in place): the town is Hyggebyen everywhere, the rename step is done; `python3 -I tools/features/rename_town.py --old NAME` is the generic tool and rule N1 proves that no text file of the repository holds the old name.
> * Row counts: the pack said "879 rows"; the repo has **906** rows in the 8 files after CD17 / CD18 (the `localization` row of the section 1 table is corrected in place; `content_features.loc_keys_da_en` pins 906).

Drop-in content for the repo: copy `lua/` and `localization/` over the project root. Nothing else is needed at runtime; `data/` feeds the art
pipeline, `tools/` regenerates and validates everything. All Lua is the dialect of `scripts/autoload/lua_runtime.gd` (literal tables, double-quoted
strings without escapes, no nil/functions in data) and is also valid Lua 5.4: `tools/validate` proves that both readers return identical data.

Town name: the fairy town is **Hyggebyen** (genitive Hyggebyens, area / map / asset id `hyggebyen`) in every file of the repository.  The rename step is done; the generic tool is
`python3 -I tools/features/rename_town.py --old NAME [--apply] ROOT ...` (it refuses an empty or blank NAME) and validator rule N1 reads the WHOLE repo and proves that the old name is left in no text file.

## 1. Files

| File | kind | Content |
|---|---|---|
| `lua/items/furniture.lua` | items | 130 furniture items (45 normal / 33 uncommon / 24 rare / 17 unique / 11 legendary), 22 art templates |
| `lua/items/clothing.lua` | items | 96 garments + jewellery (18 hats, 15 shirts, 14 pants, 14 dresses, 15 shoes, 20 jewellery; 33/24/18/13/8) |
| `lua/items/building_materials.lua` | items | 28 materials/gems + 4 blueprints (home upgrades + recipes) |
| `lua/recipes/furniture.lua`, `materials.lua` | recipes | 95 Værksted recipes for furniture, 11 processing recipes |
| `lua/shops/home_shops.lua` | shops | `furniture_shop`, `tailor_shop`, `builder_yard`, `flea_market` (plan location `lua/shops/`, not `lua/data/shops`) |
| `lua/data/home_tiers.lua` | config (`home`) | 10 tiers, hygge levels, unlock/room ids, builder dialogue keys |
| `lua/data/loot_tables.lua` | config (`loot`) | containers, creatures, per-area pools, fixed spots, gifts, tier gifts, set rewards, boss |
| `lua/data/sets.lua` | config (`furniture_sets`, `wardrobe_sets`) | 10 + 7 themed sets with bonuses |
| `lua/data/wardrobe_rules.lua` | config (`wardrobe`) | 9 equipment slots, exclusions |
| `lua/config/rarity.lua` | config (`rarity_tiers`, `perk_caps`) | the five ranks, UI colours, price bases, caps |
| `lua/dialogue/fairy_builder.lua`, `fairy_furnisher.lua`, `fairy_tailor.lua` | dialogue | builder (37 lines, 28 branches), two shopkeepers |
| `lua/quests/` | quest | `lost_cat`, `fix_roof`, `birthday_cake`, `math_wizard_quiz` = repo files with only `rewards` changed (lost_cat also `meta` per PLAN 3.12 and the one objective text that names Pippin); `bogtraeet`, `moonstone_crown`, `snurresvampen`, `slotsdroemmen` new |
| `localization/*.csv` | `keys,da,en` | 906 rows in 8 files + `.csv.import` (`importer="keep"`): `furniture`, `wardrobe`, `materials`, `home`, `dialogue_builder`, `finds`, `features_ui`, `features_quests` |
| `data/*.json` | - | `furniture_art_spec` (feed for the home art spike), `wardrobe_art_spec`, `wardrobe_design_requests` (15 new garment designs, each with a working fallback), `map_markers` (chests / digs / creatures / unique spots per area for the map authors) |
| `tools/src/` | - | generator (`gen_all.py`; tables in `src_*.py` are the source, the Lua files are the artefacts) |
| `tools/validate/`, `tools/sim/` | - | `run_validate.sh` (+ `mutation_test.py`), `balance_sim.py`; results in `reports/` |

Top-level config keys are unique (`home`, `loot`, `furniture_sets`, `wardrobe_sets`, `wardrobe`, `rarity_tiers`, `perk_caps`) and collide with nothing in game_balance.lua or PLAN 3.11.
Data files use `kind = "config"` because that is the only free-form kind the current runtime merges (`LuaRuntime.get_config("home.tiers")`); `recipes`/`shops` wait for P10's loader.

## 2. Conventions

* **Rarity ids**: `normal`, `uncommon`, `rare`, `unique`, `legendary` (labels Almindelig, Ualmindelig, Sjælden, Unik, Legendarisk; keys `RARITY_*`). Replaces the docs' `common|epic`; P07's `INV_RARITY_EPIC` should become `RARITY_UNIQUE`.
  Unique and legendary items are **keepsakes**: `buy_price = 0`, `sell_price = 0`, `protected = true`, never in a shop, never craftable, found exactly once (`stack 1`).
* **Ids** are English snake_case like the repo; Danish only in the CSV. Keys: `ITEM_<ID>`, `ITEM_<ID>_DESC`, `ITEM_<ID>_HINT` (keepsakes: where the story says to look), `FSET_*` / `OUTFIT_*` (sets; `SET_*` is the settings family), `HOME_TIER_n[_DESC|_GATE]`, `DLG_BUILDER_Tnn_{IDLE,OFFER,BUILDING,DONE}`, `FIND_*`, `SHOPTAB_*`.
* No `#`, `else`, loops, escapes, `..`, arithmetic or `nil` in any file (P10 lint); colours are hex without `#`; text never contains `--` or ASCII quotes.
* Comparisons on possibly-unset flags are avoided: `false == 3` raises a script error in the current interpreter (found while validating); dialogue/quest hooks use `local x = context.x or flag or 1`.

## 3. Item fields (new ones marked +)

Common: `name_key description_key category rarity buy_price sell_price max_stack` (existing schema) plus `+worth` (reference value, monotone in rarity, basis of prices), `+acquire` (`buy|build|find|reward`), `+sources[]`, `+hint_key`, `+protected`, `+set`, `+seasons[]` (shop rotation weights).

**Furniture** (`category = "furniture"`): `+furniture_type` (bed table chair sofa storage shelf lamp rug decor wall_decor plant hearth instrument grand), `+decor` (hygge points), `+placeable = "home"`, `+placement` (floor|rug|wall|tabletop|ceiling), `+footprint {w,d}`, `+interact` (sleep sit storage warm play), `+art {template, material, paint?, fabric?, metal?, crystal?, stone?, size|seats|shape?, tier}` = exactly the `Style` / kwargs of `spike_home/tools/characters/furniture_traetoppen.py` (`tier` 0..4 = rarity ladder), `+recipe {id, station, min_home_tier, ingredients, unlock_flag?}` (mirror of `lua/recipes`).

**Clothing** (`category = "clothing"`): `+slot` (hat shirt pants dress shoes jewellery), `+subslot` (circlet necklace bracelet earrings), `+wearable`, `+perks {speed, energy, luck, discount}`, `+art {layer, slot, palette{A primary, B trim, C accent hex}, status = existing|requested, fallback}`; `layer` is a garment design of `spike_wardrobe` (15 exist, 15 are requested in `data/wardrobe_design_requests.json`; 67 items use existing designs, 29 use a requested one and fall back until it is baked).

**Materials**: `category` building_material | gem | blueprint, `+group` (timber hardware textiles stone gem blueprint). Blueprints: `+unlock_flag` (`bp_kongelig` ...), `+consumed` - using one sets the flag that unlocks the rare recipes carrying that `unlock_flag`.

**sources[]** (`kind`): `shop {shop, slot}` (fixed|daily|tri|weekly|weekly_blueprint|weekend), `craft {recipe, station, min_home_tier, blueprint?}`, `find {zone[, container]}` (random pool; with `container` = a one-time *wanderer*), `spot {zone, spot[, quest]}` (hand-placed, one-time), `gift {npc, hearts}`, `tier_gift {tier}`, `quest {quest}`, `set_reward {set}`, `boss {enemy[, pool|first_kill]}`.

## 4. Formulas

* Furniture `worth = base x template factor x size x material`: bases 150 / 450 / 1600 / 5000 / 12000 (normal..legendary), minimum 70 / 180 / 700 / 2500 / 6000; template factors bed 1.0, throne 1.8, piano 2.0, vase 0.2 ... (`build_items.py`); `buy = worth`, `sell = 40 % (38 % rare)`, rounded to 5. Clothing bases 60 / 220 / 800 / 2600 / 7000 x slot factor (dress 1.4, circlet 1.6 ...).
* `decor` = 2 / 5 / 11 / 24 / 42 x size (1.0 for 1 tile, 1.25 for 2, 1.5 for 3+, 0.8 for wall/tabletop/rug). **Hygge** = sum of placed `decor` -> level (0, 15, 45, 110, 240, 420 points = Køligt, Lunt, Hyggeligt, Rigtig hyggeligt, Eventyrligt, Kongeligt hyggeligt) -> +0/2/4/6/8/10 energy, +0/0/0/1/2/3 % luck.
* Recipe cost (at buy prices of the inputs) is 45-85 % of the item's buy price, always above the sell price; rare recipes need the blueprint flag. Stations: `snedkerbord` home tier 1, `vaev` (loom) 3, `smedje` 5; `min_home_tier = max(station, rarity 1/3/5)`.
* Perks: uncommon 1 perk of one step, rare one double step (or two single), unique 3+1 steps, legendary 4+2 (step: speed 1 %, energy 2, luck 1 %, discount 1 %). Caps (`perk_caps`): speed 15 %, energy 20, luck 20 %, discount 15 %; global clamps `energy_total` 60 (home + hygge + sets + clothes) and `discount_total` 20 % (clothes + sets + hobbit 10 % + friend discount). Best piece in every slot reaches speed 15 %, luck 19 %, energy 28 (clamped to 20), discount 10 %.
* Set bonus = the highest `bonuses[]` entry whose `pieces` is reached (not cumulative). Furniture sets count PLACED pieces and all sets add up; wardrobe sets count WORN pieces and only the `wardrobe.max_sets_counted` = 2 best count. A wardrobe `capstone` (legendary) is granted when every other member is owned.
* **Luck** L (clamped 0.20): ordinary rarity odds of uncommon and rare x (1 + 5L), `normal` absorbs the difference; wanderer chance x (1 + 5L).

## 5. Home tiers (`home.tiers[]`)

`{tier, id, name_key, description_key, gate_hint_key, art{exterior, night, interior, floor, walls, platform_back_rows, scaffold}, cost{gold, days, materials{item=n}}, requires{quests[], friendship{npc=hearts}, hygge}, perks{max_energy_bonus, storage_slots, furniture_capacity, guest_visits_per_week, rooms[], unlocks[]}, gift_items[], dialogue{idle, offer, building, done}}`.
Ids and art ids are those of `spike_home` (`skur hytte straatag bindingsvaerk gaarden taarnhus landsted herregaard borg slot`, `house_tNN`, `room_tNN`, `scaffold_toNN`); `furniture_capacity` = `int(0.55 x floor cells)` of the spike's room shapes (11 ... 74).

| Tier | Name | Gold | Days | Needs besides money and materials |
|---|---|---|---|---|
| 2 Hytte | | 200 | 1 | quest intro_lottery |
| 3 Stråtækt hus | | 300 | 2 | - |
| 4 Bindingsværkshus | | 900 | 2 | Hyldeblomst 2 hearts |
| 5 Gården | | 2 100 | 3 | quest first_animal (gift: Rodtronen) |
| 6 Tårnhus | | 4 500 | 3 | quest crystal_cave (gift: Månestanduret) |
| 7 Landsted | | 7 500 | 4 | fairy_friendship, 4 hearts, hygge 2 (gift: Stjerneklaveret) |
| 8 Herregård | | 12 500 | 5 | snurresvampen, hygge 3 (gift: Den svævende reol) |
| 9 Borg | | 19 000 | 6 | moonstone_crown, hygge 3 (gift: Krystaltronen) |
| 10 Slottet | | 27 000 | 8 | 8 hearts Hyldeblomst, 2 hearts Fekongen, hygge 4 (gifts: Måneskinssengen, Stjernekronen) |

Unlocks (mechanics other systems read from `perks.unlocks`): `workbench` (T1) `oven` (2) `loom` (3) `guest_visits` (4) `forge_bench` (5) `forecast` (6, tomorrow's weather) `festival` (8) `royal_visit` (10). Rooms are cosmetic names.

## 6. Loot (`loot`) and shops

* `containers`: `trae jern fe konge dig` with `respawn_days, rolls{min,max}, find_chance, odds{normal,uncommon,rare}` (basis points, sum 10000), `kinds{furniture,clothing,material}` weights, `wander_bp`, `pity_opens`. `creatures`: `bat ugleoje lysesvamp` (`find_chance`, odds, kinds). `zones.<area>`: container `count` (+ overrides), `creatures`, `wanderers[{item, container}]`, `pools{kind{rarity[{item, w}]}}` (an empty pool re-draws the kind).
* Draw: open container -> `n` rolls; once per open, if the area still has an unfound wanderer for that container, with `wander_bp` (or after `pity_opens` opens without) the first roll is that unique, then ordinary rolls: `find_chance` -> kind -> rarity (odds) -> item (`w`). Legendary never comes from chests. Boss: first kill = quest reward; repeat kills every 7 days: one `konge` chest + 8 % legendary from `boss.pool` (pity 10 kills, empty pool -> `fairy_dust x3`).
* Fixed: `spots` (15, one-time, `requires{quests[], day_min, home_tier_min}`: validator R21 - quest ids are quest files that exist and match the quest of the item's `spot` source, `day_min` >= 1, `home_tier_min` 1..10, no other key), `gifts` (6, friendship hearts `friend_<npc>`), `tier_gifts` (7), `set_rewards` (4), `quest_rewards` (8 quests). All 30 unique and 19 legendary items have exactly one of these or a wanderer/boss pool as source; the validator checks both directions.
* Shops: plan schema + `tabs[]`, `buys[]`, `open_weekdays` (flea market: Saturday, Sunday = weekday index 5, 6), `rotation[] {id, period (days), pick, qty, rarity|mixed, price_mult, season_boost, pool[]}` and `price_curve {rarity_markup, repeat_surcharge{step 0.08, max 0.32}, friend_discount{per_heart 0.005, max_hearts 10}, sales[{from_day 22, to_day 28, discount 0.15, rarity}]}`.
  Rotation: `epoch = floor((total_day - 1) / period)`, seed = stable hash(shop id, slot id, epoch), candidates = pool, weight 1 (+ `season_boost` when the item's `seasons` contains the current season), pick `pick` distinct by weighted shuffle, each offered with `qty` units. Price = `buy_price x buy_multiplier x price_mult x (1 + repeat surcharge) x (1 - sale) x (1 - friend discount)`, hobbit 10 % on top, total discount capped by `discount_total`.

## 7. Runtime contract (what other packages must provide)

| Need | Owner (PLAN) |
|---|---|
| flags `home_tier` (int), `home_building` (target tier or 0), `home_upgrade_done` (tier until the builder's celebration was seen), `friend_<npc>` (hearts), `bp_*`; set `home_tier = 1` on new game (quest flags like `moonstone_crown_done` are set by the quest hooks and only used inside them) | P02 / P20 |
| HomeService: `home_upgrade` dialogue action (field `tier`) opens the upgrade panel; checks `requires`/cost/materials, builds in `cost.days`, tent while building, grants `gift_items`, emits `game_event("home_upgraded", {tier})` | P14 / P20 |
| `EventBus.game_event` names: `furniture_placed {item, rarity}`, `hygge_level {level}`, `festival_held`, `home_upgraded` + quest binding `on = "game_event"` (with `event`, optional `rarity`, `min_level`) | P02 / P13 |
| Placement of `placeable = "home"` items on `furniture_capacity` cells (layers floor/rug/wall/tabletop/ceiling, `footprint`, rotations of the art), hygge + set bonuses, perk clamps, outfit equip with `wardrobe.exclusive` | P06 / P20 |
| Value-add to ShopSystem: `rotation`, `tabs`, `qty`, `price_curve`, `buys`, `open_weekdays`; CraftingSystem: `station`, `min_home_tier`, `unlock_flag`; blueprint use sets its flag | P12 |
| LootService (algorithm above), map markers: `chest tier=trae|jern|fe|konge`, `dig_spot`, `unique_spot id=<spot id>` per area with the counts in `loot.zones`; boss chest | P19 / P11 |
| `npcs.lua` entries `fairy_builder` (Tømrerfe Hasselnød, home hyggebyen, shop builder_yard), `fairy_furnisher` (Møbelfe Stokrose, shop furniture_shop), `fairy_tailor` (Skrædderfe Fingerbøl, shop tailor_shop), and a `flea_market` choice in Pippin's dialogue; the three dialogues must be reachable; quest choices for `bogtraeet` (fairy_wizard), `snurresvampen` (guard_oak), `moonstone_crown` and `slotsdroemmen` (fairy_king) | P10 / P14 |
| Quest files of P13 must keep the `rewards` of the four amended quests (lost_cat becomes non-repeatable); P12's `economy.csv` may absorb the ITEM_ rows | P13 / P12 |
| Assumed PLAN items (not in the repo yet, prices assumed in the sim): `copper_ore`, `moonstone`, `wool` | P12 |
| Art: bake 130 furniture from `data/furniture_art_spec.json`, icons for all 258 ids, 15 requested garment designs | art packages |

## 8. Checks and numbers

```
# needs lua5.4 + luac5.4 (brew install lua), Godot 4.7.2, the art venv for the footprint probes and font check (python with numpy + fontTools)
tools/validate/run_validate.sh        # generate + copy the repo to ../features_content_proj + luac/lua5.4 + Godot headless + python checks -> reports/validation_report.txt
python3 tools/validate/mutation_test.py   # 17 deliberate defects, each must be caught
python3 tools/sim/balance_sim.py --features . --lua-dump reports/lua_dump.json --repo-lua-dump reports/repo_lua_dump.json --out reports/balance_output.txt
```

Validator: **77 passed, 0 failed, 0 warnings**; mutation test: 17 of 17 caught. It proves, among other things: real Lua 5.4 and the project interpreter read identical data (34 tables), all 258 new ids register in `LuaRuntime.get_item_def`, accepting and completing all 8 quests through `QuestManager` and the Lua hooks delivers exactly the listed gold and items, the builder dialogue picks the right branch for 29 flag combinations, every art template/material/garment id exists in the live spikes, all 130 furniture items build with the spike's real template function and report the footprint/layer/interaction stored in the Lua, rarity counts, price monotonicity per template and per slot, sell < craft cost < buy for every recipe, no orphan sets, every unique/legendary source points both ways, realised loot odds equal the designed odds (40 000 simulated opens per container), all text keys resolve, Danish text has no TODO/English words and every glyph (also Æ Ø Å) exists in Caprasimo and Alegreya Sans.

`tools/sim/balance_sim.py` (deterministic, assumptions printed at the top of `reports/balance_output.txt`): the typical player reaches tier 10 after about 50 real hours (day 337); casual about 137 h, dedicated about 28 h; tier 2 is built on day 3 and tier 3 on day 8 (1.2 h); with the CURRENT repo crop prices instead of PLAN 3.10 the typical player needs about 70 h. Furnishing the castle (74 pieces) costs about as much again as the upgrades (about 43 000 gold).

## 9. Generated dungeon extension (DL4)

The live schema adds `lua/items/weapons.lua`, `gems.lua` and `dungeon_materials.lua`, `lua/recipes/dungeon.lua`, `lua/shops/smithy.lua`, `localization/dungeon_items.csv`, and the `dungeon`, `dungeon_run`, `dungeon_loot` and `bosses` config tables. These are required inputs in every validator stage. The original art catalogue retains its category-specific contracts; dungeon rules validate all new items and their links to the complete live item registry.

- Weapons use `category=weapon`, `weapon_family`, `damage`, `stamina_cost`, `max_stack`, and an `effect={id,...}` on rare and better items. W1 checks independent rarity damage/family factors; W2-W4 validate capabilities, protected fixed rewards and acquisition routes. Ordinary weapons may be found, crafted or sold by the smithy; keepsakes use fixed sources.
- Gems use `category=gem`. Rough stones have `rough=true`, `appraise_band` and zero buy/sell prices. Cut gems have `lantern={tint,themes}`. G1-G3 check one rough stone per band, supported lantern themes, and ordinary-only appraisal pools with basis-point odds. Existing ordinary gems remain defined in their original item files.
- Dungeon materials use `category=material`, `group=dungeon` and explicit sources. A source may be `find`, `node`, `creature`, `appraisal`, `shop`, `craft`, `spot` or `boss`; a boss source can name `first_kill=true`. M1 checks node source placement and actual yield, including aliases; M2 caps sell price at `limits.material_sell_max_pct` of nominal buy price. Surplus is modelled at its complete real sell value.
- Forge valuation W5 uses nominal buy price, or `limits.recipe_unbuyable_mult * sell_price` for an unbuyable ingredient. Ingredient cost must be 45–85% of output buy price and exceed output sell value. Keepsakes cannot be forged.
- K1 links exactly three first-kill rune shards to the vault's `requires.items` and `consume` lists. Item requirements and consumed ids must exist.
- DB1-DB5 compare all twelve floor/band records, chest tiers, all five boss tables, unique/lake spot placement, and every node/anchor yield. Unplaced yield rows are permitted only as alias targets. The first band has no placed crystal nodes: its rough stones come from chests, and no false crystal source is listed.

`data/features/map_markers.json` version two contains only the static farm and Hyggebyen. Generated forest placement belongs to `lua/config/dungeon.lua`, with DB1-DB5 replacing the old static forest marker manifest. Legacy version-one synthetic fixtures still exercise their original marker/boss invariants.

P1 is the separate mandatory live-data gate `tools/dungeon_loot/run.sh --check`; it records fixed progression/value/cap/dust/rarity budgets and source binding. The model and its limits are documented in `tools/dungeon_loot/README.md`. It does not measure combat or player experience. Runtime combat acceptance is separate.
