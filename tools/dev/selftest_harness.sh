#!/usr/bin/env bash
# Self-test of the playtest harness itself (plan P09 task 5 and addendum 4.4 amendment 1): the negative tests.
#
#   tools/dev/selftest_harness.sh [--all-characters] [--with-window] [--with-slow]
#
# Runs tests/run_playtest.sh against the fixture sections in tests/lib/selftest/<case>/ (via --sections-dir) and
# checks exit codes and output:
#   list / pass            discovery output, every helper of `t` on its happy path, --only selection
#   failed check           exit 1, listed as <section>.<label>
#   injected error         exit 1                        (NEGATIVE: push_error)
#   injected warning       exit 1                        (NEGATIVE: warnings fail too)
#   script runtime error   exit 1, no hang, later section still runs
#   allow()                expected warnings/errors pass; anything else still fails; scoped to the section
#   uncompilable section   exit 1 FAST, nothing else ran; with --only=<other> it is reported but not fatal
#   section timeout        exit 1 after the section's TIMEOUT_S, not after minutes; --max-seconds stops a whole run;
#                          a Godot stuck in a synchronous loop is killed by the wrapper (exit 124)
#   bad usage              unknown --only name / unknown option -> exit 2
#   --fast (RT8)           the wrapper turns --fast into `--fixed-fps 60` ahead of the script and never hands --fast to the harness
#                          (a stand-in engine prints its argv), a windowed run ignores it, an own --fixed-fps / other engine argument
#                          is kept; on the real engine 300 physics ticks cost a few ms with it and about 5 s without
#                          (the case harness.fast_flag_forwards_fixed_fps is the verify id of the addendum, RT8); the section and run watchdogs
#                          count WALL-CLOCK time, so a section that waits on the wall clock is not stopped under --fast, a hang still is,
#                          and the UI audit's settle wait (a fade) counts process time (fast_flag_ui_audit_settle_waits_process_time)
#   legacy flow            real main_menu -> character_select -> world boot of the 3D tree, its known failure is reported
#   --with-window          trivial run_windowed section opens a real window (takes the one-window lock; run by lead/user)
#   --with-slow            a 35 s statistical section passes under the default watchdog (plan: sections up to 30 s)
#
# Run it in a test copy (tools/dev/test_in_copy.sh <pkg> --selftest) or any checkout with a Godot import cache;
# it never writes outside tests/lib/selftest, .selftest/ (removed again) and the throwaway directories.

cd "$(dirname "$0")/../.." || exit 2
ROOT="$(pwd)"
ALL_CHARS=0
WITH_WINDOW=0
WITH_SLOW=0
for a in "$@"; do
	case "$a" in
		--all-characters) ALL_CHARS=1 ;;
		--with-window) WITH_WINDOW=1 ;;
		--with-slow) WITH_SLOW=1 ;;
		*) echo "selftest_harness: unknown option $a" >&2; exit 2 ;;
	esac
done

RUN="tests/run_playtest.sh"
ST="tests/lib/selftest"
TMP_BASE="${TMPDIR:-/tmp}"
WORK="$(mktemp -d "${TMP_BASE%/}/traetoppen-selftest.XXXXXX")"
cleanup() { rm -rf "${WORK:?}" "${ROOT:?}/.selftest"; }
trap cleanup EXIT
trap 'exit 130' INT TERM

PASSED=0
FAILED=0
note_ok() { PASSED=$((PASSED + 1)); printf '  ok    %s\n' "$1"; }
note_fail() { FAILED=$((FAILED + 1)); printf '  FAIL  %s\n' "$1"; }

