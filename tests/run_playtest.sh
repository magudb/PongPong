#!/usr/bin/env bash
# Playtest runner (plan 8.1, 7.2, Appendix C).
#
#   tests/run_playtest.sh [--character=animal|fairy|hobbit|ghost] [--only=core,farm] [--list] [--fast]
#   tests/run_playtest.sh --windowed [--only=area] [--out=DIR]      real 1280x720 window, run_windowed(t) sections only
#                                                                    (use tools/dev/run_windowed.sh: it takes the one-window lock)
#   tests/run_playtest.sh --strict --no-boot --only=farm             the inner loop while working on one section (seconds, no boot stage)
#
# The gate that keeps `main` green is the CI split (.github/workflows/playtest.yml: 4 heroes x 4 shards, simulations with
# --fast), and tools/dev/ci_local.sh runs exactly that locally. A plain run of every section in one process is not the gate:
# it takes well over an hour for one hero.
#
# Harness options (passed through unchanged, see the header of tests/playtest.gd): --character= --only= --list
#   --windowed --out= --no-boot --boot --play-seconds=N --section-timeout=N --max-seconds=N --report=FILE --seed=N
#   --verbose --strict (ignore tests/lib/known_issues.txt) --known-issues=FILE --sections-dir=PATH
#   --not-judged-exit=N (exit code of a pass with timings NOT JUDGED on an overloaded machine, default 0)
# Wrapper options:
#   --fast             headless runs only: pass `--fixed-fps 60` to Godot (GODOT_EXTRA_ARGS), so physics and process frames run
#                      back to back instead of waiting for the wall clock: a 5.3 game-second real-input walk costs 0.05 s instead
#                      of 3-5 s (measured). Game time, not wall time, is what the sections see; wall-clock budgets only get easier.
#                      `Engine.time_scale` does NOT do this (physics ticks stay real-time). A windowed run ignores --fast (a real
#                      window is watched in real time); an own `--fixed-fps` in GODOT_EXTRA_ARGS is left as it is. For iterating on a
#                      section, not the gate: a section that times an animation with the wall clock instead of t.game_seconds() fails
#                      under it (see docs/DEVELOPMENT.md); ordinary sections run without it in the gate (tools/dev/ci_local.sh).
#   --no-import        skip the "is the .godot cache stale?" check (also PLAYTEST_NO_IMPORT=1)
#   --timeout=SECS     kill the run after SECS (default 900 with --only / --list / --sections-dir / --windowed, 5400 for a
#                      run of every section)
#   --keep-home        keep the throwaway HOME directory and print its path
#   GODOT=/path/to/godot   engine binary (default /Applications/Godot.app/Contents/MacOS/Godot)
#   GODOT_EXTRA_ARGS="..." more engine arguments, placed before `-s res://tests/playtest.gd` (--fast adds `--fixed-fps 60` to them);
#                      split on whitespace, never glob-expanded
#
# What it does besides starting Godot:
#   * refuses to start while another run (or tools/dev/play.sh) uses the same checkout: both would write .godot (exit 2; the
#     lock lives under $TMPDIR, see tools/dev/lock.sh, so an APFS clone of a busy checkout does not inherit it);
#   * runs `godot --headless --path . --import` once when any .gd/.gdshader/.import/asset file is newer than the last
#     import (new class_name scripts are invisible until the global class cache is rebuilt) and twice when .godot is
#     missing (the first run prints the theme font errors once). Deliberately WITHOUT --quit: `--import --quit` leaves
#     before the editor scan has written the .gd.uid files (measured in 4.7.2), plain `--import` exits by itself;
#   * runs tools/import/write_import_stubs.py --check when files under assets/ changed (no re-import pass);
#   * runs Godot with a throwaway HOME so saves and settings never touch the real user:// directory; the run's output is
#     logged there (the verdict reads that log) and copied to .godot/playtest_last.log when the run ends, also when it was
#     interrupted; the previous run's copy is removed when Godot starts;
#   * fails on engine ERROR/WARNING lines printed before the harness started (autoload and project load errors the
#     in-process Logger cannot see);
#   * exits 0 only when the harness printed its PASS line: 1 failed checks/engine messages, 2 usage or infrastructure
#     (import/stub check/no result line/checkout busy), 124 timeout, 137 Godot was killed before the timeout (SIGKILL from
#     outside: usually the out-of-memory killer), and the --not-judged-exit code for a pass with timings NOT JUDGED.
#
# Exit code != 0 on any failed check, engine error or warning (plan 8.1 negative test).

