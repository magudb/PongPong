# tools/art - the Trætoppen art pipeline

Everything that makes sprites: the procedural character generator (Python + VTK), the shared bakers and validators, the
exporter and the scripts that run it all. Owned by package **P08-art-tools**; the art packages P21 (characters), P22
(environment) and P23 (icons, key art) plug their builders into it, and the feature packages A1 (home) and A2 (wardrobe)
import it. The shipped sprites now have **warm ink contours, textured painted color and pencil accents**, baked at one scale.
The current characters, buildings and outdoor terrain use the new drawings in `drawn/`; see below.

## Current character, building and terrain art

`drawn/` packages original imagegen paintings into the game's existing sprite contracts: all 48 characters and their portraits,
21 world props (including the live scene's previously missing houses and trees), and ten home exteriors with matching night light.
Characters have expressive small eyes, soft silhouettes and hand-drawn linework. Buildings have layered roofs, worn materials,
plants, balconies and pipes. This changes the drawings themselves, beyond the texture finish described below.
All 24 outdoor terrain surfaces, the island bark sides and the bridge decks now use painted materials too.
Continuous material atlases keep grass, stones and grain flowing across tile borders.

Regenerate the shipped art with `tools/art/.venv/bin/python tools/art/drawn/pack.py`.
The source paintings, exact prompts, animation method, limits and preview command are documented in
[`drawn/README.md`](drawn/README.md). The older geometry export commands remain useful for the other art packages and source experiments.

## Illustrated finish

`storybook/illustrate.gdshader` renders the existing code-authored artwork offline in Godot. Its paper grain, broken
pencil strokes and uneven color washes repeat inside the 256 px character cells without using animation time. It leaves
every alpha pixel, atlas dimension, pivot, frame count, direction, furniture rotation and spatial manifest intact. Floors use a
gentler pass without contours or value bands. Additive lights, night layers, floating effects and contact shadows retain
their source files. UI SVGs and the runtime prop painters have matching wandering lines and painted shading.

The title illustration, five zone skies and watercolor-paper material were created with the built-in imagegen tool,
using the original drawings and the existing style guides. The paper (`storybook/watercolor_paper.png`) is read only by the
offline bake, so it lives here and is not exported with the game. Exact prompts are in `storybook/prompts.json`. The source
designs remain in `docs/original_drawings/` and `generator/`.

To finish a **pristine** asset export (use a separate checkout for source; applying the pass twice compounds the color):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-method gl_compatibility --minimized \
  -s res://tools/art/storybook/bake.gd -- --source=/absolute/path/to/pristine/assets --install
# --resume continues an interrupted bake using the same source and settings.
tools/art/.venv/bin/python tools/art/features/home/isometric/measure_mirror.py --dir assets/iso_props/furniture \
  --write tools/art/features/home/specs/mirror_ok.json --update-manifest
tools/art/.venv/bin/python tools/art/storybook/verify.py /absolute/path/to/pristine/assets assets \
  tools/art/_stage/storybook/audit.json --report=docs/art/storybook/verification.json
```

The bake requires a graphics renderer; `--headless` uses Godot's dummy renderer and cannot produce these sprites.
The finish is stored directly in the assets, so the game needs no extra material or per-frame illustration pass.
The optional mirror fallback list is remeasured after illustration: directional pencil marks can require a true view.
`docs/art/storybook/comparison.png` shows representative characters, houses, icons and portraits before and after.

`tools/art/.gdignore` hides this whole folder (and `_stage/`, `.venv/`) from Godot's importer. Nothing in here is ever a
`res://` resource.

## Quick start (repo root, bash or zsh)

```
tools/art/setup_env.sh                        # once: tools/art/.venv = Python 3.12 + numpy scipy Pillow vtk (pinned)
tools/art/core/smoke.sh                       # fox idle sheet from the GLB generator, validated and compared with the pack (~10 s)
tools/art/core/smoke.sh --full                # the P08 GATE: all 11 fox clips + GLB checks against the shipped pack (~25 s)
tools/art/core/selftest.sh                    # regression suite of the pipeline itself (sandbox project, ~4 min on a loaded machine; sections: --list)
tools/art/produce_all.sh --only=characters hobbit_pip       # build -> bake -> validate -> export -> install, one character
tools/art/produce_all.sh                      # every slice that exists
export PY="$PWD/tools/art/.venv/bin/python"   # for the single tools below
$PY tools/art/core/validate_new_assets.py --root tools/art/_stage/masters/isometric_characters hobbit_pip   # mandatory after every bake
```

* `setup_env.sh` needs a Python 3.12 with `venv` (macOS: `brew install python@3.12`; override with `TT_PYTHON312=/path`).
  It refuses interpreters that live on a `/tmp` scratch path (a venv built on one dies when the scratch is cleaned).
  The install is download-bound (the `vtk` wheel is 103 MB): about 2 minutes on a fast line, 8 minutes were measured on a
  slow one. `--check` verifies only, `--force` rebuilds. The first bake after a fresh install can be slow while macOS scans
  the new binaries (55 s measured once, 8 s every later run on a loaded machine).
* All shell entry points are **bash** scripts. macOS zsh does not word-split an unquoted `$VAR`, so never loop over ids with
  `for x in $IDS` in zsh; call these scripts as programs.
* The shell entry points find the venv themselves (`$PY` overrides it) and never write bytecode (`PYTHONDONTWRITEBYTECODE=1`); call the Python tools with `$PY`.

## Layout and ownership

| Path | Owner | What |
|---|---|---|
| `setup_env.sh`, `produce_all.sh`, `core/**`, `export/**`, `generator/**`, `.gdignore`, this README | **P08** | pipeline core |
| `tools/art/characters/**` (`traetoppen_additions.py`: builders `BUILDERS`, `EXTRA_PATTERNS`, `EXTRA_CLIPS`) | P21 | the 36 missing characters |
| `tools/art/environment/**` (`bake_tiles.py`, `bake_props.py`, props module, ortho mode, backdrops) | P22 | tiles, props, crops |
| `tools/art/icons/**` (`bake_icons.py`, `missing_icons.py`, key art) | P23 | item icons, title key art |
| `tools/art/features/home/**`, `tools/art/features/wardrobe/**` | A1, A2 | home + wardrobe art (see "Feature packages") |
| `tools/art/.venv/`, `tools/art/_stage/` | nobody | generated, gitignored |

```
tools/art/
  core/       artcontract.py (the contract as data)  artpaths.py (paths, stage, Godot-scan guard)  static_render.py
              bake_sprite_atlases.py  scene.py  validate_new_assets.py  compare_sheets.py  contact_sheet.py  cast_sheet.py
              preview.py  smoke.sh  selftest.sh  requirements.txt
  generator/  geometry.py  additions.py  build_assets.py  asset_io.py  render_assets.py  validate_assets.py   (pristine base)
  export/     export_game_assets.py (masters -> WebP)  install_assets.py (stage -> assets/<contract dirs>)  import_stubs.py
  produce_all.sh   setup_env.sh
```

Modules are found through `PYTHONPATH` (`tools/art/generator:tools/art/core`, plus `characters`, `environment`, `icons` when they
exist); `core/artpaths.py` appends them itself, **after** whatever `PYTHONPATH` already holds, so an explicit `PYTHONPATH`
always wins (the feature packages rely on that).

## The art contract (plan 6.2, verified in Godot 4.7.2 by the art spike)

One orthographic camera for everything: **36 degrees elevation, 87.074 px per metre** (vtk parallel scale 1.47 for a 256 px
cell), azimuth 45 degrees for iso art (0 for ortho tiles/walls), three lights defined in camera space (key light from the
upper left). **Sprites are never scaled individually**: every `animations.json` carries `display_scale 1.0`; zoom is the camera.

| Thing | Contract |
|---|---|
| Character cell | 256 x 256 px, ground pivot **(128, 200)**, WebP RGBA q97 method 4 |
| Sheet | one file per clip, `<clip>.webp`, **8 direction rows** in the order **S SW W NW N NE E SE** (camera azimuth 0,45,...,315), frames in columns; size = (256 x frames, 2048) |
| Outline (world sprites) | the **pack outline** warm grey-violet **(75, 60, 73) at alpha .55**, `MaxFilter(5)` on alpha. Ink `#2b2340` vanishes on the night blue `#1c2138`, so **ink is only for icons and UI** (`--outline ink`) |
| Portrait | `portrait.webp` 256 x 256, head-and-shoulders bust from a **14 degree** camera (`bake_sprite_atlases.py --bust-only`); the 12 pack busts live in `assets/portraits/<id>.webp`. A bust is cut at the torso by design, but **never at the top or the sides** (`validate_new_assets.py` checks both the character portraits and `--portraits` for the pack busts; framing: see "Bust framing") |
| `animations.json` | `character, cell_size, directions, pivot, animations{clip:{frames,fps,loop,sheet}}`; the baker adds `family, clip_set, flyer, portrait` (and `partial: true` after `--clips`), the exporter `role, clip_set, family, flyer, portrait, display_scale, glow` |
| Character id | folder name = id = **`[a-z0-9_]+`** (lower case ASCII). The 12 pack ids are protected whatever the letter case (`Fox` is `fox` on a default APFS volume) |
| Import | ONE policy for every texture under `assets/`: the `POLICY` table of `tools/import/write_import_stubs.py` (review REND-03). Clip sheets, painted wardrobe, props, furniture and buildings are VRAM-compressed **S3TC** (`compress/mode=2`, `high_quality=false`, mipmaps on), backdrops S3TC; tile atlases and packed frames lossless **without mipmaps** (R.1); portraits, icons, UI, the soft shadow and the few light kernels that band under DXT lossless. Stubs are written **before** the first `godot --import` (review R.7): the bakers and installers take them from that table (`ensure_policy()` after writing a texture, `stub_for()` for a stage tree such as `export_home.py`'s; P08's self-contained `export/import_stubs.py` keeps identical inline texts for its sandbox selftest); run `tools/import/write_import_stubs.py` after an install; its `--check` runs before every playtest and CI job |

Clips (name: frames at fps, loop):

| | |
|---|---|
| idle 4 @5 loop | walk 6 @9 loop | run 6 @12 loop | jump 4 @10 | fall 3 @6 loop | land 3 @11 |
| celebrate 6 @9 | interact 4 @9 | hit 3 @11 | sleep 4 @3 loop | talk 4 @6 loop | |
| flight (fairy, bat): takeoff 4 @10 | hover 5 @8 loop | fly 6 @12 loop | flight_land 4 @10 | | |
| Traetoppen extras: attack 5 @12 | spin 8 @14 loop | | | | |

Clip sets per role (`m.clip_set` of a builder; the exporter writes `role` and `clip_set`; `validate_new_assets.py` checks them):

| role | clip set | clips |
|---|---|---|
| player | `full` | all 11 (+ the 4 flight clips for fairies and bat) |
| npc | `npc_flyer` | idle hover talk celebrate interact |
| npc | `villager` | idle walk talk celebrate interact sleep |
| farm_animal | `farm_animal` | idle walk run interact sleep hit celebrate |
| enemy | `enemy` | idle walk run attack hit |
| boss | `boss` | idle walk attack hit spin |
| critter | `critter` | idle walk run hit sleep |

Environment and icons (produced by P22 / P23 with the same renderer, `core/static_render.py`):

| Class | Path | Contract |
|---|---|---|
| Iso tiles | `assets/iso_tiles/<terrain>.png` + `tiles.json` | tile 128 x 76 (true 36 degree diamond), atlas cell 144 x 84 with ~1.4 px overscan, **periodic 4 x 4 variants** (`atlas_coords = Vector2i(x % 4, y % 4)`); imported without mipmaps |
| Ortho tiles | `assets/iso_tiles/ortho_<terrain>.png` | tile 96 x 56, same periodic trick |
| Props | `assets/iso_props/<id>.png` + `props.json` | ground-origin `pivot` (px from the PNG top-left = tile centre), `footprint` in tiles, optional `<id>_glow.png` additive halo |
| Icons | `assets/icons/items/<item_id>.webp` | 128 x 128 RGBA **lossless**, **ink `#2b2340` 2 px outline**, no ground shadow, shown at 56-72 px |
| Key art | `assets/ui/keyart/title.webp` (+ `title_layers/`) | 1920 x 1080 |

## Pipeline, stage and install

```
generator/build_assets.py   ->  _stage/glb/<id>.glb + <id>_rig.json         (regenerated in ~1 s each; these stage GLBs are NOT committed - the old package's GLBs are archived in legacy/package_3d/assets/characters)
core/bake_sprite_atlases.py ->  _stage/masters/isometric_characters/<id>/   (lossless PNG masters + animations.json + portrait.png)
core/validate_new_assets.py     MANDATORY: sheet size, blank frames, border-opaque (alpha > 24 on the cell edge = clipped), metadata
export/export_game_assets.py->  _stage/assets/...                          (WebP q97 m4, icons lossless, role/clip_set fields, S3TC stubs)
export/install_assets.py    ->  assets/{isometric_characters/<new id>, portraits, iso_tiles, iso_props, icons/items, ui/keyart}
```

* **Staging is `tools/art/_stage/`, never `export/`** inside the project (Godot would import it) - and `.gdignore` hides it. A
  stage path that Godot would scan is refused (`artpaths.assert_not_scanned`); a path outside the project is fine. **Inside the
  project only `tools/art/_stage` (and below it) is accepted** (`artpaths.assert_stage_dir`): it is the one folder `.gitignore` lists, so
  `tools/art/_stage2` or `docs/x` (hidden from Godot, but not from git) are refused too. `$TT_ART_GLB` / `$TT_ART_MASTERS` overrides must not point into a Godot-scanned folder either.
* **install writes ONLY the six contract directories above.** It refuses (exit 2, nothing written) anything else, any
  destination that escapes them, and **the 12 pack characters** (`bat cat bear rabbit fairy monkey capybara fox raccoon penguin
  hedgehog frog`; only their busts `assets/portraits/<id>.webp` may be installed, through `--busts`). The pack guard is **case-insensitive**
  (and also compares the folders with `samefile`), and a character folder must be `[a-z0-9_]+`. A character folder is
  mirrored (stale sheets and their `.import` of that folder are removed); an existing `.import` that already carries the
  wanted preset keeps its Godot-assigned uid. `manifest_traetoppen.json` is merged, not overwritten.
* `produce_all.sh [STAGE] [--only=characters,tiles,props,icons,keyart] [--stage-only] [--busts] [--jobs=N] [ids...]` -
  see its header. A slice whose owner has not landed yet is **skipped loudly**; asking for it with `--only=` ends with exit 3.
  **Any failing step stops it** (non-zero exit, `produce_all: FAILED (exit N) at line ...`; never "done"): builder, bake, both validators, export, install,
  audit. Before a rebuild the stage's old GLB/masters/export of the same ids are deleted, so a broken builder cannot be rescued by a stale GLB.
  A function that must stop the script is never called as `fn || exit` (see the lessons).
  A package can take a slice over with an executable `tools/art/<dir>/slice_<name>.sh STAGE [ids...]` (env: `PY`, `TT_ART_STAGE`,
  `TT_ART_GLB`, `TT_ART_MASTERS`, `PYTHONPATH`; it writes lossless masters under `$TT_ART_MASTERS`, mirroring `res://assets`).
  Without a hook the spike CLIs are used: `environment/bake_tiles.py|bake_props.py --all|names --out <masters>/iso_tiles|iso_props`,
  `icons/bake_icons.py --all|names --out <masters>/icons/items`.
* The baker **rebuilds** a character's masters folder (old sheets, portrait and `animations.json` are deleted first), `--clips` names must exist
  (a typo or an empty list exits non-zero instead of writing an empty `animations.json`), and the exporter converts **only the sheets
  `animations.json` lists** (+ `portrait.png`); a listed sheet that is missing, or `--only` ids with no masters, are errors.
* Environment variables: `TT_ART_STAGE` (stage root), `TT_ART_GLB`, `TT_ART_MASTERS`, `TT_ART_PREVIEWS`, `TT_PYTHON312`, `PY`, `JOBS`.
* **Import stubs** (`export/import_stubs.py`, an inline equivalent of `tools/import/write_import_stubs.py` of P05): a minimal
  `<clip>.webp.import` with `importer="texture"`, `compress/mode=2`, `compress/high_quality=false`, `mipmaps/generate=true` next to
  every character clip sheet (not `portrait.webp`), and a lossless no-mipmap stub next to every tile atlas. Verified: Godot 4.7.2
  honours them on the very first import (only the `.s3tc.ctex` is produced, no stale lossless cache). When P05's tool exists,
  `produce_all.sh` runs its `--check` after the install.
* Parallel bakes use `xargs -P`; to wait for background jobs use `wait`. **`pgrep -f` matches its own command line** - never use
  it to test whether a bake is still running.

## Generator hooks (how P21/A1/A2 add models without editing the base)

`generator/build_assets.py` is the art spike's generator with its extension points; the base files are **pristine** - extend, do not edit:

* `traetoppen_additions.py` (any folder on `PYTHONPATH`) exposes `BUILDERS` (id -> model factory), `EXTRA_PATTERNS` (texture
  pattern -> painter) and `EXTRA_CLIPS` (clip -> motion function). A missing module means "no extra builders"; a module that
  exists but fails to import raises (it used to be swallowed).
* Model attributes read by the exporter/baker: `m.name` (rig family; `fairy bat penguin capybara` are special-cased), `m.slug` (output id),
  `m.height` (target metres), **`m.base_height`** (height of the stock model before hats and crowns: the scale is
  `m.height / m.base_height`, so **px per metre stays constant whatever you add** - never use `m.cam_scale` to fit a tall model:
  it changes px/m and forces `display_scale != 1`, which the validator rejects), `m.clip_set`, `m.extra_clips`, `m.portrait`
  (`{dy, half}` bust framing), `m.glow` (`(hex, radius_px, strength)` baked halo), `m.patterns`, `m.leg_sleeve/leg_radius/leg_color`.
* **Wardrobe patch** (addendum 4.4, 4 lines): `export(m, out, rig=None, anim_from=None)` takes `rig = rig or make_rig(m)`,
  `make_clips(anim_from or m, rig)` and `scale = m.scale_fixed` when present, so garments can share a body's rig, weights and animation.
  Default behaviour is unchanged: the pre-patch and the patched generator produce **byte-identical** `fox.glb`, `bat.glb` and rig json
  (sha256 compared, see the gate below).

## Bust framing

The bust camera (14 degrees, head and shoulders) used one fixed window, which cut wide models (bat and fairy wings, the tails of cat, fox, raccoon and monkey)
at the cell border. Framing now resolves in this order: `m.portrait = {half, dy, dx}` of the builder (explicit art direction, the validator still judges it) ->
`artcontract.BUST_FRAMING[id]` (the six pack busts, frozen) -> **`Renderer.fit_bust()`**: the default window, zoomed out and shifted sideways only as far as needed to leave
0.07 m (about 9 px) to the top and side borders, measured on a wide render. `half` = visible half-height in metres, `dy` = focus shift in rig scale units, `dx` = focus
shift to the camera's right in metres. Models that already fit keep their old framing exactly; of the art spike's 32 extra characters 8 were cut (7 fairies, the raccoon) and
none is now. The bottom edge is exempt: a bust is cut at the torso.

## Feature packages (addendum 4.4)

`tools/art/features/home` (A1) and `tools/art/features/wardrobe` (A2) **import the generator and the core through `PYTHONPATH`**
(`tools/art/features/<x>/characters:tools/art/features/<x>/isometric:tools/art/generator:tools/art/core`) and **may not edit them**:
a shared renderer or generator fix goes to the owner of this folder (P08) as a handoff. They bring their own shim modules
(`traetoppen_additions.py` with empty dicts, a vendored `props_traetoppen.py`) and put them first on `PYTHONPATH`; `artpaths` never
overrides that order. Their exporters write to their own contract paths (`assets/iso_props/home`, `assets/wardrobe`, ...), not through
`install_assets.py`, which is deliberately limited to the six directories above.

## Mandatory validators and how a look is judged

1. After **every** bake: `validate_new_assets.py` (sheet size = frames x 256 by 2048, no blank frame, no opaque pixel on the cell border,
   `animations.json` readable and consistent, at least `idle`, no sheet in the folder that it does not list, clip set of the role complete (the baker writes
   `clip_set`; a `--clips` bake is `partial`), portrait 256 x 256 and not cut at the top/sides, `display_scale == 1.0`). A broken folder is a `FAIL` line, never a traceback.
   `produce_all.sh` runs it on the masters and again on the exported WebP. For the 12 pack busts: `validate_new_assets.py --portraits DIR [ids]` (256 x 256, not
   blank, not cut at the top or the sides; `produce_all.sh --busts` runs it on the masters and on the exported WebP).
2. `core/selftest.sh` - the regression suite of the pipeline itself: one section per review defect, run in a sandbox copy of the project (never the real `assets/`),
   with injected failures; mutation-checked (reverting any single fix makes its section fail).
3. `generator/validate_assets.py` for the GLB itself (structure, skinning, loop seams; optional, ~5 s per model; `smoke.sh --full` runs it).
4. `compare_sheets.py REBUILT PACK` - the fox gate (mean error over non-transparent pixels, p99, share > 8/255, metadata equality).
5. **Contact sheets, never a single frame** (`contact_sheet.py`, `cast_sheet.py --root NEW --root assets/isometric_characters`): the new cast at
   game scale next to the pack's bat, cat, bear, rabbit, fox, fairy. Pass: figure height within +/-10 % of the pack, same outline colour and
   eye style, the face grammar of the user's sketches (two big round eyes with one dark pupil, 3 whisker strokes per cheek, tiny mouth, big round head on a small
   pear body, stubby arms, small feet).
