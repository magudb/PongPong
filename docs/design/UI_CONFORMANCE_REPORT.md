# FINAL REPORT - "make sure the menu and navigations follow our guide"

Final editor, 2026-10-14. Subject: UI navigation and conformance for TRÆTOPPEN (Godot 4.7.2, GDScript). Nothing in the main repo folder `PongPong` was touched; the spec work is in `.pongpong-build/work/design_ui/`, the library work is in the worktree `PongPong-worktrees/ui-audit` (branch `ui-audit`, nothing committed: the lead commits).

---

## 1. What exists

| Deliverable | Where | What it is |
|---|---|---|
| The specification (version 1.1, binding) | `design_ui/UI_NAVIGATION.md` (1.2 k lines) | the guide as testable rules (section 2: R1 ink, R2 gold = focus and selected only, R3 numbers in Caprasimo, R4 no red, typography, building blocks as pixel specs), the input model (section 3: the 14 engine facts F1-F14 probed in 4.7.2, the 37-action table, where each key is read, focus model, modal stack / Esc depth table, text fields, mouse, gamepad, hints), the shared infrastructure (section 4: `UiNav`, `TTScreen`, `UiHints`, `HintBar`, `UiConfirm`, theme conformance, input additions, pinned crops), the screen inventory and 27 screen cards S01-S27 (section 5; `language` and `sleep` have a card but no registry row), the navigation graph (section 6), the conformance matrix and guide-compare shots (section 7), legacy -> replacement (section 8), ownership, the P17 wave decision and the gates (section 9), the API of the audit library (section 10), appendices A-G (key glyphs, localization families, registry of 219 named checks, the screen table, theme debt, 23 decisions, the newer sketches and the open questions) |
| The package companion | `design_ui/ui_packages.json` | per package: `ownsAdd`, `ownsRemove`, `addDependsOn`, `addTasks`, notes; the new package P28; the wave changes; `optionalAmendments` (F9). Cross-checked against Appendix C by `final_tools/crosscheck.py` |
| The screen table of the audit library | `design_ui/ui_screens.proposed.json` = `tests/lib/ui_screens.json` (byte for byte) | 27 rows: the two P07 gallery pages (live) and the 25 screens of spec 5.1 (the legacy title / select, everything else pending until its scene lands). `status` is derived at run time, never edited |
| The audit library | worktree `tests/lib/ui_audit.gd` (3 015 lines) + `tests/lib/ui_audit_rules.gd` (968 lines) | `UiAudit`: `initial_focus`, `focusable_report`, `focus_walk` (+ radio pages, pad check, sliders, tabs), `mouse_walk`, `escape_chain` (depth 0 presses Esc once, key / pad B / Start), `text_field_audit`, `rule_report` (R1-R4, typography, hit targets, raw keys, per-node overrides, source scans), `locale_flip_report`, `theme_report`, windowed `ring_pixels` / `panel_pixels` / `button_pixels`, `audit_screen` / `audit_all` (the registry), option validation, the selftest |
| Its sections | worktree `tests/sections/ui_audit.gd` (planted defects, conforming layouts, the registry, the legacy report), `ui_audit_blind.gd` (new: blind negative tests of every reviewer finding, the windowed ring tests), `ui_audit_pins.gd` (new: one pin per branch and constant) + fixtures `tests/fixtures/ui_audit/**` | 904 headless checks, 54 windowed |
| The legacy audit | `design_ui/legacy_audit.txt` | what the audit says about today's title and character select (section 5 of this report) |
| Engine probes | `design_ui/probes/` | throwaway scripts behind the engine facts (`README.txt` explains each; new in this edit: `final_probe_accept.gd`, `final_probe_theme.gd`, `final_probe_spinbox.gd`, `final_probe_freed.gd`) |
| Tools of this edit | `design_ui/final_tools/` | patch scripts, `build_registry.py` (regenerates both registry files byte-identical), `crosscheck.py`, `mutate_final.py` + `mutants_extra.py` (the mutation runner and its mutants), `mutate_windowed.py`, `run_section.sh`; logs in `design_ui/final_runs/` |

How the pieces answer the request: the guide's rules are written as checks (spec 2, 7), every screen of the game has one owner and one card (5, 9), the way a player moves through the game with keyboard, mouse and gamepad is one model with one infrastructure package (3, 4), and the library measures a screen against both, today on the legacy screens and automatically on every future scene.

---

## 2. How a builder uses it (the recipe)

For the owners of P16 (menus), P17 (HUD), P18 (shop / backpack), P14 (dialogue, quest book), P19 (forest HUD), P20 (animals, build), F7 (home), F8 (wardrobe), F9 (if it ships):

