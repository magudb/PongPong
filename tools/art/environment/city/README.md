Current installed artwork follows the painted guide, including historical fixture paths.
`build_city.sh` retains the geometry stage for experiments and restores painted
fixtures after installation. See `docs/art/style-audit/current/` for the current
review; the original work-order record below describes the geometry prototype.

# tools/art/environment/city - the art of Trætoppen, the levelled treetop city (package V5-art-city)

Platform discs, tileable trunks, ten round huts with additive night layers, pennants, lanterns, the procedural-bridge tiles, the set dressing of the ten landmarks, the front
foliage, the canopy frame and the treetop backdrop: **67 textures + 10 trimmed night layers** under `assets/iso_props/city/` and `assets/backdrops/treetop_{sky,far}.webp`.
Same camera, scale and outline as every world sprite (36 degrees, 87.074 px per metre, the pack's warm outline (75,60,73) at 55 % and 2 px on the finished sprite) - soft CG
pieces, **not** the flat painted vector of the Style Guide sketch (`docs/Trætoppen Style Guide Review/refs/miljoer_v2_render.png`, a "formskitse").
The set is STRICTLY ADDITIVE: it never touches an existing asset (Codex restyles those), it never runs `tools/art/produce_all.sh`, `storybook/*` or `drawn/*`.

## Run (repo root)

```
tools/art/environment/city/build_city.sh                 # bake (~40 s) -> validate the stage -> install -> validate the install, stage tools/art/_stage/city
tools/art/environment/city/build_city.sh /path/outside/the/project/stage   # any stage outside the project works too
tools/art/environment/city/build_city.sh --only=hut_m_straw,fire_pit        # a few ids (the stage keeps the rest)
python tools/art/environment/city/city_spec.py --k 2.4   # the size table at another K (the only place the numbers live)
python tools/art/environment/city/validate_city.py       # the pure-Python validator of the installed set (second implementation of the section)
python tools/art/environment/city/sheets.py pieces --stage DIR --out DIR2      # contact sheets, never single frames
python tools/art/environment/city/sheets.py composite --stage DIR --out FILE   # one platform with trunk, huts, props, bridge next to the sketch crop
tests/run_playtest.sh --only=art_city                    # the headless section; --windowed adds the real-engine seam check and the screenshots
```
After an install: `godot --headless --import` twice in a clone, then `impl/tools/pull_meta.sh V5-art-city assets/iso_props/city assets/backdrops/treetop_sky.webp assets/backdrops/treetop_far.webp`
(the `.import` files are committed with their base file).  `install_city.py` writes ONLY `assets/iso_props/city/**` and `assets/backdrops/treetop_*` and removes only stale files of those.

## K is ONE constant

`lua/config/traetoppen.lua` `scale = 3.0` (V3's file) is the single scale; `city_spec.py` reads it (no literal), the sizes of the work order are written for K = 3 and every size is
`round(size_at_3 * K / 3)` (the bark tile height 512, the canopy and the backdrops are fixed).  Change the Lua constant, run `build_city.sh`, the whole set rescales linearly;
the check `art_city.sizes_scale_with_k` fails when the set was baked for another K than the Lua value.

## Files

| File | What |
|---|---|
| `city_spec.py` | the table: sizes at K = 3, the disc / trunk / hut classes, the pennant colours, the hut of every building (`HUT_OF`), the memory estimate |
| `paint.py` | numpy / Pillow toolkit: signed-distance coverage, periodic noise, the pack outline |
| `paint_platforms.py` | the four platform discs (radial planks, rim skirt) |
| `paint_trunks.py` | bark tile, foot arc, root flare, the two owl holes and the shelf |
| `paint_bridge.py` | deck tiles, rail post, rope tile, ladder tile, lift basket and pulley |
| `paint_decor.py` | pennants, lantern, door lamp, flame frames, hanging bat, front foliage, canopy, sky, far layer, shared shadow |
| `models_city.py`, `bake3d.py` | VTK models (huts, stall, fire pit, tub halves, planters, log stack, notice board, seed basket, bat house) and their baker (`fit` scales a model to the table size) |
| `bake_city.py`, `install_city.py`, `build_city.sh` | stage masters + `props.json`, the installer (lossless WebP, no-mipmap stubs for sky / far), the one-shot |
| `validate_city.py`, `sheets.py` | the Python validator and the Pillow contact sheets |

## Contracts the consumers (V3 / V4 / V6) rely on

* **props.json** (ArtCatalog unions `iso_props/*/props.json`): `{file, size, pivot, footprint, blend?}` + city keys. `_city` holds `k`, `hut_of` (the sprite of every building of
  `data/traetoppen/traetoppen.json`: h1..h13, raadhus), the tile usage and the night rule.  Multi-frame pieces list their frame ids in `frames` on the first frame
  (`pennant_<colour>` + `_f1`, `fire_flame` + `_f1` `_f2`, `bat_hang` + `_f1`).  Files are **lossless WebP**; props import with mipmaps; `treetop_sky` / `treetop_far` without (4.1 MB saved).
* **Pivots.** Discs: the centre of the top ellipse (draw in a non-sorted node at `rank - 4`, never sliced).  Huts, stall, fire pit, log stack, notice board, planters, seed basket: the ground
  centre (huts: the wall-circle centre on the floor; `apex` = where a pennant pole goes).  Tub halves: the water-surface centre (both halves, so back / Sofus / front line up).
  Bat house: the cone tip (`tip_y` of the data), the hanging bat hangs from it (its pivot is its hook).  Lantern: the glass-body centre (the data point of a sketch lantern).  Tiles (bark, deck,
  rope, ladder): the tile centre.  Foot / root: the centre of the base ellipse.  Basket: the bottom centre.
* **Trunks.** `trunk_bark_w<W>` is 512 tall and wraps vertically: a `Sprite2D` with `region_enabled`, `texture_repeat` ENABLED; end an upper segment at tile row 512 and put `trunk_foot_w<W>`
  at the centre of the base ellipse (its first 30 px are tile rows 0..30, so the pattern continues); `trunk_root_w<W>` is the flare of a LOWER trunk's ground end.  Widths 367 / 404 / 441 / 698 = 2 x rx x K.
* **Bridges.** `bridge_deck_tile_w43` (129 x 128) / `_w28` (85 x 128) are Line2D tiles (`LINE_TEXTURE_TILE`, repeat enabled): a Line2D maps the tile's X along the line and its Y across the width, so the
  planks are vertical bars and the two edge beams are the first / last 9 % of the height.  `bridge_post` (pivot = foot) is placed every ~46 sketch px, the rope ties at 72 px above the foot.
  `rope_tile` is a vertical rope (the lift rope: `Sprite2D` region + repeat).  `ladder_tile` (60 x 112): two rails, two rungs per tile (56 px pitch, 9.6 rungs per 180 sketch px), vertical region + repeat.
* **Night.** Every hut has `<id>_night`: an ADDITIVE layer (`blend: add`) holding the lit door and the two windows, trimmed to its lights (`night_offset` = px from the day sprite's top-left; its
  `pivot` is relative to the trimmed image).  Fade it with the night factor like A1's house tiers.  Hanging lanterns / door lamps take their halo from the existing `iso_props/fx/glow_soft.webp`.
* **Huts.** 3 wall sizes x roof colours straw c9a052 / moss 8fb85a / dark straw b88a3e + the lavender Raadhus roof 9b86d6 = 10 sprites for the 14 buildings; `wall_r` in each entry is the sketch
  radius it was baked for (data radii differ by up to 11 %: draw the sprite at `data.wall_r / wall_r` if the collision circle should match exactly).
* **No baked shadows** (the sizes are the table sizes); `shadow_soft` (256 x 128) is an optional shared soft shadow the engine can scale per object.
* **Fire / flames.** `fire_pit` is the ring + logs; `fire_flame` frames are additive (`blend: add`): draw them with the same pivot as the pit.  The steam of the tub is three white wavy particles, not a texture.

## Honest notes

* Soft CG pieces, not the sketch's flat painted vector: discs 7/10 (the planks are analytic, clean and a little mechanical), huts 7/10 (the same family as P22's mushroom houses; the roof dominates because the
  table is the sketch's drawn proportion, not a 36 degree ellipse), trunks 7/10 (the 698 px main trunk repeats visibly every 512 px).  The stall is P22's market_stall recoloured and squashed to the table size.
* The sizes are the work order's table.  Where the table is the analyst's approximation (a hut's wall base is drawn flatter than a true 36 degree ellipse in the sketch; the stall and log stack are
  low and wide) the model is fitted to the table by an affine scale, so those pieces are lower than a strict 3D model of the same width: `fit` in props.json says by how much.
* The hanging bat is a static sprite with a 2-frame sway (the pack has no hang clip): honest stub.  The tub's steam and the chimney smoke of the sketch are particles of V6, not art.
* Open question 12 (the world-sprite outline: the pack's warm one or the sketch's ink one): the set uses the pack outline everywhere (painted pieces: `paint.OUTLINE_COLOR`; the VTK bakes: `static_render.warm_outline`). The A/B sheet of the two outlines is V2's; switching this set needs those two places and a re-bake.
* A single hand-painted key plate of the whole city is NOT part of this package.

## Deviations from the work order (all reported)

| Order | Shipped | Why |
|---|---|---|
| `canopy_top_strip` 2560 x 400, used at scale .5 | **2048 x 320**, draw at `viewport_width / 2048` | the order also says nothing above 2048 px on a side and <= 70 MB; N03's `farm_canopy` is 2048 x 360 |
| total <= 70 MB RGBA8 + mips with every listed size | 66-68 MB: `treetop_sky` / `treetop_far` are imported WITHOUT mipmaps (stretched / magnified by the parallax), everything else keeps them | the listed sizes alone sum to 72-76 MB (the analysis estimate of 65.4 MB left the foliage out) |
| `rope_tile (30x186)` | a vertical rope strand 30 x 186; the sagging bridge ropes stay V3's plain Line2D | a Line2D maps tile X along the line: a 30 x 186 tile cannot be a horizontal rope |
| `ladder_tile (60x112)` with 9 rungs per 180 sketch px | two rungs per 112 px tile (9.6 rungs per 180 px) | 112 is not a multiple of the 60 px pitch of 9 rungs; the order's size wins |
| `lantern_hang 90 x 150`, `lamp_door 55 x 55` (analysis table) | 54 x 96 / 54 x 54 | the sketch lantern is a 14 x 18 rect plus a cord (about 48 x 84 px at K = 3); the analysis row is 1.9 x larger than anything in the sketch and than V3's stand-in |
| world-sprite outline "ink 2b2340" (lift note) | the pack's warm outline | contract 6.2 and the addendum's palette note keep the pack outline until the user answers open question 12 |
| budget "textures: 55" | 65 sprites + 10 trimmed night layers + the two backdrops = 77 files (67 textures without the night layers) | the 55 of the order counts base ids; the extras are what the order itself lists as frames and variants (4 x 2 pennant sway frames, 3 flame frames, 2 bat frames, the berry planter, the second owl hole) plus the optional shared `shadow_soft` |

Pre-existing paths touched: **none** (no file that existed before this package was written, created, changed or deleted; the only paths written are `assets/iso_props/city/**`, `assets/backdrops/treetop_*`,
`tools/art/environment/city/**` and `tests/sections/art_city.gd`).

## Verdict (human, after looking at the contact sheets, the composite and the windowed screenshots)

accepted at 2026-10-14 (build team, stage 2 of milestone 1a), after looking at `art_city_pieces_zoom04.png` / `_zoom02.png` (every sprite on grass at the game zoom 0.4 and 0.2), the assembled
platform by day and at dusk (`art_city_platform_day.png`, `_night.png`: real engine, Sprite2D region + repeat trunks, a Line2D bridge, the additive night layers and halos), the four bark tiles through
`texture_repeat` (no visible seam, the wrong-phase control does show one) and `composite_platform_a_vs_sketch.png` (platform A rebuilt from the baked pieces next to the Style Guide v2 crop).
The set reads as the same family as the pack and P22 (soft CG, warm outline), the proportions follow the sketch, the huts / disc / bridge / trunk assemble into a platform that looks like the sketch's
Hoppe platform; it does NOT have the sketch's flat painted vector finish (the "formskitse" look).  Self-score: discs 7/10, huts 7/10, trunks 7/10, bridge parts 8/10, set dressing 7/10, backdrop 7/10.

Known weaknesses (the lead's call whether any needs a second pass): (1) the planks of the disc are analytic radial planks: clean and a little mechanical, the rim skirt is one brown band;
(2) the hut roof dominates the wall because the work order's table is the sketch's drawn proportion, and the windows are plain ovals; (3) the 698 px main-trunk bark repeats visibly every 512 px (the
seam is invisible, the pattern is not); (4) the front foliage reads as pale leaf blobs (five circles at alpha .5 exactly as the sketch, no leaf detail); (5) the hanging bat is a static sprite with a
2-frame sway (the pack has no hang clip) and the bat house is a drum + cone, not the sketch's pure cone; (6) steam, chimney smoke and Sofus are V6 / V2 matters, not art here; (7) the Codex storybook /
hand-drawn finish pass is NOT applied (strictly additive package; bake pristine, the finish is applied later); (8) two measured deviations from the order: the canopy is 2048 x 320 and the two backdrops
are imported without mipmaps (see the table above).
