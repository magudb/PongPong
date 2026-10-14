# tools/art/ghost - Spøgelse, the fourth playable race: the two ghost heroes Bu and Hviske (package G-ghost-art)

Current shipped art: the drawn pass in `tools/art/drawn/pack.py` replaces the
model-derived sprites described below. The old generators, review sheets and
measurements remain as prototype history. Both heroes now use painted comic
turnarounds, with identical alpha and animation and distinct blue-white/pink
cloth palettes. Use the drawn packer to rebuild the installed look; this folder
still supplies the clip, pivot, palette, hover and shared-silhouette checks.
The current in-engine previews and content audit are in `docs/art/drawn/`.

The art of the friendly ghost (user, 2026-10-14: "Ghost is a friendly playable character"): a round head on a legless bell with a scalloped hem, two stub mittens, big **dark** eyes with a white
glint, blush and the three cheek strokes of the character family, and a small wisp. Two looks like the other races: **Bu** (pale sky-blue white; the default hero, shown as "Pedro" in the game
copy) and **Hviske** (pale lilac pink, a shy glance). The generator itself (geometry, rig, bake) is the pristine base in `tools/art/generator` + `tools/art/core` (P08); this folder adds one new rig
FAMILY (`ghost`) on top of it and the tools that prove it:

| File | What |
|---|---|
| `ghost_model.py` | the whole model: `make_ghost(hero)`, `HEROES`, the palette table `HERO_PALETTE`, the cloth pattern `GHOST_PATTERNS`, the glide hooks `GHOST_CLIP_HOOKS`, `BUILDERS`. **Importable by A2** (the wardrobe bases `ghost_bu_base` / `ghost_hviske_base`): put this folder on `PYTHONPATH` AFTER your own `traetoppen_additions` and `import ghost_model`; a model of the family `ghost` animates alike whatever its slug |
| `traetoppen_additions.py` | the SHIM: the module name `tools/art/generator/build_assets.py` imports (`BUILDERS`, `EXTRA_PATTERNS`, `EXTRA_CLIPS`). The caller's `PYTHONPATH` wins (`produce_all.sh` header), so `produce_ghost.sh` puts this folder first and the generator sees exactly the two ghosts. Same pattern as V2's `tools/art/cast_v2`. Never import it; import `ghost_model` |
| `produce_ghost.sh` | `tools/art/produce_all.sh --only=characters ghost_bu ghost_hviske` with the shim first on `PYTHONPATH`: build GLB -> bake -> validate -> WebP export + S3TC stubs -> validate -> install -> audit. Refuses every other id (exit 2) |
| `check_hook.py` | proves the glide hook is ghost-only: fox, bat and fairy GLB sha256 identical in the bare generator / with P21's module / with the shim first; the ghost's GLB differs with and without the hooks (teeth) |
| `measure_ghost.py` | the cast gates (imports P21's `tools/art/characters/measure_cast.py`, which is NOT edited): height, outline, pivot x, **feet window of EVERY clip**, palette dE00, one silhouette. `--check` exits 1 on a violation, `--selftest` proves the gates have teeth |
| `palette_check.py`, `occluder_equality.py`, `bob_probe.py` | the single measurements (CIEDE2000 of the idle S frame, how identical the two silhouettes are, the vertical bob of a clip), importable and runnable |
| `probe_gates.sh` | MUTATION PROBES (about 1 min): four mutants of `ghost_model.py` (the hook leaks, the hem on the ground, a green Bu, a split silhouette) are built through the real pipeline and must each be caught by `check_hook.py` / `measure_ghost.py --check` |
| `hem_fade.py` | the REJECTED translucent hem experiment, kept as a documented non-feature (see below). Nothing calls it |
| `review_sheets.py` + `review/` | regenerates the review sheets from the installed assets and the real windowed run; `review/` is hidden from Godot by `tools/art/.gdignore` |
| `README.md` | this file: how to run, the numbers, the honest notes, the verdict log |

The art itself is `assets/isometric_characters/ghost_bu/**` and `ghost_hviske/**` (11 clips each, `portrait.webp`, `animations.json`, the S3TC `.import` stubs) plus the two rows of
`assets/isometric_characters/manifest_traetoppen.json` (merged by the installer, sanctioned edit SE-G2). The section is `tests/sections/art_ghost.gd` (18 headless checks + the windowed cast shot).

## How to run it (repo root)

```
tools/art/ghost/produce_ghost.sh                                  # both heroes: build, bake, validate, export, install (10-15 s wall on an M3, 5 parallel bakes)
tools/art/ghost/produce_ghost.sh tools/art/_stage/ghost --stage-only    # stage only: nothing is copied into assets/
PYTHONPATH=tools/art/ghost tools/art/produce_all.sh --stage-only --only=characters   # the same without the wrapper (lists and builds the two ids)
export PY="$PWD/tools/art/.venv/bin/python"
$PY tools/art/core/validate_new_assets.py --root assets/isometric_characters ghost_bu ghost_hviske   # OK, 11 clips (NOT with -I: that validator imports its sibling modules from its own folder)
$PY -I tools/art/ghost/measure_ghost.py --check                    # heights, outline, pivot, feet window of every clip, palette, one silhouette: exit 0
$PY -I tools/art/ghost/measure_ghost.py --selftest                 # the gates accept the design and flag a hem on the ground, a shifted figure, a wrong colour
$PY -I tools/art/ghost/check_hook.py                               # the hook byte-identity check (about 17 s)
tools/art/ghost/probe_gates.sh                                    # mutation probes: the gates have teeth on real bakes (about 1 min; all four mutants caught on 2026-10-14)
$PY -I tools/art/ghost/review_sheets.py --shots DIR                # rebuild review/ (DIR = the --out folder of the windowed run below)
tests/run_playtest.sh --only=art_ghost --no-boot                   # headless section (needs the project imported and tools/art/.venv)
tools/dev/run_windowed.sh --only=art_ghost --out=DIR               # windowed: the cast shot at zoom 0.4 / 0.9 / night + the measured pixel height of the ghost against the fox
```

## The ghost (what is built)

* **head** the pack's big round head, an ellipsoid (.64, .575, .45) at y 1.50.
* **eyes** the family's eye (a big oval, one dark pupil, a white glint, the group names `Eye_L` / `Eye_R` so the stock blink works) **flattened to z .055**: the stock eye bulges .098 out of the head, which reads as a dark lump on a
  white head in the W / E rows. The eyes are dark with a white glint and have **no white of the eye** (the other 12 pack figures have a white sclera): a taste decision, kept by the user's answer of 2026-10-14 (dark eyes stay).
* **cheeks and mouth** blush plus the three cheek strokes; **one** smile for both heroes (a different mouth moves the side-view silhouette by a few pixels and would split the wardrobe layers).
* **body** a surface of revolution with an elliptical section (depth .84), five scallops dropping .13, a rolled hem tube and a collar fold. No legs: no `Foot_*` group exists, so `make_rig` builds none (17 bones in all).
* **mittens** the stock `Arm_L` / `Arm_R` groups. **wisp** a tapering curl on the stock `Tail` chain, the only secondary motion a legless body has.
* **palette table** Bu sheet `E6EFFF`, collar `B9CEF2`, hem `93BBEE`; Hviske sheet `F6E7F6`, collar `E2BEE6`, hem `F29DC2`, pinker blush `F29AB2`, pupils a little down (a shy glance) INSIDE the eye, so the silhouette stays the one of Bu.
* **hover** the bell's lowest lobes are baked ~10 px above the contract pivot. The near edge of a 0.66 m skirt standing on the ground projects 22 px BELOW the pivot and fails the feet window (the first prototype: lowest pixel 222;
  a first small hover still gave 216.6 in the hit clip; the final hover passes at 214.2). The shadow of `chibi.tscn` stays on the floor; the runtime adds a +-2.5 px bob (G-ghost-play).
