#!/usr/bin/env bash
# tools/art/environment/slice_props.sh STAGE_DIR [prop ids...]   (called by tools/art/produce_all.sh --only=props)
#
# P22's slice hook for the props: every registered model prop (the 55 verified spike props, the farm contract props, Hyggebyen, the Moerkeskoven set, the new
# crops) and every painted image prop (additive decals / fx, seamless ground textures) is baked into $TT_ART_MASTERS/iso_props (+ props.json).  The extras the spike's
# old produce_all did by hand (tree_giant_crown at --ss 2) live in the builder data (PropSpec.ss).  With ids only those props are re-baked (props.json is merged).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
shift
: "${PY:?PY is exported by produce_all.sh}"; : "${TT_ART_MASTERS:?TT_ART_MASTERS is exported by produce_all.sh}"
OUT="$TT_ART_MASTERS/iso_props"
mkdir -p "$OUT"
if [ $# -gt 0 ]; then
  "$PY" "$HERE/bake_props.py" "$@" --out "$OUT"
else
  rm -f "$OUT"/*.png "$OUT"/props.json
  "$PY" "$HERE/bake_props.py" --all --out "$OUT"
fi
