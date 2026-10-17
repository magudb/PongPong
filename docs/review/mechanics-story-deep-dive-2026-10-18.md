# Game mechanics & story deep-dive — 18 October 2026 (pass 2)

Worktree/branch: `../PongPong-worktrees/game-review`, `game-review` @ `a49d07b` (= main).
Scope: content and design — mechanics, economy, combat, progression pacing, quest logic, narrative
structure and copy. Not a code review (see `docs/review/devin-review-2026-10-15.md`).
Builds on pass 1 (`docs/review/game-review-2026-10-18.md`); that pass's M/S findings are treated as known
and are only re-listed when still open or when this pass corrects the record.

**Verdict up front.** The game ships a complete, coherent cozy loop: 40 quests, 12-floor boss-gated
dungeon, 10 home tiers, 9 festivals, marriages, and a full mother-story spine (S01–S08) that honours
every hard rule of `DARK_FOREST_STORY_ADDENDUM.md`. The strongest assets remain the mother story and the
Danish-first voice. The main remaining problems are **progression-ordering** (t6 home gate is deeper than
t8/t9), a **winter farming dead-zone**, a handful of **economy traps** (sheep, catnip, cheap-furniture
hygge spam), **ghost as the dominant dungeon race**, and a cluster of **story/copy defects** the first
pass missed (boss-road copy lies about killing, race-select story hooks are ghost-only, Root Scribe still
has no encounter). Nothing here is a ship-blocker for a milestone build; the top five fixes below are
the ones that change how the game *feels* to play.

---

## 1. What this pass adds over pass 1

| Area | Pass 1 | This pass |
|---|---|---|
| Economy | crop ROI table, quest reward traps | animal ROI, fertilizer, hygge decor spam, vendor spread, orphan prices |
| Combat | expected_weapon curve note | weapon-family DPS parity, club-stun dead vs bosses, smithy rotation gate, oil vs gold tax, dungeon-vs-farm income |
| Races | perks match docs | ghost dominance in dungeon, monkey perk obsoleted by gear |
| Story | spine praised; Root Scribe / Lily / weapon-nudge debts | boss-road copy lies, ghost-only race reactions, title retcon, journal `giver` mis-attribution, "Eg" naming slip |
| Pacing | t6 wall, winter | full journey timeline, stall-risk table, season×activity matrix, tutorial gaps, harness blind spots |

---

## 2. Mechanics & economy

### E1 (High) — Sheep is strictly dominated; wool is a money pit
`lua/config/husbandry.lua:35-49,95-109` · `lua/items/products.lua:29-36` · `lua/items/animals.lua:58-64`

| animal | buy | product | gross g/day | verdict |
|---|---|---|---|---|
| chicken | 150 | egg 15 ×1–2 /d | ~22.5 | best ROI |
| cow | 500 | milk 35 ×1–2 /d | ~52.5 | best absolute |
| owl | 800 | wisdom_feather 200 /3d | ~67 | good, rare feed |
| deer | 600 | magic_herb 80 /2d | ~40 | feed cost hurts |
| fox | 750 | lucky_fur 120 /3d | ~40 | slow payback (~50 d) |
| duck | 200 | duck_egg 25 /2d | ~12.5 | ≈ feed cost |
| rabbit | 180 | wool 12 /2d | ~6 | negative vs treats |
| **sheep** | **400** | wool 12 ×1–2 /3d | **~6** | **strictly worse than rabbit** |

Sheep costs 2.2× the rabbit for the same wool/day on a slower interval and needs the barn. Wool crafting
(`lua/recipes/materials.lua:63-69`) turns 3 wool into 1 fabric_wool worth 8 g — never amortizes the
animal. *Fix:* give sheep a wool premium (`wool_fine`, or amount {2,3}) or cut lamb price below rabbit.

### E2 (Medium) — Fertilizer is a dominant, decision-free purchase
`lua/items/crops.lua:156-165` · `lua/config/game_balance.lua:37`
15 g for +1 crop once. Cheapest crop (turnip) turns that into +45 g → **+300 % ROI**. Every plot, every
season should be fertilized; there is no trade-off. *Fix:* scale cost toward the target crop tier, or make
it % yield with variance.

