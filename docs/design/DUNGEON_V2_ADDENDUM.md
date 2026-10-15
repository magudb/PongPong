# TRÆTOPPEN - Dungeon and v2 addendum: Mørkeskoven as a procedural chained-floor adventure area, weapons and gems as rarity categories, the Trætoppen city and the v2 cast

Status: BINDING addendum to `PLAN_2D.md` (+ its section R) and `PLAN_2D_FEATURES.md` (+ its decisions DF1-DF27). Written 2026-10-14 by the editor of the design panel; REVISION 2 by the final editor after four adversarial reviews (29 verified defects, section 0.4 and `CHANGELOG.md`). Where this file disagrees with the plan, the feature addendum or any of the four track documents, **this file wins**. Machine-readable work packages: `packages.json` next to this file (schema of `features_workpackages.json`). Ownership proof: `check_ownership.py` (output in section 12.5). Nothing in the repo or the lift was edited; every number below has a source (file:line of the repo, a track document, or a script saved under `design2/final_candidate/`).

Project root `/Users/magnusudbjorg/Documents/projects/PongPong`, engine Godot 4.7.2, GDScript, GL Compatibility, smooth hand-painted look (sprites BAKED from 3D at a 36 degree view, never pixel art), ALL player-facing copy Danish with English fallback, cozy chibi cast, the dark forest "uhyggelig-sød" (spooky-sweet). State: waves 1-3 are built and tagged (`wave-1..wave-3`, main at `2f6410b`); this addendum amends waves 4-7 before they start.

## 0. Preface: inputs, what the editor checked, how to read the track documents

### 0.1 Inputs

| Track | Designer | Document | Packages | Supporting material |
|---|---|---|---|---|
| generator (world structure, seeds, floors) | A | `design_generator.md` (15 sections) | `generator_packages.json`: D0 D1 D2 D3 + 15 amendments | `generator/` (prototype, 10 008-floor stress, mutants, gallery) |
| loot (rarity categories, weapons, gems, economy) | B | `design_loot.md` (15 sections) | `loot_packages.json`: DL1-DL8 + 13 amendments | `loot/` (Lua drafts, CSV drafts, Monte Carlo) |
| experience (combat, enemies, bosses, HUD, run feel) | C | `design_experience.md` (14 sections) | `experience_packages.json`: DX0 DX1 DX3 DX4 DX5 DX6 DX7 DX9 + 15 amendments | `experience/sim/` (1-D combat model) |
| v2 (cast, city, forest look, HUD mock) | D | `design_v2.md` (14 sections) | `v2_packages.json`: V1-V10 + 22 amendments | `v2_proto/`, `v2_scripts/` |

The four track documents stay in `design2/` as the RATIONALE (algorithms, tables, derivations). They are not rewritten; section 10 lists every statement of them that this addendum overrules.

### 0.2 What the editor re-checked (all scripts and raw outputs under `design2/final_candidate/`)

