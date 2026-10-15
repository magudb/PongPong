# Devin deep-dive review — 2026-10-15 (branch `devin-review`, base `main` @ 863a583)

Scope: full read of `scripts/` (~25.5k lines GDScript) plus maps, Lua content, UI scenes, shaders, tests and
tooling. Harness verified green in this worktree: `run_playtest.sh --only=core,data` → 446 checks, 0 failed,
0 engine errors/warnings.

## Verdict

This is an unusually disciplined codebase: contract-documented headers, a linted signal vocabulary
(`event_bus.gd` + `core.signal_arity_lint`), an atomic save pipeline with an error-counting apply guard,
late-bound service seams (`Svc.static_call`) for unlanded packages, and data-driven maps with graceful
marker skipping. The findings below are therefore mostly *latent* — code that will activate bugs when the
pending waves (P06 player, P13 quest bindings, P14 NPCs, screens) land — plus dead code, a packaging
landmine, and a handful of perf notes.

---

## 1. Bugs / correctness

### 1.1 `pause_menu.gd` captures the mouse on resume — contract violation
`scripts/ui/pause_menu.gd:25` calls `Input.mouse_mode = Input.MOUSE_MODE_CAPTURED` in `_on_resume()`.
The GameManager header states the 2D game *never* captures the mouse, and `core.no_mouse_capture` enforces
it — but only over `scripts/autoload/`, so this slipped through. In a click-driven 2D game a captured
cursor disappears; resume breaks the UI. Also: the lint should cover `scripts/ui/` (and arguably all of
`scripts/`), not just autoloads.

### 1.2 The pause menu never pauses, and nothing opens it
`pause_menu._on_panel_toggled(&"pause")` only flips `visible`; nothing calls `push_modal`/`change_phase`.
And the only emitter of `ui_panel_toggled(&"pause", true)` is the dead `player_controller.gd`. So even
after a screen scene lands, Esc-pause won't pause. Same family: `shop_ui.gd:36,41` and
`save_load_ui.gd:37,142` drive `change_phase(PAUSED/PLAYING)` directly instead of `push_modal`/`pop_modal`
— which the GameManager header explicitly reserves for "legacy panels". Consequence: no `modal_changed`
emission, `is_modal_open()` stays false while a shop is open, and closing a nested panel (save menu over
pause) unpauses the game underneath.

### 1.3 `save_load_ui` duplicates the load flow, skipping its guards
`save_load_ui.gd:118-122` does `SaveManager.load_game(slot)` + `_close()` +
`change_scene_to_file("res://scenes/main/world.tscn")` instead of `SaveManager.load_and_enter(slot)`.
It misses the `ResourceLoader.exists(world_scene)` pre-check and `pop_all_modals()`. Also `_close()` never
emits `ui_panel_toggled(<id>, false)`, so peers see the panel as still open (the request signal is the
only close channel these screens share).

### 1.4 HUD never listens to `weather_changed`
`hud.gd:56-61` refreshes `weather_label` only inside `_on_season_changed` (reached via `day_started` and
`season_changed`). It works today only because weather is rolled once per day — but
`TimeManager.weather_duration_hours` (rolled 3–10 h, `time_manager.gd:204`) is never read anywhere: the
data already anticipates intra-day weather changes, and the moment one lands the HUD goes stale. Connect
`EventBus.weather_changed`.

### 1.5 HUD stats keys don't match the player contract
`hud.gd:63-69` reads `stats["health"]/["max_health"]`. The player contract is `half_hearts`/`max_half_hearts`,
and the bus has a dedicated `player_health_changed(half_hearts, max_half_hearts)` signal. Only the dead
`player_controller.gd` emits `player_stats_changed`; `PlayerStub2D` emits its own *local* `stats_changed`
that nobody forwards to the bus. When Player2D lands, the bars silently show stale values unless the
payload keys or the signal are reconciled.

