# BALANCE - how long the castle takes (a model, not a playtest)

`tools/features/sim/balance_sim.py` is a deterministic expected-value model of the home upgrades, the loot economy and the shops.  It reads the DATA (real Lua 5.4 dumps of the stage tree and
of the repo: `lua/data/home_tiers.lua`, `loot_tables.lua`, the item prices, the recipes, the quests, `game_balance.lua`), never a generator.  Every assumption is a named constant at the top of the
file and is printed with the results.  **It is a model with assumed income, not a playtest**: the farm income follows a plot-growth curve per play profile, the forest income is the node yield plus the
expected loot of the chests / digs / creatures, hearts come from one weekly chat per NPC, furniture takes a fixed share of the player's lifestyle budget.

## The numbers (reviewed pack = this repo's rerun)

Hours are REAL hours (one game day = 9 real minutes, 6.67 days per hour) until the Slottet (tier 10) is finished.

| profile | game day | real hours | what the profile is |
|---|---|---|---|
| typical | **345** | **51.8 h** (about 52) | 70 plots at full stretch, 70 % of the days watered, a forest run every third day, 30 % of the repeatable quests |
| casual | **919** | **137.8 h** (about 138) | 30 plots, 55 % watered, a forest run about every seventh day, 15 % of the quests |
| dedicated | **185** | **27.8 h** (about 28) | 110 plots, 85 % watered, a forest run every second day, 50 % of the quests |

Total price of the ten tiers: 74,000 guldagern plus materials (about 100,000 spent on the home including bought materials and the 27,000 of the castle itself); furnishing the 74-piece castle costs about
43,000 more.  The binding constraint is money from tier 5 on; the gates bite at tiers 2, 4 and 6 (quest `first_animal`, the mayor's hearts, `crystal_cave`).

### Why 51.8 and not 50.5 (review RV-S1)

The first model said 50.5 h / 136.8 h / 27.6 h because it counted the LEGACY repeatable `lost_cat` (150 guldagern every 5 + 3 days) as steady income.  The PLAN and the reviewed pack make `lost_cat`
one-shot (decision CD15).  The sim therefore has two quest modes and the repo rerun reproduces both (output of `tools/features/sim/balance_sim.py`, plan crop table, home_cost_scale 1.0):

| `--quests` | meaning | typical | casual | dedicated |
|---|---|---|---|---|
| `repo` | the quests that REALLY exist in the repo now: until P13 lands, `lost_cat` is the legacy repeatable one | day 337 / **50.5 h** | day 912 / **136.8 h** | day 184 / **27.6 h** |
| `stage` | the reviewed quests of the stage tree = what P13 delivers (`lost_cat` one-shot, reviewed rewards) | day 345 / **51.8 h** | day 919 / **137.8 h** | day 185 / **27.8 h** |

Both outputs are byte-identical to the reviewed pack's `balance_output_fixed_legacyrepo.txt` / `balance_output_fixed_p13repo.txt` (`diff`: 235 lines each; only the "repo crops" sensitivity
sections, lines 63-110, differ, because the repo's crop table is not the legacy one any more; plan-crop sections A-C, drop rates D, rarity E, shop curve and recipe loops F, collection G are identical).  After P13 has
landed, `--quests repo` equals `--quests stage`: run the sim again with `tools/features/sim/run_balance.sh` and update this file.

### What changed since the pack was written

* **Crops.** The pack also ran the model with the LEGACY repo crops (4 crops, about 70 h for the typical player).  P10's `game_balance.lua` now carries the PLAN 3.10 table (8 crops, the same seed prices,
  days and sell prices), so the "repo crops" section equals the "plan crops" section: the sensitivity run of the pack no longer exists.
* **Prices.** P12's economy (wave 3) defines `copper_ore`, `moonstone` and `wool` at the prices the sim had assumed (35 / 14, 440 / 220, 30 / 12): nothing moved.  The reruns are run at the time of F1's wave
  against whatever the repo had then; rerun when P12's final prices and P13's quests are in (`run_balance.sh --quests repo`).

## The knob `economy.home_cost_scale` (P10)

`lua/config/game_balance.lua` has `economy.home_cost_scale = 1.0`: a multiplier on the GOLD price of every home upgrade (materials are not scaled).  The sim reads it (or `--home-cost-scale X` for a what-if),
`tests/lib/features/grant.gd` multiplies the tier gold by it, and HomeManager (F2) must apply the same factor.  What-if (`--quests stage --crops plan`):

| scale | typical | casual | dedicated |
|---|---|---|---|
| 0.50 | day 272, 40.8 h | day 593, 89.0 h | day 185, 27.8 h |
| 0.75 | day 277, 41.5 h | day 746, 111.9 h | day 185, 27.8 h |
| **1.00** | **day 345, 51.8 h** | **day 919, 137.8 h** | **day 185, 27.8 h** |
| 1.25 | day 391, 58.6 h | day 1072, 160.8 h | day 197, 29.5 h |
| 1.50 | day 459, 68.8 h | day 1246, 186.9 h | day 244, 36.6 h |

Below 1.0 the typical and the dedicated player are held back by the GATES (quests, hearts, hygge levels, the build days), not by money: cheaper tiers shorten the casual game a lot and the dedicated game not at all.

## How to rerun

```
tools/features/sim/run_balance.sh --quests stage      # runs the validator's dumps first (tools/features/reports/lua_dump.json, repo_lua_dump.json), then the sim
tools/features/sim/run_balance.sh --quests repo --no-validate
python3 tools/features/sim/balance_sim.py --quests stage --crops plan --home-cost-scale 0.75 --out FILE --json FILE
```

Outputs: `tools/features/reports/balance_output_<mode>.txt` and `balance_summary_<mode>.json` (gitignored).  Sections of the output: A time to every tier, A2 what binds each tier, B income per hour at each stage,
C totals, then drop rates per container, recipe margins (no craft-and-sell loop: the best margin of any recipe is negative), shop rotation spend and the value of the collection.

## Honest limits

* Income is an assumption per profile; a real player's farm, forest and shop habits will differ.  The model has no randomness: it prices EXPECTED finds (legendary pieces only through the boss pool with its pity counter).
* The hours do not include talking, walking or menus; 9 real minutes per game day is the PLAN's clock.
* Hearts come from the weekly chat heart (DF3, P14); if P14 changes that mechanic the gate rows of tiers 4, 7 and 10 move (rule FG1 only proves the hearts are earnable at all).
* The prices of furniture and clothing in shops are the data; "furnishing the castle costs about 43,000" assumes a 40 / 40 / 20 normal / uncommon / rare mix.