1. **Read** spec sections 2 (the rules), 3 (input model), 4 (what P28 gives you) and your own cards in 5.2 and the `ui_packages.json` entry of your package. The card names layout, focus map, keys, Esc depth, hints, the checks you owe (Appendix C lists every name with its owner).
2. **Build on P28**: your screen extends `TTScreen`, uses theme type variations only (no per-node font / colour overrides: `tt_override_ok` meta with a reason is the escape hatch), `UiConfirm` for every question (never `ConfirmationDialog` / `OptionButton` / any `Window`), `HintBar` for the key hints, `TTSlider` for every slider, `ToastStack` / `WhisperLine` / `PromptPill` instances for feedback. Text only in localization CSVs.
3. **Do not edit `tests/lib/ui_screens.json`.** Your row exists already; the day your scene file appears the row becomes `live` by itself and the audit sweeps it. A row turning live with a failing audit is the signal that you are not done; a pending row whose scene landed without being swept fails by design (`registry_pending_scene_landed_tripwire`).
4. **In your own test section** run the whole row in one line: `await UiAudit.audit_screen(t, "<id>")`. Add what only you can prove: `UiAudit.escape_chain(t, opener, depth, opts)` for modals that need a driver (`opts.internal_layers`, `settle_seconds`, `expect_focus`), `UiAudit.focus_walk(t, root, 0, {expect_edges: {...}})` for the declared neighbour table of your card, `UiAudit.ring_pixels` (windowed) for a ring you paint yourself.
5. **Options instead of exceptions**: radio tabs that are not a `ButtonGroup`: `options.tab_groups`; chips with side effects and no page behind them: `options.pages: false`; a control that deliberately consumes a direction: `options.consumes`; gold you really draw (a guide ornament): meta `tt_gold_ok` with the reason; a hit target below 32 px that the guide really has: `options.hit_min` plus the reason. A mistyped option name or value fails the row (`bad_option`) - it never switches a requirement off silently.
6. **Fix the screen, never the audit.** A finding is either a defect in your screen or a guide exception that goes into an option / meta with a sentence of why. If you believe the audit is wrong, say so to the lead: do not weaken it.
7. **Look at it**: `tools/dev/run_windowed.sh --only=<your section> --out=...` then compare with the guide (`tests/checkpoints/compare_guide.py`, spec 7.3); the baseline PNG of your screen (`docs/qa/ui_baseline/<id>.png`) is committed by you at landing, after the lead has looked at it.
8. **Proof of life**: `tests/run_playtest.sh --strict` in an APFS clone (never in the shared checkout), then the windowed run for pixel checks.

Engine facts that decide how you write handlers (all probed, spec 3.1): Esc / Tab-as-hotkey / page keys are read in `_input` (a focused `LineEdit` eats them in the GUI stage); `ui_accept` is NEVER eaten in `_input` (the focused Button would never press: probed), a modal marks it handled in `_unhandled_input` and `close()` calls `UiNav.swallow` so the closing press does not reach the world's `interact`; only screens that dispatch the press themselves (dialogue, Indretning PLACE) consume it in `_input`.

---

## 3. What the two reviewers found and what was done (33 verified defects: 16 major, 17 minor)

Spec and package defects (1-20, lens "fidelity"):