### E3 (Medium) — Catnip is a pure trap crop (extends pass-1 M5)
`lua/items/crops.lua:136-155`
Zero non-gold use anywhere in `lua/` except as a `lost_cat` reward — no gift taste, recipe, or feed.
Worse than strawberry (which is a loved gift for ≥6 NPCs). *Fix:* wire catnip into cat/fox feed or a
loved gift, else drop it from `seed_shop` stock.

Seed ROI (recomputed; `game_balance.lua:48-57` + `crops.lua`):

| crop | days | seed | sell | margin | g/day | note |
|---|---|---|---|---|---|---|
| carrot | 4 | 20 | 65 | +45 | **11.3** | dominates turnip |
| pumpkin | 10 | 60 | 160 | +100 | 10.0 | efteraar only |
| turnip | 4 | 20 | 45 | +25 | 6.3 | starter/quest |
| sunflower | 7 | 30 | 70 | +40 | 5.7 | |
| glow_berry | 10 | 104.5 | 150 | +45.5 | 4.6 | magic-store seeds |
| moonflower | 12 | 120 | 180 | +60 | 5.0 | night watering |
| catnip | 5 | 35 | 55 | +20 | 4.0 | **no utility** |
| strawberry | 4 | 45 | 55 | +10 | **2.5** | loved-gift niche |

### E4 (Low / Design) — Vendor spread is essentially flat
Every shop is buy ×1.0 / sell ×1.0 except magic store buy ×1.1 and lantern house forage sell ×1.25.
No regional selling personality. *Fix:* give 1–2 shops a category bonus (bakery pays +25 % for crops).

### E5 (Medium) — Hygge decor is cheapest via spam-furniture
`lua/config/rarity.lua:21-24` vs `lua/items/furniture.lua:172-175`
Decor/gold: normal furniture ≈ 0.021, rare ≈ 0.007 — a 3× inversion. Hygge kongeligt needs 420 decor
(`home_tiers.lua:378`), optimally ~20 000 g of cheap chairs rather than "furnish beautifully". Gates
home tiers 7–10. *Fix:* make decor scale superlinearly with rarity, or cap decor per furniture type.

### E6 (Low) — Orphan prices / ladder inconsistency
`products.lua:35` wool `buy_price = 30` is dead (no shop stocks wool). Hoe ladder skips copper
(wood 50 → iron 400) while pickaxe has 3 tiers (`tools.lua:88`).

### C1 (Low) — Weapon families are balanced; staff ~10 % behind
`lua/config/dungeon_run.lua:15-21`. Rare-tier DPS: sword 55.0, club 55.6, spear 55.8, dagger 53.8,
**staff 50.0**. Staff's `light_boost` is the compensation but the raw lag is unadvertised. No family
dominates. **Pass.**

### C2 (Medium) — Club's signature stun is null vs every boss
`scripts/combat/weapon_fx.gd:57-58` returns early when `enemy.armor` is true; all three bosses have
`armor = true` (`lua/config/bosses.lua:4-6`). `wpn_club_mushroom` / `wpn_club_thornberry` lose their rare
effect in the three fights that matter most. *Fix:* armor reduces stun duration (e.g. ×0.4) instead of
nulling it.

### C3 (Medium) — Smithy rare-weapon rotation can gate your family for weeks
`lua/shops/smithy.lua:14-18` weekly rotation picks 2 of 5 rare weapons at ×1.1. Expected wait for a
specific family ≈ 2.5 weeks. Enemy HP scales with `expected_weapon`, so a mid weapon at floors 9–12
doubles hit counts. *Fix:* pin one rotating slot to the equipped family, or add a commission craft path.

### C4 (Pass) — Boss math is coherent
Boss HP = hits × expected_weapon[floor] (80 / 176 / 288 at floors 4/8/12). At expected gear: 8 / 11 / 12
swings — tight and readable. Damage ladder 1→2 half-hearts.

### C5 (Design) — Death penalty is cozy-gentle; oil is the real tax
Defeat: 10 % gold, items kept, wake at home. Oil 150 s base, +60 s for 25 g, empty-oil bite every 12 s.
Ghost's `oil_use_mult 0.75` + `dark_light_mult 1.25` makes it ~2× more oil-efficient in the only scarce
resource (see R1).

### C6 (Medium / Design) — Dungeon income outruns farming 2–2.5×
Full dive ≈ 2 200–2 400 g capped (`dungeon_loot.lua:38,43`); a 110-plot carrot field ≈ 1 240 g/day.
Daily loot cap is well-tuned; the farm leg is the weakest earner outside early game.

