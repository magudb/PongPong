#!/usr/bin/env bash
# Headless playthrough: tests/run_playtest.sh [--character=animal|fairy|hobbit] [--scenario=flow] [--play-seconds=3]
# Exit code 0 only if every check passes and the engine logged no errors.
cd "$(dirname "$0")/.." || exit 2
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
timeout 180 "$GODOT" --headless --path . -s res://tests/playtest.gd -- "$@" 2>&1 | grep -v '^\[' 
exit "${PIPESTATUS[0]}"