6. Godot screenshots by the consumers (windowed, run by the lead/user) and a human verdict in the log below.

## Lessons (every one of them cost time once)

* **Python module names are ASCII only** (`traetoppen_additions`, not `træ...`): VTK/Python imports and several tools choke on non-ASCII module files.
* **Scale is height-independent**: set `m.base_height` (stock height) and `m.height`; `build_assets.export` derives the scale from the pair, so hats,
  crowns and ears do not change px per metre. Never rescale a baked sprite in the engine.
* **Reset the camera every frame** (`SetParallelScale`, position, focal point, view-up inside `frame()`): the bust camera zoom leaked into every later
  clip when it was only set once.
* **Premultiplied resize** (`static_render.premul_resize`) when supersampling: resizing straight alpha makes dark fringes around every sprite.
* VTK 9.6+: `vtkCellArray.SetCells` is deprecated, use `ImportLegacyFormat` (done in the core; pinned vtk 9.7.1).
* The machine must be quiet when timing a bake; another heavy job made the spike's first timings 2-6x too slow.
* **Never call a function that must stop the script as `fn || exit $?`**: bash switches `set -e` off for the whole body of a function that is part of an `||`/`&&`/`if` list,
  so failed bakes and validators were silently ignored and stale output got installed (found by the review; `produce_all.sh` now calls it plainly and has an ERR trap).
