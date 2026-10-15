#!/usr/bin/env bash
# tools/art/cast_v2/produce_cast_v2.sh - bake the Figurer v2 cast through the REAL pipeline (package V2-cast-art).
#
#   tools/art/cast_v2/produce_cast_v2.sh [--list] [--stage-only] [--install-restyles] [--jobs=N] [--stage=DIR] [--clean]
#
#   (no flag)            build + bake + validate + export the 8 ids into the stage, swap in the ink busts, validate again and INSTALL the six NEW ids
#                        (bear_brumme bat_natteblik hedgehog_pip owl_fru_ugle capybara_sofus fairy_birk_npc) into assets/isometric_characters/
#   --stage-only         stop before the install: the result stays in <stage>/assets
#   --install-restyles   ALSO install the two RESTYLED ids (fairy_shopkeeper, cat_morfar_mis).  They are baked into the stage on every run but
#                        installed only on this explicit request: they replace art that already exists in assets/ (and that another agent restyles
#                        at the moment), so the lead decides when (see tools/art/cast_v2/README.md, "Install order")
#   --list               print the eight ids with the module and function of their builder and exit (nothing is built)
#   --jobs=N             parallel bakes (default 5, the pipeline's default)
#   --stage=DIR          stage folder, default tools/art/_stage/v2cast (a package-private stage: never collides with another package's bake)
#   --clean              delete the stage folder at the end (a stage is 200+ MB of masters)
#
# What it does (the same steps as tools/art/produce_all.sh, which it CALLS for steps 1-3):
#   0  PYTHONPATH = tools/art/cast_v2 FIRST: the shim traetoppen_additions.py of this folder is the module the generator imports
#      (build_assets.py: `from traetoppen_additions import BUILDERS, EXTRA_PATTERNS, EXTRA_CLIPS`; the caller's PYTHONPATH wins, produce_all.sh header)
#   1  produce_all.sh <stage> --only=characters --stage-only <8 ids>: GLB rigs -> 8-direction sheets (clip sets villager / npc_flyer, pack outline
#      (75,60,73) .55) -> masters validator -> WebP + S3TC stubs -> exported-tree validator
#   2  the busts: portrait.webp of every folder is baked AGAIN with the existing `bake_sprite_atlases.py --outline ink` switch (guide ink #2b2340,
#      artcontract.INK: "ink is for icons and UI"); the world sheets keep the pack outline.  The new bust replaces portrait.png in the masters and
#      portrait.webp in the exported tree (same encoder, q97 method 4), then the exported tree is validated again
#   3  install_assets.py --classes characters --only <ids>: copies the folders (new ids only unless --install-restyles) and MERGES their rows into
#      assets/isometric_characters/manifest_traetoppen.json (rows of other packages are never rewritten)
#   4  tools/import/write_import_stubs.py --check (P05's audit), as produce_all.sh does after an install
# Nothing outside assets/isometric_characters/<one of the 8 ids>/ and the manifest is ever written.  The 12 pack characters and the other 34 P21
# characters are never touched (install_assets.py refuses them; --only names the ids).
set -eEuo pipefail
trap 'rc=$?; echo "produce_cast_v2: FAILED (exit $rc) at line $LINENO: $BASH_COMMAND" >&2' ERR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ART="$(cd "$HERE/.." && pwd)"
REPO="$(cd "$ART/../.." && pwd)"
PY="${PY:-$ART/.venv/bin/python}"
NEW_IDS=(bear_brumme bat_natteblik hedgehog_pip owl_fru_ugle capybara_sofus fairy_birk_npc)
RESTYLE_IDS=(fairy_shopkeeper cat_morfar_mis)
ALL_IDS=("${NEW_IDS[@]}" "${RESTYLE_IDS[@]}")

STAGE_ONLY=0; INSTALL_RESTYLES=0; LIST=0; CLEAN=0; JOBS="${JOBS:-5}"; STAGE="$ART/_stage/v2cast"
for arg in "$@"; do
  case "$arg" in
    --stage-only) STAGE_ONLY=1 ;;
    --install-restyles) INSTALL_RESTYLES=1 ;;
    --list) LIST=1 ;;
    --clean) CLEAN=1 ;;
    --jobs=*) JOBS="${arg#--jobs=}" ;;
    --stage=*) STAGE="${arg#--stage=}" ;;
    -h|--help) sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $arg (try --help)" >&2; exit 2 ;;
  esac
done
if [ ! -x "$PY" ]; then echo "ERROR: $PY not found - run tools/art/setup_env.sh first" >&2; exit 1; fi

export PYTHONDONTWRITEBYTECODE=1
# the caller's PYTHONPATH is kept AFTER ours: this folder goes first (the shim of the same module name wins), then the generator and the core
export PYTHONPATH="$HERE${PYTHONPATH:+:$PYTHONPATH}:$ART/generator:$ART/core:$ART/characters"

