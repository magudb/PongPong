# TOWNS, FARM AND SOCIAL ADDENDUM - the treetop farm, two towns people live and shop in, and the social sim

Status: **binding** merged addendum (2026-10-14) of the four design3 tracks (farm N, towns T, social S, integration I). Written by the editor from the four track documents, their package files and prototypes, the five analyst reports, design2's dungeon / v2 addendum (`design2/FINAL`, committed as `docs/design/DUNGEON_V2_ADDENDUM.md`), the UI navigation spec (`design_ui`) and `impl/owners.json`.
Companions: `packages.json` (the work packages, schema of `docs/design/features_workpackages.json`: 32 new packages, 37 amendments RT1..RT37, contracts, decisions, acceptance rows), `key_owners_additions.json` (the CSV families, merged), `check_ownership.py` (the disjoint-ownership proof, output in section 15).
Repo read: `main` @ bba4363 (waves 1-3 built). The tracks measured at 2f6410b; the merge ff802c7 (UI conformance: `docs/design/UI_NAVIGATION.md`, `docs/design/ui_workpackages.json`, the UI audit library `tests/lib/ui_audit*.gd`, `tests/lib/ui_screens.json`, three `ui_audit*` sections) landed while this addendum was written and touches nothing the tracks measured; the landed navigation spec and package file are byte-identical to the design_ui files the checker reads, and the landed registry already accepts spec-shaped rows with a derived status (no scene = pending, a scene = live), so the six new screens add their rows through `tests/lib/ui_screens.d/*.json` (RT8). Nothing in the repo or the lift was edited. The final edit of 2026-10-14 (CHANGELOG.md) repaired the defects four adversarial reviews proved: section 11.3 lists each one.

**Precedence (DT1).** This file and `packages.json` win over `PLAN_2D.md` and `PLAN_2D_FEATURES.md` for the towns, the farm, the citizens and the social sim. They never override design2's dungeon addendum (zone graph, floors, loot, the v2 cast and the city) or `UI_NAVIGATION.md`, except for the repairs of section 11 (conflicts C12 and C21-C25) and the cross-track fixes DT14-DT16, DT47-DT49. The four track designs (`design_farm.md`, `design_towns.md`, `design_social.md`, `design_integration.md`) stay as the detailed reference; where one of them differs from this file, this file wins and says why (section 11).
**Names.** The retired town name is never written (DT40): the town is **Hyggebyen**, the farm is **Min Trækronsgård**, the city is **Trætoppen**. Package ids, check ids and file paths are code.
**"E1" disambiguation.** The farm design calls its field expansion "E1" (the 42-cell zone behind the stake sign). The sanctioned shared edit E1 of the feature addendum is the `project.godot` autoload append. Here the zone is "the field expansion" (marker `field_expansion`) and E1 means the autoload rule only.

---------------------------------------------------------------------------------------------------------------------------------------------

## 0. The answer in 40 lines

1. **One world, three places and 24 rooms.** `farm` (Min Trækronsgård) -- ONE hanging bridge -- `traetoppen` (the treetop city: seven giant trees, Torvet, Rådhuset on the middle tree, the post office, Hoppe's hut, Brumme's workshop, the bathhouse) -- ONE bridge -- `hyggebyen` (the fairy shopping district, zone id `city`). Every shop and service is also a walk-in room (24 rooms: 14 CORE, 10 EXTENDED) entered through a door marker; the shop panel of guide section 07 opens over the live room.
2. **The farm is a limb of the canopy, not an island.** One contiguous wooden deck, 61 x 51 cells (1,206 ground cells), a house terrace in front of a giant trunk, a fenced 84-plot field (+42 behind a stake sign for 800 g), a pond lobe, an animal lobe with coop, barn and house slots, an orchard on its own rope-bridged platform, a 9-plank hanging bridge to Trætoppen (the only warp). Five stages grow with the ten house tiers. The map is real: loaded headless with `map.errors` empty, 43 probe checks, 8 mutants caught, 20 windowed shots looked at.
3. **A first morning that sends you over the bridge.** Pip the hedgehog postman greets you at the mailbox, Fekongen's letter is read, the quest "Gårdens første dage" starts, ten whisper hints guide the first days; all of it is Lua and CSV data driven by a 100-line runner; Esc skips it.
4. **30 citizens with routines.** The 15 of today + the 7 of design2's v2 cast + 8 new from unused character bodies. Each has ONE Lua registry file of timed plans and select rules (44 KB for all 30). Presence is a pure function: `Routines.where_is(npc, ctx)` = 7-9 microseconds, walking times from a route table baked from the real nav grids, no simulation, no saved positions.
5. **A director that makes it visible.** `TownDirector` (a child of the area, created by ONE `town` marker) keeps exactly the wanted citizens alive, frees every node on exit (0.045 ms per physics frame for a whole game day in Hyggebyen, up to 14 live; hard cap 16 distinct looks per area).
6. **Stores have hours.** ONE rule (`Hours.state`) closes the door, `ShopSystem.is_open`, the closing sequence (a whisper 30 minutes before, the bell, you are shown out) and the festival closure. Each shop is closed exactly one weekday; 7-10 of 10 shops are open at noon on every day. In every room the keeper stands behind a 3-wide counter: E on the middle cell opens the shop panel, E on an end cell opens the keeper's own dialogue (hearts, gifts, quests); the builder yard has a desk as a second door to the home ladder.
7. **A full social sim, one writer.** `SocialManager` (the sixth feature autoload, E1) is the only writer of friendship: 0-10 whole hearts, 100 points each, the first FINISHED conversation of a calendar week gives exactly one heart (the DF3 floor), gifts by taste (40 / 20 / 8 / 0 / 0, birthday x4, 1 per day and 2 per week), 30 birthdays shown in a Kalender tab of the journal, nine town festivals + the wedding, heart events you start by talking, and marriage-style relationships (bedste ven -> hjertven -> forlovet -> gift, no gender gate, no break-up).
8. **Tiers.** CORE = what the first playable town loop needs (gate G5b): the farm, the 14 rooms, 23 citizens, hearts, talk, gifts, birthdays, the People book and the HUD chips, the first morning. EXTENDED = festivals, heart events, the 10 more rooms, the post screen, keeper greetings, art dressing. LATER = marriage-style (wave 6, built last). QA = four acceptance packages.
9. **The town loop is a test.** `town_loop` (I2, wave 5): 19 legs, about 90 named checks, real input, real UI, real save: new game -> first morning -> bridge -> Trætoppen -> talk (hearts) -> seed shop interior -> panel -> buy (hours) -> gift -> post office -> farm -> till / plant / water -> sleep -> citizens moved by routine -> save / load -> same state. Gates G4, G5, G5b, G6, G7 turn skipped legs into failures.
10. **No new engine surface beyond one autoload and one action.** 0 new EventBus signals (25 new `game_event` names), 1 new input action (`people` = P), 1 new autoload (`SocialManager`), 1 new save section (`social`, order 60), 1 new Lua kind (`registry`), 12 new marker types, 6 new screens or surfaces, 17 new CSV files.
11. **32 new packages and 37 amendments.** 16 CORE, 11 EXTENDED (one of them, the greenhouse, gated on a question), 1 LATER, 4 QA. 104 amendment tasks of the four tracks became 95 after the merge (one amendment per existing package, RT1..RT34, plus RT35-RT37 appended by the final edit; nine are fix-rounds of BUILT packages executed in a fixed order before wave 4, each with a section of its own).
12. **Disjoint ownership is proved over everything.** `check_ownership.py` intersects every pattern of all 99 packages of the five layers as regular languages: 0 overlaps, 0 tracked files with two owners (the merged table also repairs 34 pattern overlaps and 13 doubly-owned files that design_ui had left between P07, P28, P17, P14 and P27), dependencies strictly earlier, the G5b closure holds no dungeon-track package except D0 and DR7, no fix-round task names a check of a later section, 16 mutants caught.
13. **Waves.** 4: N01, S-core, T-towns-core (65 points with everything else of the plan); 5: farm objects and art, routines and the city bake, the 14 rooms, talk and gifts, the copy system and the loop harness (62); 5b: the director, People book, first morning, kit (27); 6: EXTENDED content (28); 7: QA (15). CORE before EXTENDED; no forward dependencies; the load is stated and the deferral order is written down (DT36).
14. **Decisions the editor made where tracks disagreed** (41 conflicts, section 11): farm.map is N01's; hours live in the buildings registry; festival posts are ONE set marker per spot; festival decor is one mechanism (I5); the dress marker reads the world flag `festival_now`; Pip counts as met; citizens without a dialogue file can still be talked to; QA packages never hard-depend on EXTENDED ones; one data-only proof (L18); the plan header gains a new line instead of a rewrite.
15. **Questions only you can answer** (section 16): a greenhouse for winter, the marriage-style vocabulary and items, the hero-twin rule, the voice listening test, the timing of the native Danish review, the night watch, the two outdoor stalls. Each has a default the build follows.

---------------------------------------------------------------------------------------------------------------------------------------------

## 1. User decisions (binding, 2026-10-13) and where each is answered

| # | Requirement | Answer in this addendum | Owners (packages) | Verified by |
|---|---|---|---|---|
| 1 | The two towns are USABLE with citizens and stores. Trætoppen = the treetop city of `refs/miljoer_v2_render.png` (seven giant trees, circular platforms around trunks, market square + Rådhuset in the middle tree with a ladder, the post office (Pip), Hoppe's hut, Brumme's workshop, the bathhouse (Sofus, restores energy), kitchen gardens, rope bridges, owl holes, hanging bat houses). Hyggebyen (the retired name is never written) = the fairy shopping district inside it with its own zone | sections 2, 4: the city is design2's V3 / V4 / V5 / V6 (levels, map, art, life); THIS addendum fills it: 30 buildings with doors, 24 walk-in rooms, 30 citizens by routine, the director, hours; the sketch labels map to buildings in 4.1 (bathhouse = `int_badehuset` with V6's bath tub, owl hole = `int_uglehulen`, bat house = the Natteblik window, kitchen gardens = Bertil's shed `koekkenhave_skuret`, his `g_planter` posts and the planter nodes of P19 (design2) on level G) | T-towns-core, T-routes, T-interiors-core, T-director (CORE); V1, V3-V6 (design2); P11 (hyggebyen.map) | acceptance rows 32, 34, 36, 46, 47 |
| 2 | The player's FARM "Min Trækronsgård" is the TREETOP FARM on its own branch; guide mock = isometric treetop farm with fields and a hanging bridge (`style_guide_render.png` section 06); the visual language of the city sketch (round wooden platforms, rope bridges, lanterns) | section 3: a limb of the canopy with wings, pillars on trunks, a canopy frame, lantern posts, two rope bridges; designed, prototyped and measured | N01, N02, N03, N04 (CORE); N05, N06 (EXTENDED); N07 (gated); N08 (QA) | rows 31, 45, 50 |
| 3 | CITIZENS = FULL SOCIAL SIM: daily routines, hearts / friendship, gifts, birthdays, festivals / events, marriage-style relationships (cozy, child-friendly; eligibility NOT gender-gated) | sections 4.7-4.9 (roster, routines, engine), 5 (hearts, gifts, birthdays, festivals, events, marriage-style); no gender field exists anywhere, eligibility is `partner = true` on 11 citizen rows | S-core, S-data, S-talk, S-gifts, S-ui (CORE); S-events, S-heart-content, S-fest-content (EXTENDED); S-marriage (LATER); S-qa | rows 33, 35, 40-44 |
| 4 | STORES = WALK-IN INTERIORS: every shop / service is also a room you walk into (keeper behind a counter), then the guide's shop panel (section 07: panel over the blurred shop interior with the keeper half-figure and greeting); shops have opening hours and closed days | sections 4.2-4.6: 24 rooms built from data, the counter band with its three kinds of host (the middle cell opens the panel, the end cells open the keeper), ONE hours rule, the closing sequence, keeper greetings by hearts; the panel is P18's, amended | T-towns-core, T-interiors-core (CORE); T-ext-content, T-greetings (EXTENDED); I3 (kit); P18 | rows 34, 36 |
| 5 | Characters of the v2 sketches cast the main NPCs (Hoppe, Brumme, Morfar Mis, Natteblik, Rasmus, Bertil / Bodil Bøgeknop, Kløvermynte / Birk, Pip, Fru Ugle, Sofus, Kiki) plus the 36-character roster | section 4.7: all 12 figures are citizens with a home, a workplace, a routine and (for the four playable lookalikes) the hero-twin rule; the 36-character roster supplies the bodies of the 8 new citizens | V1, V2 (design2), T-routes, T-ext-content | row 46 |
| 6 | Standing rules: rarity tiers normal / uncommon / rare / unique / legendary; Lua extensibility (new NPCs, events, festivals, quests by data without editing code); all copy in localization CSVs; honest stubs, nothing half-wired; headless + windowed tests; UI follows the guide and the navigation spec | rarity: gifts use the item rarity (x1.25 / x1.5, keepsakes never giftable), farm dig / unique spots use F1's data; Lua: the `registry` kind, 13 config keys, `tests/fixtures/town/**` and leg L18 prove "zero .gd / .tscn changed"; copy: 17 new CSV files, a style sheet and a lint; stubs: section 14; tests: section 6; UI: six screens each with a registry row, a baseline and the 9 standard checks | all | rows 39, 48, 51 |

**What the editor decided on the user's behalf** (each is a data value or one input-map line; the build follows it unless the user says otherwise; DT38): the shipping bin pays at ratio 1.0, the pond stays decoration, a citizen's home opens from 1 heart (`friend_<npc> >= 1`), the mayor commutes Tuesday to Thursday, the inn sells nothing, the `Hvor er ...?` list is built in wave 6, festival music and ambience are synthesised placeholders, festivals hold the bed until they end, the People key is P.
**What only the user can decide** (section 16): the greenhouse (Q1), the marriage-style vocabulary and items (Q2), the hero-twin rule (Q3), the voice listening test (Q4), the timing of the native Danish review (Q5), the night watch (Q6).

---------------------------------------------------------------------------------------------------------------------------------------------

## 2. The world in one page

### 2.1 The zone graph, the spawns and the walk

```
 farm  "Min Trækronsgård"  ==9 planks==>  traetoppen  "Trætoppen" (8 levels, 9 bridges, a ladder, the Skovlift)  ==bridge==>  hyggebyen (zone id city)
   |  spawns: default, from_home, from_traetoppen          spawns: default, from_farm, from_hyggebyen, from_skovlift       spawns: default, from_traetoppen, 14 x from_int_<building>
   |  the ONLY warp: traetoppen:from_farm                  the Skovlift goes down to Mørkeskoven (design2); 13 doors (12 huts + Rådhuset) and 3 gates     14 door markers -> int_<building>
   +-- the forest sign SIGN_FARM_FOREST stands where the Skovport was (REMOVED)
 interiors int_<building> (24): spawn default; the exit lands on from_int_<building> of the outer area, 0.0 px from the spawn, no re-trigger
```

Walking (measured, `towns_scripts/out`, farm probe): door to the end of the hanging bridge 2,715 ground px = 9.5 s walking, 6.0 s running; farm door to the Hyggebyen gate about 20 s; inside Trætoppen anchor to anchor 15.4 s p50 / 35.1 s max; inside Hyggebyen 7.9 s p50 / 17 s max; a citizen walks at 0.65 x the player's 285 px/s = 185 px/s, so Pip needs 65 game minutes (about 33 real seconds) from the post office to the farm mailbox. 2 game minutes pass per real second; the day has 18 playable hours.

### 2.2 A day in the loop (what the player meets, in the order the packages deliver it)

* **Day 1, 06:00, the farm.** You wake at `default`. Pip is at the mailbox with Fekongen's letter. Control returns after about 25 s; the hoe is in slot 1. The five free turnips are the first crop (ready on day 5, 225 g). The seed shop is not needed on day 1 (opening hours cannot block the tutorial).
* **The bridge.** Walk south, over the nine planks, past the lantern posts. Trætoppen is a place with people on it: at noon about 5-7 citizens are outdoors in the city, 3-6 in Hyggebyen in the morning and 9-13 there on a Sunday afternoon (the visual validator measures peaks of 11 in Trætoppen, 14 in Hyggebyen, 12 in the inn).
* **Talk.** Walk up to Hoppe, E: the first meeting line, the dialogue, the weekly heart (one heart for the first FINISHED conversation of the week; Esc after the first line gives none), a toast with the sprouted friendship heart. "Giv en gave" is a choice of the talk menu; the picker opens after the dialogue has ended.
* **Shop.** Hyggebyen's seed shop is a door with a sign: `Kløvermyntes Frø - åbent 8-18`, closed Sundays. At 08:30 on a Monday you walk in, the keeper stands behind a 3-wide counter, E on the middle of the counter opens the shop panel over the live room, and one cell to the side E talks to the keeper (hearts, gifts, quests). At 17:30 a whisper says the shop closes in half an hour; at 18:00 the bell rings and you stand on the doorstep.
* **Post office, bath, town hall.** Pip's counter (letter of the day, `Hvor er ...?` from wave 6), Sofus' tub (V6: half an hour, energy restored), the Rådhus board (V6: everyday quests). All three are rooms with the handler of their own owner inside.
* **Night.** At 23:30 a whisper, at 23:45 the night watch sends you home to `farm:from_home`; the bed opens at 18:00. Next morning the citizens stand elsewhere: Pip at the farm mailbox from day 2, Hoppe at the farm fence on Wednesdays from 15:00 with 2 hearts, the mayor on the long walk to the Rådhus Tuesday to Thursday.
* **Festivals.** Nine fixed days a year (and the wedding) close the shops they should, hold the bed until the end and gather the citizens on 24 standard posts of the festival spot; decor (wave 6) and music are placeholders.

### 2.3 The cast and the places (who stands where, in one table)

| Place | Who works / lives there | Rooms |
|---|---|---|
| **Hyggebyen** (grid map `hyggebyen.map`, P11) | Kløvermynte (seed shop), Rosmarin (bakery), Thorin (smithy), Rosa (animals), Zephyr (magic), Stokrose (furniture), Fingerbøl (tailor), Hasselnød (timber), Pippin (flea loft), the king (EXTENDED room), the mayor's house, Birk's hives, Pippin's house, the postal penguin's house | 9 shop rooms CORE; king, mayor, Pippin, Birk EXTENDED |
| **Trætoppen** (levelled builder, V3 / V4) | Pip (post office), Sofus (bathhouse), Fru Ugle (Uglehulen), Brumme (workshop; weekend stall at Torvet), Natteblik (bat window, evenings), Fjerpen (Rådhus counter), Hoppe, Kiki, Bertil, Bodil, Kvak (the inn), Strimmel, Oak, Bamse | post office, bathhouse, Rådhuset, Uglehulen, Brumme's workshop CORE; inn, Hoppe's hut, Brumme's house, the guard hut, Kiki's hut, the music room EXTENDED |
| **farm** (N01) | the player; Pip visits from day 2, Hoppe on Wednesdays | the house (F6's HomeRoom) |

---------------------------------------------------------------------------------------------------------------------------------------------

## 3. The treetop farm "Min Trækronsgård" (packages N01-N08)

### 3.1 What it is (DT4-DT7)

ONE contiguous wooden limb that grows out of the great trunks, with wings: a field lobe and a pond lobe to the west, an animal lobe to the south-east, an orchard terrace on its own platform to the north-west (a 7-plank rope bridge), a 9-plank hanging bridge that leaves the boulevard at the south and ends in the city. The house stands on a plank terrace at the north-east rim in front of a giant trunk (the sketch's central image). Far trunks and leaf masses stand behind, a leaf frame and falling leaves in front, pillars of trunk under the deck, lantern posts, a round fenced field, a pond, a bench, a scarecrow.

```
        orchard terrace (NW satellite platform): trunk_giant_b, tree hollow, 3 apple trees, 2 signs, bench
              |  7-plank rope bridge
 field lobe --+-- house terrace (planks, NE, against trunk_giant_a): door D, bed, mailbox, bin, shed, tent
  F0 84 plots |        front yard + plaza (grass, path, lantern posts, fountain slot, bench)
  (fence ring)|        field expansion (42 cells, a rope ring while locked) east of the boulevard
 pond lobe ---+        animal lobe (SE): yard r=3, coop 3x2, barn 4x3, house 3x2, greenhouse slot 4x3
              |
   boulevard (path) south to the bridgehead ---- 9-plank hanging bridge ---> Trætoppen (spawn from_farm)
```

| Item | Value (source: `design3/farm/out/farm_probe.final.txt`, 43 checks, `fails=0`) |
|---|---|
| Grid / ground | 61 x 51 = 3,111 cells, 1,206 non-void; `.` grass 645, `,` 44, `;` 26, `p` path 117, `d` deck planks 227, `=` bridge planks 16 (9 hanging + 7 orchard), `f` field 84, `~` water 47 |
| Header | `@id farm @title ZONE_FARM @projection iso @ambient farm @theme farm @zone farm @flight true @music farm_theme` |
| Play area | 3,520 x 3,382 px = 1.10 x 1.88 screens at zoom 0.4; door cell D at file (35, 15) |
| Built area | 496 nodes (124 prop sprites, 111 skirt pieces, 76 colliders, 11 point lights + 11 halos) |
| Warp / spawns | exactly ONE warp (`to=traetoppen spawn=from_farm label=ZONE_TRAETOPPEN`); spawns `default` (1,4), `from_home` (0,2), `from_traetoppen` (0,29), three planks before the warp (cells local to the door cell D); no `from_skovport`, no lift marker |
| Posts (the contract with the towns routines) | `pip_mailbox`, `hoppe_fence`, `bench_a`, `porch`, `field_edge` (`post name= facing= act=`) and ONE `town curfew=false` anchor |
| Walk | door to the end of the bridge 2,715 px = 9.5 s walking (a real body walks it in 559 physics frames, the warp fires once); every marker (35 targets) and every one of the 84 plots is reachable |

### 3.2 Five stages with the ten house tiers (DT6)

| Stage | Name | Home tiers | Growth rows | Deck under the house | Dress that switches on (EXTENDED, N05) |
|---|---|---|---|---|---|
| 1 | Spiren | 1-2 | 0 | 9 x 3 = 27 | the little hut, the tent |
| 2 | Kvisten | 3-4 | 0 | 27 | flower boxes (tier 3) |
| 3 | Grenen | 5-7 | 1 | 9 x 4 = 36 | a second storey, the garden arch (tier 5) |
| 4 | Kronen | 8-9 | 2 | 9 x 5 = 45 | the fountain (tier 8) |
| 5 | Slottet | 10 | 3 | 9 x 6 = 54 | royal banners (tier 10) |

The stage is DERIVED from the world flag `home_tier` (F2 keeps it right) and never saved: `FarmStage.of_tier(tier) -> {id, index, rows}` reads `lua/config/farm_site.lua` (`farm_site.stages`); the flag `farm_stage` (1..5) mirrors it; a rising stage during play posts ONE notification. **Anchor contract (F6):** the `home` marker is the DOOR cell, anchor = `Iso.iso_center(cell) + Vector2(-32, 19)`. **Proof:** the 9 x 3 base is deck, the 27 growth cells are void until `set_growth_stage(rows)` (rows by tier 0,0,0,0,1,1,1,2,2,3); the footprint of EVERY tier of `home.json` is deck after its rows (probe C5), `from_home` stays free for the real 25 x 14.8 body at every tier (C6), a mutant without a growth row is caught (C7), no walkable cell lies behind the castle (D1), the roof clears the camera limit by >= 468 px at tier 10.

### 3.3 Fields, crops, money, winter

F0 = 84 plots (12 x 7) behind a fence with one gate; the untilled look is the terrain `field_grass` (+36 batch breaks, 466 -> 502 draw calls). Energy: hoe 3.0, seed 0.5, can 1.5, scythe 2.0; a watering pass over 84 plots = 126 energy (pool 100 at tier 1, 130 at tier 10). Income (model `farm/out/income_model.txt`): carrot is the best crop in every season (5.05 / 6.22 / 7.32 g per plot and day at 55 / 70 / 85 % efficiency); typical player 129 g/day on day 7 and 328 on day 28, never needs more than 84 plots; a dedicated one fills 84 plots by day 20 and the **field expansion** (42 cells, 800 g) pays back in 4.2 days. **Winter earns nothing** in the plan's data (28 of 112 days): a quiet winter of craft, mining, forest and town is the default; the greenhouse (N07) is the answer only if the user says yes to Q1.

### 3.4 The yard objects (N02, CORE)

* **Field expansion** (`field_expansion id=east cells=x0..x1,y0..y1 price=800`): a stake sign + a ring of 22 `rope_stake_x/z` while locked; E opens `UiConfirm` S08 (default focus Fortryd); yes = `EconomyManager.spend_gold(800)`, then through the PUBLIC IsoArea API only (`set_ground f`, `farmable`, `set_terrain field_grass`, `remove_prop`) in 4-8 ms (**P04 needs no edit**), the area flag `zone_east = 1`, `plot_unlocked("zone:east")`, `game_event field_expanded`. A zone that is already unlocked is replayed without ropes on every enter. Persisted as an AREA flag; `FarmGrid.to_dict` stays plots only (P06 amendment).
* **Shipping bin** (`shipping_bin`): no UI; E puts the WHOLE selected hotbar stack into the bin when its category is crop / product / forage, else the whisper FARMSITE_BIN_REFUSE; contents are integer area flags `bin_<item>`; at `day_started` it pays `sell price x farm_site.bin.pay_ratio` (1.0 = the seed shop's price: a convenience, never an arbitrage), empties and posts one notification; events `bin_shipped`, `bin_payout`.
* **Tool shed** (`tool_shed`): E emits `game_event open_home_chest` (F7's Hjemkiste must open from ANY area).
* **Mailbox** (`mailbox prop=mailbox_red`, V6's PostBox2D): day 1 is EMPTY (Pip delivered in person); from day 2 opening it emits `post_read` once per day, also for an empty letter.
* **Orchard** (3 `node apple_tree`, the `unique_spot trae_hulning`, SIGN_ORCHARD), **pond** (47 water cells, decoration only), **scarecrow / bench / fence** (decoration), **animals and building slots** (`animal_yard r=3`, `building_slot type=coop|barn|house` on the FRONT cell, footprints 3x2 / 4x3 / 3x2, an empty slot shows `build_stake`).
* **`FarmReserve.blocked(area, cell) -> String`** ("" = free; reasons home / zone / slot / field / spawn / warp / bridge) is called by P20's `PlacementService` and by P06's tool use (both late bound: P06 lands one wave before this class and treats an absent `FarmReserve` as 'nothing reserved') and refuses with the whisper FARM_CELL_RESERVED: a fence can no longer be dropped into the castle's footprint (analyst gap G3). F2's upgrade calls nothing (conflict C27).
* **Underdeck pillars** (`underdeck prop=` z -11, never in the skirts node), **canopy frame** (CanvasLayer 3, tinted every frame by the DayNight colour because a CanvasModulate does not reach other layers), **leaves** (CanvasLayer 4, <= 16 live): `ambient_fx kind=auto`, one per map.

### 3.5 Look, light, weather

Eleven point lights (8 `lantern_post` + 3 `light` markers, cap 12) with an additive halo each; windows glow through A1's `_night` house layers; weather from `WeatherFx`; the ambient preset tints the season but the tint alone is weak, so N05 (EXTENDED) adds dress markers by season (blossoms, sunflowers, leaf piles and pumpkins, snow patches) and one particle family per season (petals 20, fireflies 14, leaves 16, snow 40). Every interactive marker keeps >= 140 px from the top limit and >= 70 / 90 / 90 px from the bottom / left / right (the HUD zones of guide section 06). Honest: the kit is soft CG, not the flat vector of the guide.

### 3.6 The first morning (N04; DT8, DT15)

New game, 06:00, day 1, spring, clear: (1) a TEMPORARY Npc2D hedgehog Pip at `post pip_mailbox`, (2) `farm_intro_pip` (three lines + "Tak, Pip!"), (3) Fekongen's letter (`fairy_king` `context.intro`, P14's text; `quest_accept intro_lottery`), (4) `quest_accept forste_dage`, (5) `farm_intro_pip_bye` ("Hakken ligger i din rygsæk. Tryk på 1 ..."), (6) Pip leaves over the bridge and is freed, (7) hint `hoe`. About 25 s; never more than one dialogue at a time; Esc ends the sequence but both quests are still accepted; never on Continue. `IntroSequence.run` calls `TutorialRunner.run(world)` late bound and falls back to P14's letter-only flow when the runner is absent or `farm_tutorial.first_morning.enabled = false`. **Quest `forste_dage` ("Gårdens første dage", tag LÆR):** till 3 (`plot_tilled`), sow 3 (`crop_planted`), water 3 (`crop_watered`), look in the mailbox (`post_read`, only completable from day 2), harvest 1 (`crop_harvested`); reward 150 g + 10 carrot seeds + 3 fertilizer + Pip +1 heart. **Ten whisper hints** (hoe, seeds, can, harvest, bin, energy, bridge, bed, mail, expand): once per save (`tut_hint_<id>`), only while the quest is active, >= 12 s apart, the key glyph from `UiHints`. The real Pip of the towns routines stays in town on day 1 (`day_max 1`), so there is never a second Pip; the scene counts as the first meeting (DT15). Everything is data (`lua/farm/farm_tutorial.lua`, `lua/quests/forste_dage.lua`, 24 CSV keys) and a fixture adds an eleventh hint with no GDScript change.

### 3.7 Art (DT29)

N03 bakes only the 10 farm-only props (trunk_giant_a 1227x2405 footprint 5x3 and trunk_giant_b 1274x2142 footprint 3x3 SOLID, trunk_under_a / b, tool_shed 2x2, shipping_bin 2x1, stake_sign, rope_stake_x / z, build_stake), 3 backdrops (`farm_sky` 1024x1024, `farm_far` 2048x1024 seamless in x, `farm_canopy` 2048x360) and the terrain `field_grass` (576x336). P22 bakes the seven contract props (coop_small 350x295, barn_small 472x424, animal_house 319x270, paw_prints, apple_tree 359x398, bench 2x1, signpost) and gets the 16 `props_extra.lua` rows. EXTENDED (N06): 12 dress props, 4 particle sprites, the apple-tree seasons. **VRAM:** the kit costs 65.5 MB lossless (trunks 40.1) and **15.8 MB with S3TC import** (measured, error 0.85-1.7 / 255, crops looked at); the farm scene measured 100.0 / 105.7 MB (tier 1 / 10) lossless.

### 3.8 Budgets (DN11 / DT30) and measured numbers

Warm build < 60 ms (min of 5; measured 20.4-20.9 ms quiet, 24-47 ms loaded), process <= 8 ms steady (measured 6.2-7.5), draw calls <= 560 / 640 / 780 at zoom 0.4 / 0.3 / 0.2 (measured 502-524 / 597 / 723; the y-sorted ground is 389 of 502), texture memory <= 130 MB (measured 100.0-105.7), lights <= 12 (11), leaves 16 / petals 20 / snow 40 / fireflies 14, walk door to bridge end <= 10 s (9.3-9.5). **The integration plan's 4 ms / 94 draw calls hold for fixture-sized areas, not for this farm.**

### 3.9 Packages

| Id | Class | Wave | Size | What |
|---|---|---|---|---|
| **N01-farm-map** | CORE | 4 | M | `data/maps/farm.map` (the prototype verbatim except `event=festival_now`), `farm_signs.csv` (the three exact SIGN_ keys), `maps_farm.gd` (the 43 checks re-homed from maps_iso), `tools/farm/**` (generator, preview, offline checker with 8 mutants) |
| **N02-farm-objects** | CORE | 5 | M | bin, shed, expansion, pillars, canopy and leaves, `FarmReserve`, `FarmStage`, `lua/config/farm_site.lua`, `farm_site.csv` |
| **N03-farm-art** | CORE | 5 | L | the 10 props, 3 backdrops, `field_grass`, S3TC import |
| **N04-farm-first-morning** | CORE | 5b | M | runner, quest, hints, 24 CSV keys, `lua/farm/**` |
| **N05-farm-dress** | EXTENDED | 6 | M | `dress` handler + seasonal particles |
| **N06-farm-art-seasons** | EXTENDED | 6 | S | dress art, apple seasons, particle sprites |
| **N07-farm-greenhouse** | EXTENDED, optional | 7 | M | gated on Q1: 12 indoor plots, two winter crops, own seed shop |
| **N08-farm-qa** | QA | 7 | S | strict `art_complete`, windowed shots, budgets in a real window, first-morning checklist |

Critical path: N01 (4) -> N02, N03 (5) -> N04 (5b) -> G5b. N01 alone makes the farm exist (default start area; the two SKIPs of `area` run); without N03 the farm shows placeholders; without N02 the bin, shed and expansion are inert markers (skipped silently). EXTENDED packages can all be dropped without touching a CORE gate.

---------------------------------------------------------------------------------------------------------------------------------------------

## 4. The towns: buildings, rooms, hours, citizens, routines (packages T-*)

### 4.1 The 30 buildings (data of `lua/buildings/{traetoppen,hyggebyen,ext}.lua`; weekday 0 = Monday)

"owner home + hearts" = a home door that opens while the owner is at home and awake and the friend flag `friend_<npc>` >= 1. 20 CORE buildings (14 with a room, 3 locked nameplate doors, 2 stalls, 1 decor), 10 EXTENDED (the inn, the king's house, 8 homes).

| id | area | kind | name (da) | door | room | keeper / owner | open (closed on) | wave |
|---|---|---|---|---|---|---|---|---|
| `hoppe_hut` | traetoppen | home | Hoppes hytte | hut 1 | S 6x5 | gardener_hoppe | owner home + hearts | ext |
| `uglehulen` | traetoppen | service | Uglehulen | hut 2 | S 7x5 | appraiser_fru_ugle | 12-20 (Mon, Thu: her field days) | core |
| `postkontoret` | traetoppen | service | Postkontoret | hut 3 | M 8x5 | postman_pip | 09-17 (Sun) | core |
| `vagthytten` | traetoppen | home | Vagthytten | hut 4 | S 6x5 | guard_oak | owner home + hearts | ext |
| `brummes_vaerksted` | traetoppen | shop | Brummes værksted | hut 5 | L 9x7 | carpenter_brumme | 08-16 (Sat, Sun) | core |
| `brummes_hus` | traetoppen | home | Brummes hus | hut 6 | S 6x5 | carpenter_brumme | owner home + hearts | ext |
| `kikis_hytte` | traetoppen | home | Kikis hytte | hut 7 | S 6x5 | lamplighter_kiki | owner home + hearts | ext |
| `torvekroen` | traetoppen | public | Torvekroen | hut 8 | L 10x7 | innkeeper_kvak | 11-23 (Mon from 17) | ext |
| `fjerpens_hytte` | traetoppen | home | Fjerpens hytte | hut 9 | locked nameplate | clerk_fjerpen | owner home + hearts | core |
| `badehuset` | traetoppen | service | Badehuset | hut 10 | M 9x7 | bathkeeper_sofus | 10-21 (every day) | core |
| `musikstuen` | traetoppen | home | Musikstuen | hut 11 | S 6x5 | fiddler_strimmel | owner home + hearts | ext |
| `gaestehytten` | traetoppen | decor | Gæstehytten | hut 12 | decor, no door | - | - | core |
| `koekkenhave_skuret` | traetoppen | home | Køkkenhave-skuret | hut 13 | locked nameplate | bertil | owner home + hearts | core |
| `raadhuset` | traetoppen | public | Rådhuset | upper deck (993,480) | L 10x8 | clerk_fjerpen | 09-15 (Sat, Sun) | core |
| `torvestanden` | traetoppen | stall | Torvestanden | outdoor | stall | carpenter_brumme | 10-16 (Mon-Fri) | core |
| `natteblik_vinduet` | traetoppen | stall | Natteblik-vinduet | outdoor | stall | mapseller_natteblik | 20-23:30 (every day) | core |
| `froebutikken` | hyggebyen | shop | Kløvermyntes Frø | cell (13,12) | M 8x6 | merchant_pip | 08-18 (Sun) | core |
| `bageriet` | hyggebyen | shop | Rosmarins Bageri | cell (27,12) | M 8x6 | baker_maja | 07-17 (Mon) | core |
| `smedjen` | hyggebyen | shop | Thorins Smedje | cell (31,18) | M 8x6 | smith_thorin | 09-17 (Sun) | core |
| `dyrehuset` | hyggebyen | shop | Dyrehuset | cell (27,32) | L 9x7 | farmer_rosa | 09-17 (Thu) | core |
| `troldmandstaarnet` | hyggebyen | shop | Zephyrs Tårn | cell (8,19) | M 7x6 | fairy_wizard | 11-19 (Tue) | core |
| `moebelbutikken` | hyggebyen | shop | Stokroses Møbler | cell (13,32) | L 10x7 | fairy_furnisher | 09-17 (Wed) | core |
| `skraedderiet` | hyggebyen | shop | Fingerbøls Skrædderi | cell (20,34) | M 8x6 | fairy_tailor | 09-17 (Mon) | core |
| `toemmerhandlen` | hyggebyen | shop | Hasselnøds Tømmerhandel | cell (31,27) | M 9x6 | fairy_builder | 08-16 (Fri) | core |
| `loppeloftet` | hyggebyen | shop | Pippins Loppeloft | cell (5,23) | S 8x5 | pippin_boegeknop | 10-16 (Mon-Fri: a weekend shop) | core |
| `fekongens_hus` | hyggebyen | public | Fekongens træhus | cell (21,9) | L 10x8 | fairy_king | 10-16 (Sun) | ext |
| `hyldeblomsts_hus` | hyggebyen | home | Hyldeblomsts hus | cell (8,27) | S 6x5 | mayor_lyra | owner home + hearts | ext |
| `pippins_hus` | hyggebyen | home | Pippins hus | cell (10,32) | S 6x5 | pippin_boegeknop | owner home + hearts | ext |
| `birks_bistade` | hyggebyen | home | Birks bistade | cell (32,34) | S 6x5 | beekeeper_birk | owner home + hearts | ext |
| `pingvinens_hus` | hyggebyen | home | Postpingvinens hus | cell (35,13) | locked nameplate | penguin_postman | owner home + hearts | core |

Notes. **Rådhuset is the 14th building of Trætoppen's upper deck**; Hyggebyen has no town hall; the mayor lives in Hyggebyen and works at the Rådhus Tuesday to Thursday (78 game minutes = 39 real seconds each way). The two stalls have no room: their counter is an outdoor `ShopCounter` with the same three hosts (the one deviation from requirement 4: DT38, Q7); Uglehulen is a service row with no shop id (DT59). The seed shop ("general store") is `froebutikken` with shop id `seed_shop`. Door cells of Hyggebyen are the DRAFT of the route bake, the final cells are P11's; the post and door NAMES are the contract. **Opening days at noon:** Monday 7 of 10 shops, Tuesday 8, Wednesday 8, Thursday 8, Friday 8, Saturday 10, Sunday 8 (Brumme's workshop and his stall count as one shop, `timber_yard`).

### 4.2 Doors (`Door2D extends Warp2D`)

One marker per building at the doorstep cell; the handler builds the Warp2D to the interior area, creates the arrival spawn `from_int_<building>` one cell in front and registers nothing else. Measured in the real `WorldRoot2D`: 14 door markers handled, 14 spawns; standing on the arrival spawn for 90 frames triggers nothing; the bakery door arrives 0.0 px from the interior spawn and the exit door 0.0 px from `hyggebyen:from_int_bageriet`.

| State | Reason | Whisper (da / en) | Travel |
|---|---|---|---|
| open | - | - | `area_change_requested(int_<id>, default)` |
| closed before opening / after closing | `hours` | `HOURS_CLOSED_NOW` "Lukket lige nu. Åbner kl. 07:00." / "Closed right now. Opens at 07:00." | none |
| closed weekday | `day` | `HOURS_CLOSED_DAY` "Lukket i dag. Åbner igen tirsdag." / "Closed today. Opens again on Tuesday." | none |
| closed by a festival | `festival` | `HOURS_CLOSED_FESTIVAL` "Lukket for dagens fest." | none |
| home, owner away or asleep | `away` | `HOURS_HOME_AWAY` "Der er ingen hjemme." | none |
| home, friend flag 0 | `stranger` | `HOURS_HOME_STRANGER` "Du kender ikke hinanden godt nok endnu." | none |
| nameplate, no room | `locked` | `HOURS_HOME_LOCKED` "Døren er låst." | none |

The whisper is composed at runtime from a CSV template (`tr(KEY) % args`) through `EventBus.whisper_requested`; P17 shows a string without a CSV entry as is (RT23). A door sign (`BLD_<ID>` over `HOURS_SIGN` "%s - åbent %s-%s", on a closed weekday "Lukket: tirsdag") is a world Label within 3 cells of a door: no screen, no registry row. A room's exit door is `always_open`: closing time evicts, it never traps.

### 4.3 How a map author says it (the authoring forms)

```
@marker T town                                   # ONE per map; farm.map: `@marker T town curfew=false`
@marker a door building=bageriet                 # at the doorstep cell, one per building
@marker b post name=torv_fountain_n act=sit cap=2   # act: stand sit tend fish play lean patrol (default stand); cap default 1
@marker F post set=fest spot=hyggetorv           # expands to the 24 fest_hyggetorv_* posts
@marker W warp to=traetoppen spawn=from_hyggebyen label=ZONE_TRAETOPPEN   # already there: the warp IS the gate (anchor gate_traetoppen)
```

One script serves `town`, `door` and `post` (`scripts/towns/town_marker.gd`, `create_marker(params, pos, cell, area) -> Node`, three rows of F4's `marker_handlers.lua`). The map parser takes ANY single character as the object char (proven with æ, Ø, é). A post on a blocked cell moves to the nearest free cell (<= 2 cells or the validator fails). **The festival set** is ONE marker: 24 names `fest_<spot>_host`, `_judge`, `_stall_1`..`_4`, `_table_1`..`_2`, `_gather_1`..`_16` at fixed offsets (host (0,0), judge (2,0), stalls (-4,-2) (-2,-2) (2,-2) (4,-2), tables (-3,1) (3,1), gather k at (k mod 4 - 1, 2 + k div 4)); spots `torvet`, `badehus`, `raadhus` (the city) and `hyggetorv` (DT22). **The city has no map text** (V4's builder), so its doors, 36 posts, 3 festival spots and 3 gates (`gate_hyggebyen`, `gate_farm`, `gate_skovlift`) are one sidecar `data/towns/traetoppen.json` (T-routes, so the route table bakes the city in wave 5; NOT V4's geometry file `data/traetoppen/traetoppen.json`; `towns_city.door_coords_match_city_json` of T-director is the drift guard).

### 4.4 Interiors: a room is data (DT13)

`data/interiors/<core|ext>/int_<id>.json` (schema `data/interiors/schema.json`: id, building, size S / M / L, cols x rows, wall_style, floor, door, spawn_cell, windows, exit, items, posts, markers) + a 7-line stub map `data/maps/int_<id>.map` (`@id`, `@title BLD_<ID>`, `@projection iso` (an ortho room would freeze the calendar), `@ambient home`, `@zone <outer zone>` (else the unlock toast shows `ZONE_<ID>`), `@builder res://scripts/towns/interior_room.gd`, `@room int_<id>`). `InteriorRoom.build` lays the floor, two cut-away back walls and a corner (4 wall styles, windows with night layers faded by the OUTDOOR hour), a doormat, two warm lamps, the furniture with true rotations and baked y-sort, a footprint collider per floor piece, the hatch bars, the exit door, the counter interactables and a `ShopHours` node; rooms are never parked and are rebuilt on every enter. Camera `zoom_fit = 0.85 * min(1280 / (n * 64), 720 / (n * 38 + 280))`, n = cols + rows (0.635-0.877). **Measured (24 rooms, headless):** build mean 6.2 ms, worst 27.5 ms cold; nodes p50 76, max 96; sprites p50 25, max 31; windowed first frame 123-364 ms (the inn with 11 citizens 364 ms).

**The counter band** (the same grammar in every shop):

```
row 0   back wall: shelves / ovens / racks + wall pieces
row 1   KEEPER post (behind the counter) + the staff corridor
row 2   [hatch][hatch][ COUNTER 3x1 ][hatch][hatch]   invisible bars on collision layer NPC (4): the player is stopped, citizens pass
row 3   customer zone: the `shop` host (ShopCounter, 150 x 40) in FRONT of the counter middle, a `talk` host (40 x 22) on each of the two cells in front of the counter ENDS (m-1, m+1)
row 4+  display pieces, customer posts, the door lane (reserved)
last    door + doormat
```

Proven: the player never reaches the keeper post (16 of 16 runs), a citizen body through the hatch gap does (16 of 16), flood fill with the real colliders passes in all 24 rooms (door -> counter front -> every customer post; keeper unreachable for the player). E decides by where the player STANDS (the built E-query takes, among the hosts that overlap the circle r = 45 at the facing cell, the one nearest to the PLAYER): on the middle cell -> `ShopCounter.interact` -> `ShopSystem.open_shop(shop_id)` -> `shop_opened` -> P18's panel OVER the live room; on an end cell -> the `talk` host calls the keeper's own `Npc2D.interact` (greeting, weekly heart, gifts, topics, birthdays, quest offers and turn-ins, the upgrade choice); the prompt pill changes live (`COUNTER_SHOP` 'Se varer' / `COUNTER_TALK` 'Tal med <navn>'). **Measured:** the replay of the built rule on the 14 core layouts and the REAL Player stub in a clone agree on 23,760 of 23,760 samples; standing on an end cell facing the counter selects that talk host (252 of 252), the middle cell selects the shop (126 of 126) and never a talk host at any facing (0 of 1,008); with the old design the keeper was selected 0 of 576 samples. A `talk` host stays disabled until a keeper node stands in the room. The builder yard has a fourth host, the `desk` (cell m+2: `open_home_builder`, the second door of the Husbyggeri), Uglehulen's middle host is kind `appraisal` (no shop id), and there is NO `forward_to_keeper` seam and no gift shortcut; the `blur_scrim` shader blurs the live world, so the walk-in room IS the guide's blurred background. `bath`, `board` and `mailbox` markers are built by V6's own classes (BathTub2D, NoticeBoard2D, PostBox2D) inside the room through `IsoArea.resolve_handler`; until they exist a counter announces the use as a `game_event`. `post_counter` (Pip) and `bar` (the inn) emit `open_post_office` / `open_inn_menu`. Pieces resolve: baked kit manifest (I3 / I4) > `furniture.json` (A1's 130 pieces) > `data/interiors/stand_ins.json` (15 stand-ins in 10 of the 14 core rooms, listed by `towns_interiors.stand_ins_listed`) > a labelled placeholder box. Budgets per room: <= 130 nodes, <= 12 ms warm, <= 4 lights, <= 3 MB texture with the kit.

| Room | Size | Room | Size | Room | Size |
|---|---|---|---|---|---|
| `int_froebutikken` | M 8x6 | `int_postkontoret` | M 8x5 | `int_torvekroen` (ext) | L 10x7 |
| `int_bageriet` | M 8x6 | `int_badehuset` | M 9x7 | `int_fekongens_hus` (ext) | L 10x8 |
| `int_smedjen` | M 8x6 | `int_raadhuset` | L 10x8 | `int_hoppe_hut`, `int_brummes_hus`, `int_vagthytten`, `int_kikis_hytte`, `int_musikstuen`, `int_hyldeblomsts_hus`, `int_pippins_hus`, `int_birks_bistade` (ext) | S 6x5 |
| `int_troldmandstaarnet` | M 7x6 | `int_uglehulen` | S 7x5 | | |
| `int_moebelbutikken` | L 10x7 | `int_brummes_vaerksted` | L 9x7 | | |
| `int_skraedderiet` | M 8x6 | `int_toemmerhandlen` | M 9x6 | | |
| `int_dyrehuset` | L 9x7 | `int_loppeloftet` | S 8x5 | | |

### 4.5 Opening hours: ONE rule (DT12)

`Hours` (a static class, no autoload): `state(building, ctx) -> {open, reason open|hours|day|festival|none, opens_at, closes_at, next_weekday}`, `is_open`, `shop_open(shop_id, ctx) -> bool or null` (null = no building claims the shop: the def's own weekday rule stays, so `flea_market open_weekdays {5, 6}` keeps working), `closed_info`, `minutes_to_close`, `hours_on`, `format_hour`. Data (the buildings registry):

```lua
bageriet = { area = "hyggebyen", kind = "shop", name_key = "BLD_BAGERIET", interior = "int_bageriet", size = "M", shop = "bakery", keeper = "baker_maja",
             post = "int_bageriet.counter", hours = { open = 7, close = 17, closed = { 0 } }, wave = "core" },
torvekroen = { ..., hours = { open = 11, close = 23, closed = {}, overrides = { { weekday = { 0 }, open = 17, close = 23 } } }, wave = "ext" },
natteblik_vinduet = { ..., hours = { open = 20, close = 23.5, closed = {}, short_ok = true }, ... },
```

open <= hour < close on a weekday not in `closed`; `overrides` change single weekdays; `close < open` wraps midnight; an empty Lua table arrives as a Dictionary and means "no days" (measured trap, handled). **Consumers of the one rule:** `Door2D` (whisper + no travel), `ShopSystem.is_open` / `get_shop_info` (`closed_reason`, `opens_at`, `next_open_weekday`; buying in a closed shop is refused with reason `closed`; P12 fix, RT5), `ShopHours` (the closing sequence), P18's panel (the closed state text) and, for festivals, `SocialManager.shop_closed_by_festival(shop_id)` through `ctx.fest_closed_fn` (the festival def's `closes` / `stays_open` is the one place that decides).
**Closing time** (`ShopHours`, a child of every room whose building has hours): 30 game minutes before closing the whisper `HOURS_CLOSING_SOON` "Vi lukker om en halv time." + `game_event closing_warning {shop, minutes_left}`; at closing the shop modal is closed through the TTScreen close request `EventBus.ui_panel_toggled(&"shop", false)`, `HOURS_CLOSED_BELL` "Klokken ringer. Vi lukker nu - på gensyn!", `game_event shop_open_changed`, then `area_change_requested(outer area, from_int_<building>)`. It WAITS while another modal is open or while a travel or a sleep sequence runs (`WorldRoot2D.travel()` returns silently while it travels, so an eviction fired inside the fade of entering the room would be lost) and retries each clock tick (a dialogue at 17:06 delays the bell until it ends); a panel opened at 16:59 keeps buying (the pausing modal freezes the clock). A home evicts its guest when the owner goes to bed. **Which clock every section runs at (DT55):** `Hours.now_ctx()` is the clock-only context (weekday, hour, season, weather, the festival closure through SocialManager); the config switch `towns.hours_enabled` (default true) makes `Hours.shop_open` answer null, P12's helper `ShopHoursGate` honours it, and every section that is not about hours runs with it OFF (economy.gd's `_fresh()`, RT35; later sections in their fixture); sections about hours leave it on and set the clock explicitly (Monday 12:00 unless a check names another). Validator `hours.consistency`: a shop, service, public building or stall must have hours, a shop id must exist, open >= 6 game hours unless `short_ok`, every hours entry has a keeper with a routine.

### 4.6 Services and stalls

| Place | What the player can do | Built by |
|---|---|---|
| Postkontoret (Pip) | E at the counter: Pip talks; the `mailbox` marker = today's letter (V6's PostBox2D, one a day); the counter event `open_post_office` -> the `Hvor er ...?` list (wave 6) | T-interiors-core, V6, T-post-office |
| Badehuset (Sofus) | the `bath` marker = BathTub2D (once a day, 30 game minutes, stamina and half-heart restored) | V6 inside `int_badehuset` |
| Rådhuset | the `board` marker = NoticeBoard2D (up to 5 everyday quests); Fjerpen keeps the counter, the mayor's desk post Tue-Thu | V6 inside `int_raadhuset` |
| Uglehulen (Fru Ugle) | a SERVICE without a shop id: the centre host (kind `appraisal`) emits design2's `open_appraisal` (hosted by F4's LootService, screen DL7; refused while closed, a whisper until DL7), the talk cells open her dialogue with the choice 'Vurdér mine fund'; open 12-20 except Monday and Thursday | T-interiors-core + DL7 |
| Brummes værksted / Torvestanden | shop `timber_yard` (V1): the workshop Mon-Fri 08-16, the stall at Torvet Sat-Sun 10-16 | T-interiors-core, V1, the city sidecar |
| Natteblik-vinduet | shop `natteblik_maps` 20:00-23:30, the window of the bat house on level E next to the bathhouse | the city sidecar |
| Torvekroen | the inn: a counter (`bar`), 6 seats, a stage post (Strimmel plays Friday); sells nothing | T-ext-content |

### 4.7 Citizens: the roster of 30 (DT9)

| id | name | look (art id) | role | home | work | closed / rest | twin | wave |
|---|---|---|---|---|---|---|---|---|
| `mayor_lyra` | Borgmester Hyldeblomst | `fairy_mayor` | mayor | hyldeblomsts_hus | raadhuset | Mon, Fri, Sat, Sun | - | core |
| `baker_maja` | Bagerfe Rosmarin | `fairy_baker` | baker | bageriet | bageriet | Mon | - | core |
| `merchant_pip` | Butiksfe Kløvermynte | `fairy_shopkeeper` | shopkeeper | froebutikken | froebutikken | Sun | - | core |
| `pippin_boegeknop` | Pippin Bøgeknop | `mouse_pippin` | villager | pippins_hus | loppeloftet | Mon-Fri | - | core |
| `fairy_king` | Fekongen | `fairy_king` | king | fekongens_hus | fekongens_hus | Sun | - | core |
| `fairy_lily` | Fe-barnet Lily | `fairy_lily` | child | hyldeblomsts_hus | - | - | - | core |
| `smith_thorin` | Smeden Thorin | `raccoon_smith` | smith | smedjen | smedjen | Sun | - | core |
| `guard_oak` | Vagten Oak | `bear_guard` | guard | vagthytten | vagthytten | - | - | core |
| `farmer_rosa` | Dyrehandler Rosa | `rabbit_farmer` | animal_keeper | dyrehuset | dyrehuset | Thu | - | core |
| `fairy_wizard` | Fe-troldmanden Zephyr | `fairy_wizard` | wizard | troldmandstaarnet | troldmandstaarnet | Tue | - | core |
| `cat_morfar_mis` | Morfar Mis | `cat_morfar_mis` | elder | pippins_hus | - | - | - | core (gated: quest `lost_cat` or day 60) |
| `penguin_postman` | Postpingvinen | `penguin_postman` | villager | pingvinens_hus | - | - | - | core |
| `fairy_builder` | Tømrerfe Hasselnød | `fairy_builder` | builder | toemmerhandlen | toemmerhandlen | Fri | - | core |
| `fairy_furnisher` | Møbelfe Stokrose | `fairy_furnisher` | furnisher | moebelbutikken | moebelbutikken | Wed | - | core |
| `fairy_tailor` | Skrædderfe Fingerbøl | `fairy_tailor` | tailor | skraedderiet | skraedderiet | Mon | - | core |
| `gardener_hoppe` | Gartner Hoppe | `rabbit` | gardener | hoppe_hut | - | Sun | - | core |
| `carpenter_brumme` | Tømrer Brumme | `bear_brumme` | carpenter | brummes_hus | brummes_vaerksted | Sat, Sun (stall instead) | - | core |
| `postman_pip` | Postbud Pip | `hedgehog_pip` | postman | postkontoret | postkontoret | Sun | - | core |
| `bathkeeper_sofus` | Sofus | `capybara_sofus` | bathkeeper | badehuset | badehuset | - | - | core |
| `appraiser_fru_ugle` | Fru Ugle | `owl_fru_ugle` | appraiser | uglehulen | uglehulen | Mon, Thu (field days) | - | core |
| `mapseller_natteblik` | Natteblik | `bat_natteblik` | mapseller | natteblik_vinduet | natteblik_vinduet | - | - | core |
| `beekeeper_birk` | Birk | `fairy_birk_npc` | beekeeper | birks_bistade | - | - | - | core |
| `clerk_fjerpen` | Skriver Fjerpen | `cat` | clerk | fjerpens_hytte | raadhuset | Sat, Sun | - | core |
| `rasmus` | Rasmus | `fox` | apprentice | brummes_hus | brummes_vaerksted | Sun | rasmus | ext |
| `lamplighter_kiki` | Kiki | `monkey` | lamplighter | kikis_hytte | - | - | kiki | ext |
| `bertil` | Bertil Bøgeknop | `hobbit_pip` | gardener | koekkenhave_skuret | - | - | bertil | ext |
| `bodil` | Bodil Bøgeknop | `hobbit_bodil` (draws as `hobbit_pip` until the A2 / V2 bake) | baker_helper | bageriet | - | - | bodil | ext |
| `innkeeper_kvak` | Værten Kvak | `frog` | innkeeper | torvekroen | torvekroen | Mon (fishes) | - | ext |
| `cub_bamse` | Bamse | `bear` (scale 0.72) | child | vagthytten | - | - | - | ext |
| `fiddler_strimmel` | Spillemand Strimmel | `hedgehog` | musician | musikstuen | - | - | - | ext |

CORE = 23 citizens, EXTENDED = 7 (their `npcs.lua` rows are V1's wave-4 task, `routine = true` on all 30 rows; `friendship = true` on all but Morfar Mis, who unlocks through `citizens.<npc>.unlock`). Hero twins: absent while the player is that hero (DT9, DT41). Family and age (data of V1 for the social marriage exclusion): siblings Bertil / Bodil Bøgeknop and Kløvermynte / Birk, the children Lily and Bamse. A data-only citizen WITHOUT a routine file keeps being placed by an `npc` marker (static), so both ways of adding a citizen stay valid.

### 4.8 A routine is a Lua file (kind `registry`)

```lua
kind = "registry"
registry = "routines"
routines = { gardener_hoppe = {
  home = "hoppe_hut", home_area = "traetoppen", priority = 4, shelter = "home.table",
  plans = {
    work = { blocks = {
      { from = 6.5,  at = "home.table",         act = "eat" },
      { from = 7.25, at = "traetoppen.a_beds1", act = "tend" },
      { from = 13.5, at = "traetoppen.a_beds1", act = "tend", leave = 16.5 },
      { at = "traetoppen.t_fire_n", act = "sit", leave = 18 },
      { from = 22,   at = "home.bed",           act = "sleep" } } },
    farm_visit = { blocks = { ... { from = 15, at = "farm.hoppe_fence", act = "stand", leave = 16 }, ... } } },
  select = { { plan = "inn", when = { weekday = { 4, 5 } } },
             { plan = "farm_visit", when = { weekday = { 2 }, min_hearts = 2 } },
             { plan = "rest", when = { weekday = { 6 } } }, { plan = "work" } } } }
```

* **Block.** `from` = ARRIVE by this hour (6.5 = 06:30); `leave` = leave at this hour, `stay` = leave this long after arriving; both omitted = leave in time for the next block (the resolver subtracts the baked walk). `act` one of `sit eat inside sleep work tend stand play fish patrol perch guard lamp away`. `at`: `area.post`, `int_<building>.<post>`, `home.<post>` / `work.<post>` (a citizen's own rooms; when the room is not built he is "inside at the door"), `nowhere`, `away:<anchor>`; a trailing `?` = optional (dropped when the anchor does not exist). Reserved Lua word `until` is never used.
* **`when`:** `weekday {0..6}`, `season`, `weather`, `festival "id" | true`, `flag`, `not_flag`, `min_hearts n` (hearts with THIS citizen: `SocialManager.hearts`, flag fallback), `done_quest`, `day_min`, `day_max`, `not_hero`. Unknown key = false + one warning. **Rain** moves outdoor `sit tend play fish` blocks 08-19 to the `shelter` post (weather ids `regn`, `torden`). **Gate:** `gate = { done_quest = "lost_cat", or_day = 60 }`. Time is game hours. A plan WRAPS (first and last block in the same room): the morning never teleports anyone. **Festival overlay:** when `SocialManager.override_for(npc, total_day, hour)` names a post the compiled day gets a festival stay (leave in time, stand on the post, walk to the first place of the normal day that is still going on); a citizen who is not in the world then (asleep, away, hero twin) skips it.
* **A routine cannot** choose randomly (the same day twice is the same), converse, buy, or leave the three areas (Fru Ugle's `away:` is the only exit).

**People worth knowing:** Pip leaves the post office 06:05, stands at the farm mailbox 07:10-07:30 every morning except Sundays from day 2 (65 game minutes of walking over two bridges), is at his counter 08:33; the mayor commutes Tue-Thu (leaves ~08:11, at her desk 09:30, back at the fountain 16:05); Hoppe tends the first tree's beds and **walks to the farm fence on Wednesdays from 2 hearts** (leaves 13:15, there 14:27, back 16:34), Friday and Saturday evenings at the inn; Fru Ugle is AWAY on Mon and Thu (`away:traetoppen.gate_skovlift` 09:34-17:30; the dungeon hub marker uses `when=away:appraiser_fru_ugle`); Natteblik is `nowhere` until 19:30 and at the bat window 19:30-23:30; Brumme works Mon-Fri in the workshop and keeps the stall at Torvet on Sat-Sun; Kiki lights the lamps of the Torvet cluster 17:30-19:26; the children swap towns on Saturday; the postal penguin delivers inside Hyggebyen; Kvak fishes at the Hyggebyen pond on Mondays until 17:00; shopping errands put Thorin, Rosa and Birk INSIDE other shops (the validator checks every visit lies inside that shop's hours).

### 4.9 The engine (every number measured in the prototype, host load 3.3-3.6)

```
 Lua registries                data/towns/routes.json              markers in the maps / city sidecar
 routines (30) buildings (30)  (baked from the real nav grids)     town door post warp   (data/towns/traetoppen.json)
        |                              |                                    |
        +--------> Routines.where_is(npc, ctx)  <-- RouteTable.path --------+       ctx = clock, weekday, weather, hero, hearts, festival
                   (pure, 7 us)
        NpcDirector (static facade)  -----------  TownDirector (per area, in the area tree)  ---- Door2D (hours), ShopHours (closing), ShopCounter
        is_absent is_away is_present where_is population resync(npc)    carrots + move_and_slide, cap 16 looks, curfew 23:30 / 23:45
```

* **Resolver.** Compile once per (citizen, plan, rain, festival post): blocks -> `stay` and `move` segments, a leg is `walk` (ground px / speed) or `portal` (0.5 s); a plan whose walk does not fit is reported (`routines.feasible`), never silently shortened. Measured: parse of the 30 files 14.0-16.3 ms, 136 timelines compile in 30-34 ms (0.22-0.25 ms each), `where_is` 7.1-8.6 us per call, a sweep of 30 citizens 0.21-0.26 ms. The same code runs on the shipped data, on the CORE-only subset (23 citizens, 20 buildings, 14 rooms: all 9 rules pass, 74 places degrade to a door) and on mutated copies (11 of 11 mutants caught).
* **Route table.** `data/towns/routes.json` (derived, 34 KB, 27 areas: farm, Hyggebyen, Trætoppen and 24 rooms; the header carries the hash of its inputs; regenerated at the 5b and 6 gates, sanctioned edit E3). Bake 0.82-0.86 s quiet. `NavGrid` = AStarGrid2D from the PHYSICS space with the NPC body inflated x1.4 (0 stuck events in 7,200 frames x 30 agents); `LevelNav` = a hierarchical planner over V3's `levels_graph()` (8 levels, 9 bridges, the ladder, the Skovlift basket): sketch proof 55 anchors, 2,970 pairs, 0 failures; T-routes owns it and the city sidecar, so the route table bakes the CITY in wave 5 and an unbuilt room is a PENDING area (listed by name, required empty at the gate).
* **Director.** A child of the area created by the `town` marker; `_exit_tree` frees every citizen node (a parked area keeps no sheets); keeps exactly the citizens alive whose body is in this area now; at most `towns.max_live_visuals` (16) DISTINCT looks (festival crowd first, then priority); follows a CARROT = the point of the baked path where the schedule says the citizen is (`move_and_slide`, mask WORLD | PLAYER | GROUND_BLOCK, NOT layer 4; catch-up 1.6x; snap when > 420 px behind); moves only while `current_phase == PLAYING`; resyncs on area enter, day start, each clock minute and after a time skip (3 h skip 4-5.4 ms). Measured: a whole game day Tuesday in Hyggebyen 32,311 physics frames at **0.045 ms per frame**, up to 14 live, 0 snaps, lag mean 1.0-1.3 px; 30 park / enter cycles leak nothing. **City followers are kinematic** (`global_position = carrot`; each follower carries its level) - the riskiest part of the track, proven on the design2 sketch, not yet on V4's real city (RK6).
* **Curfew** (DT24): in a town area (not the farm, not a home) at 23:30 the whisper `HOURS_CURFEW_SOON` "Det er blevet sent. Tid til at gå hjem.", at 23:45 `HOURS_CURFEW_HOME` "Nattevagten følger dig hjem." + `area_change_requested(farm, from_home)`; held during any modal and retried next tick; `towns.curfew {enabled, whisper 23.5, go_home 23.75}`; protects the hour where the 24:00 pass-out would wake the player in a shop; coexists with D0's pass-out relocation.
* **`Npc2D` driven interface** (P14, RT24): `set_driven(true)`, `hold(bool)`, `set_act(name)`, `face(dir8)`, `Npc2D.create(row)`; the `npc` marker handler skips a row with `routine = true`; the stand-in `citizen_stub.gd` is the default spawn until P14 lands.
* **Config `towns`** (`lua/towns.lua`): `npc_speed 0.65`, `portal_seconds 0.5`, `max_live_visuals 16`, `plan_visual_peak 14`, `live_min_dwell 0.05`, `rain_shelter {acts, from 8, to 19}`, `closing_whisper_minutes 30`, `curfew {...}`, `carrot_max_speed 1.6`.
* **Looks and memory.** 14-look planned peak per area (worst: Hyggebyen Tuesday 17:10 = 14, Trætoppen Monday 17:10 = 11, the inn Friday 20:15 = 12); one distinct look = 8.93 MB VRAM (measured); VRAM arithmetic in section 7.5.

### 4.10 The `Hvor er ...?` screen and keeper greetings (EXTENDED, wave 6)

`post` = modal (pauses) opened by `game_event open_post_office` from Pip's counter: `PanelParchmentL24`, header "Hvor er ...?", group tabs `[Trætoppen] [Hyggebyen] [Gården]` (page keys), one read-only row per citizen the player knows (every keeper + every citizen with `friend_<npc>` >= 1): portrait, name, the place in words (`WHERE_POST_<NAME>` / `BLD_<ID>` + `ACT_<ACT>`), an absent citizen reads "ude i skoven" (an `away:` block) or "ikke vågen endnu", never a coordinate; data = `NpcDirector.where_is` at the live clock; registry row `post` (esc depth 1, initial focus = first row, the 9 standard checks, baseline `docs/qa/ui_baseline/post.png` pinned after the lead looked at the first capture). **Keepers greet like people:** `SocialTalk.greeting_for_shop(shop_id)` reads `KEEP_<SHOP_ID>_GREET_H<band>_<n>` (bands H0 0-1 hearts, H1 2-4, H2 5-7, H3 8-10; band-only lines beat part-of-day lines) with the shop def's `greeting_key` as fallback; T-greetings writes 61 rows (11 shop ids x 4 bands, 11 samples, 6 shared panel lines; Fru Ugle has no panel) and ships no code.

### 4.11 Packages and tests

| Id | Class | Wave | Size | What | Section(s) |
|---|---|---|---|---|---|
| **T-towns-core** | CORE | 4 | L | `Hours` (own clock context), buildings registry, `InteriorRoom`, `PieceCatalog`, `Door2D`, `ShopCounter` (shop, post_counter, bar, appraisal, desk, talk), `ShopHours`, `lua/towns.lua`, `towns.csv` (BLD_ 30, HOURS_ 11, ACT_ 14, COUNTER_ 5), room schema and validator tools | `towns_data` (>= 60), `towns_interiors` (>= 60) |
| **T-routes** | CORE | 5 | L | `Routines`, `RouteTable`, `NavGrid`, `TownMarks` (collect, resolve_cells), `LevelNav`, the city sidecar `data/towns/traetoppen.json`, `FestSet`, `NpcDirector` (incl. `node_of`), `TownsValidate` (9 rules, PENDING_AREAS), `routes.json`, the 23 CORE routines | `towns_routines` (>= 100), `towns_routes` (>= 50) |
| **T-interiors-core** | CORE | 5 | M | the 14 room specs + 14 stub maps + shop / service wiring | `towns_interiors_core` (>= 80) |
| **T-director** | CORE | 5b | L | `TownDirector`, `TownMarker`, curfew, room director, real Npc2D, the city half (`city_town.gd`: doors and stall counters from the sidecar, V4 hook), `post_ground` / `door_ground`, the FestivalDecor hook | `towns_director` (>= 70), `towns_city` (>= 40) |
| **T-ext-content** | EXTENDED | 6 | M | the inn, the king's house, 8 homes, `lua/buildings/ext.lua`, 7 routines | `towns_ext` (>= 50) |
| **T-greetings** | EXTENDED | 6 | S | `keepers.csv` (61 rows) | `towns_greetings` (>= 20) |
| **T-post-office** | EXTENDED | 6 | M | the `post` screen, `post.csv` (about 75 rows), registry row | `towns_post` (>= 25) |
| **T-qa** | QA | 7 | M | `zz_towns`: populated all weekdays, shops open ratio, doors round trip, closing and curfew, save / load same positions, 3-day soak, the L18 towns legs, windowed numbers, `docs/towns/TOWNS.md` | `zz_towns` (>= 40) |

Windowed shots to take (the lead looks at every PNG): both towns at 06:30, 12:00, 17:30 and 20:30; rain; the festival green; the farm at 07:10 with Pip; every room with its keeper; the shop panel over three rooms; the post screen.

---------------------------------------------------------------------------------------------------------------------------------------------

## 5. The social sim (packages S-*): CORE, EXTENDED and LATER

### 5.1 The model in one page (DT17, DT18)

**`SocialManager`** (autoload, `scripts/social/social_manager.gd`, the sixth feature autoload) is the ONLY writer of friendship. Save section `social` (order 60) is authoritative; the flags `friend_<npc>` (whole hearts) and `friend_last_<npc>` (total_day of the last weekly heart) become a DERIVED MIRROR rewritten after every change and every load, so every reader (quest gates, `LootService.check_friend_gifts`, dialogue Lua `friend_x`, the shop discount) keeps working and an old save without the section keeps its hearts (`reset()` re-seeds points from the flags, `hearts x 100`). Three writers, all inside the manager: `add_points(npc, delta, source)`, `add_hearts(npc, n, source)` (quest rewards: WHOLE hearts), `debug_set_hearts` (raises only).

| Rule | Value |
|---|---|
| Scale | whole hearts 0-10, 100 points per heart (cap 1000), a half heart drawn at 50; **no decay, nothing negative** |
| Weekly chat (the DF3 floor) | the first FINISHED conversation of a Monday-Sunday week gives exactly +100: `on_conversation_finished(npc, lines_shown, completed)`; `completed` = the last line advanced or a closing choice picked; Esc after the first line gives NO heart; the daily greeting gives 0 points; a second chat the same week plays and pays nothing |
| Stages by hearts | fremmed 0, bekendt 1, nabo 2, ven 4, god ven 6, bedste ven 8 (labels `REL_STAGE_<ID>`, one toast + `relationship_changed` per change) |
| Gifts | points love 40 / like 20 / neutral 8 / dislike 0 / hate 0; rarity x1.25 (uncommon) x1.5 (rare); **birthday x4** (cap 160), belated (next day) x2; the same item to the same citizen within 14 days x0.5; **1 per day, 2 per week** per citizen; a birthday gift takes no weekly slot and is given once per birthday |
| Never giftable | unique / legendary keepsakes, categories quest / special / animal / building / blueprint, protected items, items an ACTIVE quest needs (`QuestManager.item_in_use`), the last copy of any tool and every tool in the hotbar, the materials of the next home tier, the pieces of a wardrobe set whose capstone is open, worn clothing, placed furniture (hidden from the picker with a footer count); a tool, a rare item or a sell value of 100 g or more asks `UiConfirm` first (default Fortryd) |
| Taste data | `gift_tastes = {universal, 8 archetypes, npcs}`; selectors item id (4) > `ftype:` / `slot:` / `set:` (3) > `category:` (2) > `rarity:` (1); NPC row > archetype row > universal; 278 of 345 items are giftable; a taste is learned from gifts and from topic answers (reveals at 2 / 5 / 8 hearts); the picker shows a text + shape chip, never colour alone |
| Shop friendliness | 1 point per 100 gold spent (weekly cap 10 per keeper) and a weekly keeper sample (a cheap normal item) from the hearts the shop def names; the existing `friend_discount` is untouched; `PriceCurve` reads the KEEPER's hearts |
| Birthdays | one per citizen, 30 distinct days (min gap 2 days, none on or beside a festival; the planner `plan_birthdays.py` fixes them); a citizen without a row gets a stable derived day from `fmix32(fnv1a("birthday", id))`; a birthday is KNOWN after the first conversation; shown in a **Kalender tab of the journal** |
| Determinism | `CalendarUtil` (28 % 7 asserted), `SocialRng` = FNV-1a 32 + murmur3 fmix32 over `seed:part:part` with a saved seed (never `String.hash`, never `randf`; a Python mirror prints six pinned vectors), state queries instead of edge triggers (`festival_active`, `is_birthday`, `eval_when`), daily work deferred and coalesced (a synchronous daily event broke `core.advance_time_multiday`; a 50 h skip catches up idempotently) |
| `when=` grammar | ONE implementation, `SocialManager.eval_when(spec)`: kinds `quest: done: flag: night` (old) + `at:<npc>` `away:<npc>` `open:<shop>` `hearts:<npc>:<n>` `fest:<id or any>` `hour:<a>-<b>` `weekday:` `season:` `birthday:<npc>` `stage:<npc>:<stage>`, `&` and a leading `!`; an UNKNOWN kind is false AND a map error at setup (today it is silently TRUE: a typo shows the prop forever) |
| Save | section `social` v1 `{v, seed, last, npcs{id:{p, wk, gt, gd, gwk, gw, bd, bk, ls[<=3], kn{<=40}, rv, rs}}, seen{}, fest{}, partner{}}`, zero fields omitted, whole numbers re-coerced; 92 bytes fresh, 15.9 KB worst case (30 friends, 12 known tastes each); unknown NPC ids go to an `orphans` bucket with a `push_warning` (a `push_error` in `from_dict` would reject the WHOLE load: measured); the whole save projects to about 31 KB against 60 KB |
| Hero twins | `can_befriend` is false while `NpcDirector.is_absent(npc)` (the player chose that look); hidden in the People book (Q3) |

### 5.2 CORE (waves 4-5b): hearts, talk, gifts, birthdays, People book

* **S-core (4, L): SocialManager, CalendarUtil, SocialRng, SocialData, `lua/social/social.lua`, `social_sys.csv`, the `when=` grammar, birthday and festival STATE (the data comes later), the save section, `tests/lib/social/**` (fixture + the validator port SV1-SV12 with a mutant self-test), the Monte Carlo as a test; the LAST task runs `python3 tools/features/add_autoload.py SocialManager` (E1)** after the P01 / F1 fix-round widened the closed lists.
* **S-data (5, L): `citizens.lua` (tier A 10 "Hjertefolk", tier B, tier C; archetype; birthday; marriage flag; unlock; keeper sample), `gift_tastes.lua`, and the LEAN copy: `social_talk.csv` 346 rows (first meeting for every citizen, greetings by hearts band, chat beats, topics, barks, bios), `social_arch.csv` 300 (8 archetype pools: child, wanderer, fairy, shopkeeper, gardener, watcher, elder, craftsman), `gifts.csv` 133, `birthdays.csv` 25; about 100 voiced lines (`_V` rows).**
* **S-talk (5, M): `SocialTalk.pick` (a key cascade NPC -> archetype -> any with a no-repeat memory), `DialogueBridge.decorate` (greeting once a day, social choices "Giv en gave" / "Fortæl mig om dig" / "Hvad har du på hjerte?", at most 5 choices, an empty module still gets a greeting and a close), topics with taste reveal, the shop greeting resolver, bubbles (quest "!" > heart > birthday candle, drawn in code).**
* **S-gifts (5, M): `GiftRules`, `GiftFlow` (options, the give transaction, ONE reaction page by the cascade `GIFT_<NPC>_<CLASS>_<n>` -> `SOC_ARCH_<ARCH>_GIFT_<CLASS>_<n>` -> `SOC_ANY_GIFT_<CLASS>_<n>`), the `gift_given` quest sugar.** No hotbar quick gift (stub): gifts go through the talk menu and the picker.
* **S-ui (5b, L): the People book `people` (P, pause row "Folk"; read-only, only MET citizens, footer "Du har mødt 12 af 30"), the gift picker `gift`, the calendar tab, the HUD chips `social_hud`, the friendship glyph `SocialHearts` (a heart with a moss sprout, drawn in code, distinct from the five plain health hearts by SHAPE, gold is never used), `rel_ui.csv` (about 40 rows), the registry rows and baselines.**

### 5.3 EXTENDED (waves 5b-6): events and festivals

* **S-events (5b, L, EXTENDED): `EventRunner` (one scene at a time, starts only in phase PLAYING with no modal, retries on `modal_changed` / `day_started`; drives Npc2D / Player2D only through the event API of the P14 / P06 amendments, a missing method skips the directive and the lines still play), `FestivalStage` (turns each activity into an `Interactable2D` at its post), the six activity primitives, the event overlay (`event_overlay`: two ink bars 72 px + HintBar; non-pausing modal `event`, Esc -> UiConfirm "Spring scenen over?" and a skip fast-forwards so rewards are paid ONCE), validators SV9 / SV10.** It is scheduled in 5b because wave 6's content needs it; no CORE package depends on it.
* **S-heart-content (6, L): 40 scenes (4 per tier A citizen at 4, 6, 8 and 10 hearts, `ev_<npc>_h4` / `_h6` / `_h8` / `_h10`, one registry file per citizen) + `heart_events.csv` (about 320 rows).** Heart events are PLAYER-INITIATED: a rose-heart bubble and the dialogue choice "Hvad har du på hjerte?" when hearts, `when`, once and cooldown hold; never a surprise cutscene. The fifth (2 hearts) and a yearly birthday card are the roadmap, not built.
* **S-fest-content (6, M): the nine festivals as registry data + scenes `ev_<id>_open` / `_end`, the five festival stall shops (`lua/shops/festival_markets.lua`), `festivals.csv` (about 190 rows).**

| Date (day of year) | Festival (da / en) | Where | Window | Host | Stays open | Activities |
|---|---|---|---|---|---|---|
| foraar 7 (7, Sun) | Blomsterfesten / Flower Fair | hyggebyen / hyggetorv | 12-20 | mayor_lyra | - (seed_shop is closed on Sundays) | flower contest (category:forage), seed stall, dance |
| foraar 21 (21, Sun) | Honningdagen / Honey Day | hyggebyen / hyggetorv | 11-19 | beekeeper_birk | bakery | honey contest (category:food), picnic, honey stall |
| sommer 14 (42, Sun) | Midsommerlanterne / Midsummer Lanterns | traetoppen / torvet | 18-23 | gardener_hoppe | - | lantern wish, bonfire supper, dance |
| sommer 27 (55, Sat) | Sofus' badedag / Bath Day | traetoppen / badehus | 10-18 | bathkeeper_sofus | (closes none) | free bath, picnic, potluck (category:food) |
| efteraar 14 (70, Sun) | Høstfesten / Harvest Festival | traetoppen / torvet | 12-20 | mayor_lyra | bakery | pumpkin contest (category:crop), harvest feast, harvest market |
| efteraar 27 (83, Sat) | Månemarkedet / Moon Fair | hyggebyen / hyggetorv | 18-23 | appraiser_fru_ugle | magic_store | moon market, gem show (category:gem), lantern wish |
| vinter 7 (91, Sun) | Vinterlysene / Winter Lights | traetoppen / torvet | 16-21 | fairy_lily | - | light procession (dance), lantern wish, warm drinks |
| vinter 21 (105, Sun) | Bagedagen / Bake-off Day | hyggebyen / hyggetorv | 12-20 | baker_maja | bakery | cookie contest (category:food), tasting table, bake stall |
| vinter 28 (112, Sun) | Årsskiftet / New Year's Eve | traetoppen / raadhus | 15-23 | fairy_king | - | year book (scene), lantern release (wish), midnight toast |

Festival ids: `blomsterfesten honningdagen midsommerlanterner badedagen hoestfesten maanemarkedet vinterlysene bagedagen aarsskiftet` (+ `bryllupsfesten`, the wedding, S-marriage). The year has 112 days (4 x 28), weekday = (day - 1) mod 7. All windows end by 23:00; every festival has `bed_hold = true` and `closes = "all"` except Badedagen. **What a festival does (all pure functions of date + data, DT25):** shops are closed unless in `stays_open` (the towns' hours rule asks `shop_closed_by_festival`; a shop is listed only if it is open on the festival's weekday by its own rule: `social_fest_content.stays_open_is_possible_on_the_festival_weekday`); the bed opens at the window's end through the config override `time.sleep_from_hour` (re-applied from the state query on every flush, load, area change and festival event, because the override is a never-saved test seam; `WorldRoot2D.can_sleep_now` already reads it: no edit of `world_2d.gd`); the host stands at `fest_<spot>_host`, attendees (the citizens whose home area is the spot's area, hero twins excluded, at most 15 + the host) on `fest_<spot>_gather_<n>` in the order of `SocialRng.roll(seed, [festival, npc])` through `override_for(npc, td, hour) -> {area, post, state}` (travel starts one game hour before the window); the HUD ribbon "Høstfesten · åben til 20:00"; `festival_now` and `town_festival_started / _ended`; attendance points (+20 to the host and to every citizen talked to during the window, once per festival and year); festivals ignore weather. **The six activity primitives** (the only mini-games): `contest` (the player picks one matching item in the gift grid, score = sell value x (1 + 0.5 x rarity rank) x (1 +- 0.15 jitter), three NPC bars of the year, rewards first / second / third, deterministic per seed and year; the prizes are items of rarity <= rare, never keepsakes, capped in VALUE by validator rule SV14: first <= min(2 x the cheapest winning entry, 400 g), second <= 0.7 x first, third <= 0.4 x first), `potluck` (donate to a shared goal of 12), `wish` (a lantern, +20 to the host), `feast` (energy and hearts once), `dance` (the highest-hearts citizen present, +30), `market` (a festival stall shop through P18's panel).

### 5.4 LATER (wave 6, built last): marriage-style relationships (S-marriage, DT3)

Cozy, child-friendly, **no gender field anywhere** (eligibility is `partner = true` on 11 adult citizens: baker_maja, merchant_pip, gardener_hoppe, carpenter_brumme, postman_pip, bathkeeper_sofus, beekeeper_birk, rasmus, lamplighter_kiki, bertil, bodil), no break-up, no jealousy, a refusal that costs nothing, nothing in the game requires it. The ladder (data `lua/social/relationships.lua`, config key `relationships`):

| Stage | Needs | Action | Result |
|---|---|---|---|
| bedste ven | 8 hearts | - | the stage of 5.1 |
| **hjertven** | `partner = true`, 8 hearts, the item **Hjertebuket** (3 wild_flower + 1 moonflower + 1 honey, crafted via `lua/recipes/social.lua`, never sold) | given through the picker's special path | a short scene (authored for Hoppe, Brumme, Maja, Birk; a generic archetype scene for the other 7); several hjertven allowed |
| **forlovet** | hjertven >= 7 days, 10 hearts, home tier >= 3, no other engaged partner, the item **Løfteagern** (2 gold_ore + 1 amber) | given | `partner = {id, since, stage}`, the wedding date announced |
| **gift** | the wedding festival `bryllupsfesten` (the first Sunday >= proposal + 7 that is not beside a festival; moves one week if you are not there by 20:00: never a penalty) | attend | `rs = gift`, `relationship_changed {partner: true}` |

A refusal is gentle ("Jeg er rigtig glad for dig, men lad os vente lidt"): the item is not consumed; "Lad os være gode venner" leaves hjertven at no cost. **Life together** (F2 / F6 hooks, late bound): the partner keeps their job and their shop is never opened unstaffed: they stand in the farmhouse room 19-22 and in the morning from 06:00 until a COMPUTED leave time = opens - walk x 2 / 60 - 5 minutes (Maja has no morning there, Kløvermynte until 06:48, Brumme and Rasmus 06:56, Pip 07:59, Sofus 09:08), validated for the 11 candidates by `hours.keeper_covers_hours` with a partner overlay; one deterministic daily chore at 06:00 (water up to 12 planted plots, else feed the animals, else a love note); the tier-8 house party and the weekly visitor gift name FRIENDS (hearts >= 4, up to 6): these live in S-marriage, so without it `HomeManager.guests_today()` is [] and the gift stays anonymous (DT37). The vocabulary (stage words and the two items) is Q2; no `PARTNER_` row exists before it is confirmed. Honest: seven of the eleven candidates use generic lines until someone authors them; no seated or sleeping pose, no second bed, no children.

### 5.5 Balance (Monte Carlo, 200 runs x 336 days; `social_scripts/mc_result*.json`)

| Profile (100 runs x 336 days, `se6`) | Social time of a game week | Tier A: 8 hearts, p10 / p90, never | 10 hearts |
|---|---|---|---|
| typical, LEAN events (4, 8), the designers' model (`free`: anybody can be talked to) | 20 % | **day 71** (55 / 97, 0 %) | day 86 |
| typical, LEAN events, visits at mixed hours, keepers reachable at the counters (`mixed`) | 20 % | **day 70** (51 / 108, 0 %) | day 84 |
| the same WITHOUT the talk cells (the defect) | 20 % | day 69 (51 / 154, **10 %**); Sofus never in 98 % of the runs, Natteblik in 100 % | day 81 |
| typical, four events (4, 6, 8, 10), `free` / `mixed` | 20 % | day 66 (51 / 90) / day 65 (48 / 101) | day 82 / day 80 |
| casual | 6 % | day 191 | day 231 |
| dedicated | 54 % | day 39 | day 50 |

The claims of `social.balance_claims_hold` are RANGES in both availability variants (median <= 80 and p90 <= 115 with the LEAN events, <= 75 and <= 110 with four events) with a ratchet file, because a typical player has seen all 20 LEAN scenes by day 97 (p90) and has 14 of 30 citizens at 10 hearts after one game year (the castle is day 345): friendship saturates before the main game does, which is why the 6- and 10-heart scenes are built and the year-2 hook is the roadmap (RK16). Chat alone: 8 hearts on **day 50**, 10 on day 64 (the DF3 floor, for a citizen talked to every week); the fastest possible 10 hearts is day 32 (best ordinary gift 60 points x 2 + chat 100 = 220 per citizen per week). Chat is 92 % of all points for a typical player, so the weekly cadence IS the pacing. Anti-exploit (each row has a test): daily talking pays 0, Esc-farming pays 0, gift spam is capped by 1 / day, 2 / week and the repeat halving, quest items and keepsakes are never offered, save-scumming a contest changes nothing (the roll is keyed on festival, year, citizen), a 50 h skip catches up idempotently.

### 5.6 UI (DT21): six registry rows

`people` (modal, esc depth 1, initial focus = the citizen talked to last else the first row; tabs `[Alle · n] [Nære · n] [I dag · n]`), `gift` (modal, 6 x 4 grid of `item_slot`, opens AFTER `dialogue_ended`, `%GiveButton` is dashed and non-focusable with the reason when a limit is used), `calendar` (third tab of the journal, 7 x 4 day cells, birthdays of KNOWN citizens as `♥ Navn`, festivals lavender, today ringed in ink; three theme variations `CalCell`, `CalCellFest`, `CalCellToday` added to P28's builder), `social_hud` (focus none: `%FestivalRibbon` at y = 64, `%BirthdayChips`), `event_overlay`, and the towns' `post`. Every row carries the nine standard checks (initial focus, focus walk, focusable report, rule report, escape chain, ring / panel / button pixels, compare) and a baseline PNG owned by its package; no HTML mock exists for these screens, so the baselines are pinned after the lead has looked at the first windowed capture (five mock shots exist in `social_scripts/shots/final/`).

### 5.7 Packages

| Id | Class | Wave | Size | What |
|---|---|---|---|---|
| **S-core** | CORE | 4 | L | `SocialManager` + helpers + validator (SV1-SV12, SV14) + balance test with availability variants + the sixth autoload (18 tasks) |
| **S-data** | CORE | 5 | L | citizens, tastes, LEAN copy (804 rows, about 100 voiced lines) |
| **S-talk** | CORE | 5 | M | cascade, decorate, topics, shop greeting, bubbles |
| **S-gifts** | CORE | 5 | M | taste resolution, limits, protections (tools, next-tier materials, set pieces), confirm predicate, give transaction, reaction |
| **S-ui** | CORE | 5b | L | People book, gift picker, calendar tab, HUD chips, glyph |
| **S-events** | EXTENDED | 5b | L | event runner, festival runtime, six primitives, overlay |
| **S-heart-content** | EXTENDED | 6 | L | 40 heart scenes (4 / 6 / 8 / 10 hearts) + copy |
| **S-fest-content** | EXTENDED | 6 | M | nine festivals + scenes + stall shops + copy |
| **S-marriage** | LATER | 6 | M | ladder, wedding, partner in the home, daily helper, items, copy |
| **S-qa** | QA | 7 | S | `zz_social`: a 112-day year walk, determinism and exploits, windowed run |

Honest stubs of the track: hotbar quick gift, letters about birthdays and events through the mailbox, a rain venue for festivals, seated or sleeping partner poses, children, five heart events per citizen, real voice, festival decor art and music (I5 / P24 placeholders).

---------------------------------------------------------------------------------------------------------------------------------------------

## 6. The town loop test (I2-loop-harness, wave 5; I6-town-qa, wave 7)

**The user's loop (binding):** start a new game -> intro on the farm -> cross the hanging bridge -> Trætoppen -> talk to a citizen (hearts +) -> enter the seed-shop interior -> shop panel -> buy seeds (hours respected) -> give a gift -> post office -> back to the farm -> till / plant / water -> sleep -> the next day the citizens have moved by routine -> save / load -> the same state.

### 6.1 Architecture

ONE test section `town_loop` (`tests/sections/town_loop.gd`: `run(t)` headless legs, `run_windowed(t)` leg L15) and `town_budgets` (every number of 7.6 as a named check). It drives the REAL player with REAL input (`LoopWalker`: steering in ground space, A* over a grid baked from the physics space with the body ladder x1.4 -> x1.2 -> x1.0, no teleport on the path being tested), the real UI and the real save system, and proves "same state after load" with a canonical digest.

| File (owner I2) | Role |
|---|---|
| `tests/lib/town_loop/loop_caps.gd` (`LoopCaps`) | capability probes (file exists / autoload method exists / group non-empty); a leg declares `needs`, a missing capability = SKIP with the list |
| `walker.gd`, `clock.gd`, `digest.gd` | real-input walking; `LoopClock.to(hour, minute)` through `advance_time`, `next_day()` through the real end-of-day path, `bed_sleep()` through the real bed; the digest |
| `probe.gd` (`TownProbe`) | the ONE adapter to the sibling tracks' names (`NpcDirector.where_is / population / is_present / is_absent / is_away` through `Svc.static_call`, `Hours.state / shop_open`, the Door2D of a building, `SocialManager.hearts`); when a sibling renames something only this file changes |
| `loop.json`, `gates.json`, `digest_volatile.json` | the loop as DATA (which citizen, shop, item, routine probes, waypoints), the gate table, the volatile payload paths (exactly `/game/play_time_seconds`, `/meta/saved_at`, `/meta/timestamp` and `/meta/summary`: `SaveManager.gather_payload` writes the two clock fields from the real clock; measured, two gathers 1.1 s apart differ in them) |

Headless cost: a 316-tick real-input walk costs 0.05 s wall with `--fixed-fps 60` (3-5 s without); `tests/run_playtest.sh --fast` forwards it (RT8). The gate variable is `TOWN_LOOP_WAVE=4|5|5b|6|7` (the harness rejects unknown CLI flags): UNSET = a leg without its capability SKIPs and is listed; SET = every leg required at that wave must have run and passed (`town_loop.gate_leg_not_skipped` names the leg and the missing capability). Proven in the prototype on main: unset PASSES with 4 checks and the skip list; `=4` and `=5b` FAIL exactly one check naming each missing leg.

### 6.2 The legs (about 90 named checks `town_loop.<leg>_<check>`)

| Leg | What is proven | G |
|---|---|---|
| **L00 farm_start** | new game on the farm, the first morning in order Pip -> letter -> Pip's goodbye with every `dialogue_ended` exactly once, quests `intro_lottery` and `forste_dage` accepted, Esc skips, control returns, the banner says "Min Trækronsgård" never "Trætoppen" | 4 (1, 6), 5b (2-5, 7) |
| **L01 bridge** | walk to the bridge end, arrive in Trætoppen once (`from_farm`), no ping-pong (40 frames), unlock toast and the `cross_bridge` objective | 5b |
| **L02 citizens_present** | Monday 10:00: the node set equals `where_is` minus `dropped`, <= 16 visuals, nodes freed on exit, one `area_populated`, the hero twin absent | 5b |
| **L03 talk** | walk and talk, first-meeting copy, the weekly heart once (`friend_changed` exactly once, ONE toast), Esc after the first line gives none, the People book shows the heart; **l03b** inside the seed shop the player stands on a talk cell, E opens the keeper's dialogue and pays the weekly heart once, E on the centre cell opens the panel | 5 (a-c), 5b (d, e, l03b) |
| **L04 shop_door** | the door enters `int_froebutikken` (no ZONE toast, banner `BLD_FROEBUTIKKEN`), no re-trigger, the calendar runs inside, keeper behind the counter, the counter is a barrier, room budget and zoom | 5b |
| **L05 hours** | closed before open (reason `hours`), opens on the hour, closed weekday (`day`), closing warning at minus 30 and eviction through the close request, an open panel survives closing, hours come from data, a festival closes shops (`festival`), the exit door is always open | 5b |
| **L06 panel** | the counter opens the panel (dialogue entry accepted at G5), greeting and keeper bust, buy exact (hobbit -10 %), refusals have reasons, Esc restores the world; **l06b** talk to Maja at 10:00 through a talk cell, one weekly heart; **l06c** Monday 12:00, enter Hasselnøds yard, E on a talk cell opens her dialogue with the upgrade choice, E on the desk cell emits `open_home_builder {tier}`; **(W)** the panel over the live interior (blur strip) and `compare_guide shop=` <= 18 | 5 / 5b |
| **L07 gift** | the gift via the talk menu, taste classes +40/+20/+8/0/0, limits 1/day 2/week and the birthday multiplier, quest / worn / placed items refused, the item removed once | 5b |
| **L08 post** | the post office interior with V6's mailbox INSIDE the room, the letter of the day, one per day, parcels = honest stub; **G6:** `l08_post_screen_where_is` | 5b / 6 |
| **L09 return** | back over the bridge, the farm state intact (digest), citizens freed | 5b |
| **L10 farm_work** | `l10_seeds_from_shop`, `l10_till_plant_water` with real `use_tool`, `l10_energy_costs` (hoe 3.0, seed 0.5, can 1.5, x race multiplier), crop signals once per plot (G4); `l10_forste_dage_objectives` and `l10_hint_once_per_save` (they need N04: G5b) | 4 / 5b |
| **L11 sleep** | the bed opens at 18:00, sleep rolls the day, crops grow and the shop restocks and the bin pays at dawn, the mail objective on day 2, the night watch sends you home, a pass-out wakes on the farm | 4 / 5b |
| **L12 routine** | citizens moved by routine, a route takes time (no teleport), 03:00 nobody outdoors, rain override, Saturday variant, Pip at the farm mailbox from day 2 but not on day 1, Hoppe's Wednesday visit | 5b |
| **L13 save_load** | digest round trip, citizens same places, `social` at order 60 after `loot`, an old save without `social`, content drift is a warning (orphans), `save_game` p95 <= 25 ms and payload <= 60 KB | 4 / 5b |
| **L14 loop_budget** | headless <= 120 s (<= 15 s with `--fixed-fps 60`), interior enter <= 150 ms, parked return <= 5 ms, orphan nodes grow <= 5, zero engine messages | 5b |
| **L15 windowed_run** (W) | the same loop in a real window <= 110 s: 14 shots S01-S14 with region assertions, citizens visible, free-on-exit VRAM falls >= 40 MB | 7 |
| **L16 audio** | cue log: shop bell, footstep surfaces wood / stone / rope, ambience by area and night, purchase / heart / gift cues, closed-door knock, town bell on `routine_changed`, a cue without a file is silent | 6 |
| **L17 copy** | the CORE copy lints clean, no raw keys in da and en, boxes fit, voiced rows reviewed and hashed, citizen slots complete | 6 |
| **L18 extensibility** | copy the repo to a temp project and add ONLY the data files of `tests/fixtures/town/**`: a citizen, a building (a new walk-in shop), a routine edit, shop hours, a festival, a heart event, a mail quest; zero `.gd` / `.tscn` changed | 6 |
| **X01-X09** | birthday, festival, heart event, relationship ladder, mail, farm visit, seasonal decor, rain festival fallback, marriage commitment (skeletons with capability guards, named when the packages ship) | 6 / 7 |

### 6.3 Gates

| Gate | Required | Meaning |
|---|---|---|
| **G4** (first RUN at the wave-5 gate against the merged wave-4 tree) | L00 `new_game_on_farm`; L10 `l10_seeds_from_shop`, `l10_till_plant_water`, `l10_energy_costs`; L11 `bed_opens_at_18`, `sleep_rolls_day`; L13 `digest_roundtrip`, `save_cost` | the farm loop and the save digest work |
| **G5** | + L00 intro checks; L03 `walk_and_talk`, `first_meeting_copy`, `weekly_heart_once`, `esc_first_line_no_heart`; L06 (entry = dialogue); L13 `social_section_order`, `old_save_without_social` | NPC runtime, dialogue, shop panel, quests |
| **G5b = the first playable town loop** | L00-L14 CORE + `art_shops.core_rooms_stand_in_free` + `towns_interiors.kit_table_matches_manifest` | bridge, city, citizens, interiors, hours, panel, gifts, post office, routines, save |
| **G6** | L16, L17, L18; `l08_post_screen_where_is`; `l05_festival_closes_shops`; the X legs of wave 6 | audio hooks, copy rules, data-only extensibility, extended content |
| **G7** | L15 windowed, `town_budgets.*`, all X legs, the three-hero run | acceptance, recorded in `docs/qa/town/` |

**Digest** `LoopDigest.of(t) -> {payload, world, citizens, shops}`: SHA-256 of canonical JSON; payload = `SaveManager.gather_payload()` with sorted keys and floats snapped to 1e-4 minus the four volatile paths (`digest_stable_over_wall_clock` compares two digests 1.1 s apart; the earlier 'exactly two paths' was an artefact of comparing inside one wall-clock second); world = `{area, player_cell, hour, minute, day, season, weather}`; citizens = sorted `[{id, area, post, state}]` from `where_is` (positions are NOT saved, they are derived); shops = `{shop: is_open}`. `l13_digest_has_teeth` proves a +1 gold payload changes it. **Mutation checks** (`town_loop.selftest_*`): shop hours ignored, interior `@projection ortho`, NPC nodes not freed, a heart on Esc, a digest drop list widened to `/economy`, `social` registered at order 10, a closed door that travels, a cue emitted without a log entry: each makes its named check fail on a clone.

### 6.4 The windowed shots (`tests/checkpoints/town/shots.json`; one window via `impl/tools/windowed.sh`, <= 110 s, then LOOK)

S01 `farm_intro` (dialogue crop vs `guide_ref_ui/dialogue_box.png` <= 16), S02 `farm_bridge_end` (lantern halos brighter than the deck, lights <= 12), S03 `city_arrival` (banner + HUD boxes <= 12), S04 `city_torvet_noon` (>= 6 citizens), S05 `dialogue_hoppe_hearts`, S06 `shop_door_closed_0830`, S07 `shop_interior_noon` (keeper behind the counter), S08 `shop_panel` (`compare_guide shop=` <= 18), S09 `gift_picker`, S10 `post_office`, S11 `farm_planted_morning`, S12 `city_next_morning` (the position set differs from S04), S13 `people_book` (+ S13b the calendar tab), S14 `festival_day_city` (extended). Guide diff targets: shop <= 18, dialogue crop <= 16, city HUD boxes <= 12, the new screens' baselines <= 1.5 once pinned.

### 6.5 Four QA packages, one index (DT32)

N08 (farm: strict `art_complete`, shots, budgets in a real window, the first-morning checklist), T-qa (towns: `zz_towns`), S-qa (social: `zz_social`, a 112-day year walk with the real managers and a scripted player, determinism and exploit scenarios), and I6-town-qa (rows 31-39 for the three heroes (`--character=animal|fairy|hobbit`, hobbit also checks the 10 % discount), the 14 shots per hero, the budget table, `TOWN_QA_REPORT.md` linking the three domain reports). QA packages hard-depend on CORE packages only; the EXTENDED ones are `softDependsOn` (a dropped package = its legs SKIP with the capability name).

---------------------------------------------------------------------------------------------------------------------------------------------

## 7. Copy, voice, audio, art, memory and performance plan (packages I1, I3-I5, P24, P26)

### 7.1 Danish copy: volume, who writes it, how it is reviewed (DT27)

The English column is complete in every phase (en/da words 1.163). **C1 CORE** (waves 5-5b) = 1,065 rows (the five counter prompts of `towns.csv` and the three gift-confirm rows added), about 10,300 Danish words, 92 voiced lines, 25.7 h of native review; **C2 EXTENDED** (wave 6) = about 979 rows (keepers.csv 61 instead of 66, heart_events.csv about 320 instead of 180), about 10,600 words, 63 voiced, 26.5 h; C3 = the roadmap to the 30-citizen TARGET (3,525 rows) is NOT built here (same keys, same cascade, more rows, no new code). Review hours use an ASSUMED 400 words per hour. Today's whole corpus is 1,548 keys / 7,801 Danish words.

| CSV (each with a `keep` import stub) | Families | Rows (C1 / C2) | Writer package |
|---|---|---|---|
| `social_sys.csv` | `SOC_SYS_`, `REL_STAGE_` | inside C1 | S-core (4) |
| `social_talk.csv` | `SOC_` | 346 / 24 | S-data (5) |
| `social_arch.csv` | `SOC_ARCH_` (carved out of `SOC_`) | 300 / 0 | S-data (5) |
| `gifts.csv`, `birthdays.csv` | `GIFT_`, `BDAY_` | 133, 25 / 0 | S-data (5) |
| `rel_ui.csv` | `REL_` (`REL_STAGE_` is S-core's) | 43 / 20 | S-ui (5b) |
| `social_events.csv` | `SOC_EV_` | 0 / 40 | S-events (5b) |
| `heart_events.csv`, `festivals.csv`, `partner.csv` | `HEART_`, `FEST_`, `PARTNER_` | 0 / 320, 190, 160 | S-heart-content, S-fest-content, S-marriage (6) |
| `towns.csv` | `BLD_`, `HOURS_`, `ACT_`, `COUNTER_` | 60 / 0 | T-towns-core (4) |
| `keepers.csv` | `KEEP_` | 0 / 61 | T-greetings (6) |
| `post.csv` | `POST_`, `WHERE_` | 0 / 75 | T-post-office (6) |
| `farm_signs.csv`, `farm_site.csv`, `farm_tutorial.csv` (`farm_greenhouse.csv`, N07 only) | exact `SIGN_ORCHARD`, `SIGN_FARM_BRIDGE`, `SIGN_FARM_FOREST`; `FARMSITE_`; `TUT_`, `DLG_FARMINTRO_`, `QUEST_FORSTE_DAGE_`, `OBJ_FORSTE_DAGE_`; `GHOUSE_` | 74 / 0 | N01 (4), N02 (5), N04 (5b), N07 (7) |
| `core.csv` | `NPC_<ID>` of the 8 new citizens | 25 / 0 | V1 (design2) |

**Style sheet** `docs/copy/STYLE_SHEET.md` (I1) R1-R11: du-form, short, concrete cosy detail; length by slot (dialogue page <= 240 characters, a spoken line <= 14 words, shop bubble <= 110, choice <= 32, name <= 21, button <= 10); child-friendly (no alcohol: "varm æblemost", no violence, jealousy, insults or shaming; **eligibility is never gender-gated and no sentence assumes the hero's gender**); display names, never ids or stale names (Borgmester Hyldeblomst, Bagerfe Rosmarin, Butiksfe Kløvermynte; the three Pips are always written with their display names); voiced lines contain no `%`, no digits, no onomatopoeia; no bare `%s` item name inside a sentence; time words from `UI_WEEKDAY_*` / `UI_MONTH_*`; both columns with the same `%` signatures; band-only tags (a day-part tag only on a minority of lines); keys `SOC_<NPC>_<SLOT>[_<SEASON>][_<PART>][_H<band>]_<n>[_V]` with the cascade NPC -> archetype -> any. **Copy lint** `tools/copy/copy_lint.py` (C1 banned and stale names, C2 length by key shape from `font_budget.json`, C3 voiced rules, C4 forbidden words, C5 display-name parity, C6 key convention and cascade completeness, C7 da / en signatures, C8 `review_status.json` consistent, C9 repetition guard, C10 `_V` rows in the index and vice versa) run by the section `copy_rules` with mutation checks.

**Review state machine** `docs/copy/review_status.json` per CSV: `draft` (the writer's wave) -> `ai_reviewed` (a second agent with a fresh context, the SAME wave; only now may rows be voiced) -> `native_reviewed` (set ONLY by a commit of the user; `voice_frozen` becomes true). P26 (wave 6) never edits a file at `draft` (it files the defect back) and never overrides a voiced key (R.17); C2 files delivered at `draft` stay `draft` and unvoiced; `docs/copy/REVIEW_QUEUE.md` is sorted by exposure (shopkeepers and daily citizens first).

### 7.2 Voice (DT27)

`say -v Sara` stays the placeholder (the only da_DK voice; 0.65 s per line); 8 archetype presets (= the 8 social archetypes) plus a deterministic +-4 % pitch / +-3 % rate jitter per citizen from FNV-1a of the id:

| Preset | pitch / rate | Preset | pitch / rate |
|---|---|---|---|
| child | 1.32 / 1.10 | gardener | 1.02 / 0.98 |
| wanderer | 1.22 / 1.16 | watcher | 0.92 / 0.94 |
| fairy | 1.18 / 1.08 | elder | 0.84 / 0.82 |
| shopkeeper | 1.10 / 1.02 | craftsman | 0.74 / 0.88 |

Filter chain `asetrate=22050*P,aresample=44100,atempo=1/P` (the plan's 44100 form halves the duration), OGG mono 22.05 kHz q2 (5.33 KB per second), generated lines get `atempo 0.88`. **Which rows:** first meetings, the headline greeting of each hearts band (tier A), milestone chat beats, one reaction per gift class (tier A / B), birthdays, the keeper greeting, quest offers, and in C2 the proposal and the ceremony; NOT voiced: barks, topics, weather lines, archetype pools, UI; English is never voiced. **Index:** a voiced CSV row ends in `_V`; `tools/voice/build_index.py` writes the generated `lua/dialogue/_voiced_social.lua` (`kind = "config"`, key `voiced_index`, one `{ text_key, voice_key }` block per row) in the only directory the existing voiced-key lint scans, so `loc_check` covers CSV-selected lines with no edit of a built file (proven in the clone: 69 voiced keys, 0 lint findings; a wrong hash is reported as `[voiced-hash]`); the manifest hash covers them; `RECORDED.txt` lines are never regenerated; a TTS line whose text changed is regenerated in the same commit. Budget: 155 new voiced lines = 3.2 MB + 75 existing lines about 1.9 MB. The bulk bake is a lead action after P26's pass and the user's listening test (Q4).

### 7.3 Audio (P24, DT28)

`AudioManager` stays the only audio autoload and creates `AudioDirector` (`scripts/audio/audio_director.gd`) as a child; data `lua/config/audio.lua` (config key `audio_map`); every call is appended to `AudioManager.cue_log` (ring of 256 `{t_msec, kind, id, played}`) even when no file exists, so headless tests assert HOOKS. Hooks: `area_changed` into a shop -> `sfx/shop_bell` then `amb/shop_interior` (the bell on enter and exit); area ambience `amb/town_day` / `amb/farm_day` with `_night` variants by `TimeManager.is_night()` (a state compare, not an edge), crossfade 1.5 s; rain overlay; `item_purchased` -> `coin_clink`; `friend_changed` -> `heart_up`; `gift_given` -> `gift_sparkle`; `post_read` -> `letter_rustle`; `bath_taken` -> `bath_splash`; the three closed whispers -> `door_locked_knock`; `shop_open_changed` while the player is inside -> `closing_bell`; `bin_payout` -> `sfx/bin_bell`; `relationship_changed` -> `sfx/stage_up`; `town_festival_started` -> `sfx/festival_horn` and `music/festival_<season>` (ducks ambience -6 dB); `routine_changed` at 12:00 and 18:00 outdoors in the city -> `town_bell`. **Footsteps (player only in CORE):** a cue per half walk cycle (every 0.333 s walking, 0.25 s running), pitch +-6 %, never the same variant twice; surface from `Surface.at(area, pos)`: the builder's `surface_fn` first (city platform -> wood, bridge -> rope; room floor), else the ground char (`d` wood, `c` stone, `=` rope, `p` dirt, grass else). **Placeholders** are SYNTHESISED in pure Python (`tools/voice/{sfx,ambience,music}_synth.py`: 14 footsteps, 14 named cues (shop_bell, door_open_wood, door_locked_knock, coin_clink, heart_up, gift_sparkle, letter_rustle, page_turn, bath_splash, town_bell, festival_horn, closing_bell, bin_bell, stage_up), 7 ambience loops of 24 s, 5 music loops of 45-60 s, about 2.3 MB) and replaced by dropping files of the same name. Tests `audio_town.*`; the loop leg L16 re-checks them in the real world.

### 7.4 Art (DT29)

Same look and pipeline as A1 (soft CG, one orthographic 36-degree camera, 87.074 px/m, warm outline, WebP q94); no Danish or English glyph is ever baked into art (shop signs are emblem plates; the label is `BLD_<ID>`). Bake CPU is trivial (52 s in total); the work is about 58 new templates (about 2,200 lines at A1's 38 lines each) and the contact-sheet review by a human.

| Package | Pieces | Sprites | VRAM if all resident | What |
|---|---|---|---|---|
| **I3-art-shops** (CORE, 5b) | 35 | 66 | 8.8 MB (a typical room 2.6 MB) | the counter band (`counter_pine` 3x1, `counter_end`, `counter_hatch`), `sign_bracket`, the 16 pieces the 14 core rooms still draw as stand-ins (brick_oven, bread_rack, anvil, forge, cauldron_stand, hay_bale, feed_sack_stack, plank_stack, workbench, mannequin, pigeonhole_wall, mail_sack, parcel_stack, letter_desk, wooden_tub, notice_board_indoor) and 15 emblem plates |
| **I4-art-shops-b** (EXTENDED, 6, XL) | 69 | 115 | 15.4 MB | identity dressing in 15 sets (generic 10, seed 6, post 2, bath 4, hall 3, hut 4, bakery 4, smithy 5, magic 6, animal 4, builder 5, furniture 3, tailor 5, timber 3, flea 5), placed by per-room overlays `data/interiors/dress/int_<id>.json`; droppable set by set |
| **I5-art-festival** (EXTENDED, 6) | 24 | 53 | 7.0 MB (one season 1.8) | bunting, banner poles, lantern strings, stage, benches, maypole, bonfire, pumpkins, sheaves, flower arch, ice lanterns, awnings, wreaths + `festival.json` slots and the data-driven `FestivalDecor.attach(director)` (non-solid, late-bound, `lua/config/festival_decor.lua` one row per festival id) |
| **N03 / N06** (farm) | 10 props + 3 backdrops + terrain / 12 dress + 4 particles + 3 apple seasons | - | kit 15.8 MB (S3TC) / <= 4 MB | section 3.7 |

Staging honesty: until I3 lands (5b) the 14 core rooms use the 15 listed stand-ins (a fireplace for a forge, a rug for a tub); `art_shops.core_rooms_stand_in_free` turns that list to zero at G5b. I4 and I5 are polish: the rooms and the festivals work without them.

### 7.5 Texture memory (measured in the real renderer, `Performance.RENDER_TEXTURE_MEM_USED`)

Baseline world + fairy player 41.1 MB; 130 furniture r0 sprites +18.7 MB (RGBA8 x 4/3 exactly); 15 NPC visuals +134.0 MB = **8.93 MB each** (9 fairies 8.67 + 6 villagers 9.33; S3TC x 4/3 exactly); a second instance of the same visual +0.0 MB; freeing the nodes +0.0 MB. Terms: farm = N03 kit + field_grass 0.7 + spike props 3.0 + tiles 6.6 + house tier 10 6.3 (82.1 MB lossless, 32.4 MB with S3TC); Hyggebyen 29.1 (11.3 + a backdrop pair of an ASSUMED 17.8); city 62.4; interior art 4.2.

| Where the player is | Total lossless | **Total with the S3TC farm kit** | Margin to 400 MB |
|---|---|---|---|
| the city (peak: baseline + parked farm + parked Hyggebyen + city + 16 looks) | 357.6 (364.4 on a festival day) | **307.9** (314.7) | **92** (85) |
| Hyggebyen | 295.2 | 245.5 | 154 |
| a shop interior (keeper + 3 looks) | 192.2 | 142.5 | 257 |
| the farm (3 visitors) | 179.1 | 129.4 | 271 |
| worst case, NOTHING freed | 394.1 | 344.4 | 56 |

**Rules (each is a check in `town_budgets`):** R-V1 NPC nodes are freed on area exit; R-V2 builder areas keep textures in INSTANCE dictionaries (never `static var`; `ArtCatalog`'s static caches never free: 62 MB would leak); R-V3 backdrops of builder areas are loaded by the builder; R-V4 `warm_clips` warms `idle talk` for radius-0 keepers and `idle talk walk` / `idle talk hover` for walkers (today's constant leaves `walk` cold for the 6 walking villagers: a first-step hitch of 15-37 ms; D0's task, RT22); R-V5 at most 16 distinct live visuals per area; R-V6 interiors hold the keeper + at most 4 other presences. Fallback ladder if a number is exceeded, in order: S3TC for the city's backdrop pair (about -13 MB); cap 16 -> 14 (-17.9 MB); keepers idle+talk only (-36 MB for nine); background citizens share bodies by tint; `walk` sheets re-baked at 192 px; the festival kit down to one season.

### 7.6 Performance budgets per area (`tests/sections/town_budgets.gd`)

| Area / system | Metric | Budget | Measured |
|---|---|---|---|
| shop interior | nodes / warm rebuild / first visit / lights / draw calls / frame | <= 130 / <= 12 ms / <= 60 ms / <= 4 / <= 60 / <= 4 ms | 62-119 (p50 87) / 1.8-6.2 ms / 4.4 ms p50 / 2 + 2 halos / 36 / 1.6-2.1 ms |
| city (levelled builder) | warm build / frame / draw calls / lights / nodes | <= 40 ms / <= 6 ms / <= 250 / <= 12 / <= 700 | 8-12 ms / 3.7 ms / 90 avg 131 max / - / 580 |
| grid area, Hyggebyen-sized | warm build / parked return / frame | <= 60 ms / <= 5 ms / <= 4 ms | 21.9 ms / 0.77-1.05 ms p50 / 2.3-3.0 ms, 94 draw calls (a 12 x 12 fixture; ratcheted at the first accepted Hyggebyen build) |
| **the farm** | build / frame / draw calls at 0.4, 0.3, 0.2 / VRAM / lights | < 60 ms / <= 8 ms / <= 560, 640, 780 / <= 130 MB / <= 12 | 20.4-47 ms / 6.2-7.5 ms / 502-524, 597, 723 / 100.0-105.7 MB / 11 |
| 16 live citizen visuals in view | wall / draw calls | <= 4 ms / <= 160 | 2.72 ms / 114 (+0.025 ms and +1.25 calls per visual) |
| citizens (30 agents) | director per physics frame / `where_is` sweep / route plan p95 | <= 0.4 ms / <= 0.3 ms / <= 1 ms | 0.045-0.186 ms / 92-260 us / 365 us |
| area switch | `travel()` with 12 cold NPC (windowed) | <= 0.8 s | 751 ms (the fade is 0.47 s fixed) |
| save | `save_game` p95 / payload at the full cast | <= 25 ms / <= 60 KB | 8-13 ms, 2-34 KB |
| copy | CSV reload added | <= 150 ms | LEAN +37 ms |
| memory | process VRAM; current-area peak | <= 400 MB; <= 320 MB (holds only with the S3TC farm kit) | 307.9 MB |
| audio | simultaneous players | <= 13 | 8 SFX + 2 ambience + rain + music + voice |

---------------------------------------------------------------------------------------------------------------------------------------------

## 8. ALL contracts in one place (names exactly as the packages use them)

### 8.1 Autoloads and the E1 rule (DT17, DT35)

The feature addendum closed the autoload list at five feature names appended by `tools/features/add_autoload.py` after the 11 base autoloads (HomeManager 10, FurnitureManager 20, WardrobeManager 30, LootService 40, CollectionLog 50 optional); the dungeon addendum adds NONE (its run node is a child of LootService). **This addendum adds exactly ONE name, the sixth:**

| Autoload | File | Owner | Save section | Registration |
|---|---|---|---|---|
| `SocialManager` | `scripts/social/social_manager.gd` | S-core | `social` (order 60) | python3 tools/features/add_autoload.py SocialManager (sanctioned edit E1: the SIXTH feature autoload, the last task of S-core after the P01 / F1 fix-round) |

The closed lists that must be widened FIRST (fix-round, in this order): the tool's CONTRACT and `tools/features/test_add_autoload.py` (F1, RT2: every literal 5 becomes `len(NAMES)`; the self-test builds every test root from the pristine form of the project it is given, because it failed as soon as ANY feature autoload line existed; no foreign section is edited), `tests/tools/check_project.gd` + its fixture (P01, RT3: `FEATURE_AUTOLOADS` gains `SocialManager`, the literal pins become `11 + FEATURE_AUTOLOADS.size()`), `tests/lib/features/fresh.gd` `FEATURE_NODES` (F1, RT2) and the save registry tests (P15, RT1). Measured in the clone: without the patches `p01.autoloads_base_in_order_features_after` fails with `unexpected autoload SocialManager`; with them `check_project` passes 59 of 59.

### 8.2 EventBus: 0 new typed signals, 25 new `game_event` names (DT20)

NONE new (75 stay exact: core.signal_contract_exact); friend_changed(npc_id, hearts) keeps its arity and fires only on whole hearts; everything else is EventBus.game_event(name, payload). `EventBus.game_event(name: StringName, payload: Dictionary)` has arity 2; consumers ignore unknown names; payload values are JSON-safe.

| Name | Payload | Emitter | Consumers | Note |
|---|---|---|---|---|
| `plot_tilled` | `{plot_id}` | P06-player-farm-core | N04-farm-first-morning, I2-loop-harness | every successful hoe use; the tutorial quest binds to it |
| `crop_ready` | `{plot_id} (exact keys are P06's; N04 reads only the name)` | P06-player-farm-core | N04-farm-first-morning | a plot becomes READY (hint trigger) |
| `field_expanded` | `{id, cells, price}` | N02-farm-objects | - | the field expansion was bought (tests and quests may bind it) |
| `bin_shipped` | `{item, amount}` | N02-farm-objects | - | one stack put into the shipping bin (tests and quests may bind it) |
| `bin_payout` | `{gold}` | N02-farm-objects | P24-audio-voice, I2-loop-harness | at day_started: what the bin paid (the farm's bell cue) |
| `farm_stage_changed` | `{stage, tier}` | N02-farm-objects | N05-farm-dress | the farm stage (1..5) changed with the home tier |
| `tutorial_hint_shown` | `{id}` | N04-farm-first-morning | - | a whisper hint of the first days was shown (the loop leg l10 counts it) |
| `home_exterior_ready` | `{tier}` | F6-home-world | N02-farm-objects, N05-farm-dress | after set_growth_stage: the house of this tier stands |
| `shop_open_changed` | `{shop, open, reason (hours\|day\|festival), opens_at, closes_at}` | T-towns-core | P24-audio-voice, I2-loop-harness | emitted by ShopHours (the room the player is in) and by the TownDirector (the buildings of the area the player is in); the door lock reads Hours directly |
| `closing_warning` | `{shop, minutes_left}` | T-towns-core | P24-audio-voice, I2-loop-harness | 30 game minutes before closing, once per shop and day |
| `area_populated` | `{area, citizens, visuals, dropped}` | T-director | I2-loop-harness | after an area enter: how many citizens were placed, how many looks, how many dropped by the look cap |
| `routine_changed` | `{hour}` | T-director | S-core | every full game hour while a town area is loaded; refreshes at:/away: markers |
| `open_post_office` | `{npc, building}` | T-towns-core | T-post-office | E at Pip's counter |
| `open_inn_menu` | `{npc, building}` | T-towns-core | - | E at the inn's bar: no consumer (the inn sells nothing: honest stub) |
| `social_points` | `{npc, delta, points, hearts, source}` | S-core | P24-audio-voice, I2-loop-harness | every friendship change |
| `chat_done` | `{npc, weekly_heart}` | S-core | - | a finished conversation was counted (the loop leg l03 binds it) |
| `gift_given` | `{npc, item, taste, points, birthday}` | S-gifts | P13-quests-lua-runtime, P24-audio-voice, I2-loop-harness | a gift was handed over |
| `birthday_today` | `{npc}` | S-core | S-ui, I2-loop-harness | today's birthday (TODAY only: a skipped day posts nothing) |
| `town_festival_started` | `{id}` | S-core | S-ui, I5-art-festival, N05-farm-dress, P24-audio-voice | festival state became active (never the house party's festival_held) |
| `town_festival_ended` | `{id}` | S-core | S-ui, I5-art-festival, N05-farm-dress, P24-audio-voice | festival state ended |
| `festival_attended` | `{id}` | S-events | P13-quests-lua-runtime | attendance points paid (once per festival and year) |
| `heart_event_started` | `{id, npc, hearts}` | S-events | - | a heart event scene began (quests and tests may bind it) |
| `heart_event_finished` | `{id, npc, hearts}` | S-events | P13-quests-lua-runtime | a heart event scene ended (also when skipped); the quest objective heart_event_finished binds it |
| `relationship_changed` | `{npc, stage, partner}` | S-core | P24-audio-voice | a friendship stage changed (S-core posts ONE toast itself; the event drives sfx/stage_up); partner true for the marriage-style ladder |
| `dialogue_action` | `{npc, action, data}` | P14-npc-dialogue | S-talk | an action Npc2D does not know (give_gift, social_topic, start_event, open_people ...): S-talk routes it (give_gift to S-gifts, start_event to S-events, open_people to S-ui); a new choice never needs an Npc2D edit |

Used, not defined here:

| Name | Payload | Note |
|---|---|---|
| `open_home_chest` | `{}` | feature addendum (F7 consumes); N02's tool shed is an additional emitter, so the Hjemkiste must open from ANY area |
| `post_read` | `{quest_id}` | design2 V6; N04's mail objective needs it once per day from day 2, also for an empty letter |
| `festival_held` | `{}` | the tier-8 house party (HomeManager); town festivals use town_festival_* and never this name |
| `friend_changed` | `typed signal (npc_id, hearts:int)` | stays, arity unchanged; emitted only when WHOLE hearts change, only by SocialManager |
| `open_home_builder` | `{tier}` | feature addendum (F7's Husbyggeri consumes); T-towns-core's ShopCounter kind `desk` (the builder yard) is an ADDITIONAL emitter: the second door of the home ladder, so it never depends on a conversation |
| `open_appraisal` | `{npc} (+ building)` | design2 (F4's LootService hosts DL7's screen); T-towns-core's ShopCounter kind `appraisal` (Uglehulen's counter) is an ADDITIONAL emitter, refused while the building is closed |

Reserved by others and never reused: `midnight_passed`, `blueprint_learned`, `animal_care_item_used`, `furniture_placed`, `hygge_level`, `festival_held`, `home_upgraded`, `garment_equipped`, `open_home_builder`, and design2's `landmark_entered ladder_climbed lift_ride post_read board_read bath_request bath_taken swap_seeds_request seeds_swapped cache_found open_appraisal` and the dungeon names.

### 8.3 Input

ONE new action: `people` = **P** (pause-menu row 'Folk' (no spare pad button)), opens the People book (modal `people`), owner P01-project-config (RT3): `ACTIONS.size()` 35 -> 36. No gift key (gifts go through the talk menu), no calendar key (the calendar is a tab of the journal J).

### 8.4 Save (DT17)

Section `social` (order 60, version 1) of `SocialManager`, owner S-core: `v, seed, last, npcs{id:{p, wk, gt, gd, gwk, gw, bd, bk, ls[<=3], kn{<=40}, rv, rs}}, seen{}, fest{}, partner{}, orphans`. farm and towns add NO section: presence is a function of the clock; farm_stage, tut_*, zone_<id>, bin_<item> ride in the existing `world` section (a few hundred bytes); the whole save projects to about 31 KB against a 60 KB budget

Rules for every section: name `^[a-z][a-z0-9_]{0,31}$`; own `"v"`; `from_dict` never emits and never `push_error`s (a `push_error` rejects the WHOLE load: measured; content drift = `push_warning` + an orphans bucket); `reset()` seeds from the legacy flags and never zeros the mirror blindly; no unbounded list; NPC positions, routine slots and the current festival are NOT saved (pure functions of date and data). Measured: `save_game` 8.1-12.9 ms p50 (2-34 KB), `load_game` 2-10 ms.

### 8.5 World flags and area flags

| World flag | Meaning |
|---|---|
| `farm_stage` | int 1..5, derived from home_tier, written by FarmStage (N02) |
| `home_tier` | int 1..10, F2 keeps it correct on new game, load and upgrade |
| `tut_hint_<id>` | once-per-save marker of a shown hint (N04) |
| `tut_done` | set when the quest forste_dage ends (N04) |
| `friend_<npc>` | WHOLE hearts: a derived mirror, written only by SocialManager |
| `friend_last_<npc>` | total_day of the last weekly heart: a derived mirror |
| `birthday_today` | npc id or empty (S-core) |
| `festival_now` | id of the festival ACTIVE now, empty otherwise (S-core); the dress marker `event=festival_now` of the farm reads it |
| `partner` | npc id of the engaged / married partner (LATER, S-marriage) |
| `wish_<festival>_<year>` | flavour flag of the wish activity |
| `hero_id` | TEST OVERRIDE ONLY: the hero is derived from GameManager.character_skin by CharacterCatalog.hero_of_skin |

| Area flag (farm) | Meaning |
|---|---|
| `zone_<id> (zone_east)` | an unlocked field zone (N02) |
| `bin_<item>` | integer: items in the shipping bin (N02) |

### 8.6 Lua: the new kind, the config keys and the registries (DT19)

* **`registry`**: NEW (P10 fix-round): kind = "registry", registry = "<name>", a top-level table <name> = { <id> = {...} }; LuaLint.KINDS += "registry"; finding registry_header; LuaRuntime.get_registry(name) -> Dictionary and get_registry_entry(name, id) -> Dictionary (both {} when unknown); a duplicate id across files is a claim error
* **`config / dialogue / items / quest / recipes / shops`**: unchanged

| Config key | File | Owner |
|---|---|---|
| `farm_site` | `lua/config/farm_site.lua` | N02-farm-objects |
| `farm_tutorial` | `lua/farm/farm_tutorial.lua` | N04-farm-first-morning |
| `greenhouse` | `lua/config/greenhouse.lua` | N07-farm-greenhouse |
| `crops_extra` | `lua/config/crops_extra.lua` | N07-farm-greenhouse |
| `towns` | `lua/towns.lua` | T-towns-core |
| `social` | `lua/social/social.lua` | S-core |
| `citizens` | `lua/social/citizens.lua` | S-data |
| `gift_tastes` | `lua/social/gift_tastes.lua` | S-data |
| `relationships` | `lua/social/relationships.lua` | S-marriage |
| `audio_map` | `lua/config/audio.lua` | P24-audio-voice |
| `voice_presets` | `lua/config/voice_presets.lua` | P24-audio-voice |
| `voiced_index` | `lua/dialogue/_voiced_social.lua` | P24-audio-voice |
| `festival_decor` | `lua/config/festival_decor.lua` | I5-art-festival |

| Registry | Files | Owners | Shape |
|---|---|---|---|
| `routines` | `lua/routines/core/**`, `lua/routines/ext/**` | T-routes, T-ext-content | one file per citizen, KEY = npc id |
| `buildings` | `lua/buildings/traetoppen.lua`, `lua/buildings/hyggebyen.lua`, `lua/buildings/ext.lua` | T-towns-core, T-ext-content | KEY = building id; hours live here |
| `festivals` | `lua/festivals/fixed/**`, `lua/festivals/wedding/**` | S-fest-content, S-marriage | one file per festival, KEY = festival id |
| `events` | `lua/events/hearts/**`, `lua/events/festivals/**`, `lua/events/relationships/**` | S-heart-content, S-fest-content, S-marriage | one file may hold several scenes, KEY = event id |

The 22 existing config keys (`adventure ambient characters combat crops economy farm furniture_sets home loot npcs perk_caps player props props_features race_perks rarity_tiers starter_kit time ui wardrobe wardrobe_sets`), the feature keys and design2's (`dungeon dungeon_run enemies bosses dungeon_loot forest_look traetoppen species_perks`) are free of collisions with these 13 (the Lua lint reports `duplicate_key` otherwise). New shop and recipe files: `lua/shops/festival_markets.lua` (S-fest-content), `lua/shops/greenhouse_seeds.lua` (N07, optional), `lua/recipes/social.lua` and `lua/items/social.lua` (S-marriage; items `heart_bouquet`, `promise_acorn`), `lua/items/winter_crops.lua` (N07, optional); the quest `lua/quests/forste_dage.lua` (N04). **API** (P10, RT4): `api.get_hearts(npc) -> int`, `api.add_hearts(npc, n)`, `api.is_birthday(npc) -> bool`, `api.festival() -> id of today's ACTIVE festival or ''`; dialogue modules keep reading hearts as `local h = context.hearts or friend_x or 0`.

### 8.7 Markers, spawns, posts, gates, files of the world

| Marker type | Parameters | Handler script | Owner |
|---|---|---|---|
| `shipping_bin` | prop= | `scripts/farm/steading/objects/shipping_bin_2d.gd` | N02-farm-objects |
| `tool_shed` | prop= | `scripts/farm/steading/objects/tool_shed_2d.gd` | N02-farm-objects |
| `field_expansion` | id= cells=x0..x1,y0..y1[;..] price= | `scripts/farm/steading/objects/field_expansion_2d.gd` | N02-farm-objects |
| `underdeck` | prop= | `scripts/farm/steading/objects/underdeck_2d.gd` | N02-farm-objects |
| `ambient_fx` | kind=auto | `scripts/farm/steading/objects/ambient_fx_2d.gd` | N02-farm-objects |
| `dress` | prop= + exactly one of tier=N \| season=<id> \| event=<flag> | `scripts/farm/steading/dress/dress_2d.gd` | N05-farm-dress |
| `greenhouse_slot` | (data marker; handler only if N07 is activated) | `scripts/farm/steading/greenhouse/greenhouse_2d.gd` | N07-farm-greenhouse |
| `bath` | (room JSON marker) BathTub2D: once a day, 30 game minutes, stamina and half a heart restored | `scripts/traetoppen/life/bath_tub_2d.gd` | V6-city-life |
| `board` | (room JSON marker) NoticeBoard2D: up to 5 everyday quests | `scripts/traetoppen/life/notice_board_2d.gd` | V6-city-life |
| `town` | [curfew=false] [area=<id>] (ONE per map) | `scripts/towns/town_marker.gd` | T-director |
| `door` | building=<id> [interior=<area>] (creates the spawn from_int_<building> one cell in front) | `scripts/towns/town_marker.gd` | T-director |
| `post` | name=<id> [act=] [cap=] [facing=] \| set=fest spot=<id> (the 24-post festival set) | `scripts/towns/town_marker.gd` | T-director |

Rows of `lua/config/marker_handlers.lua` (F4's file, RT19) register every type above except `greenhouse_slot` (a data marker until N07); an absent script is a silent skip by the framework's own rule. Existing types with new parameters:

| Marker | Parameters | Owner | Note |
|---|---|---|---|
| `mailbox` | prop=<art id> (default mailbox_red) | V6-city-life | the farm's mailbox places its own prop |
| `building_slot` | type=coop\|barn\|house, the marker on the FRONT cell, footprints 3x2 / 4x3 / 3x2 | P20-animals-buildings | N01 authors, P20 builds |
| `animal_yard` | r=<cells> | P20-animals-buildings | wander radius 3 on the farm |
| `warp` | every warp is also a GATE (anchor gate_<to area>) of the route table | T-director | no extra marker for a bridge |
| `mailbox in a room JSON` | built by V6's PostBox2D INSIDE the post office through IsoArea.resolve_handler: static func create_marker(params, pos, cell, area) -> Node (the `bath` and `board` rows are new marker types above) | V6-city-life | V4's city JSON carries none of the three |

| Area | Spawns |
|---|---|
| farm | default, from_home (door + (0,2); wake spawn of a pass-out, a defeat and the night watch), from_traetoppen (three planks before the bridge warp) |
| traetoppen | default, from_farm (east rim of tree G), from_hyggebyen, from_skovlift (V4 / design2) |
| hyggebyen (zone id city) | default, from_traetoppen, one from_int_<building> per door marker (14) |
| int_<building> (24 rooms) | default (arrival), exit = from_int_<building> of the outer area, alias from_street |

Farm posts: `pip_mailbox, hoppe_fence, bench_a, porch, field_edge`. Festival post set: fest_<spot>_host, _judge, _stall_1..4, _table_1..2, _gather_1..16 = 24 posts; spots torvet, badehus, raadhus (city sidecar) and hyggetorv (hyggebyen.map, ONE `post set=fest` marker). Hyggebyen: 24 named posts + `post set=fest spot=hyggetorv` (P11, RT12); the city: 36 posts + 3 festival spots + 3 gates + the 2 stall counters in the sidecar `data/towns/traetoppen.json` (T-routes). The `ShopCounter` kinds of a room JSON (`shop`, `post_counter`, `bar`, `appraisal`, `desk`, `talk`) are markers of the room grammar, not rows of `marker_handlers.lua`. Gates: every `warp` marker is a gate (anchor `gate_<to area>`). Marker chars: any single character. Interior stub maps: `data/maps/int_<building>.map` x 24 (14 by T-interiors-core, 10 by T-ext-content).

### 8.8 GDScript surface (static classes late-bound with `Svc.static_call`, nodes named)

| Track | Classes and signatures |
|---|---|
| farm | FarmReserve.blocked(area, cell) -> String; FarmStage.of_tier(tier) -> {id, index, rows}; TutorialRunner.run(world) -> bool (late bound by IntroSequence); nodes Shipping/Tool/FieldExpansion/Underdeck/AmbientFx 2D |
| towns | Hours (state, is_open, shop_open, closed_info, minutes_to_close, hours_on, format_hour, now_ctx: clock-only); Routines (where_is, present_in, plan_name, timeline, resolve_place, festival_block, make_ctx, now_ctx, is_unavailable, hearts_of); RouteTable; NavGrid (bake_area, bake_room, from_cells); TownMarks (collect, resolve_cells); LevelNav; FestSet; TownsValidate; NpcDirector (is_absent, is_away, is_present, where_is, population, resync(npc_id := ""), controls(id, area), node_of(id), post_ground(area_id, name)); nodes TownDirector, TownMarker, Door2D (extends Warp2D), ShopCounter (kinds shop, post_counter, bar, appraisal, desk, talk), ShopHours, InteriorRoom, PieceCatalog; P12's helper ShopHoursGate (open_override, closed_info) |
| social | SocialManager (autoload); CalendarUtil; SocialRng; SocialData; GiftRules; GiftFlow; SocialTalk + DialogueBridge.decorate; SocialHearts; SocialValidator; EventRunner; FestivalStage |
| integration | AudioDirector (child of AudioManager), Surface, Footsteps, FestivalDecor.attach(director), LoopCaps / LoopWalker / LoopClock / LoopDigest / TownProbe (tests/lib/town_loop) |

`SocialManager` (autoload; every call returns a safe default when the autoload is absent; `Svc.node("SocialManager")` is how every other package reaches it):

```
points(npc) -> int   hearts(npc) -> int   half_hearts(npc) -> int   stage(npc) -> StringName   can_befriend(npc) -> bool   friend_ids() -> Array[String]
add_points(npc, delta, source: StringName, opts := {}) -> {ok, reason?, points, hearts, gained}   add_hearts(npc, n, source := &"quest")   debug_set_hearts(npc, n)   # raises only
on_conversation_finished(npc, lines_shown: int, completed: bool) -> {weekly_heart: bool}   chat_available(npc)   talked_today(npc)
give_gift(npc, item) -> Dictionary   gift_options(npc) -> Array   gift_limits(npc) -> {per_day, per_week, left_today, left_week}   taste_of(npc, item)   is_giftable(item)
birthdays_on(td) birthdays_today() is_birthday(npc) birthday_state(npc) last_birthday(npc) next_birthday(npc) birthday_known(npc) calendar_entries(season, year)
festival_on(td) festival_today() festival_active() shop_closed_by_festival(shop_id) -> bool   bed_hold_hour() -> int   override_for(npc, td, hour) -> {area, post, state} | {}
eval_when(spec) -> bool   when_spec_errors(spec) -> Array[String]   const WHEN_REFRESH_EVENTS
dialogue_context(npc) -> {hearts, stage, weekday, weather, daypart, birthday, festival, chat_open, talked_today, gifts_left, partner}   people_rows() -> Array[Dictionary]
events_ready(npc) event_seen(id) start_event(id)   partner() partner_in_home() pick_visitor(week, i) start_house_party()   # the last four: S-marriage
set_seed(v) roll(parts) reset() flush() to_dict() from_dict(d)
```

`NpcDirector` (static, `scripts/towns/npc_director.gd`): `is_absent(id, ctx?)` (hero twin or a closed gate; NOT asleep, NOT away), `is_away(id)` (an `away:` block), `is_present(id)` (a live node in the player's area), `where_is(id, ctx?)`, `population(area, ctx?)`, `resync(npc_id := "")`, `controls(id, area) -> bool` (the citizen has a routine AND the area carries a `town` marker whose handler exists: the P14 `npc` marker handler's question, DT47), `post_ground(area_id, name) -> Vector2` (the ground-px centre of a named post, Vector2.INF when unknown: the festival runtime's question, DT51). `Hours`: `state(building, ctx)`, `shop_open(shop_id, ctx)`, `closed_info`, `minutes_to_close`. `Routines.where_is(npc, ctx)` with `ctx = {weekday, hour, weather, season, total_day, hearts, flags, done, hero, festival, override_fn}`. `FarmReserve.blocked(area, cell) -> String`, `FarmStage.of_tier(tier)`, `TutorialRunner.run(world) -> bool`. `Npc2D` additions: the driven interface (RT24), the event API `event_begin / event_end / event_walk_to / event_face / event_clip / event_emote / set_bubble`, guest mode, a temporary instance created by code (`visual`, `post`, `facing`). `Player2D`: `event_begin / event_end / event_walk_to / camera_focus / camera_release`; `FarmGrid.water_unwatered(max_n)`.

### 8.9 CSV families and owners (merged `key_owners_additions.json`, sanctioned edit E2; checked by `check_ownership.py` F)

| CSV | Owner | Wave | Prefix | Exact |
|---|---|---|---|---|
| `farm_signs.csv` | N01-farm-map | 4 | - | `SIGN_ORCHARD`, `SIGN_FARM_BRIDGE`, `SIGN_FARM_FOREST` |
| `farm_site.csv` | N02-farm-objects | 5 | `FARMSITE_` | - |
| `farm_tutorial.csv` | N04-farm-first-morning | 5b | `TUT_`, `DLG_FARMINTRO_`, `QUEST_FORSTE_DAGE_`, `OBJ_FORSTE_DAGE_` | - |
| `farm_greenhouse.csv` | N07-farm-greenhouse | 7 | `GHOUSE_` | - |
| `towns.csv` | T-towns-core | 4 | `BLD_`, `HOURS_`, `ACT_`, `COUNTER_` | - |
| `keepers.csv` | T-greetings | 6 | `KEEP_` | - |
| `post.csv` | T-post-office | 6 | `POST_`, `WHERE_` | - |
| `social_sys.csv` | S-core | 4 | `SOC_SYS_`, `REL_STAGE_` | - |
| `social_talk.csv` | S-data | 5 | `SOC_` | - |
| `social_arch.csv` | S-data | 5 | `SOC_ARCH_` | - |
| `gifts.csv` | S-data | 5 | `GIFT_` | - |
| `birthdays.csv` | S-data | 5 | `BDAY_` | - |
| `rel_ui.csv` | S-ui | 5b | `REL_` | - |
| `social_events.csv` | S-events | 5b | `SOC_EV_` | - |
| `heart_events.csv` | S-heart-content | 6 | `HEART_` | - |
| `festivals.csv` | S-fest-content | 6 | `FEST_` | - |
| `partner.csv` | S-marriage | 6 | `PARTNER_` | - |

Key shapes: `BLD_<BUILDING_ID>`; `HOURS_*` (templates with %s); `ACT_<ACT>`; `KEEP_<SHOP_ID>_GREET_H<0..3>_<n>`, `KEEP_<SHOP_ID>_SAMPLE_<n>`, `KEEP_ANY_THANKS | CANNOT_PAY | SOLD_OUT | FAREWELL_<n>`; `POST_<TITLE|EMPTY|GROUP_*>`, `WHERE_POST_<POST_NAME>`; `SOC_<NPC>_<SLOT>[_<TAG>]_<n>[_V]`, `GIFT_<NPC>_<CLASS>_<n>`, `BDAY_<NPC>_<GREET|THANKS>_<n>`, `HEART_<NPC>_<HEARTS>_<nn>`, `FEST_<ID>_<NAME|DESC|OPEN_n|END_n|<ACTIVITY>>`, `PARTNER_<NPC>_<SLOT>_<n>`; `FARMSITE_<AREA>_<WHAT>`, `TUT_HINT_<ID>`, `TUT_STEP_<ID>`, `DLG_FARMINTRO_PIP_<n>`, `DLG_FARMINTRO_PIP_BYE_<n>`; the whisper `FARM_CELL_RESERVED` lives in P06's `farm.csv`. No `SIGN_TOWN_` family and no `MAIL_` family exists (the door sign label is `BLD_<ID>`; letters are V6's PostBox2D). A CSV with an extra column would make it a locale (`localization_manager.gd:378-383`): selection tags live in key suffixes, never in a column.

### 8.10 UI screens and registry rows (DT21)

| Id | Owner | Kind | Registry row file | Baseline PNG |
|---|---|---|---|---|
| `people` | S-ui | modal (pauses), key P, pause row 'Folk', dialogue action open_people | `tests/lib/ui_screens.d/social.json` | `docs/qa/ui_baseline/people.png` |
| `gift` | S-ui | modal (pauses), GameUI id gift_ui, opens AFTER dialogue_ended | `tests/lib/ui_screens.d/social.json` | `docs/qa/ui_baseline/gift.png` |
| `calendar` | S-ui | third tab 'Kalender' of the journal (J); P14's journal instances scenes/ui/social/calendar_tab.tscn when it exists | `tests/lib/ui_screens.d/social.json` | `docs/qa/ui_baseline/calendar.png` |
| `social_hud` | S-ui | HUD surface, focus none (festival ribbon, birthday chips) | `tests/lib/ui_screens.d/social.json` | `docs/qa/ui_baseline/social_hud.png` |
| `event_overlay` | S-events | NON-pausing modal `event`, letterbox, Esc -> UiConfirm (depth 2) | `tests/lib/ui_screens.d/social_events.json` | `docs/qa/ui_baseline/event_overlay.png` |
| `post` | T-post-office | modal (pauses): 'Hvor er ...?' | `tests/lib/ui_screens.d/towns.json` | `docs/qa/ui_baseline/post.png` |

`GameUI.SCREEN_ORDER` gains `social_hud` (behind `forest_hud`), `event_overlay` (between them and `dialogue_ui`), `people`, `gift_ui`, `post` (next to `quest_journal`, below the pause menu) (P07, RT7: 21 ids, order[0] == hud, order[1] == forest_hud, order[-3] == pause_menu hold; the two built pins follow the list); GameUI instances a screen only if its scene exists. `UiAudit.screens()` merges `tests/lib/ui_screens.d/*.json` (P09, RT8). The pause menu gains the transfer row "Folk" (P16, RT14). The shop panel (S13) is amended, not added (P18, RT15). Farm: ZERO screens (the field expansion uses `UiConfirm` S08; hints are whispers).

### 8.11 Sanctioned shared edits

| Id | File | By | Rule |
|---|---|---|---|
| **E1** | `project.godot` [autoload] | tools/features/add_autoload.py (F1) run by F2, F3, F4, F5, F9 and now S-core as their last task | idempotent, flock, append-only, one line per feature autoload, only when the script exists; the addendum adds exactly ONE name (SocialManager), the sixth; the closed lists of the tool, check_project.gd and Fresh.FEATURE_NODES are widened by the P01 / F1 fix-round (RT2, RT3) BEFORE it runs |
| **E2** | `tools/loc/key_owners.json` files | the lead at the START of each wave (patch of P03, RT9) | merge the entries of design3/FINAL/key_owners_additions.json whose `wave` is the wave about to start; nobody else edits the file; check_ownership.py (F) and i_check_keys.py prove no prefix is claimed twice and no existing key is stolen |
| **E3** | `data/towns/routes.json` (derived data, 34 KB, 27 areas, the header carries the hash of its inputs) | tools/towns/bake_routes.sh run by the lead at the wave-5b and wave-6 gates | regenerate, never hand-edit; towns_routes.table_fresh recomputes the hash and FAILS when a map, a sidecar, a room spec or a post moved, so a stale table can never ship |

### 8.12 Ids other packages may rely on

Zones `farm` (title `ZONE_FARM` = "Min Trækronsgård", V1), `traetoppen`, `city` (= Hyggebyen); the farm's spawns `default`, `from_home`, `from_traetoppen`, posts `pip_mailbox hoppe_fence bench_a porch field_edge`, area flag `zone_east`, the quest `forste_dage`, the dialogues `farm_intro_pip` and `farm_intro_pip_bye`; the 30 citizen ids of section 4.7; the building ids of section 4.1; shop ids `seed_shop bakery smithy animal_store magic_store furniture_shop tailor_shop builder_yard flea_market timber_yard natteblik_maps` (Uglehulen is a service: it has none); festival ids of section 5.3; hero ids `rasmus kiki kloevermynte birk bertil bodil`; asset roots `assets/iso_props/{farm,shops/core,shops/special,festival}/**`, `data/interiors/{core,ext,dress}/**`, `data/towns/routes.json`, `data/towns/traetoppen.json`.

---------------------------------------------------------------------------------------------------------------------------------------------

## 9. Packages, waves, load and slip rules

### 9.1 The 32 new packages (full text with tasks, acceptance, budgets and honest notes in `packages.json`)

| Id | Track | Class | Wave | Size | Depends on (strictly earlier waves) | softDependsOn | Owns | Tasks |
|---|---|---|---|---|---|---|---|---|
| **N01-farm-map** | farm | CORE | 4 | M | P03-loc-core, P04-area-framework, P05-characters-pack, P09-test-harness, P10-data-contracts, F1-feature-data | - | `data/maps/farm.map`, `localization/farm_signs.csv`, `localization/farm_signs.csv.import` (+2) | 13 |
| **S-core** | social | CORE | 4 | L | P02-bus-gamemanager-time, P03-loc-core, P09-test-harness, P10-data-contracts, P12-economy-shop-crafting, P15-save-system, F1-feature-data | - | `scripts/social/social_manager.gd`, `scripts/social/calendar_util.gd`, `scripts/social/social_rng.gd` (+7) | 18 |
| **T-towns-core** | towns | CORE | 4 | L | P03-loc-core, P04-area-framework, P09-test-harness, P10-data-contracts, P12-economy-shop-crafting, A1-art-home | - | `lua/towns.lua`, `lua/buildings/traetoppen.lua`, `lua/buildings/hyggebyen.lua` (+16) | 20 |
| **I1-copy-system** | integration | CORE | 5 | M | P03-loc-core, P09-test-harness, P10-data-contracts | - | `docs/copy/**`, `tools/copy/**`, `tests/sections/copy_rules.gd` | 7 |
| **I2-loop-harness** | integration | CORE | 5 | L | P04-area-framework, P06-player-farm-core, P09-test-harness, P11-maps-iso, P13-quests-lua-runtime, P15-save-system, P17-ui-hud, P18-ui-shop-inventory, P28-ui-nav-foundation, V1-cast-data, V3-levels, T-towns-core, S-core, N01-farm-map, D0-dungeon-world-hooks | - | `tests/sections/town_loop.gd`, `tests/sections/town_budgets.gd`, `tests/lib/town_loop/**` (+3) | 16 |
| **N02-farm-objects** | farm | CORE | 5 | M | P04-area-framework, P06-player-farm-core, P10-data-contracts, P12-economy-shop-crafting, F2-home-core, F4-loot-shops, N01-farm-map | - | `scripts/farm/steading/objects/**`, `lua/config/farm_site.lua`, `localization/farm_site.csv` (+2) | 9 |
| **N03-farm-art** | farm | CORE | 5 | L | P08-art-tools, P09-test-harness, P22-art-environment, A1-art-home, N01-farm-map | - | `assets/iso_props/farm/**`, `assets/backdrops/farm_*`, `assets/iso_tiles/field_grass*` (+3) | 7 |
| **S-data** | social | CORE | 5 | L | S-core, P03-loc-core, P10-data-contracts, P12-economy-shop-crafting, F1-feature-data, V1-cast-data | - | `lua/social/citizens.lua`, `lua/social/gift_tastes.lua`, `localization/social_talk.csv` (+9) | 7 |
| **S-gifts** | social | CORE | 5 | M | S-core, P12-economy-shop-crafting, F1-feature-data | - | `scripts/social/gifts/**`, `tests/sections/social_gifts.gd` | 6 |
| **S-talk** | social | CORE | 5 | M | S-core, P03-loc-core, P10-data-contracts | - | `scripts/social/talk/**`, `tests/sections/social_talk.gd` | 7 |
| **T-interiors-core** | towns | CORE | 5 | M | T-towns-core, P11-maps-iso, P12-economy-shop-crafting, P18-ui-shop-inventory, V1-cast-data | - | `data/interiors/core/**`, `data/maps/int_froebutikken.map`, `data/maps/int_bageriet.map` (+13) | 5 |
| **T-routes** | towns | CORE | 5 | L | T-towns-core, P04-area-framework, P09-test-harness, P10-data-contracts, P11-maps-iso, V1-cast-data, N01-farm-map, V3-levels | - | `scripts/towns/nav_grid.gd`, `scripts/towns/route_table.gd`, `scripts/towns/routines.gd` (+14) | 13 |
| **I3-art-shops** | integration | CORE | 5b | M | P08-art-tools, P09-test-harness, A1-art-home, P22-art-environment, V2-cast-art, T-towns-core, T-interiors-core | - | `assets/iso_props/shops/core/**`, `tools/art/environment/shops/**`, `tests/sections/art_shops.gd` | 8 |
| **N04-farm-first-morning** | farm | CORE | 5b | M | P06-player-farm-core, P13-quests-lua-runtime, P14-npc-dialogue, P17-ui-hud, V1-cast-data, V6-city-life, N01-farm-map, N02-farm-objects | - | `lua/farm/**`, `lua/quests/forste_dage.lua`, `scripts/farm/steading/tutorial/**` (+4) | 8 |
| **S-ui** | social | CORE | 5b | L | S-core, S-gifts, S-talk, S-data, P07-ui-foundation, P28-ui-nav-foundation, P18-ui-shop-inventory, P12-economy-shop-crafting, P14-npc-dialogue, P17-ui-hud | - | `scripts/ui/social/**`, `scenes/ui/people.tscn`, `scenes/ui/gift_ui.tscn` (+11) | 8 |
| **T-director** | towns | CORE | 5b | L | T-towns-core, T-routes, T-interiors-core, F4-loot-shops, P04-area-framework, P06-player-farm-core, P11-maps-iso, P14-npc-dialogue, V1-cast-data, V3-levels, V6-city-life, N01-farm-map, DR7-dungeon-services | - | `scripts/towns/town_director.gd`, `scripts/towns/town_marker.gd`, `scripts/towns/citizen_stub.gd` (+3) | 10 |
| **S-events** | social | EXTENDED | 5b | L | S-core, S-talk, S-gifts, P06-player-farm-core, P11-maps-iso, P14-npc-dialogue, P28-ui-nav-foundation, P07-ui-foundation | - | `scripts/social/events/**`, `scripts/ui/social_events/**`, `scenes/ui/event_overlay.tscn` (+6) | 7 |
| **I4-art-shops-b** | integration | EXTENDED | 6 | XL | I3-art-shops, P08-art-tools, P22-art-environment, T-towns-core, T-interiors-core | - | `assets/iso_props/shops/special/**`, `tools/art/environment/shops_special/**`, `data/interiors/dress/**` (+1) | 6 |
| **I5-art-festival** | integration | EXTENDED | 6 | M | I3-art-shops, P08-art-tools, V5-art-city, T-director, S-core | - | `assets/iso_props/festival/**`, `tools/art/environment/festival/**`, `scripts/festival/**` (+2) | 6 |
| **N05-farm-dress** | farm | EXTENDED | 6 | M | P04-area-framework, P10-data-contracts, F2-home-core, F4-loot-shops, N01-farm-map, N02-farm-objects, N03-farm-art | - | `scripts/farm/steading/dress/**`, `tests/sections/farm_dress.gd` | 4 |
| **N06-farm-art-seasons** | farm | EXTENDED | 6 | S | P08-art-tools, P09-test-harness, P22-art-environment, N03-farm-art | - | `assets/iso_props/farm_dress/**`, `tools/art/environment/farm_dress/**`, `tests/sections/art_farm_dress.gd` | 4 |
| **S-fest-content** | social | EXTENDED | 6 | M | S-events, S-data, S-talk, P11-maps-iso, V4-city-map, P12-economy-shop-crafting | - | `lua/festivals/fixed/**`, `lua/events/festivals/**`, `lua/shops/festival_markets.lua` (+3) | 5 |
| **S-heart-content** | social | EXTENDED | 6 | L | S-events, S-data, S-talk, P14-npc-dialogue, P11-maps-iso, V4-city-map | - | `lua/events/hearts/**`, `localization/heart_events.csv`, `localization/heart_events.csv.import` (+1) | 3 |
| **T-ext-content** | towns | EXTENDED | 6 | M | T-director, T-interiors-core, T-routes, V4-city-map, P18-ui-shop-inventory | - | `data/interiors/ext/**`, `data/maps/int_torvekroen.map`, `data/maps/int_fekongens_hus.map` (+11) | 6 |
| **T-greetings** | towns | EXTENDED | 6 | S | T-towns-core, T-interiors-core, S-talk, P03-loc-core, P12-economy-shop-crafting, P18-ui-shop-inventory | - | `localization/keepers.csv`, `localization/keepers.csv.import`, `tests/sections/towns_greetings.gd` | 2 |
| **T-post-office** | towns | EXTENDED | 6 | M | T-director, T-interiors-core, P07-ui-foundation, P18-ui-shop-inventory, P28-ui-nav-foundation, P09-test-harness | - | `scripts/ui/towns/post_ui.gd`, `scenes/ui/post.tscn`, `localization/post.csv` (+4) | 3 |
| **S-marriage** | social | LATER | 6 | M | S-events, S-gifts, S-data, S-talk, F2-home-core, F6-home-world, P14-npc-dialogue, P12-economy-shop-crafting, P13-quests-lua-runtime, T-routes | - | `scripts/social/marriage/**`, `lua/social/relationships.lua`, `lua/items/social.lua` (+6) | 6 |
| **N07-farm-greenhouse** | farm | EXTENDED (optional) | 7 | M | P06-player-farm-core, P10-data-contracts, P12-economy-shop-crafting, P20-animals-buildings, N01-farm-map, N02-farm-objects, N03-farm-art | - | `scripts/farm/steading/greenhouse/**`, `lua/config/crops_extra.lua`, `lua/config/greenhouse.lua` (+6) | 4 |
| **I6-town-qa** | integration | QA | 7 | M | I2-loop-harness, I3-art-shops, P14-npc-dialogue, P17-ui-hud, P18-ui-shop-inventory, P24-audio-voice, P25-docs-refresh, P26-loc-final, F6-home-world, V4-city-map, V6-city-life, T-director, T-interiors-core, S-ui, S-gifts, S-talk, N02-farm-objects, N04-farm-first-morning | I4-art-shops-b, I5-art-festival, T-greetings, T-post-office, S-events, S-heart-content, S-fest-content | `tests/sections/zz_town.gd`, `docs/qa/town/**` | 5 |
| **N08-farm-qa** | farm | QA | 7 | S | P09-test-harness, P17-ui-hud, N01-farm-map, N02-farm-objects, N03-farm-art, N04-farm-first-morning | N05-farm-dress, N06-farm-art-seasons | `tests/sections/zz_farm.gd`, `tests/checkpoints/farm/**`, `docs/qa/farm/**` | 4 |
| **S-qa** | social | QA | 7 | S | S-core, S-data, S-talk, S-gifts, S-ui, P24-audio-voice, P25-docs-refresh, P26-loc-final, I2-loop-harness | S-events, S-heart-content, S-fest-content, S-marriage | `tests/sections/zz_social.gd`, `tests/checkpoints/social/**`, `docs/qa/social/**` | 4 |
| **T-qa** | towns | QA | 7 | M | T-towns-core, T-routes, T-interiors-core, T-director, I2-loop-harness, P24-audio-voice, P25-docs-refresh, P26-loc-final | T-ext-content, T-greetings, T-post-office | `tests/sections/zz_towns.gd`, `tests/checkpoints/towns/**`, `docs/towns/**` (+1) | 4 |

### 9.2 Wave plan and load (S=1, M=2, L=3, XL=4 points; every package of the whole plan that is not built yet)

| Wave | Points | of which this addendum | New packages of this addendum | Everything else of the plan in the wave |
|---|---|---|---|---|
| 3b | **2** | 0 | - | P28(M) |
| 4 | **65** | 8 | N01-farm-map (M), S-core (L), T-towns-core (L) | A2(XL), D0(S), D1(L), DL1(M), DL2(L), DR0(S), DR1(M), DR7(S), F2(L), F3(L), F4(L), P06(L), P11(M), P13(L), P16(L), P17(M), P18(L), P22(L), P23(M), V1(M), V2(L), V3(L), V7(M) |
| 5 | **62** | 22 | I1-copy-system (M), I2-loop-harness (L), N02-farm-objects (M), N03-farm-art (L), S-data (L), S-gifts (M), S-talk (M), T-interiors-core (M), T-routes (L) | D2(L), DL3(M), DL4(L), DL5(L), DR3(L), DR5(L), F5(L), F6(XL), P14(L), P19(L), P20(L), V5(L), V6(M), V8(M) |
| 5b | **27** | 13 | I3-art-shops (M), N04-farm-first-morning (M), S-ui (L), T-director (L), S-events (L) | D3(M), DL7(M), DR4(M), F7(L), F8(M), V4(M), V9(S) |
| 6 | **28** | 21 | I4-art-shops-b (XL), I5-art-festival (M), N05-farm-dress (M), N06-farm-art-seasons (S), S-fest-content (M), S-heart-content (L), T-ext-content (M), T-greetings (S), T-post-office (M), S-marriage (M) | DL6(M), P24(M), P25(M), P26(S) |
| 7 | **15** | 8 | N07-farm-greenhouse (M), I6-town-qa (M), N08-farm-qa (S), S-qa (S), T-qa (M) | DQ(M), F10(M), P27(M), V10(S) |

Without this addendum the waves would carry 4 = 57, 5 = 40, 5b = 14, 6 = 7, 7 = 7 points; the addendum adds 8 / 22 / 13 / 21 / 8 (72 points in all, by the sizes of the packages: farm 15, towns 18, social 24, integration 15). Waves 4 and 5 are heavy. **What cannot slide out of wave 4:** S-core (P14's weekly heart and the autoload need it), T-towns-core (the hours hook of P12, the buildings registry, the room builder) and N01 (the default start area, the farm legs of the loop); a package that slips must not be one of the loop's dependencies (P06, P11, P15, P17, P18, V1, V3).
**CORE before EXTENDED.** No CORE or QA package has a HARD dependency on an EXTENDED or LATER one (checked by `check_ownership.py` D). S-events (EXTENDED) shares wave 5b with the CORE packages only because wave 6's festival and heart-event content needs it; it gates nothing.
**Critical path to G5b:** P28 (3b) -> P18 / P17 / P06 / P11 / P15 / S-core / T-towns-core / N01 (4) -> P14 + F6 + V3-V6 + T-routes + T-interiors-core + S-data / S-talk / S-gifts + N02 + N03 (5) -> T-director + S-ui + N04 + V4 + I3 (5b) -> G5b. The loop harness (5) is off the path but is what makes G5b checkable.
**The G5b closure (DT57; checker section I).** The hard-dependency closure of the 16 CORE packages plus V4-city-map is 49 packages, 34 of them unbuilt, and holds NO dungeon-track package except D0 (the pass-out wake and the warm-clips rule that leg L11 needs) and DR7 (the shop `natteblik_maps` of the stall) and no P19: V4 lost its two edges to D2 and P19 (RT29; its two chain checks are DQ's, RT37). **Sequencing rule:** packages outside the closure (wardrobe A2 / F5 / F8, the dungeon generator D1 / D2 / DR0-DR5, D3, DL1-DL6, P19, V8 / V9, P23, and the EXTENDED packages) start after G5b or run in a separate lane; DL7 (the appraisal screen behind Uglehulen's counter) is not required for G5b: the counter whispers until it lands.
**Stagger and deferral (DT36).** If a wave overruns, first stagger writers inside the wave (data and copy last, code first), then defer in this order: the I4 dressing sets (set by set), I5, N05 / N06, T-ext-content, S-heart-content, S-fest-content, S-marriage, T-post-office, T-greetings. CORE is never deferred; the gates list what they skip. Dropping an EXTENDED package never changes a CORE gate: its legs SKIP with the capability name (the CORE-only data set of the towns passes all 9 validators; S-events' absence leaves the heart and gift loop intact).
**N07 (the greenhouse) counts its 2 points only if Q1 is answered yes.** **Wave 5 slip rule for S-core:** it may slip to wave 5 (then RT24 loses its `addDependsOn S-core`, P14 calls the manager late bound and the flag path remains the fallback).
**Honest sizes.** P14 grows from L to XL and P24 from M to L; every NEW package is one agent's job (the largest are I4 XL, 69 art pieces, droppable set by set, and the L packages T-towns-core, T-routes, T-director, S-core, S-data, S-ui, S-events, N03, I2).

### 9.3 Ownership by area (every pattern has exactly ONE owner across all layers: section 15)

| Area | Owner (new packages) |
|---|---|
| `data/maps/farm.map`, `localization/farm_signs.csv`, `tests/sections/maps_farm.gd`, `tools/farm/**` | N01 |
| `scripts/farm/steading/objects/**`, `lua/config/farm_site.lua`, `localization/farm_site.csv` | N02 |
| `assets/iso_props/farm/**`, `assets/backdrops/farm_*`, `assets/iso_tiles/field_grass*`, `tools/art/environment/farm/**` | N03 |
| `lua/farm/**`, `lua/quests/forste_dage.lua`, `scripts/farm/steading/tutorial/**`, `tools/farm_tutorial/**`, `localization/farm_tutorial.csv` | N04 |
| `scripts/farm/steading/dress/**` / `assets/iso_props/farm_dress/**` / `scripts/farm/steading/greenhouse/**` | N05 / N06 / N07 |
| `lua/towns.lua`, `lua/buildings/{traetoppen,hyggebyen}.lua`, `scripts/towns/{hours,interior_room,piece_catalog,door_2d,shop_counter,shop_hours}.gd`, `data/interiors/{stand_ins,kit_footprints,schema}.json`, `localization/towns.csv`, `tools/towns/interiors/**` | T-towns-core |
| `scripts/towns/{nav_grid,route_table,routines,fest_set,npc_director,towns_validate,level_nav,town_marks}.gd`, `lua/routines/core/**`, `data/towns/{routes,traetoppen}.json`, `tools/towns/{bake_routes.*,validate_towns.gd,authoring/**}` | T-routes |
| `data/interiors/core/**`, 14 `data/maps/int_*.map` | T-interiors-core |
| `scripts/towns/{town_director,town_marker,citizen_stub,city_town}.gd` | T-director |
| `data/interiors/ext/**`, 10 `data/maps/int_*.map`, `lua/buildings/ext.lua`, `lua/routines/ext/**` / `localization/keepers.csv` / `scripts/ui/towns/post_ui.gd`, `scenes/ui/post.tscn`, `localization/post.csv` | T-ext-content / T-greetings / T-post-office |
| `scripts/social/{social_manager,calendar_util,social_rng,social_data}.gd`, `lua/social/social.lua`, `tests/lib/social/**` / `lua/social/{citizens,gift_tastes}.lua` + 4 CSVs / `scripts/social/talk/**` / `scripts/social/gifts/**` | S-core / S-data / S-talk / S-gifts |
| `scripts/ui/social/**`, `scenes/ui/{people,gift_ui,social_hud}.tscn`, `localization/rel_ui.csv` / `scripts/social/events/**`, `scenes/ui/event_overlay.tscn` | S-ui / S-events |
| `lua/events/hearts/**` / `lua/festivals/fixed/**`, `lua/events/festivals/**`, `lua/shops/festival_markets.lua` / `scripts/social/marriage/**`, `lua/social/relationships.lua`, `lua/{items,recipes}/social.lua`, `lua/festivals/wedding/**` | S-heart-content / S-fest-content / S-marriage |
| `docs/copy/**`, `tools/copy/**` / `tests/sections/town_loop.gd`, `tests/lib/town_loop/**`, `tools/town/**` / `assets/iso_props/shops/{core,special}/**`, `data/interiors/dress/**` / `assets/iso_props/festival/**`, `scripts/festival/**` | I1 / I2 / I3, I4 / I5 |
| `tests/sections/zz_{farm,towns,social,town}.gd`, `docs/qa/{farm,towns,social,town}/**` | N08 / T-qa / S-qa / I6 |

---------------------------------------------------------------------------------------------------------------------------------------------

## 10. Decision register (DT1-DT64)

Adopted by reference (their own registers stay valid where this one is silent): design_farm DN1-DN15, design_towns (hours, interiors, director, curfew), design_social DS1-DS36, design_integration (loop, copy, voice, audio, budgets). The DT rows below are the editor's: cross-track decisions, repairs and defaults.

**DT1 - One addendum, one package file, a clear precedence.** This addendum and design3/FINAL/packages.json are binding for the towns, the treetop farm, the citizens and the social sim. They override PLAN_2D.md / PLAN_2D_FEATURES.md where they differ, they never override design2's dungeon addendum (zone graph, floors, loot, v2 cast and city) or design_ui's navigation spec except for the repairs listed in DT33 and the cross-track fixes DT14-DT16. The four track documents stay as reference (docs/design/towns_farm_social/). *Why / evidence:* Four designers worked in parallel on one codebase; the editor merged them and every disagreement is in section 11.

**DT2 - Tiers and gates.** CORE = needed for the first playable town loop (gate G5b); EXTENDED = content and polish that can be dropped without touching a CORE gate; LATER = optional and built last (S-marriage only); QA = acceptance packages of wave 7 (hard dependencies on CORE packages only, softDependsOn for the optional ones: a dropped package makes its checks SKIP with the capability name, never fail). The loop gates are G4 (wave-4 content), G5, G5b (first playable town loop), G6, G7 (design_integration 3.4). *Why / evidence:* design_integration 3.4; the three tracks used different words (scope / class): normalised to `class`.

**DT3 - The user's six requirements are all IN; marriage-style is scheduled, not hoped for.** Requirement (3) names marriage-style relationships. They are the LATER tier (S-marriage, wave 6) because they depend on the vocabulary decision Q2, but the package is in the plan, has an owner, tests, copy files, and every hook it needs is a late-bound task of built or earlier packages. If Q2 is not answered the defaults of the brief are used (bedste ven -> hjertven -> forlovet -> gift; items Hjertebuket and Løfteagern). *Why / evidence:* The user's requirement list; design_social 9.

**DT4 - The zone graph and the spawn names.** farm (Min Trækronsgård) -- ONE hanging bridge -- traetoppen (the treetop city, a levelled builder, zone traetoppen) -- ONE bridge -- hyggebyen (a grid map, zone id `city`). The Skovport is REMOVED (v2, generator and experience v2 agree); a sign SIGN_FARM_FOREST stands where the gate was. Spawns: farm {default, from_home, from_traetoppen}, hyggebyen {default, from_traetoppen, 14 x from_int_<building>}, traetoppen {default, from_farm, from_hyggebyen, from_skovlift}, interiors {default; exit from_int_<building> in the outer area}. The only warp of the farm is the bridge to traetoppen:from_farm. *Why / evidence:* design_farm DN2, design_towns 3.1, design2 DV2; farm_probe B8-B10 (43 checks).

**DT5 - farm.map is N01's (carve-out from P11).** data/maps/farm.map, localization/farm_signs.csv, tests/sections/maps_farm.gd and tools/farm/** belong to N01-farm-map (wave 4). P11 keeps hyggebyen.map, areas.csv and maps_iso.gd. To undo: delete one `owns` entry of N01 and the P11 ownsRemove of RT12; N01's tasks become P11 tasks with the same text. *Why / evidence:* The farm map is a design of its own with its own validator; both packages are wave 4.

**DT6 - Five farm stages, derived and never saved.** Stage = f(home_tier): Spiren 1-2, Kvisten 3-4, Grenen 5-7 (+1 growth row), Kronen 8-9 (+2), Slottet 10 (+3), data in lua/config/farm_site.lua, FarmStage.of_tier(tier) -> {id, index, rows}; the world flag farm_stage (1..5) is a mirror. Anchor contract: the `home` marker is the DOOR cell, anchor = iso_center + (-32, 19); the 9 x 3 deck base plus three void growth rows hold every tier's footprint and keep from_home free (probe C5-C7, mutant caught). *Why / evidence:* design_farm 4.2-4.3.

**DT7 - Farm objects: expansion, bin, shed, pond, greenhouse.** The field expansion is a marker (field_expansion id= cells= price=800) + UiConfirm, unlocked through the PUBLIC IsoArea API only (P04 needs no edit), persisted as the area flag zone_east. The shipping bin has no UI of its own: E ships the whole selected hotbar stack (crop / product / forage), paid at day_started at pay_ratio 1.0 (the seed shop's price: a convenience, never an arbitrage; the ratio is a data knob). The tool shed emits open_home_chest. The pond is decorative (no fishing). The greenhouse (N07) is OPTIONAL and gated on Q1; the default is NO and the 4 x 3 slot stays a silent data marker. *Why / evidence:* design_farm 5-6; income model: typical player 328 g/day on day 28, never needs more than 84 plots.

**DT8 - The first morning is data, run by a 100-line runner.** A new game starts at 06:00 on day 1: Pip (a TEMPORARY Npc2D at post pip_mailbox), Fekongens letter (P14's text), Pip's goodbye, the auto-accepted quest forste_dage (till 3, sow 3, water 3, mail on day 2, harvest 1; 150 g + 10 carrot seeds + 3 fertilizer + Pip +1), ten once-per-save whisper hints. Esc skips; `farm_tutorial.first_morning.enabled = false` falls back to P14's letter-only flow; never on Continue. The towns' routine keeps Pip in town on day 1 (day_max 1), so there is never a second Pip. *Why / evidence:* design_farm 11; integration leg L00 rewritten around it.

**DT9 - The roster is 30 citizens: 23 CORE, 7 EXTENDED.** 15 existing + 7 design2 cast (Hoppe, Brumme, Pip, Sofus, Fru Ugle, Natteblik, Birk) + 8 new from unused talk-capable bodies (rasmus, lamplighter_kiki, bertil, bodil, innkeeper_kvak, cub_bamse, clerk_fjerpen, fiddler_strimmel). CORE = the 15, the 7 and Skriver Fjerpen (23); EXTENDED = the other 7 (their npcs.lua rows are V1's, so the roster is 30 either way). The hero twins are rasmus, lamplighter_kiki, bertil, bodil: absent while the player is that hero; Birk and Kløvermynte (also playable) are never absent because the seed shop needs its keeper. A look cap of 16 distinct visuals per area; routines are validated to a planned peak of 14. *Why / evidence:* design_towns 5.1; design_integration 5.4.

**DT10 - Presence is a pure function of the clock.** Routines.where_is(npc, ctx) over Lua registry data with walking times from a baked route table (data/towns/routes.json): no simulation, no saved NPC positions, sleeping and skipping cost nothing. The TownDirector of the area the player is in keeps exactly the wanted citizens alive and frees every node on area exit. *Why / evidence:* design_towns 6: 7-9 us per call, 0.045 ms per physics frame for a whole day in Hyggebyen.

**DT11 - NpcDirector is a STATIC facade; the late-binding form is fixed.** There is no NpcDirector autoload. Every consumer (S-core, D2's hub marker, the loop's TownProbe) binds it the same way: Svc.node("NpcDirector") first (test fakes), then Svc.static_call("res://scripts/towns/npc_director.gd", &"<method>", [args], <default>). Methods: is_absent, is_away, is_present, where_is, population, resync(npc_id := ""). The when= grammar gains at:<npc> and away:<npc>; the hourly game_event routine_changed {hour} refreshes them. *Why / evidence:* design_towns X4; S-core patched (b1).

**DT12 - Opening hours live in the buildings registry, one rule.** Hours.state(building, ctx) is the ONLY rule: the door (Door2D), ShopSystem.is_open (a late-bound hook, RT5), the closing sequence (ShopHours) and the festival closure (SocialManager.shop_closed_by_festival) all read it. Hours are NOT fields of the shop defs (a building may host no shop; four packages own shop defs). Each shop is closed on exactly one weekday; 7-10 of 10 shops are open at noon on every day. *Why / evidence:* design_towns X1, design_integration X13.

**DT13 - Stores are walk-in rooms built from data.** 24 rooms (14 CORE, 10 EXTENDED) from data/interiors/<core|ext>/int_<id>.json by ONE builder (InteriorRoom), a 7-line stub map each (@projection iso, @zone <outer zone>, @builder), a 3x1 counter band (invisible hatch bars stop the player, citizens pass), the keeper one row behind, the `shop` interactable in front; E opens P18's panel over the live room (guide section 07). Pieces resolve: baked kit manifest > furniture.json > stand-ins > placeholder. *Why / evidence:* design_towns 4; 6.2 ms mean build, flood fill passes in all 24 rooms.

**DT14 - Cross-track fix: the dress marker reads the flag `festival_now`.** The farm map wrote `dress event=festival_today`; the social contract has the METHOD festival_today() and the WORLD FLAG festival_now (id of the festival active now, empty otherwise). N01's lifted map is changed in this ONE place and N05 re-evaluates on town_festival_started / _ended. *Why / evidence:* A flag nobody writes would have left the bunting off forever (found by comparing the three contracts).

**DT15 - Cross-track fix: Pip counts as met after the first morning.** farm_intro_pip declares social = false and ends through the normal Npc2D path, so SocialManager.on_conversation_finished('postman_pip', ...) counts it; the real Pip of the routines never greets the player as a stranger a second time. *Why / evidence:* Without it the scripted scene and the social first-meeting line would both introduce him.

**DT16 - Cross-track fix: a citizen without a dialogue file can still be talked to.** 4 of the 15 existing citizens and the 8 new ones have no lua/dialogue module. Npc2D passes an empty module to DialogueBridge.decorate, which always returns a greeting, the social choices and a close choice (P14 + S-talk tasks). *Why / evidence:* S-talk appended its choices 'before the Lua close choice': with no module there was no close choice.

**DT17 - SocialManager is the ONLY writer of friendship; the sixth feature autoload.** Autoload SocialManager (scripts/social/social_manager.gd), save section `social` (order 60, after loot 40 / dungeon 45 / collection 50), friend_<npc> and friend_last_<npc> become a derived mirror rewritten after every change and every load; reset() re-seeds points from the flags (hearts x 100), so quests, loot gifts, dialogue Lua and old saves keep working. Registered by add_autoload.py (sanctioned edit E1) after the P01 / F1 fix-round widened the closed lists of five. *Why / evidence:* design_social DS1, DS32; measured in the clone: 59 of 59 check_project checks pass with the patch.

**DT18 - The social rules are design_social's DS1-DS36.** Adopted whole: hearts 0-10 (100 points, half heart at 50), the first FINISHED conversation of a Monday-Sunday week gives exactly one heart (the DF3 floor), no decay and nothing negative, gifts 40 / 20 / 8 / 0 / 0 with rarity x1.25 / x1.5, birthday x4, 1 per day and 2 per week, 30 distinct birthdays (min gap 2, none on or beside a festival), nine festivals + the wedding, six activity primitives, heart events started by the player, the marriage ladder with no gender gate and no break-up, FNV-1a + fmix32 over a saved seed, state queries instead of edge triggers, daily work deferred and coalesced. Monte Carlo (200 runs x 336 days): a typical player reaches 8 hearts with a tier A citizen on day 72 (p10 55, p90 97). *Why / evidence:* design_social 2, 13; social_scripts/mc_result*.json.

**DT19 - One generic Lua kind for the new data: `registry`.** routines, buildings, events and festivals are registries (kind = "registry", get_registry / get_registry_entry): ONE P10 fix-round (RT4) serves the towns and the social track; the social track's dedicated-kinds patch stays a fallback only. *Why / evidence:* design_social C2 / RC3; proven with 102 scripts, 0 lint findings.

**DT20 - Zero new EventBus signals, one new input action.** Everything new is EventBus.game_event(name, payload) (section 8.2); friend_changed(npc_id, hearts) keeps its arity and fires only on whole hearts; the one new action is `people` = P (pad: pause row 'Folk'). core.signal_contract_exact stays at 75. *Why / evidence:* design_social DS29, design_integration 6.3-6.4.

**DT21 - Six new screens or surfaces, each with a registry row and a baseline owner.** people, gift, calendar (journal tab), social_hud, event_overlay, post. Rows live in tests/lib/ui_screens.d/{social,social_events,towns}.json (one file, one owner; UiAudit.screens() merges the directory), each baseline PNG is owned by its screen's package. The People book is read-only and lists only citizens the player has met; the friendship glyph is a heart with a moss sprout, distinct from the health hearts by SHAPE. *Why / evidence:* UI_NAVIGATION.md; design_social 11.

**DT22 - Festival posts: ONE marker per spot, the city has a sidecar.** Hyggebyen carries ONE `post set=fest spot=hyggetorv` marker (24 posts at fixed offsets); the three city spots (torvet, badehus, raadhus) are `fest_sets` of data/towns/traetoppen.json (T-routes, wave 5; built by T-director). The social track's 24 per-post marker lines in P11 / V4 are dropped. The names fest_<spot>_host / judge / stall_1..4 / table_1..2 / gather_1..16 are the contract. *Why / evidence:* design_towns X2; the city has no map text.

**DT23 - ONE decor mechanism: I5's FestivalDecor.** Festival decoration is placed by I5's data-driven FestivalDecor (late-bound from the TownDirector) for Hyggebyen AND the city; the shipped maps carry no `when=fest:<id>` decor markers (the grammar still allows a hand-placed one). EXTENDED: without I5 the festival works and the town is plain. *Why / evidence:* design_integration 5.3: social's marker decor cannot reach the city.

**DT24 - The night watch is the director's; world_2d.gd needs only D0's edits.** At 23:30 a whisper, at 23:45 the night watch sends the player to farm:from_home (held during modals; off on the farm and in homes). It lives in the TownDirector, so no P04 edit is needed, and it coexists with D0's pass-out relocation. The extra world_2d.gd tasks are D0's: the warm-clips rule R-V4 (walkers warm `walk`) and the pass-out wake (DT50). *Why / evidence:* design_towns X10 against design_integration X4.

**DT25 - Festivals, shops and the bed.** A festival window ends by 23:00 (the pass-out is at 24:00); while it is active SocialManager keeps the config override time.sleep_from_hour = to and RE-APPLIES it from the state query on every flush, load, area change and festival event (GameManager.set_config_override is a never-saved test seam wiped by clear_config_overrides()), closes shops per the festival's `closes` / `stays_open`, and gathers citizens through override_for. Festivals ignore weather (no rain venue: honest stub). *Why / evidence:* design_social DS17, DS28.

**DT26 - Shop friendliness is tiny and visible.** 1 point per 100 gold spent (weekly cap 10 per keeper) and a weekly keeper sample from the hearts the shop def names; the existing friend_discount (0.005 per heart, F4's PriceCurve) is untouched, but PriceCurve reads the KEEPER's hearts. *Why / evidence:* design_social DS23.

**DT27 - Copy: a review state machine, a lint, the `_V` voice rule.** Every new CSV is delivered at status draft, a fresh-context agent sets ai_reviewed in the same wave, native_reviewed is only ever set by a commit of the user. Voiced rows end in `_V` (<= 14 words, no digits, no %), the generated lua/dialogue/_voiced_social.lua indexes them for the existing hash lint, 8 archetype presets give 30 citizens their pitch and rate, voice is generated only for rows at ai_reviewed or better. Style sheet R1-R11 and copy_lint C1-C10 (I1). *Why / evidence:* design_integration 4.

**DT28 - Audio: an AudioDirector child, a cue log, synthesised placeholders.** AudioManager stays the only audio autoload and creates the AudioDirector as a child; data in lua/config/audio.lua maps area / surface / event to cue ids; every call is logged in AudioManager.cue_log (ring of 256) so headless tests assert hooks without files; placeholders are synthesised in Python and replaced by dropping real files of the same name. P24 is the heaviest package of wave 6 (size L, seam for a split in RT31). *Why / evidence:* design_integration 4.5.

**DT29 - Art: three kits, a split with P22, S3TC for the farm kit.** N03 bakes only the 10 farm-only props, 3 backdrops and the field_grass terrain; P22 bakes coop_small, barn_small, animal_house, paw_prints, apple_tree, bench, signpost to the contract sizes and gets the 16 props_extra rows. I3 (CORE, 35 pieces: counter band, sign bracket, the 16 pieces the 14 core rooms draw as stand-ins, 15 emblems), I4 (EXTENDED, 69 dressing pieces placed by overlays), I5 (EXTENDED, 24 festival pieces + FestivalDecor). N03 imports its kit VRAM-compressed (65.5 -> 15.8 MB). The apple-tree season variants are an optional lookup of the node handler's owner. *Why / evidence:* design_farm 10, design_integration 5.1-5.6.

**DT30 - Budgets.** Process VRAM <= 400 MB (city peak 307.9 MB with the S3TC farm kit, 357.6 without); 16 distinct NPC visuals per area (8.93 MB each); interior <= 130 nodes, <= 12 ms warm rebuild, <= 4 lights; city <= 40 ms build / <= 6 ms frame; the FARM has its own row (< 60 ms build, <= 8 ms frame, <= 560 / 640 / 780 draw calls at zoom 0.4 / 0.3 / 0.2, <= 130 MB, <= 12 lights) because its 1,206-cell y-sorted ground cannot be 94 calls; citizens <= 0.4 ms per frame; save <= 60 KB. *Why / evidence:* design_integration 5.6-5.7, design_farm 14.2.

**DT31 - ONE data-only extension proof.** I2's leg L18 (copy the repo to a temp project, add only the data files of tests/fixtures/town/**): citizen, building (a new walk-in shop), routine edit, shop hours, festival, heart event, quest, and zero .gd / .tscn changed. zz_towns and zz_social re-run their legs; the P25 how-tos use the same fixture files. *Why / evidence:* The proof was promised three times (T-qa, S-qa, L18).

**DT32 - Four QA packages, one index.** N08 (farm), T-qa (towns), S-qa (social) each own their section, shots and report; I6 owns the aggregate (rows 31-39, the three-hero windowed run, the budget table) and links the three. QA packages never hard-depend on an EXTENDED package. *Why / evidence:* check_ownership.py D flagged T-qa and I6 (CORE with hard dependencies on EXTENDED).

**DT33 - Repairs of design_ui's ownership (not this addendum's design).** check_ownership.py (raw mode) found 34 pattern overlaps and 13 tracked files with two owners in the merged table, all caused by design_ui and none by a design3 package: P07 still owns the component files design_ui gave to P28 and P17 and localization/ui.csv (P14), and P27's docs/qa/** still matches every screen baseline PNG. RT7 and RT34 list the exact paths. Everything else of design_ui stands. *Why / evidence:* check_ownership.py --raw output (section 15).

**DT34 - One fix-round before wave 4, in this order.** RT1 P15 (save registry tests), RT2 F1 (autoload tool, FEATURE_NODES, Grant), RT3 P01 (check_project six names, the `people` action, the docs copies and the new header line), RT4 P10 (registry kind + 4 api functions), RT5 P12 (shop hours hook), RT6 P04 (when= delegate), RT7 P07 (SCREEN_ORDER + the ownership repair), RT8 P09 (--fast, ui_screens.d merge, DEVELOPMENT.md), RT9 P03 (E2). Each is a task of a BUILT package executed by the lead; late binding makes every one harmless before its consumer exists; new checks go into a section of the amended package itself (DT58). *Why / evidence:* design_social 15.4, design_towns 10.2.

**DT35 - Three sanctioned shared edits: E1, E2, E3.** See section 8.14. *Why / evidence:* E1 existed; E2 and E3 are the new routine chores.

**DT36 - The wave plan keeps the tracks' waves; the load is stated, not hidden.** Wave 4 = 65 points, wave 5 = 62, 5b = 27, 6 = 28, 7 = 15 (S=1, M=2, L=3, XL=4). S-core, T-towns-core and N01 cannot slide out of wave 4 (wave-5 packages depend on them). If a wave overruns: stagger writers inside the wave (data and copy last), then defer in this order: I4 sets, I5, N05 / N06, T-ext-content, S-heart-content, S-fest-content, S-marriage, T-post-office, T-greetings. CORE is never deferred; the gates list what they skip. *Why / evidence:* design_integration 7.1 and 7.4; section 9.

**DT37 - Honest dependency: F2 / F6's friend hooks live only with S-marriage.** SocialManager.partner_in_home / pick_visitor / start_house_party (the weekly guest gift naming a friend, the tier-8 party with friends, the partner in the room) are provided by S-marriage. Without it HomeManager.guests_today() is [] and the visitor gift stays anonymous. *Why / evidence:* design_social 14.1: the three methods are marked S-marriage.

**DT38 - Small questions are decided here and are data knobs.** Shipping bin ratio 1.0 (farm_site.bin.pay_ratio); the pond stays decoration; a home opens while its owner is home and awake and friend_<npc> >= 1; the mayor commutes Tue-Thu (78 game minutes each way); the inn sells nothing; the `Hvor er ...?` list is built in wave 6 and droppable; the festival music is a synthesised placeholder; festivals hold the bed until they end; the key is P; the two stalls (Torvestanden, Natteblik-vinduet) keep an outdoor counter and have NO room (the sketch's own form: the one deviation from the literal requirement 4, asked as Q7). Each is one data value or one input-map line. *Why / evidence:* None of them changes a contract; the build follows these values unless the user says otherwise.

**DT39 - The plan header gains a NEW line; the pinned line never moves.** RT3 copies the addendum and the package file into docs/design/ and adds ONE new header line to PLAN_2D.md (design2 does the same); the SUPERSEDE_LINE pin of check_project.gd uses `contains`, so no existing line is rewritten. *Why / evidence:* design_social RC9 / design_integration X7 wanted ONE rewrite of line 3 plus the pin; a new line needs neither.

**DT40 - The retired town name is never written.** Not in this addendum, not in packages.json, not in any task; the lint source writes it in two halves like check_project.gd does. check_ownership.py has no way to check this, so build_final.py scrubs and asserts. *Why / evidence:* p01.design_files_use_current_town_name would fail on the first copy.

**DT41 - The hero id is derived, not stored.** hero = CharacterCatalog.hero_of_skin(GameManager.character_skin).id (rasmus, kiki, kloevermynte, birk, bertil, bodil), read late bound by the routine context; the world flag hero_id is a test override nobody writes in play. *Why / evidence:* The towns prototype read a flag that no package wrote.

**DT42 - Natteblik has two stands (honest wart).** Design2 puts him beside the Hulen of floors 2 / 6 / 10 at night entry, the towns put him at the city's bat window 19:30-23:30. One shop id, so the hours rule closes both outside 20:00-23:30; the two places are different areas and the dungeon's clock is paused. *Why / evidence:* Not reconciled further: it is a bat.

**DT43 - Package size honesty.** P14 grows from L to XL (the NPC runtime serves six tracks), P24 from M to L. Both are single-owner files; the seams for a split are written down (RT24, RT31). Every NEW package is one agent's job (largest: I4 XL, 69 art pieces, droppable set by set). *Why / evidence:* design_integration R11.

**DT44 - A decision-gated package contributes only conditional amendments.** N07 is `optional: true`; its two changes of built packages (P06: indoor flag + crops_extra merge) are `conditional` tasks of RT11 that exist only if the lead activates N07; its winter seeds have their own shop file so the seed shop's hours cannot block winter planting. *Why / evidence:* design_farm 5.5 and Q1; the carve-out of P12's glob for lua/shops/greenhouse_seeds.lua is N07's own owns line.

**DT45 - The farm's post names are the contract.** pip_mailbox, hoppe_fence, bench_a, porch, field_edge. The social draft's `farm.visitor_bench` is not a post: nobody uses it. *Why / evidence:* design_towns X5.

**DT46 - Who attends a festival.** The citizens whose home area is the festival's area (an absent hero twin excluded), ordered by SocialRng.roll(seed, [festival, npc]), at most 15 plus the host (the look cap is 16, so the crowd never drops anybody), one per fest_<spot>_gather_<n>; keepers of `stays_open` shops stay at their shop; attendance points go to the host and to every citizen the player TALKED to during the window. *Why / evidence:* design_social 7.8 and design_towns X6; S-core's task text said 'tier A/B friends sorted by id' and no cap.

**DT47 - A `routine = true` citizen is placed by the director ONLY where a director controls the area.** V1 sets `routine = true` on all 30 npcs.lua rows in wave 4, but T-director lands in wave 5b. The P14 `npc` marker handler therefore skips such a row only when NpcDirector.controls(npc_id, area) is true (the citizen has a routine entry AND the area is under a director: a `town` marker whose handler exists, or the city with its sidecar and `city_town.gd`); before that the static marker NPCs of Hyggebyen and the city keep talking, so gate G5 (L03 talk, L06 dialogue entry) has somebody to talk to. *Why / evidence:* Found tracing the loop: with a flag-only skip waves 5 and 5b would have shown empty towns while G5 requires a conversation.

**DT48 - The room services have marker rows.** Rooms place V6's PostBox2D, NoticeBoard2D and BathTub2D from room JSON markers through IsoArea.resolve_handler, which reads lua/config/marker_handlers.lua. design2 registered only `mailbox` (V4's builder instantiated the other two in the city); RT19 now registers `bath` and `board` too (scripts/traetoppen/life/{bath_tub_2d,notice_board_2d}.gd), and V4's city JSON carries none of the three. *Why / evidence:* Found tracing the loop: without the rows the Rådhus board and the bathhouse tub stay announcing counters.

**DT49 - A door of an unbuilt EXTENDED building is a clean locked nameplate.** P11's hyggebyen.map carries 14 door markers, four of them for EXTENDED buildings (the king's house, the mayor's house, Pippin's house, Birk's hives) whose registry rows live in T-ext-content's lua/buildings/ext.lua. Door2D treats a building without a registry row as a locked nameplate labelled BLD_<ID> (towns.csv defines all 30 names), so dropping T-ext-content leaves four locked doors, never a broken one. *Why / evidence:* design_towns proved the CORE-only data green (20 buildings) but not the map's doors.

**DT50 - The 24:00 pass-out wakes at home.** world_2d.gd's `_sleep_sequence(true)` leaves the player where he stands (a shop, a street, the far end of the field). The farm design (6.4) and the loop leg l11_pass_out_wakes_on_farm assume farm:from_home; D0 (the owner of world_2d.gd) already writes the gentle defeat that wakes there, so its amendment (RT22) gets the pass-out as a second small task (no gold loss, no run end). *Why / evidence:* Found tracing leg L11: three tracks promised the wake position, none wrote it.

**DT51 - A named post is found through the NpcDirector facade.** The festival runtime (S-events) and the event marks need the position of fest_<spot>_host / gather_<n> / mark:<id>. Hyggebyen has them as map markers, the city only in the sidecar, so both ask NpcDirector.post_ground(area_id, name) (T-routes' facade, forwarded to the live TownDirector); I5's FestivalDecor is handed the director and calls director.post_ground(name) directly. *Why / evidence:* Found tracing the festival leg: the social design assumed `find_markers("post")`, which is empty in the city.

**DT52 - Every game event of the contract is named by its emitter.** A contract row is only kept when the emitting package's tasks name the event and every consumer that is not a test is a package whose tasks read it; `counter_used` (named by no task and read by nobody) was dropped, routine_changed was added to T-director, home_exterior_ready to N02 and N05. *Why / evidence:* Found by a script comparing the 26 contract rows with the 228 task texts.

**DT53 - Every counter has three kinds of host, so a keeper can always be talked to.** A counter band carries the centre host of its service (`shop`, `post_counter`, `bath`, `board`, `appraisal`) and TWO `talk` hosts (ellipse 40 x 22) on the customer cells m-1 and m+1 in front of the counter ENDS; the builder yard adds a `desk` host (game_event open_home_builder {tier}) as the second door of the Husbyggeri; the two stalls get the same trio from the `counters` rows of the city sidecar. The BUILT E-query (circle r = 45 at the facing cell, the host nearest to the PLAYER wins) then decides by where the player stands: the middle cell opens the panel, an end cell opens the keeper's own dialogue (greeting, weekly heart, gifts, topics, birthdays, quest offers and turn-ins, the upgrade choice). A talk host stays disabled while no keeper stands in the room. The ShopCounter seam `forward_to_keeper` and its rule 'a giftable hotbar item takes E first' are REMOVED (the rule would have sent 12 of 12 tools and 8 of 8 seeds into a gift talk instead of the shop panel). *Why / evidence:* Reviewers (social_economy, plan): with the built rule the keeper was selected 0 of 576 samples (counter 144 at the default radius), 15 of 23 CORE citizens are keepers whose outdoor presence is 0-2 h a day for Natteblik, Sofus, Brumme, Pip, Zephyr, 14 of 24 quests have a keeper as giver, and the home ladder (74,000 g) was reachable only through Hasselnød's dialogue. Proof: replay and REAL Player stub agree on 23,760 samples of the 14 core layouts, A 252 / 252, B 126 / 126, C 0 (D3/final_editor/se1/out); availability Monte Carlo, typical tier A to 8 hearts with visits at mixed hours: day 69 / p90 154 / 10 % never WITHOUT the cells, day 70 / p90 108 / 0 % never WITH them (se6).

**DT54 - A lifted file names no class of a later wave.** Every lifted prototype script is EDITED so that it names no class_name owned by a later wave: Hours has its own clock-only now_ctx() (Routines.now_ctx extends it later), Door2D and ShopHours reach Routines only through Svc.static_call with a safe default (homes locked, no eviction by owner), NpcDirector tracks live directors as Objects in its static registry and makes duck-typed calls (no `as TownDirector`), SocialManager reaches GiftRules only through Svc.static_call. Each of the four packages carries a check (`no_forward_class_refs`) that scans its own scripts for the identifiers of later packages outside strings and comments; towns_data also loads its scripts in a tree without the later files. *Why / evidence:* The package-level 'no forward dependencies' proof does not see class_name references. Measured by simulating each wave: hours.gd alone 'Parse Error: Identifier "Routines" not declared', npc_director.gd 'Could not find type "TownDirector"', social_manager.gd 'Failed to instantiate an autoload' (three GiftRules references).

**DT55 - The opening-hours rule has ONE test switch and a stated clock.** The config key `towns.hours_enabled` (default true) makes Hours.shop_open answer null; P12's helper `ShopHoursGate` honours it, so shop_system.gd gains no third `static_call(` line and the built pin economy.late_binding_via_svc stays true. Which clock a section runs at: sections that are NOT about hours run with the switch off (economy.gd's `_fresh()` since design2 gave that file to DL1: RT35; every later section that buys or sells sets it in its fixture), sections about hours (towns_data, towns_interiors*, towns_director, economy_hours, the shop panel's closed state, the hour legs of town_loop) leave it on and set the clock explicitly through LoopClock / t.set_time (Monday 12:00 unless the check names another). The built economy section is edited by DL1's amendment, not by P12's fix-round. *Why / evidence:* Measured in a clone: with the buildings registry loaded all 9 shops are closed at the new-game clock (day 1, 06:00, Monday), 25 built P12 checks fail; with the switch off economy runs 304 checks, 0 failed, and core + save + data + content_features + economy 1,104 checks, 0 failed (D3/final_editor/te2).

**DT56 - The city sidecar and LevelNav belong to T-routes; unbuilt rooms are PENDING.** T-routes (wave 5) owns data/towns/traetoppen.json (doors, 36 posts, gates, festival spots, the two stall counters) and scripts/towns/level_nav.gd and depends on V3-levels (levels_graph(), RT21), so the route table bakes the CITY in wave 5; T-director (5b) only builds the Door2Ds and stall counters from it (city_town.gd) and re-checks the door coordinates against V4's geometry. The 14 CORE rooms are data of T-interiors-core (same wave): TownsValidate.PENDING_AREAS lists an unbuilt room by name as SKIP and the wave-5 gate requires the list to be empty. The marker collection and the post snap (TownMarks.collect / resolve_cells, lifted from the prototype's town_marker.gd) are T-routes' own statics. *Why / evidence:* Simulated wave-5 acceptance without the city: routines.feasible FAIL (219 findings), routines.places_exist FAIL (81), post_capacity FAIL; the acceptance of T-routes could not be met in its own wave.

**DT57 - The G5b closure holds no dungeon-track package except D0 and DR7.** V4-city-map no longer depends on D2-dungeon-floors and P19-forest-combat (RT29: removeDependsOn; P19 becomes a softDependsOn); its two chain checks SKIP with the capability `D2 landed` and are REQUIRED by DQ's E1 / E2 (wave 7). The hard-dependency closure of the 16 CORE packages plus V4 is 49 packages, 34 unbuilt (47 plus D0 and DR7; checker section I prints it and fails on any dungeon-track member except D0 and DR7, which the loop needs: the pass-out wake and the stall shop natteblik_maps). A sequencing rule: packages outside the closure (wardrobe A2 / F5 / F8, D1, D2, DR*, D3, DL1-DL6, P19, V8 / V9, P23) start after G5b or run in a separate lane. *Why / evidence:* closure.py: the closure of d3 CORE + V4 was 52 packages, 37 unbuilt, containing D1, D2, DR0, DR1 and P19 (12 points) only through two edges used by two chain tests and two planter node kinds; about 54 of 155 points of waves 4-5b are outside the closure.

**DT58 - A fix-round amendment writes only into its own section and names only checks that exist at that time.** Each fix-round task of a BUILT package (RT1-RT9) puts new checks into a section file of its own package (ownsAdd: RT4 tests/sections/data_registry.gd, RT5 tests/sections/economy_hours.gd, RT9 tests/sections/loc_towns.gd, P26 loc_final.gd) or keeps an EXISTING check green, and names no check of a section owned by a later wave (checker section J fails on it): RT2 builds its pristine project inside the tool and leaves content_features.gd alone, the three social.* checks of RT2 / RT4 are S-core's, RT8's merge check is in P09's ui_audit section. Checks that need a later package are proven by that package at its own gate. *Why / evidence:* review/plan/out/verify_cross_owner.txt: 21 task / check pairs named sections owned by wave 4-5 packages (and the layered ownership gate would have flagged the edits as FOREIGN).

**DT59 - Uglehulen is a service: no shop id, a counter of kind `appraisal`.** The building row of Uglehulen has no `shop` field (kind service); her room's centre host emits game_event open_appraisal {npc, building} (design2's event, hosted by F4's LootService, screen DL7), is refused with the closed whisper while Hours.state is closed and whispers COUNTER_APPRAISE_SOON while LootService has no appraise(); her talk cells open her dialogue with the choice 'Vurdér mine fund'. The draft shop id fru_ugle_vurdering is removed from the registry, the room wiring, T-greetings (11 shop ids, 61 rows) and section 8.12. *Why / evidence:* design2's final addendum says the id does not exist (DX57); a ShopCounter on it called ShopSystem.open_shop on an unknown id and the validators that require every building shop id to exist could not pass.

**DT60 - A gift of value asks first; progress is protected.** S-gifts hides tools in the hotbar, the last copy of any tool, the materials of the next home tier and the pieces of a wardrobe set whose capstone is open (late bound reads of F2 / F4), and GiftRules.needs_confirm marks tools, rarity rare and sell value >= 100 g; the picker opens UiConfirm (default focus Fortryd) for those, cheap gifts stay one press. *Why / evidence:* social_dump.json: all 12 tools, 56 rare items (sell 34-1,670 g) and all 26 building materials were giftable, one press gave the item away for at most 60 points.

**DT61 - Four economy guards.** (a) A partner who keeps a shop leaves the farmhouse at opens - walk x 2 / 60 - 5 minutes (Maja has no morning there, Kløvermynte until 06:48, Brumme and Rasmus 06:56), validated for the 11 candidates by hours.keeper_covers_hours with a partner overlay; (b) contest rewards are capped in value by SocialValidator SV14 (first <= min(2 x the cheapest winning entry, 400 g), second <= 0.7 x first, third <= 0.4 x first); (c) a festival lists a shop in stays_open only if the shop is open on that weekday (seed_shop is dropped from Blomsterfesten and Høstfesten: both Sundays); (d) the seed shop restocks 25 carrot seeds a day (was 20). *Why / evidence:* Measured: fixed 08:00 left Maja's bakery unstaffed 115 minutes, Kløvermynte's shop 67, Brumme's 59; a contest could pay up to 5 x 1,670 g = 8,350 g a year; the Sunday festivals promised an open seed shop the Hours rule closes; 6 x 20 carrot seeds a week left a dedicated 110-plot field 2.1 seeds a day short (-4.8 % income).

**DT62 - Balance claims are ranges in two availability variants; four heart scenes per tier A citizen.** social.balance_claims_hold asserts ranges, not points (median <= 80, p90 <= 115 with LEAN events, <= 110 with four events) in a `free` and a `mixed` variant (visits at mixed hours, keepers reachable at their counters), with a ratchet file written by the first accepted run; S-heart-content builds 40 scenes (4 / 6 / 8 / 10 hearts for the 10 tier A citizens) instead of 20 and becomes size L. The year-2 hook (a new birthday card per year) and the 2-heart introduction stay roadmap. *Why / evidence:* se6 (100 runs x 336 days): typical tier A to 8 hearts free 71 / p90 97, mixed 70 / 108 with the talk cells; with four events free 66 / 90, mixed 65 / 101; a typical player has seen all 20 LEAN scenes by day 97 (p90) and has 14 of 30 citizens at 10 hearts after a game year.

**DT63 - The loop digest excludes every wall-clock path.** digest_volatile.json lists exactly /game/play_time_seconds, /meta/saved_at, /meta/timestamp and /meta/summary; town_loop.digest_stable_over_wall_clock compares two digests taken 1.1 s apart; l13_digest_has_teeth still proves gold and flags move the digest. *Why / evidence:* SaveManager.gather_payload writes saved_at and timestamp from the real clock: two gathers 1.1 s apart differed in exactly those two paths and the prototype's two-path list gave two digests (D3/final_editor/te4).

**DT64 - The ownership proof must be usable by the lead's tooling.** check_ownership.py (this folder) can emit the EFFECTIVE owners table (include and exclude patterns per package, all layers merged) with `--emit-effective FILE`; the lead's impl/tools/ownership.py must honour exclusions like the checker does (a drop-in `lead_tools/ownership.py` is shipped); the docstring of the checker no longer claims the old tool has the same semantics. *Why / evidence:* impl/tools/ownership.py reads only owners[pid]['owns'] and make_orders.py removes by exact string: 67 of 69 ownsRemove entries of this addendum are sub-paths of wider globs, so a regeneration with the old rule leaves them doubly owned and the gate tool accepts it silently.

---------------------------------------------------------------------------------------------------------------------------------------------

## 11. Conflicts between the tracks and how they were decided

Found by reading the four documents against each other, by tracing the user's loop wave by wave, and by running `check_ownership.py --raw` on the unedited union of the four track files (BEFORE: 34 pattern overlaps, 13 doubly owned files, 14 dependency / tier problems, 2 unowned or ambiguous named paths; AFTER: 0 of each). The editor decided each; where a defect of design_ui or design2 was proved, it says so.

| # | Topic | The tracks said | Decision | Ref |
|---|---|---|---|---|
| C1 | who owns data/maps/farm.map | plan: P11; farm: N01 | N01 (carve-out; reversible with two lines) | DT5 |
| C2 | the Skovport | plan and experience v1 keep it; v2, generator and experience v2 remove it | removed; SIGN_FARM_FOREST; no from_skovport spawn | DT4 |
| C3 | where opening hours live | integration: shop defs; towns: buildings registry | buildings registry (a building may host no shop) | DT12 |
| C4 | how the social track reaches the towns director | social: Svc.node("NpcDirector"); towns: static class | static facade, both forms tried in order; `away:` and routine_changed added to S-core | DT11 |
| C5 | festival post sets | social: 24 marker lines per spot in P11 and V4; towns: ONE set marker + the city sidecar | towns; the social P11 and V4 tasks are dropped | DT22 |
| C6 | festival decor | social: when=fest: props in the maps; integration: FestivalDecor | FestivalDecor only (the city has no map text) | DT23 |
| C7 | dress marker flag | farm: event=festival_today (a method); social: world flag festival_now | festival_now | DT14 |
| C8 | hero id source | towns: world flag hero_id (nobody writes it) | derived from the skin through CharacterCatalog | DT41 |
| C9 | first meeting of Pip | farm: scripted scene; social: first-meeting line | scene is social = false and counts as met | DT15 |
| C10 | citizens without a dialogue module | social decorate assumed a Lua close choice | empty module + decorate always closes | DT16 |
| C11 | calendar location | integration: People book; social: journal tab | third tab of the journal (the user's brief) | DT21 |
| C12 | wasted pins: PLAN_2D.md line 3 + SUPERSEDE_LINE | social and integration: rewrite line 3 and the pin | add a new line, leave the pin | DT39 |
| C13 | world_2d.gd needs | integration: three towns edits (pass-out wake, closing eviction, director on_exit); towns: none | two small D0 tasks: warm clips and the pass-out wake; the other two are not needed | DT24, DT50 |
| C14 | the farm's frame budget | integration: 4 ms / 94 draw calls | the farm has its own row | DT30 |
| C15 | farm kit VRAM | farm: 56.5 MB model, fallback = cut trunks; integration: measured 65.5 MB | S3TC import: 15.8 MB, no fallback needed | DT29 |
| C16 | L00 expects ONE dialogue; the first morning has three | farm vs integration | L00 rewritten around the sequence; the data switch stays | DT8 |
| C17 | farm post for visitors | social: farm.visitor_bench; towns/farm: hoppe_fence and bench_a | the real names | DT45 |
| C18 | QA packages hard-depending on EXTENDED ones | T-qa, S-qa, I6 | class QA + softDependsOn | DT32 |
| C19 | the data-only extension proof | T-qa, S-qa and I2-L18 each | one proof, L18 + building + routine-edit legs | DT31 |
| C20 | how-tos | integration, social and towns each listed add_a_citizen / add_a_festival / add_a_heart_event | one merged P25 task | RT32 |
| C21 | design_ui overlaps (P07/P28/P17/P14/P27) | design_ui | exact-path repairs in RT7 and RT34 | DT33 |
| C22 | baseline PNGs of the new screens had no owner | social, towns | each screen's package owns its PNG; P27 excludes them | DT21 |
| C23 | the event_overlay registry row | S-events wrote a row into S-ui's file | own file tests/lib/ui_screens.d/social_events.json | DT21 |
| C24 | ui_screens.d carve-out by directory | integration: ownsRemove the whole directory | exact files | RT8 |
| C25 | docs/DEVELOPMENT.md | named by a task, owned by nobody | P09 | RT8 |
| C26 | F1's pristine project.godot fixture lived in P01's tree | social | tests/lib/features/fixtures/ (F1's) | RT2 |
| C27 | FarmReserve consumers | N02: P20 and F2's upgrade check; F2 has no such task | P20 and P06 (both late bound; F2 has no such task) | N02 patch |
| C28 | winter seeds had no seller | farm N07 | greenhouse_seeds shop, no town hours | DT44 |
| C29 | T-routes and T-director did not depend on the farm map they bake and use | towns | dependencies on N01 added | b1 |
| C30 | acceptance row numbers 22-30 clash with design2 | integration | rows 31-51 | section 13 |
| C31 | two files named traetoppen.json | V4 data/traetoppen/traetoppen.json (geometry), T-routes data/towns/traetoppen.json (doors, posts, gates, festival sets, stall counters; moved from T-director by the final edit) | kept apart by directory and named apart in the tasks | T-routes patch |
| C32 | Natteblik at the bat window AND at the dungeon Hulen | design2 and towns | kept; one shop id | DT42 |
| C33 | wave 4 and wave 5 overload (65 / 62 points) | integration R1 | kept, with stagger and deferral rules | DT36 |
| C34 | Fru Ugle and the other cast of V4's city JSON | design2: static `npc` markers (Fru Ugle in the first owl hole with reach 420 px, Brumme twice with `when=flag:`); towns: routine citizens with doors and rooms | the director places every `routine = true` citizen where it controls the area (DT47), so those markers are skipped there and stay the fallback of a build without the towns; Uglehulen (hut 2) is the owl hole's door; the `reach=` marker parameter stays a P14 feature | DT47 |
| C35 | routine = true rows from wave 4, the director only in wave 5b | towns: flag-only skip | NpcDirector.controls: skip only under a director | DT47 |
| C36 | board and bath had no marker rows; the pass-out wake and the post positions had no writer | design2 / farm / integration / social assumptions | RT19 rows, RT22 pass-out task, NpcDirector.post_ground | DT48, DT50, DT51 |
| C37 | V4 depends on D2 and P19, so the town loop gate drags the dungeon generator | design2: V4.dependsOn lists D2-dungeon-floors and P19-forest-combat (two chain tests, two planter kinds); design3: G5b needs V4 | the two edges are removed by RT29 (P19 soft), the chain tests move to DQ (RT37); the G5b closure holds no dungeon-track package except D0 and DR7; the defect is proved by closure.py | DT57 |
| C38 | design2's guards say '11 + 5 autoloads, 35 actions' while this addendum adds the sixth autoload and the 36th action | design2 DR1 task 10, D2 task 8, DQ E9; design3 RT3 / S-core | the guards compare with the P01 contract and assert 'this package adds none' (RT36, RT28 task 2, RT37) | DT54 |
| C39 | the shop id fru_ugle_vurdering | design2's retired draft DX7 (kept by the first merge) vs design2's final addendum (no such shop; open_appraisal event) | Uglehulen is a service with a counter of kind appraisal; the id is removed everywhere | DT59 |
| C40 | who edits tests/sections/economy.gd | P12 (built) fix-round vs DL1 (design2 gave the file to DL1, wave 4) | RT5 adds a section economy_hours and keeps shop_system.gd at two `static_call(` lines; DL1's amendment RT35 edits economy.gd | DT55 |
| C41 | who bakes the city in wave 5 | T-routes (bake, wave 5) vs T-director (sidecar and LevelNav, wave 5b) | the sidecar and LevelNav move to T-routes, T-director builds from them | DT56 |

### 11.1 The request ledger (every request of every track and where it ended)

| Id | Route | Request | Disposition |
|---|---|---|---|
| R-N1 | farm -> towns | keep Pip's day_max 1 rule | kept in T-routes; N04 relies on it |
| R-N2 | farm -> integration | L00 counts the letter by speaker or sets first_morning.enabled false | L00 rewritten (I2); the switch stays (DT8) |
| R-N3 | farm -> social / towns | bench_a vs visitor_bench | bench_a (DT45) |
| R-N4 | farm -> V4 | from_farm arrival exists and the zone toast ZONE_TRAETOPPEN fires once | V4's own check; PENDING_AREAS in maps_farm until V4 |
| R-N5 | farm -> node owner | optional apple_tree_<season> art lookup | optional, N06 (DT29) |
| R-N6 | farm -> generator hub | the hub has gate arches for Trætoppen only | design2's hub; no farm gate |
| R-N7 | farm -> F1 | data/features/map_markers.json keeps the farm entry | exists; N01's map matches it (maps_farm.feature_markers_match_json) |
| R-N8 | farm -> towns | the farm map carries town curfew=false and the five posts exactly as the towns draft | N01 task 2; handler T-director |
| T-1 | towns -> farm | one more marker line: town curfew=false | done (R-N8) |
| T-2 | towns -> social (S-core) | late-bind NpcDirector; add eval_when away:<npc>; <= 15 attendees + host; hero twins = four | DT11; S-core patched; DS17 cap in S-events |
| T-3 | towns -> social (S-fest-content, V4) | festival posts come from ONE set marker / the city sidecar | DT22 |
| T-4 | towns -> integration | kit ids, TownProbe names, post.csv, keepers.csv owner | all adopted (design_integration 9.2) |
| T-5 | towns -> D0 | no world_2d.gd edit asked | DT24 |
| R-I1 | integration -> T-towns-core | dress overlay merge, hatch art, emblem, kit table | merged into T-towns-core (b1) |
| R-I2 | integration -> T-director | post_ground / door_ground + FestivalDecor hook | merged into T-director (b1) |
| R-I3 | integration -> N03 | S3TC import of the kit | merged into N03 (b1) |
| R-I4 | integration -> lead | merge the additions at wave boundaries (E2); one editor per file | E2; the per-file editors are listed in section 12.3 |
| R-I5 | integration -> lead | wave 4 = 65 and wave 5 = 63 points: stagger? | DT36 |
| R-I6 | integration -> lead | nine duplicate-key notices of design2's own additions files | design2's: its final_candidate/key_owners_additions.json is one file; this addendum's file adds none of them |
| RC1-RC15 | social -> siblings | calendar tab, people action, registry kind, files with several editors, festival closures, keeper greetings, weekly heart, P01 line, voice index, ui_screens.d, hero twins, farm post, package ids, waves | all resolved: C11, C12, DT19, section 12.3, DT25, T-greetings, P14 (RT24), C12, DT27, RT8, DT9, DT45, the package ids of section 9, DT36 |
| R-F1 | final editor -> lead | install an ownership tool that honours ownsRemove path exclusions; regenerate owners.json with the effective table | check_ownership.py --emit-effective, effective_owners.json and lead_tools/ownership.py in design3/FINAL (the lead installs them; the editor never writes impl/) |
| R-F2 | final editor -> design2 lead | V4 loses two dependency edges (D2, P19); DR1 / D2 / DQ guards compare with the P01 contract | RT29, RT36, RT37, RT28 task 2: amendments of design2 packages, proved defects, listed in section 11 (C37, C38) |

### 11.2 The editor's patches of the track texts (asserted operations in `build_final.py`)

* `patch` N02-farm-objects: F2 never called FarmReserve in any task (P20 reads it; after the final edit P06 does too, both late bound)
* `patch` N03-farm-art: texture-memory task replaced by the S3TC import (integration R-I3): 65.5 -> 15.8 MB, city peak 357.6 -> 307.9 MB
* `patch` N05-farm-dress: dress event flag is festival_now, refreshed on the two festival events
* `patch` T-routes: hero id source named: no package wrote the flag hero_id
* `patch` T-routes: routes.json regeneration is sanctioned edit E3
* `patch` T-director: two files called traetoppen.json: the sidecar is named apart
* `patch` T-qa: TOWNS.md points at L18 instead of a second proof
* `patch` S-core: NpcDirector binding form named
* `patch` S-core: `away:<npc>` kind added (needed by the dungeon hub marker)
* `patch` S-core: routine_changed (the hourly event of the towns director) refreshes at:/away: markers
* `patch` S-ui: event_overlay registry row moved to S-events' own file
* `patch` S-fest-content: festival posts: towns' single set marker wins; decor is I5's FestivalDecor
* `patch` I1-copy-system: the retired town name must not appear in docs/design copies
* `patch` I2-loop-harness: L18 extended by the building and routine-edit legs so T-qa and S-qa no longer carry their own copies
* `patch` I6-town-qa: row numbers moved from 22-30 to 31-39 (design2's matrix already uses 22-30)
* `patch` S-core: S-core writes the world flag festival_now that the farm map reads
* `patch` S-core: festival attendees: home area + seeded order + cap 15 (the social doc 7.8 and the towns' request; the task text said 'tier A/B friends sorted by id')
* `patch` T-routes: NpcDirector.controls: staging of the marker skip rule (waves 5-5b would otherwise have no NPC to talk to)
* `patch` T-towns-core: doors of unbuilt EXTENDED buildings stay clean locked nameplates
* `patch` T-routes: NpcDirector.post_ground for S-events (the city's posts live in the sidecar)
* `patch` S-events: event marks find posts through the facade
* `patch` S-events: festival activities find their posts through the facade
* `patch` T-director: T-director emits routine_changed (the contract named it, no task did)
* `patch` N02-farm-objects: FarmStage reads home_exterior_ready (F6 emits it for exactly this)
* `patch` N05-farm-dress: dress follows the two farm events
* `patch` I2-loop-harness: the loop harness records the game events its legs assert
* `patch` S-ui: the HUD names both festival events
* `patch` T-towns-core: SE1/PL11: ShopCounter gains the kinds talk, appraisal and desk; the unassigned forward_to_keeper seam and its 'giftable hotbar item' rule are removed
* `patch` T-towns-core: TE1/TE2: Hours gets its own clock-only now_ctx() and the towns.hours_enabled switch
* `patch` T-towns-core: TE1: Door2D reaches Routines only through Svc.static_call
* `patch` T-towns-core: TE10/TE1: the eviction waits for a running travel; ShopHours has no hard reference to Routines
* `patch` T-towns-core: SE1/SE2/TE7: five COUNTER_ prompts in towns.csv
* `patch` T-towns-core: TE2: towns.hours_enabled
* `patch` T-towns-core: TE7/PL1: no dangling shop id fru_ugle_vurdering; the two late ids are listed, not failed
* `patch` T-interiors-core: SE1/SE2: every counter band carries two talk markers; the builder yard a desk
* `patch` T-interiors-core: TE7/PL1: no shop id for Uglehulen
* `patch` T-interiors-core: TE7/PL1: Uglehulen is a service, its counter is kind appraisal
* `patch` T-routes: PL4: the marker collection and the post snap are T-routes' own statics (TownMarks), TownMarker (5b) only calls them
* `patch` T-routes: TE3: the bake needs no package of a later wave
* `patch` T-routes: TE1: NpcDirector tracks live directors as Objects (static registry), not through a cast to a later-wave class
* `patch` T-director: TE3/SE1: the city half of the director builds the doors and the stall counters from T-routes' sidecar
* `patch` S-core: TE1: SocialManager boots in wave 4 without GiftRules
* `patch` S-core: PL8: the bed hold is re-applied from state, never trusted to survive a load or a clear
* `patch` S-core: SE6/SE1: the balance claims are ranges, in two availability variants, with a ratchet
* `patch` S-gifts: SE4: the picker hides tools in use, the next tier's materials and incomplete set pieces
* `patch` S-fest-content: SE7/SE5: no festival promises to keep the Sunday-closed seed shop open; contest prizes respect SV14
* `patch` N02-farm-objects: PL4: FarmReserve has TWO consumers, both late bound
* `patch` N03-farm-art: TE9: N03 writes its own import stubs
* `patch` T-greetings: TE7/PL1: 11 shop ids, 61 rows
* `patch` N01-farm-map: PL3: N01's copy check lives in its own section
* `patch` T-towns-core: PL3: T-towns-core's copy lint check lives in its own section
* `patch` S-data: PL3: S-data's lint check lives in its own section
* `patch` S-data: PL3: S-data's review-status check lives in its own section
* `patch` T-director: SE1: TownDirector answers node_of and holds the live dictionary NpcDirector reads
* `patch` I2-loop-harness: SE1: TownProbe finds the counter hosts by kind
* `add` N01-farm-map: dress event flag renamed festival_today -> festival_now (social's world flag)
* `add` N04-farm-first-morning: Pip first meeting: the scripted farm scene and the social first-meeting line must not both introduce him
* `add` N07-farm-greenhouse: winter crops had no seller: a half-wired promise
* `add` T-towns-core: integration R-I1 merged: dressing overlay + hatch art
* `add` T-towns-core: integration R-I1 merged: emblem plates
* `add` T-towns-core: integration R-I1 merged: kit table re-split
* `add` T-director: integration R-I2 merged: accessors + FestivalDecor hook
* `add` T-qa: the towns' data-only proof is I2's L18
* `add` S-talk: citizens without a dialogue module could not be talked to
* `add` S-qa: the social data-only proof is I2's L18
* `add` I6-town-qa: four QA packages, one report per domain, one index
* `add` T-towns-core: SE1: the E-query replay of the counter band is a validator rule and a section check, so the geometry cannot drift
* `add` T-towns-core: TE1: forward class references of lifted prototypes (hours.gd:80,88; door_2d.gd:37,40,42; shop_hours.gd:43,62,77) are a check, not a hope
* `add` T-routes: TE3: the city sidecar and LevelNav belong to the package that bakes the routes
* `add` T-routes: TE1: forward class references
* `add` T-director: TE1: forward class references
* `add` S-core: PL3: three checks of the F1 / P10 fix-round live in S-core's own section, where the manager exists
* `add` S-gifts: SE4: the confirm predicate is data of S-gifts
* `drop` T-qa: the data-only extension proof lives ONCE, in I2's leg L18 (citizen, building, routine edit, shop hours, festival, event, quest); zz_towns re-runs those legs, it does not duplicate them
* `drop` S-qa: the social data-only proof (citizen, festival, event) is I2's L18; zz_social re-runs those legs
* `dep` T-routes depends on N01-farm-map (the route bake builds farm.map)
* `dep` T-director depends on N01-farm-map (the farm director and its windowed shot need the farm map's `town` and `post` markers)
* `dep` T-routes depends on V3-levels (LevelNav plans over V3's levels_graph() (RT21): the city can be baked in THIS wave)
* `dep` T-director depends on DR7-dungeon-services (the stall shop id natteblik_maps is DR7's; towns_director.stall_shop_ids_resolve is REQUIRED here)
* `dep` S-marriage depends on T-routes (the partner overlay of hours.keeper_covers_hours and RouteTable.seconds)
* `dep` I2-loop-harness depends on D0-dungeon-world-hooks (leg L11 needs the pass-out wake at farm:from_home (RT22))
* `owns` N07-farm-greenhouse owns lua/shops/greenhouse_seeds.lua (the winter seeds are sold at the greenhouse door by its own shop def (carve-out of P12's lua/shops glob), no opening hours)
* `owns` S-ui owns docs/qa/ui_baseline/people.png (baseline pins of the screens it builds (design_ui repair))
* `owns` S-ui owns docs/qa/ui_baseline/gift.png
* `owns` S-ui owns docs/qa/ui_baseline/calendar.png
* `owns` S-ui owns docs/qa/ui_baseline/social_hud.png
* `owns` S-events owns tests/lib/ui_screens.d/social_events.json (the event_overlay registry row gets its own file: one file, one owner)
* `owns` S-events owns docs/qa/ui_baseline/event_overlay.png
* `owns` T-post-office owns docs/qa/ui_baseline/post.png
* `owns` T-routes owns scripts/towns/level_nav.gd (moved from T-director: the route table needs the city planner in wave 5, not 5b)
* `owns` T-routes owns data/towns/traetoppen.json (moved from T-director: the city sidecar (doors, 36 posts, gates, fest spots, stall counters) is an input of the bake)
* `owns` T-routes owns scripts/towns/town_marks.gd (PL4: the two pure marker functions the bake needs (collect, resolve_cells), lifted from the prototype's town_marker.gd)
* `field` N08-farm-qa.dependsOn: QA package: hard dependencies on the farm CORE only
* `field` T-qa.dependsOn: QA package: hard dependencies on the CORE towns packages + the loop harness whose L18 legs carry the data-only proof
* `field` S-qa.dependsOn: QA package: hard dependencies on the CORE social packages + the loop harness
* `field` I6-town-qa.dependsOn: QA package: hard dependencies on the CORE packages of the loop
* `field` S-heart-content.size: SE6: 40 scenes and about 320 CSV rows instead of 20 and 180

### 11.3 The final edit (2026-10-14): the defects of four adversarial reviews and where each was repaired

Four adversarial reviewers (lenses: social / economy, technical, plan) found 30 defects with evidence; every one is repaired in place, the full text with the evidence and the places is `CHANGELOG.md`, the probes and simulations are under `design3/final_editor/`. Ids: SE social / economy, TE technical, PL plan.

| Id | Sev | Defect | Resolution | Where |
|---|---|---|---|---|
| SE1 | major | The keeper cannot be talked to inside any walk-in shop: the seam ShopCounter.forward_to_keeper is declared and assigned by nobody, the built E-query always lets the counter win over the keeper (0 of 576 samples select the keeper), and the one rule written for the seam ('a giftable hotbar item takes E first') would make the sh... | The rule and the seam are REMOVED. Every counter band has three kinds of host: the centre host of its service and two `talk` hosts (ellipse 40 x 22) on the customer cells in front of the counter ENDS; E decides by where the player stands (middle cell = panel, end cell = the keeper's own Npc2D.interact: greeting, hearts, gifts, topics, quests). A talk host stays disabled until a keeper node exists. The two stalls get the same trio from `counters` rows of the city sidecar; I2 gains legs l03b and l06b; the balance... | T-towns-core (shop_counter.gd task rewritten, E-query replay task, counter band, COUNTER_ prompts), T-interiors-core (14 rooms carry the markers; keeper_reachable_from_counter_front), T-routes (sid... |
| SE2 | major | The only entry to the 10-step home ladder (74,000 g) and its 'upgrade finished' celebration is Tømrerfe Hasselnød's dialogue, and the candidate put her behind the counter of a shop that opens 08-16 where E opens only the materials panel; no package, leg or acceptance row covered the ladder's entry. | Covered by the `talk` hosts (her dialogue already has the `upgrade` and `materials` choices) and by a `desk` host (game_event open_home_builder {tier}) at cell m+2 of int_toemmerhandlen: the second door of the Husbyggeri, so the ladder never depends on a conversation. Leg l06c (Monday 12:00, enter the yard, E at the talk cell or the desk) and the `bridge` hint of the first days names the builder. | T-towns-core (desk kind), T-interiors-core (desk marker, builder_desk_is_a_second_door), I2 (l06c), N04 (bridge hint copy); DT53; acceptance row 37 |
| SE3 | minor | A partner who is also a keeper stands in the farmhouse until 08:00 and then walks back, so the shop opens unstaffed (Maja 115 minutes, Kløvermynte 67, Brumme 59). | The farmhouse morning ends at a computed leave time = opens - RouteTable.seconds(farm.porch, work_door) x 2 / 60 - 5 minutes; a partner whose leave is before 06:15 has no morning there (Maja); hours.keeper_covers_hours runs with a partner overlay for each of the 11 candidates (social_marriage.partner_keeps_shop_staffed). S-marriage depends on T-routes for it. | S-marriage T3, ADDENDUM 5.4; DT61 |
| SE4 | minor | One press of 'Giv' hands over any non-protected item without a confirm: all 12 tools, 56 rare items (sell 34-1,670 g) and all 26 building materials were giftable for at most 60 points. | S-gifts hides tools in the hotbar, the last copy of any tool, the next home tier's materials and the pieces of a wardrobe set whose capstone is open (late bound reads of F2 / F4; F4 gains LootService.set_capstone_granted); GiftRules.needs_confirm marks tools, rarity rare and sell value >= 100 g; S-ui's picker opens UiConfirm (default Fortryd) for them. | S-gifts (T1 + needs_confirm task), S-ui (T2, rel_ui rows), RT19 (F4 read); DT60 |
| SE5 | minor | The contest reward had no value cap and the winning entry is cheap: five contests a year could pay up to 5 x 1,670 g. | SocialValidator rule SV14: first <= min(2 x the cheapest winning entry, 400 g), second <= 0.7 x first, third <= 0.4 x first, no keepsake, rarity <= rare; S-events refuses an over-cap reward; S-fest-content checks its prizes against the loot tables. | S-core T14, S-events T3, S-fest-content T0; DT61 |
| SE6 | minor | Friendship saturates before the main game ends (a typical player has seen all 20 LEAN heart events by day 97 and has 14 of 30 citizens at 10 hearts after a game year), and the balance test passed with a 3-day margin. | S-heart-content builds 40 scenes (4 / 6 / 8 / 10 hearts for the 10 tier A citizens, size M -> L); social.balance_claims_hold asserts ranges (median <= 80, p90 <= 115 with LEAN events, <= 110 with four) in a `free` and a `mixed` availability variant with a ratchet file. DECLINED: the year-2 hook (a new birthday card per year) stays roadmap (risk RK16). | S-heart-content, S-core T15, ADDENDUM 5.5; DT62 |
| SE7 | minor | Blomsterfesten (day 7) and Høstfesten (day 70) list seed_shop in stays_open but are Sundays and the seed shop is closed on Sundays. | seed_shop is dropped from both festivals' stays_open (their own seed stall and harvest market sell); S-fest-content gains social_fest_content.stays_open_is_possible_on_the_festival_weekday. No per-festival opening override is added to Hours. | S-fest-content T0, ADDENDUM 5.3; DT61 |
| SE8 | minor | The seed shop restocks at most 20 carrot seeds a day and is closed on Sundays: a dedicated 110-plot field is 2.1 seeds a day short (-4.8 % income). | carrot_seeds stock = 25, restock = 25 in lua/shops/seed_shop.lua (RT5, one number); the pin economy.shop_save_validated follows in DL1's amendment RT35; supply 6 x 25 = 150 a week = 21.4 a day against 19.2 needed. | RT5 task 3, RT35; DT61 |
| TE1 | major | Prototypes the packages lift name class_names that a LATER wave builds: hours.gd, door_2d.gd and shop_hours.gd call Routines (wave 5) in wave 4; npc_director.gd casts to TownDirector (5b) in wave 5; social_manager.gd names GiftRules (wave 5) in wave 4 so the autoload fails to boot. | Lifted code is EDITED: Hours has its own clock-only now_ctx(); Door2D and ShopHours reach Routines only through Svc.static_call with a safe default; NpcDirector tracks live directors as Objects in its static registry (no cast); SocialManager reaches GiftRules only through Svc.static_call. Four checks `no_forward_class_refs` (towns_data, towns_routes, towns_director, social) scan the package's own scripts; towns_data also loads its scripts without the later files. | T-towns-core, T-routes, T-director, S-core (tasks and lift lines); DT54 |
| TE2 | major | RT5 (the hours hook in P12) and the wave-4 buildings registry break 25 built P12 checks (all 9 shops are closed at the new-game clock) and the pin economy.late_binding_via_svc (a third static_call line); no task amends tests/sections/economy.gd. | The hook is a helper file scripts/economy/shop_hours_gate.gd, so shop_system.gd keeps two `static_call(` lines; config towns.hours_enabled (default true) turns the rule off; economy.gd's _fresh() sets it off in DL1's amendment RT35 (design2 gave economy.gd to DL1, so P12's fix-round must not edit it); the new checks live in P12's new section economy_hours; the clock every section runs at is stated once (DT55). This differs from the reviewer's wording (a task of RT5 on economy.gd) only because of the ownership of... | RT5, RT35, T-towns-core (T0, T2, T6); DT55; ADDENDUM 4.5 |
| TE3 | major | T-routes' wave-5 acceptance (towns_routines >= 150, 9 PASS validators) cannot be met: 18 of 23 CORE routines place citizens in Trætoppen, but the city sidecar and LevelNav are T-director's (wave 5b); no pending-area rule; the 14 rooms are same-wave data of T-interiors-core. | Options (a) and (b) of the reviewer combined: the city sidecar data/towns/traetoppen.json and scripts/towns/level_nav.gd MOVE to T-routes (which gains the dependency V3-levels for levels_graph()), so the route table bakes the city in wave 5; T-director builds doors and stall counters from it; TownsValidate.PENDING_AREAS lists an unbuilt room by name as SKIP and the wave-5 gate requires the list empty. | T-routes (owns, deps, T5, T6, T8, sidecar task), T-director (owns, T6); DT56; ADDENDUM 4.9, 9.3 |
| TE4 | major | The loop digest is not stable over wall-clock time: SaveManager.gather_payload writes /meta/saved_at and /meta/timestamp from the real clock, and a check enshrined 'exactly two volatile paths'. | digest_volatile.json lists /game/play_time_seconds, /meta/saved_at, /meta/timestamp and /meta/summary; the self-check asserts exactly those paths; town_loop.digest_stable_over_wall_clock compares two digests 1.1 s apart while +1 gold and a flag still move the digest. | I2 T2, ADDENDUM 6.1 / 6.3; DT63 |
| TE5 | minor | Adding farm.map makes `farm` the default start area and two built P04 checks (area.farmable_cells, area.spawns_parsed) that assume the 12 x 12 fixture fail; no package owns tests/sections/area.gd. | RT6 (P04, a fix-round) gains a task: the fixture-bound checks enter _fixture_iso explicitly and re-enter the start area afterwards; N01's task names it. | RT6 task 2, N01 T12 |
| TE6 | minor | RT7 adds five ids to GameUI.SCREEN_ORDER but the built pins (ui_foundation.gd:730, ui_smoke.gd:389: size 16) break. | RT7 now lists the new order (21 ids; order[0] == hud, order[1] == forest_hud, order[-3] == pause_menu hold) and updates both pins to follow the list. | RT7; ADDENDUM 8.10 |
| TE7 | minor | `fru_ugle_vurdering` is a dangling shop id (design2's retired DX7 draft; design2's final candidate gives Fru Ugle no ShopSystem shop): towns_data.shop_ids_exist could not pass, her counter was inert, 6 KEEP_ rows were dead. | Uglehulen is a service row without a shop id; the centre host of its room is kind `appraisal` (game_event open_appraisal, refused while closed, a whisper until DL7); the id is removed from the buildings row, the room wiring, T-greetings (11 shop ids, 61 rows) and section 8.12; towns_data treats timber_yard and natteblik_maps (both wave 4) as late ids listed by name. | T-towns-core T1 / T14, T-interiors-core T2, T-greetings T0, ADDENDUM 4.1 / 4.6 / 8.12; DT59; conflict C39 |
| TE8 | minor | RT3 renames check ids but tests/tools/mutation_check.py pins the old id and appends exactly five autoloads. | RT3 lists mutation_check.py (new id, FEATURE_LINES gains SocialManager, a mutant for a sixth line) and runs it at the FR-4 gate. | RT3 task 1 |
| TE9 | minor | N03's S3TC import stubs are 'written by tools/import/write_import_stubs.py', which does not cover assets/iso_props/** and assets/backdrops/**: the kit would stay lossless (65.5 MB, city peak 357.6 MB). | N03 ships the stubs itself from tools/art/environment/farm/write_farm_imports.py (the same minimal stub as the character sheets); art_farm.s3tc_import_set stays the guard. | N03 T5 |
| TE10 | minor | ShopHours' eviction does not wait for a running travel although its comment says so, so a closing tick inside the fade of entering the room leaves the player in a closed shop. | _evict() waits (without setting `evicted`) while WorldRoot2D.traveling or a sleep sequence runs; check towns_interiors.closing_waits_for_travel. | T-towns-core T15 |
| TE11 | minor | design2's guard checks (DR1 task 10, D2 task 8, DQ E9) hard-code '11 + 5 autoloads, 35 actions, 75 signals' while this addendum adds the sixth autoload and the 36th action. | The guards compare with the P01 / P02 contracts and assert 'this package adds none' (amendments RT36 for DR1, a task of RT28 for D2, RT37 for DQ); conflict C38. | RT28, RT36, RT37 |
| PL1 | major | Uglehulen is wired to the shop id fru_ugle_vurdering that no package creates and design2's final addendum declares non-existent. | Same resolution as TE7 (service, counter kind `appraisal`, id removed everywhere, one check that the appraisal request is refused while the building is closed). | see TE7 |
| PL2 | major | G5b (the first playable town loop) is hard-coupled to five dungeon-track packages through V4.dependsOn (D2, P19): closure of 52 packages incl. D1, D2, DR0, DR1, P19 (12 points); the critical-path text omitted it. | RT29 removes D2 and P19 from V4's hard dependencies (P19 soft; checker `addSoftDependsOn`), V4's two chain checks SKIP and become DQ's E1 / E2 (RT37); D0 (I2 depends on it: pass-out wake) and DR7 (T-director depends on it: natteblik_maps) stay; checker section I fails on any other dungeon-track package in the closure (49 packages, 34 unbuilt); 9.2 gains the closure text and a sequencing rule. | RT29, RT37, I2 / T-director deps, checker I, ADDENDUM 9.2; DT57; conflict C37 |
| PL3 | major | Fix-round tasks of BUILT packages write new checks into sections that the layered table gives to wave 4-5 packages (data.gd, loc.gd, economy.gd V1 / DL1, content_features.gd DL4) and name sections of later waves: 21 task / check pairs. | Each fix-round amendment has its own section (RT4 data_registry, RT5 economy_hours, RT9 loc_towns; P26 loc_final) or keeps an existing check green; RT2 builds its pristine project inside the tool and leaves content_features.gd alone; the social.* checks of RT2 / RT4 are S-core's; RT8's merge check is in P09's ui_audit section; names of later sections are removed (proven at their own gate). Checker section J fails on any such name. | RT2, RT4, RT5, RT8, RT9, RT12, RT19, RT22, RT28, RT33, S-core; DT58 |
| PL4 | major | Two contracts are used one wave before their owner: T-routes (5) names TownMarker.resolve_cells (T-director, 5b); RT11 (P06, 4) makes tool use refuse FarmReserve cells (class of N02, 5). | The marker collection and the post snap are TownMarks.collect / resolve_cells, statics of a new T-routes file (the bake tool needs both) that TownMarker calls; P06 reaches FarmReserve only through Svc.static_call with a fake-injected check and an absent class means 'nothing reserved'; N02's text and section 3.4 say FarmReserve has two consumers. | T-routes T5, T-director T0, RT11 task 5, N02 |
| PL5 | minor | design_integration.md still contains the retired town name twice and RT3 copies it into docs/design. | The two occurrences are replaced; build_final.py now asserts that none of the four track documents contains the name. | design_integration.md, build_final.py |
| PL6 | minor | RT7 does not update the two pins on the screen list. | See TE6. | RT7 |
| PL7 | minor | G4 requires every L10 check at the wave-5 gate although the merged L10 includes N04-dependent checks (wave 5b). | L10 is split: l10_seeds_from_shop, l10_till_plant_water, l10_energy_costs are G4; l10_forste_dage_objectives and l10_hint_once_per_save are G5b. | I2 T7, ADDENDUM 6.2 / 6.3 |
| PL8 | minor | Production code relies on GameManager.set_config_override (a never-saved test seam wiped by clear_config_overrides()) for the festival bed hold. | The hold is re-applied from the state query on every flush, load, area change and festival event; check social.festival_bed_hold_survives_load_and_clear. | S-core T9, DT25 |
| PL9 | minor | The disjointness proof is valid only under path-exclusion semantics of ownsRemove, which impl/tools/ownership.py does not implement (67 of 69 d3 ownsRemove entries need exclusion). | check_ownership.py corrects its docstring, emits the effective owners table (`--emit-effective`, shipped as effective_owners.json) and a drop-in lead_tools/ownership.py honours exclusions. PARTLY: the editor may not write impl/; the lead installs the tool (request R-F1). | check_ownership.py, FINAL/effective_owners.json, FINAL/lead_tools/ownership.py; DT64 |
| PL10 | minor | Requirement 4 says every shop and service is also a walk-in room; the two stalls have outdoor counters only (an exception listed nowhere). | Listed in DT38 and asked as Q7 (default: the sketch's own form); the stalls get the same talk hosts; honest stub 'Two stalls without a room'. | DT38, Q7, stubs |
| PL11 | major | (The text of this defect was cut off in the brief.) E at a shop counter either opens the panel or is 'forwarded to the keeper'; no package implements the keeper side; the hotbar rule contradicts the stub 'no hotbar quick gift'; six of the ten tier A citizens are keepers. | Resolved together with SE1: the seam and the hotbar rule are removed, the keeper side is the `talk` host; gifts stay in the talk menu. | see SE1 |

---------------------------------------------------------------------------------------------------------------------------------------------

## 12. Amendments to existing packages (R-style list RT1-RT37)

One amendment per existing package: the 71 amendments of the four tracks (104 tasks) are merged into 34 (RT1-RT34, duplicates collapsed, contradictions resolved, ownership repaired) and the final edit appended three amendments of design2 packages (RT35-RT37): 37 amendments with 95 tasks in all. `built: true` = a task of a BUILT package (waves 1-3), executed by the lead as a fix-round **in the order RT1..RT9 before wave 4** (every one is harmless before its consumer exists: late binding). Everything else is an ordinary extra task of an unbuilt package. Full task text with `-> verify:` names: `packages.json` `amendments[]`.

| RT | Package | Wave | Built | Sources | Tasks | ownsAdd / ownsRemove / deps | What |
|---|---|---|---|---|---|---|---|
| **RT1** | P15-save-system | 3 | yes (FR-4) | social | 1 | - | the three registry tests detach the real sections while they assert the exact registered list (needed by EVERY feature autoload) |
| **RT2** | F1-feature-data | 3 | yes (FR-4) | social | 2 | - | add_autoload.py CONTRACT and its self-test gain SocialManager (the self-test builds pristine copies itself), FEATURE_NODES, Grant.set_hearts wrapper |
| **RT3** | P01-project-config | 1 | yes (FR-4) | social, integration | 3 | - | check_project six autoloads (+ mutation_check.py), the `people` action, docs copies + ONE new PLAN_2D.md header line (no pin change) |
| **RT4** | P10-data-contracts | 2 | yes (FR-4) | towns, social | 2 | +1 owns | the `registry` Lua kind (lint + runtime) and the four social api functions; one editor of lua_runtime.gd; own section data_registry |
| **RT5** | P12-economy-shop-crafting | 3 | yes (FR-4) | towns, social | 3 | +1 owns; -3 owns | ShopHoursGate helper (is_open asks Hours.shop_open late bound, no third static_call line), closed_reason / opens_at, towns.hours_enabled, seed stock 25; own section economy_hours; ownsRemove of 3 new files |
| **RT6** | P04-area-framework | 3 | yes (FR-4) | social | 2 | - | IsoArea.evaluate_when delegates new kinds to SocialManager.eval_when; an unknown kind is a map error; area.gd's fixture checks no longer assume the fixture is the start area |
| **RT7** | P07-ui-foundation | 3 | yes (FR-4) | towns, social, ui-repair | 1 | -21 owns | SCREEN_ORDER gains 5 ids and the two built pins follow (21 ids); REPAIR: ownsRemove of the 21 paths design_ui gave to P28 / P17 / P14 |
| **RT8** | P09-test-harness | 1 | yes (FR-4) | integration, towns, social, editor | 2 | +1 owns; -6 owns | `--fast`, UiAudit merges tests/lib/ui_screens.d/*.json (checked in P09's ui_audit section); carve-outs by exact file; owns docs/DEVELOPMENT.md |
| **RT9** | P03-loc-core | 2 | yes (FR-4) | integration | 1 | +1 owns | E2: the lead merges key_owners_additions.json at each wave start; own section loc_towns |
| **RT10** | P28-ui-nav-foundation | 3b | no | social | 1 | - | three calendar theme variations in build_theme.gd |
| **RT11** | P06-player-farm-core | 4 | no | farm, social | 7 (+conditional) | - | unlock_cells from the marker grammar, field_grass, plot_tilled / crop_ready events, FARM_CELL_RESERVED, Player2D event API, water_unwatered; CONDITIONAL greenhouse tasks |
| **RT12** | P11-maps-iso | 4 | no | farm, towns | 3 | -1 owns | farm.map carved out to N01; hyggebyen.map carries the town / door / post markers and ONE fest set marker |
| **RT13** | P13-quests-lua-runtime | 4 | no | farm, social | 4 | -1 owns | forste_dage.lua carved out; friendship rewards through SocialManager; item_in_use; friend_hearts_at_least; payload filter and social objective sugar |
| **RT14** | P16-ui-menus | 4 | no | social | 1 | - | pause row 'Folk' |
| **RT15** | P18-ui-shop-inventory | 4 | no | towns, social | 1 | - | closed state, close request, greeting from SocialTalk, optional KEEP_ANY_* lines |
| **RT16** | P22-art-environment | 4 | no | farm, integration | 3 | -13 owns | 13 carve-outs (farm, shops, festival art), 7 contract props, 16 props_extra rows |
| **RT17** | P23-art-icons-keyart | 4 | no | social | 1 | - | two item icons (badge fallback) |
| **RT18** | F2-home-core | 4 | no | farm, social | 2 | - | home_tier flag always correct; guests_today(), visitor gift from a friend, house party (late bound) |
| **RT19** | F4-loot-shops | 4 | no | farm, towns, social, editor | 4 | - | marker_handlers.lua rows (11 types: 6 farm, town / door / post, bath, board); check_friend_gifts public + idempotent; PriceCurve reads the keeper's hearts; set_capstone_granted read |
| **RT20** | V1-cast-data | 4 | no | farm, towns, integration | 4 | - | Pip offers forste_dage; 8 new roster rows (friendship, routine = true on all 30); roster pins opened for data-only citizens |
| **RT21** | V3-levels | 4 | no | towns | 1 | - | levels_graph() read API for LevelNav |
| **RT22** | D0-dungeon-world-hooks | 4 | no | integration, editor | 2 | - | warm-clips rule R-V4 (walkers warm walk); the 24:00 pass-out wakes at farm:from_home |
| **RT23** | P17-ui-hud | 4 | no | towns | 1 | - | whisper accepts a formatted string; area banner takes BLD_ titles |
| **RT24** | P14-npc-dialogue | 5 | no | farm, towns, social, integration | 9 | -1 owns; dep S-core | ONE ordered list of 9 tasks: on_conversation_finished, tutorial runner, social context + decorate, no-module citizens, action fall-through, driven interface, event API / bubbles / guest mode, temporary instance, journal calendar tab |
| **RT25** | P20-animals-buildings | 5 | no | farm | 3 | dep N01-farm-map | slot footprints, FarmReserve in PlacementService, yard radius 3 |
| **RT26** | F6-home-world | 5 | no | farm, social | 3 | dep N01-farm-map | anchor contract, home_exterior_ready, guests in the room |
| **RT27** | V6-city-life | 5 | no | farm, towns | 2 | - | mailbox prop= and day-1 empty / post_read once per day; handlers usable inside rooms |
| **RT28** | D2-dungeon-floors | 5 | no | towns | 2 | - | Fru Ugle's hub marker `when=away:appraiser_fru_ugle`; the contract guard compares with the P01 contract |
| **RT29** | V4-city-map | 5b | no | towns | 2 | - | city_builder calls city_town.attach; no board / bath markers in the city; sidecar holds the festival sets; NO dependency on D2 / P19 (soft P19), chain checks to DQ |
| **RT30** | F7-home-ui | 5b | no | farm | 1 | - | the Hjemkiste opens on open_home_chest from any area |
| **RT31** | P24-audio-voice | 6 | no | integration, social, towns, farm | 11 | +5 owns | AudioDirector, cue log, surfaces, synth tools, voice presets, the _V index, the hooks of all four tracks (L) |
| **RT32** | P25-docs-refresh | 6 | no | integration, social, towns | 2 | - | ONE merged how-to set tested in a temp project; README controls generated from the InputMap |
| **RT33** | P26-loc-final | 6 | no | integration, social, towns, farm | 3 | +1 owns | scope of the copy pass over the new CSVs, voiced rows untouched, strict green; own section loc_final |
| **RT34** | P27-qa-acceptance | 7 | no | farm, towns, social, integration, ui-repair | 1 | -23 owns | carve-outs docs/qa/{farm,towns,social,town}/** and 19 exact baseline PNGs; acceptance includes the new sections |
| **RT35** | DL1-econ-store | 4 | no | final-editor | 2 | - | economy.gd's _fresh() runs with towns.hours_enabled = false; the carrot stock pin follows 20 -> 25 (design2 package, RT35) |
| **RT36** | DR1-rules | 4 | no | final-editor | 1 | - | the contract guard compares with the P01 contract, not with the literals 11 + 5 / 35 / 75 (design2 package, RT36) |
| **RT37** | DQ-dungeon-acceptance | 7 | no | final-editor | 1 | - | E9 compares with the P01 contract; E1 / E2 are the chain checks V4 dropped (design2 package, RT37) |

### 12.1 Files with several editors: ONE owner, ONE ordered task list

| File | Owner | Tracks that edit it | Resolution |
|---|---|---|---|
| `scripts/world2d/npc_2d.gd`, `intro_sequence.gd`, `dialogue_ui.gd`, `quest_journal.gd` | P14 | design2, design_ui, farm, towns, social, integration | RT24 (one list; size XL; the carve-out of `_voiced_social.lua` goes to P24) |
| `scripts/autoload/lua_runtime.gd`, `scripts/data/lua_lint.gd` | P10 | towns (registry), social (api) | RT4: registry first |
| `scripts/world2d/iso_area.gd` | P04 | social (when= delegate) | RT6; the towns and the farm need no edit |
| `scripts/world2d/world_2d.gd` | D0 (carved from P04 by design2) | design2, integration (warm clips), editor (pass-out wake) | RT22; the towns need nothing else (DT24, DT50) |
| `lua/config/marker_handlers.lua` | F4 | farm (6), towns (3), design2, V6 | RT19: additive rows |
| `scripts/ui/game_ui.gd` | P07 | social, towns | RT7: one task, 5 ids |
| `tests/lib/ui_audit.gd` | P09 | integration (directory merge), design_ui | RT8 |
| `scripts/autoload/audio_manager.gd`, `tools/voice/**` | P24 | integration, social, towns, farm, design2 (dungeon cues) | RT31 (size L; seam written down) |
| `tools/loc/key_owners.json` | P03 | every track's additions | E2 / RT9 |
| `lua/config/props_extra.lua` | P22 | farm (16 rows), design2 | RT16 |
| `docs/howto/**`, `docs/lua_api.md`, `README.md` | P25 | integration, social, towns | RT32 (one how-to set) |
| `localization/zz_final.csv` | P26 | all copy | RT33 (never a voiced key) |
| `localization/ui.csv` | P14 (moved from P07 by the repair) | design_ui | RT7 / design_ui's P14 task |
| `project.godot` `[autoload]`, `[input]` | E1 tool / P01 | social, integration | RT2, RT3 |

### 12.2 Conditional amendments (decision-gated)

RT11 (P06) carries ONE conditional task: the `indoor` cell flag and the `crops_extra` merge, which exist only if the lead activates N07 after a yes to Q1. P12's `ownsRemove` of `lua/shops/greenhouse_seeds.lua` is data only (the file exists only with N07). With no greenhouse nothing of it is built and nothing depends on it.

---------------------------------------------------------------------------------------------------------------------------------------------

## 13. Acceptance matrix (rows 31-51; design2 owns rows 11 and 22-30)

| Row | Requirement | Section / checks | Owners |
|---|---|---|---|
| 31 | NEW GAME on the treetop farm: Pip at the mailbox, Fekongens letter, the quest 'Gårdens første dage', ten whisper hints, control returns | farm_first_morning + maps_farm + town_loop.l00_* | N01, N02, N04, P14, I2 |
| 32 | the hanging bridge leads to a POPULATED Trætoppen (citizens placed by routine, cap 16 looks, freed on exit) | town_loop.l01_*, l02_*; towns_director; towns_city | N01, V4, T-routes, T-director, I2 |
| 33 | talk to a citizen (and to a keeper behind his counter, from the end cells): first meeting, the weekly heart once, Esc after the first line gives none, the People book shows it | town_loop.l03_*, l03b_*; social; social_ui | S-core, S-talk, S-ui, P14, I2 |
| 34 | a WALK-IN shop: door by the clock, keeper behind the counter and reachable from the two end cells (the middle cell opens the panel), counter is a barrier, closing warning and eviction, the panel of guide section 07 over the live room | town_loop.l04_*, l05_*, l06_*, l06b_*; towns_interiors*; towns_interiors_core.keeper_reachable_from_counter_front; shop_ui | T-towns-core, T-interiors-core, P18, I2 |
| 35 | gifts by taste: 40 / 20 / 8 / 0 / 0, one per day and two per week, birthday x4, quest items refused | town_loop.l07_*; social_gifts | S-gifts, S-ui, I2 |
| 36 | the post office interior: Pip behind the counter, the letter of the day, one per day, 'Hvor er ...?' (wave 6) | town_loop.l08_*; towns_post | T-interiors-core, V6, T-post-office, I2 |
| 37 | farm work + sleep + the next day: citizens elsewhere by routine, Pip at the farm mailbox from day 2, Hoppe on Wednesdays; the home ladder is reachable without a conversation (Hasselnød's desk) | town_loop.l10_* l11_* l12_*, l06c_* | P06, N02, T-routes, T-director, I2 |
| 38 | save -> load -> the same state (digest), old saves without `social` keep their hearts | town_loop.l13_*; save; social | P15, S-core, I2 |
| 39 | DATA-ONLY extension: a citizen, a walk-in shop, a routine edit, shop hours, a festival, a heart event, a quest, with zero .gd / .tscn changed | town_loop.l18_*; zz_towns; zz_social | I2, T-qa, S-qa |
| 40 | friendship: 0-10 whole hearts, 100 points, the weekly chat is the floor (8 hearts by day 50 for a citizen talked to every week), stages, no decay | social; zz_social.year_walk_hearts_in_band | S-core, S-qa |
| 41 | birthdays (30 distinct days, never on or beside a festival) and the Kalender tab of the journal | social.birthdays; social_ui; zz_social.every_birthday_once | S-core, S-data, S-ui |
| 42 | nine town festivals + the wedding: closed shops by data, the bed held until the end, citizens on the standard 24-post set, six activities, decor | social_events; social_fest_content; towns_director.festival_day_fixture; art_festival | S-events, S-fest-content, T-director, I5 |
| 43 | heart events: started by the player ('Hvad har du på hjerte?'), run once, skip pays rewards once | social_events; social_heart_content | S-events, S-heart-content |
| 44 | marriage-style relationships: bedste ven -> hjertven -> forlovet -> gift, no gender gate, no break-up, partner in the farmhouse mornings and evenings | social_marriage; zz_social | S-marriage, F2, F6 |
| 45 | the farm grows with the ten house tiers (five stages), the field expansion costs 800 g through a confirm, the shipping bin pays next morning at the seed shop's price | maps_farm; farm_site; farm_dress | N01, N02, N05, F6 |
| 46 | all 30 citizens exist (the v2 cast + the 36-character roster) and every one has a routine; hero twins are absent while the player is that hero | towns_routines; towns_ext; cast_data | V1, T-routes, T-ext-content |
| 47 | every labelled element of the city sketch has a place (seven trees, Torvet, Rådhuset on the middle tree with its ladder, post office, Hoppe's hut, Brumme's workshop, the bathhouse, kitchen gardens, rope bridges, owl holes, bat houses) | zz_v2.sketch_coverage_complete; towns_city.door_coords_match_city_json | V4, V5, T-director, T-interiors-core |
| 48 | all player-facing copy is Danish with a complete English column; no raw keys; review states honest; the voice policy holds | copy_rules; loc_check --strict; voice; town_loop.l17_* | I1, P26, P24 |
| 49 | audio hooks exist (shop bell, footsteps by surface, ambience by area and night, festival music) and a missing file is silent | audio_town; town_loop.l16_* | P24, I2 |
| 50 | budgets: process VRAM <= 400 MB (city peak 307.9 MB with the S3TC farm kit), farm frame <= 8 ms / <= 560 draw calls, citizens <= 0.4 ms, save <= 60 KB | town_budgets; zz_farm; zz_town.perf_within_budget | I2, N08, I6 |
| 51 | every new screen follows the guide and the navigation spec: initial focus, neighbours, Esc depth, a guide-compare baseline, the 9 standard checks | ui_conformance rows people gift calendar social_hud event_overlay post | S-ui, S-events, T-post-office, P28 |

Every CORE leg is required from its gate on (`TOWN_LOOP_WAVE`); the windowed checks (L15, the shots) are looked at by the lead before they are pinned; headless numbers carry no GPU and no audio output.

---------------------------------------------------------------------------------------------------------------------------------------------

## 14. Honest stubs and risks

### 14.1 Stubs (each has a minimal playable behaviour and a named check that keeps it honest)

| Item | Stub | What the player gets |
|---|---|---|
| Sitting | a standing pose: the NPC sheets have no sit clip | citizens stand at benches, tables and seats |
| Interior pieces before I3 | 15-16 pieces are existing furniture drawn as something else, listed by towns_interiors.stand_ins_listed | rooms exist and work; I3 (wave 5b) removes the list: art_shops.core_rooms_stand_in_free |
| Room dressing before I4 | no overlays | rooms a little plain |
| Festival decor, music, ambience, footsteps | I5 and P24 placeholders; NPC footsteps are not played | plain city on festival days before wave 6; synthesised placeholders after |
| Voice | one TTS voice (Sara), 8 archetype presets, CORE lines only; the first-morning lines are unvoiced | voiced first meetings, key greetings, shop greetings, quest offers |
| Danish copy | AI-drafted until native_reviewed | readable, lint-clean, tone-checked |
| Hotbar quick gift | not built (needs a P06 use_tool branch) | gifts through the talk menu |
| Mail letters about birthdays and events | not built (city life owns MAIL_) | Kalender tab + HUD chip + bubble |
| Rain venue for festivals | none: festivals run in rain | citizens gather in the rain |
| Partner pose, children, anniversaries | stand / wander only; no children; a toast | the partner is in the room |
| Heart events | 2 per tier A citizen (4 and 8 hearts) in CORE-lean; five is the roadmap | 20 scenes for 10 citizens |
| Post screen and keeper greetings | wave 6 (T-post-office, T-greetings) | the post counter answers with the letter flow; the panel uses its own greeting key |
| Parcels | none | one letter per day |
| Fast travel | none | farm door to Hyggebyen gate about 20 s walking |
| Citizen homes | EXTENDED rooms, open from 1 heart | before wave 6 the owner is 'inside at the door' at night |
| The inn | sells nothing (no food economy exists) | a place to sit, listen, talk |
| Greenhouse | a gated proposal; winter earns nothing without it | a quiet winter: craft, mine, forest, town |
| Shipping bin | one stack per press, no screen | ships crops, products, forage |
| Scarecrow, pond | decoration | - |
| Pip's body before V2 | the pack hedgehog stands in | visible in the first morning |
| Tool shed | emits open_home_chest; the Hjemkiste opens from any area only from F7 (wave 5b) | a whisper once per save until then |
| Towns between waves 5 and 5b | the static `npc` marker NPCs of Hyggebyen talk and sell (DT47); doors, rooms and routines arrive with T-director (5b) | gate G5 uses the dialogue entry to the shop panel |
| Doors of unbuilt EXTENDED buildings | locked nameplates labelled BLD_<ID> (DT49) | 'Døren er låst.' |
| Portraits | one expression per character | mood is in the text |
| The city half of the director | proven on the design2 sketch, not on V4's real city (same wave 5b) | the two V4 checks are REQUIRED at G5b |
| Natteblik's two stands | see DT42 | - |
| Natteblik by day | his stand opens 20:00-23:30 (a bat), the only place he stands at a counter | a player who only plays in the daytime never befriends him; the evening player meets him at the bat window (talk cells work there) |
| Uglehulen before the appraisal screen (DL7) | the centre counter whispers COUNTER_APPRAISE_SOON while LootService has no appraise() | Fru Ugle's talk cells open her dialogue; the appraisal arrives with DL7 (wave 5b) |
| Two stalls without a room | Torvestanden and Natteblik-vinduet are outdoor counters (the sketch's own form); every other shop and service is a walk-in room | the keeper is reachable at the stall ends like at every counter; the question is Q7 |
| The year-2 hook of friendship | after 10 hearts gifts and chats pay nothing; four heart scenes per tier A citizen (4 / 6 / 8 / 10) exist, a new birthday card per year does not | the ladder is complete in about a game year; the roadmap adds the 2-heart scene and a yearly card |

### 14.2 Risks

| # | Risk | Evidence | Mitigation |
|---|---|---|---|
| RK1 | Waves 4 and 5 carry 65 and 62 points | 5.1 of the load table | stagger writers; deferral order DT36; S-core / T-towns-core / N01 cannot slide |
| RK2 | P14 is edited by six tracks (XL) | RT24 | one ordered list; the seam for moving tasks 3 and 7 is written down |
| RK3 | P24 carries voice + audio + synth + presets + index | RT31 | seam: AudioDirector side vs voice side; wave 6 has 28 points |
| RK4 | VRAM headroom: 42 MB at the city peak without the S3TC import, 92 MB with it | design_integration 5.6 (measured) | N03 task, cap 16 looks, free-on-exit rules as checks, the fallback ladder |
| RK5 | Static caches never free | ArtCatalog | builders use instance dictionaries: town_budgets.builders_use_instance_caches |
| RK6 | The city half of the director is proven on the sketch only | design_towns 11.2 | REQUIRED at G5b once V4 lands; LevelNav reads V3's levels_graph() API |
| RK7 | The loop is written before its producers | design_integration R2 | ONE adapter (TownProbe), capability guards, TOWN_LOOP_WAVE gates that FAIL on a skipped required leg |
| RK8 | Review debt: C1 about 26 h and C2 about 27 h of native review (assumption 400 words/h) | design_integration 4.1 | states, queue, voice only for ai_reviewed rows; the user decides when (Q5) |
| RK9 | One TTS voice for 30 characters | designers 2 and 5 | 8 presets + jitter; the listening test (Q4) before the bulk bake |
| RK10 | The autoload contract is closed at five names in three files | design_social F-c | RT1 to RT3 land BEFORE add_autoload.py SocialManager (task order of S-core) |
| RK11 | Pre-existing overlaps in design_ui would have re-opened the ownership table | check_ownership.py | repaired in RT7 / RT34; the checker is part of every wave gate |
| RK12 | The Hyggebyen / city maps are other packages' files: the post and door names are a contract | design_towns | tools/towns/validate_towns.gd (9 rules, 11 mutants) fails on a missing post |
| RK13 | Headless cannot see or hear | - | cue log + windowed shots looked at by the lead (I2 L15, I6) |
| RK14 | Old saves without `social` | design_social | reset() re-seeds from the flags; town_loop.l13_old_save_without_social |
| RK15 | A player who never steps beside the counter never meets the keeper | the E rule decides by where the player stands (middle cell = panel, end cell = keeper) | the prompt pill changes live (COUNTER_SHOP / COUNTER_TALK 'Tal med <navn>') as the player moves, the keeper's quest and heart bubbles show over the counter, legs l03b / l06b / l06c walk it, windowed shots show both prompts |
| RK16 | Friendship saturates early: a typical player reaches 8 hearts with tier A on day 70 and has 14 of 30 citizens at 10 hearts after one game year (the castle is day 345) | se6 and design_social 13 | four heart scenes per tier A citizen, ratcheted range bounds in social.balance_claims_hold, the roadmap year-2 hook; pacing is data (points per heart, chat points) |
| RK17 | The wave-5 city bake rests on the sketch-proven LevelNav and V3's levels_graph(), not on V4's real geometry | design_towns 11.2 (55 anchors, 2,970 pairs, 0 failures on the sketch) | the lead re-bakes at the 5b gate (E3); towns_city.door_coords_match_city_json and real_city_populated_at_noon are REQUIRED at G5b |

---------------------------------------------------------------------------------------------------------------------------------------------

## 15. Ownership proof (`check_ownership.py`, run on 2026-10-14)

`python3 -I check_ownership.py` intersects every pattern of every package of the five layers (owners.json, the feature addendum, design_ui, design2's final candidate, this file) with every other as REGULAR LANGUAGES (subset construction over the pattern alphabet, minus both packages' exclusions), then expands every tracked file of the repo, checks every `ownsRemove`, every dependency (strictly earlier waves, no cycles, CORE / QA never hard-depend on EXTENDED), every concrete path named in a task, the localization key families against `tools/loc/key_owners.json`, and the contract block (game events, input action, save section, autoload, marker handlers, Lua keys, registries, UI screens). `--raw` shows the same check on the four unedited track files (the BEFORE picture); `--selftest` breaks the merged file 16 ways and every mutant must be caught; `--emit-effective FILE` writes the effective owners table for the lead's tooling; `--design2 drafts` repeats it against design2's four draft package files.

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
```

Pre-existing issues NOT caused by this addendum and left for their owners: 335 tracked files are owned by nobody (assets, docs and tool files from before the plan; design2's checker reports 336); design2's own draft files use the short ids D1 / DR1 / DX1 in `key_owners_additions.json` (design2's final candidate merges them); `--design2 drafts` reports one dependency problem inside design2's drafts (P22 -> D1, same wave).

### 15.1 The files of this addendum

| File | What |
|---|---|
| `ADDENDUM.md` | this document (generated by `_build/build_addendum.py` from `_build/parts/*.txt` and `packages.json`) |
| `packages.json` | the work packages (schema of `docs/design/features_workpackages.json` + `class`, `track`, `softDependsOn`, `optional`, `gate`; amendments with `id`, `built`, `fixRound`, `conditional`) |
| `key_owners_additions.json` | the merged CSV families (E2) |
| `check_ownership.py` | the proof above |
| `CHANGELOG.md`, `OPEN_QUESTIONS.md` | the final edit: every reviewer defect and its resolution; the questions only the user can answer |
| `effective_owners.json`, `lead_tools/ownership.py` | the effective owners table (include + exclude) and a drop-in ownership tool that honours exclusions (DT64) |
| `_build/` | the editor's scripts: `build_final.py` (asserted patches of the track texts), `b5_final.py`..`b7_final.py` (the final edit), `build_addendum.py`, the parts, `rt_numbers.json` |

### 15.2 The design material this addendum builds on (all under `design3/`)

`design_farm.md` + `farm/` (map, probes, 43 + 11 checks, 25 shots, art), `design_towns.md` + `towns_scripts/` (prototype classes 2,700 lines, probes b0-b10, 11 mutants, shots), `design_social.md` + `social_proto/` + `social_scripts/` (102 prototype checks, Monte Carlo, planner, validator, 5 mock shots), `design_integration.md` + `integration_scripts/` (loop prototype, VRAM probes, copy and kit budgets), the five analyst reports in `analysis/`, `design2/FINAL/`, `design_ui/UI_NAVIGATION.md` and `ui_packages.json`, and the final edit's probes and simulations under `final_editor/` (`se1` the counter geometry, `se3` the partner commute, `se6` the availability Monte Carlo, `te2` the hours switch, `te4` the digest).

## 16. Open questions: only what the USER must decide

Each has a default the build follows if nobody answers. Everything smaller is a decision of the editor (DT38) and a data knob.

Q1. **Winter: a greenhouse or a quiet winter?** No crop of the plan's data lists vinter, so the farm earns nothing on 28 of 112 days. N07 (12 indoor plots, two winter crops at about a quarter of the summer income, a shop file, two conditional P06 tasks) is built only on a yes. *Default:* no greenhouse; the 4 x 3 slot stays reserved and silent.

Q2. **The marriage-style vocabulary and the two items** Stage names, the ceremony and the commitment items are copy decisions with child-friendly, gender-neutral constraints that no package may invent silently. *Default:* your words from the brief (bedste ven -> hjertven -> forlovet -> gift) and the items Hjertebuket and Løfteagern; no PARTNER_ row is written before you or the lead confirm.

Q3. **The four hero-twin citizens (Rasmus, Kiki, Bertil, Bodil)** They are the lookalikes of the playable figures. Absent while you play that figure, or present as a 'sibling' with an extra line? (Kløvermynte and Birk are playable too but stay present in every case: the seed shop needs its keeper, so a player who chose Kløvermynte meets her namesake.) *Default:* absent (the player cannot befriend their own twin).

Q4. **A 10-line listening test before the bulk voice bake** One Danish system voice (Sara) with 8 pitch / rate presets for 30 characters; the invented names (Kløvermynte, Hasselnød, Hyldeblomst, Rosmarin, Fingerbøl, Stokrose, Bøgeknop) are unverified. *Default:* presets ship as placeholders, the bake waits for your ear; voice_presets.respell fixes a name without touching text.

Q5. **Native Danish review: before or after the voice bake?** About 26 h for the first phase and 27 h for the second by an assumed 400 words per hour. *Default:* after; a text fix regenerates its voiced line in the same commit (0.65 s per line).

Q6. **The night watch** At 23:45 a forced walk home to the farm door (whispered from 23:30, never during a modal) protects you from waking up in a shop. Alternative: none, you pass out where you stand. *Default:* on.

Q7. **Two stalls without a room: acceptable?** Your requirement says every shop and service is also a room you walk into. The sketch draws the Torvet market stall and the bat house window as outdoor stalls: Torvestanden (Brumme's weekend stall, the same shop id as his workshop room) and Natteblik-vinduet (the map seller, evenings). They are the only two exceptions (24 rooms for 28 non-decor buildings) and their keepers are reachable at the stall ends like at every counter. The alternative is a 3 x 3 room for each (about 2 points of work and one more interior each for the router). *Default:* the two stalls stay outdoor, the sketch's own form.

---------------------------------------------------------------------------------------------------------------------------------------------

## Appendix A. The amendments task by task (shortened; the complete text with every `-> verify:` name is `packages.json` `amendments[]`)

**RT1 P15-save-system** (wave 3, built, fix-round FR-4; sources: social)

1. tests/sections/save.gd: the three registry tests (registry_names_in_apply_order, feature_orders_apply_order, registry_equal_orders_keep_registration_order) assert the EXACT list of registered section names and fail as soon as a REAL feature manager is registered (measured: `social` made all three fail; HomeManager / LootService will too); detach the real... *[verify: save.registry_names_in_apply_order, save.feature_orders_apply_order, save.registry_equal_orders_keep_registration_order]*
* note: First of the fix-round: needed by EVERY feature autoload of wave 4 (HomeManager, LootService ... too), not only by SocialManager; land it once.

**RT2 F1-feature-data** (wave 3, built, fix-round FR-4; sources: social)

1. tools/features/add_autoload.py CONTRACT gains SocialManager -> scripts/social/social_manager.gd; tools/features/test_add_autoload.py replaces every literal 5 by len(NAMES) (7 places) and the tool docstring says 'all six'; tests/lib/features/fresh.gd FEATURE_NODES gains SocialManager and seed_features calls set_seed(int) when the manager offers it; tests/l... *[verify: tools/features/test_add_autoload.py exits 0 with every PASS id (add_all, second_run_is_noop, base_block_untouched ...)]*
2. KNOWN TRAP found by measuring: content_features.add_autoload_idempotent_and_parallel_safe runs the python self-test against the repo's own project.godot and FAILS as soon as ANY feature autoload line exists (measured with the SocialManager line; HomeManager will do the same): tools/features/test_add_autoload.py builds EVERY test root from the PRISTINE for... *[verify: tools/features/test_add_autoload.py PASS pristine_copy_ignores_existing_feature_lines]*
* note: Editor change (final edit): no pristine fixture file and no edit of tests/sections/content_features.gd (DL4's): the self-test strips the feature lines of the given project itself, so it holds for F2-F5 landing in wave 4 as well. The two wrapper checks (social.fresh_resets_social_manager, social.grant_set_hearts_uses_manager) are S-core's.

**RT3 P01-project-config** (wave 1, built, fix-round FR-4; sources: social, integration)

1. tests/tools/check_project.gd + tests/tools/fixtures/project_with_feature_autoloads.txt: FEATURE_AUTOLOADS gains SocialManager (*res://scripts/social/social_manager.gd), the fixture gains the line, the literal pins become 11 + FEATURE_AUTOLOADS.size() (renamed from p01.fixture_is_11_base_plus_5_feature_lines and p01.live_project_accepts_five_appended_featu... *[verify: p01.autoloads_base_in_order_features_after, p01.fixture_is_11_base_plus_6_feature_lines, tests/tools/mutation_check.py exits 0 with every mutant caught]*
2. Input map: ONE new action `people` = P (pad: a pause-menu row 'Folk', no spare button; the social track and the integration track asked for the same action, this is the single task): project.godot [input], tests/tools/input_contract.gd (ACTIONS gains a TOWN list of one), print_inputmap.gd, ACTIONS.size() 35 -> 36, expected_shared() unchanged (P is free: u... *[verify: project.input_has_36_actions_incl_5_addendum_1_town, project.input_map_matches_contract]*
3. docs/design/: copy this addendum (design3/FINAL/ADDENDUM.md) to docs/design/PLAN_2D_TOWNS.md and design3/FINAL/packages.json to docs/design/towns_workpackages.json next to PLAN_2D.md, PLAN_2D_FEATURES.md and the dungeon addendum, and the four track designs (design_farm.md, design_towns.md, design_social.md, design_integration.md) to docs/design/towns_farm... *[verify: p01.design_plan_links_towns_addendum, p01.design_files_use_current_town_name]*
* note: Executed as a fix-round BEFORE wave 4 (like the ui_page_* overrides of design_ui). DECISION DT39: a NEW header line instead of rewriting line 3, so the pinned SUPERSEDE_LINE never moves. The three tasks are the ONLY P01 edits of the town, farm and social tracks.

**RT4 P10-data-contracts** (wave 2, built, fix-round FR-4; sources: towns, social)

* ownsAdd: `tests/sections/data_registry.gd`
1. FIX-ROUND (built package, wave 2): the generic Lua kind `registry`: scripts/data/lua_lint.gd KINDS gains "registry" (and the kind_unknown message lists it); scripts/autoload/lua_runtime.gd keeps `_registries` (name -> id -> def), loads a `kind = "registry"` file whose header says `registry = "<name>"` and a top-level table of that name (one claim per id:... *[verify: data_registry.registry_kind_loads_lints_and_claims, data_registry.lint_kinds_include_registry (the new section tests/sections/data_registry.gd, P10's)]*
2. LuaRuntime._call_api gains four social functions, each a one-line late-bound call (unknown names keep returning nil + the once-only log): api.get_hearts(npc) -> int, api.add_hearts(npc, n) (-> SocialManager.add_hearts(source = lua)), api.is_birthday(npc) -> bool, api.festival() -> the id of today's ACTIVE festival or ''; the 'unknown function' message lis... *[verify: data_registry.api_functions_nil_without_manager]*
* note: ONE editor of scripts/autoload/lua_runtime.gd and scripts/data/lua_lint.gd: the registry kind first, the four api functions second. The social track's `events` and `festivals` are registries of the generic kind (its dedicated-kinds patch stays only as a fallback in social_proto/patches_fallback_dedicated_kinds). The Lua key `until` is reserved: routines use leave / stay / from.

**RT5 P12-economy-shop-crafting** (wave 3, built, fix-round FR-4; sources: towns, social)

* ownsAdd: `tests/sections/economy_hours.gd`
* ownsRemove: `lua/shops/festival_markets.lua`, `lua/recipes/social.lua`, `lua/shops/greenhouse_seeds.lua`
1. FIX-ROUND (built package, wave 3): ONE new helper scripts/economy/shop_hours_gate.gd (class ShopHoursGate, static: open_override(shop_id) -> true | false | null, closed_info(shop_id) -> {closed_reason, opens_at, next_open_weekday}) that asks Svc.static_call("res://scripts/towns/hours.gd", &"shop_open" / &"closed_info", ..., null) unless the config switch... *[verify: economy_hours.shop_closed_refuses, economy_hours.shop_info_closed_reason, economy_hours.unclaimed_shop_keeps_weekday_rule, economy_hours.switch_off_ignores_the_buildings, economy_hours.shop_system_keeps_two_static_call_lines]*
2. Carve-outs of three NEW files inside P12's globs: lua/shops/festival_markets.lua (S-fest-content), lua/recipes/social.lua (S-marriage) and, only if the greenhouse is activated, lua/shops/greenhouse_seeds.lua (N07); ShopSystem keeps answering is_open as the towns track's hours rule decides and that rule asks SocialManager.shop_closed_by_festival(shop_id) f... *[verify: economy_hours.carved_out_files_have_other_owners]*
3. lua/shops/seed_shop.lua: carrot_seeds stock = 25 and restock = 25 (was 20 / 20): a dedicated player with the 800 g field expansion needs 19.2 carrot seeds a day for 110 plots (cycle 4 / 0.85 + 1 = 5.71 days) and the seed shop is closed on Sundays, so 6 x 20 = 120 a week = 17.1 a day left a shortfall of 2.1 a day: about 12 plots fall back to turnips (3.25... *[verify: economy_hours.seed_supply_covers_a_dedicated_field]*
* note: Carve-out of three NEW files inside P12's globs (S-fest-content, S-marriage, and N07's winter seeds, a file that exists only if the greenhouse is activated). The shop hours are NOT shop-def fields: they live in the buildings registry (decision DT12).

**RT6 P04-area-framework** (wave 3, built, fix-round FR-4; sources: social)

1. IsoArea.evaluate_when(spec): a spec that contains `&` or begins with `!` or whose kind is one of at open hearts fest hour weekday season birthday stage is delegated to SocialManager.eval_when (late bound through Svc, 12 lines); the four old kinds keep their fast path; an UNKNOWN kind is no longer TRUE: it answers false AND area.map.errors gets `when_unkno... *[verify: area.when_new_kinds_delegate, area.when_unknown_kind_is_a_map_error, area.when_refresh_on_hour_edge, area.when_old_kinds_unchanged]*
2. tests/sections/area.gd: the fixture-bound geometry checks (area.farmable_cells expects the 12 x 12 fixture's 12 cells, area.spawns_parsed a `from_other` spawn) enter `_fixture_iso` EXPLICITLY, run, and RE-ENTER the start area afterwards: when N01's farm.map exists the default start area becomes `farm` and these two built checks failed (measured with only... *[verify: area.geometry_runs_on_the_fixture_whatever_the_start_area, area.default_area_falls_back_to_the_fixture (existing), area.travel_to_unknown_area_is_quiet (existing)]*
* note: iso_area.gd is edited ONCE (the when= delegate) and tests/sections/area.gd once (the fixture fix, task 2); the towns director needs no hook (it is a child node of the area and frees itself in _exit_tree), the dungeon track needs none (world_2d.gd is D0's).

**RT7 P07-ui-foundation** (wave 3, built, fix-round FR-4; sources: towns, social, ui-repair; REPAIR of design_ui)

* ownsRemove: `scripts/ui/components/hint_bar.gd`, `scenes/ui/components/hint_bar.tscn`, `scripts/ui/components/ui_confirm.gd`, `scenes/ui/components/ui_confirm.tscn`, `scripts/ui/components/toast_stack.gd`, `scenes/ui/components/toast_stack.tscn`, `scripts/ui/components/prompt_pill.gd`, `scenes/ui/components/prompt_pill.tscn`, `scripts/ui/components/whisper_line.gd`, `scenes/ui/components/whisper_line.tscn`, `scripts/ui/components/tt_slider.gd`, `scripts/ui/components/quantity_stepper.gd`, `scenes/ui/components/quantity_stepper.tscn`, `scripts/ui/components/area_banner.gd`, `scenes/ui/components/area_banner.tscn`, `scripts/ui/dev/ui_fixtures.gd`, `tools/ui/build_theme.gd`, `tools/ui/crop_guide_refs.py`, `assets/ui/icons/slider_grabber.svg`, `assets/ui/icons/slider_grabber_hi.svg`, `localization/ui.csv`
1. scripts/ui/game_ui.gd SCREEN_ORDER gains social_hud (right behind hud), event_overlay (between hud and dialogue_ui, so the letterbox is BEHIND the dialogue), people, gift_ui and post (next to quest_journal, above the shops, below the pause menu); GameUI instances a screen only if its scene exists (ResourceLoader.exists), so the ids are inert until S-ui, S... *[verify: ui_foundation.game_ui_loads_new_ids_in_order, ui_foundation.smoke (existing: 0 failures)]*
* note: REPAIR of a defect in design_ui (proved by check_ownership.py --raw: part of 34 pattern overlaps and 13 tracked files with two owners): design_ui's P28 owns the component paths and P17 owns area_banner, and P14 owns localization/ui.csv, but ui_packages.json carves only assets/ui/theme.tres out of P07's globs. This amendment lists the exact paths; the P28 / P17 / P14 entries stay as design_ui wrote them.

**RT8 P09-test-harness** (wave 1, built, fix-round FR-4; sources: integration, towns, social, editor)

* ownsAdd: `docs/DEVELOPMENT.md`
* ownsRemove: `tests/lib/towns/**`, `tests/lib/social/**`, `tests/lib/town_loop/**`, `tests/lib/ui_screens.d/social.json`, `tests/lib/ui_screens.d/social_events.json`, `tests/lib/ui_screens.d/towns.json`
1. tests/run_playtest.sh: `--fast` = GODOT_EXTRA_ARGS="--fixed-fps 60" (the variable is already forwarded, run_playtest.sh line 147; measured: a 5.3-game-second real-input walk costs 0.05 s wall with it and 3-5 s without; Engine.time_scale does NOT speed physics); documented in the header and docs/DEVELOPMENT.md; windowed runs ignore it *[verify: harness.fast_flag_forwards_fixed_fps]*
2. tests/lib/ui_audit.gd: UiAudit.screens() also merges tests/lib/ui_screens.d/*.json (one file per owning package: social.json of S-ui, social_events.json of S-events, towns.json of T-post-office; same row schema as ui_screens.json; a duplicate id is a failure) so the town, social and farm packages register their screens without editing a file they do not own *[verify: ui_audit.screens_merge_dir_unique_ids (tests/sections/ui_audit.gd is P09's)]*
* note: Carve-outs by EXACT file name (the integration draft carved the whole tests/lib/ui_screens.d/ directory: a file nobody claims would then have no owner). docs/DEVELOPMENT.md (the worktree workflow, committed after owners.json was written) had no owner; the --fast flag is documented there.

**RT9 P03-loc-core** (wave 2, built, fix-round FR-4; sources: integration)

* ownsAdd: `tests/sections/loc_towns.gd`
1. tools/loc/key_owners.json (executed by the lead as a patch of this built package at the START of each wave, sanctioned shared edit E2, the same procedure as design2's task): merge the entries of design3/FINAL/key_owners_additions.json whose `wave` is the wave about to start (wave 4: towns.csv, farm_signs.csv, social_sys.csv; wave 5: farm_site.csv, social_... *[verify: loc_towns.ownership_lint_green_after_additions (the new section tests/sections/loc_towns.gd, P03's)]*
* note: Withdraws the loot track's carve-out of key_owners.json (design_integration X3). Checked by check_ownership.py (F) and design3/integration_scripts/i_check_keys.py.

**RT10 P28-ui-nav-foundation** (wave 3b, unbuilt; sources: social)

1. tools/ui/build_theme.gd gains three variations used by the calendar tab: CalCell (RowButton look with parchment-dark fill, radius 10, 2 px divider), CalCellFest (lavender-pale fill, ink border) and CalCellToday (ink 3 px border, no gold), theme.tres regenerated; the prototype used StyleBox overrides for exactly these three looks *[verify: ui_conformance.theme_calcell_variations, ui_foundation.theme_matches_builder]*
* note: design_ui package, wave 3b, unbuilt: an ordinary extra task (theme.tres is regenerated by the same builder).

**RT11 P06-player-farm-core** (wave 4, unbuilt; sources: farm, social)

1. FarmGrid.unlock_cells(zone_id) keeps its signature but takes the cells from the marker grammar `cells=x0..x1,y0..y1[;..]` (IsoArea.parse_cells) and emits EventBus.plot_unlocked("zone:<id>") once per zone; persistence of unlocked zones is the AREA FLAG `zone_<id>` written by N02's handler (FarmGrid.to_dict stays plots only) *[verify: farm.unlock_cells_from_marker_grammar, farm.plot_unlocked_once_per_zone]*
2. FarmView.setup(farm, area) paints every farmable cell with terrain `field_grass` (art by N03; placeholder until then) instead of leaving the `grass` tile, and returns a harvested / reset cell to `field_grass`, never to `grass` (area.set_terrain only: no iso_area edit) *[verify: farm.untilled_cells_use_field_grass]*
3. FarmGrid emits `game_event plot_tilled {plot_id}` on every successful hoe use (the tutorial quest binds to it); `crop_ready` as game_event when a plot becomes READY (hint trigger) *[verify: farm.plot_tilled_event, farm.crop_ready_event]*
4. The lazy handler entry for field_expansion in IsoArea.LAZY_HANDLERS (farm_view.gd) is overridden by lua/config/marker_handlers.lua (N02); FarmView must therefore not require to be the handler: FarmView.setup only reads area.farmable *[verify: farm.farm_view_works_without_expansion_handler]*
5. Tool use on a cell reserved by FarmReserve (home / slot / zone) is refused with whisper FARM_CELL_RESERVED (defined in localization/farm.csv, FARM_ prefix, da + en); the class is N02's (wave 5, one wave after this package), so it is reached ONLY through Svc.static_call("res://scripts/farm/steading/objects/farm_reserve.gd", &"blocked", [area, cell], "") an... *[verify: farm.reserved_cell_refused_with_fake_reserve, farm.absent_reserve_means_free]*
6. Player2D event API for the EventRunner: event_begin() / event_end() (like begin_talk: input off, frozen state), event_walk_to(pos, speed) awaitable, event_face(dir), camera_focus(target_pos_or_node, zoom, seconds) / camera_release(seconds) (tweens Camera2D offset + zoom inside the area's zoom range, restores on release); FarmGrid.water_unwatered(max_n) ->... *[verify: player.event_api, player.camera_focus_release_roundtrip, farm.water_unwatered]*
* CONDITIONAL (N07 (greenhouse) is activated by a yes to Q1): EXTENDED, only if the user answers yes to the greenhouse question (N07): FarmGrid merges a second crop table `crops_extra` (lua/config/crops_extra.lua, owned by N07) next to `crops` of game_balance.lua, and a plot flag `indoor` (set for the greenhouse cells) skips the season gate for crops with `winter_ok = true`; outdoor plots stay gated *[verify: farm.crops_extra_merged_and_indoor_flag_skips_season_gate, farm.outdoor_plots_still_season_gated]*
* note: No iso_area.gd, world_2d.gd or area_tileset.gd edit is needed by the farm (proved by the 43-check prototype). The conditional task does not exist unless the user answers yes to the greenhouse question: no dead code is built for a feature that may never ship.

**RT12 P11-maps-iso** (wave 4, unbuilt; sources: farm, towns)

* ownsRemove: `data/maps/farm.map`
1. CARVE-OUT: data/maps/farm.map and localization farm keys move to N01-farm-map; P11 keeps hyggebyen.map, areas.csv (UI_READ, SIGN_* except the three exact keys SIGN_ORCHARD / SIGN_FARM_BRIDGE / SIGN_FARM_FOREST that N01's farm_signs.csv defines) and maps_iso.gd; task 1 of the base order, amendment 1 of the feature addendum (home marker, growth, tent, from_... *[verify: maps_iso.farm_checks_moved_to_maps_farm]*
2. tests/sections/maps_iso.gd: drop the farm halves (names re-homed as maps_farm.*), keep hyggebyen halves and PENDING_AREAS for the hyggebyen warp; the default-start-area note: the farm file exists from wave 4 on *[verify: maps_iso.hyggebyen_checks_unchanged]*
3. data/maps/hyggebyen.map carries the TOWN markers of the draft D3/towns_scripts/proto/hyggebyen_draft.map: one `@marker T town`, 14 `door building=<id>` markers (froebutikken bageriet smedjen troldmandstaarnet moebelbutikken skraedderiet toemmerhandlen dyrehuset loppeloftet fekongens_hus hyldeblomsts_hus pippins_hus birks_bistade pingvinens_hus) each on th... *[verify: maps_iso.town_markers_present (the bake that consumes these markers is proven by T-routes at the wave-5 gate)]*
* note: farm.map is N01's (DT5; the lead may undo this by deleting one owns entry and this ownsRemove). hyggebyen.map carries ONE `post set=fest spot=hyggetorv` marker for the festival posts and NO festival decor markers (DT22, DT23): the social track's 24 per-post markers and its `when=fest:` decor markers are dropped.

**RT13 P13-quests-lua-runtime** (wave 4, unbuilt; sources: farm, social)

* ownsRemove: `lua/quests/forste_dage.lua`
1. CARVE-OUT: the tutorial quest lua/quests/forste_dage.lua belongs to N04-farm-first-morning (same precedent as pips_runde.lua and the F1 quests); P13's validator stages must stay green with it; the binding vocabulary needs `on = "game_event"` with `event =` (already ordered) and the events plot_tilled and post_read *[verify: quests.forste_dage_binds_only_known_events]*
2. rewards.friendship = {npc = n} calls SocialManager.add_hearts(npc, n, quest) late bound (the flag path of the order is the FALLBACK while the autoload is absent), no other writer of friend_<npc> remains in the package *[verify: quests.friendship_reward_goes_through_social_manager]*
3. QuestManager.item_in_use(item_id) -> bool: true when an ACTIVE quest still needs the item (have = true objectives, quest_spot needs=, consume=, recipes it asks for); S-gifts hides such items from the gift picker *[verify: quests.item_in_use]*
4. on = 'state' query friend_hearts_at_least {npc, hearts} (registered by SocialManager through the same Svc mechanism as placed_by_rarity, re-evaluated on friend_changed, which is already in the order) and the generic payload filter match = {npc = '..', item = '..', id = '..'} next to rarity / min_level for on = 'game_event'; objective sugar gift_given, fes... *[verify: quests.state_friend_hearts_at_least, quests.game_event_match_filter, quests.social_objective_sugar]*
* note: All social tasks are late bound: the package does not depend on S-core (same wave).

**RT14 P16-ui-menus** (wave 4, unbuilt; sources: social)

1. Pause menu card S07: a TRANSFER row 'Folk' after Opgavebog (closes the pause menu first, then opens `people`; the row is guarded by GameUI.get_screen like Garderobe) *[verify: menus.pause_row_folk, menus.pause_rows_transfer_vs_nest]*
* note: 

**RT15 P18-ui-shop-inventory** (wave 4, unbuilt; sources: towns, social)

1. scripts/ui/shop_ui.gd + scenes/ui/shop_ui.tscn: (a) the CLOSED state reads ShopSystem.get_shop_info closed_reason / opens_at (text 'Lukket i dag. Åbner igen onsdag.' / 'Lukket lige nu. Åbner kl. 07:00.'); (b) the panel honours the close request EventBus.ui_panel_toggled(&"shop", false) (closing-time eviction, UI_NAVIGATION 4.2); (c) the greeting bubble te... *[verify: shop_ui.closed_state_reasons, shop_ui.close_request_honoured, shop_ui.greeting_from_resolver, shop_ui.greeting_falls_back_to_def, shop_ui.keeper_lines_optional, ui_conformance.shop_compare_guide]*
* note: Everything is late bound: without scripts/towns and the social resolver the panel behaves as the order says.

**RT16 P22-art-environment** (wave 4, unbuilt; sources: farm, integration)

* ownsRemove: `assets/iso_props/farm/**`, `assets/iso_props/farm_dress/**`, `assets/iso_props/farm_greenhouse/**`, `assets/backdrops/farm_*`, `assets/iso_tiles/field_grass*`, `assets/iso_tiles/tiles_farm.json`, `tools/art/environment/farm/**`, `tools/art/environment/farm_dress/**`, `assets/iso_props/shops/**`, `assets/iso_props/festival/**`, `tools/art/environment/shops/**`, `tools/art/environment/shops_special/**`, `tools/art/environment/festival/**`
1. CARVE-OUT: the ten farm-only props (trunks, pillars, shed, bin, stakes), the farm backdrops (farm_sky / farm_far; farm_canopy is new) and the untilled terrain move to N03-farm-art (wave 5), the dress and greenhouse art to N06 / N07; P22 keeps the 56 spike props, the seven farm props above, 17 atlases, the Hyggebyen props and its other backdrops; ArtCatalo... *[verify: art_environment.farm_ids_pending_until_n03]*
2. Bake, in wave 4 as already ordered (task 3), the farm props with these CONTRACT sizes and footprints (the builders are lifted from design3/farm/art/tools/characters/props_farm.py, the baked reference files are design3/farm/art/out/farm_props): coop_small 350x295 pivot (155,218) footprint 3x2, barn_small 472x424 (208,313) 4x3, animal_house 319x270 (143,199... *[verify: art_environment.farm_contract_props_sizes_and_footprints]*
3. lua/config/props_extra.lua gains the 16 rows of design_farm.md 10.3 verbatim (trunk_giant_a 5x3 none, trunk_giant_b 3x3 solid footprint strips 12, trunk_under_a/b none, mailbox_red circle 14, shipping_bin 2x1 footprint pad 8, tool_shed 2x2 pad 12 strips 6, bench 2x1 none, stake_sign circle 10, rope_stake_x/z none, paw_prints none, build_stake none, coop_s... *[verify: art_environment.props_extra_ids_exist, art_environment.farm_rows_complete]*
* note: Carve-outs for N03 / N06 / N07 (farm) and I3 / I4 / I5 (shops, festival): the same mechanism design2 used for assets/iso_props/city/**. P22's own market_stall_furniture / tailor colourways and mailbox_red stay P22's.

**RT17 P23-art-icons-keyart** (wave 4, unbuilt; sources: social)

1. Two item icons: heart_bouquet and promise_acorn (the coloured-initial badge is the accepted fallback until they land) *[verify: art_icons.social_items_have_icons_or_badge]*
* note: Optional: the coloured-initial badge is the accepted fallback until the two icons land.

**RT18 F2-home-core** (wave 4, unbuilt; sources: farm, social)

1. HomeManager keeps the world flag `home_tier` (int 1..10) correct on new game, load and upgrade (N02 FarmStage and N05 dress read it as a bare flag) *[verify: home.flag_home_tier_always_set]*
2. HomeManager.guests_today() -> Array[{npc, reason: partner | party | visit}] (asks SocialManager.partner_in_home() and the house-party state); the weekly guest gift (guest_visits_per_week) names a friend: SocialManager.pick_visitor(week, i) (hearts >= 4, deterministic, never the same NPC twice a week) and visitor_gift(npc_id, item_id) carries that NPC inst... *[verify: home.guests_today_shape, home.visitor_gift_names_a_friend, home.house_party_calls_social]*
* note: The social task is late bound to SocialManager.partner_in_home / pick_visitor / start_house_party, which S-marriage (LATER) provides: without S-marriage guests_today() is [] and the weekly guest gift stays anonymous (honest stub, DT37).

**RT19 F4-loot-shops** (wave 4, unbuilt; sources: farm, towns, social, editor)

1. lua/config/marker_handlers.lua registers the farm types: shipping_bin -> scripts/farm/steading/objects/shipping_bin_2d.gd, tool_shed -> tool_shed_2d.gd, field_expansion -> field_expansion_2d.gd (replaces the lazy farm_view.gd entry), underdeck -> underdeck_2d.gd, ambient_fx -> ambient_fx_2d.gd, dress -> scripts/farm/steading/dress/dress_2d.gd; `post` and... *[verify: loot.marker_handlers_registered_farm_types]*
2. lua/config/marker_handlers.lua gains three entries pointing at ONE script: town = "res://scripts/towns/town_marker.gd", door = the same, post = the same (the handler contract `static func create_marker(params, pos, cell, area) -> Node`) *[verify: loot.marker_handlers_town_door_post_rows, loot.marker_handlers_table_valid (the three marker rows are proven again by T-director at wave 5b)]*
3. lua/config/marker_handlers.lua also registers the two room services of V6: `bath` -> res://scripts/traetoppen/life/bath_tub_2d.gd and `board` -> res://scripts/traetoppen/life/notice_board_2d.gd (the `mailbox` row exists from design2); design2 needed no rows for them because V4's builder instantiated them in the city, but the towns' rooms place them from t... *[verify: loot.marker_handlers_registered_room_services (the two room handlers are proven again by T-interiors-core at wave 5)]*
4. LootService.check_friend_gifts(npc_id) is public and idempotent (the one-time loot.gifts rows are keyed `npc:hearts` in the saved claimed table): SocialManager calls it after EVERY heart gain, so the P14 weekly-chat call disappears; PriceCurve reads the KEEPER's hearts (flag friend_<keeper> of the shop def) and says so in its header; LootService.set_capst... *[verify: loot.check_friend_gifts_idempotent, loot.price_curve_reads_keeper_hearts, loot.set_capstone_granted_reads_the_record]*
* note: lua/config/marker_handlers.lua is F4's file and stays so: it also carries mailbox (V6), the V8 forest types, the dungeon types and lift; every package adds ROWS through this amendment list, nobody edits the file.

**RT20 V1-cast-data** (wave 4, unbuilt; sources: farm, towns, integration)

1. npcs.lua row postman_pip: quests_offered = { pips_runde, forste_dage }; the test `postman has no quests` of data.gd is rewritten for postman_pip (penguin_postman keeps none) *[verify: cast_data.postman_pip_offers_forste_dage]*
2. lua/config/npcs.lua + localization/core.csv NPC_<ID> + the data pins: 8 new rows (friendship = true on all eight, the switch the social track reads; routine = true on all 30) rasmus (fox), lamplighter_kiki (monkey), bertil (hobbit_pip), bodil (hobbit_bodil, draws as hobbit_pip until the A2 bake), innkeeper_kvak (frog), cub_bamse (bear cub, scale 0.72), cl... *[verify: data.roster_30_rows_valid, cast_data.new_roles_valid]*
3. tests/sections/cast_data.gd: family and age fields of D3/towns_scripts/proto/citizens.json are copied into the social track's citizens.lua source (sibling pairs Bertil/Bodil Bøgeknop and Kløvermynte/Birk, children Lily and Bamse): the towns track only reads them (marriage eligibility exclusion is the social track's rule) *[verify: cast_data.family_and_age_present]*
4. tests/sections/data.gd: open the roster pins so a data-only citizen is green: replace npcs.size() == N by 'every required id exists' (the 15 + 7) plus full field validation of every row (name_key == NPC_<ID>, voice range, chain ends at a pack character, shop keeper == npc, friendship rule); areas, roles and schedules are validated against the lists their... *[verify: data.roster_accepts_data_only_citizen]*
* note: V1 is design2's package (wave 4); the roster becomes 30 and every row is validated as data, never counted.

**RT21 V3-levels** (wave 4, unbuilt; sources: towns)

1. scripts/world2d/levels/**: a read-only `levels_graph() -> Dictionary` (levels with their walkable polygons, the 9 bridges with endpoints, the ladder, the Skovlift basket) that LevelNav plans over, instead of the sketch JSON; same data the builder uses, so planner and collision cannot drift *[verify: city_levels.graph_api_matches_builder]*
* note: 

**RT22 D0-dungeon-world-hooks** (wave 4, unbuilt; sources: integration, editor)

1. world_2d.gd NPC warm list: NPC_WARM_CLIPS becomes per visual: walkers (a routine or wander radius > 0, non-flyer) warm idle talk walk, flyers idle talk hover, radius-0 keepers idle talk; today's constant idle talk hover leaves walk cold for the 6 walking villagers (first step 15-37 ms) *[verify: dungeon_defeat.warm_clips_walkers_warm_walk (its budget twin is I2's, wave 5)]*
2. The 24:00 PASS-OUT wakes at the door of the house (DT50): after the day roll of `_sleep_sequence(true)` the player is placed at hub.wake_area : hub.wake_spawn (farm : from_home; the default area when the farm map is absent) behind the black screen, exactly where D0's gentle defeat wakes him but with NO gold loss and no run end; the existing NOTIF_PASSED_O... *[verify: dungeon_defeat.passout.wake_at_farm_from_home, dungeon_defeat.passout.no_gold_loss (I2's pass-out leg, which depends on D0, proves the chain at G5)]*
* note: world_2d.gd is D0's file. The towns need two things from it, both small and both D0's: the warm-clips rule (R-V4) and the pass-out wake at farm:from_home (DT50, the farm design and the loop leg l11 assumed it, nobody had written it). They do NOT need the other two edits integration X4 assumed (the director frees itself in _exit_tree, the closing eviction uses area_change_requested): towns X10 (DT24).

**RT23 P17-ui-hud** (wave 4, unbuilt; sources: towns)

1. the whisper path accepts an already formatted string: EventBus.whisper_requested(text_key) is passed through tr(), and a string without a CSV entry is shown as is (the door whispers 'Lukket lige nu. Åbner kl. 07:00.' are composed from a CSV template with %s, not stored per hour); the area banner takes BLD_<ID> titles of the interiors *[verify: hud.whisper_accepts_formatted_string, hud.area_banner_interior_titles]*
* note: design_ui moved P17 from wave 5 to wave 4; the task is an ordinary extra task there.

**RT24 P14-npc-dialogue** (wave 5, unbuilt; sources: farm, towns, social, integration)

* ownsRemove: `lua/dialogue/_voiced_social.lua`
* addDependsOn: S-core
1. REPLACES the weekly-chat task of the feature addendum: Npc2D counts dialogue_line_shown between dialogue_started and dialogue_ended, knows whether the conversation was COMPLETED (last line advanced or a closing choice picked; Esc = not completed) and calls SocialManager.on_conversation_finished(npc, lines_shown, completed) exactly once per conversation; i... *[verify: npc.weekly_heart_once_per_week, npc.esc_first_line_no_heart, npc.friend_gate_reachable_by_day_56]*
2. IntroSequence.run(world): first `Svc.static_call("res://scripts/farm/steading/tutorial/tutorial_runner.gd", "run", [world], false)`; when it returns true the farm's first-morning sequence has played (Pip, the letter via fairy_king context.intro, forste_dage); otherwise the letter-only flow of task 5 runs unchanged. The letter text and the `intro` context... *[verify: npc.intro_delegates_to_tutorial_runner_when_present, npc.intro_once]*
3. Dialogue context = world flags + quest_active_/quest_done_/friend_<npc> + hour day season weekday + SocialManager.dialogue_context(npc) (hearts, stage, weather, daypart, birthday, festival, chat_open, talked_today, gifts_left, partner); after LuaRuntime.get_dialogue the result goes through DialogueBridge.decorate(npc_id, dlg, ctx) (S-talk, late bound, no-... *[verify: npc.context_has_social_fields, npc.decorate_called_once_per_talk]*
4. Npc2D without a dialogue module (cross-track seam DT16): 4 of the 15 existing citizens (pippin_boegeknop, fairy_king, cat_morfar_mis, penguin_postman) and the 8 new ones have no lua/dialogue file; Npc2D then passes the empty module {lines = {}, choices = {}} to DialogueBridge.decorate (S-talk adds the greeting, the social choices and a closing choice), an... *[verify: npc.no_dialogue_module_still_talks]*
5. Dialogue action fall-through: an action Npc2D does not know (give_gift, social_topic, start_event, open_people, ...) is forwarded as EventBus.game_event(&'dialogue_action', {npc, action, data}) instead of an error, and an action that opens a screen ends the dialogue first (already the rule); a new choice therefore never needs an Npc2D edit *[verify: npc.dialogue_action_fall_through]*
6. Npc2D `driven` interface for the TownDirector (the same file, one editor): set_driven(true) switches off wander and idle timers, hold(bool) stands still (a dialogue or a gift), set_act(name) selects idle | talk | hover, face(dir8), plus `Npc2D.create(row)` reachable from the director; the `npc` marker handler skips a row whose npcs.lua entry has routine =... *[verify: npc.driven_interface, npc.routine_row_not_built_from_marker, npc.talk_holds_driven_citizen]*
7. Npc2D event API (the EventRunner drives it, absence = skipped directive): event_begin() / event_end() (suspend / resume the routine and wander; event_begin also holds a DRIVEN citizen and event_end hands him back to NpcDirector.resync(npc_id)), event_walk_to(pos, speed) awaitable, event_face(dir), event_clip(name), event_emote(kind heart|note|drop), set_b... *[verify: npc.event_api, npc.bubble_priority, npc.guest_mode]*
8. Npc2D supports a TEMPORARY instance created by code with visual / post / facing (no map marker) and `queue_free` on leave; `dialogue_ended` still fires once per dialogue *[verify: npc.temporary_npc_instance]*
9. DialogueUI.show_lines(speaker, lines, choices) -> awaitable result is re-entrant (the EventRunner calls it directly with the speaker's portrait); the quest journal (S14) instances res://scenes/ui/social/calendar_tab.tscn as a third tab %TabCalendar 'Kalender' when that scene exists (ResourceLoader.exists, the GameUI pattern) *[verify: npc.dialogue_ui_reentrant, npc.journal_calendar_tab_when_scene_exists]*
* size: grows from L to XL: the eight tasks are one file family (npc_2d.gd, intro_sequence.gd, dialogue_ui.gd, quest_journal.gd); if the build agent cannot hold it, the lead moves tasks 3 and 7 (event API, guest mode, bubbles) behind the others
* note: The only package that five tracks edit (design2, design_ui, farm, towns, social, integration): ONE editor, one ordered list. `lua/dialogue/_voiced_social.lua` is the GENERATED voiced index of CSV-selected lines; it lives in lua/dialogue/ (the only directory the voiced-key lint scans) but is owned by P24 (tools/voice/build_index.py writes it). If S-core slips to wave 5 the dependency is dropped and the weekly heart falls back to the flag path (late bound).

**RT25 P20-animals-buildings** (wave 5, unbuilt; sources: farm)

* addDependsOn: N01-farm-map
1. building_slot footprints are part of the map contract: coop 3x2, barn 4x3, house 3x2 with the marker cell = the FRONT (south-most) cell; art ids coop_small, barn_small, animal_house; an empty slot shows the prop `build_stake` at the front cell (E: whisper with the cost, B opens the build menu) *[verify: animals.slot_footprints_match_map, animals.empty_slot_shows_build_stake]*
2. PlacementService.place / can_place ask FarmReserve.blocked(area, cell) (Svc.static_call, N02) and refuse placeables on the home reserve, field zones, slot footprints, the greenhouse slot, spawns and warp cells with the whisper FARM_CELL_RESERVED (fixes the open gap G3: a fence could be dropped into the castle's footprint) *[verify: animals.placement_respects_farm_reserve]*
3. Animal2D wander: radius 3 cells around the `animal_yard` marker; the yard centre (14,24 local) keeps >= 3 free cells to every slot footprint (the map guarantees it) *[verify: animals.wander_stays_in_yard]*
* note: 

**RT26 F6-home-world** (wave 5, unbuilt; sources: farm, social)

* addDependsOn: N01-farm-map
1. Marker `H home` anchor contract (resolves gap G5): the marker cell is the DOOR cell (x D, y D); anchor = Iso.iso_center(cell) + Vector2(-32, 19) = the middle of the door cell's front (+y) edge; footprint_rect of home.json is relative to that anchor; the padded collider must leave the spawn `from_home` at D + (0, 2) free for the 25 x 14.8 body at every tie... *[verify: home_world.anchor_is_door_cell_front_edge, home_world.from_home_clear_at_every_tier]*
2. HomeExterior2D reads the map reserve instead of assuming it: on enter and on home_upgraded it calls IsoArea.set_growth_stage(rows) (already ordered) and also emits `game_event home_exterior_ready {tier}` so N02's FarmStage and dress markers refresh; the tent marker is a 2x2 prop at front cell D + (8,0) *[verify: home_world.growth_stage_matches_tier_table, home_world.tent_in_reserve_free_cells]*
3. HomeRoom (builder, rebuilt on every enter) spawns the entries of HomeManager.guests_today() as Npc2D guests on free floor cells (>= 2 cells from the door and from placed furniture footprints, deterministic through SocialRng, <= 6 visuals), partner and guests face the player when he enters and idle (honest: no seated pose); they are freed with the room *[verify: home_world.guests_spawn_on_free_cells, home_world.guests_freed_with_room]*
* note: 

**RT27 V6-city-life** (wave 5, unbuilt; sources: farm, towns)

1. The `mailbox` handler places the prop named by the marker parameter `prop=` (default mailbox_red) the way the built-in warp / sign / quest_spot markers do, and the day-1 mailbox is EMPTY on a new game (Pip delivered the first letter in person: whisper LIFE_POST_EMPTY, no post_read); from day 2 on, opening the mailbox emits `game_event post_read {quest_id}... *[verify: city_life.mailbox_places_param_prop, city_life.day_one_mailbox_empty_no_event, city_life.post_read_emitted_once_per_day_from_day_2]*
2. PostBox2D, NoticeBoard2D and BathTub2D are placed by room JSON markers (`mailbox`, `board`, `bath`) inside the interiors of the towns track through IsoArea.resolve_handler (the rows of F4's marker_handlers.lua point at scripts/traetoppen/life/{post_box_2d,notice_board_2d,bath_tub_2d}.gd: these are the file names V6 uses); their handlers implement `static... *[verify: city_life.handlers_work_inside_interior_room, city_life.handler_contract_create_marker]*
* note: 

**RT28 D2-dungeon-floors** (wave 5, unbuilt; sources: towns)

1. Fru Ugle's hub marker carries `when=away:appraiser_fru_ugle` (a kind of the social track's eval_when, late bound to NpcDirector.is_away): she stands in the Hulen hub only on her field days (Mandag and Torsdag) and is in Trætoppen on the other days; before the towns track exists the condition is true (service absent = no opinion), which is the location-fre... *[verify: dungeon_floors.hub_ugle_marker_when_away_clause (the full chain is D3's at wave 5b)]*
2. design2's allow-list guard (task 8, dungeon_floors.floors.no_new_autoload_action_signal) compares with the P01 / P02 contracts, not with literals: the autoload list = 11 + FEATURE_AUTOLOADS.size(), the actions = Contract.ACTIONS.size() and the typed signals = core.signal_contract_exact, and it asserts 'this package adds none': the sixth feature autoload S... *[verify: dungeon_floors.floors.guard_compares_with_the_p01_contract]*
* note: Natteblik has two stands (the city's bat window in the evening and the dungeon's hulen_keeper at night entry) with ONE shop id; the towns hours rule closes both outside 20:00-23:30 (honest wart, recorded in the stubs list).

**RT29 V4-city-map** (wave 5b, unbuilt; sources: towns)

1. scripts/traetoppen/city_builder.gd calls `Svc.static_call("res://scripts/towns/city_town.gd", &"attach", [area, "traetoppen"])` after the build (no hard dependency); data/traetoppen/traetoppen.json carries NO `board` and NO `bath` marker and no post-office mailbox (V6's handlers live inside the interiors of the towns track: Rådhus board, Badehus tub, Post... *[verify: city_map.town_attach_called, city_map.no_board_bath_markers_in_city, towns_city.door_coords_match_city_json (same wave, T-director's)]*
2. V4 no longer depends on D2-dungeon-floors or P19-forest-combat (removeDependsOn; P19 stays a softDependsOn): the G5b closure of the town loop then holds no dungeon-track package except D0 and DR7 (the hard-dependency closure of the 16 CORE packages plus V4 was 52 packages with D1, D2, DR0, DR1 and P19 (12 points) only because of these two edges; 47 withou... *[verify: city_map.chain_checks_skip_without_d2, city_map.planter_kinds_skipped_without_p19]*
* note: The social track's V4 task (festival post sets in data/traetoppen/traetoppen.json) is DROPPED: the city's festival sets are `fest_sets` of the city sidecar data/towns/traetoppen.json (T-routes, DT22). FINAL EDIT (PL2, conflict C37): the dependency edges to D2 and P19 are removed here because the user's first requirement (a usable Trætoppen) must not wait for the dungeon generator; a design2 package is amended because the defect is proved by closure.py, not because design2's design is disputed.

**RT30 F7-home-ui** (wave 5b, unbuilt; sources: farm)

1. The Hjemkiste screen opens on `game_event open_home_chest {}` from ANY area (the tool shed on the farm emits it); the screen must not test that the current area is `home` *[verify: home_ui.chest_opens_from_the_farm]*
* note: 

**RT31 P24-audio-voice** (wave 6, unbuilt; sources: integration, social, towns, farm)

* ownsAdd: `scripts/audio/**`, `lua/config/audio.lua`, `lua/config/voice_presets.lua`, `lua/dialogue/_voiced_social.lua`, `tests/sections/audio_town.gd`
1. AudioDirector (scripts/audio/audio_director.gd, a child created by AudioManager._ready: no new autoload) driven by lua/config/audio.lua (config key audio_map: areas, surfaces, events -> cue ids): ambience by area and by state night/day (compared state, not edge), rain overlay, shop bell on entering and leaving a shop interior, door cues, coin/heart/gift/l... *[verify: audio_town.cues_follow_area]*
2. AudioManager: cue_log (ring of 256 entries {t_msec, kind sfx|amb|music|voice, id, played}) recorded on every play call even when no file exists, play_ambience(id, fade) with two crossfading players, missing files stay silent with no engine message *[verify: audio_town.cue_log_ring_256]*
3. scripts/audio/surface.gd (Surface.at(area, pos): builder-set callable area.get_meta('surface_fn') first, then the grid ground char d wood, c stone, = rope, p dirt, . , ; f grass, else audio_map.areas[id].surface_default) and scripts/audio/footsteps.gd (player child: one cue per half walk cycle, 0.333 s walking and 0.25 s running from the clip fps 9 and 12... *[verify: audio_town.footstep_interval_matches_walk_fps]*
4. tools/voice/sfx_synth.py (extends the dungeon track's 14 cues), ambience_synth.py, music_synth.py: pure Python wave/math, deterministic seeds, then ffmpeg libvorbis q2 mono 22.05 kHz: 14 footsteps (grass/dirt/wood/stone x 3, rope x 2), shop_bell, door_open_wood, door_locked_knock, coin_clink, heart_up, gift_sparkle, letter_rustle, page_turn, bath_splash,... *[verify: audio_town.every_cue_id_in_data_has_a_synth_recipe]*
5. voice presets: lua/config/voice_presets.lua (key voice_presets: the 8 archetypes of the social data child 1.32/1.10, wanderer 1.22/1.16, fairy 1.18/1.08, shopkeeper 1.10/1.02, gardener 1.02/0.98, watcher 0.92/0.94, elder 0.84/0.82, craftsman 0.74/0.88; pace 0.88; respell table), per-citizen jitter +-4 % pitch and +-3 % rate from FNV-1a of the npc id, the... *[verify: voice.pitch_filter_keeps_duration]*
6. tools/voice/build_index.py scans every CSV for keys ending _V, derives voice/<npc_id>/<slot_n>, writes the generated lua/dialogue/_voiced_social.lua (kind = config, key voiced_index, one { text_key, voice_key } literal block per row, header 'generated, do not edit') so LocalizationManager.voiced_keys and tests/loc_check.gd see CSV-selected lines with no e... *[verify: voice.index_matches_csv]*
7. generate_voice.py --only-index [--workers 4]: idempotent through the manifest, RECORDED.txt lines are never regenerated or edited, AIFFs deleted, a TTS line whose text changed is regenerated in the same commit (a forgotten run fails loc_check voiced-hash); the 11 human lines convert unchanged; the bulk bake of the C1/C2 rows is a lead action after P26's a... *[verify: voice.generator_idempotent]*
8. docs/voice_lines.md documents the cue table, the surface table, the presets, the _V rule and how to drop in a real recording or a real tune by file name *[verify: voice.docs_list_cues_presets_and_V_rule]*
9. SFX hooks from the social game_events (cue log, no files needed): social_points with a whole-heart gain -> sfx/heart_up, gift_given -> sfx/gift_sparkle, town_festival_started -> sfx/festival_horn (and music/festival_<season>), town_festival_ended -> the festival music fades back to the area's ambience (the placeholder music cue stops), relationship_change... *[verify: voice.social_cues_logged, voice.social_voice_rows_in_index]*
10. the door cues of the integration track's audio_map also play on the three closed whispers (a soft knock for HOURS_CLOSED_NOW / DAY / FESTIVAL) and the closing bell for game_event shop_open_changed {open false} while the player is inside the shop; cue names are the integration track's, only the event hooks are added *[verify: audio_town.closed_door_knock_and_closing_bell_hooks]*
11. EXTENDED: voice lines for DLG_FARMINTRO_PIP_1..3 and _BYE_1..2 under voice/postman_pip/ (preset of Pip), farm ambience cues (wind in leaves by day, crickets at night, a bell for the bin payout = sfx/bin_bell on game_event bin_payout) as hooks of audio.lua (area ambience farm_day / farm_night); missing files stay silent *[verify: voice.farm_intro_lines_generated_when_asked]*
* size: grows from M to L (design2 already added the 16 dungeon cues); the seam for a split, if wave 6 needs relief, is: A = AudioDirector, Surface, Footsteps, audio.lua, the three synth tools and tests/sections/audio_town.gd; B = voice presets, the _V index, generate_voice.py --only-index, manifests, docs/voice_lines.md
* note: Four tracks add tasks to this package; the cue names are unique per track (dungeon: pickup_soft ... appraisal_reveal; town: shop_bell ... town_bell; social: heart_up, gift_sparkle, festival_start, stage_up; farm: bin bell). A missing audio file is always silent, every call is logged in AudioManager.cue_log.

**RT32 P25-docs-refresh** (wave 6, unbuilt; sources: integration, social, towns)

1. docs/howto/ gets ONE tested set (each how-to runs in a temp project copy like the quest how-to, with the SAME fixture files as the town loop's L18 legs, tests/fixtures/town/**): add_a_citizen.md (npcs.lua row incl. friendship = true, routine file, citizens + gift_tastes rows, dialogue Lua or none, CSV rows, archetype and voice preset), add_a_shop_interior... *[verify: docs.howto_add_a_citizen_runs, docs.howto_add_a_shop_interior_runs, docs.howto_add_a_festival_in_temp_project, docs.howto_add_a_heart_event_in_temp_project, docs.lua_api_lists_social_and_towns]*
2. README controls table generated from the live InputMap including `people` (P) and the pad rows of the pause menu *[verify: docs.readme_controls_match_inputmap]*
* note: Merges three overlapping lists (integration, social, towns): add_a_citizen / add_a_festival / add_a_heart_event were each promised twice.

**RT33 P26-loc-final** (wave 6, unbuilt; sources: integration, social, towns, farm)

* ownsAdd: `tests/sections/loc_final.gd`
1. scope per design_integration.md 4.3: besides the pruning and the strict gate it reads every ai_reviewed CSV for tone and terminology WITHOUT touching voiced keys (_V rows and lua/dialogue voiced keys: R.17), files defects of draft files back to the owning package, writes docs/copy/REVIEW_QUEUE.md; zz_final.csv never overrides a key of lua/dialogue/_voiced... *[verify: loc_final.zz_final_overrides_no_voiced_key (the new section tests/sections/loc_final.gd, P26's)]*
2. loc_check --strict is green with the new CSVs in key_owners.json (applied by the lead at the wave boundary, E2) and the 12 legacy stale-name rows of docs/copy/legacy_findings.txt fixed or deleted *[verify: loc_final.strict_green_after_legacy_fixes]*
3. Copy pass over the CSVs of the town, farm and social tracks (farm_signs, farm_site, farm_tutorial; towns, keepers, post; social_sys, social_talk, social_arch, gifts, birthdays, rel_ui, social_events, heart_events, festivals, partner): overrides only NON-voiced rows (R.17), status draft -> ai_reviewed (-> native_reviewed only by the user), strict key cover... *[verify: loc_final.town_farm_social_files_strict, loc_final.voiced_rows_untouched, loc_final.towns_families_reviewed, loc_final.farm_csvs_reviewed]*
* note: 

**RT34 P27-qa-acceptance** (wave 7, unbuilt; sources: farm, towns, social, integration, ui-repair; REPAIR of design_ui)

* ownsRemove: `docs/qa/farm/**`, `docs/qa/towns/**`, `docs/qa/social/**`, `docs/qa/town/**`, `docs/qa/ui_baseline/settings.png`, `docs/qa/ui_baseline/select_2.png`, `docs/qa/ui_baseline/saveload.png`, `docs/qa/ui_baseline/pause.png`, `docs/qa/ui_baseline/area_banner.png`, `docs/qa/ui_baseline/minimap.png`, `docs/qa/ui_baseline/animal_care.png`, `docs/qa/ui_baseline/build_menu.png`, `docs/qa/ui_baseline/home_chest.png`, `docs/qa/ui_baseline/intro.png`, `docs/qa/ui_baseline/confirm.png`, `docs/qa/ui_baseline/toasts.png`, `docs/qa/ui_baseline/prompt.png`, `docs/qa/ui_baseline/people.png`, `docs/qa/ui_baseline/gift.png`, `docs/qa/ui_baseline/calendar.png`, `docs/qa/ui_baseline/social_hud.png`, `docs/qa/ui_baseline/event_overlay.png`, `docs/qa/ui_baseline/post.png`
1. Acceptance rows 31-51 of this addendum are served by the sections of the four QA packages (zz_farm, zz_towns, zz_social, zz_town) and the town loop (L15 windowed suite): the acceptance run includes them and links docs/qa/town/TOWN_QA_REPORT.md *[verify: zz_acceptance.includes_town_farm_social_sections, zz_acceptance.links_town_qa_report]*
* note: Carve-outs: docs/qa/farm|towns|social|town (N08, T-qa, S-qa, I6). REPAIR of design_ui: its screen packages (P14, P16, P17, P19, P20, F7, P28) claim their baseline PNGs but P27's docs/qa/** still matched them; this lists the exact files (not the whole directory: baselines of screens whose package claims none, e.g. the shop panel, stay P27's) and the six baselines of this addendum.

**RT35 DL1-econ-store** (wave 4, unbuilt; sources: final-editor)

1. tests/sections/economy.gd (DL1's file since design2): `_fresh()` sets GameManager.set_config_override("towns.hours_enabled", false) right after t.new_game(), so the BUILT section runs without the towns' opening hours (measured in a clone: with the buildings registry loaded and no override 25 of its checks fail at the new-game clock Monday 06:00 - buy, sel... *[verify: economy.runs_with_towns_hours_disabled]*
2. economy.shop_save_validated pins the seed shop's carrot_seeds stock at 20: it follows the RT5 data change to 25 (the 110-plot dedicated field needs 19.2 carrot seeds a day and the shop is closed on Sundays) *[verify: economy.shop_save_validated_carrot_stock_25]*
* note: The fix of the built economy section lives HERE because design2 gave tests/sections/economy.gd to DL1 (wave 4, the same wave as T-towns-core whose buildings registry makes the 25 checks fail); RT5 (the fix-round of P12) touches no line of that file. Final edit, defect TE2.

**RT36 DR1-rules** (wave 4, unbuilt; sources: final-editor)

1. design2's contract guard (task 10, dungeon_run.no_new_input_action_signal_autoload) compares with the P01 / P02 contracts, not with the literals '11 + 5 autoloads, 35 actions, 75 signals': autoloads = 11 + FEATURE_AUTOLOADS.size(), actions = Contract.ACTIONS.size(), typed signals = core.signal_contract_exact; it asserts 'this package adds none', so the si... *[verify: dungeon_run.guards_compare_with_the_p01_contract]*
* note: Final edit, defect TE11 (conflict C38): design2's guard literals would have failed on this addendum's one autoload and one input action, which section 8.1 and 8.3 name.

**RT37 DQ-dungeon-acceptance** (wave 7, unbuilt; sources: final-editor)

1. zz_dungeon_exp E9 (the contracts row) compares with the P01 / P02 contracts (11 + FEATURE_AUTOLOADS.size() autoloads, Contract.ACTIONS.size(), core.signal_contract_exact) instead of the literals 16 / 35 / 75, and E1 (first trip: Skovlift to floor 1 and back) and E2 (gentle defeat wakes at the farm) are ALSO the REQUIRED chain checks that V4 no longer carr... *[verify: zz_dungeon_exp.E9_contracts_compare_with_the_p01_contract, zz_dungeon_exp.E1_E2_cover_the_v4_chain]*
* note: Final edit, defects TE11 and PL2 (conflicts C37, C38): the wave-7 acceptance of the dungeon track owns the chain that V4 dropped.