# run_case NAME WANT_RC MAX_SECONDS MUST_MATCH MUST_NOT_MATCH ARGS...   (empty pattern = no condition; WANT_RC "*" = any)
# CASE_RUNNER=<script> run_case ...  runs another wrapper than tests/run_playtest.sh
run_case() {
	local name="$1" want="$2" max="$3" yes="$4" no="$5"
	shift 5
	local log="$WORK/$name.log"
	local t0 t1 rc
	t0=$(date +%s)
	PLAYTEST_NO_IMPORT=1 "${CASE_RUNNER:-$RUN}" "$@" >"$log" 2>&1
	rc=$?
	t1=$(date +%s)
	local secs=$((t1 - t0))
	local problems=""
	[ "$want" = "*" ] || [ "$rc" = "$want" ] || problems="$problems exit=$rc (want $want);"
	[ "$secs" -le "$max" ] || problems="$problems took ${secs}s (max ${max}s);"
	if [ -n "$yes" ] && ! grep -Eq -- "$yes" "$log"; then problems="$problems output lacks /$yes/;"; fi
	if [ -n "$no" ] && grep -Eq -- "$no" "$log"; then problems="$problems output has /$no/;"; fi
	if [ -z "$problems" ]; then
		note_ok "$name (exit $rc, ${secs}s)"
	else
		note_fail "$name:$problems log: $log"
		sed 's/^/        | /' "$log" | tail -25
		cp "$log" "$ROOT/.godot/selftest_$name.log" 2>/dev/null
	fi
}

echo "== harness self-test (log files in $WORK)"
# make sure the import cache is fresh once (cases below skip the check)
"$RUN" --list --sections-dir="$ST/pass" >"$WORK/prep.log" 2>&1 || { echo "selftest_harness: preparation failed"; tail -20 "$WORK/prep.log"; exit 2; }

# The harness fails on ANY engine message, including the ones the project itself prints at boot (autoloads) unless
# tests/lib/known_issues.txt lists them. The self-test must not depend on the state of the tree, so it measures that
# baseline once (a run of the pass fixtures) and expects "pass" cases to show exactly that many boot errors.
"$RUN" --no-import --no-boot --sections-dir="$ST/pass" >"$WORK/baseline.log" 2>&1
BASE_N=$(grep -c '^  ENGINE   \[boot\]' "$WORK/baseline.log")
if [ "$BASE_N" = 0 ]; then PASS_RC=0; else PASS_RC=1; fi
echo "  info  baseline: the tree itself prints $BASE_N engine message(s) at boot (pass cases must show exactly that many and exit $PASS_RC)"
CLEAN="\\(0 failed, [0-9]+ skipped\\), $BASE_N engine error\\(s\\), 0 engine warning\\(s\\), [0-9]+ allowed message\\(s\\), 0 problem"

# ---- discovery and happy path
run_case list 0 30 'a_basics .*\[run\]' '' --list --sections-dir="$ST/pass"
run_case help_exits_zero 0 30 'PLAYTEST help' '' --help
run_case list_windowed_filters_and_opens_no_window 0 30 'PLAYTEST list end: 0 section' 'window ' --list --windowed --sections-dir="$ST/pass"
run_case list_count 0 30 'PLAYTEST list end: 2 section' '' --list --sections-dir="$ST/pass"
run_case pass $PASS_RC 60 "$CLEAN" 'FAIL  |FAILED|PROBLEM' --no-boot --sections-dir="$ST/pass"
run_case pass_order $PASS_RC 60 '== section a_basics' '' --no-boot --sections-dir="$ST/pass"
A_LINE=$(grep -n '== section a_basics' "$WORK/pass_order.log" | head -1 | cut -d: -f1)
B_LINE=$(grep -n '== section second_named' "$WORK/pass_order.log" | head -1 | cut -d: -f1)
if [ -n "$A_LINE" ] && [ -n "$B_LINE" ] && [ "$A_LINE" -lt "$B_LINE" ]; then note_ok "sections run in alphabetical order"; else note_fail "sections did not run in alphabetical order ($A_LINE / $B_LINE)"; fi
run_case only_selects $PASS_RC 60 '== section second_named' '== section a_basics' --no-boot --sections-dir="$ST/pass" --only=second_named
run_case only_by_file_name $PASS_RC 60 '== section a_basics' '== section second_named' --no-boot --sections-dir="$ST/pass" --only=a_basics
run_case report_file $PASS_RC 60 "$CLEAN" '' --no-boot --sections-dir="$ST/pass" --report="$WORK/report.json"
if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert "a_basics" in d["sections"] and d["checks"] > 20 and d["result"] in ("pass","fail")' "$WORK/report.json" 2>/dev/null; then note_ok "report json written and valid"; else note_fail "report json missing or wrong"; fi

