#!/usr/bin/env bash
# tools/art/core/selftest.sh - regression checks of the art pipeline (P08): one section per defect found by the review.
#
#   tools/art/core/selftest.sh                       # every section, about 3-4 minutes
#   tools/art/core/selftest.sh errexit busts         # only some sections
#   tools/art/core/selftest.sh --list                # section names with the defect each one guards
#   options: --keep (keep the sandbox for a look)
#
# Everything runs in a throw-away SANDBOX PROJECT (a copy of tools/art without .venv/_stage, a project.godot and an empty assets/ in
# $TMPDIR): the installer writes into the sandbox, never into the real assets/, and the real stage is never touched.
# Failures are injected through a python wrapper (FAIL_ON=<text in the command line> makes that one call exit 1) and through a
# builder shim (selftest_fox, TT_SELFTEST_BOOM=1 makes it raise), so the test needs no network and no other package's code.
# Exit code 0 only when every check of every selected section passed.
set -uo pipefail

ART="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECTIONS_ALL="errexit clips stale ids stage smoke busts"
KEEP=0; SELECTED=""
for arg in "$@"; do
  case "$arg" in
    --keep) KEEP=1 ;;
    --list)
      cat <<'LIST'
errexit  produce_all stops (non-zero, no "done", nothing installed) when the bake, either validator or the builder fails; stale GLB is not reused
clips    baker: unknown/empty --clips fails; validator: no clips / no idle / malformed json / missing sheet are FAIL lines, no traceback
stale    a re-bake clears old sheets; the exporter only converts the sheets animations.json lists; an unlisted sheet fails validation
ids      the pack guard is case-insensitive (Fox, FOX, Bat) in install and produce_all; only [a-z0-9_]+ ids; --busts needs lower case
stage    a stage inside the project must be tools/art/_stage[/...] (tools/art/_stage2, docs/... are refused)
smoke    smoke.sh fails without a pack fox (before baking); --allow-no-reference says "SKIPPED"; --full refuses it
busts    the 12 pack busts install through produce_all --busts, pass --portraits (nothing cut at top/sides); old framing is caught; synthetic faults fail
LIST
      exit 0 ;;
    -h|--help) sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    errexit|clips|stale|ids|stage|smoke|busts) SELECTED="$SELECTED $arg" ;;
    *) echo "unknown argument: $arg (try --list)" >&2; exit 2 ;;
  esac
done
[ -n "$SELECTED" ] || SELECTED="$SECTIONS_ALL"

REAL_PY="${PY:-$ART/.venv/bin/python}"
if [ ! -x "$REAL_PY" ]; then echo "ERROR: $REAL_PY not found - run tools/art/setup_env.sh first (or set PY)" >&2; exit 1; fi
export PYTHONDONTWRITEBYTECODE=1
T="$(mktemp -d "${TMPDIR:-/tmp}/art_selftest.XXXXXX")" || exit 1
cleanup() { if [ "$KEEP" = 1 ]; then echo "sandbox kept: $T"; else rm -rf "$T"; fi; }
trap cleanup EXIT

