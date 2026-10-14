#!/usr/bin/env bash
# tools/art/ghost/produce_ghost.sh - build the two ghost heroes (Bu, Hviske) through the REAL art pipeline.
#
#   tools/art/ghost/produce_ghost.sh [STAGE_DIR] [--stage-only] [--jobs=N]
#
# = tools/art/produce_all.sh --only=characters ghost_bu ghost_hviske, with this folder (the shim traetoppen_additions.py + ghost_model.py) FIRST on
# PYTHONPATH.  The generator imports its extra builders by the module name `traetoppen_additions`, the caller's PYTHONPATH wins (produce_all.sh header),
# so the shim hides P21's module for this run only: build GLB rig -> bake 8 directions x 47 frames (clip set `full`, pack outline, no baked glow) ->
# validate the masters -> WebP export (+ S3TC import stubs) -> validate the WebP -> install into assets/isometric_characters/ghost_bu, ghost_hviske
# (+ the two rows of manifest_traetoppen.json, merged by the installer) -> audit.  About 10-14 s wall for both heroes on an M3.
#
#   --stage-only   stop after the export (nothing is copied into assets/): the result is in <stage>/assets/isometric_characters/
#   STAGE_DIR      a folder with a slash: inside the project only tools/art/_stage[/x] is accepted (produce_all.sh)
#
# Codex guardrail: strictly ADDITIVE.  The two ids are NEW; the installer mirrors only their own folders and merges two rows into the manifest.  This
# script refuses to run when an id of the other characters would be built (it passes exactly the two ghost ids), and it never touches the pack.
#
# Examples (repo root):
#   tools/art/ghost/produce_ghost.sh                                    build, bake, validate, export, install
#   tools/art/ghost/produce_ghost.sh tools/art/_stage/ghost --stage-only   just stage them (this is what `produce_all.sh --stage-only` lists: the two ids)
#   PYTHONPATH=tools/art/ghost tools/art/produce_all.sh --stage-only --only=characters    the same listing without this wrapper
set -eEuo pipefail
trap 'rc=$?; if [ "$BASH_SUBSHELL" = 0 ]; then echo "produce_ghost: FAILED (exit $rc) at line $LINENO: $BASH_COMMAND" >&2; fi' ERR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ART="$(cd "$HERE/.." && pwd)"

case "${1:-}" in -h|--help) sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

# the ids are fixed: only options (--...) and ONE stage folder (an argument with a slash) may be passed, never another character id
for arg in "$@"; do
  case "$arg" in
    --stage-only|--jobs=*|*/*) ;;
    *) echo "produce_ghost: unexpected argument '$arg' (this script builds exactly ghost_bu and ghost_hviske; options: --stage-only --jobs=N, a STAGE_DIR)" >&2; exit 2 ;;
  esac
done

# this folder FIRST (the shim must win against tools/art/characters/traetoppen_additions.py), whatever the caller exported stays behind it
export PYTHONPATH="$HERE${PYTHONPATH:+:$PYTHONPATH}"
exec "$ART/produce_all.sh" --only=characters "$@" ghost_bu ghost_hviske