### 1.6 AnimalHusbandry bypasses the EventBus contract
`animal_husbandry.gd` declares and emits its own `animal_added`/`animal_fed`/`animal_product_collected`/
`animal_bonded` signals. The contract signals `EventBus.animal_adopted`, `animal_fed`,
`animal_product_collected`, `building_built` (`event_bus.gd:40-43`) are **never emitted anywhere** — a quest
or UI bound to the bus cannot observe animal events, and `build_building()` emits nothing at all. Either
emit through the bus (keep the local signals for UI detail) or drop them from the contract.

### 1.7 `AnimalHusbandry._has_space_for` is vacuous without buildings
`animal_husbandry.gd:597`: `return current < capacity or capacity == 0`. With zero buildings of the required
type `capacity == 0`, so adoption is unlimited — `adopt_animal` then assigns `building_id = &""` and the
NOTIF_NO_SPACE path is unreachable until at least one building exists. If animals without housing are
intended, the capacity check is dead code; if not, this is `capacity > 0 and current < capacity`.

### 1.8 Broken warp target gives zero feedback
`data/maps/moerkeskoven.map:33` warps to `moerkeskoven_f1`, which isn't registered. `Warp2D` doesn't check
`WorldRoot2D.has_area(to_area)`; `travel()` refuses silently and `last_travel_error` is invisible to the
player. Walking into the gate does nothing, not even a whisper — contrast with `req_day` gates which do
whisper. Cheap fix: whisper a locked/unavailable key when `has_area` fails.

### 1.9 Faint during travel/sleep loses the rescue teleport
`world_2d.gd:690-699`: `_on_player_defeated` awaits 1.3 s, then `await travel(...)`. If `traveling` is
already true (mid-travel or mid-sleep sequence) `travel()` returns immediately — `revive()` still runs, so
the player revives *in place* rather than at the farm gate. Guard the sequence or queue the faint.

### 1.10 Quest objectives can't bind to events yet — shipped quests are uncompletable
`QuestManager` advances objectives only via `crop_harvested` (`harvest_<crop>`/`harvest_any`),
`resource_node_depleted` (`collect_<item>`), `lua_event` and quest-spot/manual calls. The `on=` binding
vocabulary the Lua quests already use is acknowledged pending (P13; `cast_data.gd:502` documents it).
Practical consequence today: `cookie_delivery`'s `collect_turnip` never advances on harvest (it emits
`harvest_turnip`), `deliver_to_baker` needs a `quest_spot` that no live marker creates, and no NPC offers
quests (`npc` handler missing). Expected per plan, but the gap between shipped content and runtime binding
is worth tracking explicitly.

### 1.11 Minor
- `character_select.gd:21` defaults `selected_skin = animal_rabbit`; `GameManager._default_skin_for(ANIMAL)`
  is `animal_fox` (`game_manager.gd:193`). Only affects a path that skips the select screen — reconcile.
- `audio_manager.gd:59-63`: "steal oldest" steals `_sfx_pool[0]` — the first slot, not the oldest. Rotate or
  track recency.
- `shop_ui.gd:_on_sell` lists `price` from `get_sell_price` but sells `amount` × unit without checking
  `QuantitySpin` against stock/owned amount — `sell_item` refuses over-amounts correctly, UX just reports
  nothing specific (last_refusal is set; surface it in the UI).
- `GameManager.day_end_hour()` allows up to 48 while the header promises `hour` stays 0..23 — either clamp
  to 24 or fix the contract text (`game_manager.gd:149-153`).
- `IsoArea.evaluate_when("flag:...")` polls at 4 Hz via `_process`; flags have no change signal. Consider a
  `flag_changed` event on `set_flag` to drop the poll — an EventBus addition, hence a contract change.

---

## 2. Performance

The hot paths are mostly already well-tuned (cached physics query in the player stub, spatial-hash
`LevelRegistry.level_at`, move-gated `LevelTracker`, one-sheet-per-frame threaded warm-up with a documented
headless race workaround, lazy+cached placeholder art with a paint budget). What remains:

