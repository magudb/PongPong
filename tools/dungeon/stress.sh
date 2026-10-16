#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
count="${1:-834}"
if [[ $# -gt 0 ]]; then shift; fi
first=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --first) first="$2"; shift 2 ;;
    *) echo "usage: tools/dungeon/stress.sh [count] [--first index]" >&2; exit 2 ;;
  esac
done
python3 tools/dungeon/run.py stress "count=$count" "first=$first" det=1
