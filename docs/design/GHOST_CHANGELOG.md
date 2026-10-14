# CHANGELOG - ghost addendum, final edit (design4)

Role: FINAL EDITOR. The independent review found 11 defects (3 major, 8 minor); every one was verified against the repo before it was fixed. `DESIGN_GHOST.md` and `ghost_packages.json` in this folder are the fixed versions; they are generated from the scripts in `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/scripts/` (`build_doc.py`, `build_packages_json.py`, `ghost_edits.py`), so the text, the edit table and the package file cannot drift apart. Proof of the sequencing claims: clone runs in `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/final_logs/` (three states of the tree, see "How it was proven" at the end).

## Major

### 1. Hero chips used type sizes that are not in the theme (design 6.2 / 6.6, AG6 task 3, numbers file)
* Verified: `tools/ui/build_theme.gd:133-182` has `Display48..Display15` and `Muted17..13`, `Bold19/18/17Muted/15Mono/15Gold`; no `Display17`, no `Bold13`. `UI_NAVIGATION.md` 2.5: names are Caprasimo with a floor of 20, "the built theme's variations are the whole scale".
* Fixed: chip name = `Display20` (`build_theme.gd:141`), kind line = `Muted13` (`:168`; built, unlike `Bold14`, which P28 adds in wave 3b). `select_mock.py` re-rendered `proto/select_4cards_fixture.png`, `_live.png` and `_animal_selected.png` and LOOKED at; `select_4cards_numbers.txt` redone: chips are 53 px high, Bu 150.9..228.9 (78 px) and Hviske 238.9..341.1 (102 px), the blurb starts at x 365 and is 541 px wide with the Tilbage button (673 without). `blurb_fit.py` now measures every race with its real chip row (the first draft used one width, 551 px, for all): the bar is 477 px for Fe (narrowest) .. 544 px for Halvling and all eight blurbs fit two lines. The S04 amendment text, AG6 task 3 and the typography check (`rule_report(root)["typography"]` empty on `select_1`) are updated; the old 79 / 92 px figures are gone.

### 2. The ghost could not be chosen in the lead's M1a
* Verified: the lead's M1a (`LEAD_NOTES.md`: stage 1 P22 V3 N01 P11, stage 2 V1 V2 V5 + the ghost, stage 3 V4) does not contain P16, P06 or P28; the draft left the legacy select unpatched; `run_playtest.sh --character=ghost` fails with `button %GhostButton not found` (reviewer's `full_ghost.log`). `tools/dev/play.sh` starts the real main menu, so the user would have met a three-button screen.
* Fixed BOTH ways the reviewer offered: (a) a cheap way in M1a: lead patch **SE-G5**, 9 edits in 3 files (`ghost_edits.py --when sel`): a fourth button `%GhostButton` in `scenes/ui/character_select.tscn` / `scripts/ui/character_select.gd` (label from `CHAR_GHOST_NAME`, preview from `CHAR_GHOST_PERK`, the two looks in the dropdown, no Danish literal) and two self-test lines. MEASURED: `--character=ghost --strict` WITH the boot stage = 17 sections / 2789 checks / 0 failed / 0 engine errors. Windowed look: `proto/shots/legacy_select_ghost.png`. (b) the milestones are labelled honestly (`DESIGN_GHOST.md` section 12, `ghost_packages.json` `milestones`): in M1a the ghost can be PICKED and WALKED around (baked hover, idle, glide walk / run by the built stub player) but has NO perks, bob, glow or garment layers (P06, G-ghost-play, A2 / F5) and no four-card page, hero chips or Danish blurbs (P16): all M1b. P16 rewrites the two legacy files in place later and keeps `%GhostButton` (AG6 notes).

