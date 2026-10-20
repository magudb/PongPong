# tools/art/environment/farm - the farm art kit of Trætoppen (package N03-farm-art)

The live field and grass materials are now painted atlases from
`tools/art/drawn/terrain.py`. The original field PNG and grass PNG remain for
this kit's source validator. `ArtCatalog` resolves the painted overrides; the
windowed seam check exercises those actual runtime textures.

The art the treetop farm (`data/maps/farm.map`) needs and nobody else bakes: the **ten farm-only props**, the **two backdrop layers** `farm_far` / `farm_canopy`, and the untilled-field
terrain **`field_grass`**. Same pipeline and scale as the rest of the environment art (P22): ONE orthographic camera at 36 degrees elevation, 87.074 px per metre, azimuth 45, three
lights, the warm pack outline (75,60,73) at 55 %, soft contact shadow, ground-origin pivot. Smooth and hand-painted in look, never pixel art; sprites are never scaled individually.

## Quick start (repo root; bash or zsh)

```
tools/art/environment/farm/build_farm.sh          # bake + install + import stubs + budget table + validator, about 45 s
python tools/art/environment/farm/validate_farm.py   # the second implementation of the art_farm checks (10 PASS lines)
python tools/art/environment/farm/farm_sheet.py --out DIR --pivots   # Pillow contact sheets of the SOURCE files (big, small, field, backdrops)
python tools/art/environment/farm/write_farm_imports.py --check      # audit of the .import presets
tests/run_playtest.sh --only=art_farm                                # the headless section (22 checks)
tools/dev/run_windowed.sh tests/run_playtest.sh --windowed --only=art_farm --out=DIR   # vram measured, S3TC error, contact sheets from the imported textures, the farm at noon / dusk / night
```

`build_farm.sh` does NOT use `tools/art/produce_all.sh`: its `--only=props` slice would re-bake and re-install P22's 149 existing props. It writes to `tools/art/_stage/n03` (gitignored,
hidden from Godot by `tools/art/.gdignore`) and `install_farm.py` copies an **allow-list** to `assets/` (below). Godot's `.import` / `.uid` files are pulled back from a clone after the
import (`impl/tools/pull_meta.sh N03-farm-art ...`), exactly as for every other art package.

## What is shipped (and where)