# ---- tiny test framework --------------------------------------------------------------------------------------------------
PASS=0; FAILS=0; OUT=""; RC=0
ok()  { PASS=$((PASS + 1)); echo "  ok   - $1"; }
bad() { FAILS=$((FAILS + 1)); echo "  FAIL - $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | tail -n 12 | sed 's/^/         | /'; return 0; }
run() { OUT="$("$@" 2>&1)"; RC=$?; }                       # never aborts the selftest: the checks below judge $RC and $OUT
want_rc()      { if [ "$RC" = "$1" ]; then ok "$2 (exit $RC)"; else bad "$2: expected exit $1, got $RC" "$OUT"; fi; }
want_nonzero() { if [ "$RC" != 0 ]; then ok "$1 (exit $RC)"; else bad "$1: expected a non-zero exit, got 0" "$OUT"; fi; }
want_out()     { if printf '%s' "$OUT" | grep -qF -- "$1"; then ok "output has '$1'"; else bad "output lacks '$1'" "$OUT"; fi; }
no_out()       { if printf '%s' "$OUT" | grep -qF -- "$1"; then bad "output must not contain '$1'" "$OUT"; else ok "output has no '$1'"; fi; }
want_file()    { if [ -e "$1" ]; then ok "exists: ${1#$T/}"; else bad "missing: ${1#$T/}"; fi; }
no_file()      { if [ ! -e "$1" ]; then ok "absent: ${1#$T/}"; else bad "must not exist: ${1#$T/}"; fi; }
same_bytes()   { if cmp -s "$1" "$2"; then ok "$3"; else bad "$3 (files differ)"; fi; }
section()      { echo; echo "== section $1: $2"; }

# python wrapper used to inject a failure: any call whose arguments contain $FAIL_ON exits 1
cat > "$T/pywrap.sh" <<EOF
#!/bin/bash
for a in "\$@"; do
  case "\$a" in *"\${FAIL_ON:-@@never@@}"*) echo "SIMULATED failure of: \$*" >&2; exit 1 ;; esac
done
exec "$REAL_PY" "\$@"
EOF
chmod +x "$T/pywrap.sh"

# builder shim: a new character built from the stock fox (clip set critter: 5 clips, the cheapest full bake)
mkdir -p "$T/shim"
cat > "$T/shim/traetoppen_additions.py" <<'EOF'
import os
from additions import BUILDERS as _BASE

def _selftest_fox():
    if os.environ.get('TT_SELFTEST_BOOM'):
        raise RuntimeError('selftest: this builder is broken on purpose')
    m = _BASE['fox']()
    m.slug = 'selftest_fox'
    m.clip_set = 'critter'
    return m

BUILDERS = {'selftest_fox': _selftest_fox}
EXTRA_PATTERNS = {}
EXTRA_CLIPS = {}
EOF

# a sandbox project: tools/art copy + project.godot + assets/.  $1 = name; sets P (project) and TA (its tools/art)
sandbox() {
  P="$T/$1/proj"; TA="$P/tools/art"
  mkdir -p "$TA" "$P/assets"
  ( cd "$ART" && tar --exclude=.venv --exclude=_stage --exclude=__pycache__ -cf - . ) | ( cd "$TA" && tar -xf - )
  : > "$P/project.godot"
}
png_fox_cell() {   # $1 = file: a 256 x 256 RGBA image with a small figure in the middle (a valid, unclipped bust)
  "$REAL_PY" -I -c "
import sys
from PIL import Image, ImageDraw
im = Image.new('RGBA', (256, 256), (0, 0, 0, 0)); ImageDraw.Draw(im).ellipse((70, 70, 190, 190), fill=(200, 120, 60, 255)); im.save(sys.argv[1])" "$1"
}

