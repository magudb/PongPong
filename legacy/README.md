# legacy/ - archive of the original full package

This folder keeps every part of the original full source package (the old 3D game plus the 3D character
models, delivered as `PongPong/` in Downloads) that the 2D rewrite does not use, so that **PongPong is the
only project**. Godot ignores this folder completely (`legacy/.gdignore`), nothing in the game depends on it,
and everything is also in git history. It is safe to delete.

| Folder | What it holds |
|---|---|
| `package_3d/` | The 3D character models (`assets/characters`: GLB, base-colour/ORM textures, rig and UV json), their 3D scenes and scripts (`scenes/characters`, `scenes/player/skins`, `scenes/npc/skins`, `scenes/farm/animals`, `scripts/characters`), the original 2D demo scenes and scripts (`scenes/isometric`, `scripts/isometric`), the original build tools (`tools/characters`, `tools/isometric`), the package's own character checks (`tests/`) and the package versions of files that the rewrite replaced (`README.md`, `localization/`, the 3D player/world/forest scenes, ...). Original relative paths are kept. `project.godot.original` is the package's project file, renamed so that this archive holds no second Godot project. |
| `package_masters/` | The lossless **PNG sheets** of the 12 pack characters with their `animations.json` / `manifest.json`. The game uses lossy WebP re-encodes of the same sheets in `assets/isometric_characters/` (mean difference about 2/255 per pixel); `tools/art` can rebuild them from code. |
| `MANIFEST.json` | Every one of the package's 475 files with its size, sha1 and where it lives now: class A = same content already in the repo, B = same content in git history, D = archived here or in `docs/`, S = empty placeholder file. |

The package's documents went to `docs/`: your four original drawings (`docs/original_drawings/`), the character
preview images (`docs/character_previews/`), `docs/ISOMETRIC_2D_README.md` and `docs/character_asset_validation.json`.