* **clips** the full player set: idle 4, walk 6, run 6, jump 4, fall 3, land 3, celebrate 6, interact 4, hit 3, sleep 4, talk 4 = 47 frames x 8 directions, role `player`, **no flight clips** (`flyer false`), `display_scale 1.0`,
  the pack outline (75, 60, 73) at alpha .55, **no baked glow** (a baked halo is darkened by the night grade; the glow is a light, G-ghost-play). Walk and run get the ghost-only glide hook: hips bob x3 of the stock bob, lean,
  mittens paddle, wisp sways x2.

## The numbers (measured here, this tree; the work order's budgets in the last column)

| What | Measured | Budget / gate |
|---|---|---|
| `produce_ghost.sh`, both heroes (build + bake + both validators + WebP + install + audit) | 15.5 s wall at machine load ~6 (the bake 5.5 s per hero, the two in parallel); 34 s at load 24 (the bake 12.8 s) | 13 s for build + bake on a quiet M3 |
| GLB | 7132 vertices, 13048 triangles, 17 bones | 7132 vertices |
| WebP, both heroes | 2.15 + 1.98 MB (4.1 MB); the lossless PNG masters (stage, never installed) 6.96 + 6.18 MB | 4.1 MB |
| S3TC with mipmaps, every clip resident | **32.86 MB per hero = hobbit_pip's 32.86 MB** (the size depends on the frame count only) | 32.9 MB |
| S3TC, the four warm clips idle walk run interact | **13.98 MB** (20 of the 47 frames) | the order says 12.6 MB: see "Deviations" |
| figure height (idle SE) | 160 px = **96 %** of the pack mean 167.4 px | +-10 % |
| outline | (75, 61, 73) / (76, 60, 72) = the pack's (76, 61, 71) | +-8 per channel |
| pivot x (8-row mean of the bbox centres, every frame of every clip) | 127.4 .. 127.6 | 127.5 +-3, opposed rows mirrored +-5 |
| feet line (8-row mean of the lowest pixel), EVERY clip incl. jump fall land hit interact | 206.1 .. 214.2 (single rows 204 .. 217) | upright window 197 .. 216, rows 188 .. 226 |
| palette dE00 of the idle S frame | 1.3 / 1.1 on the PNG masters, 1.6 / 1.1 on the shipped lossy WebP | <= 6 |
| one silhouette (Bu vs Hviske) | 1460 of 5 370 860 figure pixels = 0.027 %, all in rows y 70 .. 126 (the face band, the shy pupils) of the W / E rows | <= 0.05 %, none below the neck line y 130 |
| walk bob, SE (`bob_probe.py`: how far the top / the bottom of the figure moves) | ghost top 5 px / bottom 3 px (the fox 3 / 6, the hobbit 2 / 7) | a gentle glide |
| figure at game zoom 0.4 (rendered, `art_ghost.windowed_cast_shot`) | 64 px tall = 94 % of the fox's 68 px (the hobbit 67, the fairy 67) | within 10 % of the fox |
| hook byte identity | fox `f3b254a5..`, bat `015c1bf9..`, fairy `ff43bd98..` identical with and without the shim (= the design measurement) | identical |