# ================================================================================================================================
sec_errexit() {
  section errexit "a failing step must stop produce_all (review defect 1: errexit was off inside 'slice_characters || exit')"
  sandbox errexit; local ST="$T/errexit/stage" PA="$TA/produce_all.sh"
  echo " - busts: the bust bake fails"
  FAIL_ON=bake_sprite_atlases PY="$T/pywrap.sh" run "$PA" "$ST" --only=characters --busts bat fox
  want_nonzero "bust bake failure stops produce_all"; want_out "SIMULATED failure"; want_out "produce_all: FAILED"; no_out "produce_all: done"; no_out "== export"
  no_file "$P/assets/portraits"
  echo " - busts: the bust validator fails"
  FAIL_ON=validate_new_assets PY="$T/pywrap.sh" run "$PA" "$ST" --only=characters --busts bat
  want_nonzero "bust validator failure stops produce_all"; no_out "produce_all: done"; no_out "== export"; no_file "$P/assets/portraits"

  echo " - characters: a good run first (build, bake 5 clips, validate, export, install)"
  PYTHONPATH="$T/shim" PY="$REAL_PY" run "$PA" "$ST" --only=characters selftest_fox
  want_rc 0 "good character run"; want_out "produce_all: done -> characters(selftest_fox)"
  want_file "$P/assets/isometric_characters/selftest_fox/idle.webp"; want_file "$P/assets/isometric_characters/selftest_fox/idle.webp.import"
  want_file "$P/assets/isometric_characters/selftest_fox/portrait.webp"; want_file "$P/assets/isometric_characters/manifest_traetoppen.json"
  grep -q 'compress/mode=2' "$P/assets/isometric_characters/selftest_fox/walk.webp.import" && ok "walk.webp.import carries compress/mode=2 (S3TC stub)" || bad "S3TC stub content"
  no_file "$P/assets/isometric_characters/selftest_fox/portrait.webp.import"
  local KEEPSUM; KEEPSUM="$(cd "$P/assets" && find . -type f | sort | xargs shasum | shasum)"

  echo " - characters: the masters validator fails (mandatory step 3)"
  FAIL_ON=validate_new_assets PYTHONPATH="$T/shim" PY="$T/pywrap.sh" run "$PA" "$ST" --only=characters selftest_fox
  want_nonzero "masters validator failure stops produce_all"; want_out "SIMULATED failure"; no_out "produce_all: done"; no_out "== export"; no_out "== install"
  [ "$(cd "$P/assets" && find . -type f | sort | xargs shasum | shasum)" = "$KEEPSUM" ] && ok "the installed tree is untouched" || bad "the installed tree changed after a failed run"

  echo " - characters: the builder is broken, the stage still holds the old GLB (must not be re-baked and re-installed)"
  want_file "$ST/glb/selftest_fox.glb"
  TT_SELFTEST_BOOM=1 PYTHONPATH="$T/shim" PY="$REAL_PY" run "$PA" "$ST" --only=characters selftest_fox
  want_nonzero "broken builder stops produce_all"; want_out "selftest: this builder is broken on purpose"; no_out "produce_all: done"; no_out "characters 2/4"
  no_file "$ST/glb/selftest_fox.glb"; no_file "$ST/masters/isometric_characters/selftest_fox"
  [ "$(cd "$P/assets" && find . -type f | sort | xargs shasum | shasum)" = "$KEEPSUM" ] && ok "nothing was re-installed" || bad "assets changed after a failed run"

  echo " - characters: the baker fails after a good build"
  FAIL_ON=bake_sprite_atlases PYTHONPATH="$T/shim" PY="$T/pywrap.sh" run "$PA" "$ST" --only=characters selftest_fox
  want_nonzero "baker failure stops produce_all"; no_out "produce_all: done"; no_out "characters 3/4"

  echo " - argument errors keep exit 2"
  PYTHONPATH="$T/shim" PY="$REAL_PY" run "$PA" "$ST" --only=characters fox;       want_rc 2 "pack id without --busts"; want_out "shipped 12-character pack"
  PYTHONPATH="$T/shim" PY="$REAL_PY" run "$PA" "$ST" --only=characters nosuchchar; want_rc 2 "unknown id"; want_out "no builder for: nosuchchar"
}