* **macOS volumes are case-insensitive by default**: `Fox` is `fox`. Guards against the shipped pack compare case-insensitively, ids are `[a-z0-9_]+`, and tests must not
  rely on two sibling folders that differ only in case.
* A "pass" that compared nothing is not a pass: the smoke test fails without a pack fox to compare against (`--allow-no-reference` says so loudly and `--full` refuses it).
* **zsh does not word-split unquoted variables**: loops live in bash scripts. BSD `sed -i ''`, no `flock` on macOS.
* **`pgrep -f` matches itself** (and the shell that runs it): use `wait`/`xargs -P`, not a pgrep poll.
* Long jobs: `run_in_background` (a trailing `&` inside one tool call is killed when the call ends).
* Icons are NOT downsampled world sprites (they would keep the warm world outline and the ground shadow): bake them with the icon camera and the ink outline.
* A layer or halo shader that does not multiply the inherited modulate (`vmod`) silently drops every flash, fade and night grade (A2/F5).
* Never mix new `*_base` sheets with the old pack `fox/rabbit/hedgehog` sheets in one outfit (A2).

## Gate evidence (P08, 2026-10-13, Apple Silicon, Python 3.12.11, numpy 2.5.4, scipy 1.18.1, Pillow 12.3.0, vtk 9.7.1)

