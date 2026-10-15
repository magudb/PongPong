#!/usr/bin/env bash
# tools/art/environment/slice_tiles.sh STAGE_DIR [terrain ids...]   (called by tools/art/produce_all.sh --only=tiles)
#
# P22's slice hook for the ground tiles: the 17 diamond atlases (grass ... water_3) AND the 7 ortho terrains (forest_floor_o ... wall_void_o, camera azimuth 0,
# 96 x 56) are baked by one script into $TT_ART_MASTERS/iso_tiles (+ tiles.json).  With ids only those terrains are re-baked (tiles.json is merged).
# The exporter then writes the no-mipmap import stubs, install_assets.py copies the result to assets/iso_tiles/.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
shift                                  # STAGE_DIR: the environment variables below already carry it
: "${PY:?PY is exported by produce_all.sh}"; : "${TT_ART_MASTERS:?TT_ART_MASTERS is exported by produce_all.sh}"
OUT="$TT_ART_MASTERS/iso_tiles"
mkdir -p "$OUT"
if [ $# -gt 0 ]; then
  "$PY" "$HERE/bake_tiles.py" "$@" --out "$OUT"
else
  rm -f "$OUT"/*.png "$OUT"/tiles.json        # a full bake never keeps terrains of an older recipe list
  "$PY" "$HERE/bake_tiles.py" --all --out "$OUT"
fi