- **`IsoArea.resolve_handler` rebuilds the marker registry per marker occurrence** (`iso_area.gd:1135` →
  `marker_registry()` :133). Each call re-merges builtins + `LAZY_HANDLERS` + a `GameData.cfg` walk of
  `marker_handlers`. With ~140 marker cells in hyggebyen it's ~140 redundant registry builds per area load.
  Cheap (build-time only), but hoisting `marker_registry()` into `setup()` is free.
- **`place_prop` calls `_apply_night()` per prop during a night build** (`iso_area.gd:964-965`): O(props ×
  (glows+lights)) — quadratic-ish on a map that is built while dark. Ditto `_rebuild_skirts()` rescans the
  whole grid per `set_growth_stage` call — fine at current sizes, flagged for when maps grow.
- **`IsoArea._on_game_event` → `refresh_when()`** re-evaluates every `when=` record on *every* `game_event`
  emission (`iso_area.gd:1487`). `game_event` is the free-for-all channel (midnight_passed, furniture,
  hygge, …). Fine at current counts; consider filtering to records whose `when` kind matches the event.
- **`AudioManager._find_stream`** probes up to 5 `ResourceLoader.exists` per `play_sfx`/`play_voice` call
  (`audio_manager.gd:125-138`). Add an id→path memo (cleared on reload) so repeated sfx don't hit the
  filesystem check.
- **`EconomyManager._gained`** emits `player_inventory_changed` (rebuilding the inventory dict) per
  `add_item` — a loot burst of N items is N dict rebuilds + N signal emissions + N toasts. Consider a
  batched/coalesced emission for multi-item grants.
- **`SaveManager.describe_slots`/`get_save_summary`** parse + validate all 7 files per call. On-demand only
  — fine, just don't call it per-frame from a slot-list UI rebuild.
