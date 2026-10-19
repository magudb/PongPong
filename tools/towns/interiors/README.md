# Walk-in interiors: generator, validator, E-query replay (package T-towns-core)

A room is DATA: `data/interiors/<core|ext>/int_<id>.json` (schema `data/interiors/schema.json`) plus a seven line stub map `data/maps/int_<id>.map`;
`scripts/towns/interior_room.gd` (class `InteriorRoom`) builds it. Everything here is Python 3 standard library only, seed-free and deterministic.
Run with `python3 -B -I <script>` (isolated, no bytecode: the tools never leave a `__pycache__` behind).

| Tool | What it does |
|---|---|
| `generate.py --list` | one line per room: size, items, posts, markers, stand-ins, generator notes |
| `generate.py --out DIR [--wave core\|ext] [--only a,b]` | writes `int_<id>.json` for the 24 rooms (14 CORE, 10 EXTENDED) from the layout grammars |
| `generate.py --maps DIR [--wave core\|ext]` | writes the seven line stub maps `int_<id>.map` (zone = the zone of the outer area: `city` for Hyggebyen, `traetoppen`) |
| `generate.py --check DIR [DIR ...]` | regenerates every `int_*.json` found and fails on any difference, unless the spec carries `"hand_edited": true` (skipped, and said so) |
| `generate.py --buildings` | the room-relevant fields of the 24 buildings as JSON; the section `towns_data` / `towns_interiors` compares them with the Lua registry |
| `validate.py PATH [PATH ...] [--stand-ins] [--dress-dir D]` | every `int_*.json` under the paths, merged with its `dress/int_<id>.json` overlay: schema, id/exit/door/spawn, pieces known and inside the room, no overlap, the counter band, the hosts, flood fill (player and citizen), the E-query rules A / B / C; last line `validate: N room(s), M problem(s)` |
| `validate.py --selftest` | breaks a generated room 14 ways + 2 overlays and proves every mutant is caught |
| `validate.py PATH --reach` | JSON of the cells the player and a citizen reach (the Godot section compares it with the REAL colliders) |
| `e_query_replay.py PATH [--emit FILE]` | replays the BUILT E-query (circles r = 45 at the facing cell, at the reach point ahead of the feet and, for counter hosts, at the feet; 12-gon ellipses, the host nearest to the player wins): rule A (an end cell selects its `talk` host), B (the middle cell selects the centre host), C (a talk host is never selected from the middle cell); `--emit` writes the selection table the Godot twin must reproduce sample by sample |
| `make_kit_table.py --source integration_shop_kit.json` | writes `data/interiors/kit_footprints.json` (footprint and layer of the 104 kit ids: 89 pieces + 15 emblem plates; I3 = 35, I4 = 69) |

`--stand-ins` reports only fallbacks actually selected after the shipped core/specialist kits and furniture. Add `--without-kit` to exercise the missing-kit regression fixtures.

The 31-sprite layout gate covers the base walls, corner, doormat and room pieces. Painted hatch sprites and optional dressing also count toward the unchanged whole-room limit of 130 nodes, four lights and a 12 ms median warm build. Painted light masks use one clock connection per room and at most one additional service-fire light; ceiling art stays above actors.

## Grammars (`grammar.py`)

* **shop band**: a 3 x 1 counter on row 2 (`counter_pine`), invisible hatch bars on the NPC layer from the counter ends to the side walls, the keeper post on row 1,
  the centre host (`shop`) on the cell in front of the counter middle `(m, 3)`, a `talk` host on each of the two customer cells in front of the counter ENDS `(m - 1, 3)` and `(m + 1, 3)`,
  the builder yard's `desk` on `(m + 2, 3)`, shelves along the back wall (first fit), display pieces, customer posts.
* **service**: the same band with another centre host (`post_counter`, `bath`, `board`, `appraisal`, `bar`) and staff posts; the post office adds its `mailbox` marker.
* **home**: a bed, a wardrobe, a hearth, a table with seats and a rug; no counter, no hatch.

Pieces are kit ids (`data/interiors/kit_footprints.json`) or furniture ids (A1, 130 pieces); the room JSON never carries a `stand_in` field: `PieceCatalog` resolves
baked kit manifest > furniture.json > `data/interiors/stand_ins.json` > a labelled box, and reports every stand-in it used.

## Adding or changing a room

1. Edit the lists of `build_all()` in `grammar.py` (or hand-edit a spec and mark it `"hand_edited": true`), run `generate.py --out data/interiors/<core|ext>` and `generate.py --maps data/maps`.
2. `validate.py data/interiors tests/fixtures/towns/interiors` must print `0 problem(s)`; `generate.py --check data/interiors` must pass.
3. `tests/run_playtest.sh --only=towns_interiors` proves the same on the real colliders and the real player.
