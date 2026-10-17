# Game mechanics and story review

Reviewed 17 October 2026. Base: `abec447` on `main`. Branch/worktree: `game-mechanics` / `../PongPong-worktrees/game-mechanics`.

Follow-up: [implemented fixes and current verification](../qa/game-mechanics/fixes/README.md). The review below preserves its original findings against `abec447`.

The farm, towns, home progression and missing-mother story have working implementations. The most important defect found in this pass is that dungeon generation can silently omit an essential story witness. Husbandry also rewards keeping completely unfed animals happy, and sells a milking tool with no gameplay function. The larger design gap is that the forest describes restoration, recovering names and interpreting memories, but implements these principally as reading and confirming pages.

This is a review with reproducible observations and recommendations. It changes no game code, balance, story copy or assets. Findings distinguish defects from authored decisions; there is no demonstrated permanent progression deadlock in this pass. Evidence and rerun instructions are in [the QA record](../qa/game-mechanics/README.md).

## Findings, in priority order

### GM-01 · P1 · An essential witness can be omitted by generation

**Defect.** Natteblik supplies both `map_account` and `route_witness`. The floor tables request a `hulen_keeper` on floors 2, 6 and 10, but the [anchor placement loop](../../scripts/dungeon/gen/dungeon_gen.gd#L1035) stops after eight attempts without reporting failure if it found no location. The independent verifier checks exact supplies for designated resource nodes, but has no equivalent requirement for this witness ([verification](../../scripts/dungeon/gen/dungeon_verify.gd#L211)).

The fixed sample `DungeonRng.hash_key("mechanics-review", 36, 10)` gives seed **`3275138988032679373`**. Its floor 10 builds successfully with **zero keepers**, and the existing independent verifier accepts it. One of 120 sampled layouts omitted the keeper; this sample is evidence of existence, not a reliable estimate of player frequency. [Exact observations](../qa/game-mechanics/story-anchors.json), [exported map](../qa/game-mechanics/missing-witness.map).

The first native story run separately found no floor-2 keeper and crashed at the test's unguarded `[0]` lookup ([retained failed result](../qa/game-mechanics/native-first.json)). A second native run passed. The original native world seed was not retained, so the fixed floor-10 case establishes the underlying generation defect independently, rather than identifying that original layout exactly.

**Impact:** a player can follow the correct journal lead at the correct hour and find nobody there. Another designated floor or a new day's layout may work; neither is a satisfactory explanation for the missing witness.

**Recommended change:** reserve space for required witnesses before optional decoration, reject/retry layouts that omit them, and verify their presence and interaction reachability independently. Pin this seed in a regression test. Guard the native test's lookup so a missing witness produces a useful failed assertion instead of aborting the remaining story checks. Preserve the free witness topic and daytime-to-night retry behavior.

### GM-02 · P2 · Food is unnecessary for productive husbandry

**Rules defect.** [Production](../../scripts/farm/animal_husbandry.gd#L676) requires adulthood, happiness >=30 and an empty product buffer, with no food requirement. Empty fullness increases happiness decay, but free daily [brushing and play](../../scripts/farm/animal_husbandry.gd#L461) restore **25 happiness**. Even a hungry chicken loses only 12 per day. It therefore remains happy enough for production and the extra happy-animal product.

The review probe pays for a coop, adopts a normal chick, then brushes, plays and collects through 30 mornings without ever feeding. The saved seeded run produced **70 eggs, 65 at zero fullness**, with `last_fed_day = 0`. No animal fields were edited to force this result. [Full daily trace](../qa/game-mechanics/runtime-data.json).

**Impact:** the most economical care routine ignores the food meter and the feed shop. This weakens the farming loop and teaches the opposite of the UI's care instructions.

**Recommended change:** decide an explicit, gentle food rule before tuning profits: for example, food reserves enable production while brushing/play improve happiness and yield. Do not add death or irreversible punishment. Then rebalance feed costs and add a multi-day empty-food regression; the existing fed-animal tests do not exercise this case.

### GM-03 · P2 · The milking pail is a paid tool with no action

**Defect / misleading purchase.** Rosa [stocks the pail](../../lua/shops/animal_store.lua#L29) for **60g**. Its [definition](../../lua/items/animals.lua#L131) calls it a tool of type `pail`, but [tool execution](../../scripts/world2d/player_2d.gd#L348) has no pail action. The animal-care Collect button calls `collect_product` directly, which never checks ownership of the pail.

The probe adopted and matured a calf through normal APIs and collected **5 milk with zero pails owned**. The item's description also mentions goats, which are absent from the ten-species catalog ([copy](../../localization/da.csv#L88)).

**Recommended change:** connect the pail to a clear cow interaction, or remove its sale and describe collecting as the supported action. Avoid keeping a purchasable inert tool with an unqualified functional description. This differs from the fishing rod, whose deliberately closed status is explained on use.

### GM-04 · P2 · “Meet the guardians” actually requires killing them

**Objective/copy defect.** Both languages say “Meet” / “Mød” ([copy](../../localization/dungeon_services.csv#L47)). All three [quest objectives](../../lua/quests/bossernes_vej.lua#L6) listen to `enemy_defeated`, not an encounter, conversation or arrival. Meeting a living boss cannot satisfy the instruction.

The quest also counts new defeat events after acceptance, rather than projecting permanent boss-clear flags as the mother story does. Someone accepting it after earlier boss victories must repeat those fights. Bosses can return on later days, so this is backtracking, not a permanent block.

**Recommended change:** choose whether this quest asks for encounters or victories, state that plainly in both languages, and make its treatment of earlier victories explicit. If it means lifetime victories, use the persistent boss owner for catch-up rather than duplicating a competing history.

### GM-05 · P2 · The forest's distinctive story mechanics are mostly narrated

**Design implementation gap.** The [story direction](../design/DARK_FOREST_STORY_ADDENDUM.md#how-the-forest-behaves) describes a repaired lamp revealing a path, a remembered house, recovering a traveller's identity and interpreting a damaged route stone. The runtime [places props near a procedural route](../../scripts/world2d/story/mother_director.gd#L108), then uses the same [read/confirm/record interaction](../../scripts/world2d/story/mother_evidence_marker.gd#L64) for these discoveries.

S04 has four inspectable memories and a free owl account. There is no lamp-restoration action or room state to change. Iva's release and matching the stone are statements in a page. The Root Scribe now **does** speak in S05 and the finale; the older “no encounter” finding is obsolete. Its presence is a waymarker and halo with dialogue, rather than a staged confrontation with a changing scene. [Native memory scene](../qa/game-mechanics/native/forest_mother_memory_clearing.png), [final-account scene](../qa/game-mechanics/native/forest_mother_mother_final_account.png).

**Impact:** exploration and bosses provide mechanical variety, while most investigation asks the player to perform the same confirmation. The connection between caring for a garden and undoing the forest's fixed stories remains mainly verbal.

**Recommended change:** add one short, retryable act of care per band: restore the lamp to expose a visual route; put Iva's account beside the imposed title and visibly release it; align a stone with an already recorded map. Reuse skills and visual language taught in the garden. Keep clues free, preserve discovered evidence, and avoid perfect-memory answers or one-attempt choices. Preserve the chosen bittersweet ending; it does not need an alternate alive/dead outcome.

### GM-06 · P2 · The personal reason for the journey arrives too late

**Narrative onboarding gap.** The [first morning](../../lua/farm/farm_tutorial.lua#L18) introduces the farm lottery and farming. The [king's letter](../../localization/dialogue.csv#L21) never establishes the missing mother. The garden offer is a neighbour's restoration request; its journal description introduces the personal search. Ghost heroes can also learn the family relationship in a later kin conversation, while other heroes get the friend framing.

All four character families can complete the implemented story in the focused tests. The issue is motivation and discoverability, not missing access for non-ghost heroes.

**Recommended change:** give every hero a brief, common opening reason to be here and one concrete lead to Pip or the garden. Keep the farm lottery and ghost-specific family relationships. Let the garden be a hopeful first action in an established search, instead of relying on an optional errand description to explain the premise.

### GM-07 · P2 · Sheep investment has little payoff

**Balance issue.** At happiness >=80, [collection adds one product](../../scripts/farm/animal_husbandry.gd#L523). Including that modifier, rabbits average **2 wool / 2 days = 12g/day**, while sheep average **2.5 wool / 3 days = 10g/day**. Lambs cost **400g**, versus **180g** for rabbits, mature in six days versus two, and require a barn rather than a coop.

These are mature gross figures, not net ROI. If feeding every second day with 25g treats sustains the play/brush routine's 15 fullness/day consumption, feed alone averages 12.5g/day: neither wool animal supports that routine from raw wool sales. Current food bypass makes that cost optional, which is why GM-02 must be resolved first. Wool also has crafting value; sale price does not describe its full utility. Barn and coop slots differ, so “strictly dominated in every situation” would overstate the result.

**Recommended change:** give sheep a clear textile identity—more wool or a valuable sheep-specific output—and price the whole care loop after fixing food. Keep animals desirable for companionship and crafting as well as gold.

### GM-08 · P3 · Every forest chapter is presented as Pip's assignment

**Journal metadata defect.** All six `forest_mother_s03`–`s08` definitions use `meta.giver = "postman_pip"` ([example](../../lua/quests/forest_mother_s03.lua#L13)). The [quest journal](../../scripts/ui/quest_journal.gd#L127) renders this name and portrait even for self-directed discoveries and the final revelation. Pip is a helpful archivist, not the source of each action. The separate evidence tab has better next-lead guidance.

**Recommended change:** support an investigation/source label for these chapters, or deliberately choose the actual supporting witness. Keep auto-acceptance and ordered chapter projection; this does not require making the player report to a quest giver.

### GM-09 · P3 · The advertised Collection key has no screen

**Controls/documentation defect.** [Playing instructions](../PLAYING.md#controls-and-equipment) advertise **C**. The input action exists, but `scenes/ui/samlerbog.tscn` does not. [GameUI](../../scripts/ui/game_ui.gd#L38) intentionally loads only present screens, and pressing Collection opens no modal in the probe.

The design explicitly calls this feature optional. **Recommended change:** remove its advertised control until the feature ships, or complete the optional screen as a separately scoped task. This is not evidence that mandatory progression is missing.

### GM-10 · P3 · Out-of-order evidence uses in-order conclusions

**Narrative sequencing defect.** [Evidence eligibility](../../scripts/world2d/story/mother_story.gd#L48) deliberately permits most discoveries out of order; the existing test explicitly protects that behavior. Someone who explored deep floors before starting the garden can read `last_journey` while S03 is still open. Its [copy](../../localization/forest_mother.csv#L65) nevertheless declares that the last map pieces fit together, before those pieces need exist in the record.

**Recommended change:** retain exploration freedom and catch-up, but use a standalone observation until the supporting evidence exists, then expose the assembled interpretation in the journal. Do not solve this by discarding early discoveries or replaying rewards.

## Balance and progression assessment

The runtime export contains **435 items, 18 shops, 136 recipes, 11 crops and 10 animal species**. There are 40 quest files, ten home tiers and nine fixed festivals. Counts describe the catalog, not proof that every possible interaction has been played manually.

The updated crop comparison below plants on season day 1, uses the correct watering window, harvests/replants immediately and sells through day 28: **27 overnight growth ticks**. It assumes one crop per harvest, no race bonus, no discounts and sufficient supplies. Net deducts seeds; the fertilized case also reapplies 15g fertilizer at every harvest. It excludes labour, travel, machine/tool purchases, store stock constraints and the value of plants carried into another allowed season. [Reproducible calculation and full machine/animal tables](../qa/game-mechanics/balance.json).

| Crop | First growth / regrowth | Seed | Harvests | Raw season net | Fertilized season net |
|---|---:|---:|---:|---:|---:|
| Turnip | 4 / — | 20 | 6 | 150 | 330 |
| Carrot | 4 / — | 20 | 6 | 270 | 570 |
| Strawberry | 4 / 4 | 45 | 6 | 285 | 525 |
| Catnip | 5 / — | 35 | 5 | 100 | 300 |
| Sunflower | 7 / — | 30 | 3 | 120 | 285 |
| Pumpkin | 10 / — | 60 | 2 | 200 | 490 |
| Glow berry | 10 / 4 | 105 | 5 | 645 | 1,320 |
| Moonflower | 12 / — | 120 | 2 | 120 | 450 |
| Frost kale | 4 / — | 30 | 6 | 180 | 450 |
| Snow turnip* | 5 / — | 25 | 5 | 275 | 600 |
| Snowdrop* | 7 / — | 40 | 3 | 210 | 495 |

*Snow turnip and snowdrop seeds currently come from the greenhouse shelf; these are not opening-winter shop alternatives. Glow berry uses the ordinary magic-store price of 105g; greenhouse seeds cost 95g. Different seasonal availability prevents treating the entire table as one simultaneous choice.*

Strawberries are no longer a low-return one-use crop. Glow berries now provide a strong long-term investment, and winter has a normal seed-shop crop. Catnip remains weak for raw income and has no cat-feed or special gift niche found in this audit, but **does** have preserves and juice; “zero utility” is outdated. Fertilizer gives a guaranteed additional crop worth 45–180g for 15g, so is generally a profitable default once affordable. Its 30/day shop restock and application work are real constraints; it is not an unlimited free bonus. Consider quality, soil longevity or a distinctive catnip use before simply raising all prices.

Processing offers a useful throughput choice. A carrot jar adds **57.5g per machine-day**, versus **43.3g** for a keg, after deducting the raw carrot's sale value. At moonflower values the keg narrowly leads, **120g versus 115g**. Comparing only the final bottle price would miss this. Sprinklers, machines and the twelve-bed greenhouse now provide actual labour and seasonal progression. The base-price scan found no direct buy/resell or deterministic buy/craft/sell profit candidates; this is not a claim about every discount, rotation, festival date or random Hobbit baking bonus.

The **tier-6 house gate remains deliberately non-monotone**: `crystal_cave` requires floors 10–12, while tier 8 asks for the floor-4 boss quest and tier 9 asks for moonstone available earlier. This couples a substantial portion of cozy home progression to defeating the first two bosses. The data and gate copy agree, so it is an authored pacing choice, not an accidental circular dependency. [Gate data](../../lua/data/home_tiers.lua#L204), [cave objective](../../lua/quests/crystal_cave.lua#L27). Playtest with someone who prioritizes farming before changing it; alternatives include a shallower architectural-material commission or a clearly explained parallel route. The progression test uses `Grant.requirements(tier)` and proves payment, construction and persistence, **not** an unassisted journey through those requirements.

Combat has five family profiles, persistent boss rewards and configurable assistance. The focused owner tests passed their damage, oil, reward and save contracts. Club stun is suppressed against `armor` and every boss is armored; make that exemption visible in effect descriptions before treating it as a balance defect. Ghost oil savings are advantageous, but the earlier categorical “dominant race” finding is not established by fresh comparative combat play here. Stamina has a one-second post-use regeneration delay and regenerates only while free and neither running nor flying; older calculations that assume immediate regeneration or regeneration during sprint should not guide tuning. Hoe/can upgrades chiefly reduce energy costs; their descriptions state that correctly. Whether that reward is satisfying beside sprinklers needs a player test, not a bug label.

Social progression deliberately gives one heart for the first completed conversation each week and does not decay. Its focused simulation tests passed, including citizen availability; those simulations are useful bounds, not measurements of a child's full play session. The writing has room for more personality: 25 citizens share each of two exact bark lines (“A quiet moment.” and “Someone is passing by.”). Give the core town cast distinct observations and a few meaningful reactions to the garden, major discoveries and homecoming before adding more generic dialogue volume.

## Story assessment

The two arcs fit together through care, hospitality and a place to return to. The garden's overnight flowering makes restoration visible before the forest asks us to interpret preserved memories. Mother sought routes out for people reduced to roles; her own signature becomes the counterpoint to the imposed Keeper title. The ending explicitly establishes her death, distinguishes the echo from a living prisoner, rejects inheriting the role and plants her seeds in a place that remains playable. The native homecoming shows the tin and flowers, and the save/rebuild test preserves them. [Homecoming](../qa/game-mechanics/native/forest_mother_legacy_garden.png).

Keep that ending. Its strength is a clear answer followed by a hopeful action, rather than another unresolved disappearance. The next writing pass should make its personal details more concrete: the memories currently tell us much about what Mother represents and less about her particular habits, humour or flaws. Her own signature is discussed but never given a readable personal name in the reviewed garden/forest copy. That can remain an intentional choice, but it makes reclaiming a person's name more abstract than Iva's named example. Choose deliberately how to show the signature and add two or three details that belong specifically to her.

The current structure is mechanically safe in several important ways: evidence is independent of backpack capacity and regenerated dungeon cells; the owl account has a free written fallback; previous boss victories count for the mother chapters; cancellation records nothing; chapters catch up in order; and the completed story leaves ordinary forest play available. These behaviors passed the focused tests and should survive any richer encounter design. S04 carries five evidence requirements, while S05 and S07 each have one plus a boss checkpoint. Additional puzzles should improve variation rather than merely add more pages to the busiest chapter.

## What this review supersedes and what remains unproven

The earlier reviews dated 18 October were based on older commits. Preserve them as history, but do not use their following statements as current acceptance criteria:

| Earlier claim | Current observation |
|---|---|
| Greenhouse unimplemented; winter has no crops | Greenhouse is usable; three winter crop definitions exist, with the seed-access distinction above. |
| Strawberries and glow berries do not regrow | Both regrow every four watered nights. |
| Root Scribe has no encounter | Speaking marker encounters exist; richer staged interaction remains a design gap. |
| Fish feed reference cannot be obtained | The dangling diets were replaced with existing items. |
| Cookie-delivery reward is below its earlier quoted value | Reward is now 500g. |
| Collection screen ships | Its screen file is absent; the feature is optional. |
| Animal gross yield equals the configured random amount alone | Happy collection adds one product, changing both yield and comparisons. |
| Catnip has no use | It has generic processing outputs, although no distinctive niche was found. |
| Dungeon income beats the farm by a fixed multiplier | Not re-established after farm automation, processing and regrowth changes. |

Fresh coverage includes seven baseline sections, nine additional system sections, garden/forest story checks for all four character families, a native animal-hero story run, catalog calculations and the deterministic generation probe. All passing suites report zero skips and no unexpected engine messages. **The first native story run failed and is retained**, not converted into a green result by the successful retry. Observation-probe passes mean defects were reproduced; they are not product acceptance.

This was not a fresh save-to-finale manual playthrough, a full suite rerun, a new all-race combat tournament, a complete native controller audit, or an art/performance review. Several story tests grant progression and invoke the real boss-state owner rather than winning fights. Existing broader QA remains useful, but cannot substitute for an ordinary player's combined farm/social/story journey.

Address GM-01 first, then settle the food rule and inert pail, then align guardian objectives. The next substantial design work should turn the garden's acts of care into playable forest investigation while preserving the safe, persistent story state and chosen finale.