# ================================================================================================================================
sec_clips() {
  section clips "clip filter, empty folders and malformed animations.json (review defect 2)"
  sandbox clips; local W="$T/clips" G="$T/clips/glb" M="$T/clips/masters"
  export PYTHONPATH="$TA/generator:$TA/core"
  "$REAL_PY" "$TA/generator/build_assets.py" --only fox --output "$G" > /dev/null || { bad "could not build the fox GLB"; return; }
  run "$REAL_PY" "$TA/core/bake_sprite_atlases.py" fox --clips idel --glb "$G" --out "$M"
  want_nonzero "--clips with a typo (idel) fails"; want_out "unknown clip"; no_file "$M/fox/animations.json"
  run "$REAL_PY" "$TA/core/bake_sprite_atlases.py" fox --clips idle,idel --glb "$G" --out "$M"
  want_nonzero "--clips with one unknown name fails"; no_file "$M/fox/idle.png"
  run "$REAL_PY" "$TA/core/bake_sprite_atlases.py" fox --clips "" --glb "$G" --out "$M"
  want_nonzero "an empty --clips fails"
  run "$REAL_PY" "$TA/core/bake_sprite_atlases.py" fox --clips attack --glb "$G" --out "$M"
  want_nonzero "--clips attack on a rig without attack fails"
  run "$REAL_PY" "$TA/core/bake_sprite_atlases.py" Fox --glb "$G" --out "$M"
  want_nonzero "the baker refuses the id 'Fox'"
  run "$REAL_PY" "$TA/core/bake_sprite_atlases.py" fox --clips idle --glb "$G" --out "$M"
  want_rc 0 "--clips idle bakes"; want_file "$M/fox/idle.png"
  run "$REAL_PY" "$TA/core/validate_new_assets.py" --root "$M" fox
  want_rc 0 "a partial --clips bake validates (idle present, partial flag)"
  "$REAL_PY" -I -c "
import json, sys
m = json.load(open(sys.argv[1])); assert m['clip_set'] == 'full' and m['partial'] is True and m['flyer'] is False, m" "$M/fox/animations.json" && ok "baker writes clip_set, flyer and partial" || bad "baker metadata missing"

  # the masters validator now checks the role clip set (the baker writes clip_set): drop the partial flag -> 10 clips are missing
  mkdir -p "$W/v"; cp -R "$M/fox" "$W/v/role"
  "$REAL_PY" -I -c "
import json, sys
p = sys.argv[1]; m = json.load(open(p)); m.pop('partial'); json.dump(m, open(p, 'w'))" "$W/v/role/animations.json"
  run "$REAL_PY" "$TA/core/validate_new_assets.py" --root "$W/v" role
  want_rc 1 "a complete-claim folder with one clip fails the masters validator"; want_out "clip set full needs"

  # folders without clips / idle, broken json
  mkdir -p "$W/v/empty" "$W/v/noidle" "$W/v/badjson" "$W/v/nosheet" "$W/v/badimg" "$W/v/list"
  local HEAD='"cell_size":[256,256],"pivot":[128,200],"directions":["S","SW","W","NW","N","NE","E","SE"]'
  echo "{$HEAD,\"animations\":{}}" > "$W/v/empty/animations.json"
  run "$REAL_PY" "$TA/core/validate_new_assets.py" --root "$W/v" empty
  want_rc 1 "a folder with zero clips is invalid"; want_out "no clips"
  cp "$M/fox/idle.png" "$W/v/noidle/walk.png"
  echo "{$HEAD,\"animations\":{\"walk\":{\"frames\":4,\"fps\":9,\"loop\":true,\"sheet\":\"walk.png\"}}}" > "$W/v/noidle/animations.json"
  run "$REAL_PY" "$TA/core/validate_new_assets.py" --root "$W/v" noidle
  want_rc 1 "a folder without idle is invalid"; want_out "no idle clip"
  echo '{"cell_size": [256, 256' > "$W/v/badjson/animations.json"
  run "$REAL_PY" "$TA/core/validate_new_assets.py" --root "$W/v" badjson
  want_rc 1 "malformed animations.json is a FAIL line"; want_out "FAIL badjson"; no_out "Traceback"
  echo "{$HEAD,\"animations\":{\"idle\":{\"frames\":4,\"fps\":5,\"loop\":true}}}" > "$W/v/nosheet/animations.json"
  run "$REAL_PY" "$TA/core/validate_new_assets.py" --root "$W/v" nosheet
  want_rc 1 "a clip without 'sheet' is a FAIL line"; want_out "no sheet name"; no_out "Traceback"
  echo "{$HEAD,\"animations\":{\"idle\":{\"frames\":4,\"fps\":5,\"loop\":true,\"sheet\":\"idle.png\"}}}" > "$W/v/badimg/animations.json"
  echo "not an image" > "$W/v/badimg/idle.png"
  run "$REAL_PY" "$TA/core/validate_new_assets.py" --root "$W/v" badimg
  want_rc 1 "an unreadable sheet is a FAIL line"; want_out "unreadable"; no_out "Traceback"
  echo '[1, 2, 3]' > "$W/v/list/animations.json"
  run "$REAL_PY" "$TA/core/validate_new_assets.py" --root "$W/v" list
  want_rc 1 "animations.json that is not an object is a FAIL line"; no_out "Traceback"
  unset PYTHONPATH
}

