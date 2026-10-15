# scripts/loot - LootService, the loot rules and the helpers of the marker handlers (package F4-loot-shops)

| File | What it is |
|---|---|
| `loot_service.gd` | the autoload `LootService` (feature autoload, appended by `tools/features/add_autoload.py LootService`): the API, the two-phase transaction, delivery, the save section `loot` (order 40), the hosts of `DungeonFloors` and the appraisal screen |
| `loot_rules.gd` | `LootRules`: the pure draws (luck odds, kind -> rarity -> item, the empty-pool re-draw, the wanderer and boss-pity decisions; `compile()` + `roll_plan()` for several rolls of one row); no node, no autoload |
| `loot_markers.gd` | `LootMarkers`: what `scripts/world2d/loot_chest_2d.gd`, `dig_spot_2d.gd` and `unique_spot_2d.gd` share (uid / zone of a marker, DungeonFloors lookups, stamina, whispers, the sparkle burst) |

The shop side lives next to ShopSystem: `scripts/economy/shop_rotation.gd` (`ShopRotation.stock(shop_id)`) and `scripts/economy/price_curve.gd` (`PriceCurve.final_price(shop_id, item_id, base_price)`).
Marker rows: `lua/config/marker_handlers.lua` (this package is the ONLY editor of that file; other packages add rows through the amendment lists of their orders).

## The API (every answer `{ok: bool, results: [{id, amount, rarity, kind}], reason: StringName}`)

```
open_container(zone, container_id, uid, ctx := {})      dig(zone, uid, ctx := {})        node_loot(kind, uid, ctx := {})       on_enemy_defeated(kind, ctx := {})
on_boss_defeated(boss_id, ctx := {})   (idempotent per ctx.uid)                           claim_spot(spot_id, ctx := {})        spot_state(spot_id) -> open | claimed | cooldown | locked
check_friend_gifts(npc_id)  grant_set_capstone(set_id)  set_capstone_granted(set_id)      appraisal_quote(rough_id)             appraise(rough_id, ctx := {})   appraisal_available() -> bool
deliver(item_id, amount := 1) -> {ok, sold, reason, gold}  (THE one place items enter)     found(item_id)  day_value()  daily_cap_reached()  set_seed(int)  luck()
```

`zone` = the AREA id of the map (farm, skovkant, dybe_bregner, svampelunden, krystalgrotten) or, on a generated floor, the band of the floor. Hyggebyen has no zone: its only find is the spot `kufferten`.
`ctx = {dungeon, floor, band, zone, rng, luck, lock_ok, first_kill, ready, uid, deliver, consume}`; `ctx.odds` is ignored; `deliver = "orbs"` returns the results without adding them (the default of `on_enemy_defeated`;
the pickup orb's pickup calls `deliver`), `consume = {item: n}` is taken in the same transaction (the lake key, the rune shards). Container uid = `LootRules.container_uid(area id, cell)` = `"<area id>:<x>,<y>"`; a generated
floor uses `DungeonFloors.uid_of(area, cell)` = `dg:<day>:<floor>:<cell index>` and never writes `opened{}`.

## Two-phase (every mutating call)

PLAN (pure draws; the saved stream is the only thing that moves) -> FIT (every backpack-bound roll TOGETHER on a virtual pack, the consumed items freeing their slots; furniture / clothing have their own stores) ->
DELIVER -> COMMIT. Anything that does not fit answers `{ok = false, reason = &"full", results = []}` and nothing at all has happened: no delivery, no pity / wanderer / boss counter, no `opened` entry, no consumption, and the
stream is put back. The whisper is `DEXP_BACKPACK_FULL` on a dungeon call when that key exists (DR1), else the existing inventory-full notification.

## The delegation seam (DL5 `scripts/dungeon_loot/dungeon_loot_rules.gd`, wave 5; the tests use a FAKE written to user://)

Every call whose uid starts with `dg:` (or `ctx.dungeon`) goes to the delegate when the script exists and has the method; without it the container algorithm runs on the band's tables. Farm and Hyggebyen containers never go there.

```gdscript
static func roll_container(state, req) -> plan      # open_container and dig          req.kind = &"container" | &"dig", req.container = tier
static func roll_node(state, req) -> plan           # node_loot                        req.node_kind
static func roll_drop(state, req) -> plan           # on_enemy_defeated                req.creature
static func boss_result(state, req) -> plan         # on_boss_defeated                 req.boss
static func roll_spot(state, req) -> plan           # claim_spot                       req.spot
static func roll_appraisal(state, req) -> plan      # appraise                         req.rough, req.band, req.fee
static func fits(plan, pack_view) -> bool           # pack_view = {free_slots, stack_room{item}, max_stack{item}, own_store{item}}; the consumed items are already taken out
static func commit(state, plan) -> state            # the ONLY mutator (pity, misses, day value, boss state, claimed, unique_day, appraise counter)
static func appraisal_quote(cfg, rough_id) -> {band, fee}     static func spot_state(state, req) -> StringName       (both optional)
# state = a deep copy of the `dungeon` sub-dict {found, claimed, wander, boss, appraise, day, unique_day} of the save section `loot`
# req   = {kind, zone, band, container, uid, ctx (without odds), luck, day, cfg (config loot), ...the keys above}
# plan  = {ok, reason, results: [{id, amount, rarity, kind}], ...fields only commit reads}        a plan mutates NOTHING
```

`dungeon.found {item: day}` (the keepsake registry) is written by `deliver` and never pruned; `dungeon.day {day, value, capped}` is the daily cap's record (`day_value()`, `daily_cap_reached()`, the whisper `LOOT_DAY_TIRED` and
`game_event loot_day_capped` once per day). `deliver` also fires `game_event loot_keepsake_found {item, rarity, source}` and whispers `LOOT_KEEPSAKE_FOUND_FMT`.

## What LootService hosts

* the child node `DungeonFloors` (D2, `scripts/dungeon/floors/dungeon_floors.gd`) when that script exists, registered as the save section `dungeon` with the explicit order 45; the handlers reach it through `LootService.floors()`
  (`uid_of(area, cell)`, `is_done_cell(area, cell)`, `mark_done_cell(area, cell)`, `band_of(floor)`); LootService connects its `reset()` to `new_game_started` when the node has one;
* Fru Ugle's appraisal screen: on `game_event open_appraisal {npc}` it instantiates `scenes/ui/appraisal_ui.tscn` (DL7) ONCE under the first node of group `game_ui` and calls `open(npc)`; without the scene the event is ignored.

## Stubs (honest)

* No dungeon rules yet (DL5): `node_loot` and `appraise` answer `{ok = false, reason = &"no_rules"}`, `appraisal_quote` answers `{band: "", fee: 0}`; a dungeon container, drop, boss and spot run the built-in algorithm on the band's tables.
* `appraise()` and `open_appraisal()` always exist (stubs until DL5 / DL7): ask `appraisal_available()` (rules AND screen present), never `has_method`.
* No `DungeonFloors` node (D2) and no appraisal screen (DL7) in this tree: nothing is hosted, the event is ignored.
* The unique glimmer art is additive: in full daylight it is faint (it shines at dusk and in the dark forest).
