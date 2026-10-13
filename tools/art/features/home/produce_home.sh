#!/bin/bash
# Regenerate the whole HOME art set of package A1-art-home and install it into the repo (owned paths only).
#
#   tools/art/features/home/produce_home.sh [STAGE] [--stage-only] [--only=exteriors,symmetry,furniture,interior,icons,props,export,validate] [--no-validate] [--jobs=N] [--write-specs] [--keep-noise]
#
#   STAGE           work tree, default tools/art/_stage/features_home (gitignored, hidden from Godot; any other folder must be outside the project)
#   --stage-only    do not copy into the repo (assets/iso_props/{home,furniture,interior,fx,features}, assets/iso_tiles/floor_*, assets/data/home, assets/icons/home,
#                   lua/config/props_features.lua); the default installs after a green validator
#   --only=a,b      run only these stages (default all): exteriors symmetry furniture interior icons props export validate
#   --write-specs   store the freshly measured specs/symmetry_measured.json (symmetry stage) and specs/mirror_ok.json (export stage); without it the symmetry stage only CHECKS
#   --keep-noise    install: keep the installed file when the new bake of it differs by renderer noise only (same size, mean error < 0.8/255); the bake is not byte-deterministic
#   env: PY=python (default tools/art/.venv/bin/python)   JOBS=6
#
# Stages (the order of addendum 5.2):  1 exteriors (10 tiers ss 3 + night emissive trimmed + 9 scaffolds)   2a symmetry (MEASURE the c4/c2 pieces, specs/symmetry_measured.json)   2 furniture (130 items from specs/furniture_art_spec.json, TRUE rotations)
#   3 interior walls / door pieces / 4 floors   4 icons (130 furniture + 32 material, contract style)   5 the nine new props   6 export (WebP q92-94, icons lossless 128x128,
#   json contracts, night rims, mirror measurement, props_features.lua) -> <stage>/assets, export_stats.json   7 validate (validate_features_home.py)   8 install
# Timings on the M3 (quiet machine): exteriors 47 s wall, 130 furniture 20 s, icons 12 s + 6 s, interior + props about 60 s.  A loaded machine distorts them 2-6x.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../../.." && pwd)"
cd "$REPO"
export PYTHONDONTWRITEBYTECODE=1
PY="${PY:-$REPO/tools/art/.venv/bin/python}"
[ -x "$PY" ] || { echo "produce_home: no python at $PY (run tools/art/setup_env.sh, or set PY=...)" >&2; exit 2; }
JOBS="${JOBS:-6}"
STAGE=""
INSTALL=1; VALIDATE=1; ONLY=""; WRITE_SPECS=""; KEEP_NOISE=""
for a in "$@"; do
  case "$a" in
    --stage-only) INSTALL=0 ;;
    --no-validate) VALIDATE=0 ;;
    --only=*) ONLY="${a#--only=}" ;;
    --jobs=*) JOBS="${a#--jobs=}" ;;
    --write-specs) WRITE_SPECS="--write-specs" ;;
    --keep-noise) KEEP_NOISE="--keep-noise" ;;
    -h|--help) sed -n 2,17p "$0"; exit 0 ;;
    -*) echo "produce_home: unknown option $a" >&2; exit 2 ;;
    *) STAGE="$a" ;;
  esac
done
STAGE="${STAGE:-$REPO/tools/art/_stage/features_home}"
export PYTHONPATH="$HERE/characters:$HERE/isometric:$REPO/tools/art/generator:$REPO/tools/art/core"
I="$HERE/isometric"
W="$STAGE"
want() { [ -z "$ONLY" ] || [[ ",$ONLY," == *",$1,"* ]]; }
t0=$(date +%s)
mkdir -p "$W"
step() { echo "== $*"; }

if want exteriors; then step "1/7 exteriors (10 tiers + night emissive + 9 scaffolds)"; "$PY" "$I/bake_home.py" --all --scaffold --out "$W/home_final" --ss 3 --jobs "$JOBS" | tail -2; fi
if want symmetry; then
  step "2a/7 symmetry (measure the pieces whose template declares c4 or c2; --write-specs stores the result, otherwise it must equal specs/symmetry_measured.json)"
  if [ -n "$WRITE_SPECS" ]; then SYM="--write"; else SYM="--check"; fi
  "$PY" "$I/measure_symmetry.py" --jobs "$JOBS" $SYM | grep -E "^(wrote|check:|[0-9]+ pieces)"
fi
if want furniture; then step "2/7 furniture (130 items from the spec, true rotations)"; "$PY" "$I/bake_furniture.py" --spec "$HERE/specs/furniture_art_spec.json" --out "$W/furn" --jobs "$JOBS" --ss 3 | tail -1; fi
if want interior;  then step "3/7 interior walls, door pieces, floors"; "$PY" "$I/bake_interior.py" --out "$W/interior" --ss 3 --jobs 4 | tail -1; fi
if want icons; then
  step "4/7 icons: 130 furniture + 32 material (contract style)"
  "$PY" "$I/icons_contract.py" --spec "$HERE/specs/furniture_art_spec.json" --out "$W/icons_furn" --jobs "$JOBS" | tail -1
  "$PY" "$I/bake_material_icons.py" --out "$W/mat_icons" --jobs 4 | tail -1
fi
if want props; then step "5/7 the nine new props"; "$PY" "$I/bake_features_props.py" --out "$W/features_props" --ss 3 | tail -1; fi
if want export; then step "6/7 export (WebP q92-94, icons lossless, json contracts, night rims, mirror measurement)"; "$PY" "$I/export_home.py" --work "$W" --dst "$W/assets" $WRITE_SPECS --jobs "$JOBS" | tail -2; fi
if want validate && [ "$VALIDATE" = 1 ]; then step "7/7 validate the stage tree"; "$PY" "$I/validate_features_home.py" --assets "$W/assets" | tail -3; fi
if [ "$INSTALL" = 1 ] && want export; then step "8 install into the repo (owned paths only)"; "$PY" "$I/install_home.py" --stage "$W/assets" $KEEP_NOISE; fi
echo "total $(( $(date +%s) - t0 )) s"
if [ -f "$W/assets/export_stats.json" ]; then "$PY" -c "import json,sys; d=json.load(open(sys.argv[1])); print('export_stats: %.2f MB  ' % (d['total_bytes']/1e6) + '  '.join('%s %.2f' % (k, v/1e6) for k, v in d.items() if k != 'total_bytes'))" "$W/assets/export_stats.json"; fi
