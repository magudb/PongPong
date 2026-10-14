#!/usr/bin/env bash
# tools/dev/play.sh - play the game in a real window (no editor needed).
#
#   tools/dev/play.sh                 play with your normal Godot user profile (settings and saves persist)
#   tools/dev/play.sh --throwaway     play with a temporary profile that is deleted afterwards (saves are not kept)
#   tools/dev/play.sh --windowed-size=1920x1080   any other argument goes straight to Godot
#
# Takes the same one-window lock as the test runs, so it waits when an automated check has a window open.
# The project is imported first when needed. Close the Godot EDITOR before playing the same folder (both write .godot).
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
[ -x "$GODOT" ] || { echo "play.sh: Godot not found at $GODOT (set GODOT=...)" >&2; exit 2; }
THROWAWAY=0; ARGS=()
for a in "$@"; do case "$a" in --throwaway) THROWAWAY=1 ;; *) ARGS+=("$a") ;; esac; done
if [ ! -d .godot ]; then
	echo "play.sh: first start, importing the project (about a minute) ..."
	"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
	"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fi
LOCK="${WINDOWED_LOCK:-${TMPDIR%/}/traetoppen-windowed.lock}"
if [ "$THROWAWAY" = 1 ]; then
	HOME_DIR="$(mktemp -d "${TMPDIR%/}/traetoppen-play.XXXXXX")"
	trap 'rm -rf "$HOME_DIR"' EXIT
	HOME="$HOME_DIR" /usr/bin/lockf -k "$LOCK" "$GODOT" --path . --resolution 1280x720 ${ARGS[@]+"${ARGS[@]}"}
else
	/usr/bin/lockf -k "$LOCK" "$GODOT" --path . --resolution 1280x720 ${ARGS[@]+"${ARGS[@]}"}
fi
