# ORTHO_DECISION - Moerkeskoven floors: `ortho`

Decision: **`ortho`** (the forest maps use `@projection ortho` with the square 96 x 56 floor; the `iso fallback` is NOT needed).
Date: 2026-10-14. Package: P22-art-environment (M1a stage 1). Binding sources: PLAN D5 / review R.2 / R.16, DUNGEON addendum 3.4 and 7.5.

## What was baked and how it passed

* `tools/art/environment/bake_tiles.py` got the ortho mode the plan asked for: the character camera turned to **azimuth 0** (elevation stays 36 degrees),
  a **rectangular mask**, tile **96 x 56** (the ground square of the tile is 1.1025 m wide and 1.0941 m deep, so it is EXACTLY 96 x 56 px at 87.074 px/m and the
  engine lattice matches the render to the pixel), atlas cell 112 x 64, the same periodic 4 x 4 canvas trick (any neighbour matches), 1.4 px of overscan.
* Seven terrains, `assets/iso_tiles/ortho_<terrain>.png` + `tiles.json` entries with `proj: ortho`, `tile: [96, 56]`, `cell: [112, 64]`:
  `forest_floor_o`, `forest_floor_glow_o`, `moss_path_o`, `bog_o` (ground_block), `cave_floor_o`, `crystal_floor_o`, `wall_void_o`.
  The colours follow the baked-colour rule of the night look (final = albedo x ambient 4d5e85 / cave 343b5c): the floor is the sketch's `#232a45`
  divided by the grade, and the engine shows exactly the sketch colours (measured in a window: floor `232b48`, path `3d3e61` against the sketch's `3b3c5e`,
  water `1d4c5c` against `1c4a5a`).
* **The ortho bake passed its QA gate on the first attempt** (the "two attempts" rule never came into play). Evidence, all in `tests/sections/art_environment.gd`:
  * headless `ortho_tiles_periodic_edges`: the seam between neighbouring variants of every ortho atlas is no rougher than the texture itself;
  * windowed `filter_seams_mix_forest_ortho_zoom_30 / 40 / 70` and `filter_seams_mix_path_ortho_zoom_*`: forest floor + glow floor and floor + path mixed in the engine's
    lattice show no hairline at zoom 0.3 / 0.4 / 0.7 (luminance step across the borders 0.7 - 2.8 / 255 against 0.6 - 1.3 / 255 across the tile middles, limit excess 3 / 255;
    the negative control with a deliberate 20 / 255 hairline is caught);
  * windowed `forest_ortho_readable`: at zoom 0.4 on the night floor the outline (75,60,73) of a figure, the dark outline of a crown, the lit path and the pond stay readable.
* Screenshots looked at: `art_environment_forest_view.png`, `art_environment_forest_wide.png`, `art_environment_forest_player.png`, `art_environment_forest_ground_probe.png`,
  `art_environment_seams_mix_forest_ortho_zoom_40.png`, `art_environment_seams_mix_path_ortho_zoom_40.png` (and `fixture_ortho.png` of `tests/shot_world.tscn`).

## Consequences the other packages need

* `rim.wall_depth = 0` from the start: D1 ships `lua/config/dungeon.lua` with 0 and the 12 golden digests of that table (the first draft planned 1 until the crowns were baked,
  a flip that nobody owned). The iso fallback uses `rim.wall_depth_iso = 0` too. Measured by the dungeon track: `_enter` of the iso fallback 73 / 73 / 145 ms with wall depth 1
  against 35 / 40 / 61 ms with wall depth 0; rendering is 1.0 - 2.1 ms cheaper in ortho.
* **The forest look does not depend on `ortho` vs `iso fallback` for its crowns.** A crown is a SPHERE and a sphere is a circle under any camera: `crown_{s,m,l}_{a,b}` are baked
  with the project camera (36 degrees, azimuth 45) as spheres of leaf clumps, disc radius 170 / 230 / 300 px, the sphere centre 0.81 R above the sort pivot (the ground contact
  point), a baked ground shadow squashed to sin 36 = .59. No 90 degree art and no new bake mode exist. Only the floor tiles (and the remaining border wall) differ between the two
  projections: an `@projection iso` forest map keeps its crowns and swaps `ortho_*` terrains for the diamond `forest_floor` / `forest_floor_glow`.
* The 1-cell walls `forest_wall_a/b/c`, `cave_wall_a/b` and their edge / corner variants are DROPPED (the sketch's crowns are 3.1 - 6.8 cells wide); `wall_void_o` stays as the dark map border.
  P04's `AreaTileSet.WALL_PROPS` and `IsoArea._wall_prop_for` still name the dropped ids (handoff in the P22 report); they only matter for `W` cells, which the generated floors do not
  have (`rim.wall_depth = 0`).
* The sketch's smooth S-curve path and the Moon pond are DECALS (V8's SoftGround draws them on `ground_fx` with the seamless `path_tile_o`, `pond_water_o`, `floor_patch_{a,b,c}`);
  the tiles underneath keep their hard cell edges (collision, minimap, reachability) and are the fallback look when the shader or a texture is missing. There are no terrain
  transition tiles in this build (honest limit).

## How to flip back (not planned)

A forest map is switched to the iso fallback by its header (`@projection iso`) and by replacing its wall characters; no art has to be re-baked: the diamond terrains and
`tree_pine_forest` already exist, and the crowns are projection independent.
