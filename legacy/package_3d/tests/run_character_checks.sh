#!/bin/sh
# Read-only checks except Godot's normal .godot import cache. No save files are written.
set -eu
PROJECT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT=${GODOT_BIN:-godot}
if ! command -v "$GODOT" >/dev/null 2>&1; then
    echo "Set GODOT_BIN to the Godot 4.7 executable." >&2
    exit 127
fi
printf 'Testing with: '
"$GODOT" --version
"$GODOT" --headless --path "$PROJECT" --editor --import
"$GODOT" --headless --path "$PROJECT" --script res://tests/character_assets.gd
