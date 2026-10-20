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
#   section timeout        exit 1 after the section's TIMEOUT_S, not after minutes; the sections after it still run and the
#                          stuck one stays parked; one woken by a non-t await prints its checks as uncounted `late` lines;
#                          --max-seconds stops a whole run;
#                          a Godot stuck in a synchronous loop is killed by the wrapper (exit 124), one killed from outside
#                          (out of memory) is reported as killed (exit 137), not as a timeout
#   isolation              t.on_cleanup() runs after a script error; locale, config overrides, Engine metas, autoload *_path
#                          seams and the modal stack that a section left behind are restored before the next one
#   press()                a real click: a hidden button, one outside the window and a covered one fail; press_unchecked() does not check
#   skip budget            under --strict a section that skips more than its budget fails; without --strict it is a note
#   perf_ok                the native reference, the TT_PERF_SCALE allowance (clamped to 4) and its SLOW lines
#   require_tool           a missing tool is a skip, under --strict a failure
#   --shuffle=N            changes the section order and prints it; a bad seed is a usage error
#   checkout lock          a second run in a busy checkout exits 2 at once
#   the run's log          the verdict reads the run's own log (a failed copy cannot bring back an older one), and an
#                          interrupted run still leaves its log in .godot/playtest_last.log
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
# CI runs it as its own job (.github/workflows/playtest.yml, "harness self-test"), and tools/dev/ci_local.sh runs it too.

cd "$(dirname "$0")/../.." || exit 2
ROOT="$(pwd)"
# shellcheck source=tools/dev/lock.sh
. tools/dev/lock.sh
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
cleanup() { chmod u+w "$ROOT/.godot" 2>/dev/null; rm -rf "${WORK:?}" "${ROOT:?}/.selftest"; }
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
run_case injected_shutdown_warning 1 60 'engine messages after the harness result.*' '' --no-boot --sections-dir="$ST/inject_shutdown_warning"
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
run_case timeout_keeps_the_run_going 1 30 'ok +b_next\.the_stuck_section_stays_parked' '^ZOMBIE-RAN-ON|never_reached|not run because' --no-boot --sections-dir="$ST/hang_then_next"
if grep -q 'timed out after 2 s' "$WORK/timeout_keeps_the_run_going.log" && grep -q 'ok    b_next.gets_a_fresh_t' "$WORK/timeout_keeps_the_run_going.log"; then note_ok "the timed-out section fails the run and the next one gets a fresh t"; else note_fail "timeout isolation: no timeout or no fresh t"; fi
run_case late_lines_of_a_timed_out_section_count_nowhere 1 30 'late  ok    a_late\.late_check_after_the_timeout   \[from a_late, which timed out: not counted\]' '^ZOMBIE-RAN-ON|never_reached|FAILED   (a_late\.late|b_next)' --no-boot --sections-dir="$ST/hang_late"
LL="$WORK/late_lines_of_a_timed_out_section_count_nowhere.log"
if grep -q '^  late  FAIL  late failure after the timeout' "$LL" && grep -q '^  late  SKIP  late skip after the timeout' "$LL" && grep -q 'ok    b_next.own_counts_only' "$LL" && grep -q '^== summary: 2 section(s) run, 2 checks (0 failed, 0 skipped)' "$LL"; then
	note_ok "a woken timed-out section prints late lines, and neither the next section nor the run counts them"
else
	note_fail "late lines of a timed-out section: missing, or counted ($(grep '^== summary' "$LL"))"
fi
run_case run_watchdog 1 40 'run watchdog: the whole run exceeded 3 s' 'never_reached' --no-boot --sections-dir="$ST/hang_global" --max-seconds=3
run_case wrapper_timeout_kills_a_spinning_godot 124 60 'TIMEOUT after 6s' '' --no-boot --sections-dir="$ST/spin" --timeout=6
FAKE_GODOT_KILL=1 GODOT="$ST/fast/fake_godot.sh" run_case killed_engine_is_not_a_timeout 137 30 'Godot was KILLED \(SIGKILL\).*out of memory' 'TIMEOUT after' --no-boot
run_case bad_shuffle_seed_is_usage_error 2 30 'shuffle needs a seed' '' --no-boot --sections-dir="$ST/pass" --shuffle=abc
run_case unknown_only_is_usage_error 2 30 'unknown section .nope.' '' --no-boot --sections-dir="$ST/pass" --only=nope
run_case unknown_option_is_usage_error 2 30 'unknown option' '' --no-boot --bogus-flag
run_case bad_character_is_usage_error 2 30 'must be animal, fairy, hobbit or ghost' '' --character=dragon

