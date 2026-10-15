The installed compatibility fixtures now use the approved paintings too.
`build_all.sh` restores them after the geometry export. The current review and
repair recipes are in `docs/art/style-audit/current/`; the original geometry
work-order record follows for manufacturing context.

# tools/art/environment - the environment art of Trætoppen (package P22-art-environment)

Ground tiles, props, painted decals / fx, seamless ground textures and the backdrops of the three zone looks (Trætoppen farm, Hyggebyen, Mørkeskoven). Same pipeline
and the same scale as the characters: ONE orthographic camera at **36 degrees elevation, 87.074 px per metre**, azimuth 45 for iso art (0 for the ortho floor), three lights
in camera space with the key light from the upper left, the warm outline (75,60,73) at 55 % on world sprites. Sprites are never scaled individually; zoom is the camera.
The look is **soft 3D-rendered sprites on periodic painted ground**, not hand-painted brushwork and never pixel art.

## Quick start (repo root; bash or zsh)

```
tools/art/environment/build_all.sh                    # tiles + props (via produce_all.sh) + backdrops + validator, about 90 s
tools/art/produce_all.sh --only=tiles                 # 17 diamond + 7 ortho atlases        -> assets/iso_tiles/ (+ tiles.json, no-mipmap import stubs)
tools/art/produce_all.sh --only=props crown_m_a       # one prop (or ids...)                -> assets/iso_props/ (+ props.json)
python tools/art/environment/backdrops.py             # hyggebyen + forest sky / far canopy -> assets/backdrops/*.webp
python tools/art/environment/validate_environment.py  # the second implementation of the art_environment checks
python tools/art/environment/compose_scenes.py --out DIR   # Pillow composites: farm, hyggebyen, forest, tiles (contact sheets)
python tools/art/environment/props_sheet.py --root DIR --out sheet.png [--grade 4d5e85] [--pivots] [ids...]
python tools/art/environment/tile_sheet.py --root DIR --out sheet.png ids...   # terrains laid out like the engine lays them (id+id mixes cells)
```

`produce_all.sh` runs `slice_tiles.sh` / `slice_props.sh` (this package's hooks); they bake into `$TT_ART_MASTERS/iso_tiles|iso_props`, the exporter copies them (tile
atlases get the no-mipmap stub), `install_assets.py` copies to `assets/`. Godot-written `.import` / `.uid` files are pulled back from a clone with `impl/tools/pull_meta.sh`.

## Files

| File | What |
|---|---|
| `bake_tiles.py` | periodic painted heightfield tiles, iso (az 45, 128 x 76, cell 144 x 84) and **ortho (az 0, 96 x 56, cell 112 x 64, rectangular mask)**; recipes of the 17 + 7 terrains |
| `bake_props.py` | model props (VTK) and painted props (Pillow) to cropped PNGs + `props.json` (pivot = ground origin, footprint, glow halo, `blend`, `proj`, `elev`) |
| `props_traetoppen.py` | the verified spike set: 55 props (trees, bushes, rocks, ore, crystals, mushrooms, fences, bridge, lanterns, chests, houses, platform skirts, 16 crops) |
| `props_farm.py` | the contract props of the treetop farm (RT16): coop_small, barn_small, animal_house, paw_prints, apple_tree, bench, signpost + mailbox_red + warp_gate_stone |
| `props_town.py` | Hyggebyen: seven mushroom-house variants with signs, well, fountain, three market stalls, plank stack, wheat sack, beehive stand, flagstones, door mat, roof-repair kit, lantern colourways, strawberry / sunflower / catnip / glow-berry x 4 stages |
| `props_forest.py` | Mørkeskoven: crowns (spheres at 36 degrees), bushes with eye hollows, Hulen rings, cave stones, home rope, runestones, lily, lake chest, thorn-berry; the **baked-colour ramps** |
| `props_images.py` | painted props: additive decals and fx (eyes, ripples, sheen, rune glow, telegraph rings / line, halos, sparks), seamless 256 px textures, mist, lantern light |
| `backdrops.py` | `<theme>_sky.webp` (1920 x 1080) + `<theme>_far.webp` (2048 x 1280, seamless in x, transparent top) for hyggebyen and forest |
| `compose_scenes.py`, `props_sheet.py`, `tile_sheet.py` | QA contact sheets (never judge from one frame) |
| `validate_environment.py` | pure-Python checks of the shipped assets (tiles, props, farm contract, crowns, albedo, textures, backdrops, props_extra rows) |
| `slice_tiles.sh`, `slice_props.sh`, `build_all.sh` | pipeline hooks and the one-shot build |

Tests: `tests/sections/art_environment.gd` (headless, independent of the Python validator) and its `run_windowed` (seam probes at zoom 0.3 / 0.4 / 0.7 for every mixed pair,
`forest_ortho_readable`, the screenshots). Gameplay of every prop: `lua/config/props_extra.lua` (this package owns it; `props.lua` is P04's, `props_features.lua` A1's).

## Contracts (numbers the checks pin)

* **Tiles:** iso tile 128 x 76 in a 144 x 84 cell, periodic 4 x 4 variants, `atlas_coords = (cell.x % 4, cell.y % 4)` (water 2 x 2: four frames, four layers in the engine), 1.4 px overscan;
  **ortho** tile 96 x 56 in a 112 x 64 cell, `proj: ortho`, file `ortho_<terrain id without _o>.png`. Tile atlases import **without mipmaps** (stubs written by the exporter).
