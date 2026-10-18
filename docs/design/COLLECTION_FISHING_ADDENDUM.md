# TRÆTOPPEN - Collection and fishing addendum: Samlerbog and Fiskeri

Status: **proposed** addendum (2026-10-18), awaiting the owner's answers in `COLLECTION_FISHING_OPEN_QUESTIONS.md`. Companion: `collection_fishing_workpackages.json` (one package per independently buildable unit). Request (user, 2026-10-18): "we should also look into: Optional collection screen and fishing", the last open roadmap line on `origin/main` (`README.md:228`, `- [ ] Optional collection screen and fishing`).
Where this file disagrees with `PLAN_2D.md` (fishing CUT/STUB, `:430,694,1297,1695`), `DUNGEON_V2_ADDENDUM.md` (DX25 / CR23, `:783,868`) or `TOWNS_FARM_SOCIAL_ADDENDUM.md` (DT7 / DT38, `:44,971,1033`) about fishing, **this file wins once the owner answers Q1 with yes**. It follows `PLAN_2D_FEATURES.md` §2.8 / F9 (`:362-364,785-799`) and `UI_NAVIGATION.md` S27 (`:563-564`) for the Samlerbog, with the deviations named in §4.9.
Repo read: worktree `/Users/magnusudbjorg/Documents/projects/PongPong-worktrees/collection-fishing`, HEAD `61cd5183`. It is **9 commits behind `origin/main` (`43aa4e81`)**, which already contains PR #1 (release pipeline + area map); `61cd5183` is a content duplicate of `origin/main`'s `4d72293a`. Line numbers below are of HEAD unless marked `origin/main:`. **Implementation starts on a fresh branch from `origin/main`**, not on this worktree. Nothing was edited and Godot was not launched while this was written.

**Names.** *Fiskeri* = fishing. *Samlerbog* = the collection book (screen id `samlerbog`, autoload `CollectionLog`, package F9 in the older plans). *Gårddammen* (farm pond), *Byens dam* (Hyggebyen pond), *Månesøen* (the Moon pond: the Mørkeskoven hub bog plus the generated-floor ponds). Money is *guldagern*.

---

## 0. Summary

1. **Two features, one release line, no hard dependency.** Fishing ships without the Samlerbog and the Samlerbog ships without fishing. When both exist, fish become a sixth Samlerbog page (*Fisk*) through one event contract (§5). Neither adds an input action, an EventBus signal, a `SCREEN_ORDER` id or a save-order key: every hook they need is already reserved in the repo (§1.2).
2. **Fishing ("Proppen dykker"): no fail state.** Have a rod in the backpack, face water, press **E**. Wait for the bobber to dip; press again to land it at once, or do nothing and the fish hooks itself on the second nibble. Every cast lands a fish. No bait, one rod, no minigame screen.
3. **Three waters, 13 fish, daily pools.** Gårddammen (8 a day), Byens dam (6), Månesøen (6, shared by the hub bog and every generated-floor pond). Seasons, night and rain change the roster; two keepsakes (*Gamle Gustav*, unique; *Månefisken*, legendary) have counter-based pity so a child always gets them in the end.
4. **Fishing's uses are data-only edits:** shipping bin, the seed shop (already buys every sellable item), one backpack recipe (*Fiskefrikadeller*), cat/fox feed, and gift tastes for the five NPCs who already "fish" on the pier.
5. **Samlerbog: a gentle, read-only book of everything you ever found.** Pages Møbler 130, Tøj 76, Smykker 20, Våben 24, Skatte 32 (282 entries today), plus Fisk 13 once fishing exists. Unknown entries are dashed silhouettes that already exist (`RaritySlot.unknown`). No milestones, titles or perks; three gold stamps per page (25 / 50 / 100 %).
6. **Key C or the pause row "Samlerbog"** (both already wired; the row appears as soon as `scenes/ui/samlerbog.tscn` exists). Full keyboard and gamepad play, the gold focus ring on every tile including silhouettes (a 3-line `RaritySlot` fix), Esc / B closes.
7. **Placeholder-first art.** The Samlerbog needs no new art at all. Fishing needs 14 icons (13 fish + fish cakes); there is no painted fish cell to recolour, so the strict art-coverage gate needs either the painted sheet or a temporary listed exemption (owner question Q2).
8. **MVP size:** fishing about 5 dev days, Samlerbog about 4-5 dev days, the bridge and docs about 1 day. Each MVP is split into 3-4 packages that can be built in parallel (§6, json).
9. **Biggest risks:** Player2D input routing for fishing (the state machine refuses non-FREE input), the strict art-coverage gate, toast order in the existing `ui_nav` test, and merge hotspots in `tools/loc/key_owners.json` / `project.godot` after PR #1.

---

## 1. Current state (what exists and what is broken today)

### 1.1 Fishing: a deliberate stub in three places

| What | Where | State |
|---|---|---|
| Rod item | `lua/items/tools.lua:127-138` (`tool_type="fishing"`, `stamina_cost=1.0`, `buy_price=120`, `sell_price=40`) | complete |
| Rod in shop | `lua/shops/seed_shop.lua:42` (`stock = 2, restock = 1`) | sold; not in the starter kit (`lua/data/starter_kit.lua:9-19`) |
| Rod art | `assets/icons/items/fishing_rod.webp`; held sprite in `assets/held_equipment/manifest.json` (packer row `tools/art/drawn/held_equipment.py:33`) | complete, 8 views |
| Using the rod | `scripts/world2d/player_2d.gd:341-343` | whispers `WHISPER_FISHING_CLOSED` (`localization/farm.csv:8`, "Fiskene får ro lidt endnu.") and returns false before any energy is spent |
| Rod description | `localization/economy.csv:22` | "Fiskevandet er ikke åbnet endnu, men stangen er klar." |
| Moon pond | `scripts/forest_look/soft_ground.gd:52-82` builds a `MoonPond` trigger; `:98-103` whispers `LOOK_MOONPOND_FISHING` once per floor | copy `localization/look.csv:3` "… Fiskeri er ikke åbnet endnu."; pinned by key only (`tests/sections/forest_look.gd:34,98`) |
| NPC `fish` act | allowed in `scripts/towns/towns_validate.gd:7`; post `pond_dock act=fish cap=2` (`data/maps/hyggebyen.map:86`, placed `:206`) | cosmetic: no character has a `fish` clip, `npc_2d.gd:313-318` falls back to `idle` |
| Pier fishers | Pippin `lua/routines/core/pippin_boegeknop.lua:14`, penguin postman `lua/routines/core/penguin_postman.lua:26`, Kvak `lua/routines/ext/innkeeper_kvak.lua:19,21`, Bodil `lua/routines/ext/bodil.lua:16`, Rasmus `lua/routines/ext/rasmus.lua:30` | rain moves 08:00-19:00 `fish` posts to shelter (`scripts/towns/routines.gd:24`, asserted `tests/sections/towns_data.gd:165`) |
| Fish items, data, state | none. The old dangling `fish` feed was removed (`docs/review/game-review-2026-10-18.md:59-73`); the cat's favourite is `milk` (`lua/config/husbandry.lua:73`), the fox's `cookie` (`:148`) | missing |
| Lore | Dyne's Monday story: the moon lost a button that became a fish with light in its belly (`localization/ghostfamily.csv:122`); the style guide sketches "Månesøen … Fiskeri om natten" (`docs/Trætoppen Style Guide Review/Trætoppen Miljøer v2.dc.html:254`) | ready to use |

Why it is closed: "no budget for a mini-game" (`docs/design/PLAN_2D.md:1695`); the Moon pond stayed decor (DX25 `DUNGEON_V2_ADDENDUM.md:783`, CR23 `:868`); the farm pond stayed decoration (DT7 `TOWNS_FARM_SOCIAL_ADDENDUM.md:971`, DT38 `:44,1033`, the latter "decided by the editor on the user's behalf" and a data knob).

Water a player can stand next to: farm 47 `~` cells at x18-26, y34-40 (`data/maps/farm.map`, `@ground` at `:80`); Hyggebyen 15 `~` cells at x4-7, y31-36 with a deck pier x5-8, y34 (`data/maps/hyggebyen.map`, `@ground` at `:130`); Mørkeskoven hub 35 bog `~` cells at x11-19, y9-15 (`data/maps/moerkeskoven.map`, `@ground` at `:41`); generated-floor ponds on floors 1, 2, 3, 5, 6, 7, 9 (`lua/config/dungeon.lua:108,132,159,207,233,259,314`). `~` is unwalkable for every race (`scripts/world2d/iso_area.gd:365-370`), so shore fishing needs no race special case.

### 1.2 Samlerbog: wired in, but no screen

Everything except the files is already reserved:

| Hook | Where |
|---|---|
| Pause row `["samlerbog","CollectionButton","PAUSE_COLLECTION"]`, skipped while the screen is null | `scripts/ui/pause_menu.gd:41-43`; copy `localization/menus.csv:29` "Samlerbog" |
| Screen slot `samlerbog` in `SCREEN_ORDER`, loaded only if the scene exists | `scripts/ui/game_ui.gd:37,98` |
| Input action `collection` = C (physical key 67), nothing handles it | `project.godot:269-272`; `tests/tools/input_contract.gd:56,69`; spec `docs/design/UI_NAVIGATION.md:168` |
| Save order `"collection": 50` | `scripts/autoload/save_manager.gd:78`, pinned by `tests/sections/save.gd:710-714` |
| Signal `item_discovered(item_id, rarity, category)`, never emitted | `scripts/autoload/event_bus.gd:109-110` |
| Autoload name `CollectionLog` → `scripts/collection/collection_log.gd` | `tools/features/add_autoload.py:40`, `tests/tools/check_project.gd:42`, `tests/lib/features/fresh.gd:13` |
| Unknown-tile silhouette | `scripts/ui/components/rarity_slot.gd:7-9,60` |
| UI-audit registry row (fixture `samlerbog`, `esc_depth 1`) | `tests/lib/ui_screens.json:829` onward; `tests/sections/ui_audit.gd:325` |
| Loc family `samlerbog.csv` / prefix `COLLECT_` | `tools/loc/key_owners.json:343-349`; expected by `tests/sections/loc.gd:495,522` |
| Spec | `PLAN_2D_FEATURES.md:362-364,785-799`; `features_workpackages.json:1171-1201`; S27 `UI_NAVIGATION.md:563-564`; Q4 default "out" `:1203` |