### F1 (Medium) — House is the pet bottleneck
Four pet species (cat/dog/fox/owl) share `house` capacity **3** (`husbandry.lua:65-169,184-189`), while
the cheapest building (350 g, 1 day) holds the most valuable animals. *Fix:* raise house capacity to 4,
or move owl to barn.

### F2 — Winter dead-zone confirmed (pass 1 M6). No crop lists `vinter` (`game_balance.lua:48-57`).
### F3 (Design) — Water windows: only moonflower is night-gated; `fairy_dust_water` is a luxury sink.

### S1 (Low) — Heart pacing steady; purchase-friendship is decorative
Weekly chat = 1 heart, gifts 2/week, love 40 pts. 8 hearts ≈ 4.4 weeks; engagement ≈ 6 weeks. Fine for
cozy. Purchase-friendship (100 g/pt, 10 pt/wk) is a decorative sink. **Pass** on the core ladder.

### S2 (Pass) — Home gold curve
200→300→900→2 100→4 500→7 500→12 500→19 000→27 000 (+ amethyst/moonstone at t6/t9/t10). Roughly ×1.7/step,
coherent with dungeon gems as the late gate. `unlock_status` all `"real"`.

### R1 (High) — Ghost is the dungeon's dominant race
`lua/config/race_perks.lua:104-106`: run ×0.6, **oil ×0.75**, light ×1.25 — the three levers that matter
in Mørkeskoven. Animal is farm king; hobbit is commerce king; fairy's flight is traversal flavour.
"See in the dark" fantasy correctly belongs to the ghost, but 0.75 oil is a *numeric* advantage, not just
flavour. *Fix:* give other races a dungeon-relevant niche (animal: +node yield; hobbit: cheaper tonics)
or trim ghost to oil ×0.85.

### R2 (Medium) — Monkey's chest_sense is obsoleted by gear
`lua/config/species_perks.lua:30` (700 px) is replicated by `wpn_spear_root` and the emerald lantern gem;
`dungeon_run.gd:71-80` takes the max, never stacks. *Fix:* let monkey sense stack +3 cells over the cap.

### R3 (Pass) — Docs match implementation for race perks.

### FE1 (Pass) — Festival calendar coverage is even (2 per season, 3 in winter).
### FE2 (Low / Design) — Festival rewards are non-monetary and thin
All nine give `attend.points = 20` (0.2 heart) + finale consumables. No gold, no unique item. Festivals
never interact with the money curve — the one place a prize purse would teach goal-setting.

---

## 3. Story & narrative

### Mother story spine — hard rules all honoured (Pass)

| Hard rule | Status | Evidence |
|---|---|---|
| Fate fixed (bittersweet, dead) | **Honoured.** `FM_FINAL_TRUTH` states death plainly; echo-not-prisoner explicit; ghost family cannot retrieve her. | `localization/forest_mother.csv:71` |
| Role refused | **Honoured** (atomically). `record("mother_fate")` sets `role_refused`, `own_name_restored`, `seed_tin_homeward` in one commit. | `scripts/world2d/story/mother_story.gd:57-62` |
| Legacy = seed tin | **Honoured + visual.** `legacy_home` plants seeds; marker spawns moonflowers + `mother_seed_tin` prop. | `mother_evidence_marker.gd:20-40` |

S03–S08 exist as quests with versioned evidence, journal epistemic tiers (seen/memory/witness/remembered/
confirmed), out-of-order-safe `can_read` gates, and boss catch-up without re-farming. Natteblik's witness
beats are night-gated with retry language. Kin continuity (`DLG_GHOSTFAM_DYNE_KIN_1_4` / `SILKE_KIN_1_1`)
matches the addendum. **This remains the strongest part of the game.**

Pass-1 debt "secret garden payoff is letter-text only" is **partially retired**: S08 `legacy_home` now has
a planted-garden return scene with props. Remaining gap is the Root Scribe (below).

### S-A (High) — Root Scribe still has no encounter *(open from pass 1)*
`scripts/world2d/story/mother_evidence_marker.gd:52-53,67` · `localization/forest_mother.csv:70-72`
S08's "bargain" is three text lines in an evidence marker; refusal is one button. No speaker, no scene, no
presence beyond a `root_scribe_waymarker` prop. The climax reads as reading a letter. *Fix:* one short
authored clearing beat (roots framing the page) before the text, even unvoiced.

