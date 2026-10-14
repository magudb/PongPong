# tools/art/cast_v2 - the Figurer v2 cast (package V2-cast-art)

Current shipped sprites are the painted comic turnarounds packaged by
`tools/art/drawn/pack.py`, including the two restyles. The geometry generators
and review images below remain as prototype history and measurement tools.
Rebuild the shipped look with the drawn packer. See `docs/art/drawn/` for the
current full cast, world captures, item pages and coverage audit.

Six new NPC bodies and palettes and two restyles, built from the **Figurer v2** sheet of the Style Guide review
(`docs/Trætoppen Style Guide Review/Trætoppen Figurer v2.dc.html`, render in `refs/figurer_v2_render.png`) and baked through the existing art pipeline
(generator -> VTK baker -> validators -> exporter -> installer).  Binding design: `docs/design/DUNGEON_V2_ADDENDUM.md` section 7 (7.1 heroes, 7.2 the cast).

| id | figure of the sheet | built from | clip set | state |
|---|---|---|---|---|
| `bear_brumme` | Brumme, tømrer | stock bear, palette b98657 / d3a77a / e9d2b0, a tool belt sized to the bear's waist (pouches, hammer, pencil), toe pads | villager | NEW, installed |
| `bat_natteblik` | Natteblik, kortsælger | stock bat, body 8c7aa8, membrane 6b5b8a, belly a896c4, lilac ear lining c9a7d6, brown eyes 4a2416, ears 30 % bigger | npc_flyer | NEW, installed |
| `hedgehog_pip` | Pip, postbud | stock hedgehog, spines 7a4e2d, face f0dcc0, belly ring 8a5a32, feet 5e3b20, Pippin's satchel + strap (mirrored), white letter with a red seal | villager | NEW, installed |
| `owl_fru_ugle` | Fru Ugle, vurderer | `make_owl` of P21 (chevrons and discs exist), body a07a55, wings 7a5a3a, gold eye rings f2c14e with a big black pupil, beak e8b04a | villager (she talks) | NEW, installed |
| `capybara_sofus` | Sofus, badehus | **the one new body**: an upright capsule on `add.body`'s rig, dark muzzle patch / hands / feet a8714a, cream belly, two small ears, an orange with a leaf on the head | villager | NEW, installed |
| `fairy_birk_npc` | Birk, bigartner | stock fairy rig with a male head: short fringe c98a3a, green leaf cap 6b9a3e with a sprout, green irises 3f8f6a, tunic 6b9a3e, belt and boots 5e3b20 | npc_flyer | NEW, installed |
| `fairy_shopkeeper` | Kløvermynte (butiksfe) | RESTYLE in place: lavender hood-bob 9b86d6, coronet of gold / white beads, wings cfe6f2, dress e88f9f, violet irises 5d4fa3, the pouch stays | npc_flyer | baked in the stage, **installed on request** (see "Install order") |
| `cat_morfar_mis` | Morfar Mis | RESTYLE in place: body a7adb9, green irises c9d97a, tabby stripes 7d8494 on arms, legs and tail; sardine and old-man brows stay | villager | baked in the stage, **installed on request** |

Hoppe has no new art by design: he is the pack `rabbit` (palette dE00 1.4). Rasmus, Bertil, Bodil, Kiki and the hero versions of Kløvermynte and Birk are the
hero bases of package A2 (`tools/art/features/wardrobe`), not baked here; `palettes_v2.json` carries their sketch hex for the twins (see "Palette table").

## Commands

