#!/usr/bin/env bash
# tools/art/core/smoke.sh - end-to-end smoke test of the art pipeline: fox from the GLB generator to a validated sheet.
#
#   tools/art/setup_env.sh && tools/art/core/smoke.sh          # fox idle sheet, must take < 30 s
#   tools/art/core/smoke.sh --full                             # THE GATE: all 11 fox clips, + GLB validation, vs the shipped pack
#   options: --keep (do not clear the smoke folder first)
#            --max-mean 0.01 (limit of the mean error against the pack)
#            --allow-no-reference (bake + validate only when no pack fox exists; the gate comparison is then NOT verified, the
#                                  result says so and --full refuses it)
# The comparison with the shipped pack fox is MANDATORY: without a pack fox the smoke test fails (exit 1) before it bakes anything
# (a "pass" that compared nothing is not a pass).  --require-reference is accepted for old callers and is now the default.
#
# Steps (everything lands in tools/art/_stage/smoke, which Godot never scans):
#   1 generator/build_assets.py --only fox          GLB rig + textures (~1 s)
#   2 core/bake_sprite_atlases.py fox [--clips idle] VTK bake of the 8 direction rows
#   3 core/validate_new_assets.py                    sheet size, blank frames, border-opaque, animations.json
#   4 core/compare_sheets.py                         mean error against the pack fox + a pack | rebuilt | 8x diff sheet
#   (--full) generator/validate_assets.py            GLB structure and skinning checks
# Nothing here touches the project's assets/ folder, the 12 pack characters, or git.
set -euo pipefail

ART="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FULL=0; KEEP=0; ALLOW_NO_REF=0; MAXMEAN=0.01
while [ $# -gt 0 ]; do
  case "$1" in
    --full) FULL=1 ;;
    --keep) KEEP=1 ;;
    --require-reference) ;;                                   # the default since the P08 fix round
    --allow-no-reference) ALLOW_NO_REF=1 ;;
    --max-mean) shift; MAXMEAN="$1" ;;
    -h|--help) sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

if [ "$FULL" = 1 ] && [ "$ALLOW_NO_REF" = 1 ]; then
  echo "ERROR: --full is the gate (comparison with the shipped pack fox) and cannot run with --allow-no-reference" >&2; exit 2
fi
PY="${PY:-$ART/.venv/bin/python}"
if [ ! -x "$PY" ]; then echo "ERROR: $PY not found - run tools/art/setup_env.sh first" >&2; exit 1; fi
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}$ART/generator:$ART/core"
STAGE="${TT_ART_STAGE:-$ART/_stage}"
W="$STAGE/smoke"
"$PY" -I - "$ART/core" "$W" <<'PYEOF'      # refuses a work folder that Godot would scan
import sys; sys.path.insert(0, sys.argv[1]); import artpaths; artpaths.assert_stage_dir(sys.argv[2], 'smoke folder')
PYEOF

# the reference: the shipped pack fox (assets/isometric_characters once P05 moved it, docs/PongPong_Isometric2D before)
REF="$("$PY" -I -c "import sys;sys.path.insert(0,'$ART/core');import artpaths;d=artpaths.find_pack_character('fox');print(d or '')")"
if [ -z "$REF" ] && [ "$ALLOW_NO_REF" = 0 ]; then
  echo "SMOKE FAIL: no pack fox found to compare against (tried assets/isometric_characters, docs/PongPong_Isometric2D, docs/art/isometric_pack)." >&2
  echo "            The comparison with the shipped fox IS the gate. Run from a full checkout, or pass --allow-no-reference to bake and validate only." >&2
  exit 1
fi
if [ "$KEEP" = 0 ]; then rm -rf "$W"; fi
mkdir -p "$W"

now() { "$PY" -I -c 'import time;print("%.3f" % time.time())'; }
T0=$(now)
step() { echo; echo "== $*   [+$("$PY" -I -c "print('%.1f' % ($(now) - $T0))") s]"; }

step "1/4 generator: build the fox GLB rig"
"$PY" "$ART/generator/build_assets.py" --only fox --output "$W/glb"

CLIPS_ARG=(--clips idle); CLIPS_CMP=(--clips idle)
if [ "$FULL" = 1 ]; then CLIPS_ARG=(); CLIPS_CMP=(); fi
step "2/4 baker: fox ${CLIPS_ARG[*]:-all clips}"
"$PY" "$ART/core/bake_sprite_atlases.py" fox --glb "$W/glb" --out "$W/masters/isometric_characters" ${CLIPS_ARG[@]+"${CLIPS_ARG[@]}"}

step "3/4 validator"
"$PY" "$ART/core/validate_new_assets.py" --root "$W/masters/isometric_characters" fox

step "4/4 compare with the shipped pack fox"
STATUS=0; COMPARED=1
if [ -z "$REF" ]; then
  COMPARED=0
  echo "SKIPPED: no pack fox found and --allow-no-reference was given: the gate comparison is NOT verified."
else
  echo "reference: $REF"
  mkdir -p "$W/previews"
  "$PY" "$ART/core/compare_sheets.py" "$W/masters/isometric_characters/fox" "$REF" ${CLIPS_CMP[@]+"${CLIPS_CMP[@]}"} \
        --max-mean "$MAXMEAN" --out "$W/previews/fox_vs_pack.png" || STATUS=1
fi

if [ "$FULL" = 1 ]; then
  step "GLB structure + skinning validation (generator/validate_assets.py)"
  "$PY" "$ART/generator/validate_assets.py" --glb "$W/glb" --only fox --report "$W/glb/validation.json" || STATUS=1
fi

T1=$(now)
ELAPSED=$("$PY" -I -c "print('%.1f' % ($T1 - $T0))")
echo
echo "smoke: $ELAPSED s, outputs in $W"
if [ "$FULL" = 0 ]; then
  if "$PY" -I -c "import sys;sys.exit(0 if $T1 - $T0 < 30 else 1)"; then echo "time budget: under 30 s OK"; else echo "time budget: OVER 30 s" >&2; STATUS=1; fi
fi
if [ "$STATUS" = 0 ]; then
  if [ "$COMPARED" = 1 ]; then echo "SMOKE PASS"; else echo "SMOKE PASS (gate comparison SKIPPED: bake + validate only)"; fi
else echo "SMOKE FAIL" >&2; fi
exit "$STATUS"