# ---- isolation between sections: cleanups after a script error, leaked state restored for the next section
run_case cleanups_run_and_state_is_restored 1 60 'ok +b_checks\.modal_stack_emptied' 'FAILED   b_checks|AFTER_ERROR_SHOULD_NOT_RUN' --no-boot --sections-dir="$ST/state"
SL="$WORK/cleanups_run_and_state_is_restored.log"
C1=$(grep -n 'CLEANUP-RAN-FIRST' "$SL" | head -1 | cut -d: -f1)
C2=$(grep -n 'CLEANUP-RAN-SECOND' "$SL" | head -1 | cut -d: -f1)
if [ -n "$C1" ] && [ -n "$C2" ] && [ "$C1" -lt "$C2" ]; then note_ok "t.on_cleanup() callables run after a script error, last registered first"; else note_fail "cleanups did not run in order ($C1 / $C2)"; fi
if grep -q 'left state behind; restored: locale en -> da; config overrides; open modals' "$SL" && grep -q 'LootService.delegate_path' "$SL"; then note_ok "the harness names what it restored"; else note_fail "no restore note for the leaked state"; fi

# ---- press() is a real click; press_unchecked() is not
run_case press_refuses_what_a_player_cannot_click 1 60 'ok +press_blocked\.refused_buttons_did_not_fire' '' --no-boot --sections-dir="$ST/press_blocked"
PL="$WORK/press_refuses_what_a_player_cannot_click.log"
if grep -q 'FAILED   press_blocked.button %StHiddenButton is hidden' "$PL" && grep -q 'FAILED   press_blocked.button %StOutsideButton is outside the window' "$PL" && grep -q 'FAILED   press_blocked.button %StCoveredButton did not get the click.*StOverlay is on top of it' "$PL"; then note_ok "press() fails on a hidden, an outside and a covered button, and names the overlay"; else note_fail "press() refusals missing"; fi

# ---- the skip budget (tests/lib/skip_budget.txt; --skip-budget= points the fixtures at their own file)
run_case skip_budget_fails_under_strict 1 30 'section skipper skipped 2 check\(s\), its budget is 1' 'PLAYTEST PASS' --no-boot --strict --sections-dir="$ST/skips" --skip-budget="$ST/skips/budget_one.txt"
run_case skip_budget_is_a_note_without_strict $PASS_RC 30 'its budget is 1 .*\(fails under --strict\)' 'PROBLEM' --no-boot --sections-dir="$ST/skips" --skip-budget="$ST/skips/budget_one.txt"
run_case skip_budget_within_passes $PASS_RC 30 "$CLEAN" 'budget is' --no-boot --strict --sections-dir="$ST/skips" --skip-budget="$ST/skips/budget_two.txt"

# ---- perf_ok: native reference, the TT_PERF_SCALE allowance (clamped to 1..4) and the SLOW report
TT_PERF_SCALE=2 run_case perf_ok_allowance_passes_and_reports_slow $PASS_RC 30 'SLOW +perf\.slow: 3\.0, native reference 2\.0 \(1\.50x, passed inside the runner limit 4\.0\)' 'SLOW +perf\.(fast|over)|FAILED' --no-boot --sections-dir="$ST/perf"
TT_PERF_SCALE=1 run_case perf_ok_native_run_keeps_the_reference 1 30 'FAILED   perf\.inside_allowance' 'SLOW|FAILED   perf\.(within_reference|over_limit_is_false)' --no-boot --sections-dir="$ST/perf"
TT_PERF_SCALE=99 run_case perf_ok_scale_is_clamped_to_four $PASS_RC 30 'runner limit 8\.0' 'FAILED' --no-boot --sections-dir="$ST/perf"