# ---- negative tests
run_case many_checks_are_counted_not_flooded 1 60 'more ok lines of many not printed' 'ok line number 1499' --no-boot --sections-dir="$ST/many_checks"
if grep -q '1501 checks (1 failed' "$WORK/many_checks_are_counted_not_flooded.log" && grep -q 'FAILURES-ARE-ALWAYS-PRINTED' "$WORK/many_checks_are_counted_not_flooded.log"; then note_ok "1501 checks counted, the failure among them printed"; else note_fail "check counting with many checks"; fi
run_case verbose_prints_every_ok_line 1 60 'ok line number 1499' '' --no-boot --sections-dir="$ST/many_checks" --verbose
run_case failed_check 1 60 'FAILED   failing\.this_one_fails' '' --no-boot --sections-dir="$ST/fail_check"
run_case injected_error 1 60 'INJECTED-ENGINE-ERROR' '' --no-boot --sections-dir="$ST/inject_error"
run_case injected_warning 1 60 'INJECTED-ENGINE-WARNING.*' '' --no-boot --sections-dir="$ST/inject_warning"
run_case script_error_no_hang 1 60 'Invalid call|nothing|no_such_method' 'AFTER_ERROR_SHOULD_NOT_RUN' --no-boot --sections-dir="$ST/script_error"
run_case script_error_next_runs 1 60 'next_section_still_runs' '' --no-boot --sections-dir="$ST/script_error"
run_case allow_ok $PASS_RC 60 "\\(0 failed, [0-9]+ skipped\\), $BASE_N engine error\\(s\\), 0 engine warning\\(s\\), 4 allowed message\\(s\\), 0 problem" 'FAIL  |FAILED|ENGINE   \[allow\]' --no-boot --sections-dir="$ST/allow_ok"
run_case allow_partial_fails 1 60 'ENGINE .*SOMETHING-ELSE-UNEXPECTED' 'ENGINE .*EXPECTED-ONLY-THIS' --no-boot --sections-dir="$ST/allow_partial"
run_case allow_is_section_scoped 1 60 '\[b_leak\] warning: .*SCOPED-WARNING' '\[a_allows\] warning' --no-boot --sections-dir="$ST/allow_scoped"

# ---- known issues of the tree (tests/lib/known_issues.txt): tolerated but never silent; --strict switches them off
run_case known_issue_is_tolerated_and_listed 0 60 "KNOWN +1x 'KNOWN-ISSUE-SELFTEST'" 'ENGINE   \[' --no-boot --sections-dir="$ST/known" --known-issues="$ST/known/issues.txt"
run_case known_issue_fails_in_strict_mode 1 60 'ENGINE .*KNOWN-ISSUE-SELFTEST' "KNOWN +1x" --no-boot --strict --sections-dir="$ST/known" --known-issues="$ST/known/issues.txt"
run_case known_issue_without_hit_is_reported 0 60 "known issue 'THIS-NEVER-HAPPENS' did not occur: resolved\\? remove it" '' --no-boot --sections-dir="$ST/pass" --known-issues="$ST/known/gone.txt"
if grep -qvE '^[[:space:]]*(#|$)' tests/lib/known_issues.txt; then
	run_case live_known_issues_file_is_reported 0 60 "KNOWN +[0-9]+x|known issue '.*' did not occur" '' --no-boot --sections-dir="$ST/pass"
else
	# the live file lists nothing today (comments only): the run is as clean as the baseline and prints neither a KNOWN line nor a "did not occur" note
	run_case live_known_issues_file_is_empty $PASS_RC 60 "$CLEAN" "KNOWN +[0-9]+x|known issue '.*' did not occur" --no-boot --sections-dir="$ST/pass"
fi