### S-B (High) — `bossernes_vej` copy lies about killing *(missed by pass 1)*
`lua/quests/bossernes_vej.lua:7-28` · `localization/dungeon_services.csv:47-49`
Objectives say **"Mød Snurresvampen"** (Meet…) but `on = enemy_defeated`. Kids are told to *meet*
guardians and must *kill* them. Tonal break + trust break in a kids' game. *Fix:* retitle to
"Besejr/Overvind", or reframe the quest as "find out what they guard" with defeat as the means.

### S-C (High) — Race-select story hooks are ghost-only *(missed by pass 1)*
`lua/config/race_reactions.lua:4-16` · `scripts/.../race_reactions.gd:12`
Only `ghost` has a first-meet table (9 NPCs); flag hardcodes `ghost_met_*`. Animal / fairy / hobbit get
zero story-reception differentiation beyond `FM_FAMILY_FRIEND`. Choosing them is cosmetic for story.
*Fix:* 2–3 first-meet lines per race, or state in character select that ghost is the reactive species.

### S-D (Medium) — Draft/runtime title retcon (S07, S08)
`docs/design/dark-forest-story/copy.csv:20,23` vs `localization/forest_mother.csv:28-29`
Draft still ships `QUEST_FOREST_MOTHER_S07_TITLE = Bag det sidste lys`, `S08 = Hvad der skete med mor`;
runtime uses `FM_CHAPTER_S07 = Hinsides det sidste lys`, `S08 = Det vi bærer hjem`. Two "canonical" titles.
*Fix:* sync copy.csv to runtime keys or mark it superseded.

### S-E (Medium) — `chapters.json` S01/S02 `copy_keys` are orphaned
`docs/design/dark-forest-story/chapters.json:47-70` points at `QUEST_FOREST_MOTHER_S01/02_*` keys that
exist only in draft `copy.csv`, never in `localization/`. S01–S02 actually play as `secret_garden` with
`QUEST_SECRET_GARDEN_*` keys. *Fix:* repoint S01/S02 copy_keys at `secret_garden.csv`.

### S-F (Medium) — All mother chapters list `giver = "postman_pip"`
Including S08's floor-12 finale. Pip never offers them (MotherStory auto-accepts). Journal mis-attributes
the climax. *Fix:* `giver = "mor"`/self, or route display through the trail book.

### S-G (Medium) — Child NPC commissions deep-dungeon errand *(pass 1 debt, re-framed)*
`rare_mushroom_hunt` giver `fairy_lily` (`role = "child"`) sends the player to Mushroom Grove floor 7 for
a sick friend's medicine. *Fix:* re-giver to an adult (Birk/Ugle), or keep Lily as requester with an adult
escort line.

### S-H (Medium) — Naming slip: "Tal med Eg"
`dungeon_services.csv:50`. STYLE_SHEET R4 mandates "Vagten Oak" and bans stale names. *Fix:* "Vagten Oak".

### S-I (Low) — `FM_FINAL_BARGAIN` narrates the refusal before the button
Text already describes the refusal; the click confirms prose. Acceptable under the hard rule, but the
choice reads illusory. *Fix:* keep text conditional ("If you take the title…") until after the click.

### S-J (Low) — S04 evidence load (5 items) vs S05 (1) and S07 (1)
Uneven chapter weight. *Fix:* add a second S05 object (a name board) or split S04.

### S-K (Low) — `flower_necklace` over-specifies origin
Says "vilde skovblomster" but `wild_flower` is a generic `flower_patch` yield. *Fix:* "vilde blomster".

### S-L (Design) — Most town dialogue is static post-intro
`mayor_lyra` returns the same two lines forever; `fairy_lily` is one line despite two quests. Contrast:
`baker_maja` branches on math state, `mapseller_natteblik` on hour, `cat_morfar_mis` on zone. The world is
least alive where it matters most (quest givers).

### Voice & writing quality (Pass)
Danish is warm, du-form, kid-safe (STYLE R1–R3 respected in sampled rows). English fallbacks carry equal
meaning and warmth. Distinctiveness is strong for Dyne, Gnist, Natteblik, Mis. Dark-forest register is
cosy-strange, not scary — consistent for kids. Mother-death material is the only heavy beat and is handled
in echo-framing. Voice remains hooks-only (`_voiced_social.lua` indexes 69 keys with no recordings).

