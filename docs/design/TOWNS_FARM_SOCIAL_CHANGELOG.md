# CHANGELOG - the final edit of the towns, farm and social addendum (2026-10-14)

The merged candidate (`FINAL_CANDIDATE`) was attacked by four adversarial reviewers; they found 30 defects with evidence (lenses: social / economy `SE`, technical `TE`, plan `PL`). Every defect is repaired IN PLACE in `ADDENDUM.md` and `packages.json`, in the editor's build scripts (`_build/`, so a rebuild reproduces the result) and, where a proof was possible, by a probe or simulation under `design3/final_editor/` whose output is quoted below. Nothing in the repo, in `impl/` or in the lift was edited.

## 1. What changed in numbers

| | before | after |
|---|---|---|
| new packages | 32 | 32 (S-heart-content M -> L; T-routes, T-director, T-interiors-core, S-core, S-gifts, S-marriage, I2, N-packages and others gained tasks, owns or dependencies) |
| amendments | 34 (RT1-RT34) | 37 (RT35 DL1-econ-store, RT36 DR1-rules, RT37 DQ-dungeon-acceptance appended; no RT number moved) |
| decisions / conflicts / requests | 52 / 36 / see 11.1 | 64 / 41 / 22 |
| wave load (points) | 4 = 65, 5 = 62, 5b = 27, 6 = 27, 7 = 15 | load per wave (S=1 M=2 L=3 XL=4): 3b: 2 | 4: 65 | 5: 62 | 5b: 27 | 6: 28 | 7: 15 |
| G5b closure | 52 packages incl. D1, D2, DR0, DR1, P19 | G5b closure: the 16 CORE packages + V4-city-map reach 49 packages by hard dependencies, 34 of them unbuilt | dungeon-track members besides D0 / DR7: 0 | D0 in, DR7 in, P19 out | 0 problems |
| checker mutants | 13 | 16 (closure, later-section verify names, soft dependency) |
| checker sections | A-H | A-H plus I (G5b closure) and J (verify names exist at their time) |

