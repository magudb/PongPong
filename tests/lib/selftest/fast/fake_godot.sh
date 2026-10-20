#!/usr/bin/env bash
# Stand-in for the Godot binary (GODOT=tests/lib/selftest/fast/fake_godot.sh): prints the command line the wrapper built, one
# `FAKE_ARG <n> <arg>` line per argument, and a harness result line, so tools/dev/selftest_harness.sh can prove which arguments
# tests/run_playtest.sh passes to the engine (no engine, no window, no timing).
# FAKE_GODOT_KILL=1: the stand-in SIGKILLs itself after printing its arguments (an engine killed from outside, e.g. out of memory).
# FAKE_GODOT_MARK=TEXT: it also prints `FAKE_MARK TEXT` (which run a log belongs to); FAKE_GODOT_SLEEP=N: it waits N seconds
# before the result line (a run that can be interrupted); FAKE_GODOT_NO_RESULT=1: it exits 0 without a result line (a crash
# that the engine's exit code does not show).
i=0
for a in "$@"; do
	i=$((i + 1))
	echo "FAKE_ARG $i $a"
done
[ -n "${FAKE_GODOT_MARK:-}" ] && echo "FAKE_MARK $FAKE_GODOT_MARK"
[ "${FAKE_GODOT_KILL:-0}" = 1 ] && kill -9 $$
[ -n "${FAKE_GODOT_SLEEP:-}" ] && sleep "$FAKE_GODOT_SLEEP"
[ "${FAKE_GODOT_NO_RESULT:-0}" = 1 ] && exit 0
echo "PLAYTEST PASS (0 checks in 0 sections, fake engine)"