cd "$(dirname "$0")/.." || exit 2
ROOT="$(pwd)"
# shellcheck source=tools/dev/lock.sh
. tools/dev/lock.sh
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
TIMEOUT_S=""
PARTIAL=0
NO_IMPORT="${PLAYTEST_NO_IMPORT:-0}"
KEEP_HOME=0
WINDOWED=0
HAS_OUT=0
LIST=0
FAST=0
ARGS=()
for a in "$@"; do
	case "$a" in
		--list|--help|-h) LIST=1; PARTIAL=1; ARGS+=("$a") ;;
		--only=*|--sections-dir=*) PARTIAL=1; ARGS+=("$a") ;;
		--fast) FAST=1 ;;
		--no-import) NO_IMPORT=1 ;;
		--keep-home) KEEP_HOME=1 ;;
		--timeout=*) TIMEOUT_S="${a#--timeout=}" ;;
		--windowed) WINDOWED=1; PARTIAL=1; ARGS+=("$a") ;;
		--out=*) HAS_OUT=1; ARGS+=("$a") ;;
		*) ARGS+=("$a") ;;
	esac
done
# a run of every section in one process takes well over an hour (the gate splits it, see the header)
[ -n "$TIMEOUT_S" ] || { [ "$PARTIAL" = 1 ] && TIMEOUT_S=900 || TIMEOUT_S=5400; }
case "$TIMEOUT_S" in ''|*[!0-9]*) echo "run_playtest: --timeout needs whole seconds (got '$TIMEOUT_S')" >&2; exit 2 ;; esac

if [ ! -x "$GODOT" ]; then
	echo "run_playtest: Godot binary not found at $GODOT (set GODOT=...)" >&2
	exit 2
fi