| # | Sev | Defect | Fix | Proof |
|---|---|---|---|---|
| 1 | major | modals eat `ui_accept` in `_input` (F4 / D9 / 3.2): no Button would ever press | F2, F4, D9, 3.2, 4.1, 4.2 rewritten: `_unhandled_input` marking, `UiNav.swallow` / `swallowing` (armed one frame, honoured by every `TTScreen._unhandled_input`), `TTScreen.consumed_actions` defaults empty; new probe `final_probe_accept.gd` | probed on 4.7.2 (Enter, Space, pad A, E: never presses with an `_input` eater, once with an `_unhandled_input` eater; `set_input_as_handled()` inside `pressed` does NOT stop the later stage); checks `ui_nav.accept_presses_focused_button`, `ui_nav.closing_press_does_not_reach_the_world` |
| 2 | major | guide-compare fixtures release focus for MenuRow / ChoiceRow, losing the gold fill the mock paints | D12, 7.3, S01, S13: release only ring controls; `title_guide` keeps Fortsæt, `dialogue_guide` the first ChoiceRow | measured: repainting the gold row as parchment costs +0.58 (row) / +0.83 (whole) on the title against 7.55 / target 8, +4.86 on the dialogue crop; `ui_conformance.fixtures_guide_focus_released` rewritten |
| 3 | major | no way to open Byg (build menu) on a gamepad | pause row `%BuildButton` "Byg" (farm only, guarded by `GameUI.get_screen`) in S07, 3.2, 3.8, the graph, P16 tasks | `menus.pause_build_row_farm_only`, `menus.pause_rows_optional_screens`, `zz_acceptance.gamepad_only_flow` |
| 4 | major | title / select / title-load have no toast surface (no GameUI) | toast stack, prompt pill, whisper line moved to P28 (wave 3b); `ToastStack` instanced in `main_menu.tscn` and `character_select.tscn`; 3.5, S01, S03, S06 | `menus.title_failure_toast_visible`, `ui_nav.toast_stack_caps_and_rarity` |
| 5 | major | no whisper surface on the farm HUD; the construction chip has no slot | `WhisperLine` (P28), `PanelWhisper` on farm / Hyggebyen / home HUD, the construction chip placed under the hearts row (S09) | `hud.whisper_on_farm`, `hud.construction_chip_position`, `ui_nav.whisper_line` |
| 6 | major | a theme `focus` StyleBox cannot ring a Godot slider | new `TTSlider` (P28) paints the ring and sets meta `tt_focus_style`; 4.6 item 2, Appendix E, S02, P28 owns | windowed proof (magenta 6 px style on HSlider and Button: 0 pixels on the slider, 2976 on the button; the ring rect is grown by half a grabber at both ends); `ui_audit_blind.slider_theme_focus_entry_is_present_but_a_plain_slider_has_no_ring_verdict`, `ok_painting_slider_shows_the_ring`; `ui_conformance.sliders_are_ttslider`, `ui_nav.slider_focus_ring` |
| 7 | major | built `PillTab` / `Chip` are 4 px shorter than the guide | 4.6 3b + Appendix E + P28 task: vertical margins +2 (PillTab 33, Chip 37) | measured minimum sizes (PillTab 29, Chip 33 today); `ui_conformance.pill_heights`; the gallery row carries a temporary `hit_min` 28 that P28 deletes |
| 8 | major | library default 44 px hit target contradicts the spec's 32 and the guide's 33 px pill | one decision (D19): default 32, floor 20 for the two translucent tag plates only; library, 10.6, U4 and the registry agree | `ui_audit_blind.hit_target_edge_32`, `hit_target_tag_plates_have_a_20px_floor`, `hit_target_message_names_the_minimum`; the mutants `hit_min_36`, `hit_min_28`, `hit_floor_24` are killed |
| 9 | major | select compare ceiling 15 has 0.42 headroom; Tilbage + HintBar would eat it | D12 / D22 / S04 / 7.3: `title_guide` and `select_guide` hide HintBar, `%BackButton` and toasts, with a check | measured: the Tilbage button alone costs +0.425 against 0.42 of headroom |
| 10 | major | the newer sketches (binding look) are only partly adopted | Appendix G (new): what is adopted and what is not, per sketch element; S24 states `outline_size 3` (CSS 6 px stroke, paint-order stroke fill); the HUD and roster conflicts are open questions Q1 / Q2 (section 10 below) | Appendix G tables |
| 11 | minor | `Bold16` / `Bold14` do not exist in the theme | Appendix E, 4.6 3c, P28 task | theme type list probed (`final_probe_theme.gd`) |
| 12 | minor | "Tag på nu?" shop -> Garderobe flow has no card | S21: `UiConfirm` default Fortryd asked from the shop, Ja closes the shop first; 3.5 table row; Appendix C `wardrobe_ui.after_buy_prompt`; F8 task | named check in the F8 package |
| 13 | minor | three registry inconsistencies (intro / minimap rows never live; select_2 depth; `ui_audit.selftest` check name) | rows get a `tripwire` (the scene that hosts them), `select_2.esc_depth` 2, check renamed `ui_audit.selftest_every_control_behaves`; `language` / `sleep` have no row (5.1) | `ui_audit.registry_valid` (the table of 5.1 / 7.2 is carried exactly), `ui_audit_pins.pin_registry_part_rows_derive_from_their_tripwire` |
| 14 | minor | pause rows guard only Garderobe / Samlerbog | all four transfer rows guarded by `GameUI.get_screen(<id>)`; the check uses stub target screens | `menus.pause_rows_transfer_vs_nest` |
| 15 | minor | TTScreen re-focuses every frame, but PLACE and text-only dialogue have no focus owner | `_wants_focus()` hook (3.4, 4.2); the audit respects it | `ui_audit_pins` / blind checks (`initial_focus_report` note, `focus_walk` skipped with a note), `ui_nav.wants_focus_guard` |
| 16 | minor | Down from the farm field must land on Start | S05 / 3.6 specify the entry point; `menus.pad_only_new_game` asserts it | named check in P16 |
| 17 | minor | wrong keys: `INDRET_NOT_HOME`, `UI_READ` | `INDRET_ONLY_HOME` (features_ui.csv), `UI_READ` is defined by P11's `areas.csv` (referenced by `iso_area.gd`), `DIALOGUE_CONTINUE_HINT` deleted by P14 | Appendix B |
| 18 | minor | ownership gaps (sections, fixtures, `SCREENS` entries, the prune, the stepper, F9) | `ownsAdd` for the three sections and the fixtures (P09), baselines per owner, the fixture `SCREENS` additions in P28, the prune moved to P14, stepper fix assigned to P28, F9 in `optionalAmendments` | `crosscheck.py` clean |
| 19 | minor | wording versus facts (ornament whitelist, FramePortraitRound, gold on `pressed`, 12 pack characters) | 2.1, 2.2: `PanelToast` / `PromptPill` "built, not in the guide" (D20), FramePortraitRound is a 3 px ring, check (a) matches 10.7 | spec text |
| 20 | minor | wave-move evidence and a baseline guard that cannot detect regressions | 9.2 corrected; each owner commits its baseline PNG at landing (`ownsAdd docs/qa/ui_baseline/<id>.png`) so the guard is live from the first capture | 7.3, 9.1, `ui_packages.json` |

