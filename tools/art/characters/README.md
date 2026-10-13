# tools/art/characters - the 36 missing characters of Trætoppen (package P21-art-characters)

Everything that makes the characters the pack did not have: three hobbits, the squirrel, two fairy skins, nine NPC fairies, six named
villagers, eleven farm animals and the four forest creatures (one of them the boss). The generator itself (geometry, rig, bake) is the
pristine base in `tools/art/generator` + `tools/art/core` (P08); this folder only adds **builders**:

| File | What |
|---|---|
| `traetoppen_additions.py` | `BUILDERS` (id -> model factory, 36 ids), `EXTRA_PATTERNS` (texture painters), `EXTRA_CLIPS` (`attack`, `spin`). Found by `generator/build_assets.py` through `PYTHONPATH` (`produce_all.sh` and `core/artpaths.py` add this folder by themselves). The module name is ASCII on purpose. |
| `measure_cast.py` | the numbers behind the cast gates: figure height (alpha > 24 bounding box of the idle SE frame) against the pack, outline colour, designed height of the animals, and the **pivot check** (every frame of every sheet of all 48 characters stands on the contract pivot (128, 200): mean x of the 8 direction rows 127.5 +/- 3, opposed rows mirrored, feet line inside the window of the body class). It measures nothing about eyes or faces (those are judged on the contact sheets). `--check` exits 1 on any violation, `--selftest` proves the pivot check fires on synthetic shifted sheets |
| `review_sheets.py` | regenerates the review sheets of `review/` from the installed assets (and, with `--screenshots DIR`, from the windowed cast run) |
| `review/` | **the sheets the quality gates are judged on** (20 small PNGs, 256-colour, about 2.7 MB; listed per gate below). Hidden from Godot by `tools/art/.gdignore` |
| `README.md` | this file: roster, how to run, the honest notes and the verdict log of the package |

## Roster (36 folders in `assets/isometric_characters/`, plus 12 busts in `assets/portraits/`)

| Clip set (`animations.json` `role`) | Ids | Clips |
|---|---|---|
| `full` (player) | `hobbit_pip` (green tunic, ginger curls), `hobbit_moss` (mustard tunic, leaf cape), `hobbit_bramble` (plum waistcoat), `squirrel` (Egern), `fairy_dusk`, `fairy_stardust` | all 11 clips (+ takeoff hover fly flight_land for the two fairy skins) |
| `npc_flyer` (npc) | `fairy_mayor` Hyldeblomst (spectacles, medallion), `fairy_baker` Rosmarin (chef hat, apron, spoon), `fairy_shopkeeper` Kløvermynte (pouch), `fairy_king` Fekongen (crown, beard), `fairy_wizard` Zephyr (hat, beard, staff), **`fairy_lily`** (review R.9: a child, sunny dress, two ribbons), **`fairy_builder`** Hasselnød (hard hat, tool belt, hammer), **`fairy_furnisher`** Stokrose (apron, ribbon bow, ribbon wand), **`fairy_tailor`** Fingerbøl (measuring tape, needle and thread) | idle hover talk celebrate interact |
| `villager` (npc) | `mouse_pippin` Pippin Bøgeknop, `cat_morfar_mis` Morfar Mis, `bear_guard` Oak, `rabbit_farmer` Rosa, `raccoon_smith` Thorin, `penguin_postman` | idle walk talk celebrate interact sleep |
| `farm_animal` | `chick hen duck kitten bunny fox_cub lamb calf owl puppy fawn` | idle walk run interact sleep hit celebrate |
| `enemy` | `ugleoje` (Ugleøje), `tornebusk` | idle walk run attack hit |
| `boss` | `snurresvamp` (Snurresvampen, 2.1 m) | idle walk attack hit spin |
| `critter` | `lysesvamp` (baked halo, `glow` in animations.json) | idle walk run hit sleep |