### Quest arc map

| Arc | Quests | Narrative purpose |
|---|---|---|
| Intro/tutorial | `intro_lottery`, `forste_dage`, `skovlift_intro`, `lost_cat` | Real |
| Farm errands | `first_animal`, `animal_products`, `fix_roof`, `cookie_delivery`, `birthday_cake`, `supply_run` | Thin but giver-voiced; `supply_run` is pure fill |
| Fairy-city help | `fairy_friendship`, `moonstone_crown`, `enchanted_garden`, `flower_necklace`, `slotsdroemmen`, `bogtraeet` | `slotsdroemmen`/`bogtraeet` carry the dream tone |
| Dungeon | `dark_forest_mining`, `crystal_cave`, `night_flower`, `bossernes_vej`, `snurresvampen`, `sword_upgrade`, `ugles_noegle`, `rune_vandring`, `rare_mushroom_hunt` | Boss-road frame (S-B); no weapon-upgrade nudge before f4 |
| Ghost family | `ghostfam_garn`, `ghostfam_hittegods`, `ghostfam_lygtemager` | Warm, consistent |
| Math/education | `math_bakery_counts`, `math_harvest_puzzle`, `math_wizard_quiz` | Real learning framing |
| Mother story | `secret_garden`, `forest_mother_s03–s08` | The spine |

---

## 4. Progression pacing

### Journey timeline (estimates)

| Stage (est.) | MUST do | CAN do | Gold / gates |
|---|---|---|---|
| Day 1, h06 | `intro_lottery` + `forste_dage` auto-accepted | explore Trætoppen | start 500 g +250 +150 |
| Days 2–5 | farm loop; expand hint at g≥800 d3 | town errands, math quests | t2: 200 g + `intro_lottery` |
| Days 3–8 | `skovlift_intro` (enter, runestone, extract) | repeatable forest quests after first dive | t3: 300 g; dungeon opens |
| Days 5–15 | t4 (lyra hearts 2); `first_animal` for t5 | husbandry, festivals d7/d21 | t4 900 g, t5 2 100 g |
| Days 10–25 | **t6 wall**: `crystal_cave` = 5 shards + enter floors 10–12 | mushroom grove f7–9; mother S03–S04 | t6 4 500 g + amethyst×2 |
| Days 15–35 | t7 triple gate: `fairy_friendship` + lyra 4 + hygge 2 | weddings, ghostfam quests | t7 7 500 g |
| Days 20–40 | t8: floor-4 boss quest + hygge 3 | mother S05 (boss f8) | t8 12 500 g |
| Days 25–50 | t9: `moonstone_crown` | mother S06 | t9 19 000 g |
| Days 30–60+ | t10: lyra 8 + fairy_king 2 + hygge 4 | mother S07–S08 | t10 27 000 g; cum. ~74 k |
| Endgame | `slotsdroemmen` (t10, 6 treasures, hygge 5, festival held) | marriages, set capstones, f12 loot farm | 6 000 g + legendary gifts |

### Stall-risk table

| Risk | Severity | Evidence |
|---|---|---|
| t6 `crystal_cave` (f10–12) deeper than t8/t9 | **Critical** | `home_tiers.lua:204` vs `:282,:319`; `dungeon.lua:87` |
| Winter 28 d with 0 plantable crops | **High** | `game_balance.lua:49-56,84` |
| Floor-8 `snurresvamp_gloed` / f12 `snurresvamp_konge` boss walls on mother S05/S07 | **High** | `dungeon.lua:286-287,384-385` |
| Hygge 3/4 = 110/240 decor vs furniture_capacity 38–57 at t6–t8 | **High** | `home_tiers.lua:246,257,375-376` |
| t7 triple gate (quest + hearts 4 + hygge 2) | **Med** | `home_tiers.lua:241-245` |
| t10 lyra=8; fairy_king=2 only via t9 quest reward | **Med** | `home_tiers.lua:357`; `moonstone_crown.lua:29` |
| ghostfam hearts≥2/3/4 via slow seek ladder | **Med** | `ghostfam_seek.lua:26-29` |
| 7 quests share `requires_zone="dark_forest"` — all die until first dive | **Med** | 7 quest files |
| Festival dependence for `slotsdroemmen` (`festival` unlock only at t8) | **Low** | `slotsdroemmen.lua:29-32` |

