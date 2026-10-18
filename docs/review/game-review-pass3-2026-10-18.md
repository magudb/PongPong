# Trætoppen - Game review, pass 3 (mechanics, UI, story)

**Date:** 2026-10-18
**Commit:** `f80e7aed` (worktree `PongPong-worktrees/game-review`, branch `game-review` = `main`)
**Scope:** a deep dive into game mechanics, game UI and story, held against the owner's product intent. That intent covers the cozy farm, the Mørkeskoven dungeon, the Hyggebyen/Trætoppen social sim, the 10-step home, 5 rarity tiers, the 06:00-02:00 day, the Danish-first copy, the style-guide HUD, full keyboard play and macOS/Windows releases.
**Companion data:** [`pass3/findings.json`](pass3/findings.json) holds every verified finding, unmerged, plus the dropped claims. [`pass3/harness.txt`](pass3/harness.txt) and [`pass3/logs/`](pass3/logs/) hold the test-gate baseline. [`pass3/shots/`](pass3/shots/) holds the screenshots.

## Method

- **13 area reviewers:** farming; economy; dungeon/combat; social sim; core loop and save; home/furniture/wardrobe; HUD; menus/panels; Danish copy and accessibility; main story; side quests and cast; a first-hour/first-week trace; and the status of prior findings.
- **5 gap reviews** covered areas nobody had read closely: heart-event scenes, save/load integrity, the ghost-family arc and hide-and-seek, city traversal and wayfinding, and audio.
- Every reviewer read the code and the Lua data in the worktree. They used scratch-dir Lua/Python dumps for the arithmetic. **Nobody launched Godot.** A separate capture agent produced the screenshots and the test-gate baseline in disposable APFS clones (see [`pass3/harness.txt`](pass3/harness.txt)).
- **Adversarial verification.** A skeptic re-read the cited code for every finding and tried to refute it. P0/P1 claims got two independent skeptics. The verdict was "confirmed" or "partly", and the severity was corrected where needed. Claims that did not survive are listed under "Refuted / dropped claims".
- **Prior findings** from the five earlier reviews were re-checked. Only items that are still open are reported, with a "Prior review" line. Fixed items are tallied in "Prior review status". The prior-status reviewer's 23 standalone items (PRIOR-01..23) lost their first verification to a verifier crash and were re-verified in a separate pass: 17 are merged into area findings, 6 are reported on their own, and none was refuted outright.
- **Editing.** Near-duplicates raised by several reviewers are merged under one id, and every merged id is listed on it. Merged ids keep their own records in findings.json.

**Test gate (from the capture agent): RED.** The plain strict gate cannot finish in one run, because `combat_acceptance` and `dungeon_fights` always time out. Run in 3 parts, it covered 145 sections and 16,851 checks: 41 failed, 163 skipped, 2 script errors and 2 timeouts. Most of the failures are festival scenes that never finish headless but pass when run windowed. Also failing:
- `ghost_lines.intro_line_after_the_letter` (stale after FM_OPENING_LEAD).
- A script error at `mechanics_review_fixes.gd:140`.
- Four performance budgets, missed by small margins.
- Three windowed baseline compares: `hud.v2_hotbar_compare` 12.243 > 12.0, plus the journal, gift and calendar baselines, which are out of date.

## Counts

225 findings survived verification. 45 near-duplicates were merged into another finding, which leaves **180 distinct findings** in this document. findings.json keeps all 225 unmerged.

| Severity | Verified (unmerged) | Distinct (after merge) |
|---|---|---|
| P0 | 0 | 0 |
| P1 | 4 | 4 |
| P2 | 98 | 83 |
| P3 | 123 | 93 |
| **Total** | **225** | **180** |

| Section (distinct findings) | P0 | P1 | P2 | P3 | Total |
|---|---|---|---|---|---|
| Game mechanics | 0 | 2 | 33 | 31 | 66 |
| Game UI | 0 | 1 | 15 | 25 | 41 |
| Story | 0 | 0 | 19 | 23 | 42 |
| Cross-cutting (first week, prior findings) | 0 | 1 | 16 | 14 | 31 |

By category (distinct): ux 31, design 28, bug 24, consistency 20, copy 19, balance 17, story 12, tech-debt 12, missing-feature 10, accessibility 7.

Verification changed several severities. Eleven P1 claims were downgraded to P2: FARM-01, COMBAT-01, CORE-01, CAST-01, CAST-02, FIRSTHOUR-01, GAP-SAVE-INTEGRITY-01, GAP-WORLD-TRAVERSAL-01/02 and GAP-AUDIO-FEEL-01/02. Thirteen P2 claims were downgraded to P3. Re-verifying the prior-status items downgraded three more from P2 to P3: PRIOR-01, PRIOR-02 and PRIOR-03.

## Executive summary

Trætoppen is a broad and carefully engineered cozy game, and most of what the owner asked for exists and is wired up:
- the exact 06:00-02:00 clock and gentle defeat
- validated, daily-seeded dungeon floors with atomic loot
- a 10-tier home ladder, and five rarity tiers across furniture, clothing and weapons
- 34 citizens with routines, gifts and birthdays, and 5 + 4 festivals
- a marriage track, and Blund's counted hide-and-seek
- a clean Danish localization pipeline (0 lint errors, no "Fesby", no raw keys)
- a HUD that matches the Miljøer v2 sketch.

No P0 was found. Four P1s remain, and they are all cheap to fix:
- **FIRSTHOUR-02:** "Nyt spil" silently overwrites a child's only autosave.
- **COMBAT-02:** attacking and using tools have no keyboard key, which breaks "full keyboard play".
- **MENUS-01:** Indretning, the only way to place furniture, opens only through an untaught H key.
- **ECON-01:** the builder yard refills 1 item a day, which stalls home tiers 7-10 for weeks.

The weakest layer is the social and story content that sits on top of these systems:
- Citizen copy is largely fill-in-the-blank.
- About 140 heart-band chat lines and every bark are written but never shown.
- Four marriage candidates have no content of their own.
- All 40 heart scenes come from one template, and their choices change nothing.

The main story is structurally sound and often moving, but it is weakest where it matters most:
- In the opening, a flag clash makes the mayor's welcome unreachable, and the mother premise is an unsigned P.S. that Esc skips.
- The first letter already gives away the mystery's "why".
- The finale has no reward and no reaction from the town.

The mechanics have a few dominant strategies:
- glow-berry regrowth
- five repeatable quests that never take the goods
- unlimited runestone heals

The Energi bar is decorative: it refills in about 9 s.

UI and accessibility:
- On the code-built home and farm panels, focus jumps back to "Luk" after every action, which makes them tiring to use with keyboard or gamepad.
- Key hints are missing on half the panels, or illegible at 1.8:1 contrast.
- There are no accessibility settings at all.

Saves have a strong core, but real gaps:
- Closing the window does not save.
- Vitals are not saved, so a save and reload in the forest gives a full heal.
- The pass-out autosave records 02:00 instead of the next morning.
- A Lua rename or retune can turn a valid save into "Beskadiget".

Audio is placeholder content: all 14 tracks are the same synthesized arpeggio, and most core actions are silent.

## Top priorities

Effort: S = under a day, M = a few days, L = a content or art workstream.

| # | ID | Sev | Area | One line | Effort |
|---|---|---|---|---|---|
| 1 | FIRSTHOUR-02 | P1 | Cross-cutting | "Nyt spil" overwrites the only autosave with no warning and no backup. | S |
| 2 | COMBAT-02 (+FIRSTHOUR-01) | P1 | Mechanics | No keyboard key for `attack` or `use_tool`, so a keyboard-only player can neither farm nor fight. | S |
| 3 | MENUS-01 | P1 | UI | Indretning (furniture placement) can only be reached through an untaught H key. | S |
| 4 | ECON-01 | P1 | Mechanics | Builder yard restocks 1/day against a 40 shelf, so tiers 7-10 stall 40-50+ days unexplained. | S (data) / M (sim) |
| 5 | GAP-WORLD-TRAVERSAL-01 | P2 | Mechanics | Notice board, mailbox and travel post fake an NPC talk, which completes talk and turn-in objectives remotely. | S |
| 6 | MENUS-09 (+CORE-07, COPY-08, FIRSTHOUR-11) | P2 | UI | The cheat menu ("Giv 10.000 guld") ships in the player pause menu and on F8. | S |
| 7 | COMBAT-01 | P2 | Mechanics | A forest click always uses the hotbar item: no input buffer, Cozy auto-swing dead, tonics consumed by accident. | S |
| 8 | CORE-06 / CORE-04 / GAP-SAVE-INTEGRITY-02 | P2 | Mechanics / Cross-cutting | Closing the window doesn't save; reloading in the forest gives full vitals; the pass-out autosave records 02:00. | S |
| 9 | GAP-SAVE-INTEGRITY-01 | P2 | Cross-cutting | Catalogue checks in validators turn any Lua content rename or retune into a "Beskadiget" save, and the auto slot has no backup. | M |
| 10 | SPINE-01 + GAP-WORLD-TRAVERSAL-02 | P2 | Story / Mechanics | The mayor's welcome is dead code because of an `intro_done` clash, and the first errand gives no clue where she is. | S |
| 11 | MENUS-02 (+HOME-10) | P2 | UI | Six code-built home/farm panels open on "Luk" and jump back to it after every pick or transfer. | M |
| 12 | FARM-01 / ECON-02 | P2 | Mechanics | Glow-berry regrowth is about 3x the next-best crop; five repeatables pay forever without taking the goods. | S |
| 13 | SPINE-03 (+FIRSTHOUR-08, COPY-14) | P2 | Story | The opening never establishes the mother premise; it is a P.S. in the King's voice that Esc skips. | M |
| 14 | SOCIAL-04 + CAST-02 + GAP-HEART-EVENTS-01 | P2 | Mechanics / Story | Social copy is templated, chat and bark lines are never shown, and heart-scene choices do nothing. | L |
| 15 | GAP-AUDIO-FEEL-01 / -02 | P2 | Cross-cutting | One placeholder arpeggio for all music, and silence for farming, crafting, home upgrades and boss victories. | L |

## Game mechanics

### Area: Farming, crops, seasons, greenhouse, animals

The farm loop is fully wired in GDScript, not just described in data. Tilling, planting, watering, the moon-crop water window, regrowth, season withering, fertilizer, fairy-dust auto-water, sprinklers, preserves jars and kegs, the 12-bed greenhouse, the 42-cell field expansion, the overnight shipping bin and the animal care loop (food now gates production, the pail is required) all run, and their saves are validated. Several prior findings are now fixed: food bypass GM-02, the inert pail GM-03, sheep payoff GM-07 (sheep wool is now {3,4}) and the winter dead-zone M6/F2 (frost_kale is in the seed shop). The biggest problem is crop balance. Glow berry regrows every 4 days and earns about 30 g per plot per day over summer and autumn, roughly 3x the next-best crop. Every current balance table (including the latest deep-dive's 4.6 g/day) undervalues it because they ignore regrowth. The greenhouse's 24/7 self-service shelf removes the seed cap (99 per day, cheaper than the magic store), so one planting fills the whole field. Smaller issues: moonflowers fail silently (soil looks wet but the plant does not grow), kitten and puppy produce an item with no use, and some copy promises things that do not happen (catnip "loved by cats", kitten "follows you", puppy "guards the farm").

**Strengths**
- FarmGrid commits each change together with its inventory transaction (consume_backpack_items / receive_backpack_item with a commit callback) and validates saves strictly (farm_grid.gd:153-179, 233-262, 347-378).
- The moon-crop water window handles the 26-hour clock correctly, including wrap-around and 00:xx/01:xx belonging to the same game day (farm_grid.gd:181-187, game_balance.lua:43-45).
- Sprinkler order is right: FarmEquipment attaches after both FarmGrids (world_2d.gd:173-183 vs 205), so the morning sprinkler pass runs after the previous day's growth is counted (farm_equipment.gd:63-80).
- The shop and inventory detail panels show each seed's seasons, growth nights, regrowth days and an 'indoors only now' hint, all from the live crop table (scripts/ui/components/farming_details.gd:3-18).
- The greenhouse is a real indoor FarmGrid (indoor flag, no rain, all seasons) with 12 beds that match farm_equipment.lua capacity=12 (greenhouse.map:6,28-30).
- Animal care now has a gentle food rule: production needs hunger >= 10 at dawn, and stored products are never lost (animal_husbandry.gd:677-692).
- The shipping bin pays the next morning at the ordinary sell value and only accepts crop, product and forage (shipping_bin_2d.gd:22-25, farm_stage.gd:50-74).
- Winter is no longer dead: frost_kale is stocked in the seed shop (seed_shop.lua:36), and snow_turnip and snowdrop exist with art.

### Area: Economy, crafting and progression gates

On paper the economy is clean. There is one price function, so the listed price is always the charged price. Discounts have a single owner. No item can be bought and sold back for a profit, even at the 20% discount cap. All 52 recipe ingredients are defined, and the gold costs of the 10 home tiers rise smoothly. The biggest problem is in the home ladder. Every few days it needs more bricks, roof tiles, glass and marble than the builder yard can hold or restock: the yard holds 40 of each and refills 1 a day, and marble comes 12 at a time in about half of all weeks. Without warning this causes 40–50+ day stalls at tiers 8 and 10, and the balance model never simulates it (it assumes the yard always has enough). Five repeatable quests ask for goods and never take them, so holding one stack pays about 650 g/day indefinitely. The designed wild-flower patch on the farm never spawns, which leaves the day-1 flower-necklace quest unfinishable for weeks. The greenhouse seed shelf ignores seed scarcity and opening hours, and also buys every kind of item. Together with glow-berry regrowth and kegs, this means the published progression model (about 52 hours for a typical player) no longer matches the data. On the gold side, a dedicated player has the money for the castle by roughly day 45–60. Building materials and gates, not gold, set the late-game pace.

**Strengths**
- One price function: ShopSystem.get_buy_price → PriceCurve.final_price prices everything, so the listed price always equals the charged price.
- No direct buy→sell arbitrage exists in any of the 18 shops, even at the 20% discount cap (scripted scan).
- All 52 recipe ingredients and all 136 recipe outputs are defined items, and every ingredient has at least one source: shop, loot, node, husbandry, recipe or quest.
- Robust transactions: purchases are all-or-nothing with refunds, gold saturates instead of wrapping around, crafting returns the ingredients when the output does not fit, and loot duplicates are sold at once instead of lost (economy_manager.gd:157-187, …
- The gold cost of the home ladder rises smoothly: 200→27,000 g, about ×1.5–2.4 per step, 74,000 g in total.
- The dungeon loot cap is sound: it limits the daily value only of rarity-restricted finds, so deeper floors still drop better items (dungeon_loot.lua:47).
- Processing machines (jars vs kegs) and the greenhouse create real throughput choices, and winter now has crops.

### Area: Mørkeskoven dungeon, combat and loot

Mørkeskoven is technically solid. Every floor is validated: the exit and all features must be reachable, required witnesses must be present (the prior GM-01 fix holds), and pinned fallback seeds cover the rare failed floor. Loot is handed out as one atomic plan, fit check and commit. Gentle defeat works as the owner asked: wake at home, keep items, lose 10% of gold rounded down, then an autosave. The weakest parts are combat input and combat feel, which the data promises but the code does not deliver. In the forest, a left click (or gamepad X) is read as "use the selected hotbar item", so the `attack` action, its input buffer and the Cozy assist's auto-swing can never fire. A click with a consumable selected uses it up. Attack has no keyboard key at all, although the owner asked for full keyboard play. Each weapon family's knockback value is ignored, and a single hit on a boss during its dazed window cuts that window from 1.5–1.8 s to about 0.4 s. On loot, legendaries come only from weekly repeat boss kills after the first kill, which pays just a rune. Uniques are throttled to one per week across 27 sources, and no material is above rare. Legendary weapons only arrive after the last content they could help with is cleared. Crystal nodes that look like amethyst or moonstone never give that gem. Enemy and boss variety is thin: 5 sprites, and the 3 bosses are recolours of one.

**Strengths**
- Generation guarantees are enforced, not hoped for: dungeon_gen.gd:1196-1320 rejects layouts where the exit or any feature is unreachable, where islands appear, or where a required hulen_keeper witness is missing.
- The daily seed and chained floors are clean.
- Gentle defeat matches the owner's rule exactly (world_2d.gd:759-791): the run ends, the player sleeps until morning, loses floor(gold x 10%), wakes at the farm with all items, and the game autosaves.
- Telegraphing is consistent and well engineered.
- Loot transactions are atomic and backpack-safe.
- The assist system is rich and data-driven (dungeon_run.lua:23-29): damage, telegraph, hearts, arc, dodge, oil, last spark and reduced flash.
- Prior copy defects in this area are fixed: the bossernes_vej objectives now say 'Overvind' (dungeon_services.csv:47-49).

### Area: Social sim, festivals, ghost family

The social sim covers everything the owner asked for, and most of the data is consistent and validated. All 34 befriendable citizens have a routine, gift tastes and a birthday that never lands on a festival. There are 5 Trætoppen and 4 Hyggebyen festivals, each with activities, opening and finale scenes and decor, and the ghost family attends all of them. The marriage track and Blund's counted hide-and-seek (with rewards) are both implemented with care. The main problems are in how the pieces fit together. On two festival days shopkeepers leave their shops while the shops stay open. Silke's 8-heart dawn scene can only be reached with near-perfect play, because the window is 12 real seconds after waking on the farm. Festival contests are scored so that the themed entry (a cookie in the cookie contest, honey in the honey contest) can never place. The content is also thin for 4 of the 11 marriage candidates. In addition, all 80 heart-band chat lines (fill-in-the-blank templates) and all 66 bark lines exist in the CSVs but no code path ever shows them. I found no blocker (P0) or major (P1) issue in this area: hearts, heart events, the wedding and the seek ladder can all be reached in normal play.

**Strengths**
- Data integrity is guarded in two places: tools/social/core/validate_social.py (rules SV1-SV14: tastes resolve, birthdays at least 2 days from festivals, roster caps, contest prize caps) and scripts/towns/towns_validate.gd keepers_cover_hours (each keeper …
- The festival calendar matches the owner's brief: 5 in Trætoppen (midsommerlanterner, badedagen, hoestfesten, vinterlysene, aarsskiftet) and 4 in Hyggebyen (blomsterfesten, honningdagen, maanemarkedet, bagedagen).
- The ghost family is well integrated.
- Blund's hide-and-seek does what the owner asked: 2 counted slots per evening (none on Wednesdays or festival days), a daily cap, no way to fail, a five-step reward ladder of lamps from normal to legendary, a fallback when you already own the one-of-a-kind …
- The marriage track is careful and child-appropriate.
- The gift system stays cozy: nothing ever goes negative, there are birthday and belated multipliers, and protections stop you from gifting quest items, your last tool, home-upgrade materials or set pieces needed for a capstone …

### Area: Core loop, time, energy, heroes, save/load

The core plumbing is solid: the clock follows the 06:00-02:00 contract with exact arithmetic, weather is seeded per day, and the save system validates, writes atomically, keeps backups and rolls back a failed load. The prior Codex fixes I re-checked are still in place: midnight during travel queues the pass-out, a slot with only a backup still loads, and the config cache applies fallbacks per call. The weak part is the gameplay these systems carry. Energy refills in about 8 s, so it rarely limits anything. That makes the iron hoe (400 g), the gold watering can (600 g), energy food, the fox's cheaper tools and the ghost's cheaper running nearly worthless, and passing out at 02:00 has no consequence. The four heroes are not balanced: the fairy has no perk with any gameplay effect, while the ghost dominates the dungeon (prior R1 is still open). Tool 'equipment' is never read during play, because the hotbar slot decides which tool is used, so upgrades can appear not to work. Persistence has a few holes: closing the window does not save, a manual save in the dungeon gives back full hearts, oil and energy on load, and the pass-out autosave records the moment before waking. The cheat menu is in every build, reachable from the pause menu.

**Strengths**
- Clock contract is exact and well documented: advance_time rolls the day at day_end_hour 26 and carries the leftover minutes; day_end_hour() falls back safely on bad config (game_manager.gd:171-181, 468-485); hours 24 and 25 stay on the same game day.
- Weather is rolled once per day before day_started, from a saved per-world seed, so the forecast matches the real next day across season and year boundaries (time_manager.gd:183-201, 245-262).
- SaveManager is robust: payload validation, migration chain, a section registry with optional validate_dict, atomic temp-file write with read-back compare, backup rotation only from a valid primary, and all-or-nothing apply with snapshot rollback and an …
- Save coverage is broad: game, time, economy (with arsenal), quests, husbandry, shops, home, furniture, wardrobe, loot, dungeon and social (with an orphan bucket for removed NPCs) are all registered; farm, greenhouse, hotbar, placed equipment and area flags …
- Gentle defeat matches the owner's intent: wake at home, keep items, lose a rounded-down 10% of gold, autosave (world_2d.gd:758-793).
- Hero twin handling: if the player chooses Rasmus, Kiki, Bertil or Bodil, that NPC's town routine is suppressed (routines.gd:107, 460; lua/routines/ext/*.lua hero_twin).

### Area: Home, furniture, wardrobe, collections

The home, furniture and wardrobe systems are solid and complete as data. All six clothing categories have all five rarity tiers (jewellery across its four subslots), and furniture runs 45/33/24/17/11 across the tiers. Every one of the 226 items has at least one source that actually works (shop, craft, dungeon pool, hidden spot, boss, quest, friendship gift, tier gift or set capstone), so nothing is unobtainable. Saving, construction, gift delivery and placement are carefully written. The weakness is the game design around collecting. Builder gifts alone meet almost every cosiness gate and the finale's "6 treasures" objective, so finding rare furniture does nothing for progression. Item perks, cosiness points and set bonuses are never shown in any shop or in the wardrobe. Rare clothing looks like recoloured common clothing, and the planned rarity aura was never built. There is no collection screen, and the home-builder screen hides the gate hints that were written for it. Small issues: clothing quest rewards are silently lost if the player already owns the piece, ghost trousers and boots are drawn only as thin bands, plus some copy inconsistencies.

**Strengths**
- Rarity coverage meets the owner's requirement.
- Nothing is unobtainable.
- The furniture art data (assets/iso_props/furniture/furniture.json) has the same 130 ids as the Lua furniture catalogue, with identical footprints.
- HomeManager is careful and robust.
- Furniture is never lost on a tier change. rebuild_for_tier first nudges pieces to the nearest valid spot (within 4 cells) and otherwise returns them to storage with a message (furniture_manager.gd:113-131).
- All eight home unlocks do something real: workbench, oven (baking menu), loom, guest visits, forge bench, forecast (tomorrow's real weather), the Fe-fest (with the cooldown waived while the finale needs it) and a one-time royal evening visit that respects the …
- Rarity matters for sell value: normal to rare furniture sells back at 0.36-0.39 of the buy price, while unique and legendary pieces are keepsakes that cannot be sold.

### Area: Treetop city traversal, fast travel, notice board and wayfinding across areas

Getting around the world mostly works. Trætoppen is the hub that connects the farm, Hyggebyen and the Skovlift. The baked route table is current, has no unreachable pairs, and every NPC routine anchor resolves. Interiors evict the player at closing time without ever trapping them. Walking times are modest: a full farm → Hyggebyen → Skovlift → farm loop takes about 160 game minutes (about 80 real seconds) of the 20-hour day. Running cuts that by about a third. The serious problems are elsewhere. First, the city service dialogues (notice board, fast-travel post, farm mailbox) send a fake 'dialogue_started' signal as if the player had talked to an NPC. That completes 'talk to X' and delivery objectives from a distance, including the intro's 'talk to the mayor' step and the item turn-ins of supply_run and cookie_delivery. Second, wayfinding is weak. The intro sends the player across the bridge to 'say hello to the mayor', but on day 1 (a Monday) she is in Hyggebyen, not at Trætoppen's Rådhus. The 'Hvor er …?' locator leaves her out until the player has 1 heart with her, and the journal lists the quest location as the farm. Fast travel only jumps between four invisible points inside Trætoppen, and the Skovlift arrival point sits on top of the lift's own E target. The only interactive notice board is inside the Rådhus, open weekdays 09:00–15:00, and it always shows the same first five quests in giver order.

**Strengths**
- data/towns/routes.json is current: all 57 input hashes match the files in the worktree.
- Scheduled NPCs never walk through walls: TownDirector._path (scripts/towns/town_director.gd:353-356) holds the citizen at the safe destination when no path exists.
- No lock-in at closing time.
- Climbing and the lift cannot strand the player.
- LevelRules R1-R12 (level_rules.gd:4-21) validate the treetop geometry: bridge ends, ladder lanes and lift stand on walk regions, and every spawn on a level.
- Door signs show the building name, today's hours and closed weekdays within 3 cells (door_2d.gd:166-181), and refused doors whisper the reason and when the place opens next.
- Travel time costs the day little: walking from the farm porch to the Trætoppen gate takes 20 game-min, crossing Trætoppen 23-38 game-min, and reaching any Hyggebyen door from its gate 6-20 game-min (walk 285 ground px/s, 2 game-min per real second).

### Findings (66)

### ECON-01 - Builder-yard restock (1/day, shelf 40) and the weekly marble offer cannot supply tier 8 and tier 10 – unmodelled 40-50+ day stalls (P1, balance)

**Evidence**
- lua/shops/home_shops.lua:189-200 builder_yard fixed stock: brick, glass_pane, roof_tile … all `{ stock = 40, restock = 1 }`
- scripts/economy/shop_system.gd:415-416 morning restock = +restock (1) clamped to stock (40)
- lua/data/home_tiers.lua:280 tier 8 `brick = 90, glass_pane = 40, marble_block = 20, copper_plate = 30`
- lua/data/home_tiers.lua:354 tier 10 `roof_tile = 80, glass_pane = 40, marble_block = 40`
- lua/data/home_tiers.lua:127,165,202,239 glass 8/12/16/30, roof_tile 24/40, brick 36 at tiers 4-7
- lua/shops/home_shops.lua:213-221 marble/walnut/gold_leaf/copper_plate only in the weekly `ugens_fine_varer` slot: pick 4 of 8, qty 12
- lua/data/loot_tables.lua:269 roof_tile appears only in the skovkant (floors 1-3) material pool; :635 marble only in krystalgrotten (10-12); loot rolls are amount 1 (scripts/loot/loot_rules.gd:206)
- docs/design/PLAN_2D_FEATURES.md:292 design row: builder_yard `daily | 12 basic materials (qty 40)` – no 1/day trickle specified
- tools/features/sim/balance_sim.py:418-425 the model buys any missing builder_yard material instantly (`'fixed': 0` wait), so the restock limit never appears
- tests/acceptance/journey.gd:93-105 the only material-buying journey covers tier 2 (all amounts below 40)

**What's wrong.** Brick, glass and roof tile can only be bought at Hasselnød's yard (they are not craftable; loot gives about one unit per dive at most). The shelf holds 40 and refills 1 a day, even on closed days. Per-tier needs exceed what the shelf can hold: brick 90 at tier 8, roof tile 80 at tier 10. A player who did not secretly stock up must buy the 40 on the shelf and then come back daily for 50 or 40 more days. Totals, buying every restock from day 1: glass is 150 for the home (+8 for the greenhouse), so tier 10 is reachable around day 111-119 at the earliest. Roof tile is 144, so about day 105. Brick for tier 8 is 126, so about day 87. Marble (76 total) only arrives as 12 per marble week, offered about 50% of weeks. Waiting for tier 10's cumulative marble takes a median of 13 weeks and a 90th percentile of 19 weeks (binomial calculation). Tier 7 alone (16 marble) needs two marble weeks: median 21 days, 90th percentile 49 days. stone_block (186) and slate are fine because stone is craftable and slate has a daily slot. Nothing in game or docs tells the player to stockpile.

**Player impact.** From tier 7 on, the home ladder stalls for weeks while the player already has the gold, with no explanation. The Husbyggeri just shows e.g. 'Mursten 40/90'. A child sees a sold-out shelf and gives up, and the 'grand castle in 10 steps' goal becomes a slow daily trickle of single tiles.

**Recommendation.** In lua/shops/home_shops.lua builder_yard, set restock equal to stock (40) for the 12 basic materials, matching timber_yard and the PLAN row. Alternatively raise brick/glass_pane/roof_tile to stock 99, restock 30. Give marble_block a permanent fixed row (e.g. stock 24, restock 8), or raise ugens_fine_varer qty to 24 with marble pinned. Add glass_pane/roof_tile/brick to timber_yard, or add recipes (stone + lime → brick; sand-free glass from crystal_shard). Update balance_sim.py to model restock, and extend journey.gd or a home_progression check so every tier's materials are purchasable within N days.

**Verification.** Confirmed by two skeptics. Brick and glass are also in 3-4 loot pools, but at about 1.7 % per container roll, so loot does not change the result. The sim ignores even the weekly marble wait (`balance_sim.py:424`). A player who buys every day is not slowed (the supply floor puts tier 10 around day 111-119), but anyone who saves gold and then buys hits the 40-50 day trickle.

### COMBAT-02 - There is no keyboard key for attack, so combat cannot be played with the keyboard alone (P1, accessibility)

*Merged:* FIRSTHOUR-01 (P2, First-hour / first-week playthrough trace): No keyboard binding for tools or attacking: a keyboard-only player cannot do the first tutorial step or fight.

**Evidence**
- project.godot:158-163: `attack` = InputEventMouseButton(button_index 1) + InputEventJoypadButton(2) only; no InputEventKey
- project.godot:152-157: `use_tool` likewise LMB + joypad only
- docs/design/UI_NAVIGATION.md:161: `use_tool` / `attack` | LMB | X
- localization/dungeon_run.csv:64: DTUT_ABILITIES "Klik: slå. Mellemrum: undvig. Q: fe-lys. R: drik." (keys hard-coded in copy)
- Owner requirement: 'full keyboard play'
- [FIRSTHOUR-01] project.godot:152 use_tool={...} and :158 attack={...}: only InputEventMouseButton (left) and InputEventJoypadButton (X), no InputEventKey (decoded the whole [input] section)
- [FIRSTHOUR-01] tests/tools/input_contract.gd:33-34 pins "use_tool": {"mouse": [MOUSE_BUTTON_LEFT], "joy": [JOY_BUTTON_X]} and the same for attack, so the missing key is locked in by a test
- [FIRSTHOUR-01] scripts/world2d/player_2d.gd:194-201: farming (use_selected) and combat.request(&"slash") are reached only through these two actions
- [FIRSTHOUR-01] localization/farm_tutorial.csv:6 DLG_FARMINTRO_PIP_BYE_1 'Vælg den med %s, og brug %s på jorden' resolves to 'Venstre klik' on keyboard (ui_hints.gd glyph falls back to the mouse)
- [FIRSTHOUR-01] docs/design/UI_NAVIGATION.md §3.2 table row `use_tool` / `attack` = LMB | X
- [FIRSTHOUR-01] docs/PLAYING.md:61 claims 'Keyboard and controller attacks retain the precise movement direction', but no keyboard attack exists

**What's wrong.** Dodge (Space), fairy light (Q) and drink (R) have keys, but striking, and using a tool in general, needs a mouse button or a gamepad. The keyboard-only acceptance flows in UI_NAVIGATION cover menus and home screens, not combat. The tutorial line also hard-codes 'Klik' and the other keys, so it will be wrong once keys can be rebound. Note: the main checkout has uncommitted edits to project.godot and tests/tools/input_contract.gd that may already address this. They are not in this worktree.

**Merged findings add.** FIRSTHOUR-01 adds that `use_tool` has no key either, so a mouse-free player also cannot hoe, water or plant, and is stuck on Pip's very first instruction. `tests/tools/input_contract.gd:33-34` pins the missing key. One FIRSTHOUR-01 skeptic noted that mouse use is a documented choice (UI_NAVIGATION.md:179) and that macOS/Windows always have a mouse. Treat this as P1 if the owner means mouse-free play.

**Player impact.** A keyboard-only player can walk into Mørkeskoven but cannot fight, mine or chop, which blocks the dungeon loop and the boss gates that home progression depends on.

**Recommendation.** Bind attack and use_tool to a key (for example J or K, or F if fly_toggle moves), add the key to the P01 input contract and to UI_NAVIGATION.md's action table, extend the keyboard-only acceptance flow to one forest fight, and build DTUT_ABILITIES from the live InputMap labels instead of literal key names. Fix this together with the routing bug above so that the key reaches `combat.request(&"slash")`.

**Verification.** Confirmed by two skeptics. `interact` (E) only harvests ready crops and hits nodes with the selected tool. It never hoes, waters or swings. FIRSTHOUR-01: One skeptic confirmed, one partly. Downgraded from P1.

### FARM-01 - Glow berry regrowth makes it about 3x more profitable than any other crop; current balance tables miss this (P2, balance)

**Evidence**
- lua/config/game_balance.lua:53 glow_berry = { stages = 5, days_per_stage = 2, regrow_days = 4, seasons = { sommer, efteraar }, sell_price = 150 }
- lua/items/magic.lua:58 glow_berry_seeds buy_price = 95; :68 glow_berry sell_price = 150
- scripts/world2d/farm_grid.gd:248-249 harvest keeps the plant (regrowing = regrow_days > 0) and :134-135 later harvests need only regrow_days
- lua/shops/greenhouse_seeds.lua:11 glow_berry_seeds = { stock = 99, restock = 99 } (vs magic_store.lua:24 stock 8 / restock 4 at buy_multiplier 1.1)
- docs/review/mechanics-story-deep-dive-2026-10-18.md:73 lists glow_berry at 4.6 g/day ('magic-store seeds'), treating it as a single-harvest crop
- lua/config/game_balance.lua:50 carrot 4 days, sell 65, seed 20 (best non-regrowing crop)

**What's wrong.** Glow berry gives its first harvest after 10 watered nights and then every 4 nights for the rest of summer and autumn. A day-by-day simulation over its 56-day window gives 12 harvests: +1,705 g net per plot, or 30.4 g per plot per day (59 g/day with fertilizer every harvest). The best alternatives in the same seasons are carrot (10.5 g/day), pumpkin (about 5-7), sunflower (4.5) and moonflower (2.1). In the greenhouse it earns about 34 g per bed per day all year, against carrot's 10.7. Because the plant regrows, a field is planted once and then needs only harvesting and sprinklers, so it also needs about half the actions of carrots. The only limit on seeds was the magic store's 8 + 4 per day. The greenhouse shelf (reachable at home tier 2) removes that limit with 99 per day at the cheaper base price. All prior reviews' tables either omit regrowth (4.6 g/day) or call it 'a strong long-term investment', so the team's balance picture is wrong. In 2 of 4 seasons every other outdoor crop is strictly dominated for gold.

**Player impact.** From the first summer, the best play is 'fill the field with glow berries and harvest every 4 days'. Crop variety stops mattering for two seasons. A 126-plot glow-berry field nets about 215,000 g over summer and autumn, roughly 3x the 74,000 g total of all ten home upgrades, so home progression is front-loaded much faster than the tier curve intends.

**Recommendation.** Model regrowth in the balance tables (docs/qa/game-mechanics/analyze_balance.py). Bring glow berry's rate into the carrot band (10-14 g/day). For example: regrow_days = 7 and sell_price = 110, or keep regrow_days = 4 with sell_price about 60 and seed about 120. Alternatively, limit it to one season (sommer). Also align greenhouse_seeds.lua:11 with the magic store's scarcity (stock 8 / restock 4, or remove glow_berry_seeds from the shelf) so the shelf does not bypass the gate.

**Verification.** Two skeptics, both partly. The numbers hold (12 harvests, ~30.4 g/plot/day against carrot ~11.25). However, analyze_balance.py and game-mechanics-2026-10-17 already model regrowth (about 2.4x per season); only the two 10-18 tables omit it. Regrowing plots still need watering every night, and jars narrow the gap (~40 vs ~73 g/day). Downgraded from P1.

### FARM-02 - Moonflower fails silently: daytime and sprinkler watering shows wet soil but adds no growth (P2, ux)

**Evidence**
- lua/config/game_balance.lua:52 moonflower ... water_window = { from = 20, to = 6 }
- scripts/world2d/farm_grid.gd:189-194 _water() always sets p.watered = true; eligible_water only if in_water_window(hour)
- scripts/world2d/farm_grid.gd:329-330 growth_days += 1 only when p.eligible_water
- scripts/farm/farm_equipment.gd:80 sprinklers call model.water(cell, 6.0): 6.0 is outside the 20-6 window (hour < 6 is false)
- scripts/world2d/farm_view.gd:42 terrain = soil_watered whenever p.watered
- localization/economy.csv:41 ITEM_MOONFLOWER_SEEDS_DESC 'Gror kun om natten' (only grows at night)
- scripts/ui/components/farming_details.gd:3-18 shows seasons, nights and regrowth but not the water window
- lua/items/crops.lua:84 seed 120 / :94 sell 180 (12 days)

**What's wrong.** A moonflower only grows on nights when it was watered between 20:00 and 06:00. Watering in the morning, which is what the tutorial teaches ('Vand hver dag'), and every sprinkler (fixed at 06:00) still set the plot to watered. The soil turns dark, but the night does not count. Nothing on screen or in the seed text says the plant needs watering after 20:00. 'Gror kun om natten' reads as 'it grows by itself at night'. Watering on a rainy or already-watered plot also fails with no whisper (player_2d.gd use_selected: ok=false, no message). Separately, prior M5 (moonflower dominated) is still open. Even when watered correctly it nets 2.1 g/day over its window (120 g seed, 12 nights, 180 g sale), the worst crop in the game despite being the 'uncommon' premium seed.

**Player impact.** A player who waters every morning, or uses sprinklers, sees wet soil on a 120 g crop that never grows. This feels like a bug, and the description gives no explanation.

**Recommendation.** Show moon crops as 'waiting for night' when watered outside the window: a distinct soil tint, or a whisper on the first daytime watering, e.g. new key FARM_MOON_WATER_AT_NIGHT 'Månebønner skal vandes efter kl. 20'. Add the window to farming_details.gd when the crop def has water_window. Rewrite economy.csv:41 to 'Vand efter kl. 20 – gror kun om natten. Høst efter 12 nætter'. Either let quality_sprinkler count for night crops or say in ITEM_SPRINKLER_DESC that it does not. Rebalance (e.g. seed 80, sell 260) so the night chore pays off.

**Verification.** Partly. The silent failure is confirmed. The economics are overstated: about 4.3 g/day over the window, not 2.1, and it is not the worst crop (catnip ~4.0). Watering again after 20:00, rain and fairy dust all count. Prior M5 is still open.

### ECON-02 - Five repeatable quests 'collect' goods with have=true and never take them – one held stack pays about 650 g/day forever (P2, balance)

**Evidence**
- lua/quests/dark_forest_mining.lua:22,30 iron ore x6 / amethyst x2 `have = true`; :34 return_to_smith has no needs/consume; :44 gold 600 + gem_bag + iron_sword; :57 cooldown 7
- lua/quests/crystal_cave.lua:22 crystal_shard x5 have; :33 return without consume; :43 600 g + 3 amethyst + emerald + 2 fairy_dust; cd 7
- lua/quests/night_flower.lua:15 night_bloom x1 have; :19 'return_to_oak' no consume; :29 350 g + fairy_dust + 5 moonflower_seeds; :42 cd 5
- lua/quests/forest_patrol.lua:22 moss x6 have; :26 no consume; :36 220 g + 3 iron_ore; cd 3
- lua/quests/fairy_friendship.lua:22,30 tokens/fairy_dust have; :36 600 g + 5 fairy_dust; :49 cd 14
- scripts/autoload/quest_manager.gd:481-483 on accept, owned items count immediately; :1013-1014 _have_value = EconomyManager.count_item
- localization/quests.csv:47 'Smeden Thorin skal bruge jernmalm og ametyst…' (he needs them, yet keeps nothing)
- contrast: lua/quests/supply_run.lua:32, animal_products, cookie_delivery, rare_mushroom_hunt use `consume = true`

**What's wrong.** Prior review M8 noted that have=true goals can be bought. This is a different defect: in these five repeatables the turn-in never consumes the goods. After the first run, keep 6 iron ore + 2 amethysts, 5 shards, 1 night bloom, 6 moss, 5 tokens + 2 fairy dust. Each later run is just: accept (instantly complete), enter the forest or cave, talk. Sell-value income: mining 1,050 g/7 days ≈ 150/day; crystal cave 1,370/7 ≈ 196/day; night flower 650/5 ≈ 130/day; patrol ≈ 88/day; fairy friendship 1,425/14 ≈ 102/day. That totals about 650 g/day, or about 75,000 g over one 112-day year, which equals the whole home ladder, for no gathering. Related, but legitimate: supply_run consumes goods but can be fed from Brumme's timber yard (wood 10 + stone 6 = 74 g) for 230 g + 300 g of seeds every 2 days.

**Player impact.** The gather loop of the dungeon errands becomes meaningless after the first run, and the story of 'Thorin is short of ore' is broken because he never takes any. It is a large unintended income stream that flattens the economy.

**Recommendation.** Add a turn-in with `needs = {...}, consume = true` to the return objective of dark_forest_mining (iron_ore 6, amethyst 2), crystal_cave (crystal_shard 5), forest_patrol (moss 6) and fairy_friendship (fairy_dust 2; keep the tokens as 'show'). For night_flower either consume the bloom (Oak keeps it for his lantern) or make it non-repeatable. Re-check rewards against vendor value after the change.

**Verification.** Partly. The defect is confirmed. Free income is overstated: fairy_friendship needs 3 help quests per run and crystal_cave forces floors 10-12. Only mining, night_flower and patrol are close to free (~370 g/day).

### ECON-03 - Farm flower patch never spawns (no `flower_patch` row) – wild_flower has no gatherable source; the day-1 quest flower_necklace is stuck for weeks (P2, bug)

**Evidence**
- data/maps/farm.map:59 `@marker w node kind=flower_patch` (placed once, objects row 144 col 14)
- lua/config/resource_nodes.lua:5-23 has no `flower_patch` row (every other map node kind exists)
- scripts/world2d/resource_node_2d.gd:23-24 `if row.is_empty(): return null` – the marker is skipped silently
- lua/items/resources.lua:8 'wild_flower / night_bloom: yields of flower_patch and night_bloom resource nodes (quests flower_necklace…)'
- lua/quests/flower_necklace.lua:13-14 collect 5 wild_flower; :71-73 available from day 1 (fairy_lily, npcs.lua:145)
- lua/recipes/guide_recipes.lua:62-64 flower_necklace = wild_flower 5 + moss 1; lua/recipes/social.lua:6-9 hjertebuket (partner gift) needs wild_flower 3
- remaining sources: scripts/traetoppen/life/crown_cache_2d.gd:22 caches only for the monkey skin (species_perks.lua:31, 1 of 4 random items); lua/social/citizens.lua:31 Stokrose weekly sample only from 3 hearts; heart events lyra h4/h10, birk h6

**What's wrong.** resource_nodes.lua never had a flower_patch row (git: only added in 1ea1ca3a, without it), so the farm's only wild-flower node is dropped at map build. For every hero except Kiki the monkey, wild flowers come only from Stokrose's weekly keeper sample (after 3 hearts, which means 3 weeks of weekly chats) plus 5 flowers from heart events. The repeatable flower_necklace quest, offered from day 1, needs 5 at once, so it realistically cannot be finished before about week 7-8. It then competes with hjertebuket, the partner gift that needs 3, and with five NPCs who love the flower as a gift.

**Player impact.** A child accepts Lily's necklace quest on day 1 and finds no flowers anywhere for weeks. The marriage gift (Hjertebuket) is unexpectedly scarce.

**Recommendation.** Add `flower_patch = { art = "<flower prop>", hp = 1, forage = true, item = "wild_flower", amount = { 1, 3 }, respawn_days = 1 }` to lua/config/resource_nodes.lua. Consider 2-3 more patches in Trætoppen/Hyggebyen maps, and a validator rule that every `node kind=` marker in data/maps resolves to a resource_nodes row.

**Verification.** Confirmed against the cited code and data.

### ECON-04 - Greenhouse seed shelf: all seeds 99/day, open 24/7, cheaper glow berries, and it buys every item at full price (P2, balance)

*Merged:* FARM-03 (P3, Farming): Greenhouse seed shelf: open 24/7 with 99 of every seed, cheaper than town, and the only source of two winter crops.

**Evidence**
- lua/shops/greenhouse_seeds.lua:3-14 keeper merchant_pip, every seed `{ stock = 99, restock = 99 }`, no `buys`, no open_weekdays
- data/maps/greenhouse.map:21 `@marker S greenhouse action=seeds`; scripts/farm/greenhouse/greenhouse_2d.gd:46-47 opens the shop
- lua/buildings/*.lua claim seed_shop…lantern_house but not greenhouse_seeds → scripts/towns/hours.gd:157-159 returns null → shop_system.gd:142-148 always open
- scripts/economy/shop_system.gd:270 an empty `buys` list buys every category: furniture, gems, weapons, clothing
- designed scarcity it overrides: lua/shops/seed_shop.lua:32 moonflower 8/4; lua/shops/magic_store.lua:24 glow_berry_seeds 8/4 at ×1.1 (105 g) vs 95 g here
- lua/config/farm_equipment.lua:10-15 greenhouse: 1,500 g + 8 glass, home tier 2 (available in week 1-2)
- [FARM-03] lua/shops/greenhouse_seeds.lua:3-18 every seed incl. moonflower and glow berry at stock 99 / restock 99, buy_multiplier 1.0
- [FARM-03] lua/shops/seed_shop.lua:32 moonflower_seeds = { stock = 8, restock = 4 }; lua/shops/magic_store.lua:13,24 glow berry x1.1, stock 8 / restock 4
- [FARM-03] lua/buildings/hyggebyen.lua:16 froebutikken hours = { open = 8, close = 18, closed = { 6 } }; greenhouse_seeds is claimed by no building, so ShopHoursGate.open_override returns null and the shelf is always open (shop_hours_gate.gd open_override)
- [FARM-03] lua/shops/seed_shop.lua:27-36 sells frost_kale but neither snow_turnip_seeds nor snowdrop_seeds
- [FARM-03] localization/farm_site.csv:58,62 snow seed descriptions: 'Dyrkes om vinteren eller hele året i drivhuset'
- [FARM-03] data/maps/greenhouse.map:21 '@marker S greenhouse action=seeds' (shelf only inside the greenhouse)

**What's wrong.** After a cheap tier-2 build, the farm has an unattended shelf that sells every seed in bulk with no Sunday or hours closure, undercuts Zephyr's glow-berry seeds by 10%, and makes the 8/4 shelves of the seed shop and magic store irrelevant. Because it has no `buys` list, it is also an instant-pay sell point for any sellable item (rare furniture, gems, weapons) at the 1.0 multiplier, at 02:00 or on a festival day. The same no-`buys` rule makes the bakery, smithy, animal store, magic store, seed shop and festival markets buy everything. As a result, the `buys` specialisation of the home shops and the opening hours have no effect on selling.

**Merged findings add.** FARM-03 adds that snow_turnip and snowdrop seeds are sold only on this shelf, although their descriptions (farm_site.csv:58,62) imply outdoor winter growing. Outdoor winter farming without a greenhouse is therefore frost kale only.

**Player impact.** Town shops' hours, closed days and keepers stop mattering for the economy. The glow-berry plus keg strategy can scale with no supply friction from week 2.

**Recommendation.** Give greenhouse_seeds `buys = {}` with sell_multiplier 0, or `buys = { "seed" }`. Limit stock to the winter seeds (snow_turnip, snowdrop, frost_kale) plus small amounts of others (e.g. 10/5), and price glow_berry_seeds at magic-store parity. Give the town shops category-appropriate `buys` lists (bakery: food, crop, product; smithy: weapon, tool, mineral, gem; magic: gem, magic, forage).

**Verification.** Partly. 24/7 opening and every crop on the shelf are deliberate (DT44/C28) and pinned by `farm_automation.gd:23-27, 203`. The real problems are bulk stock of seeds that are meant to be scarce, the glow-berry undercut, and universal instant buyback that bypasses the bin's category filter. A fix must keep every seed or update the test. FARM-03: Partly; the no-hours design is deliberate. Downgraded from P2.

### ECON-05 - The progression model (BALANCE.md, about 52 h typical) is stale and contradicts the data; approximate curve attached (P2, tech-debt)

**Evidence**
- docs/features/BALANCE.md:13-17 typical day 345 / casual 919 / dedicated 185; :25 'The binding constraint is money from tier 5 on'
- tools/features/sim/balance_sim.py:418-425 builder_yard materials always in stock; `rg keg|preserve|regrow|glow_berry|greenhouse` finds nothing in the sim
- lua/config/game_balance.lua:53 glow_berry regrow_days 4 (summer and autumn)
- lua/items/farm_equipment.lua:18 juice_glow_berry 450 vs raw 150; lua/config/farm_equipment.lua:7 keg 3 days; seed_shop keg 500 g, restock 3/day
- lua/data/home_tiers.lua:58,129-131,167,204,241-245,282,319,356 gates (quests, hearts, hygge)

**What's wrong.** The model includes no glow-berry regrowth, preserves jars or kegs, greenhouse, winter crops, or keep-the-goods repeatable quests, and it assumes unlimited builder-yard stock. Its 'money binds' conclusion is therefore wrong in both directions. Approximate curve from the current data (dedicated player, estimates):
• Day 1: 900 g (start 500 + intro_lottery 250 + forste_dage 150). Tier 2 costs about 550 g including materials, so it can be built that day.
• Days 5-7: carrots on 68 plots, about 600 g/day. Tier 3 (about 900 g).
• Day 8 at the earliest: tier 4 (Lyra 2 hearts = 2 weekly chats).
• Days 10-20: tier 5 (first_animal plus 4 copper plates from the weekly rotation).
• Days 20-40: tier 6, gated by crystal_cave (floors 10-12).
• Summer (days 29-56): glow berries + kegs ≈ 2.5-3.5k g/day farm, + about 650 g/day from repeatables, + dives. All tier gold (74k + about 10k materials) is plausibly in hand by about day 45-60.
• Materials gate: tier 7 needs glass ≥ day 31 and marble median day 21 / 90th percentile day 49. Tier 8 needs brick ≈ day 87. Tier 10 needs roof tiles ≈ day 105, glass ≈ day 111 and marble median day 91 / 90th percentile day 133.
So from tier 7 on, the late game is paced by restock and rotation, not by gold. After the castle, income can reach 10k g/day with almost no sinks left (furniture about 43k, MAX_GOLD 999,999).

**Player impact.** Pacing decisions such as home_cost_scale and quest rewards are being tuned against a model that no longer describes the game. The real walls (materials) and runaway sources (processing, free repeatables) are invisible.

**Recommendation.** Extend tools/features/sim/balance_sim.py with shop restock and rotation limits, the regrow/keg/jar/greenhouse income paths and the actual repeatable consume semantics. Re-run it and update docs/features/BALANCE.md. Add a long-term gold sink (e.g. coop/barn tier art, a town donation board, furniture commissions) or cap keg throughput (keg days 4-5, or a per-farm machine limit).

**Verification.** Confirmed. The '+650 g/day repeatables' figure inherits the overstatement in ECON-02.

### COMBAT-01 - In the forest a click or gamepad X always uses the selected hotbar item, so attack, its input buffer and the Cozy assist's auto-swing never fire (P2, bug)

**Evidence**
- project.godot:152-163: `use_tool` and `attack` both bind only LMB (button_index 1) and joypad button 2
- scripts/world2d/player_2d.gd:194: `elif event.is_action_pressed("use_tool"):` ... `use_selected()` is checked BEFORE the action-area branch
- scripts/world2d/player_2d.gd:199-201: `elif _is_action_area(): if event.is_action_pressed("attack"): combat.request(&"slash")` (unreachable for LMB/X)
- scripts/world2d/player_2d.gd:386-389: use_selected: `"consumable", "food": ok = GameData.eco().use_item(item)` / `"weapon": return combat.swing(item)`
- scripts/world2d/player_combat_2d.gd:66-70,95: `attack_held` is set only by request(&"slash"); auto-swing requires attack_held
- lua/config/dungeon_run.lua:27: cozy preset `assist_auto_swing = 1`; dungeon_run.lua:14 `feel.buffer = 0.15`
- lua/data/starter_kit.lua:9-18: default hotbar = hoe, can, axe, pickaxe, sword_rusty, scythe, seeds, lantern_oil (8 slots)
- tests/sections/forest.gd:124-127 only asserts that use_tool works in the action area; no test presses a real attack input

**What's wrong.** The forest HUD shows a 'slash' ability on `attack` and the tutorial says 'Klik: slå'. But every real attack input also matches `use_tool`, and the `use_tool` branch comes first in the elif chain, so in Mørkeskoven a click or X runs use_selected() on the selected hotbar item. A swing only happens when that item is a weapon. With the pickaxe or axe selected (needed for the crystals and trees on every floor) the click hits a node or whispers that the tool is too weak. With seeds or the hoe it does nothing. With a tonic, lantern oil or tornebær selected the click consumes the item. combat.request() is never called, so the 0.15 s input buffer never works and attack_held is never set. The Cozy preset's assist_auto_swing therefore can never work. The swing also uses the hotbar weapon, while the picker lines, the weak-weapon hint and the chest-sense effect read the separately equipped weapon slot.

**Player impact.** A player who arrives from the farm holding the hoe, or who has just mined a crystal, clicks at a bat and nothing happens, or a tonic is drunk. Children and less dexterous players who pick the Cozy preset get no auto-swing although the settings say it is on. Swings pressed during the cooldown are dropped instead of buffered, so combat feels unresponsive.

**Recommendation.** In player_2d.gd `_unhandled_input`, check `_is_action_area()` before the `use_tool` branch. In the forest, route the shared press to `combat.request(&"slash")` (with the equipped weapon) unless the selected item is a tool aimed at a node in reach (use_selected for tool/pickaxe/axe only). Never consume an item on a forest click. Alternatively, auto-select the weapon slot in DungeonFloors.start_run. Add a combat test that drives a real `InputEventMouseButton` in the forest with the pickaxe and with a tonic selected, and one that checks auto-swing under the Cozy preset.

**Verification.** One skeptic confirmed, one partly. The routing bug is confirmed: `combat.request(&"slash")` is unreachable and auto-swing is dead. With a weapon selected the swing still works through use_selected, so what breaks is the buffer, Cozy auto-swing and accidental item use. Downgraded from P1. Tests miss it because `tap()` sends an InputEventAction.

### COMBAT-03 - Hitting a dazed boss cuts its punish window from 1.5–1.8 s to ~0.4 s and can stack its attacks; fairy light cancels boss attacks through armor (P2, bug)

**Evidence**
- scripts/dungeon_run/bosses/boss_base.gd:83-84: after each attack `remaining = float(cfg.dazed)` / `cooldown = remaining` (1.8/1.7/1.5 s, bosses.lua:4-6)
- scripts/world2d/enemy_2d.gd:320-323: `var armoured := armor and state in [S.WINDUP,S.LUNGE]` - in RECOVER (dazed) a hit applies 550 knockback and `stun(.38)`
- scripts/world2d/enemy_2d.gd:305-312: stun() sets `state = S.STUN`, `remaining = .38`, `cooldown = .4` (overwrites the dazed cooldown)
- scripts/dungeon_run/bosses/boss_base.gd:42: `if state == S.CHASE and cooldown <= 0:` -> next pattern ~0.4 s after the first hit
- scripts/dungeon_run/bosses/boss_base.gd:64-68: rain/cloud keep the boss in RECOVER for up to ~5.3 s while the AttackSequence keeps landing
- scripts/world2d/player_combat_2d.gd:264-267: fairy light calls `enemy.stun(1.6)` on every enemy incl. bosses (cancels WINDUP via _cancel_attack)
- docs/design/dungeon_v2_workpackages.json:1077: 'vulnerable dazed window after every attack'

**What's wrong.** The boss loop is meant to go: telegraph, dodge, then a dazed window to punish the boss. In practice the first hit in that window replaces RECOVER with a 0.38 s STUN and sets the cooldown to 0.4 s, so the boss starts a new pattern about 0.4 s later. Left alone it would have waited the full 1.5–1.8 s. Hitting the boss therefore makes it attack sooner. Slow families (club 0.54 s, staff 0.50 s, spear 0.43 s) get one hit per window instead of the 3–4 the window was tuned for (C4's 8/11/12-swing math assumed a full window). During the Konge's rain or the cloud patterns, a hit lets the boss start a dash or quake while the earlier hazards are still falling. Separately, the 'armor' flag never stops the fairy light, which stuns a boss mid-windup for 1.6 s and up to 2.4 s with light_boost. With the minimum 3 s cooldown (staff_star plus an amethyst gem) that is close to a permanent lock.

**Player impact.** Boss fights feel erratic: attacking at the right moment is punished with an instant counter, while spamming the fairy light trivialises the bosses late on. Neither matches the readable telegraph, dodge and punish rhythm the design describes.

**Recommendation.** In DungeonBoss2D, override take_hit/stun: while RECOVER (dazed), take damage and flash but do not change state, remaining or cooldown. Optionally allow knockback, or skip it entirely for bosses. While an AttackSequence child is alive, do not start a new pattern. Decide whether the fairy light should only shorten a boss windup (for example to 0.5 s) rather than stun it, and add bosses.gd checks for 'hit during dazed keeps remaining' and 'light vs boss'.

**Verification.** Partly. The mechanism is confirmed. 'One hit per window' is overstated, because armour still lets HP damage land during the windup. The opposite failure, fast weapons stun-locking a boss, also exists. The fairy-light lock maths holds.

### COMBAT-04 - Per-family weapon knockback is never applied; every hit pushes enemies a hard-coded 550 (P2, bug)

**Evidence**
- lua/config/dungeon_run.lua:16-20: knockback sword 433, club 693, spear 346, dagger 260, staff 433
- lua/config/dungeon_run.lua:14: `feel.knockback_enemy = 550` (also unused)
- scripts/world2d/enemy_2d.gd:322: `ground_velocity = Iso.to_ground(global_position-from).normalized()*550`
- scripts/world2d/player_combat_2d.gd:141-143: knockback copied into `_weapon` but take_hit receives only (damage, from, attacker)
- scripts/world2d/player_combat_2d.gd:68 reads `feel.input_buffer` while the Lua key is `buffer` (harmless today, same default)

**What's wrong.** The five weapon families are distinguished in data by damage, timing, reach, arc and knockback. Knockback is read into the swing info but Enemy2D.take_hit ignores it and always applies 550, and the `knockback_enemy` key is dead data too. The club's crowd-control push (693) and the dagger's stay-in-range low push (260) do not exist, and the dagger's 158 px reach is often shorter than the forced push (about 137 px of travel per stun), which hurts its intended chain play. A few other feel keys are hard-coded duplicates (shake 2.0/4.0 at player_combat_2d.gd:221,301; dodge-cancel 0.4 at :227), so tuning them in Lua has no effect.

**Player impact.** The families feel more alike than designed, the dagger is weaker in practice, and tuning knockback in Lua silently does nothing.

**Recommendation.** Pass the attacker's `_weapon.knockback` (or the family value) into take_hit, for example through a `knockback` parameter or by reading attacker.combat._weapon, and use it instead of 550. Fall back to `feel.knockback_enemy`. Wire the shake, dodge-cancel and buffer keys to their Lua names, and add a weapons.gd check that knockback differs per family.

**Verification.** Confirmed against the cited code and data.

### COMBAT-06 - Legendary weapons arrive only after the content they could help with is beaten; the power curve tops out at rare (P2, design)

**Evidence**
- lua/config/dungeon_run.lua:7: expected_weapon tops at 24 on floor 12; :8 `deep_step` 'only used when floors above 12 exist'
- lua/config/dungeon.lua:15: `max_floor = 12`
- lua/items/weapons.lua:99,141,245,349,453: rare sword 22 vs legendary sword_moon 42, club_trunk 57, spear_root 45, staff_star 47
- lua/data/loot_tables.lua:857,870: the legendaries come only from the floor-8 and floor-12 boss pools (repeat kills only, reward_rules.gd:20-39)
- scripts/dungeon_run/combat_rules.gd:20-24: weapon_range already rates a rare weapon (22) as good for floors 1-12

**What's wrong.** Enemy HP is normalised to expected_weapon, so a rare weapon (about 22) already clears every floor at the intended pace. Uniques (30–40) overshoot floors 7–12, and the Konge legendaries (sword_moon, staff_star) can only drop after the final boss has been beaten at least once and a week has passed. Nothing exists beyond floor 12: no deeper floors, no harder repeat mode and no stronger boss variants. The 5-tier weapon ladder therefore has no reason to exist above rare, which weakens the owner's 'weapons in 5 rarity tiers' progression.

**Player impact.** Finding a legendary weapon is a trophy with nothing left to test it on, and the endgame dive loop gets easier instead of more interesting.

**Recommendation.** Add post-game depth: activate deep_step by allowing floors 13+ as an endless 'Dybet' band with escalating expected_weapon, or add a 'night/hard' re-run of floors 10–12 after the Konge with stronger enemy HP and the legendary pools. Alternatively, move one legendary per family into floor 8–12 sources so it lands before the Konge.

**Verification.** Confirmed against the cited code and data.

### COMBAT-07 - Crystal nodes drawn as amethyst, emerald or moonstone never give those gems in the dungeon, while quests send the player to mine them (P2, consistency)

**Evidence**
- lua/config/resource_nodes.lua:11-14: amethyst/emerald/moonstone/crystal_shard nodes, item = the gem, pickaxe power 2/2/3/1
- lua/config/dungeon_loot.lua:57-61: in the dungeon every crystal kind is `alias = "crystal"` -> rough stone 30 %, else glimmer dust
- scripts/world2d/resource_node_2d.gd:142-150: on a floor (>0) deplete() uses LootService.node_loot, never cfg.item
- lua/config/dungeon.lua:27: `hard_nodes = { "moonstone" }` - the generator guarantees moonstone nodes that yield no moonstone
- localization/quests.csv:47-48: QUEST_DARK_FOREST_MINING 'Thorin skal bruge jernmalm og ametyst fra Mørkeskoven' (lua/quests/dark_forest_mining.lua:26-29 needs 2 amethyst)
- localization/features_quests.csv:15: 'Find en månesten i Mørkeskoven' (moonstone_crown)

**What's wrong.** Floors show four kinds of gem crystals, require stronger pickaxes for the 'better' ones (moonstone needs power 3), and are listed per floor as amethyst, emerald or moonstone. Every one of them yields the band's unknown stone or glimmer dust, so mining a moonstone gives the same result as mining a shard. The gems themselves come only from Fru Ugle's appraisal lottery (amethyst is about 1/6 of uncommon results), krystalugle drops, the boss first-kill extras or the magic store. Thorin's early quest asks for amethyst 'from Mørkeskoven', which mining there never produces.

**Player impact.** Players learn that the visible crystal colour and the pickaxe-power gate mean nothing, and they get stuck on 'mine amethyst / find a moonstone in the forest' quests until they think of appraising or buying.

**Recommendation.** Make each crystal kind roll its own gem with a small chance, for example amethyst node -> amethyst 15 % / rough stone / dust, moonstone node -> moonstone 10 %, in dungeon_loot.node_yields, with the depth band scaling the chance. Or give all crystals one neutral art and a 'Krystal' name, and reword the quests ('bring en ametyst – Fru Ugle kan slibe dem') to point at appraisal.

**Verification.** Confirmed against the cited code and data.

### COMBAT-08 - Enemy and boss variety is thin and the difficulty curve is flat after floor 4; the final boss hits softer than ordinary enemies (P2, design)

**Evidence**
- lua/config/enemies.lua:5-11: 7 kinds on 5 sprites (sporesvamp = lysesvamp tinted, krystalugle = ugleoje tinted); lysesvamp is a harmless critter
- lua/config/dungeon.lua:43: floors 1-3 mix = bat 60 / tornebusk 40, and tornebusk only shoots `from_tier = 2` (enemies.lua:7)
- lua/config/bosses.lua:4-6: all three bosses `visual = "snurresvamp"` + tint; scripts/dungeon_run/bosses/{snurre,gloed,konge}.gd share the dash core
- lua/config/dungeon_run.lua:10: damage ladders identical for tiers 2 and 3 (standard/heavy {1,2,2,2}); scripts/dungeon_run/combat_rules.gd:28-31 normalises HP to expected_weapon
- lua/config/bosses.lua:4-6 `damage = 1` and attack_sequence.gd:29 `impact.damage = 1`, while floor 10-12 trash deals 2 (light tier 4 = 2, keeper lance 2: enemies.lua:11)
- scripts/dungeon_run/dungeon_run.gd:51-62: +1 heart per first boss kill

**What's wrong.** At the intended gear every enemy takes the same 1/2/3 hits on every floor, and damage only steps from 1 to 2 half-hearts at floor 4. Floors 4–9 therefore play alike apart from the enemy mix, while the player gains a heart after each boss. Floors 1–3 have only bats and non-shooting bushes. The three bosses are recolours of one sprite with a shared dash. The Svampekonge deals 1 half-heart per hit, half of what the owls and bats in its own arena deal, and it drops two healing berries mid-fight. The rest of the dungeon's variety (hidden spots, lake chests, four surprise types at about 3.6 % per chest, whispers) is front-loaded: once the 27 keepsakes are claimed, floors contain only ordinary chests.

**Player impact.** The middle and late dungeon feels repetitive, and the climax is the gentlest fight on its own floor, which undercuts the action-adventure half of the pitch.

**Recommendation.** Give each band one signature enemy and introduce mosfroe or sporesvamp earlier. Give the Konge `damage = 2` (the cozy assist already clamps damage to 1) or a unique pattern. Add repeatable floor events after the keepsakes are gone, for example a Natteblik errand, a timed glow-ring and a rare wandering merchant. Plan distinct boss bakes (the design notes this as P21).

**Verification.** Confirmed against the cited code and data.

### COMBAT-09 - Club's stun effect still does nothing against armored enemies and bosses, and ordinary hits already stun everything else (prior C2 still open) (P2, balance)

*Merged:* PRIOR-18 (P3, Status of prior review findings): Club stun is still null against every boss (only the description was fixed).

*Prior review:* mechanics-story-deep-dive-2026-10-18 C2 'Club's signature stun is null vs every boss'. Re-verified against current code: still open.

*Prior review (PRIOR-18):* mechanics-story-deep-dive-2026-10-18 C2 - only the description was fixed; weapon_fx.gd:58 is unchanged since 4b9de7d1.

**Evidence**
- scripts/combat/weapon_fx.gd:58: `if bool(enemy.get("armor")): return` (unchanged)
- lua/config/bosses.lua:4-6 all `armor = true`; lua/config/enemies.lua:7,10 tornebusk/sporesvamp `armor = true`
- scripts/world2d/enemy_2d.gd:320-323: every non-armoured hit already applies `stun(.38)`
- lua/items/weapons.lua:208,231: wpn_club_mushroom stun_chance p 0.25 s 0.5; wpn_club_thornberry p 0.5 s 0.6
- [PRIOR-18] scripts/world2d/enemy_2d.gd:100 armor defaults to is_boss, and DungeonBoss2D (boss_base.gd) extends Enemy2D and inherits that path
- [PRIOR-18] scripts/world2d/enemy_2d.gd:320-322 the base stun(.38) is skipped only when the target is armored and in WINDUP or LUNGE, so armored enemies are also stunned by ordinary hits outside those phases

**What's wrong.** Re-verified against the current code: still open. It is also worse than first reported. Against the non-armored kinds, every hit from any weapon already stuns for 0.38 s, so the club's 25 % or 50 % chance at 0.5–0.6 s adds about 0.1–0.2 s. Against the armored kinds, the only targets where a stun would matter, the effect is switched off. The rare and unique club's signature effect is close to worthless everywhere, and the item text does not say so.

**Merged findings add.** PRIOR-18 sharpens the evidence above. The base stun applies to every hit unless the target is armored and winding up or lunging. Against bosses outside those phases, the club would add only the same 0.1-0.2 s as elsewhere; what is really lost is the chance to interrupt a windup, which is what the 'interrupt a WINDUP once per cycle' recommendation would restore.

**Player impact.** Players who pick the club for its stun get almost nothing for it, including in the boss fights where it should shine.

**Recommendation.** Let stun_chance work on armored targets at a reduced duration (for example ×0.5, never during LUNGE). Or make it interrupt a WINDUP once per cycle. Then state the rule in ITEM_WPN_CLUB_*_DESC.

**Verification.** Confirmed against the cited code and data. PRIOR-18: Confirmed.

### COMBAT-10 - No dungeon material is above rare, although the owner promised rare, unique and legendary materials (P2, missing-feature)

**Evidence**
- lua/config/rarity.lua:2,63,78: rarities 'shared by furniture, clothing and materials', unique material_price 600 / legendary 2500 defined
- lua/items/dungeon_materials.lua:116-136: dng_moon_silver / dng_crystal_root are the top tier (rare); :151,169,187 the only 'unique' materials are the three boss runes, consumed by runehvaelvingen (loot_tables.lua:768-776)
- Scratch parse of lua/items/*.lua: category material/building_material legendary = 0, unique = 3 (runes only)

**What's wrong.** Furniture, clothing, gems and weapons span all five tiers, but crafting materials stop at rare. The only 'unique' materials are key-runes that disappear when used, and nothing anywhere is a legendary material. The rarity table already prices unique and legendary materials, which suggests they were planned.

**Player impact.** The adventure loop never produces the special materials the pitch advertises, and late crafting has no aspirational inputs.

**Recommendation.** Add 2–3 unique materials (for example 'Svampekongens spore', 'Månesølv-kerne') as boss-repeat or lake-chest drops, and one legendary material (for example 'Skovhjerte-rav') from the Konge pool. Gate one top furniture or weapon recipe in lua/recipes/dungeon.lua on them so they have a use.

**Verification.** Confirmed against the cited code and data.

### SOCIAL-01 - Shopkeepers leave open shops on two festival days (Sofus' badedag closes nothing; Bagedagen's host keeps the open bakery) (P2, bug)

**Evidence**
- lua/festivals/fixed/badedagen.lua:31,34,39 - closes = "none", from = 10, to = 18 (sommer 27 = Saturday)
- scripts/social/social_data.gd:278-300 - every home citizen of the area joins the roster (cap 15). Only keepers of a stays_open shop are skipped, and the host never is
- lua/buildings/traetoppen.lua:17 (uglehulen 12-20, closed Mon/Thu), :26 (postkontoret 9-17, closed Sun), :73 (torvestanden 10-16, Sat/Sun); lua/buildings/ext.lua:35 (torvekroen 11-23). All of them are open on a Saturday
- scripts/social/social_manager.gd:900-925 override_for - attendees stand at the festival post from one hour before the start (09:00) until the end. relationship_flow.gd:110-119 keeper_departure only makes them leave early when the shop is open after the festival ends
- lua/festivals/fixed/bagedagen.lua:36,40-41 - host = baker_maja, stays_open = { bakery } (vinter 21 = Sunday; bakery open 7-17)
- tools/social/core/validate_social.py:317-320 - the project's own validator warns about this exact case: 'the host ... keeps the shop that stays open (... the shop would have no keeper)'
- scripts/towns/shop_counter.gd:101-110 - the 'shop' counter opens ShopSystem.open_shop even when no keeper is in the room

**What's wrong.** On Sofus' badedag (closes = "none"), every Trætoppen citizen joins the festival roster, and override_for puts them at the bath-house gather posts from 09:00 to 18:00. Their shops stay open under their normal hours:
- Postman Pip: Postkontoret is open 9-17 with nobody there all day.
- Fru Ugle: Uglehulen is open from 12 with nobody there until about 17:30.
- Kvak: Torvekroen is open from 11 with nobody there until about 17:45.
- Brumme: his weekend Torvestanden stall is open 10-16 with nobody there for the whole window.
On Bagedagen the host, Maja, stands on Hyggetorvet from 11:00 while her bakery is listed in stays_open and is open until 17:00. In both cases the counter still sells, but the talk/gift slots are disabled. The keeper-hours check (towns_validate.keepers_cover_hours) only tests ordinary days, so these festival days are never checked.

**Player impact.** The player walks into an open post office, inn or bakery and finds nobody behind the counter, yet can still buy. This is exactly the 'shopkeeper absent while the shop is open' inconsistency the owner asked about. It breaks the walk-in shop fantasy on two of the nine festival days.

**Recommendation.** badedagen: either switch to closes = "all" with stays_open = { "badehuset" }, or skip keepers whose building is open during the window in SocialData.festival_roster (the same rule stays_open already uses). bagedagen: drop "bakery" from stays_open (bakery goods are sold at fest_bake_market anyway), or move hosting to Bodil. Add a test that runs keepers_cover_hours against festival_on(td) days, using override_for.

**Verification.** Confirmed. Torvekroen has no `shop`, so it is an empty inn rather than a self-serve counter.

### SOCIAL-02 - Silke's 8-heart scene 'Det sidste lys' can only be triggered in the first 24 game minutes after waking (12 real seconds); almost no player will see it (P2, story)

**Evidence**
- lua/events/ghostfam/natlys.lua:458-468 - ev_ghostfam_silke_h8: area = "traetoppen", when = "hour:6-6.4&!fest:any&at:ghostfam_silke"
- lua/routines/ghostfam/ghostfam_silke.lua:14 - Silke is at traetoppen.f_lamp only 06:00-06:25 (the 25:45 lamp block ends at the 02:00 pass-out)
- lua/config/dungeon.lua:16 - wake_area = "farm"; lua/config/game_balance.lua:84-86 - 2 game minutes per real second, so 0.4 h = 12 real seconds
- data/towns/routes.json - farm.porch to farm.gate_traetoppen is 2,860 px, and traetoppen.gate_farm to f_lamp is 3,284 px (about 6,100 ground px). lua/config/game_balance.lua:16-30 - run 450 px/s with 100 energy at 15/s (6.7 s of sprint), walk 285 px/s, so the trip takes about 17 s
- docs/design/GHOST_FAMILY_ADDENDUM.md:413 - the design offered an alternative ('or, after midnight, the vigil at the forest lift'), which was not implemented

**What's wrong.** Every game day starts at 06:00 on the farm (after a pass-out or after sleeping). The scene only fires if the player talks to Silke at the Trætoppen lamp before 06:24. Walking straight there takes about 17 real seconds (about 15 s even for a ghost with its cheaper sprint), against a 12-second window. The only way in time is to sprint to the bridge, use the Rejsestolpe stop 'hyggebyen' (if already unlocked) and walk the last 386 px. Nothing in the game hints at this. Unlike the other heart scenes, this window cannot be waited out in place, because the player never starts a day in Trætoppen. The design's after-midnight alternative was never implemented.

**Player impact.** In practice Silke has only one heart scene (h4). Her emotional beat at 8 hearts is lost for nearly every player, even though her hearts keep rising.

**Recommendation.** Widen the window to include the night vigil, as designed: e.g. when = "hour:23.5-25.7&!fest:any&at:ghostfam_silke" while she makes her lamp round / stands at f_lamp (ghostfam_silke.lua:20-23), keeping the dawn variant as an extra. Alternatively, make the dawn scene start automatically when the player first enters Trætoppen before 07:00 and Silke is on her f_lamp/f_bench blocks (until 06:45).

**Verification.** Confirmed against the cited code and data.

### SOCIAL-03 - Festival contests can only be won by the most expensive item in the category; themed entries never place, and a win is worth less than the entry (P2, balance)

*Merged:* PRIOR-16 (P3, Status of prior review findings): Festival rewards are still token: 20 points plus a few seeds.

*Prior review:* mechanics-story-deep-dive-2026-10-18 FE2 (festival rewards thin) - still open: attend.points = 20 and seed/honey prizes are unchanged. The scoring problem described here is new.. Re-verified against current code: still open.

*Prior review (PRIOR-16):* mechanics-story-deep-dive-2026-10-18 FE2 - still open as a design suggestion, not an oversight; see below.

**Evidence**
- scripts/social/events/festival_activities.gd:9-10 - score = sell_price x (1 + 0.5 x rarity pips); :38-53 - the three bars are 0.5 / 0.75 / 1.0 x the BEST score in the category, each +/-15%
- lua/festivals/fixed/bagedagen.lua:8-12 'Småkagekonkurrence' and honningdagen.lua:8-12 'Honningkonkurrence' use select = "category:food", whose only items are apple 5, cookie 10, flour 5, honey 12 and honey_cake 90 (uncommon)
- Calculation: honey_cake scores 135, so the lowest (third-place) bar is 57-78. The best possible cookie score is 11.5 and honey 13.8, so both always come 4th. Hoestfesten 'Græskarkonkurrence' (category:crop): best is moonflower at 270, so a pumpkin (136-184) can never reach the first-place bar (230-310). Blomsterkonkurrence (category:forage): won by rare_mushroom (52.5); wild_flower (2) and fern never place
- scripts/social/events/festival_stage.gd:174-189 - the entry is consumed. bagedagen first prize is honey x3 (36 g sell value) for a 90 g honey_cake; hoestfesten's is pumpkin_seeds x3
- localization/social_sys.csv SOC_EV_CONTEST_RESULT 'Dit bidrag fik plads nummer %d.' prints 'plads nummer 4' with no explanation when nothing was won
- [PRIOR-16] every lua/festivals/fixed/*.lua has attend points 20; only 5 of the 9 festivals have contest prizes (aarsskiftet, badedagen, midsommerlanterner and vinterlysene have none); blomsterfesten's first prize is sunflower_seeds x4, 28 g at sell value
- [PRIOR-16] scripts/social/events/festival_activities.gd:12-41 and SocialValidator SV14 cap first prize at min(2x the cheapest winning entry, 400 g), second ≤ 0.7x first, third ≤ 0.4x first, and refuse keepsake, unique and legendary prizes (tests/sections/festival_activities.gd:22-24, social_fest_content.gd:50); docs/design/TOWNS_FARM_SOCIAL_CHANGELOG.md:63-65 records the exploit behind the cap

**What's wrong.** Contests rank entries by the sell value of the item, weighted by rarity, compared against the most valuable giftable item in the whole category. The festival's own theme item can never win: a cookie at the cookie contest, honey at the honey contest, a flower at the flower contest, a pumpkin at the pumpkin contest (at most 2nd place). One item dominates each category (honey_cake for both food contests). Because the entry is used up and the prize caps are small, winning loses the player money. Getting 4th place tells the player nothing useful.

**Merged findings add.** PRIOR-16 adds that the small prizes are deliberate and enforced in code: SV14 was added after 'five contests a year could pay up to 5 x 1,670 g'. A festival-exclusive rare piece (about 600 g sell value) would break SV14, so any exclusive prize would have to be cosmetic, unsellable and not a keepsake, and that needs a design decision. The prior '~120 g of seeds' used buy prices; at sell value it is 28 g.

**Player impact.** A child who brings their best cookie to the cookie contest always loses, with no explanation. The contests feel arbitrary and teach the player to sell rather than to take part. This adds to the earlier 'thin festival rewards' finding.

**Recommendation.** Make the themed item the reference: add an optional `theme = { cookie = 1.0, honey_cake = 0.8 }` (or a narrower select such as "item:cookie,honey_cake") and compute the bars from the theme's own value. Also let quality or rarity of the themed item matter. Return the entry or give a participation token. Raise the first prize to something unique per festival (a decor piece or recipe), still within the SV14 cap. Change the copy for 4th place to 'Ikke en præmie denne gang - men tak for dit bidrag!'.

**Verification.** Confirmed. The formula is exactly the spec (TOWNS_FARM_SOCIAL_ADDENDUM.md:442), so this is a flaw in the spec. FE2 is still open. PRIOR-16: Partly. The facts are confirmed, but the thin prizes are a capped design choice (SV14), not an oversight.

### SOCIAL-04 - All 80 heart-band chat lines and all 66 bark lines are never shown, and the chat lines are fill-in-the-blank templates (P2, story)

*Merged:* CAST-03 (P2, Side quests): Heart-milestone chats (CHAT_H2-H10) and barks are written but no code reads them; GREET_H2 promises a story that never comes; GAP-GHOST-FAMILY-ARC-01 (P2, Ghost family arc and Blund hide-and-seek against GHOST_FAMILY_ADDENDUM): Heart-ladder chat beats and barks are never shown, so the family's middle and late arc is dead copy.

*Prior review:* game-mechanics-2026-10-17 social-writing note ('25 citizens share each of two exact bark lines') - still open, and the barks also turn out to be unused.. Re-verified against current code: still open.

**Evidence**
- scripts/social/talk/dialogue_bridge.gd:18-27 - the only runtime use of SocialTalk.pick is with the slots "FIRST" and "GREET" (plus GIFT_* in gift_flow.gd:178). No code builds a CHAT_H* or BARK key (rg over scripts/ and lua/ finds none; the only CHAT keys used are Dyne's two voiced lines)
- scripts/world2d/npc_2d.gd:392 - the NPC bubble shows only ! / heart / note symbols, never bark text
- tools/social/data/build_copy.py:53 - generates SOC_<NPC>_CHAT_H{2,4,6,8,10}_1 from one template, filling in place and detail
- localization/social_talk.csv:8,10,213,285 - e.g. 'Ved min blomsterkrans finder jeg altid en rolig stund. Du må gerne blive lidt.' (Lily), 'Ved min rygsæk finder jeg altid en rolig stund...' (Rasmus). The H4 and H8 templates are shared by 25 NPCs each, and H2/H6/H10 by 10
- localization/*.csv - 'En stille stund.' and 'Nogen kommer forbi.' are each used as the BARK line for 25 NPCs
- [CAST-03] scripts/social/talk/social_talk.gd:61-80 - pick() builds only FIRST, GREET_*, GIFT_* and generic <slot> families
- [CAST-03] scripts/social/talk/dialogue_bridge.gd:18,22,27 - the only callers ask for 'FIRST' and 'GREET'
- [CAST-03] rg 'CHAT_H|BARK' over scripts/ finds only colour constants and city_builder bark tiles; no social consumer
- [CAST-03] localization/social_talk.csv:7-11 SOC_MAYOR_LYRA_CHAT_H2_1…CHAT_H10_1 (and the same set for 10 other citizens; CHAT_H4/H8 for 15 more)
- [CAST-03] localization/social_talk.csv:5 'Jeg har gemt en lille historie om de små broer til dig.' (GREET_H2): the story it promises is the unused CHAT line
- [GAP-GHOST-FAMILY-ARC-01] scripts/social/talk/dialogue_bridge.gd:18-27 - the only SocialTalk picks are TALK.pick(npc, "FIRST") and TALK.pick(npc, "GREET")
- [GAP-GHOST-FAMILY-ARC-01] scripts/social/talk/social_talk.gd:61-73 - GREET builds only BDAY/FEST/WX/season/GREET_H<band> families; no CHAT or BARK slot exists; rg for '_CHAT'/'_BARK' in scripts/ and lua/ finds no consumer
- [GAP-GHOST-FAMILY-ARC-01] localization/ghostfamily.csv:40-44 - Dyne's 2/4/6/8/10 ladder, e.g. CHAT_4_1 'Silke er min datter, og Gnist er hendes mand', CHAT_10_1 'Familien Natlys har en plads til dig ...'
- [GAP-GHOST-FAMILY-ARC-01] localization/ghostfamily.csv:63-64, 80-81, 97-98 - the CHAT_4/CHAT_8 beats of Gnist, Silke and Blund (Blund's 'kat, der nyser' setup for the Bu scene)
- [GAP-GHOST-FAMILY-ARC-01] localization/ghostfamily.csv:66 SOC_GHOSTFAM_GNIST_BARK_1 'Olie, lys og mod!' - Gnist's cast-sheet signature line (GHOST_FAMILY_ADDENDUM.md:84) is a bark and never appears
- [GAP-GHOST-FAMILY-ARC-01] lua/dialogue/_voiced_social.lua:92-93 - the voiced rows SOC_GHOSTFAM_DYNE_CHAT_2_1_V and CHAT_8_1_V are indexed but unreachable
- [GAP-GHOST-FAMILY-ARC-01] docs/design/GHOST_FAMILY_ADDENDUM.md:397 - the addendum promises 'chat beats at 2 / 4 / 6 / 8 / 10 hearts (the story of the family ...)' and barks

**What's wrong.** The copy pipeline produces a per-NPC friendship chat line for every heart band (H2-H10, 80 rows) and two barks per NPC. None of these are ever shown. Talking only shows FIRST, GREET (by heart band, falling back to the archetype or 'any' lines), gift reactions, topics, events and quests. The authored heart-band lines are mechanical templates anyway ('By my <thing> I always find a quiet moment'). For NPCs without their own dialogue module, the only thing that changes with friendship is which archetype greeting band they use.

**Merged findings add.** CAST-03 adds that GREET_H2 ('Jeg har gemt en lille historie om … til dig') promises a story the dead CHAT line was meant to deliver. GAP-GHOST-FAMILY-ARC-01 shows what this costs the ghost family: Dyne's tier-A 2/4/6/8/10 ladder (who Silke and Gnist are, why the family left the forest), the setups for Gnist's h4 and Blund's h8 'Bu' scenes, Gnist's signature line 'Olie, lys og mod!' and two recorded voice lines (`_voiced_social.lua:92-93`) all go unused. The family also uses a different key style (`CHAT_<n>` instead of `CHAT_H<n>`).

**Player impact.** Friendship progress has almost no voice. The authored lines that look like they deliver it are dead, and if they were switched on as they are, they would read as obviously machine-filled. This also adds review and translation cost for copy that never ships.

**Recommendation.** Either rewrite the 10 tier-A NPCs' CHAT_H2..H10 lines by hand and show them after the greeting on the weekly chat (e.g. in DialogueBridge.decorate, when on_conversation_finished would give the weekly heart, append TALK.pick(npc, "CHAT_H%d" % band)), or delete the CHAT_H*/BARK rows and their generator template so docs/copy/review_status.json stops counting them. If barks are kept, show them in the npc_2d bubble when the player passes by.

**Verification.** Confirmed. There are more dead barks than stated: 117 BARK rows in total (60 per-NPC, 48 archetype, 9 ghost). CAST-03: Partly; there are about 140 dead lines, not about 200. GAP-GHOST-FAMILY-ARC-01: Confirmed against the cited code and data.

### SOCIAL-05 - 4 of the 11 marriage candidates (Rasmus, Kiki, Bertil, Bodil) have no relationship content; 12 citizens gain nothing from hearts (P2, missing-feature)

*Merged:* CAST-05 (P2, Side quests): Four marriage candidates have no dialogue file and no heart events; several citizens have only 3 lines.

**Evidence**
- lua/social/citizens.lua:36-39 - rasmus, lamplighter_kiki, bertil, bodil: tier B, partner = true
- lua/config/npcs.lua:420,466 (and the rows for kiki/bertil) - dialogue = "rasmus"/"bodil"/..., but lua/dialogue/ has no rasmus, lamplighter_kiki, bertil, bodil, innkeeper_kvak, cub_bamse, clerk_fjerpen or fiddler_strimmel module
- lua/events/hearts/ - heart events exist only for 10 tier-A NPCs (7 of them partners); lua/social/topics.lua - topics only for the 10 tier-A NPCs plus the 4 ghosts
- lua/data/loot_tables.lua:812-819 - friendship gifts for only 5 NPCs (oak, lily x2, pippin, rosa, maja)
- scripts/social/relationships/relationship_flow.gd:53 - custom proposal lines only for hoppe/brumme/maja/birk; everyone else gets PARTNER_ARCH_<archetype>
- localization: SOC_RASMUS_*, SOC_BODIL_* = 8 rows each, all from the same template (FIRST, GREET_H0/H1, two dead CHAT lines, two dead BARK lines, BIO)
- [CAST-05] lua/config/npcs.lua:420,435,450,466 - dialogue = "rasmus" / "lamplighter_kiki" / "bertil" / "bodil", but lua/dialogue/ has no such files (the header says an empty module is passed)
- [CAST-05] lua/social/citizens.lua:36-39 - rasmus, lamplighter_kiki, bertil, bodil all have partner = true
- [CAST-05] lua/events/hearts/ contains only baker_maja, bathkeeper_sofus, beekeeper_birk, carpenter_brumme, farmer_rosa, gardener_hoppe, mayor_lyra, merchant_pip, postman_pip, smith_thorin
- [CAST-05] localization/social_talk.csv:276-307 - Rasmus/Kiki/Bertil/Bodil have 8 template lines each, and only FIRST/GREET_H0/GREET_H1 are ever shown
- [CAST-05] localization/social_talk.csv:308-332 - cat_morfar_mis, penguin_postman, cub_bamse, clerk_fjerpen, fiddler_strimmel have 3 lines each (FIRST, one GREET_H0, BIO); lua/dialogue/fairy_lily.lua and penguin_postman.lua have one line each

**What's wrong.** Rasmus, Kiki, Bertil and Bodil can become heartfriend, fiancé(e) and spouse, but they have no dialogue module, no heart events, no topics, no friendship gifts and only generic archetype proposal lines. They are also the four 'hero-twin' looks, so whichever one the player picks vanishes from the world. More broadly, rasmus, kiki, bertil, bodil, innkeeper_kvak, cub_bamse, clerk_fjerpen, fiddler_strimmel, penguin_postman, mapseller_natteblik, appraiser_fru_ugle and cat_morfar_mis get nothing from hearts 1-10 except stage-name toasts and archetype greetings.

**Merged findings add.** CAST-05 adds that cat_morfar_mis, penguin_postman, cub_bamse, clerk_fjerpen and fiddler_strimmel have only 3 lines each, and that fairy_lily.lua and penguin_postman.lua return a single line.

**Player impact.** Choosing one of these four as a partner leads to a wedding with someone who never says anything personal. A third of the town gives no reason to build friendship, which weakens the 'full social sim' the owner asked for.

**Recommendation.** Either set partner = false for the four hero-twin citizens until they have content, or give each at least a 4/8-heart event (tools/social/content/hearts.json + build_hearts.py), 3 topics in lua/social/topics.lua and PARTNER_<NAME>_1/2 lines (extend the map in relationship_flow.gd:53). For the other tier-B/C citizens, add one friendship gift row each in loot_tables.lua gifts (or a keeper `sample` in citizens.lua) so hearts lead to something.

**Verification.** Partly. The content gap is confirmed. 'Nothing from hearts' is overstated: at 4+ hearts the citizen joins the home-visit pool, and the candidates get the generic proposal, wedding and spouse track. CAST-05: Confirmed. The hjertven/engagement steps also need days, a home tier and a crafted Hjertebuket.

### CORE-01 - The four heroes are unbalanced: the fairy has no perk with any gameplay effect, and the ghost dominates the dungeon (P2, balance)

*Merged:* PRIOR-17 (P3, Status of prior review findings): Race balance notes are still open: the ghost has the oil edge, and chest_sense doesn't stack.

*Prior review:* mechanics-story-deep-dive-2026-10-18 R1 (Ghost is the dungeon's dominant race): still open, re-verified; the fairy half is new. Re-verified against current code: still open.

*Prior review (PRIOR-17):* mechanics-story-deep-dive-2026-10-18 R1 and R2 - still open; no commit has touched race_perks.lua, species_perks.lua, loot_markers.gd or dungeon_run.gd since the deep dive.

**Evidence**
- lua/config/race_perks.lua:52-55 fairy: can_fly, flight_max_seconds 8, flight_energy_per_second 10, talks_to_flowers (flavour); no economic, combat or dungeon value differs from neutral
- scripts/world2d/player_2d.gd:260 `speed = _run * 0.9` (flight 405 px/s is slower than running at 450, game_balance.lua:17)
- scripts/world2d/player_2d.gd:325 and :332 try_interact/use_selected return false while is_flying (no tools, harvest or interaction in the air); :595 needs stamina >= 15; :611-612 drains 10/s and lands after 8 s
- rg can_fly/is_flying: apart from player_2d.gd, only combat/footsteps read is_flying, and nothing requires flight; data/maps: @flight true only on farm, hyggebyen and secret_garden
- lua/config/race_perks.lua:104-106 ghost: run_cost_mult 0.6, oil_use_mult 0.75 (200 s per fill instead of 150), dark_light_mult 1.25
- lua/config/race_perks.lua:26-28 animal (Rasmus): harvest_bonus_chance 0.2 = about +20% crop income; tool_cost_mult 0.75 is close to worthless (see the energy finding)
- scripts/data/perks.gd:95 `1600 gold -> 1360 fox, 1280 hobbit`: hobbit 0.10 shares the 0.20 discount_total cap (perks.gd:69-71), so with gear at its 0.15 cap the hobbit's lead drops to 5 points
- scripts/world2d/player_combat_2d.gd:246-254 fairy_light is available to every race, so the fairy has no dungeon niche
- [PRIOR-17] scripts/loot/loot_markers.gd:80-83 sense_px = minf(maxf(run, species), cap); scripts/dungeon_run/dungeon_run.gd:71-80 chest_sense_cells = maxi(species, gem, weapon), clamped to 12, so nothing stacks
- [PRIOR-17] lua/config/species_perks.lua:30 monkey chest_sense_px = 700, which floors to 7 cells at Iso.ORTHO_W 96, while lua/config/dungeon_loot.lua:105,112 describe the monkey perk as 12 cells

**What's wrong.** The owner wants four heroes that are 'balanced and meaningfully different'. In code, the fox earns about 20% more from every harvest, the hobbit gets 10% off in shops plus a bake bonus, and the ghost gets 25% cheaper lantern oil and 25% more light radius in the dungeon (prior R1). The fairy's perks are flight and talking to flowers. Flight is slower than running, costs energy, lasts at most 8 s, blocks tools, harvest and interaction, works only on 3 maps, and no content uses it. Talking to flowers is a whisper. So the fairy is mechanically the 'no perk' choice. The ghost's run perk is real but small: cycling between running and walking after exhaustion, it travels about 6% faster than other races (360 vs 340 px/s). The ghost's oil and light advantage in the dungeon is unchanged from prior R1. The hobbit's discount shrinks late in the game because it shares the 20% cap with gear discounts.

**Merged findings add.** PRIOR-17 adds the R2 half. The monkey skin (animal race) has the only non-ghost dungeon perk, chest_sense_px 700; its other perks are city-only. It is also weaker than the data comments say: 7 cells, not 12. Because sense values take the maximum instead of adding, a unique emerald (9 cells), a legendary emerald (12) or wpn_spear_root's reveal_chests (12, weapons.lua:355) makes it worthless; only a rare emerald (6) falls below it. Let species chest_sense add to the gem and weapon values under the 12-cell cap, and fix either the 700 px or the comments.

**Player impact.** A child who picks the fairy, likely a popular choice, quietly gets a weaker game: no extra gold, no shop savings, no dungeon help. The flight perk makes them slower than running and cannot be used to work. Ghost players have an easier dungeon.

**Recommendation.** Give the fairy a real mechanical niche in race_perks.lua, for example auto-watering the 8 neighbouring plots while landing, letting flight cross into the secret_garden or onto canopy-only forage spots, or a pollination yield bonus on crops within 2 cells (hook it in farm_grid.gd next to the harvest_bonus_chance roll at :242). Make flight at least as fast as running (player_2d.gd:260: `_run * 1.1`). Trim ghost oil_use_mult to 0.85 as R1 proposed, or give animal and hobbit a forest lever. Consider exempting the race discount from discount_total so the hobbit keeps its edge.

**Verification.** Two skeptics, both partly. Flight does cross water and bog (MASK_FLYING), which is small but real. The weak fairy perk is a documented STUB (PLAN_2D.md:1697). The ghost half is prior R1, still open; GHOST_ADDENDUM.md measures it at ~5 % of a dive, so the fox's harvest bonus is the bigger economic outlier. 'Balanced and different' is not a quote from the owner's brief. Downgraded from P1. PRIOR-17: Confirmed. 'The ghost is the only race with a forest perk' is slightly overstated, because of the monkey's chest sense.

### CORE-02 - Tool 'equipment' is never read: the hotbar slot decides, so upgrades and the Equip button can appear not to work (P2, bug)

**Evidence**
- scripts/autoload/economy_manager.gd:22-24 header: 'the strongest tool of every type ... are equipped automatically ... get_tool_power(type) answers the power of the equipped tool'
- scripts/autoload/economy_manager.gd:575-582 get_tool_power: rg finds no caller outside economy_manager.gd (only get_weapon_damage); rg tool_pickaxe/tool_hoe/best_tool_id: no reader outside economy_manager.gd
- scripts/world2d/player_2d.gd:334 `var item := hotbar.current()`, :344 cost from that def, :377 `tool_hit(str(def.tool_type), int(def.get("power", 1)), self)`
- scripts/world2d/resource_node_2d.gd:94 interact uses `player.hotbar.current()`; :126-127 power too low gives whisper FOREST_TOOL_WEAK 'Redskabet er for svagt. Thorin kan hjælpe.'
- scripts/ui/inventory_ui.gd:181-185 the Equip button ('Udstyr', shop_ui.csv:13) only calls EconomyManager.equip
- scripts/world2d/hotbar.gd:37-48 the hotbar is filled only from the starter kit; a bought tool goes to the backpack; economy_manager.gd:681-682 auto-assigns to the hotbar only for farm placeables
- scripts/world2d/player_2d.gd:435-437 in forest (action) areas the item badge shows the equipped weapon, not the selected hotbar tool
- lua/config/resource_nodes.lua:8,13 gold_ore and moonstone need power 3; :11-12 amethyst and emerald need power 2

**What's wrong.** EconomyManager keeps a tool 'equipment' (strongest tool per type, auto-equipped on purchase, changeable with Udstyr), but no gameplay code reads it. Tool use, the stamina cost and the ore power check all use the item in the selected hotbar slot. The starter hotbar holds pickaxe_wooden (power 1). A player who buys pickaxe_iron (500 g) sees it auto-equipped, or presses Udstyr, then mines gold ore or moonstone with the starter hotbar and is told 'the tool is too weak, Thorin can help'. They have already bought Thorin's upgrade. In Mørkeskoven the HUD shows the weapon, not the selected tool.

**Player impact.** Players can believe a 500 g upgrade is broken, or buy it twice. The ore gate that drives the pickaxe ladder becomes confusing, especially for young players.

**Recommendation.** Make one owner the source of truth. Either use_selected() and resource_node_2d.interact() resolve the tool by type through EconomyManager.equipped_item(TOOL_SLOTS[type]) (so any pickaxe in the hotbar swings the equipped best one), or equip() and _auto_equip() for tools emit hotbar_assign_requested to replace the same-type item in the hotbar. Then remove the dead get_tool_power path or wire it in, and change FOREST_TOOL_WEAK to name the tool that is needed.

**Verification.** Confirmed against the cited code and data.

### CORE-03 - Energy is still decorative, so farm-tool upgrades, energy food and energy perks have no felt value (P2, balance)

*Merged:* PRIOR-21 (P3, Status of prior review findings): Stamina barely matters outside the dungeon.

*Prior review:* game-review-2026-10-18 M4 (Stamina is nearly non-binding): still open; the tool-upgrade and perk consequences are new. Re-verified against current code: still open.

*Prior review (PRIOR-21):* game-review-2026-10-18 M4 - still open as a design choice; no fix in git.

**Evidence**
- lua/config/game_balance.lua:28-30 max_stamina 100, stamina_regen_per_second 12, run_cost_per_second 15
- scripts/world2d/player_2d.gd:256-257 regen whenever not running or flying, after a 1 s delay (:406-408 `_regen_delay = 1.0`), so 0 to 100 takes about 9 s
- lua/items/tools.lua:29-40 hoe_iron 400 g only lowers the cost 3.0 to 2.5; :54-66 watering_can_gold 600 g lowers 1.5 to 1.2, and `capacity` is reserved and not enforced (:11); hoe and watering `power` are read nowhere (rg get_tool_power/power)
- localization/economy.csv:6,10 the iron hoe and gold can are sold only on 'costs less energy'
- lua/items/resources.lua:163 apple stamina 10, consumables.lua:37 cookie 15, magic.lua:43 and crafted.lua:71 40: 1-3 s of standing still
- docs/design/CLOCK_26_ADDENDUM.md:47 the balance assumes 'energy and chores bound the day'
- [PRIOR-21] scripts/world2d/resource_node_2d.gd:126 needs pickaxe power >= node power; amethyst/emerald need 2 and gold_ore/moonstone 3 (lua/config/resource_nodes.lua:8-13)

**What's wrong.** Re-verified that prior M4 is unchanged. Energy refills from empty in about 9 s of not running, so it only slows play while a large field is watered non-stop, by about 1.1 s per plot after roughly 66 plots. As a result, the two farm-tool upgrades (1,000 g together) change only a cost that barely matters, and their descriptions promise only that. Energy food and Perks 'energy' (up to +60) are near-useless, as is the fox's tool_cost_mult 0.75. The CLOCK_26 balance assumption that energy limits daily output is false in code.

**Merged findings add.** PRIOR-21 re-verifies M4 and limits one point: 'tool upgrades mainly lower energy cost' holds for the hoe and the watering can, but pickaxe power gates resource nodes, so pickaxe upgrades unlock content.

**Player impact.** Gold spent on the iron hoe and gold watering can buys no visible improvement. The Energi bar, which the owner wants top-right in the HUD, rarely means anything, so there is no daily planning tension.

**Recommendation.** Either make energy a day budget (Stardew-style): no passive regen while working, only regen by sitting, eating or sleeping, or regen at about 1/s; retune tools.lua costs so a full 110-plot day uses about 70-90%. Or keep regen and give the upgrades visible effects: the gold can waters a 3-cell line or 3x3 area, the iron hoe tills 3 cells (farm_grid.till/water with a power-scaled pattern), and update ITEM_*_DESC. Then update CLOCK_26_ADDENDUM.md:47.

**Verification.** Confirmed against the cited code and data. PRIOR-21: Confirmed, with the pickaxe exception noted.

### CORE-04 - Manual save and load in the dungeon gives back full hearts, lantern oil and energy (P2, bug)

**Evidence**
- scripts/world2d/world_2d.gd:861-877 to_dict saves area, player_pos, placed, area_flags, farm, greenhouse and hotbar, but not half_hearts, oil or stamina
- scripts/world2d/player_2d.gd:69-72 _ready sets `stamina = max_stamina`, `half_hearts = max_half_hearts`, `oil = max_oil`
- scripts/ui/pause_menu.gd:48 the Save and Load rows are always present (also on dungeon floors, where :50-51 adds Leave Dungeon)
- scripts/dungeon/floors/dungeon_floors.gd:283-307 from_dict keeps active and floor and registers floors -1..+1, so the load re-enters the saved floor
- scripts/autoload/save_manager.gd:155-160 the 300 s autosave also runs on floors

**What's wrong.** Player vitals are not part of the save. Loading a save made on a dungeon floor puts the player back on that floor at the saved position, with a freshly made Player2D at full hearts, full oil and full energy. Pause, Save, then Load is therefore a free full heal and lantern refill anywhere in Mørkeskoven. That bypasses the oil economy the prior review called 'the real resource pressure' (C5) and the 10% gold defeat penalty.

**Player impact.** The dungeon's main tension (oil and hearts) can be skipped, and kids will find it. The reverse also happens: a legitimate Continue after a crash restores stats the player did not have.

**Recommendation.** Persist vitals: add `"vitals": {half_hearts, oil, stamina}` to world_2d.gd to_dict and apply it in _apply_saved after the player exists (clamped to the max values). Or disable manual Save while DungeonFloors.current_floor() > 0, leaving runestones as the checkpoints (pause_menu.gd:48, the same check as :50).

**Verification.** Confirmed against the cited code and data.

### CORE-05 - Passing out at 02:00 has no consequence, and the bed gives no benefit (P2, design)

**Evidence**
- scripts/world2d/world_2d.gd:698-727 _sleep_sequence(passed_out): the only difference is _enter(wake area) and the NOTIF_PASSED_OUT toast; _restore_player() refills everything in both cases
- scripts/autoload/game_manager.gd:502-510 sleep_until_morning wakes at day_start_hour (06:00) either way
- scripts/world2d/world_2d.gd:668-671 the bed opens at 18:00; it gives no bonus for sleeping early
- docs/design/towns_farm_social_workpackages.json:1214 decision 'no gold loss, no run end' for the pass-out
- lua/towns.lua:16 the curfew whisper (01:30) exists only in towns; scripts/towns/town_director.gd:44 curfew is off on the farm and in interiors, so on the farm there is no warning before collapsing
- localization/world.csv:5-6 NOTIF_PASSED_OUT 'Du faldt om af træthed...'

**What's wrong.** The task asked about the pass-out at 02:00 and its penalty. There is no penalty: the player wakes at 06:00 at farm:from_home with full energy, hearts and oil, exactly as if they had gone to bed. Going to bed early gains nothing, since sleep_until_morning wakes at 06:00 either way. The best routine is to never use the bed and collapse at 02:00 every night. On the farm, the main place for late watering of moonflowers, there is no warning before the collapse.

**Player impact.** The day/night rhythm has no decision in it: the bed is cosmetic and staying up is free. The 'Udmattet' toast describes exhaustion that has no effect.

**Recommendation.** Keep it gentle but real. Option A: after a pass-out, wake at 08:00 instead of 06:00 (wake_hour + config time.pass_out_wake_delay_hours = 2) and with 50% energy once energy matters. Option B: reward the bed with a 'well rested' buff (for example +20 max energy or +5% walk speed until noon) when sleeping before 24:00. Add a farm whisper at 01:30 (a 'WHISPER_LATE' row) so children are warned outside the towns too.

**Verification.** Confirmed. In towns the curfew night watch walks the player home at 01:45; the farm has no warning.

### CORE-06 - Closing the window quits without saving; the pause menu's Quit autosaves (P2, bug)

**Evidence**
- scripts/autoload/game_manager.gd:88-89 `auto_accept_quit = false`; `close_requested.connect(quit_game)`
- scripts/autoload/game_manager.gd:91-97 quit_game only pauses, shuts down audio and quits; it does not save
- scripts/ui/pause_menu.gd:105-118 _leave(quit_game) calls SaveManager.autosave() first and asks for confirmation if that fails
- scripts/autoload/save_manager.gd:72 AUTOSAVE_INTERVAL_SECONDS 300 (600 game minutes = half a game day)
- lua/config/game_balance.lua:92 `auto_save_minutes = 30` is dead config (rg finds no reader)

**What's wrong.** Closing the window (red close button or Cmd+Q on macOS, the close button or Alt+F4 on Windows) runs GameManager.quit_game, which never saves. Pause, Quit game does autosave. Between autosaves (every 300 real seconds while PLAYING, plus day ends) a player who closes the window loses up to half a game day of work: harvests, purchases and quest steps. Continue then loads the older autosave without saying so. The game_balance key that looks like the autosave interval does nothing.

**Player impact.** Children usually quit by closing the window. Losing a morning of farming, or a just-bought item, with no message feels like a bug, and it is inconsistent with the menu path.

**Recommendation.** In quit_game(), when a run exists (SaveManager._game_running() and not GameManager.is_modal_open(&"event")), call SaveManager.autosave() before get_tree().quit(). Remove time.auto_save_minutes from game_balance.lua, or make SaveManager read it as the interval (minutes to seconds) instead of the const.

**Verification.** Confirmed against the cited code and data.

### HOME-01 - Builder gifts alone meet almost every cosiness gate and the finale's 'treasures' objective, so found furniture is never needed (P2, design)

*Merged:* PRIOR-15 (P3, Status of prior review findings): Hygge decor per gold still drops as rarity rises (furniture capacity limits the cheap spam).

*Prior review:* E5 'Hygge decor is cheapest via spam-furniture' (docs/review/mechanics-story-deep-dive-2026-10-18.md:82) - still open; the stall-risk row 'Hygge 3/4 vs furniture_capacity' in the same doc is not reproduced. Re-verified against current code: still open.

*Prior review (PRIOR-15):* mechanics-story-deep-dive-2026-10-18 E5 - still open as a per-gold note; the numbers are corrected below. rarity.lua and home_tiers.lua have not been touched since the deep dive.

**Evidence**
- lua/data/home_tiers.lua:176,213,254,291,328,368 gift_items: throne_root (t5), clock_moon (t6), piano_star (t7), bookshelf_floating (t8), throne_crystal (t9), bed_moon + chandelier_star (t10)
- lua/items/furniture.lua decor: throne_root 24, clock_moon 42, piano_star 52, bookshelf_floating 52, throne_crystal 42, bed_moon 63, chandelier_star 42
- lua/data/home_tiers.lua:372-378 hygge_levels: index 2 = 45, index 3 = 110, index 4 = 240, index 5 = 420 decor
- lua/data/home_tiers.lua:244 t7 hygge=2; :282 t8 hygge=3; :319 t9 hygge=3; :358 t10 hygge=4
- lua/data/starter_kit.lua:25-26 starter furniture = 7 pieces x 2 decor = 14
- lua/quests/slotsdroemmen.lua:11-17 furnish_treasures target 6, placed_by_rarity 'unique,legendary'
- lua/config/rarity.lua decor vs price: chair_pine 2 decor / 70 g (0.029 per g), chair_honey 5 / 180 (0.028), chair_ebony 11 / 940 (0.012), bed_walnut 16 / 2200 (0.007)
- [PRIOR-15] lua/items/furniture.lua: all 17 unique and all 11 legendary rows have buy_price 0 and sell_ratio 0 (loot only)
- [PRIOR-15] furniture_manager.gd:154-159 sums decor per placed piece; per-row decor by rarity is 2-3, 4-8, 9-16, 19-36 and 34-63

**What's wrong.** Running totals from the gifts the builder hands over: at tier 6 the gifts already give 66 decor, which meets tier 7's hygge 2 (45). At tier 7 they give 118, which meets the hygge 3 (110) required by tiers 8 and 9. At tier 9 the gifts plus the starter kit give 226 of the 240 needed for tier 10, a gap of 7 cheap pieces. The finale quest 'Slotsdrømmen' asks for 6 placed unique or legendary pieces, and tier 10 alone has delivered 7. The tier-10 cosiness requirement (420) is then met with about 45 normal pieces at 2 decor each. So the 'go into Mørkeskoven for rare, unique and legendary furniture' loop has no role in home or story progression. Its only value is small set perks (luck is capped at 0.20 overall) and looks. Prior finding E5 (decor per gold is inverted: normal 0.029 per g vs rare 0.012) is still true. In practice the furniture-capacity limit and the gifts make it mostly irrelevant. The prior stall-risk row 'Hygge 3/4 vs capacity (High)' does not hold up: the gifts alone exceed those thresholds.

**Merged findings add.** PRIOR-15 corrects the per-gold numbers. Among buyable rows the median is about 0.020 decor per gold for normal (bed_birch 2/105), 0.017 for uncommon and 0.0074 for rare; the older 0.013 used the rarity.lua base price. Unique and legendary furniture cannot be bought, so 'less hygge per gold' does not apply to dungeon finds. Because capacity binds, decor per slot is what matters, and it rises steeply with rarity: even 74 normal pieces at tier 10 reach only 222 of the 240 needed. The per-gold inversion among normal, uncommon and rare is a minor note; the real problem is the one above, that the gifts make finds unnecessary.

**Player impact.** Players never need to furnish thoughtfully or hunt keepsakes. Gates labelled 'Hyggeniveau' are met without the player noticing, and the dungeon's furniture rewards feel optional.

**Recommendation.** Either drop the decor of tier gifts to rare level (about 11-16) or leave them out of the cosiness score. Or raise the requirements so placed finds matter: for example t8/t9 hygge 3 → 4 and slotsdroemmen furnish_treasures to 'unique,legendary found in the forest' (exclude tier_gift sources, or raise the target to 10). Make decor grow faster than price with rarity (for example normal 2, uncommon 6, rare 18) so that rare purchases pay off per slot.

**Verification.** Partly. The core claim is confirmed (gifts give 24/66/118/170/212/317 decor). 420 hygge is the Slotsdrømmen objective, not a tier gate. The 7 keepsakes arrive across t5-t10. Decor and price data live in furniture.lua, not rarity.lua. PRIOR-15: Partly. The numbers were corrected, and its impact line ('dungeon furniture gives less hygge per gold') is refuted because those pieces have no price.

### HOME-02 - Item perks, cosiness points and set bonuses are invisible in every shop and in the Garderobe and Indretning screens (P2, ux)

**Evidence**
- scripts/ui/components/equipment_details.gd:3-30 builds stat lines only for weapons (WeaponInfo) and lantern gems; nothing for clothing perks or furniture decor
- scripts/ui/shop_ui.gd:249-275 detail panel = name, description, equipment_details, owned count, sale or surcharge; no perks, decor or set
- scripts/ui/garderobe.gd:398-402 _select shows only name and description_key; :282 shows only aggregate 'Dine bonusser' totals
- scripts/ui/indretning_ui.gd:96-102 shows the total score and 'SetName N' only; no threshold, no bonus, no set description
- lua/data/sets.lua bonuses and capstones; localization/wardrobe.csv:226-237 OUTFIT_* names and descriptions and localization/furniture.csv:304-305 FSET_*_DESC are never read by any script (rg finds no use of OUTFIT_ or set description_key in scripts/)
- localization/wardrobe.csv:169 ITEM_SHOES_BOOTS_WIND_DESC is pure flavour text with no numbers

**What's wrong.** Rarity has real effects on clothing perks (speed, energy, luck, discount), on furniture decor and in 9 furniture plus 7 outfit sets with tiered bonuses and 4 legendary capstones. None of that is shown where the player decides. A 1280 g circlet_tiara_silver (energy +2, luck +0.01, part of the fe_festen set) and a 95 g circlet_daisy (no perk) look the same in the tailor's detail panel apart from price and rarity colour. The Garderobe never says which set a piece belongs to, how many pieces are worn toward the next bonus, or that owning every other member of a set awards a legendary capstone. Indretning shows 'Bondegården 3' with no hint of what that gives or what the next step is.

**Player impact.** The rarity system's mechanics can't be learned in play. Players cannot compare or plan outfits, sets or furniture, and capstone rewards arrive as unexplained surprises.

**Recommendation.** Extend equipment_details.gd (or add clothing_details.gd and furniture_details.gd) to list PERK_* lines from def.perks, 'Hygge +N' from def.decor, and 'Sæt: <OUTFIT_x / FSET_x> (n/m), næste bonus ved k' from sets.lua. Call it from shop_ui._detail, garderobe._select and the Indretning list rows. Add a set card to the Garderobe that uses WardrobeManager.set_bonuses() and shows the capstone goal ('Saml resten for at få …').

**Verification.** Confirmed against the cited code and data.

### HOME-03 - Clothing rarity can't be seen on the character: all unique and legendary pieces are recolours, and the planned rarity aura was never built (P2, missing-feature)

**Evidence**
- assets/wardrobe/manifest.json designs = 30 shared layer families; all 96 garments resolve to one of them (art.layer), and every unique or legendary piece uses a common shell (e.g. shoes_boots_wind -> shoes_boots, dress_gown_aurora -> dress_gown, hat_wizard_night -> hat_wizard, the same shell as the rare hat_wizard_lavender)
- scripts/wardrobe/wardrobe_layers.gd:91-103 only a 3-colour palette swap is applied per item; shaders/wardrobe_layer.gdshader has no rarity, sheen or rim term
- docs/design/PLAN_2D_FEATURES.md:25 RV-A4 marked 'FIXED' via a hero-level RarityAura (unique ffd9e6, legendary ffd86a); rg 'aura' over scripts/, scenes/, shaders/ finds nothing
- localization/wardrobe.csv:169 legendary boots described as having 'små vinger i hælene' - not drawn

**What's wrong.** The plan's own measurement says that at game zoom only an aura makes unique and legendary clothing readable. The aura was prototyped and marked fixed, but no runtime code exists. As shipped, a legendary outfit differs from a normal one only by palette, and several descriptions promise features (wings, drifting stars) that are not drawn.

**Player impact.** The top two rarity tiers, the reward for capstones and bosses, feel no different on the hero. That undermines the owner's 5-tier fantasy for clothing.

**Recommendation.** Implement the specified RarityAura in WardrobeLayers or the player: a soft radial sprite behind the body, chosen by the highest rarity worn (unique ffd9e6 a.70 x1.8, legendary ffd86a a.75 x2.2), plus a small sparkle for legendary. Then do the 'Phase B' unique silhouettes (hat_mushroom, hat_hood, hat_acorn, hat_cat, dress_pinafore, necklace_beads), or reword item descriptions to match the art.

**Verification.** Confirmed against the cited code and data.

### GAP-WORLD-TRAVERSAL-01 - Notice board, fast-travel post and mailbox fake an NPC conversation and complete talk/turn-in objectives remotely (P2, bug)

**Evidence**
- scripts/traetoppen/life/life_flow.gd:13 'EventBus.dialogue_started.emit(StringName(npc), StringName(npc))', sent for every LifeFlow.ask, before any choice is made
- scripts/traetoppen/life/notice_board_2d.gd:24 'LifeFlow.ask(self, "mayor_lyra", ...)', so opening the Rådhus board counts as talking to the mayor
- scripts/traetoppen/life/rejsestolpe_2d.gd:28 'LifeFlow.ask(self, "merchant_pip", ...)'; localization/core.csv:21 NPC_MERCHANT_PIP = 'Butiksfe Kløvermynte' (the Hyggebyen shop fairy voices a Trætoppen signpost)
- scripts/traetoppen/life/life_flow.gd:22 LifeFlow.offer asks with the quest's giver (baker_maja, farmer_rosa ...); it is called from notice_board_2d.gd:28 and post_box_2d.gd:75 (the farm mailbox)
- scripts/autoload/quest_manager.gd:877-885: a dialogue_started objective matches on npc only (an empty 'dialogue' filter matches any id, _csv_contains :1355-1357); quest_manager.gd:928-945: a matching turn-in consumes its 'needs' and progresses
- lua/quests/intro_lottery.lua:24-29 talk_to_mayor (on=dialogue_started, npc=mayor_lyra)
- lua/quests/supply_run.lua:25-33 deliver_to_pip (npc=merchant_pip, needs wood 10 / stone 6, consume)
- lua/quests/cookie_delivery.lua:17-25 deliver_to_baker (npc=baker_maja, needs carrot 12, consume); lost_cat.lua:26-31 ask_neighbours any_of includes merchant_pip and mayor_lyra

**What's wrong.** LifeFlow.ask emits EventBus.dialogue_started with the portrait id it borrows. QuestManager treats that as a real conversation with that NPC. Concrete cases: (a) Opening the notice board completes intro_lottery's 'Tal med borgmester Hyldeblomst' without meeting her. That also unlocks home tier 2 (lua/data/home_tiers.lua:58). (b) With supply_run active and 10 wood + 6 stone carried, pressing E on any fast-travel post in Trætoppen hands the goods to Kløvermynte and completes the quest. (c) With cookie_delivery active and 12 carrots carried, reading a farm-mailbox letter from Maja (birthday_cake / math_bakery_counts), or picking a Maja quest on the board, takes the carrots and pays the reward even if the player answers 'Måske senere'. The same leak gives remote progress to animal_products (Rosa), flower_necklace (Lily), the Thorin turn-ins and lost_cat's 'ask the neighbours'. People-book 'last talked' (scripts/ui/social/people.gd:63-65) is also overwritten.

**Player impact.** Story beats and the help-a-citizen loop can be skipped by accident: the intro meeting with the mayor and in-person deliveries happen invisibly at a signpost or mailbox. Players also see the wrong character's name and portrait on objects. Quest completion feels random.

**Recommendation.** Give LifeFlow.ask a 'speaker' that is only a portrait/name and emit dialogue_started only for real NPC conversations. Split it as LifeFlow.ask(owner, portrait_id, lines, choices, emit_talk := false) and pass false from NoticeBoard2D, Rejsestolpe2D, PostBox2D and LifeFlow.offer. Use a neutral speaker for the board (clerk_fjerpen, who keeps the board in int_raadhuset.json:35) and none for the signpost (a sign card with no portrait). Add a test in tests/sections/city_life.gd: with supply_run active plus its goods, interact with a Rejsestolpe2D and assert the quest is still active and the goods are still in the backpack. Do the same for intro_lottery with the board.

**Verification.** One skeptic confirmed, one partly. The leak through the board, the mailbox and LifeFlow.offer is confirmed, including turn-ins that consume the goods when the player answers 'Måske senere'. Skeptic 2 disputed case (b), the fast-travel post, because no `rejsestolpe` map marker exists. Skeptic 1 and the GAP-WORLD-TRAVERSAL-03/04 verifiers confirm that `city_town.gd:53-56` places four posts in code, so case (b) most likely stands; re-test in play. Downgraded from P1.

### GAP-WORLD-TRAVERSAL-02 - Day-1 intro goal 'say hello to the mayor' sends the player the wrong way, and the locator hides her (P2, ux)

*Merged:* FIRSTHOUR-06 (P2, First-hour / first-week playthrough trace): 'Tal med borgmester Hyldeblomst' has no signposting: she is not in Trætoppen on day 1 and the locator hides her.

**Evidence**
- localization/quests.csv:5 QUEST_INTRO_LOTTERY_DESC '...gå over broen til Trætoppen, og sig goddag til borgmesteren' (gives no place); quests.csv:67 'Tal med borgmester Hyldeblomst'
- lua/quests/intro_lottery.lua:42 meta.location = "ZONE_FARM", shown as 'Fra: … · Min Trækronsgård' by tt_quest_text.gd:154-158
- lua/config/game_balance.lua:89 first_weekday = 0, so day 1 is Monday; lua/routines/core/mayor_lyra.lua:24-27 uses the 'work' plan (Rådhuset desk 09:30-15:00) only on weekday {1,2,3}. On Monday she follows the 'rest' plan in Hyggebyen (lines 16-22): home 08:00-10:30, outdoors 10:30-18:30, home from 18:30
- lua/buildings/traetoppen.lua:58-65 Rådhuset (the Town Hall in Trætoppen, where a player expects the mayor) is kept by clerk_fjerpen
- scripts/ui/towns/post_locations.gd:13 the 'Hvor er …?' list skips anyone who is not a building keeper and has < 1 heart; mayor_lyra keeps no building, so she is not listed on day 1
- scripts/towns/door_2d.gd:116-124 a home opens only to friends with >= 1 heart, so 08:00-10:30 and after 18:30 she is behind a locked door
- localization/farm_tutorial.csv:22 TUT_HINT_BRIDGE names Hasselnød in Hyggebyen, not the mayor; localization/home.csv:6 + lua/data/home_tiers.lua:58 home tier 2 is gated on intro_lottery
- [FIRSTHOUR-06] localization/quests.csv:5 and :66-67: 'gå over broen til Trætoppen, og sig goddag til borgmesteren' / 'Tal med borgmester Hyldeblomst', with no place named (the Lua comment intro_lottery.lua:3 says 'the mayor in Hyggebyen')
- [FIRSTHOUR-06] lua/routines/core/mayor_lyra.lua:29 the work plan (Rådhuset in Trætoppen) runs only on weekday {1,2,3}; game_balance.lua:89 first_weekday=0, so day 1 is a Monday and she spends the whole day in Hyggebyen (rest plan: home, blossom_bench1, torv fountain, well)
- [FIRSTHOUR-06] scripts/ui/towns/post_locations.gd:12 the post-office locator lists only building keepers or citizens with >=1 heart; mayor_lyra keeps no building (rg keeper = "mayor_lyra" finds nothing) and has 0 hearts on day 1
- [FIRSTHOUR-06] lua/quests/intro_lottery.lua:42 meta.location = ZONE_FARM, so the journal from-line (tt_quest_text.gd:152-158) reads 'Fra Borgmester Hyldeblomst · Min Trækronsgård'
- [FIRSTHOUR-06] At HEAD the minimap exists only in the forest HUD (forest_hud.gd:75); the town map screen is uncommitted work in the main checkout

**What's wrong.** The only progression-critical NPC meeting on day 1 has no correct pointer. The quest text leads the player to Trætoppen. Trætoppen has the Town Hall, but she never works there on day 1, and only works there on Tue/Wed/Thu 09:30-15:00. The journal says the quest is on the farm. The locator at Postkontoret omits her until the player already has a heart with her, which they cannot have earned before the first meeting. She is visible only outdoors in Hyggebyen between 10:30 and 18:30; a player who arrives in the evening finds a locked house. This matches the first-hour report that the mayor cannot be found on day 1, and it blocks the first home upgrade.

**Merged findings add.** FIRSTHOUR-06 adds that the town map exists only as uncommitted work and that the same blind spot covers Hoppe and Oak.

**Player impact.** New players wander Trætoppen and the Rådhus looking for the mayor, cannot finish the intro quest on day 1, and cannot start the home-upgrade track. This hurts the first-hour experience the most.

**Recommendation.** (1) Change intro_lottery meta.location to "ZONE_CITY" and make QUEST_INTRO_LOTTERY_DESC / OBJ_INTRO_LOTTERY_TALK_TO_MAYOR say 'i Hyggebyen ved springvandet'. (2) In post_locations.gd:13, also list NPCs who give an ACTIVE quest objective (or every quest giver), not only keepers and friends. (3) Pin her to a public post on day 1: add a select row such as { plan = "intro", when = { day_max = 1 } } that keeps her at hyggebyen.torv_fountain_n from 08:00 to 21:00. Alternatively, have Fjerpen at the Rådhus say where she is today. (4) Optionally extend TUT_HINT_BRIDGE to mention the mayor.

**Verification.** Two skeptics, both partly. The facts are confirmed. The mayor can be found outdoors in Hyggebyen 10:30-18:30 every day and shows a '!' bubble, so this is a delay, not a block. Tier 2 also needs materials. The Rådhus board completes the objective anyway, through the GAP-WORLD-TRAVERSAL-01 leak. Downgraded from P1. FIRSTHOUR-06: Confirmed against the cited code and data.

### GAP-WORLD-TRAVERSAL-03 - Fast travel is invisible, mislabelled, only jumps within Trætoppen, and opens an empty menu on first use (P2, design)

**Evidence**
- scripts/traetoppen/life/rejsestolpe_2d.gd:6-11 the post is a bare Interactable2D with no sprite and no _draw; scripts/towns/city_town.gd:53-56 places it at the arrival spawns
- scripts/traetoppen/life/rejsestolpe_2d.gd:31 'EventBus.area_change_requested.emit(area.map.id, ...)', so every destination is a spawn of the same area; lua/config/traetoppen.lua:54-64 stops are farm/torv/hyggebyen/skovlift spawns of traetoppen
- localization/life.csv: LIFE_STOP_HYGGEBYEN 'Hyggebyen' and LIFE_STOP_SKOVLIFT 'Skovliften' arrive at Trætoppen's bridge head and lift, not in Hyggebyen or the forest
- rejsestolpe_2d.gd:24-27: on the first arrival (only ft_farm unlocked) the 'Rejs' prompt appears where the player stands and opens 'Hvor vil du hen?' with only 'Måske senere'
- Unlock is by proximity < 200 ground px (rejsestolpe_2d.gd:17). The Torvet stop is at default [870,700] by the fire pit, while the b7 bridge from tree G lands at [1052.5,776.8] (about 670 ground px away), and the G→F route goes over b8 without touching Torvet, so 'Torvet' can stay undiscovered
- Route table (data/towns/routes.json, traetoppen): gate_farm→gate_skovlift 5422 px = 38 game-min walking; gate_hyggebyen→gate_skovlift 5365 px = 38 game-min, so the most a jump saves is about 38 game-min (about 19 real s)
- No mention in docs/PLAYING.md or any tutorial key (rg LIFE_TRAVEL only in localization/life.csv)

**What's wrong.** Answer to question 1: a typical walking loop (farm porch → Trætoppen → Hyggebyen shop → Skovlift → forest → farm) costs about 160 game-min of the 20 h day (06:00-02:00), and running cuts that by about a third. The day is not travel-starved. Fast travel unlocks early (ft_farm on the first crossing, day 1) but adds little: it never connects the farm, Hyggebyen or the forest hub, only four points inside one area, and each use triggers a full rebuild of Trætoppen. It is also hard to discover: there is no visible post, no first-use explanation, the menu labels promise areas the player does not reach, and the first interaction is an empty menu.

**Player impact.** Most players will never knowingly use fast travel. Those who do will be confused when 'Hyggebyen' leaves them in Trætoppen, and the feature does not shorten the trips that actually take time (farm ↔ Hyggebyen ↔ Skovlift ends).

**Recommendation.** Give Rejsestolpe2D a visible prop: reuse the 'signpost' art from city_builder.gd:508, or draw a lantern post in _draw. Rename the stop keys to LIFE_STOP_HYGGEBYEN 'Broen til Hyggebyen' and LIFE_STOP_SKOVLIFT 'Ved Skovliften', or let the stops leave the area: add posts in farm.map and hyggebyen.map and make each row carry {area, spawn}, so travel emits area_change_requested(row.area, row.spawn). Hide the prompt while no other stop is unlocked. Unlock 'torv' from the landmark_entered 'torvet' event (data landmark circle 230 sketch px) instead of a 200 px radius around the fire pit. Add one line to docs/PLAYING.md.

**Verification.** Confirmed against the cited code and data.

### GAP-WORLD-TRAVERSAL-04 - Skovlift arrival point and the lift's E target overlap; the invisible travel post wins the E press (P2, bug)

**Evidence**
- data/traetoppen/traetoppen.json spawns.from_skovlift = [1380,305]; lifts[0].stand = [1388,310] (about 35 ground px apart after the x3 scale and the 0.59 squash)
- scripts/towns/city_town.gd:53-56 a Rejsestolpe2D is placed exactly on the from_skovlift spawn
- scripts/traetoppen/city_builder.gd:664-669 LiftGate, radius STAND_RADIUS (130,80), sits at lift.position = stand
- scripts/world2d/player_body_2d.gd:253-260 nearest_interactable picks the host with the smallest ground distance to the player
- tests/sections/city_map.gd:2110-2130 test the lift by calling gate.interact(p) directly, not through the E query with CityTown's posts present

**What's wrong.** From level B the lift stand lies just past the travel post, on the rim. Approaching from the platform interior (bridges b1/b3), the player is nearer the post's centre, so E opens the 'Hvor vil du hen?' travel menu instead of riding the lift. The same happens for a player who just came back from the forest and stands on the arrival spawn. The lift only answers when the player stands on the far side of the bisector between two points about 35 px apart, right at the rim. Not reproduced in Godot, but the coordinates and selection rule make it near-certain.

**Player impact.** The only entrance to Mørkeskoven, the main adventure loop, intermittently opens the wrong menu, and the player has no visible cue why, because the post has no art.

**Recommendation.** Move the skovlift fast-travel post off the lift stand: give Rejsestolpe2D a position offset per row in lua/config/traetoppen.lua (e.g. at = [1330,300]) instead of reusing the spawn. Or make LiftGate win ties within its stand radius. Add a towns_city.gd check: place the player at spawn from_skovlift + 20 px toward the stand and assert nearest_interactable() is the LiftGate.

**Verification.** Confirmed against the cited code and data.

### GAP-WORLD-TRAVERSAL-06 - No town-scale wayfinding: no map, a map seller with no town map, signs that only give flavour, and a locator limited by hours (P2, missing-feature)

**Evidence**
- lua/dungeon_run/shops.lua:3-16 natteblik_maps stocks only 'etagekort' (a dungeon floor reveal, scripts/dungeon_run/run_watch.gd:47); lua/buildings/traetoppen.lua:76-81 the window is open 20:00-23:30, and lua/routines/core/mapseller_natteblik.lua:9-13 is away before 19:30
- lua/dialogue/mapseller_natteblik.lua:47-86 'Et kort? Jeg kender de mørke stier.' He is the only 'map' NPC, and he sells forest maps only
- localization/areas.csv:6-17 the Hyggebyen signs are flavour ('Dammen. Sæt dig ned...'), not directions; Trætoppen has only 3 read-signs (city_builder.gd:50-54) at the bridge and lift ends
- scripts/ui/towns/post_ui.gd:43-44 the 'Hvor er …?' locator opens only from the int_postkontoret post_counter (data/interiors/core/int_postkontoret.json:34); Postkontoret is open 09:00-17:00 and closed Sunday (lua/buildings/traetoppen.lua:20-27), about 39 game-min walk from the farm gate
- Door signs (door_2d.gd:166-181) appear only within 3 cells of a door

**What's wrong.** Answer to question 3: wayfinding consists of zone/landmark banners, door signs that appear when the player is already at the door, three bridge/lift signs, quest location at zone granularity, and the Postkontoret locator, which is limited by hours and hearts. Nothing lets the player plan a route to a shop or citizen from a distance: there is no area map, no directional signage at the Hyggebyen gate or Trætoppen junctions, and no quest-target marker. The obvious fit, Natteblik the 'kortsælger', only sells dungeon floor maps after dark. (The uncommitted map UI in the main checkout was not reviewed as instructed; this finding describes the committed game.)

**Player impact.** Players must memorise 14 Hyggebyen doors and 14 Trætoppen huts spread over 8 platforms by trial and error. That works against a cozy social sim in which NPCs move on schedules.

**Recommendation.** When the map UI lands, let Natteblik sell a 'Bykort' unlock (a new item in shops.lua) or give it free from Fjerpen. Until then, add directional sign markers at hyggebyen.map's bridgehead (W spawn) listing Bageriet / Smedjen / Frøbutikken / Torvet, and a junction sign on Torvet (traetoppen.json SIGNS) pointing to Rådhuset (stigen), Postkontoret & Skovliften (bro til E/B), Hyggebyen and the farm. Consider a second 'Hvor er …?' board outdoors next to the Torvet fire pit that is always open.

**Verification.** Confirmed against the cited code and data.

### FARM-04 - Kitten and puppy produce an item with no use, and their copy promises behaviour that does not exist (P3, design)

**Evidence**
- lua/config/husbandry.lua:65-94 cat/dog product = friendship_token, product_interval = on_bond, building = house
- lua/items/resources.lua:170-178 friendship_token category = special, sell_price = 0
- scripts/social/gifts/gift_rules.gd:13,78 NEVER_GIVEN_CATEGORIES includes 'special', so giftable() refuses it
- scripts/autoload/economy_manager.gd:49 UNSELLABLE_CATEGORIES ['quest','special']; no recipe or quest consumes friendship_token (rg over lua/recipes, lua/quests: rewards only)
- scripts/farm/animal_husbandry.gd:705-713 bond level only grants products for ON_BOND species; nothing else reads bond_level
- localization/da.csv:68 kitten 'følger dig rundt'; :70 puppy 'vogter din gård'; scripts/farm/animal_yard.gd:17-34 every animal only wanders the yard
- lua/items/animals.lua kitten/puppy buy_price 350 and they share the 3-slot house with owl/fox (husbandry.lua:151,166)

**What's wrong.** The two pet species cost 350 g each and take house slots that could hold an owl (about 133 g/day) or a fox (about 80 g/day). Their only output is friendship_token, which cannot be sold, gifted, crafted or turned in. Bond level, the animal 'hearts', has no other effect for any species, so caring for a pet changes nothing in the game. The item copy promises a kitten that follows you around and a puppy that guards the farm. Neither exists: all animals only wander the shared yard.

**Player impact.** Players who adopt a kitten or puppy get a care chore with no reward and a growing stack of dead tokens, and can feel misled by the descriptions.

**Recommendation.** Give friendship_token a sink: make it giftable (giftable = true on the def, or remove 'special' from it) as a neutral-plus gift worth friendship, or let Pip and the furniture fairies trade it for something cosmetic. Or have pets give an actual perk at bond levels 2/4/6 (e.g. dog: +1 forage find on the farm per day; cat: small happiness aura for coop animals). Rewrite da.csv:68/70 to match what is implemented.

**Verification.** Partly. The misleading copy and the weak 350 g purchase are confirmed. The token is not useless: fairy_friendship counts 5 of them (have-only, not consumed). Downgraded from P2.

### FARM-05 - Catnip is still a dominated crop with no use, and its description says cats love it but cats cannot eat it (P3, consistency)

*Merged:* PRIOR-13 (P3, Status of prior review findings): Crop table only partly rebalanced: turnip is still strictly beaten by carrot, and catnip has no niche.

*Prior review:* mechanics-story-deep-dive-2026-10-18 E3 'Catnip is a pure trap crop' (still open, re-verified). Re-verified against current code: still open.

*Prior review (PRIOR-13):* game-review-2026-10-18 M5 and mechanics-story-deep-dive-2026-10-18 E3 - the catnip half is still open; the turnip half is refuted (see 'Refuted / dropped claims').

**Evidence**
- localization/economy.csv:53 ITEM_CATNIP_SEEDS_DESC 'Elskes af katte'; :55 ITEM_CATNIP_DESC 'Duften får hver kat til at spinde'
- lua/config/husbandry.lua:73 cat feed_types = { animal_treats, milk }
- scripts/farm/animal_husbandry.gd:398 food not in feed_types -> NOTIF_WRONG_FOOD; animal_care_ui.gd lists only feed_types
- lua/config/game_balance.lua:56 catnip 5 nights, sell 55; lua/items/crops.lua:144 seed 35 -> 4.0 g/day vs carrot 11.25 in the same seasons
- lua/social/gift_tastes.lua: no NPC lists catnip; only use is the lost_cat reward of seeds (lua/quests/lost_cat.lua:58)
- [PRIOR-13] lua/items/farm_equipment.lua:2 applies one processing formula to every crop: preserve_catnip 160 / juice 165 vs preserve_carrot 180 / juice 195
- [PRIOR-13] lua/social/gift_tastes.lua:99 cat_morfar_mis dislikes category:crop, so the one cat NPC dislikes catnip

**What's wrong.** Re-verified: catnip still has no gift taste, feed use or recipe. The only change since E3 is a preserve/juice row. Its seed is the only one whose description gives no growing information. Instead it promises cats love it, but the cat's feed list excludes catnip, so the care screen never offers it.

**Merged findings add.** PRIOR-13 adds that processing gives catnip no niche either, because the preserve/juice formula is generic and carrot still wins, and that the cat NPC cat_morfar_mis dislikes it as a crop. Catnip is strictly dominated by carrot and has no use beyond gold.

**Player impact.** Players buy catnip expecting to treat their kitten, find it cannot be fed, and earn about a third of what carrots pay.

**Recommendation.** Add catnip to the cat (and fox) feed_types in husbandry.lua and to the fallback in animal_husbandry.gd. Make it the cat's favorite_feed (bonus 25) and add it as a love for one or two NPCs in gift_tastes.lua. Change the seed description to growth info, e.g. 'Kattens livret. Høst efter 5 dage'.

**Verification.** Confirmed against the cited code and data. PRIOR-13: Partly. The catnip half is confirmed. The turnip half is refuted: turnip is the sheep's favorite_feed, a cow feed, the birthday_cake crop and a liked gift.

### FARM-06 - Fertilizer is still a no-decision purchase, and its description hides what it does (P3, balance)

*Merged:* PRIOR-14 (P3, Status of prior review findings): Economy design notes untouched: fertilizer is a free win, shop prices are flat, wool has an orphan price.

*Prior review:* mechanics-story-deep-dive-2026-10-18 E2 'Fertilizer is a dominant, decision-free purchase' (still open, re-verified). Re-verified against current code: still open.

*Prior review (PRIOR-14):* mechanics-story-deep-dive-2026-10-18 E2, E4 and E6 - still open, except the lantern-house forage bonus, which already exists.

**Evidence**
- lua/items/crops.lua:176-186 fertilizer buy_price 15
- lua/config/game_balance.lua:36-37 harvest_yield = 1, fertilizer_bonus_yield = 1
- scripts/world2d/farm_grid.gd:239-240 +1 crop on the next harvest; :222-223 can be reapplied after every regrow harvest
- localization/economy.csv:61 ITEM_FERTILIZER_DESC 'Bedre høst'
- [PRIOR-14] lua/items/products.lua:35 wool buy_price 30, but no lua/shops file stocks wool
- [PRIOR-14] lua/shops/lantern_house.lua:16-17 sell_multiplier 1.25 with buys = {"forage"}; every other shop multiplier is 1.0 apart from magic_store buy 1.1, so no shop pays a crop bonus
- [PRIOR-14] lua/items/tools.lua:17,29 hoe wooden → iron with no copper step (see ECON-11)

**What's wrong.** Unchanged: 15 g doubles the next harvest, worth +45 to +180 g. With regrowing crops it can be reapplied after every harvest (glow berry: +150 g per 15 g every 4 days). The only limit is the 30-per-day seed-shop stock. The description 'Bedre høst' does not say it doubles one harvest.

**Merged findings add.** PRIOR-14 bundles the other untouched pass-2 economy notes. Shop prices are flat apart from the magic store and the lantern house's +25 % on forage, so there is no choice of where to sell crops; a bakery crop bonus is still missing. Wool has a buy_price (30) but no shop stocks it: remove the price, or stock wool at Rosa's. The hoe ladder is covered by ECON-11.

**Player impact.** There is no decision to make: always fertilize. It also doubles the glow-berry imbalance (59 g/day per plot).

**Recommendation.** Either make it a percentage, e.g. a 50% chance of +1 with price 25, or scale the price to crop tier. At minimum, change the copy to 'Giver én ekstra afgrøde ved næste høst'.

**Verification.** Confirmed against the cited code and data. PRIOR-14: Partly. Fertilizer, the flat crop prices and the wool orphan price are confirmed. The 'every multiplier is 1.0' evidence missed the lantern house, which already has the forage bonus the recommendation asked for.

### FARM-07 - Keg is a worse preserves jar for 9 of 11 crops; recipe home-tier gates are bypassed by the seed shop (P3, balance)

**Evidence**
- lua/config/farm_equipment.lua:6-7 preserves_jar days = 2, keg days = 3
- lua/items/farm_equipment.lua:2 'Preserves sell for 2x crop value + 50; juice for 3x crop value'; :9-10 preserve_turnip 140 vs juice_turnip 135
- lua/items/farm_equipment.lua:7-8 jar buy 350, keg buy 500
- lua/recipes/farm_equipment.lua:4,6 quality_sprinkler and keg min_home_tier = 3; :5 jar min_home_tier = 2
- lua/shops/seed_shop.lua:44-46 quality_sprinkler, preserves_jar, keg stocked from day 1 with no tier gate

**What's wrong.** Value added per machine-day is (c+50)/2 for a jar and 2c/3 for a keg. The keg only wins when the crop is worth more than 150 g: pumpkin (106.7 vs 105) and moonflower (120 vs 115). It ties glow berry (100 vs 100) and loses clearly for the other 8 crops. For turnip the juice even sells for less than the jam (135 vs 140). Yet the keg costs more (500 vs 350), takes a day longer and its recipe needs home tier 3. Those recipe gates (keg and quality sprinkler at tier 3) also mean nothing, because Kløvermynte sells all of them from day 1.

**Player impact.** Players who invest in kegs earn less, and the 'craft at tier 3' progression step is invisible because the shop skips it.

**Recommendation.** Make juice 2.5c + 60 or shorten the keg to 2 days, so it is the better choice for mid-value crops and the jar for cheap ones. Either gate quality_sprinkler and keg in seed_shop.lua behind the same home tier (if ShopSystem supports a tier field), or drop the min_home_tier from the recipes so the two sources agree.

**Verification.** Partly. The keg loses for 8 crops, ties 1 and wins 2. Per crop input, the keg returns more for any crop worth more than 50 g, so this is a throughput-versus-yield trade-off. The recipe gates gate the cheap crafting route only.

### FARM-08 - 'Fe-støv til marken' costs 900 g for 3 days on one plot, sold beside a 300 g permanent sprinkler (P3, balance)

*Prior review:* mechanics-story-deep-dive-2026-10-18 F3 'fairy_dust_water is a luxury sink' (still open, re-verified). Re-verified against current code: still open.

**Evidence**
- lua/items/crops.lua:187-197 fairy_dust_water buy_price 900, sell_price 200
- lua/config/game_balance.lua:38 auto_water_days = 3
- lua/items/farm_equipment.lua:5 sprinkler buy_price 300, waters 4 plots every morning forever
- lua/shops/seed_shop.lua:34,43 both on the same shelf

**What's wrong.** Re-verified: one use auto-waters one plot for 3 days, which is 3 waterings worth about 4.5 energy. The same shop sells a sprinkler at a third of the price that waters 4 plots every day indefinitely. Its only real niche is that the hourly auto-water does satisfy a moonflower's night window, but that is not explained anywhere.

**Player impact.** It is a trap purchase. Buying 3 on day 1 costs more than the 500 g starting money, and new players may buy it because it is the guide's line item.

**Recommendation.** Reprice to 40-60 g, or make it a 7-day effect on a 3x3 area at about 250 g. If its intended niche is moon crops, say so in ITEM_FAIRY_DUST_WATER_DESC ('Vander ét felt i 3 dage – også om natten').

**Verification.** Confirmed against the cited code and data.

### FARM-09 - Shipping bin always ships the whole selected stack, with no amount choice and no take-back (P3, ux)

**Evidence**
- scripts/farm/steading/objects/shipping_bin_2d.gd:17-18 amount = EconomyManager.count_item(id)
- scripts/farm/steading/objects/shipping_bin_2d.gd:27-28 consume_backpack_items({id: amount}) then the stack is only a flag (bin_<id>) until the morning payout (farm_stage.gd:50-74)
- lua/quests/birthday_cake.lua turn-in needs 3 turnips + 1 moonflower; NPC loves include carrot, strawberry, moonflower, sunflower (lua/social/gift_tastes.lua:76-97)

**What's wrong.** Pressing E at the bin with a crop selected ships every unit in the backpack. There is no confirmation, no partial amount, and no way to take items back before the morning roll.

**Player impact.** Players lose quest or gift crops (e.g. the moonflower for the birthday cake, a loved strawberry) with one key press.

**Recommendation.** Ship one unit per tap, with hold or a modifier to ship the stack. Or show a quantity confirm like the shop's sell dialog. Let the last shipped stack be taken back until 02:00 (the bin_<id> flag makes this easy).

**Verification.** Confirmed against the cited code and data.

### FARM-10 - Every farm animal from all three buildings wanders the same 3-cell yard (P3, ux)

**Evidence**
- data/maps/farm.map:30 '@marker c animal_yard r=3' (one yard)
- scripts/farm/animal_yard.gd:17-34 spawns an Animal2D for every animal in AnimalHusbandry.animals and picks targets within radius 3
- scripts/farm/animal_2d.gd:23-24 collision_mask = LAYER_WORLD only (animals pass through each other)
- lua/config/husbandry.lua:178-199 max capacities coop 12 + barn 18 + house 9 = 39 animals

**What's wrong.** Chickens, cows, owls and pets all share one yard about 28 cells across, regardless of which building houses them. At full upgrades that is up to 39 overlapping sprites, each with an '!' product bubble, in a small circle next to the coop, barn and house slots.

**Player impact.** A fully upgraded farm becomes a stacked pile of animals where it is hard to target the right one, and buildings don't visibly hold their own animals. Not runtime-verified (Godot not launched).

**Recommendation.** Give each building slot its own animal_yard marker, or have AnimalYard filter by building_type, and spread the radius by capacity. Alternatively cap the number of visible actors and offer the care screen's animal list for the rest.

**Verification.** Partly. Confirmed. A radius-3 yard is about 6 cells across, not 28.

### ECON-06 - STILL OPEN: the tier-6 gate (crystal_cave, floors 10-12) is deeper than the tier-8/9 gates (P3, design)

*Merged:* PRIOR-01 (P3, Status of prior review findings): Tier-6 house gate still needs dungeon floors 10-12, deeper than the tier 8/9 gates.

*Prior review (PRIOR-01):* game-review-2026-10-18 M1; mechanics-story-deep-dive-2026-10-18 top fix 1 / t6 stall risk; game-mechanics-2026-10-17 tier-6 note. Re-verified against current code: still open, and unchanged on origin/main fc901cf0.

**Evidence**
- lua/data/home_tiers.lua:204 tier 6 `requires = { quests = { "crystal_cave" } }`
- lua/quests/crystal_cave.lua: explore_cave = zone_entered crystal_cave; lua/config/dungeon.lua:87 zone crystal_cave = floors 10-12 (past the floor-4 and floor-8 bosses)
- lua/data/home_tiers.lua:282 tier 8 = snurresvampen (floor-4 boss); :319 tier 9 = moonstone_crown (moonstone, buyable)
- [PRIOR-01] dungeon_export.gd:106-111 seals the stairs of each boss floor (`sealed_by`, `when=flag:dg_boss_clear`); bosses sit on floors 4/8/12 (lua/config/dungeon.lua:179,286,384), so floor 10 needs both earlier victories (Glødesvampen 176 hp, lua/config/bosses.lua:5)
- [PRIOR-01] docs/qa/game-mechanics/fixes/README.md:26 'the authored tier-6 home gate remains as reviewed'; the only later commit touching these files (02f29ec0) only bumped the dungeon gen_version

**What's wrong.** Re-checked against current code: unchanged since game-review M1 and the deep-dive stall table. A player who cannot beat the floor-8 boss is capped at tier 5 however rich they are, while the tier 8 and 9 gates are easier. Combined with the material wall above, the mid-ladder is lumpy: hard at tier 6, easy at 8-9, then a material trickle at 8-10.

**Merged findings add.** PRIOR-01 confirms that the boss floors seal their stairs, so tier 6 really does need the floor-4 and floor-8 victories. It is a known, deliberate pacing choice that is still waiting on the farming-first playtest pass 1 asked for. If the gate stays as authored, run that playtest and record the result.

**Player impact.** Farming-focused or younger players stall at the Gården (tier 5) for an indeterminate time.

**Recommendation.** As proposed before: swap the tier-6 and tier-8 quest gates in lua/data/home_tiers.lua:204/282, or move crystal_cave's explore_cave to a shallower band, or let tier 6 accept dark_forest_mining.

**Verification.** Partly. The ordering is authored and pinned by validator S13, and game-review M1 already downgraded it to a design note. Downgraded from P2. PRIOR-01: Confirmed; lowered from P2 to P3 for the same reason (authored intent, pinned by S13).

### ECON-07 - Tier 5 needs 4 copper plates, but the copper-plate forge only unlocks at tier 5 (P3, design)

**Evidence**
- lua/data/home_tiers.lua:165 tier 5 materials include `copper_plate = 4`
- lua/recipes/materials.lua:71-76 forge_copper_plate: station smedje, min_home_tier 5 (the forge_bench unlock of tier 5, home_tiers.lua:178)
- lua/shops/home_shops.lua:221 copper_plate only in the weekly fine-goods slot (4 of 8 ≈ 50%/week); lua/data/loot_tables.lua:414 dybe_bregner uncommon pool (floors 4-6)

**What's wrong.** The plate needed to build the forge tier can only be crafted after that tier is built. Before it, the player must wait for a week in which the yard happens to roll copper plates (median 1 week, 90th percentile about 4 weeks) or find them on floors 4-6. Brass bar and gold leaf have the same tier-5 lock but are not needed until tiers 7-9.

**Player impact.** A confusing 'come back next week' wait right after the first-animal gate, with nothing explaining where plates come from.

**Recommendation.** Lower forge_copper_plate's min_home_tier to 4 (or give it the snedkerbord station), or pin copper_plate as a fixed builder_yard row (stock 12, restock 4).

**Verification.** Confirmed against the cited code and data.

### ECON-08 - Refining recipes are worth less than their raw ore, and iron_sword is a sell-price outlier (P3, consistency)

*Merged:* COMBAT-13 (P3, Mørkeskoven dungeon): iron_sword sells for 300, more than any rare weapon.

**Evidence**
- lua/recipes/materials.lua:71-77 forge_copper_plate: 3 copper_ore (sell 14 each = 42) → 1 copper_plate (buy 36, sell 14); tier 8 needs 30 plates (home_tiers.lua:280)
- lua/recipes/materials.lua forge_brass_bar: 2 copper + 1 iron (43 sell) → brass_bar sell 19; twist_rope: 3 moss → rope (sell 2)
- lua/recipes/guide_recipes.lua lantern_post / scarecrow: inputs sell 46/18 → outputs 30/12
- lua/items/tools.lua:151-161 iron_sword uncommon buy 750 / sell 300 (ratio 0.40) vs lua/config/rarity.lua uncommon weapon_sell_ratio 0.12 (wpn_dagger_flint 70, wpn_club_oak 105); every rare weapon sells for 205 or less
- lua/quests/dark_forest_mining.lua:44 iron_sword in every weekly repeat reward
- [COMBAT-13] lua/items/tools.lua:151-161: iron_sword uncommon, buy 750, sell 300 (40 %)
- [COMBAT-13] lua/config/rarity.lua:34,49: weapon_sell_ratio uncommon 0.12 / rare 0.10
- [COMBAT-13] lua/items/weapons.lua: uncommon peers sell 70-105; rare weapons sell 145-205
- [COMBAT-13] lua/data/loot_tables.lua:12: duplicate weapon finds are auto-sold at sell value

**What's wrong.** Smelting or weaving destroys value compared with selling the raw ore and buying the product, which teaches 'never refine'. Wool to fabric was already reported as prior E1. The legacy iron_sword keeps an old 0.4 sell ratio, so a loot or quest iron sword outsells every rare weapon. The weekly mining quest hands one out every time.

**Merged findings add.** COMBAT-13 adds that iron_sword sits in every band's uncommon weapon pool, so every duplicate auto-sells for 300.

**Player impact.** Crafting the home's copper plates feels like a loss. Selling price does not follow rarity.

**Recommendation.** Set copper_plate sell to at least 45 (or the recipe to 2 ore). Set brass_bar sell to at least 45, rope sell to at least 4 or twist_rope to 2 moss, and iron_sword sell_price to 90 (rarity rule). Add a validator check that a processing recipe's output sell value is at least its input sell value for building materials.

**Verification.** Partly. Copper plate, rope and iron_sword are confirmed. Brass bar is refuted (2x14+15 = 43 g of inputs against a 48 g buy price). The guide-recipe numbers are slightly off and weak as an argument. COMBAT-13: Confirmed against the cited code and data.

### ECON-09 - STILL OPEN: the tier-9 gate moonstone_crown can be bought outright (P3, design)

*Merged:* PRIOR-07 (P3, Status of prior review findings): Moonstone for the tier-9 gate can still be bought, for a profit.

*Prior review (PRIOR-07):* game-review-2026-10-18 M8 - still open; no commit has touched these files since.

**Evidence**
- lua/quests/moonstone_crown.lua: collect moonstone x1 `have = true` (no consume)
- lua/shops/magic_store.lua: moonstone stock 1/1 at 440 ×1.1 = 484 g; quest reward 800 g + circlet (home_tiers.lua:319 tier 9 gate)
- [PRIOR-07] quest_manager.gd:28 `have = true` counts what the player owns and does not consume it
- [PRIOR-07] lua/items/resources.lua:93 moonstone buy_price 440 (sell 220); lua/quests/moonstone_crown.lua:26-30 rewards 800 g + circlet_moon_crown + 2 fairy_king hearts; the magic store opens from fairy_wizard dialogue with no gate

**What's wrong.** Re-checked against current code: unchanged since game-review M8. The 'adventure' gate of tier 9 is a 484 g shop purchase that the quest itself pays back.

**Merged findings add.** PRIOR-07 adds that the player also keeps the moonstone (sell it for 220 g, or use it as tier-9 material), so the profit is larger than 800 - 484 g. The reward also includes a legendary crown and 2 fairy_king hearts. One nuance: tiers are sequential, and tier 8 already needs the floor-4 boss, so by tier 9 the player has fought anyway. The issue is that the 'adventure' reward and the legendary crown cost one shop trip. Pass 1 asked for an explicit decision: keep it buyable and say so in the quest copy, or remove it from stock.

**Player impact.** The tier-9 story beat ('find the moonstone for his crown') can be skipped by shopping.

**Recommendation.** Remove moonstone from magic_store stock until moonstone_crown is completed, or make the objective a dungeon pickup (resource_node_depleted moonstone / game_event).

**Verification.** Confirmed against the cited code and data. PRIOR-07: Confirmed.

### ECON-10 - No batch crafting: the home ladder implies about 140+ single craft presses, each with a toast (P3, ux)

**Evidence**
- scripts/ui/components/workshop_panel.gd:124-135 _craft() crafts exactly one unit, posts a notification and refreshes the list
- lua/data/home_tiers.lua:202,317 stone_block 60 + 120 (shelf 40, lua/shops/home_shops.lua:198) → about 140 cut_stone_block crafts (lua/recipes/materials.lua cut_stone_block 3 stone → 1)

**What's wrong.** Tiers 6 and 9 need 180 stone blocks. With the yard at 1/day, most must be cut at the workbench one press at a time, with 140 'Lavet!' toasts and a list rebuild each time. Planks, beams and nails have the same issue.

**Player impact.** Tedious and noisy right where the ladder is already slow, and especially awkward on keyboard-only controls.

**Recommendation.** Add a quantity selector (×1/×5/×max) to workshop_panel and loop CraftingSystem.craft inside one defer_notifications with a single summary toast.

**Verification.** Confirmed against the cited code and data.

### ECON-11 - STILL OPEN (extended): tool upgrade ladders are uneven – no axe or scythe upgrade, and the hoe skips copper (P3, design)

**Evidence**
- lua/items/tools.lua axe_wooden power 1 and scythe power 1 are the only axe and scythe; hoe_wooden 1 → hoe_iron 2 (smithy 400); pickaxe wooden → copper (recipe) → iron
- lua/shops/smithy.lua:21-26 sells hoe_iron, pickaxe_iron, watering_can_gold only
- lua/config/resource_nodes.lua tree_chop power 1 – nothing ever needs a better axe

**What's wrong.** Prior deep-dive E6 (hoe skips copper) is still true. In addition, two of the six farm tools have no upgrade path at all, so the tool-upgrade part of the Stardew-style loop is thin: three purchases at Thorin and one recipe.

**Player impact.** There are few mid-game tool goals, and the smithy feels finished early.

**Recommendation.** Add axe_iron and scythe_iron to smithy.lua (and hoe_copper to the guide recipes). Give them energy savings or an area swing like the hoe and can, or a large-stump node that needs axe power 2.

**Verification.** Confirmed against the cited code and data.

### PRIOR-19 - sword_upgrade is still offered after buying the iron sword, and pays out a second one (P3, bug)

*Prior review:* game-review-2026-10-18 M9 (minor quest-logic items). Re-verified against current code: still open, with no fix in git history. The enchanted_garden half of M9 is reported under SPINE-13.

**Evidence**
- lua/quests/sword_upgrade.lua:68-76 has_iron_sword is set only in handle_event on quest_completed, and is_available checks only that flag
- lua/quests/sword_upgrade.lua:38-43 rewards 400 g plus iron_sword x1
- lua/shops/smithy.lua:25 iron_sword stock 1; lua/items/tools.lua:151-160 buy_price 750
- quest_manager.gd:34,373 and lua_runtime.gd:147-159 honour is_available; nothing checks whether the player already owns the reward item

**What's wrong.** A player who buys the iron sword at the smithy for 750 g is still offered 'Et bedre sværd', and completing it hands over a second iron sword plus 400 g. The only guard is a flag that this quest sets when it completes.

**Player impact.** A duplicate weapon reward is confusing, and the quest's premise (get a better sword) is stale for a player who already has one. The spare sword ends up as sell fodder (see ECON-08 on iron_sword's sell price).

**Recommendation.** Make is_available also check `not api.has_item("iron_sword")`, or set has_iron_sword when the sword is bought. Alternatively, swap the reward for gold or an upgrade material when the sword is already owned.

**Verification.** Confirmed. Matches pass-1 M9 (game-review-2026-10-18.md:143-146), which listed it as an open minor item.

### PRIOR-20 - The fishing rod is sold for 120 g although fishing is closed (P3, ux)

*Prior review:* game-review-2026-10-18 fishing-rod note. Pass 1 accepted the rod as a deliberate teaser (game-review-2026-10-18.md:34, :70-73, :231), so this is a new low-priority UX suggestion, not a still-open defect.

**Evidence**
- lua/shops/seed_shop.lua:42 fishing_rod stock 2
- lua/items/tools.lua fishing_rod buy 120 / sell 40 (80 g lost on a buy and sell)
- scripts/world2d/player_2d.gd:341-343 using the rod whispers WHISPER_FISHING_CLOSED
- localization/economy.csv:22 'Fiskevandet er ikke åbnet endnu, men stangen er klar.'

**What's wrong.** The seed shop sells a tool that has no action yet. The item copy says so honestly, but a child who does not read the description still pays 120 g and can get only 40 g back. GM-03 is not a precedent for removing it: GM-03 (game-mechanics-2026-10-17.md:35-41) explicitly exempted the rod, and it fixed the milking pail by giving it an action, not by delisting it (animal_store.lua:29 still sells the pail; animal_husbandry.gd:556 and player_2d.gd:353 use it).

**Player impact.** Small: a young player can spend 120 g early on a tool that does nothing yet.

**Recommendation.** Keep the teaser but stop charging for it: gift the rod, or show it as 'Kommer snart' and not buyable. Otherwise take it out of seed_shop stock until fishing ships. If it stays for sale, say 'Fiskeri åbner senere' in the shop row itself, not only in the description.

**Verification.** Partly. The facts are confirmed. Two framing corrections: pass 1 accepted the rod as an authored teaser, and the GM-03 analogy runs the other way. Recast as a new P3 UX suggestion.

### COMBAT-05 - Legendary and unique loot comes slowly and is mostly post-game; the first boss kill pays only a rune and most repeat boss chests are empty (P3, balance)

**Evidence**
- scripts/dungeon_loot/reward_rules.gd:14-19: first kill = first_kill_items (+extra) only; pool not rolled
- scripts/dungeon_loot/reward_rules.gd:21: repeat kill within respawn_days(7) -> empty result
- lua/data/loot_tables.lua:846,855-857,868-870: legendary_bp 1600/1600/800, pity_kills 6/6/10, Konge pool = sword_moon, staff_star, gem_moon_heart
- lua/data/loot_tables.lua:4: 'legendary items never come from chests'; scripts/dungeon_loot/container_rules.gd:42 filters ordinary rolls to normal/uncommon/rare
- lua/config/dungeon_loot.lua:31: `unique = { cooldown_days = 7 }` gates all hunted uniques (19 band spots incl. 3 lake chests + 8 wanderers = 27)
- scripts/loot/loot_markers.gd:127-128 + localization/features_ui.csv:47: an empty boss chest whispers 'Intet andet end støv og et lille hjerte af mos.' though nothing is given
- Analytic model of loot_tables odds (scratchpad dive.py): a full 12-floor dive yields ~0.24 rare furniture, ~0.24 rare clothing, ~0.12 rare weapons

**What's wrong.** The owner's pitch is that adventuring yields rare, unique and legendary loot. In the data, a full dive gives about 0.6 rare furniture, clothing or weapons in total. Uniques are limited to one per 7 days across all 27 hunted sources, so a complete dungeon collection takes at least 27 weeks (about 189 days, nearly 7 seasons). Legendaries come only from boss pools, and only on repeat kills spaced 7 days apart: on average about 4 weekly kills per Glødesvamp item and about 7 per Svampekonge item, so roughly 21 weeks for the Konge's three items after the first kill. The first kill of each boss, the emotional peak, drops a single key-rune, and the first boss's chest contains only that rune. When a boss is beaten again within its 7 days, the sealed chest opens to a generic 'nothing' whisper that also claims there is a 'little heart of moss'.

**Player impact.** The climactic boss victories feel unrewarded. Players who dive for legendaries go months of game time without one, and the repeat-boss loop teaches them that bosses are not worth fighting.

**Recommendation.** Make the first kill roll the boss pool once (guaranteed one item from `pool`), or pay a konge chest on the first kill as well. Shorten respawn_days to 3–4 or raise legendary_bp (for example Konge 1600, pity 6). Scope the unique cooldown per band rather than globally, or cut it to 3 days. Give the not-ready boss chest its own copy (for example 'Svampekongen har intet mere i denne uge – kom igen om %d dage') and remove the false 'hjerte af mos' wording, or make that line actually grant a moss item.

**Verification.** Partly. The empty or false boss-chest whisper ('… et lille hjerte af mos') is confirmed. 'The first boss kill pays only a rune' is wrong: it completes snurresvampen (1,200 g + the legendary hat_mushroom_spinner). The slow unique pace is a documented design choice. Downgraded from P2.

### COMBAT-11 - Runestones give unlimited full heals and oil; the oil-refill config is unused and a second visit the same day starts with leftover oil (P3, tech-debt)

**Evidence**
- scripts/dungeon/markers/runestone_2d.gd:45-48: every interaction calls heal_full() and restore_oil() (not only the first)
- scripts/world2d/enemy_2d.gd:166-173,191-194: enemies disengage within 520 px of a lit stone
- lua/config/dungeon.lua:23: `oil = { refill_new_floor = true, refill_runestone = true }` - no script reads these keys (rg finds none)
- scripts/dungeon/floors/dungeon_floors.gd:188-193: oil refills only on the FIRST entry of a floor per seed day; begin_dungeon_run (player_2d.gd:486-489) does not refill
- lua/config/race_perks.lua:135 comment: 'lantern oil per visit of the forest'
- scripts/dungeon_run/picker_lines.gd:13-17 sets `warn` flags that scripts/ui/rune_picker.gd:43-46 discards (plain text only)

**What's wrong.** Floors 3, 5, 7, 9 and 11 each have a safe zone where pressing E fully heals and refuels any number of times, which makes oil and tonics on those floors meaningless. The design flags that should control refills are dead data. Because the calendar is paused in the forest, players often leave to sell and come back the same day. Those floors are then already marked 'seen', so the lantern starts at whatever was left (possibly 0) and bites the player down to 1 heart, contrary to the 'per visit' comment. The rune picker computes warning flags for a weak weapon, no oil or a nearly full backpack but shows them as plain text, with no warning style.

**Player impact.** The resource pressure feels inconsistent: free healing on odd floors, and an unexpectedly empty lantern after a same-day re-entry.

**Recommendation.** Read dungeon.oil.refill_* in DungeonFloors and Runestone2D, make runestone rest once per floor per day (or heal only), refill the lantern in begin_dungeon_run if the design means 'per visit', and style rows with `warn` in the rune picker (for example honey label plus icon).

**Verification.** Confirmed against the cited code and data.

### COMBAT-12 - The first band has three Danish names: 'Mørkeskoven', 'Skovkanten' and 'Skovbrynet' (P3, copy)

**Evidence**
- lua/config/dungeon.lua:30: band skovkant `name_key = "ZONE_DARK_FOREST"` -> localization/core.csv:52 'Mørkeskoven' (also the name of the whole dungeon)
- localization/core.csv:53: ZONE_FOREST_EDGE 'Skovkanten' (the hub, docs/copy/GLOSSARY.md:51)
- localization/finds.csv:4: FIND_AREA_SKOVKANT 'Skovbrynet'; localization/dungeon_items.csv:55 'Ukendt sten (Skovbrynet)'
- English: hub and FIND_AREA_SKOVKANT are both 'The Forest Edge'

**What's wrong.** Floors 1–3 show the zone chip 'Mørkeskoven · 1', the same name as the dungeon as a whole. The hub is 'Skovkanten', and the finds and rough stones of those same floors say 'Skovbrynet'. In English the hub and band 1 share one name.

**Player impact.** Players cannot tell from the item names or the rune picker which part of the forest a stone or find came from.

**Recommendation.** Give band 1 its own glossary name (for example 'Skovkanten' for the band and 'Skovporten' for the hub, or keep the hub and use 'Skovbrynet' everywhere for the band). Add a ZONE_SKOVBRYNET key, point dungeon.bands.skovkant.name_key at it, and record it in docs/copy/GLOSSARY.md.

**Verification.** Confirmed against the cited code and data.

### SOCIAL-06 - A festival with closes = "all" shuts every shop in both towns, even where the keeper is not attending (P3, consistency)

**Evidence**
- scripts/social/social_manager.gd:783-794 shop_closed_by_festival - no area check; every shop not in stays_open is closed from one hour before the start until the end
- scripts/towns/hours.gd:125-128 - Hours.state returns reason 'festival' for any building whose shop is closed by the festival
- scripts/social/social_data.gd:285-300 - only home citizens of the festival's own area (plus ghost guests) attend, so Kvak, Sofus, Ugle and Natteblik never attend Hyggebyen festivals and the Hyggebyen keepers never attend Trætoppen ones
- Example: blomsterfesten (Hyggebyen, Sunday 12-20) closes Torvekroen, Badehuset, Uglehulen and Brumme's Sunday stall from 11:00 while their routines keep them at their counters; maanemarkedet/midsommerlanterner (to 23) leave Natteblik's 20-23:30 window open for only 30 minutes

**What's wrong.** The rule comment says shops close because 'the keepers walk to the festival then', but the closure applies to every building in both towns, while the roster only takes citizens from the festival's own town. The other town's keepers stay at work behind doors that say 'closed for the festival'.

**Player impact.** On 9 days a year the player finds shops shut in the other town for no visible reason, with the keeper standing inside. The days are predictable, so this is minor, but it is a visible inconsistency.

**Recommendation.** Limit the closure to the festival's own area: in shop_closed_by_festival, pass the building and return false when Hours.building(id).area != meta.area (the hoestfesten stays_open = { bakery } workaround then becomes unnecessary). Alternatively, send non-attending keepers home for the window.

**Verification.** Confirmed. The spec says shops close globally, so this is an inconsistency in the spec.

### SOCIAL-07 - Festivals are attended by one town only, so a partner or spouse from the other town never comes to half of them (P3, design)

**Evidence**
- scripts/social/social_data.gd:285-300 - the pool is home_area == meta.area; guests are only the ghost family
- lua/config/npcs.lua - partner candidates Hoppe, Brumme, Postman Pip, Sofus, Rasmus, Kiki and Bertil live in traetoppen; Maja, Merchant Pip, Birk and Bodil live in hyggebyen
- scripts/social/events/festival_stage.gd:156-161 - the 'dance' partner is the attending citizen with the most hearts; scripts/social/relationships/farm_visits.gd:36-43 - a spouse's home_area does not change after marriage

**What's wrong.** In-game Hyggebyen is a district of the treetop city, yet festival crowds are split by home district. A player engaged or married to Hoppe will never see Hoppe at blomsterfesten, honningdagen, maanemarkedet or bagedagen. The dance there picks the highest-hearts Hyggebyen resident instead.

**Player impact.** The romance and community payoff at festivals is missing for half of the calendar, depending on who you befriend.

**Recommendation.** Add the player's partner (stage >= 1) and spouse to meta.guests at runtime in SocialManager.festival_roster (the wedding already appends a dynamic `first`). Optionally add the top 2-3 highest-hearts friends from the other town as guests, within the 20-visual cap.

**Verification.** Confirmed against the cited code and data.

### SOCIAL-08 - The ghost-family lost-property errand can only be finished through the gift system, so it is blocked by the weekly gift limit (P3, ux)

**Evidence**
- scripts/ghostfam/quests/family_quests.gd:49-56 - the errand only completes on the game_event gift_given for the chosen owner and item
- scripts/social/gifts/gift_flow.gd:123-128 - refuses with reason 'today'/'week' when gifts.per_day 1 / per_week 2 are used up (lua/social/social.lua gifts)
- lua/quests/ghostfam_hittegods.lua - repeatable, cooldown_days = 7; the owners (oak, pippin, lily, brumme, sofus, ugle) are popular gift targets

**What's wrong.** Handing the owner their lost item counts as a normal gift. If the player has already gifted that owner twice this week (or once today), the return is refused with the weekly gift-limit message, and the errand cannot be finished until the limit resets. It also uses up one of the player's gift slots and awards taste points as if it were a present.

**Player impact.** A child who gifts their favourite NPC and then takes the lost-property errand gets a confusing 'you've given enough gifts' refusal with no hint that the errand needs to wait.

**Recommendation.** In GiftFlow.give_gift, skip the day/week limits (and the weekly ledger) when GhostFamilyQuests reports a pending return for this npc+item (e.g. a static is_return(npc, item)). Alternatively, add a dedicated 'Aflever hittegods' dialogue choice (like the seek card) that calls QuestManager.complete_manual directly.

**Verification.** Confirmed against the cited code and data.

### CORE-11 - Thunderstorm waters crops and plays rain audio but shows no rain; fog has no visual (P3, ux)

**Evidence**
- scripts/world2d/farm_grid.gd:293-294 `_rain()` is true for regn OR torden
- scripts/audio/audio_director.gd:61 rain audio plays for regn and torden
- scripts/world2d/weather_fx.gd:3-9 VISUAL_WEATHER = [&"regn"] only
- lua/config/ambient.lua:61-63 weather tints taage, sne and torden are all 'ffffff' (no tint)
- lua/config/game_balance.lua:96 summer has torden at 12%

**What's wrong.** On a 'Torden' day the crops count as watered and rain is heard, but the screen shows a clear sunny farm with no streaks, darkening or flashes. Fog ('Tåge', up to 25% of days in winter) is only a word in the HUD. Children learn that 'rain waters the crops' from the visual. A thunderstorm teaches nothing and looks like a bug when you hear rain under clear skies.

**Player impact.** Weather feels unreal on 1 day in 8 in summer, and the 'thunder waters my plants' rule cannot be discovered.

**Recommendation.** Add &"torden" to weather_fx.gd VISUAL_WEATHER (reuse the rain curtain plus occasional screen flashes) and give torden and taage tints in ambient.lua weather (for example torden 'b8bfd0', taage 'e6e8ec'), or use a soft fog overlay for taage.

**Verification.** Confirmed against the cited code and data.

### CORE-12 - On Windows, startup deletes stale .tmp saves, which can remove the only good copy after an interrupted replace (P3, tech-debt)

*Merged:* PRIOR-02 (P3, Status of prior review findings): Atomic-save fix is likely not atomic on Windows, and startup deletes the only surviving .tmp.

*Prior review (PRIOR-02):* docs/reviews/codex-review.txt 'Additional static persistence risk (failed-rename)'. The GDScript remove-then-retry was repaired in 7f3ccd39; the engine-side Windows rename risk remains. Re-verified against current code: still open.

**Evidence**
- scripts/autoload/save_manager.gd:1006-1007 replace uses DirAccess.rename_absolute(temp, target)
- scripts/autoload/save_manager.gd:150 and :941-944 `_remove_stale_temp_files()` deletes every *.tmp in user://saves at startup without checking it
- scripts/autoload/save_manager.gd:6 'the auto slot has no backup'
- [PRIOR-02] tests/sections/save.gd:1189-1195 asserts that a stale .tmp is swept, so the current behaviour is pinned by a test

**What's wrong.** On POSIX (macOS) the rename is atomic. Godot's Windows DirAccess.rename removes an existing destination before _wrename (engine behaviour, not tested here). A crash or power loss between those two steps leaves save_auto.json missing and a fully verified save_auto.json.tmp on disk. At the next start, _remove_stale_temp_files deletes that .tmp, so the auto slot, which has no .bak, is lost. Windows is a release target.

**Merged findings add.** PRIOR-02 traces this to the Codex atomic-save fix (7f3ccd39). That fix removed the GDScript remove-then-retry, but on Windows Godot's rename is believed to remove the destination before MoveFileW. This comes from memory of Godot 4.x and was not checked against the 4.7 source, so it stays plausible, not proven. The startup sweep has no 'promote the .tmp if the target is missing' path, and that part is confirmed. The .tmp has already been read back and verified at that point, so promoting it is cheap and safe. Update the save.gd test that pins the sweep together with the fix.

**Player impact.** Rare but total loss of the autosave (and therefore of Continue) after a badly timed crash on Windows.

**Recommendation.** In _remove_stale_temp_files, when the matching primary is missing (or fails _read_json_file and validate_payload) and the .tmp validates, rename the .tmp to the primary instead of deleting it. Optionally give the auto slot the same .bak rotation as the manual slots.

**Verification.** Confirmed against the cited code and data. PRIOR-02: Partly. The code and the missing promote path are confirmed; the engine behaviour is plausible but unproven. Lowered from P2 to P3: the loss window is microseconds between two syscalls during an autosave, on Windows only (macOS rename(2) is atomic).

### HOME-05 - No collection view: the Samlerbog screen is still missing while its key and save slot remain (P3, missing-feature)

*Prior review:* GM-09 'The advertised Collection key has no screen' (docs/review/game-mechanics-2026-10-17.md:83) - still open: docs fixed, screen still absent and C still bound. Re-verified against current code: still open.

**Evidence**
- scripts/ui/game_ui.gd:37 SCREEN_ORDER lists &"samlerbog"; scenes/ui/samlerbog.tscn does not exist (find, git log --all: never committed)
- scripts/ui/pause_menu.gd:41 the 'Samlerbog' row is silently skipped when the screen is null
- project.godot:269 input action 'collection' bound to physical key C (67) with no handler
- scripts/autoload/save_manager.gd:78 FEATURE_ORDERS reserves 'collection': 50
- docs/design/PLAN_2D_FEATURES.md:58 RV-C12: 'hints of the 49 keepsakes are visible only after owning the piece'; Samlerbog kept optional (F9)

**What's wrong.** The owner's brief centres on collecting rare, unique and legendary furniture, clothing and gems across 226 items and 16 sets. The game has no place that lists what exists, what has been found, or where to look. Hints for the 49 one-of-a-kind keepsakes appear only after the piece is owned, and set progress is not shown (see the perks and sets finding). PLAYING.md no longer advertises C, which fixes part of GM-09. But C is still bound to nothing and the reserved save section is unused.

**Player impact.** Completionists can't track progress, and the long tail of keepsakes (spots, wanderers, boss pool, friendship gifts) is effectively invisible.

**Recommendation.** Ship F9 as specified (docs/design/PLAN_2D_FEATURES.md:785-799): a CollectionLog that marks items discovered on item_gained, plus a read-only samlerbog.tscn with category chips, rarity progress and silhouettes, and source lines drawn from item.sources ('kan købes / bygges / findes i skoven / belønning / gave'). At minimum, unbind 'collection' until it ships.

**Verification.** Partly. Making Samlerbog mandatory was explicitly rejected (PLAN_2D_FEATURES.md:58, F9 optional). What remains is GM-09: C is bound to nothing and a save section is reserved. Downgraded from P2.

### HOME-06 - Clothing quest and dialogue rewards the player already owns are silently lost forever (P3, bug)

**Evidence**
- scripts/wardrobe/wardrobe_manager.gd:39-40 can_add requires count_total(id) == 0
- scripts/autoload/quest_manager.gd:633-648 claim_rewards keeps any item that fails can_add_item in pending_rewards and retries it forever; no duplicate sale
- lua/quests/fix_roof.lua:38 hat_chef_white (also sold in tailor rotation, home_shops.lua:154, and found in skovkant/dybe_bregner)
- lua/quests/ghostfam_garn.lua:26-28 shirt_knit_blue (tailor rotation, dungeon find)
- lua/quests/lost_cat.lua:58 hat_cat_ears (rare dungeon pool in dybe_bregner and skovkant)
- lua/dialogue/ghostfam_dyne.lua:23 api.add_item('shirt_knit_cream', 1) (normal, tailor fixed stock)
- lua/data/loot_tables.lua duplicates = {action = 'sell', message_key = FIND_UI_DUPLICATE_FMT}, which applies only to the loot path

**What's wrong.** If the player bought or found one of these garments before finishing the quest or kin scene, the reward can never be delivered. It sits in the save's pending_rewards, is retried on every inventory change and load, and gives no gold or message. Loot duplicates, by contrast, are auto-sold with a toast.

**Player impact.** A promised reward visibly fails to arrive, with no explanation and no compensation.

**Recommendation.** In QuestManager.claim_rewards (and the Lua add_item API), apply the loot duplicate rule: when the item is clothing, or a one-of-a-kind piece already owned, pay sell_price and post FIND_UI_DUPLICATE_FMT, then clear it from owed. Alternatively, swap these four rewards for pieces that can only come from that quest.

**Verification.** Confirmed against the cited code and data.

### HOME-07 - Ghost trousers and boots are now drawn as thin hem bands, and the leftover 'hidden' copy contradicts that (P3, consistency)

**Evidence**
- assets/wardrobe/manifest.json bodies.ghost_bu.layers includes pants_* and shoes_*; fits pants_trousers [82,179,92,20], i.e. a 20 px strip below the shirt (shirt_linen fit [78,137,99,58])
- scripts/wardrobe/wardrobe_tailoring.gd:20-23 ghost drapes are attached to the wisp itself
- docs/qa/clothing-fit/final-ghost/catalog_ghost_bu_02.png 'Haveoverall' (dungarees) is drawn as a flat strip with no bib, and boots are drawn as detached brown blobs under the hem
- localization/ghost.csv:13-15 GHOST_WARDROBE_NOTE / GHOST_HIDDEN_TAG / GHOST_EQUIP_HIDDEN_FMT ('bukser og sko ses ikke') - no script uses them; tests/sections/ghost.gd:88 still requires them

**What's wrong.** The owner's premise 'worn but not drawn' is no longer accurate. The hidden-slot design was replaced by under-hem bands. The bands barely read, though: different kinds of trousers become the same coloured belt, and the legendary pants_trousers_starlight and shoes_boots_wind (a capstone and a boss prize) show up as a stripe and two blobs. The three hidden-slot strings are dead, and they would mislead if anyone wired them back in.

**Player impact.** Small. Ghost players get little visual payoff from 29 of the 96 garments, including two top-tier rewards.

**Recommendation.** Either accept bands and delete the three ghost.csv keys and the test expectation, or add ghost-specific hem designs (a star-dust hem for starlight, wisp-wings for wind boots). Consider giving the dungarees family a bib on the ghost body (wardrobe_rules.lua layer_z pants_dungarees = 22 already orders it above the shirt).

**Verification.** Confirmed against the cited code and data.

### HOME-08 - Weekly guest gifts at the castle are still nails, pine planks or starter clothes (P3, balance)

**Evidence**
- scripts/home/home_data.gd:30-31 VISIT_ZONE 'farm', VISIT_CONTAINER 'trae' for every tier
- lua/data/loot_tables.lua zones.farm.pools: material normal = nails, plank_pine, straw_bundle; furniture normal = vase_clay; clothing normal = 5 starter-tier pieces; no uncommon or rare
- lua/data/home_tiers.lua:364 tier 10 guest_visits_per_week = 5
- localization/partner.csv:47 PARTNER_VISITOR '%s har lagt en lille gave til dig.'

**What's wrong.** A 4+ heart friend 'leaving a gift' always draws from the farm's normal-only pool, whatever the tier, the friend or their hearts. Four of the five clothing results are starter-kit pieces the player owns, so they are auto-sold for 20 g. Going from 1 to 5 visits a week across tiers 3-10 multiplies junk.

**Player impact.** A social and home payoff that should feel warm reads as spam ('Rosa left you Søm').

**Recommendation.** Add a dedicated `visit` container with a friend-specific or loved-gift pool, or roll from the visitor's gift_tastes 'love' list. Scale odds by tier (e.g. uncommon at t6+, a rare pity at t9+), and remove starter clothing from the visit pool.

**Verification.** Partly. The mechanism is confirmed. Only 2 of the 5 farm garments are starter pieces, but all become auto-sold duplicates over a playthrough.

### HOME-09 - The 'two best sets' wardrobe cap is applied per perk kind, so three sets can count at once (P3, bug)

**Evidence**
- lua/data/wardrobe_rules.lua:3,24 'at most this many outfit sets give a bonus at the same time (the two best)', max_sets_counted = 2
- scripts/wardrobe/wardrobe_manager.gd:133-142 gear_points takes the top-2 bonus VALUES separately for each kind across all active sets

**What's wrong.** Example of a legal outfit: earrings_glowcap + shoes_slippers_pompom (svampesamleren 2), bracelet_string + hat_chef_white (bageren 2), and necklace_dewdrop + pants_trousers_moss + shirt_knit_thornberry (nattevandreren 3). That is three active sets. Luck takes .01 + .01 (svamp + natte), discount .01 (bageren) and speed .01 (natte), so all three sets contribute, not two.

**Player impact.** Negligible numerically. It breaks a stated rule and any UI that lists the 'two counted sets'.

**Recommendation.** Rank the sets once, by total bonus or by a priority, and take the best max_sets_counted sets. Then sum their bonuses per kind.

**Verification.** Confirmed against the cited code and data.

### HOME-11 - Copy and data inconsistencies in cosiness, rarity names and home rooms (P3, copy)

**Evidence**
- localization/home.csv:21 HOME_TIER_7_GATE '…dit hjem allerede er lunt og pænt' while home_tiers.lua:244 requires hygge 2 = HYGGE_HYGGELIGT (home.csv:63), not HYGGE_LUNT (index 1)
- localization/home_ui.csv:44 INDRET_RARITY_UNCOMMON 'Usædvanlig' vs localization/finds.csv:29 RARITY_UNCOMMON 'Ualmindelig'
- lua/data/home_tiers.lua:33,64,…,365 perks.rooms (kitchen, loft, music_room, throne_room, royal_garden …) and localization/home.csv:31-35 HOME_ROOM_* are never read; each tier is a single growing room (assets/data/home/rooms/room_tNN.json)
- lua/data/home_tiers.lua:98 guest_visits_per_week = 1 at tier 3 while the 'guest_visits' unlock is listed at tier 4 (:138); home_manager.gd:450 does not check the unlock

**What's wrong.** Four small mismatches. The tier 7 gate copy names a lower cosiness level than the one required. One rarity has two different Danish names. A 14-room data model is never used. Guest visits start one tier before their unlock is announced.

**Player impact.** Minor confusion. 'Lunt' is reached long before the gate opens, and the filter chip doesn't match the rarity label shown on items.

**Recommendation.** Change the t7 gate copy to 'hyggeligt', or require hygge 1. Use 'Ualmindelig' in INDRET_RARITY_UNCOMMON and add rarity terms to docs/copy/GLOSSARY.md. Remove perks.rooms and HOME_ROOM_*, or surface them in the tier description. Set t3 guest_visits_per_week = 0, or move the unlock to t3.

**Verification.** Confirmed (the visit roll is at home_manager.gd:475-480).

### GAP-WORLD-TRAVERSAL-05 - Notice board is hard to reach and shows a fixed giver-ordered list that hides most givers (P3, design)

**Evidence**
- data/traetoppen/traetoppen.json props 'notice_board' (level upper, at [930,520], decor:true) is painted as a plain sprite by city_builder.gd:381-404; there is no handler on the outdoor board
- data/interiors/core/int_raadhuset.json:35 the only NoticeBoard2D is inside the Rådhus; lua/buildings/traetoppen.lua:58-65 Rådhuset hours 09:00-15:00, closed Sat/Sun
- scripts/traetoppen/life/notice_board_2d.gd:10 offers().slice(0, 5); life_flow.gd:28-29 + quest_manager.gd:384-390 keep the fixed giver order mayor_lyra, baker_maja, merchant_pip, farmer_rosa, fairy_lily, smith_thorin
- lua/config/npcs.lua:56,74: on day 1 the board is fix_roof, enchanted_garden, fairy_friendship, cookie_delivery, birthday_cake, so supply_run, first_animal, animal_products, math_harvest_puzzle, flower_necklace and the Thorin quests cannot appear until those are accepted or done
- notice_board_2d.gd:22 a row shows only QUEST_<ID>_TITLE (no giver, place or reward); localization/life.csv LIFE_BOARD_INTRO 'Her er dagens opslag.' although the list never changes by day

**What's wrong.** The board on the Rådhus terrace looks interactive but is decoration. The real board is indoors and reachable only 6 h on 5 days a week, the same window in which the mayor sits at her desk. Its content is the head of a static list: the mayor's three repeatable or long quests and Maja's two fill the 5 slots, so four of the six configured givers are hidden for most of the early game. Rows carry no giver or location, so after accepting the player does not know where to turn in. (The offers do respect is_offerable / requires_zone, and accepting goes through QuestManager.accept_quest correctly, apart from the dialogue_started leak reported separately.)

**Player impact.** Players who reach town after 15:00 or at weekends never see the board. Those who do see the same five notices day after day and cannot discover Pip's, Rosa's, Lily's or Thorin's errands there.

**Recommendation.** Make the outdoor 'notice_board' prop on 'upper' the interactive NoticeBoard2D: add a 'board' marker to traetoppen.json markers so it is open all day. Keep the indoor one as flavour. Rotate the offers: take at most one quest per giver, then fill to traetoppen.board.max, seeded by total_day the way post_box_2d.gd:43 does. Show 'Fra: <giver> · <location>' under each title, using TTQuestText.from_line.

**Verification.** Partly. The board facts are confirmed. The farm mailbox rotates all six givers and the givers show '!' bubbles, so the quests can be reached elsewhere. Downgraded from P2.

### GAP-WORLD-TRAVERSAL-07 - Wayfinding copy names things inconsistently (Posthuset/Postkontoret, English town names) (P3, copy)

**Evidence**
- localization/farm_signs.csv:4 SIGN_FARM_FOREST 'Tag Skovliften ved Posthuset.' vs localization/towns.csv:7 BLD_POSTKONTORET 'Postkontoret' and traetoppen.csv:4 TRAE_LANDMARK_3 'Postkontoret'
- localization/post.csv:4-5 POST_GROUP_TRAETOPPEN en 'Treetop Town', POST_GROUP_HYGGEBYEN en 'Hygge Town' vs localization/core.csv:50-51 ZONE_TRAETOPPEN en 'Trætoppen', ZONE_CITY en 'Hyggebyen'
- localization/life.csv LIFE_STOP_SKOVLIFT en 'Forest lift' vs TRAE_SIGN_SKOVLIFT en 'The Skovlift'

**What's wrong.** The one farm sign that tells the player how to reach the forest names a building that does not exist under that name. The English strings use three different names for the same two towns and the lift.

**Player impact.** A player who follows the sign looks for 'Posthuset' and finds only 'Postkontoret'. Minor, but it is the first directional hint to the dungeon.

**Recommendation.** Change SIGN_FARM_FOREST da to 'Tag Skovliften ved Postkontoret.' Align the en values of POST_GROUP_TRAETOPPEN and POST_GROUP_HYGGEBYEN with ZONE_* ('Trætoppen', 'Hyggebyen'), and use 'the Skovlift' consistently, per docs/copy/GLOSSARY.md.

**Verification.** Confirmed against the cited code and data.


## Game UI

### Area: HUD and in-world UI

The in-world HUD matches the Miljøer v2 sketch closely. The date chip and the money/Energi chip pass their pixel comparisons against the guide. The clock handles the 06:00-02:00 day correctly: raw 25:30 shows as "01:30" under the same weekday and date, through one formatter that has tests. The HUD is event-driven and never takes focus. The main problems are about how HUD elements share the screen, not about missing pieces. Toasts posted while a modal is open (quest accepted or completed in dialogue, hotbar assignment in the backpack) time out unseen. The whisper box covers hotbar slot 1. In Mørkeskoven the top-centre toasts cover the "Etage N" floor banner and sit under the boss bar. The forest camera has no HUD-safe margin, so the hero spawns under HUD panels. Content and accessibility gaps: the four ability slots still show placeholder words instead of icons, the drink count is unreadable, the quest tracker always shows the three oldest quests and can't be pinned, and the smallest HUD text is 10-14 px with no text-size setting. The remaining findings are copy and polish ("Solskin" at midnight, "Skovkanten · 0", "etage 1–1", count badges on tools, an unlabelled birthday chip). None of these is a blocker.

**Strengths**
- Clock handling for the 26-hour day is correct and pinned by tests.
- The HUD matches the Miljøer v2 sketch closely. comparison_date.png and comparison_chip.png are nearly identical to their reference crops. hud.v2_date_compare, v2_chip_compare and v2_banner_compare pass (windowed_baseline_run.log:56-91).
- The HUD architecture is clean.
- The forest HUD is thoughtfully built.
- The dive picker states the 10% gold-loss stake before every dive ('Besvimer du, mister du 10 % af dine guldagern (ca. 50)', dungeon_hud_picker_lines.png).
- Every world refusal has feedback through the whisper line (bed too early, locked warp, missing items).
- Prior HUD findings are fixed: devin-review 1.4 (no weather_changed listener) and 1.5 (wrong stats keys). hud.gd:64 connects weather_changed and hud.gd:149-154 reads half_hearts/max_half_hearts.

### Area: Menus and gameplay panels

The menus and panels sit on a solid shared base. TTScreen gives every screen the modal stack, Esc closing only the top layer, focus return to the opener, a focus-loss guard and a swallowed closing press, and the main flows (title, select, pause, settings, save/load, shop, journal, gift, people) look like the style guide. The weak spots are the panels built in code (Husbyggeri, Indretning, Hjemmets kiste, Byg, Dine dyr, Hjem og hverdag). They ignore their UI_NAVIGATION screen cards: first focus lands on "Luk", and pressing any list row rebuilds the list, so the focus guard throws the player back to "Luk" after every pick or transfer. That makes keyboard play tiring in the exact places the owner's home, furniture and animal loop lives. The biggest discoverability gap: Indretning, the only way to place furniture, opens only with an untaught H key and appears in no menu, prompt, tutorial or doc. Other gaps: festival details, hidden error toasts (an "inventory full" purchase gets a "sold out" line instead), missing or unreadable key hints, the Husbyggeri ladder not showing the current tier or its gates clearly, and a cheat menu that ships in the player's pause menu. Copy is warm and free of "Fesby" leftovers, but has a few Danish slips: "slot" in the save toasts, decimal points, and mixed date formats.

**Strengths**
- TTScreen (scripts/ui/nav/tt_screen.gd) gives all 21 modal screens one modal stack.
- Every destructive or costly confirm defaults to 'Fortryd' (pass3_ui_confirm.png; home_ui.gd:39 pins build_defaults_to_cancel).
- The shop shows affordability well.
- The quest journal follows focus and shows giver portrait, location, ticked steps and reward chips (pass3_ui_journal.png).
- The gift picker shows known tastes, the birthday multiplier, weekly/daily limits and how many quest items are hidden.
- The rune picker works as a pre-dive checklist (weapon suitability, oil, tonics, backpack, and 'Besvimer du, mister du 10 %… (ca. 50)').
- The 'Hvor er …?' post locator hides Blund while he plays hide-and-seek (post_locations.gd:27,40), so it does not spoil the minigame.
- Character select: four painted hero cards with Danish perk blurbs, appearance chips (Rasmus/Kiki), a gold ring on the selected card, and page 2 with sensible defaults (Eventyrrejsende / Min Trækronsgård).
- The garderobe has a live try-on preview, outfit sets (Arbejde/Skov/Fest), 'Se alt tøj' showing unowned pieces greyed out, and 'replaces X' warnings before equipping.
- No 'Fesby' leftovers anywhere in localization/, scripts/ui, lua/ or scenes/ui.

### Area: Danish copy, localization, accessibility

Localization engineering is in very good shape. Both offline lints pass (tools/loc/csv_lint.py: 66 CSVs, 4563 keys, 0 errors; tools/copy/copy_lint.py: 0 findings). All 2359 text keys referenced from Lua exist. Scenes contain no hard-coded text. No English leftovers or raw keys reach players. "Fesby" and the other banned names are gone, and the voice manifest shows 0 text drift across 296 clips. The weaknesses are in what the lints cannot see. First, the social copy is largely copy-paste: 30 of 34 NPC bios use one template, and the 125 gift-reaction rows contain only 5 distinct lines, which undercuts the "full social sim" goal. Second, a few player-facing texts give the wrong information: the hero-select blurbs are design-sheet notes, the pickaxe prompts say "hakke" (the hoe's name), and the math quest shows its own answers. Third, several Danish formatting rules are not applied: decimal comma, plurals, and lowercase weekdays mid-sentence. Accessibility is the weakest area. There is no key remapping, text-size or motion setting. Tutorial and refusal feedback is a 3.5-second whisper shown once per save. The key-hint bar is illegible (1.8:1 contrast) on the dark-backdrop screens. The forest assist presets and the player-paced dialogue are genuine strengths.

**Strengths**
- Localization pipeline is solid and verified: csv_lint PASS (66 files, 4563 keys, 0 errors/warnings), copy_lint 0 findings, every Lua *_key literal (2359) resolves in the merged CSVs, no hard-coded text in scenes/*.tscn, keep-imports in place, da/en % …
- No English leftovers in the Danish column and no Danish leftovers in the English column (scripted scan of all 4563 merged rows); no raw keys visible in any of the ~30 screenshots reviewed.
- 'Fesby' is fully purged (0 hits outside docs, 0 in docs); banned names (Lyra, Maja, Mjau, Eventyrskoven, PongPong) are absent from all CSVs.
- Voice: 296 clips (11 frozen human recordings + 285 Sara placeholders) with 0 drift between manifest text and current CSV text; voice is suppressed in English and stops on advance.
- Dialogue is player-paced: no auto-advance, the typewriter (40 chars/s, config ui.dialogue_chars_per_second) is skippable with one press, and body text is 19-20 px; the box grows with long lines (dialogue_ui.tscn TextLabel fit_content).
- Rarity is never colour-only: RarityPips adds shape and count per tier (rarity_pips.gd:3-4), and the five tier names match the owner's normal/uncommon/rare/unique/legendary.
- Forest assist presets (Hjælp i skoven: gentler hits, clearer telegraphs, extra hearts, wider swing, longer dodge, gentle dark; dungeon_run.csv:32-51) are a strong cozy-accessibility feature.
- Interaction prompts strip their baked 'E:' and show the live glyph (prompt_pill.gd:4, ui_hints.gd:98), so world prompts follow the device.
- Ghost-family, festival and mother-story copy is distinctive and warm (ghostfamily.csv: 168 rows, all distinct).

### Findings (41)

### MENUS-01 - Indretning (furniture placement) has no discoverable entry point (P1, missing-feature)

**Evidence**
- scripts/ui/indretning_ui.gd:25 hotkey_action = &"decorate" (H / pad Back). This is the ONLY way to open it; a repo-wide grep finds no other opener.
- scripts/ui/pause_menu.gd:39 pause rows = inventory, journal, people, build, garderobe, samlerbog. There is no Indretning row. The only row that prints its hotkey is the cheat menu ('Testmenu · F8').
- lua/farm/farm_tutorial.lua:28-37 hints cover hoe, seeds, can, harvest, bin, energy, bridge, bed, mail, expand. None covers decorate/H (or I/J/P/G).
- docs/PLAYING.md:37 'use … the decorating screen to place owned furniture' names no key.
- localization/features_ui.csv:54 INDRET_ONLY_HOME 'Sæt det op i Indretning.' tells the player to use Indretning without saying how to open it.
- docs/review/pass3/shots/pass3_home_interior.png: at home the only prompt is 'E Sov'; nothing hints at decorating.

**What's wrong.** Bought furniture goes to a separate store ('Møbler og tøj har deres egne magasiner', KISTE_HINT). The only way to place it is Indretning, and that opens only through the H hotkey while standing at home. The pause menu does not list it, the tutorial never teaches it, no world prompt, furniture-shop line or NPC mentions it, and even the player doc omits the key. The one message that names Indretning does not say how to reach it.

**Player impact.** A player who buys furniture (one of the owner's headline systems: furniture in 5 rarities, hygge and sets gating home tiers 7-10) cannot find out how to place it, short of pressing random keys. Hygge-gated home tiers then stall with no visible reason.

**Recommendation.** Add an 'Indret' row to the pause menu while at home (pause_menu.gd _specs, same transfer pattern as garderobe). Add a world prompt or interactable at the home chest or bed ('H · Indret'), plus a one-time whisper the first time furniture enters FurnitureManager.stock or the player first enters home with stock > 0. Show hotkeys on the pause rows (e.g. 'Rygsæk · I') via UiHints.glyph, and give H in PLAYING.md.

**Verification.** Confirmed by two skeptics. It is also worse than reported: using a furniture item from the hotbar while at home whispers 'Det her hører til derhjemme' (player_2d.gd:338-340).

### HUD-04 - Forest camera has no HUD-safe margin: the hero spawns under HUD panels (P2, ux)

**Evidence**
- scripts/world2d/iso_area.gd:449-454 - `camera_rect()` returns `play_rect` for ortho areas, with no margin
- scripts/world2d/player_body_2d.gd:134-142 - camera limits are set straight from that rect
- pass3_moerkeskoven_surface.png and pass3_moerkeskoven_surface_night.png - on arrival at the southern gate spawn only the fox's ears show (x≈645, y≈520); the body is behind the 'Våben · Rustent sværd' badge and the ability row
- pass3_dungeon_f1_hud.png - the fox at about (175,185) sits directly under the Lygteolie pill
- sections/dungeon_hud_hearts_9_layout.png - the fox at about (130,180) is behind the hearts plate and the 'Hjælp i skoven' label

**What's wrong.** In ortho areas the camera clamps to the playable rectangle. Spawns and walkable cells near the map edge therefore render under the HUD's fixed corner and bottom panels: hearts and oil top-left (to about y 230), minimap top-right, and the weapon badge plus ability bar bottom-centre (from about y 540). The arrival point of the forest hub sits exactly under the bottom HUD cluster.

**Player impact.** The player can lose sight of their own character, and of enemies attacking from the map edge, in a real-time combat area.

**Recommendation.** Grow the ortho camera rect by HUD-safe margins, e.g. `play_rect.grow_individual(0, 200, 0, 220)` in IsoArea.camera_rect for projection ortho, so the camera can scroll the edge cells into the clear centre. Alternatively, move the hub's `default`/`from_traetoppen` spawn about 4 cells north in data/maps/moerkeskoven.map. Add a check that the player's screen position at every spawn lies outside the forest HUD control rects.

**Verification.** Confirmed against the cited code and data.

### HUD-06 - HUD quest tracker always shows the 3 oldest active quests; quests can't be pinned (P2, design)

**Evidence**
- scripts/autoload/quest_manager.gd:1072-1078 - `get_tracked()` takes the first max_count entries of get_active_ids()
- scripts/autoload/quest_manager.gd:1081-1092 - get_active_ids is sorted 'oldest accepted first'
- scripts/ui/hud.gd:203 - `QuestManager.get_tracked(3)`
- scripts/ui/quest_journal.gd - no track/pin control (grep for 'track' finds nothing)

**What's wrong.** The quest card is the HUD's only guidance surface, but which quests it shows is fixed: always the three accepted earliest. Long-running quests (the mother story chain, weekly or seasonal errands) occupy it permanently. Once three are active, a newly accepted quest, such as today's post letter, a board errand or a birthday task, never appears on the HUD, and the player has no way to change this.

**Player impact.** The player has to open the journal to remember what they just agreed to do. The HUD tracker loses its purpose in mid-game, when several quests are active at once.

**Recommendation.** Add a per-quest `tracked` flag (saved) with a 'Følg / Følg ikke' row in the journal's Aktive tab. get_tracked should return tracked quests first, then the most recently progressed or accepted ones (newest first) instead of the oldest. Pin the behaviour with a hud check that uses 4 or more active quests.

**Verification.** Confirmed against the cited code and data.

### MENUS-02 - Code-built home and farm panels open on 'Luk' and send focus back to 'Luk' after every pick or transfer (P2, ux)

*Merged:* HOME-10 (P3, Home): Husbyggeri drops keyboard focus each time a tier is selected.

**Evidence**
- scripts/ui/home_chest_ui.gd:44-45 _initial_focus() returns close_button. :58 L.clear(lists[index]) on every refresh. :73,80 each 'Flyt 1'/'Alle' press calls _refresh_texts(), which frees the focused button.
- scripts/ui/husbyggeri_ui.gd:56-57 initial focus = close_button (or Byg). :61 L.clear(ladder). :66 a ladder press sets selected and rebuilds the ladder.
- scripts/ui/build_menu_ui.gd:81-82 initial focus = Luk/Byg. :87 L.clear(building_list). :92 press rebuilds.
- scripts/ui/animal_care_ui.gd:98-99 initial = feed or close. :102 L.clear(animal_list). :111 press rebuilds.
- scripts/ui/indretning_ui.gd:89-90 initial = close_button. :198-201 Esc from PLACE calls _apply_initial_focus() (= Luk).
- scripts/ui/home_amenities_ui.gd:60 initial = close_button.
- scripts/ui/social/social_layout.gd clear() remove_child + queue_free. scripts/ui/nav/tt_screen.gd:232-243 the guard falls back to _initial_focus() when _last_good is gone.
- UI_NAVIGATION.md S16-S20 specify instead: animal = the interacted animal, build menu = first building, Husbyggeri = the next tier row, Indretning PLACE→BROWSE = 'the drawer row of that piece', chest = first backpack cell.
- pass3_ui_husbyggeri.png, pass3_ui_indretning.png, pass3_ui_home_chest.png, pass3_ui_home_amenities.png all show the gold ring on 'Luk'.
- [HOME-10] scripts/ui/husbyggeri_ui.gd:61-66 _refresh_texts clears and recreates every ladder button; the button's pressed handler calls _refresh_texts
- [HOME-10] scripts/ui/social/social_layout.gd:81-84 clear() does remove_child + queue_free on the focused node
- [HOME-10] scripts/ui/nav/tt_screen.gd:21-22 the focus-loss guard restores _initial_focus() (Build or Close, husbyggeri_ui.gd:56-57)
- [HOME-10] husbyggeri_ui.gd has no UiNav.wire_* calls, unlike indretning_ui.gd:121-124 and home_amenities_ui.gd:86-88

**What's wrong.** These six panels are built in code with SocialLayout. They rebuild their whole button list on every action. The focused button is freed, TTScreen's focus-loss guard finds no last-good control and falls back to _initial_focus(), and that is 'Luk' (top-right) in each panel. They also open on 'Luk' instead of the control their screen card names. The ui_audit only checks that some initial focus exists, and tests/sections/home_ui.gd drives these panels with button.pressed.emit() and direct field writes, so this never fails a test. The spec's checks home_ui.husbyggeri_focus_walk, keyboard_only_upgrade, drawer_focus_map and chest_focus_map do not exist in tests/.

**Merged findings add.** HOME-10 traces the same focus loss in the Husbyggeri ladder. Refreshes on day_started/home_upgraded also reset focus.

**Player impact.** Keyboard and gamepad players (the owner asks for full keyboard play) must walk back from the top-right 'Luk' after every chest transfer, every house-tier or building pick and every animal selection. Moving 10 stacks into the chest takes about 10× the presses it should. Esc out of furniture placement loses your place in the drawer.

**Recommendation.** Before L.clear, remember the focused row's id. After rebuilding, re-grab the matching new button (the pattern appraisal_ui.gd:150 already uses), or update rows in place like shop_ui's _row_cache. Make each _initial_focus() follow its screen card: the chest's first backpack row, Husbyggeri's row tier+1, the build menu's first building, the animal from the interaction, and in Indretning the drawer row of `selected`. Add the spec'd keyboard-only checks to tests/sections/home_ui.gd using UiAudit.press instead of pressed.emit().

**Verification.** Confirmed against the cited code and data. HOME-10: Confirmed against the cited code and data.

### MENUS-03 - Husbyggeri hides the current tier, and its gate rows skip the authored wording ('Borgmester Hyldeblomst 1 / 2') (P2, ux)

*Merged:* HOME-04 (P2, Home): Husbyggeri never shows the authored gate hints and shows cosiness as level indices.

**Evidence**
- scripts/ui/husbyggeri_ui.gd:59-63 every ladder row is a plain '%02d  %s' toggle. There is no built/current/next/locked state (spec S18: 'LadderRow (current / done / next with a gold chip / locked dashed)').
- scripts/ui/husbyggeri_ui.gd:69-75 the gate rows (quest/friend/hygge) fall to the `_` branch '%s  %d / %d' with row.name_key. The row's own `key` is ignored.
- scripts/home/home_manager.gd:178-188 each row carries key HOME_GATE_QUEST_FMT / HOME_GATE_FRIEND_FMT / HOME_GATE_HYGGE_FMT. localization/features_ui.csv:18-20 'Fuldfør opgaven: %s', '%s: %d hjerter', 'Hyggeniveau: %s' are never used.
- scripts/home/home_manager.gd:198-199 any tier other than tier+1 returns not_next. Selecting an ALREADY BUILT tier shows its gold and material rows against current stock (red 'missing' rows) plus 'Byg det næste trin først.' (home_ui.csv:11).
- pass3_ui_husbyggeri.png: tiers 01-10 look identical apart from the selected fill, materials show '0 / 20' in pink, and nothing says where Fyrretræsplanke/Kalk/Søm/Glasrude come from.
- [HOME-04] lua/data/home_tiers.lua:43,79,113,151,188,225,266,303,340 gate_hint_key = HOME_TIER_n_GATE
- [HOME-04] localization/home.csv:6-30 HOME_TIER_n_GATE text (e.g. t6 'Smeden Thorin ved, hvor man finder den i Krystalgrotten', t4/t7/t10 'Snak med hende en gang om ugen')
- [HOME-04] rg 'gate_hint' / '_GATE' over scripts/ and lua/dialogue: no consumer (only tests/sections/loc.gd lists the key)
- [HOME-04] scripts/ui/husbyggeri_ui.gd:73-81 non-gold or material rows rendered as '%s  %d / %d' % [tr(name_key), have, need]; for hygge, have and need are level indices (home_manager.gd:185-188)
- [HOME-04] localization/home_ui.csv:15 HUSBYG_BLOCK_GATE 'Opfyld de viste ønsker først.'

**What's wrong.** The 10-step home ladder (an owner requirement) never shows which tier you live in or which are built. The gate requirements that pace tiers 4-10 (mayor friendship, crystal_cave, snurresvampen, hygge levels) appear as bare '<name>  have / need'. A heart gate reads 'Borgmester Hyldeblomst  1 / 2' with no word for hearts, a quest gate reads '<quest title>  0 / 1' without 'Fuldfør opgaven', and a hygge gate reads '<level name>  2 / 3' as level indices, although localized formats for all three exist. Browsing a past tier shows misleading unmet requirements. Missing materials get only 'Saml de manglende materialer.' with no source.

**Merged findings add.** HOME-04 adds that the authored HOME_TIER_n_GATE hints (home.csv:6-30, e.g. 'Smeden Thorin ved, hvor man finder den i Krystalgrotten') have no consumer anywhere, and that cosiness rows show level indices ('Eventyrligt 3 / 4') while Indretning counts points (226 / 240).

**Player impact.** Players cannot see their own progress on the main long-term goal. They also cannot tell that tier 4 needs 2 hearts with Hyldeblomst or that tier 6 needs a deep-forest quest. Prior reviews already flagged the authored mid-tier wall (M1); this UI makes that wall unreadable.

**Recommendation.** Render each row with tr(row.key) % name (plus have/need for hearts and hygge). Mark ladder rows as done (✓, muted), current ('Dit hjem'), next (gold chip) and locked (dashed). For built tiers show 'Bygget' instead of the requirement list. Add a short source hint per material (e.g. 'Tømmerhandlen' from the shop stock lookup).

**Verification.** Confirmed against the cited code and data. HOME-04: Confirmed against the cited code and data.

### MENUS-04 - Detail pane follows focus in some panels and only Enter in others (shop, backpack, garderobe) (P2, consistency)

**Evidence**
- scripts/ui/shop_ui.gd:197 rows only connect `pressed` → _activate_row. There is no focus_entered → _select, yet hover_focus is applied (:317).
- scripts/ui/inventory_ui.gd:40 slots connect only `pressed` → _activate_slot.
- scripts/ui/garderobe.gd:369 grid items connect only `pressed` → _activate. :365 focus_entered only scrolls.
- Following focus: quest_journal.gd:144, social/people.gd:149, social/gift_picker.gd:161, appraisal_ui.gd, rune_picker.gd (focus_entered → _select).
- docs/review/pass3/shots/baseline_compare/shop_ui_smith_weapon_card_da.png: gold focus ring on 'Månesplint' while the detail and Køb describe 'Jernsværd'.
- pass3_ui_garderobe.png: ring on the dress tile, detail says 'Tom plads / Vælg en ting …'.

**What's wrong.** In the journal, people, gift, appraisal and rune screens, moving focus updates the detail. In the shop, backpack and garderobe it does not. The detail, the 'I alt' total and the Køb/Brug/Tag på buttons stay bound to the last row pressed, while the gold ring sits elsewhere. Pressing Enter selects but also jumps focus to the stepper or action button, so reading through items means Enter, back, next, Enter. The mouse makes it worse: hover moves the focus ring (hover_focus) but not the detail.

**Player impact.** When browsing a shop or the wardrobe by keyboard or pad, the ring shows one item and the description, price total and buy button another. A child can easily buy or equip the wrong thing, or never read item descriptions and rarity at all.

**Recommendation.** Connect focus_entered → _select (preview only, no focus move) on shop rows, backpack slots and garderobe tiles, as gift_picker.gd:161 does. Keep Enter as 'select and go to the action'. In the garderobe, call _select(id, false) on focus so the try-on only runs on Enter.

**Verification.** Confirmed against the cited code and data.

### MENUS-05 - Toasts are hidden while any panel is open, so a full backpack in a shop gets a 'sold out' line instead (P2, bug)

*Merged:* HUD-01 (P3, HUD and in-world UI): Toasts posted while a modal is open expire unseen (quest accepted/completed, hotbar assignment, crafting).

*Prior review:* devin-review-2026-10-15 §1.11 (shop refusal reasons not surfaced in the UI). The no_gold case is fixed; no_room is still open.. Re-verified against current code: still open.

**Evidence**
- scripts/ui/hud.gd:58 EventBus.modal_changed → toasts.visible = not GameManager.is_modal_open().
- scripts/autoload/economy_manager.gd:509-511 a buy that does not fit posts only NOTIF_INVENTORY_FULL (a toast, hidden behind the shop).
- scripts/economy/shop_system.gd:331-342 refusal = &"no_room".
- scripts/ui/shop_ui.gd:333 keeper line = 'CANNOT_PAY' if no_gold else 'SOLD_OUT'. localization/keepers.csv:64 KEEP_ANY_SOLD_OUT 'Den er der ikke flere af lige nu.'
- Toasts tick down while hidden (toast_stack.gd process ALWAYS, 4 s), so most are gone before the panel closes. That also drops STORE_ASSIGNED_FMT (inventory_ui.gd:223) and the save toast NOTIF_SAVED_MSG behind pause > Gem.
- [HUD-01] scripts/ui/hud.gd:58 - `EventBus.modal_changed.connect(func(_stack): toasts.visible = not GameManager.is_modal_open())`
- [HUD-01] scripts/ui/forest_hud.gd:151 - same hide-while-modal rule for the forest stack
- [HUD-01] scripts/ui/components/notification_toast.gd:46-50 - each toast runs its own 0.15 s + 4 s + 0.4 s tween and then calls queue_free, with no pause while hidden
- [HUD-01] scenes/ui/hud.tscn:670 - ToastStack `process_mode = 3` (ALWAYS), so the tween keeps running behind modals and pause
- [HUD-01] scripts/autoload/quest_manager.gd:475-479 (NOTIF_QUEST_ACCEPTED) and :601-605 (NOTIF_QUEST_COMPLETED) fire during dialogue; scripts/ui/dialogue_ui.gd:24 `modal_name = &"dialogue"`
- [HUD-01] scripts/ui/inventory_ui.gd:223 - STORE_ASSIGNED toast is posted from inside the backpack (inventory_ui.gd:21 `modal_name = &"inventory"`)
- [HUD-01] scripts/ui/components/workshop_panel.gd:134 - WORKSHOP_CRAFTED toast is posted from inside a modal panel
- [HUD-01] tests/sections/hud.gd - no check covers a toast posted under a modal

**What's wrong.** The HUD toast stack is hidden whenever a modal is open, but several panels rely on toasts for their feedback. In the shop, a purchase that fails because the backpack is full gets no visible toast, and the keeper says the item is sold out, which is false. Other refusals (no_stock via NOTIF_NO_STOCK) are likewise invisible but at least match the keeper's line.

**Merged findings add.** HUD-01 extends the problem to every toast posted under a modal: the toast stack is PROCESS_MODE_ALWAYS, so a hidden toast keeps ticking down and expires unseen. The real cases are the hotbar-assign toast in the backpack, the workshop craft toast, shop refusals and quest auto-completions fired from inside a modal. NPC-dialogue accept and turn-in toasts are not affected, because they fire after the dialogue closes.

**Player impact.** A player with 24/24 slots clicks Køb, sees 'Den er der ikke flere af lige nu' with stock clearly left, and doesn't learn that the backpack is the problem. The same blind spot hides hotbar-assignment confirmations and the save confirmation.

**Recommendation.** Map last_refusal &"no_room" to a keeper line such as KEEP_ANY_BAG_FULL ('Din rygsæk er fuld …') and also set a status line in the footer. More generally, keep toasts visible above the scrim (draw ToastStack on a layer above GameUI modals) or queue them until modal_changed empties the stack.

**Verification.** Confirmed against the cited code and data. HUD-01: Partly; the headline examples were wrong. Downgraded from P2.

### MENUS-06 - Key hints are missing on 11 screens and almost invisible (1.7:1) where drawn on the dark scrim (P2, accessibility)

*Merged:* COPY-03 (P2, Danish copy): Key-hint bar is about 1.8:1 contrast on dark-backdrop screens (inventory, journal and others).

**Evidence**
- Only 7 scenes carry a HintBar node (character_select, inventory_ui, save_load_ui, quest_journal, pause_menu, shop_ui, settings_ui; garderobe adds one in code). Missing on animal_care, appraisal, build_menu, home_amenities, home_chest, husbyggeri, rune_picker, gift_picker, people, forest_help/assist_panel and cheat_menu. UI_NAVIGATION.md 3.9: 'the same style is used for the hint line of every screen with focusable controls'.
- scenes/ui/inventory_ui.tscn:326, quest_journal.tscn:256, shop_ui.tscn:373 put the HintBar on the root (outside the panel, on the scrim). The spec says 'bottom-right inside the panel'.
- Measured from pass3_ui_inventory.png and pass3_ui_journal.png: hint text rgb(100,85,73) on scrim rgb(58,49,80) = 1.69:1 contrast. towns_city_seed_shop_panel.png shows the same problem in the real shop.
- scripts/ui/indretning_ui.gd:64 INDRET_HINT and towns/post_ui.gd:84 POST_HINT ('Skift by med sidetasterne') are static prose. Indretning's lists keyboard keys even for pad players.
- The shop hint offers only '↑↓ Vælg · Enter OK · Esc Tilbage'. Tab switching with PgUp/PgDn/LB/RB (shop_ui.gd:111) is never hinted, and neither is the hotbar-assign by number keys in the backpack (inventory_ui.gd:79-89).
- [COPY-03] scripts/ui/components/hint_bar.gd:3 - 'Plex Mono 11 (Eyebrow, #6a5a48)'; :125,129 - the word labels use Eyebrow
- [COPY-03] assets/ui/theme.tres:4036-4038 - Eyebrow font_color (0.416,0.353,0.282) = #6a5a48, font_size 11
- [COPY-03] docs/review/pass3/shots/pass3_ui_inventory.png and pass3_ui_journal.png (bottom right: 'Vælg · OK · Tilbage') - bar drawn on the dark plum backdrop (58,49,80)
- [COPY-03] Computed WCAG ratio: #6a5a48 on (58,49,80) = 1.83:1 (pixel-sampled 1.6-1.7:1); the same colour is 5.35:1 on the cream panel and 4.26:1 on the lilac shop backdrop

**What's wrong.** The hint system works (device-aware glyphs, live-key filtering), but most of the newer panels don't use it. Where it is used on full-screen panels it sits outside the parchment in #6a5a48 mono on the dark purple scrim, about 1.7:1 contrast, far below a legible threshold. Panel features that exist only as keys (page tabs, number-key assignment, R/X in Indretning) are never shown to the player.

**Merged findings add.** COPY-03 measures the contrast exactly: Eyebrow #6a5a48 on the scrim (58,49,80) is 1.83:1 (WCAG), against 5.35:1 on cream.

**Player impact.** Gamepad and keyboard players get no on-screen guidance on half the panels, and the guidance that exists on the backpack and journal is practically unreadable. This undercuts the 'full keyboard play' requirement and hides features.

**Recommendation.** Move the HintBar inside the panel's bottom edge (as pause/settings/save_load already do) or give it a chalk pill background on scrims. Add a HintBar to every TTScreen (e.g. instantiate it in TTScreen._ready when the subclass sets `hints`). Include PgUp/PgDn 'Skift fane' wherever _on_page is overridden, and '1-8 Hurtigplads' in the backpack. Replace INDRET_HINT and POST_HINT with HintBar items built from rotate_item / pickup_item / decorate / ui_page_*.

**Verification.** Confirmed against the cited code and data. COPY-03: Confirmed against the cited code and data.

### MENUS-07 - Festival details are never shown: descriptions unused, no place, truncated calendar, a focused day shows nothing (P2, ux)

**Evidence**
- lua/festivals/fixed/hoestfesten.lua:34 desc_key = "FEST_HOESTFESTEN_DESC", :39 spot = "torvet", :12 contest select = "category:crop". localization/festivals.csv has 9 FEST_*_DESC rows. A grep for desc_key in scripts/ finds only home_manager.gd:400 (home unlocks), so no UI ever reads a festival description.
- scripts/ui/social/social_hud.gd:39-44 the day-of ribbon is name + 'åben til / fra HH:MM' only (rel_ui.csv:40-41). There is no location.
- scripts/ui/social/calendar_tab.gd:118-120 the full text is only in captions (clipped) and the mouse tooltip. :122-130 the left panel always shows TODAY. Cells are focus stops that do nothing on focus or press.
- pass3_ui_calendar.png and sections/social_ui_journal_calendar.png: 'Månemarkede t…', 'Blomsterfeste n…' are broken mid-word, the left panel is mostly empty, and the journal's column divider (x≈533) shows through the calendar tab above and below the grid.

**What's wrong.** The owner wants 5 Trætoppen and 4 Hyggebyen festivals, and the data is rich (description, host, place, times, activities such as a pumpkin contest that needs a crop). The UI shows only a clipped name in the calendar and a name-plus-time ribbon on the day. Keyboard users can move through calendar days but the side panel never changes, and the full names live only in mouse tooltips.

**Player impact.** Players don't know which town a festival is in, what happens there or what to bring (e.g. a crop for Høstfesten's contest), so festivals feel like random crowds. Planning ahead, the point of a calendar, isn't possible.

**Recommendation.** Make the calendar's left panel show the FOCUSED day: date, festival name, tr(desc_key), place (spot → area name), from-to hours, activity names and needs (e.g. 'Tag en afgrøde med'), plus birthdays. Wire cell focus_entered to that panel. Use word-wrap with ellipsis per word, not per character. Add the place to REL_HUD_FROM/OPEN ('Høstfesten i dag · Torvet · fra 12:00'). Cover the journal divider behind the calendar host.

**Verification.** Confirmed against the cited code and data.

### MENUS-08 - Indretning drawer: invisible active filter, room for about 1 row, overlaps the HUD, and controls bypass the input map (P2, ux)

**Evidence**
- scripts/ui/indretning_ui.gd:41-51 the 12 layer and rarity filter buttons are plain ButtonTertiaryS: no toggle_mode or button_group, so the active filter is never shown (pass3_ui_indretning.png: both 'Alle' chips look like every other chip).
- indretning_ui.gd:29 panel Rect2(24,80,340,590). The filter grid plus header leave a list viewport of about 60 px. pass3_ui_indretning.png shows 'Jernstanderlampe ×1' cut mid-row, and the panel covers the HUD date chip ('Forår · Dag 1' peeks out behind it).
- indretning_ui.gd:113-117 drawer rows are a bare TTItemIcon + 'name ×n' button with no rarity tile, pips or rarity name, although rarity is a filter.
- indretning_ui.gd:169-170 rotate = physical KEY_R or JOY_BUTTON_Y and pickup = KEY_X or JOY_BUTTON_X, hard-coded. project.godot defines rotate_item (R / pad button 10 = RB) and pickup_item (X / RMB / pad X), and spec S19 says 'rotate_item (R / RB)'. On a pad, RB does not rotate.
- Spec S19 asks for filter chips as a radio row switched with Left/Right/LB/RB. Here they are a 3×4 button grid and _on_page is not overridden.

**What's wrong.** The furniture drawer is the main surface for one of the owner's headline features. The filter state is invisible, so after choosing 'Sjælden' the player can't tell why the list shrank. The list area shows about one and a half rows, so any real collection is a long scroll through a slot. The panel sits over the HUD. Rarity, an owner requirement, appears only as a filter, never on the items. Gamepad rotate uses Y instead of the mapped RB, and the in-panel hint lists only keyboard keys.

**Player impact.** Decorating, the payoff of collecting furniture, is cramped and confusing, and players can lose track of which filter is on. Pad players following the spec or the input map can't rotate with RB.

**Recommendation.** Make the filters PillTab toggles in ButtonGroups (or one radio row cycled by ui_page_*). Collapse the rarity filters into a single cycling chip, which frees about 120 px for the list. Use RaritySlot rows with pips, as spec S19 says. Hide the HUD date chip in decorate mode or move the drawer below it. Replace the hard-coded keys with event.is_action_pressed(&"rotate_item") / (&"pickup_item").

**Verification.** Confirmed against the cited code and data.

### MENUS-09 - Cheat menu ships in the player's pause menu and on F8, ungated (P2, design)

*Merged:* CORE-07 (P2, Core loop): The cheat menu ships in every build, opened from the pause menu and F8; COPY-08 (P2, Danish copy): Debug 'Testmenu · F8' (cheats) is an unconditional row in the player pause menu; FIRSTHOUR-11 (P2, First-hour / first-week playthrough trace): Cheat/test menu is reachable from every player's pause menu.

**Evidence**
- scripts/ui/pause_menu.gd:43 rows.append(["CheatButton", "CHEAT_TITLE", …]) unconditionally.
- project.godot:59 cheat_menu action (F8). scripts/ui/testing/cheat_menu.gd:2 'F8 and pause-menu access'.
- localization/cheats.csv:2 'Testmenu · F8', :10 'Giv 10.000 guld'. The menu also unlocks all clothing, fills hearts/energy/oil, travels anywhere and sets time and weather (PLAYING.md:73).
- A grep finds no OS.is_debug_build()/has_feature gate in scripts/ui; the only debug gate in scripts is lua_runtime.gd:71.
- pass3_ui_pause.png and sections/menus_pause_full_game.png: 'Testmenu · F8' sits between Garderobe and Gem, and it is the only pause row that shows a hotkey.
- [CORE-07] scripts/ui/pause_menu.gd:47 `rows.append(["CheatButton", "CHEAT_TITLE", _transfer.bind(&"cheat_menu")])` is not gated
- [CORE-07] scripts/ui/game_ui.gd:38 cheat_menu is in SCREEN_ORDER; scenes/ui/cheat_menu.tscn exists; project.godot:59 the cheat_menu action is bound to F8
- [CORE-07] scripts/ui/testing/cheat_menu.gd:38,51-56 gold, items, +1 hour and next day, clock freeze
- [CORE-07] scripts/autoload/lua_runtime.gd:71,76 the F9 Lua reload is gated by OS.is_debug_build(); the cheat menu is not
- [CORE-07] docs/PLAYING.md:73 documents it as a test tool; there is no export_presets.cfg yet
- [COPY-08] scripts/ui/pause_menu.gd:47 - rows.append(["CheatButton", "CHEAT_TITLE", _transfer.bind(&"cheat_menu")]) with no OS.is_debug_build()/feature check
- [COPY-08] scripts/ui/testing/cheat_menu.gd:1-30 - no release gating; hotkey_action cheat_menu (F8)
- [COPY-08] localization/cheats.csv:2 CHEAT_TITLE 'Testmenu · F8'; :10 CHEAT_GOLD 'Giv 10.000 guld'
- [COPY-08] docs/review/pass3/shots/pass3_ui_pause.png - 'Testmenu · F8' second row, above Gem
- [FIRSTHOUR-11] scripts/ui/pause_menu.gd:47 rows.append(["CheatButton", "CHEAT_TITLE", ...]) is unconditional; there is no OS.is_debug_build()/feature check in pause_menu.gd or scripts/ui/testing/cheat_menu.gd
- [FIRSTHOUR-11] localization/cheats.csv:2 CHEAT_TITLE 'Testmenu · F8'; project.godot cheat_menu bound to F8
- [FIRSTHOUR-11] docs/PLAYING.md:73 documents gold and item grants, travel and time control as normal save-affecting features

**What's wrong.** The test menu is a first-class row in the player-facing pause menu and one key away in any build. Its actions write to the normal save ('Genstande, penge og fremskridt bliver gemt med spillet.'). Release targets are macOS and Windows exports, and nothing hides it in a release build.

**Merged findings add.** Three other reviewers raised the same issue independently (CORE-07, COPY-08, FIRSTHOUR-11). The menu is deliberate and pinned by a test (`menus.full_game_pause_has_core_actions_and_test_menu`). The release branch (084321db) adds a map row but does not gate this one. It sits 7th or 8th in the pause list, just above Gem.

**Player impact.** A child who opens the pause menu sees 'Testmenu' and can give themselves 10 000 gold, skip progression and unlock all clothing permanently in their save. That collapses the economy and home progression the game is balanced around.

**Recommendation.** Show the row and the F8 binding only when OS.is_debug_build() or a dev feature tag / settings flag is set (pause_menu.gd _specs and cheat_menu._hotkey_open_allowed). Keep the tests working through the debug build. Optionally give non-debug builds a hidden code entry for the owner.

**Verification.** Confirmed against the cited code and data. CORE-07: Confirmed against the cited code and data. COPY-08: Confirmed. FIRSTHOUR-11: Partly.

### COPY-01 - No accessibility settings: no key remapping, text size, text/hint speed or reduce-motion option (P2, accessibility)

*Merged:* HUD-07 (P3, HUD and in-world UI): HUD text is as small as 10-14 px at 720p with no text-size setting.

**Evidence**
- scripts/ui/settings_ui.gd:4-6 - the only persisted options are PATH settings.cfg, SIZES [1280x720,1600x900,1920x1080], BUSES [Master, Music, Sfx, Voice]
- scripts/ui/settings_ui.gd:16-36 - the controls wired up are language, four volume sliders, fullscreen, window size, plus the in-world 'Hjælp i skoven' button
- docs/review/pass3/shots/pass3_ui_settings.png - Sprog / Hovedvolumen / Musik / Lyde / Stemmer / Fuldskærm / Vindue only
- docs/design/UI_NAVIGATION.md:337 - 'a rebinding in a later version changes the hint' (remapping is deferred, and no InputMap.action_erase_events/action_add_event exists in scripts/)
- scripts/world2d/player_combat_2d.gd:220,302,320 - camera shake (_shake_camera 2.0 / 4.0) with no toggle
- assets/ui/theme.tres:4038,4123,4139 - Eyebrow 11 px, HintButton 11 px, KeyCap 13 px: the smallest text, with no UI-scale option
- scripts/ui/dialogue_ui.gd:39 - typewriter speed is a Lua config value, not a player setting
- [HUD-07] scenes/ui/hud.tscn theme - HotkeyDigit font_size 10 (slot digits), HudDateLine font_size 14 IBM Plex Mono (weekday · clock · weather)
- [HUD-07] scripts/ui/hud.gd:141 - the clock lives in that 14 px line
- [HUD-07] scripts/ui/settings_ui.gd:109,114,126 - the only stored settings are audio, fullscreen and window size; there is no text or UI scale and no key rebinding
- [HUD-07] project.godot:42-45 - base 1280x720, stretch canvas_items (720p is the native size)
- [HUD-07] Style Guide text: 'Tal i Caprasimo … Penge, tid og antal står altid i display-skriften' and 'Kun i store størrelser, aldrig under 20 px'; 'Æ, ø og å står tydeligt ved 18 px'
- [HUD-07] pass3_farm_day_hud.png - the time '10:00' is the smallest text in the top-left chip; the tiny ability placeholders in pass3_dungeon_f1_hud.png

**What's wrong.** Settings offer only language, volume, fullscreen and window size. Players cannot rebind keys, cannot enlarge text or UI, cannot slow or lengthen transient text (whispers and toasts), and cannot turn off camera shake. A colour-vision option is missing too, though rarity already carries shapes. The forest assist panel covers combat difficulty only. For a children's game whose release targets are desktop keyboard/mouse plus gamepad, remapping and text size are baseline expectations, and the code already reads glyphs from the live InputMap, so remapping would propagate to all hints.

**Merged findings add.** HUD-07 adds the HUD specifics: the date/clock line is 14 px mono and the slot digits 10 px at native 720p. That is the owner-chosen Miljøer v2 sketch, but it conflicts with the guide's 'tal i Caprasimo, aldrig under 20 px'.

**Player impact.** Left-handed players, players with motor impairments or AZERTY/odd layouts, and young or low-vision readers cannot adapt the game. Small 11-13 px hint and secondary text cannot be enlarged.

**Recommendation.** Add a 'Tilgængelighed' section to settings_ui: (1) a key-remap list over the actions in project.godot, written to settings.cfg [input] and applied at boot; UiHints already reads the live InputMap. (2) A UI scale of 100/115/130% via content_scale_factor, or theme font-size multipliers. (3) 'Tekst bliver stående' (whisper/toast duration ×1.5/×2, or until dismissed). (4) 'Ryst skærmen' on/off, gating _shake_camera. (5) Typewriter speed, including instant. Store all of it beside the existing [audio]/[video] sections.

**Verification.** Confirmed against the cited code and data. HUD-07: Partly; the sizes match the owner-chosen sketch. Downgraded from P2.

### COPY-02 - Tutorial and refusal feedback are 3.5-second whispers shown once per save, replaced by the next whisper, and impossible to re-read (P2, accessibility)

**Evidence**
- scripts/ui/components/whisper_line.gd:9 - SECONDS := 3.5 regardless of text length; :3-5 - 'A second whisper replaces the first and restarts the timer'
- scripts/farm/steading/tutorial/tutorial_hints.gd:94-96 - sets flag tut_hint_<id> and then emits the whisper, so each farm tutorial hint is shown at most once per save
- lua/farm/farm_tutorial.lua:24-37 - all ten farm hints (hoe, seeds, can, harvest, bin, energy, bridge, bed, mail, expand) are delivered this way
- localization/farm_tutorial.csv:23 TUT_HINT_BED (13 words), localization/dungeon_run.csv:62 DTUT_HUB (15 words), localization/look.csv:2 LOOK_NATTEBLIK_SLEEPS (15 words): each must be read in 3.5 s
- No help, controls or 'Sådan spiller du' screen exists: no HELP_/GUIDE_/CONTROLS_ keys in any CSV
- docs/review/pass3/shots/pass3_farm_day_hud.png - the hint box (x≈40-392) also overlaps hotbar slot 1, the very slot it tells you to pick

**What's wrong.** The farm tutorial, the dungeon tutorial (DTUT_*) and every world refusal (bed before 18, locked warp, wrong tool) go through WhisperLine, which shows text for a fixed 3.5 s. A child reading 1.5-2 words/s needs 7-10 s for a 13-15-word hint. Each farm hint is flagged as shown the moment it is emitted, so a hint missed while looking elsewhere, or overwritten by another whisper (only one at a time), is lost for the whole save. Nothing in the game lets the player look the instructions up again.

**Player impact.** Young players miss core instructions (how to sleep, sell, water, use runestones) with no way to recover them, which leads to confusion or stalling in the first days.

**Recommendation.** Make the duration length-based: max(4.0, 1.5 + 0.4 × word count) s, multiplied by the new accessibility setting. Queue whispers instead of replacing them, or at least never replace a tutorial whisper with a refusal. Keep a tutorial hint on screen until its step completes ('on' event) instead of a timer. Add a 'Hjælp' tab to the journal (quest_journal) that lists every hint already shown (the tut_hint_<id> flags already record them) plus the controls from UiHints.

**Verification.** Confirmed. The persistent quest tracker partly mitigates this.

### COPY-04 - Hero-select blurbs are design-sheet notes shown verbatim to players, gendered and partly wrong (P2, copy)

*Merged:* CORE-10 (P3, Core loop): Hero select copy: Kiki shows the fox's perks, blurbs are cast-sheet developer text, and Kløvermynte is both the player and the shop fairy; FIRSTHOUR-10 (P3, First-hour / first-week playthrough trace): Character-select copy: the Kiki perk card is false, the blurbs are dev notes, and the default name ignores the hero.

**Evidence**
- scripts/ui/character_select.gd:106 - %HeroBlurb.text = tr(chosen.blurb_key)
- localization/cast.csv:6 HERO_RASMUS_BLURB 'Standardfiguren, når man vælger skovdyr. Stærke poter, så han graver hurtigere…'
- localization/cast.csv:9 HERO_KLOEVERMYNTE_BLURB 'Driver frøbutikken i Hyggebyen. Samme grundfigur bruges, når spilleren vælger at være fe…'
- localization/cast.csv:12 HERO_BIRK_BLURB 'Mandlig variant af feen og Kløvermyntes bror…'; :18 HERO_BODIL_BLURB 'Kvindelig variant af halvlingen og Bertils søster…'; :15 'Standardfiguren for halvlinge'; ghost.csv:10 'Standardfiguren for spøgelser'
- cast.csv:3 comment - 'the card BLURB verbatim from the Figurer v2 sheet (English = draft)'
- docs/copy/STYLE_SHEET.md R3 - 'no sentence assumes the hero's gender'
- docs/review/pass3/shots/pass3_ui_select_1.png - 'Standardfiguren, når man vælger skovdyr…' shown under the Udseende chips
- [CORE-10] scripts/ui/character_select.gd:108 `%PreviewPerk.text` always shows the race perk_key; localization/ui.csv:12 CHAR_ANIMAL_PERK 'Stærke poter. Graver hurtigere og får mere ud af høsten.'
- [CORE-10] lua/config/species_perks.lua:25-31 animal_monkey (Kiki): dig_speed 1.0, harvest_bonus_chance 0.0, so the shown perk is false for Kiki
- [CORE-10] localization/cast.csv:6 'Standardfiguren, når man vælger skovdyr', :12 'Driver frøbutikken i Hyggebyen. Samme grundfigur bruges, når spilleren vælger at være fe', :15 'Mandlig variant af feen', :18 'Standardfiguren for halvlinge ... går barfodet'; ghost.csv:9 'Standardfiguren for spøgelser'
- [CORE-10] lua/config/npcs.lua:76-93 merchant_pip ('Butiksfe Kløvermynte', core.csv:21) and :394-410 beekeeper_birk have routines lua/routines/core/merchant_pip.lua and beekeeper_birk.lua without hero_twin (rasmus, kiki, bertil and bodil have it: lua/routines/ext/*.lua)
- [CORE-10] lua/data/starter_kit.lua:21 every hero starts wearing shoes_boots_brown, including the halfling that 'goes barefoot'
- [FIRSTHOUR-10] character_select.gd:108 PreviewPerk = the race perk, so Kiki shows CHAR_ANIMAL_PERK 'Stærke poter. Graver hurtigere og får mere ud af høsten.' (ui.csv:12), but lua/config/species_perks.lua animal_monkey sets dig_speed=1.0 and harvest_bonus_chance=0.0, read by farm_grid.gd:242 and player_2d.gd:400
- [FIRSTHOUR-10] cast.csv:6 'Standardfiguren, når man vælger skovdyr.', cast.csv:12 'Samme grundfigur bruges, når spilleren vælger at være fe', cast.csv:18 'Standardfiguren for halvlinge.', ghost.csv:9 'Standardfiguren for spøgelser.': style-guide sheet notes shown as player copy
- [FIRSTHOUR-10] ui.csv:14 the hobbit gets a discount 'i Hyggebyens butikker', but race_perks.lua hobbit shop_discount applies in every shop (shop_system.gd:250-252 Perks.total)
- [FIRSTHOUR-10] character_select.gd:109/202: a blank name defaults to DEFAULT_PLAYER_NAME 'Eventyrrejsende' (da.csv:2), not the chosen hero's name (Rasmus, Pedro…)

**What's wrong.** The look descriptions on character select are art-direction notes ('default figure', 'base figure is used when the player chooses…', 'male/female variant of…'), not player copy. The fairy look tells the player that their hero runs the seed shop, which conflicts with the NPC Kløvermynte who does run it. Rasmus's text uses 'han' and two blurbs frame looks as male/female variants, contrary to R3.

**Merged findings add.** CORE-10 and FIRSTHOUR-10 add more problems on the same screen. Kiki is shown the fox's CHAR_ANIMAL_PERK ('Graver hurtigere og får mere ud af høsten'), but species_perks.lua gives her dig_speed 1.0 and harvest bonus 0. CHAR_HOBBIT_PERK limits the discount to Hyggebyen, but it applies in every shop. The halfling who 'går barfodet' starts in boots. A blank name defaults to 'Eventyrrejsende' rather than the chosen hero's name.

**Player impact.** The first screen of the game reads like an internal document. Choosing the Kløvermynte look implies the player is the shopkeeper, and the gendered framing goes against the project's own rule.

**Recommendation.** Rewrite HERO_*_BLURB (da+en) as short in-world descriptions with no 'figur/variant/spilleren' and no he/she. Example for Rasmus: 'En rød ræv med stærke poter. Graver hurtigt og får mere ud af høsten.' For Kløvermynte: 'Lette vinger og blomsterkrans. Kan flyve kort over markerne.' Keep the design notes in docs/ or as CSV comment rows. Add 'figur', 'variant' and 'spilleren' to tools/copy/forbidden_words.json for CHAR_/HERO_ keys.

**Verification.** Confirmed. Several cited line numbers are off: KLOEVERMYNTE is cast.csv:12, BIRK :15, BERTIL :18, BODIL :21. CORE-10: Confirmed against the cited code and data. FIRSTHOUR-10: Confirmed against the cited code and data.

### COPY-06 - Math quest shows its own answers in the tracker and journal; tracker format produces '.:' and '::' (P2, design)

**Evidence**
- lua/quests/math_harvest_puzzle.lua:8-31 - targets 12 / 21 / 8 are the answers to 3×4, 7×3, 4×2 (header comment: 'the objective TARGETS are the answers')
- localization/quests.csv:83-85 OBJ_MATH_HARVEST_PUZZLE_* 'Høst gulerødder: 3 × 4', 'Skaf sten: 7 × 3', 'Skaf sjældne svampe: 4 × 2'
- scripts/ui/hud.gd:221 - label.text = "%s: %d / %d" % [objective_text, current, target] → 'Høst gulerødder: 3 × 4: 0 / 12'
- scripts/ui/components/quest_details.gd:26-27 - journal appends '  (%d / %d)' when target > 1 → 'Skaf sten: 7 × 3  (0 / 21)'
- 24 of 119 OBJ_ texts end in '.' (e.g. localization/ghostfamily_quests.csv:20 'Giv et æble fra Silke til Oak.') → tracker 'Oak.: 0 / 1'; 9 contain ':' (quests.csv:80-88) → double colon
- hud.gd:221 format string is hard-coded, not a localization key

**What's wrong.** The 'Tal-høsten' learning quest asks children to work out 3×4 and so on, but the HUD tracker and the journal print the target count beside the expression, so the answer is always visible. The same hard-coded tracker format also creates punctuation noise for objectives that already contain ':' or end with '.'. Objective punctuation is inconsistent overall.

**Player impact.** The educational point of one of the three math quests is defeated. The HUD reads sloppily ('3 × 4: 0 / 12', '…Oak.: 0 / 1').

**Recommendation.** For quests with meta.tag 'LÆR' (or an objective flag hide_target = true), show only the current count, or '? ' until done, in hud.gd and quest_details.gd. Move the tracker format into a key (QJ_TRACK_FMT '%s · %d/%d'). Strip trailing '.' from OBJ_ rows, or have the tracker trim it, and add a copy_lint rule: OBJ_ texts contain no ':' and no final period.

**Verification.** Confirmed against the cited code and data.

### COPY-07 - 'Hakke' means both hoe and pickaxe: mining prompts name the wrong tool (P2, copy)

**Evidence**
- localization/economy.csv:3 ITEM_HOE_WOODEN 'Hakke' (hotbar slot 1); :5 ITEM_HOE_IRON 'Jernhakke'
- localization/economy.csv:11 ITEM_PICKAXE_WOODEN 'Spidshakke'; :13 ITEM_PICKAXE_COPPER 'Kobberhakke'; :15 ITEM_PICKAXE_IRON 'Jernspidshakke'
- localization/forest.csv:18 FOREST_PROMPT_MINE 'Brug hakken' (EN 'Use the pickaxe'); :20 FOREST_TOOL_PICKAXE 'Vælg din hakke, og slå på stenen.'
- localization/farm_site.csv:48 FARMSITE_MACHINE_PICKUP 'Brug hakke eller økse…' (means pickaxe)
- localization/farm_tutorial.csv:16 TUT_HINT_HOE 'Vælg hakken med %s' (means hoe)

**What's wrong.** The farm tutorial teaches that 'hakken' is the hoe in slot 1. The forest and machine prompts then say 'Brug hakken' / 'Vælg din hakke' when they mean the pickaxe (slot 4, 'Spidshakke'). The upgrade names make it worse: the copper pickaxe is 'Kobberhakke' while 'Jernhakke' is the iron hoe, so 'Kobberhakke → Jernhakke' looks like one upgrade line.

**Player impact.** Children select the hoe for stones and ore, get no result or a 'too weak' whisper, and may buy the wrong upgrade at the smithy.

**Recommendation.** Use 'spidshakke' for every pickaxe reference: FOREST_PROMPT_MINE 'Brug spidshakken', FOREST_TOOL_PICKAXE 'Vælg din spidshakke, og slå på stenen.', FARMSITE_MACHINE_PICKUP 'Brug spidshakke eller økse…', ITEM_PICKAXE_COPPER 'Kobberspidshakke'. Add a glossary row (Hakke = hoe, Spidshakke = pickaxe) to docs/copy/GLOSSARY.md.

**Verification.** Confirmed against the cited code and data.

### HUD-02 - Forest HUD top-centre lane: zone toast hides the 'Etage N' floor banner, and toasts sit under the boss bar over the arena (P3, ux)

**Evidence**
- scripts/ui/forest_hud.gd:98-101 - floor_banner at position (400,120), size 480x80 (Display30 'Etage N' + subtitle)
- scenes/ui/components/toast_stack.tscn:19-25 - toast stack centred at offset_top 96 (each toast is about 66 px tall)
- scripts/autoload/game_manager.gd:448 - NOTIF_ZONE_UNLOCKED 'Nyt område!' is posted on first entry of a zone, the same moment floor_banner.show_floor runs (forest_hud.gd:216-227)
- pass3_dungeon_f1_hud.png - the toast covers y 96-160; only the subtitle 'Mørkeskoven' is visible at y≈170 and the 'Etage 1' title is hidden
- sections/bosses_boss_telegraph_shot.png - two toasts ('Tilbage fra skoven', 'Skovens hjerte vokser … ×3') at y 96-218, directly under the boss bar (y 40-94) and over the fight
- forest_hud.gd:53-56 - boss_box at (428,40) with size 424x54

**What's wrong.** The forest HUD stacks three widgets in the same top-centre band: the boss bar (y 40-94), the toast stack (from y 96) and the floor-arrival banner (y 120-200). On the first entry to a new zone (floor 1, 7 and 10) the zone-unlock toast and the floor banner fire together, and the toast covers 'Etage N'. During boss fights any toast lands between the boss bar and the arena, where telegraphs need to be read.

**Player impact.** The player misses which floor they arrived on, the one moment the banner exists for. During boss fights the notifications block the area where attack telegraphs appear.

**Recommendation.** In the forest HUD, move the toast stack out of the centre: either right-aligned under the loot feed (anchor right, offset_top about 262 + feed height), or bottom-left above the whisper (offset_bottom -110). Alternatively, defer forest toasts while `floor_banner.visible` or `boss_box.visible`. Add a dungeon_hud check that the toast rect does not intersect floor_banner or boss_box.

**Verification.** Partly. The floor-banner overlap is confirmed, but only on the first entry to a zone. The boss-fight half is weak (leftover toasts in a test capture). Downgraded from P2.

### HUD-03 - Whisper box overlaps hotbar slot 1 on the farm/town/home HUD (P3, ux)

**Evidence**
- scenes/ui/components/whisper_line.tscn:23-26 - panel at left 40, bottom -40
- scripts/ui/components/whisper_line.gd:10 - `MAX_WIDTH := 360.0`, so the panel's right edge is x=400
- docs/review/pass3/shots/baseline_compare/v2-regions.json - hotbar region [368, 608, 544, 82], so its left edge is x=368
- pass3_farm_day_hud.png, pass3_traetoppen_city.png, pass3_interior_froebutikken.png - 'Vælg hakken med 1. Brug Venstre klik på marken.' covers the left of slot 1, including its gold selected ring and key digit '1'

**What's wrong.** Any whisper longer than about 330 px wide, which includes most tutorial hints, extends into the hotbar tray. It covers slot 1, which is the selected slot most of the time. The first tutorial hint is the clearest case: it tells the player to press 1 for the hoe while covering the hoe slot and its '1' label.

**Player impact.** Tutorial guidance hides the very control it explains, and the selected-slot ring is obscured on the farm, in towns and at home.

**Recommendation.** Cap the whisper width at 320 px (MAX_WIDTH 320 → right edge 360 < 368), or raise the whisper above the hotbar row on the farm HUD (offset_bottom about -100). Add a hud check that the whisper rect does not intersect %HotbarTray at 1280x720 in both locales.

**Verification.** Partly. The geometry is confirmed. A whisper lasts only 3.5 s. Downgraded from P2.

### HUD-05 - Ability bar shows placeholder words instead of icons; drink count is unreadable (P3, missing-feature)

**Evidence**
- scripts/ui/components/ability_slot.gd:4-7 and :76 - `icon.mode = TTItemIcon.Mode.LABEL  # LABEL until art exists`
- assets/icons/{items,home,wardrobe}/ - no slash/dodge/light/drink images exist (checked with ls)
- pass3_dungeon_f1_hud.png and the zoomed crop - grey 10-11 px mono 'slag', 'undvig', 'fe-lys', 'drik' inside the frames
- scripts/ui/forest_hud.gd:113-117 - drink_count uses Display15Owl (#f2c14e) on the cream frame; in the crop '×1' is honey-on-cream and clipped against the right border
- Style guide section 10 render - the words are the mock's placeholders, in the same style as 'minikort', not final UI

**What's wrong.** The four combat abilities, the main input surface of the forest, have no art. They show the guide mock's placeholder words in tiny low-contrast mono. The drink/tonic stack count is yellow on cream, about 1.5:1 contrast, and touches the frame edge.

**Player impact.** The combat bar looks unfinished. The cooldown veil runs over a word rather than an icon. The player can't read how many tonics are left at a glance during a fight.

**Recommendation.** Paint four ability icons (assets/icons/items/slash.webp, dodge, light, drink; ability_slot already loads them through TTItemIcon when they exist). Render drink_count in ink Display15 on a small chalk or ink badge (like the hotbar's Display15 count), anchored inside the frame with 6 px padding.

**Verification.** Partly. The words are a documented interim. The drink-count contrast (#f2c14e on cream) is the strongest part. Downgraded from P2.

### HUD-08 - Weather reads 'Solskin' (sunshine) at night (P3, copy)

**Evidence**
- localization/core.csv:7 - `UI_WEATHER_KLART,"Solskin","Sunny"`
- scripts/ui/hud.gd:141 - time line = weekday · clock · weather_name
- pass3_farm_night_0040_hud.png - 'Mandag · 00:40 · Solskin' under a night sky; pass3_farm_evening_2030_hud.png - '20:30 · Solskin'

**What's wrong.** The clear-weather id 'klart' is labelled 'Solskin' and is shown at every hour, including 20:00-02:00 when the scene is dark.

**Player impact.** A small but obvious contradiction on the HUD every evening.

**Recommendation.** Rename UI_WEATHER_KLART to 'Klart' / 'Clear'. Alternatively, add UI_WEATHER_KLART_NIGHT 'Stjerneklart' and pick it in TimeManager.weather_name when is_night().

**Verification.** Confirmed against the cited code and data.

### HUD-09 - Tools show a '1' count badge on the hotbar (contrary to item_slot contract and sketch; fails hud.v2_hotbar_compare) (P3, consistency)

**Evidence**
- scripts/ui/components/item_slot.gd:65 - `count_label.text = str(amount) if amount > 0 else ""   # pass 0 for non-stackable tools`
- scripts/ui/hud.gd:166-169 - passes the raw entry amount (1 for tools) and dims only when amount == 0
- baseline_compare/comparison_hotbar.png vs reference_hotbar.png - '1' badges on slots 1-4; the reference has none
- baseline_compare/windowed_baseline_run.log:108-115 - FAIL hud.v2_hotbar_compare mean 12.243 > 12.0

**What's wrong.** Hoe, can, axe, pickaxe, sword and sickle each show a bold '1'. The slot component documents that non-stackable tools should get amount 0. The extra badges are also what pushes the hotbar over its compare limit against the Miljøer v2 crop.

**Player impact.** Visual clutter, and it implies tools can stack or run out. It also keeps a guide-conformance test red.

**Recommendation.** In hud.set_hotbar, pass amount 0 when the item is non-stackable (ItemKinds stack size 1 or kind tool/weapon). Base the 0.45 dim on `stackable and amount == 0` so tools are not dimmed. Re-run hud.v2_hotbar_compare.

**Verification.** Confirmed. The reference crop has no items in those slots, so the badges are a likely but unproven cause of the failing compare.

### HUD-10 - Forest status lines float unplated in honey/owl-eye gold (backpack full, assist) (P3, consistency)

**Evidence**
- scripts/ui/forest_hud.gd:129-132 - backpack_chip and assist_badge are bare Labels ('OwlEye15') placed on the world
- scripts/ui/forest_hud.gd:206-208 - backpack full uses `C.HONEY` (#e8b04a)
- sections/forest_mother_mother_final_account.png - 'Rygsækken er fuld. Gå hjem eller gør plads. 24/24' in gold text over the forest floor
- sections/dungeon_hud_hearts_9_layout.png - 'Hjælp i skoven: Hyggelig' in gold over the hero sprite
- Style guide rules: 'Blæk omkring alt', 'Guld betyder valgt'

**What's wrong.** Two forest HUD states are drawn as plain gold text without a plate or ink outline. One of them is a warning (backpack full). Over light paths or sprites the text loses contrast, and gold is supposed to mean focus or selection.

**Player impact.** The backpack-full warning, which affects loot, is easy to miss and is styled as decoration rather than as a warning.

**Recommendation.** Wrap both labels in `PillNight` chips (as the oil pill is) with chalk text. Give the full-backpack state a rose/thornberry accent icon instead of honey text.

**Verification.** Confirmed against the cited code and data.

### HUD-11 - Zone chip shows 'Skovkanten · 0' on the forest hub (P3, copy)

**Evidence**
- scripts/ui/forest_hud.gd:192 and :251 - `tr(area.map.title)+" · "+str(area.map.depth)` is always appended
- data/maps/moerkeskoven.map header - no @depth line, so scripts/world2d/area_map.gd:31 defaults it to 0
- pass3_moerkeskoven_surface.png - minimap chip 'Skovkanten · 0'

**What's wrong.** The hub is not a floor, but the chip shows depth 0.

**Player impact.** A minor oddity that reads as a debug value.

**Recommendation.** Append ' · N' only when `area.map.depth > 0` (both places in forest_hud.gd).

**Verification.** Confirmed against the cited code and data.

### HUD-12 - Birthday chip on the HUD doesn't say it is a birthday; its glyph is illegible (P3, ux)

**Evidence**
- scripts/ui/social/social_hud.gd:69-73 - chip text is five spaces + NPC name, with a 1-heart TTHearts at 13 px laid over the padding
- sections/social_ui_farm_social_hud.png and pass3_ui_social_hud.png - a pink chip reading only 'Gartner Hoppe' with a garbled leaf-like glyph

**What's wrong.** On a citizen's birthday the HUD shows a pink name chip under the hearts. Nothing in it says 'birthday', and the tiny heart glyph does not read as a cake or gift.

**Player impact.** Players miss birthdays, which are an owner-requested social-sim feature, or mistake the chip for a quest or relationship marker.

**Recommendation.** Use a format key such as REL_HUD_BIRTHDAY_FMT 'Fødselsdag: %s' (en 'Birthday: %s'), or add a cake/gift icon in place of the heart. Keep the +N overflow chip.

**Verification.** Confirmed against the cited code and data.

### HUD-13 - Festival ribbon (y=64) collides with the landmark sub-title on arrival (P3, ux)

**Evidence**
- scripts/ui/social/social_hud.gd:10-11 - `ribbon.position.y = 64`, centred
- scenes/ui/components/area_banner.tscn:120-139 - Body VBox at offset_top 24: Title (AreaTitle, 30 px) + separation 5 + Landmark (22 px), so the Landmark sits at about y 71-97 when both are shown
- pass3_traetoppen_city.png - arrival shows 'Trætoppen' with 'Torvet' at y≈66-90; social_fest_content_honningdagen_gathering.png - the ribbon sits directly under the title at y 64-84

**What's wrong.** When the player arrives in an area on a festival day and spawns on a landmark (Trætoppen → Torvet, where the Trætoppen festivals take place), the landmark line and the festival ribbon occupy the same band. Not captured on screen; inferred from the layout coordinates.

**Player impact.** Two overlapping labels for about 2.5 s on every festival arrival.

**Recommendation.** Hide the ribbon while %AreaBanner's Title or Landmark is visible. Alternatively, place the ribbon below the banner's combined rect (e.g. y = banner.get_combined_minimum_size().y + 30).

**Verification.** Confirmed against the cited code and data.

### HUD-14 - Bed prompt 'Sov' is offered when sleeping is refused (before 18:00) (P3, ux)

**Evidence**
- scripts/home/home_room.gd:318 and scripts/world2d/iso_area.gd:1257 - the bed always gets prompt_key UI_SLEEP
- scripts/world2d/world_2d.gd:669-682 - can_sleep_now() requires hour >= 18; otherwise it only whispers WHISPER_TOO_EARLY
- pass3_home_interior.png - 'E Sov' at 12:00

**What's wrong.** The interaction prompt advertises an action that will be refused for 12 of the 20 waking hours.

**Player impact.** A minor trust issue: pressing E does nothing except show a whisper.

**Recommendation.** Before time.sleep_from_hour, show a variant prompt such as 'Sov (fra 18:00)' (new key UI_SLEEP_LATER), or a dimmed pill state.

**Verification.** Confirmed against the cited code and data.

### HUD-15 - Dive picker copy reads 'god til etage 1–1' (P3, copy)

**Evidence**
- localization/dungeon_run.csv:25 - `DPICK_WEAPON_FMT,Våben: %s (%d) · god til etage %d–%d`
- scripts/dungeon_run/picker_lines.gd:13 - always formats range_of_weapon.x and .y
- sections/dungeon_hud_picker_lines.png - 'Våben: Rustent sværd (5) · god til etage 1–1'

**What's wrong.** When a weapon's recommended range is a single floor, the line prints a degenerate range.

**Player impact.** Reads like a bug in a decision-making screen.

**Recommendation.** Add DPICK_WEAPON_ONE_FMT 'Våben: %s (%d) · god til etage %d' and use it when x == y.

**Verification.** Confirmed against the cited code and data.

### HUD-16 - Loot-feed rows: text is top-aligned in tall rows (P3, ux)

**Evidence**
- scripts/ui/dungeon/loot_feed.gd:24-32 - the words VBox has SIZE_EXPAND_FILL and no vertical centring; the 34 px RaritySlot drives a tall row
- sections/dungeon_hud_hearts_9_layout.png (zoomed) - '+1 Ametyst' hugs the top-right of a roughly 64 px panel with empty space below; the guide's section 10 rows are compact and centred

**What's wrong.** Each loot row is about twice the height of the guide's, and its label sits at the top edge.

**Player impact.** The feed takes about 220 px of the right column for three items and looks unbalanced.

**Recommendation.** Set `words.size_flags_vertical = SIZE_SHRINK_CENTER` and `row.alignment` to centre, and tighten the PanelLoot content margins to match the guide (about 40 px rows).

**Verification.** Confirmed against the cited code and data.

### HUD-17 - UI_NAVIGATION.md HUD spec is stale against the shipped Miljøer v2 HUD (P3, tech-debt)

**Evidence**
- docs/design/UI_NAVIGATION.md:467 - S09 still specifies a Display30 clock, a money pill under the date, a vertical 30x150 Energi meter and 'ten item_slots'
- docs/design/UI_NAVIGATION.md:1200 - Q1 (guide vs sketch HUD) is still listed as open
- scripts/ui/hud.gd:2 '## Miljøer v2 HUD'; tests/sections/hud.gd:19 `eight_slots`, :45 `v2_energy_in_chip`
- docs/design/UI_NAVIGATION.md:553 says the area-name outline_size is 3; scenes/ui/components/area_banner.tscn:83 has `AreaTitle/constants/outline_size = 10`

**What's wrong.** The authoritative UI document describes the superseded guide-06 HUD, and Q1 still appears open, while code and tests implement the sketch. The area-title outline value differs from its spec by more than three times.

**Player impact.** None directly. Future UI work, or a reviewer following the doc, will 'fix' the HUD in the wrong direction.

**Recommendation.** Rewrite S09 to describe the v2 layout (date chip, MoneyChip with a horizontal 110x14 Energi bar, 8 slots, CurrentItemBadge, hearts row, quest card). Close Q1 with the owner's decision. Reconcile S24's outline_size with area_banner.tscn by changing one of the two.

**Verification.** Confirmed against the cited code and data.

### MENUS-11 - Rarity (an owner requirement) is shown inconsistently across panels (P3, consistency)

**Evidence**
- Text rarity name only in the backpack: inventory_ui.gd:135-136 %DetailRarity.
- The shop detail shows only the tile (shop_ui.gd:257-258). The scene defines CatalogRarity_* label styles (shop_ui.tscn:43-52), but the script never sets a rarity label.
- Garderobe _select (garderobe.gd:397-) shows name, description and status, but no rarity.
- Indretning drawer rows (indretning_ui.gd:113-117) and the home chest list rows (home_chest_ui.gd:64-68) have no rarity tile or name at all.

**What's wrong.** Five rarity tiers are central to furniture, clothing and weapons. They appear as a coloured tile plus pips in the shop, gift and garderobe grids, as a named label only in the backpack, and not at all in the furniture drawer and chest lists, even though Indretning filters by rarity.

**Player impact.** Players can't tell what a 'Sjælden' or 'Unik' piece is where it matters most (decorating, wardrobe), and colour-only tiles are hard for colour-blind players.

**Recommendation.** Add the RARITY_* name line, styled CatalogRarity_<r>, to the shop, garderobe and gift details. Use RaritySlot (tile plus pips) in the Indretning and chest rows.

**Verification.** Confirmed against the cited code and data.

### MENUS-12 - Shops open on the rarest (often unaffordable) item with Køb disabled (P3, ux)

**Evidence**
- scripts/ui/shop_ui.gd:186 Rarity.sorted(entries …) rarest first. :207-208 the first entry becomes the selection. :103 initial focus = _rows[0].
- docs/review/pass3/shots/sections/towns_city_seed_shop_panel.png: with 500 gold the seed shop opens on 'Fe-støv til marken 900' (pink price) and Køb is disabled. The starter seeds (Gulerodsfrø 20) sit further down.

**What's wrong.** Because rows sort by rarity first, the first row a new player sees in the seed shop, and the one the stepper and Køb act on, is the 900-gold uncommon fairy dust they cannot afford. The real starter seeds are below it.

**Player impact.** The first shop visit opens on a disabled Køb button and an item the player can't use yet. Young players may think the shop is broken.

**Recommendation.** Put the initial selection and focus on the first affordable, in-stock row (keep the rarity sort for the list). Alternatively, sort seeds by price within the Frø tab.

**Verification.** Confirmed against the cited code and data.

### MENUS-13 - Appraisal, rune picker and forest-help screens are outside the UI audit registry (P3, tech-debt)

**Evidence**
- tests/lib/ui_screens.json and tests/lib/ui_screens.d/*.json list no 'appraisal', 'rune_picker' or 'forest_help' row. All three are TTScreens (scripts/ui/appraisal_ui.gd, rune_picker.gd, dungeon/assist_panel.gd).
- docs/design/DUNGEON_V2_ADDENDUM.md:90 records that these screens 'would … be listed in tests/lib/ui_screens.json'. That was left to the lead and never done.
- scripts/ui/rune_picker.gd:52-58 joins picker_lines text and ignores each row's `warn` flag (picker_lines.gd: no-oil, weak weapon, nearly full backpack), so warnings look like ordinary lines.

**What's wrong.** Three player-facing modals never get the initial-focus, focus-walk, Esc-chain, i18n-flip or ring-pixel checks the other screens get. One visible effect: the rune picker shows its warnings (no lantern oil, weak weapon, full backpack) as plain text, with no emphasis, right before a dive.

**Player impact.** Future regressions in these screens go unnoticed. Today, players can start a dive without noticing the 'no oil' warning.

**Recommendation.** Add registry rows for appraisal, rune_picker and forest_help (with fixtures) to ui_screens.d/. In rune_picker, render warn rows in the THORNBERRY 'RequirementMissing' style.

**Verification.** Confirmed against the cited code and data.

### MENUS-14 - Backpack 'Kassér' discards one item per confirmation (P3, ux)

**Evidence**
- scripts/ui/inventory_ui.gd:193-195 UiConfirm.ask(… STORE_DISCARD_CONFIRM_FMT) then EconomyManager.remove_item(id, 1). There is no quantity choice.
- pass3_ui_inventory.png: the actions are Brug / Udstyr / Hurtigplads / Kassér, with no stepper.

**What's wrong.** Throwing away a stack (e.g. 30 stones to free a slot before a dive) needs 30 separate confirm dialogs. The shop and chest already have 'Alle' and a quantity stepper; the backpack has neither.

**Player impact.** Freeing backpack space, which the 24-slot limit and the backpack-full warnings push players to do, is tedious.

**Recommendation.** Add the shop's QuantityStepper (or a 'Kassér alle' choice) to the discard confirm, or offer 'Læg i kisten' when at home.

**Verification.** Confirmed against the cited code and data.

### COPY-09 - Danish number and plural formatting: decimal points, missing thousands separators, no singular forms (P3, copy)

*Merged:* MENUS-10 (P3, Menus and gameplay panels): Danish copy slips in panels: 'slot' (= castle), decimal points, mixed date formats, ambiguous labels.

**Evidence**
- scripts/ui/components/equipment_details.gd:7 - '%s %d · %s %.1f · %s %.1f' → 'Slag i sekundet 2.5 · Skade i sekundet 30.0' (docs/review/pass3/shots/baseline_compare/shop_ui_equipment_iron_sword_da.png)
- localization/dungeon_items.csv:122,127,139 - '%.1f sek.' → '1.5 sek.'; scripts/ui/forest_hud.gd:244 cooldown '%.1f'
- Same UI uses '.' as thousands separator (HUD '50.500', shop '1.250'), so '2.5' and '30.0' are ambiguous
- scripts/ui/build_menu_ui.gd:112 '%s %d / %d' and localization/home_ui.csv:5 HUSBYG_GOLD_FMT → 'Guldagern 50500 / 500' with no separator (pass3_ui_build_menu.png, pass3_ui_husbyggeri.png)
- scripts/autoload/economy_manager.gd:849 '%s x%d' → toast 'Månesten x2' while the UI elsewhere uses '×'
- No plural support: localization/rel_ui.csv:3 '+%d hjerter' (gift_flow.gd:188, almost always +1), hud.csv:3 'færdig om %d dage', rel_ui.csv:17,25 'om %d dage', animals.csv:7 'Alder %d dage', ui.csv:80 WORKSHOP_MISSING 'Mangler %d %s' → 'Mangler 2 Lysende svamp' (pass3_ui_inventory.png)
- [MENUS-10] localization/da.csv:26 NOTIF_SAVED_MSG 'Dit spil er gemt i slot %d'; menus.csv:8,10 'i slot %d'; da.csv:51 UI_CONFIRM_OVERWRITE 'Overskriv slot %d?'. The save list itself says 'Plads %d' (menus.csv:14). 'Slot' in Danish means castle, and home tier 10 is 'Slottet'.
- [MENUS-10] scripts/ui/components/equipment_details.gd:7 '%.1f' gives 'Slag i sekundet 2.5 · Skade i sekundet 30.0' in Danish (shop_ui_smith_weapon_card_da.png) instead of a decimal comma.
- [MENUS-10] Dates: social/people.gd:196 '5. Forår'; calendar and amenities 'Tirsdag 9. Høstmåned' / 'I morgen, Tirsdag 2. Blomstermåned' (capitalized weekday mid-sentence, home_amenities.csv:6); the HUD shows 'Forår · Dag 1'. STYLE_SHEET.md:105 says dates come from TimeManager.date_text.
- [MENUS-10] rel_ui.csv:11 people tab 'I dag · %d' actually means birthdays today (people.gd:130). rel_ui.csv:16 'Gaver tilbage: 2 / 2' (remaining) vs the gift picker 'Gaver denne uge: 0 / 2' (used) for the same quota.
- [MENUS-10] localization/dungeon_run.csv:25 DPICK_WEAPON_FMT renders 'god til etage 1–1' (dungeon_hud_picker_lines.png).
- [MENUS-10] cheats.csv:10 'guld' vs the currency 'guldagern' (core.csv:6).

**What's wrong.** Numbers are formatted with GDScript defaults, so Danish screens show English decimal points next to Danish thousands points. Requirement lines skip Fmt.thousands. Count strings have no singular form, giving '+1 hjerter', 'om 1 dage' and 'Alder 1 dage'. Recipes join a number with a capitalised singular item name.

**Merged findings add.** MENUS-10 adds that the save toasts and confirm say 'slot' (menus.csv:8,10, da.csv:26), which means 'castle' in Danish, while the save list says 'Plads'. Dates use three formats ('5. Forår', 'Tirsdag 9. Høstmåned', 'Forår · Dag 1'). 'I dag · %d' in People counts birthdays without saying so, and the gift quota reads as 'remaining' in one place and 'used' in another. UI_CONFIRM_OVERWRITE is used only in a fixture.

**Player impact.** Stats are hard to read and look buggy. Frequent toasts such as '+1 hjerter' and 'om 1 dage' are ungrammatical for Danish readers learning to read.

**Recommendation.** Add Fmt.decimal(x, 1), which uses ',' in da, and use it in equipment_details/forest_hud and the WEFFECT/GEMFX rows (pass the pre-formatted string as %s). Route every gold or amount in build_menu_ui/husbyggeri through Fmt.thousands. Add a plural helper that tries KEY_ONE when n == 1 (e.g. REL_GIFT_HEARTS_ONE '+1 hjerte', HUD_CONSTRUCTION_ONE 'færdigt i morgen'). Change WORKSHOP_MISSING to 'Mangler: %s × %d' and the toast to '×'.

**Verification.** Confirmed against the cited code and data. MENUS-10: Partly; UI_CONFIRM_OVERWRITE is only used in a fixture.

### COPY-10 - Danish grammar and spelling errors in shipped rows (lint-invisible) (P3, copy)

*Merged:* CAST-11 (P3, Side quests): Danish copy errors and framing slips in side-quest text; PRIOR-12 (P3, Status of prior review findings): flower_necklace copy still promises 'vilde skovblomster'.

*Prior review (CAST-11):* mechanics-story-deep-dive-2026-10-18 S-K (flower_necklace origin) - still open

*Prior review (PRIOR-12):* mechanics-story-deep-dive-2026-10-18 S-K - still open; the row has not changed since 2491b217.

**Evidence**
- localization/hud.csv:3 HUD_CONSTRUCTION_FMT 'Byggeriet: færdig om %d dage' → 'Byggeriet er færdigt om…' (neuter)
- localization/quests.csv:21 QUEST_MATH_BAKERY_COUNTS_OFFER 'mistet tællingen af mine bagværk' → 'mit bagværk'
- localization/quests.csv:24 and :30 'Til markedsbodden' → 'markedsboden'
- localization/dungeon_items.csv:122 WEFFECT_STUN_CHANCE 'Hvert slag svimler upansrede fjender' → 'får upansrede fjender til at svimle'
- localization/economy.csv:63 ITEM_FAIRY_DUST_WATER_DESC 'Vand ét felt i 3 dage' → 'Vander ét felt i tre dage' (shown in pass3_ui_shop.png)
- localization/da.csv:46 INFO_LOTTERY 'Fe Kongens lotteri' → 'Fekongens' (used by lua/dialogue/mayor_lyra.lua:41)
- localization/home_amenities.csv:6 + scripts/autoload/time_manager.gd:129-131 → 'I morgen, Tirsdag 2. Blomstermåned' (weekday capitalised mid-sentence; pass3_ui_home_amenities.png); EN 'Tuesday 16. Month of Blooms' is not idiomatic
- localization/da.csv:24 'Du har låst op for: %s', :27 'Fået genstand' (translationese), :103 'Dette dyr spiser ikke det!'
- localization/quests.csv:41 QUEST_FLOWER_NECKLACE_DESC still says 'vilde skovblomster' (prior S-K; the item is a generic wild flower)
- [CAST-11] localization/quests.csv:21 QUEST_MATH_BAKERY_COUNTS_OFFER 'mistet tællingen af mine bagværk': bagværk is neuter, should be 'mit bagværk'
- [CAST-11] localization/quests.csv:24,30 'markedsbodden' should be 'markedsboden' (QUEST_MATH_HARVEST_PUZZLE_OFFER, QUEST_ANIMAL_PRODUCTS_OFFER)
- [CAST-11] localization/quests.csv:41 QUEST_FLOWER_NECKLACE_DESC 'vilde skovblomster' (wild_flower is a generic flower_patch yield)
- [CAST-11] localization/ghostfamily_quests.csv OBJ_GHOSTFAM_HITTEGODS_RETURN_* 'Giv et æble fra Silke til Oak' vs QUEST_GHOSTFAM_HITTEGODS_DESC 'Silke har fundet en lille ting … Hjælp den hjem til ejeren' (lost property described as a gift from Silke)
- [CAST-11] localization/dialogue.csv:39 DLG_OAK_GREET '…ikke sikker i aften.' (shown at any hour)
- [PRIOR-12] localization/economy.csv:105 ITEM_WILD_FLOWER_DESC 'En lille blomst fra skovkanten' (and the lua/quests/flower_necklace.lua:2 comment) also place the flower in the forest
- [PRIOR-12] wild_flower comes only from the farm flower_patch node (data/maps/farm.map:59) and the Trætoppen crown caches (lua/config/traetoppen.lua:48); no dungeon or forest floor has a flower node

**What's wrong.** The lints check structure, not language. A handful of visible rows have wrong gender agreement, wrong possessive, misspelled compounds, an intransitive verb used transitively, an imperative where a description is needed, and a split compound in the King's title. Legacy da.csv toasts (gained item, zone unlocked, wrong food) read as literal translations. TimeManager.date_text capitalises the weekday, which is wrong mid-sentence in Danish.

**Merged findings add.** CAST-11 repeats the quests.csv:21/24/30 errors and adds that the hittegods objective calls returned lost property a gift from Silke (ghostfamily_quests.csv:20-24). DLG_OAK_GREET says 'i aften' at any hour. quests.csv:41 'vilde skovblomster' is prior S-K and still open. PRIOR-12 adds that fixing only the quest description is not enough: the item tooltip ITEM_WILD_FLOWER_DESC also sends children to the forest edge. Fix both rows in both languages, or add a flower node to the skovkant floors. See ECON-03 for whether the farm patch spawns at all.

**Player impact.** Visible errors in a game partly aimed at teaching children (math and reading), and in frequent toasts.

**Recommendation.** Apply the corrections listed in the evidence. Use 'Du fik' / 'Nyt sted: %s' / 'Det spiser dyret ikke.'. Give date_text a lowercase-weekday mode for in-sentence use (or a DATE_IN_SENTENCE_FMT key) and use 'Tuesday 16 Month of Blooms' in English. Move the legacy da.csv toasts into the owning CSVs and route them through the AI/native review queue (63 of 66 CSVs are still 'draft', ≈32,600 words; docs/copy/REVIEW_QUEUE.md).

**Verification.** Confirmed against the cited code and data. CAST-11: Confirmed against the cited code and data. PRIOR-12: Confirmed.

### COPY-11 - Name and term inconsistencies: King, Oak/'Eg', mayor's town, 'Mor Silke', item and save terms (P3, consistency)

*Merged:* CAST-09 (P3, Side quests): Name slips: 'Jeg er Eg', 'Jeg er Lilje', and 'Pip' stocking Kløvermynte's shelf; PRIOR-06 (P3, Status of prior review findings): Naming slip only partly fixed: voiced first-meet lines say 'Eg' and 'Lilje'.

*Prior review (CAST-09):* mechanics-story-deep-dive-2026-10-18 S-H - the original instance is fixed; this one is still open

*Prior review (PRIOR-06):* mechanics-story-deep-dive-2026-10-18 S-H - 'Tal med Oak' (dungeon_services.csv:50) was fixed in 02f29ec0; the voiced self-introductions are still open.

**Evidence**
- King: localization/dialogue.csv:25 and quests.csv:6 'Feernes Konge', da.csv:46 'Fe Kongens', elsewhere 'Fekongen' (GLOSSARY fairy_king = Fekongen)
- localization/social_talk.csv:218 SOC_GUARD_OAK_FIRST_1_V 'Jeg er Eg.' (EN 'I am Eg') vs NPC_GUARD_OAK 'Vagten Oak' (core.csv:24); voiced first meeting
- Mayor: lua/config/npcs.lua:45 home_area 'hyggebyen' + dialogue.csv:24 'Velkommen til Hyggebyen!' vs social_talk.csv:2 'Vi finder en plads til dig i Trætoppen' and :21 BIO 'rådhusets vindue… Trætoppen' (Rådhuset is a Trætoppen door anchor, pass3 sections/towns_city_door_raadhuset.png)
- localization/ghostfamily.csv:5 NPC_GHOSTFAM_SILKE 'Mor Silke' while the mother story uses 'mor' for the hero's mother (forest_mother.csv:9 'Mors spor', :70 'Mors sidste ord'); per forest_mother.csv:77 Silke is the mother's sibling
- Potion: economy.csv:115 'Helbredsdrik' vs dungeon_run.csv:28 'Tonika: %d' vs forest.csv ABILITY_DRINK 'drik'
- Save: da.csv:26,51 and menus.csv:8 'slot %d' vs save screen 'Plads 1…6' (pass3_ui_saveload.png); da.csv:28 'Inventar fuldt' vs screen title 'Rygsæk'; da.csv:30 'Ikke nok guld' vs currency 'guldagern' (core.csv:6 UI_GOLD)
- Prior pass-2 S-H fixed only 'Tal med Eg' (dungeon_services.csv:50); the voiced self-introduction still says 'Eg'
- [CAST-09] localization/social_talk.csv:218 SOC_GUARD_OAK_FIRST_1_V 'Jeg er Eg. Jeg passer på broen, mens du finder vej.' (en: 'I am Eg'). The display name is 'Vagten Oak', and he stands at the Skovlift, not a bridge
- [CAST-09] localization/social_talk.csv:210 SOC_FAIRY_LILY_FIRST_1_V 'Jeg er Lilje. …' vs NPC_FAIRY_LILY 'Fe-barnet Lily' (localization/core.csv:22)
- [CAST-09] localization/farm_site.csv:42 FARMSITE_SEED_GREETING 'Pip har fyldt hylden med frø til alle årstider.', but lua/shops/greenhouse_seeds.lua:4 has keeper = "merchant_pip" (Kløvermynte)
- [CAST-09] localization/da.csv:14 SKIN_HOBBIT_PIP 'Pip' (the hobbit hero skin is also called Pip)
- [PRIOR-06] lua/dialogue/_voiced_social.lua:83,101 wire SOC_FAIRY_LILY_FIRST_1_V and SOC_GUARD_OAK_FIRST_1_V as voiced lines; assets/audio/voice/{guard_oak,fairy_lily}/first_1_v.ogg exist
- [PRIOR-06] docs/qa/game-mechanics/fixes/README.md:52 and copy-audit.json freeze protected text and audio hashes

**What's wrong.** The same person, place or thing goes by several names. The King has three spellings. Oak introduces himself as 'Eg' but appears everywhere else as Vagten Oak. The mayor welcomes you to Hyggebyen in one line and to Trætoppen in another. The ghost family title 'Mor Silke' collides with the hero's own 'mor' in the mother storyline (for a ghost hero she is an aunt). The healing potion, save slots, backpack and currency each have two names.

**Merged findings add.** CAST-09 adds that SOC_GUARD_OAK_FIRST_1_V also puts Oak at 'broen', although he guards the Skovlift, and that FARMSITE_SEED_GREETING says 'Pip har fyldt hylden', where Pip is the greenhouse keeper merchant_pip (Kløvermynte). This is the residue of prior S-H. PRIOR-06 adds a constraint on the fix. Both lines are recorded, and their text and audio hashes are frozen (fixes/README.md:52, copy-audit.json). Changing 'Eg' and 'Lilje' therefore needs a re-recording and a manifest update, not just a CSV edit. Do it in the same pass that moves Oak from 'broen' to the Skovlift.

**Player impact.** Children search for the wrong name ('Eg', 'Tonika', 'Inventar') and may be confused about who 'Mor' is in the main story.

**Recommendation.** Normalise to the glossary: 'Fekongen' everywhere; SOC_GUARD_OAK_FIRST_1_V 'Jeg er Oak.' (regenerate its Sara placeholder; DLG_LYRA_GREET_2 is a frozen human recording, so leave it or re-record). Decide the mayor's town and align FIRST/BIO/GREET. Consider 'Silke' or 'Moster Silke' for the display name, at least for ghost heroes. Use 'Helbredsdrik' in DPICK_TONIC_FMT, 'plads' instead of 'slot', 'Rygsækken er fuld', 'Ikke nok guldagern'. Add these terms to GLOSSARY.md and the C1 banned list.

**Verification.** Confirmed against the cited code and data. CAST-09: Confirmed against the cited code and data. PRIOR-06: Confirmed.

### COPY-12 - Key names hard-coded in copy bypass the live-glyph system (wrong on gamepad, will not follow remapping) (P3, accessibility)

**Evidence**
- localization/dungeon_run.csv:64 DTUT_ABILITIES 'Klik: slå. Mellemrum: undvig. Q: fe-lys. R: drik.'
- localization/home_ui.csv:30 INDRET_HINT 'Pile flytter · E placerer · R drejer · X samler op · H lukker.' (pass3_ui_indretning.png)
- localization/farm_site.csv:54 ITEM_PRESERVES_JAR_DESC 'Brug E…', :56 ITEM_KEG_DESC 'Brug E…', :39 FARMSITE_GREENHOUSE_LOCKED '…med B…'
- localization/post.csv:12 POST_HINT '…Skift by med sidetasterne…' (unclear name for PgUp/PgDn)
- project.godot interact = key E + InputEventJoypadButton 0; light = Q + joypad 3: the gamepad is supported
- docs/design/UI_NAVIGATION.md:39 - 'Every interaction prompt string has the key baked in… on a gamepad it lies' (fixed for prompts, not for these rows)
- Mouse glyph mid-sentence: farm_tutorial.csv:16 'Brug %s på marken' → 'Brug Venstre klik på marken' (pass3_farm_day_hud.png)

**What's wrong.** World prompts were fixed to strip baked keys, but tutorial lines, item descriptions and screen help still name keyboard keys literally. On a gamepad, or after any future remapping, they give wrong instructions. Inserting KEY_MOUSE_LEFT 'Venstre klik' mid-sentence also capitalises it.

**Player impact.** Gamepad players are told to press E/Q/R/X/H/B, which do not exist on their device.

**Recommendation.** Convert these rows to %s placeholders filled by UiHints.glyph(action), as TUT_HINT_* already do. Split INDRET_HINT into a HintBar list. Lowercase the mouse names when they appear in a sentence ('venstreklik'/'klik med venstre museknap'). Add a copy_lint rule that flags single capital letters followed by ':' or by 'for at'/'med' in non-NAV rows.

**Verification.** Confirmed against the cited code and data.

### COPY-13 - Calendar uses two vocabularies (season vs month names) and truncates festival names to tooltip-only text (P3, consistency)

**Evidence**
- scripts/ui/theme/tt_format.gd:28 - HUD 'Forår · Dag 1' (UI_SEASON_*)
- scripts/autoload/time_manager.gd:129-131 - date_text 'Tirsdag 9. Høstmåned' (UI_MONTH_*)
- scripts/ui/social/calendar_tab.gd:91-94 heading/chips 'Efterår' vs :123 'I DAG Tirsdag 9. Høstmåned' on the same screen (pass3_ui_calendar.png)
- scripts/ui/social/people.gd:196 birthday chip '5. Forår (om 52 dage)' (pass3_ui_people.png)
- docs/copy/GLOSSARY.md - 'Calendar … words resolve through UI_WEEKDAY, UI_MONTH'
- pass3_ui_calendar.png - day 27 'Månemarkede t…' (word broken across lines), day 14 'Pippins…'; full text only in calendar_tab.gd:119 tooltip_text, which keyboard focus does not show

**What's wrong.** The same 28-day period is called 'Efterår' in the HUD, people and calendar headings, and 'Høstmåned' in the calendar's today panel and the weather forecast. Small calendar cells break festival names mid-word and hide the rest behind a mouse-only tooltip.

**Player impact.** Children must learn two names per season, and 'Høstmåned' sits close to 'Høstfesten'. Keyboard players cannot read truncated calendar entries.

**Recommendation.** Pick one system. Simplest: drop UI_MONTH_* from date_text and use '9. efterår' / 'tirsdag d. 9.', or rename the season chips to the month names everywhere. Make calendar cells wrap on word boundaries (AUTOWRAP_WORD_SMART) or show only an icon plus festival name with an ellipsis, and show the focused cell's full entries in the left 'I dag' panel.

**Verification.** Confirmed against the cited code and data.

### COPY-15 - Mother-story climax exceeds length budgets and reading level; the length lint does not cover FM_/SG_/FEST_ rows (P3, copy)

**Evidence**
- localization/forest_mother.csv:67 FM_E_MOTHER_FATE_TEXT = 259 chars; :71 FM_FINAL_TRUTH = 256 chars (STYLE_SHEET R2: dialogue page ≤ 240)
- scripts/world2d/story/mother_evidence_marker.gd:109 - FM_FINAL_TRUTH is shown as a dialogue page
- tools/copy/copy_lint.py slot_of() - only DLG_/DIALOGUE_/SOC_ keys get the 240-char check, so FM_, SG_, FEST_ and GHOSTFAM rows are unchecked
- Vocabulary: forest_mother.csv:67 'uafsluttede fortællinger', 'beretning', 'ekko, ikke som en levende fange', 'afviste at overtage rollen'; :72 'Rodskriveren … titlen Vejholderen'
- Narrator shift: :67 'Vi gav hende hendes egen underskrift tilbage' (first-person plural) vs :69 'Du planter…' (second person)
- 10 rows use ';' (e.g. :35, :47, :65, :115) - semicolons are hard for young readers

**What's wrong.** The emotional peak of the main story is the densest, most abstract copy in the game, and the longest pages slip past the R2 budget because the lint's slot detection ignores story families. The voice also switches between 'vi' and 'du' inside the evidence journal.

**Player impact.** Young players may not understand what happened to their mother at the payoff moment, which weakens the strongest part of the game.

**Recommendation.** Split FM_E_MOTHER_FATE_TEXT and FM_FINAL_TRUTH into two pages each of ≤ 2 short sentences. Replace the abstract nouns with concrete ones ('Mor hjalp de fortabte hjem. Det kostede hende livet.'). Use 'du' consistently. Replace semicolons with full stops. Extend copy_lint.py slot_of() so any row shown via dialogue_ui (FM_, SG_, FEST_*_OPEN/END, DLG_GHOSTFAM_) gets the dialogue limit.

**Verification.** Confirmed (9 semicolon rows, not 10).

### COPY-16 - English column: inconsistent boss and currency names, Danish word left in English text (P3, copy)

**Evidence**
- localization/forest.csv:9 BOSS_SNURRESVAMPEN 'The Spinning Mushroom' and dungeon_services.csv:47 'Defeat the Spinning Mushroom' vs features_quests.csv:8-42, home.csv:24, furniture.csv:75,130,144, wardrobe.csv:42,170 'Whirling Mushroom'
- localization/farm_site.csv:9 'Buy %s for %d guldagern?', :11 'You are %d guldagern short of %s.', :17 'Yesterday you sold %d guldagern worth.' vs core.csv:6 UI_GOLD 'gold acorns' and home_ui.csv:9 'golden acorns'
- localization/cast.csv:6 English blurb repeats the gendered 'he digs faster'

**What's wrong.** The English locale names the first boss two ways and the currency three ways, one of them the untranslated Danish word, and one sentence is ungrammatical ('sold %d guldagern worth').

**Player impact.** English players (selectable in settings) see an untranslated word and two names for the same boss.

**Recommendation.** Standardise on 'Whirling Mushroom' (forest.csv:9, dungeon_services.csv:47) and 'golden acorns' (core.csv:6, farm_site.csv:9,11,17 → 'Yesterday you sold goods worth %d golden acorns.'). Add EN terms to the GLOSSARY table and a lint rule banning 'guldagern' in the en column.

**Verification.** Confirmed against the cited code and data.

### COPY-17 - Minor accessibility and voice gaps: colour-only requirement state, 9 silent ghost first-meet hooks, voiced lines with digits (P3, accessibility)

**Evidence**
- assets/ui/theme.tres:4424-4429 - RequirementMet green (77,122,42) vs RequirementMissing rose (179,67,107), 14 px, no icon (pass3_ui_husbyggeri.png: 'Fyrretræsplanke 0 / 20' rose, 'Guldagern 50500 / 300' green)
- lua/config/race_reactions.lua:6-14 - nine voice_key paths (voice/<npc>/ghost_first, fairy_king/ghost_intro) have no file under assets/audio/voice/ while the same NPCs' other lines are voiced
- lua/dialogue/baker_maja.lua:51-53 voice_key voice/baker_maja/math_q1 for dialogue.csv:31 'Jeg bagte 35 boller og har solgt 17…' (STYLE R5: voiced lines contain no digits; C3 lint only checks *_V keys)

**What's wrong.** The materials list shows have/need state by colour alone; the numbers are there, but the red-green pair is the main cue and 'have / need' reads ambiguously ('Træ 100 / 20'). Ghost-hero first meetings fall silent among voiced lines. Math lines with digits are voiced by TTS despite R5.

**Player impact.** Colour-vision-deficient players lose the at-a-glance cue. Ghost heroes get an uneven voice experience. TTS placeholder number reading is fragile.

**Recommendation.** Prefix requirement rows with ✓/✗ (or the existing check-circle icon) and write 'Træ: 100 af 20' or 'mangler 20'. Run tools/voice/generate_voice.py --only-index for race_reactions (extend its scanner to the race_reactions table). Extend copy_lint C3 to any CSV row referenced with a voice_key, or drop voice_key from the math question lines.

**Verification.** Confirmed against the cited code and data.


## Story

### Area: Main story spine

The main story is structurally sound and safe to play. Every chapter flag is set by its owner: forest_mother_ready_* by MotherStory.sync and intro_pending by WorldRoot2D. Evidence survives daily re-rolls, can be found out of order, and earlier boss victories count. The bittersweet finale follows all of the owner's hard rules, and much of the Danish is genuinely good. The weak points are at both ends of the story and in a few quest edges. 1) The opening does not establish its premise: the mother is mentioned in one unsigned line after the king's signed letter, Escape skips it, and the mayor's welcome is unreachable because of an intro_done flag clash. 2) The mystery gives away its central "why" in the very first letter. 3) The finale says you restore Mum's name but gives the player nothing to do for it, pays no reward, and almost nobody in town reacts. 4) Two event-bound side quests (rune_vandring, skovlift_intro) can get stuck forever if the runestones were lit before accepting. Pacing: the garden takes about 2 in-game days. Chapters S03 to S08 are limited only by beating the bosses on floors 4, 8 and 12, so a typical player finishes the spine in roughly 2 to 4 game weeks, well before home tier 10 (about day 30 to 60+). After that there is no more story, and the de-facto ending (slotsdroemmen) is a furniture checklist with no link to the mother story.

**Strengths**
- MotherStory (scripts/world2d/story/mother_story.gd) stores evidence as versioned scalar flags with a single atomic finale commit (record(): mother_fate sets own_name_restored, role_refused and seed_tin_homeward together).
- The care tasks are free and retryable, and wrong answers cost nothing: tying the lamp stitches, choosing Iva's name over the role, turning the stone (mother_memory_work.gd).
- The finale honours every hard rule in the addendum: the fate is stated plainly, the echo is not a prisoner, the role is refused, the seed tin comes home, and free play continues afterwards.
- The journal's next-lead system (MotherStory.next_lead plus the FM_LEAD_* rows) always names a concrete floor or person, so the player is never left without a lead.
- The secret garden is a warm, self-contained first beat.
- Hyggebyen inside Trætoppen and the fairy king's lottery are used consistently; no 'Fesby' leftovers remain anywhere in the code or data (rg found none outside old reviews).
- Prior findings S-B/GM-04 (the 'Mød' wording), S-F/GM-08 (the Pip giver), S-H (the 'Eg' typo), GM-10 (early conclusions) and the pre-boss weapon hint (DTUT_WEAPON_WEAK) are confirmed fixed in the current code.

### Area: Side quests, NPC writing, cast consistency

Some of the side content is good. Hoppe's weather and seed-swap dialogue, Sofus's bath, Natteblik's night-gated shop, Pip's tour and Blund's hide-and-seek ladder fit the Figurer v2 sketches, and the ghost family is written with care. The rest of the cast is mostly placeholder. The social lines for all 30 citizens are fill-in-the-blank templates. All 10 heart events use the same choice buttons. The heart-milestone chats were written, but no code ever reads them. Four of the eleven marriage candidates have no dialogue file and no heart events. Lost cat, one of the owner's three example quests, can only be finished on dungeon floor 5, which means beating the floor-4 boss first, and the quest text never says so. Roof repair leaves out Brumme, the carpenter whose whole sketch is about fixing the fairies' roof. Side quests lean hard on 'collect N, talk to the giver', and four of the new Figurer v2 characters give no quests at all. On the cast side, the Birk hero/NPC twin rule is not enforced, so NPC Birk can appear next to a player who picked Birk, with byte-identical idle, hover and talk sprites. The 'Pip' name collisions also remain, and the 'Eg'/'Lilje' name slips are still in the files.

**Strengths**
- Hoppe matches his sketch closely: one seed-for-carrots swap a day and a different weather line for each of klart/regn/taage/sne/torden (lua/dialogue/gardener_hoppe.lua:6-390, localization/dialogue_cast.csv DLG_HOPPE_*).
- The cast-v2 dialogue lines (Sofus, Natteblik, Fru Ugle, Birk, Brumme, Pip in localization/dialogue_cast.csv) are short, warm, kid-safe and give each character a voice: 'Se dampen.
- Blund's hide-and-seek is a complete counted game: two slots per evening, no way to fail, and a 5-tier reward ladder that includes unique and legendary keepsakes with fallbacks for players who already own them (lua/config/ghostfam_seek.lua).
- Heart-event prose itself is gentle and characterful, e.g.
- Quest choices are filtered by QuestManager.is_offerable, and quests a giver can offer are injected automatically, so a thin dialogue file never shows a dead quest button (scripts/world2d/npc_dialogue.gd:49-57).
- Prior finding S-B (boss-road copy said 'meet' but the quest required kills) is fixed.
- Math quests teach real arithmetic in-voice (Maja's subtraction, Zephyr's times tables) and pay off in bogtraeet.
- No leftover 'Fesby' anywhere in lua/, localization/, scripts/ or data/.

### Area: Heart-event scenes and their runner: content, triggers, choices and payoff (10 NPCs, about 4,000 Lua lines, never read)

I traced all 40 heart scenes for the 10 tier-A citizens from start to finish, with no Godot run. Mechanically they are sound. Every 'when' window overlaps that NPC's routine and the shop hours. Every 'stand' mark exists in the interior JSON or in routes.json. The runner stages all effects and commits them in one step, skip included, and tests/sections/social_heart_content.gd plays each scene against the real routines. The weakness is the content. tools/social/content/build_hearts.py emits all 10 files from one hard-coded template: after swapping names and items, the 10 files normalise to the same text (identical md5). Every NPC gets the same 8 choice labels, placed at fixed line indexes, which produces non-sequiturs and a goodbye line spoken mid-scene. The choices change nothing beyond 10 friendship points, and those points are always lost at 10 hearts. Skipping picks the best option, no flag is written, and no later code reads which choice was made. The marriage-style arc has no heart scenes of its own: it rests on 2-line gift reactions, 2 engagement lines and 3 wedding lines that are identical for every candidate, all hard-coded in GDScript. The friendship scenes never react to heartfriend, engaged or married status. There are also smaller discoverability, staging and payoff issues.

**Strengths**
- Runner robustness: effects (points, flags, items, time) are staged and committed atomically with the seen stamp, and skip goes through the same path (event_runner.gd:86-99, 216-243).
- Skip UX is safe and clear.
- All 40 scenes are reachable in data.
- The data is reproducible: build_hearts.py --check is part of the test (social_heart_content.gd:76).
- The Danish copy is warm, short, child-friendly and in du-form.

### Area: Ghost family arc and Blund hide-and-seek against GHOST_FAMILY_ADDENDUM

The ghost family is a real, well-wired subsystem. All four members have routines, an evening shop, midnight stories, the kin scenes for the ghost hero (Pedro/Hviske), all 11 heart scenes plus the welcome evening, the 9 festival attendance lists with 36 greetings, three quests and a counted hide-and-seek. Hide-and-seek can be found, played and won: slots come from the live routine, progress is saved in world flags keyed by game day, and keepsake ownership is guarded with a fallback reward. The weaknesses are in what the player experiences. The heart-ladder chat beats and barks the family's arc depends on are never shown, because the engine never picks a CHAT or BARK line for any citizen. Thursday's hiding clue sends players to the wrong platform. The interaction prompt for a hidden Blund appears beyond the distance that counts a find, so pressing E does nothing. For most dungeon players the 80-find legendary prize becomes a second copy of the 24-find candelabra. Non-ghost heroes are never told the rules or the prizes. The ghost-hero family tie is delivered and matches the mother-story revision (H5). Most remaining story and copy problems are polish: lines that contradict Blund's state, family members naming themselves in the third person, journal locations and scene windows.

**Strengths**
- Hide-and-seek reads the live routine (GhostSeek.slot_now uses NpcDirector.where_is plus a 20 px on-post check, hide_seek.gd:24-34,71-77), not a clock table.
- Progress is saved in JSON-safe world flags with a per-game-day slot mask, so a save at 00:30 keeps the same evening (found_slot uses total_day, hide_seek.gd:35-37).
- Keepsake safety: before a unique or legendary step is paid, claim_rewards checks ownership (count_item or LootService.found), pays the fallback lamp, delivers through LootService.deliver, sets the claimed bit only on success and retries a deferred gift on the …
- The ghost-hero tie is delivered as designed: per-member first-meeting scenes with the hearts and gifts (cream knit shirt, 2 lantern oil), the Natlys-blik 1.5x shimmer radius and its whisper, a 'Bu' heart scene branched on race for the cousin, and the …
- All 11 heart scenes in the addendum (Dyne 4/6/8/10, Gnist 4/8, Silke 4/8, Blund 4/8, plus the kin welcome) exist in lua/events/ghostfam/natlys.lua.
- The Danish family copy is warm, short and child-safe.
- Test coverage is real: tests/sections/ghostfam_seek.gd covers the shimmer radius, the whispers, the find radius, the second slot and the midnight mask.

### Findings (42)

### SPINE-01 - intro_done flag collision: the mayor's welcome scene can never play, and first meeting says 'Good to see you again!' (P2, bug)

*Merged:* FIRSTHOUR-03 (P2, First-hour / first-week playthrough trace): The mayor's welcome is dead code: on first meeting she says 'Godt at se dig igen!'.

*Prior review:* S-L (mechanics-story-deep-dive-2026-10-18) static Lyra dialogue is still open; the flag collision itself is new. Re-verified against current code: still open.

**Evidence**
- scripts/farm/steading/tutorial/tutorial_runner.gd:93 "GameManager.set_flag(&\"intro_done\", true)" at the end of the first morning (default flow, also on Esc-skip)
- lua/dialogue/mayor_lyra.lua:8-9 "local intro_done = context.intro_done ... if not intro_done then" (welcome + lottery branch)
- lua/dialogue/mayor_lyra.lua:46-60 fallback branch DLG_LYRA_HELLO + DLG_LYRA_FARM_STATUS
- localization/dialogue.csv:26 DLG_LYRA_HELLO "Godt at se dig igen!"; :23 DLG_LYRA_FARM_STATUS "Din gård trives! Fortsæt det gode arbejde."
- localization/social_talk.csv:2 SOC_MAYOR_LYRA_FIRST_1_V "Jeg er Hyldeblomst. Vi finder en plads til dig i Trætoppen." (prepended on first meeting by dialogue_bridge.gd:17-19)
- lua/quests/intro_lottery.lua:66 sets intro_done on quest completion (the meaning mayor_lyra.lua expects)
- localization/quests.csv:66-67 OBJ 'Gå over broen til Trætoppen' then 'Tal med borgmester Hyldeblomst' (she lives in Hyggebyen, npcs.lua:45, one bridge further; the objective does not say where)
- [FIRSTHOUR-03] lua/dialogue/mayor_lyra.lua:8-9 `if not context.intro_done` shows DLG_LYRA_GREET_1/2 and DLG_LYRA_LOTTERY ('Velkommen til Hyggebyen! Jeg er borgmester Hyldeblomst… Du har vundet en fortryllet trækronsgård!'); otherwise DLG_LYRA_HELLO + DLG_LYRA_FARM_STATUS
- [FIRSTHOUR-03] scripts/farm/steading/tutorial/tutorial_runner.gd:93 sets intro_done=true at the end of the first morning, before the player can reach the mayor; lua/quests/intro_lottery.lua:66 also sets it, on quest completion
- [FIRSTHOUR-03] scripts/world2d/npc_dialogue.gd:8 context = GameManager.world_flags.duplicate(), so context.intro_done is already true
- [FIRSTHOUR-03] localization/dialogue.csv:26-23 DLG_LYRA_HELLO 'Godt at se dig igen!', DLG_LYRA_FARM_STATUS 'Din gård trives! Fortsæt det gode arbejde.'
- [FIRSTHOUR-03] scripts/social/talk/dialogue_bridge.gd:18-21 prepends the first-meet line social_talk.csv:2 'Jeg er Hyldeblomst. Vi finder en plads til dig i Trætoppen.'

**What's wrong.** intro_done is used for two different things. TutorialRunner sets it as soon as the first morning ends. mayor_lyra.lua uses it to mean 'intro_lottery finished', so it can decide whether to play the welcome and lottery scene. In a normal new game the flag is already true before the player reaches Hyggebyen, so the welcome branch (DLG_LYRA_GREET_1/2, DLG_LYRA_LOTTERY, INFO_LOTTERY) is unreachable. The real first conversation with the mayor, which is also the objective that completes the intro quest, reads: 'Jeg er Hyldeblomst. Vi finder en plads til dig i Trætoppen.' / 'Godt at se dig igen!' / 'Din gård trives! Fortsæt det gode arbejde.' That is on day 1, usually with one seed planted. A ghost hero gets a fourth greeting on top (DLG_GHOST_MAYOR). The intro objective also only says 'Tal med borgmester Hyldeblomst' after sending the player to Trætoppen, while she lives one bridge further in Hyggebyen. Separately, prior S-L is still open: Lyra repeats the same two lines for the rest of the game.

**Merged findings add.** FIRSTHOUR-03 traces the same collision from the first-hour side. For ghost heroes a fourth greeting (DLG_GHOST_MAYOR) is stacked on top.

**Player impact.** The first story NPC the player is sent to meets them with contradictory, canned lines ('I am Hyldeblomst' followed by 'good to see you again'). The intro's payoff ('Velkommen til Trætoppen!') falls flat, and the authored welcome is dead content.

**Recommendation.** Rename the tutorial's flag (for example first_morning_done) in tutorial_runner.gd:22 and :93 and in tests/lib/flow.gd and farm_first_morning.gd. Leave intro_done to intro_lottery.lua:66, or have mayor_lyra.lua read quest_done_intro_lottery instead. Rewrite DLG_LYRA_GREET_2/LOTTERY for a player who already lives on the farm. Give OBJ_INTRO_LOTTERY_TALK_TO_MAYOR a location ('…i Hyggebyen, én bro længere'). Add one or two state-dependent Lyra lines (garden restored, Mum's trail finished) to close S-L.

**Verification.** Confirmed against the cited code and data. FIRSTHOUR-03: Confirmed against the cited code and data.

### SPINE-02 - rune_vandring (and skovlift_intro) get stuck forever if the runestones were lit before accepting (P2, bug)

**Evidence**
- scripts/dungeon/floors/dungeon_floors.gd:220-226 activate_stone(): "if first: EventBus.game_event.emit(&\"dungeon_runestone_activated\",payload)" fires only the first time a stone is lit
- lua/quests/rune_vandring.lua:5-20 rune_5/rune_9 bind to that event with min_level 5/9 and have no completed_flag; :53-55 is_available returns true from day 1 with no forest gate
- lua/quests/skovlift_intro.lua:13-18 light_rune binds to the same first-only event
- lua/config/dungeon.lua:157,205,257,312,362 stones only on floors 3,5,7,9,11 (the hub rune is the picker, moerkeskoven.map:34)
- scripts/autoload/quest_manager.gd:1002-1005 a catch-up path for already-earned achievements exists (completed_flag) but neither quest uses it
- no abandon or cancel action in quest_manager.gd or quest_journal.gd (rg 'abandon' finds nothing)

**What's wrong.** Both quests wait for the event that fires the first time a runestone is lit, and a stone is never lit twice. rune_vandring needs a new first activation on floor 9 or deeper. Stones exist only on floors 9 and 11 at that depth, and the player has to go through floors 9 to 12 for mother chapters S06 to S08 and for the home tier 6 gate (crystal_cave, floors 10 to 12). So anyone who opens Fru Ugle's unprompted quest after reaching floor 11 can never finish it. It stays 'active' in the journal for ever, and since it is not repeatable it cannot be offered again. skovlift_intro ('Første tur ned') has the same fault, but it only triggers if all five stones are lit before the player talks to Oak.

**Player impact.** A permanently unfinishable adventure quest that sits in the journal for good, and its key/gem-bag reward is lost. This undercuts the story's promise that 'En tidligere sejr gælder stadig'.

**Recommendation.** Give these objectives the same catch-up as bossernes_vej: either a state query 'runestone_lit_at_least' that reads DungeonFloors.stones, or a completed_flag backed by per-stone flags such as dungeon_stone_<n> written in activate_stone(). Evaluate it on accept and on load. As a backstop, add a quest-abandon action for non-story quests.

**Verification.** Confirmed against the cited code and data.

### SPINE-03 - The opening does not establish the main premise: the mother line is an unsigned P.S. after the king's signed letter, and Esc skips it (P2, story)

*Merged:* FIRSTHOUR-08 (P3, First-hour / first-week playthrough trace): The opening premise is fragile: a contradictory letter, the mother lead in the King's voice, and Esc permanently drops both; COPY-14 (P3, Danish copy): Opening and world-reference contradictions; player-chosen farm name is never used.

*Prior review:* GM-06 (game-mechanics-2026-10-17) marked fixed; the fix does not yet establish the premise. Re-verified against current code: still open.

*Prior review (FIRSTHOUR-08):* GM-06 (game-mechanics-2026-10-17.md) - partially fixed; still open as described

**Evidence**
- lua/dialogue/fairy_king.lua:9-16 intro page = DLG_KING_LETTER then FM_OPENING_LEAD, both shown under the speaker name 'Fekongen'
- localization/dialogue.csv:21 DLG_KING_LETTER ends "…Kærlig hilsen Fekongen." and says "Følg broen til dit nye hjem" although Pip delivers it at the farm
- localization/forest_mother.csv:115 FM_OPENING_LEAD "Du leder også efter din mor. Du behøver ikke lede alene. Spørg Hoppe om den glemte have nord for torvet…"
- scripts/farm/steading/tutorial/tutorial_runner.gd:50-52,85-95 Esc stops the step loop before the letter, accepts the quests and sets intro_letter_seen, so the letter is never shown
- localization/secret_garden.csv:9 QUEST_SECRET_GARDEN_OFFER (Hoppe) never mentions the mother; :8 the DESC presupposes it: "Mens du leder efter spor efter mor…"
- docs/design/DARK_FOREST_STORY_ADDENDUM.md 'The Fairy King's farm lottery remains genuine… not proof that the king knows'
- tests/sections/ghost_lines.gd:101 still asserts seen == [DLG_KING_LETTER, DLG_GHOST_KING_INTRO]; the intro page now also has FM_OPENING_LEAD, so this exact-list check looks stale
- [FIRSTHOUR-08] localization/dialogue.csv:21 DLG_KING_LETTER '…Følg broen til dit nye hjem…', read on the farm (tutorial_runner.gd:41 requires area 'farm')
- [FIRSTHOUR-08] lua/dialogue/fairy_king.lua:12-14: the second line FM_OPENING_LEAD (forest_mother.csv:115 'Du leder også efter din mor…') has no name_key override, so it shows under 'Fekongen' after the letter's sign-off 'Kærlig hilsen Fekongen'
- [FIRSTHOUR-08] Ghost heroes then also get localization/ghost_dialogue.csv:3 DLG_GHOST_KING_INTRO 'Et spøgelse! Hvor dejligt… Svæv bare ind, kagen står på bordet.', a letter reacting to seeing the reader (intro_sequence.gd:20-22)
- [FIRSTHOUR-08] tutorial_runner.gd:8 and :135-139: Esc, or closing any opening page, skips the whole sequence; :92 sets intro_letter_seen. FM_OPENING_LEAD is used nowhere else (rg finds only fairy_king.lua:14), so there is no reread in the journal
- [FIRSTHOUR-08] tests/sections/farm_first_morning.gd:186 pins escape_skips_whole_sequence
- [COPY-14] localization/farm_tutorial.csv:2 Pip: 'Du må være den nye på Trækronsgården' (the player is already at the farm), then localization/dialogue.csv:21 DLG_KING_LETTER '…Følg broen til dit nye hjem.'
- [COPY-14] localization/quests.csv:132 LUANOTIF_INTRO_LOTTERY_DONE 'Din gård venter i trækronerne.' (shown after the player has farmed)
- [COPY-14] lua/dialogue/fairy_king.lua:13-14 - FM_OPENING_LEAD ('Du leder også efter din mor…', forest_mother.csv:115) is appended to the King's lottery letter, unvoiced after a voiced line
- [COPY-14] scripts/autoload/game_manager.gd:207 farm_name stored, but only scripts/ui/save_load_ui.gd:111 displays it; farm_site.csv:21 FARMSITE_STAGE_UP and farm_tutorial.csv:2 hard-code 'Trækronsgården'
- [COPY-14] localization/ghost_dialogue.csv:6 DLG_GHOST_CAT 'Jeg så dig allerede i går.' (first meeting, can be day 1)

**What's wrong.** The GM-06 fix landed as a single line attached after the king has already signed off ('Kærlig hilsen Fekongen'). It is shown with his name, and it tells the player what they feel ('Du leder også efter din mor') instead of showing a loss. For animal, fairy and hobbit heroes this means the lottery king somehow knows about a private search, and that winning a farm right above the forest where Mum disappeared is pure coincidence. Only ghost heroes get a reason, because Dyne rigged the lottery (ghostfamily.csv:112-113). Pressing Esc during Pip's greeting skips the letter altogether. After that, nothing before the garden says the hero has a missing mother: the Hoppe offer is a neighbourly gardening request, and the journal tab 'Mors spor' assumes the premise. The letter also says 'Følg broen til dit nye hjem' while the player is already standing at that home.

**Merged findings add.** FIRSTHOUR-08 adds that Esc skips the letter (pinned by `farm_first_morning.gd:186`) and that DLG_GHOST_KING_INTRO reacts as if the King can see the reader. COPY-14 adds that `LUANOTIF_INTRO_LOTTERY_DONE_TEXT` says 'Din gård venter i trækronerne' after the player has already farmed (quests.csv:128), that the farm name chosen on select page 2 is never used in-world (FARMSITE_STAGE_UP hard-codes Trækronsgården), and that DLG_GHOST_CAT says 'Jeg så dig allerede i går' at a first meeting.

**Player impact.** The main motivation is easy to miss or reads as a non sequitur. Children who skip or rush the opening meet 'Mors spor' and 'leder efter spor efter mor' with no setup, which weakens every later beat.

**Recommendation.** Move the premise out of the king's letter into a short moment that belongs to the hero: for example a second line from Pip ('Der var også et gammelt brev… din mor?') or a keepsake in the starting backpack (a photo or Mum's seed tin lid). Make it survive Esc by having the skip path whisper it, or by showing FM_OPENING_LEAD as a one-time notification. Change DLG_KING_LETTER to 'Velkommen til dit nye hjem'. Add one line to QUEST_SECRET_GARDEN_OFFER tying the garden to Mum. Update ghost_lines.gd:101 to include FM_OPENING_LEAD.

**Verification.** Confirmed against the cited code and data. FIRSTHOUR-08: Partly; the premises survive in journal text and the Mother tab's empty state. COPY-14: Confirmed against the cited code and data.

### SPINE-04 - The mystery gives away its central 'why' in the first letter, and later chapters repeat it (P2, story)

**Evidence**
- localization/secret_garden.csv:38 SG_SCENE_READ_LETTER (clue 1, day 2): "Jeg satte en lygte ved stien under liften. Så kunne de andre finde hjem."
- localization/forest_mother.csv:39 FM_E_LIFT_RECORD_TEXT (S02 journal): "Hun tog Skovliften ned for at kortlægge en vej hjem for andre." though Oak's spoken line (secret_garden.csv:62) only says "Jeg ved ikke, hvor hun gik hen bagefter"
- forest_mother.csv:43 (S03) "Hun tegnede en vej ud af skoven"; :45 "et kort også skal vise vej for dem, skoven ikke vil slippe"; :51 (S04) "Mor gjorde plads til mennesker, som ikke længere kunne finde deres hjem"; :53 "Mor tegnede udgange"; :63 (S06) "Jeg så mennesker komme ud…"
- docs/design/DARK_FOREST_STORY_ADDENDUM.md chapter table: S01/S02 only establish handwriting and lantern; 'Mother's work was about getting them home' is the S05 discovery

**What's wrong.** The addendum spreads the answers out: S01/S02 tell us who and where, S05 tells us why she went (bringing people home), S06 what she promised, S08 what happened. In the shipped text the 'why' is already in the first garden letter, and it is stated outright in the S02 journal entry, which puts words in Oak's mouth that he never says. From then on, five of the next six chapters each repeat 'she made a way home for others'. Only the role/name idea (S05/S07) and her death (S08) are new. The story has very little build-up in the middle, and the journal claims more certainty than its own 'witness' and 'seen' labels allow.

**Player impact.** From floor 1 to floor 11 the player mostly re-reads one idea. That flattens S03 to S06 and makes the 'Huset der husker' and 'Navne mellem rødderne' discoveries feel like repeats rather than reveals.

**Recommendation.** Make the letter personal and puzzling, for example 'Jeg satte en lygte ved stien under liften. Jeg kommer hjem, når den sidste har fundet vej.' (who is 'den sidste'?). Limit FM_E_LIFT_RECORD_TEXT to what Oak saw ('kort, lygte, opmålingsgrej; hun skrev ingen returtid'). Then give each chapter one new fact: S03 she charted paths no one else could see; S04 she sheltered travellers and who they were; S05 that the wood swaps names for roles; S06 the promise and its cost. Keep the 'routes home' idea as the S05 reveal it was designed to be.

**Verification.** Confirmed against the cited code and data.

### SPINE-05 - The finale promises 'give her her own name back', but the player never acts and never learns the name; the refusal is narrated before the button (P2, story)

*Merged:* PRIOR-09 (P3, Status of prior review findings): FM_FINAL_BARGAIN still narrates the refusal before the player chooses.

*Prior review:* S-I (mechanics-story-deep-dive-2026-10-18) bargain narrates the refusal before the click is still open. Re-verified against current code: still open.

*Prior review (PRIOR-09):* mechanics-story-deep-dive-2026-10-18 S-I - still open; the row was last changed in 8dbd96bc.

**Evidence**
- localization/forest_mother.csv:30 FM_CHAPTER_S08_DESC "…giv hende hendes eget navn tilbage, og bær frøene hjem"
- forest_mother.csv:72 FM_FINAL_BARGAIN already says "Du lægger brevet over titlen og følger mors egen underskrift" before any choice
- scripts/world2d/story/mother_evidence_marker.gd:108-110,139,143 the finale's only choices are FM_REFUSE_ROLE or Farvel
- scripts/world2d/story/mother_story.gd:57-62 own_name_restored is set automatically when the account is recorded
- forest_mother.csv:121-125 (S05) the Iva frame is an actual choice: Iva / Gæsten / Vejholderen
- localization/secret_garden.csv:62 Oak: "Her står hendes navn." The name is never shown anywhere in the copy
- [PRIOR-09] scripts/world2d/story/mother_evidence_marker.gd:108-109 show FM_FINAL_BARGAIN as the last page of the mother_fate lines; :139 then offers FM_REFUSE_ROLE, with REL_TALK_GOODBYE as the only other choice

**What's wrong.** S05 teaches a clear mechanic: the frame names a role, the player picks the person's real name, and the word visibly changes on the frame (_name_label in mother_evidence_marker.gd). The finale is about the same idea, the wood calling Mum 'Vejholderen', but does not reuse it. 'Restoring her own name' is a flag set behind the scenes. The bargain text already describes the refusal before the player clicks (prior S-I, still open). Her name exists in Oak's lift book on day 2, yet the game never tells it to us. So 'giv hende hendes eget navn tilbage' asks for something the player cannot know and cannot do.

**Merged findings add.** PRIOR-09 re-verifies the S-I half (the refusal is narrated before the click) on its own. Nothing since 8dbd96bc has moved the narration after the choice.

**Player impact.** The emotional climax is a one-button confirmation of something already narrated. The best set-up in the story (Iva's frame) gets no payoff at the moment it matters most.

**Recommendation.** Mirror the S05 work at the frame on floor 12. Show 'Vejholderen' on the frame and offer the choices 'Vejholderen' / 'Mor' / '[the name from Oak's record]' (or her signature drawn as a glyph), with the same gentle retry as FM_WORK_NAME_RETRY. Only after the correct pick, swap the label and show FM_REFUSE_ROLE. Move 'Du lægger brevet over titlen…' out of FM_FINAL_BARGAIN so it plays after the click. If Mum's name is meant to stay secret, change S08_DESC to 'giv hende hendes egen underskrift tilbage' and make the signature something the player can see.

**Verification.** Confirmed. The player does click one refusal line. The shipped copy elsewhere uses 'underskrift', which makes S08_DESC's 'navn' inconsistent too. PRIOR-09: Confirmed; the choice is a one-click confirm, not missing altogether.

### SPINE-06 - Weak ending payoff: no reward, no celebration, and the garden's own people never react (P2, design)

**Evidence**
- lua/quests/forest_mother_s03.lua:11 … forest_mother_s08.lua:10 "rewards = {}" on all six chapters
- scripts/ui/quest_journal.gd:99,205-212 the 'Belønning' header always shows; the reward row stays empty for every mother chapter
- scripts/world2d/story/mother_evidence_marker.gd:94-104 the homecoming is three crop_moonflower_3 sprites beside the bench
- scripts/world2d/story/mother_story.gd:31 HELPERS (the only NPCs with FM_AFTER_* lines) = Natteblik, Fru Ugle, Pip, Oak, Dyne, Silke
- lua/dialogue/gardener_hoppe.lua (weather-only branches), lua/dialogue/carpenter_brumme.lua:6,42, lua/dialogue/mayor_lyra.lua:46-60, lua/dialogue/fairy_king.lua have no story-state branches
- rg 'forest_mother|legacy_home|mother_fate' scripts outside world2d/story and ui/story finds nothing: no audio, festival, mail or event reacts; there is no credits or epilogue at all

**What's wrong.** After 8 chapters, 3 bosses and the death of the hero's mother, the ending is a dialogue page on floor 12, a walk home, a 'plant' button and three flower sprites. The chapters give no keepsake. Mum's lantern or seed tin never becomes an item, furniture piece or wearable, even though the pitch is built around rare and unique keepsakes. Hoppe and Brumme, who own and rebuilt the garden where her seeds are planted, never mention it. Neither do the mayor or the fairy king. No music cue, gathering, letter or 'Mors have' sign marks the moment. The journal shows an empty reward header on every chapter.

**Player impact.** The game's emotional climax ends quietly and alone. Children get no lasting token of the story, and the town does not seem to notice.

**Recommendation.** Add a small authored homecoming. On the morning after legacy_home, Hoppe, Brumme, Pip and the Natlys family are at the garden for a one-page scene, plus one line each in their normal dialogue. Give S08 a unique keepsake (for example 'Mors lygte' as a unique/legendary furniture piece or lantern skin, or the seed tin as a placeable). Turn the planted spot into a persistent 'Mors bed' that blooms every season. Play a music sting on forest_mother_evidence id=legacy_home. Hide the journal's reward header when a quest has no rewards.

**Verification.** Confirmed against the cited code and data.

### SPINE-07 - The story and the home/castle progression never meet; the fairy king has no story role and the de-facto ending is a furniture checklist (P2, design)

**Evidence**
- lua/dialogue/fairy_king.lua:9-16 the king's only story line is the opening letter; his other branches are moonstone_crown and slotsdroemmen
- lua/quests/slotsdroemmen.lua:8-41 the final quest = 6 unique/legendary furniture + hygge 5 + feast + talk to the king; QUEST_SLOTSDROEMMEN_DESC (features_quests.csv:12) has no reference to the story
- lua/data/home_tiers.lua:204,282,319,357 the home tier gates are side quests (crystal_cave, snurresvampen, moonstone_crown) plus friendship; none uses forest_mother_* or secret_garden
- scripts/world2d/story/mother_story.gd:22-29 chapters have no day or season gating; they advance only with evidence and bosses on floors 4/8/12

**What's wrong.** The pitch has two big lines: the lottery farm in Trætoppen that grows to a castle, and the forest. They run separately. The mother story can finish within a few game weeks of combat. Home tier 10 and slotsdroemmen need about 74k gold and hygge 4/5 and arrive around day 30 to 60 or later. That leaves a long stretch after the climax with no story at all. The final quest is a furniture checklist set by a king who never acknowledges the hero's search, though his letter mentions it. No home tier or castle beat refers to the garden, the seeds or Mum. With no day gating, a strong player can also burn through the whole emotional arc in the first week.

**Player impact.** The game has two separate endings: a moving one that comes early, and a long tail that ends on 'place 6 treasures'. The lottery premise is never paid off.

**Recommendation.** Tie the two together lightly. Make slotsdroemmen's feast a gathering in Mum's memory, or require the planted 'Mors bed' or mother keepsake as one of the six treasures. Give the king a line after mother_fate that answers the lottery (for example 'Lotteriet vælger ikke tilfældigt, hvem der skal have et hjem…' while keeping it genuine per the addendum). Consider soft pacing: Natteblik or Fru Ugle 'need a night to think' between S05 and S06 and between S07 and S08. Optionally add one home tier perk that only exists after the garden (for example a moonflower bed at the castle).

**Verification.** Partly. The structure is confirmed. The pacing figure is wrong: BALANCE.md models the castle at day 185/345/919 (dedicated/typical/casual), so the stretch after the story is much longer than stated.

### SPINE-08 - Non-ghost heroes still get no special first-meeting reactions or family tie to the story (P2, story)

*Merged:* CORE-08 (P2, Core loop): Race-specific first-meeting reactions exist only for the ghost; FIRSTHOUR-14 (P3, First-hour / first-week playthrough trace): Race-specific first-meet reactions are still ghost-only; PRIOR-04 (P2, Status of prior review findings): Story reactions to the hero's race are still ghost-only.

*Prior review:* S-C (mechanics-story-deep-dive-2026-10-18) still open. Re-verified against current code: still open.

*Prior review (CORE-08):* mechanics-story-deep-dive-2026-10-18 S-C (Race-select story hooks are ghost-only): still open

*Prior review (FIRSTHOUR-14):* S-C (mechanics-story-deep-dive-2026-10-18.md) - still open

*Prior review (PRIOR-04):* mechanics-story-deep-dive-2026-10-18 S-C - still open; no commits touch these files after the cited baseline, and origin/main fc901cf0 does not change them.

**Evidence**
- lua/config/race_reactions.lua:4-15 only a `ghost` table exists (9 NPCs)
- scripts/reactions/race_reactions.gd:14-23 first-meet flag hardcoded as ghost_met_<npc>
- localization/ghostfamily.csv:112-114 ghost heroes alone learn why they won (Dyne entered the name for four springs) and who Mum was
- localization/secret_garden.csv:65 SG_FAMILY_FRIEND / forest_mother.csv:77 FM_FAMILY_FRIEND are the only race-specific story lines for animal/fairy/hobbit
- [CORE-08] lua/config/race_reactions.lua:4-15 the race_reactions table has a single key `ghost` (9 NPC hooks); there are no animal, fairy or hobbit entries
- [CORE-08] localization/cast.csv:3 the heroes are presented as distinct races with their own lore
- [FIRSTHOUR-14] lua/config/race_reactions.lua:4-16 has only a `ghost` table (9 NPCs); scripts/reactions/race_reactions.gd:13 flag ghost_met_<npc>
- [FIRSTHOUR-14] The only other race-aware line is lua/dialogue/beekeeper_birk.lua:6 (fairy), which itself misfires for hero Birk (see the fairy-hero finding)
- [PRIOR-04] scripts/reactions/race_reactions.gd:5 looks up race_reactions.<race>, so animal, fairy and hobbit always get an empty table; scripts/world2d/npc_dialogue.gd:11 passes the race for all four
- [PRIOR-04] none of the 9 ghost voice_keys (e.g. voice/guard_oak/ghost_first, voice/fairy_king/ghost_intro) has a file under assets/audio/voice/

**What's wrong.** Re-checked against current code: animal, fairy and hobbit heroes get no first-meeting reactions and no story explanation for being in Trætoppen. Ghost heroes get a lottery backstory, a grandmother and an aunt. This makes the mother premise feel like it belongs to the ghost (see the opening finding).

**Merged findings add.** CORE-08 and FIRSTHOUR-14 re-verify prior S-C from the mechanics and first-week angles. The one exception is beekeeper_birk.lua:6 (a fairy branch). PRIOR-04 adds that the 9 ghost reactions are the only voice hooks with no recording (see also COPY-17 and GAP-AUDIO-FEEL-06). Either record them or remove their voice_key.

**Player impact.** For 3 of the 4 races, the hero's background and reception are generic, and the main story's reason to start rests on coincidence.

**Recommendation.** Add 2-3 first-meet lines per race to race_reactions.lua and make the flag race-generic (<race>_met_<npc>). Give each race one short line in FM_OPENING_LEAD or Pip's greeting tying Mum to Trætoppen (for example a fox mother who once traded maps with Natteblik).

**Verification.** Confirmed against the cited code and data. CORE-08: Partly; Birk has a fairy branch. FIRSTHOUR-14: Confirmed against the cited code and data. PRIOR-04: Confirmed.

### CAST-01 - Lost cat ('Find Pippins kat', an owner example) needs the floor-4 boss beaten, but is offered on day 1 with no hint (P2, design)

**Evidence**
- lua/config/dungeon.lua:197-220 - Morfar Mis is only placed on floor 5 (n = 5): anchors = { marker='npc', params='id=cat_morfar_mis when=quest:lost_cat', place='nook' }
- lua/config/dungeon.lua:175-179 - floor 4 has boss = "snurresvamp"
- scripts/dungeon/gen/dungeon_verify.gd:142-144 - the stairs down are sealed on every boss floor until the boss-clear flag is set ('hulen_sealed_iff_boss_floor')
- lua/quests/lost_cat.lua:41-45 find_cat = dialogue_started npc=cat_morfar_mis; meta (lines 63-70) has no requires_zone, so Pippin offers it from the first visit to Hyggebyen
- localization/quests.csv:70 OBJ_LOST_CAT_FIND_CAT 'Find Morfar Mis i Mørkeskoven': no floor or band hint
- lua/social/citizens.lua:40 - Mis cannot be befriended until lost_cat is done or day 60
- lua/quests/lost_cat.lua:31-36 ask_neighbours counts any conversation with Maja/Kløvermynte/Lyra/Rosa, but none of their dialogues has a lost_cat branch, so 'asking' gets their normal small talk

**What's wrong.** The style guide's guide quest and the owner's lost-cat example opens in the city with paw prints by the farm bridge. It can only be finished on dungeon floor 5 (Dybe Bregner), which is past the first boss (Snurresvampen, floor 4). The journal says only 'find him in Mørkeskoven' and lists the location as ZONE_CITY. A child who accepts it on day 1 will search floors 1-4 and never find him. The 'ask the neighbours' step also gives no clue, because none of the four neighbours mentions the cat.

**Player impact.** The friendliest early quest becomes the hardest one. A young player spends a day searching shallow floors with no success and is told nothing about why. Morfar Mis also stays unbefriendable for up to 60 days.

**Recommendation.** Move the Mis anchor in lua/config/dungeon.lua from floor 5 to floor 1 or 2 (floor 2's spots, place = 'nook'), keeping mis_hjoerne's loot spot with it, or add requires_zone plus a floor hint to OBJ_LOST_CAT_FIND_CAT ('… i Skovbrynet'). Add a quest_active_lost_cat line to the dialogues of baker_maja, merchant_pip, mayor_lyra and farmer_rosa that points to the bridge ('Jeg så ham ved broen med en sardin!'), so the ask step gives real clues.

**Verification.** Two skeptics, both partly. Every fact is confirmed, but there is no softlock: the quest finishes as soon as the floor-4 boss falls, which the main path requires anyway. The only floor hint is a furniture description. Downgraded from P1.

### CAST-02 - Citizen small talk is fill-in-the-blank templates for all 30 citizens (P2, copy)

*Merged:* COPY-05 (P2, Danish copy): Social copy is mad-lib templated: identical NPC bios, gift reactions, birthday, bark and shop lines across citizens and archetypes; PRIOR-05 (P2, Status of prior review findings): Citizen talk is templated: 25 citizens share the same barks and chat sentence frames.

*Prior review:* game-mechanics-2026-10-17 (writing note: 25 citizens share bark lines) - extended; still open in a broader form. Re-verified against current code: still open.

*Prior review (PRIOR-05):* mechanics-story-deep-dive-2026-10-18 S-L and the game-mechanics-2026-10-17 bark note - still open; the cited evidence was corrected from the unused BARK/CHAT rows to the GREET and TOPIC_ANSWER rows.

**Evidence**
- localization/social_talk.csv:3-21 (Lyra), 22-41 (Maja), 163 (Thorin) - every citizen uses the same frames: GREET_H0 'Godt at se dig. Jeg tænkte netop på <X>.', GREET_H1 'Kom nærmere. Der er altid plads ved <Y>.', GREET_H2 'Jeg har gemt en lille historie om <X> til dig.', GREET_H3 'Du kender vejen til <Y> nu. Jeg er glad for dit selskab.'
- localization/social_talk.csv:21 and every *_BIO_1 - 'Du møder mig ved <Y>. Jeg holder af <X> og af de små samtaler, der gør Trætoppen hjemlig.' This is also used for Hyggebyen residents (Lyra, Maja, Kløvermynte, Thorin), not just Trætoppen ones
- localization/social_talk.csv:13 and every *_TOPIC_ANSWER_* - '<Item> minder mig om noget rart. Det er en af mine yndlingsting.' (word-for-word for every topic of every citizen; lua/social/topics.lua wires them)
- localization/social_arch.csv SOC_ARCH_*_GREET_H0-H3 - 'Kom, der er plads ved <place>.' + 'Det er rart at kende dig' / 'Jeg har savnet dit selskab' / 'Du er altid velkommen her'
- localization/heart_events.csv - each of the 8 heart-event choice labels ('Vis mig det hele.', 'Lad os begynde her.', 'Vi gør det sammen.', 'Vis mig dit trick.', …) is used exactly 10 times, once per heart-event NPC
- scripts/social/talk/dialogue_bridge.gd:16-27 - one of these GREET lines opens every day's first conversation with every befriendable citizen
- [COPY-05] localization/social_talk.csv:21,41,61,81,…,336 - 30 of 34 *_BIO_1 rows follow 'Du møder mig ved X. Jeg holder af Y og af de små samtaler, der gør Trætoppen hjemlig.' (incl. Hyggebyen residents Kløvermynte/Birk/Hyldeblomst and Natteblik, who 'Bor i Mørkeskoven' per cast.csv:25)
- [COPY-05] localization/gifts.csv - 125 rows, 5 distinct Danish texts: all 25 citizens' GIFT_<NPC>_LOVE_1_V = 'Du har fundet noget, jeg holder særligt af. Tak!' (gifts.csv:2…122)
- [COPY-05] localization/birthdays.csv - 20 rows, 2 distinct texts
- [COPY-05] localization/social_arch.csv - per slot across the 8 archetypes: GIFT_* 16 lines → 2 distinct, BDAY 16 → 2, BARK 48 → 6, SHOP 32 → 4 (e.g. :26-35 CHILD = :230-239 ELDER)
- [COPY-05] scripts/social/talk/social_talk.gd:76-78 - gift reaction cascade GIFT_<NPC>_ → SOC_ARCH_<ARCH>_GIFT_ → SOC_ANY_, so every citizen draws from the same 3 lines per taste
- [COPY-05] docs/copy/ARCHETYPES.md:3 - 'These sheets separate the eight social voices'
- [COPY-05] docs/review/pass3/shots/pass3_ui_people.png - Gartner Hoppe's bio shows the template
- [COPY-05] Also odd semantics: SOC_RASMUS_BIO_1 'Du møder mig ved min rygsæk', SOC_POSTMAN_PIP_BIO_1 'ved min posttaske', SOC_ARCH_*_BARK_2 'En nabo går forbi.' (an NPC narrating)
- [PRIOR-05] localization/social_talk.csv: 25x 'Kom nærmere. Der er altid plads ved <sted>' (GREET_H1), 30x 'Godt at se dig. Jeg tænkte netop på…' (H0), 10x 'Jeg har gemt en lille historie om <x> til dig' (H2), 10x 'Du kender vejen til <x> nu…' (H3); only 10 citizens have their own H2/H3 rows, the rest fall back to SOC_ARCH_* in social_arch.csv
- [PRIOR-05] scripts/social/talk/dialogue_bridge.gd:18,22,27 and gift_flow.gd:178 call SocialTalk.pick only with the FIRST, GREET and GIFT_* slots; nothing in scripts/ requests BARK or CHAT_H*

**What's wrong.** The greeting system runs on every NPC's first conversation of each day. All of its text is one sentence template with an NPC-specific noun swapped in. The same goes for biographies in the People book and topic answers. The heart events have personal prose, but all 10 share the same 8 choice buttons. The Mayor of Hyggebyen says 'Vi finder en plads til dig i Trætoppen' and closes with 'gør Trætoppen hjemlig', which mixes up the two towns. The owner wants a full social sim, but citizens speak in one voice. The template shows as soon as a player talks to two or three people.

**Merged findings add.** COPY-05 adds gift and birthday numbers: gifts.csv has 125 rows but only 5 distinct texts, birthdays.csv has 20 rows and 2 texts, and social_arch.csv GIFT/BDAY/BARK/SHOP slots are identical across all 8 archetypes. The per-NPC row always wins the cascade (`social_talk.gd:76-78`), so every citizen gives the same reaction to a gift. PRIOR-05 (prior S-L and the 17 Oct bark note) first cited the 25 identical BARK_1/BARK_2 rows and the 'finder jeg altid en rolig stund' CHAT_H4 frame. Those rows are orphans that the 2D runtime never shows (see SOCIAL-04), so the template the player actually sees is in the GREET and TOPIC_ANSWER rows above. The core cast's hand-written Lua dialogue (baker_maja.lua 268 lines, guard_oak.lua 110) softens the impact a little. fairy_lily.lua still has one greet line, although Lily gives two quests.

**Player impact.** Citizens feel like vending machines. 'Jeg tænkte netop på…' from every NPC every morning breaks the warm, characterful tone that the cast-v2 dialogue shows the team can write. It also undercuts gift hints, because every favourite thing 'reminds me of something nice'.

**Recommendation.** Rewrite SOC_<NPC>_GREET_H0-H3, BIO_1 and TOPIC_ANSWER_* in localization/social_talk.csv in each character's own voice. Start with the 11 marriage candidates (lua/social/citizens.lua partner=true) and the quest givers. Each TOPIC_ANSWER should say why the item matters to that person. Give each NPC's heart events their own choice labels. Fix the town in BIOs for Hyggebyen residents. Consider a lint in tools/loc that flags more than N keys sharing a sentence skeleton.

**Verification.** Two skeptics, both partly. A full scan confirms the templating (GREET_H0 30/30, BIO 30/30, TOPIC_ANSWER 30/30, all 8 choice labels used exactly 10x). 'Mixes up the towns' is refuted: Hyggebyen is a district of Trætoppen (GLOSSARY.md:44). On alternate days the greeting falls back to archetype/shared lines. Downgraded from P1. COPY-05: Confirmed against the cited code and data. PRIOR-05: Partly. The templating stands, but the cited BARK/CHAT rows are orphans, so the evidence was moved to the GREET and TOPIC_ANSWER rows. Kept at P2.

### CAST-06 - Quest-state dialogue locks into permanent 'thank you' lines (Maja), and some givers never change their lines (P2, story)

*Prior review:* mechanics-story-deep-dive-2026-10-18 S-L (most town dialogue is static) - still open, and Maja's branching (cited there as the good example) has this lock-in problem. Re-verified against current code: still open.

**Evidence**
- lua/dialogue/baker_maja.lua:16-37 - once math_bakery_done, every visit returns only DLG_MAJA_MATH_DONE 'Fantastisk! Nu stemmer regnskabet igen. Tak for hjælpen!' for the rest of the game. This branch is checked before the roof branch, so after the maths, Maja's 'help with roof' choice and her roof complaint disappear
- lua/dialogue/baker_maja.lua:181-209 + localization/dialogue.csv:34 - until the roof is fixed she says 'stormen i går beskadigede mit tag!' every day, for weeks
- lua/dialogue/baker_maja.lua:211-247 + dialogue.csv:35 - after the roof, every visit: 'Tak for hjælpen! Taget er som nyt igen.'
- lua/dialogue/fairy_lily.lua:6 - one line 'Hej... vil du lege?' even while you carry her necklace or her sick-friend errand
- lua/dialogue/smith_thorin.lua:12-23 - the same two lines forever, and the mining choice whatever crystal_cave/sword_upgrade state

**What's wrong.** Quest-driven branches have one-shot text that never expires: yesterday's storm lasts indefinitely, and gratitude repeats daily. Maja's branches are also checked in the wrong order: doing her maths first hides the roof storyline from her. Lily, Thorin and the Mayor still give the same line(s) whatever has happened in their quests.

**Player impact.** NPCs seem to have no memory or day-to-day life. The most-visited shopkeeper thanks you for the same sums every morning.

**Recommendation.** In baker_maja.lua, change the stale branches to one-day reactions: show the thanks only on the completion day (store a maja_roof_fixed_day / math_done_day flag and compare it to context.total_day), then fall through to a rotating default. Move the math_done check below the roof check. Change 'i går' to 'stormen' with no date. Add quest_active_/quest_done_ branches to fairy_lily.lua and smith_thorin.lua.

**Verification.** Partly. Maja's lock-in is confirmed. Her quests are still offered through auto-injection (npc_dialogue.gd:55-59), and Thorin's mining choice is filtered by is_offerable, so only lines are lost, not quests.

### CAST-07 - Side quests are mostly fetch-and-return, the owner's roof repair leaves out Brumme, and four new cast members give no quests (P2, design)

**Evidence**
- Objective summary of lua/quests/*.lua: animal_products, birthday_cake, cookie_delivery, crystal_cave, dark_forest_mining, fix_roof, flower_necklace, forest_patrol, ghostfam_garn, ghostfam_lygtemager, moonstone_crown, night_flower, rare_mushroom_hunt, supply_run, sword_upgrade and ugles_noegle are all 'item_gained have=true ×N then talk to giver' (16 of 26 non-spine quests)
- Figurer v2 Brumme card: 'Løfter bjælkerne, når feerne skal have nyt tag'. lua/quests/fix_roof.lua has giver mayor_lyra, an E-press repair at a quest_spot and rewards friendship to baker_maja only; Brumme's only part is the flavour line DLG_BRUMME_ROOF (lua/dialogue/carpenter_brumme.lua:6-20)
- lua/config/npcs.lua - carpenter_brumme, bathkeeper_sofus, mapseller_natteblik and beekeeper_birk have no quests_offered, and no quest names them as giver
- Repeatables replay their story every few days: rare_mushroom_hunt (cooldown 4, 'Lilys lille ven er syg'), cookie_delivery (3, out of carrots again), supply_run (2), flower_necklace (4)

**What's wrong.** The examples that work best (Pip's tour, Blund's hide-and-seek, Hoppe's swap) are social or systemic, but most side quests are 'gather N, hand in'. In the owner's roof-repair example the player gathers wood and moss and presses E on a marker. The bear carpenter whose sketch describes this exact job is not involved. Brumme, Sofus, Natteblik and Birk were added in Figurer v2 but have no side quests. The repeatable errands repeat one-off emergencies (a sick friend, an empty cupboard) indefinitely.

**Player impact.** Fetch fatigue sets in by the second week. The new cast members feel like shopkeepers only. Repeating 'my friend is sick' every 4 days makes the story feel careless.

**Recommendation.** Make fix_roof a two-hander: deliver the goods to Brumme (dialogue_started npc=carpenter_brumme with needs, then he climbs up), give him friendship hearts, and put him in the reward. Give each of Brumme, Sofus, Natteblik and Birk one non-fetch quest: Birk a 'follow the bees' route, Sofus a bath-house invitation round, Natteblik a night map-marking of 3 spots. Reword repeatable OFFER/DESC keys so they suit repetition (QUEST_RARE_MUSHROOM_HUNT_*: Lily collecting glowing mushrooms for her lantern collection rather than medicine).

**Verification.** Confirmed against the cited code and data.

### CAST-08 - A child NPC sends the player to floors 7-9 for medicine, and the errand repeats (P2, story)

*Merged:* PRIOR-10 (P3, Status of prior review findings): A child NPC still sends the player to floor 7 for her mushroom quest.

*Prior review:* mechanics-story-deep-dive-2026-10-18 S-G - still open. Re-verified against current code: still open.

*Prior review (PRIOR-10):* mechanics-story-deep-dive-2026-10-18 S-G and game-review-2026-10-18 S5 (fairy_lily). The M9 offer gate was fixed in fe61de82; the story framing is unchanged.

**Evidence**
- lua/quests/rare_mushroom_hunt.lua meta: giver = "fairy_lily", location = "ZONE_MUSHROOM_GROVE", repeatable = true, cooldown_days = 4
- lua/config/npcs.lua:129-146 fairy_lily role = "child", age = "child"
- localization/quests.csv QUEST_RARE_MUSHROOM_HUNT_OFFER 'Min lille ven har det dårligt! Kan du finde en glødende svamp til hans medicin?'
- [PRIOR-10] lua/quests/rare_mushroom_hunt.lua:47 giver fairy_lily, :49 requires_zone dark_forest; lua/config/dungeon.lua:249,274 put the find_glowing quest_spot on floor 7 (svampelunden), the 7th of 12 floors
- [PRIOR-10] localization/quests.csv:44-45 QUEST_RARE_MUSHROOM_HUNT_DESC/OFFER name only 'Svampelunden', with no adult and no mention of the depth

**What's wrong.** Re-checked against current code: the giver is still the child Lily, the errand is still a deep-floor medicine run, and it now repeats every 4 days.

**Merged findings add.** PRIOR-10 adds that the copy never acknowledges the danger or the depth. To be precise, the glow_mushroom collect objective can be done on floors 1-2; only find_glowing needs floor 7, so the errand is mid-to-deep rather than deep.

**Player impact.** A small child keeps asking the player to go deep into the dark forest because her friend is ill again.

**Recommendation.** Move the quest to an adult giver (beekeeper_birk, or appraiser_fru_ugle who already works with forest finds), or reframe it as Lily's harmless 'lantern-mushroom collection' with a one-time medicine variant.

**Verification.** Confirmed against the cited code and data. PRIOR-10: Confirmed.

### GAP-HEART-EVENTS-01 - All 40 heart scenes come from one template; choices have no real consequences, skipping picks the best option, and 10-heart points are always lost (P2, design)

**Evidence**
- tools/social/content/build_hearts.py:14-19 hard-codes CHOICES per heart level for every NPC: 4 'Vis mig det hele.'/'Lad os begynde her.', 6 'Vi gør det sammen.'/'Vis mig dit trick.', 8 'Jeg bliver lidt endnu.'/'Det tager jeg med mig.', 10 'Her er også plads til dig.'/'Vi mødes igen snart.'
- build_hearts.py:31 asserts exactly 5 or 3 lines per scene; :36 the same when string for all; :38-48 a fixed step list with options {id='stay',points=20},{id='remember',points=10}; :49 always rewards {points=40}
- lua/events/hearts/*.lua: after swapping NPC names, items and marks, all 10 files normalise to the same md5 (c16e1e93…). No scene has a walk, flag, reply_key, time, sfx, clip or a second speaker.
- scripts/social/events/event_runner.gd:65 and :76: on skip the choice defaults to choices[0], which is always the +20 'stay' option, so skipping earns the maximum
- event_runner.gd:108-111: _choice reads only points/flag/reply_key. No code reads the option ids 'stay'/'remember', and no heart scene writes a flag. Nothing else consumes completion either: no quest uses heart_event_finished, and only people.gd:208 shows a count.
- social_manager.gd:276-278 (hearts = floor(p/100), cap 10) and :325-328 (gained = min(delta, cap - before); returns at 0): every _h10 scene requires hearts:<npc>:10, i.e. 1000 points = cap, so its 40 + 20/10 points are always discarded

**What's wrong.** The scenes are 'authored' only at the level of line text. Structure, beat order, choice placement, choice labels, point values and rewards are identical for all 10 citizens and set in the generator. The two options per scene differ only by 10 points. The NPC's next line is the same whichever option is picked, because there is no reply_key. No flag is set and nothing downstream reads the choice. Skipping always applies the better option. At 10 hearts the points are discarded because the player is already at the cap, so the climactic scene's choice has literally zero mechanical or narrative effect.

**Player impact.** Players soon learn that choices do not matter and that skipping is optimal. After two or three citizens the scenes feel interchangeable. The 'full social sim' promise is undercut at its emotional peak.

**Recommendation.** Extend hearts.json so each scene can author its own choices (per-NPC text_key and a reply_key line per option) and an optional flag, e.g. flag='heart_maja_h6_trick'. Have 'build_hearts.py' stop forcing CHOICES, the line counts (:31) and the fixed step list. Read at least some flags back: a later scene step 'when=flag:…', a GREET line variant, or a social_topics entry. Make skip apply a neutral option (add a 'skip_option' or use the lowest-points option) rather than choices[0]. For _h10, replace points with a non-point payoff (see the payoff finding), or let the choice set a flag that a later line or the relationship flow reads.

**Verification.** Confirmed. The scene's gift is still granted at 10 hearts; only the choice and the points have no effect.

### GAP-HEART-EVENTS-03 - The marriage-style arc has no scenes behind it: 2-line reactions, generic engagement and wedding lines, and friendship scenes that ignore heartfriend/engaged/married status (P2, story)

**Evidence**
- scripts/social/relationships/relationship_flow.gd:53: confession lines are bespoke only for Hoppe, Brumme, Maja and Birk. merchant_pip, postman_pip and bathkeeper_sofus fall back to PARTNER_ARCH_* pools shared with tier-B NPCs (wanderer = rasmus, lamplighter_kiki; partner.csv:50-55)
- relationship_flow.gd:53 + localization/partner.csv:33-34: engagement uses PARTNER_ENGAGED_1/2 for every candidate; relationship_flow.gd:121-130 + partner.csv:40-42: the wedding is 3 fixed lines for every spouse
- relationship_flow.gd:70-75, 121-130: the scenes are hard-coded GDScript dictionaries, but docs/design/TOWNS_FARM_SOCIAL_ADDENDUM.md:758 assigns S-marriage scenes to the Lua registry 'lua/events/relationships/**', and lua/events/ has only festivals, ghostfam and hearts
- relationship_flow.gd:126: the wedding step {'act':'face','who':npc,'target':'player'} has its 'target' ignored by event_runner.gd:191-194 (face uses step.dir, default 'S')
- lua/events/hearts/*.lua meta.when has no stage:/flag: term. The hjertebuket unlocks at 8 hearts (lua/social/relationships.lua:4) and engagement at 10 (:5), so the generic friendship _h8/_h10 scenes can still play after the player is a hjertven, fiancé(e) or spouse, e.g. heart_events.csv:85 Maja 'Vi ses, når du har lyst.', :57 Brumme 'Sådan et venskab…', :281 Rosa 'vores venskab' (Rosa is not a candidate, but the same holds for the 7 who are)
- No heart scene mentions or foreshadows the hjertebuket/løfteagern (heart_events.csv has no reference), and there are no dating or post-wedding scenes. The addendum itself lists 'five heart events per citizen' and partner poses as stubs (TOWNS_FARM_SOCIAL_ADDENDUM.md:489)

**What's wrong.** The owner asked for marriage-style relationships. The mechanics exist: tokens, consent, stage rs 1-3, wedding festival, chores. The story backing is minimal. Becoming heartfriends shows two lines, and for three of the seven tier-A candidates those lines are archetype filler shared with background NPCs. Engagement and wedding text is identical for every partner. No scene exists for dating, the proposal or married life. The 40 friendship scenes never check the relationship stage, so a fiancé(e) or spouse can deliver a 'just friends' 10-heart scene. The scenes are also hard-coded in GDScript, against the data-driven-in-Lua rule and the addendum's registry plan.

**Player impact.** Romancing a citizen feels unrewarded and impersonal. The spouse speaks the same vows whoever they are, and the friendship scene text can contradict the relationship the player already has.

**Recommendation.** Create lua/events/relationships/<npc>.lua (registry 'events') for the 7 tier-A candidates: a hjertven scene, gated 'stage:<npc>:hjertven', a proposal scene, a personalised vow line (PARTNER_WEDDING_<NPC>_1), and one spouse scene at home (area 'home' or 'farm'). Have relationship_flow.play_scene and wedding_scene read those definitions (SocialData.event) instead of building dicts inline. Add '&!stage:<npc>:forlovet&!stage:<npc>:gift' to the _h10 scenes, or add 'when'-gated alternative lines for partners. Write bespoke PARTNER_<NPC>_1/2 confession lines for merchant_pip, postman_pip and bathkeeper_sofus. Implement 'face target' in event_runner._directive or drop the key.

**Verification.** Confirmed against the cited code and data.

### GAP-GHOST-FAMILY-ARC-02 - Thursday's hiding clue sends players to the wrong platform (P2, bug)

**Evidence**
- localization/ghostfamily.csv:144 DLG_GHOSTFAM_SILKE_SEEK_3_A 'Blund gemmer sig i køkkenhavens bede. Mellem kålhovederne, tror jeg.'
- lua/config/ghostfam_seek.lua:38 - Thursday slot A post = traetoppen.a_beds2
- data/towns/traetoppen.json:100 - a_beds2 is level 0 = platform 'a' (sx 448, sy 262), Hoppe's hut
- data/traetoppen/traetoppen.json:855 landmark hoppes_hytte on level a; :866 landmark 'koekkenhaverne' on level g, circle [1164,1042,110]; localization/traetoppen.csv:8 TRAE_LANDMARK_7 'Køkkenhaverne' (shown by the area banner, scripts/ui/components/area_banner.gd:42-47)
- docs/design/GHOST_FAMILY_ADDENDUM.md:222 - the design table also calls a_beds2 'the kitchen-garden beds' (the root of the copy error)
- Thursday slot B: localization/ghostfamily.csv:145 'ved postkassen ved skovliften', but the red mailbox prop is at sketch (1255,309.1) (traetoppen.json:701) while post b_mailbox is at (1352,300) (towns/traetoppen.json:132), about 294 ground px away, beyond shimmer_px 260 (ghostfam_seek.lua:23)

**What's wrong.** The game labels platform g, by the farm bridge, as 'Køkkenhaverne'; the area banner shows that name and the planter boxes are there. Silke's Thursday slot-A clue sends the player to the kitchen garden's beds, but Blund actually hides at a_beds2 on platform a (Hoppe's hut), on the opposite side of the city about 1000 sketch px away. No warm whisper fires anywhere near the place the clue names. On the same evening, the slot-B clue names the mailbox, but the post sits beside the Skovlift, about 97 sketch px east of the mailbox prop. A player at the mailbox gets the 'warm' whisper but no shimmer.

**Player impact.** One of the twelve weekly clues is plainly wrong. A player who follows Silke's hint on Thursday evening searches Køkkenhaverne for 2.5 game hours and finds nothing, which undermines trust in every later hint.

**Recommendation.** Either change the copy of DLG_GHOSTFAM_SILKE_SEEK_3_A to the real place ('Blund gemmer sig i bedene ved Hoppes hytte, helt oppe på den øverste platform') or move the Thursday slot A to a g-platform post (keeping the routine and ghostfam_seek.lua slots in sync; the validator slots_equal_routine_hide_blocks will catch drift). For slot B, change the text to 'ved Skovliften, lige ved Oaks vagtpost' or move the post next to the mailbox prop. Fix the GHOST_FAMILY_ADDENDUM.md:222/442 table to match.

**Verification.** Confirmed for slot A (post.csv itself calls a_beds2 'Hoppes bagerste bed'). Slot B is a near-miss, because the clue also names the Skovlift, which is 36 px from the post.

### GAP-GHOST-FAMILY-ARC-03 - Hidden Blund's talk prompt appears outside the find radius, and pressing E then silently does nothing (P2, ux)

**Evidence**
- scripts/world2d/player_body_2d.gd:235-262 - the E query is a circle of interaction_range (45 ground px, lua/config/game_balance.lua:26) centred on the FACING CELL (target_global), not on the player
- scripts/world2d/npc_2d.gd:100-103 - Blund's interact area is an ellipse with reach 60
- scripts/ghostfam/seek/hide_seek.gd:106 - before_talk returns false when the player is more than find_px 72 from Blund
- scripts/world2d/npc_2d.gd:212 - interact() returns with no feedback when the hook returns false
- tests/sections/ghostfam_seek.gd:81-82, 236-238 - tests call seek.before_talk / actor.interact directly at 73/65/55 px; no test exercises nearest_interactable() at 72-200 px
- scripts/world2d/npc_2d.gd:79-86 + scripts/world2d/iso.gd:50 (MASK_WALKING includes LAYER_NPC) - the hidden Blund keeps a solid body; hide_seek.gd:83 only sets alpha 0

**What's wrong.** The player picks an interactable with a 45 px circle about one cell (90-128 ground px) ahead, and Blund's interact ellipse adds 60 px. So the HUD shows 'Tal med Lille Blund' while Blund is roughly 72-195 ground px away. In that band before_talk refuses the find, interact() returns silently, and no 'come closer' whisper appears. Separately, the invisible Blund keeps his 14x8 collision body, so the player bumps into an unseen obstacle at the hiding spot.

**Player impact.** At the climax of the minigame (the 'Psst! Du er lige ved siden af mig!' whisper at 140 px), the prompt appears and E does nothing. Players will think the find is broken or needs something else. Bumping into an invisible object is confusing and gives the hiding spot away. This is inferred from the query geometry, not seen in play.

**Recommendation.** Make the two radii agree. Either disable Blund's InteractArea (_interact.collision_layer = 0) while ghostfam_hiding is true and his ground distance is above find_px, or raise find_px to about 130 and keep the prompt. When before_talk rejects a find, emit a whisper ('Tættere på ... hihi') instead of returning silently. Clear Npc2D._body's collision layer while hiding and restore it in _exit_tree/_refresh. Add a test that moves world.player to 100 px with facing toward Blund and asserts nearest_interactable() and the find result agree.

**Verification.** Confirmed against the cited code and data.

### GAP-GHOST-FAMILY-ARC-04 - The 80-find legendary prize will usually be a second copy of the 24-find candelabra (P2, balance)

**Evidence**
- lua/config/ghostfam_seek.lua:28-30 - step 3 (24 finds) = candelabra_brass; step 5 (80 finds) floor_lamp_fairy with fallback = candelabra_brass; step 4 (48) floor_lamp_glowshroom with fallback table_lamp_brass
- lua/data/loot_tables.lua:846 - snurresvamp boss pool { sofa_cloud, rug_magic_circle, floor_lamp_fairy, shoes_boots_wind }, respawn_days 7, pity_kills 6, floor 4; lua/quests/snurresvampen.lua:17-20 asks the player to defeat it
- lua/data/loot_tables.lua:435 - floor_lamp_glowshroom is a jern-chest wanderer
- docs/design/GHOST_FAMILY_ADDENDUM.md:366 - a typical player reaches 48/80 finds after 12/20 game weeks (14/23 real hours)
- lua/items/furniture.lua:3766-3775 and 3667-3676 - candelabra_brass and table_lamp_brass are rare, 700 buy / 265 sell, max_stack 9; lua/shops/home_shops.lua:82,262 stock candelabra_brass
- localization/ghostfamily_seek.csv:20 SEEK_GHOSTFAM_GIFT_5_OWNED '... Så får du den her i stedet. De kan stå sammen.'

**What's wrong.** The keepsake guard is correct, but the fallback choice undercuts the ladder. The fairy lantern is in a weekly-respawning boss pool of four items with a 6-kill pity timer, on a boss the quest line sends the player to. Any player who visits the dungeon will very likely own it long before 80 finds (about 20 game weeks). For those players the climax of a two-year chase is a shop-buyable rare candelabra they already got at 24 finds. The unique step similarly turns into a 700 g shop lamp. Steps 1-3 are also ordinary shop stock, so the whole ladder never gives anything the player cannot buy.

**Player impact.** The owner wanted hide-and-seek 'with rewards'. For the most engaged players the top prize is anticlimactic and duplicates an earlier one, and the line 'De kan stå sammen' calls attention to it.

**Recommendation.** Use OPEN_QUESTIONS Q5 option (b): make the 48 and 80 steps family-only items whose only fixed source is Blund (for example a 'Blunds natlys' unique lamp and a legendary 'Natlys-lanterne', plus a unique scarf or hat matching the family's coral thread, which also covers the clothing requirement). At minimum, make the step-5 fallback a different item from step 3 (for example chandelier_gold, or a non-shop rare from loot). Consider an exclusive cosmetic at 10 or 24 finds, so the early steps are not plain shop stock.

**Verification.** Confirmed against the cited code and data.

### GAP-GHOST-FAMILY-ARC-05 - Non-ghost heroes are never told the hide-and-seek rules or prizes, and the 'gemmekort' is three text lines (P2, ux)

**Evidence**
- lua/dialogue/ghostfam_blund.lua:20-38 - the rules ('to gange hver aften, undtagen onsdag ... gemmekort ... gaver', localization/ghostfamily.csv:156-157) are only in the ghost cousin's first meeting
- localization/ghostfamily.csv:93 SOC_GHOSTFAM_BLUND_FIRST_1_V - the stranger's first meeting is just 'Hov! Du fandt mig! ... Jeg hedder Blund.'
- scripts/ghostfam/seek/hide_seek.gd:81-84 - while hiding, Blund is alpha 0 and his bubble is hidden, so he is not visible during either slot (18:00-23:30)
- scripts/ghostfam/seek/hide_seek.gd:161-168 - card_page = title + '%d fund' + 'Næste gave om %d fund'; no ladder, no prize names, no rarities, no claimed state (pass3 shot docs/review/pass3/shots/sections/ghostfam_seek_progress_card.png shows only '3 fund')
- rg 'gemmeleg|gemmekort' localization/ - outside the ghostfamily files only POST_HIDING 'Gemmer sig i byen' (post.csv:78) and ACT_HIDE

**What's wrong.** Six of the eight heroes (fox, fairy, hobbit looks) get no introduction to the counted game. There is no quest, letter or journal entry, and Blund's stranger meeting does not mention the card or prizes. Blund is invisible exactly when the game runs, so a non-ghost player only learns of it by stumbling on the shimmer, asking Silke 'Hvor gemmer Blund sig?' or reading Pip's post list. Once found, the 'Blunds gemmekort' choice opens a dialogue page with a count and the distance to the next gift. It does not show the five rarity steps or what each pays, so the main motivation of a counted game is never shown.

**Player impact.** An owner-required feature is effectively hidden from most players. Those who find it have no visible goal ladder to chase.

**Recommendation.** Give non-ghost players a one-time intro. Either add a stranger version of KIN_1_2/1_3 to Blund's found branch the first time (flag ghostfam_seek_intro), or have Silke's first evening greeting mention the game. Make the card a real panel, or at least list the ladder: one line per step with the rarity name from lua/config/rarity.lua and the item name, plus a check mark for claimed bits, using SEEK_GHOSTFAM_CARD_* keys. Add a journal 'Blunds gemmeleg' entry once the player knows the rules.

**Verification.** Partly. The core is confirmed. Some cues for non-ghost heroes exist: the People bio ('gemmer sig to nye steder hver aften'), the card choice on every talk, and 'Næste gave om N fund'.

### SPINE-09 - Bosses have three different story framings and are never named in the mother story; snurresvampen does not count earlier victories (P3, consistency)

**Evidence**
- localization/forest_mother.csv:31-33 FM_OBJ_CHECKPOINT_S0x "Åbn det første/andet/sidste dybdepunkt"; :99-101 FM_LEAD_CHECKPOINT_* "Gå gennem dybdepunktet… En tidligere sejr gælder stadig."
- localization/dungeon_services.csv:43-49 bossernes_vej: "skovens tre svampevogtere", Overvind Snurresvampen/Glødesvampen/Svampekongen
- localization/features_quests.csv:9-10 snurresvampen: "Larmen fra Dybe Bregner… få Snurresvampen til at holde op"
- lua/quests/snurresvampen.lua:16-21 defeat_snurresvampen has no completed_flag (bossernes_vej.lua:11,19,27 has one)
- lua/quests/snurresvampen.lua:46 / home_tiers.lua:282 snurresvampen gates home tier 8

**What's wrong.** The same three fights are called 'depth checkpoints' in the main story, 'guardians' in Oak's road quest, and 'a racket to stop' in the tier 8 gate. The mother story never says that a 'dybdepunkt' is a boss. Its climax is fighting Svampekongen, who has no connection to the Root Scribe or to Mum, and the story's word for him is vague. Also, bossernes_vej and the mother chapters count earlier victories, but snurresvampen (home tier 8 gate, offered only after the first forest visit) does not. A player who already beat the floor-4 boss for S03 has to beat it again.

**Player impact.** Children may not understand what 'Åbn det første dybdepunkt' asks for, and the hardest fights carry no story weight. Being made to repeat a boss for tier 8 contradicts 'En tidligere sejr gælder stadig'.

**Recommendation.** Name the boss in the checkpoint text ('Overvind Snurresvampen, som vogter dybdepunktet på etage 4'). Add a one-line story hook on the Svampekongen kill (for example the crown's rune shard opening Rodskriverens ramme, which fits ITEM_DNG_RUNE_KONGE_HINT). Add completed_flag = "dungeon_boss_snurresvamp" to snurresvampen.lua's defeat objective.

**Verification.** Confirmed against the cited code and data.

### SPINE-10 - Small contradictions in clue text: where the letter is, what Pip said, wick vs stitches, lygte vs lampe (P3, copy)

**Evidence**
- localization/secret_garden.csv:34 SG_SCENE_SEE_BLOSSOMS letter lies "Mellem bladene"; :36 OBJ "Læs brevet i frøkassen"; forest_mother.csv:35 FM_E_LETTER_WATERMARK_TEXT "i havens frøkurv" (title 'Brevet i frøkurven')
- secret_garden.csv:60 Pip: "Frøkassen kom op med Skovliften, men brevet må være ældre" vs forest_mother.csv:37 FM_E_POST_ROUTE_TEXT "Brevet kom gennem skovposten"
- forest_mother.csv:117 FM_WORK_LAMP "Bind hvert sting… så lampen kan lyse" vs :47 FM_E_MEMORY_LAMP_TEXT "Du retter vægen og lukker glasset"
- forest_mother.csv:41 FM_E_GARDEN_TRAIL_TEXT "Sporet ved frøkassen" uses 'frøkassen' for the Skovkanten box too

**What's wrong.** The same letter is found in three places (among the leaves, in the seed box, in the seed basket). The journal summary of Pip's account says the opposite of what Pip actually said. The S04 lamp task has the player tie stitches, but the recorded memory describes straightening a wick and closing the glass. Within one chapter 'lampe' and 'lygte' are mixed. 'Frøkassen' means both the garden box and the forest-edge box.

**Player impact.** Small trust breaks in a clue-reading game, where children compare journal entries with what they did.

**Recommendation.** Settle on 'frøkassen' (garden) and 'kassen ved Skovkanten' (forest). Rename FM_E_LETTER_WATERMARK to '…i havens frøkasse'. Rewrite FM_E_POST_ROUTE_TEXT to match Pip ('Kassen kom op med liften; brevet er ældre end turen'). Make FM_E_MEMORY_LAMP_TEXT start with 'Du binder de tre sting…'. Use 'lygte' throughout.

**Verification.** Partly. The letter-location and lamp contradictions are confirmed. Pip's line versus FM_E_POST_ROUTE_TEXT is an embellishment, not 'the opposite'.

### SPINE-11 - Lore wording: 'mennesker' in a world with no humans; ghost-specific line shown to every race; 'Mor Silke' clashes with 'Mors spor' (P3, copy)

**Evidence**
- localization/forest_mother.csv:51,53,63,67,125 'menneske(r)' 5 times; rg finds the word in no other localization file
- forest_mother.csv:71 FM_FINAL_TRUTH "Heller ikke Natlys-familiens spøgelser kan hente hende tilbage" shown to every race (mother_evidence_marker.gd:108-110)
- localization/ghostfamily.csv:5 NPC_GHOSTFAM_SILKE "Mor Silke"; docs/copy/GLOSSARY.md:39; forest_mother.csv:2,9 FM_NAME/FM_TAB "Mors spor"; FM_FAMILY_KIN :76 "Din mor var … Silkes søskende"

**What's wrong.** The cast is foxes, fairies, hobbits and ghosts, but the main story alone talks about 'mennesker' (Mum's motto 'Et menneske er mere end den rolle…'). The finale's ghost-specific reassurance also appears for a fox hero, whose mother has nothing to do with the Natlys ghosts. Silke's name tag 'Mor Silke' ('Mum Silke') appears in dialogue next to a tab called 'Mors spor'. For a ghost hero, Silke is the aunt, which is confusing.

**Player impact.** Small immersion breaks, and real confusion for young readers about which 'Mor' is meant.

**Recommendation.** Use 'nogen', 'folk' or 'væsner' ('Man er mere end den rolle, nogen giver én'). Show the Natlys sentence only when character_type == GHOST, or reword it for everyone ('Ingen magi kan hente hende tilbage'). Rename Silke's tag to 'Silke' or 'Natvagten Silke' in ghostfamily.csv and the GLOSSARY.

**Verification.** Confirmed against the cited code and data.

### SPINE-12 - The fairy king's first in-person meeting skips the welcome and asks a question that cannot be accepted (P3, ux)

**Evidence**
- lua/dialogue/fairy_king.lua:89-115 when moonstone_crown is not done, the page is QUEST_MOONSTONE_CROWN_OFFER with a quest_accept choice
- lua/quests/moonstone_crown.lua:39 requires_zone = "dark_forest"
- scripts/world2d/npc_dialogue.gd:52 non-offerable quest_accept choices are removed
- localization/features_quests.csv:7 "Åh, kære hjælper! Min krone mangler sin månesten. Vil du lede efter en i Mørkeskoven?"

**What's wrong.** The king who drew the hero's name never welcomes them in person. Before the first forest visit, his conversation is the moonstone request ('Vil du lede efter en…?'), and the only button left is 'Farvel', because the accept choice is filtered out. He calls the hero 'kære hjælper' before they have helped with anything.

**Player impact.** The figure behind the whole premise is a puzzling dead end at first meeting.

**Recommendation.** Add a first-meet or pre-forest branch to fairy_king.lua ('Så er det dig, der vandt! Hvordan trives gården?'), and only show moon_offer when context.quest_offer_moonstone_crown is true, the same way guard_oak.lua handles its offers.

**Verification.** Partly. The unanswerable question is confirmed. The King does greet the hero at the first meeting (SOC_FAIRY_KING_FIRST_1_V is prepended), and gift/topic choices can appear next to 'Farvel'.

### SPINE-13 - Two 'garden' quests confuse the main beat; enchanted_garden's flag is still never read (P3, consistency)

*Prior review:* M9 enchanted_garden_unlocked unread (game-review-2026-10-18) still open. Re-verified against current code: still open.

**Evidence**
- localization/quests.csv:34-36 QUEST_ENCHANTED_GARDEN 'Den fortryllede have… kan vækkes med de rette frø' (mayor Lyra)
- localization/secret_garden.csv:2,7-9 'Den hemmelige have' (Hoppe), also woken with moonflower-like seeds ('små månelyse blomster')
- lua/quests/enchanted_garden.lua:66 sets enchanted_garden_unlocked; rg finds no reader

**What's wrong.** Lyra's repeatable 'Den fortryllede have' (buy 3 moonflower seeds and plant them on your own farm) uses almost the same premise and imagery as the main-story 'Den hemmelige have'. Both can be in the journal at once. The quest's flag is still never read, as prior M9 noted.

**Player impact.** Players may think they are already doing the garden beat, or wonder which garden 'wakes'.

**Recommendation.** Rename and reframe enchanted_garden as an on-farm task ('Månebedet på gården') so it says it happens on the farm, or turn it into a post-story echo set in Mum's garden. Delete or use enchanted_garden_unlocked.

**Verification.** Confirmed against the cited code and data.

### SPINE-14 - The draft story docs still disagree with the shipped titles and keys (P3, tech-debt)

*Merged:* PRIOR-11 (P3, Status of prior review findings): Story design docs still disagree with the shipped chapter keys and titles.

*Prior review:* S-D and S-E (mechanics-story-deep-dive-2026-10-18) still open. Re-verified against current code: still open.

*Prior review (PRIOR-11):* mechanics-story-deep-dive-2026-10-18 S-D and S-E - still open; the design pack was last changed in 8dbd96bc.

**Evidence**
- docs/design/dark-forest-story/copy.csv:20,23 'Bag det sidste lys' / 'Hvad der skete med mor' vs localization/forest_mother.csv:27,29 'Hinsides det sidste lys' / 'Det vi bærer hjem'
- docs/design/dark-forest-story/chapters.json:47-49,70-72 S01/S02 copy_keys point at QUEST_FOREST_MOTHER_S01/02_* which exist only in the draft copy.csv
- [PRIOR-11] docs/design/dark-forest-story/copy.csv:3-4 the S01 draft sends the player to 'Postbud Pip', while the runtime FM_OPENING_LEAD (localization/forest_mother.csv:115) sends them to Hoppe and the garden
- [PRIOR-11] docs/design/DARK_FOREST_STORY_ADDENDUM.md:93 claims 'The runtime rows now use these draft targets' (false); docs/design/GHOST_FAMILY_HANDOFFS.md:55 still points writers to copy.csv as the current direction

**What's wrong.** Re-checked: the draft copy and chapters.json still name keys and titles that differ from what ships. Writers working from the docs will edit the wrong rows.

**Merged findings add.** PRIOR-11 adds that GM-06 made the drift worse, because the draft S01 lead now contradicts the shipped opening lead, and that two other docs tell writers the draft is current. Only the Danish S07 title differs; the English 'Beyond the last light' matches. Mark the addendum line and the handoff pointer as superseded together with copy.csv.

**Player impact.** None directly; it makes later story edits more likely to go wrong.

**Recommendation.** Mark copy.csv as superseded, or sync it to the FM_* keys. Point the S01/S02 copy_keys in chapters.json at QUEST_SECRET_GARDEN_*.

**Verification.** Confirmed against the cited code and data. PRIOR-11: Confirmed.

### PRIOR-08 - The Root Scribe still has no staged scene, and S04 carries most of the forest chapters' story evidence (P3, design)

*Prior review:* mechanics-story-deep-dive-2026-10-18 S-A and S-J; game-mechanics-2026-10-17 GM-05; game-review-2026-10-18 S5 (Root Scribe). Re-verified against current code: partly fixed, still open as design polish.

**Evidence**
- scripts/world2d/story/mother_story.gd:15,20 traveller_account and mother_fate both use the root_scribe_waymarker art with an echo halo (mother_evidence_marker.gd ECHO_IDS)
- docs/qa/game-mechanics/fixes/README.md:26 'a fully staged house/Root Scribe scene … remain design polish'
- lua/quests/forest_mother_s04.lua:7-11 five evidence objectives; forest_mother_s05.lua and forest_mother_s07.lua have one evidence objective plus a checkpoint each
- scripts/world2d/story/mother_story.gd:26,28,85 the S05 and S07 checkpoints are boss-victory gates (boss_floor 8 and 12)
- mother_evidence_marker.gd _name_label: the GM-05 name-frame activity on traveller_account (S05); mother_fate has the seed-tin keepsake prop

**What's wrong.** GM-05 added the lamp stitches, the name frame and the route stone. The Root Scribe, the story's central figure, is still a waymarker with a halo plus text, and nothing in its clearing changes around the player. S04 has five memories to find, while S05 and S07 each have one piece of evidence. Those two chapters are not short in play: each also needs a boss victory (Glødesvampen on floor 8, then the floor-12 king), and S05 has the name-frame activity. The imbalance is in story evidence, not in play time.

**Player impact.** The climax reads more than it plays, and the middle chapters tell the player less about Mum than S04 does.

**Recommendation.** Stage one clearing for S05 or S08 with the existing props (roots closing round the frame, the empty chair). Move one S04 memory into S05 or S07, or add a name-board object to S05.

**Verification.** Partly. The objective counts and the missing staged scene are confirmed. 'S05 and S07 are thin' is overstated, because each carries a boss fight and S05 has the name-frame activity. Kept at P3 as design polish.

### CAST-10 - Cast collisions: three 'Pip's, two postmen, and a mouse with the halflings' surname (P3, consistency)

**Evidence**
- lua/config/npcs.lua - merchant_pip (shown as Kløvermynte), postman_pip (hedgehog Pip), pippin_boegeknop (mouse Pippin), penguin_postman (role postman, one line in lua/dialogue/penguin_postman.lua)
- lua/dialogue/merchant_pip.lua:15 voice_key = "voice/pip/greet" - DUNGEON_V2_ADDENDUM says Pip's path is voice/postman_pip/, 'never voice/pip/'
- localization/core.csv:27 'Pippin Bøgeknop' (mouse, no family field) vs core.csv:42-43 'Bertil/Bodil Bøgeknop' (family = "boegeknop", halflings in Figurer v2)
- lua/quests/lost_cat.lua:2 comment calls Mis 'Pippin Boegeknop's grandfather', while Figurer v2 says 'Pippins gamle kat'

**What's wrong.** Figurer v2 has one Pip (the hedgehog postman, quest giver) and the Bøgeknop halfling siblings. The data still carries the pre-v2 merchant_pip id, which leaks into voice paths and copy. It also has a second postman (the penguin) with almost no lines, and a mouse called Pippin Bøgeknop. He shares the halfling family's surname without being related to them (family exclusion and dialogue never link them).

**Player impact.** Confusion over who delivers the mail and who is related to whom. The Bøgeknop siblings could even be told apart from Pippin by the marriage-exclusion rule only by accident.

**Recommendation.** Rename the mouse's surname (e.g. 'Pippin Knapnål'), or add family = "boegeknop" plus one line acknowledging the link. Retire penguin_postman as a citizen (keep him as an ambient courier with friendship = false), or give him a distinct job. Fix the merchant_pip voice_key to voice/merchant_pip/greet. Correct the lost_cat.lua header to say Mis is Pippin's cat.

**Verification.** Confirmed against the cited code and data.

### GAP-HEART-EVENTS-02 - Choices placed by line index break sentences in two and put a goodbye mid-scene (Lyra, Rosa, Brumme, Sofus, Thorin, Hoppe) (P3, copy)

**Evidence**
- build_hearts.py:39: choice_at = 3 for 4/8 hearts and 1 for 6/10 hearts, regardless of content
- localization/heart_events.csv:277-280 Rosa 10: 'De små husker ikke altid, hvem der gjorde hvad.' → player 'Vi mødes igen snart.' → 'Men de husker, hvordan det føltes…' (the 'Men…' continuation is cut by the player's goodbye)
- heart_events.csv:53/56 Brumme 10: 'En god samling skal kunne give sig lidt.' → choice → 'Så holder den…'; :193/196 Sofus 10: '…fortjene en pause.' → choice → 'Og du behøver ikke…'
- heart_events.csv:137-140 Lyra 10: 'Når vi står her, behøver jeg ikke være borgmester hele tiden.' → player 'Her er også plads til dig.' (said to the mayor in her own square) → '…Hyldeblomst, der er glad for dit besøg.'
- heart_events.csv:229/232 Thorin 4: 'En hammer kan larme meget uden at gøre noget godt.' → 'Vis mig det hele.' / 'Lad os begynde her.' → 'Jeg prøver at huske forskellen. Du hjælper mig med det.' (non-sequitur); :5/8 Hoppe 4: '…brug for ro.' → 'Vis mig det hele.' → 'Du har også givet dig tid til at slå rødder her.'

**What's wrong.** The shared choice labels were written without seeing the NPC lines, and they are inserted at a fixed index. In all ten 10-heart scenes the player can say 'Vi mødes igen snart.' (a farewell) after line 1. The NPC then carries on talking and hands over a gift. In four of those scenes, line 2 continues line 1's sentence ('Men…', 'Og…', 'Så…'), so the player's line interrupts it. Several 4-heart scenes answer 'Vis mig det hele.' with a line that responds to something else.

**Player impact.** The dialogue reads as stitched together exactly at the emotional climax of each friendship, so the Danish writing comes across as machine-assembled.

**Recommendation.** Author choices per scene in hearts.json and let the author pick the insertion point (e.g. 'choice_after': 2). As a minimum, move the 10-heart choice to after line 2 and replace 'Vi mødes igen snart.' with a reply that fits a mid-scene beat. Re-review the four 'Vis mig det hele.' scenes (Thorin, Hoppe, Birk, Sofus 4). Add reply_key lines so each option gets its own NPC response.

**Verification.** Partly. The mechanism is confirmed. Only three 10-heart scenes split a sentence (Rosa, Brumme, Sofus); Birk's 4-heart scene is a further example. Downgraded from P2.

### GAP-HEART-EVENTS-04 - Pending heart scenes cannot be discovered: scene titles are never shown and the People book's 'Klar til en snak' count is almost always 0 (P3, ux)

**Evidence**
- lua/events/hearts/*.lua meta.title_key (e.g. mayor_lyra.lua:12) and 40 HEART_*_TITLE rows in heart_events.csv: no script reads meta.title_key (searched scripts/social, scripts/ui/social, scripts/ui/social_events; event_overlay.gd shows only SOC_EV_SKIP_HINT)
- social_manager.gd:1133 people_rows → events_ready(id), which requires world.area == meta.area (:1146-1149), hour:8-18 and at:<npc> (NPC live in the player's current area)
- scripts/ui/social/people.gd:208 + localization/rel_ui.csv:20 'Oplevet: %d · Klar til en snak: %d'
- No player-facing copy or docs/PLAYING.md text explains where or when scenes trigger (searched localization for 'på hjerte'/'øjeblik': only REL_TALK_EVENT and SOC_EV_*)

**What's wrong.** The only cue for a ready scene is the rose ♥ bubble, visible when the player is already in the right area at the right time with the NPC on screen. The People book's 'Klar til en snak' count runs the same strict check, so opened from the farm or anywhere else it reports 0 even when the next scene only needs the player to walk into the bakery. The 40 hand-written scene titles ('Ovnen vågner', 'Et navn mellem venner'…) are dead strings: no title card, no memories list.

**Player impact.** Players who rarely visit a given shop, area or time of day can miss scenes indefinitely without knowing they exist. The People book gives a misleading 'ready: 0'.

**Recommendation.** In people_rows, add an 'events_next' field that evaluates only hearts, after, once and cooldown (no area, at: or hour terms), and show it as 'Næste øjeblik: <tr(title_key)> · <area name>'. Show tr(meta.title_key) in the event overlay's top cinematic bar when a heart scene starts, and list seen titles in the People detail panel as memories.

**Verification.** Confirmed against the cited code and data.

### GAP-HEART-EVENTS-05 - Staging: the player is never placed in the scene, and outdoor scenes teleport the NPC to a fixed mark far away on another platform level (P3, ux)

**Evidence**
- build_hearts.py:38: the only positioning step is {'act':'stand','who':npc,'mark':author.mark,'facing':'S'}; no scene places or faces the player
- data/towns/routes.json ground distances: Brumme's weekend post t_stall (level 3) → c_logs (level 2) = 1838; Hoppe t_fire_n/t_fire_s (level 3) → a_bench (level 0) = 3050/3405; u_terrace (level 4) → a_bench = 1934; Birk blossom_bench2 → bees1 = 962
- lua/routines/core/carpenter_brumme.lua stall plan (weekday 5,6): t_stall 9.5-16, the widest window for his traetoppen scene, so the most likely trigger point is 1.8k units and one level away from c_logs
- tests/sections/social_heart_content.gd:123 hand-places the player next to Hoppe ('world.player.global_position = actor.global_position+Vector2(110,55)') before the native capture, because the runner does not
- event_runner.gd:189-194: stand/face use a fixed 'S' facing, not the player's position

**What's wrong.** In interiors this works, because the player is at the talk cell in front of the counter and the NPC is put on the 'counter' post facing S. Outdoors, the NPC fades out where the player talked to him and reappears at a fixed mark, possibly on another tree-platform level. The camera follows the NPC, so two-person beats ('Vil du holde enden, mens jeg måler?') probably play with the player out of shot. This is inferred from the distances; I could not run the game to check the framing.

**Player impact.** Scenes outdoors will likely feel like disembodied cutaways rather than shared moments. It is jarring when an NPC appears to vanish from a busy market stall.

**Recommendation.** Add a player 'stand' to the template at a per-NPC 'player_mark' authored in hearts.json, or teach the runner a 'stand who=player near=<npc>' that uses _clear_stage. For outdoor citizens, use a mark on the same level as the NPC's current post: e.g. use t_stall for Brumme on weekends, or stage his scene in int_brummes_vaerksted. Make 'face' accept 'target':'player'.

**Verification.** Confirmed from code. The framing claim is an inference, and the finding says so.

### GAP-HEART-EVENTS-06 - Narrow or weather-blocked windows for some outdoor scenes (Brumme weekdays, Birk and Lyra in rain) (P3, design)

**Evidence**
- lua/events/hearts/carpenter_brumme.lua:11/14 area='traetoppen', when 'hour:8-18&…&at:carpenter_brumme'; lua/routines/core/carpenter_brumme.lua work/inn plans: in int_brummes_vaerksted 7.75-16, then traetoppen.c_bench until 17.25/17.5, so on Monday-Friday only about 16:00-17:15 (not in his workshop, where players meet him)
- scripts/towns/routines.gd:284-293 + :24 RAIN_ACTS=['sit','tend','play','fish']: in regn/torden, outdoor sit/tend blocks with t0 in 8-19 move to the shelter. A block without 'from' counts as t0=12.
- beekeeper_birk.lua honey plan (weekday 1,2,3,5): every outdoor block has no 'from' and act tend/sit, so in rain Birk spends the whole day at home.table (int_birks_bistade) and his hyggebyen scene is unreachable
- mayor_lyra.lua work plan (weekday 1,2,3): torv_fountain_n 'sit' has no 'from', so in rain she shelters and her hyggebyen scene is unavailable; on rest days only the 16-18.5 'well' stand remains
- lua/config/game_balance.lua:95-97: rain probability 25% in spring, 16% + 12% thunder in summer, 35% in autumn; social_heart_content.gd:94 forces weather 'klart' when staging, so the tests never exercise this

**What's wrong.** All 40 scenes are reachable, and the test proves it with clear weather. On weekdays, Brumme's scene needs the player in Trætoppen during a 75-minute evening slot, even though he spends the day in his own workshop interior. Birk's and Lyra's scenes disappear on rainy days for 3-4 weekdays a week. Nothing tells the player this (see the discoverability finding). This is not a blocker, but it adds to the 'hidden scene' problem.

**Player impact.** Brumme, Birk and Lyra fans can go days without a ♥ bubble and with no hint why.

**Recommendation.** Allow a second staging area per NPC: let meta.area accept a list, e.g. Brumme {'traetoppen','int_brummes_vaerksted'} with a 'counter' mark, and Birk/Lyra their shelter interiors int_birks_bistade/int_hyldeblomsts_hus. Alternatively, drop 'area' and stage the scene at the NPC's current post. Add a rainy-day case to social_heart_content.gd.

**Verification.** Partly. Birk is worse than stated: in rain his scene is unreachable on 5 of 7 days. Lyra keeps a 16-18 'well' window on rest days.

### GAP-HEART-EVENTS-07 - Heart-scene payoff is token-level and uneven (3 stone or 2 rope at 10 hearts); 8 of the 10 tier-A citizens give no friendship item at any level (P3, balance)

**Evidence**
- lua/events/hearts/smith_thorin.lua:381-382 _h10 gives stone x3 (lua/items/resources.lua:24 sell 1); carpenter_brumme.lua:381-382 rope x2 (sell 2); mayor_lyra.lua:381-382 wild_flower x2 (sell 2); postman_pip.lua:381-382 apple x2 (sell 5)
- By contrast gardener_hoppe.lua and merchant_pip.lua _h10 give moonflower (crops.lua:87 sell 180), and bathkeeper_sofus.lua honey_cake (sell 90)
- tests/sections/social_heart_content.gd:41 asserts that heart-scene gifts are 'normal' or 'uncommon' rarity, a deliberate cap
- lua/data/loot_tables.lua:812-819 friend gifts: only farmer_rosa (4 hearts) and baker_maja (5 hearts) among the 10 tier-A citizens have a heart-gated item

**What's wrong.** The rarity cap is intentional (the addendum caps items at normal), but the gifts themselves read as random pantry items. Value varies up to 60x between NPCs at the same milestone. Thorin's best-friend gift (3 stone) is the same item he already hands out as his everyday 'sample' (citizens.lua: sample=stone). For 8 of the 10 citizens, nothing else in the game marks reaching 10 hearts: no furniture, clothing or recipe, even though the owner's pitch is built around collectible rarity-tier furniture and clothing.

**Player impact.** Maxing a friendship feels anticlimactic, and some citizens look stingy next to others.

**Recommendation.** Keep the scene gifts small, but give the _h10 scene (or a loot_tables.lua gifts row at hearts=10) a personal keepsake for each tier-A citizen, e.g. a signature furniture or clothing piece in 'uncommon'/'rare' granted through LootService.check_friend_gifts, which allows keepsakes. Even out the in-scene gifts to a similar value band. Thorin's _h10 could give iron_ore or a smithing recipe instead of stone.

**Verification.** Confirmed against the cited code and data.

### GAP-HEART-EVENTS-08 - Repetitive motifs and no ties to the wider cast or world in the Danish copy; Lyra's 'name' scene reveals her public surname (P3, story)

**Evidence**
- heart_events.csv 8-heart titles: Brumme 'Honningpausen' (:44), Maja 'En dråbe honning' (:72), Sofus 'En skefuld ro' (honey, :184), Birk 'Det første glas' (:212), and Lyra's 8-heart scene is about a honningkage. That is 5 of the 10 eight-heart scenes built around honey.
- Across the 280 rows: 'plads' appears 23 times, 'sammen' 17 and 'pause' 12. The 6-heart beat is the same 'help me make room / do it together' everywhere (Maja 6_01, Pip 6_01, Sofus 6_01, Birk 6_01 'gøre plads…')
- tools/social/content/hearts.json: per-NPC keys are only area, mark and scenes{title,lines,gift}. No line mentions another citizen, family member, quest or place: Birk and Kløvermynte (merchant_pip) are siblings per the Figurer v2 cast sheet and lua/config/npcs.lua family notes, and Lyra is Lily's mother (family 'hyldeblomst'), but none of this is referenced
- heart_events.csv:136/140 Lyra 10 'Et navn mellem venner' → 'Jeg kan bare være Hyldeblomst…', but localization/core.csv:19 NPC_MAYOR_LYRA is already 'Borgmester Hyldeblomst' and 'Lyra' appears in no Danish string, so the 'name between friends' gives the player nothing new

**What's wrong.** Taken one at a time the scenes are pleasant. Read as a set they reuse the same themes (honey, a pause, making room, sharing) and never reference the town, the fairy king's lottery, Mørkeskoven, the help quests (roof, lost cat, cookies) or relatives. Lyra's 10-heart scene is set up as a reveal and reveals nothing.

**Player impact.** The social world feels flat. Citizens seem not to know each other, and the payoff lines blur together across NPCs.

**Recommendation.** Give each tier-A citizen one scene that ties into the world: Birk/Kløvermynte sibling banter (perhaps a shared scene with a second speaker; the runner already supports per-step 'who'), Lyra and Lily, Maja and the cookie quest, Brumme and the roof repair. Change Lyra 10_02 to 'Sig bare Lyra.' so the first name is actually revealed. Rewrite at least three of the honey 8-heart scenes around each NPC's own craft.

**Verification.** Confirmed against the cited code and data.

### GAP-GHOST-FAMILY-ARC-06 - Blund's lines contradict what he is doing (says 'you found me' when not hiding) (P3, copy)

**Evidence**
- lua/dialogue/ghostfam_blund.lua:195-204 - the default non-ghost line is DLG_GHOSTFAM_BLUND_GREET_1 = 'Du fandt mig! Jeg har et nyt sted hver aften, og du er den første, der ser det.' (localization/ghostfamily.csv:23)
- localization/ghostfamily.csv:94 SOC_GHOSTFAM_BLUND_GREET_H0_1 'Jeg gemmer mig! Kig ikke. ...' is prepended by DialogueBridge.decorate (dialogue_bridge.gd:20-23)
- lua/routines/ghostfam/ghostfam_blund.lua:14,17,72-77 - Blund is plainly visible walking 17:05-18:00, on f_bench 23:30-24:00 and on f_porch all day on festival days
- lua/dialogue/ghostfam_blund.lua:46-80 - every gift branch opens with SEEK_GHOSTFAM_FOUND_1 'Åh nej, du fandt mig! Hvordan vidste du det?'
- scripts/ghostfam/seek/hide_seek.gd:108-110 - a deferred gift is also paid on an ordinary non-find talk (before_talk else branch) and reaches those same branches

**What's wrong.** When Blund is not hiding, a non-ghost player talking to him sees 'Jeg gemmer mig! Kig ikke' followed by 'Du fandt mig!', while he stands openly on the bench or the porch, including all day on festival days when Silke says he is at the party. When a gift was deferred because storage was full and is then paid at the bench, Blund also says 'Åh nej, du fandt mig! Hvordan vidste du det?'. The FOUND_2 and FOUND_3 variants are also skipped whenever a gift is paid.

**Player impact.** Small but repeated incoherence in the child character, and it muddles whether the player actually found him.

**Recommendation.** In ghostfam_blund.lua add a non-hiding greeting (e.g. 'Hej! Jeg gemmer mig først, når mørket kommer. Find mig i aften!') and keep GREET_1 for found contexts. Make gift branches use the found line only when found_now > 0 and otherwise a 'Her, jeg har gemt den til dig' line. Add a SOC_GHOSTFAM_BLUND_GREET_H0_DAG/MORGEN variant so the prepended greeting does not claim he is hiding.

**Verification.** Confirmed against the cited code and data.

### GAP-GHOST-FAMILY-ARC-07 - Family members talk about themselves in the third person in the mother and garden topics (P3, copy)

**Evidence**
- scripts/world2d/story/mother_story.gd:118-120 - for npc ghostfam_dyne/ghostfam_silke the page is {speaker: npc, lines: [FM_FAMILY_KIN|FM_FAMILY_FRIEND]}
- localization/forest_mother.csv:77 FM_FAMILY_KIN 'Dyne og Silke holder en plads til dig. Din mor var Dynes yngste og Silkes søskende.' - spoken BY Dyne or Silke
- localization/forest_mother.csv:78 FM_FAMILY_FRIEND 'Natlys-familien lader et lys brænde ... De er dine venner' - a narrator voice in a family member's speech bubble
- scripts/world2d/story/secret_garden_story.gd:68-71 + localization/secret_garden.csv:64 SG_FAMILY_KIN 'Din mor er Dynes yngste og Silkes søskende. ... Men vi holder en lygte tændt' (third and first person mixed)
- localization/ghostfamily.csv:46 SOC_GHOSTFAM_DYNE_TOPIC_ANSWER_2 ('Fortæl om din familie') lists only Gnist, Silke and Blund - for the cousin Dyne never mentions her youngest or the hero

**What's wrong.** The shared story-topic rows were written as narration but are shown as dialogue with Dyne or Silke named as speaker. So Dyne says 'Din mor var Dynes yngste' and Silke says 'Dyne og Silke holder en plads til dig'. Dyne's own family topic, when asked by her grandchild, describes the family without the hero or the hero's mother, even though she named that mother in the first meeting.

**Player impact.** At the emotional heart of the ghost hero's story, grandmother and aunt sound like a narrator reading a file. This breaks the family voice right where it matters most.

**Recommendation.** Split the rows per speaker: FM_FAMILY_KIN_GHOSTFAM_DYNE ('Din mor var min yngste. Vi holder en plads til dig ...') and FM_FAMILY_KIN_GHOSTFAM_SILKE ('Din mor var min søskende ...'), and the same for SG_ and FRIEND (first-person 'Vi er dine venner'). Select them in mother_story.gd:118 and secret_garden_story.gd:69 by npc. Add a ghost-race variant of SOC_GHOSTFAM_DYNE_TOPIC_ANSWER_2 that names 'min yngste, din mor' and 'og nu dig'.

**Verification.** Confirmed against the cited code and data.

### GAP-GHOST-FAMILY-ARC-08 - Two scenes promise interactions that never happen: Dyne's unanswered colour question and a write-only 'natlys_seat' (P3, story)

**Evidence**
- localization/ghostfamily_events.csv:3 GF_EVENT_GHOSTFAM_DYNE_H4_1 'Jeg har gemt en plads i mønstret. Hvilken farve skal den have?'
- lua/events/ghostfam/natlys.lua:15-62 - Dyne h4 steps are camera/face/say/emote/say only; no 'choice' step although the runner supports it (scripts/social/events/event_runner.gd:5,62-79)
- lua/events/ghostfam/natlys.lua:253 and :722 - Dyne h10 and the kin welcome set flag natlys_seat
- rg 'natlys_seat' lua/ scripts/ - no reader besides the two events' own 'when' gates
- docs/design/GHOST_FAMILY_ADDENDUM.md:134 - the cousin privilege (4) 'the Wednesday fire has a seat for the hero'

**What's wrong.** Dyne asks the player to choose a colour, then carries on without asking for an answer. The 'seat at the fire' earned at 10 hearts (or by the cousin at the welcome evening) is stored but never referenced again. No Wednesday greeting, no seat marker at t_fire_e and no line from Dyne acknowledges it.

**Player impact.** The scenes that end the family's arc have no follow-through, so the 'you belong here' payoff is spoken once and then forgotten.

**Recommendation.** Add a 'choice' step to ev_ghostfam_dyne_h4 with three colours (and optionally store the choice in a flag Dyne later mentions). Read natlys_seat in ghostfam_dyne.lua for Wednesday 19-23, e.g. 'Din plads er varm. Sæt dig.', and/or in Blund's family line (localization/ghostfamily.csv:162).

**Verification.** Confirmed against the cited code and data.

### GAP-GHOST-FAMILY-ARC-09 - Family quests show 'Hyggebyen' as location and a generic hand-in objective (P3, consistency)

**Evidence**
- lua/quests/ghostfam_garn.lua:36, lua/quests/ghostfam_lygtemager.lua:43, lua/quests/ghostfam_hittegods.lua:17 - location = "ZONE_CITY"
- localization/core.csv:51 ZONE_CITY = 'Hyggebyen'; core.csv:50 ZONE_TRAETOPPEN exists and is used by 5 other quests (e.g. lua/quests/pips_runde.lua:49)
- lua/buildings/ghostfam.lua:11 - the family's home and shop are in area traetoppen; Dyne's fire t_fire_e and Gnist's counter are Trætoppen posts
- localization/ghostfamily_quests.csv:7 and :14 OBJ_..._RETURN 'Tag tingene med tilbage.' - does not say to whom or where

**What's wrong.** All three family quests tell the journal they take place in Hyggebyen, while every giver and hand-in point is in Trætoppen. The hand-in objective for the wool and the lantern ingredients does not name Dyne or Gnist.

**Player impact.** The journal sends players to the wrong town to hand in, and the final step reads like a placeholder.

**Recommendation.** Set location = "ZONE_TRAETOPPEN" in the three quest files (or in tools/social/content/build_family_quests.py, which generates them). Change OBJ_GHOSTFAM_GARN_RETURN to 'Giv ulden til Dyne ved bålet på Torvet.' and OBJ_GHOSTFAM_LYGTEMAGER_RETURN to 'Giv svampene og natblomsten til Gnist i Lygtehuset.'

**Verification.** Confirmed against the cited code and data.

### GAP-GHOST-FAMILY-ARC-10 - Silke's 4-heart and Gnist's 8-heart scenes open only for about 15 real seconds a day (P3, design)

**Evidence**
- lua/events/ghostfam/natlys.lua:405 - Silke h4 when = 'hour:20.1-20.65&...' = 33 game minutes = 16.5 real seconds (2 game min/s)
- lua/routines/ghostfam/ghostfam_silke.lua:20-22 - Silke is in Hyggebyen from 20:05 until her round ends (~22:00), so the window is far narrower than her presence
- lua/events/ghostfam/natlys.lua:347 - Gnist h8 when = 'hour:24.5-25' = 30 game minutes = 15 real seconds, overlapping the closing whisper
- scripts/social/social_manager.gd:960-962 - the hour window is checked at talk time; the heart bubble appears only inside it

**What's wrong.** Silke's 'Runden' requires talking to her in Hyggebyen during 20:06-20:39 exactly, and nothing tells the player when. Gnist's 'Sidste kunde' requires talking to him in the last half hour before closing. Unlike Silke's dawn scene (already reported), these windows can be reached, but they are hard to discover and clash with Blund's slot-B search at the same hours.

**Player impact.** Heart scenes in the middle of the arc are easy to miss for weeks, which slows the family's otherwise thin progression.

**Recommendation.** Widen Silke h4 to her whole Hyggebyen round (hour:20.05-22) and move the camera mark to her live position, or use mark:round_s only for staging. Widen Gnist h8 to hour:23.5-25. The heart bubble (Npc2D._update_bubble) already signposts the scene once its condition is true.

**Verification.** Partly. Silke is in Hyggebyen until about 22:55, and the h4 window equals her round_s stay. There is no clash with Blund's slots. Both scenes can be retried daily.

### GAP-GHOST-FAMILY-ARC-11 - The ghost cousin's oil gift is lost if the backpack is full (P3, bug)

**Evidence**
- lua/dialogue/ghostfam_gnist.lua:25-27 - api.set_flag('ghostfam_kin_gnist', true) runs before api.add_item('lantern_oil', 2)
- scripts/autoload/lua_runtime.gd:298-301 - lua_add_item ignores EconomyManager.add_item's result
- scripts/autoload/economy_manager.gd:297-300 - add_item returns false (with an 'inventory full' notification) when the backpack has no room
- localization/ghostfamily.csv:130 DLG_GHOSTFAM_GNIST_KIN_1_2 'Her, to flasker olie ...' is still shown

**What's wrong.** The one-time kin gift from Gnist is applied while the dialogue is built. The flag is set first and the item result is ignored, so a player who arrives with a full backpack gets the line about two bottles of oil and an 'inventory full' toast. The gift can never be re-offered. Dyne's shirt uses the wardrobe store and is less at risk.

**Player impact.** A small but permanent loss of a promised family gift on the ghost hero's first evening.

**Recommendation.** Route kin gifts through SocialManager.owe_event_items (it keeps unclaimed items until there is room, social_manager.gd:1153-1170), or make api.add_item return the bool and set ghostfam_kin_gnist only after success.

**Verification.** Confirmed against the cited code and data.

### GAP-GHOST-FAMILY-ARC-12 - The hiding shimmer is barely visible at the start of slot A (P3, accessibility)

**Evidence**
- scripts/ghostfam/seek/hide_seek.gd:55-63 - three Glow halos at scale 0.16, colour cfe6f2 (pale blue-white)
- scripts/ghostfam/seek/hide_seek.gd:88 - alpha pulses 0.4-0.75
- docs/review/pass3/shots/sections/ghostfam_seek_shimmer.png - Monday 19:00 at 130 px with camera focus: the three dots are almost indistinguishable from lit planks and flowers
- lua/routines/ghostfam/ghostfam_blund.lua:15 - slot A starts at 18:00, before the night grade fully sets in (glow ramp 17:30-19:30 per GHOST_FAMILY_ADDENDUM.md:71)

**What's wrong.** The shimmer is the only visual clue, and it is three tiny pale dots. In the first 1.5 game hours of slot A the scene is still warm and bright, and the pass3 capture at 19:00 shows them almost invisible even when zoomed in. The only other cues are two one-time text whispers.

**Player impact.** Low-vision players, and anyone searching early in the evening, depend on luck and the whispers.

**Recommendation.** Scale the shimmer with night_factor (bigger and more opaque while the area is still bright), use a warmer, higher-contrast tint (e.g. Blund's own halo colour ffe6aa), add a soft ground ring, and offer an accessibility option that also plays a quiet chime when the shimmer first appears.

**Verification.** Confirmed against the cited code and data.

### GAP-GHOST-FAMILY-ARC-13 - Silke's light walks the whole scene tree 10 times a second (P3, tech-debt)

**Evidence**
- scripts/ghostfam/glow/npc_glow.gd:52-56 - _refresh every 0.1 s
- scripts/ghostfam/glow/npc_glow.gd:65-67,71-75 - _enabled_lights(world) recursively visits every node under world_2d to count visible PointLight2Ds

**What's wrong.** To respect the city's light cap of 15, Silke's NpcGlow counts every visible PointLight2D by recursively walking the entire world subtree every 100 ms. The city builder creates many nodes (platforms, props, foliage, lanterns), and Silke is outdoors from about 18:00 to 02:00.

**Player impact.** Avoidable CPU cost every frame-tick while Silke is in the area, adding up with the town director and other per-tick work. Low risk now, but it scales with city complexity.

**Recommendation.** Keep a light registry (lights add themselves to a group such as 'city_light', or the city builder exposes a count) and query get_nodes_in_group once per refresh, or recount only on area or light-change signals.

**Verification.** Confirmed against the cited code and data.

### GAP-GHOST-FAMILY-ARC-14 - Danish polish in family greetings (P3, copy)

**Evidence**
- localization/ghostfamily.csv:13 DLG_GHOSTFAM_DYNE_GREET_1 'Goddag, kære du! ... Jeg strikker, mens jeg fortæller, så jeg sagtens kan tale med dig imens.' - 'mens ... imens' is redundant, and 'Goddag' is used although Dyne is only met from 17:20 to 02:00 and at dawn
- localization/ghostfamily.csv:25 and :59 - SOC_GHOSTFAM_DYNE_FIRST_1_V / GNIST_FIRST_1_V open with 'Goddag!' for night-time citizens
- localization/ghostfamily.csv:72 GIFT_GHOSTFAM_GNIST_LIKE_1 'Pæn gave. Gaven får en plads ved disken.' - clumsy repetition caused by the item-neutral rule
- localization/ghostfamily.csv:15 DLG_GHOSTFAM_DYNE_DAWN_1 'Godnat! Eller godmorgen, hvis du er ung.' - the logic does not land
- localization/ghostfamily_seek.csv:13 SEEK_GHOSTFAM_TOAST_BAG_FULL says 'rygsækken', but ladder lamps go to the furniture store (EconomyManager.add_item routes non-backpack kinds, economy_manager.gd:286-294)

**What's wrong.** A handful of family lines read as translated or illogical Danish. The addendum notes that none of the 2,415 words has had a native check (GHOST_FAMILY_ADDENDUM.md:503).

**Player impact.** Minor, but these are the family's most-seen lines (default greeting and first meeting).

**Recommendation.** Use 'Godaften' or 'Hej' for the night family's default and first-meeting lines (unvoiced rows first; mark the _V rows for re-record). Rewrite as 'Sæt dig ved bålet. Jeg strikker og fortæller på samme tid.' and 'Tak, den får en fin plads ved disken.' Change the bag-full toast to 'til du har plads til den'. Schedule the 8.3 h native read listed in the addendum.

**Verification.** Confirmed. 'Godnat! Eller godmorgen…' may be an intended joke.


## Cross-cutting (first week, prior findings)

### Area: First-hour / first-week playthrough trace

I traced a new player's first week through the code, from title to the first dungeon run. The opening is well built: the first morning is data-driven and skippable, the hints are tied to a quest and show the right key for keyboard or gamepad, Pip's day-2 letter starts a town tour, failure is gentle, and the dungeon has its own whisper tutorial. The serious problems are at the edges of that path. The tools and the sword have no keyboard key at all, which breaks the owner's full-keyboard requirement on the very first tutorial step. "Nyt spil" overwrites the only autosave with no warning. One flag, `intro_done`, does two jobs, so the mayor's welcome scene can never play and she greets a stranger with "Godt at se dig igen!". The bin hint is lost in the normal order of play, so shipping is never taught. Twenty quests, endgame ones included, are offered on day 1, which buries the onboarding path. The first errand, "Tal med borgmester", gives no clue where she is. Smaller story and copy slips land on particular heroes: the fairy heroes share a name with living NPCs, the ghost opening contradicts itself, and the Kiki card is wrong. A prior finding (GM-06, the opening premise) is only partly fixed, and S-C (only ghosts get race reactions) is still open.

**Strengths**
- The first morning is data (lua/farm/farm_tutorial.lua).
- Hint glyphs are read from the live InputMap and change with the device (ui_hints.gd glyph/format_line).
- Planting out of season is refused with UI_NOT_IN_SEASON (farm_grid.gd:160), and the shop item details show seasons.
- Failure is gentle and clearly stated.
- Hero twins work for Rasmus, Kiki, Bertil and Bodil: their NPC doubles are hidden when you play them (routines/ext/*.lua hero_twin, routines.gd is_unavailable).
- Day-2 mail always carries Pip's round (post_box_2d.gd refresh pushes pips_runde first).
- The dungeon whisper tutorial now has a weak-weapon nudge, DTUT_WEAPON_WEAK (run_watch.gd:103).
- The opening now plants the mother premise and points to a first lead (fairy_king.lua:14, FM_OPENING_LEAD), which partly addresses prior GM-06.
- No 'Fesby' leftovers remain anywhere in localization, lua, scripts or maps.

### Area: Status of prior review findings

I re-checked every finding in the five prior reviews against the game-review worktree (f80e7aed). The code, save and UI defects from the Devin and Codex reviews are fixed, apart from shipping work: at this commit there is no export preset and no packaged build for macOS or Windows (the release-pipeline merge on origin/main, fc901cf0, adds both; see PRIOR-03). All ten GM findings from the 17 Oct QA review are fixed except GM-05, which is partly fixed. Most of what is still open is design, balance and story-copy debt from the two 18 Oct passes. One fix added a new problem: the Codex atomic-save fix keeps the old file in GDScript, but on Windows the engine probably deletes the target before moving the new file in.

See the "Prior review status" section for the full tally.

**Strengths**
- Fix discipline is excellent: almost every fixed finding has a named regression (tests/sections/codex_review.gd has all 10 Codex probe names; mechanics_review_fixes.gd covers the GM items; journey_regressions.gd covers the journey defects).
- The Devin modal/HUD/husbandry fixes are real in the code: pause_menu.gd uses modal_name/pop_all_modals, hud.gd:64-66 connects weather_changed and player_health_changed, and animal_husbandry.gd:377/592 emit the bus contract signals.
- Story fixes kept recorded voice intact.
- The winter gap is properly closed: frost_kale is in seed_shop (seed_shop.lua:36), and snow_turnip/snowdrop/frost_kale are on the greenhouse shelf.
- The new real-input fresh-save journey (docs/qa/journey/README.md) wins all three guardians without grants.

### Area: Save/load completeness and integrity across every subsystem

The save core is unusually solid. Writes are atomic and read back before the rename, a .bak is only made from a validated payload, a slot that has only its backup is now recovered, and active quest records are fully validated before apply (codex #1 and #2 are fixed). A load is all-or-nothing, with a snapshot and an error guard. Most daily randomness is seeded and saved, so reloading cannot re-roll shops, dungeon floors, chests or resource nodes. The main weakness is how validation treats Lua content: several validators check saved records against the live catalogue (crops, regrow_days, farm machines, animal species and buildings, a hard-coded dungeon floor cap). One renamed crop or one balance change therefore makes the whole slot 'beskadiget', and the auto slot, often the player's only save, has no backup. Second, the day-end autosave after a 02:00 pass-out captures the moment of collapse (02:00, where the player fell) instead of 06:00 at home. Section versions are handled inconsistently: 8 of 13 payload parts never read their "v" (12 sections plus world), and unknown sections are silently dropped. Furniture and wardrobe reject bad data only during apply, which bypasses the backup and misleads Continue. Smaller gaps: ground loot orbs are never saved, a section whose to_dict fails is silently omitted and then reset on load, and four small rewards use RNG that is not saved, so a reload re-rolls them. I did not re-report the core reviewer's findings (player vitals are not saved, closing the window does not save, the .tmp issue). Note that the vitals root cause (player_2d.gd:64-68 refills stamina, hearts and oil in _ready, and world_2d.gd:861-876 saves no vitals) also gives full Energi on any overworld reload, not only in the dungeon.

**Strengths**
- Write pipeline: save_manager.gd:986-1002 writes a .tmp, reads it back and compares, then renames; _roll_backup (1012-1033) only rotates a primary that validates; inspect_slot (389-397) now recovers a slot that has only its .bak (codex #2 fixed).
- Validation runs before apply and does not change game state.
- Save-scumming cannot re-roll daily outcomes.
- Small features persist through GameManager world_flags, so they need no extra save code: hide-and-seek (hide_seek.gd:116-152), crown cache, seed basket and post box (cache_day, swap_day, post_read_day), mother story (mother_story.gd:68), dungeon tutorial and …
- Machine batches (placed_items[].batch.ready_day), the greenhouse build (area_flags) and dungeon done cells, runestones and reveal all round-trip.
- Transaction safety: EconomyManager.defer_notifications (economy_manager.gd:130-145) keeps observers and saves out of half-finished transactions.
- SocialManager handles content drift well: an unknown NPC goes into an orphans bucket that survives the next save instead of failing the load (social_manager.gd:1385-1398), and tests/sections/social.gd:1332-1351 pins this.

### Area: Audio direction: music, ambience, SFX feedback and Danish voice playback

The audio code is solid and well tested. AudioManager pools and crossfades correctly and logs every cue. The director follows area, night, rain and festival state. Footsteps follow the surface. Volumes persist and are applied at startup. All 296 voiced lines match the current Danish CSV text exactly. The content does not yet meet the stated direction ("Orchestral + Nordic folk", "warm Danish narration"). All 14 music tracks are the same synthesized pentatonic arpeggio at about -36 dBFS RMS, so boss, festival and farm music cannot be told apart. Ambience is effectively inaudible after mixer gains, while TTS voices sit about 27 dB above the music. Most of the core loop is silent: hoe, water, plant, craft, mine, home upgrade, furniture, wardrobe, boss victory, sleep and pass-out, pickups outside the dungeon, and all UI focus/confirm. Two real logic bugs exist: dungeon/boss music keeps playing in the Mørkeskoven hub after a run, and the greenhouse has no music or ambience but does get rain. Voice coverage is uneven. Authored barks are voiced, but all 240 cutscene lines (hearts, festivals, Natlys) are never voiced because event_runner drops voice_key. Blund's hide-and-seek lines, the main-story hook FM_OPENING_LEAD and the 9 ghost-hero reactions are also unvoiced. Four characters switch between a quiet human recording and a loud TTS voice.

**Strengths**
- AudioManager is robust.
- Voice text is fully in sync: 296/296 manifest lines have text identical to the effective Danish CSV text in loader order (re-computed).
- Volume settings work end to end.
- Danish voice handling is careful.
- Good location and economy cues: shop bell on entering/leaving shops, door sounds, locked-door knock on the closed whispers, a closing bell only for the shop you are inside, and noon/evening town bells deduplicated per day (audio_director.gd:40-41,73-95).
- Dungeon cues are well designed.
- Footsteps use the real movement state, a surface resolver (builder callable, then ground char, then area default), ±6% pitch and no back-to-back repeated variant (footsteps.gd, surface.gd).

### Findings (31)

### FIRSTHOUR-02 - 'Nyt spil' silently overwrites the autosave of an existing run within 5 minutes (P1, bug)

**Evidence**
- scripts/ui/main_menu.gd:83-85 _on_new_game goes straight to character_select with no confirm, even though Continue is enabled (has_any_save)
- scripts/ui/character_select.gd:195-207 _on_confirm calls GameManager.start_new_game with no confirm
- scripts/autoload/save_manager.gd:4-11 there is ONE auto slot (save_auto.json, 'the auto slot has no backup') and AUTOSAVE writes it every AUTOSAVE_INTERVAL_SECONDS and at every day end
- save_manager.gd:72 AUTOSAVE_INTERVAL_SECONDS := 300.0; :155-160 _process autosaves while PLAYING; :163-168 reset() on new_game_started only zeroes the timer
- localization/menus.csv:21-22: overwrite and replace confirmations exist for save/load but there is none for New Game

**What's wrong.** A run that lives only in the auto slot is the normal case for children, who rely on autosave. If anyone starts a new game, the new run autosaves into the same auto slot after 300 real seconds or at the first bed, whichever comes first. That destroys the previous run with no warning and no backup.

**Player impact.** On a shared family computer, a sibling clicking 'Nyt spil' (or a child exploring the other heroes) wipes weeks of progress. This is unrecoverable save loss.

**Recommendation.** In main_menu.gd _on_new_game, when SaveManager.has_any_save() is true, show a UiConfirm along the lines of 'Dit gemte spil (Dag N) bliver erstattet, når det nye spil gemmer. Fortsæt?' with a 'Gem først' hint. Better still, make the first autosave of a new run copy the old save_auto.json to a save_auto.prev.json backup, or move the old autosave into a free manual slot.

**Verification.** Confirmed by two skeptics. The window is often shorter than 300 s, because event_runner, runestones and a pause-menu quit all call autosave(). A child who starts a new game by mistake and quits at once has already destroyed the old run.

### FIRSTHOUR-04 - The shipping-bin hint can never show in normal play, so shipping is not taught (P2, ux)

**Evidence**
- lua/farm/farm_tutorial.lua:32 the bin hint fires on crop_harvested; :37 expand needs gold>=800 and day>=3
- lua/quests/forste_dage.lua:6-12: harvest (target 1) is the natural LAST objective; mail is possible from day 2, while turnips need 4 watered days (game_balance turnip stages=4)
- scripts/farm/steading/tutorial/tutorial_hints.gd:30-36: hints only run while forste_dage is active, and on its completion tut_done=1 and queued.clear()
- scripts/autoload/quest_manager.gd:157 QuestManager (an autoload) connects crop_harvested before TutorialHints (attached in world _ready, tutorial_hints.gd:23); completion is synchronous (quest_manager.gd:704-708 _check_completion -> complete_quest)
- tests/sections/farm_first_morning.gd:150-163 tests the reverse order (harvest emitted before day-2 mail), so the natural order is never exercised
- docs/PLAYING.md:31 'Follow the first-days quests to learn planting, watering, harvesting and shipping.'

**What's wrong.** In the normal order (read the mail on day 2, first harvest about day 5), the harvest that triggers the bin hint also completes forste_dage. That turns the hint system off before the hint can be queued or shown. The expand hint has the same window problem: it needs 800 g while the quest is still running, and rewards push gold past 800 only on completion. The core money action, putting crops in the salgskasse, is not taught anywhere else.

**Player impact.** A child harvests the first turnips, never learns that the bin exists or that it pays the next morning, and may sell nothing, or try to sell only through shops.

**Recommendation.** Use one of these three:
- Add a `ship` objective (on = game_event shipped / item_shipped, target 1) to forste_dage after harvest, so the quest itself teaches the bin.
- Have TutorialHints keep running until tut_done is set on day_started after completion.
- Show TUT_HINT_BIN from the forste_dage completion handler.

Add a natural-order test: mail on day 2, then harvest, then expect the bin hint.

**Verification.** Partly. The core path is confirmed. 'Not taught anywhere' is strong: the bin has a proximity prompt and a morning summary, but nothing teaches it proactively. The 800 g expand hint is only 50 g away from the starting money.

### FIRSTHOUR-05 - Day-1 quest flood: 20 offers, including endgame and deep-dungeon quests, bury the onboarding path (P2, design)

**Evidence**
- scripts/world2d/npc_dialogue.gd:55-58 pushes every QuestManager.offerable(npc) to the FRONT of the choices; npc_2d.gd:386 shows '!' whenever offerable() is non-empty
- Offerable from day 1 (no requires_zone, is_available true at start, per my scan of lua/quests/*.lua):
- guard_oak: skovlift_intro, forest_patrol, bossernes_vej
- appraiser_fru_ugle: ugles_noegle, rune_vandring
- mayor_lyra: fix_roof, enchanted_garden, fairy_friendship
- farmer_rosa: first_animal, animal_products, math_harvest_puzzle
- baker_maja: cookie_delivery, birthday_cake, math_bakery_counts
- one each: fairy_wizard, fairy_lily, pippin, merchant_pip, postman_pip, gardener_hoppe
- lua/quests/bossernes_vej.lua:62-64 is_available returns true (defeat the floor 4/8/12 bosses); ugles_noegle.lua:67-69 true (amethyst, rose quartz, amber from deep floors); rune_vandring.lua:53-55 true (runestones on floors 5 and 9)
- lua/quests/animal_products.lua:73-74 is offered before the player owns any animal; fairy_friendship (a tier-7 gate) is offered on day 1

**What's wrong.** Apart from the dark_forest zone gate on 7 quests, nothing paces offers by progression. On their first walk through town a new player meets '!' over almost every quest giver. When they talk to the mayor for the intro objective, three more accept buttons sit above her lines. Oak offers 'first trip down' next to 'defeat all three guardians'.

**Player impact.** The '!' stops meaning 'next step'. A child accepts a dozen quests, the journal fills with goals that need floor 9 or a cow, and the intro path (intro_lottery, forste_dage, pips_runde, skovlift_intro, secret_garden) is lost among them.

**Recommendation.** Add light progression gates in data:
- bossernes_vej and rune_vandring: requires quest skovlift_intro done.
- ugles_noegle: requires_zone dark_forest plus deepest floor >= 3.
- animal_products: requires has_first_animal.
- fairy_friendship and enchanted_garden: requires intro_lottery done, or a min total_day.

This can be a `requires_quest` meta read by QuestManager._requirements_met next to requires_zone. Also consider capping NpcDialogue.build to one new offer per talk.

**Verification.** Confirmed against the cited code and data.

### FIRSTHOUR-07 - The fairy heroes Kløvermynte and Birk share their name with living NPCs; NPC Birk tells player-Birk 'Du ligner nogen fra min familie!' (P2, story)

*Merged:* CAST-04 (P3, Side quests): Hero twin rule missing for Birk (and Kløvermynte): the player can meet an NPC with the same name and identical sprites.

**Evidence**
- lua/config/characters.lua:73-74 heroes kloevermynte (skin fairy_meadow) and birk (skin fairy_birk)
- lua/config/npcs.lua:76-84 merchant_pip runs the seed shop with name NPC_MERCHANT_PIP = 'Butiksfe Kløvermynte' (core.csv:21); npcs.lua:394-401 beekeeper_birk with name 'Birk' (core.csv:38)
- Only rasmus, bodil, bertil and lamplighter_kiki carry hero_twin (lua/routines/ext/*.lua); merchant_pip and beekeeper_birk do not (lua/routines/core/merchant_pip.lua, beekeeper_birk.lua)
- lua/dialogue/beekeeper_birk.lua:6 the fairy branch includes DLG_BIRK_FAMILY = 'Du ligner nogen fra min familie!' (dialogue_cast.csv:68); social_talk.csv:42 'Jeg hedder Kløvermynte.'
- localization/cast.csv:12 the hero blurb says 'Driver frøbutikken i Hyggebyen'; cast.csv:15 'Passer bierne i Hyggebyen'
- [CAST-04] lua/config/characters.lua:69-76 - heroes include kloevermynte (skin fairy_meadow) and birk (skin fairy_birk)
- [CAST-04] localization/cast.csv:12 HERO_KLOEVERMYNTE_BLURB 'Driver frøbutikken i Hyggebyen…'; :15 HERO_BIRK_BLURB '… Passer bierne i Hyggebyen.' - the hero cards describe the NPCs' jobs
- [CAST-04] lua/routines/core/beekeeper_birk.lua:6-10 - no hero_twin, while lua/routines/ext/{rasmus,lamplighter_kiki,bertil,bodil}.lua all set it
- [CAST-04] scripts/towns/npc_director.gd:19 - the comment says the twins are 'rasmus, kiki, bertil, bodil, birk', but the data does not make Birk one
- [CAST-04] assets/isometric_characters/fairy_birk/idle.webp and fairy_birk_npc/idle.webp have the same md5 (4970e6ea…); hover, talk, interact and celebrate are identical too
- [CAST-04] localization/core.csv:21 NPC_MERCHANT_PIP 'Butiksfe Kløvermynte' - the seed-shop keeper has the same name as the default fairy hero
- [CAST-04] localization/dialogue_cast.csv DLG_BIRK_FAMILY 'Du ligner nogen fra min familie!' (shown to any fairy player)

**What's wrong.** For four heroes the game hides the NPC double. For the two fairy heroes it does not, and cannot easily, because Kløvermynte keeps the seed shop. The select card even tells the player that their hero runs the seed shop and keeps the bees. In week 1 a Kløvermynte player buys seeds from Kløvermynte, and a Birk player is told by Birk that he looks like family.

**Merged findings add.** From CAST-04: the design deliberately keeps Birk and Kløvermynte present (DT9 in TOWNS_FARM_SOCIAL_ADDENDUM.md:975, Q3:1512), so adding hero_twin is not the fix. What is wrong is that the fairy_birk and fairy_birk_npc idle/talk/hover sprites are byte-identical (same md5), that `npc_director.gd:19` wrongly lists birk as a twin, and that the hero blurbs describe the NPCs' jobs.

**Player impact.** There is an identity break on the first shop visit, for one of the four races, through the most-used shop.

**Recommendation.** Do one of three things:
- Rename the fairy heroes. For example, keep the looks and give the hero chips distinct names; the player types their own name anyway.
- Rewrite cast.csv:12/15 as sibling or cousin framing ('Kløvermyntes kusine…') and add a fairy-hero branch to merchant_pip and beekeeper_birk that acknowledges the relation.
- Give beekeeper_birk a hero_twin and reassign the apiary.

**Verification.** Confirmed against the cited code and data. CAST-04: Partly; the missing hero_twin is intended. Downgraded from P2.

### GAP-SAVE-INTEGRITY-01 - A Lua content or balance change makes saves fail to load: the validators check records against the live catalogue, and the auto slot has no backup (P2, bug)

**Evidence**
- scripts/autoload/save_manager.gd:702-707 - the whole payload is rejected as 'invalid' if FarmGrid.validate_dict(world.farm / greenhouse_farm) or FarmEquipment.validate_placed(world.placed) fails
- scripts/world2d/farm_grid.gd:372 - `if crop != "" and not definitions.has(crop): return false` (crop ids come from lua/config/game_balance.lua via crop_definitions(), line 38-39)
- scripts/world2d/farm_grid.gd:376 - a plot marked regrowing whose crop now has regrow_days <= 0 rejects the save (lua/config/game_balance.lua:53-54 strawberry/glow_berry regrow_days = 4 is a balance knob)
- scripts/farm/farm_equipment.gd:120 and :135 - a placed item whose def no longer has placeable="farm", or a batch whose crop or output_prefix changed, rejects the save
- scripts/farm/animal_husbandry.gd:826, 844, 850-853 - an unknown species or building_type, or a building tier above 1+upgrades.size(), rejects the save
- scripts/dungeon/floors/dungeon_floors.gd:316 - deepest and floor are hard-capped at 12 (`_whole(data.get("deepest",0),0,12)`), while max_floor is data (lua/config/dungeon.lua:15). Raising max_floor makes every save past floor 12 invalid, even in the same build
- scripts/autoload/save_manager.gd:196-198 and 389-401 - the auto slot has no .bak, so 'corrupt' means no save at all; Continue skips it (get_latest_slot 445-456)
- Contrast: social_manager.gd:1385-1398 keeps unknown NPCs in an orphans bucket (pinned by tests/sections/social.gd:1332-1351); no test pins content drift for crops, machines, animals or the dungeon floor cap

**What's wrong.** Several pure validators treat 'not in the current Lua catalogue' as file damage. Validation is slot-wide, so one plot, machine or animal record that refers to renamed or retuned content flags the whole slot as corrupt. The .bak usually has the same record, so it fails too. The game never makes a manual save on its own (current_slot starts as NO_SLOT), so a player who relies on Continue has only the backup-less auto slot. This is latent today but very likely to fire as content is renamed and balance is retuned in Lua between builds.

**Player impact.** After an update that renames or retunes a crop, animal, building upgrade or farm machine, or raises the dungeon floor cap, the save shows as 'Beskadiget' and Continue skips it or finds nothing. Every bit of progress is lost with no way to recover it.

**Recommendation.** Keep validate_dict to structural and type checks only. Move catalogue checks into from_dict as repairs with push_warning, as SocialManager does. FarmGrid.from_dict: an unknown crop becomes a TILLED plot, and regrowing is cleared when regrow_days is 0. FarmEquipment: drop an unknown placed piece and refund it to the backpack; a bad batch refunds its input crop. AnimalHusbandry: keep unknown species and buildings in an orphans dict and clamp tier to max_tier. dungeon_floors.gd:316: use int(cfg.max_floor) instead of 12. Add a test such as save.survives_content_drift that renames a crop, an animal species and a machine in a fixture config and asserts load_game succeeds.

**Verification.** Two skeptics, both partly. Every cited mechanism is confirmed. The problem is latent: nothing in the current content triggers it, and the project has a stable-id convention (npcs.lua:7). Downgraded from P1. Treat it as P1 if content renames between builds are planned before release.

### GAP-SAVE-INTEGRITY-02 - The day-end autosave after a 02:00 pass-out saves the collapse moment (02:00, the spot where the player fell), not the 06:00 wake-up at home (P2, bug)

*Merged:* CORE-09 (P3, Core loop): The pass-out's day-end autosave captures the 02:00 moment before waking, not the morning.

**Evidence**
- scripts/autoload/game_manager.gd:527-531 - _roll_day: day_ended.emit, then _step_calendar, _announce_new_day, then game_event midnight_passed (the hour is left at the restart hour 02:00)
- scripts/autoload/save_manager.gd:262-274 - day_ended queues _run_queued_autosave.call_deferred(), which runs at the end of the same frame
- scripts/world2d/world_2d.gd:687-695 and 698-706 - midnight_passed starts _sleep_sequence(true), which awaits a 0.7 s fade before GameManager.sleep_until_morning() and _enter(_wake_area()); the deferred autosave has already run by then
- scripts/autoload/game_manager.gd:502-509 - sleep_until_morning with hour < wake_hour only sets hour=6; no end_day, so no day_ended and no corrected autosave
- scripts/autoload/game_manager.gd:598 - from_dict keeps hour 2 (clamped to day_roll_restart_hour()..25), so a load resumes at 02:00
- Contrast: the defeat path autosaves after the wake-up (world_2d.gd:785-786), and bed sleep sets hour=6 synchronously in end_day (game_manager.gd:489-495) before the deferred save runs
- [CORE-09] scripts/autoload/game_manager.gd:479-482 each roll sets hour = restart (02:00) and then _roll_day; :527-531 day_ended is emitted, then midnight_passed
- [CORE-09] scripts/autoload/save_manager.gd:262-274 the day_ended autosave is deferred only to the end of the same frame
- [CORE-09] scripts/world2d/world_2d.gd:698-711 the pass-out awaits a 0.7 s fade before GameManager.sleep_until_morning() and the _enter(wake area)
- [CORE-09] scripts/autoload/game_manager.gd:502-508 the pass-out branch of sleep_until_morning sets 06:00 without day_ended, so no save follows the wake-up; save_manager.gd:247 the save resets the 300 s timer

**What's wrong.** At a pass-out, advance_time rolls the day and the deferred day-end autosave writes the auto slot in that same frame. That is before the pass-out sequence moves the player home and sets the clock to 06:00, and nothing autosaves after the wake-up. Until the 5-minute timer or a pause-menu quit writes again, the auto slot holds day N+1 at 02:00 with the player standing where they collapsed. Combined with the known window-close-without-save issue, Continue often restores exactly this snapshot.

**Merged findings add.** CORE-09 found the same thing independently and adds that the next save is up to 300 s away, and that a pass-out inside a shop interior is possible, so the player can wake at 02:00 in a closed shop.

**Player impact.** After passing out and closing the game, Continue starts at 02:00 in town or the forest instead of waking at home. It also hands out 4 free night hours (02:00-06:00) before the next pass-out, and the 'wake at home' rule is skipped.

**Recommendation.** Autosave after the wake-up instead of on the roll. One option: in world_2d._sleep_sequence, after _restore_player(), call SaveManager.autosave() when passed_out, as the defeat path does at 785-786. Another: in SaveManager._on_day_ended, skip the deferred save when GameManager.hour < day_start_hour() and let the world save once sleeping is false. Add a check such as clock26.pass_out_autosave_wakes_at_home: advance from 01:59 past 02:00, wait for the sequence, then assert the auto slot has hour 6 and area == wake_area.

**Verification.** Confirmed against the cited code and data. CORE-09: Confirmed against the cited code and data.

### GAP-AUDIO-FEEL-01 - All music, ambience and SFX are one-algorithm synth placeholders; boss, festival and farm music are indistinguishable (P2, design)

**Evidence**
- assets/audio/music/synth-manifest.json "status": "synthesized placeholder" (same for sfx/ and amb/)
- tools/voice/synth_common.py:39-44 every music track = 'sparse pentatonic placeholder', the same 8-note pattern [0,7,12,14,9,7,4,2] at 1.5 s per note; only the root pitch (seeded from the name) differs
- tools/voice/synth_common.py:31-38 every ambience = low-pass noise plus a chirp at 2100 Hz (day) / 1400 Hz (night); town_day and farm_day differ only by seed
- tools/voice/synth_common.py:26-30 every non-noise SFX = the same 3-partial tone, so loot_legendary vs pickup_soft differ only in pitch
- docs/qa/mechanics/audio/waveforms.json: all 14 music files RMS -35.8..-36.1 dBFS, peak -23.4..-24.0, 47 s mono 22.05 kHz
- docs/game_design.md:124-126 'Music: Orchestral + Nordic folk (soft strings, flute, harp)… Voice: Warm Danish narration'
- lua/config/audio.lua:9-10 Hyggebyen and Trætoppen share city_theme and town_day/town_night

**What's wrong.** The whole soundtrack comes from deterministic pure-Python placeholder recipes. All 14 music tracks are the same arpeggio at the same tempo and envelope, transposed. boss/boss_final have no more tension than farm_theme, and festival tracks have no festive character. All ambiences are the same filtered noise with a periodic chirp. The two towns (fairy shopping district vs treetop city) share one theme and one ambience. The loops are only 47 s (music) and 24 s (ambience), so they repeat constantly over an 06:00-02:00 day.

**Player impact.** Music does not mark area, mood, danger or celebration. A boss floor sounds like the farm. The 47 s loops become grating within minutes, and there is a release pipeline (macOS/Windows) in flight.

**Recommendation.** Treat audio as a release blocker workstream. Commission or license real stems for at least farm, city (separate Hyggebyen and Trætoppen), forest/dungeon acts, boss and the festival set, as ≥2-3 min loops at 44.1 kHz stereo. Replace the files at the same ids under assets/audio/{music,amb,sfx}; the pipeline already supports drop-in replacement (docs/voice_lines.md:43). Until then, add at least a tempo, instrument and mode variation per recipe in synth_common.py so boss/festival/farm are distinguishable.

**Verification.** One skeptic confirmed, one partly. The recipe analysis is confirmed. The routing pipeline works and the assets are openly labelled placeholders, so this is asset debt, not a broken system. Downgraded from P1.

### GAP-AUDIO-FEEL-02 - Farming, crafting, home, wardrobe and boss-victory events are silent (P2, missing-feature)

**Evidence**
- scripts/audio/audio_director.gd:15-23 the only EventBus listeners: item_purchased, gold_changed(+), friend_changed, crop_harvested, quest_accepted/completed, whisper, modal_changed
- scripts/autoload/event_bus.gd:37-38 crop_planted, crop_watered; :44-45 animal_fed, animal_product_collected; :52 recipe_crafted; :74-75 resource_node_hit/depleted; :78 enemy_defeated; :93-95 home_upgrade_started/home_upgraded; :99-100 furniture_placed/picked_up; :104 garment_equipped: no audio listener anywhere (rg play_sfx: only audio_director, cues.gd, footsteps.gd, event_runner.gd:204)
- docs/design/PLAN_2D_FEATURES.md:388,391,394 list 'audio' as a consumer of home_upgraded, furniture_placed and garment_equipped
- scripts/dungeon/floors/dungeon_floors.gd:263 emits dungeon_boss_defeated; cues.gd:31-42 has no case for it, so boss music loops on after the kill
- scripts/dungeon_run/cues.gd:19-20 item pickup sounds only when floor_of(area) > 0: forage, animal products, quest and Blund rewards outside the dungeon are silent
- scripts/world2d/world_2d.gd:698-713 sleep/pass-out and 752-789 gentle defeat: no audio cue, music keeps playing under the black fade
- lua/config/home_amenities.lua:14 is the only content using the event 'sfx' step; lua/events/** has 0 sfx steps

**What's wrong.** Of the requested core actions, only harvest (pickup_soft), buy and sell (coin_clink through gold_changed delta>0), gift (gift_sparkle), heart up, quest accept/complete and dungeon hit/hurt/loot make a sound. Hoe/till, water, plant, tool swing, chopping/mining, crafting, animal care, the 10-step home upgrade (start and completion), placing furniture, equipping clothing, killing an enemy, beating a boss, passing out, waking up and gentle defeat are all silent. The design docs explicitly planned audio for home_upgraded, furniture_placed and garment_equipped.

**Player impact.** The moment-to-moment cozy loop (till, water, plant) has no tactile feedback. The biggest progression moments (home tier up, first boss kill) land in silence, and boss music keeps looping after the boss is dead.

**Recommendation.** Add rows to lua/config/audio.lua (a 'signals' map next to 'events') and connect them in audio_director.gd._ready. Cover: crop_planted→seed_plant, crop_watered→water_pour, a hoe/till event, resource_node_hit→chop/pick by node_type, recipe_crafted→craft_done, home_upgraded→a fanfare plus a music sting, furniture_placed→furniture_thunk, garment_equipped→cloth_rustle, enemy_defeated→poof. Handle dungeon_boss_defeated in cues.gd: play a victory sting, then music/rune_rest or the act track. Remove the floor>0 gate for ordinary pickups (keep rarity cues). Fade music and ambience out in _sleep_sequence and _on_player_defeated, and play a soft wake chime on day_started.

**Verification.** One skeptic confirmed, one partly. Confirmed. Chest opening, weapon/gem equip and menu open do make sounds. This is missing feedback, not a broken loop. Downgraded from P1.

### GAP-AUDIO-FEEL-03 - Dungeon or boss music keeps playing in the Mørkeskoven hub after returning from a floor (P2, bug)

**Evidence**
- scripts/audio/audio_director.gd:66 'if area_id.begins_with("moerkeskoven_f"):return' runs before _music is updated
- scripts/audio/audio_director.gd:67-71 the music changes only 'if music!=_music'
- scripts/dungeon_run/cues.gd:37-42 dungeon_floor_entered switches the real track to dungeon_act1..4 / boss / boss_final (and :36 rune_rest), without telling the director
- scripts/dungeon/floors/dungeon_floors.gd:183-197 dungeon_floor_entered is emitted only for valid floors, never for the hub
- lua/config/dungeon.lua:16 hub area = "moerkeskoven"; lua/config/audio.lua:11 moerkeskoven music = forest_theme

**What's wrong.** Entering the hub from Trætoppen sets _music = 'forest_theme' and plays it. Descending to moerkeskoven_f1 returns early, so _music stays 'forest_theme' while DungeonCues starts dungeon_act1 (and later boss/boss_final/rune_rest). Climbing the home rope back to the hub runs refresh() with music 'forest_theme' == _music, so play_music is never called. The last dungeon track, possibly boss_final, keeps looping in the hub until the player leaves to the city.

**Player impact.** After a run the safe forest edge keeps playing combat or boss music, which undercuts the 'you're safe now' moment and sounds like a bug.

**Recommendation.** In refresh(), when the area is a generated floor set _music = "" (or a sentinel such as "<dungeon>") before returning, so the next non-floor area always calls play_music. Alternatively, have DungeonCues call a director method that records the track it started. Add an audio_town or dungeon test: hub → floor → hub asserts music forest_theme in the cue log.

**Verification.** Confirmed against the cited code and data.

### GAP-AUDIO-FEEL-04 - Greenhouse has no music or ambience but plays outdoor rain; per-map @music and dungeon band music are ignored (P2, bug)

**Evidence**
- lua/config/audio.lua:5-13 areas list has no 'greenhouse' entry, so audio_director.gd:54 gives data = {}, ambience '' and music '' → stop_music() (:70)
- data/maps/greenhouse.map:2,6,10 '@id greenhouse', '@indoor true', '@music farm_theme'
- scripts/world2d/area_map.gd:33,155-156 parses @music, but audio_director.gd never reads area.map.music (rg 'map.music': only iso_area.gd:342 and dungeon_verify.gd:63)
- scripts/audio/audio_director.gd:61 the rain overlay is excluded only for 'int_*' and 'home', not for @indoor maps
- scripts/ui/build_menu_ui.gd:151 world.travel(&"greenhouse") is a real playable area
- lua/config/dungeon.lua bands music = forest_theme ×3 and 'crystal_cave_theme' (no file in assets/audio/music/); the runtime uses dungeon_act% instead (cues.gd:42)

**What's wrong.** Walking from the farm into the greenhouse fades the farm music out to silence and drops all ambience. The director's own table has no greenhouse row, and the @music farm_theme declared on the map is never consulted. On rainy days the outdoor rain overlay keeps playing inside the glass house, because rain suppression checks name prefixes instead of the map's @indoor flag. There are three sources of truth for music (audio.lua, map @music, dungeon band music), and two of them are dead config. One of them names a track that does not exist.

**Player impact.** A farm building goes dead silent (it sounds broken) and has rain indoors. Content authors who set @music or band music get no effect.

**Recommendation.** Make the director fall back to area.map.music when audio_map has no row, and add greenhouse = { day='shop_interior', night='shop_interior', music='farm_theme', surface_default='wood' } to lua/config/audio.lua. Use area.map.indoor (or map ambient 'home') instead of name prefixes for rain suppression. Either remove music from the dungeon.lua bands or make cues.gd use it, and drop crystal_cave_theme or create it.

**Verification.** Confirmed against the cited code and data.

### GAP-AUDIO-FEEL-05 - Mixer gain staging: voices about 27 dB above music, ambience inaudible, and no Ambient slider (P2, balance)

**Evidence**
- docs/qa/mechanics/audio/waveforms.json RMS: music -35.9 dBFS, ambience -41.5 (cave_drip -56.9, shop_interior -53.7, rain -36.8), SFX -29..-35, TTS voice median -16.5 (max -14.1)
- scripts/autoload/audio_manager.gd:30 music_volume_db = -8.0; :29 sfx -4.0; :255 ambience target -16 dB; :60 rain -22 dB; scripts/audio/footsteps.gd:34 footsteps -20 dB
- audio_manager.gd:207 default bus volume 0.8 (-1.9 dB) for every bus
- Effective RMS: music ≈ -46 dBFS, ambience ≈ -59 dBFS (cave ≈ -75, shop interior ≈ -72), rain ≈ -61, TTS voice ≈ -18
- scenes/ui/settings_ui.tscn:94-101 (and Music/Sfx/Voice rows) max_value = 1.0, so no boost above 0 dB
- scripts/ui/settings_ui.gd:6 BUSES = Master, Music, Sfx, Voice; audio_manager.gd:206 also manages 'Ambient', which has no slider

**What's wrong.** With the shipped files and the fixed player gains, a voice line plays about 27 dB louder than the music and about 40 dB louder than the ambience. Cave drips and the shop-interior bed sit around -72..-75 dBFS, below audibility on normal listening levels. Sliders cannot go above unity, so the only fix is to turn voice and SFX down and raise system volume. Ambience/rain cannot be adjusted or muted separately at all; Music 0 + SFX 0 still leaves forest wind and rain.

**Player impact.** With the system volume set so dialogue is comfortable, music and ambience are barely there. With the volume raised for music, every voice line and coin clink is jarring. A player who wants silence except for the world cannot control ambience.

**Recommendation.** Normalise the assets to loudness targets (for example music -20 LUFS, ambience -26, SFX -18, voice -18). Set the player gains in audio_manager.gd to 0 dB and mix on the buses instead. Add a fifth TTSlider 'Omgivelser' (Ambient) to settings_ui.tscn and settings_ui.gd BUSES (the key 'ambient' is already read by audio_manager.gd:206-207). Optionally duck Music by 4-6 dB while _voice_player is playing.

**Verification.** Confirmed against the cited code and data.

### GAP-AUDIO-FEEL-06 - Danish voice coverage is inconsistent: cutscenes never voiced, key story and hide-and-seek lines silent, ghost reactions missing files (P2, consistency)

**Evidence**
- scripts/social/events/event_runner.gd:59 'lines.append({"text_key":…})' copies only text_key, so any voice_key on a say step is dropped
- lua/events/** has 240 act='say' steps (heart events of 10 NPCs, 9 festivals open/end, ghostfam/natlys.lua 44) and 0 voice keys
- lua/dialogue/ghostfam_blund.lua:48-103 all hide-and-seek 'found'/'gift' lines (SEEK_GHOSTFAM_FOUND_*, _GIFT_*) are unvoiced, while his other 13 lines (:30-199) are voiced
- lua/dialogue/fairy_king.lua:13-14 the voiced DLG_KING_LETTER is followed by FM_OPENING_LEAD (the mother-quest hook, forest_mother.csv:115) with no voice_key
- lua/config/race_reactions.lua:6-14 nine voice_keys (voice/*/ghost_first, fairy_king/ghost_intro) have no file and no manifest row; the comment at :1 says 'no audio is generated'
- Gift reactions: GIFT_*_V voiced for 10 of 29 NPCs (none for the ghost family, fairies, guard_oak, Fru Ugle, Natteblik, Pippin); localization/social_talk.csv has 40 of 335 SOC_ rows voiced (_V); bertil, bodil, clerk_fjerpen, cub_bamse, fiddler_strimmel, innkeeper_kvak, lamplighter_kiki and rasmus each have exactly one voiced line (first meeting)
- docs/game_design.md:126 'Voice: Warm Danish narration & character voices'

**What's wrong.** All 34 citizens have at least one voiced line, and authored barks are fully voiced. The emotionally important content is silent, though. Heart events, festival speeches and the Natlys family scenes cannot be voiced at all, because the event runner strips voice_key. Blund's hide-and-seek payoff, which the owner explicitly asked for, is silent while his everyday lines speak. The main story hook after the voiced lottery letter is silent mid-conversation. Ghost-hero first meetings are silent while the same NPCs speak their next line. The voice switches on and off line to line within one conversation. The protagonists (fox, fairy, hobbit, ghost) have no voice and no barks.

**Player impact.** Danish players learn that voice means 'unimportant chatter'. Important beats feel flatter than daily greetings, and on/off voicing inside one dialogue box reads as a bug.

**Recommendation.** In event_runner.gd:59 pass the voice key through: lines.append({"text_key":…, "voice_key":str(steps[index].get("voice_key",""))}). Then add voice_key to the say steps in tools/social/content and generate them. Priority order for generate_voice.py: FM_OPENING_LEAD (as narrator or king), SEEK_GHOSTFAM_* for Blund, the 9 race_reactions keys (drop the 'no audio is generated' comment), and the heart events. Make gift reactions either all voiced or none per NPC tier.

**Verification.** Confirmed against the cited code and data.

### GAP-AUDIO-FEEL-07 - Same character alternates between quiet human recordings and loud TTS; merchant Pip's greeting uses a different voice (P2, consistency)

**Evidence**
- assets/audio/voice/manifest.json kind 'recorded' (11) vs 'placeholder' (285); mixed characters: mayor_lyra 4 recorded + 10 TTS, baker_maja 4 + 13, smith_thorin 2 + 8, fairy_lily 1 + 1
- waveforms.json RMS: voice/mayor_lyra/lottery -31.5, hello -30.4, smith_thorin/mining_talk -29.0, baker_maja/* ≈ -22; TTS placeholders -18.2..-14.1 (median -16.5)
- lua/dialogue/merchant_pip.lua:15 voice_key = "voice/pip/greet" (folder 'pip', pitch 1.029) while the other merchant lines are in voice/merchant_pip (pitch 1.142)

**What's wrong.** Mayor Lyra's lottery announcement, the opening story beat, is a human recording about 15 dB quieter than her other lines, which come from the macOS 'Sara' TTS voice at a different pitch. The same speaker changes timbre, gender cues and loudness between lines, and the same happens for Maja, Thorin and Lilje. Merchant Pip's greeting was generated under a separate speaker id, so his first line has a different pitch from the rest.

**Player impact.** Characters sound like two different people. The most important early line is the hardest to hear.

**Recommendation.** Either re-record all lines of these four characters with the same performer or temporarily replace the 11 human lines with TTS for consistency (keep the originals archived). In any case, loudness-normalise all voice files to one target (for example -18 LUFS) in generate_voice.py, including protected recordings via a gain-only copy. Move voice/pip/greet to voice/merchant_pip/greet (update merchant_pip.lua:15, the manifest and RECORDED rules).

**Verification.** Confirmed (per-folder counts are slightly off; mayor_lyra has 4+9).

### GAP-AUDIO-FEEL-08 - No UI sounds: focus/accept/cancel hooks exist but nothing listens; page_turn fires on every modal push and pop (P2, missing-feature)

**Evidence**
- scripts/ui/nav/ui_nav_watcher.gd:9 'forwards focus moves and the accept / cancel presses as signals (P24 may play a sound from them)'; :18-20 signals; :52, :60-63 emits
- rg 'focus_moved|accepted.connect|cancelled.connect' finds no listener in scripts/
- docs/design/UI_NAVIGATION.md:289 'signals: device_changed(dev), focus_moved(c), accepted(c), cancelled() (P24 may play SFX from them)'
- scripts/audio/audio_director.gd:23 modal_changed → page_turn on every stack change; scripts/autoload/game_manager.gd:312-315 emits on every push and pop
- scripts/ui/dialogue_ui.gd:24 modal_name = &"dialogue"; scripts/social/events/event_runner.gd:55-67 opens a new dialogue per speaker run, so page_turn plays twice per speaker change in cutscenes

**What's wrong.** Keyboard-first play (gold focus ring everywhere) has no audible focus-move, confirm, cancel or error sounds. The only UI sound is page_turn on any modal stack change. That includes opening and closing every NPC chat (where it collides with the voice line start) and every speaker switch inside heart and festival cutscenes, plus confirm dialogs. It is too frequent where it plays and missing where it would help.

**Player impact.** Menus feel unresponsive, especially with the keyboard. Cutscenes get a stream of page-flip noises between speakers.

**Recommendation.** Connect UiNav.watcher().focus_moved/accepted/cancelled in AudioDirector (it lives under AudioManager, which processes always) to ui_tick/ui_confirm/ui_back cues. Play the focus tick only when the move came from a real keyboard or gamepad input this frame, not from programmatic grab_focus on screen open (track the last ui_* action timestamp in the watcher). Restrict page_turn to journal, letters and book screens by checking the modal name in modal_changed, and exclude 'dialogue' and 'event'.

**Verification.** Confirmed against the cited code and data.

### GAP-AUDIO-FEEL-09 - Festival music plays everywhere, and 9 festivals share 4 seasonal tracks (P2, design)

**Evidence**
- scripts/audio/audio_director.gd:62-67 'festival := SocialManager.festival_active()!=""' with no area check → music = 'festival_'+season in every non-floor area (farm, home, interiors, the other town, the Mørkeskoven hub)
- scripts/social/social_manager.gd:772-778 festival_active() is time-only
- lua/festivals/fixed/bagedagen.lua:29,38 area hyggebyen / vinter; aarsskiftet.lua:27,36 traetoppen / vinter; vinterlysene.lua:27,36 traetoppen / vinter → all three use festival_vinter
- badedagen.lua (sommer, traetoppen) and midsommerlanterner.lua (sommer, traetoppen) share festival_sommer; blomsterfesten + honningdagen share festival_foraar; hoestfesten + maanemarkedet share festival_efteraar
- audio_director.gd:63 also ducks ambience -6 dB on dungeon floors during a festival

**What's wrong.** When a festival window opens, the festival horn plays and the festival score replaces area music wherever the player is. Examples: Månemarkedet in Hyggebyen is scored on the player's farm and in Trætoppen shop interiors. Bath day and the Midsummer lanterns get the same tune. The festival's 'area' field is ignored for audio.

**Player impact.** The festival soundscape does not pull the player to the right place and makes distinct events sound the same. Being on the farm during a festival sounds like being at it.

**Recommendation.** Add a music id per festival in lua/festivals/fixed/*.lua (falling back to festival_<season>) and play it only when area_id equals the festival's area (or its interiors). Elsewhere keep the area score and optionally play the horn faintly. Skip the ambience duck when the player is not in the festival area.

**Verification.** Confirmed against the cited code and data.

### GAP-AUDIO-FEEL-10 - No night, late-night, season or snow/fog audio states; rain cuts in and out abruptly (P2, design)

**Evidence**
- lua/config/audio.lua:6-12 each area has one 'music' key; only ambience has day/night variants, so the same track runs 06:00 → 02:00
- scripts/audio/audio_director.gd:57 ambience by is_night() only; no season input anywhere in the director
- tools/voice/synth_common.py:34-35 day ambience = chirps at 2100 Hz, so 'birdsong' also plays in winter
- lua/config/game_balance.lua:94-98 vinter: sne 0.45, taage 0.25; audio_director.gd:61 only regn/torden trigger audio, so snow and fog are silent
- scripts/autoload/audio_manager.gd:263-277 play_rain() starts at a fixed -22 dB and stops with player.stop(), no fade, while area ambience crossfades for 1.5 s (:246-255)
- scripts/world2d/world_2d.gd:698-713 pass-out/sleep: no audio change under the black fade; no morning cue on wake

**What's wrong.** Night changes only the ambience bed, and only on the farm/town/forest presets. Music is identical at 10:00 and 01:30, and there is no wind-down before the 02:00 pass-out. Seasons do not change any audio outside festival days, and winter mornings play the same bird chirps as spring. Snow (45% of winter days) and fog have no ambience. Entering or leaving a shop in the rain hard-starts or hard-cuts the rain loop, the one abrupt cut in an otherwise crossfaded system.

**Player impact.** The day/season cycle that drives a Stardew-like game is mostly invisible to the ear. Late night has no audible 'go to bed' pressure, and the rain cuts are noticeable.

**Recommendation.** Allow 'music_night' (and optionally 'music_<season>') keys in lua/config/audio.lua and pick them in refresh(). Fade music out from about 00:00 (raw 24) and silence it near pass-out. Add 'amb/<area>_winter' or a season multiplier, plus 'amb/snow_wind' and 'amb/fog' overlays keyed by TimeManager.weather. Give play_rain a 1.0-1.5 s volume tween in and out like _fade_ambience.

**Verification.** Confirmed against the cited code and data.

### GAP-AUDIO-FEEL-11 - Title screen and character select are silent (P2, missing-feature)

**Evidence**
- scripts/ui/main_menu.gd:6-10 _ready calls SettingsUI.apply_saved() only; no play_music
- rg play_music: only audio_director.gd:71 and dungeon_run/cues.gd:8, and the director is gated on a live world_2d (audio_director.gd:26-27, :52)
- scripts/audio/audio_director.gd:43-50 _leave() stops all world audio when quitting to the menu (asserted by tests/sections/audio_town.gd:78 menu_stops_world_audio)

**What's wrong.** There is no menu or title theme. The game opens, and returns from 'quit to menu', into total silence until the world loads. Character select (choosing fox Rasmus, fairy, hobbit or Pedro the ghost) has no music or selection sounds.

**Player impact.** A weak first impression. Silence on the title screen often reads as broken audio drivers.

**Recommendation.** Add music/title_theme (and the UI cues from the UI-sound finding) and start it in main_menu.gd._ready with AudioManager.play_music('title_theme'). Let world entry crossfade from it, since play_music already fades.

**Verification.** Confirmed. P3 would also be defensible.

### FIRSTHOUR-09 - Opening cast continuity slips: Pip introduces himself twice, ghost mail goes to the 'fence', and the journal says the mayor gave the lottery quest (P3, consistency)

**Evidence**
- farm_tutorial.csv:3 Pip: 'Jeg hedder Pip og kører posten'; the tutorial page is social=false (tutorial_runner.gd:130), so SocialManager.met stays false and the next talk prepends social_talk.csv:102 'Jeg er Postbud Pip…' (dialogue_bridge.gd:18-21)
- ghost_dialogue.csv:10 DLG_GHOST_POST 'Jeg lægger brevene på dit gærde' is prepended to Pip's greeting (race_reactions.gd:21-25, tutorial_runner.gd:131), then farm_tutorial.csv:7 'Kig i postkassen i morgen' and TUT_HINT_MAIL 'Der ligger post i postkassen!'
- lua/quests/intro_lottery.lua:41 giver = mayor_lyra, so the journal (tt_quest_text.gd:120-127, quest_journal.gd:127/201) attributes 'Fekongens lotteri' to the mayor, although the King sent it and Pip delivered it

**What's wrong.** There are three small continuity breaks in the first hour, all in the opening.

**Player impact.** The world feels less attentive at the moment it is building trust with the player.

**Recommendation.** - Mark the citizen as met after the tutorial page, by calling SocialManager mark-met for postman_pip in tutorial_runner._dialogue.
- Change DLG_GHOST_POST to 'Jeg lægger brevene i kassen ved dit gærde'.
- Add meta.source_key = NPC_FAIRY_KING to intro_lottery (tt_quest_text.gd:121 already supports source_key).

**Verification.** Partly. 'Pip introduces himself twice' is refuted: on_conversation_finished marks him as met, and `farm_first_morning.gd:71` pins it. The ghost mail-on-the-fence line and the mayor-as-giver attribution are confirmed.

### FIRSTHOUR-12 - The first dungeon trip's 'Væk en rune' needs floor 3, and the ability hint hardcodes 'Klik' (P3, ux)

**Evidence**
- lua/quests/skovlift_intro.lua: objective light_rune on dungeon_runestone_activated; lua/config/dungeon.lua floors 1-2 stone=false (:106, :130), first stone=true on floor 3 (:149-157); the hub 'Port-runen' (rune picker) is not a runestone
- localization/dungeon_services.csv:22 OBJ_SKOVLIFT_INTRO_LIGHT_RUNE 'Væk en rune' does not name a floor
- localization/dungeon_run.csv:64 DTUT_ABILITIES 'Klik: slå. Mellemrum: undvig. Q: fe-lys. R: drik.' is literal text, not UiHints glyphs, so gamepad players see keyboard and mouse words

**What's wrong.** On their first trip a child may stand at the Port-runen in the hub expecting to 'wake a rune', or turn back on floor 1-2 thinking the objective is broken. The combat tutorial line ignores the input device, unlike every farm hint.

**Player impact.** There is confusion on the first dungeon objective and mismatched instructions for gamepad players.

**Recommendation.** - Change OBJ text to 'Find og væk runestenen på 3. etage'.
- Convert DTUT_ABILITIES to '%s: slå. %s: undvig. %s: fe-lys. %s: drik.' with format_actions [attack, dodge, light, drink], via UiHints.format_line in DungeonTutorial.say.

**Verification.** Confirmed against the cited code and data.

### FIRSTHOUR-13 - docs/PLAYING.md does not match the game in several first-week claims (P3, consistency)

**Evidence**
- PLAYING.md:61 'Keyboard and controller attacks…', but there is no keyboard attack (project.godot:158)
- PLAYING.md:31 'Follow the first-days quests to learn … shipping', but forste_dage has no shipping objective and the bin hint is unreachable (see the bin-hint finding)
- PLAYING.md:31 'The journal contains quests, relationships, calendar and the mother's investigation', but the quest_journal.gd:26-36 tabs are Active, Completed, Calendar and Mother; relationships live in People (P), which the controls table (PLAYING.md:7-23) does not list, and neither does H (Indretning)

**What's wrong.** The player-facing guide overstates keyboard support and the tutorial's coverage, and puts relationships in the wrong screen.

**Player impact.** Parents or testers following the doc will look for features that are not where it says.

**Recommendation.** After fixing the bindings and the bin teaching, update PLAYING.md:
- Controls table: add P (Folk), H (Indretning) and the new tool/attack key.
- Line 31: say relationships are under Folk (P).

**Verification.** Partly. The journal/relationships mismatch and the missing P/H/C keys are confirmed. PLAYING.md:61 most likely means keyboard-driven aim, and its controls table says 'Left mouse button' correctly.

### GAP-SAVE-INTEGRITY-03 - Section versions are handled inconsistently: most sections ignore "v", unknown sections are silently dropped, and furniture and wardrobe reject data only during apply, which bypasses the backup (P3, tech-debt)

*Prior review:* docs/reviews/codex-review.txt finding 1 (fix suggestion: 'Consider a backup attempt after an apply failure') - still open for apply-time rejections. Re-verified against current code: still open.

**Evidence**
- scripts/autoload/save_manager.gd:15-16, 26 - each section 'carries its own v' while PAYLOAD_VERSION stays 2, so the payload-level 'newer' check (678-679) never sees a section bump
- Version written but never read in from_dict: home_manager.gd:708 vs 724-767; social_manager.gd:1359 vs 1368-1404; shop_system.gd:434 vs 438-461; economy_manager.gd:736 vs 741-799; quest_manager.gd:1204 ('v': 2) vs 1282-1310; game_manager.gd:568 ('version') vs 590-614; world_2d.gd:863 ('v': 1) vs 880-905; time_manager.gd:245-262 writes none
- Rejected during validation (state 'corrupt', .bak tried): loot_service.gd:1063-1065, animal_husbandry.gd:817, dungeon_floors.gd:314
- Rejected only during apply: wardrobe_manager.gd:168-169 and furniture_manager.gd:241-242 return false from from_dict for v != 1 or a wrong shape, and neither has validate_dict. inspect_slot therefore reports 'ok', get_latest_slot (445-456) picks the slot for Continue, load_game fails with 'apply' (300-302) without trying the .bak, and _roll_backup (1023) still treats the file as valid
- save_manager.gd:682-698 - validation and apply only loop over registered entries: a payload key with no registered node (for example 'dungeon' when host_dungeon_floors() returns false, loot_service.gd:964-969) passes validation, is ignored on load and is missing from the next gather_payload (581-593)

**What's wrong.** There is no single policy for section version skew. A save from a newer build with a bumped section is silently read with old code in 8 of 13 payload parts (12 sections plus world), rejected as 'corrupt' (not 'newer') in 3, and rejected only during apply in 2, which bypasses the backup. Sections the build does not know are silently lost on the next save. The codex review's suggestion to try the backup after an apply failure (codex-review.txt finding 1, fix note) is still not implemented.

**Player impact.** Rare today because no section is past v1/v2. Once a section is bumped, though, a downgrade or a partially failing feature can quietly lose that feature's progress, or show 'Beskadiget' when the real reason is 'made by a newer version'. Continue keeps choosing a slot that cannot load.

**Recommendation.** Give every section a SECTION_VERSION and a pure validate_dict that returns a distinct 'newer' verdict. In validate_payload, map it to code 'version', so the slot becomes 'newer' and the .bak is not used, as already pinned by bak_not_used_for_newer_version. Add validate_dict to WardrobeManager and FurnitureManager mirroring their from_dict guards. Keep unknown top-level payload keys in a passthrough dict that gather_payload writes back. Add a test that bumps 'home'.v to 99 and asserts inspect_slot == &"newer".

**Verification.** Confirmed. The 'dungeon' unknown-key example is close to unreachable in a shipped build, but the general point stands.

### GAP-SAVE-INTEGRITY-04 - A section whose to_dict fails is silently left out of the save, then reset on load, so that feature's progress is erased (P3, design)

**Evidence**
- scripts/autoload/save_manager.gd:587-591 - a to_dict that returns a non-Dictionary only push_errors and 'continue's; the save is still written and reported as successful
- scripts/autoload/save_manager.gd:697-698 and 915-917 - optional sections that are missing are not an error; on load the node's reset() runs
- scripts/autoload/save_manager.gd:1012-1033 - the next manual save rotates the previous good file into .bak and the one after overwrites it, so two saves after the bug the old progress is gone
- tests/sections/save.gd:792 - section_with_bad_to_dict_is_left_out pins this as intended

**What's wrong.** Any runtime error in a feature's to_dict (home, furniture, wardrobe, loot, dungeon, social) produces a save that validates but no longer contains that section. The save is reported as successful, and the next load resets the section to a new-game state. Silently writing a partial save trades a loud failure for permanent data loss.

**Player impact.** A bug in one feature's save code could wipe all friendships, the home tier or the furniture of a run, with no warning and, after two more saves, no backup.

**Recommendation.** For a registered or core section whose to_dict fails, abort save_game: return false, set last_error code 'gather', leave the old file and .bak untouched, and show NOTIF_SAVE_FAILED for manual saves. Alternatively, write the previous on-disk copy of that section (from the current file) instead of omitting it. Update the pinned test to expect the refusal.

**Verification.** Confirmed against the cited code and data.

### GAP-SAVE-INTEGRITY-05 - Loot orbs on the ground are not saved, but their source is marked used when it drops them, so a save, quit or load loses them (P3, bug)

**Evidence**
- scripts/world2d/enemy_2d.gd:369-370 - drops are spawned as LootDrop2D orbs and the enemy cell is immediately LootMarkers.mark_done
- scripts/world2d/resource_node_2d.gd:143-161 - dungeon nodes get ctx.deliver='orbs' and mark_done; overworld nodes set the resource_day flag (158) before spawning orbs
- scripts/loot/loot_service.gd:206-211 - creature kills default to DELIVER_ORBS
- scripts/world2d/loot_drop_2d.gd:2 ('Delivery is retriable. A full pack never destroys a drop') and 103-111 - orbs wait on the ground while the backpack is full
- scripts/world2d/world_2d.gd:861-876 - world to_dict has no entry for ground drops; scripts/ui/pause_menu.gd:110-120 - quitting autosaves and then leaves

**What's wrong.** The promise that a drop is never destroyed holds only within a session. The kill or harvest is committed to the save (done cell or day flag), but the orbs it spawned are scene nodes and are not in world.to_dict. This matters most with a full backpack, when orbs stay on the ground by design.

**Player impact.** With a full bag in Mørkeskoven, quitting through the pause menu (or loading) loses every uncollected drop, including rare materials and gems, and the enemies and nodes do not come back that day.

**Recommendation.** Save live orbs per area in WorldRoot2D.to_dict as 'drops': [{area, pos, item, amount}] (including PendingDrops rows) and respawn them in _apply_saved. Alternatively, on save or area exit, deliver orbs through LootService.deliver and route any overflow to the home chest (HomeManager.chest).

**Verification.** Confirmed against the cited code and data.

### GAP-SAVE-INTEGRITY-06 - Some small daily rewards use unsaved RNG, so reloading re-rolls them (P3, balance)

**Evidence**
- scripts/traetoppen/life/crown_cache_2d.gd:40 and :51 - items.pick_random() and randi_range(gold_min, gold_max) use the global, unsaved RNG
- scripts/traetoppen/life/seed_basket_2d.gd:23 - randi_range(1, sum) picks the seed (moonflower vs glow_berry)
- scripts/economy/crafting_system.gd:24, 138 - a static RandomNumberGenerator, never saved, rolls the bake bonus
- scripts/world2d/farm_grid.gd:45, 242 - rng.randomize() on _ready and the harvest_bonus_chance roll (yield_amount is only cached once a harvest is attempted)
- scripts/social/social_rng.gd:4 - the project's own rule: 'NOT randf() (a reload would re-roll)'

**What's wrong.** These outcomes break the project's 'no re-roll on reload' rule, which shops, dungeon loot, resource nodes and the social layer all follow. Saving manually right before the interaction lets a player reload until they get the best result.

**Player impact.** A player can farm max gold from the crown cache, the rarer seed from Hoppe's basket, and bonus bakes and harvests by saving and reloading. This is minor but contradicts the deterministic design elsewhere.

**Recommendation.** Use SocialRng.roll(SocialManager.world_seed, ["crown_cache", total_day, slot]) or DungeonRng.hash_key(...) keyed on total_day and the object id for the crown cache, seed basket, bake bonus (recipe, day, craft count) and harvest bonus (cell, planted_day).

**Verification.** Confirmed against the cited code and data.

### GAP-AUDIO-FEEL-12 - The ghost hero makes footsteps although the game says ghosts arrive without a sound (P3, consistency)

**Evidence**
- scripts/audio/footsteps.gd:17-34 no race/perk check; every hero plays step_<surface>_N
- localization/ghost_dialogue.csv:4 DLG_GHOST_MAYOR 'Åh, et spøgelse! Du kom helt lydløst.'
- docs/design/GHOST_ADDENDUM.md:280 'The name sfx/ghost_whoosh is reserved (silent without a file)', written before footsteps existed
- scripts/world2d/player_2d.gd:571-574 the ghost floats (altitude bob)

**What's wrong.** Pedro the ghost hovers, and NPCs comment that he came silently, yet he plays grass, wood and stone footsteps like the fox and the hobbit. The reserved ghost_whoosh was never wired up.

**Player impact.** A small immersion break for the ghost hero.

**Recommendation.** In footsteps.gd advance(), when GameData.perk('float_bob_px',0) > 0 (or the race is ghost), play a soft 'ghost_whoosh' at a lower rate, or skip steps. Add the cue to sfx_synth.py.

**Verification.** Confirmed against the cited code and data.

### GAP-AUDIO-FEEL-13 - Gift reaction sound ignores taste: a hated gift sparkles like a loved one (P3, ux)

**Evidence**
- lua/config/audio.lua:17 gift_given = "gift_sparkle" (a single cue)
- scripts/social/gifts/gift_flow.gd:169 the game_event gift_given carries 'taste' (love/like/neutral/dislike/hate)
- scripts/audio/audio_director.gd:75-78 the generic event→cue lookup ignores the payload

**What's wrong.** Every gift plays the same sparkle, and heart_up only fires when hearts rise. A hate or dislike gift therefore sounds positive.

**Player impact.** Audio contradicts the NPC's negative reaction text and gives children the wrong signal about gift taste.

**Recommendation.** Let audio.lua events accept a table keyed by payload, e.g. gift_given = { by = 'taste', love = 'gift_sparkle_big', like = 'gift_sparkle', neutral = 'pickup_soft', dislike = 'gift_meh', hate = 'gift_meh' }, and resolve it in audio_director._event.

**Verification.** Confirmed against the cited code and data.

### GAP-AUDIO-FEEL-14 - Settings sliders lack the value readout from the spec and give no test sound (P3, ux)

**Evidence**
- docs/design/UI_NAVIGATION.md:424 'four TTSlider rows … (0-100 step 5, value readout Display20)'
- scenes/ui/settings_ui.tscn:88-101,108-121,128-141,148-161 each row is only a Caption + HSlider (0..1, step 0.05), with no readout label
- scripts/ui/settings_ui.gd:105-109 _volume_changed applies and saves but plays no preview; the world is paused when settings open from pause (settings_ui.gd:75), so no world SFX play while adjusting

**What's wrong.** The volume sliders have no number, which the UI spec requires, and adjusting SFX or Voice gives no audible sample. With the tree paused in the pause→settings path, the player adjusts blind.

**Player impact.** It is hard to set levels precisely or match them between sessions, especially for the voice slider, which only matters in Danish dialogue.

**Recommendation.** Add a Display20 readout label per row showing round(value*100), updated in _volume_changed and _refresh_texts. On release or after a short debounce, play a sample (coin_clink for SFX, a short voice line such as voice/mayor_lyra/hello for Voice when Danish) through AudioManager, which processes always.

**Verification.** Confirmed against the cited code and data.

### GAP-AUDIO-FEEL-15 - Unused audio configuration: dead event ids and an unused director field (P3, tech-debt)

**Evidence**
- lua/config/audio.lua:19-20 events seeds_swapped, gem_set, weapon_equipped: rg finds no emitter (gem/weapon cues are handled via equipment_changed in audio_director.gd:80-82)
- scripts/audio/audio_director.gd:7 var _festival is written (:64) but never read
- lua/config/dungeon.lua bands music (forest_theme ×3, crystal_cave_theme) and map '@music' headers are not read by the audio code (see the greenhouse finding)
- lua/config/race_reactions.lua:1 comment 'no audio is generated' contradicts docs/voice_lines.md:22 'no deferred hooks'

**What's wrong.** Several audio config keys never trigger. Authors editing them see no effect, and the docs claim complete coverage.

**Player impact.** None directly; it misleads content authors and makes audio regressions harder to spot.

**Recommendation.** Remove the three dead rows from audio.lua (or emit the events where seeds are swapped). Delete _festival. Add a lint in tests/sections/audio_town.gd that every audio_map.events key is in a known emitted-event list and every referenced cue id has a file.

**Verification.** Confirmed against the cited code and data.

### PRIOR-03 - No export preset or packaged-build smoke test at the reviewed commit; the release-pipeline merge on origin/main adds both (P3, tech-debt)

*Prior review:* docs/reviews/codex-review.txt (export_presets.cfg / packaged smoke test) and devin-review-2026-10-15 §3.3 (export packaging landmine). Re-verified: still open at f80e7aed and on local main (61cd5183); resolved on origin/main fc901cf0.

**Evidence**
- .gitignore:9 ignores export_presets.cfg at f80e7aed and local main; no preset and no export smoke script is tracked there
- lua/towns.lua.import importer="keep" (keep-import stubs now cover the .lua and .map files)
- .github/workflows/playtest.yml runs-on: ubuntu-latest only, with no export step
- origin/main fc901cf0 ('Merge pull request #1 from magudb/codex/release-pipeline', 2026-10-18) un-ignores and commits export_presets.cfg (Windows and macOS, include_filter "*.lua,*.csv,*.json,*.map,*.txt,*.ps1,*.sh"), adds scripts/release/export_smoke.gd, .github/workflows/build.yml (windows-latest and macos-latest export, then the binary runs with `--headless --release-smoke`, tools/release/release.py:117-142) and release.yml

**What's wrong.** At the reviewed commit, the macOS and Windows release targets have no committed export preset and no test that a packaged build boots. The runtime reads raw Lua, map, JSON and CSV files through FileAccess/DirAccess, which only Linux CI and editor runs exercise. The release-pipeline merge on origin/main closes this; the reviewed snapshot and local main simply predate it. The primary checkout (branch codex/release-pipeline) already tracks the preset.

**Player impact.** None once local main is synced with origin/main. Until then, no build from the reviewed line has been shown to boot.

**Recommendation.** Sync local main with origin/main. Check that the export smoke in build.yml also runs on pull requests, not only through the tag-triggered release.yml, so a broken include filter is caught before a release.

**Verification.** Partly. Open at f80e7aed and on local main. The original evidence ('no preset in the main checkout') was wrong, because that checkout is on codex/release-pipeline and tracks a preset, and origin/main has since merged the fix. Downgraded from P2.

### PRIOR-22 - House tiers 3-10 are never earned unassisted by any runtime test (P3, tech-debt)

*Prior review:* mechanics-story-deep-dive-2026-10-18 'Playtest harness blind spots'. Re-verified: partly closed by the fresh-save journey; still open for tiers 3-10.

**Evidence**
- tests/sections/home_progression.gd:11-12 and tests/sections/content_features.gd:521-524 call Grant.requirements(tier) for tiers 2-10
- docs/qa/journey/README.md:45-46 the fresh animal and ghost journeys end on day 20 with a tier-2 house; :67 'does not replace … all ten house tiers earned in one save'
- tools/features/sim/balance_sim.py (with tools/dungeon_loot pacing.inject) models gold and days per home tier offline; no workflow runs run_balance.sh

**What's wrong.** The fresh-save journey proves that the main story and tier 2 can be earned with real input. Every later tier gate (hearts, hygge, crystal_cave, materials) is tested only with granted requirements. Gold pacing is modelled analytically, but not checked at runtime or in CI. ECON-01's builder-yard stall is the kind of regression this misses, since the balance sim buys missing materials instantly.

**Player impact.** Pacing regressions in the middle and late home ladder go unnoticed until a player hits them.

**Recommendation.** Extend tests/acceptance/journey.gd, or add a long scenario that earns tiers 3-6 (crystal_cave included) and records days and gold per tier. Run the balance sim in CI with a budget per tier.

**Verification.** Confirmed. The offline balance sim is a nuance, not a refutation. origin/main's release merge changes none of this.

### PRIOR-23 - Codex architecture and CI advice is mostly not done at the reviewed commit: WorldRoot2D has grown and the city has no texture-cold budget (P3, tech-debt)

*Prior review:* docs/reviews/codex-review.txt (Architecture assessment / Performance / Validation and delivery coverage). Re-verified: open at f80e7aed and local main; the Python-stage and release-OS parts are fixed on origin/main fc901cf0.

**Evidence**
- scripts/world2d/world_2d.gd is 949 lines (852 in the Codex review) and still owns the travel, sleep, faint and pass-out queues (:53 _pass_out_pending, :759 _on_player_defeated)
- tests/sections/city_map.gd:710 gates only the BEST warm rebuild; town_budgets.gd:103 has interior_cold_build, while :123 has only city_warm_build
- town_budgets.gd:429-447 city_travel_twelve_cold_citizens bounds a whole travel into traetoppen to ≤800 ms with 12 cold citizens, but runs after the art prefetch loop, so it is not a texture-cold first-visit budget
- .github/workflows/playtest.yml at f80e7aed: ubuntu-latest, no tools/art/.venv setup
- origin/main fc901cf0 adds tools/art/setup_env.sh with a pinned setup-python step to playtest.yml, plus build.yml with windows-latest/macos-latest export and a packaged smoke (release.py --smoke)

**What's wrong.** At the reviewed commit the transition-coordinator split has not happened (world_2d.gd has grown by about 100 lines), the city has no texture-cold first-visit budget, and CI has no pinned Python stage. Origin/main fixes the Python stage and adds packaged smokes on macOS and Windows (see PRIOR-03). Still open even on origin/main: there is no explicit expected-skip policy, so `--strict` still does not fail on skips, and the playtest suite runs only on Linux.

**Player impact.** Indirect. First-visit hitches in the city can come back unnoticed, and skipped checks hide missing coverage.

**Recommendation.** Add a city cold_entry_ms budget measured before the art prefetch. Make `--strict` fail on unexpected skips, with an allow-list for known ones. Move the travel/sleep/faint/pass-out state machine out of world_2d.gd into a TransitionCoordinator.

**Verification.** Partly. The evidence is accurate at the reviewed snapshot. The Python and release-OS parts are fixed upstream. The city has a cold-citizen travel bound, but not a texture-cold one. The Codex review asked for a pinned Python job, packaged smoke and windowed perf; it did not ask for a macOS/Windows playtest runner. The transition-coordinator split is not done.


## Prior review status

Every finding in the five earlier reviews was re-checked against `f80e7aed`. Godot was not run; the verdicts come from code, data and the existing tests.

| Prior review | Fixed | Partly fixed | Still open | Other |
|---|---|---|---|---|
| docs/review/game-review-2026-10-18.md | 6 (M2, M6, M7, M9a, S5-voice, S5-weapon-nudge) | 3 (M5, S5-Root-Scribe, S5-garden-payoff) | 6 (M1, M4, M8, M9b enchanted flag, M9c sword_upgrade, S5-Lily) | 1 retracted (M3); the fishing-rod teaser was accepted as deliberate and is re-raised as a new suggestion (PRIOR-20) |
| docs/review/mechanics-story-deep-dive-2026-10-18.md | 6 (E1, F1, F2, S-B, S-F, C3 addressed by forge recipes); also the t10 fairy_king stall risk was invalid | 6 (E3, C2, S-A, S-H, tutorial gaps, harness blind spots) | 15 (E2, E4, E5, E6, R1, R2, FE2, S-C, S-D, S-E, S-G, S-I, S-J, S-K, S-L) | 6 passes confirmed (C1, C4, S1, S2, R3, FE1); C5/F3 design notes; C6 superseded, not re-measured |
| docs/review/devin-review-2026-10-15.md | about 23 (1.1-1.11, the 8 perf notes, arch 3.1/3.2/3.4/3.6) | 1 (3.3: keep stubs exist, no export preset at f80e7aed; fixed on origin/main, PRIOR-03) | 1 cosmetic (3.5: ShopSystem/AnimalHusbandry still outside scripts/autoload; not reported) | — |
| docs/reviews/codex-review.txt | 9 (behavioral 1-8, 3D legacy dirs) | 2 (rename resilience on Windows, perf gating) | 3 at f80e7aed (WorldRoot2D split, CI Python/OS coverage, export preset plus packaged smoke test; origin/main fc901cf0 fixes the Python stage, the export preset and the packaged smoke: PRIOR-03, PRIOR-23) | — |
| docs/qa/game-mechanics/README.md (findings in docs/review/game-mechanics-2026-10-17.md) | 9 (GM-01..04, 06..10) | 1 (GM-05) | its balance notes, tracked under M1 / E2 / E3 / S-L | — |

**Fixed (re-verified):**

- Pass 1: M2 (dead fish feed), M6 (winter crops plus greenhouse), M7 (cookie_delivery now pays 500 g), M9a (mushroom-hunt offer gate), S5 voice (296 recordings now exist), S5 weapon nudge (DTUT_WEAPON_WEAK, "Smeden kan hjælpe").
- Pass 2: E1 (sheep give 3-4 wool), F1 (house upgrades to 6/9 places), F2 (winter), S-B (bosses now say "Overvind" and earlier wins count), S-F (forest chapters use FM_INVESTIGATION as giver). C3 is covered by the forge recipes in lua/recipes/dungeon.lua. The "t10 fairy_king only via quest" stall risk was wrong, because fairy_king takes gifts.
- Devin: 1.1-1.11 (no mouse capture, modal contract, load_and_enter, HUD weather/health, bus signals, coop capacity, warp whisper, faint guard, day_end clamp, skins, audio), all perf notes, and 3.1/3.2/3.4/3.6 (legacy code removed, screens ship, quest_defs, weather_duration removed).
- Codex: findings 1-8, all with probes in tests/sections/codex_review.gd, plus the 3D legacy folders.
- QA/GM: GM-01 (missing witness), 02 (feeding rule), 03 (pail), 04 (guardian wording), 06 (opening FM_OPENING_LEAD), 07 (wool), 08 (giver), 09 (collection key), 10 (premature conclusions), and the club-stun description qualifier.

**Still open: reported in this pass with a `prior_ref`.**

- **COMBAT-09**: mechanics-story-deep-dive-2026-10-18 C2 'Club's signature stun is null vs every boss'
- **SOCIAL-03**: mechanics-story-deep-dive-2026-10-18 FE2 (festival rewards thin) - still open: attend.points = 20 and seed/honey prizes are unchanged. The scoring problem described here is new.
- **SOCIAL-04**: game-mechanics-2026-10-17 social-writing note ('25 citizens share each of two exact bark lines') - still open, and the barks also turn out to be unused.
- **CORE-01**: mechanics-story-deep-dive-2026-10-18 R1 (Ghost is the dungeon's dominant race): still open, re-verified; the fairy half is new
- **CORE-03**: game-review-2026-10-18 M4 (Stamina is nearly non-binding): still open; the tool-upgrade and perk consequences are new
- **CORE-08** (shown under SPINE-08): mechanics-story-deep-dive-2026-10-18 S-C (Race-select story hooks are ghost-only): still open
- **HOME-01**: E5 'Hygge decor is cheapest via spam-furniture' (docs/review/mechanics-story-deep-dive-2026-10-18.md:82) - still open; the stall-risk row 'Hygge 3/4 vs furniture_capacity' in the same doc is not reproduced
- **MENUS-05**: devin-review-2026-10-15 §1.11 (shop refusal reasons not surfaced in the UI). The no_gold case is fixed; no_room is still open.
- **SPINE-01**: S-L (mechanics-story-deep-dive-2026-10-18) static Lyra dialogue is still open; the flag collision itself is new
- **SPINE-03**: GM-06 (game-mechanics-2026-10-17) marked fixed; the fix does not yet establish the premise
- **SPINE-05**: S-I (mechanics-story-deep-dive-2026-10-18) bargain narrates the refusal before the click is still open
- **SPINE-08**: S-C (mechanics-story-deep-dive-2026-10-18) still open
- **CAST-02**: game-mechanics-2026-10-17 (writing note: 25 citizens share bark lines) - extended; still open in a broader form
- **CAST-06**: mechanics-story-deep-dive-2026-10-18 S-L (most town dialogue is static) - still open, and Maja's branching (cited there as the good example) has this lock-in problem
- **CAST-08**: mechanics-story-deep-dive-2026-10-18 S-G - still open
- **FARM-05**: mechanics-story-deep-dive-2026-10-18 E3 'Catnip is a pure trap crop' (still open, re-verified)
- **FARM-06**: mechanics-story-deep-dive-2026-10-18 E2 'Fertilizer is a dominant, decision-free purchase' (still open, re-verified)
- **FARM-08**: mechanics-story-deep-dive-2026-10-18 F3 'fairy_dust_water is a luxury sink' (still open, re-verified)
- **HOME-05**: GM-09 'The advertised Collection key has no screen' (docs/review/game-mechanics-2026-10-17.md:83) - still open: docs fixed, screen still absent and C still bound
- **SPINE-13**: M9 enchanted_garden_unlocked unread (game-review-2026-10-18) still open
- **SPINE-14**: S-D and S-E (mechanics-story-deep-dive-2026-10-18) still open
- **CAST-09** (shown under COPY-11): mechanics-story-deep-dive-2026-10-18 S-H - the original instance is fixed; this one is still open
- **CAST-11** (shown under COPY-10): mechanics-story-deep-dive-2026-10-18 S-K (flower_necklace origin) - still open
- **FIRSTHOUR-08** (shown under SPINE-03): GM-06 (game-mechanics-2026-10-17.md) - partially fixed; still open as described
- **FIRSTHOUR-14** (shown under SPINE-08): S-C (mechanics-story-deep-dive-2026-10-18.md) - still open
- **GAP-SAVE-INTEGRITY-03**: docs/reviews/codex-review.txt finding 1 (fix suggestion: 'Consider a backup attempt after an apply failure') - still open for apply-time rejections

**Prior-status items re-verified separately (PRIOR-01..23).** The prior-status reviewer also filed its still-open items as 23 standalone findings. Their first verifier crashed, so they were re-verified in a separate pass. All 23 survived, as confirmed or partly; none was refuted outright.
- Merged into an area finding (17): PRIOR-01 → ECON-06; PRIOR-02 → CORE-12; PRIOR-04 → SPINE-08; PRIOR-05 → CAST-02; PRIOR-06 → COPY-11; PRIOR-07 → ECON-09; PRIOR-09 → SPINE-05; PRIOR-10 → CAST-08; PRIOR-11 → SPINE-14; PRIOR-12 → COPY-10; PRIOR-13 (catnip half) → FARM-05; PRIOR-14 → FARM-06; PRIOR-15 → HOME-01; PRIOR-16 → SOCIAL-03; PRIOR-17 → CORE-01; PRIOR-18 → COMBAT-09; PRIOR-21 → CORE-03.
- Reported on their own (6): PRIOR-19 (sword_upgrade after buying the iron sword; its enchanted_garden half is in SPINE-13) and PRIOR-20 (fishing rod) under Game mechanics; PRIOR-08 (Root Scribe and chapter weight) under Story; PRIOR-03 (export preset and packaged smoke), PRIOR-22 (house tiers 3-10 never earned unassisted) and PRIOR-23 (Codex architecture and CI advice) under Cross-cutting.
- Severity changes: PRIOR-01, PRIOR-02 and PRIOR-03 were lowered from P2 to P3. PRIOR-03 and the CI parts of PRIOR-23 are open at f80e7aed and on local main, but fixed on origin/main fc901cf0.
- Refuted parts: the turnip half of PRIOR-13, plus smaller corrections to PRIOR-03, PRIOR-14, PRIOR-15 and PRIOR-20 (see "Refuted / dropped claims").

**A fix that caused a new problem:** the Codex atomic-save fix calls `DirAccess.rename_absolute`. On Windows the engine probably deletes the target before moving the new file in, and the startup `.tmp` sweep then deletes the only surviving copy. See CORE-12 (PRIOR-02 merged).

## Screenshots

All paths are relative to `docs/review/`. Every shot is 1280x720, Danish, hero Rasmus, captured 2026-10-18.

| Screenshot | Illustrates |
|---|---|
| [pass3/shots/pass3_ui_indretning.png](pass3/shots/pass3_ui_indretning.png) | MENUS-08: the active filter is invisible, about 1 list row fits, the panel covers the HUD date chip. MENUS-02: focus sits on "Luk". |
| [pass3/shots/pass3_ui_husbyggeri.png](pass3/shots/pass3_ui_husbyggeri.png) | MENUS-03: no current/done tier, bare gate rows, no material sources. COPY-17: requirement state shown by colour only. MENUS-02 |
| [pass3/shots/pass3_ui_home_chest.png](pass3/shots/pass3_ui_home_chest.png), [pass3/shots/pass3_ui_home_amenities.png](pass3/shots/pass3_ui_home_amenities.png) | MENUS-02 (focus on "Luk"); COPY-10 ("I morgen, Tirsdag 2. Blomstermåned") |
| [pass3/shots/pass3_ui_garderobe.png](pass3/shots/pass3_ui_garderobe.png) | MENUS-04: the ring is on the dress tile while the detail says "Tom plads". HOME-02 |
| [pass3/shots/baseline_compare/shop_ui_smith_weapon_card_da.png](pass3/shots/baseline_compare/shop_ui_smith_weapon_card_da.png) | MENUS-04: the ring is on "Månesplint" while the detail shows "Jernsværd". COPY-09: decimal point |
| [pass3/shots/baseline_compare/shop_ui_equipment_iron_sword_da.png](pass3/shots/baseline_compare/shop_ui_equipment_iron_sword_da.png) | COPY-09 ("Slag i sekundet 2.5 · Skade i sekundet 30.0") |
| [pass3/shots/pass3_ui_inventory.png](pass3/shots/pass3_ui_inventory.png), [pass3/shots/pass3_ui_journal.png](pass3/shots/pass3_ui_journal.png) | MENUS-06: the hint bar is about 1.8:1 on the scrim. COPY-09 ("Mangler 2 Lysende svamp"). MENUS-14 |
| [pass3/shots/sections/towns_city_seed_shop_panel.png](pass3/shots/sections/towns_city_seed_shop_panel.png) | MENUS-12: the shop opens on 900 g fairy dust with Køb disabled. MENUS-06 |
| [pass3/shots/pass3_ui_shop.png](pass3/shots/pass3_ui_shop.png) | COPY-10 ("Vand ét felt i 3 dage") |
| [pass3/shots/pass3_ui_calendar.png](pass3/shots/pass3_ui_calendar.png), [pass3/shots/sections/social_ui_journal_calendar.png](pass3/shots/sections/social_ui_journal_calendar.png) | MENUS-07: festival names truncated, side panel never follows focus. COPY-13: "Efterår" next to "Høstmåned" |
| [pass3/shots/pass3_ui_people.png](pass3/shots/pass3_ui_people.png) | CAST-02: template bio. COPY-13 ("5. Forår") |
| [pass3/shots/pass3_ui_pause.png](pass3/shots/pass3_ui_pause.png), [pass3/shots/sections/menus_pause_full_game.png](pass3/shots/sections/menus_pause_full_game.png) | MENUS-09 ("Testmenu · F8" above Gem). MENUS-01: no Indretning row |
| [pass3/shots/pass3_ui_select_1.png](pass3/shots/pass3_ui_select_1.png) | COPY-04 ("Standardfiguren, når man vælger skovdyr … så han graver …") |
| [pass3/shots/pass3_ui_settings.png](pass3/shots/pass3_ui_settings.png) | COPY-01 (no accessibility options); GAP-AUDIO-FEEL-14 (no value readout) |
| [pass3/shots/pass3_world_intro_opening.png](pass3/shots/pass3_world_intro_opening.png) | SPINE-03 (opening on the farm, Pip's greeting) |
| [pass3/shots/pass3_farm_day_hud.png](pass3/shots/pass3_farm_day_hud.png) | HUD-03: the whisper covers hotbar slot 1. COPY-02, COPY-12 ("Brug Venstre klik på marken"). HUD-09: "1" badges on tools |
| [pass3/shots/baseline_compare/comparison_hotbar.png](pass3/shots/baseline_compare/comparison_hotbar.png) vs [reference_hotbar.png](pass3/shots/baseline_compare/reference_hotbar.png) | HUD-09 (failing `hud.v2_hotbar_compare`) |
| [pass3/shots/pass3_farm_evening_2030_hud.png](pass3/shots/pass3_farm_evening_2030_hud.png), [pass3/shots/pass3_farm_night_0040_hud.png](pass3/shots/pass3_farm_night_0040_hud.png) | HUD-08 ("Solskin" at night); clock strength ("Mandag · 00:40") |
| [pass3/shots/pass3_traetoppen_city.png](pass3/shots/pass3_traetoppen_city.png) | HUD-03; HUD-13 (landmark line band) |
| [pass3/shots/pass3_moerkeskoven_surface.png](pass3/shots/pass3_moerkeskoven_surface.png) | HUD-04: the hero spawns under the bottom HUD. HUD-11 ("Skovkanten · 0") |
| [pass3/shots/pass3_dungeon_f1_hud.png](pass3/shots/pass3_dungeon_f1_hud.png) | HUD-02: the toast hides "Etage 1". HUD-04. HUD-05: placeholder ability words, unreadable drink count |
| [pass3/shots/sections/dungeon_hud_hearts_9_layout.png](pass3/shots/sections/dungeon_hud_hearts_9_layout.png) | HUD-04 (hero behind the hearts plate); HUD-10 (unplated gold assist label); HUD-16 (loot-feed rows) |
| [pass3/shots/sections/bosses_boss_telegraph_shot.png](pass3/shots/sections/bosses_boss_telegraph_shot.png) | HUD-02 (toasts under the boss bar) |
| [pass3/shots/sections/forest_mother_mother_final_account.png](pass3/shots/sections/forest_mother_mother_final_account.png) | HUD-10 (unplated backpack-full warning); COPY-15 / SPINE-05 (finale page) |
| [pass3/shots/sections/dungeon_hud_picker_lines.png](pass3/shots/sections/dungeon_hud_picker_lines.png) | HUD-15 ("god til etage 1–1"); a strength: the 10 % defeat stake is stated before the dive |
| [pass3/shots/sections/social_ui_farm_social_hud.png](pass3/shots/sections/social_ui_farm_social_hud.png), [pass3/shots/pass3_ui_social_hud.png](pass3/shots/pass3_ui_social_hud.png) | HUD-12 (unlabelled birthday chip) |
| [pass3/shots/sections/social_fest_content_honningdagen_gathering.png](pass3/shots/sections/social_fest_content_honningdagen_gathering.png) | HUD-13 (festival ribbon position) |
| [pass3/shots/pass3_home_interior.png](pass3/shots/pass3_home_interior.png) | HUD-14 ("E Sov" at 12:00); MENUS-01 (no decorate cue) |
| [pass3/shots/sections/ghostfam_seek_shimmer.png](pass3/shots/sections/ghostfam_seek_shimmer.png) | GAP-GHOST-FAMILY-ARC-12 (shimmer barely visible at 19:00) |
| [pass3/shots/sections/ghostfam_seek_progress_card.png](pass3/shots/sections/ghostfam_seek_progress_card.png) | GAP-GHOST-FAMILY-ARC-05 (card shows only a count) |
| [pass3/shots/pass3_ui_build_menu.png](pass3/shots/pass3_ui_build_menu.png) | COPY-09 ("Guldagern 50500 / 500" with no separator) |

The committed baselines in `docs/qa/ui_baseline/` (journal, gift, calendar) are out of date. Compare them with `pass3/shots/baseline_compare/npc_journal.png`, `social_ui_gift.png` and `social_ui_calendar.png`. The UI has legitimately gained tabs and items since then, so the baselines need re-reviewing, not the UI.

## Refuted / dropped claims

These lines are here so future reviewers do not raise the same claims again.

**Whole items dropped in verification.** None. The 23 prior-status items (PRIOR-01..23) were first dropped because their verifier crashed. All of them were re-verified and survived; see "Prior review status" for where each one is reported.

**Sub-claims refuted inside surviving findings:**
- **CAST-02:** "The mayor of Hyggebyen mixes up the towns." Refuted: Hyggebyen is a district of Trætoppen (GLOSSARY.md:44).
- **FIRSTHOUR-09:** "Pip introduces himself twice." Refuted: the tutorial page still marks him as met (`farm_first_morning.gd:71`).
- **ECON-08:** "Smelting a brass bar loses value." Refuted: the inputs sell for 43 g and the bar costs 48 g to buy.
- **COMBAT-05:** "The first boss kill pays only a rune." Refuted: it completes snurresvampen, which pays 1,200 g and a legendary hat.
- **HUD-01 / MENUS-05:** "Quest-accepted and quest-completed toasts from NPC dialogue expire unseen." Refuted: those toasts fire after the dialogue modal has closed.
- **FIRSTHOUR-07 / CAST-04:** "Birk and Kløvermynte need `hero_twin`." Refuted: keeping them present is the intended design (DT9, Q3). The identical sprites are the real defect.
- **HOME-05:** "Samlerbog is a missing owner requirement." Refuted: it was explicitly made optional (PLAN_2D_FEATURES.md:58).
- **ECON-04:** "The greenhouse shelf having no hours, and carrying every crop, is an oversight." Refuted: both are deliberate (DT44/C28) and test-pinned.
- **GAP-WORLD-TRAVERSAL-01, case (b):** "The fast-travel post fakes a talk." Disputed. One skeptic found no map marker; other verifiers confirm that `city_town.gd:53-56` places the posts in code. Treat it as likely and re-test.
- **SPINE-12:** "The King never welcomes the hero." Refuted: SOC_FAIRY_KING_FIRST_1_V is prepended at the first meeting.
- **Prior "Hygge 3/4 vs furniture capacity" stall risk:** not reproduced. Builder gifts alone pass those thresholds (HOME-01).
- **Prior "t10 fairy_king only via quest" stall risk:** invalid, because fairy_king accepts gifts.
- **Prior M3:** retracted in the earlier review; still retracted.
- **PRIOR-13 (turnip half):** "Turnip is strictly beaten by carrot and needs a niche." Refuted: turnip is the sheep's favorite_feed (lua/config/husbandry.lua:103-105, bonus 20, added in 6d095beb on 15 Oct), cows accept it (:118), it is the birthday_cake quest crop (birthday_cake.lua:13,31), and gardener_hoppe and bertil like it as a gift. It trails carrot on gold only.
- **PRIOR-14:** "Every shop multiplier is 1.0 except the magic store; add a lantern-house +25 % forage bonus." Refuted: lua/shops/lantern_house.lua:16-17 already has sell_multiplier 1.25 for forage. Only the bakery crop bonus is missing.
- **PRIOR-15:** "Unique and legendary furniture from the dungeon gives less hygge per gold." Refuted: all 17 unique and 11 legendary rows have buy_price 0 and sell_ratio 0, so no gold is spent on them. The per-gold figures were also corrected (normal about 0.020, not 0.013).
- **PRIOR-20:** "The fishing rod is an open prior finding, like the GM-03 milking pail." Refuted framing: pass 1 accepted the rod as a deliberate teaser, and GM-03 explicitly exempted it and fixed the pail by giving it an action.
- **PRIOR-03:** "There is no export preset in the main checkout." Refuted: the primary checkout is on codex/release-pipeline and tracks export_presets.cfg, and origin/main fc901cf0 has merged it. The finding stands only for f80e7aed and local main.

## Coverage and limits

- **No runtime play by reviewers.** Godot belongs to another agent, so every finding comes from reading code and data. Timing claims are inferred from code and the existing screenshots, not reproduced. That includes toasts expiring behind modals, the Skovlift E-target overlap, Blund's prompt band, heart-scene framing and the boss daze collapse.
- **Not captured or not reviewed:**
  - the 02:00 pass-out sequence, because the night shots set the clock directly
  - Samlerbog (no scene exists)
  - the event overlay (only an empty fixture; the real festival scenes come from the section shots)
  - the uncommitted town-map UI in the main checkout
  - the `codex/release-pipeline` branch (commit 084321db, map UI, export presets, CI); only its export and CI status was checked, through origin/main fc901cf0, for PRIOR-03 and PRIOR-23
- **Heroes and locales:** every shot uses the fox, Rasmus. The fairy, halfling and ghost heroes were seen only in two ghost_lines shots and in QA turnaround sheets. Only Danish was captured, apart from four forest_mother `_en` shots. English copy was checked only for leftovers and naming.
- **Resolutions and devices:** only 1280x720 was examined. 16:10, ultrawide, fullscreen scaling and gamepad glyph rendering were not.
- **Not proofread:** the full Danish corpus of about 32,600 words. Quests, dialogue, cast, ghost, rel_ui, nav/hud and the forest_mother finale were read in full; heart_events, wardrobe, furniture and keepers were scanned by script. The roughly 2,400 words of ghost-family copy have had no native-speaker read.
- **Not modelled:**
  - per-dive loot (estimated analytically, not Monte-Carlo)
  - festival seed markets, the hobbit bake bonus and price curves
  - hygge versus furniture-capacity simulation for tiers 6-10
  - combat DPS tuning beyond the race perks
- **Audio:** nobody listened to any of it. Loudness figures come from the pipeline's own `waveforms.json`.
- **Tests:** reviewers did not run them. The test results in this document come from the capture agent's gate run (RED, see Method). The headless festival failures look like a test-harness timing issue, not a game defect, but that is unverified.
- **Performance:** not measured. The only signals are the small misses on the gate's budgets.
