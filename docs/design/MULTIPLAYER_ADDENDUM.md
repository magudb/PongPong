# MULTIPLAYER ADDENDUM — local-network co-op for up to four players

Status: **binding** addendum (2026-10-18) for the multiplayer track. Companion: `multiplayer_workpackages.json` (schema of `features_workpackages.json` / `towns_farm_social_workpackages.json`).
User decisions of 2026-10-18 (section 1) are binding. Where this file disagrees with `PLAN_2D.md`, `PLAN_2D_FEATURES.md` or the towns/farm/social addendum about multiplayer, **this file wins**. It never overrules the dungeon addendum's zone graph, floors or loot, or `UI_NAVIGATION.md`'s screen contracts, except where an amendment is named in `multiplayer_workpackages.json`.
Repo read: `main` @ investigation of 2026-10-18. No multiplayer code, design or package exists anywhere in the repo before this addendum; the only prior statement is the paired deferral "Children and multiplayer are later work" (`README.md:227`, `docs/PLAYING.md:74`). Engine: Godot 4.7 / GL Compatibility, `ENetMultiplayerPeer` available, no engine blocker.

**Names.** The game is **PongPong** / in-game title **Trætoppen**. The farm is **Min Trækronsgård**. A multiplayer *session* is a LAN game; the *host* is the peer that owns the world and the save; a *guest* is any other connected peer (up to three). The word "guest" stays banned for room-visitor NPCs (`Npc2D.guest` is unrelated).

---

## 0. The answer in 30 lines

1. **LAN co-op, one machine per player, up to 4.** Host creates a session over `ENetMultiplayerPeer` (UDP, local network); up to three guests join. No internet matchmaking, no couch/split-screen in this track.
2. **Host-authoritative.** The host simulates the world (farm, time, shops, enemies, loot) and owns the save. Guests send *intent* (use tool, interact, buy, accept quest); the host validates and applies, then replicates results.
3. **One shared world, one shared farm.** Min Trækronsgård, Trætoppen, Hyggebyen, the calendar, weather, shop stock, animals, buildings, loot chests and world flags are shared. Design already is "one world, one farm" (`TOWNS_FARM_SOCIAL_ADDENDUM.md`); multiplayer does not add farms.
4. **Separate player profiles.** Each player has own name, character type/skin, gold, backpack, equipment, hotbar, quest log, wardrobe and vitals. This is the Stardew default and the user decision of 2026-10-18.
5. **Home is the household.** House tier, home chest, furniture stock and placed furniture are SHARED (one house on one farm). Wardrobe stays per-player.
6. **Save is host-owned.** One JSON payload, same file layout family as today, with a `players` section that holds up to four profiles. Single-player saves migrate to `players[0]`.
7. **Four player slots.** `WorldRoot2D.players: Array` replaces `WorldRoot2D.player`. Bodies are spawned per peer; group `player` stays but lookup goes through a registry, never `get_first_node_in_group`.
8. **Input becomes per-player.** A `PlayerInput` indirection replaces direct `Input.*` calls in `Player2D` / `PlayerBody2D` / `PlayerCombat2D`. Host keyboard+mouse is player 1; guests run the same input map on their own machine. The pad gaps (`run`, `fly_*`, `slot_*`) are closed for gamepad-only machines.
9. **EventBus gains a player handle on player-scoped signals.** This is a **contract change** at a wave boundary (section 4.2): the arity lint and every consumer must be updated in the same wave. World-scoped signals keep their arity.
10. **Time is one shared clock.** Sleep is a vote: the day ends when every living player is in bed, or the host forces sleep from the pause menu. Forest/dungeon clock freeze stays as it is (it is already world-global).
11. **Pause in a session is host-only** and does not freeze other players' local UI; it freezes the shared sim. A guest's inventory/journal stay openable.
12. **No split-screen, no peer-to-peer lockstep, no separate farms, no guest-owned saves in this track.** Those are explicitly out of scope (section 8).
13. **The live stack only.** `scripts/world2d/` + autoloads + feature managers. `legacy/` is inert archive; the 3D multiplayer checkbox there is historical.
14. **Packages.** 10 new packages (MP1..MP10) in 5 waves + 12 amendments (RM1..RM12) to existing packages. CORE first: registry, input, state split, session, sync, save v3. EXTENDED: drop-in/drop-out, UI polish. QA: the multiplayer acceptance track.
15. **Questions only the user can answer** (section 9): shared vs split gold by default at the table, sleep voting rules, what happens when the host leaves, guest save resume, and whether children (the other deferred feature) are designed for multiplayer now.

---

## 1. User decisions (binding, 2026-10-18)