if [ "$LIST" = 1 ]; then
  "$PY" -I - "${ALL_IDS[@]}" <<'PYEOF'
import os, sys
sys.path[:0] = os.environ['PYTHONPATH'].split(':')
import build_assets as b
import traetoppen_additions as shim
for cid in sys.argv[1:]:
    fn = b.TT_BUILDERS[cid]
    print('%-18s %s.%s  (%s)' % (cid, fn.__module__, fn.__name__, 'RESTYLE of a P21 id' if cid in shim.RESTYLE_IDS else 'NEW id'))
print('generator hook module: %s' % b.TT_BUILDERS['bear_brumme'].__module__ + '  <- must be cast_v2_models (the shim won the import)')
PYEOF
  exit 0
fi

# resolve the stage; refuse anything the pipeline's own guard refuses (a Godot-scanned folder, or inside the project but not under tools/art/_stage)
STAGE="$("$PY" -I - "$ART/core" "$STAGE" <<'PYEOF'
import sys; sys.path.insert(0, sys.argv[1]); import artpaths
print(artpaths.Stage(sys.argv[2]).root)
PYEOF
)"
export TT_ART_STAGE="$STAGE" TT_ART_GLB="$STAGE/glb" TT_ART_MASTERS="$STAGE/masters"
GLB="$TT_ART_GLB"; MASTERS="$TT_ART_MASTERS"; GAME="$STAGE/assets"
echo "produce_cast_v2: stage $STAGE   ids: ${ALL_IDS[*]}"

echo; echo "== 1/4 produce_all.sh --only=characters --stage-only (shim first on PYTHONPATH)"
"$ART/produce_all.sh" "$STAGE" --only=characters --stage-only --jobs="$JOBS" "${ALL_IDS[@]}"

echo; echo "== 2/4 busts with the guide ink outline (bake_sprite_atlases.py --outline ink), swapped into masters and exported tree"
INK="$STAGE/ink_busts"; rm -rf "$INK"; mkdir -p "$INK"
printf '%s\n' "${ALL_IDS[@]}" | xargs -P "$JOBS" -I{} "$PY" "$ART/core/bake_sprite_atlases.py" {} --clips idle --outline ink --glb "$GLB" --out "$INK" >/dev/null
"$PY" - "$ART" "$INK" "$MASTERS" "$GAME" "${ALL_IDS[@]}" <<'PYEOF'
import shutil, sys
from pathlib import Path
art = Path(sys.argv[1])
sys.path[:0] = [str(art / 'export'), str(art / 'core')]
ink, masters, game = (Path(a) for a in sys.argv[2:5])
import export_game_assets as ex          # the exporter's own encoder (WebP q97, method 4, alpha_quality 100)
for cid in sys.argv[5:]:
    src = ink / cid / 'portrait.png'
    if not src.is_file():
        raise SystemExit('no ink bust baked for %s (%s)' % (cid, src))
    shutil.copy2(src, masters / 'isometric_characters' / cid / 'portrait.png')
    n = ex.webp(src, game / 'isometric_characters' / cid / 'portrait.webp')
    print('  %-18s ink bust %6.1f KB' % (cid, n / 1024))
PYEOF
rm -rf "$INK"
"$PY" "$ART/core/validate_new_assets.py" --root "$GAME/isometric_characters" "${ALL_IDS[@]}"

if [ "$STAGE_ONLY" = 1 ]; then
  echo; echo "produce_cast_v2: --stage-only: nothing was installed (result in $GAME)"
else
  INSTALL=("${NEW_IDS[@]}")
  if [ "$INSTALL_RESTYLES" = 1 ]; then INSTALL=("${ALL_IDS[@]}"); fi
  echo; echo "== 3/4 install: ${INSTALL[*]}"
  "$PY" "$ART/export/install_assets.py" --stage "$STAGE" --classes characters --only "${INSTALL[@]}"
  if [ -f "$REPO/tools/import/write_import_stubs.py" ]; then
    echo; echo "== 4/4 audit with tools/import/write_import_stubs.py --check (P05)"
    set +e; "$PY" "$REPO/tools/import/write_import_stubs.py" --check; RC=$?; set -e
    if [ "$RC" = 1 ]; then echo "AUDIT FAILED: the installed stubs do not satisfy P05's rules" >&2; exit 1; fi
  fi
  if [ "$INSTALL_RESTYLES" = 0 ]; then
    echo; echo "produce_cast_v2: the two restyled ids (${RESTYLE_IDS[*]}) are baked in the stage but NOT installed (use --install-restyles)"
  fi
fi
if [ "$CLEAN" = 1 ]; then rm -rf "$STAGE"; echo "produce_cast_v2: stage $STAGE deleted"; fi
echo "produce_cast_v2: done"
