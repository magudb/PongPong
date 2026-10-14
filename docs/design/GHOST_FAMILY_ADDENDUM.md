# TRÆTOPPEN - Ghost family addendum: Familien Natlys, four friendly ghosts as citizens

Role: DESIGNER (design5). Request (user, 2026-10-14): asked whether other ghosts should live in the towns, the user answered "yes the Family Ghost"; the lead reads it as a family of friendly ghosts living in Trætoppen next to the fox, bat, owl, capybara, fairy and halfling citizens. The user also named the default ghost hero Pedro (so the family reuses no name of Pedro, Hviske, Bu or any NPC). Status: complete design + a REAL art prototype (built, baked through the real pipeline, shown in the real game, looked at, iterated eleven times, then re-shaped, finished and gated after two independent reviews) + a proven data layer (loaded through the real Lua runtime of main, checked by six validators) + work packages. Nothing in the repo, the lift, another agent's folder or the M1a worktree was edited.

Everything lives in `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design5/`: this file, `ghostfamily_packages.json` (packages, amendments, milestones), `proto/` (builder, screenshots, sheets), `sim/` (the routine model and checkers), `data/` (the Lua / JSON / CSV lift material), `loc/` (the Danish copy), `scripts/` (every number's script), `notes/` (raw outputs), `final_edit/` (the scripts and logs of the final edit: the 56 variant bakes, the painted-route probe, the windowed shots, the pristine masters), `review_a/` and `review_b/` (the evidence of the two reviews). All paths below are absolute under that folder unless they start with `lua/`, `scripts/`, `tests/`, `tools/`, `assets/`, `data/` or `docs/` (those are repo paths of main). **Which main:** the design was first written against `14654e1`; main then got the storybook finish (`75c6fd8`), the imagegen-PAINTED roster (`1ab4d2b`, merged as `0be6efd`), painted buildings (`9f651d1`) and painted terrain (`70f4bed`). The art, the gates and the harness were re-run on a fresh clone of main `70f4bed` (`notes/rebuild_final.log`); the roster sheets are byte-identical from `0be6efd` to `70f4bed` (`git diff --stat 0be6efd HEAD -- assets/isometric_characters` is empty) and `9f651d1 .. 70f4bed` touches no file of `assets/isometric_characters`, `lua/`, `tests/` or `scripts/` (only `tools/art/drawn/` and terrain tiles). `scripts/rebuild_clone.sh` rebuilds a fresh clone of main with everything (art bit-identical, every check green) in about 8 minutes (the first bake of a fresh clone is a 55-225 s warm-up, the storybook finish 33-113 s) plus the harness: `notes/rebuild_final.log`, `notes/verify_*.txt`; the finished sheets of three fresh clones are byte-identical (`shasum`).

**What the final edit changed (details and the verdict on every review finding: `CHANGELOG.md`).** Two independent reviews found 21 defects; each was verified against the repo and fixed in place. The ART: main moved while the design was written (`75c6fd8` gave the roster an ink-and-grain finish, then `1ab4d2b` PAINTED all 48 roster sheets with imagegen), so the family gets the storybook finish and is described honestly as closer to, not identical with, the painted roster (9.1, 9.6, 9.9); its distinctness gate is silhouette-first because the night grade makes a colour-only gate meaningless (9.4), which re-shaped Dyne and Silke; the gate tool exists now (`scripts/measure_family.py --check`). The DATA: Gnist keeps the shop on festival days (4.3), his closed branch runs on weekday and hour (7.4), the copy obeys the lint rules (7.2), the gift lines are item-neutral (6.2, 7.3), and the layer lands in ONE merge at the 5b gate with its amendments as fix-rounds of built packages (11).

## 0. Summary

**What the family is.** *Familien Natlys* ("Natlys" = a night light): four sweet ghosts on the rig of Bu and Hviske, the SWEETEST face of the "uhyggelig-sød" dark forest, who moved into the **Gæstehytten** (hut 11 of the city sketch, V3's building `h12`, level F, the one decor hut that "nobody lives in yet") and kept its name: they came as guests and stayed. They are *evening and dawn people*: they sleep from 06:45 to about 16:30, run a lantern shop from 17:00 to 23:00, tell the evening story at the Torvet fire, walk the night watch and put out the last lamp at dawn.

| member | id (NPC = art) | what the player sees | job that matters | look | tier / archetype |
|---|---|---|---|---|---|
| **Mormor Dyne** (grandmother) | `ghostfam_dyne` | round, wide, spectacles, a coral knitted stole, a bun, a ball of coral yarn in her mitten | the evening STORY at the Torvet fire (topics + chat beats), knits for everybody | ivory `FFF4DC` | A, elder, birthday vinter 10 (a Wednesday) |
| **Far Gnist** (father) | `ghostfam_gnist` | the tallest figure of the cast (184 px), a drooping striped nightcap, sleepy eyes | keeps **Natlys' Lygtehus**: oil, tonic, lamps, 17-23, closed Wednesday | mint `CBE8C0` | B, shopkeeper, efteraar 4 |
| **Mor Silke** (mother) | `ghostfam_silke` | a coral bow, a lantern on a chain | the **night watch**: Torvet 18:25, Hyggebyen round 20:05-22:20, the last lamp at dawn | turquoise `A4EFE6` | B, watcher, sommer 19 |
| **Lille Blund** (child, "a nap") | `ghostfam_blund` | small (118 px = 70 % of the pack), a striped scarf, big eyes | hides in a NEW place every evening 18:30-20:30 (hide and seek), falls asleep on the porch at dawn | lemon `FFF3A8` | B, child, foraar 23 |

**Decisions (each with its reason and its evidence).**
1. **Four members, not five** (grandparent, two parents, child): each distinct look costs 9.33 MB of resident texture (measured, section 9) and a slot of the 16-look cap per area; the planned evening peaks stay at 11 (Trætoppen) and 14 (Hyggebyen) *with* the family (sim, section 4.5), so four fit without displacing anybody.
2. **One reused slot, no new building.** Hut 11 (`gaestehytten`) is a decor hut in design3 (`towns_scripts/model.py`: `B("gaestehytten", ..., "decor", interior=False, door_hut=11, note="decor hut: lit window, no door marker (honest: nobody lives there yet)")`). All 14 houses of Hyggebyen are taken, a new building would need map geometry of V4 / P11. The family gets one door, one porch post and one S 7x5 room through data (section 3).
3. **They are not night-only.** A day is 18 game hours = 9 real minutes (`lua/config/game_balance.lua:76-86`, 2 game minutes per real second); a family that only existed after 20:00 (`night_start_hour`) would be on screen for 2 of the 9 real minutes of the player's day (4 game hours at 2 game minutes per real second). They wake at 16:20-17:15 (before the glow ramp 17:30-19:30, `lua/config/ambient.lua:82-89`), and the **dawn** (06:00-06:55) is their second appearance: all four are outdoors together at 06:00 on the porch, the bench and the lamp.
4. **The coral thread.** Every member wears ONE piece of coral wool `EF8D7C` that Mormor knitted (shawl, cap, bow, scarf): the family signature that ties four different bodies (four different hues, sizes and shapes) into one family.
5. **Hero-twin rule: no consequence.** The four share only the RIG with the ghost heroes; none shares a look. All eight heroes meet all four (`NpcDirector.is_absent` stays false). Distinctness from Pedro (pale blue) and Hviske (pale lilac-pink) is a MEASURED gate that does not rest on colour: the family is out 17:15-24:00 and 06:00-06:55 under the CanvasModulate grade of `lua/config/ambient.lua`, which multiplies every sprite and pulls every pair of the six ghosts down to 2.8-8.6 CIEDE2000, so the gate is the silhouette: IoU of idle S and SE <= 0.80 for every pair (all eight directions <= 0.85), colour only as the fallback of a pair that fails the shape test (section 9.4). The first draft's gate (baked colour >= 12 OR IoU <= 0.80) was met on paper and failed at night (Dyne, Pedro and Hviske one orange at 19:00, Pedro, Hviske and Silke one blue-violet at 22:00); Dyne and Silke were re-shaped for it: Pedro - Dyne .77 / .76, Pedro - Silke .79 / .74, the closest pair Gnist - Silke .79 / .76.
6. **A ghost player gets their own lines** (race + look: Dyne greets Bu "blue-white, like my grandmother's sheet" and Hviske "pink and gentle, like the first star"; Blund: "you are blue like the sky right after sunset", "pink like the dawn"), in each member's own dialogue module, not through the first-meeting table of G-ghost-lines (section 7.4).
7. **Droppable layer.** The family is a data layer: 2 new packages for M1b (GF-art wave 4, GF-data wave 5b), 3 for M3, 1 for M4; not building them and not merging the 17 amendments leaves G5b unchanged (section 11).
8. **Honest about the clock.** The brief says "06-26" but the repository runs 06:00-24:00 (`game_balance.lua:78-80`: `day_end_hour = 24`, pass-out at 24:00; no "26:00" exists in code or docs); the plans end at 24:00 and wrap to 06:00.
9. **The look: closer to the painted roster, honestly not identical.** Main now paints all 48 roster sheets (imagegen, `1ab4d2b`); a 3D-baked ghost with the storybook finish (contour, grain, flat colour bands, `75c6fd8`) is the closest thing the pipeline makes without the user's imagegen. The painted route is wired and gated (9.9) and is open question 6.
10. **One merge at the 5b gate.** GF-art (wave 4) only installs assets; GF-data and every amendment that touches a shared file (V1, V2, T-towns-core, T-interiors-core, T-routes, S-data, I1) land together at the wave-5b gate as fix-rounds of built packages: no same-wave coupling, no PENDING_CITIZENS rule, no late shop id, no dangling name keys (section 11).

**Evidence that the layer is real** (all re-run by `scripts/rebuild_clone.sh` on a fresh clone of main `70f4bed`: `notes/rebuild_final.log`): the art through the real pipeline and the storybook finish for the six ghosts, `measure_family.py --check` exit 0 (heights, outline, pivot and feet on every frame, palette, silhouette distinctness, graded colour, finish: `notes/measure_family_final.txt`); the data through the REAL `LuaRuntime` of main in a clone (shop, 4 npc rows, 72 dialogue contexts driven by weekday and hour: `notes/gf_probe.json`, asserted by `scripts/check_probe.py`); the routines read back by the real parser equal the sim's plans (`notes/verify_routines_lua.txt`: 4 citizens, 90 blocks including the `fest` plans, 0 mismatches) and the festival-day keeper table (`notes/check_family_final.txt`); `csv_lint` PASS on the clone (14 files, 1,663 keys, 0 errors, 0 warnings; its 5 "legacy issues" are main's own, tolerated until P26); the built harness on the clone with the family applied: `economy` 296 checks 0 failed, `loc` 114 / 0, `characters` 108 / 0, `content_features` 141 / 0, **`art_characters` 27 / 0 WITH the four ids in its roster** (the AGF2 literals, `scripts/agf2_patch_clone.py`: 40 ids, the three adults inside the height gate; WITHOUT that edit the section never looks at the family: it counts 36 ids and 21 people-sized figures), `data` 16 failures that are exactly V1's and P10's pending edits (section 8.7); the social validator SV1-SV14 with 34 citizens: 0 errors; ownership proof A-G plus E2 (lift destinations): 0 problems, the unmutated control passes and 7 of 7 mutants are rejected (8 of 8 as expected).

**What only the user can decide:** section 13 (names, the clock, whether a ghost player is related to the family, a reward for hide and seek, festival attendance, and the look: finished 3D or painted with the user's imagegen).

## 1. Method and where the numbers come from

* **Reading.** `docs/design/TOWNS_FARM_SOCIAL_ADDENDUM.md` (sections 4.1 buildings, 4.7 roster, 4.8 routine format, 4.9 engine, 5 social, 7 copy / art / memory), `DUNGEON_V2_ADDENDUM.md` 7 (cast, city), `GHOST_ADDENDUM.md` / `design4/FINAL/DESIGN_GHOST.md` (the rig and the art recipe), `GHOST_OPEN_QUESTIONS.md` (GQ4: "yes the Family Ghost"), the work orders `impl/orders/{V1,V2,T-towns-core,T-routes,T-interiors-core,T-ext-content,S-data,S-talk,S-fest-content,G-ghost-art,G-ghost-lines,I1}.md`, `impl/owners.json`, and the style sketches `docs/Trætoppen Style Guide Review/refs/{figurer_v2,miljoer_v2}_render.png` (looked at: the city sketch shows the round huts on the platforms; the family's hut is the smallest wall class on the lowest left platform, `sim/city_sketch.json` hut 11).
* **Prototype art.** A clone of main (`TT_REPO=... impl/tools/clone_run.sh ghostfam-d5`), the lifted ghost builder `proto/builder/ghost_model_proto.py` (design4's, verbatim), the new `proto/builder/family_model.py` + shim `traetoppen_additions.py`, run through `tools/art/produce_all.sh --only=characters <id>` with the builder dir first on `PYTHONPATH` (the caller's PYTHONPATH wins, `produce_all.sh` header), imported with `godot --headless --import`, shot in a real window through `impl/tools/windowed.sh` (one window at a time), and LOOKED at.
* **Final edit.** A second clone of main (`ghostfam-d5-final`, made when main was at `0be6efd`: its roster is byte-identical to `70f4bed`) for the shots, one for the first rebuild (`ghostfam-d5-verify`, main `9f651d1`) and a fresh one for the last rebuild (`ghostfam-d5-v3`, main `70f4bed`); `final_edit/` holds the scripts and logs of the final edit (the 56 variant bakes and their gates, the painted-route probe, the windowed shots against the painted roster), `scripts/produce_family.sh` is the art recipe as ONE script (build, bake, finish, import, gates), `scripts/measure_family.py` the gates as ONE program with an exit code. All clones are deleted at the end.
* **Routines.** design3's own authoring model (`design3/towns_scripts/{model,plans,sim,gen_lua}.py` + its baked route table `routes.json`, copied UNCHANGED to `sim/`) extended in `sim/family_data.py`; my checker `sim/check_family.py` reproduces design3's published peaks (**Hyggebyen 14 on Tuesday 17:10, Trætoppen 11 on Monday 17:10**, towns addendum 4.8: "worst Hyggebyen 14 on Tuesday 17:10, Trætoppen 11 on Monday 17:10") before it adds the family, so its counting is comparable. The Lua files are GENERATED from the same tables and read back by the real parser.
* **Social / economy.** design3's social dump of the 30 citizens + the family's rows parsed by the real `LuaParser`, run through design3's own validator `validate_social.py` (SV1-SV14); prices from design3's `item_catalog.json` (parsed from `lua/items/*.lua` of main), recipes from `lua/recipes/*.lua`.
* **What is estimated.** Only the walking distances of the NEW door / porch / room (section 4.6: sketch distance x 6.3 ground px through `f_bench`) and the heart-event / quest numbers of M3. Everything else is measured or read.

## 2. The cast

### 2.1 The family, the ages, the names

Family tree: **Mormor Dyne** (the grandmother, "Mormor" = mother's mother) is **Mor Silke's** mother; **Far Gnist** married in; **Lille Blund** is their child. Ghosts do not count their age: Dyne says "I am over two hundred years old, but I do not count. Only the stitches count." (`SOC_GHOSTFAM_DYNE_CHAT_2_1_V`). Names follow the world's style (Hyldeblomst and Bøgeknop are nature words): Dyne = *dyne* (duvet), Gnist = *gnist* (spark), Silke = *silke* (silk, also a real Danish name), Blund = *blund* (a nap: the child who can never nap at night), family Natlys = *natlys* (a nightlight). None of them collides with an existing name (checked against `lua/config/npcs.lua`, the 30-citizen roster of towns 4.7, the eight hero names, and the key owners).

| | Mormor Dyne | Far Gnist | Mor Silke | Lille Blund |
|---|---|---|---|---|
| personality | warm, a little scatterbrained (her glasses are never where she put them), tells everything as a story | sleepy but always awake for a customer, practical, quietly funny | calm, watchful, never hurried, says little and means it | curious, afraid of being alone in the dark, a bad scarer ("I sound like a cat sneezing") |
| signature line (CSV rows) | "Aftenen er lige begyndt." (`SOC_GHOSTFAM_DYNE_GREET_H0_1_V`) | "Olie, lys og mod!" (`SOC_GHOSTFAM_GNIST_BARK_1`) | "Hold dig i lyset." (`SOC_GHOSTFAM_SILKE_BARK_2`) | "Du fandt mig! Sig det ikke til de andre." (`SOC_GHOSTFAM_BLUND_FIRST_1_V` / `DLG_GHOSTFAM_BLUND_GREET_1`) |
| voice (`npcs.lua`) | 0.86 / 0.82 | 1.08 / 1.02 | 0.93 / 0.94 | 1.34 / 1.10 (pitch / rate, `data/lua/config/ghostfam_npcs_rows.lua.txt`: each INSIDE its archetype preset, elder 0.84 / 0.82, shopkeeper 1.10 / 1.02, watcher 0.92 / 0.94, child 1.32 / 1.10 with the +-4 % / +-3 % jitter of P24, because the voiced rows are generated from the preset of `citizens.lua`; the first draft's 0.80 / 0.90 for Gnist was 27 % below the shopkeeper preset; a deeper father is one word: archetype `craftsman` 0.74 / 0.88) |
| height (sheet, SE) | 165 px (97 % of the pack mean 169.8) | 184 px (108 %) | 160 px (94 %) | 118 px (70 %) |

### 2.2 What each one does for the player

| member | service | where / when | what the player gets |
|---|---|---|---|
| Far Gnist | **shop** `lantern_house`: lantern oil 25 g (the magic store charges 27.5), health tonic 60 g, two normal lamps a day (70-135 g); BUYS forage at 125 % | the room `int_gaestehytten`, 17:00-23:00, **closed Wednesday**; the sign reads "Gæstehytten - åbent 17-23" | oil in the evening: the magic store sells it 11-19 and is closed on Tuesday; the lantern house covers 19-23 on six days; oil is on sale on every weekday (the UNION of the open hours: Tuesday 6 h, Wednesday 8 h, else 12 h from 11 to 23: `notes/economy_check.txt`; the first draft summed the two shops and said 14 h) |
| Mormor Dyne | **stories** = the social layer's topics and chat beats (tier A: first meeting, 4 greetings by hearts, 4 weather lines, 4 season lines, chat beats at 2 / 4 / 6 / 8 / 10 hearts, 3 topics, 3 barks, bio) | the Torvet fire `t_fire_e` from about 17:40 to 21:50, every evening | lore (why "Gæstehytten"), a heart per week, gift reactions, the first citizen of the cast whose chat beats ARE a story |
| Mor Silke | **the night watch**: she is "Nattevagten" of the curfew whisper "Nattevagten følger dig hjem" (lore, no new mechanism) | at the Torvet ladder from 18:25, in Hyggebyen from 20:05 (round 20:05-22:20), the last lamp `f_lamp` at dawn | a face for the curfew (Q6 of the towns addendum), late-night company, the "Hittegods" quest (M3) |
| Lille Blund | **hide and seek**: a new hiding post per weekday (Mon `g_planter2`, Tue `c_logs`, Thu `a_beds2`, Fri `e_bench`, Sat `g_bench`, Sun `u_terrace`), 18:30-20:30 | on Wednesday no hiding (family evening) | a reason to look around the platforms; "Du fandt mig!" as his evening greeting; a heart per week |

### 2.3 Relation to the player and the hero-twin rule

The family are NEIGHBOURS who like the player; the 10-heart line makes every player a Natlys at heart: "Familien Natlys har en plads til dig, om du så kommer fra skoven eller fra gården." (`SOC_GHOSTFAM_DYNE_CHAT_10_1`). `partner = false` for all four (a family; the marriage track's exclusion list gains them like Bertil / Bodil, Kløvermynte / Birk, Lily and Bamse).

**Hero-twin rule (towns DT9, DT41: a citizen who has the player's own look is absent while the player is that hero).** The eight playable looks are `rasmus kiki kloevermynte birk bertil bodil bu hviske`; their citizen twins are Rasmus, Kiki, Bertil and Bodil. The four family visuals equal none of the eight (`art_ghostfam.no_hero_twin`), so **nobody of the family is ever absent**, for any race, and no row of the twin table changes. The rule's *art* consequence is the distinctness gate against Pedro and Hviske (9.4). The *state* consequence is the numbers: the roster is 34 citizens, of whom still exactly four are hero twins.

**When the player IS a ghost** (the user's own question): every member has a `race == "ghost"` branch in its own dialogue module, plus look branches for Dyne and Blund (`context.hero` = `bu` / `hviske`); the 20 lines are in 7.3. A fox, fairy, bear or hobbit player gets the ordinary lines; none of them mentions the player's race or gender.

### 2.4 Why not more, why not fewer

A fifth member (a baby, "Pjusk") would be 8.93-9.33 MB more per area, a sixth slot of the 16-look cap and another voice preset; three would lose either the child (hide and seek, the cast's one hide-and-seek) or the grandmother (the storyteller, the tier A of the layer). Four is the smallest cast that has one of each age and one job each.

## 3. The home: the Gæstehytten

### 3.1 The slot

The city sketch has 13 huts (`sim/city_sketch.json`, `huts`) plus the Rådhus; design3 gives the huts a function (towns addendum 4.1) and leaves **`gaestehytten`** (kind `decor`, "hut 12" in the addendum's 1-based list, index **11** in the sketch's 0-based `huts`, **V3's building id `h12`**) with a lit window and no door. V3's built data already contains it: `data/traetoppen/traetoppen.json` (read-only, the m1a worktree): `h12` cx 703.8, door (693.8, 1043.7). Position (sketch px, `sim/city_sketch.json`): the lowest left platform `f` (platform 6: cx 588.2, cy 1010, rx 183.7, ry 106.1), the hut at (703.8, 1022.5) with wall_r 36.7 (the smallest class, like huts 1 and 3), the next hut on the platform being Strimmels Musikstue (hut 10, cx 552.8). The platform's two ends are the bridge towards the farm side (762, 1010) and the Hyggebyen gate (404, 1010), so a player who walks the platform from the farm side to Hyggebyen passes the hut and its anchors `f_bench` (640, 1060) and `f_lamp` (633, 953) lie 60-70 sketch px to its left (`sim/model.py` lines 184 and 191). The door is inside the platform ellipse (0.431 < 1), the new porch post at 0.606.

Alternatives rejected: a Hyggebyen house (all 14 are in use); a NEW building (V4's geometry file and P11's map would both change: two packages of the M1a stage that is being built).

### 3.2 What changes in the data (exact)

| where | change | owner / amendment |
|---|---|---|
| `lua/buildings/traetoppen.lua` | the decor row `gaestehytten` is REMOVED (a duplicate id across registry files is a claim error) | T-towns-core, AGF4 |
| `lua/buildings/ghostfam.lua` (new) | `gaestehytten = {area traetoppen, kind shop, name_key BLD_GAESTEHYTTEN, interior int_gaestehytten, size S, shop lantern_house, keeper ghostfam_gnist, post int_gaestehytten.counter, hours {open 17, close 23, closed {2}}, wave core}` | GF-data |
| `data/towns/traetoppen.json` (the city sidecar) | + door `{building gaestehytten, sx 693.8, sy 1043.7, level 6}` (= V3's `h12`), + post `{f_porch, level 6, sx 690, sy 1068, act stand, cap 2}`: inside platform 6 (ellipse value 0.606 < 1, `sim/family_data.py` line 111: `data/data/towns/traetoppen_sidecar_additions.json`); counts: 14 doors, 37 posts, 28 areas | T-routes, AGF6 |
| `data/interiors/core/int_gaestehytten.json` + `data/maps/int_gaestehytten.map` | the room, below | T-interiors-core, AGF5 |
| `localization/towns.csv` | NO change: `BLD_GAESTEHYTTEN` stays "Gæstehytten", so the door sign reads "Gæstehytten - åbent 17-23" (the old name is the family's own story: `GHOSTFAM_FAMILY_LORE`); the shop's own name is `SHOP_LANTERN_HOUSE` = "Natlys' Lygtehus" | none |

If the family is NOT built nothing changes: the decor row stays in `traetoppen.lua`, the hut keeps its lit window and no door.

### 3.3 The room `int_gaestehytten` (S 7x5, the grammar of Uglehulen / Loppeloftet)

Derived from `design3/towns_scripts/proto/interiors/int_uglehulen.json` (the S 7x5 shop-with-a-corner): door (3,4), spawn (3,3), counter band row 2 = hatch cells (0,2) (1,2) (5,2) (6,2) + `table_long_pine` (2,2) 3x1; keeper post `counter` (3,1); the two family corners behind the band, `table` (1,1) and `bed` (5,1), **capacity 4 each** (the whole family dines and sleeps there); customer posts (1,4) (5,3) (5,4); markers: `shop` `lantern_house` keeper `ghostfam_gnist` at (3,3), `talk` at (2,3) and (4,3), `door` to `traetoppen:from_int_gaestehytten`; pieces `bookshelf_oak_narrow`, `clock_owl`, `shelf_birdhouse` (wall), `table_round_pine`, `floor_lamp_glowshroom`, `candelabra_iron` (all pieces exist in `assets/iso_props/furniture/furniture.json`). **Validated with design3's own room validator** (`scripts/room_check.py`, output `notes/room_check.txt`): flood fill with the player's hatch bars and the citizen's free corridor, **0 problems**: the keeper post, the table and the bed are unreachable for the player, the shop host and both talk hosts and every customer post are reachable. Budgets: the smallest room class (<= 130 nodes, <= 12 ms warm, <= 4 lights); R-V6 (interiors hold the keeper + at most 4 other presences): the sim's room peak is 4 family members at once (`notes/check_family_final.txt`: `int_gaestehytten 4`).

The shop panel (S13) opens over the live room like everywhere; E on an end cell talks to Gnist (greeting, hearts, gifts). The keeper stands behind the counter whenever the building is open: `keeper_covers_hours` proven for 17:00-23:00 on all six open weekdays, clear and rain (sim, `notes/check_family_final.txt`, PROBLEMS 0).

## 4. Time: the ghost day, in the routine format of the towns addendum

### 4.1 The clock and the light

`lua/config/game_balance.lua:76-86`: 06:00-24:00 at 2 game minutes per real second (9 real minutes per day), `night_start_hour` 20, `night_end_hour` 5. The glow curve (`lua/config/ambient.lua:82-89`, the farm's curve): 1.0 until 05:30, 0 at 07:00, 0 until 17:30, 1.0 at 19:30. The family's rhythm sits on it:

| time | what | why |
|---|---|---|
| 06:00 | all four are OUTDOORS at their night posts: Gnist + Blund on `f_porch`, Dyne on `f_bench`, Silke at `f_lamp` | the day starts where the plan wrapped: the previous evening's last block (the world sleeps 24:00-06:00 and nothing is simulated) |
| 06:00-06:25 | Silke puts out the last lamp (act `lamp`); Blund SLEEPS on the porch (the `sleep` clip); Dyne knits on the bench | dawn = the glow fades 05:30-07:00 |
| 06:40-06:55 | they go in; "Godnat! Eller godmorgen..." (`DLG_GHOSTFAM_DYNE_DAWN_1`) | the player who crosses at dawn meets them |
| 06:45-16:20..17:00 | asleep inside (not visible; the door is closed by the opening-hours rule, towns addendum 4.5) | ghosts sleep by day |
| 16:20 | Gnist at the table (breakfast), 16:58 at the counter | opens 17:00 |
| 17:15 | Dyne leaves for the Torvet fire (arrives about 17:40) | the evening story |
| 17:55 | Silke is outdoors (she must stand at the Torvet ladder by 18:25; the engine computes the departure) | the watch |
| 18:30-20:30 | Blund hides (6 weekdays) | the evening |
| 19:00-21:45 | **Wednesday: the family evening** - Dyne + Blund at `t_fire_e`, Gnist + Silke at `t_fire_s`, the shop closed | one night a week the whole family is in one place |
| 20:05-22:20 | Silke's Hyggebyen round (`round_s`, `round_e`, `round_n`, `well`) | the other town's night |
| 23:00 | the shop closes (the bell, the player is shown out); Gnist goes to `f_porch` | the closing sequence of towns addendum 4.5 (a whisper 30 minutes before, the bell, the player is shown out); the curfew whisper is 23:30, the walk home 23:45 (DT24) |
| 23:10-24:00 | Silke at `f_lamp`, Blund asleep on the porch, Dyne on the bench | the plan WRAPS to 06:00 |

Weather: **ghosts do not mind the rain.** The rain rule (acts `sit tend play fish` at outdoor posts 08-19 go to the shelter post) never applies because the family uses only the acts `stand lamp sleep patrol` (a ghost floats; there is no seated pose). Dyne's line: "Regn? Åh, det kilder bare."

### 4.2 The plans (the data, `lua/routines/ghostfam/<id>.lua`, kind `registry`)

Times are game hours; `from` = ARRIVE by, no `leave` = leave in time for the next block (the resolver subtracts the baked walk). Posts: `T.` = `traetoppen.`, `H.` = `hyggebyen.`; `home.<post>` = the rooms of `gaestehytten`.

**Far Gnist** (priority 4)

| plan | selected | blocks |
|---|---|---|
| `work` | all days except Wednesday and the festival days | 06:00 `T.f_porch` stand (leave 06:40) -> `home.bed` sleep (leave 16:20) -> `home.table` eat (leave in time) -> **from 16:58 `home.counter` work (leave 23:00)** -> `T.f_porch` stand |
| `family` | Wednesday | 06:00 `T.f_porch` -> bed -> table -> **from 19:00 `T.t_fire_s`** stand (leave 21:45) -> `T.f_porch` |
| `fest` | Hoestfesten, Vinterlysene, Aarsskiftet (NOT Badedagen, NOT Midsommerlanterne: 4.3) | 06:00 `T.f_porch` -> bed (leave 08:30) -> table (leave 09:00) -> `T.f_porch` stand (leave 16:20) -> **from 16:58 `home.counter` work (leave 23:00)** -> `T.f_porch` stand |

**Mormor Dyne** (priority 3): `work`: 06:00 `T.f_bench` stand (leave 06:40) -> bed (leave 16:30) -> table (leave 17:15) -> `T.t_fire_e` stand (leave 21:50) -> `T.f_bench`; `fest`: 06:00 `T.f_bench` -> bed (leave 08:30) -> table (leave 09:00) -> `T.f_bench`. One plan serves every weekday (she is at the fire every evening, Wednesday included).

**Mor Silke** (priority 4): `work`: 06:00 `T.f_lamp` lamp (leave 06:25) -> `T.f_bench` stand (leave 06:45) -> bed (leave 17:00) -> table -> **from 18:25 `T.t_ladder`** stand -> **from 20:05 `H.round_s`** patrol (leave 20:40) -> `H.round_e` patrol (21:15) -> `H.round_n` patrol (21:50) -> `H.well` stand (22:20) -> `T.f_lamp` lamp; `family` (Wednesday): ... table -> from 19:00 `T.t_fire_s` (leave 21:45) -> `T.f_lamp`; `fest` as above with `f_lamp`.

**Lille Blund** (priority 3): `hide_0 .. hide_6` (not 2): 06:00 `T.f_porch` **sleep** (leave 06:45) -> bed (leave 16:40) -> table (leave in time) -> **from 18:30 the hiding post** stand (leave 20:30) -> `T.t_fire_e` stand (leave 22:15) -> `T.f_porch` sleep; `family`: table (leave 17:45) -> `T.t_fire_e` from 17:45; `fest`: ... `T.f_porch` stand.

Selection (`select`, tested in order): the festival ids -> `fest` (all five for Dyne, Silke and Blund; three for Gnist: 4.3); Wednesday -> `family` (Blund: `family`); else `work` (Blund: `hide_<weekday>`). Shelter `home.table`. All four plans WRAP: the first and the last block are the same post. Example of the generated file (the whole file is `data/lua/routines/ghostfam/ghostfam_silke.lua`):

```lua
kind = "registry"
registry = "routines"
routines = {
    ghostfam_silke = {
      home = "gaestehytten", home_area = "traetoppen",
      priority = 4,
      shelter = "home.table",
      plans = {
        work = { blocks = {
          { from = 6, at = "traetoppen.f_lamp", act = "lamp", leave = 6.4167 },
          { at = "traetoppen.f_bench", act = "stand", leave = 6.75 },
          { at = "home.bed", act = "sleep", leave = 17 },
          { at = "home.table", act = "eat" },
          { from = 18.4167, at = "traetoppen.t_ladder", act = "stand" },
          { from = 20.0833, at = "hyggebyen.round_s", act = "patrol", leave = 20.6667 },
          ...
```

### 4.3 Festival days: the alarm clock, and the keeper who must not leave the counter

The festival overlay (`SocialManager.override_for`, towns addendum 4.8) gives a citizen a festival stay only if he is in the world then ("a citizen who is not in the world then (asleep, away, hero twin) skips it"); travel starts one game hour before the window; the keeper of a `stays_open` shop stays at his shop (DT46); a festival closes shops only DURING its window (`closes = all`; Badedagen closes none) unless the shop is listed in `stays_open`. The five Traetoppen festivals start at 10 (Sofus' badedag), 12 (Høstfesten), 15 (Årsskiftet), 16 (Vinterlysene) and 18 (Midsommerlanterne); a family asleep until 16:20-17:15 would be skipped by the four that start before 17:00, so Dyne, Silke and Blund select `fest` on all five (bed until 08:30, breakfast until 09:00, then awake at the night post until the overlay moves them).

**Gnist keeps the shop, and the first draft got this wrong.** His `fest` plan ended on the porch: after 09:07 he stood there until midnight, so the lantern house (open by the hours rule outside a festival window, or all day on a `closes none` festival) stood open and keeperless on four of the five festival days (review B, reproduced with the same model: `final_edit/fest_gap_before_after.py`, `notes/fest_gap_before_after.txt`). The fix is three rules: (1) his `fest` plan ends at the counter (porch until 16:20, counter from 16:58 to 23:00); (2) he is NOT selected on Badedagen (a `closes none` festival: on his ordinary plan he sleeps until 16:20, the overlay skips a sleeper and the shop keeps its keeper); (3) he is not selected on Midsommerlanterne either, where amendment AGF14 lists `lantern_house` in `stays_open` (as at the Moon Fair, where it already was), so the overlay leaves the keeper at his shop. He attends Høstfesten, Vinterlysene and Årsskiftet. `sim/check_family.py` step 3b models the overlay (leave one hour before the window when in the world, stand until the window ends, walk back through the route table, worst case he attends) and prints the game minutes in which the shop is open by the rule and the keeper is away:

| festival | window | closes | keeperless, first draft | keeperless, final |
|---|---|---|---|---|
| Midsommerlanterne (Sun) | 18-23 | all | 60 min | 0 (`stays_open`) |
| Sofus' badedag (Sat) | 10-18 | none | 360 min | 0 (he sleeps, the overlay skips him) |
| Høstfesten (Sun) | 12-20 | all | 180 min | **34 min** (the walk back from the Torvet) |
| Vinterlysene (Sun) | 16-21 | all | 120 min | **34 min** (the walk back) |
| Årsskiftet (Sun) | 15-23 | all | 0 | 0 (the window covers the opening hours) |
| Månemarkedet (Sat, Hyggebyen) | 18-23 | all | 0 | 0 (`stays_open`) |

The residual 34 minutes (17 real seconds; an estimate through `f_bench`; twice a year; only when he attends, about 88 %) are the honest known gap: the shop reopens at the window end while Gnist walks home. The one-line cure is `lantern_house` in the `stays_open` of those two festivals too (AGF14 names it). The first draft's claim "one hour once a year (Badedagen only)" was wrong in both directions: its gap was 1-6 h on four days. `ghostfam_data.festival_keeper_covers_hours` proves the table on the real festival files (it SKIPS loudly while none exists and FAILS if a festival file exists and `midsommerlanterner` or `maanemarkedet` lacks `lantern_house`). The festival-day peak of distinct looks (sim, Saturdays and Sundays only: the festivals fall on Saturday and Sunday): **Trætoppen 10 -> 14, Hyggebyen 14 -> 14** (14 = the planned cap, the hard cap is 16).

### 4.4 The presence table (clear weather, any weekday; `notes/check_family_final.txt`)

| | outdoors in Trætoppen / Hyggebyen | inside (not visible) |
|---|---|---|
| Dyne | 06:00-06:50 and 17:15-24:00 | 06:50-17:15 |
| Gnist | 06:00-06:50 and 23:00-24:00 (Wednesday 18:30-24:00) | 06:50-23:00 (the shop) |
| Silke | 06:00-06:55 and 17:55-24:00 (Wednesday 18:30-) | 06:55-17:55 |
| Blund | 06:00-06:55 and 17:30-24:00 (the start varies 17:30-18:05 with the hiding post's distance) | 06:55-17:30 |

Most family members outdoors together: **4 at 06:00 in Trætoppen**, and 4 on Wednesday evenings from 19:00.

### 4.5 The budgets with the family (the numbers of the towns addendum, measured with the same counting)

`sim/check_family.py`: 5-minute steps, 7 weekdays x clear / rain x hearts 0 / 5; the distinct looks per area (stay + the area a walker is in at that minute, path-aware):

| | without the family (30) | with the family (34) |
|---|---|---|
| peak distinct looks, Hyggebyen | **14** (Tuesday 17:10) | **14** (Tuesday 17:10) |
| peak distinct looks, Trætoppen | **11** (Monday 17:10) | **11** (Monday 17:10) |
| Trætoppen by half hour (max over all days) 17:30 / 18:00 / 21:00 / 23:00 | 8 / 7 / 8 / 1 | 10 / 10 / 11 / 5 |
| Hyggebyen 19:30 / 20:00 / 20:30 / 21:30 | 9 / 8 / 7 / 0 | 9 / 9 / 8 / 1 |
| room `int_gaestehytten` | - | 4 |
| festival Saturday / Sunday: Trætoppen / Hyggebyen | 10 / 14 | 14 / 14 |

`towns.plan_visual_peak` is 14 and `max_live_visuals` 16: the family fits under the planned cap on every day and it does not raise the existing peaks (they fall at 17:10 when the family is still inside). Post capacities are checked in the same run (the family uses `t_fire_e` / `t_fire_s`, `round_s/e/n`, `well`, `t_ladder`, the bench, the lamp post and the new porch post of cap 2; `PROBLEMS 0`). The sim reports 4 infeasible legs in design3's own base plans (`design3 base: infeasible legs reported by the sim: 4`, computed WITHOUT the family, line 8 of `notes/check_family_final.txt`), so none of them is a family leg.

### 4.6 What is estimated, and how wrong it may be

The route table of design3 (`routes.json`, baked on the prototype city) has no anchor for the new door / porch / room. `sim/family_data.py::extended_routes` adds them conservatively: `d(new, X) = d(new, f_bench) + d(f_bench, X)` with `d(new, f_bench)` = sketch distance x 6.3 ground px (the mean of the two measured same-level pairs `door_musikstuen`-`f_bench` 736 px / 127 sketch px and `door_musikstuen`-`f_lamp` 640 / 93), and the room as a mirror of `int_uglehulen`'s matrix. **Robustness (measured, `sim/robustness.py`):** all 4 citizens x 7 weekdays x clear / rain x hearts 0 / 5 stay feasible while the real walks are up to **1.6 times** the estimate (1.7: the first problem, Blund's longest leg). Wherever the next block has an arrive-by hour the plan carries no `leave`, so the engine computes the departure from the baked walk and a longer walk only means an earlier departure. The lead's re-bake (sanctioned edit E3, T-routes' `tools/towns/bake_routes.sh`, `impl/orders/T-routes.md`) replaces the estimates; the validator `towns_routes.table_fresh` fails loudly on a stale table.

## 5. Services, economy, sources and sinks

### 5.1 Natlys' Lygtehus (shop id `lantern_house`, `lua/shops/lantern_house.lua`, loaded by the real runtime)

```lua
lantern_house = { name_key = "SHOP_LANTERN_HOUSE", keeper = "ghostfam_gnist", greeting_key = "SHOP_LANTERN_HOUSE_GREETING",
  buy_multiplier = 1.0, sell_multiplier = 1.25, buys = { "forage" },
  tabs = { { id = "dark", categories = { "consumable" } }, { id = "light", furniture_types = { "lamp" } } },
  stock = { lantern_oil = { stock = 30, restock = 30 }, health_tonic = { stock = 8, restock = 4 } },
  rotation = { { id = "dagens_lys", period = 1, pick = 2, qty = 2, rarity = "normal", price_mult = 1.0,
                 pool = { "floor_lamp_birch", "floor_lamp_iron", "candelabra_iron", "sconce_iron", "table_lamp_clay", "chandelier_iron" } } } }
```

* **No new item id, no new icon.** Prices are the items' own (`lua/items/consumables.lua:22-32`: oil buy 25 / sell 8, tonic 60 / 20; lamps 70-135 / 25-50).
* **Sink / source.** A gold SINK for oil (25 g a bottle = 60 s of light, `race_perks.lua:81`) and lamps; a tiny SOURCE: forage sold at 125 % (`economy_check.py`: +0.25 fern .. +8.75 rare_mushroom per unit; one of each +23.00 gold). The ghost player's perk (`oil_use_mult 0.75`, `docs/design/GHOST_ADDENDUM.md:97`: a fill lasts 200 s instead of 150 s; a full dive saves about 72 gold, 4.9 %, `GHOST_ADDENDUM.md:123`) makes the oil shop a small matter to a ghost: Gnist says so ("Du sparer olie, har jeg hørt. Det er næsten uhøfligt over for en lygtemager.").
* **No loop.** Every stocked item sells for less than it costs (loop gain -17 .. -85); no recipe of `lua/recipes/*.lua` uses a stocked item (0 recipes). NOT stocked on purpose: **glow_mushroom** (a shop price of 20 g x 7 + ore would craft a `mushroom_lantern` that sells for 300: `lua/recipes/guide_recipes.lua`) and **lantern_post** (a placed post is a `PointLight2D` of radius 330, `lua/config/props.lua:67`; the shop file's own comment names the light budget as the reason).
* **Availability.** Magic store 11-19 closed Tuesday; lantern house 17-23 closed Wednesday: oil is on sale every weekday (the union of the open hours: 6 h Tuesday, 8 h Wednesday, 12 h otherwise). Wednesday evening has none: the family evening.

### 5.2 Mormor Dyne, Mor Silke, Lille Blund (no money, only hearts)

The social layer (S-talk) gives them: a weekly heart for the first FINISHED conversation of a week (DF3), gifts by taste (40 / 20 / 8 / 0 / 0, birthday x4), topics that reveal a loved item at 2 / 5 / 8 hearts. M3 adds quests (section 6.4): the numbers there are first drafts and are small against the economy (a typical full dive pays 1471 gold, `docs/design/GHOST_ADDENDUM.md:123`).

## 6. The social layer

### 6.1 Tier, archetype, birthday (S-data rows, `data/lua/social/ghostfam_citizens_rows.lua.txt`)

| id | tier | archetype | birthday | weekday | partner |
|---|---|---|---|---|---|
| `ghostfam_dyne` | A (the 11th Hjertefolk) | elder | vinter 10 (day 94) | Wednesday = the family evening | false |
| `ghostfam_gnist` | B | shopkeeper | efteraar 4 (day 60) | Thursday | false |
| `ghostfam_silke` | B | watcher | sommer 19 (day 47) | Friday | false |
| `ghostfam_blund` | B | child | foraar 23 (day 23) | Tuesday | false |

The planner's rules (never on or next to a festival day, at least 2 days from every other birthday) are satisfied: the validator reports 0 errors with 34 birthdays, festival days [7, 21, 42, 55, 70, 83, 91, 105, 112], min gap 2 days, per season vinter 7 / efteraar 9 / sommer 9 / foraar 9, per weekday Monday..Sunday 5 / 5 / 6 / 6 / 5 / 4 / 3 (`notes/social_validate_family.txt` lines 2-3). Blund's foraar 23 is exactly two days after Honningdagen (foraar 21): allowed, not adjacent.

### 6.2 Gifts (S-data format, existing items only; `data/lua/social/ghostfam_gift_tastes_rows.lua.txt`)

| | love (40 points) | like (20) | dislike (0) | archetype row under it |
|---|---|---|---|---|
| **Dyne** | wool, fabric_wool, honey_cake, shirt_knit_cream | honey, milk, ftype:rug, curtain_natural, lantern_oil, slot:hat | category:crop | elder |
| **Gnist** | glow_mushroom, night_bloom, glow_berry, floor_lamp_birch | lantern_oil, ftype:lamp, moss, category:forage | sunflower | shopkeeper |
| **Silke** | lantern_oil, glow_mushroom, honey, moonflower | slot:shoes, apple, ftype:lamp, rope | sunflower | watcher |
| **Blund** | cookie, glow_mushroom, honey_cake, bracelet_string | wild_flower, apple, slot:hat, night_bloom | health_tonic | child |

Resolution is "NPC row > archetype row > universal" (towns addendum 5.1), so Dyne's `like lantern_oil` overrides the elder archetype's `hate lantern_oil` (a family that lives over a lantern shop; design3's elders hate lantern oil, e.g. `cat_morfar_mis`, `design3/social_proto/lua/social/gift_tastes.lua:97`). Every id and selector in the table is checked against the item catalog by the validator (SV5 / SV6 syntax, SV7 at least 3 giftable loved items per citizen).

`validate_social.py --stats` with 34 citizens: **0 errors** (22 warnings = design3's own unauthored festival scenes, SV9). Per member over the 278 giftable items (`notes/social_validate_family.txt` lines 25-28): love 9 / 7 / 5 / 5 (3.2 / 2.5 / 1.8 / 1.8 %), dislike + hate 15 / 9 / 15 / 23 (5.4 / 3.2 / 5.4 / 8.3 %). The S-data order (`impl/orders/S-data.md`, item 2, test `social_data.taste_distribution_sane`) caps love at 8 % and dislike + hate at 12 % of the 278 giftable items per citizen: the family's maxima are 3.2 % and 8.3 %. For comparison the 30 existing citizens in the same file have love 3-22 items and dislike + hate 8-29 items (Natteblik 29, Bamse and Lily 23, like Blund), so the family sits inside the existing range. Cheapest loved item: glow_mushroom (8 gold) for Gnist, Silke and Blund, fabric_wool for Dyne: a cheap gift pleases. Each gift reaction line is a CSV row (5 classes x 4 members = 20 rows, 7.3). **The cascade is per CLASS** (`GIFT_<NPC>_<CLASS>_<n>` -> `SOC_ARCH_<ARCH>_GIFT_<CLASS>_<n>` -> `SOC_ANY_GIFT_<CLASS>_<n>`, towns addendum 5.2): one line is shown for EVERY item of the class (the toast names the item), so a reaction line names no item and points at none with a pronoun. The first draft's "Uld!", "Glødesvamp!", "Honning!", "En småkage!" and "Solsikker er ikke min slags blomst" would have been said to a honey cake, a floor lamp, a lantern oil bottle; "Glødesvamp" is not even the item's name (`ITEM_GLOW_MUSHROOM` = "Lysende svamp"). The copy gate G1 (`scripts/gen_family_copy.py`) rejects an item word or a `den / det` pronoun in a `GIFT_GHOSTFAM_` row; item-specific wit would need item-keyed rows in the cascade design, not a class row.

### 6.3 Hearts and the chat ladder (lean, in M1b)

Tier A Dyne: first meeting (voiced), 4 greetings by hearts band H0-H3 (voiced headlines), a MORGEN greeting, 4 weather lines (regn, taage, sne, torden), 4 season lines, chat beats at 2 / 4 / 6 / 8 / 10 hearts (the story of the family: 2 age, 4 the family, 6 why Gæstehytten, 8 "du lyser, når du kommer", 10 "en plads til dig"), 3 topics (the first yarn, the family, the night), 3 barks, a bio. Tier B (Gnist, Silke, Blund): first meeting (voiced), greetings H0 and H3, chat beats at 4 and 8, 1 topic, 2 barks, a bio. This is the LEAN coverage of S-data (towns addendum 5.2: first meeting for every citizen, greetings by hearts band, chat beats, topics, barks, bios); the rest falls to the archetype pools. **Heart events** are M3 (6.4).

### 6.4 M3 content: heart events, festival roles, quests (outlines with numbers; droppable)

**Heart events** (`GF-events`, 10 scenes in `lua/events/ghostfam/**`, player-initiated like all heart events: a rose-heart bubble + the choice "Hvad har du på hjerte?", rewards <= 100 points, items <= normal):

| scene | hearts | what happens |
|---|---|---|
| Dyne *Det første garn* | 4 | she knits the player's colour into the yarn ball: the ball in her mitten turns |
| Dyne *Familiebilledet* | 6 | a lantern-lit portrait of the four at the Torvet fire; the player stands in it |
| Dyne *Den lange aften* | 8 | the story of why the Gæstehytten is still called the guest hut |
| Dyne *Pladsen ved bålet* | 10 | a seat is kept for the player (flag `natlys_seat`, +100 points) |
| Gnist *Lanternen over døren* | 4 | the player smiles at the never-sold lantern and it glows; 3 lantern_oil |
| Gnist *Sidste kunde* | 8 | he closes the shop on purpose to talk |
| Silke *Runden* | 4 | the player walks the Torvet round with her at 20:00 |
| Silke *Det sidste lys* | 8 | at dawn she lets the player put out the last lamp |
| Blund *Find mig!* | 4 | a counted hide and seek of three posts |
| Blund *Bu* | 8 | he practises saying "boo"; a ghost player is asked to help (race branch) |

**Festival roles** (the five Traetoppen festivals; attendance by the DT46 rule (home area = the festival's area) and the `fest` plan; the lines are `FEST_<ID>_GHOSTFAM_<NAME>` rows, 20 of them, written by AGF14 in `festivals.csv`, so none of this wording exists in `ghostfamily.csv` yet):

| festival | spot / window | role of the family |
|---|---|---|
| Midsommerlanterne (sommer 14, Sun 18-23, host Hoppe) | Torvet | the light bringers: Silke leads the lantern walk, Dyne tells the supper story, Blund hides the lanterns; Gnist keeps the lantern house open (`stays_open`, AGF14) and hands the lanterns out from his counter |
| Sofus' badedag (sommer 27, Sat 10-18) | the bathhouse | Dyne, Silke and Blund come yawning (the `fest` plan); Gnist sleeps until the evening and opens the shop at 17:00; ghosts never get wet, but they feel the warmth |
| Høstfesten (efteraar 14, Sun 12-20, host the mayor) | Torvet | Blund guards the pumpkin contest (and swears not to peek) |
| Vinterlysene (vinter 7, Sun 16-21, host Lily) | Torvet | the light procession: Silke at the head, Blund with a lantern; Gnist closes the shop (the festival closes it) to hand out light |
| Årsskiftet (vinter 28, Sun 15-23, host the king) | the Rådhus | the lantern release; Dyne's topic "Natten er ikke en fjende" (`SOC_GHOSTFAM_DYNE_TOPIC_3`) continues there |
| Månemarkedet (efteraar 27, Sat 18-23, Hyggebyen) | not attended (Hyggebyen has 16 home citizens, which fills the cap of 15 + the host, and the family's home area is Trætoppen) | the lantern house is in `stays_open` (as at Midsommerlanterne): Gnist behind the counter on the night market |

Trætoppen now has 14 + 4 = 18 home citizens against the cap of 15 + the host (DT46): at a Trætoppen festival each member attends with probability about 88 % (15 of at most 17 non-host candidates by the SocialRng order; my arithmetic, not simulated); Gnist attends three of the five - open question 5.

**Quests** (`GF-quests`, `lua/quests/ghostfam_*.lua`, first drafts): `ghostfam_garn` (Dyne, hearts >= 2): 3 wool -> a `shirt_knit_cream` + a heart; `ghostfam_lygtemager` (Gnist, hearts >= 3): 3 glow_mushroom + 1 night_bloom -> 120 gold + 3 lantern_oil (120 + 3 x 25 = 195 gold of value against 3 x 8 + 18 = 42 gold of forage at the sell prices of `notes/economy_check.txt`); `ghostfam_hittegods` (Silke, hearts >= 4, repeatable weekly): a lost item of a named citizen (apple -> Oak, cookie -> Pippin, wild_flower -> Lily, rope -> Brumme, honey -> Sofus, moss -> Fru Ugle; never one of the four hero twins rasmus, kiki, bertil, bodil, who are absent while the player is that hero: the first draft named Kiki, who cannot be met and cannot pay the heart; the offer also filters every owner through `NpcDirector.is_absent`) from her lantern basket -> 60 gold + a heart with the owner; at most 16 weeks x 60 = 960 gold a year, below one dive; never a rare or unique item.

## 7. Copy: tone, key families, sample lines of Danish

### 7.1 Tone

The guide's register "Venlig og lun": short, concrete, warm, one joke at most, du-form; nothing scary: **the tone gate has NO allow-list entry** (not one banned stem `skræm bange uhyggelig frygt gyser forskræk rædsel død dræb mord blod` / `scare frighten afraid creepy terrif horror spooky dead death kill blood` in either language; the gate is design4's `tone_check.py` list, coded as `BANNED_DA` / `BANNED_EN` in `scripts/gen_family_copy.py`, without any exception). Ghosts are "the ones who light the dark": Dyne: "Natten er ikke en fjende, den er bare en meget stille nabo." No sentence assumes the player's gender or race (the hero looks are named only by the look: blue, pink).

### 7.2 Files and volume (`data/localization/ghostfamily.csv`, header `keys,da,en`, generated and gated by `scripts/gen_family_copy.py`)

115 rows, **1,527 Danish words**, 10 voiced rows (`_V`: the first meeting of all four, Dyne's greetings H0-H3 and her chat beats 2 and 8: no digits, no `%`, no onomatopoeia, **<= 14 words**, rule C3 of I1's copy lint: the first draft loosened the gate to 24 words and seven rows had 15-22 words; the bark `Ikke kig!` had 2 words against the slot rule 3-5). Native review at the assumed 400 words per hour: 3.8 h. The Danish is written by an AI and has had no native check and no Danish language tool; the two review findings of grammar (`så jeg kan sagtens` -> `så jeg sagtens kan`, `den var så fin` about a `lagen` -> `det var så fint`, `Ikke kig` -> `Kig ikke`, `dele ud af` -> `dele ud`) are fixed, the rest is the review state machine's job. Day-part tags: the family is the one cast met at BOTH dawn and night, so the greetings carry `H0_MORGEN` rows for all four and `H0_NAT` for Dyne (the cascade `SOC_<NPC>_GREET_H<band>_<PART>` beats the plain `H<band>` row): "Godaften" and "i aften" never greet a player at 06:00. Families (all start with a prefix of the key-owners entry SE-GF1, longest prefix wins):

| family | rows | beats |
|---|---|---|
| `NPC_GHOSTFAM_` | 4 | display names (`core.csv`'s `NPC_` loses to the longer prefix) |
| `GHOSTFAM_` | 2 | family name, lore |
| `SHOP_LANTERN_`, `SHOPTAB_LANTERN_` | 4 | shop name, greeting, two tabs |
| `DLG_GHOSTFAM_` | 20 | own dialogue: greetings, dawn, night, closed, early, ghost, ghost look |
| `SOC_GHOSTFAM_<NAME>_...` | 57 | the social cascade (`SOC_<NPC>_<SLOT>[_<TAG>]_<n>[_V]`) |
| `GIFT_GHOSTFAM_<NAME>_<CLASS>_1` | 20 | 4 members x 5 classes |
| `BDAY_GHOSTFAM_<NAME>_GREET_1 / THANKS_1` | 8 | birthdays |

`GHOSTFAM_` does not start with `GHOST_` (ghost.csv): no clash (`check_gf_ownership.py` F: 109 keys resolve to their own file, no existing key moves, prefixes unique).

### 7.3 Sample lines (Danish / English; every one is a row of the CSV, `scripts/verify_doc_lines.py` checks them)

| key | da | en |
|---|---|---|
| `SOC_GHOSTFAM_DYNE_FIRST_1_V` | Goddag! Jeg er Dyne og strikker til alle, der fryser. Sæt dig ved bålet. | Hello! I am Dyne and I knit for everyone who feels the cold. Sit by the fire. |
| `SOC_GHOSTFAM_DYNE_GREET_H0_1_V` | Aftenen er lige begyndt. Der er plads ved bålet til en historie. | The evening has just begun. There is room by the fire for a story. |
| `SOC_GHOSTFAM_DYNE_GREET_H3_1_V` | Nu er du næsten familie. Du må gerne kalde mig Mormor. | Now you are almost family. You may call me Granny. |
| `SOC_GHOSTFAM_DYNE_GREET_H0_MORGEN_1` | Solen er oppe igen. Så er det sengetid for os, men sig bare goddag. | The sun is up again. That means bedtime for us, but do say hello. |
| `SOC_GHOSTFAM_DYNE_GREET_H0_NAT_1` | Nu er det sent, men jeg strikker stadig. Der er altid plads på bænken. | It is late now, but I am still knitting. There is always room on the bench. |
| `SOC_GHOSTFAM_DYNE_GREET_WX_REGN_1` | Regn? Åh, det kilder bare. Spøgelser bliver aldrig våde, kan du tro. | Rain? Oh, it only tickles. Ghosts never get wet, you know. |
| `SOC_GHOSTFAM_DYNE_GREET_EFTERAAR_1` | Efterårsaftener er de bedste. Mørket kommer tidligt, og historierne følger med. | Autumn evenings are the best. The dark comes early, and the stories come along. |
| `SOC_GHOSTFAM_DYNE_CHAT_2_1_V` | Jeg er over to hundrede år, men jeg tæller ikke. Kun maskerne tæller. | I am over two hundred years old, but I do not count. Only the stitches count. |
| `SOC_GHOSTFAM_DYNE_CHAT_6_1` | Vi boede i skoven, før vi flyttede ind i Gæstehytten. Der var for mørkt til at strikke, så vi tog lyset med herind. | We lived in the forest before we moved into the Guest Hut. It was too dark to knit there, so we brought our light in here. |
| `SOC_GHOSTFAM_DYNE_TOPIC_1` | Her er historien om det første garn. En dag fandt jeg en tråd af måneskin og strikkede den til en hue. Siden da har ingen i min familie frosset. | Here is the story of the first yarn. One day I found a thread of moonlight and knitted it into a cap. Since then nobody in my family has been cold. |
| `SOC_GHOSTFAM_DYNE_BARK_3` | Hvor var jeg nu? | Where was I now? |
| `DLG_GHOSTFAM_DYNE_GREET_1` | Goddag, kære du! Sæt dig ved bålet. Jeg strikker, mens jeg fortæller, så jeg sagtens kan tale med dig imens. | Good day, dear! Sit by the fire. I knit while I tell stories, so I can easily talk to you at the same time. |
| `DLG_GHOSTFAM_DYNE_NIGHT_1` | Bålet er brændt ned, men bænken er varm. Sæt dig lidt, så fortæller jeg en kort en. | The fire has burnt down, but the bench is warm. Sit a while, and I will tell you a short one. |
| `DLG_GHOSTFAM_DYNE_GHOST_1` | Et nyt spøgelse i byen! Så er vi fem, der svæver rundt her. Kom og sæt dig ved bålet, barn. | A new ghost in town! Now there are five of us floating about. Come and sit by the fire, child. |
| `DLG_GHOSTFAM_DYNE_GHOST_BU_1` | Så lys og blåhvid. Du minder mig om min bedstemors lagen. Det var også så fint om aftenen. | So pale and blue-white. You remind me of my grandmother's sheet. It looked lovely in the evening too. |
| `DLG_GHOSTFAM_DYNE_GHOST_HVISKE_1` | Så lyserød og blid. Du må være lidt genert, ligesom nattens første stjerne. Det klæder dig. | So pink and gentle. You must be a little shy, like the first star of the night. It suits you. |
| `SOC_GHOSTFAM_GNIST_FIRST_1_V` | Goddag! Jeg er Gnist, lygtemageren. Skal du ud i mørket, så kig forbi. | Hello! I am Gnist, the lantern maker. If you are going into the dark, drop by. |
| `DLG_GHOSTFAM_GNIST_GREET_1` | Natlys' Lygtehus. Olie, lys og gode råd til mørket. Hvad skal det være? | Natlys' Lantern House. Oil, light and good advice for the dark. What will it be? |
| `DLG_GHOSTFAM_GNIST_GHOST_1` | Et spøgelse i lygtehuset! Du sparer olie, har jeg hørt. Det er næsten uhøfligt over for en lygtemager. Men du er velkommen! | A ghost in the lantern house! You save oil, I hear. That is almost rude to a lantern maker. But you are welcome! |
| `DLG_GHOSTFAM_GNIST_CLOSED_1` | Vi har lukket for i dag. Kom igen i morgen aften, så er der varmt på lamperne. | We are closed today. Come back tomorrow evening, the lamps will be warm. |
| `DLG_GHOSTFAM_GNIST_EARLY_1` | Godmorgen, eller godnat. Lygtehuset åbner først i aften klokken sytten. Kom igen, når lamperne er tændt. | Good morning, or good night. The lantern house only opens this evening at five. Come back when the lamps are lit. |
| `SOC_GHOSTFAM_GNIST_GREET_H0_MORGEN_1` | Godmorgen. Eller godnat, jeg er ikke helt sikker. Lygtehuset åbner først i aften. | Good morning. Or good night, I am not quite sure. The lantern house only opens this evening. |
| `SOC_GHOSTFAM_GNIST_CHAT_8_1` | Over døren hænger en lanterne, jeg aldrig har solgt. Den lyser af sig selv, så længe nogen smiler til den. Prøv. | Over the door hangs a lantern I have never sold. It glows by itself as long as someone smiles at it. Try it. |
| `SOC_GHOSTFAM_GNIST_TOPIC_1` | Mørkeskoven er ikke mørk, hvis man har den rigtige lygte. Den er bare nysgerrig. Tag olie med til hver ny etage, så går det fint. | The Dark Forest is not dark if you have the right lantern. It is only curious. Take oil for every new floor and you will be fine. |
| `SOC_GHOSTFAM_SILKE_FIRST_1_V` | Hej. Jeg er Silke, nattevagten. Går du hjem sent, følger jeg dig gerne. | Hello. I am Silke, the night watch. If you walk home late, I will gladly walk with you. |
| `DLG_GHOSTFAM_SILKE_LATE_1` | Det er blevet sent. Skal jeg følge dig hjem, før klokken slår? | It has grown late. Shall I walk you home before the clock strikes? |
| `DLG_GHOSTFAM_SILKE_DAWN_1` | Nu slukker jeg det sidste lys. Se, hvor fint det bliver, når solen overtager. | Now I put out the last light. Look how lovely it gets when the sun takes over. |
| `DLG_GHOSTFAM_SILKE_GHOST_1` | Et spøgelse i vagten! Så skal jeg ikke lyse for to. Vi går sammen, hvis du vil. | A ghost on the watch! Then I do not have to light the way for two. We can walk together, if you like. |
| `SOC_GHOSTFAM_SILKE_GREET_H0_MORGEN_1` | Nu er natten ved at være færdig. Alt er roligt, og solen overtager snart. | The night is nearly done. All is calm, and the sun takes over soon. |
| `SOC_GHOSTFAM_SILKE_CHAT_8_1` | Jeg har gået den samme runde i tusind nætter. Jeg har aldrig set to nætter, der var ens. Det er derfor, jeg bliver ved. | I have walked the same round for a thousand nights. I have never seen two nights alike. That is why I keep going. |
| `SOC_GHOSTFAM_BLUND_FIRST_1_V` | Hov! Du fandt mig! Sig det ikke til de andre. Jeg hedder Blund. | Oh! You found me! Do not tell the others. My name is Blund. |
| `SOC_GHOSTFAM_BLUND_BARK_1` | Kig ikke! Jeg gemmer mig! | Do not look! I am hiding! |
| `DLG_GHOSTFAM_BLUND_GREET_1` | Du fandt mig! Jeg har et nyt sted hver aften, og du er den første, der ser det. | You found me! I have a new place every evening, and you are the first to see it. |
| `DLG_GHOSTFAM_BLUND_DAWN_1` | Zzz... Hvad? Er det morgen? Jeg sov slet ikke. Jeg hvilede bare øjnene. | Zzz... What? Is it morning? I was not asleep at all. I was only resting my eyes. |
| `DLG_GHOSTFAM_BLUND_GHOST_1` | Du er ligesom os! Kan du sige bu? Jeg øver mig, men jeg lyder bare sød. | You are just like us! Can you say boo? I am practising, but I only sound sweet. |
| `DLG_GHOSTFAM_BLUND_GHOST_BU_1` | Du er blå, ligesom himlen lige efter solnedgang! Den er min yndlingsfarve. | You are blue, like the sky right after sunset! It is my favourite colour. |
| `SOC_GHOSTFAM_BLUND_CHAT_8_1` | Jeg øver mig i at sige bu. Mormor siger, jeg lyder som en kat, der nyser. Det er lidt flovt, men jeg øver mig videre. | I am practising saying boo. Granny says I sound like a cat sneezing. It is a little embarrassing, but I keep practising. |

Gift lines (a sample; item-neutral by gate G1, 6.2): `GIFT_GHOSTFAM_DYNE_LOVE_1` "Åh, lige noget til mig! Den bedste gave, jeg kender."; `GIFT_GHOSTFAM_GNIST_LOVE_1` "Lys i mørket, lige noget for en lygtemager! Tak, det varmer helt ind i lygterne."; `GIFT_GHOSTFAM_SILKE_LOVE_1` "Lige hvad jeg skulle bruge efter en lang runde. Tak!"; `GIFT_GHOSTFAM_BLUND_LOVE_1` "Åh, tak, tak! Det er en hemmelighed, at jeg er så glad. Sig det ikke til Mormor."; `GIFT_GHOSTFAM_GNIST_DISLIKE_1` "Hm. Det er ikke lige min slags. Men tak, du er sød."; `GIFT_GHOSTFAM_BLUND_DISLIKE_1` "Øh. Tak. Jeg gemmer gaven rigtig godt." (hate = 0 points, never negative: the world stays cozy).

### 7.4 How the ghost player's lines reach the player, and how Gnist knows that he is closed

NOT through G-ghost-lines' `RaceReactions.apply` (its first-meeting prepend serves the other citizens): each family dialogue module branches on `context.race == "ghost"` itself (and on `context.hero` for the looks), so the reaction is not a one-off: it is the speaker's greeting every time. The real LuaRuntime evaluated every branch for 18 contexts x 4 modules (`notes/gf_probe.json`, asserted by `scripts/check_probe.py`): Dyne with race ghost + hero bu returns `[GHOST_1, GHOST_BU_1]`, hero hviske `[GHOST_1, GHOST_HVISKE_1]`, another ghost look `[GHOST_1]`; `daypart` "morgen" returns the dawn line, "nat" Dyne's bench line (she leaves the fire at 21:50) and Silke's late line. Test `ghostfam_data.no_double_reaction` asserts that `race_reactions.ghost` never lists a family id.

**Gnist's closed / early lines follow weekday and hour, not the shop flag.** The first draft branched on `context.shop_lantern_house == false`. P14's context sets `shop_<id> = true` for every shop that LuaRuntime KNOWS (existence, `impl/orders/P14-npc-dialogue.md` task 2: "so a dialogue can offer a shop button only when the shop exists"), so the field is true or nil and never false; the probe had set it to false by hand. In play Gnist would have said "Hvad skal det være?" and offered "Se varer" on Wednesday (the family evening at the fire), from 23:00 and at dawn, and the shop panel would have refused. Now the module reads `context.weekday` (0 = Monday, S-core) and `context.hour` with the numbers of his own building row: `weekday == 2 or hour >= 23` returns the closed line ("i morgen aften"), `hour < 17` returns the early line ("i aften klokken sytten", the dawn line on the porch), otherwise the greeting and the shop choice; the ghost player gets the same rule after the ghost line. Known limit: a festival closure is not known to the dialogue (the shop panel itself refuses it, P18 / `ShopSystem.is_open`), so on a festival evening the greeting can precede the refusal. The context keys and the `daypart` strings are the S-core contract used by the probe (`proto/gf_probe.gd`); `ghostfam_data.dialogue_branches_run` asserts them against the real constants once S-core exists.

## 8. The formats they plug into

### 8.1 `lua/config/npcs.lua` rows (V1, AGF1; `data/lua/config/ghostfam_npcs_rows.lua.txt`)

```lua
ghostfam_gnist = { name_key = "NPC_GHOSTFAM_GNIST", visual = "ghostfam_gnist", fallback = "rabbit", voice = { pitch = 1.08, rate = 1.02 },
  home_area = "traetoppen", role = "shopkeeper", dialogue = "ghostfam_gnist", wander = { radius = 0, speed = 0 }, facing = "S",
  schedule = "stay", friendship = true, routine = true },
```
Roles are the EXISTING roles `elder shopkeeper guard child` of `tests/sections/data.gd` ROLES (no new role, no change to the role -> archetype table); schedules `stay / stay / patrol / stay` of SCHEDULES; **no `shop_id` on Gnist's row** (the Natteblik rule, `impl/orders/V1-cast-data.md` task 5 and `V10-v2-qa.md:17`: `tests/sections/economy.gd:919` fails a `shop_id` whose shop file is missing in an isolated build; the shop is named by the building row, the room's `shop` marker and his dialogue); no `hover` (the villager clip set has no hover / flight clips; the ghost's `walk` is the glide hook); **`fallback = "rabbit"`** because `data.gd roster_fields` demands that the fallback chain END at one of the 12 pack characters (measured: with `fallback = ghost_bu` the check fails; the ghost skins end the same way: `[ghost_bu_base, ghost_bu, rabbit]`) - never drawn in practice (GF-art is a hard dependency).

### 8.2 Social rows (S-data, AGF7), routines, building, shop, room, sidecar, keys

`citizens`: 4 rows (6.1); `gift_tastes.npcs`: 4 rows (6.2); `routines`: 4 registry files (4.2, 10.0 KB with the `fest` plans); `buildings`: 1 registry file; `shops`: 1 file (1.8 KB); `dialogue`: 4 modules (12.2 KB); the room JSON (2.8 KB) + a 7-line stub map; the sidecar: +1 door +1 post; CSV `ghostfamily.csv` (20.1 KB); key owners: `data/tools/loc/ghostfam_key_owners_additions.json` (sanctioned edit SE-GF1: `ghostfamily.csv` wave 5b; `ghostfamily_quests.csv` and `ghostfamily_events.csv` wave 6). Lua config keys: none new in M1b (`npc_glow` in M3).

### 8.3 Save consequences

**None for the static data** (towns addendum 8.4: "NPC positions, routine slots and the current festival are NOT saved (pure functions of date and data)"; the farm / towns add no save section). The family adds: no new save section, no new world flag, no new autoload, no new input action, no new EventBus signal. The `social` section gains four citizen rows on first contact; derived arithmetic from the section's own worst case (15.9 KB for 30 friends x 12 known tastes, towns 5.1): about +2.1 KB for four more, the towns addendum's measured payload range at the full cast is 2-34 KB against the 60 KB limit (line 637, L13), so 34 + 2.1 = about 36 KB stays under it. A save made WITH the family loads in a build WITHOUT it: unknown NPC ids go to the `orphans` bucket with a `push_warning` (S-core), never an error.

### 8.4 Flags and context

Dialogue context keys used: `race`, `hero` (P14, design4 7.5), `daypart` (S-core `dialogue_context`), `weekday` (0 = Monday) and `hour` (integer: Gnist's closed / early lines); `shop_<id>` is true when the shop EXISTS and never false (P14), so it is NOT used for the closed branch. World flags: only the existing `friend_<npc>` / `friend_last_<npc>` mirrors of SocialManager. M3 adds `natlys_seat` (a flag of the Dyne h10 scene).

### 8.5 Interfaces to the built code

The family needs NO new class in M1b: `Hours`, `Routines`, `NpcDirector`, `TownDirector`, `Door2D`, `ShopCounter`, `SocialTalk`, `GiftRules` already serve any registry entry. The family is the proof of the towns addendum's "Lua-extensible" promise: **four citizens, a shop and a building without a line of GDScript** (GF-play, M3, adds one small script for the glow).

### 8.6 The look cap per area (16) and the VRAM

R-V5: at most 16 distinct live looks per area; planned peak 14 (`towns.plan_visual_peak`). The family's four looks are four of the looks the director can choose among; it keeps exactly the wanted citizens alive "festival crowd first, then priority" (priorities 3 / 4 / 4 / 3). Peaks: 4.5. VRAM per member (`scripts/vram_per_member.py` reads the imported `.ctex`, `notes/vram_per_member.txt`, `notes/vram_comparison.txt`): **9.33 MB warm** (idle talk walk = what R-V4's `warm_clips` keeps for a walker) and **18.67 MB with all six clips**, exactly equal to `cat_morfar_mis` and `bear_guard` measured by the same script (`hobbit_pip` all 11 clips 31.33 MB). The city numbers of DT30 (process VRAM <= 400 MB, city peak 307.9 MB with 16 looks at 8.93 MB each, i.e. a margin of 92 MB) are unchanged: the cap bounds the number of looks, not the family's share.

### 8.7 What the family does to today's main (measured on a clone of main with the family applied)

`tests/run_playtest.sh --character=animal --strict --no-boot --only=data,characters,art_characters,loc,economy,content_features` on a fresh clone of main `70f4bed` (`impl/clones/ghostfam-d5-v3`, `notes/harness_final_sections.log`): **economy 296 checks 0 failed** (the new shop file loads through ShopSystem, every item exists), **loc 114 / 0**, `characters` 108 / 0, `content_features` 141 / 0, and **`art_characters` 27 / 0 with the family inside it**: the section is ROSTER driven (36 ids on main), so it inspects the four folders only once amendment AGF2 adds them; `scripts/agf2_patch_clone.py` applies exactly those literals (4 ids in ROSTER, 3 in PEOPLE, 36 -> 40, 48 -> 52) and the section then reports "40 ids (... villager 10 ...)" and lists ghostfam_dyne 97 %, ghostfam_gnist 108 %, ghostfam_silke 94 % in `figure_heights_match_pack`. The first draft's "art_characters 27 / 0" was run WITHOUT the edit and never looked at the family (review A, reproduced: "36 ids", 21 people-sized figures, none a ghost). **`data` fails 16 checks, all explained by two pending edits that V1 / P10 make for their own rows too** (`data 332 checks, 16 failed, 1 skipped`): (a) `data.roster_ids` pins the 15 stable ids and `AREA_IDS` lacks `traetoppen` (6 failures: `data.roster_ids`, `data.roster_fields` and the four `data.npc ghostfam_*: home_area traetoppen`: V1's amendment territory, the family rows need the same edit as Hoppe's); (b) the Lua kind `registry` is unknown on main (P10's fix-round adds it; 10 failures: `lint_clean`, 5 file lints, the tool exit and summary, `kinds_shops_recipes`, `reload_scripts clears...`) - the same message appears for ANY routine or building file of design3. Nothing else changes.

## 9. Art: the prototype

### 9.1 What was built (the real pipeline, end to end)

`proto/builder/family_model.py` (a module of 377 lines) + the shim `proto/builder/traetoppen_additions.py` + the lifted `ghost_model_proto.py` -> `generator/build_assets.py` (GLB, 17 bones) -> `core/bake_sprite_atlases.py` (VTK, orthographic, 36 degrees, 87.074 px/m, clip set `villager`; header of `core/bake_sprite_atlases.py`) -> `core/validate_new_assets.py` (masters and WebP) -> `export/export_game_assets.py` -> `export/install_assets.py` -> **the storybook finish** (`tools/art/storybook/bake.gd --source=<the pristine copy of exactly these folders> --install`, a windowed GL run under the window lock, ONCE: it repaints RGB with ink contour, paper grain and flat colour bands and touches no alpha pixel) -> `godot --headless --import` (S3TC stubs) -> `measure_family.py --check` (the gates, 9.4) -> a windowed shot at zoom 0.4 / 0.9 / dusk / night. The whole recipe is ONE script, `scripts/produce_family.sh` (lift: `tools/art/ghost_family/produce_family.sh`). **The whole build is deterministic: rebuilt from scratch in three clones the finished sheets of the six ghosts are byte-identical** (one `shasum` over every WebP of `ghost_bu`, `ghost_hviske` and the four members; `notes/rebuild_final.log`).

**Why the finish step exists (review A, defect A1).** The first draft's recipe stopped at `produce_all.sh`. Main's roster at that time had been repainted by `75c6fd8` (`tools/art/README.md`: "warm ink contours, textured painted color and pencil accents"), so smooth CG figures next to it were the odd ones out; reproduced by the reviewer and again here (`proto/style_before_after.png`, rows A and B). A second run of the finish over finished sheets compounds the colour (README), so the recipe stages the PRISTINE export copy first and runs the pass once. Main then replaced the roster by imagegen paintings (`1ab4d2b`): 9.9.
### 9.2 Design: proportions, palettes, accessories

The model is Bu's ghost with four numbers per member (the visible body height under the chin `vis`, the width factor `wide`, the head ellipsoid and a hem lift `hem_dy`) and ONE px-per-unit scale for all four (`scale_fixed = 1.92 / 2.075`, Bu's), so model sizes ARE pixel sizes. Measured on the finished sheets (`scripts/zoom_sizes.py`, `notes/zoom_sizes.txt`; the pack mean is 169.8 px):

| | vis | wide | head (x, y, z) | hem_dy | figure SE (px) / % pack | bbox SE at zoom 0.4 / 0.9 (px) | accessory (modelled into the body) |
|---|---|---|---|---|---|---|---|
| Bu (reference) | .515 | 1.0 | .64 .575 .45 | 0 | 160 / 94 % | 46 x 64 / 103 x 144 | - |
| **Dyne** | **.36** | **1.40** | .72 .58 .50 | **+.12** | 165 / 97 % | 61 x 66 / 138 x 148 | round spectacles with temples, a knitted stole with two tails and bobbles, a bun, a coral yarn ball in the mitten |
| **Gnist** | **.77** | .76 | .58 .54 .42 | 0 | **184 / 108 %** | 44 x 74 / 99 x 166 | a drooping striped nightcap (dome, cream band, two stripe rings, a tip over the cheek, a pompom), sleepy eyes (a heavy lid arc) |
| **Silke** | .68 | **.62** | .64 .60 .47 | -.06 | 160 / 94 % | 42 x 64 / 95 x 144 | a bow (two lobes, knot, tails), a lantern on a chain (brass ring, cap, glowing cage, foot) |
| **Blund** | **.22** | .74 | .56 .48 .43 | -.04 | **118 / 69.5 %** | 38 x 47 / 86 x 106 | a striped scarf (ten alternating arcs, a tail down the front, a flag behind), big eyes (glint x1.25) |

`hem_dy` > 0 lifts the hem, which makes the lowest pixel SMALLER (the feet window 197-216 bounds both signs). Dyne (wide, low, hem raised) and Silke (slim body under a large head) were re-shaped in the final edit so that their SILHOUETTES carry the distinctness gate (9.4); the first draft had Dyne at wide 1.20 / vis .42 / hem +.05 and Silke at wide .84 / vis .64 (IoU .85 / .86 against Pedro: the same outline).

Palettes: a member's sheet colours derive from its body hex and hem accent with the relations of Bu's sheet (light 70 % to white, belly 35 %, sheet_dark 45 % to the hem). The colour gate G4 (the dominant region of the idle S frame within CIEDE2000 <= 6 of the declared body hex) is measured on the unfinished bake AND on the finished sheet that ships (`final_edit/logs/measure_family_unfinished.txt`, `notes/measure_family_final.txt`):

| | body | hem accent | knit / accent | dE00 baked, unfinished | dE00 on the finished sheet |
|---|---|---|---|---|---|
| Dyne | `FFF4DC` ivory | `E3A83C` gold | coral `EF8D7C` / `D6705F`, glasses `D6705F`, bun `F5E7AE` | 1.1 | 3.4 |
| Gnist | `CBE8C0` mint | `7DBF73` | cap coral `EF8D7C`, band `FFF1D0`, pompom `FFF4DA` | 2.3 | 1.1 |
| Silke | `A4EFE6` turquoise | `38B8AE` | bow coral, brass `B8893A`, glass `FFE48C` | 2.0 | 1.6 |
| Blund | `FFF3A8` lemon | `E6B93A` | stripes coral `EF8D7C` / cream `FFF1D6` | 1.4 | 3.6 |
| (Bu / Hviske) | `E6EFFF` / `F6E7F6` | `93BBEE` / `F29DC2` | - | 1.6 / 1.1 | **5.9** / 3.4 |

The finish lifts and warms colour: **Pedro's `E6EFFF` reads 5.9 after it, against the gate 6** (passes by 0.1; G-ghost-art's own palette gate must be measured on the finished sheet, amendment AGF3: widen to 8 or declare `EEF4FF`).
### 9.3 Iteration log (eleven iterations, each rendered and looked at: `proto/it1_rows.png` .. `it9_rows.png`, then the final edit's variant sheets `final_edit/variants_sheet1.png` / `variants_sheet2.png`)

| it | change | verdict (what I saw) |
|---|---|---|
| 1 | first builder: scaled bell profiles, four accessories, derived palettes | reads as a family of ghosts; Gnist 200 px (top at 6 of 256: too tall for the cell), the bun's needles read as ANTENNAE, the peach Silke and mint Blund look alike |
| 2 | body height by `vis` (the visible bell below the chin), Gnist 190, shawl as a ring | Blund had no body (a head with a skirt rim); the shawl read as a SWIM RING |
| 3 | thin shawl with tails, striped cap with a longer droop, palette variants (peach / mango / aqua / sage) | the cap read like a Santa hat (pointing up), peach reads as SKIN, mango as biscuit |
| 4 | sleepy eyes without a lid line (the wide line read as SUNGLASSES), a bigger lantern, hues (lime / lemon / aqua) | lime read olive on grass; Silke aqua + coral bow reads best so far |
| 5 | the family coral knit, new hues (mint Dyne, greige Gnist) | greige read as a dull pebble, mint grandmother as a FROG; the coral was too red |
| 6 | soft coral `EF8D7C`, back to a butter / ivory grandmother, Blund variants (coral = baby doll, white = a small Bu) | the hue plan now works: ivory / mint / turquoise / lemon next to blue-white and lilac-pink |
| 7 | final heights, hem margins | Dyne and Blund outside the feet window in some clips |
| 8 | Dyne hem +.05, Blund -.04 (the gate FIRED: Blund's celebrate frame 196.6; my first fix had the wrong sign: raising the hem makes the lowest pixel SMALLER), a coral yarn ball in Dyne's mitten | knitter reads; yarn ball small |
| 9 | yarn ball radius .165, a taller lantern | both read at zoom 0.9; Silke's silhouette is Bu's (IoU .92) -> she is slimmed (wide .93 -> .84, taller `vis` .58 -> .64, six scallops): IoU .86 / .84, and the palette is nudged for the night grade (turquoise for aqua, sage-lime for mint) |
| 10 | review A measured the night grade (`review_a/logs/07_night_grade_baked.txt`) and the first-draft gate failed it; the gate became silhouette-first (9.4) and Dyne was re-shaped: wide 1.20 -> 1.40, vis .42 -> .36, hem_dy .05 -> .12 (review A's variant `d3`; without the hem raise the lowest pixel left the feet window) | Dyne is now a wide low bell, clearly not Pedro (IoU .77 / .76); the spectacles, stole and bun still read |
| 11 | Silke against the all-eight-directions gate: 56 scratch bakes (`final_edit/variants/traetoppen_additions.py`, `final_edit/search_variant.py`, series f g h sa-so t u; the u series = wide .54 / .58 / .62 x vis .60 / .64 / .68 x two head sizes at hem_dy -.06) -> `u17`: wide .62, vis .68, head (.64, .60, .47), hem_dy -.06. The gate FIRED once more on the way: the first re-shape had its lowest pixel at 193.9 (window 197-216), fixed with hem_dy -.06 (198.4) | a slim figure under a large round head; the bow and the lantern read; IoU Pedro .79 / .74, Gnist .79 / .76 (.82 over eight directions). No variant with a height inside the +-10 % window got below .80 against Gnist in all eight directions: the shape space of one bell rig is crowded |
### 9.4 The cast gates (one program: `scripts/measure_family.py --check`, exit 1 on a failed gate; `notes/measure_family_final.txt`)

The first draft only PRINTED numbers (`measure_family.py` had no `--check`, did not import `measure_cast.py` and crashed on the argument; the gate names in the package were not gates). `measure_family.py` now imports `tools/art/characters/measure_cast.py` for the pack reference, the outline, the pivot and the feet window, and adds what `measure_cast` does not do: it gates NOTHING for a `ghostfam_*` id (measured: Blund at 70 % of the pack prints `ok`, and any height would), so the +-10 % gate on Dyne, Gnist and Silke is applied here. `--selftest` proves the distinctness gate fires on near-identical pairs and accepts distinct ones. Gates, measured on the FINISHED sheets that ship:

* **G1 height** SE 165 / 184 / 160 / 118 px = 97.2 / 108.4 / 94.2 / 69.5 % of the pack mean 169.8 px (bear 170, cat 170, rabbit 170, fox 169, fairy 170; the mean was 167.4 before main drew the roster at one height). The three adults are inside +-10 %; **Gnist's margin is 2.8 px (+8.4 %)**, and was one pixel (+9.92 % against the old mean 167.4) in the first draft: a re-baked pack moves it. Blund is sized by design (a 60-80 % band is checked, like Lily and Bamse).
* **G2 outline** after the finish [78,61,73] [78,61,74] [76,60,73] [78,61,73] = the pack's [75,61,71] within 8 per channel.
* **G3 pivot / feet** x pivot 127.4-127.6; feet line 208.5-214.8 / 199.2-205.9 / 198.4-204.9 / 200.4-206.9 over all 28 frames of the 6 sheets, window 197-216 (**Silke's margin is 1.4 px**); `validate_new_assets.py` OK on masters and WebP, 6 clips each, portraits 256 x 256 not cut. The gate FIRED three times while building (Blund's celebrate frame 196.6, Blund idle f1 196.8 after the wrong-signed first fix, Silke's first re-shape 193.9).
* **G4 palette** dE00 <= 6 on the finished sheets (9.2: 3.4 / 1.1 / 1.6 / 3.6; Pedro 5.9).
* **G5 shape (the distinctness gate, grade independent).** The family is out 17:15-24:00 and 06:00-06:55, under the CanvasModulate grade of `lua/config/ambient.lua`, which MULTIPLIES every sprite. Measured with the real keyframes (both presets, four seasons, clear and rain, nine hours) the colour distance of every pair of the six ghosts falls to **2.8-8.6 dE00** (lowest: Pedro - Dyne 2.8 at 19:00 on an autumn evening, Hviske - Dyne 3.2, Pedro - Silke 3.6, Gnist - Silke 4.1). Review A measured the first draft the same way (`review_a/logs/07_night_grade_baked.txt`): farm 22:00 Hviske - Dyne 4.9, Pedro - Dyne 5.6, Pedro - Silke 6.4, Hviske - Silke 8.4; 19:00 Pedro - Dyne 6.4; 20:30 Pedro - Silke 10.6; Hyggebyen 06:00 Hviske - Dyne 10.0: Pedro, Hviske and Dyne one orange at 19:00, Pedro, Hviske and Silke one blue-violet at 22:00 (`review_a/img/night_grade_zoom04.png`). A gate on baked colour (the first draft's "dE00 >= 12 OR IoU <= 0.80") is therefore met on paper and fails when it matters. **The gate is the silhouette:** for every pair of the six ghosts except Pedro - Hviske (the two heroes' own twin design, exempt) the IoU of the idle S and SE silhouettes aligned on the pivot is <= 0.80, and over ALL EIGHT directions <= 0.85. A pair that is not shape-distinct would have to be colour-distinct at every sampled hour (**G6**, graded dE00 >= 12); no pair needs it.
* **G7 finish** every finished sheet equals its pristine master on the alpha channel (0 flips) and differs on RGB (mean |dRGB| 15.7 / 15.6 / 14.7 / 15.1 on the idle sheets of Dyne / Gnist / Silke / Blund): the pass ran, exactly once, and moved no contour pixel.

| pair | IoU S / SE | all 8 | dE00 baked | graded min (worst case) |
|---|---|---|---|---|
| Pedro - Dyne | .77 / .76 | .79 | 12.3 | 2.8 (farm autumn clear 19:00) |
| Pedro - Gnist | .68 / .68 | .72 | 18.3 | 5.5 |
| Pedro - Silke | **.79 / .74** | .79 | 17.9 | 3.6 |
| Pedro - Blund | .62 / .64 | .66 | 23.0 | 6.1 |
| Hviske - Dyne / Gnist / Silke / Blund | .77 / .76, .68 / .68, .79 / .74, .62 / .64 | .79 .72 .79 .66 | 17.9 28.8 31.2 29.8 | 3.2 5.8 4.5 8.6 |
| Dyne - Gnist | .63 / .60 | .64 | 12.4 | 3.7 |
| Dyne - Silke | .67 / .64 | .67 | 20.2 | 4.3 |
| Dyne - Blund | .49 / .49 | .54 | **11.7** | 4.3 |
| Gnist - Silke | **.79 / .76** | **.82** | 13.8 | 4.1 |
| Gnist - Blund | .54 / .54 | .58 | 12.3 | 4.8 |
| Silke - Blund | .59 / .58 | .62 | 24.2 | 7.8 |
| (Pedro - Hviske, exempt) | 1.00 / 1.00 | 1.00 | 10.3 | 1.1 |

All 14 pairs that involve the family pass the shape gate, the tightest by one to three hundredths (Pedro - Dyne .79, Pedro - Silke .79, Gnist - Silke .82 over eight directions): the six ghosts are cousins of one rig. The variants that passed the cast gates were measured by `final_edit/search_variant.py` and `final_edit/iou_matrix.py`; the table is `notes/measure_family_final.txt`.
### 9.5 Numbers against the budgets of the art addenda

| | Dyne | Gnist | Silke | Blund | budget (source) |
|---|---|---|---|---|---|
| build + bake + validators + export + install, wall (`produce_all.sh --only=characters <id>`) | 8.0 s (first draft, load 3-5) / 13 s (final rebuild, load 16-29) | 8.1 / 15 | 7.8 / 17 | 7.4 / 18 | V2 (`impl/orders/V2-cast-art.md:33`): "under 2 min wall (8 characters, 5 jobs)"; Bu 12.5 s at load 3-5 (`notes/art_numbers.txt`); the final edit's rebuild: `final_edit/logs/times.txt` |
| the storybook finish (windowed, once) | 33-113 s for the six ghosts (52 images; 28 for the four), load dependent | | | | no budget in the addenda |
| GLB (stage only, never committed): vertices / KB | 10,384 / 1,401 | 11,044 / 1,460 | 8,585 / 1,267 | 8,427 / 1,224 | Bu: 7,132 / 1,006 |
| WebP sheets (6 clips + portrait), unfinished | 1,949 KB | 1,740 KB | 1,360 KB | 1,119 KB | sum 6,168 KB |
| WebP sheets, FINISHED (what ships) | **2,468 KB** | **2,148 KB** | **1,774 KB** | **1,367 KB** | sum **7,757 KB** (+26 %); the six finished villager folders of main (painted): 2,232-2,669 KB (`bear_guard` 2,232, `cat_morfar_mis` 2,447, `rabbit_farmer` 2,669) |
| PNG masters (stage only) | 5,729 KB | 4,989 KB | 3,907 KB | 3,145 KB | not committed |
| VRAM warm / all clips | 9.33 / 18.67 MB | = | = | = | villager figure 9.33 / 18.67 (`cat_morfar_mis`, `bear_guard`: `notes/vram_comparison.txt`); DT30: 8.93 MB per look |

Honest reading of the disk row: the first draft's table gave the unfinished sheets (6.0 MB for four) against an estimate of V2's order ("about 7 for eight characters at 1.1-1.3 MB per folder"), a figure made for the older roster. The roster of main is now painted and each villager folder is 2.2-2.7 MB; the finished family (7.8 MB for four, 1.4-2.5 MB each) sits inside that range, and the budget of the package is **about 7.8 MB**, not 6.0 MB. The bake time varies with host load; the first `produce_all.sh` of a fresh clone is a 55-225 s warm-up (the macOS first-run scan of the new venv path that `tools/art/README.md` documents; 55 s there, 132 s and 225 s here), not a budget number: the following ones took 9-30 s.
### 9.6 Game zoom: the evidence (real windowed Godot shots, looked at)

`proto/gamezoom_check_family.png` (the composite, re-shot for the final edit against the roster of CURRENT main: the clone's 48 roster folders are byte-identical to main `70f4bed`, `diff -rq`), raw 1280 x 720 shots in `proto/shots/` (the M1b look: no halo on the NPC ghosts), `proto/shots_m3/` (the M3 look with halos) and `proto/shots_unfinished/` (the first draft's smooth bake): `f_noon_zoom04.png`, `f_noon_zoom09_left.png`, `f_noon_zoom09_right.png`, `f_dusk_zoom04.png`, `f_night_zoom04.png`, `f_crowd_zoom09_dusk.png`, `f_crowd_zoom09_night.png`. `proto/style_before_after.png` shows the same six figures before and after the finish next to the drawn fox, hobbit and fairy.

What I saw. At zoom 0.4 the four read at a glance as four individuals next to Pedro and Hviske: Gnist taller than everybody with the cap, Dyne the widest with the coral-rimmed glasses and the coral stole, Silke slim with the bow, Blund the small yellow one. At zoom 0.9 the accessories read (the nightcap's tip, the lantern, the bun, the scarf stripes). **Next to the painted fox, hobbit and fairy the ghosts do not look like the same hand:** with the finish they carry a grey contour, grain and flat colour bands and sit much closer to the roster than the smooth CG of the first draft (style_before_after.png, A against B), but their volume is still soft 3D shading and their large dark eyes (the user's decision "dark eyes yes") are bigger than the roster's small bean eyes; they read as cute rounded ghosts among drawn animals, not as drawn ghosts (9.9). At dusk the warm grade tints everybody; at night the family's colours slide (Dyne grey-lilac, Gnist grey-green with a dark-red cap, Silke blue, Blund tan) and Pedro, with his halo and light, is clearly the brightest figure; the family is told apart by silhouette and accessory, which is what the gate guarantees (9.4). In the M3 look (halos alpha 0.9, scale 1.25, no light) an NPC ghost reads as a soft aura clearly weaker than Pedro's.
### 9.7 What is still weak (honest)

1. **At night the grade shifts the hues** (graded dE00 of every pair 2.8-8.6): from 19:00 the figures are told apart by silhouette and accessory (the bow, the cap, the stole, the scarf), not by colour. The gate rests on that (9.4); the turquoise / sage-lime nudge of iteration 9 reduced the shift and did not remove it.
2. **Six ghosts of one body plan.** Pedro, Hviske and the four share the rig, the eyes, the blush, the wisp; every pair passes the shape gate by one to three hundredths (Pedro - Dyne .79, Pedro - Silke .79, Gnist - Silke .82 over eight directions). A fifth distinct species of ghost (a hooded one, a tall thin one) would need a second rig: not built.
3. **Not the roster's hand.** The 48 roster sheets are imagegen paintings (`1ab4d2b`); the ghosts are 3D bakes with the storybook finish: closer than the first draft, not identical (9.6, 9.9; open question 6).
4. Gnist's sleepy eyes read "smug" from some angles (the lid arc is short on purpose: a wider arc read as sunglasses).
5. Silke's lantern is a baked yellow cage next to her mitten: a small brass jar at zoom 0.4, no light until GF-play.
6. Dyne's bun reads as a bump on her head from the front.
7. The back rows (N, NW, NE) are an egg with a wisp (as for Bu).
8. The walk is the ghost glide (a 5 px bob), not a step; the roster's own animations are 2D puppet deformations of five drawings, not frame-by-frame either.
9. The child's size is by design 70 % of the pack (like Lily and Bamse), not inside the +-10 % gate; Gnist's height margin is 2.8 px of the 10 % window and Silke's feet margin 1.4 px: a re-baked pack or a changed rim moves them (the tool prints the margins).
10. The finish costs +26 % disk (7.8 MB for four) and lifts Pedro's colour to 5.9 of the 6 allowed.
### 9.8 Reuse of G-ghost-art

The family IS a second use of the ghost pipeline: GF-art depends on `G-ghost-art` (wave 3b), imports `tools/art/ghost/ghost_model.py`'s `bell`, `ring_path`, `ghost_eyes`, `PALETTES`, `pat_sheet` and the glide hook WITHOUT editing them (the shim pattern of V2's `cast_v2` and G-ghost-art's own), and needs one amendment (AGF3), which now has two tasks: a check that the names exist, and the same storybook finish for Pedro and Hviske (the family stands next to them; a ghost player would otherwise be the only smooth CG figure on screen). The A2 wardrobe bases are NOT needed: NPCs wear no wardrobe.

### 9.9 The painted route (what matches the roster exactly, and what only the user can give)

Main's roster is no longer 3D-baked: `tools/art/drawn/pack.py` packages imagegen paintings (flat pastel watercolour, loose grey contour, tiny dark bean eyes, blush hatching) into the same sprite contracts with a 2D puppet bake from five authored views (`tools/art/drawn/README.md`). The only way to make the six ghosts the same hand is to paint them with the same tool, which needs the user's imagegen and cannot be done here. What was built and tested without it:

* `scripts/pack_ghosts_probe.py` imports `pack.py` WITHOUT editing it and drives `pack.character()` for the four family ids from a STAND-IN source (the idle views of the pristine 3D masters instead of paintings; `pack.HEIGHTS` updated at run time to 161 / 180 / 156 / 114, which with the rim of `pack.outlined()` give 165 / 184 / 160 / 118) into a scratch folder, and runs `measure_family.py` on the result (`final_edit/logs/measure_family_paint_probe.txt`). It proves the WIRING: the villager clip set packs, heights, pivot x 127.1-127.8, feet 207.0-209.0 and the palette gates hold. It does not prove the look (there are no paintings), and it shows that **the shape gate fires on a painted Silke that is not slim** (stand-in: Pedro - Silke .85, Hviske - Silke .85; `pack.fitted` normalises each drawing to a box): the paintings must keep the proportions of the bake.
* `proto/prompts_ghosts.json` (lift: `tools/art/ghost_family/prompts_ghosts.json`): DRAFT prompts for the two atlas sheets and the rear views, adapted from the `villagers1` / `backs1` prompts of `tools/art/drawn/prompts.json`, with the measured shape plan (height, aspect, body) of every ghost and the contact sheet of the bake as the SHAPE reference only. Nothing was generated.
* GF-art task 'STYLE TARGET AND HONEST LIMIT': `tools/art/ghost_family/sources/ghosts1.png` (+ a rear-view sheet) -> `pack_ghosts.py` -> the same gates; Pedro and Hviske are painted in the same sitting (AGF3). Until the sources exist the task is a named SKIP and the finished 3D bake ships.

Decision for the user: ship the finished 3D bake (default, ready now) or generate the paintings: open question 6.
## 10. The look of the layer in the rest of the system

* **Hero-twin consequences:** none (2.3). **Look cap:** 4.5 / 8.6. **Light budget:** the city's 12 map lights + the ghost player's glow 1 + Silke's lantern 1 = 14 <= 15 (V8's measured safe number); the NPC halos are additive sprites without lights (GF-play).
* **Voice:** text only in M1b; the 10 `_V` rows are voiced later, after review and the user's listening test (towns addendum Q4).
* **Audio:** none new.
* **UI:** none new (no screen, no registry row): the People book (S-ui, M1b) lists the family when met; the EXTENDED post screen `Hvor er ...?` (towns addendum 4.10) works from the same routine data, so it needs no change either.

## 11. Packages, waves, milestones

`ghostfamily_packages.json` (schema of design4 / design3). **New packages (6):**

| id | wave | size | milestone | owns | role |
|---|---|---|---|---|---|
| **GF-art** | 4 | M | **M1b** | `tools/art/ghost_family/**`, `assets/isometric_characters/ghostfam_{dyne,gnist,silke,blund}/**`, `tests/sections/art_ghostfam.gd` | the four figures: builder, shim, bake, storybook finish, the gate program `measure_family.py --check`, the shot driver, review sheets; depends on G-ghost-art (reuses its pipeline) |
| **GF-data** | 5b | M | **M1b** | `lua/routines/ghostfam/**`, `lua/buildings/ghostfam.lua`, `lua/shops/lantern_house.lua`, `lua/dialogue/ghostfam_<name>.lua` x4, `localization/ghostfamily.csv(.import)`, `tools/ghostfam/**`, `tests/sections/ghostfam_data.gd` | routines, shop, building, dialogue, copy, the section and the authoring tools |
| GF-play | 6 | S | M3 | `scripts/ghostfam/**`, `lua/config/npc_glow.lua`, `tests/sections/ghostfam_play.gd` | halos + Silke's lantern light |
| GF-quests | 6 | S | M3 | `lua/quests/ghostfam_{garn,lygtemager,hittegods}.lua`, `localization/ghostfamily_quests.csv`, `tests/sections/ghostfam_quests.gd` | three quests |
| GF-events | 6 | M | M3 | `lua/events/ghostfam/**`, `localization/ghostfamily_events.csv`, `tests/sections/ghostfam_events.gd` | ten heart scenes |
| GF-qa | 7 | S | M4 | `tests/sections/zz_ghostfam.gd`, `docs/qa/ghostfam/**` | acceptance + evidence |

**Amendments (17).** `apply_designs.py` decides "built" from the amendment's `built` / `fixRound` flags or from the PACKAGE's wave and IGNORES the amendment's own wave, so the intended apply gate is stated in the JSON (`applyAt`) and here: a fix-round of a built package that must wait for a later package carries `built = true`, `fixRound = true` and its gate.

| id | package | what | gate |
|---|---|---|---|
| AGF1 | V1-cast-data | 4 rows in `npcs.lua` (8.1); the voices inside the archetype presets; a fix-round of a BUILT package | **5b, one merge with GF-data** |
| AGF1b | V1-cast-data | `quests_offered` on three rows; the quest ids must exist (`data.gd` skips only FEATURE_QUESTS) | wave 6, the SAME commit as GF-quests |
| AGF2 | V2-cast-art | `art_characters.gd`: ROSTER +4 villager ids, PEOPLE +3, in terms of the literals of the file: `roster_is_36` and `checked == 36` -> 40, `_pivot.size() == 48` -> 52 (every ROSTER id + the 12 pack characters, Blund counted); after V2's own edit (36 -> 42, 48 -> 54) the totals are 46 and 58; `cast_pixels` gets a fifth CAST_ROWS row (58 once V2 has landed); the header list of check names follows the rename | **5b** |
| AGF3 | G-ghost-art | `art_ghost.model_api_for_family`; the storybook finish for Pedro and Hviske; the palette gate on the finished sheet | 3b (plain amendment; a fix-round task if G-ghost-art is already built) |
| AGF4 | T-towns-core | remove the decor row `gaestehytten`; NO late shop id any more (the building row, the shop file, the room and the dialogue land at the same gate) | **5b** |
| AGF5 | T-interiors-core | the room + stub map (`data/maps/int_gaestehytten.map`); `*_14` checks become `*_15`, derived from the directory | **5b** |
| AGF6 | T-routes | sidecar +1 door +1 post; counts derived (13 -> 14 doors, 36 -> 37 posts, 27 -> 28 areas, 14 -> 15 rooms, 23 / 30 citizens -> derived); NO `PENDING_CITIZENS` rule | **5b** |
| AGF7 | S-data | 4 citizens rows, 4 taste rows: they go in at the gate where `ghostfamily.csv` exists, because S-data's section runs the slot-coverage rules (`social_data.slots_complete_per_tier`, `skeleton_has_no_missing_core_keys`) on the real data | **5b** |
| AGF8 | I1-copy-system | `ghostfamily.csv` in `review_status.json` (draft); `copy_lint` covers it (C3: 10 voiced rows <= 14 words) | **5b** |
| AGF9 | P12 | CARVE-OUT `lua/shops/lantern_house.lua` (P12 owns `lua/shops/**`) | 3 (built, no file change) |
| AGF10 | P14 | CARVE-OUT the four dialogue files (P14 owns `lua/dialogue/**`) | 5 |
| AGF11 | P27 | CARVE-OUT `docs/qa/ghostfam/**` | 7 |
| AGF12 | P14 | one null-safe `Svc.static_call` in `Npc2D._ready` (`scripts/world2d/npc_2d.gd`) for the glow; a fix-round of the built P14 | wave 6, WITH GF-play (M3) |
| AGF13 | P13 | CARVE-OUT the three quest files | 4 |
| AGF14 | S-fest-content | `maanemarkedet` AND `midsommerlanterner` `stays_open += lantern_house`; 20 `FEST_<ID>_GHOSTFAM_<NAME>` rows | 6 (M3) |
| AGF15 | GF-data | quest branches in the dialogue modules (an amendment of a new package by another new package; a fix-round) | wave 6, with GF-quests (M3) |
| AGF16 | S-heart-content | the tier-A set and the counts of `scene_per_tier_a_4_6_8_and_10` / `forty_scenes_registered` are DERIVED: Dyne is the 11th tier-A citizen from M1b and her four scenes are GF-events', so a pinned "10 citizens, 40 scenes" fails either for Dyne (GF-events dropped) or on the count (GF-events built) | 6 (M3, plain amendment) |

**No same-wave coupling is left.** The first draft spread the amendments over waves 4 and 5 and needed a coupling table (V1 rows with GF-art, `PENDING_CITIZENS` in T-routes, a late shop id for `lantern_house`, a sidecar door without a building row, and S-data seeing citizens without copy, review B). Now GF-art (wave 4) only INSTALLS assets (the roster-driven `art_characters` ignores a folder that is not in its ROSTER) and everything that touches a shared file lands in ONE merge at the wave-5b gate, together with GF-data's files, as fix-rounds of built packages: nothing dangles at any commit between the gates (no name key without its CSV, no `routine = true` citizen without a file, no shop marker without a shop).

**Order and milestone placement.**
* **M1a (the city preview being built now): NOT part of it.** The art can be baked at any time after G-ghost-art (wave 3b); a preview has no citizens.
* **M1b (usable towns): GF-art (wave 4) + GF-data (wave 5b)** + AGF1-AGF8 (at the 5b gate) and the four carve-outs. Gate **G5c** = G5b with the family: `ghostfam_data` + `art_ghostfam` green under all four heroes, the 34-citizen sweep green, four windowed shots looked at. Load: GF-art M (2) + GF-data M (2) + amendments (about 1.5) = about 5.5 points, about 4.7 M tokens at the lead's measured 0.85 M per point (an ESTIMATE of the lead's own figure). **The family is droppable:** not building the GF packages and not merging the AGF amendments leaves G5b exactly as designed (30 citizens, 14 rooms, the decor hut).
* **M3 (extended social): GF-play, GF-quests, GF-events** + AGF1b, AGF12, AGF14, AGF15, AGF16 (about 4.5 points).
* **M4: GF-qa** (1 point).
* **Can GF-art reuse G-ghost-art?** Yes, it is built on it (9.8).

Sanctioned shared edits (the lead): **SE-GF1** `tools/loc/key_owners.json` (the `files` of `data/tools/loc/ghostfam_key_owners_additions.json` at the START of wave 5b, where `ghostfamily.csv` first exists, and at the start of wave 6 for the quest and event files; the additions file and the package JSON agree on `5b`); **SE-GF2** `assets/isometric_characters/manifest_traetoppen.json` (GF-art's installer merge: four rows `role npc, clip_set villager, family ghost, flyer false, display_scale 1.0, portrait portrait.webp` AND the `animations` table of each folder, which the installer writes and `art_characters.manifest_lists_the_roster` compares); **SE-GF3** `docs/copy/review_status.json` (AGF8); **E3** `data/towns/routes.json` regenerated at the wave-5b gate.

**Ownership proof** (`scripts/check_gf_ownership.py` = design4's checker re-used, the family as a seventh layer over design3's EFFECTIVE table + the ghost layer; run on main `70f4bed`): A pattern pairs intersected 105, overlaps 0; B `git ls-files` 3,709: multi-owner 0; C ownsRemove sanity 0; D dependency waves / cycles / schema / verify tags 0; E concrete paths 46, problems 0; **E2 lift destinations 7, problems 0** (the first draft lifted the shot driver into `tests/shot_*`, which P04-area-framework owns: it lives in `tools/art/ghost_family/` now); F key families 115 keys resolve to their own file, no existing key moved, prefixes unique, 0; G contracts 0; **RESULT OK**; `scripts/ownership_mutants.py`: 7 mutants (a foreign directory, a missing carve-out, a task without the verify tag, a same-wave hard dependency, a foreign QA folder, V1's file, a lift into `tests/shot_*`) all rejected, with the unmutated control 8 of 8 as expected (`notes/ownership_mutants.txt`). **Against the lead's MERGED table** (`impl/owners.json`, 104 packages; `scripts/check_own_against_owners.py`, `notes/check_own_against_owners.txt`): the carve-outs AGF9 / AGF10 / AGF11 / AGF13 remove exact strings, but P12 / P14 / P27 / P13 hold the globs `lua/shops/**`, `lua/dialogue/**`, `docs/qa/**`, `lua/quests/**`, so 9 `ownsRemove` strings match nothing and 9 pattern pairs overlap (the existing baseline has 134 overlaps of the same kind); the gates still pass because `impl/tools/ownership.py` counts a file as the wave's when ANY of its owners is in the wave. The proof above is against design3's effective table where the exclusions are real; at the merge keep the exclusions with the lead's tooling or accept the 9 overlaps as precedent, and re-run `check_own_against_owners.py`.
## 12. Risks and honest stubs

Risks (ordered by how much they would hurt):
* **medium - Six similar ghosts, not the roster's hand.** The roster gets six ghosts of one body plan (9.7 items 2, 3), 3D-baked with the storybook finish next to a painted roster. Guard: the measured shape gate (9.4); the accessories; the painted route (9.9) and open question 6.
* **medium - One merge at the 5b gate** touches seven built packages' files (V1, V2, T-towns-core, T-interiors-core, T-routes, S-data, I1). Guard: the clone run shows exactly which 16 `data` checks fail on today's main and why (8.7); `apply_designs.py` has no deferral concept, so the gates are stated in each amendment's `applyAt`; the family is droppable as a layer.
* **low-medium - Festival attendance** (18 home citizens against the cap of 15). Guard: the `fest` plans; open question 5.
* **low-medium - 34 keeperless minutes twice a year** (Hoestfesten, Vinterlysene: the shop reopens at the window end while Gnist walks back; 4.3). Guard: `zz_ghostfam` names it; the cure is `lantern_house` in those two festivals' `stays_open`.
* **low - Gate margins move with main** (Gnist 2.8 px of the height window, Silke 1.4 px of the feet window, Pedro's palette 5.9 of 6). Guard: the gate tool prints the margins.
* **low - Estimated walking times** (4.6). Guard: robustness 1.6x; arrive-by blocks carry no `leave`; E3 bake; `towns_routes.table_fresh`.
* **low - Light budget** (Silke's lantern is the 14th light). Guard: GF-play's count; the lantern halo is the first to go.
* **low - Copy quality**: AI-drafted Danish, status draft, no native check and no Danish language tool. Guard: review state machine; 3.8 h native.

Honest stubs (the full list is `honestStubs` in the JSON): hide and seek is a routine, not a mini-game and gives no reward; Silke "follows you home" is lore (the curfew mechanism is unchanged); the family has no glow before GF-play and the baked accessories cast no light; the route times of the new anchors are estimates; the social layer is lean (tier A Dyne, B the rest) until GF-events / GF-quests; the family does not attend the four Hyggebyen festivals; no ghost voice; no marriage, no children, no seasonal change; no fallback art (a missing sheet would draw a pack rabbit: guarded by a check); the day is 06-24, not 06-26; a festival closure is not known to Gnist's dialogue; the ghosts are NOT painted in the roster's hand until the user supplies imagegen sheets.

## 13. Open questions (only the user can decide; the default is what is designed)

1. **Names.** *Familien Natlys*, Mormor Dyne, Far Gnist, Mor Silke, Lille Blund. Keep? *Default: keep.*
2. **The clock.** The brief says "06-26"; the game runs 06:00-24:00 and passes the player out at 24:00. Should the day be extended past midnight so the ghosts get a real night (a change of `time.day_end_hour`, the pass-out and the curfew)? *Default: no.*
3. **Is the ghost player related to the family?** Now: a welcome new neighbour, and a Natlys at heart at 10 hearts. A cousin who arrives would need a story scene. *Default: no.*
4. **Hide and seek:** a pure routine (default) or a reward / counter for finding Blund (GF-events h4 has a counted version)? *Default: none in M1b.*
5. **Festivals:** should the ghosts ALWAYS attend the five Trætoppen light festivals (a `first` list in the festival file, one line in `SocialManager.override_for`) and visit the four Hyggebyen ones (a guests field and a raised cap)? *Default: about 88 % in Trætoppen, none in Hyggebyen (Gnist three of the five).*
6. **The look of the six ghosts.** Main's roster is painted (imagegen, `1ab4d2b`). Ship the 3D bake with the storybook finish (*default*: closer than the first draft, still a different hand, ready now) or paint Pedro, Hviske and the family with your imagegen from `proto/prompts_ghosts.json` and the shape references (the painted route is wired and gated, 9.9; only you can generate the sheets)?

## 14. Evidence index (everything under `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design5/`)

* **Art:** `proto/contact_sheet_family.png` (the size ladder, 8 directions, walk SE and SW all frames, talk / celebrate / interact / sleep, busts; built from the FINISHED sheets), `proto/gamezoom_check_family.png` (the game-zoom composite next to Pedro, Hviske, the painted fox, hobbit and fairy), `proto/style_before_after.png` (smooth vs finished bake next to the painted roster), `proto/silhouette_check.png`, `proto/shots/f_*.png` (raw 1280 x 720 shots, M1b look), `proto/shots_m3/` (halos), `proto/shots_unfinished/`, `proto/shots_first_draft/` (the first draft's shots), `proto/it1_rows.png` .. `it9_rows.png` (the nine iterations), `final_edit/variants_sheet1.png` / `variants_sheet2.png` (the final edit's variants), `proto/prompts_ghosts.json` (the painted route's draft prompts), builder `proto/builder/{family_model,traetoppen_additions,ghost_model_proto}.py`, shot driver `proto/shot_family.gd`, probes `proto/gf_probe.gd`, `proto/gf_probe_rows.gd`.
* **Art numbers:** `scripts/{measure_family (the gates, --check, --selftest),produce_family.sh,vram_per_member,contact_family,compose_family,zoom_sizes,pack_ghosts_probe,agf2_patch_clone}.py` -> `notes/{measure_family_final,zoom_sizes,vram_per_member,vram_comparison,verify_produce_family}.txt`; the earlier first-draft tools (`palette_check`, `palette_distance`, `palette_search`, `quick_rows`) are superseded by `measure_family.py`; `final_edit/logs/{times,measure_family_unfinished,measure_family_finished,measure_family_paint_probe,measure_cast_new}.txt`, `final_edit/logs/var_*.log` (the 56 variant bakes), `final_edit/{search_variant,iou_matrix,iou8}.py`, `final_edit/pristine/` (the pristine masters), `review_a/` (the night-grade measurement `logs/07_night_grade_baked.txt`, the storybook run `logs/08_storybook_run.log`, the amended `art_characters` run `logs/14_art_characters_amended.log`).
* **Routines:** `sim/{family_data,check_family,robustness,verify_routines_lua,gen_family_lua}.py` + design3's `model,plans,sim,gen_lua` copies and `routes_base.json` -> `notes/check_family_final.txt` (including the festival-day keeper table), `notes/robustness.txt`, `notes/verify_routines_lua.txt`, `notes/fest_gap_before_after.txt` (`final_edit/fest_gap_before_after.py`), `sim/routes_family.json`.
* **Data:** `data/lua/{routines/ghostfam,buildings,shops,dialogue,config,social}/`, `data/data/{interiors/core,maps,towns}/`, `data/localization/ghostfamily.csv` (also under `loc/`), `data/tools/loc/ghostfam_key_owners_additions.json`; `scripts/{gen_family_copy,economy_check,social_check,room_check,validate_social,check_probe}.py` -> `notes/{economy_check,social_validate_family,room_check,gf_probe.json,gf_rows.json}`.
* **Harness:** `notes/harness_final_sections.log` (the final re-run on the rebuilt clone), `notes/rebuild_final.log` (the log of `scripts/rebuild_clone.sh`), `scripts/verify_doc_lines.py` (checks section 7.3 against the CSV).
* **Ownership:** `scripts/{check_gf_ownership,check_own_against_owners,ownership_lib,globlib,ownership_mutants}.py` -> `notes/{ownership_mutants,check_own_against_owners}.txt`; `ghostfamily_packages.json` (generated by `scripts/build_packages_json.py`).
* **The reviews and their verdicts:** `CHANGELOG.md` (in `FINAL/`), `review_a/`, `review_b/`.
* **Reproduce everything:** `scripts/rebuild_clone.sh [NAME]`.
