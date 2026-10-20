#!/usr/bin/env bash
# tools/dev/ci_local.sh - the local gate: runs what .github/workflows/playtest.yml runs, on this machine, and finishes.
#
#   tools/dev/ci_local.sh [--out=DIR] [--parallel=N] [--races="animal fairy hobbit ghost"] [--shards="0 1 2 3"] [--no-selftest]
#
# A plain `tests/run_playtest.sh --strict` runs every section in ONE process for one hero (well over an hour); the gate that
# keeps `main` green is the CI split instead, and this script is that split:
#   1. the checks without Godot: localization lint, release tooling unit tests, crop-guide reference check (art venv);
#   2. two imports of THIS checkout; the second one must print no ERROR / WARNING line;
#   3. per hero x shard (4 x 4): an APFS clone of this checkout (.godot included, so it starts warm), the shard's ordinary
#      sections (tools/ci/sections.py --pace normal) with --strict --timeout=2700, then its seeded simulations (--pace simulation)
#      with --strict --fast --timeout=1800, exactly as the CI job does; N clones run at a time (default 4, one Godot each);
#   4. the harness self-test (tools/dev/selftest_harness.sh, the CI job "harness self-test") in a clone of its own;
#   5. a summary (DIR/SUMMARY.txt): one line per run; exit 0 only when every step passed.
# TT_PERF_SCALE defaults to 4 like CI (shared CPUs). It tests the working tree as it is, uncommitted changes included.
# Logs, JSON reports and the summary go to DIR (default $TMPDIR/traetoppen-ci/<timestamp>); clones are deleted when done.
# Wall time on an 8-core Mac with --parallel=4: about an hour. For one section while developing, use the inner loop instead:
#   tests/run_playtest.sh --strict --no-boot --only=<section> [--character=fairy]
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 2
ROOT="$(pwd)"
# shellcheck source=tools/dev/lock.sh
. tools/dev/lock.sh
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
export GODOT TT_PERF_SCALE="${TT_PERF_SCALE:-4}" PYTHONUNBUFFERED=1
TMP_BASE="${TMPDIR:-/tmp}"
TMP_BASE="${TMP_BASE%/}"
OUT="$TMP_BASE/traetoppen-ci/$(date +%Y%m%d-%H%M%S)"
PAR=4
RACES="animal fairy hobbit ghost"
SHARDS="0 1 2 3"
SELFTEST=1
for a in "$@"; do
	case "$a" in
		--out=*) OUT="${a#--out=}" ;;
		--parallel=*) PAR="${a#--parallel=}" ;;
		--races=*) RACES="${a#--races=}" ;;
		--shards=*) SHARDS="${a#--shards=}" ;;
		--no-selftest) SELFTEST=0 ;;
		-h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "ci_local: unknown option $a (see --help)" >&2; exit 2 ;;
	esac