### 3. Fix-round verify tags cited checks that cannot be green there; "FIRST gate of the fix round" was false
* Verified in the reviewer's clones (`review/logs/c_fixround_*.log`, `f4_ghost_section_on_fixround_clone.log`; the fix-round-only state is re-measured below): on a clone with exactly the fix-round edits the built harness is green for animal, fairy and hobbit, but the draft `ghost.gd` fails 5 checks (`race_key_and_visual_chain`, `data_rows_agree`, `perk_keys_defined_for_every_race`, `perk_numbers`, `keys_translate`) and the ghost under `--no-boot` fails `area.game_data_race_and_config` (no V1 race row).
* Fixed structurally: (a) `ghost.gd` keeps the **7 checks** that need only the fix round + `ghost.csv`; the 4 that read V1's rows moved to **`tests/sections/ghost_data.gd`, owned by V1** (AG1 `ownsAdd`), proto in `proto/tests/ghost_data.gd`. (b) **G-ghost-data moved to wave 3b**, so it really IS the first gate directly after the fix round. (c) the RG1-RG6 verify tags now name only built checks that are green at that state (`core.new_game_default_and_explicit_skin`, `save.summary_character_keys`, `area.game_data_race_and_config` for the three old races, the self-test case `bad_character_is_usage_error`) plus the fix-round gate "the built harness for animal / fairy / hobbit, strict", with the `ghost.*` guards named as the re-assertion in 3b; `shot_world.character_argument_ghost` (no such check) is replaced by an honest statement; `menus.guide_diff_select` stays with P16, `zz_ghost.docs_name_four_races` with G-ghost-qa (RG7 now verifies by a grep + diff review).
* MEASURED (`final_logs/`): fix round only: animal 15 sections / 2774 checks / 0 failed / 0 engine errors, fairy 15 sections / 2774 checks / 0 failed / 0 engine errors, hobbit 15 sections / 2774 checks / 0 failed / 0 engine errors; fix round + 3b: `--only=ghost` green for all four heroes (`t3b_ghost_section_*`), animal full 16 sections / 2781 checks / 0 failed / 0 engine errors. The perk-leak mutant is still caught by the new section (`mut_perk_leak.log`: failed ghost.every_enum_value_has_a_perk_row, ghost.no_hobbit_perks_leak).

## Minor

### 4. G-ghost-play acceptance without `--no-boot`; the self-test went green on a red boot stage
* Verified: `f2_only_ghost_with_boot.log` (11 ghost checks pass, exit 1 with two boot failures); `selftest_all_chars.log` `ok boot_2d_ghost (exit 1, 5s)`: the case matches only `ok boot.phase_playing` with exit `*`.
* Fixed: with SE-G5 the boot stage of the ghost is green, so G-ghost-play (now wave 5) keeps the boot variant. The self-test case gains the must-not-match `FAIL(ED)? +boot\.` and the ghost enters `--all-characters` only together with the button (`when = sel`, not in the fix round). MEASURED: self-test 42 ok / 1 failed (the one failure, live_known_issues_file_is_reported, is pre-existing: pristine main gives 41 ok / 1 failed with the same case, `notes/selftest_main_pristine.log`); mutant (`mut_boot_case_verdict.txt`): on a legacy screen without the button the old case predicate says ok, the new one says RED.

### 5. Same-wave couplings only in prose
* Verified in `ownership_review.txt` O4. The reviewer proposed `softDependsOn` inside wave 4; **the design3 checker rejects it** (`check_ownership.py` D: "softDependsOn is not in a strictly earlier wave"; mutant 7 of `scripts/ownership_mutants.py` shows it), so a soft edge would have broken the ownership proof.
* Fixed with hard edges across waves: **G-ghost-data and G-ghost-art -> wave 3b** (V1 `addDependsOn G-ghost-data`, A2 `addDependsOn G-ghost-art`), **G-ghost-play -> wave 5** (dependsOn V1, P06, DR1). P06's hooks are null-safe and P06 has no edge to the ghost packages (AG4); the four behaviour checks that needed the classes moved from `player.*` to `ghost_play.player_*` (they could not pass at P06's own gate). The merge order inside wave 4 is written down (V1 first, SE-G5 right after, P16 after V1). `check_ghost_ownership.py` still reports OK and `ownership_mutants.py` shows 8 of 8 mutants caught.

### 6. Acceptance numbers contradicted the wardrobe rules
* Verified: `lua/data/wardrobe_rules.lua` exclusive pairs, `lua/data/sets.lua` header ("at most 7, with a dress 6").
* Fixed (design section 5, AG8, AQ-F10, G-ghost-qa row G4): two maximal outfits. No dress: pants, shoes, shirt, bracelet, necklace, earrings, hat = 7 worn, **5 drawn**, 2 hidden-but-counted. With a dress: dress, shoes, bracelet, necklace, earrings, hat = 6 worn, 5 drawn, 1 hidden. "7 layer parts" / "7 layers" are gone; 7 is the number of drawable slot KINDS.

### 7. Hero-count checks not reconciled with design2
* Verified by grep: `wardrobe_ui.preview_six_heroes` (design2 F8) and `wardrobe.heroes_from_catalog` (design2 F5) vs the draft's fixed rename.
* Fixed: AG8 defines the F5 all-slots check over `CharacterCatalog.heroes()` (eight looks) as `wardrobe.heroes_all_slots`; AG10 renames the F8 preview check to `wardrobe_ui.preview_eight_heroes`.