| # | Question | Decision | Consequence |
|---|---|---|---|
| 1 | What does "local network multiplayer for up to 4 players" mean? | **LAN, one machine per player** | `ENetMultiplayerPeer`, host/join UI, one process per machine. No couch/split-screen. |
| 2 | How shared are farm and economy? | **Shared farm + world, separate inventories** | One farm; gold/backpack/equipment/quests/wardrobe per player; home tier/chest/furniture household-shared. |
| 3 | Who owns the save? | **Host owns the save** | One save file on the host's machine holds world + up to 4 profiles. Guests do not persist the world. |
| 4 | Deliverable of the investigation | **Design addendum + work packages** | This file and `multiplayer_workpackages.json`. |

The architecture default that follows from 1–3 (and is written into the packages): **host-authoritative simulation**. Guests never write world state; they send intent and receive replicated state. This is the cheapest correct model for a farm game and the only one that makes "host owns the save" coherent.

**What the editor decided on the user's behalf** (each is a data value or one rule; the build follows it unless the user says otherwise): shared gold is **off** by default (each player has their own purse); the host can toggle "shared purse" later (EXTENDED, MP8); sleep is a **vote** with a host force-sleep; a disconnecting guest keeps their profile in the host save; rejoining mid-session is allowed in EXTENDED and loads the profile from the host save.

---

## 2. Scope and non-goals

### In scope (this track)

* Host/join a LAN session, up to 4 players, one machine each.
* Up to four `Player2D` bodies in one shared `WorldRoot2D`, each with own camera on their own machine.
* Shared farm, towns, dungeon, calendar, weather, shops, animals, loot, world flags.
* Per-player identity, gold, inventory, equipment, hotbar, quests, wardrobe, vitals.
* Host-owned save with up to four profiles (payload v3).
* Input abstraction + gamepad-complete bindings.
* EventBus player-handle contract.
* Host-authoritative netcode for movement, interaction, economy, quests, farm, combat.

### Out of scope (explicitly)

* Couch / split-screen / multiple players on one machine.
* Internet / Steam / matchmaking / NAT punch-through beyond LAN.
* Peer-to-peer or client-authoritative simulation.
* Separate farms per player, visiting other players' farms.
* Guest-owned or cloud saves; mid-session save on guests.
* Cross-play, dedicated servers, headless host.
* The vestigial 3D stack and `legacy/`'s multiplayer checkbox.
* Children (the other deferred feature) — separate track.

---

## 3. Architecture

### 3.1 Topology

```
  Machine A (HOST)                 Machine B..D (GUESTS, up to 3)
  ----------------                 -------------------------------
  ENetMultiplayerPeer (server)     ENetMultiplayerPeer (client)
  WorldRoot2D + 4 player slots     WorldRoot2D + 4 player slots
  FULL sim: farm, time, enemies,   PREDICT local body; apply host
  shops, loot, quests apply        world snapshots; send INTENT only
  SaveManager writes the save      No world save; profile lives host-side
```

* Transport: `ENetMultiplayerPeer`, default port from `lua/config/multiplayer.lua` (`port = 24565`, `max_players = 4`). LAN discovery is optional (EXTENDED, MP8); v1 is direct IP/host code join.
* Channel 0: reliable (intent, inventory, quests, save, chat/events).
* Channel 1: unreliable (position/animation sync).

### 3.2 Authority split

| State | Authority | Replication |
|---|---|---|
| Calendar, weather, day roll | Host | Broadcast on change (`day_started`, `time_of_day_changed` already exist) |
| Farm plots, greenhouse, placed items, area flags | Host | Apply-on-intent + broadcast resulting `EventBus` facts |
| Animals, buildings, shop stock, loot chests | Host | Same |
| Enemies, combat hits, boss state | Host | Host runs `Enemy2D`; guests see replicated transforms + hit events |
| Player transform / anim / aim | Local prediction, host-corrected | `MultiplayerSynchronizer` on each body (ch. 1) |
| Gold, inventory, equipment, hotbar | **Owner player** writes locally; host validates economy ops | Reliable RPC / synchronizer (ch. 0) |
| Quests, friendships, wardrobe | Owner player | Same |
| Home tier, home chest, furniture | Host (household) | Broadcast |
| Vitals (hearts, stamina, oil) | Owner player | Periodic sync + on-change |

**Intent, not state, travels from guests.** Guest sends e.g. `use_tool(cell, item_id)`, `interact(target_id)`, `buy(shop, item, n)`, `accept_quest(id)`. The host re-validates (range, cost, stock, cooldown) and applies. This keeps the save coherent and kills the "two players buy the last seed" race at the source.

