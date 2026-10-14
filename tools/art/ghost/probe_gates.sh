#!/usr/bin/env bash
# tools/art/ghost/probe_gates.sh - MUTATION PROBES: proves that the cast gates of the ghost have teeth on REAL bakes (about 75 s wall).
#
#   tools/art/ghost/probe_gates.sh
#
# Four mutants of ghost_model.py, each ONE change, built through the real pipeline (produce_all.sh --stage-only, into tools/art/_stage/ghost_probe, gitignored) and measured:
#   hookleak   the glide hook acts on EVERY model            -> check_hook.py must exit 1 (the fox, bat and fairy GLBs change)
#   hemground  the bell stands ON the ground (0.11 m lower)  -> measure_ghost.py --check must exit 1 (the feet line leaves the window 197 .. 216: measured 219.9 in the walk frames)
#   greenbu    Bu's sheet is green                           -> measure_ghost.py --check must exit 1 (palette dE00 28 > 6)
#   splitsil   Hviske's hem has 6 scallops instead of 5      -> measure_ghost.py --check must exit 1 (2.4 % of the figure pixels differ, below the neck line: A2 could not share the layers)
# Exit 0 only when every mutant is caught.  Nothing outside tools/art/_stage is written (the mutants are copies of two files); the shipped sheets are never touched.
# Measured 2026-10-14: all four caught.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ART="$(cd "$HERE/.." && pwd)"
PY="${PY:-$ART/.venv/bin/python}"
[ -x "$PY" ] || { echo "probe_gates: $PY not found (tools/art/setup_env.sh)" >&2; exit 2; }
WORK="$ART/_stage/ghost_probe"
rm -rf "$WORK"; mkdir -p "$WORK"
FAILED=0

mutant() {   # name from to  (one replacement in a copy of ghost_model.py)
  local name="$1" from="$2" to="$3" dir="$WORK/$1/shim"
  mkdir -p "$dir"; cp "$HERE/ghost_model.py" "$HERE/traetoppen_additions.py" "$dir/"
  "$PY" -I - "$dir/ghost_model.py" "$from" "$to" <<'PYEOF'
import sys
p, a, b = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
assert a in s, 'mutation pattern not found (ghost_model.py changed?): ' + a
open(p, 'w').write(s.replace(a, b, 1))
PYEOF
}

bake() {     # name -> stages the mutant through produce_all.sh with the mutant FIRST on PYTHONPATH
  PYTHONPATH="$WORK/$1/shim" "$ART/produce_all.sh" "$WORK/$1/stage" --only=characters --stage-only ghost_bu ghost_hviske > "$WORK/$1/produce.log" 2>&1
}

expect_fail() {  # name label cmd...
  local name="$1" label="$2"; shift 2
  if "$@" > "$WORK/$name/gate.log" 2>&1; then
    echo "NOT CAUGHT  $name: $label exited 0"; FAILED=$((FAILED + 1))
  else
    echo "caught      $name: $label -> $(tail -1 "$WORK/$name/gate.log" | cut -c1-170)"
  fi
}

mutant hookleak "return getattr(m, 'name', None) == FAMILY" "return True"
expect_fail hookleak "check_hook.py" "$PY" -I "$HERE/check_hook.py" --shim-dir "$WORK/hookleak/shim"

mutant hemground "ys = [1.16, 1.02, .90, .73, .58, .48, .41]" "ys = [1.16, 1.02, .90, .73, .58, .48 - .11, .41 - .11]"
bake hemground || { echo "BAKE FAILED hemground: see $WORK/hemground/produce.log"; FAILED=$((FAILED + 1)); }
expect_fail hemground "measure_ghost.py --check" "$PY" -I "$HERE/measure_ghost.py" --check --root "$WORK/hemground/stage/assets/isometric_characters"

mutant greenbu "PALETTES[FAMILY] = dict(body='E6EFFF'" "PALETTES[FAMILY] = dict(body='9FD0A0'"
bake greenbu || { echo "BAKE FAILED greenbu: see $WORK/greenbu/produce.log"; FAILED=$((FAILED + 1)); }
expect_fail greenbu "measure_ghost.py --check" "$PY" -I "$HERE/measure_ghost.py" --check --root "$WORK/greenbu/stage/assets/isometric_characters"

mutant splitsil "    LOBES, DROP = 5, .13" "    LOBES, DROP = (6 if hero == 'hviske' else 5), .13"
bake splitsil || { echo "BAKE FAILED splitsil: see $WORK/splitsil/produce.log"; FAILED=$((FAILED + 1)); }
expect_fail splitsil "measure_ghost.py --check" "$PY" -I "$HERE/measure_ghost.py" --check --root "$WORK/splitsil/stage/assets/isometric_characters"

rm -rf "$WORK"
if [ "$FAILED" = 0 ]; then echo "probe_gates: all four mutants caught"; exit 0; fi
echo "probe_gates: $FAILED mutant(s) NOT caught" >&2; exit 1