* **Props:** PNG with the ground origin as `pivot` (px from the top-left), `footprint` in cells, optional `<id>_glow.png` additive halo, `blend: add` for additive sprites; props import with mipmaps.
  Farm contract sizes (RT16): coop_small 350x295 (155,218) 3x2, barn_small 472x424 (208,313) 4x3, animal_house 319x270 (143,199) 3x2, paw_prints 39x49 (16,29), apple_tree 359x398 (172,355),
  bench 174x144 (78,107) 2x1, signpost 84x130 (38,112).
* **Crowns:** R 170 / 230 / 300 px, centre 0.81 R above the pivot, shadow squashed to .59 with the sketch's (16, 20) x K=3 = (48, 60) ground px offset, sizes 400-411 x 447 / 513-525 x 589-593 / 671-674 x 756-758 (the table's 'about 400x420 / 530x550 / 670x690' plus the shadow ellipse, within 12 %).
* **Night look (baked-colour rule):** final = albedo x (ambient + lights) with ambient 4d5e85 (x0.30 / 0.37 / 0.52): the albedo of a forest prop is the sketch colour divided by that; whatever needs
  R > 77, G > 94 or B > 133 is clamped (marked `clamped` in the manifest) and made readable by an additive layer (`rune_glow`, `pond_sheen`, `eyes_glow` ...) or by an unshaded actor (V8).
* **Not here (carve-outs):** the ten farm-only props, `farm_*` backdrops and `field_grass` (N03, wave 5), the dress and the greenhouse (N06 / N07), the shops and festival art (I3 / I4 / I5),
  the treetop city `iso_props/city/**` and `treetop_*` backdrops (V5), the home / furniture / interior / feature props and the `floor_*` tiles (A1).

## Honest notes (plan 6.5 and what this package found)

* Tiles are periodic painted heightfield renders: the strongest painted feel of the set. **There are no terrain transition tiles**: grass-to-path-to-water edges are hard cuts of the cell lattice
  (path / deck / cobble carry 1.4 px overscan and props such as bushes and rocks hide joins); the forest's smooth path and pond are DECALS (V8's SoftGround), the tiles are their fallback.
* Props are soft CG, about 7/10: the trees and blossom crowns read as CG blobs at 1:1, Hyggebyen's blossom trees are flat, the new buildings are one mushroom-house family (cap colour, sign and
  a few attachments tell them apart; at zoom 0.4 the signs are small). Hyggebyen's layout belongs to P11 (the Pillow composite here is only a look test).
* The forest crowns are lumpy leaf spheres (the sketch draws flat concentric circles with a heavy outline); they read well at zoom 0.4 and carry the night grade exactly (floor 232b48, path 3d3e61,
  water 1d4c5c measured in a window against the sketch's 232a45 / 3b3c5e / 1c4a5a), but a close crop looks like a berry cluster.
* The forest needs the ENGINE lights, not baked darkness: shaded actors sit at 30 % brightness (the fox `e07b3c` becomes `432d1f`); at zoom 0.4 the pack outline of a shaded figure separates from
  the night floor by only about 6 / 255. V8's ForestDress (unshaded actors) is what makes the figures pop; the check `forest_ortho_readable` passes with that thin margin and says so.
* Water is a 4-frame swap (four layers, one visible), no seasonal tile sets (season is a tint), the farm sky is N03's: until it lands ArtCatalog serves P04's painted gradient + haze.
* The painted decals (rings, halos, sparks) are additive; on a bright ground an additive layer is weak (the forest is dark, so it is fine there).
* The `pond_lily` id is also used by N06's farm dress (96 x 56 pads for the farm pond): whichever manifest loads last wins the art id; rename one of them.

## Verdict (human, after looking at the contact sheets, the windowed screenshots and the real-art area renders)

accepted at 2026-10-14 for M1a stage 1 (farm + Hyggebyen + the Mørkeskoven set). Known weaknesses: the ones listed under "Honest notes", plus the pending ids of later packages (N03 farm kit and
backdrop, N06 dress, P04's dropped wall rows) which are SKIP lines with the package named in `art_environment`, never silent.

## Lift history

| File | Source | Changes |
|---|---|---|
| `bake_tiles.py` | art spike `tools/isometric/bake_tiles.py` | paths via `artpaths`, ortho mode + 7 ortho recipes, exact 96 x 56 mesh, no timing noise in tiles.json, iso output byte-identical to the spike export |
| `bake_props.py` | spike `bake_props.py` | model + painted props, `PropSpec` extras (post ramp, own shadow, outline, elevation), manifest `elev` / `proj` / `kind`, stage-aware default output |
| `props_traetoppen.py` | spike `tools/characters/props_traetoppen.py` | unchanged builders (the 55 props re-bake within 1/255 of the spike export), `PropSpec` extended, `tree_giant_crown` ss 2 as data |
| `props_farm.py` | design3 `farm/art/tools/characters/props_farm.py` | only the seven contract props + mailbox_red + warp_gate_stone |
| `compose_scenes.py`, `props_sheet.py` | spike | rewritten for the shipped asset tree and the three scenes; ortho / night compositor |
