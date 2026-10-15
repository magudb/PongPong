#!/usr/bin/env bash
# tools/art/environment/build_all.sh [STAGE_DIR]
#
# Everything P22 produces, in one go (~90 s): the ground tiles (17 diamond + 7 ortho atlases), the props (model bakes + painted decals / textures), the backdrops
# (hyggebyen, forest) and the validator.  tiles / props go through tools/art/produce_all.sh (stage -> masters -> export -> install into assets/iso_tiles, assets/iso_props);
# the backdrops are painted straight into assets/backdrops (WebP, no master step).
#   STAGE_DIR   default tools/art/_stage (gitignored, hidden from Godot); any folder outside the project works too
# Godot-generated `.import` / `.uid` files of the installed assets are NOT written here: run `godot --headless --import` twice in a CLONE of the repo and copy
# them back (impl/tools/pull_meta.sh) - the tile atlases come with their no-mipmap stubs already (export/import_stubs.py).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ART="$(cd "$HERE/.." && pwd)"
export PY="${PY:-$ART/.venv/bin/python}"
STAGE_ARGS=()
if [ $# -gt 0 ]; then STAGE_ARGS=("$1"); fi
"$ART/produce_all.sh" ${STAGE_ARGS[@]+"${STAGE_ARGS[@]}"} --only=tiles,props
"$PY" "$HERE/backdrops.py"
"$PY" "$ART/drawn/fixtures.py"
"$PY" "$HERE/validate_environment.py"
