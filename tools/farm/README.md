# tools/farm - the treetop farm "Min Traekronsgaard" (package N01-farm-map)

`data/maps/farm.map` is the map of the player's farm: 61 x 51 cells, 1,206 of them ground. **The file is authoritative and hand-editable**; these
tools help to change it safely. Python tools run with the project venv (`tools/art/.venv/bin/python`) or plain `python3` (the checker needs only
the standard library; the generator's `--out` previews need Pillow).

| Tool | What it does |
|---|---|
| `python tools/farm/check_farm_map.py [MAP]` | offline checker, no Godot: header, grid, field (84 = 12 x 7), expansion zone (42 cells), home reserve + growth rows, spawns / warps, the towns contract (one `town curfew=false`, the five posts, the dress flag `festival_now`), objects on void, light budget, HUD / canopy band, building slots, a conservative reachability BFS. Exit 0 = clean. |
| `python tools/farm/check_farm_map.py --selftest` | the baseline must be clean and eight mutants (E1 cells in the reserve, 83 `f` cells, spawn `from_home` removed, a gap in the hanging bridge, a growth marker on the wrong row, a post renamed, the town anchor missing, a Skovport lift marker back) must each be caught. Prints `PASS farm_map_tool.selftest_catches_eight_mutants`. |
| `python tools/farm/farm_map_gen.py --check` | does the committed map still equal the generator's output? (A hand edit makes it differ: fine, the checker and the section `maps_farm` are the contract.) `--out DIR` writes a regenerated map, facts and a layout preview PNG; `--stdout` prints the map text. It never writes into the repo by itself. |
| `python tools/farm/farm_preview.py` | the drawing helper behind the layout preview (imported by the generator). |
| `python tools/farm/contact_sheet.py OUT.png IMG...` | a labelled contact sheet of screenshots (art is judged on sheets). |
| `farm_shot.tscn` | windowed screenshot driver: `impl/tools/windowed.sh godot --path . --resolution 1280x720 res://tools/farm/farm_shot.tscn --quit-after 6000 -- --out=DIR [--part=all\|main\|tiers\|night\|tour\|expansion\|plain\|perf]`. |
| `farm_standins.gd` | stand-ins for handlers other packages own (house, tent, mailbox, shed, bin, rope ring, field look). Used by the section and the shot driver only; never registered as a marker handler. |

The headless proof is `tests/run_playtest.sh --only=maps_farm` (real IsoArea / WorldRoot2D / Warp2D / colliders); `--windowed` adds the draw-call and
texture budgets in a real window.
