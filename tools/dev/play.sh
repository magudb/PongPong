#!/usr/bin/env bash
# tools/dev/play.sh - play the game in a real window (no editor needed).
#
#   tools/dev/play.sh                 play with your normal Godot user profile (settings and saves persist)
#   tools/dev/play.sh --throwaway     play with a temporary profile that is deleted afterwards (saves are not kept)
#   tools/dev/play.sh --windowed-size=1920x1080   any other argument goes straight to Godot
#
# Takes the same one-window lock as the test runs, so it waits when an automated check has a window open, and the run lock of
# this checkout (tools/dev/lock.sh), so it does not start while tests/run_playtest.sh runs in the same folder (both write .godot).
# The project is imported first when needed. Close the Godot EDITOR before playing the same folder (both write .godot).
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$(pwd)"
# shellcheck source=tools/dev/lock.sh
. tools/dev/lock.sh
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
[ -x "$GODOT" ] || { echo "play.sh: Godot not found at $GODOT (set GODOT=...)" >&2; exit 2; }
TMP_BASE="${TMPDIR:-/tmp}"
TMP_BASE="${TMP_BASE%/}"
THROWAWAY=0; ARGS=()
for a in "$@"; do case "$a" in --throwaway) THROWAWAY=1 ;; *) ARGS+=("$a") ;; esac; done
take_checkout_lock "$ROOT" play.sh || exit 2
HOME_DIR=""
cleanup() {
	release_checkout_lock
	if [ -n "$HOME_DIR" ]; then rm -rf "${HOME_DIR:?}"; fi
}
trap cleanup EXIT
# Import when the cache is missing, and again when a script / shader / .import / asset / localization file is newer than the last import (a new class_name
# script is invisible to the game until the global class cache is rebuilt: the treetop city failed to build with "Identifier CityData not declared" on a
# stale cache). The stamp is the one tests/run_playtest.sh keeps; only an import that succeeded renews it.
IMPORT_STAMP=".godot/playtest_import.stamp"
needs_import() {
	[ -d .godot ] || return 0
	[ -f .godot/global_script_class_cache.cfg ] || return 0
	local ref="$IMPORT_STAMP"
	[ -f "$ref" ] || ref=".godot/global_script_class_cache.cfg"
	[ -n "$(find . \( -path ./.godot -o -path ./.git -o -path ./docs -o -path ./tools/art \) -prune -o -type f \( -name '*.gd' -o -name '*.gdshader' -o -name '*.import' -o -name 'project.godot' \) -newer "$ref" -print 2>/dev/null | head -1)" ] && return 0
	[ -n "$(find assets localization -type f -newer "$ref" -print 2>/dev/null | head -1)" ]
}
if needs_import; then
	passes=1
	[ -d .godot ] || passes=2
	IMPORT_LOG="$(mktemp "$TMP_BASE/traetoppen-play-import.XXXXXX")"
	echo "play.sh: importing the project (about a minute) ..."
	for _ in $(seq 1 "$passes"); do
		if ! "$GODOT" --headless --path . --import >"$IMPORT_LOG" 2>&1; then
			echo "play.sh: godot --import failed; the cache stays marked as stale, so the next start imports again:" >&2
			tail -20 "$IMPORT_LOG" >&2
			echo "play.sh: full import log: $IMPORT_LOG" >&2
			exit 2
		fi
	done
	rm -f "$IMPORT_LOG"
	mkdir -p .godot
	touch "$IMPORT_STAMP"
fi
LOCK="${WINDOWED_LOCK:-$TMP_BASE/traetoppen-windowed.lock}"
if [ "$THROWAWAY" = 1 ]; then
	HOME_DIR="$(mktemp -d "$TMP_BASE/traetoppen-play.XXXXXX")"
	HOME="$HOME_DIR" with_lock "$LOCK" "$GODOT" --path . --resolution 1280x720 ${ARGS[@]+"${ARGS[@]}"}
else
	with_lock "$LOCK" "$GODOT" --path . --resolution 1280x720 ${ARGS[@]+"${ARGS[@]}"}
fi