- **Ground TileMapLayer has `y_sort_enabled = true`** (`iso_area.gd:232`). Y-sorting the flat ground layer
  buys nothing visually (tiles don't overlap actors) but adds per-frame sort work; worth measuring whether
  disabling it on `ground` (keeping it on `objects`/`walls`) helps on large maps.
- **Water = 4 stacked TileMapLayers toggled by visibility** — reasonable memory-for-CPU trade, but each
  water cell is painted 4× at build (`iso_area.gd:522-528`). Alternative: one layer, swap `atlas_coords`
  via `set_cell` — only worth it if maps get water-heavy.
- **`IsoChibiSprite2D._sync_sprite` lazy `load()`** hitches on first un-warmed clip play (a ~12 MB sheet).
  `warm_clips` covers the player + in-view NPCs behind fades — actors spawned *without* a travel fade (e.g.
  a shop screen NPC, a summon) will still hitch. Acceptable; keep in mind for future spawn paths.
- **Lua interpreter**: function bodies compile lazily and cache ASTs (`lua_runtime.gd:563`) — good. The
  subset intentionally lacks loops; a hostile/weird script can't hang the game. `get_config` splits/walks
  per call but `GameManager._config_cache` memoizes the hot keys — fine.
- **Per-frame scan**: ~19 `_process`/`_physics_process` functions total across scripts/ — all reviewed are
  either allocation-free, gated (`IsoArea` only processes with water/flag-whens), or early-outed. No
  `get_nodes_in_group` inside per-frame code (the one usage in `preview_citizens.hud_present` is polled at
  `HUD_POLL_S`).

---

## 3. Architecture

### Strengths worth keeping
- **Contract-driven layering**: EventBus arity lint, modal-stack phase model, save-section registry with
  orders, JSON-safety rules, `Svc`/`GameData`/`LuaData` seams. The header docs are executable specifications
  — keep them in sync (several already are enforced by tests).
- **Save system** is the standout: atomic write-verify-rename, .bak rollover only for valid payloads,
  validate→snapshot→apply-with-error-guard→rollback, versioned migrations, legacy-def carry-over.
- **IsoArea/LevelRegistry/LevelTracker** is a clean data-driven stack: ASCII maps → markers → lazy handler
  registry; levels → ranked collision bits → per-position `level_at`; tracker restores actors on detach so
  parked areas can't leak state.

### Concerns
1. **Two parallel world stacks.** The live stack is `world2d/` + `isometric/` + `traetoppen/` (2D iso).
   Dead-or-dying 3D code remains beside it and still compiles:
   `scripts/player/player_controller.gd` + `scenes/player/player.tscn`, `scripts/npc/{npc_agent,npc_base,
   npc_spawner}.gd` + `scenes/npc/npc.tscn`, `scripts/world/{enemy,dark_forest,dark_forest_zone,
   crystal_cave,mushroom_grove,resource_node_interactable}.gd` + `scenes/forest/dark_forest.tscn`,
   `scripts/farm/{farm_system,farm_animal,building_placer,farm_plot_interactable}.gd` (all `Node3D`-family).
   ~2.5k+ lines that rot silently and muddy searches (they also *consume* contract signals, which is how
   §1.5/§1.6 look wired when they aren't). Recommend: move to `legacy/` (already `.gdignore`d) or delete.
2. **UI screens are written but none ship as .tscn** — `scenes/ui/` has only `game_ui.tscn` +
   `character_select.tscn`. All of `SCREEN_ORDER` resolves to nothing, so `hud.gd`, `shop_ui.gd`,
   `pause_menu.gd`, `save_load_ui.gd`, `inventory_ui.gd`… never run — which is exactly why their contract
   violations (§1.1–1.5) went unnoticed. When the scenes land they land *with* those bugs.
3. **Export packaging landmine.** `.map`, `.lua` are non-resource files with no `.import` keep files (the
   CSVs have them). On export they'd be dropped from the PCK (default `filters_to_export_non_resources`
   covers `*.json`/`*.cfg` only) — the game would boot to an empty world: no maps, no Lua, no config.
   `export_presets.cfg` is gitignored, so no preset exists yet. When the first preset lands it must add
   `*.lua,*.map` (and the loose `data/**/*.json` are safe by default) — or adopt keep-imports for them like
   localization did.
4. **Quest definitions stored inside `quest_flags` as `def_<id>`** (`quest_manager.gd:80`) — the registry
   doubles as flag store; SaveManager strips them on write and re-injects on apply (`_legacy_quest_defs`).
   Works, documented, but fragile: a Lua `set_flag("def_x")` collides with the namespace, and the dance
   exists purely to survive `from_dict`'s wholesale flag replace. A separate `quest_defs` dict (the P13
   direction) removes the special-casing.
5. **Autoload count (11) is fine**, but `ShopSystem` and `AnimalHusbandry` live under `scripts/economy/` /
   `scripts/farm/` while all others live under `scripts/autoload/` — cosmetic, but consistent placement
   aids discovery.
6. **`weather_duration_hours` is written, never read** — dead state implying a feature (intra-day weather
   changes) that doesn't exist; either wire it or remove.

---

## 4. Suggested order of work

1. §1.1–1.3 (modal contract + mouse capture) — small, prevents a whole class of UI bugs before the screens
   land. Extend `no_mouse_capture` lint beyond `scripts/autoload`.
2. §1.6 + §1.4/§1.5 (signal contract gaps) — cheap; keeps the bus honest before more content binds to it.
3. §1.7 (animal capacity) — one-line fix; confirm intended rule first.
4. §1.8/§1.9 (warp feedback, faint-during-travel) — small robustness fixes.
5. §3.1 (retire 3D legacy) — pure hygiene, unblocks honest greps.
6. §3.3 (export filters) — zero urgency, but write it into the export preset the day one is added; a
   `keep`-style `.import` convention already exists to copy.
