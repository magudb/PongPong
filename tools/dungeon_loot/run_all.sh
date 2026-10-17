#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/../.."
python3 tools/dungeon_loot/mc.py bands --n 1000
python3 tools/dungeon_loot/mc.py life --n 200
exec tools/dungeon_loot/run.sh --check "$@"