Library defects (21-33, lens "technical"):

| # | Sev | Defect | Fix | Proof |
|---|---|---|---|---|
| 21 | major | `escape_chain` dies (typed assignment of a freed opener) | opener taken as `Variant`, checked, a note when gone; the same fault in the Modals fixture fixed; a second crash found by the pins (`stack1[-1]` on an internal-only layer) fixed | `ui_audit_pins.pin_escape_freed_opener_is_noted_not_judged`, `pin_escape_internal_layer_that_fades_out`, mutants `escape_want_level_off`, `escape_internal_layer_focus_check_uses_expected_depth` |
| 22 | major | false `nav_geometry` on ragged last grid rows | the "beyond" test counts only controls in the mover's own band (rects) | `ui_audit_blind.ok_grid_ragged_wrapped`, `ok_grid_ragged_plain`; the planted wrong way still reports; `pin_walk_geometry_*` |
| 23 | major | `text_field_audit` types letters and digits only | `_hotkey_specials`: Space, Tab, Shift, Ctrl, Alt, Backspace, Delete (Enter only with `options.press_enter`: Enter submits and the select page 2 would start the game; a note is emitted otherwise); leaked modals popped | `ui_audit_blind.text_field_specials_cover_the_bound_keys`, `ui_audit_pins.pin_text_field_audit_names_the_special_key_that_leaked` |
| 24 | major | the `esc_depth 0` chain presses nothing | presses the key once (key, pad B, Start via `escape.vias`), reports `esc_opens_modal` when the stack, the phase or the pause state moved, cleans up | `ui_audit_blind.blind_esc_depth_zero_*`, `ok_esc_depth_zero_via_pad_b`, `ok_esc_depth_zero_via_start`, `blind_registry_esc_depth_zero_row_that_opens_pause`; pins for the phase-only, pause-only, stack-only and pop-under-the-screen cases |
| 25 | major | radio-group tabs (PillTab / Chip in a `ButtonGroup`) not audited | every member's page is selected (focus, then accept when focus alone does not), walked, rule-scanned, hit-target-checked and restored; `radio_select_dead`; `options.pages / max_pages / tab_groups`; other members are not probed while a page is walked | `ui_audit.neg_radio_page_defects_*`, `neg_radio_select_dead_*`, `conforming_radio_tabs_*`; pins on max_pages, the pad check on a closed page, the single-member group |
| 26 | major | the section pins few branches (110 of 277 reviewer mutants survived) | new sections `ui_audit_blind` (121 checks) and `ui_audit_pins` (344 checks) pin every constant on both sides and every scan branch; the mutation run of section 7 | section 7 |
| 27 | minor | `escape_negatives_clean_up` tested its own cleanup | asserts stack, pause and phase right after each `escape_chain` returns, then cleans up | `ui_audit.escape_negatives_clean_up` |
| 28 | minor | `theme_override`, `no_theme` missing from the catalogue; no negative test | added to `DEFECTS`; planted fixtures; the section derives the raised codes from the library source | `ui_audit.every_raised_code_is_catalogued`, `every_defect_code_has_a_negative_test`, `neg_small_*_theme_override` |
| 29 | minor | R2 blind to gold painted in `_draw`, `StyleBoxLine`, theme text colours, `TextureProgressBar` tints | `separator` / `StyleBoxLine` / `StyleBoxTexture` colours, tints, theme-provided text colours, a source scan for `GOLD` / `GOLD_HOVER` / the hex values (allow-list `ladder_row.gd`, `rarity_slot.gd`, meta `tt_gold_ok`), documented limit in the header | `ui_audit_blind.blind_gold_source_scan_without_the_meta`, `ok_gold_draw_allow_list_ladder_row`, `ok_gold_source_scan_meta_exemption`, `ui_audit_pins.pin_gold_source_scan_names_gold_hover_and_counts_a_script_once` |
| 30 | minor | `ring_pixels` tolerates a missing side | every sampled pixel must show (n of n); `allow_missing_sides`; the report prints gold and ink counts separately | windowed `blind_ring_clipped_*`, `blind_ring_covered_on_two_sides`, `blind_ring_always_on_*` |
| 31 | minor | blind spots of `focusable_report` (own `gui_input`, `_input` clicks, accessibility focus, windows created on press) | `reads_mouse_in_input`, self-connected `gui_input`, `FOCUS_ACCESSIBILITY` is not a keyboard stop, a source scan for `ConfirmationDialog.new()` / `popup_centered()` (comments skipped) | `ui_audit_blind.blind_mouse_only_*`, `blind_focus_accessibility_*`, `ui_audit_pins.pin_window_scan_*` |
| 32 | minor | `escape_chain` waits N frames, the registry cannot pass `settle` | frames first (default 3), then polling up to `settle_seconds` (default 0.25 s) until the stack or the internal depth moves; `escape.settle_seconds` in the registry | `ui_audit_blind.ok_two_modals_fade_*`, `two_modals_settle_returns_as_soon_as_the_stack_moves`, `ui_audit_pins.pin_escape_default_settle_is_three_frames` |
| 33 | minor | unknown options silently switch checks off; default `max_steps` 200 truncates | `OPTION_KEYS` + `validate_options` for every function and for registry rows (`bad_option`, check `<id>.options`); `max_steps` 0 = automatic (8 per control + 60, 200 .. 4000) | `ui_audit.neg_bad_option_*`, `registry_valid_is_not_vacuous`, `ui_audit_blind.auto_steps_scales`, `ui_audit_pins.pin_registry_walk_uses_the_automatic_budget` (56 of 56 reached) |

