#!/usr/bin/env bash
# tools/art/produce_all.sh - regenerate art from source: build / bake -> validate -> export -> install at the contract paths.
#
#   tools/art/produce_all.sh [STAGE_DIR] [--only=SLICES] [--stage-only] [--busts] [--jobs=N] [ids...]
#
#   --only=characters|tiles|props|icons|keyart      one or several slices, comma separated (default: all of them)
#   ids...                                          restrict the slice to these ids (characters, tiles, props, icons)
#   STAGE_DIR                                       an argument containing a slash; default tools/art/_stage (gitignored,
#                                                   hidden from Godot by tools/art/.gdignore).  Inside the project ONLY tools/art/_stage[/x]
#                                                   is accepted (a Godot-scanned folder, or one git does not ignore, is refused)
#   --stage-only                                    stop after the export: do not copy into the project's assets/
#   --busts                                         characters slice for the 12 PACK ids: bake only the head-and-shoulders bust
#                                                   and install it as assets/portraits/<id>.webp (the pack itself is never rebuilt)
#   --jobs=N (or env JOBS)                          parallel bakes, default 5
#
# Examples (repo root):
#   tools/art/produce_all.sh                                   EVERYTHING that exists (slices of packages that have not landed are skipped, loudly)
#   tools/art/produce_all.sh --only=characters hobbit_pip      one character: ~1 s build + 3-14 s bake (clip-set dependent)
#   tools/art/produce_all.sh --only=tiles,props                P22 slice
#   tools/art/produce_all.sh --only=characters --busts fox bat P21: pack busts -> assets/portraits
#
# Where things go:   _stage/glb (rigs)  ->  _stage/masters (lossless PNG)  ->  _stage/assets (WebP, game-ready)  ->  assets/<contract dir>
# The install step writes ONLY assets/{isometric_characters/<new id>,portraits,iso_tiles,iso_props,icons/items,ui/keyart} and never
# touches the 12 pack characters (export/install_assets.py enforces it).  Character sheets get their S3TC .import stub next to them.
#
# Slice owners and what runs (a slice whose script is missing is SKIPPED with a message; an explicitly requested slice that
# cannot run makes the exit code 3):
#   characters  generator/build_assets.py + core/bake_sprite_atlases.py + core/validate_new_assets.py   builders: tools/art/characters (P21)
#   tiles       tools/art/environment/bake_tiles.py --all|names --out <masters>/iso_tiles               (P22)
#   props       tools/art/environment/bake_props.py --all|names --out <masters>/iso_props               (P22)
#   icons       tools/art/icons/bake_icons.py --all|names --out <masters>/icons/items                   (P23)
#   keyart      tools/art/icons/slice_keyart.sh                                                         (P23)
#   A package may take over a slice completely with an executable tools/art/<its dir>/slice_<name>.sh; it is called as
#   `slice_<name>.sh STAGE_DIR [ids...]` with PY, TT_ART_STAGE, TT_ART_GLB, TT_ART_MASTERS and PYTHONPATH exported, and must
#   write its lossless masters under $TT_ART_MASTERS (mirroring res://assets, e.g. iso_tiles/, icons/items/).
# Failure semantics: ANY failing step (builder, bake, either validator, export, install, audit) stops the script at once with a
#   non-zero exit and a "produce_all: FAILED" line; nothing after the failing step runs, so a failed bake can never be exported or
#   installed.  Before a rebuild the stage's old output of the same ids (GLB, masters, exported tree) is deleted, so a broken builder
#   cannot silently re-bake and re-install the previous GLB.  Character ids must be lower-case [a-z0-9_]+ (exit 2 otherwise);
#   the pack ids are recognised whatever the letter case.
# Lessons baked in: bash (macOS zsh does not word-split variables), no pgrep -f (it matches itself), xargs -P for parallel bakes,
#   NEVER call a function that must stop the script as `fn || exit` (bash switches errexit off inside such a call).
set -eEuo pipefail
trap 'rc=$?; if [ "$BASH_SUBSHELL" = 0 ]; then echo "produce_all: FAILED (exit $rc) at line $LINENO: $BASH_COMMAND" >&2; fi' ERR

