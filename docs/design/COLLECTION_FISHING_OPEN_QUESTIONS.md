# OPEN QUESTIONS - collection and fishing addendum (only what the OWNER must decide)

Companion of `COLLECTION_FISHING_ADDENDUM.md` (2026-10-18). Each question has a recommended default that the build follows if nobody answers. Only Q1 and Q2 block a package; everything else is one data value, one copy row or a later phase.

## Fishing

1. **Reopen fishing at all?** This reverses "no fishing" in `PLAN_2D.md:1695` (CUT/STUB), DX25 / CR23 (`DUNGEON_V2_ADDENDUM.md:783,868`, Moon pond stays decor) and DT7 / DT38 (`TOWNS_FARM_SOCIAL_ADDENDUM.md:44,971,1033`, farm pond stays decoration). There is still no `fishing_spot` marker and no minigame screen.
   **Default:** yes, as designed ("Proppen dykker": shore fishing, no fail state). Blocks FI1-FI3.

2. **Fish icons and the strict art gate.** No painted cell shows a fish, and `palette_variant` only recolours cloth and trim (`tools/art/drawn/items.py:44-45`), so a recolour placeholder would ship a wrong picture. The strict coverage gate (`tests/sections/art_forest_mother.gd:16-17` → `tools/art/drawn/coverage.gd:73`) fails on any item without an icon file. Options: (a) paint `tools/art/drawn/sources/icons_fish.png` (one 4×4 sheet: 13 fish + fish cakes) before fishing merges; (b) a temporary, listed exemption in `coverage.gd` for the 14 fish ids, removed when the sheet lands. Either needs coordination with the Codex restyle.
   **Default:** (b) the listed exemption so the code can land, with (a) ordered in parallel and the exemption list required to be empty before the next release build. Blocks merging FI1.

3. **Daily pools and prices.** Pools 8 / 6 / 6 give at most about 480 g a day and typically 100-250 g for a child (3-6 turnips' worth). Fish sell 12-140 g; keepsakes are unsellable.
   **Default:** as designed; pool sizes are the knob if it feels too rich.

4. **Rod access.** The rod costs 120 g in the seed shop today (`lua/shops/seed_shop.lua:42`), not in the starter kit.
   **Default:** shop only in the MVP; a free rod from Pippin's first fishing quest in P2.

5. **Moon Fish pity.** Månefisken (legendary) is certain on the 12th night catch at Månesøen (≈ 2 night visits); Gamle Gustav (unique) is eligible after 10 town-pond catches and certain on the 25th.
   **Default:** 12 and 10 / 25. Alternative: make the Moon Fish quest-gated (Dyne scene first).

6. **Keepsake display.** Gamle Gustav and Månefisken are one-of-a-kind fish items (cannot be sold or gifted).
   **Default:** items only (shown in the Samlerbog). An aquarium or trophy furniture is a later option that needs furniture art and a validator source-kind change.

## Samlerbog

7. **Stamps.** The F9 spec says progress only, milestones cut (`PLAN_2D_FEATURES.md:362,1303`). Proposed: 3 stamps per page at 25 / 50 / 100 %, paying 50 / 150 / 400 guldagern, no titles, items or perks (3,000 over five pages; starting gold is 500).
   **Default:** stamps on, `reward_pct = 100`. Setting `reward_pct = 0` keeps the seals and removes the gold.

8. **Hints on unknown entries.** Show source kinds ("Kan findes i …") and, for the 68 riddle items, the `hint_key` riddle on tiles not yet found? This reverses the spec's "source lines after discovery" and the RV-C12 rejection.
   **Default:** yes for the young audience; both are knobs (`unknown_shows_source`, `unknown_shows_riddle`).

9. **Ship the Samlerbog now, and how to tick the README.** F9 was optional with Q4 default "out" (`UI_NAVIGATION.md:1203`). The audit row goes live as soon as `scenes/ui/samlerbog.tscn` exists (`tests/lib/ui_audit.gd:2743-2753`). The roadmap line (`origin/main:README.md:228`) covers both features.
   **Default:** build it now (it has no art blocker); split the README line into "Samlerbog" and "Fishing" so each is ticked when it ships.

10. **Reference mock.** The registry compares against `tests/checkpoints/guide_ref_features/ui_samlerbog.png`, which does not exist; the old mock outside the repo has outdated counts and the cut milestones.
    **Default:** accept the first windowed capture of the build as the reference after you look at it.

11. **Skatte scope.** The spec says "rare building_materials" (`PLAN_2D_FEATURES.md:795`: e.g. plank_cherry, plank_ebony, gold_leaf, fabric_damask, marble_block and 4 blueprints). The design uses the 21 cut gems (incl. `gem_bag`) plus the 11 `dng_` forest materials, including the 3 boss rune shards.
    **Default:** gems + `dng_` (32 entries).

12. **Våben page.** The F9 spec has no weapons page; you listed weapons as collectables.
    **Default:** yes, a Våben page with 24 entries.

13. **Fru Ugle as the book's keeper.** Subtitle "ført af Fru Ugle" and the welcome letter signed by her; her daily tip comes in P2.
    **Default:** yes (flavour only, no gameplay).

## Related, outside both features

14. **A keyboard key for `use_tool`.** `use_tool` / `attack` have no keyboard binding (LMB and pad X only, `project.godot:152-162`), which breaks full-keyboard play for every tool. Fishing avoids it by starting on E. Binding a key is an input-contract change (`tests/tools/input_contract.gd`, `check_project.gd`).
    **Default:** a separate input change, not part of these packages; proposal to be made with the controls review.
