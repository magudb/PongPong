# Builder supply and stock-aware home progression

## Decision

Construction remains earned. No item prices, home gold/material costs, build days,
quests, friendship/hygge requirements, unlocks, recipes or sell values change.
Only `builder_yard` supply in `lua/shops/home_shops.lua` changes:

- **Fixed materials:** existing 12 shelves still hold **40** each; replenish **40
  per dawn**, capped at 40 (previously +1).
- **Daily catalogue:** all **5 of 5** pool members, **40 each per daily epoch**
  (previously 3 random members, 30 each).
- **Fine catalogue:** all **8 of 8** pool members, **40 each per weekly epoch**
  (previously 4 random members, 12 each).

The slot IDs, pools, daily/weekly periods and price multipliers stay unchanged.
The other shops are untouched. This deliberately removes random catalogue
absence from construction supply, not its finite quantities or weekly planning.
Fine furniture materials share this expanded fine catalogue; that is an explicit
consequence, not an unreported construction-only exception.

A shelf cannot be exceeded by reopening/reloading the shop. A weekly purchase
count persists through ordinary dawns and save/load until the slot's next epoch,
**days 1–7, 8–14, …**, not seven days after the purchase. Fixed shelves refill on
`day_started`, including closed days, never above their cap. ShopSystem and
ShopRotation already implement this, so no runtime transaction/save code changes
are needed. Existing saves keep their depleted counts; their next dawn uses the
new fixed restock. Existing rotation purchases still subtract from the newly
bounded 40-unit offer; migration does not reset purchases.

### Why 40, for all ten tiers

The existing shelf size is retained instead of adding unlimited stock, bulk
cheats, larger inventory limits or a second ordering system. Guaranteed complete
catalogues avoid an unbounded random absence of marble. Every one-tier weekly
material demand fits one fine shelf, including **40 marble for tier 10**.
Tier 7 plus tier 8 require 36 marble total; tier 10 then needs a later weekly
shipment unless another shipment was saved beforehand. Gems remain found, not
purchased. Ordinary construction needs at most three open-day visits from a full
shelf, with daily slate requiring at most two. Fridays, festivals, other spending
and previously exhausted shelves can add calendar days.

The table is derived from `lua/data/home_tiers.lua`; visits assume enough earned
gold, no other purchases and initially full shelves. Rotating rows are listed as
`daily` or `weekly`, not counted as free materials.

| Tier | Gold | Maximum fixed-shelf visits | Daily material needs | Weekly material needs | Found requirements |
|---|---:|---:|---|---|---|
| 1 | 0 | 0 | — | — | — |
| 2 | 200 | 1 | — | — | — |
| 3 | 300 | 1 | — | — | — |
| 4 | 900 | 1 | oak 16 | — | — |
| 5 | 2,100 | 1 | oak 24 | copper 4 | — |
| 6 | 4,500 | 2 (stone 60) | slate 30 | walnut 12 | amethyst 2 |
| 7 | 7,500 | 1 | slate 40 | marble 16, walnut 20, gold leaf 2 | — |
| 8 | 12,500 | 3 (brick 90) | — | copper 30, marble 20, gold leaf 4 | — |
| 9 | 19,000 | 3 (stone 120) | slate 60 (2 visits) | brass 12 | moonstone 2 |
| 10 | 27,000 | 2 (roof tile 80) | — | marble 40, gold leaf 12 | amethyst 6, moonstone 6 |

Previously brick 90 required 50 replenishments after the first 40, stone 120
required 80, and weekly marble 40 required at least four *selected* weekly
shipments of 12. Increasing common restock alone would not fix the fine-material
bottleneck; charging for unlimited missing materials would only hide it.

## Simulator contract

`tools/features/sim/balance_sim.py` now owns one `BuilderStock` per simulation:

Each simulation starts fresh and advances continuously; `BuilderStock` does not
import or resume runtime save files. Runtime save compatibility is provided by
the unchanged ShopSystem serialization and epoch logic, exercised separately by
the real-shop regressions below.

1. Read actual shop definitions, not `items.sources[].slot` hints as permission
   to buy today. Keep fixed units and purchases keyed by rotation slot/epoch.
2. Replenish fixed shelves with the actual capped `restock`; draw offers by
   period, longest-slot priority, eligibility, season weights and distinct picks.
3. Attempt one visit at **noon** each game day, respecting building weekday
   hours and authored festival closures. Builder closes on Friday. A festival
   closure begins one hour before its window, matching SocialManager.
4. Once the next tier's gates and the **whole remaining order** are affordable,
   buy only available integer units at full neutral-race/base builder prices,
   keeping the tier's gold fee reserved. Paid materials accumulate across visits.
   Start construction only after the inventory really covers every material.