`packages.json` keeps its schema: the top-level keys, the package keys and the amendment keys are unchanged; two OPTIONAL amendment keys are used where the plan needs them (`removeDependsOn` was already read by the checker for design2's layer, `addSoftDependsOn` is new) and `editorLog` gains the kind `final`. The lead's `apply_designs.py` ignored both fields: `lead_tools/apply_designs.py` honours them (section 5).

## 2. The defects and their resolution

### SE1 (major, social_economy)

**Defect.** The keeper cannot be talked to inside any walk-in shop: the seam ShopCounter.forward_to_keeper is declared and assigned by nobody, the built E-query always lets the counter win over the keeper (0 of 576 samples select the keeper), and the one rule written for the seam ('a giftable hotbar item takes E first') would make the shop panel unreachable instead (12 of 12 tools and 8 of 8 seeds are giftable). Greeting, weekly heart, gifts, topics, birthdays and quest offers of 15 of 23 CORE citizens were reachable only while the keeper stood outdoors; Natteblik could never be befriended.

**Resolution.** The rule and the seam are REMOVED. Every counter band has three kinds of host: the centre host of its service and two `talk` hosts (ellipse 40 x 22) on the customer cells in front of the counter ENDS; E decides by where the player stands (middle cell = panel, end cell = the keeper's own Npc2D.interact: greeting, hearts, gifts, topics, quests). A talk host stays disabled until a keeper node exists. The two stalls get the same trio from `counters` rows of the city sidecar; I2 gains legs l03b and l06b; the balance claim gains an availability variant.

**Where.** T-towns-core (shop_counter.gd task rewritten, E-query replay task, counter band, COUNTER_ prompts), T-interiors-core (14 rooms carry the markers; keeper_reachable_from_counter_front), T-routes (sidecar `counters`), T-director (stall hosts, room director enables them), I2 (l03b, l06b), S-core (balance variants); DT53; ADDENDUM 4.4; acceptance rows 33 / 34

**Evidence.** design3/final_editor/se1 (replay14.py: A 252 / 252, B 126 / 126, C 0 of 1,008 over the 14 core layouts; fe_se1.gd: the REAL Player stub in a clone agrees on 23,760 of 23,760 samples) and se6 (typical tier A to 8 hearts, mixed visits: day 69 / p90 154 / 10 % never without the cells, day 70 / p90 108 / 0 % never with them; Sofus never in 98 % of runs -> 0 %, Natteblik 100 % -> 2 %)

### SE2 (major, social_economy)

**Defect.** The only entry to the 10-step home ladder (74,000 g) and its 'upgrade finished' celebration is Tømrerfe Hasselnød's dialogue, and the candidate put her behind the counter of a shop that opens 08-16 where E opens only the materials panel; no package, leg or acceptance row covered the ladder's entry.

**Resolution.** Covered by the `talk` hosts (her dialogue already has the `upgrade` and `materials` choices) and by a `desk` host (game_event open_home_builder {tier}) at cell m+2 of int_toemmerhandlen: the second door of the Husbyggeri, so the ladder never depends on a conversation. Leg l06c (Monday 12:00, enter the yard, E at the talk cell or the desk) and the `bridge` hint of the first days names the builder.

**Where.** T-towns-core (desk kind), T-interiors-core (desk marker, builder_desk_is_a_second_door), I2 (l06c), N04 (bridge hint copy); DT53; acceptance row 37

**Evidence.** design3/final_editor/se1 (desk D selected 9 / 9 from its cell, T1 still 9 / 9 beside it)

### SE3 (minor, social_economy)

**Defect.** A partner who is also a keeper stands in the farmhouse until 08:00 and then walks back, so the shop opens unstaffed (Maja 115 minutes, Kløvermynte 67, Brumme 59).

**Resolution.** The farmhouse morning ends at a computed leave time = opens - RouteTable.seconds(farm.porch, work_door) x 2 / 60 - 5 minutes; a partner whose leave is before 06:15 has no morning there (Maja); hours.keeper_covers_hours runs with a partner overlay for each of the 11 candidates (social_marriage.partner_keeps_shop_staffed). S-marriage depends on T-routes for it.

**Where.** S-marriage T3, ADDENDUM 5.4; DT61

**Evidence.** design3/final_editor/se3/partner_leave.py: Maja leave 05:00, Kløvermynte 06:48, Brumme and Rasmus 06:56, Pip 07:59, Sofus 09:08

### SE4 (minor, social_economy)

**Defect.** One press of 'Giv' hands over any non-protected item without a confirm: all 12 tools, 56 rare items (sell 34-1,670 g) and all 26 building materials were giftable for at most 60 points.

**Resolution.** S-gifts hides tools in the hotbar, the last copy of any tool, the next home tier's materials and the pieces of a wardrobe set whose capstone is open (late bound reads of F2 / F4; F4 gains LootService.set_capstone_granted); GiftRules.needs_confirm marks tools, rarity rare and sell value >= 100 g; S-ui's picker opens UiConfirm (default Fortryd) for them.

**Where.** S-gifts (T1 + needs_confirm task), S-ui (T2, rel_ui rows), RT19 (F4 read); DT60

**Evidence.** social_dump.json counts quoted by the reviewer

### SE5 (minor, social_economy)

**Defect.** The contest reward had no value cap and the winning entry is cheap: five contests a year could pay up to 5 x 1,670 g.

**Resolution.** SocialValidator rule SV14: first <= min(2 x the cheapest winning entry, 400 g), second <= 0.7 x first, third <= 0.4 x first, no keepsake, rarity <= rare; S-events refuses an over-cap reward; S-fest-content checks its prizes against the loot tables.

**Where.** S-core T14, S-events T3, S-fest-content T0; DT61

**Evidence.** reviewer's contest arithmetic

### SE6 (minor, social_economy)

**Defect.** Friendship saturates before the main game ends (a typical player has seen all 20 LEAN heart events by day 97 and has 14 of 30 citizens at 10 hearts after a game year), and the balance test passed with a 3-day margin.

**Resolution.** S-heart-content builds 40 scenes (4 / 6 / 8 / 10 hearts for the 10 tier A citizens, size M -> L); social.balance_claims_hold asserts ranges (median <= 80, p90 <= 115 with LEAN events, <= 110 with four) in a `free` and a `mixed` availability variant with a ratchet file. DECLINED: the year-2 hook (a new birthday card per year) stays roadmap (risk RK16).

**Where.** S-heart-content, S-core T15, ADDENDUM 5.5; DT62

**Evidence.** design3/final_editor/se6: free 71 / p90 97, mixed 70 / 108 (LEAN); four events free 66 / 90, mixed 65 / 101

### SE7 (minor, social_economy)

**Defect.** Blomsterfesten (day 7) and Høstfesten (day 70) list seed_shop in stays_open but are Sundays and the seed shop is closed on Sundays.

**Resolution.** seed_shop is dropped from both festivals' stays_open (their own seed stall and harvest market sell); S-fest-content gains social_fest_content.stays_open_is_possible_on_the_festival_weekday. No per-festival opening override is added to Hours.

**Where.** S-fest-content T0, ADDENDUM 5.3; DT61

**Evidence.** reviewer's s11_shop_access.py

### SE8 (minor, social_economy)

**Defect.** The seed shop restocks at most 20 carrot seeds a day and is closed on Sundays: a dedicated 110-plot field is 2.1 seeds a day short (-4.8 % income).

**Resolution.** carrot_seeds stock = 25, restock = 25 in lua/shops/seed_shop.lua (RT5, one number); the pin economy.shop_save_validated follows in DL1's amendment RT35; supply 6 x 25 = 150 a week = 21.4 a day against 19.2 needed.

**Where.** RT5 task 3, RT35; DT61

**Evidence.** reviewer's income model rows

### TE1 (major, technical)

**Defect.** Prototypes the packages lift name class_names that a LATER wave builds: hours.gd, door_2d.gd and shop_hours.gd call Routines (wave 5) in wave 4; npc_director.gd casts to TownDirector (5b) in wave 5; social_manager.gd names GiftRules (wave 5) in wave 4 so the autoload fails to boot.

**Resolution.** Lifted code is EDITED: Hours has its own clock-only now_ctx(); Door2D and ShopHours reach Routines only through Svc.static_call with a safe default; NpcDirector tracks live directors as Objects in its static registry (no cast); SocialManager reaches GiftRules only through Svc.static_call. Four checks `no_forward_class_refs` (towns_data, towns_routes, towns_director, social) scan the package's own scripts; towns_data also loads its scripts without the later files.

**Where.** T-towns-core, T-routes, T-director, S-core (tasks and lift lines); DT54

**Evidence.** reviewer's probes p2 / p6 (Parse Error: Identifier "Routines" not declared; Could not find type "TownDirector"; GiftRules x3)

### TE2 (major, technical)

**Defect.** RT5 (the hours hook in P12) and the wave-4 buildings registry break 25 built P12 checks (all 9 shops are closed at the new-game clock) and the pin economy.late_binding_via_svc (a third static_call line); no task amends tests/sections/economy.gd.

**Resolution.** The hook is a helper file scripts/economy/shop_hours_gate.gd, so shop_system.gd keeps two `static_call(` lines; config towns.hours_enabled (default true) turns the rule off; economy.gd's _fresh() sets it off in DL1's amendment RT35 (design2 gave economy.gd to DL1, so P12's fix-round must not edit it); the new checks live in P12's new section economy_hours; the clock every section runs at is stated once (DT55). This differs from the reviewer's wording (a task of RT5 on economy.gd) only because of the ownership of that file.

**Where.** RT5, RT35, T-towns-core (T0, T2, T6); DT55; ADDENDUM 4.5

**Evidence.** design3/final_editor/te2: hook + stand-in registry with the built economy.gd unchanged: 32 failed, late_binding_via_svc ok (2 call sites); with _fresh() switch off: economy 304 checks 0 failed; core + save + data + content_features + economy 1,104 checks 0 failed

### TE3 (major, technical)

**Defect.** T-routes' wave-5 acceptance (towns_routines >= 150, 9 PASS validators) cannot be met: 18 of 23 CORE routines place citizens in Trætoppen, but the city sidecar and LevelNav are T-director's (wave 5b); no pending-area rule; the 14 rooms are same-wave data of T-interiors-core.

**Resolution.** Options (a) and (b) of the reviewer combined: the city sidecar data/towns/traetoppen.json and scripts/towns/level_nav.gd MOVE to T-routes (which gains the dependency V3-levels for levels_graph()), so the route table bakes the city in wave 5; T-director builds doors and stall counters from it; TownsValidate.PENDING_AREAS lists an unbuilt room by name as SKIP and the wave-5 gate requires the list empty.

**Where.** T-routes (owns, deps, T5, T6, T8, sidecar task), T-director (owns, T6); DT56; ADDENDUM 4.9, 9.3

**Evidence.** reviewer's b2_resolver_sweep without the city: routines.feasible FAIL 219 findings, places_exist FAIL 81

### TE4 (major, technical)

**Defect.** The loop digest is not stable over wall-clock time: SaveManager.gather_payload writes /meta/saved_at and /meta/timestamp from the real clock, and a check enshrined 'exactly two volatile paths'.

**Resolution.** digest_volatile.json lists /game/play_time_seconds, /meta/saved_at, /meta/timestamp and /meta/summary; the self-check asserts exactly those paths; town_loop.digest_stable_over_wall_clock compares two digests 1.1 s apart while +1 gold and a flag still move the digest.

**Where.** I2 T2, ADDENDUM 6.1 / 6.3; DT63

**Evidence.** design3/final_editor/te4: two gathers 1.1 s apart differ in /meta/saved_at and /meta/timestamp; old list: digests differ; new list: equal, +1 gold and a flag change it

### TE5 (minor, technical)

**Defect.** Adding farm.map makes `farm` the default start area and two built P04 checks (area.farmable_cells, area.spawns_parsed) that assume the 12 x 12 fixture fail; no package owns tests/sections/area.gd.

**Resolution.** RT6 (P04, a fix-round) gains a task: the fixture-bound checks enter _fixture_iso explicitly and re-enter the start area afterwards; N01's task names it.

**Where.** RT6 task 2, N01 T12

**Evidence.** reviewer: area 236 checks, 0 failed with the fix; a naive 'enter the fixture' breaks two other checks

### TE6 (minor, technical)

**Defect.** RT7 adds five ids to GameUI.SCREEN_ORDER but the built pins (ui_foundation.gd:730, ui_smoke.gd:389: size 16) break.

**Resolution.** RT7 now lists the new order (21 ids; order[0] == hud, order[1] == forest_hud, order[-3] == pause_menu hold) and updates both pins to follow the list.

**Where.** RT7; ADDENDUM 8.10

**Evidence.** reviewer: FAILED ui_foundation.GameUI list (16), ui_foundation.smoke

### TE7 (minor, technical)

**Defect.** `fru_ugle_vurdering` is a dangling shop id (design2's retired DX7 draft; design2's final candidate gives Fru Ugle no ShopSystem shop): towns_data.shop_ids_exist could not pass, her counter was inert, 6 KEEP_ rows were dead.

**Resolution.** Uglehulen is a service row without a shop id; the centre host of its room is kind `appraisal` (game_event open_appraisal, refused while closed, a whisper until DL7); the id is removed from the buildings row, the room wiring, T-greetings (11 shop ids, 61 rows) and section 8.12; towns_data treats timber_yard and natteblik_maps (both wave 4) as late ids listed by name.

**Where.** T-towns-core T1 / T14, T-interiors-core T2, T-greetings T0, ADDENDUM 4.1 / 4.6 / 8.12; DT59; conflict C39

**Evidence.** design2/FINAL/ADDENDUM.md:808

### TE8 (minor, technical)

**Defect.** RT3 renames check ids but tests/tools/mutation_check.py pins the old id and appends exactly five autoloads.

**Resolution.** RT3 lists mutation_check.py (new id, FEATURE_LINES gains SocialManager, a mutant for a sixth line) and runs it at the FR-4 gate.

**Where.** RT3 task 1

**Evidence.** reviewer: mutant reports 'expected to fail but did not'

### TE9 (minor, technical)

**Defect.** N03's S3TC import stubs are 'written by tools/import/write_import_stubs.py', which does not cover assets/iso_props/** and assets/backdrops/**: the kit would stay lossless (65.5 MB, city peak 357.6 MB).

**Resolution.** N03 ships the stubs itself from tools/art/environment/farm/write_farm_imports.py (the same minimal stub as the character sheets); art_farm.s3tc_import_set stays the guard.

**Where.** N03 T5

**Evidence.** reviewer: a hand-written stub gives a 3.95 MB .s3tc.ctex in 4.7.2

### TE10 (minor, technical)

**Defect.** ShopHours' eviction does not wait for a running travel although its comment says so, so a closing tick inside the fade of entering the room leaves the player in a closed shop.

**Resolution.** _evict() waits (without setting `evicted`) while WorldRoot2D.traveling or a sleep sequence runs; check towns_interiors.closing_waits_for_travel.

**Where.** T-towns-core T15

**Evidence.** shop_hours.gd header vs world_2d.gd travel()

### TE11 (minor, technical)

**Defect.** design2's guard checks (DR1 task 10, D2 task 8, DQ E9) hard-code '11 + 5 autoloads, 35 actions, 75 signals' while this addendum adds the sixth autoload and the 36th action.

**Resolution.** The guards compare with the P01 / P02 contracts and assert 'this package adds none' (amendments RT36 for DR1, a task of RT28 for D2, RT37 for DQ); conflict C38.

**Where.** RT28, RT36, RT37

**Evidence.** design2/FINAL/packages.json

### PL1 (major, plan)

**Defect.** Uglehulen is wired to the shop id fru_ugle_vurdering that no package creates and design2's final addendum declares non-existent.

**Resolution.** Same resolution as TE7 (service, counter kind `appraisal`, id removed everywhere, one check that the appraisal request is refused while the building is closed).

**Where.** see TE7

**Evidence.** see TE7

### PL2 (major, plan)

**Defect.** G5b (the first playable town loop) is hard-coupled to five dungeon-track packages through V4.dependsOn (D2, P19): closure of 52 packages incl. D1, D2, DR0, DR1, P19 (12 points); the critical-path text omitted it.

**Resolution.** RT29 removes D2 and P19 from V4's hard dependencies (P19 soft; checker `addSoftDependsOn`), V4's two chain checks SKIP and become DQ's E1 / E2 (RT37); D0 (I2 depends on it: pass-out wake) and DR7 (T-director depends on it: natteblik_maps) stay; checker section I fails on any other dungeon-track package in the closure (49 packages, 34 unbuilt); 9.2 gains the closure text and a sequencing rule.

**Where.** RT29, RT37, I2 / T-director deps, checker I, ADDENDUM 9.2; DT57; conflict C37

**Evidence.** design3/review/plan/out/closure.txt; _final checker output section I

### PL3 (major, plan)

**Defect.** Fix-round tasks of BUILT packages write new checks into sections that the layered table gives to wave 4-5 packages (data.gd, loc.gd, economy.gd V1 / DL1, content_features.gd DL4) and name sections of later waves: 21 task / check pairs.

**Resolution.** Each fix-round amendment has its own section (RT4 data_registry, RT5 economy_hours, RT9 loc_towns; P26 loc_final) or keeps an existing check green; RT2 builds its pristine project inside the tool and leaves content_features.gd alone; the social.* checks of RT2 / RT4 are S-core's; RT8's merge check is in P09's ui_audit section; names of later sections are removed (proven at their own gate). Checker section J fails on any such name.

**Where.** RT2, RT4, RT5, RT8, RT9, RT12, RT19, RT22, RT28, RT33, S-core; DT58

**Evidence.** design3/review/plan/out/verify_cross_owner.txt (before) and checker section J (after: 0)

### PL4 (major, plan)

**Defect.** Two contracts are used one wave before their owner: T-routes (5) names TownMarker.resolve_cells (T-director, 5b); RT11 (P06, 4) makes tool use refuse FarmReserve cells (class of N02, 5).

**Resolution.** The marker collection and the post snap are TownMarks.collect / resolve_cells, statics of a new T-routes file (the bake tool needs both) that TownMarker calls; P06 reaches FarmReserve only through Svc.static_call with a fake-injected check and an absent class means 'nothing reserved'; N02's text and section 3.4 say FarmReserve has two consumers.

**Where.** T-routes T5, T-director T0, RT11 task 5, N02

**Evidence.** ADDENDUM 3.4 / 11.2 patch text

### PL5 (minor, plan)

**Defect.** design_integration.md still contains the retired town name twice and RT3 copies it into docs/design.

**Resolution.** The two occurrences are replaced; build_final.py now asserts that none of the four track documents contains the name.

**Where.** design_integration.md, build_final.py

**Evidence.** grep before / after

### PL6 (minor, plan)

**Defect.** RT7 does not update the two pins on the screen list.

**Resolution.** See TE6.

**Where.** RT7

**Evidence.** see TE6

### PL7 (minor, plan)

**Defect.** G4 requires every L10 check at the wave-5 gate although the merged L10 includes N04-dependent checks (wave 5b).

**Resolution.** L10 is split: l10_seeds_from_shop, l10_till_plant_water, l10_energy_costs are G4; l10_forste_dage_objectives and l10_hint_once_per_save are G5b.

**Where.** I2 T7, ADDENDUM 6.2 / 6.3

**Evidence.** design_integration.md:166

### PL8 (minor, plan)

**Defect.** Production code relies on GameManager.set_config_override (a never-saved test seam wiped by clear_config_overrides()) for the festival bed hold.

**Resolution.** The hold is re-applied from the state query on every flush, load, area change and festival event; check social.festival_bed_hold_survives_load_and_clear.

**Where.** S-core T9, DT25

**Evidence.** game_manager.gd:74, :100-106

### PL9 (minor, plan)

**Defect.** The disjointness proof is valid only under path-exclusion semantics of ownsRemove, which impl/tools/ownership.py does not implement (67 of 69 d3 ownsRemove entries need exclusion).

**Resolution.** check_ownership.py corrects its docstring, emits the effective owners table (`--emit-effective`, shipped as effective_owners.json) and a drop-in lead_tools/ownership.py honours exclusions. PARTLY: the editor may not write impl/; the lead installs the tool (request R-F1).

**Where.** check_ownership.py, FINAL/effective_owners.json, FINAL/lead_tools/ownership.py; DT64

**Evidence.** impl/tools/ownership.py reads only owners[pid]['owns']; make_orders.py removes by exact string

### PL10 (minor, plan)

**Defect.** Requirement 4 says every shop and service is also a walk-in room; the two stalls have outdoor counters only (an exception listed nowhere).

**Resolution.** Listed in DT38 and asked as Q7 (default: the sketch's own form); the stalls get the same talk hosts; honest stub 'Two stalls without a room'.

**Where.** DT38, Q7, stubs

**Evidence.** ADDENDUM 4.1 note

### PL11 (major, plan)

**Defect.** (The text of this defect was cut off in the brief.) E at a shop counter either opens the panel or is 'forwarded to the keeper'; no package implements the keeper side; the hotbar rule contradicts the stub 'no hotbar quick gift'; six of the ten tier A citizens are keepers.

**Resolution.** Resolved together with SE1: the seam and the hotbar rule are removed, the keeper side is the `talk` host; gifts stay in the talk menu.

**Where.** see SE1

**Evidence.** see SE1

## 3. Where the final edit differs from a reviewer's wording, declined or partial

* **TE2, economy.gd:** the reviewer proposed a task on `tests/sections/economy.gd` inside RT5. design2 gave that file to DL1 (wave 4), so P12's fix-round must not edit it: RT5 adds a helper file (no third `static_call(` line) and its own section, and the `_fresh()` switch is DL1's amendment RT35. Same proof (economy 304 checks, 0 failed), different owner.
* **TE3:** the reviewer offered three options; (a) and (b) are combined (sidecar + LevelNav move to T-routes AND a PENDING_AREAS rule for the same-wave rooms), (c) was not needed. The bake also needs `TownMarker.collect`, not only `resolve_cells` (prototype b1_route_bake.gd:46-47): both move to a new T-routes file `town_marks.gd`.
* **SE1:** the reviewer's `talk` hosts are adopted as written (40 x 22); added: the hosts are disabled while no keeper node exists (so waves 5 / 5b stay honest), `NpcDirector.node_of`, the stall geometry (the shop host two cells in front of the keeper so the keeper's own interactable never ties with it), and the replay as a validator rule.
* **SE6:** the 6- and 10-heart scenes are built (S-heart-content M -> L); the **year-2 hook is declined** (roadmap, risk RK16).
* **PL2:** P19 is demoted to a soft dependency with the new amendment key `addSoftDependsOn`; D0 and DR7 stay in the closure (they are real dependencies of the loop); DL7 is NOT required for G5b (Uglehulen's counter whispers until it lands).
* **PL3:** pairs where an EARLIER owner's section is named (S-ui -> ui_conformance rows of P28, T-qa -> P25's docs section, RT29 -> T-director's section of the same wave) are information in the reviewer's own script and are left; every LATER-owner pair is gone (the reviewer's own `review/plan/verify_cross_owner.py`: 21 LATER-wave pairs before -> 0 after).
* **PL9 is PARTLY done:** the editor may not write `impl/`; the repair is shipped as `effective_owners.json`, `lead_tools/ownership.py`, `lead_tools/apply_designs.py` and `lead_tools/install_effective_owners.py` and must be installed by the lead (request R-F1). A per-path comparison of the table that the patched `apply_designs.py` builds from the lead's current owners.json against the proven table found 1,432 differing paths (e.g. P23 and A1 both own assets/icons/home/**: the features layer's carve-outs were lost by make_orders.py's exact-string removal), which the installation removes.
* **PL11:** the text of the last defect was cut off in the brief; it is the plan lens' view of SE1 and is resolved with it.

## 4. Evidence (outputs of the probes and simulations; scripts and logs under `design3/final_editor/`)

### 4.1 SE1 - the counter geometry (`se1/`)
```
TALK ellipse (40.0, 22.0) | over 14 rooms: A 252 / 252, B 126 / 126, C violations 0, keeper-direct selections 0
PLAYTEST start mode=headless character=animal sections=res://tests/sections only=fe_se1
FE_SE1 TOTAL 23760 samples, mismatches vs the Python replay: 0, host histogram { "none": 16794, "T0": 2283, "S": 2833, "T1": 1687, "D": 163 }
FE_SE1 ACCEPTANCE over 14 rooms: A (end cell, facing the counter -> its talk host) 252 / 252, B (middle cell -> shop) 126 / 126, C (talk selected from the middle cell, any facing) 0
PLAYTEST PASS (11 checks in 1 sections, 0 allowed engine messages, 0 known-issue messages)
```

### 4.2 SE1 / SE6 - availability Monte Carlo (`se6/`, 100 runs x 336 days, typical profile, tier A)
```
free_lean                  8h: day 71 (p10 55, p90 97, never 0%)
mixed_lean_nocounter       8h: day 69 (p10 51, p90 154, never 10%)
mixed_lean_counter         8h: day 70 (p10 51, p90 108, never 0%)
day_lean_nocounter         8h: day 81 (p10 45, p90 169, never 20%)
day_lean_counter           8h: day 67 (p10 51, p90 88, never 0%)
free_four                  8h: day 66 (p10 51, p90 90, never 0%)
mixed_four_counter         8h: day 65 (p10 48, p90 101, never 0%)
```

(names: free = anybody can be talked to, mixed = visits at random hours, day / evening = one part of the day, lean = heart events at 4 and 8, four = at 4, 6, 8, 10, counter = keepers reachable at their counters; the table in the addendum 5.5 quotes the same runs)

### 4.3 SE3 - the partner's leave time (`se3/`)
```
citizen            work               opens  walk(min) leave   old 08:00 -> unstaffed(old) farmhouse morning (new)
baker_maja         bageriet           07:00  55        05:00   08:55        115          none (leaves at 05:00, before the day starts)
merchant_pip       froebutikken       08:00  67        06:48   09:07        67           06:00-06:48
gardener_hoppe     -                  no shop hours to cover
carpenter_brumme   brummes_vaerksted  08:00  59        06:56   08:59        59           06:00-06:56
postman_pip        postkontoret       09:00  56        07:59   08:56        0            06:00-07:59
bathkeeper_sofus   badehuset          10:00  47        09:08   08:47        0            06:00-09:08
beekeeper_birk     -                  no shop hours to cover
rasmus             brummes_vaerksted  08:00  59        06:56   08:59        59           06:00-06:56
lamplighter_kiki   -                  no shop hours to cover
bertil             -                  no shop hours to cover
bodil              -                  no shop hours to cover
```

### 4.4 TE1 - the edited wave-4 lifts (`te1/`)
```
BEFORE (the unedited prototypes in a wave-4 tree; reload() 43 = parse error):
BEFORE door_2d reload() = 43
BEFORE hours reload() = 43
BEFORE shop_counter reload() = 0
BEFORE shop_hours reload() = 43
SCRIPT ERROR: Parse Error: Identifier "Routines" not declared in the current scope.
AFTER (te1/drafts, probe fe_probe_towns.gd):
TE1 ok   script hours loads and compiles
TE1 ok   script door_2d loads and compiles
TE1 ok   script shop_hours loads and compiles
TE1 ok   script shop_counter loads and compiles
TE1 ok   script npc_director loads and compiles
TE1 ok   script routines loads and compiles
TE1 ok   script route_table loads and compiles
TE1 ok   script nav_grid loads and compiles
TE1 ok   script fest_set loads and compiles
TE1 ok   Hours.now_ctx is clock-only with the keys (["weekday", "hour", "season", "total_day", "weather", "_gm"])
TE1 ok   Hours.shop_open open on Monday 12:00
TE1 ok   Hours.shop_open closed on Monday 06:00 (new-game clock)
TE1 ok   switch off: Hours.shop_open answers null
TE1 ok   Door2D home without Routines is closed (away) (away)
TE1 ok   NpcDirector.is_present answers through the registry without TownDirector
TE1 ok   NpcDirector.node_of returns the live keeper node
TE1 ok   talk host enabled while the keeper stands in the room
TE1 ok   talk host forwards to the keeper's interact
TE1 ok   talk host disabled (inert) without a keeper node
TE1 ok   shop host half axes 150 x 40, talk 40 x 22
TE1 ok   appraisal counter refuses while the building is closed (["HOURS_CLOSED_DAY"])
TE1 ok   desk emits open_home_builder {tier} ([["open_home_builder", { "tier": 1 }]])
TE1 ok   closing tick during a travel: no eviction, evicted stays false ([])
TE1 ok   next tick after the travel: evicted and area_change requested ([["hyggebyen", "from_int_froebutikken"]])
TE1 SUMMARY fails=0
```

### 4.5 TE2 - the hours switch (`te2/`)
```
(a) hook + stand-in registry, built economy.gd UNCHANGED:
  ok    economy.late_binding_via_svc (shop_system.gd calls ShopRotation.stock and PriceCurve.final_price through Svc.static_call (2 call sites), with no load / ResourceLoader / callv / signature helper of its own)
  --    economy: 296 checks, 32 failed, 2 skipped, 0.9 s
== summary: 1 section(s) run, 304 checks (32 failed, 2 skipped), 0 engine error(s), 0 engine warning(s), 0 allowed message(s), 0 problem(s), 0 known-issue message(s), 4.2 s
(b) economy.gd _fresh() sets towns.hours_enabled = false:
PLAYTEST start mode=headless character=animal sections=res://tests/sections only=economy
  ok    economy.late_binding_via_svc (shop_system.gd calls ShopRotation.stock and PriceCurve.final_price through Svc.static_call (2 call sites), with no load / ResourceLoader / callv / signature helper of its own)
  --    economy: 296 checks, 0 failed, 2 skipped, 0.8 s
== summary: 1 section(s) run, 304 checks (0 failed, 2 skipped), 0 engine error(s), 0 engine warning(s), 0 allowed message(s), 0 problem(s), 0 known-issue message(s), 4.2 s
PLAYTEST PASS (304 checks in 1 sections, 0 allowed engine messages, 0 known-issue messages)
(c) core + save + data + content_features + economy with (b):
PLAYTEST start mode=headless character=animal sections=res://tests/sections only=core,save,data,content_features,economy
  --    boot: 8 checks, 0 failed, 0 skipped, 2.1 s
  --    content_features: 141 checks, 0 failed, 0 skipped, 5.1 s
  --    core: 111 checks, 0 failed, 1 skipped, 0.2 s
  --    data: 314 checks, 0 failed, 1 skipped, 3.4 s
  --    economy: 296 checks, 0 failed, 2 skipped, 0.9 s
  --    save: 234 checks, 0 failed, 2 skipped, 4.4 s
== summary: 5 section(s) run, 1104 checks (0 failed, 6 skipped), 0 engine error(s), 0 engine warning(s), 19 allowed message(s), 0 problem(s), 0 known-issue message(s), 17.4 s
PLAYTEST PASS (1104 checks in 5 sections, 19 allowed engine messages, 0 known-issue messages)
```

### 4.5b TE3 - the resolver sweep with the city data present (reviewer's run, `review_r2_technical/towns_out/b2_resolver_sweep.r2.txt`)
```
B2 RULE routines.feasible            PASS
B2 RULE routines.places_exist        PASS
B2 RULE hours.keeper_covers_hours    PASS
B2 RULE hours.consistency            PASS
B2 RULE routines.post_capacity       PASS
B2 RULE towns.visual_budget          PASS
B2 RULE routines.no_short_visits     PASS
B2 RULE routines.day_wrap            PASS
B2 RULE hours.visits_inside_hours    PASS
B2 CORE-ONLY: 23 citizens, 20 buildings, 14 rooms; 74 places degrade to a door (homes of the EXTENDED rooms), 14 optional places dropped; all rules pass: true; worst visuals { "n": 13, "wd": 1, "hour": 17.1666666666667 }
```
(without the city the same rules FAIL: routines.feasible 219 findings, routines.places_exist 81; the sidecar and LevelNav now bake the city in wave 5, an unbuilt room is a pending area)

### 4.6 TE4 - the loop digest (`te4/`)
```
TE4 meta keys: ["version", "timestamp", "saved_at", "summary"]
TE4 paths that differ between two gathers 1.1 s apart (nothing else changed): ["/meta/saved_at", "/meta/timestamp"]
TE4 OLD list: digests equal = false
TE4 NEW list: digests equal = true
TE4 NEW list has teeth: +1 gold changes the digest = true, a flag changes it = true
```

### 4.7 PL2 - the G5b closure (reviewer's own `review/plan/closure.py` on the new candidate, `out/closure_after.txt`)
```
d3 CORE only closure 46 unbuilt 31
   d3 [('4', 'N01-farm-map'), ('4', 'S-core'), ('4', 'T-towns-core'), ('5', 'I1-copy-system'), ('5', 'I2-loop-harness'), ('5', 'N02-farm-objects'), ('5', 'N03-farm-art'), ('5', 'S-data'), ('5', 'S-gifts'), ('5', 'S-talk'), ('5', 'T-interiors-core'), ('5', 'T-routes'), ('5b', 'I3-art-shops'), ('5b', 'N04-farm-first-morning'), ('5b', 'S-ui'), ('5b', 'T-director')]
   d2 [('4', 'D0-dungeon-world-hooks'), ('4', 'DR7-dungeon-services'), ('4', 'V1-cast-data'), ('4', 'V2-cast-art'), ('4', 'V3-levels'), ('5', 'V6-city-life')]
   base [('4', 'F2-home-core'), ('4', 'F4-loot-shops'), ('4', 'P06-player-farm-core'), ('4', 'P11-maps-iso'), ('4', 'P13-quests-lua-runtime'), ('4', 'P17-ui-hud'), ('4', 'P18-ui-shop-inventory'), ('4', 'P22-art-environment'), ('5', 'P14-npc-dialogue')]
d3 CORE + V4-city-map closure 49 unbuilt 34
   d3 [('4', 'N01-farm-map'), ('4', 'S-core'), ('4', 'T-towns-core'), ('5', 'I1-copy-system'), ('5', 'I2-loop-harness'), ('5', 'N02-farm-objects'), ('5', 'N03-farm-art'), ('5', 'S-data'), ('5', 'S-gifts'), ('5', 'S-talk'), ('5', 'T-interiors-core'), ('5', 'T-routes'), ('5b', 'I3-art-shops'), ('5b', 'N04-farm-first-morning'), ('5b', 'S-ui'), ('5b', 'T-director')]
   d2 [('4', 'D0-dungeon-world-hooks'), ('4', 'DR7-dungeon-services'), ('4', 'V1-cast-data'), ('4', 'V2-cast-art'), ('4', 'V3-levels'), ('4', 'V7-dialogue-v2'), ('5', 'V5-art-city'), ('5', 'V6-city-life'), ('5b', 'V4-city-map')]
```

### 4.8 PL3 - verify names of a later section (reviewer's `review/plan/verify_cross_owner.py`)
```
LATER-wave owner rows: 0
```

### 4.9 The ownership proof (`check_ownership.py`, output of `out/check_ownership.txt`) and its self-test
```
== ownership check: MERGED design3/FINAL/packages.json (the packages.json next to this file)
layers: owners.json + features amendments + design_ui + design2/FINAL + design3
packages in table: 99 | new in this addendum: 32 | amended by it: 12 | include patterns: 891 | exclusion patterns: 187
A  language intersection: 308 pattern pairs with comparable literal prefixes tested over ALL packages, 0 overlaps
B  repo expansion: 3514 tracked files | 0 with several owners | 335 owned by nobody | 0 claimed by a new package
C  ownsRemove sanity (all layers): 0 problems
D  dependencies / waves / tiers / verify tags / schema: 0 problems
E  named paths: 174 concrete paths named in tasks | 0 owned by nobody or ambiguous | 9 cross-package mentions (info)
F  localization: 54 files in the merged key table, 1248 existing keys re-resolved | 0 problems | 12 same-wave couplings (info)
G  contracts: 25 game_events, 12 marker_types, 6 ui_screens | 0 problems
I  G5b closure: the 16 CORE packages + V4-city-map reach 49 packages by hard dependencies, 34 of them unbuilt | dungeon-track members besides D0 / DR7: 0 | D0 in, DR7 in, P19 out | 0 problems
J  verify names: 10 names of sections owned by another package checked | 0 name a section of a LATER wave
H  load per wave (S=1 M=2 L=3 XL=4): 3b: 2 | 4: 65 | 5: 62 | 5b: 27 | 6: 28 | 7: 15
   tiers of the new packages: CORE 16 | EXTENDED 11 | LATER 1 | QA 4

OK: every pattern of every package of every layer was intersected with every other; no overlap, no repo file with two owners, dependencies point to strictly earlier waves, contracts are unique.

  mutant claims a built file (iso_area.gd)                                      CAUGHT (5 findings)
  mutant two new packages own the same pattern                                  CAUGHT (1 findings)
  mutant P22 carve-out of the farm art dropped                                  CAUGHT (14 findings)
  mutant P11 carve-out of farm.map dropped                                      CAUGHT (1 findings)
  mutant a package depends on itself                                            CAUGHT (2 findings)
  mutant forward dependency (wave 4 -> wave 5)                                  CAUGHT (2 findings)
  mutant CORE depends on EXTENDED                                               CAUGHT (2 findings)
  mutant task without verify                                                    CAUGHT (1 findings)
  mutant duplicate game_event name                                              CAUGHT (1 findings)
  mutant save section order collides with loot (40)                             CAUGHT (1 findings)
  mutant second input action shares the key P                                   CAUGHT (1 findings)
  mutant marker handler script owned by another package                         CAUGHT (1 findings)
  mutant amendment targets an unknown package                                   CAUGHT (2 findings)
  mutant V4 depends on D2 again (the G5b closure holds the dungeon generator)   CAUGHT (5 findings)
  mutant a fix-round task names a check of a LATER section                      CAUGHT (1 findings)
  mutant an amendment demotes a package that does not exist to soft             CAUGHT (2 findings)
selftest: all mutants caught
```

### 4.10 PL9 - the old and the patched ownership gate on an excluded path (`lead_tools/`)
```
old tool, P12 writes lua/shops/festival_markets.lua, lua/shops/seed_shop.lua, tests/sections/economy.gd:
  changed files: 3 | owned by this wave: 3 | owned by other waves: 0 | owned by nobody: 0
patched tool, same files:
  changed files: 3 | owned by this wave: 1 | owned by other waves: 2 | owned by nobody: 0
    FOREIGN lua/shops/festival_markets.lua -> S-fest-content
    FOREIGN tests/sections/economy.gd -> DL1-econ-store
```

## 5. Hand-over to the lead

1. Copy `ADDENDUM.md` and `packages.json` as before (RT3 copies them into `docs/design/`); the four track documents are scrubbed of the retired town name.
2. `lead_tools/README.md`: install `install_effective_owners.py` (writes impl/owners.json from `effective_owners.json`), `ownership.py` and, if orders are regenerated, `apply_designs.py` (it honours `removeDependsOn`, `addSoftDependsOn` and path exclusions).
3. The fix-round (RT1-RT9) is executed before wave 4 in the stated order; RT35 (DL1) is an ordinary wave-4 task, RT36 / RT37 touch design2 packages and are listed as such in conflicts C37 / C38.
4. Re-run `python3 -I check_ownership.py` (and `--selftest`) after any edit of packages.json: sections I and J now guard the G5b closure and the verify names.

## 6. How to reproduce

```
python3 -I design3/FINAL/_build/run_all.py          # packages.json, key_owners_additions.json, check_ownership.py + outputs, ADDENDUM.md (relocatable: runs in the folder that holds _build)
python3 -I design3/FINAL/_build/make_changelog.py   # this file and OPEN_QUESTIONS.md
python3 -I design3/FINAL/check_ownership.py [--selftest | --raw | --emit-effective FILE]
python3 -I design3/final_editor/patch_parts.py     # the prose patches of the hand-written parts (idempotent; applied once)
```