# ---- wrapping external tools that print PASS/FAIL ids (tests/tools/check_project.gd style)
run_case tool_wrapping_helpers $PASS_RC 60 "\\(0 failed, [0-9]+ skipped\\), $BASE_N engine error" 'FAIL  |FAILED|PROBLEM' --no-boot --sections-dir="$ST/tool_ok"
run_case tool_ids_become_checks 1 60 'FAILED   tool_wrap_fail\.fake\.two' 'FAILED   tool_wrap_fail\.fake\.one' --no-boot --sections-dir="$ST/tool_fail"
if grep -q 'FAILED   tool_wrap_fail.tool_exit_code' "$WORK/tool_ids_become_checks.log"; then note_ok "the wrapped tool's non-zero exit code is a failed check"; else note_fail "tool exit code not reported"; fi

# ---- fail fast on a section that does not compile
mkdir -p "$ROOT/.selftest/bad_compile"
cp "$ST/bad_compile/ok_one.gd" "$ROOT/.selftest/bad_compile/ok_one.gd"
cp "$ST/bad_compile/uncompilable.gd.src" "$ROOT/.selftest/bad_compile/uncompilable.gd"
run_case uncompilable_fails_fast 1 15 'does not compile' '== section|== boot' --sections-dir=.selftest/bad_compile
run_case uncompilable_list_flags_it 1 15 'DOES NOT COMPILE' '' --list --sections-dir=.selftest/bad_compile
run_case uncompilable_unselected_is_noted $PASS_RC 30 'does not compile \(not selected' 'PROBLEM|FAILED' --no-boot --sections-dir=.selftest/bad_compile --only=ok_one
rm -rf "${ROOT:?}/.selftest"

# ---- watchdog, usage errors
run_case section_timeout 1 30 'timed out after 2 s' 'never_reached' --no-boot --sections-dir="$ST/hang"
run_case run_watchdog 1 40 'run watchdog: the whole run exceeded 3 s' 'never_reached' --no-boot --sections-dir="$ST/hang_global" --max-seconds=3
run_case wrapper_timeout_kills_a_spinning_godot 124 60 'TIMEOUT after 6s' '' --no-boot --sections-dir="$ST/spin" --timeout=6
run_case unknown_only_is_usage_error 2 30 'unknown section .nope.' '' --no-boot --sections-dir="$ST/pass" --only=nope
run_case unknown_option_is_usage_error 2 30 'unknown option' '' --no-boot --bogus-flag
run_case bad_character_is_usage_error 2 30 'must be animal, fairy, hobbit or ghost' '' --character=dragon

