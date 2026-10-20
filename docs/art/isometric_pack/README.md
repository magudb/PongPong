> **Integration status (Trætoppen, package P05-characters-pack).** This file is the pack author's original README, kept as
> the art reference. It was moved here from `docs/PongPong_Isometric2D/`; that standalone demo project is gone.
>
> * **The pack runs in Godot.** The statement below that "Godot could not be executed" / "no live Godot import/run test" is
>   **obsolete**: the 12 characters were imported and animated in Godot 4.7.2 (headless import + windowed run, zero errors) and are
>   exercised by `tests/sections/characters.gd` and `tests/perf_world.tscn` (a windowed `-- --cast` line-up).
> * The sheets now live in the game at `res://assets/isometric_characters/<id>/` (same files, byte-identical, S3TC import stubs
>   written by `tools/import/write_import_stubs.py`). The previews are in `isometric_previews/` next to this file.
> * Deleted with the demo project (replaced, see `docs/design/PLAN_2D.md` section 6.1): `project.godot`, `isometric_demo.gd`,
>   `isometric_ground_2d.gd`, `IsoPlayerController2D`, `IsoWanderer2D`, the demo / `player_2d` / `npc_2d` scenes, the 12
>   per-character scenes and `tests/validate_isometric.py`. Controls, scene names and `Visual.scale 0.6` below describe that demo only.
> * Runtime entry point is now `IsoChibiSprite2D.create("<id>")` (`scripts/isometric/iso_chibi_sprite_2d.gd`, one generic
>   `scenes/isometric/chibi.tscn`); which sprite a skin, NPC or animal uses is data in `lua/config/characters.lua`.
> * Sprites are never scaled individually in the game (the camera zooms); the demo's 0.6 scale is not used.

# PongPong — Isometric 2D characters (Godot 4.7 demo)

Open `project.godot`, press F5, and explore all **twelve** characters.

**Controls:** WASD/arrows to move, Shift to run, Space to jump, Tab to swap characters, C to celebrate, E to interact. Bat and fairy can also press F to toggle flying (Space = rise, Shift = descend; LT on a controller).

All atlases have 8 rendered directions and animation frames in columns. This optimized project uses **WebP RGBA** sprite sheets at quality 97 to reduce download size. Godot 4 supports importing WebP as 2D textures. The separate PNG pack contains lossless master atlases.

Read `docs/ISOMETRIC_2D_README.md` for complete integration instructions and important scope limitations. The full 3D game systems are **not** converted in this demo. Godot could not be executed inside this build environment; this project must be smoke-tested in the editor before release.