Beyond the 33, the pins found and fixed (in this edit): the internal-layer crash (21), ten unreachable branches (section 7), a SpinBox finding (spec 10.3: a `SpinBox` is walked through its `LineEdit`, which eats Up / Down KEYS like every field, so it is a `trap` via key until `UiNav.yield_updown_from_fields` covers it), and a registry finding (`settings` sets `pages: false`: the language and window-size chips have side effects and no page behind them).

---

## 4. Files of the worktree to be committed (branch `ui-audit`)

All are new (untracked) files; `.uid` files are tracked in this repo and are included (copied from the clone Godot generated them in).

```
tests/lib/ui_audit.gd                 tests/lib/ui_audit.gd.uid
tests/lib/ui_audit_rules.gd           tests/lib/ui_audit_rules.gd.uid
tests/lib/ui_screens.json             (= design_ui/ui_screens.proposed.json)
tests/sections/ui_audit.gd            tests/sections/ui_audit.gd.uid
tests/sections/ui_audit_blind.gd      tests/sections/ui_audit_blind.gd.uid
tests/sections/ui_audit_pins.gd       tests/sections/ui_audit_pins.gd.uid
tests/fixtures/ui_audit/              bad_literal.tscn, bad_literal_script.gd, closed_screen.gd, conforming.tscn, custom_focus.gd,
                                      driver_esc_opens.gd, driver_modals.gd, driver_screen.gd, en_label.gd, esc_opens_pause.gd,
                                      hotkey_leaker.gd, key_hook.gd, modal_screen.gd, modal_screen.tscn, modal_screen_two.tscn,
                                      modals.gd, no_focus_mode.gd, plants.gd, ring_slider.gd, screen.gd, ui_screens_fixture.json
                                      (each .gd with its .gd.uid)
```

Ownership: `tests/lib/**` is already P09's; `tests/sections/ui_audit*.gd` and `tests/fixtures/ui_audit/**` are added to P09's `ownsAdd` in `ui_packages.json`. The lead copies `UI_NAVIGATION.md` to `docs/design/UI_NAVIGATION.md`; `ui_packages.json` is merged by package id (a merge keyed by id never meets F9).

Not in the worktree, for the lead: the spec, `ui_packages.json`, `legacy_audit.txt`, the probes and the tools of this edit stay under `.pongpong-build/work/design_ui/`.

---

## 5. Legacy audit findings (what the library says about today's screens)

Source: `design_ui/legacy_audit.txt`, produced by `UI_AUDIT_REPORT=<file> tests/run_playtest.sh --only=ui_audit` (41 findings). In the normal harness these print as KNOWN-GAP lines (never green) and each listed gap is a check that fails the day it disappears without its flag being removed from the row.

