# Game mechanics & story review — 18 October 2026

Reviewed commit: `268bb6a` (main). Worktree and branch: `../PongPong-worktrees/game-review`, `game-review`.
This is a *content and design* review — mechanics, economy, pacing, quest logic, narrative structure, and
copy — not a code review (for that see `docs/review/devin-review-2026-10-15.md`). All findings cite the
data/source location. The harness is green on the baseline (`run_playtest.sh --only=core`: 122 checks, 0 failures).

**Verdict up front:** the game is far more complete than the design docs' "pending wave" framing suggests —
40 quests, ~30 citizens with routines and dialogue, a 12-floor boss-gated dungeon, 10-tier home progression,
9 festivals, marriages, birthdays, a full social engine, and the entire mother-story spine (S01–S08) are
implemented, localized in da+en, and wired into the world. The main issues are a small number of
progression-ordering anomalies, a dominated crop table, a few quest rewards priced below vendor value, a
dead `fish` item reference, and seasonal content asymmetry (winter).

---

## 1. Content inventory (what actually ships)

| System | State | Evidence |
|---|---|---|
| Farm loop (till/plant/water/harvest/sell) | live | `farm_grid.gd`, `crops` table (8 crops), `seed_shop` |
| Animal husbandry | live | `husbandry.lua` (10 species, 3 buildings), `animal_yard`, `placement_service` |
| Shops | 9 live + rotations | `lua/shops/*` (seed, bakery, smithy w/ weapon rotation, animal, magic, lantern, timber, home×4, festival markets) |
| Quests | 40 defined, all reachable | `lua/quests/*`; offering is generic (`QuestManager.offerable(giver)` + `quests_offered` in `npcs.lua`) |
| Dungeon | live, 12 generated floors | `dungeon_floors.gd`, `dungeon_gen.gd`, `dungeon.lua` (4 bands, 3 bosses at floors 4/8/12, runestones, oil) |
| Combat | live | `player_2d.gd`, `enemies.lua` (7 kinds), `bosses.lua`, weapon families in `dungeon_run.lua` |
| Home upgrades | live, 10 tiers | `home_tiers.lua`, `home_manager.gd` (feast emits `festival_held`) |
| Social | live | `social.lua` (hearts/gifts/purchase/festival points, 6 stages, marriage stages hjertven/forlovet/gift) |
| Festivals | live | `festival_director.gd`, `festival_decor.lua` (9 named festivals), `festivals.csv` |
| Mother story | live, S03–S08 + journal | `mother_story.gd`, `mother_evidence_marker.gd`, `mother_journal.gd` (journal tab 3), `forest_mother.csv` (102 keys) |
| Secret Garden | live, 12-step quest | `secret_garden_story.gd`, `secret_garden.map` |
| Ghost family | live | `ghostfam_*` dialogue/quests (kin recognition for ghost heroes, evening shop, midnight stories, hide-and-seek) |
| Screens | all shipped | `scenes/ui/*`: 30+ `.tscn` incl. `appraisal_ui`, `gift_ui`, `samlerbog`, `garderobe`, `rune_picker` |
| Fishing | **closed on purpose** | `player_2d.gd:308` whispers `WHISPER_FISHING_CLOSED` |
| Greenhouse | **not implemented** | `greenhouse_slot` marker exists (`farm.map:47`); `marker_handlers.lua` notes it waits for N07 |

---

## 2. Mechanics & economy findings

### M1. Home-tier gate ordering is non-monotone in difficulty — the mid-tier wall
`lua/data/home_tiers.lua` gates: t2 `intro_lottery`; t4 `friendship mayor_lyra:2`; t5 `first_animal`; **t6
`crystal_cave`**; t7 `fairy_friendship`+hygge 2; t8 `snurresvampen`+hygge 3; t9 `moonstone_crown`+hygge 3;
t10 `mayor_lyra:8` + `fairy_king:2` + hygge 4.