| # | check | result | source |
|---|---|---|---|
| 1 | Disjoint ownership of ALL packages (66 in the table: 28 new, 27 amended, the rest unchanged) by language intersection of every pattern pair, repo expansion of 3 509 tracked files (main at `ff802c7`, 0.5), `ownsRemove` sanity, dependency waves, `-> verify:` tags, named paths (check E now also flags a package that names a NEW path owned by a LATER package), cross-wave localization keys | 0 problems; 8 of 8 mutants of the merged file caught (two new ones: a write into a path of a later package, a re-claimed `assets/icons/dungeon/**`); the RAW union of the four track files had 0 pattern overlaps but 2 other defects (a same-wave dependency, a path owned by nobody) and the semantic conflicts of section 10 | `check_ownership.py` (`--raw`, default, `--selftest`, `--with-ui`), section 12.5 |
| 2 | The generator with the MERGED floor table (lake tier `noegle`, `hulen_keeper` anchors, three extra enemy kinds in the band mixes, no `odds`, no `hulen_marker`) | 1 200 floors: 0 failures, 0 violations of 46 invariants, 0 of 180 determinism mismatches, first attempt 88.7 %; 12 golden digests identical on macOS arm64 and x86_64 (RE-PINNED at `rim.wall_depth` 0 in row 8; the layouts are the same, only the rim ring of wall tiles is gone) | `gen_check/results/`, `gen_check/dungeon_final.lua` |
| 3 | A second 10 008-floor stress from a NEW seed range (first=1000, 834 floors per floor id) | **3 violations** (f1 i1550 `hulen_far_from_spawn` manhattan 21 < 22; f2 i1396 and f2 i1526 `tutorial_ambush`): the generator track's own run (seed range 0..833) had reported 0. Both rules were soft after attempt 4 or measured at another cell than the verifier. Fixed in the prototype by two HARD gates (`gen_check/proto_changes_dg2_gen.diff`, 38 lines); re-run: 10 007 floors verified with 0 violations and 1 floor that exhausted all 8 attempts (f2 i1396, 'nooks'; row 8 gives it the pinned fallback), 0 of 1 428 determinism mismatches, first attempt 88.5 %, mean 1.139 attempts; the golden digests of the first range are UNCHANGED by the gates | `gen_check/results/pregate_violations_original_generator.txt`, `stress10k_part_*.txt`, `stress_range0_f1f2.txt` |
| 4 | The four-boss alternative table (bosses 3 / 6 / 9 / 12, a stone on every floor) in the shipped marker mode (`warp`) | 480 floors, 0 failures, 0 violations, first attempt 87.5 % (re-run at `rim.wall_depth` 0: the same numbers, `final_gen/results/alt_table_depth0_480.txt`) | `gen_check/dungeon_alt_warp.lua`, `results/alt_table_warp_480.txt` |
| 5 | The one conflict with real money in it (loot C7: the generator's 45 crystal nodes per dive against the loot budget) | decided by SIMULATION with the loot track's own Monte Carlo and the plan's `balance_sim.py` unmodified: section 5.8 | `c7_sim/` |
| 6 | Localization keys named by a package before the CSV that defines them exists (cross-wave literals fail `loc_check`) | 3 real cases found and moved (hub sign, the `LOOT_*` and `LOOT_SURPRISE_*` rows, V3's prompts); 19 same-wave couplings are listed in 12.4 | `check_ownership.py` check F |
| 7 | Every repo API this addendum calls exists as written (`GameManager.total_day / sleep_until_morning`, `EconomyManager.spend_gold / equip / add_item`, `WorldRoot2D.register_map / unregister_map / has_area / travel`, `SaveManager.register_section(name, node, order)`, `EventBus.item_gained / rare_item_found`, `Player2D` callers `heal_half / add_oil / restore_stamina / revive`) | read at `2f6410b`; the editor's pass added `GameManager.pop_all_modals`, `SaveManager.autosave`, `EconomyManager.can_add_item`, `IsoArea._handler_api` (`create_marker` of arity 4 is picked first), `ArtCatalog.ICON_DIRS` / `TTItemIcon.DIRS` (items, home, wardrobe), `GameUI.SCREEN_ORDER` (16 entries, pinned) | `scripts/autoload/*.gd`, `scripts/world2d/world_2d.gd:117-150, 472, 636-699`, `scripts/world2d/iso_area.gd:169-190`, `scripts/world2d/art_catalog.gd:24`, `scripts/ui/components/tt_item_icon.gd:22` |
| 8 | **The editor's final pass (after four adversarial reviews, 29 verified defects, section 0.4)**: the pinned FALLBACK floors of the generator on all 12 specs and on the one real exhausted floor; both 10 008-floor ranges re-run on the FINAL table (`rim.wall_depth` 0, fallback seeds); x86_64 against arm64 digests | fallback: 12 of 12 specs forced through the fallback pass the verifier (797 checks, 0 violations), f2 i1396 passes through it; stress range 0..833: 10 008 floors, 0 failures, 0 violations, 0 of 1 440 determinism mismatches, first attempt 88.8 %; range 1000..1833: 10 008 floors, 0 failures, ONE fallback (f2 i1396), 0 violations, 0 of 1 428 mismatches, first attempt 88.5 %; four-boss table 480 floors 0 violations; digests identical on arm64 and x86_64 (Rosetta) | `final_gen/` (`run.sh`, `stress10k.sh`, `results/`), `gen_check/proto/find_fallback.gd`, `fallback_check.gd` |
| 9 | Probes in clones of the repo with the real world scene (headless) and the GL Compatibility renderer (windowed, one window) | (a) a leave issued while the pause modal is open does not travel (2 s later the same area), after `pop_all_modals` the area changed in 219 ms and settled in 428 ms; (b) the 16-light cap per canvas item: in four runs of the same sweep the lantern was dropped from 15 or 16 other lights on (created last) or from 17 or 20 on (created first), or not at all, never at <= 14 other lights; child index and tree order do not decide it; (c) an icon in `assets/icons/items/` resolves in `ArtCatalog.icon_path` and `TTItemIcon.resolve_path` (also the `_night` file), one in `assets/icons/dungeon/` did not | `final_probes/` |
| 10 | The economy re-run with the FINAL data (the loot track's Monte Carlo and the plan's `balance_sim.py` through the review's free-furniture hook; 80 saves per profile unless stated): dng_ materials at their real price, the daily cap on the rarity-restricted sources, the corrected appraisal EV, the two-phase delivery, the pace dials | section 5; typical castle day 246 (keep) / 201 (free furniture replaces bought furniture); cap 3 200: P(cap before floor 10) 5 % at luck 0; two-phase: 0 items delivered by 1 000 retries on a full pack, 0 lost keepsakes in 3 000 fuzz runs | `final_sim/` (`sim/`, `results/`) |
| 11 | The recipe cost band with ONE written valuation rule at three multipliers (2.0, 2.2, 2.5) | 13 of 13 recipes in the 45-85 % band (the moonshard recipe widened: 0.497 / 0.509 / 0.528, was 0.442 / 0.454 / 0.473) | `final_sim/sim/recipe_band.py`, `results/recipe_band_final.txt` |

### 0.3 Package id map (track ids -> ids of this addendum)

| track id | final id | note |
|---|---|---|
| D0 D1 D2 D3 | `D0-dungeon-world-hooks` `D1-dungeon-gen` `D2-dungeon-floors` `D3-dungeon-qa` | D1 now also owns `localization/dungeon.csv`; D2 no longer owns it |
| DX0 DX1 DX3 DX4 | `DR0-pickups-fx` `DR1-rules` `DR3-enemies` `DR4-bosses` | prefix DX renamed DR ("dungeon run") because the decision register of this addendum is DX1.. |
| DX5 + DX6 | `DR5-forest-hud` | the forest HUD and the loot reveal / cues are one package now |
| DX7 | `DR7-dungeon-services` | moved from wave 5 to **wave 4** (NPC rows and dialogue name its shop and quests) |
| DX9 + DL8 | `DQ-dungeon-acceptance` | wave 7: experience rows E1-E10 and the loot dive in one package |
| DL1 DL2 DL4 DL5 DL7 | unchanged | |
| DL3 | `DL3-weapon-code` | moved from wave 4 to **wave 5** (nothing in wave 4 needs it; it is where the real-player wiring is verified) |
| DL6 | `DL6-loot-icons` | moved from wave 5 to **wave 6** (only DQ in wave 7 depends on it; relieves wave 5, 12.3); installs into `assets/icons/items/`, not `assets/icons/dungeon/` |
| V1 ... V10 | unchanged | V3 gained `localization/levels.csv`, and (from V4, plan review 27) `data/traetoppen/traetoppen.json` and `lua/config/traetoppen.lua`; V4 now depends on D2; V5 depends on V3 |

### 0.4 What the final editor changed: the 29 verified review defects and where each is resolved

Four adversarial reviews (economy, technical, plan, experience-readability) found defects that were verified with evidence. Every blocker and major defect and every cheap minor one is fixed in place; the full list with the reason of each decision is `FINAL/CHANGELOG.md`. Short map:

| # | lens | defect | resolved in |
|---|---|---|---|
| 1 | economy, major | partial delivery of a multi-roll container replays on every retry (retry faucet; boss shard burned by a full pack) | 5.7 two-phase delivery, DL5, F4, D2, DQ; DX53 |
| 2 | economy, major | dng_ materials (dust 22 gold) had no sink: the 0.35 share was an assumption of the model, not of the data | 5.6 prices, DL2, DL4 rule M2 / P1; DX30 |
| 3 | economy, minor | free furniture replaces bought furniture: the pace was understated | 5.9 and open question 1 (corrected, with a measured dial table) |
| 4 | economy, minor | the 1 400 cap burned by floor 7-9 and made the deepest stone strictly best | 5.7, `dungeon_loot.daily`, 2.6.3; DX38 |
| 5 | economy, minor | luck-0.2 appraisal gains were wrong (no clamp) | 5.5, S16, `appraisal_ev.py` |
| 6 | economy, minor | one shared appraisal stream for all bands / luck levels | 5.5, DL5 (per-band streams, commit before reveal); DX54 |
| 7 | economy, minor | stale boss pool constants (8 % / 10) in the DL5 task | DL5 reads `legendary_bp` / `pity_kills` from data |
| 8 | technical, major | dungeon icons in `assets/icons/dungeon/`, a directory no lookup reads | 8.11, DL6, RD.2 carve-out of P23; DX55 |
| 9 | technical, major | the generator's fallback template was not prototyped and could not pass the verifier | 3.5, 3.6, D1 task 5; DX56 (pinned verified seeds, measured) |
| 10 | technical, minor | leave from the pause menu stalls under the pause modal | 2.6, P16, D2 (`pop_all_modals`, measured) |
| 11 | technical, minor | "lantern = first light" by child index does nothing | 3.4, P06 (budget instead, measured) |
| 12 | technical, minor | `Enemy2D.create(params)` receives no cell and no area | 8.9, DR3, P19 (`create_marker`) |
| 13 | technical, minor | weapon damage rounding (40.5) | 5.4, DL2 check (tolerance 0.5) |
| 14 | technical, minor | recipe cost band depends on how an unbuyable ingredient is valued | 5.4, DL2, DL4 W5 (one rule, three multipliers) |
| 15 | technical, minor | check ids named 52 | DL2 / DL6 ids say 51 |
| 16 | technical, minor | `swap_day == today` had no context key | P14 context `total_day`, V7 |
| 17 | technical, minor | the lake chest tier has no prop art | P22 `chest_noegle`, F4 fallback, S20 |
| 18 | technical, minor | nobody flips `rim.wall_depth` | D1 ships 0; digests re-pinned; DX16 |
| 19 | technical, minor | no whole-run test budget | 15.6, P27 |
| 20 | plan, major | DL4 deleted `map_markers.json`, which P11's wave-4 check reads | DL4 trims it to farm + hyggebyen (RD.2, DL4 task 1) |
| 21 | plan, major | P23's wave-4 check red until DL6 (wave 5) | P23 pending rule, 12.4; DL6 moved to wave 6 |
| 22 | plan, major | icon directory unregistered in two built files (= 8) | see 8 |
| 23 | plan, major | nothing instantiated the appraisal screen | F4 LootService hosts it (no SCREEN_ORDER edit); S21; DX57 |
| 24 | plan, major | smithy rotation breaks `economy.gd:961` | DL1 task 4, 12.4 |
| 25 | plan, major | P26's loc checks had no section file | P26 owns `tests/sections/loc_final.gd` |
| 26 | plan, minor | check E direction bug; DL6 wrote into DQ's directory | `check_ownership.py` check E, selftest mutant, DL6 path |
| 27 | plan, minor | V5 / V6 / P13 read V4's data (wave 5b) | V3 owns the city JSON and config (wave 4); DX58 |
| 28 | plan, minor | stale or homeless verify ids | D0, P18, P24, D3, P03 (levels.csv) |
| 29 | plan, minor | wave overload mitigation did not apply | 12.3 (points per wave), 13.1, DL6 to wave 6 |

### 0.5 The repo moved on (read before the first wave starts)

This addendum was written against `2f6410b` (waves 1-3). Main is at `ff802c7` now: a parallel stream merged the UI navigation spec (`docs/design/UI_NAVIGATION.md` v1.1, `docs/design/ui_workpackages.json`, the audit library `tests/lib/ui_audit*.gd`, sections `ui_audit*`). It adds a package **P28-ui-nav-foundation** (wave 3b), moves **P17** from wave 5 to 4 and amends P16 P17 P18 P14 P19 P20 F7 F8 P25 P26 P27. `python3 -I check_ownership.py --with-ui` layers that file over this addendum's table: **0 problems involve a new package of this addendum** (A, B, D, E, F); 47 problems are inside the UI stream's own file (P07 against P28 on the components and the theme, P14 against P07 on `localization/ui.csv`, P27's `docs/qa/**` against the new `docs/qa/ui_baseline/**`, P17's wave move against its dependencies) and belong to that stream. Not applied here, to be decided by the lead when the two streams merge: the screens of THIS addendum (`rune_picker` of D2, `appraisal_ui` of DL7, the forest HUD of DR5 which was carved out of P19, the pause row of P16) fall under the same navigation rules (focus map, hints, `UiConfirm`) and would depend on P28 and be listed in `tests/lib/ui_screens.json`.



## 1. The user's decisions (binding, 2026-10-13) and where each one is realised

| # | decision | realised by | section |
|---|---|---|---|
| U1 | MØRKESKOVEN IS A PROCEDURAL DUNGEON-STYLE ADVENTURE AREA where the player can get rare, unique and legendary items: furniture, weapons, materials and gems (weapons and gems are NEW rarity categories next to furniture / clothing / materials) | generator D1 + D2; loot DL1-DL7 (weapons 24 ids in a new store `Arsenal`, gems 18 new ids + Fru Ugle's appraisal, materials 11 new ids, the existing 226 furniture + 96 garments in the band pools) | 3, 5 |
| U2 | STRUCTURE = CHAINED FLOORS: each floor is a generated top-down night clearing with winding paths, ponds, chests and enemies; the cave "Hulen" leads to the next, harder floor; runestones are checkpoints (and quest triggers); a boss every few floors; the player can leave any time and keeps all loot; deeper floors drop better rarities; a new seed every day | 12 floors in four bands, Hulen = walk-in warp, runestones on floors 3 / 5 / 7 / 9 / 11, bosses on 4 / 8 / 12, leave from the pause menu and the arrival caves, depth ladder on chest odds, seed = (save, day, floor) | 2, 3, 4, 5 |
| U3 | DEFEAT IS GENTLE: pass out in the dungeon -> wake at home the next morning, keep every item, lose 10 % of the gold | D0 + DR1 `after_defeat`; gold loss `floori(gold * 10 / 100)`, never capped | 2.6, 6.8 |
| U4 | TWO PLACES: Trætoppen is the whole treetop settlement (the isometric sketch: seven giant trees, market square + town hall in the middle tree, post office, Hoppe's hut, Brumme's workshop, bathhouse, kitchen gardens, rope bridges, owl holes, hanging bat houses) and Hyggebyen (the district's retired earlier name is never written) is the fairy shopping district inside it with its own zone; the player's farm "Min Trækronsgård" is on its own branch | areas `traetoppen` (city builder, V3 / V4 / V5 / V6), `hyggebyen` (grid area, zone id `city`, P11), `farm` (zone `farm`); the Skovlift of the city is the way down | 2, 7 |
| U5 | The Style Guide v2 sketches are BINDING design input (13 characters; the treetop city isometric by day; Mørkeskoven top-down by night; the guide's UI look) | V1-V10; section 7 and the coverage matrix of `design_v2.md` 11 (executable as `docs/qa/v2/sketch_coverage.json`) | 7 |
| U6 | Earlier standing rules: rarity tiers normal / uncommon / rare / unique / legendary (Almindelig / Ualmindelig / Sjælden / Unik / Legendarisk); unique and legendary furniture / clothing are only FINDABLE (never buyable / craftable), unique = at most one per save; Lua extensibility for quests / data; all copy in localization CSVs; honest stubs, no half-wired features; tests: headless sections + windowed checks | applied to the new categories too: unique and legendary weapons, gems and materials are keepsakes (buy 0, sell 0, protected, one fixed source, registry `loot.dungeon.found`); copy only in CSVs (families in 8.10); section 14 lists every stub; section 15 the tests | 5, 8, 14, 15 |

The retired earlier name of the fairy district appears in no file this addendum creates (test `loc_final.no_old_town_name`, `cast_data.no_old_town_name_anywhere`, `zz_v2.no_old_town_name_anywhere`).


## 2. Zone graph and travel (ONE graph for the generator, the city and the experience tracks)

### 2.1 Areas

| area id | file / source | kind | zone id | `@title` key (shown) | ambient / theme | flight | clock / HUD | owner |
|---|---|---|---|---|---|---|---|---|
| `farm` | `data/maps/farm.map` | iso grid, own platform | `farm` | `ZONE_FARM` ("Min Trækronsgård") | farm / farm | yes | runs / farm HUD | P11 (+ F6 growth) |
| `home` | `data/maps/home.map` (builder) | iso builder | `farm` | `HOME_WORLD_TITLE` ("Dit hjem") | home / home | no | runs / farm HUD | F6 (unchanged) |
| `traetoppen` | `data/maps/traetoppen.map` + `data/traetoppen/traetoppen.json` | iso LEVELLED builder (8 platforms, 9 bridges, ladder, rope lift) | `traetoppen` | `ZONE_TRAETOPPEN` ("Trætoppen") | farm / treetop | **no** | runs / farm HUD | V4 (+ V3 framework, V5 art, V6 life) |
| `hyggebyen` | `data/maps/hyggebyen.map` | iso grid 40 x 40 | `city` (id kept, shows "Hyggebyen") | `ZONE_CITY` | hyggebyen / hyggebyen | yes | runs / farm HUD | P11 |
| `moerkeskoven` (the HUB "Skovkanten") | `data/maps/moerkeskoven.map` (hand-authored, 40 x 30 play area) | ortho, static | `dark_forest` | `ZONE_FOREST_EDGE` (exists: "Skovkanten") | forest / forest | no | PAUSED / action HUD | P11 (+ D2 for the Port-runen, V8 for the dress) |
| `moerkeskoven_f1` ... `_f12` | generated text, `WorldRoot2D.register_map` at run time | ortho, generated | `dark_forest` (f1-f6), `mushroom_grove` (f7-f9), `crystal_cave` (f10-f12) | `ZONE_DARK_FOREST`, `ZONE_DYBE_BREGNER`, `ZONE_MUSHROOM_GROVE`, `ZONE_CRYSTAL_CAVE` + the depth chip `· N` | forest (f1-f9), cave (f10-f12) | no | PAUSED / action HUD | D1 (text), D2 (registry) |

A generated id never exists at boot (the registry is a static dictionary): the farm, Hyggebyen, the city, every quest, NPC anchor and save know only the hub id `moerkeskoven`; `area.warp_roundtrips`, `maps_iso.connectivity` and the shot tour exempt targets that start with `moerkeskoven_f`.

### 2.2 The graph (decision DX2: the Skovlift is the ONLY way in and out)

```
 Min Trækronsgård (farm)  ==hængebro (plank bridge)==>  traetoppen  (levels A B C Torvet Upper E F G; 9 bridges; ladder)
   spawns default from_home                                |  spawns default from_farm from_hyggebyen from_skovlift
   from_traetoppen                                         |
                                                           +==bridge from tree F==>  hyggebyen  (spawns default from_traetoppen)
                                                           |
                           Skovlift = the rope basket at the rim of tree B, guard Oak, E -> 1.6 s ride
                                                           v
                                    moerkeskoven "Skovkanten" (HUB)   spawns default = from_traetoppen, from_floor
                                       |  ONE gate arch -> traetoppen:from_skovlift
                                       |  Port-runen (rune_hub): picker "Fra begyndelsen" + every lit stone
                                       |  Hulen mouth (warp to moerkeskoven_f1)                ^ up cave of floor 1 (warp to moerkeskoven:from_floor)
                                       v                                                       |
   f1 -> f2 -> f3[stone] -> f4[BOSS 1] -> f5[stone] -> f6 -> f7[stone] -> f8[BOSS 2] -> f9[stone] -> f10 -> f11[stone] -> f12[BOSS 3, home rope instead of a Hulen]
   down = Hulen (walk-in warp, prop cave_ring, sealed by roots until the boss falls on 4 / 8 / 12)     up = the arrival cave of each floor (prop cave_ring_up)
```

* Removed: the farm's NW stone gate (Skovport) and every `skovkant` warp, Hyggebyen's west gate (Oak), the generator draft's three hub gates (farm / Hyggebyen / city) and its spawns `from_farm` / `from_hyggebyen`, the plan's four hand-authored forest maps `skovkant dybe_bregner svampelunden krystalgrotten` (they are the four BANDS now), the run's `origin` bookkeeping (leaving always goes to the hub).
* The farm bridge lands on tree G (east rim), the Hyggebyen bridge leaves from tree F (west rim), joined over bridge B8: farm gate -> Hyggebyen gate 3 154 ground px = 11.1 s walking (7.0 s running), farm gate -> Skovlift 15.7 s (`design2/v2_scripts/city_paths_output.txt`, K = 3.0).
* The Skovlift is the v2 track's reading of the unlabelled rope basket of the city sketch (open question 10); `adventure.dark_forest_unlock_day` (default 1) is read by the lift exactly as the old gate's `req_day` was.
* Guard **Oak** (`guard_oak`, `home_area = traetoppen`) stands at the Skovlift. **Fru Ugle** (`appraiser_fru_ugle`) lives in the FIRST OWL HOLE of tree A (reach 420 px, talked to from bridge B2): the hub has NO npc slot. **Natteblik** (`mapseller_natteblik`, `home_area = moerkeskoven`) stands beside the Hulen of floors 2 / 6 / 10 through the anchor marker `hulen_keeper npc=mapseller_natteblik` (night entry: the NPC; day entry: a hanging bat sprite and the whisper `LOOK_NATTEBLIK_SLEEPS`; the clock is paused in ortho areas, so "night" is the hour of ENTRY: the evening dive rhythm of the experience track).

### 2.3 Spawns and warps (exact names; every warp round-trips; checked by `maps_iso.warp_roundtrips`, `city_map.every_warp_round_trips`, `zz_v2.zone_graph_walk`)

| area | spawns | warps out |
|---|---|---|
| `farm` | `default` `from_home` `from_traetoppen` | bridge -> `traetoppen:from_farm` |
| `traetoppen` | `default` (Torvet, beside the fire pit) `from_farm` (tree G east rim) `from_hyggebyen` (tree F west rim) `from_skovlift` (rim of tree B at the rope) | bridge G -> `farm:from_traetoppen`; bridge F -> `hyggebyen:from_traetoppen`; Skovlift ride -> `moerkeskoven:from_traetoppen` (`area_change_requested`; whisper `TRAE_LIFT_CLOSED` only if `has_area` is false) |
| `hyggebyen` | `default` `from_traetoppen` | east bridge -> `traetoppen:from_hyggebyen` |
| `moerkeskoven` | `default` (= `from_traetoppen`, in front of the gate) `from_floor` (beside the Hulen mouth) | gate -> `traetoppen:from_skovlift`; Hulen -> `moerkeskoven_f1:default` |
| `moerkeskoven_f<N>` | `default` (arrival clearing) `from_down` (two cells before the Hulen, only when the floor has one) `rune` (beside the runestone, only on stone floors) | Hulen -> `f<N+1>:default`; up cave -> `f<N-1>:from_down` (floor 1: `moerkeskoven:from_floor`); floor 12: home rope -> `moerkeskoven:from_floor` |

### 2.4 Names (core.csv, owner V1)

`ZONE_FARM` "Min Trækronsgård" / "My Treetop Farm" (was "Trætoppen"; the pin in `tests/sections/loc.gd` moves with it), `ZONE_TRAETOPPEN` "Trætoppen", `ZONE_CITY` "Hyggebyen" (zone id `city` stays: renaming it would touch GameManager defaults, `core.gd`, `area.gd`, `loc_check.gd`, the F1 validator and four quests for no player-visible gain), `ZONE_FOREST_EDGE` "Skovkanten" (hub), `ZONE_DARK_FOREST` "Mørkeskoven", `ZONE_DYBE_BREGNER`, `ZONE_MUSHROOM_GROVE`, `ZONE_CRYSTAL_CAVE`. The forest HUD chip reads `tr(@title) + " · " + @depth` of the floor's own header: "Mørkeskoven · 2", "Dybe Bregner · 5", "Svampelunden · 8", "Krystalgrotten · 11" (no new key). `FIND_AREA_FARM` and `CHAR_HOBBIT_NAME` ("Halvling") are overridden in P26's `zz_final.csv`.

### 2.5 The hub (P11 authors it from the generator's draft)

40 x 30 ortho area, ambient forest, no enemies, no oil drain: ONE gate arch (`warp_gate_stone`) to `traetoppen:from_skovlift`, the Hulen mouth, the **Port-runen** (`runestone id=rune_hub hub=1`, always lit; `E` opens the rune picker with the checklist lines of `DungeonRun.picker_lines`), a sign (`SIGN_MOERKESKOVEN_HUB` "Her begynder Mørkeskoven. Husk lygten."), a whisper zone (`SIGN_MOERKESKOVEN_WHISPER` "Her dufter af vådt mos og gamle eventyr."), one `forest_dress` marker, 3 glow lights, rim crowns. The three strings are rows of P11's own `areas.csv` so the hub never names a key of a later wave.

### 2.6 The flows

1. **First trip** (acceptance row E1): farm -> bridge -> Torvet -> Skovlift (Oak offers `skovlift_intro`) -> 1.6 s ride -> hub (hint `DTUT_HUB`) -> Hulen -> floor 1 (banner "Etage 1 / Skovkanten", lantern hint) -> ... -> floor 3 stone (heal, oil, autosave, quest objective) -> pause row "Forlad Mørkeskoven" (confirm) -> hub -> three summary toasts -> gate -> Skovlift top.
2. **Leave any time**: the pause row (every floor; the confirm and the pause menu are closed with `GameManager.pop_all_modals()` BEFORE `leave()` runs: measured, a request issued under the pause modal does not travel until the modal is closed, after the pop the area changed in 219 ms), the arrival cave (one floor up; floor 1 -> hub), the home rope after the last boss. Everything found stays found; the same day the SAME floors come back with every consumed chest, enemy, node and dig spot still consumed; a new day = new floors.
3. **Runestones are waypoints**: the Port-runen offers "Fra begyndelsen" and every lit stone (`DungeonFloors.start_floors() = [1] + stones`); stones are permanent across days (open question 6); there is NO fast travel between stones inside the dungeon. Consequence, measured (`final_sim/results/17_start_floor_final_luck*.txt`, clear-all day, luck 0): starting at the deepest lit stone (floor 11, 10 minutes) pays the same gold per minute as a clear-all from floor 1 (50 against 49) and about twice the rare items per hour (19.8 against 10.4), but a clear-all day pays four times the gold and 2.3 times the rare items per DAY (2 178 gold and 7.7 rare items against 523 and 3.4), so floors 1-10 stay worth playing and the stones are a convenience, not a dominant strategy (the first design's cap of 1 400 on every source made starting deep strictly best, 5.7).
4. **Save in a floor, quit, load**: the section `dungeon` regenerates and registers floors N-1..N+1 BEFORE `WorldRoot2D._ready` reads `pending_world`; vitals are not saved (a loaded floor starts with full hearts and a refilled lantern: a save is a rest).
5. **Defeat**: see 6.8. The player wakes at `farm:from_home` the next morning.
6. **Day change** while outside: `day_started` clears `done`, `seen`, `reveal` and unregisters the floors; `stones` and `deepest` stay.

### 2.7 Quests and anchors that name a place (all re-checked; P13 / D0 / DR7 / V1 own the edits)

| quest | binding today | new binding |
|---|---|---|
| `intro_lottery.cross_bridge` | zone `farm` bridge | `zone_entered traetoppen` |
| `snurresvampen.enter_dybe_bregner` | `area_changed dybe_bregner` | `area_changed moerkeskoven_f4` (D0; the objective's text stays true: floor 4 is the first Dybe Bregner floor) |
| `snurresvampen.defeat_snurresvampen` | `enemy_defeated kind snurresvamp` | unchanged (the floor-4 boss keeps the id) |
| `lost_cat` | Mis lives in Dybe Bregner | Mis lives in Hyggebyen (`when=done:lost_cat`); the forest marker is a nook anchor on floor 5 (`when=quest:lost_cat`); paw prints stay on the farm bridge |
| `dark_forest_mining`, `forest_patrol`, `crystal_cave` | `zone_entered` of the zone id | unchanged (floors carry the four zone ids; `zone_entered` repeats are harmless: every objective has target 1) |
| `night_flower` | `night_bloom` nodes `when=night` | floor 2 anchor |
| `rare_mushroom_hunt` | manual `find_glowing` | `quest_spot` on floor 7 |
| `moonstone_crown` | `item_gained moonstone` | unchanged (moonstone from appraisal / chests / the wizard's slot, section 5.8) |
| NEW `skovlift_intro`, `rune_vandring`, `ugles_noegle`, `bossernes_vej` | - | DR7, section 6.6 |


## 3. The generator and the run (D1 + D2; rationale and algorithm detail in `design_generator.md` 3-7, 9)

### 3.1 What is generated, and when

A static hub (2.5) plus **12 generated floors** `moerkeskoven_f1 .. f12`. Each floor is AreaMap TEXT (`@id ... @ground ... @objects`, 8-19 KB, 20-32 object chars out of a 77-char pool) produced by `DungeonGen.build_text(cfg, floor, floor_seed, ctx)` (pure, integer only, scene-free, callable from a `WorkerThreadPool` task), parsed by the BUILT `AreaMap.parse_text`, registered with the BUILT `WorldRoot2D.register_map`, entered by the BUILT `_enter`. No change in `area_map.gd`, `iso_area.gd`, `warp_2d.gd`. The floor AFTER the current one is generated ahead on a worker thread and registered ahead (floors N-1 and N+1 are always registered; older ones are unregistered), so the plain built-in `warp` marker works as the Hulen and `travel()` never sees an unknown id.

Pipeline (one pass per attempt, 8 attempts, deterministic retry seeds): sites on a jittered grid (entry clearing in column 0, exit clearing in the last column) -> boss arena (last column, one clearing of about 13 x 23 cells) -> Prim spanning tree over aspect-corrected distance `3dx^2 + dy^2` + up to n/3 loop edges -> winding trails (centre line + two-octave lateral value noise; main route brush 3 x 5, ~2.9 cells wide, ground char `p` / `x`) -> ponds (ellipses `0.6 rx x 0.5 ry`, char `~`) -> island repair -> nooks (1-wide spur + diamond pocket cut into the wall; host the unique spots, quest anchors and hidden chests) -> features in the fixed order (spawn, up cave, runestone + `rune` spawn, Hulen + `from_down` spawn or home rope, boss + sealed chest, nook contents, lake chest on a pond shore, ordinary chest, ambush spots, enemy groups, critters, nodes, glow patches + lights, digs, whispers, anchors) -> deterministic mirror in x / y (before the canopy) -> inner crowns -> decor -> final repair -> validate (hard every attempt, soft attempts 1-4) -> export (pad +4 / +3 north / +9 south, rim crowns, char allocation).

### 3.2 Seeds (exact; ONE world seed per save, owned by the generator; the loot track has no second seed)

```
world_seed     62-bit integer, saved as DECIMAL TEXT, made once by DungeonFloors.reset(): hash_key("newgame", unix_time_s, ticks_usec); tests call set_world_seed(int)
seed_day       GameManager.total_day(), captured by start_run() and PINNED while the run is active
floor_seed(n)  hash_key(world_seed_text, seed_day, n)
attempt k      k = 0: floor_seed(n);  k >= 1: hash_key("retry", floor_seed(n) & 0xFFFFFFFF, k)   (k < 8)
purpose seed   hash_key(world_seed_text + "|" + purpose, seed_day, floor * 65536 + cell_index)   purpose in {chest enemy node dig boss drop spot}
keyed stream   hash_key(world_seed_text + "|" + stream, 0, key)     (DungeonFloors.rng_keyed: appraisal counter, boss pool; independent of day and cell)
cell_index     y * map_width + x of the PADDED map; uid = "dg:<day>:<floor>:<cell index>"
hash_key       FNV-1a 32 in two lanes + murmur3 fmix32 with an overflow-free 32-bit multiply, masked to 62 bits;  RNG = sfc32 (16 warm-up draws, rejection sampling); no engine RNG, no float but IEEE sqrt
```

Same save + same day + same floor = the same text byte for byte on every process and CPU (golden digests, 3.6). A new day is the ONLY way to a new layout, so reloading cannot re-roll anything: chest contents, drops, spots and boss pools are pure functions of these streams plus saved pity / cap / cooldown state (1 distinct outcome in 1 000 reloads, `loot/results/abuse.txt`). A change of `gen_version` or of the layout-relevant Lua (`spec_hash` over floors + bands + rim + limits, `odds` do not exist any more) drops the running dungeon (delta lists), keeps `stones`, `deepest`, loot and gold, and toasts `DUNGEON_RUN_RESET` once.

### 3.3 Output text and marker vocabulary (what the generator emits; who builds it: section 8.9)

Header extras: `@floor @band @day @seed @gen @spec @flip`; standard header: `@id @title @projection ortho @ambient @theme @zone @depth @flight false @music`. Terrain chars: bands 1-3 floor `m`, glow patch `g`, lit path `p`; band 4 floor `c`, patch and path `x`; pond `~`; rim `W` (depth `rim.wall_depth`), void `#`. Per-instance data is NOT in the text: handlers derive it from the cell and the header extras.

Props the generator references (P22 bakes them, placeholders until then): `crown_{s,m,l}_{a,b}` (rim canopy, not solid), `crown_{s,m}_{a,b}_solid` (free-standing, collider circle r 130 / 175 ground px, `art =` the rim crown of the same size), `cave_ring`, `cave_ring_up`, `home_rope`, `rock_dark`, `bush_forest`, `glowmush_teal`, `pond_lily`, `runestone_dormant`, `runestone_active`, `bush_eyes_a`, `bush_eyes_b`.

### 3.4 The look (v2 sketch "Mørkeskoven, set oppefra, nat")

* **Rim = void + canopy.** The rim of every floor is void plus tree-crown props (sphere = circle under any camera, baked at the project's 36 degrees: no new bake mode). **`rim.wall_depth = 0` from the start** (D1 ships the table with 0; the first draft planned 1 'until the crowns are baked' and a flip that no package owned, which would also have changed `spec_hash` and the 12 golden digests later; measured -1.0 .. -2.1 ms render; the iso fallback uses `wall_depth_iso = 0`, `_enter` 35 / 40 / 61 ms instead of 73 / 73 / 145 with a ring of wall tiles). Crowns never cover a marker, the spawn or a Hulen (disc geometry `crown_covers`, R 170 / 230 / 300 px, sphere centre 0.81 R above the anchor, verified on every floor); the canopy fade (D2, alpha 0.45 in 0.15 s for a crown whose disc contains the player) is the safety net.
* **ForestDress (V8) is attached by D2 on `area_ready` of every generated floor** (and by a `forest_dress` marker in the hand-authored hub): every actor of the floor is UNSHADED (the fox `e07b3c` would be `432d1f` under the night grade `4d5e85`), one CPU firefly field (40 particles), two mist decals, a light-budget assertion (at most 10 glow lights + the runestone's one; a 13th map light overlapping one point is refused at build). The Compatibility renderer caps the lights of one canvas item at 16 and drops the rest, but WHICH lights survive is decided neither by the child index nor by the tree order (measured in a window in Godot 4.7.2: 20 faint lights + a red lantern, the lantern was dropped when added last and also after `move_child(player, 0)`; in four runs of the same sweep the lantern created last was dropped from 15 or 16 other lights on, or not at all up to 20, and created first from 17 or 20 on, or not at all: the survivors depend on allocation details that the game cannot control, the only rule that held in every run and order is <= 14 other lights, `final_probes/light_cap_output.txt`), so there is NO 'lantern = first light' mechanism (the first draft had one, a check for it and a P06 task): the BUDGET is the rule, a canvas item sees at most 12 map lights + the lantern = 13 of the 15 that were safe in every order measured. There is no `atmosphere.gd` and no `forest_dress` marker in the generated text.
* **Soft ground (V8 SoftGround, decision DX11).** The sketch's smooth S-curve path and pond are DECALS: SoftGround builds one 1-px-per-cell mask per feature class from the ground grid (path chars, `~`, glow patches), upscales it x8, cuts it with a smoothstep in a canvas shader and draws it on `ground_fx` with P22's seamless textures; the tiles underneath stay (collision, minimap, reachability, spawn logic unchanged; tile art is the fallback). No marker, so the golden digests do not move. New and unprototyped: judged windowed against the sketch.
* **The seven callouts of the sketch -> elements:** 1 player with lantern (spawn + P06 lantern 0.10 energy `ffe9a8`), 2 glow mushrooms (`g` patches + `light kind=glow` + `node glow_mushroom`), 3 eyes in the dark (`enemy ... ambush=1`, DR3 draws the `bush_eyes` host), 4 the Hulen (`warp ... prop=cave_ring` far end + Natteblik beside it on 2 / 6 / 10), 5 runestone (D2), 6 treasure chest (`chest role=lake lock=ugle_noegle` on the pond shore of floors 3 / 6 / 9), 7 the Moon pond (`~` + lily pads + calm whisper stub, no fishing).

### 3.5 Invariants, hard gates, fallback

46 named invariants are checked by an independent verifier (`DungeonVerify`, reads ONLY the parsed text, own flood fill) on every generated floor in the tests and in `tools/dungeon/stress.sh`; two run-level ones (first attempt >= 85 %, mean attempts <= 1.3) keep the retry loop honest. HARD in every attempt: exact feature counts of the table (chest roles and tiers, boss, runestone, spots, Hulen, up cave), every marker reachable from the spawn, no unreachable floor cell, 3-cell border not walkable, exact moonstone art-node count, boss arena room, no feature under a crown disc, props within budget, **and (new, found by the second stress range) `hulen_far_from_spawn` (Manhattan >= w * 2 / 5) and the floor-1/2 tutorial ambush (`3dx^2 + dy^2` in [150, 420])**. SOFT (attempts 1-4): enemy budget, ambush / critter counts, nodes, digs, glow patches, walkable share, site count. If all 8 attempts fail the generator returns its **PINNED FALLBACK**: the ordinary generator run ONCE on `dungeon.seed.fallback[floor]`, a seed that `tools/dungeon/find_fallback_seeds.sh` chose as the first of the fixed sequence `hash_key("fallback", 1, floor * 1024 + k)` whose single attempt passes the generator's own validation AND the independent verifier. The first draft's 'fallback template' (one big clearing, fixed marker cells, no nooks) could not have passed the verifier on floors 2-11: the hidden nook main chest of floors 2 / 6 / 9 / 11, `unique_spots_equal_spec` and `nook_features_sit_in_hidden_dead_ends` all demand nooks, and a template that satisfies 46 invariants would be a second generator. **Measured, not claimed** (`final_gen/results/fallback_check_output.txt`, `find_fallback_output.txt`): all 12 specs forced through the fallback (`max_attempts = 0`): generate, export, parse, verify: 797 checks, 0 violations, the same digest twice, independent of the input seed; the one real exhausted floor of the two 10 008-floor ranges (f2 i1396: all 8 attempts failed at 'nooks') passes through floor 2's pinned seed; 46-100 % of all sequence seeds of a floor pass at their first attempt (floors 1-10 and 12 are pinned at k = 0, floor 11 at k = 1). A fallback floor is the same layout every time it happens for that floor (about 1 floor in 10 000); `spec_hash` does not cover the list, so a change of floors / bands / limits can invalidate a pinned seed: `dungeon_gen.gen.fallback_valid` then fails and the tool is run again. The generator never fails the game.

### 3.6 Measured (MY re-runs on the merged table; `final_candidate/gen_check/`; machine: shared M3, load 5-26)

| run | floors | failures | violations | first attempt | mean attempts | determinism | digests |
|---|---|---|---|---|---|---|---|
| merged table BEFORE the two hard gates, seed range 0..99 per floor id | 1 200 | 0 | 0 of 46 invariants | 88.7 % (1 064) | 1.147 (max 5) | 0 mismatches of 180 | see below |
| FINAL table (hard gates, `rim.wall_depth` 0, pinned fallback), seed range 0..833 (834 per floor id, 6 processes) | 10 008 | 0 | **0** | 88.8 % (8 884) | 1.139 (max 6) | 0 of 1 440 | below |
| FINAL table, seed range 1000..1833 | 10 008 | 0 (ONE pinned fallback: f2 i1396) | **0** | 88.5 % (8 859) | 1.139 (max 9 = 8 + the fallback) | 0 of 1 428 | - |
| same range, ORIGINAL prototype and table | 3 seeds of 10 008 | 0 | **3** (see 0.2 row 3) | - | - | - | - |
| four-boss alternative (3 / 6 / 9 / 12, stone on every floor), `rim.wall_depth` 0 | 480 | 0 | 0 | 87.5 % | - | 0 of 72 | not pinned |

**Golden digests** (world `stress`, `first 0, count 10`, FNV-1a 32 of the map text, IDENTICAL on macOS arm64 and x86_64 under Rosetta; Linux / Windows only through the test): `f1=ea020e8c f2=245477a0 f3=d7940510 f4=0bb780e0 f5=6e06f71d f6=2548c06e f7=b48ceefc f8=b7ab3ea1 f9=34d1d0b6 f10=a8f88b52 f11=c9f4afaa f12=ebb30a85` (the FINAL table, `rim.wall_depth` 0; `final_gen/results/digest_arm64_depth0.txt` and `digest_x86_64_depth0.txt`). With `wall_depth` 1 they were `b0cefd70 f5280768 708d2308 a74dc768 b491b2c5 05550062 ea0e6988 f3e534d1 42e4be22 0737ac4e f2b31b76 d603c4cd` (the layouts are identical, only the ring of wall tiles differs; the pinned fallback seeds do not enter the digests of ordinary floors), and the generator track's own were `b0cefd70 d47e9748 fd137b8e cdc43495 ...` (they differ from the merged ones exactly on the floors the merged data touches: f2 hulen_keeper, f3 f6 f9 lake tier `noegle`, f4-f12 enemy mixes).
Generation + export at the headless p95 <= 60 + 35 ms; `_enter` of a floor 23-53 ms headless, 30-69 ms windowed `setup` with placeholder art (generator doc 6.3); props max 503 per floor and 96 per screen; wall tiles 0 per screen at `rim.wall_depth` 0 (the old depth-1 maximum was 330); windowed CPU render 2.3-5.0 ms before enemies and HUD (budget 8 ms, 12 ms at 1080p with real art).

### 3.7 The run node, the registry and the save section (D2; sections 8.6, 8.7 have the exact names)

`DungeonFloors` (class_name, `extends Node`) is a child of the LootService autoload (added in F4's `_ready` when the script exists; `SaveManager.register_section("dungeon", node, 45)`), because only an autoload exists early enough for `load_game` and the allow-list of autoloads forbids a sixth. It owns: the world seed, the seed-day pin, `start_run / enter / leave / end_run`, the register-ahead and prefetch, the per-floor consumed-cell lists, the activated runestones, the first-arrival oil refill, the boss flag `dg_boss_clear`, the boss events, `reveal_floor`, and the seeds / uids handlers use (`uid_of`, `rng_for`, `rng_keyed`). It holds NO combat or loot rules (`DungeonRun` and `LootService`). No new autoload, input action or EventBus signal: events travel through `game_event`.

### 3.8 Budgets (one table)

| quantity | limit | this design | source |
|---|---|---|---|
| padded floor size | <= 112 x 84 | max 104 x 84 (floor 11) | spike_forest.md 8.1 |
| props per floor / per screen | <= 800 / <= 400 | max 503 / 96 | 10 008 floors |
| wall tiles per screen | <= 400 | 0 (`rim.wall_depth` 0; the old depth-1 maximum was 330) | same |
| map lights per floor | <= 10 glow + 1 runestone; <= 12 overlapping a point | <= 10; <= 6 within 5 cells; a canvas item sees <= 12 map lights + the lantern = 13 | engine cap 16 PointLight2D per canvas item, order-dependent from 15 other lights (3.4) |
| awake enemies in view / alive | <= 24 / <= 48 | 22 ordinary on floor 11; 14 + boss + 8 adds on floor 12 | spike_forest.md 8.1 |
| save section `dungeon` | far below 8 MB | 2.7 KB worst case | integration probe |
| CPU render 1280 x 720 | <= 8 ms | 2.3-5.0 ms (placeholder art) | design_generator.md 6.4 |


## 4. The ONE floor table (`lua/config/dungeon.lua`, D1; the loot, experience and v2 tracks read it, none keeps a copy)

Source of truth: `design2/final_candidate/lua/config/dungeon.lua` (= `gen_check/dungeon_final.lua`). The loot validator rules DB1-DB5 and the tests `dungeon_world.world.boss_tables_agree` / `crystal_and_node_kinds_have_yield_rows` keep `dungeon_loot`, `dungeon_run`, `bosses.lua`, `loot.boss` and `dungeon.floors` in agreement. Size = PLAY area in cells (the exported map is padded: 56 x 42 -> 64 x 54 ... 96 x 72 -> 104 x 84).

### 4.1 The twelve floors

| n | band | play (cells) | boss (adds) | stone | ponds | glow | enemies (ambush) + critters | chest | lake | digs | nodes | spots | anchors |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | skovkant | 56 x 42 | - | - | 1 | 4 | 6 (1) + 0 | trae (clearing) | - | 1 | glow_mushroom 2, moss_patch 3, tree_chop 1 | - | - |
| 2 | skovkant | 60 x 45 | - | - | 1 | 5 | 8 (1) + 1 | trae (nook) | - | 2 | glow_mushroom 2, iron_ore 2, moss_patch 2 | sneglestien | `node kind=night_bloom when=night` (edge); `hulen_keeper npc=mapseller_natteblik` (hulen) |
| 3 | skovkant | 64 x 48 | - | yes | 1 | 5 | 9 (2) + 1 | trae (clearing) | noegle | 2 | copper_ore 1, glow_mushroom 2, iron_ore 2, moss_patch 2, rock_stone 1 | mosstenen | - |
| 4 | dybe_bregner | 64 x 48 | snurresvamp (4) | - | 0 | 4 | 7 (1) + 0 | jern (clearing) | - | 1 | fern 3, glow_mushroom 2, iron_ore 2 | hul_stamme | - |
| 5 | dybe_bregner | 72 x 54 | - | yes | 1 | 5 | 12 (2) + 1 | jern (clearing) | - | 2 | amethyst 1, fern 3, glow_mushroom 2, iron_ore 2 | mis_hjoerne, hekselysning | `npc id=cat_morfar_mis when=quest:lost_cat` (nook) |
| 6 | dybe_bregner | 72 x 54 | - | - | 1 | 5 | 14 (2) + 2 | jern (nook) | noegle | 2 | amethyst 2, fern 2, glow_mushroom 3, gold_ore 1, iron_ore 2, moonstone 1 | tornebaerkrattet, slyngplanterne | `hulen_keeper npc=mapseller_natteblik` (hulen) |
| 7 | svampelunden | 80 x 60 | - | yes | 1 | 8 | 14 (2) + 6 | jern (clearing) | - | 2 | amethyst 2, glow_mushroom 5, moonstone 1, moss_patch 2, rare_mushroom 2 | svampering, lysstubben | `quest_spot rare_mushroom_hunt / find_glowing` (glow) |
| 8 | svampelunden | 72 x 54 | snurresvamp_gloed (6) | - | 0 | 8 | 10 (1) + 4 | jern (clearing) | - | 1 | amethyst 2, emerald 1, glow_mushroom 4, moonstone 1, rare_mushroom 1 | lysningen | - |
| 9 | svampelunden | 88 x 66 | - | yes | 1 | 8 | 18 (3) + 6 | jern (nook) | noegle | 2 | amethyst 2, emerald 2, glow_mushroom 4, moonstone 1, rare_mushroom 2 | svampelysringe, tornehegnet | - |
| 10 | krystalgrotten | 88 x 66 | - | - | 0 | 6 | 20 (2) + 0 | fe (clearing) | - | 2 | amethyst 3, crystal_shard 4, emerald 2, iron_ore 2, moonstone 1 | stjernekigger, glodestenen | `hulen_keeper npc=mapseller_natteblik` (hulen) |
| 11 | krystalgrotten | 96 x 72 | - | yes | 0 | 6 | 22 (3) + 0 | fe (nook) | - | 2 | amethyst 3, crystal_shard 4, emerald 2, gold_ore 1, moonstone 2 | runealteret, runehvaelvingen | - |
| 12 | krystalgrotten | 80 x 60 | snurresvamp_konge (8) | - | 0 | 5 | 14 (1) + 0 | fe (clearing) | - | 1 | amethyst 2, crystal_shard 3, emerald 2, moonstone 1 | - | - |

Columns: `boss` = kind id (adds); `stone` = a runestone in the ARRIVAL clearing (permanent checkpoint, waypoint of the Port-runen); `ponds` / `glow` = ponds and glow patches; `enemies` = ordinary + ambush part (+ `critters` = harmless `lysesvamp`); `chest` = tier of the ONE ordinary chest and where it stands (clearing edge or a hidden nook, `hidden=1`); `lake` = locked key chest on the pond shore (tier `noegle`, `lock=ugle_noegle`); `nodes` = node markers (art kinds `amethyst emerald moonstone crystal_shard` are all loot kind `crystal`, 5.8); `spots` = the hidden unique spots of the floor (nooks; at most 3 nooks per floor, verified); `anchors` = quest / NPC slots placed independent of quest state.

### 4.2 The four bands (the four old loot zone ids: the 367 find sources, the pools and the 23 forest keepsakes stay valid)

| band id | floors | zone / ambient | title key | terrain | enemy tier | main chest | enemy mix (weights) |
|---|---|---|---|---|---|---|---|
| `skovkant` | 1-3 | `dark_forest` / forest | `ZONE_DARK_FOREST` | `m g p` | 1 | `trae` | bat 60, tornebusk 40 |
| `dybe_bregner` | 4-6 | `dark_forest` / forest | `ZONE_DYBE_BREGNER` | `m g p` | 2 | `jern` | bat 30, ugleoje 30, mosfroe 15, tornebusk 25 |
| `svampelunden` | 7-9 | `mushroom_grove` / forest | `ZONE_MUSHROOM_GROVE` | `m g p` | 3 | `jern` | ugleoje 30, bat 25, sporesvamp 20, tornebusk 25 (+ critters) |
| `krystalgrotten` | 10-12 | `crystal_cave` / cave | `ZONE_CRYSTAL_CAVE` | `c x x` | 4 | `fe` | ugleoje 30, bat 25, krystalugle 25, tornebusk 20 |

Whispers per band: `DUNGEON_WHISPER_<BAND>_<n>` (1, 2, 2, 2). `enemy_tier` (marker param `tier`) is the damage ladder column of DR1; hit points come from the floor (`@floor`) and `DungeonRun.enemy_hp` (6.2), NOT from a per-floor percentage.

### 4.3 What grows with depth

| quantity | floor 1 | floor 6 | floor 12 | rule |
|---|---|---|---|---|
| play size (cells) | 56 x 42 | 72 x 54 | 80 x 60 (96 x 72 on floor 11) | steps of 4; boss floors fixed small enough for the arena |
| ordinary enemies | 6 | 14 | 14 + 8 adds | 6 8 9 7+boss 12 14 14 10+boss 18 20 22 14+boss |
| ambush spots | 1 | 2 | 1 | 1-3 per floor; the first on floors 1-2 stands 6-11 cells from the spawn (readable tutorial) |
| main chest | trae, clearing | jern, nook | fe, clearing | tier by band; nooks on floors 2, 6, 9, 11 |
| special chests | - | key chest | boss chest (`konge`) | key chests 3 / 6 / 9; boss chests 4 / 8 / 12 |
| unique spots | 0 | 2 | 0 | 16 per full dive (12 hand-placed forest spots of `loot.spots` + 4 new), in nooks |
| chest rarity odds | trae 78.0 / 21.0 / 1.0 % | jern 62.3 / 33.8 / 3.9 % | fe 36.5 / 48.2 / 15.3 % | `DungeonLootRules.depth_odds`, luck 0, section 5.1 |
| oil | 150 s refilled on the FIRST arrival of every floor and at every stone | | | clear-all tour 50-222 s walking |

Per full dive the table places (deterministic): 18 chests (3 trae, 6 jern, 3 fe, 3 noegle lake chests, 3 konge boss chests; 4 of the 12 ordinary chests hide in nooks), 20 dig spots, 16 unique spots, 154 ordinary enemies + 21 critters, **45 crystal nodes and 8 moonstone art nodes** (the old forest had 17 chests, 23 dig spots, 15 spots and one moonstone per clear). Chests are DAILY, which is why the ordinary roll count per floor is 1.

### 4.4 How long a floor takes (generator doc 4.4 walking tour + experience doc 3.9 model; the clock is frozen inside: a run costs 0 game minutes)

Walking only (greedy clear-all tour, 25 seeds per floor, 285 px/s): floor 1 50 s, 3 89 s, 5 110 s, 7 156 s, 9 194 s, 11 222 s; spawn -> Hulen 14-39 s; all 12 floors 25 min. With fights and chests (ASSUMED archetypes, experience sim): a floor takes **42-120 s diving, 64-213 s typically, 103-350 s clearing everything**; floors 1-4 take 3.7 / 6.1 / 9.6 minutes (dive / typical / clear), the whole 12-floor dive 13.7 / 28.1 / 44.5 minutes. The 150 s of oil covers a thorough floor on the smaller sizes; floors 9-11 need `lantern_oil` (+60 s, auto-used at <= 15 s) or running: a gentle pacing device, not a hard timer.


## 5. Loot and the rarity categories (DL1-DL7 + F4; rationale and tables in `design_loot.md`, simulations in `design2/loot/results/` and `design2/final_candidate/c7_sim/results/`)

Rarity ids and ranks are unchanged: `normal` 1, `uncommon` 2, `rare` 3, `unique` 4, `legendary` 5 (Almindelig / Ualmindelig / Sjælden / Unik / Legendarisk). Categories: furniture (226 ids) and clothing (96 ids) as built; **weapons** (24 ids, NEW category `weapon`), **gems** (6 existing + 18 new ids, category `gem`), **materials** (+ 11 dungeon ids, category `material`, group `dungeon`). The UI is category-blind (`Rarity.ui`, `RaritySlot`, pips). `EconomyManager.add_item` already refuses a second copy of any rank >= 4 item and gives rank >= 4 items buy / sell 0 (`economy_manager.gd:162-186, 231-236`): that is the keepsake rule for the new categories with no code.

### 5.1 Bands and the depth ladder ("deeper floors drop better rarities")

The four loot zones are the four bands (4.2). Rarity odds of an ORDINARY roll at floor f: take the container's base odds (normal / uncommon / rare in basis points), multiply uncommon by `s` and rare by `s^2` with `s = 1 + 0.10 x (min(f, 12) - 1)`, renormalise; luck (cap 0.20): uncommon and rare x (1 + 5 L), normal absorbs. Floor 1 trae 78.0 / 21.0 / 1.0 %, floor 3 trae 74.5 / 24.1 / 1.4, floor 4 jern 65.9 / 31.0 / 3.1, floor 6 jern 62.3 / 33.8 / 3.9, floor 9 jern 57.5 / 37.4 / 5.2, floor 10 fe 39.4 / 47.1 / 13.5, floor 12 fe 36.5 / 48.2 / 15.3 (luck 0; at luck 0.20 floors 10-12 have no normal roll left). Three levers multiply: the ladder (uncommon x2.1, rare x4.4 at floor 12), the tier of the band (trae -> jern -> fe changes the base odds 2-5x) and the pools (each band's pool of furniture / clothing is a different slice of the catalogue). **Unique and legendary have NO column on purpose.** The daily value cap (5.7) counts only the rarity-restricted sources and sits at 3 200, so the ladder is not switched off on a clear-all day (the first rule burned the cap by floor 7-9 and cut the rare items of floors 10-12 to 14 %).

### 5.2 Containers (`loot.containers`, bp normal / uncommon / rare; kinds are weights summing to 100)

| tier | odds N / U / R | rolls | kinds furniture / clothing / material / weapon / gem | wander bp | pity opens | used by |
|---|---|---|---|---|---|---|
| `trae` | 7800 / 2100 / 100 | 1 | 16 / 18 / 36 / 6 / 24 | 250 | 24 | main chest floors 1-3 |
| `jern` | 7200 / 2600 / 200 | 1-2 | 18 / 20 / 28 / 8 / 26 | 300 | 14 | main chest floors 4-9 |
| `fe` | 5800 / 3650 / 550 | 2 | 18 / 18 / 24 / 10 / 30 | 700 | 8 | main chest floors 10-12 |
| `konge` | 1800 / 6900 / 1300 | 2 | 16 / 16 / 20 / 16 / 32 | 0 | 0 | boss chests |
| `noegle` (NEW, `lock = ugle_noegle`) | 2500 / 5000 / 2500 | 2-3 | 16 / 16 / 14 / 14 / 40 | 0 | 0 | lake chests |
| `dig` | 7600 / 2200 / 200 | 1 (`find_chance` 0.12) | 8 / 8 / 52 / 0 / 32 | 0 | 0 | dig spots |

The gem kind always yields the band's unknown stone (`rough_<band>`); the rarity of a stone is decided at the appraisal. An EMPTY pool re-draws the kind. The old values were balanced for 17 chests with 7-21 day respawns; the dungeon deals ONE chest per floor per day, so the first draft (old odds) paid 3-4 times what the plan allows (`loot/results/tune_run1.txt`). One ordinary roll is worth 17-35 gold (trae), 32-69 (jern), 57-128 (fe) at luck 0.

### 5.3 Where rare, unique and legendary items come from (validator R3: exactly one fixed source for every keepsake)

| rarity | sources |
|---|---|
| normal, uncommon, rare (all categories) | ordinary chests (ladder), digs, nodes, creature drops, appraisal of unknown stones (gems), smithy rotation and forging (weapons), shops (furniture / clothing as before) |
| **unique** (at most one per save, `protected`, buy 0 / sell 0) | the 16 hidden spots (nooks), lake chests (the FIRST locked chest opened in each of bands 1-3 holds the band's unique gem: `gem_dewdrop`, `gem_owl_eye`, `gem_sunset_stone`), unique WANDERERS (8, with pity; they appear in ordinary chests of their band and tier once per save), the rune shards (first kill of each boss), the first-kill hat |
| **legendary** | the three bosses (pool 3-4 each, weekly), the rune chain (`gem_rune_heart` at the Runehvælvingen), tier gifts and quest rewards of the home ladder; **NEVER an ordinary chest** (F4 verify `loot.legendary_never_from_ordinary_chests`) |

A unique item is paced by `unique.cooldown_days = 7` (one HUNTED unique per week at most; boss first kills, boss pools and quest items are never delayed). The registry `loot.dungeon.found {item: day}` is written when a keepsake is delivered and never pruned: a keepsake can never be found twice, even after a sale, a loss or (rune shards) consumption.

### 5.4 Weapons: 24 ids, 5 families, 5 rarities (NEW category; fixed ids, no random affixes, no instances)

`sword_rusty` (5) and `iron_sword` (12) stay in `lua/items/tools.lua` (DL1 adds `weapon_family = "sword"`); 22 are new (`lua/items/weapons.lua`, DL2). **Damage = round(sword damage of the rarity x family factor)**: sword 5 / 12 / 22 / 30 / 42 (normal / uncommon / rare / unique / legendary), factors dagger 0.65, sword 1.00, spear 1.08, staff 1.125, club 1.35, which keeps damage PER SECOND within +-4 % of the sword (the staff is 8-10 % lower on purpose: its power is the fairy light). One effect at most, rare and better only. The data was made with half-to-even rounding and GDScript's `roundi` rounds half away from zero: `wpn_club_thornberry` (30 x 1.35 = 40.5) is 40 in the data and is the only id where the two conventions differ, so the check `dungeon_items.damage_formula` allows a tolerance of 0.5 against the pinned table below instead of re-rounding.

| family (da) | swing | cooldown | radius | half angle | knockback | damage x | row owner |
|---|---|---|---|---|---|---|---|
| sword (sværd) | 0.28 | 0.12 | 197 | 62 | 433 | 1.00 | DR1 `dungeon_run.weapon_families` |
| club (kølle) | 0.42 | 0.12 | 177 | 95 | 693 | 1.35 | DR1 |
| spear (spyd) | 0.31 | 0.12 | 286 | 22 | 346 | 1.08 | DR1 |
| dagger (dolk) | 0.20 | 0.06 | 158 | 70 | 260 | 0.65 | DR1 |
| staff (stav) | 0.34 | 0.16 | 197 | 48 | 433 | 1.125 | DR1 (the loot track's exact row) |

| id | family | rarity | dmg | buy / sell | effect (params) | source |
|---|---|---|---|---|---|---|
| `sword_rusty` | sword | normal | 5 | 100 / 20 | - | starter kit |
| `iron_sword` | sword | uncommon | 12 | 750 / 300 | - | smithy fixed stock, quest `dark_forest_mining` |
| `wpn_sword_forest_steel` | sword | rare | 22 | 1800 / 180 | `oil_on_kill` s 2 | smithy weekly; forging; chests |
| `wpn_sword_candle` | sword | unique | 30 | worth 5000 | `oil_on_kill` s 4 | spot `lysstubben` (floor 7) |
| `wpn_sword_moon` | sword | legendary | 42 | worth 12000 | `moon_wave` every 5, x0.6, range 360 | boss king pool |
| `wpn_club_spruce` / `_oak` / `_mushroom` | club | normal / uncommon / rare | 7 / 16 / 30 | 115 / 860 / 2070 (sell 15 / 105 / 205) | rare: `stun_chance` p .25, s .5 | smithy; forging; chests |
| `wpn_club_thornberry` | club | unique | 40 | worth 5750 | `stun_chance` p .5, s .6 | spot `tornehegnet` (floor 9) |
| `wpn_club_trunk` | club | legendary | 57 | worth 13800 | `quake` every 4, x0.9, radius 160 | boss Glødesvampen pool |
| `wpn_dagger_thorn` / `_flint` / `_moonshard` | dagger | normal / uncommon / rare | 3 / 8 / 14 | 80 / 600 / 1440 | rare: `heart_on_kill` every 8 | smithy; forging; chests |
| `wpn_dagger_bee` | dagger | unique | 20 | worth 4000 | `heart_on_kill` every 4 | wanderer `fe` (krystalgrotten) |
| `wpn_spear_twig` / `_iron` / `_thistle` | spear | normal / uncommon / rare | 5 / 13 / 24 | 100 / 750 / 1800 | rare: `light_arc` radius x1 | smithy; forging; chests |
| `wpn_spear_owl` | spear | unique | 32 | worth 5000 | `light_arc` x1.5 | wanderer `jern` (svampelunden) |
| `wpn_spear_root` | spear | legendary | 45 | worth 12000 | `reveal_chests` 12 cells | boss Glødesvampen pool |
| `wpn_staff_branch` / `_hazel` / `_light` | staff | normal / uncommon / rare | 6 / 14 / 25 | 110 / 825 / 1980 | rare: `light_boost` cd -1.0 s, radius x1.1 | smithy; forging; chests |
| `wpn_staff_ember` | staff | unique | 34 | worth 5500 | `light_boost` -1.5 s, x1.2, stun +0.4 s | spot `glodestenen` (floor 10) |
| `wpn_staff_star` | staff | legendary | 47 | worth 13200 | `light_boost` -2.5 s, x1.3, stun +0.8 s | boss king pool |

(The dagger has no legendary: 27 damage at 0.26 s a blow would be a machine gun. Weapon sell ratios 0.15 / 0.12 / 0.10 for the new ones, so a spare copy is worth a meal, never a faucet; a duplicate copy that `add_item` refuses is sold at once, whisper `FIND_UI_DUPLICATE_FMT`.)

**Eight effects**, params are item data, the code is `WeaponFx` (DL3) and `Player2D` calls five hooks late-bound: `stun_chance {p, s}`, `oil_on_kill {s}`, `heart_on_kill {every}`, `light_arc {radius_mult}`, `reveal_chests {cells}`, `light_boost {cd_minus_s, radius_mult, stun_bonus_s}`, `moon_wave {every, mult, range}`, `quake {every, mult, radius}`. Limits (`dungeon_loot.limits`): the fe-lys cooldown never drops below 3 s (weapon + lantern gem together), chest sense is the MAX of its sources never the sum. The ids are DR1's list `dungeon_run.weapon_effects`.

**Storage and equipping (decision DX35).** Weapons live in a new store `Arsenal` (child node of EconomyManager, NOT an autoload, no section of its own: the `economy` section gains the optional key `arsenal {id: count}`, `SAVE_VERSION` stays 1; a v1 save with the two swords in the backpack is adopted by `adopt_misrouted`). A weapon is equipped BY HAND in the Rygsæk tab `Våben` (no hotbar slot, no input action, `attack` stays LMB); auto-equip only when nothing is equipped or the new weapon is of the SAME family with a higher damage-per-second rating, otherwise the toast `WSTAT_BETTER`; the equipped copy is neither sellable nor placeable. **Rating** = sword-equivalent damage = `damage x 0.40 / (swing + cooldown)` = `WeaponInfo.sword_equivalent(id)`; `DungeonRun.weapon_range(id)` = "good for floors 1 .. last floor with expected_weapon <= rating / 0.9" (rusty 1-1, iron 1-6, a rare sword 1-12), shown on weapon cards ("God til etage a-b") and in the rune picker.

**Prices, smithy, forging.** `weapon_price` 100 / 750 / 1 800 / 5 000 / 12 000 x family factor (club 1.15, dagger 0.8, staff 1.1, sword and spear 1.0), keepsakes have `worth` only; the smithy's fixed stock is untouched, two rotation rows are added (`smedens_udvalg` period 3 pick 4, `ugens_staal` period 7 pick 2 rare, price x1.1); 13 forging recipes `dng_forge_*` (5 normal at the carpenter's bench tier 1, 8 uncommon / rare at the forge tier 5), cost 45-85 % of the weapon's buy price and above its sell price (validator W5) with ONE written valuation rule: an ingredient is worth its `buy_price`, or `limits.recipe_unbuyable_mult` (2.2) x its `sell_price` when it has none, asserted at 2.0 (the repo's `economy.sell_price_ratio` 0.5), 2.2 and 2.5 (`final_sim/results/recipe_band_final.txt`: 13 of 13 in band; the moonshard dagger recipe takes 3 moss agate and 5 resin and sits at 0.497 / 0.509 / 0.528, it was outside the band at 2.0), unique and legendary never craftable or sold.

**No weapon art in the world** (decision DX35, an honest gap): the hero bake has no weapon layer; the slash arc and the hit spark are tinted with the weapon's rarity ring colour and the icon carries the look.

### 5.5 Gems: unknown stones, Fru Ugle's appraisal, the lantern

Gems: 6 exist (`crystal_shard rose_quartz amber amethyst moonstone emerald`, prices unchanged); 18 are new (`lua/items/gems.lua`): 4 unknown stones `rough_skovkant / _dybe_bregner / _svampelunden / _krystalgrotten` (unsellable, shown as the dashed unknown slot) and 14 cut gems: normal `gem_rock_crystal gem_smoky_quartz gem_moss_agate gem_forest_jade`; uncommon `gem_mushroom_opal gem_thornberry_stone`; rare `gem_fairy_tear gem_night_sapphire`; unique `gem_dewdrop gem_owl_eye gem_sunset_stone` (lake chests); legendary `gem_moon_heart` (king pool), `gem_star_tear` (Glødesvampen pool), `gem_rune_heart` (the Runehvælvingen). `gem_price` 45 / 150 / 450 / 1 500 / 4 500, sell ratio 0.44.

**Appraisal** (Fru Ugle, dialogue choice "Vurdér mine fund" emits `game_event open_appraisal {npc}`; **F4's LootService hosts the screen**: it listens to the event and adds `scenes/ui/appraisal_ui.tscn` (DL7) to the `game_ui` layer, so `GameUI.SCREEN_ORDER` and its pins stay as built; `LootService.appraise(rough_id)`): the player pays the band's fee per stone (30 / 50 / 75 / 105 gold, `batch_max` 12) and gets ONE cut gem: rarity by the band's odds (skovkant 64 / 33 / 3 %, dybe_bregner 45 / 45 / 10, svampelunden 32 / 50 / 18, krystalgrotten 20 / 50 / 30; uncommon and rare x (1 + 5 L), the sum CLAMPED to 100 % and renormalised, normal absorbs), the gem by pool weight; **no unique or legendary gem ever comes from appraisal**. The outcome is a pure function of (world seed, band, the band's OWN counter n_band) through `rng_keyed("appraise:" + band, n_band)`. The first design keyed the draw by one shared counter, so a player who could read a result and reload learned one draw for all four bands and luck levels and could pick the stone that suits it (review 1: +45 gold per appraisal at luck 0 and +75 at luck 0.2 against +15 / +48 for the honest player, without limit). Now the stone, the fee and the band's counter are committed in ONE step and `SaveManager.autosave()` (atomic: tmp file, read back, rename) runs BEFORE the result is returned or shown, so a quit or a crash after the reveal cannot take the counter back; a result of one band says nothing about another band; a stone is a stack item without identity, so no per-stone origin can key the draw. Measured (`final_sim/results/05_appraisal_scum_fixed.txt`, 8 stones of every band): the honest player nets +9 per stone at luck 0 and +35 at luck 0.2; a player who could see every band's next draw (the UI does not show it) nets less; the residual is the full look-ahead of a manual-save scummer, +265 gold per 32 stones at luck 0 and +67 at luck 0.2, the generic offline save-scum of every game (risk 15). **Corrected economics** (the luck multiplier clamped like `loot_mc.appraise()` does; the first version of the script did not, left a negative probability of a normal gem for svampelunden (x1.36) and krystalgrotten (x1.60) and so overstated the luck-0.2 gain as +37 / +55 / +66 / +81): net of the fee, per stone, **at luck 0 +15 / +14 / +7 / 0** (skovkant .. krystalgrotten; EV of the cut gem 45 / 64 / 82 / 105 against fees 30 / 50 / 75 / 105), **at luck 0.2 +37 / +48 / +35 / +20** (`final_sim/results/04_appraisal_ev_fixed.txt`). So the fee is a tax only at the deepest band; elsewhere an unknown stone pays a little at luck 0 and +20 to +48 at luck 0.2, the reward of luck gear, bounded by the stone supply (30 % of 45 crystal nodes + chest gems) and by the daily cap (an appraised gem counts, 5.7). The prize is above all the CHANCE of a rare lantern gem.

**The lantern gem** (equipment slot `accessory`, reserved since P01): ONE gem in the lantern; colour (`lantern.tint`) plus one small effect per theme x rarity step: oil burn -4 %, light radius +4 %, fairy-light cooldown -0.5 s, chest sense +3 cells, bush eyes seen +20 % farther, pickup magnet +20 %; step normal 0 (colour only) / uncommon 1 / rare 2 / unique 3 / legendary 4; the six existing gems have themes too (amethyst light_cd, amber oil, crystal_shard radius, rose_quartz pickup, moonstone ambush, emerald chest_sense). `gem_rune_heart` has all six themes. Read by `LanternGem.effects(...)` (DL3), applied by P06 (oil, radius, light colour, Q cooldown), DR0 (pickup), DR3 (ambush), DR1 / DR5 (chest sense).

**Lake chests** (sketch landmark 6): `chest tier=noegle role=lake lock=ugle_noegle` on the pond shore of floors 3 / 6 / 9; the key `ugle_noegle` exists only through Fru Ugle's weekly quest `ugles_noegle` (amethyst + rose_quartz + amber in, key + 150 gold out: net -81 gold), one key per chest; the first locked chest of a band holds its unique gem (spots `soeskatten_*`, `container = noegle`, `requires.items`, `consume`); later ones are ordinary `noegle` rolls.

### 5.6 Materials and the rune chain

11 new materials (`lua/items/dungeon_materials.lua`): normal `dng_resin dng_mushroom_felt dng_forest_thread`, uncommon `dng_forest_steel dng_glimmer_dust dng_owl_feather`, rare `dng_moon_silver dng_crystal_root`, and THREE unique rune shards `dng_rune_snurre dng_rune_gloed dng_rune_konge` (the first kill of each boss gives one; they are consumed at the hidden spot `runehvaelvingen` on floor 11 which needs all three and gives the legendary lantern gem `gem_rune_heart`; `loot.found` keeps them recorded, so a consumed shard can never be found twice). Sources: chests, creature drops (bat, ugleoje, tornebusk, lysesvamp + the three extra kinds) and the crystal extras; the materials feed the 13 forging recipes and nothing else. The nine `resin_tree` / `steel_vein` / `moon_vein` source rows of the loot track's first draft are deleted (the generator places none of these node kinds; rule M1 forbids a source that is not placed).

**Prices (the editor's fix of review 1).** `buy_price` is the NOMINAL value that the recipes are valued with (no shop sells these materials), `sell_price` is what a shop PAYS for the surplus: resin 2, mushroom felt 2, forest thread 1, forest steel 10, glimmer dust 8, owl feather 6, moon silver 24, crystal root 21 gold (the first draft: 5 / 6 / 4 / 28 / 22 / 18 / 68 / 60; the three rune shards stay buy 0 / sell 0). Why: the 13 one-off forging recipes use 67 pieces in all, while a typical save RECEIVES 1 704 glimmer dust, 203 owl feathers and 194 forest threads in 337 days, so the surplus is sold; the loot track's model valued these materials at 0.35 of their price ('the rest is kept for recipes and the home', an assumption: nothing consumes it), and at the old prices the dust alone was 36 124 gold per save, 54 % of the dungeon's gold and about 21 % of all gold of the game (review 1, results 14 / 15; the castle day with the real price was 30 % earlier instead of 22 %). The 0.35 is now true in the DATA (the new prices are 0.33-0.40 of the old ones), the money model sells the surplus at 100 % of THESE prices, validator rule M2 keeps `sell_price <= 25 %` of `buy_price` and rule P1 tests the real price. At the new prices the dust is 13 248 gold per save = 9.8 % of the dungeon's gross sold value (`final_sim/results/18_item_breakdown_final.txt`).

### 5.7 Bosses, spots, caps, surprises, delivery

| boss (kind id) | floor / band | first kill | repeat pool (every 7 game days) | pool |
|---|---|---|---|---|
| Snurresvampen `snurresvamp` | 4 / dybe_bregner | quest hat + `dng_rune_snurre` | `sofa_cloud rug_magic_circle floor_lamp_fairy shoes_boots_wind` (the four home legendaries), **16 %, pity 6** | 4 |
| Glødesvampen `snurresvamp_gloed` | 8 / svampelunden | `dng_rune_gloed` + 2 moonstone | `wpn_club_trunk wpn_spear_root gem_star_tear`, **16 %, pity 6** | 3 |
| Svampekongen `snurresvamp_konge` | 12 / krystalgrotten | `dng_rune_konge` + 2 moonstone | `wpn_sword_moon wpn_staff_star gem_moon_heart`, 8 %, pity 10 | 3 |

The two early bosses pay twice as often as the old table because players move on (with the old 8 % / pity 10 only 25-39 % of typical saves found their pool legendaries by day 520, with 16 % / 6 it is 50-77 %); an exhausted pool pays 2 `dng_glimmer_dust`. `LootService.on_boss_defeated` is authoritative and IDEMPOTENT per `ctx.uid` (the kill and the opening of the sealed chest may both ask). Seven new hidden spots: `lysstubben` (sword_candle, floor 7), `tornehegnet` (club_thornberry, 9), `glodestenen` (staff_ember, 10), `soeskatten_skov / _bregner / _lund` (gems, 3 / 6 / 9), `runehvaelvingen` (`gem_rune_heart`, 11).

* **Daily value cap** 3 200 gold-equivalent per day, counted for the RARITY-RESTRICTED sources only: ordinary, lake and boss chests, digs and appraised gems (`dungeon_loot.daily.counts` = chest, dig, appraise); nodes, creature drops and surprise gold do not count (they cannot hand out rare items); keepsakes, first kills, quest items and boss pools never count. A plan counts when it is COMMITTED (a refused plan counts nothing). When the cap is reached the rest of the day's ordinary rolls cap at uncommon, draw only materials 70 % / stones 30 %, appraisals cannot return rare; one whisper `LOOT_DAY_TIRED`; `game_event loot_day_capped`. **Why 3 200 on the restricted sources and not 1 400 on everything** (review 1; `final_sim/results/16_cap_grid_final.txt`, clear-all day floors 1-12 in order, the dust at its real price): the first rule was reached before floor 10 on 98 % of the days at luck 0 and 100 % at luck 0.2 and cut the rare items of floors 10-12 to 14 % / 12 % of the uncapped day, which defeated 'deeper floors drop better rarities'. At 3 200 it is reached before floor 10 on 5 % (luck 0) / 20 % (luck 0.2) of the days, floors 10-12 keep 79 % / 48 % of their rare items, and the day pays 2 149 / 2 847 gold net (48 / 64 gold per minute of a 44.5 minute dive; the farm pays 37-48 per minute). A cap of 4 000 pays 2 370 / 3 156 (53 / 71 per minute) and keeps 93 % / 74 %; 2 600 pays 1 903 / 2 465 and keeps 58 % / 28 %. Per-band caps keep the rares (88-99 % at luck 0) but bind on 50-93 % of the days (luck 0) and bound the income little (2 167-2 370 against 2 422 uncapped), so they were not adopted. The dials are `dungeon_loot.daily.value_cap` and `.counts`.
* **Surprises** (3.6 % of ordinary and lake chests, cozy: never a trap or a mimic): `firefly_swarm` +15 s oil (1.2 %), `acorn_purse` 15-40 gold (1.0 %), `cocoa_thermos` +2 half hearts (0.8 %), `pip_note` a whisper hinting at an unclaimed hidden spot (0.6 %). LootService announces the winner with `game_event dungeon_surprise`; **RunWatch (DR1) applies it and shows the toast** (`DEXP_SURPRISE_*`); LootService shows none.
* **Delivery is TWO-PHASE and all-or-nothing.** Review 1 found that the first rule ('a full backpack leaves the chest closed and not done') still delivered the rolls BEFORE the failing one on every retry, because the keyed stream replays the same draws: 12-13 % of jern, 24-25 % of fe and konge and 31 % of noegle chests were retry faucets, five presses of E delivered five iron swords (1 500 gold), the daily cap was reached after 8-41 presses, and a full pack at the first boss kill burned the rune shard and the two moonstone for good (the Rune Heart chain blocked). `LootService.open_container`, `dig`, `on_boss_defeated`, `claim_spot` and `appraise` therefore run, in this order: (1) PLAN: the pure `DungeonLootRules.roll_*` draws every roll of the container from the keyed stream on a COPY of the state; (2) FIT: every backpack-bound roll of the plan (materials, rough stones, any other backpack item) must fit TOGETHER (`EconomyManager.can_add_item` on a virtual pack: new stacks + stack room), the Arsenal and the furniture / clothing stores always fit (a duplicate is sold at once, `FIND_UI_DUPLICATE_FMT`); (3) when ANYTHING does not fit the answer is `{ok: false, reason: &"full", results: []}` and NOTHING happens: no deliver, no pity or wanderer-miss bump, no `daily_add`, no surprise, no `last_uid`, no `first_done`, no `last_day`, the cell is not marked done (the chest stays closed, the sealed boss chest stays sealed, the whisper `DEXP_BACKPACK_FULL` says why); (4) otherwise every roll is delivered through `LootService.deliver` (it cannot refuse after the fit; if it ever does the item is sold at its sell value, never dropped); (5) every state delta and the idempotency answer of a boss uid are committed. Creature drops (and nodes when asked) are RETURNED in `results` and become pickup orbs (DR0) whose pickup calls `deliver`, so the duplicates policy, the registry and the full-backpack rule apply at pickup (an orb that does not fit stays on the floor). Measured (`final_sim/results/13_partial_delivery_fixed.txt`, `23_keepsake_fuzz_fixed.txt`): 1 000 retries on a full pack deliver 0 items and change no state in every tier; the keepsake fuzz of 3 000 runs ends with 0 lost and 0 duplicated keepsakes and 0 extra copies of chest items (the first rule stored the boss state before the delivery: 68 % of the runs lost a keepsake; both first readings ended 99.6 % of the runs with extra copies).
* **Anti-exploit** (all measured or tested): seed scumming (keyed streams), order scumming, appraisal re-roll (per-band streams, committed and saved before the reveal), save / load duplication (registry), same-day re-entry (`done` lists), day rolling (a new day costs a game day; the cap; a band run pays 26-68 gold per minute of the typical walk against the farm's 37-48), luck swapping (can only lower luck), weapon sell loops (sell 10-15 %, forging 45-85 %), boss farming (weekly, finite pool), key duplication (one weekly quest), backpack tricks (a plan that does not fit changes nothing: no delivery, no counter, no re-roll, so repeated presses of E on a full pack gain nothing), time skips (`seed_day` pinned).

### 5.8 Crystal nodes: the one conflict with real money in it (loot C7), DECIDED by simulation (decision DX30)

The generator places **45 crystal nodes per full dive** (art kinds `amethyst` 17, `emerald` 9, `moonstone` 8, `crystal_shard` 11; floors 5-12: 1, 3, 3, 4, 5, 10, 11, 8) with a hard moonstone placement. The loot track's draft let those nodes yield the gems directly (worth about 5 700 gold per dive against 2 266 for its whole dive: the home ladder would collapse) and therefore capped loot-bearing crystals at 0-2 per floor, the rest "decoration without loot" (a harvest that gives nothing is a bad feel and needs a per-node selection the handler cannot make). **Decision:** every crystal node the generator places is the loot kind `crystal` (the four art kinds are aliases; colour is art only) and a harvest ALWAYS gives something: with `chance_bp 3000` the band's unknown stone (+ extras: glimmer dust 30 % in bands 3-4, crystal root 7 % in band 4), otherwise one `dng_glimmer_dust` (it sells for 8 gold). `hard_nodes` stays in the generator as a PLACEMENT guarantee (digests unchanged); `floor_loot` and the orphan node rows are deleted from `dungeon_loot`. Data: `final_candidate/lua/config/dungeon_loot.lua`; model of the DECISION: `final_candidate/c7_sim/sim/loot_mc.py` = the loot track's Monte Carlo + 6 lines (`fallback`), the plan's `balance_sim.py` unmodified, 80 saves per profile, 200 for the lifetime table; model of the FINAL numbers: `final_candidate/final_sim/sim/loot_mc.py` (dng_ at their real price, `daily.counts`, per-band caps and the dials) with the same assumptions. The rows below are the DECISION evidence (the dust valued at 0.35 of its old price of 22 gold = 8 gold, which is the real price of the final data, 5.6; the daily cap still 1 400 on every source, which 5.7 replaced); the FINAL numbers follow the table:

| variant (crystals per full dive) | typical castle day keep / sell | casual keep | dedicated keep | full dive uncapped / capped (luck 0) | typical 8 moonstone / 8 amethyst day |
|---|---|---|---|---|---|
| plan baseline (old forest) | 337 | 912 | 184 | - | - |
| loot track's own draft (0-2 loot crystals per floor, 14 at most) | 266 / 246 | 796 | 144 | 2 266 / 1 127 | 77 / 79 |
| ALL 45 crystals give a stone, no fallback (REJECTED) | **371** (+10 %: fees on stones the sim forces the player to appraise exceed their value; band 4 pays -59 per run) | 942 | 156 | - | - |
| **DECIDED: all 45, 30 % stone, else one glimmer dust** | **263 (-22.0 %) / 246 (-27.0 %)** | 756 (-17.1 %) | 146 (-20.7 %) | **2 388 / 924** | **55 / 62** (casual 136 / 155, dedicated 28 / 29) |

**Final numbers** (the final data: dust at 8 gold, the cap 3 200 on the restricted sources; `final_sim/results/pacing_keep_final.txt`, `pacing_sell_final.txt`, `abuse_final.txt`, `life_keep_final.txt`, `bands_final.txt`; 80 saves per profile, 200 for the lifetime table): castle day (keep / sell): typical **246 (-27.0 %) / 220 (-34.7 %)**, casual 718 (-21.3 %) / 625 (-31.5 %), dedicated 132 (-28.3 %) / 126 (-31.5 %); full dive of floors 1-12 uncapped / capped, luck 0: 2 409 / 2 205 gold with 8.9 / 7.6 rare items, luck 0.2: 3 516 / 2 901 with 12.1 / 8.4; typical: 8 moonstone on day 56, 8 amethyst on day 59 (casual 138 / 161, dedicated 27 / 29), every tier supplied (`find-waits {}`). These are richer than the decision table because the cap no longer eats the deep floors (5.7); the substitution of bought furniture is NOT in them (5.9). Keepsake timelines: first unique day 4, 12th day 83, first legendary day 48, a unique every 2.7 runs and a legendary every 9.9 runs in the first 100 days; rare items per floor in band 4 0.71 -> 1.36 (more rare gems and uncapped deep chests, gold-neutral). Not simulated: real appraisal behaviour (a rational player appraises only when it pays: the castle day is the same either way, the 100 % rows of `25_appraise_policy_final.txt`: typical 245 forced and rational), fun.

### 5.9 Pace: the corrected figure (typical player, 0.35 runs per day, plan pace)

The first quote of this addendum (typical castle about day 263, -22 %) left the SUBSTITUTION out: the plan makes the player spend 20-30 % of gross on lifestyle and 55 % of that on furniture, the hygge gates of tiers 7-10 depend on it, and a typical save is handed 22 366 gold (buy value) of kept furniture and clothing by day 100 and 53 305 by day 258 (review 1, `09_kept_value.txt`; the castle's 74 pieces cost about 43 000). 'Keep' counted those pieces as 0 gold and left the lifestyle spend untouched, so it was not a lower bound on the pace effect. The model now has the substitution (`final_sim/sim/balance_sim_free.py` = the plan's `balance_sim.py` plus a 12-line hook: free furniture replaces the furniture spend of the day, capped at the furniture share of the lifestyle budget, the hygge points are kept). Castle (tier 10) day and real hours (9-minute farm days + the dungeon minutes of the typical walk; plan without a dungeon: casual 912 days / 136.8 h, typical 337 / 50.5 h, dedicated 184 / 27.6 h), 80 saves per profile, `final_sim/results/dial_pace_final.txt`:

| case | casual | typical | dedicated |
|---|---|---|---|
| 0 no substitution (the loot track's convention) | 718 (-21 %), 118.6 h | **246 (-27 %), 49.4 h** | 132 (-28 %), 31.5 h |
| **1 AS DESIGNED: free furniture replaces 100 % of the bought furniture** | 591 (-35 %), 99.6 h | **201 (-40 %), 40.4 h** | 101 (-45 %), 24.1 h |
| 2 only half of it replaces a purchase | 609 (-33 %), 102.3 h | 210 (-38 %), 42.2 h | 108 (-41 %), 25.7 h |
| 3 furniture and clothing kind weights x 0.5 (`loot.containers`) | 611 (-33 %), 102.7 h | 219 (-35 %), 44.1 h | 116 (-37 %), 27.7 h |
| 4 keep only uncommon or better pieces | 588 (-36 %), 99.1 h | 200 (-41 %), 40.2 h | 101 (-45 %), 24.1 h |
| 5 keep only rare or better pieces | 573 (-37 %), 96.9 h | 197 (-42 %), 39.6 h | 99 (-46 %), 23.6 h |
| 6 weights x 0.5 and keep uncommon or better | 609 (-33 %), 102.4 h | 218 (-35 %), 43.9 h | 116 (-37 %), 27.7 h |

Reading: the days fall by 27-40 % for the typical player, the real hours barely do without the substitution (49.4 against 50.5 h: the player earns while the dungeon clock is frozen, a run costs 0 game minutes, and spends the saved game days in the dungeon; the dedicated player needs 31.5 h against 27.6 h because he dives on more than every second day) and by about a fifth with it (40.4 h); the dedicated player finishes on day 101, still above the gate floor of 64 days. This is far richer than the analyst's budget of about -13 %. The data dials reach only part of the way: the cap and the dust price were settled in 5.6 / 5.7 for other reasons, kind weights x 0.5 give -35 % (-33 % / -37 %), the 'keep' rule hardly matters (the value of free furniture sits in the uncommon and rare pieces), and no data lever reaches the no-substitution figure, because the free furniture IS the point of the dungeon (the user asked for rare furniture). Open question 1 asks the user to choose between 'as designed' and a dial. A band run pays 107 / 360 / 335 / 669 gold (keep valuation, typical player) in bands 1-4; per minute of the typical walk (4.2 / 6.1 / 8.1 / 9.8 minutes) 26 / 59 / 42 / 68 gold against the farm's 37-48. Uniques arrive one per 2.7 runs in the first 100 days (over 520 days one per 7.1 runs), legendaries one per 9.9 runs (over 520 days one per 17.7); the first legendary, usually the Rune Heart, around day 48; rare items per floor 0.15 / 0.36 / 0.63 / 1.36 in bands 1-4 (luck 0, sell valuation).

### 5.10 Furniture and clothing from the dungeon (no new ids, no art)

The dungeon re-uses all 226 pieces of furniture and 96 garments through the band pools. It is the ONLY source of 8 rare pieces of furniture and 7 rare garments (not sold anywhere), 13 rare furniture and 2 rare garments of the deepest band only, and the main source of the 38 existing keepsakes (23 are dungeon-bound and need no edit because the band ids are unchanged: 12 spots, 6 unique wanderers, 4 boss-pool legendaries, the first-kill hat). New keepsakes: 18 (weapons 5 unique + 4 legendary, gems 3 + 3, materials 3 unique): 67 in all, 41 dungeon-sourced (28 unique, 13 legendary). Four wanderers moved one tier down because each band has ONE main-chest tier (`rug_flower_petal` jern -> trae, `clock_owl` fe -> jern, `floor_lamp_glowshroom` and `piano_toadstool` fe -> jern); two weapon wanderers were added (`wpn_spear_owl`, `wpn_dagger_bee`).


## 6. Combat and the player experience (DR0-DR7, P06; rationale and simulation in `design_experience.md`, model in `design2/experience/sim/`)

The ASSUMED parts are marked: the three player skill archetypes of the combat model (novice / average / expert) are assumptions, the world of the model is 1-D, groups, terrain, ranged enemies and the real boss patterns are not simulated. All enemy, boss and assist numbers are Lua data, so retuning costs no code; the acceptance bots (`enemies.bot_fight_matches_model`, `bosses.bot_beats_each_boss_in_window`) run the REAL `Enemy2D` against a scripted "average" player and playtests must replace the archetypes.

### 6.1 The kit, the weapon curve, ONE damage / HP model (decision DX20)

Inputs unchanged (35 actions): `attack` LMB, `dodge` Space, `light` Q (fe-lys), `drink` R, `interact` E, `pause` Esc, `inventory` I. Built numbers (`lua/config/race_perks.lua:63-84`): 10 half hearts, swing 0.28 s (hit window 22-72 %, half angle 62 degrees, radius 197 ground px, cooldown 0.12 s, knockback 433), dodge 0.30 s / 317 px / i-frames 0.42 s / cooldown 0.9 s, fe-lys radius 550 / stun 1.6 s / cooldown 7 s, drink +4 half hearts, hurt i-frames 0.9 s. Three additions (P06; `dungeon_run.feel`): input buffer 0.15 s, the dodge cancels a swing after 40 % of it (measured: the average player loses 0.080 instead of 0.110 half hearts per standard encounter), hit-stop 3 physics frames; camera shake 2 / 4 px (off with `assist_reduce_flash`).

**The curve** `dungeon_run.expected_weapon` (sword-equivalent damage the combat is tuned to, floors 1-12): `5, 6, 8, 10, 12, 13, 15, 16, 18, 20, 22, 24`. It sits at the top of each rarity's range of the sword ladder (normal 5 / uncommon 12 / rare 22 / unique 30 / legendary 42): the starter sword is floor 1, `iron_sword` (smithy 750 gold) floor 5-6, a RARE weapon covers floors 1-12 (92 % of the curve at floor 12), a unique or legendary weapon is deliberate power (r 1.25 / 1.75). **Enemy hp = round(hits x curve(floor))** with light 0.6 / standard 1.6 / heavy 2.4 hits (standard: 8 10 13 16 19 21 24 26 29 32 35 38; heavy 12 ... 58); bosses 8 / 11 / 12 hits = **80 / 176 / 288**. The generator's proposal `hp_pct_per_floor` +20 % per floor is DROPPED (the two derivations agree: about +15 % per floor). `DungeonRun.enemy_hp(kind, floor)` is the one function; `enemies.lua` and `bosses.lua` carry `hits_x10`.

Damage per hit in half hearts by tier 1 / 2 / 3 / 4: light 1/1/1/2, standard 1/2/2/2, heavy 1/2/2/2, bosses 1; the assist "Let" subtracts 1 (minimum 1), "Hyggelig" makes every hit 1. Damage feedback is thorn-berry pink `e58fa6`, never red; no damage numbers.

### 6.2 Enemies: seven kinds, no new art, data-driven (DR3 `Enemy2D` from `lua/config/enemies.lua`)

| id (da) | visual + tint | class / behaviour | bands | special |
|---|---|---|---|---|
| `bat` (Flagermus) | `bat` | light / `chase_lunge` flier, altitude 73, speed 175, detect 550 | all | lunge reach 163 px; may hide in a bush |
| `ugleoje` (Ugleøje) | `ugleoje` | standard / `chase_lunge` walker, speed 160 | 2-4 | the classic bush ambusher |
| `tornebusk` (Tornebusk) | `tornebusk` | heavy / `stationary`: contact damage after 0.3 s inside 70 px (the ring shakes first); from tier 2 one thorn bolt per 3.5 s | all | drops `tornebaer` 50 %; destructible in 3 hits |
| `lysesvamp` (Lysesvamp) | `lysesvamp` | critter / `flee` 190 px/s inside 330 px, harmless, cornered it sleeps | critters | drops via the loot track |
| `mosfroe` (Mosfrø) | `frog` tint `3f7a5a` | standard / hops 0.35 s x 140 px, the lunge is a leap | 2 | harmless between hops |
| `sporesvamp` (Sporesvamp) | `lysesvamp` tint `9b86d6` | heavy / stationary `spore`: every 5 s a 1.0 s ring marks the player's cell, then a cloud r 150 px for 3 s that slows 40 % (no damage) | 3 | the grove's own enemy |
| `krystalugle` (Krystalugle) | `ugleoje` tint `6fd6c4`, glow | standard / `keeper`: stays 400 px away, 0.9 s thin line, then a light lance (2 half hearts), cooldown 4 s | 4 | the one ranged enemy |

The three extra kinds are ADOPTED (decision DX15; their drop rows are in `dungeon_loot.drops`). **Telegraph language:** cream pulse on the sprite + a ground ring / line decal that IS the exact hit area (`TelegraphRing2D.hit_area()` is the one source of truth, at most 8 visible) + a soft tick sound; windups 0.5 s ordinary (0.6-0.7 heavy), assist stretches x1.2 / x1.4; the windup trigger distance is lunge reach + 70 px (not the spike's fixed 317). **Bush ambush ("Øjne i mørket"):** `enemy ... ambush=1` makes DR3 draw the host prop `bush_eyes`; pink-red eyes `f25a6a` pulse from 780 px (x the lantern gem's `ambush_mult`), the bush rustles 0.6 s inside 330 px then the enemy leaps; Q reveals and stuns every ambusher within 550 px; allowed kinds bat, ugleoje, mosfroe, otherwise an ordinary enemy. **Leash:** an awake enemy never enters 520 ground px around a LIT node of group `runestone`. **Budgets:** enemies beyond 1.8 x detect are `process_mode = DISABLED` (96 sleeping cost 0.01 ms against 0.41-0.81 ms for 32 awake), <= 24 awake in view, <= 48 alive, the floor's roster is warmed behind the fade. **Seeded:** `RandomNumberGenerator` from `DungeonFloors.rng_for(area, cell, "enemy")`, drops replay with the seed. **Drops:** `LootService.on_enemy_defeated(kind, {floor, band, uid})` -> `results` -> one `LootDrop2D` orb per row (magnet 183 px x gem multiplier, pickup 0.25 s, <= 50 orbs); the enemy's own row is only the berry. Colour beacons (additive, visible outside the lantern): teal `6fd6c4` rest (runestone, glow patches), yellow `f2c14e` the way on (Hulen eyes), pink-red `f25a6a` eyes in the dark, warm gold treasure band, cream boss ring.

### 6.3 Three bosses (decision DX24; recolours of ONE baked sprite, variety lives in patterns and arenas)

| boss | floor | kind id | tint / halo | hp (hits x curve) | windup / dazed | pattern |
|---|---|---|---|---|---|---|
| Snurresvampen | 4 | `snurresvamp` | the bake as is | 8 x 10 = **80** | 1.0 / 1.8 s | **Snurre**: 90 px line telegraph locked 0.2 s before a 0.5 s dash at 540 px/s (`spin` clip), dazed; every 3rd cycle **Sporepuf** (ring 200 px, one harmless lysesvamp); doubled dash at 33 %; adds 4 |
| Glødesvampen | 8 | `snurresvamp_gloed` | `e8b04a` + amber halo | 11 x 16 = **176** | 1.0 / 1.7 s | Snurre at 620 px/s (two dashes in a row from 50 %), **Skælv** (ring r 260 around itself), **Sporesky** from 50 % (two clouds r 150, slow 40 %); adds 6 |
| Svampekongen | 12 | `snurresvamp_konge` | `7b6bb8` + violet-gold halo + `crown_spark` | 12 x 24 = **288** | 0.9 / 1.5 s | all of the above + **Sporeregn** from 66 % (3 volleys of 3 rings r 120 around the player, 0.35 s apart, each lands 1.0 s after its mark); adds 8 |

Common (DR4 `BossBase`): armored (a hit does not interrupt a windup or dash), damage 1 half heart per hit, bar `boss_bar_changed(name_key, ratio, true)` with phase ticks at 66 / 33 %, two `tornebaer` berries (+2 half hearts each) at 66 / 33 % of the boss's hp, adds (bats) in two waves at 66 / 33 %, the boss sleeps inside a cream ring decal and wakes at 520 ground px; leaving or passing out mid-fight changes no flag. **Kill flow (decision DX24):** the boss emits `enemy_defeated(id, kind, loot)` ONCE; D2's `DungeonFloors` marks the cell done, raises `dg_boss_clear` (roots part within 0.25 s because IsoArea polls flags; `HULEN_ROOTS_PART`), calls `DungeonRun.boss_killed(kind, floor)` (flag `dungeon_boss_<kind>` = day of the last kill; on the FIRST kill `dungeon_hearts_bonus += 2` and the toast `DEXP_SKOVHJERTE`) and emits `dungeon_boss_defeated`; the sealed `konge` chest opens after the flag and calls `LootService.on_boss_defeated`. The boss is regenerated every seed day; a stone start skips it; the reward cooldown (7 days) is the loot track's, so the boss is a gate, not a farm. Floor 12 has no Hulen: the home rope (sealed by the boss) and the whisper `DEXP_END_WHISPER` after the last boss. The hp ladder (hits 8 / 11 / 12) was chosen by sweep: the last boss at 14 hits made 19.7 % of the average player's fights lose more than 14 half hearts + 4 of berries, at 12 hits 5.9 %. The four-boss alternative (a moss bear, a night owl, a dusk fairy: three new bakes) is DATA on the generator side (`gen_check/dungeon_alt_warp.lua`, verified) and one package row here.

### 6.4 Hearts, healing, oil, darkness, assist

* **Hearts** `DungeonRun.hearts_max() = 10 + dungeon_hearts_bonus (0..6) + assist hearts (0 / 2 / 4)` = at most 10 hearts. "Skovens hjerte": +2 half hearts for each of the three bosses, once, on the first kill (the only permanent defensive progression; `hearts_per_boss = 0` removes it: open question 9).
* **Healing:** runestone (full), `health_tonic` +4 (R), `tornebaer` +2 (heals on pickup when hurt, else to the backpack), `svampe_eliksir` +6 (3 `glow_mushroom` + 1 `moss`), surprise `cocoa_thermos` +2, "Sidste gnist" (assist, once per run). No regeneration, no healing from kills (except the `heart_on_kill` dagger effect).
* **Oil:** 150 s; the generator's rule (refill on the FIRST arrival of every floor of a run and at every stone; leaving and re-entering the same day does not farm it) is applied by D2 through `Player2D.restore_oil()`; everything else is DR1's pure functions applied by P06: drain only on a generated floor and never while a modal is open or a dialogue runs (not in the hub), `assist_oil` 1 half speed / 2 never, the gem's `oil_mult`; light = max(oil / max, 0.35); the dark bites 1 half heart per 12 s at oil 0 **but never below 2 half hearts**; whisper `DEXP_OIL_LOW` at 20 %; auto-refuel at <= 15 s from `lantern_oil` (+60 s) then `lysdraabe` (+45 s) when `assist_auto_refuel` (default on); surprise `firefly_swarm` +15 s. Thorough play on floors 8-12 outlasts 150 s: the intended gold sink; a diver never sees it.
* **Lantern look (V8, measured):** colour `ffe9a8`, energy 0.10 (the sketch lift x1.3 R / x1.2 G; the plan's 0.9 is 8x too bright), radius 630 px at full oil, 220 px at the 35 % minimum.
* **Assist ("Hjælp i skoven"):** presets Standard / Let / Hyggelig / Egen over eleven toggles (`assist_dmg`, `_telegraph`, `_hearts`, `_arc`, `_dodge`, `_oil`, `_last_spark`, `_auto_swing`, `_auto_refuel`, `_reduce_flash`, `_hints`), per save, immediate, offered once after the 2nd pass-out, optional and never forced; **assist never touches loot odds, luck, rarity or prices** (asserted).

### 6.5 What the player sees

Forest HUD = the style guide's section 10 unchanged (hearts panel, lantern-oil pill with `xN` count, boss bar, circular minimap with the depth chip, loot feed, four ability slots, whisper box) plus a floor banner ("Etage 4" + zone name, once per arrival), a backpack chip at >= 20/24, an assist badge, a second heart row above 6 hearts. **Minimap fog:** cells within 14 cells of the player stay revealed for the visit (not saved) unless `DungeonFloors.is_revealed(floor)` (Natteblik's map shows everything); markers: runestone, Hulen, arrival cave once seen, chests once seen, nook chests within `DungeonRun.chest_sense_cells()`, awake enemies within 10 cells, the boss ring on boss floors. **Loot feed:** <= 4 rows, same item within 1.5 s merges, rarity ring + pips for EVERY category, weapons show "Skade N · Familie". **Reveal tiers** (`rare_item_found` fires AFTER the item is stored, so nothing is ever lost): T0 normal / uncommon = feed row; T1 rare = a bigger row with a pop and a lavender burst; T2 unique = a reveal card ("Unikt fund!", 3.0 s, skippable after 0.8 s); T3 legendary = the world holds its breath (enemies within 800 px stunned 3 s, dim to 45 %, the `<id>_night` tile rises, "Legendarisk fund!", 3.2 s). `assist_reduce_flash` makes it static. **Audio:** names only, silent when files are missing; 16 placeholder SFX are synthesised by P24; music stays silent names (`music/dungeon_act1..4`, `boss`, `boss_final`, `rune_rest`, `amb/forest_night`, `amb/cave_drip`).

### 6.6 First-time help, quests, services

* **Tutorial:** world flag `dungeon_tut`; at most one hint per 20 real seconds, never during a boss fight, never with `assist_hints` 0; all hints are whispers or a 3 s pulse of an ability slot: `DTUT_HUB`, `_LANTERN`, `_ABILITIES`, `_EYES` (after `WHISPER_FERNS`), `_RUNE`, `_CHEST`, `_BERRY`, `_HULEN`, `_BOSS`, `_WEAPON_WEAK`, `_ASSIST` (from the 2nd defeat on, then once per 3).
* **Picker lines** under the Port-runen's rows (`DungeonRun.picker_lines(start_floor)`, pure): weapon with "god til etage a-b" (amber when the rating is below 75 % of the curve of the highlighted floor), `Lygteolie: n`, `Tonika: n`, `Rygsæk: used/max`, and the user's rule made visible BEFORE the dive: "Besvimer du, mister du 10 % af dine guldagern (ca. N)".
* **Run summary** on a normal leave: three toasts ~1.2 s apart (floors / finds / best find); not after a defeat.
* **Services (DR7, data):** items `tornebaer`, `lysdraabe`, `svampe_eliksir`, `etagekort` (Natteblik's floor map, 40 gold, 5 per day, consumed on the first arrival at the next floor: `reveal_floor`, event `floor_map_used`), `ugle_noegle`; recipes `lysdraabe` (2 `glow_mushroom`), `svampe_eliksir` (3 + 1 `moss`); shop `natteblik_maps`; quests `skovlift_intro` "Første tur ned" (Oak; `dungeon_floor_entered`, `dungeon_runestone_activated`, `dungeon_run_ended`, report; reward 2 `lantern_oil`, 1 `health_tonic`, 100 gold, Oak +1), `rune_vandring` "Runernes vej" (Fru Ugle; a stone on floor >= 5 and >= 9; `ugle_noegle` + `gem_bag`), `ugles_noegle` (Fru Ugle, weekly; amethyst + rose_quartz + amber; key + 150 gold), `bossernes_vej` "Skovens tre vogtere" (Oak; the three boss kinds; 800 gold, 5 `fairy_dust`, 2 `gem_bag`). No keepsake rewards (validator R3 untouched).

### 6.7 Numbers from the model (ASSUMED archetypes; `experience/sim/*_results.txt`)

Floor 4 by day ~15, floor 7 by ~40, floor 10 by ~85, floor 12 by ~140 for the typical player (the loot pacing sim ran it: castle day 264 against 267 without it). An AVERAGE player with the curve weapon passes out in 0.0 % of floors 1-11 and 2.0 % of full dives (all at the last boss); with a weapon 25 % below the curve 31 % of full dives end in a pass-out; a novice with "Let" and the curve weapon 4 %, with "Hyggelig" 0.2 %; a novice WITHOUT assist hits a wall at bosses 2 and 3 (66 % / 92 % pass-outs from a stone start) unless the weapon is a unique one (boss 2 then costs 10 half hearts): exactly the two valves the design wants (loot progression and the assist hint after the second defeat). Boss fights (average, curve weapon, before the berries): 3.4 / 6.7 / 8.7 half hearts lost in 18 / 30 / 39 s. The second rest stone on boss floors (variant B, `stone = true` on 4 / 8 / 12) would cut full-dive pass-outs from 2.0 to 0.6 % and is NOT adopted (data switch; digests would be re-pinned).

### 6.8 Gentle defeat (user decision U3; D0 + P06 + DR1)

Sequence in `WorldRoot2D._on_player_defeated` (D0, <= 40 changed lines; guard `_faint_pending` kept): wait 1.3 s (faint pose, falling stars as built) -> fade out -> `DungeonFloors.inst().end_run(&"defeated")` (event `dungeon_run_ended {reason: defeated}`) -> `GameManager.sleep_until_morning()` (the farm grows one day; before the 02:00 day-end roll, the raw hours 6..25, the day-end autosave fires) -> `EconomyManager.spend_gold(floori(gold * 10 / 100))` (`dungeon.defeat.gold_loss_pct`, rounded DOWN, NEVER capped) -> `travel(farm, from_home)` -> `player.revive()` (hearts to `DungeonRun.hearts_max()`, oil reset) -> whisper `WHISPER_FAINT` -> ONE warm toast through `DungeonRun.after_defeat(loss)`: "Besvimet i mørket" / "Ugleøjnene bar dig hjem. Du mistede {gold} guldagern, men beholdt alt andet." (or "...Du beholdt alt." when the loss is 0). Kept: every item, equipment, quests, furniture and wardrobe, the lit stones, the deepest floor. Edge cases are tests: gold < 10 -> loss 0; 999 999 -> 99 999; a defeat after the 02:00 day-end roll (raw hours 2..5) still wakes at 06:00 of the same date, a defeat at 00:xx or 01:xx (raw 24 / 25, the same game day) wakes at 06:00 of the NEXT date (CLOCK_26 CK-A-D0); two `player_defeated` in a frame -> one sequence; no farm map -> the default area; a defeat on a boss floor sets no flag. Honest: a defeat costs the REST OF THE DAY and 10 % of the gold (a median defeat about 880 gold of a typical wallet = 2-6 band runs of loot); at 21:00 that is almost nothing, at 07:00 it is the farm day (crops stay unwatered but do not die): the evening dive is the natural rhythm. The picker shows the amount before every dive.


## 7. Characters and environment: alignment with the Style Guide v2 sketches (V1-V10; rationale in `design_v2.md`)

### 7.1 Six heroes, two per race (V1 data, A2 bases, P16 chips, F5 / F8 lists)

| hero id | race | skin id | look (A2 base) | name / kind |
|---|---|---|---|---|
| `rasmus` (default) | animal | `animal_fox` | `fox_base` | Rasmus / Ræv |
| `kiki` | animal | `animal_monkey` | `monkey_base` | Kiki / Abe |
| `kloevermynte` (default) | fairy | `fairy_meadow` | `fairy_base` | Kløvermynte / Fe |
| `birk` | fairy | `fairy_birk` | `fairy_birk_base` | Birk / Fe |
| `bertil` (default) | hobbit ("Halvling") | `hobbit_pip` | `hobbit_pip_base` | Bertil Bøgeknop / Halvling |
| `bodil` | hobbit | `hobbit_bodil` | `hobbit_bodil_base` | Bodil Bøgeknop / Halvling |

The cards are LOOKS: the player still types a name on page 2. The seven other skins (`animal_rabbit animal_hedgehog animal_squirrel fairy_stardust fairy_dusk hobbit_moss hobbit_bramble`) stay as RETIRED data rows (`retired = true`, wardrobe body re-pointed to a live hero: built tests pin their chains) and are not offered or baked as wardrobe bases. Species perks (`lua/config/species_perks.lua`, resolved only through `SpeciesPerks.value(skin, key, default)`): `animal_monkey` = dig 1.0, tool cost 0.9, harvest bonus 0, `climb_speed_mult` 2.2 (ladder 1.1 s -> 0.5 s), `chest_sense_px` 700 (= 7 cells in the dungeon, decision DX31), `crown_caches` (one hidden cache per day in the city); Rasmus is the race baseline. Wardrobe cost: 101 bakes (monkey native body scope; Bodil / Birk borrow head scopes, 123 in the worst case) against 112 for ten bases; Rasmus's scarf and Kiki's banana are NOT baked (open question 12).

### 7.2 The cast: 22 NPCs (15 + 7)

New rows (`name_key = NPC_<ID>`, `friendship = true`): `gardener_hoppe` (the PACK rabbit, no new art, dE00 1.4), `carpenter_brumme` (`bear_brumme`, shop `timber_yard`, Torvet stall on Saturday and Sunday through two markers and two world flags), `postman_pip` (`hedgehog_pip`; quest `pips_runde`; the farm mailbox flag-up + one toast per day is the whole "morning visit"), `bathkeeper_sofus` (`capybara_sofus`, the ONE new body; the bath: once per day, 30 game minutes, full energy and hearts), `appraiser_fru_ugle` (`owl_fru_ugle`, owl hole of tree A, `quests_offered {ugles_noegle, rune_vandring}`), `mapseller_natteblik` (`bat_natteblik`, home `moerkeskoven`, NO `shop_id`; shop `natteblik_maps` names him as keeper), `beekeeper_birk` (`fairy_birk_npc`, Hyggebyen, three beehive stands). Kløvermynte (`fairy_shopkeeper`) and Morfar Mis (`cat_morfar_mis`) are re-baked in place; `guard_oak` moves to the Skovlift; `penguin_postman` stays the ambient courier. Dialogue: 7 files (V7) with voice keys `voice/<npc_id>/<line_id>` (Pip's path is `voice/postman_pip/`, never `voice/pip/`). Palette gate: dominant-region dE00 <= 6 of the idle-S frame against the sketch fill (`art_cast_v2.palette_within_de`); sprite style: palette snap everywhere, ink outline on busts only, world sprites keep the pack outline pending the user's choice (open question 12).

### 7.3 Trætoppen, the treetop city (V3 framework, V4 map, V5 art, V6 life)

A LEVELLED builder area (`@builder`): 8 round platforms (`a b c torvet upper e f g`, painted heights = ranked `z_index` 10 .. 160), 9 rope bridges (ranks 30 .. 170), one ladder (1.1 s, monkey 0.5 s), the rope-basket Skovlift, 14 buildings (13 huts + the lavender Rådhus), 32 hanging lanterns + 14 door lamps (<= 12 PointLight2D, the rest additive halos), 3 owl holes, 3 bat houses, 3 planters, stall, fire pit, tub, log stack, notice board, seed basket, 2 foliage clusters, canopy frame. The level of an actor is a FUNCTION OF POSITION (`LevelTracker`), colliders live on per-level physics bits 12..28 (no shared world bit), no built framework file is edited (prototype: 14 checks green with the real harness). K = 3.0 world px per sketch px (ONE constant `traetoppen.scale`). Budgets: <= 6 ms and <= 250 draw calls at zoom 0.4, rebuild <= 40 ms (stand-in measurement 3.7 ms / 580 nodes / 93 MB), <= 12 lights. The ten landmarks (Torvet, Rådhuset, Postkontoret, Hoppes hytte, Brummes værksted, Badehuset, Køkkenhaverne, Hængebroer, Uglehulerne, Flagermusenes huse) emit `landmark_entered`. Interactables (V6, data in `lua/config/traetoppen.lua`, which V3 owns together with `data/traetoppen/traetoppen.json`: V5, V6 and P13 read them at their own gates, earlier than V4's wave 5b): `mailbox` (farm + post office; one letter per day = Pip's first quest, then the next offerable everyday quest), `board` (Rådhus; up to 5 offerable everyday quests), `bath`, `seed_basket` (2 carrots -> 1 rare seed, once per day: no gold arbitrage), `kiki_cache` (monkey only), `rejsestolpe` (STRETCH, cut first). Honest: Pip never walks to the farm; parcels are not modelled; the hanging bats are static sprites.

### 7.4 Hyggebyen

Not in the city sketch: P11's 40 x 40 grid blueprint (seed shop, bakery, builder yard, furnisher and tailor stalls, smithy, animal store, wizard tower, the king's house, flea stall, town hall, fountain) with the v2 changes: ONE bridge on the east side to `traetoppen:from_hyggebyen`, Oak gone, Birk with three beehive stands, Mis `when=done:lost_cat`. "Inside Trætoppen" = a district one bridge away (open question 12 offers an extra district sketch).

### 7.5 Mørkeskoven's look

Sketch -> generator -> art: the 14 crowns (S 4 / M 3 / L 7) around a clearing, the S-curve path 2.9 cells wide, the Moon pond with lily pads and the chest on its shore, a runestone beside the path, the Hulen stone ring far lower right, 2-3 bush clumps with eyes, 4 glow-mushroom clusters, fireflies, a lantern of radius ~6.6 cells (section 3.4 has the element table). Lighting recipe (measured in Godot 4.7.2): ambient `4d5e85` (x0.30 / 0.37 / 0.52), vignette 0.78, baked albedo = sketch colour / ambient (path `3b3c5e` -> `c3a3b4`, crown base `2e3556` -> `9890a5`), anything above `R 77 / G 94 / B 133` is an additive layer or an unshaded actor, lantern E 0.10, hard cap of 16 PointLight2D per canvas item, which drops lights by allocation details, not by tree order or child index (measured, 3.4): the budget (at most 12 map lights + the lantern per canvas item) is the rule, not a child index. Art (P22): crowns, bush eyes, cave rings, runestone, pond, seamless ground textures, mist and firefly dots, `home_rope`, the experience layer's decals and fx.

### 7.6 HUD of the city mock (P17)

Nine differences between the mock, the v0.1 guide and P17 (date block "Forår · Dag 14", gold + horizontal Energi chip top-right, the zone banner top-centre `tr(area.map.title)`, selected-slot style, inner keyline panels); the forest HUD (DR5) is unchanged guide section 10 plus the additions of 6.5. The zone banner is hidden in action areas where the forest chip and boss bar take over.

### 7.7 Coverage

Every element of the three v2 sources (13 figures, city landmarks 1-10, forest callouts 1-7, the HUD mock, the zone graph) has an id and an owner: `design_v2.md` section 11, executable as `docs/qa/v2/sketch_coverage.json` (V10, `zz_v2.sketch_coverage_complete`). Cross-track items checked by V10: `natteblik_maps` is a real shop with its keeper, `open_appraisal` has a listener (F4's LootService, which hosts DL7's screen), the `hidden` chest flag and `SpeciesPerks.chest_sense_px` are read by the chest handler (F4), no new autoload / action / signal, no old town name.


## 8. Contracts in ONE place (exact names; the single source for every package of this addendum)

### 8.1 Autoloads, child nodes, static classes, project.godot (E1)

* **No new autoload.** The 11 base autoloads (`EventBus GameManager LocalizationManager SaveManager EconomyManager QuestManager LuaRuntime TimeManager AudioManager ShopSystem AnimalHusbandry`) and the feature autoloads (`HomeManager FurnitureManager WardrobeManager LootService`, optional `CollectionLog`) stay exact (`tests/tools/check_project.gd`); `project.godot` is NOT edited by any package of this addendum (the sanctioned exception E1 is not used).
* **Child nodes:** `LootService/DungeonFloors` (class `DungeonFloors`, scripts/dungeon/floors/dungeon_floors.gd, added by F4's `_ready` when the script exists, section `dungeon` order 45), `EconomyManager/Arsenal` (class `Arsenal`, created in EconomyManager's `_ready`), `forest_hud.tscn/RunWatch` (created by `DungeonRun.attach(host)`, idempotent), `area/ForestLook` (created by `ForestDress.attach`), `area/LevelTracker`, `LevelGlow`, `OccluderFade` (V3, created by V4's builder).
* **Static classes (no node, no state unless named):** `DungeonRng DungeonGen DungeonExport DungeonVerify` (D1, `scripts/dungeon/gen/`), `DungeonRun` (DR1, rules only, NO run state), `DungeonLootRules LootRng` (DL5), `WeaponInfo WeaponFx LanternGem` (DL3, `scripts/combat/`), `SpeciesPerks` (V1, `scripts/data/species_perks.gd`), `CharacterCatalog` (P05, edited by V1: `heroes(race) hero_of_skin(skin) is_retired(skin)`), `LevelRegistry ActorLevel LevelRules` (V3), `ForestDress` (V8).
* Names that differ across the track documents: the RUN NODE is `DungeonFloors` (the loot document's `DungeonRun.inst()` reads `DungeonFloors.inst()`); the RULES class is `DungeonRun` with config key `dungeon_run`.

### 8.2 Input actions: none new (35 stay exact, `tests/tools/input_contract.gd`)

Used as built: `attack` (LMB), `dodge` (Space), `light` (Q), `drink` (R), `interact` (E), `pause` (Esc), `inventory` (I), the `ui_*` actions of the rune picker and the appraisal screen. Weapons are equipped in the Rygsæk (no action, no hotbar slot); the minimap needs no key; the Skovlift, ladder, bath, mailbox, board and caches are E-interactables. No key-remapping UI exists in the plan and none is added.

### 8.3 EventBus signals: none new (75 stay exact, arity lint)

Everything new travels through the existing escape hatch `game_event(name: StringName, payload: Dictionary)` (consumers ignore unknown names). Existing signals consumed as built: `area_changed area_change_requested zone_entered zone_unlocked enemy_defeated(enemy_id, kind, loot) player_defeated player_health_changed player_oil_changed player_stats_changed item_gained rare_item_found loot_rolled boss_bar_changed combat_finished whisper_requested notification_posted player_inventory_changed gold_changed day_started save_completed new_game_started modal_changed`.

### 8.4 `game_event` names (payloads are JSON-safe; every payload of the dungeon events carries `floor` and `level` = the floor number, so P13's `min_level` filter reads "floor >= N")

| name | payload | emitter | consumers |
|---|---|---|---|
| `dungeon_floor_entered` | `{floor, level, band, zone, seed_day, first_today, deepest}` (`deepest` bool) | D2 on `area_changed` to a floor | DR5 banner, DR1 RunWatch (tally, tutorial, `etagekort`), quests |
| `dungeon_runestone_activated` | `{floor, level, band, first_time, waypoint}` | D2 (stone touched) | DR1, quests (`rune_vandring`, `skovlift_intro`), toast `RUNE_ACTIVATED` |
| `dungeon_boss_defeated` | `{boss, kind, floor, level, first_kill}` (`first_kill` = the result of `DungeonRun.boss_killed`) | D2 on `enemy_defeated` of a boss kind | HUD, quests |
| `dungeon_run_ended` | `{reason: left\|defeated, deepest, floors}` | D2 `leave()` / `end_run()` | DR1 summary (`left` only), quest `skovlift_intro` |
| `dungeon_floor_revealed` | `{floor, level}` | D2 `reveal_floor` | DR5 minimap |
| `floor_map_used` | `{floor}` | DR1 RunWatch (an `etagekort` is consumed) | DR5 toast, quests |
| `dungeon_hint` | `{id}` | DR1 tutorial | DR5 pulses the ability slot |
| `assist_changed` | `{preset}` | DR1 `set_assist` | DR5 badge, P06 re-reads multipliers |
| `skovhjerte_grown` | `{bonus, hearts_max}` | DR1 `boss_killed` | DR5 hearts, P06 maximum |
| `dungeon_surprise` | `{id, oil_s}` \| `{id, gold}` \| `{id, heal_half_hearts}` \| `{id, hint_key}` | LootService (DL5 rules) after an ordinary / lake chest | DR1 RunWatch applies it and toasts (`DEXP_SURPRISE_*`) |
| `loot_keepsake_found` | `{item, rarity, source}` | `LootService.deliver` | DR5 (optional reveal), CollectionLog |
| `loot_day_capped` | `{day}` | LootService | whisper `LOOT_DAY_TIRED` (once) |
| `open_appraisal` | `{npc}` | P14 `emit_event` of Fru Ugle's dialogue (V7) | F4's LootService (the host): instantiates DL7's `scenes/ui/appraisal_ui.tscn` once into the `game_ui` layer and calls its `open(npc)`; ignored while the scene does not exist (S21) |
| `appraisal_done` | `{stone, gem, rarity, fee}` | DL7 | DR5 reveal (rare or better) |
| `landmark_entered` | `{id, name_key}` | V4 city triggers | P17 sub-banner |
| `ladder_climbed` / `lift_ride` | `{actor}` / `{to_area}` | V3 | P24 cues |
| `post_read` / `board_read` | `{quest_id}` / `{}` | V6 | P24 cues |
| `bath_request` (in) / `bath_taken` | `{npc}` / `{minutes}` | Sofus's dialogue (P14) / V6 | V6 / P24 |
| `swap_seeds_request` (in) / `seeds_swapped` | `{npc}` / `{item}` | Hoppe's dialogue / V6 | V6 / P24 |
| `cache_found` | `{slot}` | V6 | P24 |

There is NO `dungeon_run_started` (the first `dungeon_floor_entered` after a hub visit starts RunWatch's tally).

### 8.5 World flags (in the built `game` section; JSON-safe)

`dg_boss_clear` (bool; set when the boss cell is in `done`, cleared on every `area_changed`; read by IsoArea through `when=flag:dg_boss_clear`), `dungeon_hearts_bonus` (int 0..6), `dungeon_boss_snurresvamp` / `_snurresvamp_gloed` / `_snurresvamp_konge` (int: `total_day()` of the last kill, 0 = never), `dungeon_defeats`, `dungeon_gold_lost` (stats), `dungeon_tut` (String, comma list of finished hints), `assist_preset` (String none / light / cozy / custom) and the int flags `assist_dmg assist_telegraph assist_hearts assist_arc assist_dodge assist_oil assist_last_spark assist_auto_swing assist_auto_refuel assist_reduce_flash assist_hints`; v2: `post_read_day post_toast_day bath_day swap_day cache_day brumme_at_stall brumme_at_work ft_farm ft_torv ft_hyggebyen ft_skovlift`. Every flag is reset by `new_game_started`.

### 8.6 Save (no new section except `dungeon`; SaveManager `FEATURE_ORDERS` is passed explicitly: 45)

| where | key | content | owner |
|---|---|---|---|
| section `dungeon` v1, order 45 | `v gen spec world_seed seed_day active floor deepest stones[] seen[] done{floor:[cell indexes, sorted]} reveal[]` | the run and the consumed state of THIS seed day; `world_seed` is decimal TEXT; a `gen` / `spec` mismatch drops the run and keeps `stones`, `deepest`; worst case about 2.7 KB; `validate_payload` ok | D2 |
| section `loot` v1 (order 40), optional sub-dict `dungeon` | `found{item:day} claimed[] wander{zone:tier:n} boss{id:{kills,last_day,last_uid,misses,pool_left,first_done}} appraise{band: n_band} (one counter per band) day{day,value,capped} unique_day` | keepsake registry, pity, caps, appraisal counter; absent = empty; < 3 KB | F4 hosts, DL5 state helpers |
| section `economy` v1, optional key | `arsenal {id: count}` | weapons (cap 9 copies per id) | DL1 |
| section `game` | the world flags of 8.5 | | DR1 / V6 |

NO second world seed, NO `opened{}` entry for `dg:` uids, NO vitals (a load starts with full hearts and a refilled lantern), NO stored layout (it is a pure function of seed, day, floor). A save inside the city stores `area` + `player_pos` (the level is a function of position).

### 8.7 APIs (signatures are the contract; the owner implements, everyone else calls; every call to a LATER or SAME-wave package is late-bound with `Svc` and null-safe)

```gdscript
# --- D2 scripts/dungeon/floors/dungeon_floors.gd  (class_name DungeonFloors extends Node; child of LootService)
static func inst() -> DungeonFloors                         # null = "no dungeon"
static func ensure_registered(floor: int, total_day: int) -> StringName   # THE seam: generate (or take the prefetched text) + register_map, return the id
static func floor_of_id(area_id: StringName) -> int         # 0 unless moerkeskoven_f<N>
static func floor_of(area: IsoArea) -> int                  # from area.map.extra["floor"], 0 on a static map
func world_seed_text() -> String ;  func set_world_seed(v: int) -> void
func rng_keyed(stream: String, key: int) -> DungeonRng       # hash_key(world_seed_text + "|" + stream, 0, key)
func rng_for(area: IsoArea, cell: Vector2i, purpose: String) -> DungeonRng
func uid_of(area: IsoArea, cell: Vector2i) -> String        # "dg:<day>:<floor>:<cell index>"
func is_done_cell(area, cell) -> bool ;  func mark_done_cell(area, cell) -> void
func floor_id(n: int) -> StringName ;  func band_of(n: int) -> StringName ;  func current_floor() -> int
func start_run(first_floor: int = 1) -> StringName ;  func enter(n: int) -> void ;  func leave() -> void ;  func end_run(reason: StringName) -> void   # &"left" | &"defeated"; leave() and end_run() call GameManager.pop_all_modals() BEFORE the travel (a request under the pause modal does not travel)
func activate_stone(n: int) -> bool ;  func has_stone(n: int) -> bool ;  func start_floors() -> Array[int]    # [1] + stones
func reveal_floor(n: int) -> void ;  func is_revealed(n: int) -> bool ;  func prefetch(n: int) -> void
func to_dict() -> Dictionary ;  func from_dict(d: Dictionary) -> bool ;  func reset() -> void

# --- D1 scripts/dungeon/gen/  (pure, integer only, scene-free)
DungeonRng: static hash_key(save_id_text: String, day: int, floor: int) -> int ;  below(n) range_i(lo, hi) chance_bp(bp) weighted(weights) shuffle(a) noise1(...)
DungeonGen: static build_text(cfg: Dictionary, floor: int, floor_seed: int, ctx: Dictionary) -> Dictionary {text, stats, crowns} ;  static fallback(spec) ;  static crown_rows(cls) ;  static crown_covers(cls, x, y, fx, fy) ;  const SOLID_MARKERS
DungeonExport.build(fl, cfg, ctx) ;  DungeonVerify.verify(map, spec, cfg, ctx, tally)        # 46 invariants, one check id each

# --- DR1 scripts/dungeon_run/dungeon_run.gd  (class_name DungeonRun, all static)
cfg(path, default)  expected_weapon(floor) -> int  weapon_family(f) -> Dictionary  weapon_rating(item_id) -> float  weapon_ratio(item_id, floor) -> float  weapon_range(item_id) -> Vector2i
enemy_hp(kind, floor) -> int  enemy_damage(kind, tier) -> int  boss_hp(kind) -> int  hearts_max() -> int  hearts_bonus() -> int
oil_step(oil, dt, ctx{paused, on_floor, assist_oil}) -> float  light_ratio(oil) -> float  bite_due(oil, hearts_half, since_last) -> bool  auto_refuel_item(oil, owned) -> StringName
assist(key) -> Variant  set_assist(key, value)  apply_preset(id)  windup_mult() dmg_minus() assist_hearts() arc_pct() dodge_bonus()
boss_killed(kind, floor) -> {first, hearts_bonus}        # called by D2 only
after_defeat(gold_lost)                                   # impure: toast DEXP_DEFEAT_*, counters, hint; called by D0
picker_lines(start_floor) -> Array[{kind, text, warn}]  tutorial_say(id)  attach(host: Node)
chest_sense_cells() -> int  chest_sense_px() -> int       # MAX of species px / cell_px, LanternGem cells, reveal_chests cells; capped 12

# --- F4 LootService (autoload; every answer {ok: bool, results: [{id, amount, rarity, kind}], reason: StringName}; every MUTATING call is two-phase: plan -> fit -> deliver -> commit, or {ok:false, reason:&"full", results:[]} with NO state change, 5.7)
open_container(zone: band id, container_id: tier, uid, ctx := {})  dig(zone, uid, ctx)  node_loot(kind, uid, ctx)  on_enemy_defeated(kind, ctx)
on_boss_defeated(boss_id, ctx)         # idempotent per ctx.uid;  claim_spot(spot_id, ctx)  spot_state(spot_id) -> &"open"|&"claimed"|&"cooldown"|&"locked"
appraisal_quote(rough_id) -> {band, fee}  appraise(rough_id, ctx) -> {ok, gem, rarity, fee, reason}  found(item_id) -> bool
deliver(item_id, amount := 1) -> {ok, sold, reason}      # THE one place items enter (pickup orbs call it)
day_value()  daily_cap_reached()  set_seed(int)          # ctx = {dungeon, floor, band, rng, luck, lock_ok, first_kill, ready, uid, deliver};  ctx.odds is IGNORED

# --- DL5 scripts/dungeon_loot/  (static, pure: state in, plan out)
DungeonLootRules: depth_odds(base, floor, luck, cfg)  roll_container(...)  roll_node(...)  roll_drop(...)  roll_appraisal(...)  boss_result(...)  daily_add(...)  unique_ready(...)   # every roll_* is a PLAN (reads a copy of the state, mutates nothing)
                  fits(plan, pack_view) -> bool   commit(state, plan) -> state          # pack_view = {free_slots, stack_room{item}} from EconomyManager; commit is the ONLY mutator (pity, misses, day value, boss state, claimed, unique_day, appraise counter of the band)
LootRng.keyed(stream, key) -> Object    # = DungeonFloors.inst().rng_keyed; without the node a DungeonRng seeded from LootService.set_seed

# --- DL3 scripts/combat/  (static)
WeaponInfo.of(id) -> {family, damage, cycle, rating, sword_equiv, swing, effect}  rating(id)  sword_equivalent(id)
WeaponFx.on_swing(player, swing_index)  on_hit(player, enemy, damage)  on_kill(player, enemy)  on_light(player, params) -> Dictionary  on_dodge(player)
LanternGem.effects(id) -> {tint, oil_mult, radius_mult, light_cd_minus_s, chest_sense_cells, ambush_mult, pickup_mult}  equipped() -> StringName

# --- DL1 scripts/economy/arsenal.gd  (class_name Arsenal extends Node, child of EconomyManager)
add(id, n) -> bool  remove(id, n) -> bool  count_total(id)  can_add(id, n)  owned_ids()  count_stock(id)  to_dict()  from_dict(d)  reset()
ItemKinds.WEAPON := &"weapon" (storage_of);  Rarity.sell_ratio(id, kind := "")

# --- P06 Player2D (callers: D0, D2, EconomyManager, V6, DR1, DR3, DR5)
heal_full()  restore_oil()  add_oil(seconds)  heal_half(n)  restore_stamina(n)  revive(pos)  restore_after_sleep()  cd_ratio(slot)
# --- V1 SpeciesPerks.value(skin, key, default) / current(key, default);  CharacterCatalog.heroes(race) hero_of_skin(skin) is_retired(skin)
# --- P13 QuestManager.offerable(npc_id)  offerable_for(givers)
# --- V8 ForestDress.attach(area, params) ;  marker `forest_dress` (same effect)
# --- V3 LevelRegistry.level_at(pos)  ActorLevel.set_level / lock / unlock  LevelRules.validate(data)  (+ BridgeStrip Railing ClimbLane RopeLift OccluderFade LevelGlow)
```

### 8.8 Lua: config keys, kinds, files (top-level config keys are unique across files; the loader scans `lua/` recursively)

| config key | file | owner | notes |
|---|---|---|---|
| `dungeon` | `lua/config/dungeon.lua` | D1 | the ONE floor table, bands, rim, limits, hub, oil, defeat, flags, key_item, hard_nodes |
| `dungeon_run` | `lua/config/dungeon_run.lua` | DR1 | hearts, curve, ladders, oil, feel, weapon_families (5 rows), weapon_effects (8 ids), assist, tutorial, summary, reveal, boss, audio, cell_px |
| `enemies` | `lua/config/enemies.lua` | DR3 | reserved by P19, now defined (7 kinds) |
| `bosses` | `lua/config/bosses.lua` | DR4 | 3 rows |
| `dungeon_loot` | `lua/config/dungeon_loot.lua` | DL4 | bands, bosses, depth, unique, daily, node_yields (aliases + fallback), drops, surprises, appraisal, limits, lantern_gem; NO floor_loot |
| `forest_look` | `lua/config/forest_look.lua` | V8 | lantern, fireflies, mist, unshaded groups, light budget |
| `traetoppen` | `lua/config/traetoppen.lua` | V3 (moved from V4: V5, V6 and P13 read it before V4's wave 5b) | scale 3.0, post, board, bath, swap, stall, caches, skovlift, fast_travel |
| `species_perks` | `lua/config/species_perks.lua` | V1 | per SKIN |
| (data) | `lua/items/weapons.lua gems.lua dungeon_materials.lua` (DL2), `lua/items/dungeon_supplies.lua` (DR7), `lua/recipes/dungeon.lua` (DL2), `lua/dungeon_run/{recipes,shops}.lua` (DR7), `lua/shops/{smithy,magic_store}.lua` (rows by DL2), `lua/shops/timber_yard.lua` (V1), `lua/quests/{skovlift_intro,rune_vandring,ugles_noegle,bossernes_vej}.lua` (DR7), `lua/quests/pips_runde.lua` (V1), `lua/quests/snurresvampen.lua` (D0), `lua/dialogue/<7 npc ids>.lua` (V7), `lua/data/loot_tables.lua` (DL4) | | no new Lua KIND; existing kinds items / recipes / shops / quests / dialogue / config |

### 8.9 Marker vocabulary (what handlers exist; unhandled markers are skipped silently and counted)

| marker | params | built by |
|---|---|---|
| `spawn` | `name=from_down` \| `name=rune` (default spawn is `@`) | built-in |
| `warp` | `to spawn label prop r [when=flag:dg_boss_clear]`; props `cave_ring` (Hulen), `cave_ring_up`, `home_rope` | built-in `Warp2D` |
| `runestone` | `id=rune_f<N>` \| `id=rune_hub hub=1`, `waypoint=1`, optional `quest= objective=` | D2 `runestone_2d.gd` (registered by F4) |
| `chest` | `tier=trae\|jern\|fe\|konge\|noegle role=main\|nook\|lake\|boss [lock=ugle_noegle] [hidden=1] [when=flag:..] [boss=<kind>]` | F4 `loot_chest_2d.gd` |
| `dig_spot`, `unique_spot id=` | | F4 |
| `enemy` | `kind tier [ambush=1] [critter=1] [boss=1 adds=N]` | DR3 `Enemy2D.create_marker(params, pos, cell, area)` (`LAZY_HANDLERS`; the entry point the built `IsoArea._handler_api` picks first: arity 4; null for a done cell) |
| `node` | `kind=<node kind> [when=night]` | P19 `resource_node_2d.gd` (`create_marker(params, pos, cell, area)`; null for a done cell) |
| `light` | `kind=glow r=170 h=30` | built-in |
| `whisper` | `text=<KEY> r=2` | P19 `whisper_zone.gd` (`create_marker(params, pos, cell, area)`) |
| `npc`, `quest_spot`, `sign` | from anchors rows / hand-authored maps | P14 `npc_2d.gd` / built-in |
| `hulen_keeper` | `npc=mapseller_natteblik` (floors 2 / 6 / 10) | V8 (registered by F4) |
| `forest_dress` | `fireflies= mist= unshaded=1` (hand-authored areas; generated floors get it from D2) | V8 (registered by F4) |
| `mailbox` | on `farm.map` and the post office | V6 `post_box_2d.gd` (registered by F4) |
| city markers `board bath seed_basket kiki_cache rejsestolpe lift climb` | | instantiated by V4's builder from V3 / V6 classes: NO row in `marker_handlers.lua` |

Deleted from the first drafts: the interactive `hulen` marker, `path_line`, `ground_decal`, `fishing_spot`, `lift` / `skovport` entrance markers of the experience version 1.

### 8.10 Localization: CSV files, owners, key families (merged table: `key_owners_additions.json`; the lead merges it into P03's `tools/loc/key_owners.json` at the start of each wave)

| CSV | owner (wave) | families / content |
|---|---|---|
| `dungeon.csv` | D1 (4) | `DUNGEON_` `RUNE_` `HULEN_`: whispers x7, `DUNGEON_PROMPT_GLOWING`, `DUNGEON_LEAVE`, `DUNGEON_LEAVE_CONFIRM`, `DUNGEON_RUN_RESET`, `DUNGEON_FLOOR_FMT`, `RUNE_ACTIVATED` `RUNE_REST` `RUNE_PROMPT` `RUNE_PICKER_*`, `HULEN_ROOTS_PART` |
| `dungeon_run.csv` | DR1 (4) | `DEXP_` (defeat, summary, oil, backpack, weak hint, end whisper, map read, Skovens hjerte, last spark, weapon range, **surprises**), `DPICK_`, `ASSIST_`, `DTUT_`, `FUND_`, `WEAPON_FAMILY_` |
| `dungeon_services.csv` | DR7 (4) | items `ITEM_TORNEBAER` `_LYSDRAABE` `_SVAMPE_ELIKSIR` `_ETAGEKORT` `_UGLE_NOEGLE` (+ `_DESC`) via `item_files`, `RECIPE_LYSDRAABE`, `RECIPE_SVAMPE_ELIKSIR`, `SHOP_NATTEBLIK_MAPS(_GREETING)`, `QUEST_` / `OBJ_` of the four quests |
| `dungeon_items.csv` | DL2 (4) | `ITEM_<ID>[_DESC\|_HINT]` of 51 ids via `item_files`, `WEFFECT_` (8), `WSTAT_` (7), `GEMFX_` (9), `RECIPE_DNG_` (13): 157 rows |
| `loot_dungeon.csv` | F4 (4) | `LOOT_DAY_TIRED`, `LOOT_KEEPSAKE_FOUND_FMT`, `LOOT_RUNE_VAULT_NEEDS` (three shards), `LOOT_LAKE_LOCKED` |
| `levels.csv` | V3 (4) | `LEVEL_PROMPT_CLIMB` "Klatre", `LEVEL_PROMPT_LIFT` "Tag liften" |
| `cast.csv`, `dialogue_cast.csv` | V1, V7 (4) | `CAST_ HERO_ SHOP_TIMBER_ QUEST_PIPS_RUNDE_ OBJ_PIPS_RUNDE_`; `DLG_HOPPE_ DLG_BRUMME_ DLG_PIP_ DLG_SOFUS_ DLG_UGLE_ DLG_NATTEBLIK_ DLG_BIRK_` |
| `core.csv` | V1 (owner change from P03) | `ZONE_TRAETOPPEN`, `ZONE_FARM` text, seven `NPC_*` names |
| `areas.csv` | P11 (4) | `SIGN_MOERKESKOVEN_HUB`, `SIGN_MOERKESKOVEN_WHISPER`, `SIGN_FARM_FOREST` |
| `forest.csv` | DR3 (5; owner change from P19) | `ENEMY_*` (7 kinds), `BOSS_SNURRESVAMPEN` `BOSS_GLOEDESVAMPEN` `BOSS_SVAMPEKONGEN`, `ABILITY_SLASH/DODGE/LIGHT/DRINK`, exact `WHISPER_FERNS` |
| `finds.csv` | DL4 (5; owner change from F1) | + `FIND_SPOT_LYSSTUBBEN _TORNEHEGNET _GLODESTENEN _SOESKATTEN_SKOV _SOESKATTEN_BREGNER _SOESKATTEN_LUND _RUNEHVAELVINGEN`, `FIND_CONTAINER_NOEGLE` |
| `life.csv`, `look.csv` | V6, V8 (5) | `LIFE_`, `LOOK_` |
| `traetoppen.csv`, `appraisal.csv` | V4, DL7 (5b) | `TRAE_` (landmark names, prompts, lift, signs), `APPRAISE_` (12 rows) |

Copy that this addendum fixes (Danish primary, English complete; tone gentle and spooky-sweet, never red or grim): `DUNGEON_LEAVE` "Forlad Mørkeskoven" / "Leave the Dark Wood", `DUNGEON_LEAVE_CONFIRM` "Vil du gå tilbage til Skovkanten? Alt, du har fundet, beholder du." / "Go back to the forest edge? You keep everything you found.", `DUNGEON_RUN_RESET` "Skoven har ændret sig. De gamle spor er væk, men runerne husker dig." / "The wood has changed. The old tracks are gone, but the runes remember you.", `RUNE_ACTIVATED` "Runen vågner. Dit fremskridt er gemt." / "The rune wakes. Your progress is saved.", `RUNE_REST` "Runen hviler dig.", `HULEN_ROOTS_PART` "Rødderne giver slip. Hulen er åben." / "The roots let go. The cave is open.", `DUNGEON_FLOOR_FMT` "Etage %d", `DEXP_DEFEAT_TITLE` "Besvimet i mørket", `DEXP_DEFEAT_TEXT_FMT` "Ugleøjnene bar dig hjem. Du mistede %d guldagern, men beholdt alt andet.", `DEXP_DEFEAT_TEXT_FREE` "Ugleøjnene bar dig hjem. Du beholdt alt.", `DEXP_SUMMARY_TITLE` "Tilbage fra skoven", `DEXP_SKOVHJERTE` "Skovens hjerte vokser: +1 hjerte.", `DEXP_LAST_SPARK` "Lygten flammer op!", `DEXP_WEAPON_RANGE_FMT` "God til etage %d-%d", `DPICK_RISK_FMT` "Besvimer du, mister du %d %% af dine guldagern (ca. %d).", `DEXP_SURPRISE_FIREFLIES` "En sværm ildfluer lyser op i kisten! Lygten fyldes.", `DEXP_SURPRISE_PURSE_FMT` "En lille agernpung med %d guldagern.", `DEXP_SURPRISE_COCOA` "En termokande med varm kakao. Så godt!", `DEXP_SURPRISE_NOTE_FMT` "En seddel fra Pip: »%s«", `LOOT_RUNE_VAULT_NEEDS` "Hvælvingen mangler runeskår. Tre skal der til.", `LOOT_LAKE_LOCKED` "Låst. Måske kender Fru Ugle en nøgle?", the full texts of the other `DEXP_ DPICK_ ASSIST_ DTUT_ FUND_ WEAPON_FAMILY_` rows are `design_experience.md` 10.6 (verbatim, minus its QUEST_ / ITEM_ / SHOP_ / RECIPE_ rows which are DR7's), the 157 + 12 + 4 loot rows are `design2/loot/localization/*.csv` (with the corrections of DL2 / DL7 / F4: three shards, no LOOT_ rows in appraisal.csv). **Placeholders are printf style `%d` / `%s` (`%%` for a literal percent), the repo's `tr(KEY) % args` convention (PLAN 3.4); the `{n}` style of the generator and experience drafts is NOT used** (decision DX46, checked by P26's `loc_final.final_review_dungeon_keys`, section `loc_final` of P26's own file `tests/sections/loc_final.gd`). No dungeon key is voiced (R.17).

### 8.11 Asset and item ids

* **Props to bake (P22):** `crown_{s,m,l}_{a,b}`, `crown_{s,m}_{a,b}_solid`, `cave_ring`, `cave_ring_up`, `home_rope`, `cave_stone` x5, `runestone_dormant`, `runestone_active`, `rune_glow`, `bush_eyes_a`, `bush_eyes_b`, `eyes_glow`, `empty_bush`, `pond_lily` x3, `pond_ripple`, `pond_sheen`, seamless textures `path_tile_o` `pond_water_o` `floor_patch_{a,b,c}`, `mist_patch_{a,b}`, `firefly_dot`, `lantern_light`, `mailbox_red`, `chest_noegle` (the lake chest), experience decals `telegraph_ring_{s,m,l}` `telegraph_line` `boss_arena_ring`, boss layers `halo_amber` `halo_violet` `crown_spark`, fx `fx_hit_spark` `fx_heal_sparkle`, the `tornebaer` pickup sprite. Everything above the ambient ceiling (R > 77, G > 94, B > 133) is additive.
* **Icons (DL6, wave 6):** `assets/icons/items/<id>.webp` for the 51 new ids + 7 `<id>_night.webp` variants (`wpn_sword_moon wpn_club_trunk wpn_spear_root wpn_staff_star gem_star_tear gem_moon_heart gem_rune_heart`) - in `items/`, the FIRST directory of `ArtCatalog.ICON_DIRS` and `TTItemIcon.DIRS` (items, home, wardrobe; both pinned by built tests: `area.icon_lookup_order`, `ui_foundation`), because no package may edit those two files and a fourth directory would never be read (measured: a webp in `assets/icons/dungeon/` resolves to nothing, in `assets/icons/items/` to the file and its `_night` file); the file names are unique prefixes (`wpn_*` `rough_*` `dng_*` and the 14 new `gem_<name>` ids), carved out of P23's `assets/icons/**` (RD.13; `gem_bag` stays P23's); the five DR7 icons are P23's.
* **Cast art (V2):** `bear_brumme bat_natteblik hedgehog_pip owl_fru_ugle capybara_sofus fairy_birk_npc` + re-baked `fairy_shopkeeper cat_morfar_mis`; A2 bases `monkey_base hobbit_bodil_base fairy_birk_base`. **City art (V5):** 55 textures under `assets/iso_props/city/` + `assets/backdrops/treetop_*`.
* **Item ids:** weapons `wpn_{dagger,sword,club,spear,staff}_*` (22), `rough_skovkant rough_dybe_bregner rough_svampelunden rough_krystalgrotten`, 14 cut gems, 8 `dng_*` materials + `dng_rune_snurre dng_rune_gloed dng_rune_konge`, recipes `dng_forge_*` (13); `tornebaer lysdraabe svampe_eliksir etagekort ugle_noegle`.

### 8.12 Groups, layers, ids

Groups: `player npc enemy interactable resource_node pickup warp game_ui dialogue_ui` (built) + **`runestone`** (D2; property `lit`: bool) + **`boss`** (DR4; DR5's awe stun skips it). Physics layers 1-11 as built; the city uses 12-28 (V3 allocates from `FIRST_BIT = 12`, `project.godot` is not touched). Area ids and spawn names: section 2.3. World/zone ids: `farm home traetoppen hyggebyen moerkeskoven moerkeskoven_f1..f12`; zones `farm traetoppen city dark_forest mushroom_grove crystal_cave`.


## 9. Decision register DX1 - DX60 (binding; "owner" = package that implements it)

### A. World and zone graph

| # | decision | why / evidence | owner |
|---|---|---|---|
| DX1 | Areas: `farm`, `home`, `traetoppen` (levelled builder), `hyggebyen` (grid, zone id `city`), `moerkeskoven` (static hub), `moerkeskoven_f1..f12` (generated). One graph for all four tracks (2.2). | generator DG1 + v2 DV3/DV6; the hub is a plain registered area so `area.warp_roundtrips`, saves, quests and NPC anchors stay static | P11, V4, D2 |
| DX2 | **The Skovlift (the rope basket of the city sketch) is the ONLY way into and out of Mørkeskoven.** The hub has ONE gate (to `traetoppen:from_skovlift`); the farm's Skovport, Hyggebyen's west gate and the draft's three hub gates are removed. | v2 DV8 + the sketch; the user's two-places decision; the generator's hub draft carried gates to farm / Hyggebyen / city only because the city track did not exist | P11, V4 |
| DX3 | The hub `moerkeskoven` is hand-authored by P11 from the generator's draft; a generated id never exists at boot. | `world_2d.gd:199-209` static registry | P11 |
| DX4 | `leave()` and the pause row go to the hub (`from_floor`); defeat wakes at `farm:from_home`; the run keeps no `origin`. | the hub's gate is fixed, so "where did I come from" is not needed | D2, D0 |
| DX5 | Fru Ugle lives in the first owl hole of tree A (location-free service: appraisal, key quest); the hub has no npc slot; Natteblik stands beside the Hulen of floors 2 / 6 / 10 through the anchor marker `hulen_keeper`. | v2 DV20 / DV21 against the generator's hub slot | V1, V7, V8, D1 |
| DX6 | Zone ids stay; names come from the CSV (`ZONE_FARM` "Min Trækronsgård", `ZONE_TRAETOPPEN`, `ZONE_CITY` "Hyggebyen", race "Halvling"). | D11 (ids stable, names from CSV) | V1, P26 |
| DX7 | Register-ahead: floors N-1 and N+1 are registered while on N, N+1 generated on a worker thread; the section's `from_dict` registers the saved floor BEFORE the world exists. | `world_2d.gd:140-157, 269, 353`; probe in `generator/results/integration_probe.txt` | D2 |
| DX8 | No new autoload, input action, EventBus signal or save section except `dungeon` (order 45); the run node is a child of LootService, the weapon store a child of EconomyManager. | allow-lists of `check_project.gd`, `input_contract.gd`, the signal arity lint | D2, DL1, F4 |
| DX9 | Bosses on floors 4 / 8 / 12, runestones on 3 / 5 / 7 / 9 / 11: DATA in `dungeon.floors`. The four-boss table (3 / 6 / 9 / 12 + a stone on every floor) is verified data (480 floors, 0 violations), a second stone on boss floors is NOT adopted. | three tracks now agree; experience sim variant B gains 2.0 -> 0.6 % pass-outs, not decisive | D1 |

### B. Generator

| # | decision | why / evidence | owner |
|---|---|---|---|
| DX10 | World seed per save (decimal text), `seed_day` pinned while a run is active, `floor_seed = hash_key(world_seed_text, seed_day, floor)`, purpose seeds keyed by cell, keyed streams for appraisal and boss pools; consumed state = per-floor sorted cell lists in section `dungeon` v1 (no `origin`, no `run` key). | tech analyst's sfc32 + FNV-1a, measured identical on arm64 / x86_64; ONE seed in the whole game | D1, D2 |
| DX11 | The sketch's smooth path and pond are DECALS derived at run time from the ground grid (SoftGround, mask + threshold shader); the generator emits no `path_line` / `ground_decal` marker and its text and digests are untouched. | a marker would change the digests of every floor and need a new 10 008-floor verification; tile art stays the fallback | V8, P22 |
| DX12 | ForestDress is attached by D2 on `area_ready` of every generated floor (and by a `forest_dress` marker in the hub); D2's `atmosphere.gd` and the marker in generated text are dropped. | one owner for fireflies, mist, unshaded actors and the light budget | V8, D2 |
| DX13 | The Hulen and the up cave are built-in walk-in `warp` markers; the interactive `hulen` marker mode and the config key `hulen_marker` are dropped. | no consumer exists (the experience track dropped DX8's `hulen_2d.gd`); a switch without a handler is a half-wired promise | D1 |
| DX14 | `hulen_far_from_spawn` and the floor-1/2 tutorial ambush are HARD gates in every attempt, in the verifier's own formulas. | second 10 008-floor range found 3 violations (0.2 row 3); gates re-run: 0 violations | D1 |
| DX15 | The three extra enemy kinds `mosfroe` (band 2), `sporesvamp` (band 3), `krystalugle` (band 4) are ADOPTED in the band mixes. | variety with existing bakes (tints); sim maps them to the nearest class; digests re-pinned (3.6) | D1, DR3 |
| DX16 | Rim = void + crown props; **`rim.wall_depth` 0 from the start** (D1 ships it; the first draft planned 1 until the crowns exist, a flip no package owned); iso fallback `wall_depth_iso` 0. | measured -1.0 .. -2.1 ms; sketch has no wall tiles; 2 x 10 008 floors 0 violations at depth 0, digests re-pinned (arm64 = x86_64) | D1, P22 |
| DX17 | ONE floor table in `lua/config/dungeon.lua`: the informational `odds` are deleted (the ladder is DL5's), lake tier `noegle`, Natteblik anchors are `hulen_keeper`, the hub has `exit_area / exit_spawn`. | two ladders drift; loot validator DB4 would warn | D1 |
| DX18 | `DungeonFloors` = the run node (floors, seed pin, consumed cells, stones, registry); `DungeonRun` = static rules (curve, ladders, hearts, oil, assist, tutorial, picker lines), NO run state, config key `dungeon_run`. | a class name must be unique; the loot track's text read `DungeonRun.inst()` for the node | D2, DR1 |
| DX19 | `world_2d.gd` (gentle defeat) and `lua/quests/snurresvampen.lua` (`area_changed moerkeskoven_f4`) have ONE owner: D0. | experience version 1's DX2 / DX7 claims no longer exist | D0 |

### C. Experience and combat

| # | decision | why / evidence | owner |
|---|---|---|---|
| DX20 | ONE damage / HP model: `dungeon_run.expected_weapon` (5 .. 24) is the curve; enemy hp = round(hits x curve), bosses 80 / 176 / 288; damage = round(sword damage x family factor); `hp_pct_per_floor` is dropped. | the loot track's `ttk.txt` and the experience sim agree (about +15 % per floor) | DR1, DR3, DR4, DL2 |
| DX21 | Oil: refill to full on the FIRST arrival of each floor and at each stone (D2, `restore_oil()`); drain, bite, auto-refuel, assist, gem multipliers are DR1's pure functions applied by P06; the "+45 s per descent" of version 1 is gone. | generator DG8 + experience DE8 | D2, DR1, P06 |
| DX22 | Hearts: 10 + "Skovens hjerte" (+2 half hearts per boss, once, at most +6) + assist (0 / 2 / 4). | the only non-random defensive progression; `hearts_per_boss = 0` removes it | DR1 |
| DX23 | Assist "Hjælp i skoven": presets over eleven flags; never touches loot odds, luck, rarity or prices. | the novice wall of the sim (66 % / 92 % pass-outs at bosses 2 / 3) | DR1, P16, P06 |
| DX24 | Three bosses (recolours of one bake) with the kill flow: the boss emits `enemy_defeated` once; D2 sets the flag, calls `DungeonRun.boss_killed` and emits `dungeon_boss_defeated`; the sealed chest calls `LootService.on_boss_defeated`. | one caller per rule; first-kill hearts and loot are independent registers | D2, DR4, DR1 |
| DX25 | Fishing at the Moon pond is an honest whisper stub (`LOOK_MOONPOND_FISHING`, once per floor); no `fishing_spot` marker. | open question 5 | V8 |
| DX26 | Runestones join group `runestone` with property `lit`; awake enemies never enter 520 ground px around a lit stone. | experience DE5 | D2, DR3 |
| DX27 | The defeat toast is DR1's warm `DEXP_DEFEAT_*` through `DungeonRun.after_defeat`; `DUNGEON_DEFEAT_FMT` does not exist. | "says everything that was kept" | D0, DR1 |
| DX28 | Player2D API names: `heal_full`, `restore_oil` (not `refill_oil`), `add_oil`, `heal_half`, `restore_stamina`, `revive(pos)`, `restore_after_sleep`; EconomyManager already calls `heal_half / add_oil / restore_stamina`. | `economy_manager.gd:580-593` | P06 |
| DX29 | A weapon's rating is its sword-equivalent damage `damage x 0.40 / (swing + cooldown)` (`WeaponInfo.sword_equivalent`), used for "God til etage a-b", the picker line and `weapon_ratio`. | a dagger of 14 is as good as the rare sword of 22 (54 vs 55 damage per second) | DL3, DR1 |

### D. Loot

| # | decision | why / evidence | owner |
|---|---|---|---|
| DX30 | Crystal nodes: all 45 per full dive are loot kind `crystal` (art kinds are aliases), `chance_bp 3000` unknown stone else one glimmer dust, no `floor_loot`, no direct gem yields; `hard_nodes` stays a placement guarantee. | simulated (5.8): typical castle day 246 (-27 %) with the dust at its REAL price of 8 gold (5.6), full dive 2 409 / 2 205, supply earlier (56 / 59 days) | DL4, DL5 |
| DX31 | Chest sense is measured in CELLS (96 ground px each): `max(species px / 96, gem cells, weapon cells)`, never the sum, capped at 12; Kiki's 700 px = 7 cells; F4's hidden-chest reveal reads `DungeonRun.chest_sense_px()` (default 240 px). | v2 used px, loot used cells | DR1, F4, V1 |
| DX32 | Pickup orbs call `LootService.deliver(item, amount)` when LootService exists (duplicates policy, keepsake registry), else `EconomyManager.add_item`; nothing else toasts. | one place items enter | DR0, F4 |
| DX33 | Natteblik's npcs.lua row carries NO `shop_id`; DR7 (items, shop, quests) is wave 4 so the NPC rows, the dialogue and the quest ids exist at the same gate; real-event completion is P13's table-driven section and DQ. | `economy.gd:919` fails for a shop that is missing in an isolated build | DR7, V1, P13 |
| DX34 | Bands = the four loot zone ids; depth ladder `s = 1 + 0.10 (floor - 1)` on uncommon x s and rare x s^2; **legendary and unique NEVER from an ordinary chest**. | keeps R3 provable, the 367 sources valid | DL4, DL5 |
| DX35 | Weapons: 24 fixed ids, no affixes, new store `Arsenal`, equipped by hand, auto-equip only within a family by rating, no weapon art in the world (arc tinted by rarity). | 24 ids would fill the 24-slot backpack | DL1, DL2, DL3 |
| DX36 | Gems: 4 unknown stones + 14 cut gems; appraisal by Fru Ugle for 30 / 50 / 75 / 105 gold (pure function of seed, counter, band, luck); the lantern's `accessory` slot holds ONE gem; no sockets in weapons or clothing. | per-instance data would be needed; luck is near its cap | DL2, DL3, DL7 |
| DX37 | Rune chain: THREE unique shards (first kill of each boss) are consumed at the hidden spot `runehvaelvingen` (floor 11) into the legendary `gem_rune_heart`; no "Dybet". | the loot track's own conclusion after the boss roster fell to three | DL2, DL4 |
| DX38 | One randomness source (the generator's `rng_for` / `rng_keyed`), a permanent keepsake registry, a daily value cap of **3 200 on the rarity-restricted sources** (chest, dig, appraise), a 7-day cooldown on hunted uniques. | 1 distinct outcome in 1 000 reloads; the cap is reached before floor 10 on 5 % of the clear-all days (the old 1 400 on everything: 98 %), floors 10-12 keep 79 % of their rare items (old: 14 %), full dive 2 409 -> 2 205 capped (5.7) | DL5 |
| DX39 | Surprise toasts are DR1's `DEXP_SURPRISE_*`; the four `LOOT_` service messages are F4's `loot_dungeon.csv`; `appraisal.csv` keeps only `APPRAISE_`. | the literals live in wave-4 and wave-5 code; a key must exist in the wave of its first literal | DR1, F4, DL7 |

### E. v2 characters and environment

| # | decision | why / evidence | owner |
|---|---|---|---|
| DX40 | Six heroes (two per race), 22 NPCs, seven retired skins as data rows; perks through `SpeciesPerks`. | v2 DV9-DV15 | V1, V2, A2, P16 |
| DX41 | The city is a levelled builder area with ranked z, per-level collision bits and level = f(position); K = 3.0; no built framework file edited. | prototype 14 checks green | V3, V4 |
| DX42 | City HUD per the v2 mock (date block, gold + energy chip, zone banner) on the FARM HUD; the forest HUD stays the guide's section 10. | `design_v2.md` 7.1 | P17, DR5 |
| DX43 | Mørkeskoven look: actors unshaded in dark ortho areas (enemies too), lantern 0.10 / `ffe9a8`, <= 12 overlapping lights, 16 per canvas item. | measured | V8, P06 |
| DX44 | Art ownership: P22 forest + dungeon art ids (crowns, rings, runestone, textures, decals, fx, `mailbox_red`), V5 city, V2 cast, A2 hero bases, DL6 loot icons, V9 key art. | disjoint patterns | |
| DX45 | Shared-file protocol: ONE owner per file. `lua/config/marker_handlers.lua` F4, `lua/config/npcs.lua` / `race_perks.lua` / `tests/sections/data.gd` / `loc.gd` / `core.csv` V1, `tests/sections/economy.gd` + `economy_manager.gd` DL1, `lua/data/loot_tables.lua` + validator DL4, `world_2d.gd` D0, `tools/loc/key_owners.json` P03 (the lead merges `key_owners_additions.json`). Other packages hand their lines to the owner or keep checks in their own sections. | the seven shared names of `design_v2.md` 9 + the experience / generator / loot overlaps | all |

### F. Process

| # | decision | why | owner |
|---|---|---|---|
| DX46 | printf placeholders `%d` / `%s` (`%%`) in every FMT key, never `{n}`. | PLAN 3.4 convention | all CSV owners |
| DX47 | Package ids: DX* -> DR*, DX6 merged into DR5, DL8 + DX9 merged into DQ, DR7 to wave 4, DL3 to wave 5, D1 owns `dungeon.csv`, V3 owns `levels.csv`, F4 owns `loot_dungeon.csv`. | 3 of the 4 tracks' ids collided with the register; keys must exist in the wave of their first literal | the editor |
| DX48 | `key_owners_additions.json` (merged) replaces the four tracks' files; the lead merges its entries at the start of each wave. | one file, four tracks | P03 |
| DX49 | A package may only name a localization key of a CSV owned by a package of the same or an EARLIER wave (same wave = coupling resolved at the gate and listed in 12.4). | `loc_check` strong references | check F |
| DX50 | QA is split by what it needs: D3 (5b) the technical world, DQ (7) the acceptance rows and the loot dive, V10 (7) the sketch coverage, P27 / F10 link to them. | each needs the packages before it | D3, DQ, V10 |
| DX51 | Same-wave coupling is allowed only for DATA that two packages must agree on at the wave gate (V1 + V2 art roster, V1 + DR7 + V7 + P13 quests / shop, P11 + V1 zone labels, P16 / P18 / D0 / DR0 keys of D1 / DR1 / DL2); every other dependency is strictly earlier. | 12.4 | the lead |
| DX52 | Every number in this addendum is read from a file or measured by a saved script; ASSUMED parts (player archetypes, appraisal behaviour, the 8-minute run, real-art costs) are marked. | the brief | the editor |

### G. The editor's final pass (review findings, section 0.4)

| # | decision | why / evidence | owner |
|---|---|---|---|
| DX53 | **Two-phase delivery**: plan (pure, on a copy of the state), fit (all backpack-bound rolls together), deliver, commit; a plan that does not fit answers `{ok: false, reason: &"full", results: []}` and changes NOTHING (no delivery, pity, wanderer miss, daily value, surprise, `last_uid`, `first_done`, done mark). | review 1: 12-31 % of multi-roll chests were retry faucets, a full pack at the first boss kill burned the rune shard; measured 0 items after 1 000 retries, 0 lost keepsakes in 3 000 fuzz runs | DL5, F4, D2 |
| DX54 | **Appraisal**: one counter per band, `rng_keyed("appraise:" + band, n_band)`; the stone, the fee and the counter are committed in one step and `SaveManager.autosave()` runs before the result is shown. | review 1: one shared stream let a reloading player pick the stone for a peeked draw (+45 / +75 gold per appraisal against +15 / +48) | DL5, DL7 |
| DX55 | **The 51 + 7 dungeon icons install into `assets/icons/items/`** (file-name prefixes `wpn_ rough_ dng_` and the 14 new `gem_` ids, carved out of P23's `assets/icons/**`); no package edits `ArtCatalog.ICON_DIRS` or `TTItemIcon.DIRS`. | the built lookups search items, home, wardrobe only and two built tests pin the lists; a webp in `assets/icons/dungeon/` resolved to nothing (probe) | DL6, P23 |
| DX56 | **The generator's safety net is a PINNED, VERIFIED fallback seed per floor** (`dungeon.seed.fallback`), not a hand-built template; `build_text` returns it when all 8 attempts fail. | a template that passes 46 invariants is a second generator; the pinned seeds are measured: 12 of 12 specs, 797 checks, 0 violations, and the one exhausted floor of 20 016 | D1 |
| DX57 | **LootService hosts the appraisal screen** (listens to `open_appraisal`, adds DL7's scene to the `game_ui` layer); `GameUI.SCREEN_ORDER` is not edited. | the list is pinned by built tests; nothing else instantiated the screen | F4, DL7 |
| DX58 | **V3 (wave 4) owns `data/traetoppen/traetoppen.json` and `lua/config/traetoppen.lua`**; V4 (5b) reads them. | V5 and V6 (wave 5) and P13 (wave 4) read them at their own gates | V3, V4 |
| DX59 | Marker handlers of a generated floor expose `static create_marker(params, pos, cell, area)` (enemy, node, whisper); the legacy `create(params)` is not used there. | `IsoArea._handler_api` picks the arity-4 entry first; only it receives the cell and the area that done-cell skipping and the keyed streams need | DR3, P19, F4 |
| DX60 | **Leaving is always preceded by `GameManager.pop_all_modals()`** (pause row and `DungeonFloors.leave()`), and the lantern has NO ordering mechanism: the light budget is the rule. | measured: travel under the pause modal stalls; the 16-light cap drops lights by allocation details, not by tree order or child index (thresholds differed between two runs of the same probe) | P16, D2, P06, V8 |



## 10. Conflict log: where the tracks disagreed and what this addendum decided (and which sentences of the track documents it overrules)

| # | conflict | tracks | decision (register) | reason / evidence | cost of the other choice |
|---|---|---|---|---|---|
| CR1 | Boss floors 3 / 6 / 9 / 12 (four bosses) vs 4 / 8 / 12 (three) | exp v1, loot v1 vs generator | 4 / 8 / 12, three recolours (DX9) | all three tracks converged in their final texts; alt table verified as data | four bosses: 3 new bakes, 4 rows, a fourth rune shard |
| CR2 | Stone placement and a second stone on boss floors | generator vs experience R-G7 | arrival clearing of 3 / 5 / 7 / 9 / 11 only (DX9) | variant B gain is real but not decisive; digests would move | `stone = true` on 4 / 8 / 12 + re-pin |
| CR3 | Hulen as walk-in `warp` vs interactive `hulen` marker | generator switch vs experience v1 | walk-in only (DX13) | no handler exists any more | a new handler package |
| CR4 | Entrances: hub with gates to farm / Hyggebyen / city (generator), lift picker (experience v1), Skovlift only (v2) | all | Skovlift only, ONE hub gate (DX2) | the sketch has a rope basket; v2 removed the other gates; a hub keeps generated ids out of every other map | gates back: P11 / V4 tasks and `from_farm` / `from_hyggebyen` spawns |
| CR5 | Fru Ugle: hub slot / floor 1 / owl hole | generator / experience / v2 | city owl hole, location-free service (DX5) | v2 DV20; the appraisal needs only the dialogue event | none |
| CR6 | Natteblik: `npc` anchor vs V8's `hulen_keeper` | generator vs v2 | `hulen_keeper` anchor (data) (DX5, DX17) | measured: stress 1 200 floors 0 violations, `hulen_keeper` added to `SOLID_MARKERS` | `npc ... when=night` only: no sleeping-bat day variant |
| CR7 | Who patches `world_2d.gd` | generator D0 vs experience DX2 | D0 only (DX19) | DX2 no longer exists | - |
| CR8 | Who re-keys `snurresvampen.lua` | D0 vs DX7 | D0 only (DX19) | one owner per file | - |
| CR9 | Oil rule: refill per floor and stone vs +45 s per descent | generator vs experience v1 | refill (D2) + DR1's rules (DX21) | experience v2 adopted the generator's refill | - |
| CR10 | Defeat toast copy | `DUNGEON_DEFEAT_FMT` vs `DEXP_DEFEAT_*` | the warm one through `DungeonRun.after_defeat` (DX27) | it says what was kept | a bare loss line |
| CR11 | Names `DungeonRun` for node vs rules | loot text vs generator rename | node `DungeonFloors`, rules `DungeonRun` (DX18) | class names are unique | - |
| CR12 | Enemy hp: `hp_pct_per_floor` +20 % vs hits x curve | generator P19 task vs experience | hits x curve (DX20) | loot `ttk.txt` agrees | two ladders |
| CR13 | `refill_oil` vs `restore_oil`, `heal_full`, `add_oil` | generator vs experience / economy | one API (DX28) | EconomyManager already calls `add_oil` | - |
| CR14 | Who calls `boss_killed` | DR4 vs D2 | D2 (DX24) | the event payload needs `first_kill` | - |
| CR15 | Pickup orb: `add_item` vs `LootService.deliver` | experience vs loot | `deliver` when present (DX32) | duplicates policy, registry | a faucet hole |
| CR16 | Chest-sense unit px vs cells | v2 vs loot | cells, 96 px each (DX31) | MAX of sources needs one unit | - |
| CR17 | **Crystal nodes** (45 per dive, hard moonstone) vs the loot budget | generator vs loot C7 | alias to `crystal`, 30 % stone else dust (DX30) | SIMULATED, section 5.8 | direct yields collapse the home ladder; "decoration" nodes feel bad |
| CR18 | Orphan node rows (`steel_vein` ...) in `dungeon_loot` and the materials' sources | loot | deleted (5.6) | the generator places none; rule DB5 / M1 | unplaced content |
| CR19 | Surprise toasts and `LOOT_` keys in `appraisal.csv` (wave 5b) used by wave-4 / 5 code | loot vs experience | `DEXP_SURPRISE_*` in DR1, `LOOT_*` in F4's `loot_dungeon.csv` (DX39) | check F | `loc_check` MISS at the gate |
| CR20 | Natteblik `shop_id` and Fru Ugle `quests_offered` in rows of wave 4 vs DR7 in wave 5 | experience vs v2 | DR7 to wave 4; no `shop_id` (DX33) | `economy.gd:919` | a failing isolated build |
| CR21 | Smooth path and pond: markers `path_line` / `ground_decal` (v2) vs tiles (generator) | v2 vs generator | SoftGround from the ground grid (DX11) | no digest change, no re-verification | markers change every floor's digest |
| CR22 | Atmosphere: D2 `atmosphere.gd` vs V8 ForestDress | generator vs v2 | V8 owns it, D2 attaches (DX12) | one owner | - |
| CR23 | `fishing_spot` marker (v2) vs decor (generator) | | whisper stub on every pond (DX25) | sketch caption honoured, no feature | a fishing feature |
| CR24 | Hub strings (`DUNGEON_SIGN_HUB`) in D2's CSV (wave 5) named by P11's hub (wave 4) | generator | `SIGN_MOERKESKOVEN_*` in `areas.csv` | check F | - |
| CR25 | `dungeon.csv` owner D2 (wave 5) vs D1's Lua literals and P16's button (wave 4) | generator | D1 owns it | check F | - |
| CR26 | Three extra enemy kinds (R-G6) optional vs adopted | experience vs generator | adopted (DX15) | measured 1 200 floors | 3 data rows + 3 scripts less |
| CR27 | Informational `odds` in the floor table | generator vs loot DB4 | deleted (DX17) | one ladder | drift |
| CR28 | `origin` and nested `run` in the section | generator | dropped (DX10) | no run state in `DungeonRun`; the hub gate is fixed | - |
| CR29 | V3's prompts named `TRAE_PROMPT_*` (V4's CSV, 5b) | v2 | `LEVEL_PROMPT_*` in V3's `levels.csv` | check F | - |
| CR30 | Screenshot drivers: `tests/shot_world.tscn --part=dungeon_exp` (P04's `tests/shot_*`) vs D3's `tests/dungeon_shots.*` | experience / generator | two drivers: D3 `tests/dungeon_shots.*`, DQ `tests/dungeon_exp_shots.*` | one file, one owner | a hidden cross-edit |
| CR31 | Rune shards: four (loot v1 text, `LOOT_RUNE_VAULT_NEEDS`, `dungeon_materials.lua` comment) vs three | loot | three (DX37) | boss roster of three | - |
| CR32 | Moon pond decal `moon_pond` 900 x 540 (v2) vs variable ponds (generator) | v2 | seamless `pond_water_o` + SoftGround mask (P22) | ponds are ellipses of several sizes | scaled decals |
| CR33 | P22 `addDependsOn D1` (same wave) | generator | removed | it only emits ids | a same-wave dependency |
| CR34 | `data/icons.json` path in DL6's task named no owner | loot | lift path `design2/loot/data/icons.json` | check E | - |
| CR35 | Third generator defect class: 3 verifier violations in the second seed range | (found by the editor) | two HARD gates (DX14) | 0.2 row 3 | 0.03 % of floors broken |
| CR36 | The generator's safety net: a scripted fallback TEMPLATE (generator doc) vs what the verifier demands | generator vs technical review | pinned, verified fallback SEEDS (DX56) | the template could not pass 46 invariants (nooks); the seeds are measured: 12 of 12 specs, 797 checks, the one exhausted floor of 20 016 | a second generator |
| CR37 | Who flips `rim.wall_depth` from 1 to 0 | generator vs P22 | D1 ships 0 (DX16) | a flip nobody owned would re-pin digests and `spec_hash` later; measured at 0: 2 x 10 008 floors 0 violations | an orphan task |
| CR38 | Daily cap: 1 400 on every source (loot) vs 'deeper floors drop better rarities' (the user) | loot vs the user's decision U2 | 3 200 on chest / dig / appraise (5.7) | 98 % of the clear-all days reached the old cap before floor 10 | the depth ladder switched off |
| CR39 | Dungeon icons in `assets/icons/dungeon/` (loot) vs the built icon lookups | loot vs built code | `assets/icons/items/` (DX55) | two built tests pin the three directories; the probe resolved nothing from `dungeon/` | placeholder badges everywhere |
| CR40 | Who instantiates the appraisal screen: nobody (loot DL7) | loot vs the plan's `GameUI.SCREEN_ORDER` | F4's LootService (DX57) | the list is pinned; Fru Ugle's choice would emit an event nobody hears | a dead dialogue choice |
| CR41 | V4 (5b) created the city JSON and config that V5, V6 (wave 5) and P13 (wave 4) read | v2 vs the wave plan | V3 (wave 4) owns both (DX58) | strictly earlier waves | checks that cannot go green at their own gates |

Statements of the track documents that are OVERRULED (everything else in them stands as rationale):

* **generator** 3.5 / DG13 / 5.x (the 'deterministic fallback template' and its claim 'passes the verifier by construction': replaced by pinned, measured seeds, 3.5), the plan to flip `rim.wall_depth` to 0 'when the crowns are baked' (DX16), 2.2 (three hub gates; spawns `from_farm` / `from_hyggebyen`), 2.5 (the notification `DUNGEON_DEFEAT_FMT`), 2.6 (Fru Ugle's hub slot; Natteblik as a plain `npc` anchor), 5.4 (the interactive `hulen` marker, `dungeon.hulen_marker`, `odds` in the table), 5.6 row "mist, fireflies = D2 atmosphere.gd", 7.2 (section keys `origin`, nested `run`), 7.8 (`atmosphere.gd`), 9.1 (`gen.never_over_6_attempts`, `export.hub_draft_parses_and_connects`), 10 (D2 owns `dungeon.csv`; "D0 or DX2"), 12.11, 15.1 (every row, decided above), 15.3 (the city's gate flag).
* **experience** 1.3 C1-C11 (all closed above), 3.1 (the hub "with three gates"), 3.6 (Fru Ugle's place), 4.4 R-G6 "optional", 4.5 (DR4 calls `boss_killed`), 10.2 (`chest_sense()` in px-less form), 10.6 (QUEST_ / ITEM_ / SHOP_ / RECIPE_ rows in `dungeon_run.csv`, `{n}` placeholders), 11 (packages DX6 / DX7 / DX9 as written; DX7 in wave 5).
* **loot** 2.2 C1-C14 (closed), 7.2 step 6 and section 10 row 'Backpack tricks' ('a full pack leaves the chest closed and not done' with a partial delivery: replaced by the two-phase rule of 5.7), 5.2 / 7.9 (`rng_keyed("appraise", n)`, one shared counter), 5.2 (the luck-0.2 appraisal gains +37 / +55 / +66 / +81: corrected in 5.5), 7.1 ('counted when the roll is made' and every source burning the cap), LD2 / LD13 and the DL5 task text (boss pool 8 % with pity 10 for all three bosses: bosses 1-2 are 16 % / 6), `dungeon_materials.lua` sell prices (5.6), 4.1 / `dungeon_materials.lua` comments naming four rune shards, 5.5 ("the experience track's shop `fru_ugle_vurdering`": that shop does not exist), 6.1 (node rows `steel_vein` ...), 7.10 / 8.3 (`floor_loot`), 8.6 (`LOOT_` rows in `appraisal.csv`), 9 (the pacing numbers for the crystal rule: the simulated variant of 5.8 replaces them), DL3 in wave 4, DL8 as a separate package.
* **v2** 6.4 and 8 (markers `path_line`, `ground_decal`, `fishing_spot`, `forest_dress` "ONE per floor, emitted by the generator"), 2.2 / 2.5 (the forest exit "returns to `traetoppen:from_skovlift` from every floor": it returns to the hub, whose gate does), `v2_packages.json` V3 (the `TRAE_PROMPT_*` keys named by V3's code), 10 wave notes (V3 and V7 may move to 5: they stay in 4; DR7 joins wave 4).


## 11. Amendments to existing packages (R-style: what was checked, what was found, the rule that replaces the old text; binding like PLAN section R)

The machine-readable form is `packages.json` -> `amendments` (27 entries, section 11.2). Eight are carve-outs of BUILT packages (waves 1-3: the files move to a new package, the lead executes the listed patches at the wave boundary); nineteen amend packages that are not built yet.

### RD.1 What was checked
Every `owns` pattern of the 38 packages of `impl/owners.json` (with the feature addendum's amendments) and the 28 new packages (66 in all), by language intersection (not only by the files that exist), plus the repo's 3 509 tracked files (`ff802c7`); every task's named paths; every localization key literal against the wave of its CSV; every dependency against the wave table (`check_ownership.py`, 12.5). The raw union of the four track files was clean on pattern overlap but left the semantic conflicts of section 10 and two mechanical defects (P22 depended on D1 in the same wave 4; `data/icons.json` named in a task but owned by nobody).

### RD.2 Carve-outs of BUILT packages (files that change owner; the built tests must stay green)
| built package | files that move | to | built tests that pin them |
|---|---|---|---|
| P03 (wave 2) | `localization/core.csv`, `tests/sections/loc.gd` | V1 | `loc`, `core`; V1 edits the ZONE_FARM pin |
| P04 (wave 3) | `scripts/world2d/world_2d.gd` | D0 | `area.faint_returns_to_the_farm` (asserts only "area == farm and WHISPER_FAINT seen": stays true) |
| P05 (wave 2) | `lua/config/characters.lua`, `tests/sections/characters.gd`, `scripts/isometric/character_catalog.gd` | V1 | `characters` |
| P10 (wave 2) | `lua/config/npcs.lua`, `lua/config/race_perks.lua`, `tests/sections/data.gd`, `scripts/data/species_perks.gd` (new file) | V1 | `data` |
| P10 (wave 2) | `scripts/data/item_kinds.gd`, `scripts/data/rarity.gd`, `lua/config/rarity.lua`, `tests/sections/rarity.gd` | DL1 | `data`, `rarity` |
| P12 (wave 3) | `lua/shops/timber_yard.lua` (new file) | V1 | `economy` |
| P12 (wave 3) | `scripts/economy/arsenal.gd` (new), `scripts/autoload/economy_manager.gd`, `lua/items/tools.lua`, `tests/sections/economy.gd` | DL1 | `economy` |
| P12 (wave 3) | `lua/recipes/dungeon.lua` (new), `lua/shops/smithy.lua`, `lua/shops/magic_store.lua` | DL2 | `economy` |
| P21 (wave 3) | `assets/isometric_characters/fairy_shopkeeper/**`, `.../cat_morfar_mis/**`, `manifest_traetoppen.json`, `tests/sections/art_characters.gd` | V2 | `art_characters` (ROSTER-DRIVEN over `npcs.lua`: V1 and V2 must land in the same wave) |
| F1 (wave 3) | `lua/quests/snurresvampen.lua` | D0 | `quests`, `content_features.quest_references_valid` (the first draft named `content_features.quest_files_load`, which does not exist) |
| F1 (wave 3) | `lua/data/loot_tables.lua`, `data/features/map_markers.json` (TRIMMED to the two static areas `farm` and `hyggebyen`, never deleted: P11's wave-4 check `maps_iso.feature_markers_match_json` reads them), `localization/finds.csv`, the validator, its mutation test and self-test, `tools/features/sim/**`, `tests/lib/features/content_validator.gd`, `tests/sections/content_features.gd`, `docs/features/SCHEMA.md` | DL4 | `content_features` (its pinned `loc_keys_da_en` row count 906 becomes 914, its pinned area count of the markers file 6 becomes 2) |
| P01 / P03 patches by the lead | `.gitignore` entries; the docs copy; the `tools/loc/key_owners.json` merge | the lead | `project`, `loc.ownership_lint` |

### RD.3 P19 forest-combat is RE-SCOPED (L -> M)
Found: P19 owned Enemy2D, the forest HUD, the minimap, LootDrop2D, `enemies.lua`, `forest.csv` AND four hand-authored forest maps, two of which (enemies and resource nodes) are both wave 5 and may not depend on each other. Rule: `enemy_2d.gd`, `enemies.lua`, `forest.csv` -> **DR3**; `loot_drop_2d.gd` -> **DR0** (wave 4); `minimap_2d.gd`, `forest_hud.*` -> **DR5**; the four maps are NOT written (generated floors); P19 keeps `resource_node_2d.gd`, `whisper_zone.gd`, `resource_nodes.lua`, the legacy 3D deletions, `scenes/forest/**` and `tests/sections/forest.gd`, and gains: done-cell skipping, `LootService.node_loot`, forage by `E`, the two kitchen-garden node kinds.

### RD.4 P06 player-farm-core gains ONE merged list
Four tracks listed overlapping edits (API, lantern budget instead of the 'first light' trick, weapon hooks, feel, assist, oil, faint, species perks). Rule: seven tasks (11.2) with unified names (DX28); every dungeon read is late-bound with the built numbers as fallback (P06 is wave 4 and must not depend on DR1 / DL3); the real wiring is proven by DL3 (wave 5) `weapons.player_uses_weapon_info_and_lantern_gem`.

### RD.5 F4 loot-shops stays L but carries the seams
Found: F4 (wave 4) was asked by three tracks for hosting, marker rows, chest / dig / spot params, the API with `ctx`, the delegation seam, the save sub-dict. Rule: six tasks, defaults reproduce the plan's behaviour so F4 is buildable alone; the dungeon algorithm is DL5's (wave 5) behind the late-bound seam with a FAKE delegate in F4's tests; F4 also hosts the appraisal screen (listener of `open_appraisal`, no `GameUI.SCREEN_ORDER` edit) and runs every mutating call two-phase (5.7); F4 also owns `lua/config/marker_handlers.lua` for everybody (rows listed in 8.9) and `localization/loot_dungeon.csv`.

### RD.6 Localization: a key must exist in the wave of its first literal (DX49)
Found by check F: the hub sign (wave 4) named a key of D2's wave-5 CSV; `LOOT_*` and `LOOT_SURPRISE_*` (wave 4-5 code) lived in the wave-5b appraisal CSV; V3 (wave 4) named V4's wave-5b prompts. Rule: strings move to the CSV of the earliest consumer (`areas.csv`, `loot_dungeon.csv`, `dungeon_run.csv`, `levels.csv`, `dungeon.csv` owned by D1); `check_ownership.py` check F fails the build otherwise; 19 same-wave couplings are listed in 12.4.

### RD.7 P11 maps
`farm.map`, `hyggebyen.map` per v2 (no forest gate, one bridge each to the city), NEW `moerkeskoven.map` from the generator's draft with ONE gate; `maps_iso` accepts `traetoppen` as a PENDING area until V4 (5b) and exempts `moerkeskoven_f*` targets; the hub's strings are P11's `areas.csv` rows; `maps_iso.feature_markers_match_json` reads ONLY the areas `farm` and `hyggebyen` of `data/features/map_markers.json` (DL4 trims the file to those two in wave 5).

### RD.8 P22 art list is the UNION of the generator's, the experience layer's and v2's
Crowns (+ solid variants), cave rings, `home_rope`, runestone, bush eyes + empty bush, pond water and lily, seamless path / pond / patch textures for SoftGround (there is no fixed-size `moon_pond`), mist, fireflies, `lantern_light`, `mailbox_red`, `chest_noegle` (the lake chest, sketch landmark 6), telegraph decals, boss layers, fx sprites, the `tornebaer` pickup, plus the `props_extra.lua` entries; the city art (`assets/iso_props/city/**`, `assets/backdrops/treetop_*`, `tools/art/environment/city/**`) moves to V5.

### RD.9 P13 / P14 vocabulary
No new quest vocabulary: `on = "game_event"` + `event` + P13's planned generic `min_level`, `area_changed`, `zone_entered`, `item_gained have`, `manual`; P13 gains `offerable / offerable_for`, the rebinding of `intro_lottery`, and ONE table-driven completability section over every quest file (the five carved-out ones included, fed with the real payloads of 8.4); P14 gains `emit_event`, five context keys, `reach=`, `when=night`, the 22-NPC walk, Mis' two states and Oak's two quest branches.

### RD.10 UI packages
P16: hero chips, "Halvling", the assist group, the pause row "Forlad Mørkeskoven" (confirm -> `GameManager.pop_all_modals()` -> `leave()`, measured: under the pause modal the travel does not happen). P17: the city HUD mock, the zone banner, a toast queue that keeps four summary toasts in order. P18: the `Våben` tab, weapon and gem cards, the range line, the compare arrow.

### RD.11 Audio, docs, copy
P24: 16 placeholder SFX (13 dungeon + 3 loot cues) synthesised by `tools/voice/sfx_synth.py`, city event cues, voices of the seven new NPCs. P25: nine howtos + `lua_api` keys + the PNG references of the v2 sheets are owned. P26: the copy pass over every new CSV and the glossary overrides.

### RD.12 Acceptance
P27: row 11 and the v2 rows delegate to D1 / D2 / D3, DQ and V10; F10: rows 17 / 18 and the real-play segment 6 point at the dungeon.

### RD.13 The dungeon icons: carve-out of the UNBUILT P23 (wave 4) in favour of DL6 (wave 6)
P23 owns `assets/icons/**`; the 51 + 7 icons of the new item ids install into `assets/icons/items/` (the first directory of the built lookups `ArtCatalog.ICON_DIRS` and `TTItemIcon.DIRS`, pinned by `area.icon_lookup_order` and `ui_foundation`), so `ownsRemove` of P23 and `owns` of DL6 are the file-name patterns `assets/icons/items/{wpn_,rough_,dng_}*` and `assets/icons/items/gem_{rock_crystal,smoky_quartz,moss_agate,forest_jade,mushroom_opal,thornberry_stone,fairy_tear,night_sapphire,dewdrop,owl_eye,sunset_stone,moon_heart,star_tear,rune_heart}*` (`.import` and `_night` files follow their file). `gem_bag` (an existing item, P23's icon) is not matched. Until DL6 lands, P23's `tools/art/icons/missing_icons.py` lists the three new item files as PENDING (information, exit 0) and turns strict when `tools/art/features/dungeon/manifest.json` exists: wave 4, 5 and 5b gates would otherwise be red with 51 + 7 missing files (12.4).

### 11.2 The 27 amendments (generated from `packages.json`)

| package | wave | built | ownsRemove | ownsAdd | addDependsOn | tasks |
|---|---|---|---|---|---|---|
| `P01-project-config` | 1 | yes (patch by the lead) | - | - | - | 2 |
| `P03-loc-core` | 2 | yes (patch by the lead) | `localization/core.csv`, `tests/sections/loc.gd` | - | - | 1 |
| `P04-area-framework` | 3 | yes (patch by the lead) | `scripts/world2d/world_2d.gd` | - | - | 0 |
| `P05-characters-pack` | 2 | yes (patch by the lead) | `lua/config/characters.lua`, `tests/sections/characters.gd`, `scripts/isometric/character_catalog.gd` | - | - | 0 |
| `P10-data-contracts` | 2 | yes (patch by the lead) | `lua/config/npcs.lua`, `lua/config/race_perks.lua`, `tests/sections/data.gd` + 5 more | - | - | 0 |
| `P12-economy-shop-crafting` | 3 | yes (patch by the lead) | `lua/shops/timber_yard.lua`, `scripts/economy/arsenal.gd`, `scripts/autoload/economy_manager.gd` + 5 more | - | - | 0 |
| `P21-art-characters` | 3 | yes (patch by the lead) | `assets/isometric_characters/fairy_shopkeeper/**`, `assets/isometric_characters/cat_morfar_mis/**`, `assets/isometric_characters/manifest_traetoppen.json` + 1 more | - | - | 0 |
| `F1-feature-data` | 3 | yes (patch by the lead) | `lua/quests/snurresvampen.lua`, `lua/data/loot_tables.lua`, `data/features/map_markers.json` + 10 more | - | - | 0 |
| `P06-player-farm-core` | 4 | no | - | - | - | 7 |
| `P11-maps-iso` | 4 | no | - | `data/maps/moerkeskoven.map` | - | 4 |
| `P13-quests-lua-runtime` | 4 | no | `lua/quests/pips_runde.lua`, `lua/quests/skovlift_intro.lua`, `lua/quests/rune_vandring.lua` + 2 more | - | - | 4 |
| `P16-ui-menus` | 4 | no | - | - | - | 3 |
| `P18-ui-shop-inventory` | 4 | no | - | - | - | 1 |
| `P22-art-environment` | 4 | no | `assets/iso_props/city/**`, `assets/backdrops/treetop_*`, `tools/art/environment/city/**` | - | - | 5 |
| `P23-art-icons-keyart` | 4 | no | `assets/icons/items/wpn_*`, `assets/icons/items/rough_*`, `assets/icons/items/dng_*` + 2 more | - | - | 2 |
| `A2-art-wardrobe` | 4 | no | `assets/isometric_characters/rabbit_base/**`, `assets/isometric_characters/hedgehog_base/**`, `assets/isometric_characters/squirrel_base/**` + 4 more | `assets/isometric_characters/monkey_base/**`, `assets/isometric_characters/hobbit_bodil_base/**`, `assets/isometric_characters/fairy_birk_base/**` | - | 5 |
| `F4-loot-shops` | 4 | no | - | `localization/loot_dungeon.csv`, `localization/loot_dungeon.csv.import` | - | 7 |
| `P14-npc-dialogue` | 5 | no | `lua/dialogue/gardener_hoppe.lua`, `lua/dialogue/carpenter_brumme.lua`, `lua/dialogue/postman_pip.lua` + 4 more | - | - | 4 |
| `P17-ui-hud` | 5 | no | - | `tests/checkpoints/guide_ref_v2/**` | - | 4 |
| `P19-forest-combat` | 5 | no | `scripts/world2d/enemy_2d.gd`, `lua/config/enemies.lua`, `localization/forest.csv` + 8 more | - | `DR0`, `D1` | 5 |
| `F5-wardrobe-core` | 5 | no | - | - | - | 1 |
| `F8-wardrobe-ui` | 5b | no | - | - | - | 1 |
| `P24-audio-voice` | 6 | no | - | - | - | 2 |
| `P25-docs-refresh` | 6 | no | - | `docs/Trætoppen Style Guide Review/refs/*.png`, `docs/Trætoppen Style Guide Review/uploads/*.png` | `DR1`, `DR3`, `DR4`, `D3`, `DL4` | 2 |
| `P26-loc-final` | 6 | no | - | `tests/sections/loc_final.gd` | `D1`, `DR1`, `DR7`, `DL2`, `DL7` | 2 |
| `P27-qa-acceptance` | 7 | no | `docs/qa/dungeon/**`, `docs/qa/loot/**`, `docs/qa/v2/**` | - | - | 2 |
| `F10-features-qa` | 7 | no | - | - | - | 1 |


## 12. Packages and waves

### 12.1 The 28 new packages (generated from `packages.json`; sizes S / M / L / XL as in the feature addendum; the first line of each `owns` list is the headline)

| id | wave | size | depends on | owns (patterns) | tasks |
|---|---|---|---|---|---|
| `D1-dungeon-gen` | 4 | L | `P03`, `P04`, `P09`, `P10` | `scripts/dungeon/gen/**`, `lua/config/dungeon.lua`, `localization/dungeon.csv` + 3 more | 9 |
| `D0-dungeon-world-hooks` | 4 | S | `P04`, `P12`, `F1` | `scripts/world2d/world_2d.gd`, `lua/quests/snurresvampen.lua`, `tests/sections/dungeon_defeat.gd` | 3 |
| `DR0-pickups-fx` | 4 | S | `P04`, `P12`, `P09` | `scripts/world2d/loot_drop_2d.gd`, `scripts/dungeon_run/fx/**`, `tests/sections/dungeon_pickups.gd` | 4 |
| `DR1-rules` | 4 | M | `P02`, `P03`, `P10`, `P12`, `P09` | `scripts/dungeon_run/dungeon_run.gd`, `scripts/dungeon_run/combat_rules.gd`, `scripts/dungeon_run/oil_rules.gd` + 9 more | 12 |
| `DR7-dungeon-services` | 4 | S | `P03`, `P10`, `P12` | `lua/items/dungeon_supplies.lua`, `lua/dungeon_run/recipes.lua`, `lua/dungeon_run/shops.lua` + 7 more | 5 |
| `DL1-econ-store` | 4 | M | `P03`, `P09`, `P10`, `P12`, `P15` | `scripts/economy/arsenal.gd`, `scripts/autoload/economy_manager.gd`, `scripts/data/item_kinds.gd` + 6 more | 6 |
| `DL2-items-data` | 4 | L | `P03`, `P10`, `P12`, `F1` | `lua/items/weapons.lua`, `lua/items/gems.lua`, `lua/items/dungeon_materials.lua` + 6 more | 5 |
| `V1-cast-data` | 4 | M | `P03`, `P05`, `P10`, `P12`, `F1` | `lua/config/characters.lua`, `lua/config/npcs.lua`, `lua/config/race_perks.lua` + 12 more | 10 |
| `V2-cast-art` | 4 | L | `P05`, `P08`, `P09`, `P21` | `tools/art/cast_v2/**`, `assets/isometric_characters/bear_brumme/**`, `assets/isometric_characters/bat_natteblik/**` + 9 more | 8 |
| `V3-levels` | 4 | L | `P04`, `P05`, `P09`, `P10` | `scripts/world2d/levels/**`, `tests/sections/city_levels.gd`, `tests/levels_shots.*` + 4 more | 9 |
| `V7-dialogue-v2` | 4 | M | `P03`, `P10`, `F1` | `lua/dialogue/gardener_hoppe.lua`, `lua/dialogue/carpenter_brumme.lua`, `lua/dialogue/postman_pip.lua` + 7 more | 9 |
| `D2-dungeon-floors` | 5 | L | `D1`, `DR1`, `F4`, `P06`, `P15`, `P04`, `P07`, `P03`, `P12`, `P13` | `scripts/dungeon/floors/**`, `scripts/dungeon/markers/**`, `scripts/ui/rune_picker.gd` + 2 more | 9 |
| `DR3-enemies` | 5 | L | `P04`, `P05`, `P06`, `P10`, `P12`, `P21`, `P22`, `F4`, `DR0`, `DR1` | `scripts/world2d/enemy_2d.gd`, `scripts/dungeon_run/enemies/**`, `scripts/dungeon_run/testing/**` + 4 more | 10 |
| `DR5-forest-hud` | 5 | L | `DR1`, `P03`, `P04`, `P06`, `P07`, `P12`, `P23` | `scripts/ui/forest_hud.gd`, `scenes/ui/forest_hud.tscn`, `scripts/world2d/minimap_2d.gd` + 7 more | 10 |
| `DL3-weapon-code` | 5 | M | `P06`, `P10`, `P12` | `scripts/combat/**`, `tests/sections/weapons.gd` | 5 |
| `DL4-loot-data` | 5 | L | `P03`, `P10`, `P12`, `F1`, `F4`, `D1`, `DL1`, `DL2` | `lua/data/loot_tables.lua`, `lua/config/dungeon_loot.lua`, `data/features/map_markers.json` + 11 more | 7 |
| `DL5-loot-rules` | 5 | L | `P10`, `P15`, `F4`, `D1`, `DL1` | `scripts/dungeon_loot/**`, `tests/sections/loot_dungeon.gd` | 7 |
| `V5-art-city` | 5 | L | `P08`, `P09`, `P22`, `A1`, `V3` | `assets/iso_props/city/**`, `assets/backdrops/treetop_*`, `tools/art/environment/city/**` + 1 more | 6 |
| `V6-city-life` | 5 | M | `P06`, `P12`, `P13`, `V1`, `V3` | `scripts/traetoppen/life/**`, `localization/life.csv`, `localization/life.csv.import` + 1 more | 8 |
| `V8-forest-look` | 5 | M | `P04`, `P06`, `P22`, `F4` | `scripts/forest_look/**`, `lua/config/forest_look.lua`, `localization/look.csv` + 2 more | 7 |
| `D3-dungeon-qa` | 5b | M | `D1`, `D2`, `DR3`, `P19`, `P22`, `F4`, `P11`, `P16`, `P06` | `tests/sections/dungeon_world.gd`, `tests/dungeon_shots.gd`, `tests/dungeon_shots.tscn` + 1 more | 3 |
| `DR4-bosses` | 5b | M | `DR3`, `DR1`, `DR0`, `D2` | `scripts/dungeon_run/bosses/**`, `lua/config/bosses.lua`, `tests/sections/bosses.gd` | 6 |
| `DL7-appraise-ui` | 5b | M | `P03`, `P07`, `P18`, `P12`, `F4`, `DL5` | `scripts/ui/appraisal_ui.gd`, `scenes/ui/appraisal_ui.tscn`, `localization/appraisal.csv` + 2 more | 3 |
| `V4-city-map` | 5b | M | `P04`, `P06`, `P11`, `P14`, `P19`, `V1`, `V3`, `V5`, `V6`, `V7`, `D2` | `data/maps/traetoppen.map`, `scripts/traetoppen/city_builder.gd`, `scripts/traetoppen/city_data.gd` + 3 more | 7 |
| `V9-keyart-v2` | 5b | S | `P08`, `P23`, `A2`, `V5` | `assets/ui/keyart/**`, `tools/art/keyart_v2/**`, `tests/sections/art_keyart_v2.gd` | 2 |
| `DL6-loot-icons` | 6 | M | `P08`, `P09`, `P23`, `DL2` | `tools/art/features/dungeon/**`, `assets/icons/items/wpn_*`, `assets/icons/items/rough_*` + 3 more | 3 |
| `DQ-dungeon-acceptance` | 7 | M | `D0`, `D2`, `D3`, `DL1`, `DL2`, `DL3`, `DL4`, `DL5`, `DL6`, `DL7`, `DR5`, `DR7`, `DR0`, `DR1`, `DR3`, `DR4`, `P24`, `P26` | `tests/sections/zz_dungeon_exp.gd`, `tests/sections/zz_loot.gd`, `tests/dungeon_exp_shots.gd` + 5 more | 8 |
| `V10-v2-qa` | 7 | S | `P11`, `P14`, `P16`, `P17`, `P19`, `P22`, `A2`, `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `P25`, `P26` | `tests/sections/zz_v2.gd`, `tests/checkpoints/v2/**`, `docs/qa/v2/**` | 4 |

### 12.2 What each new package is for (one line; the tasks are in `packages.json`)

| id | purpose |
|---|---|
| D1 | integer-only floor generator, exporter, independent verifier (46 invariants), pinned fallback seeds, merged floor table `dungeon.lua` (`rim.wall_depth` 0), `dungeon.csv`, stress + mutation + `find_fallback_seeds` tools |
| D0 | gentle defeat in `world_2d.gd` (<= 40 lines) + `snurresvampen` rebinding + `dungeon_defeat` tests |
| D2 | `DungeonFloors` run node + section `dungeon`, register-ahead + prefetch, boss / run events, runestone handler + rune picker, canopy fade, ForestDress hook |
| D3 | technical world gate (5b): city -> hub -> floors, bosses, save, handlers, table agreement; windowed shots + budgets; developer docs |
| DR0 | pickup orbs (`LootDrop2D`), telegraph ring / line, hit spark, heal sparkle |
| DR1 | `DungeonRun` rules library (curve, ladders, hearts, oil, assist, tutorial, picker lines, summary, surprises, `etagekort`, chest sense), `dungeon_run.lua`, sims, `dungeon_run.csv` |
| DR3 | `Enemy2D` + 7 kinds, telegraphs, bush ambush, leash, seeded RNG, drops, fight bot, `forest.csv` |
| DR4 | the three bosses (patterns, adds, berries, end whisper) |
| DR5 | forest HUD, minimap with fog, loot feed, floor banner, the four-tier loot reveal, sound cues |
| DR7 | supplies and elixirs, `etagekort`, `ugle_noegle`, Natteblik's map shop, four quests, `dungeon_services.csv` |
| DL1 | `Arsenal` weapon store, price keys for weapon / gem / material, rating-based equip |
| DL2 | 51 new item ids, 13 forging recipes, smithy rotation, 157 CSV rows |
| DL3 | `WeaponInfo`, `WeaponFx` (8 effects), `LanternGem`; real-player wiring test |
| DL4 | loot data (`loot_tables.lua` edits, `dungeon_loot.lua`), validator rules W / G / M / DB / P, productionised Monte Carlo |
| DL5 | loot rules (keyed streams, ladder, wanderers, cap, cooldown, bosses, spots, appraisal, state) |
| DL6 | 51 icons + 7 night variants, installed into `assets/icons/items/` (wave 6) |
| DL7 | Fru Ugle's appraisal screen (hosted by F4's LootService) |
| V1 | six heroes, seven NPC rows, zone names, species perks, timber yard, Pip's quest, `cast.csv`, `core.csv` |
| V2 | cast art: six new bodies / palettes + two restyles |
| V3 | levelled builder-area framework (registry, tracker, bridge strips, ladder, lift, fade, glow) + `levels.csv` + the city's `traetoppen.json` and `lua/config/traetoppen.lua` |
| V4 | the city: `traetoppen.map`, `CityBuilder`, landmarks, warps (reads V3's JSON and config) |
| V5 | city art (55 textures) + treetop backdrop |
| V6 | mailbox, notice board, bath, seed swap, Brumme's stall flags, Kiki's caches, Rejsestolpen (stretch) |
| V7 | dialogue of the seven new NPCs |
| V8 | forest look: ForestDress, SoftGround, Hulen keeper, pond whisper, lantern recipe, `look.csv` |
| V9 | title key art v2 |
| DQ | acceptance rows E1-E10, the driven loot dive, screenshots, budgets, real-play, sim re-runs |
| V10 | sketch coverage, zone-graph walk, strict contracts |

### 12.3 The wave plan (every dependency strictly earlier; 5b between 5 and 6 as in the feature addendum)

| wave | existing packages (* = amended by this addendum) | NEW packages | what the gate proves |
|---|---|---|---|
| **4** | P06-player-farm-core*, P11-maps-iso*, P13-quests-lua-runtime*, P16-ui-menus*, P18-ui-shop-inventory*, P22-art-environment*, P23-art-icons-keyart*, A2-art-wardrobe*, F2-home-core, F3-furniture-core, F4-loot-shops* | `D1-dungeon-gen`, `D0-dungeon-world-hooks`, `DR0-pickups-fx`, `DR1-rules`, `DR7-dungeon-services`, `DL1-econ-store`, `DL2-items-data`, `V1-cast-data`, `V2-cast-art`, `V3-levels`, `V7-dialogue-v2` | the generator + verifier green, the hub and farm / Hyggebyen maps, rules / items / data of the dungeon, the first runnable player; the weapon store and the cast data land with their tests |
| **5** | P14-npc-dialogue*, P17-ui-hud*, P19-forest-combat*, P20-animals-buildings, F5-wardrobe-core*, F6-home-world | `D2-dungeon-floors`, `DR3-enemies`, `DR5-forest-hud`, `DL3-weapon-code`, `DL4-loot-data`, `DL5-loot-rules`, `V5-art-city`, `V6-city-life`, `V8-forest-look` | the run node + registry + stones, enemies, forest UI, loot rules and data, city art / life / forest look; first full dungeon dive on the real handlers (D3 comes next) |
| **5b** | F7-home-ui, F8-wardrobe-ui* | `D3-dungeon-qa`, `DR4-bosses`, `DL7-appraise-ui`, `V4-city-map`, `V9-keyart-v2` | bosses, the city map (the Skovlift chain city -> hub -> floor 1 and back), the appraisal screen, the technical world gate D3 |
| **6** | P24-audio-voice*, P25-docs-refresh*, P26-loc-final* | `DL6-loot-icons` | audio placeholders, docs, copy pass, the dungeon icons (DL6: P23's missing-icon script turns strict) |
| **7** | P27-qa-acceptance*, F10-features-qa* | `DQ-dungeon-acceptance`, `V10-v2-qa` | acceptance: DQ rows, V10 sketch coverage, P27, F10 (all four at one gate) |

Built waves 1-3 are amended only by carve-outs and lead patches: P01-project-config (wave 1), P03-loc-core (wave 2), P04-area-framework (wave 3), P05-characters-pack (wave 2), P10-data-contracts (wave 2), P12-economy-shop-crafting (wave 3), P21-art-characters (wave 3), F1-feature-data (wave 3).

Why this order: the dungeon is reachable only through the city (V4, 5b): until then the hub and the floors are entered by `area_change_requested` in tests (D3 / DQ) and the farm bridge's target `traetoppen` is a PENDING area; nothing ships between waves. Wave 4 is the heaviest (22 packages: the 11 existing and 11 new): the three "data" packages DR7 / DL2 / V1 + V7 must agree at the gate (12.4) and V1 + V2 land together; DL3 moved to 5, DR7 to 4 and DL6 to 6 to make that work.

| wave | existing packages | points | NEW packages | points | all | points | largest built wave |
|---|---|---|---|---|---|---|---|
| **4** | 11 | 44 | 11 | 27 | **22** | **71** | 18 |
| **5** | 6 | 26 | 9 | 30 | **15** | **56** | 18 |
| **5b** | 2 | 6 | 5 | 9 | **7** | **15** | 18 |
| **6** | 3 | 5 | 1 | 2 | **4** | **7** | 18 |
| **7** | 2 | 4 | 2 | 3 | **4** | **7** | 18 |

Points: S 1, M 2, L 4, XL 8 (sizes of the plan and of the feature addendum; waves 1-3 had 5 / 11 / 18 points). Waves 4 and 5 together are 127 points against the 34 points of waves 1-3 together.

Waves 4 and 5 are both far above anything built (the largest built wave is 18 points) and the dependencies leave little room to move packages (checked against the dependency lists and the couplings of 12.4: V6 precedes V4, V7 precedes P14's roster walk, V1 and V2 share a wave, DL1 shares a wave with P18's Våben tab, V8's look is what D3's windowed shots judge); what the plan does about it is in 13.1: a CUT LIST for each of the two waves, every cut verified against the dependency graph, and the gate order inside a wave (data first, art last).

### 12.4 Same-wave couplings (data that two packages must agree on at the wave gate; declared dependencies stay strictly earlier)

| named by <- defined by | keys (examples) | resolved |
|---|---|---|
| D0-dungeon-world-hooks <- DR1-rules | `DEXP_DEFEAT_TEXT_FMT`, `DEXP_DEFEAT_TITLE` | wave gate |
| DL1-econ-store <- DL2-items-data | `WSTAT_BETTER` | wave gate |
| DR0-pickups-fx <- DR1-rules | `DEXP_BACKPACK_FULL` | wave gate |
| F4-loot-shops <- DR1-rules | `DEXP_BACKPACK_FULL` | wave gate |
| P06-player-farm-core <- DR1-rules | `DEXP_LAST_SPARK` | wave gate |
| P16-ui-menus <- D1-dungeon-gen | `DUNGEON_LEAVE`, `DUNGEON_LEAVE_CONFIRM` | wave gate |
| P16-ui-menus <- DR1-rules | `ASSIST_LEVEL_0`, `ASSIST_TITLE` | wave gate |
| P18-ui-shop-inventory <- DL2-items-data | `GEMFX_SET_IN_LANTERN`, `WSTAT_DAMAGE`, `WSTAT_EQUIP`, `WSTAT_EQUIPPED`, `WSTAT_FAMILY` ... | wave gate |
| P18-ui-shop-inventory <- DR1-rules | `DEXP_WEAPON_RANGE_FMT` | wave gate |
| V1 + V2 | the built `art_characters` section is roster-driven over `npcs.lua`: a new NPC row without its art folder turns it red | land in the SAME wave 4 |
| V1 + DR7 + V7 + P13 | Fru Ugle's / Oak's `quests_offered`, Natteblik's dialogue naming the shop, the four quest files | wave-4 gate; P13's table-driven section covers every quest file in the tree |
| P11 + V1 | hub / farm warps `label=ZONE_TRAETOPPEN` (core.csv is V1's) | wave-4 gate |
| DL4 + DL5 | `loot_dungeon.python_parity` runs `tools/dungeon_loot/mc.py` | SKIPs naming DL4 in an isolated build |
| F4 + DL5 | F4's delegation seam is tested with a FAKE delegate | DL5 (wave 5) replaces it |
| D2 + V8 | `ForestDress.attach` is late-bound | absent V8 = a plain floor |
| DL1 + DL2 + F4 | the smithy check of `economy.gd:961` compares only the `fixed` rows: DL2's two rotation rows and F4's ShopRotation add six `rotation` offers to the same shop | wave-4 gate (DL1 edits the check) |
| P23 + DL2 + DL6 | P23's missing-icon script lists weapons.lua / gems.lua / dungeon_materials.lua as PENDING until DL6's `tools/art/features/dungeon/manifest.json` exists | information only in waves 4, 5 and 5b; strict from wave 6 |
| P13 + V3 | `post.givers` of `lua/config/traetoppen.lua` (V3's file) | wave-4 gate; a fixture list in an isolated build, SKIP naming V3 |
| F4 + DL7 | F4's LootService hosts DL7's appraisal scene (late-bound `ResourceLoader.exists`) | the event is ignored until DL7 (5b): stub S21 |
| F4 + DL5 + DR1 | the two-phase rule: F4 calls DL5's `roll_*` / `fits` / `commit` through the late-bound seam (a fake delegate in F4's tests); the refusal whisper is DR1's `DEXP_BACKPACK_FULL` | DL5 (wave 5) replaces the fake |

### 12.5 Ownership proof (`check_ownership.py`, run on the final `packages.json`)

```
== ownership check: MERGED final_candidate/packages.json
packages in table: 66 | new packages: 28 | amendments: 27 | include patterns: 616 | exclusion patterns: 117
A  language intersection: 194 pattern pairs with comparable literal prefixes tested, 0 overlaps
B  repo expansion: 3509 tracked files | 0 with several owners | 379 owned by nobody | 76 claimed by a new package
C  ownsRemove sanity: 0 problems
D  dependencies / waves / verify tags: 0 problems
E  named paths: 151 concrete paths named in tasks | 0 owned by nobody or ambiguous | 71 cross-package mentions (info)
F  localization keys named before their CSV exists: 0 problems | 20 same-wave couplings (info)

OK: every pattern of every package was intersected with every other; no overlap, no repo file with two owners, dependencies point to earlier waves.
```

The raw union of the four track files gave: `A language intersection: 172 pattern pairs ... 0 overlaps`, `B 3458 files, 0 with several owners`, `D 1 problem` (P22 (wave 4) depended on D1 (wave 4)), `E 1 path owned by nobody` (`data/icons.json` of DL6): `python3 -I check_ownership.py --raw`. Self-test (`--selftest`): eight mutants of the merged file (claim of `iso_area.gd`, two packages owning one pattern, a dropped P19 carve-out, a self dependency, a task without `-> verify:`, a broad glob, a package that writes into a path owned by a LATER package, DL6 re-claiming `assets/icons/dungeon/**`) are all caught. Check E (named paths) was tightened by the editor: a package that names a NEW path (not tracked in the repo) owned by a package of a LATER wave is a problem unless the pair is in `HANDOFF_ALLOW` (registration rows of `marker_handlers.lua`, the late-bound appraisal scene, one hand-off sentence of P13); the first version dropped the finding when the writer was a dependency of the owner, which is the wrong direction (it let DL6 write into DQ's directory). `--with-ui` layers `docs/design/ui_workpackages.json` (0.5).


## 13. Risks (ordered by how much they would hurt) and what is NOT verified

1. **Waves 4 and 5 are overloaded** (review 3: wave 4 is 22 packages / 71 points after V3 grew from M to L, wave 5 15 / 56 after DL6 moved to wave 6 (it was 16 / 58), against a largest built wave of 18 points; 12.3 has the table). Nothing may move out of wave 4 or 5 without breaking a dependency (12.3), so the plan carries a CUT LIST per wave (each cut checked against the dependency graph and the couplings of 12.4; the first draft's cut list named V6's Rejsestolpen, which is a WAVE-5 package and gave wave 4 no relief). **Wave 4**, in this order: (1) P22's optional ortho art with procedural fallbacks (telegraph ring / line textures, `halo_amber`, `halo_violet`, `crown_spark`, `fx_hit_spark`, `fx_heal_sparkle`: DR0 draws the rings in code; the crowns, cave rings, runestone, bush eyes, ponds and ground textures stay: they ARE the sketch); (2) V2's two restyles (Kløvermynte, Mis re-baked in place: the six new bodies stay; the old art remains until wave 6); (3) DL1's Arsenal -> the cheaper fallback of risk 14 (weapons stay in the backpack, the Våben tab filters it); (4) DR7's quests `rune_vandring` and `bossernes_vej` together with Fru Ugle's / Oak's `quests_offered` entries (V1), their dialogue buttons (V7) and Oak's two branches (P14, wave 5). **Wave 5**: it falls into two halves whose only coupling is D2's late-bound `ForestDress.attach` (12.4), so two merge trains can run in parallel: the dive (D2, DR3, DR5, DL3, DL4, DL5 + P14, P19, F5) and the look and the city (V5, V6, V8 + P17, P20, F6; D2 late-binds V8); cuts in this order: (1) V6's Rejsestolpen (marker + two checks, its `fast_travel` config rows stay as inert data in V3's file); (2) V8's SoftGround (fallback = the tile art; the other V8 parts stay); (3) DR5's reduce-flash variant of the loot reveal is NOT a cut (an accessibility rule). Inside wave 4 the order is data first (D1, D0, DR0, DR1, DR7, DL1, DL2, V1, V3, V7), art last (V2, A2, P22, P23). Do NOT move V2 away from V1 (the built `art_characters` section is roster-driven over `npcs.lua`).
2. **The generator's second seed range found 3 defects the first range missed** (0.03 % of floors). The fix is measured on 10 008 floors, but there are 2^62 seeds: D1's acceptance runs BOTH ranges and the lead repeats `tools/dungeon/stress.sh` with a third range (`--first 5000`) at the final gate; the PINNED fallback (3.5) makes a defect a plain floor, never a crash: measured on all 12 specs and on the one real exhausted floor of 20 016; a changed table can invalidate a pinned seed, and `dungeon_gen.gen.fallback_valid` then fails loudly.
3. **Pace.** The corrected figure (5.9): the typical castle is day 246 without the furniture substitution (-27 %) and day 201 with it (-40 %); casual 718 / 591, dedicated 132 / 101; real hours 49.4 / 40.4 against the plan's 50.5. The first quote (263, -22 %) left the substitution out, valued the dust at an unproven 0.35 and let the 1 400 cap eat the deep floors; the corrected one is far above the analyst's -13 %. The dials (5.9) reach -35 % at most; open question 1. The model is the plan's profiles, no combat, 8-minute runs, and a substitution that replaces ALL furniture spending as soon as the dungeon has handed out enough (an upper bound).
4. **The crystal rule is simulated, not played.** The sim forces the player to appraise every stone; a real player appraises when it pays. The numbers say the gold effect is neutral either way and the gem supply arrives earlier (56 days), the dust sells for 8 gold (5.6) so it cannot become income, but "30 % stone, else dust" may feel stingy: it is two numbers in `dungeon_loot.lua`.
5. **Defeat costs the rest of the day and 10 % of the gold, uncapped** (about 880 gold for a typical wallet = 2-6 band runs). It is what the user wrote; the picker shows the amount before every dive; the cap question is open (8).
6. **Combat is a model.** Player archetypes are assumed, the world is 1-D, boss patterns are not simulated; the novice without assist hits a wall at bosses 2 / 3 (66 % / 92 % pass-outs from a stone start) unless the weapon is unique or the assist is on: the first two defeats are real. All numbers are Lua data; the fight bots test the real Enemy2D.
7. **Enemies are UNSHADED** (DV30): the tension of "eyes in the dark" rests on the additive eyes, the bush host and the lantern radius hiding terrain; a windowed review (`enemies.ambush_eyes_visible_outside_lantern`, `dungeon_world.world.art_sketch_compare`) must confirm it before art is baked.
8. **SoftGround is new** (mask + threshold shader for the smooth path and pond): unprototyped; fallback = the tile art; judged windowed against the sketch.
9. **Three recolours of one mushroom** carry the boss fights: variety lives in patterns and arenas; the four-boss table is verified data and one package row.
10. **Real-art cost and low-end machines are not measured** (every number uses placeholder art; the spike's model says 20 ms at 1080p on an Iris Xe class machine for a busier floor).
11. **Backpack pressure:** weapons live in the Arsenal, but stones, materials and spare gems share 24 slots (one band run puts 11-13 stacks in it); the answer is the existing shop and home chest; the Skovens-hjerte, tonics and oil add pressure. With the two-phase rule (5.7) a full pack refuses a WHOLE multi-roll chest (it used to deliver part of it again and again): the player stands in front of a closed chest with the whisper `DEXP_BACKPACK_FULL` until a slot is free, which is the honest cost.
12. **Same-wave coupling** (12.4) means an isolated build of V1, DR7, V7 or P11 can fail a check that only the wave gate satisfies; each such check names its partner and SKIPs with a reason in an isolated run.
13. **Cross-platform determinism** is measured on macOS arm64 and x86_64 only; Linux / Windows rely on the golden-digest test.
14. **Edits of three BUILT files by DL1** (`economy_manager.gd`, `rarity.gd`, `tools.lua`) and one by D0 (`world_2d.gd`): the cheaper fallback for the Arsenal (weapons stay in the backpack, a strictly worse weapon of the same family sells on pickup) is data plus `_auto_equip`.
15. **Daily seed:** a run left at floor 5 and resumed the same day continues in the same floors; the next day only the lit stones remain. The seed is computable from a save file by anyone who reads the algorithm (offline game; not hidden).
16. **The 16-light cap is order-dependent** (measured, 3.4): a canvas item drops lights from 15 other lights on (17 when the lantern was created first; one earlier run showed none dropped at 20), and which ones is not decided by tree or child order; the budget (12 map lights + the lantern) and `forest_look.light_budget_enforced` are the only guard, there is no mechanism to lean on.
17. **The UI navigation stream** merged into main after this addendum was written (0.5): P28, P17's wave move and nine amendments are not in this addendum's tables; `check_ownership.py --with-ui` finds no problem with a new package here, but the screens of this addendum (`rune_picker`, `appraisal_ui`, the forest HUD, the pause row) are not yet bound to its navigation rules or listed in `tests/lib/ui_screens.json`: the lead decides at the merge.
18. **A pinned fallback floor repeats** (about 1 floor in 10 000: the same layout every time for that floor): honest, cheap and measured; the alternative is a second generator.


## 14. Honest stubs: what exists, what the player sees

| # | item | status | what the player sees / what to do |
|---|---|---|---|
| S1 | Weapons have no sprite in the player's hand | gap by decision (DX35) | the swing arc and the hit spark are tinted with the rarity colour; icons carry the look; a weapon layer needs a new bake of every hero (open question 4) |
| S2 | `moon_wave` and `quake` visuals | placeholder | the cream pulse and existing dust; 2 Hz with `assist_reduce_flash` |
| S3 | Fishing at the Moon pond | stub | the pond is calm decor; standing at its edge whispers "Månesøen ligger stille. Fiskeri er ikke åbnet endnu." once per floor |
| S4 | Natteblik by day | honest | a hanging bat sprite (static, no hang clip) and a whisper; the map shop opens only for an evening entry |
| S5 | Pip never walks to the farm; parcels | not modelled | the farm mailbox flag and one toast per day are the whole "morning visit" |
| S6 | Hyggebyen | blueprint | PLAN 4.2's layout one bridge from the city; no district sketch exists |
| S7 | Flight in the city | off (`@flight false`) | fairies walk in Trætoppen |
| S8 | Rejsestolpen (fast travel) | STRETCH | cut first; if cut, marker, config rows and checks are removed together |
| S9 | Rasmus's scarf, Kiki's banana | not baked | bare neck / no banana (open question 12) |
| S10 | Music and ambience | names only | silent; 16 placeholder SFX are synthesised |
| S11 | The loot reveal's legendary moment | UI over the world | not a cutscene; the awe stun affects enemies already awake |
| S12 | SoftGround | new, unprototyped | tile art underneath is the fallback |
| S13 | Vitals are not saved | by design | a loaded floor starts with full hearts and a refilled lantern |
| S14 | The dungeon ends at floor 12 | bounded value | after the last boss: the home rope; no "Dybet" |
| S15 | Minimap fog | not saved | revealed cells are remembered for the visit only |
| S16 | The unknown-stone appraisal is about break-even at luck 0 (net +15 / +14 / +7 / 0 per stone) and pays +37 / +48 / +35 / +20 at luck 0.2 | by design (corrected: the first quote of +37 / +55 / +66 / +81 had no clamp) | its prize is the chance of a rare lantern gem and the gem collection; `appraisal.fee` is the lever |
| S17 | `ugle_noegle` before F4's locked chest exists | real item, nothing consumes it | only in an isolated wave-4 build; the final tree has the handler |
| S18 | Windowed checks | open | need a human at the machine under the one-window lock |
| S19 | The unknown parts of the model | listed in 13.6 | ASSUMED archetypes, 1-D world |
| S20 | The lake chest's art `chest_noegle` before P22 bakes it | placeholder with a code-drawn padlock | F4's handler draws `chest_konge` with a brass padlock overlay until the art exists (the first draft had no prop for the tier `noegle` at all) |
| S21 | Fru Ugle's 'Vurdér mine fund' before DL7 (wave 5b) | the event is ignored | LootService hosts the screen only when `scenes/ui/appraisal_ui.tscn` exists; in the final tree the choice opens it |
| S22 | A fallback floor | the same layout every time for that floor | about 1 floor in 10 000 takes the pinned fallback seed of its floor number; the loot of that floor still differs by day |
| S23 | The 51 new item icons before DL6 (wave 6) | placeholder badges | P23's script lists the three new item files as `pending DL6` (information); the strict checks `art_dungeon_icons.*` turn on with DL6's manifest |


## 15. Test and acceptance matrix

Conventions as built (P09): sections `tests/sections/<name>.gd` with `const SECTION`, `run(t)` headless, optional `run_windowed(t)`; check ids `<section>.<check>`; seeded RNG; throwaway HOME; every engine error AND warning fails a run; one window at a time (`impl/tools/windowed.sh`), run by the lead or the user at the wave boundary. A check that needs a later or same-wave package SKIPs naming it.

### 15.1 Checks per package (generated from the `-> verify:` tags of `packages.json`; amendments' checks are listed in 15.2)

| package | wave | section(s) | checks | check ids |
|---|---|---|---|---|
| `D1-dungeon-gen` | 4 | `dungeon_gen`, `loc` | 24 | dungeon_gen: rng.sfc32_vectors_pinned, rng.hash_key_pinned, rng.hash_key_avalanche, rng.below_unbiased, spec.floor_table_valid, spec.cross_refs, spec.moonstone_supply_8, spec.rim_wall_depth_zero_and_twelve_fallback_seeds_listed, gen.invariants_on_240_floors, gen.same_seed_same_text, gen.day_floor_save_change_floor, gen.first_attempt_rate, gen.mean_attempts, gen.fallback_rate_under_1_in_2000, gen.regression_seeds_hulen_far_and_tutorial_ambush, export.text_roundtrip, export.char_pool_not_exhausted, export.iso_projection_builds, gen.fallback_valid, gen.fallback_used_on_regression_seed, gen.thread_matches_serial, gen.golden_digests, keys_defined_da_en; loc: ownership_lint \| other: dungeon_gen.gen.inv.text_parses_without_errors .. dungeon_gen.gen.inv.visible_wall_tiles_at_most_400_per_screen, tools/dungeon/stress.sh 834 and tools/dungeon/stress.sh 834 --first 1000 both end with '0 violations' over 10 008 floors |
| `D0-dungeon-world-hooks` | 4 | `dungeon_defeat`, `content_features` | 9 | dungeon_defeat: defeat.next_morning, defeat.gold_minus_10_percent_rounded_down, defeat.items_and_equipment_kept, defeat.wake_at_farm_from_home, defeat.hearts_and_oil_restored, defeat.whisper_and_warm_toast_through_dungeonrun, defeat.autosave_written, quest_snurresvampen_binds_floor_4_and_completes; content_features: quest_references_valid \| other: tests/run_playtest.sh --only=dungeon_defeat, area passes with zero engine errors |
| `DR0-pickups-fx` | 4 | `dungeon_pickups` | 10 | dungeon_pickups: orb_magnet_and_pickup, pickup_goes_through_loot_deliver_when_present, rare_gate_no_double_toast, berry_heals_when_hurt, orb_cap_50_auto_collects, orb_magnet_grows_with_pickup_gem, telegraph_ring_matches_hit_area, telegraph_pool_cap_8, fx_pool_reuse, section_clean |
| `DR1-rules` | 4 | `dungeon_run`, `loc` | 27 | dungeon_run: config_complete, expected_weapon_curve_monotone, cfg_fallback_equals_lua, weapon_family_rows_valid, weapon_rating_matches_loot_ttk, enemy_hp_ladder_matches_table, enemy_damage_ladder_by_tier, hearts_max_composition, oil_drains_only_on_floors_and_not_in_modals, darkness_never_below_two_half_hearts, auto_refuel_order, assist_presets_map_to_multipliers, assist_never_touches_loot, boss_killed_flags_and_hearts_once, after_defeat_copy_and_counters, chest_sense_is_max_of_sources, run_watch_summary_toasts_three, run_watch_applies_surprises, run_watch_etagekort_reveals_next_floor, tutorial_spacing_and_flags, events_payload_shapes, picker_lines_follow_highlight, keys_defined_da_en, no_new_input_action_signal_autoload, section_clean, boss_kinds_match_floor_table; loc: ownership_lint \| other: validator: dungeon_sim.claims_hold |
| `DR7-dungeon-services` | 4 | `dungeon_services`, `economy`, `quests`, `loc` | 13 | dungeon_services: supplies_defs_valid, elixir_recipes_craftable, shops_valid, quests_load_and_bind, dialogue_hooks_present, section_clean, keys_defined_da_en; economy: item_defs_complete, sell_below_half_of_buy, no_buy_sell_loop; quests: every_objective_completable_with_dungeon_events, manual_objectives_have_completers; loc: ownership_lint |
| `DL1-econ-store` | 4 | `arsenal`, `rarity`, `economy` | 13 | arsenal: store_contract_answers, weapon_category_routes_to_store, v1_save_adopts_backpack_weapons, save_roundtrip, equip_same_family_higher_rating_only, better_other_family_toasts_only, equipped_copy_not_sellable; rarity: weapon_gem_material_keys_present, fallback_equals_lua; economy: smithy_fixed_stock_unchanged, smithy_rotation_pools_hold_no_keepsake, item_defs_complete, starter_kit_equips_sword_rusty \| other: tests/run_playtest.sh --only=economy, rarity, arsenal, save, data |
| `DL2-items-data` | 4 | `dungeon_items`, `loc` | 11 | dungeon_items: ids_load_51, shop_rows_valid, names_and_descriptions_resolve_da_en, keepsakes_protected_no_price, recipes_in_cost_band, damage_formula, dng_material_prices_pinned, materials_have_sources_without_unplaced_nodes, rune_shards_are_three; loc: ownership_lint, lint_clean_for_non_legacy_files |
| `V1-cast-data` | 4 | `characters`, `data`, `cast_data`, `loc`, `economy` | 21 | characters: heroes_two_per_race, skin_chains_match_the_addendum, retired_skins_resolve, catalog_heroes_api, species_chips; data: race_skins_match_characters, race_perks_complete, roster_ids, roster_fields; cast_data: species_perk_precedence, species_perks_complete, npc_homes_match_zone_graph, pips_runde_loads_through_lua_runtime, pips_runde_objectives_bind, keys_da_en_complete, no_old_town_name_anywhere, no_foreign_csv_touched, timber_yard_stock_items_exist_and_keeper; loc: ownership_lint, core_csv_pins; economy: shop_system_green |
| `V2-cast-art` | 4 | `art_cast_v2`, `art_characters` | 15 | art_cast_v2: builders_resolve, shim_does_not_edit_p21, restyle_idle_s_palette, roles_and_clip_sets, portraits_exist_and_are_busts, manifest_lists_new_ids, palette_within_de, heights_and_pivot, review_sheets_exist, readme_has_the_honest_notes; art_characters: cast_pixels, roster_is_42, roster_visuals_resolve, portrait_lookup_order, vram_budget_hyggebyen |
| `V3-levels` | 4 | `city_levels`, `loc` | 22 | city_levels: level_at_is_a_function_of_position, levels_disjoint, set_level_changes_z_shadow_mask, late_actor_gets_level_on_enter, lock_blocks_the_tracker, bridge_strip_polygon_matches_path, railing_gap_count, colliders_use_level_bits_only, ladder_climb_flips_level, monkey_climbs_faster, lift_requests_area_change, occluder_fade_alpha, glow_follows_day_night_signal, glow_connection_released_on_leave, rank_order, validator_mutants, ysort_pixels, json_matches_extract_within_1px, validator_green_on_shipped_json, config_numbers_documented, prompt_keys_defined_da_en; loc: ownership_lint |
| `V7-dialogue-v2` | 4 | `npc_cast` | 13 | npc_cast: hoppe_branches, brumme_branches, open_shop_ids_are_shops_of_the_speaker, pip_branches, pips_runde_acceptable_by_dialogue_contract, sofus_branches, ugle_branches, emit_event_actions_are_declared, natteblik_branches, birk_branches, keys_da_en_complete, voice_keys_shape, runs_through_lua_runtime |
| `D2-dungeon-floors` | 5 | `dungeon_floors`, `loc` | 28 | dungeon_floors: floors.world_seed_made_on_new_game, floors.section_registered_order_45_and_resets, floors.spec_or_gen_mismatch_drops_run_keeps_stones, floors.section_size_worst_case_under_4kb, floors.save_roundtrip_registers_floor_before_world, floors.leave_with_open_modals_travels, floors.seed_pinned_while_active, floors.new_day_clears_done_and_seen, floors.same_day_reenter_keeps_done, floors.register_ahead_neighbours_and_unregister_far, floors.hulen_warp_travels_through_the_bus, floors.unregistered_floor_refused, floors.leave_to_hub_keeps_everything, floors.up_cave_chain, floors.prefetch_equals_sync, floors.day_started_prunes_when_outside, floors.uid_and_rng_deterministic, floors.done_cells_skip_consumed_markers, floors.boss_flag_opens_hulen_and_chest, floors.stone_activation_effects, floors.rune_picker_lists_one_plus_stones, floors.enter_from_stone_starts_at_that_floor, floors.oil_refill_first_visit_only, floors.canopy_fade_alpha, floors.forest_dress_attached_when_present, keys_resolve_da_en, floors.no_new_autoload_action_signal; loc: ownership_lint |
| `DR3-enemies` | 5 | `enemies` | 25 | enemies: create_marker_is_the_picked_entry_point, every_kind_spawns_and_dies, hp_ladder_matches_expected_weapon, damage_ladder_by_tier, marker_params_tier_critter_boss, stagger_cancels_windup_except_armor, telegraph_windup_ring_and_pulse, no_damage_during_dodge_iframes, assist_scales_windup_and_damage, behaviors_follow_data, ambush_rustle_then_leap_once, ambush_kind_fallback, fe_lys_reveals_and_stuns_ambushers, runestone_leash_blocks_aggro, sleeping_enemies_cost_zero, awake_cap_in_view_24, rng_seeded_replay, drops_via_lootservice_and_orbs, death_tween_clean, bot_fight_matches_model, names_keys_defined, section_clean, ambush_eyes_visible_outside_lantern, telegraph_ring_readable, done_cells_skip_consumed_enemies \| other: validator K9 PASS, ui_foundation.ability_slot_danish_label runs |
| `DR5-forest-hud` | 5 | `dungeon_hud`, `dungeon_reveal` | 22 | dungeon_hud: reacts_to_events, hearts_scale_with_bonus, chip_text_from_header, hint_pulses_ability_slot, backpack_chip_and_full_whisper, assist_badge, hidden_in_farm_mode, minimap_fog_reveal_and_map, loot_feed_coalesces_and_caps, floor_banner_once_per_floor, diff_vs_guide_forest, hearts_9_layout, picker_lines_shot; dungeon_reveal: tier_selection_by_rank, item_already_in_store_before_reveal, queue_best_rank_first, legendary_awe_stun_and_skip, reduce_flash_variant, cues_by_rarity, missing_audio_is_silent, unique_shot, legendary_shot |
| `DL3-weapon-code` | 5 | `weapons` | 8 | weapons: weapon_info_family_rows, sword_equivalent_range, fx_each_effect_on_stub_player, light_cd_never_below_min, lantern_gem_effects_per_step, chest_sense_is_max_not_sum, dps_parity_within_ten_percent, player_uses_weapon_info_and_lantern_gem |
| `DL4-loot-data` | 5 | `content_features`, `maps_iso`, `loc` | 3 | content_features: map_markers_equal_loot_tables; maps_iso: feature_markers_match_json; loc: ownership_lint \| other: tools/features/validate/run_validate.sh --stage full R1 R2 R3 R10 R11 R12, validator DB1 DB2 DB3 DB4 DB5, mutation_test.py catches the retargeted MM1 mutants, run_validate.sh --stage full exit 0, rules_selftest.py, mutation_test.py catches all mutants, tools/dungeon_loot/run.sh --check exit 0, tests/run_playtest.sh --only=content_features, validator DB5, validator M1, mutation_test.py catches a yield row without a placed node kind |
| `DL5-loot-rules` | 5 | `loot_dungeon` | 25 | loot_dungeon: rng_pinned_vectors, depth_odds_match_table, rates_match_odds, legendary_never_from_ordinary_chests, wanderer_once_with_pity_and_cooldown, daily_cap_binds_and_resets, boss_first_kill_weekly_pity, boss_pool_rates_read_from_data, boss_idempotent_per_uid, rune_chain_consumes_three_shards, lake_key_consumed_first_gem_once, save_roundtrip_dungeon_subdict, reload_same_outcome, backpack_full_leaves_chest_closed, duplicate_weapon_sold, keepsake_found_registry_survives_sale, appraisal_pure_function_of_band_counter, python_parity, multi_roll_full_backpack_delivers_nothing, boss_full_pack_keeps_first_kill_pending, retry_after_full_changes_no_state, deliver_after_fit_never_refuses, appraisal_streams_independent_per_band, appraisal_commits_save_before_result, appraisal_counter_and_stone_in_one_commit |
| `V5-art-city` | 5 | `art_city` | 10 | art_city: sizes_match_json, tileable_trunk_seam, huts_have_night_layers, night_layers_additive, bridge_parts_tile_seamlessly, landmark_props_exist, every_city_json_prop_has_art, backdrop_loads_through_artcatalog, vram_budget, sizes_scale_with_k |
| `V6-city-life` | 5 | `city_life` | 19 | city_life: post_letter_selection, post_once_per_day, post_accept_starts_quest, post_toast_once, board_lists_only_everyday_givers, board_accept_starts_quest, bath_restores_and_costs_time, bath_once_per_day, swap_needs_two_carrots, swap_once_per_day, swap_refused_when_backpack_full, brumme_weekend_stall_flags, cache_only_for_monkey, cache_once_per_day, cache_reward_is_small, fast_travel_unlocks_on_arrival, fast_travel_absent_in_dungeon, keys_da_en_complete, numbers_come_from_config |
| `V8-forest-look` | 5 | `forest_look` | 18 | forest_look: config_numbers_present, lantern_energy_matches_sketch, actors_unshaded_in_forest_only, light_budget_enforced, firefly_field_cost_free, attach_and_marker_are_equivalent, soft_ground_masks_follow_cells, soft_ground_keeps_cells_walkable, pond_blocks_walkers, soft_ground_cost_under_0_3_ms, hulen_keeper_night_vs_day, pond_whisper_stub_once_per_floor, fixture_map_builds_with_every_marker, markers_registered_in_marker_handlers_lua, shot_forest_sketch_layout, lantern_lift_profile, frame_budget, keys_da_en_complete |
| `D3-dungeon-qa` | 5b | `dungeon_world` | 20 | dungeon_world: world.boss_tables_agree, world.crystal_and_node_kinds_have_yield_rows, world.hub_has_one_gate_to_the_skovlift, world.hub_to_f1_through_the_hulen, world.all_12_floors_chain_down_and_up, world.boss_floor_sealed_then_open, world.pause_leave_goes_to_hub, world.save_in_floor_loads_in_floor, world.day_change_new_dungeon, world.picker_start_floor, world.real_handlers_consume_cells, world.enter_budget_p95_under_150ms, world.tour_12_floors_no_engine_errors, world.quest_bindings_resolve, world.art_dungeon_floor_readable, world.perf_dungeon_render_budget, world.art_canopy_fade_visible, world.art_lantern_visible_with_14_lights, world.art_sketch_compare, docs.marker_vocabulary_matches_generator |
| `DR4-bosses` | 5b | `bosses` | 14 | bosses: boss_bar_events, phase_berries_at_66_33, kind_ids_stable_for_quests, reset_on_leave, adds_in_two_waves, pattern_timings_snurresvamp, pattern_timings_gloed, pattern_timings_konge, telegraph_present_every_windup, first_kill_grants_skovhjerte_once, end_whisper_after_last_boss, bot_beats_each_boss_in_window, boss_telegraph_shot, section_clean |
| `DL7-appraise-ui` | 5b | `appraisal`, `loc` | 7 | appraisal: opens_through_loot_service_on_event, fee_charged_per_stone, no_gold_no_change, full_backpack_refuses, keys_resolve_da_en, dialogue_choice_present; loc: ownership_lint |
| `V4-city-map` | 5b | `city_map` | 18 | city_map: json_matches_extract_within_1px, rank_order, builds_in_budget, no_builder_error, walkable_test_matches_levels, every_warp_round_trips, skovlift_closed_whisper_when_no_forest, zone_unlocks_on_first_arrival, landmarks_reachable_flood_fill, landmark_positions_within_3_percent_of_sketch, npc_markers_resolve_in_npcs_lua, keys_da_en_complete, config_numbers_documented, save_inside_city_roundtrip, shot_overview_0_2, frame_budget, skovlift_reaches_floor_1_and_back, defeat_wakes_at_the_farm |
| `V9-keyart-v2` | 5b | `art_keyart_v2` | 3 | art_keyart_v2: size_and_layers, safe_areas_quiet, review_sheet_exists |
| `DL6-loot-icons` | 6 | `art_dungeon_icons` | 5 | art_dungeon_icons: ui_resolves_every_icon, night_variants_for_legendary, 51_icons_exist_128, rarity_rim_colour_matches, night_variants_resolve_in_both_resolvers \| other: tools/art/features/dungeon/make_icons.py --check exit 0 |
| `DQ-dungeon-acceptance` | 7 | `zz_dungeon_exp` | 1 | zz_dungeon_exp: screenshots_complete \| other: zz_dungeon_exp.E1 .. E10, windowed zz_dungeon_exp.E8_budgets, docs/qa/dungeon/REAL_PLAY.md exists and is filled in; zz_dungeon_exp.report_written, validator: dungeon_sim.claims_hold, tests/run_playtest.sh --only=zz_loot, the report lists each check with a screenshot or the reason it was not run, run.sh --check exit 0 |
| `V10-v2-qa` | 7 | `zz_v2` | 8 | zz_v2: sketch_coverage_complete, zone_graph_walk, quest_zone_bindings, cross_track_contracts_strict, cast_palettes_match_hero_palettes, no_new_autoloads_actions_signals, no_old_town_name_anywhere, windowed_checkpoints |

412 named checks in the new packages (plus the per-invariant ids `dungeon_gen.gen.inv.*`, 46, which one verify tag stands for).

### 15.2 Checks added to existing packages (from the amendments)

| package | checks (acceptanceAdd and the verify tags of its tasks) |
|---|---|
| `P01-project-config` | project.gitignore_has_dungeon_entries, files exist; PLAN_2D.md links to them |
| `P03-loc-core` | loc.ownership_lint with the dungeon families, loc.ownership_lint |
| `P06-player-farm-core` | player.dungeon_api_heal_full_restore_oil_add_oil, player.lantern_survives_light_budget, player.weapon_family_swing_params, player.assist_hooks_with_and_without_dungeonrules, player.species_perks_applied, player.heal_half_clamps, player.restore_stamina_and_heal_half, player.faint_emits_once, player.restore_uses_hearts_max, windowed player.lantern_survives_light_budget, player.weapon_effect_hooks_late_bound, player.input_buffer, player.dodge_cancels_swing, player.hit_stop_frames, player.last_spark_once_per_run, player.max_hearts_from_dungeonrules, player.oil_rules, player.dark_bite_floor, player.lantern_gem_bonuses_apply, player.drink_order, player.cd_ratio_for_ability_slots |
| `P11-maps-iso` | maps_iso.hub_parses_and_connects, maps_iso.hub_has_one_gate_to_the_skovlift, maps_iso.farm_warp_graph, maps_iso.hyggebyen_warp_graph, maps_iso.farm_mailbox_marker, maps_iso.feature_markers_match_json, maps_iso.connectivity, loc_check, maps_iso.warp_roundtrips, maps_iso.warp_graph_pending_areas |
| `P13-quests-lua-runtime` | quests.every_objective_completable_with_dungeon_events, quests.offerable_by_giver, quests.offerable_for_many, quests.intro_lottery_binds_traetoppen, quests.no_fixed_forest_area_ids, quests.game_event_min_level_generic, quests.zone_entered_repeat_is_harmless, quests.bound_quests_have_their_floor_anchors |
| `P16-ui-menus` | menus.hero_chips_two_per_race, menus.pause_leave_dungeon_button, menus.assist_group_visible_only_in_game, menus.new_game_all_six_heroes, menus.no_raw_keys_both_locales, menus.assist_changes_flags, menus.pause_leave_travels_to_the_hub |
| `P18-ui-shop-inventory` | shop_ui.weapon_tab_and_gem_card, shop_ui.weapon_card_range_line |
| `P22-art-environment` | art_environment.forest_art_ids_exist, art_environment.dungeon_prop_defs_complete, art_environment.forest_crowns_baked_at_36, art_environment.dungeon_crowns_present_and_sized, art_environment.forest_albedo_within_ambient_headroom, art_environment.props_extra_ids_exist, art_environment.dungeon_ids_in_catalog, ArtCatalog.missing, art_environment.ortho_decision_mentions_rim_depth, art_environment.ortho_decision_mentions_crowns |
| `P23-art-icons-keyart` | art_icons.dungeon_supplies_have_icons, art_icons.missing_icons_three_dirs, art_icons.dungeon_item_files_pending_until_dl6, art_icons.keyart_slice_defers_to_v9 |
| `A2-art-wardrobe` | art_wardrobe.catalogue_shapes (6 heroes), art_wardrobe.hero_palettes_within_de, art_wardrobe.monkey_scope_fit, art_wardrobe.catalogue_shapes, art_wardrobe.bases_and_busts_for_six, art_wardrobe.head_scope_occluder_equality, art_wardrobe.no_scarf_in_base_layers, art_wardrobe.manifest_untouched |
| `F4-loot-shops` | loot.dungeon_markers_use_done_cells_and_uid, loot.dungeon_ctx_signatures_and_full_backpack, loot.legendary_never_from_ordinary_chests, loot.multi_roll_full_backpack_changes_nothing, loot.open_appraisal_event_instantiates_scene_when_present, loot.dungeon_floors_node_hosted_and_section_registered, loot.marker_handlers_registered, loot.chest_lock_needs_key, loot.locked_chest_consumes_key, loot.full_backpack_leaves_chest_closed, loot.lake_chest_has_art_or_padlock_fallback, loot.hidden_chest_reveal_radius, loot.two_phase_plan_fit_deliver_commit_with_fake, loot.no_opened_entries_for_dungeon_uids, loot.dungeon_delegate_seam_with_fake, loot.save_roundtrip_dungeon_subdict_optional, loot.boss_table_keyed_by_id, loot.open_appraisal_event_ignored_without_scene, loot.dungeon_keys_defined_da_en, loc.ownership_lint |
| `P14-npc-dialogue` | npc.every_roster_npc_has_a_dialogue_file, npc.dungeon_quests_acceptable_by_dialogue, npc.emit_event_action, npc.context_weather_race_stamina_zone_shops, npc.context_total_day_matches_game_manager, npc.reach_override_talkable_from_distance, npc.when_night_hides_the_npc, npc.mis_two_states, npc.oak_lift_line, npc.feature_quests_acceptable_by_dialogue still green |
| `P17-ui-hud` | hud.v2_date_block_text, hud.zone_banner_uses_area_title, hud.toast_queue_keeps_summary_order, hud.v2_energy_in_chip, hud.hotbar_selected_style, hud.landmark_sub_banner, hud.v2_crops_compare, hud.no_double_toast_in_action_mode |
| `P19-forest-combat` | forest.generated_floors_parse_and_connect, forest.node_loot_through_loot_service, forest.planter_nodes_respawn_daily, forest.no_legacy_files, forest.section_runs_without_removed_files, forest.maps_art_complete, forest.marker_counts_match_the_table, forest.done_cells_skip_consumed_nodes, forest.handlers_build_on_generated_floor, forest.forage_pick_with_e |
| `F5-wardrobe-core` | wardrobe.heroes_from_catalog, wardrobe.retired_skin_dresses_live_body |
| `F8-wardrobe-ui` | wardrobe_ui.preview_six_heroes |
| `P24-audio-voice` | voice.dungeon_sfx_files_exist, voice.new_npc_voice_files_generated, voice.pip_voice_path_is_own, voice.cue_ids_registered, voice.sfx_hooks_for_city_events |
| `P25-docs-refresh` | docs.howto_dungeon_pages_exist, docs.lua_api_lists_dungeon_keys, docs.howtos_exist_for_loot, docs.v2_pages_present |
| `P26-loc-final` | loc_final.final_review_dungeon_keys, loc_final.glossary_halvling_consistent, loc_final.keys_defined_da_en, loc_final.no_raw_keys_on_dungeon_screens, loc_final.final_review_dungeon_items_and_appraisal, loc_final.no_old_town_name |
| `P27-qa-acceptance` | zz_acceptance.row_11_dungeon, zz_acceptance.includes_v2_rows, zz_acceptance.sections_declare_timeouts_above_default, zz_acceptance.gate_command_lines_documented |
| `F10-features-qa` | zz_features.row_17_18_dungeon_sources, the report names the zz_loot result |

### 15.3 Acceptance rows (extending PLAN 8.2 and the feature addendum's rows 14-21)

| row | requirement | check | owner |
|---|---|---|---|
| 11 (replaced) | dark forest, mushroom grove, crystal cave | `dungeon_gen` + `dungeon_floors` + `dungeon_world` + `dungeon_01..08` + `zz_dungeon_exp.E1 .. E10` + `zz_loot` | D1 D2 D3 DQ |
| 22 | procedural chained floors: new seed every day, same day = same floors, consumed state kept, the Hulen leads on, leave any time | `dungeon_floors.floors.same_day_reenter_keeps_done`, `new_day_clears_done_and_seen`, `dungeon_world.world.hub_to_f1_through_the_hulen`, `all_12_floors_chain_down_and_up`, `pause_leave_goes_to_hub` | D2 D3 |
| 23 | runestones are checkpoints and quest triggers | `floors.stone_activation_effects`, `rune_picker_lists_one_plus_stones`, `enter_from_stone_starts_at_that_floor`, `quests.every_objective_completable_with_dungeon_events` | D2 P13 |
| 24 | a boss every few floors, sealed Hulen, first-kill hearts | `floors.boss_flag_opens_hulen_and_chest`, `bosses.*`, E3 | D2 DR4 DQ |
| 25 | rare, unique and legendary furniture, weapons, materials and gems (new categories) | `loot_dungeon.legendary_never_from_ordinary_chests`, `rates_match_odds`, `dungeon_items.*`, `weapons.dps_parity_within_ten_percent`, `zz_loot` | DL1-DL5 DQ |
| 26 | deeper floors drop better rarities | `loot_dungeon.depth_odds_match_table` (12 rows of 5.1), `python_parity` | DL5 |
| 27 | gentle defeat | `dungeon_defeat.*`, E2 | D0 DQ |
| 28 | two places: Trætoppen city and Hyggebyen, the farm on its own branch | `zz_v2.zone_graph_walk`, `sketch_coverage_complete`, `city_map.*` | V10 V4 |
| 29 | the v2 characters and environment | `art_cast_v2.*`, `cast_data.*`, `npc_cast.*`, `forest_look.*`, `art_city.*` | V1 V2 V5 V7 V8 |
| 30 | no new autoload, input action, EventBus signal, no second seed | `dungeon_floors.floors.no_new_autoload_action_signal`, `dungeon_run.no_new_input_action_signal_autoload`, E9, `zz_v2.no_new_autoloads_actions_signals` | D2 DR1 DQ V10 |

### 15.4 DQ rows E1-E10 and the screenshots

E1 First trip (city Skovlift -> hub -> floor 1 -> floor 3 stone -> pause leave: `skovlift_intro` completes in order, three summary toasts), E2 Gentle defeat (floor 2, 1 000 gold, full backpack -> farm next morning, 900 gold, items identical, warm toast, autosave exists), E3 Boss 1 (the bot kills Snurresvampen: `dungeon_hearts_bonus` 2 once, roots part, the next day's boss gives no second heart), E4 Reveal tiers, E5 Assist (Hyggelig: hearts +4, every hit 1, windup x1.4), E6 Quests (the four through real events; the zone quests through `zone_entered`), E7 Save in a floor (stone of floor 5), E8 Budgets (windowed), E9 Contracts, E10 Surprises and maps. Screenshots `exp_01..12` (picker with checklist, floor 1 banner, lantern + beacons, ambush ring, chest, unique card, legendary moment, boss arena, boss bar + berries, 9-heart HUD + assist badge, wake-up toast, summary toasts) and D3's `dungeon_01..08` (hub, floor 1, floor 3 stone, floor 4 arena with roots, floor 7, floor 9 key chest, floor 11 cave, floor 12) compared by eye with `refs/miljoer_v2_render.png`; five loot checks (Våben tab, appraisal screen, gem in the lantern, icon contact sheet, legendary reveal); V10's eight checkpoints (character select with six heroes, cast sheet, city at 0.4 and 0.2, Brumme's stall, the bath at dusk, farm mailbox, forest layout with Natteblik at the Hulen, city HUD crops <= 12 per box).

### 15.5 Validators and tools that gate

`tools/features/validate/run_validate.sh --stage full` (DL4: R1 R2 R3 R7 R10-R12 generalised, W1-W5 weapons, G1-G3 gems, M1 materials, K1 keys, DB1-DB5 dungeon agreement, P1 Monte Carlo budgets; `mutation_test.py` catches the old 26 + 8 new mutants; M2 caps the sell price of a dng_ material at 25 % of its nominal price; W5 values an unbuyable ingredient at 2.2 x its sell price), `tools/dungeon/stress.sh 834` (both seed ranges; D1) and `tools/dungeon/mutants.py` (>= 12 of 14), `tools/dungeon_run/run_sim.sh --check` (`dungeon_sim.claims_hold`), `tools/dungeon_loot/run.sh --check`, `tools/loc` lints (`loc.ownership_lint`, key owners), `LevelRules.validate` on `traetoppen.json`, `check_ownership.py` (the lead, before each wave).

### 15.6 Budgets (one table; windowed on the M3, 1280 x 720, zoom 0.4)

| quantity | limit | source |
|---|---|---|
| floor CPU render | <= 8 ms (12 ms at 1080p with real art and 50 enemies) | PLAN 8.6 / D3 |
| busy floor (24 awake enemies, 12 lights, 200 props, 8 rings, 15 orbs) | <= 12 ms | DQ E8 |
| floor `_enter` | <= 220 ms (the fade); generation + export p95 <= 95 ms headless | D1 / D3 |
| forest HUD / reveal / DungeonRun logic | <= 0.4 / 0.3 / 0.05 ms per frame | DR5, DR1 |
| city frame / rebuild | <= 6 ms and <= 250 draw calls / <= 40 ms warm | V4 |
| lights | <= 12 overlapping a point; a canvas item sees <= 12 map lights + the lantern; 16 per canvas item is the HARD engine cap and it drops lights from 15 other lights on in an order the game cannot control (no ordering trick: the budget is the rule, 3.4) | V8, D1, P06 |
| save | section `dungeon` <= 4 KB, `loot.dungeon` < 3 KB | D2, DL5 |
| sections | each default section < 60 s, `zz_loot` < 180 s, `zz_dungeon_exp` < 120 s; a section whose budget exceeds the harness's 120 s default declares `const TIMEOUT_S` = budget + 30 % (`zz_loot` 240, `zz_dungeon_exp` 160) | DQ, P27 |
| whole headless suite (final gate) | `tests/run_playtest.sh --timeout=3000 --max-seconds=2700`; today 12 sections / 1 870 checks / 73.5 s, about 40 new and 20 amended sections add under about 2 000 s of declared budgets; the defaults (900 s / 1 200 s) are for today's tree | P27 |
| one wave gate | `tests/run_playtest.sh --only=<the sections of the wave> --timeout=1500 --max-seconds=1300` | the lead |
| clean engine log | zero engine errors AND warnings in every run (also the forced fallback floors and the full-backpack paths) | all |


## 16. Evidence index (everything under `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design2/`)

| path | what |
|---|---|
| `final_candidate/ADDENDUM.md`, `packages.json`, `key_owners_additions.json` | this document, the work packages (schema of `features_workpackages.json`), the merged key-owner entries |
| `final_candidate/check_ownership.py` | the ownership proof (`--raw` the four tracks unioned, `--selftest` eight mutants, `--list` the effective pattern table, `--info`, `--with-ui` the UI navigation stream layered over the table) |
| `final_candidate/lua/config/dungeon.lua`, `dungeon_loot.lua`, `lua/items/dungeon_materials.lua`, `lua/recipes/dungeon.lua` | the FINAL floor table (`rim.wall_depth` 0, 12 pinned fallback seeds), the loot config (cap 3 200 on chest / dig / appraise, limits), and the editor's versions of the loot track's materials (final prices) and recipes (moonshard widened): D1, DL4 and DL2 copy them |
| `final_candidate/final_gen/` | the editor's generator pass: `run.sh`, `stress10k.sh`, `results/` (both 10 008-floor ranges on the FINAL table, digests arm64 / x86_64 at depth 0, the four-boss table at depth 0, `fallback_check_output.txt`, `find_fallback_output.txt`); the prototype changes are in `gen_check/proto/` (`dg2_gen.gd` `generate` / `_run`, `find_fallback.gd`, `fallback_check.gd`, `stress.gd`) |
| `final_candidate/final_sim/` | the editor's economy pass: `sim/` (`loot_mc.py` with `daily.counts`, per-band caps, DNG_SELL_SHARE 1.0 and the dials; `appraisal_ev.py` with the clamp; `appraisal_scum_fixed.py`; `partial_delivery_fixed.py`; `keepsake_fuzz_fixed.py`; `cap_grid.py`; `dial_pace.py`; `final_pace.py`; `recipe_band.py`; `balance_sim_free.py`), `results/` (every number of 5.5-5.9) |
| `final_candidate/final_probes/` | Godot probes in clones: `paused_travel_*` (the leave under the pause modal), `light_cap*` (the 16-light cap, windowed), `icon_fix_probe*` (where an icon resolves), the baseline run log of the tree at `2f6410b` |
| `final_candidate/gen_check/` | `dungeon_final.lua` (= the table above), `dungeon_alt_warp.lua`, `proto/` (the generator prototype + `proto_changes_dg2_gen.diff`), `run.sh`, `stress10k.sh`, `results/` (digests arm64 / x86_64, 1 200-floor and 10 008-floor stress parts, the pre-gate violations of the original generator, the alt table) |
| `final_candidate/c7_sim/` | the crystal-rule simulation: `sim/loot_mc.py` (+ `fallback`), `sim/pacing.py`, `results/` (`draft_dump_baseline.json`, `_all45.json`, `_g.json`, `bands_*`, `pacing_*`, `abuse_g.txt`, `life_keep_g.txt`) |
| `final_candidate/build/` | `common.py new_gen.py new_run.py new_loot.py new_v2.py amend.py make.py key_owners.py make_addendum.py` and `doc/*.md`: the builder of `packages.json` and of this document (every edit of a track package is an asserted substitution) |
| `design_generator.md`, `generator/` | track A: algorithm, tables, prototype, 10 008-floor results, mutants, gallery |
| `design_loot.md`, `loot/` | track B: rarity categories, Lua / CSV drafts, Monte Carlo and every result file |
| `design_experience.md`, `experience/sim/` | track C: combat model, tables A-E, boss sweep, ablations |
| `design_v2.md`, `v2_proto/`, `v2_scripts/` | track D: cast, city, forest look; prototypes and ownership scripts |
| `analysis/` | the four analysts' reports and data (`loot_economy.md`, `plan_forest.md`, `spike_forest.md`, `v2_environment.md`, `v2_characters.md`) |
| `docs/design/PLAN_2D.md`, `PLAN_2D_FEATURES.md`, `features_workpackages.json` | the base plan and the feature addendum |
| repo facts read at `2f6410b` | `scripts/world2d/world_2d.gd:117-150, 472, 600-700`, `scripts/autoload/{game_manager,economy_manager,save_manager,event_bus}.gd`, `tests/sections/{data,economy,content_features}.gd`, `lua/config/{race_perks,game_balance,npcs}.lua`, `localization/*.csv`, `tools/loc/key_owners.json` |

Clones used by the editors: `impl/clones/d2-final-gen` (generator verification, deleted), and for the final pass `impl/clones/editor-gen` and `editor-probe` (deleted at the end); no file of the repo or the lift was edited.


## 17. Open questions (only the user can answer; the default in brackets is what is built unless told otherwise)

1. **Pace.** With the dungeon the typical player reaches the castle on day **246 instead of 337 (-27 %)** if the furniture the dungeon hands out replaces nothing the player buys, and on day **201 (-40 %)** if it replaces the furniture spending of the plan (casual 718 / 591 instead of 912, dedicated 132 / 101 instead of 184); in real hours (9-minute farm days + dungeon minutes) 49.4 / 40.4 h against the plan's 50.5 h. This is the corrected figure: the first quote (263 days, -22 %) left the substitution out (5.9). The dials in the data reach at most -35 % (furniture and clothing kind weights x 0.5: typical day 219); nothing short of giving up free furniture, which is your own request, reaches the -27 %. Is "the dark forest is the main adventure" worth -40 %, or should the dungeon give fewer common pieces (-35 %)? [as designed: -40 %]
2. **Power fantasy.** A legendary weapon ends the three bosses in 2 / 4-5 / 6-7 swings (1.3-2.4 x the combat curve). Keep that, or keep the best weapons close to the curve and make them about effects? [keep]
3. **Depth.** Stop at floor 12 (three bosses, about 30 minutes for a complete dive) or continue with an endless tail (needs weapons above 57 damage, a longer curve and its own daily value cap)? [12]
4. **Weapon in hand.** Show the equipped weapon on the hero (a new layer in every hero bake, a large art job) or is the rarity-tinted swing arc enough? [arc]
5. **Fishing at the Moon pond** (the sketch's "Fiskeri om natten"): open it (a `fishing_spot`, fish items, a rod) or keep it calm decor with a whisper? [decor]
6. **Runestones across days.** Lit stones stay for ever so you can start at floor 3, 5, ... on any day while the layout is new each day, or reset every day? Measured consequence (2.6): starting at the deepest stone doubles the rare items per hour but a clear-all day still pays four times the gold and 2.3 times the rare items per day, so floors 1-10 stay worth playing. [stay]
7. **Natteblik's map.** A reveal of the minimap of the next floor, consumed from the backpack as an item (`etagekort`, 40 gold)? Only available when you enter at night. [as built]
8. **The 10 % defeat gold** is not capped (about 880 gold for a typical wallet). Keep it uncapped as you wrote it, or cap it? [uncapped]
9. **Skovens hjerte**, +1 heart for the first kill of each of the three bosses (at most +3 hearts): wanted? [yes; `hearts_per_boss = 0` removes it]
10. **The Skovlift** (the rope basket of the city sketch) as the ONE entrance to Mørkeskoven, with no gate on the farm or in Hyggebyen: is that your reading of the sketch? [yes]
11. **Should a dungeon run cost farm clock time** (so a run of 3-5 floors takes about half an in-game day)? [no: the dungeon clock is frozen, a run costs 0 game minutes; a defeat still costs the rest of the day]
12. **Art leftovers.** Rasmus's green scarf and Kiki's banana (a garment design + bakes), the world-sprite outline (the pack's warm one or the sketch's ink one, A/B sheet in V2), an extra sketch of the Hyggebyen district? [bare neck, pack outline, blueprint]
