# tools/art/features/home - the home art of Trætoppen (package A1-art-home)

Ten house tiers from shed to castle (day sprite, additive night layer, nine construction scaffolds), the interior shell and four floors, **130 furniture items**
with true rotations (symmetry MEASURED, not declared), **162 contract-style icons** (130 furniture + 32 materials) plus the pale night rims of the 11 legendary pieces, and nine small props.
Everything is baked by the same procedural VTK pipeline as the cast (one orthographic 36 degree camera, 87.074 px per metre, warm outline `(75,60,73)` at .55 on
world sprites, ink `#2b2340` on icons) - soft 3D-rendered sprites, **not** hand-painted brushwork. The tools only import `tools/art/generator` and `tools/art/core`
(P08) through `PYTHONPATH`; they never edit them.

The shipped day sprites and icons additionally receive the offline illustrated finish documented in `tools/art/README.md`:
warm ink, textured color washes and pencil accents. The original VTK export is the input to that finish; night and float
layers remain additive source artwork. Regenerating this package needs the illustration pass before installing final art.

## Run (repo root)

```
tools/art/features/home/produce_home.sh                       # bake -> export -> validate -> install into the repo (owned paths only), about 4 min on a loaded M3
tools/art/features/home/produce_home.sh --stage-only          # same, but nothing is written outside tools/art/_stage/features_home
tools/art/features/home/produce_home.sh --only=furniture,export --write-specs     # one slice; --write-specs stores the measured specs/mirror_ok.json and specs/symmetry_measured.json
tools/art/features/home/produce_home.sh --keep-noise          # install: keep an installed WebP whose new bake differs by renderer noise only (the VTK bake is not byte-deterministic): a clean git diff
export PY=$PWD/tools/art/.venv/bin/python
$PY tools/art/features/home/isometric/bake_home.py --only 1 --ss 2          # task 1: one tier, writes <stage>/home_final/house_t01.png
$PY tools/art/features/home/isometric/validate_features_home.py             # the Python validator on assets/ (or --assets <stage>/assets)
$PY tools/art/features/home/isometric/measure_symmetry.py --check            # re-measure the c4/c2 pieces: does specs/symmetry_measured.json still equal the measured classes?
$PY tools/art/features/home/isometric/sheets.py                             # all contact sheets of task 8 from the exported tree -> <stage>/sheets
tests/run_playtest.sh --only=art_home                                       # the headless section (independent of the Python validator)
```