TMP_BASE="${TMPDIR:-/tmp}"
TMP_BASE="${TMP_BASE%/}"
take_checkout_lock "$ROOT" run_playtest || exit 2
PLAY_HOME="$(mktemp -d "$TMP_BASE/traetoppen-playtest.XXXXXX")" || { release_checkout_lock; exit 2; }
LOG="$ROOT/.godot/playtest_last.log"      # a copy of RUN_LOG, written when the run ends (also an interrupted one)
RUN_LOG="$PLAY_HOME/playtest.log"         # the run's own log: the verdict below reads this one
cleanup() {
	if [ -f "$RUN_LOG" ] && ! { cp "$RUN_LOG" "$LOG.tmp" 2>/dev/null && mv -f "$LOG.tmp" "$LOG"; }; then
		rm -f "$LOG.tmp"
		echo "run_playtest: could not copy the run's log to $LOG" >&2
	fi
	release_checkout_lock
	if [ "$KEEP_HOME" = 1 ]; then
		echo "run_playtest: throwaway HOME kept at $PLAY_HOME"
	else
		rm -rf "${PLAY_HOME:?}"
	fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

run_timeout() {
	local secs="$1"
	shift
	# -k: a Godot that is stuck in a synchronous loop ignores SIGTERM, so it gets SIGKILLed 10 s later
	if command -v timeout >/dev/null 2>&1; then
		timeout -k 10 "$secs" "$@"
	elif command -v gtimeout >/dev/null 2>&1; then
		gtimeout -k 10 "$secs" "$@"
	else
		perl -e 'alarm shift; exec @ARGV' "$secs" "$@"
	fi
}

# ---------------------------------------------------------------- 1. import cache

IMPORT_STAMP=".godot/playtest_import.stamp"
needs_import() {
	[ -d .godot ] || return 0
	[ -f .godot/global_script_class_cache.cfg ] || return 0
	local ref="$IMPORT_STAMP"
	[ -f "$ref" ] || ref=".godot/global_script_class_cache.cfg"
	local newer
	newer="$(find . \( -path ./.godot -o -path ./.git -o -path ./docs -o -path ./tools/art -o -path ./.selftest \) -prune -o \
		-type f \( -name '*.gd' -o -name '*.gdshader' -o -name '*.import' -o -name 'project.godot' \) -newer "$ref" -print 2>/dev/null | head -1)"
	[ -n "$newer" ] && return 0
	newer="$(find assets localization -type f -newer "$ref" -print 2>/dev/null | head -1)"
	[ -n "$newer" ] && return 0
	return 1
}

run_import() {
	local passes=1
	[ -d .godot ] || passes=2
	local log="$PLAY_HOME/import.log"
	local i
	for i in $(seq 1 $passes); do
		echo "run_playtest: importing project (pass $i of $passes) ..."
		if ! HOME="$PLAY_HOME" run_timeout 600 "$GODOT" --headless --path . --import >"$log" 2>&1; then
			echo "run_playtest: godot --import failed:" >&2
			tail -20 "$log" >&2
			return 1
		fi
	done
	mkdir -p .godot
	touch "$IMPORT_STAMP"
	return 0
}

if [ "$NO_IMPORT" != 1 ] && needs_import; then
	run_import || exit 2
fi

# ---------------------------------------------------------------- 2. import stubs (assets changed)

STUB_SCRIPT="tools/import/write_import_stubs.py"
ASSET_STAMP=".godot/playtest_assets.stamp"
if [ "$NO_IMPORT" != 1 ] && [ -f "$STUB_SCRIPT" ] && [ -d assets ]; then
	if [ ! -f "$ASSET_STAMP" ] || [ -n "$(find assets -type f -newer "$ASSET_STAMP" -print 2>/dev/null | head -1)" ]; then
		PY="tools/art/.venv/bin/python"
		[ -x "$PY" ] || PY="python3"
		echo "run_playtest: assets changed, running $STUB_SCRIPT --check"
		if ! "$PY" "$STUB_SCRIPT" --check; then
			echo "run_playtest: import stub check failed (see above)" >&2
			exit 2
		fi
		mkdir -p .godot
		touch "$ASSET_STAMP"
	fi
fi

# ---------------------------------------------------------------- 3. the run

mkdir -p .godot
rm -f "$LOG"                              # never let an older run's log stand in for this one
HARNESS_MAX=$((TIMEOUT_S > 40 ? TIMEOUT_S - 15 : TIMEOUT_S))
GODOT_ARGS=(--path .)
if [ "$WINDOWED" = 1 ] && [ "$LIST" = 0 ]; then
	# Xvfb/Mesa cannot enable V-Sync. Disable it before creating the window,
	# rather than emitting an engine warning before the harness can start.
	GODOT_ARGS+=(--resolution 1280x720 --disable-vsync)
	if [ "$HAS_OUT" = 0 ]; then
		OUT_DIR="$TMP_BASE/traetoppen-shots/$(date +%Y%m%d-%H%M%S)"
		ARGS+=("--out=$OUT_DIR")
		echo "run_playtest: screenshots go to $OUT_DIR"
	fi
else
	GODOT_ARGS+=(--headless)
fi
if [ "$FAST" = 1 ]; then
	# --fast: fixed 60 fps = every frame advances game time by 1/60 s and is not paced by the wall clock. Not for a real window.
	if [ "$WINDOWED" = 1 ] && [ "$LIST" = 0 ]; then
		echo "run_playtest: --fast is ignored in a windowed run (a window runs in real time)"
	else
		case " ${GODOT_EXTRA_ARGS:-} " in
			*" --fixed-fps"*) ;;
			*) GODOT_EXTRA_ARGS="--fixed-fps 60${GODOT_EXTRA_ARGS:+ $GODOT_EXTRA_ARGS}" ;;
		esac
		ARGS+=("--fast")
	fi
