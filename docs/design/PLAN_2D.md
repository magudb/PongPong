# TRÆTOPPEN - Integration Plan (2D rewrite of PongPong) - REVIEWED (adversarial critic amendments in section R apply first)

supersedes for the features: PITCH 6 note 'House interior and festivals: cut' (2.1) and the CUT row 'Farmhouse interior, festivals, friendship hearts UI, gifting, relationship events' (9.2): the home interior, a partial festival (button + event), friend gifts and the weekly chat heart are IN

supersedes for the towns, the farm and the social sim: PLAN 4.0's flat farm beside Hyggebyen, the CUT rows 'friendship hearts UI, gifting, relationship events' and 'festivals' (9.2) and the idea that shops are only a panel: the farm is the treetop farm Min Trækronsgård on its own branch, the citizens follow daily routines, every shop is a walk-in room with opening hours, and friendship hearts, gifts, birthdays, nine festivals, heart events and marriage-style relationships are IN: TOWNS_FARM_SOCIAL_ADDENDUM.md

Feature addendum (binding; it WINS over this plan wherever the two disagree on a feature topic): [PLAN_2D_FEATURES.md](PLAN_2D_FEATURES.md). Machine-readable work packages of the addendum: [features_workpackages.json](features_workpackages.json).

Towns, farm and social addendum (binding; it WINS over this plan wherever the two disagree on a town, farm or social topic): [TOWNS_FARM_SOCIAL_ADDENDUM.md](TOWNS_FARM_SOCIAL_ADDENDUM.md). Machine-readable work packages of the addendum: [towns_farm_social_workpackages.json](towns_farm_social_workpackages.json).

Published copy of the reviewed plan (`docs/design` is owned by P01 and is hidden from the Godot importer by `docs/.gdignore`). Read-only reference for every package: a contract change is announced in the commit/PR message of the package that makes it and re-published by editing this file only through P01's owner at the next wave boundary.

Project root: `/Users/magnusudbjorg/Documents/projects/PongPong` (folder name stays; product name is **Trætoppen**, tagline "En gård i Fekongens skov").
Engine: Godot 4.7.2, GDScript. Target: PC 16:9, Danish first, English fallback.
Written by the synthesizer from: 11 audits (3D code), 3 spikes (world tech, UI, art), the Trætoppen Style Guide v0.1 (HTML read in full, four sketch JPGs looked at), the character pack, and checks run while writing this plan.

## R. Adversarial review amendments (BINDING - they supersede any conflicting sentence further down)

This file is PLAN.md regenerated from the same sources with every correction below applied inline (section numbers unchanged; package headers, owner lists, wave table, contracts and the acceptance matrix already reflect the amendments). Every item states what was checked, what was found (with evidence you can re-run; probes live in `scratchpad/critic/`) and the rule that replaces the old text. Items are ordered by how badly they would have hurt.

### R.0 What the critic checked and how

| Check | Method | Result |
|---|---|---|
| Style guide | read all 472 lines of `Trætoppen Style Guide.dc.html` (palettes, `renderVals()`, every screen), looked at all spike screenshots listed in the spike reports (cast_all32, farm f00000039, forest, Hyggebyen, title key art, UI comparisons) | layout/colour/type claims hold; deviations listed in R.12 |
| Project setting enum | Godot 4.7.2 headless probe of `ProjectSettings` hint string and `ClassDB` enums | **`default_texture_filter=3` is "Nearest Mipmap", not linear** (R.1) |
| Lua parser on the plan's new shapes | scratch copy of the repo, scene driver calling `LuaRuntime.parse_lua_source` on the plan's `lost_cat` shape (`any_of={...}`, nested `friendship`, `have=false`) and on a `kind="shops"` file | quest shape parses completely; **shops/recipes tables are NOT extracted** (only `objectives, rewards, items, config, lines, choices, meta` are) - so the Lua kinds work is real new code and gates wave order (R.2) |
| CSV importer | scratch project: new `a.csv` vs `b.csv` + `b.csv.import importer="keep"` | new CSVs generate `a.da.translation`/`a.en.translation` junk and drop out of exports; `keep` is honoured (R.4) |
| Import cost / disk | scratch copy of the 12-character pack: first import, then S3TC presets, then hand-written `.import` stub | 64 s first import (lossless) + 17 s S3TC pass for 12 characters; S3TC cache is 33 MB per full character (fox, 11 clips; 402 MB of `.godot/imported` for the 12-character pack) -> about 1.2 GB for all 45 characters plus tiles/props (estimate from the clip sets); disk has 63 GB free; **a hand-written minimal `.import` is honoured on the very first import** (R.7) |
| User voice MP3s | `ffmpeg` -> 16 kHz wav -> `faster-whisper small`, `language=da`, all 14 files | **11 of 14 recordings are reusable verbatim**; none says "PongPong" (R.5) |
| Spike UI smoke | read `ui_smoke.gd` / `ui_fixtures.gd` | loads 11 screen scenes, nine of them owned by later packages (R.3) |
| Spike `ui.csv` vs plan CSV owners | diffed keys | `UI_CURRENCY`, `RECIPE_*`, `ITEM_*`, `SHOP_*` already inside `ui.csv` while P03/P12 also claim them -> P03's own lint would fail (R.4) |
| Ownership / layering | re-ran the plan's checker (`_src/check.py`) on the amended data | 0 unowned, 0 double-owned, every dependency points to a strictly earlier wave (see R.2 table) |

### R.1 Texture filter: the project default must be 2 ("Linear Mipmap"), never 3 (guide-mismatch, MAJOR)

Evidence: `rendering/textures/canvas_textures/default_texture_filter` has hint string `Nearest,Linear,Linear Mipmap,Nearest Mipmap` (0..3) in Godot 4.7.2. The plan (3.1, P01 task 1, 6.2 "Import" row, P05 task 2) wrote `=3` and called it "linear + mipmaps (smooth, NOT pixel art)". 3 is **Nearest Mipmap**: sprites are blocky when magnified (any window larger than 1280x720 combined with zoom 0.7) and shimmer when minified. The world spike's 40 verified screenshots used the default (1, Linear, no mipmaps); the art spike used 3 and was only looked at at one static zoom. `CanvasItem.texture_filter` is a different enum (0 parent, 1 nearest, 2 linear, 3 nearest mip, 4 linear mip) - mixing the two enums was the root cause.

Rule: project default **2**. Set explicit per-node values instead of trusting the default: `IsoArea/Ground` (TileMapLayer) `texture_filter = 2` (TEXTURE_FILTER_LINEAR, no mipmaps) and the tile atlases are imported with `mipmaps/generate=false` (periodic atlas cells would bleed into each other at mip >= 1); `IsoArea/Objects`, characters, props, backdrops `texture_filter = 4` (LINEAR_WITH_MIPMAPS); UI inherits the project default. `[importer_defaults] texture mipmaps/generate=true` stays for sprites/props/icons. Verification is **windowed** (R.6): `tests/windowed` probe renders the farm at zoom 0.3/0.4/0.7 x window 1280x720/1920x1080/2560x1440 and asserts no hairline seams (neighbouring-tile luminance step < 3/255 along tile borders) and no block edges; fallback if seams appear at mip >= 1: default 1 and mipmaps off for characters (the world spike configuration). A headless check `p01.texture_filter_is_2` asserts the setting.

### R.2 Wave layering was wrong: wave 1 had hard internal dependencies (ordering, BLOCKER for the orchestrator)

Found by reading what each package must `load()`/call to pass its own gate:

* **P03 vs P01**: current `project.godot:124` lists the four `.translation` files; P03 deletes them. If P03 lands before P01 removes the list the project boots with "Cannot open file" errors. -> P03 depends on P01.
* **P04 <-> P06 circular**: `WorldRoot2D` (P04) must host a player; `Player2D` (P06) needs `Iso`, `IsoArea`, `GameData`, `Interactable2D` (P04). -> P04 ships `scripts/world2d/player_stub_2d.gd` (a 60-line CharacterBody2D + Camera2D honouring the contract `enter_area(area, spawn)`, group `player`) and loads `scenes/world2d/player_2d.tscn` instead when it exists; P06 depends on P04.
* **P06/P11/P07/P04 need P02 (signals), P05 (IsoChibiSprite2D, characters.lua), P10 (race perks/game_balance/npcs)**.
* **P12 and P13 both needed `LuaRuntime` kinds `shops`/`recipes`** (new code in `lua_runtime.gd`, owned by P13) while P13's quest tests need P12's `item_gained`/inventory. -> `lua_runtime.gd`, `tools/lua/**`, `addons/lua_runtime/**` and the parser/lint work move to **P10** (data contracts, earlier); P12 depends on P10; P13 depends on P12 and P10.
* **P02's calendar test needs translated month names** (keys in `ui.csv`, loader in P03) in the same wave -> P02's test uses an injected temporary `Translation` for the weekday/month keys; the real da/en text check is `hud.date_text_real_keys` (P17).
* **P22 gate needed forest maps (P19, later)**; **P19 needs the ortho-bake decision (P22)** -> P22 moves before P19; the "no placeholder left" check for the forest maps is P19's (`forest.maps_art_complete`).
* **Wave-3 gates quoted `compare_guide.py` (P27, last wave)** -> moved to P07 together with the reference PNGs.
* **P16/P06 tests start the default area before P11's `farm.map` exists** -> P04's WorldRoot2D falls back to `_fixture_iso` when `data/maps/farm.map` is missing.
* **P09's gate (boot menu -> select -> world for all 3 characters)** needs P04+P06; a harness package cannot own that gate -> P09 keeps harness + windowed mode only; the wave-4 reviewer runs the first full boot.
* **P15's gate (round trip of every system incl. crops, animals, Continue from the new menu)** needs P06/P12/P13/P20/P16 -> P15 is rescoped to SaveManager itself; the cross-system round trip is asserted by `farm.save_roundtrip` (P06), `animals.save_roundtrip` (P20) and `zz_acceptance` (P27).
* **P24 (voice) vs P26 (copy pass)**: a copy pass after voice generation desynchronises text and audio -> voiced keys are frozen for P26 (R.17).

**Corrected layering (7 waves; every dependency points to a strictly earlier wave; verified mechanically):**

| Wave | Packages | Hard dependencies (earlier waves only) |
|---|---|---|
| **1** bootstrap | P01 project-config, P08 art-tools, P09 test-harness | none |
| **2** contracts | P02 bus-gamemanager-time (P01,P09), P03 loc-core (P01,P09), P05 characters-pack (P01,P09), P10 data-contracts + LuaRuntime (P01,P09) | W1 |
| **3** framework + services | P04 area-framework (P01,P02,P03,P05,P09,P10), P07 ui-foundation (P01,P03,P05,P09,P10), P12 economy-shop-crafting (P02,P03,P09,P10), P15 save-system (P01,P02,P09), P21 art-characters (P05,P08,P09,P10) | W1-W2 |
| **4** gameplay core + screens + art | P06 player-farm-core (P02,P04,P05,P10,P12), P11 maps-iso (P03,P04,P05,P10), P13 quests (P02,P03,P10,P12), P16 ui-menus (P02,P03,P04,P05,P07,P15), P18 ui-shop-inventory (P03,P07,P12), P22 art-environment (P04,P08,P09), P23 art-icons-keyart (P07,P08,P12) | W1-W3 |
| **5** content | P14 npc-dialogue (P02,P03,P04,P05,P06,P07,P10,P12,P13), P17 ui-hud (P02,P06,P07,P13), P19 forest-combat (P04,P05,P06,P07,P10,P12,P13,P22), P20 animals-buildings (P04,P05,P06,P07,P12,P13) | W1-W4 |
| **6** finish | P24 audio-voice (P12,P13,P14,P16,P20), P25 docs-refresh (P12-P14,P16-P22), P26 loc-final (P03,P12,P13,P14,P16-P20) | W1-W5 |
| **7** acceptance | P27 qa-acceptance (everything) | W1-W6 |

First runnable 2D world: end of wave 3 (P04 + player stub, placeholder art); first playable farm loop: end of wave 4; the legacy 3D flow only has to survive for the harness until wave 3 (P02 retypes `player_spawned` and stops touching the mouse; the legacy 3D `world.gd` still captures it until P04 deletes it). Close the Godot editor that is open on the repo (PID seen with `--editor`) before wave 1 and reopen it after wave 7: an open editor reimports on focus and can overwrite rewritten scenes.

### R.3 `ui_smoke` cannot pass in the wave that owns it (missing-verification, MAJOR)

`scenes/ui/dev/ui_smoke.tscn` (123 checks) and `ui_fixtures.gd`/`shot_runner` instantiate `main_menu`, `character_select`, `hud`, `shop_ui`, `dialogue_ui`, `quest_journal`, `inventory_ui`, `forest_hud`, `pause_menu`, `settings_ui`, `save_load_ui` - nine of them are created by P14/P16/P17/P18/P19 (wave 3 in the original plan, waves 4-5 now) and the shop/inventory fixtures also need `CraftingSystem` (P12). P07's gate "ui_smoke passes" is therefore unsatisfiable.

Rule: P07 owns a **foundation smoke** (components gallery, theme/fonts/Æ Ø Å, `GameUI` dynamic loader, `tt_*` helpers, stretch at 5 window shapes, raw-key sweep of the gallery). Each spike `_title/_select/_hud/_shop/_dialogue/_journal/_inventory/_forest/_pause/_saveload` function is lifted by the screen's owner into that owner's `tests/sections/<name>.gd` (P16: title, select, pause, settings, saveload; P17: hud; P18: shop, inventory; P14: dialogue, journal; P19: forest) and runs against the real managers. `ui_fixtures.gd` loads a screen only if its scene exists and reports SKIP otherwise.

### R.4 CSV ownership collisions and the CSV importer (ownership-overlap + other, MAJOR)

1. **Key collisions** (diffed against the spike `ui.csv`, 90 rows): `UI_CURRENCY` is in `ui.csv` (P07) *and* in P03's `core.csv`; `ui.csv` already holds `RECIPE_MUSHROOM_LANTERN/SCARECROW/HONEY_CAKE/IRON_PICKAXE`, `ITEM_MUSHROOM_LANTERN/SCARECROW/HONEY_CAKE` and five `SHOP_*_GREETING` rows that P12's `economy.csv` must own; P03's `core.csv` also claimed `ITEM_GEM_BAG/COMPANIONSHIP/EGG...`, `ITEM_BABY_FAWN_DESC`, `ITEM_BARN_KIT_DESC`, species names and 15 `OBJ_*` that P12/P20/P13 define in their own files. P03's lint rule "a key may live in only one non-legacy file" would fail the integrated tree. **Key ownership (binding):**

| Keys | Owner file |
|---|---|
| `GAME_*`, `NPC_*`, `ZONE_*`, `LANG_*` and the legacy overrides `UI_GOLD`, `UI_WEATHER_KLART` ("Solskin"), `UI_JOURNAL` ("Opgavebog"), `UI_INVENTORY` ("Rygsæk"), `NOTIF_QUEST_ACCEPTED_TITLE` / `NOTIF_QUEST_COMPLETED_TITLE` (the REAL legacy key names end in `_TITLE`; defining `NOTIF_QUEST_ACCEPTED` would change nothing), `NOTIF_LANGUAGE_CHANGED_MSG`, `CHAR_SELECT_TITLE`, `CHAR_ANIMAL_NAME` | `core.csv` (P03) |
| `UI_*` that are new (`UI_CURRENCY`, `UI_WEEKDAY_*`, `UI_MONTH_*`; the legacy `UI_SEASON_*`/`UI_WEATHER_*` rows stay in `da.csv`), `MENU_*`, `CHAR_*` (rest), `HUD_*` shared, `DIALOGUE_*` hints, `INV_*`, `WORKSHOP_*`, `QJ_*`, `SET_*`, `KEY_*`, `FOREST_*` | `ui.csv` (P07) - **minus** every `RECIPE_*` and `ITEM_*` row and every per-shop `SHOP_<SHOP_ID>_*` row (removed on lift; `SHOP_TAB_*`, `SHOP_TOTAL`, `SHOP_GREETING_DEFAULT` are UI strings and stay) |
| `ITEM_*`, `ITEM_*_DESC` (all but the ones below), `RECIPE_*`, `SHOP_*` | `economy.csv` (P12) |
| `ITEM_BABY_*`, `ITEM_<SPECIES>`, `BUILDING_*`, `ANIMAL_*` | `animals.csv` (P20) |
| `QUEST_*`, `OBJ_*`, `LUANOTIF_*` | `quests.csv` (P13) |
| `DLG_*` | `dialogue.csv` (P14) |
| `WHISPER_TOO_EARLY`, `WHISPER_FAINT`, `UI_SLEEP`, `NOTIF_PASSED_OUT` and other WorldRoot2D/bed strings | `world.csv` (P04, new) |
| `FARM_*`, flower/fishing whispers, `WHISPER_NOT_YET` | `farm.csv` (P06) |
| `SIGN_*`, area titles not in core | `areas.csv` (P11) |
| everything else of a package | that package's own csv |
| copy-pass overrides of NON-voiced keys | `zz_final.csv` (P26) - the only file allowed to redefine a key of another file; loaded last |

2. **CSV importer**: `godot --import` gives every new `*.csv` a `csv_translation` import and writes `<name>.da.translation`/`<name>.en.translation` beside it (verified). With the plan's D17 (stop ignoring `*.translation`) that would commit ~28 unused binaries, and, by Godot's export rule for imported resources (not run here: no export templates are installed), an export would pack the importer's output instead of the raw CSV so the runtime loader would find nothing. Rule: every `localization/*.csv` ships with a committed `<file>.csv.import` containing `[remap] importer="keep"` (verified honoured); `tools/loc/new_csv.py` (P03) creates both files; `csv_lint.py` and `LocalizationManager.lint()` fail when a CSV has no keep-import; **`.gitignore` keeps ignoring `*.translation`** (only `*.import` and `*.uid` stop being ignored).

### R.5 Use the user's recorded Danish voice (gap, MAJOR for pitch sentence 10b)

The plan archived all 14 MP3s because it "could not listen to them" and planned robotic macOS `Sara` TTS for every line. ASR (faster-whisper small, Danish) over the 14 files in sorted-filename order gives, with durations matching the old `docs/voice_lines.md`:

| # | file (docs/audio/) | s | text (canonical wording of `docs/voice_lines.md`, ASR-confirmed) | old id | reusable in the new copy? |
|---|---|---|---|---|---|
| 1 | 1791823969398-XkYBRO2dnQbph41KDHGk | 7.0 | "Velkommen, eventyrrejsende! Jeg er **Lyra**, feborgmesteren her i den magiske by" | lyra/greet_1 | no (names Lyra) |
| 2 | 1791824012718-XhN6eodgXp7gIt2bpHZt | 4.2 | "Feernes Konge har udvalgt dig i det årlige lotteri!" | lyra/greet_2 | **yes** |
| 3 | 1791824036719-si8CTUzlxgMGMJ72pLrA | 5.8 | "Du har vundet en fortryllet trækronsgård! Den venter på dig i skovens kroner." | lyra/lottery | **yes** |
| 4 | 1791824085445-0auAn0YGDoAXbWAscpWy | 2.1 | "Godt at se dig igen!" | lyra/hello | **yes** |
| 5 | 1791824160309-OCNsoALeBK43huEgZvav | 4.3 | "Din gård trives! Fortsæt det gode arbejde." | lyra/farm_status | **yes** |
| 6 | 1791824709447-y9NVUhrYK0p0nNgPEFTK | 3.5 | "Hej der! Velkommen til mit lille bageri." | maja/greet | **yes** |
| 7 | 1791824748828-z1IGw6RjwOnXdfeAxk7U | 5.3 | "Åh nej, stormen i går beskadigede mit tag! Kan du hjælpe mig?" | maja/roof_trouble | **yes** |
| 8 | 1791824782710-116CoJRbVKvq8pRTsvcL | 3.7 | "Tak for hjælpen! Taget er som nyt igen." | maja/thanks | **yes** |
| 9 | 1791824822587-0obK1buRXrie3XEqRKxI | 4.8 | "Jeg bager de bedste småkager i hele **den magiske by**." | maja/cookie_talk | **yes** (the recording says "den magiske by", not PongPong) |
| 10 | 1791825510331-E1UqlZBqpM23D7yO2f7M | 2.4 | "Hej... vil du lege?" | lily/greet | **yes** |
| 11 | 1791825588689-oSiDSeUVwkO8vJIykZ28 | 5.1 | "Min kat Mjau er væk! ..." | lily/cat_missing | no (the lost cat is Pippin's Morfar Mis) |
| 12 | 1791825614243-fZKtgAGVACjRsUXoDgT7 | 3.7 | "Har du fundet Mjau endnu? ..." | lily/worried | no |
| 13 | 1791825721345-6vzCxJlAT1xu9hxZ3zIy | 2.8 | "Hrmf. Velkommen til smedjen." | thorin/greet | **yes** |
| 14 | 1791825762850-h0WoDjHlLe0MHokrFQeA | 5.5 | "Den mørke skov er fuld af sjældne malmsten... men også farer." | thorin/mining_talk | **yes** |

Caveat: the small ASR model garbled some words (#1 "febormasteren", #6 "Velkommen til Migile Bærerik" for "mit lille bageri", #12 "en jav" for "Mjau") but agreed on every key phrase, on the order and on the speaker change at #6, #10 and #13; it never produced "PongPong". The mapping is therefore very likely but not proven by listening - hence the confirming question below.

Rules: (1) **P14 writes the new dialogue so that the 11 reusable lines appear verbatim** (same Danish text, canonical wording from `docs/voice_lines.md`, #9 with "den magiske by") on the speaker named above under the new roster (mayor_lyra = Borgmester Hyldeblomst etc.); the English column is free. (2) **P24 converts them** (`ffmpeg -ac 1 -ar 44100 -c:a libvorbis`) to `assets/audio/voice/<npc_id>/<line_id>.ogg`, lists them in `RECORDED.txt` (human recordings win) and archives the originals incl. #1/#11/#12 under `assets/audio/voice/_user_recordings_v0/`. (3) The generator synthesises only the remaining lines (about 90-120). (4) The user is asked one confirming question (they can listen; the ASR/duration/order evidence is strong). (5) Test: `voice.recorded_lines_match_text` (text of every RECORDED line equals the canonical text; P26 may not change it, R.17).

### R.6 Several acceptance checks cannot run headless - add a windowed category (missing-verification, MAJOR)

Headless Godot uses the dummy renderer: `area.render_not_blank` ("sample ground and sky pixels"), `player.sprite_visible` by pixels, tile seams, filter quality, guide diffs, boss visibility and the HUD diff targets cannot be asserted there, yet acceptance item 2 ("visible lit ground and sky, visible player") rests on them and the plan left them to "a human looks at screenshots".

Rule: tests/sections files may define `func run_windowed(t)`; `tests/run_playtest.sh --windowed` (P09 harness) runs only those, with a real window (`--resolution 1280x720`, closes itself in ~1 s per check) and **automated pixel assertions** (sampled ground/sky/player pixels differ from the clear colour and from each other; seam probe; diff numbers from `compare_guide.py`); the same run saves PNGs for a human. `tools/dev/run_windowed.sh` wraps it. Agents write the drivers; **the lead (or the user) executes windowed runs at each wave boundary** (about 3 minutes in total). Windowed-only checks (owner): `area.render_not_blank`, `area.filter_seams` (P04), `player.sprite_visible_pixels` (P06), `art.cast_matches_pack` (P21), `art.forest_ortho_readable` (P22), `hud.diff_<=9` (P17), `menus.title_diff` (P16), `forest.hud_diff` (P19), `zz.guide_diffs` (P27).

### R.7 Import cost, disk and `.import` stubs (infeasible as written, MAJOR)

* Measured on the 12-character pack: 64 s first import (lossless) then +17 s to re-import as S3TC; S3TC cache = 33 MB per full-clip character (fox: 11 sheets, 2.1-4.2 MB each) and the old lossless `.ctex` stay behind -> `.godot/imported` is 467 MB after the pack (402 MB S3TC + stale lossless) and about 1.2 GB with all 45 characters (400 MB measured + ~750 MB estimated for the 33 new characters' smaller clip sets, plus tiles/props/icons). `tools/dev/test_in_copy.sh` as planned ("rsync copy with its own `.godot`, persistent per package") would take up to 27 copies x ~1.2 GB (about 32 GB of the 63 GB free, plus the repo copies) and a 5-minute first import each.
* **Hand-written `.import` stubs are honoured on the first import** (verified: `importer="texture"`, `compress/mode=2`, `compress/high_quality=false`, `mipmaps/generate=true` -> only the `.s3tc.ctex` is produced). Therefore `tools/import/write_import_stubs.py` (P05; used by P08's exporter and P21) writes the stub next to every clip sheet **before** the first import; the "after the first import rewrite and re-import" flow (D17, P05 task 4) is dropped. `apply_import_presets.py` survives only as an audit (`--check`).
* `tools/dev/test_in_copy.sh`: seed the copy with an APFS clone of the canonical repo **including `.godot`** (`cp -Rc`), rsync only the changes, run, then **delete the copy** (persistent copies only for the three art packages). Never two imports in the same directory.

### R.8 Art tooling ownership and staging (ownership-overlap, MAJOR)

* P08's gate rebuilds the fox from source, but the generator base (`geometry.py`, `additions.py`, `build_assets.py`, `asset_io.py`, `render_assets.py`, `validate_assets.py`) was in P21's directory (`tools/art/characters/**`, wave 2, after P08). -> P08 owns the pristine base in `tools/art/generator/**` (with hook points `TT_BUILDERS`, `EXTRA_PATTERNS`, `EXTRA_CLIPS`, `m.slug`, `m.base_height` already present as optional imports); P21 owns only `tools/art/characters/**` (`traetoppen_additions.py` and new builders), P22 `tools/art/environment/**`, P23 `tools/art/icons/**`.
* Staging directory `export/` inside the project is scanned by Godot (WebP/PNG would be imported twice and gain `.import` files). -> staging moves to `tools/art/_stage/` (gitignored) and **`tools/art/.gdignore`** (owned by P08) hides all of `tools/art/` from the importer.

### R.9 Roster count (gap, minor)

The art spike delivered **32** characters (folder listing: bear_guard bunny calf cat_morfar_mis chick duck fairy_baker fairy_dusk fairy_king fairy_mayor fairy_shopkeeper fairy_stardust fairy_wizard fawn fox_cub hen hobbit_bramble hobbit_moss hobbit_pip kitten lamb lysesvamp mouse_pippin owl penguin_postman puppy rabbit_farmer raccoon_smith snurresvamp squirrel tornebusk ugleoje). `fairy_lily` (plan: 33rd) was never baked. P21 must author it (recolour/accessory builder like the other NPC fairies, npc_flyer clip set).

### R.10 Iso environment gaps the spikes did not close (gap + vague task, MAJOR)

1. **Platform skirts.** The art spike ships the cliff as three **props** (`platform_sw` 79x143 pivot (73,13), `platform_se`, `platform_corner` 146x146), not as tiles; the plan's "bark skirts chosen from void neighbours" (P04) described the spike's placeholder tiles. Rule: `IsoArea` places one skirt sprite per platform-edge cell (SW-facing where the cell below-left is void, SE-facing where below-right is void, corner where both) in a `Skirts` node at `z_index = -9` (above Ground, below Objects, not y-sorted), never in `Objects` (a sort tie with an actor standing on the edge cell would paint the skirt over the actor). Placeholder fallback keeps the old tile skirts.
2. **`strips=N` y-sort slicing** was never prototyped. Exact rule: for a prop with footprint f (cells) and front cell F, let `L, B, R` = left, bottom, right corners of `Iso.iso_footprint(F, fx, fy)`. For vertical strip k covering sprite pixel columns `[u0, u1)` the strip centre in layer coordinates is `xc = P.x + (u0+u1)/2 - pivot.x` (P = the prop's ground origin, `pivot` from props.json) and its sort y is `B.y - squash * |xc - B.x|`, clamped from below by `L.y` when `xc < B.x` and by `R.y` when `xc > B.x`; each strip is a `Sprite2D` with `centered=false`, an `AtlasTexture` region `(u0, 0, u1-u0, H)`, node `position = (xc, sort_y)` and `offset = (P + Vector2(u0 - pivot.x, -pivot.y)) - position` (exact, so the strips draw the full sprite unchanged); strip width 32 px (house_farm 436 px: 14 strips). `tests/shot_sort` (windowed) and `area.strips_sort` (headless, numeric order probe) must both pass before P11 uses `strips`.
3. **Animated water.** The spike baked `water_0..3` as four separate atlases and never integrated them; swapping every water cell's source four times a second is O(cells). Rule: four `TileMapLayer`s with identical cells, only one `visible` (swap every 0.5 s, O(1)), physics only on layer 0.
4. **Hyggebyen/forest prop ids**: the blueprint's props that do not exist in the 56-prop export are listed in `lua/config/props_extra.lua` by P22 first (ids + footprint + solid shape) so P11/P19 can author maps against ids, with placeholders until the art lands.

### R.11 Ownership moves that make every gate satisfiable (ownership-overlap, MAJOR)

`tests/lib/print_inputmap.gd` -> `tests/tools/print_inputmap.gd`, owned by P01 (P01's gate needs it; P09 is the same wave). `tests/shot_*` (needs a world) -> P04; `tests/perf_world.*` (needs sprites) -> P05. `tests/checkpoints/compare_guide.py` + `tests/checkpoints/guide_ref/*.png` (the seven `pw1x_*.png` Playwright renders of the guide at 1280x720 from the UI spike, so no browser is needed at test time) -> P07; P27 keeps `tests/checkpoints/*.gd`. `lua_runtime.gd`, `tools/lua/**`, `addons/lua_runtime/**` -> P10. `tests/fixtures/lua/**` (the 15 audit probe files copied out of `/Users/magnusudbjorg/Documents/projects/PongPong_lift/lua_audit`, because scratch paths must not be test inputs) -> P10. `docs/audio/*.import` and `docs/Trætoppen Style Guide Review/**/*.import` stay with P01 (deleted there; they were hidden by the compact owner list). New: `localization/world.csv`, `scripts/world2d/player_stub_2d.gd` (P04), `tools/art/generator/**`, `tools/art/.gdignore` (P08), `tools/import/write_import_stubs.py` (P05), `tools/loc/new_csv.py` (P03), `localization/zz_final.csv` (P26), `assets/iso_tiles/ORTHO_DECISION.md` (P22).

### R.12 Contradictions and stale numbers (contradiction, minor)

* P06 task 2 still said "circle query r=34" while D20 and 3.13 say 45 ground px -> **45**; every spike literal that is in sprite space (not ground space) must be rescaled by 1/0.6: grep `player_2d.gd`, `enemy_2d.gd`, `npc_2d.gd`, `minimap_2d.gd`, `target_marker_2d.gd`, `slash_2d.gd`, `light_ring_2d.gd`, `dust_2d.gd` and `scenes/world2d/player_2d.tscn` (Visual scale 0.6, lantern `texture_scale` 3.3/1.6, burst light, Hurtbox/AttackArc offsets such as `Vector2(0,-24)`, `-6`, `14.0`, hurt ellipse 16x24 at y=-34) - one helper `Iso.S = 1.0 / 0.6` is used for all of them.
* Hotbar defaults (3.10) list carrot/pumpkin seeds that the starter kit (P12) does not give -> hotbar slots with 0 items are shown empty-dimmed, not hidden; defaults follow the starter kit: hoe, can, axe, pickaxe, scythe, turnip_seeds, lantern_oil, health_tonic, then two free slots.
* **Hearts on the farm HUD**: acceptance item 3 lists "health/stamina bars" but the guide's farm HUD shows only Energi. Resolution (flag to the user): the guide layout plus a small 5-heart `PanelHearts` row always visible under the gold pill (same style as the forest HUD); recorded as a deliberate guide extension.
* **Calendar**: the guide mock reads "Tirsdag 14. Blomstermåned"; with 28-day seasons and Monday = day 1 the 14th is a Sunday. `time.first_weekday` (0 = Monday) in `game_balance.lua` makes it a one-line choice; default Monday, open question 5 stays.
* "Gold ring means focus/selected only" vs the guide drawing the double gold edge on every major panel: **two styles**: panel chrome = `0 0 0 4px gold, 0 0 0 6px ink` (dialogue, shop, book, hotbar, HUD date block, minimap, ability slots - as drawn in the guide); selection/focus ring = `0 0 0 3px gold, 0 0 0 5px ink` on slots, cards, buttons, rows. No other use of gold outlines.
* "ink outline on every figure" vs the pack's thin grey-violet outline (75,60,73): kept (ink vanishes on #1c2138 - evidence `outline_compare.png`); icons and UI use the ink outline.

### R.13 EventBus extension protocol (gap, minor)

3.5 is complete for what is known, but later packages will find signals missing and the plan forbids editing P02's file. Add now: `hotbar_assign_requested(slot: int, item_id: StringName)` (P18 emits, P06 `Hotbar` consumes - removes P18's hidden dependency on P06) and a generic `game_event(name: StringName, payload: Dictionary)` escape hatch (consumers must tolerate unknown names). Any further signal is added by P02's owner at a wave boundary.

### R.14 Smaller gaps (each is a task in the named package)

* P17: every HUD control `focus_mode = FOCUS_NONE` (otherwise Space/Enter act on the last-clicked hotbar slot through `ui_accept` while `jump`/`interact` fire). P16: `ConfirmationDialog` OK/Cancel/title localized (`UI_OK`, `UI_CANCEL`, `CONFIRM`) - the engine ships "Please Confirm..."/"OK"/"Cancel". P14: a "!" bubble over NPCs that currently offer an unaccepted quest (audit: `offers_quests` never read; 12 NPCs and 22 quests are undiscoverable otherwise). P24: `audio_manager.gd` still has `Array[AudioStreamPlayer3D]` -> `AudioStreamPlayer2D`/plain `AudioStreamPlayer`. P03: `LocalizationManager.play_voice/voice_*` become a thin forwarder to `AudioManager.play_voice(key)` (no double prefix, no second volume state). P04: `WHISPER_*`/bed keys live in `world.csv`. P01: lift sources (spikes, `pongsrc`, scratch drivers) are snapshotted by the lead to `~/Documents/projects/PongPong_lift/` (outside the repo, never committed) before wave 1 because `/private/tmp` is not a safe long-term input.

### R.15 Acceptance matrix (see 8.2, already amended)

Item 2 split into headless (`player.screen_relative_wasd`, `player.camera_follows`, `player.hop`, `player.run_and_stamina`, `player.sprite_visible` = visible `Sprite2D` with texture in the scene tree) and windowed (`area.render_not_blank`, `player.sprite_visible_pixels`). Item 3 includes the always-visible hearts row and `hud.date_text_real_keys`. Item 5 "mouse mode toggles" stays "cursor visible in every state" (user decision 1: 2D has no mouse capture; this deviation is stated in the QA report). Item 11 adds `forest.maps_art_complete` (P19) and the windowed `art.forest_ortho_readable`.

### R.16 Quality bar (j): what is real, what is not

Real and verified in Godot by the spikes: the 12-character pack and 32 generated characters (same renderer; cast sheet viewed - hobbits, squirrel and NPC fairies sit believably next to the pack; accessories read), iso tiles/props/crops on a `TileMapLayer` with y-sort (farm diorama render looks cohesive), icons, UI theme (diff 7.5-21.9 vs the guide, differences are placeholder art). Not real yet: **Mørkeskoven ortho art** (no ortho tile or wall has ever been baked; the only forest renders are diamond tiles or world-spike placeholders) - therefore P22 bakes it first and writes `ORTHO_DECISION.md` before P19 authors maps; **Hyggebyen** (6.5/10: a 40x40 map with 7 buildings and 11 NPCs will look empty unless P11 fills it with the ~25 new props and the lanterns/stalls of the blueprint); **title key art** 6/10; **hand-painted** feel exists only in the periodic ground tiles. These limits are honest in 6.5 and unchanged; the plan does not promise more.

### R.17 P26 copy pass versus voice (ownership-overlap + ordering)

P26 "Danish copy pass" edited every CSV while owning only `da.csv`. Rule: P26 owns `localization/da.csv` and `localization/zz_final.csv` (the only override layer, loaded last, exempt from the duplicate-key lint). It may override any key **except voiced keys** (every `text_key` of a `lua/dialogue` line that has a `voice_key`); `loc_check --strict` fails when a voiced key's text hash differs from `assets/audio/voice/manifest.json` (P24 regenerates idempotently; P27 asserts `voice.manifest_in_sync`).

### R.18 New decisions (register extension)

D21 project texture filter 2 + explicit node filters (R.1). D22 seven-wave layering (R.2). D23 foundation smoke vs per-screen smokes (R.3). D24 CSV key ownership + keep-imports + `zz_final.csv` (R.4, R.17). D25 recorded voice lines reused, TTS for the rest (R.5). D26 windowed verification category (R.6). D27 import stubs + clone-based copies (R.7). D28 generator base owned by P08, staging in `tools/art/_stage` (R.8). D29 skirts as props, strips formula, four-layer water (R.10). D30 LuaRuntime ownership moves to P10 (R.2, R.11). D31 EventBus additions `hotbar_assign_requested`, `game_event` (R.13).



## 0. Preface

### 0.1 What this plan is and how to use it

* One plan, **27 work packages in 7 waves** (re-layered by the adversarial review, R.2), each with a **strictly disjoint file set**. Section 7 lists them; section 1 maps every existing file and every planned new file to exactly one package (checked by a script: 320 existing files + 273 planned files after the review amendments, 0 unowned, 0 owned twice, 0 pattern overlaps, every dependency on a strictly earlier wave).
* Waves 1-2 = bootstrap + contracts. A package may rely on the contracts of section 3 only after the package that owns them (its `dependsOn`) has landed - the original "all of wave 1 in parallel" was wrong (R.2); a package must still **re-read every file immediately before editing it** (other tools and parallel packages touch the tree; the audit snapshots are already stale: `project.godot` has `jump`, `scenes/npc/npc.tscn` exists).
* The spikes are **lift sources, not finished code**. Their paths (all under the scratchpad `/Users/magnusudbjorg/Documents/projects/PongPong_lift/`): `SW = spike_world`, `SU = spike_ui`, `SA = spike_art`, `SAG = spike_art_godot`, `pongsrc` = source package copy. Where the plan says "lift", copy the file and apply the listed changes. The repo itself is untouched by this planning phase.
* Verification rule for every package: a headless assertion in `tests/sections/<name>.gd` **and**, where it is about looks, a screenshot the builder actually opens and looks at (contact sheets, never a single frame, for art). Checks that need pixels are **windowed checks** (R.6) executed by the lead/user at wave boundaries; headless runs can never assert them.
* **Honesty rule:** a feature is implemented, honestly stubbed (it behaves, says so on screen where relevant, and is listed in section 9), or cut with a reason. Nothing is left half-wired.

### 0.2 What I checked myself while writing (not just repeated from reports)

| Check | Result |
|---|---|
| Read `Trætoppen Style Guide.dc.html` (472 lines) completely; looked at the four sketches (`refs/tegning-24/34/38/43.jpg` = bat, cat, bear, rabbit) | Face grammar noted for art QA: two big round eyes with one dark pupil, 3 whisker strokes per cheek, tiny mouth, big round head on small pear body, stubby arms, small feet. |
| Runtime CSV translation loader prototype (`/Users/magnusudbjorg/Documents/projects/PongPong_lift/loc_verify/drv.gd`, Godot 4.7.2 headless) on the real `da.csv` + spike `ui.csv` | Works: 502 keys, quoted commas fine, `atr()` flips da/en on a Label whose text is a key, fallback locale works, **duplicate detection finds exactly the 3 known duplicates**. No `--import` step needed. |
| macOS Danish TTS | Exactly one Danish voice: `Sara` (da_DK). `say -v Sara` -> `ffmpeg -c:a libvorbis` gives a 38 KB OGG for 4.7 s. `afconvert`, `ffmpeg` (libvorbis), `lame` present. |
| `docs/audio/*.mp3` (14 files, 2-7 s) | Durations and order match the 14 lines of the old `docs/voice_lines.md` (Lyra x5, Maja x4, Lily x3, Thorin x2). They therefore speak the OLD copy ("Lyra", "PongPong"); I could not listen to them. |
| Art spike Godot render `spike_art_shots/godot/f00000039.png` and `farm_1920.png`, world spike `farm_03_field_hud.png`, `forest_07_boss.png`, cast sheet `cast_all32.png` | Real art in the real engine looks cohesive (soft CG family); the world spike's own placeholder art is clearly weaker; the boss bat is an edge-on purple blob (confirms the audit). |
| Spike `iso.gd`, `hotbar.gd`, `game_data.gd`, `world_2d.gd`, pack-script diffs, `event_bus.gd` diffs | Found three real conflicts between spikes (tile height, character scale vs camera zoom, `hotbar_changed` argument order) - resolved in 0.3. |
| File ownership script | `/Users/magnusudbjorg/Documents/projects/PongPong_lift/plan/_src/check.py` (ownership + overlap + wave-order). |

### 0.3 Decision register (conflicts between audits/spikes settled here; binding for all packages)

| # | Decision | Why / evidence | Overrules |
|---|---|---|---|
| D1 | **Base viewport 1280x720**, `stretch/mode=canvas_items`, `aspect=expand`. All UI sizes are design pixels of the guide's 1280x720 screens. | The guide's screens, theme builder and 123-check UI smoke are 1280x720; the pack project is 1280x720; text stays vector-sharp at 1.5x on 1080p. | World spike's 1920x1080 |
| D2 | **Renderer: GL Compatibility** (desktop and mobile keys). No `msaa_2d`. | Spike measured identical pixels in Compatibility/Mobile/Forward+ and 7.2 ms for 100 animated sprites (139 fps) - enough; widest reach; `msaa_2d` prints a warning in Compatibility. BPTC is NOT available in Compatibility on macOS -> use **S3TC** import. | `Forward Plus` in current project.godot |
| D3 | **Iso tile 128x76** (true 36 degree diamond, `Iso.TILE_H=76`), atlas cell 144x84; **ortho tile 96x56**. | The baked tiles/props are 128x75.2 diamonds; the spike's 128x64 (2:1) was for placeholder art. One-line constant change in `iso.gd` the spike itself documented. | World spike `TILE_H=64` |
| D4 | **Sprites are never scaled individually** (Visual scale 1.0). Zoom is camera only: `Iso.DEFAULT_ZOOM = 0.4` at the 1280x720 base (identical on screen to the art spike's 0.6 at 1920x1080), wheel range 0.3-0.7. | Props, tiles and characters are baked at one px/m (87.074); the art spike's Godot render proves this scale reads right. A 0.6 per-character scale (world spike) would break parity with props. | World spike `SPRITE_SCALE=0.6` |
| D5 | **Mørkeskoven floor is orthogonal squares (96x56), sprites keep the 36 degree view** (user decision 6); needs a new ortho mode in the tile baker (P22). **Fallback:** if P22 cannot pass its gate in two attempts the four forest maps flip to `@projection iso` (header + wall chars only). | Axis-aligned corridors read like a top-down action game and match the guide's forest HUD; diagonal-only corridors would not. Both projections are in the framework anyway. | Art spike (forest tiles are diamonds) |
| D6 | **Localization = runtime CSV loader**, no `.translation` files, no `locale/translations` list in project.godot, no import step. Load order: `da.csv` (legacy base) then every other `*.csv` alphabetically, later overrides earlier; duplicates inside non-legacy files are lint errors. Fallback locale `en`. | Audits flagged 4 separate failure modes of the import path (gitignored binaries -> raw keys on a fresh clone, re-import needed after every edit, 2 files fighting for one key, first-import ordering). Verified prototype above. | "Re-import after CSV edit" in audits |
| D7 | **Pause/modal ownership: `GameManager` modal stack** (`push_modal/pop_modal`, derived phase), every panel root `PROCESS_MODE_ALWAYS` and owning its own key. No `PauseController`, no router node. Mouse is **never captured** in the 2D game. | Three competing proposals (core audit, HUD audit, spike's PauseController). The stack is autoload-level (always processed), testable headless, nests correctly (pause > save > settings), and removes all mouse-mode code. Acceptance item 5 "mouse mode toggles" becomes "cursor stays visible in every state" (tested). | PauseController, GameUI router |
| D8 | **One dialogue UI** (`scenes/ui/dialogue_ui.tscn`, parchment, portrait). `Npc2D` calls `DialogueUI.start_dialogue(...)` and awaits `dialogue_finished`. The spike's `DialogueBox2D` and the timer loop of the 3D NPC are dropped. | Fixes the audited blocker (choices never shown, quests never accepted). | `dialogue_box_2d.gd` |
| D9 | `EventBus.hotbar_changed(entries: Array, selected: int)`, entries `{id, amount, name?, rare?}`. `interaction_prompt_changed(text)` is event-driven; HUD never polls the player. | UI spike HUD expects `(entries, selected)`; world spike emitted `(selected, slots)`. | World spike order |
| D10 | Item icons live in `res://assets/icons/items/<item_id>.webp` (UI chrome SVGs stay in `assets/ui/icons/`). | `tt_item_icon.gd` already reads that path; the art spike wrote `assets/ui/icons/<item>.webp`. | Art spike export path |
| D11 | **NPC/quest/item ids stay stable** (`mayor_lyra`, `baker_maja`, `merchant_pip`, ...). Display names come from CSV: Borgmester Hyldeblomst, Bagerfe Rosmarin, Butiksfe Kløvermynte. New ids: `pippin_boegeknop`, `fairy_king`, `cat_morfar_mis`, `penguin_postman`. | Renaming ids touches Lua, maps, tests, voice keys in many packages for no player-visible gain. Cosmetic debt is listed in section 9. | Guide-name-for-id |
| D12 | **One generic `scenes/isometric/chibi.tscn`** + `IsoChibiSprite2D.create(id)`; the 12 per-character scenes are not copied. | 44+ identical scenes would rot; fallback chain and `display_scale` are data. | Pack's per-character scenes |
| D13 | **Keep the regex Lua-subset interpreter**; fix its two parse/runtime bugs, add load-time lint and generic kinds. No GDExtension. | Diffed 217 cases against real Lua 5.4: only the empty-function parse bug and the spurious `items` key deviated; no current content needs more. Lint stops authors from writing unsupported Lua. | GDExtension idea (`addons/lua_runtime`) |
| D14 | Crafting, shops, recipes, enemies, resource nodes, NPC roster, perks, combat numbers, ambient grading and prop gameplay are **Lua data**. | Pitch: "easily extendable using LUA". The 3D code hard-coded SHOPS, NODE_TYPES, NPC_SPAWNS. | Hard-coded tables |
| D15 | Saves: payload v2, 6 manual slots + one **auto** slot (autosave never overwrites a manual slot), validated and applied atomically, world state handed over through `SaveManager.pending_world`. | Audits: autosave destroyed slot 0, half-applied loads, no world state. | v1 saves |
| D16 | Calendar: weeks start Monday on day 1 of every 28-day season (`weekday = (day-1)%7`); example "Tirsdag 16. Blomstermåned" (the guide's mock says the 14th - cosmetic). Months: Blomstermåned / Solmåned / Høstmåned / Frostmåned. "Dag N" on the title = total days played. | 28 = 4 weeks exactly; UI spike used this. | - |
| D17 | Commit `.import` and `.uid` files (remove only the `*.import` ignore rule; **keep ignoring `*.translation`**, R.4). Character clip sheets get a hand-written S3TC `.import` stub written BEFORE the first import by `tools/import/write_import_stubs.py` (R.7; verified honoured) - there is no re-import pass. A fresh clone needs `godot --headless --path . --import` **twice** (first run prints theme font errors once). | Presets live in `.import` files; ignoring them loses them; the stub flow avoids a double import and a stale lossless cache. | `.gitignore *.import`, `apply_import_presets` re-import |
| D18 | `PlaceholderArt/PropArt` stay as the **permanent fallback** behind `ArtCatalog` (missing keys never crash, never warn); QA asserts the missing list is empty for shipped content. | Lets code packages land before art and art drop in without code edits. | Deleting placeholders |
| D19 | Stand-in characters are data (`lua/config/characters.lua` fallback chain), so swapping to real hobbit/squirrel/NPC art needs **no code change** when P21 lands. | Spikes had hard-coded raccoon/capybara/monkey stand-ins. | Hard-coded stand-ins |
| D20 | Interaction = shape query (r=45 ground px) at the facing cell on layer `interactable`; E is the only interact key; hotbar keys 1..0; mouse wheel = zoom. | Spike-verified; audited foot-level ray never hit anything. | 3D `InteractRay` |
| D21 | Project texture filter **2** (Linear Mipmap) plus explicit node filters (Ground 2, Objects/characters/props 4); value 3 is Nearest Mipmap. | Probed in Godot 4.7.2 (R.1). | `default_texture_filter=3` |
| D22 | Seven waves with strictly earlier dependencies. | R.2 (circular P04/P06, P03 before P01, LuaRuntime kinds, compare tool, ortho decision). | five waves |
| D23 | UI foundation smoke only in P07; screen smokes live with the screen owners. | R.3. | one 123-check `ui_smoke` in wave 1 |
| D24 | Single owner per CSV key family, keep-imports, `zz_final.csv` as the only override layer. | R.4, R.17. | duplicate claims in core/ui/economy/animals |
| D25 | The user's 11 reusable recorded lines are used verbatim; TTS only for the rest. | ASR evidence R.5. | archive all 14 |
| D26 | Windowed checks are a first-class, automated, user-run category. | R.6. | headless pixel assertions |
| D27 | `.import` stubs before first import; clone-seeded, disposable test copies. | R.7. | persistent per-package copies |
| D28 | Generator base in `tools/art/generator` (P08); staging in `tools/art/_stage`. | R.8. | `tools/art/characters` base, `export/` staging |
| D29 | Skirts are props; `strips=N` formula; four-layer water. | R.10. | tile skirts, one sort key, source swapping |
| D30 | `lua_runtime.gd` ownership moves to P10. | R.2. | P13 |
| D31 | EventBus gains `hotbar_assign_requested`, `game_event`. | R.13. | - |



## 1. File disposition

Legend: **keep-and-fix** edit in place; **port-to-2d** content survives, moved/rewritten for 2D; **replace** file is rewritten from the spike/new design (same or new path); **delete** removed (obsolete 3D or dead); **new** created. Owner = package id (section 7). `.uid` and `.import` files follow their base file (committed, D17). Generated files (`.godot/`, `*.translation`) are not listed.

### 1.1 Existing files (320 scanned files; group rows stand for several files with identical treatment)

| File | Action | Why | Owner |
|---|---|---|---|
| `.gitignore` | keep-and-fix | Stop ignoring *.import (keep ignoring *.translation); ignore tool dirs, venv, tools/art/_stage (P01). | P01 |
| `README.md` | replace | 3D-era README rewritten for Trætoppen 2D (P25). | P25 |
| `assets/audio/{music,sfx,voice}/.gitkeep (3 files)` | delete | Real voice/sfx folders created by P24. | P24 |
| `assets/models/.gitkeep` | delete | 3D models folder obsolete (P01). | P01 |
| `assets/textures/.gitkeep` | delete | Replaced by iso_tiles/iso_props/icons (P01). | P01 |
| `assets/ui/theme.tres` | replace | Empty theme -> generated parchment/ink theme (P07). | P07 |
| `data/.gitkeep` | delete | data/maps now holds real map files (P11). | P11 |
| `docs/.DS_Store` | delete | macOS junk (P01). | P01 |
| `docs/PongPong_Isometric2D/README.md` | port-to-2d | Moved to docs/art/isometric_pack/ with a note that the pack runs in Godot 4.7.2 (P05). | P05 |
| `docs/PongPong_Isometric2D/assets/isometric_characters/** (12 character folders x 13 files, shadow.png, manifest.json)` | port-to-2d | Copied to assets/isometric_characters (same res:// paths), originals deleted with the nested project (P05). | P05 |
| `docs/PongPong_Isometric2D/docs/** (ISOMETRIC_2D_README.md + 3 preview PNGs)` | port-to-2d | Moved to docs/art/isometric_pack/ (P05). | P05 |
| `docs/PongPong_Isometric2D/project.godot` | delete | Nested standalone project (P05). | P05 |
| `docs/PongPong_Isometric2D/scenes/isometric/characters/*.tscn (12 files)` | delete | Per-character scenes replaced by one generic scenes/isometric/chibi.tscn (P05). | P05 |
| `docs/PongPong_Isometric2D/scenes/isometric/{demo_isometric_2d,npc_2d,player_2d}.tscn` | delete | Demo scenes (P05). | P05 |
| `docs/PongPong_Isometric2D/scripts/isometric/iso_chibi_sprite_2d.gd` | port-to-2d | Merged with the world-spike and art-spike patches into scripts/isometric/iso_chibi_sprite_2d.gd (P05). | P05 |
| `docs/PongPong_Isometric2D/scripts/isometric/{iso_player_controller_2d,iso_wanderer_2d,isometric_demo,isometric_ground_2d}.gd` | delete | Demo/controller scripts replaced by Player2D, Npc2D, Animal2D and the area framework (P05). | P05 |
| `docs/PongPong_Isometric2D/tests/validate_isometric.py` | delete | Superseded by tools/art/core/validate_new_assets.py (P05). | P05 |
| `docs/Trætoppen Style Guide Review/** (HTML guide, support.js, refs/ and uploads/ JPGs, .thumbnail)` | keep-and-fix | Authoritative design (read-only; docs/.gdignore keeps Godot from importing it). | P25 |
| `docs/audio/*.mp3 (14 files)` | keep-and-fix | User's 14 Danish voice MP3s: archived, not wired until text confirmed (P24). | P24 |
| `docs/game_design.md` | replace | Rewritten for 2D + guide (P25). | P25 |
| `docs/lua_api.md` | replace | Matches the engine as built, supported subset documented (P25). | P25 |
| `docs/voice_lines.md` | replace | Voice pipeline guide (P24). | P24 |
| `icon.svg` | replace | New Trætoppen app icon (P23). | P23 |
| `localization/da.csv` | keep-and-fix | Legacy base: shadowed by other csv files until P26 prunes malformed/duplicate/orphan rows. | P26 |
| `localization/{da.da,da.en,en.da,en.en}.translation (4 files)` | delete | Generated binaries; translations load at runtime now (P03). | P03 |
| `localization/en.csv` | delete | 87-key duplicate of da.csv's en column that fought it for QUEST_FIX_ROOF_TITLE (P03). | P03 |
| `lua/config/game_balance.lua` | keep-and-fix | 3D metre units -> ground px/s, guide crop timings, new keys (P10). | P10 |
| `lua/dialogue/*.lua (8 files: baker_maja fairy_lily fairy_wizard farmer_rosa guard_oak mayor_lyra merchant_pip smith_thorin)` | keep-and-fix | 8 dialogues rewritten in guide tone, accept choices for all quests, voice keys (P14). | P14 |
| `lua/items/animals.lua` | keep-and-fix | Species items; kits removed, descriptions fixed (P20). | P20 |
| `lua/items/crops.lua` | keep-and-fix | Guide crops/prices, new crops, descriptions (P12). | P12 |
| `lua/items/magic.lua` | keep-and-fix | Remove duplicate fairy_dust, add ids (P12). | P12 |
| `lua/items/resources.lua` | keep-and-fix | gem_bag, moonstone, moss etc. (P12). | P12 |
| `lua/items/tools.lua` | keep-and-fix | stamina_cost, scythe, copper pickaxe (P12). | P12 |
| `lua/quests/*.lua (20 files)` | keep-and-fix | 20 quests get giver/tag/location/description keys, `on=` bindings; guide quests added (P13). | P13 |
| `project.godot` | keep-and-fix | Rename to Trætoppen, 1280x720, GL Compatibility, 2D layers, full input map, runtime-loaded translations (P01). | P01 |
| `scenes/forest/dark_forest.tscn` | delete | 3D forest scene (own WorldEnvironment broke the world) -> 4 ortho maps (P19). | P19 |
| `scenes/main/main_menu.tscn` | replace | UI-spike title scene (P16). | P16 |
| `scenes/main/world.tscn` | replace | Root Node2D with world_2d.gd (P04). | P04 |
| `scenes/npc/npc.tscn` | delete | 3D NPC scene (P14). | P14 |
| `scenes/player/player.tscn` | delete | 3D player scene (P06). | P06 |
| `scenes/ui/character_select.tscn` | replace | UI-spike character select (P16). | P16 |
| `scripts/autoload/audio_manager.gd` | keep-and-fix | play_voice key fix, buses, SFX hooks, settings persistence (P24). | P24 |
| `scripts/autoload/economy_manager.gd` | keep-and-fix | Reset, 24 slots, item_gained, equip/use, validation (P12). | P12 |
| `scripts/autoload/event_bus.gd` | keep-and-fix | Node3D -> Node2D player signal, 2D/area/combat/economy signals, new_game_started etc. (P02). | P02 |
| `scripts/autoload/game_manager.gd` | keep-and-fix | Modal stack, new-game reset signal, zone_unlocked, multi-day advance_time, no mouse capture (P02). | P02 |
| `scripts/autoload/localization_manager.gd` | keep-and-fix | Runtime CSV loader + persistence + lint hooks; removes the import/.translation dependency (P03). | P03 |
| `scripts/autoload/lua_runtime.gd` | keep-and-fix | Interpreter kept; parse/nil/api bugs fixed, load-time lint, generic kinds incl. shops/recipes tables (P10, moved from P13 by the review). | P10 |
| `scripts/autoload/quest_manager.gd` | keep-and-fix | Objective bindings, defs separate from saves, safe iteration, repeatable (P13). | P13 |
| `scripts/autoload/save_manager.gd` | keep-and-fix | v2 payload, validation, auto slot, world hand-off (P15). | P15 |
| `scripts/autoload/time_manager.gd` | keep-and-fix | Danish calendar helpers, weather ids/names, reset (P02). | P02 |
| `scripts/economy/shop_system.gd` | keep-and-fix | Shops from Lua, listed==charged price, discount perk (P12). | P12 |
| `scripts/farm/animal_husbandry.gd` | keep-and-fix | Data layer is sound (autoload); fix day counter, intervals, signals, reset, save (P20). | P20 |
| `scripts/farm/building_placer.gd` | replace | 3D Node3D placer -> scripts/farm/placement_service.gd (2D, building slots + placeables) (P20). | P20 |
| `scripts/farm/farm_animal.gd` | replace | CharacterBody3D with parse error -> scripts/farm/animal_2d.gd (P20). | P20 |
| `scripts/farm/farm_plot_interactable.gd` | delete | Per-plot StaticBody3D interactable; farming is now a grid model + tool dispatch in Player2D (P06). | P06 |
| `scripts/farm/farm_system.gd` | replace | 3D plot nodes + random growth -> scripts/world2d/farm_grid.gd (deterministic, seasons, rain) (P06). | P06 |
| `scripts/npc/npc_agent.gd` | replace | NavigationAgent3D NPC with timer dialogue -> scripts/world2d/npc_2d.gd (P14). | P14 |
| `scripts/npc/npc_base.gd` | delete | Unreferenced duplicate of npc_agent (P14). | P14 |
| `scripts/npc/npc_spawner.gd` | delete | Dead: world.gd spawned NPCs itself; markers in maps now (P14). | P14 |
| `scripts/player/player_controller.gd` | replace | CharacterBody3D controller -> scripts/world2d/player_2d.gd (P06). | P06 |
| `scripts/ui/animal_care_ui.gd` | keep-and-fix | Control script is dimension-agnostic; fix labels/ItemList/close; add scene (P20). | P20 |
| `scripts/ui/build_menu_ui.gd` | keep-and-fix | Fix ItemList.selected crash, add scene and opener (P20). | P20 |
| `scripts/ui/character_select.gd` | replace | UI-spike version: 2 pages, species chips, real sprites, skin passed to start_new_game (P16). | P16 |
| `scripts/ui/dialogue_ui.gd` | replace | UI-spike version + start_dialogue()/dialogue_finished flow, voice label (P14). | P14 |
| `scripts/ui/hud.gd` | replace | UI-spike HUD, event-driven, guide layout (P17). | P17 |
| `scripts/ui/inventory_ui.gd` | replace | 24-slot grid + Værksted crafting panel (P18). | P18 |
| `scripts/ui/main_menu.gd` | replace | Title screen, Continue(latest slot), no re-connect bug (P16). | P16 |
| `scripts/ui/pause_menu.gd` | replace | Resume on second Esc, modal stack, quit-to-menu unpauses (P16). | P16 |
| `scripts/ui/quest_journal.gd` | replace | Opgavebog reading Lua fields (P14). | P14 |
| `scripts/ui/save_load_ui.gd` | replace | 6 slots + auto, themed confirms, no phase handling (P16). | P16 |
| `scripts/ui/shop_ui.gd` | replace | Guide shop screen with stepper and keeper bust (P18). | P18 |
| `scripts/world/crystal_cave.gd` | delete | 3D; GEM_TYPES data moves to lua/config/resource_nodes.lua (P19). | P19 |
| `scripts/world/dark_forest.gd` | delete | 3D; NODE_TYPES/loot tables move to lua/config/resource_nodes.lua (P19). | P19 |
| `scripts/world/dark_forest_zone.gd` | delete | 3D atmosphere/spawner; rules move to maps + enemies.lua (P19). | P19 |
| `scripts/world/enemy.gd` | delete | 3D enemy (tween on modulate bug) -> scripts/world2d/enemy_2d.gd (P19). | P19 |
| `scripts/world/mushroom_grove.gd` | delete | 3D; mushroom types move to resource_nodes.lua + svampelunden.map (P19). | P19 |
| `scripts/world/resource_node_interactable.gd` | delete | 3D; hit_node group crash -> resource_node_2d.gd (P19). | P19 |
| `scripts/world/world.gd` | delete | 3D world builder -> scripts/world2d/world_2d.gd (P04). | P04 |
| `scripts/world/zone_trigger.gd` | delete | Area3D trigger (double zone_entered bug) -> warp_2d.gd + WorldRoot2D.zone logic (P04). | P04 |
| `tests/.gitkeep` | delete | Folder now has real content (P09). | P09 |
| `tests/playtest.gd` | replace | Rewritten for 2D as harness + auto-discovered sections (P09). | P09 |
| `tests/run_playtest.sh` | keep-and-fix | Same CLI; auto-import, import-stub audit, windowed mode, clone-based copy runner (P09). | P09 |

Not under the scoped directories and left alone: `.git/`, `.godot/` (cache), `.mimocode/` and `.playwright-mcp/` (other tools' state; added to `.gitignore`), root `.DS_Store` (ignored), `addons/lua_runtime/` (empty directory, deleted by P13).

### 1.2 New files (planned; globs summarise bulk outputs)

| Owner | Creates |
|---|---|
| P01 | `.gitattributes`, `docs/.gdignore`, `docs/design/PLAN_2D.md`, `tests/tools/print_inputmap.gd`, `tests/tools/check_project.gd` |
| P02 | `tests/sections/core.gd` |
| P03 | `localization/core.csv`, `tools/loc/csv_lint.py`, `tools/loc/prune_legacy.py`, `tests/loc_check.gd`, `tools/loc/new_csv.py`, `tests/sections/loc.gd` |
| P04 | `scripts/world2d/iso.gd`, `scripts/world2d/area_map.gd`, `scripts/world2d/area_tileset.gd`, `scripts/world2d/iso_area.gd`, `scripts/world2d/world_2d.gd`, `scripts/world2d/warp_2d.gd`, `scripts/world2d/interactable_2d.gd`, `scripts/world2d/day_night.gd`, `scripts/world2d/glow.gd`, `scripts/world2d/art_catalog.gd`, `scripts/world2d/placeholder_art.gd`, `scripts/world2d/prop_art.gd`, `scripts/world2d/game_data.gd`, `scripts/world2d/weather_fx.gd`, `data/maps/_fixture_iso.map`, `data/maps/_fixture_ortho.map`, `lua/config/props.lua`, `lua/config/ambient.lua`, `tests/shot_world.gd`, `tests/shot_world.tscn`, `tests/shot_sort.gd`, `localization/world.csv`, `scripts/world2d/player_stub_2d.gd`, `tests/sections/area.gd` |
| P05 | `assets/isometric_characters/{12 pack ids}/**` (copied), `assets/isometric_characters/shadow.png`, `manifest.json`, `scenes/isometric/chibi.tscn`, `scripts/isometric/iso_chibi_sprite_2d.gd`, `lua/config/characters.lua`, `tools/import/write_import_stubs.py`, `tests/perf_world.*`, `docs/art/isometric_pack/**`, `tests/sections/characters.gd` |
| P06 | `localization/farm.csv`, `scripts/world2d/player_2d.gd`, `scripts/world2d/target_marker_2d.gd`, `scripts/world2d/slash_2d.gd`, `scripts/world2d/light_ring_2d.gd`, `scripts/world2d/dust_2d.gd`, `scripts/world2d/hotbar.gd`, `scripts/world2d/farm_grid.gd`, `scripts/world2d/farm_view.gd`, `scenes/world2d/player_2d.tscn`, `tests/sections/player.gd`, `tests/sections/farm.gd` |
| P07 | `assets/fonts/**` (Caprasimo, Alegreya Sans x4, IBM Plex Mono x2, TTSymbols + OFL texts), `assets/ui/icons/*.svg`, `shaders/*.gdshader` (3), `scripts/ui/theme/*` (5), `scripts/ui/components/*` (9), `scenes/ui/components/*` (4), `scripts/ui/dev/*` + `scenes/ui/dev/*` (gallery, shot_runner, ui_smoke), `tools/ui/**` (theme + scene builders), `scripts/ui/game_ui.gd`, `scenes/ui/game_ui.tscn`, `localization/ui.csv`, `tests/checkpoints/compare_guide.py` + `tests/checkpoints/guide_ref/*.png`, `tests/sections/ui_foundation.gd` |
| P08 | `tools/art/README.md`, `setup_env.sh`, `produce_all.sh`, `tools/art/.gdignore`, `tools/art/generator/**`, `tools/art/core/**`, `tools/art/export/**` |
| P09 | `tools/dev/test_in_copy.sh`, `tests/lib/asserts.gd`, `tools/dev/run_windowed.sh` |
| P10 | `lua/config/npcs.lua`, `lua/config/race_perks.lua`, `tools/lua/lint.gd`, `tests/fixtures/lua/probe_empty_function.lua`, `tests/sections/data.gd` |
| P11 | `localization/areas.csv`, `data/maps/farm.map`, `data/maps/hyggebyen.map`, `tests/sections/maps_iso.gd` |
| P12 | `localization/economy.csv`, `lua/items/consumables.lua`, `lua/items/products.lua`, `lua/items/crafted.lua`, `lua/shops/seed_shop.lua`, `lua/shops/bakery.lua`, `lua/shops/smithy.lua`, `lua/shops/magic_store.lua`, `lua/shops/animal_store.lua`, `lua/recipes/guide_recipes.lua`, `scripts/economy/crafting_system.gd`, `tests/sections/economy.gd` |
| P13 | `localization/quests.csv`, `lua/quests/moonstone_crown.lua`, `tests/sections/quests.gd` |
| P14 | `localization/dialogue.csv`, `scripts/world2d/npc_2d.gd`, `scripts/world2d/intro_sequence.gd`, `lua/dialogue/fairy_king.lua`, `lua/dialogue/pippin_boegeknop.lua`, `lua/dialogue/cat_morfar_mis.lua`, `lua/dialogue/penguin_postman.lua`, `scenes/ui/dialogue_ui.tscn`, `scenes/ui/quest_journal.tscn`, `tests/sections/npc.gd` |
| P15 | `tests/sections/save.gd` |
| P16 | `localization/menus.csv`, `scripts/ui/settings_ui.gd`, `scenes/ui/settings_ui.tscn`, `scenes/ui/pause_menu.tscn`, `scenes/ui/save_load_ui.tscn`, `tests/sections/menus.gd` |
| P17 | `localization/hud.csv`, `scenes/ui/hud.tscn`, `tests/sections/hud.gd` |
| P18 | `localization/shop_ui.csv`, `scenes/ui/inventory_ui.tscn`, `scenes/ui/shop_ui.tscn`, `tests/sections/shop_ui.gd` |
| P19 | `localization/forest.csv`, `scripts/world2d/enemy_2d.gd`, `scripts/world2d/loot_drop_2d.gd`, `scripts/world2d/resource_node_2d.gd`, `scripts/world2d/whisper_zone.gd`, `scripts/world2d/minimap_2d.gd`, `data/maps/skovkant.map`, `data/maps/dybe_bregner.map`, `data/maps/svampelunden.map`, `data/maps/krystalgrotten.map`, `lua/config/enemies.lua`, `lua/config/resource_nodes.lua`, `scripts/ui/forest_hud.gd`, `scenes/ui/forest_hud.tscn`, `tests/sections/forest.gd` |
| P20 | `localization/animals.csv`, `scripts/farm/animal_2d.gd`, `scripts/farm/placement_service.gd`, `scenes/ui/animal_care_ui.tscn`, `scenes/ui/build_menu_ui.tscn`, `tests/sections/animals.gd` |
| P21 | `assets/isometric_characters/<33 new ids>/**` (hobbit_pip/moss/bramble, squirrel, fairy_dusk/stardust/mayor/baker/shopkeeper/king/wizard/lily, mouse_pippin, cat_morfar_mis, bear_guard, rabbit_farmer, raccoon_smith, penguin_postman, chick hen duck kitten bunny fox_cub lamb calf owl puppy fawn, snurresvamp tornebusk ugleoje lysesvamp), `manifest_traetoppen.json`, `assets/portraits/<id>.webp` (45), `tools/art/characters/**`, `tests/sections/art_characters.gd` |
| P22 | `assets/iso_tiles/**` (17 diamond atlases + ~7 ortho + tiles.json), `assets/iso_props/**` (~80 props + ~8 ortho walls + glow halos + props.json), `assets/backdrops/*`, `lua/config/props_extra.lua`, `tools/art/environment/**`, `tests/sections/art_environment.gd` |
| P23 | `assets/icons/items/<id>.webp` (~75), `assets/ui/keyart/title.webp` + `title_layers/`, `icon.svg`, `tools/art/icons/**`, `tests/sections/art_icons.gd` |
| P24 | `tools/voice/**`, `assets/audio/voice/<npc>/<line>.ogg` (~100-130), `assets/audio/voice/manifest.json`, `RECORDED.txt`, `_user_recordings_v0/`, `assets/audio/sfx/*.ogg` (optional), `tests/sections/voice.gd` |
| P25 | `docs/howto/add_a_quest.md`, `docs/howto/add_an_npc.md`, `docs/howto/add_an_item_and_recipe.md`, `docs/howto/add_a_shop.md`, `docs/howto/add_an_enemy.md`, `docs/howto/add_a_map.md`, `docs/howto/add_a_character_with_the_generator.md`, `docs/howto/voice.md`, `docs/art/PIPELINE.md`, `tests/sections/docs.gd` |
| P26 | `localization/zz_final.csv` |
| P27 | `docs/qa/QA_REPORT.md`, `tests/checkpoints/run_checkpoints.gd`, `tests/sections/zz_acceptance.gd` |


## 2. Pitch and guide coverage

Every sentence of the pitch and every screen/feature of the guide mapped to **implement / stub / cut**. Status counts: see end of section.

### 2.1 Pitch

| Requirement | Status | Packages | Note |
|---|---|---|---|
| PITCH 1: "a Stardew Valley like game ... based on GoDot" | **implement** | P04, P06, P11, P12 | Godot 4.7.2 2D; farm loop (till/plant/water/grow/harvest/sell), town, quests, adventure area. |
| PITCH 2: "in an enchanted forest, where we live among all the cute forest animals (chibi)" | **implement** | P05, P20, P21, P14, P11 | 12 pack chibi characters + 33 generated (animals, villagers); farm animals live on the farm; Hyggebyen villagers wander. |
| PITCH 3: "There are fairies, they operate the city where we can buy things for our farm" | **implement** | P11, P12, P14, P18, P21 | Hyggebyen: fairy NPC roster, 5 Lua-defined shops (frø, bageri, smedje, magi, dyr). |
| PITCH 4: "The player can choose to be a cute animal, fairy or hobbit" | **implement** | P16, P05, P21, P06, P10 | Skovdyr (Ræv/Kanin/Pindsvin/Egern), Fe (3 skins), Hobbit (3 skins) with real perks; hobbit/squirrel art generated by P21 (raccoon/monkey stand-ins until it lands). |
| PITCH 5: "given an enchanted treetop farm, because we won it in the fairy king's lottery" | **implement** | P11, P14, P13, P21 | Raised treetop platform map; IntroSequence with Fekongen's letter on a new game; intro_lottery quest. |
| PITCH 6: "build the farm and crops and earn money for upgrades" | **implement** | P06, P20, P12, P11 | Crops (7), field expansion zone, coop/barn/house, placeables (scarecrow, lantern, fence), tool upgrades at the smithy. House interior and festivals: cut. |
| PITCH 7: "action adventure in the dark forest ... rare items and valuable minerals, gems and metals" | **implement** | P19, P22, P21, P12 | Mørkeskoven: 4 ortho maps, real-time combat, boss Snurresvampen, ore/crystal/mushroom nodes, loot, lantern oil. |
| PITCH 8a: "help fairy citizens ... like fixing their roof" | **implement** | P13, P14, P11 | fix_roof 'Utæt tag på bageriet' (BYG): wood+moss then repair quest_spot on the bakery roof. |
| PITCH 8b: "... finding their lost cat" | **implement** | P13, P14, P19 | lost_cat 'Find Pippins kat' (FIND): neighbours, paw prints at the bridge, Morfar Mis in Dybe Bregner. |
| PITCH 8c: "... giving the crops they need for their cookie" | **implement** | P13, P14, P12 | cookie_delivery 'Gulerødder til småkager' (HØST): collect 12 carrots for Bagerfe Rosmarin. |
| PITCH 9: "quests and game easily extendable using LUA" | **implement** | P13, P12, P10, P25 | Quests, dialogue, items, shops, recipes, enemies, nodes, roster, perks, ambient are Lua; load-time lint; F9 reload in debug; how-to guides with a worked example. |
| PITCH 10a: "all copy ... in Danish" | **implement** | P03, P26, P14, P16 | Danish default and primary; English column complete; loc_check --strict gate. |
| PITCH 10b: "... and voices in Danish" | **stub** | P24, P14 | Playback wired for every line; the user's recorded lines (11 of the 14 MP3s, ASR-verified, R.5) are used verbatim and win via RECORDED.txt; the remaining ~100 lines use placeholder macOS `Sara` TTS with per-NPC pitch. A full human cast is outside this build. |

### 2.2 Style guide screens and features

| Requirement | Status | Packages | Note |
|---|---|---|---|
| GUIDE: camera isometric on the farm (and Hyggebyen) | **implement** | P04, P06, P22 | TileMapLayer iso, DIAMOND_DOWN, 128x76. |
| GUIDE: camera top-down in Mørkeskoven | **implement** | P19, P22 | Changed by user decision 6: same 36 degree view on an orthogonal square floor with free movement (iso fallback documented). |
| GUIDE: hand-painted 2D sprites, chibi ~2.5 heads, ink outline on every figure | **implement** | P05, P21, P22 | Soft rendered 'painted' sprites with the pack's thin grey-violet outline; NOT hand-brushed (honest limit, section 6.5). |
| GUIDE: parchment panels, 2 px ink, double gold ring, gold only for focus/selected | **implement** | P07 | Generated Theme (145 types) + TTBoxStyle. |
| GUIDE: buttons with dark lower edge (green/gold/cream/dashed disabled), hover lift, press sink | **implement** | P07 | ButtonPrimary/Secondary/Tertiary variations. |
| GUIDE: Caprasimo for numbers/time/money/buttons/titles, Alegreya Sans body, Æ Ø Å | **implement** | P07 | Fonts + metric-corrected symbol fallback; has_char tests. |
| GUIDE: damage = thorn-berry pink, never red | **implement** | P06, P19, P07 | Flash color e58fa6 / meter b3436b; test greps for red. |
| GUIDE: three zone palettes (Trætoppen, Hyggebyen, Mørkeskoven) | **implement** | P04, P22 | Ambient keyframes in lua/config/ambient.lua + tile/backdrop art. |
| GUIDE screen: Titelskærm (key art, menu panel Fortsæt/Nyt spil/Indstillinger/Afslut, 'v0.1 · Dansk') | **implement** | P16, P23 | Key art 6/10 first pass (risk R9). |
| GUIDE screen: Vælg figur (3 cards + perks, species chips Ræv/Kanin/Pindsvin/Egern, page 1/2) | **implement** | P16, P05, P21 | Real sprites in cards. |
| GUIDE screen: HUD på gården (date/time/weather, guldagern pill, active quests, vertical Energi, 10-slot hotbar with tool name) | **implement** | P17, P06, P02 | Event-driven. |
| GUIDE screen: Butik i Hyggebyen (tabs, 2-col list, stepper, Køb, keeper bust + bubble, blurred backdrop) | **implement** | P18, P12, P21 | Kløvermynte's 8 guide items. |
| GUIDE screen: Opgavebog (reads title/giver/steps/reward straight from Lua) | **implement** | P14, P13 | Fields defined in section 3.12. |
| GUIDE screen: Rygsæk 24 slots + Værksted recipes with ingredient tiles | **implement** | P18, P12 | Recipes are Lua. |
| GUIDE screen: Dialogboks (portrait, name plate, ▸ choices, 'E for at fortsætte', 'dansk stemme') | **implement** | P14, P24 | Voice label only when a voice file plays. |
| GUIDE screen: Mørkeskoven HUD (5 hearts with halves, Lygteolie, round minimap + zone chip, loot feed, boss bar, abilities, whisper) | **implement** | P19, P06 | All elements; zone chip 'Dybe Bregner · 2' from @depth. |
| GUIDE: combat abilities slag=LMB, undvig=Space, fe-lys=Q, drik=R | **implement** | P06, P19, P01 | Real-time arc swing, dodge roll with i-frames, light burst stun, health tonic. |
| GUIDE: Lygteolie as a gentle time limit | **implement** | P06, P19 | 150 s oil, min light 35%, whisper at 20%, optional slow damage at 0 (config). |
| GUIDE: calendar 'Tirsdag 14. Blomstermåned', weather label (Solskin) | **implement** | P02, P17 | Danish weekday and month names per season (D16). |
| GUIDE: weather effects | **stub** | P04, P02 | Rain overlay + auto-watering implemented; fog/snow/thunder are label-only. |
| GUIDE race perk: Skovdyr digs faster / more from the harvest | **implement** | P06, P10 | dig_speed 1.3, tool_cost 0.75, +1 harvest 20%. |
| GUIDE race perk: Fe flies briefly over fields | **implement** | P06, P10, P05 | F toggles, 8 s, pack fairy flight clips. |
| GUIDE race perk: Fe talks to flowers | **stub** | P06 | 6 Danish flower whispers when flying near crops; no dialogue system. |
| GUIDE race perk: Hobbit bakes better cakes + shop discount | **implement** | P12, P10 | bake_bonus on bake recipes; 10% discount in all Hyggebyen shops. |
| GUIDE: NPCs Borgmester Hyldeblomst, Pippin Bøgeknop, Bagerfe Rosmarin, Butiksfe Kløvermynte, Fekongen; cat Morfar Mis | **implement** | P10, P03, P14, P21 | Roster in lua/config/npcs.lua, art by P21. |
| GUIDE: currency guldagern; 1.250 formatting | **implement** | P03, P17 |  |
| GUIDE quests: Find Pippins kat, Gulerødder til småkager, Utæt tag på bageriet, Månesten til kronen | **implement** | P13 | Plus the 19 legacy quests made completable. |
| GUIDE: hængebro (rope bridge), marker, trætopsgård | **implement** | P11, P22 | Bridge props + warp to Hyggebyen. |
| GUIDE: hotbar tools Hakke/Vandkande/Økse/Le | **implement** | P06, P12 | hoe, can, axe, pickaxe, scythe. |
| GUIDE: Fiskestang (fishing rod) | **stub** | P06, P12, P23 | Item + icon exist; using it shows a Danish 'fiskevandet er ikke åbnet endnu' whisper. Fishing is cut. |
| GUIDE: Æble, Honning, Hvede items | **stub** | P12, P19, P22 | Apple from orchard trees (implemented node); honey sold at the bakery (no beehive); wheat omitted (flour is bought). |
| GUIDE shop: Gødning and Fe-støv (vand ét felt i 3 dage) | **implement** | P06, P12 | fertilizer +1 yield; auto_water_days=3. |
| GUIDE shop: Jordbær-, Solsikke-, Kattemynte-frø, Månebønne 'gror kun om natten' | **implement** | P12, P06, P22 | 3 new crops with art; moon crop uses water_window. |
| GUIDE: music | **cut** | - | No music in guide or pitch; AudioManager keeps slots, missing files are silent. |
| GUIDE: gamepad ('kan styres med tastatur') | **stub** | P01, P07 | Keyboard focus complete and tested; joypad events bound but untested. |
| PLAYABILITY: Esc pause, save/load/continue, settings, language switch da/en | **implement** | P16, P15, P03, P02 | Acceptance 5, 12, 13. |
| PLAYABILITY: day/night, sleep in bed, 02:00 pass-out (the game day runs 06:00-02:00, CLOCK_26) | **implement** | P04, P11 | Bed marker at the farmhouse door. |
| PLAYABILITY: farm animals bought, fed, collected | **implement** | P20, P12, P21 | Acceptance 10. |
| PLAYABILITY: zones farm, city, dark forest, crystal cave, mushroom grove with triggers, enemies, resource nodes | **implement** | P11, P19 | Acceptance 11. |

Count: implement 45, stub 6, cut 1 (stubs and cuts are expanded with their minimal playable behaviour in 9.2).


## 3. Shared contracts (waves 1-3 own them; a package relies on a contract only after its owner has landed)

Single owner per contract: project settings P01, EventBus/GameManager/TimeManager P02, localization P03, area framework P04, characters P05, player/farm P06, UI foundation P07, data P10. Changing a contract after its owner's wave requires the owner (or the wave-boundary reviewer) to edit `docs/design/PLAN_2D.md` - nobody patches another package's file.

### 3.1 project.godot (P01) - final content summary

```
[application]
config/name="Trætoppen"                      config/description="En gård i Fekongens skov."
run/main_scene="res://scenes/main/main_menu.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
config/use_custom_user_dir=true              config/custom_user_dir_name="Traetoppen"   # AE in folder names warns on macOS
[autoload]  EventBus GameManager LocalizationManager SaveManager EconomyManager QuestManager LuaRuntime TimeManager AudioManager ShopSystem AnimalHusbandry   (same names, same order)
[display]   window/size/viewport_width=1280  viewport_height=720  stretch/mode="canvas_items"  stretch/aspect="expand"
[gui]       theme/custom="res://assets/ui/theme.tres"
[internationalization]  locale/fallback="en"        # NO locale/translations list (runtime loader, D6)
[layer_names]  2d_physics/layer_1..11 (3.3)
[rendering] renderer/rendering_method="gl_compatibility"  renderer/rendering_method.mobile="gl_compatibility"
            textures/canvas_textures/default_texture_filter=2        # Linear Mipmap (enum: 0 Nearest, 1 Linear, 2 Linear Mipmap, 3 Nearest Mipmap; 3 is WRONG - R.1); node filters: Ground=2, Objects/characters/props=4
            textures/vram_compression/import_s3tc_bptc=true          # S3TC works everywhere tested; BPTC does not in Compatibility on macOS
            environment/defaults/default_clear_color = sky blue a9d3e0
[importer_defaults] texture = {"mipmaps/generate": true}
[removed]  [animation] 3D key, 3d_physics/*, anti_aliasing/quality/msaa_3d, any msaa_2d, window_width_override/height_override
```
Smooth look rules: no `snap_2d_*`, linear filtering everywhere, art pre-antialiased, UI = vector StyleBoxes (no 9-patch textures). Camera is never pixel-snapped.

### 3.2 Input map (P01)

| Action | Bindings | Read by |
|---|---|---|
| `move_forward/back/left/right` | W S A D, arrows, left stick | Player2D (screen-relative: W = screen up) |
| `interact` | E, Enter, joy A | interact / talk / harvest / bed / warp prompt |
| `jump` | Space, joy A | hop in iso areas (fake height, `jump` clip) |
| `dodge` | Space, joy B | roll in action (ortho) areas |
| `run` | Shift | run, costs stamina, hysteresis |
| `fly_toggle` / `fly_descend` | F / Shift (in flight) | Fe flight (Space climbs) |
| `use_tool` | LMB, joy X | selected hotbar item in iso areas (target cell) |
| `attack` | LMB, joy X | arc swing in action areas (slag) |
| `light` / `drink` | Q / R | fe-lys burst / health tonic |
| `slot_1`..`slot_10` | 1..9, 0 | hotbar selection |
| `inventory` | I, Tab | Rygsæk (**not** F10) |
| `journal` | J | Opgavebog |
| `pause` | Esc, joy Start | pause menu / closes the top modal |
| `build_menu` | B | build menu on the farm |
| `zoom_in` / `zoom_out` | wheel up / down | camera zoom 0.3-0.7 (`Iso.DEFAULT_ZOOM` 0.4) |
| `ui_*` | Godot defaults + D-pad, joy A/B | focus navigation (tested) |

Space is `jump` in iso areas and `dodge` in ortho areas: both actions share the key, the player reads the one that matches `area.projection`. LMB likewise (`use_tool` vs `attack`). The mouse cursor is always visible; aiming uses `get_global_mouse_position()` after the first mouse motion, otherwise the facing direction.

### 3.3 Collision layers, groups, conventions (P01 names, P04/P06 apply)

| Layer | Name | Value | Notes |
|---|---|---|---|
| 1 | world | 1 | solid props, walls, map bounds ring |
| 2 | player | 2 | Player2D body |
| 3 | npc | 4 | NPC/animal bodies (solid for the player) |
| 4 | interactable | 8 | E-query target shapes (NPC, bed, sign, quest_spot, animal) |
| 5 | enemy | 16 | enemy Hurtbox |
| 6 | farm_plot | 32 | reserved (farm is a grid, unused) |
| 7 | resource_node | 64 | ore/crystal/tree/mushroom bodies |
| 8 | ground_block | 128 | water, bog, void rim - fliers ignore it |
| 9 | player_attack | 256 | swing Area2D |
| 10 | enemy_attack | 512 | enemy Hitbox (monitorable only during a lunge) |
| 11 | pickup | 1024 | loot orbs |

Player mask walking = 1+4+64+128 = 197; flying = 69. TileSet physics layer 0 -> 128, layer 1 -> 1. **Groups:** `player`, `world_2d`, `npc`, `enemy`, `interactable`, `resource_node`, `pickup`, `warp`, `game_ui`, `dialogue_ui`, `prop_tree`. **Ground units:** all speeds, ranges and arcs are in ground px; `Iso.to_screen(g) = (g.x, g.y*squash)`; collision bodies are flattened ellipses (25 x 14.8 for a figure). Names must be unique per parent or use `add_child(node, true)`; find nodes by group, not name.

### 3.4 Localization (P03; D6)

* `LocalizationManager._ready` loads every `res://localization/*.csv` (`keys,da,en`), da.csv first, then alphabetical; later rows override earlier ones; one `Translation` per locale; `locale/fallback="en"`; default locale `da`, saved choice in `user://settings.cfg [game] locale`.
* Lint (`LocalizationManager.lint()`, `tests/loc_check.gd`): key regex `^[A-Z0-9_]+$`; no duplicate key inside one non-legacy file; no key defined in two non-legacy files; every key has da **and** en text; scripts/scenes/Lua reference only keys that exist (dynamic patterns expanded: `ITEM_<id>`, `ITEM_<id>_DESC`, `OBJ_<QUEST>_<OBJ>` then `OBJ_<OBJ>`, `QUEST_<id>_TITLE/_DESC/_OFFER`, `ZONE_<id>`, `SHOP_<id>`, `NPC_<id>`, `BUILDING_<id>`, `RECIPE_<id>`, `UI_MONTH_*`, `UI_WEEKDAY_*`, `UI_WEATHER_*`, `BOSS_*`, `WHISPER_*`).
* **Scenes hold KEYS as `text`** (Label/Button/LineEdit placeholder auto-translate and follow locale changes). Text assembled in code uses `tr(KEY) % args` after `has_key`, and subscribes to `NOTIFICATION_TRANSLATION_CHANGED`. No Danish or English literals in scripts or scenes; no `tr()` of Lua strings except through `lua_notification`.
* **File owners (binding key-family table in R.4):** `da.csv` P26 (legacy base, pruned last; nobody else edits it), `zz_final.csv` P26 (the only override layer, loaded last, voiced keys excluded, R.17), `core.csv` P03 (GAME_/NPC_/ZONE_/LANG_ + the legacy overrides listed in R.4 - no ITEM_/OBJ_/QUEST_/RECIPE_/SHOP_), `ui.csv` P07 (new UI_*/MENU_*/HUD_*/INV_*/QJ_*/SET_*/WORKSHOP_* etc., without RECIPE_/ITEM_ rows and per-shop SHOP_<id>_* rows), `world.csv` P04, `areas.csv` P11, `farm.csv` P06, `economy.csv` P12 (ITEM_*, RECIPE_*, SHOP_*), `quests.csv` P13 (QUEST_*, OBJ_*, LUANOTIF_*), `dialogue.csv` P14, `menus.csv` P16, `hud.csv` P17, `shop_ui.csv` P18, `forest.csv` P19, `animals.csv` P20 (ITEM_BABY_*, species, BUILDING_*). Every CSV ships a committed `<name>.csv.import` with `importer="keep"` (R.4). A package that needs a changed legacy text defines the key again in its own file (override).
* Prefixes: `DLG_<NPC>_<LINE>` (dialogue), `QUEST_<ID>_*`, `OBJ_<QUEST>_<OBJ>`, `ITEM_<ID>[_DESC]`, `SHOP_<ID>*`, `RECIPE_<ID>`, `ZONE_*`, `SIGN_*`, `WHISPER_*`, `NOTIF_*`, `UI_*`, `HUD_*`, `ABILITY_*`, `BOSS_*`, `ENEMY_*`, `LANG_*`, `LUANOTIF_*`, `FARM_*`.
* **Canonical copy** (guide v0.1; P03 `core.csv` / P07 `ui.csv` implement it verbatim, both languages):

| Key | Danish (primary) | English |
|---|---|---|
| `GAME_TITLE` / `GAME_SUBTITLE` | Trætoppen / En gård i Fekongens skov | Trætoppen / A farm in the Fairy King's forest |
| `MENU_CONTINUE` `MENU_NEW_GAME` `MENU_SETTINGS` `MENU_QUIT` | Fortsæt / Nyt spil / Indstillinger / Afslut | Continue / New game / Settings / Quit |
| `MENU_VERSION_TAG` | v0.1 · Dansk | v0.1 · English |
| `CHAR_SELECT_TITLE` / `CHAR_SELECT_SUBTITLE` | Hvem er du? / Fekongen vil gerne vide, hvem der har vundet hans gård. | Who are you? / The Fairy King would like to know who won his farm. |
| `CHAR_ANIMAL_NAME` `CHAR_FAIRY_NAME` `CHAR_HOBBIT_NAME` | Skovdyr / Fe / Hobbit | Forest animal / Fairy / Hobbit |
| `CHAR_ANIMAL_PERK` | Stærke poter. Graver hurtigere og får mere ud af høsten. | Strong paws. Digs faster and gets more from the harvest. |
| `CHAR_FAIRY_PERK` | Kan flyve kort over marker og taler med blomster. | Can fly briefly over fields and talks to flowers. |
| `CHAR_HOBBIT_PERK` | Bager bedre kager og får rabat i Hyggebyens butikker. | Bakes better cakes and gets a discount in Hyggebyen's shops. |
| species chips | Ræv, Kanin, Pindsvin, Egern | Fox, Rabbit, Hedgehog, Squirrel |
| `UI_CURRENCY` | guldagern | gold acorns |
| `HUD_ACTIVE_QUESTS` / `HUD_ENERGY` | AKTIVE OPGAVER / Energi | ACTIVE QUESTS / Energy |
| `UI_JOURNAL` / `UI_INVENTORY` / `UI_WORKSHOP` | Opgavebog / Rygsæk / Værksted | Quest book / Backpack / Workshop |
| `UI_WEEKDAY_1..7` | Mandag Tirsdag Onsdag Torsdag Fredag Lørdag Søndag | Monday ... Sunday |
| `UI_MONTH_FORAAR/SOMMER/EFTERAAR/VINTER` | Blomstermåned, Solmåned, Høstmåned, Frostmåned | Month of Blooms, Sun, Harvest, Frost |
| `UI_WEATHER_KLART/REGN/TAAGE/SNE/TORDEN` | Solskin, Regn, Tåge, Sne, Torden | Sunny, Rain, Fog, Snow, Thunder |
| buttons | Køb, Sælg, Lav, Tilbage, Acceptér, Videre ▸, Start ▸ | Buy, Sell, Craft, Back, Accept, Next ▸, Start ▸ |
| `NOTIF_QUEST_ACCEPTED_TITLE` / `NOTIF_QUEST_COMPLETED_TITLE` (the real legacy key names) | Ny opgave! / Opgave fuldført! | New quest! / Quest complete! |
| `ABILITY_SLASH/DODGE/LIGHT/DRINK` | slag, undvig, fe-lys, drik | strike, dodge, fairy light, drink |
| `HUD_OIL` / `BOSS_SNURRESVAMPEN` | Lygteolie / Snurresvampen | Lantern oil / The Whirling Mushroom |
| `ZONE_FARM/CITY/DARK_FOREST/DYBE_BREGNER/MUSHROOM_GROVE/CRYSTAL_CAVE` | Trætoppen, Hyggebyen, Mørkeskoven, Dybe Bregner, Svampelunden, Krystalgrotten | Treetop Farm, Hyggebyen, The Dark Wood, Deep Ferns, Mushroom Grove, Crystal Cave |
| `WHISPER_FERNS` | Noget rasler i bregnerne… | Something rustles in the ferns… |
| `DIALOGUE_CONTINUE_HINT` / `DIALOGUE_VOICE_DA` | E for at fortsætte / dansk stemme | E to continue / Danish voice |
| NPC names | Borgmester Hyldeblomst, Pippin Bøgeknop, Bagerfe Rosmarin, Butiksfe Kløvermynte, Fekongen, Morfar Mis | Mayor Hyldeblomst, Pippin Bøgeknop, Baker-fairy Rosmarin, Shop-fairy Kløvermynte, The Fairy King, Grandpa Mis |
| `SHOP_SEED_SHOP` | Kløvermyntes Frø | Kløvermynte's Seeds |
| `RECIPE_*` | Lygte med svampelys, Fugleskræmsel, Honningkage, Kobberhakke | Mushroom lantern, Scarecrow, Honey cake, Copper pickaxe |
| quest titles | Find Pippins kat, Gulerødder til småkager, Utæt tag på bageriet, Månesten til kronen | Find Pippin's cat, Carrots for the cookies, Leaky roof at the bakery, Moonstone for the crown |
* Guide voice: friendly and warm ("Du har vist glemt at vande gulerødderne."), short buttons (Køb, Sælg, Lav, Tilbage), the forest whispers ("Noget rasler i bregnerne…").

### 3.5 EventBus (P02) - complete signal list

Existing signals keep their arity. **Changed:** `player_spawned(player: Node2D)`. **Removed:** `farm_upgraded` (never used). **New** (emitter -> main consumers):

| Signal | Emitter | Consumers |
|---|---|---|
| `new_game_started()` | GameManager.start_new_game (last) | every autoload `reset()` |
| `zone_unlocked(zone_id)` | GameManager.unlock_zone | quests, toast |
| `item_gained(item_id, amount)` | EconomyManager.add_item (not for silent/loading) | QuestManager bindings, HUD toast, loot feed |
| `recipe_crafted(recipe_id, amount)` | CraftingSystem | quests |
| `building_built(building_id, building_type)` | AnimalHusbandry.build_building / PlacementService | quests, PlacementService |
| `animal_adopted(animal_id, species)` / `animal_fed(animal_id, food_id)` / `animal_product_collected(animal_id, product_id, amount)` | AnimalHusbandry | quests, Animal2D, UI |
| `area_change_requested(area_id, spawn_name)` / `area_changed(area_id)` | Warp2D / WorldRoot2D | WorldRoot2D, minimap, GameUI |
| `player_health_changed(half_hearts, max_half_hearts)` / `player_oil_changed(seconds, max_seconds)` | Player2D | forest HUD |
| `player_stats_changed(stats)` | Player2D (dirty flag, all four keys `health,max_health,stamina,max_stamina`) | HUD |
| `hotbar_changed(entries: Array, selected: int)` | Player2D/Hotbar | HUD (entries `{id, amount, name?, rare?}`) |
| `interaction_prompt_changed(text)` | Player2D | HUD |
| `boss_bar_changed(name_key, ratio, visible)` / `whisper_requested(text_key)` | Enemy2D / WhisperZone / Player2D | forest HUD |
| `enemy_defeated(enemy_id, kind, loot)` / `player_defeated()` | Enemy2D / Player2D | quests, loot feed, WorldRoot2D |
| `weather_changed(weather)` | TimeManager | HUD, weather_fx, FarmGrid |
| `modal_changed(stack: Array)` | GameManager | tests, HUD dimming |
| `hotbar_assign_requested(slot: int, item_id: StringName)` | InventoryUI (P18) | Hotbar (P06) |
| `game_event(name: StringName, payload: Dictionary)` | any (escape hatch for signals nobody foresaw; consumers ignore unknown names) | any |

`quest_*`, `dialogue_*`, `zone_entered/exited` (emitted ONLY by WorldRoot2D when the player enters an area or an area's zone), `resource_node_*`, `ui_panel_toggled(panel, is_open)` (an **open/close request** that the owning panel acts on) and `lua_event` are unchanged. Every `connect` must use a declared signal with matching arity (tests lint this).

### 3.6 GameManager phases, modals, new game (P02)

```gdscript
enum GamePhase { MENU, CHARACTER_SELECT, PLAYING, PAUSED, CUTSCENE }
func change_phase(p)                         # scene boundaries only (menu, select, world start)
func push_modal(name: StringName, pauses_tree := true)   # pause, inventory, journal, shop, dialogue(false), save_menu, load_menu, settings, animal_care, build_menu
func pop_modal(name: StringName)
func is_modal_open(name := &"") -> bool
# phase = PAUSED if any pausing modal; CUTSCENE if only non-pausing modals (dialogue); else PLAYING. get_tree().paused = any pausing modal.
func start_new_game(p_name, p_type, p_farm, p_skin := &"")   # resets own state, sets skin, emits player_character_changed, then new_game_started
```
* Every modal root is `PROCESS_MODE_ALWAYS`, hides itself in `_ready`, owns its key (`I`, `J`, `Esc`...), calls `get_viewport().set_input_as_handled()`, and pushes/pops exactly once. Input order is reverse tree order, so `GameUI` draws/handles dialogue and shop above pause.
* `pause_menu` opens on `pause` only when `phase == PLAYING` and no modal is open; the second `pause` closes it. Quit-to-menu: pop all modals, `change_phase(MENU)`, tree unpaused.
* **Reset contract** (`new_game_started`): GameManager flags/day/zones; EconomyManager gold/inventory/equipment/starter kit; QuestManager runtime state (not definitions); TimeManager weather/accumulator; ShopSystem stock; AnimalHusbandry animals/buildings/counter; SaveManager current slot/timers; FarmGrid is rebuilt with the world scene.
* `GameManager.world_flags` JSON-safe values only (bool/int/float/String).



### 3.7 Area and map architecture (P04 framework, P11/P19 maps)

```
World (Node2D, scenes/main/world.tscn, script world_2d.gd = class WorldRoot2D)   persistent, survives area switches
|- AreaHolder              the current IsoArea (iso areas are PARKED in a cache when left; ortho areas are rebuilt per visit)
|- FarmGrid (Node)         crop model, always alive          |- DayNight (CanvasModulate)  one per canvas
|- Player (Player2D)       parked here between areas; lives in area/Objects otherwise
|- GameUI (CanvasLayer 10, scenes/ui/game_ui.tscn)  HUD, forest HUD, dialogue, inventory, journal, shop, animal care, build menu, pause, save/load, settings
|- Vignette (CanvasLayer 5, dark areas)   |- FadeLayer (CanvasLayer 100)   |- WeatherFx (rain overlay)

IsoArea (Node2D)
|- Backdrop (Parallax2D x2)     sky + far canopy from ArtCatalog.backdrop(theme)
|- Ground (TileMapLayer z=-10, y_sort_enabled)     physics layer 0 -> ground_block(128), layer 1 -> world(1)
|- GroundFx (Node2D z=-9)       target marker, dust, light rings
|- Objects (Node2D y_sort_enabled)   props (Sprite2D centered=false offset=-pivot), strips, crops, NPCs, animals, enemies, loot, PLAYER; ortho: Walls TileMapLayer (y-sorted, tile y_sort_origin=+H/2, solid)
|- Triggers (Warp2D, WhisperZone ...)   |- Bounds (StaticBody2D ring, layer world)
```
**Projections.** `iso` = `TileMapLayer`, `TILE_SHAPE_ISOMETRIC`, `TILE_LAYOUT_DIAMOND_DOWN` (the default STACKED is wrong), tile 128x76, texture_region 144x84; `map_to_local` returns the tile CENTRE (cell (0,0) at (64,38)); `texture_origin` is SUBTRACTED. `ortho` = `TILE_SHAPE_SQUARE` 96x56. WASD is screen-relative in both (`use_diamond_grid_axes` stays off: it would make W walk NE). Facing = `Iso.dir8_of(input)`; target cell = current cell + `Iso.DIR8_TO_CELL_STEP[facing8]` (iso: S(1,1) SW(0,1) W(-1,1) NW(-1,0) N(-1,-1) NE(0,-1) E(1,-1) SE(1,0)).

**Map file `data/maps/<id>.map`** (files starting `_` are test fixtures):
```
# comment                                  @id farm                        @title ZONE_FARM (translation key)
@projection iso|ortho                      @ambient farm|hyggebyen|forest|cave (preset in lua/config/ambient.lua)
@theme farm|hyggebyen|forest                   @zone farm|city|dark_forest|crystal_cave|mushroom_grove   (quest/zone id)
@depth 2        (ortho; minimap chip "Dybe Bregner · 2")   @flight true|false   @music <track|none>
@prop <char> <prop_id>                     object char -> art prop id (collision/strips from lua/config/props*.lua)
@marker <char> <type> key=value ...        one char per marker
@ground  <rows>        @objects  <rows>    same width/height; '#' or space = void
```
Orientation (iso, DIAMOND_DOWN): text COLUMNS run to the screen lower-RIGHT (+x), text ROWS to the lower-LEFT (+y); top-left char = NORTH corner, top-right = EAST, bottom-right = SOUTH, bottom-left = WEST. Ground chars **iso**: `.` grass, `,` grass_flowers, `f` field (tillable; soil swaps when tilled/watered), `p` dirt path, `c` cobble (hyggebyen), `d` deck (platform), `~` water (ground_block, animated), `=` plank bridge (rails/posts auto-built along runs), `#` void (rim cells get invisible blockers, bark skirts chosen from void neighbours). **ortho**: `m n o` forest floor variants, `g` glow floor, `p` moss path, `~` bog (ground_block), `c` cave floor, `x` crystal floor, `W` canopy/cave wall (solid, y-sorted wall tile), `#` void. Object chars: `@` default spawn, chars declared with `@prop` or `@marker`.

| Marker type | Parameters | Handler (package) | Behaviour |
|---|---|---|---|
| `spawn` | `name=` | built-in (P04) | arrival point; `default` mandatory, others `from_<area>` |
| `warp` | `to= spawn= label=KEY [req_day=N] [r=]` | Warp2D (P04) | prompt + fade travel via `area_change_requested`; `req_day` from `adventure.dark_forest_unlock_day` |
| `npc` | `id= [facing= wander= when=]` | `npc_2d.gd` (P14) | visual/name/shop/dialogue from `lua/config/npcs.lua` |
| `enemy` | `kind= [when=]` | `enemy_2d.gd` (P19) | row in `lua/config/enemies.lua` |
| `node` | `kind= [when=]` | `resource_node_2d.gd` (P19) | row in `lua/config/resource_nodes.lua` |
| `whisper` | `text=KEY [r=]` | `whisper_zone.gd` (P19) | `EventBus.whisper_requested` once per visit |
| `sign` / `bed` | `text=KEY` / - | built-in (P04) | read prompt / sleep (after 18:00) |
| `quest_spot` | `quest= objective= prompt=KEY [needs=item:n,..] [consume=1] [prop=] [when=]` | built-in (P04) -> `QuestManager.complete_manual` (P13) | interact to finish a manual objective, optionally consuming items |
| `animal_yard` | `r=` (cells) | `animal_2d.gd` (P20) | centre of the farm-animal wander area |
| `building_slot` | `type=coop\|barn\|house` | `placement_service.gd` (P20) | where a built building appears |
| `field_expansion` | `id= cells= price=` | `farm_view.gd` (P06) | locked field cells; E on its stake sign buys it (`plot_unlocked`) |
| `light` | `kind=lantern\|glow [r= color=]` | built-in (P04) | PointLight2D that ramps in at dusk |

`when=` = `quest:<id>` (active) | `done:<id>` | `flag:<name>` | `night`; evaluated on arrival and whenever quests/flags change (hides node + collider). **Unknown marker types or missing handler scripts are skipped silently** and counted in `area.skipped_markers`, so packages can land independently.

**Y-sort and camera.** Ground `z=-10`; GroundFx `-9`; flying actors `z_index=20`; every figure's shadow `z_as_relative=false, z_index=-5` (else a flying Fe's shadow draws over trees). Sort point of an actor = feet; of a prop = its pivot; big sprites (house_farm 3x2, mushroom houses 2x2) are sliced into `strips=N` vertical strips each sorted at the footprint front line under that strip (one sort key per big sprite is wrong at the side faces - spike-proved). `Camera2D` child of the player: smoothing 6, `limit_smoothed`, limits from the map extents (centre when the map is smaller than the view), `make_current()` + `reset_smoothing()` after every teleport, zoom accumulated on a target value. Area switch = fade 0.22 s, remove player, swap, `player.enter_area(area, spawn)`, ambient/clear colour, `GameUI.set_mode`, TimeManager pause (ortho) / resume (iso), `warm_clips()` behind the fade, unlock zone, fade in 0.25 s.

**Review additions (R.10, binding).** *Skirts*: the platform cliff is three props (`platform_sw`, `platform_se`, `platform_corner`), placed one per edge cell in a non-y-sorted `Skirts` node at `z_index -9`. *strips=N*: strip width 32 px; strip centre `xc = P.x + (u0+u1)/2 - pivot.x` gets sort y `B.y - squash*|xc - B.x|`, clamped below by `L.y` (left of B) or `R.y` (right of B), where `L,B,R` are the left/bottom/right corners of `Iso.iso_footprint(front, fx, fy)`; the strip `Sprite2D` (`centered=false`, AtlasTexture region `(u0,0,u1-u0,H)`) sits at `(xc, sort_y)` with `offset = (P + (u0 - pivot.x, -pivot.y)) - position`. *Water*: four identical `TileMapLayer`s, one visible, swapped every 0.5 s, physics on layer 0 only. *Filters*: `Ground texture_filter=2` (atlases imported without mipmaps), `Objects texture_filter=4`.


### 3.8 Roster and character data (P10 npcs.lua, P05 characters.lua)

`lua/config/npcs.lua` (schema; ids stable, D11):
```lua
config = { npcs = {
  mayor_lyra = { name_key="NPC_MAYOR_LYRA", visual="fairy_mayor", role="mayor", home="hyggebyen", dialogue="mayor_lyra",
                 voice={ pitch=1.12, rate=0.95 }, wander={ radius=3, speed=0.5 }, facing="SW", quests={"intro_lottery","fix_roof","enchanted_garden","fairy_friendship"} },
  ...
}}
```
| Lua id | Display (da) | Visual (P21 art id) | Home | Shop / role | Quests it gives |
|---|---|---|---|---|---|
| `mayor_lyra` | Borgmester Hyldeblomst | `fairy_mayor` | Hyggebyen town hall | - | intro_lottery, fix_roof, enchanted_garden, fairy_friendship |
| `baker_maja` | Bagerfe Rosmarin | `fairy_baker` | bageri | `bakery` | cookie_delivery, birthday_cake, math_bakery_counts |
| `merchant_pip` | Butiksfe Kløvermynte | `fairy_shopkeeper` | frøbutik | `seed_shop` ("Kløvermyntes Frø") | supply_run |
| `pippin_boegeknop` (new) | Pippin Bøgeknop | `mouse_pippin` | Hyggebyen by the bridge | - | lost_cat |
| `fairy_king` (new) | Fekongen | `fairy_king` | Fekongens træhus | intro letter | moonstone_crown |
| `fairy_lily` | Fe-barnet Lily | `fairy_lily` | torvet | - | flower_necklace, rare_mushroom_hunt |
| `smith_thorin` | Smeden Thorin | `raccoon_smith` | smedjen | `smithy` | dark_forest_mining, sword_upgrade, crystal_cave |
| `guard_oak` | Vagten Oak | `bear_guard` | skovporten | - | forest_patrol, night_flower |
| `farmer_rosa` | Dyrehandler Rosa | `rabbit_farmer` | dyrehandlen | `animal_store` | first_animal, animal_products, math_harvest_puzzle |
| `fairy_wizard` | Fe-troldmanden Zephyr | `fairy_wizard` | tårnet | `magic_store` | math_wizard_quiz |
| `cat_morfar_mis` (new) | Morfar Mis | `cat_morfar_mis` | Dybe Bregner (`when=quest:lost_cat`) | - | - |
| `penguin_postman` (new) | Postpingvinen | `penguin_postman` | wanders Hyggebyen | ambient + `sneglens_brev` example | - |

`lua/config/characters.lua` (P05): `skins = { animal_fox={visual="fox"}, animal_rabbit={visual="rabbit"}, animal_hedgehog={visual="hedgehog"}, animal_squirrel={visual="squirrel", fallback="monkey"}, fairy_meadow={visual="fairy"}, fairy_stardust={visual="fairy_stardust", fallback="fairy"}, fairy_dusk={visual="fairy_dusk", fallback="fairy"}, hobbit_pip={visual="hobbit_pip", fallback="raccoon"}, hobbit_moss=..., hobbit_bramble=... }`; `species = { {id="fox", name_key="SPECIES_FOX"(Ræv), skin="animal_fox"}, kanin/rabbit, pindsvin/hedgehog, egern/squirrel }`; `animals = { chicken={baby="chick", adult="hen", baby_scale=0.7}, rabbit={visual="bunny"}, duck, cat={kitten}, dog={puppy}, sheep={lamb}, cow={calf}, deer={fawn}, fox={fox_cub}, owl }`; `enemies` visuals. Race -> skin default: animal -> animal_fox, fairy -> fairy_meadow, hobbit -> hobbit_pip. `animal_bear`/`animal_owl` skins are dropped from selection (the guide lists four species).

### 3.9 Calendar, time, weather (P02)

2 game minutes per real second, 06:00 to 02:00 (game hours 6..25: the hours 24 and 25 are 00:xx and 01:xx of the same game day) = **10 real minutes per day** (CLOCK_26, user answer 2026-10-14), 28 days per season, seasons `foraar sommer efteraar vinter` (ids unchanged), months `Blomstermåned Solmåned Høstmåned Frostmåned`, weekday `(day-1)%7` (Mandag first). Weather ids `klart regn taage sne torden`, rolled once per day from `time.weather_chances.<season>` in game_balance.lua (snow only in vinter), labels `UI_WEATHER_*` ("Solskin" for klart). Only `regn` has a visual (rain overlay) and a rule (all planted plots count as watered before the growth step); the other three are label-only (stub). Sleeping in the farmhouse bed is allowed from 18:00 (earlier: whisper `WHISPER_TOO_EARLY`); 02:00 (game hour 26) passes the player out (sleep clip, fade, next day 06:00, energy and hearts restored). The calendar runs only in iso areas; the forest uses the lantern-oil clock and pauses time.

### 3.10 Farm grid, tools, hotbar, placeables, crops (P06 model, P12 data)

* **Hotbar**: 10 slots holding ITEM IDS (counts always read from EconomyManager); defaults follow the starter kit: `hoe_wooden, watering_can_copper, axe_wooden, pickaxe_wooden, scythe, turnip_seeds, lantern_oil, health_tonic` + 2 free slots (0-count entries are shown dimmed; `EventBus.hotbar_assign_requested` assigns from the backpack); selected via `slot_n`; saved in the world dict.
* **Tool dispatch** (`use_tool` on the target cell; cost = `stamina_cost` of the def x `tool_cost_mult`; swing lock `0.34/dig_speed`, effect `0.16/dig_speed` into the interact clip):

| Item category / `tool_type` | Target | Effect |
|---|---|---|
| `hoe` | empty `f` cell | till (soil tile swaps) |
| `watering` | tilled/planted cell | water; rain waters all; **can capacity is NOT enforced** (cut: reserved field `capacity`) |
| seed (`crop_id`) | tilled empty cell | plant if the crop's `seasons` contain the current season, else whisper `FARM_NOT_IN_SEASON` |
| `scythe` | READY plots in a 3-cell arc | harvest |
| `axe` / `pickaxe` | resource node in the facing cell | hit; `min_power` gates ore (E also works) |
| `fertilizer` | planted/tilled cell | next harvest +1 once |
| `fairy_dust_water` | planted cell | auto-waters 3 days |
| placeable (`scarecrow`, `lantern_post`, `fence`) | free iso cell | `PlacementService.place`; **decorations only** (scarecrow has no crow mechanic - stub) |
| consumable | - | `drink`/click: `heal_half_hearts`, `oil_seconds`, `stamina` |
| `fishing_rod` | - | whisper `WHISPER_FISHING_CLOSED` (stub) |
| weapon | (action areas) | `attack` arc swing, damage from def |
Any tool or `E` on a READY plot harvests it; yield 1 (+1 `harvest_bonus_chance`, +1 fertilizer); harvest goes to the inventory or is refused when full (plot stays READY).
* **FarmGrid growth**: +1 growth day per watered day (rain counts); READY when `growth_days >= stages*days_per_stage`; sprite = `crop_<id>_<0..3>` by progress ratio; `water_window={from,to}` makes moon crops count only when watered 20:00-06:00; JSON-safe `"x,y"` keys; plot ids `plot_x_y`.
* **Crops shipped** (id: seed price / days / seasons / sell): turnip 20/4/foraar+sommer/45; carrot 20/4/foraar+sommer+efteraar/65; pumpkin 60/10/efteraar/160; moonflower ("Månebønne", water_window) 120/12/sommer+efteraar/180; strawberry 45/4/foraar/55; sunflower 30/7/sommer+efteraar/70; catnip 35/5/foraar+sommer/55 (art: first 4 exist, last 3 by P22).
* **Placed items and buildings** persist as `placed:[{item,cell}]` and `buildings` in the save.

### 3.11 Lua runtime decision and data kinds (P10 runtime since the review, R.2; P13 quests; D13/D14)

Keep the regex Lua-subset reader. Supported subset (documented in `docs/lua_api.md`): top-level assignments of literal tables; functions with a single `if cond then return {literal table} end` per branch (newline after `then`); locals initialised from `context.x or false`; conditions of flags/context/payload/literals with `and or not == ~= < >`; statements `api.add_gold add_item remove_item set_flag get_flag has_flag has_item get_gold notification unlock_zone emit log offer_quest complete_quest`. **Not supported** (lint warns at load): `else/elseif`, loops, `[[ ]]`, `local function`, module-style `function M.f`, escaped quotes, `#`, `string./math./table.`, arithmetic in statements, bare-identifier table values.

| `kind` | Directory | Notes |
|---|---|---|
| `config` | `lua/config/*.lua` | merged by top-level key (`player`, `crops`, `economy`, `adventure`, `time`, `ui`, `race_perks`, `combat`, `npcs`, `characters`, `props`, `props_extra`, `ambient`, `enemies`, `resource_nodes`); two files must not define the same top-level key |
| `items` | `lua/items/*.lua` | `name_key description_key category buy_price sell_price rarity max_stack stamina_cost crop_id tool_type power damage heal_half_hearts oil_seconds placeable icon` |
| `quests` | `lua/quests/*.lua` | 3.12 |
| `dialogue` | `lua/dialogue/<npc id>.lua` | `get_dialogue(context)` returns `{speaker, speaker_name_key, lines={{id,text_key,voice_key}}, choices={{id,text_key,action,...}}}` |
| `recipes` | `lua/recipes/*.lua` | `recipes = { id = { name_key, category="craft\|bake\|forge", ingredients={item=n}, output={item=,amount=}, unlock_flag? } }` |
| `shops` | `lua/shops/*.lua` | `shops = { id = { name_key, keeper=<npc id>, greeting_key, buy_multiplier, sell_multiplier, stock={item={price?,stock,restock}} } }` |

Hot reload: `LuaRuntime.reload_scripts()` bound to F9 only in debug builds. Runtime errors in Lua are caught and logged once (no engine error), the call returns `{}`.

### 3.12 Quest schema and objective bindings (P13; the Opgavebog reads exactly these fields)

```lua
kind = "quest"; id = "lost_cat"
meta = { giver="pippin_boegeknop", location="ZONE_CITY", tag="FIND", category="help", repeatable=false, cooldown_days=0, requires_zone="" }
-- title_key / description_key default to QUEST_<ID>_TITLE / QUEST_<ID>_DESC
objectives = {
  { id="ask_neighbours", target=3, on="dialogue_started", any_of={"baker_maja","merchant_pip","mayor_lyra","farmer_rosa"}, description_key="OBJ_LOST_CAT_ASK_NEIGHBOURS" },
  { id="follow_pawprints", target=1, on="manual", description_key="OBJ_LOST_CAT_FOLLOW_PAWPRINTS" },     -- finished by a quest_spot marker
  { id="find_cat", target=1, on="dialogue_started", npc="cat_morfar_mis", description_key="OBJ_LOST_CAT_FIND_CAT" },
  { id="return_cat", target=1, on="dialogue_started", npc="pippin_boegeknop", after_others=true, description_key="OBJ_LOST_CAT_RETURN_CAT" },
}
rewards = { gold=150, items={ catnip_seeds=3 }, friendship={ pippin_boegeknop=1 } }
```
**`on=` vocabulary** (+ filter fields): `item_gained(item)`, `crop_planted(crop?)`, `crop_watered`, `crop_harvested(crop?)`, `zone_entered(zone)`, `dialogue_started(npc | any_of)`, `animal_adopted`, `animal_fed`, `animal_product_collected(product)`, `building_built(type)`, `enemy_defeated(kind)`, `recipe_crafted(recipe)`, `quest_completed`, `manual`. Flags: `after_others=true` (turn-in only counts when all other objectives are done), `have=true` (progress = inventory count, stays done once reached), `amount` per event. UI text: `OBJ_<QUEST>_<OBJ>` -> `OBJ_<OBJ>` -> `description`. Rewards: `gold`, `items`, `friendship` (world flag `friend_<npc>`, shown as rose chip "♥ Pippin"). The book additionally shows `quests/<id>.lua` as the source path.

| Quest | Giver | Tag | Objectives -> binding |
|---|---|---|---|
| intro_lottery | mayor_lyra (auto-accepted by IntroSequence) | FIND | plant_first_crop (crop_planted), cross_bridge (zone_entered city), talk_to_mayor (dialogue mayor_lyra) |
| lost_cat | pippin_boegeknop | FIND | ask_neighbours x3, follow_pawprints (manual quest_spot at the bridge), find_cat (dialogue cat_morfar_mis), return_cat (after_others) |
| cookie_delivery | baker_maja | HØST | collect_carrot 12 (have), deliver_to_baker (after_others) |
| fix_roof | mayor_lyra | BYG | collect_wood 8, collect_moss 4, repair_roof (manual quest_spot on the bakery roof, `needs=wood:8,moss:4 consume=1`) |
| moonstone_crown (NEW) | fairy_king | SKOV | collect_moonstone 1 (item_gained), return_to_king (after_others) |
| animal_products | farmer_rosa | HØST | collect_egg 5, collect_milk 3, deliver_to_rosa |
| first_animal | farmer_rosa | BYG | build_coop (building_built coop), adopt_animal, feed_animal 3 |
| birthday_cake | baker_maja | HØST | collect_turnip 3, collect_moonflower 1, deliver_cake (+ craft honey_cake optional) |
| enchanted_garden | mayor_lyra | HØST | collect_rare_seeds 3, water_garden 3 (crop_watered), plant_enchanted 2 |
| fairy_friendship | mayor_lyra | VENSKAB | help_citizens 3 (quest_completed), earn_friendship 5 (friendship_token), collect_fairy_dust 2 |
| flower_necklace | fairy_lily | FIND | collect_flowers 5 (wild_flower from `flower_patch`), craft_necklace (recipe), deliver_necklace |
| rare_mushroom_hunt | fairy_lily | SKOV | collect_mushrooms 4, find_glowing (manual spot in Svampelunden), deliver_to_lily |
| dark_forest_mining | smith_thorin | SKOV | enter_dark_forest (zone), collect_iron 6 (iron_ore), collect_amethyst 2, return_to_smith |
| crystal_cave | smith_thorin | SKOV | enter_dark_forest, collect_crystals 5 (crystal_shard), explore_cave (zone crystal_cave), return_to_smith |
| sword_upgrade | smith_thorin | BYG | collect_iron_ingots 3 (forge recipe at the smith), collect_fairy_dust, deliver_to_smith |
| forest_patrol | guard_oak | SKOV | enter_forest_edge (zone dark_forest), collect_moss 6, return_to_oak |
| night_flower | guard_oak | SKOV | collect_night_bloom (`night_bloom` node, `when=night`), return_to_oak |
| supply_run | merchant_pip | HØST | collect_wood 10, collect_stone 6, deliver_to_pip |
| math_bakery_counts / math_wizard_quiz | baker_maja / fairy_wizard | LÆR | math_*_q1..q3 (manual via `math_answer`) |
| math_harvest_puzzle | farmer_rosa | LÆR | math_harvest_carrot (harvest carrot 12), math_collect_stone (21), math_collect_mushroom (8) |
| sneglens_brev (docs example) | penguin_postman | FIND | talk_to_baker (dialogue baker_maja) |

Node kinds this table needs from P19: `tree_chop` (wood, axe), `rock_stone` (stone, pickaxe), `moss_patch`, `flower_patch`, `night_bloom`, ores, crystals, mushrooms, `apple_tree`.

### 3.13 Combat, perks, lantern oil (numbers live in Lua; values at sprite scale 1.0)

The spike tuned distances for sprites drawn at 0.6; sprites are now unscaled, so **every distance/speed is the spike value x 1/0.6** (timings unchanged). Same screen feel: crossing the view takes ~11 s at walk speed.

| Key (file) | Spike | Final | | Key | Spike | Final |
|---|---|---|---|---|---|---|
| walk / run (game_balance `player`) | 170 / 270 | **285 / 450** | | swing_radius (combat) | 118 | **197** |
| accel / decel | 1500 / 2000 | 2500 / 3300 | | dodge_distance | 190 | 317 |
| hop impulse / gravity | 370 / 1050 | 620 / 1750 | | light_radius | 330 | 550 |
| flight altitude / climb | 90 / 135 | 150 / 225 | | knockback | 260 | 433 |
| body ellipse rx | 15 | 25 | | bat speed / detect / altitude | 105/330/44 | 175/550/73 |
| interact circle | 34 | 45 | | boss speed / detect | 125/560 | 208/930 |

Unchanged numbers: 10 half-hearts (5 hearts), swing 0.28 s active 22-72%, half-angle 62 degrees, dodge 0.30 s with i-frames 0.42 s cooldown 0.9, fe-lys cooldown 7 s stun 1.6 s, drink +4 half-hearts, hurt i-frames 0.9 s, lantern oil 150 s (`lantern_oil` item +60 s), min light 35%, whisper at 20%, `oil_empty_hurt_interval` 12 s (0 disables). Race perks: animal `dig_speed 1.3, tool_cost_mult 0.75, harvest_bonus_chance 0.2`; fairy `can_fly, flight_max_seconds 8, flight_energy_per_second 10, talks_to_flowers`; hobbit `shop_discount 0.1, bake_bonus 0.25`. Damage flash is thorn-berry pink `e58fa6`, hearts pink/pale-pink/slate, boss bar `b3436b` with gold ring - **no red** anywhere.

### 3.14 Voice and audio contract (P24; P14 consumes)

Voice key = path below `res://assets/audio/`: `voice/<npc_id>/<line_id>` (+ `.ogg`). `AudioManager.play_voice(key)` (no second prefix), `voice_exists(key)`, single voice at a time, stops on advance/close, plays only in `da`. Buses `Master, Music, SFX, Voice` created idempotently, volumes saved in `user://settings.cfg [audio]`. Speaker pitch/rate in `npcs.lua`. Files listed in `assets/audio/voice/RECORDED.txt` are human recordings and are never regenerated.

### 3.15 Autoload and service API gaps (the audits' missing members, one table; asset contract = section 6.2)

| Service | Added / changed API | Pkg |
|---|---|---|
| EventBus | signals of 3.5 | P02 |
| GameManager | `push_modal/pop_modal/is_modal_open`, derived phase, `start_new_game(name,type,farm,skin)`, `total_day()`, JSON-safe `get_flag/set_flag`, `unlock_zone` -> `zone_unlocked`, `unlocked_zones` read by `warp req_day` | P02 |
| TimeManager | `weekday_index/weekday_name/season_month_name/date_text/weather_name/is_raining/is_night`, idempotent `pause_time/resume_time`, `reset()` | P02 |
| LocalizationManager | `set_locale(locale, announce)`, `locale_changed`, `t(key,args)`, `has_key`, `all_keys`, `lint()` | P03 |
| EconomyManager | `reset()`, 24 slots + `max_stack`, `add_item(id,n,silent) -> bool` + `item_gained`, validated `remove_item/has_items`, `equip/get_tool_power`, `use_item` | P12 |
| ShopSystem | Lua shops, `get_buy_price(shop,item)` (shop multiplier + hobbit discount), `get_sell_price` (min 1, unsellable -> 0), `open_shop/close_shop`, `reset()` | P12 |
| CraftingSystem (static) | `get_recipes(category?)`, `can_craft(id) -> {ok, missing[{item,have,need}]}`, `craft(id) -> bool`, emits `recipe_crafted` | P12 |
| LuaRuntime | kinds `recipes`/`shops`, `get_recipes()`, `get_shop(id)`, `get_npc(id)`, `lint_report`, `reload_scripts()` (F9 in debug), `api.get_flag`, `api.emit(name,payload)` | P10 |
| QuestManager | `quest_defs` (never saved), `reset()`, `on=` bindings, `get_objective_text`, `get_tracked(max)`, `complete_manual(quest,objective)`, repeatable/cooldown | P13 |
| SaveManager | `save_game(slot)`, `load_game(slot) -> bool`, `get_latest_slot()`, `get_save_summary(slot)`, `pending_world`, validate/migrate, auto slot | P15 |
| AnimalHusbandry | `reset()`, `day_counter`, `build_building(type, free)` (+ `building_built`), purchase/inventory adoption, positions in `to_dict` | P20 |
| AudioManager | `play_voice(key)`, `voice_exists(key)`, buses, volume persistence, SFX hooks | P24 |
| WorldRoot2D (group `world_2d`) | `travel(area, spawn)`, `sleep()`, `to_dict/from_dict`, fields `area player farm` | P04 |
| Player2D (group `player`) | `enter_area`, `take_damage(half, from)`, `cd_ratio(name)`, `begin_talk/end_talk`, `set_character(visual)`, `hotbar`, stats | P06 |
| GameUI (group `game_ui`) / DialogueUI (group `dialogue_ui`) | `set_mode`, `get_screen` / `start_dialogue(speaker: Dictionary, lines, choices)`, signals `choice_selected`, `dialogue_finished` | P07 / P14 |
| ArtCatalog, GameData (static) | `terrain prop backdrop icon portrait character_exists missing()` / `lua perk combat item_def visual_for_skin race_key` | P04 |



## 4. World / area blueprint

Six areas, two projections, one persistent world root. Coordinates are map cells `(col,row)` of the ASCII grid (iso: col -> screen lower-right, row -> lower-left). Authors (P11 iso maps, P19 forest maps) place markers by these targets; exact cells are theirs to tune as long as the connectivity and count tests pass.

### 4.0 Area graph, zones, spawns

```
                +--------------------------- skovport (stone gate) -------------+
                |                                                               |
   [farm] <==== hængebro ====> [hyggebyen] ----- west gate (Oak) -----> [skovkant] <+  (also gate from farm)
   iso  Trætoppen   iso  Hyggebyen                                          ortho depth 1  zone dark_forest
                                                                             |
                                                                   [dybe_bregner]  ortho depth 2  (boss, Morfar Mis, moonstone)
                                                                    /          \
                                                        [svampelunden]     [krystalgrotten]
                                                     ortho depth 2 (mushroom_grove)   ortho depth 3 (crystal_cave)
```
| Area id | File | Projection | Zone id | Ambient | Flight (Fe) | Music | Time |
|---|---|---|---|---|---|---|---|
| farm | `data/maps/farm.map` | iso | farm | farm | yes | farm_theme | runs |
| hyggebyen | `data/maps/hyggebyen.map` | iso | city | hyggebyen | yes | city_theme | runs |
| skovkant | `data/maps/skovkant.map` | ortho | dark_forest | forest | no | forest_theme | paused (oil clock) |
| dybe_bregner | `data/maps/dybe_bregner.map` | ortho | dark_forest | forest | no | forest_theme | paused |
| svampelunden | `data/maps/svampelunden.map` | ortho | mushroom_grove | forest | no | forest_theme | paused |
| krystalgrotten | `data/maps/krystalgrotten.map` | ortho | crystal_cave | cave | no | crystal_cave_theme | paused |

Music tracks are names only (missing files are silent). Warps (`from -> to : spawn`): farm->hyggebyen:from_farm (end of the bridge), farm->skovkant:from_farm (stone gate), hyggebyen->farm:from_hyggebyen, hyggebyen->skovkant:from_hyggebyen (west gate), skovkant->farm:from_skovkant, skovkant->hyggebyen:from_skovkant, skovkant->dybe_bregner:from_skovkant, dybe_bregner->skovkant:from_dybe, dybe_bregner->svampelunden:from_dybe, dybe_bregner->krystalgrotten:from_dybe, svampelunden->dybe_bregner:from_svamp, krystalgrotten->dybe_bregner:from_krystal. Fainting in a forest area returns to farm:`from_skovkant` with full hearts and the whisper `WHISPER_FAINT`. `adventure.dark_forest_unlock_day` defaults to 1 (open from the start; the gate code stays for tuning).

### 4.1 Trætoppen farm (`farm.map`, iso, ~44x44 cells, raised platform with bark skirts, void rim)

| Element | Count / size | Where (approx.) | Notes |
|---|---|---|---|
| Field `f` | 12x7 = 84 cells (>= 84 asserted) | west-centre (cols 9-20, rows 12-18) | all tillable; `~` pond SW of it (cols 7-13, rows 20-24) |
| Field expansion | 1 zone, 6x7 | east of the field | `@marker field_expansion id=east price=800`, bought at its stake sign |
| Farmhouse | `house_farm` 3x2 front cell facing the plaza | NE quadrant (front cell ~ (30,19)) | `bed` marker at the door; strips=3 |
| Spawn | `default`, `from_hyggebyen`, `from_skovkant` | default beside the house | new game also plays IntroSequence here |
| Orchard | 3 `node kind=apple_tree`, sign `SIGN_ORCHARD` | NE corner | daily respawn |
| Trees / rocks | 2 `tree_chop`, 2 `rock_stone`, bushes, 1 `flower_patch` | edges, a few in the way of paths | wood/stone/wild_flower sources for quests |
| Animal yard | `animal_yard r=3` | SE quadrant (cols 25-31, rows 24-30) | Animal2D wander |
| Building slots | coop, barn, house | around the yard: (26,26), (32,27), (20,29) | PlacementService |
| Hængebro | plank bridge `=` row 16, cols 21-28, posts+ropes | leaves the platform to the east | warp `to=hyggebyen spawn=from_farm label=ZONE_CITY` at its end; `quest_spot` paw prints (`lost_cat.follow_pawprints`) on it |
| Skovport | stone gate prop + warp | NW edge (cols 6-8, rows 7-9) | `to=skovkant spawn=from_farm label=ZONE_DARK_FOREST` |
| Lanterns / scarecrow spot | 3 `lantern_post` (glow at dusk), 1 `scarecrow` | along the path | decor |
| NPCs | none on the farm | - | all NPCs live in Hyggebyen; animals via husbandry |

### 4.2 Hyggebyen (`hyggebyen.map`, iso, ~40x40, lavender/rose palette, cobble torv)

Cobble `c` square in the centre with a fountain; ring of mushroom houses (`house_mushroom_rose/lavender/mint`, 2x2) and the new Hyggebyen building variants of P22. NPC markers (ids only; visual/facing/wander from npcs.lua):

| NPC | Position | Notes |
|---|---|---|
| mayor_lyra (Hyldeblomst) | steps of the town hall, N side of the torv | quest hub |
| baker_maja (Rosmarin) | at the bageri door, NE | shop `bakery`; roof `quest_spot` (fix_roof) on the bageri |
| merchant_pip (Kløvermynte) | frøbutik, NW | shop `seed_shop`, the guide's shop screen |
| pippin_boegeknop | by the bridge end, SW | lost_cat giver |
| fairy_king (Fekongen) | Fekongens træhus, far N (stairs of `deck_hyggebyen`) | opening letter + moonstone_crown |
| smith_thorin | smedje, E | shop `smithy` |
| farmer_rosa | dyrehandel, SE | shop `animal_store` |
| fairy_wizard (Zephyr) | tower, W | shop `magic_store` |
| fairy_lily | torv, wanders | |
| guard_oak | west gate | patrol |
| penguin_postman | wanders the torv | ambient |

Also: warps (hængebro SW -> farm; west gate -> skovkant), `blossom` trees, `lantern_post`s, signs, 6 `light` markers, `fountain`, `well`, `market_stall`. Walkable-area flood fill must reach every NPC, warp and spawn.

### 4.3 Mørkeskoven (ortho 96x56 floor, 36 degree sprites, free movement, `@ambient forest|cave`)

| Map | Size | Content (counts are asserted by tests/sections/forest.gd) |
|---|---|---|
| skovkant (depth 1) | ~40x26 | farm gate + Hyggebyen gate spawns, 3 bats, 2 tornebusk, 4 `glow_mushroom`, 2 `moss_patch`, 1 `tree_chop`, 3 whisper zones, Oak patrol marker, warp to dybe_bregner |
| dybe_bregner (depth 2) | ~56x40 | ferns (`fern` nodes x6), 3 ugleoje, 2 bats, glowing path, boss clearing (**Snurresvampen**, chest `chest_closed` that opens on kill), `cat_morfar_mis` NPC (`when=quest:lost_cat`), 1 `moonstone` crystal, 2 `night_bloom` (`when=night` = `TimeManager.is_night()` (hour >= 20) as it was when the player entered; time is frozen inside the forest, so the quest text tells the player to enter after dusk), 2 whispers, warps to svampelunden and krystalgrotten |
| svampelunden (depth 2) | ~32x24 | 3 lysesvamp critters, 8 mushroom nodes (glow/rare), 1 `quest_spot` (`rare_mushroom_hunt.find_glowing`), warp back |
| krystalgrotten (depth 3, cave ambient, no sky backdrop) | ~40x28 | 6 crystal nodes (amethyst x3, moonstone x1, emerald x2), 4 ore nodes (iron x2, copper x1, gold x1), 2 ugleoje, cave `W` walls, warp back |

Enemy stats and resource node yields: `lua/config/enemies.lua` and `resource_nodes.lua` (P19). Loot is dropped as orbs and picked up automatically; depleted nodes respawn after `adventure.ore_respawn_days` (state in `world_flags`). Lantern oil starts at 150 s on each entry (carried `lantern_oil` items refill 60 s each); at 0 the light shrinks to 35% and every 12 s costs a half heart (configurable).

### 4.4 Day/night, palettes, collision (summary of 3.3/3.7)

* `lua/config/ambient.lua`: per preset a list of `{hour, color}` keyframes for the single `CanvasModulate`; farm (warm honey, noon ~0.98 luminance, night ~0.40), hyggebyen (lavender/rose), forest (fixed night navy #1c2138 + PointLights and teal mushroom glow #6fd6c4), cave (darker). Season multiplier foraar neutral, sommer warm, efteraar orange, vinter cool (tint only; seasonal tile sets are cut).
* Glow sprites (lantern posts, windows, mushrooms, crystals) are additive and ramp with the night factor; they are never baked into the base sprite.
* Collision: iso water/void = `ground_block` tiles, solid props = `world` bodies from `props.lua`/`props_extra.lua` (trunk circle r=26, house footprint polygon padded 20 px, rocks r=30, bushes none), ortho walls = wall tiles. Fliers (Fe, bats) drop `ground_block` from their mask; landing is refused over water/void.



## 5. UI: Theme, component library and every guide screen

Source: the UI spike (`SU`) - 17 generated scenes, theme from the guide's numbers, 123-check headless smoke, mean pixel difference to the HTML guide at 1280x720: title 7.5, farm HUD 8.2, quest book 11.3, forest HUD 14.5, Vælg figur 14.7, shop 17.5, backpack/workshop 21.9 (the remaining difference is placeholder art, not layout). P07 lifts the foundation; screens are lifted and **adapted to the real systems** by the package that owns the system they show.

### 5.1 Design tokens and Theme (P07; `tools/ui/build_theme.gd` is the single source - never edit theme.tres by hand)

* Colours (`scripts/ui/theme/tt_colors.gd`, all from the guide's `renderVals`): INK `#2b2340`, PARCHMENT `#f4e6c4`, PARCHMENT_DARK `#ecdcb4`, CHALK `#fbf5e6`, GOLD `#e3c372`, MOSS `#6b9a3e`, HONEY `#e8b04a`, BARK `#7a4e2d`, ROSE `#e58fa6`, THORNBERRY `#b3436b` (damage, "too dear", missing ingredient - never red), LAVENDER `#9b86d6`, forest: NIGHT `#1c2138`, NIGHT_TRACK `#2f3654`, GLOWSHROOM `#6fd6c4`, OWL_EYE `#f2c14e`. Muted text `#4c4058`/`#6a5a48`, dividers `#cdb98f`.
* Fonts: Caprasimo (numbers, time, money, buttons, titles; never under 20 px except slot counts 15-16 px as in the guide), Alegreya Sans 500/700/800 (body; OpenType `lnum` for lining figures - a deliberate legibility deviation from the mock's old-style figures), IBM Plex Mono (eyebrows, paths), TTSymbols (21-glyph metric-corrected fallback for ▸ ◂ ♥ ★ ✓ ✗ ·; a fallback with large metrics would stretch every Label - spike pitfall). Æ Ø Å æ ø å are tested with `has_char`.
* **Gold ring means focus/selected only.** Panels = parchment + 2 px ink + double gold ring (4 px gold + 2 px ink drawn outside the control rect like CSS box-shadow) via the scripted `TTBoxStyle` (vector, sharp at any stretch).
* Theme type variations (use `theme_type_variation`, never per-node overrides): panels `PanelParchment/L/L24/Book/Menu/Hud/Card/Bubble/Round/Hotbar/Whisper/Loot/Toast/Tooltip/Scrim`, pills `PillGold/PillNight`, buttons `ButtonPrimary/Secondary/Tertiary` (S/L), `MenuRow PillTab Chip RowButton RecipeRow CardButton SlotEmpty/Filled/Rare StepperButton ChoiceRow`, meters `MeterGreen/Rose/Honey/Vertical/Night/Boss`, labels `HeroTitle Display48..15 MoneyPill NamePlate KeyCap Eyebrow ...`; disabled = dashed.
* Components (`scripts/ui/components`, `scenes/ui/components`): `item_slot` (empty/filled/selected/rare), `quantity_stepper`, `ability_slot` (cooldown veil + number), `notification_toast`, `tt_hearts` (half hearts), `tt_item_icon`, `tt_sprite_face` (pack sprite frame in a Control), `tt_stripes` (placeholder stripes), `tt_dashed_line`.
* Rules every screen obeys: design size 1280x720 (never multiply by 1.5), modal roots `PROCESS_MODE_ALWAYS` and hidden in `_ready`, panel children inside a plain Control (a `PanelContainer` lays out ALL children over its whole rect), Button content wrapped in a full-rect `MarginContainer` with `mouse_filter=IGNORE`, hidden containers do not sort children (measure after show), unique names prefixed per card (`FoxFace`, not `Face`), `texture_filter` linear+mipmaps for portraits, first-import font errors vanish on the second `--import`.

### 5.2 Screen -> scene -> script -> package -> data it needs

| Guide screen | Scene | Script | Pkg | Reads / emits |
|---|---|---|---|---|
| Titelskærm | `scenes/main/main_menu.tscn` | `scripts/ui/main_menu.gd` | P16 | `SaveManager.get_latest_slot/get_save_summary` ("Fortsæt · Dag N"), `assets/ui/keyart/title.webp`, `LocalizationManager.set_locale` (the "v0.1 · Dansk" tag is the switch) |
| Vælg figur (1/2, 2/2) | `scenes/ui/character_select.tscn` | `character_select.gd` | P16 | `lua/config/characters.lua` (skins, species chips), `race_perks.lua` texts, `GameManager.start_new_game(name,type,farm,skin)` |
| HUD på gården | `scenes/ui/hud.tscn` | `hud.gd` | P17 | `gold_changed`, `time_of_day_changed`, `day_started`, `weather_changed`, `TimeManager.date_text()`, `player_stats_changed`, `hotbar_changed`, `quest_*` + `QuestManager.get_tracked/get_objective_text`, `notification_posted`, `interaction_prompt_changed` |
| Butik i Hyggebyen | `scenes/ui/shop_ui.tscn` | `shop_ui.gd` | P18 | `shop_opened(shop_id)`, `ShopSystem` (Lua shop, `get_buy_price`, buy/sell), keeper portrait via `npcs.lua`, `ArtCatalog.icon` |
| Opgavebog | `scenes/ui/quest_journal.tscn` | `quest_journal.gd` | P14 | `QuestManager.get_quest_def()` fields through `tt_quest_text.gd` (5.3), `npcs.lua` giver, `quest_*` signals |
| Rygsæk (24 slots) + Værksted | `scenes/ui/inventory_ui.tscn` | `inventory_ui.gd` | P18 | `EconomyManager` (inventory, `use_item`), `CraftingSystem` (`lua/recipes`), `player_inventory_changed` |
| Dialogboks | `scenes/ui/dialogue_ui.tscn` | `dialogue_ui.gd` | P14 | `start_dialogue(speaker, lines, choices)`, portrait, `AudioManager.voice_exists`; emits `choice_selected(action,data)`, `dialogue_finished` |
| Mørkeskoven HUD | `scenes/ui/forest_hud.tscn` | `forest_hud.gd` | P19 | `player_health_changed`, `player_oil_changed`, `boss_bar_changed`, `whisper_requested`, `item_gained` (loot feed), `area_changed` (zone chip `ZONE_x · depth`), `Minimap2D` texture, `Player2D.cd_ratio('slash'\|'dodge'\|'light'\|'drink')`, key names read from the InputMap |
| Pause (ikke i guiden, samme sprog) | `scenes/ui/pause_menu.tscn` | `pause_menu.gd` | P16 | modal stack; Fortsæt, Gem, Indlæs, Indstillinger, Hovedmenu |
| Indstillinger | `scenes/ui/settings_ui.tscn` | `settings_ui.gd` | P16 | language chips, Master/Music/SFX/Voice sliders, fullscreen, window size |
| Gem / Indlæs | `scenes/ui/save_load_ui.tscn` | `save_load_ui.gd` | P16 | `SaveManager` slots 0-5 + auto |
| Dyrepleje / Byg | `scenes/ui/animal_care_ui.tscn`, `build_menu_ui.tscn` | `animal_care_ui.gd`, `build_menu_ui.gd` | P20 | `AnimalHusbandry`, `PlacementService` (same parchment language, designed by analogy) |
| Notifikationer | `scenes/ui/components/notification_toast.tscn` | - | P07 + P17 | `notification_posted` (icon `item` -> loot feed in the forest, toast on the farm) |
| UI root | `scenes/ui/game_ui.tscn` | `game_ui.gd` | P07 | instantiates the screens above if their scene exists; `set_mode(&"farm"\|&"action")` |

### 5.3 Opgavebog reads Lua directly (P14 + P13)

| Book element (guide) | Lua field |
|---|---|
| Row: tag chip colour + text FIND/HØST/BYG/SKOV | `meta.tag` (colours: FIND lavender `#e2d8f4`, HØST light moss `#cde0a6`, BYG light honey `#f0d49a`, SKOV blue-grey `#b9c3e3`) |
| Row title / giver line ("Pippin · Hyggebyen") | `title_key` (default `QUEST_<ID>_TITLE`) / `meta.giver` -> `npcs.lua` `name_key` / `meta.location` |
| Detail portrait (96 px, gold ring) | giver's `visual` -> bust portrait |
| "Fra Pippin Bøgeknop · Hyggebyen" | `meta.giver` + `meta.location` |
| Body text | `description_key` (default `QUEST_<ID>_DESC`) |
| Steps with ✓ / strike-through | `objectives[].description_key` + live progress from `QuestManager` |
| Rewards chips: "150 guldagern", "Kattemynte-frø × 3", rose "♥ Pippin" | `rewards.gold`, `rewards.items`, `rewards.friendship` |
| Footer "quests/pippins_kat.lua" | the quest's source path (`quests/<id>.lua`) |
| Tabs "Aktive · 4" / "Fuldført · 11" | `QuestManager.active_quests` / `completed_quests` counts |
New quests therefore need **no UI change** - the book only reads fields (the guide's promise).

### 5.4 Behaviour (all screens)

Keyboard/gamepad: `ui_*` focus walk (tested on title, select, shop, pause, journal, inventory); `Esc` closes the top modal; first focus is set on open; the gold ring is the focus indicator. Language switch re-labels every open screen (`NOTIFICATION_TRANSLATION_CHANGED`) with zero engine errors. Stretch (tested numerically at 1920x1080, 2560x1080, 1600x1200, 1280x720, 3440x1440): HUD card stays 40 px from the right edge, hotbar centred 30 px from the bottom. Blurred world backdrop for shop/book uses `blur_scrim.gdshader` with a per-screen tint (lavender shop, `#3a3150` book and backpack).



## 6. Art and characters

### 6.1 Integrating the existing character pack (P05; verified by the lead: imports and runs in 4.7.2 with zero errors)

| Pack item | What happens |
|---|---|
| `assets/isometric_characters/<12 ids>/**` (bat cat bear rabbit fairy monkey capybara fox raccoon penguin hedgehog frog; 8 rows S SW W NW N NE E SE, frames in columns, cell 256x256, pivot (128,200); clips idle4 walk6 run6 jump4 fall3 land3 celebrate6 interact4 hit3 sleep4 talk4 + takeoff4 hover5 fly6 flight_land4 for fairy and bat; `portrait.webp`, `animations.json`), `shadow.png`, `manifest.json` | **Copy** unchanged to the same res:// paths (22 MB WebP). Import presets (S3TC, mipmaps) via `tools/import/apply_import_presets.py`. |
| `scripts/isometric/iso_chibi_sprite_2d.gd` | **Merge** the world-spike gameplay patch (facing_override, `play_action(clip, rate)`, `clip_duration/has_clip/cancel_action/is_action_playing`, `set_spin` roll about body centre, `flash`, `get_portrait`, `preload_clips`, awaitable `warm_clips`, shadow on an absolute floor z) and the art-spike patch (open character ids from `animations.json`, `display_scale`, glow), plus `create(id)` and the fallback chain; sprite texture filter inherits the project default. |
| `IsoPlayerController2D` | **Replaced** by `Player2D` (P06). Kept: jump/fake-height and flight constants and the "Fe/bat flight toggle" idea; removed: Tab/C/E demo keys; `use_diamond_grid_axes` rejected (W would walk NE). Numbers rescaled (3.13). |
| `IsoWanderer2D` | **Replaced** by the wander code of `Npc2D`, `Animal2D`, `Enemy2D` (collision-aware, walkable cells, no NavigationAgent). |
| `isometric_ground_2d.gd`, `isometric_demo.gd`, demo/player/npc scenes, per-character scenes | **Deleted** (area framework + one generic `chibi.tscn`). |
| `docs/` previews and READMEs | **Moved** to `docs/art/isometric_pack/`; the nested project, `project.godot`, `tests/validate_isometric.py` deleted. |

**Mapping of choices to sprites** (data in `lua/config/characters.lua`): Skovdyr species chips Ræv/Kanin/Pindsvin/Egern -> `fox / rabbit / hedgehog / squirrel` (squirrel = new, fallback monkey); Fe -> `fairy` (meadow, pack) or `fairy_stardust` / `fairy_dusk` (new, fallback fairy), flight = the Fe perk using takeoff/hover/fly/flight_land; Hobbit -> `hobbit_pip / hobbit_moss / hobbit_bramble` (new, fallback raccoon). Pack characters in the world: `bat` = normal forest flier (its W/E rows are edge-on, so it is never scaled up into a boss), `fox`/`rabbit`/`hedgehog`/`fairy` = player skins; `bear`, `cat`, `monkey`, `capybara`, `frog`, `penguin`, `raccoon` are fallbacks/stand-ins and optional ambient forest critters (Oak, Morfar Mis, the postman, Thorin are NEW variants, not re-uses). Clip use: `talk` + portrait in dialogue, `celebrate` on quest completion and harvest, `hit` on damage, `sleep` at the bed and when passing out, `interact` for tool use, `jump/fall/land` for the hop, `takeoff/hover/fly/flight_land` for flight.

Portraits: the pack's `portrait.webp` are full-body crops; dialogue/book/shop use **bust** portraits (head and shoulders, 14 degree camera): new characters carry one in their folder, the 12 pack characters get `assets/portraits/<id>.webp` (P21).

### 6.2 ASSET CONTRACT (verified in Godot 4.7.2 by the art spike; P08 documents, P21-P23 produce, P04/P05/P07 consume)

One orthographic camera, **36 degree elevation, 87.074 px per metre**, azimuth 45 degrees for iso art (0 for ortho tiles/walls), key light from the upper left in camera space, three lights, warm outline `(75,60,73)` alpha .55 on world sprites (the ink `#2b2340` outline vanishes on night blue; ink is for icons/UI only). **Sprites are never scaled individually** (all new `animations.json` carry `display_scale 1.0`); zoom is the camera (`Iso.DEFAULT_ZOOM`).

| Class | Path | Format |
|---|---|---|
| Characters | `res://assets/isometric_characters/<id>/<clip>.webp`, `portrait.webp`, `animations.json` | cell 256x256, pivot (128,200), 8 rows S SW W NW N NE E SE, frames in columns, WebP RGBA q97. `animations.json` adds `role` (player\|npc\|enemy\|boss\|critter\|farm_animal), `family`, `flyer`, `portrait`, `display_scale`, `glow`. New clips `attack` (5 f, 12 fps, once), `spin` (8 f, 14 fps, loop). |
| Clip sets per role | | player all 11 (+4 flight for fairies); npc_flyer idle hover talk celebrate interact; villager idle walk talk celebrate interact sleep; farm_animal idle walk run interact sleep hit celebrate; enemy idle walk run attack hit; boss idle walk attack hit spin; critter idle walk run hit sleep |
| Portraits of pack characters | `res://assets/portraits/<id>.webp` | 256x256 bust |
| Iso tiles | `res://assets/iso_tiles/<terrain>.png` + `tiles.json` | tile 128x76, atlas cell 144x84 with ~1.4 px overscan, **periodic 4x4 variants**, `atlas_coords = Vector2i(cell.x % 4, cell.y % 4)`; terrains grass, grass_flowers, grass_hyggebyen, grass_hyggebyen_flowers, soil_tilled, soil_watered, path_dirt, deck_farm, deck_hyggebyen, cobble_hyggebyen, forest_floor, forest_floor_glow, void_haze, water_0..3 (4-frame animation, 2x2 variants) |
| Ortho tiles (NEW) | `assets/iso_tiles/ortho_<terrain>.png` (`proj: ortho`) | tile 96x56, same periodic trick |
| Props | `res://assets/iso_props/<id>.png` + `props.json` | ground-origin `pivot` (px from PNG top-left = tile centre), `footprint` (tiles), optional `<id>_glow.png` additive halo + centre; `Sprite2D centered=false, offset=-pivot` under a y-sorted parent; ortho wall props carry `proj: ortho` |
| Backdrops (NEW) | `assets/backdrops/<theme>_sky.webp`, `<theme>_far.webp` | 1920x1080 sky, seamless far canopy strip |
| Icons | `res://assets/icons/items/<item_id>.webp` | 128x128 RGBA lossless, ink `#2b2340` 2 px outline, shown 56-72 px |
| Key art | `assets/ui/keyart/title.webp` (+ `title_layers/`) | 1920x1080 |
| Import | | linear + mipmaps (project default **2**, CanvasItem filter 4 on Objects; tile atlases without mipmaps, Ground filter 2 - R.1); character clip sheets VRAM-compressed S3TC (`compress/mode=2`, `high_quality=false`) via import stubs written BEFORE the first import (R.7); portraits/tiles/props/icons lossless |

Memory (measured by the world spike): 125 MB RGBA8 per character with all clips; S3TC cuts it 4x (1.2% mean error, load 1.2 ms vs 19.6 ms). Residency rule: keep the player (idle walk run interact talk hit celebrate jump fall land), nearby NPCs (idle walk/hover talk) and current enemies resident; `warm_clips()` behind the fade; unload on area exit. Re-baking at 192 px cells (the figure is ~170x190 of 256) is a **deferred optimisation** (R5), not in this plan.

### 6.3 Producing every MISSING asset by extending the verified generator (fills gaps of decision 6)

All of it is the same procedural pipeline the pack came from: `geometry.py` (Model with ellipsoid/tube/pillow/group primitives, eyes/cheeks/arms/feet/bezier helpers, PALETTES) + `additions.py` builders + `build_assets.py` (rig, skin weights, painted UV textures, glTF clips, GLB) -> `bake_sprite_atlases.py` (VTK, 36 degrees, three lights, warm outline). The art spike extended it (hooks `TT_BUILDERS`, `EXTRA_CLIPS`, `m.slug`, `m.base_height`, `--clips`, `--outline`, bust camera) and produced everything below; the lead's venv is `/Users/magnusudbjorg/Documents/projects/PongPong_lift/artenv/bin/python` (Python 3.12 + numpy scipy Pillow vtk).

```
tools/art/setup_env.sh                                 # P08, ~2 min: tools/art/.venv
export PY=$PWD/tools/art/.venv/bin/python
tools/art/produce_all.sh tools/art/_stage                 # EVERYTHING: 2 min 33 s wall (5 min 11 s CPU, 5 parallel bakes), 447 files, 55 MB
tools/art/produce_all.sh --only=characters hobbit_pip  # one character: ~1 s build + 3-14 s bake (clip set dependent)
tools/art/produce_all.sh --only=tiles | props | icons | keyart
$PY tools/art/core/validate_new_assets.py tools/art/_stage/isometric_characters/<id>   # mandatory after every bake
$PY tools/art/core/cast_sheet.py ...                    # contact sheets
tools/import/write_import_stubs.py                     # BEFORE the first godot --import (R.7); `--check` audits
```
**Generator ownership:** `tools/art/core` + `export` + `produce_all.sh` + env = P08; `tools/art/characters` = P21; `tools/art/environment` = P22; `tools/art/icons` = P23 (a package edits its builder files only; shared renderer fixes go through P08's owner).

| Missing asset | Count | Generator slice | Wall time | Owner | Output | Verified by |
|---|---|---|---|---|---|---|
| Hobbit (3 skins: Pip green, Moss mustard, Bramble purple; curls, hairy feet) | 3 | `characters` | ~10-14 s each | P21 | `assets/isometric_characters/hobbit_*` | contact sheet idle/walk/run/talk/interact/hit/celebrate/jump rows S and SE; cast screenshot next to pack |
| Squirrel (Egern) | 1 | `characters` | ~12 s | P21 | `.../squirrel` | same |
| Fairy skins Stardust, Dusk (+15 clips incl. flight) | 2 | `characters` | ~14 s each | P21 | `.../fairy_stardust`, `fairy_dusk` | flight rows |
| Named NPC fairies: Hyldeblomst (mayor, spectacles), Rosmarin (chef hat), Kløvermynte (shopkeeper), Fekongen (crown, beard), Zephyr (wizard hat), Lily | 6 | `characters` (npc_flyer set) | ~4 s each | P21 | `.../fairy_mayor, fairy_baker, fairy_shopkeeper, fairy_king, fairy_wizard, fairy_lily` | portrait legibility at 96-150 px |
| Pippin Bøgeknop (mouse), Morfar Mis (grey cat), villagers Oak (bear), Rosa (rabbit), Thorin (raccoon), postman (penguin) | 6 | `characters` (villager set) | ~4 s each | P21 | `.../mouse_pippin, cat_morfar_mis, bear_guard, rabbit_farmer, raccoon_smith, penguin_postman` | accessory visibility (scarf/apron/strap must sit outside the body surface) |
| Farm animals: chick, hen, duck, kitten, bunny, fox_cub, lamb, calf, owl, puppy, fawn (covers every `baby_*` item) | 11 | `characters` (farm_animal set; quadrupeds use the capybara-style rig with Foot_/HindFoot_ groups) | ~4 s each | P21 | `.../chick ... fawn` | contact sheet at game scale |
| Forest creatures: Snurresvampen (boss, 2.1 m, spin+attack), Tornebusk, Ugleøje, Lysesvamp (halo baked) | 4 | `characters` (boss/enemy/critter sets) | ~5-8 s each | P21 | `.../snurresvamp, tornebusk, ugleoje, lysesvamp` | spin frames from all sides |
| Pack busts | 12 | `characters` bust camera | ~2 s each | P21 | `assets/portraits/<id>.webp` | portrait sheet |
| Iso terrain (17 atlases) | 17 | `tiles` | ~21 s | P22 | `assets/iso_tiles/` | seamless mixes; Godot render, no hairline seams |
| **Ortho terrain + walls (new mode)** | 7 + ~8 | `tiles` ortho (camera az 0, rectangular mask, 96x56) | ~25 s | P22 | `assets/iso_tiles/ortho_*`, `assets/iso_props/forest_wall_*` | forest screenshot; fallback = iso maps |
| Props (55 verified + ~25 new: Hyggebyen buildings, signs, well, fountain, warp gate, coop, barn, apple tree, crops x3 new, paw prints, roof patch ...) | ~80 | `props` | ~13 s + ~15 s | P22 | `assets/iso_props/` | prop sheet + y-sort probe |
| Crops 4 stages x 7 crops | 28 | `props` | included | P22 | `crop_<id>_<0..3>` | farm screenshot |
| Backdrops | 6 | Pillow script | seconds | P22 | `assets/backdrops/` | screenshot |
| Item icons | ~75 (60 verified + new) | `icons` | ~9 s | P23 | `assets/icons/items/` | icon sheet + `missing_icons.py` (fails when a Lua item has no icon) |
| Title key art | 1 (+layers) | Pillow composite of baked layers | minutes | P23 | `assets/ui/keyart/` | screenshot, target 8/10 |
| App icon | 1 | SVG | - | P23 | `icon.svg` | - |

### 6.4 How the team verifies looks (every art package, before it is accepted)

1. Validator green (`validate_new_assets.py`: sheet size = frames x 256 by 2048, no blank frames, no opaque pixels on the cell border).
2. **Contact sheets**, never a single frame: the new cast at game scale next to the pack's bat, cat, bear, rabbit (the four sketch-derived characters), fox and fairy. Pass if figure height is within +/-10% of the pack, outline and eye style match, the face grammar of the sketches holds (two big round eyes with one dark pupil, 3 whisker strokes per cheek, tiny mouth, big round head on a small pear body, stubby arms, small feet).
3. Godot screenshots with `tests/shot_world.tscn` (the user runs them; ~1 s window each) at Camera zoom 0.4 / 1280x720: `--part=cast` (pack + new characters on farm tiles), `--part=farm|hyggebyen|forest|fixtures`, `tests/shot_sort.tscn` (walk around house and trees), night grade readable.
4. Animation check: walk/run/talk/hit rows S and SE for hobbit, squirrel, fairy NPCs; boss spin from every side; fairy hover glide.
5. A human looks at 2-4 and writes the verdict into `tools/art/README.md` ("accepted at <date>, known weaknesses ...").

### 6.5 Quality bar and where the result is weaker than the originals (honest)

The look is **soft 3D-rendered sprites in the pack's style, not hand-painted brushwork**. Only the periodic ground tiles carry a painted feel. Art-spike self-assessment, which I agree with after viewing the renders: characters/NPCs/animals 8/10 (same family as the pack; weak spots: hobbit feet at game scale, Pippin's strap reads as a stick), icons 8/10 (brush, lantern, owl feather, hoe weaker), props/tiles/crops 7/10 (blob-texture trees look CG at 1:1; platform edge plain), Hyggebyen 6.5/10 (cramped layout, flat blossom trees), Mørkeskoven 6.5/10 (needs the engine lights; no baked darkness; outline disappears on navy unless the pack outline is used), title key art 6/10 (flat foliage mass). The pack's four characters follow the user's own sketches; hobbit, squirrel, NPCs and creatures are **our** designs from the guide text, so the user may want to supply sketches. Gaps accepted: no terrain transition tiles (hard cuts hidden by props), no seasonal tile sets, no emissive eye layers (Ugleøje, Tornebusk), single portrait expression, hovering fairies have no walk cycle, water is a 4-frame swap. Optional later pass to push towards "hand-painted": brush-stroke displacement + paper-grain overlay at bake time (not planned, not tested).



## 7. Work packages

27 packages, 7 waves. **File ownership is strictly disjoint** (checked mechanically, see 0.1). A package owns files it creates, edits or **deletes**; nobody else touches them. Where two packages need the same file the plan already split it (for example `localization/da.csv` is frozen until P26; every package owns its own `localization/<name>.csv`; every package owns its own `tests/sections/<name>.gd` so nobody edits the harness; `lua/config/props.lua` is P04 and `props_extra.lua` is P22).

### 7.1 Wave overview and gates (re-layered by the review, R.2; every dependency points to a strictly earlier wave)

| Wave | Packages | Purpose | Exit gate (run by the wave reviewer) |
|---|---|---|---|
| **1** bootstrap | P01 project-config, P08 art-tools, P09 test-harness | project settings + input map + ignore rules; art pipeline base; test harness incl. windowed mode | boots clean on the new `project.godot` (legacy 3D scenes still load); harness `--list` + negative test; fox rebuilt from source; `tools/dev/test_in_copy.sh` seeds a clone copy |
| **2** contracts | P02 bus-gamemanager-time, P03 loc-core, P05 characters-pack, P10 data-contracts (+ LuaRuntime) | EventBus/GameManager/TimeManager, runtime localization, the 12-character pack + sprite script + import stubs, Lua data + hardened runtime | core, loc, characters, data sections green; pack imports as S3TC from stubs; loc_check runs on a fresh clone |
| **3** framework + services | P04 area-framework, P07 ui-foundation, P12 economy-shop-crafting, P15 save-system, P21 art-characters | world framework with player stub, UI foundation, economy/shops/crafting, SaveManager, generated cast | farm map loads headless on the player stub; windowed render probe; foundation smoke; economy + save sections; art validators + cast sheet |
| **4** gameplay core, screens, art | P06 player-farm-core, P11 maps-iso, P13 quests, P16 ui-menus, P18 ui-shop-inventory, P22 art-environment, P23 art-icons-keyart | the first playable farm loop, quests, menus, shop/backpack, real environment art + ortho decision, icons + key art | **first full boot menu -> select -> farm for animal, fairy, hobbit**; till/plant/water/4 days/harvest; farm HUD placeholder; quests completable by events; ORTHO_DECISION.md |
| **5** content | P14 npc-dialogue, P17 ui-hud, P19 forest-combat, P20 animals-buildings | NPCs/dialogue/Opgavebog, farm HUD, Mørkeskoven, animals/buildings | Lua quest completed from dialogue alone; forest fight; animals loop; all guide screens render without raw keys |
| **6** finish | P24 audio-voice, P25 docs-refresh, P26 loc-final | voice (recorded + TTS), docs, strict localization | `loc_check --strict` green; every dialogue line has a voice file; howto example test green |
| **7** acceptance | P27 qa-acceptance | prove acceptance items 1-13 for 3 characters, windowed suite, QA report | QA report |

Package order inside a wave is free (no package depends on another of the same wave). Code references to scripts of later waves (`npc_2d.gd`, `enemy_2d.gd`, `game_ui` children) are resolved lazily so a missing script is skipped, never an error; cross-package checks whose subject lands later report `SKIP` until it exists and are strict in P27. The Godot editor must not be open on the repo while a wave runs.

### 7.2 Working rules for every package

1. Re-read each file immediately before editing; the tree is shared and other tools write to it. 2. Test against the current shared tree with `tools/dev/test_in_copy.sh <pkg>` (APFS-clone copy seeded WITH the canonical `.godot`, deleted afterwards - a full S3TC cache is ~1.2 GB, R.7; never run `--import` concurrently in the real directory; run `--import` after adding a `class_name` script - the global class cache is not updated otherwise). 3. Scripts use autoloads only through `get_node("/root/Name")` in `-s` drivers (autoloads are not compile-time resolvable there); do NOT use `--check-only` on single scripts. 4. Never run Godot non-headless except the documented windowed drivers (`--windowed`, R.6), and only when the lead/user has allowed it for this wave. 5. Add `.uid`/`.import` files together with their base file; delete them with it. 6. Danish and English text only in CSV files. 7. Every package ends with its section test green and its screenshots opened and looked at; **a task is not done until the named check of the package's final VERIFY task covers it and passes**; failures that belong to another package are filed against that package id, not patched.

### 7.3 Packages (generated from the ownership data; "lift" paths are under the scratchpad / repo as noted in 0.1)

##### Wave 1

#### P01-project-config - Project settings, input map, layers, ignore rules, repo hygiene

*Wave 1 - size S - depends on: none*

**Owns (exclusive):** `project.godot`, `.gitignore`, `.gitattributes`, `docs/.gdignore`, `docs/design/**`, `assets/models/**`, `assets/textures/**`, `docs/.DS_Store`, `.DS_Store`, `tests/tools/**`

**Lift from:** SW/project.godot (2d layer names, input actions, user dir); SU/project.godot (viewport 1280x720, theme, no msaa_2d)

**Tasks**

1. Rewrite project.godot exactly per PLAN section 3.1: config/name="Trætoppen", description, features ("4.7","GL Compatibility"), use_custom_user_dir=true + custom_user_dir_name="Traetoppen", viewport 1280x720 with stretch canvas_items + aspect expand, renderer gl_compatibility (desktop and mobile), default_texture_filter=2 (= Linear Mipmap; the project-setting enum is 0 Nearest, 1 Linear, 2 Linear Mipmap, 3 Nearest Mipmap - verified in Godot 4.7.2; 3 is WRONG, review R.1), textures/vram_compression/import_s3tc_bptc=true, [importer_defaults] texture mipmaps/generate=true, 2d_physics layer names 1-11 (section 3.3), delete all 3d_physics names, msaa_3d and the [animation] 3D key, autoload block unchanged in order (EventBus, GameManager, LocalizationManager, SaveManager, EconomyManager, QuestManager, LuaRuntime, TimeManager, AudioManager, ShopSystem, AnimalHusbandry), internationalization locale/fallback="en" and NO locale/translations list (translations are loaded at runtime by LocalizationManager, section 3.4). gui/theme/custom stays res://assets/ui/theme.tres. Do NOT add window_width_override/height_override (screenshot-only in the UI spike).
2. Input map: write every action of section 3.2 (move_*, interact, jump, run, fly_toggle, fly_descend, dodge, light, drink, slot_1..slot_10, use_tool, attack, inventory (I and Tab, NOT F10), journal, pause, build_menu, zoom_in, zoom_out) with keyboard/mouse events and joypad events (A=interact/jump, X=attack/use_tool, B=dodge, Y=light, RB=drink, Start=pause, left stick = move). `ui_*` actions stay Godot defaults.
3. Rewrite .gitignore: keep .godot/ and OS/IDE entries; REMOVE only the *.import rule (import files and .uid files are committed so a fresh clone works) and KEEP ignoring *.translation (the runtime CSV loader does not use them; the csv importer would otherwise commit ~28 junk binaries, review R.4); add .mimocode/, .playwright-mcp/, __pycache__/, tools/art/.venv/, tools/art/_stage/, /scratch/. Add .gitattributes marking *.webp *.png *.ogg *.ttf *.jpg as binary (add commented Git LFS lines for assets/**/*.webp; decision left to the user because the repo has no commits yet).
4. Add docs/.gdignore so docs/ (style-guide JPGs, user MP3s, nested pack project) is never imported; delete the stale Godot-generated .import files under docs/audio/ and docs/Trætoppen Style Guide Review/ (other docs/ .import files belong to P05/P24 and are removed with their directories).
5. Copy this PLAN.md to docs/design/PLAN_2D.md (read-only reference for every later package; a contract change is announced in the commit/PR message of the package that makes it and re-published by editing PLAN_2D.md only through P01's owner at the next wave boundary).
6. VERIFY: `godot --headless --path . --import` twice (first run prints font errors once - expected, second run must be silent), then `godot --headless --path . --quit-after 30` prints ZERO errors and ZERO warnings; `godot --headless --path . -s res://tests/tools/print_inputmap.gd` (written here, review R.11); headless check `p01.texture_filter_is_2` lists every action in section 3.2.
7. REVIEW: removing locale/translations means NO translations load between P01 (wave 1) and P03 (wave 2) - raw keys everywhere in the legacy UI; acceptable because no UI test runs in that window. REVIEW R.1/R.11: write tests/tools/print_inputmap.gd (lists every action and its events) and tests/tools/check_project.gd (asserts texture filter == 2, viewport 1280x720, renderer gl_compatibility, no locale/translations list, all 2d layer names). Delete docs/audio/*.import and docs/Trætoppen Style Guide Review/**/*.import (create docs/.gdignore FIRST so they are not regenerated). Copy PLAN.reviewed.md (not PLAN.md) to docs/design/PLAN_2D.md. -> verify: both scripts exit 0 on the boot tree

**Gate:** Legacy tree boots with no errors on the new project.godot (the 3D scenes still load); InputMap complete; check_project.gd green; fresh-clone check (rsync repo without .godot to scratch, import twice, boot) is clean.

#### P08-art-tools - Art pipeline core: Python env bootstrap, shared bakers, validators, exporter, produce_all

*Wave 1 - size M - depends on: none*

**Owns (exclusive):** `tools/art/README.md`, `tools/art/setup_env.sh`, `tools/art/core/**`, `tools/art/export/**`, `tools/art/produce_all.sh`, `tools/art/generator/**`, `tools/art/.gdignore`

**Lift from:** /Users/magnusudbjorg/Documents/projects/PongPong_lift/artenv (verified Python 3.12 venv: numpy scipy Pillow vtk); SA/tools/isometric/{static_render,scene,bake_sprite_atlases,validate_new_assets,contact_sheet,cast_sheet,preview,export_game_assets,produce_all.sh}; SA/patches/*.diff; /Users/magnusudbjorg/Documents/projects/PongPong_lift/pongsrc (source package copy: tools/ + assets/characters/*.glb)

**Tasks**

1. tools/art/setup_env.sh: creates tools/art/.venv (gitignored) with `python3.12 -m venv`, installs numpy scipy Pillow vtk (versions pinned from /Users/magnusudbjorg/Documents/projects/PongPong_lift/artenv `pip freeze`), prints the interpreter; works on Apple Silicon macOS (verified by the lead).
2. tools/art/core/: copy static_render.py (VTK static renderer, camera 36 degrees elevation, 87.074 px/m, warm outline (75,60,73) alpha .55, glow_halo, soft_shadow), scene.py, bake_sprite_atlases.py (hooked version with CLIP_SETS, attack/spin clips, bust portraits, --clips, --outline), validate_new_assets.py (sheet size, blank frames, border-opaque), contact_sheet.py, cast_sheet.py, preview.py. All paths relative to tools/art so `PYTHONPATH=tools/art` works; the pristine generator base (geometry.py, additions.py, build_assets.py with the optional hooks TT_BUILDERS/EXTRA_PATTERNS/EXTRA_CLIPS, asset_io.py, render_assets.py, validate_assets.py) is copied to tools/art/generator/ (review R.8: P08's own gate needs it); the 25 MB GLBs are NOT copied (regenerated in ~1 s each).
3. tools/art/export/export_game_assets.py + produce_all.sh: stage outputs into the gitignored tools/art/_stage/ tree (NOT export/: Godot would import that folder; tools/art/.gdignore hides all of tools/art) and then copy them to the contract paths of section 6.2 ONLY (assets/isometric_characters/<new ids>/, assets/iso_tiles/, assets/iso_props/, assets/icons/items/, assets/ui/keyart/); WebP method 4 q97 for sprites, lossless for icons; never writes outside those directories and never touches the 12 pack characters. `produce_all.sh --only=characters|tiles|props|icons|keyart [ids...]` so each art package runs its own slice.
4. tools/art/README.md: the art contract (camera, px/m, cell 256, pivot (128,200), 8 direction rows S SW W NW N NE E SE, clip names/fps, clip sets per role, tile/prop/icon contract, outline rule: world sprites use the pack outline (75,60,73), ink #2b2340 only on icons/UI), quality bar of section 6.5, the mandatory validators, and the lessons: Python module names ASCII only, scale = height-independent via m.base_height, reset camera every frame, premultiplied resize, zsh does not word-split variables, pgrep -f matches itself.
5. VERIFY: from a clean checkout `tools/art/setup_env.sh && tools/art/core/smoke.sh` bakes the fox idle sheet from the GLB generator in < 30 s and `validate_new_assets.py` passes; contact sheet next to the pack fox is visually identical (screenshot compare).
6. REVIEW R.7/R.8: the exporter writes the S3TC import stub (tools/import/write_import_stubs.py from P05, or an equivalent inline writer if P05 has not landed) next to every character clip sheet it copies; tools/art/.gdignore is created first. -> verify: export writes <clip>.webp.import with compress/mode=2

**Gate:** Fox rebuilt end-to-end from tools/art/generator + tools/art/core and identical to the pack within 1% mean error; staging never lands inside a Godot-scanned folder.

#### P09-test-harness - Headless playtest harness (rewritten for 2D), section plug-ins, windowed mode, clone-based dev runner

*Wave 1 - size M - depends on: none*

**Owns (exclusive):** `tests/playtest.gd`, `tests/run_playtest.sh`, `tests/.gitkeep`, `tests/lib/**`, `tools/dev/**`

**Lift from:** SW/tests/playtest_world.gd (782 lines, 100 checks) -> harness + sections; existing tests/playtest.gd (Logger capture) and run_playtest.sh

**Tasks**

1. tests/playtest.gd = harness only: Logger capture of engine/script errors (errors AND warnings fail), boot via the REAL main_menu.tscn -> character_select.tscn -> world.tscn for --character=animal|fairy|hobbit, helpers in tests/lib (assert/expect, frames/seconds, press unique node, tap action with InputEventAction pairs, await physics_frame for physics-driven asserts, autoload access by root.get_node, never statically reference autoload names). It auto-discovers res://tests/sections/*.gd (each: `const SECTION := "farm"` + `func run(t) -> void`), runs them in alphabetical order, supports `--only=a,b` and `--list`. Sections are owned by the package they test, so no package edits the harness.
2. tests/run_playtest.sh: keeps the CLI of the lead's script (`--character=`, `--only=`), plus: runs `godot --headless --path . --import --quit` once if .godot is missing or any .gd newer than global_script_class_cache.cfg (class_name pitfall), calls tools/import/write_import_stubs.py --check when assets changed (no re-import pass), exit code != 0 on any failed check/engine error.
3. tools/dev/test_in_copy.sh: seed $SCRATCH/copy-<pkg>/ with an APFS CLONE of the canonical repo INCLUDING .godot (`cp -Rc`, the import cache is path-relative and md5-keyed so it stays valid), rsync only the changes (excluding docs, tools/art/_stage, .git), and DELETE the copy afterwards (only the three art packages keep theirs); a copy with its own full S3TC cache is ~1.2 GB and a 5-minute first import (review R.7) and run the harness there - the way parallel package builders verify against the CURRENT shared tree without racing on the real directory's .godot cache.
4. Windowed mode (review R.6): sections may define `func run_windowed(t)`; `tests/run_playtest.sh --windowed [--only=...]` runs only those with a real window (`--resolution 1280x720`, ~1 s per check, automated pixel assertions + PNGs into `--out=DIR`) and `tools/dev/run_windowed.sh` wraps it (run by the lead/user at wave boundaries; agents never open windows on their own). tests/lib/print_inputmap.gd is NOT here any more (P01 owns tests/tools/). The screenshot drivers (shot_*) moved to P04 and perf_world to P05.
5. VERIFY: `tests/run_playtest.sh --list` shows sections; the harness runs the legacy flow (menu -> select -> legacy world) and reports its known failures instead of crashing; a trivial `run_windowed` section opens and closes a window; an injected engine error makes the run exit non-zero (negative test). The 3-character full-boot gate belongs to the wave-4 reviewer (needs P04+P06).

**Gate:** Harness lists/runs sections, negative test fails as designed, windowed mode works; clone-based test_in_copy.sh seeds a copy in < 1 min.

##### Wave 2

#### P02-bus-gamemanager-time - EventBus, GameManager (phases, modal stack, new game), TimeManager (calendar, weather)

*Wave 2 - size M - depends on: P01, P09*

**Owns (exclusive):** `scripts/autoload/event_bus.gd`, `scripts/autoload/game_manager.gd`, `scripts/autoload/time_manager.gd`, `tests/sections/core.gd`

**Lift from:** SW/scripts/autoload/event_bus.gd (2D signals); audit reports: core autoloads, save, quest, economy (reset hooks)

**Tasks**

1. EventBus: apply section 3.5 exactly: player_spawned(player: Node2D); NEW signals new_game_started, zone_unlocked, item_gained, building_built, animal_adopted, animal_fed, animal_product_collected, area_change_requested, area_changed, player_health_changed, player_oil_changed, hotbar_changed(entries: Array, selected: int), boss_bar_changed, whisper_requested, interaction_prompt_changed, weather_changed, recipe_crafted, enemy_defeated, player_defeated, modal_changed. Keep all existing signals (arity unchanged) so untouched autoloads still connect.
2. GameManager: add the modal-stack API of section 3.6: push_modal(name, pauses_tree := true), pop_modal(name), is_modal_open(name := &""), phase derived (PAUSED if any pausing modal, CUTSCENE if only non-pausing modals, else PLAYING) while change_phase() remains for MENU/CHARACTER_SELECT/PLAYING at scene boundaries; emit EventBus.modal_changed; mouse stays visible always (the 2D game never captures it) so remove every Input.mouse_mode write. Phase PAUSED/CUTSCENE must also be restored correctly when pop order differs from push order.
3. GameManager.start_new_game(p_name, p_type, p_farm, p_skin): sets character_skin directly (default per type if empty), resets its own state and sets world flag intro_pending=true (read by WorldRoot2D/IntroSequence), then emits EventBus.new_game_started() LAST so Economy/Quest/Time/Shop/Husbandry/Save/FarmGrid reset themselves; also emits player_character_changed AFTER the skin is final. from_dict() must NOT set phase PLAYING and must emit player_character_changed. unlock_zone() emits zone_unlocked ONLY (never zone_entered) and posts the unlock toast with tr("ZONE_%s").
4. GameManager.advance_time(): loop while hour >= day_end_hour (26) so multi-day skips are exact (each roll restarts the clock at 02:00 of the new date); end_day() emits day_ended then day_started; add GameManager.total_day() (days played, shown as "Dag N" on the title) and a sleep helper used by WorldRoot2D; single source of truth for DAYS_PER_SEASON(28)/SEASONS/hours read from LuaRuntime.get_config("time.*") with the current literals as defaults.
5. TimeManager: calendar helpers for section 3.9: weekday_index(day) = (day-1)%7 (Mandag = day 1 of every season), weekday_name(), season_month_name(), date_text() -> "Tirsdag 16. Blomstermåned" using tr("UI_WEEKDAY_n") / tr("UI_MONTH_<SEASON>") (keys live in localization/ui.csv, P07); weather ids klart/regn/taage/sne/torden with weather_name() -> tr("UI_WEATHER_*"), emit weather_changed; is_raining(); pause_time()/resume_time() (idempotent); reset() on new_game_started; keep rolling weather once per day BEFORE other day_started listeners (autoload order).
6. tests/sections/core.gd: asserts (a) push_modal x2 / pop x2 keeps paused until the last pop, (b) start_new_game after dirty state resets gold/inventory/quests/flags (wired by P12/P13/P15 - assert via signal count here), (c) date_text for day 16 foraar == "Tirsdag 16. Blomstermåned" in da and "Tuesday 16. Month of Blooms" in en, (d) unlock_zone emits zone_unlocked once and zone_entered zero times, (e) advance_time(25h) from 06:00 lands on next-day 07:00.
7. REVIEW R.13: add `hotbar_assign_requested(slot: int, item_id: StringName)` and the generic `game_event(name: StringName, payload: Dictionary)` to EventBus. core.calendar_names uses an INJECTED temporary Translation (UI_WEEKDAY_n, UI_MONTH_*) because the real keys live in ui.csv (P07) and the loader (P03) is the same wave; the real da/en text is asserted by hud.date_text_real_keys (P17). Expose `time.first_weekday` (game_balance, default 0 = Monday) in weekday_index. -> verify: core.calendar_names, signal arity lint

**Gate:** tests/run_playtest.sh --only=core passes (legacy 3D world may still be present and is not part of the gate); no engine errors.

#### P03-loc-core - Runtime CSV localization (no import step), locale persistence, lint, core.csv overrides

*Wave 2 - size M - depends on: P01, P09*

**Owns (exclusive):** `scripts/autoload/localization_manager.gd`, `localization/core.csv`, `localization/en.csv`, `localization/*.translation`, `tests/loc_check.gd`, `tests/sections/loc.gd`, `tools/loc/**`

**Lift from:** /Users/magnusudbjorg/Documents/projects/PongPong_lift/loc_verify/drv.gd (verified loader prototype); /Users/magnusudbjorg/Documents/projects/PongPong_lift/loc/ (key extraction drivers: extract.py analyze.py needed.py runtime_keys.gd); SU/localization/ui.csv (86 rows, owned by P07)

**Tasks**

1. Implement the runtime loader of section 3.4 in LocalizationManager._ready (autoload runs before any scene): scan res://localization/*.csv, order = da.csv first (legacy base), then every other *.csv alphabetically; parse with FileAccess.get_csv_line; header `keys,da,en`; skip blank rows and rows starting with ; or #; build ONE Translation per locale and TranslationServer.add_translation; later files override earlier keys (override of a legacy da.csv key is allowed and silent; the same key twice in the same non-legacy file, or in two non-legacy files, is a LINT ERROR returned by LocalizationManager.lint()). A key must match ^[A-Z0-9_]+$ - malformed rows (the colon rows in da.csv) are skipped and reported by lint() (tolerated while da.csv is legacy, fatal under `tests/loc_check.gd --strict`, which P26 runs at the end).
2. API: set_locale(locale, announce := true) (no toast at boot), signal locale_changed(locale), persist the choice in user://settings.cfg section [game] locale (shared file with SettingsUI/P16; use ConfigFile load-modify-save, never overwrite other sections), boot with the saved locale or "da"; t(key, args := []) that never applies % to an untranslated key (returns the key); has_key(key); all_keys() for the lint tool. Fix the NOTIF_LANGUAGE_CHANGED message to take the language name (keys LANG_DA/LANG_EN live in core.csv).
3. localization/core.csv (owned here, overrides legacy rows without touching da.csv): GAME_TITLE=Trætoppen, GAME_SUBTITLE="En gård i Fekongens skov"/"A farm in the Fairy King's forest", UI_GOLD="guldagern" (UI_CURRENCY lives in ui.csv, review R.4), UI_WEATHER_KLART="Solskin", CHAR_SELECT_TITLE="Hvem er du?", CHAR_ANIMAL_NAME="Skovdyr", UI_JOURNAL="Opgavebog", UI_INVENTORY="Rygsæk", NOTIF_QUEST_ACCEPTED_TITLE/NOTIF_QUEST_COMPLETED_TITLE (the real legacy key names) -> "Ny opgave!"/"Opgave fuldført!", the canonical NPC display names of section 3.8 (NPC_MAYOR_LYRA="Borgmester Hyldeblomst", NPC_BAKER_MAJA="Bagerfe Rosmarin", NPC_MERCHANT_PIP="Butiksfe Kløvermynte", NPC_FAIRY_LILY, NPC_SMITH_THORIN, NPC_GUARD_OAK, NPC_FARMER_ROSA, NPC_FAIRY_WIZARD, NPC_PIPPIN_BOEGEKNOP, NPC_FAIRY_KING="Fekongen", NPC_CAT_MORFAR_MIS="Morfar Mis") in da AND en, ZONE_* area titles (ZONE_FARM=Trætoppen, ZONE_CITY=Hyggebyen, ZONE_DARK_FOREST=Mørkeskoven, ZONE_FOREST_EDGE=Skovkanten, ZONE_DYBE_BREGNER=Dybe Bregner, ZONE_MUSHROOM_GROVE=Svampelunden, ZONE_CRYSTAL_CAVE=Krystalgrotten), LANG_DA/LANG_EN. core.csv contains ONLY the key families of the R.4 ownership table (no ITEM_*, OBJ_*, QUEST_*, RECIPE_*, SHOP_*: P12/P13/P20 define those in their own files; the legacy malformed colon rows are harmless until P26 prunes them).
4. tests/loc_check.gd (SceneTree script, runnable `godot --headless --path . -s res://tests/loc_check.gd [-- --strict]`): scans scripts/**/*.gd, scenes/**/*.tscn, lua/**/*.lua for literal keys (tr("KEY"), name_key, description_key, text_key, speaker_name_key, info_key, theme_type text = KEY, text = "KEY") and expands the dynamic patterns (ITEM_<id> for every Lua item/shop/product/loot id, ITEM_<id>_DESC, OBJ_<QUEST>_<OBJ> then OBJ_<OBJ>, QUEST_<id>_TITLE/_OFFER, ZONE_<id>, SHOP_<id>, NPC_<id>, BUILDING_<id>, UI_MONTH_*, UI_WEEKDAY_*, UI_WEATHER_*), then asserts tr(k) != k in da AND en. Non-strict mode prints the misses and exits 0 until wave 3; --strict exits 1 on any miss, any malformed row, any duplicate. Base it on the audit prototype /Users/magnusudbjorg/Documents/projects/PongPong_lift/loc/runtime_keys.gd + extract.py.
5. tools/loc/: `csv_lint.py` (same rules offline), `prune_legacy.py` (lists/removes keys in da.csv that are overridden by another file or referenced nowhere; used by P26 only).
6. tests/sections/loc.gd: switch da<->en at runtime with a Label whose text is a key (atr() flips), boot-time no toast, locale persisted in settings.cfg, loader finds >= 480 keys, lint() returns no duplicate errors for non-legacy files.
7. REVIEW R.4: every localization/*.csv ships with a committed <name>.csv.import containing `[remap] importer="keep"` (verified: otherwise `--import` writes <name>.da/.en.translation junk and exports drop the raw CSV). tools/loc/new_csv.py creates a CSV + keep-import; csv_lint.py and LocalizationManager.lint() fail when a CSV lacks the keep-import. Add the key-ownership table (R.4) to lint: a key may live in only one non-legacy file, EXCEPT zz_final.csv which may override any non-voiced key. LocalizationManager keeps `play_voice/voice_*` only as a thin forwarder to AudioManager.play_voice(key) (no double prefix, no second volume state). -> verify: loc.csv_keep_imports, loc.ownership_lint

**Gate:** `-s res://tests/loc_check.gd` runs on a fresh clone without any --import of CSVs (and the import creates no .translation files); da/en switch verified headless.

#### P05-characters-pack - Integrate the 12-character pack: assets, generic chibi scene, merged sprite script, skin->visual data, import stubs

*Wave 2 - size M - depends on: P01, P09*

**Owns (exclusive):** `assets/isometric_characters/bat/**`, `assets/isometric_characters/cat/**`, `assets/isometric_characters/bear/**`, `assets/isometric_characters/rabbit/**`, `assets/isometric_characters/fairy/**`, `assets/isometric_characters/monkey/**`, `assets/isometric_characters/capybara/**`, `assets/isometric_characters/fox/**`, `assets/isometric_characters/raccoon/**`, `assets/isometric_characters/penguin/**`, `assets/isometric_characters/hedgehog/**`, `assets/isometric_characters/frog/**`, `assets/isometric_characters/shadow.png`, `assets/isometric_characters/manifest.json`, `scenes/isometric/chibi.tscn`, `scripts/isometric/**`, `lua/config/characters.lua`, `tools/import/**`, `docs/art/isometric_pack/**`, `docs/PongPong_Isometric2D/**`, `tests/sections/characters.gd`, `tests/perf_world.*`

**Lift from:** PACK (repo docs/PongPong_Isometric2D): assets/isometric_characters/**, scripts/isometric/iso_chibi_sprite_2d.gd; SW/scripts/isometric/iso_chibi_sprite_2d.gd (gameplay patch); SA/patches/iso_chibi_sprite_2d.diff (open character ids); SW/tests/perf_world.*

**Tasks**

1. Copy PACK/assets/isometric_characters/** (12 characters + shadow.png + manifest.json, 25 MB) into the repo under the same res:// paths; copy PACK/docs/ISOMETRIC_2D_README.md, README.md and docs/isometric_previews/*.png to docs/art/isometric_pack/; then DELETE the whole standalone project docs/PongPong_Isometric2D (nested project.godot, demo scenes, demo scripts isometric_demo/ground, IsoPlayerController2D, IsoWanderer2D, player_2d/npc_2d/demo scenes, validate_isometric.py). The pack's own README claim 'Godot was never run' is obsolete (lead verified it runs) - say so in the moved README header.
2. scripts/isometric/iso_chibi_sprite_2d.gd = the pack script MERGED with BOTH patches: (a) SW gameplay patch (update_motion facing_override, play_action(clip, rate), clip_duration, has_clip, is_action_playing, cancel_action, set_spin, flash, get_portrait, preload_clips, awaitable warm_clips (finalise ONE sheet per frame), shadow z_as_relative=false z_index=-5) and (b) SA patch: character_id becomes a plain String and load_character accepts any id whose res://assets/isometric_characters/<id>/animations.json exists (CHARACTER_IDS/@export_enum removed), plus: a static factory `IsoChibiSprite2D.create(id) -> IsoChibiSprite2D` that instantiates scenes/isometric/chibi.tscn and calls load_character, `display_scale` and `glow` read from animations.json, a missing-id fallback chain from lua/config/characters.lua (so hobbit_pip falls back to raccoon until P21 lands), and the Sprite2D texture_filter set explicitly to 4 (LINEAR_WITH_MIPMAPS) instead of the pack's explicit 2 (review R.1; CanvasItem enum, not the project-setting enum).
3. scenes/isometric/chibi.tscn: ONE generic scene (Node2D + Shadow + Sprite) replacing the 12 per-character scenes (do not copy scenes/isometric/characters/*.tscn; all runtime code uses IsoChibiSprite2D.create). lua/config/characters.lua (data, section 3.8/6.1): skin -> visual id table for all skins (animal_fox=fox, animal_rabbit=rabbit, animal_hedgehog=hedgehog, animal_squirrel=squirrel, fairy_meadow=fairy, fairy_stardust=fairy_stardust, fairy_dusk=fairy_dusk, hobbit_pip/hobbit_moss/hobbit_bramble) each with fallback (squirrel->monkey, hobbit_*->raccoon, fairy_stardust/dusk->fairy), species list for the chips (Ræv fox, Kanin rabbit, Pindsvin hedgehog, Egern squirrel), perk key per race, farm-animal species -> baby/adult visual + scale, enemy visuals; `role` and clip sets live in each animations.json.
4. tools/import/write_import_stubs.py (review R.7): BEFORE the first import writes a minimal <clip>.webp.import stub next to every assets/isometric_characters/<id>/<clip>.webp (NOT portrait.webp, NOT shadow.png): `[remap] importer="texture" type="CompressedTexture2D"` + `[params] compress/mode=2 compress/high_quality=false mipmaps/generate=true process/fix_alpha_border=true` (verified honoured on the first import: only the .s3tc.ctex is produced, no stale lossless cache; 12 characters import in ~64 s). `--check` audits that every sheet has the preset. Used by P08's exporter and P21. tests/perf_world.* (100/200 animated characters, frame ms) are owned here.
5. VERIFY tests/sections/characters.gd: every id in lua/config/characters.lua resolves (real or fallback), all 8 direction rows x all clips of the 12 pack characters render a non-empty frame, create() works for fox and fairy, flight clips exist only for fairy and bat, warm_clips() finishes and costs < 8 ms per frame, memory report. Windowed screenshot tests/perf_world.tscn -- --cast (this package; shot_world.tscn belongs to P04 in a later wave) lines up the 12 characters at game zoom (look at it, compare with docs/art/isometric_pack/isometric_previews/character_lineup_2d.png).

**Gate:** Pack characters animate in a Godot scene with zero errors; every clip sheet imports as S3TC straight from the committed stubs; generic scene replaces per-character scenes; perf_world prints the 100/200-character frame times.

#### P10-data-contracts - Lua data contracts + LuaRuntime hardening: NPC roster, race perks and combat numbers, 2D game balance, parser/lint/kinds

*Wave 2 - size S - depends on: P01, P09*

**Owns (exclusive):** `lua/config/npcs.lua`, `lua/config/race_perks.lua`, `lua/config/game_balance.lua`, `tests/sections/data.gd`, `scripts/autoload/lua_runtime.gd`, `tools/lua/**`, `addons/lua_runtime/**`, `tests/fixtures/lua/**`

**Lift from:** SW/lua/config/race_perks.lua; current lua/config/game_balance.lua; PLAN section 3.8 roster; /Users/magnusudbjorg/Documents/projects/PongPong_lift/lua_audit (217-case diff vs real Lua 5.4, probes p01..p23)

**Tasks**

1. lua/config/npcs.lua: the canonical roster table (section 3.8): per NPC id -> {name_key, visual (art id), voice {pitch, rate}, home_area, role, shop_id, dialogue (file id), portrait override, wander {radius, speed}, facing, quests_offered[]}. Ids stay stable (mayor_lyra, baker_maja, merchant_pip, fairy_lily, smith_thorin, guard_oak, farmer_rosa, fairy_wizard) with NEW ids pippin_boegeknop, fairy_king, cat_morfar_mis and ambient villager penguin_postman; DISPLAY names come from core.csv. This file is read by npc_2d (P14), tt_portraits (P07), maps (P11), the voice generator (P24), the quest book (P14).
2. lua/config/race_perks.lua: lifted `race_perks` + `combat` tables from the spike with every distance/speed multiplied by 1/0.6 (swing_radius 197, dodge_distance 317, light_radius 550, knockback 433; table in section 3.13) and keys documented in comments; add per-race `species`/`skins` lists and the Fe `talks_to_flowers`, hobbit `bake_bonus` (+25% output chance in P12 crafting category bake), animal `harvest_bonus_chance`.
3. lua/config/game_balance.lua: convert the 3D units to ground px/s (player walk_speed 285, run_speed 450, accel 2500, decel 3300, hop impulse 620, gravity 1750, flight altitude 150, body ellipse rx 25, interaction_range 45, stamina 100, stamina_regen_per_second 12, run_cost_per_second 15 - the spike numbers x 1/0.6 because sprites are now unscaled, table in section 3.13), crops table complete for the 4 shipped crops with guide-aligned timing (carrot 4 stages x1 day = 4 days, pumpkin 5 stages x2 days = 10 days, turnip, moonflower with water_window) and glow_berry/strawberry/sunflower/catnip entries added by P12/P06 notes, economy.starting_gold 500 and sell_price_ratio, adventure.dark_forest_unlock_day=1 (open from the start; the warp keeps the gate code), ore_respawn_days, oil_empty_hurt_interval, time.* (read by P02), ui.dialogue_chars_per_second.
4. tests/sections/data.gd: every npc.visual/home_area/dialogue/shop exists (visual may be a fallback), every race has all perk keys, every crop in game_balance has an item with crop_id, numbers are positive.
5. REVIEW R.2 (moved here from P13, the plan's old P13 task 1 verbatim): keep the regex Lua-subset interpreter but harden it: anchor the function regex with (?m)^end so an empty/comment-only function no longer swallows the next one (intro_lottery.lua), replace bool(null) by Lua truthiness (only nil/false are false), arguments with ')' inside strings, api.get_flag, api.emit(name, payload) carries the payload, lua_notification passes title/message through tr(), unknown identifiers log once; fix the `rewards.items` hoist and empty `{}` -> Dictionary. Add the LOAD-TIME LINT (unsupported tokens: else, elseif, for, while, repeat, [[ ]], local function, function M., escaped quotes, #, string./math./table., arithmetic in statements -> LuaRuntime.lint_report, no engine warnings) and tools/lua/lint.gd. Generic loader for kinds config/items/quests/dialogue/recipes/shops: `_extract_named_table` currently extracts ONLY objectives/rewards/items/config/lines/choices/meta (verified: a kind="shops" file yields no `shops` key), so add `shops`, `recipes` and any top-level table named in a `tables` header; get_recipes(), get_shop(id), get_npc(id), reload_scripts() bound to F9 only when OS.is_debug_build(). Delete the empty addons/lua_runtime directory. Copy the 15 audit probes from /Users/magnusudbjorg/Documents/projects/PongPong_lift/lua_audit into tests/fixtures/lua/ (scratch paths are not test inputs) and assert them in tests/sections/data.gd. The plan's quest shapes (any_of arrays, nested friendship, have=false, after_others) were verified to parse. -> verify: data.lua_probes, data.lint_clean, data.kinds_shops_recipes
6. REVIEW R.9: the roster check `data.roster_visuals_resolve` (every npc.visual resolves via characters.lua, real or fallback) is NOT here (P05 is the same wave); it lives in P21's art_characters section.

**Gate:** LuaRuntime.get_config() returns every documented key; get_shop/get_recipes exist; lint clean on every repo Lua file; tests/sections/data.gd green.

##### Wave 3

#### P04-area-framework - 2D world framework: Iso maths, ASCII map parser, TileSet factory, IsoArea builder, WorldRoot2D, ArtCatalog with placeholder fallback

*Wave 3 - size L - depends on: P01, P02, P03, P05, P09, P10*

**Owns (exclusive):** `scripts/world2d/iso.gd`, `scripts/world2d/area_map.gd`, `scripts/world2d/area_tileset.gd`, `scripts/world2d/iso_area.gd`, `scripts/world2d/world_2d.gd`, `scripts/world2d/warp_2d.gd`, `scripts/world2d/interactable_2d.gd`, `scripts/world2d/day_night.gd`, `scripts/world2d/glow.gd`, `scripts/world2d/art_catalog.gd`, `scripts/world2d/placeholder_art.gd`, `scripts/world2d/prop_art.gd`, `scripts/world2d/game_data.gd`, `scripts/world2d/weather_fx.gd`, `scenes/main/world.tscn`, `scripts/world/world.gd`, `scripts/world/zone_trigger.gd`, `data/maps/_fixture_iso.map`, `data/maps/_fixture_ortho.map`, `lua/config/props.lua`, `lua/config/ambient.lua`, `tests/sections/area.gd`, `localization/world.csv`, `scripts/world2d/player_stub_2d.gd`, `tests/shot_*`

**Lift from:** SW/scripts/world2d/{iso,area_map,area_tileset,iso_area,world_2d,warp_2d,interactable_2d,day_night,glow,game_data,placeholder_art,prop_art}.gd; SW/scenes/main/world.tscn; SAG/scenes/farm_test.gd (TileMapLayer + real art contract); SA/export/assets/{iso_tiles,iso_props}/*.json (manifests); SW/tests/{shot_world,shot_sort,shot_flight,shot_tiles,sort_probe}.*

**Tasks**

1. Lift the spike framework and apply the DECISIONS of section 3.1/3.7: Iso.TILE_W=128, TILE_H=76 (true 36 degree diamond; the spike's 64 is replaced), ORTHO_W=96, ORTHO_H=56, SPRITE_SCALE removed (sprites are never scaled), Iso.DEFAULT_ZOOM=0.4 with ZOOM_MIN 0.3 / ZOOM_MAX 0.7 for the 1280x720 base viewport (equals the art spike's 0.6 at 1920x1080), squash() = TILE_H/TILE_W, all constants in one file. Verify cell<->world round trips and that TileMapLayer.map_to_local equals Iso.iso_center in tests/sections/area.gd.
2. ArtCatalog (new, scripts/world2d/art_catalog.gd, class_name ArtCatalog): single lookup for terrain(id), prop(id), backdrop(theme) (res://assets/backdrops/<theme>_sky.webp + _far.webp, gradient fallback), icon(item_id), portrait(visual_id), character_exists(id). Reads res://assets/iso_tiles/tiles.json, res://assets/iso_props/props.json, res://assets/icons/items/<id>.webp, res://assets/isometric_characters/<id>/animations.json; when a key has no real asset it returns the PlaceholderArt/PropArt fallback (keep the spike's generators, renamed to the art-spike catalogue ids of section 6.2) and records the id in ArtCatalog.missing() WITHOUT push_warning/push_error (tests print the list, P27 asserts it is empty). Placeholder painting must be cached/lazy: boot cost under 0.2 s (the spike measured 0.65 s).
3. area_tileset.gd: build the runtime TileSet from the art contract: one TileSetAtlasSource per terrain with texture_region_size 144x84, tile_size 128x76, TILE_SHAPE_ISOMETRIC + TILE_LAYOUT_DIAMOND_DOWN, atlas coords = Vector2i(cell.x % 4, cell.y % 4) (periodic), animated water (water_0..3 swap every 0.5 s), physics layer 0 -> ground_block (128) and layer 1 -> world (1), invisible blocker tile for the void rim, ortho TileSet (square 96x56) for projection ortho. Ground = TileMapLayer z=-10; Objects = y_sorted Node2D that holds props, NPCs, enemies, crops, player.
4. iso_area.gd: ASCII map -> area as in the spike (incl. the Parallax2D backdrop from ArtCatalog.backdrop so the platform floats in a visible sky) plus: `@prop <char> <prop_id>` header lines (map files choose props by art id; collision/strips come from lua/config/props.lua), `strips=N` y-sort slicing for big sprites (house_farm 3x2, mushroom houses 2x2: slice the PNG into N vertical AtlasTexture strips, each Sprite2D sorted at the footprint front line under that strip - fixes the single-sort-key side-face artefact the spike documented), additive glow sprites that fade in with night, unknown marker types are skipped silently and counted in area.skipped_markers (so later packages can land independently), marker parameter `when=` (quest:<id> | done:<id> | flag:<name> | night) evaluated on enter and on quest/flag changes, marker types of the table in section 3.7: built-in spawn, warp (req_day=), sign, bed, quest_spot, light; lazily resolved npc, enemy, node, whisper, animal_yard, building_slot, field_expansion.
5. world_2d.gd (WorldRoot2D): lift and change: (1) area registry scans res://data/maps/*.map (ids from @id, files starting with _ are fixtures) instead of the hard-coded MAPS; (2) instances scenes/ui/game_ui.tscn (P07) instead of HudProto/DialogueBox2D/PauseController and calls GameUI.set_mode(&"farm"|&"action") on travel; (3) marker handlers are resolved lazily by script path (npc_2d.gd, enemy_2d.gd, resource_node_2d.gd, whisper_zone.gd, animal_yard, quest_spot...) via ResourceLoader.exists so this wave can run without the scripts of waves 4-5; (4) iso areas (farm, hyggebyen) are parked in the cache, ortho areas rebuilt each visit; warm_clips() for the player + visible NPC clips behind the fade; (5) to_dict/from_dict include area id, player pos, farm, hotbar, placed items, area flags; SaveManager.pending_world consumed in _ready; (6) emits EventBus.zone_entered(zone) ONLY from here (zone id = the map's @zone header, default from lua/config/ambient.lua `area_zone`), unlocks via GameManager.unlock_zone; (7) sleep()/pass-out unchanged, plus rain overlay (weather_fx.gd) and season tint; (8) opening hook: if GameManager.world_flags has intro_pending, call IntroSequence (P14) when it exists.
6. day_night.gd + lua/config/ambient.lua: CanvasModulate keyed by hour via Lua keyframes per ambient preset (farm_day, hyggebyen_day, forest_night, cave) and a season multiplier (foraar neutral, sommer warm, efteraar orange, vinter cool); the three zone palettes of the guide (Trætoppen warm honey, Hyggebyen lavender/rose, Mørkeskoven navy #1c2138 + mushroom teal #6fd6c4) are the keyframe colours. Glow sprites and PointLight2D (lantern posts, windows) ramp in at dusk. weather_fx.gd: CPUParticles2D rain overlay while TimeManager.is_raining() (iso areas only); fog/snow/thunder are label-only (stub).
7. interactable_2d.gd + game_data.gd: Interactable2D base (group interactable, layer 4, get_interaction_prompt(), interact(player), optional when=); GameData static helpers (lua(), perk(), combat(), item_def(), visual_for_skin() reading lua/config/characters.lua from P05 with fallback ids, race_key()).
8. Replace scenes/main/world.tscn by a root Node2D with world_2d.gd (spike version) and delete scripts/world/world.gd + zone_trigger.gd. data/maps/_fixture_iso.map (12x12, water, bridge, field, tree, house, every marker type) and _fixture_ortho.map (12x10, wall tiles, bog) are the test fixtures used by tests/sections/area.gd and the screenshot drivers.
9. VERIFY: tests/sections/area.gd (geometry, collision slide 150 vs 162 px, y-sort probes at the sort point +/-5 px, marker handlers, strips, `when=`, fixture area switch farm<->fixture, ArtCatalog.missing() lists only expected ids) passes headless with zero engine errors; screenshots tests/shot_world.tscn --part=fixtures show the iso fixture with real tiles when assets exist.
10. REVIEW R.2/R.10 (binding): (1) scripts/world2d/player_stub_2d.gd: minimal CharacterBody2D + Camera2D honouring the Player contract (group `player`, enter_area(area, spawn), global_position, take_damage no-op); WorldRoot2D loads scenes/world2d/player_2d.tscn when it exists, else the stub - this breaks the P04<->P06 cycle. (2) Skirts: one skirt sprite per platform-edge cell (platform_sw / platform_se / platform_corner props) in a non-y-sorted `Skirts` node at z_index -9; placeholders keep the old tile skirts. (3) strips=N: strip width 32 px; strip centre xc = P.x + (u0+u1)/2 - pivot.x gets sort y = B.y - squash*|xc - B.x| clamped below by L.y (xc < B.x) or R.y (xc > B.x), with L,B,R the footprint corners from Iso.iso_footprint; node position = (xc, sort_y), offset = (P + (u0 - pivot.x, -pivot.y)) - position (exact formula in R.10). (4) Water: four TileMapLayers with identical cells, one visible, swap every 0.5 s, physics on layer 0 only. (5) Node texture filters: Ground texture_filter=2 (tile atlases imported without mipmaps), Objects/Backdrop 4 (R.1). (6) tests/shot_world.*, shot_sort.*, shot_flight.*, shot_tiles.* are owned here (lift from SW/tests; they need a world). (7) world.csv holds WHISPER_TOO_EARLY, WHISPER_FAINT, UI_SLEEP, NOTIF_PASSED_OUT and other strings of WorldRoot2D/bed/sign. (8) default start area = `farm` if data/maps/farm.map exists, else `_fixture_iso` (so P06/P16 tests run before P11 lands). (9) windowed checks `area.render_not_blank` (ground, sky and player pixels differ from clear colour and from each other) and `area.filter_seams` (R.6) in tests/sections/area.gd run_windowed(). -> verify: area.strips_sort, area.skirts_placed, area.water_frames, area.player_stub_contract headless; windowed ones at the wave boundary

**Gate:** WorldRoot2D loads the farm map and the fixtures with the placeholder fallback and the player stub (zero engine errors, headless); the windowed render probe passes at the wave boundary; real tiles/props appear later without code change.

#### P07-ui-foundation - Fonts, generated Theme, component library, GameUI root, ui.csv, UI dev tools

*Wave 3 - size M - depends on: P01, P03, P05, P09, P10*

**Owns (exclusive):** `assets/fonts/**`, `assets/ui/theme.tres`, `assets/ui/icons/**`, `shaders/**`, `scripts/ui/theme/**`, `scripts/ui/components/**`, `scenes/ui/components/**`, `scripts/ui/dev/**`, `scenes/ui/dev/**`, `tools/ui/**`, `scripts/ui/game_ui.gd`, `scenes/ui/game_ui.tscn`, `localization/ui.csv`, `tests/sections/ui_foundation.gd`, `tests/checkpoints/compare_guide.py`, `tests/checkpoints/guide_ref/**`

**Lift from:** SU/assets/fonts/** (Caprasimo, Alegreya Sans x4, IBM Plex Mono x2, TTSymbols + OFL texts; NOT NotoSansSymbols2 binary if TTSymbols covers all glyphs); SU/assets/ui/{theme.tres,icons/*.svg}; SU/shaders/*.gdshader; SU/scripts/ui/{theme,components,dev}/**; SU/scenes/ui/{components,dev}/**; SU/tools/ui/** (build_theme.gd, build_scenes.*, scene_kit.gd, scenes/s_*.gd, make_symbols_font.py); SU/localization/ui.csv; spike_ui_shots/pw1x_{title,select,hud,shop,quest,inventory,forest}.png (guide reference renders) + compare scripts of the UI spike

**Tasks**

1. Lift the UI spike foundation verbatim: fonts (OFL), assets/ui/theme.tres (145 theme types, regenerate with `godot --headless --path . -s res://tools/ui/build_theme.gd` AFTER the first --import so SVG icons resolve), TTBoxStyle scripted StyleBox, tt_colors/tt_format/tt_portraits/tt_quest_text, components (item_slot, quantity_stepper, ability_slot, notification_toast, tt_stripes, tt_item_icon, tt_sprite_face, tt_hearts, tt_dashed_line), shaders (stripes, blur_scrim, circle_mask), dev scenes (components_gallery, shot_runner, ui_smoke) - but NOT the throw-away probe_inv.* and NOT the stale scenes/ui/title_screen.tscn. The theme builder remains the single source of the guide's numbers.
2. tt_item_icon.gd icon path becomes res://assets/icons/items/<item_id>.webp (contract 6.2; the art spike's assets/ui/icons path is replaced); tt_portraits.gd resolves NPC id -> visual id (lua/config/npcs.lua, P10, with the characters.lua fallback chain) -> res://assets/portraits/<visual>.webp, else res://assets/isometric_characters/<visual>/portrait.webp; tt_format.gd uses TimeManager.date_text() (P02) so there is one calendar implementation.
3. scenes/ui/game_ui.tscn + game_ui.gd (CanvasLayer 10, process_mode ALWAYS): children are instanced DYNAMICALLY from an ordered list [hud, forest_hud, dialogue_ui, inventory_ui, quest_journal, shop_ui, animal_care_ui, build_menu_ui, pause_menu, save_load_ui, settings_ui] only if the scene file exists (ResourceLoader.exists) so screens can land in any order; API set_mode(&"farm"|&"action") (shows hud or forest_hud), group `game_ui`, `get_screen(name)`; no key handling here (each modal owns its key). Draw order = list order; panels are PROCESS_MODE_ALWAYS.
4. localization/ui.csv: lifted 86-row file (guide copy: perks, months, weekdays, shop tabs, journal tags, inventory, forest, pause, settings, dialogue hints) - it is now the base of every screen text; later packages add keys in their own csv. Add the HUD_ACTIVE_QUESTS/HUD_ENERGY/ABILITY_* keys if missing.
5. VERIFY (review R.3): the FOUNDATION smoke only - `godot --headless --path . res://scenes/ui/dev/ui_smoke.tscn` runs the components gallery, theme/fonts (Æ Ø Å æ ø å via has_char in Caprasimo and Alegreya), GameUI dynamic loader with zero screens, tt_* helpers, 5 stretch shapes and a raw-key sweep, with zero engine errors; tests/sections/ui_foundation.gd re-runs it; screenshots with shot_runner.tscn -- components match the spike's FINAL2/components.png (windowed).
6. REVIEW R.3/R.4/R.11: (1) ui_smoke is cut down to a FOUNDATION smoke (components gallery, theme/fonts/Æ Ø Å, GameUI dynamic loader, tt_* helpers, 5 stretch shapes, raw-key sweep of the gallery); the per-screen functions (_title/_select/_hud/_shop/_dialogue/_journal/_inventory/_forest/_pause/_saveload) are NOT kept here - their owners lift them into their own tests/sections (P16, P17, P18, P14, P19). ui_fixtures.gd loads a screen only if its scene exists (SKIP otherwise); the legacy main_menu.tscn/character_select.tscn do not count. (2) ui.csv is lifted WITHOUT any RECIPE_* or ITEM_* rows and WITHOUT the per-shop SHOP_<id>_* rows (owned by P12; SHOP_TAB_*, SHOP_TOTAL, SHOP_GREETING_DEFAULT are UI strings and stay) - keep UI_CURRENCY, UI_WEEKDAY_*, UI_MONTH_*, WORKSHOP_*, QJ_*, INV_*, SET_*, MENU_*, HUD_* shared, DIALOGUE_* hints; ship ui.csv.import with importer=keep (R.4). (3) tests/checkpoints/compare_guide.py (Pillow/numpy only, mean absolute RGB difference per screen) + the seven Playwright reference renders at 1280x720 (spike_ui_shots/pw1x_{title,select,hud,shop,quest,inventory,forest}.png) committed in tests/checkpoints/guide_ref/ so no browser is needed at test time. (4) game_ui.gd HUD controls use focus_mode NONE (documented rule for P17). -> verify: ui_foundation.components, ui_foundation.no_duplicate_keys

**Gate:** Theme + components load without second-import font errors; GameUI root instantiates whatever screens exist (none required); foundation smoke passes; compare_guide.py reproduces the spike's numbers on the spike screenshots.

#### P12-economy-shop-crafting - EconomyManager, Lua-driven shops, Lua recipes + CraftingSystem, all item definitions

*Wave 3 - size L - depends on: P02, P03, P09, P10*

**Owns (exclusive):** `scripts/autoload/economy_manager.gd`, `scripts/economy/**`, `lua/items/tools.lua`, `lua/items/crops.lua`, `lua/items/magic.lua`, `lua/items/resources.lua`, `lua/items/consumables.lua`, `lua/items/products.lua`, `lua/items/crafted.lua`, `lua/shops/**`, `lua/recipes/**`, `localization/economy.csv`, `tests/sections/economy.gd`

**Lift from:** SU/scripts/economy/crafting_system.gd (const table STUB -> Lua); SW/lua/items/consumables.lua; /Users/magnusudbjorg/Documents/projects/PongPong_lift/econ_proposal + econ_probe*.gd (verified fixes); audit: economy, farm, animals

**Tasks**

1. EconomyManager: reset on EventBus.new_game_started (gold = config economy.starting_gold, inventory cleared, starter kit given SILENTLY: hoe_wooden, watering_can_copper, axe_wooden, pickaxe_wooden, sword_rusty, scythe, 5 turnip_seeds, 2 lantern_oil, 1 health_tonic), INVENTORY_SLOTS = 24 (guide '18 / 24') with per-def max_stack (default 99, tools 1), amount validation (<= 0 rejected everywhere incl. Lua api), from_dict rebuilds StringName/int and drops invalid slots, emit EventBus.item_gained(id, amount) after every successful add (silent flag for starter/loading), add_item returns false when full and callers must respect it (harvest/collect leave the source untouched), auto-equip best tool/weapon by Lua power/damage, get_tool_power(type), use_item(id) (consumable effects via player, animals via AnimalHusbandry signal, placeable -> hotbar), has_items(dict).
2. ShopSystem: delete the hard-coded SHOPS dict; shops come from lua/shops/*.lua (kind="shops": id, name_key, keeper = npc id, greeting_key, tabs by item category + sell tab, buy/sell multipliers, stock {item: {price?, stock, restock}}). Listed price == charged price (shop multiplier AND hobbit shop_discount applied in ONE function get_buy_price), sell price min 1, items with sell price <= 0 or category quest/special are not sellable, stock refreshes on day_started, buy/sell refund on failure, open_shop emits EventBus.shop_opened. Shops shipped: seed_shop (Kløvermynte: the guide's 8 lines: carrot_seeds 20, pumpkin_seeds 60, strawberry_seeds 45, sunflower_seeds 30, catnip_seeds 35, moonflower_seeds 120 ('Månebønne'), fertilizer 15, fairy_dust_water 900; tabs Frø/Redskaber/Sælg), bakery (flour, honey, cookie ingredients), smithy (hoe_iron, pickaxe_iron, watering_can_gold, iron_sword), magic_store (Zephyr: fairy_dust, gems, lantern_oil, health_tonic), animal_store (Rosa: baby_* animals, feed, brush, milking pail; coop_kit/barn_kit REMOVED - buildings come from the build menu).
3. CraftingSystem (class_name CraftingSystem, static API): recipes from lua/recipes/*.lua (kind="recipes": id, name_key, category craft|bake|forge, ingredients {item=amount}, output {item,amount}, unlock flag optional); get_recipes(), can_craft(id) -> {ok, missing[{item,have,need}]}, craft(id) consumes/produces through EconomyManager, emits EventBus.recipe_crafted, hobbit bake_bonus gives +1 output with the configured chance for category bake. Shipped recipes (guide): mushroom_lantern ('Lygte med svampelys': glow_mushroom 7, iron_ingot/iron_ore 5, moonstone 1), scarecrow, honey_cake ('Honningkage': flour 2, honey 1, egg 1 - 'Mangler mel'), pickaxe_copper ('Kobberhakke': copper_ore 3, wood 2 - 'Mangler 2 kobber'), flour is bought at the bakery (no wheat crop); plus lantern_post and fence placeables and the forge recipe iron_ingot (iron_ore x2) used by sword_upgrade.
4. Item Lua (all lua/items except animals.lua): add max_stack, stamina_cost, rarity (common|uncommon|rare per guide 'Sjælden'), sell/buy prices from the economy table, description keys for EVERY id (gem_bag, moonstone sell 220 'Lyser svagt i mørke...', egg, duck_egg, wool, milk, magic_herb, lucky_fur, wisdom_feather, flour, honey, apple (orchard forage), strawberry/sunflower/catnip seeds + crops, fertilizer, fairy_dust_water, mushroom_lantern, scarecrow, lantern_post, fence, honey_cake, cookie, pickaxe_copper, scythe, fishing_rod (stub), moss, wood, stone, ores, ingots, crystals); remove the duplicate fairy_dust def; fix categories documented in docs; companionship product replaced by friendship_token. Every item id needs an icon id match in assets/icons/items (P23 list) - add `icon` only when it differs from the id.
5. localization/economy.csv: ITEM_*/ITEM_*_DESC for new ids, SHOP_* names/greetings (guide: 'Kløvermyntes Frø', 'Frisk fra regnbuen i morges! Græskarfrø giver gode penge til høstfesten.'), RECIPE_* names, RARITY keys not already in ui.csv.
6. tests/sections/economy.gd: gold clamp, 24-slot cap and stacking, listed==charged price for every shop item with and without hobbit discount, sell min 1, new game resets, save round trip of inventory, every item def has name/description keys that resolve in da+en, every recipe's ingredients/outputs are defined items, craft consumes/produces exactly, bake_bonus statistical (seeded) check, item_gained emitted once per add.
7. REVIEW R.4: economy.csv is the only owner of ITEM_*, ITEM_*_DESC (all but ITEM_BABY_*/species, which P20 owns), RECIPE_* and SHOP_* - including the rows the UI spike put into ui.csv (RECIPE_MUSHROOM_LANTERN/SCARECROW/HONEY_CAKE/IRON_PICKAXE, ITEM_MUSHROOM_LANTERN/SCARECROW/HONEY_CAKE, SHOP_*_GREETING); ship economy.csv.import (keep). Shops/recipes are read through LuaRuntime.get_shop/get_recipes (P10). animal_store stocks only item ids that exist in the current lua/items/animals.lua (baby_*, chicken_feed, animal_treats, brush, milking_pail). -> verify: economy.no_key_collisions, economy.shops_from_lua

**Gate:** tests/run_playtest.sh --only=economy passes; loc_check shows no missing ITEM_/SHOP_/RECIPE_ keys.

#### P15-save-system - SaveManager: versioned validated atomic saves, autosave slot, world state hand-off

*Wave 3 - size M - depends on: P01, P02, P09*

**Owns (exclusive):** `scripts/autoload/save_manager.gd`, `tests/sections/save.gd`

**Lift from:** /Users/magnusudbjorg/Documents/projects/PongPong_lift/save_audit (roundtrip, continue_flow, edge_cases, subsystems); SW report: SaveManager.pending_world hook

**Tasks**

1. Payload v2: meta{version,timestamp,summary}, game, economy, quests (no defs), time, husbandry (AnimalHusbandry.to_dict), shops (stock), world (WorldRoot2D.to_dict: area, player_pos, farm, hotbar, placed items, area flags). Validate BEFORE applying (root Dictionary, version <= current with a _migrate chain, sections are Dictionaries with required keys) - apply atomically; a failed load returns false and posts NOTIF_LOAD_FAILED_*, never half-applies; try the .bak on parse failure; JSON.new().parse() not parse_string (no engine-error spam); vectors stored as arrays; ints re-coerced.
2. Slots 0-5 manual + a dedicated `auto` slot: autosave on day end (end_day) and every 5 real minutes while PLAYING writes ONLY the auto slot (never overwrites a manual save); .bak rolled from manual saves only; write via temp file + rename; get_save_summary(slot) incl. farm name, character, day, season, gold, play time; get_latest_slot() (newest timestamp across manual+auto) used by Continue; reset on new_game_started (current_slot = -1, timers zero); pending_world handed to WorldRoot2D._ready, applied after the scene exists.
3. tests/sections/save.gd: round trip of every system that exists in this wave (gold, items, quests, time, husbandry, shops, calendar) plus the WORLD DICT CONTRACT (an opaque Dictionary handed through pending_world and returned unchanged; the crop/placed/hotbar/player content is asserted by farm.save_roundtrip (P06), animals.save_roundtrip (P20) and zz_acceptance (P27)); SaveManager.continue_latest() loads get_latest_slot() (the menu button in P16 only calls it), corrupt/empty/foreign-version/truncated saves do not soft-lock and show feedback, autosave never touches a manual slot, New Game after Continue is clean, saves written in a throwaway HOME so the real user:// is untouched.

**Gate:** tests/run_playtest.sh --only=save passes: validation, atomic apply, slots + auto slot, summaries, latest-slot, throwaway HOME; the cross-system round trip is closed by P06/P20/P27.

#### P21-art-characters - Missing characters: hobbit x3, squirrel, NPC fairies and named NPCs, farm animals, forest creatures + boss

*Wave 3 - size L - depends on: P05, P08, P09, P10*

**Owns (exclusive):** `assets/isometric_characters/hobbit_pip/**`, `assets/isometric_characters/hobbit_moss/**`, `assets/isometric_characters/hobbit_bramble/**`, `assets/isometric_characters/squirrel/**`, `assets/isometric_characters/fairy_dusk/**`, `assets/isometric_characters/fairy_stardust/**`, `assets/isometric_characters/fairy_mayor/**`, `assets/isometric_characters/fairy_baker/**`, `assets/isometric_characters/fairy_shopkeeper/**`, `assets/isometric_characters/fairy_king/**`, `assets/isometric_characters/fairy_wizard/**`, `assets/isometric_characters/fairy_lily/**`, `assets/isometric_characters/mouse_pippin/**`, `assets/isometric_characters/cat_morfar_mis/**`, `assets/isometric_characters/bear_guard/**`, `assets/isometric_characters/rabbit_farmer/**`, `assets/isometric_characters/raccoon_smith/**`, `assets/isometric_characters/penguin_postman/**`, `assets/isometric_characters/chick/**`, `assets/isometric_characters/hen/**`, `assets/isometric_characters/duck/**`, `assets/isometric_characters/kitten/**`, `assets/isometric_characters/bunny/**`, `assets/isometric_characters/fox_cub/**`, `assets/isometric_characters/lamb/**`, `assets/isometric_characters/calf/**`, `assets/isometric_characters/owl/**`, `assets/isometric_characters/puppy/**`, `assets/isometric_characters/fawn/**`, `assets/isometric_characters/snurresvamp/**`, `assets/isometric_characters/tornebusk/**`, `assets/isometric_characters/ugleoje/**`, `assets/isometric_characters/lysesvamp/**`, `assets/isometric_characters/manifest_traetoppen.json`, `assets/portraits/**`, `tools/art/characters/**`, `tests/sections/art_characters.gd`

**Lift from:** SA/tools/characters/{geometry,additions,build_assets,traetoppen_additions}.py (32 characters); SA/export/assets/isometric_characters/** (reference output to diff against); /Users/magnusudbjorg/Documents/projects/PongPong_lift/pongsrc (original generator package)

**Tasks**

1. The pristine generator base is in tools/art/generator (P08); this package owns tools/art/characters/ = traetoppen_additions.py (ASCII module name) and new builders only. Run `tools/art/produce_all.sh --only=characters` (about 2.5 min wall, 5 parallel bakes; single: `python tools/art/characters/build_assets.py --only <id> --output DIR` ~1 s then `python tools/art/core/bake_sprite_atlases.py <id> --out DIR` 3-14 s). Roster (all validated by validate_new_assets.py): hobbit_pip/moss/bramble (3 skins), squirrel (Egern), fairy_dusk + fairy_stardust (Fe skins, flight clips), fairy_lily, fairy_mayor (Hyldeblomst), fairy_baker (Rosmarin, chef hat), fairy_shopkeeper (Kløvermynte), fairy_king (Fekongen, crown + beard), fairy_wizard (Zephyr), mouse_pippin (Pippin Bøgeknop), cat_morfar_mis, bear_guard (Oak), rabbit_farmer (Rosa), raccoon_smith (Thorin), penguin_postman, farm animals chick hen duck kitten bunny fox_cub lamb calf owl puppy fawn, forest creatures snurresvamp (boss: idle walk attack hit spin), tornebusk, ugleoje, lysesvamp (baked halo).
2. Clip sets per role (keeps atlases small, section 6.2): player = all 11 clips (+ takeoff/hover/fly/flight_land for fairies), npc_flyer = idle hover talk celebrate interact, villager = idle walk talk celebrate interact sleep, farm_animal = idle walk run interact sleep hit celebrate, enemy = idle walk run attack hit, boss = idle walk attack hit spin, critter = idle walk run hit sleep. Each folder has animations.json (role, family, flyer, portrait, display_scale 1.0, glow) and portrait.webp rendered from the 14 degree bust camera (head and shoulders).
3. QUALITY GATES (all mandatory): (1) validate_new_assets.py green for all 32 (sheet size, no blank frames, no opaque border pixels); (2) contact sheets `tools/art/core/cast_sheet.py` of the whole cast at game scale NEXT TO the 4 sketch-derived pack characters (bear, cat, rabbit, bat) and fox/fairy - figure height within +/-10% of the pack, same outline colour, same eye style; (3) windowed screenshot tests/perf_world.tscn -- --cast (P05, same wave as P04's shot drivers so shot_world.tscn is not available yet) with Camera zoom 0.4 at 1280x720 showing pack + new characters on grass tiles; (4) animation check: walk/run/talk/hit rows S and SE for hobbit, squirrel, fairy NPCs, boss spin from all sides; (5) hobbit hairy feet readable at game scale (bump foot size/colour if not); (6) portrait.webp legible at 96-150 px. A human looks at 2, 3 and 4 before the package is accepted.
4. Write the new folders directly under assets/isometric_characters/<id>/ (WebP q97 method 4, 6 workers), the exporter writes the S3TC import stubs (tools/import/write_import_stubs.py, P05) BEFORE the first import, update manifest_traetoppen.json, and re-run tests/sections/characters.gd from P05 (all ids in lua/config/characters.lua now resolve to REAL art, no fallback). tests/sections/art_characters.gd: every roster id has all clips of its role, frame sizes 256 cells, pivots in animations.json, portraits exist, VRAM budget report (S3TC) < 400 MB for everything loaded in Hyggebyen.
5. Bust portraits for the 12 PACK characters: the pack's portrait.webp files are old full-body crops; regenerate head-and-shoulders busts from the source generator (build_assets.py --only <pack id> then the bust camera) into assets/portraits/<id>.webp (this package owns that folder; TTPortraits resolves assets/portraits/<id>.webp first, then <id>/portrait.webp) so every dialogue/quest/shop portrait has the same framing. FACE GRAMMAR of the four user sketches (docs/Trætoppen Style Guide Review/refs: bat, cat, bear, rabbit) must hold for every new character: two big round eyes with one dark pupil, three short whisker strokes on each cheek, tiny mouth, big round head on a small pear body, stubby arm arcs, small feet; check against the sketches in the contact sheet.
6. HONEST NOTES to record in tools/art/README.md: characters are soft CG renders in the same family as the pack, not hand-painted; hobbit/squirrel/NPC bodies reuse the stock rig so animation is as subtle as the pack's; Pippin's satchel strap reads as a stick; fairy NPCs have no walk clip (they hover); the boss is a single design, not a texture pass.
7. REVIEW R.9: the art spike baked 32 characters; fairy_lily was NOT among them - author it (npc_flyer clip set, recolour + ribbon like the other NPC fairies). Add `art.roster_visuals_resolve` (every npc.visual of lua/config/npcs.lua and every skin of characters.lua resolves to REAL art, no fallback) and the windowed `art.cast_matches_pack`.

**Gate:** All 33 ids resolve to real sprites; cast screenshot approved next to the pack.

##### Wave 4

#### P06-player-farm-core - Player2D (movement, camera, tools, flight, combat abilities), hotbar, FarmGrid/FarmView, target marker and FX

*Wave 4 - size L - depends on: P02, P04, P05, P10, P12*

**Owns (exclusive):** `scripts/world2d/player_2d.gd`, `scripts/world2d/target_marker_2d.gd`, `scripts/world2d/slash_2d.gd`, `scripts/world2d/light_ring_2d.gd`, `scripts/world2d/dust_2d.gd`, `scripts/world2d/hotbar.gd`, `scripts/world2d/farm_grid.gd`, `scripts/world2d/farm_view.gd`, `scenes/world2d/player_2d.tscn`, `scripts/player/player_controller.gd`, `scenes/player/player.tscn`, `scripts/farm/farm_system.gd`, `scripts/farm/farm_plot_interactable.gd`, `localization/farm.csv`, `tests/sections/player.gd`, `tests/sections/farm.gd`

**Lift from:** SW/scripts/world2d/{player_2d,target_marker_2d,slash_2d,light_ring_2d,dust_2d,hotbar,farm_grid,farm_view}.gd; SW/scenes/world2d/player_2d.tscn; SW/tests/playtest_world.gd sections geometry,move,collide,slide,perks,farm,flight,zoom,sleep

**Tasks**

1. Lift Player2D and apply the section 3.1/3.9/3.10 changes: no Visual scale (1.0), camera zoom from Iso.DEFAULT_ZOOM with wheel zoom between ZOOM_MIN/ZOOM_MAX (accumulate on a target value), IsoChibiSprite2D.create(visual_id) for the visual (skin read from GameManager.character_skin in _ready AND on player_character_changed; visual id via GameData.visual_for_skin), ground-unit walk 285 / run 450 / accel 2500 / decel 3300 (the spike numbers x 1/0.6, section 3.13) read from lua/config/game_balance.lua `player` (P10), collision ellipse 25 x 14.8, hop gravity 1750, hotbar_changed/player_stats_changed(all four keys, dirty flag only)/player_health_changed/player_oil_changed/interaction_prompt_changed emitted on EventBus (no polling by the UI), run uses the `run` action with hysteresis (exhausted at 0, recovers at 20%), stamina regen from config, stamina cost per tool from the item def (stamina_cost, default 4), faint -> WorldRoot2D.
2. Tool dispatch (tool/hotbar model, section 3.10): item category tool with tool_type hoe|watering|axe|pickaxe|scythe, seed (crop_id), consumable (heal_half_hearts, oil_seconds, stamina), placeable (calls PlacementService.place(item, cell) from P20 when it exists, else whisper `WHISPER_NOT_YET`), weapon; scythe harvests every READY plot in a 3-cell arc; fishing_rod shows whisper `WHISPER_FISHING_CLOSED` (stub); axe/pickaxe act on node markers (resource nodes, trees) via the interactable query; selected slot via slot_1..slot_10 actions, mouse wheel stays zoom. Interact = circle query r=45 ground px at the facing cell on layer 4 (D20; the spike's 34 was for 0.6-scaled sprites); E on a READY plot harvests; target marker draws the cell (gold ring when farmable).
3. Race perks in code but numbers in Lua (race_perks.lua P10): animal dig_speed/tool_cost_mult/harvest_bonus_chance, fairy can_fly (F toggles, Space/Shift climb/descend, 8 s, 10 energy/s, only where @flight true, forced landing glides to nearest walkable cell, shadow stays on floor), hobbit shop_discount/bake_bonus read by P12. `talks_to_flowers` (Fe): while within 2 cells of a crop the whisper box shows a Danish flower line (stub flavour, 6 lines in farm.csv).
4. Combat abilities lifted unchanged in behaviour (numbers in race_perks.lua `combat`): swing arc Area2D (slag, LMB), dodge roll with i-frames (undvig, Space in action areas), fe-lys PointLight burst + stun (Q), drink (R), half-heart damage with thorn-berry pink flash (never red), lantern oil with min light 35% and whisper at 20% (oil_empty_hurt_interval from config, default 12 s -> 1 half heart, 0 disables), faint -> farm.
5. FarmGrid (model, section 3.7/3.10) lifted + extended: till only on `f` cells, seed item decides crop via def crop_id, season gate, +1 growth day per watered day (rain auto-waters via TimeManager.is_raining), READY when growth_days >= stages*days_per_stage, yield 1 (+1 harvest_bonus_chance); NEW: fertilizer item (`fertilizer` on a tilled/planted plot -> yield +1 once), `auto_water_days` (item fairy_dust_water: waters the plot 3 days), optional crop def `water_window = {from=20,to=6}` (moon crops only grow if watered at night), plot expansion API unlock_cells(zone_id) driven by map marker `field_expansion` (emits EventBus.plot_unlocked), placed items list (scarecrow/lantern/fence) in to_dict, JSON-safe "x,y" keys. Emits crop_planted/watered/harvested/stage_changed with the existing arities.
6. FarmView draws crops using ArtCatalog.prop("crop_<crop>_<stage>") (4 stages, ready stage glows for moonflower), soil tiles swap tilled/watered, harvest sparkle; works with the placeholder fallback.
7. Delete the 3D files scripts/player/player_controller.gd, scenes/player/player.tscn, scripts/farm/farm_system.gd, scripts/farm/farm_plot_interactable.gd. localization/farm.csv: FARM_* notifications, WHISPER_* for flowers/fishing, tool names fall back to ITEM_*.
8. tests/sections/player.gd + farm.gd: port the spike's geometry/move/collide/slide/perks/farm/flight/zoom/sleep checks to the final TILE_H=76 constants and the fixture maps; add: Space is hop on the farm and dodge in action areas, stamina stats emitted only on change (<= 2/s idle), farm loop till->plant->water->4 days->harvest into EconomyManager for each of the 4 crops, rain waters, fertilizer +1, fairy flight blocked in non-flight area, hotbar_changed entries carry item ids and counts, 100 frames of idle emit zero stats signals.
9. REVIEW R.12/R.13/R.6: (a) one helper Iso.S = 1/0.6 rescales EVERY sprite-space literal of the lifted scripts and scene (Visual scale 0.6 -> 1.0, lantern texture_scale 3.3/1.6, burst light, Hurtbox 16x24 at y=-34, AttackArc and dust offsets -24/-6/14, target marker) - grep list in R.12. (b) Hotbar listens to EventBus.hotbar_assign_requested(slot, item_id) (emitted by the backpack, P18); default hotbar follows the starter kit and shows 0-count entries dimmed. (c) windowed check player.sprite_visible_pixels; headless player.sprite_visible = visible Sprite2D with a texture under Player/Visual. -> verify: player.rescale_literals (no literal left from the R.12 grep list), player.hotbar_assign

**Gate:** tests/run_playtest.sh --character=animal|fairy|hobbit --only=player,farm passes with zero engine errors; windowed screenshots farm_01..farm_04 (tests/shot_world.tscn, P04) show tilled soil, crops in 4 stages and the target marker.

#### P11-maps-iso - Isometric area maps: Trætoppen farm and Hyggebyen town (ASCII + markers), area strings

*Wave 4 - size M - depends on: P03, P04, P05, P10*

**Owns (exclusive):** `data/maps/farm.map`, `data/maps/hyggebyen.map`, `data/.gitkeep`, `localization/areas.csv`, `tests/sections/maps_iso.gd`

**Lift from:** SW/data/maps/farm.map (44x44 treetop platform, field, pond, bridge, plaza); PLAN section 4 blueprint

**Tasks**

1. Author data/maps/farm.map ('Trætoppen', @projection iso, @ambient farm, @flight true, @music farm_theme) per blueprint 4.1: raised treetop platform with void rim, farmhouse (`@prop H house_farm`, front cell facing the plaza), field `f` block 12x7 plus a locked expansion zone marker (`field_expansion id=east cells=...`), pond `~`, apple orchard (3 `node kind=apple_tree`, sign SIGN_ORCHARD), animal yard + 3 building slots (coop, barn, house), bed at the farmhouse door, scarecrow spot, lantern posts, rope bridge `=` with posts to Hyggebyen (hængebro), stone warp gate to the Mørkeskoven, spawn points default, from_hyggebyen, from_forest.
2. Author data/maps/hyggebyen.map ('Hyggebyen', iso, @ambient hyggebyen, @flight true): cobble torv with fountain/well, ring of mushroom houses (`house_mushroom_rose/lavender/mint`) for the NPC roster of section 3.8 (town hall = Borgmester Hyldeblomst, bageri = Bagerfe Rosmarin, frøbutik = Butiksfe Kløvermynte, smedje, dyrehandel (Rosa), troldmandstårn (Zephyr), Fekongens træhus at the north end), `npc id=<roster id>` markers only (visual/facing/wander from npcs.lua), a penguin_postman critter, blossom trees, lanterns, signs, hængebro warp back to the farm, west gate warp to skovkant (`req_day` from config), spawn points from_farm, from_forest.
3. Wire the sort/collision props through `@prop` lines using only art-spike ids (tree_oak_farm, tree_blossom_hyggebyen, house_farm, house_mushroom_*, fence_x/z, bridge_x/z, lantern_post, rock_*, bush_*, scarecrow, platform_*, chest_closed) so P22 art drops in unchanged.
4. localization/areas.csv: SIGN_* texts, zone/area titles for farm and Hyggebyen that are not in core.csv, warp labels, interaction prompts for bed/sign/gate (UI_SLEEP, UI_READ...).
5. VERIFY tests/sections/maps_iso.gd: both maps parse (rows equal width, markers resolve, every npc id exists in npcs.lua, every prop id has a placeholder or real art, every warp target+spawn exists), walkable path exists from every spawn to every warp (flood fill on non-ground_block cells), farm has >= 84 `f` cells, plots reachable; screenshots shot_world --part=farm / --part=hyggebyen show the layout (look at them).
6. REVIEW R.10/R.2: `maps_iso.art_complete` (ArtCatalog.missing() empty for farm and Hyggebyen) is SKIP until P22's assets exist and strict in P27; skirts and big buildings use the P04 mechanisms (skirt props, strips=N with the R.10 formula); prop ids that are not in the 56-prop export come from P22's lua/config/props_extra.lua list. Fill Hyggebyen: the blueprint's 7 buildings, torv fountain, 3 market stalls, 6 lantern posts, signs, well, blossom trees - an empty 40x40 grass diamond is the known 6.5/10 failure.

**Gate:** Farm and Hyggebyen build with the placeholder fallback and later with real art; flood-fill connectivity test passes.

#### P13-quests-lua-runtime - QuestManager objective bindings, quest/objective text, all quest Lua (guide quests)

*Wave 4 - size L - depends on: P02, P03, P10, P12*

**Owns (exclusive):** `scripts/autoload/quest_manager.gd`, `lua/quests/**`, `localization/quests.csv`, `tests/sections/quests.gd`

**Lift from:** /Users/magnusudbjorg/Documents/projects/PongPong_lift/loose/quest_triggers.gd + triggers_test.gd (completes all 20 quests); audit: quests, lua

**Tasks**

1. REVIEW R.2: LuaRuntime hardening, lint and the generic kinds loader are done by P10 (earlier wave) - this package USES them: register quests through LuaRuntime, run `tools/lua/lint.gd` in its section, and must not edit lua_runtime.gd. If a runtime gap is found, file it against P10.
2. QuestManager: separate `quest_defs` (never saved) from runtime `quest_flags`; reset() on new_game_started; always iterate over keys() copies; honour meta.repeatable/cooldown_days/requires_zone; objective binding matcher driven by the Lua field `on=` (vocabulary in section 3.12: item_gained(item), crop_planted(crop?), crop_watered, crop_harvested(crop?), zone_entered(zone), dialogue_started(npc | any_of = each listed NPC counts once), animal_adopted/animal_fed/animal_product_collected(product), building_built(type), enemy_defeated(kind), recipe_crafted(recipe), quest_completed, manual) with `after_others=true` for turn-ins, `have=true` objectives that track inventory counts; remove the resource_node_depleted special case (double counting); keep harvest_<crop>/harvest_any as a documented alias; get_objective_text(quest, obj) (OBJ_<QUEST>_<OBJ> -> OBJ_<OBJ> -> Lua description); get_tracked(max=3); friendship rewards `friendship = {npc = n}` -> world flag friend_<npc>; quest_spot interaction API complete_manual(quest, objective); emits quest_* signals; to_dict/from_dict of only active/completed/failed/offered + flags.
3. Quest Lua content (all 20 files edited + new): every quest gets meta.giver (npc id), meta.location (zone key), meta.tag (FIND/HØST/BYG/SKOV/LÆR/VENSKAB), title_key/description_key (QUEST_<ID>_TITLE/_DESC), objective description_key and `on=` bindings from the audit table (section 3.12 lists all of them), no hard-coded Danish notification strings, math objectives renamed unique (math_harvest_carrot, math_collect_stone, math_collect_mushroom). GUIDE QUESTS: lost_cat ('Find Pippins kat', giver pippin_boegeknop, FIND; steps 'Spørg naboerne i Hyggebyen' (talk to 3 NPCs), 'Følg poteaftrykkene ved broen' (quest_spot), 'Find Morfar Mis i Mørkeskoven' (dialogue with cat_morfar_mis, visible when quest active), return; reward 150 guldagern + catnip_seeds x3 + friendship Pippin), cookie_delivery ('Gulerødder til småkager', giver baker_maja, HØST, collect carrot 12, 'Bagerfe Rosmarin · 5 / 12'), fix_roof ('Utæt tag på bageriet', giver mayor_lyra, BYG: wood 8 + moss 4 then repair at the bakery quest_spot), NEW moonstone_crown ('Månesten til kronen', giver fairy_king, SKOV: collect moonstone 1 in Dybe Bregner/Krystalgrotten, return to the king, reward crown fairy_dust + gold). intro_lottery objectives become plant_first_crop, cross_bridge (zone city), talk_to_mayor; auto-accepted by IntroSequence (P14).
4. localization/quests.csv: QUEST_*_TITLE/_DESC/_OFFER, OBJ_<QUEST>_<OBJ> for every objective, LUANOTIF_* keys; remove dependence on the legacy shared OBJ_* rows that bake numbers.
5. tests/sections/quests.gd: (a) lint_report empty for every repo Lua file, (b) a table-driven test drives EVERY objective of ALL quests through the real EventBus signals / API and asserts completion and rewards (no quest left uncompletable), (c) repeatable quests re-accept after cooldown, (d) loading a save keeps live Lua definitions, (e) the Lua probes live in P10's tests/fixtures/lua (regression there), (f) every quest text key resolves in da+en.
6. REVIEW R.4: quests.csv is the only owner of QUEST_*, OBJ_*, LUANOTIF_* (it replaces the 15 missing legacy OBJ_* keys and the QUEST_FAIRY_FRIENDSHIP_TITLE typo); ship quests.csv.import (keep).

**Gate:** tests/run_playtest.sh --only=quests passes: all quests completable; lint clean.

#### P16-ui-menus - Title screen, Vælg figur (2 pages), settings, pause menu, save/load screens

*Wave 4 - size L - depends on: P02, P03, P04, P05, P07, P15*

**Owns (exclusive):** `scenes/main/main_menu.tscn`, `scripts/ui/main_menu.gd`, `scripts/ui/character_select.gd`, `scenes/ui/character_select.tscn`, `scripts/ui/settings_ui.gd`, `scenes/ui/settings_ui.tscn`, `scripts/ui/pause_menu.gd`, `scenes/ui/pause_menu.tscn`, `scripts/ui/save_load_ui.gd`, `scenes/ui/save_load_ui.tscn`, `localization/menus.csv`, `tests/sections/menus.gd`

**Lift from:** SU/scenes/main/main_menu.tscn + scripts/ui/{main_menu,character_select,settings_ui,pause_menu,save_load_ui}.gd + scenes; /Users/magnusudbjorg/Documents/projects/PongPong_lift/hud_menus (modal/focus fixes)

**Tasks**

1. Title (guide 'Titelskærm'): key art background assets/ui/keyart/title.webp (P23; stripes placeholder until it exists), 132 px 'Trætoppen' with ink stroke and gold sub-badge, menu panel Fortsæt (+ 'Dag N' from SaveManager summary, disabled without a save, loads get_latest_slot with failure feedback) / Nyt spil / Indstillinger / Afslut, language tag 'v0.1 · Dansk' is the da<->en switch (NOTIFICATION_TRANSLATION_CHANGED refresh, no signal re-connects = the 5-errors-per-click bug), initial focus on first enabled row, GameManager.change_phase(MENU) + tree unpaused in _ready (quit-to-menu from a paused world must give a live menu).
2. Vælg figur: page 1 three race cards (Skovdyr/Fe/Hobbit) with guide perk texts and tt_sprite_face showing the real sprite (fox/fairy/hobbit_pip; stand-ins via characters.lua fallbacks), selected card lifts 8 px and gets the gold ring, 'Dyr:' species chips Ræv/Kanin/Pindsvin/Egern (animal only; Egern uses squirrel), a variant chip row for Fe (Eng/Stjernestøv/Skumring) and Hobbit (Pip/Mos/Tornebusk) - optional stretch, 'Videre ▸'; page 2 name + farm name fields, 'Start ▸', Esc/Tilbage returns, '1 / 2'. Calls GameManager.start_new_game(name, type, farm, skin) then change_scene_to_file(world.tscn). All labels are translation keys in the scene (no Danish literals).
3. SettingsUI: language chips, Master/Music/SFX/Voice sliders bound to the buses created by AudioManager, fullscreen check, window size presets (1280x720, 1600x900, 1920x1080), persisted in user://settings.cfg shared with LocalizationManager (load-modify-save), static apply_saved() called by the title. PauseMenu: Fortsæt / Gem / Indlæs / Indstillinger / Hovedmenu (+ Afslut spil), opens on `pause` when no other modal is open and closes on the second Esc (the playtest bug), uses GameManager.push_modal("pause"), Quit-to-menu: pop modals, change_phase(MENU), autosave first. SaveLoadUI: 6 manual slots + auto slot (read-only), summary rows, delete with themed confirm (borderless ConfirmationDialog), never changes the phase itself (nested under pause).
4. localization/menus.csv for new keys only; tests/sections/menus.gd: keyboard focus walk on title/select/pause, Esc behaviour, language switch with zero engine errors and zero raw keys on every screen in both locales (regex over every Label/Button/RichTextLabel), New Game flow for all 3 races incl. each species chip, Continue, pause -> save -> load -> resume, quit-to-menu then New Game, settings persist across a restart of the harness.
5. REVIEW R.3/R.14: lift the spike's _title/_select/_pause/_saveload smoke functions into tests/sections/menus.gd and run them against the real SaveManager/GameManager; ConfirmationDialog/AcceptDialog get title CONFIRM, ok_button_text UI_OK, cancel_button_text UI_CANCEL (engine defaults are English); every *.csv.import is keep (R.4); the title diff (compare_guide.py from P07) is a windowed check. main_menu.gd Continue only calls SaveManager.continue_latest().

**Gate:** Screens match the guide (cmp screenshots: title 7.5, select 14.7 mean diff in the UI spike - must not regress); flow tests pass for all 3 characters.

#### P18-ui-shop-inventory - Shop in Hyggebyen, Rygsæk (24 slots) and Værksted (crafting) screens

*Wave 4 - size L - depends on: P03, P07, P12*

**Owns (exclusive):** `scripts/ui/shop_ui.gd`, `scenes/ui/shop_ui.tscn`, `scripts/ui/inventory_ui.gd`, `scenes/ui/inventory_ui.tscn`, `localization/shop_ui.csv`, `tests/sections/shop_ui.gd`

**Lift from:** SU/scripts/ui/{shop_ui,inventory_ui}.gd + scenes (guide diff 17.5 / 21.9); /Users/magnusudbjorg/Documents/projects/PongPong_lift/econ_proposal/*_fixed.gd

**Tasks**

1. ShopUI: opens on EventBus.shop_opened(shop_id) from ShopSystem (Lua shop def), blurred world backdrop (blur_scrim lavender tint), keeper bust + chalk speech bubble (keeper npc portrait + shop greeting_key), parchment panel 'Kløvermyntes Frø' with category tabs Frø/Redskaber/Sælg, 2-column item list with icons (ArtCatalog.icon), name, description, price in Caprasimo (thorn-berry pink when gold < price), quantity stepper (− 5 +), 'I alt N', gold readout, Køb/Sælg (primary green), Esc/✕ closes, GameManager.push_modal("shop"); process_mode ALWAYS; no raw 'guld' literals; hobbit discount reflected because it reads ShopSystem.get_buy_price.
2. InventoryUI ('Rygsæk'): 6x4 slot grid (EconomyManager.INVENTORY_SLOTS=24) with empty/filled/selected/rare states, counts, 'n / 24', detail card (icon, name, rarity ' · Sjælden', description, 'Sælges for N'), actions Brug/Udstyr/Slip via EconomyManager.use_item, hotbar assign (click slot then press 1..0); 'Værksted' panel to the right: recipe list with 'Kan laves'/'Mangler ...' states, ingredient tiles (icon, have/need in moss green or thorn-berry), 'Lav' button -> CraftingSystem.craft; I and Tab toggle, Esc closes, push_modal("inventory").
3. tests/sections/shop_ui.gd: open every Lua shop, buy and sell through the UI controls (button presses) and check gold/inventory deltas equal the displayed totals; discount for hobbit; too-dear styling; Esc closes and phase returns; inventory opens/closes with I; craft the guide recipes through the UI with seeded ingredients; unique-name uniqueness; screenshots shop + inventory vs guide (<= 18 / <= 22 mean diff).
4. REVIEW R.13/R.3: hotbar assignment is `EventBus.hotbar_assign_requested(slot, item_id)` (P06's Hotbar consumes it) - no dependency on P06; the spike's _shop/_inventory smoke functions are lifted into tests/sections/shop_ui.gd; shop_ui.csv.import (keep).

**Gate:** Acceptance (6) and (9): inventory open/close, shop buy/sell via UI controls.

#### P22-art-environment - Environment art: iso tiles, ortho forest tiles + wall props, props, crops, buildings, water, effects

*Wave 4 - size L - depends on: P04, P08, P09*

**Owns (exclusive):** `assets/iso_tiles/**`, `assets/iso_props/**`, `assets/backdrops/**`, `lua/config/props_extra.lua`, `tools/art/environment/**`, `tests/sections/art_environment.gd`

**Lift from:** SA/tools/characters/props_traetoppen.py; SA/tools/isometric/{bake_tiles,bake_props,props_sheet,compose_scenes}.py; SA/export/assets/{iso_tiles,iso_props}/** (17 atlases + 56 props already verified in Godot)

**Tasks**

1. Re-run the verified bake (`tools/art/produce_all.sh --only=tiles,props`, ~35 s) and copy to assets/iso_tiles/ (grass, grass_flowers, grass_hyggebyen, grass_hyggebyen_flowers, soil_tilled, soil_watered, path_dirt, deck_farm, deck_hyggebyen, cobble_hyggebyen, forest_floor, forest_floor_glow, void_haze, water_0..3 + tiles.json) and assets/iso_props/ (56 props + props.json + glow halos). Contract: tile 128x76, atlas cell 144x84, periodic 4x4 variants, atlas coords (x%4,y%4), overscan 1.4 px; props PNG with ground-origin pivot, footprint, optional additive glow; Sprite2D centered=false offset=-pivot.
2. DO THIS FIRST (review R.2/R.16: P19 needs the decision): NEW ORTHO MODE in bake_tiles.py (decision section 3.1: Mørkeskoven floor is square): camera azimuth 0, rectangular mask, tile 96x56 (edge 1.1025 m at 87.074 px/m), same periodic canvas trick and seam fixes; terrains forest_floor_o, forest_floor_glow_o, moss_path_o, bog_o (ground_block), cave_floor_o, crystal_floor_o, wall_void_o; saved to assets/iso_tiles/ortho_*.png with tiles.json entries `proj: ortho`. NEW wall props baked at azimuth 0 (props.json `proj: ortho`): forest_wall_a/b/c (dense trunks + dark canopy, 1 cell, tall), cave_wall_a/b, and edge/corner variants - they are y-sorted tiles in the area builder. If ortho baking fails the QA gate in two attempts, ship forest maps with `@projection iso` (the area framework supports both; the maps only change one header and their walls) - record the decision in docs/art.
3. NEW props needed by the blueprint (builders in props_traetoppen.py, recolours of existing models where possible): hyggebyen buildings (house_town_hall, house_bakery with chimney, house_seedshop, house_smithy, house_animalstore, tower_wizard, house_king_treetop) as mushroom-house variants with signs, well, fountain, market_stall, bench, signpost, warp_gate_stone (farm and Hyggebyen forest gate), bed (door mat prop), coop_small, barn_small, animal_house, paw_prints (quest_spot), roof_patch (quest_spot), apple_tree, crops for the 3 new crops (strawberry, sunflower, catnip x4 stages), wheat sack, stone path pieces, beehive stub, lantern_post glow variants. Every new prop gets footprint, pivot, glow where lit, and a gameplay entry (solid shape, strips, interact type) in lua/config/props_extra.lua (this package owns it; top-level config key `props_extra`, read by the area builder next to P04's `props`).
4. Backdrops (acceptance 2 'visible sky'): assets/backdrops/<theme>_sky.webp (gradient sky + soft clouds, farm = warm morning, hyggebyen = lavender dusk, forest = night navy with haze) and <theme>_far.webp (blurred far canopy layer, seamless horizontally) used by the area builder as Parallax2D layers behind the platform (the guide's floating-treetop look); baked/painted by a small Pillow script in tools/art/environment/backdrops.py.
5. Quality gates: `tools/art/environment/compose_scenes.py` Pillow composites (farm, Hyggebyen, forest) viewed as contact sheets (never single frames); Godot screenshot tests/shot_world.tscn --part=farm|hyggebyen|forest|fixtures with real art at Camera zoom 0.4 / 1280x720; no tile seams when mixing grass/grass_flowers and forest_floor/forest_floor_glow; y-sort probe (tests/shot_sort.tscn) with a character walking around house and trees; night grading readable (outline (75,60,73) stays visible on #1c2138); tests/sections/art_environment.gd: every prop id referenced by data/maps/*.map and lua/config/props.lua exists, pivots inside images, tiles.json lists every terrain used by area_tileset, ArtCatalog.missing() empty for the fixtures, props_extra.lua and (once P11 has landed - same wave, so SKIP otherwise) farm and Hyggebyen; the four forest maps are checked by P19.
6. HONEST NOTES: tiles are periodic painted-style heightfield renders (the strongest painted feel), props are soft CG (7/10), Hyggebyen layout 6.5/10, forest grade needs the engine lights not baked darkness, no terrain transition tiles (grass-to-path-to-water edges are hard cuts; mitigation: path_dirt/deck/cobble use overscan and props like bushes/rocks hide joins), no seasonal tile sets (season handled by tint), water animation is 4-frame swap.
7. REVIEW R.1/R.10/R.2: (1) write assets/iso_tiles/ORTHO_DECISION.md (`ortho` or `iso fallback`, date, screenshot names) as soon as the ortho bake passed or failed twice; (2) tile atlases are imported WITHOUT mipmaps (stubs), props/backdrops with mipmaps; (3) platform skirts = props platform_sw/platform_se/platform_corner, 4 water frames as four layers (P04 mechanisms); (4) props_extra.lua lists every blueprint prop id (footprint, solid shape, strips, interact) FIRST so P11/P19 can author against ids; (5) the gate checks farm, Hyggebyen, `_fixture_iso/_fixture_ortho` and the props_extra list - the four forest maps do not exist yet (P19 checks them); (6) windowed `art.forest_ortho_readable`: outline (75,60,73) stays visible on #1c2138 at zoom 0.4.

**Gate:** Real art replaces every placeholder for farm, Hyggebyen and both fixtures; props_extra ids all exist as art; ORTHO_DECISION.md written; windowed seam/filter probe passes.

#### P23-art-icons-keyart - Item icons (~75), title key art, app icon

*Wave 4 - size M - depends on: P07, P08, P12*

**Owns (exclusive):** `assets/icons/**`, `assets/ui/keyart/**`, `icon.svg`, `tools/art/icons/**`, `tests/sections/art_icons.gd`

**Lift from:** SA/tools/characters/icons_traetoppen.py; SA/tools/isometric/{bake_icons,icons_sheet}.py; SA/export/assets/ui/icons/*.webp (60 icons, move to assets/icons/items/); SA/export/ title_1920.png key art draft (6/10)

**Tasks**

1. Bake 128x128 item icons with the pack lighting and ink #2b2340 2 px outline to assets/icons/items/<item_id>.webp (path decision of section 6.2: matches tt_item_icon.gd). The 60 verified icons plus the ones the items need: lantern_oil, health_tonic (rename of health_potion), fertilizer, fairy_dust_water, flour, mushroom_lantern, scarecrow, lantern_post, fence, honey_cake, pickaxe_copper, apple, strawberry/sunflower/catnip seeds + crops, glow_mushroom, iron_ingot, gem_bag, friendship_token, fishing_rod (exists) - exact list = every id in lua/items/*.lua (script `tools/art/icons/missing_icons.py` diffs the Lua item ids against the folder and fails when any id has no icon).
2. Title key art (guide 'Titelskærm': giant tree with the farm in the crown, fairies with lanterns, sunset): rebuild the 6/10 draft with a proper pipeline: baked 3D layers (tree_giant_crown prop 2218x2893, farm platform, house, fairies, lanterns) composed with a painted-style gradient sky plate and parallax foliage layers into assets/ui/keyart/title.webp (1920x1080) + title_layers/ (sky, far foliage, tree, farm, fairies, glow) so the title can parallax slowly; safe-area for the menu panel left, title text top-left. Quality bar: 8/10 before shipping; if not reached after two iterations ship the 6/10 plate and mark it in the risk list.
3. icon.svg: new app icon (acorn/leaf crown on parchment with ink outline). tests/sections/art_icons.gd: every Lua item has an icon file, all icons 128x128 RGBA, key art 1920x1080, ArtCatalog.icon() never returns the badge fallback for shipped items.
4. REVIEW R.2: the item list is the union of lua/items/*.lua after P12 AND the CURRENT ids in lua/items/animals.lua (P20 only fixes descriptions there); tools/art/icons/missing_icons.py reads both. Wave 4 because the item catalogue is final after P12.

**Gate:** Hotbar, backpack and shop show real icons; title screen shows key art.

##### Wave 5

#### P14-npc-dialogue - Npc2D, dialogue flow + DialogueUI, quest book (Opgavebog), intro sequence, all dialogue Lua

*Wave 5 - size L - depends on: P02, P03, P04, P05, P06, P07, P10, P12, P13*

**Owns (exclusive):** `scripts/world2d/npc_2d.gd`, `scripts/world2d/intro_sequence.gd`, `scripts/ui/dialogue_ui.gd`, `scripts/ui/quest_journal.gd`, `scenes/ui/dialogue_ui.tscn`, `scenes/ui/quest_journal.tscn`, `lua/dialogue/**`, `localization/dialogue.csv`, `scripts/npc/**`, `scenes/npc/**`, `tests/sections/npc.gd`

**Lift from:** SW/scripts/world2d/{npc_2d,dialogue_box_2d}.gd; SU/scripts/ui/{dialogue_ui,quest_journal}.gd + scenes; /Users/magnusudbjorg/Documents/projects/PongPong_lift/loose/proto_dialogue_ui.gd proto_npc.gd proto_flow.gd; audit: npcs, lua dialogue

**Tasks**

1. Npc2D (CharacterBody2D layer npc, Interactable2D): `Npc2D.create(marker_params)`; roster data from lua/config/npcs.lua; visual via IsoChibiSprite2D.create (preload idle/walk/talk only), hover NPCs (fairies) glide with the hover clip; wander inside radius on walkable cells (ground units, collision ellipse, no NavigationAgent); day schedule: at night go to home position and sleep clip, guards patrol; `when=` visibility; faces the player and plays talk while talking; prompt 'E · Tal med <name>'. Delete scripts/npc/** (npc_agent, npc_base, npc_spawner) and scenes/npc/npc.tscn.
2. Dialogue flow (the whole chain was broken in the audit): Npc2D.interact() emits dialogue_started, builds the Lua context (world flags + quest_active_<id>/quest_done_<id>/friend_<npc> + hour/day/season), calls LuaRuntime.get_dialogue(id, ctx), then DialogueUI.start_dialogue({name_key, portrait, voice key}, lines, choices) via group `dialogue_ui` and awaits dialogue_finished; choices call npc.handle_choice(action, data): close, quest_accept (+celebrate clip), quest_offer (alias of accept), open_shop, open_journal, show_info, math_answer (re-ask next question), quest_update, give_item (turn-in checks items). dialogue_ended is emitted exactly once on every path (including errors).
3. DialogueUI (guide 'Dialogboks'): parchment box with 150 px portrait frame (portrait.webp of the speaker via tt_portraits), ink name plate, typewriter (Lua ui.dialogue_chars_per_second), E / ui_accept / click completes then advances, choices with ▸ cursor and gold-selected row, hint 'E for at fortsætte', '🔊 dansk stemme' label ONLY when the voice file exists and AudioManager is playing it, Esc closes, GameManager.push_modal("dialogue", false) (phase CUTSCENE), generation counter against overlapping typewriters, mouse always visible.
4. QuestJournal (guide 'Opgavebog'): sidebar tabs 'Aktive · n' / 'Fuldført · m', quest rows with tag colour chips (FIND lavender, HØST moss-light, BYG honey-light, SKOV blue-grey) and giver name from npcs.lua; detail: 96 px giver portrait in gold ring, title, 'Fra <giver> · <location>', description, steps with checkboxes (✓ moss, strikethrough when done), rewards chips (guldagern in Caprasimo, items, rose '♥ <npc>'), and the quest's lua path (`quests/<id>.lua`) at the bottom - everything read straight from the Lua fields through tt_quest_text. J toggles, Esc closes, push_modal("journal").
5. IntroSequence (pitch: 'won the farm in the fairy king's lottery'): on a NEW game the world calls IntroSequence once: Fekongen (fairy_king portrait) letter dialogue from lua/dialogue/fairy_king.lua (context.intro) then QuestManager.accept_quest(intro_lottery); skipped on Continue/Load (flag intro_done).
6. Lua dialogue (lua/dialogue/**): rewrite the 8 files in the guide's tone ('Venlig og lun', short buttons) with the new display names, ADD fairy_king.lua, pippin_boegeknop.lua, cat_morfar_mis.lua, penguin_postman.lua; add quest_accept choices for the 11 previously unreachable quests (audit table), reminder lines while a quest is active, fix the quiz_done early return in baker_maja/fairy_wizard, every line has voice_key voice/<npc_id>/<line_id>; Lily keeps fairy_friendship/flower_necklace/rare_mushroom_hunt (lost_cat moves to Pippin). New texts in localization/dialogue.csv (keys DLG_<NPC>_<LINE>); legacy DIALOGUE_* rows stay as unused until P26 prunes them.
7. tests/sections/npc.gd: teleport next to every roster NPC, press interact, advance to choices, pick the first choice and assert quest accepted/shop opened/phase restored; Esc mid-dialogue ends cleanly; every Lua dialogue branch returns lines+choices whose keys resolve in da+en; portrait exists or falls back; NPCs wander without leaving walkable cells over 60 simulated seconds; night schedule sleeps; intro runs once for New Game and never for Continue; journal shows the Lua fields of lost_cat exactly as the guide screen.
8. REVIEW R.5 (binding): the new Lua dialogue must contain these recorded lines VERBATIM in Danish (canonical wording of docs/voice_lines.md; #9 with "den magiske by"): mayor_lyra/greet_2 "Feernes Konge har udvalgt dig i det årlige lotteri!", mayor_lyra/lottery "Du har vundet en fortryllet trækronsgård! Den venter på dig i skovens kroner.", mayor_lyra/hello "Godt at se dig igen!", mayor_lyra/farm_status "Din gård trives! Fortsæt det gode arbejde.", baker_maja/greet "Hej der! Velkommen til mit lille bageri.", baker_maja/roof_trouble "Åh nej, stormen i går beskadigede mit tag! Kan du hjælpe mig?", baker_maja/thanks "Tak for hjælpen! Taget er som nyt igen.", baker_maja/cookie_talk "Jeg bager de bedste småkager i hele den magiske by.", fairy_lily/greet "Hej... vil du lege?", smith_thorin/greet "Hrmf. Velkommen til smedjen.", smith_thorin/mining_talk "Den mørke skov er fuld af sjældne malmsten... men også farer." (voice_key voice/<npc_id>/<line_id>; P24 supplies the audio from the user's MP3s). Do not keep the lines that name Lyra or Mjau.
9. REVIEW R.14: Npc2D shows a "!" bubble while the NPC offers a quest the player has not accepted (QuestManager.offerable(npc_id)); the dialogue/journal smokes lifted from the spike's ui_smoke (_dialogue, _journal) run against the real managers here (R.3); dialogue.csv.import (keep).

**Gate:** Talk to every NPC, accept and complete lost_cat/cookie_delivery/fix_roof from dialogue alone (scripted test) and see the Opgavebog screen (shot hud/journal).

#### P17-ui-hud - Farm HUD: date/time/weather, guldagern pill, quest card, Energi bar, 10-slot hotbar, toasts, prompt

*Wave 5 - size M - depends on: P02, P06, P07, P13*

**Owns (exclusive):** `scripts/ui/hud.gd`, `scenes/ui/hud.tscn`, `localization/hud.csv`, `tests/sections/hud.gd`

**Lift from:** SU/scripts/ui/hud.gd + scenes/ui/hud.tscn (matches guide: mean diff 8.2)

**Tasks**

1. Adapt the spike HUD to the real event contract (section 3.5/3.10): everything event-driven, no _process polling - date block from TimeManager.date_text() ('Tirsdag 16. Blomstermåned') + clock in Caprasimo + weather label (UI_WEATHER_*), gold pill with thousands separator ('1.250 guldagern'), active-quest card (max 3, title + current objective 'Spor fundet: 2 / 3' via QuestManager.get_tracked/get_objective_text, hidden when empty, HUD_ACTIVE_QUESTS localized), vertical Energi bar from player_stats_changed(stamina), hearts bar only when hurt, hotbar from EventBus.hotbar_changed(entries, selected) with icons from ArtCatalog.icon (initial badge fallback), key numbers 1..0, counts in Caprasimo, selected slot gold ring + tool name above (Vandkande), notification toasts (item gains stack, quest accepted/complete), interaction prompt pill from interaction_prompt_changed, language change refresh. Slot click selects via the player API.
2. Mode switch: GameUI.set_mode(&"action") hides this HUD (forest_hud from P19 shows); GameManager phase CUTSCENE/PAUSED never hides the HUD.
3. tests/sections/hud.gd: values after gold/time/day/season/stat/quest/hotbar signals, the 4 season month names, no raw keys, hotbar 10 slots with selected ring after slot_n actions, toast count caps, screenshot checkpoint hud (compare with guide: mean diff <= 9).
4. REVIEW R.12/R.14: (1) a 5-heart PanelHearts row is ALWAYS visible under the gold pill (guide extension so acceptance item 3 'health bar' holds; flagged in the QA report); (2) every HUD control has focus_mode = FOCUS_NONE; (3) hud.date_text_real_keys asserts "Tirsdag 16. Blomstermåned"/"Tuesday 16. Month of Blooms" with the REAL loaded keys; (4) the spike's _hud smoke is lifted into tests/sections/hud.gd (R.3); the hud diff is a windowed check.

**Gate:** Farm HUD screenshot matches the guide's 'HUD på gården'; all acceptance item (3) elements verified by assertion.

#### P19-forest-combat - Mørkeskoven: forest maps (ortho), enemies and boss, loot, resource nodes, minimap, forest HUD

*Wave 5 - size L - depends on: P04, P05, P06, P07, P10, P12, P13, P22*

**Owns (exclusive):** `scripts/world2d/enemy_2d.gd`, `scripts/world2d/loot_drop_2d.gd`, `scripts/world2d/resource_node_2d.gd`, `scripts/world2d/whisper_zone.gd`, `scripts/world2d/minimap_2d.gd`, `scripts/ui/forest_hud.gd`, `scenes/ui/forest_hud.tscn`, `data/maps/skovkant.map`, `data/maps/dybe_bregner.map`, `data/maps/svampelunden.map`, `data/maps/krystalgrotten.map`, `lua/config/enemies.lua`, `lua/config/resource_nodes.lua`, `localization/forest.csv`, `scripts/world/crystal_cave.gd`, `scripts/world/dark_forest_zone.gd`, `scripts/world/dark_forest.gd`, `scripts/world/enemy.gd`, `scripts/world/mushroom_grove.gd`, `scripts/world/resource_node_interactable.gd`, `scenes/forest/**`, `tests/sections/forest.gd`

**Lift from:** SW/scripts/world2d/{enemy_2d,loot_drop_2d,resource_node_2d,whisper_zone,minimap_2d}.gd; SW/data/maps/forest.map (seed for skovkant); SW/lua/config/enemies.lua; SU/scripts/ui/forest_hud.gd + scenes/ui/forest_hud.tscn; SW/tests/playtest_world.gd _test_forest; old 3D scripts as GAME LOGIC reference: NODE_TYPES, GEM_TYPES, mushroom types, spawn rules

**Tasks**

1. Enemy2D data-driven from lua/config/enemies.lua (id -> visual, hp, speed, detect, damage_half_hearts, behavior, loot table {item,chance,min,max}, flying/altitude; NO per-enemy sprite scale - sizes come from the art/display_scale; spike distances x 1/0.6 per section 3.13 e.g. bat speed 175, detect 550): behaviours chase_lunge (bat, ugleoje: idle->chase->windup 0.5 s cream pulse->lunge->recover), stationary (tornebusk: contact damage, destructible, drops thorn items), flee (lysesvamp: glow critter that runs, drops glow_mushroom), boss_spin (snurresvamp: telegraphed chase + spin dash using the `spin` clip, 18 hp, bar name BOSS_SNURRESVAMPEN, drops chest with moonstone/amethyst/rare_mushroom). Hit feedback: pink flash, knockback, no red anywhere; emits EventBus.enemy_defeated(id, kind, loot) and boss_bar_changed. The pack bat stays as the normal flier; the boss uses the baked snurresvamp (P21) - until it lands, characters.lua gives it the capybara as fallback (the bat is never scaled up as a boss: its side rows are edge-on).
2. ResourceNode2D data-driven from lua/config/resource_nodes.lua (converted from the 3D NODE_TYPES/GEM_TYPES/mushroom tables): iron/copper/gold ore (pickaxe power gates), amethyst/moonstone/emerald crystals (glow), glowing/rare mushrooms, moss_patch, fern, apple_tree (farm orchard, daily respawn), per-node hp/yield/rare table; self-contained (no manager group lookup = the hit_node crash), depleted state persisted per area in GameManager world flags with ore_respawn_days, loot via LootDrop2D orbs picked up into EconomyManager (item_gained -> loot feed). WhisperZone: 'Noget rasler i bregnerne…' style text via EventBus.whisper_requested.
3. Maps (ortho, @projection ortho, ambient forest/cave): skovkant (depth 1, 40x26: farm gate + Hyggebyen gate warps, 3 bats, 2 tornebusk, mushrooms, Oak's patrol, whispers), dybe_bregner (depth 2, 56x40: ferns, ugleoje x3, glowing path, boss clearing with Snurresvampen, chest, quest_spot for Morfar Mis (when=quest:lost_cat) and moonstone crystal), svampelunden (depth 2, 32x24: lysesvamp, mushroom nodes), krystalgrotten (depth 3, 40x28: crystals, ore nodes, cave walls, no sky; ambient cave). `@title`, `@depth` (shown on the minimap chip as 'Dybe Bregner · 2'), warps per blueprint 4.3, spawns from_farm/from_hyggebyen/from_dybe etc., flood-fill reachability of every warp and every resource node.
4. Minimap2D (1 px per cell ImageTexture, round via clip_children, gold/ink ring drawn with draw_arc, player/enemy/boss/warp dots) and ForestHUD adapted to the final EventBus contract (player_health_changed -> TTHearts with half hearts and pink/pale-pink/slate colours, player_oil_changed -> Lygteolie pill, boss_bar_changed -> thorn-berry bar with gold ring and name, whisper_requested -> teal whisper box, notification icon item -> loot feed with fade, area_changed -> zone chip + minimap, ability slots slag/undvig/fe-lys/drik with keys read from the InputMap and cooldown veils from Player2D.cd_ratio). Hide in iso mode (GameUI.set_mode).
5. Delete the 3D forest files after extracting their data: scripts/world/{crystal_cave,dark_forest_zone,dark_forest,enemy,mushroom_grove,resource_node_interactable}.gd and scenes/forest/dark_forest.tscn. localization/forest.csv: BOSS_*, WHISPER_*, ABILITY_*, ENEMY_*, area/zone chips, loot feed strings.
6. tests/sections/forest.gd: port the spike's forest checks (melee arc hits only inside arc, dodge i-frames, half-heart damage + pink flash + hit clip, drink, fe-lys stun, chase AI reaches and hurts, loot + kill, resource node, boss bar, oil drains, faint -> back on the farm with full hearts) and add: every enemy kind from enemies.lua spawns and dies, boss full fight with seeded RNG, 4 maps parse + connectivity + each warp round-trips, depleted node respawns after N days, enemy_defeated drives a quest objective, minimap texture non-empty, forest HUD hides farm HUD, TimeManager paused in forest, no enemy damages during dodge i-frames. Screenshots forest_01..09 (tests/shot_world.tscn --part=forest).
7. REVIEW R.2/R.16: before authoring maps read assets/iso_tiles/ORTHO_DECISION.md (P22, earlier wave): if it says `iso fallback`, set `@projection iso` and the wall chars in the four maps (this package owns them); add `forest.maps_art_complete` (ArtCatalog.missing() empty for the four maps when assets exist) - the forest map art check was wrongly in P22's gate; the spike's _forest smoke is lifted into tests/sections/forest.gd; the forest HUD diff is windowed.

**Gate:** Acceptance (11) for dark forest, crystal cave and mushroom grove; screenshot compare with the guide's 'Mørkeskoven HUD' (<= 15 mean diff).

#### P20-animals-buildings - Farm animals (2D), buildings and placeables, animal care and build menu screens

*Wave 5 - size L - depends on: P04, P05, P06, P07, P12, P13*

**Owns (exclusive):** `scripts/farm/animal_husbandry.gd`, `scripts/farm/animal_2d.gd`, `scripts/farm/placement_service.gd`, `scripts/farm/farm_animal.gd`, `scripts/farm/building_placer.gd`, `scripts/ui/animal_care_ui.gd`, `scripts/ui/build_menu_ui.gd`, `scenes/ui/animal_care_ui.tscn`, `scenes/ui/build_menu_ui.tscn`, `lua/items/animals.lua`, `localization/animals.csv`, `tests/sections/animals.gd`

**Lift from:** /Users/magnusudbjorg/Documents/projects/PongPong_lift/loose/farm_animal_fixed2.gd animal_spawner.gd build_menu_fixed.gd farm_animal.tscn (verified logic); /Users/magnusudbjorg/Documents/projects/PongPong_lift/loose/logic.gd (husbandry rules); audit: animals, farming/building

**Tasks**

1. AnimalHusbandry (autoload) fixes from the audit: absolute day_counter (GameManager.day is day-of-season: production stalled after season change), product intervals mapped from the enum (DAILY=1, EVERY_2=2, EVERY_3=3, ON_BOND awarded at bond level-up not by timer), reset() on new_game_started, buildings keep a position, build_building(type, free) emits EventBus.building_built, capacity required (an animal needs a coop/barn/house; existing unhoused animals move into a new building), adopt on EventBus.item_purchased/inventory use for baby_* items (adopt_animal removes the item), emits animal_adopted/animal_fed/animal_product_collected on EventBus, collect_product respects add_item() result, play cooldown, species labels via SPECIES_DATA name_key, to_dict/from_dict complete.
2. Animal2D (CharacterBody2D, layer interactable): visual = IsoChibiSprite2D.create(species visual from lua/config/characters.lua: chick/hen, bunny, duck, kitten, puppy, lamb, calf (cow), fawn, fox_cub, owl) with baby/adult scale; wanders inside the farm map's `animal_yard` marker radius (horizontal arrival test + velocity zeroed - the audit's glide bug), '!' bubble when a product is ready, E opens AnimalCareUI preselected; WorldRoot2D asks `animal_yard` handler (registered by this package's script path) to respawn nodes from AnimalHusbandry state on enter/load.
3. PlacementService (replaces building_placer.gd): places coop/barn/house at the map's `building_slot` markers using ArtCatalog props (coop_small, barn_small, animal_house from P22; fallback boxes), and `placeable` items (scarecrow, lantern_post, fence_x/z) on the targeted free iso cell, persisted in WorldRoot2D.to_dict placed list; build menu shows cost (wood/stone/gold) and capacity.
4. AnimalCareUI and BuildMenuUI scenes in the parchment theme (PanelParchmentL24 + RowButton lists, ItemList replacement), same unique names the scripts declare (%AnimalList %NameLabel %SpeciesLabel %BondLabel %HappinessBar %HungerBar -> 'Fylde' %FoodOption %FeedButton %BrushButton %PlayButton %CollectButton %RenameButton %CloseButton; %BuildingList %CostLabel %CapacityLabel %BuildButton %CloseButton), process_mode ALWAYS, push_modal, open on B (build_menu action) and on animal interact; fix ItemList.selected -> select(0), auto-select first animal, food filtered by species feed_types, rename dialog freed on cancel and updates the label. Delete farm_animal.gd and building_placer.gd.
5. lua/items/animals.lua: baby_* defs (descriptions incl. the malformed fawn row now in animals.csv), animal_feed, brush, milking pail; kits removed. tests/sections/animals.gd: buy baby_chick at Rosa -> adopted -> node spawned on the farm -> feed -> next day product -> collect -> inventory + quest signals (first_animal/animal_products objectives), season rollover keeps production, save/load restores animals and buildings, placeables persist, full inventory keeps the product.
6. REVIEW R.4: animals.csv owns ITEM_BABY_*, ITEM_<SPECIES>, BUILDING_*, ANIMAL_* incl. the malformed ITEM_BABY_FAWN_DESC (the barn/coop kits are removed, so ITEM_BARN_KIT_DESC disappears) - none of these may also be defined by core.csv or economy.csv; animals.csv.import (keep).

**Gate:** Acceptance (10): animals can be bought, fed and collected; buildings visible; save round trip.

##### Wave 6

#### P24-audio-voice - Danish voice: macOS `say` placeholder generator, playback wiring, SFX hooks, audio buses

*Wave 6 - size M - depends on: P12, P13, P14, P16, P20*

**Owns (exclusive):** `scripts/autoload/audio_manager.gd`, `tools/voice/**`, `assets/audio/**`, `docs/audio/*.mp3`, `docs/voice_lines.md`, `tests/sections/voice.gd`

**Lift from:** /Users/magnusudbjorg/Documents/projects/PongPong_lift/voice_probe (verified: `say -v Sara` da_DK -> ffmpeg libvorbis ogg, 38 KB for 4.7 s); existing 14 user MP3s in docs/audio (7 s ... 2 s, mono 44.1 kHz)

**Tasks**

1. INVESTIGATION RESULT (verified on this Mac): exactly ONE Danish system voice exists, `Sara` (da_DK); ffmpeg has libvorbis, `afconvert` is available. Pipeline `say -v Sara -r <wpm> -o x.aiff "<text>"` -> `ffmpeg -ac 1 -ar 44100 [-af asetrate/atempo for per-NPC pitch] -c:a libvorbis -q:a 4 x.ogg` (about 8 KB per second of speech). No second Danish voice: character separation is faked with pitch/rate per speaker from lua/config/npcs.lua `voice = {pitch, rate}` (fairies +12%, king -8%, guard -15%, mouse +20%), honestly a placeholder.
2. tools/voice/generate_voice.py: walks lua/dialogue/*.lua for every line {text_key, voice_key}, looks up the Danish text in ALL localization/*.csv (override order of the runtime loader), generates assets/audio/voice/<npc_id>/<line_id>.ogg, idempotent (hash of text+voice params in a sidecar manifest assets/audio/voice/manifest.json), SKIPS any file listed in assets/audio/voice/RECORDED.txt (human recordings always win), reports lines without text, prints total size (about 90-130 lines, ~6-9 MB). `--only npc_id`, `--dry-run`, `--voice Sara`.
3. REVIEW R.5 (replaces the old 'archive and do not wire' decision): ASR (faster-whisper small, Danish) over the 14 MP3s in sorted-filename order matches the 14 lines of docs/voice_lines.md (durations 7.0/4.2/5.8/2.1/4.3/3.5/5.3/3.7/4.8/2.4/5.1/3.7/2.8/5.5 s). Convert files 2-10, 13, 14 (`ffmpeg -ac 1 -ar 44100 -c:a libvorbis -q:a 4`) to assets/audio/voice/<npc_id>/<line_id>.ogg for mayor_lyra/greet_2, lottery, hello, farm_status, baker_maja/greet, roof_trouble, thanks, cookie_talk, fairy_lily/greet, smith_thorin/greet, mining_talk (the P14 dialogue carries exactly that text), list them in assets/audio/voice/RECORDED.txt, and archive ALL 14 originals under assets/audio/voice/_user_recordings_v0/ with a README (1, 11, 12 name Lyra/Mjau and are unused). Ask the user once to confirm by listening. The generator synthesises only the other lines.
4. AudioManager: single play_voice(voice_key) (key is already the path below res://assets/audio/, no double prefix), stops the previous voice on advance/close, Voice bus volume from settings, `voice_exists(key)` used by DialogueUI for the '🔊 dansk stemme' label, voice only plays when locale is da (English text is not read in Danish), buses Master/Music/SFX/Voice created idempotently, volume persistence (user://settings.cfg [audio], shared load-modify-save with P03/P16), SFX hooks connected to EventBus (crop_harvested, gold_changed delta>0, quest_accepted/completed, item_gained, player damaged, enemy_defeated, ui toggles), music slots kept but music is CUT (no assets, no budget) - missing files are silent, never errors. Optional placeholder SFX via ffmpeg lavfi synth in tools/voice/make_sfx.sh (soft pops/chimes, 12 files) - small, can be skipped.
5. docs/voice_lines.md: rewrite as the voice pipeline guide (how to record real lines: mono 44.1 kHz OGG, -1 dBFS, naming, RECORDED.txt, how to re-run the generator when copy changes). tests/sections/voice.gd: every Lua dialogue line with a voice_key has an ogg (or is listed as missing), keys have no double prefix, play_voice on a missing key is silent, locale en does not play voice, voice stops when dialogue closes.
6. REVIEW R.14/R.17: audio_manager.gd: Array[AudioStreamPlayer3D] -> 2D/plain AudioStreamPlayer; tests voice.recorded_lines_match_text and voice.manifest_in_sync (text hash of every voiced key equals manifest.json).

**Gate:** Every dialogue line speaks Danish (placeholder voice) and the dialogue UI shows the voice label.

#### P25-docs-refresh - README, design doc, Lua API reference, how-to guides (quest, NPC, item, recipe, enemy, map), art docs

*Wave 6 - size M - depends on: P12, P13, P14, P16, P17, P18, P19, P20, P21, P22*

**Owns (exclusive):** `README.md`, `docs/game_design.md`, `docs/lua_api.md`, `docs/howto/**`, `docs/art/*.md`, `docs/Trætoppen Style Guide Review/*.html`, `docs/Trætoppen Style Guide Review/*.js`, `docs/Trætoppen Style Guide Review/.thumbnail`, `docs/Trætoppen Style Guide Review/refs/*.jpg`, `docs/Trætoppen Style Guide Review/uploads/*.jpg`, `tests/sections/docs.gd`

**Lift from:** /Users/magnusudbjorg/Documents/projects/PongPong_lift/lua_audit (supported-subset findings); this PLAN sections 3, 4, 6

**Tasks**

1. README.md (Danish first, English second): Trætoppen pitch, requirements (Godot 4.7.2, Python 3.12 only for art), first run (`godot --headless --path . --import` twice on a fresh clone because the theme loads before fonts the first time), controls table (WASD, Shift, Space, E, 1..0, LMB, Q, R, F, I, J, B, Esc, wheel zoom), repo map, test commands (`tests/run_playtest.sh --character=fairy`), screenshot drivers, export notes (include filter `data/*,lua/*,localization/*.csv,assets/audio/*`), credits for fonts (OFL).
2. docs/lua_api.md rewrite to match the engine as built: directory kinds (config, items, quests, dialogue, recipes, shops), the SUPPORTED LUA SUBSET (one `if cond then ... end` per branch with newline after `then`, literal-only returned tables, locals from `context.x or false`, api.add_gold/add_item/remove_item/set_flag/get_flag/has_flag/has_item/get_gold/notification/unlock_zone/emit/log/offer_quest/complete_quest), the objective `on=` vocabulary, dialogue choice actions (close, quest_accept, quest_offer alias, open_shop, open_journal, show_info, math_answer, quest_update, give_item), item categories (all 16+), config tables, recipes, shops, enemies, resource_nodes, npcs, characters, ambient, props, hot reload (F9 debug), lint output. Remove everything the engine does not do (documented-but-never-dispatched events).
3. docs/howto/: add_a_quest.md WITH A COMPLETE WORKED EXAMPLE (the plan's section 7 example `sneglens_brev`: lua/quests/sneglens_brev.lua + dialogue accept choice + 6 CSV rows + objective bindings + test line), add_an_npc.md, add_an_item_and_recipe.md, add_a_shop.md, add_an_enemy.md, add_a_map.md (ASCII format, markers), add_a_character_with_the_generator.md (builder recipe + bake + validate + characters.lua), voice.md. docs/game_design.md rewritten for 2D (pillars unchanged, camera, zones, perks, economy numbers, progression with the guide's quests). docs/art/*.md: pipeline summary pointing at tools/art/README.md and the honest quality notes. `docs/Trætoppen Style Guide Review/**` stays untouched (design source of truth).
4. tests/sections/docs.gd: every file path mentioned in README/howto exists, every code block in add_a_quest.md that is Lua passes the LuaRuntime lint, every CSV key mentioned resolves after copying the example into a temp project.

**Gate:** A newcomer can add a quest by following docs/howto/add_a_quest.md only (verified by the test).

#### P26-loc-final - Finalize localization: prune legacy da.csv, strict key coverage, da/en audit

*Wave 6 - size S - depends on: P03, P12, P13, P14, P16, P17, P18, P19, P20*

**Owns (exclusive):** `localization/da.csv`, `localization/zz_final.csv`

**Lift from:** tools/loc/prune_legacy.py (P03)

**Tasks**

1. Run `python tools/loc/prune_legacy.py` against the final tree: remove from localization/da.csv every key that is (a) overridden by another csv file or (b) referenced nowhere (3D-era DIALOGUE_*/old OBJ_*/old NPC_* rows), fix/delete the malformed colon rows and the duplicate rows; keep only still-referenced legacy rows; review the diff by eye for Danish quality (hoe vs pickaxe names, 'Rustent sværd', 'Fekongens lotteri', male/female noun for Rosa).
2. `godot --headless --path . -s res://tests/loc_check.gd -- --strict` must exit 0 (no misses, no malformed rows, no duplicates, every key has da AND en), and a screen sweep (tests/sections/menus.gd + hud + shop_ui + npc) reports zero raw keys in both locales.
3. Danish copy pass: read every da string for the guide's tone ('Venlig og lun', short buttons: Køb, Sælg, Lav, Tilbage; Mørkeskoven hvisker), correct English column.
4. REVIEW R.17: the Danish copy pass writes localization/zz_final.csv (+ keep-import), the only file that may override keys of other files; it must NOT change a voiced key (text_key of any lua/dialogue line with a voice_key); loc_check --strict compares voiced-key hashes with assets/audio/voice/manifest.json when it exists.

**Gate:** loc_check --strict is green.

##### Wave 7

#### P27-qa-acceptance - Acceptance scenario for items 1-13, screenshot checkpoints, final QA report

*Wave 7 - size M - depends on: P09, P16, P17, P18, P19, P20, P21, P22, P23, P24, P25, P26*

**Owns (exclusive):** `tests/sections/zz_acceptance.gd`, `docs/qa/**`, `tests/checkpoints/*.gd`

**Lift from:** PLAN section 8 matrix

**Tasks**

1. tests/sections/zz_acceptance.gd (runs last): one linear playthrough per character (animal+Ræv, fairy, hobbit) covering acceptance items 1-13 exactly as the matrix in section 8 (launch -> menu -> New Game -> select -> confirm -> world: zero engine errors; movement/jump/run/stamina; HUD elements; time/day/season progress; Esc pause resume/save/load/main menu/quit with the cursor visible in every state; I and J open/close; till/plant/water/4 days/harvest -> inventory; talk to NPCs and complete a Lua quest from dialogue alone; shop buy/sell; buy/feed/collect an animal; enter farm, Hyggebyen, Mørkeskoven, Svampelunden, Krystalgrotten with triggers, enemies, resource nodes; save/load + Continue; da/en switch with no raw keys), total runtime < 6 min per character headless.
2. tests/checkpoints/*.gd: screenshot checkpoint scripts (non-headless, user-run) that write PNGs for the guide screens (title, select page 1/2, farm HUD, shop, quest book, backpack+workshop, dialogue, forest HUD, pause, settings, save/load) and for world views (farm morning/dusk/night/rain, Hyggebyen, each forest map, boss fight) into a folder; the compare helper tests/checkpoints/compare_guide.py (P07, reference PNGs in tests/checkpoints/guide_ref/) prints mean abs diff per screen (target: title <= 8, HUD <= 9, journal <= 12, forest HUD <= 15, select <= 15, shop <= 18, inventory <= 22 - the UI spike's numbers; real art should lower them).
3. docs/qa/QA_REPORT.md: results of the acceptance run for all 3 characters, ArtCatalog.missing() == [], lint clean, perf numbers (tests/perf_world.tscn: 100 characters < 8 ms/frame Compatibility on Apple M3), VRAM budget, list of known visual issues with screenshots, final cut/stub list status. Anything failing is filed back to the owning package id, not fixed here.
4. REVIEW R.6/R.12/R.15: P27 runs the windowed suite once per character (`tests/run_playtest.sh --windowed`) and records: render_not_blank, filter seams, guide diffs, hearts-row deviation, cursor-visible deviation, voice.manifest_in_sync, ArtCatalog.missing()==[] for all 6 maps.

**Gate:** Acceptance run green for 3 characters; QA report written with screenshots.


### 7.4 Worked example: adding a quest with Lua only (P25 turns this into `docs/howto/add_a_quest.md`; its test copies it into a temp project)

Quest: *Sneglens brev* - the postman penguin asks you to bring a letter to Bagerfe Rosmarin.

`lua/quests/sneglens_brev.lua`
```lua
-- quests/sneglens_brev.lua
kind = "quest"
id = "sneglens_brev"

meta = { giver = "penguin_postman", location = "ZONE_CITY", tag = "FIND", category = "errand", repeatable = false }

objectives = {
  { id = "talk_to_baker", target = 1, on = "dialogue_started", npc = "baker_maja", description_key = "OBJ_SNEGLENS_BREV_TALK_TO_BAKER" },
}

rewards = { gold = 80, items = { honey = 1 }, friendship = { penguin_postman = 1 } }
```
`lua/dialogue/penguin_postman.lua` (only the accept branch is new; the interpreter supports one `if ... then return {...} end` per branch)
```lua
function get_dialogue(context)
  local done = context.quest_done_sneglens_brev or false
  local active = context.quest_active_sneglens_brev or false
  if done then
    return { speaker = "penguin_postman", speaker_name_key = "NPC_PENGUIN_POSTMAN",
      lines = { { id = "thanks", text_key = "DLG_POSTMAN_THANKS", voice_key = "voice/penguin_postman/thanks" } },
      choices = { { id = "bye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" } } }
  end
  if active then
    return { speaker = "penguin_postman", speaker_name_key = "NPC_PENGUIN_POSTMAN",
      lines = { { id = "reminder", text_key = "DLG_POSTMAN_REMINDER", voice_key = "voice/penguin_postman/reminder" } },
      choices = { { id = "bye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" } } }
  end
  return { speaker = "penguin_postman", speaker_name_key = "NPC_PENGUIN_POSTMAN",
    lines = { { id = "offer", text_key = "DLG_POSTMAN_OFFER", voice_key = "voice/penguin_postman/offer" } },
    choices = { { id = "accept", text_key = "DLG_POSTMAN_ACCEPT", action = "quest_accept", quest_id = "sneglens_brev" },
                { id = "bye", text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" } } }
end
```
`localization/<yourfile>.csv` (6 rows, da + en): `QUEST_SNEGLENS_BREV_TITLE`, `QUEST_SNEGLENS_BREV_DESC`, `OBJ_SNEGLENS_BREV_TALK_TO_BAKER`, `DLG_POSTMAN_OFFER`, `DLG_POSTMAN_REMINDER`, `DLG_POSTMAN_THANKS`, `DLG_POSTMAN_ACCEPT`. Then: `python tools/voice/generate_voice.py --only penguin_postman` (placeholder voice), `godot --headless --path . -s res://tests/loc_check.gd`, `tests/run_playtest.sh --only=quests` (the table-driven test completes any quest it finds, no test edit). The book, tracker, toast, rewards and save/load need no code.



## 8. Test plan

### 8.1 Harness (P09) and conventions

`tests/playtest.gd` is only the harness (windowed mode: `--windowed` runs the `run_windowed(t)` functions of the sections with a real window and automated pixel assertions, R.6; Logger capture of engine **and** script errors/warnings - any one fails the run; real `main_menu.tscn -> character_select.tscn -> world.tscn` boot; helpers `expect`, `frames`, `seconds`, `press(unique_path)`, `tap(action)` using `InputEventAction` pairs, `await physics_frame` for anything driven by `_physics_process`, `Input.action_press` for held keys, autoloads via `root.get_node`). It auto-discovers `tests/sections/*.gd` (alphabetical; `zz_acceptance` last), `--only=a,b`, `--list`, `--character=animal|fairy|hobbit`. Run: `tests/run_playtest.sh --character=fairy [--only=farm,forest]` (exit code != 0 on any failed check or engine error; ~45 s per character for the first full set (end of wave 4), < 6 min for everything). Saves are written to a throwaway `HOME`/user dir so the real `user://` is never touched. `tests/loc_check.gd [-- --strict]` and `ui_smoke.tscn` run standalone too. Non-headless screenshot drivers (user-run) are listed in 8.4. **Negative test:** an injected engine error must make the run fail. The check names used in 8.2 and 8.5 are the required names (`<section>.<check>`), so reviewers can grep for them.

Section files and what they own: `core`(P02) `loc`(P03) `area`(P04) `characters`(P05) `player`+`farm`(P06) `ui_foundation`(P07) `data`(P10) `maps_iso`(P11) `economy`(P12) `quests`(P13) `npc`(P14) `save`(P15) `menus`(P16) `hud`(P17) `shop_ui`(P18) `forest`(P19) `animals`(P20) `art_characters`(P21) `art_environment`(P22) `art_icons`(P23) `voice`(P24) `docs`(P25) `zz_acceptance`(P27).

### 8.2 Acceptance matrix (every item has at least one automated check and, where visual, one screenshot)

| # | Acceptance item | Automated checks (section.check) | Screenshot |
|---|---|---|---|
| 1 | launch -> main menu -> New Game -> select (animal/fairy/hobbit) -> confirm -> world with ZERO engine errors | `menus.new_game_flow` x3 races x each species chip; `zz_acceptance.boot` (Logger sees 0 errors AND 0 warnings) | title, select_1, select_2 |
| 2 | lit ground/sky, visible player, camera follows, WASD relative to camera (screen), mouse aim, jump, run, stamina | headless: `player.sprite_visible` (visible Sprite2D with texture), `player.camera_follows`, `player.screen_relative_wasd` (W moves up on screen in iso and ortho; ground speed equal in all 8 directions), `player.hop`, `player.run_and_stamina` (drain, hysteresis at 0, regen), `player.aim_uses_mouse_after_motion`; **windowed (R.6)**: `area.render_not_blank` (ground, sky, player pixels), `area.filter_seams`, `player.sprite_visible_pixels` | farm_01 |
| 3 | HUD: gold, time, day, season, health/stamina, notifications, prompt, quest tracker | `hud.values_after_signals`, `hud.hotbar_ten_slots`, `hud.toast`, `hud.prompt`, `hud.quest_card`, `hud.hearts_row_always_visible` (guide extension, R.12), `hud.date_text_real_keys`, `hud.no_raw_keys` | hud_farm (windowed diff <= 9 vs guide) |
| 4 | time/day/season progress | `core.calendar_names`, `core.advance_time_multiday`, `hud.clock_updates`, `zz_acceptance.three_days_pass` | farm dawn/dusk/night |
| 5 | Esc pause: resume/save/load/main menu/quit; "mouse mode toggles" = cursor stays visible (2D has no mouse capture; deviation stated in the QA report) | `core.modal_stack`, `menus.pause_resume_on_second_esc`, `menus.pause_save_load_roundtrip`, `menus.quit_to_menu_is_live`, `menus.cursor_always_visible` (mouse_mode == VISIBLE in every phase) | pause |
| 6 | inventory (I) and quest journal (J) open and close | `shop_ui.inventory_toggle_i_tab`, `npc.journal_toggle_j`, `menus.esc_closes_top_modal` | backpack, quest_book |
| 7 | farming loop: plots exist, till/plant/water/harvest, crops grow over days, harvest to inventory | `farm.loop_all_crops` (each of the 7 crops), `farm.rain_waters`, `farm.season_gate`, `farm.fertilizer`, `farm.harvest_full_inventory_keeps_plot` | farm_02..04 |
| 8 | NPCs in the city, talk via dialogue UI, dialogue/quests come from Lua and progress | `npc.talk_every_roster_npc`, `npc.quest_from_dialogue_lost_cat_cookie_roof`, `quests.every_quest_completable_by_events`, `quests.lint_clean`, `npc.intro_once` | dialogue, quest_book |
| 9 | shop buy/sell works | `economy.listed_equals_charged`, `shop_ui.buy_sell_through_controls`, `shop_ui.hobbit_discount`, `shop_ui.too_dear_styling` | shop (diff <= 18) |
| 10 | farm animals bought/fed/collected | `animals.buy_adopt_spawn_feed_collect`, `animals.season_rollover`, `animals.save_roundtrip`, `animals.build_coop_visible` | animals |
| 11 | zones with triggers, enemies, resource nodes | `maps_iso.connectivity`, `forest.maps_parse_and_connect`, `forest.maps_art_complete`, `forest.every_enemy_kind`, `forest.boss_fight`, `forest.nodes_loot_respawn`, `area.warp_roundtrips`, `forest.oil_and_faint`; windowed `art.forest_ortho_readable` | forest_01..09 |
| 12 | save/load round-trips; Continue works | `save.roundtrip_all_systems`, `save.continue_from_menu`, `save.corrupt_and_foreign_saves`, `save.autosave_never_overwrites_manual` | save_load |
| 13 | da/en switch; no raw translation KEYS on screen | `loc.switch_runtime`, `loc_check --strict`, `menus.no_raw_keys_all_screens_both_locales`, per-screen sweeps in hud/shop_ui/npc/forest | title_english |

### 8.3 Guide screens: each must render without errors, without raw keys, and meet its diff target (the diff itself is a **windowed** check using `tests/checkpoints/compare_guide.py` + `tests/checkpoints/guide_ref/*.png`, owned by P07, so waves 4-5 can use it)

Mean absolute pixel difference of a 1280x720 Godot capture against the Playwright render of the HTML guide (`tests/checkpoints/compare_guide.py`; UI-spike baselines in brackets; real art should lower them): title <= 8 (7.5), farm HUD <= 9 (8.2), quest book <= 12 (11.3), forest HUD <= 15 (14.5), Vælg figur <= 15 (14.7), shop <= 18 (17.5), backpack+workshop <= 22 (21.9). Dialogue, pause, settings, save/load and the confirm dialog have no HTML reference: looked at only (checked by the builder and listed in the QA report). Each screen also has a **render-without-errors** check in its section (instantiate, show, drive 2-3 interactions, hide) and an English-locale pass.

### 8.4 Screenshot checkpoints (non-headless, ~1 s window each, run by a human or the QA package; output folder is passed with `-- --out=DIR`)

`godot --path . res://tests/shot_world.tscn -- --part=farm|hyggebyen|forest|fixtures|cast|hud --character=animal|fairy|hobbit --out=DIR`, `shot_sort.tscn`, `shot_flight.tscn`, `perf_world.tscn -- --tag=x [--quick]`, `tests/checkpoints/*.gd` for UI screens. Required checkpoint list (P27 collects them in `docs/qa`): title, select page 1 and 2 (each race), farm morning/dusk/night/rain, farm with all 4 crop stages, tool swing, target marker, flight over water, Hyggebyen day/night, shop, quest book, backpack+workshop, dialogue with portrait, forest edge, mushroom grove, crystal cave, forest damage (pink), boss fight, loot feed, pause, settings, save/load, animals + coop, cast line-up next to the pack.

### 8.5 Regression tests for the audited defects (each audit blocker/major has a named check)

Pause cannot resume (`menus.pause_resume_on_second_esc`); invisible hero/skin ignored (`player.sprite_visible` after New Game and after Continue); quit-to-menu leaves tree paused (`menus.quit_to_menu_is_live`); language button 5 errors (`menus.language_switch_no_errors`); New Game keeps old gold/quests (`core.new_game_resets_all`); intro quest objectives never advance and 17 quests uncompletable (`quests.every_quest_completable_by_events`); dialogue choices never shown (`npc.talk_every_roster_npc`); shop price mismatch (`economy.listed_equals_charged`); 0-gold stone and unsellable tokens (`economy.sell_min_one`); `hit_node` group crash (`forest.nodes_loot_respawn` without any manager group); enemy death tween error (`forest.every_enemy_kind`); double `zone_entered` (`core.unlock_zone_signals`); animal product stall after season change (`animals.season_rollover`); autosave destroys slot 0 (`save.autosave_never_overwrites_manual`); save drops farm/animals (`save.roundtrip_all_systems`); malformed CSV rows / duplicate keys (`loc_check`); `ItemList.selected` crash (`animals.build_menu_opens`); wander glide (`animals.wander_stops`); NPCs never move (`npc.wander_stays_walkable`); double sort of big buildings (`area.strips_sort`); fairy shadow over trees (`characters.shadow_floor_z`).

### 8.6 Performance and memory checks (tests/perf_world.tscn, headless-safe numbers where possible)

100 animated characters < 8 ms/frame in Compatibility on the Apple M3 reference (spike: 7.2 ms; 200 characters 8.6 ms); first use of an unwarmed clip < 40 ms, warmed < 8 ms/frame; area switch with `warm_clips` hides all hitches behind the 0.22 s fade; VRAM budget report (S3TC) < 400 MB in Hyggebyen; boot to menu < 5 s after import; placeholder painting < 0.2 s.



## 9. Risks, explicit CUT / STUB list, open questions

### 9.1 Risks (with the mitigation already built into the plan)

| # | Risk | Mitigation / fallback |
|---|---|---|
| R1 | Many writers in one tree, one `.godot` cache (other tools already touch the directory) | disjoint ownership, `tools/dev/test_in_copy.sh`, re-read-before-edit rule, wave reviewers; recommend an initial git commit as baseline before wave 1 (the repo has no commits; the user decides, this plan runs no git command) |
| R2 | Memory/hitches: 125 MB per character RGBA8, 15-37 ms first-use hitch | S3TC import presets (4x), residency rule, awaitable `warm_clips` behind the fade; 192 px re-bake deferred |
| R3 | Big sprites sort wrongly at side faces | `strips=N` slicing in the area builder, padded footprints, `shot_sort` evidence |
| R4 | Look is soft CG, not hand-painted; Hyggebyen/forest 6.5/10; key art 6/10 | stated honestly (6.5); QA gate on contact sheets; optional painterly pass not planned |
| R5 | VRAM at scale (all 45 characters resident) | per-area residency and unload on exit |
| R6 | New ortho tile/wall bake may not reach quality in two attempts | forest maps switch to `@projection iso` with existing diamond art (header + wall chars only) |
| R7 | Danish voice: only one system voice (`Sara`), pitch-shifted per NPC sounds artificial; the user's 14 MP3s say old copy | placeholder status is explicit; RECORDED.txt lets real recordings win; MP3s archived, question below |
| R8 | The Lua reader is a subset; authors can write Lua it silently misreads | load-time lint, documented subset, tests drive every quest; GDExtension stays an option behind the same API |
| R9 | Title key art quality | ship the best iteration; stripes placeholder never ships |
| R10 | First `--import` prints font errors (theme before fonts); `class_name` scripts invisible until import | run import twice on a fresh clone (documented, scripted in `run_playtest.sh`) |
| R11 | Repo size ~80 MB of WebP/PNG | `.gitattributes` with optional LFS lines; user decides |
| R12 | Not verifiable headless: real mouse aim, gamepad, audio, hand feel, Retina rendering | covered by screenshot checkpoints and an explicit "needs a human" list in the QA report |
| R13 | Copy rewrite for new NPC names invalidates old voice lines and `docs/voice_lines.md` | voice regenerated by P24; ids stay stable (D11) so no code churn |
| R14 | Contract drift inside a wave | contracts in section 3, wave gates, `tests/sections` of each package lint signal arities |
| R15 | Danish long words overflow fixed-size UI | tested at 1280x720 with the longest names ("Fe-troldmanden Zephyr", "Gulerødder til småkager"); labels clip with ellipsis, never overlap |
| R16 | Acceptance run time | per-character acceptance < 6 min headless; sections independent |
| R19 | A Godot editor is open on the repo (seen running with `--editor`) and reimports or overwrites files while packages rewrite them | close the editor for the duration of waves 1-7; builders use clone copies (R.7) |
| R20 | Disk: each `.godot` with the full cast is ~1.2 GB (S3TC 33 MB per full character), 63 GB free | clone-seeded disposable copies, import stubs, no stale lossless cache (R.7) |
| R21 | Windowed checks are the only proof of acceptance item 2 and of every art gate | `--windowed` suite with automated pixel assertions, run by the lead/user at each wave boundary (R.6) |
| R22 | Ortho forest art has never been baked | P22 does it FIRST and writes ORTHO_DECISION.md before P19 starts; iso fallback is a header + wall-char change in P19's own maps (R.2) |
| R23 | Linear+mipmap filtering with periodic tile atlases was never rendered (spikes used 1 and 3) | explicit Ground filter 2 and mipmap-free atlases; windowed seam probe at 3 zooms x 3 window sizes (R.1) |
| R24 | The user's recorded lines were matched by ASR (small model) and duration, not by listening | one confirming question to the user; RECORDED.txt entries are removable (R.5) |
| R18 | Stable ids with new display names (`mayor_lyra` shown as Borgmester Hyldeblomst) is cosmetic debt for people reading the Lua | `npcs.lua` carries a `display_hint` comment per id; a rename tool can be added later without gameplay change |
| R17 | The user's four sketches define the pack's face grammar; our invented hobbit/squirrel/NPCs may not match their taste | optional: user provides sketches for hobbit, squirrel, Fekongen, Pippin; builders only need a day to re-model |

### 9.2 CUT and STUB list (nothing half-wired; each has a minimal playable behaviour)

| Item | Status | Reason | What the player gets |
|---|---|---|---|
| Fishing (Fiskestang) | STUB | no budget for a mini-game; guide shows the item | item + icon; use shows a Danish "fiskevandet er ikke åbnet endnu" whisper |
| Weather fog/snow/thunder visuals | STUB | rain is the only weather with a rule | label changes, no effect |
| Fe "taler med blomster" | STUB | flavour perk | 6 flower whispers near crops while flying |
| Scarecrow effect, watering-can capacity, strawberry regrow | STUB/CUT | not needed for the loop | decoration; unlimited water; single harvest |
| Honey source / wheat / bee hive | STUB | out of scope | honey and flour sold at the bakery |
| Farmhouse interior, festivals, friendship hearts UI, gifting, relationship events | CUT | not in the pitch/guide beyond the "♥ Pippin" reward chip | friendship stored as world flag and shown on reward chips |
| Music | CUT | no assets, not requested | AudioManager slots; silent |
| SFX | STUB | hooks wired, optional ffmpeg-synth placeholders | quiet game; voice works |
| Real voice acting | STUB | placeholder TTS | Danish voice for every line, recordings drop in |
| Gamepad play | STUB | bindings exist, untested | full keyboard/mouse play |
| Seasonal tile sets, terrain transition tiles | CUT | art budget | tint per season; hard cuts hidden by props |
| NavigationAgent pathing | CUT | not needed in 2D | NPCs wander on walkable cells; enemies steer straight with sliding |
| Bear/owl as player species | CUT | guide lists four species | Ræv, Kanin, Pindsvin, Egern |
| Skin variants for Fe/Hobbit on the select screen | STRETCH (P16) | guide shows only species chips | default skin per race if not built |
| Moon crop "grows only at night" | IMPLEMENT (cheap) | `water_window` | counts only when watered 20:00-06:00 |

### 9.3 Open questions for the user (none block wave 1)

1. The 14 MP3s in `docs/audio`: ASR (Danish) and durations show they are the 14 lines of the old `docs/voice_lines.md` in order, spoken without the word PongPong ("den magiske by"). 11 of them are reused verbatim in the new copy (R.5); #1 names Lyra and #11/#12 name Mjau and stay archived. Please listen to files 2-10, 13, 14 once and confirm they say what R.5 lists (and tell me if you want the three archived ones re-recorded with the new names).
2. Git: create an initial commit as baseline before wave 1? Use Git LFS for `assets/**/*.webp`?
3. Do you want to sketch the hobbit, the squirrel and Fekongen (the pack's four characters came from your drawings; ours are generated from the guide text)?
4. Renderer: GL Compatibility chosen for reach; Forward Mobile would be 2x faster on the sprite stress test but nothing needs it - OK?
5. Calendar: weeks start Monday on day 1 of each season (the guide's mock shows "Tirsdag 14") - OK?

## Appendix A. Spike -> package lift map

| Package | Lift from |
|---|---|
| P01 | SW/project.godot, SU/project.godot |
| P02 | SW/scripts/autoload/event_bus.gd; audit reports (core, save, quest, economy) |
| P03 | /Users/magnusudbjorg/Documents/projects/PongPong_lift/loc_verify/drv.gd (loader), /Users/magnusudbjorg/Documents/projects/PongPong_lift/loc/* (key extraction), SU/localization/ui.csv |
| P04 | SW/scripts/world2d/{iso,area_map,area_tileset,iso_area,world_2d,warp_2d,interactable_2d,day_night,glow,game_data,placeholder_art,prop_art}.gd, SW/scenes/main/world.tscn, SAG/scenes/farm_test.gd, SW/tests/{shot_world,shot_sort,shot_flight,shot_tiles,sort_probe}.* |
| P05 | repo docs/PongPong_Isometric2D, SW/scripts/isometric/iso_chibi_sprite_2d.gd, SA/patches/iso_chibi_sprite_2d.diff |
| P06 | SW/scripts/world2d/{player_2d,target_marker_2d,slash_2d,light_ring_2d,dust_2d,hotbar,farm_grid,farm_view}.gd, SW/scenes/world2d/player_2d.tscn |
| P07 | SU assets/fonts, assets/ui, shaders, scripts/ui/{theme,components,dev}, scenes/ui/{components,dev}, tools/ui, localization/ui.csv |
| P08 | /Users/magnusudbjorg/Documents/projects/PongPong_lift/artenv, SA/tools/isometric/*, SA/patches, /Users/magnusudbjorg/Documents/projects/PongPong_lift/pongsrc |
| P09 | SW/tests/*, repo tests/playtest.gd + run_playtest.sh |
| P10 | SW/lua/config/race_perks.lua, repo game_balance.lua, /Users/magnusudbjorg/Documents/projects/PongPong_lift/lua_audit (probes -> tests/fixtures/lua), the parser/lint work of the old P13 task 1 |
| P11 | SW/data/maps/farm.map |
| P12 | SU/scripts/economy/crafting_system.gd, SW/lua/items/consumables.lua, /Users/magnusudbjorg/Documents/projects/PongPong_lift/econ_proposal |
| P13 | quest_triggers.gd, triggers_test.gd |
| P14 | SW/scripts/world2d/{npc_2d,dialogue_box_2d}.gd, SU/scripts/ui/{dialogue_ui,quest_journal}.gd, proto_dialogue_ui.gd, proto_npc.gd |
| P15 | /Users/magnusudbjorg/Documents/projects/PongPong_lift/save_audit |
| P16 | SU/scenes/main/main_menu.tscn, SU/scripts/ui/{main_menu,character_select,settings_ui,pause_menu,save_load_ui}.gd + scenes, /Users/magnusudbjorg/Documents/projects/PongPong_lift/hud_menus |
| P17 | SU/scripts/ui/hud.gd + scenes/ui/hud.tscn |
| P18 | SU/scripts/ui/{shop_ui,inventory_ui}.gd + scenes, /Users/magnusudbjorg/Documents/projects/PongPong_lift/econ_proposal |
| P19 | SW/scripts/world2d/{enemy_2d,loot_drop_2d,resource_node_2d,whisper_zone,minimap_2d}.gd, SW/data/maps/forest.map, SW/lua/config/enemies.lua, SU/scripts/ui/forest_hud.gd |
| P20 | scratchpad/{farm_animal_fixed2.gd,animal_spawner.gd,build_menu_fixed.gd,farm_animal.tscn,logic.gd} |
| P21-P23 | SA/tools/**, SA/export/assets/** (reference output) |
| P24 | /Users/magnusudbjorg/Documents/projects/PongPong_lift/voice_probe |

## Appendix B. Godot pitfalls collected from the spikes (put in every builder's head)

`class_name World2D` hides a native class (use `WorldRoot2D`; avoid Node/Area/Camera/Light names); new `class_name` scripts are invisible until `--import`; `-s` SceneTree drivers compile before autoloads exist (reference classes by `load()`/duck typing, autoloads by `root.get_node`); `const A := ClassName` is not a constant expression (use `preload`); iso `TileSet.tile_layout` must be `DIAMOND_DOWN`; `map_to_local` is the tile centre; `texture_origin` is subtracted; Y-sort flattens descendants and gives a big sprite ONE key; ground `z=-10` must not sit inside the y-sorted node; child `z_index` is relative (shadow needs `z_as_relative=false`); `add_child` with a colliding name renames the later node (use groups or `add_child(n, true)`); a `CharacterBody2D` teleported into a solid is depenetrated (disable physics processing to test pure draw order); await `physics_frame` for physics-driven asserts; paused tree needs `PROCESS_MODE_ALWAYS` on every modal and on any node that must see the unpause key; input order is reverse tree order; `PanelContainer` ignores child anchors; `Panel` with transparent background paints its shadow inside (draw rings with `draw_arc`); `FontVariation` height = tallest font in the fallback chain; theme icons from not-yet-imported SVGs load null (import before building the theme); Camera2D limits smaller than the view stick to top-left; `reset_smoothing()` after teleports; `CanvasModulate` exactly one per canvas and `PointLight2D` adds to it (burst energy > ~1.5 whites out); static caches of ImageTexture leak at quit (harmless); `user://` folder names with AE warn on macOS (custom user dir); `.import` presets live in files - commit them.

## Appendix C. Verification commands

```
godot --headless --path . --import                       # twice on a fresh clone
tests/run_playtest.sh --character=animal|fairy|hobbit [--only=core,farm,forest] [--list]
godot --headless --path . -s res://tests/loc_check.gd -- --strict
godot --headless --path . res://scenes/ui/dev/ui_smoke.tscn
godot --path . res://tests/shot_world.tscn -- --part=cast --out=/tmp/shots     # screenshots: opens a window for ~1 s
tools/art/produce_all.sh --only=characters hobbit_pip && python tools/art/core/validate_new_assets.py ...
python tools/voice/generate_voice.py --only mayor_lyra
tools/dev/test_in_copy.sh P14-npc-dialogue               # package self-test against the current shared tree
```
