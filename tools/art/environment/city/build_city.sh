#!/usr/bin/env bash
# tools/art/environment/city/build_city.sh [STAGE_DIR]      (package V5-art-city; bash, from any directory)
#
# bake every texture of the Traetoppen city set -> validate the stage -> install into assets/iso_props/city + assets/backdrops/treetop_* -> validate the install.
# About 90 s on a quiet M3.  The stage is a folder OUTSIDE the project or tools/art/_stage/<name>; default tools/art/_stage/city.
# It never runs tools/art/produce_all.sh, storybook/* or drawn/* and never writes a pre-existing asset (the installer guards its two owned paths).
#   --only=id,id   bake just these ids (the stage's props.json keeps the others), then install everything the stage holds
#   --no-install   stop after the validation of the stage
# Godot-written .import / .uid files are NOT written here: run `godot --headless --import` twice in a CLONE and copy them back with impl/tools/pull_meta.sh.
# K: lua/config/traetoppen.lua `scale` (ONE constant); change it and re-run this script, the whole set rescales.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ART="$(cd "$HERE/../.." && pwd)"
export PY="${PY:-$ART/.venv/bin/python}"
export PYTHONDONTWRITEBYTECODE=1
STAGE="$ART/_stage/city"; ONLY=""; INSTALL=1
for arg in "$@"; do
  case "$arg" in
    --only=*) ONLY="${arg#--only=}" ;;
    --no-install) INSTALL=0 ;;
    */*) STAGE="$arg" ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done
ONLY_ARGS=(); if [ -n "$ONLY" ]; then ONLY_ARGS=(--only "$ONLY"); fi
echo "== bake -> $STAGE"
"$PY" "$HERE/bake_city.py" --stage "$STAGE" ${ONLY_ARGS[@]+"${ONLY_ARGS[@]}"}
echo "== validate the stage"
"$PY" "$HERE/validate_city.py" --stage "$STAGE"
if [ "$INSTALL" = 1 ]; then
  echo "== install"
  "$PY" "$HERE/install_city.py" --stage "$STAGE"
  echo "== validate the installed set"
  "$PY" "$HERE/validate_city.py"
fi