ART="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONLY=""; STAGE_ONLY=0; BUSTS=0; STAGE_ARG=""; JOBS="${JOBS:-5}"; IDS=()
for arg in "$@"; do
  case "$arg" in
    --only=*) ONLY="${ONLY:+$ONLY,}${arg#--only=}" ;;
    --stage-only) STAGE_ONLY=1 ;;
    --busts) BUSTS=1 ;;
    --jobs=*) JOBS="${arg#--jobs=}" ;;
    -h|--help) sed -n '2,42p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --*) echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
    */*) STAGE_ARG="$arg" ;;
    *) IDS+=("$arg") ;;
  esac
done

PY="${PY:-$ART/.venv/bin/python}"
if [ ! -x "$PY" ]; then echo "ERROR: $PY not found - run tools/art/setup_env.sh first" >&2; exit 1; fi

ALL_SLICES="characters,props,tiles,icons,keyart"
REQUESTED=0; NSLICES=0
if [ -n "$ONLY" ]; then REQUESTED=1; else ONLY="$ALL_SLICES"; fi
for s in $(echo "$ONLY" | tr ',' ' '); do
  case "$s" in characters|props|tiles|icons|keyart) NSLICES=$((NSLICES + 1)) ;; *) echo "unknown slice '$s' (characters|tiles|props|icons|keyart)" >&2; exit 2 ;; esac
done
if [ ${#IDS[@]} -gt 0 ] && [ "$NSLICES" -ne 1 ]; then
  echo "ERROR: ids (${IDS[*]}) only make sense for exactly one slice: use --only=<slice> ids..." >&2; exit 2
fi
if [ "$BUSTS" = 1 ] && [ "$ONLY" != "characters" ]; then echo "ERROR: --busts belongs to --only=characters" >&2; exit 2; fi
if [ "$ONLY" != "characters" ]; then   # tiles/props/icons ids go to the bakers of P22/P23 as file names: no path tricks
  for id in ${IDS[@]+"${IDS[@]}"}; do
    case "$id" in ""|*/*|.*|-*) echo "ERROR: bad id '$id' (no path separators, no leading dot or dash)" >&2; exit 2 ;; esac
  done
fi

export PYTHONDONTWRITEBYTECODE=1
export PY
# the caller's PYTHONPATH wins (feature packages put their shims first); ours are appended
OWN_PATH="$ART/generator:$ART/core"
for d in characters environment icons; do [ -d "$ART/$d" ] && OWN_PATH="$OWN_PATH:$ART/$d"; done
export PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}$OWN_PATH"

# resolve + guard the stage (a folder Godot scans is refused)
STAGE="$("$PY" -I - "$ART/core" "${STAGE_ARG:-${TT_ART_STAGE:-$ART/_stage}}" <<'PYEOF'
import sys; sys.path.insert(0, sys.argv[1]); import artpaths
print(artpaths.Stage(sys.argv[2]).root)
PYEOF
)" || exit $?
export TT_ART_STAGE="$STAGE" TT_ART_GLB="$STAGE/glb" TT_ART_MASTERS="$STAGE/masters"
GLB="$TT_ART_GLB"; MASTERS="$TT_ART_MASTERS"; GAME="$STAGE/assets"
mkdir -p "$GLB" "$MASTERS" "$GAME"
echo "stage: $STAGE   python: $PY   jobs: $JOBS"

# pack | new | invalid  (artcontract.classify_id: the pack check is case-insensitive, new ids are [a-z0-9_]+)
id_kind() { "$PY" -I "$ART/core/artcontract.py" classify "$1"; }
PACK="$("$PY" -I -c "import sys;sys.path.insert(0,'$ART/core');import artcontract as c;print(' '.join(c.PACK_IDS))")"
lower() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

DONE=(); SKIPPED=(); INSTALL_CLASSES=(); CHAR_IDS=(); ICON_IDS=()
skip_slice() { SKIPPED+=("$1: $2"); echo "SKIP $1: $2"; }
step() { echo; echo "== $*"; }

# ---- characters -------------------------------------------------------------------------------------------------------
# Delete what an earlier run left in the stage for these ids (GLB + textures + rig json, masters, exported tree, bust), so that a
# failing builder or baker can never be "rescued" by stale output.  Ids were classified [a-z0-9_]+ before: no path can escape the stage.
clear_stage_ids() {
  local id
  for id in "$@"; do
    rm -rf "$MASTERS/isometric_characters/$id" "$GAME/isometric_characters/$id"
    rm -f "$MASTERS/portraits/$id.png" "$GAME/portraits/$id.webp"
    rm -f "$GLB/$id.glb" "$GLB/${id}_rig.json" "$GLB/${id}_basecolor.png" "$GLB/${id}_orm.png" "$GLB/${id}_uv_layout.json"
  done
}

