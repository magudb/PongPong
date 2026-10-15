# Social core tools (package S-core)

Python tools of the social track's CORE package. They need nothing but the standard library (`python3 -I tool.py ...`); the harness section
`tests/sections/social.gd` runs every one of them (the project's `tools/art/.venv` python when it exists, else `python3`).

| Tool | What it does |
|---|---|
| `social_rng_mirror.py` | Python twin of `scripts/social/social_rng.gd` (FNV-1a 32 + murmur3 fmix32 over `seed\|part\|part`). `--json` prints the six pinned vectors and the 25 % count the section compares with the GDScript numbers. |
| `validate_social.py DUMP.json [--routes=FILE]` | The rules SV1..SV12 and SV14 on a JSON dump of the data (twin of `tests/lib/social/social_validator.gd`; SV13 is S-marriage's). Exit 1 on an error. Rules whose data is not in the tree (gift tastes before S-data, the route table before T-routes) are printed as `SKIP`, never passed silently. |
| `balance_mc.py --dump=FILE --variant=free\|mixed --events=lean\|four\|target` | The Monte Carlo of the social economy (3 profiles x 100 runs x 336 days, reproducible: the rolls use the game's own mixer; `--jobs=N` spreads the games over N forked workers, up to 4 by default, and the numbers are byte for byte the sequential ones). `--bounds=FILE --check` asserts the claims against the ratcheted bounds, `--write-bounds` writes them the first time, `--ratchet` may only tighten them. |
| `availability.py` | Library: the availability table of the `mixed` variant (when can the player talk to whom: outdoors, in transit or - a keeper - at his counter). Schema in its docstring. |
| `build_availability_snapshot.py --towns DIR --out FILE` | One-off provenance tool: samples the design phase's python mirror of the 30 routines into `tests/lib/social/fixtures/availability_design.json`. Not needed to run the game or the tests. |

## The dump

`tests/lib/social/dump_social_json.gd` writes what the REAL LuaRuntime made of the social data (the effective `social` config, `citizens`, `gift_tastes`, the trimmed `npcs`
and `items`, the registries `festivals` and `events`, `time`, `shops`, `towns`):

    godot --headless --path . -s res://tests/lib/social/dump_social_json.gd -- --out=/some/folder/dump.json
    python3 -I tools/social/core/validate_social.py /some/folder/dump.json

`tests/lib/social/fixtures/design_dump.json` is the pinned DESIGN snapshot (30 citizens, 278 giftable items, 9 festivals): what the section and the Monte Carlo use until
S-data (citizens.lua, gift_tastes.lua) and S-fest-content (the festival files) put the real rows into the tree; then the section switches to the live dump by itself.

## The balance claims and the ratchet

`tests/lib/social/balance_bounds.json` holds the bounds the claims are asserted against: each bound is at most the design limit (8 hearts with a tier A citizen by day 80 / p90 115,
75 / 110 with four heart events per citizen, gifts <= 25 % of a dedicated player's points, social time <= 25 % of a game week, never reaching 8 hearts <= 2 %) and at most a small
margin above what the run measured. A data edit that moves the pacing makes `balance_mc.py --check` fail; the file is lowered with `--ratchet` and never raised.