done
[ -x "$GODOT" ] || { echo "ci_local: Godot binary not found at $GODOT (set GODOT=...)" >&2; exit 2; }
case "$PAR" in ''|*[!0-9]*|0) echo "ci_local: --parallel needs a positive number (got '$PAR')" >&2; exit 2 ;; esac
mkdir -p "$OUT" || exit 2
OUT="$(cd "$OUT" && pwd)"
case "$OUT/" in "$ROOT"/*) echo "ci_local: --out must be outside the checkout (the clones would copy themselves)" >&2; exit 2 ;; esac
COPIES="$OUT/copies"
mkdir -p "$COPIES"
# the one Python of the tooling: the art venv when it exists (CI: setup-python 3.12 + tools/art/setup_env.sh), else python3
PY=python3
[ -x tools/art/.venv/bin/python ] && PY="$ROOT/tools/art/.venv/bin/python"

stop_all() {
	echo "ci_local: interrupted, stopping the running shards" >&2
	# shellcheck disable=SC2046
	kill $(jobs -p) 2>/dev/null
	wait
	rm -rf "${COPIES:?}"
	exit 130
}
trap stop_all INT TERM

# ---------------------------------------------------------------- 1. checks without Godot
step() {   # step NAME CMD...  -> OUT/NAME.log, OUT/NAME.rc
	"$@" >"$OUT/$1.log" 2>&1
	echo $? >"$OUT/$1.rc"
}
lint_loc() { "$PY" tools/loc/csv_lint.py --strict --quiet; }
release_tests() { "$PY" -m unittest discover -s tools/release/tests -v; }
crop_refs() {
	[ -x tools/art/.venv/bin/python ] || { echo "the art venv is missing (tools/art/setup_env.sh): CI runs this check with it"; return 1; }
	tools/art/.venv/bin/python tools/ui/test_crop_guide_refs.py
}
echo "ci_local: results go to $OUT"
echo "ci_local: checks without Godot ..."
step localization lint_loc
step release_tooling release_tests
step crop_guide_refs crop_refs

# ---------------------------------------------------------------- 2. import this checkout twice
echo "ci_local: importing $ROOT (two passes) ..."
take_checkout_lock "$ROOT" ci_local || exit 2
"$GODOT" --headless --path . --import >"$OUT/import1.log" 2>&1
I1=$?
"$GODOT" --headless --path . --import >"$OUT/import2.log" 2>&1
I2=$?
release_checkout_lock
if [ "$I1" != 0 ] || [ "$I2" != 0 ]; then
	echo 2 >"$OUT/import.rc"
	echo "ci_local: godot --import failed (exit $I1 / $I2, see $OUT/import*.log)" >&2
elif grep -Eq '^(ERROR|WARNING|SCRIPT ERROR|USER ERROR|USER WARNING):' "$OUT/import2.log"; then
	echo 1 >"$OUT/import.rc"
	echo "ci_local: the second import printed errors or warnings (see $OUT/import2.log)" >&2
else
	echo 0 >"$OUT/import.rc"
fi
# the import succeeded: renew the runner's stamp, or every clone would see a stale cache and import again
[ "$I1" = 0 ] && [ "$I2" = 0 ] && mkdir -p .godot && touch .godot/playtest_import.stamp

# ---------------------------------------------------------------- 3. + 4. the shards and the self-test, N at a time
clone_tree() {   # clone_tree DEST: APFS clone (cp -c keeps the blocks shared and the mtimes), else a plain archive copy
	rm -rf "${1:?}"
	cp -Rc "$ROOT" "$1" 2>/dev/null || { rm -rf "${1:?}"; cp -a "$ROOT" "$1"; } || return 1
	rm -f "$1/project.godot.lock"
}

run_shard() {   # run_shard RACE SHARD
	local race="$1" shard="$2" c="$COPIES/$1-$2" sections sim
	clone_tree "$c" || { echo 2 >"$OUT/$race-$shard.rc"; return; }
	(
		cd "$c" || exit 2
		sections="$("$PY" tools/ci/sections.py --shard "$shard" --count 4 --pace normal)"
		tests/run_playtest.sh --strict --timeout=2700 --only="$sections" --character="$race" \
			--report="$OUT/$race-$shard.json" >"$OUT/$race-$shard.log" 2>&1
		echo $? >"$OUT/$race-$shard.rc"
		sim="$("$PY" tools/ci/sections.py --shard "$shard" --count 4 --pace simulation)"
		if [ -n "$sim" ]; then
			tests/run_playtest.sh --strict --fast --timeout=1800 --only="$sim" --character="$race" \
				--report="$OUT/$race-$shard-sim.json" >"$OUT/$race-$shard-sim.log" 2>&1
			echo $? >"$OUT/$race-$shard-sim.rc"
		fi
	)
	rm -rf "${c:?}"
}

run_selftest() {
	local c="$COPIES/selftest"
	clone_tree "$c" || { echo 2 >"$OUT/selftest.rc"; return; }
	( cd "$c" && tools/dev/selftest_harness.sh >"$OUT/selftest.log" 2>&1; echo $? >"$OUT/selftest.rc" )
	rm -rf "${c:?}"
}

JOBS=()
[ "$SELFTEST" = 1 ] && JOBS+=("selftest")
for r in $RACES; do for s in $SHARDS; do JOBS+=("$r $s"); done; done
echo "ci_local: ${#JOBS[@]} run(s), $PAR at a time, TT_PERF_SCALE=$TT_PERF_SCALE ..."
for j in "${JOBS[@]}"; do
	while [ "$(jobs -pr | wc -l | tr -d ' ')" -ge "$PAR" ]; do sleep 2; done
	echo "ci_local: start $j"
	if [ "$j" = selftest ]; then
		run_selftest &
	else
		# shellcheck disable=SC2086
		run_shard $j &
	fi
done
wait
rmdir "$COPIES" 2>/dev/null

# ---------------------------------------------------------------- 5. summary
FAIL=0
{
	for f in "$OUT"/*.rc; do
		n="$(basename "$f" .rc)"
		rc="$(cat "$f")"
		[ "$rc" = 0 ] || FAIL=1
		printf '%-18s rc=%-3s %s\n' "$n" "$rc" "$(grep -E '^PLAYTEST (PASS|FAIL)|^== self-test:|TIMEOUT|killed' "$OUT/$n.log" 2>/dev/null | tail -1)"
	done
} >"$OUT/SUMMARY.txt"
cat "$OUT/SUMMARY.txt"
echo "ci_local: $([ "$FAIL" = 0 ] && echo GREEN || echo RED) (logs in $OUT)"
exit "$FAIL"