### 3.3 Player registry

```
WorldRoot2D
  players: Array[Player2D]          # slot 0..3, index = player_slot
  player_by_peer: Dictionary        # peer_id -> Player2D
  player: Player2D                  # DEPRECATED alias = players[0] during migration (RM1)
```

* `player_id` is a stable string (save key): `p0`..`p3`. `peer_id` is session-local (`1` = host).
* `PlayerBody2D` gains `player_id: StringName` and `peer_id: int` and `is_local: bool`.
* Lookup rule: **never** `get_first_node_in_group("player")`. Use `WorldRoot2D.player_by_id(id)`, `player_for_event(event)` (device-aware), or `local_player()`.
* `EventBus.player_spawned(player)` keeps its arity and is emitted **once per body**; a new `player_despawned(player_id)` is added at the contract change.

### 3.4 Input

* New `scripts/player/player_input.gd` (RefCounted or Node) owned by each `Player2D`.
* Reads from either (a) the global `Input` singleton when `is_local and device == "keyboard_mouse"`, or (b) a bound `InputEvent` device for pads, or (c) a remote intent buffer on guests' copies of non-local bodies.
* `Player2D._unhandled_input` becomes `input.handle_event(event)` and is a no-op when `not is_local`.
* `Input.get_vector(...)` calls move behind `input.move_vector()`. Mouse aim moves behind `input.aim_position(world)`.
* `get_viewport().set_input_as_handled()` is only called by the local player.
* Pad binding gaps close: `run` = L3 / Shift, `fly_toggle` = R3, `fly_descend` = D-pad down + face, `slot_*` = hotbar wheel + shoulder chords. Exact glyphs in `MP2`.

### 3.5 Save payload v3

```
meta {version: 3, timestamp, saved_at, summary}     summary lists the host + player count
game       GameManager   {day, season, year, hour, minute, total_day,
                          farm_name, world_flags, unlocked_zones,
                          discovered_locations, play_time_seconds}
                           # player_name / character_type / character_skin REMOVED (they move to players[])
time       TimeManager   {weather, time_scale, weather_day, weather_seed}
world      WorldRoot2D   {v, area, placed, area_flags, farm?, greenhouse_farm?}
                           # player_pos / hotbar REMOVED (they move to players[])
players    PlayerRoster  ORDER 15   [{id, peer_ordinal, name, character_type, character_skin,
                                      gold, inventory, equipment, arsenal, hotbar,
                                      half_hearts, stamina, oil, area, player_pos,
                                      quests, wardrobe, social}, ...]   # 1..4 rows
husbandry, shops, home, furniture, loot, dungeon, social(campaign)   # unchanged, SHARED
```

* Migration: payload v2 with a single implicit player becomes v3 `players[0]` (name/type/skin from `game`, gold/inventory from `economy`, hotbar/pos from `world`, quests from `quests`, wardrobe from `wardrobe`).
* `economy` and `quests` core sections are **replaced** by per-player rows inside `players` (RM3). The shared economy that remains is shop stock (`shops`) and household (`home`, `furniture`).
* Autosave stays host-only, every 300 s + on `day_ended`.
* `meta.summary` gains `players` (array of short rows) and keeps `player_name` as the host's name for old UI, until the summary UI is amended (RM12).

### 3.6 Sleep, pause, disconnect

| Event | Rule |
|---|---|
| Sleep | Vote: day ends when every player with `state != FAINTED` is in bed. Host pause menu offers "Force sleep" (EXTENDED). |
| Pause | Host pause freezes the shared sim (`TimeManager.pause_time` already exists). Guests can still open inventory/journal/wardrobe. |
| Guest disconnect | Profile stays in the host save. Body despawns (`player_despawned`). Rejoin is EXTENDED (MP8). |
| Host disconnect | Session ends for everyone; host save is the world of record. A "host migration" is out of scope. |

### 3.7 What stays as it is

* One `FarmGrid`, one `greenhouse_farm`, one `AnimalHusbandry`, one `ShopSystem`, one `TimeManager` clock, one `LootService`, one `DungeonFloors` run.
* `Hours` / `ShopHoursGate` rule unchanged (shared world).
* Lua content layer unchanged in kind; multiplayer config is one new config file, not a new Lua kind.
* `IsoArea` builder, maps, markers, TownDirector, social routines — shared world, no per-player copies.
* Forest clock freeze on ortho areas (`world_2d.gd:458–464`) stays world-global.

---

## 4. Contract changes (wave-boundary, linted)

### 4.1 What the arity lint already enforces

