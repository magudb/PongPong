# TRÆTOPPEN - Ghost addendum: Spøgelse, the fourth playable race

Role: FINAL EDITOR (design4), after an independent review of the designer's draft: eleven verified defects (three major) are fixed in place, see `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/FINAL/CHANGELOG.md`. Request (user, 2026-10-14): "Ghost is a friendly playable character." Status: complete design + a REAL art prototype + a proven data / test patch; nothing in the repo, the lift or another agent's folder was edited.
Everything lives in `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/`: this file, `ghost_packages.json` (work packages), `proto/` (art, screenshots, select mock), `scripts/` (every number's script), `loc/` (the Danish copy as CSV), `notes/` (raw outputs), `final_logs/` (the clone runs of the final edit), `ghost_key_owners_additions.json`; the shipped copies are in `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/FINAL/`.
All paths below are absolute under that folder unless they start with `lua/`, `scripts/`, `tests/`, `tools/`, `assets/` or `docs/` (those are repo paths of main at commit `b909274`).

## 0. Summary

**What the ghost is.** A round, friendly chibi ghost for the dark forest's sweet side ("uhyggelig-sød"): a big round head on a small legless bell body with a scalloped, rolled hem, two stub mittens, a small curl of a wisp, big DARK eyes with a white glint, blush and the three cheek strokes of the character family, a soft glow, and a hover instead of footsteps. Two looks like the other races: **Bu** (pale sky-blue-white, the default) and **Hviske** (pale lilac-pink, shy glance). Race name **Spøgelse**. The look is built, baked and shown in the real game: `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/proto/contact_sheet_ghost.png`, `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/proto/gamezoom_check.png`, `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/proto/sketch_vs_baked.png`, windowed shots in `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/proto/shots/`.

**Decisions (each with the reason; the lead's defaults kept unless noted).**
1. **Enum**: `GHOST` appended LAST (`ANIMAL 0, FAIRY 1, HOBBIT 2, GHOST 3`). Saves store the int, so no migration; `SaveManager` is enum-driven and needs no edit (section 4).
2. **THE trap**: `Perks._race()` and `CraftingSystem.bake_bonus_chance()` clamp the race index to `Perks.RACE_KEYS.size() - 1`. With the enum extended and that table not, the ghost silently gets the HOBBIT's 10 % discount and +25 % bake bonus. Measured by mutation (`/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/notes/t4_mutant_perks.log` for the first draft, `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/final_logs/mut_perk_leak.log` for the final 7-check section: with the `RACE_KEYS` entry taken away again `ghost.every_enum_value_has_a_perk_row` and `ghost.no_hobbit_perks_leak` fail with discount 0.1 / bake 0.25); guarded by `ghost.no_hobbit_perks_leak`.
3. **Perk "Nattesyn + svæv"**: runs 40 % cheaper (`run_cost_mult 0.6`), one lantern fill lasts 200 s instead of 150 s (`oil_use_mult 0.75`), the lantern light reaches 25 % further (`dark_light_mult 1.25`, 630 -> 787.5 px), floats +-2.5 px (`float_bob_px 2.5`), glows softly (`glow_*`). Worth about 5 % of a typical dive's income in saved oil and +6 % sustained sprint speed: a utility perk of the fairy / hobbit class, not the animal's (section 3, `scripts/perk_balance.py`). The lead's default idea "no energy loss at night" was NOT kept: energy regenerates 12/s, so it would be worth nothing; the real energy sink is running (15/s).
4. **The glow is a PointLight2D, not a halo** (the task's default stands, now with evidence): in a real windowed night shot the additive halo alone is barely visible, halo + a small PointLight2D reads (section 7.3). It is a PLAYER light like the lantern, so 12 map lights + lantern + glow = 14 <= 15 (V8's measured safe number).
5. **Hover = baked + runtime**: the hem is baked ~10 px above the contract pivot (a 0.66 m bell on the ground would project 22 px BELOW the pivot and fail the feet window), the runtime adds a 0..5 px bob through the built `set_altitude()` (the fairy's mechanism). Only LOOKS floaty: no water crossing.
6. **Wardrobe**: pants and shoes are worn, counted (perks, set bonuses AND the RarityAura) and NOT drawn (`bodies.json hidden_slots`); the Garderobe says so. Hats, shirts, dresses, necklace, bracelet, earrings, circlet are drawn: 7 drawable slot kinds, never more than 5 parts at once (two maximal outfits: 7 worn / 5 drawn / 2 hidden without a dress, 6 / 5 / 1 with one, section 5). 30 % of the loot (29 of 96 wearables) is pants or shoes: the invisible cue is accepted and the aura carries it. Cost: +22 layer bakes (+10.6 CPU-min, +14.7 MB), +11 if the head scope can be borrowed.
7. **Select screen**: FOUR cards in one row (270 px wide, gap 24, x = 64 / 358 / 652 / 946), the hero-chip row and the blurb in the bottom bar (the blurb cannot live inside a 270 px card), pixel reference rendered with the real fonts and sprites (`/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/proto/select_4cards_fixture.png`). Every text uses a variation of the BUILT theme: chips = `Display20` over `Muted13`. The guide diff is re-based on that reference (the guide shows three cards).
8. **Translucent hem: built, compared, REJECTED** (invisible at zoom 0.4 / 0.9). S3TC handled the alpha ramp; the door stays open.
9. **No ghost citizens, no ghost voice, no water crossing, no movement audio** (there is none for any race): honest stubs, section 13.
10. **Selectable in M1a, honestly** (review defect 2): P16, which builds the four-card page, is M1b. So the lead patches the LEGACY select screen with a fourth button (`SE-G5`, 9 edits in 3 files, proven by the boot stage of `--character=ghost`): the ghost can be picked and walked around in the city preview, WITHOUT perks, bob, glow or garment layers (those need P06, G-ghost-play and the wardrobe packages: M1b). Section 12 says what each milestone contains.
11. **Wave placement** (review defects 3 and 5): the design3 checker allows a dependency only on a strictly EARLIER wave, so the same-wave couplings became hard edges: `G-ghost-data` and `G-ghost-art` are wave **3b** (V1 and A2 depend on them), `G-ghost-play` is wave **5** (it depends on V1, P06 and DR1; P06's hooks are null-safe). The fix round is gated by the built harness; the seven `ghost.*` guards of G-ghost-data are the first gate right after it.

**Evidence that the patch is mechanical and correct.** `ghost_edits.py` holds 61 exact before -> after edits in 22 files, in three TIMES (`when`): 28 `fix`, 24 `v1`, 9 `sel`. MEASURED in three SEQUENCING states, strict (`final_logs/`): **the fix round only** (what a fixer does before wave 3b): animal, fairy, hobbit: 15 sections, 2774 checks, 0 failed, 0 engine messages each; **fix round + wave 3b** (ghost.csv, the 7-check section, the ghost art): the section is green under all four heroes (7 checks each), animal 16 sections, 2781 checks, 0 failed, 0 engine messages; **everything** (+ V1, V2, the legacy-select patch, `ghost_data.gd`) WITH the boot stage: animal, fairy, hobbit, ghost: 17 sections, 2789 checks, 0 failed, 0 engine messages each. Without the edits exactly 4 built checks fail (3 for every hero, 1 only under `--character=ghost`), section 11. Ownership: `check_ghost_ownership.py` OK (68 pattern pairs, 0 overlaps, 8 mutants caught (`notes/check_ghost_ownership_selftest.txt`)).

**What only you can decide**: section 14 (look: dark eyes; names; water; ghost citizens).

## 1. Method and where the numbers come from

* A clone of main (`impl/tools/clone_run.sh ghost-d4`, pinned to main with `TT_REPO` because `impl/current_repo` points at the M1a worktree while a wave runs). `scripts/rebuild_clone.sh` rebuilds it from design4 alone: edits, ghost art through the REAL `tools/art/produce_all.sh`, loc, draft section, import. Runs: `scripts/run_clone_tests.sh`.
* Art: the prototype builder follows `tools/art/characters/traetoppen_additions.py` (same hooks) and the geometry of `tools/art/generator/geometry.py`; it is run through `tools/art/produce_all.sh --only=characters ghost_bu ghost_hviske` with `PYTHONPATH=/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/proto/builder` first (the caller's PYTHONPATH wins, `produce_all.sh` header). Own Python runs use `python -I` through `scripts/run_step.py`, which puts the module paths on `sys.path` itself.
* Windowed shots: `impl/tools/windowed.sh`, one window at a time, `tests/shot_ghost.tscn` of the clone (`proto/shot_ghost.gd`), looked at.
* FINAL EDIT: `scripts/final_clone.sh fix|t3b|full NAME` builds the three SEQUENCING states of the final design (the fix round only; fix round + wave 3b; everything) as clones of main, `scripts/final_runs.sh` runs the harness in them (logs in `final_logs/`), `scripts/dry_check_edits.py` checks every anchor of the edit table against main read-only, `scripts/select_mock.py` + `scripts/blurb_fit.py` re-render and re-measure the select page with the in-scale type, `scripts/tone_check.py` is the tone gate as an allow-list, `scripts/clothing_counts.py` counts the loot a ghost cannot show.
* Dungeon rules, oil and light: `docs/design/DUNGEON_V2_ADDENDUM.md` lines 304-309 (floor times), 427-442 (pace), 484-495 (oil, lantern look); the price of oil `lua/items/consumables.lua:22-32`; the energy rules `lua/config/game_balance.lua:28-31`.
* Wardrobe: `docs/design/PLAN_2D_FEATURES.md` 2.4, the A2 amendment of `dungeon_v2_workpackages.json` (0.482 CPU-min and 0.67 MB per bake; scopes 15 body / 11 head / 4 feet).
* Select screen: `docs/Trætoppen Style Guide Review/Trætoppen Style Guide.dc.html` lines 157-186, 424-428; `docs/design/UI_NAVIGATION.md` S04 / S05; design2's P16 amendment (`%Heroes`, `%HeroChip1/2`).

## 2. Race identity and Danish copy

### 2.1 What "friendly" means here (rules the art and the copy obey)
* Cute before ghostly: round, pale, a smile, blush, big glinting eyes; no skull shapes, no dripping, no pointed teeth, no red, no empty eye sockets (the eyes are full dark ovals with two white glints).
* The ghost is the SWEET side of the dark forest: it is not afraid of the dark, so the dark is a friend (the perk). Nobody in town is frightened of it; the king says so in the first line.
* Same character family rule as the 12 pack figures and the guide: head about as big as the body (here bigger, as chibi), three cheek strokes, tiny mouth, stubby arms, thin warm-grey outline in the world, ink outline only on UI.
* Readable at game zoom 0.4: the ghost is a white / pink figure of 46 x 64 px on the grass with two dark eyes that stay visible (windowed shot).

### 2.2 The copy (authoritative CSV: `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/loc/ghost.csv`, `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/loc/ghost_dialogue.csv`; the guide tone "Venlig og lun")
| key | da | en |
|---|---|---|
| CHAR_GHOST_NAME | Spøgelse | Ghost |
| CHAR_GHOST_PERK | Svæver lydløst og ser i mørket. Løber længere og sparer lygteolie. | Floats silently and sees in the dark. Runs further and saves lantern oil. |
| SKIN_GHOST_BU | Bu | Boo |
| SKIN_GHOST_HVISKE | Hviske | Whisper |
| HERO_BU_NAME | Bu | Boo |
| HERO_BU_KIND | Spøgelse | Ghost |
| HERO_BU_BLURB | Standardfiguren for spøgelser. Svæver lydløst og siger »bu!« for sjov. Ser i mørket og sparer lygteolie. | The default ghost. Floats silently and says 'boo!' for fun. Sees in the dark and saves lantern oil. |
| HERO_HVISKE_NAME | Hviske | Whisper |
| HERO_HVISKE_KIND | Spøgelse | Ghost |
| HERO_HVISKE_BLURB | Blid og lidt genert variant af spøgelset. Samme evner: svæver, ser i mørket og sparer lygteolie. | A gentle, slightly shy variant of the ghost. Same abilities: floats, sees in the dark, saves lantern oil. |
| GHOST_WARDROBE_NOTE | Spøgelser har ingen ben: bukser og sko ses ikke, men de tæller stadig med. | Ghosts have no legs: trousers and shoes cannot be seen, but they still count. |
| GHOST_HIDDEN_TAG | Skjult | Hidden |
| GHOST_EQUIP_HIDDEN_FMT | %s ses ikke på et spøgelse, men tæller stadig med. | %s cannot be seen on a ghost, but it still counts. |
| GHOST_WHISPER_WATER | Du svæver kun lidt. Vandet er for bredt at krydse. | You only float a little. The water is too wide to cross. |
| GHOST_WHISPER_DARK | Du ser godt i mørket. Lygteolien holder længere, og lyset rækker videre. | You see well in the dark. The lantern oil lasts longer and the light reaches further. |

The perk text is two short sentences like the other cards ("Stærke poter. Graver hurtigere og får mere ud af høsten."): *what it is* and *what it gives*. The hero blurbs follow the Figurer v2 card pattern ("Standardfiguren ... Samme evner: ...") and fit two lines of the select bottom bar, whose width depends on the chip row of the selected race (measured per race with the real fonts and the in-scale chips `Display20` / `Muted13`: `scripts/blurb_fit.py` -> `notes/blurb_fit.txt`: the bar is 541 px wide for the ghost, 477 px for Fe (the narrowest), 533 px for Skovdyr, 544 px for Halvling; Bu 658 px and Hviske 613 px of one line need two lines; all six blurbs of the sheet, with Hyggebyen for Fesby, need at most two, the longest, Kløvermynte, 772 px). `ghost.keys_translate` checks <= 118 characters as a proxy; `menus.hero_blurb_fits_two_lines` measures per race.

### 2.3 The Fairy King's line and the citizens
The line the Fekongen says to a ghost, directly after the letter of the intro (key `DLG_GHOST_KING_INTRO`):

> "Et spøgelse! Hvor dejligt. Her er der ingen, der skal skræmmes. Svæv bare ind, kagen står på bordet."

Reactions of nine citizens on the FIRST meeting (condition: `context.race == "ghost"`, once per NPC through the flag `ghost_met_<npc>`; data in `lua/config/race_reactions.lua`, package G-ghost-lines):

| key | da | en |
|---|---|---|
| DLG_GHOST_KING_INTRO | Et spøgelse! Hvor dejligt. Her er der ingen, der skal skræmmes. Svæv bare ind, kagen står på bordet. | A ghost! How lovely. Nobody here needs to be frightened. Just float in, the cake is on the table. |
| DLG_GHOST_MAYOR | Åh, et spøgelse! Du kom helt lydløst. Velkommen til Hyggebyen, du lyser jo hele gaden op. | Oh, a ghost! You arrived without a sound. Welcome to Hyggebyen, you light up the whole street. |
| DLG_GHOST_BAKER | Spøgelser spiser vel ikke kage? Nå, du nyder duften, og jeg nyder selskabet. Du må gerne smage alligevel. | Ghosts don't eat cake, do they? Well, you enjoy the smell and I enjoy the company. You may taste a bit anyway. |
| DLG_GHOST_CAT | Miav. Katte kan se spøgelser, ved du. Jeg så dig allerede i går. Gå ikke igennem mig, hvis du kan lade være. | Meow. Cats can see ghosts, you know. I saw you yesterday already. Don't float through me if you can help it. |
| DLG_GHOST_GUARD | Stå! ... Åh, det er dig. Spøgelser er velkomne her. Tag lygten med i skoven, mørket skal også have en ven. | Halt! ... Oh, it's you. Ghosts are welcome here. Take the lantern into the forest, the dark needs a friend too. |
| DLG_GHOST_OWL | Uhu. Vi er begge nattens folk, du og jeg. Kom forbi i skumringen, så tager jeg mig tid til dig. | Hoo. We are both people of the night, you and I. Come by at dusk and I will make time for you. |
| DLG_GHOST_BATH | Et spøgelse i badet? Du bliver aldrig våd, men varmen kan du da fornemme. Kom ind og slap af. | A ghost in the bath? You never get wet, but you can surely feel the warmth. Come in and relax. |
| DLG_GHOST_POST | Post til et spøgelse! Jeg har aldrig leveret til nogen uden dør. Jeg lægger brevene på dit gærde, ikke? | Mail for a ghost! I have never delivered to anybody without a door. I will leave the letters on your fence, all right? |
| DLG_GHOST_BAT | Endelig en, der er vågen, når jeg er. Kortene er ekstra gode i nat, bare til dig. | Finally somebody who is awake when I am. The maps are extra good tonight, just for you. |

The tone gate (`ghost_lines.tone_gate`) is an ALLOW-LIST, not a word match (review defect 10): the stems skræm / bange / uhyggelig / frygt / gyser / forskrække / rædsel (and the English scare / frighten / afraid / creepy / terrif / horror / spooky) fail in every string of both CSVs except the keys on the allow-list, whose single entry is this king line (the reassurance names the stem to deny it); `scripts/tone_check.py` is the draft (24 strings checked, exit 0).

The Lua dialogue files are not edited (nine files with three different owners): `RaceReactions.apply(npc_id, ctx, dialogue)` prepends the line from data (section 7.5).

## 3. Perk numbers and balance

Mechanism: `lua/config/race_perks.lua` (every race defines EVERY key, file header), read by `GameData.perk(key)` and, from V1 on, through `SpeciesPerks.value(skin, key, default)`. The animal / fairy / hobbit perks are the balance reference (`race_perks.lua:17-59`, `scripts/data/perks.gd`).

| key | animal | fairy | hobbit | ghost | read by |
|---|---|---|---|---|---|
| `run_cost_mult` | 1.0 | 1.0 | 1.0 | **0.6** | P06 Player2D stamina drain while running (15/s -> 9/s) |
| `oil_use_mult` | 1.0 | 1.0 | 1.0 | **0.75** | DR1 `OilRules.oil_step` ctx.race_mult (150 s -> 200 s per fill) |
| `dark_light_mult` | 1.0 | 1.0 | 1.0 | **1.25** | P06 lantern radius: 630 x light_ratio x gem x this |
| `float_bob_px` | 0.0 | 0.0 | 0.0 | **2.5** | GhostFloat -> Player2D altitude |
| `glow_energy` / `glow_energy_dark` | 0 / 0 | 0 / 0 | 0 / 0 | **0.35 / 0.08** | GhostGlow (iso areas x night factor / dark presets) |
| `glow_scale`, `glow_color` | 0, "" | 0, "" | 0, "" | **0.9, "bfe0ff"** | GhostGlow |
| old keys | dig 1.3, tool 0.75, harvest +0.2 | flight 8 s, flowers | discount 0.1, bake 0.25 | all neutral | unchanged |

Computation (`scripts/perk_balance.py`, output `notes/perk_balance.txt`; sources printed in its first line):

```
SOURCES lua/config/game_balance.lua:30 lua/config/game_balance.lua:29 lua/config/game_balance.lua:31 lua/config/game_balance.lua:28 lua/config/game_balance.lua:16 lua/config/game_balance.lua:17 lua/config/race_perks.lua:81 lua/items/consumables.lua:26
lantern_oil: 60 s of oil for 25 gold (lua/items/consumables.lua)  -> 0.4167 gold per oil-second

--- running (game_balance.lua player.*): hold `run` for 120 s
  run_cost_mult 1.00: first sprint  6.65 s, run share 47.2 %, average speed 362.9 px/s (+27.3 % over walking)
  run_cost_mult 0.75: first sprint  8.88 s, run share 55.1 %, average speed 376.0 px/s (+31.9 % over walking)
  run_cost_mult 0.60: first sprint 11.10 s, run share 60.7 %, average speed 385.3 px/s (+35.2 % over walking)
  run_cost_mult 0.50: first sprint 13.32 s, run share 65.1 %, average speed 392.5 px/s (+37.7 % over walking)
  ghost 0.6 vs everybody else: +6.2 % average travel speed when sprinting all the time, first sprint 11.1 s instead of 6.7 s
  (energy regenerates 12/s while not running, so the fox's -25 % TOOL cost is worth almost nothing in energy: its value is the harvest +20 % and the 30 % faster tools)

--- lantern oil: one fill per FIRST arrival of every floor (DUNGEON_V2_ADDENDUM 6.4), drain 1 oil-s per second x oil_use_mult
  band 1 floors 1-3       84 s per floor: oil bought per floor   0.0 gold (others) vs   0.0 gold (ghost)
  band 2 floors 4-6      122 s per floor: oil bought per floor   0.0 gold (others) vs   0.0 gold (ghost)
  band 3 floors 7-9      162 s per floor: oil bought per floor   5.0 gold (others) vs   0.0 gold (ghost)
  band 4 floors 10-12    196 s per floor: oil bought per floor  19.2 gold (others) vs   0.0 gold (ghost)
  typical full dive: oil bought 72 gold vs 0 gold, payout 1471 gold -> the ghost saves 72 gold = 4.9 % of a full dive
  clear-everything pace (1.6 x typical, addendum 4.4: 103-350 s per floor):
     oil bought 398 gold vs 162 gold: the ghost saves 236 gold = 16.0 % of the typical payout (the payout grows with thoroughness too)
  one lantern fill lasts 150 s for everybody else and 200 s for the ghost; the light radius 630 px x ratio: at full oil 630 -> 787.5 px, at the 35 % floor 220.5 -> 275.6 px

--- scale: what the other three are worth (same sources)
  hobbit: 10 % off every shop price (Perks.total(discount), cap discount_total 0.20) + 25 % chance of one more output on bake recipes
          -> if the player spends 40-50 % of the gross income in shops (plan: 20-30 % lifestyle of which furniture 55 %, plus seeds, tools, oil): about 4-5 % of gross
  animal: +20 % crops per harvest (harvest_bonus_chance 0.2) = about +20 % of the crop income, dig_speed 1.3, tool cost x0.75: the strongest perk of the three
  fairy : flight 8 s at 10 energy/s over fields (utility, no income), flower whispers (flavour)
  ghost : about 5 % of the dive income in oil, 25 % further light, +6 % sustained sprint speed: a utility perk of the hobbit / fairy size, not the animal's
```

Reading: energy REGENERATES at 12/s (`game_balance.lua:29`) so the only energy sink that matters is running (15/s); that is why the farm-side perk is `run_cost_mult`, not a tool-cost cut like the fox's. The fox's real value is +20 % crops; the hobbit's about 4-5 % of gross; the ghost's dungeon-side oil saving is 4.9 % of a typical dive (72 of 1471 gold) and rises with thoroughness; the extra light radius and the sprint are quality of life. The ghost keeps the dark's bite (1 half heart per 12 s at oil 0, never below 2: the gold sink and the safety rule are the same for every race).

## 4. Data model

### 4.1 Enum, saves, migration
* `scripts/autoload/game_manager.gd:31` `enum CharacterType { ANIMAL, FAIRY, HOBBIT }` -> `{ ANIMAL, FAIRY, HOBBIT, GHOST }`. Saves: `to_dict()` writes `"character_type": int(character_type)` (line ~467); `from_dict()` clamps to `0 .. CharacterType.size() - 1` (line ~487). **Appending is save-compatible; inserting or reordering would silently turn every hobbit save into a ghost.** `SaveManager` derives `meta.summary.character` from `CharacterType.keys()` (`save_manager.gd:826-846`): `"ghost"` is valid the moment the enum has it (checked: `ghost.save_roundtrip_and_old_saves`). `PAYLOAD_VERSION` stays 2, `SAVE_VERSION` 1, no migration step. Side effects, documented and tested: a damaged save with `character_type` 99 now loads as the ghost (was: hobbit); an OLDER build loading a ghost save clamps it to the hobbit with an unknown skin and falls back to the race default skin (forward compatibility is not promised).
* Default skin: `_default_skin_for(GHOST)` = `ghost_bu`.
### 4.2 Everything that reads the race (complete list, `rg CharacterType|RACE_KEYS|character_type scripts`)
| file | what | change |
|---|---|---|
| `scripts/autoload/game_manager.gd` | enum, `_default_skin_for`, `to_dict`, `from_dict` | enum + one match arm (RG1) |
| `scripts/data/perks.gd:22,128` | `RACE_KEYS`, the clamp | one list entry (RG2); the clamp is the trap of section 0 |
| `scripts/world2d/game_data.gd:11,63-79,103` | `RACE_KEYS` fallback dict, `race_key()`, `FALLBACK_VISUALS` | two dict entries (RG3); `race_key()` itself is enum-name driven and finds `characters.lua races.ghost` |
| `scripts/economy/crafting_system.gd:116` | `bake_bonus_chance()` clamps with `Perks.RACE_KEYS` | none (fixed by RG2) |
| `scripts/economy/shop_system.gd` | discount through `Perks.total` | none |
| `scripts/autoload/save_manager.gd:85,826-846` | enum-driven | none |
| `scripts/isometric/character_catalog.gd`, `iso_chibi_sprite_2d.gd` | id-driven | no code change (V1 adds `heroes()`); ONE doc-comment line of `character_catalog.gd` learns "ghost" (table of section 11) |
| `scripts/player/player_controller.gd` | legacy 3D player | deleted / replaced by P06, NOT patched |
| `scripts/ui/character_select.gd`, `scenes/ui/character_select.tscn` | the legacy select screen the main menu opens | **patched by the lead (SE-G5, 7 edits)**: a fourth button `%GhostButton`, the two ghost skins in the dropdown; P16 rewrites both files in place (UI_NAVIGATION.md line 764) and keeps `%GhostButton` |
### 4.3 `lua/config/characters.lua` (owner after the carve-out: V1-cast-data)
`races.ghost = { name_key = "CHAR_GHOST_NAME", perk_key = "CHAR_GHOST_PERK", default_skin = "ghost_bu" }`; skins `ghost_bu` and `ghost_hviske` (`race = "ghost"`, `visual = "<skin>_base"`, `fallback = "rabbit"`, `wardrobe_body = "<skin>"`); `fallbacks`: `ghost_bu_base -> ghost_bu -> rabbit` and the same for Hviske; V1's `heroes` table gets `bu` and `hviske` after the six (order rasmus kiki | kloevermynte birk | bertil bodil | bu hviske). The stand-in at the END of the chain is the pack **rabbit** (the paleish round pack figure; every chain must end at a pack character, `characters.chains_end_at_pack_characters`). The chain is only used while the art is missing; with `G-ghost-art` landed `ghost_bu` resolves to itself.
### 4.4 `lua/config/race_perks.lua` (V1)
The ghost row and the eight new keys on all four races (table in section 3; exact text in section 11). `species = {"bu", "hviske"}` = the hero chip ids (V1 turns `species` into the chip list), `skins = {"ghost_bu", "ghost_hviske"}`, `default_skin = "ghost_bu"`.
### 4.5 Wardrobe body family
`bodies.json` (A2): hero ids `ghost_bu`, `ghost_hviske`, `family "G"`, `hidden_slots ["pants","shoes"]` (new field, `[]` for every other hero), bakes `{body: "G", head: "ghost"}` (no feet scope).

## 5. Wardrobe rules and the art consequence

**Rule (one honest sentence, shown in the Garderobe)**: *"Spøgelser har ingen ben: bukser og sko ses ikke, men de tæller stadig med."* The starter kit (`lua/data/starter_kit.lua`) puts trousers and boots on every new hero, so a new ghost is "wearing" two invisible items: that is fine and stated.

| slot | ghost | how |
|---|---|---|
| hat, circlet, shirt, dress, bracelet, necklace, earrings | drawn | layers of the body scope G and the head scope `ghost` |
| pants, shoes | worn, counted, NOT drawn | `hidden_slots`; F5 does not load their layers; F8 shows the tag `GHOST_HIDDEN_TAG` and the note; toast `GHOST_EQUIP_HIDDEN_FMT` |

Perks, set bonuses and the RarityAura count the WORN items regardless of visibility (`WardrobeManager.gear_points`, `RarityAura` reads the highest rarity among the worn pieces), exclusions are unchanged ({dress, shirt}, {dress, pants}, {hat, circlet}). Earrings hang at the head sides (a round head has lobes too): 2-4 px at game zoom like the other races' jewellery, honest.

**How many parts can a ghost show? Two maximal outfits** (review defect 6; nine slots can never be worn at once, `lua/data/wardrobe_rules.lua` exclusive pairs, `lua/data/sets.lua` header "at most 7, with a dress 6"):

| outfit | worn | drawn on the ghost | hidden but counted |
|---|---|---|---|
| no dress | pants, shoes, shirt, bracelet, necklace, earrings, hat (or circlet instead of the hat) = **7** | shirt, bracelet, necklace, earrings, hat = **5** | pants, shoes = 2 |
| with a dress | dress, shoes, bracelet, necklace, earrings, hat = **6** | dress, bracelet, necklace, earrings, hat = **5** | shoes = 1 |

"7 drawable slots" (hat, circlet, shirt, dress, bracelet, necklace, earrings) is a number of SLOT KINDS, not of parts: at most 5 are drawn at once. Every acceptance text that says "7 layer parts" reads 5 (AG8, AQ-F10, G-ghost-qa).

**Loot the ghost cannot show (review defect 8).** `scripts/clothing_counts.py` -> `notes/clothing_counts.txt`: 29 of the 96 wearables (30 %) are pants (14) or shoes (15); 6 of the 21 unique and legendary pieces are among them, among them the legendary `pants_trousers_starlight` (the capstone of the set `nattevandreren`, the set that suits the ghost best) and the legendary `shoes_boots_wind`; `localization/wardrobe.csv:105` says of those trousers "De glimter, når du går" (they twinkle when you walk), which can never show on a legless body. Decisions: (1) **hidden slots count** for perks, set bonuses and the RarityAura, asserted by `wardrobe.hidden_slot_counts_for_aura_and_sets` (AG8): the aura (unique `ffd9e6`, legendary `ffd86a`) is THE rarity cue of clothes at game zoom and it does not need a layer, so a legendary hidden piece still shows; (2) **no reroll, no race-aware drop**: loot tables, shop prices and the four-hero matrices stay identical; (3) **the invisible cue is accepted** and flagged by the Garderobe tag `Skjult`, the equip toast and the aura; the item's flavour text stays; (4) **known upgrade, not built**: one tint-ready `hem` layer in the colour of the worn pants / shoes (every item has `art.palette`): +1 bake (+0.5 CPU-min, +0.7 MB), if play shows the invisible cue disappoints.

**Layer atlases and cost** (A2's model: 0.482 CPU-min and 0.67 MB per bake):
| scope | designs (Phase A + B) | bakes |
|---|---|---|
| body G (native: bell, no legs) | shirt 2+2, dress 2+1, necklace 1+1, bracelet 1+1 (NO pants) | 11 |
| head `ghost` | hat 3+5, circlet 1+1, earrings 1 | 11 |
| feet | none | 0 |
| total added | | **22 = +10.6 CPU-min, +14.7 MB** (101 -> 123; 145 with Bodil / Birk's own head scopes) |

The ghost head is the pack ellipsoid .64 x .575 at the ghost's export scale 0.925 = 1.18 m wide against the fox head 2 x .62 x .80 = .99 m: 20 % wider, so the borrow of the fox head scope is NOT expected to fit; A2 decides with `fit_test.py` (borrow if the mismatch is <= 0.28, else native; +11 if borrowed). Lock-step: the layers mirror the body sprite's position every frame (F5), the runtime bob is a `sprite.position` change through `set_altitude`, so no layer art depends on it; `wardrobe.lockstep_ghost_float` proves it.

**Hero palette table** (one table, `tools/art/ghost/ghost_model.py` -> A2's `hero_designs.py`; measured dE00 of the baked idle S against the hex: 1.3 / 1.1, gate <= 6; `scripts/palette_check.py`):
| | Bu | Hviske |
|---|---|---|
| sheet (body, head, mittens) | `E6EFFF` | `F6E7F6` |
| collar fold | `B9CEF2` | `E2BEE6` |
| hem trim | `93BBEE` | `F29DC2` |
| eye / pupil | `34305A` / `1B1633` | `3B2F5C` / `1E1436` |
| blush | `E8A0A3` | `F29AB2` |
| wisp | `DCE8FB` | `F0DCF4` |
**One silhouette**: Bu and Hviske share the geometry; the only differences are colour, hem trim, blush and Hviske's shy glance (pupils a little down). Measured: 1460 of 5 370 860 figure pixels differ (0.027 %), ALL inside the face band y 60-130 of the W / E rows (`notes/occluder_equality.txt`), so garment layers can be shared; A2's rule is relaxed for the two ghosts to "<= 0.05 % and none below the neck line", else Hviske gets her own scopes (+22).

## 6. Character select for FOUR races

### 6.1 Why a single row of four
Cards in the guide are 3 columns at gap 32 (362.7 px). Four columns at gap 24 give **270 px** cards with a **238 x 304.4** picture frame: the sprite (169 px figure x 1.25) fits with 90 px to spare, the four perk texts all wrap to **two lines** with the real Alegreya Sans Medium 17 (checked in `scripts/select_mock.py`: 56 / 49 / 53 / 66 characters, 2 lines each). A 2 x 2 grid would halve the frame height. The hero chips and blurb cannot stay inside a card (design2's `%HeroBlurb` under the perk text: 270 px x 5 lines): they move to the bottom bar.

### 6.2 Pixel plan (1280 x 720 design px; the picture is `proto/select_4cards_live.png`, the fixture without Tilbage / HintBar is `proto/select_4cards_fixture.png`, numbers `proto/select_4cards_numbers.txt`)
```
--- select_4cards_fixture (selected card Ghost)
card column width 270.0, gap 24, grid y 153..587 (height 434)
Animal  card x    64.0..  334.0  y 153.0..587.0  frame    80.0,169.0 238.0 x 304.4  perk lines 2
Fairy   card x   358.0..  628.0  y 153.0..587.0  frame   374.0,169.0 238.0 x 304.4  perk lines 2
Hobbit  card x   652.0..  922.0  y 153.0..587.0  frame   668.0,169.0 238.0 x 304.4  perk lines 2
Ghost   card x   946.0.. 1216.0  y 145.0..579.0  frame   962.0,161.0 238.0 x 304.4  perk lines 2
footer y 615..672; chips [(150.9, 615, 228.9, 668), (238.9, 615, 341.1, 668)]; blurb x 365.1..1038.0 (673 px) lines 1
Videre 1052..1216 x 615..668
--- select_4cards_live (selected card Ghost)
card column width 270.0, gap 24, grid y 153..587 (height 434)
Animal  card x    64.0..  334.0  y 153.0..587.0  frame    80.0,169.0 238.0 x 304.4  perk lines 2
Fairy   card x   358.0..  628.0  y 153.0..587.0  frame   374.0,169.0 238.0 x 304.4  perk lines 2
Hobbit  card x   652.0..  922.0  y 153.0..587.0  frame   668.0,169.0 238.0 x 304.4  perk lines 2
Ghost   card x   946.0.. 1216.0  y 145.0..579.0  frame   962.0,161.0 238.0 x 304.4  perk lines 2
footer y 615..672; chips [(150.9, 615, 228.9, 668), (238.9, 615, 341.1, 668)]; blurb x 365.1..906.0 (541 px) lines 2
Videre 1052..1216 x 615..668
Tilbage 920..1040; HintBar centred at y 692
--- select_4cards_animal_selected (selected card Animal)
card column width 270.0, gap 24, grid y 153..587 (height 434)
Animal  card x    64.0..  334.0  y 145.0..579.0  frame    80.0,161.0 238.0 x 304.4  perk lines 2
Fairy   card x   358.0..  628.0  y 153.0..587.0  frame   374.0,169.0 238.0 x 304.4  perk lines 2
Hobbit  card x   652.0..  922.0  y 153.0..587.0  frame   668.0,169.0 238.0 x 304.4  perk lines 2
Ghost   card x   946.0.. 1216.0  y 153.0..587.0  frame   962.0,169.0 238.0 x 304.4  perk lines 2
footer y 615..672; chips [(150.9, 615, 261.8, 668), (271.8, 615, 349.3, 668)]; blurb x 373.3..1038.0 (665 px) lines 2
Videre 1052..1216 x 615..668
```
* Page: `#e7d8b6`, padding 48 / 64, column gap 28. Header: title `Display48` at (64, 48), subtitle `Subtitle` 20 at y 101, counter "1 / 2" right-aligned to x 1216.
* Cards: x = 64, 358, 652, 946; width 270; y 153..587 (height 434 = 720 - 96 - 77 header - 28 - 28 - 57 footer); padding 16, gap 14, parchment `#f4e6c4`, 2 px ink, radius 18. Frame: (x+16, y+16), 238 x 304.4, 2 px ink, radius 12, stripes 135 degrees 14 / 14 px in the race tints: Skovdyr `#e8cfa6 / #dfc293`, Fe `#e2d8f4 / #d3c6ee`, Halvling `#d4e4b4 / #c7dba2`, **Spøgelse `#cfe6f2 / #c0dceb`** (the guide's "Månesten" blue, hue family of the night). Name `Display32` at frame bottom + 14; perk `Muted17`, 2 lines at 23.8 px line height.
* Selected card: lifted 8 px (y 145..579) with `RING_SEL` (3 px gold + 2 px ink): the ring reaches x 59 .. 1221 and y 140, inside the 48 px safe area on every side (the right-most ring ends 59 px from the edge).
* Bottom bar y 615..672: `SELECT_HERO_PREFIX` "Udseende:" (`Heavy18`) at x 64; hero chips (stadium, 53 px high, 2 lines: name **`Display20`** over the kind line **`Muted13`**, both variations of the BUILT theme (`tools/ui/build_theme.gd:141` / `:168`; the first draft used a Display17 and a Bold13 that are not in the scale: review defect 1, `UiAudit.rule_report(root)["typography"]` would have failed); selected = gold fill): for the ghost Bu 150.9..228.9 (78 px) and Hviske 238.9..341.1 (102 px), y 615..668, for the animal Rasmus 150.9..261.8 and Kiki 271.8..349.3 (measured with the real fonts); blurb `%HeroBlurb` (`Muted17`, <= 2 lines; it starts 14 px after the chip row of the SELECTED race, so its width is 541 px for the ghost with the Tilbage button (x 365..906) and 673 px without it (x 365..1038); the narrowest bar is Fe with 477 px; all eight blurbs fit at every race's width, `notes/blurb_fit.txt`); `%BackButton` 120 px at x 920..1040; `%NextButton` 164 px at x 1052..1216 (y 615..668, hard shadow to 672); `HintBar` centred at y 692; `%ToastStack` as P28 places it.
* Unique names: `%AnimalButton %FairyButton %HobbitButton %GhostButton` (+ `%GhostFace %GhostName %GhostPerk`), `%HeroChip1 %HeroChip2 %HeroBlurb %NextButton %BackButton`; `tests/lib/flow.gd` presses `%GhostButton`.

### 6.3 Focus map (pattern T for the cards, pattern L for the bar, as UI_NAVIGATION 3.4)
| from | Left | Right | Up | Down | Accept | Esc / B / Start |
|---|---|---|---|---|---|---|
| card Skovdyr | card Spøgelse (wrap), selects | card Fe, selects | selected hero chip (ring) | selected hero chip | = Videre | title (focus Nyt spil) |
| card Fe / Halvling | previous card | next card | selected hero chip (ring) | selected hero chip | = Videre | same |
| card Spøgelse | Halvling | Skovdyr (wrap), selects | selected hero chip (ring) | selected hero chip | = Videre | same |
| hero chip 1 / 2 | previous in the bar (chip 1 -> Videre by wrap) | next in the bar | selected card | selected card (two-row ring) | selects the hero, focus -> Videre | same |
| Tilbage | last chip | Videre | selected card | selected card | title | same |
| Videre | Tilbage | first chip (wrap) | selected card | selected card | page 2 | same |
Initial focus: the SELECTED card (Skovdyr on entry, the remembered race after coming back from page 2). Cards are ONE radio group in enum order (selection follows focus, hover never selects, a click selects and focuses). Chips are radio and select while moving. `ui_page_down` / RB = Videre, `ui_page_up` / LB = Tilbage. Gamepad: D-pad / left stick, A accept, B back. No new input action. **Up on a card goes to the selected hero chip** (review defect 9: the first draft left it a dead end; `UI_NAVIGATION.md` 3.4 says `ui_up` from the first item of the first group goes to the LAST group, and `UiAudit` reports a dead end where a wrap is required): with two groups (cards, bottom bar) Up and Down from a card are the same move, the two-row ring S04 already uses for the bar. **Hint: unchanged**, `[←→] Vælg · [Enter] Videre · [Esc] Tilbage` (the first draft added `[↓] Udseende`, a hint that no package defines and the reference render did not show).

### 6.4 Page 2
Unchanged apart from the read-only preview card (320 wide, the card of page 1 with the chosen hero's stock sprite: the ghost frame is the moon-blue stripe). `start_new_game(name, GHOST, farm, skin)` with the 4th argument, `skin` = `ghost_bu` or `ghost_hviske`.

### 6.5 Checks
`menus.select_four_cards_layout_rects` (card x 64 / 358 / 652 / 946 +-1, width 270 +-1, frame 238 +-1, footer y), `menus.select_four_cards_wrap`, `menus.select_focus_map_four`, `menus.hero_chips_two_per_race`, `menus.hero_blurb_fits_two_lines`, `menus.new_game_all_eight_heroes` (4 races x 2 chips through real key events AND real pad events), `menus.guide_diff_select` against `tests/checkpoints/guide_ref_ghost/select_4cards.png` (target 12 re-pinned at the first windowed build, `pinned_after_lead_review`).

### 6.6 AMENDMENT TEXT for `docs/design/UI_NAVIGATION.md` (the task text says "S03 / S04": in the file S03 is the language card; the select cards are **S04 `select_1`** and **S05 `select_2`**; RG7 applies this)
Replace the Layout / Focus / Keys / Hint / Checks bullets of **S04** by:

> * **Layout** (1280x720 on `#e7d8b6`, padding 48 / 64, gap 28; FOUR races, amendment of the ghost addendum): header `CHAR_SELECT_TITLE` "Hvem er du?" (`Display48`) at (64, 48) + `CHAR_SELECT_SUBTITLE` (`Subtitle` 20) at y 101 left, counter "1 / 2" (`EyebrowL`) right-aligned to x 1216; four `CardButton`s `%AnimalButton` ("Skovdyr"), `%FairyButton`, `%HobbitButton` ("Halvling"), `%GhostButton` ("Spøgelse") in ONE row of a 4-column grid, **gap 24** (the guide's 3 columns have gap 32): card 270 x 434 at x 64 / 358 / 652 / 946, y 153..587, padding 16, gap 14, parchment, 2 px ink, radius 18; frame 238 x 304.4 = `TTSpriteFace` of the real stock sprite of the selected hero (fox / fairy / hobbit_pip / ghost_bu; the equipped bust `assets/portraits/<base>.webp` when it exists), direction SE, `sprite_scale` 1.25, `feet_y` .93, stripes in the race tint (the ghost: `#cfe6f2` / `#c0dceb`); name `Display32`; perk text `Muted17` (two lines at 238 px for all four); **the selected card lifts 8 px and shows RING_SEL** (reaches x 59 .. 1221, y 140: inside the safe area). Bottom bar (y 615..672): `SELECT_HERO_PREFIX` "Udseende:" (`Heavy18`) + the two hero chips of the SELECTED race `%HeroChip1 %HeroChip2` (53 px high; name `Display20` over the kind `Muted13`, both theme variations; Skovdyr Rasmus / Kiki, Fe Kløvermynte / Birk, Halvling Bertil / Bodil, Spøgelse Bu / Hviske; gold when selected), `%HeroBlurb` (`Muted17`, at most 2 lines; it starts after the chip row of the selected race, 477 .. 544 px wide with the Tilbage button) in the free middle, `%BackButton` (120 px, x 920..1040) and `%NextButton` (`ButtonPrimary` L "Videre ▸", 164 px, x 1052..1216), a `HintBar` centred at y 692 and a `%ToastStack`. **The guide's mock has three cards, no Tilbage button and no hint line; the `select_guide4` fixture selects the ghost and hides `%BackButton`, the HintBar and the toasts; its reference is `tests/checkpoints/guide_ref_ghost/select_4cards.png`.**
> * **Focus.** Initial: the SELECTED card. Groups: cards (radio, pattern T, enum order Skovdyr, Fe, Halvling, Spøgelse, wrap both ways) -> bottom bar [hero chips..., Tilbage, Videre] (one horizontal row). Left / Right on a card: +/-1 with wrap, the card becomes selected (lift and ring follow); hover does not. Down AND Up from a card -> the selected hero chip (ring: `ui_up` from the first item of the first group goes to the last group); Up from the bottom bar -> the selected card; Down from the bottom bar -> the selected card (two-row ring). Left / Right in the bottom bar: +/-1 along the whole bar, wraps; chips are radio (select while moving).
> * **Keys.** Accept: card -> same as Videre (page 2); chip -> selects the hero and focuses Videre; Tilbage -> title; Videre -> page 2 (stores race and hero). Esc / B / Start -> title (focus: Nyt spil). `ui_page_down` / RB = Videre, `ui_page_up` / LB = Tilbage.
> * **Hint.** Unchanged: `[←→] Vælg · [Enter] Videre · [Esc] Tilbage`.
> * **Checks.** `menus.select_radio_focus_selects`, `menus.select_four_cards_layout_rects`, `menus.select_four_cards_wrap`, `menus.hero_chips_two_per_race`, `menus.hero_blurb_fits_two_lines` (per race), `menus.new_game_all_eight_heroes` (4 races x 2 hero chips, through real key events and real pad events), `menus.harness_unique_names`, focus_walk (cycle_right on the card row true, cycle_down true, no `dead_end`), `rule_report` clean (`typography`: only built variations), `ring_pixels` on the selected card, windowed `compare_guide select=` against `guide_ref_ghost/select_4cards.png` (target re-pinned at the first build; the old target 15 was against the three-card guide).

**S05**: only the preview changes: "left a read-only preview of the chosen race and hero (the card of page 1 at 320 wide, no focus, no hover; the ghost frame is the moon-blue stripe)". Other doc lines to edit (line numbers of the file at b909274): 577 (graph node: "cards · hero chips · Videre"), 706 (`select <= 15` -> "`select` re-based, see S04"), 972 (`new_game_flow_all_races`: "4 races x each hero chip"), 992-993 (`select_species_chips_all` -> `hero_chips_two_per_race`), 1201 (Q2: add the ghost to the playable cast).

## 7. In-world behaviour

### 7.1 Float and glide
* **Baked**: the bell's lowest lobes sit ~10 px above the pivot (the figure's lowest pixel is 206-214 px, window 197-216): with the hem on the ground the lowest pixel was 222 px and a first small hover still gave 216.6 in the hit clip: both FAILED `measure_cast`'s upright window (a 0.66 m skirt on the ground projects 22 px below the pivot); the final ~10 px hover passes at 214.2.
* **Runtime**: `GhostFloat.altitude(t, moving) = float_bob_px * (1 + sin(TAU * 0.55 t)) * (0.4 if moving else 1)` = 0 .. 5 px, written ONLY by Player2D's `_apply_altitude()` together with the hop and the fairy's flight altitude (`IsoChibiSprite2D.set_altitude`, `iso_chibi_sprite_2d.gd:475`; the shadow stays on the floor, fades and widens: the mechanism the Fe already uses). The baked idle bobs 1 px at 5 fps; the code bob is smooth.
* **Clips (all existing names, all baked, role `player`, clip set `full`)**: idle, walk, run, jump, fall, land, celebrate, interact, hit, sleep, talk = 47 frames x 8 directions. `update_motion` picks idle / walk / run / fall as for every race; `play_action` the others. **Not used: the flight clips** (`takeoff hover fly flight_land`): the ghost is not a flyer (`flyer false`), so no extra clips, no extra wardrobe groups. Walk / run get the ghost-only glide hook (hips bob x3 of the stock bob: 5 px measured against the fox's 3 and the hobbit's 2, lean, mittens paddle, wisp x2); the hook is a no-op for every other model (GLB sha256 of fox, bat, fairy equal with and without it: `notes/glide_hook_is_ghost_only.txt`).
* **Sleep** floats above the bed (honest); **hit** is the stock recoil.
### 7.2 Audio
No footstep sound exists for ANY race in the plan (P24's SFX hook list has none), so the ghost replaces nothing. The name `sfx/ghost_whoosh` is reserved (silent without a file).
### 7.3 The glow (evidence)
`proto/shot_ghost.gd` shot the night (23:00, zoom 0.4) with the prototype glow: an additive halo sprite (`Glow.halo_texture`) on all three ghosts and a `PointLight2D` (energy .42, scale .95) on all. First run: halo ALONE on Hviske was barely visible; halo + light on Bu read as a soft friendly glow that also lights the grass. Final shot `proto/gamezoom_check.png` (middle panel). Recommendation: **PointLight2D, energy 0.35, `texture_scale` 0.9 (radius 115 px), colour `bfe0ff`, no shadows**, energy = `glow_energy x area.night_factor` (the built DayNight rule: 0 at noon, ramps in at dusk) in iso areas and the constant `glow_energy_dark` 0.08 where `area.map.ambient` is `forest` or `cave` (the lantern is E 0.10 there). Budget: it is a PLAYER light like the lantern: 12 map lights + lantern + glow = 14 <= 15 (V8 measured 15 safe; the engine drops the 17th silently); the city's "<= 12 PointLight2D" is a MAP-light budget and is unchanged.
### 7.4 Water
The ghost only LOOKS floaty. Collisions are the figure ellipse of every race (`body_rx 25, body_ry 14.8`), ponds block it. The fairy's flight stays the only crossing perk. The whisper `GHOST_WHISPER_WATER` exists as a key and is a flagged stub (cut first).
### 7.5 Citizens
`context.race` (now `animal fairy hobbit ghost`) and `context.hero` join the dialogue context (P14). `RaceReactions.apply(npc_id, ctx, dialogue)` (late-bound from `Npc2D.interact`) prepends the first-meeting line of the nine NPCs; `RaceReactions.line_for("fairy_king", "intro", ctx)` gives the king's line after the letter. Data: `lua/config/race_reactions.lua` (`race_reactions.ghost.<npc_id> = {text_key, voice_key, when}`). No other race has a table (the structure is ready for them). Voice: text only until P24 (wave 6).

## 8. Mørkeskoven rules (what the ghost changes and where it plugs in)
Source rules: `DUNGEON_V2_ADDENDUM.md` 6.4 (lines 484-495). Oil `oil_seconds 150` per FIRST arrival of every floor and at every stone (`lua/config/race_perks.lua:81`), a `lantern_oil` item adds 60 s (`lua/items/consumables.lua:26`, 25 gold); drain only on a generated floor and never in a modal; `light_ratio = max(oil / max, 0.35)` (`oil_min_light`); the dark bites 1 half heart per 12 s at oil 0 but never below 2; lantern look colour `ffe9a8`, energy 0.10, radius 630 px at full oil, 220 px at the 35 % floor.
| rule | everybody else | ghost | plug-in |
|---|---|---|---|
| drain per second | 1 oil-s x assist x gem `oil_mult` | x **0.75** | DR1 `OilRules.oil_step(oil, dt, ctx)` gains `ctx.race_mult`; P06 passes `GhostRules.oil_use_mult(skin)` |
| one fill lasts | 150 s | **200 s** | derived |
| lantern radius, full oil | 630 px | **787.5 px** | P06: `OilRules.light_radius_px(oil, max, gem_mult, race_mult)` = 630 x ratio x gem x race |
| lantern radius, 35 % floor | 220.5 px | **275.6 px** | same |
| colour / energy | ffe9a8 / 0.10 | unchanged | V8 (not per race) |
| bite at oil 0 | 1 half heart / 12 s, floor 2 | unchanged | `adventure.oil_empty_hurt_interval 12` |
| ghost glow | - | 0.08 energy, `bfe0ff`, radius 115 px | `GhostGlow`, V8's light budget (player lights <= 2) |
| gentle defeat | wake at home, lose 10 % gold | unchanged | D0 |
The numbers in the "typical dive" computation of section 3 use the addendum's band run times (4.2 / 6.1 / 8.1 / 9.8 min per 3 floors) and payouts (107 / 360 / 335 / 669 gold); at 1.6 x the pace (clear everything) the ghost saves 236 gold of oil per dive.

## 9. Harness consequence
* `tests/run_playtest.sh --character=ghost` (flow.gd `CHARACTER_TYPES`, `UI_RACE %GhostButton`, `playtest.gd` argument check and usage, `run_playtest.sh` header, `drive.gd` comment, `fresh.gd` map, `shot_world.gd` map, `selftest_harness.sh`): section 11.
* MEASURED by the reviewer on the first draft: `tests/run_playtest.sh --character=ghost` WITH the boot stage fails with `button %GhostButton not found in CharacterSelect` and `boot.character_matches (type 0 for ghost)` as long as no select screen has the button (`review/logs/full_ghost.log`); the draft left the legacy screen unpatched until P16, which is M1b, so in M1a the ghost was reachable by tests only (review defect 2). **FINAL:** the lead patch SE-G5 (7 edits in `scripts/ui/character_select.gd` and `scenes/ui/character_select.tscn`) gives the legacy screen the button and the two looks; MEASURED: `--character=ghost --strict` WITH the boot stage = 17 sections, 2789 checks, 0 failed, 0 engine messages (`final_logs/full_ghost.log`, boot.character_matches ok). P16 rewrites both files later and keeps `%GhostButton`. Windowed look (one window, `impl/tools/windowed.sh`, driver `proto/shot_select_legacy.gd`): `proto/shots/legacy_select_ghost.png` shows the fourth button "Spøgelse" in the legacy dashed "selected" state, its perk sentence as the preview and Bu / Hviske in the dropdown (the legacy look is the pre-guide dark screen that P16 replaces; `proto/shots/legacy_select_animal.png` is the same screen with the animal).
* `tools/dev/selftest_harness.sh --all-characters`: 42 ok, 1 failed (`final_logs/full_selftest.log`), with the ghost in the list and `boot_2d_ghost` green: boot_2d_animal (exit 0, 4s); boot_2d_fairy (exit 0, 4s); boot_2d_hobbit (exit 0, 3s); boot_2d_ghost (exit 0, 4s). The one pre-existing failure (`live_known_issues_file_is_reported`) is on pristine main too (`notes/selftest_main_pristine.log`: 41 ok, 1 failed; `tests/lib/known_issues.txt` has no entries). The boot case used to match only `ok boot.phase_playing` with exit `*`, so a FAILED boot stage read as `ok boot_2d_ghost (exit 1)` (reviewer, `review/logs/selftest_all_chars.log`): the SE-G5 edit adds the must-not-match `FAIL(ED)? +boot\.`, so the case is red when any boot-stage check fails (MEASURED on a legacy screen without the button: the old line would have read ok, the new line is red, `final_logs/mut_boot_case_verdict.txt`). The ghost enters the `--all-characters` list in the SAME commit as the button (when = sel), never in the fix round.
* All "three heroes" runs of the plan become four: P27 `zz_acceptance` (one playthrough per character), F10 `zz_features`, I6 `zz_town` rows 31-39 (hobbit -10 %, the ghost pays the listed price), N01 / N02 / N04 / I2 / N08 acceptance commands, P06 gate, A2's same-palette ladder, F5's `three_heroes_all_slots` (now `wardrobe.heroes_all_slots` over `CharacterCatalog.heroes()`), P16's flow tests (`scripts/find_three_hero_pins.py` -> `notes/three_hero_pins.txt`, 66 hits). The ghost-specific numbers are asserted in `tests/sections/ghost.gd` (G-ghost-data) and `zz_ghost.gd` (G-ghost-qa).

## 10. Art plan and prototype report

### 10.1 What was built (the real pipeline, end to end)
`proto/builder/traetoppen_additions.py` (a standalone module of the generator's hook name; `PYTHONPATH` first) -> `generator/build_assets.py` (GLB, 7132 vertices, 13 048 triangles, 17 bones: Root Hips Spine Head, two eyes, three arm bones x2, five tail bones) -> `core/bake_sprite_atlases.py` (VTK, 36 degrees, 87.07 px/m, pack outline) -> `core/validate_new_assets.py` -> `export/export_game_assets.py` (WebP q97, S3TC stubs) -> `export/install_assets.py` -> `godot --import` -> windowed screenshot. Iterations (each looked at; images in `proto/`):
| step | change | verdict |
|---|---|---|
| v1 `v1_idle_rows.png` | bell lathe + stock dark eyes + wisp tube | already a ghost; eyes bulge as lumps in W / E, hem barely scalloped, hem on the ground: feet window FAILED (222 px), arms hug the body |
| v2 `v2_idle_rows.png` | hem lifted (hover), five scallops dropping .13, bigger mittens swung out, tapering wisp | reads as cute; 160 px = 96 % of the pack |
| v3 `v3_*_rows.png` | cooler brighter sheet, Hviske lilac, plumper wisp | friendly; Bu and Hviske too alike |
| v4 `v4_*_rows.png` | flatter eyes (z .055 instead of .098), blue / rose hem trim, lashes on Hviske | eyes read as eyes in profile; Hviske distinct |
| v5 `v5_walk_SE.png` `v5_run_SW.png` | glide hook (bob 5 px), hover +.05 so every clip passes the feet window (216.6 -> 214.2), head .64 x .575 | passes `measure_cast` |
| final | lashes removed, ONE smile, shy pupils: the two heroes share one silhouette (0.027 %) | real windowed shots; hem-fade experiment compared and rejected |

### 10.2 Cast gates (measured, `tools/art/characters/measure_cast.py --root ... ghost_bu ghost_hviske`)
height SE 160 px = **96 %** of the pack mean 167.4 (gate +-10 %); outline [75, 61, 73] / [76, 60, 72] = the pack's [76, 61, 71]; pivot x mean 127.4 .. 127.6 (want 127.5 +- 3); feet line 206.1 .. 214.2 over all 47 frames of 11 sheets (upright window 197 .. 216); `validate_new_assets.py` OK on masters and WebP, 11 clips, portrait 256 x 256 not cut at the top or sides. Palette dE00 1.3 / 1.1 (gate 6). Figure at game zoom 0.4: 46 x 64 px (fox 38 x 68, hobbit 40 x 68, fairy 50 x 65).
### 10.3 Bake budget and texture memory
Build + bake + both validators + export + install for BOTH heroes: 13.5 s, 11.0 s, 10.3 s wall (three runs, M3, load ~5; `notes/produce_all_run*.log`); 2.15 + 1.98 MB WebP; 6.7 MB PNG masters per hero. VRAM: `compress/mode=2` S3TC with mipmaps: **32.89 MB per hero with all 11 clips resident = hobbit_pip 32.90 MB**; the four warm clips (idle walk run interact) 12.6 MB; one hero per save. Wardrobe: section 5.
### 10.4 Bust / portrait
`portrait.webp` 256 x 256 from the 14 degree camera, default framing (nothing wide: no `fit_bust` shift needed), validated not cut at the top or sides; the guide's equipped-bust rule (A2) gives `assets/portraits/ghost_*_base.webp` with the starter shirt (trousers and boots invisible). Busts are in the contact sheet.
### 10.5 Translucent hem and S3TC alpha (tested, rejected)
`scripts/hem_fade.py` multiplied the alpha of the lowest 18 px of every frame (screen space: the camera is orthographic, so "the bottom of the figure" is the hem in all 8 directions) by a smooth ramp from 0.30 up; exported through the same exporter (WebP `alpha_quality=100`), imported as S3TC (`compress/mode=2`, `fix_alpha_border=true`, DXT5 keeps 8 interpolated alpha levels per 4 x 4 block), shown in the real game next to the opaque one at zoom 0.4 and 0.9: **no visible difference at game scale** (a 5.6 px band at 0.4) and it dims the scalloped trim. Rejected. If it is ever wanted: a `hem_fade` stat in the baker (P08) applied after the outline, the validator unchanged (it only checks the cell border), S3TC fine.
### 10.6 What is still weak (honest)
* Soft CG render in the pack's family, not hand-painted; next to the flat Figurer v2 cards (`proto/sketch_vs_baked.png`) the whole roster looks softer, the ghost no more than the others.
* The EYES: dark ovals with two white glints and NO white sclera (the 12 other figures have one). Cuter and more ghostly in the prototype; a taste decision (question GQ1).
* The stock-rig walk is a gentle glide, not an animation: 5 px bob, lean, paddling mittens, a swaying wisp.
* The back rows (N, NW, NE) are an egg with a wisp; the wisp reads as a tail from the side.
* Bu and Hviske differ by colour and a glance only (one silhouette on purpose, for the wardrobe).
* Damage flash (thorn-berry pink) has less contrast on Hviske.
* The hover gap is 4 px at zoom 0.4: visible, small.
* No baked glow (a baked halo is darkened by the night grade; the glow is a light).

### 10.6b Builder, tools, review sheets (package G-ghost-art)
`tools/art/ghost/{ghost_model.py, traetoppen_additions.py (shim, same module name as V2's cast_v2), produce_ghost.sh, measure_ghost.py, review/, README.md}`; the shim re-exports `BUILDERS`, `EXTRA_PATTERNS` (`sheet`), `EXTRA_CLIPS` (`walk`, `run` hooks); A2 imports `ghost_model` for the bases and registers the same hooks so `ghost_bu_base` animates like `ghost_bu`. Nothing in `tools/art/core`, `generator` or P21's folder is edited.

## 11. EVERY built test / file that pins three races, with the exact edit
`scripts/ghost_edits.py md` prints this table; `scripts/ghost_edits.py apply CLONE [--when fix,v1,sel]` applies it. The column **when** is the TIME of the edit: `fix` = the fix round (files of BUILT packages, before wave 3b), `v1` = the unbuilt owners of wave 4 (V1, V2), `sel` = the legacy-select patch SE-G5 and the self-test lines that need it (the lead, in the commit that lands V1). `scripts/dry_check_edits.py` checks every anchor against main read-only (61 edits, 0 problems). Measured failures are marked MEASURED in the "why" column: **3 built checks fail for every hero** (`characters.races_perk_keys_and_default_skins`, `characters.all ten skins ...`, `art_characters.roster_visuals_resolve`) and **1 only under `--character=ghost`** (`area.game_data_race_and_config`); everything else listed passes today but pins three (or, like `save.gd`'s loop and `perks.gd`, silently hides the ghost).
| # | when | owner (merged table) | file | what pins it / why | exact edit (before -> after) |
|---|---|---|---|---|---|
| 1 | fix | P02-bus-gamemanager-time (built) | `scripts/autoload/game_manager.gd` | the enum value is APPENDED: saves store the int (to_dict "character_type"), 0 1 2 never move | `enum CharacterType { ANIMAL, FAIRY, HOBBIT }` → `enum CharacterType { ANIMAL, FAIRY, HOBBIT, GHOST }` |
| 2 | fix | P02-bus-gamemanager-time (built) | `scripts/autoload/game_manager.gd` | default skin of the race (start_new_game with an empty skin) | `        CharacterType.HOBBIT: ⏎             return &"hobbit_pip" ⏎ ` → `        CharacterType.HOBBIT: ⏎             return &"hobbit_pip" ⏎         CharacterType.GHOST: ⏎             return &"ghost_bu" ⏎ ` |
| 3 | fix | P10-data-contracts (built) | `scripts/data/perks.gd` | without it Perks._race() CLAMPS index 3 to 2 and gives the ghost the HOBBIT discount (and CraftingSystem.bake_bonus_chance the hobbit bake bonus): a silent leak, asserted by ghost.no_hobbit_perks_leak | `const RACE_KEYS := ["animal", "fairy", "hobbit"]       # GameManager.CharacterType 0 1 2` → `const RACE_KEYS := ["animal", "fairy", "hobbit", "ghost"]       # GameManager.CharacterType 0 1 2 3` |
| 4 | fix | P04-area-framework (built) | `scripts/world2d/game_data.gd` | fallback of GameData.race_key() when the enum name is not found in characters.lua | `const RACE_KEYS := {0: "animal", 1: "fairy", 2: "hobbit"}` → `const RACE_KEYS := {0: "animal", 1: "fairy", 2: "hobbit", 3: "ghost"}` |
| 5 | fix | P04-area-framework (built) | `scripts/world2d/game_data.gd` | last-resort pack stand-in of a race (the paleish round pack figure) | `const FALLBACK_VISUALS := {"animal": "fox", "fairy": "fairy", "hobbit": "raccoon"}` → `const FALLBACK_VISUALS := {"animal": "fox", "fairy": "fairy", "hobbit": "raccoon", "ghost": "rabbit"}` |
| 6 | v1 | V1-cast-data | `lua/config/characters.lua` | the race row (GameData.race_key() = lower-case enum name must find it) | `      hobbit = { name_key = "CHAR_HOBBIT_NAME", perk_key = "CHAR_HOBBIT_PERK", default_skin = "hobbit_pip" }, ⏎ ` → `      hobbit = { name_key = "CHAR_HOBBIT_NAME", perk_key = "CHAR_HOBBIT_PERK", default_skin = "hobbit_pip" }, ⏎       ghost = { name_key = "CHAR_GHOST_NAME", perk_key = "CHAR_GHOST_PERK", default_skin = "ghost_bu" }, ⏎ ` |
| 7 | v1 | V1-cast-data | `lua/config/characters.lua` | two skins; visual = the wardrobe-ready base (A2), fallback = the pack figure at the END of the chain (data.gd rule: every chain ends at a pack character) | `      hobbit_bramble = { race = "hobbit", name_key = "SKIN_HOBBIT_BRAMBLE", visual = "hobbit_bramble_base", fallback = "raccoon", wardrobe_body = "hobbit_bramble" }, ⏎ ` → `      hobbit_bramble = { race = "hobbit", name_key = "SKIN_HOBBIT_BRAMBLE", visual = "hobbit_bramble_base", fallback = "raccoon", wardrobe_body = "hobbit_bramble" }, ⏎       ghost_bu = { race = "ghost", name_key = "SKIN_GHOST_BU", visual = "ghost_bu_ ...` |
| 8 | v1 | V1-cast-data | `lua/config/characters.lua` | base -> stock sheet of the same body until A2 bakes the base | `      hobbit_bramble_base = "hobbit_bramble", ⏎ ` → `      hobbit_bramble_base = "hobbit_bramble", ⏎       ghost_bu_base = "ghost_bu", ⏎       ghost_hviske_base = "ghost_hviske", ⏎ ` |
| 9 | v1 | V1-cast-data | `lua/config/characters.lua` | stock sheet -> pack stand-in while the art is missing (never used once G-ghost-art has landed) | `      hobbit_bramble = "raccoon", ⏎ ` → `      hobbit_bramble = "raccoon", ⏎       ghost_bu = "rabbit", ⏎       ghost_hviske = "rabbit", ⏎ ` |
| 10 | v1 | V1-cast-data | `lua/config/race_perks.lua` | EVERY race defines EVERY perk key (file header rule): the eight new keys, neutral for the animal | `      bake_bonus = 0.0,              -- extra output chance in the crafting category bake ⏎     }, ⏎     -- Fairy` → `      bake_bonus = 0.0,              -- extra output chance in the crafting category bake ⏎       run_cost_mult = 1.0,           -- running energy cost x this (ghost 0.6) ⏎       oil_use_mult = 1.0,            -- lantern oil drain x this in Moerkesko ...` |
| 11 | v1 | V1-cast-data | `lua/config/race_perks.lua` | neutral new keys for the fairy | `      shop_discount = 0.0, ⏎       bake_bonus = 0.0, ⏎     }, ⏎     -- Hobbit` → `      shop_discount = 0.0, ⏎       bake_bonus = 0.0, ⏎       run_cost_mult = 1.0, ⏎       oil_use_mult = 1.0, ⏎       dark_light_mult = 1.0, ⏎       float_bob_px = 0.0, ⏎       glow_energy = 0.0, ⏎       glow_energy_dark = 0.0, ⏎       glow_scale = 0 ...` |
| 12 | v1 | V1-cast-data | `lua/config/race_perks.lua` | the ghost row + the neutral values of the hobbit | `      bake_bonus = 0.25,             -- +25% chance of one more output in the crafting category bake (P12) ⏎     }, ⏎   }, ⏎ ` → `      bake_bonus = 0.25,             -- +25% chance of one more output in the crafting category bake (P12) ⏎       run_cost_mult = 1.0, ⏎       oil_use_mult = 1.0, ⏎       dark_light_mult = 1.0, ⏎       float_bob_px = 0.0, ⏎       glow_energy = 0.0,  ...` |
| 13 | fix | P09-test-harness (built) | `tests/lib/flow.gd` | --character=ghost, t.character_type(), boot() | `const CHARACTER_TYPES := {"animal": 0, "fairy": 1, "hobbit": 2}` → `const CHARACTER_TYPES := {"animal": 0, "fairy": 1, "hobbit": 2, "ghost": 3}` |
| 14 | fix | P09-test-harness (built) | `tests/lib/flow.gd` | the unique node name P16 must give the fourth race card (boot() presses it; until P16 builds it the ghost boot stage fails with "button %GhostButton not found") | `const UI_RACE := {"animal": "%AnimalButton", "fairy": "%FairyButton", "hobbit": "%HobbitButton"}` → `const UI_RACE := {"animal": "%AnimalButton", "fairy": "%FairyButton", "hobbit": "%HobbitButton", "ghost": "%GhostButton"}` |
| 15 | fix | P09-test-harness (built) | `tests/lib/flow.gd` | doc comment | `## 0 animal, 1 fairy, 2 hobbit (GameManager.CharacterType).` → `## 0 animal, 1 fairy, 2 hobbit, 3 ghost (GameManager.CharacterType).` |
| 16 | fix | P09-test-harness (built) | `tests/lib/flow.gd` | usage text | `fail("unknown character '%s' (animal\|fairy\|hobbit)" % character)` → `fail("unknown character '%s' (animal\|fairy\|hobbit\|ghost)" % character)` |
| 17 | fix | P09-test-harness (built) | `tests/playtest.gd` | the argument check; tools/dev/selftest_harness.sh pins the message | `if _character not in ["animal", "fairy", "hobbit"]: ⏎                 return "--character must be animal, fairy or hobbit (got '%s')" % _character` → `if _character not in ["animal", "fairy", "hobbit", "ghost"]: ⏎                 return "--character must be animal, fairy, hobbit or ghost (got '%s')" % _character` |
| 18 | fix | P09-test-harness (built) | `tests/playtest.gd` | header comment | `##   tests/run_playtest.sh [--character=animal\|fairy\|hobbit] [--only=core,farm] [--list] [--windowed ...]` → `##   tests/run_playtest.sh [--character=animal\|fairy\|hobbit\|ghost] [--only=core,farm] [--list] [--windowed ...]` |
| 19 | fix | P09-test-harness (built) | `tests/playtest.gd` | header comment | `##   --character=animal\|fairy\|hobbit   hero for the boot stage and t.character (default animal)` → `##   --character=animal\|fairy\|hobbit\|ghost   hero for the boot stage and t.character (default animal)` |
| 20 | fix | P09-test-harness (built) | `tests/playtest.gd` | usage line | `print("usage: tests/run_playtest.sh [--character=animal\|fairy\|hobbit] [--only=a,b]` → `print("usage: tests/run_playtest.sh [--character=animal\|fairy\|hobbit\|ghost] [--only=a,b]` |
| 21 | fix | P09-test-harness (built) | `tests/run_playtest.sh` | header comment | `#   tests/run_playtest.sh [--character=animal\|fairy\|hobbit] [--only=core,farm] [--list]` → `#   tests/run_playtest.sh [--character=animal\|fairy\|hobbit\|ghost] [--only=core,farm] [--list]` |
| 22 | fix | P09-test-harness (built) | `tests/lib/drive.gd` | doc comment | `## Hero the run was started with: "animal" \| "fairy" \| "hobbit" (--character=).` → `## Hero the run was started with: "animal" \| "fairy" \| "hobbit" \| "ghost" (--character=).` |
| 23 | fix | P09-test-harness (built) | `tools/dev/selftest_harness.sh` | pins the usage message | `run_case bad_character_is_usage_error 2 30 'must be animal, fairy or hobbit' '' --character=dragon` → `run_case bad_character_is_usage_error 2 30 'must be animal, fairy, hobbit or ghost' '' --character=dragon` |
| 24 | sel | P09-test-harness (built) | `tools/dev/selftest_harness.sh` | self-test list of heroes. TIME: with the legacy-select patch (SE-G5), NOT in the fix round: before %GhostButton exists the boot case of the ghost cannot be green. MEASURED on the review clone: `ok boot_2d_ghost (exit 1)` while the boot stage failed with "button %GhostButton not found in CharacterSelect" (the case matched only `ok boot.phase_playing` with exit *); the next edit makes that case red. PRE-EXISTING and unrelated: `live_known_issues_file_is_reported` fails on pristine main (41 ok, 1 failed) because tests/lib/known_issues.txt has no entries | `[ "$ALL_CHARS" = 1 ] && CHARS="animal fairy hobbit" ⏎ ` → `[ "$ALL_CHARS" = 1 ] && CHARS="animal fairy hobbit ghost" ⏎ ` |
| 25 | sel | P09-test-harness (built) | `tools/dev/selftest_harness.sh` | the boot_2d_<hero> case (exit * on purpose: the legacy sections of its directory may fail) now also FAILS when any boot-stage check of the hero fails (boot.character_matches, a missing race button): a red boot stage can no longer read as ok. TIME: sel | `run_case "boot_2d_$c" "*" 120 'ok +boot\.phase_playing' '' --character="$c" --sections-dir="$ST/legacy"` → `run_case "boot_2d_$c" "*" 120 'ok +boot\.phase_playing' 'FAIL(ED)? +boot\.' --character="$c" --sections-dir="$ST/legacy"` |
| 26 | fix | F1-feature-data (built) | `tests/lib/features/fresh.gd` | Fresh.new_game(t) maps --character to the enum; an unknown name silently gave 0 (animal): the ghost would have been tested as a fox | `return {"animal": 0, "fairy": 1, "hobbit": 2}.get(character, 0)` → `return {"animal": 0, "fairy": 1, "hobbit": 2, "ghost": 3}.get(character, 0)` |
| 27 | fix | F1-feature-data (built) | `tests/lib/features/fresh.gd` | doc comment | `##   Fresh.new_game(t)                          t.new_game("animal"\|"fairy"\|"hobbit" per --character)` → `##   Fresh.new_game(t)                          t.new_game("animal"\|"fairy"\|"hobbit"\|"ghost" per --character)` |
| 28 | fix | P04-area-framework (built) | `tests/shot_world.gd` | screenshot driver --character= (an unknown name gave the animal) | `character = {"animal": 0, "fairy": 1, "hobbit": 2}.get(a.get_slice("=", 1), 0)` → `character = {"animal": 0, "fairy": 1, "hobbit": 2, "ghost": 3}.get(a.get_slice("=", 1), 0)` |
| 29 | fix | P04-area-framework (built) | `tests/shot_world.gd` | comment | `var character := 0          # GameManager.CharacterType: 0 animal 1 fairy 2 hobbit` → `var character := 0          # GameManager.CharacterType: 0 animal 1 fairy 2 hobbit 3 ghost` |
| 30 | fix | P09-test-harness (built) | `tests/lib/ui_screens.json` | the guide shows THREE cards: with four the diff against pw1x_select.png cannot stay <= 15 (a Tilbage button alone was +0.425 of 0.42 headroom). The reference becomes the 4-card layout of design4/proto/select_4cards_fixture.png; the target is re-pinned at the first windowed build | `            "compare": { ⏎                 "screen": "select", ⏎                 "fixture": "select_guide", ⏎                 "target": 15.0 ⏎             },` → `            "compare": { ⏎                 "baseline": "tests/checkpoints/guide_ref_ghost/select_4cards.png", ⏎                 "fixture": "select_guide4", ⏎                 "no_frame_crop": true, ⏎                 "target": 12.0, ⏎                 " ...` |
| 31 | fix | P04-area-framework (built) | `scripts/world2d/game_data.gd` | doc comment of race_key() | `## "animal" \| "fairy" \| "hobbit": the enum name of GameManager.character_type, checked against lua/config/characters.lua `races`.` → `## "animal" \| "fairy" \| "hobbit" \| "ghost": the enum name of GameManager.character_type, checked against lua/config/characters.lua `races`.` |
| 32 | fix | P04-area-framework (built) | `tests/shot_world.gd` | usage line of the screenshot driver (the argument itself is edit "--character= ... gave the animal") | `[--character=animal\|fairy\|hobbit] [--part=fixtures\|cast\|rim\|farm\|hyggebyen\|forest]` → `[--character=animal\|fairy\|hobbit\|ghost] [--part=fixtures\|cast\|rim\|farm\|hyggebyen\|forest]` |
| 33 | v1 | V1-cast-data | `lua/config/race_perks.lua` | header comment | `Race ids: animal fairy hobbit ⏎ -- (GameManager.CharacterType 0 1 2).` → `Race ids: animal fairy hobbit ghost ⏎ -- (GameManager.CharacterType 0 1 2 3).` |
| 34 | v1 | V1-cast-data | `lua/config/characters.lua` | comment of the races table | `    -- The three races of "Vaelg figur".` → `    -- The four races of "Vaelg figur".` |
| 35 | v1 | V1-cast-data | `scripts/isometric/character_catalog.gd` | the only edit of character_catalog.gd (id-driven code, doc comment of race()) | `## Race table row (name_key, perk_key, default_skin) of "animal" \| "fairy" \| "hobbit".` → `## Race table row (name_key, perk_key, default_skin) of "animal" \| "fairy" \| "hobbit" \| "ghost".` |
| 36 | sel | P16-ui-menus (SE-G5: lead patch before P16; P16 rewrites both files) | `scripts/ui/character_select.gd` | header comment | `## Character selection screen: Animal, Fairy, or Hobbit.` → `## Character selection screen: Animal, Fairy, Hobbit or Ghost (P16 replaces this legacy screen by the four-card page).` |
| 37 | sel | P16-ui-menus (SE-G5: lead patch before P16; P16 rewrites both files) | `scripts/ui/character_select.gd` | the fourth race button (the unique name the harness boot stage presses: tests/lib/flow.gd UI_RACE) | `@onready var hobbit_btn: Button = %HobbitButton ⏎ ` → `@onready var hobbit_btn: Button = %HobbitButton ⏎ @onready var ghost_btn: Button = %GhostButton ⏎ ` |
| 38 | sel | P16-ui-menus (SE-G5: lead patch before P16; P16 rewrites both files) | `scripts/ui/character_select.gd` | the two looks of the ghost in the skin dropdown (keys of ghost.csv) | `        {"id": &"hobbit_bramble", "name_key": "SKIN_HOBBIT_BRAMBLE"}, ⏎     ], ⏎ }` → `        {"id": &"hobbit_bramble", "name_key": "SKIN_HOBBIT_BRAMBLE"}, ⏎     ], ⏎     CharacterType.GHOST: [ ⏎         {"id": &"ghost_bu", "name_key": "SKIN_GHOST_BU"}, ⏎         {"id": &"ghost_hviske", "name_key": "SKIN_GHOST_HVISKE"}, ⏎     ], ⏎ }` |
| 39 | sel | P16-ui-menus (SE-G5: lead patch before P16; P16 rewrites both files) | `scripts/ui/character_select.gd` | connect + label from the loc key (the scene carries no Danish literal for the new button) | `    hobbit_btn.pressed.connect(func(): _select_type(CharacterType.HOBBIT)) ⏎ ` → `    hobbit_btn.pressed.connect(func(): _select_type(CharacterType.HOBBIT)) ⏎     ghost_btn.pressed.connect(func(): _select_type(CharacterType.GHOST)) ⏎     ghost_btn.text = tr("CHAR_GHOST_NAME") ⏎ ` |
| 40 | sel | P16-ui-menus (SE-G5: lead patch before P16; P16 rewrites both files) | `scripts/ui/character_select.gd` | the legacy screen disables the button of the selected race | `    hobbit_btn.disabled = type == CharacterType.HOBBIT ⏎ ` → `    hobbit_btn.disabled = type == CharacterType.HOBBIT ⏎     ghost_btn.disabled = type == CharacterType.GHOST ⏎ ` |
| 41 | sel | P16-ui-menus (SE-G5: lead patch before P16; P16 rewrites both files) | `scripts/ui/character_select.gd` | preview texts: the race card perk line stands in for the legacy *_DESC paragraph | `            preview_desc.text = tr("CHAR_HOBBIT_DESC") ⏎ ` → `            preview_desc.text = tr("CHAR_HOBBIT_DESC") ⏎         CharacterType.GHOST: ⏎             preview_label.text = tr("CHAR_GHOST_NAME") ⏎             preview_desc.text = tr("CHAR_GHOST_PERK") ⏎ ` |
| 42 | sel | P16-ui-menus (SE-G5: lead patch before P16; P16 rewrites both files) | `scenes/ui/character_select.tscn` | the node %GhostButton in the race button row | `[node name="HobbitButton" type="Button" parent="HBoxContainer/LeftPanel/TypeButtons"] ⏎ unique_name_in_owner = true ⏎ layout_mode = 2 ⏎ size_flags_horizontal = 3 ⏎ text = "Hobbit" ⏎ ` → `[node name="HobbitButton" type="Button" parent="HBoxContainer/LeftPanel/TypeButtons"] ⏎ unique_name_in_owner = true ⏎ layout_mode = 2 ⏎ size_flags_horizontal = 3 ⏎ text = "Hobbit" ⏎  ⏎ [node name="GhostButton" type="Button" parent="HBoxContainer/Left ...` |
| 43 | v1 | V1-cast-data | `tests/sections/characters.gd` | SKIN_CHAINS: the two chains (measured: characters.all ten skins fails without it) | `    "hobbit_bramble": ["hobbit_bramble_base", "hobbit_bramble", "raccoon"], ⏎ }` → `    "hobbit_bramble": ["hobbit_bramble_base", "hobbit_bramble", "raccoon"], ⏎     "ghost_bu": ["ghost_bu_base", "ghost_bu", "rabbit"], ⏎     "ghost_hviske": ["ghost_hviske_base", "ghost_hviske", "rabbit"], ⏎ }` |
| 44 | v1 | V1-cast-data | `tests/sections/characters.gd` | WARDROBE_BODIES | `    "hobbit_pip": "hobbit_pip", "hobbit_moss": "hobbit_moss", "hobbit_bramble": "hobbit_bramble", ⏎ }` → `    "hobbit_pip": "hobbit_pip", "hobbit_moss": "hobbit_moss", "hobbit_bramble": "hobbit_bramble", ⏎     "ghost_bu": "ghost_bu", "ghost_hviske": "ghost_hviske", ⏎ }` |
| 45 | v1 | V1-cast-data | `tests/sections/characters.gd` | the stock sheets the scenarios simulate | `const NEW_STOCK_IDS: Array[String] = ["squirrel", "fairy_stardust", "fairy_dusk", "hobbit_pip", "hobbit_moss", "hobbit_bramble"]` → `const NEW_STOCK_IDS: Array[String] = ["squirrel", "fairy_stardust", "fairy_dusk", "hobbit_pip", "hobbit_moss", "hobbit_bramble", "ghost_bu", "ghost_hviske"]` |
| 46 | v1 | V1-cast-data | `tests/sections/characters.gd` | MEASURED FAILURE characters.races_perk_keys_and_default_skins (races.size() == 3) | `var ok := races.size() == 3 ⏎     for race in ["animal", "fairy", "hobbit"]:` → `var ok := races.size() == 4 ⏎     for race in ["animal", "fairy", "hobbit", "ghost"]:` |
| 47 | v1 | V1-cast-data | `tests/sections/characters.gd` | detail text | `t.check("races_perk_keys_and_default_skins", ok, "animal -> %s, fairy -> %s, hobbit -> %s" % [Catalog.default_skin("animal"), Catalog.default_skin("fairy"), Catalog.default_skin("hobbit")])` → `t.check("races_perk_keys_and_default_skins", ok, "animal -> %s, fairy -> %s, hobbit -> %s, ghost -> %s" % [Catalog.default_skin("animal"), Catalog.default_skin("fairy"), Catalog.default_skin("hobbit"), Catalog.default_skin("ghost")])` |
| 48 | v1 | V1-cast-data | `tests/sections/characters.gd` | the default-skin pin | `t.expect_eq([Catalog.default_skin("animal"), Catalog.default_skin("fairy"), Catalog.default_skin("hobbit")], ["animal_fox", "fairy_meadow", "hobbit_pip"], "race -> default skin (plan 3.8)")` → `t.expect_eq([Catalog.default_skin("animal"), Catalog.default_skin("fairy"), Catalog.default_skin("hobbit"), Catalog.default_skin("ghost")], ["animal_fox", "fairy_meadow", "hobbit_pip", "ghost_bu"], "race -> default skin (plan 3.8)")` |
| 49 | v1 | V1-cast-data | `tests/sections/characters.gd` | MEASURED FAILURE (the skin list now has 12 rows): V1 makes it 15 with its retired rows and the monkey / birk / bodil skins; the ghost adds exactly +2 | `t.expect_eq(skins, want, "all ten skins are in characters.lua")` → `t.expect_eq(skins, want, "all twelve skins are in characters.lua")` |
| 50 | v1 | V1-cast-data | `tests/sections/characters.gd` | detail text | `"fox rabbit hedgehog squirrel hobbit_* fairy fairy_stardust fairy_dusk")` → `"fox rabbit hedgehog squirrel hobbit_* fairy fairy_stardust fairy_dusk ghost_*")` |
| 51 | fix | P04-area-framework (built) | `tests/sections/area.gd` | MEASURED FAILURE area.game_data_race_and_config under --character=ghost (the only failure that depends on the run's hero) | `GameData.race_key() in ["animal", "fairy", "hobbit"]` → `GameData.race_key() in ["animal", "fairy", "hobbit", "ghost"]` |
| 52 | v1 | V2-cast-art | `tests/sections/art_characters.gd` | MEASURED FAILURE art_characters.roster_visuals_resolve: a skin of characters.lua that is not in this table is reported as "draws through a fallback". ROSTER and the counts stay untouched; the ghost art checks live in tests/sections/art_ghost.gd | `    "fairy_meadow": ["fairy_base", "fairy"], ⏎ }` → `    "fairy_meadow": ["fairy_base", "fairy"], ⏎     "ghost_bu": ["ghost_bu_base", "ghost_bu", "rabbit"], "ghost_hviske": ["ghost_hviske_base", "ghost_hviske", "rabbit"], ⏎ }` |
| 53 | fix | P02-bus-gamemanager-time (built) | `tests/sections/core.gd` | default skin of the new race | `    var hobbit_skin: StringName = gm.character_skin ⏎ ` → `    var hobbit_skin: StringName = gm.character_skin ⏎     gm.start_new_game("G", gm.CharacterType.GHOST, "F") ⏎     var ghost_skin: StringName = gm.character_skin ⏎ ` |
| 54 | fix | P02-bus-gamemanager-time (built) | `tests/sections/core.gd` | the pin | `animal_skin == &"animal_fox" and hobbit_skin == &"hobbit_pip" and explicit_skin == &"fairy_dusk", "animal %s hobbit %s explicit %s" % [animal_skin, hobbit_skin, explicit_skin])` → `animal_skin == &"animal_fox" and hobbit_skin == &"hobbit_pip" and ghost_skin == &"ghost_bu" and explicit_skin == &"fairy_dusk", "animal %s hobbit %s ghost %s explicit %s" % [animal_skin, hobbit_skin, ghost_skin, explicit_skin])` |
| 55 | fix | P15-save-system (built) | `tests/sections/save.gd` | the slot summary is tried for every race (it passed with 3 only because the loop stopped before the ghost) | `    for type_id in 3: ⏎         gm.start_new_game("X", type_id, "F")` → `    for type_id in 4: ⏎         gm.start_new_game("X", type_id, "F")` |
| 56 | fix | P15-save-system (built) | `tests/sections/save.gd` | the pin | `kinds.has("animal") and kinds.has("fairy") and kinds.has("hobbit"), "%s" % [kinds.keys()])` → `kinds.has("animal") and kinds.has("fairy") and kinds.has("hobbit") and kinds.has("ghost"), "%s" % [kinds.keys()])` |
| 57 | v1 | V1-cast-data | `tests/sections/data.gd` | the race loop of config_documented_keys / race_perks_complete / race_skins_match_characters (it passed without the ghost: it just did not look at it) | `const RACES := ["animal", "fairy", "hobbit"]` → `const RACES := ["animal", "fairy", "hobbit", "ghost"]` |
| 58 | v1 | V1-cast-data | `tests/sections/data.gd` | PERK_KEYS: the eight new keys must exist on every race | `"talks_to_flowers", "shop_discount", "bake_bonus", "species", "skins", "default_skin"]` → `"talks_to_flowers", "shop_discount", "bake_bonus", "run_cost_mult", "oil_use_mult", "dark_light_mult", "float_bob_px", "glow_energy", "glow_energy_dark", "glow_scale", "glow_color", "species", "skins", "default_skin"]` |
| 59 | v1 | V1-cast-data | `tests/sections/data.gd` | a race with two skins failed ">= 3" (V1 rewrites this line to species == heroes; the ghost needs the bound >= 2) | `t.expect(skins.size() >= 3 and species.size() == skins.size() and str(cfg.get("default_skin", "")) in skins,` → `t.expect(skins.size() >= 2 and species.size() == skins.size() and str(cfg.get("default_skin", "")) in skins,` |
| 60 | v1 | V1-cast-data | `tests/sections/data.gd` | message | `"animal, fairy and hobbit define every perk key (neutral values where the race has no perk)")` → `"animal, fairy, hobbit and ghost define every perk key (neutral values where the race has no perk)")` |
| 61 | v1 | V1-cast-data | `tests/sections/data.gd` | the pins of the ghost numbers; "only the hobbit has discount and bake perks" now includes the ghost | `    var only_hobbit_discounts: bool = animal["shop_discount"] == 0.0 and fairy["shop_discount"] == 0.0 and animal["bake_bonus"] == 0.0 and fairy["bake_bonus"] == 0.0` → `    var ghost: Dictionary = _lr.get_config("race_perks.ghost", {}) ⏎     t.expect(ghost["run_cost_mult"] == 0.6 and ghost["oil_use_mult"] == 0.75 and ghost["dark_light_mult"] == 1.25 and ghost["float_bob_px"] == 2.5 and ghost["glow_energy"] == 0.35 a ...` |


Files that look like pins but need NO edit (verified): `scripts/autoload/save_manager.gd`, `scripts/economy/crafting_system.gd`, `scripts/economy/shop_system.gd`, `scripts/isometric/iso_chibi_sprite_2d.gd` (id-driven; `character_catalog.gd` gets ONE doc-comment line, see the table), `tests/sections/economy.gd` and `rarity.gd` (they set `character_type` explicitly), `tests/sections/ui_audit*.gd` / `ui_foundation.gd` (they name `CHAR_HOBBIT_NAME` only), `tools/art/characters/measure_cast.py` (the ghost is measured by `tools/art/ghost/measure_ghost.py`, PEOPLE is not edited), `tools/features/validate/validate.py` (R8 names the hobbit discount in a message only), `tools/ui/scenes/screens/s_select.gd` (P07's spike builder still builds three cards; P16 builds the real scene, see 6.6). Stale "three races" COMMENTS that no check reads are in the table too (review defect 11): `race_perks.lua` header, `characters.lua` races comment, `shot_world.gd` usage line, `game_data.gd` race_key() doc, `character_catalog.gd` race() doc.
The pins of UNBUILT packages (acceptance texts, matrices, key art) are the amendments AQ-* / AG* of `ghost_packages.json`.

## 12. Packages, waves, milestones, ownership

| id | wave | size | owns | role |
|---|---|---|---|---|
| G-ghost-data | 3b | S | `localization/ghost.csv`, `localization/ghost.csv.import`, `tests/sections/ghost.gd` | Spoegelse data: the fourth race's Danish copy (race card, two heroes, wardrobe rule, whispers), its key famili |
| G-ghost-art | 3b | M | `tools/art/ghost/**`, `assets/isometric_characters/ghost_bu/**`, `assets/isometric_characters/ghost_hviske/**`, `tests/sections/art_ghost.gd` | Spoegelse art: the two ghost heroes Bu and Hviske as a new rig family (legless bell body, scalloped hem, big d |
| G-ghost-play | 5 | S | `scripts/ghost/**`, `tests/sections/ghost_play.gd` | Spoegelse in the world: the float (baked hover + a runtime bob through set_altitude), the soft glow as a Point |
| G-ghost-lines | 5 | S | `lua/config/race_reactions.lua`, `scripts/reactions/**`, `localization/ghost_dialogue.csv`, `localization/ghost_dialogue.csv.import`, `tests/sections/ghost_lines.gd` | Spoegelse reactions: how nine citizens (and the Fairy King after the letter) greet a ghost, as data (lua/confi |
| G-ghost-qa | 7 | S | `tests/sections/zz_ghost.gd`, `docs/qa/ghost/**` | Spoegelse acceptance: the four-race row set (select with the keyboard and the pad, farm day and night, wardrob |

Amendments (`ghost_packages.json`): fix round **RG1-RG7** (BUILT: P02, P10, P04, P15, P09, F1, P01; before wave 3b, after design3's RT1-RT9), wave 4: V1 (+ `tests/sections/ghost_data.gd`), V2, A2 (+2 base folders), P06, DR1, P16 (+ the reference folder), N01; wave 5: P14, F5, V8, N02, I2; 5b: F8, V9, N04; 6: P24, P25; 7: P27 (carve-out `docs/qa/ghost/**`), F10, I6, N08, DQ, V10.

**Wave placement and merge order (review defects 3 and 5).** The design3 checker (`check_ownership.py` D) accepts a dependency only on a strictly EARLIER wave, so a `softDependsOn` between two wave-4 packages is rejected, and the three couplings of the first draft became hard edges across waves: **G-ghost-data and G-ghost-art are wave 3b** (V1 depends on G-ghost-data because its literal keys name ghost.csv and its loc check fails without the CSV: AG1; A2 depends on G-ghost-art because it imports `ghost_model.py`: AG3), **G-ghost-play is wave 5** (it depends on V1 for `SpeciesPerks`, on P06 for the real `Player2D` and on DR1 for `OilRules`; P06's hooks are null-safe and P06 has no edge to it: AG4). Order: fix round (gate: the built harness for animal, fairy, hobbit, strict) -> 3b: G-ghost-data (first gate: 7 checks), G-ghost-art -> 4: V1, then V2 / A2 / DR1 / P06 / N01 in any order, the lead patch SE-G5 right after V1, P16 after V1 (it reads `CharacterCatalog.heroes()`, the same coupling design2's six-hero amendment already has) -> 5: G-ghost-play, G-ghost-lines, ...

**Milestone placement (review defect 2: ghost selectable in M1a, stated honestly).** The lead's M1a is the CITY PREVIEW (stage 1 P22 V3 N01 P11, stage 2 V1 V2 V5 + the ghost, stage 3 V4); P16, P06 and P28 are M1b. **M1a contains**: the fix round, G-ghost-data, G-ghost-art, V1 (AG1), V2 (AG2) and the lead patch SE-G5. **Result in M1a**: the ghost can be PICKED in the real game (legacy "Vælg din helt", fourth button, Bu / Hviske in the dropdown; the boot stage of `--character=ghost` is green) and WALKED around with its own baked sprite (hover, idle, glide walk / run) by the built stub player. **Not in M1a**: perks (cheaper running, lantern oil and light), the code bob, the glow (P06 + G-ghost-play), hat / shirt layers (A2 + F5), the four-card page with hero chips and Danish blurbs (P16), citizen greetings (P14 + G-ghost-lines). **M1b**: P06, DR1, P16, A2, G-ghost-play, G-ghost-lines, F5 / F8 / V8 / P14. **M4**: P24 / P25, G-ghost-qa and the matrices.

**Ownership proof** (`scripts/check_ghost_ownership.py`, a sixth layer on the five of design3's checker, base `design3/FINAL/effective_owners.json`):
```
A  pattern pairs intersected (ghost-touched packages x all): 68, overlaps: 0
B  git ls-files 3518: multi-owner 0 (ghost-involved 0), unowned 335, claimed by new packages 0
C  ownsRemove sanity (ghost-touched): 0 problems
D  dependency waves / cycles / schema / verify tags: 0 problems in the merged table, 0 involve the ghost layer
E  concrete paths named in ghost tasks: 54, problems 0, info 12
F  key families: 24 ghost keys, resolve to their own file, no existing key moved, prefixes unique: 0 problems
G  contracts: 0 problems

EFFECTIVE OWNERS of the ghost layer:
  G-ghost-data    wave 3b owns ['localization/ghost.csv', 'localization/ghost.csv.import', 'tests/sections/ghost.gd']
  G-ghost-art     wave 3b owns ['tools/art/ghost/**', 'assets/isometric_characters/ghost_bu/**', 'assets/isometric_characters/ghost_hviske/**', 'tests/sections/art_ghost.gd']
  G-ghost-play    wave  5 owns ['scripts/ghost/**', 'tests/sections/ghost_play.gd']
  G-ghost-lines   wave  5 owns ['lua/config/race_reactions.lua', 'scripts/reactions/**', 'localization/ghost_dialogue.csv', 'localization/ghost_dialogue.csv.import', 'tests/sections/ghost_lines.gd']
  G-ghost-qa      wave  7 owns ['tests/sections/zz_ghost.gd', 'docs/qa/ghost/**']
  amend V1-cast-data              ownsAdd ['tests/sections/ghost_data.gd'] ownsRemove []
  amend A2-art-wardrobe           ownsAdd ['assets/isometric_characters/ghost_bu_base/**', 'assets/isometric_characters/ghost_hviske_base/**'] ownsRemove []
  amend P16-ui-menus              ownsAdd ['tests/checkpoints/guide_ref_ghost/**'] ownsRemove []
  amend P27-qa-acceptance         ownsAdd [] ownsRemove ['docs/qa/ghost/**']

RESULT: OK, no problem
```
Mutants (`scripts/ownership_mutants.py` -> `notes/check_ghost_ownership_selftest.txt`, 8 of 8 as expected): the unmutated file is clean; a built-file claim, a foreign directory, a task without the verify tag, a same-wave hard dependency, the defect-5 shape (G-ghost-data back in wave 4 while V1 depends on it), G-ghost-play back in wave 4 and the reviewer's own proposal, a same-wave `softDependsOn`, are all rejected (`check_ownership.py` D: "softDependsOn is not in a strictly earlier wave"). Sanctioned shared edits: SE-G1 `tools/loc/key_owners.json` (the lead, at the start of waves 3b and 5), SE-G2 `assets/isometric_characters/manifest_traetoppen.json` (two rows by the installer's merge, V2's file), SE-G3 `tests/lib/ui_screens.json` (RG5), SE-G4 `docs/design/UI_NAVIGATION.md` (RG7), **SE-G5** the legacy select screen + two self-test lines (the lead, right after V1).

## 13. Risks and honest stubs
* **high** - Silent perk leak (enum extended, Perks.RACE_KEYS not): the ghost gets the hobbit's discount and bake bonus. Guard: RG2 + ghost.no_hobbit_perks_leak (mutation-proven) + ghost.every_enum_value_has_a_perk_row.
* **medium** - The select page diff against the guide cannot stay <= 15 with four cards (the guide shows three). Guard: RG5 re-bases the reference on the 4-card render; the user may redraw it.
* **medium** - A2 cost: +22 bakes (+10.6 CPU-min, +14.7 MB), more if Hviske needs her own scope. Guard: the ghost scopes are baked last in Phase A; the borrow / own-scope rule is A2's measurement.
* **medium** - Runtime float vs the wardrobe lock-step (the layers must follow the bob). Guard: wardrobe.lockstep_ghost_float; the bob goes through set_altitude, which F5 already mirrors for the fairy.
* **low** - Light budget in the forest and the city. Guard: forest_look.light_budget_with_the_ghost_glow; 12 map + lantern + glow = 14 <= 15.
* **low** - Two writers of the sprite altitude (hop, flight, bob). Guard: P06 _apply_altitude is the only caller; player.ghost_float_and_hop_compose.
* **low** - Same-wave couplings of the first draft (V1 <-> G-ghost-data keys, A2 <-> G-ghost-art import, P06 <-> G-ghost-play). Guard: now hard edges across waves (the design3 checker allows only strictly earlier waves): G-ghost-data and G-ghost-art in wave 3b, G-ghost-play in wave 5, P06 null-safe (AG4); one id table in the contracts block.
* **medium** - A ghost cannot show 30 % of the loot (pants, shoes), among them 2 of the 8 legendaries and the set capstone pants_trousers_starlight. Guard: hidden slots count for perks, set bonuses and the RarityAura (wardrobe.hidden_slot_counts_for_aura_and_sets); Garderobe tag + equip toast; no reroll (loot stays race-blind); upgrade path = a tinted hem layer (+1 bake).
* **low** - The legacy-select patch (SE-G5) is a lead patch to a file P16 owns. Guard: mechanical (9 edits, proven by the boot stage of --character=ghost), applied after V1, replaced when P16 rewrites the two files; P16 keeps %GhostButton.
* **low** - The ghost's dark eyes differ from the family's white-sclera eyes. Guard: open question 1; flipping it is a palette entry (eye colour) and a re-bake of 2 heroes (13 s).

Honest stubs:
* **the ghost in M1a (the lead's city preview)**: The ghost can be PICKED in the legacy select screen (SE-G5: a fourth button, Bu / Hviske in the dropdown) and WALKED around with its own baked sprite (hover, idle, glide walk and run) because the built stub player draws any skin. It has NO perks, NO bob, NO glow and NO hat / shirt layers there: those need P06 (Player2D), G-ghost-play and the wardrobe packages (M1b). The four-card page, the hero chips and the Danish hero blurbs arrive with P16 (M1b).
* **ghost over water**: The ghost only LOOKS floaty: collisions are the figure ellipse of every race, ponds block the ghost like everybody (the fairy's flight is the only crossing perk). The whisper GHOST_WHISPER_WATER exists as a key but is a stub, cut first.
* **movement audio**: No footstep sound exists for ANY race in the plan; the name sfx/ghost_whoosh is only reserved (silent without a file).
* **walk animation**: The stock-rig glide: 5 px bob, leaning, paddling mittens, a swaying wisp. A dedicated hover / glide clip set (the fairy's four flight clips) would add 4 clips x 2 heroes and 4 more layer groups per garment and was not built.
* **translucent hem**: Built, baked, imported and compared at zoom 0.4 / 0.9: invisible at game scale; REJECTED. S3TC (DXT5) handled the alpha ramp without artefacts (fix_alpha_border true), so the door stays open.
* **ghost voice**: The player has no voice; the nine reaction lines are text-only until P24 voices them in wave 6.
* **ghost citizens**: None. The player is the only ghost; the hero-twin rule needs no change.
* **pants and shoes of a ghost**: Worn, counted in perks, set bonuses and the RarityAura, never drawn (29 of 96 wearables are pants or shoes, 6 of 21 unique / legendary pieces, among them the capstone pants_trousers_starlight and the legendary shoes_boots_wind). The cue of a legendary piece is the gold aura, the Garderobe tag and the equip toast, not a layer; item flavour text such as "De glimter, når du går" stays. A tint-ready hem layer in the colour of the worn piece (every item has art.palette: +1 bake, +0.5 CPU-min, +0.7 MB) is the known upgrade if play shows the invisible cue disappoints; not built.
* **ghost glow in the farm at dusk**: A PointLight2D that lights the grass around the ghost at dusk and night; at noon it is invisible by the night factor. It is the ghost's second player light in the forest (lantern + glow = 2).
* **damage flash on Hviske**: The thorn-berry-pink flash tints a pink-lilac sprite: less contrast than on the others; the heart bar, the knock-back and the hit clip carry the feedback.

## 14. Open questions (only the user can decide; the default is what is built)
* **GQ1** Is the look right? The ghost has big DARK eyes with a white glint and no white of the eye (the other twelve figures have a white sclera), and a white / pale-blue sheet (Bu) and a pale-pink one (Hviske). Look at proto/contact_sheet_ghost.png, gamezoom_check.png and sketch_vs_baked.png. *Default:* dark eyes (cuter and more ghostly in the prototype); switching to the family eye is one palette entry and a 13 second re-bake of both heroes.
* **GQ2** The names: race "Spøgelse", looks "Bu" and "Hviske" (the lead's defaults, kept because Bu = boo and Hviske = whisper are what a child expects). Keep them? *Default:* keep.
* **GQ3** Should the ghost be allowed to float over water (a real perk, needs the maps to allow it) instead of only looking floaty? *Default:* no: only looks floaty (the fairy keeps the flight perk).
* **GQ4** Should there be other ghosts as citizens of Trætoppen / Hyggebyen (e.g. a ghost baker's apprentice)? *Default:* no: the player is the only ghost (the look cap per area is 16 and the hero-twin rule would need two more twins).

## 15. Evidence index (everything under `/Users/magnusudbjorg/Documents/projects/.pongpong-build/work/design4/`)
* Art: `proto/contact_sheet_ghost.png` (8 directions x 2 heroes, walk / run frames, 8 clips, busts), `proto/gamezoom_check.png` (real windowed Godot shots at zoom 0.4, 0.9 and night, magnified x3 with nearest neighbour), `proto/sketch_vs_baked.png` (Figurer v2 cards vs baked roster vs the ghost; the ghost sketch is drawn with the sheet's rules), `proto/shots/g_*.png` (the raw 1280 x 720 shots), iteration images `proto/v1..v6_*.png`, builder `proto/builder/traetoppen_additions.py`, shot driver `proto/shot_ghost.gd`.
* Select screen: `proto/select_4cards_{fixture,live,animal_selected}.png`, `proto/select_4cards_numbers.txt`, generator `scripts/select_mock.py`.
* FINAL EDIT: `final_logs/*.log` (the clone runs of the three states: `fix_*`, `t3b_*`, `full_*`, mutants, self-test), `scripts/final_clone.sh`, `scripts/final_runs.sh`, `scripts/dry_check_edits.py`, `scripts/tone_check.py`, `scripts/clothing_counts.py` -> `notes/clothing_counts.txt`, `scripts/blurb_fit.py` -> `notes/blurb_fit.txt`, `proto/tests/ghost_data.gd` (draft of V1's section), `review/` (the independent review: logs and scripts of the reviewer).
* Data / tests: `scripts/ghost_edits.py`, `scripts/rebuild_clone.sh`, `scripts/run_clone_tests.sh`, `proto/tests/ghost.gd` (draft of `tests/sections/ghost.gd`, 7 checks), `loc/*.csv`, logs `notes/t6_{ghost,animal,fairy,hobbit}.log` (16 sections, 2781 checks, 0 failed), `notes/t_animal_strict.log` / `notes/t_ghost_strict.log` (before the test edits: 3 / 4 failures), `notes/t4_mutant_perks.log` (the leak), `notes/t_boot_ghost.log` (the boot stage), `notes/selftest_*.log`.
* Numbers: `scripts/perk_balance.py` -> `notes/perk_balance.txt`, `scripts/measure_fig.py`, `scripts/palette_check.py`, `scripts/occluder_equality.py` -> `notes/occluder_equality.txt`, `scripts/bob_probe.py`, `notes/glide_hook_is_ghost_only.txt`, `notes/produce_all_run{1,2,3}.log`, `notes/rebuild_art3.log`, `scripts/find_three_hero_pins.py` -> `notes/three_hero_pins.txt`.
* Ownership: `scripts/check_ghost_ownership.py` -> `notes/check_ghost_ownership.txt`, `ghost_key_owners_additions.json`.