fi
# split on whitespace without pathname expansion (an argument such as `--log-file=*.log` stays as it is)
EXTRA=()
if [ -n "${GODOT_EXTRA_ARGS:-}" ]; then
	read -r -a EXTRA <<<"$GODOT_EXTRA_ARGS"
fi
GODOT_ARGS+=(${EXTRA[@]+"${EXTRA[@]}"} -s res://tests/playtest.gd -- "--max-seconds=$HARNESS_MAX" ${ARGS[@]+"${ARGS[@]}"})

T_START=$(date +%s)
HOME="$PLAY_HOME" PLAYTEST_ISOLATED=1 run_timeout "$TIMEOUT_S" "$GODOT" "${GODOT_ARGS[@]}" 2>&1 | tee "$RUN_LOG"
RC="${PIPESTATUS[0]}"
ELAPSED=$(( $(date +%s) - T_START ))

# ---------------------------------------------------------------- 4. verdict

# 124: timeout(1) stopped Godot; 142: the perl fallback's SIGALRM; 137: SIGKILL, from timeout -k (a Godot that ignored SIGTERM)
# when the time was up, otherwise from outside (the out-of-memory killer, a kill -9)
if [ "$RC" = 124 ] || [ "$RC" = 142 ] || { [ "$RC" = 137 ] && [ "$ELAPSED" -ge "$TIMEOUT_S" ]; }; then
	echo "run_playtest: TIMEOUT after ${TIMEOUT_S}s, Godot was stopped (log: $LOG)" >&2
	exit 124
fi
if [ "$RC" = 137 ]; then
	echo "run_playtest: Godot was KILLED (SIGKILL) after ${ELAPSED}s, before the ${TIMEOUT_S}s timeout: out of memory or killed from outside (log: $LOG)" >&2
	exit 137
fi

# engine errors/warnings printed before the harness started (autoload / project load): the in-process Logger is not
# registered yet, so they are only visible in the raw output
BOOT_ERRORS="$(awk '/^PLAYTEST (start|list|help|usage)/{exit} {print}' "$RUN_LOG" | grep -E '^(SCRIPT ERROR|ERROR|WARNING|USER ERROR|USER WARNING|SHADER ERROR):' || true)"
if [ -n "$BOOT_ERRORS" ]; then
	echo "run_playtest: FAIL - engine messages before the harness started (project load / autoloads):" >&2
	echo "$BOOT_ERRORS" >&2
	[ "$RC" = 0 ] && RC=1
fi

# The logger is gone when the tree/resources shut down. Engine messages after
# the verdict still fail, including leaked ObjectDB/RID diagnostics at exit.
SHUTDOWN_ERRORS="$(awk '/^PLAYTEST (PASS|FAIL|list end|help|usage)/ {after=1; tail=""; next} after {tail=tail $0 ORS} END {printf "%s",tail}' "$RUN_LOG" | grep -E '^(SCRIPT ERROR|ERROR|WARNING|USER ERROR|USER WARNING|SHADER ERROR):' || true)"
if [ -n "$SHUTDOWN_ERRORS" ]; then
	echo "run_playtest: FAIL - engine messages after the harness result (shutdown):" >&2
	echo "$SHUTDOWN_ERRORS" >&2
	[ "$RC" = 0 ] && RC=1
fi

if ! grep -qE '^PLAYTEST (PASS|FAIL|list end|help)' "$RUN_LOG" && ! grep -qE '^PLAYTEST usage error' "$RUN_LOG"; then
	echo "run_playtest: the harness printed no result line (it did not compile or crashed; log: $LOG)" >&2
	[ "$RC" = 0 ] && RC=2
fi
exit "$RC"