Missing: `scripts/collection/`, `scenes/ui/samlerbog.tscn`, `localization/samlerbog.csv`, `lua/config/samlerbog.lua`, `tests/sections/collection.gd`. Pressing C does nothing today.

An old prototype exists outside the repo (`/Users/magnusudbjorg/Documents/projects/.pongpong-build/lift/features/FD/proto/scripts/collection/collection_log.gd`, 193 lines). Lifted as-is it breaks: it reads `d.wardrobe.slot` (the live schema has a top-level `slot`, `lua/items/clothing.lua:12`), emits an undeclared `collection_milestone` (proto `:167`), reads a nonexistent `config.collections` (proto `:28`), registers without order 50 (proto `:18`) and backfills only furniture and wardrobe (proto `:110-116`).

### 1.3 Documentation state (correcting the task brief)

* The roadmap line exists only on `origin/main` (`README.md:228`); this worktree's README has the older roadmap.
* **Neither** this worktree's nor `origin/main`'s `docs/PLAYING.md` mentions the Samlerbog or the C key any more (grep for "samler", "collect", "fisk"); the review finding GM-09 (`docs/review/game-mechanics-2026-10-17.md:83-87`) was fixed on the documentation side. The pause-menu key `PAUSE_COLLECTION` exists, but the row is hidden.
* Stale: `docs/review/game-review-2026-10-18.md:34` cites the rod stub at `player_2d.gd:308` (now `:341`); `tools/towns/authoring/model.py:206` places the dock at (10,34), the map marker is at (5,34).

### 1.4 Gaps found on the way (not fixed here)

* `use_tool` / `attack` have **no keyboard key** (LMB and pad X only, `project.godot:152-162`). That breaks full-keyboard play for every tool, which is why fishing starts on **E** (§3.4). A separate input change is recommended (Q14).
* Tools play no sound (`scripts/audio/audio_director.gd:14-22`; `tool_used` has no listener).
* In ortho areas `use_tool` is matched before `attack` (`player_2d.gd:194-200`), so any non-weapon on the selected hotbar slot turns LMB into "use" instead of "swing".

---

## 2. How the designs were chosen

Three designs were drafted and scored per feature (1-10 each; for cost and art, higher = cheaper and safer), then the winner was critiqued against the code and corrected.

| Fishing | D1 "Proppen dykker" (minimal, no fail) | D2 depth-first (bait, tiers, sizes) | D3 "Stille vand" (story-woven) |
|---|---|---|---|
| Fun / fit / accessibility | 6 / 8 / **10** | 7 / 5 / 6 | 8 / 9 / 6 |
| Cost-risk / art / longevity | **8** / 7 / 5 | 3 / 2 / 9 | 4 / 4 / 7 |
| **Total of 60** | **44** | 32 | 38 |

Kept from D3: Pippin as mentor, dock-NPC tastes, Dyne's legend, the Moon-pond copy. From D2: the "stirring" hint, size records later, lazy daily reset. Cut: bait, rod tiers, `TOOL_SLOTS`, a fishing assist toggle, hold-to-reel, a catch-card modal, keepsake furniture, a separate Fiskebog.

| Samlerbog | A cozy-minimal | B deep (stars, levels, records) | C woven-in (patrons, Fru Ugle) |
|---|---|---|---|
| Fun / fit / accessibility | 6 / **9** / **9** | 8 / 5 / 6 | 8 / 7 / 8 |
| Cost-risk / art / longevity | **8** / **10** / 5 | 3 / 4 / 9 | 5 / 7 / 8 |
| **Total of 60** | **47** | 35 | 43 |

Kept from B: day `0` for backfilled entries, one welcome-back toast, fish records, a reward knob. From C: Fru Ugle as keeper (flavour), "Bogen husker alt …", the explicit Skatte rule; daily tip and shop badge in P2. Cut: stars, season bits, book levels, hint gating, the "Set" state, 100 % reward items, patron scenes in the MVP.

---

## 3. Fishing design: "Proppen dykker"

### 3.1 Rules in one breath

Rod in the backpack (not necessarily on the hotbar), stand on any walkable cell facing a `~` cell, press **E** / Enter / pad **A**. The bobber lands, bobs, dips. Press in the 1.5 s window and the fish comes at once; miss it and it nibbles again and hooks itself. Energy is spent only on a catch. Moving, opening any modal, travelling or taking damage reels in empty at no cost.

Why the backpack and not the hotbar: the hotbar is full from day 1 (9 starter entries for 8 slots, `scripts/autoload/economy_manager.gd:53-56`, `scripts/world2d/hotbar.gd:5,37-47`), only placeables request a slot (`economy_manager.gd:682`), so a bought rod never reaches the bar, and the forest HUD has no hotbar at all (`scripts/ui/game_ui.gd:43,155-166`).

### 3.2 Where

Fishing is allowed when `area.map.ground_at(target_cell()) == "~"` (`iso_area.gd:365-370`; `target_cell` at `scripts/world2d/player_body_2d.gd:227-228`). There is **no `fishing_spot` marker**, so CR23 (`DUNGEON_V2_ADDENDUM.md:868`) still holds in spirit.

| water id | Danish name | areas | catches per day |
|---|---|---|---|
| `dam` | Gårddammen | farm | 8 |
| `byens_dam` | Byens dam | hyggebyen (pier and every shore cell, e.g. (4,31), (7,31)) | 6 |
| `maanesoe` | Månesøen (`LOOK_MOON_POND_NAME`, `localization/look.csv:5`) | Mørkeskoven hub bog **and** every generated-floor pond, one shared pool | 6 |

* Generated floors are recognised with `DungeonFloors.floor_of(area) > 0` (`scripts/dungeon/floors/dungeon_floors.gd:35-36`).
* **Daily pools reset lazily:** if flag `fish_day` ≠ `GameManager.total_day()` (`scripts/autoload/game_manager.gd:514`) every pool is full. Only landed fish count.
* **Talking wins over fishing:** the fishing branch applies only when `nearest_interactable()` is null, so Pippin on the pier stays talkable (`player_body_2d.gd:286-289`).
* **Races:** animal heroes get their 0.75 energy discount (`lua/config/race_perks.lua:27`; `player_2d.gd:344`). A flying fairy gets the whisper `FISH_LAND`. Ghost and halfling fish from shore; nobody can walk on water.

### 3.3 When

* Open **06:00-02:00 in every season**; winter is flavoured as ice fishing with no new art.
* **Night** = `TimeManager.is_night()` (20-05, `scripts/autoload/time_manager.gd:99-102`) opens Ål and Månefisken.
* **Rain** = `is_raining()`, true only for `regn` (`time_manager.gd:141-142`); winter has no rain (`lua/config/game_balance.lua:95-98`). Rain doubles Suder and Guldkarusse, and moves the NPC fishers to shelter, so rainy days give the child the pier.
* **The forest clock is frozen** in ortho areas (`scripts/world2d/world_2d.gd:463-464`; `time_manager.gd:65-67`): entering Mørkeskoven after 20:00 keeps it night at Månesøen for the whole trip. The Skovlift runs at night (`look.csv:2`). The hub bog is Månesøen, so the legendary never requires diving floors.

### 3.4 Controls and input routing (no new input action)

| Step | Keyboard | Mouse | Gamepad |
|---|---|---|---|
| Cast / hook | **E** or **Enter** (`interact`, `project.godot:118`), rod in the backpack | LMB (`use_tool`) with the rod selected, farm and town only | **A** (`interact`); **X** (`use_tool`) with the rod selected, not in ortho areas |
| Stop | any movement key | – | stick / D-pad |

* In ortho areas fishing starts **only with E / A**; `use_tool` keeps its weapon meaning there.
* `try_interact` and `use_selected` refuse when the state is not FREE (`player_2d.gd:324-325,331-332`), so Player2D routes presses: `_unhandled_input` checks `if _fishing != null` **before** the `interact` / `use_tool` branches (`:194-198`), calls `_fishing.press()` and returns. The session node never reads input itself.
* `S.USING` ends by itself when `_tool_time` reaches 0 (`:241-245`) and still allows 0.35× walking and turning (`:261,271-274`). Player2D keeps `_tool_time` above 0 while `_fishing` is live, and **any non-zero movement vector cancels** the session.
* `try_interact` gets the fishing branch before the `is_flying` refusal, so a flying fairy hears `FISH_LAND` instead of nothing.

**Prompt** (`Player2D.interaction_text`, `player_2d.gd:318-322`): `FISH_PROMPT` "Fisk" only when FREE, not flying, facing `~`, rod owned, no interactable, pool not empty and stamina ≥ cost. Otherwise no fishing prompt. The prompt pill always adds the E/A key cap (`scripts/ui/components/prompt_pill.gd:4-6`), so a prompt that leads to a refusal would mislead; refusals are whispers on E instead.

### 3.5 Timeline (`FishingSession2D`, numbers in `lua/config/fishing.lua`)

