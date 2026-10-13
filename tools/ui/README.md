# tools/ui - UI generators and dev tools (package P07)

`tools/ui/build_theme.gd` is the **single source of the style guide's numbers**: never edit `assets/ui/theme.tres` by hand.
Colours come from `scripts/ui/theme/tt_colors.gd`, the scripted vector StyleBox is `scripts/ui/theme/tt_box_style.gd`
(`TTBoxStyle`), the five rarity tiles (`SlotFilled` = normal, `SlotUncommon`, `SlotRare`, `SlotUnique`, `SlotLegendary`) and the
`RarityWord<Id>` label variations read `Rarity.ui()` (P10), so a palette change in `lua/config/rarity.lua` is one regeneration away.

```
godot --headless --path . --import                      # TWICE on a fresh clone (the first run may print the theme font errors once)
godot --headless --path . -s res://tools/ui/build_theme.gd          # AFTER the import, so the SVG icons resolve (-> assets/ui/theme.tres)
godot --headless --path . res://tools/ui/build_scenes.tscn          # the foundation scenes (item_slot stepper toast ability components game_ui)
godot --headless --path . res://scenes/ui/dev/ui_smoke.tscn         # the foundation smoke (exit 0 = green)
tests/run_playtest.sh --only=ui_foundation                          # the section (re-runs the smoke as a child process)
```

Screenshots (a window opens; ALWAYS through the one-window lock `impl/tools/windowed.sh` / `tools/dev/run_windowed.sh`, <= 2 min):
```
godot --path . --write-movie OUT/f.png --fixed-fps 10 --quit-after 40 res://scenes/ui/dev/shot_runner.tscn -- components components_rarity
python tests/checkpoints/compare_guide.py hud=OUT/hud.png title=OUT/title.png      # mean abs diff against the guide, see its --help
```

* `scenes/ui/dev/components_gallery.tscn`: page `guide` (section 03 of the guide) and page `rarity` (RaritySlot x5 states, selected, unknown,
  themed item slots, word + pips, the legendary `_night` icon and the pale disc, the ladder). Every text is a key (`GALLERY_*` in `localization/ui.csv`).
* `tools/ui/scenes/s_<name>.gd`: generators of the FOUNDATION scenes. `tools/ui/scenes/screens/s_<name>.gd` are the spike's generators of the guide
  screens, kept as REFERENCE for the packages that own those screens (P14 P16 P17 P18 P19); they hold the guide's mock copy and only run with
  `build_scenes.tscn -- --screens --out=user://ui_ref/` (never into `res://scenes/ui`).
* `make_symbols_font.py` rebuilds `assets/fonts/TTSymbols-Regular.ttf` from `NotoSansSymbols2-Regular.ttf` (not shipped: download it from the Noto project, OFL
  text in `assets/fonts/OFL-NotoSansSymbols2.txt`, and pass `--src`). The shipped TTSymbols covers every glyph the UI uses (checked by the smoke).

Rules every screen obeys (plan 5.1): design size 1280x720 (never multiply by 1.5), modal roots `PROCESS_MODE_ALWAYS` and hidden in `_ready`, panel
children inside a plain Control (a `PanelContainer` lays out ALL children over its whole rect), button content in a full-rect `MarginContainer` with
`mouse_filter = IGNORE`, hidden containers do not sort children (measure after show), unique names prefixed per card, portraits with a linear +
mipmaps filter, theme variations instead of per-node overrides, **HUD controls use `focus_mode = NONE`** (GameUI enforces it for `hud` and `forest_hud`),
scenes hold translation KEYS as text, gold ring = focus / selected only (a selected slot REPLACES its rarity ring).