The 12 pack busts (`bat cat bear rabbit fairy monkey capybara fox raccoon penguin hedgehog frog`) are regenerated head-and-shoulders portraits
from the source generator at the 14 degree bust camera and live in `assets/portraits/<id>.webp` (TTPortraits looks there first, then in
`<id>/portrait.webp`); the pack folders themselves are untouched.

## How to run it (repo root)

```
tools/art/produce_all.sh --only=characters                    # all 36: build -> bake -> validate -> export -> install (about 2.5 min wall, 5 parallel bakes)
tools/art/produce_all.sh --only=characters fairy_lily         # one character: ~1 s build + 3-17 s bake (clip-set dependent)
tools/art/produce_all.sh --only=characters --busts            # the 12 pack busts -> assets/portraits
export PY="$PWD/tools/art/.venv/bin/python"
$PY tools/art/core/validate_new_assets.py --root assets/isometric_characters hobbit_pip    # mandatory after every bake
$PY tools/art/characters/measure_cast.py --check                                           # heights +/-10 % of the pack, outline colour, every figure on the pivot (128, 200)
$PY tools/art/characters/measure_cast.py --selftest                                        # the pivot check on synthetic shifted sheets: must flag every misplacement
$PY tools/art/characters/review_sheets.py [--screenshots DIR]                              # rebuild tools/art/characters/review/ from the installed assets
$PY tools/art/core/cast_sheet.py --root assets/isometric_characters --cell 128 --out cast.png bear cat rabbit bat fox fairy hobbit_pip squirrel fairy_mayor
$PY tools/art/core/contact_sheet.py --root assets/isometric_characters --chars hobbit_pip --clips walk run talk hit --rows 0 7 --scale 0.4 --out rows.png
tools/import/write_import_stubs.py                             # S3TC stubs BEFORE the first godot --import (produce_all/exporter already wrote them)
tests/run_playtest.sh --only=art_characters --no-boot          # headless section (imports the project first when needed)
tools/dev/run_windowed.sh --only=art_characters                # windowed: cast screenshots + measured pixel heights + measured VRAM
```

The sheets are WebP q97 method 4, 256 x 256 cells, 8 direction rows S SW W NW N NE E SE, pivot (128, 200); the exporter writes the S3TC import stub
next to every sheet before Godot ever sees it. `assets/isometric_characters/manifest_traetoppen.json` is merged by the installer.

## What this package changed against the art spike's builders (and why)

* **Four new NPC fairies** (`fairy_lily`, `fairy_builder`, `fairy_furnisher`, `fairy_tailor`): stock `make_fairy` under a palette override plus accessories, `npc_flyer` clip set,
  exactly like the other NPC fairies. They need no code: `lua/config/characters.lua` already lists them with the shopkeeper as fallback, which stops being used as soon as the art exists.
* **Hobbit feet** (quality gate 5, rebuilt twice): the spike's feet were skin coloured with small tufts and disappeared at game scale; round 1 made a darker fur cap, but Pip's
  fur (`7A431C`, a shoe brown) over a mostly peach foot still read as **brown feet with peach toes** (the builder's own and the reviewer's verdict). Now (fix round 2, two iterations,
  all three skins, only the three hobbit folders were re-baked): the fur is the colour of the head's curls (Pip: his ginger `B8733A`, every third tuft in the lighter curl colour
  `E3A862`; Moss and Bramble keep their dark brown / near black with a lighter curl tuft) and carries the `hair` strand texture; it covers the instep **all the way to the toes**; 25 tufts
  instead of 16, among them six bumps on the flanks that break the silhouette (the foot is shaggy, not a smooth shoe); the three small skin toes carry a tuft of hair each (hairy toes).
  The sole is unchanged, the height and the pivot are unchanged (measure_cast: 101 % of the pack, feet line 208.8..212.6); the foot reaches about 0.05 m further out to the sides
  (x +/- 0.52 m instead of 0.47 m), which A2's `feet` garment scope has to fit. Verdict: **improved, not solved by detail** - see "Honest notes".
