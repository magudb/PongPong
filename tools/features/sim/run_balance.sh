#!/bin/bash
# Reruns the balance model against the repo as it is NOW (prices of P12, quests of P13 once they landed).  Not a gate: the sim is a model with assumed income, not a playtest.
#   tools/features/sim/run_balance.sh [--quests repo|stage] [--no-validate]
# Needs the dumps of tools/features/validate/run_validate.sh (real Lua 5.4 evaluation of the stage tree and of the repo); runs it first unless --no-validate.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
FEAT="$(cd "$HERE/.." && pwd)"
QUESTS=repo; VAL=1
while [ $# -gt 0 ]; do
  case "$1" in
    --quests) QUESTS="${2:-repo}"; shift 2 ;;
    --no-validate) VAL=0; shift ;;
    *) echo "run_balance: unknown argument $1" >&2; exit 2 ;;
  esac
done
REPO="$(cd "$FEAT/../.." && pwd)"
PY="${ARTPY:-$REPO/tools/art/.venv/bin/python}"; [ -x "$PY" ] || PY=python3
if [ "$VAL" = 1 ]; then "$FEAT/validate/run_validate.sh" --stage f1 > "$FEAT/reports/last_validate.log" 2>&1 || echo "run_balance: the validator is red (see tools/features/reports/last_validate.log); the dumps are still written and used"; fi
exec "$PY" -I "$HERE/balance_sim.py" --quests "$QUESTS" --out "$FEAT/reports/balance_output_$QUESTS.txt" --json "$FEAT/reports/balance_summary_$QUESTS.json"