* `tools/art/core/smoke.sh --full` on a clean clone of the repo: fox rebuilt end to end (generator -> GLB -> VTK bake of all 11 clips -> validator) and compared
  with the shipped pack fox: **mean error 0.58-0.61 % per clip (limit 1 %)**, `animations.json` frames/fps/loop equal for all 11 clips.
  The error is the pack's lossy WebP encoding, not drift: the rebuilt PNG master is **pixel-identical** (max difference 0) to what the original
  `pongsrc` baker produces from the original `fox.glb`, and the idle master re-encoded with this exporter (WebP q97 m4) is 0.29 % from the pack file.
* The regenerated `fox.glb` is content-identical to the shipped one (positions, UVs, joints, weights, faces, base colour and ORM textures equal; normals differ by
  2e-16 on 55 of 8821 vertices; only the PNG byte encoding inside the file differs with the Pillow version).
* The wardrobe patch changes nothing by default: `fox.glb`, `bat.glb` and `fox_rig.json` of the pre-wardrobe spike generator and of this generator have the same sha256.
* Staging never lands in a Godot-scanned folder: after `godot --headless --import` of a tree containing `tools/art/_stage` (WebP, PNG, `.import` stubs, `.venv`) no
  resource of `tools/art` was imported and no `.import` was generated there.