1. **CAST 0.5 s.** State `S.USING`, `_using_item = &"fishing_rod"` so the rod is drawn even in ortho areas, where the weapon is otherwise drawn (`player_2d.gd:430-439`); `visual.play_action(&"interact")`; a code-drawn bobber arcs onto the water cell in the guide palette (cream / honey, ink outline, **no red**: rule R4 in the header of `tests/sections/ui_audit.gd`); `AudioManager.play_sfx("bath_splash", -12)` (`scripts/autoload/audio_manager.gd:78`).
2. **WAIT 1.5-4.0 s.** The bobber bobs. An early press only makes it wiggle.
3. **BITE, window 1.5 s.** Three redundant, colour-free cues: motion (the bobber dips and its own code-drawn ripple expands), shape (a "!" bubble over the hero, a world `Node2D`, never focusable) and sound (`bath_splash` at -6 dB). `assist_reduce_flash` (read through `DungeonRun.assist(...)`, as `scripts/ui/dungeon/loot_reveal.gd:79,86` does) draws the ripple as an outline only. **Not** `TelegraphRing2D` / `telegraph_tick`: those are the enemy-attack warning (`scripts/world2d/enemy_2d.gd:240-252`), drawn additive (`telegraph_ring_2d.gd:16-20`), and would teach "danger".
4. **Press in the window** → catch at once. **Miss** → a new nibble after 1.0-2.0 s; on bite 2 the fish **hooks itself** (`FISH_SELF_HOOK`). Worst case with no input ≈ 9 s.
5. **REEL 0.6 s.** The fish arcs to the hero (item icon or initial badge).
6. **CATCH.** The fish was already rolled at cast time. `EconomyManager.add_item` posts its own item toast (`economy_manager.gd:849-850`) and `rare_item_found` for rank ≥ 3 (`:846-847`); in Mørkeskoven `loot_reveal` then shows automatically (it is created only by `scripts/ui/forest_hud.gd:142`). Spend `stamina_cost` 1.0 × race multiplier through `_spend_stamina` (`player_2d.gd:406-408`). One `GameManager.set_flags` call (`game_manager.gd:371-390`). Emit `game_event fish_caught` and `tool_used` (`player_2d.gd:403`). Whisper `FISH_LEFT_FMT`, or `FISH_LAST_TODAY` when the pool hits 0.
7. **Cancel** (movement, `EventBus.modal_changed` `event_bus.gd:34`, `area_changed`, `Player2D.damaged` `player_2d.gd:9`) before the catch → `FISH_REEL_IN`; energy, pool and inventory unchanged.

**Refusals, all before the cast, nothing spent:** flying `FISH_LAND`; pool empty `FISH_POOL_EMPTY`; stamina < cost `UI_TIRED` (the stamina check moves before the cast, `player_2d.gd:344-347`); bag full: the fish is rolled only among fish for which `can_add_item` is true (`economy_manager.gd:264-273`), and only if none fits is `FISH_BAG_FULL` whispered. A due keepsake that does not fit is skipped and keeps its pity.

**First-time tutorial** (flag `fish_tutorial`): `FISH_TUTORIAL_WAIT` at the first cast, `FISH_TUTORIAL_BITE` at the first bite. A whisper replaces the previous one (`scripts/ui/components/whisper_line.gd:4`), so `FISH_STIR` is never sent in the same second as a tutorial whisper.

### 3.6 Roster: 13 fish, category `fish`

Weights come from `Rarity.find_weight` (`scripts/data/rarity.gd:115-116`; `lua/config/rarity.lua:25,40,55,70,85` = 100 / 40 / 12 / 3 / 1).

| # | id | Danish (English) | rarity | water | season | extra | sell |
|---|---|---|---|---|---|---|---|
| 1 | fish_roach | Skalle (Roach) | normal | all three | all | – | 12 |
| 2 | fish_perch | Aborre (Perch) | normal | dam, byens_dam | foraar, sommer, efteraar | – | 18 |
| 3 | fish_crucian | Karusse (Crucian carp) | normal | dam, byens_dam | sommer, efteraar | – | 20 |
| 4 | fish_smelt | Smelt (Smelt) | normal | dam, byens_dam | vinter | – | 22 |
| 5 | fish_lantern | Lygtefisk (Lantern fish) | normal | maanesoe | all | – | 25 |
| 6 | fish_tench | Suder (Tench) | uncommon | dam, byens_dam | foraar, sommer | rain ×2 | 45 |
| 7 | fish_pike | Gedde (Pike) | uncommon | dam, byens_dam | efteraar, vinter | – | 55 |
| 8 | fish_eel | Ål (Eel) | uncommon | dam, byens_dam | foraar, sommer, efteraar | night only | 60 |
| 9 | fish_glimmer | Glimtefisk (Glimmer fish) | uncommon | maanesoe | all | – | 50 |
| 10 | fish_goldfish | Guldkarusse (Goldfish) | rare | byens_dam | foraar, sommer | rain ×2 | 120 |
| 11 | fish_star_roach | Stjerneskalle (Star roach) | rare | maanesoe | all | – | 140 |
| 12 | fish_old_gustav | Gamle Gustav (Old Gustav) | unique | byens_dam | not vinter | eligible after 10 lifetime catches at Byens dam; certain on the 25th | 0 |
| 13 | fish_moon | Månefisken (The Moon Fish) | legendary | maanesoe | all | night only; certain on the 12th night catch (≈ 2 night visits) | 0 |

* **No empty casts:** every water has at least 2 normal fish in every season (winter farm pond: Skalle, Smelt, plus Gedde; Månesøen: Skalle, Lygtefisk).
* **Keepsakes are fish items, not furniture:** `max_stack = 1`, `sell_price = 0`; a second copy is refused (`economy_manager.gd:283-284`) and they can never be gifted (`scripts/social/gifts/gift_rules.gd:12,64-66`). `add_item` only checks current holdings and a keepsake can sit in the home chest, so the flags `fish_got_<id>` are the authority that it is never drawn again. The furniture/clothing keepsake source validator does not apply (`tests/lib/features/content_validator.gd:213`).
* **Hints:** `FISH_STIR` on the first cast of the day at a water where a keepsake is eligible. Gamle Gustav is the town legend; Månefisken is Dyne's story.
* **Income** (weighted averages from the table): farm in summer ≈ 20 g per fish (full pool ≈ 160 g), town ≈ 23 g (≈ 140 g), Månesøen ≈ 29 g (≈ 176 g); maximum ≈ 480 g a day. A typical child catches 5-10 a day, ≈ 100-250 g, the value of 3-6 turnips at 45 g (`lua/items/crops.lua:34`). The rod (120 g) pays for itself on day 1. Pool sizes are the tuning knob (Q3).

### 3.7 The rod

Unchanged (`lua/items/tools.lua:127-138`), stays in the seed shop (`lua/shops/seed_shop.lua:42`). No tiers, no `TOOL_SLOTS` entry (`economy_manager.gd:60-62`). A free rod from Pippin's first quest is a P2 option (Q4).

### 3.8 What fish are for