`tests/sections/core.gd` lints every `EventBus` declaration and every `connect`/`emit` for matching arity. Adding or changing a signal is a **contract change** and must land in one wave with all consumers (`event_bus.gd:5–8`).

### 4.2 Signal changes (wave 2, package MP3)

**Keep arity (players are identified by the node or by a parallel convention):**
* `player_spawned(player: Node2D)` — emitted per body.
* `player_character_changed(character_id: StringName)` — now fires per player; consumers filter by `player_id` from the node.

**New signals:**
* `player_despawned(player_id: StringName)`
* `player_joined(player_id: StringName, peer_id: int, profile: Dictionary)`
* `player_left(player_id: StringName, reason: StringName)`
* `net_session_changed(state: StringName)` — `idle | hosting | joining | connected | ended`

**Arity changes (add `player_id: StringName` as the first argument):**
* `player_inventory_changed`, `player_stats_changed`, `player_moved`, `player_health_changed`, `player_oil_changed`, `player_defeated`, `hotbar_changed`, `hotbar_assign_requested`, `interaction_prompt_changed`, `gold_changed`, `item_gained`, `item_purchased`, `item_sold`, `quest_offered`, `quest_accepted`, `quest_objective_updated`, `quest_completed`, `quest_failed`, `outfit_changed`, `garment_equipped`, `friend_changed`.

`game_event` and `lua_event` stay unchanged (they are the escape hatch). World-scoped signals (`day_*`, `crop_*`, `animal_*`, `shop_*`, `enemy_*`, `zone_*`, `flag_changed`) keep arity; their payloads may add an optional `actor_id` only if a package needs it, via `game_event` first.

### 4.3 Save section changes

* Remove built-in required section `economy` (gold/inventory move to `players`). Keep a transitional `economy` reader for v2 migration only (`SaveManager._migrate`).
* Remove built-in required section `quests` as the single-player log; quest state moves to each player row. Shared/campaign quest state that is world-owned (e.g. `world_flags` quest mirrors) stays in `game.world_flags`.
* New registered section `players` (order 15), owned by the new `PlayerRoster` node.

The implemented v3 section is `{v: 1, rows: {p0: profile, ...}}`, with one to four
profiles and `p0` required. `PlayerRoster` registers at order 15. A staging node under
`SaveManager` handles inspection and loading before a world exists; the roster child
of `WorldRoot2D` views the same session rows. Entering or freeing a world therefore
preserves all loaded profiles. `meta.summary.players` lists profile identity and gold
in slot order. The existing summary fields remain available to the current save UI.

RM8 stores friendship mirrors at `players.rows.<id>.flags.friend_<npc>` and
`friend_last_<npc>`. The `GameManager` flag accessors route these names through the
acting profile; they are absent from `game.world_flags`. Host operations can use
`SocialManager.for_player(id, callable)` for synchronous friendship, gift and chat
work. Friendship signals carry that actor id. Social NPC rows and content-drift
orphans retain their player owner, while seed, festivals and household partner
remain shared.

### 4.4 Autoloads

**No new autoload in CORE.** `PlayerRoster` lives as a child of `WorldRoot2D` (like `FarmGrid`) so it is spawnable per session and testable without a global. A `MultiplayerSession` node is created under `WorldRoot2D` by MP4, not as an autoload — session lifetime is world lifetime.

---

## 5. Packages (summary)

Full rows in `multiplayer_workpackages.json`. Wave plan:

| Wave | New | Amended | Theme |
|---|---|---|---|
| 1 | MP1-player-registry, MP2-player-input | RM1 (world_2d), RM2 (player_*) | Identity + input without networking |
| 2 | MP3-player-state, MP4-net-session | RM3–RM8 (economy, quests, save, event_bus, game_manager, wardrobe) | State split + EventBus contract + save v3 |
| 3 | MP5-net-sync, MP6-net-intent | RM9 (farm_grid), RM10 (shop_system) | Movement sync + intent pipeline |
| 4 | MP7-mp-ui | RM11 (ui_nav / character_select), RM12 (save summary) | Host/join UI, roster UI, pad glyphs |
| 5 | MP8-drop-in-out, MP9-mp-qa | — | Rejoin, shared-purse toggle, acceptance |

Tiers: MP1–MP7 = CORE; MP8 = EXTENDED; MP9 = QA. No forward dependencies. Estimated load: wave 1 ≈ 30 pts, wave 2 ≈ 45, wave 3 ≈ 40, wave 4 ≈ 25, wave 5 ≈ 20.

---

## 6. Testing