# ================================================================================================================================
sec_stale() {
  section stale "stale sheets must neither survive a re-bake nor be exported (review defect 3)"
  sandbox stale; local G="$T/stale/glb" MS="$T/stale/masters" A="$T/stale/assets"; local M="$MS/isometric_characters"
  export PYTHONPATH="$TA/generator:$TA/core"
  "$REAL_PY" "$TA/generator/build_assets.py" --only fox --output "$G" > /dev/null || { bad "could not build the fox GLB"; return; }
  "$REAL_PY" "$TA/core/bake_sprite_atlases.py" fox --clips idle,walk,run --glb "$G" --out "$M" > /dev/null || { bad "bake failed"; return; }
  want_file "$M/fox/run.png"
  "$REAL_PY" "$TA/core/bake_sprite_atlases.py" fox --clips idle,walk --glb "$G" --out "$M" > /dev/null
  no_file "$M/fox/run.png"; want_file "$M/fox/walk.png"
  "$REAL_PY" -I -c "
import json, sys
print(sorted(json.load(open(sys.argv[1]))['animations']))" "$M/fox/animations.json" | grep -qx "\['idle', 'walk'\]" && ok "animations.json lists exactly idle, walk" || bad "animations.json clip list"

  echo " - a stray sheet in the masters folder"
  cp "$M/fox/idle.png" "$M/fox/ghost.png"
  run "$REAL_PY" "$TA/core/validate_new_assets.py" --root "$M" fox
  want_rc 1 "the validator flags a sheet that animations.json does not list"; want_out "not listed in animations.json"
  run "$REAL_PY" "$TA/export/export_game_assets.py" --src "$MS" --dst "$A" --glb "$G" --classes characters --only fox
  want_rc 0 "export"; want_file "$A/isometric_characters/fox/idle.webp"; want_file "$A/isometric_characters/fox/walk.webp"; want_file "$A/isometric_characters/fox/portrait.webp"
  no_file "$A/isometric_characters/fox/ghost.webp"; no_file "$A/isometric_characters/fox/ghost.webp.import"; no_file "$A/isometric_characters/fox/run.webp"
  want_file "$A/isometric_characters/fox/idle.webp.import"; want_file "$A/isometric_characters/fox/walk.webp.import"
  "$REAL_PY" -I -c "
import json, sys
m = json.load(open(sys.argv[1])); assert 'partial' not in m and m['role'] == 'player' and m['clip_set'] == 'full', m" "$A/isometric_characters/fox/animations.json" && ok "exported animations.json: no partial flag, role/clip_set set" || bad "exported animations.json"
  run "$REAL_PY" "$TA/core/validate_new_assets.py" --root "$A/isometric_characters" fox
  want_rc 1 "an incomplete export fails the role clip-set validation"; want_out "clip set full needs"
  no_out "not listed"

  echo " - a listed sheet that is missing"
  rm -f "$M/fox/ghost.png" "$M/fox/walk.png"
  run "$REAL_PY" "$TA/export/export_game_assets.py" --src "$MS" --dst "$T/stale/assets2" --glb "$G" --classes characters --only fox
  want_nonzero "export refuses an animations.json that names a missing sheet"; want_out "does not exist"
  run "$REAL_PY" "$TA/export/export_game_assets.py" --src "$MS" --dst "$T/stale/assets3" --glb "$G" --classes characters --only nosuch
  want_nonzero "export of an id that has no masters folder fails"; want_out "nothing to export"
  unset PYTHONPATH
}

