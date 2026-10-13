# legacy/ - archive of the original full package

This folder keeps every part of the original full source package (the old 3D game plus the 3D character
models, delivered as `PongPong/` in Downloads) that the 2D rewrite does not use, so that **PongPong is the
only project**. Godot ignores this folder completely (`legacy/.gdignore`), nothing in the game depends on it, and
everything in it is committed to git. It is safe to delete from the working tree (the blobs stay in git history, so
deleting it does not shrink `.git`).

| Folder | What it holds |
|---|---|
| `package_3d/` | The 3D character models (`assets/characters`: GLB, base-colour/ORM textures, rig and UV json), their 3D scenes and scripts (`scenes/characters`, `scenes/player/skins`, `scenes/npc/skins`, `scenes/farm/animals`, `scripts/characters`), the 12 per-character 2D scenes (`scenes/isometric/characters`) and the package's version of `iso_chibi_sprite_2d.gd`, the original build tools (`tools/characters`, `tools/isometric`), the package's own character checks (`tests/`) and the package versions of files that the rewrite replaced (`README.md`, `localization/`, the 3D player/world/forest scenes, ...). Original relative paths are kept. `project.godot.original` is the package's project file, renamed so that this archive holds no second Godot project. The original 2D *demo* scenes and scripts of the character package (`demo_isometric_2d.tscn`, ...) are not here: they were already in git history (commit `7801e65`, under `docs/PongPong_Isometric2D/`). |
| `package_masters/` | The lossless **PNG sheets** of the 12 pack characters with their `animations.json` / `manifest.json`. The game uses lossy WebP re-encodes of the same sheets in `assets/isometric_characters/`: premultiplied mean difference about 0.2/255 over a whole sheet (about 1.2/255 over the non-transparent pixels; worst single clip 1.8/255, worst single channel value 74/255). `tools/art` re-bakes the animation sheets from code (not byte-identical, mean about 0.1/255) but does not reproduce the `portrait.png` masters, so keep these if you need the originals. |
| `MANIFEST.json` | Every one of the package's 475 files with its size, sha1 (the git blob id: `git cat-file -p <sha>` prints the content of class A/B files that are in the object database) and where it lives now: class A = same content already in the repo, B = same content in git history, D = archived here or in `docs/`, S = empty placeholder file. |

The package's documents went to `docs/`: your four original drawings (`docs/original_drawings/`), the character
preview images (`docs/character_previews/`), `docs/ISOMETRIC_2D_README.md` (the package's original README: historical,
its paths such as `scenes/isometric/demo_isometric_2d.tscn` do not exist in this project) and
`docs/character_asset_validation.json` (the 3D GLB report of the package).
