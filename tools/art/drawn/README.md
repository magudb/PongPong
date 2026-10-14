# Drawn characters and painted buildings

The character reference calls for small dark eyes, expressive mouths, blush,
loose grey contours and soft irregular silhouettes. The architecture reference
calls for layered roofs, worn materials, balconies, pipes, plants and warm
windows. This replaces the model-derived character drawings and the live world's
placeholder houses and trees, rather than adding another texture finish.

The original transparent paintings are in `sources/`. They were generated with
the built-in imagegen tool using the user's two references. The exact prompt set
and reference roles are in [prompts.json](prompts.json). No API key is needed to
rebuild the installed sprites from these committed paintings.

From the project root:

```sh
tools/art/.venv/bin/python tools/art/drawn/pack.py
tools/art/.venv/bin/python tools/import/write_import_stubs.py --check
tests/run_playtest.sh --strict --character=animal
tests/run_playtest.sh --strict --character=fairy
tests/run_playtest.sh --strict --character=hobbit
```

`--only=characters|props|homes` rebuilds a slice. `--sheet heroes players2`
restricts the character sources. `--portraits-only --only=characters` updates
portraits without rebuilding animation sheets. Run one Godot instance at a time.

The 48 characters keep their original clip sets, frame counts, timing, role and
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

Buildings have additive window masks derived from the new paintings. Sliced building
masks use the complete image origin, so their light stays on the windows. All ten home tiers
retain their door anchors, dimensions, footprints and depth sorting; their
paintings are projected onto the existing isometric ground plane. The thin stone
foundation uses the game's floor material. Night masks are rebuilt from the new
windows, trimmed, and placed by the updated offsets. Home exterior WebPs use
quality 90 to stay inside the existing 12 MB home art budget; character sheets
remain quality 97 and use the existing S3TC import presets.

The 12 original pack characters keep distinct full-body thumbnails and dialogue
busts. The other 36 keep their bust in the character folder, preserving the
portrait lookup order.

The native-engine review script is:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method gl_compatibility --minimized \
  -s res://tools/art/drawn/capture.gd
```

It saves dawn, daylight close view, tile alignment, night, full cast and building
previews in `docs/art/drawn/`.
It starts a review game in memory and does not write a save. The previous
`storybook/` shader and geometry generators remain available for the other
assets and for source experiments; use this packer to restore the shipped look
after a geometry export.