`crystal_cave`'s `explore_cave` objective requires `zone_entered(crystal_cave)` — floors **10–12** of the
dungeon (`dungeon.lua:79-87`), which means defeating the floor-4 *and* floor-8 bosses first. But t8's gate
`snurresvampen` only requires the floor-4 boss, and t9's `moonstone_crown` needs only floor ~6 moonstone.
**Tier 6 requires deeper progression than tiers 8–9.** A player who stalls at the floor-8 boss
(`snurresvamp_gloed`, 176 hp) is hard-capped at home tier 5 no matter how rich they are — while a player who
rushes combat skips ahead.

*Post-review check:* this ordering is **authored, not accidental** — the t6 gate copy narrates it
(`HOME_TIER_6_GATE`: "Spiret skal have ametyst … Krystalgrotten") and validator rule S13 pins
"snurresvampen gates tier 8, moonstone_crown tier 9". Downgraded to a *design note*: if the deep-gate
ever proves too steep in playtest, `explore_cave` could move to a shallower band rather than swapping
tier gates. Left as designed.

### M2. `fish` is a dead item reference — favorite-feed bonuses unreachable
`husbandry.lua:73,88,148`: cat/dog/fox list `feed_types`/`favorite_feed` including `"fish"`. **No `fish`
item exists** — not in `lua/items/*`, loot tables, resource nodes, or shops. Consequences:
- cat's only non-treat feed and favorite, and fox's favorite, were `fish` — unobtainable, so the
  `favorite_feed_bonus` (25 happiness) could never be reached for either;
- any feed UI iterating `feed_types` may offer a nonexistent item.

**Fixed** (`husbandry.lua` + the `species_data` fallback table in `animal_husbandry.gd`): cat feeds on
`animal_treats`/`milk` with `milk` as favorite; fox feeds on `animal_treats`/`cookie` with `cookie` as
favorite (same diet as the dog — they were already sharing `cookie`).

Note: `fishing_rod` is *deliberately* sold despite the mechanic being closed — its item copy says so
("Fiskevandet er ikke åbnet endnu, men stangen er klar" / `WHISPER_FISHING_CLOSED` on use,
`player_2d.gd:308`). Left in stock as authored teaser; if it ever proves a kid-confusion trap, drop the
`seed_shop` row until the fishing wave lands.

### M3. ~~Ghost's run perk = literally infinite sprint~~ — RETRACTED
**Correction (verified against `player_2d.gd:236`):** stamina regen only applies when
`not running and not is_flying` — sprint drains flat. Ghost at `run_cost_mult 0.6` sprints 11.1 s vs
6.7 s for the others, exactly the "runs longer" the design intends. Not a bug; the original note assumed
regen applied mid-sprint.

### M4. Stamina is nearly non-binding everywhere else too
Tool costs 1–4 (`tools.lua`), regen 12/s: watering the full 110-plot field ≈ 130 stamina ≈ 11 s of idle
time. Food/tonic consumables (`consumables.lua` 12–60 g) have almost no buyer. The day is 10 real minutes;
the stamina "economy" exists but never bites after the first season. Acceptable for cozy — but then the
docs/tools (`UI_TIRED` whisper, stamina UI) oversell a mechanic that is decorative. Lantern oil (150 s/fill,
`combat.oil_seconds`) is the *real* resource pressure — well tuned.

### M5. Crop table is dominated; two crops are never worth planting for gold
g/day per plot = (sell − seed)/grow-days, `game_balance.lua:37-47` + `crops.lua` seed prices:

| crop | days | margin | g/day | verdict |
|---|---|---|---|---|
| carrot | 4 | +45 | **11.3** | strictly dominates turnip (same days, more gold) |
| pumpkin | 10 | +100 | 10.0 | best bulk, efteraar only |
| turnip | 4 | +25 | 6.3 | dominated by carrot; starter/quest crop only |
| sunflower | 7 | +40 | 5.7 | |
| moonflower | 12 | +60 | 5.0 | + night-only watering (`water_window 20–6`); quest/utility niche |
| catnip | 5 | +20 | 4.0 | |
| strawberry | 4 | +10 | 2.5 | worst; foraar only |
| glow_berry | 10 | +55 | 5.5 | magic-store seeds only |

For a kids' game a dominant strategy is not fatal (teaches "compare prices"), but strawberry at 22 % ROI is
a trap purchase. Either give dominated crops a utility (catnip → cat gift/friendship? strawberry → loved
gift already) or accept as intended tiering.

### M6. Winter is a content dead-zone for the farm loop
No crop lists `vinter` in `seasons`. Winter = 28 game days ≈ **4.7 real hours per year** with the farming
leg of the core loop switched off; greenhouse (the designed fix) is a bare marker awaiting N07. The
dungeon/social/home legs remain, so it isn't empty — but 1/4 of the calendar is farming-silent. If the
greenhouse slips further, add one vinter crop (e.g., `frost_kale`, water_window-free) as an interim.

### M7. Quest rewards sometimes pay less than vendoring the turn-in goods
`needs`/`consume` turn-ins price the goods at ~0 implicitly; compare reward vs `sell_price` of the consumed:

| quest | consumes (vendor value) | reward | net gold-ish |
|---|---|---|---|
| `cookie_delivery` | 12 carrots ≈ 780 g | ~~230 g~~ → **500 g** + 3 cookies + 1 fairy_dust | ≈ −70 g (**fixed**: gold 230 → 500, near vendor-parity while the quest still teaches "helping isn't free") |
| `ugles_noegle` | amethyst+rose_quartz+amber ≈ 510 g | 150 g + `ugle_noegle` (dungeon key) | −360 g but buys a **gate item** — fine |
| `birthday_cake` | 3 turnip+1 moonflower ≈ 315 g | 280 g + items | ≈ −35 g + items |
| `animal_products` | 5 egg+3 milk ≈ 150 g | 320 g + items | +170 g ✓ |
| `fix_roof`, `supply_run` | ~20–30 g | 320 g / 230 g + items | very generous ✓ |

The carrot errand is a repeatable *money trap* for kids (teaches "helping costs something" — maybe intended;
if so, the objective text should not call it a sale). The gem-key purchase is correctly a progression buy.

### M8. `have = true` collect objectives are buyable — some gates are purchasable
Because `item_gained` + `have=true` counts *owned* items regardless of source (`quest_manager.gd` header),
shopping completes "collect" steps:
- `moonstone_crown` (the **t9 gate**): 1 moonstone = ~484 g at `magic_store` (1/day) → quest done for
  net *profit* (800 g reward). The adventure-tagged gate reduces to a shop purchase.
- `crystal_cave`'s 5 shards are buyable (~2 420 g, 2/day restock) — but `explore_cave` still forces floors
  10–12, so the deep gate survives. Good.
- `enchanted_garden`'s "find rare seeds" = buying `moonflower_seeds` — flavor mismatch ("find" → "buy").
Buying your way through adventure gates may be deliberate flexibility (money sink); flag it so it's a
*choice*, not an accident.

### M9. Misc smaller items
- `rare_mushroom_hunt` (giver `fairy_lily`, a *child* NPC) requires the floor-7 `find_glowing` quest_spot
  (`dungeon.lua`) — was offerable immediately, completable only deep. **Fixed**: added
  `requires_zone = "dark_forest"` (the same offer gate its four forest siblings carry), so the offer only
  appears after the player's first walk into the wood. `meta.location = "ZONE_MUSHROOM_GROVE"` on a city
  NPC stays — it labels where the quest *leads*, not where it is offered.
- `enchanted_garden` sets `enchanted_garden_unlocked` on completion — **read nowhere**; a forward hook
  (enchanted-garden area pending?). Harmless today.