# ---- require_tool: a missing program is a skip, under --strict a failure
run_case require_tool_skips_a_missing_tool $PASS_RC 30 'SKIP  probe check: tt-selftest-no-such-tool is not installed' 'FAILED' --no-boot --sections-dir="$ST/require_tool"
run_case require_tool_fails_under_strict 1 30 'FAILED   require\.probe check: tt-selftest-no-such-tool is not installed' 'MISSING_TOOL_MUST_NOT_PASS|FAILED   require\.existing_tool' --no-boot --strict --sections-dir="$ST/require_tool"

# ---- --shuffle=N reorders the sections (seed 2 puts second_named first) and says so
run_case shuffle_changes_the_order $PASS_RC 60 'shuffle=2: sections run in this order: second_named, a_basics' 'FAILED' --no-boot --sections-dir="$ST/pass" --shuffle=2
A_LINE=$(grep -n '== section a_basics' "$WORK/shuffle_changes_the_order.log" | head -1 | cut -d: -f1)
B_LINE=$(grep -n '== section second_named' "$WORK/shuffle_changes_the_order.log" | head -1 | cut -d: -f1)
if [ -n "$A_LINE" ] && [ -n "$B_LINE" ] && [ "$B_LINE" -lt "$A_LINE" ]; then note_ok "--shuffle=2 runs second_named before a_basics"; else note_fail "--shuffle=2 did not change the order ($A_LINE / $B_LINE)"; fi

# ---- one run per checkout: a second run while the lock is held exits 2 at once (this script holds it for the case)
if take_checkout_lock "$ROOT" selftest_harness; then
	run_case busy_checkout_is_refused 2 15 'another run is using this checkout' 'PLAYTEST start' --no-boot --sections-dir="$ST/pass"
	release_checkout_lock
else
	note_fail "busy_checkout_is_refused: could not take the checkout lock for the case"
fi

# ---- the run's own log: the verdict reads it, and .godot/playtest_last.log gets a copy also when the run was interrupted
LAST=".godot/playtest_last.log"
echo "PLAYTEST PASS (an older run)" >"$LAST"
chmod a-w .godot   # the copy to playtest_last.log fails, and so does removing the older run's copy
FAKE_GODOT_NO_RESULT=1 GODOT="$ST/fast/fake_godot.sh" run_case verdict_reads_the_runs_own_log 2 30 'printed no result line' '' --no-boot
chmod u+w .godot
if grep -q "could not copy the run's log" "$WORK/verdict_reads_the_runs_own_log.log"; then note_ok "a failed copy of the run's log is reported"; else note_fail "a failed copy of the run's log was not reported"; fi
rm -f "$LAST"
FAKE_GODOT_MARK="interrupted-$$" FAKE_GODOT_SLEEP=4 PLAYTEST_NO_IMPORT=1 GODOT="$ST/fast/fake_godot.sh" "$RUN" --no-boot >"$WORK/interrupted_run.log" 2>&1 &
RUN_PID=$!
sleep 1
kill -TERM "$RUN_PID"
wait "$RUN_PID"
RUN_RC=$?
if [ "$RUN_RC" = 130 ] && grep -q "^FAKE_MARK interrupted-$$\$" "$LAST" 2>/dev/null; then
	note_ok "an interrupted run (exit 130) leaves its own log in $LAST"
else
	note_fail "interrupted run: exit $RUN_RC, $LAST has $(grep '^FAKE_MARK' "$LAST" 2>/dev/null || echo 'no FAKE_MARK line')"
fi

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
GODOT_EXTRA_ARGS="--verbose *" fake_run extra_engine_args_are_not_glob_expanded 0 30 'PLAYTEST PASS' '' --no-boot
fake_expect "GODOT_EXTRA_ARGS are split on spaces, a * stays a literal argument" '--verbose \* -s res://tests/playtest.gd' yes extra_engine_args_are_not_glob_expanded
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
run_case fast_flag_run_watchdog_counts_wall_time 0 30 'ok +wall_wait\.waited_on_the_wall_clock' 'run watchdog|timed out|FAIL  |PROBLEM' --fast --no-boot --sections-dir="$ST/fast_wall" --max-seconds=8
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