| Screen (scene) | Findings |
|---|---|
| title (`scenes/main/main_menu.tscn`), 16 | `no_initial_focus` x1 (the keyboard cannot start: focus owner NONE on open, after `ui_down` still NONE, only Tab wakes the first control: `keyboard_start` x1); `disabled_focusable` x1 (the disabled Fortsæt button is a focus stop); `hardcoded_literal` x7 (PongPong, Et fortryllet landbrugseventyr, Nyt spil, Fortsæt, Indstillinger, Sprog, Afslut written into the scene); `not_localized` x6 (the same strings do not change with the language) |
| character select (`scenes/ui/character_select.tscn`, rows `select_1` / `select_2`), 25 | `no_initial_focus` x1 + `keyboard_start` x1; `only_via_tab` x3 (farm name field, Bekræft, Tilbage are unreachable with arrows or pad); `trap` x1 (the name field: focus enters, no `ui_*` press leads back); `window_in_screen` x1 (the `OptionButton` popup is a Window); `disabled_focusable` x1 (the dashed, disabled "selected" species button takes focus); `hardcoded_literal` x7; `not_localized` x10 |
| 22 screens without a scene | one SKIP line each with the owning package; a failing check the day a scene appears without its row being swept |

What the audit does not see (pixels, windowed): the flat dark background, the dark-on-dark title text, the plain pills, the missing key art, panel, double gold edge, "Dag N", race cards, ring, chips and preview. Those are measured by `tests/checkpoints/compare_guide.py` (title 7.55 against a target of 8, select 14.58 against 15) and by looking at the windowed screenshots. The hit-target findings that an earlier run showed are gone: the 32 px rule (D19) accepts the guide's own controls.

---

## 6. Amendments summary per package (full text in `ui_packages.json`; spec 9.3)

| Package | Wave | Change |
|---|---|---|
| **P28-ui-nav-foundation** (new) | 3b | owns `UiNav`, `TTScreen`, `UiHints`, `HintBar`, `UiConfirm`, the shared widgets `toast_stack`, `prompt_pill`, `whisper_line`, `TTSlider`, the `quantity_stepper` fix (one focus stop, +/-1, +/-5, accept), the theme (`theme.tres`, `build_theme.gd`: pill margins +2, `Bold14` / `Bold16`, slider icons), the fixtures `SCREENS` additions, `nav.csv`, `ui_nav` and `ui_conformance` sections, the pinned crops and the baselines of confirm / toasts / prompt; 15 tasks; acceptance runs the three audit sections |
| P07-ui-foundation | built (3) | `assets/ui/theme.tres` ownership moves to P28; P07's checks stay green after the regeneration |
| P01-project-config | built (1) | one reopened task: the two actions of 4.7 only (no other new action) |
| P03-loc-core | built (2) | the `nav.csv` and families of Appendix B |
| P09-test-harness | built | `ownsAdd` the three audit sections and `tests/fixtures/ui_audit/**` |
| P06-player-farm-core | 4 | depends on P28; the hotbar contract is pinned by a shape test |
| P16-ui-menus | 4 | depends on P28; new pause rows Rygsæk / Opgavebog / Byg (guarded, a gamepad has no I / J / B); `UiConfirm` replaces the `ConfirmationDialog` task; ToastStack on the title and select; title Esc is inert (key, pad B, Start); baselines settings / select_2 / saveload / pause; 10 tasks |
| P17-ui-hud | 5 -> 4 | `ownsAdd` only `area_banner` (script, scene, baseline); toast / prompt / whisper widgets moved to P28 and instanced; whisper on the farm HUD and the construction chip placement; `outline_size 3` for the area name; dependsOn [P02, P07, P28] |
| P18-ui-shop-inventory | 4 | depends on P28; I and Tab through `_input` (F2); the shop asks the "Tag på nu?" `UiConfirm`; uses the amended stepper, does not edit it |
| P13-quests-lua-runtime | 4 | small API additions, the Lua schema is unchanged |
| P14-npc-dialogue | 5 | depends on P28; owns `localization/ui.csv` (deletes `DIALOGUE_CONTINUE_HINT`) and the intro baseline; the dialogue dispatches `ui_accept` itself |
| P19-forest-combat | 5 | depends on P28 (not P17); minimap baseline |
| P20-animals-buildings | 5 | depends on P28; animal care and build menu baselines; the Byg pause row opens the build menu as a transfer |
| F7-home-ui | 5b | depends on P28; `INDRET_ONLY_HOME`; home chest baseline; the draw-only components use the `FocusProxy` pattern |
| F8-wardrobe-ui | 5b | depends on P28; `wardrobe_ui.after_buy_prompt` |
| P25 / P26 / P27 / F10 | 6 / 6 / 7 / 7 | depend on P28; P26 no longer prunes `DIALOGUE_CONTINUE_HINT`; P27 baseline wording |
| F9-collection | optional | in `optionalAmendments` (not in `owners.json`): applies only if the lead schedules it; with F9 absent every other check still passes |

---

## 7. Verification numbers

All runs in APFS clones of the worktree (`clone_run.sh`), Godot 4.7.2, `--strict`.