- `sword_upgrade.is_available` checks `has_iron_sword` — a flag set only by this quest's completion, so a
  player who *buys* `iron_sword` from the smithy first still gets offered the quest (minor: flag name lies).
- `slotsdroemmen` (the endgame capstone: 6000 g + 2 legendary keepsakes) is well-formed — `state` queries
  for placed keepsakes + hygge 5 + `festival_held` (the 500 g great-hall feast) — coherent endgame loop.
- `ghostfam_hittegods` requires `get_hearts(silke) >= 4` — a hearts-gated errand; consistent with the
  weekly-chat heart economy (≈4 weeks of chats) — check pacing is intended.

---

## 3. Story findings

### S1. The spine is complete and faithful to the addendum — this is the headline
Playable arc: `intro_lottery` (lottery letter) → `forste_dage` (tutorial) → `secret_garden` (12-step
restoration → mother's letter `garden_trail` evidence, `secret_garden_story.gd`) → `MotherStory`
(`forest_mother_s03–s08`, `mother_story.gd`): 14 evidence pieces placed across floors 1–12 with boss-gated
chapters (floors 4/8/12 = `snurresvamp`/`_gloed`/`_konge`), witness accounts from Natteblik/Fru Ugle/Pip/
Oak/ghost family, a persistent journal tab ("Mors spor"), and the S08 revelation.

The `forest_mother.csv` copy is genuinely good and honors every hard rule of
`DARK_FOREST_STORY_ADDENDUM.md`: the fate is fixed and stated plainly ("Det kostede hende livet… et ekko,
ikke en levende fange" — she is *not* alive waiting), the player refuses the Root Scribe's role
(`FM_REFUSE_ROLE`), and the legacy is the seed tin planted in the restored garden (`FM_E_LEGACY_HOME`).
`can_read` ordering enforces pacing (`mother_fate` needs s07 done; `echo_account` needs all four s04
memories). Evidence is versioned and re-placed if a daily floor re-roll moves it — kids can't permanently
miss a clue. **This is the strongest part of the game.**

### S2. Story↔mechanics interleaving is well-designed
Checkpoints sit exactly at boss floors; `skovlift_intro` teaches descend→rune→extract→report;
`rune_vandring` (runestones at 5 & 9) and `ugles_noegle` (gem-key → lake chests) layer progression on top.
Natteblik's witness accounts (`map_account`, `route_witness`) reuse an established character with a reason
to know routes — good cast economy per the addendum's helper table.

### S3. Ghost-family continuity is handled with real care
Ghost heroes get the kin-recognition scene (Dyne's 5-line `ghostfam_kin_*` sequence + free sweater + 2
hearts) while non-ghosts get friends-not-relatives per the addendum; `DLG_GHOSTFAM_*_KIN` rows were revised
for the mother chronology exactly as specced. Evening shop, midnight bench stories (one per weekday),
hide-and-seek (`ghostfam_seek`), family quests — the family is a full subsystem, not a cameo.

### S4. Writing quality (sampled broadly)
Danish-first, warm, short-sentence voice appropriate for children; English is complete and clean
(`festivals.csv` festival text is genuinely charming — "Del frø og blomster på Hyggetorvet"). The intro
("et brev fra Fekongen selv!") sets stakes in one line. No raw translation keys reach players (loc lints
cover all 8 quest-relevant CSVs; `ui_foundation` verifies no raw keys in quest titles/from-lines).

### S5. Narrative debts / thin spots
- **The Root Scribe is text-only.** S05's "names in the roots" traveller, the echoes, and the role-refusal
  scenes exist as evidence *text rows*, not encounters — the addendum's interactive proposals (empty chair,
  echo conversations, the frame) aren't built. The final boss is `snurresvamp_konge`, deliberately *not*
  the Scribe — correct per design, but the reveal is a read, not a scene. Consider one authored clearing
  (S04's "house that remembers" is the obvious candidate) if scope allows.
- **Voice is hooks only**: every `voice_key` points at `voice/<npc>/<line>` recordings that don't exist;
  `_voiced_social.lua` indexes 69 keys. If voice ships later, fine — if not, the keys are dead weight.
- **Secret garden map is small** (a walled ~25×20 plot): the 12-step quest uses 7 marker kinds — adequate,
  but the "restore" steps are three E-presses; the emotional payoff is carried by the letter text.
- **`fairy_lily`'s mushroom hunt** (M9) also has a story wart: a small child sends you to the deepest
  mushroom floors — flavor-wise odd unless she's meant to be weirdly fearless (her file suggests so).
- **`expected_weapon` curve** (`dungeon_run.lua:5`) implies weapons of damage 5→24 by floor; the rusty
  sword (dmg 3) + smithy rotation + t5 forge cover it — but the *narrative* never nudges you to upgrade
  before floor 4; a stuck player gets the boss-gate wall with no story reason. `skovlift_intro`'s report
  line to Oak is the natural place for a "bring a better blade" hint.

### S6. Consistency checks passed
- All 40 quests reachable: `quests_offered` lists per NPC (`npcs.lua`) + generic `meta.giver` offers +
  story-driven (`forest_mother_*`, `secret_garden`) + auto-accept (`intro_lottery`, `forste_dage`).
- Every turn-in target NPC exists; every `zone`/`item`/`npc`/`crop`/`state` reference in objectives resolves
  (zones = the 4 dungeon bands + farm/city/traetoppen).
- `lost_cat` is one-shot per decision CD15; repeatables have cooldowns (2–14 d).
- Character-select perk copy (`CHAR_*_PERK`) matches the *implemented* perks (the `game_design.md` table is
  the stale artifact — e.g., doc says fairy = "magic crops grow faster", actual = flight/flower-talk).

---

## 4. Fix round (this review pass)

Applied and verified (`run_playtest.sh --only=quests,save`: 313 checks, 0 failures):

1. **`fish` dead item** — cat favorite now `milk`, fox `cookie`; feed lists dropped `fish` in both
   `lua/config/husbandry.lua` and the `animal_husbandry.gd` fallback table.
2. **`cookie_delivery` reward** — gold 230 → 500 (near vendor parity for the 12 carrots).
3. **`rare_mushroom_hunt` offer gate** — added `requires_zone = "dark_forest"`.

Re-classified on verification:

- **M3 ghost sprint — retracted** (regen is off while running; the perk is exactly as designed).
- **M1 tier-gate order — authored intent** (t6 copy narrates the amethyst/spire; validator S13 pins the
  later gates). Kept as a design note, not changed.
- **Fishing rod** kept in `seed_shop` — authored teaser with self-aware copy.

Still open (deliberate or pending-wave work):

- **Winter farming dead-zone** — no `vinter` crop; `greenhouse_slot` awaits package N07. Interim option:
  one frost crop. Not fixed here (new content, needs its own loc/validator pass).
- **Buyable adventure-gate collects** (`moonstone_crown`, `crystal_cave` shards via `have=true`) —
  requires_zone still forces the forest visit; the buy-out is a money sink. Flagged as a design
  *question*, not changed.
- **Stamina is decorative** outside the dungeon — a design choice, not a defect.
- **Dominated crop rows** (strawberry/moonflower as gold crops) — seed prices are pinned by
  `economy.gd:GUIDE_SHOP`; rebalancing belongs to a balance pass, not a review fix.
- **Root Scribe as encounter** — remains a story-text entity; an authored scene is a feature, not a fix.

*Not reviewed:* save/robustness internals (code review's scope), art pipeline, voice production, and the
balance sim's assumed-income caveat (it's a model, not a playtest — but it's a *good* model and its numbers
are consistent with the data).