7. Perf notes — all minor; re-measure only if maps grow or NPC counts climb into the dozens.

## Method note
Reviewed on `../PongPong-worktrees/devin-review` (branch `devin-review`, == main @ 863a583 + this file).
Verified: `./tests/run_playtest.sh --no-import --only=core,data --character=animal` → PASS (446 checks).

---

## Fix round (same branch, follow-up commit)

What was fixed and where the semantics landed:

- **Modal contract, all screens** (`pause_menu`, `save_load_ui`, `shop_ui`, `inventory_ui`, `quest_journal`,
  `animal_care_ui`, `build_menu_ui`): open pushes `GameManager.push_modal(<name>)`, close pops it and answers
  `ui_panel_toggled(<toggle>, false)`; Esc closes the TOP modal only (`top_modal()` compare) and opens pause
  only when nothing is modal. Modal names follow `tests/lib/ui_screens.json` (`save_load` for the slot
  browser, not the `save_menu`/`load_menu` toggle names). `pause_menu._on_quit` pops all modals first — the
  tree would stay paused on the title screen otherwise. The `MOUSE_MODE_CAPTURED` on resume is gone.
- **`save_load_ui` load** now calls `SaveManager.load_and_enter` (scene existence check + pop_all_modals +
  phase PLAYING); a failed load keeps the browser open.
- **`hud.gd`** connects `weather_changed` and `player_health_changed`; `_on_stats_changed` reads the
  half-hearts keys first (the stats dict the stub now emits carries both).
- **`player_stub_2d`** forwards its `stats_changed` onto `player_health_changed` + `player_stats_changed`
  (HUD live today, not just when Player2D lands).
- **`animal_husbandry`** emits the contract signals (`animal_adopted`, `animal_fed`,
  `animal_product_collected`, `building_built`) next to its local ones; `_has_space_for` is now
  `capacity > 0 and current < capacity` (every species needs a building: a missing one is NO SPACE, not
  free range).
- **`warp_2d`/`world_2d`**: the warp keeps firing `area_change_requested` for an unknown target (the request
  contract — `maps_iso.door_triggers_can_be_entered` probes exactly this); the refusal whisper moved into
  `travel()`, which also emits `WORLD_WARP_LOCKED` when `has_area` fails. Fainting now waits for a running
  travel/sleep sequence before the rescue teleport (600-frame guard).
- **`game_manager.day_end_hour()`** clamps at 24 (the 0..23 hour contract).
- **`character_select.gd`** reads the live skins from `characters.lua` (`CharacterCatalog.skin_ids` filtered
  by race + `retired`), default first — the old table offered 7 retired ids and 2 that never existed
  (`animal_bear`, `animal_owl`). `review_regressions` now picks `fairy_birk` (index 1 of the live list).
- **`quest_manager`** has a real `quest_defs` dictionary (Lua defs, never saved, survive reset/load);
  `quest_flags` is a clean flag store. `save_manager`'s `_legacy_quest_defs` carry-over is deleted (its own
  comment anticipated this); `def_*` keys in old saves are still stripped on read.
- **Perf** (`iso_area.gd`): `marker_registry()` is memoised (`clear_handler_cache` + a LuaRuntime reload
  clear it — late-bound `load().callv` so the autoload needs no class cache); `place_prop` applies the night
  factor to the entries it just made instead of re-walking every glow/light; `ground.y_sort_enabled` off
  (flat diamonds never interleave); `_on_game_event` early-outs when no `when=` records exist.
  `audio_manager.gd`: SFX steal is a real FIFO (round-robin cursor), `_find_stream` memoises resolved paths.
- **Dead 3D code deleted**: `scripts/player/`, `scripts/npc/`, `scripts/farm/` (3D-era files),
  `scripts/world/`, `scenes/player|npc|forest` — all preserved in `legacy/package_3d/`.
