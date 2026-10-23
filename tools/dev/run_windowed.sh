#!/usr/bin/env bash
# Windowed playtest run (plan R.6): opens a REAL 1280x720 window, runs only the sections that define
# run_windowed(t), asserts pixels and writes PNGs. Meant for the lead / the user at wave boundaries (about 1 s per
# check); agents never open windows on their own.
#
#   tools/dev/run_windowed.sh [--only=area,player] [--out=DIR] [--character=fairy] [--list]
#
# Takes the one-window lock (two windows on one screen make both runs unreliable; tools/dev/lock.sh), then runs
# tests/run_playtest.sh --windowed with the same arguments. Screenshots default to
# $TMPDIR/traetoppen-shots/<timestamp>/ (the path is printed); open the PNGs and LOOK at them.
#   WINDOWED_LOCK=<file>       lock file (default $TMPDIR/traetoppen-windowed.lock)
#   WINDOWED_LOCK_HELD=1       the caller already holds a window lock (e.g. the lead's windowed.sh): do not lock again
#   GODOT=<binary>             engine binary
cd "$(dirname "$0")/../.." || exit 2
# shellcheck source=tools/dev/lock.sh
. tools/dev/lock.sh
TMP_BASE="${TMPDIR:-/tmp}"
LOCK="${WINDOWED_LOCK:-${TMP_BASE%/}/traetoppen-windowed.lock}"
if [ "${WINDOWED_LOCK_HELD:-0}" = 1 ]; then
	exec tests/run_playtest.sh --windowed "$@"
fi
echo "run_windowed: waiting for the window lock ($LOCK), then opening a 1280x720 window ..."
with_lock "$LOCK" tests/run_playtest.sh --windowed "$@"