## Review fix round (P08, 2026-10-13) - what changed and how it is guarded

| Defect | Fix | Guard (`core/selftest.sh` section) |
|---|---|---|
| `slice_characters \|\| exit` disabled errexit: failed bake/validator/builder still exported, installed and printed "done" | plain call + `set -E` ERR trap, stale stage output of the ids deleted before a rebuild, busts validated on masters and export | `errexit` |
| zero clips valid, `--clips` typo writes an empty folder, malformed json = traceback | baker/validator exit non-zero / FAIL lines; idle required; baker writes `clip_set`/`flyer`/`partial` so masters get the role check | `clips` |
| stale sheets re-exported after a clip set shrank | baker clears its folder; exporter converts only listed sheets; validator flags unlisted sheets | `stale` |
| `Fox`/`FOX` mirrored over the pack folder on APFS | case-insensitive guard + `samefile` + `[a-z0-9_]+` in install, baker, exporter, produce_all | `ids` |
| smoke "passed" without a pack fox | reference mandatory, early failure, `--allow-no-reference` | `smoke` |
| stage `tools/art/_stage2` not gitignored | inside the project only `tools/art/_stage[/...]` | `stage` |
| pack busts unvalidated, bat/fairy/tails cut | `--portraits` validator, `BUST_FRAMING` + `fit_bust()` | `busts` |