- **Export**: `keep` `.import` stubs for all `lua/**/*.lua` + `data/maps/*.map` (79 files), and
  `tools/import/write_import_stubs.py` audits them (`--check` fails on a missing stub; `--only keep`
  rewrites). A default-include `.map.import` naming a missing `.translation` is replaced rather than
  extended.
- `PINNED` in `city_levels.gd` updated for the legitimately edited `iso_area.gd` / `world_2d.gd`.

**Not fixed, on purpose:** `weather_duration_hours` (save-schema field held for the weather-duration wave —
registered flag to add at a boundary), `flag_changed` signal (no new signals without a package —
signal_contract), `evaluate_when` flag-vs-colon slice (flags with `:` are not a real input today), the
`collect_turnip`-style quest-binding gap (P13's owner), `.ttf`/`.json` export stubs (resources and already
default-filtered), and every missing marker handler / lazy script (pending waves, by design).

Verified: `run_playtest.sh --only=core,data,save,economy,review_regressions,loc,cast_data` (1193 checks),
`area,content_features,characters,cast_data,ghost,ghost_data` (523), `city_levels,maps_iso,maps_farm` (178),
`ui_foundation,ui_audit,ui_audit_blind,ui_audit_pins,rarity,art_home` (1015+) — all PASS, 0 engine
errors/warnings.

---

## Fix round 2 (branch devin-review, on top of the m1b merge)

The deferred items, revisited:

- **`flag_changed` landed** as a contract signal (`flag: StringName, value: Variant`; `REVIEW_SIGNALS` in
  `core.gd`). `GameManager.set_flag`/`clear_flag`/`from_dict` and the new-game reset emit it; same-value
  writes don't fire. `IsoArea` re-evaluates its `flag:` whens on the signal — the 4 Hz `_process` poll
  (`FLAG_POLL_PERIOD`) is gone. Lua `api.set_flag` routes through `GameManager.set_flag`, so Lua writes are
  covered.
- **`weather_duration_hours` removed** — vestigial intra-day-weather state (written, never read; weather is
  rolled once per day). Old saves keep loading (the key is simply ignored).
- **`collect_<item>` binds to `item_gained`** — harvest / purchase / gift all route through
  `EconomyManager.add_item`, so `cookie_delivery`'s `collect_turnip` is completable now. The
  `resource_node_depleted` binding stays (its test asserts it; nothing emits it yet) with a comment warning
  the loot wave not to double-count.
- **Modal contract exercised headless**: `review_regressions` builds each shipped screen script on a bare
  Control carrying its `%`-named nodes and drives real Esc key events: open pushes the modal (names per
  `ui_screens.json`), close pops, Esc closes only the top modal, pause opens only when nothing is modal,
  the mouse is never captured. Surfaced and fixed a real bug: `build_menu_ui` wrote `ItemList.selected`
  (no such property — `select(0)` now).
- **Mouse-capture lint widened**: `area.gd`'s `no_mouse_capture` check now covers `scripts/ui/` too — the
  `pause_menu` capture it would have caught lived outside `scripts/autoload`.
- **Still not done (package work, not bugs):** the screens' real `.tscn` scenes are P16/P17 deliverables
  with baseline-pinned pixel audits — hand-building them would break `compare_guide`, so they stay unshipped
  and `SKIP`; the marker handlers and lazy scripts (npc P14, doors/posts T-director, runestone D2, whisper
  P19, forest_dress V8, Player2D P06) are pending waves by design.
- **Verification:** full headless suite green (~3100 checks over 25 sections, 0 engine errors/warnings) and
  `run_windowed.sh` run end-to-end: all windowed sections pass (`area`, `maps_*`, `city_*`, `characters`,
  `clock26`, `ui_*`, `art_*`) except five PRE-EXISTING art-content failures (`art_city.tileable_trunk_seam`,
  `bridge_line2d_orientation`, `art_environment.forest_*` readability) that fail identically on the clean
  `review-fixes-4` checkout of the same commit — V8-era art tuning, not from this change set.