### 8. Hidden pants / shoes vs loot and rarity
* Verified by `scripts/clothing_counts.py` (`notes/clothing_counts.txt`): 29 of 96 wearables are pants / shoes (30 %), 6 of 21 unique + legendary, 2 of 8 legendaries, the capstone `pants_trousers_starlight`; `localization/wardrobe.csv:105`.
* Decided and written down (design section 5, AG8, AG10, risks, stubs): **hidden slots count** for perks, set bonuses AND the RarityAura (the aura reads the worn items and is THE rarity cue at game zoom, so a legendary hidden piece still shows; test `wardrobe.hidden_slot_counts_for_aura_and_sets`); **no reroll** (loot stays race-blind); the invisible cue is accepted and flagged by the Garderobe tag, the equip toast and the aura; a tinted hem layer (+1 bake) is the recorded upgrade if play shows it disappoints. Risk added.

### 9. Hint line and dead-end Up on the cards
* Fixed: the hint is unchanged (`[←→] Vælg · [Enter] Videre · [Esc] Tilbage`; `[↓] Udseende` is gone: no package defines it and the reference render never showed it). Up on a card goes to the selected hero chip (the ring of `UI_NAVIGATION.md` 3.4), in the focus map, the S04 amendment and AG6.

### 10. Tone gate would fail the king's line
* Verified: `DLG_GHOST_KING_INTRO` contains "skræmmes". Fixed: `ghost_lines.tone_gate` is an ALLOW-LIST (banned stems fail unless the key is listed; the list's one entry is the king line; an entry without a stem is reported). `scripts/tone_check.py`: 24 strings, exit 0.

### 11. Edit list missed stale comments; AG2 anchor collides with V2
* Fixed: five comment edits added to `ghost_edits.py` and to section 11: `race_perks.lua` header, `characters.lua` races comment, `shot_world.gd` usage line, `game_data.gd` race_key() doc, and one the review did not list, `character_catalog.gd` race() doc (V1 owns it). AG2 / AG1 now say "append the ghost entries as the last row(s) of the table as V2 / V1 leave it" instead of quoting closing lines. `dry_check_edits.py`: 61 edits, every anchor found exactly once in main.

## Also changed, not in the review
* The edit table gained a `when` column (`fix` / `v1` / `sel`): the fix round is exactly the edits of BUILT packages, V1 / V2 edits are wave 4, SE-G5 is the lead's.
* `check_ghost_ownership_selftest.txt` is now produced by `scripts/ownership_mutants.py` (8 mutants, each required to exit 1 with the expected problem) instead of a hand-kept note.
* N01's ghost run is a stage-gate run (it has no edge to V1, same wave).
* The ghost art, palettes and the contact sheets were NOT touched: no defect concerned the look, so nothing was re-baked (`proto/contact_sheet_ghost.png`, `gamezoom_check.png`, `sketch_vs_baked.png` are the designer's, looked at again).

## How it was proven (clones of main at b909274, `scripts/final_clone.sh` + `scripts/final_runs.sh`, logs in `final_logs/`)
| state | what is applied | runs |
|---|---|---|
| fix | the 28 `fix` edits (files of built packages) | animal / fairy / hobbit `--strict` full |
| t3b | fix + ghost.csv + `ghost.gd` (7 checks) + ghost art through `produce_all.sh` | `--only=ghost` for four heroes, animal `--strict` full |
| full | all 61 edits + ghost_data.gd + ghost_dialogue.csv + art | animal / fairy / hobbit / ghost `--strict` full WITH boot, self-test `--all-characters`, mutants |
Full state: animal 17 sections / 2789 checks / 0 failed / 0 engine errors; fairy 17 sections / 2789 checks / 0 failed / 0 engine errors; hobbit 17 sections / 2789 checks / 0 failed / 0 engine errors; ghost 17 sections / 2789 checks / 0 failed / 0 engine errors (17 sections = the 15 built + `ghost` + `ghost_data`, plus the boot stage). Fix state: ghost under `--no-boot` fails exactly `area.game_data_race_and_config` (V1's race row is missing) and nothing else; the same one failure at 3b (`t3b_ghost_noboot.log`), so the first green ghost run is the V1 commit. Mutants: `mut_perk_leak.log` (the leak) and `mut_boot_case_verdict.txt` (the self-test case).
**A flake, kept as evidence:** the first full-state animal run (`full_animal_run1_loaded.log`) failed ONLY `ui_audit.fast_enough` (12.3 s against a hard 10 s wall-clock bar) while other agents kept the machine at a load average of 26-32; the rerun at load ~14 passed (`full_animal.log`). The reviewer's own `c_fixround_ghost_noboot.log` shows the same check failing under load. Nothing in the ghost edits touches `ui_audit`.
