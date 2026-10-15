# Drawn characters and painted buildings

The character reference calls for small dark eyes, expressive mouths, blush,
loose grey contours and soft irregular silhouettes. The architecture reference
calls for layered roofs, worn materials, balconies, pipes, plants and warm
windows. This replaces the model-derived character drawings and the live world's
placeholder houses and trees, rather than adding another texture finish.

The original paintings are in `sources/`. They were generated with
the built-in imagegen tool using the user's two references. The exact prompt set
and reference roles are in [prompts.json](prompts.json). No API key is needed to
rebuild the installed sprites from these saved paintings.

From the project root:

```sh
tools/art/.venv/bin/python tools/art/drawn/pack.py
tools/art/.venv/bin/python tools/art/drawn/optimize_environment.py
tools/art/.venv/bin/python tools/import/write_import_stubs.py
tools/art/.venv/bin/python tools/import/write_import_stubs.py --check
tests/run_playtest.sh --strict --character=animal
tests/run_playtest.sh --strict --character=fairy
tests/run_playtest.sh --strict --character=hobbit
```

`--only=characters|props|homes|terrain|items|world` rebuilds a slice. `--sheet heroes players2`
restricts the character sources; `--character <ids...>` restricts individual IDs.
`--portraits-only --only=characters` updates
portraits without rebuilding animation sheets. Run one Godot instance at a time.

The 58 characters keep their original clip sets, frame counts, timing, role and
256 px cells with the ground pivot at (128, 200). Five authored views supply
eight directions: front, front-left, left, rear-left and a separate full rear
view, with three opposite-side views mirrored. Continuous offline 2D puppet
deformation supplies steps, breathing, gestures, squashes and reactions. The boss
spin turns through the directional drawings. These are puppet animations, not
individually illustrated frames. There is no additional runtime material.

The 21 world props are resolved through `assets/iso_props/drawn/props.json`.
Collision and depth sorting still come from the Lua prop definitions. Buildings
use measured wall-plane junctions from `building_planes.json`. The packer reads
the 128 by 76 tile geometry from `Iso`, projects each facade onto those tile
axes, and computes the sprite pivot from its actual footprint. Verticals stay
upright, and roof edges, balconies and foundations share the ground perspective.
Soft contact shadows and soil shading are separate `ground` textures, drawn
below every character and tracked with the building when hidden or removed.
The `world-footprints.png` review image overlays the real tile grid and foundation
edges; the overlay is only part of the capture tool.

The 25 outdoor and four interior terrain atlases replace the runtime surfaces in both
isometric and orthographic areas. `terrain.py` cuts the twelve painted materials
from `sources/terrain.png`, removes their edge lighting mismatch with a periodic
Poisson solve, and projects each continuous material across the complete 4 by 4
tile period. Grass blades, stones and wood grain continue through tile borders.
Water retains four animation frames and a 2 by 2 period; watered soil stays
darker than dry soil. Atlas dimensions, collision, and terrain IDs stay in the
existing contract. `interior_terrain.png` supplies stone, plank, parquet and marble;
the separate field material keeps the farm's lighter untilled furrows.
Tiles use lossless WebP exports and lossless imports without mipmaps, with the existing
1.4 px overscan to prevent hairline seams at low zoom.

The same source supplies three painted bark sidewalls and two timber bridge
decks, installed separately in `assets/iso_props/drawn_terrain/`. Their original
pivots and dimensions keep the platform rim aligned with the terrain. The source
was generated using the built-in imagegen tool; its exact prompt is in
`terrain-prompt.txt`.

Buildings have additive window masks derived from the new paintings. Sliced building
masks use the complete image origin, so their light stays on the windows. All ten home tiers
retain their door anchors, dimensions, footprints and depth sorting; their
paintings are projected onto the existing isometric ground plane. The thin stone
foundation uses the game's floor material. Night masks are rebuilt from the new
windows, trimmed, and placed by the updated offsets. Home exterior WebPs use
quality 90 to stay inside the existing 12 MB home art budget. Original character
sheets use quality 97; the additional cast uses quality 90 with method 6 to keep
the existing cast disk budget. All use the existing S3TC import presets.

