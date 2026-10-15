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

`--only=characters|props|homes|terrain|items|world|interiors|consistency|shop-core` rebuilds a slice. `--sheet heroes players2`
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
`docs/art/world-consistency/prompts.json` and `detail-prompt.txt` in that folder
retain the exact prompts and reference roles; `asset-repair-prompt.txt` provides
a reusable correction template. The packer extracts their alpha islands and exports the city
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

`interiors.py` exports the painted modular interior kit, including four wall
materials, aligned window masks, domestic and later-tier furniture, profession
emblems and the functional shop pieces. The 34 furnishing studies cover all ten
home upgrades and the 24 town interiors. Their design, saved imagegen prompts,
scope and rebuild/capture commands are in `docs/art/interiors/design.txt`.
`interiors_gallery.tscn` previews them with native tiles and character sprites;
left/right changes room and N switches daylight/evening. These are art studies:
live door, home ownership and shop services remain their planned gameplay packages.

`equipment.py` packs the equipment design studies: three outfit directions for
the eight playable heroes, eight equipped-pose concepts, and twenty clothing,
weapon, tool and action-item shapes. It writes only `assets/art_studies/equipment/`;
the drawings are flattened concepts, not fitted animation layers or live item
catalog replacements. Review them with
`tools/dev/play.sh --throwaway tools/art/drawn/equipment_studio.tscn`.
The design, animation/ownership
contracts, exact imagegen prompts and future fit-repair prompts are saved under
`docs/art/equipment/`. Rebuild with
`tools/art/.venv/bin/python tools/art/drawn/equipment.py`.

After importing the project, audit the effective catalogs and map references:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s res://tools/art/drawn/coverage.gd -- --strict
```

The report is `docs/art/drawn/coverage.json`. It checks every installed character
clip and portrait, hero and NPC resolution, animal/enemy references, every live
item icon, all terrain IDs and every declared or mapped prop. Run it again when
the content registry changes.

The full asset consistency review is recorded in `docs/art/style-audit/` with
before/after file inventories, labeled review sheets, native captures and exact
built-in imagegen prompts. `consistency.py` packs the saved replacement paintings
for 130 furniture designs, 32 crafting materials and the remaining world props.
It also projects painted timber onto the construction frames. Run it after a
legacy geometry bake; the complete `pack.py` command runs it as the final stage.
Use `--only=consistency` to rebuild this stage without redoing the character pack.

The furniture manifest now retains 482 authored views: four per free-standing
piece and two per wall piece, plus 44 separate legendary effect overlays. All
130 IDs retain their footprint, original placement anchors and gameplay fields.
The old symmetry/mirror measurements describe the geometry generator; they do
not authorize flipping the painted grain or embroidery. Native checks enforce
the painted rotation policy and still test anchors, icon outlines, distinctness
and the unchanged 12 MB home art budget.

The painted core shop kit exports the towns `PieceCatalog` interface under
`assets/iso_props/shops/core/`: 20 pieces with 51 authored views, 15 emblem plates
and five trimmed ember masks. Run `pack.py --only=shop-core`; open
`shop_core_gallery.tscn` through `tools/dev/play.sh --throwaway` to browse the 14
core room snapshots or compare their former stand-ins. Exact prompts, masters,
budgets, native evidence and implementation handoffs are recorded in
`docs/art/shop-core/review.txt`. This is the core art delivery; the unfinished
m1b town gameplay, live festival integration and fitted wardrobe animations remain their
respective packages.

The specialist shop kit adds 69 designs with 115 authored views across 15 sets,
plus two trimmed additive accents, under `assets/iso_props/shops/special/`.
Repack with `pack.py --only=shop-special`; it also builds the optional 2–6-piece
room overlays in `data/interiors/dress/`. The generator reads saved room contract
snapshots rather than changing gameplay room geometry. Open
`shop_special_gallery.tscn` with `tools/dev/play.sh --throwaway` to browse the 15
dressed rooms, press D for the bare core room and N for evening. All generation
and repair prompts, source hashes, budgets, native evidence and pending consumer
work are in `docs/art/shop-special/review.txt` and `handoff.txt`.

`pack.py --only=festival` exports the I5 painted festival kit: 24 designs,
53 authored views, six cropped additive accents and four seasonal slot sets.
The literal `lua/config/festival_decor.lua` describes nine festivals and the
wedding without starting or scheduling an event. `PaintedFestivalArt` is a
stateless presentation example; the live director/lifecycle hookup remains
the towns/social owner's work. Exported textures carry `render_scale` so their
world dimensions stay fixed while the all-view texture budget remains bounded.
Open `festival_gallery.tscn` through `tools/dev/play.sh --throwaway` for the
day/evening art studies in both native towns (arrows season, T town, N evening,
D bare/decorated). Exact prompts, pole correction, review captures, budget
definitions and the Torvet post-layout limitation are in
`docs/art/festival/review.txt` and `handoff.txt`.

`pack.py --only=equipment-fit` exports the next equipment art step under
`assets/art_studies/equipment_fit/`: Rasmus and Pedro, four removable starter
garments, iron sword, body/hand/ear parts and explicit grips for 320 poses across
eight directions of idle/walk/run/reach. These use a common offline deformation
field, sampled from the existing actor clock in the native art consumer. Open
`equipment_fit_gallery.tscn` through `tools/dev/play.sh --throwaway` (arrows turn,
H hero, 1–4 motion, F flash, S spin, individual garment toggles). Selected and
rejected masters, generation/repair prompts, native captures, measured budgets
and the remaining complete-clip/other-body/runtime gates are documented under
`docs/art/equipment-fit/`. No production wardrobe base is enabled by this proof.
