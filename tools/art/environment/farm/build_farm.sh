#!/usr/bin/env bash
# tools/art/environment/farm/build_farm.sh [STAGE_DIR]
#
# Everything package N03-farm-art produces, in one go (about 40 s): the ten farm-only props, the untilled terrain field_grass, the two backdrop layers, the import stubs and the
# validator.  Strictly ADDITIVE (Codex guardrail, 2026-10-14): nothing that already exists under assets/ is touched; install_farm.py writes an allow-list only
# (assets/iso_props/farm/**, assets/backdrops/farm_far.webp + farm_canopy.webp, assets/iso_tiles/field_grass.png + tiles_farm.json) and refuses farm_sky.*.
# This script deliberately does NOT go through tools/art/produce_all.sh: its `--only=props` slice would re-bake and re-install P22's 149 existing props.
#   STAGE_DIR   default tools/art/_stage/n03 (gitignored, hidden from Godot by tools/art/.gdignore); any folder outside the project works too
# Godot-generated `.import` / `.uid` files are NOT written here: run `godot --headless --import` twice in a CLONE and copy them back (impl/tools/pull_meta.sh).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ART="$(cd "$HERE/../.." && pwd)"
export PY="${PY:-$ART/.venv/bin/python}"
export PYTHONDONTWRITEBYTECODE=1
if [ ! -x "$PY" ]; then echo "ERROR: $PY not found - run tools/art/setup_env.sh first" >&2; exit 1; fi
STAGE_ARGS=()
if [ $# -gt 0 ]; then STAGE_ARGS=(--stage "$1"); fi
"$PY" "$HERE/bake_farm_kit.py" ${STAGE_ARGS[@]+"${STAGE_ARGS[@]}"}
"$PY" "$HERE/bake_farm_tiles.py" ${STAGE_ARGS[@]+"${STAGE_ARGS[@]}"}
"$PY" "$HERE/backdrops_farm.py" ${STAGE_ARGS[@]+"${STAGE_ARGS[@]}"}
"$PY" "$HERE/install_farm.py" ${STAGE_ARGS[@]+"${STAGE_ARGS[@]}"}
"$PY" "$HERE/write_farm_imports.py"
"$PY" "$HERE/art_budget.py" --write > /dev/null
"$PY" "$HERE/validate_farm.py"