The 12 original pack characters keep distinct full-body thumbnails and dialogue
busts. The other 46 keep their bust in the character folder, preserving the
portrait lookup order.

The native-engine review script is:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method gl_compatibility --minimized \
  -s res://tools/art/drawn/capture.gd
```

It saves dawn, daylight close view, tile alignment, night, full cast, building
and terrain previews plus four pages of every registered item in `docs/art/drawn/`.
It starts a review game in memory and does not write a save. The previous
`storybook/` shader and geometry generators remain available for the other
assets and for source experiments; use this packer to restore the shipped look
after a geometry export.

The coverage additions use the built-in imagegen tool. Their exact prompts are
in `coverage-prompts.json`, `trinkets-prompt.json`, `extra-backs-prompt.txt`,
`revised-prompts.json` and `interior-terrain-prompt.txt`; all paintings are in
`sources/`. `item_recipes.json` and `items.py` map the 183 additional pictures to
the registered tools, resources, food, seeds, animals and wardrobe items.
Birk and Bodil have their own canonical hero drawings. Bu and Hviske share the
same alpha and animation; the pink cloth is a palette variant.

`optimize_environment.py` exports the retained full-colour masters in
`sources/environment_masters/`. Painted sky PNGs use 128 colours and the native
1920 by 1080 crop and the farm's S3TC/mipmap background preset; the large crown
uses 256 colours with its alpha unchanged.
Legacy terrain masters are exported as lossless WebP with identical visible
RGBA and no mipmaps. `environment-export.json` records dimensions, colour error,
alpha comparisons and the combined 22 MB environment budget.

The treetop city and Mørkeskoven use the same painted source family through
`world.py` (`pack.py --only=world`). `city_painted.png`,
`city_details_painted.png` and `forest_painted.png` are saved imagegen masters;
`world-prompts.json` and `world-detail-prompt.txt` retain the exact prompts and
reference roles. The packer extracts their alpha islands and exports the city
huts, furniture, lanterns, lift, woodland crowns, cave stones and runestones to
`assets/iso_props/painted_world/`. Timber decks and bark use the same painted
material sheet as the approved tiles. City canopy leaves come from the forest
master and hanging bats from the existing drawn character master.
The distant city trees reuse the approved nature painting. Rope rails take their
warm timber colour from the city art settings; other level builders retain their
own defaults. Forest glow patches keep the painted leaf litter, with mushrooms
and radial lights supplying the glow instead of bright square tiles.

The effective pack overrides the original generator exports. Canvas dimensions,
floor pivots, level ranks and collision data stay in their existing contracts.
Hut night masks are derived from the new amber windows; CityData reads their
effective pivots and offsets from ArtCatalog so old window positions cannot leak
through a painted hut. `art_world_style` verifies the effective resources and
their source paintings, rather than only checking that an old asset exists.
The effective city textures, sky and distant trees use 69.4 MB of RGBA8 upload
space including imported mipmaps, within the existing 70 MB contract. The
magnified far backdrop keeps the original backdrop's no-mipmap import preset.

Native engine comparisons use the same camera poses for the original and new pack:

```sh
GODOT_EXTRA_ARGS=--minimized tools/dev/run_windowed.sh --strict --no-boot \
  --sections-dir=res://tests/art_review --only=world_views --out=/tmp/world-views
```

The five captures show the city overview, close view and night, plus the forest
overview and cave clearing. Inspect them together with the character/tile sheets.

After importing the project, audit the effective catalogs and map references:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s res://tools/art/drawn/coverage.gd -- --strict
```

The report is `docs/art/drawn/coverage.json`. It checks every installed character
clip and portrait, hero and NPC resolution, animal/enemy references, every live
item icon, all terrain IDs and every declared or mapped prop. Run it again when
the content registry changes.