## Honest notes (what this art is and is not)

Items marked (design4) are measurements of the design prototype that this build reproduced bit for bit (the 24 WebP sheets are byte-identical) but did not repeat.

* **Soft CG render in the pack's family, not hand-painted**, like the 12 pack characters and the 36 of P21. Next to the flat ink cards of the Figurer v2 sheet (`review/sketch_vs_baked.png`) the whole baked roster looks softer
  and rounder; the ghost no more than the others. The look of the real game at zoom 0.4 / 0.9 and at night is `review/gamezoom_check.png`.
* **The eyes are the one deliberate break of the family**: dark ovals with white glints and **no white sclera** (the pack has a white of the eye). Cuter and more ghostly in the prototype and in the real shot, a taste decision;
  the user answered 2026-10-14 that the dark eyes stay. Switching is one palette entry and a re-bake of both heroes (15 s on a quiet machine).
* **The walk is a gentle glide, not an animation**: the stock rig has no legs to move here, so walk and run are a 5 px bob of the top of the figure (the fox 3, the hobbit 2; `bob_probe.py`), a lean, paddling mittens and a swaying wisp. It reads as floating, not as walking.
* **The back rows (N, NW, NE) are an egg with a wisp**: no face is visible and the wisp reads as a tail from the side (`review/contact_sheet_ghost.png` rows W / NE).
* **Bu and Hviske are ONE silhouette on purpose** (colour, hem trim, blush and a glance only), so that the wardrobe layers of A2 can be shared: `silhouette_shared_outside_the_face_band` holds the 0.027 % and the neck line. Hviske's damage flash
  (thorn-berry pink) has less contrast than Bu's (design4).