| Path | What |
|---|---|
| `assets/iso_props/farm/<id>.png` + `props.json` | the ten props (ArtCatalog reads every `assets/iso_props/*/props.json`): `trunk_giant_a` 1227x2405 pivot (622,2092) 5x3, `trunk_giant_b` 1274x2142 (685,1903) 3x3 SOLID (the orchard trunk with the tree hollow), `trunk_under_a` 907x1352 (454,139) and `trunk_under_b` 746x1306 (371,117) (pillars under the deck: the pivot is the deck plane), `tool_shed` 316x313 (140,246) 2x2, `shipping_bin` 226x182 (100,138) 2x1 lid open, `stake_sign` 84x124 (38,105), `rope_stake_x` / `rope_stake_z` 87x97 (41,72), `build_stake` 76x118 (35,100) |
| `assets/backdrops/farm_far.webp` | 2048x1024, seamless in x, three depths of shaded trunks + a leaf band + mist, transparent soft top (Parallax2D "Far", scroll 0.5, drawn at 1.5) |
| `assets/backdrops/farm_canopy.webp` | 2048x360, the leaf frame with hanging vines, faded lower edge (N02's canopy handler draws it as a CanvasLayer) |
| `assets/iso_tiles/field_grass.png` + `tiles_farm.json` | 576x336 = 4x4 periodic diamond cells of 144x84, the untilled look of an `f` cell (FarmView applies it, P06 amendment) |
| `<each>.import` | stubs by `write_farm_imports.py`, completed by Godot (below) |

**No `farm_sky.webp`** (lead amendment M1a): Codex's painted `assets/backdrops/farm_sky.png` (on main) is the farm sky; `art_catalog.gd` loads `<theme>_sky.webp` first, so a webp would
shadow it. Until the lead merges Codex's PNG, `ArtCatalog.backdrop(&"farm").real` is false on this tree (P04's gradient sky stands in behind the real far layer): `art_farm` says so with a
SKIP line, never silently. `warp_gate_stone` (P22's forest-hub prop) and `dock_x` of the prototype are not shipped here.

## Import settings and memory (TOWNS addendum TE9 / DT29)

`tools/import/write_import_stubs.py` now holds one import policy for every texture (review REND-03: props and backdrops S3TC), and the painted consistency pass repaints the ten
props and the far layer (ArtCatalog draws those; the N03 bakes are no longer kept, review REND-10). Before that, P05's tool covered only the character sheets, the tile atlases and the
wardrobe layers, so `assets/iso_props/**` and `assets/backdrops/**` would have stayed lossless (the kit 56 MB), and this package wrote the same minimal stub itself (`write_farm_imports.py`, audit with `--check`): the ten props, `farm_far` and `farm_canopy` use `compress/mode=2`
(VRAM compressed S3TC, `high_quality=false`) with mipmaps and `process/fix_alpha_border=true` (`project.godot` has `import_s3tc_bptc=true`; BPTC does not exist in the Compatibility renderer
on macOS); only `field_grass.png` stays lossless **without** mipmaps (periodic cells bleed into each other at mip >= 1). A stub is honoured on the first import in Godot 4.7.2
(`trunk_giant_a`: a 3.95 MB `.s3tc.ctex`).

Measured in a real window (`art_farm` windowed, `Performance.RENDER_TEXTURE_MEM_USED` before / after the whole kit is loaded and drawn, on a clean baseline): **14.9 MB** (trunks 10.1, other
props 0.2, backdrops 3.6, field_grass 1.0) against **56.1 MB lossless**; the arithmetic of `art_budget.py` says 14.6. Budget 20 MB. (The prototype measured 15.8 / 65.5 including the 1024x1024 farm_sky
that this package no longer ships.) Mean error of the imported textures against the source on the visible pixels: 2.2 - 3.0 / 255 on the big textures, 3.8 - 4.9 on the thin small props;
the 60 %-height trunk fallback of the farm design is therefore NOT needed.

## Files

| File | What |
|---|---|
| `props_farm.py` | the ten builders (`FARM_KIT`), the measured size table (`FARM_CONTRACT`), and the builders of the eight P22 contract props kept as `P22_REFERENCE` (never registered, never baked here; `check_reference()` proves their footprints). Loaded BY PATH: this folder also contains a `props_farm.py` and P22's own `tools/art/environment/props_farm.py` must not be shadowed |
| `farm_common.py` | paths, id lists, `prepare_path()` (removes this folder from `sys.path`), `load_kit()` |
| `bake_farm_kit.py` | bakes the ten props with P22's `bake_props.bake_prop`, compares size / pivot / footprint with the contract (a DEVIATION makes the exit code 1) |
| `bake_farm_tiles.py` | `field_grass` with P22's `bake_tiles` (same farm grass base as `grass`, lighter and warmer, faint furrows, soil specks) |
| `backdrops_farm.py` | `farm_far` + `farm_canopy` (Pillow + numpy, wrap-aware blur, deterministic) |
| `install_farm.py` | the allow-list copy into `assets/`; refuses `farm_sky.*`, never deletes, writes only when bytes differ |
| `write_farm_imports.py` | the S3TC / tile stubs and the audit |
| `art_budget.py`, `art_budget.txt` | the size and texture-memory table, made from the shipped files; its rows are the contract of `art_farm.sizes_match_art_budget_table` |
| `validate_farm.py` | the second implementation of the checks (10 PASS lines) |
| `farm_sheet.py`, `sheets/` | contact sheets (`sheets/art_farm_contact_big.png`, `_small.png` are drawn from the IMPORTED S3TC textures by the windowed section) |
| `build_farm.sh` | the one-shot build |

Tests: `tests/sections/art_farm.gd` (headless 22 checks, windowed 9 checks). Gameplay rows of the ten props: `lua/config/props_extra.lua` (P22's file, the 16 rows of design_farm.md 10.3; this
package defines no Lua key).

## Contracts (numbers the checks pin)

* Sizes, pivots and footprints = the measured prototype table (`props_farm.FARM_CONTRACT`, the test's `KIT`, `art_budget.txt`): three independent copies that must agree.
* `farm_far` repeats in x: the premultiplied step between its last and first column < 3 / 255 (measured 1.7), and a probe that compares two distant columns sees a break (21). Its top row is
  transparent and the mean alpha rises softly (row 100: 0.19, 200: 0.46, 300: 0.70). `farm_canopy` is solid at the top (0.88), fades over the last 90 rows and its last row is empty.
* `field_grass` differs from `grass` (mean colour distance 10 / 255, +7.9 luminance, 1.4x the vertical detail) and mixes with it without a hairline at zoom 0.3 / 0.4 / 0.7 (windowed probe + negative control).
* Reuse (never re-baked here): the spike props (trees, bush, rock, fences + gate, scarecrow, lantern post + glow, bridges, platform skirts), the 8 crops x 4 stages, A1's house tiers + night
  layers + scaffolds + tent + glimmers, P21's farm animals, the pack hedgehog bust and fairy_king's portrait (`art_farm.reused_ids_exist`, 91 ids).

## Codex coexistence (2026-10-14)

Another agent restyles the existing assets (the "storybook finish", the hand-drawn sprites). This package is strictly additive: it creates files only in `assets/iso_props/farm/`, as
`assets/backdrops/farm_far|farm_canopy.*` and `assets/iso_tiles/field_grass.*` / `tiles_farm.json`; it never touches, re-bakes, renames or deletes an existing asset, never runs
`tools/art/storybook/*` or `tools/art/drawn/*` or `produce_all.sh` for an existing id, and bakes pristine (no extra painterly effect): Codex's finish pass is applied to these files later.

## Honest notes

* **Style gap to the guide.** The kit is soft 3D-rendered sprites in the family of the rest of the game. The guide's sketches (`miljoer_v2_render.png`: the city in the trunks) are flat vector art
  with a heavy ink outline and drawn bark. Ours: the trunks are stout cylinders with root buttresses and clumps of leaf spheres (lumpy at 1:1, fine at game zoom 0.4), the bark has a soft
  mottled texture, not drawn grain; the outline is the thin warm pack outline, not ink. The backdrops are procedural: three depths of shaded trunks and a canopy of many small leaf blobs; they
  read as the guide's "forest of trunks with a canopy and mist" and are not painted brushwork (Codex's watercolour sky, once merged, is stylistically ahead of them).
* The far layer of this package replaced the prototype's one: the prototype was 70 flat ellipses on straight rectangles (bubbles on poles) and looked like it at the edges of the farm;
  size, seam, top edge, mist and memory are unchanged. The `shipping_bin` of the prototype read as a closed crate with a floating plank (its dark hollow lay inside the rounded top); the opening
  now sits above it with a plank rim and three vegetables. The tree hollow of `trunk_giant_b` (the `trae_hulning` spot) lay INSIDE the prototype's trunk and never showed; it is now a dark opening with a
  bark rim and a little moss, flat against the face that looks at the camera, above the root buttresses (about 50 px at zoom 0.4). Sizes and pivots of all ten props are the prototype's, and eight of
  the ten props are the prototype's pixels within 1 / 255 (the bin and trunk_giant_b changed on purpose).
* Not here (said where they belong): hanging vines on the deck rim, foliage clusters, the city glimpse across the bridge (EXTENDED, N06), the dress props, the apple-tree seasons.
* A re-bake is reproducible to +-1 / 255 (offscreen GL is not bit-exact), so every rebuild shows the PNGs of the props as changed in git; the backdrops and the terrain are deterministic.
* `trunk_under_a / b` are only seen under the deck (N02's `underdeck` handler, z -11): the stage 2 picture of the farm does not show them yet; `shipping_bin`, `tool_shed`, `stake_sign`,
  `rope_stake_*` and `build_stake` are shown by N02's marker handlers (until then N01's stand-ins in `tools/farm/farm_standins.gd` draw them for the screenshots).

## Verdict (human, after looking at the contact sheets, the windowed screenshots and the real-art farm renders)

accepted at 2026-10-14 for M1a stage 2, **looked at after the S3TC import**: the contact sheets of `sheets/` are drawn from the textures read back out of the compressed files, and
`sheets/art_farm_s3tc_side_by_side_*.png` put a 1:1 crop of the source next to the same crop after compression. What that shows: outlines and colours are identical; the bark mottling and the leaf
texture of the trunks come out a touch softer, and the smooth, gradient trunks of the far layer show faint 4x4 blocks at 1:1. The engine never draws these textures at 1:1 (game zoom 0.3 - 0.7, the far
layer at 1.5 x zoom, from a mip level), and the farm at noon / dusk / night and the edges of the platform at zoom 0.4 show none of it. Compared with the prototype and the guide sketches the
farm reads as the same place with a better backdrop.
Known weaknesses: the ones listed under "Honest notes" (the style gap above all), a far layer that is procedural, trunks that are cylinders, thin props (`rope_stake`, `stake_sign`) that
carry the highest S3TC error (about 4.9 / 255), and the pending farm sky (Codex's PNG on main).

## Lift history

| File | Source | Changes |
|---|---|---|
| `props_farm.py` | design3 `farm/art/tools/characters/props_farm.py` | only the ten farm-only builders + the eight P22 reference builders (unregistered); `shipping_bin` opened, the tree hollow of `trunk_giant_b` made visible; the dress / dock / warp gate builders are not here |
| `bake_farm_kit.py` | design3 `farm/art/bake_farm_kit.py` | P22's `bake_prop`, stage-aware paths, contract comparison |
| `bake_farm_tiles.py` | design3 `farm/art/bake_farm_tiles.py` | P22's `bake_tiles`, byte-identical to the prototype's atlas |
| `backdrops_farm.py` | design3 `farm/art/backdrops_farm.py` | no farm_sky, wrap-aware blur, new far layer and canopy (see the honest notes) |