### Season × activity matrix

| Season | Farm | Dungeon | Social | Festivals | Quests | Home |
|---|---|---|---|---|---|---|
| foraar | turnip/carrot/strawberry/catnip | f1–12 | full | blomsterfesten d7, honningdagen d21 | full | full |
| sommer | + moonflower/glow_berry/sunflower | f1–12 | full | midsommerlanterner d14, badenedagen d27 | full | full |
| efteraar | carrot/pumpkin/moonflower/glow_berry/sunflower | f1–12 | full | hoestfesten d14, maanemarkedet d27 | full | full |
| **vinter** | **NONE** | f1–12 | full | vinterlysene d7, bagedagen d21, aarsskiftet d28 | full | full |

### Tutorial / onboarding gaps (target: 10-year-old)
**Taught:** till/plant/water/harvest/mail; bin=shipping, energy, bed, bridge, expand; dungeon
enter/runestone/extract. **Missing:** combat, gifts & friendship, home-upgrade flow, festivals (first is
day 7 with zero prep), weapon readiness before floor-4 boss, "nothing grows in winter" explanation.

### Playtest harness blind spots
`tests/sections/home_progression.gd:10-12` cheats all gates in (`Grant.requirements`) then checks payment
mechanics only. `tests/sections/quests.gd` feeds synthetic signals per objective (completability, not
order/reachability). No seasonal calendar run, no gold-accumulation curve, no zone-before-quest
reachability, no boss-difficulty wall detection. `tests/lib/known_issues.txt` can mask regressions without
`--strict`.

---

## 5. Prior-pass record (updated)

| Pass-1 finding | Status now |
|---|---|
| M1 t6 gate non-monotone | **Still open** — confirmed authored; remains the Critical pacing issue |
| M2 dead `fish` item | **Fixed** (pass 1) |
| M3 ghost infinite sprint | **Retracted** (pass 1) |
| M4 stamina decorative | **Still open** — design choice |
| M5 dominated crops | **Still open** — + catnip has zero utility (E3) |
| M6 winter dead-zone | **Still open** |
| M7 quest rewards < vendor | **Fixed** (cookie_delivery); others re-classified |
| M8 buyable adventure collects | **Still open** — design question |
| M9 rare_mushroom_hunt gate | **Fixed** (pass 1); story wart remains (S-G) |
| S1 spine complete | **Confirmed** |
| S5 Root Scribe text-only | **Still open** (S-A) |
| S5 voice hooks only | **Still open** |
| S5 secret garden payoff thin | **Partially retired** — S08 return scene now exists |
| S5 no weapon-upgrade nudge | **Still open** |

---

## 6. Top fixes (priority order)

1. **Make home gates monotone in dungeon depth.** Swap t6↔t8 quest gates (t6=`snurresvampen`,
   t8=`crystal_cave`) or replace t6's `crystal_cave` with `dark_forest_mining`/`night_flower`.
   `lua/data/home_tiers.lua:204,282`.
2. **Fill winter.** Add 1–2 `vinter` crops and/or the greenhouse plot; alternatively a winter-only
   forage/craft loop. `lua/config/game_balance.lua:48-56`.
3. **Fix the boss-road copy lie** and the "Eg" naming slip. `bossernes_vej` objectives say "Mød" and
   require kills; `dungeon_services.csv:50` says "Eg". These are cheap, high-trust fixes.
4. **Pre-boss weapon nudge.** Auto-offer/track `sword_upgrade` in `bossernes_vej`, or a forced Oak line
   before floor 4. `lua/quests/sword_upgrade.lua`, `lua/config/dungeon.lua:179`.
5. **Soften the t10 friendship wall** and **give non-ghost races story reception** (or own the ghost-only
   framing). `moonstone_crown.lua:29`, `home_tiers.lua:357`, `race_reactions.lua`.

Runners-up: sheep/wool ROI (E1), club-stun vs bosses (C2), hygge decor spam (E5), Root Scribe encounter
(S-A), catnip utility (E3), ghost oil trim (R1), town dialogue branching (S-L).

---

## 7. Not reviewed

Save/robustness internals (code review's scope), art pipeline, voice production, localization completeness
beyond quest-relevant CSVs, and the balance sim's assumed-income caveat (a model, not a playtest — but a
good model whose numbers are consistent with the data).