* **The hover gap is 4 px at zoom 0.4**: visible, small. At game scale the shadow (115 px visible) is as wide as the ghost seen from the front (116 px), so the floating reads through the gap between the hem and its shadow.
* **No baked glow.** The soft light of the ghost at night is a `PointLight2D` of G-ghost-play (the night shot in `review/gamezoom_check.png` shows the plain night grade: the figures turn blue-violet but stay clearly visible, the dark
  eyes lose some contrast against the dark body).
* **The translucent hem was built, baked and compared in the real game at zoom 0.4 and 0.9 and REJECTED**: no visible difference at game scale (a 5.6 px band at zoom 0.4) and it dims the scalloped trim (design4). S3TC handled the alpha ramp
  (`fix_alpha_border` true, DXT5 keeps 8 interpolated alpha levels per 4 x 4 block), so the door stays open: `hem_fade.py` is the record, a `hem_fade` stat in the baker (P08) would be the way.
* **Wardrobe**: the garment layers are A2's. Pants and shoes are worn and counted but not drawn on a legless body (`hidden_slots`); the heroes' palette table in `ghost_model.HERO_PALETTE` is what A2's `hero_designs.py` reads.

## Deviations from the work order, and why (all measured in this tree)

* **Warm clips 12.6 MB**: the order names the four clips idle walk run interact and 12.6 MB. Those clips are 20 of the 47 frames and weigh **13.98 MB** (the S3TC size of a sheet depends only on its pixel count: 1 byte per pixel x 4/3 for the
  mip chain; 12.6 MB would be 18 frames). The check holds the arithmetic of the named clips (<= 14.0 MB); the 32.9 MB total of the order is met (32.86 MB).
* **Shadow "118 px wider than the ghost"**: the visible ellipse of `shadow.png` is 115 px (the texture is 144 px wide with padding); the ghost seen from the front (bell and mittens) is 116 px, the widest idle row 137 px (the wisp from the side).
  The shadow is as wide as the ghost from the front, not wider; the check (`hover_baked_feet_window`) holds that they agree within 10 px.
* **`validate_new_assets.py` with `-I`**: the order's acceptance line runs it as `python -I ...`; in isolated mode Python does not put the script's own folder on `sys.path`, so the validator cannot import its sibling module `artpaths`
  (`ModuleNotFoundError`). It is P08's file and is not edited here: it is run without `-I` (what `produce_all.sh` does, with `PYTHONPATH` set). The other tools of this folder add their paths themselves and run with `-I`.
* **The windowed cast shot** is regenerated through the real world scene (`scenes/main/world.tscn`, a registered fixture map, the day / night grade of the area) instead of the prototype's standalone driver, and the pixel heights are measured
  on a flat-colour fixture ground like P21's `cast_matches_pack`; the rows face SE, SW and S (the prototype had SE and SW).

## Codex guardrail (strictly additive)

Another agent (Codex) restyles the existing assets (the "storybook finish" on main, a hand-drawn pass over every character sheet and house in other worktrees). This package therefore only CREATED files: the two new character folders
`assets/isometric_characters/ghost_bu/**` and `ghost_hviske/**`, this tool folder and the section. The only pre-existing file it touched is `assets/isometric_characters/manifest_traetoppen.json`, by the installer's merge (two rows
added, the 36 other rows and the header unchanged: sanctioned edit SE-G2). `tools/art/storybook/*` and `tools/art/drawn/*` were never run and `produce_all.sh` was never run for an id that exists. The sheets are baked **pristine** in the
current look (no extra painterly effect): the finish pass is applied to them later, in a separate checkout.

## Gates and where each is proven