1. **Shipping bin:** add `"fish"` to `lua/config/farm_site.lua:28`. The bin takes the hotbar-selected item (`scripts/farm/steading/objects/shipping_bin_2d.gd:17-25`); keepsakes are refused because they are not sellable.
2. **Selling:** **no shop edit.** The seed shop has no `buys` field (`lua/shops/seed_shop.lua:19-47`) and an empty `buys` means it buys every sellable item (`scripts/economy/shop_system.gd:269-271`). Adding `buys = { "fish" }` would stop it buying wood and break `tests/sections/economy_hours.gd:218`.
3. **Recipe Fiskefrikadeller** (`lua/recipes/fishing.lua`, backpack Værksted from day 1, `lua/recipes/guide_recipes.lua:9`): `fish_roach 2 + flour 1 → fish_cakes ×2`, category `bake` (the halfling's `bake_bonus` applies, `race_perks.lua:80`). Item: food, `stamina 25`, **`stamina_cost 0`** (otherwise eating costs 4 energy and is refused when tired: `player_2d.gd:344-347,383-384,395-396`; precedent `lua/items/consumables.lua:37-38`), **sell 15** (two cakes = 30 g against 36 g of inputs, `flour` 12 g `lua/items/products.lua:74-81`: energy, not a money loop).
4. **Husbandry:** cat `feed_types` += `fish_roach` (`lua/config/husbandry.lua:73`, milk stays favourite); fox += `fish_roach` (`:148`, cookie stays favourite); mirror both in the fallback table (`scripts/farm/animal_husbandry.gd:86,161`). The only feed pin in tests is `chicken_feed` (`tests/sections/mechanics_review_fixes.gd:112-113`).
5. **Gifts** (`lua/social/gift_tastes.lua`): Pippin `:84` like `category:fish`; Rasmus `:95` like `category:fish`; Bodil `:98` love `fish_goldfish`; Morfar Mis `:99` love `fish_roach`, like `category:fish`; Kvak `:100` like `category:fish`, love `fish_cakes`; penguin postman `:104` love `fish_smelt`.
6. **Samlerbog:** the Fisk page (§5). Fishing itself contains no Samlerbog code.

### 3.9 Data files

`lua/items/fish.lua` (kind `items`; **not** under `lua/data/**`, which the F1 validator stages, `tools/features/validate/stage.manifest:20`) + `fish.lua.import` keep stub (every `lua/**/*.lua` needs one, `tools/import/write_import_stubs.py:19,77`):

```lua
kind = "items"
items = {
  fish_roach = { name_key = "ITEM_FISH_ROACH", description_key = "ITEM_FISH_ROACH_DESC", category = "fish",
                 rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 12 },
  -- perch 18, crucian 20, smelt 22, lantern 25, tench 45, pike 55, eel 60, glimmer 50, goldfish 120, star_roach 140
  fish_old_gustav = { name_key = "ITEM_FISH_OLD_GUSTAV", description_key = "ITEM_FISH_OLD_GUSTAV_DESC", hint_key = "ITEM_FISH_OLD_GUSTAV_HINT",
                      category = "fish", rarity = "unique", max_stack = 1, buy_price = 0, sell_price = 0 },
  fish_moon = { name_key = "ITEM_FISH_MOON", description_key = "ITEM_FISH_MOON_DESC", hint_key = "ITEM_FISH_MOON_HINT",
                category = "fish", rarity = "legendary", max_stack = 1, buy_price = 0, sell_price = 0 },
  fish_cakes = { name_key = "ITEM_FISH_CAKES", description_key = "ITEM_FISH_CAKES_DESC", category = "food",
                 rarity = "normal", stamina = 25, stamina_cost = 0, max_stack = 99, buy_price = 0, sell_price = 15 },
}
```

`lua/config/fishing.lua` (kind `config`, one top-level key, literals only per `scripts/data/lua_lint.gd`) + `.import`:

```lua
kind = "config"
config = { fishing = {
  cast_s = 0.5, wait_s = { 1.5, 4.0 }, bite_window_s = 1.5, renibble_s = { 1.0, 2.0 }, auto_hook_bite = 2, reel_s = 0.6,
  areas = { farm = "dam", hyggebyen = "byens_dam", moerkeskoven = "maanesoe" }, floor_water = "maanesoe",
  waters = { dam = { name_key = "FISH_WATER_DAM", per_day = 8 },
             byens_dam = { name_key = "FISH_WATER_BYENS_DAM", per_day = 6 },
             maanesoe = { name_key = "LOOK_MOON_POND_NAME", per_day = 6 } },
  rain_mult = 2,
  roster = {
    fish_roach = { waters = { "dam", "byens_dam", "maanesoe" } },
    fish_eel   = { waters = { "dam", "byens_dam" }, seasons = { "foraar", "sommer", "efteraar" }, night = true },
    fish_tench = { waters = { "dam", "byens_dam" }, seasons = { "foraar", "sommer" }, rain = true },
    fish_old_gustav = { waters = { "byens_dam" }, seasons = { "foraar", "sommer", "efteraar" }, counter = "fish_byens_count", after = 10, sure_at = 25 },
    fish_moon  = { waters = { "maanesoe" }, night = true, counter = "fish_moon_nights", after = 0, sure_at = 12 },
    -- ... the remaining rows follow table 3.6
  },
} }
```

The roster is the **single source of truth** for where a fish lives: fish items carry no `sources` rows, and the Samlerbog reads the roster for its "Kan fanges i …" line (§5).

`lua/recipes/fishing.lua` (kind `recipes`) + `.import`: `fish_cakes = { name_key = "RECIPE_FISH_CAKES", category = "bake", ingredients = { fish_roach = 2, flour = 1 }, output = { item = "fish_cakes", amount = 2 } }`.

### 3.10 Save data: GameManager world flags only

All JSON scalars, written with **one** `set_flags` per catch, because every changed flag fans out `flag_changed` to `iso_area.gd:1614`, `npc_2d.gd:122` and `inventory_ui.gd:60`.

| flag | type | meaning |
|---|---|---|
| `fish_day` | int | `total_day()` of the last catch; mismatch = all pools full |
| `fish_left_dam`, `fish_left_byens_dam`, `fish_left_maanesoe` | int | catches left today (`flag_int`, `game_manager.gd:402-419`) |
| `fish_byens_count` | int | lifetime catches at Byens dam (Gustav pity) |
| `fish_moon_nights` | int | lifetime night catches at Månesøen (Moon Fish pity) |
| `fish_total` | int | lifetime catches, for `flag:` and quest gates |
| `fish_got_fish_old_gustav`, `fish_got_fish_moon` | bool | keepsake caught, never drawn again |
| `fish_tutorial` | bool | first-cast whispers shown |

No `save_manager.gd` change (`FEATURE_ORDERS` is pinned, `tests/sections/save.gd:710-714`). Old saves have no flags, so pools are full. An old build loading a save with fish only logs "unknown item" (`economy_manager.gd:286-287`). Multiplayer: these are world flags; revisit if `MULTIPLAYER_ADDENDUM.md` lands (per-player counters).

**Events** via `EventBus.game_event` (`event_bus.gd:120`): `fish_cast {water}`, `fish_bite {water}`, `fish_caught {item, rarity, water, night}` (P2 adds an optional int `cm`, §5). Quests match payload keys with `match = {...}` (`scripts/autoload/quest_manager.gd:19-21,918-920`).

### 3.11 UI and audio (no screen, nothing focusable)

* Catch feedback = `add_item`'s own item toast + a whisper. **No** second "Fanget!" toast.
* No focusable nodes, so no focus ring is needed; full keyboard play through E / Enter.
* Esc / Start opens pause as usual, which cancels the session for free.
* No change to `game_ui.gd`, `pause_menu.gd` or `ui_foundation.gd`: no conflict with PR #1.

| Event | Cue | Route |
|---|---|---|
| `fish_cast` | `bath_splash` | data row in `lua/config/audio.lua` `audio_map.events` (`:16-21`; looked up by `audio_director.gd:14,75-77`) |
| bite | soft `bath_splash` (-6 dB) | `AudioManager.play_sfx` from the session (the director's `_sfx` has no volume, `audio_director.gd:28`) |
| `fish_caught` normal | `pickup_soft` | code case in `audio_director.gd` `_event` |
| `fish_caught` rare / unique / legendary | `loot_rare` / `loot_unique` / `loot_legendary` | same case, **skipped when `floor_of(area) > 0`**, because `DungeonCues` already plays the rarity cue on every `item_gained` there (`scripts/dungeon_run/cues.gd:19-21`) |

### 3.12 Danish copy: new `localization/fishing.csv` (keys, da, en)

| key | da | en |
|---|---|---|
| FISH_PROMPT | Fisk | Fish |
| FISH_LAND | Land først, så kan du fiske. | Land first, then you can fish. |
| FISH_POOL_EMPTY | Fiskene hviler sig. Kom tilbage i morgen. | The fish are resting. Come back tomorrow. |
| FISH_BAG_FULL | Rygsækken er fuld. Fisken svømmer glad videre. | Your backpack is full. The fish swims happily on. |
| FISH_TUTORIAL_WAIT | Vent til proppen dykker … | Wait for the bobber to dip … |
| FISH_TUTORIAL_BITE | Tryk nu – eller vent, så bider den selv på. | Press now – or wait, and it hooks itself. |
| FISH_SELF_HOOK | Den bed selv på! | It hooked itself! |
| FISH_REEL_IN | Du spoler ind. | You reel in. |
| FISH_STIR | Vandet bobler … noget stort er vågent i dag. | The water bubbles … something big is awake today. |
| FISH_LEFT_FMT | %d fisk tilbage i %s i dag. | %d fish left in %s today. |
| FISH_LAST_TODAY | Det var dagens sidste fisk her. | That was the last fish here today. |
| FISH_WATER_DAM / FISH_WATER_BYENS_DAM | Gårddammen / Byens dam | Farm pond / Town pond |
| RECIPE_FISH_CAKES | Fiskefrikadeller | Fish cakes |
| ITEM_FISH_ROACH / _DESC | Skalle / En lille sølvfisk. Den er her hele året. | Roach / A little silver fish. It is here all year. |
| ITEM_FISH_EEL_DESC | Ålen kommer kun frem, når det er mørkt. | The eel only comes out after dark. |
| ITEM_FISH_OLD_GUSTAV / _DESC / _HINT | Gamle Gustav / Byens ældste karpe. Alle på broen har prøvet at fange ham. / Han svømmer i byens dam. Bliv ved med at fiske der. | Old Gustav / The town's oldest carp. Everyone on the pier has tried to catch him. / He swims in the town pond. Keep fishing there. |
| ITEM_FISH_MOON / _DESC / _HINT | Månefisken / Månens tabte knap – med lys i maven. / Dyne siger, den kun kommer frem, når det er nat ved Månesøen. | The Moon Fish / The moon's lost button – with light in its belly. / Dyne says it only comes out when it is night at the Moon pond. |
| ITEM_FISH_CAKES / _DESC | Fiskefrikadeller / Sprøde og varme. Giver energi. | Fish cakes / Crispy and warm. Restores energy. |

The other `ITEM_FISH_<ID>` / `_DESC` rows follow the same pattern: about 46 keys in total. Rarity words reuse `RARITY_*` (`localization/finds.csv:28-32`).

* **Changed text, same key:** `ITEM_FISHING_ROD_DESC` (`economy.csv:22`) → "Stil dig ved vandet og tryk E. Tryk igen, når proppen dykker – eller vent, så bider fisken selv på."; `LOOK_MOONPOND_FISHING` (`look.csv:3`) → "Månesøen ligger stille. Noget lyser dernede – har du en fiskestang med?" (the forest test pins the key, not the text).
* **Retired:** `WHISPER_FISHING_CLOSED` (`farm.csv:8`) and its exact owner entry (`tools/loc/key_owners.json:87`); no test references it.
* **Ownership:** a new `key_owners.json` entry for `fishing.csv` with prefixes `FISH_`, `RECIPE_FISH_`, `QUEST_FISH_`, `OBJ_FISH_` and `item_files: ["lua/items/fish.lua"]`. The longest prefix beats economy.csv's `RECIPE_` (`key_owners.json:110`); `ITEM_FISHING_ROD*` is not matched (no item of `fish.lua`), so it stays with economy.csv. Create the CSV with `python tools/loc/new_csv.py fishing`.

### 3.13 Files

* **New:** `scripts/fishing/fishing_rules.gd` (pure statics: `water_for(area)`, `faces_water(player)`, `left_today`, `eligible`, `roll(rng, fits: Callable)`, `record`); `scripts/fishing/fishing_session_2d.gd` (CAST → WAIT → BITE ⇄ NIBBLE → REEL, driven by `press()`, frees itself on cancel); `lua/items/fish.lua`, `lua/config/fishing.lua`, `lua/recipes/fishing.lua` (+ `.import` each); `localization/fishing.csv` (+ keep-import); `tests/sections/fishing.gd`.
* **Edited:** `scripts/world2d/player_2d.gd` (`:194-198` routing, `:241-245` hold, `:255-274` cancel, `:318-322` prompt, `:324-329` E branch, `:331-347` rod branch + stamina check before cast, `_using_item`); `lua/config/farm_site.lua:28`; `lua/config/husbandry.lua:73,148`; `scripts/farm/animal_husbandry.gd:86,161`; `lua/social/gift_tastes.lua:84,95,98,99,100,104`; `lua/config/audio.lua:16-21` (shared, §6.3); `scripts/audio/audio_director.gd` `_event`; `localization/farm.csv:8`, `economy.csv:22`, `look.csv:3`; `tools/loc/key_owners.json`.
* **Not touched:** `project.godot` `[input]` / `[autoload]`, `input_contract.gd`, `check_project.gd`, `game_ui.gd`, `pause_menu.gd`, `ui_foundation.gd`, `save_manager.gd`, `event_bus.gd`, `marker_handlers.lua`, `soft_ground.gd`, `forest_look.gd`, `seed_shop.lua`, `economy_manager.gd`.
* **Separate hygiene commit, not fishing:** `tools/towns/authoring/model.py:206` dock (10,34) → (5,34).

---

## 4. Samlerbog design

### 4.1 Pages

Totals are computed at runtime from `ItemKinds.all_ids(category)` (`scripts/data/item_kinds.gd:46`) and the top-level `slot`; a page with 0 entries is hidden.

| Page | Rule | Total today | normal / uncommon / rare / unique / legendary |
|---|---|---|---|
| Møbler | `category=furniture` | 130 | 45 / 33 / 24 / 17 / 11 |
| Tøj | `category=clothing`, `slot ~= "jewellery"` | 76 | 25 / 20 / 15 / 10 / 6 |
| Smykker | `category=clothing`, `slot == "jewellery"` | 20 | 8 / 4 / 3 / 3 / 2 |
| Våben | `category=weapon` (22 in `weapons.lua` + `sword_rusty`, `iron_sword` in `tools.lua:139,151`) | 24 | 5 / 5 / 5 / 5 / 4 |
| Skatte | `category=gem` without `rough_` (21, incl. `gem_bag`, `lua/items/resources.lua:96-103`) + the 11 `dng_` ids (`lua/items/dungeon_materials.lua`) | 32 | 7 / 10 / 6 / 6 / 3 |
| Fisk | `category=fish` | 0 now, 13 with fishing | 5 / 4 / 2 / 1 / 1 |

282 entries today. `iron_ingot` and the 4 `rough_*` stones are excluded on purpose. Every entry already has an icon file, so no item art is needed.

### 4.2 Tile states

| State | Look | Rule |
|---|---|---|
| **Ukendt** | `RaritySlot.unknown` dashed silhouette; **gold double ring when focused** (needs §4.6) | never owned |
| **Fundet** | full colour, rarity ring and pips | ever owned; never reverts |
| **Ny** | Fundet + a non-focusable `TagBox` (`tools/ui/build_theme.gd:321`) with an ink `Heavy14` label "Ny". Not a `Chip`: Chip is a Button (`build_theme.gd:528`) and would add focus stops | cleared on close, for every tile that had focus while the book was open |

### 4.3 Detail card (`PanelDetail`, `build_theme.gd:301`)

Follows keyboard / pad focus; with the mouse it previews on hover without taking focus.

* **Found:** big icon, name, rarity word and pips, description, "Du har: %d" (owned now = `ItemKinds.owned_total(id)` **+ `HomeManager.chest_count(id)`**; `owned_total` calls `EconomyManager.count_item`, backpack + store only, `economy_manager.gd:426-433`; chest `scripts/home/home_manager.gd:422-423`), up to 3 source lines, a set line, and for fish a record line.
* **Source lines** cover all 12 catalogue kinds (`find 208, shop 175, craft 108, spot 22, boss 14, appraisal 8, tier_gift 7, quest 7, gift 6, set_reward 4, creature 4, node 2`) plus `COLLECT_SRC_UNKNOWN` for the 7 entries without `sources` (`sword_rusty, iron_sword, crystal_shard, amethyst, emerald, moonstone, gem_bag`). Fish get `COLLECT_SRC_FISH_FMT` from the fishing roster's water names.
* **Unknown:** "???" and the rarity word, the source-kind lines (never the name) behind knob `unknown_shows_source`, and for the 68 entries with a `hint_key` the riddle behind knob `unknown_shows_riddle`. Both default on, pending Q8. Hint riddles are already shown on the loot reveal card (`loot_reveal.gd:105`).
* "Bogen husker alt …" (`COLLECT_SAFE_SELL`) shows once, on the first found entry.

### 4.4 Stamps

Each page has 3 stamps at 25 / 50 / 100 % of its total (ceil), paying 50 / 150 / 400 guldagern × `reward_pct / 100` (int knob, default 100, house `_x100` style `lua/config/dungeon_run.lua:27`). Five pages pay 3,000 over a whole game, Fisk 600. Scale: starting gold is 500 (`lua/config/game_balance.lua:64`); home tiers cost 200 / 300 / 900 / 2,100 … (`lua/data/home_tiers.lua:54-163`). The five early stamps together pay 250.

* A stamp is **claimed automatically when the book opens**, never during a load: `EconomyManager.add_gold` (`economy_manager.gd:157`), flag `samlerbog_<page>_<n>` via `set_flags` (`game_manager.gd:369`), `game_event collection_stamp` (sound `stage_up`).
* When a stamp becomes ready, one toast fires once, naming `UiHints.glyph(&"collection")` on keyboard or the pause menu on a gamepad (C has no pad button, `UI_NAVIGATION.md:168`).
* No titles, items or perks. Only furniture/clothing keepsakes have a validated fixed source (`content_validator.gd:210-255`), so a new test `every_entry_obtainable` guards weapons, gems and `dng_` against an unreachable 100 % stamp.

### 4.5 Discovery and backfill

* `item_gained` (`economy_manager.gd:844`) for a catalogue id not yet discovered: `discovered[id] = total_day()`, `new[id] = 1`, emit `item_discovered(id, rarity, page_id)` (the third argument is named `category` in the signal and carries the page id), `game_event collection_new`, queue a toast.
* **Toasts** flush once per frame (deferred): one discovery → `COLLECT_TOAST_NEW` with the **item id as icon**, so the forest stack drops it like the economy's item toast (`item_toasts = false`, `scripts/ui/components/toast_stack.gd:15,113-121`); several → `COLLECT_TOAST_MANY_FMT` with icon `"info"`. Discoveries made while `GameUI.mode == &"action"` (the forest) are held and merged into one toast on the next `area_changed` out of the forest (`event_bus.gd:73`).
* **`reset()`** is pure and idempotent (`Fresh.new_game` calls it again after a new game, `tests/lib/features/fresh.gd:13,30-37`): it clears state and arms `_from_save_without_section`.
* **`from_dict()`** disarms the flag and runs a merge-only top-up (day 0) from owned + chest + `LootService.found(id)` (`scripts/loot/loot_service.gd:430`).
* **`load_completed`** (`event_bus.gd:90`) with the flag still armed = an old save: silent backfill with day 0, `welcome_back_pending = n`. The welcome-back toast posts on the **first `player_spawned`** (`event_bus.gd:11`), because `load_game` does not change the scene (`save_manager.gd:283-284`) and a toast posted on the title would be lost (`UI_NAVIGATION.md:226`).
* **New game:** `new_game_started` → `_on_new_game()` (not `reset`): `reset()` then `_backfill.call_deferred(total_day())`, so the silent starter kit (`economy_manager.gd:84,93-99`) is discovered with no toast.
* Backfill and `from_dict` never `push_error`: the apply guard turns any engine error into a load rollback (`save_manager.gd:897,911-927`).

### 4.6 UI flow and navigation

* **Open:** C via `hotkey_action = &"collection"` (TTScreen ignores it while a modal is open or the world is not free, `scripts/ui/nav/ui_nav.gd:378-394`); `_hotkey_open_allowed()` also requires the player FREE, as Garderobe (`scripts/ui/garderobe.gd:163-165`) and pause (`pause_menu.gd:30`) do. Gamepad: the pause row. **No new input action.**
* **Layout (1280×720):** `PanelParchmentL24` (`build_theme.gd:278`) ≈ 1120×630 on `L.scrim`. Header: `Display34` "Samlerbog", subtitle "ført af Fru Ugle", "I alt %d af %d" (numbers in Caprasimo `Display*`), a `CloseButton` ✕ (`build_theme.gd:619`). `PillTab` radio chips per page in a ButtonGroup. A **`MeterGreen`** bar (not `MeterHoney`: honey is the lantern-oil colour and close to focus gold, `scripts/ui/theme/tt_colors.gd:17`). Five rarity counts with pips and `RarityWord*` labels. Three stamp seals. Left: an 8-column `ScrollContainer` (`follow_focus = true`) of `RaritySlot` tiles each in a `FocusProxy` (`build_theme.gd:623-627`), 82 px per tile ≈ 684 px. Right: the detail card. Footer: `HintBar` (`scripts/ui/components/hint_bar.gd`) with `HINT_MOVE`, `HINT_TAB`, `HINT_CLOSE`.
* **Focus:** `UiNav.wire_grid(cells, 8)` then `UiNav.wire_groups([chips, cells, [close_button]])` (`ui_nav.gd:206-256`); up from the top row goes to the chips. Left / Right on the chips change page (the route on Mac laptops without PgUp / PgDn); PgUp / PgDn and LB / RB also page via `_on_page` (`scripts/ui/nav/tt_screen.gd:161`). Mouse hover previews only, a click focuses: pattern H hover-focus is "never for cards, chips, tabs" (`ui_nav.gd:256-258`) and the audit reports `hover_grabs_focus`. Initial focus: the first Ny tile, else the first tile; an empty page focuses its chip.
* **The gold double ring on every focused tile, silhouettes included.** Today `RaritySlot.plan()` returns before the `is_selected` branch for unknown tiles (`rarity_slot.gd:136-141`), so a focused silhouette draws no ring and would fail `ring_pixels` on a fresh save. Fix: about 3 lines in `plan()` / `_draw`; existing asserts use `is_selected = false` (`tests/sections/ui_foundation.gd:275-277,408,416`) and stay green.
* **Close:** C, Esc, B, Start (`tt_screen.gd:258-273`); the tree pauses (`pauses_tree`, `UI_NAVIGATION.md:227`). Opening already plays `page_turn` (`audio_director.gd:23`).
* **First open:** the welcome is an inline banner at the top of the detail column, not a dismissible layer (a layer would break the registry's `esc_depth: 1`). `welcomed` is set on close; then stamp claims, each with a 0.4 s seal pop, static under `assist_reduce_flash`.
* **Performance:** tiles are built per page, at most 130 proxies at once.
* **i18n audit:** item names identical in da/en are marked `tt_text_same_ok` / `same_ok`, otherwise `locale_flip_report` reports `not_localized`.

### 4.7 Data and save

`lua/config/samlerbog.lua` (kind `config`, + `.import`; read with `Svc.lua_config("samlerbog.pages")`, `scripts/data/svc.gd:59`):

```lua
kind = "config"
config = {
  samlerbog = {
    pages = {
      { id = "furniture", label_key = "COLLECT_PAGE_FURNITURE", categories = { "furniture" } },
      { id = "clothing",  label_key = "COLLECT_PAGE_CLOTHING",  categories = { "clothing" }, not_slot = "jewellery" },
      { id = "jewellery", label_key = "COLLECT_PAGE_JEWELLERY", categories = { "clothing" }, slot = "jewellery" },
      { id = "weapons",   label_key = "COLLECT_PAGE_WEAPONS",   categories = { "weapon" } },
      { id = "treasures", label_key = "COLLECT_PAGE_TREASURES", categories = { "gem" }, exclude_prefix = "rough_", also_prefix = "dng_" },
      { id = "fish",      label_key = "COLLECT_PAGE_FISH",      categories = { "fish" } },
    },
    stamps = { 25, 50, 100 }, stamp_gold = { 50, 150, 400 }, reward_pct = 100,
    unknown_shows_source = true, unknown_shows_riddle = true,
  },
}
```

Save section `collection`, order `SaveManager.FEATURE_ORDERS["collection"]` (50):

```json
{ "v": 1,
  "discovered": { "bed_pine": 0, "amethyst": 40 },
  "new":        { "amethyst": 1 },
  "stamps":     { "furniture": 1 },
  "fish":       { "fish_perch": { "n": 3, "d": 71 } },
  "welcomed": true,
  "orphans": {} }
```

* Key `discovered`, as the spec (`PLAN_2D_FEATURES.md:442,795`). Day 0 = backfilled. Whole floats normalised with `SaveCodec.int_counts` (`scripts/data/save_codec.gd:16`).
* `fish[id]` = count `n`, first day `d`, and `cm` (best size) only once fishing P2 sends sizes.
* Unknown `v` → `from_dict` returns false (pattern `furniture_manager.gd:239-241`). Ids no longer in the data move to `orphans`, kept and never counted. A pure `validate_dict(d)` (pattern `loot_service.gd:1063`). On `from_dict` the stamp flags are re-asserted from `stamps`.
* Audio: data rows `collection_new = "pickup_soft"`, `collection_stamp = "stage_up"` in `lua/config/audio.lua` (shared, §6.3).

### 4.8 Copy: `localization/samlerbog.csv` (prefix `COLLECT_`, already owned, `%s`/`%d` style as `localization/appraisal.csv:3-11`)

| key | da | en |
|---|---|---|
| COLLECT_TITLE | Samlerbog | Collection Book |
| COLLECT_KEEPER | ført af Fru Ugle | kept by Mrs Owl |
| COLLECT_PAGE_FURNITURE / _CLOTHING / _JEWELLERY / _WEAPONS / _TREASURES / _FISH | Møbler / Tøj / Smykker / Våben / Skatte / Fisk | Furniture / Clothes / Jewellery / Weapons / Treasures / Fish |
| COLLECT_COUNT_FMT | %d af %d | %d of %d |
| COLLECT_TOTAL_FMT | I alt %d af %d | %d of %d in all |
| COLLECT_UNKNOWN_BODY | Du har ikke fundet den endnu. | You haven't found this yet. |
| COLLECT_BACKFILL | Var allerede din, da du fik Samlerbogen. | Was already yours when you got the book. |
| COLLECT_SAFE_SELL | Bogen husker alt, du har fundet – også hvis du sælger det. | The book remembers everything you found – even if you sell it. |
| COLLECT_OWNED_FMT | Du har: %d | You have: %d |
| COLLECT_NEW_BADGE | Ny | New |
| COLLECT_SRC_SHOP_FMT | Kan købes: %s | Can be bought: %s |
| COLLECT_SRC_FIND_FMT | Kan findes i %s | Can be found in %s |
| COLLECT_SRC_CRAFT | Kan bygges på værkstedet | Can be built at the workbench |
| COLLECT_SRC_SPOT_FMT | Gemt et hemmeligt sted i %s | Hidden somewhere secret in %s |
| COLLECT_SRC_BOSS | En gave fra en af skovens vogtere | A gift from one of the forest's guardians |
| COLLECT_SRC_APPRAISAL_FMT | Fru Ugle kan slibe den frem af en rå sten fra %s | Mrs Owl can cut it from a rough stone from %s |
| COLLECT_SRC_CREATURE | Skovens væsner taber den nogle gange | The forest's creatures sometimes drop it |
| COLLECT_SRC_NODE_FMT | Kan hakkes fri i %s | Can be chipped loose in %s |
| COLLECT_SRC_QUEST | En belønning for en opgave | A reward for a task |
| COLLECT_SRC_GIFT | En gave fra en god ven | A present from a good friend |
| COLLECT_SRC_TIER_GIFT | En gave til dit nye hjem | A gift for your new home |
| COLLECT_SRC_SET_REWARD | Belønning for et helt sæt tøj | Reward for a whole outfit set |
| COLLECT_SRC_FISH_FMT | Kan fanges i %s | Can be caught in %s |
| COLLECT_SRC_UNKNOWN | Findes et sted i Trætoppens verden | Found somewhere in the world of Trætoppen |
| COLLECT_SET_FMT | Sæt: %s – %d af %d fundet | Set: %s – %d of %d found |
| COLLECT_SET_PLACE / COLLECT_SET_WEAR | Stil dem i dit hjem for en bonus / Tag dem på for en bonus | Place them at home for a bonus / Wear them for a bonus |
| COLLECT_FISH_COUNT_FMT | Fanget %d gange | Caught %d times |
| COLLECT_FISH_RECORD_FMT | Fanget %d gange · Største: %d cm | Caught %d times · Biggest: %d cm |
| COLLECT_TOAST_NEW | Ny i Samlerbogen! | New in your Collection Book! |
| COLLECT_TOAST_MANY_FMT | %d nye ting i Samlerbogen! | %d new things in your Collection Book! |
| COLLECT_TOAST_STAMP_FMT | Et stempel venter i Samlerbogen (%s) | A stamp is waiting in your Collection Book (%s) |
| COLLECT_TOAST_STAMP_PAD | Et stempel venter i Samlerbogen (pausemenuen) | A stamp is waiting in your Collection Book (pause menu) |
| COLLECT_WELCOME_BACK_FMT | Samlerbogen har talt dine ting: %d fund! | The book has counted your things: %d finds! |
| COLLECT_WELCOME | Kære samler! Her er en bog til alt det fine, du finder. – Fru Ugle | Dear collector! Here is a book for all the lovely things you find. – Mrs Owl |
| COLLECT_STAMP_GOT_FMT | Stempel! +%d guldagern | Stamp! +%d gold acorns |
| COLLECT_STAMP_1 / _2 / _3 | En fjerdedel / Halvdelen / Hele siden! | A quarter / Half / The whole page! |

Reused keys: `FIND_AREA_*`, `RARITY_*`, `SOURCE_BUY / BUILD / FIND / REWARD` (`localization/finds.csv`), shop `name_key`s, `FSET_*`, `OUTFIT_*`, `HINT_*`, `PAUSE_COLLECTION` (`menus.csv:29`). No hard-coded footer copy: the HintBar replaces it.

### 4.9 Deviations from the F9 spec (each an owner question)

* Three stamps per page (spec: "no milestones", `PLAN_2D_FEATURES.md:362,1303`) → Q7.
* Source lines and riddles on unknown tiles (spec: after discovery; RV-C12 rejected hint-through-book) → Q8.
* Skatte = gems + `dng_` instead of "rare building_materials" (`:795`) → Q11.
* A Våben page (the spec has none; the owner lists weapons as collectables) → Q12.

### 4.10 Files

* **New:** `lua/config/samlerbog.lua` (+ `.import`); `scripts/collection/collection_catalog.gd` (pure static, ≈ 200 lines); `scripts/collection/collection_log.gd` (autoload, ≈ 330 lines); `scripts/ui/samlerbog_ui.gd` (`extends TTScreen`, ≈ 450 lines, registers fixtures `samlerbog` and `samlerbog_guide` with `UiFixtures.register_setup`, `scripts/ui/dev/ui_fixtures.gd:104`); `scenes/ui/samlerbog.tscn` (12 lines, the `scenes/ui/home_amenities.tscn` pattern); `localization/samlerbog.csv` (+ `.import`); `tests/sections/collection.gd`.
* **Edited:** `scripts/ui/components/rarity_slot.gd` (≈ 3 lines); `tests/sections/ui_foundation.gd` (1 check); `lua/config/audio.lua` (shared); `tests/lib/ui_screens.json` samlerbog row `note` only (optional); `project.godot` only through `python3 tools/features/add_autoload.py CollectionLog`, run **last**.
* **Not touched:** `game_ui.gd`, `pause_menu.gd`, `event_bus.gd`, `project.godot [input]`, `input_contract.gd`, `key_owners.json`, `save_manager.gd`, `economy_manager.gd`, `assets/**`, `tools/art/drawn/**`.

---

## 5. How the two connect

One contract, owned by the fishing side, consumed by the Samlerbog side. Neither imports the other.

| Contract | Producer | Consumer | If the other side is absent |
|---|---|---|---|
| Fish items have `category = "fish"` (`lua/items/fish.lua`) | fishing FI1 | Samlerbog page `fish` (config row already present) | no fish items → the Fisk page has 0 entries and is hidden |
| `game_event fish_caught {item, rarity, water, night}` + optional int `cm` (P2) | `FishingRules.record` | `CollectionLog` increments `fish[item].n`, sets `d` on first catch, keeps the max `cm` when present | no CollectionLog → nobody listens; fishing works unchanged |
| Discovery of a fish | `add_item` → `item_gained` (always paired with a catch: fishing never catches with a full bag) | `CollectionLog` normal discovery path; the `discovered` check de-duplicates | – |
| Where a fish lives | `lua/config/fishing.lua` `roster[id].waters` + `waters[w].name_key` | `CollectionCatalog` source line `COLLECT_SRC_FISH_FMT` | config absent → `COLLECT_SRC_UNKNOWN` |
| Record line | – | `COLLECT_FISH_COUNT_FMT` until sizes exist, then `COLLECT_FISH_RECORD_FMT` | – |

Design decisions that reconcile the two drafts:
* The Samlerbog draft wanted fish items to carry `sources = {{kind = "fish", …}}`; the fishing draft had none. **Decision:** no `sources` on fish; the roster is the single source of where a fish lives, and the catalog reads it. This avoids two copies drifting.
* The Samlerbog draft's payload key `spot` and mandatory `cm` → **`water`** (the fishing design's id) and `cm` optional, P2.
* The Samlerbog draft said a released fish (full bag) still counts. Fishing refuses to cast when nothing fits, so there is no released fish; `fish_caught` is always paired with an `add_item`.
* A first catch shows two toasts: the economy item toast and "Ny i Samlerbogen!" (like every first find). In Mørkeskoven the book toast is held until leaving.
* While fishing, the player is `S.USING`, so C is ignored (the FREE gate); Esc opens pause and cancels the cast at no cost.

---

## 6. Phases, packages and order

### 6.1 MVP

| Package (json) | Feature | Depends on | Estimate |
|---|---|---|---|
| FI1-fish-data-rules | fishing data, rules, copy, key ownership | – (art gate: ART-FISH or the Q2 exemption) | 1.5 d |
| FI2-fishing-session | Player2D routing, session node, prompt, cancel paths | FI1 | 2.25 d |
| FI3-fish-uses | bin, husbandry, gifts, audio cues | FI1 | 0.75 d |
| SB1-collection-log | autoload, catalog, config, save section, toasts, stamps | – | 2 d |
| SB2-rarity-slot-focus | 3-line focus-ring fix + check | – | 0.25 d |
| SB3-samlerbog-ui | screen, scene, copy, UI audit | SB1, SB2 | 2.25 d |
| CF1-fish-page-bridge | integration tests across both | FI1, FI2, SB1, SB3 | 0.5 d |
| CF2-docs | README, PLAYING, superseded notes | everything shipped | 0.5 d |
| ART-FISH (owner-gated) | 14 painted icons | FI1 ids frozen, owner go-ahead | owner |

Order: wave A = FI1, SB1, SB2 (parallel); wave B = FI2, FI3, SB3; wave C = CF1, CF2. The Samlerbog can ship alone after SB3 (it has no art blocker); fishing can ship alone after FI2 + FI3 once the art gate is settled.

### 6.2 Later phases

* **Fishing P2 (≈ 2 d, data-heavy):** quest "Prik i proppen" (Pippin, tag `HØST`, `game_event fish_caught` → 60 g + 2 cookies; tags at `quest_manager.gd:47`); math quest "Kvaks fiskeregning" (`LÆR`, pattern `lua/quests/math_harvest_puzzle.lua`); fish sizes (`cm`) and the Samlerbog record line; a Dyne scene gated on `flag:fish_got_fish_moon&night&at:traetoppen.t_fire_e` (predicates `scripts/social/social_manager.gd:978-986`); optionally the free rod from Pippin (Q4).
* **Samlerbog P2 (≈ 2-3 d, each droppable):** Fru Ugle's daily tip (`emit_event collect_tip`, `lua/dialogue/appraiser_fru_ugle.lua`, `scripts/world2d/npc_dialogue.gd:87-92`); "Ny til din Samlerbog" glyph in `scripts/ui/shop_ui.gd`; quest state query `samlerbog_found` (`QuestManager.register_state_query`, `quest_manager.gd:213`, + `refresh_objectives()` `:968`); a Sæt filter chip.
* **Later (owner choice):** a Badedagen fish activity (it already runs a `category:food` contest, `lua/festivals/fixed/badedagen.lua:24`); a Månestang (+2 per pool); a water legend on the area map (`scripts/ui/maps/area_map_snapshot.gd`, `origin/main`); a painted bobber and cast pose; read-only Rekorder / Minder / Venner pages; patron scenes; an aquarium for keepsake fish (Q6).

### 6.3 Shared files and merge hotspots

* `lua/config/audio.lua` `audio_map.events`: FI3 adds `fish_cast`, SB1 adds `collection_new`, `collection_stamp`. Append-only rows, a sanctioned shared edit; nothing pins the table.
* `tools/loc/key_owners.json`: FI1 adds `fishing.csv` next to the `map.csv` / `updates.csv` entries PR #1 added on `origin/main`.
* `project.godot` `[autoload]`: only `add_autoload.py CollectionLog` (SB1, last task, after branching from `origin/main`).
* `README.md`, `docs/PLAYING.md`: changed by PR #1, edited only by CF2 on `origin/main`.
* Codex is restyling `assets/**` and `tools/art/drawn/**` on main: ART-FISH must check with that work before touching either; no other package touches them.

---

## 7. Overlap with other work

* **PR #1** (`origin/codex/release-pipeline`) is merged into `origin/main`. It added `map_ui` to `SCREEN_ORDER` and a Kort row to `pause_menu._specs()`; the Samlerbog row already exists, and `origin/main:tests/sections/menus.gd` expects pause rows `size() in [13,14]` and `all_pause_rows_fit_720 == 14` with Samlerbog already stubbed. Byg (farm only) and Forlad skoven (dungeon only) never both appear, so the farm has 14 rows with Samlerbog, inside the range and the 630 px cap of `_fit_panel`. No code overlap with either feature; only README / PLAYING / key_owners / project.godot need a clean rebase (avoided by branching fresh).
* **Codex art restyle:** see §6.3.
* **Multiplayer addendum:** fishing counters are world flags and the collection is one section; both become per-player questions if `MULTIPLAYER_ADDENDUM.md` lands (its RM3 / RM4 per-player split).
* **Area map (PR #1):** a water legend is a later option, not MVP.

---

## 8. Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | Player2D state machine: presses refused in `S.USING`, `S.USING` auto-ends, slow walking still allowed | Player2D routes presses first, holds `_tool_time`, cancels on any movement vector; tests `press_routed_while_using`, `move_modal_travel_damage_cancel_without_cost` |
| R2 | Strict art coverage fails on any fish without an icon file (`tests/sections/art_forest_mother.gd:16-17` → `tools/art/drawn/coverage.gd:73`); no fish cell exists and `palette_variant` only recolours cloth and trim (`tools/art/drawn/items.py:44-45`) | Q2: paint `icons_fish.png` first, or a temporary listed exemption in `coverage.gd` with a test that the list only holds fish ids |
| R3 | `use_tool` precedes `attack` in ortho areas; a rod would block swinging | fishing in Mørkeskoven starts only from E / A; test `ortho_use_tool_still_swings_weapon_with_rod_owned` |
| R4 | Double toast / double SFX | no "Fanget!" toast; `fish_caught` SFX skipped on floors; tests `catch_emits_one_item_toast…`, `no_double_rarity_sfx_on_floor` |
| R5 | Book toast displaces the item tile in `ui_nav.toast_stack_caps_and_rarity` (`tests/sections/ui_nav.gd:1450-1484`) | deferred flush, item-id icon; run `--only=ui_nav,hud,loot,collection` together |
| R6 | Old-save welcome toast lost on the title stack | post on the first `player_spawned` |
| R7 | `Fresh.new_game` calls `reset()` twice | `reset()` pure; backfill deferred from `_on_new_game` |
| R8 | A 100 % stamp that can never be reached | `every_entry_obtainable` test |
| R9 | Economy drift (fish income vs farming) | pool sizes and prices are data knobs; Q3 |
| R10 | Keepsake drawn twice after moving to the chest | `fish_got_<id>` flags are the authority; test `keepsake_never_rolled_twice_even_when_in_chest` |
| R11 | `flag_changed` fan-out per catch | one `set_flags` call per catch |
| R12 | Unknown silhouettes fail `ring_pixels` / "gold = focus" | SB2 fix, landed before SB3 |
| R13 | Reversing earlier "no fishing" decisions confuses later readers | CF2 adds superseded notes at `PLAN_2D.md:430,694,1297,1695`, `DUNGEON_V2_ADDENDUM.md:783,868`, `TOWNS_FARM_SOCIAL_ADDENDUM.md:44,971,1033` |

---

## 9. Test plan

All new sections run under `tests/run_playtest.sh --strict` (any engine warning fails). New sections join CI sharding automatically (`tools/ci/sections.py` on `origin/main`).

**`tests/sections/fishing.gd`** (`--only=fishing`):
1. `rules_every_water_every_season_has_two_normals`
2. `rules_roll_deterministic_seeded`, `rules_roll_only_fish_that_fit`
3. `rules_eel_moon_night_only`, `rules_goldfish_byens_dam_only`, `rules_rain_doubles_weight` (`regn` only)
4. `pity_gustav_sure_at_25`, `pity_moon_sure_at_12_nights`, `keepsake_never_rolled_twice_even_when_in_chest`
5. `pool_counts_down_and_resets_next_day`, `old_save_without_flags_has_full_pools`
6. `session_no_input_still_catches` (the no-fail guarantee)
7. `session_press_in_window_catches_first_bite`, `early_press_harmless`, `press_routed_while_using`
8. `move_modal_travel_damage_cancel_without_cost` (energy, pool, inventory unchanged)
9. `keyboard_only_e_fishes_without_rod_on_hotbar` (`t.tap_key(KEY_E)`, `tests/lib/drive.gd:193`)
10. `fairy_flying_whispers_land`, `ghost_fishes_from_shore`
11. `npc_on_pier_keeps_talk_prompt`
12. `ortho_use_tool_still_swings_weapon_with_rod_owned`, `hub_bog_and_floor_pond_share_maanesoe_pool`
13. `tired_refuses_before_cast`, `bag_full_refuses_before_cast`, `not_facing_water_no_prompt`
14. `catch_emits_one_item_toast_item_gained_and_fish_caught`
15. `held_rod_drawn_while_fishing_in_ortho`
16. `bin_accepts_fish`, `seed_shop_buys_fish_unchanged` (still buys wood), `cat_fox_accept_fish_roach` (Lua and fallback agree), `fish_cakes_recipe_crafts`, `fish_cakes_cost_no_energy`
17. `config_roster_matches_items` (both ways), `loc_keys_da_en`, `owner_of("RECIPE_FISH_CAKES") == "fishing.csv"`, `owner_of("ITEM_FISHING_ROD_DESC") == "economy.csv"`
18. `no_double_rarity_sfx_on_floor`

**`tests/sections/collection.gd`** (`--only=collection`):

| Test | Checks |
|---|---|
| `page_counts` | 130 / 76 / 20 / 24 / 32 = 282; `iron_ingot`, `rough_*` excluded; `gem_bag` included; Fisk hidden without fish |
| `every_entry_has_a_source_line` | 12 kinds mapped; the 7 source-less ids use `COLLECT_SRC_UNKNOWN`; no raw keys |
| `every_entry_obtainable` | every weapon, gem and `dng_` id is referenced by a loot, shop, recipe or quest table |
| `discover_once` | same item twice → 1 `item_discovered`, 1 toast |
| `toast_merge` | 3 adds in one frame → 1 `COLLECT_TOAST_MANY_FMT` |
| `toast_forest_deferred` | no book toast in action mode; one merged toast after leaving |
| `silent_starter_backfilled` | `Fresh.new_game` + 1 frame: starter kit discovered, no toast |
| `reset_is_pure` | `reset()` twice posts nothing, state empty |
| `chest_counts` | an item only in the home chest backfills and shows "Du har" |
| `sell_keeps_found` | selling / consuming keeps it discovered |
| `old_save_backfill` | payload without `collection` → owned + chest + `LootService.found` discovered with day 0; no gold; welcome toast only after `player_spawned`; no engine error |
| `persist_roundtrip` | round trip; unknown `v` → false and rollback; stamp flags re-asserted |
| `orphans_kept` | kept, not counted |
| `stamps_claim_on_open` | 25 % → one stamp toast; open → +50 once; reopen → +0; flag set |
| `fish_event` | a stub `fish_caught` records `n` and `d`, and `cm` only when present |
| `hotkey_gates` | C ignored while another modal is open or the player is not FREE; C toggles |
| `collection.screen_counts`, `collection.focus_map` | chip counts; 8-wide grid; up from the top row → chips; Left / Right on chips pages; focused unknown tile has `gold_ring` (`UI_NAVIGATION.md:912-913`) |
| windowed `samlerbog` | `UiAudit.ring_pixels` on a focused unknown tile and on a found tile; `await UiAudit.audit_screen(t, "samlerbog")` (recipe in the header of `tests/sections/ui_audit.gd`) |

**`tests/sections/ui_foundation.gd`:** `unknown_selected_has_gold_ring`.

**Bridge (CF1, in `collection.gd`, skipped when fish items are absent):** `fish_page_shows_13_with_fishing`, `real_catch_discovers_and_records`, `fish_source_line_from_roster`, `fish_stamp_25_needs_4`.

**Must stay green:** `forest_look.pond_whisper_once_per_floor`; `economy_hours` (seed shop buys wood); the social gift validator; `mechanics_review_fixes.basic_feed_*`; `menus` pause-row counts (on `origin/main`); `save.feature_orders_*`; `loc` (`loc.gd:495,522`); `core.signal_arity_lint` (`core.gd:109`, no new signal); `ui_foundation` (`:775-777` uses a temp scene dir); `ui_nav.toast_stack_caps_and_rarity`; strict art coverage; `write_import_stubs.py --check`.

**Manual (owner / human playtest):** a child-age player fishes at all three waters with keyboard only and gamepad only; reads the bite cue with sound off; opens the Samlerbog with C and from the pause menu; walks every page with arrows, Left/Right chips and Esc.

---

## 10. Art and audio list (placeholder-first; painted art needs the owner's go-ahead)

| Need | Count | Placeholder (ships first) | Painted Codex-style route |
|---|---|---|---|
| Fish icons | 13 (+ `_night` rims for the 2 keepsakes, generated by the packer) | runtime falls back to the initial badge (`scripts/world2d/art_catalog.gd:351-354`); the **strict CI gate** fails without a file, so either the painted sheet or a temporary listed exemption (Q2). A recolour row would ship a wrong picture | one 4×4 sheet `tools/art/drawn/sources/icons_fish.png` (13 fish + fish cakes + 2 spare) → rows in `tools/art/drawn/item_recipes.json` → `pack.py --only=items` → `write_import_stubs.py` (`tools/art/drawn/README.md`) |
| Fish-cakes icon | 1 | same | same sheet |
| Bobber, ripple, "!" bubble | – | final: drawn in code in the guide palette (no red, no additive look) | optional painted bobber |
| Hero cast pose | optional | existing `interact` clip + held rod (`held_equipment_2d.gd:119`) | imagegen turnaround |
| NPC `fish` clip | optional | `idle` fallback (`npc_2d.gd:313-318`) | per character |
| Samlerbog stamp seal (empty / filled) | 2 states | `TagBox` with `COLLECT_STAMP_1..3` | one painted seal cell |
| Samlerbog book icon (pause row, toast) | 1 | text row; toast uses the item tile or `"info"` | painted book icon |
| "Ny" marker | – | `TagBox` + label | optional painted ribbon |
| Samlerbog guide reference | 1 png | first windowed capture at `tests/checkpoints/guide_ref_features/ui_samlerbog.png`; `compare_guide` is informational (`tests/lib/ui_audit.gd:3161-3165`) | an owner-approved mock (Q10); the old mock at `/Users/magnusudbjorg/Documents/projects/.pongpong-build/lift/features/FD/shots/ui_samlerbog.png` has outdated counts and cut milestones |

**Audio:** existing sounds only: `bath_splash`, `pickup_soft`, `loot_rare`, `loot_unique`, `loot_legendary`, `stage_up` (all in `assets/audio/sfx/`); `page_turn` already plays on every modal change. `telegraph_tick` is deliberately not used. Optional new sounds for the owner: a soft plop, a reel click, a stamp thump.

---

## 11. Open questions

See `COLLECTION_FISHING_OPEN_QUESTIONS.md` (14 numbered decisions, each with the default the build follows). The blocking ones: Q1 (reopen fishing at all) and Q2 (fish icons vs the strict art gate).

## 12. Honest stubs and non-goals

* No fishing minigame screen, no bait, no rod tiers, no fail state, no fishing marker, no fishing on interior maps (they have no water).
* No Samlerbog pages for NPCs, events, quests, recipes or animals in the MVP (read-only P3 options; recipes crafted and enemies defeated have no saved state today).
* No new input action, signal, autoload (other than the reserved `CollectionLog`), save-order key or screen id.
* The keyboard binding for `use_tool` stays open (Q14); fishing does not need it.