5. Keep affordability, gates, found-material waits and `stock_wait` separate.
   `stock_wait` includes affordable, gate-ready visits blocked by closure or
   shelf absence/exhaustion. It can overlap a found-material wait. JSON includes
   purchases with day, tier, amount, price, pre-purchase wallet and availability.

No assumed 40% self-crafting discount remains: the model does not execute those
recipes or pay their inputs. Found materials are retained; quoted shop materials
are paid in full. Scheduled investments now queue until affordable instead of
creating a negative wallet; the eventual investment costs are not waived.

Current Lua includes dynamic gem/weapon kinds without legacy static pools.
The legacy forest EV no longer crashes on these: it retains their draw weight
but assigns **zero speculative income/materials**. Its other node/run/yield
assumptions remain explicit. Use the existing live-dungeon pacing model for a
separate source-backed sensitivity run.

### Verification and interpretation

Regressions run through the existing **`shop_rotation`** harness section; its
helper invokes `test_balance_supply.py`, so the model tests are not an orphaned
standalone suite. The Python suite evaluates current Lua with the repository's
real-Lua serializer and uses unchanged home data for lifetime acceptance.

- Runtime: exhaustion, listed-price payment, no oversell, real end-day refill,
  exhausted save/load, marble availability, weekly persistence/new epoch,
  no-gold rollback and full-backpack rollback.
- Model: affordable-but-out-of-stock dawn wait; weekly exhaustion wait; absent
  rotation offers; capped incremental refill; atomic refusal; Friday/festival
  closure; full material prices; all ten tiers' supply bounds; no credit;
  earned-money conservation; source-priced purchase/shelf replay; sequential
  construction and gates; tier-10 marble; reported stock waits.
- RED/GREEN tracer bullets were observed separately for shop policy, model dawn
  wait, weekly wait, weekday closure, festival closure, full-price quotes,
  live-pool compatibility, no-credit investments, audit data and report output.
  Refusal/cap/source-bound invariants additionally cover existing behavior.

With the unchanged named profiles and source costs, the legacy-EV model reaches
all ten tiers. Both crop modes give the same results because these profiles
choose the same profitable seasonal crops and no winter crops:

| Profile | Tier 8 done | Tier 9 done | Tier 10 done | Total home spend | Gross earned through completion |
|---|---:|---:|---:|---:|---:|
| casual | 420 | 638 | 943 | 102,523 | 159,317 |
| typical | 159 | 250 | 358 | 102,523 | 152,318 |
| dedicated | 84 | 138 | 191 | 102,523 | 156,310 |

All nine upgrades pay the unchanged 74,000 gold fees plus actual purchased
materials. Wallets stay nonnegative, all scheduled investments are paid, and
late-tier stock/closure waits remain visible. A three-seed run of the existing
live-dungeon pacing model (`--n 3`, no free-furniture substitution) also completed:
casual 668–697 days, typical 241–256, dedicated 140–143. This is sensitivity
coverage, not a statistical balance guarantee.

**Limits:** this is source-backed earned *model* acceptance plus real runtime
shop tests, not an end-to-end child/player castle playthrough. Farming income,
zone access, quest completion days, friendship accrual and decorating/hygge are
still named profile assumptions, not actions executed by the Python model. The
inventory model is aggregate; runtime backpack refusal is checked separately.
The Python weighted subset-rotation RNG is deterministic but not Godot PCG seed
parity. Current builder draws include every candidate, so builder membership is
exact for every world seed; hypothetical reduced-pick scenarios are labelled
Python scenarios. Neutral full prices are conservative; no favorable racial,
friendship or gear discounts are assumed. No claim is made that the resulting
191–943-day range satisfies final player-balance or production acceptance.

### Reproduce without a project copy

Use the repository art Python (or a Python with the standard library) and Lua
5.4. Keep temporary dumps/reports in the configured scratch directory:

```sh
export TMPDIR=/Users/magnusudbjorg/.hermes/cache/scratch
tools/art/.venv/bin/python -B -I tools/features/sim/test_balance_supply.py
tests/run_playtest.sh --strict --no-boot --only=shop_rotation \
  --report="$TMPDIR/builder-supply.json"
tools/art/.venv/bin/python tools/dungeon_loot/pacing.py --n 3
```

To run the full balance CLI, evaluate current `lua/**/*.lua` with
`tools/features/validate/ser.lua` into a scratch JSON and supply that same dump
as both `--lua-dump` and `--repo-lua-dump`, with `--crops both --out ... --json ...`.
This uses current source without generating a stage tree/project copy. The
wrapper `run_balance.sh` normally creates those copies; it is not required for
this focused check.
