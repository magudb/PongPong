# HANDOFFS - ghost family (Familien Natlys), final edit

Exact texts for the people and tracks whose files this design does not edit. Nothing here edits, regenerates or proposes an in-place change of Codex's files (`tools/art/drawn/**`, `tools/art/storybook/**`, `tools/art/README.md`, the existing `assets/isometric_characters/*` folders, `assets/iso_props/drawn*`, `assets/iso_tiles/drawn_*`), of the clock track's files or of the lead's tools.

## H1 - to the clock track (final editor of `CLOCK_26_ADDENDUM.md` / `clock_packages.json`)

State found (`design6/clock/clock_packages.json`, 2026-10-15 02:21): the final round made CK-A-GFD and CK-A-GFQ contract level and they agree with the family design (the family's own night, the lantern house 17-25, `ghostfam_data.presence_after_midnight` defined by the family only). **One literal is left** in CK-A-GFD task 3 and it contradicts the family's own module, whose Gnist reads the building row's close (25 with the lantern house open until 01:00, 23 with `close = 23`):

* now: `ghostfam_data.dialogue_branches_run gains the contexts Tuesday raw 24 and 25 (Gnist's closed / early branches read the RAW stored hour: hour >= 23 closed, hour < 17 dawn, and the weekday of the game day) -> verify: ghostfam_data.dialogue_branches_run`
* replace with: `ghostfam_data.dialogue_branches_run gains the contexts Tuesday raw 24 and 25 (Gnist's closed / early branches read the RAW stored hour AND the building row, never a literal: weekday == 2 closed, hour >= the row's close (25 with the lantern house open until 01:00, 23 with close = 23) 'the lamps are being put out', hour < 17 early; and the weekday of the game day) -> verify: ghostfam_data.dialogue_branches_run`

With this rewording the family's top-level `supersedes` entry (which drops any CK-A-GFD task containing `hour >= 23 closed`, and for safety any task of the first version of CK-A-GFD / CK-A-GFQ that wanted the lantern house closed after midnight) matches nothing and is harmless. Until the rewording lands, `apply_designs_deferral.patch` drops the old task and the family's `replacementText` stands in.

**A second literal, outside the family:** CK-A-TD (T-director) check `passout_in_shop_is_evicted_by_hours` says "the closing sequence has already run at <= 23:30". With the family's lantern house open until 25:00 (its closing sequence runs at 24:30-25:00) that is false for a pass-out inside that shop. Reading the close from the data fixes it: "... and the closing sequence of THAT shop has already run (its building row's close: <= 23:30 for every shipped shop of the 30 citizens, 25:00 for the family's lantern house)". If the user answers the family's Q1 with "no" (`close = 23`) the literal is true again.

The clock track defines no check in a family section (its own check G) and the family defines no check of the clock track: nothing else overlaps.

## H2 - to the lead

1. `impl/tools/apply_designs.py`: the SRC entry GHOSTFAM must point at `work/design6/FINAL/family/ghostfamily_packages.json` and CLOCK must be the LAST entry (CLOCK_26 section 11). Apply `design6/FINAL/family/apply_designs_deferral.patch` (honours `deferred` / `deferredTasks` and the top-level `supersedes`; tested on a scratch copy with the real owners.json, orders and the current clock file: `final_edit/logs/apply_designs_patched_dry.txt`, `final_edit/dry/run_dry.sh`). Without it nothing of the family runs early (the deferred tasks are not under `tasks`), but the one superseded clock task is not dropped (H1 removes the need).
2. After `--apply`: `impl/fixround4.json` holds no family task (only the empty carve-out AGF9 of the built P12); `impl/deferred_amendments.json` lists the 11 deferred amendments with their gates. They are executed as ONE fix-round at the G5c gate (after wave 5b), AGF1b with GF-quests, AGF15 / AGF21 with GF-quests / GF-seek (wave 6).
3. Copy into the repo (`docs/design/`): `DESIGN_GHOSTFAMILY.md` -> `GHOST_FAMILY_ADDENDUM.md` (full replacement of design5's), `ghostfamily_packages.json` -> `ghostfamily_workpackages.json`, `OPEN_QUESTIONS.md` -> `GHOST_FAMILY_OPEN_QUESTIONS.md`, `CHANGELOG.md` -> `GHOST_FAMILY_CHANGELOG.md`. The data to lift is in `data/`, `loc/`, `sim/`, `scripts/`, `art/` of this folder (every package's `lift` list names its sources).
4. Sanctioned edits unchanged except: SE-GF4 (the cross-write into `ghost_bu` / `ghost_hviske`) is OPTIONAL and changes nothing a ghost player sees (H3). The key-owner entries are in `data/tools/loc/ghostfam_key_owners_additions.json` (`ghostfamily_seek.csv` has 22 rows now, same prefix `SEEK_GHOSTFAM_`).
5. After the merge re-run: `python3 scripts/check_own6.py` (9 documented carve-out overlaps, F and G clean), `python3 scripts/check_pkg_schema6.py`, `python3 scripts/economy_check6.py <repo>`, `python3 sim/check_family6.py` (after the E3 bake: the festival walk-back check re-runs on the real route times).

## H3 - to A2-art-wardrobe and Codex: the player's ghost is not painted by the family route

Facts (verified): `GHOST_ADDENDUM.md` 4.3 - the ghost skins draw `<skin>_base` (`ghost_bu_base`, `ghost_hviske_base`); the chain `ghost_bu_base -> ghost_bu -> rabbit` "is only used while the art is missing". `impl/owners.json`: A2-art-wardrobe (wave 4) owns `assets/isometric_characters/ghost_bu_base/**` and `ghost_hviske_base/**`; A2's order bakes them with `ghost_model.make_ghost` in 3D and bakes the wardrobe layers (hat, shirt, dress, necklace, bracelet, earrings) in 3D against that body with its alpha as the occluder (`validate_wardrobe_assets.py`). Codex's roster is imagegen paintings packed by `pack.py`; its heroes (`fox`, `fairy`, `hobbit_pip`) are painted without wardrobe layers.

Consequence: the painted `ghost_bu` / `ghost_hviske` that `pack_ghosts.py` produces replace the stock sheets and the fallback only; a ghost player draws A2's 3D base and sees the painted family next to it. A painted body deformed by the packer's 2D puppet cannot carry A2's 3D layers. The same holds for the other heroes once they are painted.

What the family design already does: states it (DESIGN 9.1, 12, `OPEN_QUESTIONS.md` Q4), measures the family's silhouettes against BOTH the stock hero and the on-screen base (`measure_family.py` / `check_sources.py --hero-base-root assets/isometric_characters`, with a control that fails), keeps SE-GF4 optional.

Questions for A2 / Codex / the user (none is a ghost-only task): (a) is a painted-plus-wardrobe route wanted for the heroes (a 2D layer system that registers to the puppet, or hero bases painted WITHOUT layers and the wardrobe drawn as 2D overlays)? (b) cheaper: give A2's ghost bases the same storybook finish as the stand-in (RGB only, alpha untouched, so the occluder alpha is unchanged; the layers would need the same finish to match in colour: A2 to check). Until decided nothing in the family depends on the answer.

Optional lines for Codex, only if Codex prefers the six ghosts in its own `CAST` (the wrapper `pack_ghosts.py` needs none of it; `pack.py` is untouched):

```python
# tools/art/drawn/pack.py
HEIGHTS.update({'ghost_bu': 158, 'ghost_hviske': 158, 'ghostfam_dyne': 163, 'ghostfam_gnist': 182, 'ghostfam_silke': 158, 'ghostfam_blund': 114})
CAST['ghosts1'] = ['ghost_bu', 'ghost_hviske', 'ghostfam_dyne', 'ghostfam_gnist']
CAST['ghosts2'] = ['ghostfam_silke', 'ghostfam_blund']   # main() calls extract(path, 4, 4): it must become extract(path, len(cast), 4)
NORTH_GROUPS['ghostbacks1'] = ['ghosts1', 'ghosts2']     # main() extracts 16 rear figures and indexes norths[north_sheets.index(sheet) * 4 + row]: a 6-figure sheet needs extract(path, 2, 3) and a north-aware index
```

Without `ghost_puppet` and the 4 px hover the stock walk waddles: acceptable only as a fallback.

## H4 - to the user (the only person who can run the imagegen tool)

`art/prompts_ghosts.json` holds the three prompts (`ghosts1`, `ghosts2`, `ghostbacks1`), the three attachments (your cartoon style reference, `art/shape_reference/shape_reference_turnarounds.png`, `art/shape_reference/shape_reference_silhouettes.png`) and the checklist (seven lines). Nothing painted exists; the stand-in ships until you decide. Read the new `scope_of_the_painted_ghosts` field first: it says what the painted Pedro and Hviske do and do not change.