| Run | Result |
|---|---|
| Baseline before this edit (section `ui_audit` only) | 378 checks, 0 failed, 1.4 s; the full strict harness of the reviewers: 2 248 checks |
| Headless sections after this edit (`--only=ui_audit,ui_audit_blind,ui_audit_pins`, `--no-boot`) | **904 checks, 0 failed**, 23 skipped (22 pending screens + one windowed-only line), 0 engine errors; `ui_audit` 439 (5.3 s, bar 10 s), `ui_audit_blind` 121 (4.5 s), `ui_audit_pins` 344 (1.4 s) |
| Windowed (`tools/dev/run_windowed.sh --only=ui_audit,ui_audit_blind`, one window, the PNGs were looked at) | **54 checks, 0 failed**, 0 engine errors / warnings |
| FULL harness, character animal, `--strict` (no `--only`, fresh clone, `final_runs/full_animal.log`) | **15 sections, 2774 checks, 0 failed**, 32 skipped, 0 engine errors, 0 engine warnings, 26 allowed messages (the project's own provoked ones), 0 known-issue messages, ~80 s; the three audit sections inside it: 439 + 121 + 344 checks, 5.2 s / 4.4 s / 1.3 s |
| FULL harness, character fairy, `--strict` (no `--only`, fresh clone, `final_runs/full_fairy.log`) | **15 sections, 2774 checks, 0 failed**, 32 skipped, 0 engine errors, 0 engine warnings, 26 allowed messages (the project's own provoked ones), 0 known-issue messages, ~80 s; the three audit sections inside it: 439 + 121 + 344 checks, 5.2 s / 4.4 s / 1.3 s |
| FULL harness, character hobbit, `--strict` (no `--only`, fresh clone, `final_runs/full_hobbit.log`) | **15 sections, 2774 checks, 0 failed**, 32 skipped, 0 engine errors, 0 engine warnings, 26 allowed messages (the project's own provoked ones), 0 known-issue messages, ~80 s; the three audit sections inside it: 439 + 121 + 344 checks, 5.2 s / 4.4 s / 1.3 s |
| Mutation, headless (357 mutants against the three sections; `final_tools/mutate_final.py`, 6 parallel clones, results `final_tools/final_mutation_results_FINAL.json`, log `final_runs/mut_run_final.txt`) | **350 killed** (345 by a failing check, 5 by an engine error), **7 survive**: 3 are windowed-only (killed in the windowed run, next row) and 4 are equivalent (below). The technical review's own 277 mutants left 110 survivors against the old section (run 1 of this edit, before the pins); the final run has no non-equivalent survivor |
| Mutation, windowed-only mutants (`final_tools/mutate_windowed.py`: one window per mutant, `ui_audit` + `ui_audit_blind`) | **3 of 3 killed**: `ring_allow_default_1` by `ui_audit_blind.blind_ring_clipped_on_one_side`, `ring_none_threshold_strict` by `ui_audit_blind.blind_ring_always_on_with_one_side_missing` (a gold frame on three of four sides: new windowed test, PNG looked at), `auto_pick_off` by `ui_audit.auto_pick_finds_gallery_controls` |

Equivalent mutants (documented, not hidden):

* `escape_opener_focus_freed_off` (`is_instance_valid(x)` replaced by `x != null` where the opener's path is recorded): in Godot 4.7.2 a freed Object stored in an Array compares `== null` (probe `final_probe_freed.gd`), so the two conditions are the same; the typed-assignment crash of defect 21 is pinned separately (`pin_escape_freed_opener_is_noted_not_judged`).
* `font_family_variation_off` (not looking through a `FontVariation` by hand): `FontVariation.get_font_name()` forwards the base font's name (same probe), and the family test reads the resource path OR the name; the explicit unwrapping only adds the path as a second witness.
* `initial_visible_off` (dropping `is_visible_in_tree()` of the focus owner in `initial_focus`): Godot releases a control's focus the moment it is hidden, so a hidden focus owner cannot exist; the clause is a guard against an engine change.
* `walk_pad_visible_off` (dropping "the edge's target is visible" in the pad check): the walk merges edges first-wins, so a visible source whose recorded edge leads into a page that is closed again exists only for a control first reached on a later page; two constructed layouts (empty page 0 plus a shared footer, select-on-focus and press-to-select tabs) did not produce one. The guard stays as a defence against a false `pad_mismatch` and is pinned from the other side (`pin_pad_check_skips_targets_on_a_closed_page`, `pin_pad_check_ignores_an_edge_into_a_closed_page`).

Ten code paths that no behaviour could reach were deleted instead of being pinned (each had a surviving mutant that proved it dead): the class-name branch of the ornament test, the `TTSlider` class-name fallback of the slider verdict (`TTSlider` sets the meta), the redundant stack clause of the end-of-chain phase check, the single-opener `elif` of the escape chain (merged), the comment skip of the window scan, the shadow-alpha skip of the red scan, the early-return list of `style_info`, `gold_n > 0` in the ring verdict, `not s.editable` in the slider probe, and the file-read fallback of `node_scripts`.

The 26 "allowed engine messages" of the full harness are the project's own provoked ones (unknown character ids, a corrupt settings file, refused modal names and the like); none comes from the audit.

---

## 8. The P17 wave decision

**P17 (HUD) moves from wave 5 to wave 4**, with contract-only dependencies on P06 and P13 (spec 9.2, D7). Reasons: the user-visible fact is that the farm shows no HUD at all today (`4_world_hud.png`); P17's real dependencies are P02 and P07 (built) and the EventBus contracts of P06 / P13 (`hotbar_changed`, `player_stats_changed`, `player_health_changed`, `interaction_prompt_changed`, `quest_*`, `notification_posted`: declared and arity-linted since wave 2, hotbar entries `{id, amount, name?, rare?}`), `QuestManager.get_tracked` has a working fallback, and the one player-API call (the slot click) becomes a synthetic `slot_n` action. `hud.integration_player_quests` runs after the wave-4 merge. P06's gate screenshots do not need a HUD (the review caught the earlier sentence: removed), so the move rests on the HUD-less farm, not on them. Because P16 and P17 are both wave 4 and may not build on each other, the shared widgets (toast stack, prompt pill, whisper line) moved to the new **P28 in wave 3b** (between 3 and 4, like the existing 5b); P19 depends on P28, not on P17; P17 now owns only the area banner.

---

## 9. Known limits and decisions taken

Known limits (stated in the library header and in 10.x of the spec):
* R2 gold that a script paints from run-time numbers (a `Color(r, g, b)` built in code) is invisible to the node and source scans; the windowed pixel checks and the compare shots cover it.
* A `SubViewport` has its own focus and is not walked.
* Enter is not typed into text fields by default (it submits; the select page would start the game): `options.press_enter` opts in, a note says so.
* Windowed checks (`ring_pixels`, `panel_pixels`, `button_pixels`, the compare shots) need a window and print as SKIP headless; they are proven by the windowed runs above.
* `TTSlider`, the stepper fix, the shared widgets and the theme margins are P28 deliverables: until they land the foundation gallery row carries the temporary `hit_min` 28 and the theme rows the pending status.

Decisions taken (all in Appendix F, the lead or the user may overturn them): D9 `ui_accept` is never eaten in `_input`; D12 guide shots keep the gold MenuRow / ChoiceRow focus and release only ring controls; D17 the registry's `status` is derived and never edited by owners; D19 hit targets 32 / 20 px; D20 `PanelToast` / `PromptPill` keep their gold borders; D21 the widgets belong to P28; D22 the select ceiling stays 15; D23 the Esc depths of the registry; the Byg pause row; the default `settle_seconds` 0.25 s; `max_steps` automatic; Enter opt-in; `pages: false` on the settings chips.

---

## 10. Open questions for the user (only real decisions)

1. **Q1 - the HUD look.** The style guide section 06 (what P17 builds by default) and the newer sketch `Miljøer v2` disagree: the sketch (showHud default on) has top-left "Forår - Dag 14" over "Tirsdag - 10:20 - Solskin" in Plex Mono, top-right money plus a horizontal Energi bar in one panel, the area name top centre, an 8-slot hotbar of 58 px with a 3 px gold selected border and a 2 px ink ring, inset double-gold rims; the guide has date and money left, quests right, a vertical Energi meter and the hotbar bottom. You said the newer sketches are binding look. Which HUD do we build? (Default until you answer: the guide's layout, with only the area-name banner taken from the sketch. Changing it later costs P17's layout task only, not the navigation model.)
2. **Q2 - the playable roster.** The sketch `Figurer v2` lists playable ("Spilbar") characters Rasmus (Ræv, Skovdyr), Kiki (Abe, Skovdyr), Bertil and Bodil Bøgeknop (Halvling), Kløvermynte and Birk (Fe, tag Hyggebyen); the built roster (`lua/config/characters.lua`) is Ræv / Kanin / Pindsvin / Egern, Eng / Stjernestøv / Skumring, Pip / Mos / Tornebusk. Which roster does the character select show? (Default: the built roster; the select screen reads the Lua config, so either choice is data, not navigation.)
3. **Q3 - gold borders on toasts and the prompt pill.** `PanelToast` and `PromptPill` are built with gold borders that the guide does not draw (plan R.12: no other use of gold outlines). Keep them (recorded deviation D20) or turn them into ink borders in P28 (a theme change that touches no screen)? (Default: keep.)
4. **Q4 - Samlerbog (F9).** The collection book is optional and not in `owners.json`. Ship it (the lead schedules F9; spec card S25 and the `C` key are ready) or leave it out (the pause row and the hotkey simply do not exist; every other check passes either way)? (Default: out.)