## Quality bar and honest verdict log (plan 6.5)

The look is **soft 3D-rendered sprites in the pack's style, not hand-painted brushwork**; only the periodic ground tiles carry a painted feel.
Self-assessment of the art spike (agreed after viewing the renders): characters, NPCs, animals 8/10 (weak spots: hobbit feet at game scale, Pippin's strap reads as a
stick); icons 8/10 (brush, lantern, owl feather, hoe weaker); props, tiles, crops 7/10 (blob-texture trees look CG at 1:1; platform edge plain); Hyggebyen 6.5/10
(cramped layout, flat blossom trees); Mørkeskoven 6.5/10 (needs the engine lights; no baked darkness; the outline disappears on navy unless the pack outline is
used); title key art 6/10 (flat foliage mass). Accepted gaps: no terrain transition tiles (hard cuts hidden by props), no seasonal sets, no emissive eye layers,
one portrait expression, hovering fairies have no walk cycle, water is a 4-frame swap. The pack's four characters follow the user's own sketches; hobbit, squirrel,
NPCs and creatures are **our** designs from the guide text.

Honest notes for the characters (P21 asked to record them; P21 may refine them in `tools/art/characters/README.md`, this file belongs to P08): characters are soft CG renders in the
same family as the pack, not hand-painted; hobbit/squirrel/NPC bodies reuse the stock rig so animation is as subtle as the pack's; Pippin's satchel strap reads as a
stick; fairy NPCs have no walk clip (they hover); the boss is a single design, not a texture pass. Known core limits: wide models get a zoomed-out bust
(the bat's face is smaller than the others': its 2.8 m wingspan is in view on purpose); a builder can still art-direct with `m.portrait = {half, dy, dx}`.