# ---- --fast (RT8): the wrapper adds `--fixed-fps 60`; a stand-in engine (tests/lib/selftest/fast/fake_godot.sh) prints its argv
FAKE_GODOT="$ST/fast/fake_godot.sh"
# fake_run NAME WANT_RC MAX_SECONDS MUST_MATCH MUST_NOT_MATCH ARGS...  (run_case with the stand-in engine; GODOT_EXTRA_ARGS is whatever the caller exported)
fake_run() { GODOT="$FAKE_GODOT" run_case "$@"; }
# fake_argv NAME -> the engine's argv of that case on one line ("--path . --headless --fixed-fps 60 -s res://tests/playtest.gd -- ...")
fake_argv() { grep '^FAKE_ARG ' "$WORK/$1.log" | cut -d' ' -f3- | tr '\n' ' '; }
fake_expect() { # fake_expect LABEL ARGV_PATTERN WANT(yes|no) CASE   (the argv matches / does not match the pattern)
	local argv
	argv="$(fake_argv "$4")"
	if { [ "$3" = yes ] && printf '%s' "$argv" | grep -Eq -- "$2"; } || { [ "$3" = no ] && ! printf '%s' "$argv" | grep -Eq -- "$2"; }; then
		note_ok "$1"
	else
		note_fail "$1: engine argv was: $argv"
	fi
}
fake_run harness.fast_flag_forwards_fixed_fps 0 30 'PLAYTEST PASS' '' --fast --no-boot
fake_expect "--fast becomes '--fixed-fps 60' ahead of the harness script" '--headless --fixed-fps 60 -s res://tests/playtest.gd -- ' yes harness.fast_flag_forwards_fixed_fps
fake_expect "--fast itself never reaches the harness (it would be an unknown option there)" '(^| )--fast( |$)' no harness.fast_flag_forwards_fixed_fps
fake_run no_fast_flag_keeps_real_time 0 30 'PLAYTEST PASS' '' --no-boot
fake_expect "without --fast no --fixed-fps is passed" '--fixed-fps' no no_fast_flag_keeps_real_time
GODOT_EXTRA_ARGS="--verbose" fake_run fast_flag_with_extra_engine_args 0 30 'PLAYTEST PASS' '' --fast --no-boot
fake_expect "GODOT_EXTRA_ARGS are kept next to --fixed-fps 60" '--headless --fixed-fps 60 --verbose -s res://tests/playtest.gd' yes fast_flag_with_extra_engine_args
GODOT_EXTRA_ARGS="--fixed-fps 30" fake_run fast_flag_keeps_an_own_fixed_fps 0 30 'PLAYTEST PASS' '' --fast --no-boot
fake_expect "an own --fixed-fps 30 is kept and not doubled" '--headless --fixed-fps 30 -s res://tests/playtest.gd' yes fast_flag_keeps_an_own_fixed_fps
fake_expect "an own --fixed-fps 30 is not followed by a second --fixed-fps 60" '--fixed-fps 60' no fast_flag_keeps_an_own_fixed_fps
fake_run fast_flag_is_ignored_in_a_windowed_run 0 30 'PLAYTEST PASS|--fast is ignored in a windowed run' '' --windowed --fast --out="$WORK/win_shots"
fake_expect "a windowed run opens its 1280x720 window and gets no --fixed-fps" '--resolution 1280x720 -s res://tests/playtest.gd' yes fast_flag_is_ignored_in_a_windowed_run
fake_expect "a windowed run does not pass --fixed-fps" '--fixed-fps' no fast_flag_is_ignored_in_a_windowed_run
fake_expect "a windowed run does not hand --fast to the harness either" '(^| )--fast( |$)' no fast_flag_is_ignored_in_a_windowed_run
if grep -q 'run_playtest: --fast is ignored in a windowed run' "$WORK/fast_flag_is_ignored_in_a_windowed_run.log"; then note_ok "a windowed run says that --fast is ignored"; else note_fail "a windowed run with --fast printed no notice"; fi
# the real engine: the flag is only worth something if physics really runs ahead of the wall clock
run_case fast_flag_runs_physics_ahead_of_the_wall_clock 0 60 'FASTPROBE ticks=300 wall_ms=' 'FAIL  |FAILED|PROBLEM' --fast --no-boot --sections-dir="$ST/fast"
FAST_MS=$(sed -n 's/.*FASTPROBE ticks=300 wall_ms=\([0-9]*\).*/\1/p' "$WORK/fast_flag_runs_physics_ahead_of_the_wall_clock.log" | head -1)
if [ -n "$FAST_MS" ] && [ "$FAST_MS" -lt 2500 ]; then note_ok "5 game seconds (300 physics ticks) with --fast: ${FAST_MS} ms of wall time"; else note_fail "5 game seconds with --fast took '${FAST_MS}' ms (want < 2500)"; fi
run_case real_time_without_the_fast_flag 0 60 'FASTPROBE ticks=300 wall_ms=' 'FAIL  |FAILED|PROBLEM' --no-boot --sections-dir="$ST/fast"
REAL_MS=$(sed -n 's/.*FASTPROBE ticks=300 wall_ms=\([0-9]*\).*/\1/p' "$WORK/real_time_without_the_fast_flag.log" | head -1)
if [ -n "$REAL_MS" ] && [ "$REAL_MS" -ge 3500 ]; then note_ok "the same 5 game seconds without --fast wait for the wall clock: ${REAL_MS} ms (the control of the check above)"; else note_fail "5 game seconds without --fast took '${REAL_MS}' ms (want >= 3500: without the flag the engine paces physics by the wall clock)"; fi
run_case fast_flag_with_list 0 30 'PLAYTEST list end: 2 section' '' --list --fast --sections-dir="$ST/pass"
# the watchdogs count wall-clock time: under --fast a frame is a fraction of a millisecond, so a game-time timer would stop a section that only waits on the wall clock
run_case fast_flag_section_watchdog_counts_wall_time 0 30 'ok +wall_wait\.waited_on_the_wall_clock' 'timed out|FAIL  |PROBLEM' --fast --no-boot --sections-dir="$ST/fast_wall"
run_case fast_flag_run_watchdog_counts_wall_time 0 30 'ok +wall_wait\.waited_on_the_wall_clock' 'run watchdog|timed out|FAIL  |PROBLEM' --fast --no-boot --sections-dir="$ST/fast_wall" --max-seconds=4
run_case fast_flag_ui_audit_settle_waits_process_time $PASS_RC 90 'ok +ui_audit_blind\.blind_two_modals_fade_longer_than_the_default' 'FAIL  |FAILED|PROBLEM|timed out' --fast --no-boot --only=ui_audit_blind
run_case fast_flag_hang_is_still_stopped 1 30 'timed out after 2 s' 'never_reached' --fast --no-boot --sections-dir="$ST/hang"
run_case fast_flag_run_watchdog_still_stops_a_hang 1 40 'run watchdog: the whole run exceeded 3 s' 'never_reached' --fast --no-boot --sections-dir="$ST/hang_global" --max-seconds=3