* **Pippin's satchel strap**: was a thin tube floating inside the stubby arms (it read as a stick). Now a broad flat band that hugs the chest in the gap between the arms plus a real satchel with flap and clasp.
* **Zephyr's hat**: with the full 1.0 m cone the wizard was 16 % taller than the pack; the cone is 0.66 now (+5 %).
* Everything else is the spike's geometry unchanged (the hooks `TT_BUILDERS`, `m.slug`, `m.base_height`, `m.clip_set`, `m.glow`, `m.portrait` of `tools/art/generator/build_assets.py`).

## Honest notes (what this art is and is not)

* The characters are **soft CG renders** (VTK, three lights, warm grey-violet outline) in the same family as the pack, **not hand-painted**; only the periodic ground tiles of P22 carry a painted feel.
* Hobbit, squirrel and NPC bodies reuse the **stock rig**, so the animation is as subtle as the pack's: a small bob and arm swing for `walk`/`run`/`talk`/`hit`, and rows S and SE
  differ mostly in the head turn. The hobbit and squirrel rows were looked at (walk, run, talk, hit, S and SE): they move, but nobody will mistake them for hand-animated sprites.
* The **quadrupeds** (puppy, fawn, lamb, calf) use the stock quadruped IK: at game scale the legs barely read as stepping, the body bobs. Seen from the front (row S) the tails of puppy and fawn stick up behind the head.
* **Pippin's satchel** now reads as a strap with a bag at normal zoom, but at game scale (40 %) it is still a few pixels wide: it is a detail for close-ups and the dialogue bust.
* **Hobbit feet at game scale**: a foot is about 12 x 8 pixels at zoom 0.4, so the fur is read through colour and silhouette (ginger/dark curls with lighter highlights, a bumpy outline, peach
  toe tips with a dot of hair), not through strands; at zoom 0.9 and in the 256 px cell the curls and the hairy toes are plainly visible (`review/detail_hobbit_feet_x4.png` is the true game
  scale, magnified 4x, `review/detail_hobbit_feet_x4_before.png` the same crop before the fix). Pip's ginger feet are the least contrasting against the green grass of the three.
* The NPC fairies have **no walk clip** (they hover): `npc_flyer` = idle hover talk celebrate interact, so they glide and never step.
* The boss is a **single design, not a texture pass**: Snurresvampen is one model with the pack's face, a big spotted cap, `attack` and `spin`; there is no damaged or enraged variant.
* The pack's four characters follow the user's own sketches; hobbit, squirrel, NPCs, animals and creatures are **our** designs from the guide text. The face grammar of the sketches
  (two big round eyes with one dark pupil, three short whisker strokes on each cheek, tiny mouth, big round head on a small pear body, stubby arm arcs, small feet) is kept by all of them
  except where a species forbids it: the beards of Fekongen and Zephyr hide the mouth, the owls, the chick, the hen and the duck have beaks, the mushrooms and the thornbush have no pear body.
* Baby animals are smaller than the people on purpose (chick 1.05 m ... fawn 1.5 m); the boss is 2.1 m. Only people-sized figures are held to the pack height +/-10 %.
* Lily is the smallest person on purpose (a child): 91 % of the pack height, still inside the +/-10 % gate.
* No emissive eye layers (Ugleøje, Tornebusk), one portrait expression per character, no damaged variants.

## Gates (work order task 3) and where each is proven

Every sheet named here is in `review/` (regenerate with `review_sheets.py`); the check `art_characters.readme_points_at_the_review_sheets` fails when a sheet named in this table is missing,
unreadable, larger than 700 KB or when `review/` holds a PNG this README does not mention.