Every entry script does `import homepaths`, which puts `home/characters : home/isometric : tools/art/generator : tools/art/core` at the FRONT of `sys.path` in exactly this
order (so the shim `characters/traetoppen_additions.py` wins over P21's builder module) and turns bytecode off. `produce_home.sh` exports the same `PYTHONPATH` too.
The machine should be quiet when timing: other work running at the same time made the spike's first numbers 2-6x too slow (measured here at load 5-70: 236 s for everything).

## Layout

| Path | What |
|---|---|
| `characters/` | `home_kit.py` (painters with real-world texel size, the `HM` builder: boxes, roofs, towers), `home_traetoppen.py` (10 houses), `home_scaffold.py`, `home_data.py` (ids, platform stages, room shapes, `zoom_fit`), `furniture_traetoppen.py` (22 templates x `Style`), `icons_materials.py` (47 spike builders + 5 new), `features_props.py` (the nine new props), **`props_traetoppen.py` VENDORED, do not edit** (copy of the file P22 lifts), `traetoppen_additions.py` (shim: empty `BUILDERS/EXTRA_PATTERNS/EXTRA_CLIPS`) |
| `isometric/` | `bake_lib.py`, `bake_home.py`, `bake_furniture.py`, `bake_interior.py`, `bake_material_icons.py`, `bake_features_props.py`, `icons_contract.py`, `night_rim.py`, `measure_mirror.py`, `measure_symmetry.py`, `spec_reader.py`, `export_home.py`, `install_home.py`, `validate_features_home.py`, `sheets.py`, the lifted `ladder.py` `sheet_tiers.py` `sheet_scaffold.py` `icon_audit.py` `make_content_contract.py`, **`bake_tiles_vendored.py` VENDORED** (only for the four floor atlases), `homepaths.py` |
| `specs/` | `furniture_art_spec.json` (the ONLY furniture catalogue: 130 English ids), `content_contract.json` (snapshot of the content numbers: 10 tiers, 130 furniture, 32 materials, 96 garments), `material_icon_map.json`, `mirror_ok.json` and `symmetry_measured.json` (GENERATED), `mirror_ok.measured.json` and `template_rarity_cells.json` (the review's reference measurements, read-only) |
| `produce_home.sh` | stages: 1 exteriors, 2a symmetry (measure), 2 furniture, 3 interior + floors, 4 icons, 5 props, 6 export, 7 validate, 8 install |

Outputs (every `file` of every json is **relative to that json's folder**; no gold, no material numbers, no Danish text anywhere in them):

| Path | |
|---|---|
| `assets/iso_props/home/` | `house_tNN.webp` (q92), `house_tNN_night.webp` (additive), `scaffold_toNN.webp` (tiers 2..10), `home.json` |
| `assets/iso_props/furniture/` | `<id>_r<k>.webp` (+ `_float.webp` of the **legendary pieces only**: 11 ids, 38 sprites; the 17 unique pieces have none), `furniture.json` (layer, sym, baked, rot{file,size,pivot,footprint,ysort,float,glow,interact_*,surface_slots}, rot_map, surface, interact, hang_m, icon, mirror_ok) |
| `assets/iso_props/interior/` | 18 wall pieces (3 styles x plain/pilaster/window x 2 yaws) + `_night` of the windows, 3 corner posts, `doormat_r0/r1`, `door_post`, `interior.json` |
| `assets/iso_props/fx/glow_soft.webp` | one white 256 px halo, tinted and scaled by the engine for every glowing piece |
| `assets/iso_props/features/` | the nine new props + `props.json` (same manifest shape as `iso_props/props.json`) |
| `assets/iso_tiles/` | `floor_stone/plank/parquet/marble.png` (periodic 4x4, cell 144x84) + `.import` stubs WITHOUT mipmaps, `tiles_floors.json` |
| `assets/data/home/rooms/room_t01..t10.json` | `_contract`, rows, cells, floor, wall_style, door, spawn_cell, windows (+ `windows_by_wall`), max_furniture, **zoom_fit** |
| `assets/icons/home/` | `<furniture id>.webp`, `<material id>.webp` (lossless 128x128), `<legendary id>_night.webp` |
| `lua/config/props_features.lua` | gameplay entries (footprint, solid shape, interact type) of the nine props, GENERATED from `features_props.GAMEPLAY` + the baked footprints |

### Contract notes for the consumers (F3 F6 F7 P04)

* **Night layers are trimmed** to the bbox of their lights (they are mostly empty): `exterior.night_offset` = px from the top-left of the day sprite, `exterior.night_size`, `night_blend = "add"`;
  same pivot as the day sprite, so a layer is drawn at `day_origin + night_offset`. Saves about 9 MB of texture memory at tiers 9-10.
* **Pivots.** Floor / rug / tabletop pieces: the pivot is the ground point at the footprint centre, INSIDE the sprite. **Wall and ceiling pieces** (painting, shelf, curtain, sconce, chandelier):
  the pivot is the ground point on the wall plane / under the ceiling piece, BELOW the sprite on the same vertical line (contract: "on the wall plane below the item centre").
* Furniture `rot_map[k] = [baked rotation index, flip_h]`; with the default export the flag is always false (all views are true bakes). `interact_from` / `interact_anchor` / `surface_slots`
  are already rotated per `rot`.
* `home.json platform_stages` = `{0: 0, 1: 1, 2: 2, 3: 3}` back rows; `tiers[].platform.back_rows` = 0,0,0,0,1,1,1,2,2,3 (the content numbers).
* `room_tNN.json zoom_fit` = 0.85 x min(1280/W, 720/H), W = (cols+rows) x 64, H = (cols+rows) x 38 + 280: 0.98 0.88 0.83 0.72 0.69 0.63 0.59 0.55 0.51 0.48 (at the 1280x720 base).
* **Room windows (read this before building a furniture grid or a room).** The keys are named by the WALL and the values are the OTHER axis: `windows.z` = the **x indices** of the windows on the `z = 0` wall
  (the back-RIGHT wall, along the first row, `0 < v < rows[0] - 1`); `windows.x` = the **z indices** of the windows on the `x = 0` wall (the back-LEFT wall, along the first column, `0 < v < len(rows) - 1`).
  `windows_by_wall` repeats the same two lists under unambiguous names (`back_right_z0` = `windows.z`, `back_left_x0` = `windows.x`); `_contract` in every room json says so as well.
  All numbers in these jsons arrive as FLOATS in Godot (`JSON.parse_string`): compare with `int(v)`, `Array.has(1)` is false for `[1.0]`. Test `art_home.room_windows_contract`.
* **Float layers belong to the LEGENDARY pieces only** (plan 2.1 says unique and legendary): only tier 4 builds a `float` layer, so 11 pieces carry `<id>_r<k>_float.webp` (38 sprites); the 17 unique pieces
  have none - their cue in the world is shape and palette (mushrooms, roots, shells). F3/F6: do not expect a float entry on unique furniture (or add sparkles to the unique tier in the generator).
  Test `art_home.float_layers_legendary_only`.
* **Symmetry classes are MEASURED** (`furniture.json sym`, `baked`, `rot_map`): see "Rotation policy". Always draw rotation k from `rot_map[k]`; never assume that a piece of a given template has one view.
* **Anchors are checked on pixels**, not only as JSON arithmetic (`art_home.house_ground_contact`, `scaffold_anchor_matches_tier`, `furniture_ground_contact`): the footprint corners must be covered, the lowest opaque row must sit at the
  front corner of the footprint (floor/rug), the wall base must follow the projected ground line (houses), the y-sort key must be the footprint's key corner, every scaffold frame must stand at one distance from its footprint.
  A pivot shifted by 20 px or more in any direction fails (10 px in y already fails most floor pieces); wall and ceiling pieces have no ground shadow, their check is coarse (pivot on the vertical centre line, 30-125 px below the sprite).
* The props that are additive soft sprites (`dig_glimmer`, `unique_glimmer`) say `"blend": "add"` in props.json; `chest_*` open state = the same sprite darkened + a sparkle burst (`opened` in the Lua entry) - there is no open-lid art.

## Rotation policy and the mirror list (RV-A5)

All 130 items ship TRUE bakes of every distinct view: `c4` pieces 1 view, `c2` and wall pieces 2, the other pieces 4 = **404 main sprites + 38 float layers** (79 four-view pieces, 18 `c2`, 14 `c4`, 19 wall pieces).

**The symmetry class is measured, not declared** (review fix). A template declares `c4`/`c2` (`FSpec.sym`), but that was never checked: 14 pieces looked visibly different when rotated and got one or two views only
(the first plan number of 373 sprites baked that declaration in). `measure_symmetry.py` bakes r0..r3 of all 41 pieces that declare `c4` or `c2` and calls two views equal when the silhouette mismatch is < 4 % and the colour error
of the 4x4 block means < 20/255 (a 1-2 % mismatch is the facets of a lathe turned by 90 degrees). It found **15 declarations wrong**: `plant_fern`, `plant_flowering`, `plant_rose_pot`, `plant_teapot_bonsai`, `vase_clay`, `vase_rose`,
`chandelier_lantern_flower` (c4 -> 4 views), `table_long_walnut`, `table_stump` (c2 -> 4 views), `candelabra_brass`, `candelabra_copper`, `chandelier_gold`, `chandelier_star`, `floor_lamp_brass`, `floor_lamp_fairy` (c4 -> c2: two views).
The result is `specs/symmetry_measured.json` (GENERATED; `produce_home.sh` measures first, `--write-specs` stores, otherwise it must equal the stored file); `spec_reader.symmetry()` uses it, the 33 extra sprites (31 main + 2 float) cost 0.17 MB.
`art_home.symmetry_measured_consistent` checks the stored classes against their own measurements and against `furniture.json`, and re-measures in Godot that every piece that ships extra views really differs (weakest 12.9 % of the silhouette).
The 26 pieces that stay `c4`/`c2` were measured symmetric. Limit: the measurement is a bake at ss 2 and a threshold; a piece that is 4 %-asymmetric would still ship as symmetric (nothing measured sits between 2 % and 4.7 %).

`measure_mirror.py` measures, on the exported sprites, which pieces *could* be drawn as `flip_h` of the other view: mean RGB error < 8/255 and silhouette mismatch < 1 % on BOTH pairs
(`flip_h(r0)` vs `r1`, `flip_h(r2)` vs `r3`), never unique/legendary, never patterned fabric (stripe, quilt, damask). It writes `specs/mirror_ok.json`
(**34 of the 79 asymmetric pieces pass** after the symmetry fix: the 9 new four-view pieces added no mirror candidate, `fireplace_slate` passes now that it is slate and not a second marble); `export_home.py --mirror-fallback` would drop their r1/r3 files (a disk fallback: 66 sprites, 0.65 MB) and mark the entries `mirror_of` / `flip_h`. The default does not.
The review's list (`specs/mirror_ok.measured.json`) has 40 ids; the difference is read off the printout of `measure_mirror.py`: six pieces with a quilt or damask cloth
(bed_oak_single, bed_cherry, chair_oak, chair_ebony, sofa_oak_three, sofa_cherry_three) fall out because "never patterned fabric" is applied literally here, and piano_walnut sits at exactly
8.0/255 on this bake; `fireplace_slate` is new on the list. The test `art_home.mirror_ok_measured` re-measures every id of the stored list inside Godot.

## Icons (RV-A2, RV-A3)

`icons_contract.py` renders every furniture item like the 60 cast icons: icon camera az 28 / el 30, NO ground shadow, NO world outline, fit on main + float shapes at fill .92, ink outline radius 2 alpha .95 `2b2340`.
`bake_material_icons.py` uses the same renderer for the 32 materials (`specs/material_icon_map.json`: 27 spike builders mapped, 5 new: the four blueprint rolls with a wax seal in four colours and the milk paint pot).
The 11 legendary furniture icons get `<id>_night.webp` (4 px die-cut rim `e4eff5`): ink vs rim 12.4:1, rim vs night tile `2f3654` 10.1:1, because ink on the night tile is 1.25:1.

## Mirror of the review numbers (measured here)

| | plan / review | this build |
|---|---|---|
| furniture sprites | 373 main + 36 float, 3.64 MB | **404 + 38, 3.81 MB** (the plan number baked the declared symmetry in; 15 declarations were refuted by measurement: +31 main, +2 float sprites, +0.17 MB) |
| icons | 162, about 1.6 MB, budget 1.8 | 162 + 11 night rims = 1.44 + 0.11 MB |
| total on disk | about 9.2 MB (limit 12) | **8.77 MB** of sprites/icons/floors, **9.02 MB** with the json contracts counted (furniture.json alone is about 0.2 MB; the test and the validator count 9.02) (houses 1.12, night 0.27, scaffolds 1.02, furniture 3.81, interior 0.16, floors 0.74, icons 1.55, props 0.08) |
| bake wall time | exteriors 47 s, furniture 20 s, icons 12 s (+ about 60 s for interior and props), quiet M3 | first round (load 5-70): 63 s, 43 s, 22 s + 14 s, 27 s + 10 s, export 43 s = 236 s; fix round (load about 15-30): 56 s, symmetry 25 s, 36 s, 14 s + 7.5 s, 16 s + 8 s, export 46 s = **211 s in total** |
| houses vs the spike's final bake | - | day sprites equal the spike's `home_set/home_final` within 1-7/255 (renderer noise), same opaque areas 75207 123854 192094 229322 328653 392280 ... |

## Task 5 - the nine props: built, not placeholders

All nine are real builders (no recolours of the furniture chest, no flat discs). Two iterations were allowed; the first showed the chests fine and the tent, the slate and the marble vein weak
(tilted slabs with a clamped texture span, one dark blob for the slate, white blob for the marble). The second iteration fixed the texture spans (planar UVs clamp: the span `L` must cover the shape), built the slate as
stacked strata with pale cut edges and the marble as angular blocks with veins; the tent now reads as a striped ridge tent with an open dark door flap, guy ropes, a barrel, a crate and a lantern post.
Honest limits: the chests are 100-140 px wide sprites (small at zoom 0.4), the veins read as a stone pile and a pale boulder rather than as ore seams, the opened chest is a modulate + sparkle stub.

## Task 9 - the roofline (RV-A9)

The gate is mass: opaque pixel area **and** footprint of tier n+1 are strictly larger than tier n (`art_home.house_mass_monotonic`): 75207, 123854, 192094, 229322, 328653, 392280, 460719, 531418, 636927, 744411 opaque px;
footprints 2x2 3x2 4x3 5x3 5x4 6x4 7x4 7x5 9x5 9x6.
The spike's **roofline height dipped** at tiers 7 and 9 (opaque heights 399 432 571 620 761 966 **826** 1059 **1014** 1292 px: the Landsted stood lower than the Tårnhus, the Borg lower than the Herregård), which reads as a step down for one upgrade.
The stretch goal was done in this re-bake: the Landsted got a belvedere tower with a copper-green cupola on its mansard roof, the Borg got a keep and front towers raised by 1.2 m. The heights are now
399 432 571 620 761 966 **1014** 1059 **1099** 1292 px - monotonic (+5 % and +3.8 % over the tier before). `art_home.house_height_monotonic` guards it; had it not been done, the README would have had to say "accepted dip".

## Contact sheets (task 8) and the human verdict

`sheets.py` draws, from the exported WebP tree: `tiers_contact_sheet`, `tiers_strip_night`, `scaffolds`, `ladder_<template>` for every template (22 sheets; every one of the 91 existing (template, rarity) cells of the spec,
missing cells drawn as "no such piece"), `interior_wall_pieces` (with the four floors), `material_icons` (+ on night), `furniture_icons_130` (on kridt), `legendary_icons_on_night` (plain vs rim variant), `props` (day and night, glimmers additive), and (fix round) `distinct_pairs` (the three pairs that used to ship as twins, sprite and icon side by side) and `symmetry_views` (the 15 pieces whose declared symmetry was refuted, all four rotations).

## Verdict

**accepted on 2026-10-13** by the builder of A1 after looking at all sheets (sheets stored with the report; this folder keeps only the tools).

* `tiers_contact_sheet` / `tiers_strip_night` / `scaffolds`: ten clearly different silhouettes in the cast's soft CG style - shed with tarp, log cabin, thatch, half-timber, yellow farm with barn wing, round-tower house, white villa (now with a belvedere), brick manor with clock tower, stone keep, palace with gold and teal domes. 8/10.
  The night strip shows the windows and lanterns lit from the additive layer; the scaffolds read as construction over the previous house. Weak: the grey-violet stone of tiers 6, 9 and 10 is a bit uniform at 1:1.
* `ladder_*` (22 sheets): BIG pieces (beds, sofas, thrones, bookshelves, pianos, chests, wardrobes, fireplaces) change shape and material up the ladder - strong (8/10). SMALL DECOR (sconce, vase, table lamp, candelabra, shelf, chair, plant) differs between rarities mostly by palette (6/10).
  On 8 of the 11 complete templates the legendary silhouette equals the rare one (bookshelf, rug, floor_lamp, fireplace, chest, clock, piano, chandelier); only bed, sofa and throne change shape - the legendary look there is palette plus separate sparkle layers.
  Found and fixed while looking: tabletop pieces (vase, lamp, candelabra) carried a full-tile diamond shadow, now a small contact ellipse.
* `furniture_icons_130` and `material_icons`: one family with the 60 cast icons (ink outline, no shadow, fill about .91); rugs and vases remain small shapes; the blueprint rolls are small but distinguishable by their seals; hollow-looking shirts do not occur here (that is A2).
* `legendary_icons_on_night`: without the rim the dark pieces (clock_moon, piano_star, chest_rune, bookshelf_floating, chandelier_star) vanish into the night tile; with the pale rim all eleven read clearly.
* `interior_wall_pieces`: cosy cut-away walls in three styles with matching floors; seams between neighbouring pieces were not walked live (periodic textures by construction). 7.5/10.
* `props`: see task 5 above.
* A throwaway Godot driver (not committed; F6 owns the real checkpoints) drew tiers 1, 5 and 10 with the 4->5 scaffold, by day and by night, and the rooms of tiers 5 and 10 in a real 1280x720 window with the
  project defaults (sprites linear + mipmaps, floors linear without mipmaps): the parquet and marble floors tile without seams, walls and furniture line up on the iso grid, true r1/r3 chairs stand correctly,
  the trimmed night layers land exactly on the windows at `night_offset`. The sparkle glow of the legendary pieces looked too strong with the driver's naive halo - a tuning job for F6 (strength and radius are in furniture.json), not an art defect.

* **Fix round after the independent review (2026-10-13), looked at on `distinct_pairs`, `symmetry_views` and the re-drawn `ladder_*` sheets.** The small-decor ladders were checked for duplicates - and the first verdict had MISSED three pairs of
  distinct ids that shipped as pixel-identical twins (sprites AND icons), because a template ignored its style key at one tier: `curtain_natural` = `curtain_green` (the tier-0 curtain hard-coded cream), `fireplace_marble` = `fireplace_slate`
  (tier 2 forced white marble over `stone: skifer`), `floor_lamp_iron` = `floor_lamp_birch` (the tier-0 pole ignored `wood`). All three templates honour their key now (green plain cloth; slate-blue slab fireplace; turned pale birch stand on a wooden foot,
  the default pine style stays the wrought-iron lamp). The ladders and the icon sheet were looked at again, and the check is mechanical now: `art_home.furniture_looks_distinct` / the validator hash every r0 sprite and every icon (162) and compare
  the same-template pairs (mean difference over the union below 2/255 with the same silhouette = the same picture); closest legitimate pair `candelabra_copper` / `candelabra_brass` at 4.7/255 (metal colour only - the small-decor weakness below).
  The symmetry fix (15 pieces, see "Rotation policy") was looked at on `symmetry_views`: the rotated plants, vases, the bonsai (teapot spout, leaning trunk), the walnut table and the stump table now show their real other sides.

**Known weaknesses:** no wood-grain brushwork (soft CG, not hand-painted); legendary float layers bob as a plain y-offset by the engine; small decor ladders are palette-only; the nine props are new builders that were only iterated twice;
the interior was never walked with collision; Godot windowed checkpoints (farm_t1, farm_t5, farm_t10_castle with +3 growth rows, room_t1, room_t5, room_t10) are F6's job at wave 5.
Fix-round additions: pairs of small decor that differ by a metal or paint colour only exist by design (candelabra copper/brass, table lamps clay/brass); wall and ceiling pieces have no ground shadow, so their anchor check is coarse (30-125 px window);
the pixel anchor checks catch a pivot shifted by 20 px or more, not a drift of a few px; the symmetry measurement is a threshold (4 % silhouette / 20 colour) on an ss 2 bake. A **content request** if it matters: new legendary silhouettes for fireplace, clock, piano, chest and bookshelf.

## Handoffs (files this package does not own)

* P08 (`tools/art/core/static_render.py`): `model_mesh()` has no tile cache and no `planar` guard for planar-UV shapes (the home spike's copy had both); A1 carries local equivalents in `bake_lib.py`, so nothing is blocked - merge them into the core if another package needs HM shapes.
* F6 (HomeExterior2D): the night layer is trimmed, place it at `night_offset`; the wall/ceiling pivot convention above; `iso_props/home/home.json` has no money fields.
* F3/F6 (furniture): `furniture.json` files are relative to the json; the mirror list is only a disk fallback and F6 does not flip by default.
* F1 (validator R19): `specs/content_contract.json` is the snapshot to prove against `lua/data/home_tiers.lua` and `lua/items/*.lua` (regenerate with `isometric/make_content_contract.py --features DIR` where DIR holds F1's `reports/lua_dump.json`).

## Lift history

| File | Source | Changes |
|---|---|---|
| `characters/{home_kit,home_traetoppen,home_scaffold,furniture_traetoppen,icons_materials}.py` | `SH/tools/characters` | sys.path hacks removed; `home_data` without Danish texts and money (`UPGRADE`), with `zoom_fit`; `icons_materials` decoupled from `icons_traetoppen`, +5 builders; tiers 7 and 9 re-modelled (tall belvedere, raised keep and towers) |
| `characters/props_traetoppen.py` | spike (same file P22 lifts) | none (header only): vendored |
| `isometric/{bake_lib,bake_home,bake_furniture,bake_interior,bake_material_icons,export_home,ladder,sheet_tiers,sheet_scaffold}.py` | `SH/tools/isometric` | `homepaths`, stage defaults, `--only`, trimmed night layers, spec instead of `furniture_catalog`, contract-style icons, relative json paths, no names/prices/money, tabletop contact shadow |
| `isometric/{icons_contract,night_rim,icon_audit,measure_mirror,make_content_contract}.py` | `FR/tools` | scratch paths removed; `icons_contract` reused for materials; `measure_mirror` reads the exported WebP and writes `specs/mirror_ok.json` (fix round: laid out from the pivots, a ceiling piece compared as two empty canvases) |
| `isometric/measure_symmetry.py`, `specs/symmetry_measured.json` | new (fix round) | measures the declared c4/c2 classes; `spec_reader.symmetry()` uses the result |
| `characters/furniture_traetoppen.py` (fix round) | A1 | `STONE_TEX`; curtain tier 0 in the `fabric` colour; fireplace tiers 0 and 2 follow `stone`; floor lamp tier 0 follows `wood`; `characters/home_data.py`: room `_contract` + `windows_by_wall` |
| `isometric/bake_tiles_vendored.py` | `SH/tools/isometric/bake_tiles.py` (= P22's) | two marked edits, vendored |
| `specs/*` | `FC/data`, `FR/artifacts` | copies (`mirror_ok.json` and `material_icon_map.json` are new) |