# ---- the flow helpers on the real game (new_game, start_world, days, go_menu, boot)
run_case flow_helpers $PASS_RC 90 "\\(0 failed, [0-9]+ skipped\\), $BASE_N engine error" 'FAIL  |FAILED|PROBLEM' --no-boot --sections-dir="$ST/flow"

# ---- the real flow on the current tree (legacy 3D tree: known failures are reported, never a crash)
CHARS="animal"
[ "$ALL_CHARS" = 1 ] && CHARS="animal fairy hobbit ghost"
for c in $CHARS; do
	if grep -q 'Node3D' scenes/main/world.tscn 2>/dev/null; then
		run_case "boot_legacy_$c" "*" 90 'PLAYTEST (PASS|FAIL)' '' --character="$c" --sections-dir="$ST/legacy"
		# the boot stage must be completely green and the ONLY failed check the known legacy one
		NFAIL=$(grep -c '^  FAIL  ' "$WORK/boot_legacy_$c.log")
		if grep -q 'ok    boot.phase_playing' "$WORK/boot_legacy_$c.log" && grep -q '^  FAIL  legacy_flow.pause_resumes' "$WORK/boot_legacy_$c.log" && [ "$NFAIL" = 1 ]; then
			note_ok "boot_legacy_$c: boot stage green, the one known legacy failure (pause_resumes) is reported instead of crashing"
		else
			note_fail "boot_legacy_$c: expected a green boot and exactly the known legacy failure pause_resumes ($NFAIL FAIL lines)"
		fi
	else
		run_case "boot_2d_$c" "*" 120 'ok +boot\.phase_playing' 'FAIL(ED)? +boot\.' --character="$c" --sections-dir="$ST/legacy"
	fi
done

# ---- a long statistical section (addendum 4.4: sections may run for statistical work up to 30 s)
if [ "$WITH_SLOW" = 1 ]; then
	run_case slow_statistics_section_is_allowed $PASS_RC 120 "\\(0 failed, [0-9]+ skipped\\), $BASE_N engine error" 'timed out|FAIL  |PROBLEM' --no-boot --sections-dir="$ST/slow"
fi

# ---- windowed (opens a real window: lead/user only)
if [ "$WITH_WINDOW" = 1 ]; then
	WOUT="$WORK/shots"
	CASE_RUNNER=tools/dev/run_windowed.sh run_case windowed_trivial $PASS_RC 90 "$CLEAN" 'FAIL  |FAILED|PROBLEM' --out="$WOUT" --sections-dir="$ST/windowed"
	if [ -s "$WOUT/trivial_trivial.png" ]; then note_ok "windowed screenshot written ($WOUT/trivial_trivial.png)"; else note_fail "windowed screenshot missing"; fi
fi

echo "== self-test: $PASSED ok, $FAILED failed"
[ "$FAILED" = 0 ]