slice_characters() {
  local ids=() id
  if [ ${#IDS[@]} -gt 0 ]; then ids=("${IDS[@]}"); else
    # every extra builder registered by tools/art/characters/traetoppen_additions.py (P21), or a feature shim on PYTHONPATH
    local listing
    if [ "$BUSTS" = 1 ]; then listing="$PACK"; else listing="$("$PY" -I -c "
import sys, os
sys.path[:0] = os.environ['PYTHONPATH'].split(':')
import build_assets as b
print('\n'.join(b.TT_BUILDERS))")"; fi
    for id in $listing; do ids+=("$id"); done
  fi
  if [ ${#ids[@]} -eq 0 ]; then
    skip_slice characters "no extra character builders (tools/art/characters/traetoppen_additions.py of P21 is not present)"; return 0
  fi
  local pack_given=() new=()
  for id in "${ids[@]}"; do
    case "$(id_kind "$id")" in
      pack) pack_given+=("$id") ;;
      new) new+=("$id") ;;
      *) echo "ERROR: bad character id '$id': ids are lower-case ASCII [a-z0-9_]+ (they become folder names)" >&2; return 2 ;;
    esac
  done
  if [ ${#pack_given[@]} -gt 0 ] && [ "$BUSTS" = 0 ]; then
    echo "ERROR: ${pack_given[*]} belong to the shipped 12-character pack; the pack is never rebuilt into the game tree." >&2
    echo "       Use --busts to produce their portraits (assets/portraits/<id>.webp), or tools/art/core/smoke.sh --full to rebuild fox for comparison." >&2
    return 2
  fi
  if [ "$BUSTS" = 1 ]; then
    if [ ${#new[@]} -gt 0 ]; then echo "ERROR: --busts is for the 12 pack ids only (got: ${new[*]})" >&2; return 2; fi
    for id in "${pack_given[@]}"; do
      if [ "$id" != "$(lower "$id")" ]; then echo "ERROR: write the pack id in lower case for --busts ('$id' -> '$(lower "$id")')" >&2; return 2; fi
    done
    step "characters: busts of ${pack_given[*]}"
    clear_stage_ids "${pack_given[@]}"
    "$PY" "$ART/generator/build_assets.py" --only "${pack_given[@]}" --output "$GLB"
    "$PY" "$ART/core/bake_sprite_atlases.py" "${pack_given[@]}" --bust-only --glb "$GLB" --out "$MASTERS/portraits"
    step "characters: MANDATORY validator on the busts (256 x 256, not blank, not cut at the top or the sides)"
    "$PY" "$ART/core/validate_new_assets.py" --portraits "$MASTERS/portraits" "${pack_given[@]}"
    INSTALL_CLASSES+=(portraits); CHAR_IDS+=("${pack_given[@]}"); DONE+=("characters(busts: ${pack_given[*]})")
    return 0
  fi
  local unknown
  unknown="$("$PY" -I - "${new[@]}" <<'PYEOF'
import sys, os
sys.path[:0] = os.environ['PYTHONPATH'].split(':')
import build_assets as b
known = set(b.TT_BUILDERS) | set(b.BUILDERS) | {n for n in b.NAMES}
print(' '.join(n for n in sys.argv[1:] if n not in known))
PYEOF
)"
  if [ -n "$unknown" ]; then
    echo "ERROR: no builder for: $unknown (known extra builders come from tools/art/characters/traetoppen_additions.py on PYTHONPATH)" >&2; return 2
  fi
  clear_stage_ids "${new[@]}"
  step "characters 1/4: build GLB rigs (${#new[@]} models, ~1 s each)"
  "$PY" "$ART/generator/build_assets.py" --only "${new[@]}" --output "$GLB" --manifest manifest_tt.json
  step "characters 2/4: bake 8-direction sprite sheets ($JOBS parallel, ~3-14 s per model)"
  printf '%s\n' "${new[@]}" | xargs -P "$JOBS" -I{} "$PY" "$ART/core/bake_sprite_atlases.py" {} --glb "$GLB" --out "$MASTERS/isometric_characters"
  step "characters 3/4: MANDATORY validator on the masters"
  "$PY" "$ART/core/validate_new_assets.py" --root "$MASTERS/isometric_characters" "${new[@]}"
  INSTALL_CLASSES+=(characters); CHAR_IDS+=("${new[@]}"); DONE+=("characters(${new[*]})")
}

# ---- tiles / props / icons / keyart: owned by P22 / P23 ---------------------------------------------------------------
slice_builder() {   # name  dir  script  subdir-of-masters  install-class
  local name="$1" dir="$2" script="$3" sub="$4" cls="$5" hook="$ART/$2/slice_$1.sh" ids=()
  if [ ${#IDS[@]} -gt 0 ]; then ids=("${IDS[@]}"); fi
  if [ -x "$hook" ]; then
    step "$name: $dir/slice_$name.sh"
    "$hook" "$STAGE" ${ids[@]+"${ids[@]}"}
  elif [ "$script" != "-" ] && [ -f "$ART/$dir/$script" ]; then
    step "$name: $dir/$script"
    if [ ${#ids[@]} -gt 0 ]; then "$PY" "$ART/$dir/$script" "${ids[@]}" --out "$MASTERS/$sub"
    else "$PY" "$ART/$dir/$script" --all --out "$MASTERS/$sub"; fi
  else
    local what="tools/art/$dir/slice_$name.sh"
    if [ "$script" != "-" ]; then what="tools/art/$dir/$script (or $dir/slice_$name.sh)"; fi
    skip_slice "$name" "$what is not present yet - owned by ${6:-its art package}"; return 0
  fi
  if [ "$name" = icons ] && [ ${#ids[@]} -gt 0 ]; then ICON_IDS+=("${ids[@]}"); fi
  INSTALL_CLASSES+=("$cls"); DONE+=("$name")
}

for s in $(echo "$ONLY" | tr ',' ' '); do
  case "$s" in
    characters) slice_characters ;;   # never `|| exit $?`: bash disables errexit inside a function called that way (review defect 1)
    props)      slice_builder props environment bake_props.py iso_props props "P22" ;;
    tiles)      slice_builder tiles environment bake_tiles.py iso_tiles tiles "P22" ;;
    icons)      slice_builder icons icons bake_icons.py icons/items icons "P23" ;;
    keyart)     slice_builder keyart icons - ui/keyart keyart "P23" ;;
  esac
done

if [ ${#INSTALL_CLASSES[@]} -eq 0 ]; then
  echo
  echo "nothing was produced."
  for m in ${SKIPPED[@]+"${SKIPPED[@]}"}; do echo "  skipped - $m"; done
  if [ "$REQUESTED" = 1 ]; then exit 3; fi
  exit 0
fi

step "export: masters -> game-ready tree ($GAME)"
CLASSES="$(printf '%s,' "${INSTALL_CLASSES[@]}")"; CLASSES="${CLASSES%,}"
EXPORT_ARGS=(--src "$MASTERS" --dst "$GAME" --glb "$GLB" --jobs "$JOBS" --classes "$CLASSES")
if [ ${#CHAR_IDS[@]} -gt 0 ]; then EXPORT_ARGS+=(--only "${CHAR_IDS[@]}"); fi
if [ ${#ICON_IDS[@]} -gt 0 ]; then EXPORT_ARGS+=(--only-icons "${ICON_IDS[@]}"); fi
"$PY" "$ART/export/export_game_assets.py" "${EXPORT_ARGS[@]}"

for cls in ${INSTALL_CLASSES[@]+"${INSTALL_CLASSES[@]}"}; do
  if [ "$cls" = characters ]; then
    step "validator on the exported WebP sheets (role clip sets, display_scale, portrait)"
    "$PY" "$ART/core/validate_new_assets.py" --root "$GAME/isometric_characters" "${CHAR_IDS[@]}"
  elif [ "$cls" = portraits ]; then
    step "validator on the exported bust WebP files"
    "$PY" "$ART/core/validate_new_assets.py" --portraits "$GAME/portraits" "${CHAR_IDS[@]}"
  fi
done

if [ "$STAGE_ONLY" = 1 ]; then
  echo; echo "stage-only: nothing was copied into the project (result is in $GAME)"
else
  step "install: copy to the contract paths of assets/"
  INSTALL_ARGS=(--stage "$STAGE" --classes "$CLASSES")
  if [ ${#CHAR_IDS[@]} -gt 0 ]; then INSTALL_ARGS+=(--only "${CHAR_IDS[@]}"); fi
  if [ ${#ICON_IDS[@]} -gt 0 ]; then INSTALL_ARGS+=(--only-icons "${ICON_IDS[@]}"); fi
  "$PY" "$ART/export/install_assets.py" "${INSTALL_ARGS[@]}"
  # P05's audit when it exists (it may not understand every flag: only a hard FAIL (exit 1) counts)
  REPO="$(cd "$ART/../.." && pwd)"
  if [ -f "$REPO/tools/import/write_import_stubs.py" ]; then
    step "audit with tools/import/write_import_stubs.py --check (P05)"
    set +e; "$PY" "$REPO/tools/import/write_import_stubs.py" --check; RC=$?; set -e
    if [ "$RC" = 1 ]; then echo "AUDIT FAILED: the installed stubs do not satisfy P05's rules" >&2; exit 1; fi
    [ "$RC" != 0 ] && echo "(audit tool exited $RC: not a verdict, check its usage)"
  fi
fi

echo
echo "produce_all: done -> ${DONE[*]}"
for m in ${SKIPPED[@]+"${SKIPPED[@]}"}; do echo "  skipped - $m"; done
if [ "$REQUESTED" = 1 ] && [ ${#SKIPPED[@]} -gt 0 ]; then exit 3; fi
exit 0