| Gate | Proof (check) | Sheets to LOOK at |
|---|---|---|
| 1 `validate_new_assets.py` green for all 36 | `produce_all.sh` runs it on the masters and on the exported WebP; the section re-checks sizes, blank frames and border clipping on the imported S3TC textures (`art_characters.sheet_sizes_and_cells`) and, new, that every figure stands on the pivot (`art_characters.figures_on_the_pivot`, `measure_cast.py --check`) | - |
| 2 contact sheets next to bear, cat, rabbit, bat, fox, fairy: height +/-10 %, outline, eyes | `measure_cast.py` + `art_characters.figure_heights_match_pack`, `outline_colour_matches_pack` | `review/contact_cast_next_to_pack_S.png`, `review/contact_cast_next_to_pack_SE.png` (cell 128 = zoom 0.5), `review/contact_busts.png` (eye style, cheeks, face grammar) |
| 3 windowed cast screenshot at zoom 0.4, 1280 x 720, on grass | `art_characters.cast_matches_pack` (windowed; measures the rendered pixel heights) writes the shots | `review/cast_pack_and_new_zoom04.png` and the zoom-0.9 close-ups `review/cast_closeup_1_pack_and_mayor_to_lily.png`, `review/cast_closeup_2_players_and_builder_to_oak.png`, `review/cast_closeup_3_rosa_to_animals.png`, `review/cast_closeup_4_farm_animals_and_pack.png` |
| 4 animation rows S and SE (hobbit, squirrel, fairy NPCs, boss spin from all sides) | `art_characters.clips_animate`, `boss_spin_all_sides` | `review/anim_hobbits_rows_S_SE.png`, `review/anim_squirrel_rows_S_SE.png`, `review/anim_fairy_npcs_rows_S_SE.png`, `review/anim_villagers_rows_S_SE.png`, `review/anim_quadrupeds.png`, `review/anim_boss_spin_all_8_sides.png`, `review/anim_boss_attack_hit_walk.png` |
| 5 hairy feet readable | feet rework above | `review/detail_hobbit_feet_x4.png` (the real zoom-0.4 screenshot, magnified 4x), `review/detail_hobbit_feet_x4_before.png` (before fix round 2) |
| 6 portrait legible at 96-150 px | `art_characters.portraits_exist_and_are_busts`, `pack_busts`, `portrait_lookup_order` (through P07's `TTPortraits`) | `review/portraits_96px.png`, `review/portraits_150px.png`, `review/pack_busts_new_vs_old.png` (the 12 new busts above the old full-body crops) |

## Verdict log

| Date | Who | Verdict |
|---|---|---|
| 2026-10-13 | builder (P21) | all gates run, every sheet looked at; contact sheets, the cast screenshot and the animation rows are in `review/` for the human review |
| 2026-10-13 | fix round 2 (P21) | review defects fixed: pivot check (python + section, with self-tests), `portrait_lookup_order` through `TTPortraits`, doc drift, review sheets inside the repo, hobbit feet rebuilt (two iterations, looked at the 4x crop and the contact sheets: ginger / dark curls over the whole instep, shaggy silhouette, hairy toes; improved, the fur still reads through colour rather than strands at zoom 0.4) |
| - | Accepted at: pending the human look at the contact sheets, the cast screenshot and the animation rows (work order task 3: "a human looks at 2, 3 and 4 before the package is accepted") | known weaknesses: the notes above (CG not hand-painted, subtle stock-rig animation, small Pippin strap at game scale, hovering fairies without walk, one boss design) |

## Lift history

| File | Source | Changes |
|---|---|---|
| `traetoppen_additions.py` | art spike `tools/characters/traetoppen_additions.py` (32 characters) | + `fairy_lily`, `fairy_builder`, `fairy_furnisher`, `fairy_tailor` and their accessories; hobbit feet (fix round 2: curl-coloured fur over the whole instep, shaggy flanks, hairy toes); Pippin's strap and satchel; wizard hat height; the module header and this README |
| `measure_cast.py` | new | height / outline measurements for the gates; fix round 2: pivot check + `--selftest`, docstring corrected (it never measured eyes) |
| `review_sheets.py` + `review/` | new (fix round 2) | the sheets of the gates 2-6, inside the repo instead of the lead's report folder |