```
tools/art/cast_v2/produce_cast_v2.sh [--list] [--stage-only] [--install-restyles] [--jobs=N] [--stage=DIR] [--clean]
tools/art/.venv/bin/python tools/art/cast_v2/measure_cast_v2.py [--check] [--root DIR] [ids]           # height, outline, pivot of the eight (imports P21's measure_cast.py)
tools/art/.venv/bin/python tools/art/cast_v2/measure_cast_v2.py palette [--check] [--regions] [...]    # the palette gate (CIEDE2000)
tools/art/.venv/bin/python tools/art/cast_v2/measure_cast_v2.py busts [--check]                         # the busts: 256 x 256, edges clear, guide ink outline
tools/art/.venv/bin/python tools/art/cast_v2/review_v2.py [--ab] [--shots DIR]                          # the review sheets
tools/art/.venv/bin/python -I tools/art/cast_v2/check_shim.py                                           # the shim checks of the section
tests/run_playtest.sh --only=art_cast_v2,art_characters --no-boot                                       # headless gate (needs the project imported)
tools/dev/run_windowed.sh --only=art_cast_v2 --out=DIR                                                  # the cast next to the pack at Camera zoom 0.4 (a window, ~6 s)
```

`produce_cast_v2.sh` sets `PYTHONPATH=tools/art/cast_v2` **first** and calls `tools/art/produce_all.sh --only=characters --stage-only <the 8 ids>`; the shim
`traetoppen_additions.py` of this folder is a module of the SAME NAME as the generator's hook (`build_assets.py`: `from traetoppen_additions import BUILDERS,
EXTRA_PATTERNS, EXTRA_CLIPS`; the caller's PYTHONPATH wins, `produce_all.sh` header).  It loads P21's `tools/art/characters/traetoppen_additions.py` from its file under
another name, re-exports a COPY of its builder table, adds the six builders and replaces the entries of the two restyled ids in the copy only.  No P08 or P21 file is
edited (`check_shim.py`: sha256 before and after, the exported table not mutated).  The bake of the eight ids takes about 30 s wall (5 jobs); the six folders are 6.4 MB on disk.

What the script does after `produce_all.sh`: the busts are baked AGAIN with the existing `bake_sprite_atlases.py --outline ink` switch (guide ink #2b2340, `artcontract.INK`:
"ink is for icons and UI") and swapped into the masters and the exported tree (`portrait.webp`, same encoder); the exported tree is validated once more; the six new folders are
installed with `install_assets.py --classes characters --only <ids>`, which MERGES their rows into `assets/isometric_characters/manifest_traetoppen.json` (rows of other
packages, e.g. the ghost heroes of G-ghost-art, are never rewritten); `tools/import/write_import_stubs.py --check` audits the result.  The world sheets keep the pack outline
(75, 60, 73) at alpha .55.

## Install order (the two restyles are held back)

`fairy_shopkeeper` and `cat_morfar_mis` already exist in `assets/isometric_characters/` (P21).  The user's instruction for this milestone is that the existing assets are not
touched while Codex restyles them ("hand-drawn sprites" pass, branch `art/hand-drawn-sprites`, and the "illustrated storybook finish" already on main), so this package bakes
both into the stage on every run (`produce_cast_v2.sh` prints them) but installs only the six NEW folders.  The restyles are fully built, validated and measured (below);
to put them in, after Codex's state is known and the lead has decided:

```
tools/art/cast_v2/produce_cast_v2.sh --install-restyles        # ~30 s; replaces the two folders (sheets, portrait, animations.json), manifest rows are re-merged
godot --headless --path . --import   (twice)                   # then pull the .import files of the two folders into the repo
```

Codex's finish pass needs a pristine export: the six new folders are baked in the current look without any painterly effect, so the pass can be applied to them later.
`art_characters` (P21's section, carved out to this package) passes both with the old and with the restyled folders installed (measured in a clone, see the report).

## Palette table

`palettes_v2.json` holds the sketch hex of all 13 figures (design section 3.4), the ONE source the builders read.  A2's `hero_designs.py` carries the same hex for the six
heroes; the two files import nothing from each other and V10's `zz_v2.cast_palettes_match_hero_palettes` asserts equality (format: `figures.<figure>.<region> = "rrggbb"` or a
list of two).  Deviations from the table, all in the sketch's direction: Sofus's hands are a8714a like the design table says (the SVG paints them d99a64; the reference
photos in `uploads/` have dark paws); Morfar Mis's body, belly and ear lining move onto the sketch hex a7adb9 / e7e3ea / f2b8c6 (P21's A9A6B8 was dE00 5.9 from the sketch on the
palette and 6.5 - 7.3 on the screen: the gate of 6 would have failed on the screen).

## Gates and measured numbers (stage and installed sheets, Apple M3)

| gate | measured |
|---|---|
| height, idle SE bounding box, pack mean 167.4 px (bear 170, cat 168, rabbit 167, fox 169, fairy 163), +/-10 % | Brumme 170 (102 %), Natteblik 159 (95 %), Pip 164 (98 %), Fru Ugle 178 (106 %), Sofus 162 (97 %), Birk 163 (97 %), Kløvermynte 161 (96 %), Mis 168 (100 %); rendered at Camera zoom 0.4 on 1280 x 720: pack 67 px, cast 95 - 106 % |
| outline of the world sheets | (76, 60, 72) = the pack's (75, 60, 73) at alpha .55, all eight |
| pivot (128, 200), every frame of every clip, 8 rows mirrored | x 127.4 .. 127.6; feet line 200.6 .. 210.6 (upright window 197 .. 216; the bat uses the flyer window) |
| busts | 256 x 256, top / left / right clear, guide ink outline (44, 35, 64) on all eight |
| palette, single-region figures, dominant region of the idle-S frame against the sketch fill (dE00 <= 6) | Brumme 4.1, Fru Ugle 3.3, Sofus 4.4, Mis 4.2, Hoppe (pack rabbit) 3.1 |
| palette, multi-region figures, region by region on the palette hex the bake starts from | Natteblik, Pip, Birk, Kløvermynte: every region 0.0 (the models contain the sketch hex); on the screen the large regions are 1.2 - 4.5 (`measure_cast_v2.py palette --regions`) |
| resident S3TC with mipmaps (idle, walk / hover, talk) | 8.7 - 9.3 MB per NPC (P21's villager bear_guard 9.3) |
| disk of the six new folders | 6.4 MB |

The palette gate has teeth (`measure_cast_v2.py --selftest`: published CIEDE2000 pairs, a shaded sketch colour passes, P21's Oak brown fails).  Small regions (the seal of Pip's
letter, Birk's irises, Mis's ear lining) mix with their neighbours at game size and measure 5 - 15 on the screen: they are reported by `--regions`, not gated.

## Review sheets (tools/art/cast_v2/review_v2/, LOOK at them)

* `review_v2/compare_hoppe.png`, `review_v2/compare_brumme.png`, `review_v2/compare_morfar_mis.png`, `review_v2/compare_natteblik.png`, `review_v2/compare_rasmus.png`,
  `review_v2/compare_bertil.png`, `review_v2/compare_bodil.png`, `review_v2/compare_kloevermynte.png`, `review_v2/compare_birk.png`, `review_v2/compare_pip.png`,
  `review_v2/compare_fru_ugle.png`, `review_v2/compare_sofus.png`, `review_v2/compare_kiki.png`: one sheet per figure of the sheet,
  **sketch | bust | idle S | idle SE** (13 sheets like the analysis' `compare_*.png`).  The four heroes of A2 and Hoppe show the stock figure that stands in for them
  (fox, hobbit_pip twice, monkey, pack rabbit); the restyles show the stage bake.
* `review_v2/contact_cast_v2.png`: the eight figures, bust and five frames each (idle S / SE / W, talk, walk or hover).
* `review_v2/cast_next_to_pack_zoom04.png` (+ `review_v2/cast_closeup_zoom09.png`): the real windowed shot of `art_cast_v2.run_windowed`, the eight cast figures next to the pack's bear cat
  rabbit fox fairy on grass at Camera zoom 0.4 on 1280 x 720 (the two restyles in this shot come from a clone in which they were installed).
* `review_v2/outline_ink_vs_pack.png`: the outline A/B of the six heroes (stock stand-ins) and the eight NPCs, pack outline | guide ink, at game zoom magnified 2x and 1:1.

## The honest verdict

Accepted for the M1a city preview as a first pass, with the known weaknesses below; the lead's verdict goes into the next row of the log.

* **Soft CG renders, not the flat painted vector of the sheet.**  The sheet itself says it is "formskitser" (shape sketches to lock proportions and colours before the final
  painted artwork is made): the work here is colour, silhouette and accessories on the pack's soft CG render of the stock rig, not a reproduction of the flat fills and the
  ink stroke.  Eye grammar and the three cheek strokes are the pack's.
* **Upright poses.**  Every figure stands upright on the pear-body rig; the seated sketch poses (Hoppe, Brumme, Mis, Rasmus, Kiki on their haunches, Pip and Fru Ugle on a
  branch) are presentation poses and are not baked.  Relative sizes of the sketch are not binding either: Brumme's sketch is 10.2 % short and Hoppe's ears 8 % tall, both accepted by
  keeping `display_scale` 1.0 (every figure is the pack height).
* **Natteblik shares his model with the hostile bat, Fru Ugle hers with the farm owl and the enemy `ugleoje`** (the stock bat and P21's `make_owl`), but not their colours
  (purple with a lilac lining instead of the pink bat; a gold-eyed brown owl instead of the navy ugleoje) and not their folders: the pack `bat` and the enemy visuals are untouched.
  A player who looks twice will see the family resemblance (the bat's ears and wings, the owl's tufts).
* **Sofus is the only new body and the only figure that can look wrong**: an upright capsule against the pack's low quadruped capybara.  Judged on `review_v2/compare_sofus.png` against the
  sketch and the reference photos in `uploads/`: the capsule, the dark muzzle patch, the dark hands and feet, the cream belly and the orange with its leaf read like the sketch;
  the body below the orange is a little wider than the sketch's (width / height .74 against .70) and his ears are small blobs at game size.  He reads as a capybara from the muzzle patch and the orange.
* **Not baked:** Kiki's banana and Rasmus's scarf (the hero bases are A2's), the paw pads of the seated pose (Brumme has toe beans on his feet), Pip's forehead spine fringe
  (the stock hedgehog has spines on the back of the head only), Mis's whiskers, the sparkles around Kløvermynte and Birk.  The humanoid irises of the sketch are a flat coloured
  disc between sclera and pupil (Birk green, Kløvermynte violet, Mis green, the owl's gold sclera): they read in the busts, they are a few pixels at game size.
* **Ink outline for world sprites: not adopted.**  The busts use the guide ink (UI rule), the world sheets keep the pack outline.  `review_v2/outline_ink_vs_pack.png` is the A/B for the user:
  the ink outline is crisper on grass but heavier and "stickered"; the decision stays with the user (design section 3.7, open question 12).  Palette snap alone is within dE00 <= 6.
* **The restyles are not installed yet** (see "Install order"): in the game Kløvermynte is still the mint-dressed pink-haired shopkeeper and Mis the old purple-grey cat until the
  lead runs `--install-restyles`.  The A/B and the review sheets show them from the stage.
* Voices, dialogue and data of these NPCs are V1 / V7 / P24, not this package.

Known weaknesses: Fru Ugle is the tallest of the cast (106 %, her ear tufts); Natteblik is the shortest (95 %), his wings are 2.8 m wide (241 of 256 px: 7 px to spare in the S and N rows)
and he has no separate body with a belly oval like the sketch's (the stock bat is a head with wings: the belly a896c4 is a chin patch under the mouth); the toe beans, the hammer and the
pencil of Brumme are invisible below zoom 0.9; Birk's cap reads as a beret from the front; Fru Ugle's breast chevrons are flat bars, not the sketch's V marks.

## Verdict log

| date | who | verdict |
|---|---|---|
| 2026-10-14 | builder (V2-cast-art) | Accepted for the milestone preview: 8 ids baked, six installed, two restyles held; gates green (see above); LOOKED at the 13 compare sheets, the contact sheet, the outline A/B and the windowed shot at zoom 0.4 / 0.9 |
| | lead | |

## Codex note

Another agent (Codex) restyles the existing assets at the moment.  Everything in this folder is additive: new folders only, no existing path under `assets/` is written (the two
restyles are held for exactly that reason), `tools/art/README.md` is not edited (the lead merges its rows), `tools/art/storybook/*` and `tools/art/drawn/*` are never run.
