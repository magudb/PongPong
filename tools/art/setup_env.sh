#!/usr/bin/env bash
# tools/art/setup_env.sh - create tools/art/.venv: Python 3.12 + numpy scipy Pillow vtk, versions pinned in core/requirements.txt
# (the verified art-spike environment).  Idempotent: an existing healthy venv is only re-checked.  Takes about 2 minutes the first time.
#
#   tools/art/setup_env.sh            create or repair the venv, verify the imports, print the interpreter
#   tools/art/setup_env.sh --check    verify only (exit 1 when the venv is missing or wrong), install nothing
#   tools/art/setup_env.sh --force    delete the venv and build it again
#
# Interpreter lookup (first hit that is Python 3.12 with venv+ensurepip and not on a volatile tmp path):
#   $TT_PYTHON312, /opt/homebrew/bin/python3.12, /usr/local/bin/python3.12, python3.12 on PATH, `uv python find 3.12`.
# No Python 3.12?   macOS: brew install python@3.12
#
# Then: export PY="$PWD/tools/art/.venv/bin/python"   (the scripts also find .venv by themselves)
# zsh note: macOS zsh does not word-split unquoted variables - this file is bash on purpose, call it as a program.
set -euo pipefail

ART="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$ART/.venv"
REQ="$ART/core/requirements.txt"
FORCE=0
CHECK=0
for a in "$@"; do
  case "$a" in
    --force) FORCE=1 ;;
    --check) CHECK=1 ;;
    -h|--help) sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $a (try --help)" >&2; exit 2 ;;
  esac
done

is_good_python() {   # $1 = interpreter path
  local p="$1" real
  [ -n "$p" ] && [ -x "$p" ] || return 1
  case "$("$p" -c 'import sys;print("%d.%d" % sys.version_info[:2])' 2>/dev/null)" in 3.12) ;; *) return 1 ;; esac
  "$p" -c 'import venv, ensurepip' >/dev/null 2>&1 || return 1
  real="$("$p" -c 'import os,sys;print(os.path.realpath(sys.executable))' 2>/dev/null)" || return 1
  case "$real" in /tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*) return 1 ;; esac   # a venv built on a scratch interpreter breaks when the scratch is cleaned
  return 0
}

find_python() {
  local c
  for c in "${TT_PYTHON312:-}" /opt/homebrew/bin/python3.12 /usr/local/bin/python3.12 "$(command -v python3.12 || true)" "$( (command -v uv >/dev/null 2>&1 && uv python find 3.12 2>/dev/null) || true)"; do
    if is_good_python "$c"; then echo "$c"; return 0; fi
  done
  return 1
}

verify_env() {   # prints the report, returns 0 when the venv imports everything at the pinned versions
  [ -x "$VENV/bin/python" ] || { echo "no venv at $VENV" >&2; return 1; }
  "$VENV/bin/python" -I - "$REQ" <<'PYEOF'
import sys, re, importlib.metadata as md
pins = {}
for line in open(sys.argv[1]):
    line = line.split('#')[0].strip()
    m = re.match(r'([A-Za-z0-9_.-]+)==(\S+)$', line)
    if m: pins[m.group(1)] = m.group(2)
bad = []
for name, want in pins.items():
    try: got = md.version(name)
    except md.PackageNotFoundError: got = None
    if got != want: bad.append(f'{name}: want {want}, got {got}')
if sys.version_info[:2] != (3, 12): bad.append('python is %d.%d, want 3.12' % sys.version_info[:2])
try:
    import numpy, scipy, PIL, vtk
    from PIL import features
    if not features.check('webp'): bad.append('Pillow was built without WebP')
    vtk.vtkCellArray().ImportLegacyFormat   # API the bakers use (SetCells is deprecated since 9.6)
except Exception as e:
    bad.append(f'import failed: {e!r}')
if bad:
    print('ENV PROBLEMS:'); [print('  -', b) for b in bad]; sys.exit(1)
print('python  :', sys.executable, '(%d.%d.%d)' % sys.version_info[:3])
print('packages:', ', '.join(f'{n} {v}' for n, v in pins.items()), '(Pillow WebP ok, vtk ok)')
PYEOF
}

if [ "$CHECK" = 1 ]; then
  verify_env && exit 0 || { echo "run tools/art/setup_env.sh" >&2; exit 1; }
fi

if [ "$FORCE" = 1 ] && [ -d "$VENV" ]; then rm -rf "$VENV"; fi

if [ -x "$VENV/bin/python" ] && verify_env >/dev/null 2>&1; then
  echo "venv already healthy: $VENV"
else
  PY312="$(find_python)" || { echo "ERROR: no usable Python 3.12 found (need venv + ensurepip, not on a /tmp path). macOS: brew install python@3.12  - or set TT_PYTHON312=/path/to/python3.12" >&2; exit 1; }
  echo "using $PY312 ($("$PY312" --version))"
  rm -rf "$VENV"
  "$PY312" -m venv "$VENV"
  echo "installing pinned packages (numpy scipy Pillow vtk; wheels only) ..."
  "$VENV/bin/python" -m pip install --disable-pip-version-check --progress-bar off --only-binary=:all: -r "$REQ"
fi

verify_env
echo
echo "ready.  export PY=\"$VENV/bin/python\""