| Accepted | Package | Verdict / known weaknesses |
|---|---|---|
| 2026-10-13 | P08 core | pipeline + fox gate green (above); the 12 pack characters are reproducible from source, nothing else is claimed |
| - | P21 characters | `accepted at <date>, known weaknesses ...` is written by the package after the human looks at contact sheets, cast screenshot and animation rows |
| - | P22 environment | same, incl. `ORTHO_DECISION.md` |
| - | P23 icons, key art | same |

## Lift history (what came from where)

| File | Source | Changes |
|---|---|---|
| `core/static_render.py`, `bake_sprite_atlases.py`, `scene.py`, `contact_sheet.py`, `cast_sheet.py`, `preview.py`, `validate_new_assets.py` | art spike `tools/isometric` (hooked versions: `CLIP_SETS`, attack/spin, bust portraits, `--clips`, `--outline`) | paths via `artpaths`, contract numbers via `artcontract`, VTK `ImportLegacyFormat`, repeatable `--root`, `--bust-only`, stronger validator; `scene.py` unchanged |
| `export/export_game_assets.py` | art spike `export_game_assets.py` | contract paths (icons/items, portraits, key art), S3TC stubs, `clip_set` field, `display_scale` fixed (the spike's `1.47/cam_scale` was inverted), staging guard |
| `generator/*.py` | `pongsrc/tools/characters` + spike hooks (`SA/patches/build_assets.diff`) + wardrobe patch (`features/SWD`) | `ASSETS` -> `_stage/glb`, narrower hook import, render/validate paths; no model change |
| `core/compare_sheets.py`, `smoke.sh`, `selftest.sh`, `export/install_assets.py`, `import_stubs.py`, `produce_all.sh`, `setup_env.sh`, `artcontract.py`, `artpaths.py` | new (P08) | - |