* The existing harness (`tests/run_playtest.sh`, throwaway HOME, boot-error gate) stays the gate for single-player. **Single-player must remain green on every wave** — every refactor keeps `players[0]` equivalent to today's one player.
* New `tests/sections/multiplayer_*.gd` sections run **in-process with a mock peer** (loopback `ENetMultiplayerPeer` to 127.0.0.1 is acceptable in CI; two OS processes are not required for CORE checks). Mock peer covers: registry, intent validation, save v3 round-trip, sleep vote, disconnect despawn.
* The acceptance package (MP9) adds a `net_loop` playtest leg: host + 2 mock guests, join, walk, till/plant/water, shop buy, sleep vote, save/load on host, guest rejoin (EXTENDED).
* CI: one new job is enough (matrix stays 4 characters). Networked leg is host-only + mocks; no multi-machine CI.

---

## 7. Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | EventBus arity change touches ~20 signals and every consumer | One wave (wave 2), arity lint is the net, `MP3` owns the whole cut |
| R2 | `get_first_node_in_group("player")` appears in ~30 files | MP1 replaces them all; a lint check (`no_first_player_group`) fails the suite if a new one appears |
| R3 | Host desync (farm state diverges) | Host-authoritative + intent validation; world mutations only on host; periodic farm hash in net tests |
| R4 | Save migration breaks existing player saves | v2→v3 migration is test-pinned (`tests/sections/save.gd` extended); v2 files still load as `players[0]` |
| R5 | Input abstraction regresses feel (tool repeat, dodge, aim) | MP2 keeps a single-player parity section; `--strict` playtest is the gate |
| R6 | GL Compatibility + ENet on older Wi-Fi | LAN only, unreliable channel for transforms, interpolation on guests; no guarantee claims on public internet |
| R7 | Feature managers still write "the" player via `GameData.eco()` | MP3 introduces `PlayerState.for_id(id)`; managers take an explicit player handle at their boundary |

---

## 8. Precedence and conflicts

* **DT-MP1.** This file wins over `PLAN_2D.md` / `PLAN_2D_FEATURES.md` for multiplayer.
* **DT-MP2.** `TOWNS_FARM_SOCIAL_ADDENDUM.md`'s "one world, one farm" stands; multiplayer does not create per-player farms. Its SocialManager is per-player for friendship rows in v3 (each player has their own hearts with citizens) — **this is the one real conflict** and the editor resolves it as: `SocialManager._rows` becomes keyed by `player_id -> npc_id` in wave 2 (RM8). Shared campaign state (`world_seed`, festivals, `partner` for the household) stays global.
* **DT-MP3.** Home tier/chest/furniture are household-shared even though inventories are per-player (one house).
* **DT-MP4.** `is_single_player` (`game_manager.gd:77`) becomes live: `true` when `players.size() == 1` and no peer is connected. Pause, sleep and save paths read it.
* **DT-MP5.** The dungeon's single-run state (`DungeonFloors.active`) is shared: one dungeon run at a time for the whole party, as today. Party wipe / leave rules are unchanged.

---

## 9. Open questions (defaults the build follows)

| # | Question | Default |
|---|---|---|
| Q1 | Shared purse as an option at session create? | **Later (MP8)**, default off. |
| Q2 | Sleep: all-in-bed vote or host forces? | **Vote + host force** (section 3.6). |
| Q3 | When the host quits mid-day, do guests get a copy of the save? | **No.** Session ends; host save is the world of record. |
| Q4 | Can a guest resume their own profile on another host later? | **No in this track.** Profile lives with the host save. |
| Q5 | Should the two hero-twin NPCs / Children be designed for multiplayer now? | **No.** Separate tracks. |
| Q6 | LAN discovery (UDP broadcast) in CORE or EXTENDED? | **EXTENDED (MP8).** CORE is join-by-IP / host code. |

---

## 10. Honest stubs

Until a package lands, the following are absent on purpose (the contract manifest reports them, `scripts/data/contract_manifest.gd`):


* `scripts/net/multiplayer_session.gd` (MP4)
* `scripts/net/intent_bus.gd` (MP6)
* `scenes/ui/multiplayer_lobby.tscn` (MP7)
* `lua/config/multiplayer.lua` (MP4)
* `localization/multiplayer.csv` (MP7)

Single-player play never requires any of them. `PlayerStub2D` stays the area-framework fixture it is today.

MP1/MP2's offline input prerequisites are implemented in `PlayerInput` and the body
registry/camera paths; see `MP_INPUT_WAVE1.md` for exact source/device, passive-frame,
pad-chord and compatibility contracts. This does not implement a LAN session. MP4's
transport and MP5/6's replication/host validation remain absent. Existing state/save
work uses the implemented `players.rows` shape, not the obsolete array sketch above.