# ================================================================================================================================
sec_ids() {
  section ids "the pack guard is case-insensitive; ids are [a-z0-9_]+ (review defect 4)"
  sandbox ids; local PA="$TA/produce_all.sh" PK="$P/assets/isometric_characters/fox"
  mkdir -p "$PK"; echo 'pack idle bytes' > "$PK/idle.webp"; echo 'pack walk bytes' > "$PK/walk.webp"; echo '{}' > "$PK/animations.json"
  local ID N=0
  for ID in Fox FOX Bat fOx; do      # stage folders get distinct names: on APFS stage_Fox and stage_FOX would be one folder
    N=$((N + 1)); local ST="$T/ids/stage_$N"; mkdir -p "$ST/assets/isometric_characters/$ID"
    echo "staged bytes $ID" > "$ST/assets/isometric_characters/$ID/idle.webp"; echo '{}' > "$ST/assets/isometric_characters/$ID/animations.json"
    run "$REAL_PY" "$TA/export/install_assets.py" --stage "$ST" --classes characters
    want_rc 2 "install refuses the staged folder '$ID'"; want_out "refusing"
  done
  [ "$(cat "$PK/idle.webp")" = "pack idle bytes" ] && ok "pack fox/idle.webp is untouched" || bad "pack fox/idle.webp was overwritten"
  want_file "$PK/walk.webp"
  for ID in hobbit-pip Hobbit pip.v2 "a b" .hidden; do
    local ST="$T/ids/stage_x"; rm -rf "$ST"; mkdir -p "$ST/assets/isometric_characters/$ID"; echo '{}' > "$ST/assets/isometric_characters/$ID/animations.json"
    run "$REAL_PY" "$TA/export/install_assets.py" --stage "$ST" --classes characters
    want_rc 2 "install refuses the folder name '$ID'"
  done
  local ST="$T/ids/stage_ok"; mkdir -p "$ST/assets/isometric_characters/hobbit_pip"; echo '{}' > "$ST/assets/isometric_characters/hobbit_pip/animations.json"
  run "$REAL_PY" "$TA/export/install_assets.py" --stage "$ST" --classes characters --dry-run
  want_rc 0 "a valid new id is accepted"
  echo " - produce_all"
  PY="$REAL_PY" run "$PA" "$T/ids/s1" --only=characters Fox;            want_rc 2 "produce_all refuses 'Fox' as a rebuild"; want_out "shipped 12-character pack"
  PY="$REAL_PY" run "$PA" "$T/ids/s1" --only=characters --busts FOX;    want_rc 2 "produce_all --busts needs lower case"; want_out "lower case"
  PY="$REAL_PY" run "$PA" "$T/ids/s1" --only=characters "hobbit-pip";   want_rc 2 "produce_all refuses 'hobbit-pip'"; want_out "bad character id"
  PY="$REAL_PY" run "$PA" "$T/ids/s1" --only=characters ".hidden";      want_rc 2 "produce_all refuses '.hidden'"; want_out "bad character id"
  PY="$REAL_PY" run "$PA" "$T/ids/s1" --only=tiles ".hidden";           want_rc 2 "produce_all refuses '.hidden' for tiles"; want_out "bad id"
  "$REAL_PY" -I "$TA/core/artcontract.py" classify fox Fox FOX hobbit_pip Hobbit "a/b" "" > "$T/ids/kinds.txt"
  [ "$(tr '\n' ' ' < "$T/ids/kinds.txt")" = "pack pack pack new invalid invalid invalid " ] && ok "artcontract classify: pack pack pack new invalid invalid invalid" || bad "classify output: $(tr '\n' ' ' < "$T/ids/kinds.txt")"
}