Every sheet named here is in `review/` (regenerate with `review_sheets.py`); the check `art_ghost.review_sheets_exist_and_readme_names_them` fails when a sheet named in this README is missing, unreadable, larger than 900 KB or when
`review/` holds a PNG this README does not mention.

| Gate | Proof (check) | Sheet to LOOK at |
|---|---|---|
| validators green, 11 clips, S3TC stubs | `produce_ghost.sh` exit 0, `art_ghost.sheets_valid`, `import_stubs_s3tc` | - |
| the hook leaves every other character byte-identical | `check_hook.py`, `art_ghost.hook_leaves_other_characters_byte_identical` | - |
| contact sheet next to the pack: height +-10 %, outline, pivot, feet window | `measure_ghost.py --check`, `art_ghost.heights_and_pivot`, `hover_baked_feet_window` | `review/contact_sheet_ghost.png` (8 directions x 2 heroes, walk / run frames, 8 other clips, the two busts) |
| palette and one silhouette | `art_ghost.palette_within_de`, `silhouette_shared_outside_the_face_band` | `review/contact_sheet_ghost.png` |
| windowed cast shot at zoom 0.4, 0.9 and night, the pixel height against the fox | `art_ghost.windowed_cast_shot` (windowed) | `review/gamezoom_check.png` (the real screenshots, the zoom 0.4 crops magnified x2 with nearest neighbour) |
| the roster next to the Figurer v2 sketches | looked at | `review/sketch_vs_baked.png` (the sketch cards of Rasmus, Bertil, Kløvermynte, our sketch of Bu in the sheet's rules, and the baked fox, hobbit_pip, fairy, ghost_bu, ghost_hviske) |
| portrait legible, a bust, not cut | `art_ghost.portraits_are_busts` | `review/contact_sheet_ghost.png` (the two busts) |
| VRAM = the hobbit's | `art_ghost.vram_budget` | - |

## Verdict log

| Date | Who | Verdict |
|---|---|---|
| 2026-10-14 | builder (G-ghost-art) | rebuilt through the real pipeline: all 24 WebP sheets and both `animations.json` are byte-identical to the design prototype; every gate run, every sheet and the windowed cast shot looked at (the ghost reads as a friendly white / pink figure with two big dark eyes next to the fox, hobbit and fairy at zoom 0.4, 0.9 and at night); the contact sheet, the zoom check and the sketch comparison are in `review/` |
| - | Accepted at: pending the human look at the contact sheet, the zoom check and the sketch comparison (and the taste decision of the dark eyes, already answered by the user) | known weaknesses: the notes above (CG not hand-painted, the glide, the egg + wisp back rows, one silhouette so Hviske is a colour variant, the 4 px hover gap, no baked glow until G-ghost-play) |

## Lift history

| File | Source | Changes |
|---|---|---|
| `ghost_model.py` | design4 `proto/builder/traetoppen_additions.py` (the prototype builder, five visual iterations v1-v5) | split into the model module (this file) and the shim; `hero_palette` / `HERO_PALETTE`, `is_ghost`, `GHOST_IDS`, argument checks; the geometry numbers are unchanged (the rebuilt sheets are byte-identical to the prototype's) |
| `traetoppen_additions.py` | the same file | the 3-line shim |
| `measure_ghost.py` | design4 `scripts/measure_fig.py` + the cast gates of `tools/art/characters/measure_cast.py` | one tool with `--check` / `--selftest`; the feet window of EVERY clip (measure_cast exempts jump / fall / land) |
| `palette_check.py`, `occluder_equality.py`, `bob_probe.py` | design4 `scripts/` | importable (`palette_de`, `silhouette_diff`, `bob`) and the neck-line rule |
| `hem_fade.py` | design4 `scripts/hem_fade.py` | the docstring records the rejection |
| `review_sheets.py` | design4 `scripts/contact_ghosts.py` + `compose_checks.py` | repo-relative paths, the real section's shots, English labels, Hviske in the sketch comparison |
| `check_hook.py` | design4 `notes/glide_hook_is_ghost_only.txt` (a manual sha256 comparison) | a tool with three configurations and a teeth check |
