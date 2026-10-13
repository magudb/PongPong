# PongPong — Isometric 2D characters (Godot 4.7 demo)

Open `project.godot`, press F5, and explore all **twelve** characters.

**Controls:** WASD/arrows to move, Shift to run, Space to jump, Tab to swap characters, C to celebrate, E to interact. Bat and fairy can also press F to toggle flying (Space = rise, Ctrl = descend).

All atlases have 8 rendered directions and animation frames in columns. This optimized project uses **WebP RGBA** sprite sheets at quality 97 to reduce download size. Godot 4 supports importing WebP as 2D textures. The separate PNG pack contains lossless master atlases.

Read `docs/ISOMETRIC_2D_README.md` for complete integration instructions and important scope limitations. The full 3D game systems are **not** converted in this demo. Godot could not be executed inside this build environment; this project must be smoke-tested in the editor before release.