# ================================================================================================================================
sec_stage() {
  section stage "inside the project the stage must be tools/art/_stage (review defect 6)"
  sandbox stage; local PA="$TA/produce_all.sh"
  mkdir -p "$P/docs"; : > "$P/docs/.gdignore"
  local C="import sys; sys.path.insert(0, sys.argv[1]); import artpaths; artpaths.Stage(sys.argv[2])"
  run "$REAL_PY" -I -c "$C" "$TA/core" "$TA/_stage";           want_rc 0 "tools/art/_stage is a stage"
  run "$REAL_PY" -I -c "$C" "$TA/core" "$TA/_stage/second";    want_rc 0 "tools/art/_stage/second is a stage"
  run "$REAL_PY" -I -c "$C" "$TA/core" "$T/stage/elsewhere";   want_rc 0 "a folder outside the project is a stage"
  run "$REAL_PY" -I -c "$C" "$TA/core" "$TA/_stage2";          want_nonzero "tools/art/_stage2 is refused"; want_out "tools/art/_stage"
  run "$REAL_PY" -I -c "$C" "$TA/core" "$TA/.venv/x";          want_nonzero "tools/art/.venv/x is refused"
  run "$REAL_PY" -I -c "$C" "$TA/core" "$P/docs/out";          want_nonzero "docs/out (hidden from Godot, but not gitignored) is refused"
  run "$REAL_PY" -I -c "$C" "$TA/core" "$P/assets/oops";       want_nonzero "assets/oops (scanned by Godot) is refused"; want_out ".gdignore"
  PY="$REAL_PY" run "$PA" "$TA/_stage2" --only=characters --busts bat
  want_nonzero "produce_all refuses tools/art/_stage2"; want_out "not under tools/art/_stage"
  no_file "$TA/_stage2"
  run env TT_ART_GLB="$P/assets/glb" "$REAL_PY" -I -c "import sys; sys.path.insert(0, sys.argv[1]); import artpaths; artpaths.glb_dir()" "$TA/core"
  want_nonzero "a TT_ART_GLB override into assets/ is refused"
}

# ================================================================================================================================
sec_smoke() {
  section smoke "the gate comparison cannot silently turn into a pass (review defect 5)"
  sandbox smoke; local SM="$TA/core/smoke.sh"
  PY="$REAL_PY" TT_ART_STAGE="$T/smoke/st" run "$SM"
  want_rc 1 "smoke without a pack fox fails"; want_out "SMOKE FAIL: no pack fox found"; no_out "SMOKE PASS"
  no_file "$T/smoke/st/smoke"
  PY="$REAL_PY" TT_ART_STAGE="$T/smoke/st" run "$SM" --full --allow-no-reference
  want_rc 2 "--full cannot be combined with --allow-no-reference"
  PY="$REAL_PY" TT_ART_STAGE="$T/smoke/st" run "$SM" --allow-no-reference
  want_rc 0 "smoke --allow-no-reference bakes and validates"; want_out "SMOKE PASS (gate comparison SKIPPED"; want_out "NOT verified"
  PY="$REAL_PY" TT_ART_STAGE="$TA/_stage2" run "$SM" --allow-no-reference
  want_nonzero "smoke refuses a work folder in tools/art/_stage2"
}

