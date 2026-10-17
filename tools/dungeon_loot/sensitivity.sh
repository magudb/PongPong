#!/usr/bin/env bash
# Alternative progression assumptions are diagnostic; only the named plan has P1 budgets.
set -eu
cd "$(dirname "$0")/../.."
python3 tools/dungeon_loot/run.py --pace plan "$@"
exec python3 tools/dungeon_loot/run.py --pace de30 "$@"