# ================================================================================================================================
sec_busts() {
  section busts "the 12 pack busts: framing table, --portraits validator, produce_all --busts (review defect 7)"
  sandbox busts; local ST="$T/busts/stage" PA="$TA/produce_all.sh"
  PY="$REAL_PY" run "$PA" "$ST" --only=characters --busts
  want_rc 0 "produce_all --only=characters --busts (all 12 pack ids)"; want_out "validator on the busts"; want_out "12/12 bust portraits valid"; want_out "produce_all: done"
  local n; n="$(find "$P/assets/portraits" -name '*.webp' 2>/dev/null | wc -l | tr -d ' ')"
  [ "$n" = 12 ] && ok "12 busts installed into assets/portraits" || bad "installed busts: $n"
  [ "$(cd "$P/assets" && find . -type f | grep -v '^./portraits/' | wc -l | tr -d ' ')" = 0 ] && ok "nothing but assets/portraits/*.webp was written" || bad "other files were written"
  run "$REAL_PY" "$TA/core/validate_new_assets.py" --portraits "$P/assets/portraits"
  want_rc 0 "the installed WebP busts validate"; want_out "12/12 bust portraits valid"

  echo " - the old single-rule framing (no table, no fit) is caught: bat, fairy, fox, cat, raccoon, monkey were cut at the sides"
  export PYTHONPATH="$TA/generator:$TA/core"
  mkdir -p "$T/busts/old"
  "$REAL_PY" -I -c "
import sys
sys.path[:0] = sys.argv[1:3]
import artcontract as ac
ac.BUST_FRAMING.clear()
import bake_sprite_atlases as bk
bk.Renderer.fit_bust = lambda self, angle, fy, half, margin=None: (half, 0.0)    # the old single rule: default window, no shift
for n in ('bat', 'fairy', 'fox', 'cat', 'raccoon', 'monkey', 'bear'):
    bk.bust_only(n, sys.argv[4], sys.argv[3])" "$TA/core" "$TA/generator" "$ST/glb" "$T/busts/old" > /dev/null
  run "$REAL_PY" "$TA/core/validate_new_assets.py" --portraits "$T/busts/old"
  want_rc 1 "the old framing fails --portraits"; want_out "FAIL bat"; want_out "FAIL fox"; want_out "OK   bear"; want_out "CLIPPED at the"
  unset PYTHONPATH

  echo " - synthetic faults"
  local D="$T/busts/syn"; mkdir -p "$D"
  png_fox_cell "$D/fox.png"; cp "$D/fox.png" "$D/cat.png"; cp "$D/fox.png" "$D/bear.png"; cp "$D/fox.png" "$D/bat.png"; cp "$D/fox.png" "$D/frog.png"
  "$REAL_PY" -I -c "
import sys
from PIL import Image, ImageDraw
d = sys.argv[1]
Image.new('RGBA', (128, 128), (0, 0, 0, 0)).save(d + '/cat.png')                                   # wrong size
Image.new('RGBA', (256, 256), (0, 0, 0, 0)).save(d + '/bear.png')                                  # blank
im = Image.open(d + '/bat.png'); ImageDraw.Draw(im).rectangle((0, 100, 5, 150), fill=(255, 0, 0, 255)); im.save(d + '/bat.png')   # left edge
im = Image.open(d + '/frog.png'); ImageDraw.Draw(im).rectangle((100, 0, 150, 5), fill=(255, 0, 0, 255)); im.save(d + '/frog.png') # top edge
im = Image.open(d + '/fox.png'); ImageDraw.Draw(im).rectangle((100, 250, 150, 255), fill=(255, 0, 0, 255)); im.save(d + '/fox.png')  # bottom edge
" "$D"
  run "$REAL_PY" "$TA/core/validate_new_assets.py" --portraits "$D"
  want_rc 1 "synthetic busts"; want_out "FAIL cat"; want_out "FAIL bear"; want_out "FAIL bat"; want_out "FAIL frog"; want_out "OK   fox"
  no_out "Traceback"
  cp "$D/fox.png" "$D/notapackid.png"
  run "$REAL_PY" "$TA/core/validate_new_assets.py" --portraits "$D" notapackid
  want_rc 1 "an id that is not a pack id"; want_out "not one of the 12 pack ids"
}

# ================================================================================================================================
echo "art pipeline selftest - sandbox $T - python $("$REAL_PY" -c 'import sys;print(sys.version.split()[0])')"
for s in $SELECTED; do "sec_$s"; done
echo
echo "selftest: $PASS passed, $FAILS failed ($SELECTED )"
[ "$FAILS" = 0 ]
